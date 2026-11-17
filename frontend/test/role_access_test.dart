// Chặng 4 — Phân quyền giao diện theo vai trò: router guard, ẩn menu, URL trực tiếp,
// chưa đăng nhập, token hết hạn.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nhatro_frontend/core/auth/role_access.dart';
import 'package:nhatro_frontend/core/constants/api_constants.dart';
import 'package:nhatro_frontend/core/widgets/app_sidebar.dart';
import 'package:nhatro_frontend/features/auth/presentation/forbidden_page.dart';
import 'package:nhatro_frontend/features/auth/presentation/login_page.dart';
import 'package:nhatro_frontend/features/billing/presentation/billing_page.dart';
import 'package:nhatro_frontend/features/contract/presentation/contract_page.dart';
import 'package:nhatro_frontend/features/dashboard/presentation/dashboard_page.dart';
import 'package:nhatro_frontend/features/maintenance/presentation/maintenance_page.dart';
import 'package:nhatro_frontend/features/notification/presentation/notification_page.dart';
import 'package:nhatro_frontend/features/notification/presentation/settings_page.dart';
import 'package:nhatro_frontend/features/property/presentation/property_page.dart';
import 'package:nhatro_frontend/features/room/presentation/room_create_page.dart';
import 'package:nhatro_frontend/features/room/presentation/room_detail_page.dart';
import 'package:nhatro_frontend/features/room/presentation/room_page.dart';
import 'package:nhatro_frontend/features/tenant/presentation/tenant_page.dart';
import 'package:nhatro_frontend/main.dart';
import 'package:nhatro_frontend/providers/auth_provider.dart';
import 'package:nhatro_frontend/shared/services/api_client.dart';
import 'package:nhatro_frontend/shared/services/app_data_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object? body, [int status = 200]) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );

/// AuthProvider có vai trò cố định; login() mô phỏng đăng nhập thành công với vai trò đó.
class _RoleAuth extends AuthProvider {
  AuthStatus _s;
  final String _role;
  _RoleAuth(this._role, [this._s = AuthStatus.authenticated]);

  @override
  AuthStatus get status => _s;
  @override
  bool get isAuthenticated => _s == AuthStatus.authenticated;
  @override
  String get role => _s == AuthStatus.authenticated ? _role : '';
  @override
  String get displayName => 'Test $_role'; // tên ngắn: top bar tràn với tên dài (lỗi layout có sẵn, đã báo cáo)

  @override
  Future<bool> login(String username, String password) async {
    _s = AuthStatus.authenticated;
    notifyListeners();
    return true;
  }

  @override
  Future<void> logout() async {
    _s = AuthStatus.unauthenticated;
    notifyListeners();
  }
}

class _OfflineRepo extends AppDataRepository {
  @override
  Future<void> syncWithBackend() async {}
}

/// Trang quản lý (chỉ ADMIN/STAFF/LANDLORD) và widget trang tương ứng.
const _managerRoutes = <String, Type>{
  '/dashboard': DashboardPage,
  '/property': PropertyPage,
  '/rooms': RoomPage,
  '/rooms/create': RoomCreatePage,
  '/rooms/5': RoomDetailPage,
  '/tenant': TenantPage,
  '/contract': ContractPage,
  '/billing': BillingPage,
  '/maintenance': MaintenancePage,
};

