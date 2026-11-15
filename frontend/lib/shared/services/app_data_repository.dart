import 'package:flutter/foundation.dart';

import '../../core/constants/api_constants.dart';
import '../../models/dashboard_summary_model.dart';
import '../../models/system_health_model.dart';
import '../models/app_models.dart';
import 'api_client.dart';

/// Repository dữ liệu của ứng dụng (Clean Architecture).
///
/// - MỌI request đi qua API Gateway (:8000). Flutter không gọi trực tiếp 5 service (8001–8005);
///   việc định tuyến, kiểm tra health và tổng hợp số liệu Dashboard do Gateway đảm nhiệm.
/// - Khi đã đăng nhập và Gateway phản hồi: Nhà trọ / Phòng / Bảo trì là dữ liệu THẬT
///   (kể cả khi danh sách rỗng), Dashboard lấy từ /api/dashboard/summary/,
///   trạng thái SOA lấy từ /api/system/health/.
/// - Khi chưa kết nối được Gateway: hiển thị dữ liệu mẫu (Mock Data) để demo giao diện,
///   cờ [isBackendConnected] = false.
class AppDataRepository extends ChangeNotifier {
  bool isBackendConnected = false;
  bool isSyncing = false;
  String? lastSyncError;

  /// Trạng thái thực tế Gateway + 5 service (null = chưa kiểm tra).
  SystemHealth? systemHealth;

  /// Số liệu Dashboard do Gateway tổng hợp (null = chưa có / Gateway lỗi).
  DashboardSummary? dashboardSummary;
  String? dashboardError;

  late List<PropertyItem> _properties;
  late List<RoomItem> _rooms;
  late List<TenantItem> _tenants;
  late List<ContractItem> _contracts;
  late List<InvoiceItem> _invoices;
  late List<MaintenanceItem> _maintenances;
  late List<NotificationItem> _notifications;
  late List<MonthlyRevenuePoint> _revenuePoints;

  AppDataRepository() {
    _seedMockData();
  }

  List<PropertyItem> get properties => List.unmodifiable(_properties);
  List<RoomItem> get rooms => List.unmodifiable(_rooms);
  List<TenantItem> get tenants => List.unmodifiable(_tenants);
  List<ContractItem> get contracts => List.unmodifiable(_contracts);
  List<InvoiceItem> get invoices => List.unmodifiable(_invoices);
  List<MaintenanceItem> get maintenances => List.unmodifiable(_maintenances);
  List<NotificationItem> get notifications => List.unmodifiable(_notifications);
  List<MonthlyRevenuePoint> get revenuePoints => List.unmodifiable(_revenuePoints);

  /// Trạng thái từng service theo port (dùng cho trang Cài đặt). Không có dữ liệu -> false.
  Map<int, bool> get portStatus => {
        for (final s in systemHealth?.services ?? const <ServiceHealth>[]) s.port: s.status == ServiceStatus.up,
      };

  // Dashboard computed statistics (dữ liệu cục bộ; Dashboard ưu tiên [dashboardSummary])
  int get totalPropertiesCount => _properties.length;
  int get totalRoomsCount => _rooms.length;
  int get occupiedRoomsCount =>
      _rooms.where((r) => r.status == 'OCCUPIED' || r.status == 'RESERVED').length;
  int get availableRoomsCount =>
      _rooms.where((r) => r.status == 'AVAILABLE').length;
  int get maintenanceRoomsCount =>
      _rooms.where((r) => r.status == 'MAINTENANCE').length;
  int get activeContractsCount =>
      _contracts.where((c) => c.status == 'ACTIVE' || c.status == 'EXPIRING').length;
  int get unpaidInvoicesCount =>
      _invoices.where((i) => i.status == 'UNPAID' || i.status == 'OVERDUE').length;
  int get unreadNotificationCount =>
      _notifications.where((n) => !n.isRead).length;

