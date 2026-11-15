import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_table.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/services/app_data_repository.dart';

class RoomDetailPage extends StatelessWidget {
  final String roomId;

  const RoomDetailPage({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppDataRepository>();
    final parsedId = int.tryParse(roomId);

    RoomItem? room;
    if (parsedId != null) {
      for (final r in repo.rooms) {
        if (r.id == parsedId) {
          room = r;
          break;
        }
      }
    }

    if (room == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Chi tiết phòng',
            subtitle: 'Không tìm thấy thông tin phòng theo mã định danh.',
            actions: [
              AppButton(
                label: 'Quay lại danh sách',
                icon: Icons.arrow_back_rounded,
                variant: AppButtonVariant.outlined,
                onPressed: () => context.go('/rooms'),
              ),
            ],
          ),
          EmptyState(
            icon: Icons.door_front_door_outlined,
            title: 'Không tìm thấy phòng',
            subtitle:
                'Phòng với mã "$roomId" không tồn tại trong dữ liệu hiện tại.',
            actionLabel: 'Quay lại Quản lý phòng',
            onAction: () => context.go('/rooms'),
          ),
        ],
      );
    }

    final occupancyRatio = room.maxOccupants > 0
        ? (room.currentOccupants / room.maxOccupants).clamp(0.0, 1.0)
        : 0.0;
    final occupancyPercent = (occupancyRatio * 100).round();

    final relatedContracts = repo.contracts
        .where(
          (c) =>
              c.roomName == room!.name && c.propertyName == room.propertyName,
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: room.name,
          subtitle: '${room.code} · ${room.propertyName}',
          actions: [
            StatusBadge.fromRoomStatus(room.status),
            AppButton(
              label: 'Quay lại',
              icon: Icons.arrow_back_rounded,
              variant: AppButtonVariant.outlined,
              onPressed: () => context.go('/rooms'),
            ),
            AppButton(
              label: 'Chỉnh sửa',
              icon: Icons.edit_outlined,
              onPressed: () => showSuccessToast(
                context,
                'Chức năng chỉnh sửa đang ở chế độ UI-only (chưa kết nối Django backend).',
              ),
            ),
          ],
        ),

        // Basic Information & Room Specifications
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 880;

            final basicInfoCard = _DetailSectionCard(
              title: 'Thông tin cơ bản',
              icon: Icons.info_outline_rounded,
              child: Column(
                children: [
                  _KeyValueRow(
                    label: 'Mã phòng',
                    valueWidget: CodeBadge(room!.code),
                  ),
                  const Divider(height: 1),
                  _KeyValueRow(
                    label: 'Tên phòng',
                    value: room.name,
                  ),
                  const Divider(height: 1),
                  _KeyValueRow(
                    label: 'Nhà trọ / Tòa nhà',
                    value: room.propertyName,
                  ),
                  const Divider(height: 1),
                  _KeyValueRow(
                    label: 'Tầng',
                    value: 'Tầng ${room.floor}',
                  ),
                  const Divider(height: 1),
                  _KeyValueRow(
                    label: 'Trạng thái',
                    valueWidget: StatusBadge.fromRoomStatus(room.status),
                  ),
                ],
              ),
            );

            final specsCard = _DetailSectionCard(
              title: 'Thông số phòng',
              icon: Icons.tune_rounded,
              child: Column(
                children: [
                  _KeyValueRow(
                    label: 'Giá thuê',
                    value: '${AppFormatters.currency(room.rentPrice)}/tháng',
                    valueColor: AppColors.secondary,
                  ),
                  const Divider(height: 1),
                  _KeyValueRow(
                    label: 'Diện tích',
                    value: '${room.area.toStringAsFixed(0)} m²',
                  ),
                  const Divider(height: 1),
                  _KeyValueRow(
                    label: 'Số người hiện tại',
                    value: '${room.currentOccupants} người',
                  ),
                  const Divider(height: 1),
                  _KeyValueRow(
                    label: 'Số người tối đa',
                    value: '${room.maxOccupants} người',
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Tỷ lệ sử dụng / phòng',
                              style: AppTypography.bodyMd,
                            ),
                            Text(
                              '$occupancyPercent% (${room.currentOccupants}/${room.maxOccupants})',
                              style: AppTypography.bodyBold.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.pillRadius),
                          child: LinearProgressIndicator(
                            value: occupancyRatio,
                            minHeight: 8,
                            backgroundColor: AppColors.surfaceMuted,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: basicInfoCard),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(child: specsCard),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                basicInfoCard,
                const SizedBox(height: AppSpacing.lg),
                specsCard,
              ],
            );
          },
        ),

        const SizedBox(height: AppSpacing.lg),

        // Additional Information
        _DetailSectionCard(
          title: 'Thông tin bổ sung',
          icon: Icons.notes_rounded,
          child: Text(
            room.description.isNotEmpty
                ? room.description
                : 'Chưa có mô tả chi tiết cho phòng này.',
            style: AppTypography.bodyMd,
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // Related Contracts from Mock Repository
        AppSurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hợp đồng liên quan',
                      style: AppTypography.sectionTitle,
                    ),
                    SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Danh sách hợp đồng thuê gắn với phòng này (dữ liệu mẫu)',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (relatedContracts.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    'Hiện chưa có hợp đồng nào gắn với phòng này.',
                    style: AppTypography.caption,
                  ),
                )
              else
                AppTable<ContractItem>(
                  items: relatedContracts,
                  columns: [
                    AppTableColumn(
                      label: 'MÃ HĐ',
                      width: 130,
                      cellBuilder: (c) => CodeBadge(c.code),
                    ),
                    AppTableColumn(
                      label: 'KHÁCH THUÊ ĐẠI DIỆN',
                      flex: 2,
                      cellBuilder: (c) =>
                          Text(c.tenantName, style: AppTypography.bodyBold),
                    ),
                    AppTableColumn(
                      label: 'THỜI HẠN THUÊ',
                      flex: 2,
                      cellBuilder: (c) => Text(
                        '${c.startDate} → ${c.endDate}',
                        style: AppTypography.bodyMd,
                      ),
                    ),
                    AppTableColumn(
                      label: 'GIÁ THỎA THUẬN',
                      width: 150,
                      cellBuilder: (c) => Text(
                        AppFormatters.currency(c.rentPrice),
                        style: AppTypography.bodyBold.copyWith(
                          color: AppColors.secondary,
                        ),
                      ),
                    ),
                    AppTableColumn(
                      label: 'TRẠNG THÁI HĐ',
                      width: 155,
                      cellBuilder: (c) =>
                          StatusBadge.fromContractStatus(c.status),
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

class _DetailSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _DetailSectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 19, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(title, style: AppTypography.sectionTitle),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.xs),
          child,
        ],
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? valueWidget;
  final Color? valueColor;

  const _KeyValueRow({
    required this.label,
    this.value,
    this.valueWidget,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(width: AppSpacing.lg),
          Flexible(
            child: valueWidget ??
                Text(
                  value ?? '',
                  textAlign: TextAlign.right,
                  style: AppTypography.bodyBold.copyWith(
                    color: valueColor ?? AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
          ),
        ],
      ),
    );
  }
}
