import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../widgets/app_widgets.dart';
import '../widgets/feedback.dart';

String _formatDateTime(String iso) {
  final parts = iso.split('T');
  if (parts.length < 2) return iso;
  final dateParts = parts[0].split('-');
  if (dateParts.length != 3) return iso;
  final y = dateParts[0], m = dateParts[1], d = dateParts[2];
  final timePart = parts[1].split('.')[0];
  final timeSegments = timePart.split(':');
  if (timeSegments.length < 2) return '$d-$m-$y';
  var hh = int.parse(timeSegments[0]);
  final mm = timeSegments[1];
  final period = hh >= 12 ? 'م' : 'ص';
  if (hh > 12) hh -= 12;
  if (hh == 0) hh = 12;
  final hhStr = hh.toString().padLeft(2, '0');
  return '$d-$m-$y — $hhStr:$mm $period';
}

class StudentProfileScreen extends StatelessWidget {
  const StudentProfileScreen({super.key, this.onOpenSession});

  final VoidCallback? onOpenSession;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final student = app.selectedStudent;
    if (student == null) {
      return const _StudentSelectionPrompt();
    }
    if (app.isParent) {
      return _ParentStudentProfile(app: app, student: student);
    }

    final assessments = app.clinicalAssessments;
    final assessmentSummary = assessments.isEmpty
        ? 'لا توجد تقييمات'
        : 'آخر تقييم: ${_formatDateTime(assessments.first.createdAt)}';

    final plans = app.plans;
    final goalSummary = plans.isEmpty
        ? 'لا توجد أهداف'
        : '${plans.length} أهداف قيد المتابعة';

    final exercises = app.exercises;
    final pendingCount =
        exercises.where((e) => e.status == 'pending').length;
    final reviewCount =
        exercises.where((e) => e.status == 'completed_by_parent').length;
    final reviewedCount =
        exercises.where((e) => e.status == 'specialist_reviewed').length;
    final homeworkSummary = exercises.isEmpty
        ? 'لا توجد واجبات'
        : '$pendingCount بانتظار  |  $reviewCount للمراجعة  |  $reviewedCount تمت مراجعتها';

    final followups = app.pendingFollowups;
    final followupSummary = followups.isEmpty
        ? 'لا توجد متابعات'
        : '${followups.length} مهارات تحتاج إعادة';

    final notesExercises =
        exercises.where((e) => e.parentNote.isNotEmpty).toList();
    final parentNotesSummary = notesExercises.isEmpty
        ? 'لا توجد ملاحظات'
        : '${notesExercises.length} ملاحظات';

    final timelineCount = app.sessions.length +
        app.evaluations.length +
        app.clinicalAssessments.length +
        app.exercises.length +
        app.reports.length +
        (app.reward != null ? 1 : 0);
    final timelineSummary = timelineCount == 0
        ? 'لا توجد أحداث'
        : '$timelineCount أحداث';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!app.isParent)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () => app.selectStudent(null),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('رجوع لاختيار طالب آخر'),
                ),
              ],
            ),
          ),
        StudentHeaderCard(app: app, student: student),
        const SizedBox(height: 16),
        _CollapsibleCard(
          icon: Icons.fact_check_outlined,
          title: 'التقييم العلاجي',
          summary: assessmentSummary,
          count: assessments.length,
          child: _ClinicalAssessmentProfileSection(app: app),
        ),
        const SizedBox(height: 12),
        _CollapsibleCard(
          icon: Icons.track_changes_outlined,
          title: 'الأهداف النشطة',
          summary: goalSummary,
          count: plans.where((p) => app.goalProgress(p.id) < 100).length,
          child: _GoalProgressSection(app: app, onOpenSession: onOpenSession),
        ),
        const SizedBox(height: 12),
        if (plans.any((p) => app.goalProgress(p.id) >= 100))
          _CollapsibleCard(
            icon: Icons.emoji_events_outlined,
            title: 'الأهداف المنجزة',
            summary:
                '${plans.where((p) => app.goalProgress(p.id) >= 100).length} أهداف مكتملة',
            count: plans.where((p) => app.goalProgress(p.id) >= 100).length,
            child: _MasteredGoalsSection(app: app),
          ),
        if (plans.any((p) => app.goalProgress(p.id) >= 100)) const SizedBox(height: 12),
        if (followups.isNotEmpty)
          _CollapsibleCard(
            icon: Icons.refresh_outlined,
            title: 'يحتاج إعادة تدريب',
            summary: followupSummary,
            count: followups.length,
            child: _FollowupsSection(
                app: app, onOpenSession: onOpenSession),
          ),
        if (followups.isNotEmpty) const SizedBox(height: 12),
        _CollapsibleCard(
          icon: Icons.assignment_turned_in_outlined,
          title: 'الواجبات المنزلية',
          summary: homeworkSummary,
          count: exercises.length,
          child: _HomeworkSummary(app: app),
        ),
        const SizedBox(height: 12),
        _CollapsibleCard(
          icon: Icons.chat_outlined,
          title: 'ملاحظات ولي الأمر',
          summary: parentNotesSummary,
          count: notesExercises.length,
          child: _ParentNotesCard(exercises: notesExercises),
        ),
        const SizedBox(height: 12),
        _CollapsibleCard(
          icon: Icons.auto_graph_outlined,
          title: 'الخط الزمني',
          summary: timelineSummary,
          count: timelineCount,
          child: _Timeline(app: app),
        ),
        const SizedBox(height: 16),
        _QuickActions(app: app, student: student),
        const SizedBox(height: 16),
        _PreviousSessions(app: app),
        const SizedBox(height: 16),
        _ReportsFromProfile(app: app),
      ],
    );
  }
}

class _StudentSelectionPrompt extends StatefulWidget {
  const _StudentSelectionPrompt();

  @override
  State<_StudentSelectionPrompt> createState() =>
      _StudentSelectionPromptState();
}

