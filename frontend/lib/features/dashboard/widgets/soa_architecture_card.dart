import 'package:flutter/material.dart';

import '../../../models/system_health_model.dart';

/// Thẻ "Kiến trúc SOA": hiển thị trạng thái THỰC TẾ do API Gateway kiểm tra.
/// UP -> xanh, DOWN -> đỏ, UNKNOWN -> xám.
class SoaArchitectureCard extends StatelessWidget {
  final SystemHealth? health;
  final bool isLoading;
  final VoidCallback? onRefresh;

  const SoaArchitectureCard({
    super.key,
    required this.health,
    required this.isLoading,
    this.onRefresh,
  });

  /// Danh sách service hiển thị cố định về TÊN/PORT (thông tin kiến trúc);
  /// TRẠNG THÁI luôn lấy từ Gateway, không hard-code.
  static const List<(String key, String name, int port, IconData icon)> _layout = [
    ('identity', 'Identity Service', 8001, Icons.verified_user_rounded),
    ('property', 'Property & Maintenance', 8002, Icons.apartment_rounded),
    ('tenant', 'Tenant Service', 8003, Icons.people_alt_rounded),
    ('contract', 'Contract Service', 8004, Icons.assignment_rounded),
    ('billing', 'Billing & Notification', 8005, Icons.receipt_long_rounded),
  ];

  static Color statusColor(ServiceStatus status) {
    switch (status) {
      case ServiceStatus.up:
        return const Color(0xFF16A34A);
      case ServiceStatus.down:
        return const Color(0xFFDC2626);
      case ServiceStatus.unknown:
        return const Color(0xFF94A3B8);
    }
  }

  static String statusLabel(ServiceStatus status) {
    switch (status) {
      case ServiceStatus.up:
        return 'UP';
      case ServiceStatus.down:
        return 'DOWN';
      case ServiceStatus.unknown:
        return 'UNKNOWN';
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = health;
    final gatewayStatus = h?.gatewayStatus ?? ServiceStatus.unknown;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hub_rounded, size: 20, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Kiến trúc SOA',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
              ),
              if (isLoading)
                const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              else ...[
                _OverallBadge(health: h),
                if (onRefresh != null)
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF64748B)),
                    tooltip: 'Kiểm tra lại',
                    onPressed: onRefresh,
                  ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Trạng thái do API Gateway kiểm tra trực tiếp endpoint /health/ của từng service.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          _ServiceTile(
            name: 'API Gateway',
            port: h?.gatewayPort ?? 8000,
            icon: Icons.router_rounded,
            status: gatewayStatus,
            detail: h?.error != null ? 'Không kết nối được Gateway' : null,
          ),
          ..._layout.map((item) {
            final s = h?.service(item.$1);
            return _ServiceTile(
              name: item.$2,
              port: s?.port ?? item.$3,
              icon: item.$4,
              // Gateway không trả về service này (hoặc Gateway down) -> UNKNOWN.
              status: s?.status ?? ServiceStatus.unknown,
              detail: s == null
                  ? null
                  : s.status == ServiceStatus.up
                      ? 'DB ${s.databaseStatus ?? '-'}'
                          '${s.responseTimeMs != null ? ' • ${s.responseTimeMs!.toStringAsFixed(0)} ms' : ''}'
                      : s.error,
            );
          }),
          if (h?.checkedAt != null) ...[
            const SizedBox(height: 6),
            Text(
              'Kiểm tra lúc ${TimeOfDay.fromDateTime(h!.checkedAt!.toLocal()).format(context)}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ],
      ),
    );
  }
}

class _OverallBadge extends StatelessWidget {
  final SystemHealth? health;

  const _OverallBadge({required this.health});

  @override
  Widget build(BuildContext context) {
    final h = health;
    late final String text;
    late final Color color;
    if (h == null) {
      text = 'CHƯA KIỂM TRA';
      color = const Color(0xFF94A3B8);
    } else if (h.error != null) {
      text = 'GATEWAY DOWN';
      color = const Color(0xFFDC2626);
    } else if (h.overallStatus == 'UP') {
      text = '${h.upCount}/${h.services.length} UP';
      color = const Color(0xFF16A34A);
    } else if (h.overallStatus == 'DEGRADED') {
      text = '${h.upCount}/${h.services.length} UP';
      color = const Color(0xFFD97706);
    } else {
      text = 'DOWN';
      color = const Color(0xFFDC2626);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final String name;
  final int port;
  final IconData icon;
  final ServiceStatus status;
  final String? detail;

  const _ServiceTile({
    required this.name,
    required this.port,
    required this.icon,
    required this.status,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final color = SoaArchitectureCard.statusColor(status);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Icon(icon, size: 18, color: const Color(0xFF475569)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                Text(
                  'Port $port${detail != null && detail!.isNotEmpty ? ' • $detail' : ''}',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            SoaArchitectureCard.statusLabel(status),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}