  void _seedMockData() {
    _properties = [
      const PropertyItem(
        id: 1,
        code: 'NT-001',
        name: 'Khu nhà trọ Bình Thạnh Rivera',
        address: '142 Nguyễn Gia Trí, Phường 25, Quận Bình Thạnh, TP.HCM',
        district: 'Quận Bình Thạnh',
        ward: 'Phường 25',
        totalRooms: 8,
        occupiedRooms: 5,
        availableRooms: 2,
        maintenanceRooms: 1,
        status: 'ACTIVE',
        description: 'Khu căn hộ dịch vụ mini gần ĐH HUTECH, có thang máy, khóa vân tay.',
      ),
      const PropertyItem(
        id: 2,
        code: 'NT-002',
        name: 'Nhà trọ Sinh viên Thủ Đức Garden',
        address: '58 Hoàng Diệu 2, Phường Linh Chiểu, TP. Thủ Đức, TP.HCM',
        district: 'TP. Thủ Đức',
        ward: 'Phường Linh Chiểu',
        totalRooms: 6,
        occupiedRooms: 4,
        availableRooms: 2,
        maintenanceRooms: 0,
        status: 'ACTIVE',
        description: 'Khu nhà trọ yên tĩnh, sân để xe rộng rãi, camera an ninh 24/7.',
      ),
      const PropertyItem(
        id: 3,
        code: 'NT-003',
        name: 'Căn hộ Mini Quận 7 Lotus',
        address: '215 Nguyễn Thị Thập, Phường Tân Phú, Quận 7, TP.HCM',
        district: 'Quận 7',
        ward: 'Phường Tân Phú',
        totalRooms: 6,
        occupiedRooms: 4,
        availableRooms: 1,
        maintenanceRooms: 1,
        status: 'ACTIVE',
        description: 'Gần Lotte Mart Quận 7, đầy đủ nội thất máy lạnh, tủ lạnh, máy giặt.',
      ),
      const PropertyItem(
        id: 4,
        code: 'NT-004',
        name: 'Nhà trọ Gò Vấp Parkview',
        address: '89 Quang Trung, Phường 10, Quận Gò Vấp, TP.HCM',
        district: 'Quận Gò Vấp',
        ward: 'Phường 10',
        totalRooms: 4,
        occupiedRooms: 2,
        availableRooms: 2,
        maintenanceRooms: 0,
        status: 'INACTIVE',
        description: 'Đang nâng cấp hệ thống phòng cháy chữa cháy định kỳ.',
      ),
    ];

    _rooms = [
      const RoomItem(
        id: 101,
        code: 'P-A101',
        name: 'Phòng A101',
        propertyId: 1,
        propertyName: 'Khu nhà trọ Bình Thạnh Rivera',
        floor: 1,
        rentPrice: 3800000,
        area: 24,
        currentOccupants: 2,
        maxOccupants: 2,
        status: 'OCCUPIED',
        description: 'Có ban công thoáng mát, máy lạnh Inverter, kệ bếp.',
      ),
      const RoomItem(
        id: 102,
        code: 'P-A102',
        name: 'Phòng A102',
        propertyId: 1,
        propertyName: 'Khu nhà trọ Bình Thạnh Rivera',
        floor: 1,
        rentPrice: 3500000,
        area: 22,
        currentOccupants: 0,
        maxOccupants: 2,
        status: 'AVAILABLE',
        description: 'Phòng mới sơn sửa, đầy đủ bình nóng lạnh, bàn làm việc.',
      ),
      const RoomItem(
        id: 103,
        code: 'P-A201',
        name: 'Phòng A201',
        propertyId: 1,
        propertyName: 'Khu nhà trọ Bình Thạnh Rivera',
        floor: 2,
        rentPrice: 4200000,
        area: 28,
        currentOccupants: 2,
        maxOccupants: 3,
        status: 'OCCUPIED',
        description: 'Phòng góc 2 cửa sổ, nội thất cao cấp.',
      ),
      const RoomItem(
        id: 104,
        code: 'P-A202',
        name: 'Phòng A202',
        propertyId: 1,
        propertyName: 'Khu nhà trọ Bình Thạnh Rivera',
        floor: 2,
        rentPrice: 4000000,
        area: 25,
        currentOccupants: 0,
        maxOccupants: 2,
        status: 'MAINTENANCE',
        description: 'Đang bảo trì hệ thống điều hòa và chống thấm ban công.',
      ),
      const RoomItem(
        id: 201,
        code: 'P-B101',
        name: 'Phòng B101',
        propertyId: 2,
        propertyName: 'Nhà trọ Sinh viên Thủ Đức Garden',
        floor: 1,
        rentPrice: 2600000,
        area: 18,
        currentOccupants: 2,
        maxOccupants: 2,
        status: 'OCCUPIED',
        description: 'Phòng có gác lửng, phù hợp 2 sinh viên.',
      ),
      const RoomItem(
        id: 202,
        code: 'P-B102',
        name: 'Phòng B102',
        propertyId: 2,
        propertyName: 'Nhà trọ Sinh viên Thủ Đức Garden',
        floor: 1,
        rentPrice: 2800000,
        area: 20,
        currentOccupants: 0,
        maxOccupants: 2,
        status: 'AVAILABLE',
        description: 'Phòng trống tầng trệt, tiện để xe.',
      ),
      const RoomItem(
        id: 203,
        code: 'P-B201',
        name: 'Phòng B201',
        propertyId: 2,
        propertyName: 'Nhà trọ Sinh viên Thủ Đức Garden',
        floor: 2,
        rentPrice: 3000000,
        area: 22,
        currentOccupants: 1,
        maxOccupants: 2,
        status: 'RESERVED',
        description: 'Khách đã đặt cọc giữ phòng, nhận phòng đầu tháng.',
      ),
      const RoomItem(
        id: 301,
        code: 'P-C101',
        name: 'Phòng C101',
        propertyId: 3,
        propertyName: 'Căn hộ Mini Quận 7 Lotus',
        floor: 1,
        rentPrice: 4800000,
        area: 30,
        currentOccupants: 2,
        maxOccupants: 3,
        status: 'OCCUPIED',
        description: 'Full nội thất: sofa, tủ lạnh, máy giặt riêng.',
      ),
      const RoomItem(
        id: 302,
        code: 'P-C102',
        name: 'Phòng C102',
        propertyId: 3,
        propertyName: 'Căn hộ Mini Quận 7 Lotus',
        floor: 1,
        rentPrice: 4500000,
        area: 28,
        currentOccupants: 0,
        maxOccupants: 2,
        status: 'AVAILABLE',
        description: 'Căn hộ studio cửa sổ lớn hướng Đông Nam.',
      ),
    ];

    _tenants = [
      const TenantItem(
        id: 1,
        fullName: 'Trần Minh Hoàng',
        phone: '0908 124 567',
        email: 'hoang.tran@gmail.com',
        idCard: '079098001234',
        currentRoom: 'Phòng A101',
        propertyName: 'Khu nhà trọ Bình Thạnh Rivera',
        startDate: '01/02/2026',
        status: 'ACTIVE',
      ),
      const TenantItem(
        id: 2,
        fullName: 'Lê Thị Ngọc Ánh',
        phone: '0912 345 890',
        email: 'ngocanh.le@outlook.com',
        idCard: '079199004512',
        currentRoom: 'Phòng A201',
        propertyName: 'Khu nhà trọ Bình Thạnh Rivera',
        startDate: '15/01/2026',
        status: 'ACTIVE',
      ),
      const TenantItem(
        id: 3,
        fullName: 'Phạm Quốc Bảo',
        phone: '0987 654 321',
        email: 'quocbao.pham@gmail.com',
        idCard: '075097008911',
        currentRoom: 'Phòng B101',
        propertyName: 'Nhà trọ Sinh viên Thủ Đức Garden',
        startDate: '01/09/2025',
        status: 'ACTIVE',
      ),
      const TenantItem(
        id: 4,
        fullName: 'Nguyễn Thảo Vy',
        phone: '0933 221 908',
        email: 'thaovy.nguyen@gmail.com',
        idCard: '079200003389',
        currentRoom: 'Phòng C101',
        propertyName: 'Căn hộ Mini Quận 7 Lotus',
        startDate: '10/03/2026',
        status: 'ACTIVE',
      ),
      const TenantItem(
        id: 5,
        fullName: 'Võ Đăng Khoa',
        phone: '0971 882 119',
        email: 'dangkhoa.vo@gmail.com',
        idCard: '079196007721',
        currentRoom: 'Phòng B201',
        propertyName: 'Nhà trọ Sinh viên Thủ Đức Garden',
        startDate: '01/05/2025',
        status: 'TEMPORARY_ABSENT',
      ),
      const TenantItem(
        id: 6,
        fullName: 'Đặng Thu Hà',
        phone: '0945 612 300',
        email: 'thuha.dang@gmail.com',
        idCard: '079198005510',
        currentRoom: 'Phòng A102',
        propertyName: 'Khu nhà trọ Bình Thạnh Rivera',
        startDate: '01/03/2025',
        status: 'MOVED_OUT',
      ),
    ];

    _contracts = [
      const ContractItem(
        id: 1,
        code: 'HD-2026-001',
        tenantName: 'Trần Minh Hoàng',
        roomName: 'Phòng A101',
        propertyName: 'Khu nhà trọ Bình Thạnh Rivera',
        startDate: '01/02/2026',
        endDate: '01/02/2027',
        rentPrice: 3800000,
        depositAmount: 7600000,
        status: 'ACTIVE',
      ),
      const ContractItem(
        id: 2,
        code: 'HD-2026-002',
        tenantName: 'Lê Thị Ngọc Ánh',
        roomName: 'Phòng A201',
        propertyName: 'Khu nhà trọ Bình Thạnh Rivera',
        startDate: '15/01/2026',
        endDate: '15/01/2027',
        rentPrice: 4200000,
        depositAmount: 8400000,
        status: 'ACTIVE',
      ),
      const ContractItem(
        id: 3,
        code: 'HD-2025-018',
        tenantName: 'Phạm Quốc Bảo',
        roomName: 'Phòng B101',
        propertyName: 'Nhà trọ Sinh viên Thủ Đức Garden',
        startDate: '01/09/2025',
        endDate: '30/11/2026',
        rentPrice: 2600000,
        depositAmount: 5200000,
        status: 'EXPIRING',
      ),
      const ContractItem(
        id: 4,
        code: 'HD-2026-009',
        tenantName: 'Nguyễn Thảo Vy',
        roomName: 'Phòng C101',
        propertyName: 'Căn hộ Mini Quận 7 Lotus',
        startDate: '10/03/2026',
        endDate: '10/03/2027',
        rentPrice: 4800000,
        depositAmount: 9600000,
        status: 'ACTIVE',
      ),
      const ContractItem(
        id: 5,
        code: 'HD-2025-004',
        tenantName: 'Đặng Thu Hà',
        roomName: 'Phòng A102',
        propertyName: 'Khu nhà trọ Bình Thạnh Rivera',
        startDate: '01/03/2025',
        endDate: '01/03/2026',
        rentPrice: 3500000,
        depositAmount: 7000000,
        status: 'EXPIRED',
      ),
    ];

    _invoices = [
      const InvoiceItem(
        id: 1,
        code: 'INV-202611-01',
        tenantName: 'Trần Minh Hoàng',
        roomName: 'Phòng A101',
        propertyName: 'Khu nhà trọ Bình Thạnh Rivera',
        billingMonth: '11/2026',
        totalAmount: 4350000,
        dueDate: '05/11/2026',
        status: 'PAID',
      ),
      const InvoiceItem(
        id: 2,
        code: 'INV-202611-02',
        tenantName: 'Lê Thị Ngọc Ánh',
        roomName: 'Phòng A201',
        propertyName: 'Khu nhà trọ Bình Thạnh Rivera',
        billingMonth: '11/2026',
        totalAmount: 4720000,
        dueDate: '15/11/2026',
        status: 'UNPAID',
      ),
      const InvoiceItem(
        id: 3,
        code: 'INV-202611-03',
        tenantName: 'Phạm Quốc Bảo',
        roomName: 'Phòng B101',
        propertyName: 'Nhà trọ Sinh viên Thủ Đức Garden',
        billingMonth: '11/2026',
        totalAmount: 2980000,
        dueDate: '05/11/2026',
        status: 'OVERDUE',
      ),
      const InvoiceItem(
        id: 4,
        code: 'INV-202611-04',
        tenantName: 'Nguyễn Thảo Vy',
        roomName: 'Phòng C101',
        propertyName: 'Căn hộ Mini Quận 7 Lotus',
        billingMonth: '11/2026',
        totalAmount: 5390000,
        dueDate: '18/11/2026',
        status: 'UNPAID',
      ),
      const InvoiceItem(
        id: 5,
        code: 'INV-202610-01',
        tenantName: 'Trần Minh Hoàng',
        roomName: 'Phòng A101',
        propertyName: 'Khu nhà trọ Bình Thạnh Rivera',
        billingMonth: '10/2026',
        totalAmount: 4280000,
        dueDate: '05/10/2026',
        status: 'PAID',
      ),
    ];

    _maintenances = [
      const MaintenanceItem(
        id: 1,
        code: 'BT-001',
        roomId: 104,
        roomName: 'Phòng A202',
        propertyName: 'Khu nhà trọ Bình Thạnh Rivera',
        title: 'Điều hòa không lạnh, cần vệ sinh và nạp gas',
        description: 'Máy lạnh Daikin 1.5HP chạy nhưng không mát, rò nước nhẹ ở dàn lạnh.',
        createdAt: '10/11/2026',
        priority: 'HIGH',
        status: 'IN_PROGRESS',
        estimatedCost: 500000,
        actualCost: 450000,
      ),
      const MaintenanceItem(
        id: 2,
        code: 'BT-002',
        roomId: 101,
        roomName: 'Phòng A101',
        propertyName: 'Khu nhà trọ Bình Thạnh Rivera',
        title: 'Thay vòi sen và dây cấp nước phòng tắm',
        description: 'Vòi sen bị rỉ nước ở khớp nối.',
        createdAt: '08/11/2026',
        priority: 'MEDIUM',
        status: 'PENDING',
        estimatedCost: 250000,
        actualCost: 0,
      ),
      const MaintenanceItem(
        id: 3,
        code: 'BT-003',
        roomId: 201,
        roomName: 'Phòng B101',
        propertyName: 'Nhà trọ Sinh viên Thủ Đức Garden',
        title: 'Sửa ổ khóa vân tay cửa chính',
        description: 'Cảm biến vân tay chập chờn, đã thay pin và hiệu chỉnh.',
        createdAt: '02/11/2026',
        priority: 'HIGH',
        status: 'COMPLETED',
        estimatedCost: 400000,
        actualCost: 350000,
      ),
      const MaintenanceItem(
        id: 4,
        code: 'BT-004',
        roomId: 301,
        roomName: 'Phòng C101',
        propertyName: 'Căn hộ Mini Quận 7 Lotus',
        title: 'Thay bóng đèn LED âm trần khu vực bếp',
        description: 'Cháy 2 bóng đèn LED 9W.',
        createdAt: '01/11/2026',
        priority: 'LOW',
        status: 'COMPLETED',
        estimatedCost: 150000,
        actualCost: 140000,
      ),
    ];

    _notifications = [
      const NotificationItem(
        id: 1,
        title: 'Hóa đơn quá hạn thanh toán',
        message: 'Hóa đơn INV-202611-03 (Phòng B101 - Phạm Quốc Bảo) đã quá hạn thanh toán.',
        createdAt: '2 giờ trước',
        category: 'BILLING',
        isRead: false,
      ),
      const NotificationItem(
        id: 2,
        title: 'Yêu cầu bảo trì mới',
        message: 'Phòng A101 gửi yêu cầu bảo trì BT-002: Thay vòi sen phòng tắm.',
        createdAt: '5 giờ trước',
        category: 'MAINTENANCE',
        isRead: false,
      ),
      const NotificationItem(
        id: 3,
        title: 'Hợp đồng sắp hết hạn trong 15 ngày',
        message: 'Hợp đồng HD-2025-018 của khách Phạm Quốc Bảo (Phòng B101) sẽ hết hạn vào 30/11/2026.',
        createdAt: '1 ngày trước',
        category: 'CONTRACT',
        isRead: false,
      ),
      const NotificationItem(
        id: 4,
        title: 'Hoàn tất bảo trì phòng B101',
        message: 'Yêu cầu BT-003 đã được nghiệm thu hoàn thành với chi phí 350.000 đ.',
        createdAt: '3 ngày trước',
        category: 'MAINTENANCE',
        isRead: true,
      ),
    ];

    _revenuePoints = const [
      MonthlyRevenuePoint(monthLabel: 'T6', amountInMillions: 52.0),
      MonthlyRevenuePoint(monthLabel: 'T7', amountInMillions: 56.5),
      MonthlyRevenuePoint(monthLabel: 'T8', amountInMillions: 54.0),
      MonthlyRevenuePoint(monthLabel: 'T9', amountInMillions: 61.2),
      MonthlyRevenuePoint(monthLabel: 'T10', amountInMillions: 64.8),
      MonthlyRevenuePoint(monthLabel: 'T11', amountInMillions: 68.5),
    ];
  }

