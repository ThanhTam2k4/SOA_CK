from unittest import mock

import requests
from django.test import TestCase, override_settings
from rest_framework import status

from common.testing import fake_http_response, jwt_client
from services.tenant_service.models import TenantProfile


class TenantServiceTests(TestCase):
    def setUp(self):
        self.landlord = jwt_client(10, 'LANDLORD')
        # Property Service (giả lập): phòng thuộc phạm vi chủ trọ -> 200.
        patcher = mock.patch('common.service_client.requests.get', return_value=fake_http_response(200, {'id': 3}))
        self.property_api = patcher.start()
        self.addCleanup(patcher.stop)

    @override_settings(SPRINT_FEATURE_LOCK=False)  # kiểm thử source nghiệp vụ được giữ lại (ghi lịch sử thuê)
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



class TenantLinksAndOwnershipTests(TestCase):
    """Liên kết user_id ↔ tenant_id ↔ room_id và kiểm tra quyền sở hữu khi ghi."""

    def setUp(self):
        self.mine = TenantProfile.objects.create(full_name='Của tôi', user_id=50, landlord_id=10, room_id=1,
                                                 status='ACTIVE')
        self.other = TenantProfile.objects.create(full_name='Khác', user_id=51, landlord_id=99, room_id=9,
                                                  status='ACTIVE')

    def test_links_scoped_by_jwt(self):
        rows = jwt_client(50, 'TENANT').get('/api/tenants/links/').data
        self.assertEqual(rows, [{'tenant_id': self.mine.id, 'user_id': 50, 'room_id': 1,
                                 'landlord_id': 10, 'status': 'ACTIVE'}])
        # Tham số client không mở rộng phạm vi.
        self.assertEqual(len(jwt_client(50, 'TENANT').get('/api/tenants/links/?user_id=51').data), 1)
        self.assertEqual([r['tenant_id'] for r in jwt_client(10, 'LANDLORD').get('/api/tenants/links/').data],
                         [self.mine.id])
        self.assertEqual(len(jwt_client(1, 'ADMIN').get('/api/tenants/links/').data), 2)
        self.assertEqual(jwt_client(300, 'STAFF').get('/api/tenants/links/').data, [])
        from rest_framework.test import APIClient
        self.assertEqual(APIClient().get('/api/tenants/links/').status_code, status.HTTP_401_UNAUTHORIZED)

    def test_staff_not_admin(self):
        staff = jwt_client(300, 'STAFF')
        self.assertEqual(staff.get('/api/tenants/').data, [])
        self.assertEqual(staff.post('/api/tenants/', {'full_name': 'X'}, format='json').status_code,
                         status.HTTP_403_FORBIDDEN)

    def test_landlord_cannot_touch_other_landlord_profile(self):
        landlord = jwt_client(10, 'LANDLORD')
        self.assertEqual(landlord.get(f'/api/tenants/{self.other.id}/').status_code, status.HTTP_404_NOT_FOUND)
        self.assertEqual(landlord.patch(f'/api/tenants/{self.other.id}/', {'notes': 'x'}, format='json').status_code,
                         status.HTTP_404_NOT_FOUND)

    def test_room_must_belong_to_landlord(self):
        landlord = jwt_client(10, 'LANDLORD')
        with mock.patch('common.service_client.requests.get', return_value=fake_http_response(404, {})) as fake:
            res = landlord.post('/api/tenants/', {'full_name': 'A', 'room_id': 9}, format='json')
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('room_id', res.data)
        self.assertEqual(fake.call_args.args[0], 'http://127.0.0.1:8002/api/rooms/9/')
        with mock.patch('common.service_client.requests.get', return_value=fake_http_response(404, {})):
            res = landlord.patch(f'/api/tenants/{self.mine.id}/', {'room_id': 9}, format='json')
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        self.mine.refresh_from_db()
        self.assertEqual(self.mine.room_id, 1)

    def test_property_service_down_fails_closed(self):
        with mock.patch('common.service_client.requests.get', side_effect=requests.exceptions.ConnectionError()):
            res = jwt_client(10, 'LANDLORD').post('/api/tenants/', {'full_name': 'A', 'room_id': 1}, format='json')
        self.assertEqual(res.status_code, status.HTTP_503_SERVICE_UNAVAILABLE)
        self.assertEqual(TenantProfile.objects.count(), 2)

    def test_cannot_claim_account_linked_to_other_landlord(self):
        with mock.patch('common.service_client.requests.get', return_value=fake_http_response(200, {'id': 1})):
            res = jwt_client(10, 'LANDLORD').post('/api/tenants/', {'full_name': 'B', 'user_id': 51, 'room_id': 1},
                                                  format='json')
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('user_id', res.data)

    def test_history_post_locked_get_allowed(self):
        landlord = jwt_client(10, 'LANDLORD')
        res = landlord.post(f'/api/tenants/{self.mine.id}/history/', {'room_id': 1, 'move_in_date': '2026-01-01'},
                            format='json')
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)
        self.assertEqual(self.mine.rental_history.count(), 0)
        self.assertEqual(landlord.get(f'/api/tenants/{self.mine.id}/history/').status_code, status.HTTP_200_OK)
        self.assertEqual(jwt_client(50, 'TENANT').get(f'/api/tenants/{self.mine.id}/history/').status_code,
                         status.HTTP_200_OK)
