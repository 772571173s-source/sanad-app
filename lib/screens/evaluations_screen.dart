import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../widgets/app_widgets.dart';
import '../widgets/feedback.dart';

class EvaluationsScreen extends StatefulWidget {
  const EvaluationsScreen({super.key});

  @override
  State<EvaluationsScreen> createState() => _EvaluationsScreenState();
}

class _EvaluationsScreenState extends State<EvaluationsScreen> {
  int stepIndex = 0;
  bool summaryMode = false;
  bool saved = false;
  final selections = <String, _AssessmentChoice>{};

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final student = app.selectedStudent;
    if (student == null) {
      return const EmptyState(
        icon: Icons.fact_check_outlined,
        title: 'اختر طالبًا قبل التقييم',
        message:
            'افتح شاشة الطلاب واختر الطالب، ثم ابدأ التقييم العلاجي من ملفه.',
      );
    }

    final steps = _buildSteps(app);
    if (steps.isEmpty) {
      return const EmptyState(
        icon: Icons.schema_outlined,
        title: 'لا توجد قوالب تقييم جاهزة',
        message:
            'هذه الشاشة تستخدم قوالب Therapy Structure Builder. افتح شاشة بناء الهيكل العلاجي وأدخل الأقسام والبنود والاحتمالات أولًا.',
      );
    }
    if (stepIndex >= steps.length) stepIndex = 0;
    final complete = selections.length == steps.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TherapyCard(
          icon: Icons.psychology_alt_outlined,
          title: 'Clinical Assessment Wizard',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ProgressHeader(
                stepIndex: summaryMode ? steps.length : stepIndex,
                total: steps.length,
                complete: complete,
              ),
              const SizedBox(height: AppSpacing.md),
              if (summaryMode)
                _AssessmentSummary(
                  steps: steps,
                  selections: selections,
                  saved: saved,
                  onBack: () => setState(() => summaryMode = false),
                  onSave: saved ? null : () => _save(app, student, steps),
                )
              else
                _AssessmentStepCard(
                  step: steps[stepIndex],
                  selected: selections[steps[stepIndex].id],
                  onSelected: (choice) => setState(() {
                    selections[steps[stepIndex].id] = choice;
                    saved = false;
                  }),
                  onPrevious:
                      stepIndex == 0 ? null : () => setState(() => stepIndex--),
                  onNext: selections[steps[stepIndex].id] == null
                      ? null
                      : () => setState(() {
                            if (stepIndex == steps.length - 1) {
                              summaryMode = true;
                            } else {
                              stepIndex++;
                            }
                          }),
                  nextLabel:
                      stepIndex == steps.length - 1 ? 'عرض الملخص' : 'التالي',
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _PreviousClinicalAssessments(app: app),
      ],
    );
  }

  List<_AssessmentStep> _buildSteps(AppProvider app) {
    final steps = <_AssessmentStep>[];
    for (final section in app.assessmentSections) {
      final items = app.assessmentItems
          .where((item) => item.sectionId == section.id)
          .toList();
      for (final item in items) {
        final options = app.assessmentOptions
            .where((option) => option.itemId == item.id)
            .map((option) => _AssessmentChoice(
                  label: option.label,
                  isNormal: !option.generatesTherapy,
                  weakness: option.weaknessTemplate,
                  goal: option.goalTemplate,
                  training: option.therapyTemplate,
                ))
            .toList();
        if (options.isEmpty) continue;
        steps.add(_AssessmentStep(
          id: item.id,
          domain: section.title,
          title: item.title,
          question: item.prompt.isEmpty
              ? 'اختر نتيجة البند حسب ملاحظة الأخصائي.'
              : item.prompt,
          options: options,
        ));
      }
    }
    if (app.speechSoundTriggers.isNotEmpty) {
      steps.add(_AssessmentStep(
        id: 'speech_sound_matrix',
        domain: 'الحروف',
        title: 'Speech Sound Matrix Assessment',
        question:
            'اختر الخلية السريرية المناسبة: الحرف، نوع الخطأ، وموقعه داخل الكلمة.',
        options: app.speechSoundTriggers
            .map((trigger) => _AssessmentChoice(
                  label:
                      '${trigger.letter} - ${trigger.errorType} - ${trigger.position}',
                  isNormal: !trigger.generatesTherapy,
                  weakness: trigger.weaknessTemplate,
                  goal: trigger.goalTemplate,
                  training: trigger.therapyTemplate,
                ))
            .toList(),
      ));
    }
    return steps;
  }

  Future<void> _save(
    AppProvider app,
    Student student,
    List<_AssessmentStep> steps,
  ) async {
    final now = DateTime.now().toIso8601String();
    final assessmentId = 'clinical_${DateTime.now().millisecondsSinceEpoch}';
    final strengths = steps
        .where((step) => selections[step.id]?.isNormal == true)
        .map((step) => '${step.title}: طبيعي')
        .join('\n');
    final weakChoices = steps
        .where((step) => selections[step.id]?.isNormal == false)
        .map((step) => MapEntry(step, selections[step.id]!))
        .toList();
    final weaknesses = weakChoices
        .map((entry) => '${entry.key.title}: ${entry.value.weakness}')
        .join('\n');
    final goals = weakChoices
        .map((entry) => entry.value.goal)
        .where((value) => value.trim().isNotEmpty)
        .join('\n');
    final trainings = weakChoices
        .map((entry) => entry.value.training)
        .where((value) => value.trim().isNotEmpty)
        .join('\n');

    await runWithFeedback(
      context,
      () async {
        await app.saveClinicalAssessment(
          assessment: ClinicalAssessment(
            id: assessmentId,
            centerId: student.centerId,
            studentId: student.id,
            specialistId: app.user?.id ?? '',
            specialistName: app.user?.name ?? '',
            type: 'speech',
            strengthsSummary: strengths,
            weaknessesSummary: weaknesses,
            goalsSummary: goals,
            trainingSummary: trainings,
            createdAt: now,
          ),
          findings: steps.map((step) {
            final choice = selections[step.id]!;
            return ClinicalFinding(
              id: 'finding_${step.id}_${DateTime.now().microsecondsSinceEpoch}',
              assessmentId: assessmentId,
              centerId: student.centerId,
              studentId: student.id,
              domain: step.domain,
              itemTitle: step.title,
              result: choice.label,
              isNormal: choice.isNormal,
              weakness: choice.weakness,
              goal: choice.goal,
              training: choice.training,
              createdAt: now,
            );
          }).toList(),
        );
        setState(() => saved = true);
      },
      loading: 'جاري حفظ التقييم العلاجي...',
      success: 'تم حفظ التقييم وتوليد الأهداف العلاجية.',
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.stepIndex,
    required this.total,
    required this.complete,
  });

  final int stepIndex;
  final int total;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final value = total == 0 ? 0.0 : stepIndex / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            AppPill(
              label:
                  complete ? 'جاهز للملخص' : 'خطوة ${stepIndex + 1} من $total',
              icon: Icons.route_outlined,
              selected: true,
            ),
            const AppPill(
              label: 'يستخدم القوالب العلاجية الجاهزة',
              icon: Icons.schema_outlined,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        LinearProgressIndicator(value: value.clamp(0, 1)),
      ],
    );
  }
}

