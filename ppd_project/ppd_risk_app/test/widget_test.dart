import 'package:flutter_test/flutter_test.dart';

import 'package:ppd_risk_app/main.dart';

void main() {
  testWidgets('Splash screen renders the app name', (WidgetTester tester) async {
    await tester.pumpWidget(const PpdRiskApp());
    await tester.pump();
    expect(find.text('MotherWell'), findsOneWidget);
  });
}
