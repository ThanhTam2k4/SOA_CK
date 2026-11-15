from django.db.models import Q
from rest_framework import permissions, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

from common.auth import IsManagerRole, get_user_id, is_admin_or_staff, is_landlord
from .models import TenantProfile, TenantStatus
from .serializers import RentalHistorySerializer, TenantProfileSerializer


def scoped_tenants(user):
    """
    - ADMIN / STAFF : toàn bộ
    - LANDLORD      : người thuê do mình quản lý (landlord_id)
    - TENANT        : chỉ hồ sơ gắn với tài khoản của mình (user_id)
    """
    queryset = TenantProfile.objects.all()
    if is_admin_or_staff(user):
        return queryset
    if is_landlord(user):
        return queryset.filter(landlord_id=get_user_id(user))
    return queryset.filter(user_id=get_user_id(user))


class TenantProfileViewSet(viewsets.ModelViewSet):
    """
    SERVICE 3 — TENANT SERVICE
    - CRUD hồ sơ người thuê (quản lý: ADMIN/STAFF/LANDLORD; TENANT chỉ xem hồ sơ của mình)
    - Lọc: ?search= (tên/SĐT/CCCD), ?status=, ?room_id=
    - GET/POST /{id}/history/  lịch sử thuê
    - GET /summary/            thống kê (Dashboard qua Gateway)
    """
    serializer_class = TenantProfileSerializer

    def get_permissions(self):
        if self.action in ('list', 'retrieve', 'summary') or (
                self.action == 'history' and self.request.method == 'GET'):
            return [permissions.IsAuthenticated()]
        return [permissions.IsAuthenticated(), IsManagerRole()]

    def get_queryset(self):
        queryset = scoped_tenants(self.request.user)
        params = self.request.query_params
        search = params.get('search')
        if search:
            queryset = queryset.filter(
                Q(full_name__icontains=search) | Q(phone_number__icontains=search) |
                Q(identity_card__icontains=search))
        if params.get('status') and params['status'] != 'ALL':
            queryset = queryset.filter(status=params['status'])
        if params.get('room_id'):
            queryset = queryset.filter(room_id=params['room_id'])
        return queryset

    def perform_create(self, serializer):
        serializer.save(landlord_id=get_user_id(self.request.user))

    @action(detail=True, methods=['get', 'post'])
    def history(self, request, pk=None):
        tenant = self.get_object()
        if request.method == 'GET':
            return Response(RentalHistorySerializer(tenant.rental_history.all(), many=True).data)
        serializer = RentalHistorySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save(tenant=tenant)
        return Response(serializer.data, status=201)

    @action(detail=False, methods=['get'])
    def summary(self, request):
        queryset = scoped_tenants(request.user)
        return Response({
            'total_tenants': queryset.count(),
            'active_tenants': queryset.filter(status=TenantStatus.ACTIVE).count(),
            'moved_out_tenants': queryset.filter(status=TenantStatus.MOVED_OUT).count(),
        })
