import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../widgets/app_widgets.dart';
import '../widgets/feedback.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  final selectedStepIds = <String>{};
  final stepResults = <String, String>{};
  final notes = TextEditingController();
  final sessionFocus = FocusNode();
  Timer? timer;
  int seconds = 0;
  int stepIndex = 0;
  int homeworkSentCount = 0;
  bool sessionStarted = false;
  bool autoMoveToNext = true;
  _ClinicalSessionSummary? lastSummary;

  @override
  void dispose() {
    timer?.cancel();
    notes.dispose();
    sessionFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final student = app.selectedStudent;
    final selectedSteps = _selectedSteps(app);
    if (stepIndex >= selectedSteps.length) stepIndex = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!sessionStarted) ...[
          _ClinicalSetupCard(
            app: app,
            selectedStepIds: selectedStepIds,
            onStudentChanged: (student) async {
              await app.selectStudent(student);
              setState(_resetForStudent);
            },
            onStepChanged: (stepId, selected) {
              setState(() {
                if (selected) {
                  selectedStepIds.add(stepId);
                } else {
                  selectedStepIds.remove(stepId);
                  stepResults.remove(stepId);
                }
                stepIndex = 0;
                lastSummary = null;
              });
            },
            onStart: selectedSteps.isEmpty ? null : _startSession,
          ),
          const SizedBox(height: AppSpacing.md),
          if (lastSummary != null) ...[
            _ClinicalSessionSummaryCard(summary: lastSummary!),
            const SizedBox(height: AppSpacing.md),
          ],
          _PreviousGoalSessions(app: app),
        ] else if (student != null && selectedSteps.isNotEmpty) ...[
          Focus(
            focusNode: sessionFocus,
            autofocus: true,
            onKeyEvent: (node, event) => _handleKey(event, selectedSteps),
            child: _GoalFocusSessionCard(
              step: selectedSteps[stepIndex],
              goal: _goalForStep(app, selectedSteps[stepIndex]),
              index: stepIndex,
              total: selectedSteps.length,
              completedCount: stepResults.length,
              selectedValue: stepResults[selectedSteps[stepIndex].id],
              elapsedSeconds: seconds,
              masteryRate: _masteryRate(selectedSteps),
              homeworkSentCount: homeworkSentCount,
              autoMoveToNext: autoMoveToNext,
              notes: notes,
              onEvaluate: (value) => _evaluateStep(value, selectedSteps),
              onPrevious:
                  stepIndex == 0 ? null : () => setState(() => stepIndex--),
              onNext: stepIndex >= selectedSteps.length - 1
                  ? null
                  : () => setState(() => stepIndex++),
              onToggleAutoMove: (value) =>
                  setState(() => autoMoveToNext = value),
              onQuickNote: _addQuickNote,
              onSendHomework: () => _sendSmartHomework(app, selectedSteps),
              onSave: () => _saveClinicalSession(app, selectedSteps),
              onStop: _stopSession,
            ),
          ),
        ],
      ],
    );
  }

  List<GoalSkillStep> _selectedSteps(AppProvider app) => app.goalSkillSteps
      .where((step) => selectedStepIds.contains(step.id))
      .toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  void _resetForStudent() {
    selectedStepIds.clear();
    stepResults.clear();
    stepIndex = 0;
    homeworkSentCount = 0;
    sessionStarted = false;
    lastSummary = null;
    notes.clear();
  }

  void _startSession() {
    setState(() {
      sessionStarted = true;
      stepIndex = 0;
      seconds = 0;
      homeworkSentCount = 0;
      stepResults.clear();
    });
    timer?.cancel();
    timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => seconds++),
    );
  }

  void _stopSession() {
    timer?.cancel();
    setState(() => sessionStarted = false);
  }

  void _evaluateStep(String value, List<GoalSkillStep> steps) {
    if (steps.isEmpty) return;
    setState(() {
      stepResults[steps[stepIndex].id] = value;
      if (autoMoveToNext && stepIndex < steps.length - 1) {
        stepIndex++;
      }
    });
  }

  KeyEventResult _handleKey(KeyEvent event, List<GoalSkillStep> steps) {
    if (event is! KeyDownEvent || steps.isEmpty) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) {
      _evaluateStep('بمساعدة', steps);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) {
      _evaluateStep('جزئي', steps);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit3 || key == LogicalKeyboardKey.numpad3) {
      _evaluateStep('مستقل', steps);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit4 || key == LogicalKeyboardKey.numpad4) {
      _evaluateStep('متقن', steps);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight && stepIndex > 0) {
      setState(() => stepIndex--);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft && stepIndex < steps.length - 1) {
      setState(() => stepIndex++);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  TrainingPlan? _goalForStep(AppProvider app, GoalSkillStep step) {
    for (final plan in app.plans) {
      if (plan.id == step.goalId) return plan;
    }
    return null;
  }

  int _masteryRate(List<GoalSkillStep> steps) {
    if (steps.isEmpty) return 0;
    final mastered =
        stepResults.values.where((value) => value == 'متقن').length;
    return ((mastered / steps.length) * 100).round();
  }

  Future<void> _sendSmartHomework(
      AppProvider app, List<GoalSkillStep> steps) async {
    final student = app.selectedStudent;
    final items = steps.where((step) {
      final result = stepResults[step.id] ?? step.status;
      return result != 'متقن';
    }).toList();
    if (student == null || items.isEmpty) return;
    await runWithFeedback(context, () async {
      await app.saveExercise(Exercise(
        id: 'exercise_${DateTime.now().millisecondsSinceEpoch}',
        centerId: student.centerId,
        studentId: student.id,
        title: 'واجب علاجي من أهداف الجلسة',
        instructions: items
            .map((step) => 'تدريب يومي: ${step.title} لمدة 5 دقائق.')
            .join('\n'),
        dueDate: DateTime.now()
            .add(const Duration(days: 1))
            .toIso8601String()
            .split('T')
            .first,
        status: 'مرسل',
      ));
      setState(() => homeworkSentCount++);
    }, success: 'تم إرسال واجب ذكي من المهارات غير المكتملة.');
  }

  Future<void> _saveClinicalSession(
      AppProvider app, List<GoalSkillStep> steps) async {
    final student = app.selectedStudent;
    if (student == null) return;
    await runWithFeedback(context, () async {
      if (stepResults.isEmpty) {
        throw StateError('حدّث حالة مهارة واحدة على الأقل قبل حفظ الجلسة.');
      }
      final sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
      final now = DateTime.now().toIso8601String();
      final rate = _masteryRate(steps);
      final summary = _ClinicalSessionSummary(
        stepsCount: steps.length,
        updatedCount: stepResults.length,
        masteryRate: rate,
        homeworkSentCount: homeworkSentCount,
        notes: notes.text.trim(),
      );
      await app.saveSession(TherapySession(
        id: sessionId,
        centerId: student.centerId,
        studentId: student.id,
        planId: steps.first.goalId,
        activityResults:
            stepResults.entries.map((e) => '${e.key}:${e.value}').join('|'),
        sessionType: 'جلسة علاجية مبنية على هدف',
        practiceItems: steps.map((step) => step.title).join('، '),
        attempts: stepResults.length,
        successRate: rate,
        startedAt: now,
        durationSeconds: seconds,
        cardTitle: 'تتبع هدف علاجي',
        quickResult: stepResults.values.last,
        notes: notes.text.trim(),
        summary:
            'تم تحديث ${stepResults.length} من ${steps.length} مهارات. نسبة الإتقان داخل الجلسة $rate%.',
        createdAt: now,
        updatedAt: now,
      ));
      for (final step in steps) {
        final status = stepResults[step.id];
        if (status == null) continue;
        await app.updateGoalSkillStepStatus(
          step: step,
          status: status,
          notes: notes.text.trim(),
          lastSessionId: sessionId,
        );
      }
      await app.selectStudent(student);
      timer?.cancel();
      setState(() {
        sessionStarted = false;
        stepIndex = 0;
        seconds = 0;
        stepResults.clear();
        selectedStepIds.clear();
        homeworkSentCount = 0;
        lastSummary = summary;
        notes.clear();
      });
    }, success: 'تم حفظ الجلسة وتحديث رحلة الهدف.');
  }

  void _addQuickNote(String value) {
    final current = notes.text.trim();
    notes.text = current.isEmpty ? value : '$current، $value';
    notes.selection = TextSelection.collapsed(offset: notes.text.length);
  }
}

