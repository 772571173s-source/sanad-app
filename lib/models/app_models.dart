enum UserRole {
  sanadOwner,
  centerManager,
  specialist,
  dataEntry,
  programEntry,
  parent
}

extension UserRoleX on UserRole {
  String get label {
    switch (this) {
      case UserRole.sanadOwner:
        return 'مالك النظام';
      case UserRole.centerManager:
        return 'مدير مركز';
      case UserRole.specialist:
        return 'أخصائي';
      case UserRole.dataEntry:
        return 'مدخل بيانات';
      case UserRole.programEntry:
        return 'مدخل برامج';
      case UserRole.parent:
        return 'ولي أمر';
    }
  }

  static UserRole fromDb(String value) {
    if (value == 'systemOwner') return UserRole.sanadOwner;
    if (value == 'owner') return UserRole.sanadOwner;
    if (value == 'admin') return UserRole.centerManager;
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
    required this.targetDate,
    required this.progress,
    this.createdAt = '',
    this.updatedAt = '',
  });

  final String id;
  final String centerId;
  final String studentId;
  final String goal;
  final String targetDate;
  final int progress;
  final String createdAt;
  final String updatedAt;

  static TrainingPlan fromMap(Map<String, Object?> row) => TrainingPlan(
        id: row['id'] as String,
        centerId: (row['center_id'] ?? '') as String,
        studentId: row['student_id'] as String,
        goal: row['goal'] as String,
        targetDate: row['target_date'] as String,
        progress: row['progress'] as int,
        createdAt: (row['created_at'] ?? '') as String,
        updatedAt: (row['updated_at'] ?? '') as String,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'center_id': centerId,
        'student_id': studentId,
        'goal': goal,
        'target_date': targetDate,
        'progress': progress,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

class TherapyProgram {
  const TherapyProgram({
    required this.id,
    required this.centerId,
    required this.name,
    required this.type,
    this.description = '',
    this.isActive = true,
    this.createdAt = '',
    this.updatedAt = '',
  });

  final String id;
  final String centerId;
  final String name;
  final String type;
  final String description;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  static TherapyProgram fromMap(Map<String, Object?> row) => TherapyProgram(
        id: row['id'] as String,
        centerId: (row['center_id'] ?? '') as String,
        name: row['name'] as String,
        type: row['type'] as String,
        description: (row['description'] ?? '') as String,
        isActive: ((row['is_active'] ?? 1) as int) == 1,
        createdAt: (row['created_at'] ?? '') as String,
        updatedAt: (row['updated_at'] ?? '') as String,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'center_id': centerId,
        'name': name,
        'type': type,
        'description': description,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

class ProgramSection {
  const ProgramSection({
    required this.id,
    required this.centerId,
    required this.programId,
    required this.title,
    this.sortOrder = 0,
    this.createdAt = '',
    this.updatedAt = '',
  });

  final String id;
  final String centerId;
  final String programId;
  final String title;
  final int sortOrder;
  final String createdAt;
  final String updatedAt;

  static ProgramSection fromMap(Map<String, Object?> row) => ProgramSection(
        id: row['id'] as String,
        centerId: (row['center_id'] ?? '') as String,
        programId: row['program_id'] as String,
        title: row['title'] as String,
        sortOrder: (row['sort_order'] ?? 0) as int,
        createdAt: (row['created_at'] ?? '') as String,
        updatedAt: (row['updated_at'] ?? '') as String,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'center_id': centerId,
        'program_id': programId,
        'title': title,
        'sort_order': sortOrder,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

class ProgramSkill {
  const ProgramSkill({
    required this.id,
    required this.centerId,
    required this.programId,
    required this.sectionId,
    required this.title,
    this.description = '',
    this.createdAt = '',
    this.updatedAt = '',
  });

  final String id;
  final String centerId;
  final String programId;
  final String sectionId;
  final String title;
  final String description;
  final String createdAt;
  final String updatedAt;

  static ProgramSkill fromMap(Map<String, Object?> row) => ProgramSkill(
        id: row['id'] as String,
        centerId: (row['center_id'] ?? '') as String,
        programId: row['program_id'] as String,
        sectionId: row['section_id'] as String,
        title: row['title'] as String,
        description: (row['description'] ?? '') as String,
        createdAt: (row['created_at'] ?? '') as String,
        updatedAt: (row['updated_at'] ?? '') as String,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'center_id': centerId,
        'program_id': programId,
        'section_id': sectionId,
        'title': title,
        'description': description,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

class ProgramActivity {
  const ProgramActivity({
    required this.id,
    required this.centerId,
    required this.programId,
    required this.skillId,
    required this.title,
    this.instructions = '',
    this.homework = '',
    this.evaluationType = 'speech',
    this.createdAt = '',
    this.updatedAt = '',
  });

  final String id;
  final String centerId;
  final String programId;
  final String skillId;
  final String title;
  final String instructions;
  final String homework;
  final String evaluationType;
  final String createdAt;
  final String updatedAt;

  static ProgramActivity fromMap(Map<String, Object?> row) => ProgramActivity(
        id: row['id'] as String,
        centerId: (row['center_id'] ?? '') as String,
        programId: row['program_id'] as String,
        skillId: row['skill_id'] as String,
        title: row['title'] as String,
        instructions: (row['instructions'] ?? '') as String,
        homework: (row['homework'] ?? '') as String,
        evaluationType: (row['evaluation_type'] ?? 'speech') as String,
        createdAt: (row['created_at'] ?? '') as String,
        updatedAt: (row['updated_at'] ?? '') as String,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'center_id': centerId,
        'program_id': programId,
        'skill_id': skillId,
        'title': title,
        'instructions': instructions,
        'homework': homework,
        'evaluation_type': evaluationType,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
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
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
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
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
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
