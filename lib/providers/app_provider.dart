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
  List<SanadCenter> centers = [];
  List<AppUser> staff = [];
  List<Student> students = [];
  Student? selectedStudent;
  List<TherapySession> sessions = [];
  List<Evaluation> evaluations = [];
  List<TrainingPlan> plans = [];
  List<TherapyProgram> programs = [];
  List<ProgramSection> programSections = [];
  List<ProgramSkill> programSkills = [];
  List<ProgramActivity> programActivities = [];
  List<Exercise> exercises = [];
  List<ReportRecord> reports = [];
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

  bool get isOwner => user?.role == UserRole.sanadOwner;
  bool get isCenterManager => user?.role == UserRole.centerManager;
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
  bool get canManagePrograms => isCenterManager || isProgramEntry;
  bool get canUsePrograms => canManagePrograms || isSpecialist;
  bool get canWriteParentArea => isParent || canWriteClinical;
  bool get canViewReports => isCenterManager || isSpecialist;
  String get activeCenterId => currentCenter?.id ?? user?.centerId ?? '';
  int get completedHomeworkCount => centerExercises
      .where((item) => item.status == 'ط¸â€¦ط¸ئ’ط·ع¾ط¸â€¦ط¸â€‍')
      .length;
  String get hardestLetter {
    final counts = <String, int>{};
    for (final evaluation in centerEvaluations
        .where((item) => item.score == 'ط·آ®ط·آ·ط·آ£' || item.severity >= 4)) {
      counts[evaluation.letter] = (counts[evaluation.letter] ?? 0) + 1;
    }
    if (counts.isEmpty) return '-';
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return '${sorted.first.key} (${sorted.first.value})';
  }

  String get mostUsedSign {
    final counts = <String, int>{};
    for (final session in centerSessions.where(
        (item) => item.sessionType == 'ط¸â€‍ط·ط›ط·آ© ط·آ¥ط·آ´ط·آ§ط·آ±ط·آ©')) {
      for (final item in session.practiceItems
          .split(RegExp(r'[ط·إ’,]'))
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
            title: 'ط·آ¨ط·آ§ط·آ¨',
            letter: 'ط·آ¨',
            position: 'ط·آ£ط¸ث†ط¸â€‍ ط·آ§ط¸â€‍ط¸ئ’ط¸â€‍ط¸â€¦ط·آ©',
            level: 'ط¸â€¦ط·آ¨ط·ع¾ط·آ¯ط·آ¦',
            category: 'ط¸ئ’ط¸â€‍ط¸â€¦ط·آ§ط·ع¾'),
        TrainingItem(
            id: 's2',
            type: 'word',
            title: 'ط¸ئ’ط¸ث†ط·آ¨',
            letter: 'ط·آ¨',
            position: 'ط·آ¢ط·آ®ط·آ± ط·آ§ط¸â€‍ط¸ئ’ط¸â€‍ط¸â€¦ط·آ©',
            level: 'ط¸â€¦ط·آ¨ط·ع¾ط·آ¯ط·آ¦',
            category: 'ط¸ئ’ط¸â€‍ط¸â€¦ط·آ§ط·ع¾'),
        TrainingItem(
            id: 's3',
            type: 'sentence',
            title: 'ط·آ¨ط·آ§ط·آ¨ ط·آ§ط¸â€‍ط·آ¨ط¸ظ¹ط·ع¾ ط¸â€¦ط¸ظ¾ط·ع¾ط¸ث†ط·آ­',
            letter: 'ط·آ¨',
            position: 'ط·آ£ط¸ث†ط¸â€‍ ط·آ§ط¸â€‍ط¸ئ’ط¸â€‍ط¸â€¦ط·آ©',
            level: 'ط¸â€¦ط·ع¾ط¸ث†ط·آ³ط·آ·',
            category: 'ط·آ¬ط¸â€¦ط¸â€‍'),
        TrainingItem(
            id: 's4',
            type: 'word',
            title: 'ط·آ³ط¸â€¦ط¸ئ’',
            letter: 'ط·آ³',
            position: 'ط·آ£ط¸ث†ط¸â€‍ ط·آ§ط¸â€‍ط¸ئ’ط¸â€‍ط¸â€¦ط·آ©',
            level: 'ط¸â€¦ط·آ¨ط·ع¾ط·آ¯ط·آ¦',
            category: 'ط¸ئ’ط¸â€‍ط¸â€¦ط·آ§ط·ع¾'),
        TrainingItem(
            id: 's5',
            type: 'sentence',
            title: 'ط·آ³ط·آ§ط¸â€¦ط¸ظ¹ ط¸ظ¹ط·آ³ط¸â€¦ط·آ¹ ط·آ§ط¸â€‍ط·آµط¸ث†ط·ع¾',
            letter: 'ط·آ³',
            position: 'ط¸ث†ط·آ³ط·آ· ط·آ§ط¸â€‍ط¸ئ’ط¸â€‍ط¸â€¦ط·آ©',
            level: 'ط¸â€¦ط·ع¾ط¸ث†ط·آ³ط·آ·',
            category: 'ط·آ¬ط¸â€¦ط¸â€‍'),
      ];
  String get smartSessionSuggestion {
    if (evaluations.isEmpty && sessions.isEmpty) {
      return 'ط·آ§ط·آ¨ط·آ¯ط·آ£ ط·آ¨ط¸â€،ط·آ¯ط¸ظ¾ ط¸â€ڑط·آµط¸ظ¹ط·آ± ط¸â€¦ط¸â€  ط·آ§ط¸â€‍ط·آ®ط·آ·ط·آ© ط·آ§ط¸â€‍ط·آ­ط·آ§ط¸â€‍ط¸ظ¹ط·آ© ط·آ«ط¸â€¦ ط¸â€ڑط¸ظ¹ط¸â€کط¸â€¦ 5 ط¸â€¦ط·آ­ط·آ§ط¸ث†ط¸â€‍ط·آ§ط·ع¾.';
    }
    final weakEvaluation = evaluations
        .where((item) => item.score == 'ط·آ®ط·آ·ط·آ£' || item.severity >= 4)
        .toList();
    if (weakEvaluation.isNotEmpty) {
      final item = weakEvaluation.first;
      return 'ط·آ§ط¸â€ڑط·ع¾ط·آ±ط·آ­ ط·ع¾ط·آ¯ط·آ±ط¸ظ¹ط·آ¨ ط·آ­ط·آ±ط¸ظ¾ ${item.letter} ط¸ظ¾ط¸ظ¹ ط¸â€¦ط¸ث†ط·آ¶ط·آ¹ ${item.position} ط·آ¨ط·آ³ط·آ¨ط·آ¨ ط·ع¾ط¸ئ’ط·آ±ط·آ§ط·آ± ${item.errorType}.';
    }
    final lastSession = sessions.isEmpty ? null : sessions.first;
    if (lastSession != null && lastSession.successRate >= 85) {
      return 'ط·آ§ط¸â€‍ط·آ£ط·آ¯ط·آ§ط·طŒ ط¸â€¦ط¸â€¦ط·ع¾ط·آ§ط·آ²ط·â€؛ ط·آ¬ط·آ±ط¸â€کط·آ¨ ط¸â€¦ط·آ³ط·ع¾ط¸ث†ط¸â€° ط·آ£ط·آµط·آ¹ط·آ¨ ط¸ث†ط·آ²ط·آ¯ ط¸â€ ط¸â€ڑط·آ§ط·آ· XP ط·آ¹ط¸â€ ط·آ¯ ط·آ§ط¸â€‍ط·آ¥ط·ع¾ط¸â€ڑط·آ§ط¸â€ .';
    }
    if (lastSession != null &&
        lastSession.letterPosition ==
            'ط·آ¢ط·آ®ط·آ± ط·آ§ط¸â€‍ط¸ئ’ط¸â€‍ط¸â€¦ط·آ©' &&
        lastSession.quickResult == 'ط·آ®ط·آ·ط·آ£') {
      return 'ط·آ±ط¸ئ’ط¸â€کط·آ² ط·آ¹ط¸â€‍ط¸â€° ط·ع¾ط·آ¯ط·آ±ط¸ظ¹ط·آ¨ط·آ§ط·ع¾ ط·آ¢ط·آ®ط·آ± ط·آ§ط¸â€‍ط¸ئ’ط¸â€‍ط¸â€¦ط·آ© ط¸ظ¾ط¸ظ¹ ط·آ§ط¸â€‍ط·آ¬ط¸â€‍ط·آ³ط·آ© ط·آ§ط¸â€‍ط¸â€ڑط·آ§ط·آ¯ط¸â€¦ط·آ©.';
    }
    return 'ط·آ§ط·آ³ط·ع¾ط¸â€¦ط·آ± ط·آ¹ط¸â€‍ط¸â€° ط¸â€،ط·آ¯ط¸ظ¾ ط·آ§ط¸â€‍ط·آ®ط·آ·ط·آ© ط·آ§ط¸â€‍ط·آ­ط·آ§ط¸â€‍ط¸ظ¹ ط¸â€¦ط·آ¹ ط·ع¾ط¸â€ڑط¸â€‍ط¸ظ¹ط¸â€‍ ط·آ§ط¸â€‍ط¸â€¦ط·آ³ط·آ§ط·آ¹ط·آ¯ط·آ© ط·ع¾ط·آ¯ط·آ±ط¸ظ¹ط·آ¬ط¸ظ¹ط¸â€¹ط·آ§.';
  }

  bool get signLanguageEnabledForSelectedStudent {
    final student = selectedStudent;
    if (student == null) return true;
    return student.programType.contains('ط·آ³ط¸â€¦ط·آ¹') ||
        student.programType.contains('ط·آ¥ط·آ´ط·آ§ط·آ±ط·آ©') ||
        plans.any((plan) => plan.goal.contains('ط·آ¥ط·آ´ط·آ§ط·آ±ط·آ©'));
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

  Future<void> createSystemOwner(
      {required String name,
      required String email,
      required String password,
      required String confirmPassword}) async {
    if (name.trim().isEmpty || email.trim().isEmpty || password.isEmpty) {
      throw StateError(
          'ط·آ£ط¸ئ’ط¸â€¦ط¸â€‍ ط·آ¨ط¸ظ¹ط·آ§ط¸â€ ط·آ§ط·ع¾ ط¸â€¦ط·آ§ط¸â€‍ط¸ئ’ ط·آ§ط¸â€‍ط¸â€ ط·آ¸ط·آ§ط¸â€¦.');
    }
    if (password.length < 8) {
      throw StateError(
          'ط¸ئ’ط¸â€‍ط¸â€¦ط·آ© ط·آ§ط¸â€‍ط¸â€¦ط·آ±ط¸ث†ط·آ± ط¸ظ¹ط·آ¬ط·آ¨ ط·آ£ط¸â€‍ط·آ§ ط·ع¾ط¸â€ڑط¸â€‍ ط·آ¹ط¸â€  8 ط·آ£ط·آ­ط·آ±ط¸ظ¾.');
    }
    if (password != confirmPassword) {
      throw StateError(
          'ط¸ئ’ط¸â€‍ط¸â€¦ط·ع¾ط·آ§ ط·آ§ط¸â€‍ط¸â€¦ط·آ±ط¸ث†ط·آ± ط·ط›ط¸ظ¹ط·آ± ط¸â€¦ط·ع¾ط·آ·ط·آ§ط·آ¨ط¸â€ڑط·ع¾ط¸ظ¹ط¸â€ .');
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
          'ط¸ئ’ط¸â€‍ط¸â€¦ط·آ© ط·آ§ط¸â€‍ط¸â€¦ط·آ±ط¸ث†ط·آ± ط¸ظ¹ط·آ¬ط·آ¨ ط·آ£ط¸â€‍ط·آ§ ط·ع¾ط¸â€ڑط¸â€‍ ط·آ¹ط¸â€  6 ط·آ£ط·آ­ط·آ±ط¸ظ¾.');
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
    centers = [];
    staff = [];
    students = [];
    selectedStudent = null;
    sessions = [];
    evaluations = [];
    plans = [];
    programs = [];
    programSections = [];
    programSkills = [];
    programActivities = [];
    exercises = [];
    reports = [];
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
        : allCenters.where((center) => center.id == current.centerId).toList();
    if (isOwner) {
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
    signResources = activeCenterId.isEmpty
        ? []
        : await _repository.signResources(activeCenterId);
    if (activeCenterId.isEmpty) {
      programs = [];
      programSections = [];
      programSkills = [];
      programActivities = [];
    } else {
      programs = await _repository.programs(activeCenterId);
      await _loadProgramTree();
    }
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
        : (students.isEmpty ? null : students.first);
    await selectStudent(selectedStudent);
  }

  Future<void> switchCenter(SanadCenter center) async {
    _ensure(canManageCenters,
        'ط·آ¥ط·آ¯ط·آ§ط·آ±ط·آ© ط·آ§ط¸â€‍ط¸â€¦ط·آ±ط·آ§ط¸ئ’ط·آ² ط·آ®ط·آ§ط·آµط·آ© ط·آ¨ط¸â€¦ط·آ§ط¸â€‍ط¸ئ’ ط·آ§ط¸â€‍ط¸â€ ط·آ¸ط·آ§ط¸â€¦ ط¸ظ¾ط¸â€ڑط·آ·.');
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
      exercises = [];
      reports = [];
      auditLogs = isOwner || isCenterManager
          ? await _repository.auditLogs(
              centerId: isOwner ? null : activeCenterId)
          : [];
      reward = null;
    } else {
      sessions = await _repository.sessions(student.id);
      evaluations = await _repository.evaluations(student.id);
      plans = await _repository.plans(student.id);
      exercises = await _repository.exercises(student.id);
      reports = await _repository.reports(student.id);
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

  Future<void> _loadProgramTree() async {
    programSections = [];
    programSkills = [];
    programActivities = [];
    for (final program in programs) {
      programSections.addAll(await _repository.programSections(program.id));
      programSkills.addAll(await _repository.programSkills(program.id));
      programActivities.addAll(await _repository.programActivities(program.id));
    }
  }

  Future<void> saveCenter(SanadCenter center) async {
    _ensure(
        canManageCenters || (isCenterManager && center.id == activeCenterId),
        'ط¸â€‍ط¸ظ¹ط·آ³ط·ع¾ ط¸â€‍ط·آ¯ط¸ظ¹ط¸ئ’ ط·آµط¸â€‍ط·آ§ط·آ­ط¸ظ¹ط·آ© ط·ع¾ط·آ¹ط·آ¯ط¸ظ¹ط¸â€‍ ط¸â€،ط·آ°ط·آ§ ط·آ§ط¸â€‍ط¸â€¦ط·آ±ط¸ئ’ط·آ².');
    await _repository.saveCenter(center);
    await _log(
        action: 'ط·آ­ط¸ظ¾ط·آ¸ ط¸â€¦ط·آ±ط¸ئ’ط·آ²',
        entityType: 'center',
        entityId: center.id,
        centerId: center.id,
        details: center.name);
    await loadHome();
  }

  Future<void> deleteCenter(String id) async {
    _ensure(canManageCenters,
        'ط·آ­ط·آ°ط¸ظ¾ ط·آ§ط¸â€‍ط¸â€¦ط·آ±ط·آ§ط¸ئ’ط·آ² ط·آ®ط·آ§ط·آµ ط·آ¨ط¸â€¦ط·آ§ط¸â€‍ط¸ئ’ ط·آ§ط¸â€‍ط¸â€ ط·آ¸ط·آ§ط¸â€¦ ط¸ظ¾ط¸â€ڑط·آ·.');
    await _repository.deleteCenter(id);
    if (currentCenter?.id == id) {
      currentCenter = null;
    }
    await _log(
        action: 'ط·آ­ط·آ°ط¸ظ¾ ط¸â€¦ط·آ±ط¸ئ’ط·آ²',
        entityType: 'center',
        entityId: id,
        centerId: id);
    await loadHome();
  }

  Future<void> saveStaffUser(AppUser account) async {
    _ensure(canManageStaff,
        'ط·آ¥ط·آ¯ط·آ§ط·آ±ط·آ© ط·آ§ط¸â€‍ط¸â€¦ط¸ث†ط·آ¸ط¸ظ¾ط¸ظ¹ط¸â€  ط·ط›ط¸ظ¹ط·آ± ط¸â€¦ط·ع¾ط·آ§ط·آ­ط·آ© ط¸â€‍ط¸â€،ط·آ°ط·آ§ ط·آ§ط¸â€‍ط·آ­ط·آ³ط·آ§ط·آ¨.');
    if (!isOwner && account.centerId != activeCenterId) {
      throw StateError(
          'ط¸â€‍ط·آ§ ط¸ظ¹ط¸â€¦ط¸ئ’ط¸â€  ط·آ¥ط¸â€ ط·آ´ط·آ§ط·طŒ ط¸â€¦ط¸ث†ط·آ¸ط¸ظ¾ ط·آ®ط·آ§ط·آ±ط·آ¬ ط¸â€¦ط·آ±ط¸ئ’ط·آ²ط¸ئ’.');
    }
    if (!isOwner && account.role == UserRole.sanadOwner) {
      throw StateError(
          'ط¸â€¦ط·آ§ط¸â€‍ط¸ئ’ ط·آ§ط¸â€‍ط¸â€ ط·آ¸ط·آ§ط¸â€¦ ط¸â€‍ط·آ§ ط¸ظ¹ط¸â€ ط·آ´ط·آ¦ط¸â€، ط·آ¥ط¸â€‍ط·آ§ ط¸â€¦ط·آ§ط¸â€‍ط¸ئ’ ط·آ§ط¸â€‍ط¸â€ ط·آ¸ط·آ§ط¸â€¦.');
    }
    if (isOwner && account.role != UserRole.centerManager) {
      throw StateError(
          'ط¸â€¦ط·آ§ط¸â€‍ط¸ئ’ ط·آ§ط¸â€‍ط¸â€ ط·آ¸ط·آ§ط¸â€¦ ط¸ظ¹ط¸â€ ط·آ´ط·آ¦ ط¸â€¦ط·آ¯ط¸ظ¹ط·آ± ط¸â€¦ط·آ±ط¸ئ’ط·آ² ط¸ظ¾ط¸â€ڑط·آ·.');
    }
    if (isCenterManager &&
        account.role != UserRole.specialist &&
        account.role != UserRole.dataEntry &&
        account.role != UserRole.programEntry) {
      throw StateError(
          'ط¸â€¦ط·آ¯ط¸ظ¹ط·آ± ط·آ§ط¸â€‍ط¸â€¦ط·آ±ط¸ئ’ط·آ² ط¸ظ¹ط¸â€ ط·آ´ط·آ¦ ط·آ£ط·آ®ط·آµط·آ§ط·آ¦ط¸ظ¹ ط·آ£ط¸ث† ط¸â€¦ط·آ¯ط·آ®ط¸â€‍ ط·آ¨ط¸ظ¹ط·آ§ط¸â€ ط·آ§ط·ع¾ ط·آ£ط¸ث† ط¸â€¦ط·آ¯ط·آ®ط¸â€‍ ط·آ¨ط·آ±ط·آ§ط¸â€¦ط·آ¬ ط¸ظ¾ط¸â€ڑط·آ·.');
    }
    await _repository.saveUser(account);
    await _log(
        action: 'ط·آ­ط¸ظ¾ط·آ¸ ط¸â€¦ط¸ث†ط·آ¸ط¸ظ¾',
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
    _ensure(canManageStudents,
        'ط¸â€‍ط·آ§ ط·ع¾ط¸â€¦ط¸â€‍ط¸ئ’ ط·آµط¸â€‍ط·آ§ط·آ­ط¸ظ¹ط·آ© ط·آ­ط¸ظ¾ط·آ¸ ط·آ§ط¸â€‍ط·آ·ط¸â€‍ط·آ§ط·آ¨.');
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
        action: 'ط·آ­ط¸ظ¾ط·آ¸ ط·آ·ط·آ§ط¸â€‍ط·آ¨',
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
    _ensure(canDeleteStudents,
        'ط¸â€‍ط·آ§ ط·ع¾ط¸â€¦ط¸â€‍ط¸ئ’ ط·آµط¸â€‍ط·آ§ط·آ­ط¸ظ¹ط·آ© ط·آ­ط·آ°ط¸ظ¾ ط·آ§ط¸â€‍ط·آ·ط¸â€‍ط·آ§ط·آ¨.');
    await _repository.softDeleteStudent(id);
    await _log(
        action: 'ط·آ­ط·آ°ط¸ظ¾ ط·آ·ط·آ§ط¸â€‍ط·آ¨',
        entityType: 'student',
        entityId: id,
        centerId: activeCenterId);
    selectedStudent = null;
    await loadHome();
  }

  Future<void> saveSession(TherapySession session,
      {bool autosave = false}) async {
    _ensure(canWriteClinical,
        'ط·آ§ط¸â€‍ط·آ¬ط¸â€‍ط·آ³ط·آ§ط·ع¾ ط¸ظ¹ط·آ¶ط¸ظ¹ط¸ظ¾ط¸â€،ط·آ§ ط·آ§ط¸â€‍ط·آ£ط·آ®ط·آµط·آ§ط·آ¦ط¸ظ¹ ط¸ظ¾ط¸â€ڑط·آ·.');
    _ensureClinicalAccess(session.studentId, session.centerId);
    await _repository.saveSession(session);
    if (!autosave) {
      await _log(
          action: 'ط·آ¥ط¸â€ ط·آ´ط·آ§ط·طŒ ط·آ¬ط¸â€‍ط·آ³ط·آ©',
          entityType: 'session',
          entityId: session.id,
          centerId: session.centerId,
          details:
              '${session.studentId} - ${session.sessionType} - ${session.cardTitle}');
      await _grantXp(
          session.studentId,
          session.quickResult == 'ط·آµط·آ­ط¸ظ¹ط·آ­' ||
                  session.quickResult == 'ط¸â€ ط·آ§ط·آ¬ط·آ­' ||
                  session.quickResult == 'ط·آ£ط·ع¾ط¸â€ڑط¸â€ '
              ? 12
              : 6);
    }
    await selectStudent(selectedStudent);
  }

  Future<void> saveEvaluation(Evaluation evaluation) async {
    _ensure(canWriteClinical,
        'ط·آ§ط¸â€‍ط·ع¾ط¸â€ڑط¸ظ¹ط¸ظ¹ط¸â€¦ ط¸ظ¹ط·آ¶ط¸ظ¹ط¸ظ¾ط¸â€، ط·آ§ط¸â€‍ط·آ£ط·آ®ط·آµط·آ§ط·آ¦ط¸ظ¹ ط¸ظ¾ط¸â€ڑط·آ·.');
    _ensureClinicalAccess(evaluation.studentId, evaluation.centerId);
    await _repository.saveEvaluation(evaluation);
    await _log(
        action: 'ط·آ­ط¸ظ¾ط·آ¸ ط·ع¾ط¸â€ڑط¸ظ¹ط¸ظ¹ط¸â€¦',
        entityType: 'evaluation',
        entityId: evaluation.id,
        centerId: evaluation.centerId,
        details:
            '${evaluation.studentId} - ${evaluation.letter} - ${evaluation.errorType}');
    await _grantXp(
        evaluation.studentId,
        evaluation.score == 'ط·آµط·آ­ط¸ظ¹ط·آ­' ||
                evaluation.score == 'ط¸â€ ط·آ§ط·آ¬ط·آ­'
            ? 8
            : 4);
    await selectStudent(selectedStudent);
  }

  Future<void> savePlan(TrainingPlan plan) async {
    _ensure(canWriteClinical,
        'ط·آ§ط¸â€‍ط·آ®ط·آ·ط·آ· ط¸ظ¹ط·آ¶ط¸ظ¹ط¸ظ¾ط¸â€،ط·آ§ ط·آ§ط¸â€‍ط·آ£ط·آ®ط·آµط·آ§ط·آ¦ط¸ظ¹ ط¸ظ¾ط¸â€ڑط·آ·.');
    _ensureClinicalAccess(plan.studentId, plan.centerId);
    await _repository.savePlan(plan);
    await _log(
        action: 'ط·آ­ط¸ظ¾ط·آ¸ ط·آ®ط·آ·ط·آ©',
        entityType: 'plan',
        entityId: plan.id,
        centerId: plan.centerId,
        details: '${plan.studentId} - ${plan.goal}');
    await selectStudent(selectedStudent);
  }

  Future<void> saveProgram(TherapyProgram program) async {
    _ensure(canManagePrograms,
        'ط·آ¥ط·آ¯ط·آ§ط·آ±ط·آ© ط·آ§ط¸â€‍ط·آ¨ط·آ±ط·آ§ط¸â€¦ط·آ¬ ط¸â€¦ط·ع¾ط·آ§ط·آ­ط·آ© ط¸â€‍ط¸â€¦ط·آ¯ط¸ظ¹ط·آ± ط·آ§ط¸â€‍ط¸â€¦ط·آ±ط¸ئ’ط·آ² ط·آ£ط¸ث† ط¸â€¦ط·آ¯ط·آ®ط¸â€‍ ط·آ§ط¸â€‍ط·آ¨ط·آ±ط·آ§ط¸â€¦ط·آ¬ ط¸ظ¾ط¸â€ڑط·آ·.');
    _ensure(program.centerId == activeCenterId,
        'ط¸â€‍ط·آ§ ط¸ظ¹ط¸â€¦ط¸ئ’ط¸â€  ط·آ­ط¸ظ¾ط·آ¸ ط·آ¨ط·آ±ط¸â€ ط·آ§ط¸â€¦ط·آ¬ ط·آ®ط·آ§ط·آ±ط·آ¬ ط¸â€¦ط·آ±ط¸ئ’ط·آ²ط¸ئ’.');
    await _repository.saveProgram(program);
    await _log(
        action: 'ط·آ­ط¸ظ¾ط·آ¸ ط·آ¨ط·آ±ط¸â€ ط·آ§ط¸â€¦ط·آ¬',
        entityType: 'program',
        entityId: program.id,
        centerId: program.centerId,
        details: program.name);
    programs = await _repository.programs(activeCenterId);
    await _loadProgramTree();
    notifyListeners();
  }

  Future<void> saveProgramSection(ProgramSection section) async {
    _ensure(canManagePrograms,
        'ط·آ¥ط·آ¯ط·آ§ط·آ±ط·آ© ط·آ§ط¸â€‍ط·آ¨ط·آ±ط·آ§ط¸â€¦ط·آ¬ ط¸â€¦ط·ع¾ط·آ§ط·آ­ط·آ© ط¸â€‍ط¸â€¦ط·آ¯ط¸ظ¹ط·آ± ط·آ§ط¸â€‍ط¸â€¦ط·آ±ط¸ئ’ط·آ² ط·آ£ط¸ث† ط¸â€¦ط·آ¯ط·آ®ط¸â€‍ ط·آ§ط¸â€‍ط·آ¨ط·آ±ط·آ§ط¸â€¦ط·آ¬ ط¸ظ¾ط¸â€ڑط·آ·.');
    _ensure(section.centerId == activeCenterId,
        'ط¸â€‍ط·آ§ ط¸ظ¹ط¸â€¦ط¸ئ’ط¸â€  ط·آ­ط¸ظ¾ط·آ¸ ط¸â€¦ط·آ±ط·آ­ط¸â€‍ط·آ© ط·آ®ط·آ§ط·آ±ط·آ¬ ط¸â€¦ط·آ±ط¸ئ’ط·آ²ط¸ئ’.');
    await _repository.saveProgramSection(section);
    await _loadProgramTree();
    notifyListeners();
  }

  Future<void> saveProgramSkill(ProgramSkill skill) async {
    _ensure(canManagePrograms,
        'ط·آ¥ط·آ¯ط·آ§ط·آ±ط·آ© ط·آ§ط¸â€‍ط·آ¨ط·آ±ط·آ§ط¸â€¦ط·آ¬ ط¸â€¦ط·ع¾ط·آ§ط·آ­ط·آ© ط¸â€‍ط¸â€¦ط·آ¯ط¸ظ¹ط·آ± ط·آ§ط¸â€‍ط¸â€¦ط·آ±ط¸ئ’ط·آ² ط·آ£ط¸ث† ط¸â€¦ط·آ¯ط·آ®ط¸â€‍ ط·آ§ط¸â€‍ط·آ¨ط·آ±ط·آ§ط¸â€¦ط·آ¬ ط¸ظ¾ط¸â€ڑط·آ·.');
    _ensure(skill.centerId == activeCenterId,
        'ط¸â€‍ط·آ§ ط¸ظ¹ط¸â€¦ط¸ئ’ط¸â€  ط·آ­ط¸ظ¾ط·آ¸ ط¸â€¦ط¸â€،ط·آ§ط·آ±ط·آ© ط·آ®ط·آ§ط·آ±ط·آ¬ ط¸â€¦ط·آ±ط¸ئ’ط·آ²ط¸ئ’.');
    await _repository.saveProgramSkill(skill);
    await _loadProgramTree();
    notifyListeners();
  }

  Future<void> saveProgramActivity(ProgramActivity activity) async {
    _ensure(canManagePrograms,
        'ط·آ¥ط·آ¯ط·آ§ط·آ±ط·آ© ط·آ§ط¸â€‍ط·آ¨ط·آ±ط·آ§ط¸â€¦ط·آ¬ ط¸â€¦ط·ع¾ط·آ§ط·آ­ط·آ© ط¸â€‍ط¸â€¦ط·آ¯ط¸ظ¹ط·آ± ط·آ§ط¸â€‍ط¸â€¦ط·آ±ط¸ئ’ط·آ² ط·آ£ط¸ث† ط¸â€¦ط·آ¯ط·آ®ط¸â€‍ ط·آ§ط¸â€‍ط·آ¨ط·آ±ط·آ§ط¸â€¦ط·آ¬ ط¸ظ¾ط¸â€ڑط·آ·.');
    _ensure(activity.centerId == activeCenterId,
        'ط¸â€‍ط·آ§ ط¸ظ¹ط¸â€¦ط¸ئ’ط¸â€  ط·آ­ط¸ظ¾ط·آ¸ ط¸â€ ط·آ´ط·آ§ط·آ· ط·آ®ط·آ§ط·آ±ط·آ¬ ط¸â€¦ط·آ±ط¸ئ’ط·آ²ط¸ئ’.');
    await _repository.saveProgramActivity(activity);
    await _loadProgramTree();
    notifyListeners();
  }

  Future<void> saveExercise(Exercise exercise) async {
    _ensure(canWriteParentArea,
        'ط¸â€‍ط·آ§ ط·ع¾ط¸â€¦ط¸â€‍ط¸ئ’ ط·آµط¸â€‍ط·آ§ط·آ­ط¸ظ¹ط·آ© ط·ع¾ط·آ¹ط·آ¯ط¸ظ¹ط¸â€‍ ط¸ث†ط·آ§ط·آ¬ط·آ¨ط·آ§ط·ع¾ ط¸â€،ط·آ°ط·آ§ ط·آ§ط¸â€‍ط·آ·ط·آ§ط¸â€‍ط·آ¨.');
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
        action: 'ط·آ­ط¸ظ¾ط·آ¸ ط¸ث†ط·آ§ط·آ¬ط·آ¨',
        entityType: 'exercise',
        entityId: exercise.id,
        centerId: exercise.centerId,
        details: '${exercise.studentId} - ${exercise.title}');
    await selectStudent(selectedStudent);
  }

  Future<void> saveReward(Reward reward) async {
    _ensure(canWriteClinical,
        'ط·آ§ط¸â€‍ط¸â€¦ط¸ئ’ط·آ§ط¸ظ¾ط·آ¢ط·ع¾ ط¸ظ¹ط·آ¹ط·آ¯ط¸â€‍ط¸â€،ط·آ§ ط·آ§ط¸â€‍ط¸â€¦ط·آ±ط¸ئ’ط·آ² ط¸ظ¾ط¸â€ڑط·آ·.');
    _ensureClinicalAccess(reward.studentId, reward.centerId);
    await _repository.saveReward(reward);
    await selectStudent(selectedStudent);
  }

  Future<void> saveSignResource(SignResource resource) async {
    _ensure(canWriteClinical,
        'ط¸â€¦ط¸ئ’ط·ع¾ط·آ¨ط·آ© ط·آ§ط¸â€‍ط·آ¥ط·آ´ط·آ§ط·آ±ط·آ© ط¸ظ¹ط·آ¹ط·آ¯ط¸â€‍ط¸â€،ط·آ§ ط·آ§ط¸â€‍ط¸â€¦ط·آ±ط¸ئ’ط·آ² ط¸ظ¾ط¸â€ڑط·آ·.');
    _ensure(resource.centerId == activeCenterId,
        'ط¸â€‍ط·آ§ ط¸ظ¹ط¸â€¦ط¸ئ’ط¸â€  ط·ع¾ط·آ¹ط·آ¯ط¸ظ¹ط¸â€‍ ط·آ¥ط·آ´ط·آ§ط·آ±ط·آ© ط·آ®ط·آ§ط·آ±ط·آ¬ ط¸â€¦ط·آ±ط¸ئ’ط·آ²ط¸ئ’.');
    await _repository.saveSignResource(resource);
    await _log(
        action: 'ط·آ­ط¸ظ¾ط·آ¸ ط·آ¥ط·آ´ط·آ§ط·آ±ط·آ©',
        entityType: 'sign_resource',
        entityId: resource.id,
        centerId: resource.centerId,
        details: resource.title);
    signResources = await _repository.signResources(activeCenterId);
    notifyListeners();
  }

  Future<void> deleteSignResource(String id) async {
    _ensure(canWriteClinical,
        'ط¸â€¦ط¸ئ’ط·ع¾ط·آ¨ط·آ© ط·آ§ط¸â€‍ط·آ¥ط·آ´ط·آ§ط·آ±ط·آ© ط¸ظ¹ط·آ¹ط·آ¯ط¸â€‍ط¸â€،ط·آ§ ط·آ§ط¸â€‍ط¸â€¦ط·آ±ط¸ئ’ط·آ² ط¸ظ¾ط¸â€ڑط·آ·.');
    await _repository.deleteSignResource(id);
    await _log(
        action: 'ط·آ­ط·آ°ط¸ظ¾ ط·آ¥ط·آ´ط·آ§ط·آ±ط·آ©',
        entityType: 'sign_resource',
        entityId: id,
        centerId: activeCenterId);
    signResources = await _repository.signResources(activeCenterId);
    notifyListeners();
  }

  Future<void> exportBackup(String targetPath) async {
    _ensure(isOwner || isCenterManager,
        'ط·آ§ط¸â€‍ط¸â€ ط·آ³ط·آ® ط·آ§ط¸â€‍ط·آ§ط·آ­ط·ع¾ط¸ظ¹ط·آ§ط·آ·ط¸ظ¹ ط¸â€‍ط¸â€‍ط¸â€¦ط·آ§ط¸â€‍ط¸ئ’ ط·آ£ط¸ث† ط¸â€¦ط·آ¯ط¸ظ¹ط·آ± ط·آ§ط¸â€‍ط¸â€¦ط·آ±ط¸ئ’ط·آ².');
    await _repository.exportBackup(targetPath);
  }

  Future<void> importBackup(String sourcePath) async {
    _ensure(isOwner || isCenterManager,
        'ط·آ§ط·آ³ط·ع¾ط¸ظ¹ط·آ±ط·آ§ط·آ¯ ط·آ§ط¸â€‍ط¸â€ ط·آ³ط·آ® ط·آ§ط¸â€‍ط·آ§ط·آ­ط·ع¾ط¸ظ¹ط·آ§ط·آ·ط¸ظ¹ ط¸â€‍ط¸â€‍ط¸â€¦ط·آ§ط¸â€‍ط¸ئ’ ط·آ£ط¸ث† ط¸â€¦ط·آ¯ط¸ظ¹ط·آ± ط·آ§ط¸â€‍ط¸â€¦ط·آ±ط¸ئ’ط·آ².');
    await _repository.importBackup(sourcePath);
    await loadHome();
  }

  Future<void> _grantXp(String studentId, int value) async {
    final current = await _repository.reward(studentId);
    if (current == null) return;
    final xp = current.xp + value;
    final badges = current.badges.isEmpty && xp >= 50
        ? 'ط·آ¨ط·آ¯ط·آ§ط¸ظ¹ط·آ© ط¸â€ڑط¸ث†ط¸ظ¹ط·آ©'
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
        'ط·آ§ط¸â€‍ط·ع¾ط¸â€ڑط·آ§ط·آ±ط¸ظ¹ط·آ± ط·آ§ط¸â€‍ط·آ±ط·آ³ط¸â€¦ط¸ظ¹ط·آ© ط¸ظ¹ط·آµط·آ¯ط·آ±ط¸â€،ط·آ§ ط·آ§ط¸â€‍ط¸â€¦ط·آ±ط¸ئ’ط·آ² ط¸ظ¾ط¸â€ڑط·آ·.');
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
        action: 'ط·آ·ط·آ¨ط·آ§ط·آ¹ط·آ© ط·ع¾ط¸â€ڑط·آ±ط¸ظ¹ط·آ±',
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

  String recommendationFor({required String errorType, required int severity}) {
    if (severity >= 4) {
      return 'ط¸ظ¹ط¸ث†ط·آµط¸â€° ط·آ¨ط·ع¾ط¸ئ’ط·آ«ط¸ظ¹ط¸ظ¾ ط·آ§ط¸â€‍ط·ع¾ط·آ¯ط·آ±ط¸ظ¹ط·آ¨ ط·آ§ط¸â€‍ط·آ³ط¸â€¦ط·آ¹ط¸ظ¹ ط¸ث†ط·آ§ط¸â€‍ط·آ¨ط·آµط·آ±ط¸ظ¹ ط¸ث†ط·ع¾ط¸â€ڑط·آ³ط¸ظ¹ط¸â€¦ ط·آ§ط¸â€‍ط¸â€،ط·آ¯ط¸ظ¾ ط·آ¥ط¸â€‍ط¸â€° ط·آ®ط·آ·ط¸ث†ط·آ§ط·ع¾ ط¸â€ڑط·آµط¸ظ¹ط·آ±ط·آ©.';
    }
    if (errorType == 'ط·آ¥ط·آ¨ط·آ¯ط·آ§ط¸â€‍') {
      return 'ط¸ظ¹ط¸ث†ط·آµط¸â€° ط·آ¨ط·ع¾ط¸â€¦ط¸ظ¹ط¸ظ¹ط·آ² ط·آµط¸ث†ط·ع¾ ط·آ§ط¸â€‍ط·آ­ط·آ±ط¸ظ¾ ط·آ§ط¸â€‍ط¸â€¦ط·آ³ط·ع¾ط¸â€،ط·آ¯ط¸ظ¾ ط·آ¹ط¸â€  ط·آ§ط¸â€‍ط·آ­ط·آ±ط¸ظ¾ ط·آ§ط¸â€‍ط·آ¨ط·آ¯ط¸ظ¹ط¸â€‍ ط·آ¯ط·آ§ط·آ®ط¸â€‍ ط¸ئ’ط¸â€‍ط¸â€¦ط·آ§ط·ع¾ ط¸â€ڑط·آµط¸ظ¹ط·آ±ط·آ©.';
    }
    if (errorType == 'ط·آ­ط·آ°ط¸ظ¾') {
      return 'ط¸ظ¹ط¸ث†ط·آµط¸â€° ط·آ¨ط·ع¾ط¸â€¦ط·آ§ط·آ±ط¸ظ¹ط¸â€  ط·آ¥ط·آ·ط·آ§ط¸â€‍ط·آ© ط·آ§ط¸â€‍ط·آµط¸ث†ط·ع¾ ط¸ث†ط·ع¾ط·آ«ط·آ¨ط¸ظ¹ط·ع¾ ط¸â€¦ط¸ث†ط·آ¶ط·آ¹ ط·آ§ط¸â€‍ط·آ­ط·آ±ط¸ظ¾ ط¸ظ¾ط¸ظ¹ ط·آ§ط¸â€‍ط¸ئ’ط¸â€‍ط¸â€¦ط·آ©.';
    }
    if (errorType == 'ط·ع¾ط·آ´ط¸ث†ط¸ظ¹ط¸â€،') {
      return 'ط¸ظ¹ط¸ث†ط·آµط¸â€° ط·آ¨ط·ع¾ط·آ¯ط·آ±ط¸ظ¹ط·آ¨ ط¸â€¦ط¸ث†ط·آ¶ط·آ¹ ط·آ§ط¸â€‍ط¸â€‍ط·آ³ط·آ§ط¸â€  ط¸ث†ط·آ§ط¸â€‍ط·آ´ط¸ظ¾ط·آ§ط¸â€، ط·آ£ط¸â€¦ط·آ§ط¸â€¦ ط¸â€¦ط·آ±ط·آ¢ط·آ© ط¸â€¦ط·آ¹ ط·ع¾ط·ط›ط·آ°ط¸ظ¹ط·آ© ط·آ±ط·آ§ط·آ¬ط·آ¹ط·آ© ط¸ظ¾ط¸ث†ط·آ±ط¸ظ¹ط·آ©.';
    }
    return 'ط¸ظ¹ط¸ث†ط·آµط¸â€° ط·آ¨ط·ع¾ط¸ئ’ط·آ±ط·آ§ط·آ± ط·آ§ط¸â€‍ط¸â€،ط·آ¯ط¸ظ¾ ط·آ¯ط·آ§ط·آ®ط¸â€‍ ط·آ¬ط¸â€¦ط¸â€‍ ط¸ث†ط·آ¸ط¸ظ¹ط¸ظ¾ط¸ظ¹ط·آ© ط¸â€ڑط·آµط¸ظ¹ط·آ±ط·آ©.';
  }

  int get _improvementRate {
    if (evaluations.isEmpty) return 0;
    final good = evaluations
        .where((item) =>
            item.score == 'ط·آµط·آ­ط¸ظ¹ط·آ­' ||
            item.score == 'ط¸â€ ط·آ§ط·آ¬ط·آ­')
        .length;
    final partial =
        evaluations.where((item) => item.score == 'ط·آ¬ط·آ²ط·آ¦ط¸ظ¹').length;
    return (((good + partial * .5) / evaluations.length) * 100).round();
  }

  AppUser _requireUser() {
    final current = user;
    if (current == null) {
      throw StateError(
          'ط¸ظ¹ط·آ¬ط·آ¨ ط·ع¾ط·آ³ط·آ¬ط¸ظ¹ط¸â€‍ ط·آ§ط¸â€‍ط·آ¯ط·آ®ط¸ث†ط¸â€‍ ط·آ£ط¸ث†ط¸â€‍ط¸â€¹ط·آ§.');
    }
    return current;
  }

  void _ensure(bool allowed, String message) {
    if (!allowed) throw StateError(message);
  }

  void _ensureClinicalAccess(String studentId, String centerId) {
    _ensure(centerId == activeCenterId,
        'ط¸â€‍ط·آ§ ط¸ظ¹ط¸â€¦ط¸ئ’ط¸â€  ط·ع¾ط¸â€ ط¸ظ¾ط¸ظ¹ط·آ° ط·آ§ط¸â€‍ط·آ¹ط¸â€¦ط¸â€‍ط¸ظ¹ط·آ© ط·آ®ط·آ§ط·آ±ط·آ¬ ط¸â€¦ط·آ±ط¸ئ’ط·آ²ط¸ئ’.');
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
          'ط¸â€‍ط·آ§ ط¸ظ¹ط¸â€¦ط¸ئ’ط¸â€  ط·آ§ط¸â€‍ط¸ث†ط·آµط¸ث†ط¸â€‍ ط¸â€‍ط·آ¨ط¸ظ¹ط·آ§ط¸â€ ط·آ§ط·ع¾ ط¸â€¦ط·آ±ط¸ئ’ط·آ² ط·آ¢ط·آ®ط·آ±.');
    }
    if (isParent) {
      _ensure(user?.studentId == studentId,
          'ط¸ث†ط¸â€‍ط¸ظ¹ ط·آ§ط¸â€‍ط·آ£ط¸â€¦ط·آ± ط¸ظ¹ط·آ±ط¸â€° ط·آ¨ط¸ظ¹ط·آ§ط¸â€ ط·آ§ط·ع¾ ط·آ·ط¸ظ¾ط¸â€‍ط¸â€، ط¸ظ¾ط¸â€ڑط·آ·.');
    }
  }

  void _ensureStudentAccess(Student student) {
    final current = _requireUser();
    if (current.role == UserRole.sanadOwner) return;
    if (current.role == UserRole.parent && current.studentId == student.id) {
      return;
    }
    if ((current.role == UserRole.centerManager ||
            current.role == UserRole.specialist ||
            current.role == UserRole.dataEntry) &&
        current.centerId == student.centerId) {
      return;
    }
    throw StateError(
        'ط¸â€‍ط·آ§ ط·ع¾ط¸â€¦ط¸â€‍ط¸ئ’ ط·آµط¸â€‍ط·آ§ط·آ­ط¸ظ¹ط·آ© ط·آ§ط¸â€‍ط¸ث†ط·آµط¸ث†ط¸â€‍ ط¸â€‍ط¸â€،ط·آ°ط·آ§ ط·آ§ط¸â€‍ط·آ·ط·آ§ط¸â€‍ط·آ¨.');
  }

  Future<void> _log(
      {required String action,
      required String entityType,
      required String entityId,
      String centerId = '',
      String details = ''}) async {
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
