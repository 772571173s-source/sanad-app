import 'dart:convert';

enum UserRole {
  sanadOwner,
  centerManager,
  clinicalSupervisor,
  therapyProgramEntry,
  coordinator,
  specialist,
  dataEntry,
  parent
}

enum AppPermission {
  manageSystem,
  manageCenters,
  manageSubscriptions,
  manageCenterStaff,
  manageCenterPermissions,
  viewStudents,
  manageStudents,
  assignStudents,
  viewReports,
  writeReports,
  viewClinicalAssessments,
  writeClinicalAssessments,
  manageTherapyStructure,
  runSessions,
  updateGoalProgress,
  createHomework,
  parentFollowUp,
}

extension UserRoleX on UserRole {
  String get label {
    switch (this) {
      case UserRole.sanadOwner:
        return 'مالك سند';
      case UserRole.centerManager:
        return 'مدير مركز';
      case UserRole.clinicalSupervisor:
        return 'مشرف فني';
      case UserRole.therapyProgramEntry:
        return 'مدخل البرامج العلاجية';
      case UserRole.coordinator:
        return 'منسق';
      case UserRole.specialist:
        return 'أخصائي';
      case UserRole.dataEntry:
        return 'مدخل بيانات / سكرتارية';
      case UserRole.parent:
        return 'ولي أمر';
    }
  }

  Set<AppPermission> get permissions {
    switch (this) {
      case UserRole.sanadOwner:
        return {
          AppPermission.manageSystem,
          AppPermission.manageCenters,
          AppPermission.manageSubscriptions,
          AppPermission.manageCenterStaff,
          AppPermission.manageCenterPermissions,
          AppPermission.viewStudents,
          AppPermission.manageStudents,
          AppPermission.assignStudents,
          AppPermission.viewReports,
          AppPermission.writeReports,
          AppPermission.viewClinicalAssessments,
          AppPermission.writeClinicalAssessments,
          AppPermission.manageTherapyStructure,
          AppPermission.runSessions,
          AppPermission.updateGoalProgress,
          AppPermission.createHomework,
        };
      case UserRole.centerManager:
        return {
          AppPermission.manageCenterStaff,
          AppPermission.manageCenterPermissions,
          AppPermission.viewStudents,
          AppPermission.manageStudents,
          AppPermission.viewReports,
          AppPermission.viewClinicalAssessments,
          AppPermission.manageTherapyStructure,
        };
      case UserRole.clinicalSupervisor:
        return {
          AppPermission.viewStudents,
          AppPermission.viewReports,
          AppPermission.viewClinicalAssessments,
          AppPermission.writeClinicalAssessments,
          AppPermission.manageTherapyStructure,
          AppPermission.assignStudents,
        };
      case UserRole.therapyProgramEntry:
        return {AppPermission.manageTherapyStructure};
      case UserRole.coordinator:
        return {
          AppPermission.viewStudents,
          AppPermission.assignStudents,
        };
      case UserRole.dataEntry:
        return {
          AppPermission.viewStudents,
          AppPermission.manageStudents,
        };
      case UserRole.specialist:
        return {
          AppPermission.viewStudents,
          AppPermission.viewReports,
          AppPermission.writeReports,
          AppPermission.viewClinicalAssessments,
          AppPermission.writeClinicalAssessments,
          AppPermission.runSessions,
          AppPermission.updateGoalProgress,
          AppPermission.createHomework,
        };
      case UserRole.parent:
        return {
          AppPermission.parentFollowUp,
          AppPermission.viewReports,
        };
    }
  }

  bool can(AppPermission permission) => permissions.contains(permission);

