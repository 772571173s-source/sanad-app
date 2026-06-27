import 'package:flutter_test/flutter_test.dart';

import '../lib/models/word_report_model.dart';
import '../lib/services/word_report_service.dart';

void main() {
  test('WordReportService.generateBytes returns non-empty bytes', () {
    final model = WordReportModel(
      centerName: 'مركز سند التجريبي',
      studentName: 'طالب تجريبي',
      dateRange: 'التقرير الربع سنوي - الربع الأول - 2026',
      sections: [
        WordReportSection(
          sectionTitle: 'بيانات الجلسات',
          rows: [
            WordReportRow(cells: [
              'نوع الخدمة',
              'مجال المهارة',
              'الهدف',
              '1',
              '2',
              '3',
              'مقدم الخدمة',
            ]),
            WordReportRow(cells: [
              'علاج نطق',
              'مخارج حروف',
              'نطق حرف الراء',
              '0',
              '1',
              '2',
              'أ. أحمد',
            ]),
            WordReportRow(cells: [
              'علاج وظيفي',
              'مهارات حركية',
              'المشي على خط مستقيم',
              '1',
              '2',
              '',
              'أ. سارة',
            ]),
            WordReportRow(cells: [
              'علاج سلوكي',
              'تواصل',
              'طلب المساعدة',
              '0',
              '',
              '',
              'أ. خالد',
            ]),
          ],
        ),
        WordReportSection(
          sectionTitle: 'ملاحظات',
          rows: [
            WordReportRow(cells: [
              'تم تحقيق تقدم ملحوظ في جلسات النطق.',
            ]),
          ],
        ),
      ],
    );

    final bytes = WordReportService.generateBytes(model);
    expect(bytes, isNotEmpty);
    expect(bytes.length, greaterThan(100));
  });

  test('WordReportService.generateBytes with minimal model', () {
    final model = WordReportModel(
      centerName: 'مركز',
      studentName: 'طالب',
      dateRange: 'التقرير',
      sections: [],
    );

    final bytes = WordReportService.generateBytes(model);
    expect(bytes, isNotEmpty);
  });
}
