from decimal import Decimal, InvalidOperation

from django.db import transaction
from django.db.models import Count, Q
from django.utils import timezone
from rest_framework import permissions, serializers, status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

from common.auth import (
    IsManagerOrReadOnly, IsManagerRole, get_user_id, is_admin_or_staff, is_landlord, is_manager,
)
from .models import MaintenanceRequest, MaintenanceStatus, Property, Room, RoomStatus
from .serializers import MaintenanceRequestSerializer, PropertySerializer, RoomSerializer


def _parse_decimal(value):
    if value in (None, ''):
        return None
    try:
        return Decimal(value)
    except (InvalidOperation, TypeError):
        raise serializers.ValidationError({'detail': f'Giá trị số không hợp lệ: {value}'})


def scoped_properties(user):
    """
    Phân quyền dữ liệu nhà trọ dựa trên claims JWT (Identity Service):
    - ADMIN / STAFF : toàn bộ hệ thống
    - LANDLORD      : nhà trọ mình sở hữu (owner_id)
    - TENANT        : chỉ nhà trọ còn phòng trống (xem để tìm phòng)
    """
    queryset = Property.objects.all()
    if is_admin_or_staff(user):
        return queryset
    if is_landlord(user):
        return queryset.filter(owner_id=get_user_id(user))
    return queryset.filter(rooms__status=RoomStatus.AVAILABLE).distinct()


def scoped_rooms(user):
    queryset = Room.objects.select_related('property')
    if is_admin_or_staff(user):
        return queryset
    if is_landlord(user):
        return queryset.filter(property__owner_id=get_user_id(user))
    return queryset


class PropertyViewSet(viewsets.ModelViewSet):
    """
    SERVICE 2 — PROPERTY MANAGEMENT:
    - CRUD nhà trọ, tìm kiếm
    - /{id}/rooms/  danh sách phòng của nhà trọ
    - /{id}/stats/  thống kê phòng của 1 nhà trọ
    - /summary/     thống kê tổng hợp theo phạm vi user (dùng cho Dashboard qua Gateway)
    """
    serializer_class = PropertySerializer
    permission_classes = [IsManagerOrReadOnly]

    def get_queryset(self):
        queryset = scoped_properties(self.request.user).prefetch_related('rooms')

        search = self.request.query_params.get('search')
        if search:
            queryset = queryset.filter(
                Q(name__icontains=search) |
                Q(address__icontains=search) |
                Q(district__icontains=search)
            )
        return queryset

    @action(detail=True, methods=['get'], url_path='rooms')
    def rooms(self, request, pk=None):
        property_obj = self.get_object()
        status_filter = request.query_params.get('status')
        rooms = property_obj.rooms.all()
        if status_filter and status_filter != 'ALL':
            rooms = rooms.filter(status=status_filter)
        return Response(RoomSerializer(rooms, many=True).data)

    @action(detail=True, methods=['get'], url_path='stats')
    def stats(self, request, pk=None):
        property_obj = self.get_object()
        total = property_obj.rooms.count()
        available = property_obj.rooms.filter(status=RoomStatus.AVAILABLE).count()
        occupied = property_obj.rooms.filter(status=RoomStatus.OCCUPIED).count()
        maintenance = property_obj.rooms.filter(status=RoomStatus.MAINTENANCE).count()
        reserved = property_obj.rooms.filter(status=RoomStatus.RESERVED).count()
        occupancy_rate = round((occupied / total * 100), 1) if total > 0 else 0.0

        return Response({
            'property_id': property_obj.id,
            'property_name': property_obj.name,
            'total_rooms': total,
            'available_rooms': available,
            'occupied_rooms': occupied,
            'maintenance_rooms': maintenance,
            'reserved_rooms': reserved,
            'occupancy_rate_percent': occupancy_rate,
        })

    @action(detail=False, methods=['get'], url_path='summary')
    def summary(self, request):
        """Thống kê tổng hợp nhà trọ / phòng / bảo trì trong phạm vi của user hiện tại."""
        user = request.user
        properties = scoped_properties(user)
        rooms = scoped_rooms(user)
        if not is_manager(user):
            rooms = rooms.filter(property__in=properties)
        counts = {row['status']: row['n'] for row in rooms.values('status').annotate(n=Count('id'))}
        total_rooms = sum(counts.values())
        occupied = counts.get(RoomStatus.OCCUPIED, 0)
        open_maintenance = MaintenanceRequest.objects.filter(
            room__in=rooms,
            status__in=[MaintenanceStatus.PENDING, MaintenanceStatus.IN_PROGRESS],
        ).count()
        return Response({
            'total_properties': properties.count(),
            'total_rooms': total_rooms,
            'available_rooms': counts.get(RoomStatus.AVAILABLE, 0),
            'occupied_rooms': occupied,
            'maintenance_rooms': counts.get(RoomStatus.MAINTENANCE, 0),
            'reserved_rooms': counts.get(RoomStatus.RESERVED, 0),
            'occupancy_rate_percent': round(occupied / total_rooms * 100, 1) if total_rooms else 0.0,
            'open_maintenance_requests': open_maintenance,
        })