class _AssessmentStepCard extends StatelessWidget {
  const _AssessmentStepCard({
    required this.step,
    required this.selected,
    required this.onSelected,
    required this.onPrevious,
    required this.onNext,
    required this.nextLabel,
  });

  final _AssessmentStep step;
  final _AssessmentChoice? selected;
  final ValueChanged<_AssessmentChoice> onSelected;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final String nextLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(step.domain, style: SanadText.muted(context)),
        const SizedBox(height: AppSpacing.xs),
        Text(step.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(step.question, style: SanadText.secondary(context)),
        const SizedBox(height: AppSpacing.lg),
        ResponsiveGrid(
          children: step.options.map((choice) {
            final active = selected?.label == choice.label;
            return InkWell(
              borderRadius: BorderRadius.circular(AppRadii.card),
              onTap: () => onSelected(choice),
              child: AppCard(
                highlight: active,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          choice.isNormal
                              ? Icons.verified_outlined
                              : Icons.flag_outlined,
                          color: active
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            choice.label,
                            style: SanadText.subtitle(context),
                          ),
                        ),
                      ],
                    ),
                    if (!choice.isNormal && choice.goal.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(choice.goal, style: SanadText.secondary(context)),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            FilledButton.tonalIcon(
              onPressed: onPrevious,
              icon: const Icon(Icons.arrow_back),
              label: const Text('السابق'),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: onNext,
              icon: const Icon(Icons.arrow_forward),
              label: Text(nextLabel),
            ),
          ],
        ),
      ],
    );
  }
}

