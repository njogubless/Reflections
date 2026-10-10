import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Last listened sermon for "Continue listening". Stored on-device per user.
class ListeningProgress {
  const ListeningProgress({
    required this.sermonId,
    required this.title,
    required this.speakerName,
    required this.scriptureReference,
    required this.position,
    required this.duration,
    required this.updatedAt,
  });

  final String sermonId;
  final String title;
  final String speakerName;
  final String scriptureReference;
  final Duration position;
  final Duration duration;
  final DateTime updatedAt;

  double get fraction => duration.inMilliseconds <= 0
      ? 0
      : (position.inMilliseconds / duration.inMilliseconds)
            .clamp(0, 1)
            .toDouble();

  Duration get remaining => duration - position;

  /// Treat the last 30 seconds as finished.
  bool get isFinished =>
      duration > Duration.zero && remaining < const Duration(seconds: 30);

  Map<String, dynamic> toJson() => {
    'sermonId': sermonId,
    'title': title,
    'speakerName': speakerName,
    'scriptureReference': scriptureReference,
    'positionMs': position.inMilliseconds,
    'durationMs': duration.inMilliseconds,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory ListeningProgress.fromJson(
    Map<String, dynamic> j,
  ) => ListeningProgress(
    sermonId: j['sermonId'] as String,
    title: j['title'] as String? ?? '',
    speakerName: j['speakerName'] as String? ?? '',
    scriptureReference: j['scriptureReference'] as String? ?? '',
    position: Duration(milliseconds: (j['positionMs'] as num?)?.toInt() ?? 0),
    duration: Duration(milliseconds: (j['durationMs'] as num?)?.toInt() ?? 0),
    updatedAt:
        DateTime.tryParse(j['updatedAt'] as String? ?? '') ?? DateTime.now(),
  );
}

class ListeningHistoryStore {
  ListeningHistoryStore(this._prefs);

  final SharedPreferencesAsync _prefs;

  String _key(String uid) => 'listening.last.$uid';
  String _posKey(String uid, String sermonId) => 'listening.pos.$uid.$sermonId';

  Future<ListeningProgress?> last(String uid) async {
    final raw = await _prefs.getString(_key(uid));
    if (raw == null) return null;
    try {
      return ListeningProgress.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } on FormatException {
      await _prefs.remove(_key(uid));
      return null;
    }
  }

  Future<Duration> positionFor(String uid, String sermonId) async {
    final ms = await _prefs.getInt(_posKey(uid, sermonId));
    return Duration(milliseconds: ms ?? 0);
  }

  Future<void> save(String uid, ListeningProgress p) async {
    await _prefs.setString(_key(uid), jsonEncode(p.toJson()));
    await _prefs.setInt(_posKey(uid, p.sermonId), p.position.inMilliseconds);
  }
}
