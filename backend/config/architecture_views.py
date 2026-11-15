import json
import time
import urllib.request
from django.conf import settings
from django.db import connections
from django.http import HttpResponse
from rest_framework import permissions
from rest_framework.response import Response
from rest_framework.views import APIView


SOA_SERVICES_META = [
    {
        'id': 1,
        'key': 'identity',
        'name': 'SERVICE 1 — IDENTITY & AUTHENTICATION',
        'short_name': 'Identity Service',
        'port': 8001,
        'portal_path': '/identity/',
        'base_url': 'http://127.0.0.1:8001',
        'health_url': 'http://127.0.0.1:8001/health/',
        'api_root': 'http://127.0.0.1:8001/api/v1/auth/test-users/',
        'db_alias': 'default',
        'database': 'nhatro_identity_db',
        'sprint': 'SPRINT 1 (Đang hoạt động)',
        'is_active_sprint': True,
        'color': '#2563eb',
        'description': 'Xác thực người dùng bằng JWT Stateless, phân quyền RBAC (ADMIN, LANDLORD, STAFF, TENANT).',
        'endpoints': [
            {'method': 'POST', 'path': '/api/v1/auth/login/', 'desc': 'Đăng nhập nhận cặp JWT Access & Refresh Token'},
            {'method': 'POST', 'path': '/api/v1/auth/refresh/', 'desc': 'Làm mới Access Token'},
            {'method': 'POST', 'path': '/api/v1/auth/register/', 'desc': 'Đăng ký tài khoản mới'},
            {'method': 'GET', 'path': '/api/v1/auth/me/', 'desc': 'Lấy thông tin tài khoản hiện tại theo JWT'},
            {'method': 'GET', 'path': '/api/v1/auth/test-users/', 'desc': 'Danh sách tài khoản mẫu để test nhanh'},
            {'method': 'GET', 'path': '/api/v1/users/', 'desc': 'Quản lý danh sách người dùng'},
        ],
    },
    {
        'id': 2,
        'key': 'property',
        'name': 'SERVICE 2 — PROPERTY & MAINTENANCE SERVICE',
        'short_name': 'Property & Maintenance',
        'port': 8002,
        'portal_path': '/property/',
        'base_url': 'http://127.0.0.1:8002',
        'health_url': 'http://127.0.0.1:8002/health/',
        'api_root': 'http://127.0.0.1:8002/api/v1/properties/',
        'db_alias': 'property_db',
        'database': 'nhatro_property_db',
        'sprint': 'SPRINT 1 (Đang hoạt động)',
        'is_active_sprint': True,
        'color': '#16a34a',
        'description': 'Quản lý toàn bộ tài sản vật lý: Nhà trọ (Property), Phòng trọ (Room), Trạng thái phòng, Tìm kiếm/Lọc/Sắp xếp và Bảo trì (Maintenance Request & History).',
        'endpoints': [
            {'method': 'GET/POST', 'path': '/api/v1/properties/', 'desc': 'I.1 & I.2: Danh sách, Tìm kiếm, Lọc & Thêm nhà trọ'},
            {'method': 'GET/PATCH/DELETE', 'path': '/api/v1/properties/{id}/', 'desc': 'I.3, I.4, I.5: Chi tiết, Cập nhật & Soft Delete nhà trọ'},
            {'method': 'POST', 'path': '/api/v1/properties/{id}/update_status/', 'desc': 'I.5: Đổi trạng thái nhà trọ (ACTIVE / INACTIVE / DELETED)'},
            {'method': 'GET/POST', 'path': '/api/v1/rooms/', 'desc': 'II, IV, V, VI: Danh sách, Tìm kiếm, Lọc, Sắp xếp & Thêm phòng'},
            {'method': 'GET/PATCH/DELETE', 'path': '/api/v1/rooms/{id}/', 'desc': 'II.3, II.4, II.5: Chi tiết, Cập nhật & Soft Delete phòng'},
            {'method': 'GET/POST', 'path': '/api/v1/rooms/{id}/status/', 'desc': 'III.1 & III.2: Xem & Cập nhật trạng thái phòng (AVAILABLE, OCCUPIED, FULL, MAINTENANCE, INACTIVE)'},
            {'method': 'GET', 'path': '/api/v1/rooms/{id}/check_rentable/', 'desc': 'III.3: Kiểm tra phòng có thể thuê hay không'},
            {'method': 'GET', 'path': '/api/v1/rooms/available/', 'desc': 'III.4: Danh sách phòng trống'},
            {'method': 'GET', 'path': '/api/v1/rooms/occupied/', 'desc': 'III.5: Danh sách phòng đang thuê'},
            {'method': 'GET', 'path': '/api/v1/rooms/maintenance/', 'desc': 'III.6: Danh sách phòng đang bảo trì'},
            {'method': 'GET/POST', 'path': '/api/v1/maintenance/', 'desc': 'VII.1 & VII.2: Tạo & Xem danh sách yêu cầu bảo trì'},
            {'method': 'GET/PATCH', 'path': '/api/v1/maintenance/{id}/', 'desc': 'VII.3 & VII.4: Chi tiết & Cập nhật yêu cầu bảo trì'},
            {'method': 'POST', 'path': '/api/v1/maintenance/{id}/update_status/', 'desc': 'VII.5: Cập nhật trạng thái bảo trì (PENDING → IN_PROGRESS → COMPLETED / CANCELLED)'},
            {'method': 'POST', 'path': '/api/v1/maintenance/{id}/record_cost/', 'desc': 'VII.6: Ghi nhận chi phí dự kiến & chi phí thực tế'},
            {'method': 'POST', 'path': '/api/v1/maintenance/{id}/complete/', 'desc': 'VII.7: Hoàn thành bảo trì & chuyển phòng về AVAILABLE'},
            {'method': 'GET', 'path': '/api/v1/maintenance-history/', 'desc': 'VII.8: Xem toàn bộ lịch sử bảo trì'},
        ],
    },
    {
        'id': 3,
        'key': 'tenant',
        'name': 'SERVICE 3 — TENANT MANAGEMENT SERVICE',
        'short_name': 'Tenant Service',
        'port': 8003,
        'portal_path': '/tenant/',
        'base_url': 'http://127.0.0.1:8003',
        'health_url': 'http://127.0.0.1:8003/health/',
        'api_root': 'http://127.0.0.1:8003/api/v1/tenants/status/',
        'db_alias': 'tenant_db',
        'database': 'nhatro_tenant_db',
        'sprint': 'SPRINT 2 (Lộ trình tiếp theo)',
        'is_active_sprint': False,
        'color': '#0d9488',
        'description': 'Quản lý hồ sơ định danh khách thuê (CCCD/CMND), đăng ký tạm trú và lịch sử cư trú.',
        'endpoints': [
            {'method': 'GET', 'path': '/health/', 'desc': 'Kiểm tra trạng thái sức khỏe Service 3'},
            {'method': 'GET', 'path': '/api/v1/tenants/status/', 'desc': 'Trạng thái & lộ trình tính năng Sprint 2'},
        ],
    },
    {
        'id': 4,
        'key': 'contract',
        'name': 'SERVICE 4 — CONTRACT MANAGEMENT SERVICE',
        'short_name': 'Contract Service',
        'port': 8004,
        'portal_path': '/contract/',
        'base_url': 'http://127.0.0.1:8004',
        'health_url': 'http://127.0.0.1:8004/health/',
        'api_root': 'http://127.0.0.1:8004/api/v1/contracts/status/',
        'db_alias': 'contract_db',
        'database': 'nhatro_contract_db',
        'sprint': 'SPRINT 2 (Lộ trình tiếp theo)',
        'is_active_sprint': False,
        'color': '#7c3aed',
        'description': 'Quản lý hợp đồng thuê phòng, gia hạn hợp đồng, thanh lý và hoàn trả tiền cọc.',
        'endpoints': [
            {'method': 'GET', 'path': '/health/', 'desc': 'Kiểm tra trạng thái sức khỏe Service 4'},
            {'method': 'GET', 'path': '/api/v1/contracts/status/', 'desc': 'Trạng thái & lộ trình tính năng Sprint 2'},
        ],
    },
    {
        'id': 5,
        'key': 'billing',
        'name': 'SERVICE 5 — BILLING & NOTIFICATION SERVICE',
        'short_name': 'Billing Service',
        'port': 8005,
        'portal_path': '/billing/',
        'base_url': 'http://127.0.0.1:8005',
        'health_url': 'http://127.0.0.1:8005/health/',
        'api_root': 'http://127.0.0.1:8005/api/v1/billing/status/',
        'db_alias': 'billing_db',
        'database': 'nhatro_billing_db',
        'sprint': 'SPRINT 3 (Lộ trình tiếp theo)',
        'is_active_sprint': False,
        'color': '#ea580c',
        'description': 'Tính hóa đơn tiền phòng + điện nước tự động, tạo mã VietQR và gửi thông báo.',
        'endpoints': [
            {'method': 'GET', 'path': '/health/', 'desc': 'Kiểm tra trạng thái sức khỏe Service 5'},
            {'method': 'GET', 'path': '/api/v1/billing/status/', 'desc': 'Trạng thái & lộ trình tính năng Sprint 3'},
        ],
    },
]


