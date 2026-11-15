import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
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

class MaintenancePage extends StatefulWidget {
  const MaintenancePage({super.key});

  @override
  State<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends State<MaintenancePage> {
  final _searchCtrl = TextEditingController();
  String _priorityFilter = 'ALL';
  String _statusFilter = 'ALL';
  int _page = 1;
  static const int _pageSize = 6;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openMaintenanceForm([MaintenanceItem? existing]) {
    final repo = context.read<AppDataRepository>();
    final formKey = GlobalKey<FormState>();
    final codeCtrl = TextEditingController(
      text: existing?.code ?? 'BT-00${repo.maintenances.length + 1}',
    );
    final roomCtrl = TextEditingController(text: existing?.roomName ?? 'Phòng A101');
    final propCtrl = TextEditingController(
      text: existing?.propertyName ??
          (repo.properties.isNotEmpty ? repo.properties.first.name : ''),
    );
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final dateCtrl = TextEditingController(text: existing?.createdAt ?? '13/11/2026');
    final costCtrl = TextEditingController(
      text: '${existing?.estimatedCost.toInt() ?? 350000}',
    );
    String priority = existing?.priority ?? 'MEDIUM';
    String status = existing?.status ?? 'PENDING';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text(
            existing == null ? 'Tạo yêu cầu bảo trì' : 'Cập nhật yêu cầu bảo trì',
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
                            label: 'Mã yêu cầu',
                            controller: codeCtrl,
                            requiredField: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            label: 'Ngày tạo',
                            controller: dateCtrl,
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
                            label: 'Phòng',
                            controller: roomCtrl,
                            requiredField: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            label: 'Chi phí dự kiến (VNĐ)',
                            controller: costCtrl,
                            isNumber: true,
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
                    AppTextField(
                      label: 'Nội dung yêu cầu',
                      controller: titleCtrl,
                      hint: 'VD: Sửa điều hòa, thay bóng đèn...',
                      requiredField: true,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: AppSelect<String>(
                            label: 'Mức độ ưu tiên',
                            width: null,
                            value: priority,
                            options: const [
                              AppSelectOption(value: 'LOW', label: 'Thấp'),
                              AppSelectOption(value: 'MEDIUM', label: 'Trung bình'),
                              AppSelectOption(value: 'HIGH', label: 'Cao'),
                            ],
                            onChanged: (v) => setModalState(() => priority = v ?? 'MEDIUM'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppSelect<String>(
                            label: 'Trạng thái',
                            width: null,
                            value: status,
                            options: const [
                              AppSelectOption(value: 'PENDING', label: 'Chờ xử lý'),
                              AppSelectOption(value: 'IN_PROGRESS', label: 'Đang xử lý'),
                              AppSelectOption(value: 'COMPLETED', label: 'Hoàn thành'),
                              AppSelectOption(value: 'CANCELLED', label: 'Đã hủy'),
                            ],
                            onChanged: (v) => setModalState(() => status = v ?? 'PENDING'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      label: 'Mô tả chi tiết / Phương án xử lý',
                      controller: descCtrl,
                      maxLines: 2,
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
              label: existing == null ? 'Tạo yêu cầu' : 'Lưu thay đổi',
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final cost = double.tryParse(costCtrl.text.trim()) ?? 0;

                if (existing == null) {
                  repo.addMaintenance(
                    MaintenanceItem(
                      id: DateTime.now().millisecondsSinceEpoch,
                      code: codeCtrl.text.trim(),
                      roomId: 0,
                      roomName: roomCtrl.text.trim(),
                      propertyName: propCtrl.text.trim(),
                      title: titleCtrl.text.trim(),
                      description: descCtrl.text.trim(),
                      createdAt: dateCtrl.text.trim(),
                      priority: priority,
                      status: status,
                      estimatedCost: cost,
                    ),
                  );
                  Navigator.pop(ctx);
                  showSuccessToast(context, 'Đã tạo yêu cầu bảo trì "${codeCtrl.text.trim()}"');
                } else {
                  repo.updateMaintenance(
                    existing.copyWith(
                      code: codeCtrl.text.trim(),
                      roomName: roomCtrl.text.trim(),
                      propertyName: propCtrl.text.trim(),
                      title: titleCtrl.text.trim(),
                      description: descCtrl.text.trim(),
                      createdAt: dateCtrl.text.trim(),
                      priority: priority,
                      status: status,
                      estimatedCost: cost,
                    ),
                  );
                  Navigator.pop(ctx);
                  showSuccessToast(context, 'Đã cập nhật yêu cầu "${codeCtrl.text.trim()}"');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _markCompleted(MaintenanceItem item) {
    context.read<AppDataRepository>().updateMaintenance(item.copyWith(status: 'COMPLETED'));
    showSuccessToast(context, 'Đã hoàn thành yêu cầu bảo trì ${item.code}');
  }

  Future<void> _confirmDelete(MaintenanceItem item) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Xóa yêu cầu bảo trì',
      message: 'Bạn có chắc chắn muốn xóa yêu cầu "${item.code}" (${item.roomName})?',
    );
    if (!confirmed || !mounted) return;
    context.read<AppDataRepository>().deleteMaintenance(item.id);
    showSuccessToast(context, 'Đã xóa yêu cầu "${item.code}"');
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppDataRepository>();
    final query = _searchCtrl.text.trim().toLowerCase();

    final filtered = repo.maintenances.where((m) {
      final matchesPriority = _priorityFilter == 'ALL' || m.priority == _priorityFilter;
      final matchesStatus = _statusFilter == 'ALL' || m.status == _statusFilter;
      final matchesQuery = query.isEmpty ||
          m.code.toLowerCase().contains(query) ||
          m.roomName.toLowerCase().contains(query) ||
          m.title.toLowerCase().contains(query);
      return matchesPriority && matchesStatus && matchesQuery;
    }).toList();

    final start = ((_page - 1) * _pageSize).clamp(0, filtered.length);
    final end = (_page * _pageSize).clamp(0, filtered.length);
    final paged = filtered.sublist(start, end);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Bảo trì & sửa chữa',
          subtitle: 'Tiếp nhận sự cố kỹ thuật, phân công sửa chữa và kiểm soát chi phí bảo trì phòng.',
          actions: [
            AppButton(
              label: '+ Tạo yêu cầu bảo trì',
              onPressed: () => _openMaintenanceForm(),
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
                hintText: 'Tìm theo mã yêu cầu, phòng, nội dung...',
                onChanged: (_) => setState(() => _page = 1),
              ),
              AppSelect<String>(
                label: 'Mức độ ưu tiên',
                width: 175,
                value: _priorityFilter,
                options: const [
                  AppSelectOption(value: 'ALL', label: 'Tất cả mức độ'),
                  AppSelectOption(value: 'HIGH', label: 'Cao'),
                  AppSelectOption(value: 'MEDIUM', label: 'Trung bình'),
                  AppSelectOption(value: 'LOW', label: 'Thấp'),
                ],
                onChanged: (v) => setState(() {
                  _priorityFilter = v ?? 'ALL';
                  _page = 1;
                }),
              ),
              AppSelect<String>(
                label: 'Trạng thái',
                width: 185,
                value: _statusFilter,
                options: const [
                  AppSelectOption(value: 'ALL', label: 'Tất cả trạng thái'),
                  AppSelectOption(value: 'PENDING', label: 'Chờ xử lý'),
                  AppSelectOption(value: 'IN_PROGRESS', label: 'Đang xử lý'),
                  AppSelectOption(value: 'COMPLETED', label: 'Hoàn thành'),
                  AppSelectOption(value: 'CANCELLED', label: 'Đã hủy'),
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
            icon: Icons.build_outlined,
            title: 'Không có yêu cầu bảo trì nào',
            subtitle: 'Tất cả các phòng đang vận hành ổn định hoặc không khớp bộ lọc.',
            actionLabel: '+ Tạo yêu cầu bảo trì',
            onAction: () => _openMaintenanceForm(),
          )
        else
          AppSurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                AppTable<MaintenanceItem>(
                  items: paged,
                  columns: [
                    AppTableColumn(
                      label: 'MÃ YÊU CẦU',
                      width: 120,
                      cellBuilder: (m) => CodeBadge(m.code),
                    ),
                    AppTableColumn(
                      label: 'PHÒNG',
                      width: 180,
                      cellBuilder: (m) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(m.roomName, style: AppTypography.bodySemiBold),
                          Text(
                            m.propertyName,
                            style: AppTypography.caption,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    AppTableColumn(
                      label: 'NỘI DUNG YÊU CẦU',
                      flex: 3,
                      cellBuilder: (m) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            m.title,
                            style: AppTypography.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Chi phí dự kiến: ${AppFormatters.currency(m.estimatedCost)}',
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ),
                    AppTableColumn(
                      label: 'NGÀY TẠO',
                      width: 120,
                      cellBuilder: (m) => Text(m.createdAt, style: AppTypography.body),
                    ),
                    AppTableColumn(
                      label: 'MỨC ĐỘ ƯU TIÊN',
                      width: 140,
                      cellBuilder: (m) => StatusBadge.fromPriority(m.priority),
                    ),
                    AppTableColumn(
                      label: 'TRẠNG THÁI',
                      width: 145,
                      cellBuilder: (m) => StatusBadge.fromMaintenanceStatus(m.status),
                    ),
                    AppTableColumn(
                      label: 'THAO TÁC',
                      width: 135,
                      alignment: Alignment.centerRight,
                      cellBuilder: (m) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (m.status != 'COMPLETED')
                            IconButton(
                              tooltip: 'Đánh dấu hoàn thành',
                              icon: const Icon(
                                Icons.check_circle_outline_rounded,
                                size: 19,
                                color: AppColors.success,
                              ),
                              onPressed: () => _markCompleted(m),
                            ),
                          IconButton(
                            tooltip: 'Chỉnh sửa',
                            icon: const Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            onPressed: () => _openMaintenanceForm(m),
                          ),
                          IconButton(
                            tooltip: 'Xóa',
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: AppColors.error,
                            ),
                            onPressed: () => _confirmDelete(m),
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

