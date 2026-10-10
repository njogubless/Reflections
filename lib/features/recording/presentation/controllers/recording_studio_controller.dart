import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/app_exception.dart';
import '../../data/datasources/audio_recorder_service.dart';
import '../../domain/entities/recording_draft.dart';
import '../../domain/entities/recording_submission.dart';
import '../../domain/repositories/recording_repositories.dart';
import '../../domain/recording_timer.dart';
import '../providers/recording_providers.dart';

enum StudioPhase {
  checkingPermission,
  permissionDenied,
  permissionPermanentlyDenied,
  ready,
  starting,
  recording,
  paused,
  finishing,
  finished,
  failed,
}

class StudioState {
  const StudioState({
    this.phase = StudioPhase.checkingPermission,
    this.elapsed = Duration.zero,
    this.levels = const [],
    this.inputDb,
    this.draft,
    this.error,
    this.notice,
    this.limitReached = false,
  });

  final StudioPhase phase;
  final Duration elapsed;

  /// Recent normalized input levels for the waveform (oldest first).
  final List<double> levels;
  final double? inputDb;
  final RecordingDraft? draft;
  final AppException? error;

  /// Non-error information such as "Paused by an interruption".
  final String? notice;
  final bool limitReached;

  Duration get remaining {
    final r = RecordingLimits.maxDuration - elapsed;
    return r.isNegative ? Duration.zero : r;
  }

  double get progress =>
      (elapsed.inMilliseconds / RecordingLimits.maxDuration.inMilliseconds)
          .clamp(0, 1)
          .toDouble();

  bool get isActive =>
      phase == StudioPhase.recording || phase == StudioPhase.paused;

  bool get nearLimit => isActive && remaining <= RecordingLimits.warnRemaining;

  StudioState copyWith({
    StudioPhase? phase,
    Duration? elapsed,
    List<double>? levels,
    double? inputDb,
    RecordingDraft? draft,
    AppException? error,
    String? notice,
    bool clearNotice = false,
    bool? limitReached,
  }) => StudioState(
    phase: phase ?? this.phase,
    elapsed: elapsed ?? this.elapsed,
    levels: levels ?? this.levels,
    inputDb: inputDb ?? this.inputDb,
    draft: draft ?? this.draft,
    error: error,
    notice: clearNotice ? null : (notice ?? this.notice),
    limitReached: limitReached ?? this.limitReached,
  );
}

/// Recording-studio state machine. One instance per studio visit; the
/// optional argument is the recording ID being re-recorded for resubmission.
class RecordingStudioController extends Notifier<StudioState> {
  RecordingStudioController(this.resubmissionOf);

  final String? resubmissionOf;

  static const _bars = 36;
  static const _tick = Duration(milliseconds: 200);

  late AudioRecorderService _recorder;
  late DraftRepository _drafts;
  final RecordingTimer _timer = RecordingTimer(
    limit: RecordingLimits.maxDuration,
  );
  Timer? _ticker;
  StreamSubscription<double>? _levelSub;
  StreamSubscription<RecorderSignal>? _signalSub;
  String? _draftId;
  String? _path;
  bool _busy = false;

  /// Mirrors "recording or paused" outside of [state], which must not be
  /// touched while the provider is disposing.
  bool _sessionActive = false;

  @override
  StudioState build() {
    _recorder = ref.watch(audioRecorderServiceProvider);
    _drafts = ref.watch(draftRepositoryProvider);
    ref.onDispose(_onDispose);
    Future.microtask(checkPermission);
    return const StudioState();
  }

  Future<void> checkPermission() async {
    try {
      final p = await _recorder.checkPermission();
      if (!ref.mounted) return;
      state = state.copyWith(phase: _phaseFor(p));
    } catch (e, s) {
      if (!ref.mounted) return;
      state = state.copyWith(
        phase: StudioPhase.failed,
        error: AppException.from(e, s),
      );
    }
  }

  Future<void> requestPermission() async {
    final p = await _recorder.requestPermission();
    if (!ref.mounted) return;
    state = state.copyWith(phase: _phaseFor(p));
  }

  Future<void> openSettings() => _recorder.openSettings();

  StudioPhase _phaseFor(MicPermission p) => switch (p) {
    MicPermission.granted => StudioPhase.ready,
    MicPermission.denied => StudioPhase.permissionDenied,
    MicPermission.permanentlyDenied => StudioPhase.permissionPermanentlyDenied,
  };

  Future<void> start() async {
    // Prevent duplicate sessions from repeated taps.
    if (_busy || state.phase != StudioPhase.ready) return;
    _busy = true;
    state = state.copyWith(phase: StudioPhase.starting, clearNotice: true);
    try {
      final permission = await _recorder.checkPermission();
      if (permission != MicPermission.granted) {
        state = state.copyWith(phase: _phaseFor(permission));
        return;
      }
      _draftId = const Uuid().v4();
      _path = await _drafts.newRecordingPath(_draftId!);
      await _recorder.start(_path!);
      _timer.start();
      _sessionActive = true;
      _levelSub = _recorder.levels.listen(_onLevel);
      _signalSub = _recorder.signals.listen(_onSignal);
      _ticker = Timer.periodic(_tick, (_) => _onTick());
      if (!ref.mounted) return;
      state = state.copyWith(
        phase: StudioPhase.recording,
        elapsed: Duration.zero,
        levels: const [],
      );
    } catch (e, s) {
      _timer.reset();
      if (!ref.mounted) return;
      state = state.copyWith(
        phase: StudioPhase.failed,
        error: AppException.from(e, s),
      );
    } finally {
      _busy = false;
    }
  }

