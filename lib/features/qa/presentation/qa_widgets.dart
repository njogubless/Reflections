import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/status_chip.dart';
import '../domain/entities/question.dart';

class QuestionStatusChip extends StatelessWidget {
  const QuestionStatusChip({super.key, required this.status});

  final QuestionStatus status;

  @override
  Widget build(BuildContext context) => StatusChip(
    label: status.label,
    tone: switch (status) {
      QuestionStatus.open => StatusTone.pending,
      QuestionStatus.answered => StatusTone.published,
      QuestionStatus.closed => StatusTone.neutral,
    },
    icon: switch (status) {
      QuestionStatus.open => Icons.schedule,
      QuestionStatus.answered => Icons.check_circle_outline,
      QuestionStatus.closed => Icons.lock_outline,
    },
  );
}

/// The official administrator answer, visually distinct from any discussion.
class OfficialAnswerCard extends StatelessWidget {
  const OfficialAnswerCard({super.key, required this.answer});

  final OfficialAnswer answer;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.approvedBg,
      borderRadius: AppRadii.card,
      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.verified, color: AppColors.teal, size: 20),
            const SizedBox(width: 6),
            Text(
              'OFFICIAL ANSWER',
              style: context.text.labelSmall?.copyWith(color: AppColors.teal),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final p in answer.body.split(RegExp(r'\n\s*\n')))
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(p.trim(), style: context.text.bodyLarge),
          ),
        Text(
          '— ${answer.adminName}, ${formatShortDate(answer.publishedAt)}',
          style: context.text.labelMedium?.copyWith(
            color: AppColors.inkSecondary,
          ),
        ),
      ],
    ),
  );
}
