import 'dart:async';
import 'dart:math' as math;

import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

enum MicPermission { granted, denied, permanentlyDenied }

enum RecorderSignal { pausedByInterruption, stopped }

/// Seam over the `record` package (keeps the studio controller testable).
abstract class AudioRecorderService {
  Future<MicPermission> checkPermission();
  Future<MicPermission> requestPermission();
  Future<void> openSettings();

  Future<void> start(String path);
  Future<void> pause();
  Future<void> resume();

  /// Finalizes the file and returns its path.
  Future<String?> stop();

  /// Stops and deletes the in-progress file.
  Future<void> cancel();

  /// Input level normalized to 0..1 (from dBFS).
  Stream<double> get levels;

  /// Last level in dBFS for the "Input gain" readout.
  double get lastDb;

  /// Platform-driven state changes (e.g. phone call paused the recorder).
  Stream<RecorderSignal> get signals;

  Future<void> dispose();
}

class RecordPackageService implements AudioRecorderService {
  RecordPackageService() : _recorder = AudioRecorder();

  /// AAC-LC 64 kbps mono: speech-appropriate; 20 min ≈ 9.6 MB, comfortably
  /// under the 25 MB Storage-rule cap.
  static const config = RecordConfig(
    encoder: AudioEncoder.aacLc,
    bitRate: 64000,
    sampleRate: 44100,
    numChannels: 1,
    noiseSuppress: true,
    audioInterruption: AudioInterruptionMode.pause,
  );

  final AudioRecorder _recorder;
  double _lastDb = -160;
  bool _expectPause = false;
  RecordState _state = RecordState.stop;

  @override
  Future<MicPermission> checkPermission() async =>
      _map(await Permission.microphone.status);

  @override
  Future<MicPermission> requestPermission() async =>
      _map(await Permission.microphone.request());

  MicPermission _map(PermissionStatus s) {
    if (s.isGranted || s.isLimited) return MicPermission.granted;
    if (s.isPermanentlyDenied || s.isRestricted) {
      return MicPermission.permanentlyDenied;
    }
    return MicPermission.denied;
  }

  @override
  Future<void> openSettings() async {
    await openAppSettings();
  }

  @override
  Future<void> start(String path) async {
    if (await _recorder.isRecording()) {
      throw StateError('A recording session is already active.');
    }
    await _recorder.start(config, path: path);
  }

  @override
  Future<void> pause() {
    _expectPause = true;
    return _recorder.pause();
  }

  @override
  Future<void> resume() => _recorder.resume();

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> cancel() => _recorder.cancel();

  @override
  Stream<double> get levels =>
      _recorder.onAmplitudeChanged(const Duration(milliseconds: 120)).map((a) {
        final db = a.current.isFinite ? a.current : -160.0;
        _lastDb = db;
        // Map -50 dBFS..0 dBFS onto 0..1 with a slight curve.
        final n = ((db + 50) / 50).clamp(0.0, 1.0);
        return math.pow(n, 1.4).toDouble();
      });

  @override
  double get lastDb => _lastDb;

  @override
  Stream<RecorderSignal> get signals => _recorder.onStateChanged().expand((s) {
    final prev = _state;
    _state = s;
    if (s == RecordState.pause && prev == RecordState.record) {
      final user = _expectPause;
      _expectPause = false;
      return user
          ? const <RecorderSignal>[]
          : const [RecorderSignal.pausedByInterruption];
    }
    if (s == RecordState.stop && prev != RecordState.stop) {
      return const [RecorderSignal.stopped];
    }
    return const <RecorderSignal>[];
  });

  @override
  Future<void> dispose() async {
    // Finalize any in-progress file so it remains playable as a draft.
    if (await _recorder.isRecording() || await _recorder.isPaused()) {
      await _recorder.stop();
    }
    await _recorder.dispose();
  }
}
