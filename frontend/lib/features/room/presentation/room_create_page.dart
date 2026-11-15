import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/app_table.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../shared/services/app_data_repository.dart';

class RoomCreatePage extends StatefulWidget {
  const RoomCreatePage({super.key});

  @override
  State<RoomCreatePage> createState() => _RoomCreatePageState();
}

class _RoomCreatePageState extends State<RoomCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _floorCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _maxOccupantsCtrl = TextEditingController(text: '2');
  final _descriptionCtrl = TextEditingController();

  int? _selectedPropertyId;
  String _status = 'AVAILABLE';

  @override
  void initState() {
    super.initState();
    final properties = context.read<AppDataRepository>().properties;
    if (properties.isNotEmpty) {
      _selectedPropertyId = properties.first.id;
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _floorCtrl.dispose();
    _priceCtrl.dispose();
    _areaCtrl.dispose();
    _maxOccupantsCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_selectedPropertyId == null) {
      showErrorToast(context, 'Vui lòng chọn nhà trọ / tòa nhà.');
      return;
    }

    showSuccessToast(
      context,
      'Dữ liệu phòng "${_nameCtrl.text.trim()}" hợp lệ (UI Demo — chưa kết nối Django backend).',
    );
    context.go('/rooms');
  }

  @override
  Widget build(BuildContext context) {
    final properties = context.watch<AppDataRepository>().properties;
    final activePropertyId = _selectedPropertyId ??
        (properties.isNotEmpty ? properties.first.id : null);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Thêm phòng mới',
            subtitle:
                'Khởi tạo thông tin phòng trọ theo giao diện Stitch (chỉ kiểm tra hợp lệ cục bộ).',
            actions: [
              AppButton(
                label: 'Hủy',
                variant: AppButtonVariant.outlined,
                onPressed: () => context.go('/rooms'),
              ),
              AppButton(
                label: 'Lưu phòng',
                icon: Icons.save_outlined,
                onPressed: _handleSubmit,
              ),
            ],
          ),

          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;

              final mainSections = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Basic Information
                  _SectionCard(
                    title: 'Thông tin cơ bản',
                    subtitle: 'Định danh phòng và vị trí thuộc tòa nhà',
                    child: Column(
                      children: [
                        _ResponsivePair(
                          isWide: constraints.maxWidth >= 640,
                          first: AppTextField(
                            label: 'Mã phòng',
                            hint: 'VD: P-A105',
                            controller: _codeCtrl,
                            requiredField: true,
                          ),
                          second: AppTextField(
                            label: 'Tên phòng',
                            hint: 'VD: Phòng A105 - Studio Ban công',
                            controller: _nameCtrl,
                            requiredField: true,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _ResponsivePair(
                          isWide: constraints.maxWidth >= 640,
                          first: activePropertyId == null
                              ? const Text(
                                  'Chưa có tòa nhà nào trong dữ liệu mẫu.',
                                  style: AppTypography.caption,
                                )
                              : AppSelect<int>(
                                  label: 'Nhà trọ / Tòa nhà *',
                                  width: null,
                                  value: activePropertyId,
                                  options: [
                                    for (final p in properties)
                                      AppSelectOption(
                                        value: p.id,
                                        label: '${p.code} — ${p.name}',
                                      ),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _selectedPropertyId = v),
                                ),
                          second: AppTextField(
                            label: 'Tầng',
                            hint: 'VD: 1',
                            controller: _floorCtrl,
                            requiredField: true,
                            isNumber: true,
                            validator: (v) {
                              final raw = v?.trim() ?? '';
                              if (raw.isEmpty) return 'Vui lòng nhập Tầng';
                              final n = int.tryParse(raw);
                              if (n == null || n < 0) {
                                return 'Tầng phải là số nguyên không âm';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Room Specifications
                  _SectionCard(
                    title: 'Thông số phòng',
                    subtitle: 'Đơn giá thuê niêm yết, diện tích và sức chứa',
                    child: _ResponsiveTriple(
                      isWide: constraints.maxWidth >= 640,
                      first: AppTextField(
                        label: 'Giá thuê (VNĐ/tháng)',
                        hint: 'VD: 3500000',
                        controller: _priceCtrl,
                        requiredField: true,
                        isNumber: true,
                        validator: (v) {
                          final raw = v?.trim() ?? '';
                          if (raw.isEmpty) return 'Vui lòng nhập Giá thuê';
                          final n = double.tryParse(raw);
                          if (n == null || n <= 0) {
                            return 'Giá thuê phải lớn hơn 0';
                          }
                          return null;
                        },
                      ),
                      second: AppTextField(
                        label: 'Diện tích (m²)',
                        hint: 'VD: 24',
                        controller: _areaCtrl,
                        requiredField: true,
                        isNumber: true,
                        validator: (v) {
                          final raw = v?.trim() ?? '';
                          if (raw.isEmpty) return 'Vui lòng nhập Diện tích';
                          final n = double.tryParse(raw);
                          if (n == null || n <= 0) {
                            return 'Diện tích phải lớn hơn 0';
                          }
                          return null;
                        },
                      ),
                      third: AppTextField(
                        label: 'Số người tối đa',
                        hint: 'VD: 2',
                        controller: _maxOccupantsCtrl,
                        requiredField: true,
                        isNumber: true,
                        validator: (v) {
                          final raw = v?.trim() ?? '';
                          if (raw.isEmpty) {
                            return 'Vui lòng nhập Số người tối đa';
                          }
                          final n = int.tryParse(raw);
                          if (n == null || n <= 0) {
                            return 'Số người tối đa phải lớn hơn 0';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Additional Information
                  _SectionCard(
                    title: 'Thông tin bổ sung',
                    subtitle: 'Tiện ích, nội thất và ghi chú hiển thị',
                    child: AppTextField(
                      label: 'Mô tả',
                      hint:
                          'VD: Có ban công, máy lạnh inverter, tủ lạnh, khóa vân tay...',
                      controller: _descriptionCtrl,
                      maxLines: 4,
                    ),
                  ),
                ],
              );

              final statusCard = _SectionCard(
                title: 'Trạng thái phòng',
                subtitle: 'Thiết lập trạng thái ban đầu của phòng',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSelect<String>(
                      label: 'Trạng thái',
                      width: null,
                      value: _status,
                      options: const [
                        AppSelectOption(
                          value: 'AVAILABLE',
                          label: 'Còn trống',
                        ),
                        AppSelectOption(
                          value: 'OCCUPIED',
                          label: 'Đang thuê',
                        ),
                        AppSelectOption(
                          value: 'RESERVED',
                          label: 'Đã đặt trước',
                        ),
                        AppSelectOption(
                          value: 'MAINTENANCE',
                          label: 'Đang bảo trì',
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => _status = v ?? 'AVAILABLE'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.badgeRadius),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Hiển thị nhãn:',
                            style: AppTypography.labelSm,
                          ),
                          StatusBadge.fromRoomStatus(_status),
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
                    Expanded(flex: 8, child: mainSections),
                    const SizedBox(width: AppSpacing.xl),
                    Expanded(flex: 4, child: statusCard),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  mainSections,
                  const SizedBox(height: AppSpacing.lg),
                  statusCard,
                ],
              );
            },
          ),

          const SizedBox(height: AppSpacing.xl),

          // Bottom Action Bar
          AppSurfaceCard(
            padding: AppSpacing.cardPadding,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: [
                AppButton(
                  label: 'Hủy',
                  variant: AppButtonVariant.outlined,
                  onPressed: () => context.go('/rooms'),
                ),
                AppButton(
                  label: 'Lưu phòng',
                  icon: Icons.save_outlined,
                  onPressed: _handleSubmit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.sectionTitle),
          const SizedBox(height: AppSpacing.xxs),
          Text(subtitle, style: AppTypography.caption),
          const SizedBox(height: AppSpacing.lg),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

class _ResponsivePair extends StatelessWidget {
  final bool isWide;
  final Widget first;
  final Widget second;

  const _ResponsivePair({
    required this.isWide,
    required this.first,
    required this.second,
  });

  @override
  Widget build(BuildContext context) {
    if (!isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          first,
          const SizedBox(height: AppSpacing.lg),
          second,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: AppSpacing.lg),
        Expanded(child: second),
      ],
    );
  }
}

class _ResponsiveTriple extends StatelessWidget {
  final bool isWide;
  final Widget first;
  final Widget second;
  final Widget third;

  const _ResponsiveTriple({
    required this.isWide,
    required this.first,
    required this.second,
    required this.third,
  });

  @override
  Widget build(BuildContext context) {
    if (!isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          first,
          const SizedBox(height: AppSpacing.lg),
          second,
          const SizedBox(height: AppSpacing.lg),
          third,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: AppSpacing.lg),
        Expanded(child: second),
        const SizedBox(width: AppSpacing.lg),
        Expanded(child: third),
      ],
    );
  }
}
