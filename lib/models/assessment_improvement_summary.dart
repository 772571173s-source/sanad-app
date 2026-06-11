import 'app_models.dart';

class AssessmentImprovementSummary {
  final bool hasEnoughData;
  final String? previousAssessmentId;
  final String? currentAssessmentId;
  final String? previousDate;
  final String? currentDate;
  final int baseWeaknessCount;
  final int improvedCount;
  final int unchangedWeaknessCount;
  final double improvementRate;
  final int regressionCount;
  final int newFindingCount;
  final int missingCount;
  final int stableNormalCount;

  const AssessmentImprovementSummary({
    required this.hasEnoughData,
    this.previousAssessmentId,
    this.currentAssessmentId,
    this.previousDate,
    this.currentDate,
    this.baseWeaknessCount = 0,
    this.improvedCount = 0,
    this.unchangedWeaknessCount = 0,
    this.improvementRate = 0,
    this.regressionCount = 0,
    this.newFindingCount = 0,
    this.missingCount = 0,
    this.stableNormalCount = 0,
  });

  static AssessmentImprovementSummary compute(
    String studentId,
    List<ClinicalAssessment> allAssessments,
    Map<String, List<ClinicalFinding>> findingsByAssessment,
  ) {
    final studentAssessments = allAssessments
        .where((a) => a.studentId == studentId)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    if (studentAssessments.length < 2) {
      return const AssessmentImprovementSummary(hasEnoughData: false);
    }

    final previous = studentAssessments[studentAssessments.length - 2];
    final current = studentAssessments.last;

    final prevFindings = findingsByAssessment[previous.id] ?? [];
    final currFindings = findingsByAssessment[current.id] ?? [];

    final prevByTemplate = <String, ClinicalFinding>{};
    for (final f in prevFindings) {
      if (f.templateId.isNotEmpty) {
        prevByTemplate[f.templateId] = f;
      }
    }
    final currByTemplate = <String, ClinicalFinding>{};
    for (final f in currFindings) {
      if (f.templateId.isNotEmpty) {
        currByTemplate[f.templateId] = f;
      }
    }

    final allIds = {...prevByTemplate.keys, ...currByTemplate.keys};

    int baseWeakness = 0;
    int improved = 0;
    int unchangedWeakness = 0;
    int regression = 0;
    int newFinding = 0;
    int missing = 0;
    int stableNormal = 0;

    for (final id in allIds) {
      final prev = prevByTemplate[id];
      final curr = currByTemplate[id];

      if (prev != null && curr != null) {
        if (!prev.isNormal && curr.isNormal) {
          baseWeakness++;
          improved++;
        } else if (!prev.isNormal && !curr.isNormal) {
          baseWeakness++;
          unchangedWeakness++;
        } else if (prev.isNormal && !curr.isNormal) {
          regression++;
        } else {
          stableNormal++;
        }
      } else if (prev != null && curr == null) {
        missing++;
        if (!prev.isNormal) {
          baseWeakness++;
        }
      } else if (prev == null && curr != null) {
        newFinding++;
      }
    }

    final rate = baseWeakness > 0 ? (improved / baseWeakness) * 100 : 0.0;

    return AssessmentImprovementSummary(
      hasEnoughData: true,
      previousAssessmentId: previous.id,
      currentAssessmentId: current.id,
      previousDate: previous.createdAt,
      currentDate: current.createdAt,
      baseWeaknessCount: baseWeakness,
      improvedCount: improved,
      unchangedWeaknessCount: unchangedWeakness,
      improvementRate: rate,
      regressionCount: regression,
      newFindingCount: newFinding,
      missingCount: missing,
      stableNormalCount: stableNormal,
    );
  }
}
