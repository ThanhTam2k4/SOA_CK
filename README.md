# 🏢 Hệ Thống Quản Lý Nhà Trọ — Kiến Trúc SOA Microservices

Hệ thống được thiết kế theo kiến trúc **Service-Oriented Architecture (SOA)**:
- **Mỗi Service chạy trên 1 Port riêng biệt** (`8001` → `8005`) và sở hữu **1 Database SQL Server độc lập** (không dùng Foreign Key chéo giữa các service).
- **Port `8000`** đóng vai trò là **Cổng Giao Diện Web Tổng Hợp (Unified Web Portal)**, **API Gateway** và **Trang API Docs & Kiểm Tra Sức Khỏe Hệ Thống (Health Check)**.
- **Xác thực JWT Stateless**: Identity Service (`8001`) phát hành JWT chứa sẵn thông tin phân quyền (`user_id`, `username`, `role`), giúp các service khác xác thực yêu cầu độc lập.

---

## 🌐 Danh Sách Cổng Dịch Vụ (Ports) & Databases

| Cổng (Port) | Tên Dịch Vụ / Giao Diện | Database (SQL Server) | URL Truy Cập |
| :---: | :--- | :--- | :--- |
| **`8000`** | **Giao Diện Web Tổng Hợp & API Gateway** | *(Điều hướng 5 DB)* | `http://127.0.0.1:8000/` |
| **`8000`** | **Trang API Docs & Kiểm Tra Hoạt Động Services** | *(Live Health Check)* | `http://127.0.0.1:8000/api-docs/` |
| **`8001`** | **Service 1 — Identity & Authentication** | `nhatro_identity_db` | `http://127.0.0.1:8001/` |
| **`8002`** | **Service 2 — Property & Maintenance Service** | `nhatro_property_db` | `http://127.0.0.1:8002/` |
| **`8003`** | **Service 3 — Tenant Service (Sprint 2)** | `nhatro_tenant_db` | `http://127.0.0.1:8003/` |
| **`8004`** | **Service 4 — Contract Service (Sprint 2)** | `nhatro_contract_db` | `http://127.0.0.1:8004/` |
| **`8005`** | **Service 5 — Billing & Notification (Sprint 3)** | `nhatro_billing_db` | `http://127.0.0.1:8005/` |

---

## 🚀 Cách Khởi Chạy Toàn Bộ Hệ Thống (`run_all`)

Từ thư mục gốc của project, chạy 1 trong 2 lệnh sau để bật đồng thời cả 6 cổng (`8000` → `8005`):

```powershell
python run_all.py
```
Hoặc chạy file batch trên Windows:
```powershell
.\run_all.bat
```

Sau khi chạy, mở trình duyệt tại:
- **Giao diện Quản lý Tổng hợp**: [http://127.0.0.1:8000/](http://127.0.0.1:8000/)
- **Trang API Docs & Kiểm tra Services**: [http://127.0.0.1:8000/api-docs/](http://127.0.0.1:8000/api-docs/)
- **Swagger OpenAPI UI**: [http://127.0.0.1:8000/api/docs/](http://127.0.0.1:8000/api/docs/)

### Tài khoản kiểm thử mặc định
- **Chủ nhà trọ (`LANDLORD`)**: `chutro1` / `chutropassword123`
- **Quản trị viên (`ADMIN`)**: `admin` / `adminpassword123`
- **Khách thuê (`TENANT`)**: `khach1` / `khachpassword123`

---

## 📁 Cấu Trúc Thư Mục Đã Tối Giản

```text
nhatro_management/
├── run_all.py                        # Script khởi chạy đồng thời tất cả Services (Port 8000 -> 8005)
├── run_all.bat                       # File chạy nhanh trên Windows
├── README.md                         # Tài liệu hướng dẫn
└── backend/
    ├── manage.py
    ├── create_db.py                  # Khởi tạo 5 Databases trên SQL Server
    ├── seed_data.py                  # Nạp dữ liệu mẫu cho Identity, Property, Room & Maintenance
    ├── run_all_services.py           # Bộ điều phối tiến trình đa cổng (Multi-port runner)
    ├── templates/
    │   ├── portal.html               # Giao diện Web Tổng hợp trên Port 8000
    │   └── api_docs.html             # Trang API Docs & Kiểm tra hoạt động các Services
    ├── config/
    │   ├── settings.py               # Cấu hình Multi-DB, JWT, CORS
    │   ├── db_router.py              # SOA Database Router (Database-per-service)
    │   ├── service_auth.py           # Xác thực Stateless JWT
    │   ├── architecture_views.py     # Health Check & Trang chủ riêng cho từng Port
    │   └── urls.py                   # Định tuyến Port 8000
    └── services/
        ├── identity_service/         # Service 1 (Port 8001)
        ├── property_service/         # Service 2 (Port 8002): Property, Room, Status, Maintenance
        ├── tenant_service/           # Service 3 (Port 8003)
        ├── contract_service/         # Service 4 (Port 8004)
        └── billing_notification_service/ # Service 5 (Port 8005)
```
