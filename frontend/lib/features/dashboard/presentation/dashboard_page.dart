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
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/services/app_data_repository.dart';
import '../widgets/service_endpoints_dialog.dart';
import '../widgets/soa_architecture_card.dart';
import 'widgets/monthly_revenue_chart.dart';
import 'widgets/room_ratio_chart.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppDataRepository>();
    final width = MediaQuery.sizeOf(context).width;
    final cols = AppResponsive.statGridCrossAxisCount(width);

    // Chỉ dùng số liệu THẬT từ GET /api/dashboard/summary/ (Gateway tổng hợp).
    // - dashboardSummary chỉ có giá trị sau khi tải thành công (được giữ lại khi lần tải sau lỗi).
    // - Chưa có số liệu -> "…" khi đang tải, "—" khi lỗi / chưa tải; trường null (service sở hữu
    //   số liệu DOWN) -> "—". Không bịa số, không đổi lỗi thành 0, không tự tính từ dữ liệu cục bộ.
    final summaryState = repo.sectionState(DataSection.dashboard);
    final s = repo.dashboardSummary;
    final live = s != null;
    final loadingSummary = !live && (summaryState.isLoading || (repo.isSyncing && !repo.hasSyncedOnce));
    final placeholder = loadingSummary ? '…' : '—';
    String n(int? liveValue) => live ? (liveValue?.toString() ?? '—') : placeholder;
    String money(double? value) => live ? (value == null ? '—' : AppFormatters.currency(value)) : placeholder;

    final occupancyText = live && s.occupancyRatePercent != null ? '${s.occupancyRatePercent!.round()}%' : '—';
    final unpaid = live ? (s.unpaidInvoices ?? 0) : 0;
    // Nút "Thử lại" riêng chỉ cần khi Gateway vẫn phản hồi (lỗi ở một service / summary).
    // Mất kết nối Gateway đã có banner chung kèm "Thử lại" ở MainLayout.
    final canRetry = repo.isBackendConnected;
    Future<void> retry() => repo.syncWithBackend();

    final stats = [
      StatCard(
        title: 'Tổng số tòa nhà',
        value: n(s?.totalProperties),
        subtitle: 'Cơ sở đang vận hành',
        icon: Icons.apartment_rounded,
        tone: StatIconTone.primary,
        onTap: () => context.go('/property'),
      ),
      StatCard(
        title: 'Tổng số phòng',
        value: n(s?.totalRooms),
        subtitle: 'Tỷ lệ lấp đầy $occupancyText',
        icon: Icons.door_front_door_outlined,
        tone: StatIconTone.primary,
        onTap: () => context.go('/rooms'),
      ),
      StatCard(
        title: 'Phòng đang thuê',
        value: n(s?.occupiedRooms),
        subtitle: 'Đang khai thác ổn định',
        icon: Icons.people_outline_rounded,
        tone: StatIconTone.primary,
        onTap: () => context.go('/rooms'),
      ),
      StatCard(
        title: 'Phòng còn trống',
        value: n(s?.availableRooms),
        subtitle: 'Sẵn sàng đón khách',
        icon: Icons.check_circle_outline_rounded,
        tone: StatIconTone.success,
        onTap: () => context.go('/rooms'),
      ),
      StatCard(
        title: 'Hợp đồng hiệu lực',
        value: n(s?.activeContracts),
        subtitle: live && (s.expiringSoonContracts ?? 0) > 0
            ? '${s.expiringSoonContracts} sắp hết hạn'
            : 'Đang hoạt động',
        icon: Icons.description_outlined,
        tone: StatIconTone.primary,
        onTap: () => context.go('/contract'),
      ),
      StatCard(
        title: 'Hóa đơn cần thu',
        value: n(s?.unpaidInvoices),
        subtitle: live && s.unpaidAmount != null
            ? 'Còn nợ ${AppFormatters.currency(s.unpaidAmount)}'
            : 'Chờ thanh toán / quá hạn',
        icon: Icons.receipt_long_outlined,
        tone: unpaid > 0
            ? StatIconTone.warning
            : StatIconTone.neutral,
        onTap: () => context.go('/billing'),
      ),
      // Hai chỉ số backend đã cung cấp sẵn — hiển thị nguyên giá trị, không tự tính lại.
      StatCard(
        title: 'Doanh thu dự kiến / tháng',
        value: money(s?.estimatedMonthlyRevenue),
        subtitle: 'Tổng giá thuê các phòng đang thuê',
        icon: Icons.trending_up_rounded,
        tone: StatIconTone.success,
        onTap: () => context.go('/rooms'),
      ),
      StatCard(
        title: 'Tổng tiền chưa thanh toán',
        value: money(s?.unpaidAmount),
        subtitle: 'Hóa đơn chưa thu / quá hạn',
        icon: Icons.account_balance_wallet_outlined,
        tone: (live && (s.unpaidAmount ?? 0) > 0) ? StatIconTone.warning : StatIconTone.neutral,
        onTap: () => context.go('/billing'),
      ),
    ];

    final propertySection = repo.sectionState(DataSection.properties);
    final invoiceSection = repo.sectionState(DataSection.invoices);

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

        // Lỗi mất kết nối Gateway được hiển thị chung ở MainLayout (kèm nút "Thử lại").
        if (loadingSummary)
          const _DataSourceBanner(
            key: Key('dashboard_summary_loading'),
            message: 'Đang tải số liệu tổng quan từ API Gateway...',
            isError: false,
            loading: true,
          )
        else if (!repo.isBackendConnected && !live)
          const _DataSourceBanner(
            message: 'Chưa có số liệu tổng quan vì chưa kết nối được API Gateway.',
            isError: true,
          )
        else if (!repo.isBackendConnected)
          const _DataSourceBanner(
            message: 'Mất kết nối API Gateway: đang hiển thị số liệu của lần cập nhật trước.',
            isError: true,
          )
        else if (summaryState.isForbidden)
          const _DataSourceBanner(
            key: Key('dashboard_summary_forbidden'),
            message: 'Tài khoản của bạn không có quyền xem số liệu tổng quan.',
            isError: false,
          )
        else if (summaryState.isError || repo.dashboardError != null)
          _DataSourceBanner(
            key: const Key('dashboard_summary_error'),
            message: 'Không lấy được số liệu tổng quan: '
                '${repo.dashboardError ?? summaryState.message ?? 'lỗi không xác định'}'
                '${live ? ' Đang hiển thị số liệu của lần cập nhật trước.' : ''}',
            isError: true,
            onRetry: canRetry ? retry : null,
          )
        else if (live && !s.complete)
          _DataSourceBanner(
            message: 'Thiếu số liệu do service không phản hồi: ${s.failedSources.join(', ')}',
            isError: false,
            onRetry: canRetry ? retry : null,
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
            // Chỉ vẽ biểu đồ khi Property Service đã trả số liệu phòng (0 thật vẫn được vẽ là 0).
            // Không có số liệu -> trạng thái đang tải / lỗi / không có quyền, KHÔNG vẽ 0/0/0 giả.
            final hasRoomStats = live && s.occupiedRooms != null && s.availableRooms != null;
            final Widget ratioChart;
            if (hasRoomStats) {
              ratioChart = RoomRatioChart(
                occupied: s.occupiedRooms!,
                available: s.availableRooms!,
                maintenance: s.maintenanceRooms ?? 0,
              );
            } else if (loadingSummary) {
              ratioChart = const LoadingState(
                key: Key('room_ratio_loading'),
                message: 'Đang tải tỷ lệ trạng thái phòng...',
              );
            } else if (summaryState.isForbidden) {
              ratioChart = const EmptyState(
                key: Key('room_ratio_forbidden'),
                icon: Icons.lock_outline_rounded,
                title: 'Không có quyền xem tỷ lệ phòng',
                subtitle: 'Tài khoản của bạn không được xem số liệu tổng quan.',
              );
            } else if (canRetry) {
              ratioChart = ErrorState(
                key: const Key('room_ratio_error'),
                message: live
                    ? 'Property Service không trả số liệu phòng nên chưa vẽ được tỷ lệ trạng thái phòng.'
                    : 'Chưa lấy được số liệu tổng quan nên chưa vẽ được tỷ lệ trạng thái phòng.',
                onRetry: retry,
              );
            } else {
              ratioChart = const EmptyState(
                key: Key('room_ratio_unavailable'),
                icon: Icons.donut_large_rounded,
                title: 'Chưa có số liệu tỷ lệ phòng',
                subtitle: 'Biểu đồ sẽ hiển thị khi kết nối được API Gateway.',
              );
            }
            // Backend (Gateway /dashboard/summary/) chưa cung cấp chuỗi doanh thu theo tháng:
            // hiển thị trạng thái rỗng, không vẽ số bịa.
            final Widget revenueChart = repo.revenuePoints.isEmpty
                ? const EmptyState(
                    key: Key('revenue_chart_empty'),
                    icon: Icons.bar_chart_rounded,
                    title: 'Chưa có dữ liệu doanh thu theo tháng',
                    subtitle: 'Hệ thống chưa cung cấp số liệu doanh thu theo từng tháng. '
                        'Doanh thu dự kiến hiện tại xem ở thẻ "Doanh thu dự kiến / tháng".',
                  )
                : MonthlyRevenueChart(points: repo.revenuePoints);

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

        // Trạng thái THỰC TẾ của kiến trúc SOA (Gateway kiểm tra /health/ của 5 service)
        SoaArchitectureCard(
          health: repo.systemHealth,
          isLoading: repo.isSyncing,
          onRefresh: repo.refreshSystemHealth,
          onServiceTap: (key, name, port, status) => ServiceEndpointsDialog.show(
            context,
            serviceKey: key,
            name: name,
            port: port,
            healthStatus: status,
            load: repo.fetchServiceEndpoints,
          ),
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
              _SectionStatus(
                key: const Key('dashboard_properties_status'),
                state: propertySection,
                isEmpty: repo.properties.isEmpty,
                syncing: repo.isSyncing,
                what: 'danh sách tòa nhà',
                emptyText: 'Chưa có tòa nhà nào.',
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                onRetry: canRetry ? retry : null,
              ),
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
              // Phân biệt: đang tải / không có hóa đơn (rỗng thật) / lỗi Billing / không có quyền.
              _SectionStatus(
                key: const Key('dashboard_invoices_status'),
                state: invoiceSection,
                isEmpty: repo.invoices.isEmpty,
                syncing: repo.isSyncing,
                what: 'danh sách hóa đơn',
                emptyText: 'Chưa có hóa đơn nào.',
                padding: const EdgeInsets.all(AppSpacing.xl),
                onRetry: canRetry ? retry : null,
              ),
              if (repo.invoices.isNotEmpty)
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
                  property.displayAddress,
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


/// Băng thông báo nguồn dữ liệu của Dashboard (đang tải / lỗi / thiếu số liệu).
class _DataSourceBanner extends StatelessWidget {
  final String message;
  final bool isError;
  final bool loading;

  /// Tải lại qua [AppDataRepository.syncWithBackend]; null = không hiện nút.
  final VoidCallback? onRetry;

  const _DataSourceBanner({
    super.key,
    required this.message,
    required this.isError,
    this.loading = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isError ? AppColors.errorText : AppColors.warningText;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isError ? AppColors.errorLight : AppColors.warningLight,
        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
        border: Border.all(color: isError ? AppColors.errorBorder : AppColors.warningBorder),
      ),
      child: Row(
        children: [
          if (loading) ...[
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: fg)),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Text(message.trim(), style: AppTypography.caption.copyWith(color: fg)),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: AppSpacing.sm),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Thử lại'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Trạng thái một danh sách trên Dashboard theo [SectionState] của repository:
/// đang tải / rỗng thật / lỗi (kèm thử lại) / không có quyền. Khi danh sách có dữ liệu cũ mà
/// lần tải mới lỗi thì báo dữ liệu có thể chưa cập nhật. Có dữ liệu bình thường -> không hiển thị gì.
class _SectionStatus extends StatelessWidget {
  final SectionState state;
  final bool isEmpty;
  final bool syncing;
  final String what;
  final String emptyText;
  final EdgeInsets padding;
  final VoidCallback? onRetry;

  const _SectionStatus({
    super.key,
    required this.state,
    required this.isEmpty,
    required this.syncing,
    required this.what,
    required this.emptyText,
    required this.padding,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final String text;
    var isError = false;
    var loading = false;
    if (!isEmpty) {
      if (!state.isError) return const SizedBox.shrink();
      text = 'Không cập nhật được $what: ${state.message ?? 'lỗi không xác định'}. '
          'Đang hiển thị dữ liệu của lần tải trước.';
      isError = true;
    } else if (state.isForbidden) {
      text = 'Tài khoản của bạn không có quyền xem $what.';
    } else if (state.isError) {
      text = 'Không tải được $what: ${state.message ?? 'lỗi không xác định'}';
      isError = true;
    } else if (state.isLoaded) {
      text = emptyText;
    } else if (state.isLoading || syncing) {
      text = 'Đang tải $what...';
      loading = true;
    } else {
      text = 'Chưa tải được $what.';
    }
    final style = AppTypography.caption.copyWith(color: isError ? AppColors.errorText : null);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (loading) ...[
            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: AppSpacing.sm),
          ],
          if (isError) ...[
            const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.error),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(child: Text(text, style: style)),
          if (isError && onRetry != null)
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Thử lại'),
            ),
        ],
      ),
    );
  }
}
