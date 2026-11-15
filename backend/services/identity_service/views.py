from rest_framework import generics, viewsets, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.views import TokenObtainPairView
from django.conf import settings
from django.contrib.auth import get_user_model
from django.http import Http404
from .models import UserRole
from .serializers import (
    UserSerializer,
    ProfileSerializer,
    RegisterSerializer,
    CustomTokenObtainPairSerializer,
    ChangePasswordSerializer,
    LogoutSerializer,
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
    SERVICE 1 — IDENTITY: Lấy & cập nhật thông tin cá nhân của người dùng hiện tại.
    Dùng ProfileSerializer: không cho tự đổi role / is_active / username.
    """
    serializer_class = ProfileSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        if isinstance(self.request.user, User):
            return self.request.user
        return User.objects.get(pk=self.request.user.id)

class LogoutView(APIView):
    """
    SERVICE 1 — IDENTITY: Đăng xuất — thu hồi (blacklist) refresh token.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = LogoutSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            token = RefreshToken(serializer.validated_data['refresh'])
            if str(token.get('user_id')) != str(request.user.id):
                return Response({'error': 'Refresh token không thuộc về người dùng hiện tại.'},
                                status=status.HTTP_400_BAD_REQUEST)
            token.blacklist()
        except TokenError as exc:
            return Response({'error': str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        return Response({'detail': 'Đăng xuất thành công.'}, status=status.HTTP_200_OK)


class ChangePasswordView(APIView):
    """
    SERVICE 1 — IDENTITY: Đổi mật khẩu người dùng hiện tại.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = ChangePasswordSerializer(data=request.data, context={'request': request})
        serializer.is_valid(raise_exception=True)
        user = request.user if isinstance(request.user, User) else User.objects.get(pk=request.user.id)
        user.set_password(serializer.validated_data['new_password'])
        user.save(update_fields=['password'])
        return Response({'detail': 'Đổi mật khẩu thành công.'}, status=status.HTTP_200_OK)


class UserViewSet(viewsets.ModelViewSet):
    """
    SERVICE 1 — IDENTITY: Quản lý danh sách người dùng và phân quyền (ADMIN / LANDLORD)
    - ADMIN    : toàn quyền (tạo/sửa/xóa, đổi role, khóa tài khoản)
    - LANDLORD : xem danh sách TENANT + chính mình, tạo tài khoản TENANT, sửa thông tin
                 liên hệ của TENANT; không được đổi role/is_active, không được xóa.
    """
    serializer_class = UserSerializer
    permission_classes = [IsLandlordOrAdmin]

    def get_permissions(self):
        if self.action == 'destroy':
            return [IsAdminUserRole()]
        return super().get_permissions()

    def perform_destroy(self, instance):
        if instance.pk == self.request.user.pk:
            from rest_framework.exceptions import ValidationError
            raise ValidationError({'detail': 'Không thể tự xóa tài khoản của chính mình.'})
        instance.delete()

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
    DEV ONLY: danh sách tài khoản mẫu (do seed_data.py tạo) để đăng nhập nhanh khi phát triển.
    - Chỉ bật khi DEBUG=True (hoặc EXPOSE_TEST_ACCOUNTS=True); production trả 404.
    - Không bao giờ công bố tài khoản ADMIN.
    """
    permission_classes = [permissions.AllowAny]
    authentication_classes = []

    def get(self, request):
        if not getattr(settings, 'EXPOSE_TEST_ACCOUNTS', settings.DEBUG):
            raise Http404
        return Response({
            'message': 'Tài khoản mẫu cho môi trường phát triển (seed_data.py). Không dùng ở production.',
            'test_accounts': [
                {'username': 'chutro1', 'password': 'chutropassword123', 'role': 'LANDLORD', 'name': 'Chủ trọ Nguyễn Văn An'},
                {'username': 'khach1', 'password': 'khachpassword123', 'role': 'TENANT', 'name': 'Khách thuê Trần Thị Mai'},
            ]
        })

