import 'package:flutter/material.dart';

import '../models/app_models.dart';
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
  List<ClinicalAssessment> clinicalAssessments = [];
  Map<String, List<ClinicalFinding>> clinicalFindingsByAssessment = {};
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
  Reward? reward;
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
    reports = [];
    clinicalAssessments = [];
    clinicalFindingsByAssessment = {};
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
    notifications = [];
    reward = null;
    notifyListeners();
  }

  void toggleTheme() {
    darkMode = !darkMode;
    notifyListeners();
  }

  Future<void> loadHome() async {
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
    staff = canManageStaff
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
    await _loadCenterMetrics();
    final currentSelection = selectedStudent;
    selectedStudent = currentSelection != null &&
            students.any((student) => student.id == currentSelection.id)
        ? currentSelection
        : null;
    await selectStudent(selectedStudent);
  }

  Future<void> _loadTherapyStructure() async {
    if (!isGlobalTherapyStructureMode && activeCenterId.isEmpty) {
      assessmentSections = [];
      assessmentItems = [];
      assessmentOptions = [];
      skillStepTemplates = [];
      speechSoundTriggers = [];
      return;
    }
    final scopeCenterId = isGlobalTherapyStructureMode ? '' : activeCenterId;
    assessmentSections =
        await _repository.assessmentSectionTemplates(scopeCenterId);
    assessmentItems = await _repository.assessmentItemTemplates(scopeCenterId);
    assessmentOptions =
        await _repository.assessmentOptionTemplates(scopeCenterId);
    skillStepTemplates = await _repository.skillStepTemplates(scopeCenterId);
    speechSoundTriggers =
        await _repository.speechSoundTriggerTemplates(scopeCenterId);
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
    if (student != null) _ensureStudentAccess(student);
    selectedStudent = student;
    if (student == null) {
      sessions = [];
      evaluations = [];
      plans = [];
      goalSkillSteps = [];
      exercises = [];
      reports = [];
      clinicalAssessments = [];
      clinicalFindingsByAssessment = {};
      auditLogs = isOwner || isCenterManager
          ? await _repository.auditLogs(
              centerId: isOwner ? null : activeCenterId)
          : [];
      reward = null;
    } else {
      sessions = await _repository.sessions(student.id);
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
    }
    notifyListeners();
  }

  Future<void> _loadCenterMetrics() async {
    centerSessions = [];
    centerEvaluations = [];
    centerExercises = [];
    for (final student in students) {
      centerSessions.addAll(await _repository.sessions(student.id));
      centerEvaluations.addAll(await _repository.evaluations(student.id));
      centerExercises.addAll(await _repository.exercises(student.id));
    }
  }

  Future<void> _loadCenterCardsMetrics() async {
    centerStudentCounts = {};
    centerSpecialistCounts = {};
    centerSessionCounts = {};
    centerLastActivities = {};
    if (!isOwner) return;
    for (final center in centers) {
      centerStudentCounts[center.id] =
          await _repository.centerStudentCount(center.id);
      centerSpecialistCounts[center.id] =
          await _repository.centerSpecialistCount(center.id);
      centerSessionCounts[center.id] =
          await _repository.centerSessionCount(center.id);
      centerLastActivities[center.id] =
          await _repository.centerLastActivity(center.id);
    }
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
    await loadHome();
  }

  Future<void> deleteCenter(String id) async {
    _ensure(canManageCenters, 'حذف المراكز خاص بمالك النظام فقط.');
    await _repository.deleteCenter(id);
    if (currentCenter?.id == id) currentCenter = null;
    await _log(
        action: 'حذف مركز', entityType: 'center', entityId: id, centerId: id);
    await loadHome();
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
    await loadHome();
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
    await loadHome();
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
    await loadHome();
  }

  Future<void> deleteStaffUser(AppUser account) async {
    _ensure(canManageStaff, 'إدارة الموظفين غير متاحة لهذا الحساب.');
    if (!isOwner && account.centerId != activeCenterId) {
      throw StateError('لا يمكن حذف موظف خارج مركزك.');
    }
    await _repository.deleteUser(account.id);
    await loadHome();
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
    await loadHome();
    final saved = students.firstWhere((item) => item.id == student.id,
        orElse: () => centerStudent);
    selectedStudent = saved;
    notifyListeners();
    return saved;
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
    await loadHome();
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
          session.quickResult == 'صحيح' ||
                  session.quickResult == 'ناجح' ||
                  session.quickResult == 'أتقن' ||
                  session.quickResult == 'يؤدي جيدًا'
              ? 12
              : 6);
    }
    await selectStudent(selectedStudent);
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
    await _grantXp(evaluation.studentId,
        evaluation.score == 'صحيح' || evaluation.score == 'ناجح' ? 8 : 4);
    await selectStudent(selectedStudent);
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
    await selectStudent(selectedStudent);
  }

  List<GoalSkillStep> stepsForGoal(String goalId) =>
      goalSkillSteps.where((step) => step.goalId == goalId).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  int goalProgress(String goalId) {
    final steps = stepsForGoal(goalId);
    if (steps.isEmpty) {
      final matches = plans.where((item) => item.id == goalId).toList();
      return matches.isEmpty ? 0 : matches.first.progress;
    }
    final completed = steps.where((step) => step.status == 'متقن').length;
    return ((completed / steps.length) * 100).round();
  }

  String goalStatus(String goalId) {
    final progress = goalProgress(goalId);
    if (progress >= 100) return 'مكتمل';
    if (progress >= 70) return 'متحسن';
    if (progress > 0) return 'قيد التدريب';
    final hasStarted = stepsForGoal(goalId)
        .any((step) => step.status != 'لم يبدأ' && step.status.isNotEmpty);
    return hasStarted ? 'يحتاج متابعة' : 'جديد';
  }

  Future<void> saveGoalSkillStep(GoalSkillStep step) async {
    _ensure(canUpdateGoalProgress, 'تتبع الأهداف يحدّثه الأخصائي فقط.');
    _ensureClinicalAccess(step.studentId, step.centerId);
    await _repository.saveGoalSkillStep(step);
    await _syncGoalProgress(step.goalId);
    await selectStudent(selectedStudent);
  }

  Future<void> updateGoalSkillStepStatus({
    required GoalSkillStep step,
    required String status,
    required String notes,
    String lastSessionId = '',
  }) async {
    _ensure(canUpdateGoalProgress, 'تتبع الأهداف يحدّثه الأخصائي فقط.');
    _ensureClinicalAccess(step.studentId, step.centerId);
    await _repository.saveGoalSkillStep(step.copyWith(
      status: status,
      notes: notes,
      lastSessionId: lastSessionId.isEmpty ? step.lastSessionId : lastSessionId,
      updatedAt: DateTime.now().toIso8601String(),
    ));
    await _syncGoalProgress(step.goalId);
  }

  Future<void> _syncGoalProgress(String goalId) async {
    final goalSteps = await _repository.goalStepsForGoal(goalId);
    final matches = plans.where((plan) => plan.id == goalId).toList();
    if (matches.isEmpty || goalSteps.isEmpty) return;
    final plan = matches.first;
    final completed = goalSteps.where((step) => step.status == 'متقن').length;
    final progress = ((completed / goalSteps.length) * 100).round();
    await _repository.savePlan(TrainingPlan(
      id: plan.id,
      centerId: plan.centerId,
      studentId: plan.studentId,
      goal: plan.goal,
      targetDate: plan.targetDate,
      progress: progress,
      createdAt: plan.createdAt,
      updatedAt: DateTime.now().toIso8601String(),
    ));
  }

  Future<void> saveClinicalAssessment({
    required ClinicalAssessment assessment,
    required List<ClinicalFinding> findings,
  }) async {
    _ensure(canWriteClinical, 'التقييم العلاجي يضيفه الأخصائي فقط.');
    _ensureClinicalAccess(assessment.studentId, assessment.centerId);
    await _repository.saveClinicalAssessment(assessment);
    for (final finding in findings) {
      await _repository.saveClinicalFinding(finding);
      if (!finding.isNormal && finding.goal.trim().isNotEmpty) {
        final planId = 'plan_${finding.id}';
        final now = DateTime.now().toIso8601String();
        await _repository.savePlan(
          TrainingPlan(
            id: planId,
            centerId: finding.centerId,
            studentId: finding.studentId,
            goal: finding.goal,
            targetDate: DateTime.now()
                .add(const Duration(days: 45))
                .toIso8601String()
                .split('T')
                .first,
            progress: 0,
            createdAt: now,
            updatedAt: now,
          ),
        );
        final training =
            finding.training.trim().isEmpty ? finding.goal : finding.training;
        final templateSteps = _skillStepTemplatesForFinding(finding);
        final stepTitles = templateSteps.isEmpty
            ? [
                'يشاهد الأخصائي ينفذ التدريب: $training',
                'ينفذ التدريب بمساعدة: $training',
                'ينفذ التدريب باستقلالية: $training',
              ]
            : templateSteps.map((step) => step.title).toList();
        for (var index = 0; index < stepTitles.length; index++) {
          await _repository.saveGoalSkillStep(GoalSkillStep(
            id: 'step_${finding.id}_${index + 1}',
            centerId: finding.centerId,
            studentId: finding.studentId,
            goalId: planId,
            title: stepTitles[index],
            sortOrder: index,
            createdAt: now,
            updatedAt: now,
          ));
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
    await selectStudent(selectedStudent);
  }

  Future<void> saveAssessmentSectionTemplate(
      AssessmentSectionTemplate section) async {
    _ensure(canManageTherapyStructure,
        'بناء الهيكل العلاجي متاح لمدخل البرامج أو مدير المركز فقط.');
    final writeCenterId = therapyStructureWriteCenterId;
    final normalized = AssessmentSectionTemplate(
      id: section.id,
      centerId: writeCenterId,
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
      letter: trigger.letter,
      errorType: trigger.errorType,
      position: trigger.position,
      generatesTherapy: trigger.generatesTherapy,
      weaknessTemplate: trigger.weaknessTemplate,
      goalTemplate: trigger.goalTemplate,
      therapyTemplate: trigger.therapyTemplate,
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
    final optionIds = assessmentOptions
        .where((option) =>
            option.goalTemplate == finding.goal &&
            option.therapyTemplate == finding.training &&
            option.weaknessTemplate == finding.weakness)
        .map((option) => option.id)
        .toSet();
    final soundIds = speechSoundTriggers
        .where((trigger) =>
            trigger.goalTemplate == finding.goal &&
            trigger.therapyTemplate == finding.training &&
            trigger.weaknessTemplate == finding.weakness)
        .map((trigger) => trigger.id)
        .toSet();
    final steps = skillStepTemplates
        .where((step) =>
            (step.ownerType == 'option' && optionIds.contains(step.ownerId)) ||
            (step.ownerType == 'sound' && soundIds.contains(step.ownerId)))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
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
    await selectStudent(selectedStudent);
  }

  Future<void> saveReward(Reward reward) async {
    _ensure(canUpdateGoalProgress, 'المكافآت يعدلها الأخصائي فقط.');
    _ensureClinicalAccess(reward.studentId, reward.centerId);
    await _repository.saveReward(reward);
    await selectStudent(selectedStudent);
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
    await _repository.saveReward(
      Reward(
        id: current.id,
        centerId: current.centerId,
        studentId: studentId,
        xp: xp,
        level: (xp ~/ 100) + 1,
        badges: badges,
        dailyStreak: current.dailyStreak,
      ),
    );
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
    await selectStudent(student);
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
    await selectStudent(student);
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

  String _cleanError(Object error) => error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Exception: ', '');
}
