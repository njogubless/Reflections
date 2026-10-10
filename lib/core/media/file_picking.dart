import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../errors/app_exception.dart';
import '../utils/formatters.dart';

enum PickKind {
  audio({
    'mp3': 'audio/mpeg',
    'm4a': 'audio/mp4',
    'aac': 'audio/aac',
    'wav': 'audio/wav',
    'ogg': 'audio/ogg',
  }, 200 * 1024 * 1024),
  image({
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  }, 5 * 1024 * 1024),
  pdf({'pdf': 'application/pdf'}, 50 * 1024 * 1024);

  const PickKind(this.types, this.maxBytes);

  /// Allowed extension -> MIME type. Must match storage.rules.
  final Map<String, String> types;
  final int maxBytes;
}

class PickedLocalFile {
  const PickedLocalFile(this.file, this.name, this.sizeBytes, this.contentType);

  final File file;
  final String name;
  final int sizeBytes;
  final String contentType;
}

/// Validates a picked file's extension and size for [kind].
/// Pure; used by [pickLocalFile] and unit tests.
String validatePick(
  PickKind kind, {
  required String name,
  required int sizeBytes,
}) {
  final dot = name.lastIndexOf('.');
  final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  final type = kind.types[ext];
  if (type == null) {
    throw AppException.validation(
      'Unsupported file type. Choose a ${kind.types.keys.map((e) => '.$e').join(', ')} file.',
    );
  }
  if (sizeBytes <= 0) {
    throw const AppException.validation('That file is empty.');
  }
  if (sizeBytes > kind.maxBytes) {
    throw AppException.validation(
      'That file is too large (max ${formatBytes(kind.maxBytes)}).',
    );
  }
  return type;
}

/// Opens the system picker. Returns null if the user cancels.
Future<PickedLocalFile?> pickLocalFile(PickKind kind) async {
  final PlatformFile? picked;
  try {
    picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: kind.types.keys.toList(),
    );
  } catch (e, s) {
    throw AppException.from(e, s);
  }
  if (picked == null) return null;
  final size = picked.lengthSync() ?? await picked.length() ?? 0;
  final type = validatePick(kind, name: picked.name, sizeBytes: size);

  final path = picked.path;
  if (path != null) return PickedLocalFile(File(path), picked.name, size, type);

  // Content URIs (Android SAF): copy into a temp file for resumable upload.
  final tmp = await getTemporaryDirectory();
  final out = File(
    '${tmp.path}/upload_${DateTime.now().microsecondsSinceEpoch}_${picked.name}',
  );
  final sink = out.openWrite();
  await sink.addStream(picked.readAsByteStream());
  await sink.close();
  return PickedLocalFile(out, picked.name, size, type);
}

/// Reads an audio file's duration without playing it.
Future<Duration?> probeAudioDuration(File file) async {
  final player = AudioPlayer();
  try {
    return await player.setFilePath(file.path);
  } catch (e, s) {
    throw AppException(
      AppErrorKind.validation,
      'This audio file could not be read. It may be corrupt or in an unsupported format.',
      cause: AppException.from(e, s),
    );
  } finally {
    await player.dispose();
  }
}
