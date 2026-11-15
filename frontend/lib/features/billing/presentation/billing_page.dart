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

class BillingPage extends StatefulWidget {
  const BillingPage({super.key});

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  final _searchCtrl = TextEditingController();
  String _monthFilter = 'ALL';
  String _statusFilter = 'ALL';
  int _page = 1;
  static const int _pageSize = 6;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openInvoiceForm([InvoiceItem? existing]) {
    final repo = context.read<AppDataRepository>();
    final formKey = GlobalKey<FormState>();
    final codeCtrl = TextEditingController(
      text: existing?.code ?? 'INV-202611-0${repo.invoices.length + 1}',
    );
    final tenantCtrl = TextEditingController(text: existing?.tenantName ?? '');
    final roomCtrl = TextEditingController(text: existing?.roomName ?? 'Phòng A101');
    final propCtrl = TextEditingController(
      text: existing?.propertyName ??
          (repo.properties.isNotEmpty ? repo.properties.first.name : ''),
    );
    final monthCtrl = TextEditingController(text: existing?.billingMonth ?? '11/2026');
    final totalCtrl = TextEditingController(
      text: '${existing?.totalAmount.toInt() ?? 4200000}',
    );
    final dueCtrl = TextEditingController(text: existing?.dueDate ?? '15/11/2026');
    String status = existing?.status ?? 'UNPAID';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text(
            existing == null ? 'Lập hóa đơn mới' : 'Cập nhật hóa đơn',
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
                            label: 'Mã hóa đơn',
                            controller: codeCtrl,
                            requiredField: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            label: 'Kỳ hóa đơn (Tháng/Năm)',
                            controller: monthCtrl,
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
                            label: 'Người thuê',
                            controller: tenantCtrl,
                            requiredField: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            label: 'Phòng',
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
                            label: 'Tổng tiền (VNĐ)',
                            controller: totalCtrl,
                            requiredField: true,
                            isNumber: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            label: 'Hạn thanh toán',
                            controller: dueCtrl,
                            requiredField: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    AppSelect<String>(
                      label: 'Trạng thái thanh toán',
                      width: null,
                      value: status,
                      options: const [
                        AppSelectOption(value: 'UNPAID', label: 'Chưa thanh toán'),
                        AppSelectOption(value: 'PAID', label: 'Đã thanh toán'),
                        AppSelectOption(value: 'OVERDUE', label: 'Quá hạn'),
                      ],
                      onChanged: (v) => setModalState(() => status = v ?? 'UNPAID'),
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
              label: existing == null ? 'Lập hóa đơn' : 'Lưu thay đổi',
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final total = double.tryParse(totalCtrl.text.trim()) ?? 0;

                if (existing == null) {
                  repo.addInvoice(
                    InvoiceItem(
                      id: DateTime.now().millisecondsSinceEpoch,
                      code: codeCtrl.text.trim(),
                      tenantName: tenantCtrl.text.trim(),
                      roomName: roomCtrl.text.trim(),
                      propertyName: propCtrl.text.trim(),
                      billingMonth: monthCtrl.text.trim(),
                      totalAmount: total,
                      dueDate: dueCtrl.text.trim(),
                      status: status,
                    ),
                  );
                  Navigator.pop(ctx);
                  showSuccessToast(context, 'Đã lập hóa đơn "${codeCtrl.text.trim()}"');
                } else {
                  repo.updateInvoice(
                    existing.copyWith(
                      code: codeCtrl.text.trim(),
                      tenantName: tenantCtrl.text.trim(),
                      roomName: roomCtrl.text.trim(),
                      propertyName: propCtrl.text.trim(),
                      billingMonth: monthCtrl.text.trim(),
                      totalAmount: total,
                      dueDate: dueCtrl.text.trim(),
                      status: status,
                    ),
                  );
                  Navigator.pop(ctx);
                  showSuccessToast(context, 'Đã cập nhật hóa đơn "${codeCtrl.text.trim()}"');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _markPaid(InvoiceItem item) {
    context.read<AppDataRepository>().updateInvoice(item.copyWith(status: 'PAID'));
    showSuccessToast(context, 'Đã xác nhận thanh toán cho hóa đơn ${item.code}');
  }

  Future<void> _confirmDelete(InvoiceItem item) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Xóa hóa đơn',
      message: 'Bạn có chắc chắn muốn xóa hóa đơn "${item.code}" của khách ${item.tenantName}?',
    );
    if (!confirmed || !mounted) return;
    context.read<AppDataRepository>().deleteInvoice(item.id);
    showSuccessToast(context, 'Đã xóa hóa đơn "${item.code}"');
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppDataRepository>();
    final query = _searchCtrl.text.trim().toLowerCase();

    final filtered = repo.invoices.where((i) {
      final matchesMonth = _monthFilter == 'ALL' || i.billingMonth == _monthFilter;
      final matchesStatus = _statusFilter == 'ALL' || i.status == _statusFilter;
      final matchesQuery = query.isEmpty ||
          i.code.toLowerCase().contains(query) ||
          i.tenantName.toLowerCase().contains(query) ||
          i.roomName.toLowerCase().contains(query);
      return matchesMonth && matchesStatus && matchesQuery;
    }).toList();

    final start = ((_page - 1) * _pageSize).clamp(0, filtered.length);
    final end = (_page * _pageSize).clamp(0, filtered.length);
    final paged = filtered.sublist(start, end);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Hóa đơn',
          subtitle: 'Quản lý hóa đơn tiền thuê phòng, điện, nước và theo dõi công nợ hàng tháng.',
          actions: [
            AppButton(
              label: '+ Lập hóa đơn',
              onPressed: () => _openInvoiceForm(),
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
                hintText: 'Tìm theo mã hóa đơn, người thuê, phòng...',
                onChanged: (_) => setState(() => _page = 1),
              ),
              AppSelect<String>(
                label: 'Tháng',
                width: 165,
                value: _monthFilter,
                options: const [
                  AppSelectOption(value: 'ALL', label: 'Tất cả các tháng'),
                  AppSelectOption(value: '11/2026', label: 'Tháng 11/2026'),
                  AppSelectOption(value: '10/2026', label: 'Tháng 10/2026'),
                ],
                onChanged: (v) => setState(() {
                  _monthFilter = v ?? 'ALL';
                  _page = 1;
                }),
              ),
              AppSelect<String>(
                label: 'Trạng thái',
                width: 190,
                value: _statusFilter,
                options: const [
                  AppSelectOption(value: 'ALL', label: 'Tất cả trạng thái'),
                  AppSelectOption(value: 'PAID', label: 'Đã thanh toán'),
                  AppSelectOption(value: 'UNPAID', label: 'Chưa thanh toán'),
                  AppSelectOption(value: 'OVERDUE', label: 'Quá hạn'),
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
            icon: Icons.receipt_long_outlined,
            title: 'Chưa có hóa đơn nào phù hợp',
            subtitle: 'Thử chọn tháng khác hoặc lập hóa đơn mới cho kỳ này.',
            actionLabel: '+ Lập hóa đơn',
            onAction: () => _openInvoiceForm(),
          )
        else
          AppSurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                AppTable<InvoiceItem>(
                  items: paged,
                  columns: [
                    AppTableColumn(
                      label: 'MÃ HÓA ĐƠN',
                      width: 145,
                      cellBuilder: (i) => CodeBadge(i.code),
                    ),
                    AppTableColumn(
                      label: 'NGƯỜI THUÊ',
                      flex: 2,
                      cellBuilder: (i) => Text(i.tenantName, style: AppTypography.bodySemiBold),
                    ),
                    AppTableColumn(
                      label: 'PHÒNG',
                      flex: 2,
                      cellBuilder: (i) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(i.roomName, style: AppTypography.bodyMedium),
                          Text(
                            i.propertyName,
                            style: AppTypography.caption,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    AppTableColumn(
                      label: 'THÁNG',
                      width: 105,
                      cellBuilder: (i) => Text(i.billingMonth, style: AppTypography.bodyMedium),
                    ),
                    AppTableColumn(
                      label: 'TỔNG TIỀN',
                      width: 145,
                      cellBuilder: (i) => Text(
                        AppFormatters.currency(i.totalAmount),
                        style: AppTypography.bodySemiBold,
                      ),
                    ),
                    AppTableColumn(
                      label: 'HẠN THANH TOÁN',
                      width: 135,
                      cellBuilder: (i) => Text(i.dueDate, style: AppTypography.body),
                    ),
                    AppTableColumn(
                      label: 'TRẠNG THÁI',
                      width: 150,
                      cellBuilder: (i) => StatusBadge.fromInvoiceStatus(i.status),
                    ),
                    AppTableColumn(
                      label: 'THAO TÁC',
                      width: 135,
                      alignment: Alignment.centerRight,
                      cellBuilder: (i) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (i.status != 'PAID')
                            IconButton(
                              tooltip: 'Xác nhận đã thu tiền',
                              icon: const Icon(
                                Icons.check_circle_outline_rounded,
                                size: 19,
                                color: AppColors.success,
                              ),
                              onPressed: () => _markPaid(i),
                            ),
                          IconButton(
                            tooltip: 'Chỉnh sửa',
                            icon: const Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            onPressed: () => _openInvoiceForm(i),
                          ),
                          IconButton(
                            tooltip: 'Xóa',
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: AppColors.error,
                            ),
                            onPressed: () => _confirmDelete(i),
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

