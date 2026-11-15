from django.test import TestCase
from rest_framework import status

from common.testing import jwt_client
from services.property_service.models import (
    MaintenanceRequest, MaintenanceStatus, Property, Room, RoomStatus,
)

LANDLORD_ID = 101


class _Landlord:
    id = LANDLORD_ID


class PropertyServiceTests(TestCase):
    """
    Service chạy độc lập: KHÔNG import model User của Identity Service.
    Xác thực bằng JWT có claims (user_id, role) như Identity Service phát hành.
    """

    def setUp(self):
        self.landlord = _Landlord()
        self.client = jwt_client(LANDLORD_ID, 'LANDLORD')

        self.property = Property.objects.create(
            owner_id=self.landlord.id,
            name='Nhà trọ Thử Nghiệm',
            address='123 Test Street',
            district='Quận 1',
            city='TP. Hồ Chí Minh',
            total_floors=2,
            electricity_rate=3500.0,
            water_rate=20000.0
        )
        # Room in property_db
        self.room = Room.objects.create(
            property=self.property,
            room_number='101',
            floor=1,
            area=20.0,
            rent_price=3000000.0,
            deposit_amount=3000000.0,
            status=RoomStatus.AVAILABLE
        )

    def test_view_property_list(self):
        """SPRINT 1: View Property List"""
        response = self.client.get('/api/properties/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertGreaterEqual(len(response.data), 1)

    def test_create_property(self):
        """SPRINT 1: Create Property"""
        data = {
            'name': 'Nhà trọ Mới Tạo',
            'address': '456 Phố Mới',
            'district': 'Bình Thạnh',
            'city': 'TP.HCM',
            'total_floors': 3,
            'electricity_rate': 3800.0,
            'water_rate': 25000.0,
            'internet_rate': 100000.0
        }
        response = self.client.post('/api/properties/', data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['name'], 'Nhà trọ Mới Tạo')
        self.assertEqual(response.data['owner_id'], self.landlord.id)

    def test_update_property(self):
        """SPRINT 1: Update Property"""
        data = {
            'name': 'Nhà trọ Đã Sửa Tên',
            'address': self.property.address,
            'total_floors': 4,
            'electricity_rate': 4000.0,
            'water_rate': 30000.0,
            'internet_rate': 120000.0
        }
        response = self.client.put(f'/api/properties/{self.property.id}/', data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.property.refresh_from_db()
        self.assertEqual(self.property.name, 'Nhà trọ Đã Sửa Tên')

    def test_delete_property(self):
        """SPRINT 1: Delete Property"""
        prop = Property.objects.create(
            owner_id=self.landlord.id,
            name='Nhà trọ Cần Xóa',
            address='789 Cần Xóa'
        )
        response = self.client.delete(f'/api/properties/{prop.id}/')
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(Property.objects.filter(id=prop.id).exists())

    def test_view_room_list(self):
        """SPRINT 1: View Room List"""
        response = self.client.get(f'/api/rooms/?property_id={self.property.id}')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]['room_number'], '101')

    def test_create_room(self):
        """SPRINT 1: Create Room"""
        data = {
            'property': self.property.id,
            'room_number': '102',
            'floor': 1,
            'area': 22.0,
            'rent_price': 3500000.0,
            'deposit_amount': 3500000.0,
            'max_occupants': 2,
            'status': RoomStatus.AVAILABLE
        }
        response = self.client.post('/api/rooms/', data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['room_number'], '102')

    def test_update_room(self):
        """SPRINT 1: Update Room"""
        data = {
            'property': self.property.id,
            'room_number': '101-VIP',
            'floor': 1,
            'area': 25.0,
            'rent_price': 4000000.0,
            'deposit_amount': 4000000.0,
            'max_occupants': 3,
            'status': RoomStatus.AVAILABLE
        }
        response = self.client.put(f'/api/rooms/{self.room.id}/', data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.room.refresh_from_db()
        self.assertEqual(self.room.room_number, '101-VIP')

    def test_update_room_status(self):
        """SPRINT 1: Update Room Status"""
        response = self.client.patch(
            f'/api/rooms/{self.room.id}/status/',
            {'status': RoomStatus.OCCUPIED},
            format='json'
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.room.refresh_from_db()
        self.assertEqual(self.room.status, RoomStatus.OCCUPIED)

    def test_tenant_cannot_create_property(self):
        client = jwt_client(555, 'TENANT')
        res = client.post('/api/properties/', {'name': 'X', 'address': 'Y'}, format='json')
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

    def test_landlord_cannot_add_room_to_other_property(self):
        other = Property.objects.create(owner_id=999, name='Khác', address='Z')
        res = self.client.post('/api/rooms/', {
            'property': other.id, 'room_number': 'X1', 'rent_price': 1000000}, format='json')
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)

    def test_room_price_filter_and_occupants_validation(self):
        Room.objects.create(property=self.property, room_number='201', rent_price=5000000)
        res = self.client.get('/api/rooms/?min_price=4000000')
        self.assertEqual([r['room_number'] for r in res.data], ['201'])
        res = self.client.get('/api/rooms/?max_price=3500000')
        self.assertEqual([r['room_number'] for r in res.data], ['101'])
        res = self.client.patch(f'/api/rooms/{self.room.id}/', {'current_occupants': 5}, format='json')
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)

    def test_maintenance_lifecycle_restores_room_status(self):
        res = self.client.post('/api/maintenance/', {
            'room': self.room.id, 'title': 'Hỏng máy lạnh', 'priority': 'HIGH',
            'mark_room_maintenance': True}, format='json')
        self.assertEqual(res.status_code, status.HTTP_201_CREATED, res.data)
        req_id = res.data['id']
        self.assertEqual(res.data['reported_by_id'], LANDLORD_ID)
        self.room.refresh_from_db()
        self.assertEqual(self.room.status, RoomStatus.MAINTENANCE)

        res = self.client.post(f'/api/maintenance/{req_id}/start/', {'assigned_to': 'Thợ A'}, format='json')
        self.assertEqual(res.data['status'], MaintenanceStatus.IN_PROGRESS)
        res = self.client.post(f'/api/maintenance/{req_id}/complete/', {'cost': '350000'}, format='json')
        self.assertEqual(res.data['status'], MaintenanceStatus.COMPLETED)
        self.room.refresh_from_db()
        self.assertEqual(self.room.status, RoomStatus.AVAILABLE)
        res = self.client.post(f'/api/maintenance/{req_id}/cancel/')
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)

    def test_tenant_can_report_but_not_complete_maintenance(self):
        tenant = jwt_client(777, 'TENANT')
        res = tenant.post('/api/maintenance/', {'room': self.room.id, 'title': 'Rò nước'}, format='json')
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        res = tenant.post(f"/api/maintenance/{res.data['id']}/complete/")
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)
        self.assertEqual(len(tenant.get('/api/maintenance/').data), 1)

    def test_summary_is_scoped_to_landlord(self):
        other = Property.objects.create(owner_id=999, name='Khác', address='Z')
        Room.objects.create(property=other, room_number='1', rent_price=1, status=RoomStatus.OCCUPIED)
        Room.objects.create(property=self.property, room_number='102', rent_price=1, status=RoomStatus.OCCUPIED)
        MaintenanceRequest.objects.create(room=self.room, title='t')
        res = self.client.get('/api/properties/summary/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data['total_properties'], 1)
        self.assertEqual(res.data['total_rooms'], 2)
        self.assertEqual(res.data['occupied_rooms'], 1)
        self.assertEqual(res.data['available_rooms'], 1)
        self.assertEqual(res.data['open_maintenance_requests'], 1)

    def test_unauthenticated_rejected_and_health_public(self):
        from rest_framework.test import APIClient
        anon = APIClient()
        self.assertEqual(anon.get('/api/properties/').status_code, status.HTTP_401_UNAUTHORIZED)
        res = anon.get('/health/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data['port'], 8002)
