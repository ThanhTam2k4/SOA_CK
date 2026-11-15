import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/presentation/login_page.dart';
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
      final atLogin = state.matchedLocation == '/login';
      switch (_auth.status) {
        case AuthStatus.unknown:
          return null; // đang khôi phục phiên
        case AuthStatus.unauthenticated:
          return atLogin ? null : '/login';
        case AuthStatus.authenticated:
          return atLogin ? '/dashboard' : null;
      }
    },
    routes: [
      GoRoute(
        path: '/',
        redirect: (_, _) => '/dashboard',
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => const LoginPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainLayout(
          currentLocation: state.uri.path,
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, _) => const DashboardPage(),
          ),
          GoRoute(
            path: '/property',
            builder: (_, _) => const PropertyPage(),
          ),
          GoRoute(
            path: '/rooms',
            builder: (_, _) => const RoomPage(),
          ),
          GoRoute(
            path: '/rooms/create',
            builder: (_, _) => const RoomCreatePage(),
          ),
          GoRoute(
            path: '/rooms/:id',
            builder: (_, state) => RoomDetailPage(
              roomId: state.pathParameters['id'] ?? '',
            ),
          ),
          GoRoute(
            path: '/tenant',
            builder: (_, _) => const TenantPage(),
          ),
          GoRoute(
            path: '/contract',
            builder: (_, _) => const ContractPage(),
          ),
          GoRoute(
            path: '/billing',
            builder: (_, _) => const BillingPage(),
          ),
          GoRoute(
            path: '/maintenance',
            builder: (_, _) => const MaintenancePage(),
          ),
          GoRoute(
            path: '/notifications',
            builder: (_, _) => const NotificationPage(),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, _) => const SettingsPage(),
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