  // =====================================================================
  // GATEWAY: HEALTH & DASHBOARD (từ nhánh origin/baodev)
  // =====================================================================

  /// Trạng thái thực tế của Gateway + 5 service.
  /// Không ném lỗi: nếu Gateway không phản hồi thì Gateway = DOWN, các service = UNKNOWN.
  Future<SystemHealth> fetchSystemHealth() async {
    try {
      final res = await ApiClient.get(ApiConstants.systemHealth, requireAuth: false);
      if (res is Map<String, dynamic>) {
        return SystemHealth.fromJson(res);
      }
      return SystemHealth.gatewayUnreachable('Phản hồi không hợp lệ từ API Gateway.');
    } catch (e) {
      return SystemHealth.gatewayUnreachable(e.toString());
    }
  }

  /// Số liệu Dashboard tổng hợp (theo phạm vi quyền của user đang đăng nhập).
  /// Ném [ApiException] khi Gateway lỗi hoặc token hết hạn.
  Future<DashboardSummary> fetchDashboardSummary() async {
    final res = await ApiClient.get(ApiConstants.dashboardSummary);
    if (res is Map<String, dynamic>) {
      return DashboardSummary.fromJson(res);
    }
    throw ApiException('Phản hồi không hợp lệ từ API Gateway.');
  }

