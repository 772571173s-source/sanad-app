import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../widgets/app_widgets.dart';
import '../widgets/feedback.dart';

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
        : 'آخر تقييم: ${assessments.first.createdAt.split('T').first}';

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
        _StudentOverview(app: app, student: student),
        const SizedBox(height: 16),
        _ProfileSummary(app: app),
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
          title: 'متابعة الأهداف العلاجية',
          summary: goalSummary,
          count: plans.length,
          child: _GoalProgressSection(app: app, onOpenSession: onOpenSession),
        ),
        const SizedBox(height: 12),
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

class _StudentOverview extends StatelessWidget {
  const _StudentOverview({required this.app, required this.student});

  final AppProvider app;
  final Student student;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final programs = app.programsForStudent();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(Icons.child_care, size: 32, color: colorScheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
          Text(student.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(app.currentCenter?.name ?? 'المركز غير محدد',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text(student.status, style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
          if (programs.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: programs.map((p) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(AppRadii.control),
                ),
                child: Text(
                  p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
              )).toList(),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _CompactInfoTile(
                  icon: Icons.cake_outlined,
                  label: 'العمر',
                  value: '${student.age}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CompactInfoTile(
                  icon: Icons.medical_information_outlined,
                  label: 'التشخيص',
                  value: student.diagnosis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _CompactInfoTile(
                  icon: Icons.person_outlined,
                  label: 'ولي الأمر',
                  value: student.parentName,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CompactInfoTile(
                  icon: Icons.phone_outlined,
                  label: 'رقم ولي الأمر',
                  value: student.parentPhone,
                  ltr: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _CompactInfoTile(
            icon: Icons.person_outline,
            label: 'اسم المستخدم',
            value: student.portalEmail,
            ltr: true,
          ),
          if (student.notes.isNotEmpty) ...[
            const Divider(height: 24),
            Text('ملاحظات الملف',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(student.notes, maxLines: 3, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class _CompactInfoTile extends StatelessWidget {
  const _CompactInfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.ltr = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool ltr;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface,
                  )),
              Directionality(
                textDirection: ltr ? TextDirection.ltr : TextDirection.rtl,
                child: Text(
                  value.isEmpty ? '-' : value,
                  maxLines: 1,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  textAlign: ltr ? TextAlign.left : TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
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
                              'تقييم نطقي - ${assessment.createdAt.split('T').first}',
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
        ],
      ),
    );
  }
}

class _GoalProgressSection extends StatelessWidget {
  const _GoalProgressSection(
      {required this.app, this.onOpenSession});

  final AppProvider app;
  final VoidCallback? onOpenSession;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            context,
            'متابعة الأهداف العلاجية',
            Icons.track_changes_outlined,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (app.plans.isEmpty)
            const EmptyState(
              icon: Icons.track_changes_outlined,
              title: 'لا توجد أهداف علاجية بعد',
              message:
                  'ابدأ بتقييم علاجي؛ سيحوّل سند نقاط الضعف إلى أهداف ومهارات قابلة للتتبع.',
            )
          else
            ...app.plans.map((plan) {
              final steps = app.stepsForGoal(plan.id);
              final completed =
                  steps.where((step) => step.status == 'متقن').length;
              final remaining = steps.length - completed;
              final progress = app.goalProgress(plan.id);
              final status = app.goalStatus(plan.id);
              final lastSession = _lastSessionDate(app, steps);
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 380;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (narrow)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(plan.goal,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: SanadText.subtitle(context)),
                              const SizedBox(height: 6),
                              AppPill(
                                label: status,
                                icon: status == 'مكتمل'
                                    ? Icons.verified_outlined
                                    : Icons.trending_up_outlined,
                                selected: status == 'مكتمل',
                              ),
                            ],
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: Text(plan.goal,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: SanadText.subtitle(context)),
                              ),
                              AppPill(
                                label: status,
                                icon: status == 'مكتمل'
                                    ? Icons.verified_outlined
                                    : Icons.trending_up_outlined,
                                selected: status == 'مكتمل',
                              ),
                            ],
                          ),
                        const SizedBox(height: AppSpacing.sm),
                        LinearProgressIndicator(value: progress / 100),
                        const SizedBox(height: AppSpacing.sm),
                        if (narrow)
                          Column(
                            children: [
                              _progressRow(
                                  Icons.trending_up_outlined, 'التقدم: $progress%', context),
                              const SizedBox(height: 6),
                              _progressRow(
                                  Icons.check_circle_outline, 'متقن: $completed', context),
                              const SizedBox(height: 6),
                              _progressRow(
                                  Icons.pending_outlined, 'متبقي: $remaining', context),
                              const SizedBox(height: 6),
                              _progressRow(
                                  Icons.history_outlined, 'آخر جلسة: $lastSession', context),
                            ],
                          )
                        else
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              AppPill(label: 'التقدم: $progress%'),
                              AppPill(label: 'متقن: $completed'),
                              AppPill(label: 'متبقي: $remaining'),
                              AppPill(label: 'آخر جلسة: $lastSession'),
                            ],
                          ),
                        if (steps.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: steps.map((step) {
                              final needsRetrain = step.status == 'بمساعدة' ||
                                  step.status == 'يحتاج إعادة';
                              final chip = Chip(
                                avatar: Icon(
                                  step.status == 'متقن'
                                      ? Icons.check_circle_outline
                                      : Icons.radio_button_unchecked,
                                  size: 18,
                                ),
                                label: Text('${step.title} - ${step.status}', maxLines: 1, overflow: TextOverflow.ellipsis),
                                deleteIcon: needsRetrain
                                    ? const Icon(Icons.refresh_outlined, size: 18)
                                    : null,
                                onDeleted: needsRetrain
                                    ? () => _openRetrain(context, plan, step)
                                    : null,
                              );
                              if (narrow) {
                                return ConstrainedBox(
                                  constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                                  child: chip,
                                );
                              }
                              return chip;
                            }).toList(),
                          ),
                        ],
                        if (steps.isEmpty && plan.treatment.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(plan.treatment,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: SanadText.secondary(context)),
                          if (plan.progress < 100)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: FilledButton.tonalIcon(
                                onPressed: () =>
                                    _openRetrainPlan(context, plan),
                                icon: const Icon(Icons.refresh_outlined),
                                label: const Text('إعادة التدريب'),
                              ),
                            ),
                        ],
                      ],
                    );
                  },
                ),
              );
            }),
        ],
      ),
    );
  }

  String _lastSessionDate(AppProvider app, List<GoalSkillStep> steps) {
    final sessionIds = steps
        .map((step) => step.lastSessionId)
        .where((value) => value.trim().isNotEmpty)
        .toSet();
    final matches = app.sessions
        .where((session) => sessionIds.contains(session.id))
        .toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    if (matches.isEmpty) return 'لا توجد';
    return matches.first.startedAt.split('T').first;
  }

  Widget _progressRow(IconData icon, String label, BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openRetrain(BuildContext context, TrainingPlan plan,
      GoalSkillStep step) {
    final app = context.read<AppProvider>();
    app.preselectSession({
      'programId': plan.programId,
      'sourceType': plan.sourceType,
      'planId': plan.id,
      'stepId': step.id,
    });
    onOpenSession?.call();
  }

  void _openRetrainPlan(BuildContext context, TrainingPlan plan) {
    final app = context.read<AppProvider>();
    app.preselectSession({
      'programId': plan.programId,
      'sourceType': plan.sourceType,
      'planId': plan.id,
    });
    onOpenSession?.call();
  }
}

