import 'package:flutter_test/flutter_test.dart';

import '../lib/models/word_report_model.dart';
import '../lib/services/word_report_service.dart';
import '../lib/services/center_quarterly_data_builder.dart';

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

  group('monthsForReportPeriod', () {
    test('period 1 => [1,2,3,4]', () {
      expect(CenterQuarterlyDataBuilder.monthsForReportPeriod(1), [1, 2, 3, 4]);
    });

    test('period 2 => [5,6,7]', () {
      expect(CenterQuarterlyDataBuilder.monthsForReportPeriod(2), [5, 6, 7]);
    });

    test('period 3 => [8,9,10]', () {
      expect(CenterQuarterlyDataBuilder.monthsForReportPeriod(3), [8, 9, 10]);
    });

    test('period 4 => [11,12]', () {
      expect(CenterQuarterlyDataBuilder.monthsForReportPeriod(4), [11, 12]);
    });

    test('invalid period defaults to [1,2,3,4]', () {
      expect(CenterQuarterlyDataBuilder.monthsForReportPeriod(0), [1, 2, 3, 4]);
      expect(CenterQuarterlyDataBuilder.monthsForReportPeriod(5), [1, 2, 3, 4]);
    });
  });

  group('CenterQuarterlyDataBuilder helpers', () {
    test('quickResultToScore متقن => 2', () {
      expect(CenterQuarterlyDataBuilder.quickResultToScore('متقن'), '2');
    });

    test('quickResultToScore بمساعدة => 1', () {
      expect(CenterQuarterlyDataBuilder.quickResultToScore('بمساعدة'), '1');
    });

    test('quickResultToScore خطأ => 0', () {
      expect(CenterQuarterlyDataBuilder.quickResultToScore('خطأ'), '0');
    });

    test('quickResultToScore يحتاج إعادة => 0', () {
      expect(CenterQuarterlyDataBuilder.quickResultToScore('يحتاج إعادة'), '0');
    });

    test('quickResultToScore لم يبدأ => 0', () {
      expect(CenterQuarterlyDataBuilder.quickResultToScore('لم يبدأ'), '0');
    });

    test('quickResultToScore unknown => empty string', () {
      expect(CenterQuarterlyDataBuilder.quickResultToScore('غير معروف'), '');
    });

    test('quickResultToScore empty => empty string', () {
      expect(CenterQuarterlyDataBuilder.quickResultToScore(''), '');
    });
  });
}
