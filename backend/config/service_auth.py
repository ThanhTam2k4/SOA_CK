"""
Stateless JWT Authentication cho kiến trúc SOA Microservices.
- Identity Service (Port 8001) cấp JWT chứa sẵn claims: user_id, username, role, full_name.
- Các Service khác (Port 8002 -> 8005) xác thực JWT thông qua SECRET_KEY chung mà không cần
  truy vấn chéo sang database nhatro_identity_db.
"""
from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework_simplejwt.models import TokenUser


class StatelessServiceUser(TokenUser):
    """Đối tượng User được khôi phục trực tiếp từ JWT payload (Stateless)."""

    @property
    def role(self):
        return self.token.get('role', 'LANDLORD')

    @property
    def full_name(self):
        return self.token.get('full_name') or self.token.get('username', '')

    @property
    def is_superuser(self):
        return bool(self.token.get('is_superuser', False)) or self.role == 'ADMIN'

    @property
    def is_staff(self):
        return self.is_superuser


class StatelessJWTAuthentication(JWTAuthentication):
    """
    Nếu token có sẵn claim 'role', dựng StatelessServiceUser ngay từ token (không gọi DB).
    Nếu chưa có, fallback về get_user() mặc định.
    """
    def get_user(self, validated_token):
        if 'role' in validated_token:
            return StatelessServiceUser(validated_token)
        return super().get_user(validated_token)

