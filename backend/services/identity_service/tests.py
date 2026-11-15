from django.test import TestCase
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from rest_framework import status
from rest_framework_simplejwt.tokens import AccessToken
from services.identity_service.models import UserRole

User = get_user_model()

class IdentityServiceTests(TestCase):
    databases = {'default'}

    def setUp(self):
        self.client = APIClient()
        self.landlord = User.objects.create_user(
            username='testlandlord',
            password='testpassword123',
            email='landlord@test.com',
            role=UserRole.LANDLORD,
            first_name='An',
            last_name='Nguyen'
        )

    def test_login_success(self):
        """SPRINT 1: Test Login API & JWT Authentication"""
        response = self.client.post('/api/auth/login/', {
            'username': 'testlandlord',
            'password': 'testpassword123'
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('access', response.data)
        self.assertIn('refresh', response.data)
        self.assertIn('user', response.data)
        self.assertEqual(response.data['user']['role'], UserRole.LANDLORD)

    def test_login_invalid_credentials(self):
        """SPRINT 1: Test Login thất bại khi sai mật khẩu"""
        response = self.client.post('/api/auth/login/', {
            'username': 'testlandlord',
            'password': 'wrongpassword'
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_role_authorization_and_me(self):
        """SPRINT 1: Test Role Authorization & Me endpoint"""
        self.client.force_authenticate(user=self.landlord)
        response = self.client.get('/api/auth/me/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['username'], 'testlandlord')
        self.assertEqual(response.data['role'], UserRole.LANDLORD)

    def _login(self):
        return self.client.post('/api/auth/login/', {
            'username': 'testlandlord', 'password': 'testpassword123'}, format='json').data

    def test_jwt_contains_role_claims_for_stateless_services(self):
        """Token phải mang role để service khác phân quyền không cần DB Identity"""
        token = AccessToken(self._login()['access'])
        self.assertEqual(token['role'], UserRole.LANDLORD)
        self.assertEqual(token['username'], 'testlandlord')
        self.assertFalse(token['is_superuser'])

    def test_logout_blacklists_refresh_token(self):
        data = self._login()
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {data['access']}")
        res = self.client.post('/api/auth/logout/', {'refresh': data['refresh']}, format='json')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        res = self.client.post('/api/auth/refresh/', {'refresh': data['refresh']}, format='json')
        self.assertEqual(res.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_change_password(self):
        self.client.force_authenticate(user=self.landlord)
        res = self.client.post('/api/auth/change-password/', {
            'old_password': 'wrong', 'new_password': 'newpass123'}, format='json')
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        res = self.client.post('/api/auth/change-password/', {
            'old_password': 'testpassword123', 'new_password': 'newpass123'}, format='json')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.landlord.refresh_from_db()
        self.assertTrue(self.landlord.check_password('newpass123'))

    def test_public_register_cannot_create_admin(self):
        res = self.client.post('/api/auth/register/', {
            'username': 'hacker', 'password': 'abcdef12', 'role': UserRole.ADMIN}, format='json')
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)

    def test_health(self):
        res = self.client.get('/health/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data['status'], 'UP')
        self.assertEqual(res.data['port'], 8001)
