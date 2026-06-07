import 'package:flutter_test/flutter_test.dart';
import 'package:kabete2026eiteet/main.dart';

void main() {
  testWidgets('App loads and shows login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const KabeteApp());
    expect(find.byType(KabeteApp), findsOneWidget);
  });
}
