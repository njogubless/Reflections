import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/dialogs.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../sermons/presentation/controllers/audio_player_controller.dart';
import '../controllers/recording_studio_controller.dart';
import '../widgets/recording_widgets.dart';

class RecordingStudioPage extends ConsumerStatefulWidget {
  const RecordingStudioPage({super.key, this.resubmissionOf});

  /// Recording ID when re-recording audio for a changes-requested submission.
  final String? resubmissionOf;

  @override
  ConsumerState<RecordingStudioPage> createState() =>
      _RecordingStudioPageState();
}

class _RecordingStudioPageState extends ConsumerState<RecordingStudioPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Recording and sermon playback never run together.
    Future.microtask(
      () => ref.read(audioPlayerControllerProvider.notifier).pause(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  NotifierProvider<RecordingStudioController, StudioState> get _provider =>
      recordingStudioControllerProvider(widget.resubmissionOf);

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.paused ||
        lifecycle == AppLifecycleState.hidden) {
      ref.read(_provider.notifier).onAppBackgrounded();
    } else if (lifecycle == AppLifecycleState.resumed) {
      final phase = ref.read(_provider).phase;
      if (phase == StudioPhase.permissionDenied ||
          phase == StudioPhase.permissionPermanentlyDenied) {
        // User may have granted access in Settings.
        ref.read(_provider.notifier).checkPermission();
      }
    }
  }

  Future<void> _finish() async {
    final draft = await ref.read(_provider.notifier).finish();
    if (draft != null && mounted) {
      context.pushReplacement(Routes.studioSubmit(draft.id));
    }
  }

  Future<void> _discard() async {
    final ok = await confirmAction(
      context,
      title: 'Discard this recording?',
      message:
          'The audio recorded so far will be permanently deleted from this device.',
      confirmLabel: 'Discard',
      destructive: true,
    );
    if (ok) await ref.read(_provider.notifier).discard();
  }

  Future<void> _onPopRequested() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave the studio?'),
        content: const Text(
          'Your recording is still in progress. Save it as a draft to finish later, or keep recording.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'stay'),
            child: const Text('Keep recording'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('Save draft'),
          ),
        ],
      ),
    );
    if (choice == 'save' && mounted) {
      final draft = await ref.read(_provider.notifier).finish();
      if (draft != null && mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_provider);
    final controller = ref.read(_provider.notifier);

    ref.listen(_provider.select((s) => s.phase), (prev, next) {
      // Auto-finish at the 20:00 cap → review screen.
      final s = ref.read(_provider);
      if (next == StudioPhase.finished &&
          s.limitReached &&
          s.draft != null &&
          mounted) {
        showAppSnack(
          context,
          'The 20-minute limit was reached. Your recording was saved.',
        );
        context.pushReplacement(Routes.studioSubmit(s.draft!.id));
      }
    });

    return PopScope(
      canPop: !state.isActive,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onPopRequested();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.resubmissionOf == null ? 'Recording Studio' : 'Record Again',
          ),
          actions: [
            IconButton(
              tooltip: 'My recordings',
              onPressed: state.isActive
                  ? null
                  : () => context.push(Routes.myRecordings),
              icon: const Icon(Icons.history),
            ),
          ],
        ),
        body: switch (state.phase) {
          StudioPhase.checkingPermission => const LoadingView(
            label: 'Preparing microphone…',
          ),
          StudioPhase.permissionDenied => _PermissionView(
            permanently: false,
            onRequest: controller.requestPermission,
            onSettings: controller.openSettings,
          ),
          StudioPhase.permissionPermanentlyDenied => _PermissionView(
            permanently: true,
            onRequest: controller.requestPermission,
            onSettings: controller.openSettings,
          ),
          _ => _StudioBody(
            state: state,
            onStart: controller.start,
            onTogglePause: controller.togglePause,
            onFinish: _finish,
            onDiscard: _discard,
            onRetry: () => ref.invalidate(_provider),
          ),
        },
      ),
    );
  }
}

class _PermissionView extends StatelessWidget {
  const _PermissionView({
    required this.permanently,
    required this.onRequest,
    required this.onSettings,
  });

  final bool permanently;
  final VoidCallback onRequest;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) => EmptyView(
    icon: Icons.mic_off_outlined,
    title: 'Microphone access needed',
    message: permanently
        ? 'Microphone access is turned off for Devotion. Enable it in your device settings to record a sermon.'
        : 'Devotion needs your microphone to record sermons. Audio is only uploaded when you choose to submit.',
    action: FilledButton.icon(
      onPressed: permanently ? onSettings : onRequest,
      icon: Icon(permanently ? Icons.settings_outlined : Icons.mic),
      label: Text(permanently ? 'Open settings' : 'Allow microphone'),
    ),
  );
}

class _StudioBody extends StatelessWidget {
  const _StudioBody({
    required this.state,
    required this.onStart,
    required this.onTogglePause,
    required this.onFinish,
    required this.onDiscard,
    required this.onRetry,
  });

