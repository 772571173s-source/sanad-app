import '../models/app_models.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

class SanadRepository {
  SanadRepository(this._db);

  final DatabaseService _db;

  Future<bool> hasUsers() async => await _db.count('users') > 0;

  Future<void> createSystemOwner({
    required String name,
    required String email,
    required String password,
  }) async {
    if (await hasUsers()) {
      throw StateError('طھظ… ط¥ط¹ط¯ط§ط¯ ط§ظ„ظ†ط¸ط§ظ… ظ…ط³ط¨ظ‚ظ‹ط§.');
    }
    await saveUser(
      AppUser(
        id: 'owner_${DateTime.now().millisecondsSinceEpoch}',
        email: email,
        passwordHash: AuthService.hashPassword(password),
        name: name,
        role: UserRole.sanadOwner,
        centerId: '',
        forcePasswordChange: false,
        isDemo: false,
      ),
    );
  }

  Future<AppUser?> login(String email, String password) async {
    final row = await _db.first('users',
        where: 'email = ? AND is_active = 1', whereArgs: [email]);
    if (row == null) return null;
    final user = AppUser.fromMap(row);
    if (!AuthService.verifyPassword(password, user.passwordHash)) return null;
    if (user.role != UserRole.sanadOwner && user.centerId.isNotEmpty) {
      final centerRow = await _db
          .first('centers', where: 'id = ?', whereArgs: [user.centerId]);
      final center = centerRow == null ? null : SanadCenter.fromMap(centerRow);
      if (center == null || !center.isActive) {
        throw StateError(
            'طھظ… ط¥ظٹظ‚ط§ظپ ط®ط¯ظ…ط§طھ ظ‡ط°ط§ ط§ظ„ظ…ط±ظƒط² ظ…ط¤ظ‚طھظ‹ط§.\nظٹط±ط¬ظ‰ ط§ظ„طھظˆط§طµظ„ ظ…ط¹ ط®ط¯ظ…ط© ط§ظ„ط¹ظ…ظ„ط§ط، ط£ظˆ ط¥ط¯ط§ط±ط© ط³ظ†ط¯.');
      }
    }
    return user;
  }

  Future<void> changePassword(AppUser user, String newPassword) async {
    await _db.updateWhere(
      'users',
      {
        'password_hash': AuthService.hashPassword(newPassword),
        'force_password_change': 0,
      },
      'id = ?',
      [user.id],
    );
  }

  Future<void> changeUserPassword(String userId, String newPassword) async {
    await _db.updateWhere(
      'users',
      {
        'password_hash': AuthService.hashPassword(newPassword),
        'force_password_change': 1,
      },
      'id = ?',
      [userId],
    );
  }

  Future<List<SanadCenter>> centers() async {
    final rows = await _db.all('centers', orderBy: 'name');
    return rows.map(SanadCenter.fromMap).toList();
  }

  Future<void> saveCenter(SanadCenter center) =>
      _db.upsert('centers', center.toMap());

  Future<void> deleteCenter(String id) => _db.delete('centers', id);

  Future<int> totalStudents() =>
      _db.countWhere('students', 'deleted_at = ?', ['']);

  Future<int> totalSessions() => _db.count('sessions');

  Future<int> centerStudentCount(String centerId) => _db.countWhere(
      'students', 'center_id = ? AND deleted_at = ?', [centerId, '']);

  Future<int> centerSpecialistCount(String centerId) => _db.countWhere(
      'users',
      'center_id = ? AND role = ? AND is_active = 1',
      [centerId, UserRole.specialist.name]);

  Future<int> centerSessionCount(String centerId) =>
      _db.countWhere('sessions', 'center_id = ?', [centerId]);

  Future<String> centerLastActivity(String centerId) async {
    final rows = await _db.where('audit_logs',
        where: 'center_id = ?',
        whereArgs: [centerId],
        orderBy: 'created_at DESC');
    if (rows.isEmpty) return '';
    return (rows.first['created_at'] ?? '') as String;
  }

  Future<List<AppUser>> users({String? centerId}) async {
    final rows = centerId == null
        ? await _db.all('users', orderBy: 'role, name')
        : await _db.where('users',
            where: 'center_id = ?',
            whereArgs: [centerId],
            orderBy: 'role, name');
    return rows.map(AppUser.fromMap).toList();
  }

  Future<void> saveUser(AppUser user) => _db.upsert('users', user.toMap());

  Future<void> deleteUser(String id) => _db.delete('users', id);

  Future<AppUser?> userByEmail(String email) async {
    final row =
        await _db.first('users', where: 'email = ?', whereArgs: [email]);
    return row == null ? null : AppUser.fromMap(row);
  }

