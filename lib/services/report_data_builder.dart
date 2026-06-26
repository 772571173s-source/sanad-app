import '../models/app_models.dart';
import '../providers/app_provider.dart';

class ProgramReportSection {
  final String programId;
  final String programName;
  final String specialistId;
  final String specialistName;
  final List<ClinicalAssessment> assessments;
  final List<ClinicalFinding> findings;
  final List<TrainingPlan> plans;
  final List<GoalSkillStep> goalSkillSteps;
  final List<TherapySession> sessions;
  final List<StudentFollowup> followups;
  final List<Exercise> exercises;
  final int overallProgress;
  final int masteredGoals;
  final int activeGoals;
  final int standardGoalCount;
  final int speechSoundGoalCount;

  const ProgramReportSection({
    required this.programId,
    required this.programName,
    required this.specialistId,
    required this.specialistName,
    this.assessments = const [],
    this.findings = const [],
    this.plans = const [],
    this.goalSkillSteps = const [],
    this.sessions = const [],
    this.followups = const [],
    this.exercises = const [],
    this.overallProgress = 0,
    this.masteredGoals = 0,
    this.activeGoals = 0,
    this.standardGoalCount = 0,
    this.speechSoundGoalCount = 0,
  });

  int get totalSessions => sessions.length;

  List<TrainingPlan> get standardPlans =>
      plans.where((p) => p.sourceType == 'standard').toList();

  List<TrainingPlan> get speechSoundPlans =>
      plans.where((p) => p.sourceType == 'speechSound').toList();

  List<GoalSkillStep> stepsForPlan(String planId) =>
      goalSkillSteps.where((s) => s.goalId == planId).toList();
}

class ReportData {
  final Student student;
  final SanadCenter? center;
  final String type;
  final String scope;
  final String dateFrom;
  final String dateTo;
  final String createdByUserId;
  final String createdByName;
  final List<ProgramReportSection> sections;
  final int overallImprovementRate;

  const ReportData({
    required this.student,
    this.center,
    required this.type,
    required this.scope,
    this.dateFrom = '',
    this.dateTo = '',
    this.createdByUserId = '',
    this.createdByName = '',
    this.sections = const [],
    this.overallImprovementRate = 0,
  });

  int get totalSections => sections.length;
  int get totalSessions =>
      sections.fold(0, (sum, s) => sum + s.totalSessions);
  int get totalPlans => sections.fold(0, (sum, s) => sum + s.plans.length);
  int get totalMasteredGoals =>
      sections.fold(0, (sum, s) => sum + s.masteredGoals);
  int get totalActiveGoals =>
      sections.fold(0, (sum, s) => sum + s.activeGoals);
}

class ReportDataBuilder {
  final AppProvider app;

  const ReportDataBuilder({required this.app});

  List<StudentProgramAssignment> specialistAssignments() {
    final user = app.user;
    if (user == null) return [];
    return app.studentProgramAssignments.where((a) =>
        a.specialistId == user.id &&
        a.isActive &&
        a.centerId == app.activeCenterId).toList();
  }

  List<TrainingPlan> plansForProgram(String programId, {String? specialistId}) {
    var filtered = app.plans.where((p) => p.programId == programId).toList();
    if (specialistId != null && specialistId.isNotEmpty) {
      filtered = filtered.where((p) => p.specialistId == specialistId).toList();
    }
    return filtered;
  }

  List<TherapySession> sessionsForProgram(
      String programId,
      String studentId,
      {String? specialistId,
      String? dateFrom,
      String? dateTo}) {
    var filtered = app.sessions
        .where((s) =>
            s.programId == programId && s.studentId == studentId)
        .toList();
    if (specialistId != null && specialistId.isNotEmpty) {
      filtered = filtered.where((s) => s.specialistId == specialistId).toList();
    }
    if (dateFrom != null && dateFrom.isNotEmpty) {
      final from = DateTime.tryParse(dateFrom);
      if (from != null) {
        filtered = filtered.where((s) {
          final d = DateTime.tryParse(s.startedAt);
          return d != null && !d.isBefore(from);
        }).toList();
      }
    }
    if (dateTo != null && dateTo.isNotEmpty) {
      final to = DateTime.tryParse(dateTo);
      if (to != null) {
        filtered = filtered.where((s) {
          final d = DateTime.tryParse(s.startedAt);
          return d != null && !d.isAfter(to.add(const Duration(days: 1)));
        }).toList();
      }
    }
    return filtered;
  }

