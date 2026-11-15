import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/app_sidebar.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/state_views.dart';
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
    final isDesktop = AppResponsive.isDesktop(context);
    final isMobile = AppResponsive.isMobile(context);

    final sidebar = AppSidebar(
      currentLocation: currentLocation,
      unreadNotifications: repo.unreadNotificationCount,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: isDesktop ? null : Drawer(width: AppSpacing.sidebarWidth, child: sidebar),
      bottomNavigationBar: isMobile
          ? _MobileBottomNav(currentLocation: currentLocation)
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
                  userName: repo.currentUserName,
                  userRole: repo.currentUserRole,
                  unreadNotifications: repo.unreadNotificationCount,
                  onGlobalSearch: (query) {
                    context.go('/rooms');
                  },
                  onSyncApi: () async {
                    await repo.syncWithBackend();
                    if (context.mounted) {
                      showSuccessToast(
                        context,
                        repo.isBackendConnected
                            ? 'Đã đồng bộ dữ liệu trực tiếp từ Django SOA (Ports 8001–8005)'
                            : 'Đang sử dụng dữ liệu mẫu (Mock Data chuẩn SOA)',
                      );
                    }
                  },
                ),
                Expanded(
                  child: SingleChildScrollView(
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
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileBottomNav extends StatelessWidget {
  final String currentLocation;

  const _MobileBottomNav({required this.currentLocation});

  int _selectedIndex() {
    if (currentLocation.startsWith('/property')) return 1;
    if (currentLocation.startsWith('/rooms')) return 2;
    if (currentLocation.startsWith('/settings')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _selectedIndex();

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
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/dashboard');
            case 1:
              context.go('/property');
            case 2:
              context.go('/rooms');
            case 3:
              context.go('/settings');
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.bar_chart_rounded, color: AppColors.textSecondary),
            selectedIcon: Icon(Icons.bar_chart_rounded, color: AppColors.primary),
            label: 'Tổng quan',
          ),
          NavigationDestination(
            icon: Icon(Icons.apartment_rounded, color: AppColors.textSecondary),
            selectedIcon: Icon(Icons.apartment_rounded, color: AppColors.primary),
            label: 'Tòa nhà',
          ),
          NavigationDestination(
            icon: Icon(Icons.door_front_door_outlined, color: AppColors.textSecondary),
            selectedIcon: Icon(Icons.door_front_door_rounded, color: AppColors.primary),
            label: 'Phòng trọ',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined, color: AppColors.textSecondary),
            selectedIcon: Icon(Icons.settings_rounded, color: AppColors.primary),
            label: 'Cài đặt',
          ),
        ],
      ),
    );
  }
}