  final StudioState state;
  final VoidCallback onStart;
  final VoidCallback onTogglePause;
  final VoidCallback onFinish;
  final VoidCallback onDiscard;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final active = state.isActive;
    final recording = state.phase == StudioPhase.recording;
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
            _LiveChip(
              active: recording,
              paused: state.phase == StudioPhase.paused,
            ),
            const SizedBox(width: AppSpacing.xs),
            const Spacer(),
            Flexible(
              flex: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: AppRadii.pill,
                  border: Border.all(color: AppColors.linen),
                ),
                child: const MetaItem(
                  icon: Icons.mic_none,
                  label: 'Device mic · 44.1 kHz · AAC',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (state.error != null) ...[
          InlineError(state.error!.message),
          if (state.phase == StudioPhase.failed)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onRetry,
                child: const Text('Start over'),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (state.notice != null) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: const BoxDecoration(
              color: AppColors.pendingBg,
              borderRadius: AppRadii.control,
            ),
            child: MetaItem(
              icon: Icons.info_outline,
              label: state.notice!,
              color: AppColors.pending,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              LevelWaveform(levels: state.levels, active: recording),
              const SizedBox(height: AppSpacing.md),
              _GainReadout(db: recording ? state.inputDb : null),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.circle,
                    size: 12,
                    color: recording ? AppColors.error : AppColors.inkMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    switch (state.phase) {
                      StudioPhase.recording => 'RECORDING ACTIVE',
                      StudioPhase.paused => 'PAUSED',
                      StudioPhase.finishing => 'SAVING…',
                      StudioPhase.starting => 'STARTING…',
                      _ => 'READY TO RECORD',
                    },
                    style: context.text.labelMedium?.copyWith(
                      color: recording
                          ? AppColors.error
                          : AppColors.inkSecondary,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Semantics(
                liveRegion: true,
                label: 'Recorded ${formatDuration(state.elapsed)}',
                child: Text(
                  formatDuration(state.elapsed),
                  style: context.devotionText.timer,
                ),
              ),
              Text('Strict 20:00 maximum', style: context.text.bodySmall),
              const SizedBox(height: AppSpacing.md),
              ClipRRect(
                borderRadius: AppRadii.pill,
                child: Stack(
                  children: [
                    Container(height: 10, color: AppColors.linen),
                    FractionallySizedBox(
                      widthFactor: state.progress,
                      child: Container(
                        height: 10,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primaryInk, AppColors.goldDeep],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Recorded: ${state.elapsed.inMinutes}m ${state.elapsed.inSeconds % 60}s',
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: state.nearLimit
                          ? AppColors.changesBg
                          : AppColors.pendingBg,
                      borderRadius: AppRadii.pill,
                    ),
                    child: MetaItem(
                      icon: Icons.schedule,
                      label: '${formatDuration(state.remaining)} remaining',
                      color: state.nearLimit
                          ? AppColors.changes
                          : AppColors.pending,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (!active)
          FilledButton.icon(
            onPressed: state.phase == StudioPhase.ready ? onStart : null,
            icon: const Icon(Icons.radio_button_checked),
            label: const Text('Start recording'),
          )
        else
          Row(
            children: [
              _RoundAction(
                icon: Icons.delete_outline,
                label: 'DISCARD',
                color: AppColors.error,
                onTap: onDiscard,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: SizedBox(
                  height: 64,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryInk,
                    ),
                    onPressed: state.phase == StudioPhase.finishing
                        ? null
                        : onFinish,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.goldDeep,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.stop,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        const Flexible(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Finish & Review',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Saved as a draft',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _RoundAction(
                icon: recording ? Icons.pause : Icons.play_arrow,
                label: recording ? 'PAUSE' : 'RESUME',
                onTap: onTogglePause,
              ),
            ],
          ),
        const SizedBox(height: AppSpacing.lg),
        const _Guidelines(),
      ],
    );
  }
}

class _LiveChip extends StatelessWidget {
  const _LiveChip({required this.active, required this.paused});

  final bool active;
  final bool paused;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: const BoxDecoration(
      color: AppColors.surfaceHigh,
      borderRadius: AppRadii.pill,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.circle,
          size: 12,
          color: active
              ? AppColors.error
              : (paused ? AppColors.pending : AppColors.inkMuted),
        ),
        const SizedBox(width: 6),
        Text(
          active ? 'LIVE CAPTURE' : (paused ? 'PAUSED' : 'STANDBY'),
          style: context.text.labelMedium?.copyWith(
            color: active ? AppColors.error : AppColors.inkSecondary,
            letterSpacing: 1,
          ),
        ),
      ],
    ),
  );
}

class _GainReadout extends StatelessWidget {
  const _GainReadout({required this.db});

  final double? db;

  @override
  Widget build(BuildContext context) {
    final value = db;
    final (label, color) = value == null
        ? ('Idle', AppColors.inkMuted)
        : value < -40
        ? ('Too quiet — move closer', AppColors.pending)
        : value > -3
        ? ('Too loud — move back', AppColors.changes)
        : ('Optimal range', AppColors.goldDeep);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 10,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: AppRadii.control,
      ),
      child: Row(
        children: [
          const Icon(Icons.volume_up_outlined, size: 18),
          const SizedBox(width: 6),
          Text('Input: ', style: context.text.bodySmall),
          Text(
            value == null ? '—' : '${value.toStringAsFixed(1)} dB',
            style: context.text.labelMedium,
          ),
          const Spacer(),
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surfaceHigh,
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox.square(
        dimension: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color ?? AppColors.primaryInk),
            const SizedBox(height: 2),
            Text(
              label,
              style: context.text.labelSmall?.copyWith(
                color: color ?? AppColors.primaryInk,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Guidelines extends StatelessWidget {
  const _Guidelines();

  @override
  Widget build(BuildContext context) => AppCard(
    color: AppColors.surfaceLow,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.verified_outlined, color: AppColors.goldDeep),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                'Recording guidelines',
                style: context.text.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final (icon, text) in const [
          (
            Icons.check_circle_outline,
            'Keep 15–20 cm (6–8 in) from the microphone for warmth and clarity.',
          ),
          (
            Icons.check_circle_outline,
            'Recordings stop automatically at the strict 20-minute maximum.',
          ),
          (
            Icons.info_outline,
            'Every submission is reviewed by the ministry team before it is published.',
          ),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 18, color: AppColors.goldDeep),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: Text(text, style: context.text.bodyMedium)),
              ],
            ),
          ),
      ],
    ),
  );
}