  Future<List<Student>> students(String centerId) async {
    final rows = await _db.where('students',
        where: 'center_id = ? AND deleted_at = ?',
        whereArgs: [centerId, ''],
        orderBy: 'name');
    return rows.map(Student.fromMap).toList();
  }

  Future<List<Student>> studentsForParent(
      String studentId, String email) async {
    final rows = await _db.where('students',
        where: '(id = ? OR portal_email = ?) AND deleted_at = ?',
        whereArgs: [studentId, email, ''],
        orderBy: 'name');
    return rows.map(Student.fromMap).toList();
  }

  Future<void> saveStudent(Student student) async {
    final existingEmailUser = await userByEmail(student.portalEmail);
    if (existingEmailUser != null &&
        existingEmailUser.role != UserRole.parent) {
      throw StateError(
          'ط±ظ‚ظ… ظˆظ„ظٹ ط§ظ„ط£ظ…ط± ظ…ط³طھط®ط¯ظ… ظ…ط³ط¨ظ‚ظ‹ط§ ظ„ط­ط³ط§ط¨ ط؛ظٹط± ظˆظ„ظٹ ط£ظ…ط±طŒ ظ„ط°ظ„ظƒ ظ„ط§ ظٹظ…ظƒظ† ط¥ظ†ط´ط§ط، ط¨ط±ظٹط¯ ظ…ظƒط±ط±.');
    }
    await _db.upsert(
      'students',
      Student(
        id: student.id,
        centerId: student.centerId,
        name: student.name,
        age: student.age,
        status: student.status,
        diagnosis: student.diagnosis,
        programType: student.programType,
        parentName: student.parentName,
        parentPhone: student.parentPhone,
        portalEmail: student.portalEmail,
        portalPassword: '',
        photoPath: student.photoPath,
        notes: student.notes,
        deletedAt: student.deletedAt,
        createdAt: student.createdAt,
        updatedAt: student.updatedAt,
      ).toMap(),
    );
    await _db.upsert(
      'parents',
      ParentProfile(
        id: 'parent_${student.id}',
        centerId: student.centerId,
        studentId: student.id,
        name: student.parentName,
        phone: student.parentPhone,
        email: student.portalEmail,
      ).toMap(),
    );
    final existingParentUser = await _db
        .first('users', where: 'student_id = ?', whereArgs: [student.id]);
    final existingAccount = existingParentUser == null
        ? existingEmailUser
        : AppUser.fromMap(existingParentUser);
    if (existingAccount == null && student.portalPassword.isEmpty) {
      throw StateError(
          'ظƒظ„ظ…ط© ظ…ط±ظˆط± ظˆظ„ظٹ ط§ظ„ط£ظ…ط± ظ…ط·ظ„ظˆط¨ط© ط¹ظ†ط¯ ط¥ظ†ط´ط§ط، ط­ط³ط§ط¨ ط¬ط¯ظٹط¯.');
    }
    if (existingAccount == null || student.portalPassword.isNotEmpty) {
      await _db.upsert(
        'users',
        AppUser(
          id: existingAccount?.id ?? 'user_${student.id}',
          centerId: student.centerId,
          email: student.portalEmail,
          passwordHash: AuthService.hashPassword(student.portalPassword),
          name: student.parentName.isEmpty
              ? 'Parent ${student.name}'
              : student.parentName,
          role: UserRole.parent,
          studentId: existingAccount?.studentId ?? student.id,
          forcePasswordChange: true,
          isDemo: false,
        ).toMap(),
      );
    } else {
      await _db.updateWhere(
        'users',
        {
          'center_id': student.centerId,
          'email': student.portalEmail,
          'name': student.parentName.isEmpty
              ? 'Parent ${student.name}'
              : student.parentName,
        },
        'id = ?',
        [existingAccount.id],
      );
    }
    if (await reward(student.id) == null) {
      await _db.upsert(
        'rewards',
        Reward(
          id: 'reward_${student.id}',
          centerId: student.centerId,
          studentId: student.id,
          xp: 0,
          level: 1,
          badges: '',
          dailyStreak: 0,
        ).toMap(),
      );
    }
  }

  Future<void> softDeleteStudent(String id) async {
    await _db.updateWhere(
      'students',
      {
        'deleted_at': DateTime.now().toIso8601String(),
        'status': 'ظ…ط­ط°ظˆظپ',
      },
      'id = ?',
      [id],
    );
  }

  Future<List<TherapySession>> sessions(String studentId) async {
    final rows = await _db.where('sessions',
        where: 'student_id = ?',
        whereArgs: [studentId],
        orderBy: 'started_at DESC');
    return rows.map(TherapySession.fromMap).toList();
  }

  Future<void> saveSession(TherapySession session) =>
      _db.upsert('sessions', session.toMap());

