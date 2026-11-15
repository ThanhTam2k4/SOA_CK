from unittest import mock

import requests
from django.test import SimpleTestCase


def _resp(status=200, json_body=None, content=b'', headers=None):
    r = mock.Mock()
    r.status_code = status
    r.headers = headers or {'Content-Type': 'application/json'}
    r.content = content
    if json_body is None:
        r.json.side_effect = ValueError('no json')
    else:
        r.json.return_value = json_body
    return r


class SystemHealthTests(SimpleTestCase):
    def test_reports_real_status_per_service(self):
        def fake_get(url, headers=None, timeout=None):
            if ':8003' in url:
                raise requests.exceptions.ConnectionError()
            if ':8005' in url:
                return _resp(503, {'status': 'DOWN', 'database': {'status': 'DOWN', 'error': 'db lỗi'}})
            if ':8004' in url:
                return _resp(500, None, b'<html>')
            return _resp(200, {'status': 'UP', 'database': {'status': 'UP'}})

        with mock.patch('gateway.client.get_json', side_effect=fake_get):
            data = self.client.get('/api/system/health/').json()

        self.assertEqual(data['gateway'], {'name': 'API Gateway', 'status': 'UP', 'port': 8000})
        status = {s['port']: s['status'] for s in data['services']}
        self.assertEqual(status, {8001: 'UP', 8002: 'UP', 8003: 'DOWN', 8004: 'UNKNOWN', 8005: 'DOWN'})
        self.assertEqual(data['overall_status'], 'DEGRADED')
        self.assertEqual(data['summary'], {'total': 5, 'up': 2, 'down': 3})

    def test_all_up(self):
        with mock.patch('gateway.client.get_json', return_value=_resp(200, {'status': 'UP'})):
            data = self.client.get('/api/system/health/').json()
        self.assertEqual(data['overall_status'], 'UP')
        self.assertEqual([s['name'] for s in data['services']], [
            'Identity Service', 'Property & Maintenance Service', 'Tenant Service',
            'Contract Service', 'Billing & Notification Service'])


class ProxyTests(SimpleTestCase):
    def _proxy(self, path, method='get', **kwargs):
        with mock.patch('gateway.client._session.request',
                        return_value=_resp(201, {}, b'{"ok":true}',
                                           {'Content-Type': 'application/json', 'Content-Encoding': 'gzip'})) as req:
            res = getattr(self.client, method)(path, **kwargs)
        return res, req

    def test_routes_to_owner_service_with_auth_and_query(self):
        cases = {
            '/api/auth/login/': 'http://127.0.0.1:8001/api/auth/login/',
            '/api/users/': 'http://127.0.0.1:8001/api/users/',
            '/api/properties/1/stats/': 'http://127.0.0.1:8002/api/properties/1/stats/',
            '/api/rooms/?status=AVAILABLE': 'http://127.0.0.1:8002/api/rooms/?status=AVAILABLE',
            '/api/maintenance/': 'http://127.0.0.1:8002/api/maintenance/',
            '/api/tenants/': 'http://127.0.0.1:8003/api/tenants/',
            '/api/contracts/5/extend/': 'http://127.0.0.1:8004/api/contracts/5/extend/',
            '/api/billing/invoices/': 'http://127.0.0.1:8005/api/billing/invoices/',
            '/api/notifications/': 'http://127.0.0.1:8005/api/notifications/',
            '/api/v1/rooms/3/': 'http://127.0.0.1:8002/api/rooms/3/',
        }
        for path, expected in cases.items():
            res, req = self._proxy(path, HTTP_AUTHORIZATION='Bearer abc')
            self.assertEqual(req.call_args.kwargs['url'], expected, path)
            self.assertEqual(req.call_args.kwargs['headers']['Authorization'], 'Bearer abc')
            self.assertEqual(res.status_code, 201)
            self.assertNotIn('Content-Encoding', res)

    def test_forwards_method_and_body(self):
        res, req = self._proxy('/api/rooms/', method='post', data='{"a":1}', content_type='application/json')
        self.assertEqual(req.call_args.kwargs['method'], 'POST')
        self.assertEqual(req.call_args.kwargs['data'], b'{"a":1}')

    def test_unknown_route_404(self):
        res = self.client.get('/api/unknown/')
        self.assertEqual(res.status_code, 404)
        self.assertIn('/api/rooms/', res.json()['available_routes'])

    def test_service_down_returns_503_json(self):
        with mock.patch('gateway.client._session.request', side_effect=requests.exceptions.ConnectionError()):
            res = self.client.get('/api/tenants/')
        self.assertEqual(res.status_code, 503)
        self.assertEqual(res.json()['service'], 'tenant')

    def test_timeout_returns_504(self):
        with mock.patch('gateway.client._session.request', side_effect=requests.exceptions.ReadTimeout()):
            self.assertEqual(self.client.get('/api/contracts/').status_code, 504)