class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({required this.app});

  final AppProvider app;

  @override
  Widget build(BuildContext context) {
    final sessions = app.sessions;
    final average = sessions.isEmpty
        ? 0
        : (sessions.fold<int>(0, (sum, item) => sum + item.successRate) /
                sessions.length)
            .round();
    final lastSession = sessions.isEmpty
        ? 'لا توجد'
        : sessions.first.startedAt.split('T').first;
    final completedHomework =
        app.exercises.where((item) => item.status == 'تم الإنجاز').length;
    return ResponsiveGrid(
      children: [
        StatTile(
          label: 'عدد الجلسات',
          value: '${sessions.length}',
          icon: Icons.event_note_outlined,
        ),
        StatTile(
          label: 'متوسط التحسن',
          value: '$average%',
          icon: Icons.trending_up_outlined,
        ),
        StatTile(
          label: 'آخر جلسة',
          value: lastSession,
          icon: Icons.history_outlined,
        ),
        StatTile(
          label: 'واجبات مكتملة',
          value: '$completedHomework',
          icon: Icons.assignment_turned_in_outlined,
        ),
      ],
    );
  }
}

class _PreviousSessions extends StatelessWidget {
  const _PreviousSessions({required this.app});

  final AppProvider app;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, 'الجلسات السابقة', Icons.timeline_outlined),
          const SizedBox(height: 10),
          if (app.sessions.isEmpty)
            const Text('لا توجد جلسات بعد.')
          else
            ...app.sessions.map((session) => _SessionTile(session: session)),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});

  final TherapySession session;

  @override
  Widget build(BuildContext context) {
    final activities = _activityTags(session.practiceItems);
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
