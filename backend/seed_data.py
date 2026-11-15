"""
Nạp dữ liệu mẫu vào database RIÊNG của từng service.

Script dev này dùng TOOLBOX settings (config.settings) để ghi lần lượt vào 5 database
qua ServiceDatabaseRouter. Liên kết giữa các service chỉ là ID (owner_id, room_id,
tenant_id...), không có Foreign Key chéo. Runtime KHÔNG dùng cách truy cập này —
mỗi service chỉ đọc/ghi database của chính nó.

Chạy sau khi đã migrate: python run_all_services.py --migrate (hoặc migrate từng service).
"""
import os
from datetime import timedelta

import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.contrib.auth import get_user_model  # noqa: E402
from django.utils import timezone  # noqa: E402
from services.billing_notification_service.models import Invoice, InvoiceStatus, Notification  # noqa: E402
from services.contract_service.models import Contract, ContractEvent, ContractStatus  # noqa: E402
from services.identity_service.models import UserRole  # noqa: E402
from services.property_service.models import MaintenanceRequest, Property, Room, RoomStatus  # noqa: E402
from services.tenant_service.models import RentalHistory, TenantProfile, TenantStatus  # noqa: E402

User = get_user_model()

def seed():
    print("=" * 60)
    print("🚀 SEEDING INITIAL DATA (SOA — 5 SERVICES)")
    print("=" * 60)

    # -------------------------------------------------------------
    # 1. IDENTITY SERVICE (default database: nhatro_identity_db)
    # -------------------------------------------------------------
    print("\n[1/5] Seeding Identity Service (nhatro_identity_db)...")

    # Admin
    admin_user, created = User.objects.using('default').get_or_create(
        username='admin',
        defaults={
            'email': 'admin@nhatro.vn',
            'first_name': 'Hệ Thống',
            'last_name': 'Admin',
            'role': UserRole.ADMIN,
            'is_staff': True,
            'is_superuser': True,
            'phone_number': '0900000001',
            'identity_card': '079090000001',
            'address': 'Quận 1, TP. Hồ Chí Minh'
        }
    )
    if created:
        admin_user.set_password('adminpassword123')
        admin_user.save(using='default')
        print("  [+] Admin user created: admin / adminpassword123")
    else:
        print("  [ok] Admin user already exists.")

    # Landlord (Chủ trọ)
    landlord, created = User.objects.using('default').get_or_create(
        username='chutro1',
        defaults={
            'email': 'chutro1@nhatro.vn',
            'first_name': 'Nguyễn Văn',
            'last_name': 'An',
            'role': UserRole.LANDLORD,
            'phone_number': '0901234567',
            'identity_card': '079092001122',
            'address': '123 Đường D2, P. 25, Q. Bình Thạnh, TP.HCM'
        }
    )
    if created:
        landlord.set_password('chutropassword123')
        landlord.save(using='default')
        print("  [+] Landlord user created: chutro1 / chutropassword123 (ID: %s)" % landlord.id)
    else:
        print("  [ok] Landlord user already exists (ID: %s)." % landlord.id)

    # Tenant (Khách thuê)
    tenant, created = User.objects.using('default').get_or_create(
        username='khach1',
        defaults={
            'email': 'khach1@gmail.com',
            'first_name': 'Trần Thị',
            'last_name': 'Mai',
            'role': UserRole.TENANT,
            'phone_number': '0912345678',
            'identity_card': '079198003344',
            'address': 'Tiền Giang'
        }
    )
    if created:
        tenant.set_password('khachpassword123')
        tenant.save(using='default')
        print("  [+] Tenant user created: khach1 / khachpassword123")
    else:
        print("  [ok] Tenant user already exists.")

    # -------------------------------------------------------------
    # 2. PROPERTY SERVICE (property_db: nhatro_property_db)
    # -------------------------------------------------------------
    print("\n[2/5] Seeding Property & Room Service (nhatro_property_db)...")
    landlord_id = landlord.id

    prop1, created = Property.objects.using('property_db').get_or_create(
        name='Nhà trọ Hoa Mai - Bình Thạnh',
        owner_id=landlord_id,
        defaults={
            'address': '45/12 Đường Nguyễn Gia Trí, Phường 25',
            'ward': 'Phường 25',
            'district': 'Bình Thạnh',
            'city': 'TP. Hồ Chí Minh',
            'total_floors': 3,
            'electricity_rate': 3800.0,
            'water_rate': 25000.0,
            'internet_rate': 100000.0,
            'description': 'Nhà trọ sinh viên gần ĐH Hutech, Ngoại Thương, an ninh 24/7.',
            'rules': '- Không tụ tập nhậu nhẹt sau 23h\n- Giữ gìn vệ sinh chung khuôn viên',
            'image_url': 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=800&q=80'
        }
    )
    if created:
        print("  [+] Property 1 created: Nhà trọ Hoa Mai (owner_id=%s)" % landlord_id)
    else:
        print("  [ok] Property 1 already exists.")

    prop2, created = Property.objects.using('property_db').get_or_create(
        name='Căn hộ Mini Happy House - Quận 7',
        owner_id=landlord_id,
        defaults={
            'address': '88 Đường số 7, KDC Tân Quy Đông',
            'ward': 'Tân Phong',
            'district': 'Quận 7',
            'city': 'TP. Hồ Chí Minh',
            'total_floors': 4,
            'electricity_rate': 4000.0,
            'water_rate': 30000.0,
            'internet_rate': 120000.0,
            'description': 'Căn hộ mini cao cấp full nội thất, thang máy, bãi đỗ xe hơi.',
            'rules': '- Cho nuôi thú cưng nhỏ có cam kết\n- Để xe đúng vị trí quy định',
            'image_url': 'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?auto=format&fit=crop&w=800&q=80'
        }
    )
    if created:
        print("  [+] Property 2 created: Happy House (owner_id=%s)" % landlord_id)
    else:
        print("  [ok] Property 2 already exists.")

    # Rooms for Property 1
    rooms_data_1 = [
        {
            'room_number': '101', 'floor': 1, 'area': 22.5, 'rent_price': 3500000,
            'deposit_amount': 3500000, 'max_occupants': 2, 'status': RoomStatus.AVAILABLE,
            'amenities': 'Gác lửng, Máy lạnh Inverter, Kệ bếp, WC riêng',
            'description': 'Phòng tầng trệt rộng rãi, thoáng mát.',
            'initial_electric_reading': 120.0, 'initial_water_reading': 45.0,
        },
        {
            'room_number': '102', 'floor': 1, 'area': 20.0, 'rent_price': 3200000,
            'deposit_amount': 3200000, 'max_occupants': 2, 'status': RoomStatus.OCCUPIED,
            'amenities': 'Gác lửng, Quạt trần, WC riêng',
            'description': 'Phòng đang cho sinh viên thuê.',
            'initial_electric_reading': 85.0, 'initial_water_reading': 30.0,
        },
        {
            'room_number': '201', 'floor': 2, 'area': 25.0, 'rent_price': 4200000,
            'deposit_amount': 4200000, 'max_occupants': 3, 'status': RoomStatus.AVAILABLE,
            'amenities': 'Ban công view đường, Máy lạnh, Tủ lạnh, WC riêng',
            'description': 'Phòng góc hai mặt thoáng gió mát mẻ.',
            'initial_electric_reading': 210.0, 'initial_water_reading': 60.0,
        },
        {
            'room_number': '202', 'floor': 2, 'area': 24.0, 'rent_price': 3900000,
            'deposit_amount': 3900000, 'max_occupants': 3, 'status': RoomStatus.RESERVED,
            'amenities': 'Máy lạnh, Gác lửng, Bình nước nóng',
            'description': 'Khách đã cọc giữ phòng đến 15 hàng tháng.',
            'initial_electric_reading': 150.0, 'initial_water_reading': 50.0,
        },
        {
            'room_number': '301', 'floor': 3, 'area': 20.0, 'rent_price': 3000000,
            'deposit_amount': 3000000, 'max_occupants': 2, 'status': RoomStatus.MAINTENANCE,
            'amenities': 'Gác lửng, Quạt trần, Cửa sổ thoáng',
            'description': 'Đang sửa chữa và sơn mới tường.',
            'initial_electric_reading': 40.0, 'initial_water_reading': 15.0,
        },
    ]

    for r_data in rooms_data_1:
        Room.objects.using('property_db').get_or_create(
            property=prop1,
            room_number=r_data['room_number'],
            defaults=r_data
        )

    # Rooms for Property 2
    rooms_data_2 = [
        {
            'room_number': 'P.101', 'floor': 1, 'area': 30.0, 'rent_price': 5500000,
            'deposit_amount': 5500000, 'max_occupants': 2, 'status': RoomStatus.AVAILABLE,
            'amenities': 'Full nội thất, Sofa, Máy giặt riêng, Smart TV',
            'description': 'Căn hộ Studio tiện nghi cao cấp.',
            'initial_electric_reading': 310.0, 'initial_water_reading': 80.0,
        },
        {
            'room_number': 'P.201', 'floor': 2, 'area': 32.0, 'rent_price': 6000000,
            'deposit_amount': 6000000, 'max_occupants': 3, 'status': RoomStatus.OCCUPIED,
            'amenities': 'Full nội thất cao cấp, Ban công riêng rộng',
            'description': 'Khách là chuyên gia thuê lâu dài.',
            'initial_electric_reading': 420.0, 'initial_water_reading': 110.0,
        },
    ]

    for r_data in rooms_data_2:
        Room.objects.using('property_db').get_or_create(
            property=prop2,
            room_number=r_data['room_number'],
            defaults=r_data
        )

    room_102 = Room.objects.using('property_db').get(property=prop1, room_number='102')
    room_p201 = Room.objects.using('property_db').get(property=prop2, room_number='P.201')
    room_301 = Room.objects.using('property_db').get(property=prop1, room_number='301')
    Room.objects.using('property_db').filter(pk__in=[room_102.pk, room_p201.pk], current_occupants=0) \
        .update(current_occupants=1)
    MaintenanceRequest.objects.using('property_db').get_or_create(
        room=room_301, title='Sơn lại tường & thay bóng đèn',
        defaults={'description': 'Tường bong tróc, đèn chập chờn.', 'priority': 'MEDIUM',
                  'reported_by_id': landlord_id, 'previous_room_status': RoomStatus.AVAILABLE})

    # -------------------------------------------------------------
    # 3. TENANT SERVICE (tenant_db)
    # -------------------------------------------------------------
    print("\n[3/5] Seeding Tenant Service (nhatro_tenant_db)...")
    today = timezone.localdate()
    tenant_profiles = []
    for data in [
        {'full_name': 'Trần Thị Mai', 'user_id': tenant.id, 'phone_number': '0912345678',
         'identity_card': '079198003344', 'hometown': 'Tiền Giang', 'occupation': 'Sinh viên',
         'room_id': room_102.id},
        {'full_name': 'Lê Hoàng Nam', 'user_id': None, 'phone_number': '0987654321',
         'identity_card': '079090112233', 'hometown': 'Đà Nẵng', 'occupation': 'Kỹ sư phần mềm',
         'room_id': room_p201.id},
    ]:
        profile, created = TenantProfile.objects.using('tenant_db').get_or_create(
            full_name=data['full_name'], landlord_id=landlord_id,
            defaults={**data, 'status': TenantStatus.ACTIVE})
        tenant_profiles.append(profile)
        RentalHistory.objects.using('tenant_db').get_or_create(
            tenant=profile, room_id=data['room_id'],
            defaults={'move_in_date': today - timedelta(days=60)})
        print("  [%s] Tenant profile: %s (room_id=%s)" % ('+' if created else 'ok', profile.full_name, data['room_id']))

    # -------------------------------------------------------------
    # 4. CONTRACT SERVICE (contract_db)
    # -------------------------------------------------------------
    print("\n[4/5] Seeding Contract Service (nhatro_contract_db)...")
    contracts = []
    for idx, (profile, room) in enumerate(zip(tenant_profiles, [room_102, room_p201]), start=1):
        contract, created = Contract.objects.using('contract_db').get_or_create(
            contract_number=f'HD-SEED-{idx:03d}',
            defaults={'room_id': room.id, 'tenant_id': profile.id, 'landlord_id': landlord_id,
                      'start_date': today - timedelta(days=60), 'end_date': today + timedelta(days=300),
                      'rental_price': room.rent_price, 'deposit_amount': room.deposit_amount,
                      'status': ContractStatus.ACTIVE})
        if created:
            ContractEvent.objects.using('contract_db').create(
                contract=contract, event_type='CREATED', actor_id=landlord_id, new_end_date=contract.end_date)
        contracts.append(contract)
        print("  [%s] Contract %s (room_id=%s, tenant_id=%s)" % (
            '+' if created else 'ok', contract.contract_number, contract.room_id, contract.tenant_id))

    # -------------------------------------------------------------
    # 5. BILLING & NOTIFICATION SERVICE (billing_db)
    # -------------------------------------------------------------
    print("\n[5/5] Seeding Billing & Notification Service (nhatro_billing_db)...")
    for idx, (contract, room, prop) in enumerate(zip(contracts, [room_102, room_p201], [prop1, prop2]), start=1):
        code = f'HDN-SEED-{idx:03d}'
        if Invoice.objects.using('billing_db').filter(invoice_code=code).exists():
            print("  [ok] Invoice %s already exists." % code)
            continue
        invoice = Invoice(
            invoice_code=code, room_id=room.id, contract_id=contract.id,
            tenant_id=contract.tenant_id, landlord_id=landlord_id,
            billing_month=today.month, billing_year=today.year, room_fee=room.rent_price,
            electricity_old_num=room.initial_electric_reading,
            electricity_new_num=room.initial_electric_reading + 80, electricity_unit_price=prop.electricity_rate,
            water_old_num=room.initial_water_reading, water_new_num=room.initial_water_reading + 5,
            water_unit_price=prop.water_rate, other_service_cost=prop.internet_rate,
            status=InvoiceStatus.UNPAID if idx == 1 else InvoiceStatus.PAID,
            paid_at=None if idx == 1 else timezone.now(), due_date=today + timedelta(days=5))
        invoice.calculate()
        invoice.save(using='billing_db')
        print("  [+] Invoice %s: %s VNĐ (%s)" % (invoice.invoice_code, invoice.total_amount, invoice.status))
    Notification.objects.using('billing_db').get_or_create(
        user_id=tenant.id, title='Hóa đơn tháng %s/%s' % (today.month, today.year),
        defaults={'content': 'Bạn có hóa đơn HDN-SEED-001 cần thanh toán trước hạn.',
                  'category': 'INVOICE', 'created_by_id': landlord_id})

    print("\n✅ SEEDING COMPLETED SUCCESSFULLY!")
    print("=" * 60)

if __name__ == '__main__':
    seed()