def check_database_health(db_key):
    try:
        t0 = time.perf_counter()
        conn = connections[db_key]
        with conn.cursor() as cursor:
            cursor.execute("SELECT 1")
            row = cursor.fetchone()
        ms = round((time.perf_counter() - t0) * 1000, 1)
        db_name = settings.DATABASES[db_key].get('NAME', 'unknown')
        return {
            'status': 'HEALTHY' if row and row[0] == 1 else 'WARNING',
            'database_name': str(db_name),
            'engine': settings.DATABASES[db_key].get('ENGINE', 'unknown').split('.')[-1],
            'latency_ms': ms,
        }
    except Exception as e:
        return {
            'status': 'DISCONNECTED',
            'database_name': str(settings.DATABASES.get(db_key, {}).get('NAME', db_key)),
            'error': str(e),
        }


def ping_service_port(health_url, timeout=0.6):
    t0 = time.perf_counter()
    try:
        req = urllib.request.Request(health_url, headers={'Accept': 'application/json'})
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            ms = round((time.perf_counter() - t0) * 1000, 1)
            return {'online': resp.status == 200, 'http_status': resp.status, 'latency_ms': ms}
    except Exception as e:
        ms = round((time.perf_counter() - t0) * 1000, 1)
        return {'online': False, 'http_status': 0, 'latency_ms': ms, 'error': str(e)}


