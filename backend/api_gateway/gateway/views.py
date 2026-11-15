import time
from concurrent.futures import ThreadPoolExecutor

import requests
from django.conf import settings
from django.http import HttpResponse, JsonResponse
from django.utils import timezone
from django.views.decorators.csrf import csrf_exempt

from . import client
from .registry import route_table, service_for_path, services


def _error(http_status, message, **extra):
    return JsonResponse({'error': message, **extra}, status=http_status, json_dumps_params={'ensure_ascii': False})


# ==============================================================================
# 1. ROUTING / REVERSE PROXY
# ==============================================================================
@csrf_exempt
def proxy(request, path):
    """/api/<path> -> <service_url>/api/<path> (giữ nguyên method, query, body, Authorization)."""
    key, conf = service_for_path(path)
    if conf is None:
        return _error(404, f'Không có service nào phục vụ đường dẫn /api/{path}',
                      available_routes=list(route_table().keys()))

    url = f"{conf['url'].rstrip('/')}/api/{path}"
    query = request.META.get('QUERY_STRING')
    if query:
        url = f'{url}?{query}'

    try:
        upstream = client.session().request(
            method=request.method,
            url=url,
            headers=client.forward_headers(request),
            data=request.body if request.body else None,
            timeout=(settings.GATEWAY_CONNECT_TIMEOUT, settings.GATEWAY_READ_TIMEOUT),
            allow_redirects=False,
        )
    except requests.exceptions.Timeout:
        return _error(504, f"{conf['name']} không phản hồi kịp (timeout).", service=key, status='DOWN')
    except requests.exceptions.ConnectionError:
        return _error(503, f"{conf['name']} hiện không hoạt động (port {conf['port']}).", service=key, status='DOWN')

    response = HttpResponse(upstream.content, status=upstream.status_code)
    for header, value in upstream.headers.items():
        if header.lower() not in client.STRIP_RESPONSE:
            response[header] = value
    response['X-Served-By'] = key
    return response


def legacy_v1_proxy(request, path):
    """Alias tương thích ngược: /api/v1/<path> -> /api/<path>."""
    return proxy(request, path)


# ==============================================================================
# 2. SYSTEM HEALTH
# ==============================================================================
def check_service(key, conf):
    started = time.monotonic()
    result = {'key': key, 'name': conf['name'], 'port': conf['port']}
    try:
        resp = client.get_json(f"{conf['url'].rstrip('/')}/health/", timeout=settings.GATEWAY_HEALTH_TIMEOUT)
    except requests.exceptions.Timeout:
        return {**result, 'status': 'DOWN', 'error': 'Timeout khi kiểm tra health.'}
    except requests.exceptions.ConnectionError:
        return {**result, 'status': 'DOWN', 'error': 'Không kết nối được tới service.'}
    result['response_time_ms'] = round((time.monotonic() - started) * 1000, 1)
    try:
        body = resp.json()
    except ValueError:
        return {**result, 'status': 'UNKNOWN', 'error': f'Phản hồi health không hợp lệ (HTTP {resp.status_code}).'}

    reported = body.get('status') if isinstance(body, dict) else None
    if resp.status_code == 200 and reported == 'UP':
        status = 'UP'
    elif reported == 'DOWN':
        status = 'DOWN'
    else:
        status = 'UNKNOWN'
    result['status'] = status
    if isinstance(body, dict) and isinstance(body.get('database'), dict):
        result['database'] = body['database']
    if status != 'UP':
        result['error'] = (body.get('database') or {}).get('error') if isinstance(body, dict) else None
        result['error'] = result['error'] or f'HTTP {resp.status_code}'
    return result


def system_health(request):
    """
    GET /api/system/health/
    Gateway gọi song song /health/ của từng service và trả về trạng thái THỰC TẾ.
    """
    registry = services()
    with ThreadPoolExecutor(max_workers=len(registry)) as pool:
        results = list(pool.map(lambda item: check_service(*item), registry.items()))

    up = sum(1 for r in results if r['status'] == 'UP')
    if up == len(results):
        overall = 'UP'
    elif up == 0:
        overall = 'DOWN'
    else:
        overall = 'DEGRADED'
    return JsonResponse({
        'gateway': {'name': 'API Gateway', 'status': 'UP', 'port': settings.GATEWAY_PORT},
        'overall_status': overall,
        'summary': {'total': len(results), 'up': up, 'down': len(results) - up},
        'services': results,
        'checked_at': timezone.now().isoformat(),
    }, json_dumps_params={'ensure_ascii': False})


