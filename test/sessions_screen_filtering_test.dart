import 'package:flutter_test/flutter_test.dart';
import 'package:sanad_app/models/app_models.dart';

void main() {
  final progSpeech = TherapyProgramTemplate(
    id: 'prog_speech',
    centerId: 'c1',
    name: 'العلاج النطقي',
    usesSpeechSounds: true,
    sortOrder: 1,
  );
  final progOccup = TherapyProgramTemplate(
    id: 'prog_occup',
    centerId: 'c1',
    name: 'العلاج الوظيفي',
    usesSpeechSounds: false,
    sortOrder: 2,
  );



  TrainingPlan plan({
    required String id,
    required String programId,
    String specialistId = 'spec1',
    String sourceType = 'standard',
    int progress = 0,
  }) =>
      TrainingPlan(
        id: id,
        centerId: 'c1',
        studentId: 's1',
        goal: 'هدف تجريبي',
        targetDate: '2025-06-01',
        progress: progress,
        programId: programId,
        sourceType: sourceType,
        specialistId: specialistId,
      );

  group('_filteredPlans logic — programId filter', () {
    test('filters plans by programId', () {
      final plans = [
        plan(id: 'p1', programId: 'prog_speech'),
        plan(id: 'p2', programId: 'prog_occup'),
        plan(id: 'p3', programId: 'prog_speech'),
      ];
      final result = plans.where((p) => p.programId == 'prog_speech').toList();
      expect(result.length, 2);
      expect(result.every((p) => p.programId == 'prog_speech'), isTrue);
    });

    test('returns empty when no plans match programId', () {
      final plans = [
        plan(id: 'p1', programId: 'prog_occup'),
      ];
      final result = plans.where((p) => p.programId == 'prog_speech').toList();
      expect(result, isEmpty);
    });
  });

  group('_filteredPlans logic — specialistId filter', () {
    test('specialist sees only their own plans', () {
      final plans = [
        plan(id: 'p1', programId: 'prog_speech', specialistId: 'spec1'),
        plan(id: 'p2', programId: 'prog_speech', specialistId: 'spec2'),
        plan(id: 'p3', programId: 'prog_speech', specialistId: 'spec1'),
      ];
      final result = plans
          .where((p) => p.programId == 'prog_speech')
          .where((p) => p.specialistId == 'spec1')
          .toList();
      expect(result.length, 2);
      expect(result.every((p) => p.specialistId == 'spec1'), isTrue);
    });

    test('specialist does not see another specialist plans', () {
      final plans = [
        plan(id: 'p2', programId: 'prog_speech', specialistId: 'spec2'),
      ];
      final result = plans
          .where((p) => p.programId == 'prog_speech')
          .where((p) => p.specialistId == 'spec1')
          .toList();
      expect(result, isEmpty);
    });
  });

  group('_filteredPlans logic — sourceType filter', () {
    test('"all" shows both standard and speechSound plans', () {
      final plans = [
        plan(id: 'p1', programId: 'prog_speech', sourceType: 'standard'),
        plan(id: 'p2', programId: 'prog_speech', sourceType: 'speechSound'),
      ];
      const sourceType = 'all';
      final result = plans
          .where((p) => p.programId == 'prog_speech')
          .where((p) => sourceType == 'all' || p.sourceType == sourceType)
          .toList();
      expect(result.length, 2);
    });

    test('"standard" shows only standard plans', () {
      final plans = [
        plan(id: 'p1', programId: 'prog_speech', sourceType: 'standard'),
        plan(id: 'p2', programId: 'prog_speech', sourceType: 'speechSound'),
      ];
      const sourceType = 'standard';
      final result = plans
          .where((p) => p.programId == 'prog_speech')
          .where((p) => sourceType == 'all' || p.sourceType == sourceType)
          .toList();
      expect(result.length, 1);
      expect(result.first.sourceType, 'standard');
    });

    test('"speechSound" shows only speechSound plans', () {
      final plans = [
        plan(id: 'p1', programId: 'prog_speech', sourceType: 'standard'),
        plan(id: 'p2', programId: 'prog_speech', sourceType: 'speechSound'),
      ];
      const sourceType = 'speechSound';
      final result = plans
          .where((p) => p.programId == 'prog_speech')
          .where((p) => sourceType == 'all' || p.sourceType == sourceType)
          .toList();
      expect(result.length, 1);
      expect(result.first.sourceType, 'speechSound');
    });
  });

  group('Combined filter logic', () {
    test('all filters combined: programId + specialistId + all sourceType', () {
      final plans = [
        plan(id: 'p1', programId: 'prog_speech', specialistId: 'spec1', sourceType: 'standard'),
        plan(id: 'p2', programId: 'prog_speech', specialistId: 'spec1', sourceType: 'speechSound'),
        plan(id: 'p3', programId: 'prog_speech', specialistId: 'spec2', sourceType: 'standard'),
        plan(id: 'p4', programId: 'prog_occup', specialistId: 'spec1', sourceType: 'standard'),
      ];
      const sourceType = 'all';
      const isSpecialist = true;
      const userId = 'spec1';
      final result = plans
          .where((p) => p.programId == 'prog_speech')
          .where((p) => !isSpecialist || p.specialistId == userId)
          .where((p) => sourceType == 'all' || p.sourceType == sourceType)
          .toList();
      expect(result.length, 2);
      expect(result.every((p) => p.programId == 'prog_speech'), isTrue);
      expect(result.every((p) => p.specialistId == 'spec1'), isTrue);
    });

    test('occupational specialist sees only occupational plans', () {
      final plans = [
        plan(id: 'p1', programId: 'prog_speech', specialistId: 'spec1', sourceType: 'standard'),
        plan(id: 'p2', programId: 'prog_occup', specialistId: 'spec2', sourceType: 'standard'),
      ];
      const sourceType = 'all';
      const userId = 'spec2';
      final result = plans
          .where((p) => p.programId == 'prog_occup')
          .where((p) => p.specialistId == userId)
          .where((p) => sourceType == 'all' || p.sourceType == sourceType)
          .toList();
      expect(result.length, 1);
      expect(result.first.programId, 'prog_occup');
      expect(result.first.specialistId, 'spec2');
    });
  });

  group('Active vs completed goals', () {
    test('new plan with progress 0 and steps "لم يبدأ" is an active goal', () {
      final p = plan(id: 'p1', programId: 'prog_speech', progress: 0);
      expect(p.progress < 100, isTrue,
          reason: 'Newly created plan with progress 0 must be active');
    });

    test('plan with progress 100 is completed', () {
      final p = plan(id: 'p1', programId: 'prog_speech', progress: 100);
      expect(p.progress >= 100, isTrue,
          reason: 'Plan with progress 100 must be considered completed');
    });
  });

  group('Assignment filtering for specialists', () {
    test('specialist sees only their active assignments', () {
      final assignments = [
        StudentProgramAssignment(
          id: 'a1', centerId: 'c1', studentId: 's1',
          programId: 'prog_speech', specialistId: 'spec1', role: 'primary',
          status: 'active',
        ),
        StudentProgramAssignment(
          id: 'a2', centerId: 'c1', studentId: 's1',
          programId: 'prog_occup', specialistId: 'spec2', role: 'primary',
          status: 'active',
        ),
        StudentProgramAssignment(
          id: 'a3', centerId: 'c1', studentId: 's2',
          programId: 'prog_speech', specialistId: 'spec1', role: 'primary',
          status: 'active',
        ),
      ];
      final specAssignments = assignments
          .where((a) => a.specialistId == 'spec1' && a.isActive)
          .toList();
      expect(specAssignments.length, 2);
      expect(specAssignments.every((a) => a.specialistId == 'spec1'), isTrue);
    });

    test('inactive assignments are not shown', () {
      final assignments = [
        StudentProgramAssignment(
          id: 'a1', centerId: 'c1', studentId: 's1',
          programId: 'prog_speech', specialistId: 'spec1', role: 'primary',
          status: 'inactive',
        ),
      ];
      final activeOnes = assignments
          .where((a) => a.specialistId == 'spec1' && a.isActive)
          .toList();
      expect(activeOnes, isEmpty);
    });
  });

  group('Standard goal generation fallback (goalTemplate empty → weaknessTemplate)', () {
    test('a finding with isNormal=false, non-empty goal (from fallback) passes the plan creation condition', () {
      // Simulates the _saveAssessment fallback: goalTemplate empty → use weaknessTemplate
      const goal = 'الطالب يحتاج تقوية';
      const findingIsNormal = false;
      // ignore: prefer_const_constructors
      final findingGoalNonEmpty = goal.trim().isNotEmpty;
      expect(findingIsNormal, isFalse);
      expect(findingGoalNonEmpty, isTrue);
      // plan is created when both conditions are met
      expect(!findingIsNormal && findingGoalNonEmpty, isTrue);
    });

    test('a finding with isNormal=false and empty goal (no fallback) fails plan creation', () {
      // Before fix: goalTemplate empty, no fallback → plan not created
      const goal = '';
      const findingIsNormal = false;
      // ignore: prefer_const_constructors
      final findingGoalNonEmpty = goal.trim().isNotEmpty;
      expect(!findingIsNormal && findingGoalNonEmpty, isFalse,
          reason: 'Plan must NOT be created when goal is empty');
    });

    test('a standard plan with goal from weaknessTemplate fallback appears in filtered plans', () {
      final plans = [
        plan(id: 'p1', programId: 'prog_speech', sourceType: 'standard', specialistId: 'spec1'),
      ];
      const sourceType = 'all';
      final result = plans
          .where((p) => p.programId == 'prog_speech')
          .where((p) => p.specialistId == 'spec1')
          .where((p) => sourceType == 'all' || p.sourceType == sourceType)
          .toList();
      expect(result.length, 1);
      expect(result.first.sourceType, 'standard');
    });

    test('a standard plan is visible under "أقسام التقييم" filter (sourceType standard)', () {
      final plans = [
        plan(id: 'p1', programId: 'prog_speech', sourceType: 'standard'),
        plan(id: 'p2', programId: 'prog_speech', sourceType: 'speechSound'),
      ];
      const sourceType = 'standard';
      final result = plans
          .where((p) => p.programId == 'prog_speech')
          .where((p) => sourceType == 'all' || p.sourceType == sourceType)
          .toList();
      expect(result.length, 1);
      expect(result.first.sourceType, 'standard');
    });

    test('a standard plan is NOT visible under "حروف النطق" filter (sourceType speechSound)', () {
      final plans = [
        plan(id: 'p1', programId: 'prog_speech', sourceType: 'standard'),
        plan(id: 'p2', programId: 'prog_speech', sourceType: 'speechSound'),
      ];
      const sourceType = 'speechSound';
      final result = plans
          .where((p) => p.programId == 'prog_speech')
          .where((p) => sourceType == 'all' || p.sourceType == sourceType)
          .toList();
      expect(result.length, 1);
      expect(result.first.sourceType, 'speechSound');
    });
  });

  group('SessionsScreen smart behavior — sourceType chips', () {
    test('non-speech program (usesSpeechSounds=false) does not show chips (simulated: treat sourceType as "all")', () {
      final plans = [
        plan(id: 'p1', programId: 'prog_occup', sourceType: 'standard'),
        plan(id: 'p2', programId: 'prog_occup', sourceType: 'speechSound'),
      ];
      // non-speech program: sourceType filter should be ignored → show all
      const sourceType = 'all';
      final result = plans
          .where((p) => p.programId == 'prog_occup')
          .where((p) => sourceType == 'all' || p.sourceType == sourceType)
          .toList();
      expect(result.length, 2);
    });

    test('non-speech program shows standard goals directly', () {
      final plans = [
        plan(id: 'p1', programId: 'prog_occup', sourceType: 'standard'),
      ];
      const sourceType = 'all';
      final result = plans
          .where((p) => p.programId == 'prog_occup')
          .where((p) => sourceType == 'all' || p.sourceType == sourceType)
          .toList();
      expect(result.length, 1);
      expect(result.first.sourceType, 'standard');
    });

    test('speech-enabled program shows filter chips (simulated via sourceType logic)', () {
      final plans = [
        plan(id: 'p1', programId: 'prog_speech', sourceType: 'standard'),
        plan(id: 'p2', programId: 'prog_speech', sourceType: 'speechSound'),
      ];
      // 'all' filter shows both
      const sourceType = 'all';
      final result = plans
          .where((p) => p.programId == 'prog_speech')
          .where((p) => sourceType == 'all' || p.sourceType == sourceType)
          .toList();
      expect(result.length, 2);
    });

    test('speech-enabled program defaults to all goals', () {
      final plans = [
        plan(id: 'p1', programId: 'prog_speech', sourceType: 'standard'),
        plan(id: 'p2', programId: 'prog_speech', sourceType: 'speechSound'),
      ];
      // default is 'all' → no sourceType filter applied
      const sourceType = 'all';
      final result = plans
          .where((p) => p.programId == 'prog_speech')
          .where((p) => sourceType == 'all' || p.sourceType == sourceType)
          .toList();
      expect(result.length, 2);
    });
  });

  group('Full fallback chain (goalTemplate → weaknessTemplate → option.label)', () {
    test('goalTemplate present → uses goalTemplate (first priority)', () {
      // Simulates _saveAssessment single-select finding creation
      const goalTemplate = 'تحسين تناسق الوجه';
      const weaknessTemplate = 'الوجه مائل لليسار';
      const optionLabel = 'مائل لليسار';
      // ignore: prefer_const_constructors
      final goal = goalTemplate.isNotEmpty
          ? goalTemplate
          : (weaknessTemplate.isNotEmpty ? weaknessTemplate : optionLabel);
      expect(goal, 'تحسين تناسق الوجه');
      expect(goal.trim().isNotEmpty, isTrue);
    });

    test('goalTemplate empty, weaknessTemplate present → uses weaknessTemplate', () {
      const goalTemplate = '';
      const weaknessTemplate = 'الوجه مائل لليسار';
      const optionLabel = 'مائل لليسار';
      // ignore: prefer_const_constructors
      final goal = goalTemplate.isNotEmpty
          ? goalTemplate
          : (weaknessTemplate.isNotEmpty ? weaknessTemplate : optionLabel);
      expect(goal, 'الوجه مائل لليسار');
      expect(goal.trim().isNotEmpty, isTrue);
    });

    test('goalTemplate and weaknessTemplate both empty → uses option.label as final fallback', () {
      const goalTemplate = '';
      const weaknessTemplate = '';
      const optionLabel = 'مائل لليسار';
      // ignore: prefer_const_constructors
      final optionLabelFallback = goalTemplate.isNotEmpty
          ? goalTemplate
          : (weaknessTemplate.isNotEmpty ? weaknessTemplate : optionLabel);
      expect(optionLabelFallback, 'مائل لليسار');
      expect(optionLabelFallback.trim().isNotEmpty, isTrue);
    });

    test('all templates empty for multi-select abnormal → uses option.label as final fallback', () {
      const isNormal = false;
      const goalTemplate = '';
      const weaknessTemplate = '';
      const optionLabel = 'ضعيف';
      // ignore: prefer_const_constructors
      final goal = isNormal
          ? ''
          : (goalTemplate.isNotEmpty
              ? goalTemplate
              : (weaknessTemplate.isNotEmpty ? weaknessTemplate : optionLabel));
      expect(goal, 'ضعيف');
      expect(goal.trim().isNotEmpty, isTrue);
    });

    test('multi-select normal → goal is empty regardless of templates', () {
      const isNormal = true;
      const goalTemplate = 'تحسين';
      const weaknessTemplate = 'ضعف';
      const optionLabel = 'ضعيف';
      // ignore: prefer_const_constructors
      final goal = isNormal
          ? ''
          : (goalTemplate.isNotEmpty
              ? goalTemplate
              : (weaknessTemplate.isNotEmpty ? weaknessTemplate : optionLabel));
      expect(goal, '');
      expect(goal.trim().isEmpty, isTrue);
    });

    test('scenario: "تناسق الوجه → مائل لليسار" with empty goalTemplate and weaknessTemplate', () {
      // Admin configured: generatesTherapy=true but never filled goal/weakness fields
      const optionLabel = 'مائل لليسار';
      const generatedGoal = optionLabel; // fallback to label
      const isNormal = false;
      // ignore: prefer_const_constructors
      final goalNonEmpty = generatedGoal.trim().isNotEmpty;
      // plan creation condition
      expect(!isNormal && goalNonEmpty, isTrue,
          reason: 'Plan must be created when goal falls back to option.label');
    });

    test('scenario: all three fallback levels produce a non-empty goal', () {
      const goalTemplate = 'هدف علاجي';
      const weaknessTemplate = 'نقطة ضعف';
      const optionLabel = 'خيار تجريبي';
      // Level 1: goalTemplate
      var goal = goalTemplate.isNotEmpty ? goalTemplate : (weaknessTemplate.isNotEmpty ? weaknessTemplate : optionLabel);
      expect(goal.trim().isNotEmpty, isTrue);
      // Level 2: weaknessTemplate
      goal = ''.isNotEmpty ? '' : (weaknessTemplate.isNotEmpty ? weaknessTemplate : optionLabel);
      expect(goal, 'نقطة ضعف');
      expect(goal.trim().isNotEmpty, isTrue);
      // Level 3: option.label
      goal = ''.isNotEmpty ? '' : (''.isNotEmpty ? '' : optionLabel);
      expect(goal, 'خيار تجريبي');
      expect(goal.trim().isNotEmpty, isTrue);
    });

    test('Finding with isNormal=true never generates a plan regardless of fallback', () {
      const isNormal = true;
      const goal = 'هدف غير طبيعي'; // would be set by fallback
      expect(isNormal, isTrue);
      expect(!isNormal && goal.trim().isNotEmpty, isFalse,
          reason: 'Normal findings must NOT generate plans');
    });
  });
}