class DashboardSummaryTests(SimpleTestCase):
    PAYLOADS = {
        '/api/properties/summary/': {'total_properties': 2, 'total_rooms': 20, 'occupied_rooms': 12,
                                     'available_rooms': 6, 'maintenance_rooms': 2, 'reserved_rooms': 0,
                                     'occupancy_rate_percent': 60.0, 'open_maintenance_requests': 1},
        '/api/tenants/summary/': {'total_tenants': 18, 'active_tenants': 15},
        '/api/contracts/summary/': {'active_contracts': 12, 'expiring_soon_contracts': 1},
        '/api/billing/invoices/summary/': {'unpaid_invoices': 5, 'overdue_invoices': 2, 'unpaid_amount': '1000'},
    }

    def _fake(self, down=None, unauthorized=False):
        def fake_get(url, headers=None, timeout=None):
            assert headers['Authorization'] == 'Bearer tok'
            for path, body in self.PAYLOADS.items():
                if url.endswith(path):
                    if down and down in path:
                        raise requests.exceptions.ConnectionError()
                    if unauthorized:
                        return _resp(401, {'detail': 'x'})
                    return _resp(200, body)
            raise AssertionError(url)
        return fake_get

    def test_requires_token(self):
        self.assertEqual(self.client.get('/api/dashboard/summary/').status_code, 401)

    def test_aggregates_all_sources(self):
        with mock.patch('gateway.client.get_json', side_effect=self._fake()):
            data = self.client.get('/api/dashboard/summary/', HTTP_AUTHORIZATION='Bearer tok').json()
        self.assertEqual(data['total_properties'], 2)
        self.assertEqual(data['total_rooms'], 20)
        self.assertEqual(data['total_tenants'], 18)
        self.assertEqual(data['active_contracts'], 12)
        self.assertEqual(data['unpaid_invoices'], 5)
        self.assertTrue(data['complete'])
        self.assertEqual(data['errors'], [])

    def test_partial_failure_returns_nulls_not_500(self):
        with mock.patch('gateway.client.get_json', side_effect=self._fake(down='tenants')):
            res = self.client.get('/api/dashboard/summary/', HTTP_AUTHORIZATION='Bearer tok')
        data = res.json()
        self.assertEqual(res.status_code, 200)
        self.assertIsNone(data['total_tenants'])
        self.assertEqual(data['total_rooms'], 20)
        self.assertFalse(data['complete'])
        self.assertEqual(data['errors'][0]['source'], 'tenant')
        self.assertEqual(data['sources']['tenant']['status'], 'DOWN')

    def test_invalid_token_propagates_401(self):
        with mock.patch('gateway.client.get_json', side_effect=self._fake(unauthorized=True)):
            res = self.client.get('/api/dashboard/summary/', HTTP_AUTHORIZATION='Bearer tok')
        self.assertEqual(res.status_code, 401)
