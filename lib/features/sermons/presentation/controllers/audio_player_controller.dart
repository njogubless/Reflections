import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/media/media_storage.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/audio_playback_engine.dart';
import '../../data/datasources/listening_history_store.dart';
import '../../domain/entities/sermon.dart';
import '../providers/sermon_providers.dart';

class NowPlayingState {
  const NowPlayingState({
    this.sermon,
    this.playing = false,
    this.loading = false,
    this.completed = false,
    this.speed = 1.0,
    this.duration,
    this.sleepAt,
    this.error,
  });

  final Sermon? sermon;
  final bool playing;
  final bool loading;
  final bool completed;
  final double speed;
  final Duration? duration;
  final DateTime? sleepAt;
  final AppException? error;

  bool get hasMedia => sermon != null;

  NowPlayingState copyWith({
    Sermon? sermon,
    bool? playing,
    bool? loading,
    bool? completed,
    double? speed,
    Duration? duration,
    DateTime? sleepAt,
    bool clearSleep = false,
    AppException? error,
    bool clearError = false,
  }) => NowPlayingState(
    sermon: sermon ?? this.sermon,
    playing: playing ?? this.playing,
    loading: loading ?? this.loading,
    completed: completed ?? this.completed,
    speed: speed ?? this.speed,
    duration: duration ?? this.duration,
    sleepAt: clearSleep ? null : (sleepAt ?? this.sleepAt),
    error: clearError ? null : (error ?? this.error),
  );
}

final audioEngineProvider = Provider<AudioPlaybackEngine>((ref) {
  final engine = JustAudioEngine();
  ref.onDispose(engine.dispose);
  return engine;
});

/// Published-sermon playback. Entirely separate from the recording studio.
final audioPlayerControllerProvider =
    NotifierProvider<AudioPlayerController, NowPlayingState>(
      AudioPlayerController.new,
    );

final playbackPositionProvider = StreamProvider<Duration>(
  (ref) => ref.watch(audioEngineProvider).positionStream,
);

class AudioPlayerController extends Notifier<NowPlayingState> {
  static const speeds = [0.75, 1.0, 1.25, 1.5, 2.0];
  static const _persistEvery = Duration(seconds: 10);

  final _subs = <StreamSubscription<Object?>>[];
  Timer? _sleepTimer;
  DateTime _lastPersist = DateTime.fromMillisecondsSinceEpoch(0);
  int _loadToken = 0;

  AudioPlaybackEngine get _engine => ref.read(audioEngineProvider);

  @override
  NowPlayingState build() {
    final engine = ref.watch(audioEngineProvider);
    _subs
      ..add(
        engine.playingStream.listen((p) {
          state = state.copyWith(playing: p);
          if (!p) unawaited(_persist(force: true));
        }),
      )
      ..add(
        engine.stateStream.listen((s) {
          state = state.copyWith(
            loading: s == EngineState.loading,
            completed: s == EngineState.completed,
          );
        }),
      )
      ..add(
        engine.durationStream.listen((d) {
          if (d != null) state = state.copyWith(duration: d);
        }),
      )
      ..add(engine.positionStream.listen((_) => unawaited(_persist())))
      ..add(engine.becomingNoisy.listen((_) => pause()));

    // Session cleanup: stop playback when the user signs out.
    ref.listen(currentUserProvider, (prev, next) {
      if (prev != null && next == null) unawaited(stop());
    });

    ref.onDispose(() {
      for (final s in _subs) {
        s.cancel();
      }
      _subs.clear();
      _sleepTimer?.cancel();
    });
    return const NowPlayingState();
  }

  /// Loads and plays [sermon], resuming from saved progress.
  Future<void> playSermon(Sermon sermon) async {
    if (state.sermon?.id == sermon.id && !state.completed) {
      if (!state.playing) await resume();
      return;
    }
    if (!sermon.hasAudio) {
      state = state.copyWith(
        error: const AppException.notFound('This sermon has no audio yet.'),
      );
      return;
    }
    final token = ++_loadToken;
    await _persist(force: true);
    state = NowPlayingState(sermon: sermon, loading: true, speed: state.speed);
    try {
      final url = await ref
          .read(mediaStorageProvider)
          .downloadUrl(sermon.storagePath!);
      final user = ref.read(currentUserProvider);
      var start = Duration.zero;
      if (user != null) {
        start = await ref
            .read(listeningHistoryStoreProvider)
            .positionFor(user.uid, sermon.id);
      }
      if (token != _loadToken) return; // superseded by a newer request
      final duration = await _engine.load(url, initialPosition: start);
      if (duration != null && start >= duration - const Duration(seconds: 30)) {
        await _engine.seek(Duration.zero);
      }
      await _engine.setSpeed(state.speed);
      if (token != _loadToken) return;
      state = state.copyWith(duration: duration, loading: false);
      await _engine.play();
    } catch (e, s) {
      if (token != _loadToken) return;
      state = state.copyWith(
        loading: false,
        playing: false,
        error: AppException.from(e, s),
      );
    }
  }

  Future<void> resume() async {
    if (!state.hasMedia) return;
    if (state.completed) await _engine.seek(Duration.zero);
    await _engine.play();
  }

  Future<void> pause() => _engine.pause();

  Future<void> togglePlay() => state.playing ? pause() : resume();

  Future<void> seek(Duration position) => _engine.seek(position);

  Future<void> skip(Duration delta) async {
    final d = state.duration ?? Duration.zero;
    var target = _engine.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (d > Duration.zero && target > d) target = d;
    await _engine.seek(target);
  }

  Future<void> cycleSpeed() async {
    final i = speeds.indexOf(state.speed);
    final next = speeds[(i + 1) % speeds.length];
    await _engine.setSpeed(next);
    state = state.copyWith(speed: next);
  }

  /// Sleep timer: pauses playback after [after]; null cancels.
  void setSleepTimer(Duration? after) {
    _sleepTimer?.cancel();
    if (after == null) {
      state = state.copyWith(clearSleep: true);
      return;
    }
    _sleepTimer = Timer(after, () {
      pause();
      state = state.copyWith(clearSleep: true);
    });
    state = state.copyWith(sleepAt: DateTime.now().add(after));
  }

  Future<void> stop() async {
    _loadToken++;
    await _persist(force: true);
    _sleepTimer?.cancel();
    await _engine.stop();
    state = NowPlayingState(speed: state.speed);
  }

  void clearError() => state = state.copyWith(clearError: true);

  Future<void> _persist({bool force = false}) async {
    final sermon = state.sermon;
    final user = ref.read(currentUserProvider);
    final duration = state.duration;
    if (sermon == null || user == null || duration == null) return;
    final now = DateTime.now();
    if (!force && now.difference(_lastPersist) < _persistEvery) return;
    _lastPersist = now;
    try {
      await ref
          .read(listeningHistoryStoreProvider)
          .save(
            user.uid,
            ListeningProgress(
              sermonId: sermon.id,
              title: sermon.title,
              speakerName: sermon.speakerName,
              scriptureReference: sermon.scriptureReference,
              position: _engine.position,
              duration: duration,
              updatedAt: now,
            ),
          );
    } catch (e, s) {
      // Progress is a convenience; log and continue playback.
      AppException.from(e, s);
    }
  }
}
