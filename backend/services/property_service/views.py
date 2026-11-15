from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from django.db.models import Q, Sum
from django.utils import timezone

from .models import (
    Property,
    PropertyStatus,
    Room,
    RoomStatus,
    MaintenanceRequest,
    MaintenanceStatus,
    MaintenanceHistory,
)
from .serializers import (
    PropertySerializer,
    RoomSerializer,
    MaintenanceRequestSerializer,
    MaintenanceHistorySerializer,
)


def _actor_name(user):
    if not user or not user.is_authenticated:
        return 'Hệ thống'
    return getattr(user, 'full_name', '') or getattr(user, 'username', '') or f'User #{user.id}'


# ==============================================================================
# I. MODULE PROPERTY — QUẢN LÝ NHÀ TRỌ
# ==============================================================================
class PropertyViewSet(viewsets.ModelViewSet):
    """
    I. MODULE PROPERTY — QUẢN LÝ NHÀ TRỌ:
    1.1 Thêm nhà trọ (POST /api/v1/properties/)
    1.2 Xem danh sách nhà trọ (GET /api/v1/properties/)
    1.3 Xem chi tiết nhà trọ (GET /api/v1/properties/{id}/)
    1.4 Cập nhật thông tin nhà trọ (PUT/PATCH /api/v1/properties/{id}/)
    1.5 Xóa / Ngừng hoạt động nhà trọ (Soft Delete: ACTIVE / INACTIVE / DELETED)
    1.6 Tìm kiếm nhà trọ (?search= theo Tên, Mã, Địa chỉ, Khu vực)
    1.7 Lọc nhà trọ (?status=ACTIVE|INACTIVE|DELETED, ?district=, ?ward=)
    """
    serializer_class = PropertySerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        queryset = Property.objects.all().prefetch_related('rooms')

        if hasattr(user, 'role') and user.role == 'LANDLORD' and not getattr(user, 'is_superuser', False):
            queryset = queryset.filter(owner_id=user.id)

        # 1.7 Lọc theo trạng thái hoạt động
        status_param = self.request.query_params.get('status')
        include_deleted = self.request.query_params.get('include_deleted') == 'true'
        if status_param and status_param != 'ALL':
            queryset = queryset.filter(status=status_param.upper())
        elif not include_deleted and self.action == 'list' and status_param != 'ALL':
            queryset = queryset.exclude(status=PropertyStatus.DELETED)

        # 1.7 Lọc theo khu vực
        district = self.request.query_params.get('district')
        if district and district != 'ALL':
            queryset = queryset.filter(district__icontains=district.strip())

        ward = self.request.query_params.get('ward')
        if ward and ward != 'ALL':
            queryset = queryset.filter(ward__icontains=ward.strip())

        # 1.6 Tìm kiếm nhà trọ (Tên, Mã, Địa chỉ, Khu vực)
        search = self.request.query_params.get('search')
        if search:
            q = search.strip()
            queryset = queryset.filter(
                Q(name__icontains=q)
                | Q(code__icontains=q)
                | Q(address__icontains=q)
                | Q(ward__icontains=q)
                | Q(district__icontains=q)
                | Q(city__icontains=q)
            )

        return queryset

    def destroy(self, request, *args, **kwargs):
        """
        1.5 Soft Delete nhà trọ:
        Nếu nhà trọ đang có phòng hoặc dữ liệu liên quan, chuyển sang DELETED/INACTIVE thay vì xóa cứng.
        """
        prop = self.get_object()
        occupied_count = prop.rooms.filter(status__in=[RoomStatus.OCCUPIED, RoomStatus.FULL]).count()
        if occupied_count > 0:
            return Response(
                {
                    'error': f'Nhà trọ "{prop.name}" đang có {occupied_count} phòng đang thuê. '
                             f'Không thể xóa khi còn khách đang ở (hãy chuyển sang INACTIVE).'
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        if prop.rooms.exists():
            prop.status = PropertyStatus.DELETED
            prop.save(update_fields=['status', 'updated_at'])
            return Response({
                'message': f'Nhà trọ "{prop.name}" đang có {prop.rooms.count()} phòng nên đã được chuyển sang trạng thái '
                           f'DELETED (Soft Delete) để bảo toàn dữ liệu lịch sử.',
                'soft_deleted': True,
                'property': PropertySerializer(prop).data,
            })

        prop_name = prop.name
        prop.delete()
        return Response({'message': f'Đã xóa nhà trọ "{prop_name}" thành công.', 'soft_deleted': False})

    @action(detail=True, methods=['post', 'patch'], url_path='update_status')
    def update_status(self, request, pk=None):
        """1.5 Đổi nhanh trạng thái nhà trọ: ACTIVE / INACTIVE / DELETED."""
        prop = self.get_object()
        new_status = (request.data.get('status') or '').upper()
        if new_status not in PropertyStatus.values:
            return Response(
                {'error': f'Trạng thái không hợp lệ. Chọn một trong: {PropertyStatus.values}'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        prop.status = new_status
        prop.save(update_fields=['status', 'updated_at'])
        return Response({
            'message': f'Đã cập nhật trạng thái nhà trọ "{prop.name}" thành {prop.get_status_display()}.',
            'property': PropertySerializer(prop).data,
        })

    @action(detail=True, methods=['get'], url_path='rooms')
    def rooms(self, request, pk=None):
        property_obj = self.get_object()
        rooms = property_obj.rooms.all()
        status_filter = request.query_params.get('status')
        if status_filter and status_filter != 'ALL':
            rooms = rooms.filter(status=status_filter.upper())
        return Response(RoomSerializer(rooms, many=True).data)

    @action(detail=True, methods=['get'], url_path='stats')
    def stats(self, request, pk=None):
        property_obj = self.get_object()
        rooms = property_obj.rooms.all()
        total = rooms.count()
        available = rooms.filter(status=RoomStatus.AVAILABLE).count()
        occupied = rooms.filter(status=RoomStatus.OCCUPIED).count()
        full = rooms.filter(status=RoomStatus.FULL).count()
        maintenance = rooms.filter(status=RoomStatus.MAINTENANCE).count()
        inactive = rooms.filter(status=RoomStatus.INACTIVE).count()
        rented_total = occupied + full
        occupancy_rate = round((rented_total / total * 100), 1) if total > 0 else 0.0
        monthly_revenue = sum(r.rent_price for r in rooms.filter(status__in=[RoomStatus.OCCUPIED, RoomStatus.FULL]))

        return Response({
            'property_id': property_obj.id,
            'property_code': property_obj.code,
            'property_name': property_obj.name,
            'status': property_obj.status,
            'total_rooms': total,
            'available_rooms': available,
            'occupied_rooms': occupied,
            'full_rooms': full,
            'maintenance_rooms': maintenance,
            'inactive_rooms': inactive,
            'occupancy_rate_percent': occupancy_rate,
            'estimated_monthly_revenue': monthly_revenue,
        })

    @action(detail=True, methods=['get'], url_path='room_matrix')
    def room_matrix(self, request, pk=None):
        property_obj = self.get_object()
        rooms = property_obj.rooms.all().order_by('floor', 'room_number')
        total_rooms = rooms.count()
        status_summary = {
            'AVAILABLE': rooms.filter(status=RoomStatus.AVAILABLE).count(),
            'OCCUPIED': rooms.filter(status=RoomStatus.OCCUPIED).count(),
            'FULL': rooms.filter(status=RoomStatus.FULL).count(),
            'MAINTENANCE': rooms.filter(status=RoomStatus.MAINTENANCE).count(),
            'INACTIVE': rooms.filter(status=RoomStatus.INACTIVE).count(),
        }

        matrix_by_floor = {}
        for room in rooms:
            floor_key = f"Tầng {room.floor}"
            matrix_by_floor.setdefault(floor_key, []).append(RoomSerializer(room).data)

        floors_list = [
            {
                'floor_name': floor_name,
                'rooms_count': len(matrix_by_floor[floor_name]),
                'rooms': matrix_by_floor[floor_name],
            }
            for floor_name in sorted(matrix_by_floor.keys(), key=lambda x: int(x.replace('Tầng ', '')))
        ]

        return Response({
            'property_id': property_obj.id,
            'property_code': property_obj.code,
            'property_name': property_obj.name,
            'total_floors': property_obj.total_floors,
            'total_rooms': total_rooms,
            'status_summary': status_summary,
            'floors': floors_list,
        })


# ==============================================================================
# II, III, IV, V, VI. MODULE ROOM — QUẢN LÝ PHÒNG, TRẠNG THÁI, TÌM KIẾM, LỌC, SẮP XẾP
# ==============================================================================
class RoomViewSet(viewsets.ModelViewSet):
    """
    II. MODULE ROOM — QUẢN LÝ PHÒNG TRỌ
    III. QUẢN LÝ TRẠNG THÁI PHÒNG (AVAILABLE, OCCUPIED, FULL, MAINTENANCE, INACTIVE)
    IV. TÌM KIẾM PHÒNG (Tên phòng, Mã phòng, Tên nhà trọ, Khu vực, Địa chỉ)
    V. LỌC PHÒNG (Giá phòng, Diện tích, Số người tối đa, Trạng thái, Vị trí/Khu vực)
    VI. SẮP XẾP DANH SÁCH PHÒNG (Giá tăng/giảm, Diện tích tăng/giảm, Tên phòng, Ngày tạo)
    """
    serializer_class = RoomSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        queryset = Room.objects.select_related('property').prefetch_related('maintenance_requests').all()

        if hasattr(user, 'role') and user.role == 'LANDLORD' and not getattr(user, 'is_superuser', False):
            queryset = queryset.filter(property__owner_id=user.id)

        p = self.request.query_params

        # V.5 Lọc theo nhà trọ & vị trí / khu vực
        property_id = p.get('property_id') or p.get('property')
        if property_id and property_id != 'ALL':
            queryset = queryset.filter(property_id=property_id)

        district = p.get('district')
        if district and district != 'ALL':
            queryset = queryset.filter(property__district__icontains=district.strip())

        ward = p.get('ward')
        if ward and ward != 'ALL':
            queryset = queryset.filter(property__ward__icontains=ward.strip())

        address = p.get('address')
        if address:
            queryset = queryset.filter(property__address__icontains=address.strip())

        floor_param = p.get('floor')
        if floor_param and floor_param != 'ALL':
            queryset = queryset.filter(floor=floor_param)

        # V.4 Lọc theo trạng thái phòng
        status_param = p.get('status')
        if status_param and status_param != 'ALL':
            queryset = queryset.filter(status=status_param.upper())

        # V.1 Lọc theo khoảng giá phòng (VD: min_price=2000000&max_price=4000000)
        min_price = p.get('min_price')
        if min_price:
            try:
                queryset = queryset.filter(rent_price__gte=float(min_price))
            except ValueError:
                pass
        max_price = p.get('max_price')
        if max_price:
            try:
                queryset = queryset.filter(rent_price__lte=float(max_price))
            except ValueError:
                pass

        # V.2 Lọc theo khoảng diện tích (VD: min_area=15&max_area=30)
        min_area = p.get('min_area')
        if min_area:
            try:
                queryset = queryset.filter(area__gte=float(min_area))
            except ValueError:
                pass
        max_area = p.get('max_area')
        if max_area:
            try:
                queryset = queryset.filter(area__lte=float(max_area))
            except ValueError:
                pass

        # V.3 Lọc theo số người tối đa (VD: max_occupants=2)
        max_occupants = p.get('max_occupants')
        if max_occupants and max_occupants != 'ALL':
            try:
                queryset = queryset.filter(max_occupants=int(max_occupants))
            except ValueError:
                pass

        # IV. Tìm kiếm phòng (Tên phòng, Mã phòng, Tên nhà trọ, Khu vực, Địa chỉ)
        search = p.get('search')
        if search:
            q = search.strip()
            queryset = queryset.filter(
                Q(room_number__icontains=q)
                | Q(code__icontains=q)
                | Q(property__name__icontains=q)
                | Q(property__code__icontains=q)
                | Q(property__district__icontains=q)
                | Q(property__ward__icontains=q)
                | Q(property__address__icontains=q)
                | Q(tenant_name__icontains=q)
            )

        # VI. Sắp xếp danh sách phòng
        sort_by = p.get('sort') or p.get('ordering') or ''
        sort_map = {
            'price_asc': ('rent_price', 'room_number'),
            'price_desc': ('-rent_price', 'room_number'),
            'area_asc': ('area', 'room_number'),
            'area_desc': ('-area', 'room_number'),
            'name_asc': ('room_number',),
            'name_desc': ('-room_number',),
            'created_desc': ('-created_at',),
            'created_asc': ('created_at',),
        }
        if sort_by in sort_map:
            queryset = queryset.order_by(*sort_map[sort_by])
        else:
            queryset = queryset.order_by('property_id', 'floor', 'room_number')

        return queryset

    def destroy(self, request, *args, **kwargs):
        """
        2.5 Xóa / ngừng sử dụng phòng:
        Hạn chế xóa cứng nếu phòng đang thuê hoặc đã có lịch sử bảo trì -> chuyển sang INACTIVE.
        """
        room = self.get_object()
        if room.status in [RoomStatus.OCCUPIED, RoomStatus.FULL] or room.current_occupants > 0:
            return Response(
                {'error': f'Phòng {room.room_number} đang có người thuê, không thể xóa.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if room.maintenance_requests.exists():
            room.status = RoomStatus.INACTIVE
            room.save(update_fields=['status', 'updated_at'])
            return Response({
                'message': f'Phòng {room.room_number} đã có lịch sử bảo trì nên được chuyển sang trạng thái '
                           f'INACTIVE (Ngừng hoạt động) để bảo toàn dữ liệu.',
                'soft_deleted': True,
                'room': RoomSerializer(room).data,
            })

        room_num = room.room_number
        room.delete()
        return Response({'message': f'Đã xóa phòng {room_num} thành công.', 'soft_deleted': False})

    # --- III. QUẢN LÝ TRẠNG THÁI PHÒNG (3.1 -> 3.6) ---------------------------
    @action(detail=True, methods=['get', 'patch', 'post'], url_path='status')
    def update_status(self, request, pk=None):
        """
        3.1 Xem trạng thái phòng (GET /api/v1/rooms/{id}/status/)
        3.2 Cập nhật trạng thái phòng (PATCH/POST /api/v1/rooms/{id}/status/)
        """
        room = self.get_object()
        if request.method == 'GET':
            can_rent, reason = room.check_rentability()
            return Response({
                'room_id': room.id,
                'code': room.code,
                'room_number': room.room_number,
                'status': room.status,
                'status_display': room.get_status_display(),
                'current_occupants': room.current_occupants,
                'max_occupants': room.max_occupants,
                'is_rentable': can_rent,
                'rentability_reason': reason,
            })

        new_status = (request.data.get('status') or '').upper()
        if new_status not in RoomStatus.values:
            return Response(
                {'error': f'Trạng thái không hợp lệ. Chọn một trong: {RoomStatus.values}'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        occupants = request.data.get('current_occupants')
        tenant_name = request.data.get('tenant_name')
        tenant_phone = request.data.get('tenant_phone')

        if occupants is not None:
            try:
                room.current_occupants = max(0, int(occupants))
            except ValueError:
                pass

        if new_status == RoomStatus.AVAILABLE:
            room.current_occupants = 0
            room.tenant_name = ''
            room.tenant_phone = ''
        elif new_status == RoomStatus.FULL:
            room.current_occupants = room.max_occupants
        elif new_status == RoomStatus.OCCUPIED:
            if room.current_occupants <= 0:
                room.current_occupants = 1
            if room.current_occupants >= room.max_occupants:
                new_status = RoomStatus.FULL

        if tenant_name is not None:
            room.tenant_name = tenant_name
        if tenant_phone is not None:
            room.tenant_phone = tenant_phone

        room.status = new_status
        room.save()
        return Response({
            'message': f'Đã cập nhật trạng thái phòng {room.room_number} sang "{room.get_status_display()}".',
            'room': RoomSerializer(room).data,
        })

    @action(detail=True, methods=['get'], url_path='check_rentable')
    def check_rentable(self, request, pk=None):
        """3.3 Kiểm tra phòng có thể thuê hay không."""
        room = self.get_object()
        can_rent, reason = room.check_rentability()
        return Response({
            'room_id': room.id,
            'code': room.code,
            'room_number': room.room_number,
            'property_name': room.property.name,
            'status': room.status,
            'status_display': room.get_status_display(),
            'can_rent': can_rent,
            'reason': reason,
            'rent_price': room.rent_price,
            'area': room.area,
            'max_occupants': room.max_occupants,
            'current_occupants': room.current_occupants,
        })

    @action(detail=False, methods=['get'], url_path='available')
    def available_rooms(self, request):
        """3.4 Hiển thị danh sách phòng trống (AVAILABLE)."""
        qs = self.get_queryset().filter(status=RoomStatus.AVAILABLE)
        return Response(RoomSerializer(qs, many=True).data)

    @action(detail=False, methods=['get'], url_path='occupied')
    def occupied_rooms(self, request):
        """3.5 Hiển thị danh sách phòng đang được thuê (OCCUPIED & FULL)."""
        qs = self.get_queryset().filter(status__in=[RoomStatus.OCCUPIED, RoomStatus.FULL])
        return Response(RoomSerializer(qs, many=True).data)

    @action(detail=False, methods=['get'], url_path='maintenance')
    def maintenance_rooms(self, request):
        """3.6 Hiển thị danh sách phòng đang bảo trì (MAINTENANCE)."""
        qs = self.get_queryset().filter(status=RoomStatus.MAINTENANCE)
        return Response(RoomSerializer(qs, many=True).data)


# ==============================================================================
# VII. MODULE MAINTENANCE — QUẢN LÝ BẢO TRÌ / SỬA CHỮA
# ==============================================================================
class MaintenanceRequestViewSet(viewsets.ModelViewSet):
    """
    VII. MODULE MAINTENANCE — QUẢN LÝ BẢO TRÌ:
    7.1 Tạo yêu cầu bảo trì (POST /api/v1/maintenance/)
    7.2 Xem danh sách yêu cầu bảo trì (GET /api/v1/maintenance/)
    7.3 Xem chi tiết yêu cầu bảo trì (GET /api/v1/maintenance/{id}/)
    7.4 Cập nhật yêu cầu bảo trì (PUT/PATCH /api/v1/maintenance/{id}/)
    7.5 Cập nhật trạng thái bảo trì (POST /api/v1/maintenance/{id}/update_status/)
    7.6 Ghi nhận chi phí bảo trì (POST /api/v1/maintenance/{id}/record_cost/)
    7.7 Hoàn thành bảo trì (POST /api/v1/maintenance/{id}/complete/)
    7.8 Xem lịch sử bảo trì (GET /api/v1/maintenance/{id}/history/ & /api/v1/maintenance-history/)
    """
    serializer_class = MaintenanceRequestSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        queryset = MaintenanceRequest.objects.select_related('room', 'room__property').prefetch_related('histories').all()
        p = self.request.query_params

        room_id = p.get('room_id') or p.get('room')
        if room_id and room_id != 'ALL':
            queryset = queryset.filter(room_id=room_id)

        property_id = p.get('property_id') or p.get('property')
        if property_id and property_id != 'ALL':
            queryset = queryset.filter(room__property_id=property_id)

        status_param = p.get('status')
        if status_param and status_param != 'ALL':
            queryset = queryset.filter(status=status_param.upper())

        priority = p.get('priority')
        if priority and priority != 'ALL':
            queryset = queryset.filter(priority=priority.upper())

        search = p.get('search')
        if search:
            q = search.strip()
            queryset = queryset.filter(
                Q(code__icontains=q)
                | Q(title__icontains=q)
                | Q(description__icontains=q)
                | Q(room__room_number__icontains=q)
                | Q(room__code__icontains=q)
                | Q(room__property__name__icontains=q)
            )

        return queryset

    def perform_create(self, serializer):
        """7.1 Tạo yêu cầu bảo trì + Tự động ghi lịch sử & chuyển phòng sang MAINTENANCE nếu cần."""
        req = serializer.save()
        set_room_maint = self.request.data.get('set_room_maintenance', True)
        if str(set_room_maint).lower() not in ('false', '0', 'no'):
            room = req.room
            if room.status != RoomStatus.MAINTENANCE:
                room.status = RoomStatus.MAINTENANCE
                room.save(update_fields=['status', 'updated_at'])

        MaintenanceHistory.objects.create(
            maintenance_request=req,
            room=req.room,
            action='Tạo yêu cầu bảo trì mới',
            previous_status='',
            new_status=req.status,
            cost=req.estimated_cost or 0,
            repair_content=req.description or req.title,
            performed_by=_actor_name(self.request.user),
        )

    def perform_update(self, serializer):
        """7.4 Cập nhật thông tin yêu cầu bảo trì."""
        old_status = self.get_object().status
        req = serializer.save()
        MaintenanceHistory.objects.create(
            maintenance_request=req,
            room=req.room,
            action='Cập nhật thông tin yêu cầu bảo trì',
            previous_status=old_status,
            new_status=req.status,
            cost=req.actual_cost or req.estimated_cost or 0,
            repair_content=req.repair_info or req.description,
            performed_by=_actor_name(self.request.user),
        )

    @action(detail=True, methods=['post', 'patch'], url_path='update_status')
    def update_status(self, request, pk=None):
        """
        7.5 Cập nhật trạng thái bảo trì: PENDING -> IN_PROGRESS -> COMPLETED (hoặc CANCELLED).
        """
        req = self.get_object()
        new_status = (request.data.get('status') or '').upper()
        if new_status not in MaintenanceStatus.values:
            return Response(
                {'error': f'Trạng thái không hợp lệ. Chọn một trong: {MaintenanceStatus.values}'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        old_status = req.status
        req.status = new_status
        repair_info = request.data.get('repair_info')
        if repair_info is not None:
            req.repair_info = repair_info
        technician = request.data.get('technician_name')
        if technician is not None:
            req.technician_name = technician

        if new_status == MaintenanceStatus.IN_PROGRESS:
            if req.room.status != RoomStatus.MAINTENANCE:
                req.room.status = RoomStatus.MAINTENANCE
                req.room.save(update_fields=['status', 'updated_at'])
        elif new_status == MaintenanceStatus.COMPLETED:
            req.completed_date = timezone.localdate()
            if req.room.status == RoomStatus.MAINTENANCE:
                req.room.status = RoomStatus.AVAILABLE if req.room.current_occupants == 0 else RoomStatus.OCCUPIED
                req.room.save(update_fields=['status', 'updated_at'])
        elif new_status == MaintenanceStatus.CANCELLED:
            if req.room.status == RoomStatus.MAINTENANCE:
                req.room.status = RoomStatus.AVAILABLE if req.room.current_occupants == 0 else RoomStatus.OCCUPIED
                req.room.save(update_fields=['status', 'updated_at'])

        req.save()
        MaintenanceHistory.objects.create(
            maintenance_request=req,
            room=req.room,
            action=f'Đổi trạng thái: {old_status} → {new_status}',
            previous_status=old_status,
            new_status=new_status,
            cost=req.actual_cost or req.estimated_cost or 0,
            repair_content=req.repair_info or f'Chuyển trạng thái sang {req.get_status_display()}',
            performed_by=_actor_name(request.user),
        )
        return Response({
            'message': f'Đã cập nhật trạng thái yêu cầu {req.code} sang {req.get_status_display()}.',
            'maintenance_request': MaintenanceRequestSerializer(req).data,
        })

    @action(detail=True, methods=['post'], url_path='record_cost')
    def record_cost(self, request, pk=None):
        """
        7.6 Ghi nhận chi phí bảo trì (Chi phí dự kiến & Chi phí thực tế).
        """
        req = self.get_object()
        estimated_cost = request.data.get('estimated_cost')
        actual_cost = request.data.get('actual_cost')
        note = request.data.get('repair_info') or request.data.get('note') or ''

        if estimated_cost is not None and estimated_cost != '':
            req.estimated_cost = float(estimated_cost)
        if actual_cost is not None and actual_cost != '':
            req.actual_cost = float(actual_cost)
        if note:
            req.repair_info = note
        req.save()

        MaintenanceHistory.objects.create(
            maintenance_request=req,
            room=req.room,
            action='Ghi nhận chi phí bảo trì',
            previous_status=req.status,
            new_status=req.status,
            cost=req.actual_cost or req.estimated_cost or 0,
            repair_content=f'Chi phí dự kiến: {req.estimated_cost:,.0f} VNĐ | Chi phí thực tế: {req.actual_cost:,.0f} VNĐ. {note}'.strip(),
            performed_by=_actor_name(request.user),
        )
        return Response({
            'message': f'Đã ghi nhận chi phí cho yêu cầu {req.code}.',
            'maintenance_request': MaintenanceRequestSerializer(req).data,
        })

    @action(detail=True, methods=['post'], url_path='complete')
    def complete(self, request, pk=None):
        """
        7.7 Hoàn thành bảo trì:
        - Maintenance Status: IN_PROGRESS -> COMPLETED
        - Room Status: MAINTENANCE -> AVAILABLE (hoặc OCCUPIED nếu đang có khách)
        """
        req = self.get_object()
        old_status = req.status
        actual_cost = request.data.get('actual_cost')
        repair_info = request.data.get('repair_info', '')
        new_room_status = (request.data.get('room_status') or RoomStatus.AVAILABLE).upper()

        if actual_cost is not None and actual_cost != '':
            req.actual_cost = float(actual_cost)
        if repair_info:
            req.repair_info = repair_info

        req.status = MaintenanceStatus.COMPLETED
        req.completed_date = timezone.localdate()
        req.save()

        room = req.room
        old_room_status = room.status
        if new_room_status in RoomStatus.values:
            room.status = new_room_status
            room.save(update_fields=['status', 'updated_at'])

        MaintenanceHistory.objects.create(
            maintenance_request=req,
            room=room,
            action='Hoàn thành bảo trì & Bàn giao lại phòng',
            previous_status=old_status,
            new_status=MaintenanceStatus.COMPLETED,
            cost=req.actual_cost or req.estimated_cost or 0,
            repair_content=(
                f'{repair_info or "Đã sửa chữa hoàn tất."} '
                f'(Phòng {room.room_number}: {old_room_status} → {room.status})'
            ),
            performed_by=_actor_name(request.user),
        )
        return Response({
            'message': f'Đã hoàn thành bảo trì {req.code}. Phòng {room.room_number} đã chuyển sang {room.get_status_display()}.',
            'maintenance_request': MaintenanceRequestSerializer(req).data,
        })

    @action(detail=True, methods=['get'], url_path='history')
    def history(self, request, pk=None):
        """7.8 Xem lịch sử của 1 yêu cầu bảo trì."""
        req = self.get_object()
        return Response(MaintenanceHistorySerializer(req.histories.all(), many=True).data)


class MaintenanceHistoryViewSet(viewsets.ReadOnlyModelViewSet):
    """
    7.8 Xem toàn bộ lịch sử bảo trì (theo dõi các lần sửa chữa, ngày sửa chữa, chi phí, trạng thái, nội dung).
    """
    serializer_class = MaintenanceHistorySerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        qs = MaintenanceHistory.objects.select_related('maintenance_request', 'room', 'room__property').all()
        room_id = self.request.query_params.get('room_id') or self.request.query_params.get('room')
        if room_id and room_id != 'ALL':
            qs = qs.filter(room_id=room_id)
        property_id = self.request.query_params.get('property_id') or self.request.query_params.get('property')
        if property_id and property_id != 'ALL':
            qs = qs.filter(room__property_id=property_id)
        return qs
