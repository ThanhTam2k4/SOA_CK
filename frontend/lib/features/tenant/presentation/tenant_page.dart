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

class TenantPage extends StatefulWidget {
  const TenantPage({super.key});

  @override
  State<TenantPage> createState() => _TenantPageState();
}

class _TenantPageState extends State<TenantPage> {
  final _searchCtrl = TextEditingController();
  String _statusFilter = 'ALL';
  int _page = 1;
  static const int _pageSize = 6;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openTenantForm([TenantItem? existing]) {
    final repo = context.read<AppDataRepository>();
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: existing?.fullName ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final roomCtrl = TextEditingController(
      text: existing?.currentRoom ?? (repo.rooms.isNotEmpty ? repo.rooms.first.name : 'Phòng A101'),
    );
    final propCtrl = TextEditingController(
      text: existing?.propertyName ?? (repo.properties.isNotEmpty ? repo.properties.first.name : ''),
    );
    final startCtrl = TextEditingController(text: existing?.startDate ?? '01/11/2026');
    String status = existing?.status ?? 'ACTIVE';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text(
            existing == null ? 'Thêm người thuê mới' : 'Chỉnh sửa thông tin người thuê',
            style: AppTypography.sectionTitle,
          ),
          content: SizedBox(
            width: 500,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppTextField(
                      label: 'Họ và tên',
                      controller: nameCtrl,
                      requiredField: true,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'Số điện thoại',
                            controller: phoneCtrl,
                            requiredField: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            label: 'Email',
                            controller: emailCtrl,
                            requiredField: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'Phòng hiện tại',
                            controller: roomCtrl,
                            requiredField: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            label: 'Ngày bắt đầu thuê',
                            controller: startCtrl,
                            requiredField: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      label: 'Nhà trọ',
                      controller: propCtrl,
                      requiredField: true,
                    ),
                    const SizedBox(height: 14),
                    AppSelect<String>(
                      label: 'Trạng thái',
                      width: null,
                      value: status,
                      options: const [
                        AppSelectOption(value: 'ACTIVE', label: 'Đang thuê'),
                        AppSelectOption(value: 'TEMPORARY_ABSENT', label: 'Tạm vắng'),
                        AppSelectOption(value: 'MOVED_OUT', label: 'Đã trả phòng'),
                      ],
                      onChanged: (v) => setModalState(() => status = v ?? 'ACTIVE'),
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
              label: existing == null ? 'Thêm người thuê' : 'Lưu thay đổi',
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                if (existing == null) {
                  repo.addTenant(
                    TenantItem(
                      id: DateTime.now().millisecondsSinceEpoch,
                      fullName: nameCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                      email: emailCtrl.text.trim(),
                      currentRoom: roomCtrl.text.trim(),
                      propertyName: propCtrl.text.trim(),
                      startDate: startCtrl.text.trim(),
                      status: status,
                    ),
                  );
                  Navigator.pop(ctx);
                  showSuccessToast(context, 'Đã thêm khách thuê "${nameCtrl.text.trim()}"');
                } else {
                  repo.updateTenant(
                    existing.copyWith(
                      fullName: nameCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                      email: emailCtrl.text.trim(),
                      currentRoom: roomCtrl.text.trim(),
                      propertyName: propCtrl.text.trim(),
                      startDate: startCtrl.text.trim(),
                      status: status,
                    ),
                  );
                  Navigator.pop(ctx);
                  showSuccessToast(context, 'Đã cập nhật "${nameCtrl.text.trim()}"');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(TenantItem item) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Xóa hồ sơ người thuê',
      message: 'Bạn có chắc chắn muốn xóa khách thuê "${item.fullName}" (${item.currentRoom})?',
    );
    if (!confirmed || !mounted) return;
    context.read<AppDataRepository>().deleteTenant(item.id);
    showSuccessToast(context, 'Đã xóa hồ sơ "${item.fullName}"');
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppDataRepository>();
    final query = _searchCtrl.text.trim().toLowerCase();

    final filtered = repo.tenants.where((t) {
      final matchesStatus = _statusFilter == 'ALL' || t.status == _statusFilter;
      final matchesQuery = query.isEmpty ||
          t.fullName.toLowerCase().contains(query) ||
          t.phone.toLowerCase().contains(query) ||
          t.email.toLowerCase().contains(query) ||
          t.currentRoom.toLowerCase().contains(query);
      return matchesStatus && matchesQuery;
    }).toList();

    final start = ((_page - 1) * _pageSize).clamp(0, filtered.length);
    final end = (_page * _pageSize).clamp(0, filtered.length);
    final paged = filtered.sublist(start, end);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Quản lý người thuê',
          subtitle: 'Quản lý thông tin liên hệ, tạm trú và lịch sử thuê phòng của khách.',
          actions: [
            AppButton(
              label: '+ Thêm người thuê',
              onPressed: () => _openTenantForm(),
            ),
          ],
        ),

        AppSurfaceCard(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppSearchBar(
                controller: _searchCtrl,
                hintText: 'Tìm theo họ tên, SĐT, email, phòng...',
                onChanged: (_) => setState(() => _page = 1),
              ),
              AppSelect<String>(
                label: 'Trạng thái',
                value: _statusFilter,
                options: const [
                  AppSelectOption(value: 'ALL', label: 'Tất cả trạng thái'),
                  AppSelectOption(value: 'ACTIVE', label: 'Đang thuê'),
                  AppSelectOption(value: 'TEMPORARY_ABSENT', label: 'Tạm vắng'),
                  AppSelectOption(value: 'MOVED_OUT', label: 'Đã trả phòng'),
                ],
                onChanged: (v) => setState(() {
                  _statusFilter = v ?? 'ALL';
                  _page = 1;
                }),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        if (filtered.isEmpty)
          EmptyState(
            icon: Icons.people_outline_rounded,
            title: 'Chưa tìm thấy người thuê',
            subtitle: 'Thử từ khóa khác hoặc thêm hồ sơ người thuê mới.',
            actionLabel: '+ Thêm người thuê',
            onAction: () => _openTenantForm(),
          )
        else
          AppSurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                AppTable<TenantItem>(
                  items: paged,
                  columns: [
                    AppTableColumn(
                      label: 'HỌ TÊN',
                      flex: 2,
                      cellBuilder: (t) => Text(t.fullName, style: AppTypography.bodySemiBold),
                    ),
                    AppTableColumn(
                      label: 'SỐ ĐIỆN THOẠI',
                      width: 140,
                      cellBuilder: (t) => Text(t.phone, style: AppTypography.body),
                    ),
                    AppTableColumn(
                      label: 'EMAIL',
                      flex: 2,
                      cellBuilder: (t) => Text(
                        t.email,
                        style: AppTypography.body,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    AppTableColumn(
                      label: 'PHÒNG HIỆN TẠI',
                      flex: 2,
                      cellBuilder: (t) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(t.currentRoom, style: AppTypography.bodyMedium),
                          Text(
                            t.propertyName,
                            style: AppTypography.caption,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    AppTableColumn(
                      label: 'NGÀY BẮT ĐẦU THUÊ',
                      width: 150,
                      cellBuilder: (t) => Text(t.startDate, style: AppTypography.body),
                    ),
                    AppTableColumn(
                      label: 'TRẠNG THÁI',
                      width: 145,
                      cellBuilder: (t) => StatusBadge.fromTenantStatus(t.status),
                    ),
                    AppTableColumn(
                      label: 'THAO TÁC',
                      width: 105,
                      alignment: Alignment.centerRight,
                      cellBuilder: (t) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Chỉnh sửa',
                            icon: const Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            onPressed: () => _openTenantForm(t),
                          ),
                          IconButton(
                            tooltip: 'Xóa',
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: AppColors.error,
                            ),
                            onPressed: () => _confirmDelete(t),
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

