import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/soa_services.dart';
import '../theme/app_typography.dart';
import '../utils/responsive.dart';
import 'status_badge.dart';

class AppTopBar extends StatelessWidget {
  final String currentLocation;
  final String userName;
  final String userRole;
  final int unreadNotifications;
  final ValueChanged<String>? onGlobalSearch;
  final VoidCallback? onSyncApi;
  final VoidCallback? onLogout;

  const AppTopBar({
    super.key,
    required this.currentLocation,
    required this.userName,
    required this.userRole,
    required this.unreadNotifications,
    this.onGlobalSearch,
    this.onSyncApi,
    this.onLogout,
  });

  String _breadcrumbLabel(String path) {
    if (path.startsWith('/dashboard')) return 'Tổng quan';
    if (path.startsWith('/property')) return 'Quản lý nhà trọ';
    if (path.startsWith('/rooms')) return 'Quản lý phòng';
    if (path.startsWith('/tenant')) return 'Quản lý người thuê';
    if (path.startsWith('/contract')) return 'Quản lý hợp đồng';
    if (path.startsWith('/billing')) return 'Hóa đơn';
    if (path.startsWith('/maintenance')) return 'Bảo trì & sửa chữa';
    if (path.startsWith('/notifications')) return 'Thông báo';
    if (path.startsWith('/settings')) return 'Cài đặt hệ thống';
    return 'Tổng quan';
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = AppResponsive.isMobile(context);
    final activeService = SoaServices.forRoute(currentLocation);
    // Flutter chỉ gọi Gateway; nhãn cho biết Gateway định tuyến tới service nào.
    final routeLabel = 'Gateway :8000 → ${activeService.shortName} :${activeService.port}';

    return Container(
      height: AppSpacing.topBarHeight,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? AppSpacing.lg : AppSpacing.xxl,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (!AppResponsive.isDesktop(context)) ...[
            IconButton(
              icon: const Icon(Icons.menu_rounded, color: AppColors.textHeadingStrong),
              onPressed: () => Scaffold.of(context).openDrawer(),
              tooltip: 'Menu',
            ),
            const SizedBox(width: AppSpacing.xs),
          ],

          // Breadcrumb + Active SOA Service Port indicator
          Expanded(
            child: Row(
              children: [
                if (!isMobile) ...[
                  const Text('Hệ thống', style: AppTypography.labelSm),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
                Flexible(
                  child: Text(
                    _breadcrumbLabel(currentLocation),
                    style: AppTypography.headlineMd,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!isMobile) ...[
                  const SizedBox(width: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(AppSpacing.badgeRadius),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      routeLabel,
                      style: AppTypography.captionSm.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Quick Search Bar on Topbar (Desktop & Tablet)
          if (!isMobile) ...[
            SizedBox(
              width: 248,
              height: 40,
              child: TextField(
                onSubmitted: (q) {
                  if (q.trim().isNotEmpty) {
                    onGlobalSearch?.call(q.trim());
                  }
                },
                style: AppTypography.bodyMd.copyWith(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Tìm nhanh phòng, người thuê...',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 0,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceMuted,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
          ],

          // Notification Icon Button
          InkWell(
            onTap: () => context.go('/notifications'),
            borderRadius: BorderRadius.circular(AppSpacing.badgeRadius),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.badgeRadius),
                border: Border.all(color: AppColors.border),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.notifications_none_rounded,
                    size: 20,
                    color: AppColors.textPrimary,
                  ),
                  if (unreadNotifications > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // User Profile Dropdown
          PopupMenuButton<String>(
            offset: const Offset(0, 46),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
              side: const BorderSide(color: AppColors.border),
            ),
            onSelected: (value) {
              if (value == 'settings') {
                context.go('/settings');
              } else if (value == 'notifications') {
                context.go('/notifications');
              } else if (value == 'sync') {
                onSyncApi?.call();
              } else if (value == 'logout') {
                onLogout?.call();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(userName, style: AppTypography.bodyBold),
                    const SizedBox(height: AppSpacing.xs),
                    RoleBadge(role: userRole),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'sync',
                child: Row(
                  children: [
                    Icon(Icons.sync_rounded, size: 17, color: AppColors.textSecondary),
                    SizedBox(width: 10),
                    Text('Đồng bộ dữ liệu REST API', style: AppTypography.body),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'notifications',
                child: Row(
                  children: [
                    Icon(Icons.notifications_none_rounded, size: 17, color: AppColors.textSecondary),
                    SizedBox(width: 10),
                    Text('Thông báo hệ thống', style: AppTypography.body),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, size: 17, color: AppColors.textSecondary),
                    SizedBox(width: 10),
                    Text('Cài đặt & Kết nối SOA', style: AppTypography.body),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 17, color: AppColors.error),
                    SizedBox(width: 10),
                    Text('Đăng xuất', style: AppTypography.body),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.badgeRadius),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.primaryLight,
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  if (!isMobile) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          userRole,
                          style: AppTypography.captionSm,
                        ),
                      ],
                    ),
                    const SizedBox(width: AppSpacing.labelGap),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

