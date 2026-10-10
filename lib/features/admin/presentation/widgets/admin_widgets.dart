import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/domain/content_status.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/widgets/dialogs.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../auth/presentation/pages/auth_pages.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Second line of defence behind the router guard: admin pages render only
/// for users whose ID-token role is `admin`. Firestore/Storage rules remain
/// the actual security boundary.
class AdminGate extends ConsumerWidget {
  const AdminGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    return switch (auth) {
      AsyncData(value: final user?) when user.isAdmin => child,
      AsyncData() || AsyncError() => const ForbiddenPage(),
      _ => const Scaffold(body: LoadingView()),
    };
  }
}

class ContentStatusChip extends StatelessWidget {
  const ContentStatusChip({super.key, required this.status});

  final ContentStatus status;

  @override
  Widget build(BuildContext context) => StatusChip(
    label: status.label,
    tone: switch (status) {
      ContentStatus.published => StatusTone.published,
      ContentStatus.draft => StatusTone.pending,
      ContentStatus.unpublished => StatusTone.changes,
      ContentStatus.archived => StatusTone.neutral,
    },
  );
}

/// Horizontal filter chips for list screens.
class FilterBar<T> extends StatelessWidget {
  const FilterBar({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 52,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.page,
        vertical: 8,
      ),
      children: [
        for (final v in values)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: ChoiceChip(
              label: Text(label(v).toUpperCase()),
              selected: v == selected,
              showCheckmark: false,
              labelStyle: context.text.labelSmall?.copyWith(
                color: v == selected ? Colors.white : AppColors.ink,
              ),
              onSelected: (_) => onSelected(v),
            ),
          ),
      ],
    ),
  );
}

/// Publish / unpublish / archive buttons limited to valid transitions.
class LifecycleActions extends StatelessWidget {
  const LifecycleActions({
    super.key,
    required this.status,
    required this.busy,
    required this.onChange,
    this.entityLabel = 'item',
  });

  final ContentStatus status;
  final bool busy;
  final String entityLabel;
  final Future<void> Function(ContentStatus next) onChange;

  @override
  Widget build(BuildContext context) {
    final next = status.allowedNext.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final n in next)
          n == ContentStatus.published
              ? FilledButton.icon(
                  onPressed: busy ? null : () => _confirm(context, n),
                  icon: const Icon(Icons.public),
                  label: Text(
                    status == ContentStatus.unpublished
                        ? 'Republish'
                        : 'Publish',
                  ),
                )
              : OutlinedButton(
                  onPressed: busy ? null : () => _confirm(context, n),
                  child: Text(switch (n) {
                    ContentStatus.unpublished => 'Unpublish',
                    ContentStatus.archived => 'Archive',
                    ContentStatus.draft => 'Move to drafts',
                    ContentStatus.published => 'Publish',
                  }),
                ),
      ],
    );
  }

  Future<void> _confirm(BuildContext context, ContentStatus n) async {
    final ok = await confirmAction(
      context,
      title: switch (n) {
        ContentStatus.published => 'Publish this $entityLabel?',
        ContentStatus.unpublished => 'Unpublish this $entityLabel?',
        ContentStatus.archived => 'Archive this $entityLabel?',
        ContentStatus.draft => 'Move back to drafts?',
      },
      message: switch (n) {
        ContentStatus.published =>
          'It will become visible to every signed-in member.',
        ContentStatus.unpublished =>
          'It will be hidden from members immediately. Existing links will stop working.',
        ContentStatus.archived =>
          'It will be hidden and removed from active lists.',
        ContentStatus.draft =>
          'It will remain hidden until you publish it again.',
      },
      confirmLabel: 'Confirm',
      destructive:
          n == ContentStatus.unpublished || n == ContentStatus.archived,
    );
    if (ok) await onChange(n);
  }
}

/// Shows the latest error of an admin action inline.
class ActionError extends StatelessWidget {
  const ActionError({super.key, required this.state});

  final AsyncValue<void> state;

  @override
  Widget build(BuildContext context) => state.hasError
      ? Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: InlineError(AppException.from(state.error!).message),
        )
      : const SizedBox.shrink();
}

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
    this.highlight = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Material(
    color: highlight ? AppColors.primary : AppColors.card,
    shape: RoundedRectangleBorder(
      borderRadius: AppRadii.card,
      side: highlight
          ? BorderSide.none
          : const BorderSide(color: AppColors.linen),
    ),
    child: InkWell(
      borderRadius: AppRadii.card,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: highlight ? AppColors.gold : AppColors.goldDeep),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: context.text.displayMedium?.copyWith(
                      color: highlight ? Colors.white : AppColors.primaryInk,
                    ),
                  ),
                ),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelMedium?.copyWith(
                    color: highlight
                        ? AppColors.onPrimaryMuted
                        : AppColors.inkSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