  /// Chỉ kiểm tra trạng thái hệ thống (không cần đăng nhập).
  Future<void> refreshSystemHealth() async {
    systemHealth = await fetchSystemHealth();
    notifyListeners();
  }

  /// Đồng bộ dữ liệu thật qua API Gateway (cần đã đăng nhập).
  Future<void> syncWithBackend() async {
    if (isSyncing) return;
    isSyncing = true;
    lastSyncError = null;
    notifyListeners();

    try {
      systemHealth = await fetchSystemHealth();
      if (systemHealth!.gatewayStatus != ServiceStatus.up) {
        isBackendConnected = false;
        lastSyncError = systemHealth!.error ?? 'API Gateway không phản hồi.';
        return;
      }

      try {
        dashboardSummary = await fetchDashboardSummary();
        dashboardError = null;
      } on ApiException catch (e) {
        dashboardSummary = null;
        dashboardError = e.message;
      }

      final rawProps = await ApiClient.get(ApiConstants.properties);
      final rawRooms = await ApiClient.get(ApiConstants.rooms);
      final rawMaint = await ApiClient.get(ApiConstants.maintenance);

      // Đã kết nối: thay toàn bộ dữ liệu mẫu bằng dữ liệu thật (kể cả khi rỗng).
      _properties = rawProps is List
          ? rawProps.whereType<Map<String, dynamic>>().map(_propertyFromJson).toList()
          : <PropertyItem>[];
      _rooms = rawRooms is List
          ? rawRooms.whereType<Map<String, dynamic>>().map(_roomFromJson).toList()
          : <RoomItem>[];
      _maintenances = rawMaint is List
          ? rawMaint.whereType<Map<String, dynamic>>().map(_maintenanceFromJson).toList()
          : <MaintenanceItem>[];
      isBackendConnected = true;
    } on ApiException catch (e) {
      isBackendConnected = false;
      lastSyncError = e.message;
    } catch (e) {
      isBackendConnected = false;
      lastSyncError = e.toString();
    } finally {
      isSyncing = false;
      notifyListeners();
    }
  }