const _managerMenu = [
  'Tổng quan',
  'Quản lý nhà trọ',
  'Quản lý phòng',
  'Quản lý người thuê',
  'Quản lý hợp đồng',
  'Hóa đơn',
  'Bảo trì & sửa chữa',
  'Thông báo',
  'Cài đặt',
];

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiClient.resetForTest();
  });

  tearDown(() {
    ApiClient.httpClient = http.Client();
    ApiClient.onSessionExpired = null;
    ApiClient.resetForTest();
  });

  void screen(WidgetTester tester, [Size size = const Size(1440, 900)]) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> pumpApp(WidgetTester tester, AuthProvider auth) async {
    await tester.pumpWidget(NhaTroManagerApp(authProvider: auth, repository: _OfflineRepo()));
    await tester.pumpAndSettle();
  }

  /// Mô phỏng gõ thẳng URL vào thanh địa chỉ (router chạy lại redirect).
  Future<void> goTo(WidgetTester tester, String location) async {
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go(location);
    await tester.pumpAndSettle();
  }

  Finder inSidebar(String text) => find.descendant(of: find.byType(AppSidebar), matching: find.text(text));

  group('RoleAccess (ma trận quyền)', () {
    test('ADMIN / STAFF / LANDLORD mở được mọi trang', () {
      for (final role in ['ADMIN', 'STAFF', 'LANDLORD']) {
        for (final path in [..._managerRoutes.keys, '/notifications', '/settings']) {
          expect(RoleAccess.canAccess(role, path), isTrue, reason: '$role -> $path');
        }
        expect(RoleAccess.homeFor(role), '/dashboard');
      }
    });

    test('TENANT và vai trò không xác định chỉ mở Thông báo / Cài đặt', () {
      for (final role in ['TENANT', '', null, 'admin', 'SUPERUSER']) {
        for (final path in _managerRoutes.keys) {
          expect(RoleAccess.canAccess(role, path), isFalse, reason: '$role -> $path');
        }
        expect(RoleAccess.canAccess(role, '/notifications'), isTrue);
        expect(RoleAccess.canAccess(role, '/settings'), isTrue);
        expect(RoleAccess.canAccess(role, '/propertyX'), isFalse, reason: 'không khớp tiền tố lỏng');
        expect(RoleAccess.canAccess(role, '/trang-moi'), isFalse, reason: 'mặc định từ chối');
        expect(RoleAccess.homeFor(role), '/notifications');
      }
    });
  });

  for (final role in ['ADMIN', 'STAFF', 'LANDLORD']) {
    testWidgets('$role: thấy đủ menu quản lý và mở trực tiếp mọi URL quản lý', (tester) async {
      screen(tester);
      await pumpApp(tester, _RoleAuth(role));
      expect(find.byType(DashboardPage), findsOneWidget);
      for (final label in _managerMenu) {
        expect(inSidebar(label), findsOneWidget, reason: label);
      }
      for (final MapEntry(key: path, value: page) in _managerRoutes.entries) {
        await goTo(tester, path);
        expect(find.byType(ForbiddenPage), findsNothing, reason: path);
        expect(find.byType(page), findsOneWidget, reason: path);
      }
    });
  }

  testWidgets('TENANT: vào thẳng trang Thông báo, menu chỉ có Thông báo + Cài đặt', (tester) async {
    screen(tester);
    await pumpApp(tester, _RoleAuth('TENANT'));

    expect(find.byType(NotificationPage), findsOneWidget);
    expect(find.byType(DashboardPage), findsNothing);
    expect(inSidebar('Thông báo'), findsOneWidget);
    expect(inSidebar('Cài đặt'), findsOneWidget);
    for (final label in _managerMenu.where((l) => l != 'Thông báo' && l != 'Cài đặt')) {
      expect(inSidebar(label), findsNothing, reason: label);
    }
  });

  testWidgets('TENANT gõ thẳng URL trang quản lý -> trang "Không có quyền truy cập"', (tester) async {
    screen(tester);
    await pumpApp(tester, _RoleAuth('TENANT'));

    for (final MapEntry(key: path, value: page) in _managerRoutes.entries) {
      await goTo(tester, path);
      expect(find.byType(page), findsNothing, reason: path);
      if (path == '/dashboard') {
        // Trang chính mặc định -> về trang chính của TENANT.
        expect(find.byType(NotificationPage), findsOneWidget);
      } else {
        expect(find.byType(ForbiddenPage), findsOneWidget, reason: path);
        expect(find.text('Không có quyền truy cập'), findsOneWidget);
        expect(find.textContaining('"$path"'), findsOneWidget);
      }
    }

    await tester.tap(find.text('Về trang chính'));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationPage), findsOneWidget);

    await goTo(tester, '/settings');
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.text('Đơn giá dịch vụ mặc định'), findsNothing, reason: 'cấu hình của chủ trọ');
    expect(find.text('Quản lý tài khoản & phân quyền'), findsNothing);
  });

  testWidgets('TENANT đăng nhập từ màn Login -> về Thông báo, không vào Dashboard', (tester) async {
    screen(tester);
    await pumpApp(tester, _RoleAuth('TENANT', AuthStatus.unauthenticated));
    expect(find.byType(LoginPage), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'khach1');
    await tester.enterText(find.byKey(const Key('login_password')), 'x');
    await tester.tap(find.text('Đăng nhập'));
    await tester.pumpAndSettle();

    expect(find.byType(NotificationPage), findsOneWidget);
    expect(find.byType(DashboardPage), findsNothing);
  });

  testWidgets('TENANT trên điện thoại: thanh điều hướng dưới chỉ có Thông báo + Cài đặt', (tester) async {
    screen(tester, const Size(760, 1000)); // <768 = mobile; 390px: biểu đồ Dashboard tràn (lỗi có sẵn)
    await pumpApp(tester, _RoleAuth('TENANT'));
    final nav = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(nav.destinations, hasLength(2));
    final labels = find.descendant(of: find.byType(NavigationBar), matching: find.byType(Text));
    expect(tester.widgetList<Text>(labels).map((t) => t.data), containsAll(['Thông báo', 'Cài đặt']));
    expect(find.descendant(of: find.byType(NavigationBar), matching: find.text('Phòng trọ')), findsNothing);
  });

  testWidgets('LANDLORD trên điện thoại: thanh điều hướng dưới giữ nguyên 4 mục', (tester) async {
    screen(tester, const Size(760, 1000)); // <768 = mobile; 390px: biểu đồ Dashboard tràn (lỗi có sẵn)
    await pumpApp(tester, _RoleAuth('LANDLORD'));
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).destinations, hasLength(4));
  });

  testWidgets('Chưa đăng nhập: mọi URL cần đăng nhập đều về màn Login', (tester) async {
    screen(tester);
    await pumpApp(tester, _RoleAuth('LANDLORD', AuthStatus.unauthenticated));
    for (final path in [..._managerRoutes.keys, '/notifications', '/settings', '/forbidden', '/']) {
      await goTo(tester, path);
      expect(find.byType(LoginPage), findsOneWidget, reason: path);
      expect(find.byType(AppSidebar), findsNothing, reason: path);
    }
  });

  group('Phiên thật (AuthProvider + /auth/me/)', () {
    late bool expired;
    late String meRole;

    setUp(() {
      expired = false;
      meRole = 'TENANT';
      ApiClient.httpClient = MockClient((req) async {
        if (req.url.path == '/api/auth/refresh/') {
          return _json({'detail': 'Token is blacklisted', 'code': 'token_not_valid'}, 401);
        }
        if (expired) return _json({'detail': 'Given token not valid for any token type'}, 401);
        if (req.url.path == '/api/auth/me/') {
          return _json({'id': 7, 'username': 'khach1', 'role': meRole, 'full_name': 'Khách Test'});
        }
        return _json([]);
      });
    });

    Future<AuthProvider> restored() async {
      await ApiClient.saveSession(
        access: 'access-ok',
        refresh: 'refresh-ok',
        user: {'username': 'khach1', 'role': 'LANDLORD'}, // bản lưu cũ: phải lấy role mới từ /auth/me/
      );
      final auth = AuthProvider();
      await auth.restoreSession();
      return auth;
    }

    testWidgets('Vai trò lấy từ Identity (/auth/me/), không tin bản lưu cục bộ', (tester) async {
      screen(tester);
      final auth = await restored();
      expect(auth.role, 'TENANT');
      await pumpApp(tester, auth);
      expect(find.byType(NotificationPage), findsOneWidget);
      await goTo(tester, '/billing');
      expect(find.byType(ForbiddenPage), findsOneWidget);
    });

    testWidgets('Token hết hạn (refresh bị từ chối) -> về Login, không vào lại được trang nào', (tester) async {
      screen(tester);
      meRole = 'LANDLORD';
      final auth = await restored();
      await pumpApp(tester, auth);
      expect(find.byType(DashboardPage), findsOneWidget);

      expired = true;
      await expectLater(ApiClient.get(ApiConstants.notifications), throwsA(isA<ApiException>()));
      await tester.pumpAndSettle();

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.text('Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại.'), findsOneWidget);
      expect(auth.role, '');
      expect(await ApiClient.getAccessToken(), isNull);

      await goTo(tester, '/property');
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(PropertyPage), findsNothing);
    });
  });
}
