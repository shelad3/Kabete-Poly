import 'package:kabete2026eiteet/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseLessonStartTime', () {
    test('parses HH:MM with colon', () {
      expect(parseLessonStartTime('08:30'), (8, 30));
    });

    test('parses HHMM with no colon', () {
      expect(parseLessonStartTime('1430'), (14, 30));
    });

    test('parses 24-hour evening times', () {
      expect(parseLessonStartTime('19:45'), (19, 45));
    });

    test('parses midnight as 00', () {
      expect(parseLessonStartTime('00:05'), (0, 5));
    });

    test('returns null for < 4 digits', () {
      expect(parseLessonStartTime('8:30'), isNull);
      expect(parseLessonStartTime(''), isNull);
    });

    test('returns null for non-numeric input', () {
      expect(parseLessonStartTime('abcd'), isNull);
    });
  });
}
