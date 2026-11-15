from django.test import TestCase
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from rest_framework import status
from services.identity_service.models import UserRole
from services.property_service.models import (
    Property,
    PropertyStatus,
    Room,
    RoomStatus,
    MaintenanceRequest,
    MaintenanceStatus,
)

User = get_user_model()


class PropertyAndMaintenanceServiceTests(TestCase):
    databases = {'default', 'property_db'}

    def setUp(self):
        self.client = APIClient()
        self.landlord = User.objects.create_user(
            username='testlandlord_prop',
            password='password123',
            role=UserRole.LANDLORD,
        )
        self.client.force_authenticate(user=self.landlord)

        self.property = Property.objects.create(
            code='NT100',
            owner_id=self.landlord.id,
            name='Nhà trọ Thử Nghiệm',
            address='123 Đường Nguyễn Gia Trí',
            ward='Phường 25',
            district='Bình Thạnh',
            city='TP. Hồ Chí Minh',
            total_floors=2,
            status=PropertyStatus.ACTIVE,
        )
        self.room = Room.objects.create(
            code='NT100-A01',
            property=self.property,
            room_number='Phòng A01',
            floor=1,
            area=22.0,
            rent_price=3200000,
            max_occupants=2,
            status=RoomStatus.AVAILABLE,
        )

    def test_property_crud_and_soft_delete(self):
        # 1.1 Create
        res = self.client.post('/api/v1/properties/', {
            'name': 'Nhà trọ Mới Tạo',
            'address': '456 Phố Mới',
            'district': 'Quận 7',
            'status': 'ACTIVE',
        }, format='json')
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)

        # 1.6 & 1.7 Search & Filter
        res = self.client.get('/api/v1/properties/?search=Thử Nghiệm&status=ACTIVE')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(len(res.data), 1)

        # 1.5 Soft Delete when property has rooms
        res = self.client.delete(f'/api/v1/properties/{self.property.id}/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.property.refresh_from_db()
        self.assertEqual(self.property.status, PropertyStatus.DELETED)

    def test_room_search_filter_sort_and_status(self):
        # 3.3 Check rentable
        res = self.client.get(f'/api/v1/rooms/{self.room.id}/check_rentable/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertTrue(res.data['can_rent'])

        # 3.2 Update status
        res = self.client.post(f'/api/v1/rooms/{self.room.id}/status/', {
            'status': 'OCCUPIED',
            'current_occupants': 1,
        }, format='json')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.room.refresh_from_db()
        self.assertEqual(self.room.status, RoomStatus.OCCUPIED)

        # IV, V, VI Search, Filter, Sort
        res = self.client.get('/api/v1/rooms/?search=Phòng A01&min_price=2000000&max_price=4000000&sort=price_asc')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(len(res.data), 1)

    def test_maintenance_workflow_and_history(self):
        # 7.1 Create maintenance request
        res = self.client.post('/api/v1/maintenance/', {
            'room': self.room.id,
            'title': 'Phòng A01 bị hỏng điều hòa',
            'description': 'Cần vệ sinh và nạp gas',
            'estimated_cost': 500000,
        }, format='json')
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        maint_id = res.data['id']
        self.room.refresh_from_db()
        self.assertEqual(self.room.status, RoomStatus.MAINTENANCE)

        # 7.5 Update status to IN_PROGRESS
        res = self.client.post(f'/api/v1/maintenance/{maint_id}/update_status/', {
            'status': 'IN_PROGRESS',
        }, format='json')
        self.assertEqual(res.status_code, status.HTTP_200_OK)

        # 7.6 Record cost
        res = self.client.post(f'/api/v1/maintenance/{maint_id}/record_cost/', {
            'estimated_cost': 500000,
            'actual_cost': 450000,
        }, format='json')
        self.assertEqual(res.status_code, status.HTTP_200_OK)

        # 7.7 Complete maintenance -> Room returns to AVAILABLE
        res = self.client.post(f'/api/v1/maintenance/{maint_id}/complete/', {
            'actual_cost': 450000,
            'repair_info': 'Đã sửa xong điều hòa',
            'room_status': 'AVAILABLE',
        }, format='json')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.room.refresh_from_db()
        self.assertEqual(self.room.status, RoomStatus.AVAILABLE)

        # 7.8 Check maintenance history
        res = self.client.get('/api/v1/maintenance-history/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertGreaterEqual(len(res.data), 3)
