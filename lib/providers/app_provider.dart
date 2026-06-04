import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../repositories/sanad_repository.dart';
import '../services/pdf_service.dart';

class AppProvider extends ChangeNotifier {
  AppProvider(this._repository, this._pdfService);

  final SanadRepository _repository;
  final PdfService _pdfService;

  AppUser? user;
  SanadCenter? currentCenter;
  List<SanadCenter> centers = [];
  List<AppUser> staff = [];
  List<Student> students = [];
  Student? selectedStudent;
  List<TherapySession> sessions = [];
  List<Evaluation> evaluations = [];
  List<TrainingPlan> plans = [];
  List<Exercise> exercises = [];
  List<ReportRecord> reports = [];
  List<SignResource> signResources = [];
  Reward? reward;
  bool loading = false;
  bool darkMode = false;

  bool get isOwner => user?.role == UserRole.sanadOwner;
  bool get isAdmin => user?.role == UserRole.admin;
  bool get isSpecialist => user?.role == UserRole.specialist;
  bool get isParent => user?.role == UserRole.parent;
  bool get canManageCenters => isOwner;
  bool get canManageStaff => isOwner || isAdmin;
  bool get canManageStudents => isOwner || isAdmin || isSpecialist;
  bool get canWriteClinical => isAdmin || isSpecialist;
  bool get canWriteParentArea => isParent || canWriteClinical;
  String get activeCenterId => currentCenter?.id ?? user?.centerId ?? 'center_demo';

  Future<bool> login(String email, String password) async {
    loading = true;
    notifyListeners();
    user = await _repository.login(email.trim(), password.trim());
    if (user != null) await loadHome();
    loading = false;
    notifyListeners();
    return user != null;
  }

  Future<void> changePassword(String newPassword) async {
    final current = _requireUser();
    if (newPassword.length < 6) throw StateError('كلمة المرور يجب ألا تقل عن 6 أحرف.');
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
    exercises = [];
    reports = [];
    signResources = [];
    reward = null;
    notifyListeners();
  }

  void toggleTheme() {
    darkMode = !darkMode;
    notifyListeners();
  }

