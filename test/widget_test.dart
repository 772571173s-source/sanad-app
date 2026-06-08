import 'package:flutter_test/flutter_test.dart';
import 'package:sanad_app/main.dart';

void main() {
  testWidgets('Sanad app starts', (tester) async {
    await tester.pumpWidget(const SanadApp());

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    final loading = find.text('جار تجهيز النظام...').evaluate().isNotEmpty;
    final login = find.text('تسجيل الدخول').evaluate().isNotEmpty;
    final setup = find.text('إعداد سند لأول مرة').evaluate().isNotEmpty;

    expect(loading || login || setup, isTrue,
        reason:
            'المشروع يجب أن يظهر إحدى الحالات: تحميل، تسجيل دخول، أو إعداد أولي');
  });
}