class _ClinicalSetupCard extends StatelessWidget {
  const _ClinicalSetupCard({
    required this.app,
    required this.selectedStepIds,
    required this.onStudentChanged,
    required this.onStepChanged,
    required this.onStart,
  });

  final AppProvider app;
  final Set<String> selectedStepIds;
  final ValueChanged<Student?> onStudentChanged;
  final void Function(String stepId, bool selected) onStepChanged;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final student = app.selectedStudent;
    return TherapyCard(
      title: 'الجلسة العلاجية الموجهة بالأهداف',
      icon: Icons.psychology_alt_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SemanticAlertCard(
            kind: SemanticAlertKind.info,
            icon: Icons.account_tree_outlined,
            title: 'Clinical Core',
            message:
                'مسار الجلسة الآن يبدأ من التقييم ونقاط الضعف ثم الأهداف والمهارات، وليس من برامج وأنشطة عامة.',
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: student?.id,
            decoration: const InputDecoration(labelText: 'الطالب'),
            items: app.students
                .map((item) => DropdownMenuItem(
                      value: item.id,
                      child: Text(item.name, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (value) {
              final matches =
                  app.students.where((item) => item.id == value).toList();
              onStudentChanged(matches.isEmpty ? null : matches.first);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          if (student == null)
            const EmptyState(
              icon: Icons.person_search_outlined,
              title: 'اختر طالبًا أولًا',
              message:
                  'بعد اختيار الطالب ستظهر أهدافه العلاجية الحالية والمهارات التي تحتاج تدريب.',
            )
          else
            _GoalStepPicker(
              app: app,
              selectedStepIds: selectedStepIds,
              onStepChanged: onStepChanged,
            ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow),
              label: Text('ابدأ جلسة هدف (${selectedStepIds.length})'),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalStepPicker extends StatelessWidget {
  const _GoalStepPicker({
    required this.app,
    required this.selectedStepIds,
    required this.onStepChanged,
  });

  final AppProvider app;
  final Set<String> selectedStepIds;
  final void Function(String stepId, bool selected) onStepChanged;

  @override
  Widget build(BuildContext context) {
    final activeGoals =
        app.plans.where((plan) => app.goalStatus(plan.id) != 'مكتمل').toList();
    if (activeGoals.isEmpty) {
      return const EmptyState(
        icon: Icons.track_changes_outlined,
        title: 'لا توجد أهداف علاجية نشطة',
        message:
            'ابدأ من شاشة التقييم العلاجي. أي نتيجة غير طبيعية ستنشئ هدفًا ومهارات تدريب تلقائيًا.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('الأهداف الحالية', style: SanadText.subtitle(context)),
        const SizedBox(height: AppSpacing.sm),
        ...activeGoals.map((goal) {
          final steps = app
              .stepsForGoal(goal.id)
              .where((step) => step.status != 'متقن')
              .toList();
          if (steps.isEmpty) return const SizedBox.shrink();
          final progress = app.goalProgress(goal.id);
          return Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                        child: Text(goal.goal,
                            style: SanadText.subtitle(context))),
                    AppPill(label: app.goalStatus(goal.id)),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                LinearProgressIndicator(value: progress / 100),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: steps.map((step) {
                    final selected = selectedStepIds.contains(step.id);
                    return FilterChip(
                      selected: selected,
                      label: Text('${step.title} - ${step.status}'),
                      onSelected: (value) => onStepChanged(step.id, value),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _GoalFocusSessionCard extends StatelessWidget {
  const _GoalFocusSessionCard({
    required this.step,
    required this.goal,
    required this.index,
    required this.total,
    required this.completedCount,
    required this.selectedValue,
    required this.elapsedSeconds,
    required this.masteryRate,
    required this.homeworkSentCount,
    required this.autoMoveToNext,
    required this.notes,
    required this.onEvaluate,
    required this.onPrevious,
    required this.onNext,
    required this.onToggleAutoMove,
    required this.onQuickNote,
    required this.onSendHomework,
    required this.onSave,
    required this.onStop,
  });

  final GoalSkillStep step;
  final TrainingPlan? goal;
  final int index;
  final int total;
  final int completedCount;
  final String? selectedValue;
  final int elapsedSeconds;
  final int masteryRate;
  final int homeworkSentCount;
  final bool autoMoveToNext;
  final TextEditingController notes;
  final ValueChanged<String> onEvaluate;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<bool> onToggleAutoMove;
  final ValueChanged<String> onQuickNote;
  final VoidCallback onSendHomework;
  final VoidCallback onSave;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    const options = ['بمساعدة', 'جزئي', 'مستقل', 'متقن'];
    final progress = total == 0 ? 0.0 : (index + 1) / total;
    return TherapyCard(
      title: 'Focus Therapy Mode',
      icon: Icons.center_focus_strong_outlined,
      trailing: AppPill(
        label: Duration(seconds: elapsedSeconds).toString().split('.').first,
        icon: Icons.timer_outlined,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AppPill(label: 'المهارة ${index + 1} من $total', selected: true),
              AppPill(label: 'تم تحديث $completedCount'),
              AppPill(label: 'الإتقان $masteryRate%'),
              AppPill(label: 'واجبات $homeworkSentCount'),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          LinearProgressIndicator(value: progress),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: .28),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppPill(
                  label: goal?.goal ?? 'هدف علاجي',
                  icon: Icons.flag_outlined,
                  selected: true,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  step.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  alignment: WrapAlignment.center,
                  children: [
                    AppPill(label: 'الحالة الحالية: ${step.status}'),
                    if (step.notes.isNotEmpty)
                      const AppPill(label: 'له ملاحظة سابقة'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SemanticAlertCard(
            kind: SemanticAlertKind.info,
            icon: Icons.home_work_outlined,
            title: 'واجب مقترح',
            message: 'تدريب يومي: ${step.title} لمدة 5 دقائق.',
          ),
          const SizedBox(height: AppSpacing.md),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: autoMoveToNext,
            onChanged: onToggleAutoMove,
            title: const Text('انتقال تلقائي بعد تحديث الحالة'),
            subtitle: const Text('اختصارات: 1 مساعدة، 2 جزئي، 3 مستقل، 4 متقن'),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('حالة المهارة', style: SanadText.subtitle(context)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: options.map((option) {
              final selected = selectedValue == option;
              return SizedBox(
                height: 68,
                width: 150,
                child: selected
                    ? FilledButton(
                        onPressed: () => onEvaluate(option),
                        child: Text(option),
                      )
                    : FilledButton.tonal(
                        onPressed: () => onEvaluate(option),
                        child: Text(option),
                      ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.md),
          _QuickNotes(onQuickNote: onQuickNote),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: notes,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'ملاحظة الأخصائي'),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton.icon(
                onPressed: onPrevious,
                icon: const Icon(Icons.arrow_back),
                label: const Text('السابق'),
              ),
              FilledButton.icon(
                onPressed: onNext,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('التالي'),
              ),
              FilledButton.tonalIcon(
                onPressed: onSendHomework,
                icon: const Icon(Icons.playlist_add_check),
                label: const Text('إرسال واجب ذكي'),
              ),
              FilledButton.icon(
                onPressed: completedCount == 0 ? null : onSave,
                icon: const Icon(Icons.save_outlined),
                label: const Text('حفظ الجلسة'),
              ),
              TextButton.icon(
                onPressed: onStop,
                icon: const Icon(Icons.close),
                label: const Text('إيقاف الجلسة'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickNotes extends StatelessWidget {
  const _QuickNotes({required this.onQuickNote});

  final ValueChanged<String> onQuickNote;

  @override
  Widget build(BuildContext context) {
    const notes = [
      'تحسن ممتاز',
      'يحتاج متابعة',
      'تشتت',
      'تعاون ممتاز',
      'يحتاج تدريب منزلي',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ملاحظات سريعة', style: SanadText.subtitle(context)),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: notes
              .map((note) => ActionChip(
                    label: Text(note),
                    onPressed: () => onQuickNote(note),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _ClinicalSessionSummary {
  const _ClinicalSessionSummary({
    required this.stepsCount,
    required this.updatedCount,
    required this.masteryRate,
    required this.homeworkSentCount,
    required this.notes,
  });

  final int stepsCount;
  final int updatedCount;
  final int masteryRate;
  final int homeworkSentCount;
  final String notes;
}

class _ClinicalSessionSummaryCard extends StatelessWidget {
  const _ClinicalSessionSummaryCard({required this.summary});

  final _ClinicalSessionSummary summary;

  @override
  Widget build(BuildContext context) {
    return TherapyCard(
      title: 'ملخص آخر جلسة علاجية',
      icon: Icons.summarize_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AppPill(label: 'المهارات: ${summary.stepsCount}'),
              AppPill(label: 'المحدث: ${summary.updatedCount}'),
              AppPill(label: 'الإتقان: ${summary.masteryRate}%'),
              AppPill(label: 'الواجبات: ${summary.homeworkSentCount}'),
            ],
          ),
          if (summary.notes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('ملاحظة الأخصائي: ${summary.notes}'),
          ],
        ],
      ),
    );
  }
}

class _PreviousGoalSessions extends StatelessWidget {
  const _PreviousGoalSessions({required this.app});

  final AppProvider app;

  @override
  Widget build(BuildContext context) {
    final sessions = app.sessions
        .where((session) => session.sessionType.contains('هدف'))
        .toList();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الجلسات المبنية على أهداف', style: SanadText.subtitle(context)),
          const SizedBox(height: AppSpacing.sm),
          if (sessions.isEmpty)
            const EmptyState(
              icon: Icons.timeline_outlined,
              title: 'لا توجد جلسات أهداف بعد',
              message:
                  'بعد حفظ أول جلسة مبنية على هدف ستظهر هنا كجزء من رحلة التحسن.',
            )
          else
            ...sessions.take(6).map((session) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.track_changes_outlined),
                  title: Text(session.cardTitle),
                  subtitle: Text(
                    '${session.startedAt.split('T').first} - إتقان ${session.successRate}%',
                  ),
                  trailing: Text(session.quickResult),
                )),
        ],
      ),
    );
  }
}