class _AssessmentSummary extends StatelessWidget {
  const _AssessmentSummary({
    required this.steps,
    required this.selections,
    required this.saved,
    required this.onBack,
    required this.onSave,
  });

  final List<_AssessmentStep> steps;
  final Map<String, _AssessmentChoice> selections;
  final bool saved;
  final VoidCallback onBack;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final strengths = steps
        .where((step) => selections[step.id]?.isNormal == true)
        .map((step) => '${step.title}: طبيعي')
        .toList();
    final weaknesses = steps
        .where((step) => selections[step.id]?.isNormal == false)
        .map((step) => MapEntry(step, selections[step.id]!))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SemanticAlertCard(
          kind: SemanticAlertKind.info,
          icon: Icons.summarize_outlined,
          title: 'ملخص التقييم العلاجي',
          message:
              'راجع جوانب القوة والضعف والأهداف المقترحة قبل حفظها داخل ملف الطالب.',
        ),
        const SizedBox(height: AppSpacing.md),
        _SummaryPanel(
          title: 'جوانب القوة',
          icon: Icons.verified_outlined,
          empty: 'لا توجد بنود قوة في هذا التقييم.',
          items: strengths,
        ),
        const SizedBox(height: AppSpacing.md),
        _SummaryPanel(
          title: 'جوانب الضعف',
          icon: Icons.flag_outlined,
          empty: 'لا توجد نقاط ضعف مولدة.',
          items: weaknesses
              .map((entry) => '${entry.key.title}: ${entry.value.weakness}')
              .toList(),
        ),
        const SizedBox(height: AppSpacing.md),
        _SummaryPanel(
          title: 'الأهداف والتدريبات المقترحة',
          icon: Icons.track_changes_outlined,
          empty: 'لا توجد أهداف لأن كل البنود المحددة لا تولد علاجًا.',
          items: weaknesses
              .map((entry) =>
                  '${entry.value.goal}\nالتدريب: ${entry.value.training}')
              .toList(),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            FilledButton.tonalIcon(
              onPressed: onBack,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('مراجعة الخطوات'),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: onSave,
              icon: Icon(saved ? Icons.check_circle : Icons.save_outlined),
              label: Text(saved ? 'تم الحفظ' : 'حفظ داخل ملف الطالب'),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({
    required this.title,
    required this.icon,
    required this.empty,
    required this.items,
  });

  final String title;
  final IconData icon;
  final String empty;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(title, style: SanadText.subtitle(context))),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (items.isEmpty)
            Text(empty, style: SanadText.secondary(context))
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(item, style: SanadText.secondary(context)),
              ),
            ),
        ],
      ),
    );
  }
}

class _PreviousClinicalAssessments extends StatelessWidget {
  const _PreviousClinicalAssessments({required this.app});

  final AppProvider app;

  @override
  Widget build(BuildContext context) {
    if (app.clinicalAssessments.isEmpty) {
      return const EmptyState(
        icon: Icons.history_edu_outlined,
        title: 'لا توجد تقييمات علاجية محفوظة',
        message: 'بعد حفظ أول تقييم سيظهر هنا داخل ملف الطالب.',
      );
    }
    return TherapyCard(
      icon: Icons.folder_special_outlined,
      title: 'التقييمات العلاجية المحفوظة',
      child: Column(
        children: app.clinicalAssessments.map((assessment) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.fact_check_outlined),
            title:
                Text('تقييم نطقي - ${assessment.createdAt.split('T').first}'),
            subtitle: Text(
              assessment.weaknessesSummary.isEmpty
                  ? 'كل البنود المحددة لا تولد علاجًا.'
                  : assessment.weaknessesSummary,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AssessmentStep {
  const _AssessmentStep({
    required this.id,
    required this.domain,
    required this.title,
    required this.question,
    required this.options,
  });

  final String id;
  final String domain;
  final String title;
  final String question;
  final List<_AssessmentChoice> options;
}

class _AssessmentChoice {
  const _AssessmentChoice({
    required this.label,
    required this.isNormal,
    this.weakness = '',
    this.goal = '',
    this.training = '',
  });

  final String label;
  final bool isNormal;
  final String weakness;
  final String goal;
  final String training;
}
