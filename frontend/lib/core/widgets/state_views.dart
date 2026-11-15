import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';
import 'app_table.dart';

class LoadingState extends StatelessWidget {
  final String message;
  const LoadingState({super.key, this.message = 'Đang tải dữ liệu...'});

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(message, style: AppTypography.captionMedium),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 24, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Text(title, style: AppTypography.cardTitle),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTypography.caption,
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            AppButton(
              label: actionLabel!,
              icon: Icons.add_rounded,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.errorLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.error_outline_rounded, color: AppColors.error),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Không thể tải dữ liệu', style: AppTypography.cardTitle),
                const SizedBox(height: 2),
                Text(message, style: AppTypography.caption),
              ],
            ),
          ),
          const SizedBox(width: 12),
          AppButton(
            label: 'Thử lại',
            icon: Icons.refresh_rounded,
            variant: AppButtonVariant.outlined,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

void showSuccessToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      width: 420,
      backgroundColor: AppColors.textPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      content: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.surface),
            ),
          ),
        ],
      ),
    ),
  );
}

void showErrorToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      width: 440,
      backgroundColor: AppColors.errorText,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      content: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.surface, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.surface),
            ),
          ),
        ],
      ),
    ),
  );
}

