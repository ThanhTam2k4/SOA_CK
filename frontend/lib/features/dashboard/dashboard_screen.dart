import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../models/dashboard_summary_model.dart';
import '../../models/system_health_model.dart';
import '../../providers/auth_provider.dart';
import '../../shared/services/app_data_repository.dart';
import 'widgets/dashboard_summary_card.dart';
import 'widgets/soa_architecture_card.dart';

/// Dashboard tổng quan. Chỉ gọi API Gateway :8000 với đúng 2 request:
///   GET /api/dashboard/summary/  (Gateway tổng hợp số liệu từ các service)
///   GET /api/system/health/      (Gateway kiểm tra /health/ của 5 service)
class DashboardScreen extends StatefulWidget {
  final AppDataRepository repository;

  const DashboardScreen({super.key, this.repository = const AppDataRepository()});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  SystemHealth? _health;
  DashboardSummary? _summary;
  String? _summaryError;
  bool _loadingHealth = false;
  bool _loadingSummary = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() => Future.wait([_loadHealth(), _loadSummary()]);

  Future<void> _loadHealth() async {
    setState(() => _loadingHealth = true);
    final health = await widget.repository.fetchSystemHealth();
    if (!mounted) return;
    setState(() {
      _health = health;
      _loadingHealth = false;
    });
  }

  Future<void> _loadSummary() async {
    setState(() {
      _loadingSummary = true;
      _summaryError = null;
    });
    try {
      final summary = await widget.repository.fetchDashboardSummary();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _loadingSummary = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _summary = null;
        _summaryError = e.message;
        _loadingSummary = false;
      });
      if (e.statusCode == 401) {
        Provider.of<AuthProvider>(context, listen: false).logout();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Tổng Quan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới',
            onPressed: _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(18),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Xin chào, ${user?.displayName ?? 'bạn'}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Số liệu được API Gateway tổng hợp trực tiếp từ các service.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
                  DashboardSummaryCard(
                    summary: _summary,
                    isLoading: _loadingSummary,
                    error: _summaryError,
                  ),
                  const SizedBox(height: 18),
                  SoaArchitectureCard(
                    health: _health,
                    isLoading: _loadingHealth,
                    onRefresh: _loadHealth,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
