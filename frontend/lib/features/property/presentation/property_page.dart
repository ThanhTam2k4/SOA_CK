import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_search_bar.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/app_table.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/pagination_widget.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/services/app_data_repository.dart';
import 'widgets/property_header_card.dart';

class PropertyPage extends StatefulWidget {
  const PropertyPage({super.key});

  @override
  State<PropertyPage> createState() => _PropertyPageState();
}

class _PropertyPageState extends State<PropertyPage> {
  final _searchCtrl = TextEditingController();
  String _statusFilter = 'ALL';
  int _page = 1;
  static const int _pageSize = 6;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openPropertyForm([PropertyItem? existing]) {
    final formKey = GlobalKey<FormState>();
    final codeCtrl = TextEditingController(
      text: existing?.code ?? 'NT-00${context.read<AppDataRepository>().properties.length + 1}',
    );
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    final districtCtrl = TextEditingController(text: existing?.district ?? '');
    final totalRoomsCtrl = TextEditingController(text: '${existing?.totalRooms ?? 10}');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    String status = existing?.status ?? 'ACTIVE';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text(
            existing == null ? 'Thêm nhà trọ mới' : 'Chỉnh sửa nhà trọ',
            style: AppTypography.sectionTitle,
          ),
          content: SizedBox(
            width: 520,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'Mã nhà trọ',
                            controller: codeCtrl,
                            requiredField: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppSelect<String>(
                            label: 'Trạng thái',
                            width: null,
                            value: status,
                            options: const [
                              AppSelectOption(value: 'ACTIVE', label: 'Đang hoạt động'),
                              AppSelectOption(value: 'INACTIVE', label: 'Tạm ngưng'),
                            ],
                            onChanged: (v) => setModalState(() => status = v ?? 'ACTIVE'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      label: 'Tên nhà trọ',
                      controller: nameCtrl,
                      hint: 'VD: Khu nhà trọ Bình Thạnh Rivera',
                      requiredField: true,
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      label: 'Địa chỉ chi tiết',
                      controller: addressCtrl,
                      hint: 'Số nhà, đường, phường/xã...',
                      requiredField: true,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'Quận / Huyện / Khu vực',
                            controller: districtCtrl,
                            requiredField: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            label: 'Tổng số phòng',
                            controller: totalRoomsCtrl,
                            requiredField: true,
                            isNumber: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      label: 'Mô tả & tiện ích chung',
                      controller: descCtrl,
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            AppButton(
              label: 'Hủy',
              variant: AppButtonVariant.outlined,
              onPressed: () => Navigator.pop(ctx),
            ),
            AppButton(
              label: existing == null ? 'Thêm nhà trọ' : 'Lưu thay đổi',
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final repo = context.read<AppDataRepository>();
                final total = int.tryParse(totalRoomsCtrl.text.trim()) ?? 0;

                if (existing == null) {
                  final err = await repo.addProperty(
                    PropertyItem(
                      id: DateTime.now().millisecondsSinceEpoch,
                      code: codeCtrl.text.trim(),
                      name: nameCtrl.text.trim(),
                      address: addressCtrl.text.trim(),
                      district: districtCtrl.text.trim(),
                      totalRooms: total,
                      occupiedRooms: 0,
                      availableRooms: total,
                      status: status,
                      description: descCtrl.text.trim(),
                    ),
                  );
                  if (!ctx.mounted || !mounted) return;
                  if (err != null) {
                    showErrorToast(context, err);
                    return;
                  }
                  Navigator.pop(ctx);
                  showSuccessToast(context, 'Đã thêm nhà trọ "${nameCtrl.text.trim()}"');
                } else {
                  final err = await repo.updateProperty(
                    existing.copyWith(
                      code: codeCtrl.text.trim(),
                      name: nameCtrl.text.trim(),
                      address: addressCtrl.text.trim(),
                      district: districtCtrl.text.trim(),
                      totalRooms: total,
                      status: status,
                      description: descCtrl.text.trim(),
                    ),
                  );
                  if (!ctx.mounted || !mounted) return;
                  if (err != null) {
                    showErrorToast(context, err);
                    return;
                  }
                  Navigator.pop(ctx);
                  showSuccessToast(context, 'Đã cập nhật nhà trọ "${nameCtrl.text.trim()}"');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPropertyDetails(PropertyItem item) {
    final rooms = context
        .read<AppDataRepository>()
        .rooms
        .where((r) => r.propertyId == item.id)
        .toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            CodeBadge(item.code),
            const SizedBox(width: 10),
            Expanded(child: Text(item.name, style: AppTypography.sectionTitle)),
            StatusBadge.fromPropertyStatus(item.status),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Địa chỉ: ${item.address}', style: AppTypography.body),
              const SizedBox(height: 6),
              Text('Khu vực: ${item.district}', style: AppTypography.caption),
              if (item.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Mô tả: ${item.description}', style: AppTypography.body),
              ],
              const Divider(height: 24),
              Row(
                children: [
                  _MiniStat(label: 'Tổng số phòng', value: '${item.totalRooms}'),
                  const SizedBox(width: 24),
                  _MiniStat(label: 'Đang thuê', value: '${item.occupiedRooms}'),
                  const SizedBox(width: 24),
                  _MiniStat(label: 'Còn trống', value: '${item.availableRooms}'),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Danh sách phòng thuộc nhà trọ (${rooms.length})',
                style: AppTypography.cardTitle,
              ),
              const SizedBox(height: 8),
              if (rooms.isEmpty)
                const Text('Chưa có phòng nào được gán.', style: AppTypography.caption)
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: rooms.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, idx) {
                      final r = rooms[idx];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            CodeBadge(r.code),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${r.name} · ${r.area.toStringAsFixed(0)} m²',
                                style: AppTypography.bodyMedium,
                              ),
                            ),
                            StatusBadge.fromRoomStatus(r.status),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          AppButton(
            label: 'Đóng',
            variant: AppButtonVariant.outlined,
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(PropertyItem item) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Xác nhận xóa nhà trọ',
      message:
          'Bạn có chắc chắn muốn xóa nhà trọ "${item.name}" (${item.code})? Hành động này sẽ ngừng kích hoạt dữ liệu nhà trọ.',
    );
    if (!confirmed || !mounted) return;
    final err = await context.read<AppDataRepository>().deleteProperty(item.id);
    if (!mounted) return;
    if (err != null) {
      showErrorToast(context, err);
      return;
    }
    showSuccessToast(context, 'Đã xóa nhà trọ "${item.name}"');
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppDataRepository>();
    final query = _searchCtrl.text.trim().toLowerCase();

    final filtered = repo.properties.where((p) {
      final matchesStatus = _statusFilter == 'ALL' || p.status == _statusFilter;
      final matchesQuery = query.isEmpty ||
          p.name.toLowerCase().contains(query) ||
          p.code.toLowerCase().contains(query) ||
          p.address.toLowerCase().contains(query) ||
          p.district.toLowerCase().contains(query);
      return matchesStatus && matchesQuery;
    }).toList();

    final start = ((_page - 1) * _pageSize).clamp(0, filtered.length);
    final end = (_page * _pageSize).clamp(0, filtered.length);
    final paged = filtered.sublist(start, end);

    final activeCount =
        repo.properties.where((p) => p.status == 'ACTIVE').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Quản lý Tòa nhà',
          subtitle: 'Quản lý danh sách các cơ sở, tòa nhà trọ và công suất phòng.',
          actions: [
            AppButton(
              label: '+ Thêm tòa nhà mới',
              onPressed: () => _openPropertyForm(),
            ),
          ],
        ),

        // Stitch Property Header Card (Banner + Recessed Stats Strip)
        PropertyHeaderCard(
          totalProperties: repo.totalPropertiesCount,
          activeProperties: activeCount,
          totalRooms: repo.totalRoomsCount,
          occupiedRooms: repo.occupiedRoomsCount,
          availableRooms: repo.availableRoomsCount,
          maintenanceRooms: repo.maintenanceRoomsCount,
        ),

        const SizedBox(height: AppSpacing.xl),

        // Filter Bar
        AppSurfaceCard(
          padding: AppSpacing.cardPadding,
          child: Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppSearchBar(
                controller: _searchCtrl,
                hintText: 'Tìm theo tên tòa nhà, mã, địa chỉ...',
                onChanged: (_) => setState(() => _page = 1),
              ),
              AppSelect<String>(
                label: 'Trạng thái',
                value: _statusFilter,
                options: const [
                  AppSelectOption(value: 'ALL', label: 'Tất cả trạng thái'),
                  AppSelectOption(value: 'ACTIVE', label: 'Đang hoạt động'),
                  AppSelectOption(value: 'INACTIVE', label: 'Tạm ngưng'),
                ],
                onChanged: (v) => setState(() {
                  _statusFilter = v ?? 'ALL';
                  _page = 1;
                }),
              ),
              if (query.isNotEmpty || _statusFilter != 'ALL')
                AppButton(
                  label: 'Đặt lại',
                  variant: AppButtonVariant.outlined,
                  compact: true,
                  onPressed: () => setState(() {
                    _searchCtrl.clear();
                    _statusFilter = 'ALL';
                    _page = 1;
                  }),
                ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        if (filtered.isEmpty)
          EmptyState(
            icon: Icons.apartment_rounded,
            title: 'Không tìm thấy tòa nhà nào',
            subtitle: 'Thử thay đổi từ khóa tìm kiếm hoặc thêm tòa nhà mới vào hệ thống.',
            actionLabel: '+ Thêm tòa nhà mới',
            onAction: () => _openPropertyForm(),
          )
        else
          AppSurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                AppTable<PropertyItem>(
                  items: paged,
                  onRowTap: _showPropertyDetails,
                  columns: [
                    AppTableColumn(
                      label: 'TÒA NHÀ & THÔNG SỐ',
                      flex: 3,
                      cellBuilder: (item) => Row(
                        children: [
                          CodeBadge(item.code),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  item.name,
                                  style: AppTypography.bodyBold,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${item.totalRooms} phòng · ${item.district}',
                                  style: AppTypography.caption,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppTableColumn(
                      label: 'ĐỊA CHỈ',
                      flex: 3,
                      cellBuilder: (item) => Text(
                        item.address,
                        style: AppTypography.bodyMd,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    AppTableColumn(
                      label: 'HIỆN TRẠNG CÔNG SUẤT',
                      flex: 2,
                      cellBuilder: (item) {
                        final ratio = item.totalRooms > 0
                            ? item.occupiedRooms / item.totalRooms
                            : 0.0;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${item.occupiedRooms}/${item.totalRooms} thuê',
                                  style: AppTypography.labelSm.copyWith(
                                    color: AppColors.primary,
                                  ),
                                ),
                                Text(
                                  '${item.availableRooms} trống',
                                  style: AppTypography.labelSm.copyWith(
                                    color: AppColors.successText,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppSpacing.pillRadius,
                              ),
                              child: LinearProgressIndicator(
                                value: ratio.clamp(0.0, 1.0),
                                minHeight: 6,
                                backgroundColor: AppColors.surfaceMuted,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.secondary,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    AppTableColumn(
                      label: 'TRẠNG THÁI',
                      width: 155,
                      cellBuilder: (item) =>
                          StatusBadge.fromPropertyStatus(item.status),
                    ),
                    AppTableColumn(
                      label: 'THAO TÁC',
                      width: 130,
                      alignment: Alignment.centerRight,
                      cellBuilder: (item) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Xem chi tiết',
                            icon: const Icon(
                              Icons.visibility_outlined,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            onPressed: () => _showPropertyDetails(item),
                          ),
                          IconButton(
                            tooltip: 'Chỉnh sửa',
                            icon: const Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            onPressed: () => _openPropertyForm(item),
                          ),
                          IconButton(
                            tooltip: 'Xóa',
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: AppColors.error,
                            ),
                            onPressed: () => _confirmDelete(item),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                PaginationWidget(
                  currentPage: _page,
                  totalItems: filtered.length,
                  pageSize: _pageSize,
                  onPageChanged: (p) => setState(() => _page = p),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.caption),
        const SizedBox(height: 2),
        Text(value, style: AppTypography.sectionTitle),
      ],
    );
  }
}

