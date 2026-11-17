import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/auth/role_access.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/soa_services.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/app_table.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../models/system_health_model.dart';
import '../../../providers/auth_provider.dart';
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
  bool _loadingUsers = false;
  List<Map<String, dynamic>> _users = const [];
  String? _usersError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.isAuthenticated && auth.isManager) {
        _loadUsers();
      }
    });
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loadingUsers = true;
      _usersError = null;
    });
    try {
      final list = await context.read<AuthProvider>().fetchUsers();
      if (!mounted) return;
      setState(() {
        _users = list;
        _loadingUsers = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _usersError = e.toString();
        _loadingUsers = false;
      });
    }
  }

  void _openChangePasswordDialog() {
    final formKey = GlobalKey<FormState>();
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đổi mật khẩu tài khoản', style: AppTypography.sectionTitle),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  label: 'Mật khẩu hiện tại',
                  controller: oldCtrl,
                  requiredField: true,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Mật khẩu mới',
                  controller: newCtrl,
                  requiredField: true,
                  validator: (v) {
                    if (v == null || v.trim().length < 6) {
                      return 'Mật khẩu mới cần tối thiểu 6 ký tự';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Xác nhận mật khẩu mới',
                  controller: confirmCtrl,
                  requiredField: true,
                  validator: (v) {
                    if (v != newCtrl.text) return 'Mật khẩu xác nhận không khớp';
                    return null;
                  },
                ),
              ],
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
            label: 'Đổi mật khẩu',
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              final err = await context
                  .read<AuthProvider>()
                  .changePassword(oldCtrl.text, newCtrl.text);
              if (!ctx.mounted || !mounted) return;
              if (err != null) {
                showErrorToast(context, err);
                return;
              }
              Navigator.pop(ctx);
              showSuccessToast(context, 'Đổi mật khẩu thành công.');
            },
          ),
        ],
      ),
    );
  }

  void _openProfileDialog(AuthProvider auth) {
    final user = auth.user ?? const <String, dynamic>{};
    final formKey = GlobalKey<FormState>();
    final firstCtrl = TextEditingController(text: '${user['first_name'] ?? ''}');
    final lastCtrl = TextEditingController(text: '${user['last_name'] ?? ''}');
    final emailCtrl = TextEditingController(text: '${user['email'] ?? ''}');
    final phoneCtrl = TextEditingController(text: '${user['phone_number'] ?? ''}');
    final addressCtrl = TextEditingController(text: '${user['address'] ?? ''}');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cập nhật hồ sơ cá nhân', style: AppTypography.sectionTitle),
        content: SizedBox(
          width: 480,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(child: AppTextField(label: 'Họ', controller: lastCtrl)),
                      const SizedBox(width: 12),
                      Expanded(child: AppTextField(label: 'Tên', controller: firstCtrl)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AppTextField(label: 'Email', controller: emailCtrl),
                  const SizedBox(height: 12),
                  AppTextField(label: 'Số điện thoại', controller: phoneCtrl),
                  const SizedBox(height: 12),
                  AppTextField(label: 'Địa chỉ', controller: addressCtrl),
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
            label: 'Lưu hồ sơ',
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              final err = await auth.updateProfile({
                'first_name': firstCtrl.text.trim(),
                'last_name': lastCtrl.text.trim(),
                'email': emailCtrl.text.trim(),
                'phone_number': phoneCtrl.text.trim(),
                'address': addressCtrl.text.trim(),
              });
              if (!ctx.mounted || !mounted) return;
              if (err != null) {
                showErrorToast(context, err);
                return;
              }
              Navigator.pop(ctx);
              showSuccessToast(context, 'Đã cập nhật thông tin tài khoản.');
            },
          ),
        ],
      ),
    );
  }

  void _openUserFormDialog(AuthProvider auth, [Map<String, dynamic>? existing]) {
    final isAdmin = auth.role == 'ADMIN';
    final formKey = GlobalKey<FormState>();
    final usernameCtrl = TextEditingController(text: '${existing?['username'] ?? ''}');
    final passwordCtrl = TextEditingController();
    final firstCtrl = TextEditingController(text: '${existing?['first_name'] ?? ''}');
    final lastCtrl = TextEditingController(text: '${existing?['last_name'] ?? ''}');
    final emailCtrl = TextEditingController(text: '${existing?['email'] ?? ''}');
    final phoneCtrl = TextEditingController(text: '${existing?['phone_number'] ?? ''}');
    String role = '${existing?['role'] ?? 'TENANT'}';
    bool isActive = existing?['is_active'] != false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text(
            existing == null ? 'Tạo tài khoản mới' : 'Cập nhật tài khoản',
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
                    if (existing == null) ...[
                      AppTextField(
                        label: 'Tên đăng nhập',
                        controller: usernameCtrl,
                        requiredField: true,
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        label: 'Mật khẩu',
                        controller: passwordCtrl,
                        requiredField: true,
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        Expanded(child: AppTextField(label: 'Họ', controller: lastCtrl)),
                        const SizedBox(width: 12),
                        Expanded(child: AppTextField(label: 'Tên', controller: firstCtrl)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: AppTextField(label: 'Email', controller: emailCtrl)),
                        const SizedBox(width: 12),
                        Expanded(child: AppTextField(label: 'Số điện thoại', controller: phoneCtrl)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (isAdmin) ...[
                      Row(
                        children: [
                          Expanded(
                            child: AppSelect<String>(
                              label: 'Vai trò (Role)',
                              width: null,
                              value: role,
                              options: const [
                                AppSelectOption(value: 'TENANT', label: 'TENANT — Khách thuê'),
                                AppSelectOption(value: 'LANDLORD', label: 'LANDLORD — Chủ trọ'),
                                AppSelectOption(value: 'STAFF', label: 'STAFF — Nhân viên'),
                                AppSelectOption(value: 'ADMIN', label: 'ADMIN — Quản trị viên'),
                              ],
                              onChanged: (v) => setModalState(() => role = v ?? 'TENANT'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Kích hoạt', style: AppTypography.bodyBold),
                              value: isActive,
                              onChanged: (v) => setModalState(() => isActive = v ?? true),
                            ),
                          ),
                        ],
                      ),
                    ] else
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Chủ trọ chỉ được tạo/cập nhật tài khoản Khách thuê (TENANT).',
                          style: AppTypography.caption,
                        ),
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
              label: existing == null ? 'Tạo tài khoản' : 'Lưu thay đổi',
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                final payload = <String, dynamic>{
                  'first_name': firstCtrl.text.trim(),
                  'last_name': lastCtrl.text.trim(),
                  'email': emailCtrl.text.trim(),
                  'phone_number': phoneCtrl.text.trim(),
                  if (existing == null) 'username': usernameCtrl.text.trim(),
                  if (existing == null) 'password': passwordCtrl.text,
                  if (isAdmin) 'role': role,
                  if (isAdmin) 'is_active': isActive,
                };
                final err = existing == null
                    ? await auth.createUser(payload)
                    : await auth.updateUser(existing['id'] as int, payload);
                if (!ctx.mounted || !mounted) return;
                if (err != null) {
                  showErrorToast(context, err);
                  return;
                }
                Navigator.pop(ctx);
                showSuccessToast(
                  context,
                  existing == null ? 'Đã tạo tài khoản thành công.' : 'Đã cập nhật tài khoản.',
                );
                _loadUsers();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteUser(AuthProvider auth, Map<String, dynamic> user) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Xóa tài khoản',
      message: 'Xóa tài khoản "${user['username']}"?',
    );
    if (!confirmed || !mounted) return;
    final err = await auth.deleteUser(user['id'] as int);
    if (!mounted) return;
    if (err != null) {
      showErrorToast(context, err);
      return;
    }
    showSuccessToast(context, 'Đã xóa tài khoản "${user['username']}".');
    _loadUsers();
  }

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
    final auth = context.watch<AuthProvider>();
    final user = auth.user ?? const <String, dynamic>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Cài đặt hệ thống & Kiến trúc SOA',
          subtitle: 'Quản lý tài khoản Identity, phân quyền và trạng thái kết nối 5 Microservices.',
          actions: [
            AppButton(
              label: 'Đổi mật khẩu',
              icon: Icons.lock_reset_rounded,
              variant: AppButtonVariant.outlined,
              onPressed: _openChangePasswordDialog,
            ),
            AppButton(
              label: 'Kiểm tra kết nối SOA',
              icon: Icons.sync_rounded,
              isLoading: _syncing,
              variant: AppButtonVariant.outlined,
              onPressed: () async {
                setState(() => _syncing = true);
                await repo.refreshSystemHealth();
                if (context.mounted) {
                  setState(() => _syncing = false);
                  final h = repo.systemHealth;
                  if (h != null && h.gatewayStatus == ServiceStatus.up) {
                    showSuccessToast(
                      context,
                      'API Gateway: ${h.upCount}/${h.services.length} service đang hoạt động',
                    );
                  } else {
                    showErrorToast(context, 'Không kết nối được API Gateway (:8000)');
                  }
                }
              },
            ),
          ],
        ),

        // Current User Profile Card (Service 1: Identity)
        AppSurfaceCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primaryLight,
                child: Text(
                  auth.displayName.isNotEmpty ? auth.displayName[0].toUpperCase() : 'U',
                  style: AppTypography.titleLg.copyWith(color: AppColors.primary),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AppSpacing.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(auth.displayName, style: AppTypography.sectionTitle),
                        RoleBadge(role: auth.roleDisplay),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Tài khoản: ${user['username'] ?? '—'} · Email: ${user['email'] ?? '—'} · SĐT: ${user['phone_number'] ?? '—'}',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  AppButton(
                    label: 'Sửa hồ sơ',
                    compact: true,
                    variant: AppButtonVariant.outlined,
                    onPressed: () => _openProfileDialog(auth),
                  ),
                  AppButton(
                    label: 'Đăng xuất',
                    compact: true,
                    variant: AppButtonVariant.danger,
                    onPressed: () => auth.logout(),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xxl),

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
                      'Mỗi service có Port & Database riêng; Frontend chỉ gọi qua API Gateway :8000',
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
                    label: 'ENDPOINT (QUA GATEWAY)',
                    flex: 2,
                    cellBuilder: (s) => Text(s.gatewayEndpoint, style: AppTypography.code),
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
                      final status = repo.systemHealth?.service(s.id)?.status;
                      return switch (status) {
                        ServiceStatus.up => const StatusBadge(label: 'UP', type: BadgeType.success),
                        ServiceStatus.down => const StatusBadge(label: 'DOWN', type: BadgeType.error),
                        ServiceStatus.unknown => const StatusBadge(label: 'UNKNOWN', type: BadgeType.info),
                        null => const StatusBadge(label: 'Chưa kiểm tra', type: BadgeType.info),
                      };
                    },
                  ),
                  AppTableColumn(
                    label: 'ĐIỀU HƯỚNG',
                    width: 120,
                    alignment: Alignment.centerRight,
                    // Chỉ cho mở trang mà vai trò hiện tại được phép (RoleAccess).
                    cellBuilder: (s) => RoleAccess.canAccess(auth.role, s.route)
                        ? AppButton(
                            label: 'Mở trang',
                            compact: true,
                            variant: AppButtonVariant.outlined,
                            onPressed: () => context.go(s.route),
                          )
                        : const Text('—', style: AppTypography.caption),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Đơn giá dịch vụ: cấu hình của chủ trọ -> chỉ hiện với vai trò quản lý.
        if (auth.isManager) ...[
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

        if (auth.isManager) ...[
          const SizedBox(height: AppSpacing.xxl),
          AppSurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.sm,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quản lý tài khoản & Phân quyền (Identity :8001)',
                            style: AppTypography.sectionTitle,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'ADMIN quản lý toàn bộ vai trò; LANDLORD tạo và sửa tài khoản TENANT.',
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppButton(
                            label: 'Tải lại',
                            compact: true,
                            variant: AppButtonVariant.outlined,
                            isLoading: _loadingUsers,
                            onPressed: _loadUsers,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          AppButton(
                            label: '+ Tạo tài khoản',
                            compact: true,
                            onPressed: () => _openUserFormDialog(auth),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (_usersError != null)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Không tải được danh sách tài khoản: $_usersError',
                      style: AppTypography.caption.copyWith(color: AppColors.error),
                    ),
                  )
                else if (_users.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Chưa có tài khoản hoặc chưa kết nối Identity Service.',
                      style: AppTypography.caption,
                    ),
                  )
                else
                  AppTable<Map<String, dynamic>>(
                    items: _users,
                    columns: [
                      AppTableColumn(
                        label: 'USERNAME',
                        width: 140,
                        cellBuilder: (u) => CodeBadge('${u['username'] ?? ''}'),
                      ),
                      AppTableColumn(
                        label: 'HỌ TÊN & EMAIL',
                        flex: 2,
                        cellBuilder: (u) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${u['full_name'] ?? u['username'] ?? ''}',
                              style: AppTypography.bodyBold,
                            ),
                            Text('${u['email'] ?? '—'}', style: AppTypography.caption),
                          ],
                        ),
                      ),
                      AppTableColumn(
                        label: 'VAI TRÒ',
                        width: 165,
                        cellBuilder: (u) => RoleBadge(role: '${u['role_display'] ?? u['role'] ?? ''}'),
                      ),
                      AppTableColumn(
                        label: 'TRẠNG THÁI',
                        width: 140,
                        cellBuilder: (u) => StatusBadge(
                          label: u['is_active'] == false ? 'Bị khóa' : 'Hoạt động',
                          type: u['is_active'] == false ? BadgeType.error : BadgeType.success,
                        ),
                      ),
                      AppTableColumn(
                        label: 'THAO TÁC',
                        width: 110,
                        alignment: Alignment.centerRight,
                        cellBuilder: (u) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Chỉnh sửa',
                              icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                              onPressed: () => _openUserFormDialog(auth, u),
                            ),
                            if (auth.role == 'ADMIN')
                              IconButton(
                                tooltip: 'Xóa',
                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                                onPressed: () => _confirmDeleteUser(auth, u),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
