from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient

from common.testing import jwt_client
from services.property_service.models import (
    MaintenanceHistory, MaintenanceRequest, MaintenanceStatus, Property, PropertyStatus, Room, RoomStatus,
)

LANDLORD_ID = 101


class PropertyServiceTests(TestCase):
    """
    Service chạy độc lập: KHÔNG import model User của Identity Service.
    Xác thực bằng JWT có claims (user_id, role) như Identity Service phát hành.
    """

    def setUp(self):
        self.client = jwt_client(LANDLORD_ID, 'LANDLORD')
        self.property = Property.objects.create(
            code='NT100',
            owner_id=LANDLORD_ID,
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
            room_number='101',
            floor=1,
            area=20.0,
            rent_price=3000000,
            deposit_amount=3000000,
            max_occupants=2,
            status=RoomStatus.AVAILABLE,
        )

    # ------------------------------------------------------------------ PROPERTY
    def test_view_property_list(self):
        response = self.client.get('/api/properties/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)

    def test_create_property_assigns_owner_and_code(self):
        response = self.client.post('/api/properties/', {
            'name': 'Nhà trọ Mới Tạo', 'address': '456 Phố Mới', 'district': 'Quận 7',
            'owner_id': 999,  # bị bỏ qua: owner lấy từ JWT
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED, response.data)
        self.assertEqual(response.data['owner_id'], LANDLORD_ID)
        self.assertTrue(response.data['code'].startswith('NT'))

    def test_update_property(self):
        response = self.client.patch(f'/api/properties/{self.property.id}/',
                                     {'name': 'Nhà trọ Đã Sửa Tên', 'total_floors': 4}, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.property.refresh_from_db()
        self.assertEqual(self.property.name, 'Nhà trọ Đã Sửa Tên')

    def test_search_and_filter_property(self):
        res = self.client.get('/api/properties/?search=Thử Nghiệm&status=ACTIVE')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(len(res.data), 1)
        res = self.client.get('/api/properties/?district=Quận 9')
        self.assertEqual(len(res.data), 0)

    def test_delete_property_hard_when_empty_soft_when_has_rooms(self):
        empty = Property.objects.create(owner_id=LANDLORD_ID, name='Nhà trọ Cần Xóa', address='789')
        res = self.client.delete(f'/api/properties/{empty.id}/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertFalse(res.data['soft_deleted'])
        self.assertFalse(Property.objects.filter(id=empty.id).exists())

        res = self.client.delete(f'/api/properties/{self.property.id}/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertTrue(res.data['soft_deleted'])
        self.property.refresh_from_db()
        self.assertEqual(self.property.status, PropertyStatus.DELETED)
        # Nhà trọ đã xóa mềm không hiện trong danh sách mặc định
        self.assertEqual(len(self.client.get('/api/properties/').data), 0)

    def test_cannot_delete_property_with_rented_rooms(self):
        self.room.status = RoomStatus.OCCUPIED
        self.room.current_occupants = 1
        self.room.save()
        res = self.client.delete(f'/api/properties/{self.property.id}/')
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)

    def test_property_update_status_and_stats(self):
        res = self.client.post(f'/api/properties/{self.property.id}/update_status/', {'status': 'INACTIVE'},
                               format='json')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        res = self.client.get(f'/api/properties/{self.property.id}/stats/')
        self.assertEqual(res.data['total_rooms'], 1)
        self.assertEqual(res.data['available_rooms'], 1)
        res = self.client.get(f'/api/properties/{self.property.id}/room_matrix/')
        self.assertEqual(res.data['floors'][0]['floor_name'], 'Tầng 1')

    def test_landlord_cannot_see_or_edit_other_landlord_property(self):
        other = Property.objects.create(owner_id=999, name='Khác', address='Z')
        self.assertEqual(self.client.get(f'/api/properties/{other.id}/').status_code, status.HTTP_404_NOT_FOUND)
        res = self.client.patch(f'/api/properties/{other.id}/', {'name': 'Hack'}, format='json')
        self.assertEqual(res.status_code, status.HTTP_404_NOT_FOUND)

    def test_tenant_cannot_create_or_delete_property(self):
        tenant = jwt_client(555, 'TENANT')
        res = tenant.post('/api/properties/', {'name': 'X', 'address': 'Y'}, format='json')
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)
        res = tenant.delete(f'/api/properties/{self.property.id}/')
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

    # ------------------------------------------------------------------ ROOM
    def test_view_room_list(self):
        response = self.client.get(f'/api/rooms/?property_id={self.property.id}')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]['room_number'], '101')

    def test_create_and_update_room(self):
        res = self.client.post('/api/rooms/', {
            'property': self.property.id, 'room_number': '102', 'floor': 1, 'area': 22.0,
            'rent_price': 3500000, 'max_occupants': 2,
        }, format='json')
        self.assertEqual(res.status_code, status.HTTP_201_CREATED, res.data)
        self.assertEqual(res.data['code'], 'NT100-102')
        res = self.client.patch(f'/api/rooms/{self.room.id}/', {'room_number': '101-VIP', 'area': 25}, format='json')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.room.refresh_from_db()
        self.assertEqual(self.room.room_number, '101-VIP')

    def test_landlord_cannot_add_room_to_other_property(self):
        other = Property.objects.create(owner_id=999, name='Khác', address='Z')
        res = self.client.post('/api/rooms/', {
            'property': other.id, 'room_number': 'X1', 'rent_price': 1000000}, format='json')
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)

    def test_room_status_check_rentable_and_lists(self):
        res = self.client.get(f'/api/rooms/{self.room.id}/check_rentable/')
        self.assertTrue(res.data['can_rent'])

        res = self.client.patch(f'/api/rooms/{self.room.id}/status/', {'status': 'OCCUPIED'}, format='json')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.room.refresh_from_db()
        self.assertEqual(self.room.status, RoomStatus.OCCUPIED)
        self.assertEqual(self.room.current_occupants, 1)

        res = self.client.post(f'/api/rooms/{self.room.id}/status/', {'status': 'OCCUPIED', 'current_occupants': 2},
                               format='json')
        self.room.refresh_from_db()
        self.assertEqual(self.room.status, RoomStatus.FULL)
        self.assertEqual(len(self.client.get('/api/rooms/occupied/').data), 1)
        self.assertEqual(len(self.client.get('/api/rooms/available/').data), 0)

        res = self.client.post(f'/api/rooms/{self.room.id}/status/', {'status': 'OCCUPIED', 'current_occupants': 9},
                               format='json')
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        res = self.client.post(f'/api/rooms/{self.room.id}/status/', {'status': 'BOGUS'}, format='json')
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)

    def test_room_search_filter_sort(self):
        Room.objects.create(property=self.property, room_number='201', floor=2, area=30, rent_price=5000000)
        res = self.client.get('/api/rooms/?min_price=4000000')
        self.assertEqual([r['room_number'] for r in res.data], ['201'])
        res = self.client.get('/api/rooms/?max_price=3500000')
        self.assertEqual([r['room_number'] for r in res.data], ['101'])
        res = self.client.get('/api/rooms/?min_area=25&max_area=35')
        self.assertEqual([r['room_number'] for r in res.data], ['201'])
        res = self.client.get('/api/rooms/?sort=price_desc')
        self.assertEqual([r['room_number'] for r in res.data], ['201', '101'])
        res = self.client.get('/api/rooms/?search=Thử Nghiệm&max_occupants=2')
        self.assertEqual(len(res.data), 2)
        self.assertEqual(self.client.get('/api/rooms/?min_price=abc').status_code, status.HTTP_400_BAD_REQUEST)

    def test_occupants_validation(self):
        res = self.client.patch(f'/api/rooms/{self.room.id}/', {'current_occupants': 5}, format='json')
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)

    def test_delete_room_hard_and_soft(self):
        res = self.client.delete(f'/api/rooms/{self.room.id}/')
        self.assertFalse(res.data['soft_deleted'])
        room = Room.objects.create(property=self.property, room_number='202', rent_price=1)
        MaintenanceRequest.objects.create(room=room, title='t')
        res = self.client.delete(f'/api/rooms/{room.id}/')
        self.assertTrue(res.data['soft_deleted'])
        room.refresh_from_db()
        self.assertEqual(room.status, RoomStatus.INACTIVE)

    def test_tenant_does_not_see_occupant_personal_info(self):
        self.room.tenant_name = 'Nguyễn Văn A'
        self.room.tenant_phone = '0900000000'
        self.room.save()
        res = jwt_client(555, 'TENANT').get(f'/api/rooms/{self.room.id}/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertNotIn('tenant_phone', res.data)
        self.assertNotIn('tenant_name', res.data)
        res = self.client.get(f'/api/rooms/{self.room.id}/')
        self.assertEqual(res.data['tenant_phone'], '0900000000')

    # ------------------------------------------------------------------ MAINTENANCE
    def test_maintenance_workflow_and_history(self):
        res = self.client.post('/api/maintenance/', {
            'room': self.room.id, 'title': 'Phòng 101 hỏng điều hòa', 'estimated_cost': 500000,
            'priority': 'HIGH',
        }, format='json')
        self.assertEqual(res.status_code, status.HTTP_201_CREATED, res.data)
        maint_id = res.data['id']
        self.assertEqual(res.data['reported_by_id'], LANDLORD_ID)
        self.room.refresh_from_db()
        self.assertEqual(self.room.status, RoomStatus.MAINTENANCE)

        res = self.client.post(f'/api/maintenance/{maint_id}/update_status/', {'status': 'IN_PROGRESS'},
                               format='json')
        self.assertEqual(res.data['maintenance_request']['status'], MaintenanceStatus.IN_PROGRESS)

        res = self.client.post(f'/api/maintenance/{maint_id}/record_cost/',
                               {'estimated_cost': 500000, 'actual_cost': 450000}, format='json')
        self.assertEqual(res.status_code, status.HTTP_200_OK)

        res = self.client.post(f'/api/maintenance/{maint_id}/complete/',
                               {'repair_info': 'Đã sửa xong điều hòa'}, format='json')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data['maintenance_request']['status'], MaintenanceStatus.COMPLETED)
        self.room.refresh_from_db()
        self.assertEqual(self.room.status, RoomStatus.AVAILABLE)  # khôi phục trạng thái trước bảo trì

        # Không thể hủy yêu cầu đã hoàn thành
        res = self.client.post(f'/api/maintenance/{maint_id}/cancel/')
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)

        res = self.client.get('/api/maintenance-history/')
        self.assertGreaterEqual(len(res.data), 4)
        res = self.client.get(f'/api/maintenance/{maint_id}/history/')
        self.assertGreaterEqual(len(res.data), 4)

    def test_maintenance_start_complete_restores_previous_status(self):
        self.room.status = RoomStatus.OCCUPIED
        self.room.current_occupants = 1
        self.room.save()
        res = self.client.post('/api/maintenance/', {
            'room': self.room.id, 'title': 'Hỏng máy lạnh', 'mark_room_maintenance': True}, format='json')
        req_id = res.data['id']
        self.room.refresh_from_db()
        self.assertEqual(self.room.status, RoomStatus.MAINTENANCE)
        res = self.client.post(f'/api/maintenance/{req_id}/start/', {'assigned_to': 'Thợ A'}, format='json')
        self.assertEqual(res.data['maintenance_request']['technician_name'], 'Thợ A')
        res = self.client.post(f'/api/maintenance/{req_id}/complete/', {'cost': '350000'}, format='json')
        self.assertEqual(res.data['maintenance_request']['actual_cost'], '350000')
        self.room.refresh_from_db()
        self.assertEqual(self.room.status, RoomStatus.OCCUPIED)

    def test_create_maintenance_without_locking_room(self):
        res = self.client.post('/api/maintenance/', {
            'room': self.room.id, 'title': 'Thay bóng đèn', 'set_room_maintenance': False}, format='json')
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.room.refresh_from_db()
        self.assertEqual(self.room.status, RoomStatus.AVAILABLE)

    def test_tenant_can_report_but_not_manage_maintenance(self):
        tenant = jwt_client(777, 'TENANT')
        res = tenant.post('/api/maintenance/', {'room': self.room.id, 'title': 'Rò nước'}, format='json')
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        req_id = res.data['id']
        self.room.refresh_from_db()
        self.assertEqual(self.room.status, RoomStatus.AVAILABLE)  # TENANT không khóa được phòng
        for path in ('complete', 'start', 'record_cost', 'update_status'):
            res = tenant.post(f'/api/maintenance/{req_id}/{path}/', {'status': 'COMPLETED'}, format='json')
            self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN, path)
        self.assertEqual(len(tenant.get('/api/maintenance/').data), 1)
        self.assertEqual(len(jwt_client(778, 'TENANT').get('/api/maintenance/').data), 0)
        self.assertEqual(len(jwt_client(778, 'TENANT').get('/api/maintenance-history/').data), 0)
        res = tenant.post(f'/api/maintenance/{req_id}/cancel/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)

    def test_landlord_cannot_see_other_landlord_maintenance(self):
        other = Property.objects.create(owner_id=999, name='Khác', address='Z')
        other_room = Room.objects.create(property=other, room_number='1', rent_price=1)
        req = MaintenanceRequest.objects.create(room=other_room, title='x')
        MaintenanceHistory.objects.create(maintenance_request=req, room=other_room, action='a')
        self.assertEqual(len(self.client.get('/api/maintenance/').data), 0)
        self.assertEqual(len(self.client.get('/api/maintenance-history/').data), 0)
        res = self.client.post('/api/maintenance/', {'room': other_room.id, 'title': 'x'}, format='json')
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)

    # ------------------------------------------------------------------ SUMMARY / HEALTH
    def test_summary_is_scoped_to_landlord(self):
        other = Property.objects.create(owner_id=999, name='Khác', address='Z')
        Room.objects.create(property=other, room_number='1', rent_price=1, status=RoomStatus.OCCUPIED)
        Room.objects.create(property=self.property, room_number='102', rent_price=1, status=RoomStatus.OCCUPIED)
        Room.objects.create(property=self.property, room_number='103', rent_price=1, status=RoomStatus.FULL)
        MaintenanceRequest.objects.create(room=self.room, title='t')
        res = self.client.get('/api/properties/summary/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data['total_properties'], 1)
        self.assertEqual(res.data['total_rooms'], 3)
        self.assertEqual(res.data['occupied_rooms'], 2)
        self.assertEqual(res.data['full_rooms'], 1)
        self.assertEqual(res.data['available_rooms'], 1)
        self.assertEqual(res.data['open_maintenance_requests'], 1)

    def test_unauthenticated_rejected_and_health_public(self):
        anon = APIClient()
        self.assertEqual(anon.get('/api/properties/').status_code, status.HTTP_401_UNAUTHORIZED)
        res = anon.get('/health/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data['port'], 8002)
