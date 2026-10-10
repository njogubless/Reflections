import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';

/// Level-1 parchment card (white, linen border, ambient shadow).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.color = AppColors.card,
    this.border = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color color;
  final bool border;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      borderRadius: AppRadii.card,
      border: border ? Border.all(color: AppColors.linen) : null,
      boxShadow: color == AppColors.card ? AppShadows.level1 : null,
    ),
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: AppRadii.card,
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}

/// Deep pine hero card used for "Sermon of the week" / featured content.
class HeroCard extends StatelessWidget {
  const HeroCard({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: AppRadii.card,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.primary, AppColors.primaryDeep],
      ),
      boxShadow: AppShadows.level2,
    ),
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.card,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md + 4),
          child: child,
        ),
      ),
    ),
  );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.overline,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? overline;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.page,
      AppSpacing.lg,
      AppSpacing.xs,
      AppSpacing.sm,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (overline != null)
                Text(
                  overline!.toUpperCase(),
                  style: context.devotionText.overline,
                ),
              Text(title, style: context.text.headlineMedium),
            ],
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(actionLabel!),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.goldDeep,
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

/// Ornamental divider with a small centred glyph (filigree motif).
class OrnamentDivider extends StatelessWidget {
  const OrnamentDivider({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
    child: Row(
      children: [
        Expanded(
          child: Divider(color: AppColors.gold, indent: 60, endIndent: 12),
        ),
        Icon(Icons.wb_twilight, size: 18, color: AppColors.gold),
        Expanded(
          child: Divider(color: AppColors.gold, indent: 12, endIndent: 60),
        ),
      ],
    ),
  );
}

/// Leading meta row: small icon + text in the functional voice.
class MetaItem extends StatelessWidget {
  const MetaItem({
    super.key,
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.inkSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: c),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySmall?.copyWith(color: c),
          ),
        ),
      ],
    );
  }
}
