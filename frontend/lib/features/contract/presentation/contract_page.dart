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

class ContractPage extends StatefulWidget {
  const ContractPage({super.key});

  @override
  State<ContractPage> createState() => _ContractPageState();
}

class _ContractPageState extends State<ContractPage> {
  final _searchCtrl = TextEditingController();
  String _statusFilter = 'ALL';
  int _page = 1;
  static const int _pageSize = 6;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openContractForm([ContractItem? existing]) {
    final repo = context.read<AppDataRepository>();
    final formKey = GlobalKey<FormState>();
    final codeCtrl = TextEditingController(
      text: existing?.code ?? 'HD-2026-0${repo.contracts.length + 10}',
    );
    final tenantCtrl = TextEditingController(text: existing?.tenantName ?? '');
    final roomCtrl = TextEditingController(text: existing?.roomName ?? 'Phòng A101');
    final propCtrl = TextEditingController(
      text: existing?.propertyName ??
          (repo.properties.isNotEmpty ? repo.properties.first.name : ''),
    );
    final startCtrl = TextEditingController(text: existing?.startDate ?? '01/11/2026');
    final endCtrl = TextEditingController(text: existing?.endDate ?? '01/11/2027');
    final rentCtrl = TextEditingController(text: '${existing?.rentPrice.toInt() ?? 3800000}');
    final depCtrl = TextEditingController(text: '${existing?.depositAmount.toInt() ?? 7600000}');
    String status = existing?.status ?? 'ACTIVE';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text(
            existing == null ? 'Tạo hợp đồng thuê mới' : 'Cập nhật hợp đồng',
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
                            label: 'Mã hợp đồng',
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
                              AppSelectOption(value: 'ACTIVE', label: 'Đang hiệu lực'),
                              AppSelectOption(value: 'EXPIRING', label: 'Sắp hết hạn'),
                              AppSelectOption(value: 'EXPIRED', label: 'Đã hết hạn'),
                              AppSelectOption(value: 'CANCELLED', label: 'Đã hủy'),
                            ],
                            onChanged: (v) => setModalState(() => status = v ?? 'ACTIVE'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'Người thuê',
                            controller: tenantCtrl,
                            requiredField: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            label: 'Phòng thuê',
                            controller: roomCtrl,
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
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'Ngày bắt đầu',
                            controller: startCtrl,
                            requiredField: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            label: 'Ngày kết thúc',
                            controller: endCtrl,
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
                            label: 'Giá thuê (VNĐ/tháng)',
                            controller: rentCtrl,
                            requiredField: true,
                            isNumber: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            label: 'Tiền đặt cọc (VNĐ)',
                            controller: depCtrl,
                            requiredField: true,
                            isNumber: true,
                          ),
                        ),
                      ],
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
              label: existing == null ? 'Tạo hợp đồng' : 'Lưu thay đổi',
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final rent = double.tryParse(rentCtrl.text.trim()) ?? 0;
                final dep = double.tryParse(depCtrl.text.trim()) ?? 0;

                if (existing == null) {
                  repo.addContract(
                    ContractItem(
                      id: DateTime.now().millisecondsSinceEpoch,
                      code: codeCtrl.text.trim(),
                      tenantName: tenantCtrl.text.trim(),
                      roomName: roomCtrl.text.trim(),
                      propertyName: propCtrl.text.trim(),
                      startDate: startCtrl.text.trim(),
                      endDate: endCtrl.text.trim(),
                      rentPrice: rent,
                      depositAmount: dep,
                      status: status,
                    ),
                  );
                  Navigator.pop(ctx);
                  showSuccessToast(context, 'Đã tạo hợp đồng "${codeCtrl.text.trim()}"');
                } else {
                  repo.updateContract(
                    existing.copyWith(
                      code: codeCtrl.text.trim(),
                      tenantName: tenantCtrl.text.trim(),
                      roomName: roomCtrl.text.trim(),
                      propertyName: propCtrl.text.trim(),
                      startDate: startCtrl.text.trim(),
                      endDate: endCtrl.text.trim(),
                      rentPrice: rent,
                      depositAmount: dep,
                      status: status,
                    ),
                  );
                  Navigator.pop(ctx);
                  showSuccessToast(context, 'Đã cập nhật hợp đồng "${codeCtrl.text.trim()}"');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(ContractItem item) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Xóa hợp đồng thuê',
      message: 'Bạn có chắc chắn muốn xóa hợp đồng "${item.code}" của khách ${item.tenantName}?',
    );
    if (!confirmed || !mounted) return;
    context.read<AppDataRepository>().deleteContract(item.id);
    showSuccessToast(context, 'Đã xóa hợp đồng "${item.code}"');
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppDataRepository>();
    final query = _searchCtrl.text.trim().toLowerCase();

    final filtered = repo.contracts.where((c) {
      final matchesStatus = _statusFilter == 'ALL' || c.status == _statusFilter;
      final matchesQuery = query.isEmpty ||
          c.code.toLowerCase().contains(query) ||
          c.tenantName.toLowerCase().contains(query) ||
          c.roomName.toLowerCase().contains(query);
      return matchesStatus && matchesQuery;
    }).toList();

    final start = ((_page - 1) * _pageSize).clamp(0, filtered.length);
    final end = (_page * _pageSize).clamp(0, filtered.length);
    final paged = filtered.sublist(start, end);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Quản lý hợp đồng',
          subtitle: 'Quản lý thời hạn hợp đồng, tiền đặt cọc và gia hạn thuê phòng.',
          actions: [
            AppButton(
              label: '+ Tạo hợp đồng',
              onPressed: () => _openContractForm(),
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
                hintText: 'Tìm theo mã hợp đồng, người thuê, phòng...',
                onChanged: (_) => setState(() => _page = 1),
              ),
              AppSelect<String>(
                label: 'Trạng thái',
                value: _statusFilter,
                options: const [
                  AppSelectOption(value: 'ALL', label: 'Tất cả trạng thái'),
                  AppSelectOption(value: 'ACTIVE', label: 'Đang hiệu lực'),
                  AppSelectOption(value: 'EXPIRING', label: 'Sắp hết hạn'),
                  AppSelectOption(value: 'EXPIRED', label: 'Đã hết hạn'),
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
            icon: Icons.description_outlined,
            title: 'Không có hợp đồng nào',
            subtitle: 'Thử điều chỉnh bộ lọc hoặc tạo hợp đồng thuê mới.',
            actionLabel: '+ Tạo hợp đồng',
            onAction: () => _openContractForm(),
          )
        else
          AppSurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                AppTable<ContractItem>(
                  items: paged,
                  columns: [
                    AppTableColumn(
                      label: 'MÃ HỢP ĐỒNG',
                      width: 145,
                      cellBuilder: (c) => CodeBadge(c.code),
                    ),
                    AppTableColumn(
                      label: 'NGƯỜI THUÊ',
                      flex: 2,
                      cellBuilder: (c) => Text(c.tenantName, style: AppTypography.bodySemiBold),
                    ),
                    AppTableColumn(
                      label: 'PHÒNG',
                      flex: 2,
                      cellBuilder: (c) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(c.roomName, style: AppTypography.bodyMedium),
                          Text(
                            c.propertyName,
                            style: AppTypography.caption,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    AppTableColumn(
                      label: 'NGÀY BẮT ĐẦU',
                      width: 125,
                      cellBuilder: (c) => Text(c.startDate, style: AppTypography.body),
                    ),
                    AppTableColumn(
                      label: 'NGÀY KẾT THÚC',
                      width: 125,
                      cellBuilder: (c) => Text(c.endDate, style: AppTypography.body),
                    ),
                    AppTableColumn(
                      label: 'TIỀN ĐẶT CỌC',
                      width: 145,
                      cellBuilder: (c) => Text(
                        AppFormatters.currency(c.depositAmount),
                        style: AppTypography.bodySemiBold,
                      ),
                    ),
                    AppTableColumn(
                      label: 'TRẠNG THÁI',
                      width: 150,
                      cellBuilder: (c) => StatusBadge.fromContractStatus(c.status),
                    ),
                    AppTableColumn(
                      label: 'THAO TÁC',
                      width: 105,
                      alignment: Alignment.centerRight,
                      cellBuilder: (c) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Chỉnh sửa',
                            icon: const Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            onPressed: () => _openContractForm(c),
                          ),
                          IconButton(
                            tooltip: 'Xóa',
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: AppColors.error,
                            ),
                            onPressed: () => _confirmDelete(c),
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

