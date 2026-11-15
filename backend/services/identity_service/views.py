from rest_framework import generics, viewsets, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.views import TokenObtainPairView
from django.contrib.auth import get_user_model
from .models import UserRole
from .serializers import (
    UserSerializer,
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
    SERVICE 1 — IDENTITY: Lấy & cập nhật thông tin cá nhân của người dùng hiện tại
    """
    serializer_class = UserSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        return self.request.user

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
        request.user.set_password(serializer.validated_data['new_password'])
        request.user.save(update_fields=['password'])
        return Response({'detail': 'Đổi mật khẩu thành công.'}, status=status.HTTP_200_OK)


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

