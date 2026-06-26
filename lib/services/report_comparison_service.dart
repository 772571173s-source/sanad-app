import 'dart:convert';

import 'report_data_builder.dart';

class GoalProgressChange {
  final String goalTitle;
  final String planId;
  final int previousProgress;
  final int currentProgress;
  final int delta;

  const GoalProgressChange({
    required this.goalTitle,
    required this.planId,
    required this.previousProgress,
    required this.currentProgress,
    required this.delta,
  });
}

class ReportComparisonResult {
  final List<GoalProgressChange> goalsProgressChanged;
  final List<GoalProgressChange> masteredGoals;
  final List<String> stagnantGoalIds;
  final List<String> newGoalIds;
  final List<String> allPreviousGoalIds;
  final int sessionsSincePreviousReport;
  final List<String> remainingWeaknesses;
  final List<String> improvedWeaknesses;

  const ReportComparisonResult({
    this.goalsProgressChanged = const [],
    this.masteredGoals = const [],
    this.stagnantGoalIds = const [],
    this.newGoalIds = const [],
    this.allPreviousGoalIds = const [],
    this.sessionsSincePreviousReport = 0,
    this.remainingWeaknesses = const [],
    this.improvedWeaknesses = const [],
  });
}

class ReportComparisonService {
  /// Parse the snapshot JSON saved in a previous ReportRecord.
  static Map<String, dynamic> parseSnapshot(String snapshotJson) {
    if (snapshotJson.isEmpty) return {};
    try {
      return jsonDecode(snapshotJson) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  /// Compare a previous report snapshot with current ReportData.
  static ReportComparisonResult compare({
    required Map<String, dynamic> previousSnapshot,
    required ReportData currentData,
  }) {
    if (previousSnapshot.isEmpty) {
      return const ReportComparisonResult();
    }

    final prevGoals = _parseGoalsFromSnapshot(previousSnapshot);
    final prevGoalIds = prevGoals.keys.toList();
    final currentPlanIds = <String>{};
    for (final section in currentData.sections) {
      for (final plan in section.plans) {
        currentPlanIds.add(plan.id);
      }
    }

    final currentProgress = <String, int>{};
    for (final section in currentData.sections) {
      for (final plan in section.plans) {
        currentProgress[plan.id] = _goalProgressFromSection(section, plan.id);
      }
    }

    final changed = <GoalProgressChange>[];
    final mastered = <GoalProgressChange>[];
    final stagnant = <String>[];
    final newGoals = <String>[];

    for (final entry in prevGoals.entries) {
      final planId = entry.key;
      final prevProg = entry.value;
      if (currentPlanIds.contains(planId)) {
        final currProg = currentProgress[planId] ?? 0;
        if (currProg > prevProg) {
          final title = _findGoalTitle(planId, currentData) ?? planId;
          changed.add(GoalProgressChange(
            goalTitle: title,
            planId: planId,
            previousProgress: prevProg,
            currentProgress: currProg,
            delta: currProg - prevProg,
          ));
          if (currProg >= 100) {
            mastered.add(GoalProgressChange(
              goalTitle: title,
              planId: planId,
              previousProgress: prevProg,
              currentProgress: currProg,
              delta: currProg - prevProg,
            ));
          }
        } else if (currProg == prevProg && currProg < 100) {
          stagnant.add(planId);
        }
      } else {
        newGoals.add(planId);
      }
    }

    for (final planId in currentPlanIds) {
      if (!prevGoals.containsKey(planId)) {
        newGoals.add(planId);
      }
    }

    final prevSessionsCount = previousSnapshot['totalSessions'] as int? ?? 0;
    final sessionsSince =
        currentData.totalSessions - prevSessionsCount;

    final prevWeaknesses = _parseWeaknessesFromSnapshot(previousSnapshot);
    final remainingWeaknesses = <String>[];
    final improvedWeaknesses = <String>[];
    for (final w in prevWeaknesses) {
      if (currentData.sections.any((s) =>
          s.findings.any((f) => f.itemTitle.contains(w) || w.contains(f.itemTitle)))) {
        remainingWeaknesses.add(w);
      } else {
        improvedWeaknesses.add(w);
      }
    }

    return ReportComparisonResult(
      goalsProgressChanged: changed,
      masteredGoals: mastered,
      stagnantGoalIds: stagnant,
      newGoalIds: newGoals,
      allPreviousGoalIds: prevGoalIds,
      sessionsSincePreviousReport: sessionsSince >= 0 ? sessionsSince : 0,
      remainingWeaknesses: remainingWeaknesses,
      improvedWeaknesses: improvedWeaknesses,
    );
  }

  static Map<String, int> _parseGoalsFromSnapshot(
      Map<String, dynamic> snapshot) {
    final result = <String, int>{};
    final sections = snapshot['sections'] as List<dynamic>? ?? [];
    for (final section in sections) {
      final plans = section['plans'] as List<dynamic>? ?? [];
      for (final plan in plans) {
        final id = plan['id'] as String? ?? '';
        final progress = plan['progress'] as int? ?? 0;
        if (id.isNotEmpty) result[id] = progress;
      }
    }
    return result;
  }

  static List<String> _parseWeaknessesFromSnapshot(
      Map<String, dynamic> snapshot) {
    final result = <String>[];
    final sections = snapshot['sections'] as List<dynamic>? ?? [];
    for (final section in sections) {
      final findings = section['findings'] as List<dynamic>? ?? [];
      for (final finding in findings) {
        final title = finding['itemTitle'] as String? ?? '';
        if (title.isNotEmpty) result.add(title);
      }
    }
    return result;
  }

  static String? _findGoalTitle(
      String planId, ReportData currentData) {
    for (final section in currentData.sections) {
      for (final plan in section.plans) {
        if (plan.id == planId) return plan.goal;
      }
    }
    return null;
  }

  static int _goalProgressFromSection(
      ProgramReportSection section, String planId) {
    final steps =
        section.goalSkillSteps.where((s) => s.goalId == planId).toList();
    if (steps.isEmpty) {
      final matches = section.sessions
          .where((s) => s.planId == planId)
          .toList()
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
      if (matches.isEmpty) return 0;
      switch (matches.first.quickResult) {
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
}