  /// Gọi khi đăng xuất: bỏ dữ liệu thật của phiên trước, quay về dữ liệu mẫu.
  void resetAfterLogout() {
    isBackendConnected = false;
    dashboardSummary = null;
    dashboardError = null;
    lastSyncError = null;
    _seedMockData();
    notifyListeners();
  }

  // ---------------- JSON MAPPING ----------------
  static int _int(dynamic v, [int fallback = 0]) =>
      v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? fallback;
  static double _double(dynamic v, [double fallback = 0]) =>
      v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? fallback;

  static PropertyItem _propertyFromJson(Map<String, dynamic> p) => PropertyItem(
        id: _int(p['id']),
        code: '${p['code'] ?? 'NT-${p['id']}'}',
        name: '${p['name'] ?? ''}',
        address: '${p['full_address'] ?? p['address'] ?? ''}',
        district: '${p['district'] ?? ''}',
        ward: '${p['ward'] ?? ''}',
        totalRooms: _int(p['total_rooms_count']),
        occupiedRooms: _int(p['occupied_rooms_count']),
        availableRooms: _int(p['available_rooms_count']),
        maintenanceRooms: _int(p['maintenance_rooms_count']),
        status: '${p['status'] ?? 'ACTIVE'}',
        description: '${p['description'] ?? ''}',
      );

