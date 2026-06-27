import 'dart:convert';

import '../models/app_models.dart';
import '../repositories/sanad_repository.dart';
import '../services/database_service.dart';
import 'auth_service.dart';
import 'sanad_library_service.dart';

class DemoDataService {
  DemoDataService(this._repository);

  final SanadRepository _repository;

  // ─── Fixed IDs ───────────────────────────────────────────
  static const demoCenterId = 'demo_center_sanad';
  static const demoManagerId = 'demo_manager';
  static const demoCoordinatorId = 'demo_coordinator';
  static const demoDataEntryId = 'demo_data_entry';

  static const _demoPass = 'Demo@123456';

  static bool isDemoId(String id) => id.startsWith('demo_');

  DatabaseService get _db => DatabaseService.instance;

  // ─── Status ───────────────────────────────────────────────
  Future<Map<String, dynamic>> getStatus() async {
    final center = await _db.first('centers',
        where: 'id = ?', whereArgs: [demoCenterId]);
    if (center == null) {
      return {'exists': false, 'message': 'لا توجد بيانات تجريبية بعد.'};
    }
    final userCount = await _db.countWhere(
        'users', 'center_id = ?', [demoCenterId]);
    final studentCount = await _db.countWhere(
        'students', 'center_id = ?', [demoCenterId]);
    final sessionCount = await _db.countWhere(
        'sessions', 'center_id = ?', [demoCenterId]);
    final reportCount = await _db.countWhere(
        'reports', 'center_id = ?', [demoCenterId]);
    final assessmentCount = await _db.countWhere(
        'clinical_assessments', 'center_id = ?', [demoCenterId]);
    final planCount = await _db.countWhere(
        'training_plans', 'center_id = ?', [demoCenterId]);
    final updatedAt = center['updated_at'] as String? ?? '';
    return {
      'exists': true,
      'centerName': center['name'],
      'userCount': userCount,
      'studentCount': studentCount,
      'sessionCount': sessionCount,
      'reportCount': reportCount,
      'assessmentCount': assessmentCount,
      'planCount': planCount,
      'updatedAt': updatedAt,
    };
  }

  /// Full status including Sanad library info.
  Future<Map<String, dynamic>> getFullStatus() async {
    final basic = await getStatus();
    if (basic['exists'] != true) return basic;
    final progCount = await _db.countWhere(
        'therapy_program_templates', 'center_id = ?', [SanadLibraryService.centerId]);
    return {
      ...basic,
      'programCount': progCount,
      'libraryReady': progCount > 0,
    };
  }

  // ─── Seed: center + 3 base accounts ONLY ─────────────────
  /// Creates the demo center and 3 base accounts (manager, coordinator,
  /// dataEntry). Does NOT create programs, specialists, or students.
  /// The Sanad library must be available system-wide before calling this.
  Future<void> seedFullDemoData() async {
    // Clean up any old demo-specific programs before seeding
    await _db.deleteWhere('therapy_program_templates',
        'center_id = ?', [demoCenterId]);
    await createDemoCenter();
    await createDemoBaseUsers();
  }

  /// Returns true if the global Sanad library is ready.
  Future<bool> isLibraryReady() async {
    final count = await _db.countWhere(
        'therapy_program_templates', 'center_id = ?', [SanadLibraryService.centerId]);
    return count > 0;
  }

  // ─── Reset (keep center + base accounts, delete therapeutic data) ─
  Future<void> resetDemoData() async {
    final tablesToClean = [
      'goal_skill_steps',
      'clinical_findings',
      'sessions',
      'evaluations',
      'training_plans',
      'exercises',
      'rewards',
      'reports',
      'clinical_assessments',
      'parents',
      'student_followups',
      'student_program_assignments',
      'student_therapy_programs',
      'specialist_program_capabilities',
      'students',
    ];
    for (final table in tablesToClean) {
      await _db.deleteWhere(table, 'center_id = ?', [demoCenterId]);
    }
    // Keep center + all demo users (base + manually added).
    // Keep global Sanad library untouched.
  }

