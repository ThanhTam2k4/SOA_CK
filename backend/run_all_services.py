import os
import subprocess
import sys
import time

SERVICES = [
    ('API Gateway & Giao Diện Web Tổng Hợp (Port 8000)', 'config.urls', 8000),
    ('Service 1: Identity & Authentication (Port 8001)', 'services.identity_service.standalone_urls', 8001),
    ('Service 2: Property & Maintenance Service (Port 8002)', 'services.property_service.standalone_urls', 8002),
    ('Service 3: Tenant Service (Port 8003)', 'services.tenant_service.standalone_urls', 8003),
    ('Service 4: Contract Service (Port 8004)', 'services.contract_service.standalone_urls', 8004),
    ('Service 5: Billing & Notification Service (Port 8005)', 'services.billing_notification_service.standalone_urls', 8005),
]


def main():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    manage_py = os.path.join(base_dir, 'manage.py')
    python_bin = sys.executable

    # Cho phép lọc theo port nếu truyền tham số (VD: python run_all_services.py 8002)
    filter_arg = sys.argv[1].strip() if len(sys.argv) > 1 else None
    selected = [
        s for s in SERVICES
        if not filter_arg or filter_arg == str(s[2]) or filter_arg.lower() in s[0].lower()
    ]

    print("=" * 76)
    print("🚀 KHỞI ĐỘNG HỆ THỐNG SOA MICROSERVICES — QUẢN LÝ NHÀ TRỌ")
    print("=" * 76)
    for name, urlconf, port in selected:
        print(f"  • {name:<54} -> http://127.0.0.1:{port}/")
    print("-" * 76)
    print("  🌟 GIAO DIỆN QUẢN LÝ TỔNG HỢP (WEB UI) : http://127.0.0.1:8000/")
    print("  📡 TRANG API DOCS & KIỂM TRA SERVICES   : http://127.0.0.1:8000/api-docs/")
    print("  📘 SWAGGER OPENAPI UI                   : http://127.0.0.1:8000/api/docs/")
    print("=" * 76)

    processes = []
    try:
        for name, urlconf, port in selected:
            env = os.environ.copy()
            env['DJANGO_SETTINGS_MODULE'] = 'config.settings'
            env['ROOT_URLCONF'] = urlconf
            print(f"[Starting] {name}...")
            p = subprocess.Popen(
                [python_bin, manage_py, 'runserver', f'127.0.0.1:{port}', '--noreload'],
                cwd=base_dir,
                env=env,
            )
            processes.append((name, port, p))
            time.sleep(0.4)

        print("\n✅ TẤT CẢ SERVICES ĐÃ KHỞI ĐỘNG THÀNH CÔNG!")
        print("👉 Mở trình duyệt tại: http://127.0.0.1:8000/ hoặc http://127.0.0.1:8000/api-docs/")
        print("Nhấn Ctrl + C để dừng toàn bộ hệ thống.\n")

        while True:
            time.sleep(2)
            for name, port, p in processes:
                if p.poll() is not None:
                    print(f"⚠️ {name} (Port {port}) đã dừng (exit code {p.returncode})")
                    return

    except KeyboardInterrupt:
        print("\n🛑 Đang tắt toàn bộ Microservices...")
    finally:
        for _, _, p in processes:
            if p.poll() is None:
                p.terminate()
        for _, _, p in processes:
            try:
                p.wait(timeout=3)
            except Exception:
                p.kill()
        print("👋 Đã tắt toàn bộ services an toàn.")


if __name__ == '__main__':
    main()
