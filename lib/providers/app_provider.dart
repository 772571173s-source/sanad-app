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
  bool get isSpecialist => user?.role == UserRole.specialist;
  bool get isDataEntry => user?.role == UserRole.dataEntry;
  bool get isProgramEntry => user?.role == UserRole.programEntry;
  bool get isParent => user?.role == UserRole.parent;
  bool get canManageCenters => isOwner;
  bool get canManageStaff => isOwner || isCenterManager;
  bool get canViewStudents =>
      isCenterManager || isSpecialist || isDataEntry || isParent;
  bool get canManageStudents => isCenterManager || isDataEntry;
  bool get canDeleteStudents => isCenterManager;
  bool get canWriteClinical => isSpecialist;
  bool get canWriteParentArea => isParent || canWriteClinical;
  bool get canViewReports => isCenterManager || isSpecialist;
  String get activeCenterId => currentCenter?.id ?? user?.centerId ?? '';

  int get completedHomeworkCount =>
      centerExercises.where((item) => item.status == 'ظ…ظƒطھظ…ظ„').length;

  String get hardestLetter {
    final counts = <String, int>{};
    for (final evaluation in centerEvaluations
        .where((item) => item.score == 'ط®ط·ط£' || item.severity >= 4)) {
      counts[evaluation.letter] = (counts[evaluation.letter] ?? 0) + 1;
    }
    if (counts.isEmpty) return '-';
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return '${sorted.first.key} (${sorted.first.value})';
  }

  String get mostUsedSign {
    final counts = <String, int>{};
    for (final session in centerSessions
        .where((item) => item.sessionType == 'ظ„ط؛ط© ط¥ط´ط§ط±ط©')) {
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
            title: 'ط¨ط§ط¨',
            letter: 'ط¨',
            position: 'ط£ظˆظ„ ط§ظ„ظƒظ„ظ…ط©',
            level: 'ظ…ط¨طھط¯ط¦',
            category: 'ظƒظ„ظ…ط§طھ'),
        TrainingItem(
            id: 's2',
            type: 'word',
            title: 'ظƒظˆط¨',
            letter: 'ط¨',
            position: 'ط¢ط®ط± ط§ظ„ظƒظ„ظ…ط©',
            level: 'ظ…ط¨طھط¯ط¦',
            category: 'ظƒظ„ظ…ط§طھ'),
        TrainingItem(
            id: 's3',
            type: 'sentence',
            title: 'ط¨ط§ط¨ ط§ظ„ط¨ظٹطھ ظ…ظپطھظˆط­',
            letter: 'ط¨',
            position: 'ط£ظˆظ„ ط§ظ„ظƒظ„ظ…ط©',
            level: 'ظ…طھظˆط³ط·',
            category: 'ط¬ظ…ظ„'),
        TrainingItem(
            id: 's4',
            type: 'word',
            title: 'ط³ظ…ظƒ',
            letter: 'ط³',
            position: 'ط£ظˆظ„ ط§ظ„ظƒظ„ظ…ط©',
            level: 'ظ…ط¨طھط¯ط¦',
            category: 'ظƒظ„ظ…ط§طھ'),
        TrainingItem(
            id: 's5',
            type: 'sentence',
            title: 'ط³ط§ظ…ظٹ ظٹط³ظ…ط¹ ط§ظ„طµظˆطھ',
            letter: 'ط³',
            position: 'ظˆط³ط· ط§ظ„ظƒظ„ظ…ط©',
            level: 'ظ…طھظˆط³ط·',
            category: 'ط¬ظ…ظ„'),
      ];

  String get smartSessionSuggestion {
    if (evaluations.isEmpty && sessions.isEmpty) {
      return 'ط§ط¨ط¯ط£ ط¨ظ‡ط¯ظپ ظ‚طµظٹط± ظ…ظ† ط§ظ„ط®ط·ط© ط§ظ„ط­ط§ظ„ظٹط© ط«ظ… ظ‚ظٹظ‘ظ… 5 ظ…ط­ط§ظˆظ„ط§طھ.';
    }
    final weakEvaluation = evaluations
        .where((item) => item.score == 'ط®ط·ط£' || item.severity >= 4)
        .toList();
    if (weakEvaluation.isNotEmpty) {
      final item = weakEvaluation.first;
      return 'ط§ظ‚طھط±ط­ طھط¯ط±ظٹط¨ ط­ط±ظپ ${item.letter} ظپظٹ ظ…ظˆط¶ط¹ ${item.position} ط¨ط³ط¨ط¨ طھظƒط±ط§ط± ${item.errorType}.';
    }
    final lastSession = sessions.isEmpty ? null : sessions.first;
    if (lastSession != null && lastSession.successRate >= 85) {
      return 'ط§ظ„ط£ط¯ط§ط، ظ…ظ…طھط§ط²ط› ط¬ط±ظ‘ط¨ ظ…ط³طھظˆظ‰ ط£طµط¹ط¨ ظˆط²ط¯ ظ†ظ‚ط§ط· XP ط¹ظ†ط¯ ط§ظ„ط¥طھظ‚ط§ظ†.';
    }
    if (lastSession != null &&
        lastSession.letterPosition == 'ط¢ط®ط± ط§ظ„ظƒظ„ظ…ط©' &&
        lastSession.quickResult == 'ط®ط·ط£') {
      return 'ط±ظƒظ‘ط² ط¹ظ„ظ‰ طھط¯ط±ظٹط¨ط§طھ ط¢ط®ط± ط§ظ„ظƒظ„ظ…ط© ظپظٹ ط§ظ„ط¬ظ„ط³ط© ط§ظ„ظ‚ط§ط¯ظ…ط©.';
    }
    return 'ط§ط³طھظ…ط± ط¹ظ„ظ‰ ظ‡ط¯ظپ ط§ظ„ط®ط·ط© ط§ظ„ط­ط§ظ„ظٹ ظ…ط¹ طھظ‚ظ„ظٹظ„ ط§ظ„ظ…ط³ط§ط¹ط¯ط© طھط¯ط±ظٹط¬ظٹظ‹ط§.';
  }

  bool get signLanguageEnabledForSelectedStudent {
    final student = selectedStudent;
    if (student == null) return true;
    return student.programType.contains('ط³ظ…ط¹') ||
        student.programType.contains('ط¥ط´ط§ط±ط©') ||
        plans.any((plan) => plan.goal.contains('ط¥ط´ط§ط±ط©'));
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
      throw StateError('ط£ظƒظ…ظ„ ط¨ظٹط§ظ†ط§طھ ظ…ط§ظ„ظƒ ط§ظ„ظ†ط¸ط§ظ….');
    }
    if (password.length < 8) {
      throw StateError(
          'ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط± ظٹط¬ط¨ ط£ظ„ط§ طھظ‚ظ„ ط¹ظ† 8 ط£ط­ط±ظپ.');
    }
    if (password != confirmPassword) {
      throw StateError('ظƒظ„ظ…طھط§ ط§ظ„ظ…ط±ظˆط± ط؛ظٹط± ظ…طھط·ط§ط¨ظ‚طھظٹظ†.');
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
      throw StateError(
          'ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط± ظٹط¬ط¨ ط£ظ„ط§ طھظ‚ظ„ ط¹ظ† 6 ط£ط­ط±ظپ.');
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
    auditLogs = isOwner || isCenterManager
        ? await _repository.auditLogs(centerId: isOwner ? null : activeCenterId)
        : [];
    students = current.role == UserRole.parent && current.studentId != null
        ? await _repository.studentsForParent(current.studentId!, current.email)
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

  Future<void> enterSupportMode(SanadCenter center) async {
    _ensure(isSanadOwnerAccount,
        'ظˆط¶ط¹ ط§ظ„ظ…ط³ط§ط¹ط¯ط© ط®ط§طµ ط¨ظ…ط§ظ„ظƒ ط³ظ†ط¯ ظپظ‚ط·.');
    supportModeCenter = center;
    currentCenter = center;
    selectedStudent = null;
    await _log(
      action: 'ط¯ط®ظ„ ظ…ط§ظ„ظƒ ط³ظ†ط¯ ظˆط¶ط¹ ظ…ط³ط§ط¹ط¯ط© ظ…ط±ظƒط²',
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
      action: 'ط®ط±ط¬ ظ…ط§ظ„ظƒ ط³ظ†ط¯ ظ…ظ† ظˆط¶ط¹ ظ…ط³ط§ط¹ط¯ط© ظ…ط±ظƒط²',
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
    _ensure(canManageCenters,
        'ط¥ط¯ط§ط±ط© ط§ظ„ظ…ط±ط§ظƒط² ط®ط§طµط© ط¨ظ…ط§ظ„ظƒ ط§ظ„ظ†ط¸ط§ظ… ظپظ‚ط·.');
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
        'ظ„ط§ طھظ…ظ„ظƒ طµظ„ط§ط­ظٹط© طھط¹ط¯ظٹظ„ ظ‡ط°ط§ ط§ظ„ظ…ط±ظƒط².');
    await _repository.saveCenter(center);
    await _log(
        action: 'ط­ظپط¸ ظ…ط±ظƒط²',
        entityType: 'center',
        entityId: center.id,
        centerId: center.id,
        details: center.name);
    await loadHome();
  }

  Future<void> deleteCenter(String id) async {
    _ensure(canManageCenters,
        'ط­ط°ظپ ط§ظ„ظ…ط±ط§ظƒط² ط®ط§طµ ط¨ظ…ط§ظ„ظƒ ط§ظ„ظ†ط¸ط§ظ… ظپظ‚ط·.');
    await _repository.deleteCenter(id);
    if (currentCenter?.id == id) currentCenter = null;
    await _log(
        action: 'ط­ط°ظپ ظ…ط±ظƒط²',
        entityType: 'center',
        entityId: id,
        centerId: id);
    await loadHome();
  }

  Future<void> saveStaffUser(AppUser account) async {
    _ensure(canManageStaff,
        'ط¥ط¯ط§ط±ط© ط§ظ„ظ…ظˆط¸ظپظٹظ† ط؛ظٹط± ظ…طھط§ط­ط© ظ„ظ‡ط°ط§ ط§ظ„ط­ط³ط§ط¨.');
    if (!isOwner && account.centerId != activeCenterId) {
      throw StateError(
          'ظ„ط§ ظٹظ…ظƒظ† ط¥ظ†ط´ط§ط، ظ…ظˆط¸ظپ ط®ط§ط±ط¬ ظ…ط±ظƒط²ظƒ.');
    }
    if (!isOwner && account.role == UserRole.sanadOwner) {
      throw StateError(
          'ظ…ط§ظ„ظƒ ط§ظ„ظ†ط¸ط§ظ… ظ„ط§ ظٹظ†ط´ط£ ط¥ظ„ط§ ظ…ظ† ظ…ط§ظ„ظƒ ط§ظ„ظ†ط¸ط§ظ….');
    }
    if (isOwner && account.role != UserRole.centerManager) {
      throw StateError(
          'ظ…ط§ظ„ظƒ ط§ظ„ظ†ط¸ط§ظ… ظٹظ†ط´ط¦ ظ…ط¯ظٹط± ظ…ط±ظƒط² ظپظ‚ط·.');
    }
    if (isCenterManager &&
        account.role != UserRole.specialist &&
        account.role != UserRole.dataEntry &&
        account.role != UserRole.programEntry) {
      throw StateError(
          'ظ…ط¯ظٹط± ط§ظ„ظ…ط±ظƒط² ظٹظ†ط´ط¦ ط£ط®طµط§ط¦ظٹ ط£ظˆ ظ…ط¯ط®ظ„ ط¨ظٹط§ظ†ط§طھ ط£ظˆ ظ…ط¯ط®ظ„ ط¨ط±ط§ظ…ط¬ ظپظ‚ط·.');
    }
    await _repository.saveUser(account);
    await _log(
        action: 'ط­ظپط¸ ظ…ظˆط¸ظپ',
        entityType: 'user',
        entityId: account.id,
        centerId: account.centerId,
        details: '${account.name} - ${account.role.label}');
    await loadHome();
  }

  Future<void> setStaffUserActive(AppUser account, bool isActive) async {
    _ensure(canManageStaff,
        'ط¥ط¯ط§ط±ط© ط§ظ„ظ…ظˆط¸ظپظٹظ† ط؛ظٹط± ظ…طھط§ط­ط© ظ„ظ‡ط°ط§ ط§ظ„ط­ط³ط§ط¨.');
    if (!isOwner && account.centerId != activeCenterId) {
      throw StateError(
          'ظ„ط§ ظٹظ…ظƒظ† طھط¹ط¯ظٹظ„ ظ…ظˆط¸ظپ ط®ط§ط±ط¬ ظ…ط±ظƒط²ظƒ.');
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
    _ensure(canManageStaff,
        'ط¥ط¯ط§ط±ط© ط§ظ„ظ…ظˆط¸ظپظٹظ† ط؛ظٹط± ظ…طھط§ط­ط© ظ„ظ‡ط°ط§ ط§ظ„ط­ط³ط§ط¨.');
    if (newPassword.length < 8) {
      throw StateError(
          'ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط± ظٹط¬ط¨ ط£ظ„ط§ طھظ‚ظ„ ط¹ظ† 8 ط£ط­ط±ظپ.');
    }
    if (!isOwner && account.centerId != activeCenterId) {
      throw StateError(
          'ظ„ط§ ظٹظ…ظƒظ† طھط¹ط¯ظٹظ„ ط­ط³ط§ط¨ ط®ط§ط±ط¬ ظ…ط±ظƒط²ظƒ.');
    }
    if (isOwner && account.role != UserRole.centerManager) {
      throw StateError(
          'ظ…ط§ظ„ظƒ ط§ظ„ظ†ط¸ط§ظ… ظٹط؛ظٹط± ظƒظ„ظ…ط© ظ…ط±ظˆط± ظ…ط¯ط±ط§ط، ط§ظ„ظ…ط±ط§ظƒط² ظپظ‚ط· ظ…ظ† ظ‡ط°ظ‡ ط§ظ„ط´ط§ط´ط©.');
    }
    await _repository.changeUserPassword(account.id, newPassword);
    await loadHome();
  }

  Future<void> deleteStaffUser(AppUser account) async {
    _ensure(canManageStaff,
        'ط¥ط¯ط§ط±ط© ط§ظ„ظ…ظˆط¸ظپظٹظ† ط؛ظٹط± ظ…طھط§ط­ط© ظ„ظ‡ط°ط§ ط§ظ„ط­ط³ط§ط¨.');
    if (!isOwner && account.centerId != activeCenterId) {
      throw StateError('ظ„ط§ ظٹظ…ظƒظ† ط­ط°ظپ ظ…ظˆط¸ظپ ط®ط§ط±ط¬ ظ…ط±ظƒط²ظƒ.');
    }
    await _repository.deleteUser(account.id);
    await loadHome();
  }

  Future<Student> saveStudent(Student student) async {
    _ensure(
        canManageStudents, 'ظ„ط§ طھظ…ظ„ظƒ طµظ„ط§ط­ظٹط© ط­ظپط¸ ط§ظ„ط·ظ„ط§ط¨.');
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
        action: 'ط­ظپط¸ ط·ط§ظ„ط¨',
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
    _ensure(
        canDeleteStudents, 'ظ„ط§ طھظ…ظ„ظƒ طµظ„ط§ط­ظٹط© ط­ط°ظپ ط§ظ„ط·ظ„ط§ط¨.');
    await _repository.softDeleteStudent(id);
    await _log(
        action: 'ط­ط°ظپ ط·ط§ظ„ط¨',
        entityType: 'student',
        entityId: id,
        centerId: activeCenterId);
    selectedStudent = null;
    await loadHome();
  }

  Future<void> saveSession(TherapySession session,
      {bool autosave = false}) async {
    _ensure(canWriteClinical,
        'ط§ظ„ط¬ظ„ط³ط§طھ ظٹط¶ظٹظپظ‡ط§ ط§ظ„ط£ط®طµط§ط¦ظٹ ظپظ‚ط·.');
    _ensureClinicalAccess(session.studentId, session.centerId);
    await _repository.saveSession(session);
    if (!autosave) {
      await _log(
          action: 'ط¥ظ†ط´ط§ط، ط¬ظ„ط³ط©',
          entityType: 'session',
          entityId: session.id,
          centerId: session.centerId,
          details:
              '${session.studentId} - ${session.sessionType} - ${session.cardTitle}');
      await _grantXp(
          session.studentId,
          session.quickResult == 'طµط­ظٹط­' ||
                  session.quickResult == 'ظ†ط§ط¬ط­' ||
                  session.quickResult == 'ط£طھظ‚ظ†' ||
                  session.quickResult == 'ظٹط¤ط¯ظٹ ط¬ظٹط¯ظ‹ط§'
              ? 12
              : 6);
    }
    await selectStudent(selectedStudent);
  }

  Future<void> saveEvaluation(Evaluation evaluation) async {
    _ensure(
        canWriteClinical, 'ط§ظ„طھظ‚ظٹظٹظ… ظٹط¶ظٹظپظ‡ ط§ظ„ط£ط®طµط§ط¦ظٹ ظپظ‚ط·.');
    _ensureClinicalAccess(evaluation.studentId, evaluation.centerId);
    await _repository.saveEvaluation(evaluation);
    await _log(
        action: 'ط­ظپط¸ طھظ‚ظٹظٹظ…',
        entityType: 'evaluation',
        entityId: evaluation.id,
        centerId: evaluation.centerId,
        details:
            '${evaluation.studentId} - ${evaluation.letter} - ${evaluation.errorType}');
    await _grantXp(
        evaluation.studentId,
        evaluation.score == 'طµط­ظٹط­' || evaluation.score == 'ظ†ط§ط¬ط­'
            ? 8
            : 4);
    await selectStudent(selectedStudent);
  }

  Future<void> savePlan(TrainingPlan plan) async {
    _ensure(
        canWriteClinical, 'ط§ظ„ط®ط·ط· ظٹط¶ظٹظپظ‡ط§ ط§ظ„ط£ط®طµط§ط¦ظٹ ظپظ‚ط·.');
    _ensureClinicalAccess(plan.studentId, plan.centerId);
    await _repository.savePlan(plan);
    await _log(
        action: 'ط­ظپط¸ ط®ط·ط©',
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
    final completed = steps.where((step) => step.status == 'ظ…طھظ‚ظ†').length;
    return ((completed / steps.length) * 100).round();
  }

  String goalStatus(String goalId) {
    final progress = goalProgress(goalId);
    if (progress >= 100) return 'ظ…ظƒطھظ…ظ„';
    if (progress >= 70) return 'ظ…طھط­ط³ظ†';
    if (progress > 0) return 'ظ‚ظٹط¯ ط§ظ„طھط¯ط±ظٹط¨';
    final hasStarted = stepsForGoal(goalId).any(
        (step) => step.status != 'ظ„ظ… ظٹط¨ط¯ط£' && step.status.isNotEmpty);
    return hasStarted ? 'ظٹط­طھط§ط¬ ظ…طھط§ط¨ط¹ط©' : 'ط¬ط¯ظٹط¯';
  }

  Future<void> saveGoalSkillStep(GoalSkillStep step) async {
    _ensure(canWriteClinical,
        'طھطھط¨ط¹ ط§ظ„ط£ظ‡ط¯ط§ظپ ظٹط­ط¯ظ‘ط«ظ‡ ط§ظ„ط£ط®طµط§ط¦ظٹ ظپظ‚ط·.');
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
    _ensure(canWriteClinical,
        'طھطھط¨ط¹ ط§ظ„ط£ظ‡ط¯ط§ظپ ظٹط­ط¯ظ‘ط«ظ‡ ط§ظ„ط£ط®طµط§ط¦ظٹ ظپظ‚ط·.');
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
    final completed =
        goalSteps.where((step) => step.status == 'ظ…طھظ‚ظ†').length;
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
    _ensure(canWriteClinical,
        'ط§ظ„طھظ‚ظٹظٹظ… ط§ظ„ط¹ظ„ط§ط¬ظٹ ظٹط¶ظٹظپظ‡ ط§ظ„ط£ط®طµط§ط¦ظٹ ظپظ‚ط·.');
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
        final stepTitles = [
          'ظٹط´ط§ظ‡ط¯ ط§ظ„ط£ط®طµط§ط¦ظٹ ظٹظ†ظپط° ط§ظ„طھط¯ط±ظٹط¨: $training',
          'ظٹظ†ظپط° ط§ظ„طھط¯ط±ظٹط¨ ط¨ظ…ط³ط§ط¹ط¯ط©: $training',
          'ظٹظ†ظپط° ط§ظ„طھط¯ط±ظٹط¨ ط¨ط§ط³طھظ‚ظ„ط§ظ„ظٹط©: $training',
        ];
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
      action: 'ط­ظپط¸ طھظ‚ظٹظٹظ… ط¹ظ„ط§ط¬ظٹ ظ†ط·ظ‚ظٹ',
      entityType: 'clinical_assessment',
      entityId: assessment.id,
      centerId: assessment.centerId,
      details: '${assessment.studentId} - ${findings.length} ط¨ظ†ظˆط¯',
    );
    await selectStudent(selectedStudent);
  }

  Future<void> saveExercise(Exercise exercise) async {
    _ensure(canWriteParentArea,
        'ظ„ط§ طھظ…ظ„ظƒ طµظ„ط§ط­ظٹط© طھط¹ط¯ظٹظ„ ظˆط§ط¬ط¨ط§طھ ظ‡ط°ط§ ط§ظ„ط·ط§ظ„ط¨.');
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
        action: 'ط­ظپط¸ ظˆط§ط¬ط¨',
        entityType: 'exercise',
        entityId: exercise.id,
        centerId: exercise.centerId,
        details: '${exercise.studentId} - ${exercise.title}');
    await selectStudent(selectedStudent);
  }

  Future<void> saveReward(Reward reward) async {
    _ensure(canWriteClinical,
        'ط§ظ„ظ…ظƒط§ظپط¢طھ ظٹط¹ط¯ظ„ظ‡ط§ ط§ظ„ط£ط®طµط§ط¦ظٹ ظپظ‚ط·.');
    _ensureClinicalAccess(reward.studentId, reward.centerId);
    await _repository.saveReward(reward);
    await selectStudent(selectedStudent);
  }

  Future<void> saveSignResource(SignResource resource) async {
    _ensure(canWriteClinical,
        'ظ…ظƒطھط¨ط© ط§ظ„ط¥ط´ط§ط±ط© ظٹط¹ط¯ظ„ظ‡ط§ ط§ظ„ط£ط®طµط§ط¦ظٹ ظپظ‚ط·.');
    _ensure(resource.centerId == activeCenterId,
        'ظ„ط§ ظٹظ…ظƒظ† طھط¹ط¯ظٹظ„ ط¥ط´ط§ط±ط© ط®ط§ط±ط¬ ظ…ط±ظƒط²ظƒ.');
    await _repository.saveSignResource(resource);
    await _log(
        action: 'ط­ظپط¸ ط¥ط´ط§ط±ط©',
        entityType: 'sign_resource',
        entityId: resource.id,
        centerId: resource.centerId,
        details: resource.title);
    signResources = await _repository.signResources(activeCenterId);
    notifyListeners();
  }

  Future<void> deleteSignResource(String id) async {
    _ensure(canWriteClinical,
        'ظ…ظƒطھط¨ط© ط§ظ„ط¥ط´ط§ط±ط© ظٹط¹ط¯ظ„ظ‡ط§ ط§ظ„ط£ط®طµط§ط¦ظٹ ظپظ‚ط·.');
    await _repository.deleteSignResource(id);
    await _log(
        action: 'ط­ط°ظپ ط¥ط´ط§ط±ط©',
        entityType: 'sign_resource',
        entityId: id,
        centerId: activeCenterId);
    signResources = await _repository.signResources(activeCenterId);
    notifyListeners();
  }

  Future<void> exportBackup(String targetPath) async {
    _ensure(isOwner || isCenterManager,
        'ط§ظ„ظ†ط³ط® ط§ظ„ط§ط­طھظٹط§ط·ظٹ ظ…طھط§ط­ ظ„ظ…ط§ظ„ظƒ ط§ظ„ظ†ط¸ط§ظ… ط£ظˆ ظ…ط¯ظٹط± ط§ظ„ظ…ط±ظƒط².');
    await _repository.exportBackup(targetPath);
  }

  Future<void> importBackup(String sourcePath) async {
    _ensure(isOwner || isCenterManager,
        'ط§ط³طھظٹط±ط§ط¯ ط§ظ„ظ†ط³ط® ط§ظ„ط§ط­طھظٹط§ط·ظٹ ظ…طھط§ط­ ظ„ظ…ط§ظ„ظƒ ط§ظ„ظ†ط¸ط§ظ… ط£ظˆ ظ…ط¯ظٹط± ط§ظ„ظ…ط±ظƒط².');
    await _repository.importBackup(sourcePath);
    await loadHome();
  }

  Future<void> _grantXp(String studentId, int value) async {
    final current = await _repository.reward(studentId);
    if (current == null) return;
    final xp = current.xp + value;
    final badges = current.badges.isEmpty && xp >= 50
        ? 'ط¨ط¯ط§ظٹط© ظ‚ظˆظٹط©'
        : current.badges;
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
    _ensure(canViewReports,
        'ط§ظ„طھظ‚ط§ط±ظٹط± ط§ظ„ط±ط³ظ…ظٹط© ظٹطµط¯ط±ظ‡ط§ ط§ظ„ظ…ط±ظƒط² ظپظ‚ط·.');
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
        action: 'ط·ط¨ط§ط¹ط© طھظ‚ط±ظٹط±',
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
    _ensure(canViewReports,
        'ط§ظ„طھظ‚ط§ط±ظٹط± ط§ظ„ط±ط³ظ…ظٹط© ظٹطµط¯ط±ظ‡ط§ ط§ظ„ظ…ط±ظƒط² ظپظ‚ط·.');
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
        action: 'ط·ط¨ط§ط¹ط© طھظ‚ط±ظٹط±',
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
      return 'ظٹظˆطµظ‰ ط¨طھظƒط«ظٹظپ ط§ظ„طھط¯ط±ظٹط¨ ط§ظ„ط³ظ…ط¹ظٹ ظˆط§ظ„ط¨طµط±ظٹ ظˆطھظ‚ط³ظٹظ… ط§ظ„ظ‡ط¯ظپ ط¥ظ„ظ‰ ط®ط·ظˆط§طھ ظ‚طµظٹط±ط©.';
    }
    if (errorType == 'ط¥ط¨ط¯ط§ظ„') {
      return 'ظٹظˆطµظ‰ ط¨طھظ…ظٹظٹط² طµظˆطھ ط§ظ„ط­ط±ظپ ط§ظ„ظ…ط³طھظ‡ط¯ظپ ط¹ظ† ط§ظ„ط­ط±ظپ ط§ظ„ط¨ط¯ظٹظ„ ط¯ط§ط®ظ„ ظƒظ„ظ…ط§طھ ظ‚طµظٹط±ط©.';
    }
    if (errorType == 'ط­ط°ظپ') {
      return 'ظٹظˆطµظ‰ ط¨طھظ…ط§ط±ظٹظ† ط¥ط·ط§ظ„ط© ط§ظ„طµظˆطھ ظˆطھط«ط¨ظٹطھ ظ…ظˆط¶ط¹ ط§ظ„ط­ط±ظپ ظپظٹ ط§ظ„ظƒظ„ظ…ط©.';
    }
    if (errorType == 'طھط´ظˆظٹظ‡') {
      return 'ظٹظˆطµظ‰ ط¨طھط¯ط±ظٹط¨ ظ…ظˆط¶ط¹ ط§ظ„ظ„ط³ط§ظ† ظˆط§ظ„ط´ظپط§ظ‡ ط£ظ…ط§ظ… ظ…ط±ط¢ط© ظ…ط¹ طھط؛ط°ظٹط© ط±ط§ط¬ط¹ط© ظپظˆط±ظٹط©.';
    }
    return 'ظٹظˆطµظ‰ ط¨طھظƒط±ط§ط± ط§ظ„ظ‡ط¯ظپ ط¯ط§ط®ظ„ ط¬ظ…ظ„ ظˆط¸ظٹظپظٹط© ظ‚طµظٹط±ط©.';
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
        .where((item) => item.score == 'طµط­ظٹط­' || item.score == 'ظ†ط§ط¬ط­')
        .length;
    final partial =
        evaluations.where((item) => item.score == 'ط¬ط²ط¦ظٹ').length;
    return (((good + partial * .5) / evaluations.length) * 100).round();
  }

  AppUser _requireUser() {
    final current = user;
    if (current == null) {
      throw StateError('ظٹط¬ط¨ طھط³ط¬ظٹظ„ ط§ظ„ط¯ط®ظˆظ„ ط£ظˆظ„ظ‹ط§.');
    }
    return current;
  }

  void _ensure(bool allowed, String message) {
    if (!allowed) throw StateError(message);
  }

  void _ensureClinicalAccess(String studentId, String centerId) {
    _ensure(centerId == activeCenterId,
        'ظ„ط§ ظٹظ…ظƒظ† طھظ†ظپظٹط° ط§ظ„ط¹ظ…ظ„ظٹط© ط®ط§ط±ط¬ ظ…ط±ظƒط²ظƒ.');
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
      _ensure(centerId == activeCenterId,
          'ظ„ط§ ظٹظ…ظƒظ† ط§ظ„ظˆطµظˆظ„ ظ„ط¨ظٹط§ظ†ط§طھ ظ…ط±ظƒط² ط¢ط®ط±.');
    }
    if (isParent) {
      final allowed = user?.studentId == studentId ||
          students.any((item) => item.id == studentId);
      _ensure(allowed,
          'ظˆظ„ظٹ ط§ظ„ط£ظ…ط± ظٹط±ظ‰ ط¨ظٹط§ظ†ط§طھ ط£ط·ظپط§ظ„ظ‡ ظپظ‚ط·.');
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
            current.role == UserRole.specialist ||
            current.role == UserRole.dataEntry ||
            current.role == UserRole.programEntry) &&
        current.centerId == student.centerId) {
      return;
    }
    throw StateError(
        'ظ„ط§ طھظ…ظ„ظƒ طµظ„ط§ط­ظٹط© ط§ظ„ظˆطµظˆظ„ ظ„ظ‡ط°ط§ ط§ظ„ط·ط§ظ„ط¨.');
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