class RoomViewSet(viewsets.ModelViewSet):
    """
    SERVICE 2 — ROOM MANAGEMENT:
    - CRUD phòng
    - Lọc: property_id, status, min_price, max_price, search (số phòng)
    - PATCH /{id}/status/ cập nhật nhanh trạng thái
    """
    serializer_class = RoomSerializer
    permission_classes = [IsManagerOrReadOnly]

    def get_queryset(self):
        queryset = scoped_rooms(self.request.user)
        params = self.request.query_params

        property_id = params.get('property_id')
        if property_id:
            queryset = queryset.filter(property_id=property_id)

        status_param = params.get('status')
        if status_param and status_param != 'ALL':
            queryset = queryset.filter(status=status_param)

        min_price = _parse_decimal(params.get('min_price'))
        if min_price is not None:
            queryset = queryset.filter(rent_price__gte=min_price)
        max_price = _parse_decimal(params.get('max_price'))
        if max_price is not None:
            queryset = queryset.filter(rent_price__lte=max_price)

        search = params.get('search')
        if search:
            queryset = queryset.filter(room_number__icontains=search)

        return queryset

    def _check_property_ownership(self, serializer):
        prop = serializer.validated_data.get('property')
        if prop is not None and not scoped_properties(self.request.user).filter(pk=prop.pk).exists():
            raise serializers.ValidationError({'property': 'Bạn không có quyền quản lý nhà trọ này.'})

    def perform_create(self, serializer):
        self._check_property_ownership(serializer)
        serializer.save()

    def perform_update(self, serializer):
        self._check_property_ownership(serializer)
        serializer.save()

    @action(detail=True, methods=['patch'], url_path='status')
    def update_status(self, request, pk=None):
        room = self.get_object()
        new_status = request.data.get('status')
        if new_status not in RoomStatus.values:
            return Response(
                {
                    'error': f'Trạng thái không hợp lệ. Các giá trị được phép: {RoomStatus.values}',
                    'allowed_statuses': RoomStatus.values
                },
                status=status.HTTP_400_BAD_REQUEST
            )
        room.status = new_status
        room.save(update_fields=['status', 'updated_at'])
        return Response(RoomSerializer(room).data)