class _StudentSelectionPromptState extends State<_StudentSelectionPrompt> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final students = app.students.where((student) {
      if (query.trim().isEmpty) return true;
      return student.name.contains(query) || student.diagnosis.contains(query);
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EmptyState(
          icon: Icons.folder_shared_outlined,
          title: 'اختر طالبًا لعرض ملفه',
          message:
              'لا يتم فتح أي ملف تلقائيًا. اختر الطالب من القائمة أو ابحث عنه.',
          action: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'بحث سريع عن طالب',
              ),
              onChanged: (value) => setState(() => query = value),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (students.isEmpty)
          const EmptyState(
            icon: Icons.search_off_outlined,
            title: 'لا توجد نتائج',
            message: 'جرّب كتابة اسم أو تشخيص مختلف.',
          )
        else
          ResponsiveGrid(
            children: students
                .map((student) => TherapyCard(
                      title: student.name,
                      icon: Icons.child_care_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              StudentAvatar(student: student, radius: 32),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(student.diagnosis, maxLines: 2, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    AppPill(label: student.status),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () => app.selectStudent(student),
                              icon: const Icon(Icons.folder_shared_outlined),
                              label: const Text('فتح الملف'),
                            ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
      ],
    );
  }
}

class _ParentStudentProfile extends StatelessWidget {
  const _ParentStudentProfile({required this.app, required this.student});

  final AppProvider app;
  final Student student;

  @override
  Widget build(BuildContext context) {
    final completedHomework =
        app.exercises.where((item) => item.status == 'تم الإنجاز').length;
    final reward = app.reward;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StudentAvatar(student: student, radius: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        const Text('متابعة منزلية مبسطة لولي الأمر',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Chip(label: Text(student.status)),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _InfoTile('العمر', '${student.age}'),
                  _InfoTile('التشخيص', student.diagnosis),
                  _InfoTile('الواجبات المنجزة', '$completedHomework'),
                  _InfoTile('الجلسات المكتملة', '${app.sessions.length}'),
                  if (reward != null) _InfoTile('المستوى', '${reward.level}'),
                  if (reward != null) _InfoTile('النقاط', '${reward.xp}'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(
                  context, 'الواجبات الحالية', Icons.assignment_outlined),
              const SizedBox(height: 10),
              if (app.exercises.isEmpty)
                const Text('لا توجد واجبات حالية.')
              else
                ...app.exercises.take(5).map((exercise) => _ParentHomeworkTile(
                      exercise: exercise,
                    )),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(
                  context, 'الجلسات المكتملة', Icons.history_edu_outlined),
              const SizedBox(height: 10),
              if (app.sessions.isEmpty)
                const Text('لا توجد جلسات مكتملة بعد.')
              else
                ...app.sessions.take(8).map((session) => _ParentSessionCard(
                      session: session,
                      parentNote: _noteForSession(app.exercises, session),
                    )),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(context, 'الملاحظات والملفات', Icons.mic_none),
              const SizedBox(height: 10),
              const Text(
                'يمكنك إرسال ملاحظة للأخصائي من بطاقة الواجب. رفع الصوت والفيديو مجهز لاحقًا.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _noteForSession(List<Exercise> exercises, TherapySession session) {
    for (final exercise in exercises) {
      if (exercise.title.contains(session.cardTitle) &&
          exercise.parentNote.isNotEmpty) {
        return exercise.parentNote;
      }
    }
    return '';
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.app, required this.student});

  final AppProvider app;
  final Student student;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, 'الإجراءات السريعة', Icons.bolt_outlined),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _reportButton(context, 'تقرير مختصر'),
              FilledButton.tonalIcon(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('سيتم تفعيل اختبار جلسة محددة لاحقًا'),
                  ),
                ),
                icon: const Icon(Icons.science_outlined),
                label: const Text('اختبار جلسة محددة'),
              ),
              _reportButton(context, 'تقرير شامل'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _reportButton(BuildContext context, String type) {
    return FilledButton.tonalIcon(
      onPressed: app.canViewReports
          ? () => type == 'تقرير مختصر'
              ? _chooseSessionReport(context)
              : runWithFeedback(
                  context,
                  () => app.printReportForSessions(
                    type: type,
                    selectedSessions: _sessionsForType(type),
                    specialistSignature: app.user?.name ?? 'الأخصائي',
                    managerSignature: app.currentCenter?.managerName ?? '',
                  ),
                  loading: 'جار إنشاء التقرير...',
                  success: 'تم إنشاء التقرير.',
                )
          : null,
      icon: const Icon(Icons.picture_as_pdf_outlined),
      label: Text(type, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }

  Future<void> _chooseSessionReport(BuildContext context) async {
    if (app.sessions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد جلسات للطالب.')),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('اختر جلسة للتقرير'),
        content: SizedBox(
          width: MediaQuery.of(context).size.width.clamp(300, 560).toDouble(),
          child: ListView(
            shrinkWrap: true,
            children: app.sessions.map((session) {
              return ListTile(
                title: Text(session.cardTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                    '${session.startedAt.split('T').first} - نجاح ${session.successRate}%', maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.picture_as_pdf_outlined),
                onTap: () async {
                  await runWithFeedback(
                    context,
                    () => app.printReportForSessions(
                      type: 'تقرير جلسة',
                      selectedSessions: [session],
                      specialistSignature: app.user?.name ?? 'الأخصائي',
                      managerSignature: app.currentCenter?.managerName ?? '',
                    ),
                    loading: 'جار إنشاء التقرير...',
                    success: 'تم إنشاء التقرير.',
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  List<TherapySession> _sessionsForType(String type) {
    if (type == 'تقرير شامل') return app.sessions;
    final now = DateTime.now();
    final from = switch (type) {
      'تقرير مختصر' => now.subtract(const Duration(days: 7)),
      _ => DateTime(1900),
    };
    return app.sessions.where((session) {
      final date = DateTime.tryParse(session.startedAt);
      return date != null && !date.isBefore(from);
    }).toList();
  }
}

class _ClinicalAssessmentProfileSection extends StatelessWidget {
  const _ClinicalAssessmentProfileSection({required this.app});

  final AppProvider app;

  @override
  Widget build(BuildContext context) {
    final assessments = app.clinicalAssessments;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            context,
            'التقييم العلاجي',
            Icons.fact_check_outlined,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (assessments.isEmpty)
            const Text(
              'لم يتم حفظ تقييم علاجي بعد. ابدأ من شاشة التقييم العلاجي لبناء الأهداف.',
            )
          else
            ...assessments.take(3).map((assessment) {
              final findings =
                  app.clinicalFindingsByAssessment[assessment.id] ?? const [];
              final weaknesses =
                  findings.where((finding) => !finding.isNormal).toList();
              return Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(AppRadii.control),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'تقييم نطقي - ${_formatDateTime(assessment.createdAt)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SanadText.subtitle(context),
                            ),
                          ),
                          AppPill(
                          label: weaknesses.isEmpty
                              ? 'كلها طبيعية'
                              : '${weaknesses.length} أهداف',
                          icon: weaknesses.isEmpty
                              ? Icons.verified_outlined
                              : Icons.track_changes_outlined,
                          selected: weaknesses.isEmpty,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (assessment.strengthsSummary.isNotEmpty)
                      Text(
                        'القوة:\n${assessment.strengthsSummary}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: SanadText.secondary(context),
                      ),
                    if (assessment.weaknessesSummary.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'الضعف:\n${assessment.weaknessesSummary}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: SanadText.secondary(context),
                      ),
                    ],
                    if (assessment.goalsSummary.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'الأهداف:\n${assessment.goalsSummary}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: SanadText.secondary(context),
                      ),
                    ],
                  ],
                ),
              );
            }),
          const SizedBox(height: AppSpacing.md),
          _ImprovementSummaryCard(app: app),
        ],
      ),
    );
  }
}

class _ImprovementSummaryCard extends StatelessWidget {
  const _ImprovementSummaryCard({required this.app});

  final AppProvider app;

  @override
  Widget build(BuildContext context) {
    final summary = app.studentAssessmentImprovement;
    final colorScheme = Theme.of(context).colorScheme;

    if (!summary.hasEnoughData) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadii.control),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 18, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'يحتاج تقييمين للمقارنة',
                style: SanadText.secondary(context),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: colorScheme.primaryContainer),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.compare_arrows, size: 18, color: colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'تحسن الطالب بين التقييمات',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _ImprovementStat(
                  label: 'نسبة التحسن',
                  value: '${summary.improvementRate.round()}%',
                  color: summary.improvementRate >= 50
                      ? Colors.green
                      : Colors.orange,
                ),
              ),
              Expanded(
                child: _ImprovementStat(
                  label: 'تحسنت',
                  value: '${summary.improvedCount}',
                  color: Colors.green,
                ),
              ),
              Expanded(
                child: _ImprovementStat(
                  label: 'لم تتحسن',
                  value: '${summary.unchangedWeaknessCount}',
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          if (summary.regressionCount > 0 || summary.newFindingCount > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                if (summary.regressionCount > 0)
                  Expanded(
                    child: _ImprovementStat(
                      label: 'تراجع',
                      value: '${summary.regressionCount}',
                      color: Colors.red,
                    ),
                  ),
                if (summary.newFindingCount > 0)
                  Expanded(
                    child: _ImprovementStat(
                      label: 'مستجد',
                      value: '${summary.newFindingCount}',
                      color: Colors.purple,
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            summary.previousDate != null && summary.currentDate != null
                ? 'من: ${_formatDateTime(summary.previousDate!)}\nإلى: ${_formatDateTime(summary.currentDate!)}'
                : '',
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImprovementStat extends StatelessWidget {
  const _ImprovementStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalProgressSection extends StatelessWidget {
  const _GoalProgressSection({required this.app, this.onOpenSession});

  final AppProvider app;
  final VoidCallback? onOpenSession;

  @override
  Widget build(BuildContext context) {
    final activePlans =
        app.plans.where((p) => app.goalProgress(p.id) < 100).toList();
    final masteredPlans =
        app.plans.where((p) => app.goalProgress(p.id) >= 100).toList();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            context,
            'متابعة الأهداف العلاجية',
            Icons.track_changes_outlined,
          ),
          const SizedBox(height: 12),
          if (activePlans.isEmpty && masteredPlans.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('لا توجد أهداف علاجية بعد.'),
            )
          else if (activePlans.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('كل الأهداف مكتملة.'),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final narrow = width < 500;
                if (narrow) {
                  return Column(
                    children: activePlans.map((plan) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _GoalCard(
                        key: ValueKey(plan.id),
                        app: app,
                        plan: plan,
                        onOpenSession: onOpenSession,
                        onTrainPressed: () =>
                            _openRetrainPlan(context, plan),
                      ),
                    )).toList(),
                  );
                }
                final columns = width < 750 ? 2 : 3;
                const spacing = 12.0;
                final cardWidth =
                    (width - spacing * (columns - 1)) / columns;
                return Wrap(
                  spacing: spacing,
                  runSpacing: 12,
                  children: activePlans.map((plan) => SizedBox(
                    width: cardWidth,
                    child: _GoalCard(
                      key: ValueKey(plan.id),
                      app: app,
                      plan: plan,
                      onOpenSession: onOpenSession,
                      onTrainPressed: () =>
                          _openRetrainPlan(context, plan),
                    ),
                  )).toList(),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _openRetrainPlan(
      BuildContext context, TrainingPlan plan) async {
    final app = context.read<AppProvider>();
    final students =
        app.students.where((s) => s.id == plan.studentId).toList();
    if (students.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'تعذر فتح التمرين مباشرة: لم يتم العثور على الطالب.')),
        );
      }
      return;
    }
    await app.selectStudent(students.first);
    if (!context.mounted) return;
    app.preselectSession({
      'studentId': plan.studentId,
      'programId': plan.programId,
      'sourceType': plan.sourceType,
      'planId': plan.id,
    });
    onOpenSession?.call();
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    super.key,
    required this.app,
    required this.plan,
    this.onOpenSession,
    this.onTrainPressed,
  });

  final AppProvider app;
  final TrainingPlan plan;
  final VoidCallback? onOpenSession;
  final VoidCallback? onTrainPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final steps = app.stepsForGoal(plan.id);
    final progress = app.goalProgress(plan.id);
    final status = app.goalStatus(plan.id);
    final lastSession = _lastSessionDate(steps);
    final followupsCount = app.pendingFollowups
        .where((f) => f.planId == plan.id && f.status == 'pending')
        .length;
    final skillsCount = steps.length;
    final hasSessions = app.sessions.any((s) => s.planId == plan.id);
    final borderColor = _borderColor(status, colorScheme);

    return GestureDetector(
      onTap: () => _showGoalDetails(context),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: borderColor, width: 1.5),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      plan.goal,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusBadge(status: status),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress / 100,
                  minHeight: 8,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor:
                      AlwaysStoppedAnimation(_progressColor(status, colorScheme)),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _MiniInfoChip(
                    icon: Icons.history_outlined,
                    label: lastSession,
                  ),
                  if (skillsCount > 0)
                    _MiniInfoChip(
                      icon: Icons.list_alt_outlined,
                      label: '$skillsCount مهارات',
                    ),
                  if (followupsCount > 0)
                    _MiniInfoChip(
                      icon: Icons.refresh_outlined,
                      label: '$followupsCount متابعات',
                      highlight: true,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: onTrainPressed,
                  icon: Icon(
                    hasSessions
                        ? Icons.refresh_outlined
                        : Icons.play_arrow_outlined,
                    size: 18,
                  ),
                  label: Text(
                    hasSessions ? 'إعادة التدريب' : 'تدريب',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _borderColor(String status, ColorScheme colors) {
    switch (status) {
      case 'جديد':
        return colors.outlineVariant;
      case 'يحتاج مساعدة':
        return const Color(0xFFFCD34D).withValues(alpha: 0.7);
      case 'يحتاج إعادة':
        return colors.error.withValues(alpha: 0.5);
      default:
        return colors.primary.withValues(alpha: 0.4);
    }
  }

  Color _progressColor(String status, ColorScheme colors) {
    switch (status) {
      case 'جديد':
        return colors.outlineVariant;
      case 'يحتاج مساعدة':
        return const Color(0xFFF59E0B);
      case 'يحتاج إعادة':
        return colors.error;
      default:
        return colors.primary;
    }
  }

  String _lastSessionDate(List<GoalSkillStep> steps) {
    final sessionIds = steps
        .map((step) => step.lastSessionId)
        .where((value) => value.trim().isNotEmpty)
        .toSet();
    final matches = app.sessions
        .where((session) =>
            sessionIds.contains(session.id) || session.planId == plan.id)
        .toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    if (matches.isEmpty) return 'لا توجد';
    return matches.first.startedAt.split('T').first;
  }

  void _showGoalDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => _GoalDetails(
          app: app,
          plan: plan,
          scrollController: scrollController,
        ),
      ),
    );
  }
}

class _GoalDetails extends StatelessWidget {
  const _GoalDetails({
    required this.app,
    required this.plan,
    this.scrollController,
  });

  final AppProvider app;
  final TrainingPlan plan;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final steps = app.stepsForGoal(plan.id);
    final status = app.goalStatus(plan.id);
    final progress = app.goalProgress(plan.id);
    final sessions = app.sessions.where((s) => s.planId == plan.id).toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final lastSession =
        sessions.isNotEmpty ? sessions.first.startedAt.split('T').first : 'لا توجد';
    final sessionsCount = sessions.length;
    final followups = app.pendingFollowups
        .where((f) => f.planId == plan.id && f.status == 'pending')
        .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: ListView(
        controller: scrollController,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(plan.goal,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: colorScheme.onSurface,
                    )),
              ),
              const SizedBox(width: 8),
              _StatusBadge(status: status),
            ],
          ),
          if (plan.treatment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('العلاج:',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 13)),
            const SizedBox(height: 4),
            Text(plan.treatment,
                style:
                    TextStyle(color: colorScheme.onSurface, fontSize: 14)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              _DetailStat(
                  icon: Icons.history_outlined,
                  title: 'آخر جلسة',
                  value: lastSession),
              const SizedBox(width: 16),
              _DetailStat(
                  icon: Icons.play_circle_outlined,
                  title: 'الجلسات',
                  value: '$sessionsCount'),
              if (steps.isNotEmpty) ...[
                const SizedBox(width: 16),
                _DetailStat(
                    icon: Icons.list_alt_outlined,
                    title: 'المهارات',
                    value: '${steps.length}'),
              ],
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress / 100,
              minHeight: 8,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 4),
          Text('التقدم: $progress%',
              style: TextStyle(
                  fontSize: 12, color: colorScheme.onSurfaceVariant)),
          if (steps.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('المهارات:',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 13)),
            const SizedBox(height: 8),
            ...steps.map((step) {
              final hasPending = followups
                  .any((f) => f.goalSkillStepId == step.id);
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      step.status == 'متقن'
                          ? Icons.check_circle
                          : hasPending
                              ? Icons.refresh_outlined
                              : Icons.radio_button_unchecked,
                      size: 18,
                      color: step.status == 'متقن'
                          ? Colors.green
                          : hasPending
                              ? Colors.orange
                              : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${step.title} - ${step.status}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: step.status == 'متقن'
                              ? FontWeight.normal
                              : FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          if (followups.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('المتابعات المفتوحة:',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.error,
                    fontSize: 13)),
            const SizedBox(height: 8),
            ...followups.map((f) {
              final step =
                  steps.where((s) => s.id == f.goalSkillStepId).firstOrNull;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.refresh_outlined,
                        size: 18, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        step?.title ?? 'مهارة غير معروفة',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (Color bg, Color fg, IconData icon) = switch (status) {
      'جديد' => (colorScheme.surfaceContainerHighest,
          colorScheme.onSurfaceVariant, Icons.fiber_new_outlined),
      'يحتاج مساعدة' => (const Color(0xFFFEF3C7),
          const Color(0xFF92400E), Icons.help_outline),
      'يحتاج إعادة' => (colorScheme.errorContainer,
          colorScheme.onErrorContainer, Icons.refresh_outlined),
      _ => (colorScheme.primaryContainer,
          colorScheme.onPrimaryContainer, Icons.trending_up_outlined),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            status,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniInfoChip extends StatelessWidget {
  const _MiniInfoChip({
    required this.icon,
    required this.label,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fg = highlight ? Colors.orange.shade700 : colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  const _DetailStat({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: colorScheme.primary),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600)),
            Text(value,
                style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ],
    );
  }
}

class _MasteredGoalsSection extends StatelessWidget {
  const _MasteredGoalsSection({required this.app});

  final AppProvider app;

  @override
  Widget build(BuildContext context) {
    final masteredPlans = app.plans.where((p) => app.goalProgress(p.id) >= 100).toList();
    if (masteredPlans.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: masteredPlans.map((plan) {
        final steps = app.stepsForGoal(plan.id);
        final masteredSteps =
            steps.where((step) => step.status == 'متقن').length;
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(AppRadii.card),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.emoji_events, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      plan.goal,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SanadText.subtitle(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              LinearProgressIndicator(
                value: 1,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  const AppPill(label: 'مكتمل'),
                  AppPill(label: 'مهارات متقنة: $masteredSteps/${steps.length}'),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class StudentHeaderCard extends StatelessWidget {
  const StudentHeaderCard({required this.app, required this.student});

  final AppProvider app;
  final Student student;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final programs = app.programsForStudent();
    final lastSession = app.sessions.isNotEmpty ? app.sessions.first : null;
    final assessmentStatus = app.studentAssessmentStatus;
    final improvement = app.selectedStudent != null
        ? app.studentGoalAverageProgress(app.selectedStudent!.id)
        : 0;
    final pendingFollowups = app.pendingFollowups.length;
    final masteredCount = app.masteredGoalCount;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Avatar + Name + Status ──
          Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(Icons.child_care,
                    size: 32, color: colorScheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(student.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900)),
                    if (app.currentCenter != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(app.currentCenter!.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant)),
                      ),
                  ],
                ),
              ),
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text(student.status,
                    style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Diagnosis ──
          if (student.diagnosis.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(Icons.medical_information_outlined,
                      size: 16, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(student.diagnosis,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium
                            ?.copyWith(color: colorScheme.onSurfaceVariant)),
                  ),
                ],
              ),
            ),

          // ── Program chips ──
          if (programs.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: programs
                  .map((p) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius:
                              BorderRadius.circular(AppRadii.control),
                        ),
                        child: Text(p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: colorScheme.onSecondaryContainer)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 14),
          ],

          // ── Stats chips ──
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatChip(
                icon: Icons.history_outlined,
                label: 'آخر جلسة',
                value: lastSession != null
                    ? lastSession.startedAt.split('T').first
                    : 'لا توجد',
              ),
              if (lastSession != null)
                _StatChip(
                  icon: Icons.check_circle_outline,
                  label: 'النتيجة',
                  value: lastSession.quickResult,
                  chipColor: lastSession.quickResult == 'متقن'
                      ? colorScheme.primary
                      : lastSession.quickResult == 'بمساعدة'
                          ? colorScheme.tertiary
                          : colorScheme.error,
                ),
              _StatChip(
                icon: Icons.calendar_today_outlined,
                label: 'جلسات',
                value: '${app.sessions.length}',
              ),
              _StatChip(
                icon: Icons.track_changes_outlined,
                label: 'أهداف نشطة',
                value: app.activeGoalCount,
              ),
              if (masteredCount != '0')
                _StatChip(
                  icon: Icons.emoji_events_outlined,
                  label: 'منجز',
                  value: masteredCount,
                ),
              _StatChip(
                icon: Icons.refresh_outlined,
                label: 'متابعات',
                value: '$pendingFollowups',
              ),
              _StatChip(
                icon: Icons.assignment_turned_in_outlined,
                label: 'للمراجعة',
                value: app.pendingHomeworkReviewCount,
              ),
              _StatChip(
                icon: assessmentStatus == 'مقيّم'
                    ? Icons.fact_check_outlined
                    : Icons.pending_outlined,
                label: 'التقييم',
                value: assessmentStatus,
              ),
              _StatChip(
                icon: Icons.trending_up_outlined,
                label: 'متوسط التقدم',
                value: assessmentStatus == 'مقيّم' ? '$improvement%' : '-',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    this.chipColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? chipColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = chipColor ?? colorScheme.primary;
    return Container(
      constraints: const BoxConstraints(minWidth: 90),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 10, color: colorScheme.onSurfaceVariant)),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: colorScheme.onSurface)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FollowupsSection extends StatelessWidget {
  const _FollowupsSection(
      {required this.app, required this.onOpenSession});

  final AppProvider app;
  final VoidCallback? onOpenSession;

  @override
  Widget build(BuildContext context) {
    final followups = app.pendingFollowups;
    if (followups.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('لا توجد متابعات مفتوحة.'),
      );
    }
    return Column(
      children: followups.map((f) => _FollowupTile(
            followup: f,
            app: app,
            onOpenSession: onOpenSession,
          )).toList(),
    );
  }
}

class _FollowupTile extends StatelessWidget {
  const _FollowupTile({
    required this.followup,
    required this.app,
    required this.onOpenSession,
  });

  final StudentFollowup followup;
  final AppProvider app;
  final VoidCallback? onOpenSession;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final step = app.goalSkillSteps
        .where((s) => s.id == followup.goalSkillStepId)
        .firstOrNull;
    final plan = app.plans
        .where((p) => p.id == followup.planId)
        .firstOrNull;
    final stepName = step?.title ?? 'مهارة غير معروفة';
    final goalName = plan?.goal ?? 'هدف غير معروف';
    final reasonText =
        followup.reason == 'assisted' ? 'بمساعدة' : 'يحتاج إعادة';
    final reasonColor = followup.reason == 'assisted'
        ? colorScheme.tertiary
        : colorScheme.error;
    final lastOpened = followup.lastOpenedAt.isNotEmpty
        ? followup.lastOpenedAt.split('T').first
        : followup.createdAt.split('T').first;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(stepName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: reasonColor.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(reasonText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: reasonColor)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(goalName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text('آخر تحديث: $lastOpened',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: () => _openRetrain(context),
              child: const Text('إعادة التدريب',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openRetrain(BuildContext context) async {
    final app = context.read<AppProvider>();
    final students =
        app.students.where((s) => s.id == followup.studentId).toList();
    if (students.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر فتح التمرين مباشرة: لم يتم العثور على الطالب.'),
          ),
        );
      }
      return;
    }
    final stepExists = app.goalSkillSteps
        .any((s) => s.id == followup.goalSkillStepId);
    if (!stepExists) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر فتح التمرين مباشرة: المهارة غير موجودة.'),
          ),
        );
      }
      return;
    }
    await app.selectStudent(students.first);
    if (!context.mounted) return;
    app.preselectSession({
      'studentId': followup.studentId,
      'programId': followup.programId,
      'sourceType': followup.sourceType,
      'planId': followup.planId,
      'stepId': followup.goalSkillStepId,
    });
    onOpenSession?.call();
  }
}

class _PreviousSessions extends StatelessWidget {
  const _PreviousSessions({required this.app});

  final AppProvider app;

  @override
  Widget build(BuildContext context) {
    final sortedSessions = app.sessions.toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, 'الجلسات السابقة', Icons.timeline_outlined),
          const SizedBox(height: 10),
          if (sortedSessions.isEmpty)
            const Text('لا توجد جلسات بعد.')
          else
            ...sortedSessions.map((session) => _SessionTile(session: session, app: app)),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.app});

  final TherapySession session;
  final AppProvider app;

  @override
  Widget build(BuildContext context) {
    final activities = _activityTags(session.practiceItems);
    return GestureDetector(
      onTap: () => _showDetails(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(session.cardTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w900)),
                ),
                Chip(label: Text('${session.successRate}%')),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(session.startedAt.split('T').first)),
                Chip(label: Text(session.sessionType)),
                Chip(label: Text(session.quickResult, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
            if (activities.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final activity in activities.take(4))
                    Chip(label: Text(activity)),
                  if (activities.length > 4)
                    Chip(label: Text('+${activities.length - 4}')),
                ],
              ),
            ],
            if (session.summary.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(session.summary, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            if (session.notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('ملاحظة الأخصائي: ${session.notes}', maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    final canCorrect = _canCorrect();
    final disabledReason = _correctionDisabledReason();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(session.cardTitle,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            _detailRow(context, 'التاريخ', session.startedAt.split('T').first),
            _detailRow(context, 'نوع الجلسة', session.sessionType),
            _detailRow(context, 'النتيجة', session.quickResult),
            _detailRow(context, 'نسبة النجاح', '${session.successRate}%'),
            if (session.practiceItems.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('الأنشطة:', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(session.practiceItems),
            ],
            if (session.notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('ملاحظات:', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(session.notes),
            ],
            if (canCorrect) ...[
              const Divider(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () => _showCorrectionDialog(context),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('تصحيح النتيجة'),
                ),
              ),
              const SizedBox(height: 4),
              Text('فترة التصحيح: 24 ساعة من إنشاء الجلسة',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      )),
            ] else if (disabledReason != null) ...[
              const Divider(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: null,
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(disabledReason),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text('$label: ',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          Expanded(
            child: Text(value,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  bool _canCorrect() {
    final createdAt = DateTime.tryParse(session.startedAt);
    if (createdAt == null) return false;
    final hoursSince = DateTime.now().difference(createdAt).inHours;
    if (hoursSince >= 24) return false;
    if (session.specialistId.isEmpty) return false;
    return session.specialistId == app.user?.id || app.isCenterManager;
  }

  String? _correctionDisabledReason() {
    if (session.specialistId.isEmpty) return 'معلومات المنشئ غير متوفرة';
    final createdAt = DateTime.tryParse(session.startedAt);
    if (createdAt == null) return null;
    final hoursSince = DateTime.now().difference(createdAt).inHours;
    if (hoursSince >= 24) return 'انتهت فترة التصحيح (24 ساعة)';
    final isCreator = session.specialistId == app.user?.id;
    if (!isCreator && !app.isCenterManager) return 'يمكن لكاتب الجلسة فقط التصحيح';
    return null;
  }

  void _showCorrectionDialog(BuildContext context) {
    final oldResult = session.quickResult;
    String selected = oldResult;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('تصحيح نتيجة الجلسة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('سيتم تعديل نتيجة هذه الجلسة وإعادة حساب حالة الهدف والمتابعات.'),
              const SizedBox(height: 16),
              for (final result in ['متقن', 'بمساعدة', 'يحتاج إعادة'])
                InkWell(
                  onTap: () => setDialogState(() => selected = result),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Radio<String>(
                          value: result,
                          groupValue: selected,
                          onChanged: (v) => setDialogState(() => selected = v!),
                          toggleable: false,
                        ),
                        const SizedBox(width: 8),
                        Text(result),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: selected == oldResult
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      _showConfirmDialog(context, oldResult, selected);
                    },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirmDialog(
      BuildContext context, String oldResult, String newResult) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد التصحيح'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('هل أنت متأكد من تصحيح نتيجة الجلسة؟'),
            const SizedBox(height: 12),
            Text('من: $oldResult'),
            Text('إلى: $newResult'),
            const SizedBox(height: 12),
            Text('لن يتم إنشاء جلسة جديدة. سيتم تحديث حالة الهدف والمتابعات فقط.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _executeCorrection(context, newResult);
            },
            child: const Text('تأكيد التصحيح'),
          ),
        ],
      ),
    );
  }

  void _executeCorrection(BuildContext context, String newResult) {
    runWithFeedback(
      context,
      () => app.correctSessionResult(
        sessionId: session.id,
        newQuickResult: newResult,
        newSuccessRate: switch (newResult) {
          'متقن' => 100,
          'بمساعدة' => 60,
          _ => 20,
        },
      ),
      success: 'تم تصحيح النتيجة.',
      loading: 'جارٍ تصحيح النتيجة...',
    );
  }
}

class _ReportsFromProfile extends StatelessWidget {
  const _ReportsFromProfile({required this.app});

  final AppProvider app;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, 'التقارير', Icons.picture_as_pdf_outlined),
          const SizedBox(height: 10),
          if (app.reports.isEmpty)
            const Text('لا توجد تقارير محفوظة بعد.')
          else
            ...app.reports.map((report) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.picture_as_pdf_outlined),
                  title: Text(report.type, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('نسبة التقدم ${report.improvementRate}%'),
                  trailing: Text(report.createdAt.split('T').first),
                )),
        ],
      ),
    );
  }
}

class _HomeworkSummary extends StatelessWidget {
  const _HomeworkSummary({required this.app});

  final AppProvider app;

  @override
  Widget build(BuildContext context) {
    final pending = app.exercises
        .where((e) => e.status == 'pending')
        .toList();
    final review = app.exercises
        .where((e) => e.status == 'completed_by_parent')
        .toList();
    final reviewed = app.exercises
        .where((e) => e.status == 'specialist_reviewed')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HomeworkSection(
          icon: Icons.hourglass_empty_outlined,
          title: 'بانتظار ولي الأمر',
          count: pending.length,
          color: Colors.orange,
          exercises: pending,
          app: app,
        ),
        const SizedBox(height: AppSpacing.sm),
        _HomeworkSection(
          icon: Icons.rate_review_outlined,
          title: 'تحتاج مراجعة',
          count: review.length,
          color: Colors.blue,
          exercises: review,
          app: app,
        ),
        const SizedBox(height: AppSpacing.sm),
        _HomeworkSection(
          icon: Icons.check_circle_outline,
          title: 'تمت مراجعتها',
          count: reviewed.length,
          color: Colors.green,
          exercises: reviewed,
          app: app,
        ),
      ],
    );
  }
}

