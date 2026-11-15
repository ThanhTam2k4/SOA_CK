import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhatro_frontend/core/constants/api_constants.dart';
import 'package:nhatro_frontend/core/constants/soa_services.dart';
import 'package:nhatro_frontend/main.dart';
import 'package:nhatro_frontend/providers/auth_provider.dart';
import 'package:nhatro_frontend/shared/services/app_data_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AuthProvider giả: không gọi mạng.
class FakeAuthProvider extends AuthProvider {
  AuthStatus _fakeStatus;
  FakeAuthProvider(this._fakeStatus);

  @override
  AuthStatus get status => _fakeStatus;

  @override
  bool get isAuthenticated => _fakeStatus == AuthStatus.authenticated;

  @override
  String get displayName => 'Chủ trọ Test';

  @override
  String get roleDisplay => 'Chủ nhà trọ';

  @override
  Future<bool> login(String username, String password) async {
    _fakeStatus = AuthStatus.authenticated;
    notifyListeners();
    return true;
  }

  @override
  Future<void> logout() async {
    _fakeStatus = AuthStatus.unauthenticated;
    notifyListeners();
  }
}

/// Repository giả: giữ dữ liệu mẫu, không đồng bộ qua mạng.
class OfflineRepository extends AppDataRepository {
  int syncCalls = 0;

  @override
  Future<void> syncWithBackend() async {
    syncCalls++;
  }
}

void _desktop(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Chưa đăng nhập -> chuyển tới màn hình đăng nhập', (tester) async {
    _desktop(tester);
    final repo = OfflineRepository();
    await tester.pumpWidget(NhaTroManagerApp(
      authProvider: FakeAuthProvider(AuthStatus.unauthenticated),
      repository: repo,
    ));
    await tester.pumpAndSettle();

    expect(find.text('NHÀ TRỌ MANAGER'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsOneWidget);
    expect(find.text('Tổng quan hệ thống'), findsNothing);
    expect(repo.syncCalls, 0);
  });

  testWidgets('Đăng nhập -> vào Dashboard và đồng bộ dữ liệu qua Gateway', (tester) async {
    _desktop(tester);
    final repo = OfflineRepository();
    final auth = FakeAuthProvider(AuthStatus.unauthenticated);
    await tester.pumpWidget(NhaTroManagerApp(authProvider: auth, repository: repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'chutro1');
    await tester.enterText(find.byKey(const Key('login_password')), 'secret');
    await tester.tap(find.text('Đăng nhập'));
    await tester.pumpAndSettle();

    expect(find.text('Tổng quan hệ thống'), findsOneWidget);
    expect(find.text('Chủ trọ Test'), findsWidgets);
    expect(repo.syncCalls, 1);
    // Chưa kết nối Gateway -> có cảnh báo dữ liệu mẫu, không giả vờ là dữ liệu thật.
    expect(find.textContaining('DỮ LIỆU MẪU'), findsOneWidget);
  });

  test('Frontend chỉ dùng API Gateway, không trỏ trực tiếp port 8001–8005', () {
    expect(ApiConstants.baseUrl, startsWith(ApiConstants.gatewayUrl));
    for (final s in SoaServices.all) {
      expect(s.gatewayEndpoint, startsWith(ApiConstants.baseUrl));
      expect(s.gatewayEndpoint, isNot(contains(':${s.port}')));
    }
  });
}
