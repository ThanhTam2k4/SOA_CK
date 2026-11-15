import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
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
import 'shared/layouts/main_layout.dart';
import 'shared/services/app_data_repository.dart';

void main() {
  usePathUrlStrategy();
  runApp(const NhaTroManagerApp());
}

class NhaTroManagerApp extends StatefulWidget {
  const NhaTroManagerApp({super.key});

  @override
  State<NhaTroManagerApp> createState() => _NhaTroManagerAppState();
}

class _NhaTroManagerAppState extends State<NhaTroManagerApp> {
  final AppDataRepository _repository = AppDataRepository();

  late final GoRouter _router = GoRouter(
    initialLocation: '/dashboard',
    routes: [
      GoRoute(
        path: '/',
        redirect: (_, _) => '/dashboard',
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
    return ChangeNotifierProvider<AppDataRepository>.value(
      value: _repository,
      child: MaterialApp.router(
        title: 'Nhà Trọ Manager — SaaS SOA Platform',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: _router,
      ),
    );
  }
}
