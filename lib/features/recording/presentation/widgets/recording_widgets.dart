import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/media/media_storage.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../sermons/presentation/controllers/audio_player_controller.dart';
import '../../domain/entities/recording_status.dart';
import '../../domain/entities/recording_submission.dart';

/// Live input visualizer: pine/gold bars, older bars fade to linen.
class LevelWaveform extends StatelessWidget {
  const LevelWaveform({
    super.key,
    required this.levels,
    this.active = true,
    this.bars = 36,
  });

  final List<double> levels;
  final bool active;
  final int bars;

  @override
  Widget build(BuildContext context) => Semantics(
    label: active ? 'Microphone input level' : 'Microphone idle',
    child: SizedBox(
      height: 120,
      child: LayoutBuilder(
        builder: (context, c) {
          final recent = levels.length > bars
              ? levels.sublist(levels.length - bars)
              : levels;
          final padded = [
            ...List<double>.filled(bars - recent.length, 0.04),
            ...recent.map((l) => l.clamp(0.04, 1.0)),
          ];
          final w = c.maxWidth / bars;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < bars; i++)
                SizedBox(
                  width: w,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: w * 0.55,
                      height: 8 + padded[i] * 108,
                      decoration: BoxDecoration(
                        color: !active
                            ? AppColors.linen
                            : (i < bars * 0.25
                                  ? AppColors.linen
                                  : (i.isEven
                                        ? AppColors.primaryInk
                                        : AppColors.goldDeep)),
                        borderRadius: AppRadii.pill,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

class RecordingStatusChip extends StatelessWidget {
  const RecordingStatusChip({super.key, required this.status});

  final RecordingStatus status;

  @override
  Widget build(BuildContext context) {
    final (tone, icon) = switch (status) {
      RecordingStatus.draft => (StatusTone.neutral, Icons.edit_note),
      RecordingStatus.submitted => (StatusTone.pending, Icons.schedule),
      RecordingStatus.underReview => (StatusTone.pending, Icons.hourglass_top),
      RecordingStatus.changesRequested => (
        StatusTone.changes,
        Icons.edit_outlined,
      ),
      RecordingStatus.approved => (
        StatusTone.published,
        Icons.check_circle_outline,
      ),
      RecordingStatus.rejected => (StatusTone.rejected, Icons.block),
      RecordingStatus.published => (StatusTone.published, Icons.public),
    };
    return StatusChip(label: status.label, tone: tone, icon: icon);
  }
}

/// Audio source for [PreviewPlayer].
sealed class PreviewSource {
  const PreviewSource();
}

class LocalFileSource extends PreviewSource {
  const LocalFileSource(this.path);
  final String path;
}

class StorageSource extends PreviewSource {
  const StorageSource(this.storagePath);
  final String storagePath;
}

/// Self-contained player for previewing a draft or a submission. It owns its
/// own [AudioPlayer] and is independent of the published-sermon player.
class PreviewPlayer extends ConsumerStatefulWidget {
  const PreviewPlayer({
    super.key,
    required this.source,
    this.label = 'Preview',
  });

  final PreviewSource source;
  final String label;

  @override
  ConsumerState<PreviewPlayer> createState() => _PreviewPlayerState();
}

class _PreviewPlayerState extends ConsumerState<PreviewPlayer> {
  final _player = AudioPlayer();
  bool _loaded = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _ensureLoaded() async {
    if (_loaded || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      switch (widget.source) {
        case LocalFileSource(:final path):
          await _player.setFilePath(path);
        case StorageSource(:final storagePath):
          final url = await ref
              .read(mediaStorageProvider)
              .downloadUrl(storagePath);
          await _player.setUrl(url);
      }
      _loaded = true;
    } catch (e, s) {
      _error = AppException.from(e, s).message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle() async {
    await _ensureLoaded();
    if (!_loaded) return;
    if (_player.playing) {
      await _player.pause();
    } else {
      // Don't talk over the sermon player.
      await ref.read(audioPlayerControllerProvider.notifier).pause();
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      unawaited(_player.play());
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.sm),
    decoration: BoxDecoration(
      color: AppColors.surfaceLow,
      borderRadius: AppRadii.card,
      border: Border.all(color: AppColors.linen),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            StreamBuilder<bool>(
              stream: _player.playingStream,
              builder: (context, snap) {
                final playing = snap.data ?? false;
                return IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primaryInk,
                  ),
                  tooltip: playing ? 'Pause preview' : 'Play preview',
                  onPressed: _loading ? null : _toggle,
                  icon: _loading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          playing ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                        ),
                );
              },
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: StreamBuilder<Duration>(
                stream: _player.positionStream,
                builder: (context, snap) {
                  final pos = snap.data ?? Duration.zero;
                  final total = _player.duration ?? Duration.zero;
                  final max = total.inMilliseconds.toDouble();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.label.toUpperCase(),
                        style: context.devotionText.overline,
                      ),
                      Slider(
                        value: max <= 0
                            ? 0
                            : pos.inMilliseconds.clamp(0, max).toDouble(),
                        max: max <= 0 ? 1 : max,
                        onChanged: max <= 0
                            ? null
                            : (v) => _player.seek(
                                Duration(milliseconds: v.round()),
                              ),
                      ),
                      Text(
                        '${formatDuration(pos)} / ${formatDuration(total)}',
                        style: context.text.labelSmall,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            _error!,
            style: context.text.bodySmall?.copyWith(color: AppColors.changes),
          ),
        ],
      ],
    ),
  );
}

/// Title / speaker / scripture / description fields for a sermon.
class SermonMetadataFields extends StatelessWidget {
  const SermonMetadataFields({
    super.key,
    required this.title,
    required this.speaker,
    required this.scripture,
    required this.description,
    this.enabled = true,
  });

  final TextEditingController title;
  final TextEditingController speaker;
  final TextEditingController scripture;
  final TextEditingController description;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextFormField(
        controller: title,
        enabled: enabled,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Sermon title *'),
        validator: Validators.title,
      ),
      const SizedBox(height: AppSpacing.sm),
      TextFormField(
        controller: speaker,
        enabled: enabled,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Speaker',
          hintText: 'e.g. Rev. Grace Mwangi',
        ),
        validator: Validators.optionalShort,
      ),
      const SizedBox(height: AppSpacing.sm),
      TextFormField(
        controller: scripture,
        enabled: enabled,
        decoration: const InputDecoration(
          labelText: 'Scripture reference',
          hintText: 'e.g. Luke 4:1–13',
        ),
        validator: Validators.optionalShort,
      ),
      const SizedBox(height: AppSpacing.sm),
      TextFormField(
        controller: description,
        enabled: enabled,
        minLines: 3,
        maxLines: 6,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Description',
          alignLabelWithHint: true,
        ),
        validator: Validators.description,
      ),
    ],
  );
}

SermonMetadata metadataFrom({
  required TextEditingController title,
  required TextEditingController speaker,
  required TextEditingController scripture,
  required TextEditingController description,
}) => SermonMetadata(
  title: title.text.trim(),
  speakerName: speaker.text.trim(),
  scriptureReference: scripture.text.trim(),
  description: description.text.trim(),
);
