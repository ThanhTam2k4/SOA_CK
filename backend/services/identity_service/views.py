from rest_framework import generics, viewsets, permissions, status
from rest_framework.response import Response
from rest_framework_simplejwt.views import TokenObtainPairView
from django.contrib.auth import get_user_model
from .models import UserRole
from .serializers import (
    UserSerializer,
    RegisterSerializer,
    CustomTokenObtainPairSerializer,
)
from .permissions import IsAdminUserRole, IsLandlordOrAdmin

User = get_user_model()

class CustomLoginView(TokenObtainPairView):
    """
    SERVICE 1 — IDENTITY: Đăng nhập hệ thống trả về JWT Token và thông tin phân quyền
    """
    serializer_class = CustomTokenObtainPairSerializer

class RegisterView(generics.CreateAPIView):
    """
    SERVICE 1 — IDENTITY: Đăng ký tài khoản (mặc định là LANDLORD)
    """
    queryset = User.objects.all()
    serializer_class = RegisterSerializer
    permission_classes = [permissions.AllowAny]

class CurrentUserView(generics.RetrieveUpdateAPIView):
    """
    SERVICE 1 — IDENTITY: Lấy & cập nhật thông tin cá nhân của người dùng hiện tại
    """
    serializer_class = UserSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        if isinstance(self.request.user, User):
            return self.request.user
        return User.objects.get(pk=self.request.user.id)

class UserViewSet(viewsets.ModelViewSet):
    """
    SERVICE 1 — IDENTITY: Quản lý danh sách người dùng và phân quyền (ADMIN / LANDLORD)
    """
    serializer_class = UserSerializer
    permission_classes = [IsLandlordOrAdmin]

    def get_queryset(self):
        user = self.request.user
        role_filter = self.request.query_params.get('role')
        queryset = User.objects.all()

        if role_filter:
            queryset = queryset.filter(role=role_filter)

        # Nếu là Landlord thông thường, chỉ xem danh sách khách thuê (TENANT) hoặc chính mình
        if user.role == UserRole.LANDLORD and not user.is_superuser:
            queryset = queryset.filter(role=UserRole.TENANT) | User.objects.filter(id=user.id)

        return queryset


class TestAccountsView(generics.GenericAPIView):
    """
    SPRINT 1: Cung cấp danh sách tài khoản mẫu để kiểm thử đăng nhập nhanh (Test Login)
    """
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        return Response({
            'message': 'Danh sách tài khoản kiểm thử hệ thống SOA',
            'test_accounts': [
                {'username': 'chutro1', 'password': 'chutropassword123', 'role': 'LANDLORD', 'name': 'Chủ trọ Nguyễn Văn An'},
                {'username': 'admin', 'password': 'adminpassword123', 'role': 'ADMIN', 'name': 'Quản trị viên Hệ thống'},
                {'username': 'khach1', 'password': 'khachpassword123', 'role': 'TENANT', 'name': 'Khách thuê Trần Thị Mai'},
            ]
        })