  static RoomItem _roomFromJson(Map<String, dynamic> r) {
    final st = '${r['status'] ?? 'AVAILABLE'}';
    return RoomItem(
      id: _int(r['id']),
      code: '${r['code'] ?? ''}',
      name: '${r['room_number'] ?? ''}',
      propertyId: _int(r['property']),
      propertyName: '${r['property_name'] ?? ''}',
      floor: _int(r['floor'], 1),
      rentPrice: _double(r['rent_price']),
      area: _double(r['area'], 20),
      currentOccupants: _int(r['current_occupants']),
      maxOccupants: _int(r['max_occupants'], 2),
      // Giao diện gộp FULL (đủ người) vào "Đang thuê".
      status: st == 'FULL' ? 'OCCUPIED' : st,
      description: '${r['description'] ?? ''}',
    );
  }

  static MaintenanceItem _maintenanceFromJson(Map<String, dynamic> m) => MaintenanceItem(
        id: _int(m['id']),
        code: '${m['code'] ?? ''}',
        roomId: _int(m['room']),
        roomName: '${m['room_number'] ?? ''}',
        propertyName: '${m['property_name'] ?? ''}',
        title: '${m['title'] ?? ''}',
        description: '${m['description'] ?? ''}',
        createdAt: '${m['requested_date'] ?? ''}',
        priority: '${m['priority'] ?? 'MEDIUM'}',
        status: '${m['status'] ?? 'PENDING'}',
        estimatedCost: _double(m['estimated_cost']),
        actualCost: _double(m['actual_cost']),
      );

