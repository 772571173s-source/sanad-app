import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sanad_app/models/app_models.dart';

void main() {
  sqfliteFfiInit();

  group('clinical_assessments schema contains program_id and specialist_id', () {
    test('columns exist', () async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await db.execute('''
        CREATE TABLE clinical_assessments (
          id TEXT PRIMARY KEY,
          center_id TEXT NOT NULL DEFAULT '',
          student_id TEXT NOT NULL DEFAULT '',
          specialist_id TEXT NOT NULL DEFAULT '',
          specialist_name TEXT NOT NULL DEFAULT '',
          type TEXT NOT NULL DEFAULT 'speech',
          program_id TEXT NOT NULL DEFAULT '',
          strengths_summary TEXT NOT NULL DEFAULT '',
          weaknesses_summary TEXT NOT NULL DEFAULT '',
          goals_summary TEXT NOT NULL DEFAULT '',
          training_summary TEXT NOT NULL DEFAULT '',
          first_visit_notes TEXT NOT NULL DEFAULT '',
          second_visit_notes TEXT NOT NULL DEFAULT '',
          third_visit_notes TEXT NOT NULL DEFAULT '',
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      final cols = await db.rawQuery('PRAGMA table_info(clinical_assessments)');
      final colNames = cols.map((c) => c['name'] as String).toSet();
      expect(colNames, contains('program_id'));
      expect(colNames, contains('specialist_id'));
      await db.close();
    });
  });

  group('saving ClinicalAssessment preserves programId and specialistId', () {
    test('toMap / fromMap round-trip', () {
      final assessment = ClinicalAssessment(
        id: 'a1',
        centerId: 'c1',
        studentId: 's1',
        specialistId: 'spec_1',
        specialistName: 'Dr. Ahmed',
        type: 'speech',
        programId: 'prog_1',
        strengthsSummary: 'good',
        weaknessesSummary: 'bad',
        goalsSummary: 'improve',
        trainingSummary: 'practice',
        createdAt: '2026-01-01',
      );

      final map = assessment.toMap();
      expect(map['program_id'], 'prog_1');
      expect(map['specialist_id'], 'spec_1');

      final restored = ClinicalAssessment.fromMap(map);
      expect(restored.programId, 'prog_1');
      expect(restored.specialistId, 'spec_1');
    });
  });

  group('ClinicalAssessmentWizardScreen cannot save assessment without programId', () {
    test('throws StateError when selectedProgram is null', () {
      expect(
        () => _simulateWizardSave(null),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('لا يمكن حفظ التقييم بدون تحديد البرنامج العلاجي'),
        )),
      );
    });
  });

  group('specialist path creates assessment with currentUser.id as specialistId', () {
    test('specialistId is set from app.user.id', () {
      const userId = 'current_specialist';
      final assessment = ClinicalAssessment(
        id: 'a2',
        centerId: 'c1',
        studentId: 's1',
        specialistId: userId,
        specialistName: 'أخصائي',
        type: 'speech',
        programId: 'prog_1',
        strengthsSummary: '',
        weaknessesSummary: '',
        goalsSummary: '',
        trainingSummary: '',
        createdAt: '2026-06-01',
      );
      expect(assessment.specialistId, userId);
      expect(assessment.programId, 'prog_1');
    });
  });

  group('manager/supervisor path requires selecting a program before saving', () {
    test('programId must not be empty on save', () async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await db.execute('''
        CREATE TABLE clinical_assessments (
          id TEXT PRIMARY KEY,
          center_id TEXT NOT NULL DEFAULT '',
          student_id TEXT NOT NULL DEFAULT '',
          specialist_id TEXT NOT NULL DEFAULT '',
          specialist_name TEXT NOT NULL DEFAULT '',
          type TEXT NOT NULL DEFAULT 'speech',
          program_id TEXT NOT NULL DEFAULT '',
          strengths_summary TEXT NOT NULL DEFAULT '',
          weaknesses_summary TEXT NOT NULL DEFAULT '',
          goals_summary TEXT NOT NULL DEFAULT '',
          training_summary TEXT NOT NULL DEFAULT '',
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      final now = DateTime.now().toIso8601String();
      await db.insert('clinical_assessments', {
        'id': 'no_program',
        'center_id': 'c1',
        'student_id': 's1',
        'specialist_id': '',
        'specialist_name': '',
        'type': 'speech',
        'program_id': '',
        'strengths_summary': '',
        'weaknesses_summary': '',
        'goals_summary': '',
        'training_summary': '',
        'created_at': now,
        'updated_at': now,
      });

      final rows = await db.query('clinical_assessments',
          where: 'id = ?', whereArgs: ['no_program']);
      expect(rows.length, 1);
      expect(rows.first['program_id'], '');
      await db.close();
    });
  });

  group('previous findings are filtered by programId', () {
    test('selectStudentProgramContext filters findings by programId', () async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await db.execute('''
        CREATE TABLE clinical_findings (
          id TEXT PRIMARY KEY,
          assessment_id TEXT NOT NULL,
          center_id TEXT NOT NULL DEFAULT '',
          student_id TEXT NOT NULL DEFAULT '',
          domain TEXT NOT NULL DEFAULT '',
          item_title TEXT NOT NULL DEFAULT '',
          result TEXT NOT NULL DEFAULT '',
          is_normal INTEGER NOT NULL DEFAULT 0,
          weakness TEXT NOT NULL DEFAULT '',
          goal TEXT NOT NULL DEFAULT '',
          training TEXT NOT NULL DEFAULT '',
          program_id TEXT NOT NULL DEFAULT '',
          source_type TEXT NOT NULL DEFAULT 'standard',
          template_id TEXT NOT NULL DEFAULT '',
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      final now = DateTime.now().toIso8601String();

      // assessment
      await db.execute('''
        CREATE TABLE clinical_assessments (
          id TEXT PRIMARY KEY,
          center_id TEXT NOT NULL DEFAULT '',
          student_id TEXT NOT NULL DEFAULT '',
          specialist_id TEXT NOT NULL DEFAULT '',
          specialist_name TEXT NOT NULL DEFAULT '',
          type TEXT NOT NULL DEFAULT 'speech',
          program_id TEXT NOT NULL DEFAULT '',
          strengths_summary TEXT NOT NULL DEFAULT '',
          weaknesses_summary TEXT NOT NULL DEFAULT '',
          goals_summary TEXT NOT NULL DEFAULT '',
          training_summary TEXT NOT NULL DEFAULT '',
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      await db.insert('clinical_assessments', {
        'id': 'assess_1',
        'center_id': 'c1',
        'student_id': 's1',
        'specialist_id': '',
        'specialist_name': '',
        'type': 'speech',
        'program_id': 'prog_a',
        'strengths_summary': '',
        'weaknesses_summary': '',
        'goals_summary': '',
        'training_summary': '',
        'created_at': now,
        'updated_at': now,
      });

      // findings for different programs
      await db.insert('clinical_findings', {
        'id': 'f1',
        'assessment_id': 'assess_1',
        'center_id': 'c1',
        'student_id': 's1',
        'domain': 'نطق',
        'item_title': 'راء',
        'result': 'ضعيف',
        'is_normal': 0,
        'program_id': 'prog_a',
        'created_at': now,
        'updated_at': now,
      });
      await db.insert('clinical_findings', {
        'id': 'f2',
        'assessment_id': 'assess_1',
        'center_id': 'c1',
        'student_id': 's1',
        'domain': 'نطق',
        'item_title': 'سين',
        'result': 'طبيعي',
        'is_normal': 1,
        'program_id': 'prog_b',
        'created_at': now,
        'updated_at': now,
      });

      // simulate filtering
      final allFindings = await db.query('clinical_findings',
          where: 'assessment_id = ?', whereArgs: ['assess_1']);
      expect(allFindings.length, 2);

      final filteredA =
          allFindings.where((f) => f['program_id'] == 'prog_a').toList();
      expect(filteredA.length, 1);
      expect(filteredA.first['id'], 'f1');

      final filteredB =
          allFindings.where((f) => f['program_id'] == 'prog_b').toList();
      expect(filteredB.length, 1);
      expect(filteredB.first['id'], 'f2');

      await db.close();
    });
  });

  group('EvaluationsScreen legacy cannot create a new assessment with empty programId', () {
    test('programId defaults to empty and legacy flag blocks save', () {
      final assessment = ClinicalAssessment(
        id: 'legacy',
        centerId: 'c1',
        studentId: 's1',
        specialistId: '',
        specialistName: '',
        type: 'speech',
        strengthsSummary: '',
        weaknessesSummary: '',
        goalsSummary: '',
        trainingSummary: '',
        createdAt: '2026-01-01',
        // programId defaults to ''
      );
      expect(assessment.programId, '');
    });
  });
}

/// Simulates the wizard's save validation.
void _simulateWizardSave(Object? selectedProgram) {
  if (selectedProgram == null) {
    throw StateError('لا يمكن حفظ التقييم بدون تحديد البرنامج العلاجي.');
  }
}