class ArchitectureStatusView(APIView):
    """
    Endpoint kiểm tra toàn diện trạng thái Kiến trúc SOA, kết nối 5 Database độc lập
    và kiểm tra cổng mạng (Port 8001 -> 8005) của từng Microservice.
    """
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        db_status = {
            db_key: check_database_health(db_key)
            for db_key in ['default', 'property_db', 'tenant_db', 'contract_db', 'billing_db']
        }

        check_ports = request.query_params.get('ping_ports', 'true').lower() != 'false'
        services_report = []
        for svc in SOA_SERVICES_META:
            item = dict(svc)
            item['db_health'] = db_status.get(svc['db_alias'], {})
            if check_ports:
                item['port_health'] = ping_service_port(svc['health_url'])
            services_report.append(item)

        return Response({
            'architecture': 'SOA Microservices (Mỗi service 1 Port riêng & 1 Database riêng)',
            'gateway_url': 'http://127.0.0.1:8000',
            'api_docs_url': 'http://127.0.0.1:8000/api-docs/',
            'swagger_url': 'http://127.0.0.1:8000/api/docs/',
            'ports': {
                'gateway_portal': 8000,
                'identity_service': 8001,
                'property_maintenance_service': 8002,
                'tenant_service': 8003,
                'contract_service': 8004,
                'billing_service': 8005,
            },
            'databases_health': db_status,
            'services': services_report,
            'status': 'ONLINE',
        })


