import 'package:flutter_test/flutter_test.dart';
import 'package:sanad_app/models/app_models.dart';
import 'package:sanad_app/models/assessment_improvement_summary.dart';

void main() {
  group('تقييم واحد فقط → hasEnoughData = false', () {
    test('قائمة تقييمات فارغة', () {
      final result = AssessmentImprovementSummary.compute(
        'student_1', [], {},
      );
      expect(result.hasEnoughData, isFalse);
    });

    test('تقييم واحد فقط', () {
      final assessments = [
        ClinicalAssessment(
          id: 'a1', centerId: 'c1', studentId: 'student_1',
          specialistId: 's1', specialistName: 'أخصائي',
          type: 'speech',
          strengthsSummary: '', weaknessesSummary: '',
          goalsSummary: '', trainingSummary: '',
          createdAt: '2026-01-01',
        ),
      ];
      final result = AssessmentImprovementSummary.compute(
        'student_1', assessments, {},
      );
      expect(result.hasEnoughData, isFalse);
    });
  });

  group('تقييمان: 6 من 10 تحسنت', () {
    test('improvementRate = 60%', () {
      // السابق: 10 نقاط ضعف (templateId: t1..t10)
      // الحالي: t1..t6 طبيعي, t7..t10 ضعف
      final prevFindings = List.generate(10, (i) => ClinicalFinding(
        id: 'pf${i+1}', assessmentId: 'a1', centerId: 'c1',
        studentId: 'student_1',
        domain: 'نطق', itemTitle: 'بند ${i+1}', result: 'ضعف',
        isNormal: false,
        templateId: 't${i+1}',
      ));
      final currFindings = [
        for (var i = 0; i < 6; i++)
          ClinicalFinding(
            id: 'cf${i+1}', assessmentId: 'a2', centerId: 'c1',
            studentId: 'student_1',
            domain: 'نطق', itemTitle: 'بند ${i+1}', result: 'طبيعي',
            isNormal: true,
            templateId: 't${i+1}',
          ),
        for (var i = 6; i < 10; i++)
          ClinicalFinding(
            id: 'cf${i+1}', assessmentId: 'a2', centerId: 'c1',
            studentId: 'student_1',
            domain: 'نطق', itemTitle: 'بند ${i+1}', result: 'ضعف',
            isNormal: false,
            templateId: 't${i+1}',
          ),
      ];

      final assessments = [
        ClinicalAssessment(
          id: 'a1', centerId: 'c1', studentId: 'student_1',
          specialistId: 's1', specialistName: 'أخصائي',
          type: 'speech',
          strengthsSummary: '', weaknessesSummary: '',
          goalsSummary: '', trainingSummary: '',
          createdAt: '2026-01-01',
        ),
        ClinicalAssessment(
          id: 'a2', centerId: 'c1', studentId: 'student_1',
          specialistId: 's1', specialistName: 'أخصائي',
          type: 'speech',
          strengthsSummary: '', weaknessesSummary: '',
          goalsSummary: '', trainingSummary: '',
          createdAt: '2026-06-01',
        ),
      ];

      final findingsByAssessment = {
        'a1': prevFindings,
        'a2': currFindings,
      };

      final result = AssessmentImprovementSummary.compute(
        'student_1', assessments, findingsByAssessment,
      );

      print('══════ 6 من 10 تحسنت ══════');
      print('baseWeaknessCount: ${result.baseWeaknessCount}');
      print('improvedCount:     ${result.improvedCount}');
      print('improvementRate:   ${result.improvementRate}');
      print('unchangedWeakness: ${result.unchangedWeaknessCount}');
      print('regressionCount:   ${result.regressionCount}');
      print('newFindingCount:   ${result.newFindingCount}');
      print('missingCount:      ${result.missingCount}');
      print('stableNormalCount: ${result.stableNormalCount}');

      expect(result.hasEnoughData, isTrue);
      expect(result.baseWeaknessCount, equals(10));
      expect(result.improvedCount, equals(6));
      expect(result.unchangedWeaknessCount, equals(4));
      expect(result.regressionCount, equals(0));
      expect(result.newFindingCount, equals(0));
      expect(result.missingCount, equals(0));
      expect(result.stableNormalCount, equals(0));

      // 6/10 = 60%
      expect((result.improvementRate - 60).abs(), lessThan(0.01));
    });
  });

  group('تقييمان: طبيعي سابق ← ضعف حالي (regression)', () {
    test('regression لا يدخل في improvementRate', () {
      // السابق: t1 طبيعي, t2 ضعف
      // الحالي: t1 ضعف (regression), t2 طبيعي (improved)
      final prevFindings = [
        ClinicalFinding(
          id: 'pf1', assessmentId: 'a1', centerId: 'c1',
          studentId: 'student_1',
          domain: 'نطق', itemTitle: 'بند 1', result: 'طبيعي',
          isNormal: true, templateId: 't1',
        ),
        ClinicalFinding(
          id: 'pf2', assessmentId: 'a1', centerId: 'c1',
          studentId: 'student_1',
          domain: 'نطق', itemTitle: 'بند 2', result: 'ضعف',
          isNormal: false, templateId: 't2',
        ),
      ];
      final currFindings = [
        ClinicalFinding(
          id: 'cf1', assessmentId: 'a2', centerId: 'c1',
          studentId: 'student_1',
          domain: 'نطق', itemTitle: 'بند 1', result: 'ضعف',
          isNormal: false, templateId: 't1',
        ),
        ClinicalFinding(
          id: 'cf2', assessmentId: 'a2', centerId: 'c1',
          studentId: 'student_1',
          domain: 'نطق', itemTitle: 'بند 2', result: 'طبيعي',
          isNormal: true, templateId: 't2',
        ),
      ];

      final assessments = [
        ClinicalAssessment(
          id: 'a1', centerId: 'c1', studentId: 'student_1',
          specialistId: 's1', specialistName: 'أخصائي',
          type: 'speech',
          strengthsSummary: '', weaknessesSummary: '',
          goalsSummary: '', trainingSummary: '',
          createdAt: '2026-01-01',
        ),
        ClinicalAssessment(
          id: 'a2', centerId: 'c1', studentId: 'student_1',
          specialistId: 's1', specialistName: 'أخصائي',
          type: 'speech',
          strengthsSummary: '', weaknessesSummary: '',
          goalsSummary: '', trainingSummary: '',
          createdAt: '2026-06-01',
        ),
      ];

      final findingsByAssessment = {
        'a1': prevFindings,
        'a2': currFindings,
      };

      final result = AssessmentImprovementSummary.compute(
        'student_1', assessments, findingsByAssessment,
      );

      print('══════ regression ══════');
      print('baseWeaknessCount: ${result.baseWeaknessCount}');
      print('improvedCount:     ${result.improvedCount}');
      print('improvementRate:   ${result.improvementRate}');
      print('regressionCount:   ${result.regressionCount}');

      expect(result.hasEnoughData, isTrue);
      // t2 كانت ضعف وتحسنت → 1, t1 كانت طبيعي
      expect(result.baseWeaknessCount, equals(1));
      expect(result.improvedCount, equals(1));
      expect(result.regressionCount, equals(1));

      // improvementRate = 1/1 = 100%
      expect((result.improvementRate - 100).abs(), lessThan(0.01));
    });
  });

  group('بند جديد في الحالي فقط (newFinding)', () {
    test('newFinding لا يدخل في improvementRate', () {
      // السابق: t1 ضعف
      // الحالي: t1 ضعف, t3 جديد ضعف
      final prevFindings = [
        ClinicalFinding(
          id: 'pf1', assessmentId: 'a1', centerId: 'c1',
          studentId: 'student_1',
          domain: 'نطق', itemTitle: 'بند 1', result: 'ضعف',
          isNormal: false, templateId: 't1',
        ),
      ];
      final currFindings = [
        ClinicalFinding(
          id: 'cf1', assessmentId: 'a2', centerId: 'c1',
          studentId: 'student_1',
          domain: 'نطق', itemTitle: 'بند 1', result: 'ضعف',
          isNormal: false, templateId: 't1',
        ),
        ClinicalFinding(
          id: 'cf3', assessmentId: 'a2', centerId: 'c1',
          studentId: 'student_1',
          domain: 'نطق', itemTitle: 'بند 3', result: 'ضعف',
          isNormal: false, templateId: 't3',
        ),
      ];

      final assessments = [
        ClinicalAssessment(
          id: 'a1', centerId: 'c1', studentId: 'student_1',
          specialistId: 's1', specialistName: 'أخصائي',
          type: 'speech',
          strengthsSummary: '', weaknessesSummary: '',
          goalsSummary: '', trainingSummary: '',
          createdAt: '2026-01-01',
        ),
        ClinicalAssessment(
          id: 'a2', centerId: 'c1', studentId: 'student_1',
          specialistId: 's1', specialistName: 'أخصائي',
          type: 'speech',
          strengthsSummary: '', weaknessesSummary: '',
          goalsSummary: '', trainingSummary: '',
          createdAt: '2026-06-01',
        ),
      ];

      final findingsByAssessment = {
        'a1': prevFindings,
        'a2': currFindings,
      };

      final result = AssessmentImprovementSummary.compute(
        'student_1', assessments, findingsByAssessment,
      );

      print('══════ newFinding ══════');
      print('baseWeaknessCount: ${result.baseWeaknessCount}');
      print('improvedCount:     ${result.improvedCount}');
      print('newFindingCount:   ${result.newFindingCount}');

      expect(result.hasEnoughData, isTrue);
      expect(result.baseWeaknessCount, equals(1));
      expect(result.improvedCount, equals(0));
      expect(result.newFindingCount, equals(1));
      expect(result.unchangedWeaknessCount, equals(1));
    });
  });

  group('بند كان ضعف في السابق ومفقود في الحالي (missing)', () {
    test('missing لا يعتبر تحسنًا', () {
      // السابق: t1 ضعف, t2 طبيعي
      // الحالي: t2 طبيعي (t1 مفقود)
      final prevFindings = [
        ClinicalFinding(
          id: 'pf1', assessmentId: 'a1', centerId: 'c1',
          studentId: 'student_1',
          domain: 'نطق', itemTitle: 'بند 1', result: 'ضعف',
          isNormal: false, templateId: 't1',
        ),
        ClinicalFinding(
          id: 'pf2', assessmentId: 'a1', centerId: 'c1',
          studentId: 'student_1',
          domain: 'نطق', itemTitle: 'بند 2', result: 'طبيعي',
          isNormal: true, templateId: 't2',
        ),
      ];
      final currFindings = [
        ClinicalFinding(
          id: 'cf2', assessmentId: 'a2', centerId: 'c1',
          studentId: 'student_1',
          domain: 'نطق', itemTitle: 'بند 2', result: 'طبيعي',
          isNormal: true, templateId: 't2',
        ),
      ];

      final assessments = [
        ClinicalAssessment(
          id: 'a1', centerId: 'c1', studentId: 'student_1',
          specialistId: 's1', specialistName: 'أخصائي',
          type: 'speech',
          strengthsSummary: '', weaknessesSummary: '',
          goalsSummary: '', trainingSummary: '',
          createdAt: '2026-01-01',
        ),
        ClinicalAssessment(
          id: 'a2', centerId: 'c1', studentId: 'student_1',
          specialistId: 's1', specialistName: 'أخصائي',
          type: 'speech',
          strengthsSummary: '', weaknessesSummary: '',
          goalsSummary: '', trainingSummary: '',
          createdAt: '2026-06-01',
        ),
      ];

      final findingsByAssessment = {
        'a1': prevFindings,
        'a2': currFindings,
      };

      final result = AssessmentImprovementSummary.compute(
        'student_1', assessments, findingsByAssessment,
      );

      print('══════ missing (ضعف سابق مفقود) ══════');
      print('baseWeaknessCount: ${result.baseWeaknessCount}');
      print('improvedCount:     ${result.improvedCount}');
      print('missingCount:      ${result.missingCount}');
      print('improvementRate:   ${result.improvementRate}');

      expect(result.hasEnoughData, isTrue);
      // t1 كان ضعف ومفقود → يدخل baseWeaknessCount لكن ليس improved
      // t2 كان طبيعي ومازال طبيعي → stableNormal
      expect(result.baseWeaknessCount, equals(1));
      expect(result.improvedCount, equals(0));
      expect(result.missingCount, equals(1)); // t1 مفقود (كان ضعفًا)
      // t2 موجود → stableNormal
      expect(result.stableNormalCount, equals(1));
      expect(result.improvementRate, equals(0));
    });
  });
}
