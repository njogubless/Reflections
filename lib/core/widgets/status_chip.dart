import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';

enum StatusTone { published, pending, changes, rejected, neutral }

/// Pill-shaped status badge (DESIGN.md "Status Pills").
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
  });

  final String label;
  final StatusTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (tone) {
      StatusTone.published => (AppColors.approved, AppColors.approvedBg),
      StatusTone.pending => (AppColors.pending, AppColors.pendingBg),
      StatusTone.changes => (AppColors.changes, AppColors.changesBg),
      StatusTone.rejected => (AppColors.error, AppColors.errorBg),
      StatusTone.neutral => (AppColors.inkSecondary, AppColors.neutralBg),
    };
    return Semantics(
      label: 'Status: $label',
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: bg, borderRadius: AppRadii.pill),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 4),
            ],
            Text(
              label.toUpperCase(),
              style: context.text.labelSmall?.copyWith(color: fg),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small gold "overline" pill used for section and scripture labels.
class GoldTag extends StatelessWidget {
  const GoldTag({super.key, required this.label, this.icon, this.dark = false});

  final String label;
  final IconData? icon;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? AppColors.goldContainer : AppColors.onGoldContainer;
    final bg = dark
        ? Colors.white.withValues(alpha: 0.10)
        : AppColors.goldContainer.withValues(alpha: 0.55);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadii.pill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label.toUpperCase(),
              overflow: TextOverflow.ellipsis,
              style: context.text.labelSmall?.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}
