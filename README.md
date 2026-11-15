# HỆ THỐNG QUẢN LÝ NHÀ TRỌ (SOA — API GATEWAY + 5 SERVICES)

- **Frontend**: Flutter (Provider, Material 3) — chỉ giao tiếp với **API Gateway :8000**
- **Backend**: Django REST Framework + SimpleJWT — 1 Gateway + 5 service, **mỗi service 1 process, 1 port, 1 database**
- **Database**: Microsoft SQL Server (mssql-django) hoặc SQLite (`DB_ENGINE=sqlite`)

---

## 🏛️ KIẾN TRÚC

```
Flutter Web
     │  (chỉ gọi :8000)
     ▼
API Gateway :8000  ── /api/system/health/      (kiểm tra /health/ của 5 service)
     │             ── /api/dashboard/summary/  (tổng hợp số liệu Dashboard)
     │
     ├── /api/auth/*, /api/users/*                        ─► Identity Service              :8001  nhatro_identity_db
     ├── /api/properties/*, /api/rooms/*, /api/maintenance/* ─► Property & Maintenance     :8002  nhatro_property_db
     ├── /api/tenants/*                                   ─► Tenant Service                :8003  nhatro_tenant_db
     ├── /api/contracts/*                                 ─► Contract Service              :8004  nhatro_contract_db
     └── /api/billing/*, /api/notifications/*             ─► Billing & Notification        :8005  nhatro_billing_db
```

| Service | Port | Trách nhiệm (owner dữ liệu) |
| :--- | :--- | :--- |
| **Identity** | 8001 | Đăng ký, đăng nhập, JWT access/refresh, đăng xuất (blacklist), đổi mật khẩu, tài khoản, role |
| **Property & Maintenance** | 8002 | Nhà trọ, phòng (giá, diện tích, số người tối đa/hiện tại, trạng thái, lọc giá), yêu cầu bảo trì |
| **Tenant** | 8003 | Hồ sơ người thuê, liên hệ, lịch sử thuê (**không** quản lý mật khẩu) |
| **Contract** | 8004 | Hợp đồng: tạo, cập nhật, kích hoạt, gia hạn, kết thúc, lịch sử |
| **Billing & Notification** | 8005 | Hóa đơn (phòng/điện/nước/dịch vụ), thanh toán, công nợ, thông báo |

**Nguyên tắc SOA đang áp dụng**
- Mỗi service chạy với settings riêng (`backend/config/service_settings/<service>.py`): chỉ cài app của nó và chỉ có database của nó → không thể truy vấn model của service khác.
- Liên kết giữa service bằng **ID** (`owner_id`, `room_id`, `tenant_id`, `contract_id`, `user_id`), không có Foreign Key chéo.
- Xác thực **stateless**: Identity ký JWT có claim `role`, `username`, `is_superuser`; các service khác chỉ xác minh chữ ký (cùng `JWT_SIGNING_KEY`), không đọc DB Identity.
- CORS chỉ bật ở Gateway → trình duyệt không gọi trực tiếp được 8001–8005.
- `backend/common/` là thư viện hạ tầng dùng chung (health check, đọc role từ JWT) — không chứa model nghiệp vụ.

---

## 🚀 KHỞI CHẠY

### 1. Backend

```bash
cd backend
.\venv\Scripts\Activate.ps1          # hoặc: source venv/bin/activate
pip install -r requirements.txt

# (SQL Server) tạo 5 database nếu chưa có
python create_db.py

# Migrate DB của từng service + chạy Gateway và 5 service
python run_all_services.py --migrate

# (cửa sổ khác) nạp dữ liệu mẫu
python seed_data.py
```

Các lần sau chỉ cần `python run_all_services.py`. Dùng SQLite: đặt `DB_ENGINE=sqlite` trong `.env`.

Chạy riêng 1 service (ví dụ để debug):

```bash
python manage.py runserver 8002 --settings=config.service_settings.property
cd api_gateway && python manage.py runserver 8000
```

> Nâng cấp từ bản cũ (1 server :8000): chạy `python run_all_services.py --migrate` một lần — lệnh này áp dụng migration mới (bảo trì, hồ sơ người thuê, lịch sử hợp đồng, token blacklist...) vào đúng database của từng service. Người dùng cần **đăng nhập lại** để nhận JWT có claim `role`.

### 2. Kiểm tra

```bash
cd backend
python run_tests.py          # test từng service với settings riêng + test Gateway
```

- Trạng thái hệ thống: `http://127.0.0.1:8000/api/system/health/`
- Swagger của từng service: `http://127.0.0.1:800X/api/docs/`

### 3. Frontend

