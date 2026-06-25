import 'package:cloud_firestore/cloud_firestore.dart';

List<Map<String, dynamic>> asMapList(Object? value) {
  if (value is! List) return const [];
  return value.whereType<Map>().map((entry) {
    return entry.map((key, value) => MapEntry(key.toString(), value));
  }).toList();
}

Map<String, dynamic> asStringMap(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, value) => MapEntry(key.toString(), value));
}

String? asNestedString(Object? value, String key) {
  return asNonEmptyString(asStringMap(value)[key]);
}

String? asNonEmptyString(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int? asInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

bool? asBool(Object? value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value.toString().trim().toLowerCase();
  if (text == 'true' || text == '1' || text == 'yes' || text == 'ja') {
    return true;
  }
  if (text == 'false' || text == '0' || text == 'no' || text == 'nei') {
    return false;
  }
  return null;
}

DateTime? asDateTime(Object? value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

int compareNullableDateDesc(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return b.compareTo(a);
}
