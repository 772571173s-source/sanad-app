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
      throw StateError('تم إعداد النظام مسبقًا.');
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
            'تم إيقاف خدمات هذا المركز مؤقتًا.\nيرجى التواصل مع خدمة العملاء أو إدارة سند.');
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

  Future<void> deleteCenter(String id) => _db.deleteCenter(id);

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

  Future<List<Student>> studentsForParent(AppUser parent) async {
    final rows = await _db.where('students',
        where:
            'center_id = ? AND (parent_phone = ? OR portal_email = ?) AND deleted_at = ?',
        whereArgs: [parent.centerId, parent.email, parent.email, ''],
        orderBy: 'name');
    return rows.map(Student.fromMap).toList();
  }

  Future<void> saveStudent(Student student) async {
    final parentUsername = student.parentPhone.trim().isNotEmpty
        ? student.parentPhone.trim()
        : student.portalEmail.trim();
    final existingParentAccount = await userByEmail(parentUsername);
    if (existingParentAccount != null &&
        existingParentAccount.role != UserRole.parent) {
      throw StateError('رقم ولي الأمر مستخدم مسبقًا لحساب غير ولي أمر.');
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
        portalEmail: parentUsername,
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
        email: parentUsername,
      ).toMap(),
    );

    final initialPassword = student.portalPassword.trim().isNotEmpty
        ? student.portalPassword.trim()
        : parentUsername;
    final isNewParent = existingParentAccount == null;
    if (isNewParent || student.portalPassword.isNotEmpty) {
      await _db.upsert(
        'users',
        AppUser(
          id: existingParentAccount?.id ??
              'parent_${parentUsername.hashCode.abs()}',
          centerId: student.centerId,
          email: parentUsername,
          passwordHash: existingParentAccount?.passwordHash ??
              AuthService.hashPassword(initialPassword),
          name: student.parentName.isEmpty
              ? '??? ??? ${student.name}'
              : student.parentName,
          role: UserRole.parent,
          studentId: existingParentAccount?.studentId,
          forcePasswordChange:
              existingParentAccount?.forcePasswordChange ?? true,
          isDemo: existingParentAccount?.isDemo ?? false,
        ).toMap(),
      );
    } else {
      await _db.updateWhere(
        'users',
        {
          'center_id': student.centerId,
          'email': parentUsername,
          'name': student.parentName.isEmpty
              ? '??? ??? ${student.name}'
              : student.parentName,
          if (existingParentAccount.studentId == null) 'student_id': null,
        },
        'id = ?',
        [existingParentAccount.id],
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
        'status': 'محذوف',
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

  Future<void> saveSessionSkillResult(SessionSkillResult result) =>
      _db.upsert('session_skill_results', result.toMap());

  Future<List<SessionSkillResult>> sessionSkillResults(
          String sessionId) async =>
      (await _db.where('session_skill_results',
              where: 'session_id = ?', whereArgs: [sessionId]))
          .map(SessionSkillResult.fromMap)
          .toList();

  Future<List<SessionSkillResult>> sessionSkillResultsForGoal(
          String planId) async =>
      (await _db.where('session_skill_results',
              where: 'goal_id = ?',
              whereArgs: [planId],
              orderBy: 'created_at DESC'))
          .map(SessionSkillResult.fromMap)
          .toList();

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

  Future<List<TrainingPlan>> plansForProgram(
      String studentId, String programId) async {
    final rows = await _db.where('training_plans',
        where: 'student_id = ? AND program_id = ?',
        whereArgs: [studentId, programId],
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

  Future<List<GoalSkillStep>> goalStepsForProgramAndSource(
      String studentId, String programId, String sourceType) async {
    final rows = await _db.where('goal_skill_steps',
        where: 'student_id = ? AND program_id = ? AND source_type = ?',
        whereArgs: [studentId, programId, sourceType],
        orderBy: 'goal_id, sort_order');
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

  Future<List<TherapyProgramTemplate>> therapyProgramTemplates(
      String centerId) async {
    final rows = await _db.where(
      'therapy_program_templates',
      where: centerId.isEmpty
          ? 'center_id = ?'
          : '(center_id = ? OR center_id = ?)',
      whereArgs: centerId.isEmpty ? [''] : ['', centerId],
      orderBy: 'center_id, sort_order, created_at',
    );
    // Deduplicate by name: when multiple programs have the same name,
    // keep the global one (center_id = '') over a center-specific one.
    final seen = <String, TherapyProgramTemplate>{};
    for (final row in rows) {
      final program = TherapyProgramTemplate.fromMap(row);
      final existing = seen[program.name];
      if (existing == null || program.centerId.isEmpty) {
        seen[program.name] = program;
      }
    }
    return seen.values.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  Future<void> saveTherapyProgramTemplate(TherapyProgramTemplate program) =>
      _db.upsert('therapy_program_templates', program.toMap());

  Future<void> deleteTherapyProgramTemplate(String id) async {
    final sections = await _db.where('assessment_section_templates',
        where: 'program_id = ?', whereArgs: [id]);
    for (final section in sections) {
      await deleteAssessmentSectionTemplate(section['id'] as String);
    }
    final sounds = await _db.where('speech_sound_trigger_templates',
        where: 'program_id = ?', whereArgs: [id]);
    for (final sound in sounds) {
      await deleteSpeechSoundTriggerTemplate(sound['id'] as String);
    }
    await _db.delete('therapy_program_templates', id);
  }

  Future<List<AssessmentSectionTemplate>> assessmentSectionTemplates(
      String centerId) async {
    final rows = await _db.where(
      'assessment_section_templates',
      where: centerId.isEmpty
          ? 'center_id = ?'
          : '(center_id = ? OR center_id = ?)',
      whereArgs: centerId.isEmpty ? [''] : ['', centerId],
      orderBy: 'center_id, sort_order, created_at',
    );
    return rows.map(AssessmentSectionTemplate.fromMap).toList();
  }

  Future<List<AssessmentItemTemplate>> assessmentItemTemplates(
      String centerId) async {
    final rows = await _db.where(
      'assessment_item_templates',
      where: centerId.isEmpty
          ? 'center_id = ?'
          : '(center_id = ? OR center_id = ?)',
      whereArgs: centerId.isEmpty ? [''] : ['', centerId],
      orderBy: 'center_id, sort_order, created_at',
    );
    return rows.map(AssessmentItemTemplate.fromMap).toList();
  }

  Future<List<AssessmentOptionTemplate>> assessmentOptionTemplates(
      String centerId) async {
    final rows = await _db.where(
      'assessment_option_templates',
      where: centerId.isEmpty
          ? 'center_id = ?'
          : '(center_id = ? OR center_id = ?)',
      whereArgs: centerId.isEmpty ? [''] : ['', centerId],
      orderBy: 'center_id, sort_order, created_at',
    );
    return rows.map(AssessmentOptionTemplate.fromMap).toList();
  }

  Future<List<SkillStepTemplate>> skillStepTemplates(String centerId) async {
    final rows = await _db.where(
      'skill_step_templates',
      where: centerId.isEmpty
          ? 'center_id = ?'
          : '(center_id = ? OR center_id = ?)',
      whereArgs: centerId.isEmpty ? [''] : ['', centerId],
      orderBy: 'center_id, owner_type, owner_id, sort_order, created_at',
    );
    return rows.map(SkillStepTemplate.fromMap).toList();
  }

  Future<List<SpeechSoundTriggerTemplate>> speechSoundTriggerTemplates(
      String centerId) async {
    final rows = await _db.where(
      'speech_sound_trigger_templates',
      where: centerId.isEmpty
          ? 'center_id = ?'
          : '(center_id = ? OR center_id = ?)',
      whereArgs: centerId.isEmpty ? [''] : ['', centerId],
      orderBy: 'center_id, sort_order, letter, error_type, position',
    );
    return rows.map(SpeechSoundTriggerTemplate.fromMap).toList();
  }

  Future<void> saveAssessmentSectionTemplate(
          AssessmentSectionTemplate section) =>
      _db.upsert('assessment_section_templates', section.toMap());

  Future<void> saveAssessmentItemTemplate(AssessmentItemTemplate item) =>
      _db.upsert('assessment_item_templates', item.toMap());

  Future<void> saveAssessmentOptionTemplate(AssessmentOptionTemplate option) =>
      _db.upsert('assessment_option_templates', option.toMap());

  Future<void> saveSkillStepTemplate(SkillStepTemplate step) =>
      _db.upsert('skill_step_templates', step.toMap());

  Future<void> saveSpeechSoundTriggerTemplate(
          SpeechSoundTriggerTemplate trigger) =>
      _db.upsert('speech_sound_trigger_templates', trigger.toMap());

  Future<void> deleteAssessmentSectionTemplate(String id) async {
    final items = await _db.where('assessment_item_templates',
        where: 'section_id = ?', whereArgs: [id]);
    for (final item in items) {
      await deleteAssessmentItemTemplate(item['id'] as String);
    }
    await _db.delete('assessment_section_templates', id);
  }

  Future<void> deleteAssessmentItemTemplate(String id) async {
    final options = await _db.where('assessment_option_templates',
        where: 'item_id = ?', whereArgs: [id]);
    for (final option in options) {
      await deleteAssessmentOptionTemplate(option['id'] as String);
    }
    await _db.delete('assessment_item_templates', id);
  }

  Future<void> deleteAssessmentOptionTemplate(String id) async {
    await _db.deleteWhere('skill_step_templates',
        'owner_type = ? AND owner_id = ?', ['option', id]);
    await _db.delete('assessment_option_templates', id);
  }

  Future<void> deleteSkillStepTemplate(String id) =>
      _db.delete('skill_step_templates', id);

  Future<void> deleteSpeechSoundTriggerTemplate(String id) async {
    await _db.deleteWhere('skill_step_templates',
        'owner_type = ? AND owner_id = ?', ['sound', id]);
    await _db.delete('speech_sound_trigger_templates', id);
  }

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

  Future<AssessmentDraft?> assessmentDraft(
      String studentId, String programId) async {
    final row = await _db.first('assessment_drafts',
        where: 'student_id = ? AND program_id = ?',
        whereArgs: [studentId, programId]);
    return row == null ? null : AssessmentDraft.fromMap(row);
  }

  Future<void> saveAssessmentDraft(AssessmentDraft draft) =>
      _db.upsert('assessment_drafts', draft.toMap());

  Future<void> deleteAssessmentDraft(String studentId, String programId) =>
      _db.deleteWhere('assessment_drafts',
          'student_id = ? AND program_id = ?', [studentId, programId]);

  Future<List<String>> studentProgramIds(String studentId) async {
    final rows = await _db.where('student_therapy_programs',
        where: 'student_id = ? AND is_active = 1',
        whereArgs: [studentId],
        orderBy: 'sort_order');
    return rows.map((row) => row['program_id'] as String).toList();
  }

  Future<List<StudentTherapyProgram>> studentTherapyPrograms({
    String? studentId,
    String? programId,
  }) async {
    if (studentId != null && programId != null) {
      final rows = await _db.where('student_therapy_programs',
          where: 'student_id = ? AND program_id = ?',
          whereArgs: [studentId, programId],
          orderBy: 'sort_order');
      return rows.map(StudentTherapyProgram.fromMap).toList();
    }
    if (studentId != null) {
      final rows = await _db.where('student_therapy_programs',
          where: 'student_id = ?',
          whereArgs: [studentId],
          orderBy: 'sort_order');
      return rows.map(StudentTherapyProgram.fromMap).toList();
    }
    final rows = await _db.all('student_therapy_programs',
        orderBy: 'sort_order');
    return rows.map(StudentTherapyProgram.fromMap).toList();
  }

  Future<void> saveStudentTherapyProgram(
      StudentTherapyProgram program) async {
    final existing = await _db.first('student_therapy_programs',
        where: 'student_id = ? AND program_id = ?',
        whereArgs: [program.studentId, program.programId]);
    if (existing != null) {
      await _db.updateWhere(
        'student_therapy_programs',
        program.toMap(),
        'id = ?',
        [existing['id']],
      );
    } else {
      await _db.upsert('student_therapy_programs', program.toMap());
    }
  }

  Future<void> removeStudentTherapyProgram(
      String studentId, String programId) async {
    await _db.deleteWhere('student_therapy_programs',
        'student_id = ? AND program_id = ?', [studentId, programId]);
  }

  // ── Student Program Assignments ──────────────────────────────────

  Future<List<StudentProgramAssignment>> studentProgramAssignments() async {
    final rows = await _db.all('student_program_assignments',
        orderBy: 'assigned_at DESC');
    return rows.map(StudentProgramAssignment.fromMap).toList();
  }

  Future<List<StudentProgramAssignment>> activeAssignmentsForStudent(
      String studentId) async {
    final rows = await _db.where('student_program_assignments',
        where: 'student_id = ? AND status = ?',
        whereArgs: [studentId, 'active']);
    return rows.map(StudentProgramAssignment.fromMap).toList();
  }

  Future<List<StudentProgramAssignment>> activeAssignmentsForStudentByProgram(
      String studentId, String programId) async {
    final rows = await _db.where('student_program_assignments',
        where: 'student_id = ? AND program_id = ? AND status = ?',
        whereArgs: [studentId, programId, 'active']);
    return rows.map(StudentProgramAssignment.fromMap).toList();
  }

  Future<List<StudentProgramAssignment>> activeAssignmentsForSpecialist(
      String specialistId) async {
    final rows = await _db.where('student_program_assignments',
        where: 'specialist_id = ? AND status = ?',
        whereArgs: [specialistId, 'active']);
    return rows.map(StudentProgramAssignment.fromMap).toList();
  }

  Future<List<StudentProgramAssignment>>
      activeAssignmentsForSpecialistByProgram(
          String specialistId, String programId) async {
    final rows = await _db.where('student_program_assignments',
        where: 'specialist_id = ? AND program_id = ? AND status = ?',
        whereArgs: [specialistId, programId, 'active']);
    return rows.map(StudentProgramAssignment.fromMap).toList();
  }

  Future<List<StudentProgramAssignment>> activeAssignmentsByCenter(
      String centerId) async {
    final rows = await _db.where('student_program_assignments',
        where: 'center_id = ? AND status = ?',
        whereArgs: [centerId, 'active']);
    return rows.map(StudentProgramAssignment.fromMap).toList();
  }

  Future<StudentProgramAssignment?> getActivePrimaryAssignment(
      String studentId, String programId) async {
    final row = await _db.first('student_program_assignments',
        where: 'student_id = ? AND program_id = ? AND status = ? AND role = ?',
        whereArgs: [studentId, programId, 'active', 'primary']);
    return row != null ? StudentProgramAssignment.fromMap(row) : null;
  }

  Future<bool> hasActivePrimaryAssignment(
      String studentId, String programId) async {
    final count = await _db.countWhere('student_program_assignments',
        'student_id = ? AND program_id = ? AND status = ? AND role = ?',
        [studentId, programId, 'active', 'primary']);
    return count > 0;
  }

  Future<StudentProgramAssignment?> getAssignmentById(String id) async {
    final row = await _db.first('student_program_assignments',
        where: 'id = ?', whereArgs: [id]);
    return row != null ? StudentProgramAssignment.fromMap(row) : null;
  }

  Future<List<StudentProgramAssignment>> assignmentsForStudent(
      String studentId) async {
    final rows = await _db.where('student_program_assignments',
        where: 'student_id = ?', whereArgs: [studentId],
        orderBy: 'assigned_at DESC');
    return rows.map(StudentProgramAssignment.fromMap).toList();
  }

  /// Creates a new active assignment.
  /// Throws if:
  /// - The specialist has no active capability for (center_id, program_id).
  /// - An active primary assignment already exists for the same
  ///   (student_id + program_id).
  Future<void> assignProgramToSpecialist(
      StudentProgramAssignment assignment) async {
    final cap = await capabilityBySpecialistAndProgram(
        assignment.specialistId, assignment.programId);
    if (cap == null || !cap.isActive) {
      throw StateError(
          'الأخصائي غير مؤهل لهذا البرنامج. يرجى ربط الأخصائي بالبرنامج أولاً من شاشة الموظفين.');
    }
    if (assignment.role == 'primary') {
      final conflict = await hasActivePrimaryAssignment(
          assignment.studentId, assignment.programId);
      if (conflict) {
        throw StateError(
            'يوجد إسناد نشط بالفعل لهذا الطالب والبرنامج. استخدم replaceSpecialistForProgram لاستبدال الأخصائي.');
      }
    }
    await _db.upsert('student_program_assignments', assignment.toMap());
  }

  /// Deactivates the current active primary assignment for
  /// (studentId, programId) and creates a new active assignment for the new
  /// specialist. Logs both actions in audit_logs.
  Future<void> replaceSpecialistForProgram({
    required String studentId,
    required String programId,
    required String newSpecialistId,
    required String centerId,
    required String userId,
    required String userName,
    required String newAssignmentId,
    String notes = '',
  }) async {
    final old = await getActivePrimaryAssignment(studentId, programId);
    if (old != null) {
      await _db.updateWhere(
        'student_program_assignments',
        {'status': 'inactive'},
        'id = ?',
        [old.id],
      );
      await _db.upsert('audit_logs', {
        'id': 'audit_${DateTime.now().millisecondsSinceEpoch}_deact',
        'center_id': centerId,
        'user_id': userId,
        'user_name': userName,
        'action': 'deactivate_assignment',
        'entity_type': 'student_program_assignment',
        'entity_id': old.id,
        'details': 'إلغاء إسناد الطالب $studentId من الأخصائي '
            '${old.specialistId} للبرنامج $programId',
        'created_at': DateTime.now().toIso8601String(),
      });
    }
    final newAssignment = StudentProgramAssignment(
      id: newAssignmentId,
      centerId: centerId,
      studentId: studentId,
      programId: programId,
      specialistId: newSpecialistId,
      role: 'primary',
      status: 'active',
      notes: notes,
      assignedByUserId: userId,
      assignedAt: DateTime.now().toIso8601String(),
    );
    await _db.upsert('student_program_assignments', newAssignment.toMap());
    await _db.upsert('audit_logs', {
      'id': 'audit_${DateTime.now().millisecondsSinceEpoch}_assign',
      'center_id': centerId,
      'user_id': userId,
      'user_name': userName,
      'action': 'assign_program_to_specialist',
      'entity_type': 'student_program_assignment',
      'entity_id': newAssignment.id,
      'details': 'إسناد الطالب $studentId إلى الأخصائي $newSpecialistId '
          'للبرنامج $programId',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Sets an assignment status to 'inactive'.
  Future<void> deactivateAssignment(String id) async {
    await _db.updateWhere(
      'student_program_assignments',
      {'status': 'inactive'},
      'id = ?',
      [id],
    );
  }

  /// Reactivates an inactive assignment.
  /// Throws if there is already an active primary assignment for the same
  /// (student_id + program_id).
  Future<void> reactivateAssignment(String id) async {
    final assignment = await getAssignmentById(id);
    if (assignment == null) {
      throw StateError('الإسناد غير موجود.');
    }
    if (assignment.status == 'active') {
      return; // already active, no-op
    }
    if (assignment.role == 'primary') {
      final conflict = await hasActivePrimaryAssignment(
          assignment.studentId, assignment.programId);
      if (conflict) {
        throw StateError(
            'لا يمكن إعادة التفعيل، يوجد إسناد نشط آخر لنفس الطالب والبرنامج.');
      }
    }
    await _db.updateWhere(
      'student_program_assignments',
      {'status': 'active'},
      'id = ?',
      [id],
    );
  }

  /// Returns student IDs assigned to a specialist via the new table.
  Future<List<String>> studentIdsForSpecialist(String specialistId) async {
    final rows = await activeAssignmentsForSpecialist(specialistId);
    return rows.map((a) => a.studentId).toSet().toList();
  }

  Future<List<StudentFollowup>> studentFollowups(String studentId) async {
    final rows = await _db.where('student_followups',
        where: 'student_id = ?', whereArgs: [studentId],
        orderBy: 'created_at DESC');
    return rows.map(StudentFollowup.fromMap).toList();
  }

  Future<StudentFollowup?> pendingFollowupForStep(
      String studentId, String goalSkillStepId) async {
    final row = await _db.first('student_followups',
        where: 'student_id = ? AND goal_skill_step_id = ? AND status = ?',
        whereArgs: [studentId, goalSkillStepId, 'pending']);
    return row != null ? StudentFollowup.fromMap(row) : null;
  }

  Future<void> saveStudentFollowup(StudentFollowup followup) async {
    final existing = await _db.first('student_followups',
        where:
            'student_id = ? AND goal_skill_step_id = ? AND status = ?',
        whereArgs: [
          followup.studentId,
          followup.goalSkillStepId,
          'pending'
        ]);
    if (existing != null) {
      await _db.updateWhere('student_followups', followup.toMap(),
          'id = ?', [existing['id']]);
    } else {
      await _db.upsert('student_followups', followup.toMap());
    }
  }

  Future<void> resolveFollowupForStep(
      String studentId, String goalSkillStepId) async {
    final existing = await _db.first('student_followups',
        where:
            'student_id = ? AND goal_skill_step_id = ? AND status = ?',
        whereArgs: [studentId, goalSkillStepId, 'pending']);
    if (existing == null) return;
    final now = DateTime.now().toIso8601String();
    await _db.updateWhere('student_followups', {
      'status': 'completed',
      'resolved_at': now,
    }, 'id = ?', [existing['id']]);
  }

  Future<void> resolveFollowupsByPlan(String planId) async {
    await _db.updateWhere(
      'student_followups',
      {'status': 'resolved', 'resolved_at': DateTime.now().toIso8601String()},
      'plan_id = ? AND status = ?',
      [planId, 'pending'],
    );
  }

  Future<StudentFollowup?> pendingFollowupForPlan(String planId) async {
    final row = await _db.first('student_followups',
        where: 'plan_id = ? AND goal_skill_step_id = ? AND status = ?',
        whereArgs: [planId, '', 'pending']);
    return row != null ? StudentFollowup.fromMap(row) : null;
  }

  // ---- Specialist Program Capabilities ----

  Future<List<SpecialistProgramCapability>> capabilitiesForSpecialist(
      String specialistId) async {
    final rows = await _db.where('specialist_program_capabilities',
        where: 'specialist_id = ?', whereArgs: [specialistId]);
    return rows.map(SpecialistProgramCapability.fromMap).toList();
  }

  Future<List<SpecialistProgramCapability>> activeCapabilitiesForSpecialist(
      String specialistId) async {
    final rows = await _db.where('specialist_program_capabilities',
        where: 'specialist_id = ? AND status = ?',
        whereArgs: [specialistId, 'active']);
    return rows.map(SpecialistProgramCapability.fromMap).toList();
  }

  Future<List<SpecialistProgramCapability>> capabilitiesForProgram(
      String programId) async {
    final rows = await _db.where('specialist_program_capabilities',
        where: 'program_id = ? AND status = ?',
        whereArgs: [programId, 'active']);
    return rows.map(SpecialistProgramCapability.fromMap).toList();
  }

  Future<List<SpecialistProgramCapability>>
      activeCapabilitiesByCenter(String centerId) async {
    final rows = await _db.where('specialist_program_capabilities',
        where: 'center_id = ? AND status = ?',
        whereArgs: [centerId, 'active']);
    return rows.map(SpecialistProgramCapability.fromMap).toList();
  }

  Future<SpecialistProgramCapability?> capabilityBySpecialistAndProgram(
      String specialistId, String programId) async {
    final row = await _db.first('specialist_program_capabilities',
        where: 'specialist_id = ? AND program_id = ?',
        whereArgs: [specialistId, programId]);
    return row != null ? SpecialistProgramCapability.fromMap(row) : null;
  }

  Future<bool> hasCapability(
      String specialistId, String programId) async {
    final cap = await capabilityBySpecialistAndProgram(
        specialistId, programId);
    return cap != null && cap.isActive;
  }

  Future<void> saveCapability(
      SpecialistProgramCapability capability) async {
    await _db.upsert(
        'specialist_program_capabilities', capability.toMap());
  }

  Future<void> removeCapability(String id) async {
    await _db.delete('specialist_program_capabilities', id);
  }

  Future<void> setCapabilitiesForSpecialist(
    String specialistId,
    String centerId,
    String userId,
    List<String> programIds,
  ) async {
    final existing =
        await capabilitiesForSpecialist(specialistId);
    final existingMap = {
      for (final c in existing) c.programId: c
    };
    final now = DateTime.now().toIso8601String();

    // Remove capabilities for programs no longer selected
    for (final cap in existing) {
      if (!programIds.contains(cap.programId)) {
        await removeCapability(cap.id);
      }
    }

    // Add capabilities for newly selected programs
    for (final programId in programIds) {
      if (!existingMap.containsKey(programId)) {
        await saveCapability(SpecialistProgramCapability(
          id: 'cap_${DateTime.now().millisecondsSinceEpoch}_$programId',
          centerId: centerId,
          specialistId: specialistId,
          programId: programId,
          status: 'active',
          createdByUserId: userId,
          createdAt: now,
          updatedAt: now,
        ));
      }
    }
  }

  // ---- End Specialist Program Capabilities ----

  Future<void> exportBackup(String targetPath) => _db.exportBackup(targetPath);

  Future<Map<String, dynamic>> exportCenterBackup(String centerId) =>
      _db.exportCenterBackup(centerId);

  Future<void> saveCenterBackupToFile(
          Map<String, dynamic> backup, String targetPath) =>
      _db.saveCenterBackupToFile(backup, targetPath);

  Future<Map<String, dynamic>> loadCenterBackupFromFile(String sourcePath) =>
      _db.loadCenterBackupFromFile(sourcePath);

  Future<void> importCenterBackup(Map<String, dynamic> backup) =>
      _db.importCenterBackup(backup);

  Future<void> importBackup(String sourcePath) => _db.importBackup(sourcePath);

  Future<void> resetLocalDatabase() => _db.resetLocalDatabase();
}
