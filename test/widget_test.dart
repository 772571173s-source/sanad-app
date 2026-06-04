import 'package:flutter_test/flutter_test.dart';
import 'package:sanad_app/main.dart';

void main() {
  testWidgets('Sanad app starts at login screen', (tester) async {
    await tester.pumpWidget(const SanadApp());
    await tester.pump();

    expect(find.text('تسجيل الدخول'), findsOneWidget);
  });
}
