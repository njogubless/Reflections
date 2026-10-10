import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/brand.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../core/widgets/storage_image.dart';
import '../../domain/entities/sermon.dart';
import '../controllers/audio_player_controller.dart';
import '../providers/sermon_providers.dart';

class SermonPlayerPage extends ConsumerWidget {
  const SermonPlayerPage({super.key, required this.sermonId});

  final String sermonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sermon = ref.watch(sermonDetailProvider(sermonId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sermon Player'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: LogoEmblem(size: 36),
          ),
        ],
      ),
      body: AsyncValueView(
        value: sermon,
        onRetry: () => ref.invalidate(sermonDetailProvider(sermonId)),
        data: (s) => _PlayerBody(sermon: s),
      ),
    );
  }
}

class _PlayerBody extends ConsumerWidget {
  const _PlayerBody({required this.sermon});

  final Sermon sermon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final related = ref.watch(relatedSermonsProvider(sermon.id));
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        0,
        AppSpacing.page,
        AppSpacing.xl,
      ),
      children: [
        Row(
          children: [
            const Icon(Icons.circle, size: 8, color: AppColors.goldDeep),
            const SizedBox(width: 6),
            Text(
              sermon.sourceType == SermonSource.userSubmission
                  ? 'COMMUNITY RECORDING'
                  : 'AUDIO DEVOTIONAL',
              style: context.devotionText.overline,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: AppRadii.card,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (sermon.coverStoragePath != null)
                      StorageImage(path: sermon.coverStoragePath)
                    else
                      const _CoverArt(),
                    Positioned(
                      top: 14,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: GoldTag(label: sermon.category, dark: true),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.xs,
          children: [
            if (sermon.scriptureReference.isNotEmpty)
              GoldTag(
                label: sermon.scriptureReference,
                icon: Icons.menu_book_outlined,
              ),
            Text(
              formatShortDate(sermon.publishedAt),
              style: context.text.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          sermon.title,
          textAlign: TextAlign.center,
          style: context.text.displayMedium,
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.person_outline,
              size: 18,
              color: AppColors.goldDeep,
            ),
            const SizedBox(width: 4),
            Text(
              sermon.speakerName,
              style: context.text.labelLarge?.copyWith(
                color: AppColors.goldDeep,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _Transport(sermon: sermon),
        if (sermon.scriptureQuote != null) ...[
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.format_quote,
                      size: 18,
                      color: AppColors.goldDeep,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'KEY VERSE OF MEDITATION',
                      style: context.devotionText.overline,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '“${sermon.scriptureQuote}”',
                  style: context.devotionText.scriptureQuote,
                ),
                const SizedBox(height: AppSpacing.xs),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '— ${sermon.scriptureReference}',
                    style: context.text.labelMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (sermon.description.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('About this message', style: context.text.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(sermon.description, style: context.text.bodyLarge),
        ],
        related.maybeWhen(
          data: (items) => items.isEmpty
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.lg),
                  child: AppCard(
                    color: AppColors.surfaceLow,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.playlist_play,
                              size: 20,
                              color: AppColors.goldDeep,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'MORE FROM ${sermon.speakerName.toUpperCase()}',
                              style: context.devotionText.overline,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        for (final r in items)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.xs,
                            ),
                            child: AppCard(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              onTap: () =>
                                  context.pushReplacement(Routes.sermon(r.id)),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.anchor,
                                      color: AppColors.gold,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          r.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: context.text.headlineSmall,
                                        ),
                                        Text(
                                          r.scriptureReference,
                                          style: context.text.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    formatMinutes(r.durationSeconds),
                                    style: context.text.labelSmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _CoverArt extends StatelessWidget {
  const _CoverArt();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: RadialGradient(
        colors: [Color(0xFF2B4A3B), AppColors.primaryDeep],
        radius: 0.9,
      ),
    ),
    child: Center(child: LogoEmblem(size: 120)),
  );
}

class _Transport extends ConsumerWidget {
  const _Transport({required this.sermon});

  final Sermon sermon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioPlayerControllerProvider);
    final controller = ref.read(audioPlayerControllerProvider.notifier);
    final isCurrent = state.sermon?.id == sermon.id;
    final position = isCurrent
        ? (ref.watch(playbackPositionProvider).value ?? Duration.zero)
        : Duration.zero;
    final total = isCurrent && state.duration != null
        ? state.duration!
        : Duration(seconds: sermon.durationSeconds);
    final maxMs = total.inMilliseconds.toDouble();
    final valueMs = position.inMilliseconds
        .clamp(0, total.inMilliseconds)
        .toDouble();

    return Column(
      children: [
        if (isCurrent && state.error != null) ...[
          InlineError(state.error!.message),
          const SizedBox(height: AppSpacing.sm),
        ],
        Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xs,
            AppSpacing.sm,
            AppSpacing.xs,
            AppSpacing.sm,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surfaceLow,
            borderRadius: AppRadii.card,
          ),
          child: Column(
            children: [
              Slider(
                value: maxMs <= 0 ? 0 : valueMs,
                max: maxMs <= 0 ? 1 : maxMs,
                onChanged: isCurrent && maxMs > 0
                    ? (v) => controller.seek(Duration(milliseconds: v.round()))
                    : null,
                semanticFormatterCallback: (v) =>
                    '${formatDuration(Duration(milliseconds: v.round()))} of ${formatDuration(total)}',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  children: [
                    Text(
                      formatDuration(position),
                      style: context.text.labelSmall,
                    ),
                    const Spacer(),
                    if (isCurrent && state.loading)
                      Text('BUFFERING', style: context.devotionText.overline),
                    const Spacer(),
                    Text(formatDuration(total), style: context.text.labelSmall),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _PillButton(
              label: '${state.speed}x',
              tooltip: 'Playback speed',
              onTap: controller.cycleSpeed,
            ),
            IconButton(
              tooltip: 'Back 10 seconds',
              onPressed: isCurrent
                  ? () => controller.skip(const Duration(seconds: -10))
                  : null,
              icon: const Icon(Icons.replay_10, size: 30),
            ),
            SizedBox.square(
              dimension: 76,
              child: IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primaryInk,
                ),
                tooltip: isCurrent && state.playing ? 'Pause' : 'Play',
                onPressed: () {
                  if (isCurrent) {
                    controller.togglePlay();
                  } else {
                    controller.playSermon(sermon);
                  }
                },
                icon: isCurrent && state.loading
                    ? const SizedBox.square(
                        dimension: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        isCurrent && state.playing
                            ? Icons.pause
                            : Icons.play_arrow,
                        size: 40,
                        color: Colors.white,
                      ),
              ),
            ),
            IconButton(
              tooltip: 'Forward 30 seconds',
              onPressed: isCurrent
                  ? () => controller.skip(const Duration(seconds: 30))
                  : null,
              icon: const Icon(Icons.forward_30, size: 30),
            ),
            _PillButton(
              icon: Icons.bedtime_outlined,
              label: state.sleepAt == null ? 'Off' : 'On',
              tooltip: 'Sleep timer',
              onTap: () =>
                  _pickSleepTimer(context, controller, state.sleepAt != null),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickSleepTimer(
    BuildContext context,
    AudioPlayerController controller,
    bool active,
  ) async {
    final choice = await showModalBottomSheet<Duration?>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Sleep timer')),
            for (final m in const [5, 15, 30, 45, 60])
              ListTile(
                leading: const Icon(Icons.bedtime_outlined),
                title: Text('$m minutes'),
                onTap: () => Navigator.of(context).pop(Duration(minutes: m)),
              ),
            if (active)
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Turn off'),
                onTap: () => Navigator.of(context).pop(Duration.zero),
              ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    controller.setSleepTimer(choice == Duration.zero ? null : choice);
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.onTap,
    required this.tooltip,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final String tooltip;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: AppColors.surfaceLow,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 56),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 4),
              ],
              Text(label, style: context.text.labelLarge),
            ],
          ),
        ),
      ),
    ),
  );
}
