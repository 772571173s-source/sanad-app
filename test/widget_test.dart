import 'package:flutter_test/flutter_test.dart';
import 'package:sanad_app/main.dart';

void main() {
  testWidgets('Sanad app starts', (tester) async {
    await tester.pumpWidget(const SanadApp());
    await tester.pump(const Duration(milliseconds: 300));

    final login = find.text('تسجيل الدخول').evaluate().isNotEmpty;
    final setup = find.text('إعداد سند لأول مرة').evaluate().isNotEmpty;
    expect(login || setup, isTrue);
  });
}
