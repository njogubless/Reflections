import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../core/widgets/storage_image.dart';
import '../../domain/entities/sermon.dart';
import '../controllers/audio_player_controller.dart';

/// Library list card (sermons_published_audio_library design).
class SermonCard extends ConsumerWidget {
  const SermonCard({super.key, required this.sermon});

  final Sermon sermon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nowPlaying = ref.watch(
      audioPlayerControllerProvider.select((s) => s.sermon?.id),
    );
    final isCurrent = nowPlaying == sermon.id;
    return AppCard(
      onTap: () => context.push(Routes.sermon(sermon.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (sermon.scriptureReference.isNotEmpty) ...[
                const Icon(
                  Icons.menu_book_outlined,
                  size: 14,
                  color: AppColors.goldDeep,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    sermon.scriptureReference.toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    style: context.devotionText.overline,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                '· ${formatShortDate(sermon.publishedAt)}',
                style: context.text.bodySmall,
              ),
              const Spacer(),
              if (sermon.sourceType == SermonSource.userSubmission)
                const Tooltip(
                  message: 'Community recording reviewed by the ministry team',
                  child: Icon(
                    Icons.verified_outlined,
                    size: 18,
                    color: AppColors.teal,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            sermon.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.text.headlineSmall,
          ),
          const SizedBox(height: 2),
          Text(
            sermon.speakerName,
            style: context.text.labelMedium?.copyWith(
              color: AppColors.inkSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          if ((sermon.scriptureQuote ?? sermon.description).isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: AppColors.gold, width: 2),
                ),
              ),
              child: Text(
                sermon.scriptureQuote != null
                    ? '“${sermon.scriptureQuote}”'
                    : sermon.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: AppColors.inkSecondary,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          const Divider(),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Flexible(
                child: MetaItem(
                  icon: Icons.local_offer_outlined,
                  label: sermon.category,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              MetaItem(
                icon: Icons.schedule,
                label: formatMinutes(sermon.durationSeconds),
              ),
              const Spacer(),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: const StadiumBorder(),
                ),
                onPressed: () {
                  ref
                      .read(audioPlayerControllerProvider.notifier)
                      .playSermon(sermon);
                  context.push(Routes.sermon(sermon.id));
                },
                icon: Icon(
                  isCurrent ? Icons.graphic_eq : Icons.play_arrow,
                  size: 18,
                ),
                label: Text(isCurrent ? 'Playing' : 'Listen'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Sermon of the week" hero (dark pine card).
class FeaturedSermonCard extends ConsumerWidget {
  const FeaturedSermonCard({
    super.key,
    required this.sermon,
    this.label = 'Sermon of the week',
  });

  final Sermon sermon;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) => HeroCard(
    onTap: () => context.push(Routes.sermon(sermon.id)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Pill takes the free space; it only ellipsizes when truly cramped.
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: GoldTag(
                  label: label,
                  icon: Icons.star_outline,
                  dark: true,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            MetaItem(
              icon: Icons.schedule,
              label: formatMinutes(sermon.durationSeconds),
              color: AppColors.onPrimaryMuted,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          sermon.title,
          style: context.text.displaySmall?.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(
          sermon.speakerName,
          style: context.text.labelLarge?.copyWith(color: AppColors.gold),
        ),
        if (sermon.scriptureReference.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: AppRadii.control,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sermon.scriptureReference.toUpperCase(),
                  style: context.text.labelSmall?.copyWith(
                    color: AppColors.goldContainer,
                  ),
                ),
                if (sermon.scriptureQuote != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '“${sermon.scriptureQuote}”',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.goldContainer,
              foregroundColor: AppColors.primaryInk,
            ),
            onPressed: () {
              ref
                  .read(audioPlayerControllerProvider.notifier)
                  .playSermon(sermon);
              context.push(Routes.sermon(sermon.id));
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('LISTEN NOW'),
          ),
        ),
      ],
    ),
  );
}

/// Compact horizontal card with cover image (home "Recent sermons").
class SermonTile extends StatelessWidget {
  const SermonTile({super.key, required this.sermon});

  final Sermon sermon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    child: AppCard(
      padding: EdgeInsets.zero,
      onTap: () => context.push(Routes.sermon(sermon.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadii.lg),
            ),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  StorageImage(
                    path: sermon.coverStoragePath,
                    fallbackIcon: Icons.headphones,
                  ),
                  if (sermon.scriptureReference.isNotEmpty)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryDeep.withValues(alpha: 0.85),
                          borderRadius: AppRadii.pill,
                        ),
                        child: Text(
                          sermon.scriptureReference,
                          style: context.text.labelSmall?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sermon.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.headlineSmall,
                ),
                Text(
                  sermon.speakerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                MetaItem(
                  icon: Icons.headphones,
                  label: formatMinutes(sermon.durationSeconds),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Docked mini-player above the bottom navigation.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioPlayerControllerProvider);
    final sermon = state.sermon;
    if (sermon == null) return const SizedBox.shrink();
    final controller = ref.read(audioPlayerControllerProvider.notifier);
    return Material(
      color: AppColors.canvas,
      child: InkWell(
        onTap: () => context.push(Routes.sermon(sermon.id)),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.gold, width: 0.6)),
          ),
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 8, 4, 8),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.graphic_eq, color: AppColors.gold),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      sermon.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall,
                    ),
                    Text(
                      state.error?.message ?? sermon.speakerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(
                        color: state.error != null ? AppColors.changes : null,
                      ),
                    ),
                  ],
                ),
              ),
              if (state.loading)
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primaryInk,
                  ),
                  tooltip: state.playing ? 'Pause' : 'Play',
                  onPressed: controller.togglePlay,
                  icon: Icon(
                    state.playing ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                  ),
                ),
              IconButton(
                tooltip: 'Close player',
                onPressed: controller.stop,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
