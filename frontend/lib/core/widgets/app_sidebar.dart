import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../theme/app_typography.dart';

class SidebarNavItem {
  final String label;
  final String route;
  final IconData icon;
  final int? port;
  final int? badgeCount;

  const SidebarNavItem({
    required this.label,
    required this.route,
    required this.icon,
    this.port,
    this.badgeCount,
  });
}

class AppSidebar extends StatelessWidget {
  final String currentLocation;
  final int unreadNotifications;

  /// Trạng thái thực tế từ GET /api/system/health/ (null = chưa kiểm tra).
  final int? servicesUp;
  final int? servicesTotal;
  final bool gatewayUp;

  const AppSidebar({
    super.key,
    required this.currentLocation,
    this.unreadNotifications = 0,
    this.servicesUp,
    this.servicesTotal,
    this.gatewayUp = false,
  });

  (Color, String, String) get _soaStatus {
    if (servicesTotal == null) {
      return (AppColors.textMuted, 'Kiến trúc SOA', 'Chưa kiểm tra trạng thái');
    }
    if (!gatewayUp) {
      return (AppColors.error, 'API Gateway DOWN', 'Không kết nối được :8000');
    }
    final allUp = servicesUp == servicesTotal;
    return (
      allUp ? AppColors.success : AppColors.warning,
      allUp ? 'Kiến trúc SOA Active' : 'Hệ thống suy giảm',
      'Gateway :8000 · $servicesUp/$servicesTotal service UP',
    );
  }

  List<SidebarNavItem> get _mainItems => [
        const SidebarNavItem(
          label: 'Tổng quan',
          route: '/dashboard',
          icon: Icons.bar_chart_rounded,
        ),
        const SidebarNavItem(
          label: 'Quản lý nhà trọ',
          route: '/property',
          icon: Icons.apartment_rounded,
          port: 8002,
        ),
        const SidebarNavItem(
          label: 'Quản lý phòng',
          route: '/rooms',
          icon: Icons.door_front_door_outlined,
          port: 8002,
        ),
        const SidebarNavItem(
          label: 'Quản lý người thuê',
          route: '/tenant',
          icon: Icons.people_outline_rounded,
          port: 8003,
        ),
        const SidebarNavItem(
          label: 'Quản lý hợp đồng',
          route: '/contract',
          icon: Icons.description_outlined,
          port: 8004,
        ),
        const SidebarNavItem(
          label: 'Hóa đơn',
          route: '/billing',
          icon: Icons.payments_outlined,
          port: 8005,
        ),
        const SidebarNavItem(
          label: 'Bảo trì & sửa chữa',
          route: '/maintenance',
          icon: Icons.build_outlined,
          port: 8002,
        ),
        SidebarNavItem(
          label: 'Thông báo',
          route: '/notifications',
          icon: Icons.notifications_none_rounded,
          port: 8005,
          badgeCount: unreadNotifications > 0 ? unreadNotifications : null,
        ),
      ];

  bool _isActive(String route) {
    return currentLocation == route || currentLocation.startsWith('$route/');
  }

  @override
  Widget build(BuildContext context) {
    final (soaColor, soaTitle, soaSubtitle) = _soaStatus;
    return Container(
      width: AppSpacing.sidebarWidth,
      decoration: const BoxDecoration(
        color: AppColors.sidebarBackground,
        border: Border(right: BorderSide(color: AppColors.border)),
        boxShadow: AppSpacing.shadowLevel1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Brand Logo Header
          Container(
            height: AppSpacing.topBarHeight,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppSpacing.badgeRadius),
                  ),
                  child: const Icon(
                    Icons.apartment_rounded,
                    color: AppColors.surface,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nhatro Pro',
                        style: AppTypography.titleMd.copyWith(
                          color: AppColors.textHeadingStrong,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text(
                        'Enterprise SOA Platform',
                        style: AppTypography.captionSm,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Navigation Menu
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.lg,
              ),
              children: [
                for (final item in _mainItems)
                  _SidebarTile(
                    item: item,
                    active: _isActive(item.route),
                    onTap: () {
                      if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
                        Navigator.of(context).pop();
                      }
                      context.go(item.route);
                    },
                  ),
                const Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: AppSpacing.md,
                    horizontal: AppSpacing.sm,
                  ),
                  child: Divider(color: AppColors.border, height: 1),
                ),
                _SidebarTile(
                  item: const SidebarNavItem(
                    label: 'Cài đặt',
                    route: '/settings',
                    icon: Icons.settings_outlined,
                    port: 8001,
                  ),
                  active: _isActive('/settings'),
                  onTap: () {
                    if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
                      Navigator.of(context).pop();
                    }
                    context.go('/settings');
                  },
                ),
              ],
            ),
          ),

          // Footer SOA Architecture status
          Container(
            margin: const EdgeInsets.all(AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: soaColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        soaTitle,
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        soaSubtitle,
                        style: AppTypography.captionSm,
                      ),
                    ],
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

class _SidebarTile extends StatefulWidget {
  final SidebarNavItem item;
  final bool active;
  final VoidCallback onTap;

  const _SidebarTile({
    required this.item,
    required this.active,
    required this.onTap,
  });

  @override
  State<_SidebarTile> createState() => _SidebarTileState();
}

class _SidebarTileState extends State<_SidebarTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.active
        ? AppColors.primaryLight
        : (_hovered ? AppColors.background : Colors.transparent);
    final fg = widget.active ? AppColors.primary : AppColors.textSecondary;
    final textColor = widget.active ? AppColors.primary : AppColors.textPrimary;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
              border: widget.active
                  ? Border.all(color: AppColors.primaryBorder)
                  : null,
            ),
            child: Row(
              children: [
                Icon(widget.item.icon, size: 20, color: fg),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    widget.item.label,
                    style: AppTypography.bodyMedium.copyWith(
                      color: textColor,
                      fontWeight: widget.active ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (widget.item.badgeCount != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
                    ),
                    child: Text(
                      '${widget.item.badgeCount}',
                      style: AppTypography.captionSm.copyWith(
                        color: AppColors.surface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else if (widget.item.port != null)
                  Text(
                    ':${widget.item.port}',
                    style: AppTypography.captionSm.copyWith(
                      fontFamily: 'monospace',
                      color: widget.active ? AppColors.primary : AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

