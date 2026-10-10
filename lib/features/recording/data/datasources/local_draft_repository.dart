import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/recording_draft.dart';
import '../../domain/repositories/recording_repositories.dart';

/// Stores each draft as `<dir>/<id>.m4a` + `<dir>/<id>.json`.
class LocalDraftRepository implements DraftRepository {
  LocalDraftRepository(this._dirFuture);

  /// Resolved lazily (path_provider) and scoped per user by the provider.
  final Future<Directory> _dirFuture;

  Future<Directory> get _dir async {
    final d = await _dirFuture;
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<File> _meta(String id) async => File('${(await _dir).path}/$id.json');

  @override
  Future<String> newRecordingPath(String draftId) async =>
      '${(await _dir).path}/$draftId.m4a';

  @override
  Future<RecordingDraft> saveNew({
    required String id,
    required String filePath,
    required Duration duration,
    String? resubmissionOf,
  }) async {
    if (!await File(filePath).exists()) {
      throw const AppException(
        AppErrorKind.unexpected,
        'The recording could not be saved. Please try again.',
      );
    }
    final now = clock.now();
    final draft = RecordingDraft(
      id: id,
      filePath: filePath,
      duration: duration,
      createdAt: now,
      updatedAt: now,
      resubmissionOf: resubmissionOf,
    );
    await _write(draft);
    return draft;
  }

  @override
  Future<void> update(RecordingDraft draft) =>
      _write(draft.copyWith(updatedAt: clock.now()));

  Future<void> _write(RecordingDraft draft) async {
    final f = await _meta(draft.id);
    // Write-then-rename so a crash never leaves a truncated JSON file.
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(draft.toJson()), flush: true);
    await tmp.rename(f.path);
  }

  @override
  Future<List<RecordingDraft>> list() async {
    final dir = await _dir;
    final drafts = <RecordingDraft>[];
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final d = RecordingDraft.fromJson(
          jsonDecode(await entity.readAsString()) as Map<String, dynamic>,
        );
        if (await File(d.filePath).exists()) {
          drafts.add(d);
        } else {
          await entity.delete(); // orphaned metadata
        }
      } on Object catch (e, s) {
        // Corrupt metadata: report and skip rather than fail the whole list.
        AppException.from(e, s);
      }
    }
    drafts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return drafts;
  }

  @override
  Future<RecordingDraft?> get(String id) async {
    final f = await _meta(id);
    if (!await f.exists()) return null;
    final d = RecordingDraft.fromJson(
      jsonDecode(await f.readAsString()) as Map<String, dynamic>,
    );
    return await File(d.filePath).exists() ? d : null;
  }

  @override
  Future<void> delete(String id) async {
    final dir = await _dir;
    for (final name in ['$id.json', '$id.m4a']) {
      final f = File('${dir.path}/$name');
      if (await f.exists()) await f.delete();
    }
  }
}
