import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../models/assessment_improvement_summary.dart';
import '../repositories/sanad_repository.dart';
import '../models/center_report_settings.dart';
import '../services/center_report_settings_service.dart';
import '../services/database_service.dart';
import '../services/demo_data_service.dart';
import '../services/notification_service.dart';
import '../services/pdf_service.dart';
import '../services/report_comparison_service.dart';
import '../services/report_data_builder.dart';

class AppProvider extends ChangeNotifier {
  AppProvider(this._repository, this._pdfService);

  final SanadRepository _repository;
  final PdfService _pdfService;
  final NotificationService _notificationService = const NotificationService();

  AppUser? user;
  SanadCenter? currentCenter;
  SanadCenter? supportModeCenter;
  AppUser? _realUserBeforeDemo;
  bool isDemoModeActive = false;
  String? demoModeUserId;
  List<SanadCenter> centers = [];
  List<AppUser> staff = [];
  List<Student> students = [];
  Student? selectedStudent;
  List<TherapySession> sessions = [];
  List<Evaluation> evaluations = [];
  List<TrainingPlan> plans = [];
  List<GoalSkillStep> goalSkillSteps = [];
  List<Exercise> exercises = [];
  List<ReportRecord> reports = [];
  List<StudentFollowup> studentFollowups = [];
  List<StudentFollowup> centerStudentFollowups = [];
  List<ClinicalAssessment> clinicalAssessments = [];
  Map<String, List<ClinicalFinding>> clinicalFindingsByAssessment = {};
  List<TherapyProgramTemplate> therapyPrograms = [];
  List<AssessmentSectionTemplate> assessmentSections = [];
  List<AssessmentItemTemplate> assessmentItems = [];
  List<AssessmentOptionTemplate> assessmentOptions = [];
  List<SkillStepTemplate> skillStepTemplates = [];
  List<SpeechSoundTriggerTemplate> speechSoundTriggers = [];
  List<SignResource> signResources = [];
  List<AuditLog> auditLogs = [];
  List<TherapySession> centerSessions = [];
  List<Evaluation> centerEvaluations = [];
  List<Exercise> centerExercises = [];
  List<SanadNotification> notifications = [];
  String? currentProgramId;
  List<StudentProgramAssignment> studentProgramAssignments = [];
  List<StudentTherapyProgram> studentTherapyPrograms = [];
  List<SpecialistProgramCapability> specialistProgramCapabilities = [];
  Map<String, List<String>> specialistCapabilityProgramsByUser = {};
  Reward? reward;
  List<String> studentProgramIds = [];
  Map<String, String>? sessionPreselect;
  bool loading = false;
  bool darkMode = false;
  bool initialized = false;
  bool setupRequired = false;
  String? startupError;
  int totalStudentsCount = 0;
  int totalSessionsCount = 0;
  Map<String, int> centerStudentCounts = {};
  Map<String, int> centerSpecialistCounts = {};
  Map<String, int> centerSessionCounts = {};
  Map<String, String> centerLastActivities = {};
  List<TrainingPlan> centerPlans = [];
  List<GoalSkillStep> centerGoalSteps = [];
  bool _centerPlansLoaded = false;
  List<ClinicalAssessment> centerClinicalAssessments = [];
  bool _centerAssessmentsLoaded = false;
  CenterReportSettings? centerReportSettings;
  final CenterReportSettingsService _centerReportSettingsService =
      CenterReportSettingsService(DatabaseService.instance);

  bool get isSanadOwnerAccount => user?.role == UserRole.sanadOwner;
  bool get isSupportMode => isSanadOwnerAccount && supportModeCenter != null;
  bool get isOwner =>
      isSanadOwnerAccount && !isSupportMode && !isDemoModeActive;
  bool get isCenterManager =>
      user?.role == UserRole.centerManager || isSupportMode;
  bool get isClinicalSupervisor => user?.role == UserRole.clinicalSupervisor;
  bool get isSpecialist => user?.role == UserRole.specialist;
  bool get isDataEntry => user?.role == UserRole.dataEntry;
  bool get isProgramEntry => user?.role == UserRole.therapyProgramEntry;
  bool get isCoordinator => user?.role == UserRole.coordinator;
  bool get isParent => user?.role == UserRole.parent;
  bool hasPermission(AppPermission permission) =>
      isSupportMode || user?.role.can(permission) == true;
  bool get canManageCenters => hasPermission(AppPermission.manageCenters);
  bool get canManageStaff => hasPermission(AppPermission.manageCenterStaff);
  bool get canViewStudents =>
      hasPermission(AppPermission.viewStudents) || isParent;
  bool get canManageStudents => hasPermission(AppPermission.manageStudents);
  bool get canDeleteStudents => isCenterManager;
  bool get canWriteClinical =>
      hasPermission(AppPermission.writeClinicalAssessments);
  bool get canRunSessions => hasPermission(AppPermission.runSessions);
  bool get canUpdateGoalProgress =>
      hasPermission(AppPermission.updateGoalProgress);
  bool get canCreateHomework => hasPermission(AppPermission.createHomework);
  bool get canManageTherapyStructure =>
      hasPermission(AppPermission.manageTherapyStructure);
  bool get isGlobalTherapyStructureMode => isOwner && !isSupportMode;
  String get therapyStructureWriteCenterId =>
      isGlobalTherapyStructureMode ? '' : activeCenterId;
  bool get canWriteParentArea =>
      isParent || hasPermission(AppPermission.createHomework);
  bool get canViewReports => hasPermission(AppPermission.viewReports);
  String get activeCenterId => currentCenter?.id ?? user?.centerId ?? '';

  List<String> get specialistCapabilityProgramIds =>
      isSpecialist
          ? specialistProgramCapabilities.map((c) => c.programId).toList()
          : [];

  int get completedHomeworkCount =>
      centerExercises.where((item) => item.status == 'مكتمل').length;

  List<TherapySession> get specialistSessions {
    if (user == null) return [];
    return centerSessions.where((s) => s.specialistId == user!.id).toList();
  }

  int get centerGoalImprovementRate {
    final withProgress = centerPlans.where((p) => goalProgress(p.id) > 0).toList();
    if (withProgress.isEmpty) return 0;
    return (withProgress.fold<int>(0, (sum, p) => sum + goalProgress(p.id)) /
            withProgress.length)
        .round();
  }

  List<Student> get studentsNeedingAssessment {
    if (!isSpecialist) return [];
    return students
        .where((s) => !centerClinicalAssessments.any((a) => a.studentId == s.id))
        .toList();
  }

  int studentGoalAverageProgress(String studentId) {
    final studentPlans =
        plans.where((p) => p.studentId == studentId && goalProgress(p.id) > 0).toList();
    if (studentPlans.isEmpty) return 0;
    return (studentPlans.fold<int>(0, (sum, p) => sum + goalProgress(p.id)) /
            studentPlans.length)
        .round();
  }

  bool studentHasAssessment(String studentId) =>
      clinicalAssessments.any((a) => a.studentId == studentId);

  /// Check if student has ANY therapy data across all data sources.
  /// For supervisor/manager roles, having any data (assessment, plan, session,
  /// finding, followup, exercise) is sufficient to create a report.
  bool studentHasTherapyData(String studentId, {String? programId}) {
    if (programId != null) {
      if (clinicalAssessments.any((a) => a.studentId == studentId && a.programId == programId)) return true;
      if (plans.any((p) => p.studentId == studentId && p.programId == programId)) return true;
      if (sessions.any((s) => s.studentId == studentId && s.programId == programId)) return true;
      if (goalSkillSteps.any((s) => s.studentId == studentId && s.programId == programId)) return true;
      if (studentFollowups.any((f) => f.studentId == studentId && f.programId == programId)) return true;
      if (exercises.any((e) => e.studentId == studentId && e.programId == programId)) return true;
      for (final entry in clinicalFindingsByAssessment.entries) {
        if (entry.value.any((f) => f.studentId == studentId && f.programId == programId)) return true;
      }
    } else {
      if (clinicalAssessments.any((a) => a.studentId == studentId)) return true;
      if (plans.any((p) => p.studentId == studentId)) return true;
      if (sessions.any((s) => s.studentId == studentId)) return true;
      if (goalSkillSteps.any((s) => s.studentId == studentId)) return true;
      if (studentFollowups.any((f) => f.studentId == studentId)) return true;
      if (exercises.any((e) => e.studentId == studentId)) return true;
      for (final entry in clinicalFindingsByAssessment.entries) {
        if (entry.value.any((f) => f.studentId == studentId)) return true;
      }
    }
    return false;
  }

  String get studentAssessmentStatus {
    final student = selectedStudent;
    if (student == null) return '';
    final has = clinicalAssessments.any((a) => a.studentId == student.id);
    return has ? 'مقيّم' : 'يحتاج تقييم';
  }

  AssessmentImprovementSummary get studentAssessmentImprovement {
    final student = selectedStudent;
    if (student == null) {
      return const AssessmentImprovementSummary(hasEnoughData: false);
    }
    return AssessmentImprovementSummary.compute(
      student.id,
      clinicalAssessments,
      clinicalFindingsByAssessment,
    );
  }

  String get pendingHomeworkReviewCount =>
      '${exercises.where((e) => e.status == 'completed_by_parent').length}';

  String get lastSessionDate {
    if (sessions.isEmpty) return 'لا توجد';
    return sessions.first.startedAt.split('T').first;
  }

  String get activeGoalCount {
    final studentPlans = plans.where((p) => goalProgress(p.id) < 100).toList();
    return '${studentPlans.length}';
  }

  String get masteredGoalCount {
    final studentPlans = plans.where((p) => goalProgress(p.id) >= 100).toList();
    return '${studentPlans.length}';
  }

  String get hardestLetter {
    final counts = <String, int>{};
    for (final evaluation in centerEvaluations
        .where((item) => item.score == 'خطأ' || item.severity >= 4)) {
      counts[evaluation.letter] = (counts[evaluation.letter] ?? 0) + 1;
    }
    if (counts.isEmpty) return '-';
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return '${sorted.first.key} (${sorted.first.value})';
  }

