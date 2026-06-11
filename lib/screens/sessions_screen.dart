import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../widgets/app_widgets.dart';
import '../widgets/feedback.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key, this.onReturnToProfile});

  final VoidCallback? onReturnToProfile;

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  String query = '';
  TherapyProgramTemplate? _selectedProgram;
  String? _selectedSourceType;
  TrainingPlan? _selectedGoal;
  String? _currentSessionId;
  bool _isRetrainMode = false;
  bool _showCompletedGoals = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = context.read<AppProvider>();
      if (app.sessionPreselect != null) {
        _applyPreselect();
      } else {
        _reset();
      }
    });
  }

  void _applyPreselect() {
    final app = context.read<AppProvider>();
    final preselect = app.sessionPreselect;
    if (preselect == null) return;
    final programId = preselect['programId'] ?? '';
    final sourceType = preselect['sourceType'] ?? '';
    final planId = preselect['planId'] ?? '';
    final program =
        app.therapyPrograms.where((p) => p.id == programId).toList();
    if (program.isEmpty) return;
    app.clearSessionPreselect();
    setState(() {
      _selectedProgram = program.first;
      _selectedSourceType = sourceType;
      _selectedGoal = null;
      _currentSessionId = null;
      _isRetrainMode = false;
    });
    if (planId.isNotEmpty) {
      final plan = app.plans.where((p) => p.id == planId).toList();
      if (plan.isNotEmpty) {
        setState(() {
          _selectedGoal = plan.first;
          _isRetrainMode = true;
        });
        // Update all pending followups for this goal's steps
        final goalSteps = app.stepsForGoal(planId);
        final studentId = preselect['studentId'] ?? '';
        if (studentId.isNotEmpty) {
          for (final step in goalSteps) {
            app.pendingFollowupForStep(studentId, step.id).then((followup) {
              if (followup != null) {
                app.upsertFollowup(
                  studentId: followup.studentId,
                  specialistId: followup.specialistId,
                  programId: followup.programId,
                  sourceType: followup.sourceType,
                  planId: followup.planId,
                  goalSkillStepId: followup.goalSkillStepId,
                  reason: followup.reason,
                );
              }
            });
          }
        }
      }
    }
  }

  void _reset() {
    setState(() {
      _selectedProgram = null;
      _selectedSourceType = null;
      _selectedGoal = null;
      _currentSessionId = null;
      _isRetrainMode = false;
      _showCompletedGoals = false;
    });
  }

  // ─── Filter helpers ─────────────────────────────────────

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

  List<TrainingPlan> _activeGoals(AppProvider app) =>
      _filteredPlans(app).where((p) => app.goalProgress(p.id) < 100).toList();

  List<TrainingPlan> _completedGoals(AppProvider app) =>
      _filteredPlans(app).where((p) => app.goalProgress(p.id) >= 100).toList();

  // ─── Goal status colors ─────────────────────────────────

  Color _goalStatusColor(String status) {
    switch (status) {
      case 'جديد':
        return const Color(0xFF64748B);
      case 'قيد العلاج':
        return const Color(0xFF0F766E);
      case 'يحتاج مساعدة':
        return const Color(0xFFD97706);
      case 'يحتاج إعادة':
        return const Color(0xFFDC2626);
      case 'متقن':
        return const Color(0xFF16A34A);
      default:
        return const Color(0xFF64748B);
    }
  }

  Color _goalStatusBgColor(String status) {
    switch (status) {
      case 'جديد':
        return const Color(0xFFF1F5F9);
      case 'قيد العلاج':
        return const Color(0xFFE0F2FE);
      case 'يحتاج مساعدة':
        return const Color(0xFFFEF3C7);
      case 'يحتاج إعادة':
        return const Color(0xFFFEE2E2);
      case 'متقن':
        return const Color(0xFFDCFCE7);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  // ─── Evaluation ─────────────────────────────────────────

  Future<void> _evaluateGoal(String status) async {
    final app = context.read<AppProvider>();
    final goal = _selectedGoal;
    final student = app.selectedStudent;
    if (student == null || goal == null) return;

    await runWithFeedback(context, () async {
      final steps = _filteredSteps(app, goal.id);
      if (steps.isEmpty) {
        if (status == 'متقن') {
          await app.updatePlanProgress(planId: goal.id, progress: 100);
        } else if (app.goalProgress(goal.id) >= 100) {
          await app.updatePlanProgress(planId: goal.id, progress: 50);
        }
      }
      await _recordGoalSession(app, student, goal, status);
    });
  }

  Future<void> _evaluateStep(GoalSkillStep step, String status) async {
    final app = context.read<AppProvider>();
    final goal = _selectedGoal;
    final student = app.selectedStudent;
    if (student == null || goal == null) return;

    await runWithFeedback(context, () async {
      await app.updateGoalSkillStepStatus(
        step: step,
        status: status,
        notes: 'تقييم مهارة: ${step.title} - النتيجة: $status',
      );

      if (status == 'متقن') {
        await app.resolveFollowupForStep(student.id, step.id);
      } else {
        await app.upsertFollowup(
          studentId: student.id,
          specialistId: app.user?.id ?? '',
          programId: _selectedProgram?.id ?? '',
          sourceType: _selectedSourceType ?? '',
          planId: goal.id,
          goalSkillStepId: step.id,
          reason: status == 'بمساعدة' ? 'assisted' : 'retry',
        );
      }

      await _recordGoalSession(app, student, goal, status);
    });
  }

  Future<void> _recordGoalSession(
    AppProvider app,
    Student student,
    TrainingPlan goal,
    String status,
  ) async {
    final now = DateTime.now();
    final steps = _filteredSteps(app, goal.id);
    final evaluated = steps
        .where((s) => s.status != 'لم يبدأ' && s.status.isNotEmpty)
        .toList();

    String summary;
    if (steps.isEmpty) {
      summary = 'تقييم هدف: ${goal.goal} - النتيجة: $status';
    } else if (evaluated.isEmpty) {
      summary = 'تقييم: $status';
    } else {
      summary = evaluated.map((s) => '${s.title}: ${s.status}').join(' | ');
    }

    final isFirstSave = _currentSessionId == null;
    final sessionId = _currentSessionId ??
        'session_${now.millisecondsSinceEpoch}_goal_${goal.id}';

    final session = TherapySession(
      id: sessionId,
      centerId: student.centerId,
      studentId: student.id,
      specialistId: app.user?.id ?? '',
      planId: goal.id,
      programId: _selectedProgram?.id ?? '',
      skillId: '',
      sessionType: _selectedProgram?.name ?? 'جلسة علاجية',
      startedAt: now.toIso8601String(),
      durationSeconds: 0,
      cardTitle: goal.goal,
      quickResult: status,
      successRate: switch (status) {
        'متقن' => 100,
        'بمساعدة' => 60,
        _ => 20,
      },
      notes: summary,
    );

    await app.saveSession(session, autosave: !isFirstSave);
    _currentSessionId = sessionId;

    if (evaluated.isNotEmpty) {
      for (final step in evaluated) {
        await app.saveSessionSkillResult(SessionSkillResult(
          id: '${sessionId}_${step.id}',
          sessionId: sessionId,
          goalSkillStepId: step.id,
          goalId: goal.id,
          stepTitle: step.title,
          result: step.status,
        ));
      }
    }
  }

  // ─── Build: Router ──────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();

    Widget content;
    if (app.selectedStudent == null) {
      content = _buildStudentPicker(app);
    } else if (app.plans.isEmpty && _selectedProgram == null) {
      content = _buildNoPlans();
    } else if (_selectedProgram == null) {
      content = _buildProgramPicker(app);
    } else if (_selectedProgram!.usesSpeechSounds && _selectedSourceType == null) {
      content = _buildSourceTypePicker();
    } else if (_selectedGoal == null) {
      content = _buildGoalList(app);
    } else {
      content = _buildGoalSession(app);
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: content,
      ),
    );
  }

  // ─── Phase 1: Student picker ────────────────────────────

  Widget _buildStudentPicker(AppProvider app) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Text('الجلسات العلاجية', style: SanadText.title(context)),
        const SizedBox(height: 4),
        Text('اختر طالبًا لبدء الجلسة', style: SanadText.secondary(context)),
        const SizedBox(height: AppSpacing.md),
        TextField(
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
            hintText: 'ابحث عن طالب',
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.control),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              message: 'لم يتم ربط أي طالب بحسابك بعد. تواصل مع المنسق لربط طلاب.',
            ),
          )
        else
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
    );
  }

  // ─── Phase 2: Program picker ───────────────────────────

  Widget _buildNoPlans() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPhase2Header(),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: EmptyState(
            icon: Icons.track_changes_outlined,
            title: 'لا توجد أهداف علاجية',
            message: 'تأكد من تخصيص برامج علاجية للطالب في شاشة إدخال البيانات، ثم قم بتقييم الطالب في شاشة التقييم العلاجي.',
          ),
        ),
      ],
    );
  }

  Widget _buildProgramPicker(AppProvider app) {
    final programs = app.programsForStudent();
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPhase2Header(),
        const SizedBox(height: AppSpacing.md),
        Text('اختر البرنامج العلاجي', style: SanadText.subtitle(context)),
        const SizedBox(height: 4),
        Text('اختر البرنامج المناسب للطالب', style: SanadText.secondary(context)),
        const SizedBox(height: AppSpacing.md),
        if (programs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: EmptyState(
              icon: Icons.auto_stories_outlined,
              title: 'لا توجد برامج علاجية مخصصة',
              message: 'لم يتم تخصيص برامج علاجية لهذا الطالب. يرجى التواصل مع مدخل البيانات.',
            ),
          )
        else
          ...programs.map((program) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Material(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    onTap: () {
                      setState(() {
                        _selectedProgram = program;
                        _selectedSourceType = program.usesSpeechSounds ? null : 'standard';
                        _selectedGoal = null;
                        _currentSessionId = null;
                      });
                    },
                    child: AppCard(
                      highlight: true,
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              program.usesSpeechSounds ? Icons.record_voice_over_outlined : Icons.psychology_alt_outlined,
                              color: colorScheme.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  program.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                                ),
                                if (program.description.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    program.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.arrow_back_ios_new_outlined, color: colorScheme.onSurfaceVariant, size: 18),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          child: TextButton.icon(
            onPressed: () async {
              await context.read<AppProvider>().selectStudent(null);
              _reset();
            },
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text('رجوع', style: TextStyle(fontSize: 14)),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text('الجلسات العلاجية', style: SanadText.title(context)),
        ),
      ],
    );
  }

  // ─── Phase 3: Source type picker ────────────────────────

  Widget _buildSourceTypePicker() {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPhase3Header(),
        const SizedBox(height: AppSpacing.md),
        Text('اختر نوع الجلسة', style: SanadText.subtitle(context)),
        const SizedBox(height: 4),
        Text('حدد نوع التمارين للجلسة', style: SanadText.secondary(context)),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 460;
            if (narrow) {
              return Column(
                children: [
                  _sourceTypeCard(
                    colorScheme, Icons.assessment_outlined,
                    'أقسام التقييم', 'تماثل الوجه - أعضاء النطق - العمليات الوظيفية',
                    () => setState(() {
                      _selectedSourceType = 'standard';
                      _selectedGoal = null;
                      _currentSessionId = null;
                    }),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _sourceTypeCard(
                    colorScheme, Icons.record_voice_over_outlined,
                    'حروف النطق', 'حذف - إبدال - إضافة - تشويه',
                    () => setState(() {
                      _selectedSourceType = 'speechSound';
                      _selectedGoal = null;
                      _currentSessionId = null;
                    }),
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(
                  child: _sourceTypeCard(
                    colorScheme, Icons.assessment_outlined,
                    'أقسام التقييم', 'تماثل الوجه - أعضاء النطق - العمليات الوظيفية',
                    () => setState(() {
                      _selectedSourceType = 'standard';
                      _selectedGoal = null;
                      _currentSessionId = null;
                    }),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _sourceTypeCard(
                    colorScheme, Icons.record_voice_over_outlined,
                    'حروف النطق', 'حذف - إبدال - إضافة - تشويه',
                    () => setState(() {
                      _selectedSourceType = 'speechSound';
                      _selectedGoal = null;
                      _currentSessionId = null;
                    }),
                  ),
                ),
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
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 28, color: colorScheme.primary),
              ),
              const SizedBox(height: 12),
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhase3Header() {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          child: TextButton.icon(
            onPressed: () => setState(() {
              _selectedProgram = null;
              _selectedSourceType = null;
              _selectedGoal = null;
              _currentSessionId = null;
            }),
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text('رجوع', style: TextStyle(fontSize: 14)),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(_selectedProgram?.name ?? '', style: SanadText.title(context)),
        ),
      ],
    );
  }

  // ─── Phase 4: Goal Dashboard ────────────────────────────

  Widget _buildGoalList(AppProvider app) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeGoals = _activeGoals(app);
    final completedGoals = _completedGoals(app);
    final hasGoals = activeGoals.isNotEmpty || completedGoals.isNotEmpty;
    final student = app.selectedStudent!;
    final todaySessions = app.specialistSessions
        .where((s) => s.startedAt.split('T').first == DateTime.now().toIso8601String().split('T').first)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildGoalListHeader(),
        const SizedBox(height: 20),
        // ─── Hero Area ─────────────────────────────────────
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 480;
            return Container(
              padding: EdgeInsets.all(narrow ? AppSpacing.md : AppSpacing.xl),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primaryContainer,
                    colorScheme.surface,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      StudentAvatar(student: student, radius: narrow ? 22 : 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(student.name,
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: narrow ? 15 : 17, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 2),
                            Text(_selectedProgram?.name ?? '',
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: SanadText.secondary(context)),
                          ],
                        ),
                      ),
                      if (!narrow)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(AppRadii.control),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.calendar_today_outlined, size: 14, color: colorScheme.primary),
                              const SizedBox(width: 6),
                              Text('$todaySessions', style: TextStyle(fontWeight: FontWeight.w800, color: colorScheme.primary)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  if (!narrow) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _heroStat(colorScheme, 'الأهداف النشطة', '${activeGoals.length}', Icons.flag_outlined),
                        const SizedBox(width: 16),
                        _heroStat(colorScheme, 'البرنامج', _selectedProgram?.name ?? '', Icons.auto_stories_outlined),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        // Goals section
        Text('الأهداف العلاجية', style: SanadText.subtitle(context)),
        const SizedBox(height: 4),
        Text(activeGoals.isEmpty ? 'جميع الأهداف مكتملة' : 'اختر هدفًا لبدء الجلسة', style: SanadText.secondary(context)),
        const SizedBox(height: AppSpacing.md),
        if (!hasGoals)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: EmptyState(
              icon: Icons.flag_outlined,
              title: 'لا توجد أهداف علاجية',
              message: 'لم يتم إنشاء أهداف علاجية بعد. قم بتقييم الطالب أولاً.',
            ),
          )
        else ...[
          if (activeGoals.isEmpty)
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: SanadUiColors.accentGreen.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: Border.all(color: SanadUiColors.accentGreen),
              ),
              child: const Row(
                children: [
                  Icon(Icons.emoji_events_outlined, color: Color(0xFF16A34A), size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('تم إتقان جميع الأهداف 🎉', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            )
          else
            ...activeGoals.map((goal) => _buildGoalCard(app, goal, false)),
          if (completedGoals.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: () => setState(() => _showCompletedGoals = !_showCompletedGoals),
              icon: Icon(_showCompletedGoals ? Icons.expand_less : Icons.expand_more, size: 20),
              label: Text(
                _showCompletedGoals
                    ? 'إخفاء الأهداف المنجزة'
                    : 'الأهداف المنجزة (${completedGoals.length})',
                style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
              ),
            ),
            if (_showCompletedGoals)
              ...completedGoals.map((goal) => _buildGoalCard(app, goal, true)),
          ],
        ],
      ],
    );
  }

  Widget _heroStat(ColorScheme colorScheme, String label, String value, IconData icon) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: colorScheme.primary)),
              Text(label, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(AppProvider app, TrainingPlan goal, bool isCompleted) {
    final colorScheme = Theme.of(context).colorScheme;
    final steps = _filteredSteps(app, goal.id);
    final progress = app.goalProgress(goal.id);
    final status = app.goalStatus(goal.id);
    final statusColor = _goalStatusColor(status);
    final statusBg = _goalStatusBgColor(status);
    final hasSteps = steps.isNotEmpty;
    final hasTreatment = goal.treatment.isNotEmpty;
    final masteredCount = steps.where((s) => s.status == 'متقن').length;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        child: Material(
          color: isCompleted ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5) : colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          elevation: isCompleted ? 0 : 1,
          shadowColor: colorScheme.shadow.withValues(alpha: 0.08),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.card),
            onTap: isCompleted
                ? null
                : () => setState(() {
                    _selectedGoal = goal;
                    _currentSessionId = null;
                  }),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: Border.all(
                  color: isCompleted
                      ? colorScheme.outlineVariant
                      : status == 'يحتاج إعادة'
                          ? statusColor.withValues(alpha: 0.3)
                          : statusColor.withValues(alpha: 0.15),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          isCompleted ? Icons.check_circle : Icons.flag_outlined,
                          color: statusColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              goal.goal,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: isCompleted ? colorScheme.onSurfaceVariant : colorScheme.onSurface,
                              ),
                            ),
                            if (hasTreatment) ...[
                              const SizedBox(height: 4),
                              Text(
                                goal.treatment,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (!isCompleted)
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.arrow_back_ios_new_outlined, color: colorScheme.onSurfaceVariant, size: 16),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Progress
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            minHeight: 8,
                            value: progress / 100,
                            backgroundColor: colorScheme.surfaceContainerHighest,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('$progress%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: statusColor)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Badges row
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: statusColor)),
                      ),
                      if (hasSteps) ...[
                        AppPill(label: 'المهارات: ${steps.length}'),
                        AppPill(label: 'المتقنة: $masteredCount'),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoalListHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          child: TextButton.icon(
            onPressed: () => setState(() {
              _selectedSourceType = null;
              _selectedGoal = null;
              _currentSessionId = null;
            }),
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text('رجوع', style: TextStyle(fontSize: 14)),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text('الجلسات العلاجية', style: SanadText.title(context)),
        ),
      ],
    );
  }

  // ─── Phase 5: Goal session ──────────────────────────────

  Widget _buildGoalSession(AppProvider app) {
    final goal = _selectedGoal;
    final student = app.selectedStudent;
    if (goal == null || student == null) {
      return _buildGoalList(app);
    }

    final colorScheme = Theme.of(context).colorScheme;
    final steps = _filteredSteps(app, goal.id);
    final progress = app.goalProgress(goal.id);
    final hasSteps = steps.isNotEmpty;
    final hasTreatment = goal.treatment.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildGoalSessionHeader(),
        const SizedBox(height: 16),
        // Retrain banner
        if (_isRetrainMode)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: SanadUiColors.accentAmber,
              borderRadius: BorderRadius.circular(AppRadii.control),
              border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.refresh_outlined, size: 18, color: Color(0xFFD97706)),
                SizedBox(width: 8),
                Expanded(
                  child: Text('إعادة تدريب من ملف الطالب',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF92400E))),
                ),
              ],
            ),
          ),
        // Workspace header
        Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colorScheme.primaryContainer, colorScheme.surface],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Student + program row
              Row(
                children: [
                  StudentAvatar(student: student, radius: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(student.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                        Text(_selectedProgram?.name ?? '', style: SanadText.muted(context)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _selectedSourceType == 'speechSound' ? 'حروف النطق' : 'أقسام التقييم',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colorScheme.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Goal name
              Text('الهدف العلاجي', style: SanadText.muted(context)),
              const SizedBox(height: 4),
              Text(goal.goal, maxLines: 3, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, height: 1.3)),
              if (hasTreatment) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.healing_outlined, size: 18, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(goal.treatment, maxLines: 3, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: colorScheme.onSurface, height: 1.4)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              // Progress
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        minHeight: 10,
                        value: progress / 100,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        color: _goalStatusColor(app.goalStatus(goal.id)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('$progress%', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 10),
              // Status + skill count
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _goalStatusBgColor(app.goalStatus(goal.id)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(app.goalStatus(goal.id),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _goalStatusColor(app.goalStatus(goal.id)))),
                  ),
                  if (hasSteps) ...[
                    AppPill(label: 'المهارات: ${steps.length}'),
                    AppPill(label: 'المتقنة: ${steps.where((s) => s.status == 'متقن').length}'),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Skills section
        if (hasSteps) ...[
          Row(
            children: [
              Icon(Icons.psychology_outlined, size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text('المهارات العلاجية', style: SanadText.subtitle(context)),
            ],
          ),
          const SizedBox(height: 4),
          Text('قيّم كل مهارة بنتيجة الجلسة', style: SanadText.secondary(context)),
          const SizedBox(height: AppSpacing.md),
          _buildSkillsList(app, steps, progress),
        ] else
          _buildGoalEvaluation(),
      ],
    );
  }

  Widget _buildSkillsList(AppProvider app, List<GoalSkillStep> steps, int goalProgress) {

    return Column(
      children: [
        for (final step in steps) ...[
          _TherapyActionCard(
            step: step,
            goalProgress: goalProgress,
            goalStatusColor: _goalStatusColor,
            goalStatusBgColor: _goalStatusBgColor,
            onEvaluate: (status) => _evaluateStep(step, status),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }

  Widget _buildGoalEvaluation() {
    final colorScheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.psychology, size: 20, color: colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('تقييم الهدف', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text('قم بتقييم الهدف العلاجي ككل', style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildEvaluationButtons((status) => _evaluateGoal(status)),
        ],
      ),
    );
  }

  Widget _buildEvaluationButtons(Function(String) onEvaluate) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 420;
        if (narrow) {
          return Column(
            children: [
              _evalButton(
                label: 'متقن',
                icon: Icons.check_circle_outlined,
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                narrow: true,
                onTap: () => onEvaluate('متقن'),
              ),
              const SizedBox(height: 10),
              _evalButton(
                label: 'بمساعدة',
                icon: Icons.assistant,
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                narrow: true,
                onTap: () => onEvaluate('بمساعدة'),
              ),
              const SizedBox(height: 10),
              _evalButton(
                label: 'يحتاج إعادة',
                icon: Icons.replay,
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                narrow: true,
                onTap: () => onEvaluate('يحتاج إعادة'),
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(
              child: _evalButton(
                label: 'متقن',
                icon: Icons.check_circle_outlined,
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                narrow: false,
                onTap: () => onEvaluate('متقن'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _evalButton(
                label: 'بمساعدة',
                icon: Icons.assistant,
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                narrow: false,
                onTap: () => onEvaluate('بمساعدة'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _evalButton(
                label: 'يحتاج إعادة',
                icon: Icons.replay,
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                narrow: false,
                onTap: () => onEvaluate('يحتاج إعادة'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _evalButton({
    required String label,
    required IconData icon,
    required Color backgroundColor,
    required Color foregroundColor,
    required bool narrow,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: narrow ? double.infinity : null,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
        ),
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  void _exitGoalSession() {
    if (_isRetrainMode) {
      widget.onReturnToProfile?.call();
    } else {
      context.read<AppProvider>().selectStudent(null).then((_) {
        if (context.mounted) _reset();
      });
    }
  }

  Widget _buildGoalSessionHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          child: TextButton.icon(
            onPressed: _exitGoalSession,
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text('رجوع', style: TextStyle(fontSize: 14)),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text('جلسة علاجية', style: SanadText.title(context)),
        ),
      ],
    );
  }
}

// ─── Therapy Action Card ────────────────────────────

class _TherapyActionCard extends StatefulWidget {
  const _TherapyActionCard({
    required this.step,
    required this.goalProgress,
    required this.goalStatusColor,
    required this.goalStatusBgColor,
    required this.onEvaluate,
  });

  final GoalSkillStep step;
  final int goalProgress;
  final Color Function(String) goalStatusColor;
  final Color Function(String) goalStatusBgColor;
  final Function(String) onEvaluate;

  @override
  State<_TherapyActionCard> createState() => _TherapyActionCardState();
}

class _TherapyActionCardState extends State<_TherapyActionCard> {

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final step = widget.step;
    final hasStatus = step.status == 'متقن' || step.status == 'بمساعدة' || step.status == 'يحتاج إعادة';
    final statusColor = hasStatus ? widget.goalStatusColor(
      step.status == 'متقن' ? 'متقن' : step.status == 'بمساعدة' ? 'يحتاج مساعدة' : 'يحتاج إعادة',
    ) : colorScheme.onSurfaceVariant;
    final statusBg = hasStatus ? widget.goalStatusBgColor(
      step.status == 'متقن' ? 'متقن' : step.status == 'بمساعدة' ? 'يحتاج مساعدة' : 'يحتاج إعادة',
    ) : colorScheme.surfaceContainerHighest;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: hasStatus ? statusBg.withValues(alpha: 0.4) : colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(
          color: hasStatus ? statusColor.withValues(alpha: 0.25) : colorScheme.outlineVariant,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      hasStatus ? Icons.check_circle : Icons.psychology,
                      key: ValueKey(hasStatus),
                      color: statusColor,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(step.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                      if (hasStatus)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(step.status,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (widget.goalProgress < 100) ...[
              const SizedBox(height: 14),
              _buildEvaluationButtons(widget.onEvaluate),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEvaluationButtons(Function(String) onEvaluate) {

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 400;
        if (narrow) {
          return Column(
            children: [
              _evalButton(
                label: 'متقن',
                icon: Icons.check_circle_outlined,
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                narrow: true,
                onTap: () => onEvaluate('متقن'),
              ),
              const SizedBox(height: 8),
              _evalButton(
                label: 'بمساعدة',
                icon: Icons.assistant,
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                narrow: true,
                onTap: () => onEvaluate('بمساعدة'),
              ),
              const SizedBox(height: 8),
              _evalButton(
                label: 'يحتاج إعادة',
                icon: Icons.replay,
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                narrow: true,
                onTap: () => onEvaluate('يحتاج إعادة'),
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(
              child: _evalButton(
                label: 'متقن',
                icon: Icons.check_circle_outlined,
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                narrow: false,
                onTap: () => onEvaluate('متقن'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _evalButton(
                label: 'بمساعدة',
                icon: Icons.assistant,
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                narrow: false,
                onTap: () => onEvaluate('بمساعدة'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _evalButton(
                label: 'يحتاج إعادة',
                icon: Icons.replay,
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                narrow: false,
                onTap: () => onEvaluate('يحتاج إعادة'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _evalButton({
    required String label,
    required IconData icon,
    required Color backgroundColor,
    required Color foregroundColor,
    required bool narrow,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: narrow ? double.infinity : null,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
        ),
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 6),
            Expanded(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
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

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        elevation: 1,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.06),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.card),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                StudentAvatar(student: student, radius: 30),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${student.age} سنة - ${student.diagnosis}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                      ),
                      if (student.parentName.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(Icons.people_outline, size: 14, color: colorScheme.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text(
                                student.parentName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.arrow_back_ios_new_outlined, color: colorScheme.primary, size: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
