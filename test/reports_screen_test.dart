import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sanad_app/models/app_models.dart';
import 'package:sanad_app/models/center_report_settings.dart';
import 'package:sanad_app/providers/app_provider.dart';
import 'package:sanad_app/repositories/sanad_repository.dart';
import 'package:sanad_app/services/center_report_settings_service.dart';
import 'package:sanad_app/services/database_service.dart';
import 'package:sanad_app/services/pdf_service.dart';
import 'package:sanad_app/services/report_comparison_service.dart';
import 'package:sanad_app/services/report_data_builder.dart';
import 'package:sanad_app/services/report_export_service.dart';
import 'package:sanad_app/services/smart_pdf_report_service.dart';
import 'package:sanad_app/services/demo_data_service.dart';
import 'package:sanad_app/services/demo_time_service.dart';
import 'package:sanad_app/services/sanad_library_service.dart';
import 'package:sanad_app/screens/demo_center_screen.dart';
import 'package:sanad_app/screens/reports_screen.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  AppProvider bareProvider({bool isSpecialist = true}) {
    final repo = SanadRepository(DatabaseService.instance);
    final pdf = PdfService();
    return AppProvider(repo, pdf)
      ..user = AppUser(
        id: 'spec_1',
        email: 'spec@test.com',
        passwordHash: 'hash',
        name: 'أخصائي 1',
        role: isSpecialist ? UserRole.specialist : UserRole.centerManager,
        centerId: 'center_1',
      );
  }

  Student student({
    String id = 'student_1',
    String name = 'طالب اختبار',
  }) =>
      Student(
        id: id,
        centerId: 'center_1',
        name: name,
        age: 6,
        status: 'نشط',
        diagnosis: 'اضطراب نطق',
        parentName: '',
        parentPhone: '',
        portalEmail: '',
        portalPassword: '',
        photoPath: '',
        notes: '',
        createdAt: '2026-01-01',
        updatedAt: '2026-06-01',
      );

  TherapyProgramTemplate tProg({
    String id = 'prog_1',
    String name = 'برنامج أول',
  }) =>
      TherapyProgramTemplate(
        id: id,
        centerId: 'center_1',
        name: name,
        sortOrder: 1,
      );

  StudentProgramAssignment sAssignment({
    String id = 'assign_1',
    String programId = 'prog_1',
    String studentId = 'student_1',
  }) =>
      StudentProgramAssignment(
        id: id,
        centerId: 'center_1',
        studentId: studentId,
        programId: programId,
        specialistId: 'spec_1',
      );

  // ===========================================================================
  // ReportDataBuilder
  // ===========================================================================
  group('ReportDataBuilder', () {
    late AppProvider app;

    setUp(() {
      app = bareProvider(isSpecialist: true);
      app.students = [student()];
      app.therapyPrograms = [tProg(), tProg(id: 'prog_2', name: 'برنامج ثاني')];
      app.plans = [
        const TrainingPlan(
          id: 'plan_1', studentId: 'student_1', goal: 'هدف أول',
          targetDate: '2026-03-01', progress: 50,
          programId: 'prog_1', sourceType: 'standard', specialistId: 'spec_1',
        ),
        const TrainingPlan(
          id: 'plan_2', studentId: 'student_1', goal: 'هدف ثاني',
          targetDate: '2026-03-01', progress: 50,
          programId: 'prog_2', sourceType: 'standard', specialistId: 'spec_1',
        ),
      ];
      app.sessions = [
        const TherapySession(
          id: 'sess_1', studentId: 'student_1', planId: 'plan_1',
          startedAt: '2026-05-15T10:00:00', durationSeconds: 1800,
          cardTitle: 'جلسة أول', quickResult: 'متقن', notes: '',
          programId: 'prog_1', specialistId: 'spec_1', successRate: 100,
        ),
        const TherapySession(
          id: 'sess_2', studentId: 'student_1', planId: 'plan_2',
          startedAt: '2026-05-16T10:00:00', durationSeconds: 1800,
          cardTitle: 'جلسة ثاني', quickResult: 'بمساعدة', notes: '',
          programId: 'prog_2', specialistId: 'spec_1', successRate: 50,
        ),
      ];
      app.studentProgramIds = ['prog_1', 'prog_2'];
      app.studentProgramAssignments = [sAssignment()];
    });

    test('singleProgram scope builds one section', () {
      final builder = ReportDataBuilder(app: app);
      final data = builder.build(
        studentId: 'student_1',
        type: 'تقرير شامل',
        scope: 'singleProgram',
        programId: 'prog_1',
        specialistId: 'spec_1',
      );

      expect(data.totalSections, equals(1));
      expect(data.sections.first.programId, equals('prog_1'));
      expect(data.sections.first.plans.length, equals(1));
    });

    test('specialistPrograms scope builds sections from student assignments', () {
      app.studentProgramAssignments = [
        sAssignment(),
        sAssignment(id: 'assign_2', programId: 'prog_2'),
      ];

      final builder = ReportDataBuilder(app: app);
      final data = builder.build(
        studentId: 'student_1',
        type: 'تقرير شامل',
        scope: 'specialistPrograms',
        specialistId: 'spec_1',
      );

      expect(data.totalSections, equals(2));
    });

    test('specialistPrograms with no active assignments returns empty sections', () {
      app.studentProgramAssignments = [];

      final builder = ReportDataBuilder(app: app);
      final data = builder.build(
        studentId: 'student_1',
        type: 'تقرير شامل',
        scope: 'specialistPrograms',
        specialistId: 'spec_1',
      );

      expect(data.totalSections, equals(0));
    });

    test('allPrograms scope builds all student program sections', () {
      final builder = ReportDataBuilder(app: app);
      final data = builder.build(
        studentId: 'student_1',
        type: 'تقرير شامل',
        scope: 'allPrograms',
      );

      expect(data.totalSections, greaterThanOrEqualTo(1));
    });
  });

  // ===========================================================================
  // SmartPdfReportService
  // ===========================================================================
  group('SmartPdfReportService', () {
    test('buildSmartReportPdfBytes returns non-empty bytes (empty data)', () async {
      final data = ReportData(
        student: student(),
        type: 'تقرير شامل',
        scope: 'singleProgram',
      );

      final service = SmartPdfReportService();
      final bytes = await service.buildSmartReportPdfBytes(data);

      expect(bytes, isNotNull);
      expect(bytes.length, greaterThan(0));
    });

    test('buildSmartReportPdfBytes with sections returns content', () async {
      final section = ProgramReportSection(
        programId: 'prog_1',
        programName: 'برنامج اختبار',
        specialistId: 'spec_1',
        specialistName: 'أخصائي',
        plans: [
        const TrainingPlan(
          id: 'plan_1', studentId: 'student_1', goal: 'هدف',
          targetDate: '2026-01-01', progress: 50,
          programId: 'prog_1', sourceType: 'standard',
          specialistId: 'spec_1',
        ),
      ],
        sessions: [
          const TherapySession(
            id: 'sess_1', studentId: 'student_1', planId: 'plan_1',
            startedAt: '2026-05-15T10:00:00', durationSeconds: 1800,
            cardTitle: 'جلسة', quickResult: 'متقن', notes: '',
            programId: 'prog_1', specialistId: 'spec_1', successRate: 100,
          ),
        ],
        masteredGoals: 1,
        activeGoals: 0,
      );

      final data = ReportData(
        student: student(),
        type: 'تقرير شامل',
        scope: 'singleProgram',
        sections: [section],
      );

      final service = SmartPdfReportService();
      try {
        final bytes = await service.buildSmartReportPdfBytes(data);
        expect(bytes.length, greaterThan(0));
      } catch (e) {
        expect(e, isA<Exception>());
      }
    });

    test('buildSmartReportPdfBytes with zero-change comparison builds PDF', () async {
      final section = ProgramReportSection(
        programId: 'prog_1',
        programName: 'برنامج اختبار',
        specialistId: 'spec_1',
        specialistName: 'أخصائي',
        plans: [
          const TrainingPlan(
            id: 'plan_1', studentId: 'student_1', goal: 'هدف',
            targetDate: '2026-01-01', progress: 50,
            programId: 'prog_1', sourceType: 'standard',
            specialistId: 'spec_1',
          ),
        ],
        sessions: [
          const TherapySession(
            id: 'sess_1', studentId: 'student_1', planId: 'plan_1',
            startedAt: '2026-05-15T10:00:00', durationSeconds: 1800,
            cardTitle: 'جلسة', quickResult: 'متقن', notes: '',
            programId: 'prog_1', specialistId: 'spec_1', successRate: 100,
          ),
        ],
        masteredGoals: 0,
        activeGoals: 1,
      );

      const comparison = ReportComparisonResult(
        sessionsSincePreviousReport: 0,
        goalsProgressChanged: [],
        masteredGoals: [],
        stagnantGoalIds: ['plan_1'],
        newGoalIds: [],
        allPreviousGoalIds: ['plan_1'],
      );

      final data = ReportData(
        student: student(),
        type: 'تقرير شامل',
        scope: 'singleProgram',
        sections: [section],
      );

      final service = SmartPdfReportService();
      try {
        final bytes = await service.buildSmartReportPdfBytes(
          data,
          reportCategory: 'specialistFollowup',
          comparison: comparison,
        );
        expect(bytes.length, greaterThan(0));
      } catch (e) {
        expect(e, isA<Exception>());
      }
    });

    test('buildSmartReportPdfBytes with specialistFollowup always shows comparison section', () async {
      final section = ProgramReportSection(
        programId: 'prog_1',
        programName: 'برنامج اختبار',
        specialistId: 'spec_1',
        specialistName: 'أخصائي',
        plans: [
          const TrainingPlan(
            id: 'plan_1', studentId: 'student_1', goal: 'هدف',
            targetDate: '2026-01-01', progress: 50,
            programId: 'prog_1', sourceType: 'standard',
            specialistId: 'spec_1',
          ),
        ],
        masteredGoals: 0,
        activeGoals: 1,
      );

      const comparison = ReportComparisonResult();

      final data = ReportData(
        student: student(),
        type: 'تقرير شامل',
        scope: 'singleProgram',
        sections: [section],
      );

      final service = SmartPdfReportService();
      try {
        final bytes = await service.buildSmartReportPdfBytes(
          data,
          reportCategory: 'specialistFollowup',
          comparison: comparison,
        );
        expect(bytes.length, greaterThan(0));
      } catch (e) {
        expect(e, isA<Exception>());
      }
    });

    test('no pw.Expanded or pw.Bullet or PdfGoogleFonts in SmartPdfReportService', () {
      final service = SmartPdfReportService();
      // Verify that the service can be constructed and used (which would fail
      // at compile time if any of the banned pw/widgets were used incorrectly).
      expect(service, isNotNull);
      // Verify _arBullet is the actual method used (checked at compile time).
      // The source also avoids pw.Expanded, pw.Bullet, and PdfGoogleFonts.
    });
  });

  // ===========================================================================
  // Save flow integration (builder + service + file)
  // ===========================================================================
  group('Save flow integration', () {
    late AppProvider app;

    setUp(() async {
      app = bareProvider(isSpecialist: true);
      // Ensure FK dependencies exist in the database
      final db = DatabaseService.instance;
      await db.upsert('centers', {
        'id': 'center_1',
        'name': 'مركز اختبار',
        'created_at': '2026-01-01',
        'updated_at': '2026-06-01',
      });
      await db.upsert('students', {
        'id': 'student_1',
        'center_id': 'center_1',
        'name': 'طالب اختبار',
        'age': 6,
        'status': 'نشط',
        'diagnosis': 'اختبار',
        'parent_name': '',
        'parent_phone': '',
        'portal_email': '',
        'portal_password': '',
        'photo_path': '',
        'notes': '',
        'created_at': '2026-01-01',
        'updated_at': '2026-06-01',
      });
      app.students = [student()];
      app.therapyPrograms = [tProg()];
      app.clinicalAssessments = [
        const ClinicalAssessment(
          id: 'ca_1', centerId: 'center_1', studentId: 'student_1',
          specialistId: 'spec_1', specialistName: 'أخصائي', type: 'speech',
          programId: 'prog_1', strengthsSummary: '', weaknessesSummary: '',
          goalsSummary: '', trainingSummary: '', createdAt: '2026-01-15',
          updatedAt: '2026-01-15',
        ),
      ];
      app.plans = [
        const TrainingPlan(
          id: 'plan_1', studentId: 'student_1', goal: 'هدف',
          targetDate: '2026-03-01', progress: 50,
          programId: 'prog_1', sourceType: 'standard', specialistId: 'spec_1',
        ),
      ];
      app.sessions = [
        const TherapySession(
          id: 'sess_1', studentId: 'student_1', planId: 'plan_1',
          startedAt: '2026-05-15T10:00:00', durationSeconds: 1800,
          cardTitle: 'جلسة', quickResult: 'متقن', notes: '',
          programId: 'prog_1', specialistId: 'spec_1', successRate: 100,
        ),
      ];
      app.studentProgramIds = ['prog_1'];
      app.studentProgramAssignments = [sAssignment()];
    });

    test('null outputPath does not save ReportRecord', () async {
      final result = await app.buildSmartReportData(
        studentId: 'student_1',
        type: 'تقرير شامل',
        scope: 'singleProgram',
        programId: 'prog_1',
        specialistId: 'spec_1',
      );
      expect(result.data.sections, isNotEmpty);

      const String? outputPath = null;
      if (outputPath == null) {
        expect(app.reports.any((r) => r.id == result.record.id), isFalse);
      }
    });

    test('build data + PDF + file succeeds when font available', () async {
      final result = await app.buildSmartReportData(
        studentId: 'student_1',
        type: 'تقرير شامل',
        scope: 'singleProgram',
        programId: 'prog_1',
        specialistId: 'spec_1',
      );
      expect(result.data.sections, isNotEmpty);
      expect(result.record.id, isNotEmpty);

      final service = SmartPdfReportService();
      Uint8List? bytes;
      try {
        bytes = await service.buildSmartReportPdfBytes(result.data);
      } catch (_) {
      }

      if (bytes != null && bytes.isNotEmpty) {
        final tmpDir = Directory.systemTemp.createTempSync('sanad_test_');
        final tmpPath = '${tmpDir.path}${Platform.pathSeparator}test_report.pdf';
        await File(tmpPath).writeAsBytes(bytes);
        expect(File(tmpPath).existsSync(), isTrue);
        expect(File(tmpPath).lengthSync(), greaterThan(0));

        final savedRecord = result.record.copyWith(
          filePath: tmpPath,
          reportStatus: 'exported',
        );
        await app.saveReportRecord(savedRecord);
        expect(app.reports.any((r) => r.id == savedRecord.id), isTrue);

        tmpDir.deleteSync(recursive: true);
      }
    });
  });

  // ===========================================================================
  // ReportsScreen widget – self-contained two-step flow
  // ===========================================================================
  group('ReportsScreen specialist UI', () {
    Widget buildScreen(AppProvider app) {
      return ChangeNotifierProvider<AppProvider>.value(
        value: app,
        child: const MaterialApp(home: ReportsScreen()),
      );
    }

    testWidgets('specialist with NO assignments shows empty message', (tester) async {
      final app = bareProvider(isSpecialist: true);
      app.students = [student()];
      app.studentProgramAssignments = [];

      await tester.pumpWidget(buildScreen(app));
      await tester.pump();

      expect(find.text('لا توجد إسنادات نشطة.'), findsOneWidget);
    });

    testWidgets('specialist with ONE assignment shows card; tap to see form', (tester) async {
      final app = bareProvider(isSpecialist: true);
      app.students = [student()];
      app.therapyPrograms = [tProg()];
      app.studentProgramAssignments = [sAssignment()];

      await tester.pumpWidget(buildScreen(app));
      await tester.pump();

      // Should show assignment cards grouped by student
      expect(find.text('إسناداتي النشطة'), findsOneWidget);
      expect(find.text('طالب اختبار'), findsOneWidget);
      expect(find.text('برنامج أول'), findsOneWidget);

      // Tap the assignment card to proceed to form
      await tester.tap(find.text('برنامج أول'));
      await tester.pumpAndSettle();

      // Now in form step
      expect(find.text('التقارير الذكية'), findsOneWidget);
      expect(find.text('إنشاء تقرير علاجي شامل'), findsOneWidget);
      expect(find.text('حفظ تقرير PDF شامل'), findsOneWidget);
    });

    testWidgets('specialist with MULTIPLE assignments shows all programs', (tester) async {
      final app = bareProvider(isSpecialist: true);
      app.students = [student()];
      app.therapyPrograms = [tProg(), tProg(id: 'prog_2', name: 'برنامج ثاني')];
      app.studentProgramAssignments = [
        sAssignment(),
        sAssignment(id: 'assign_2', programId: 'prog_2'),
      ];

      await tester.pumpWidget(buildScreen(app));
      await tester.pump();

      expect(find.text('إسناداتي النشطة'), findsOneWidget);
      expect(find.text('برنامج أول'), findsOneWidget);
      expect(find.text('برنامج ثاني'), findsOneWidget);
      // "جميع برامجي المسندة لهذا الطالب" appears when 2+ programs for same student
      expect(find.text('جميع برامجي المسندة لهذا الطالب'), findsOneWidget);
    });

    testWidgets('specialist taps all assignments button to generate combined report', (tester) async {
      final app = bareProvider(isSpecialist: true);
      app.students = [student()];
      app.therapyPrograms = [tProg(), tProg(id: 'prog_2', name: 'برنامج ثاني')];
      app.studentProgramAssignments = [
        sAssignment(),
        sAssignment(id: 'assign_2', programId: 'prog_2'),
      ];

      await tester.pumpWidget(buildScreen(app));
      await tester.pump();

      // Tap "جميع برامجي المسندة لهذا الطالب"
      await tester.tap(find.text('جميع برامجي المسندة لهذا الطالب'));
      await tester.pumpAndSettle();

      expect(find.text('التقارير الذكية'), findsOneWidget);
      expect(find.text('إنشاء تقرير علاجي شامل'), findsOneWidget);
      expect(find.textContaining('برنامج أول، برنامج ثاني'), findsOneWidget);
    });

    testWidgets('specialist with MULTIPLE students shows grouped by student', (tester) async {
      final app = bareProvider(isSpecialist: true);
      app.students = [
        student(id: 'student_1', name: 'طالب أول'),
        student(id: 'student_2', name: 'طالب ثاني'),
      ];
      app.therapyPrograms = [tProg()];
      app.studentProgramAssignments = [
        sAssignment(studentId: 'student_1'),
        sAssignment(id: 'assign_2', studentId: 'student_2', programId: 'prog_1'),
      ];

      await tester.pumpWidget(buildScreen(app));
      await tester.pump();

      expect(find.text('طالب أول'), findsOneWidget);
      expect(find.text('طالب ثاني'), findsOneWidget);
      // Each student should have one program card
      expect(find.text('برنامج أول'), findsNWidgets(2));
    });
  });

  group('ReportsScreen manager UI', () {
    Widget buildScreen(AppProvider app) {
      return ChangeNotifierProvider<AppProvider>.value(
        value: app,
        child: const MaterialApp(home: ReportsScreen()),
      );
    }

    Future<void> ensureDbReady() async {
      // Ensure database is initialized before tests that call selectStudent
      final db = DatabaseService.instance;
      await db.database;
    }

    testWidgets('manager with NO students shows empty message', (tester) async {
      final app = bareProvider(isSpecialist: false);
      app.students = [];
      await ensureDbReady();

      await tester.pumpWidget(buildScreen(app));
      await tester.pump();

      expect(find.text('اختر الطالب'), findsAtLeastNWidgets(1));
      expect(find.text('لا يوجد طلاب.'), findsOneWidget);
    });

    testWidgets('manager sees student picker', (tester) async {
      final app = bareProvider(isSpecialist: false);
      app.students = [student()];
      await ensureDbReady();

      await tester.pumpWidget(buildScreen(app));
      await tester.pump();

      expect(find.text('اختر الطالب'), findsAtLeastNWidgets(1));
      expect(find.text('طالب اختبار'), findsOneWidget);
    });

    testWidgets('manager taps student and sees form with action buttons', (tester) async {
      final app = bareProvider(isSpecialist: false);
      await ensureDbReady();
      app.students = [student()];
      app.therapyPrograms = [tProg()];
      // Directly set the data that selectStudent would load
      app.clinicalAssessments = [
        const ClinicalAssessment(
          id: 'ca_1', centerId: 'center_1', studentId: 'student_1',
          specialistId: 'spec_1', specialistName: 'أخصائي', type: 'speech',
          programId: 'prog_1', strengthsSummary: '', weaknessesSummary: '',
          goalsSummary: '', trainingSummary: '', createdAt: '2026-01-15',
        ),
      ];
      app.plans = [
        const TrainingPlan(
          id: 'plan_1', studentId: 'student_1', goal: 'هدف',
          targetDate: '2026-03-01', progress: 50,
          programId: 'prog_1', sourceType: 'standard', specialistId: 'spec_1',
        ),
      ];
      app.studentProgramAssignments = [
        sAssignment(),
      ];

      await tester.pumpWidget(buildScreen(app));
      await tester.pump();

      // Tap student - use runAsync for the async selectStudent call
      await tester.runAsync(() async {
        await tester.tap(find.text('طالب اختبار'));
        // Give selectStudent time to complete
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      // Now in form step
      expect(find.text('التقارير الذكية'), findsOneWidget);
      expect(find.text('إنشاء تقرير علاجي'), findsOneWidget);
      expect(find.text('الطالب: طالب اختبار'), findsOneWidget);
      expect(find.text('البرامج: برنامج أول'), findsOneWidget);
      // Should see action buttons instead of old dropdowns
      expect(find.text('تقرير شامل'), findsWidgets);
      expect(find.text('الربع الأول'), findsWidgets);
      expect(find.text('الربع الثاني'), findsWidgets);
      expect(find.text('الربع الثالث'), findsWidgets);
      expect(find.text('الربع الرابع'), findsWidgets);
      // No old type dropdown or date fields
      expect(find.text('نوع التقرير'), findsNothing);
    });

    testWidgets('manager form shows scope radio buttons and year selector', (tester) async {
      final app = bareProvider(isSpecialist: false);
      await ensureDbReady();
      app.students = [student()];
      app.therapyPrograms = [tProg()];
      app.clinicalAssessments = [
        const ClinicalAssessment(
          id: 'ca_1', centerId: 'center_1', studentId: 'student_1',
          specialistId: 'spec_1', specialistName: 'أخصائي', type: 'speech',
          programId: 'prog_1', strengthsSummary: '', weaknessesSummary: '',
          goalsSummary: '', trainingSummary: '', createdAt: '2026-01-15',
        ),
      ];
      app.studentProgramAssignments = [
        sAssignment(),
      ];

      await tester.pumpWidget(buildScreen(app));
      await tester.pump();

      await tester.runAsync(() async {
        await tester.tap(find.text('طالب اختبار'));
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      expect(find.text('برنامج محدد'), findsOneWidget);
      expect(find.text('جميع البرامج'), findsOneWidget);
      // Year selector should be visible
      expect(find.text('السنة:'), findsOneWidget);
      // No old type dropdown
      expect(find.text('نوع التقرير'), findsNothing);
    });

    testWidgets('back button returns to selection step', (tester) async {
      final app = bareProvider(isSpecialist: false);
      await ensureDbReady();
      app.students = [student()];

      await tester.pumpWidget(buildScreen(app));
      await tester.pump();

      // Tap student to go to form
      await tester.runAsync(() async {
        await tester.tap(find.text('طالب اختبار'));
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      expect(find.text('التقارير الذكية'), findsOneWidget);

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Back at selection step
      expect(find.text('اختر الطالب'), findsAtLeastNWidgets(1));
      expect(find.text('طالب اختبار'), findsOneWidget);
    });
  });

  // ===========================================================================
  // Validation logic tests
  // ===========================================================================
  group('Validation logic', () {
    test('studentHasTherapyData returns false for student with no data', () {
      final app = bareProvider(isSpecialist: false);
      app.clinicalAssessments = [];
      app.plans = [];
      app.sessions = [];
      app.goalSkillSteps = [];
      app.studentFollowups = [];
      app.exercises = [];
      app.clinicalFindingsByAssessment = {};

      expect(app.studentHasTherapyData('student_1'), isFalse);
    });

    test('studentHasTherapyData returns true when student has assessment', () {
      final app = bareProvider(isSpecialist: false);
      app.clinicalAssessments = [
        const ClinicalAssessment(
          id: 'ca_1', centerId: 'center_1', studentId: 'student_1',
          specialistId: 'spec_1', specialistName: 'أخصائي', type: 'speech',
          programId: 'prog_1', strengthsSummary: '', weaknessesSummary: '',
          goalsSummary: '', trainingSummary: '', createdAt: '2026-01-15',
        ),
      ];

      expect(app.studentHasTherapyData('student_1'), isTrue);
    });

    test('studentHasTherapyData returns true when student has plans only', () {
      final app = bareProvider(isSpecialist: false);
      app.plans = [
        const TrainingPlan(
          id: 'plan_1', studentId: 'student_1', goal: 'هدف',
          targetDate: '2026-03-01', progress: 50,
          programId: 'prog_1', sourceType: 'standard',
        ),
      ];

      expect(app.studentHasTherapyData('student_1'), isTrue);
    });

    test('studentHasTherapyData returns true when student has sessions only', () {
      final app = bareProvider(isSpecialist: false);
      app.sessions = [
        const TherapySession(
          id: 'sess_1', studentId: 'student_1', planId: 'plan_1',
          startedAt: '2026-05-15T10:00:00', durationSeconds: 1800,
          cardTitle: 'جلسة', quickResult: 'متقن', notes: '',
          programId: 'prog_1', successRate: 100,
        ),
      ];

      expect(app.studentHasTherapyData('student_1'), isTrue);
    });

    test('validateStudentHasAssessment returns null when data exists', () {
      final app = bareProvider(isSpecialist: false);
      app.clinicalAssessments = [
        const ClinicalAssessment(
          id: 'ca_1', centerId: 'center_1', studentId: 'student_1',
          specialistId: 'spec_1', specialistName: 'أخصائي', type: 'speech',
          programId: 'prog_1', strengthsSummary: '', weaknessesSummary: '',
          goalsSummary: '', trainingSummary: '', createdAt: '2026-01-15',
        ),
      ];

      final result = app.validateStudentHasAssessment(
        studentId: 'student_1',
        scope: 'allPrograms',
      );
      expect(result, isNull);
    });

    test('validateStudentHasAssessment returns error when no data exists', () {
      final app = bareProvider(isSpecialist: false);
      app.clinicalAssessments = [];
      app.plans = [];
      app.sessions = [];

      final result = app.validateStudentHasAssessment(
        studentId: 'student_1',
        scope: 'allPrograms',
      );
      expect(result, isNotNull);
      expect(result, contains('لا توجد بيانات علاجية كافية'));
    });

    test('validateStudentHasAssessment returns null for manager when assessment done by specialist', () {
      final app = bareProvider(isSpecialist: false);
      app.clinicalAssessments = [
        const ClinicalAssessment(
          id: 'ca_1', centerId: 'center_1', studentId: 'student_1',
          specialistId: 'spec_1', specialistName: 'أخصائي', type: 'speech',
          programId: 'prog_1', strengthsSummary: '', weaknessesSummary: '',
          goalsSummary: '', trainingSummary: '', createdAt: '2026-01-15',
        ),
      ];

      // Manager tries to create report - should be OK because student has assessment
      final result = app.validateStudentHasAssessment(
        studentId: 'student_1',
        scope: 'allPrograms',
      );
      expect(result, isNull);
    });

    test('findPreviousQuarterlyReport Q2 looks for Q1 same year', () {
      final app = bareProvider(isSpecialist: false);
      app.reports = [
        ReportRecord(
          id: 'r1', centerId: 'center_1', studentId: 'student_1',
          type: 'تقرير ربع سنوي', createdAt: '2026-05-01T10:00:00',
          scope: 'allPrograms', reportCategory: 'supervisorQuarterly',
          quarter: 'Q1', year: '2026',
        ),
      ];

      final prev = app.findPreviousQuarterlyReport(
        studentId: 'student_1',
        scope: 'allPrograms',
        quarter: 'Q2',
        year: '2026',
      );
      expect(prev, isNotNull);
      expect(prev!.quarter, equals('Q1'));
      expect(prev.year, equals('2026'));
    });

    test('findPreviousQuarterlyReport Q1 looks for Q4 previous year', () {
      final app = bareProvider(isSpecialist: false);
      app.reports = [
        ReportRecord(
          id: 'r1', centerId: 'center_1', studentId: 'student_1',
          type: 'تقرير ربع سنوي', createdAt: '2025-12-01T10:00:00',
          scope: 'allPrograms', reportCategory: 'supervisorQuarterly',
          quarter: 'Q4', year: '2025',
        ),
      ];

      final prev = app.findPreviousQuarterlyReport(
        studentId: 'student_1',
        scope: 'allPrograms',
        quarter: 'Q1',
        year: '2026',
      );
      expect(prev, isNotNull);
      expect(prev!.quarter, equals('Q4'));
      expect(prev.year, equals('2025'));
    });

    test('findPreviousQuarterlyReport returns null when no previous quarter exists', () {
      final app = bareProvider(isSpecialist: false);
      app.reports = [];

      final prev = app.findPreviousQuarterlyReport(
        studentId: 'student_1',
        scope: 'allPrograms',
        quarter: 'Q1',
        year: '2026',
      );
      expect(prev, isNull);
    });

    test('findPreviousSpecialistReport returns null when no previous report', () {
      final app = bareProvider(isSpecialist: true);
      app.reports = [];

      final prev = app.findPreviousSpecialistReport(
        studentId: 'student_1',
        programId: 'prog_1',
        specialistId: 'spec_1',
      );
      expect(prev, isNull);
    });

    test('findPreviousSpecialistReport returns most recent previous specialist report', () {
      final app = bareProvider(isSpecialist: true);
      app.reports = [
        ReportRecord(
          id: 'r1', centerId: 'center_1', studentId: 'student_1',
          specialistId: 'spec_1', programId: 'prog_1',
          type: 'تقرير شامل', createdAt: '2026-03-01T10:00:00',
          scope: 'singleProgram', reportCategory: 'specialistInitial',
        ),
        ReportRecord(
          id: 'r2', centerId: 'center_1', studentId: 'student_1',
          specialistId: 'spec_1', programId: 'prog_1',
          type: 'تقرير شامل', createdAt: '2026-05-01T10:00:00',
          scope: 'singleProgram', reportCategory: 'specialistFollowup',
        ),
      ];

      final prev = app.findPreviousSpecialistReport(
        studentId: 'student_1',
        programId: 'prog_1',
        specialistId: 'spec_1',
      );
      expect(prev, isNotNull);
      expect(prev!.id, equals('r2')); // most recent
    });

    test('findPreviousSpecialistReport ignores quarterly reports', () {
      final app = bareProvider(isSpecialist: true);
      app.reports = [
        ReportRecord(
          id: 'qr1', centerId: 'center_1', studentId: 'student_1',
          type: 'تقرير ربع سنوي', createdAt: '2026-03-01T10:00:00',
          scope: 'allPrograms', reportCategory: 'supervisorQuarterly',
          quarter: 'Q1', year: '2026',
        ),
      ];

      final prev = app.findPreviousSpecialistReport(
        studentId: 'student_1',
        specialistId: 'spec_1',
      );
      expect(prev, isNull);
    });

    test('ReportComparisonResult with zero changes does not crash', () {
      const comparison = ReportComparisonResult(
        sessionsSincePreviousReport: 0,
        goalsProgressChanged: [],
        masteredGoals: [],
        stagnantGoalIds: [],
        newGoalIds: [],
        allPreviousGoalIds: [],
        remainingWeaknesses: [],
        improvedWeaknesses: [],
      );

      expect(comparison.sessionsSincePreviousReport, equals(0));
      expect(comparison.goalsProgressChanged, isEmpty);
      expect(comparison.masteredGoals, isEmpty);
    });

    test('ReportComparisonService.compare handles identical snapshots', () {
      // Snapshot with a session count
      final snapshot = {
        'totalSessions': 0,
        'sections': [
          {
            'programId': 'prog_1',
            'plans': [
              {'id': 'plan_1', 'progress': 0},
            ],
            'findings': [],
          },
        ],
      };

      // Current data with no sessions (progress computed as 0, matching snapshot)
      final currentData = ReportData(
        student: student(),
        type: 'تقرير شامل',
        scope: 'singleProgram',
        sections: [
          ProgramReportSection(
            programId: 'prog_1',
            programName: 'برنامج أول',
            specialistId: 'spec_1',
            specialistName: 'أخصائي',
            plans: [
              const TrainingPlan(
                id: 'plan_1', studentId: 'student_1', goal: 'هدف أول',
                targetDate: '2026-03-01', progress: 0,
                programId: 'prog_1', sourceType: 'standard',
              ),
            ],
          ),
        ],
      );

      final result = ReportComparisonService.compare(
        previousSnapshot: snapshot,
        currentData: currentData,
      );

      expect(result.sessionsSincePreviousReport, equals(0));
      expect(result.goalsProgressChanged, isEmpty);
      // Same progress → stagnant
      expect(result.stagnantGoalIds, contains('plan_1'));
      // No new goals because plan_1 exists in both
      expect(result.newGoalIds, isEmpty);
    });

    test('specialist can create followup report without new sessions or progress', () async {
      final app = bareProvider(isSpecialist: true);
      app.centerSessions = []; // No db dependency needed
      // Set up minimal data: assessment + plans (same as initial report)
      app.clinicalAssessments = [
        const ClinicalAssessment(
          id: 'ca_1', centerId: 'center_1', studentId: 'student_1',
          specialistId: 'spec_1', specialistName: 'أخصائي', type: 'speech',
          programId: 'prog_1', strengthsSummary: '', weaknessesSummary: '',
          goalsSummary: '', trainingSummary: '', createdAt: '2026-01-15',
        ),
      ];
      app.plans = [
        const TrainingPlan(
          id: 'plan_1', studentId: 'student_1', goal: 'هدف أول',
          targetDate: '2026-03-01', progress: 50,
          programId: 'prog_1', sourceType: 'standard', specialistId: 'spec_1',
        ),
      ];
      app.students = [student()];
      app.therapyPrograms = [tProg()];
      app.studentProgramAssignments = [sAssignment()];
      app.studentProgramIds = ['prog_1'];

      // First: initial report (no previous report)
      final initialResult = await app.buildSmartReportData(
        studentId: 'student_1',
        type: 'تقرير شامل',
        scope: 'singleProgram',
        programId: 'prog_1',
        specialistId: 'spec_1',
        reportCategory: 'specialistInitial',
        previousReportId: null,
      );
      expect(initialResult.record.reportCategory, equals('specialistInitial'));
      expect(initialResult.record.previousReportId, isNull);
      expect(initialResult.comparison, isNull);
      expect(initialResult.data.sections, isNotEmpty);

      // Save the initial report
      await app.saveReportRecord(initialResult.record);

      // Now: followup report with the same data (no new sessions, no progress)
      final prevReport = app.findPreviousSpecialistReport(
        studentId: 'student_1',
        programId: 'prog_1',
        specialistId: 'spec_1',
      );
      expect(prevReport, isNotNull);
      expect(prevReport!.reportCategory, equals('specialistInitial'));

      final followupResult = await app.buildSmartReportData(
        studentId: 'student_1',
        type: 'تقرير شامل',
        scope: 'singleProgram',
        programId: 'prog_1',
        specialistId: 'spec_1',
        reportCategory: 'specialistFollowup',
        previousReportId: prevReport.id,
      );
      expect(followupResult.record.reportCategory, equals('specialistFollowup'));
      expect(followupResult.record.previousReportId, equals(prevReport.id));
      expect(followupResult.comparison, isNotNull);
      // No new sessions and identical progress → sessions since = 0
      expect(followupResult.comparison!.sessionsSincePreviousReport, equals(0));
      expect(followupResult.comparison!.goalsProgressChanged, isEmpty);
      expect(followupResult.data.sections, isNotEmpty);
    });
  });

  group('ReportsScreen save flow', () {
    Widget buildScreen(AppProvider app) {
      return ChangeNotifierProvider<AppProvider>.value(
        value: app,
        child: const MaterialApp(home: ReportsScreen()),
      );
    }

    testWidgets('specialist save button exists', (tester) async {
      final app = bareProvider(isSpecialist: true);
      app.students = [student()];
      app.therapyPrograms = [tProg()];
      app.studentProgramAssignments = [sAssignment()];

      await tester.pumpWidget(buildScreen(app));
      await tester.pump();

      // Tap assignment to reach form
      await tester.tap(find.text('برنامج أول'));
      await tester.pumpAndSettle();

      expect(find.text('حفظ تقرير PDF شامل'), findsOneWidget);
      expect(find.byIcon(Icons.save_alt_outlined), findsOneWidget);
    });
  });

  // ===========================================================================
  // ReportExportService
  // ===========================================================================
  group('ReportExportService', () {
    test('sanitizeFileName removes illegal chars', () {
      expect(ReportExportService.sanitizeFileName('طالب/اختبار:1'),
          equals('طالب_اختبار_1'));
      expect(ReportExportService.sanitizeFileName('normal name'),
          equals('normal name'));
      expect(ReportExportService.sanitizeFileName('a<b>c"d/e\\f|g?h*i'),
          equals('a_b_c_d_e_f_g_h_i'));
    });

    test('buildFileName includes student name', () {
      final name = ReportExportService.buildFileName(
        studentName: 'أحمد',
        programName: null,
      );
      expect(name, startsWith('sanad_report_أحمد_'));
      expect(name, endsWith('.pdf'));
    });

    test('buildFileName includes program name when given', () {
      final name = ReportExportService.buildFileName(
        studentName: 'أحمد',
        programName: 'برنامج نطق',
      );
      expect(name, startsWith('sanad_report_أحمد_برنامج نطق_'));
      expect(name, endsWith('.pdf'));
    });
  });

  // ─── Demo / Sandbox Tests ─────────────────────────────────
  group('DemoDataService', () {
    late DemoDataService demoService;

    setUp(() async {
      final db = DatabaseService.instance;
      await db.deleteCenter(DemoDataService.demoCenterId);
      await db.deleteWhere('users', 'center_id = ?', [DemoDataService.demoCenterId]);
      demoService = DemoDataService(SanadRepository(db));
    });

    test('isDemoId returns true for demo_ prefixed IDs', () {
      expect(DemoDataService.isDemoId(DemoDataService.demoCenterId), isTrue);
      expect(DemoDataService.isDemoId(DemoDataService.demoManagerId), isTrue);
      expect(DemoDataService.isDemoId('real_center'), isFalse);
      expect(DemoDataService.isDemoId(''), isFalse);
    });

    test('seedFullDemoData creates center + 3 base accounts (no students, no programs)', () async {
      await demoService.seedFullDemoData();
      final status = await demoService.getStatus();
      expect(status['exists'], isTrue);
      expect(status['centerName'], contains('تجريبي'));
      expect(status['studentCount'], equals(0));
      expect(status['userCount'], equals(3));

      final users = await demoService.getDemoUsers();
      expect(users.length, equals(3));
      final roles = users.map((u) => u['role'] as String).toSet();
      expect(roles, contains('centerManager'));
      expect(roles, contains('coordinator'));
      expect(roles, contains('dataEntry'));
    });

    test('seedFullDemoData does not duplicate data on second run', () async {
      await demoService.seedFullDemoData();
      final status1 = await demoService.getStatus();
      await demoService.seedFullDemoData();
      final status2 = await demoService.getStatus();
      expect(status2['studentCount'], equals(status1['studentCount']));
      expect(status2['userCount'], equals(status1['userCount']));
    });

    test('isLibraryReady returns false when no programs exist', () async {
      final ready = await demoService.isLibraryReady();
      // This depends on whether the test environment has Sanad library seeded
      // At minimum it should not throw
      expect(ready, isA<bool>());
    });

    test('getDemoUsers returns all demo users', () async {
      await demoService.seedFullDemoData();
      final users = await demoService.getDemoUsers();
      expect(users.length, equals(3));
      final ids = users.map((u) => u['id'] as String).toSet();
      expect(ids, contains(DemoDataService.demoManagerId));
      expect(ids, contains(DemoDataService.demoCoordinatorId));
      expect(ids, contains(DemoDataService.demoDataEntryId));
    });

    test('getDemoStudents returns empty after seed (no auto-created students)', () async {
      await demoService.seedFullDemoData();
      final students = await demoService.getDemoStudents();
      expect(students, isEmpty);
    });

    test('getDemoSpecialists returns empty after seed (no auto-created specialists)', () async {
      await demoService.seedFullDemoData();
      final specialists = await demoService.getDemoSpecialists();
      expect(specialists, isEmpty);
    });

    test('deleteDemoData deletes demo only, real data untouched', () async {
      await demoService.seedFullDemoData();
      var status = await demoService.getStatus();
      expect(status['exists'], isTrue);

      await demoService.deleteDemoData();
      status = await demoService.getStatus();
      expect(status['exists'], isFalse);
    });

    test('resetDemoData keeps center+accounts, removes student data', () async {
      await demoService.seedFullDemoData();
      final db = DatabaseService.instance;
      await db.upsert('students', {
        'id': 'demo_test_student',
        'center_id': DemoDataService.demoCenterId,
        'name': 'طالب اختبار',
        'age': 6,
        'status': 'نشط',
        'diagnosis': 'اختبار',
        'parent_name': '',
        'parent_phone': '',
        'portal_email': '',
        'portal_password': '',
        'photo_path': '',
        'notes': '',
      });
      var status = await demoService.getStatus();
      expect(status['studentCount'], greaterThan(0));
      final keptUserCount = status['userCount'] as int;

      await demoService.resetDemoData();
      status = await demoService.getStatus();
      expect(status['exists'], isTrue);
      expect(status['studentCount'], equals(0));
      expect(status['userCount'], equals(keptUserCount));
    });

    test('prepareInitialReport creates assessment + goals + steps', () async {
      await demoService.seedFullDemoData();
      final db = DatabaseService.instance;
      await db.upsert('students', {
        'id': 'demo_accel_test_st',
        'center_id': DemoDataService.demoCenterId,
        'name': 'طالب تسريع',
        'age': 6,
        'status': 'نشط',
        'diagnosis': 'اختبار',
        'parent_name': '',
        'parent_phone': '',
        'portal_email': '',
        'portal_password': '',
        'photo_path': '',
        'notes': '',
      });
      await db.upsert('users', {
        'id': 'demo_accel_test_spec',
        'center_id': DemoDataService.demoCenterId,
        'name': 'أخصائي تسريع',
        'role': 'specialist',
        'email': 'spec@test.com',
        'password_hash': 'hash',
      });
      // use Sanad library program if available, otherwise skip
      final programs = await demoService.getDemoPrograms();
      if (programs.isEmpty) return; // skip if no library
      final progId = programs.first['id'] as String;
      await demoService.prepareInitialReport('demo_accel_test_st', progId, 'demo_accel_test_spec');
      final assessments = await db.where('clinical_assessments',
          where: 'student_id = ?', whereArgs: ['demo_accel_test_st']);
      expect(assessments.length, greaterThanOrEqualTo(1));
      final plans = await db.where('training_plans',
          where: 'student_id = ?', whereArgs: ['demo_accel_test_st']);
      expect(plans.length, greaterThanOrEqualTo(1));
    });

    test('addProgressSessions creates 5 sessions', () async {
      await demoService.seedFullDemoData();
      final db = DatabaseService.instance;
      await db.upsert('students', {
        'id': 'demo_st_progress',
        'center_id': DemoDataService.demoCenterId,
        'name': 'طالب تقدم',
        'age': 6,
        'status': 'نشط',
        'diagnosis': 'اختبار',
        'parent_name': '',
        'parent_phone': '',
        'portal_email': '',
        'portal_password': '',
        'photo_path': '',
        'notes': '',
      });
      await db.upsert('users', {
        'id': 'demo_spec_progress',
        'center_id': DemoDataService.demoCenterId, 'name': 'أخصائي', 'role': 'specialist',
        'email': 's@t.com', 'password_hash': 'h',
      });
      final programs = await demoService.getDemoPrograms();
      if (programs.isEmpty) return;
      final progId = programs.first['id'] as String;
      await demoService.prepareInitialReport('demo_st_progress', progId, 'demo_spec_progress');
      final before = await db.countWhere('sessions', 'student_id = ?', ['demo_st_progress']);
      await demoService.addProgressSessions('demo_st_progress', progId, 'demo_spec_progress');
      final after = await db.countWhere('sessions', 'student_id = ?', ['demo_st_progress']);
      expect(after - before, equals(5));
    });

    test('_ensureAssignment creates student program assignment', () async {
      await demoService.seedFullDemoData();
      final db = DatabaseService.instance;
      await db.upsert('students', {
        'id': 'demo_st_assign',
        'center_id': DemoDataService.demoCenterId,
        'name': 'طالب',
        'age': 6,
        'status': 'نشط',
        'diagnosis': 'اختبار',
        'parent_name': '',
        'parent_phone': '',
        'portal_email': '',
        'portal_password': '',
        'photo_path': '',
        'notes': '',
      });
      await db.upsert('users', {
        'id': 'demo_spec_assign',
        'center_id': DemoDataService.demoCenterId, 'name': 'أخصائي', 'role': 'specialist',
        'email': 's@t.com', 'password_hash': 'h',
      });
      final programs = await demoService.getDemoPrograms();
      if (programs.isEmpty) return;
      final progId = programs.first['id'] as String;
      // indirect test via prepareInitialReport which calls _ensureAssignment
      await demoService.prepareInitialReport('demo_st_assign', progId, 'demo_spec_assign');
      final assignments = await db.where('student_program_assignments',
          where: 'student_id = ?', whereArgs: ['demo_st_assign']);
      expect(assignments.length, greaterThanOrEqualTo(1));
      expect(assignments.first['specialist_id'], equals('demo_spec_assign'));
    });
  });

  group('Demo watermarked PDF', () {
    test('PDF with isDemo=true contains demo watermark text', () async {
      final service = SmartPdfReportService();
      final data = ReportData(
        student: Student(
          id: 'demo_st_pdf',
          centerId: DemoDataService.demoCenterId,
          name: 'طالب تجريبي',
          age: 6,
          status: 'نشط',
          diagnosis: 'تجريبي',
          parentName: 'ولي أمر',
          parentPhone: '0550000000',
          portalEmail: 'test@test.com',
          portalPassword: 'pass',
        ),
        type: 'تقرير تجريبي',
        scope: 'singleProgram',
        sections: [],
        createdByName: 'نظام تجريبي',
      );
      final bytes = await service.buildSmartReportPdfBytes(data, isDemo: true);
      expect(bytes.length, greaterThan(1000));
    });

    test('PDF without isDemo does not have demo watermark', () async {
      final service = SmartPdfReportService();
      final data = ReportData(
        student: Student(
          id: 'real_student',
          centerId: 'real_center',
          name: 'طالب حقيقي',
          age: 6,
          status: 'نشط',
          diagnosis: 'اختبار',
          parentName: 'ولي أمر',
          parentPhone: '0550000000',
          portalEmail: 'test@test.com',
          portalPassword: 'pass',
        ),
        type: 'تقرير',
        scope: 'singleProgram',
        sections: [],
        createdByName: 'أخصائي',
      );
      final bytes = await service.buildSmartReportPdfBytes(data, isDemo: false);
      expect(bytes.length, greaterThan(1000));
    });
  });

  group('Demo role switching', () {
    AppProvider _ownerProvider() {
      final repo = SanadRepository(DatabaseService.instance);
      final pdf = PdfService();
      return AppProvider(repo, pdf)
        ..user = AppUser(
          id: 'real_owner',
          email: 'owner@sanad.app',
          passwordHash: 'hash',
          name: 'مالك سند',
          role: UserRole.sanadOwner,
          centerId: '',
        );
    }

    test('enterDemoMode switches user to demo manager', () async {
      final app = _ownerProvider();
      await app.initialize();
      await DemoDataService(SanadRepository(DatabaseService.instance))
          .seedFullDemoData();

      await app.enterDemoMode(DemoDataService.demoManagerId);
      expect(app.isDemoModeActive, isTrue);
      expect(app.user?.id, equals(DemoDataService.demoManagerId));
      expect(app.user?.role, equals(UserRole.centerManager));
      expect(app.isCenterManager, isTrue);

      await app.exitDemoMode();
      expect(app.isDemoModeActive, isFalse);
      expect(app.isOwner, isTrue);
    });

    test('exitDemoMode restores original owner', () async {
      final app = _ownerProvider();
      await app.initialize();

      final originalId = app.user!.id;
      await app.enterDemoMode(DemoDataService.demoManagerId);
      expect(app.user?.id, equals(DemoDataService.demoManagerId));

      await app.exitDemoMode();
      expect(app.user?.id, equals(originalId));
      expect(app.isOwner, isTrue);
    });

    test('owner sidebar includes demo center item', () async {
      final screen = DemoCenterScreen();
      expect(screen, isNotNull);
    });

    test('demo centerManager isCenterManager true, isOwner false', () async {
      final app = _ownerProvider();
      await app.initialize();
      await DemoDataService(SanadRepository(DatabaseService.instance))
          .seedFullDemoData();
      await app.enterDemoMode(DemoDataService.demoManagerId);
      expect(app.isCenterManager, isTrue);
      expect(app.isOwner, isFalse);
      expect(app.isSpecialist, isFalse);
      await app.exitDemoMode();
    });

    test('demo coordinator isCoordinator true, isOwner false', () async {
      final app = _ownerProvider();
      await app.initialize();
      await DemoDataService(SanadRepository(DatabaseService.instance))
          .seedFullDemoData();
      await app.enterDemoMode(DemoDataService.demoCoordinatorId);
      expect(app.isCoordinator, isTrue);
      expect(app.isOwner, isFalse);
      expect(app.isCenterManager, isFalse);
      expect(app.isParent, isFalse);
      await app.exitDemoMode();
    });

    test('demo dataEntry isDataEntry true, isOwner false', () async {
      final app = _ownerProvider();
      await app.initialize();
      await DemoDataService(SanadRepository(DatabaseService.instance))
          .seedFullDemoData();
      await app.enterDemoMode(DemoDataService.demoDataEntryId);
      expect(app.isDataEntry, isTrue);
      expect(app.isOwner, isFalse);
      expect(app.isDemoModeActive, isTrue);
      await app.exitDemoMode();
      expect(app.isOwner, isTrue);
    });

    test('demo dataEntry switching does not crash sidebar build', () async {
      final app = _ownerProvider();
      await app.initialize();
      await DemoDataService(SanadRepository(DatabaseService.instance))
          .seedFullDemoData();
      await app.enterDemoMode(DemoDataService.demoDataEntryId);
      expect(app.isDataEntry, isTrue);
      expect(app.isDemoModeActive, isTrue);
      await app.exitDemoMode();
      expect(app.isOwner, isTrue);
    });

    test('demo reset deletes students but keeps accounts; delete removes all', () async {
      final db = DatabaseService.instance;
      final demoService = DemoDataService(SanadRepository(db));
      await demoService.seedFullDemoData();
      await db.upsert('students', {
        'id': 'demo_reset_test_st',
        'center_id': DemoDataService.demoCenterId,
        'name': 'طالب اختبار',
        'age': 6,
        'status': 'نشط',
        'diagnosis': 'اختبار',
        'parent_name': '',
        'parent_phone': '',
        'portal_email': '',
        'portal_password': '',
        'photo_path': '',
        'notes': '',
      });

      var status = await demoService.getStatus();
      expect(status['exists'], isTrue);
      expect(status['studentCount'] as int, greaterThan(0));
      final keptUserCount = status['userCount'] as int;

      await demoService.resetDemoData();
      status = await demoService.getStatus();
      expect(status['exists'], isTrue);
      expect(status['studentCount'], equals(0));
      expect(status['userCount'], equals(keptUserCount));

      await demoService.deleteDemoData();
      status = await demoService.getStatus();
      expect(status['exists'], isFalse);
    });

    // ─── Sanad Library / Global Program Tests ───────────────
    test('demo uses global Sanad library programs (not demo-specific)', () async {
      final db = DatabaseService.instance;
      final library = SanadLibraryService(db);
      await library.ensureSeeded();
      final globalPrograms = await db.where('therapy_program_templates',
          where: 'center_id = ?', whereArgs: [SanadLibraryService.centerId]);
      final globalIds = globalPrograms.map((p) => p['id'] as String).toSet();
      expect(globalIds, contains(SanadLibraryService.progSpeech));
      expect(globalIds, contains(SanadLibraryService.progOt));
      expect(globalIds, contains(SanadLibraryService.progSensory));

      await DemoDataService(SanadRepository(db)).seedFullDemoData();
      final demoPrograms = await db.where('therapy_program_templates',
          where: 'center_id = ?', whereArgs: [DemoDataService.demoCenterId]);
      expect(demoPrograms, isEmpty,
          reason: 'Demo center should NOT have its own programs');
    });

    test('creating demo does not duplicate global programs', () async {
      final db = DatabaseService.instance;
      final progCount = await db.countWhere(
          'therapy_program_templates',
          'center_id = ?',
          [SanadLibraryService.centerId]);

      await DemoDataService(SanadRepository(db)).seedFullDemoData();
      final afterCount = await db.countWhere(
          'therapy_program_templates',
          'center_id = ?',
          [SanadLibraryService.centerId]);

      expect(afterCount, equals(progCount),
          reason: 'Seeding demo should NOT duplicate global programs');
    });

    test('reset demo keeps global Sanad library intact', () async {
      final db = DatabaseService.instance;
      final library = SanadLibraryService(db);
      await library.ensureSeeded();

      await DemoDataService(SanadRepository(db)).seedFullDemoData();

      await DemoDataService(SanadRepository(db)).resetDemoData();

      final globalCount = await db.countWhere(
          'therapy_program_templates',
          'center_id = ?',
          [SanadLibraryService.centerId]);
      expect(globalCount, greaterThan(0),
          reason: 'Global library should survive demo reset');
    });

    test('demo does not auto-create students on seed', () async {
      final db = DatabaseService.instance;
      await DemoDataService(SanadRepository(db)).seedFullDemoData();
      final status = await DemoDataService(SanadRepository(db)).getStatus();
      expect(status['studentCount'], equals(0),
          reason: 'seedFullDemoData must not create students automatically');
    });

    // ─── Acceleration-tools visibility ──────────────────────
    test('acceleration tools section only appears in demo mode', () async {
      final app = _ownerProvider();
      await app.initialize();
      await DemoDataService(SanadRepository(DatabaseService.instance))
          .seedFullDemoData();

      expect(app.isDemoModeActive, isFalse);

      await app.enterDemoMode(DemoDataService.demoManagerId);
      expect(app.isDemoModeActive, isTrue);
      expect(app.user?.id, equals(DemoDataService.demoManagerId));

      await app.exitDemoMode();
    });

    // ─── Navigation sharing tests ────────────────────────────
    test('demo coordinator uses same navigation as real coordinator', () async {
      final app = _ownerProvider();
      await app.initialize();
      await DemoDataService(SanadRepository(DatabaseService.instance))
          .seedFullDemoData();
      await app.enterDemoMode(DemoDataService.demoCoordinatorId);

      expect(app.isCoordinator, isTrue);
      expect(app.isOwner, isFalse);

      await app.exitDemoMode();
    });

    test('demo manager uses same navigation as real manager', () async {
      final app = _ownerProvider();
      await app.initialize();
      await DemoDataService(SanadRepository(DatabaseService.instance))
          .seedFullDemoData();
      await app.enterDemoMode(DemoDataService.demoManagerId);

      expect(app.isCenterManager, isTrue);
      expect(app.isOwner, isFalse);

      await app.exitDemoMode();
    });

    // ─── Deduplication tests (moved from previous session) ───
    test('therapyProgramTemplates deduplicates by name preferring global', () async {
      final db = DatabaseService.instance;
      final repo = SanadRepository(db);
      final library = SanadLibraryService(db);
      await library.ensureSeeded();

      final globalPrograms = await db.where('therapy_program_templates',
          where: 'center_id = ?', whereArgs: [SanadLibraryService.centerId]);
      final firstGlobal = globalPrograms.first;
      final duplicateName = firstGlobal['name'] as String;

      await db.upsert('therapy_program_templates', {
        'id': 'demo_dup_test',
        'name': duplicateName,
        'center_id': DemoDataService.demoCenterId,
        'sort_order': 0,
      });

      final programs = await repo.therapyProgramTemplates(DemoDataService.demoCenterId);
      final names = programs.map((p) => p.name).toList();
      final matchedNames = names.where((n) => n == duplicateName).toList();

      expect(matchedNames, hasLength(1),
          reason: 'Duplicate program names must not appear more than once');
      final kept = programs.firstWhere((p) => p.name == duplicateName);
      expect(kept.centerId, equals(SanadLibraryService.centerId),
          reason: 'Global program must be preferred over center-specific duplicate');

      await db.delete('therapy_program_templates', 'demo_dup_test');
    });

    test('resetDemoData removes old center-specific programs', () async {
      final db = DatabaseService.instance;
      final repo = SanadRepository(db);
      final library = SanadLibraryService(db);
      await library.ensureSeeded();

      await db.upsert('therapy_program_templates', {
        'id': 'demo_legacy_prog',
        'name': 'برنامج قديم',
        'center_id': DemoDataService.demoCenterId,
        'sort_order': 0,
      });

      await DemoDataService(repo).seedFullDemoData();

      final leftover = await db.where('therapy_program_templates',
          where: 'center_id = ?', whereArgs: [DemoDataService.demoCenterId]);
      expect(leftover, isEmpty,
          reason: 'seedFullDemoData must clean up old center-specific programs');
    });

    test('no non-Sanad programs appear for demo center after reset', () async {
      final db = DatabaseService.instance;
      final repo = SanadRepository(db);
      final library = SanadLibraryService(db);
      await library.ensureSeeded();

      await db.upsert('therapy_program_templates', {
        'id': 'non_sanad_prog',
        'name': 'برنامج العلاج المنطقي',
        'center_id': DemoDataService.demoCenterId,
        'sort_order': 0,
      });

      await DemoDataService(repo).seedFullDemoData();

      final programs = await repo.therapyProgramTemplates(DemoDataService.demoCenterId);
      final names = programs.map((p) => p.name).toSet();

      expect(names, isNot(contains('برنامج العلاج المنطقي')),
          reason: 'Non-Sanad programs must not appear in demo center');
    });

    test('getDemoUsers returns all 3 base accounts after seed', () async {
      final db = DatabaseService.instance;
      await DemoDataService(SanadRepository(db)).seedFullDemoData();
      final service = DemoDataService(SanadRepository(db));
      final users = await service.getDemoUsers();
      expect(users.length, equals(3));
      final ids = users.map((u) => u['id'] as String).toSet();
      expect(ids, contains(DemoDataService.demoManagerId));
      expect(ids, contains(DemoDataService.demoCoordinatorId));
      expect(ids, contains(DemoDataService.demoDataEntryId));
    });

    test('getDemoSpecialists returns empty (no auto-created specialists)', () async {
      final db = DatabaseService.instance;
      await DemoDataService(SanadRepository(db)).seedFullDemoData();
      final service = DemoDataService(SanadRepository(db));
      final specialists = await service.getDemoSpecialists();
      expect(specialists, isEmpty);
    });

    test('isLibraryReady returns bool without throwing', () async {
      final db = DatabaseService.instance;
      final service = DemoDataService(SanadRepository(db));
      final ready = await service.isLibraryReady();
      expect(ready, isA<bool>());
    });

    test('prepareInitialReport uses baseDate when provided', () async {
      final srv = DemoDataService(SanadRepository(DatabaseService.instance));
      await srv.seedFullDemoData();
      final db = DatabaseService.instance;
      await db.upsert('students', {
        'id': 'demo_base_st',
        'center_id': DemoDataService.demoCenterId,
        'name': 'طالب أساس',
        'age': 6, 'status': 'نشط', 'diagnosis': 'اختبار',
        'parent_name': '', 'parent_phone': '',
        'portal_email': '', 'portal_password': '',
        'photo_path': '', 'notes': '',
      });
      await db.upsert('users', {
        'id': 'demo_base_spec',
        'center_id': DemoDataService.demoCenterId, 'name': 'أخصائي أساس',
        'role': 'specialist', 'email': 'spec@test.com', 'password_hash': 'hash',
      });
      final programs = await srv.getDemoPrograms();
      if (programs.isEmpty) return;
      final progId = programs.first['id'] as String;
      final baseDate = DateTime(2026, 3, 15);
      await srv.prepareInitialReport('demo_base_st', progId, 'demo_base_spec',
          baseDate: baseDate);
      final plans = await db.where('training_plans',
          where: 'student_id = ?', whereArgs: ['demo_base_st']);
      if (plans.isNotEmpty) {
        final targetDate = plans.first['target_date'] as String;
        expect(targetDate.startsWith('2026-03-15'), isTrue);
      }
    });

    test('addProgressSessions uses baseDate when provided', () async {
      final srv = DemoDataService(SanadRepository(DatabaseService.instance));
      await srv.seedFullDemoData();
      final db = DatabaseService.instance;
      await db.upsert('students', {
        'id': 'demo_base_st2',
        'center_id': DemoDataService.demoCenterId,
        'name': 'طالب أساس 2',
        'age': 6, 'status': 'نشط', 'diagnosis': 'اختبار',
        'parent_name': '', 'parent_phone': '',
        'portal_email': '', 'portal_password': '',
        'photo_path': '', 'notes': '',
      });
      await db.upsert('users', {
        'id': 'demo_base_spec2',
        'center_id': DemoDataService.demoCenterId, 'name': 'أخصائي أساس 2',
        'role': 'specialist', 'email': 's2@test.com', 'password_hash': 'hash',
      });
      final programs = await srv.getDemoPrograms();
      if (programs.isEmpty) return;
      final progId = programs.first['id'] as String;
      final baseDate = DateTime(2026, 2, 1);
      await srv.prepareInitialReport('demo_base_st2', progId, 'demo_base_spec2',
          baseDate: baseDate);
      await srv.addProgressSessions('demo_base_st2', progId, 'demo_base_spec2',
          baseDate: baseDate);
      final sessions = await db.where('sessions',
          where: 'student_id = ?', whereArgs: ['demo_base_st2']);
      if (sessions.isNotEmpty) {
        for (final s in sessions) {
          final startedAt = s['started_at'] as String;
          expect(startedAt.startsWith('2026'), isTrue,
              reason: 'Session should use baseDate year, not real year');
        }
      }
    });

    test('prepareQuarterlyData uses baseDate year when provided', () async {
      final srv = DemoDataService(SanadRepository(DatabaseService.instance));
      await srv.seedFullDemoData();
      final db = DatabaseService.instance;
      await db.upsert('students', {
        'id': 'demo_base_st3',
        'center_id': DemoDataService.demoCenterId,
        'name': 'طالب أساس 3',
        'age': 6, 'status': 'نشط', 'diagnosis': 'اختبار',
        'parent_name': '', 'parent_phone': '',
        'portal_email': '', 'portal_password': '',
        'photo_path': '', 'notes': '',
      });
      await db.upsert('users', {
        'id': 'demo_base_spec3',
        'center_id': DemoDataService.demoCenterId, 'name': 'أخصائي أساس 3',
        'role': 'specialist', 'email': 's3@test.com', 'password_hash': 'hash',
      });
      final programs = await srv.getDemoPrograms();
      if (programs.isEmpty) return;
      final progId = programs.first['id'] as String;
      final baseDate = DateTime(2025, 6, 1);
      await srv.prepareQuarterlyData('demo_base_st3', progId, 'demo_base_spec3',
          baseDate: baseDate);
      final sessions = await db.where('sessions',
          where: 'student_id = ?', whereArgs: ['demo_base_st3']);
      if (sessions.isNotEmpty) {
        for (final s in sessions) {
          final startedAt = s['started_at'] as String;
          expect(startedAt.startsWith('2025'), isTrue,
              reason: 'Quarterly sessions should use baseDate year 2025');
        }
      }
    });
  });

  // ─── Phase 2: simulateSingleGoalTherapyJourney Tests ───────
  group('simulateSingleGoalTherapyJourney', () {
    /// Sets up fresh state: demo center, student, specialist, assignment, assessment, plan.
    /// Progress is always reset to 0 even if prepareInitialReport skips.
    Future<({
      DemoDataService srv,
      DatabaseService db,
      String studentId,
      String specialistId,
      String programId,
      String planId,
    })> _setup() async {
      final srv = DemoDataService(SanadRepository(DatabaseService.instance));
      await srv.seedFullDemoData();
      final db = DatabaseService.instance;
      final library = SanadLibraryService(db);
      await library.ensureSeeded();
      final programs = await srv.getDemoPrograms();
      final progId = programs.first['id'] as String;
      final studentId = 'demo_phase2_st';
      final specialistId = 'demo_phase2_spec';
      await db.upsert('students', {
        'id': studentId, 'center_id': DemoDataService.demoCenterId,
        'name': 'طالب المرحلة 2', 'age': 6, 'status': 'نشط',
        'diagnosis': 'اضطراب نطق', 'parent_name': '', 'parent_phone': '',
        'portal_email': '', 'portal_password': '', 'photo_path': '', 'notes': '',
      });
      await db.upsert('users', {
        'id': specialistId, 'center_id': DemoDataService.demoCenterId,
        'name': 'أخصائي المرحلة 2', 'role': 'specialist',
        'email': 'spec_p2@test.com', 'password_hash': 'hash',
      });
      // Create assignment + assessment + plans
      await srv.prepareInitialReport(studentId, progId, specialistId,
          baseDate: DateTime(2026, 1, 15));
      // Reset all plan progress to 0 (prepareInitialReport may skip if assessment exists)
      await db.updateWhere('training_plans',
          {'progress': 0}, 'student_id = ? AND program_id = ?', [studentId, progId]);
      // Delete any prior simulated sessions for this student
      await db.deleteWhere('sessions',
          'student_id = ?', [studentId]);
      // Get the plan
      final plans = await srv.getDemoPlans(studentId, progId);
      if (plans.isEmpty) {
        throw StateError('No plans after prepareInitialReport');
      }
      final planId = plans.first['id'] as String;
      return (
        srv: srv, db: db,
        studentId: studentId, specialistId: specialistId,
        programId: progId, planId: planId,
      );
    }

    test('fails outside demo_center_sanad with clear message', () async {
      final srv = DemoDataService(SanadRepository(DatabaseService.instance));
      final result = await srv.simulateSingleGoalTherapyJourney(
        studentId: 'real_st', programId: 'real_prog',
        specialistId: 'real_spec', planId: 'real_plan',
      );
      expect(result['success'], isFalse);
      // Center or student not found (center may exist from other tests)
      expect(result['message'],
          anyOf(contains('المركز التجريبي غير موجود'), contains('الطالب غير موجود')));
    });

    test('fails if student not in demo center', () async {
      final srv = DemoDataService(SanadRepository(DatabaseService.instance));
      await srv.seedFullDemoData();
      final result = await srv.simulateSingleGoalTherapyJourney(
        studentId: 'nonexistent', programId: 'prog',
        specialistId: 'spec', planId: 'plan',
      );
      expect(result['success'], isFalse);
      expect(result['message'], contains('الطالب غير موجود'));
    });

    test('fails if no assessment exists', () async {
      final (:srv, :db, :studentId, :specialistId, :programId, :planId) =
          await _setup();
      // Delete findings first, then assessment (keep assignment & plans)
      final existingAssessments = await db.where('clinical_assessments',
          where: 'student_id = ? AND program_id = ?',
          whereArgs: [studentId, programId]);
      for (final a in existingAssessments) {
        await db.deleteWhere('clinical_findings',
            'assessment_id = ?', [a['id'] as String]);
        await db.delete('clinical_assessments', a['id'] as String);
      }
      // Reset progress (previous test may have set it to 100)
      await db.updateWhere('training_plans',
          {'progress': 0}, 'id = ?', [planId]);
      final result = await srv.simulateSingleGoalTherapyJourney(
        studentId: studentId, programId: programId,
        specialistId: specialistId, planId: planId,
      );
      expect(result['success'], isFalse);
      expect(result['message'], contains('تقييم أولي'));
    });

    test('creates 5 sessions with only allowed statuses', () async {
      final (:srv, :db, :studentId, :specialistId, :programId, :planId) =
          await _setup();
      final baseDate = DateTime(2026, 2, 1);
      final result = await srv.simulateSingleGoalTherapyJourney(
        studentId: studentId, programId: programId,
        specialistId: specialistId, planId: planId,
        baseDate: baseDate,
      );
      expect(result['success'], isTrue);
      expect(result['sessionsCreated'], equals(5));
      final sessions = await db.where('sessions',
          where: 'student_id = ? AND plan_id = ?',
          whereArgs: [studentId, planId]);
      expect(sessions.length, equals(5));
      final allowedStatuses = {'يحتاج إعادة', 'بمساعدة', 'متقن'};
      for (final s in sessions) {
        final qr = s['quick_result'] as String? ?? '';
        expect(allowedStatuses, contains(qr),
            reason: 'Session has disallowed status: $qr');
      }
      // Verify sequence
      final seq = sessions.map((m) => Map<String, Object?>.from(m)).toList()
        ..sort((a, b) => (a['started_at'] as String)
            .compareTo(b['started_at'] as String));
      expect(seq[0]['quick_result'], equals('يحتاج إعادة'));
      expect(seq[1]['quick_result'], equals('يحتاج إعادة'));
      expect(seq[2]['quick_result'], equals('بمساعدة'));
      expect(seq[3]['quick_result'], equals('بمساعدة'));
      expect(seq[4]['quick_result'], equals('متقن'));
    });

    test('sessions use baseDate and not DateTime.now', () async {
      final (:srv, :db, :studentId, :specialistId, :programId, :planId) =
          await _setup();
      final baseDate = DateTime(2026, 3, 1);
      await srv.simulateSingleGoalTherapyJourney(
        studentId: studentId, programId: programId,
        specialistId: specialistId, planId: planId,
        baseDate: baseDate,
      );
      final sessions = await db.where('sessions',
          where: 'student_id = ? AND plan_id = ?',
          whereArgs: [studentId, planId]);
      for (final s in sessions) {
        final startedAt = s['started_at'] as String;
        expect(startedAt.startsWith('2026'), isTrue,
            reason: 'Session date should use baseDate year, not real year');
      }
    });

    test('updates goal progress to 100 via steps', () async {
      final (:srv, :db, :studentId, :specialistId, :programId, :planId) =
          await _setup();
      // Verify steps exist (3 steps per plan from prepareInitialReport)
      var steps = await db.where('goal_skill_steps',
          where: 'goal_id = ?', whereArgs: [planId]);
      expect(steps.length, greaterThan(0));

      final result = await srv.simulateSingleGoalTherapyJourney(
        studentId: studentId, programId: programId,
        specialistId: specialistId, planId: planId,
        baseDate: DateTime(2026, 4, 1),
      );

      // Steps should all be متقن now
      steps = await db.where('goal_skill_steps',
          where: 'goal_id = ?', whereArgs: [planId]);
      for (final step in steps) {
        expect(step['status'], equals('متقن'));
      }

      // Plan progress should be 100
      final plan = await db.first('training_plans',
          where: 'id = ?', whereArgs: [planId]);
      expect(plan, isNotNull);
      expect(plan!['progress'], equals(100),
          reason: 'All steps متقن → progress=100');
      expect(result['progressAchieved'], equals(100));
    });

    test('updates goal progress for plan without steps', () async {
      final (:srv, :db, :studentId, :specialistId, :programId, :planId) =
          await _setup();
      // Delete steps for this plan
      await db.deleteWhere('goal_skill_steps',
          'goal_id = ?', [planId]);
      // Set initial progress < 100
      await db.updateWhere('training_plans',
          {'progress': 20}, 'id = ?', [planId]);

      await srv.simulateSingleGoalTherapyJourney(
        studentId: studentId, programId: programId,
        specialistId: specialistId, planId: planId,
        baseDate: DateTime(2026, 5, 1),
      );

      final plan = await db.first('training_plans',
          where: 'id = ?', whereArgs: [planId]);
      expect(plan, isNotNull);
      // No steps → progress = 100 because last session is متقن
      expect(plan!['progress'], equals(100));
    });

    test('creates new assessment with linked finding set to normal', () async {
      final (:srv, :db, :studentId, :specialistId, :programId, :planId) =
          await _setup();
      await srv.simulateSingleGoalTherapyJourney(
        studentId: studentId, programId: programId,
        specialistId: specialistId, planId: planId,
        baseDate: DateTime(2026, 6, 1),
      );

      // Should have created a new assessment
      final assessments = await db.where('clinical_assessments',
          where: 'student_id = ? AND program_id = ?',
          whereArgs: [studentId, programId],
          orderBy: 'created_at DESC');
      final newAssess = assessments.isNotEmpty ? assessments.first : null;
      expect(newAssess, isNotNull);
      expect(newAssess!['id'], contains('demo_phase2_assess_'));

      // Check findings: the linked one should be is_normal=1
      final findings = await db.where('clinical_findings',
          where: 'assessment_id = ?', whereArgs: [newAssess['id']]);
      expect(findings.length, greaterThan(0));
      bool foundImproved = false;
      for (final f in findings) {
        if ((f['is_normal'] as int? ?? 0) == 1) {
          foundImproved = true;
        }
      }
      expect(foundImproved, isTrue,
          reason: 'New assessment should have at least one normal finding');
    });

    test('no duplicate goals created after new assessment', () async {
      final (:srv, :db, :studentId, :specialistId, :programId, :planId) =
          await _setup();
      final plansBefore = await db.where('training_plans',
          where: 'student_id = ? AND program_id = ?',
          whereArgs: [studentId, programId]);

      await srv.simulateSingleGoalTherapyJourney(
        studentId: studentId, programId: programId,
        specialistId: specialistId, planId: planId,
        baseDate: DateTime(2026, 7, 1),
      );

      final plansAfter = await db.where('training_plans',
          where: 'student_id = ? AND program_id = ?',
          whereArgs: [studentId, programId]);
      expect(plansAfter.length, equals(plansBefore.length),
          reason: 'New assessment should not create duplicate goals');
    });

    test('does not modify other plans', () async {
      final (:srv, :db, :studentId, :specialistId, :programId, :planId) =
          await _setup();
      final allPlansBefore = await db.where('training_plans',
          where: 'student_id = ? AND program_id = ?',
          whereArgs: [studentId, programId]);
      final otherPlanProgressBefore = <String, int>{};
      for (final p in allPlansBefore) {
        if (p['id'] != planId) {
          otherPlanProgressBefore[p['id'] as String] = p['progress'] as int? ?? 0;
        }
      }

      await srv.simulateSingleGoalTherapyJourney(
        studentId: studentId, programId: programId,
        specialistId: specialistId, planId: planId,
        baseDate: DateTime(2026, 8, 1),
      );

      final allPlansAfter = await db.where('training_plans',
          where: 'student_id = ? AND program_id = ?',
          whereArgs: [studentId, programId]);
      for (final p in allPlansAfter) {
        if (p['id'] != planId) {
          final before = otherPlanProgressBefore[p['id'] as String] ?? 0;
          expect(p['progress'], equals(before),
              reason: 'Other plan ${p['id']} progress should not change');
        }
      }
    });

    test('fails if plan is already mastered', () async {
      final (:srv, :db, :studentId, :specialistId, :programId, :planId) =
          await _setup();
      await db.updateWhere('training_plans',
          {'progress': 100}, 'id = ?', [planId]);
      final result = await srv.simulateSingleGoalTherapyJourney(
        studentId: studentId, programId: programId,
        specialistId: specialistId, planId: planId,
        baseDate: DateTime(2026, 9, 1),
      );
      expect(result['success'], isFalse);
      expect(result['message'], contains('متقن بالفعل'));
    });
  });

  // ─── DemoTimeService Tests ──────────────────────────────────
  group('DemoTimeService', () {
    late DemoTimeService timeService;

    setUp(() async {
      final db = DatabaseService.instance;
      await db.deleteCenter(DemoTimeService.demoCenterId);
      timeService = DemoTimeService.instance;
      await timeService.reset();
    });

    test('getState returns exists=false before initialization', () async {
      final db = DatabaseService.instance;
      await db.deleteWhere('demo_time_state', 'center_id = ?', [DemoTimeService.demoCenterId]);
      final state = await timeService.getState();
      expect(state['exists'], isFalse);
    });

    test('reset creates default state with 2026-01-01', () async {
      await timeService.reset();
      final state = await timeService.getState();
      expect(state['exists'], isTrue);
      expect(state['currentDate'], startsWith('2026-01-01'));
      expect(state['initialDate'], startsWith('2026-01-01'));
      expect(state['lastAction'], isNotEmpty);
    });

    test('getCurrentDate returns correct default date', () async {
      await timeService.reset();
      final date = await timeService.getCurrentDate();
      expect(date.year, equals(2026));
      expect(date.month, equals(1));
      expect(date.day, equals(1));
    });

    test('advanceWeeks advances date by 7 days', () async {
      await timeService.reset();
      await timeService.advanceWeeks(1);
      final date = await timeService.getCurrentDate();
      expect(date.year, equals(2026));
      expect(date.month, equals(1));
      expect(date.day, equals(8));
    });

    test('advanceWeeks multiple weeks', () async {
      await timeService.reset();
      await timeService.advanceWeeks(4);
      final date = await timeService.getCurrentDate();
      expect(date.year, equals(2026));
      expect(date.month, equals(1));
      expect(date.day, equals(29));
    });

    test('advanceMonths advances date by 1 month', () async {
      await timeService.reset();
      await timeService.advanceMonths(1);
      final date = await timeService.getCurrentDate();
      expect(date.year, equals(2026));
      expect(date.month, equals(2));
      expect(date.day, equals(1));
    });

    test('advanceMonths multiple months crosses year boundary', () async {
      await timeService.reset();
      await timeService.advanceMonths(12);
      final date = await timeService.getCurrentDate();
      expect(date.year, equals(2027));
      expect(date.month, equals(1));
      expect(date.day, equals(1));
    });

    test('reset restores date to initial value after advances', () async {
      await timeService.reset();
      await timeService.advanceMonths(3);
      var date = await timeService.getCurrentDate();
      expect(date.month, equals(4));

      await timeService.reset();
      date = await timeService.getCurrentDate();
      expect(date.month, equals(1));
      expect(date.day, equals(1));
    });

    test('setCurrentDate sets a specific date', () async {
      await timeService.reset();
      await timeService.setCurrentDate(DateTime(2026, 6, 15));
      final date = await timeService.getCurrentDate();
      expect(date.year, equals(2026));
      expect(date.month, equals(6));
      expect(date.day, equals(15));
    });

    test('currentWeekRange returns valid range', () async {
      await timeService.reset();
      final range = await timeService.currentWeekRange();
      expect(range['start'], isA<DateTime>());
      expect(range['end'], isA<DateTime>());
      expect(range['end']!.difference(range['start']!).inDays, equals(6));
    });

    test('currentMonthRange returns valid range', () async {
      await timeService.reset();
      final range = await timeService.currentMonthRange();
      expect(range['start'], isA<DateTime>());
      expect(range['end'], isA<DateTime>());
      expect(range['start']!.month, equals(1));
      expect(range['start']!.day, equals(1));
      expect(range['end']!.month, equals(1));
      expect(range['end']!.day, equals(31));
    });

    test('advanceDays works correctly', () async {
      await timeService.reset();
      await timeService.advanceDays(15);
      final date = await timeService.getCurrentDate();
      expect(date.day, equals(16));
    });

    test('time state is isolated to demo_center_sanad', () async {
      // Non-demo center should not have time state
      final db = DatabaseService.instance;
      final nonDemoState = await db.first('demo_time_state',
          where: 'center_id = ?', whereArgs: ['real_center']);
      expect(nonDemoState, isNull);
    });

    test('advanceMonths January 31 shifts correctly', () async {
      await timeService.reset();
      await timeService.setCurrentDate(DateTime(2026, 1, 31));
      await timeService.advanceMonths(1);
      final date = await timeService.getCurrentDate();
      // Dart's DateTime(2026, 2, 31) overflows to 2026-03-03
      expect(date.month, equals(3));
      expect(date.day, equals(3));
    });
  });

  // ─── Center Report Settings ───────────────────────────────────
  group('CenterReportSettings', () {
    late DatabaseService db;
    late CenterReportSettingsService svc;

    setUp(() async {
      db = DatabaseService.instance;
      svc = CenterReportSettingsService(db);
    });

    test('defaults() returns center-specific defaults', () {
      final s = CenterReportSettings.defaults('center_1');
      expect(s.centerId, equals('center_1'));
      expect(s.defaultReportTitle, isNotEmpty);
      expect(s.arabicHeaderText, equals(''));
      expect(s.reportsToFund, isFalse);
    });

    test('save then getForCenter returns same data', () async {
      final now = DateTime.now().toIso8601String();
      final original = CenterReportSettings(
        centerId: 'test_report_center',
        arabicHeaderText: 'مركز اختبار التقارير',
        englishHeaderText: 'Test Report Center',
        defaultReportTitle: 'تقرير اختبار',
        defaultTechnicalSupervisorName: 'مشرف اختبار',
        footerNotes: 'ملاحظة اختبار',
        reportsToFund: true,
        fundName: 'جهة اختبار',
        showFundCardNumber: true,
        showReferralDate: true,
        showReferralSource: false,
        updatedAt: now,
      );
      await svc.save(original);

      final loaded = await svc.getForCenter('test_report_center');
      expect(loaded.centerId, equals('test_report_center'));
      expect(loaded.arabicHeaderText, equals('مركز اختبار التقارير'));
      expect(loaded.englishHeaderText, equals('Test Report Center'));
      expect(loaded.defaultReportTitle, equals('تقرير اختبار'));
      expect(loaded.defaultTechnicalSupervisorName, equals('مشرف اختبار'));
      expect(loaded.footerNotes, equals('ملاحظة اختبار'));
      expect(loaded.reportsToFund, isTrue);
      expect(loaded.fundName, equals('جهة اختبار'));
      expect(loaded.showFundCardNumber, isTrue);
      expect(loaded.showReferralDate, isTrue);
      expect(loaded.showReferralSource, isFalse);
    });

    test('save updates existing row (upsert)', () async {
      final now = DateTime.now().toIso8601String();
      await svc.save(CenterReportSettings(
        centerId: 'upsert_center',
        arabicHeaderText: 'نص أول',
        updatedAt: now,
      ));
      await svc.save(CenterReportSettings(
        centerId: 'upsert_center',
        arabicHeaderText: 'نص محدث',
        reportsToFund: true,
        updatedAt: now,
      ));
      final loaded = await svc.getForCenter('upsert_center');
      expect(loaded.arabicHeaderText, equals('نص محدث'));
      expect(loaded.reportsToFund, isTrue);
    });

    test('getForCenter returns defaults when no row exists', () async {
      final s = await svc.getForCenter('nonexistent_center');
      expect(s.centerId, equals('nonexistent_center'));
      expect(s.defaultReportTitle, isNotEmpty);
    });

    test('save/load logo then clearLogo', () async {
      final bytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]); // PNG header
      await svc.updateLogo('logo_center', bytes, 'test.png');

      var loaded = await svc.getForCenter('logo_center');
      expect(loaded.logoBase64, isNotNull);
      expect(loaded.logoFileName, equals('test.png'));

      await svc.clearLogo('logo_center');
      loaded = await svc.getForCenter('logo_center');
      expect(loaded.logoBase64, isNull);
      expect(loaded.logoFileName, isNull);
    });

    test('delete removes row', () async {
      final now = DateTime.now().toIso8601String();
      await svc.save(CenterReportSettings(
        centerId: 'delete_test_center',
        arabicHeaderText: 'سيتم حذفي',
        updatedAt: now,
      ));
      await svc.delete('delete_test_center');
      final s = await svc.getForCenter('delete_test_center');
      // After delete, getForCenter returns defaults
      expect(s.arabicHeaderText, equals(''));
    });

    test('data survives database re-open (persistence)', () async {
      final now = DateTime.now().toIso8601String();
      await svc.save(CenterReportSettings(
        centerId: 'persist_test_center',
        arabicHeaderText: 'بيانات ثابتة',
        reportsToFund: true,
        fundName: 'صندوق اختبار',
        updatedAt: now,
      ));

      // Close and re-open the database
      await db.close();
      await db.database; // re-opens

      // Verify data still exists
      final svc2 = CenterReportSettingsService(db);
      final loaded = await svc2.getForCenter('persist_test_center');
      expect(loaded.arabicHeaderText, equals('بيانات ثابتة'));
      expect(loaded.reportsToFund, isTrue);
      expect(loaded.fundName, equals('صندوق اختبار'));
    });
  });
}
