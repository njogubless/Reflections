import 'package:clock/clock.dart';

/// Monotonic elapsed-time tracker for a recording session that supports
/// pause/resume. UI ticks only *read* this; they never accumulate time, so
/// dropped frames cannot skew the recorded duration.
class RecordingTimer {
  RecordingTimer({this.limit = const Duration(seconds: 1200)});

  final Duration limit;
  final Stopwatch _watch = clock.stopwatch();

  Duration get elapsed => _watch.elapsed > limit ? limit : _watch.elapsed;
  Duration get remaining => limit - elapsed;
  bool get isRunning => _watch.isRunning;
  bool get limitReached => _watch.elapsed >= limit;

  void start() {
    _watch
      ..reset()
      ..start();
  }

  void pause() => _watch.stop();
  void resume() => _watch.start();

  void stop() => _watch.stop();

  void reset() {
    _watch
      ..stop()
      ..reset();
  }
}
