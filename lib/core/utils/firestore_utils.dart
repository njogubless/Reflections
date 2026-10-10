import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? readDate(Object? value) => switch (value) {
  Timestamp t => t.toDate(),
  DateTime d => d,
  _ => null,
};

String readString(
  Map<String, dynamic> data,
  String key, [
  String fallback = '',
]) {
  final v = data[key];
  return v is String ? v : fallback;
}

String? readOptionalString(Map<String, dynamic> data, String key) {
  final v = data[key];
  return v is String && v.isNotEmpty ? v : null;
}

int readInt(Map<String, dynamic> data, String key, [int fallback = 0]) {
  final v = data[key];
  return v is num ? v.toInt() : fallback;
}

List<String> readStringList(Map<String, dynamic> data, String key) {
  final v = data[key];
  return v is List ? v.whereType<String>().toList() : const [];
}
