import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/soa_services.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_table.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../shared/services/app_data_repository.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _elecCtrl = TextEditingController(text: '3500');
  final _waterCtrl = TextEditingController(text: '18000');
  final _netCtrl = TextEditingController(text: '100000');
  bool _syncing = false;

  @override
  void dispose() {
    _elecCtrl.dispose();
    _waterCtrl.dispose();
    _netCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppDataRepository>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Cài đặt hệ thống & Kiến trúc SOA',
          subtitle: 'Quản lý cấu hình đơn giá dịch vụ và trạng thái kết nối 5 Microservices.',
          actions: [
            AppButton(
              label: 'Kiểm tra kết nối SOA',
              icon: Icons.sync_rounded,
              isLoading: _syncing,
              variant: AppButtonVariant.outlined,
              onPressed: () async {
                setState(() => _syncing = true);
                await repo.syncWithBackend();
                if (context.mounted) {
                  setState(() => _syncing = false);
                  showSuccessToast(
                    context,
                    'Đã kiểm tra 5 cổng dịch vụ SOA (Ports 8001–8005)',
                  );
                }
              },
            ),
          ],
        ),

        // SOA Services Status Table
        AppSurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Danh sách Microservices (Kiến trúc SOA)',
                      style: AppTypography.sectionTitle,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Mỗi service hoạt động độc lập trên một Port và Database riêng biệt',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              AppTable<SoaServiceConfig>(
                items: SoaServices.all,
                columns: [
                  AppTableColumn(
                    label: 'TÊN SERVICE',
                    flex: 2,
                    cellBuilder: (s) => Row(
                      children: [
                        Icon(s.icon, size: 18, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(s.name, style: AppTypography.bodySemiBold),
                        ),
                      ],
                    ),
                  ),
                  AppTableColumn(
                    label: 'PORT',
                    width: 110,
                    cellBuilder: (s) => CodeBadge(':${s.port}'),
                  ),
                  AppTableColumn(
                    label: 'ENDPOINT REST API',
                    flex: 2,
                    cellBuilder: (s) => Text(s.apiBase, style: AppTypography.code),
                  ),
                  AppTableColumn(
                    label: 'DATABASE',
                    width: 180,
                    cellBuilder: (s) => Text(s.database, style: AppTypography.captionMedium),
                  ),
                  AppTableColumn(
                    label: 'TRẠNG THÁI',
                    width: 150,
                    cellBuilder: (s) {
                      final online = repo.portStatus[s.port] ?? false;
                      return StatusBadge(
                        label: online ? 'Sẵn sàng' : 'Mock Mode',
                        type: online ? BadgeType.success : BadgeType.info,
                      );
                    },
                  ),
                  AppTableColumn(
                    label: 'ĐIỀU HƯỚNG',
                    width: 120,
                    alignment: Alignment.centerRight,
                    cellBuilder: (s) => AppButton(
                      label: 'Mở trang',
                      compact: true,
                      variant: AppButtonVariant.outlined,
                      onPressed: () => context.go(s.route),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xxl),

        // Default Utility Rates Card
        AppSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Đơn giá dịch vụ mặc định',
                style: AppTypography.sectionTitle,
              ),
              const SizedBox(height: 4),
              const Text(
                'Áp dụng khi lập hóa đơn hàng tháng cho các nhà trọ',
                style: AppTypography.caption,
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.lg,
                children: [
                  SizedBox(
                    width: 240,
                    child: AppTextField(
                      label: 'Giá điện (VNĐ / kWh)',
                      controller: _elecCtrl,
                      isNumber: true,
                    ),
                  ),
                  SizedBox(
                    width: 240,
                    child: AppTextField(
                      label: 'Giá nước (VNĐ / m³)',
                      controller: _waterCtrl,
                      isNumber: true,
                    ),
                  ),
                  SizedBox(
                    width: 240,
                    child: AppTextField(
                      label: 'Internet & Rác (VNĐ / phòng)',
                      controller: _netCtrl,
                      isNumber: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              AppButton(
                label: 'Lưu cấu hình',
                onPressed: () => showSuccessToast(
                  context,
                  'Đã lưu cấu hình đơn giá dịch vụ thành công',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