  List<ClinicalAssessment> assessmentsForProgram(
      String programId, String studentId,
      {String? specialistId}) {
    var filtered = app.clinicalAssessments
        .where((a) =>
            a.programId == programId && a.studentId == studentId)
        .toList();
    if (specialistId != null && specialistId.isNotEmpty) {
      filtered = filtered.where((a) => a.specialistId == specialistId).toList();
    }
    return filtered;
  }

  List<ClinicalFinding> findingsForAssessment(String assessmentId) =>
      app.clinicalFindingsByAssessment[assessmentId] ?? [];

  List<GoalSkillStep> stepsForProgram(String programId,
      {String? specialistId}) {
    var filtered =
        app.goalSkillSteps.where((s) => s.programId == programId).toList();
    if (specialistId != null && specialistId.isNotEmpty) {
      filtered =
          filtered.where((s) => s.specialistId == specialistId).toList();
    }
    return filtered;
  }

  List<StudentFollowup> followupsForProgram(String programId) =>
      app.pendingFollowups.where((f) => f.programId == programId).toList();

  List<Exercise> exercisesForProgram(String programId) =>
      app.exercises.where((e) => e.programId == programId).toList();

  int goalProgressFromSteps(String goalId) {
    final steps =
        app.goalSkillSteps.where((s) => s.goalId == goalId).toList();
    if (steps.isEmpty) {
      final matches = app.plans.where((p) => p.id == goalId).toList();
      if (matches.isEmpty) return 0;
      final sessionMatches = app.sessions
          .where((s) => s.planId == goalId)
          .toList()
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
      if (sessionMatches.isEmpty) return matches.first.progress;
      switch (sessionMatches.first.quickResult) {
        case 'متقن':
          return 100;
        case 'بمساعدة':
          return 50;
        default:
          return 0;
      }
    }
    final completed = steps.where((s) => s.status == 'متقن').length;
    return ((completed / steps.length) * 100).round();
  }

  ProgramReportSection buildSection({
    required String programId,
    required String programName,
    required String specialistId,
    required String specialistName,
    required String studentId,
    String? dateFrom,
    String? dateTo,
  }) {
    final plans = plansForProgram(programId, specialistId: specialistId);
    final assessments =
        assessmentsForProgram(programId, studentId, specialistId: specialistId);
    final allFindings = <ClinicalFinding>[];
    for (final a in assessments) {
      allFindings.addAll(findingsForAssessment(a.id));
    }
    final goalSkillSteps = stepsForProgram(programId, specialistId: specialistId);
    final sessions = sessionsForProgram(programId, studentId,
        specialistId: specialistId, dateFrom: dateFrom, dateTo: dateTo);
    final followups = followupsForProgram(programId);
    final exercises = exercisesForProgram(programId);

    int overallProgress = 0;
    if (plans.isNotEmpty) {
      final totalProgress =
          plans.fold<int>(0, (sum, p) => sum + goalProgressFromSteps(p.id));
      overallProgress = (totalProgress / plans.length).round();
    }

    final mastered = plans.where((p) => goalProgressFromSteps(p.id) >= 100).length;
    final active = plans.where((p) => goalProgressFromSteps(p.id) < 100).length;
    final standardCount = plans.where((p) => p.sourceType == 'standard').length;
    final speechCount = plans.where((p) => p.sourceType == 'speechSound').length;

    return ProgramReportSection(
      programId: programId,
      programName: programName,
      specialistId: specialistId,
      specialistName: specialistName,
      assessments: assessments,
      findings: allFindings,
      plans: plans,
      goalSkillSteps: goalSkillSteps,
      sessions: sessions,
      followups: followups,
      exercises: exercises,
      overallProgress: overallProgress,
      masteredGoals: mastered,
      activeGoals: active,
      standardGoalCount: standardCount,
      speechSoundGoalCount: speechCount,
    );
  }

