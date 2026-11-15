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


class IdentityPermissionPolicyTests(TestCase):
    """Chống leo quyền: role / is_active chỉ ADMIN được thay đổi."""
    databases = {'default'}

    def setUp(self):
        self.admin = User.objects.create_user(username='admin_t', password='adminpass123', role=UserRole.ADMIN)
        self.landlord = User.objects.create_user(username='landlord_t', password='landlordpass123',
                                                 role=UserRole.LANDLORD)
        self.tenant = User.objects.create_user(username='tenant_t', password='tenantpass123', role=UserRole.TENANT)
        self.client = APIClient()

    def as_user(self, user):
        self.client.force_authenticate(user=user)
        return self.client

    def test_user_cannot_escalate_own_role_or_activate_flag_via_me(self):
        client = self.as_user(self.tenant)
        res = client.patch('/api/auth/me/', {'role': UserRole.ADMIN, 'is_active': False,
                                             'username': 'renamed', 'phone_number': '0909'}, format='json')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.tenant.refresh_from_db()
        self.assertEqual(self.tenant.role, UserRole.TENANT)
        self.assertTrue(self.tenant.is_active)
        self.assertEqual(self.tenant.username, 'tenant_t')
        self.assertEqual(self.tenant.phone_number, '0909')

    def test_tenant_cannot_access_user_management(self):
        client = self.as_user(self.tenant)
        self.assertEqual(client.get('/api/users/').status_code, status.HTTP_403_FORBIDDEN)
        res = client.post('/api/users/', {'username': 'x', 'password': 'abcdef12', 'role': UserRole.ADMIN},
                          format='json')
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

    def test_landlord_can_only_create_tenant(self):
        client = self.as_user(self.landlord)
        res = client.post('/api/users/', {'username': 'evil', 'password': 'abcdef12', 'role': UserRole.ADMIN},
                          format='json')
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertFalse(User.objects.filter(username='evil').exists())
        res = client.post('/api/users/', {'username': 'newtenant', 'password': 'abcdef12'}, format='json')
        self.assertEqual(res.status_code, status.HTTP_201_CREATED, res.data)
        created = User.objects.get(username='newtenant')
        self.assertEqual(created.role, UserRole.TENANT)
        self.assertTrue(created.check_password('abcdef12'))
        self.assertNotIn('password', res.data)

    def test_landlord_cannot_change_role_or_deactivate(self):
        client = self.as_user(self.landlord)
        res = client.patch(f'/api/users/{self.tenant.id}/', {'role': UserRole.ADMIN}, format='json')
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        res = client.patch(f'/api/users/{self.tenant.id}/', {'is_active': False}, format='json')
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        res = client.patch(f'/api/users/{self.landlord.id}/', {'role': UserRole.ADMIN}, format='json')
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        # Không thấy / không sửa được tài khoản ADMIN
        res = client.patch(f'/api/users/{self.admin.id}/', {'first_name': 'x'}, format='json')
        self.assertEqual(res.status_code, status.HTTP_404_NOT_FOUND)
        self.assertEqual(client.delete(f'/api/users/{self.tenant.id}/').status_code, status.HTTP_403_FORBIDDEN)
        self.tenant.refresh_from_db()
        self.assertEqual(self.tenant.role, UserRole.TENANT)
        self.assertTrue(self.tenant.is_active)

    def test_admin_can_change_role_and_deactivate(self):
        client = self.as_user(self.admin)
        res = client.patch(f'/api/users/{self.tenant.id}/', {'role': UserRole.LANDLORD, 'is_active': False},
                           format='json')
        self.assertEqual(res.status_code, status.HTTP_200_OK, res.data)
        self.tenant.refresh_from_db()
        self.assertEqual(self.tenant.role, UserRole.LANDLORD)
        self.assertFalse(self.tenant.is_active)
        self.assertEqual(client.delete(f'/api/users/{self.admin.id}/').status_code, status.HTTP_400_BAD_REQUEST)

    def test_public_register_cannot_create_staff_or_superuser(self):
        anon = APIClient()
        for role in (UserRole.ADMIN, UserRole.STAFF):
            res = anon.post('/api/auth/register/', {'username': f'r_{role}', 'password': 'abcdef12', 'role': role},
                            format='json')
            self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        res = anon.post('/api/auth/register/', {'username': 'r_ok', 'password': 'abcdef12',
                                                'is_superuser': True, 'is_staff': True}, format='json')
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        user = User.objects.get(username='r_ok')
        self.assertFalse(user.is_superuser)
        self.assertFalse(user.is_staff)
        self.assertEqual(user.role, UserRole.LANDLORD)

    def test_test_accounts_endpoint_hidden_when_not_debug(self):
        from django.test import override_settings
        with override_settings(EXPOSE_TEST_ACCOUNTS=False):
            self.assertEqual(APIClient().get('/api/auth/test-users/').status_code, status.HTTP_404_NOT_FOUND)
        with override_settings(EXPOSE_TEST_ACCOUNTS=True):
            res = APIClient().get('/api/auth/test-users/')
            self.assertEqual(res.status_code, status.HTTP_200_OK)
            self.assertNotIn('ADMIN', [a['role'] for a in res.data['test_accounts']])