  String get mostUsedSign {
    final counts = <String, int>{};
    for (final session
        in centerSessions.where((item) => item.sessionType == 'لغة إشارة')) {
      for (final item in session.practiceItems
          .split(RegExp(r'[طŒ,]'))
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)) {
        counts[item] = (counts[item] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return '-';
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return '${sorted.first.key} (${sorted.first.value})';
  }

  List<TrainingItem> get speechTrainingBank => const [
        TrainingItem(
            id: 's1',
            type: 'word',
            title: 'باب',
            letter: 'ب',
            position: 'أول الكلمة',
            level: 'مبتدئ',
            category: 'كلمات'),
        TrainingItem(
            id: 's2',
            type: 'word',
            title: 'كوب',
            letter: 'ب',
            position: 'آخر الكلمة',
            level: 'مبتدئ',
            category: 'كلمات'),
        TrainingItem(
            id: 's3',
            type: 'sentence',
            title: 'باب البيت مفتوح',
            letter: 'ب',
            position: 'أول الكلمة',
            level: 'متوسط',
            category: 'جمل'),
        TrainingItem(
            id: 's4',
            type: 'word',
            title: 'سمك',
            letter: 'س',
            position: 'أول الكلمة',
            level: 'مبتدئ',
            category: 'كلمات'),
        TrainingItem(
            id: 's5',
            type: 'sentence',
            title: 'سامي يسمع الصوت',
            letter: 'س',
            position: 'وسط الكلمة',
            level: 'متوسط',
            category: 'جمل'),
      ];

  String get smartSessionSuggestion {
    if (evaluations.isEmpty && sessions.isEmpty) {
      return 'ابدأ بهدف قصير من الخطة الحالية ثم قيّم 5 محاولات.';
    }
    final weakEvaluation = evaluations
        .where((item) => item.score == 'خطأ' || item.severity >= 4)
        .toList();
    if (weakEvaluation.isNotEmpty) {
      final item = weakEvaluation.first;
      return 'اقترح تدريب حرف ${item.letter} في موضع ${item.position} بسبب تكرار ${item.errorType}.';
    }
    final lastSession = sessions.isEmpty ? null : sessions.first;
    if (lastSession != null && lastSession.successRate >= 85) {
      return 'الأداء ممتاز؛ جرّب مستوى أصعب وزد نقاط XP عند الإتقان.';
    }
    if (lastSession != null &&
        lastSession.letterPosition == 'آخر الكلمة' &&
        lastSession.quickResult == 'خطأ') {
      return 'ركّز على تدريبات آخر الكلمة في الجلسة القادمة.';
    }
    return 'استمر على هدف الخطة الحالي مع تقليل المساعدة تدريجيًا.';
  }

  bool get signLanguageEnabledForSelectedStudent {
    final student = selectedStudent;
    if (student == null) return true;
    return student.programType.contains('سمع') ||
        student.programType.contains('إشارة') ||
        plans.any((plan) => plan.goal.contains('إشارة'));
  }

  Future<void> initialize() async {
    try {
      startupError = null;
      setupRequired = !await _repository.hasUsers();
    } catch (error) {
      startupError = _cleanError(error);
    } finally {
      initialized = true;
      notifyListeners();
    }
  }

  Future<void> createSystemOwner({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    if (name.trim().isEmpty || email.trim().isEmpty || password.isEmpty) {
      throw StateError('أكمل بيانات مالك النظام.');
    }
    if (password.length < 8) {
      throw StateError('كلمة المرور يجب ألا تقل عن 8 أحرف.');
    }
    if (password != confirmPassword) {
      throw StateError('كلمتا المرور غير متطابقتين.');
    }
    await _repository.createSystemOwner(
        name: name.trim(), email: email.trim(), password: password);
    setupRequired = false;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    loading = true;
    notifyListeners();
    try {
      user = await _repository.login(email.trim(), password.trim());
      if (user != null) await loadHome();
      return user != null;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> resetLocalDatabaseForDevelopment() async {
    await _repository.resetLocalDatabase();
    logout();
    initialized = false;
    setupRequired = false;
    startupError = null;
    await initialize();
  }

  Future<void> changePassword(String newPassword) async {
    final current = _requireUser();
    if (newPassword.length < 6) {
      throw StateError('كلمة المرور يجب ألا تقل عن 6 أحرف.');
    }
    await _repository.changePassword(current, newPassword);
    user = AppUser(
      id: current.id,
      email: current.email,
      passwordHash: current.passwordHash,
      name: current.name,
      role: current.role,
      centerId: current.centerId,
      studentId: current.studentId,
      forcePasswordChange: false,
      isDemo: current.isDemo,
      isActive: current.isActive,
      createdAt: current.createdAt,
      updatedAt: DateTime.now().toIso8601String(),
    );
    notifyListeners();
  }

  void logout() {
    user = null;
    currentCenter = null;
    supportModeCenter = null;
    _realUserBeforeDemo = null;
    isDemoModeActive = false;
    demoModeUserId = null;
    centers = [];
    centerStudentCounts = {};
    centerSpecialistCounts = {};
    centerSessionCounts = {};
    centerLastActivities = {};
    staff = [];
    students = [];
    selectedStudent = null;
    sessions = [];
    evaluations = [];
    plans = [];
    exercises = [];
    studentProgramAssignments = [];
    studentTherapyPrograms = [];
    specialistProgramCapabilities = [];
    specialistCapabilityProgramsByUser = {};
    reports = [];
    studentFollowups = [];
    centerStudentFollowups = [];
    clinicalAssessments = [];
    clinicalFindingsByAssessment = {};
    therapyPrograms = [];
    assessmentSections = [];
    assessmentItems = [];
    assessmentOptions = [];
    skillStepTemplates = [];
    speechSoundTriggers = [];
    signResources = [];
    auditLogs = [];
    centerSessions = [];
    centerEvaluations = [];
    centerExercises = [];
    centerClinicalAssessments = [];
    _centerAssessmentsLoaded = false;
    notifications = [];
    reward = null;
    notifyListeners();
  }

  void toggleTheme() {
    darkMode = !darkMode;
    notifyListeners();
  }

  Future<void> loadHome() async {
    try {
      final current = _requireUser();
      final allCenters = await _repository.centers();
      totalStudentsCount = isOwner ? await _repository.totalStudents() : 0;
      totalSessionsCount = isOwner ? await _repository.totalSessions() : 0;
      centers = isOwner
          ? allCenters
          : isSupportMode && supportModeCenter != null
              ? allCenters
                  .where((center) => center.id == supportModeCenter!.id)
                  .toList()
              : allCenters
                  .where((center) => center.id == current.centerId)
                  .toList();
      if (isSupportMode && supportModeCenter != null) {
        final matches =
            allCenters.where((center) => center.id == supportModeCenter!.id);
        currentCenter = matches.isEmpty ? supportModeCenter : matches.first;
        supportModeCenter = currentCenter;
      } else if (isOwner) {
        final selectedCenter = currentCenter;
        currentCenter = selectedCenter == null ||
                centers.any((center) => center.id == selectedCenter.id)
            ? selectedCenter
            : null;
      } else if (current.centerId.isNotEmpty) {
        final matches =
            centers.where((center) => center.id == current.centerId).toList();
        currentCenter = matches.isEmpty ? null : matches.first;
      } else {
        currentCenter = null;
      }
      staff = canManageStaff || isCoordinator
          ? await _repository.users(centerId: isOwner ? null : activeCenterId)
          : [];
      await _loadCenterCardsMetrics();
      signResources = activeCenterId.isEmpty
          ? []
          : await _repository.signResources(activeCenterId);
      await _loadTherapyStructure();
      auditLogs = isOwner || isCenterManager
          ? await _repository.auditLogs(centerId: isOwner ? null : activeCenterId)
          : [];
      students = current.role == UserRole.parent
          ? await _repository.studentsForParent(current)
          : activeCenterId.isEmpty
              ? []
              : await _repository.students(activeCenterId);

      if (isSpecialist || isCoordinator || isCenterManager || isClinicalSupervisor) {
        studentProgramAssignments =
            await _repository.studentProgramAssignments();
        studentTherapyPrograms =
            await _repository.studentTherapyPrograms();
      }
      if (isSpecialist) {
        final myStudentIds = await _repository.studentIdsForSpecialist(current.id);
        students = students.where((s) => myStudentIds.contains(s.id)).toList();
        specialistProgramCapabilities =
            await _repository.activeCapabilitiesForSpecialist(current.id);
      }
      if (canManageStaff || isCoordinator) {
        final specialistUsers = staff
            .where((u) => u.role == UserRole.specialist)
            .toList();
        specialistCapabilityProgramsByUser = {};
        for (final spec in specialistUsers) {
          final caps =
              await _repository.activeCapabilitiesForSpecialist(spec.id);
          specialistCapabilityProgramsByUser[spec.id] =
              caps.map((c) => c.programId).toList();
        }
      }

      await _loadCenterMetrics();
      final currentSelection = selectedStudent;
      selectedStudent = currentSelection != null &&
              students.any((student) => student.id == currentSelection.id)
          ? currentSelection
          : null;
      await selectStudent(selectedStudent);
    } catch (error) {
      _debugLog('loadHome: $error');
      notifyListeners();
    }
  }

  Future<void> _loadTherapyStructure() async {
    if (!isGlobalTherapyStructureMode && activeCenterId.isEmpty) {
      assessmentSections = [];
      therapyPrograms = [];
      assessmentItems = [];
      assessmentOptions = [];
      skillStepTemplates = [];
      speechSoundTriggers = [];
      return;
    }
    try {
      final scopeCenterId = isGlobalTherapyStructureMode ? '' : activeCenterId;
      therapyPrograms = await _repository.therapyProgramTemplates(scopeCenterId);
      assessmentSections =
          await _repository.assessmentSectionTemplates(scopeCenterId);
      assessmentItems = await _repository.assessmentItemTemplates(scopeCenterId);
      assessmentOptions =
          await _repository.assessmentOptionTemplates(scopeCenterId);
      skillStepTemplates = await _repository.skillStepTemplates(scopeCenterId);
      speechSoundTriggers =
          await _repository.speechSoundTriggerTemplates(scopeCenterId);
    } catch (error) {
      _debugLog('_loadTherapyStructure: $error');
      assessmentSections = [];
      therapyPrograms = [];
      assessmentItems = [];
      assessmentOptions = [];
      skillStepTemplates = [];
      speechSoundTriggers = [];
    }
  }

  Future<void> enterSupportMode(SanadCenter center) async {
    _ensure(isSanadOwnerAccount, 'وضع المساعدة خاص بمالك سند فقط.');
    supportModeCenter = center;
    currentCenter = center;
    selectedStudent = null;
    await _log(
      action: 'دخل مالك سند وضع مساعدة مركز',
      entityType: 'center',
      entityId: center.id,
      centerId: center.id,
      details: center.name,
    );
    await loadHome();
  }

  Future<void> exitSupportMode() async {
    final center = supportModeCenter;
    if (center == null) return;
    await _log(
      action: 'خرج مالك سند من وضع مساعدة مركز',
      entityType: 'center',
      entityId: center.id,
      centerId: center.id,
      details: center.name,
    );
    supportModeCenter = null;
    currentCenter = null;
    selectedStudent = null;
    await loadHome();
  }

  Future<void> enterDemoMode(String demoUserId) async {
    _ensure(isSanadOwnerAccount || isDemoModeActive,
        'الوضع التجريبي خاص بمالك سند فقط.');
    if (!isDemoModeActive) {
      _realUserBeforeDemo = user;
    }
    final rows = await _repository.users(centerId: DemoDataService.demoCenterId);
    final demoUser = rows.cast<AppUser?>().firstWhere(
        (u) => u?.id == demoUserId,
        orElse: () => null);
    if (demoUser == null) {
      throw StateError('المستخدم التجريبي غير موجود. أنشئ البيانات التجريبية أولاً.');
    }
    user = demoUser;
    isDemoModeActive = true;
    demoModeUserId = demoUserId;
    selectedStudent = null;
    await loadHome();
    notifyListeners();
  }

  Future<void> exitDemoMode() async {
    if (!isDemoModeActive || _realUserBeforeDemo == null) return;
    user = _realUserBeforeDemo;
    _realUserBeforeDemo = null;
    isDemoModeActive = false;
    demoModeUserId = null;
    selectedStudent = null;
    supportModeCenter = null;
    currentCenter = null;
    await loadHome();
  }

  Future<void> switchCenter(SanadCenter center) async {
    _ensure(canManageCenters, 'إدارة المراكز خاصة بمالك النظام فقط.');
    currentCenter = center;
    selectedStudent = null;
    await loadHome();
  }

  Future<void> selectStudent(Student? student) async {
    if (student == null) {
      sessions = [];
      evaluations = [];
      plans = [];
      goalSkillSteps = [];
      exercises = [];
      reports = [];
      studentFollowups = [];
      clinicalAssessments = [];
      clinicalFindingsByAssessment = {};
      auditLogs = isOwner || isCenterManager
          ? await _repository.auditLogs(
              centerId: isOwner ? null : activeCenterId)
          : [];
      reward = null;
      studentProgramIds = [];
      selectedStudent = null;
      notifyListeners();
      return;
    }
    try {
      _ensureStudentAccess(student);
      selectedStudent = student;
      sessions = await _repository.sessions(student.id);
      studentFollowups = await _repository.studentFollowups(student.id);
      evaluations = await _repository.evaluations(student.id);
      plans = await _repository.plans(student.id);
      goalSkillSteps = await _repository.goalSkillSteps(student.id);
      exercises = await _repository.exercises(student.id);
      reports = await _repository.reports(student.id);
      clinicalAssessments = await _repository.clinicalAssessments(student.id);
      clinicalFindingsByAssessment = {};
      for (final assessment in clinicalAssessments) {
        clinicalFindingsByAssessment[assessment.id] =
            await _repository.clinicalFindings(assessment.id);
      }
      auditLogs = isOwner || isCenterManager
          ? await _repository.auditLogs(
              centerId: isOwner ? null : activeCenterId, studentId: student.id)
          : [];
      reward = await _repository.reward(student.id);
      studentProgramIds = await _repository.studentProgramIds(student.id);
    } catch (error) {
      _debugLog('فشل تحميل بيانات الطالب ${student.id}: $error');
      selectedStudent = null;
    }
    notifyListeners();
  }

  Future<void> selectStudentProgramContext({
    required String studentId,
    required String programId,
    String? specialistId,
  }) async {
    final student = _requireStudent(studentId);
    try {
      _ensureStudentAccess(student);
      selectedStudent = student;
      currentProgramId = programId;
      sessions = (await _repository.sessions(student.id))
          .where((s) => s.programId == programId)
          .toList();
      if (specialistId != null) {
        sessions = sessions.where((s) => s.specialistId == specialistId).toList();
      }
      studentFollowups = await _repository.studentFollowups(student.id);
      evaluations = await _repository.evaluations(student.id);
      plans = (await _repository.plansForProgram(student.id, programId)).toList();
      if (specialistId != null) {
        plans = plans.where((p) => p.specialistId == specialistId).toList();
      }
      goalSkillSteps = (await _repository.goalSkillSteps(student.id))
          .where((s) => s.programId == programId)
          .toList();
      exercises = (await _repository.exercises(student.id))
          .where((e) => e.programId == programId)
          .toList();
      reports = await _repository.reports(student.id);
      clinicalAssessments = (await _repository.clinicalAssessments(student.id))
          .where((a) => a.programId == programId)
          .toList();
      clinicalFindingsByAssessment = {};
      for (final assessment in clinicalAssessments) {
        clinicalFindingsByAssessment[assessment.id] =
            (await _repository.clinicalFindings(assessment.id))
                .where((f) => f.programId == programId)
                .toList();
      }
      auditLogs = isOwner || isCenterManager
          ? await _repository.auditLogs(
              centerId: isOwner ? null : activeCenterId, studentId: student.id)
          : [];
      reward = await _repository.reward(student.id);
      studentProgramIds = await _repository.studentProgramIds(student.id);
    } catch (error) {
      _debugLog('فشل تحميل سياق الطالب ${student.id} برنامج $programId: $error');
      selectedStudent = null;
      currentProgramId = null;
    }
    notifyListeners();
  }

  Student _requireStudent(String studentId) {
    for (final s in students) {
      if (s.id == studentId) return s;
    }
    throw StateError('الطالب غير موجود.');
  }

  void _debugLog(String message) {
    // ignore: avoid_print
    print('[Sanad] $message');
  }

  Future<void> _loadCenterMetrics() async {
    centerSessions = [];
    centerEvaluations = [];
    centerExercises = [];
    for (final student in students) {
      try {
        centerSessions.addAll(await _repository.sessions(student.id));
        centerEvaluations.addAll(await _repository.evaluations(student.id));
        centerExercises.addAll(await _repository.exercises(student.id));
      } catch (error) {
        _debugLog(
            'فشل تحميل بيانات الطالب ${student.id} في _loadCenterMetrics: $error');
      }
    }
  }

  Future<void> _loadCenterCardsMetrics() async {
    centerStudentCounts = {};
    centerSpecialistCounts = {};
    centerSessionCounts = {};
    centerLastActivities = {};
    if (!isOwner) return;
    for (final center in centers) {
      try {
        centerStudentCounts[center.id] =
            await _repository.centerStudentCount(center.id);
        centerSpecialistCounts[center.id] =
            await _repository.centerSpecialistCount(center.id);
        centerSessionCounts[center.id] =
            await _repository.centerSessionCount(center.id);
        centerLastActivities[center.id] =
            await _repository.centerLastActivity(center.id);
      } catch (error) {
        _debugLog('فشل تحميل إحصائيات المركز ${center.id}: $error');
      }
    }
  }

  Future<void> loadCenterPlansAndSteps() async {
    if (_centerPlansLoaded) return;
    centerPlans = [];
    centerGoalSteps = [];
    centerStudentFollowups = [];
    for (final student in students) {
      centerPlans.addAll(await _repository.plans(student.id));
      centerGoalSteps.addAll(await _repository.goalSkillSteps(student.id));
      centerStudentFollowups
          .addAll(await _repository.studentFollowups(student.id));
    }
    _centerPlansLoaded = true;
    notifyListeners();
  }

  Future<void> loadCenterAssessments() async {
    if (_centerAssessmentsLoaded) return;
    centerClinicalAssessments = [];
    for (final student in students) {
      centerClinicalAssessments
          .addAll(await _repository.clinicalAssessments(student.id));
    }
    _centerAssessmentsLoaded = true;
    notifyListeners();
  }

  Future<void> loadCenterReportSettings() async {
    if (activeCenterId.isEmpty) return;
    centerReportSettings =
        await _centerReportSettingsService.getForCenter(activeCenterId);
    notifyListeners();
  }

  Future<void> saveCenterReportSettings(CenterReportSettings s) async {
    _ensure(activeCenterId.isNotEmpty, 'لا يوجد مركز محدد.');
    final finalSettings = s.copyWith(centerId: activeCenterId);
    await _centerReportSettingsService.save(finalSettings);
    centerReportSettings = finalSettings;
    notifyListeners();
  }

  Future<void> updateCenterReportLogo(List<int> bytes, String fileName) async {
    _ensure(activeCenterId.isNotEmpty, 'لا يوجد مركز محدد.');
    await _centerReportSettingsService.updateLogo(
        activeCenterId, bytes, fileName);
    centerReportSettings =
        await _centerReportSettingsService.getForCenter(activeCenterId);
    notifyListeners();
  }

  Future<void> clearCenterReportLogo() async {
    _ensure(activeCenterId.isNotEmpty, 'لا يوجد مركز محدد.');
    await _centerReportSettingsService.clearLogo(activeCenterId);
    centerReportSettings =
        await _centerReportSettingsService.getForCenter(activeCenterId);
    notifyListeners();
  }

  Future<void> saveCenter(SanadCenter center) async {
    _ensure(
        canManageCenters || (isCenterManager && center.id == activeCenterId),
        'لا تملك صلاحية تعديل هذا المركز.');
    await _repository.saveCenter(center);
    await _log(
        action: 'حفظ مركز',
        entityType: 'center',
        entityId: center.id,
        centerId: center.id,
        details: center.name);
    final idx = centers.indexWhere((c) => c.id == center.id);
    if (idx != -1) {
      centers[idx] = center;
    } else {
      centers = await _repository.centers();
    }
    if (currentCenter?.id == center.id) currentCenter = center;
    notifyListeners();
  }

  Future<void> deleteCenter(String id) async {
    _ensure(canManageCenters, 'حذف المراكز خاص بمالك النظام فقط.');
    await _repository.deleteCenter(id);
    if (currentCenter?.id == id) {
      currentCenter = null;
      staff = [];
      students = [];
      sessions = [];
      evaluations = [];
      plans = [];
      goalSkillSteps = [];
      exercises = [];
      reports = [];
      clinicalAssessments = [];
      clinicalFindingsByAssessment = {};
    }
    await _log(
        action: 'حذف مركز', entityType: 'center', entityId: id, centerId: id);
    centers.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  Future<void> saveStaffUser(AppUser account) async {
    _ensure(canManageStaff, 'إدارة الموظفين غير متاحة لهذا الحساب.');
    if (!isOwner && account.centerId != activeCenterId) {
      throw StateError('لا يمكن إنشاء موظف خارج مركزك.');
    }
    if (!isOwner && account.role == UserRole.sanadOwner) {
      throw StateError('مالك النظام لا ينشأ إلا من مالك النظام.');
    }
    if (isOwner && account.role != UserRole.centerManager) {
      throw StateError('مالك سند ينشئ مدراء المراكز فقط.');
    }
    if (!isOwner &&
        !{
          UserRole.clinicalSupervisor,
          UserRole.therapyProgramEntry,
          UserRole.coordinator,
          UserRole.dataEntry,
          UserRole.specialist,
        }.contains(account.role)) {
      throw StateError(
          'مدير المركز ينشئ مشرفًا فنيًا أو مدخل برامج أو منسقًا أو سكرتارية أو أخصائيًا فقط.');
    }
    await _repository.saveUser(account);
    await _log(
        action: 'حفظ موظف',
        entityType: 'user',
        entityId: account.id,
        centerId: account.centerId,
        details: '${account.name} - ${account.role.label}');
    final idx = staff.indexWhere((u) => u.id == account.id);
    if (idx != -1) {
      staff[idx] = account;
    } else {
      staff.add(account);
    }
    notifyListeners();
  }

  Future<void> setSpecialistCapabilities(
    String specialistId,
    List<String> programIds,
  ) async {
    _ensure(canManageStaff, 'إدارة الموظفين غير متاحة لهذا الحساب.');
    final current = _requireUser();
    await _repository.setCapabilitiesForSpecialist(
      specialistId,
      activeCenterId,
      current.id,
      programIds,
    );
    if (specialistId == current.id) {
      specialistProgramCapabilities =
          await _repository.activeCapabilitiesForSpecialist(specialistId);
    }
    specialistCapabilityProgramsByUser[specialistId] = programIds;
    notifyListeners();
  }

  Future<void> setStaffUserActive(AppUser account, bool isActive) async {
    _ensure(canManageStaff, 'إدارة الموظفين غير متاحة لهذا الحساب.');
    if (!isOwner && account.centerId != activeCenterId) {
      throw StateError('لا يمكن تعديل موظف خارج مركزك.');
    }
    await _repository.saveUser(AppUser(
      id: account.id,
      email: account.email,
      passwordHash: account.passwordHash,
      name: account.name,
      role: account.role,
      centerId: account.centerId,
      studentId: account.studentId,
      forcePasswordChange: account.forcePasswordChange,
      isDemo: account.isDemo,
      isActive: isActive,
      createdAt: account.createdAt,
      updatedAt: DateTime.now().toIso8601String(),
    ));
    final idx = staff.indexWhere((u) => u.id == account.id);
    if (idx != -1) staff[idx] = account;
    notifyListeners();
  }

  Future<void> changeStaffPassword(AppUser account, String newPassword) async {
    _ensure(canManageStaff, 'إدارة الموظفين غير متاحة لهذا الحساب.');
    if (newPassword.length < 8) {
      throw StateError('كلمة المرور يجب ألا تقل عن 8 أحرف.');
    }
    if (!isOwner && account.centerId != activeCenterId) {
      throw StateError('لا يمكن تعديل حساب خارج مركزك.');
    }
    if (isOwner && account.role != UserRole.centerManager) {
      throw StateError(
          'مالك النظام يغير كلمة مرور مدراء المراكز فقط من هذه الشاشة.');
    }
    await _repository.changeUserPassword(account.id, newPassword);
    notifyListeners();
  }

  Future<void> deleteStaffUser(AppUser account) async {
    _ensure(canManageStaff, 'إدارة الموظفين غير متاحة لهذا الحساب.');
    if (!isOwner && account.centerId != activeCenterId) {
      throw StateError('لا يمكن حذف موظف خارج مركزك.');
    }
    if (account.role == UserRole.sanadOwner) {
      throw StateError('لا يمكن حذف مالك سند.');
    }
    if (user?.id == account.id) {
      throw StateError('لا يمكن حذف حسابك الحالي.');
    }
    await _repository.deleteUser(account.id);
    staff.removeWhere((u) => u.id == account.id);
    notifyListeners();
  }

  Future<Student> saveStudent(Student student) async {
    _ensure(canManageStudents, 'لا تملك صلاحية حفظ الطلاب.');
    final centerStudent = Student(
      id: student.id,
      centerId: isOwner ? student.centerId : activeCenterId,
      name: student.name,
      age: student.age,
      status: student.status,
      diagnosis: student.diagnosis,
      programType: student.programType,
      parentName: student.parentName,
      parentPhone: student.parentPhone,
      portalEmail: student.portalEmail,
      portalPassword: student.portalPassword,
      photoPath: student.photoPath,
      notes: student.notes,
      deletedAt: student.deletedAt,
      createdAt: student.createdAt,
      updatedAt: student.updatedAt,
    );
    await _repository.saveStudent(centerStudent);
    await _log(
        action: 'حفظ طالب',
        entityType: 'student',
        entityId: centerStudent.id,
        centerId: centerStudent.centerId,
        details: centerStudent.name);
    final idx = students.indexWhere((s) => s.id == centerStudent.id);
    if (idx != -1) {
      students[idx] = centerStudent;
    } else {
      students = await _repository.students(activeCenterId);
    }
    selectedStudent = centerStudent;
    notifyListeners();
    return centerStudent;
  }

  Future<void> deleteStudent(String id) async {
    _ensure(canDeleteStudents, 'لا تملك صلاحية حذف الطلاب.');
    await _repository.softDeleteStudent(id);
    await _log(
        action: 'حذف طالب',
        entityType: 'student',
        entityId: id,
        centerId: activeCenterId);
    selectedStudent = null;
    students.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  Future<void> assignStudentProgram(
      String studentId, String programId) async {
    final existing = studentProgramIds.contains(programId);
    if (existing) return;
    await _repository.saveStudentTherapyProgram(StudentTherapyProgram(
      id: 'stp_${studentId}_$programId',
      studentId: studentId,
      programId: programId,
      assignedAt: DateTime.now().toIso8601String(),
      assignedByUserId: user?.id ?? '',
      sortOrder: studentProgramIds.length,
    ));
    studentProgramIds.add(programId);
    notifyListeners();
  }

  Future<void> unassignStudentProgram(
      String studentId, String programId) async {
    await _repository.removeStudentTherapyProgram(studentId, programId);
    studentProgramIds.remove(programId);
    notifyListeners();
  }

  // ── Student Program Assignments ────────────────────────────────────

  Future<void> loadStudentProgramAssignments() async {
    studentProgramAssignments =
        await _repository.studentProgramAssignments();
    notifyListeners();
  }

  Future<void> assignProgramToSpecialist({
    required String studentId,
    required String programId,
    required String specialistId,
    required String centerId,
  }) async {
    final id = 'spa_${DateTime.now().millisecondsSinceEpoch}';
    await _repository.assignProgramToSpecialist(StudentProgramAssignment(
      id: id,
      centerId: centerId,
      studentId: studentId,
      programId: programId,
      specialistId: specialistId,
      role: 'primary',
      status: 'active',
      assignedByUserId: user?.id ?? '',
      assignedAt: DateTime.now().toIso8601String(),
    ));
    await loadStudentProgramAssignments();
  }

  Future<void> replaceSpecialistForProgram({
    required String studentId,
    required String programId,
    required String newSpecialistId,
    required String centerId,
    String notes = '',
  }) async {
    final newId = 'spa_${DateTime.now().millisecondsSinceEpoch}';
    await _repository.replaceSpecialistForProgram(
      studentId: studentId,
      programId: programId,
      newSpecialistId: newSpecialistId,
      centerId: centerId,
      userId: user?.id ?? '',
      userName: user?.name ?? '',
      newAssignmentId: newId,
      notes: notes,
    );
    await loadStudentProgramAssignments();
  }

  Future<void> deactivateAssignment(String id) async {
    await _repository.deactivateAssignment(id);
    await loadStudentProgramAssignments();
  }

  Future<void> reactivateAssignment(String id) async {
    await _repository.reactivateAssignment(id);
    await loadStudentProgramAssignments();
  }

  List<TherapyProgramTemplate> programsForStudent() {
    if (studentProgramIds.isEmpty) return [];
    return therapyPrograms
        .where((p) => studentProgramIds.contains(p.id))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  void preselectSession(Map<String, String> target) {
    sessionPreselect = target;
    notifyListeners();
  }

  void clearSessionPreselect() {
    sessionPreselect = null;
    notifyListeners();
  }

  Future<void> saveSession(TherapySession session,
      {bool autosave = false}) async {
    _ensure(canRunSessions, 'الجلسات ينفذها الأخصائي فقط.');
    _ensureClinicalAccess(session.studentId, session.centerId);
    await _repository.saveSession(session);
    if (!autosave) {
      await _log(
          action: 'إنشاء جلسة',
          entityType: 'session',
          entityId: session.id,
          centerId: session.centerId,
          details:
              '${session.studentId} - ${session.sessionType} - ${session.cardTitle}');
      await _grantXp(
          session.studentId,
          session.quickResult == 'متقن'
              ? 2
              : session.quickResult == 'بمساعدة'
                  ? 1
                  : 0);
    }
    final idx = sessions.indexWhere((s) => s.id == session.id);
    if (idx != -1) { sessions[idx] = session; } else { sessions.add(session); }
    final centerIdx = centerSessions.indexWhere((s) => s.id == session.id);
    if (centerIdx != -1) { centerSessions[centerIdx] = session; } else { centerSessions.add(session); }
    notifyListeners();
  }

  Future<void> saveSessionSkillResult(SessionSkillResult result) async {
    await _repository.saveSessionSkillResult(result);
  }

  Future<void> correctSessionResult({
    required String sessionId,
    required String newQuickResult,
    required int newSuccessRate,
  }) async {
    _ensure(canRunSessions, 'تصحيح النتيجة متاح للأخصائي فقط.');
    final idx = sessions.indexWhere((s) => s.id == sessionId);
    if (idx == -1) throw StateError('الجلسة غير موجودة.');
    final old = sessions[idx];

    final isCreator = old.specialistId == user?.id;
    if (!isCreator && !isCenterManager) {
      throw StateError('يمكن لكاتب الجلسة أو مدير المركز فقط تصحيح النتيجة.');
    }

    final createdAt = DateTime.tryParse(old.startedAt);
    if (createdAt != null) {
      final hoursSince = DateTime.now().difference(createdAt).inHours;
      if (hoursSince >= 24) {
        throw StateError('انتهت فترة التصحيح (24 ساعة).');
      }
    }

    final corrected = TherapySession(
      id: old.id,
      centerId: old.centerId,
      studentId: old.studentId,
      specialistId: old.specialistId,
      planId: old.planId,
      programId: old.programId,
      skillId: old.skillId,
      activityResults: old.activityResults,
      sessionType: old.sessionType,
      targetLetter: old.targetLetter,
      letterPosition: old.letterPosition,
      errorType: old.errorType,
      practiceItems: old.practiceItems,
      attempts: old.attempts,
      successRate: newSuccessRate,
      startedAt: old.startedAt,
      durationSeconds: old.durationSeconds,
      cardTitle: old.cardTitle,
      quickResult: newQuickResult,
      notes: old.notes,
      summary: old.summary,
      createdAt: old.createdAt,
      updatedAt: DateTime.now().toIso8601String(),
    );
    await _repository.saveSession(corrected);
    sessions[idx] = corrected;

    await syncGoalProgress(old.planId);

    if (newQuickResult == 'متقن') {
      await _repository.resolveFollowupsByPlan(old.planId);
    } else if (old.quickResult == 'متقن') {
      final now = DateTime.now().toIso8601String();
      final existing =
          await _repository.pendingFollowupForPlan(old.planId);
      if (existing == null) {
        await _repository.saveStudentFollowup(StudentFollowup(
          id: 'fu_${old.planId}_${now.hashCode}',
          studentId: old.studentId,
          specialistId: user?.id ?? old.specialistId,
          programId: old.programId,
          sourceType: '',
          planId: old.planId,
          goalSkillStepId: '',
          reason: newQuickResult == 'بمساعدة' ? 'assisted' : 'retry',
          createdAt: now,
          lastOpenedAt: now,
        ));
      }
    }

    if (selectedStudent != null) {
      studentFollowups =
          await _repository.studentFollowups(selectedStudent!.id);
    }
    notifyListeners();
  }

  Future<void> saveEvaluation(Evaluation evaluation) async {
    _ensure(canWriteClinical, 'التقييم يضيفه الأخصائي فقط.');
    _ensureClinicalAccess(evaluation.studentId, evaluation.centerId);
    await _repository.saveEvaluation(evaluation);
    await _log(
        action: 'حفظ تقييم',
        entityType: 'evaluation',
        entityId: evaluation.id,
        centerId: evaluation.centerId,
        details:
            '${evaluation.studentId} - ${evaluation.letter} - ${evaluation.errorType}');
    final idx = evaluations.indexWhere((e) => e.id == evaluation.id);
    if (idx != -1) { evaluations[idx] = evaluation; } else { evaluations.add(evaluation); }
    notifyListeners();
  }

  Future<void> savePlan(TrainingPlan plan) async {
    _ensure(canWriteClinical || canUpdateGoalProgress,
        'لا تملك صلاحية تعديل الخطط.');
    _ensureClinicalAccess(plan.studentId, plan.centerId);
    await _repository.savePlan(plan);
    await _log(
        action: 'حفظ خطة',
        entityType: 'plan',
        entityId: plan.id,
        centerId: plan.centerId,
        details: '${plan.studentId} - ${plan.goal}');
    final idx = plans.indexWhere((p) => p.id == plan.id);
    if (idx != -1) { plans[idx] = plan; } else { plans.add(plan); }
    notifyListeners();
  }

  List<GoalSkillStep> stepsForGoal(String goalId) =>
      goalSkillSteps.where((step) => step.goalId == goalId).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  int goalProgress(String goalId) {
    final steps = stepsForGoal(goalId);
    if (steps.isNotEmpty) {
      final completed = steps.where((step) => step.status == 'متقن').length;
      return ((completed / steps.length) * 100).round();
    }
    final goalSessions = sessions.where((s) => s.planId == goalId).toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    if (goalSessions.isEmpty) {
      final matches = plans.where((item) => item.id == goalId).toList();
      return matches.isEmpty ? 0 : matches.first.progress;
    }
    switch (goalSessions.first.quickResult) {
      case 'متقن':
        return 100;
      case 'بمساعدة':
        return 50;
      default:
        return 0;
    }
  }

  String goalStatus(String goalId) {
    final progress = goalProgress(goalId);
    if (progress >= 100) return 'متقن';
    final steps = stepsForGoal(goalId);
    if (steps.any((s) => s.status == 'يحتاج إعادة')) return 'يحتاج إعادة';
    if (steps.any((s) => s.status == 'بمساعدة')) return 'يحتاج مساعدة';
    if (steps.isEmpty) {
      final goalSessions = sessions.where((s) => s.planId == goalId).toList()
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
      if (goalSessions.isNotEmpty) {
        final lastResult = goalSessions.first.quickResult;
        if (lastResult == 'يحتاج إعادة') return 'يحتاج إعادة';
        if (lastResult == 'بمساعدة') return 'يحتاج مساعدة';
      }
    }
    if (progress > 0) return 'قيد العلاج';
    final hasStarted =
        steps.any((step) => step.status != 'لم يبدأ' && step.status.isNotEmpty);
    return hasStarted ? 'قيد العلاج' : 'جديد';
  }

  Future<void> saveGoalSkillStep(GoalSkillStep step) async {
    _ensure(canUpdateGoalProgress, 'تتبع الأهداف يحدّثه الأخصائي فقط.');
    _ensureClinicalAccess(step.studentId, step.centerId);
    await _repository.saveGoalSkillStep(step);
    final stepIdx = goalSkillSteps.indexWhere((s) => s.id == step.id);
    if (stepIdx != -1) { goalSkillSteps[stepIdx] = step; } else { goalSkillSteps.add(step); }
    await syncGoalProgress(step.goalId);
    notifyListeners();
  }

  Future<void> updateGoalSkillStepStatus({
    required GoalSkillStep step,
    required String status,
    required String notes,
    String lastSessionId = '',
  }) async {
    _ensure(canUpdateGoalProgress, 'تتبع الأهداف يحدّثه الأخصائي فقط.');
    _ensureClinicalAccess(step.studentId, step.centerId);
    final updated = step.copyWith(
      status: status,
      notes: notes,
      lastSessionId: lastSessionId.isEmpty ? step.lastSessionId : lastSessionId,
      updatedAt: DateTime.now().toIso8601String(),
    );
    await _repository.saveGoalSkillStep(updated);
    final stepIdx = goalSkillSteps.indexWhere((s) => s.id == step.id);
    if (stepIdx != -1) goalSkillSteps[stepIdx] = updated;
    await syncGoalProgress(step.goalId);
    notifyListeners();
  }

  Future<void> updatePlanProgress({
    required String planId,
    required int progress,
  }) async {
    final matches = plans.where((p) => p.id == planId).toList();
    if (matches.isEmpty) return;
    final plan = matches.first;
    final updated = TrainingPlan(
      id: plan.id,
      centerId: plan.centerId,
      studentId: plan.studentId,
      goal: plan.goal,
      treatment: plan.treatment,
      targetDate: plan.targetDate,
      progress: progress,
      programId: plan.programId,
      sourceType: plan.sourceType,
      specialistId: plan.specialistId,
      createdAt: plan.createdAt,
      updatedAt: DateTime.now().toIso8601String(),
    );
    await _repository.savePlan(updated);
    final planIdx = plans.indexWhere((p) => p.id == planId);
    if (planIdx != -1) plans[planIdx] = updated;
    notifyListeners();
  }

  Future<void> syncGoalProgress(String goalId) async {
    final goalSteps = await _repository.goalStepsForGoal(goalId);
    final matches = plans.where((plan) => plan.id == goalId).toList();
    if (matches.isEmpty) return;
    final plan = matches.first;
    final completed = goalSteps.where((step) => step.status == 'متقن').length;
    final progress = goalSteps.isEmpty
        ? plan.progress
        : ((completed / goalSteps.length) * 100).round();
    final updated = TrainingPlan(
      id: plan.id,
      centerId: plan.centerId,
      studentId: plan.studentId,
      goal: plan.goal,
      treatment: plan.treatment,
      targetDate: plan.targetDate,
      progress: progress,
      programId: plan.programId,
      sourceType: plan.sourceType,
      specialistId: plan.specialistId,
      createdAt: plan.createdAt,
      updatedAt: DateTime.now().toIso8601String(),
    );
    await _repository.savePlan(updated);
    final planIdx = plans.indexWhere((p) => p.id == goalId);
    if (planIdx != -1) plans[planIdx] = updated;
  }

  List<StudentFollowup> get pendingFollowups =>
      studentFollowups.where((f) => f.status == 'pending').toList();

  List<StudentFollowup> get centerPendingFollowups =>
      centerStudentFollowups.where((f) => f.status == 'pending').toList();

  Future<void> upsertFollowup({
    required String studentId,
    required String specialistId,
    required String programId,
    required String sourceType,
    required String planId,
    required String goalSkillStepId,
    required String reason,
  }) async {
    final now = DateTime.now().toIso8601String();
    final existing =
        await _repository.pendingFollowupForStep(studentId, goalSkillStepId);
    if (existing != null) {
      final updated = existing.copyWith(
        lastOpenedAt: now,
      );
      await _repository.saveStudentFollowup(updated);
    } else {
      await _repository.saveStudentFollowup(StudentFollowup(
        id: 'fu_${goalSkillStepId}_${now.hashCode}',
        studentId: studentId,
        specialistId: specialistId,
        programId: programId,
        sourceType: sourceType,
        planId: planId,
        goalSkillStepId: goalSkillStepId,
        reason: reason,
        createdAt: now,
        lastOpenedAt: now,
      ));
    }
    studentFollowups = await _repository.studentFollowups(studentId);
    notifyListeners();
  }

  Future<void> resolveFollowupForStep(
      String studentId, String goalSkillStepId) async {
    await _repository.resolveFollowupForStep(studentId, goalSkillStepId);
    if (selectedStudent != null) {
      studentFollowups =
          await _repository.studentFollowups(selectedStudent!.id);
    }
    notifyListeners();
  }

  Future<StudentFollowup?> pendingFollowupForStep(
          String studentId, String goalSkillStepId) =>
      _repository.pendingFollowupForStep(studentId, goalSkillStepId);

  Future<void> saveClinicalAssessment({
    required ClinicalAssessment assessment,
    required List<ClinicalFinding> findings,
  }) async {
    _ensure(canWriteClinical, 'التقييم العلاجي يضيفه الأخصائي فقط.');
    _ensureClinicalAccess(assessment.studentId, assessment.centerId);
    try {
      await _repository.saveClinicalAssessment(assessment);
    } catch (e) {
      _debugLog('saveClinicalAssessment: فشل حفظ التقييم: $e');
      _debugLog('assessment data: ${assessment.toMap()}');
      rethrow;
    }
    final existingPlans = await _repository.plans(assessment.studentId);
    for (final finding in findings) {
      try {
        await _repository.saveClinicalFinding(finding);
      } catch (e) {
        _debugLog('saveClinicalAssessment: فشل حفظ finding ${finding.id}: $e');
        _debugLog('finding data: ${finding.toMap()}');
        rethrow;
      }
      if (!finding.isNormal && finding.goal.trim().isNotEmpty) {
        // Skip if an active plan with the same goal + programId already exists
        final isDuplicate = existingPlans.any((p) =>
            p.programId == finding.programId &&
            p.goal == finding.goal &&
            goalProgress(p.id) < 100);
        if (isDuplicate) continue;
        final planId = 'plan_${finding.id}';
        final now = DateTime.now().toIso8601String();
      final training =
          finding.training.trim().isEmpty ? finding.goal : finding.training;
      try {
        await _repository.savePlan(
          TrainingPlan(
            id: planId,
            centerId: finding.centerId,
            studentId: finding.studentId,
            goal: finding.goal,
            treatment: training,
            targetDate: DateTime.now()
                .add(const Duration(days: 45))
                .toIso8601String()
                .split('T')
                .first,
            progress: 0,
            programId: finding.programId,
            sourceType: finding.sourceType,
            specialistId: assessment.specialistId,
            createdAt: now,
            updatedAt: now,
          ),
        );
      } catch (e) {
        _debugLog('saveClinicalAssessment: فشل حفظ training_plan $planId: $e');
        rethrow;
      }
        final templateSteps = _skillStepTemplatesForFinding(finding);
        for (var index = 0; index < templateSteps.length; index++) {
          try {
            await _repository.saveGoalSkillStep(GoalSkillStep(
              id: 'step_${finding.id}_${index + 1}',
              centerId: finding.centerId,
              studentId: finding.studentId,
              goalId: planId,
              title: templateSteps[index].title,
              sortOrder: index,
              programId: finding.programId,
              sourceType: finding.sourceType,
              specialistId: assessment.specialistId,
              createdAt: now,
              updatedAt: now,
            ));
          } catch (e) {
            _debugLog('saveClinicalAssessment: فشل حفظ goal_skill_step step_${finding.id}_${index + 1}: $e');
            rethrow;
          }
        }
      }
    }
    await _log(
      action: 'حفظ تقييم علاجي نطقي',
      entityType: 'clinical_assessment',
      entityId: assessment.id,
      centerId: assessment.centerId,
      details: '${assessment.studentId} - ${findings.length} بنود',
    );
    if (selectedStudent != null) {
      plans = await _repository.plans(selectedStudent!.id);
      goalSkillSteps = await _repository.goalSkillSteps(selectedStudent!.id);
    }
    clinicalAssessments.add(assessment);
    clinicalFindingsByAssessment[assessment.id] =
        findings.where((f) => f.assessmentId == assessment.id).toList();
    centerClinicalAssessments.add(assessment);
    _centerAssessmentsLoaded = false;
    notifyListeners();
  }

  Future<void> saveAssessmentSectionTemplate(
      AssessmentSectionTemplate section) async {
    _ensure(canManageTherapyStructure,
        'بناء الهيكل العلاجي متاح لمدخل البرامج أو مدير المركز فقط.');
    final writeCenterId = therapyStructureWriteCenterId;
    final normalized = AssessmentSectionTemplate(
      id: section.id,
      centerId: writeCenterId,
      programId: section.programId,
      title: section.title,
      description: section.description,
      sortOrder: section.sortOrder,
      createdAt: section.createdAt,
      updatedAt: section.updatedAt,
    );
    await _repository.saveAssessmentSectionTemplate(normalized);
    await _logTherapyStructureChange('حفظ قسم تقييم', normalized.id,
        centerId: writeCenterId, details: normalized.title);
    await _loadTherapyStructure();
    notifyListeners();
  }

  Future<void> saveTherapyProgramTemplate(
      TherapyProgramTemplate program) async {
    _ensure(canManageTherapyStructure,
        'بناء البرامج العلاجية متاح للصلاحيات العلاجية المعتمدة فقط.');
    final writeCenterId = therapyStructureWriteCenterId;
    final normalized = TherapyProgramTemplate(
      id: program.id,
      centerId: writeCenterId,
      name: program.name,
      description: program.description,
      usesSpeechSounds: program.usesSpeechSounds,
      sortOrder: program.sortOrder,
      createdAt: program.createdAt,
      updatedAt: program.updatedAt,
    );
    await _repository.saveTherapyProgramTemplate(normalized);
    await _logTherapyStructureChange('حفظ برنامج علاجي', normalized.id,
        centerId: writeCenterId, details: normalized.name);
    await _loadTherapyStructure();
    notifyListeners();
  }

  Future<void> deleteTherapyProgramTemplate(String id) async {
    _ensure(canManageTherapyStructure,
        'بناء البرامج العلاجية متاح للصلاحيات العلاجية المعتمدة فقط.');
    final program = therapyPrograms.firstWhere((entry) => entry.id == id);
    _ensureCanWriteTherapyTemplate(program.centerId);
    await _repository.deleteTherapyProgramTemplate(id);
    await _logTherapyStructureChange('حذف برنامج علاجي', id,
        centerId: program.centerId, details: program.name);
    await _loadTherapyStructure();
    notifyListeners();
  }

  Future<void> saveAssessmentItemTemplate(AssessmentItemTemplate item) async {
    _ensure(canManageTherapyStructure,
        'بناء الهيكل العلاجي متاح لمدخل البرامج أو مدير المركز فقط.');
    final section =
        assessmentSections.firstWhere((entry) => entry.id == item.sectionId);
    _ensureCanWriteTherapyTemplate(section.centerId);
    final writeCenterId = section.centerId;
    final normalized = AssessmentItemTemplate(
      id: item.id,
      centerId: writeCenterId,
      sectionId: item.sectionId,
      title: item.title,
      responseType: item.responseType,
      responseMode: item.responseMode,
      prompt: item.prompt,
      sortOrder: item.sortOrder,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
    );
    await _repository.saveAssessmentItemTemplate(normalized);
    await _logTherapyStructureChange('حفظ بند تقييم', normalized.id,
        centerId: writeCenterId, details: normalized.title);
    await _loadTherapyStructure();
    notifyListeners();
  }

  Future<void> saveAssessmentOptionTemplate(
      AssessmentOptionTemplate option) async {
    _ensure(canManageTherapyStructure,
        'بناء الهيكل العلاجي متاح لمدخل البرامج أو مدير المركز فقط.');
    final item =
        assessmentItems.firstWhere((entry) => entry.id == option.itemId);
    _ensureCanWriteTherapyTemplate(item.centerId);
    final writeCenterId = item.centerId;
    final normalized = AssessmentOptionTemplate(
      id: option.id,
      centerId: writeCenterId,
      itemId: option.itemId,
      label: option.label,
      generatesTherapy: option.generatesTherapy,
      weaknessTemplate: option.weaknessTemplate,
      goalTemplate: option.goalTemplate,
      therapyTemplate: option.therapyTemplate,
      sortOrder: option.sortOrder,
      createdAt: option.createdAt,
      updatedAt: option.updatedAt,
    );
    await _repository.saveAssessmentOptionTemplate(normalized);
    await _logTherapyStructureChange('حفظ احتمال تقييم', normalized.id,
        centerId: writeCenterId, details: normalized.label);
    await _loadTherapyStructure();
    notifyListeners();
  }

  Future<void> saveSkillStepTemplate(SkillStepTemplate step) async {
    _ensure(canManageTherapyStructure,
        'بناء الهيكل العلاجي متاح لمدخل البرامج أو مدير المركز فقط.');
    final writeCenterId = _skillStepOwnerCenterId(step.ownerType, step.ownerId);
    _ensureCanWriteTherapyTemplate(writeCenterId);
    final normalized = SkillStepTemplate(
      id: step.id,
      centerId: writeCenterId,
      ownerType: step.ownerType,
      ownerId: step.ownerId,
      title: step.title,
      sortOrder: step.sortOrder,
      createdAt: step.createdAt,
      updatedAt: step.updatedAt,
    );
    await _repository.saveSkillStepTemplate(normalized);
    await _logTherapyStructureChange('حفظ خطوة مهارية', normalized.id,
        centerId: writeCenterId, details: normalized.title);
    await _loadTherapyStructure();
    notifyListeners();
  }

  Future<void> saveSpeechSoundTriggerTemplate(
      SpeechSoundTriggerTemplate trigger) async {
    _ensure(canManageTherapyStructure,
        'بناء الهيكل العلاجي متاح لمدخل البرامج أو مدير المركز فقط.');
    final writeCenterId = therapyStructureWriteCenterId;
    final normalized = SpeechSoundTriggerTemplate(
      id: trigger.id,
      centerId: writeCenterId,
      programId: trigger.programId,
      letter: trigger.letter,
      errorType: trigger.errorType,
      position: trigger.position,
      generatesTherapy: trigger.generatesTherapy,
      weaknessTemplate: trigger.weaknessTemplate,
      goalTemplate: trigger.goalTemplate,
      therapyTemplate: trigger.therapyTemplate,
      skillStepTemplates: trigger.skillStepTemplates,
      sortOrder: trigger.sortOrder,
      createdAt: trigger.createdAt,
      updatedAt: trigger.updatedAt,
    );
    await _repository.saveSpeechSoundTriggerTemplate(normalized);
    await _logTherapyStructureChange('حفظ خلية مصفوفة حروف', normalized.id,
        centerId: writeCenterId,
        details:
            '${normalized.letter} - ${normalized.errorType} - ${normalized.position}');
    await _loadTherapyStructure();
    notifyListeners();
  }

  Future<void> deleteAssessmentSectionTemplate(String id) async {
    _ensure(canManageTherapyStructure,
        'بناء الهيكل العلاجي متاح لمدخل البرامج أو مدير المركز فقط.');
    final section = assessmentSections.firstWhere((entry) => entry.id == id);
    _ensureCanWriteTherapyTemplate(section.centerId);
    await _repository.deleteAssessmentSectionTemplate(id);
    await _logTherapyStructureChange('حذف قسم تقييم', id,
        centerId: section.centerId, details: section.title);
    await _loadTherapyStructure();
    notifyListeners();
  }

  String _skillStepOwnerCenterId(String ownerType, String ownerId) {
    if (ownerType == 'option') {
      return assessmentOptions
          .firstWhere((entry) => entry.id == ownerId)
          .centerId;
    }
    if (ownerType == 'sound') {
      return speechSoundTriggers
          .firstWhere((entry) => entry.id == ownerId)
          .centerId;
    }
    return therapyStructureWriteCenterId;
  }

  Future<void> deleteAssessmentItemTemplate(String id) async {
    _ensure(canManageTherapyStructure,
        'بناء الهيكل العلاجي متاح لمدخل البرامج أو مدير المركز فقط.');
    final item = assessmentItems.firstWhere((entry) => entry.id == id);
    _ensureCanWriteTherapyTemplate(item.centerId);
    await _repository.deleteAssessmentItemTemplate(id);
    await _logTherapyStructureChange('حذف بند تقييم', id,
        centerId: item.centerId, details: item.title);
    await _loadTherapyStructure();
    notifyListeners();
  }

  Future<void> deleteAssessmentOptionTemplate(String id) async {
    _ensure(canManageTherapyStructure,
        'بناء الهيكل العلاجي متاح لمدخل البرامج أو مدير المركز فقط.');
    final option = assessmentOptions.firstWhere((entry) => entry.id == id);
    _ensureCanWriteTherapyTemplate(option.centerId);
    await _repository.deleteAssessmentOptionTemplate(id);
    await _logTherapyStructureChange('حذف احتمال تقييم', id,
        centerId: option.centerId, details: option.label);
    await _loadTherapyStructure();
    notifyListeners();
  }

  Future<void> deleteSkillStepTemplate(String id) async {
    _ensure(canManageTherapyStructure,
        'بناء الهيكل العلاجي متاح لمدخل البرامج أو مدير المركز فقط.');
    final step = skillStepTemplates.firstWhere((entry) => entry.id == id);
    _ensureCanWriteTherapyTemplate(step.centerId);
    await _repository.deleteSkillStepTemplate(id);
    await _logTherapyStructureChange('حذف خطوة مهارية', id,
        centerId: step.centerId, details: step.title);
    await _loadTherapyStructure();
    notifyListeners();
  }

  Future<void> deleteSpeechSoundTriggerTemplate(String id) async {
    _ensure(canManageTherapyStructure,
        'بناء الهيكل العلاجي متاح لمدخل البرامج أو مدير المركز فقط.');
    final trigger = speechSoundTriggers.firstWhere((entry) => entry.id == id);
    _ensureCanWriteTherapyTemplate(trigger.centerId);
    await _repository.deleteSpeechSoundTriggerTemplate(id);
    await _logTherapyStructureChange('حذف خلية مصفوفة حروف', id,
        centerId: trigger.centerId,
        details: '${trigger.letter} - ${trigger.errorType}');
    await _loadTherapyStructure();
    notifyListeners();
  }

  void _ensureCanWriteTherapyTemplate(String templateCenterId) {
    if (templateCenterId.isEmpty) {
      _ensure(isGlobalTherapyStructureMode,
          'قوالب سند العامة يعدلها مالك سند فقط من إدارة سند.');
    } else {
      _ensure(isSupportMode || templateCenterId == activeCenterId,
          'لا يمكن تعديل قوالب مركز آخر.');
    }
  }

  bool canEditTherapyTemplate(String templateCenterId) {
    if (templateCenterId.isEmpty) return isGlobalTherapyStructureMode;
    return isSupportMode || templateCenterId == activeCenterId;
  }

  Future<void> _logTherapyStructureChange(String action, String entityId,
      {required String centerId, String details = ''}) {
    final scope = centerId.isEmpty ? 'مكتبة سند العامة' : 'مكتبة المركز';
    return _log(
      action: action,
      entityType: 'therapy_structure',
      entityId: entityId,
      centerId: centerId,
      details: '$scope - $details',
    );
  }

  List<SkillStepTemplate> _skillStepTemplatesForFinding(
      ClinicalFinding finding) {
    if (finding.templateId.isNotEmpty) {
      final option = assessmentOptions.firstWhere(
        (o) => o.id == finding.templateId,
        orElse: () => const AssessmentOptionTemplate(
          id: '',
          centerId: '',
          itemId: '',
          label: '',
          generatesTherapy: false,
          sortOrder: 0,
        ),
      );
      if (option.id.isNotEmpty) {
        final steps = skillStepTemplates
            .where((step) =>
                step.ownerType == 'option' && step.ownerId == option.id)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        return steps;
      }

      final trigger = speechSoundTriggers.firstWhere(
        (t) => t.id == finding.templateId,
        orElse: () => const SpeechSoundTriggerTemplate(
          id: '',
          centerId: '',
          programId: '',
          letter: '',
          errorType: '',
          position: '',
          generatesTherapy: false,
          sortOrder: 0,
        ),
      );
      if (trigger.id.isNotEmpty) {
        final steps = skillStepTemplates
            .where((step) =>
                step.ownerType == 'sound' && step.ownerId == trigger.id)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

        if (steps.isEmpty && trigger.skillStepTemplates.isNotEmpty) {
          for (var i = 0; i < trigger.skillStepTemplates.length; i++) {
            steps.add(SkillStepTemplate(
              id: '${trigger.id}_step_$i',
              centerId: '',
              ownerType: 'sound',
              ownerId: trigger.id,
              title: trigger.skillStepTemplates[i],
              sortOrder: i,
              createdAt: '',
              updatedAt: '',
            ));
          }
        }

        return steps;
      }
    }

    // Fallback: text matching for legacy findings without templateId
    final optionIds = assessmentOptions
        .where((option) =>
            option.goalTemplate == finding.goal &&
            option.therapyTemplate == finding.training &&
            option.weaknessTemplate == finding.weakness)
        .map((option) => option.id)
        .toSet();
    final matchedSoundTriggers = speechSoundTriggers
        .where((trigger) =>
            trigger.goalTemplate == finding.goal &&
            trigger.therapyTemplate == finding.training &&
            trigger.weaknessTemplate == finding.weakness)
        .toList();
    final soundIds = matchedSoundTriggers.map((t) => t.id).toSet();

    final steps = skillStepTemplates
        .where((step) =>
            (step.ownerType == 'option' && optionIds.contains(step.ownerId)) ||
            (step.ownerType == 'sound' && soundIds.contains(step.ownerId)))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    // Fall back to inline skillStepTemplates on the trigger if no separate
    // skill_step_templates entries exist.
    if (steps.isEmpty && matchedSoundTriggers.isNotEmpty) {
      final trigger = matchedSoundTriggers.first;
      for (var i = 0; i < trigger.skillStepTemplates.length; i++) {
        steps.add(SkillStepTemplate(
          id: '${trigger.id}_step_$i',
          centerId: '',
          ownerType: 'sound',
          ownerId: trigger.id,
          title: trigger.skillStepTemplates[i],
          sortOrder: i,
          createdAt: '',
          updatedAt: '',
        ));
      }
    }

    return steps;
  }

  Future<void> saveExercise(Exercise exercise) async {
    _ensure(canWriteParentArea, 'لا تملك صلاحية تعديل واجبات هذا الطالب.');
    _ensureStudentEntityAccess(exercise.studentId, exercise.centerId);
    await _repository.saveExercise(exercise);
    notifications = [
      _notificationService.homeworkCreated(
          centerId: exercise.centerId,
          studentId: exercise.studentId,
          title: exercise.title),
      ...notifications,
    ];
    await _log(
        action: 'حفظ واجب',
        entityType: 'exercise',
        entityId: exercise.id,
        centerId: exercise.centerId,
        details: '${exercise.studentId} - ${exercise.title}');
    final idx = exercises.indexWhere((e) => e.id == exercise.id);
    if (idx != -1) { exercises[idx] = exercise; } else { exercises.add(exercise); }
    notifyListeners();
  }

  Future<void> saveReward(Reward reward) async {
    _ensure(canUpdateGoalProgress, 'المكافآت يعدلها الأخصائي فقط.');
    _ensureClinicalAccess(reward.studentId, reward.centerId);
    await _repository.saveReward(reward);
    this.reward = reward;
    notifyListeners();
  }

  Future<void> saveSignResource(SignResource resource) async {
    _ensure(canWriteClinical, 'مكتبة الإشارة يعدلها الأخصائي فقط.');
    _ensure(
        resource.centerId == activeCenterId, 'لا يمكن تعديل إشارة خارج مركزك.');
    await _repository.saveSignResource(resource);
    await _log(
        action: 'حفظ إشارة',
        entityType: 'sign_resource',
        entityId: resource.id,
        centerId: resource.centerId,
        details: resource.title);
    signResources = await _repository.signResources(activeCenterId);
    notifyListeners();
  }

  Future<void> deleteSignResource(String id) async {
    _ensure(canWriteClinical, 'مكتبة الإشارة يعدلها الأخصائي فقط.');
    await _repository.deleteSignResource(id);
    await _log(
        action: 'حذف إشارة',
        entityType: 'sign_resource',
        entityId: id,
        centerId: activeCenterId);
    signResources = await _repository.signResources(activeCenterId);
    notifyListeners();
  }

  Future<void> exportBackup(String targetPath) async {
    _ensure(isOwner || isCenterManager,
        'النسخ الاحتياطي متاح لمالك النظام أو مدير المركز.');
    await _repository.exportBackup(targetPath);
  }

  Future<void> importBackup(String sourcePath) async {
    _ensure(isOwner || isCenterManager,
        'استيراد النسخ الاحتياطي متاح لمالك النظام أو مدير المركز.');
    await _repository.importBackup(sourcePath);
    await loadHome();
  }

  Future<void> _grantXp(String studentId, int value) async {
    final current = await _repository.reward(studentId);
    if (current == null) return;
    final xp = current.xp + value;
    final badges =
        current.badges.isEmpty && xp >= 50 ? 'بداية قوية' : current.badges;
    final updated = Reward(
      id: current.id,
      centerId: current.centerId,
      studentId: studentId,
      xp: xp,
      level: (xp ~/ 100) + 1,
      badges: badges,
      dailyStreak: current.dailyStreak,
    );
    await _repository.saveReward(updated);
    reward = updated;
  }

  Future<AssessmentDraft?> assessmentDraft(
      String studentId, String programId) async {
    return _repository.assessmentDraft(studentId, programId);
  }

  Future<void> saveAssessmentDraft(AssessmentDraft draft) async {
    await _repository.saveAssessmentDraft(draft);
  }

  Future<void> deleteAssessmentDraft(
      String studentId, String programId) async {
    await _repository.deleteAssessmentDraft(studentId, programId);
  }

  Future<void> printCredentials(Student student) =>
      _pdfService.printStudentCredentials(student);

  Future<void> printReport(
      String type, String specialistSignature, String managerSignature) async {
    _ensure(canViewReports, 'التقارير الرسمية يصدرها المركز فقط.');
    final student = selectedStudent;
    if (student == null) return;
    final report = ReportRecord(
      id: 'report_${DateTime.now().millisecondsSinceEpoch}',
      centerId: student.centerId,
      studentId: student.id,
      type: type,
      createdAt: DateTime.now().toIso8601String(),
      improvementRate: _improvementRate,
      specialistSignature: specialistSignature,
      managerSignature: managerSignature,
    );
    await _repository.saveReport(report);
    notifications = [
      _notificationService.reportReady(
          centerId: report.centerId, studentId: report.studentId, type: type),
      ...notifications,
    ];
    await _log(
        action: 'طباعة تقرير',
        entityType: 'report',
        entityId: report.id,
        centerId: report.centerId,
        details: '${report.studentId} - $type');
    await _pdfService.printProgressReport(
      center: currentCenter,
      student: student,
      sessions: sessions,
      evaluations: evaluations,
      plans: plans,
      reports: reports,
      type: type,
      specialistSignature: specialistSignature,
      managerSignature: managerSignature,
    );
    reports.add(report);
    notifyListeners();
  }

  Future<void> printReportForSessions({
    required String type,
    required List<TherapySession> selectedSessions,
    required String specialistSignature,
    required String managerSignature,
  }) async {
    _ensure(canViewReports, 'التقارير الرسمية يصدرها المركز فقط.');
    final student = selectedStudent;
    if (student == null) return;
    final report = ReportRecord(
      id: 'report_${DateTime.now().millisecondsSinceEpoch}',
      centerId: student.centerId,
      studentId: student.id,
      type: type,
      createdAt: DateTime.now().toIso8601String(),
      improvementRate: _sessionImprovement(selectedSessions),
      specialistSignature: specialistSignature,
      managerSignature: managerSignature,
    );
    await _repository.saveReport(report);
    await _log(
        action: 'طباعة تقرير',
        entityType: 'report',
        entityId: report.id,
        centerId: report.centerId,
        details: '${report.studentId} - $type');
    await _pdfService.printProgressReport(
      center: currentCenter,
      student: student,
      sessions: selectedSessions,
      evaluations: evaluations,
      plans: plans,
      reports: reports,
      type: type,
      specialistSignature: specialistSignature,
      managerSignature: managerSignature,
    );
    reports.add(report);
    notifyListeners();
  }

  String recommendationFor({required String errorType, required int severity}) {
    if (severity >= 4) {
      return 'يوصى بتكثيف التدريب السمعي والبصري وتقسيم الهدف إلى خطوات قصيرة.';
    }
    if (errorType == 'إبدال') {
      return 'يوصى بتمييز صوت الحرف المستهدف عن الحرف البديل داخل كلمات قصيرة.';
    }
    if (errorType == 'حذف') {
      return 'يوصى بتمارين إطالة الصوت وتثبيت موضع الحرف في الكلمة.';
    }
    if (errorType == 'تشويه') {
      return 'يوصى بتدريب موضع اللسان والشفاه أمام مرآة مع تغذية راجعة فورية.';
    }
    return 'يوصى بتكرار الهدف داخل جمل وظيفية قصيرة.';
  }

  int _sessionImprovement(List<TherapySession> selectedSessions) {
    if (selectedSessions.isEmpty) return _improvementRate;
    final total = selectedSessions.fold<int>(
        0, (sum, session) => sum + session.successRate);
    return (total / selectedSessions.length).round();
  }

  int get _improvementRate {
    if (evaluations.isEmpty) return 0;
    final good = evaluations
        .where((item) => item.score == 'صحيح' || item.score == 'ناجح')
        .length;
    final partial = evaluations.where((item) => item.score == 'جزئي').length;
    return (((good + partial * .5) / evaluations.length) * 100).round();
  }

  /// Returns current quarter (Q1-Q4) for a given date.
  static String quarterForDate(DateTime date) {
    final m = date.month;
    if (m <= 3) return 'Q1';
    if (m <= 6) return 'Q2';
    if (m <= 9) return 'Q3';
    return 'Q4';
  }

  /// Quarter start date for a given quarter and year.
  static DateTime quarterStart(String quarter, int year) {
    switch (quarter) {
      case 'Q1': return DateTime(year, 1, 1);
      case 'Q2': return DateTime(year, 4, 1);
      case 'Q3': return DateTime(year, 7, 1);
      case 'Q4': return DateTime(year, 10, 1);
      default: return DateTime(year, 1, 1);
    }
  }

  /// Quarter end date for a given quarter and year.
  static DateTime quarterEnd(String quarter, int year) {
    switch (quarter) {
      case 'Q1': return DateTime(year, 3, 31);
      case 'Q2': return DateTime(year, 6, 30);
      case 'Q3': return DateTime(year, 9, 30);
      case 'Q4': return DateTime(year, 12, 31);
      default: return DateTime(year, 12, 31);
    }
  }

  /// Find the most recent previous specialist report for the same
  /// (studentId, programId?, specialistId) combination.
  ReportRecord? findPreviousSpecialistReport({
    required String studentId,
    String? programId,
    String? specialistId,
    String? scope,
  }) {
    final matching = reports.where((r) {
      if (r.studentId != studentId) return false;
      if (r.reportCategory != 'specialistInitial' &&
          r.reportCategory != 'specialistFollowup') return false;
      if (programId != null && r.programId != programId) return false;
      if (specialistId != null && r.specialistId != specialistId) return false;
      return true;
    }).toList();
    matching.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return matching.isNotEmpty ? matching.first : null;
  }

  /// Find the logically previous quarterly report for the same
  /// (studentId, scope, programId).
  /// Q1 → looks for Q4 of previous year.
  /// Q2 → looks for Q1 of same year.
  /// Q3 → looks for Q2 of same year.
  /// Q4 → looks for Q3 of same year.
  ReportRecord? findPreviousQuarterlyReport({
    required String studentId,
    required String scope,
    String? programId,
    String? quarter,
    String? year,
  }) {
    if (quarter == null || year == null) return null;

    String prevQuarter;
    int prevYear;
    switch (quarter) {
      case 'Q1':
        prevQuarter = 'Q4';
        prevYear = int.tryParse(year) ?? DateTime.now().year;
        prevYear--;
        break;
      case 'Q2':
        prevQuarter = 'Q1';
        prevYear = int.tryParse(year) ?? DateTime.now().year;
        break;
      case 'Q3':
        prevQuarter = 'Q2';
        prevYear = int.tryParse(year) ?? DateTime.now().year;
        break;
      case 'Q4':
        prevQuarter = 'Q3';
        prevYear = int.tryParse(year) ?? DateTime.now().year;
        break;
      default:
        return null;
    }

    final matching = reports.where((r) {
      if (r.studentId != studentId) return false;
      if (r.reportCategory != 'supervisorQuarterly') return false;
      if (r.scope != scope) return false;
      if (programId != null && r.programId != programId) return false;
      if (r.quarter == prevQuarter && r.year == prevYear.toString()) return true;
      return false;
    }).toList();
    matching.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return matching.isNotEmpty ? matching.first : null;
  }

  /// Build full snapshot JSON from ReportData for later comparison.
  String buildSnapshotJson(ReportData data, {String reportCategory = 'general'}) {
    return jsonEncode({
      'studentId': data.student.id,
      'studentName': data.student.name,
      'generatedAt': DateTime.now().toIso8601String(),
      'reportCategory': reportCategory,
      'dateFrom': data.dateFrom,
      'dateTo': data.dateTo,
      'totalSessions': data.totalSessions,
      'totalPlans': data.totalPlans,
      'totalMasteredGoals': data.totalMasteredGoals,
      'totalActiveGoals': data.totalActiveGoals,
      'overallImprovementRate': data.overallImprovementRate,
      'sections': data.sections.map((s) => {
        'programId': s.programId,
        'programName': s.programName,
        'specialistId': s.specialistId,
        'specialistName': s.specialistName,
        'overallProgress': s.overallProgress,
        'masteredGoals': s.masteredGoals,
        'activeGoals': s.activeGoals,
        'plans': s.plans.map((p) => {
          'id': p.id,
          'goal': p.goal,
          'sourceType': p.sourceType,
          'progress': _goalProgressFromSectionData(s, p.id),
        }).toList(),
        'sessions': s.sessions.map((sess) => {
          'id': sess.id,
          'startedAt': sess.startedAt,
          'quickResult': sess.quickResult,
          'planId': sess.planId,
          'successRate': sess.successRate,
        }).toList(),
        'assessments': s.assessments.map((a) => {
          'id': a.id,
          'specialistName': a.specialistName,
          'createdAt': a.createdAt,
        }).toList(),
        'findings': s.findings.map((f) => {
          'itemTitle': f.itemTitle,
          'result': f.result,
          'isNormal': f.isNormal,
        }).toList(),
        'goalSkillSteps': s.goalSkillSteps.map((g) => {
          'id': g.id,
          'goalId': g.goalId,
          'title': g.title,
          'status': g.status,
        }).toList(),
      }).toList(),
    });
  }

  int _goalProgressFromSectionData(ProgramReportSection section, String planId) {
    final steps = section.goalSkillSteps.where((s) => s.goalId == planId).toList();
    if (steps.isEmpty) {
      final matches = section.sessions
          .where((s) => s.planId == planId)
          .toList()
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
      if (matches.isEmpty) return 0;
      switch (matches.first.quickResult) {
        case 'متقن': return 100;
        case 'بمساعدة': return 50;
        default: return 0;
      }
    }
    final completed = steps.where((s) => s.status == 'متقن').length;
    return ((completed / steps.length) * 100).round();
  }

  /// Check if the student has enough therapy data to generate a report.
  /// For all roles: looks for ANY therapy data (assessments, findings, plans,
  /// sessions, followups, exercises) within the relevant program scope.
  /// Returns an error message string if no data found, or null if OK.
  String? validateStudentHasAssessment({
    required String studentId,
    required String scope,
    String? programId,
    String? specialistId,
  }) {
    bool hasData = false;

    if (scope == 'singleProgram' && programId != null) {
      hasData = studentHasTherapyData(studentId, programId: programId);
    } else if (scope == 'specialistPrograms' && specialistId != null) {
      final assignedIds = studentProgramAssignments
          .where((a) =>
              a.specialistId == specialistId &&
              a.studentId == studentId &&
              a.isActive &&
              a.centerId == activeCenterId)
          .map((a) => a.programId)
          .toSet();
      for (final pid in assignedIds) {
        if (studentHasTherapyData(studentId, programId: pid)) {
          hasData = true;
          break;
        }
      }
    } else {
      hasData = studentHasTherapyData(studentId);
    }

    if (!hasData) {
      return 'لا توجد بيانات علاجية كافية لهذا الطالب بعد. يرجى إجراء تقييم أولي أو تسجيل بيانات علاجية أولًا.';
    }
    return null;
  }

  Future<({
    ReportData data,
    ReportRecord record,
    ReportComparisonResult? comparison,
  })> buildSmartReportData({
    required String studentId,
    required String type,
    required String scope,
    String? programId,
    String? specialistId,
    String? dateFrom,
    String? dateTo,
    String specialistSignature = '',
    String managerSignature = '',
    String reportCategory = 'general',
    String? previousReportId,
    String? quarter,
    String? year,
  }) async {
    _ensure(canViewReports, 'التقارير الرسمية يصدرها المركز فقط.');

    // Validate assessment exists
    final assessmentError = validateStudentHasAssessment(
      studentId: studentId,
      scope: scope,
      programId: programId,
      specialistId: specialistId,
    );
    if (assessmentError != null) {
      throw StateError(assessmentError);
    }

    final student = students.where((s) => s.id == studentId).firstOrNull;
    if (student == null) {
      throw StateError('الطالب غير موجود.');
    }

    final builder = ReportDataBuilder(app: this);
    final data = builder.build(
      studentId: studentId,
      type: type,
      scope: scope,
      programId: programId,
      specialistId: specialistId,
      dateFrom: dateFrom,
      dateTo: dateTo,
      createdByUserId: user?.id ?? '',
      createdByName: user?.name ?? '',
    );

    final now = DateTime.now();
    final reportId = 'report_${now.millisecondsSinceEpoch}';

    // Build full snapshot
    final snapshotJson = buildSnapshotJson(data, reportCategory: reportCategory);

    // Build data summary (kept for backward compat)
    final dataSummary = jsonEncode({
      'programCount': data.sections.length,
      'sessionsCount': data.totalSessions,
      'plansCount': data.totalPlans,
      'masteredGoals': data.totalMasteredGoals,
      'activeGoals': data.totalActiveGoals,
      'sections': data.sections.map((s) => {
        'programId': s.programId,
        'programName': s.programName,
        'specialistId': s.specialistId,
        'specialistName': s.specialistName,
        'plansCount': s.plans.length,
        'sessionsCount': s.sessions.length,
        'progress': s.overallProgress,
        'masteredGoals': s.masteredGoals,
        'activeGoals': s.activeGoals,
      }).toList(),
    });

    // Compute comparison if previous report exists
    ReportComparisonResult? comparison;
    if (previousReportId != null) {
      final prevReport = reports.where((r) => r.id == previousReportId).firstOrNull;
      if (prevReport != null && prevReport.snapshotJson.isNotEmpty) {
        final prevSnapshot = ReportComparisonService.parseSnapshot(prevReport.snapshotJson);
        comparison = ReportComparisonService.compare(
          previousSnapshot: prevSnapshot,
          currentData: data,
        );
      }
    }

    final report = ReportRecord(
      id: reportId,
      centerId: student.centerId,
      studentId: student.id,
      programId: programId,
      specialistId: specialistId,
      createdByUserId: user?.id ?? '',
      type: type,
      reportTitle: data.type,
      createdAt: now.toIso8601String(),
      improvementRate: data.overallImprovementRate,
      specialistSignature: specialistSignature,
      managerSignature: managerSignature,
      scope: scope,
      dateFrom: dateFrom ?? '',
      dateTo: dateTo ?? '',
      reportStatus: 'exported',
      dataJson: dataSummary,
      reportCategory: reportCategory,
      previousReportId: previousReportId,
      quarter: quarter,
      year: year,
      snapshotJson: snapshotJson,
    );

    return (data: data, record: report, comparison: comparison);
  }

  Future<void> saveReportRecord(ReportRecord report) async {
    await _repository.saveReport(report);
    await _log(
      action: 'إنشاء تقرير ذكي',
      entityType: 'report',
      entityId: report.id,
      centerId: report.centerId,
      details: '${report.studentId} - ${report.type} - ${report.scope}',
    );
    reports.add(report);
    notifyListeners();
  }

  AppUser _requireUser() {
    final current = user;
    if (current == null) {
      throw StateError('يجب تسجيل الدخول أولًا.');
    }
    return current;
  }

  void _ensure(bool allowed, String message) {
    if (!allowed) throw StateError(message);
  }

  void _ensureClinicalAccess(String studentId, String centerId) {
    _ensure(centerId == activeCenterId, 'لا يمكن تنفيذ العملية خارج مركزك.');
    _ensureStudentEntityAccess(studentId, centerId);
  }

  void _ensureStudentEntityAccess(String studentId, String centerId) {
    Student? student;
    for (final item in students) {
      if (item.id == studentId) {
        student = item;
        break;
      }
    }
    if (student != null) _ensureStudentAccess(student);
    if (!isOwner && !isParent) {
      _ensure(centerId == activeCenterId, 'لا يمكن الوصول لبيانات مركز آخر.');
    }
    if (isParent) {
      final allowed = user?.studentId == studentId ||
          students.any((item) => item.id == studentId);
      _ensure(allowed, 'ولي الأمر يرى بيانات أطفاله فقط.');
    }
  }

  void _ensureStudentAccess(Student student) {
    final current = _requireUser();
    if (current.role == UserRole.sanadOwner && !isSupportMode) return;
    if (isSupportMode && student.centerId == activeCenterId) return;
    if (current.role == UserRole.parent &&
        (current.studentId == student.id ||
            students.any((item) => item.id == student.id))) {
      return;
    }
    if ((current.role == UserRole.centerManager ||
            current.role == UserRole.clinicalSupervisor ||
            current.role == UserRole.specialist ||
            current.role == UserRole.dataEntry ||
            current.role == UserRole.therapyProgramEntry ||
            current.role == UserRole.coordinator) &&
        current.centerId == student.centerId) {
      return;
    }
    throw StateError('لا تملك صلاحية الوصول لهذا الطالب.');
  }

  Future<void> _log({
    required String action,
    required String entityType,
    required String entityId,
    String centerId = '',
    String details = '',
  }) async {
    final current = user;
    if (current == null) return;
    await _repository.saveAuditLog(
      AuditLog(
        id: 'audit_${DateTime.now().microsecondsSinceEpoch}',
        centerId: centerId,
        userId: current.id,
        userName: current.name,
        action: action,
        entityType: entityType,
        entityId: entityId,
        details: details,
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
  }

  String _cleanError(Object error) {
    final message = error
        .toString()
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Exception: ', '');
    if (message.contains('DatabaseException') ||
        message.contains('DatabaseError')) {
      return 'حدث خطأ في قاعدة البيانات. يرجى المحاولة مرة أخرى.';
    }
    return message;
  }
}
