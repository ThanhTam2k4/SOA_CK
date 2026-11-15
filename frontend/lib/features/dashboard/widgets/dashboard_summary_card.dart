import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../models/dashboard_summary_model.dart';
import '../../../widgets/stat_card.dart';

/// Số liệu tổng quan lấy từ GET /api/dashboard/summary/ (API Gateway tổng hợp).
/// Giá trị null (service sở hữu đang DOWN) hiển thị "—", không bịa số.
class DashboardSummaryCard extends StatelessWidget {
  final DashboardSummary? summary;
  final bool isLoading;
  final String? error;

  const DashboardSummaryCard({
    super.key,
    required this.summary,
    required this.isLoading,
    this.error,
  });

  static String _n(int? v) => v == null ? '—' : '$v';

  @override
  Widget build(BuildContext context) {
    if (isLoading && summary == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (summary == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: Color(0xFFDC2626), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                error ?? 'Không lấy được số liệu tổng quan từ API Gateway.',
                style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12.5),
              ),
            ),
          ],
        ),
      );
    }

    final s = summary!;
    final items = <Widget>[
      StatCard(
        title: 'Nhà trọ',
        value: _n(s.totalProperties),
        icon: Icons.apartment_rounded,
        color: const Color(0xFF2563EB),
      ),
      StatCard(
        title: 'Tổng số phòng',
        value: _n(s.totalRooms),
        icon: Icons.meeting_room_rounded,
        color: const Color(0xFF0EA5E9),
        subtitle: s.occupancyRatePercent != null ? 'Lấp đầy ${s.occupancyRatePercent}%' : null,
      ),
      StatCard(
        title: 'Đang thuê',
        value: _n(s.occupiedRooms),
        icon: Icons.key_rounded,
        color: const Color(0xFF16A34A),
      ),
      StatCard(
        title: 'Còn trống',
        value: _n(s.availableRooms),
        icon: Icons.door_front_door_outlined,
        color: const Color(0xFF0D9488),
      ),
      StatCard(
        title: 'Bảo trì',
        value: _n(s.maintenanceRooms),
        icon: Icons.build_rounded,
        color: const Color(0xFFD97706),
        subtitle: s.openMaintenanceRequests != null ? '${s.openMaintenanceRequests} yêu cầu mở' : null,
      ),
      StatCard(
        title: 'Người thuê',
        value: _n(s.totalTenants),
        icon: Icons.people_alt_rounded,
        color: const Color(0xFF7C3AED),
      ),
      StatCard(
        title: 'HĐ hiệu lực',
        value: _n(s.activeContracts),
        icon: Icons.assignment_turned_in_rounded,
        color: const Color(0xFF9333EA),
        subtitle: s.expiringSoonContracts != null && s.expiringSoonContracts! > 0
            ? '${s.expiringSoonContracts} sắp hết hạn'
            : null,
      ),
      StatCard(
        title: 'Chưa thanh toán',
        value: _n(s.unpaidInvoices),
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFFEA580C),
        subtitle: s.unpaidAmount != null ? Formatters.formatCurrency(s.unpaidAmount) : null,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!s.complete)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Text(
              'Thiếu số liệu do service không phản hồi: ${s.failedSources.join(', ')}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
            ),
          ),
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth >= 720 ? 4 : 2;
          return GridView.count(
            crossAxisCount: columns,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: columns == 4 ? 1.9 : 1.6,
            children: items,
          );
        }),
      ],
    );
  }
}
