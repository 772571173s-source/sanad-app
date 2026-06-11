import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../models/assessment_improvement_summary.dart';
import '../repositories/sanad_repository.dart';
import '../services/notification_service.dart';
import '../services/pdf_service.dart';

class AppProvider extends ChangeNotifier {
  AppProvider(this._repository, this._pdfService);

  final SanadRepository _repository;
  final PdfService _pdfService;
  final NotificationService _notificationService = const NotificationService();

  AppUser? user;
  SanadCenter? currentCenter;
  SanadCenter? supportModeCenter;
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
  List<StudentSpecialist> studentSpecialists = [];
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

  bool get isSanadOwnerAccount => user?.role == UserRole.sanadOwner;
  bool get isSupportMode => isSanadOwnerAccount && supportModeCenter != null;
  bool get isOwner => isSanadOwnerAccount && !isSupportMode;
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
    studentSpecialists = [];
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
        studentSpecialists = await _repository.studentSpecialists();
      }
      if (isSpecialist) {
        final myStudentIds = studentSpecialists
            .where((s) => s.specialistId == current.id && s.isActive)
            .map((s) => s.studentId)
            .toSet();
        students = students.where((s) => myStudentIds.contains(s.id)).toList();
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

  Future<void> assignStudentToSpecialist(
      String studentId, String specialistId) async {
    await _repository.saveStudentSpecialist(StudentSpecialist(
      id: 'ss_${studentId}_$specialistId',
      studentId: studentId,
      specialistId: specialistId,
      assignedByUserId: user?.id ?? '',
      assignedAt: DateTime.now().toIso8601String(),
      isActive: true,
    ));
    studentSpecialists = await _repository.studentSpecialists();
    notifyListeners();
  }

  Future<void> unassignStudentFromSpecialist(
      String studentId, String specialistId) async {
    await _repository.deactivateStudentSpecialist(studentId, specialistId);
    studentSpecialists = await _repository.studentSpecialists();
    notifyListeners();
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
