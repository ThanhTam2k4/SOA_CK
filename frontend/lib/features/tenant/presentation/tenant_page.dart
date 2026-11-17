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
    final idCardCtrl = TextEditingController(text: existing?.idCard ?? '');
    final addressCtrl = TextEditingController(text: existing?.permanentAddress ?? '');
    final occupationCtrl = TextEditingController(text: existing?.occupation ?? '');
    final emergNameCtrl = TextEditingController(text: existing?.emergencyContactName ?? '');
    final emergPhoneCtrl = TextEditingController(text: existing?.emergencyContactPhone ?? '');
    final startCtrl = TextEditingController(text: existing?.startDate ?? '2026-11-01');
    int? selectedRoomId = existing?.roomId ?? (repo.rooms.isNotEmpty ? repo.rooms.first.id : null);
    bool tempReg = existing?.temporaryResidenceRegistered ?? false;
    String status = existing?.status ?? 'ACTIVE';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text(
            existing == null ? 'Thêm người thuê mới' : 'Chỉnh sửa hồ sơ người thuê',
            style: AppTypography.sectionTitle,
          ),
          content: SizedBox(
            width: 560,
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
                            label: 'Họ và tên',
                            controller: nameCtrl,
                            requiredField: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            label: 'CCCD / CMND',
                            controller: idCardCtrl,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
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
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: repo.rooms.isEmpty
                              ? AppTextField(
                                  label: 'Ngày bắt đầu',
                                  controller: startCtrl,
                                )
                              : AppSelect<int?>(
                                  label: 'Phòng hiện tại',
                                  width: null,
                                  value: repo.rooms.any((r) => r.id == selectedRoomId)
                                      ? selectedRoomId
                                      : null,
                                  options: [
                                    const AppSelectOption<int?>(
                                      value: null,
                                      label: 'Chưa gán phòng',
                                    ),
                                    for (final r in repo.rooms)
                                      AppSelectOption<int?>(
                                        value: r.id,
                                        label: '${r.name} — ${r.propertyName}',
                                      ),
                                  ],
                                  onChanged: (v) => setModalState(() => selectedRoomId = v),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppSelect<String>(
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
                        ),
                      ],
                    ),
                    // Không có danh sách phòng thì không chọn phòng được: nói rõ lý do
                    // (đang tải / lỗi / không có quyền / thật sự chưa có phòng).
                    if (repo.rooms.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _roomsUnavailableText(repo),
                          key: const Key('tenant_form_rooms_status'),
                          style: AppTypography.caption.copyWith(color: AppColors.warningText),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'Nghề nghiệp',
                            controller: occupationCtrl,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            label: 'Địa chỉ thường trú',
                            controller: addressCtrl,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'Liên hệ khẩn cấp',
                            controller: emergNameCtrl,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            label: 'SĐT khẩn cấp',
                            controller: emergPhoneCtrl,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Đã đăng ký tạm trú', style: AppTypography.bodyBold),
                      value: tempReg,
                      onChanged: (v) => setModalState(() => tempReg = v ?? false),
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
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final matchedRoom = selectedRoomId != null
                    ? repo.rooms.where((r) => r.id == selectedRoomId).firstOrNull
                    : null;
                final item = TenantItem(
                  id: existing?.id ?? DateTime.now().millisecondsSinceEpoch,
                  roomId: selectedRoomId,
                  fullName: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  email: emailCtrl.text.trim(),
                  idCard: idCardCtrl.text.trim(),
                  currentRoom: matchedRoom?.name ?? existing?.currentRoom ?? 'Chưa gán phòng',
                  propertyName: matchedRoom?.propertyName ?? existing?.propertyName ?? '',
                  startDate: startCtrl.text.trim(),
                  status: status,
                  permanentAddress: addressCtrl.text.trim(),
                  occupation: occupationCtrl.text.trim(),
                  emergencyContactName: emergNameCtrl.text.trim(),
                  emergencyContactPhone: emergPhoneCtrl.text.trim(),
                  temporaryResidenceRegistered: tempReg,
                );
                final err = existing == null
                    ? await repo.addTenant(item)
                    : await repo.updateTenant(item);
                if (!ctx.mounted || !mounted) return;
                if (err != null) {
                  showErrorToast(context, err);
                  return;
                }
                Navigator.pop(ctx);
                showSuccessToast(
                  context,
                  existing == null
                      ? 'Đã thêm khách thuê "${nameCtrl.text.trim()}"'
                      : 'Đã cập nhật "${nameCtrl.text.trim()}"',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static String _roomsUnavailableText(AppDataRepository repo) {
    final state = repo.sectionState(DataSection.rooms);
    if (state.isForbidden) return 'Tài khoản của bạn không có quyền xem danh sách phòng nên chưa thể gán phòng.';
    if (state.isError) {
      return 'Không tải được danh sách phòng: ${state.message ?? 'lỗi không xác định'}. Chưa thể gán phòng.';
    }
    if (state.isLoading || (repo.isSyncing && !state.isLoaded)) return 'Đang tải danh sách phòng...';
    if (!state.isLoaded) return 'Chưa tải được danh sách phòng nên chưa thể gán phòng.';
    return 'Hệ thống chưa có phòng nào để gán.';
  }

  /// Mở hộp thoại ngay; lịch sử được tải bên trong (đang tải / lỗi + Thử lại / 403 / rỗng / dữ liệu).
  void _openHistoryDialog(TenantItem tenant) {
    final repo = context.read<AppDataRepository>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Lịch sử cư trú: ${tenant.fullName}', style: AppTypography.sectionTitle),
        content: SizedBox(
          width: 540,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CCCD: ${tenant.idCard.isNotEmpty ? tenant.idCard : '—'} · Nghề nghiệp: ${tenant.occupation.isNotEmpty ? tenant.occupation : '—'}',
                style: AppTypography.caption,
              ),
              const SizedBox(height: 4),
              Text(
                'Tạm trú: ${tenant.temporaryResidenceRegistered ? 'Đã đăng ký' : 'Chưa đăng ký'} · Địa chỉ: ${tenant.permanentAddress.isNotEmpty ? tenant.permanentAddress : '—'}',
                style: AppTypography.caption,
              ),
              const Divider(height: 20),
              HistoryLoader<TenantHistoryItem>(
                load: () => repo.fetchTenantHistory(tenant.id),
                what: 'lịch sử thuê phòng',
                emptyText: 'Chưa có bản ghi lịch sử thuê phòng.',
                builder: (_, history) => ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: history.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, idx) {
                      final h = history[idx];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Vào ở: ${h.moveInDate}${h.moveOutDate.isNotEmpty ? ' → Trả phòng: ${h.moveOutDate}' : ' (Đang ở)'}',
                          style: AppTypography.bodyBold,
                        ),
                        subtitle: Text(
                          '${h.roomId != null ? 'Phòng #${h.roomId} · ' : ''}${h.note}',
                          style: AppTypography.caption,
                        ),
                      );
                    },
                  ),
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

  Future<void> _confirmDelete(TenantItem item) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Xóa hồ sơ người thuê',
      message: 'Bạn có chắc chắn muốn xóa khách thuê "${item.fullName}" (${item.currentRoom})?',
    );
    if (!confirmed || !mounted) return;
    final err = await context.read<AppDataRepository>().deleteTenant(item.id);
    if (!mounted) return;
    if (err != null) {
      showErrorToast(context, err);
      return;
    }
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

    // Sau khi xóa / lọc, số trang có thể giảm: không để trang hiện tại vượt quá trang cuối.
    final pageCount = filtered.isEmpty ? 1 : (filtered.length + _pageSize - 1) ~/ _pageSize;
    final page = _page.clamp(1, pageCount);
    final start = ((page - 1) * _pageSize).clamp(0, filtered.length);
    final end = (page * _pageSize).clamp(0, filtered.length);
    final paged = filtered.sublist(start, end);
    final hasFilter = query.isNotEmpty || _statusFilter != 'ALL';

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

        SectionListGate(
          state: repo.sectionState(DataSection.tenants),
          isSyncing: repo.isSyncing,
          lastSyncError: repo.lastSyncError,
          hasData: repo.tenants.isNotEmpty,
          what: 'danh sách người thuê',
          keyPrefix: 'tenant_list',
          onRetry: repo.syncWithBackend,
          empty: EmptyState(
            key: const Key('tenant_list_empty'),
            icon: Icons.people_outline_rounded,
            title: 'Chưa có người thuê nào',
            subtitle: 'Hệ thống chưa có hồ sơ người thuê nào trong phạm vi quản lý của bạn.',
            actionLabel: '+ Thêm người thuê',
            onAction: () => _openTenantForm(),
          ),
          noMatch: filtered.isNotEmpty
              ? null
              : EmptyState(
                  key: const Key('tenant_list_no_match'),
                  icon: Icons.search_off_rounded,
                  title: 'Chưa tìm thấy người thuê',
                  subtitle: 'Không có người thuê nào khớp với từ khóa hoặc bộ lọc hiện tại.',
                  actionLabel: hasFilter ? 'Đặt lại bộ lọc' : null,
                  onAction: hasFilter
                      ? () => setState(() {
                            _searchCtrl.clear();
                            _statusFilter = 'ALL';
                            _page = 1;
                          })
                      : null,
                ),
          builder: (_) => AppSurfaceCard(
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
                      width: 145,
                      alignment: Alignment.centerRight,
                      cellBuilder: (t) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Lịch sử cư trú & Hồ sơ',
                            icon: const Icon(
                              Icons.history_rounded,
                              size: 18,
                              color: AppColors.secondary,
                            ),
                            onPressed: () => _openHistoryDialog(t),
                          ),
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
                  currentPage: page,
                  totalItems: filtered.length,
                  pageSize: _pageSize,
                  onPageChanged: (p) => setState(() => _page = p),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