  static UserRole fromDb(String value) {
    if (value == 'systemOwner') return UserRole.sanadOwner;
    if (value == 'owner') return UserRole.sanadOwner;
    if (value == 'admin') return UserRole.centerManager;
    if (value == 'programEntry') return UserRole.therapyProgramEntry;
    if (value == 'therapyBuilder') return UserRole.therapyProgramEntry;
    if (value == 'supervisor') return UserRole.clinicalSupervisor;
    return UserRole.values.firstWhere((role) => role.name == value,
        orElse: () => UserRole.parent);
  }
}

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.passwordHash,
    required this.name,
    required this.role,
    this.centerId = '',
    this.studentId,
    this.forcePasswordChange = false,
    this.isDemo = false,
    this.isActive = true,
    this.createdAt = '',
    this.updatedAt = '',
  });

  final String id;
  final String email;
  final String passwordHash;
  final String name;
  final UserRole role;
  final String centerId;
  final String? studentId;
  final bool forcePasswordChange;
  final bool isDemo;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  static AppUser fromMap(Map<String, Object?> row) => AppUser(
        id: row['id'] as String,
        email: row['email'] as String,
        passwordHash: (row['password_hash'] ?? row['password'] ?? '') as String,
        name: row['name'] as String,
        role: UserRoleX.fromDb(row['role'] as String),
        centerId: (row['center_id'] ?? '') as String,
        studentId: row['student_id'] as String?,
        forcePasswordChange: ((row['force_password_change'] ?? 0) as int) == 1,
        isDemo: ((row['is_demo'] ?? 0) as int) == 1,
        isActive: ((row['is_active'] ?? 1) as int) == 1,
        createdAt: (row['created_at'] ?? '') as String,
        updatedAt: (row['updated_at'] ?? '') as String,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'email': email,
        'password_hash': passwordHash,
        'name': name,
        'role': role.name,
        'center_id': centerId,
        'student_id': studentId,
        'force_password_change': forcePasswordChange ? 1 : 0,
        'is_demo': isDemo ? 1 : 0,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

class SanadCenter {
  const SanadCenter({
    required this.id,
    required this.name,
    this.logoPath = '',
    this.address = '',
    this.phone = '',
    this.managerName = '',
    this.isActive = true,
    this.createdAt = '',
    this.updatedAt = '',
  });

  final String id;
  final String name;
  final String logoPath;
  final String address;
  final String phone;
  final String managerName;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  static SanadCenter fromMap(Map<String, Object?> row) => SanadCenter(
        id: row['id'] as String,
        name: row['name'] as String,
        logoPath: (row['logo_path'] ?? '') as String,
        address: (row['address'] ?? '') as String,
        phone: (row['phone'] ?? '') as String,
        managerName: (row['manager_name'] ?? '') as String,
        isActive: ((row['is_active'] ?? 1) as int) == 1,
        createdAt: (row['created_at'] ?? '') as String,
        updatedAt: (row['updated_at'] ?? '') as String,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'logo_path': logoPath,
        'address': address,
        'phone': phone,
        'manager_name': managerName,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

class Student {
  const Student({
    required this.id,
    this.centerId = '',
    required this.name,
    required this.age,
    required this.status,
    required this.diagnosis,
    this.programType = 'نطق وتخاطب',
    required this.parentName,
    required this.parentPhone,
    required this.portalEmail,
    required this.portalPassword,
    this.photoPath = '',
    this.notes = '',
    this.deletedAt = '',
    this.createdAt = '',
    this.updatedAt = '',
  });

  final String id;
  final String centerId;
  final String name;
  final int age;
  final String status;
  final String diagnosis;
  final String programType;
  final String parentName;
  final String parentPhone;
  final String portalEmail;
  final String portalPassword;
  final String photoPath;
  final String notes;
  final String deletedAt;
  final String createdAt;
  final String updatedAt;

  static Student fromMap(Map<String, Object?> row) => Student(
        id: row['id'] as String,
        centerId: (row['center_id'] ?? '') as String,
        name: row['name'] as String,
        age: row['age'] as int,
        status: row['status'] as String,
        diagnosis: row['diagnosis'] as String,
        programType: (row['program_type'] ?? 'نطق وتخاطب') as String,
        parentName: row['parent_name'] as String,
        parentPhone: row['parent_phone'] as String,
        portalEmail: row['portal_email'] as String,
        portalPassword: row['portal_password'] as String,
        photoPath: row['photo_path'] as String,
        notes: row['notes'] as String,
        deletedAt: (row['deleted_at'] ?? '') as String,
        createdAt: (row['created_at'] ?? '') as String,
        updatedAt: (row['updated_at'] ?? '') as String,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'center_id': centerId,
        'name': name,
        'age': age,
        'status': status,
        'diagnosis': diagnosis,
        'program_type': programType,
        'parent_name': parentName,
        'parent_phone': parentPhone,
        'portal_email': portalEmail,
        'portal_password': portalPassword,
        'photo_path': photoPath,
        'notes': notes,
        'deleted_at': deletedAt,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

class ParentProfile {
  const ParentProfile({
    required this.id,
    this.centerId = '',
    required this.studentId,
    required this.name,
    required this.phone,
    required this.email,
  });

  final String id;
  final String centerId;
  final String studentId;
  final String name;
  final String phone;
  final String email;

  static ParentProfile fromMap(Map<String, Object?> row) => ParentProfile(
        id: row['id'] as String,
        centerId: (row['center_id'] ?? '') as String,
        studentId: row['student_id'] as String,
        name: row['name'] as String,
        phone: row['phone'] as String,
        email: row['email'] as String,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'center_id': centerId,
        'student_id': studentId,
        'name': name,
        'phone': phone,
        'email': email,
      };
}

class TherapySession {
  const TherapySession({
    required this.id,
    this.centerId = '',
    required this.studentId,
    this.specialistId = '',
    this.planId = '',
    this.programId = '',
    this.skillId = '',
    this.activityResults = '',
    this.sessionType = 'نطق وتخاطب',
    this.targetLetter = '',
    this.letterPosition = '',
    this.errorType = '',
    this.practiceItems = '',
    this.attempts = 0,
    this.successRate = 0,
    required this.startedAt,
    required this.durationSeconds,
    required this.cardTitle,
    required this.quickResult,
    required this.notes,
    this.summary = '',
    this.createdAt = '',
    this.updatedAt = '',
  });

  final String id;
  final String centerId;
  final String studentId;
  final String specialistId;
  final String planId;
  final String programId;
  final String skillId;
  final String activityResults;
  final String sessionType;
  final String targetLetter;
  final String letterPosition;
  final String errorType;
  final String practiceItems;
  final int attempts;
  final int successRate;
  final String startedAt;
  final int durationSeconds;
  final String cardTitle;
  final String quickResult;
  final String notes;
  final String summary;
  final String createdAt;
  final String updatedAt;

  static TherapySession fromMap(Map<String, Object?> row) => TherapySession(
        id: row['id'] as String,
        centerId: (row['center_id'] ?? '') as String,
        studentId: row['student_id'] as String,
        specialistId: (row['specialist_id'] ?? '') as String,
        planId: (row['plan_id'] ?? '') as String,
        programId: (row['program_id'] ?? '') as String,
        skillId: (row['skill_id'] ?? '') as String,
        activityResults: (row['activity_results'] ?? '') as String,
        sessionType: (row['session_type'] ?? 'نطق وتخاطب') as String,
        targetLetter: (row['target_letter'] ?? '') as String,
        letterPosition: (row['letter_position'] ?? '') as String,
        errorType: (row['error_type'] ?? '') as String,
        practiceItems: (row['practice_items'] ?? '') as String,
        attempts: (row['attempts'] ?? 0) as int,
        successRate: (row['success_rate'] ?? 0) as int,
        startedAt: row['started_at'] as String,
        durationSeconds: row['duration_seconds'] as int,
        cardTitle: row['card_title'] as String,
        quickResult: row['quick_result'] as String,
        notes: row['notes'] as String,
        summary: (row['summary'] ?? '') as String,
        createdAt: (row['created_at'] ?? '') as String,
        updatedAt: (row['updated_at'] ?? '') as String,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'center_id': centerId,
        'student_id': studentId,
        'specialist_id': specialistId,
        'plan_id': planId,
        'program_id': programId,
        'skill_id': skillId,
        'activity_results': activityResults,
        'session_type': sessionType,
        'target_letter': targetLetter,
        'letter_position': letterPosition,
        'error_type': errorType,
        'practice_items': practiceItems,
        'attempts': attempts,
        'success_rate': successRate,
        'started_at': startedAt,
        'duration_seconds': durationSeconds,
        'card_title': cardTitle,
        'quick_result': quickResult,
        'notes': notes,
        'summary': summary,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

class Evaluation {
  const Evaluation({
    required this.id,
    this.centerId = '',
    required this.studentId,
    required this.letter,
    required this.position,
    required this.errorType,
    required this.score,
    required this.createdAt,
    this.notes = '',
    this.severity = 1,
    this.recommendation = '',
    this.updatedAt = '',
  });

  final String id;
  final String centerId;
  final String studentId;
  final String letter;
  final String position;
  final String errorType;
  final String score;
  final String createdAt;
  final String notes;
  final int severity;
  final String recommendation;
  final String updatedAt;

  static Evaluation fromMap(Map<String, Object?> row) => Evaluation(
        id: row['id'] as String,
        centerId: (row['center_id'] ?? '') as String,
        studentId: row['student_id'] as String,
        letter: row['letter'] as String,
        position: row['position'] as String,
        errorType: row['error_type'] as String,
        score: row['score'] as String,
        createdAt: row['created_at'] as String,
        notes: row['notes'] as String,
        severity: (row['severity'] ?? 1) as int,
        recommendation: (row['recommendation'] ?? '') as String,
        updatedAt: (row['updated_at'] ?? '') as String,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'center_id': centerId,
        'student_id': studentId,
        'letter': letter,
        'position': position,
        'error_type': errorType,
        'score': score,
        'created_at': createdAt,
        'notes': notes,
        'severity': severity,
        'recommendation': recommendation,
        'updated_at': updatedAt,
      };
}

class TrainingPlan {
  const TrainingPlan({
    required this.id,
    this.centerId = '',
    required this.studentId,
    required this.goal,
    this.treatment = '',
    required this.targetDate,
    required this.progress,
    this.programId = '',
    this.sourceType = 'standard',
    this.createdAt = '',
    this.updatedAt = '',
  });

  final String id;
  final String centerId;
  final String studentId;
  final String goal;
  final String treatment;
  final String targetDate;
  final int progress;
  final String programId;
  final String sourceType;
  final String createdAt;
  final String updatedAt;

  static TrainingPlan fromMap(Map<String, Object?> row) => TrainingPlan(
        id: row['id'] as String,
        centerId: (row['center_id'] ?? '') as String,
        studentId: row['student_id'] as String,
        goal: row['goal'] as String,
        treatment: (row['treatment'] ?? '') as String,
        targetDate: row['target_date'] as String,
        progress: row['progress'] as int,
        programId: (row['program_id'] ?? '') as String,
        sourceType: (row['source_type'] ?? 'standard') as String,
        createdAt: (row['created_at'] ?? '') as String,
        updatedAt: (row['updated_at'] ?? '') as String,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'center_id': centerId,
        'student_id': studentId,
        'goal': goal,
        'treatment': treatment,
        'target_date': targetDate,
        'progress': progress,
        'program_id': programId,
        'source_type': sourceType,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  TrainingPlan copyWith({
    String? goal,
    int? progress,
    String? programId,
    String? sourceType,
    String? targetDate,
    String? updatedAt,
  }) =>
      TrainingPlan(
        id: id,
        centerId: centerId,
        studentId: studentId,
        goal: goal ?? this.goal,
        targetDate: targetDate ?? this.targetDate,
        progress: progress ?? this.progress,
        programId: programId ?? this.programId,
        sourceType: sourceType ?? this.sourceType,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class GoalSkillStep {
  const GoalSkillStep({
    required this.id,
    required this.centerId,
    required this.studentId,
    required this.goalId,
    required this.title,
    this.status = 'لم يبدأ',
    this.sortOrder = 0,
    this.notes = '',
    this.lastSessionId = '',
    this.programId = '',
    this.sourceType = 'standard',
    this.createdAt = '',
    this.updatedAt = '',
  });

  final String id;
  final String centerId;
  final String studentId;
  final String goalId;
  final String title;
  final String status;
  final int sortOrder;
  final String notes;
  final String lastSessionId;
  final String programId;
  final String sourceType;
  final String createdAt;
  final String updatedAt;

  static GoalSkillStep fromMap(Map<String, Object?> row) => GoalSkillStep(
        id: row['id'] as String,
        centerId: (row['center_id'] ?? '') as String,
        studentId: row['student_id'] as String,
        goalId: row['goal_id'] as String,
        title: row['title'] as String,
        status: (row['status'] ?? 'لم يبدأ') as String,
        sortOrder: (row['sort_order'] ?? 0) as int,
        notes: (row['notes'] ?? '') as String,
        lastSessionId: (row['last_session_id'] ?? '') as String,
        programId: (row['program_id'] ?? '') as String,
        sourceType: (row['source_type'] ?? 'standard') as String,
        createdAt: (row['created_at'] ?? '') as String,
        updatedAt: (row['updated_at'] ?? '') as String,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'center_id': centerId,
        'student_id': studentId,
        'goal_id': goalId,
        'title': title,
        'status': status,
        'sort_order': sortOrder,
        'notes': notes,
        'last_session_id': lastSessionId,
        'program_id': programId,
        'source_type': sourceType,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  GoalSkillStep copyWith({
    String? status,
    String? notes,
    String? lastSessionId,
    String? programId,
    String? sourceType,
    String? updatedAt,
  }) =>
      GoalSkillStep(
        id: id,
        centerId: centerId,
        studentId: studentId,
        goalId: goalId,
        title: title,
        status: status ?? this.status,
        sortOrder: sortOrder,
        notes: notes ?? this.notes,
        lastSessionId: lastSessionId ?? this.lastSessionId,
        programId: programId ?? this.programId,
        sourceType: sourceType ?? this.sourceType,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class Exercise {
  const Exercise({
    required this.id,
    this.centerId = '',
    required this.studentId,
    required this.title,
    required this.instructions,
    required this.dueDate,
    required this.status,
    this.audioPath = '',
    this.parentNote = '',
    this.stars = 0,
    this.programId = '',
    this.planId = '',
    this.goalSkillStepId = '',
    this.sourceType = 'standard',
    this.sessionDate = '',
    this.noteForParent = '',
    this.parentCompletedAt = '',
    this.specialistReviewedAt = '',
    this.createdFromSessionResult = '',
    this.createdAt = '',
    this.updatedAt = '',
  });

  final String id;
  final String centerId;
  final String studentId;
  final String title;
  final String instructions;
  final String dueDate;
  final String status;
  final String audioPath;
  final String parentNote;
  final int stars;
  final String programId;
  final String planId;
  final String goalSkillStepId;
  final String sourceType;
  final String sessionDate;
  final String noteForParent;
  final String parentCompletedAt;
  final String specialistReviewedAt;
  final String createdFromSessionResult;
  final String createdAt;
  final String updatedAt;

  static Exercise fromMap(Map<String, Object?> row) => Exercise(
        id: row['id'] as String,
        centerId: (row['center_id'] ?? '') as String,
        studentId: row['student_id'] as String,
        title: row['title'] as String,
        instructions: row['instructions'] as String,
        dueDate: row['due_date'] as String,
        status: row['status'] as String,
        audioPath: row['audio_path'] as String,
        parentNote: (row['parent_note'] ?? '') as String,
        stars: (row['stars'] ?? 0) as int,
        programId: (row['program_id'] ?? '') as String,
        planId: (row['plan_id'] ?? '') as String,
        goalSkillStepId: (row['goal_skill_step_id'] ?? '') as String,
        sourceType: (row['source_type'] ?? 'standard') as String,
        sessionDate: (row['session_date'] ?? '') as String,
        noteForParent: (row['note_for_parent'] ?? '') as String,
        parentCompletedAt: (row['parent_completed_at'] ?? '') as String,
        specialistReviewedAt: (row['specialist_reviewed_at'] ?? '') as String,
        createdFromSessionResult:
            (row['created_from_session_result'] ?? '') as String,
        createdAt: (row['created_at'] ?? '') as String,
        updatedAt: (row['updated_at'] ?? '') as String,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'center_id': centerId,
        'student_id': studentId,
        'title': title,
        'instructions': instructions,
        'due_date': dueDate,
        'status': status,
        'audio_path': audioPath,
        'parent_note': parentNote,
        'stars': stars,
        'program_id': programId,
        'plan_id': planId,
        'goal_skill_step_id': goalSkillStepId,
        'source_type': sourceType,
        'session_date': sessionDate,
        'note_for_parent': noteForParent,
        'parent_completed_at': parentCompletedAt,
        'specialist_reviewed_at': specialistReviewedAt,
        'created_from_session_result': createdFromSessionResult,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  Exercise copyWith({
    String? status,
    String? parentNote,
    String? parentCompletedAt,
    String? specialistReviewedAt,
    String? noteForParent,
    String? programId,
    String? planId,
    String? goalSkillStepId,
    String? sourceType,
    String? sessionDate,
  }) =>
      Exercise(
        id: id,
        centerId: centerId,
        studentId: studentId,
        title: title,
        instructions: instructions,
        dueDate: dueDate,
        status: status ?? this.status,
        audioPath: audioPath,
        parentNote: parentNote ?? this.parentNote,
        stars: stars,
        programId: programId ?? this.programId,
        planId: planId ?? this.planId,
        goalSkillStepId: goalSkillStepId ?? this.goalSkillStepId,
        sourceType: sourceType ?? this.sourceType,
        sessionDate: sessionDate ?? this.sessionDate,
        noteForParent: noteForParent ?? this.noteForParent,
        parentCompletedAt: parentCompletedAt ?? this.parentCompletedAt,
        specialistReviewedAt:
            specialistReviewedAt ?? this.specialistReviewedAt,
        createdFromSessionResult: createdFromSessionResult,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

class Reward {
  const Reward({
    required this.id,
    this.centerId = '',
    required this.studentId,
    required this.xp,
    required this.level,
    required this.badges,
    required this.dailyStreak,
  });

  final String id;
  final String centerId;
  final String studentId;
  final int xp;
  final int level;
  final String badges;
  final int dailyStreak;

  static Reward fromMap(Map<String, Object?> row) => Reward(
        id: row['id'] as String,
        centerId: (row['center_id'] ?? '') as String,
        studentId: row['student_id'] as String,
        xp: row['xp'] as int,
        level: row['level'] as int,
        badges: row['badges'] as String,
        dailyStreak: row['daily_streak'] as int,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'center_id': centerId,
        'student_id': studentId,
        'xp': xp,
        'level': level,
        'badges': badges,
        'daily_streak': dailyStreak,
      };
}

class ReportRecord {
  const ReportRecord({
    required this.id,
    this.centerId = '',
    required this.studentId,
    required this.type,
    required this.createdAt,
    required this.improvementRate,
    required this.specialistSignature,
    this.managerSignature = '',
    this.filePath = '',
    this.updatedAt = '',
  });

  final String id;
  final String centerId;
  final String studentId;
  final String type;
  final String createdAt;
  final int improvementRate;
  final String specialistSignature;
  final String managerSignature;
  final String filePath;
  final String updatedAt;

  static ReportRecord fromMap(Map<String, Object?> row) => ReportRecord(
        id: row['id'] as String,
        centerId: (row['center_id'] ?? '') as String,
        studentId: row['student_id'] as String,
        type: row['type'] as String,
        createdAt: row['created_at'] as String,
        improvementRate: row['improvement_rate'] as int,
        specialistSignature: row['specialist_signature'] as String,
        managerSignature: (row['manager_signature'] ?? '') as String,
        filePath: (row['file_path'] ?? '') as String,
        updatedAt: (row['updated_at'] ?? '') as String,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'center_id': centerId,
        'student_id': studentId,
        'type': type,
        'created_at': createdAt,
        'improvement_rate': improvementRate,
        'specialist_signature': specialistSignature,
        'manager_signature': managerSignature,
        'file_path': filePath,
        'updated_at': updatedAt,
      };
}

class ClinicalAssessment {
  const ClinicalAssessment({
    required this.id,
    required this.centerId,
    required this.studentId,
    required this.specialistId,
    required this.specialistName,
    required this.type,
    required this.strengthsSummary,
    required this.weaknessesSummary,
    required this.goalsSummary,
    required this.trainingSummary,
    required this.createdAt,
    this.updatedAt = '',
  });

  final String id;
  final String centerId;
  final String studentId;
  final String specialistId;
  final String specialistName;
  final String type;
  final String strengthsSummary;
  final String weaknessesSummary;
  final String goalsSummary;
  final String trainingSummary;
  final String createdAt;
  final String updatedAt;

  static ClinicalAssessment fromMap(Map<String, Object?> row) =>
      ClinicalAssessment(
        id: row['id'] as String,
        centerId: (row['center_id'] ?? '') as String,
        studentId: row['student_id'] as String,
        specialistId: (row['specialist_id'] ?? '') as String,
        specialistName: (row['specialist_name'] ?? '') as String,
        type: (row['type'] ?? 'speech') as String,
        strengthsSummary: (row['strengths_summary'] ?? '') as String,
        weaknessesSummary: (row['weaknesses_summary'] ?? '') as String,
        goalsSummary: (row['goals_summary'] ?? '') as String,
        trainingSummary: (row['training_summary'] ?? '') as String,
        createdAt: (row['created_at'] ?? '') as String,
        updatedAt: (row['updated_at'] ?? '') as String,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'center_id': centerId,
        'student_id': studentId,
        'specialist_id': specialistId,
        'specialist_name': specialistName,
        'type': type,
        'strengths_summary': strengthsSummary,
        'weaknesses_summary': weaknessesSummary,
        'goals_summary': goalsSummary,
        'training_summary': trainingSummary,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

class ClinicalFinding {
  const ClinicalFinding({
    required this.id,
    required this.assessmentId,
    required this.centerId,
    required this.studentId,
    required this.domain,
    required this.itemTitle,
    required this.result,
    required this.isNormal,
    this.weakness = '',
    this.goal = '',
    this.training = '',
    this.programId = '',
    this.sourceType = 'standard',
    this.createdAt = '',
    this.updatedAt = '',
  });

  final String id;
  final String assessmentId;
  final String centerId;
  final String studentId;
  final String domain;
  final String itemTitle;
  final String result;
  final bool isNormal;
  final String weakness;
  final String goal;
  final String training;
  final String programId;
  final String sourceType;
  final String createdAt;
  final String updatedAt;

  static ClinicalFinding fromMap(Map<String, Object?> row) => ClinicalFinding(
        id: row['id'] as String,
        assessmentId: row['assessment_id'] as String,
        centerId: (row['center_id'] ?? '') as String,
        studentId: row['student_id'] as String,
        domain: row['domain'] as String,
        itemTitle: row['item_title'] as String,
        result: row['result'] as String,
        isNormal: ((row['is_normal'] ?? 0) as int) == 1,
        weakness: (row['weakness'] ?? '') as String,
        goal: (row['goal'] ?? '') as String,
        training: (row['training'] ?? '') as String,
        programId: (row['program_id'] ?? '') as String,
        sourceType: (row['source_type'] ?? 'standard') as String,
        createdAt: (row['created_at'] ?? '') as String,
        updatedAt: (row['updated_at'] ?? '') as String,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'assessment_id': assessmentId,
        'center_id': centerId,
        'student_id': studentId,
        'domain': domain,
        'item_title': itemTitle,
        'result': result,
        'is_normal': isNormal ? 1 : 0,
        'weakness': weakness,
        'goal': goal,
        'training': training,
        'program_id': programId,
        'source_type': sourceType,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

class TherapyProgramTemplate {
  const TherapyProgramTemplate({
    required this.id,
    required this.centerId,
    required this.name,
    this.description = '',
    this.usesSpeechSounds = false,
    required this.sortOrder,
    this.createdAt = '',
    this.updatedAt = '',
  });

  final String id;
  final String centerId;
  final String name;
  final String description;
  final bool usesSpeechSounds;
  final int sortOrder;
  final String createdAt;
  final String updatedAt;

  static TherapyProgramTemplate fromMap(Map<String, Object?> row) =>
      TherapyProgramTemplate(
        id: row['id'] as String,
        centerId: (row['center_id'] ?? '') as String,
        name: row['name'] as String,
        description: (row['description'] ?? '') as String,
        usesSpeechSounds: ((row['uses_speech_sounds'] ?? 0) as int) == 1,
        sortOrder: (row['sort_order'] ?? 0) as int,
        createdAt: (row['created_at'] ?? '') as String,
        updatedAt: (row['updated_at'] ?? '') as String,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'center_id': centerId,
        'name': name,
        'description': description,
        'uses_speech_sounds': usesSpeechSounds ? 1 : 0,
        'sort_order': sortOrder,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

class AssessmentSectionTemplate {
  const AssessmentSectionTemplate({
    required this.id,
    required this.centerId,
    required this.programId,
    required this.title,
    this.description = '',
    required this.sortOrder,
    this.createdAt = '',
    this.updatedAt = '',
  });

  final String id;
  final String centerId;
  final String programId;
  final String title;
  final String description;
  final int sortOrder;
  final String createdAt;
  final String updatedAt;

  static AssessmentSectionTemplate fromMap(Map<String, Object?> row) =>
      AssessmentSectionTemplate(
        id: row['id'] as String,
        centerId: (row['center_id'] ?? '') as String,
        programId: (row['program_id'] ?? '') as String,
        title: row['title'] as String,
        description: (row['description'] ?? '') as String,
        sortOrder: (row['sort_order'] ?? 0) as int,
        createdAt: (row['created_at'] ?? '') as String,
        updatedAt: (row['updated_at'] ?? '') as String,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'center_id': centerId,
        'program_id': programId,
        'title': title,
        'description': description,
        'sort_order': sortOrder,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

class AssessmentItemTemplate {
  const AssessmentItemTemplate({
    required this.id,
    required this.centerId,
    required this.sectionId,
    required this.title,
    this.responseType = 'custom',
    this.responseMode = 'singleChoice',
    this.prompt = '',
    required this.sortOrder,
    this.createdAt = '',
    this.updatedAt = '',
  });

  final String id;
  final String centerId;
  final String sectionId;
  final String title;
  final String responseType;
  final String responseMode;
  final String prompt;
  final int sortOrder;
  final String createdAt;
  final String updatedAt;

  static AssessmentItemTemplate fromMap(Map<String, Object?> row) =>
      AssessmentItemTemplate(
        id: row['id'] as String,
        centerId: (row['center_id'] ?? '') as String,
        sectionId: row['section_id'] as String,
        title: row['title'] as String,
        responseType: (row['response_type'] ?? 'custom') as String,
        responseMode: (row['response_mode'] ?? 'singleChoice') as String,
        prompt: (row['prompt'] ?? '') as String,
        sortOrder: (row['sort_order'] ?? 0) as int,
        createdAt: (row['created_at'] ?? '') as String,
        updatedAt: (row['updated_at'] ?? '') as String,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'center_id': centerId,
        'section_id': sectionId,
        'title': title,
        'response_type': responseType,
        'response_mode': responseMode,
        'prompt': prompt,
        'sort_order': sortOrder,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

class AssessmentOptionTemplate {
  const AssessmentOptionTemplate({
    required this.id,
    required this.centerId,
    required this.itemId,
    required this.label,
    required this.generatesTherapy,
    this.weaknessTemplate = '',
    this.goalTemplate = '',
    this.therapyTemplate = '',
    required this.sortOrder,
    this.createdAt = '',
    this.updatedAt = '',
  });

  final String id;
  final String centerId;
  final String itemId;
  final String label;
  final bool generatesTherapy;
  final String weaknessTemplate;
  final String goalTemplate;
  final String therapyTemplate;
  final int sortOrder;
  final String createdAt;
  final String updatedAt;

  static AssessmentOptionTemplate fromMap(Map<String, Object?> row) =>
      AssessmentOptionTemplate(
        id: row['id'] as String,
        centerId: (row['center_id'] ?? '') as String,
        itemId: row['item_id'] as String,
        label: row['label'] as String,
        generatesTherapy: ((row['generates_therapy'] ?? 0) as int) == 1,
        weaknessTemplate: (row['weakness_template'] ?? '') as String,
        goalTemplate: (row['goal_template'] ?? '') as String,
        therapyTemplate: (row['therapy_template'] ?? '') as String,
        sortOrder: (row['sort_order'] ?? 0) as int,
        createdAt: (row['created_at'] ?? '') as String,
        updatedAt: (row['updated_at'] ?? '') as String,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'center_id': centerId,
        'item_id': itemId,
        'label': label,
        'generates_therapy': generatesTherapy ? 1 : 0,
        'weakness_template': weaknessTemplate,
        'goal_template': goalTemplate,
        'therapy_template': therapyTemplate,
        'sort_order': sortOrder,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

class SkillStepTemplate {
  const SkillStepTemplate({
    required this.id,
    required this.centerId,
    required this.ownerType,
    required this.ownerId,
    required this.title,
    required this.sortOrder,
    this.createdAt = '',
    this.updatedAt = '',
  });

  final String id;
  final String centerId;
  final String ownerType;
  final String ownerId;
  final String title;
  final int sortOrder;
  final String createdAt;
  final String updatedAt;

  static SkillStepTemplate fromMap(Map<String, Object?> row) =>
      SkillStepTemplate(
        id: row['id'] as String,
        centerId: (row['center_id'] ?? '') as String,
        ownerType: row['owner_type'] as String,
        ownerId: row['owner_id'] as String,
        title: row['title'] as String,
        sortOrder: (row['sort_order'] ?? 0) as int,
        createdAt: (row['created_at'] ?? '') as String,
        updatedAt: (row['updated_at'] ?? '') as String,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'center_id': centerId,
        'owner_type': ownerType,
        'owner_id': ownerId,
        'title': title,
        'sort_order': sortOrder,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  SkillStepTemplate copyWith({
    String? id,
    String? centerId,
    String? ownerType,
    String? ownerId,
    String? title,
    int? sortOrder,
    String? createdAt,
    String? updatedAt,
  }) =>
      SkillStepTemplate(
        id: id ?? this.id,
        centerId: centerId ?? this.centerId,
        ownerType: ownerType ?? this.ownerType,
        ownerId: ownerId ?? this.ownerId,
        title: title ?? this.title,
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class SpeechSoundTriggerTemplate {
  const SpeechSoundTriggerTemplate({
    required this.id,
    required this.centerId,
    required this.programId,
    required this.letter,
    required this.errorType,
    required this.position,
    required this.generatesTherapy,
    this.weaknessTemplate = '',
    this.goalTemplate = '',
    this.therapyTemplate = '',
    this.skillStepTemplates = const [],
    required this.sortOrder,
    this.createdAt = '',
    this.updatedAt = '',
  });

  final String id;
  final String centerId;
  final String programId;
  final String letter;
  final String errorType;
  final String position;
  final bool generatesTherapy;
  final String weaknessTemplate;
  final String goalTemplate;
  final String therapyTemplate;
  final List<String> skillStepTemplates;
  final int sortOrder;
  final String createdAt;
  final String updatedAt;

  static SpeechSoundTriggerTemplate fromMap(Map<String, Object?> row) =>
      SpeechSoundTriggerTemplate(
        id: row['id'] as String,
        centerId: (row['center_id'] ?? '') as String,
        programId: (row['program_id'] ?? '') as String,
        letter: row['letter'] as String,
        errorType: row['error_type'] as String,
        position: row['position'] as String,
        generatesTherapy: ((row['generates_therapy'] ?? 0) as int) == 1,
        weaknessTemplate: (row['weakness_template'] ?? '') as String,
        goalTemplate: (row['goal_template'] ?? '') as String,
        therapyTemplate: (row['therapy_template'] ?? '') as String,
        skillStepTemplates: _parseSkillSteps(row['skill_steps_json']),
        sortOrder: (row['sort_order'] ?? 0) as int,
        createdAt: (row['created_at'] ?? '') as String,
        updatedAt: (row['updated_at'] ?? '') as String,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'center_id': centerId,
        'program_id': programId,
        'letter': letter,
        'error_type': errorType,
        'position': position,
        'generates_therapy': generatesTherapy ? 1 : 0,
        'weakness_template': weaknessTemplate,
        'goal_template': goalTemplate,
        'therapy_template': therapyTemplate,
        'skill_steps_json': _encodeSkillSteps(skillStepTemplates),
        'sort_order': sortOrder,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  static List<String> _parseSkillSteps(Object? value) {
    if (value == null) return const [];
    if (value is List) return value.cast<String>();
    if (value is String) {
      if (value.isEmpty || value == '[]') return const [];
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) return decoded.cast<String>();
      } catch (_) {}
    }
    return const [];
  }

  static String _encodeSkillSteps(List<String> steps) {
    return steps.isEmpty ? '[]' : jsonEncode(steps);
  }

  SpeechSoundTriggerTemplate copyWith({
    String? id,
    String? centerId,
    String? programId,
    String? letter,
    String? errorType,
    String? position,
    bool? generatesTherapy,
    String? weaknessTemplate,
    String? goalTemplate,
    String? therapyTemplate,
    List<String>? skillStepTemplates,
    int? sortOrder,
    String? createdAt,
    String? updatedAt,
  }) =>
      SpeechSoundTriggerTemplate(
        id: id ?? this.id,
        centerId: centerId ?? this.centerId,
        programId: programId ?? this.programId,
        letter: letter ?? this.letter,
        errorType: errorType ?? this.errorType,
        position: position ?? this.position,
        generatesTherapy: generatesTherapy ?? this.generatesTherapy,
        weaknessTemplate: weaknessTemplate ?? this.weaknessTemplate,
        goalTemplate: goalTemplate ?? this.goalTemplate,
        therapyTemplate: therapyTemplate ?? this.therapyTemplate,
        skillStepTemplates:
            skillStepTemplates ?? this.skillStepTemplates,
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class SignResource {
  const SignResource({
    required this.id,
    this.centerId = '',
    required this.title,
    required this.category,
    required this.mediaType,
    required this.mediaPath,
    this.notes = '',
    this.level = 'مبتدئ',
    this.isFavorite = false,
  });

  final String id;
  final String centerId;
  final String title;
  final String category;
  final String mediaType;
  final String mediaPath;
  final String notes;
  final String level;
  final bool isFavorite;

  static SignResource fromMap(Map<String, Object?> row) => SignResource(
        id: row['id'] as String,
        centerId: (row['center_id'] ?? '') as String,
        title: row['title'] as String,
        category: row['category'] as String,
        mediaType: row['media_type'] as String,
        mediaPath: row['media_path'] as String,
        notes: row['notes'] as String,
        level: (row['level'] ?? 'مبتدئ') as String,
        isFavorite: ((row['is_favorite'] ?? 0) as int) == 1,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'center_id': centerId,
        'title': title,
        'category': category,
        'media_type': mediaType,
        'media_path': mediaPath,
        'notes': notes,
        'level': level,
        'is_favorite': isFavorite ? 1 : 0,
      };
}

class AuditLog {
  const AuditLog({
    required this.id,
    required this.centerId,
    required this.userId,
    required this.userName,
    required this.action,
    required this.entityType,
    required this.entityId,
    this.details = '',
    required this.createdAt,
  });

  final String id;
  final String centerId;
  final String userId;
  final String userName;
  final String action;
  final String entityType;
  final String entityId;
  final String details;
  final String createdAt;

  static AuditLog fromMap(Map<String, Object?> row) => AuditLog(
        id: row['id'] as String,
        centerId: (row['center_id'] ?? '') as String,
        userId: row['user_id'] as String,
        userName: row['user_name'] as String,
        action: row['action'] as String,
        entityType: row['entity_type'] as String,
        entityId: row['entity_id'] as String,
        details: (row['details'] ?? '') as String,
        createdAt: row['created_at'] as String,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'center_id': centerId,
        'user_id': userId,
        'user_name': userName,
        'action': action,
        'entity_type': entityType,
        'entity_id': entityId,
        'details': details,
        'created_at': createdAt,
      };
}

class TrainingItem {
  const TrainingItem({
    required this.id,
    required this.type,
    required this.title,
    this.letter = '',
    this.position = '',
    this.level = 'مبتدئ',
    this.category = '',
  });

  final String id;
  final String type;
  final String title;
  final String letter;
  final String position;
  final String level;
  final String category;
}

class AssessmentDraft {
  const AssessmentDraft({
    required this.studentId,
    required this.programId,
    this.phase = 'sections',
    this.stepIndex = 0,
    this.currentLetter = '',
    this.selectionsJson = '{}',
    this.multiSelectionsJson = '{}',
    this.matrixSelectionsJson = '[]',
    this.letterResultsJson = '{}',
    this.updatedAt = '',
  });

  final String studentId;
  final String programId;
  final String phase;
  final int stepIndex;
  final String currentLetter;
  final String selectionsJson;
  final String multiSelectionsJson;
  final String matrixSelectionsJson;
  final String letterResultsJson;
  final String updatedAt;

  static AssessmentDraft fromMap(Map<String, Object?> row) =>
      AssessmentDraft(
        studentId: row['student_id'] as String,
        programId: row['program_id'] as String,
        phase: (row['phase'] ?? 'sections') as String,
        stepIndex: (row['step_index'] ?? 0) as int,
        currentLetter: (row['current_letter'] ?? '') as String,
        selectionsJson: (row['selections_json'] ?? '{}') as String,
        multiSelectionsJson:
            (row['multi_selections_json'] ?? '{}') as String,
        matrixSelectionsJson:
            (row['matrix_selections_json'] ?? '[]') as String,
        letterResultsJson:
            (row['letter_results_json'] ?? '{}') as String,
        updatedAt: (row['updated_at'] ?? '') as String,
      );

  Map<String, Object?> toMap() => {
        'student_id': studentId,
        'program_id': programId,
        'phase': phase,
        'step_index': stepIndex,
        'current_letter': currentLetter,
        'selections_json': selectionsJson,
        'multi_selections_json': multiSelectionsJson,
        'matrix_selections_json': matrixSelectionsJson,
        'letter_results_json': letterResultsJson,
        'updated_at': updatedAt,
      };
}

class StudentTherapyProgram {
  const StudentTherapyProgram({
    required this.id,
    required this.studentId,
    required this.programId,
    required this.assignedAt,
    this.assignedByUserId = '',
    this.isActive = true,
    this.sortOrder = 0,
  });

  final String id;
  final String studentId;
  final String programId;
  final String assignedAt;
  final String assignedByUserId;
  final bool isActive;
  final int sortOrder;

  static StudentTherapyProgram fromMap(Map<String, Object?> row) =>
      StudentTherapyProgram(
        id: row['id'] as String,
        studentId: row['student_id'] as String,
        programId: row['program_id'] as String,
        assignedAt: row['assigned_at'] as String,
        assignedByUserId: (row['assigned_by_user_id'] ?? '') as String,
        isActive: ((row['is_active'] ?? 1) as int) == 1,
        sortOrder: (row['sort_order'] ?? 0) as int,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'student_id': studentId,
        'program_id': programId,
        'assigned_at': assignedAt,
        'assigned_by_user_id': assignedByUserId,
        'is_active': isActive ? 1 : 0,
        'sort_order': sortOrder,
      };
}

class StudentSpecialist {
  const StudentSpecialist({
    required this.id,
    required this.studentId,
    required this.specialistId,
    this.assignedByUserId = '',
    this.assignedAt = '',
    this.isActive = true,
  });

  final String id;
  final String studentId;
  final String specialistId;
  final String assignedByUserId;
  final String assignedAt;
  final bool isActive;

  static StudentSpecialist fromMap(Map<String, Object?> row) =>
      StudentSpecialist(
        id: row['id'] as String,
        studentId: row['student_id'] as String,
        specialistId: row['specialist_id'] as String,
        assignedByUserId: (row['assigned_by_user_id'] ?? '') as String,
        assignedAt: (row['assigned_at'] ?? '') as String,
        isActive: ((row['is_active'] ?? 1) as int) == 1,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'student_id': studentId,
        'specialist_id': specialistId,
        'assigned_by_user_id': assignedByUserId,
        'assigned_at': assignedAt,
        'is_active': isActive ? 1 : 0,
      };
}
