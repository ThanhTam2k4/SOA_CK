from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from django.contrib.auth import get_user_model
from .models import UserRole

User = get_user_model()

class UserSerializer(serializers.ModelSerializer):
    role_display = serializers.CharField(source='get_role_display', read_only=True)
    full_name = serializers.CharField(read_only=True)

    class Meta:
        model = User
        fields = [
            'id',
            'username',
            'email',
            'first_name',
            'last_name',
            'full_name',
            'role',
            'role_display',
            'phone_number',
            'identity_card',
            'address',
            'avatar_url',
            'is_active',
            'created_at',
            'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']

class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=6)

    class Meta:
        model = User
        fields = [
            'username',
            'password',
            'email',
            'first_name',
            'last_name',
            'role',
            'phone_number',
            'identity_card',
            'address',
        ]

    # Đăng ký công khai không được tự cấp quyền ADMIN/STAFF.
    PUBLIC_ROLES = (UserRole.LANDLORD, UserRole.TENANT)

    def validate_role(self, value):
        if value and value not in self.PUBLIC_ROLES:
            raise serializers.ValidationError('Chỉ được đăng ký vai trò LANDLORD hoặc TENANT.')
        return value

    def create(self, validated_data):
        password = validated_data.pop('password')
        # Mặc định người dùng đăng ký ngoài là LANDLORD nếu không chọn
        if 'role' not in validated_data or not validated_data['role']:
            validated_data['role'] = UserRole.LANDLORD

        user = User(**validated_data)
        user.set_password(password)
        user.save()
        return user

class CustomTokenObtainPairSerializer(TokenObtainPairSerializer):
    """
    Kèm thông tin User và Phân quyền trực tiếp trong response Login.
    Đồng thời nhúng claims (username, role, is_superuser) vào JWT để các service
    khác xác thực STATELESS mà không cần truy cập database của Identity Service.
    """
    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)
        token['username'] = user.username
        token['role'] = user.role
        token['is_superuser'] = user.is_superuser
        token['is_staff'] = user.is_staff
        token['full_name'] = user.full_name
        return token

    def validate(self, attrs):
        data = super().validate(attrs)
        user = self.user
        data['user'] = {
            'id': user.id,
            'username': user.username,
            'email': user.email,
            'full_name': user.full_name,
            'first_name': user.first_name,
            'last_name': user.last_name,
            'role': user.role,
            'role_display': user.get_role_display(),
            'phone_number': user.phone_number,
            'identity_card': user.identity_card,
            'address': user.address,
            'avatar_url': user.avatar_url,
        }
        return data



class ChangePasswordSerializer(serializers.Serializer):
    old_password = serializers.CharField(write_only=True)
    new_password = serializers.CharField(write_only=True, min_length=6)

    def validate_old_password(self, value):
        user = self.context['request'].user
        if not user.check_password(value):
            raise serializers.ValidationError('Mật khẩu hiện tại không đúng.')
        return value

    def validate(self, attrs):
        if attrs['old_password'] == attrs['new_password']:
            raise serializers.ValidationError({'new_password': 'Mật khẩu mới phải khác mật khẩu hiện tại.'})
        return attrs


class LogoutSerializer(serializers.Serializer):
    refresh = serializers.CharField()
