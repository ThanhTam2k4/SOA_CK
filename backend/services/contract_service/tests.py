from datetime import timedelta

from django.test import TestCase
from django.utils import timezone
from rest_framework import status

from common.testing import jwt_client
from services.contract_service.models import Contract, ContractStatus


class ContractServiceTests(TestCase):
    def setUp(self):
        self.client = jwt_client(10, 'LANDLORD')
        self.today = timezone.localdate()

    def _payload(self, **kw):
        data = {'room_id': 1, 'tenant_id': 5, 'start_date': str(self.today),
                'end_date': str(self.today + timedelta(days=180)), 'rental_price': '3000000'}
        data.update(kw)
        return data

    def test_create_extend_terminate_history(self):
        res = self.client.post('/api/contracts/', self._payload(), format='json')
        self.assertEqual(res.status_code, status.HTTP_201_CREATED, res.data)
        cid = res.data['id']
        self.assertTrue(res.data['contract_number'].startswith('HD'))
        self.assertEqual(res.data['landlord_id'], 10)

        dup = self.client.post('/api/contracts/', self._payload(), format='json')
        self.assertEqual(dup.status_code, status.HTTP_400_BAD_REQUEST)

        new_end = str(self.today + timedelta(days=365))
        res = self.client.post(f'/api/contracts/{cid}/extend/', {'new_end_date': new_end}, format='json')
        self.assertEqual(res.status_code, status.HTTP_200_OK, res.data)
        self.assertEqual(res.data['status'], ContractStatus.EXTENDED)
        self.assertEqual(res.data['end_date'], new_end)

        self.assertEqual(self.client.get('/api/contracts/summary/').data['active_contracts'], 1)

        res = self.client.post(f'/api/contracts/{cid}/terminate/', {'reason': 'Chuyển đi'}, format='json')
        self.assertEqual(res.data['status'], ContractStatus.TERMINATED)
        events = self.client.get(f'/api/contracts/{cid}/history/').data
        self.assertEqual([e['event_type'] for e in events], ['TERMINATED', 'EXTENDED', 'CREATED'])
        self.assertEqual(self.client.get('/api/contracts/summary/').data['active_contracts'], 0)

    def test_validation_and_status_guard(self):
        res = self.client.post('/api/contracts/', self._payload(end_date=str(self.today)), format='json')
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        res = self.client.post('/api/contracts/', self._payload(status='DRAFT'), format='json')
        cid = res.data['id']
        res = self.client.patch(f'/api/contracts/{cid}/', {'status': 'TERMINATED'}, format='json')
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        res = self.client.post(f'/api/contracts/{cid}/activate/')
        self.assertEqual(res.data['status'], ContractStatus.ACTIVE)

    def test_scope(self):
        Contract.objects.create(contract_number='X1', room_id=9, tenant_id=1, landlord_id=99,
                                start_date=self.today, end_date=self.today + timedelta(days=10),
                                rental_price=1)
        self.assertEqual(len(self.client.get('/api/contracts/').data), 0)
        self.assertEqual(jwt_client(1, 'ADMIN').get('/api/contracts/summary/').data['active_contracts'], 1)
        self.assertEqual(jwt_client(2, 'TENANT').get('/api/contracts/').status_code, status.HTTP_403_FORBIDDEN)
