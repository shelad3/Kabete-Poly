import 'package:kabete2026eiteet/models/feature_flag.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FeatureFlag.fromJson timestamp parsing', () {
    test('parses Timestamp values in schedule fields', () {
      final when = DateTime(2026, 6, 1, 10, 30);
      final flag = FeatureFlag.fromJson({
        'name': 'voting',
        'displayName': 'Voting',
        'enabled': true,
        'schedule': {
          'autoDisableAt': Timestamp.fromDate(when),
        },
      }, 'voting');

      expect(flag.autoDisableAt, when);
      expect(flag.autoEnableAt, isNull);
    });

    test('parses ISO-8601 String values in schedule fields', () {
      final flag = FeatureFlag.fromJson({
        'name': 'voting',
        'displayName': 'Voting',
        'enabled': true,
        'schedule': {
          'autoDisableAt': '2026-06-01T10:30:00.000Z',
        },
      }, 'voting');

      expect(flag.autoDisableAt, isNotNull);
      expect(flag.autoDisableAt!.toUtc().year, 2026);
      expect(flag.autoDisableAt!.toUtc().month, 6);
    });

    test('handles null or missing schedule without crashing', () {
      final flag = FeatureFlag.fromJson({
        'name': 'quiz',
        'displayName': 'Quiz',
        'enabled': true,
      }, 'quiz');

      expect(flag.autoDisableAt, isNull);
      expect(flag.autoEnableAt, isNull);
    });

    test('parses created/lastModified timestamps', () {
      final created = DateTime(2026, 6, 1);
      final flag = FeatureFlag.fromJson({
        'name': 'voting',
        'displayName': 'Voting',
        'enabled': true,
        'createdAt': Timestamp.fromDate(created),
      }, 'voting');

      expect(flag.createdAt, created);
    });
  });

  group('FeatureFlag.isEffectivelyEnabled', () {
    test('disabled when autoDisableAt has passed', () {
      final flag = FeatureFlag.fromJson({
        'name': 'voting',
        'displayName': 'Voting',
        'enabled': true,
        'schedule': {
          'autoDisableAt': '2000-01-01T00:00:00.000Z',
        },
      }, 'voting');

      expect(flag.isEffectivelyEnabled, isFalse);
    });

    test('enabled in the future after autoEnableAt', () {
      final flag = FeatureFlag.fromJson({
        'name': 'voting',
        'displayName': 'Voting',
        'enabled': false,
        'schedule': {
          'autoEnableAt': '2000-01-01T00:00:00.000Z',
        },
      }, 'voting');

      expect(flag.isEffectivelyEnabled, isTrue);
    });

    test('falls back to enabled when no schedule', () {
      final flag = FeatureFlag.fromJson({
        'name': 'voting',
        'displayName': 'Voting',
        'enabled': true,
      }, 'voting');

      expect(flag.isEffectivelyEnabled, isTrue);
    });
  });
}