  Future<List<Evaluation>> evaluations(String studentId) async {
    final rows = await _db.where('evaluations',
        where: 'student_id = ?',
        whereArgs: [studentId],
        orderBy: 'created_at DESC');
    return rows.map(Evaluation.fromMap).toList();
  }

  Future<void> saveEvaluation(Evaluation evaluation) =>
      _db.upsert('evaluations', evaluation.toMap());

  Future<List<TrainingPlan>> plans(String studentId) async {
    final rows = await _db.where('training_plans',
        where: 'student_id = ?',
        whereArgs: [studentId],
        orderBy: 'target_date');
    return rows.map(TrainingPlan.fromMap).toList();
  }

  Future<void> savePlan(TrainingPlan plan) =>
      _db.upsert('training_plans', plan.toMap());

  Future<List<GoalSkillStep>> goalSkillSteps(String studentId) async {
    final rows = await _db.where('goal_skill_steps',
        where: 'student_id = ?',
        whereArgs: [studentId],
        orderBy: 'goal_id, sort_order');
    return rows.map(GoalSkillStep.fromMap).toList();
  }

  Future<List<GoalSkillStep>> goalStepsForGoal(String goalId) async {
    final rows = await _db.where('goal_skill_steps',
        where: 'goal_id = ?', whereArgs: [goalId], orderBy: 'sort_order');
    return rows.map(GoalSkillStep.fromMap).toList();
  }

  Future<void> saveGoalSkillStep(GoalSkillStep step) =>
      _db.upsert('goal_skill_steps', step.toMap());

  Future<List<Exercise>> exercises(String studentId) async {
    final rows = await _db.where('exercises',
        where: 'student_id = ?',
        whereArgs: [studentId],
        orderBy: 'due_date DESC');
    return rows.map(Exercise.fromMap).toList();
  }

  Future<void> saveExercise(Exercise exercise) =>
      _db.upsert('exercises', exercise.toMap());

  Future<Reward?> reward(String studentId) async {
    final row = await _db
        .first('rewards', where: 'student_id = ?', whereArgs: [studentId]);
    return row == null ? null : Reward.fromMap(row);
  }

  Future<void> saveReward(Reward reward) =>
      _db.upsert('rewards', reward.toMap());

  Future<List<ReportRecord>> reports(String studentId) async {
    final rows = await _db.where('reports',
        where: 'student_id = ?',
        whereArgs: [studentId],
        orderBy: 'created_at DESC');
    return rows.map(ReportRecord.fromMap).toList();
  }

  Future<void> saveReport(ReportRecord report) =>
      _db.upsert('reports', report.toMap());

  Future<List<ClinicalAssessment>> clinicalAssessments(String studentId) async {
    final rows = await _db.where('clinical_assessments',
        where: 'student_id = ?',
        whereArgs: [studentId],
        orderBy: 'created_at DESC');
    return rows.map(ClinicalAssessment.fromMap).toList();
  }

  Future<List<ClinicalFinding>> clinicalFindings(String assessmentId) async {
    final rows = await _db.where('clinical_findings',
        where: 'assessment_id = ?',
        whereArgs: [assessmentId],
        orderBy: 'domain, item_title');
    return rows.map(ClinicalFinding.fromMap).toList();
  }

  Future<void> saveClinicalAssessment(ClinicalAssessment assessment) =>
      _db.upsert('clinical_assessments', assessment.toMap());

  Future<void> saveClinicalFinding(ClinicalFinding finding) =>
      _db.upsert('clinical_findings', finding.toMap());

  Future<List<SignResource>> signResources(String centerId) async {
    final rows = await _db.where('sign_resources',
        where: 'center_id = ?',
        whereArgs: [centerId],
        orderBy: 'category, title');
    return rows.map(SignResource.fromMap).toList();
  }

  Future<void> saveSignResource(SignResource resource) =>
      _db.upsert('sign_resources', resource.toMap());

  Future<void> deleteSignResource(String id) =>
      _db.delete('sign_resources', id);

  Future<List<AuditLog>> auditLogs(
      {String? centerId, String? studentId}) async {
    final rows = centerId == null
        ? await _db.all('audit_logs', orderBy: 'created_at DESC')
        : await _db.where('audit_logs',
            where: 'center_id = ?',
            whereArgs: [centerId],
            orderBy: 'created_at DESC');
    return rows
        .map(AuditLog.fromMap)
        .where((log) =>
            studentId == null ||
            log.entityId == studentId ||
            log.details.contains(studentId))
        .toList();
  }

  Future<void> saveAuditLog(AuditLog log) =>
      _db.upsert('audit_logs', log.toMap());

  Future<void> exportBackup(String targetPath) => _db.exportBackup(targetPath);

  Future<void> importBackup(String sourcePath) => _db.importBackup(sourcePath);

  Future<void> resetLocalDatabase() => _db.resetLocalDatabase();
}
