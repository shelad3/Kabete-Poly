/// Run: dart run tools/export_timetable_data.dart
/// Exports the hardcoded TimetableData.cohorts map to timetable_export.json
/// for migration to Firestore.

import 'dart:convert';
import 'dart:io';
import '../lib/utils/timetable_data.dart';

void main() {
  final json = jsonEncode(TimetableData.cohorts);
  final outFile = File('timetable_export.json');
  outFile.writeAsStringSync(json);
  final size = outFile.lengthSync();
  print('Exported TimetableData.cohorts (${size ~/ 1024} KB) to timetable_export.json');
}