  ReportData build({
    required String studentId,
    required String type,
    required String scope,
    String? programId,
    String? specialistId,
    String? dateFrom,
    String? dateTo,
    String? createdByUserId,
    String? createdByName,
  }) {
    final student = app.students.where((s) => s.id == studentId).firstOrNull;
    if (student == null) {
      throw StateError('الطالب غير موجود.');
    }

    final sections = <ProgramReportSection>[];
    final programMap = {for (final p in app.therapyPrograms) p.id: p.name};
    final userMap = {for (final u in app.staff) u.id: u.name};

    if (scope == 'singleProgram' && programId != null) {
      final specId = specialistId ?? '';
      final specName = specId.isNotEmpty
          ? (userMap[specId] ?? '')
          : '';
      sections.add(buildSection(
        programId: programId,
        programName: programMap[programId] ?? 'برنامج غير معروف',
        specialistId: specId,
        specialistName: specName,
        studentId: studentId,
        dateFrom: dateFrom,
        dateTo: dateTo,
      ));
    } else if (scope == 'specialistPrograms' && specialistId != null && specialistId.isNotEmpty) {
      final assignedProgramIds = app.studentProgramAssignments
          .where((a) =>
              a.specialistId == specialistId &&
              a.studentId == studentId &&
              a.isActive &&
              a.centerId == app.activeCenterId)
          .map((a) => a.programId)
          .toSet()
          .toList();
      for (final pid in assignedProgramIds) {
        sections.add(buildSection(
          programId: pid,
          programName: programMap[pid] ?? 'برنامج غير معروف',
          specialistId: specialistId,
          specialistName: userMap[specialistId] ?? '',
          studentId: studentId,
          dateFrom: dateFrom,
          dateTo: dateTo,
        ));
      }
    } else {
      List<String> programIds;
      if (specialistId != null && specialistId.isNotEmpty && app.isSpecialist) {
        programIds = app.specialistCapabilityProgramIds;
      } else {
        programIds = app.studentProgramIds;
      }
      for (final pid in programIds) {
        final specId = specialistId ?? '';
        final specName = specId.isNotEmpty ? (userMap[specId] ?? '') : '';
        sections.add(buildSection(
          programId: pid,
          programName: programMap[pid] ?? 'برنامج غير معروف',
          specialistId: specId,
          specialistName: specName,
          studentId: studentId,
          dateFrom: dateFrom,
          dateTo: dateTo,
        ));
      }
    }

    final totalPlans = sections.fold(0, (sum, s) => sum + s.plans.length);
    int overallRate = 0;
    if (totalPlans > 0) {
      final totalProgress = sections.fold<int>(
          0, (sum, s) => sum + (s.overallProgress * s.plans.length));
      overallRate = (totalProgress / totalPlans).round();
    }

    return ReportData(
      student: student,
      center: app.currentCenter ?? app.currentCenter,
      type: type,
      scope: scope,
      dateFrom: dateFrom ?? '',
      dateTo: dateTo ?? '',
      createdByUserId: createdByUserId ?? '',
      createdByName: createdByName ?? '',
      sections: sections.where((s) =>
          s.assessments.isNotEmpty ||
          s.findings.isNotEmpty ||
          s.plans.isNotEmpty ||
          s.goalSkillSteps.isNotEmpty ||
          s.sessions.isNotEmpty ||
          s.followups.isNotEmpty ||
          s.exercises.isNotEmpty).toList(),
      overallImprovementRate: overallRate,
    );
  }
}
