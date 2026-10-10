import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../media/media_storage.dart';
import 'state_views.dart';

/// Upload progress / failure / retry feedback shared by all upload flows.
class UploadProgressCard extends StatelessWidget {
  const UploadProgressCard({
    super.key,
    required this.label,
    required this.progress,
    this.error,
    this.onRetry,
    this.onCancel,
  });

  final String label;
  final UploadProgress? progress;
  final String? error;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InlineError('$label failed. $error'),
          if (onRetry != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry upload'),
              ),
            ),
        ],
      );
    }
    final p = progress;
    if (p == null) return const SizedBox.shrink();
    final done = p.phase == UploadPhase.success;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: done ? AppColors.approvedBg : AppColors.recessed,
        borderRadius: AppRadii.control,
        border: Border.all(color: AppColors.linen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                done ? Icons.check_circle : Icons.cloud_upload_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  done
                      ? '$label uploaded'
                      : '$label… ${(p.fraction * 100).round()}%',
                  style: context.text.labelMedium,
                ),
              ),
              if (!done && onCancel != null)
                TextButton(onPressed: onCancel, child: const Text('Cancel')),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: AppRadii.pill,
            child: LinearProgressIndicator(
              value: p.fraction,
              minHeight: 6,
              color: AppColors.goldDeep,
            ),
          ),
        ],
      ),
    );
  }
}
