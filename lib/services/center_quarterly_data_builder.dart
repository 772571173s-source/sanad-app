import '../models/app_models.dart';
import '../models/word_report_model.dart';
import '../providers/app_provider.dart';

class CenterQuarterlyDataBuilder {
  final AppProvider app;

  CenterQuarterlyDataBuilder({required this.app});

  /// Builds a [WordReportModel] with real Sanad data for the quarterly report.
  ///
  /// Expects [app] to already have the student's data loaded
  /// (via [AppProvider.selectStudent]).
  ///
  /// Provide either [periodNumber] (1-4) for standard periods,
  /// or [selectedMonths] for custom month selection.
  Future<WordReportModel> build({
    required String studentId,
    required int year,
    required String dateFrom,
    required String dateTo,
    int? periodNumber,
    List<int>? selectedMonths,
    String? programId,
  }) async {
    final student = app.students.firstWhere((s) => s.id == studentId);
    final centerName = app.currentCenter?.name ?? '';

    final months = selectedMonths ??
        (periodNumber != null ? monthsForReportPeriod(periodNumber) : [1, 2, 3, 4]);
    final monthLabels = months.map((m) => m.toString()).toList();

    final userNames = <String, String>{};
    for (final u in app.staff) {
      userNames[u.id] = u.name;
    }

    final programNames = <String, String>{};
    for (final p in app.therapyPrograms) {
      programNames[p.id] = p.name;
    }

    // Build a lookup from GoalSkillStep.id → goalId (TrainingPlan.id)
    // Used as fallback when sessions link via skillId instead of planId.
    final skillToGoalId = <String, String>{};
    for (final step in app.goalSkillSteps) {
      if (step.goalId.isNotEmpty) {
        skillToGoalId[step.id] = step.goalId;
      }
    }

    List<String> progIds;
    if (programId != null) {
      progIds = [programId];
    } else {
      progIds = app.plans
          .map((p) => p.programId)
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      if (progIds.isEmpty) {
        progIds = app.studentProgramIds;
      }
    }

    final plans = app.plans.where((p) => progIds.contains(p.programId)).toList();

    final sessionsInRange = app.sessions.where((s) {
      return s.startedAt.compareTo(dateFrom) >= 0 &&
          s.startedAt.compareTo(dateTo) <= 0;
    }).toList();

    final headerRow = WordReportRow(cells: [
      'نوع الخدمة',
      'مجال المهارة',
      'الأهداف الفصلية / المهارات التعليمية والتدريبية',
      ...monthLabels,
      'مقدم الخدمة',
    ]);

    final dataRows = <WordReportRow>[];
    for (final plan in plans) {
      final programName = programNames[plan.programId] ?? plan.programId;
      final skillArea = _skillArea(plan);
      final providerName = _providerName(plan, sessionsInRange, userNames);

      final monthScores = <String>[];
      for (final month in months) {
        monthScores.add(_scoreForMonth(plan, month, year, sessionsInRange, skillToGoalId));
      }

      dataRows.add(WordReportRow(cells: [
        programName,
        skillArea,
        plan.goal,
        ...monthScores,
        providerName,
      ]));
    }

    final title = periodNumber != null
        ? 'التقرير ${_periodArabic(periodNumber)} - $year'
        : 'التقرير - $year';

    return WordReportModel(
      centerName: centerName,
      studentName: student.name,
      dateRange: title,
      sections: [
        WordReportSection(
          sectionTitle: 'بيانات الجلسات',
          rows: [headerRow, ...dataRows],
        ),
      ],
    );
  }

  /// Returns the provider name, preferring the specialist from the last
  /// session for this plan in range, falling back to plan.specialistId.
  String _providerName(
    TrainingPlan plan,
    List<TherapySession> sessionsInRange,
    Map<String, String> userNames,
  ) {
    final planSessionsInRange =
        sessionsInRange.where((s) => _matchesPlan(s, plan.id)).toList();
    if (planSessionsInRange.isNotEmpty) {
      planSessionsInRange.sort((a, b) => a.startedAt.compareTo(b.startedAt));
      final last = planSessionsInRange.last;
      if (last.specialistId.isNotEmpty) {
        return userNames[last.specialistId] ?? last.specialistId;
      }
    }
    if (plan.specialistId.isNotEmpty) {
      return userNames[plan.specialistId] ?? plan.specialistId;
    }
    return '';
  }

  String _skillArea(TrainingPlan plan) {
    if (plan.sourceType == 'speechSound') return 'حروف النطق';
    if (plan.sourceType == 'standard') return 'مجال عام';
    return plan.sourceType;
  }

  /// Checks if a session matches the given [planId].
  ///
  /// Primary match: [session.planId] == [planId].
  /// Fallback: [session.skillId] → [GoalSkillStep.id] → [goalId] (TrainingPlan.id).
  bool _matchesPlan(TherapySession session, String planId) {
    if (session.planId == planId) return true;
    if (session.skillId.isNotEmpty) {
      // Fallback via skillId: session.skillId -> GoalSkillStep -> goalId -> TrainingPlan.id
      for (final step in app.goalSkillSteps) {
        if (step.id == session.skillId && step.goalId == planId) return true;
      }
    }
    return false;
  }

  String _scoreForMonth(
    TrainingPlan plan,
    int month,
    int year,
    List<TherapySession> sessions,
    Map<String, String> skillToGoalId,
  ) {
    final monthStr = _pad(month);
    final dateStr = '$year-$monthStr';
    final prefix = '$dateStr-';
    final nextPrefix = month == 12
        ? '${year + 1}-01-'
        : '${year}-${_pad(month + 1)}-';

    final matching = sessions.where((s) {
      if (!_matchesPlan(s, plan.id)) return false;
      return s.startedAt.compareTo(prefix) >= 0 &&
          s.startedAt.compareTo(nextPrefix) < 0;
    }).toList();

    if (matching.isEmpty) return '';

    matching.sort((a, b) => a.startedAt.compareTo(b.startedAt));
    final lastSession = matching.last;

    // TODO: When attendance/holiday system is built:
    //   - If student was absent the whole month → 'غ'
    //   - If month is a holiday → 'ج'
    // For now, only show scores from actual sessions.
    return quickResultToScore(lastSession.quickResult);
  }

  static String quickResultToScore(String quickResult) {
    switch (quickResult) {
      case 'متقن':
        return '2';
      case 'بمساعدة':
        return '1';
      case 'خطأ':
      case 'يحتاج إعادة':
      case 'لم يبدأ':
        return '0';
      default:
        return '';
    }
  }

  /// Returns the month list for the given report [periodNumber] (1-4).
  ///
  /// Period 1 covers months  1–4 (e.g. Sep–Dec or Jan–Apr depending on center).
  /// Period 2 covers months 5–7.
  /// Period 3 covers months 8–10.
  /// Period 4 covers months 11–12.
  static List<int> monthsForReportPeriod(int periodNumber) {
    switch (periodNumber) {
      case 1:
        return [1, 2, 3, 4];
      case 2:
        return [5, 6, 7];
      case 3:
        return [8, 9, 10];
      case 4:
        return [11, 12];
      default:
        return [1, 2, 3, 4];
    }
  }

  static String _periodArabic(int periodNumber) {
    switch (periodNumber) {
      case 1:
        return 'الأول';
      case 2:
        return 'الثاني';
      case 3:
        return 'الثالث';
      case 4:
        return 'الرابع';
      default:
        return '';
    }
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