class _HomeworkSection extends StatelessWidget {
  const _HomeworkSection({
    required this.icon,
    required this.title,
    required this.count,
    required this.color,
    required this.exercises,
    required this.app,
  });

  final IconData icon;
  final String title;
  final int count;
  final Color color;
  final List<Exercise> exercises;
  final AppProvider app;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w900, color: color)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('$count',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (exercises.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                'لا توجد واجبات',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          else
            ...exercises.map((ex) => _HomeworkTile(
                  exercise: ex,
                  app: app,
                )),
        ],
      ),
    );
  }
}

class _HomeworkTile extends StatelessWidget {
  const _HomeworkTile({required this.exercise, required this.app});

  final Exercise exercise;
  final AppProvider app;

  @override
  Widget build(BuildContext context) {
    final hasPlan = exercise.planId.isNotEmpty;
    final plan =
        app.plans.where((p) => p.id == exercise.planId).toList();
    final planName = plan.isNotEmpty ? plan.first.goal : '';
    final step = exercise.goalSkillStepId.isNotEmpty
        ? app.goalSkillSteps
            .where((s) => s.id == exercise.goalSkillStepId)
            .toList()
        : <GoalSkillStep>[];
    final stepName = step.isNotEmpty ? step.first.title : '';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(exercise.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              if (exercise.status == 'pending')
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('بانتظار',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Colors.orange, fontSize: 11)),
                )
              else if (exercise.status == 'completed_by_parent')
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('للمراجعة',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Colors.blue, fontSize: 11)),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('تمت المراجعة',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Colors.green, fontSize: 11)),
                ),
            ],
          ),
          if (exercise.instructions.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(exercise.instructions,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall),
          ],
          if (hasPlan) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.track_changes_outlined,
                    size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    planName.isNotEmpty ? planName : 'هدف علاجي',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary),
                  ),
                ),
              ],
            ),
          ],
          if (stepName.isNotEmpty && hasPlan) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.checklist_outlined,
                    size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    stepName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
          if (exercise.parentNote.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: SanadUiColors.accentAmber,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.chat_outlined, size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(exercise.parentNote,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                exercise.parentCompletedAt.isNotEmpty
                    ? 'تم: ${exercise.parentCompletedAt.split('T').first}'
                    : 'أرسل: ${exercise.createdAt.isNotEmpty ? exercise.createdAt.split('T').first : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              if (exercise.status == 'completed_by_parent' && !app.isParent)
                FilledButton.tonal(
                  onPressed: () => _reviewHomework(context, exercise),
                  child: const Text('مراجعة',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              if (exercise.stars > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text('★ ${exercise.stars}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _reviewHomework(
      BuildContext context, Exercise exercise) async {
    final app = context.read<AppProvider>();
    final student = app.selectedStudent;
    if (student == null) return;
    if (exercise.planId.isEmpty) return;
    final plan =
        app.plans.where((p) => p.id == exercise.planId).toList();
    if (plan.isEmpty) return;
    final planItem = plan.first;
    if (exercise.goalSkillStepId.isNotEmpty) {
      final step = app.goalSkillSteps
          .where((s) => s.id == exercise.goalSkillStepId)
          .toList();
      if (step.isNotEmpty) {
        await app.updateGoalSkillStepStatus(
          step: step.first,
          status: 'متقن',
          notes: 'تم اعتماد الإتقان بعد واجب منزلي.',
        );
        await app.resolveFollowupForStep(student.id, step.first.id);
      }
    } else {
      await app.updatePlanProgress(
        planId: planItem.id,
        progress: 100,
      );
    }
    final now = DateTime.now().toIso8601String();
    await app.saveExercise(
      exercise.copyWith(
        status: 'specialist_reviewed',
        specialistReviewedAt: now,
      ),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم اعتماد إتقان المهارة.')),
      );
    }
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.app});

  final AppProvider app;

  @override
  Widget build(BuildContext context) {
    final items = _timeline(app);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, 'الخط الزمني', Icons.auto_graph_outlined),
          const SizedBox(height: 10),
          if (items.isEmpty)
            const EmptyState(
              icon: Icons.timeline_outlined,
              title: 'لا يوجد سجل علاجي بعد',
              message: 'سيظهر هنا سجل الجلسات والتقييمات والواجبات والتقارير.',
            )
          else
            ...items.map((item) => _TimelineRow(item: item)),
        ],
      ),
    );
  }

  List<_TimelineItem> _timeline(AppProvider app) {
    final items = <_TimelineItem>[
      ...app.sessions.map((session) => _TimelineItem(
          Icons.record_voice_over_outlined,
          'جلسة ${session.sessionType}',
          '${session.cardTitle} - نجاح ${session.successRate}%',
          session.startedAt)),
      ...app.evaluations.map((evaluation) => _TimelineItem(
          Icons.fact_check_outlined,
          'تقييم حرف ${evaluation.letter}',
          '${evaluation.position} - ${evaluation.errorType} - شدة ${evaluation.severity}',
          evaluation.createdAt)),
      ...app.clinicalAssessments.map((assessment) => _TimelineItem(
          Icons.psychology_alt_outlined,
          'تقييم علاجي نطقي',
          assessment.weaknessesSummary.isEmpty
              ? 'لا توجد نقاط ضعف في البنود المقيمة.'
              : assessment.weaknessesSummary,
          assessment.createdAt)),
      ...app.exercises.map((exercise) => _TimelineItem(
          Icons.assignment_outlined,
          'واجب منزلي',
          '${exercise.title} - ${exercise.status}',
          exercise.dueDate)),
      ...app.reports.map((report) => _TimelineItem(
          Icons.picture_as_pdf_outlined,
          'تقرير ${report.type}',
          'نسبة التقدم ${report.improvementRate}%',
          report.createdAt)),
    ];
    final reward = app.reward;
    if (reward != null) {
      items.add(_TimelineItem(
          Icons.workspace_premium_outlined,
          'مكافآت ونقاط',
          'XP ${reward.xp} - المستوى ${reward.level}',
          DateTime.now().toIso8601String()));
    }
    items.sort((a, b) => b.date.compareTo(a.date));
    return items;
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.item});

  final _TimelineItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(item.icon,
                  size: 20, color: colorScheme.onPrimaryContainer),
            ),
            Container(width: 2, height: 42, color: colorScheme.outlineVariant),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    AppPill(label: item.date.split('T').first),
                  ],
                ),
                const SizedBox(height: 6),
                Text(item.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ParentHomeworkTile extends StatelessWidget {
  const _ParentHomeworkTile({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.assignment_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exercise.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('الحالة: ${exercise.status}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Text('★ ${exercise.stars}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _ParentSessionCard extends StatelessWidget {
  const _ParentSessionCard({required this.session, required this.parentNote});

  final TherapySession session;
  final String parentNote;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(session.cardTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              Chip(label: Text('نجاح ${session.successRate}%')),
            ],
          ),
          const SizedBox(height: 8),
          Text('التاريخ: ${session.startedAt.split('T').first}'),
          Text('البرنامج: ${session.sessionType}'),
          if (parentNote.isNotEmpty) Text('ملاحظتك: $parentNote', maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        Text(
          value.isEmpty ? '-' : value,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _TimelineItem {
  const _TimelineItem(this.icon, this.title, this.subtitle, this.date);

  final IconData icon;
  final String title;
  final String subtitle;
  final String date;
}

class _CollapsibleCard extends StatefulWidget {
  const _CollapsibleCard({
    required this.icon,
    required this.title,
    required this.summary,
    required this.child,
    this.count,
  });

  final IconData icon;
  final String title;
  final String summary;
  final Widget child;
  final int? count;

  @override
  State<_CollapsibleCard> createState() => _CollapsibleCardState();
}

class _CollapsibleCardState extends State<_CollapsibleCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(AppRadii.card),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(widget.icon, size: 18, color: colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (widget.count != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${widget.count}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.only(
                        bottom: 16, left: 16, right: 16),
                    child: widget.child,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _ParentNotesCard extends StatelessWidget {
  const _ParentNotesCard({required this.exercises});
  final List<Exercise> exercises;

  @override
  Widget build(BuildContext context) {
    if (exercises.isEmpty) {
      return const Text('لا توجد ملاحظات من ولي الأمر.');
    }
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: exercises.map((e) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(e.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Text(e.parentNote,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colorScheme.onSurfaceVariant)),
          ],
        ),
      )).toList(),
    );
  }
}

Widget _sectionHeader(BuildContext context, String title, IconData icon) {
  return Row(
    children: [
      Icon(icon),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          title,
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

List<String> _activityTags(String value) {
  return value
      .split(RegExp(r'[،,\n]+'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty && !item.trimLeft().startsWith('{'))
      .toList();
}
