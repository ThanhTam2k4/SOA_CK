import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/auth/role_access.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/forbidden_page.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/auth/presentation/register_page.dart';
import 'features/billing/presentation/billing_page.dart';
import 'features/contract/presentation/contract_page.dart';
import 'features/dashboard/presentation/dashboard_page.dart';
import 'features/maintenance/presentation/maintenance_page.dart';
import 'features/notification/presentation/notification_page.dart';
import 'features/notification/presentation/settings_page.dart';
import 'features/property/presentation/property_page.dart';
import 'features/room/presentation/room_create_page.dart';
import 'features/room/presentation/room_detail_page.dart';
import 'features/room/presentation/room_page.dart';
import 'features/tenant/presentation/tenant_page.dart';
import 'providers/auth_provider.dart';
import 'shared/layouts/main_layout.dart';
import 'shared/services/app_data_repository.dart';

void main() {
  usePathUrlStrategy();
  runApp(const NhaTroManagerApp());
}

class NhaTroManagerApp extends StatefulWidget {
  /// Cho phép test truyền sẵn provider (không gọi mạng khi khởi tạo).
  final AuthProvider? authProvider;
  final AppDataRepository? repository;

  const NhaTroManagerApp({super.key, this.authProvider, this.repository});

  @override
  State<NhaTroManagerApp> createState() => _NhaTroManagerAppState();
}

class _NhaTroManagerAppState extends State<NhaTroManagerApp> {
  late final AuthProvider _auth = widget.authProvider ?? AuthProvider();
  late final AppDataRepository _repository = widget.repository ?? AppDataRepository();
  AuthStatus? _lastStatus;

  @override
  void initState() {
    super.initState();
    _auth.addListener(_onAuthChanged);
    if (widget.authProvider == null) {
      _auth.restoreSession();
    } else {
      _onAuthChanged();
    }
  }

  /// Đăng nhập -> đồng bộ dữ liệu thật qua Gateway; đăng xuất -> xóa dữ liệu phiên.
  void _onAuthChanged() {
    final status = _auth.status;
    if (status == _lastStatus) return;
    _lastStatus = status;
    if (status == AuthStatus.authenticated) {
      _repository.syncWithBackend();
    } else if (status == AuthStatus.unauthenticated) {
      _repository.resetAfterLogout();
    }
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  late final GoRouter _router = GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: _auth,
    redirect: (_, state) {
      // Trang công khai: đăng nhập và đăng ký (chỉ dành cho người chưa đăng nhập).
      final path = state.uri.path;
      final atPublic = const {'/login', '/register'}.contains(path);
      switch (_auth.status) {
        case AuthStatus.unknown:
          return null; // đang khôi phục phiên
        case AuthStatus.unauthenticated:
          return atPublic ? null : '/login';
        case AuthStatus.authenticated:
          final role = _auth.role;
          final home = RoleAccess.homeFor(role);
          if (atPublic || path == '/') return home;
          if (RoleAccess.canAccess(role, path)) return null;
          // Trang chính mặc định của quản lý (/dashboard) -> đưa TENANT về trang chính của mình;
          // các trang quản lý khác (vd. gõ thẳng URL) -> báo không có quyền.
          if (path == '/dashboard') return home;
          return Uri(path: RoleAccess.forbiddenRoute, queryParameters: {'from': path}).toString();
      }
    },
    routes: [
      GoRoute(
        path: '/',
        redirect: (_, _) => RoleAccess.homeFor(_auth.role),
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (_, _) => const RegisterPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainLayout(
          currentLocation: state.uri.path,
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, _) => const MainPageScroll(child: DashboardPage()),
          ),
          GoRoute(
            path: '/property',
            builder: (_, _) => const MainPageScroll(child: PropertyPage()),
          ),
          GoRoute(
            path: '/rooms',
            builder: (_, _) => const MainPageScroll(child: RoomPage()),
          ),
          GoRoute(
            path: '/rooms/create',
            builder: (_, _) => const MainPageScroll(child: RoomCreatePage()),
          ),
          GoRoute(
            path: '/rooms/:id',
            builder: (_, state) => MainPageScroll(
              child: RoomDetailPage(
                roomId: state.pathParameters['id'] ?? '',
              ),
            ),
          ),
          GoRoute(
            path: '/tenant',
            builder: (_, _) => const MainPageScroll(child: TenantPage()),
          ),
          GoRoute(
            path: '/contract',
            builder: (_, _) => const MainPageScroll(child: ContractPage()),
          ),
          GoRoute(
            path: '/billing',
            builder: (_, _) => const MainPageScroll(child: BillingPage()),
          ),
          GoRoute(
            path: '/maintenance',
            builder: (_, _) => const MainPageScroll(child: MaintenancePage()),
          ),
          GoRoute(
            path: '/notifications',
            builder: (_, _) => const MainPageScroll(child: NotificationPage()),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, _) => const MainPageScroll(child: SettingsPage()),
          ),
          GoRoute(
            path: RoleAccess.forbiddenRoute,
            builder: (_, state) => MainPageScroll(
              child: ForbiddenPage(attemptedPath: state.uri.queryParameters['from']),
            ),
          ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: _auth),
        ChangeNotifierProvider<AppDataRepository>.value(value: _repository),
      ],
      child: MaterialApp.router(
        title: 'Nhà Trọ Manager — SaaS SOA Platform',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: _router,
      ),
    );
  }
}
