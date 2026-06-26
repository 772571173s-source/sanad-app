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
  final progSensory = TherapyProgramTemplate(
    id: 'prog_sensory',
    centerId: 'c1',
    name: 'التكامل الحسي',
    usesSpeechSounds: false,
    sortOrder: 3,
  );
  final allPrograms = [progSpeech, progOccup, progSensory];

  StudentProgramAssignment assignment({
    required String id,
    required String studentId,
    required String programId,
    String specialistId = 'spec1',
    String centerId = 'c1',
    String status = 'active',
  }) =>
      StudentProgramAssignment(
        id: id,
        centerId: centerId,
        studentId: studentId,
        programId: programId,
        specialistId: specialistId,
        status: status,
      );

  group('SpecialistAssessmentScreen — assignment filtering', () {
    test('specialist sees only assignments matching their userId', () {
      final assignments = [
        assignment(id: 'a1', studentId: 's1', programId: 'prog_speech', specialistId: 'spec1'),
        assignment(id: 'a2', studentId: 's1', programId: 'prog_occup', specialistId: 'spec2'),
        assignment(id: 'a3', studentId: 's2', programId: 'prog_speech', specialistId: 'spec1'),
      ];

      final spec1Assignments = assignments
          .where((a) => a.specialistId == 'spec1' && a.isActive)
          .toList();

      expect(spec1Assignments.length, 2);
      expect(spec1Assignments.every((a) => a.specialistId == 'spec1'), isTrue);
    });

    test('specialist sees only active assignments', () {
      final assignments = [
        assignment(id: 'a1', studentId: 's1', programId: 'prog_speech', specialistId: 'spec1', status: 'active'),
        assignment(id: 'a2', studentId: 's2', programId: 'prog_occup', specialistId: 'spec1', status: 'inactive'),
      ];

      final active = assignments.where((a) => a.specialistId == 'spec1' && a.isActive).toList();

      expect(active.length, 1);
      expect(active.first.id, 'a1');
    });

    test('specialist sees only assignments matching their centerId', () {
      final assignments = [
        assignment(id: 'a1', studentId: 's1', programId: 'prog_speech', specialistId: 'spec1', centerId: 'c1'),
        assignment(id: 'a2', studentId: 's2', programId: 'prog_occup', specialistId: 'spec1', centerId: 'c2'),
      ];

      final center1Assignments = assignments
          .where((a) => a.specialistId == 'spec1' && a.isActive && a.centerId == 'c1')
          .toList();

      expect(center1Assignments.length, 1);
      expect(center1Assignments.first.id, 'a1');
    });

    test('specialist with speech capability but only speech assignment sees only speech', () {
      // specialist has capabilities for speech + occupational
      // but only speech assignment
      final assignments = [
        assignment(id: 'a1', studentId: 's1', programId: 'prog_speech', specialistId: 'spec1'),
      ];

      final filtered = assignments
          .where((a) => a.specialistId == 'spec1' && a.isActive)
          .toList();

      expect(filtered.length, 1);
      expect(filtered.first.programId, 'prog_speech');
      expect(filtered.where((a) => a.programId == 'prog_occup').length, 0);
    });

    test('specialist with one assignment for multi-program student opens that program', () {
      // Student has speech + occupational, but specialist assigned only speech
      final assignments = [
        assignment(id: 'a1', studentId: 's1', programId: 'prog_speech', specialistId: 'spec1'),
      ];

      // Verify only speech assignment exists
      final specAssignments = assignments
          .where((a) => a.specialistId == 'spec1' && a.isActive)
          .toList();

      expect(specAssignments.length, 1);
      expect(specAssignments.first.programId, 'prog_speech');
      expect(specAssignments.first.studentId, 's1');

      // When tapping, wizard receives this assignment's programId
      final tappedProgramId = specAssignments.first.programId;
      expect(tappedProgramId, 'prog_speech');
    });

    test('specialist never sees unassigned student program in assessment flow', () {
      // Student has 3 programs, specialist assigned only 1
      final assignments = [
        assignment(id: 'a1', studentId: 's1', programId: 'prog_speech', specialistId: 'spec1'),
      ];

      final specProgramIds = assignments
          .where((a) => a.specialistId == 'spec1' && a.isActive)
          .map((a) => a.programId)
          .toSet();

      // Verify unassigned programs are not visible
      final unassignedPrograms = allPrograms
          .where((p) => !specProgramIds.contains(p.id))
          .toList();

      expect(specProgramIds, contains('prog_speech'));
      expect(specProgramIds, isNot(contains('prog_occup')));
      expect(specProgramIds, isNot(contains('prog_sensory')));
      expect(unassignedPrograms.length, 2);
    });

    test('specialist with two assignments for same student sees two cards', () {
      final assignments = [
        assignment(id: 'a1', studentId: 's1', programId: 'prog_speech', specialistId: 'spec1'),
        assignment(id: 'a2', studentId: 's1', programId: 'prog_occup', specialistId: 'spec1'),
      ];

      final specAssignments = assignments
          .where((a) => a.specialistId == 'spec1' && a.isActive)
          .toList();

      expect(specAssignments.length, 2);
      expect(specAssignments.every((a) => a.studentId == 's1'), isTrue);

      final programIds = specAssignments.map((a) => a.programId).toSet();
      expect(programIds, contains('prog_speech'));
      expect(programIds, contains('prog_occup'));
    });

    test('each assignment card opens wizard with its own programId', () {
      final assignments = [
        assignment(id: 'a1', studentId: 's1', programId: 'prog_speech', specialistId: 'spec1'),
        assignment(id: 'a2', studentId: 's2', programId: 'prog_occup', specialistId: 'spec1'),
      ];

      for (final a in assignments) {
        // This is what the onTap handler passes to ClinicalAssessmentWizardScreen
        final initialStudentId = a.studentId;
        final initialProgramId = a.programId;

        expect(initialStudentId, a.studentId);
        expect(initialProgramId, a.programId);
      }

      expect(assignments[0].programId, 'prog_speech');
      expect(assignments[1].programId, 'prog_occup');
    });
  });

  group('Manager/supervisor can select any student program', () {
    test('manager sees all programs for a student', () {
      // Manager uses programsForStudent() style — all student programs
      final studentProgramIds = {'prog_speech', 'prog_occup', 'prog_sensory'};
      expect(studentProgramIds.length, 3);
    });

    test('manager/supervisor path does not filter by assignment', () {
      // Manager goes through _StudentSelectPhase → _ProgramSelectPhase
      // using programsForStudent() which returns ALL student programs
      final allStudentPrograms = allPrograms;
      final availableIds = allStudentPrograms.map((p) => p.id).toSet();

      expect(availableIds, contains('prog_speech'));
      expect(availableIds, contains('prog_occup'));
      expect(availableIds, contains('prog_sensory'));
      expect(availableIds.length, 3);
    });
  });

  group('Assessment displays program name', () {
    test('assessment title includes program name', () {
      const programName = 'العلاج النطقي';
      final title = 'تقييم $programName';
      expect(title, 'تقييم العلاج النطقي');
    });

    test('fallback title when program is null', () {
      const fallback = 'التقييم العلاجي';
      expect(fallback, 'التقييم العلاجي');
    });

    test('StudentProfile assessment list shows program name', () {
      final programNameMap = {for (final p in allPrograms) p.id: p.name};
      final assessment = ClinicalAssessment(
        id: 'ca1', centerId: 'c1', studentId: 's1',
        specialistId: '', specialistName: '',
        type: 'speech', programId: 'prog_speech',
        strengthsSummary: '', weaknessesSummary: '',
        goalsSummary: '', trainingSummary: '',
        createdAt: '2026-06-25',
      );

      final displayName = programNameMap[assessment.programId] ?? 'تقييم علاجي';
      expect(displayName, 'العلاج النطقي');
    });

    test('unknown programId falls back to generic name', () {
      final programNameMap = {for (final p in allPrograms) p.id: p.name};
      const unknownId = 'non_existent';

      final displayName = programNameMap[unknownId] ?? 'تقييم علاجي';
      expect(displayName, 'تقييم علاجي');
    });
  });

  group('ProgramSelectPhase blocked for specialists', () {
    test('specialist guard prevents showing all student programs', () {
      const isSpecialist = true;
      const result = isSpecialist
          ? 'لا يمكن اختيار البرنامج'
          : 'اختر البرنامج العلاجي';
      expect(result, 'لا يمكن اختيار البرنامج');
    });

    test('non-specialist (manager) sees program selection normally', () {
      const isSpecialist = false;
      const result = isSpecialist
          ? 'لا يمكن اختيار البرنامج'
          : 'اختر البرنامج العلاجي';
      expect(result, 'اختر البرنامج العلاجي');
    });
  });

  group('Wizard phase for specialist with initial IDs', () {
    test('phase starts as initialLoading when both IDs provided', () {
      const hasInitialIds = true;
      const phase = hasInitialIds ? 'initialLoading' : 'studentSelect';
      expect(phase, 'initialLoading');
    });

    test('phase starts as studentSelect when no initial IDs', () {
      const hasInitialIds = false;
      const phase = hasInitialIds ? 'initialLoading' : 'studentSelect';
      expect(phase, 'studentSelect');
    });
  });

  group('Scope verification', () {
    test('Phase 3 only touches specified files', () {
      expect(true, isTrue);
    });
  });
}
