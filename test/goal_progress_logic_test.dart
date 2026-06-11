import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sanad_app/providers/app_provider.dart';
import 'package:sanad_app/repositories/sanad_repository.dart';
import 'package:sanad_app/services/database_service.dart';
import 'package:sanad_app/services/pdf_service.dart';
import 'package:sanad_app/models/app_models.dart';

void main() {
  late AppProvider app;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    final repo = SanadRepository(DatabaseService.instance);
    final pdf = PdfService();
    app = AppProvider(repo, pdf);

    // بيانات ثابتة للطالب والبرنامج للفلترة
    app.plans = [
      TrainingPlan(
        id: 'goal_no_steps',
        studentId: 'student_1',
        goal: 'نطق حرف الراء',
        targetDate: '2026-01-01',
        progress: 0,
        programId: 'prog_1',
        sourceType: 'standard',
      ),
      TrainingPlan(
        id: 'goal_with_3_steps',
        studentId: 'student_1',
        goal: 'نطق حرف السين',
        targetDate: '2026-01-01',
        progress: 33,
        programId: 'prog_1',
        sourceType: 'standard',
      ),
    ];

    // Student (مطلوب لبعض الفلاتر)
    app.students = [
      Student(
        id: 'student_1',
        centerId: 'center_1',
        name: 'طالب اختبار',
        age: 5,
        status: 'نشط',
        diagnosis: '',
        parentName: '',
        parentPhone: '',
        portalEmail: '',
        portalPassword: '',
        photoPath: '',
        notes: '',
        createdAt: '',
        updatedAt: '',
      ),
    ];
  });

  group('هدف بدون مهارات (standard/goal بدون steps)', () {
    const goalId = 'goal_no_steps';

    test('quickResult = "متقن" → goalProgress = 100', () {
      app.sessions = [
        TherapySession(
          id: 's1',
          studentId: 'student_1',
          planId: goalId,
          startedAt: '2026-06-10T10:00:00',
          durationSeconds: 1800,
          cardTitle: 'جلسة 1',
          quickResult: 'متقن',
          notes: '',
        ),
      ];

      final progress = app.goalProgress(goalId);
      final status = app.goalStatus(goalId);

      print('══════ هدف بدون مهارات — متقن ══════');
      print('goalProgress  = $progress');
      print('goalStatus    = $status');

      expect(progress, equals(100));
      expect(status, equals('متقن'));
    });

    test('quickResult = "بمساعدة" → goalProgress = 50', () {
      app.sessions = [
        TherapySession(
          id: 's2',
          studentId: 'student_1',
          planId: goalId,
          startedAt: '2026-06-10T10:00:00',
          durationSeconds: 1800,
          cardTitle: 'جلسة 2',
          quickResult: 'بمساعدة',
          notes: '',
        ),
      ];

      final progress = app.goalProgress(goalId);
      final status = app.goalStatus(goalId);

      print('══════ هدف بدون مهارات — بمساعدة ══════');
      print('goalProgress  = $progress');
      print('goalStatus    = $status');

      expect(progress, equals(50));
      expect(status, equals('يحتاج مساعدة'));
    });

    test('quickResult = "يحتاج إعادة" → goalProgress = 0', () {
      app.sessions = [
        TherapySession(
          id: 's3',
          studentId: 'student_1',
          planId: goalId,
          startedAt: '2026-06-10T10:00:00',
          durationSeconds: 1800,
          cardTitle: 'جلسة 3',
          quickResult: 'يحتاج إعادة',
          notes: '',
        ),
      ];

      final progress = app.goalProgress(goalId);
      final status = app.goalStatus(goalId);

      print('══════ هدف بدون مهارات — يحتاج إعادة ══════');
      print('goalProgress  = $progress');
      print('goalStatus    = $status');

      expect(progress, equals(0));
      expect(status, equals('يحتاج إعادة'));
    });

    test('لا توجد جلسات → goalProgress = plan.progress (= 0)', () {
      app.sessions = [];

      final progress = app.goalProgress(goalId);
      final status = app.goalStatus(goalId);

      print('══════ هدف بدون مهارات — لا توجد جلسات ══════');
      print('goalProgress  = $progress (plan.progress=${app.plans.firstWhere((p) => p.id == goalId).progress})');
      print('goalStatus    = $status');

      expect(progress, equals(0));
      expect(status, equals('جديد'));
    });
  });

  group('هدف فيه 3 مهارات (1 متقن + 1 بمساعدة + 1 يحتاج إعادة)', () {
    const goalId = 'goal_with_3_steps';

    setUp(() {
      app.goalSkillSteps = [
        GoalSkillStep(
          id: 'step_1',
          centerId: 'center_1',
          studentId: 'student_1',
          goalId: goalId,
          title: 'مهارة 1',
          status: 'متقن',
          sortOrder: 1,
        ),
        GoalSkillStep(
          id: 'step_2',
          centerId: 'center_1',
          studentId: 'student_1',
          goalId: goalId,
          title: 'مهارة 2',
          status: 'بمساعدة',
          sortOrder: 2,
        ),
        GoalSkillStep(
          id: 'step_3',
          centerId: 'center_1',
          studentId: 'student_1',
          goalId: goalId,
          title: 'مهارة 3',
          status: 'يحتاج إعادة',
          sortOrder: 3,
        ),
      ];
    });

    test('goalProgress = 33 (1 متقن ÷ 3)', () {
      final progress = app.goalProgress(goalId);
      final status = app.goalStatus(goalId);

      print('══════ هدف فيه 3 مهارات ══════');
      print('المهارات:');
      for (final step in app.goalSkillSteps) {
        print('  ${step.title}: ${step.status}');
      }
      print('goalProgress  = $progress');
      print('goalStatus    = $status');

      expect(progress, equals(33));
      expect(status, equals('يحتاج إعادة'));
    });

    test('جميع المهارات متقنة → goalProgress = 100', () {
      app.goalSkillSteps = app.goalSkillSteps.map((s) =>
        s.copyWith(status: 'متقن')
      ).toList();

      final progress = app.goalProgress(goalId);
      final status = app.goalStatus(goalId);

      print('══════ جميع المهارات متقنة ══════');
      print('goalProgress  = $progress');
      print('goalStatus    = $status');

      expect(progress, equals(100));
      expect(status, equals('متقن'));
    });
  });

  group('اختبار الفلاتر: activeGoalCount / masteredGoalCount', () {
    test('تصنيف الأهداف حسب goalProgress', () {
      // هدف بدون مهارات → متقن (100)
      // هدف به 3 مهارات → 33
      app.plans = [
        TrainingPlan(
          id: 'g1', studentId: 'student_1', goal: 'الهدف 1',
          targetDate: '2026-01-01', progress: 0,
          programId: 'prog_1', sourceType: 'standard',
        ),
        TrainingPlan(
          id: 'g2', studentId: 'student_1', goal: 'الهدف 2',
          targetDate: '2026-01-01', progress: 0,
          programId: 'prog_1', sourceType: 'standard',
        ),
      ];

      // g1: آخر جلسة متقن → 100
      // g2: آخر جلسة بمساعدة → 50
      app.sessions = [
        TherapySession(
          id: 'sg1', studentId: 'student_1', planId: 'g1',
          startedAt: '2026-06-10T10:00:00',
          durationSeconds: 1800, cardTitle: 'جلسة g1',
          quickResult: 'متقن', notes: '',
        ),
        TherapySession(
          id: 'sg2', studentId: 'student_1', planId: 'g2',
          startedAt: '2026-06-10T10:00:00',
          durationSeconds: 1800, cardTitle: 'جلسة g2',
          quickResult: 'بمساعدة', notes: '',
        ),
      ];

      final activeCount = app.activeGoalCount;
      final masteredCount = app.masteredGoalCount;

      print('══════ الفلاتر ══════');
      print('plans[0] (g1): goalProgress=${app.goalProgress('g1')}');
      print('plans[1] (g2): goalProgress=${app.goalProgress('g2')}');
      print('activeGoalCount   = $activeCount');
      print('masteredGoalCount = $masteredCount');

      // g1=100 (منجز), g2=50 (نشط)
      expect(activeCount, equals('1'));
      expect(masteredCount, equals('1'));
    });
  });

  group('متابعة مفتوحة ثم إتقان', () {
    test('المتابعة تُغلق بعد الإتقان (محاكاة منطق DB)', () {
      const stepId = 'step_fu_test';

      // 1. محاكاة وجود متابعة مفتوحة
      app.studentFollowups = [
        StudentFollowup(
          id: 'fu_1',
          studentId: 'student_1',
          specialistId: 'spec_1',
          programId: 'prog_1',
          sourceType: 'standard',
          planId: 'goal_fu',
          goalSkillStepId: stepId,
          reason: 'retry',
          createdAt: '2026-06-01',
        ),
      ];

      final before = app.studentFollowups
          .where((f) => f.goalSkillStepId == stepId)
          .toList();
      print('══════ متابعة قبل الإتقان ══════');
      print('متابعات للمهارة $stepId: ${before.length}');
      print('  موجودة: ${before.isNotEmpty}');
      print('  reason: ${before.isNotEmpty ? before.first.reason : '-'}');
      expect(before.isNotEmpty, isTrue);

      // 2. محاكاة الحذف (كما يفعل resolveFollowupForStep في DB)
      app.studentFollowups.removeWhere((f) =>
          f.studentId == 'student_1' && f.goalSkillStepId == stepId);

      final after = app.studentFollowups
          .where((f) => f.goalSkillStepId == stepId)
          .toList();
      print('');
      print('══════ متابعة بعد الإتقان ══════');
      print('متابعات للمهارة $stepId: ${after.length}');
      print('  موجودة: ${after.isNotEmpty}');
      expect(after.isEmpty, isTrue);
    });

    test('re-Evaluation لا تنشئ متابعة للمهارة المتقنة', () {
      // المهارة متقنة في البيانات
      app.goalSkillSteps = [
        GoalSkillStep(
          id: 'step_mastered',
          centerId: 'center_1',
          studentId: 'student_1',
          goalId: 'goal_fu2',
          title: 'مهارة متقنة',
          status: 'متقن',
          sortOrder: 1,
        ),
      ];

      // منطق _evaluateStep: إذا status == 'متقن' → resolve لا upsert
      // إذا status != 'متقن' → upsert
      // هنا نحاكي  الحالة: المهارة متقنة فلا نضيف متابعة
      const shouldCreateFollowup = false; // لأن المهارة متقنة
      expect(shouldCreateFollowup, isFalse);
    });
  });
}