  Future<void> pause({String? notice}) async {
    if (_busy || state.phase != StudioPhase.recording) return;
    _busy = true;
    try {
      await _recorder.pause();
      _timer.pause();
      state = state.copyWith(
        phase: StudioPhase.paused,
        elapsed: _timer.elapsed,
        notice: notice,
      );
    } catch (e, s) {
      state = state.copyWith(error: AppException.from(e, s));
    } finally {
      _busy = false;
    }
  }

  Future<void> resume() async {
    if (_busy || state.phase != StudioPhase.paused || _timer.limitReached) {
      return;
    }
    _busy = true;
    try {
      await _recorder.resume();
      _timer.resume();
      state = state.copyWith(phase: StudioPhase.recording, clearNotice: true);
    } catch (e, s) {
      state = state.copyWith(error: AppException.from(e, s));
    } finally {
      _busy = false;
    }
  }

  Future<void> togglePause() =>
      state.phase == StudioPhase.recording ? pause() : resume();

  /// Stops recording and persists a local draft. Returns the draft.
  Future<RecordingDraft?> finish() async {
    if (!state.isActive) return state.draft;
    if (_busy) return null;
    _busy = true;
    state = state.copyWith(phase: StudioPhase.finishing);
    try {
      return await _stopAndSave();
    } catch (e, s) {
      if (ref.mounted) {
        state = state.copyWith(
          phase: StudioPhase.failed,
          error: AppException.from(e, s),
        );
      }
      return null;
    } finally {
      _busy = false;
    }
  }

  Future<RecordingDraft?> _stopAndSave() async {
    _stopObservers();
    _timer.stop();
    final duration = _timer.elapsed;
    final path = await _recorder.stop() ?? _path;
    _sessionActive = false;
    if (path == null) {
      throw const AppException(
        AppErrorKind.unexpected,
        'The recording could not be saved. Please try again.',
      );
    }
    if (duration < const Duration(seconds: 1)) {
      await _drafts.delete(_draftId!);
      throw const AppException.validation(
        'That recording was too short to keep.',
      );
    }
    final draft = await _drafts.saveNew(
      id: _draftId!,
      filePath: path,
      duration: duration,
      resubmissionOf: resubmissionOf,
    );
    if (ref.mounted) {
      state = state.copyWith(
        phase: StudioPhase.finished,
        elapsed: duration,
        draft: draft,
      );
      ref.invalidate(draftsProvider);
    }
    return draft;
  }

  /// Discards the in-progress recording (caller confirms with the user).
  Future<void> discard() async {
    if (_busy) return;
    _busy = true;
    try {
      _stopObservers();
      _timer.reset();
      if (_sessionActive) await _recorder.cancel();
      _sessionActive = false;
      final draftId = state.draft?.id ?? _draftId;
      if (draftId != null) await _drafts.delete(draftId);
      _draftId = null;
      _path = null;
      if (ref.mounted) {
        state = const StudioState(phase: StudioPhase.ready);
        ref.invalidate(draftsProvider);
      }
    } catch (e, s) {
      if (ref.mounted) state = state.copyWith(error: AppException.from(e, s));
    } finally {
      _busy = false;
    }
  }

  /// App lifecycle: the OS may stop background capture, so pause cleanly.
  void onAppBackgrounded() {
    if (state.phase == StudioPhase.recording) {
      pause(notice: 'Recording paused while the app was in the background.');
    }
  }

  void _onTick() {
    if (!ref.mounted) return;
    if (_timer.limitReached && state.phase == StudioPhase.recording) {
      state = state.copyWith(
        limitReached: true,
        elapsed: RecordingLimits.maxDuration,
      );
      finish();
      return;
    }
    if (state.phase == StudioPhase.recording) {
      state = state.copyWith(
        elapsed: _timer.elapsed,
        inputDb: _recorder.lastDb,
      );
    }
  }

  void _onLevel(double level) {
    if (!ref.mounted || state.phase != StudioPhase.recording) return;
    final next = [...state.levels, level];
    state = state.copyWith(
      levels: next.length > _bars ? next.sublist(next.length - _bars) : next,
    );
  }

  void _onSignal(RecorderSignal signal) {
    if (!ref.mounted) return;
    if (signal == RecorderSignal.pausedByInterruption &&
        state.phase == StudioPhase.recording) {
      _timer.pause();
      state = state.copyWith(
        phase: StudioPhase.paused,
        elapsed: _timer.elapsed,
        notice: 'Recording paused by an interruption. Tap resume when ready.',
      );
    }
  }

  void _stopObservers() {
    _ticker?.cancel();
    _ticker = null;
    _levelSub?.cancel();
    _levelSub = null;
    _signalSub?.cancel();
    _signalSub = null;
  }

  void _onDispose() {
    _stopObservers();
    // Leaving mid-session: keep the take as a recoverable draft instead of
    // losing it. The recorder service finalizes the file when it is disposed
    // (RecordPackageService.dispose stops before releasing).
    if (_sessionActive && _draftId != null && _path != null) {
      final duration = _timer.elapsed;
      if (duration >= const Duration(seconds: 1)) {
        unawaited(
          _drafts
              .saveNew(
                id: _draftId!,
                filePath: _path!,
                duration: duration,
                resubmissionOf: resubmissionOf,
              )
              .then<void>(
                (_) {},
                onError: (Object e, StackTrace s) => AppException.from(e, s),
              ),
        );
      }
    }
  }
}

final recordingStudioControllerProvider = NotifierProvider.autoDispose
    .family<RecordingStudioController, StudioState, String?>(
      RecordingStudioController.new,
    );