  // ─── Delete everything demo ───────────────────────────────
  Future<void> deleteDemoData() async {
    await _db.deleteCenter(demoCenterId);
    // Delete all demo users (base + manually added + any with center_id)
    await _db.deleteWhere('users', 'center_id = ?', [demoCenterId]);
    // Also delete the demo owner if it somehow exists
    await _db.delete('users', 'demo_owner');
  }

  // ─── 1. Demo Center ──────────────────────────────────────
  Future<void> createDemoCenter() async {
    await _db.upsert('centers', {
      'id': demoCenterId,
      'name': 'مركز سند التجريبي',
      'logo_path': '',
      'address': 'الرياض - بيئة اختبار تجريبية',
      'phone': '0500000000',
      'manager_name': 'مدير المركز',
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // ─── 2. Demo Base Users (only 3 accounts) ─────────────────
  Future<void> createDemoBaseUsers() async {
    final now = DateTime.now().toIso8601String();
    Future<void> u(AppUser user) => _repository.saveUser(user);
    final passHash = AuthService.hashPassword(_demoPass);

    await u(AppUser(
      id: demoManagerId,
      email: 'demo_manager@sanad.app',
      passwordHash: passHash,
      name: '[تجريبي] مدير مركز سند',
      role: UserRole.centerManager,
      centerId: demoCenterId,
      isDemo: true,
      createdAt: now,
    ));
    await u(AppUser(
      id: demoCoordinatorId,
      email: 'demo_coordinator@sanad.app',
      passwordHash: passHash,
      name: '[تجريبي] منسق برامج',
      role: UserRole.coordinator,
      centerId: demoCenterId,
      isDemo: true,
      createdAt: now,
    ));
    await u(AppUser(
      id: demoDataEntryId,
      email: 'demo_dataentry@sanad.app',
      passwordHash: passHash,
      name: '[تجريبي] مدخل بيانات',
      role: UserRole.dataEntry,
      centerId: demoCenterId,
      isDemo: true,
      createdAt: now,
    ));
  }

  /// Returns a user-friendly name for a specialist ID by querying the DB.
  Future<String> _specialistName(String specialistId) async {
    final user = await _db.first('users',
        where: 'id = ?', whereArgs: [specialistId]);
    return (user?['name'] as String?) ?? 'أخصائي';
  }

  /// Lookup program name from Sanad library.
  String _programName(String id) => SanadLibraryService.programName(id);

  // ═══════════════════════════════════════════════════════════
  //  ACCELERATION TOOLS
  // ═══════════════════════════════════════════════════════════

  /// Ensure a student is assigned to a program + specialist.
  Future<void> _ensureAssignment(String studentId, String programId, String specialistId, {DateTime? baseDate}) async {
    final existing = await _db.first('student_program_assignments',
        where: 'student_id = ? AND program_id = ?', whereArgs: [studentId, programId]);
    if (existing != null) return;
    final now = (baseDate ?? DateTime.now()).toIso8601String();
    await _db.upsert('student_program_assignments', {
      'id': 'spa_accel_${studentId}_$programId', 'center_id': demoCenterId,
      'student_id': studentId, 'program_id': programId,
      'specialist_id': specialistId, 'role': 'primary', 'status': 'active',
      'assigned_by_user_id': demoManagerId, 'assigned_at': now, 'created_at': now,
    });
    await _db.upsert('student_therapy_programs', {
      'id': 'stp_accel_${studentId}_$programId', 'center_id': demoCenterId,
      'student_id': studentId, 'program_id': programId,
      'assigned_at': now, 'assigned_by_user_id': demoManagerId,
      'is_active': 1, 'sort_order': 0, 'created_at': now,
    });
  }

  /// Tool 1: تجهيز تقرير أولي
  /// Creates: assessment + findings + goals + steps.
  Future<void> prepareInitialReport(String studentId, String programId, String specialistId, {DateTime? baseDate}) async {
    await _ensureAssignment(studentId, programId, specialistId, baseDate: baseDate);
    // Check if assessment already exists
    final existing = await _db.first('clinical_assessments',
        where: 'student_id = ? AND program_id = ?', whereArgs: [studentId, programId]);
    if (existing != null) return;

    final now = (baseDate ?? DateTime.now()).toIso8601String();
    final assessmentId = 'demo_accel_assess_${studentId}_$programId';
    await _db.upsert('clinical_assessments', {
      'id': assessmentId, 'center_id': demoCenterId, 'student_id': studentId,
      'specialist_id': specialistId, 'specialist_name': await _specialistName(specialistId),
      'type': 'speech', 'program_id': programId,
      'strengths_summary': 'التواصل البصري جيد، الاستجابة للتعليمات جيدة',
      'weaknesses_summary': 'ضعف في مخارج الحروف الأساسية، يحتاج تدريبًا مكثفًا',
      'goals_summary': 'تحسين مخارج الحروف، زيادة الطلاقة اللفظية',
      'training_summary': 'تمارين نطق يومية + جلسات أسبوعية',
      'created_at': now,
    });
    // Findings
    for (final entry in [
      {'item': 'مخرج صوت /ر/', 'result': 'ضعيف', 'weakness': 'عدم القدرة على نطق الراء', 'goal': 'إتقان نطق صوت /ر/', 'training': 'تمارين أمام المرآة'},
      {'item': 'مخرج صوت /س/', 'result': 'بمساعدة', 'weakness': 'نطق السين بين الأسنان', 'goal': 'إتقان نطق صوت /س/', 'training': 'تمارين لفظية'},
      {'item': 'التمييز السمعي', 'result': 'جيد', 'weakness': '', 'goal': '', 'training': ''},
    ]) {
      await _db.upsert('clinical_findings', {
        'id': 'demo_accel_finding_${studentId}_${programId}_${entry['item']!.replaceAll(' ', '_')}',
        'assessment_id': assessmentId, 'center_id': demoCenterId, 'student_id': studentId,
        'domain': 'نطق', 'item_title': entry['item'], 'result': entry['result'],
        'is_normal': entry['result'] == 'جيد' || entry['result'] == 'متقن' ? 1 : 0,
        'weakness': entry['weakness']!, 'goal': entry['goal']!, 'training': entry['training']!,
        'program_id': programId, 'source_type': 'standard', 'created_at': now,
      });
    }
    // Goals
    for (final g in ['نطق صوت /ر/', 'نطق صوت /س/', 'نطق صوت /ش/']) {
      final planId = 'demo_accel_plan_${studentId}_${g.replaceAll(' ', '_').replaceAll('/', '_')}';
      await _db.upsert('training_plans', {
        'id': planId, 'center_id': demoCenterId, 'student_id': studentId,
        'goal': g, 'treatment': 'تمارين نطق', 'target_date': now, 'progress': 0,
        'program_id': programId, 'source_type': 'standard',
        'specialist_id': specialistId, 'created_at': now,
      });
      for (int s = 1; s <= 3; s++) {
        await _db.upsert('goal_skill_steps', {
          'id': 'demo_accel_step_${planId}_$s', 'goal_id': planId,
          'student_id': studentId, 'center_id': demoCenterId,
          'title': s == 1 ? 'محاولة النطق' : (s == 2 ? 'النطق بمساعدة' : 'النطق المستقل'),
          'status': s == 1 ? 'متقن' : (s == 2 ? 'بمساعدة' : 'لم يبدأ'),
          'program_id': programId, 'specialist_id': specialistId, 'created_at': now,
        });
      }
    }
  }

  /// Tool 2: إضافة جلسات تقدم
  /// Creates [count] sessions after now with increasing success rates.
  Future<void> addProgressSessions(String studentId, String programId, String specialistId, {int count = 5, DateTime? baseDate}) async {
    final plans = await _db.where('training_plans',
        where: 'student_id = ? AND program_id = ?', whereArgs: [studentId, programId]);
    if (plans.isEmpty) {
      throw StateError('لا توجد أهداف علاجية لهذا الطالب. استخدم "تجهيز تقرير أولي" أولاً.');
    }
    final now = baseDate ?? DateTime.now();
    for (int i = 1; i <= count; i++) {
      final planId = plans[i % plans.length]['id'] as String;
      final targetGoal = plans[i % plans.length]['goal'] as String;
      await _db.upsert('sessions', {
        'id': 'demo_accel_sess_${studentId}_${programId}_$i', 'center_id': demoCenterId,
        'student_id': studentId, 'specialist_id': specialistId,
        'plan_id': planId, 'program_id': programId,
        'skill_id': '', 'activity_results': '', 'session_type': 'نطق وتخاطب',
        'attempts': 10, 'success_rate': 40 + (i * 12),
        'started_at': now.add(Duration(days: i * 3)).toIso8601String(),
        'duration_seconds': 1800, 'card_title': 'جلسة تدريب $targetGoal',
        'quick_result': i <= 1 ? 'بمساعدة' : (i <= 3 ? 'متقن' : 'متقن'),
        'notes': 'جلسة تقدم آلية رقم $i', 'summary': 'تم التدريب وتحقيق تقدم',
        'created_at': now.toIso8601String(),
      });
    }
    // Update plan progress for the first plan
    final firstPlanId = plans[0]['id'] as String;
    final progress = (count * 15).clamp(0, 100);
    await _db.updateWhere('training_plans',
        {'progress': progress},
        'id = ?', [firstPlanId]);
  }

  /// Tool 3: تجهيز متابعة بلا تغيير
  /// Creates assessment + goals + pre-report sessions + a saved report,
  /// but NO sessions after the report date.
  Future<void> prepareFollowupNoChange(String studentId, String programId, String specialistId, {DateTime? baseDate}) async {
    await _ensureAssignment(studentId, programId, specialistId, baseDate: baseDate);
    await prepareInitialReport(studentId, programId, specialistId, baseDate: baseDate);
    // Add 2 sessions before a past report date
    final reportDate = (baseDate ?? DateTime.now()).subtract(const Duration(days: 30));
    final plans = await _db.where('training_plans',
        where: 'student_id = ? AND program_id = ?', whereArgs: [studentId, programId]);
    if (plans.isEmpty) return;
    for (int i = 1; i <= 2; i++) {
      final planId = plans[0]['id'] as String;
      await _db.upsert('sessions', {
        'id': 'demo_accel_pre_${studentId}_$i', 'center_id': demoCenterId,
        'student_id': studentId, 'specialist_id': specialistId,
        'plan_id': planId, 'program_id': programId,
        'skill_id': '', 'activity_results': '', 'session_type': 'نطق وتخاطب',
        'attempts': 10, 'success_rate': 40 + (i * 20),
        'started_at': reportDate.subtract(Duration(days: (3 - i) * 7)).toIso8601String(),
        'duration_seconds': 1800, 'card_title': 'نطق صوت /ر/',
        'quick_result': i == 1 ? 'بمساعدة' : 'متقن',
        'notes': 'جلسة قبل التقرير', 'summary': 'تم التدريب', 'created_at': (baseDate ?? DateTime.now()).toIso8601String(),
      });
    }
    // Save a report with snapshot
    final snapshot = jsonEncode({
      'studentId': studentId, 'generatedAt': reportDate.toIso8601String(),
      'reportCategory': 'specialistInitial', 'totalSessions': 2, 'totalPlans': plans.length,
      'sections': [{
        'programId': programId, 'programName': _programName(programId),
        'overallProgress': 30, 'masteredGoals': 0, 'activeGoals': plans.length,
        'plans': plans.map((p) => {'id': p['id'], 'goal': p['goal'], 'progress': (p['progress'] ?? 0) as int}).toList(),
      }],
    });
    await _db.upsert('reports', {
      'id': 'demo_accel_report_${studentId}_initial', 'center_id': demoCenterId,
      'student_id': studentId, 'type': 'تقرير أخصائي أولي',
      'created_at': reportDate.toIso8601String(), 'improvement_rate': 30,
      'specialist_signature': await _specialistName(specialistId), 'manager_signature': '',
      'program_id': programId, 'specialist_id': specialistId,
      'report_category': 'specialistInitial', 'scope': 'singleProgram',
      'snapshot_json': snapshot, 'report_status': 'exported',
      'updated_at': (baseDate ?? DateTime.now()).toIso8601String(),
    });
  }

  /// Tool 4: تجهيز متابعة مع تحسن
  /// Creates assessment + goals + pre-report sessions + report +
  /// sessions AFTER the report date with progress.
  Future<void> prepareFollowupWithProgress(String studentId, String programId, String specialistId, {DateTime? baseDate}) async {
    await prepareFollowupNoChange(studentId, programId, specialistId, baseDate: baseDate);
    // Add 3 sessions after the report with progress
    final reportDate = (baseDate ?? DateTime.now()).subtract(const Duration(days: 30));
    final plans = await _db.where('training_plans',
        where: 'student_id = ? AND program_id = ?', whereArgs: [studentId, programId]);
    if (plans.isEmpty) return;
    for (int i = 1; i <= 3; i++) {
      final planId = plans[i % plans.length]['id'] as String;
      await _db.upsert('sessions', {
        'id': 'demo_accel_post_${studentId}_$i', 'center_id': demoCenterId,
        'student_id': studentId, 'specialist_id': specialistId,
        'plan_id': planId, 'program_id': programId,
        'skill_id': '', 'activity_results': '', 'session_type': 'نطق وتخاطب',
        'attempts': 10, 'success_rate': 60 + (i * 10),
        'started_at': reportDate.add(Duration(days: i * 7)).toIso8601String(),
        'duration_seconds': 1800, 'card_title': 'نطق صوت /ر/',
        'quick_result': i == 1 ? 'بمساعدة' : (i == 2 ? 'بمساعدة' : 'متقن'),
        'notes': 'جلسة بعد التقرير مع تحسن', 'summary': 'تم ملاحظة تحسن في الأداء',
        'created_at': (baseDate ?? DateTime.now()).toIso8601String(),
      });
    }
    final lastPlanId = plans.last['id'] as String;
    await _db.updateWhere('training_plans',
        {'progress': 80},
        'id = ?', [lastPlanId]);
  }

  /// Tool 5: تجهيز بيانات ربع سنوية Q1/Q2
  /// Creates Q1 sessions + Q1 report + Q2 sessions with progress.
  Future<void> prepareQuarterlyData(String studentId, String programId, String specialistId, {DateTime? baseDate}) async {
    await _ensureAssignment(studentId, programId, specialistId, baseDate: baseDate);
    // Create assessment if not exists
    final existing = await _db.first('clinical_assessments',
        where: 'student_id = ? AND program_id = ?', whereArgs: [studentId, programId]);
    if (existing == null) {
      await prepareInitialReport(studentId, programId, specialistId, baseDate: baseDate);
    }
    final now = (baseDate ?? DateTime.now()).toIso8601String();
    final year = baseDate?.year ?? 2026;
    final plans = await _db.where('training_plans',
        where: 'student_id = ? AND program_id = ?', whereArgs: [studentId, programId]);
    if (plans.isEmpty) return;

    // Q1 sessions (Jan-Mar)
    final q1Dates = ['$year-01-15T10:00:00','$year-02-01T10:00:00','$year-02-15T10:00:00','$year-03-01T10:00:00'];
    for (int i = 0; i < q1Dates.length; i++) {
      final planId = plans[i % plans.length]['id'] as String;
      await _db.upsert('sessions', {
        'id': 'demo_accel_${studentId}_Q1_${i + 1}', 'center_id': demoCenterId,
        'student_id': studentId, 'specialist_id': specialistId,
        'plan_id': planId, 'program_id': programId,
        'skill_id': '', 'activity_results': '', 'session_type': 'نطق وتخاطب',
        'attempts': 10, 'success_rate': 30 + i * 10, 'started_at': q1Dates[i],
        'duration_seconds': 1800, 'card_title': 'Q1 - تدريب نطق',
        'quick_result': 'بمساعدة', 'notes': 'جلسة الربع الأول', 'summary': 'تم التدريب',
        'created_at': now,
      });
    }
    // Q1 report
    final q1snapshot = jsonEncode({
      'studentId': studentId, 'generatedAt': '${year}-03-31T23:59:59',
      'reportCategory': 'supervisorQuarterly', 'totalSessions': q1Dates.length,
      'totalPlans': plans.length, 'quarter': 'Q1', 'year': '$year',
      'sections': [{'programId': programId, 'programName': _programName(programId), 'overallProgress': 25, 'masteredGoals': 0, 'activeGoals': plans.length}],
    });
    await _db.upsert('reports', {
      'id': 'demo_accel_${studentId}_Q1', 'center_id': demoCenterId,
      'student_id': studentId, 'type': 'تقرير ربع سنوي',
      'created_at': '${year}-03-31T23:59:59', 'improvement_rate': 25,
      'specialist_signature': await _specialistName(specialistId), 'manager_signature': '[تجريبي] مدير مركز سند',
      'program_id': programId, 'specialist_id': specialistId,
      'report_category': 'supervisorQuarterly', 'scope': 'singleProgram',
      'quarter': 'Q1', 'year': '$year', 'snapshot_json': q1snapshot,
      'report_status': 'exported', 'updated_at': now,
    });

    // Q2 sessions with progress (Apr-Jun)
    final q2Dates = ['$year-04-10T10:00:00','$year-04-25T10:00:00','$year-05-10T10:00:00','$year-05-25T10:00:00'];
    for (int i = 0; i < q2Dates.length; i++) {
      final planId = plans[i % plans.length]['id'] as String;
      await _db.upsert('sessions', {
        'id': 'demo_accel_${studentId}_Q2_${i + 1}', 'center_id': demoCenterId,
        'student_id': studentId, 'specialist_id': specialistId,
        'plan_id': planId, 'program_id': programId,
        'skill_id': '', 'activity_results': '', 'session_type': 'نطق وتخاطب',
        'attempts': 10, 'success_rate': 50 + i * 12, 'started_at': q2Dates[i],
        'duration_seconds': 1800, 'card_title': 'Q2 - تدريب نطق',
        'quick_result': i < 2 ? 'بمساعدة' : 'متقن',
        'notes': 'جلسة الربع الثاني - تحسن', 'summary': 'تحسن ملحوظ في الأداء',
        'created_at': now,
      });
    }
    // Update plan progress
    final planId = plans.last['id'] as String;
    await _db.updateWhere('training_plans',
        {'progress': 60},
        'id = ?', [planId]);
  }

  /// Helper: get demo students as list of maps.
  Future<List<Map<String, dynamic>>> getDemoStudents() async {
    return _db.where('students', where: 'center_id = ?', whereArgs: [demoCenterId]);
  }

  /// Helper: get demo specialists.
  Future<List<Map<String, dynamic>>> getDemoSpecialists() async {
    return _db.where('users',
        where: 'center_id = ? AND role = ?', whereArgs: [demoCenterId, 'specialist']);
  }

  /// Helper: get all demo users (base + any manually added).
  Future<List<Map<String, dynamic>>> getDemoUsers() async {
    return _db.where('users',
        where: 'center_id = ?', whereArgs: [demoCenterId]);
  }

  /// Helper: get global Sanad library programs.
  Future<List<Map<String, dynamic>>> getDemoPrograms() async {
    return _db.where('therapy_program_templates',
        where: 'center_id = ?', whereArgs: [SanadLibraryService.centerId]);
  }
}
