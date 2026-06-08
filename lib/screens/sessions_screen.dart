import 'package:flutter/material.dart';
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
  String query = '';
  TherapyProgramTemplate? _selectedProgram;
  String? _selectedSourceType;
  TrainingPlan? _currentGoal;
  GoalSkillStep? _currentStep;
  bool _allDone = false;
  int _stepsDone = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reset());
  }

  void _applyPreselect() {
    final app = context.read<AppProvider>();
    final preselect = app.sessionPreselect;
    if (preselect == null) return;
    final programId = preselect['programId'] ?? '';
    final sourceType = preselect['sourceType'] ?? '';
    final planId = preselect['planId'] ?? '';
    final stepId = preselect['stepId'] ?? '';
    final program =
        app.therapyPrograms.where((p) => p.id == programId).toList();
    if (program.isEmpty) return;
    app.clearSessionPreselect();
    setState(() {
      _selectedProgram = program.first;
      _selectedSourceType = sourceType;
      _currentGoal = null;
      _currentStep = null;
      _allDone = false;
      _stepsDone = 0;
    });
    if (stepId.isNotEmpty) {
      final step = app.goalSkillSteps.where((s) => s.id == stepId).toList();
      final plan =
          app.plans.where((p) => p.id == (planId.isNotEmpty ? planId : step.isNotEmpty ? step.first.goalId : '')).toList();
      if (step.isNotEmpty && plan.isNotEmpty) {
        setState(() {
          _currentGoal = plan.first;
          _currentStep = step.first;
        });
        return;
      }
    }
    if (planId.isNotEmpty) {
      final plan = app.plans.where((p) => p.id == planId).toList();
      if (plan.isNotEmpty) {
        setState(() => _currentGoal = plan.first);
        _findCurrent();
        return;
      }
    }
    _findCurrent();
  }

  void _reset() {
    setState(() {
      _selectedProgram = null;
      _selectedSourceType = null;
      _currentGoal = null;
      _currentStep = null;
      _allDone = false;
      _stepsDone = 0;
    });
  }

  List<TrainingPlan> _filteredPlans(AppProvider app) {
    final pid = _selectedProgram?.id ?? '';
    final st = _selectedSourceType ?? '';
    if (pid.isEmpty || st.isEmpty) return [];
    return app.plans
        .where((p) => p.programId == pid && p.sourceType == st)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  List<GoalSkillStep> _filteredSteps(AppProvider app, String goalId) =>
      app.stepsForGoal(goalId)
          .where((s) =>
              s.programId == (_selectedProgram?.id ?? '') &&
              s.sourceType == (_selectedSourceType ?? ''))
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  void _findCurrent() {
    final app = context.read<AppProvider>();
    final student = app.selectedStudent;
    if (student == null) {
      _reset();
      return;
    }
    for (final plan in _filteredPlans(app)) {
      final steps = _filteredSteps(app, plan.id);
      final remaining = steps
          .where((s) =>
              s.status != 'متقن' &&
              s.status != 'بمساعدة' &&
              s.status != 'يحتاج إعادة')
          .toList();
      if (remaining.isNotEmpty) {
        setState(() {
          _currentGoal = plan;
          _currentStep = remaining.first;
          _allDone = false;
        });
        return;
      }
      if (steps.isEmpty && plan.progress < 100) {
        setState(() {
          _currentGoal = plan;
          _currentStep = null;
          _allDone = false;
        });
        return;
      }
    }
    setState(() {
      _currentGoal = null;
      _currentStep = null;
      _allDone = true;
    });
  }

  Future<void> _evaluate(String status) async {
    final app = context.read<AppProvider>();
    final step = _currentStep;
    final goal = _currentGoal;
    final student = app.selectedStudent;
    if (student == null || goal == null) return;

    if (step == null) {
      await runWithFeedback(context, () async {
        await app.updatePlanProgress(
          planId: goal.id,
          progress: 100,
        );
        await _recordSession(app, student, goal, null, status);
        setState(() => _stepsDone++);
        _findCurrent();
      });
      return;
    }

    await runWithFeedback(context, () async {
      await app.updateGoalSkillStepStatus(
        step: step,
        status: status,
        notes: status == 'متقن'
            ? ''
            : (status == 'بمساعدة'
                ? 'تمت بمساعدة وتحتاج متابعة منزلية'
                : 'تحتاج إعادة في جلسة لاحقة'),
      );
      await _recordSession(app, student, goal, step, status);
      setState(() => _stepsDone++);
      _findCurrent();
    });
  }

  Future<void> _recordSession(
    AppProvider app,
    Student student,
    TrainingPlan goal,
    GoalSkillStep? step,
    String status,
  ) async {
    final now = DateTime.now();
    final session = TherapySession(
      id: 'session_${now.millisecondsSinceEpoch}_$_stepsDone',
      centerId: student.centerId,
      studentId: student.id,
      specialistId: app.user?.id ?? '',
      planId: goal.id,
      programId: _selectedProgram?.id ?? '',
      skillId: step?.id ?? '',
      sessionType: _selectedProgram?.name ?? 'جلسة علاجية',
      startedAt: now.toIso8601String(),
      durationSeconds: 0,
      cardTitle: step?.title ?? goal.goal,
      quickResult: status,
      notes: step != null
          ? 'تقييم مهارة: ${step.title} - النتيجة: $status'
          : 'تقييم هدف: ${goal.goal} - النتيجة: $status',
    );
    // Save directly to avoid selectStudent reload on every step
    await app.saveSession(session, autosave: true);
  }

  // ─── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();

    if (_selectedProgram == null && app.selectedStudent != null) {
      _applyPreselect();
    }

    if (app.selectedStudent == null) return _buildStudentPicker(app);
    if (app.plans.isEmpty && _selectedProgram == null) return _buildNoPlans();
    if (_selectedProgram == null) return _buildProgramPicker(app);
    if (_selectedProgram!.usesSpeechSounds && _selectedSourceType == null) {
      return _buildSourceTypePicker();
    }
    if (_allDone) {
      return _buildPathComplete();
    }
    return _buildSessionView(app);
  }

  // ─── Phase 1: Student picker ────────────────────────────

  Widget _buildStudentPicker(AppProvider app) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'الجلسات العلاجية',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'ابحث عن طالب',
            isDense: true,
          ),
          onChanged: (value) => setState(() => query = value),
        ),
        const SizedBox(height: AppSpacing.md),
        if (app.students.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: EmptyState(
              icon: Icons.child_care_outlined,
              title: 'لا يوجد طلاب مرتبطون',
              message:
                  'لم يتم ربط أي طالب بحسابك بعد. تواصل مع المنسق لربط طلاب.',
            ),
          )
        else ...[
          Text(
            'اختر طالبًا لبدء الجلسة',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...app.students
              .where((s) => s.name.contains(query))
              .map((student) => _StudentSessionCard(
                    student: student,
                    onTap: () async {
                      await app.selectStudent(student);
                      _reset();
                      _applyPreselect();
                    },
                  )),
        ],
      ],
    );
  }

  // ─── Phase 2: Program picker ───────────────────────────

  Widget _buildNoPlans() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPhase2Header(),
        const SizedBox(height: AppSpacing.md),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: EmptyState(
            icon: Icons.track_changes_outlined,
            title: 'لا توجد أهداف علاجية',
            message:
                'تأكد من تخصيص برامج علاجية للطالب في شاشة إدخال البيانات، ثم قم بتقييم الطالب في شاشة التقييم العلاجي.',
          ),
        ),
      ],
    );
  }

  Widget _buildProgramPicker(AppProvider app) {
    final programs = app.programsForStudent();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPhase2Header(),
        const SizedBox(height: AppSpacing.md),
        Text(
          'اختر البرنامج العلاجي',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (programs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: EmptyState(
              icon: Icons.auto_stories_outlined,
              title: 'لا توجد برامج علاجية مخصصة',
              message:
                  'لم يتم تخصيص برامج علاجية لهذا الطالب. يرجى التواصل مع مدخل البيانات.',
            ),
          )
        else
          ...programs.map((program) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    onTap: () {
                      setState(() {
                        _selectedProgram = program;
                        _selectedSourceType =
                            program.usesSpeechSounds ? null : 'standard';
                        _currentGoal = null;
                        _currentStep = null;
                        _allDone = false;
                        _stepsDone = 0;
                      });
                      _findCurrent();
                    },
                    child: AppCard(
                      highlight: true,
                      child: Row(
                        children: [
                          Icon(
                            program.usesSpeechSounds
                                ? Icons.record_voice_over_outlined
                                : Icons.psychology_alt_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  program.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                                if (program.description.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    program.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Icon(
                            Icons.arrow_back_ios_new_outlined,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )),
      ],
    );
  }

  Widget _buildPhase2Header() {
    return Row(
      children: [
        TextButton.icon(
          onPressed: () async {
            await context.read<AppProvider>().selectStudent(null);
            _reset();
          },
          icon: const Icon(Icons.arrow_forward),
          label: const Text('رجوع'),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'الجلسات العلاجية',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  // ─── Phase 3: Source type picker ────────────────────────

  Widget _buildSourceTypePicker() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPhase3Header(),
        const SizedBox(height: AppSpacing.md),
        Text(
          'اختر نوع الجلسة',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 460;
            if (narrow) {
              return Column(
                children: [
                  _sourceTypeCard(
                    colorScheme,
                    Icons.assessment_outlined,
                    'أقسام التقييم',
                    'تماثل الوجه - أعضاء النطق - العمليات الوظيفية',
                    () {
                      setState(() {
                        _selectedSourceType = 'standard';
                        _currentGoal = null;
                        _currentStep = null;
                        _allDone = false;
                        _stepsDone = 0;
                      });
                      _findCurrent();
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _sourceTypeCard(
                    colorScheme,
                    Icons.record_voice_over_outlined,
                    'حروف النطق',
                    'حذف - إبدال - إضافة - تشويه',
                    () {
                      setState(() {
                        _selectedSourceType = 'speechSound';
                        _currentGoal = null;
                        _currentStep = null;
                        _allDone = false;
                        _stepsDone = 0;
                      });
                      _findCurrent();
                    },
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(
                    child: _sourceTypeCard(
                        colorScheme,
                        Icons.assessment_outlined,
                        'أقسام التقييم',
                        'تماثل الوجه - أعضاء النطق - العمليات الوظيفية', () {
                  setState(() {
                    _selectedSourceType = 'standard';
                    _currentGoal = null;
                    _currentStep = null;
                    _allDone = false;
                    _stepsDone = 0;
                  });
                  _findCurrent();
                })),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                    child: _sourceTypeCard(
                        colorScheme,
                        Icons.record_voice_over_outlined,
                        'حروف النطق',
                        'حذف - إبدال - إضافة - تشويه', () {
                  setState(() {
                    _selectedSourceType = 'speechSound';
                    _currentGoal = null;
                    _currentStep = null;
                    _allDone = false;
                    _stepsDone = 0;
                  });
                  _findCurrent();
                })),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _sourceTypeCard(ColorScheme colorScheme, IconData icon, String title,
      String subtitle, VoidCallback onTap) {
    return AppCard(
      highlight: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              Icon(icon, size: 40, color: colorScheme.primary),
              const SizedBox(height: 8),
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhase3Header() {
    return Row(
      children: [
        TextButton.icon(
          onPressed: () => setState(() {
            _selectedProgram = null;
            _selectedSourceType = null;
            _currentGoal = null;
            _currentStep = null;
            _allDone = false;
            _stepsDone = 0;
          }),
          icon: const Icon(Icons.arrow_forward),
          label: const Text('رجوع'),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            _selectedProgram?.name ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  // ─── Done message ───────────────────────────────────────

  Widget _buildEmpty(String title, String message) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSessionHeader(),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: EmptyState(
            icon: Icons.track_changes_outlined,
            title: title,
            message: message,
          ),
        ),
      ],
    );
  }

  Widget _buildPathComplete() {
    final pathName = _selectedSourceType == 'speechSound'
        ? 'حروف النطق'
        : _selectedSourceType == 'evaluationSections'
            ? 'أقسام التقييم'
            : 'هذا المسار';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSessionHeader(),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: EmptyState(
            icon: Icons.check_circle_outline,
            title: 'تم إنهاء مسار $pathName',
            message: 'يمكنك اختيار مسار آخر أو العودة لاحقاً.',
            action: FilledButton.icon(
              onPressed: () => setState(() {
                _selectedSourceType = null;
                _currentGoal = null;
                _currentStep = null;
                _allDone = false;
              }),
              icon: const Icon(Icons.swap_horiz),
              label: const Text('اختيار مسار آخر'),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Phase 4: Session view ──────────────────────────────

  Widget _buildSessionView(AppProvider app) {
    final goal = _currentGoal;
    final student = app.selectedStudent;
    if (goal == null || student == null) {
      return _buildEmpty(
        'لا توجد مهارات متبقية',
        'تم إتقان جميع المهارات في هذا الهدف.',
      );
    }

    final step = _currentStep;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final steps = _filteredSteps(app, goal.id);
    final progress = app.goalProgress(goal.id);
    final hasSteps = steps.isNotEmpty;
    final hasTreatment = goal.treatment.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSessionHeader(),
        const SizedBox(height: AppSpacing.md),
        // Student + program pills
        Row(
          children: [
            CircleAvatar(
              backgroundColor: colorScheme.primaryContainer,
              child: Text(
                student.name.isNotEmpty ? student.name[0] : '?',
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                student.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            AppPill(
              label: _selectedProgram?.name ?? '',
              icon: Icons.auto_stories_outlined,
              selected: true,
            ),
            AppPill(
              label: _selectedSourceType == 'speechSound'
                  ? 'حروف النطق'
                  : 'أقسام التقييم',
              icon: _selectedSourceType == 'speechSound'
                  ? Icons.record_voice_over_outlined
                  : Icons.assessment_outlined,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        // Goal card
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.flag_outlined,
                      size: 18, color: colorScheme.primary),
                  const SizedBox(width: 6),
                  Text('الهدف الحالي',
                      style: textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                goal.goal,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
              if (hasTreatment) ...[
                const SizedBox(height: 6),
                Text(
                  goal.treatment,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(value: progress / 100),
                  ),
                  const SizedBox(width: 8),
                  Text('$progress%',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (hasSteps) ...[
                    AppPill(label: 'المهارات: ${steps.length}'),
                    AppPill(
                      label:
                          'المتقنة: ${steps.where((s) => s.status == 'متقن').length}',
                    ),
                  ],
                  AppPill(label: app.goalStatus(goal.id)),
                  if (_stepsDone > 0)
                    AppPill(
                      label: 'تم تقييم $_stepsDone في هذه الجلسة',
                      icon: Icons.check_circle_outline,
                    ),
                ],
              ),
            ],
          ),
        ),
        // Current step
        if (hasSteps && step != null) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: .3),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.psychology,
                  color: colorScheme.onPrimaryContainer,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  step.title,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 6),
                AppPill(
                  label: 'الحالة: ${step.status}',
                  icon: Icons.info_outline,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Text(
          hasSteps ? 'تقييم المهارة' : 'تقييم الهدف',
          style:
              textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Three evaluation buttons
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 400;
            if (narrow) {
              return Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                      ),
                      onPressed: () => _evaluate('متقن'),
                      child: const Text('متقن',
                          style: TextStyle(fontSize: 15)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.tertiaryContainer,
                      ),
                      onPressed: () => _evaluate('بمساعدة'),
                      child: Text('بمساعدة',
                          style: TextStyle(
                              fontSize: 15,
                              color: colorScheme.onTertiaryContainer)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: colorScheme.error),
                      ),
                      onPressed: () => _evaluate('يحتاج إعادة'),
                      child: Text('يحتاج إعادة',
                          style: TextStyle(
                              fontSize: 15, color: colorScheme.error)),
                    ),
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                      ),
                      onPressed: () => _evaluate('متقن'),
                      child: const Text('متقن'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.tertiaryContainer,
                      ),
                      onPressed: () => _evaluate('بمساعدة'),
                      child: Text('بمساعدة',
                          style: TextStyle(
                              color: colorScheme.onTertiaryContainer)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: colorScheme.error),
                      ),
                      onPressed: () => _evaluate('يحتاج إعادة'),
                      child: Text('يحتاج إعادة',
                          style: TextStyle(color: colorScheme.error)),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSessionHeader() {
    return Row(
      children: [
        TextButton.icon(
          onPressed: () => setState(() {
            if (_selectedSourceType != null) {
              _selectedSourceType = null;
              _currentGoal = null;
              _currentStep = null;
              _allDone = false;
            } else if (_selectedProgram != null) {
              _selectedProgram = null;
              _selectedSourceType = null;
              _currentGoal = null;
              _currentStep = null;
              _allDone = false;
              _stepsDone = 0;
            }
          }),
          icon: const Icon(Icons.arrow_forward),
          label: const Text('رجوع'),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'الجلسات العلاجية',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

// ─── Student card for session picker ─────────────────────

class _StudentSessionCard extends StatelessWidget {
  const _StudentSessionCard({
    required this.student,
    required this.onTap,
  });

  final Student student;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.card),
          onTap: onTap,
          child: AppCard(
            child: Row(
              children: [
                StudentAvatar(student: student, radius: 28),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${student.age} سنة - ${student.diagnosis}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall,
                      ),
                      if (student.parentName.isNotEmpty)
                        Text(
                          'ولي الأمر: ${student.parentName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_back_ios_new_outlined,
                  color: colorScheme.onSurfaceVariant,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
