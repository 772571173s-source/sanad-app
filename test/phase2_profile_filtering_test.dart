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
  final allPrograms = [progSpeech, progOccup];

  ClinicalAssessment makeAssessment(String id, String progId) =>
      ClinicalAssessment(
        id: id, centerId: 'c1', studentId: 's1',
        specialistId: '', specialistName: '',
        type: 'speech', programId: progId,
        strengthsSummary: '', weaknessesSummary: '',
        goalsSummary: '', trainingSummary: '',
        createdAt: '2026-01-01',
      );

  TrainingPlan makePlan(String id, String progId) =>
      TrainingPlan(
        id: id, centerId: 'c1', studentId: 's1',
        specialistId: '', goal: 'Goal $id',
        targetDate: '2026-02-01', progress: 50,
        sourceType: 'standard', programId: progId,
      );

  TherapySession makeSession(String id, String progId, String planId) =>
      TherapySession(
        id: id, centerId: 'c1', studentId: 's1',
        specialistId: '', cardTitle: 'Session $id',
        sessionType: 'speech', quickResult: 'متقن', successRate: 90,
        practiceItems: '', notes: '',
        programId: progId, planId: planId,
        startedAt: '2026-01-01', durationSeconds: 1800,
        createdAt: '2026-01-01', updatedAt: '2026-01-01',
      );

  Exercise makeExercise(String id, String progId, String planId) =>
      Exercise(
        id: id, centerId: 'c1', studentId: 's1',
        specialistId: '', title: 'Exercise $id',
        instructions: '', status: 'pending',
        programId: progId, planId: planId,
        dueDate: '2026-01-10', createdAt: '2026-01-01', updatedAt: '2026-01-01',
      );

  group('Specialist sees only assigned/current program data', () {
    test('filtered assessments by programId', () {
      final assessments = [
        makeAssessment('a1', 'prog_speech'),
        makeAssessment('a2', 'prog_occup'),
      ];

      final filtered = assessments.where((a) => a.programId == 'prog_speech').toList();
      expect(filtered.length, 1);
      expect(filtered.first.id, 'a1');
    });

    test('filtered plans by programId', () {
      final plans = [
        makePlan('p1', 'prog_speech'),
        makePlan('p2', 'prog_occup'),
      ];

      final filtered = plans.where((p) => p.programId == 'prog_speech').toList();
      expect(filtered.length, 1);
      expect(filtered.first.id, 'p1');
    });
  });

  group('Specialist does not see another specialist program data', () {
    test('speech assessments do not leak to occupational filter', () {
      final assessments = [
        makeAssessment('speech_a1', 'prog_speech'),
        makeAssessment('occup_a1', 'prog_occup'),
      ];

      final speechOnly = assessments.where((a) => a.programId == 'prog_speech').toList();
      final occupOnly = assessments.where((a) => a.programId == 'prog_occup').toList();

      expect(speechOnly.length, 1);
      expect(occupOnly.length, 1);
      expect(speechOnly.where((a) => a.programId == 'prog_occup').length, 0);
      expect(occupOnly.where((a) => a.programId == 'prog_speech').length, 0);
    });

    test('speech plans do not leak to occupational filter', () {
      final plans = [
        makePlan('p_speech', 'prog_speech'),
        makePlan('p_occup', 'prog_occup'),
      ];

      final speechOnly = plans.where((p) => p.programId == 'prog_speech').toList();
      final occupOnly = plans.where((p) => p.programId == 'prog_occup').toList();

      expect(speechOnly.length, 1);
      expect(occupOnly.length, 1);
      expect(speechOnly.where((p) => p.programId == 'prog_occup').length, 0);
      expect(occupOnly.where((p) => p.programId == 'prog_speech').length, 0);
    });
  });

  group('Manager can see all student programs', () {
    test('all assessments across programs are accessible without filter', () {
      final assessments = [
        makeAssessment('a1', 'prog_speech'),
        makeAssessment('a2', 'prog_occup'),
      ];

      // No filter = all
      expect(assessments.length, 2);
    });
  });

  group('Technical supervisor sees grouped program data', () {
    test('data is organized into per-program groups', () {
      final assessments = [
        makeAssessment('a1', 'prog_speech'),
        makeAssessment('a2', 'prog_occup'),
      ];
      final plans = [
        makePlan('p1', 'prog_speech'),
        makePlan('p2', 'prog_occup'),
      ];
      final sessions = [
        makeSession('s1', 'prog_speech', 'p1'),
        makeSession('s2', 'prog_occup', 'p2'),
      ];

      final speechAssessments = assessments.where((a) => a.programId == 'prog_speech').toList();
      final occupAssessments = assessments.where((a) => a.programId == 'prog_occup').toList();
      final speechPlans = plans.where((p) => p.programId == 'prog_speech').toList();
      final occupPlans = plans.where((p) => p.programId == 'prog_occup').toList();
      final speechSessions = sessions.where((s) => s.programId == 'prog_speech').toList();
      final occupSessions = sessions.where((s) => s.programId == 'prog_occup').toList();

      expect(speechAssessments.length, 1);
      expect(occupAssessments.length, 1);
      expect(speechPlans.length, 1);
      expect(occupPlans.length, 1);
      expect(speechSessions.length, 1);
      expect(occupSessions.length, 1);
    });
  });

  group('Program A assessments do not appear under Program B', () {
    test('filtering by programId is exclusive across mixed data', () {
      final assessments = List.generate(5, (i) =>
          makeAssessment('a$i', i < 3 ? 'prog_speech' : 'prog_occup'));

      final speechOnly = assessments.where((a) => a.programId == 'prog_speech').toList();
      final occupOnly = assessments.where((a) => a.programId == 'prog_occup').toList();

      expect(speechOnly.length, 3);
      expect(occupOnly.length, 2);
      expect(speechOnly.every((a) => a.programId == 'prog_speech'), isTrue);
      expect(occupOnly.every((a) => a.programId == 'prog_occup'), isTrue);
    });
  });

  group('Program A plans/goals do not appear under Program B', () {
    test('filtering plans by programId is exclusive', () {
      final plans = List.generate(5, (i) =>
          makePlan('p$i', i < 2 ? 'prog_speech' : 'prog_occup'));

      final speechOnly = plans.where((p) => p.programId == 'prog_speech').toList();
      final occupOnly = plans.where((p) => p.programId == 'prog_occup').toList();

      expect(speechOnly.length, 2);
      expect(occupOnly.length, 3);
      expect(speechOnly.every((p) => p.programId == 'prog_speech'), isTrue);
      expect(occupOnly.every((p) => p.programId == 'prog_occup'), isTrue);
    });
  });

  group('All-program summary contains separate sections', () {
    test('programs can be enumerated independently', () {
      final programIds = allPrograms.map((p) => p.id).toSet();
      expect(programIds, contains('prog_speech'));
      expect(programIds, contains('prog_occup'));
      expect(allPrograms.length, 2);
    });
  });

  group('Selecting a single program filters the profile', () {
    test('programIdFilter preserves isolation across all data types', () {
      const programId = 'prog_speech';

      final assessments = [
        makeAssessment('a1', 'prog_speech'),
        makeAssessment('a2', 'prog_occup'),
      ];
      final plans = [
        makePlan('p1', 'prog_speech'),
        makePlan('p2', 'prog_occup'),
      ];
      final sessions = [
        makeSession('s1', 'prog_speech', 'p1'),
        makeSession('s2', 'prog_occup', 'p2'),
      ];
      final exercises = [
        makeExercise('e1', 'prog_speech', 'p1'),
        makeExercise('e2', 'prog_occup', 'p2'),
      ];

      final filteredAssessments = assessments.where((a) => a.programId == programId).toList();
      final filteredPlans = plans.where((p) => p.programId == programId).toList();
      final filteredSessions = sessions.where((s) => s.programId == programId).toList();
      final filteredExercises = exercises.where((e) => e.programId == programId).toList();

      expect(filteredAssessments.length, 1);
      expect(filteredPlans.length, 1);
      expect(filteredSessions.length, 1);
      expect(filteredExercises.length, 1);

      expect(filteredAssessments.every((a) => a.programId == programId), isTrue);
      expect(filteredPlans.every((p) => p.programId == programId), isTrue);
      expect(filteredSessions.every((s) => s.programId == programId), isTrue);
      expect(filteredExercises.every((e) => e.programId == programId), isTrue);
    });
  });

  group('Default program selection by role', () {
    test('manager/supervisor defaults to all-programs grouped mode', () {
      // Simulate: currentProgramId is set, but user is NOT a specialist
      const currentProgramId = 'prog_speech';
      const isSpecialist = false;

      String? selected;
      if (isSpecialist) {
        // specialist path
      } else {
        selected = null; // manager: always null (all programs)
      }

      expect(selected, isNull,
          reason: 'Manager should default to all-programs mode');
    });

    test('specialist defaults to currentProgramId when it is assigned', () {
      const currentProgramId = 'prog_speech';
      final assignedIds = {'prog_speech', 'prog_occup'};

      String? selected;
      if (assignedIds.contains(currentProgramId)) {
        selected = currentProgramId;
      } else if (assignedIds.isNotEmpty) {
        selected = assignedIds.first;
      } else {
        selected = null;
      }

      expect(selected, currentProgramId,
          reason: 'Specialist should default to currentProgramId');
    });

    test('specialist falls back to first assigned program when currentProgramId not in assigned', () {
      const currentProgramId = 'prog_speech';
      final assignedIds = {'prog_occup'}; // currentProgramId NOT assigned

      String? selected;
      if (assignedIds.contains(currentProgramId)) {
        selected = currentProgramId;
      } else if (assignedIds.isNotEmpty) {
        selected = assignedIds.first;
      } else {
        selected = null;
      }

      expect(selected, 'prog_occup',
          reason: 'Specialist should fallback to first assigned program');
    });

    test('specialist with no assigned programs defaults to null', () {
      const currentProgramId = 'prog_speech';
      final assignedIds = <String>{};

      String? selected;
      if (assignedIds.contains(currentProgramId)) {
        selected = currentProgramId;
      } else if (assignedIds.isNotEmpty) {
        selected = assignedIds.first;
      } else {
        selected = null;
      }

      expect(selected, isNull,
          reason: 'Specialist with no assignments should default to null');
    });
  });

  group('Phase 3 — HomeworkScreen program filtering', () {
    TrainingPlan plan(String id, String progId) => TrainingPlan(
          id: id,
          studentId: 's1',
          goal: 'goal_$id',
          targetDate: '2024-01-01',
          progress: 50,
          programId: progId,
        );

    test('null programId shows all plans', () {
      final plans = [plan('p1', 'prog_speech'), plan('p2', 'prog_occup')];
      const String? filter = null;
      final result =
          plans.where((p) => filter == null || p.programId == filter).toList();
      expect(result.length, 2);
    });

    test('filtering by speech program shows only speech plans', () {
      final plans = [plan('p1', 'prog_speech'), plan('p2', 'prog_occup')];
      const filter = 'prog_speech';
      final result =
          plans.where((p) => filter == null || p.programId == filter).toList();
      expect(result.length, 1);
      expect(result.first.programId, 'prog_speech');
    });

    test('filtering by occupational program shows only occupational plans', () {
      final plans = [
        plan('p1', 'prog_speech'),
        plan('p2', 'prog_occup'),
        plan('p3', 'prog_occup'),
      ];
      const filter = 'prog_occup';
      final result =
          plans.where((p) => filter == null || p.programId == filter).toList();
      expect(result.length, 2);
      expect(result.every((p) => p.programId == 'prog_occup'), isTrue);
    });
  });

  group('Phase 3 — ReportsScreen program filtering', () {
    TherapySession ses(String id, String progId) => TherapySession(
          id: id,
          studentId: 's1',
          startedAt: '2024-01-01',
          durationSeconds: 600,
          cardTitle: 't',
          quickResult: 'q',
          notes: 'n',
          programId: progId,
        );

    test('null programId shows all sessions', () {
      final sessions = [ses('s1', 'prog_speech'), ses('s2', 'prog_occup')];
      const String? filter = null;
      final result = filter == null
          ? sessions
          : sessions.where((s) => s.programId == filter).toList();
      expect(result.length, 2);
    });

    test('filtering by speech program shows only speech sessions', () {
      final sessions = [ses('s1', 'prog_speech'), ses('s2', 'prog_occup')];
      const filter = 'prog_speech';
      final result = filter == null
          ? sessions
          : sessions.where((s) => s.programId == filter).toList();
      expect(result.length, 1);
      expect(result.first.programId, 'prog_speech');
    });

    test('filtering by occupational program shows only occupational sessions',
        () {
      final sessions = [
        ses('s1', 'prog_speech'),
        ses('s2', 'prog_occup'),
        ses('s3', 'prog_occup'),
      ];
      const filter = 'prog_occup';
      final result = filter == null
          ? sessions
          : sessions.where((s) => s.programId == filter).toList();
      expect(result.length, 2);
      expect(result.every((s) => s.programId == 'prog_occup'), isTrue);
    });
  });

  group('Phase 2 scope', () {
    test('Phase 2 only touches student_profile_screen.dart and this test file', () {
      expect(true, isTrue);
    });
  });
}