def gateway_health(request):
    return JsonResponse({'service': 'API Gateway', 'key': 'gateway', 'port': settings.GATEWAY_PORT, 'status': 'UP'})


# ==============================================================================
# 3. DASHBOARD AGGREGATION
# ==============================================================================
# service key -> (endpoint thống kê, các trường lấy về Dashboard)
DASHBOARD_SOURCES = {
    'property': ('/api/properties/summary/', [
        'total_properties', 'total_rooms', 'occupied_rooms', 'available_rooms', 'maintenance_rooms',
        'reserved_rooms', 'full_rooms', 'inactive_rooms', 'occupancy_rate_percent',
        'estimated_monthly_revenue', 'open_maintenance_requests']),
    'tenant': ('/api/tenants/summary/', ['total_tenants', 'active_tenants']),
    'contract': ('/api/contracts/summary/', ['active_contracts', 'expiring_soon_contracts']),
    'billing': ('/api/billing/invoices/summary/', ['unpaid_invoices', 'overdue_invoices', 'unpaid_amount']),
}


def _fetch_source(key, auth_header):
    conf = services()[key]
    endpoint, fields = DASHBOARD_SOURCES[key]
    meta = {'service': conf['name'], 'port': conf['port']}
    try:
        resp = client.get_json(f"{conf['url'].rstrip('/')}{endpoint}", headers={'Authorization': auth_header})
    except requests.exceptions.Timeout:
        return key, fields, None, {**meta, 'status': 'DOWN', 'error': 'Timeout'}
    except requests.exceptions.ConnectionError:
        return key, fields, None, {**meta, 'status': 'DOWN', 'error': 'Không kết nối được tới service.'}
    if resp.status_code != 200:
        return key, fields, None, {**meta, 'status': 'ERROR', 'http_status': resp.status_code,
                                   'error': f'HTTP {resp.status_code}'}
    try:
        return key, fields, resp.json(), {**meta, 'status': 'UP'}
    except ValueError:
        return key, fields, None, {**meta, 'status': 'UNKNOWN', 'error': 'Phản hồi không phải JSON.'}


def dashboard_summary(request):
    """
    GET /api/dashboard/summary/  (cần Authorization: Bearer <token>)
    Gateway gọi song song endpoint thống kê của Property/Tenant/Contract/Billing với token
    của người dùng (để mỗi service tự phân quyền phạm vi dữ liệu), rồi gộp kết quả.
    Service nào lỗi -> các trường của nó là null và được liệt kê trong `errors`.
    """
    auth_header = request.headers.get('Authorization', '')
    if not auth_header.startswith('Bearer '):
        return _error(401, 'Cần đăng nhập (Authorization: Bearer <token>).')

    with ThreadPoolExecutor(max_workers=len(DASHBOARD_SOURCES)) as pool:
        results = list(pool.map(lambda k: _fetch_source(k, auth_header), DASHBOARD_SOURCES))

    if any(meta.get('http_status') == 401 for *_, meta in results):
        return _error(401, 'Phiên đăng nhập đã hết hạn hoặc token không hợp lệ.')

    data, sources, errors = {}, {}, []
    for key, fields, payload, meta in results:
        sources[key] = meta
        for field in fields:
            data[field] = payload.get(field) if isinstance(payload, dict) else None
        if meta['status'] != 'UP':
            errors.append({'source': key, **meta})

    return JsonResponse({
        **data,
        'sources': sources,
        'errors': errors,
        'complete': not errors,
        'generated_at': timezone.now().isoformat(),
    }, json_dumps_params={'ensure_ascii': False})


def index(request):
    return JsonResponse({
        'name': 'Nhà Trọ — API Gateway',
        'port': settings.GATEWAY_PORT,
        'endpoints': {
            '/api/system/health/': 'Trạng thái thực tế của Gateway và 5 service',
            '/api/dashboard/summary/': 'Số liệu tổng hợp cho Dashboard (cần đăng nhập)',
        },
        'routes': route_table(),
    }, json_dumps_params={'ensure_ascii': False})