class MaintenanceRequestViewSet(viewsets.ModelViewSet):
    """
    SERVICE 2 — MAINTENANCE:
    - POST   /maintenance/                 tạo yêu cầu (mọi user đã đăng nhập, kể cả TENANT)
    - GET    /maintenance/?status=&room_id=&property_id=   theo dõi
    - PATCH  /maintenance/{id}/            cập nhật nội dung (quản lý)
    - POST   /maintenance/{id}/start/      bắt đầu xử lý
    - POST   /maintenance/{id}/complete/   hoàn thành (cost, resolution_note)
    - POST   /maintenance/{id}/cancel/     hủy
    """
    serializer_class = MaintenanceRequestSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        queryset = MaintenanceRequest.objects.select_related('room', 'room__property')
        if is_admin_or_staff(user):
            pass
        elif is_landlord(user):
            queryset = queryset.filter(room__property__owner_id=get_user_id(user))
        else:
            queryset = queryset.filter(reported_by_id=get_user_id(user))

        params = self.request.query_params
        if params.get('status') and params['status'] != 'ALL':
            queryset = queryset.filter(status=params['status'])
        if params.get('room_id'):
            queryset = queryset.filter(room_id=params['room_id'])
        if params.get('property_id'):
            queryset = queryset.filter(room__property_id=params['property_id'])
        return queryset

    def get_permissions(self):
        if self.action in ('update', 'partial_update', 'destroy', 'start', 'complete'):
            return [permissions.IsAuthenticated(), IsManagerRole()]
        return super().get_permissions()

    @transaction.atomic
    def perform_create(self, serializer):
        user = self.request.user
        room = serializer.validated_data['room']
        if is_landlord(user) and room.property.owner_id != get_user_id(user):
            raise serializers.ValidationError({'room': 'Phòng không thuộc nhà trọ của bạn.'})
        mark = serializer.validated_data.pop('mark_room_maintenance', False)
        extra = {'reported_by_id': get_user_id(user)}
        if mark and is_manager(user) and room.status != RoomStatus.MAINTENANCE:
            extra['previous_room_status'] = room.status
            room.status = RoomStatus.MAINTENANCE
            room.save(update_fields=['status', 'updated_at'])
        serializer.save(**extra)

    def perform_update(self, serializer):
        serializer.validated_data.pop('mark_room_maintenance', None)
        serializer.save()

    def _restore_room(self, req):
        room = req.room
        if req.previous_room_status and room.status == RoomStatus.MAINTENANCE:
            room.status = req.previous_room_status
            room.save(update_fields=['status', 'updated_at'])

    def _transition(self, req, allowed_from, target):
        if req.status not in allowed_from:
            return Response(
                {'error': f'Không thể chuyển từ {req.status} sang {target}.'},
                status=status.HTTP_400_BAD_REQUEST)
        return None

    @action(detail=True, methods=['post'])
    def start(self, request, pk=None):
        req = self.get_object()
        error = self._transition(req, [MaintenanceStatus.PENDING], MaintenanceStatus.IN_PROGRESS)
        if error:
            return error
        req.status = MaintenanceStatus.IN_PROGRESS
        req.started_at = timezone.now()
        if request.data.get('assigned_to'):
            req.assigned_to = request.data['assigned_to']
        req.save()
        return Response(self.get_serializer(req).data)

    @action(detail=True, methods=['post'])
    @transaction.atomic
    def complete(self, request, pk=None):
        req = self.get_object()
        error = self._transition(
            req, [MaintenanceStatus.PENDING, MaintenanceStatus.IN_PROGRESS], MaintenanceStatus.COMPLETED)
        if error:
            return error
        cost = _parse_decimal(request.data.get('cost'))
        if cost is not None:
            req.cost = cost
        if request.data.get('resolution_note'):
            req.resolution_note = request.data['resolution_note']
        req.status = MaintenanceStatus.COMPLETED
        req.completed_at = timezone.now()
        req.save()
        self._restore_room(req)
        return Response(self.get_serializer(req).data)

    @action(detail=True, methods=['post'])
    @transaction.atomic
    def cancel(self, request, pk=None):
        req = self.get_object()
        user = request.user
        if not is_manager(user) and req.reported_by_id != get_user_id(user):
            return Response({'error': 'Bạn không có quyền hủy yêu cầu này.'}, status=status.HTTP_403_FORBIDDEN)
        error = self._transition(
            req, [MaintenanceStatus.PENDING, MaintenanceStatus.IN_PROGRESS], MaintenanceStatus.CANCELLED)
        if error:
            return error
        req.status = MaintenanceStatus.CANCELLED
        req.save()
        self._restore_room(req)
        return Response(self.get_serializer(req).data)

