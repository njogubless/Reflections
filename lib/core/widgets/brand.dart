import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';

/// Circular logo emblem (dove over radiating cross).
class LogoEmblem extends StatelessWidget {
  const LogoEmblem({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.linen),
    ),
    padding: EdgeInsets.all(size * 0.12),
    child: Image.asset(
      'assets/images/logo.png',
      fit: BoxFit.contain,
      semanticLabel: 'Devotion logo',
    ),
  );
}

/// "Devotion [FAITH] / <section>" header from the Stitch screens.
class BrandTitle extends StatelessWidget {
  const BrandTitle({super.key, required this.section});

  final String section;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.church_outlined, color: AppColors.goldDeep, size: 22),
      const SizedBox(width: AppSpacing.xs),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                'Devotion',
                style: context.text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryInk,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.goldContainer.withValues(alpha: 0.6),
                  borderRadius: AppRadii.pill,
                ),
                child: Text(
                  'FAITH',
                  style: context.text.labelSmall?.copyWith(
                    color: AppColors.goldDeep,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
          Text(section, style: context.text.bodySmall),
        ],
      ),
    ],
  );
}