  /// Thực hiện thao tác ghi qua Gateway rồi đồng bộ lại. Trả về null nếu thành công,
  /// ngược lại trả về thông báo lỗi để UI hiển thị.
  Future<String?> _remoteWrite(Future<dynamic> Function() call) async {
    try {
      await call();
      await syncWithBackend();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // ---------------- CRUD PROPERTY ----------------
  Map<String, dynamic> _propertyPayload(PropertyItem item) => {
        'name': item.name,
        'address': item.address,
        'district': item.district,
        'ward': item.ward,
        'status': item.status,
        'description': item.description,
        if (item.code.isNotEmpty) 'code': item.code,
      };

  Future<String?> addProperty(PropertyItem item) async {
    if (isBackendConnected) {
      return _remoteWrite(() => ApiClient.post(ApiConstants.properties, _propertyPayload(item)));
    }
    _properties = [item, ..._properties];
    notifyListeners();
    return null;
  }

  Future<String?> updateProperty(PropertyItem updated) async {
    if (isBackendConnected) {
      return _remoteWrite(
          () => ApiClient.patch('${ApiConstants.properties}${updated.id}/', _propertyPayload(updated)));
    }
    _properties = [
      for (final p in _properties) p.id == updated.id ? updated : p,
    ];
    notifyListeners();
    return null;
  }

  Future<String?> deleteProperty(int id) async {
    if (isBackendConnected) {
      return _remoteWrite(() => ApiClient.delete('${ApiConstants.properties}$id/'));
    }
    _properties = _properties.where((p) => p.id != id).toList();
    notifyListeners();
    return null;
  }

  // ---------------- CRUD ROOM ----------------
  Map<String, dynamic> _roomPayload(RoomItem item) => {
        'property': item.propertyId,
        'room_number': item.name,
        'floor': item.floor,
        'rent_price': item.rentPrice,
        'area': item.area,
        'max_occupants': item.maxOccupants,
        'current_occupants': item.currentOccupants,
        'status': item.status,
        'description': item.description,
        if (item.code.isNotEmpty) 'code': item.code,
      };

  Future<String?> addRoom(RoomItem item) async {
    if (isBackendConnected) {
      return _remoteWrite(() => ApiClient.post(ApiConstants.rooms, _roomPayload(item)));
    }
    _rooms = [item, ..._rooms];
    _recalculatePropertyCounts();
    notifyListeners();
    return null;
  }

  Future<String?> updateRoom(RoomItem updated) async {
    if (isBackendConnected) {
      return _remoteWrite(() => ApiClient.patch('${ApiConstants.rooms}${updated.id}/', _roomPayload(updated)));
    }
    _rooms = [
      for (final r in _rooms) r.id == updated.id ? updated : r,
    ];
    _recalculatePropertyCounts();
    notifyListeners();
    return null;
  }

  Future<String?> deleteRoom(int id) async {
    if (isBackendConnected) {
      return _remoteWrite(() => ApiClient.delete('${ApiConstants.rooms}$id/'));
    }
    _rooms = _rooms.where((r) => r.id != id).toList();
    _recalculatePropertyCounts();
    notifyListeners();
    return null;
  }

  void _recalculatePropertyCounts() {
    _properties = _properties.map((p) {
      final pRooms = _rooms.where((r) => r.propertyId == p.id).toList();
      if (pRooms.isEmpty) return p;
      return p.copyWith(
        totalRooms: pRooms.length,
        occupiedRooms: pRooms.where((r) => r.status == 'OCCUPIED' || r.status == 'RESERVED').length,
        availableRooms: pRooms.where((r) => r.status == 'AVAILABLE').length,
        maintenanceRooms: pRooms.where((r) => r.status == 'MAINTENANCE').length,
      );
    }).toList();
  }

  // ---------------- CRUD TENANT ----------------
  void addTenant(TenantItem item) {
    _tenants = [item, ..._tenants];
    notifyListeners();
  }

  void updateTenant(TenantItem updated) {
    _tenants = [
      for (final t in _tenants) t.id == updated.id ? updated : t,
    ];
    notifyListeners();
  }

  void deleteTenant(int id) {
    _tenants = _tenants.where((t) => t.id != id).toList();
    notifyListeners();
  }

  // ---------------- CRUD CONTRACT ----------------
  void addContract(ContractItem item) {
    _contracts = [item, ..._contracts];
    notifyListeners();
  }

  void updateContract(ContractItem updated) {
    _contracts = [
      for (final c in _contracts) c.id == updated.id ? updated : c,
    ];
    notifyListeners();
  }

  void deleteContract(int id) {
    _contracts = _contracts.where((c) => c.id != id).toList();
    notifyListeners();
  }

  // ---------------- CRUD INVOICE ----------------
  void addInvoice(InvoiceItem item) {
    _invoices = [item, ..._invoices];
    notifyListeners();
  }

  void updateInvoice(InvoiceItem updated) {
    _invoices = [
      for (final i in _invoices) i.id == updated.id ? updated : i,
    ];
    notifyListeners();
  }

  void deleteInvoice(int id) {
    _invoices = _invoices.where((i) => i.id != id).toList();
    notifyListeners();
  }

  // ---------------- CRUD MAINTENANCE ----------------
  /// Form bảo trì nhập tên phòng dạng chữ -> tìm id phòng thật (theo tên/mã, có thể kèm tên nhà trọ).
  int? _resolveRoomId(MaintenanceItem item) {
    if (item.roomId > 0) return item.roomId;
    final name = item.roomName.trim().toLowerCase();
    final prop = item.propertyName.trim().toLowerCase();
    final matches = _rooms.where((r) =>
        r.name.toLowerCase() == name || r.code.toLowerCase() == name || 'phòng ${r.name}'.toLowerCase() == name);
    final narrowed = prop.isEmpty ? matches : matches.where((r) => r.propertyName.toLowerCase() == prop);
    final list = narrowed.isNotEmpty ? narrowed.toList() : matches.toList();
    return list.length == 1 ? list.first.id : null;
  }

  Future<String?> addMaintenance(MaintenanceItem item) async {
    if (isBackendConnected) {
      final roomId = _resolveRoomId(item);
      if (roomId == null) {
        return 'Không xác định được phòng "${item.roomName}". Nhập đúng tên hoặc mã phòng (kèm tên nhà trọ nếu trùng).';
      }
      return _remoteWrite(() => ApiClient.post(ApiConstants.maintenance, {
            'room': roomId,
            'title': item.title,
            'description': item.description,
            'priority': item.priority,
            'estimated_cost': item.estimatedCost,
          }));
    }
    _maintenances = [item, ..._maintenances];
    notifyListeners();
    return null;
  }

  Future<String?> updateMaintenance(MaintenanceItem updated) async {
    if (isBackendConnected) {
      final current = _maintenances.where((m) => m.id == updated.id).firstOrNull;
      return _remoteWrite(() async {
        await ApiClient.patch('${ApiConstants.maintenance}${updated.id}/', {
          'title': updated.title,
          'description': updated.description,
          'priority': updated.priority,
          'estimated_cost': updated.estimatedCost,
          'actual_cost': updated.actualCost,
        });
        // Trạng thái bảo trì chỉ đổi qua action để backend đồng bộ trạng thái phòng + lịch sử.
        if (current != null && current.status != updated.status && updated.status != 'PENDING') {
          await ApiClient.post('${ApiConstants.maintenance}${updated.id}/update_status/', {'status': updated.status});
        }
      });
    }
    _maintenances = [
      for (final m in _maintenances) m.id == updated.id ? updated : m,
    ];
    notifyListeners();
    return null;
  }

  Future<String?> deleteMaintenance(int id) async {
    if (isBackendConnected) {
      return _remoteWrite(() => ApiClient.delete('${ApiConstants.maintenance}$id/'));
    }
    _maintenances = _maintenances.where((m) => m.id != id).toList();
    notifyListeners();
    return null;
  }

  // ---------------- NOTIFICATIONS ----------------
  void markAllNotificationsRead() {
    _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    notifyListeners();
  }

  void toggleNotificationRead(int id) {
    _notifications = [
      for (final n in _notifications)
        n.id == id ? n.copyWith(isRead: !n.isRead) : n,
    ];
    notifyListeners();
  }
}

