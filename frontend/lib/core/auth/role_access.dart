/// Phân quyền truy cập trang theo vai trò (frontend).
///
/// Bám theo quyền thực tế của backend (JWT claim `role`):
/// - ADMIN / STAFF / LANDLORD: quản lý dữ liệu -> mọi trang.
/// - TENANT: Contract/Billing trả 403, Property/Room/Tenant chỉ đọc, Bảo trì có thao tác quản lý
///   (chi phí, trạng thái, phòng) -> KHÔNG vào các trang quản lý; chỉ dùng Thông báo (của mình)
///   và Cài đặt (hồ sơ cá nhân, đổi mật khẩu).
/// - Vai trò rỗng / không xác định: xử lý như TENANT (quyền tối thiểu).
///
/// Đây chỉ là lớp chặn giao diện; backend vẫn là nơi kiểm tra quyền cuối cùng.
class RoleAccess {
  RoleAccess._();

  static const managerRoles = {'ADMIN', 'STAFF', 'LANDLORD'};

  /// Trang quản lý — chỉ ADMIN / STAFF / LANDLORD.
  static const managerOnlyRoutes = [
    '/dashboard',
    '/property',
    '/rooms',
    '/tenant',
    '/contract',
    '/billing',
    '/maintenance',
  ];

  /// Trang mọi người dùng đã đăng nhập đều dùng được.
  static const sharedRoutes = ['/notifications', '/settings'];

  /// Trang báo không có quyền.
  static const forbiddenRoute = '/forbidden';

  static bool isManager(String? role) => managerRoles.contains(role);

  static bool _matches(String path, String route) => path == route || path.startsWith('$route/');

  /// Người dùng có [role] có được mở [path] không (chỉ áp dụng cho trang cần đăng nhập).
  static bool canAccess(String? role, String path) {
    if (isManager(role)) return true;
    if (path == forbiddenRoute) return true;
    // Mặc định từ chối với vai trò không phải quản lý: trang mới phải được khai báo rõ.
    return sharedRoutes.any((r) => _matches(path, r));
  }

  /// Trang chính sau đăng nhập.
  static String homeFor(String? role) => isManager(role) ? '/dashboard' : '/notifications';
}
