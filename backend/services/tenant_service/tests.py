from django.test import TestCase
from rest_framework import status

from common.testing import jwt_client
from services.tenant_service.models import TenantProfile


class TenantServiceTests(TestCase):
    def setUp(self):
        self.landlord = jwt_client(10, 'LANDLORD')

    def test_crud_and_scope(self):
        res = self.landlord.post('/api/tenants/', {
            'full_name': 'Trần Thị B', 'phone_number': '0909', 'room_id': 3, 'status': 'ACTIVE'}, format='json')
        self.assertEqual(res.status_code, status.HTTP_201_CREATED, res.data)
        self.assertEqual(res.data['landlord_id'], 10)
        tid = res.data['id']
        TenantProfile.objects.create(full_name='Khác', landlord_id=99)

        self.assertEqual(len(self.landlord.get('/api/tenants/').data), 1)
        self.assertEqual(len(self.landlord.get('/api/tenants/?search=0909').data), 1)
        res = self.landlord.patch(f'/api/tenants/{tid}/', {'occupation': 'Kỹ sư'}, format='json')
        self.assertEqual(res.data['occupation'], 'Kỹ sư')

        res = self.landlord.post(f'/api/tenants/{tid}/history/', {
            'room_id': 3, 'move_in_date': '2026-01-01'}, format='json')
        self.assertEqual(res.status_code, status.HTTP_201_CREATED, res.data)
        self.assertEqual(len(self.landlord.get(f'/api/tenants/{tid}/history/').data), 1)

        summary = self.landlord.get('/api/tenants/summary/').data
        self.assertEqual(summary['total_tenants'], 1)
        self.assertEqual(summary['active_tenants'], 1)

        self.assertEqual(self.landlord.delete(f'/api/tenants/{tid}/').status_code, status.HTTP_204_NO_CONTENT)

    def test_tenant_role_sees_only_own_profile_and_cannot_write(self):
        TenantProfile.objects.create(full_name='Tôi', user_id=50, landlord_id=10)
        TenantProfile.objects.create(full_name='Người khác', user_id=51, landlord_id=10)
        tenant = jwt_client(50, 'TENANT')
        data = tenant.get('/api/tenants/').data
        self.assertEqual([t['full_name'] for t in data], ['Tôi'])
        res = tenant.post('/api/tenants/', {'full_name': 'X'}, format='json')
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

    def test_password_not_exposed(self):
        res = self.landlord.post('/api/tenants/', {'full_name': 'A', 'password': 'x'}, format='json')
        self.assertNotIn('password', res.data)

    def test_health(self):
        from rest_framework.test import APIClient
        res = APIClient().get('/health/')
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data['port'], 8003)
