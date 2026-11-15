import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../models/dashboard_summary_model.dart';
import '../../models/system_health_model.dart';

/// Lớp truy cập dữ liệu Dashboard. Mọi request đều đi qua API Gateway (:8000);
/// việc gọi tới từng service và tổng hợp số liệu được thực hiện ở Gateway,
/// Flutter không tự gọi 5 service.
class AppDataRepository {
  const AppDataRepository();

  /// Trạng thái thực tế của Gateway + 5 service.
  /// Không ném lỗi: nếu Gateway không phản hồi thì trả về Gateway = DOWN,
  /// các service = UNKNOWN (không biết, vì không có ai kiểm tra hộ).
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
}