  Future<void> loadHome() async {
    final current = _requireUser();
    centers = await _repository.centers();
    currentCenter = isOwner ? (currentCenter ?? centers.firstWhere((center) => center.id == current.centerId, orElse: () => centers.first)) : centers.firstWhere((center) => center.id == current.centerId);
    staff = canManageStaff ? await _repository.users(centerId: isOwner ? null : activeCenterId) : [];
    signResources = await _repository.signResources(activeCenterId);
    students = current.role == UserRole.parent && current.studentId != null ? await _repository.studentsForParent(current.studentId!) : await _repository.students(activeCenterId);
    final currentSelection = selectedStudent;
    selectedStudent = currentSelection != null && students.any((student) => student.id == currentSelection.id) ? currentSelection : (students.isEmpty ? null : students.first);
    await selectStudent(selectedStudent);
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
      exercises = [];
      reports = [];
      reward = null;
    } else {
      sessions = await _repository.sessions(student.id);
      evaluations = await _repository.evaluations(student.id);
      plans = await _repository.plans(student.id);
      exercises = await _repository.exercises(student.id);
      reports = await _repository.reports(student.id);
      reward = await _repository.reward(student.id);
    }
    notifyListeners();
  }

  Future<void> saveCenter(SanadCenter center) async {
    _ensure(canManageCenters || (isAdmin && center.id == activeCenterId), 'ليست لديك صلاحية تعديل هذا المركز.');
    await _repository.saveCenter(center);
    await loadHome();
  }

  Future<void> saveStaffUser(AppUser account) async {
    _ensure(canManageStaff, 'إدارة الموظفين غير متاحة لهذا الحساب.');
    if (!isOwner && account.centerId != activeCenterId) throw StateError('لا يمكن إنشاء موظف خارج مركزك.');
    if (!isOwner && account.role == UserRole.sanadOwner) throw StateError('مالك النظام لا ينشئه إلا مالك النظام.');
    await _repository.saveUser(account);
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
    await loadHome();
    final saved = students.firstWhere((item) => item.id == student.id, orElse: () => centerStudent);
    selectedStudent = saved;
    notifyListeners();
    return saved;
  }

  Future<void> deleteStudent(String id) async {
    _ensure(canManageStudents, 'لا تملك صلاحية حذف الطلاب.');
    await _repository.softDeleteStudent(id);
    selectedStudent = null;
    await loadHome();
  }

  Future<void> saveSession(TherapySession session) async {
    _ensure(canWriteClinical, 'الجلسات يضيفها المدير أو الأخصائي فقط.');
    await _repository.saveSession(session);
    await _grantXp(session.studentId, session.quickResult == 'صحيح' || session.quickResult == 'ناجح' ? 12 : 6);
    await selectStudent(selectedStudent);
  }

  Future<void> saveEvaluation(Evaluation evaluation) async {
    _ensure(canWriteClinical, 'التقييم يضيفه المدير أو الأخصائي فقط.');
    await _repository.saveEvaluation(evaluation);
    await _grantXp(evaluation.studentId, evaluation.score == 'صحيح' || evaluation.score == 'ناجح' ? 8 : 4);
    await selectStudent(selectedStudent);
  }

  Future<void> savePlan(TrainingPlan plan) async {
    _ensure(canWriteClinical, 'الخطط يضيفها المدير أو الأخصائي فقط.');
    await _repository.savePlan(plan);
    await selectStudent(selectedStudent);
  }

  Future<void> saveExercise(Exercise exercise) async {
    _ensure(canWriteParentArea, 'لا تملك صلاحية تعديل واجبات هذا الطالب.');
    await _repository.saveExercise(exercise);
    await selectStudent(selectedStudent);
  }

  Future<void> saveReward(Reward reward) async {
    _ensure(canWriteClinical, 'المكافآت يعدلها المركز فقط.');
    await _repository.saveReward(reward);
    await selectStudent(selectedStudent);
  }

  Future<void> saveSignResource(SignResource resource) async {
    _ensure(canWriteClinical, 'مكتبة الإشارة يعدلها المركز فقط.');
    await _repository.saveSignResource(resource);
    signResources = await _repository.signResources(activeCenterId);
    notifyListeners();
  }

  Future<void> deleteSignResource(String id) async {
    _ensure(canWriteClinical, 'مكتبة الإشارة يعدلها المركز فقط.');
    await _repository.deleteSignResource(id);
    signResources = await _repository.signResources(activeCenterId);
    notifyListeners();
  }

  Future<void> exportBackup(String targetPath) async {
    _ensure(isOwner || isAdmin, 'النسخ الاحتياطي للمالك أو مدير المركز.');
    await _repository.exportBackup(targetPath);
  }

  Future<void> importBackup(String sourcePath) async {
    _ensure(isOwner || isAdmin, 'استيراد النسخ الاحتياطي للمالك أو مدير المركز.');
    await _repository.importBackup(sourcePath);
    await loadHome();
  }

  Future<void> _grantXp(String studentId, int value) async {
    final current = await _repository.reward(studentId);
    if (current == null) return;
    final xp = current.xp + value;
    final badges = current.badges.isEmpty && xp >= 50 ? 'بداية قوية' : current.badges;
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

  Future<void> printCredentials(Student student) => _pdfService.printStudentCredentials(student);

  Future<void> printReport(String type, String specialistSignature, String managerSignature) async {
    _ensure(canWriteClinical, 'التقارير الرسمية يصدرها المركز فقط.');
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
    if (severity >= 4) return 'يوصى بتكثيف التدريب السمعي والبصري وتقسيم الهدف إلى خطوات قصيرة.';
    if (errorType == 'إبدال') return 'يوصى بتمييز صوت الحرف المستهدف عن الحرف البديل داخل كلمات قصيرة.';
    if (errorType == 'حذف') return 'يوصى بتمارين إطالة الصوت وتثبيت موضع الحرف في الكلمة.';
    if (errorType == 'تشويه') return 'يوصى بتدريب موضع اللسان والشفاه أمام مرآة مع تغذية راجعة فورية.';
    return 'يوصى بتكرار الهدف داخل جمل وظيفية قصيرة.';
  }

  int get _improvementRate {
    if (evaluations.isEmpty) return 0;
    final good = evaluations.where((item) => item.score == 'صحيح' || item.score == 'ناجح').length;
    final partial = evaluations.where((item) => item.score == 'جزئي').length;
    return (((good + partial * .5) / evaluations.length) * 100).round();
  }

  AppUser _requireUser() {
    final current = user;
    if (current == null) throw StateError('يجب تسجيل الدخول أولًا.');
    return current;
  }

  void _ensure(bool allowed, String message) {
    if (!allowed) throw StateError(message);
  }

  void _ensureStudentAccess(Student student) {
    final current = _requireUser();
    if (current.role == UserRole.sanadOwner) return;
    if (current.role == UserRole.parent && current.studentId == student.id) return;
    if ((current.role == UserRole.admin || current.role == UserRole.specialist) && current.centerId == student.centerId) return;
    throw StateError('لا تملك صلاحية الوصول لهذا الطالب.');
  }
}
