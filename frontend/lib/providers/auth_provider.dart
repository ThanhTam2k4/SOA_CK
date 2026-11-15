import 'package:flutter/foundation.dart';

import '../core/constants/api_constants.dart';
import '../shared/services/api_client.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Trạng thái đăng nhập của ứng dụng. Xác thực qua Identity Service, đi qua API Gateway.
class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.unknown;
  Map<String, dynamic>? _user;
  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider() {
    ApiClient.onSessionExpired = _handleSessionExpired;
  }

  AuthStatus get status => _status;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get user => _user;

  String get role => '${_user?['role'] ?? ''}';
  String get displayName {
    final name = '${_user?['full_name'] ?? ''}'.trim();
    return name.isNotEmpty ? name : '${_user?['username'] ?? 'Người dùng'}';
  }

  String get roleDisplay {
    final display = '${_user?['role_display'] ?? ''}'.trim();
    if (display.isNotEmpty) return display;
    return switch (role) {
      'ADMIN' => 'Quản trị viên',
      'LANDLORD' => 'Chủ nhà trọ',
      'STAFF' => 'Quản lý / Nhân viên',
      'TENANT' => 'Khách thuê',
      _ => role,
    };
  }

  bool get isManager => const {'ADMIN', 'STAFF', 'LANDLORD'}.contains(role);

  /// Khôi phục phiên đã lưu và xác minh token với Identity Service (/auth/me/).
  Future<void> restoreSession() async {
    final token = await ApiClient.getAccessToken();
    if (token == null || token.isEmpty) {
      _setUnauthenticated();
      return;
    }
    _user = await ApiClient.getSavedUser();
    try {
      final me = await ApiClient.get(ApiConstants.currentUser);
      if (me is Map<String, dynamic>) {
        _user = me;
        await ApiClient.saveSession(access: (await ApiClient.getAccessToken())!, user: me);
      }
      _status = AuthStatus.authenticated;
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await ApiClient.clearSession();
        _setUnauthenticated();
        return;
      }
      // Gateway/Identity tạm không phản hồi: giữ phiên cục bộ, dữ liệu sẽ đồng bộ lại sau.
      _status = _user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _user = await ApiClient.login(username.trim(), password);
      _status = AuthStatus.authenticated;
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.isUnauthorized ? 'Sai tên đăng nhập hoặc mật khẩu.' : e.message;
      _status = AuthStatus.unauthenticated;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await ApiClient.logout();
    _setUnauthenticated();
  }

  void _handleSessionExpired() {
    if (_status == AuthStatus.authenticated) {
      _errorMessage = 'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại.';
      _setUnauthenticated();
    }
  }

  void _setUnauthenticated() {
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
