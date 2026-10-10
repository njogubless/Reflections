import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

enum EngineState { idle, loading, ready, completed }

/// Thin seam over just_audio so the player controller is testable.
abstract class AudioPlaybackEngine {
  Stream<bool> get playingStream;
  Stream<EngineState> get stateStream;
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;

  /// Fires when the OS asks us to pause (headphones unplugged, etc.).
  Stream<void> get becomingNoisy;

  Duration get position;

  Future<Duration?> load(
    String url, {
    Duration initialPosition = Duration.zero,
  });
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> stop();
  Future<void> dispose();
}

class JustAudioEngine implements AudioPlaybackEngine {
  JustAudioEngine() : _player = AudioPlayer() {
    _initSession();
  }

  final AudioPlayer _player;
  final _noisy = StreamController<void>.broadcast();
  StreamSubscription<void>? _noisySub;

  Future<void> _initSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    // just_audio pauses/resumes on interruptions (calls, other apps)
    // automatically once the session is configured.
    _noisySub = session.becomingNoisyEventStream.listen(_noisy.add);
  }

  @override
  Stream<bool> get playingStream => _player.playingStream;

  @override
  Stream<EngineState> get stateStream => _player.processingStateStream.map(
    (s) => switch (s) {
      ProcessingState.idle => EngineState.idle,
      ProcessingState.loading ||
      ProcessingState.buffering => EngineState.loading,
      ProcessingState.ready => EngineState.ready,
      ProcessingState.completed => EngineState.completed,
    },
  );

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Stream<void> get becomingNoisy => _noisy.stream;

  @override
  Duration get position => _player.position;

  @override
  Future<Duration?> load(
    String url, {
    Duration initialPosition = Duration.zero,
  }) => _player.setUrl(url, initialPosition: initialPosition);

  @override
  Future<void> play() async {
    final session = await AudioSession.instance;
    if (await session.setActive(true)) {
      // Don't await: completes only when playback stops.
      unawaited(_player.play());
    }
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() async {
    await _noisySub?.cancel();
    await _noisy.close();
    await _player.dispose();
  }
}