def make_service_root_view(service_key, extra_info=None):
    """
    Tạo View cho đường dẫn gốc '/' và '/health/' của từng standalone service (8001 -> 8005)
    để KHÔNG BAO GIỜ bị lỗi 404 Page Not Found khi truy cập trực tiếp trên trình duyệt.
    """
    svc_meta = next((s for s in SOA_SERVICES_META if s['key'] == service_key), SOA_SERVICES_META[0])

    class StandaloneServiceRootView(APIView):
        permission_classes = [permissions.AllowAny]

        def get(self, request):
            db_health = check_database_health(svc_meta['db_alias'])
            payload = {
                'service': svc_meta['name'],
                'key': svc_meta['key'],
                'port': svc_meta['port'],
                'base_url': svc_meta['base_url'],
                'portal_url': f"http://127.0.0.1:8000{svc_meta['portal_path']}",
                'api_docs_url': 'http://127.0.0.1:8000/api-docs/',
                'database': svc_meta['database'],
                'database_health': db_health,
                'status': 'HEALTHY',
                'sprint': svc_meta['sprint'],
                'description': svc_meta['description'],
                'endpoints': svc_meta['endpoints'],
            }
            if extra_info:
                payload.update(extra_info)

            # Nếu gọi đường dẫn /health/ hoặc yêu cầu JSON
            accept = request.META.get('HTTP_ACCEPT', '')
            if request.path.rstrip('/').endswith('/health') or request.GET.get('format') == 'json' or (
                'application/json' in accept and 'text/html' not in accept
            ):
                return Response(payload)

            # Hiển thị giao diện HTML trực quan cho Service đó trên đúng Port của nó
            nav_links = ''.join(
                f'<a href="{s["base_url"]}/" class="nav-pill {"active" if s["key"] == service_key else ""}" '
                f'style="--c:{s["color"]}">:{s["port"]} {s["short_name"]}</a>'
                for s in SOA_SERVICES_META
            )
            ep_rows = ''.join(
                f'<tr>'
                f'<td><span class="badge-method">{ep["method"]}</span></td>'
                f'<td><a href="{svc_meta["base_url"]}{ep["path"]}" class="ep-link">{svc_meta["base_url"]}{ep["path"]}</a></td>'
                f'<td>{ep["desc"]}</td>'
                f'</tr>'
                for ep in svc_meta['endpoints']
            )
            db_badge = (
                f'<span style="color:#16a34a;font-weight:700">● HEALTHY ({db_health.get("latency_ms", 0)}ms)</span>'
                if db_health.get('status') == 'HEALTHY'
                else f'<span style="color:#dc2626;font-weight:700">● {db_health.get("status")}</span>'
            )

            html = f"""<!DOCTYPE html>
<html lang="vi">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{svc_meta['name']} — Port {svc_meta['port']}</title>
<style>
  *{{box-sizing:border-box;margin:0;padding:0}}
  body{{font-family:'Segoe UI',system-ui,-apple-system,sans-serif;background:#f8fafc;color:#0f172a;line-height:1.5}}
  .topbar{{background:#0f172a;color:#fff;padding:12px 24px;display:flex;align-items:center;justify-content:space-between;flex-wrap:wrap;gap:12px}}
  .brand{{display:flex;align-items:center;gap:10px;font-weight:800;font-size:15px;color:#fff;text-decoration:none}}
  .nav-list{{display:flex;align-items:center;gap:8px;flex-wrap:wrap}}
  .nav-pill{{padding:6px 12px;border-radius:8px;font-size:12.5px;font-weight:700;color:#cbd5e1;text-decoration:none;border:1px solid #334155;transition:.15s}}
  .nav-pill:hover{{background:#1e293b;color:#fff}}
  .nav-pill.active{{background:var(--c);color:#fff;border-color:var(--c)}}
  .nav-portal{{background:#2563eb;color:#fff;padding:6px 14px;border-radius:8px;font-size:12.5px;font-weight:800;text-decoration:none}}
  .container{{max-width:1080px;margin:28px auto;padding:0 20px}}
  .hero{{background:#fff;border-radius:16px;padding:24px;border:1px solid #e2e8f0;border-top:5px solid {svc_meta['color']};box-shadow:0 4px 12px rgba(15,23,42,.04)}}
  .tag-row{{display:flex;gap:10px;align-items:center;flex-wrap:wrap;margin-bottom:12px}}
  .tag{{padding:4px 10px;border-radius:6px;font-size:12px;font-weight:800;background:#f1f5f9;color:#334155}}
  .tag-port{{background:{svc_meta['color']}18;color:{svc_meta['color']};border:1px solid {svc_meta['color']}40}}
  h1{{font-size:22px;font-weight:900;margin-bottom:8px}}
  .desc{{color:#475569;font-size:14px;margin-bottom:20px}}
  .meta-grid{{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:12px;margin-bottom:20px}}
  .meta-box{{background:#f8fafc;border:1px solid #e2e8f0;border-radius:10px;padding:12px 14px}}
  .meta-label{{font-size:11px;font-weight:700;color:#64748b;text-transform:uppercase}}
  .meta-val{{font-size:14px;font-weight:800;color:#0f172a;margin-top:2px}}
  .btn-row{{display:flex;gap:10px;flex-wrap:wrap}}
  .btn{{display:inline-flex;align-items:center;gap:6px;padding:10px 16px;border-radius:10px;font-size:13px;font-weight:800;text-decoration:none;cursor:pointer;border:none}}
  .btn-primary{{background:{svc_meta['color']};color:#fff}}
  .btn-outline{{background:#fff;color:#0f172a;border:1px solid #cbd5e1}}
  .card{{background:#fff;border-radius:16px;padding:22px;border:1px solid #e2e8f0;margin-top:20px}}
  .card h2{{font-size:16px;font-weight:800;margin-bottom:14px}}
  table{{width:100%;border-collapse:collapse;font-size:13.5px}}
  th,td{{text-align:left;padding:11px 12px;border-bottom:1px solid #f1f5f9}}
  th{{font-size:11.5px;text-transform:uppercase;color:#64748b;background:#f8fafc}}
  .badge-method{{background:#eff6ff;color:#1d4ed8;padding:3px 8px;border-radius:6px;font-weight:800;font-size:11.5px;font-family:monospace}}
  .ep-link{{font-family:monospace;font-weight:700;color:#2563eb;text-decoration:none}}
  .ep-link:hover{{text-decoration:underline}}
</style>
</head>
<body>
  <div class="topbar">
    <a href="http://127.0.0.1:8000/" class="brand">🏢 HỆ THỐNG QUẢN LÝ NHÀ TRỌ SOA</a>
    <div class="nav-list">
      <a href="http://127.0.0.1:8000{svc_meta['portal_path']}" class="nav-portal">⚡ Giao diện Tổng hợp (Port 8000)</a>
      <a href="http://127.0.0.1:8000/api-docs/" class="nav-pill">📡 API Docs & Health Check</a>
      {nav_links}
    </div>
  </div>
  <div class="container">
    <div class="hero">
      <div class="tag-row">
        <span class="tag tag-port">PORT {svc_meta['port']}</span>
        <span class="tag">DATABASE: {svc_meta['database']}</span>
        <span class="tag">{svc_meta['sprint']}</span>
      </div>
      <h1>{svc_meta['name']}</h1>
      <p class="desc">{svc_meta['description']}</p>
      <div class="meta-grid">
        <div class="meta-box">
          <div class="meta-label">Service URL hiện tại</div>
          <div class="meta-val">{svc_meta['base_url']}/</div>
        </div>
        <div class="meta-box">
          <div class="meta-label">Trạng thái Microservice</div>
          <div class="meta-val" style="color:#16a34a">● ONLINE (HTTP 200 OK)</div>
        </div>
        <div class="meta-box">
          <div class="meta-label">Kết nối Database ({svc_meta['database']})</div>
          <div class="meta-val">{db_badge}</div>
        </div>
      </div>
      <div class="btn-row">
        <a href="http://127.0.0.1:8000{svc_meta['portal_path']}" class="btn btn-primary">🚀 Mở Quản lý {svc_meta['short_name']} trên Port 8000</a>
        <a href="http://127.0.0.1:8000/api-docs/" class="btn btn-outline">📋 Mở Trang Kiểm Tra API & Health Check</a>
        <a href="{svc_meta['base_url']}/health/?format=json" class="btn btn-outline">🔍 Xem JSON Health</a>
      </div>
    </div>

    <div class="card">
      <h2>Danh sách API Endpoints trên Port {svc_meta['port']}</h2>
      <table>
        <thead>
          <tr><th style="width:140px">Method</th><th>Endpoint URL</th><th>Mô tả chức năng</th></tr>
        </thead>
        <tbody>
          {ep_rows}
        </tbody>
      </table>
    </div>
  </div>
</body>
</html>"""
            return HttpResponse(html, content_type='text/html; charset=utf-8')

    return StandaloneServiceRootView
