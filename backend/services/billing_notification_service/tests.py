from datetime import timedelta

from django.test import TestCase
from django.utils import timezone
from rest_framework import status

from common.testing import jwt_client
from services.billing_notification_service.models import Invoice, InvoiceStatus


class BillingServiceTests(TestCase):
    def setUp(self):
        self.client = jwt_client(10, 'LANDLORD')
        self.today = timezone.localdate()

    def _create(self, **kw):
        data = {'room_id': 1, 'tenant_id': 3, 'billing_month': 11, 'billing_year': 2026,
                'room_fee': '3000000', 'electricity_old_num': 100, 'electricity_new_num': 150,
                'electricity_unit_price': '3500', 'water_old_num': 10, 'water_new_num': 14,
                'water_unit_price': '20000', 'other_service_cost': '100000',
                'due_date': str(self.today + timedelta(days=5))}
        data.update(kw)
        return self.client.post('/api/billing/invoices/', data, format='json')

    def test_invoice_calculation_payment_and_summary(self):
        res = self._create(notify_user_id=77)
        self.assertEqual(res.status_code, status.HTTP_201_CREATED, res.data)
        # 3.000.000 + 50*3.500 + 4*20.000 + 100.000
        self.assertEqual(float(res.data['total_amount']), 3355000.0)
        inv_id = res.data['id']

        summary = self.client.get('/api/billing/invoices/summary/').data
        self.assertEqual(summary['unpaid_invoices'], 1)
        self.assertEqual(float(summary['unpaid_amount']), 3355000.0)

        res = self.client.post(f'/api/billing/invoices/{inv_id}/pay/')
        self.assertEqual(res.data['status'], InvoiceStatus.PAID)
        self.assertEqual(self.client.get('/api/billing/invoices/summary/').data['unpaid_invoices'], 0)
        self.assertEqual(self.client.patch(f'/api/billing/invoices/{inv_id}/', {'room_fee': 1}, format='json')
                         .status_code, status.HTTP_400_BAD_REQUEST)

        # thông báo hóa đơn gửi tới người thuê
        tenant = jwt_client(77, 'TENANT')
        notes = tenant.get('/api/notifications/').data
        self.assertEqual(len(notes), 1)
        self.assertEqual(notes[0]['category'], 'INVOICE')
        tenant.post(f"/api/notifications/{notes[0]['id']}/read/")
        self.assertEqual(len(tenant.get('/api/notifications/?unread=1').data), 0)

    def test_overdue_and_debt(self):
        self._create(due_date=str(self.today - timedelta(days=1)))
        res = self.client.get('/api/billing/invoices/debt/')
        self.assertEqual(res.data[0]['invoice_count'], 1)
        self.assertEqual(Invoice.objects.get().status, InvoiceStatus.OVERDUE)
        self.assertEqual(self.client.get('/api/billing/invoices/summary/').data['overdue_invoices'], 1)

    def test_invalid_meter_and_scope(self):
        self.assertEqual(self._create(electricity_new_num=50).status_code, status.HTTP_400_BAD_REQUEST)
        self._create()
        self.assertEqual(len(jwt_client(11, 'LANDLORD').get('/api/billing/invoices/').data), 0)
        self.assertEqual(jwt_client(77, 'TENANT').post('/api/notifications/', {
            'user_id': 1, 'title': 'x', 'content': 'y'}, format='json').status_code, status.HTTP_403_FORBIDDEN)

    def test_health(self):
        from rest_framework.test import APIClient
        self.assertEqual(APIClient().get('/health/').data['port'], 8005)
