// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:flutter_test/flutter_test.dart';
import 'package:kabete2026eiteet/services/update_service.dart';

void main() {
  group('UpdateService.isDirectApk', () {
    test('accepts GitHub release asset URLs ending in .apk', () {
      expect(
        UpdateService.isDirectApk(
          'https://github.com/shelad3/Kabete-Poly/releases/download/'
          'v2.9.0%2B1/app-release.apk',
        ),
        isTrue,
      );
    });

    test('accepts plain https URLs ending in .apk', () {
      expect(
        UpdateService.isDirectApk('https://example.com/files/app.apk'),
        isTrue,
      );
    });

    test('accepts .apk with query parameters', () {
      expect(
        UpdateService.isDirectApk(
          'https://example.com/app.apk?token=abc123',
        ),
        isTrue,
      );
    });

    test('rejects release page URLs that serve HTML', () {
      expect(
        UpdateService.isDirectApk(
          'https://github.com/shelad3/Kabete-Poly/releases/latest',
        ),
        isFalse,
      );
      expect(
        UpdateService.isDirectApk(
          'https://github.com/shelad3/Kabete-Poly/releases/tag/v2.9.0%2B1',
        ),
        isFalse,
      );
    });

    test('rejects non-apk file extensions', () {
      expect(UpdateService.isDirectApk('https://example.com/app.zip'), isFalse);
      expect(UpdateService.isDirectApk('https://example.com/app.html'), isFalse);
      expect(UpdateService.isDirectApk('https://example.com/app-release.aab'),
          isFalse);
    });

    test('rejects empty and malformed URLs', () {
      expect(UpdateService.isDirectApk(''), isFalse);
      expect(UpdateService.isDirectApk('not a url'), isFalse);
      expect(UpdateService.isDirectApk('https://'), isFalse);
    });

    test('is case-insensitive on the extension', () {
      expect(UpdateService.isDirectApk('https://example.com/APP.APK'), isTrue);
    });
  });
}
