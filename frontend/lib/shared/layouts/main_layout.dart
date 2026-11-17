import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/auth/role_access.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/app_sidebar.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/state_views.dart';
import '../../models/system_health_model.dart';
import '../../providers/auth_provider.dart';
import '../services/app_data_repository.dart';

class MainLayout extends StatelessWidget {
  final String currentLocation;
  final Widget child;

  const MainLayout({
    super.key,
    required this.currentLocation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppDataRepository>();
    final auth = context.watch<AuthProvider>();
    if (auth.status == AuthStatus.unknown) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final isDesktop = AppResponsive.isDesktop(context);
    final isMobile = AppResponsive.isMobile(context);

    final health = repo.systemHealth;
    final sidebar = AppSidebar(
      currentLocation: currentLocation,
      unreadNotifications: repo.unreadNotificationCount,
      servicesUp: health?.upCount,
      servicesTotal: health?.services.length,
      gatewayUp: health?.gatewayStatus == ServiceStatus.up,
      role: auth.role,
    );
    final isManager = RoleAccess.isManager(auth.role);

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: isDesktop ? null : Drawer(width: AppSpacing.sidebarWidth, child: sidebar),
      bottomNavigationBar: isMobile
          ? _MobileBottomNav(currentLocation: currentLocation, role: auth.role)
          : null,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isDesktop) sidebar,
          Expanded(
            child: Column(
              children: [
                AppTopBar(
                  currentLocation: currentLocation,
                  userName: auth.displayName,
                  userRole: auth.roleDisplay,
                  unreadNotifications: repo.unreadNotificationCount,
                  // Tìm kiếm toàn cục mở trang Quản lý phòng -> chỉ dành cho vai trò quản lý.
                  onGlobalSearch: isManager
                      ? (query) {
                          context.go('/rooms');
                        }
                      : null,
                  onSyncApi: () async {
                    await repo.syncWithBackend();
                    if (context.mounted) {
                      if (repo.isBackendConnected) {
                        showSuccessToast(context, 'Đã đồng bộ dữ liệu qua API Gateway (:8000)');
                      } else {
                        showErrorToast(
                          context,
                          'Không kết nối được API Gateway. ${repo.lastSyncError ?? ''}'.trim(),
                        );
                      }
                    }
                  },
                  onLogout: () => context.read<AuthProvider>().logout(),
                ),
                if (repo.isSyncing && !repo.hasSyncedOnce)
                  const LinearProgressIndicator(minHeight: 2),
                if (!repo.isBackendConnected && !repo.isSyncing && repo.lastSyncError != null)
                  _ConnectionErrorBanner(
                    message: repo.lastSyncError!,
                    hasStaleData: repo.hasSyncedOnce,
                    onRetry: repo.syncWithBackend,
                  ),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Băng báo lỗi kết nối API Gateway dùng chung cho mọi trang, kèm nút "Thử lại".
class _ConnectionErrorBanner extends StatelessWidget {
  final String message;
  final bool hasStaleData;
  final Future<void> Function() onRetry;

  const _ConnectionErrorBanner({
    required this.message,
    required this.hasStaleData,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final detail = hasStaleData
        ? 'Dữ liệu đang hiển thị là của lần đồng bộ gần nhất và có thể chưa cập nhật.'
        : 'Chưa tải được dữ liệu từ hệ thống.';
    return Material(
      color: AppColors.errorLight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, size: 18, color: AppColors.error),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Không kết nối được API Gateway: ${message.replaceAll(RegExp(r'[.\s]+$'), '')}. $detail',
                style: const TextStyle(color: AppColors.errorText, fontSize: 13),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}

class MainPageScroll extends StatelessWidget {
  final Widget child;

  const MainPageScroll({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 768;
    return SingleChildScrollView(
      padding: isMobile
          ? AppSpacing.pagePaddingMobile
          : AppSpacing.pagePaddingDesktop,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1440),
          child: child,
        ),
      ),
    );
  }
}

class _MobileNavItem {
  final String route;
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const _MobileNavItem(this.route, this.label, this.icon, this.selectedIcon);
}

class _MobileBottomNav extends StatelessWidget {
  final String currentLocation;
  final String role;

  const _MobileBottomNav({required this.currentLocation, required this.role});

  static const _all = [
    _MobileNavItem('/dashboard', 'Tổng quan', Icons.bar_chart_rounded, Icons.bar_chart_rounded),
    _MobileNavItem('/property', 'Tòa nhà', Icons.apartment_rounded, Icons.apartment_rounded),
    _MobileNavItem('/rooms', 'Phòng trọ', Icons.door_front_door_outlined, Icons.door_front_door_rounded),
    _MobileNavItem(
      '/notifications',
      'Thông báo',
      Icons.notifications_none_rounded,
      Icons.notifications_rounded,
    ),
    _MobileNavItem('/settings', 'Cài đặt', Icons.settings_outlined, Icons.settings_rounded),
  ];

  /// Quản lý: Tổng quan / Tòa nhà / Phòng trọ / Cài đặt (như trước).
  /// TENANT: chỉ các trang được phép (Thông báo / Cài đặt).
  List<_MobileNavItem> get _items => RoleAccess.isManager(role)
      ? _all.where((i) => i.route != '/notifications').toList()
      : _all.where((i) => RoleAccess.canAccess(role, i.route)).toList();

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final found = items.indexWhere(
      (i) => currentLocation == i.route || currentLocation.startsWith('${i.route}/'),
    );
    final selectedIndex = found < 0 ? 0 : found;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: AppSpacing.shadowLevel2,
      ),
      child: NavigationBar(
        selectedIndex: selectedIndex,
        backgroundColor: AppColors.surface,
        elevation: 0,
        indicatorColor: AppColors.primary.withValues(alpha: 0.12),
        onDestinationSelected: (index) => context.go(items[index].route),
        destinations: [
          for (final item in items)
            NavigationDestination(
              icon: Icon(item.icon, color: AppColors.textSecondary),
              selectedIcon: Icon(item.selectedIcon, color: AppColors.primary),
              label: item.label,
            ),
        ],
      ),
    );
  }
}

