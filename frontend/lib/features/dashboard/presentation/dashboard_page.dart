import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_table.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/services/app_data_repository.dart';
import 'widgets/monthly_revenue_chart.dart';
import 'widgets/room_ratio_chart.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppDataRepository>();
    final width = MediaQuery.sizeOf(context).width;
    final cols = AppResponsive.statGridCrossAxisCount(width);
    final occupancyRate = repo.totalRoomsCount > 0
        ? ((repo.occupiedRoomsCount / repo.totalRoomsCount) * 100).round()
        : 0;

    final stats = [
      StatCard(
        title: 'Tổng số tòa nhà',
        value: '${repo.totalPropertiesCount}',
        subtitle: 'Cơ sở đang vận hành',
        icon: Icons.apartment_rounded,
        tone: StatIconTone.primary,
        onTap: () => context.go('/property'),
      ),
      StatCard(
        title: 'Tổng số phòng',
        value: '${repo.totalRoomsCount}',
        subtitle: 'Tỷ lệ lấp đầy $occupancyRate%',
        icon: Icons.door_front_door_outlined,
        tone: StatIconTone.primary,
        onTap: () => context.go('/rooms'),
      ),
      StatCard(
        title: 'Phòng đang thuê',
        value: '${repo.occupiedRoomsCount}',
        subtitle: 'Đang khai thác ổn định',
        icon: Icons.people_outline_rounded,
        tone: StatIconTone.primary,
        onTap: () => context.go('/rooms'),
      ),
      StatCard(
        title: 'Phòng còn trống',
        value: '${repo.availableRoomsCount}',
        subtitle: 'Sẵn sàng đón khách',
        icon: Icons.check_circle_outline_rounded,
        tone: StatIconTone.success,
        onTap: () => context.go('/rooms'),
      ),
      StatCard(
        title: 'Hợp đồng hiệu lực',
        value: '${repo.activeContractsCount}',
        subtitle: 'Đang hoạt động',
        icon: Icons.description_outlined,
        tone: StatIconTone.primary,
        onTap: () => context.go('/contract'),
      ),
      StatCard(
        title: 'Hóa đơn cần thu',
        value: '${repo.unpaidInvoicesCount}',
        subtitle: 'Chờ thanh toán / quá hạn',
        icon: Icons.receipt_long_outlined,
        tone: repo.unpaidInvoicesCount > 0
            ? StatIconTone.warning
            : StatIconTone.neutral,
        onTap: () => context.go('/billing'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Tổng quan hệ thống',
          subtitle:
              'Theo dõi công suất phòng, dòng tiền và tình hình vận hành nhà trọ.',
          actions: [
            AppButton(
              label: 'Quản lý phòng',
              icon: Icons.door_front_door_outlined,
              variant: AppButtonVariant.outlined,
              onPressed: () => context.go('/rooms'),
            ),
            AppButton(
              label: 'Quản lý tòa nhà',
              icon: Icons.apartment_rounded,
              onPressed: () => context.go('/property'),
            ),
          ],
        ),

        // KPI Statistics Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: stats.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: AppSpacing.lg,
            mainAxisSpacing: AppSpacing.lg,
            mainAxisExtent: 140,
          ),
          itemBuilder: (_, index) => stats[index],
        ),

        const SizedBox(height: AppSpacing.xxl),

        // Charts Section: Room Occupancy Ratio & Monthly Revenue
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            final ratioChart = RoomRatioChart(
              occupied: repo.occupiedRoomsCount,
              available: repo.availableRoomsCount,
              maintenance: repo.maintenanceRoomsCount,
            );
            final revenueChart = MonthlyRevenueChart(points: repo.revenuePoints);

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: ratioChart),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(flex: 7, child: revenueChart),
                ],
              );
            }
            return Column(
              children: [
                ratioChart,
                const SizedBox(height: AppSpacing.lg),
                revenueChart,
              ],
            );
          },
        ),

        const SizedBox(height: AppSpacing.xxl),

        // Property Occupancy Overview
        AppSurfaceCard(
          padding: AppSpacing.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tình trạng công suất theo tòa nhà',
                          style: AppTypography.sectionTitle,
                        ),
                        SizedBox(height: AppSpacing.xxs),
                        Text(
                          'Tổng hợp số phòng đang thuê, còn trống và bảo trì tại từng cơ sở',
                          style: AppTypography.caption,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppButton(
                    label: 'Chi tiết tòa nhà',
                    variant: AppButtonVariant.outlined,
                    compact: true,
                    onPressed: () => context.go('/property'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const Divider(height: 1),
              for (var i = 0; i < repo.properties.length; i++) ...[
                _PropertyOccupancyRow(
                  property: repo.properties[i],
                  onTap: () => context.go('/property'),
                ),
                if (i < repo.properties.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xxl),

        // Recent Invoices Table
        AppSurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hóa đơn gần đây',
                            style: AppTypography.sectionTitle,
                          ),
                          SizedBox(height: AppSpacing.xxs),
                          Text(
                            'Danh sách hóa đơn tiền phòng và điện nước cần theo dõi',
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppButton(
                      label: 'Xem tất cả',
                      variant: AppButtonVariant.outlined,
                      compact: true,
                      onPressed: () => context.go('/billing'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              AppTable<InvoiceItem>(
                items: repo.invoices,
                onRowTap: (_) => context.go('/billing'),
                columns: [
                  AppTableColumn(
                    label: 'MÃ HÓA ĐƠN',
                    width: 140,
                    cellBuilder: (item) => CodeBadge(item.code),
                  ),
                  AppTableColumn(
                    label: 'PHÒNG & KHÁCH',
                    flex: 3,
                    cellBuilder: (item) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(item.tenantName, style: AppTypography.bodyBold),
                        Text(
                          '${item.roomName} · ${item.propertyName}',
                          style: AppTypography.caption,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  AppTableColumn(
                    label: 'KỲ THU',
                    width: 140,
                    cellBuilder: (item) => Text(
                      item.dueDate,
                      style: AppTypography.bodyMd,
                    ),
                  ),
                  AppTableColumn(
                    label: 'SỐ TIỀN',
                    width: 150,
                    cellBuilder: (item) => Text(
                      AppFormatters.currency(item.totalAmount),
                      style: AppTypography.bodyBold.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                  AppTableColumn(
                    label: 'TRẠNG THÁI',
                    width: 160,
                    cellBuilder: (item) =>
                        StatusBadge.fromInvoiceStatus(item.status),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PropertyOccupancyRow extends StatelessWidget {
  final PropertyItem property;
  final VoidCallback onTap;

  const _PropertyOccupancyRow({
    required this.property,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = property.totalRooms > 0
        ? property.occupiedRooms / property.totalRooms
        : 0.0;
    final percent = (ratio * 100).round();

    return InkWell(
      onTap: onTap,
      hoverColor: AppColors.background,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 640;

            final titleBlock = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CodeBadge(property.code),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        property.name,
                        style: AppTypography.bodyBold,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  property.address,
                  style: AppTypography.caption,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            );

            final progressBlock = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${property.occupiedRooms}/${property.totalRooms} phòng đang thuê',
                      style: AppTypography.labelSm,
                    ),
                    Text(
                      '$percent%',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.labelGap),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
                  child: LinearProgressIndicator(
                    value: ratio.clamp(0.0, 1.0),
                    minHeight: 7,
                    backgroundColor: AppColors.surfaceMuted,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.secondary,
                    ),
                  ),
                ),
              ],
            );

            final badgesBlock = Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                StatusBadge(
                  label: '${property.availableRooms} trống',
                  type: BadgeType.success,
                ),
                if (property.maintenanceRooms > 0)
                  StatusBadge(
                    label: '${property.maintenanceRooms} bảo trì',
                    type: BadgeType.warning,
                  ),
              ],
            );

            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titleBlock,
                  const SizedBox(height: AppSpacing.md),
                  progressBlock,
                  const SizedBox(height: AppSpacing.sm),
                  badgesBlock,
                ],
              );
            }

            return Row(
              children: [
                Expanded(flex: 4, child: titleBlock),
                const SizedBox(width: AppSpacing.lg),
                Expanded(flex: 3, child: progressBlock),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  flex: 3,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: badgesBlock,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
