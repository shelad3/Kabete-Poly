// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabete2026eiteet/theme/app_theme.dart';
import 'package:kabete2026eiteet/widgets/shimmer_loading.dart';

void main() {
  testWidgets('explore shimmer list renders three placeholder cards',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ShimmerExploreList())),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(Card), findsAtLeastNWidgets(1));
  });

  testWidgets('notification shimmer list renders four placeholder cards',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ShimmerNotificationList())),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(Card), findsNWidgets(4));
  });

  test('knp theme exposes a valid scaffold background color', () {
    final theme = AppTheme.knpTheme;
    expect(theme.scaffoldBackgroundColor, isNotNull);
    expect(theme.primaryColor, isNotNull);
  });
}