```bash
cd frontend
flutter pub get
flutter run -d chrome
# Gateway ở địa chỉ khác:
flutter run -d chrome --dart-define=API_GATEWAY_URL=http://192.168.1.10:8000
```

---

## 🔌 ENDPOINT CHÍNH (qua Gateway :8000)

| Nhóm | Endpoint |
| :--- | :--- |
| Hệ thống | `GET /api/system/health/` · `GET /api/dashboard/summary/` (cần token) |
| Auth | `POST /api/auth/login/` · `refresh/` · `register/` · `logout/` · `change-password/` · `GET/PATCH /api/auth/me/` · `/api/users/` |
| Nhà trọ / Phòng | `/api/properties/` (+ `{id}/rooms/`, `{id}/stats/`, `summary/`) · `/api/rooms/?property_id=&status=&min_price=&max_price=&search=` · `PATCH /api/rooms/{id}/status/` |
| Bảo trì | `/api/maintenance/` · `POST {id}/start/` · `{id}/complete/` · `{id}/cancel/` |
| Người thuê | `/api/tenants/?search=&status=&room_id=` · `GET/POST {id}/history/` · `summary/` |
| Hợp đồng | `/api/contracts/?status=&room_id=&tenant_id=` · `POST {id}/activate/` · `{id}/extend/` · `{id}/terminate/` · `GET {id}/history/` · `summary/` |
| Hóa đơn | `/api/billing/invoices/?status=UNPAID|PAID|OVERDUE|DEBT` · `POST {id}/pay/` · `{id}/cancel/` · `GET debt/` · `summary/` |
| Thông báo | `/api/notifications/?unread=1&category=` · `POST {id}/read/` · `POST read-all/` |

`/api/v1/...` vẫn được Gateway chấp nhận (alias của `/api/...`) để tương thích client cũ.

---

## 🔑 TÀI KHOẢN MẪU (seed_data.py)

| Vai trò | Username | Password |
| :--- | :--- | :--- |
| **Chủ trọ (LANDLORD)** | `chutro1` | `chutropassword123` |
| **Quản trị viên (ADMIN)** | `admin` | `adminpassword123` |
| **Khách thuê (TENANT)** | `khach1` | `khachpassword123` |

---

## 📁 CẤU TRÚC THƯ MỤC

```
nhatro_management/
├── backend/
│   ├── api_gateway/                 # API GATEWAY :8000 (Django project riêng, không DB)
│   │   ├── config/                  #   settings (SERVICE_REGISTRY), urls
│   │   ├── gateway/                 #   proxy, system health, dashboard aggregation, tests
│   │   └── manage.py
│   ├── common/                      # Hạ tầng dùng chung: /health/, phân quyền theo JWT claims
│   ├── config/
│   │   ├── common.py                # Cấu hình chung (JWT, DRF, DB per service)
│   │   ├── service_settings/        # Settings riêng của 5 service (identity/property/tenant/contract/billing)
│   │   ├── settings.py              # TOOLBOX settings: seed/migrate thủ công (không chạy runtime)
│   │   └── db_router.py             # Router 5 DB cho toolbox settings
│   ├── services/
│   │   ├── identity_service/        # SERVICE 1 :8001
│   │   ├── property_service/        # SERVICE 2 :8002
│   │   ├── tenant_service/          # SERVICE 3 :8003
│   │   ├── contract_service/        # SERVICE 4 :8004
│   │   └── billing_notification_service/ # SERVICE 5 :8005
│   ├── run_all_services.py          # Chạy Gateway + 5 service
│   ├── run_tests.py                 # Test từng service độc lập + Gateway
│   └── seed_data.py
└── frontend/lib/
    ├── core/                        # api_constants (chỉ Gateway URL), api_client, theme, storage
    ├── features/dashboard/          # Dashboard: số liệu tổng hợp + trạng thái SOA thực tế
    ├── shared/services/             # app_data_repository.dart (health & summary qua Gateway)
    ├── models/ providers/ screens/ widgets/
    └── main.dart
```

## 🧭 LỘ TRÌNH TÁCH TIẾP

- Thông tin CCCD/địa chỉ hiện vẫn nằm trên `User` (Identity) và đồng thời có trong `TenantProfile`; sẽ chuyển hẳn sang Tenant Service.
- Đồng bộ giữa service (vd. ký hợp đồng → phòng OCCUPIED, gửi thông báo hợp đồng/bảo trì) hiện làm thủ công qua API; bước sau: event/message bus hoặc gọi API nội bộ có xác thực service-to-service.
- Màn hình Flutter cho Người thuê / Hợp đồng / Hóa đơn (backend API đã sẵn sàng).
