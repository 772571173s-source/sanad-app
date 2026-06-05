import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../widgets/app_widgets.dart';
import '../widgets/feedback.dart';

class StudentProfileScreen extends StatelessWidget {
  const StudentProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final student = app.selectedStudent;
    if (student == null) {
      return const EmptyState(
        icon: Icons.folder_shared_outlined,
        title: 'اختر طالبًا أولًا',
        message: 'سيظهر ملف الطالب العلاجي بعد اختياره من شاشة الطلاب.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StudentOverview(app: app, student: student),
        const SizedBox(height: 16),
        _QuickActions(app: app, student: student),
        const SizedBox(height: 16),
        _PreviousSessions(app: app),
        const SizedBox(height: 16),
        _ReportsFromProfile(app: app),
        const SizedBox(height: 16),
        _HomeworkSummary(app: app),
        const SizedBox(height: 16),
        _Timeline(app: app),
      ],
    );
  }
}

class _StudentOverview extends StatelessWidget {
  const _StudentOverview({required this.app, required this.student});

  final AppProvider app;
  final Student student;

  @override
  Widget build(BuildContext context) {
    return AppCard(
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
                    Text(student.name,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(app.currentCenter?.name ?? 'المركز غير محدد'),
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
              _InfoTile('ولي الأمر', student.parentName),
              _InfoTile('رقم ولي الأمر', student.parentPhone),
              _InfoTile('نوع البرنامج', student.programType),
              _InfoTile('البريد', student.portalEmail, ltr: true),
            ],
          ),
          if (student.notes.isNotEmpty) ...[
            const Divider(height: 28),
            Text('ملاحظات الملف',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(student.notes),
          ],
        ],
      ),
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
          Text('الإجراءات السريعة',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _action(context, Icons.play_circle_outline, 'بدء جلسة جديدة',
                  'افتح شاشة الجلسات واختر أنشطة الطالب.'),
              _action(context, Icons.history, 'عرض الجلسات السابقة',
                  'الجلسات السابقة ظاهرة أسفل الملف.'),
              _reportButton(context, 'تقرير جلسة'),
              _reportButton(context, 'تقرير أسبوعي'),
              _reportButton(context, 'تقرير شهري'),
              _reportButton(context, 'تقرير ثلاثة أشهر'),
              _reportButton(context, 'تقرير سنة'),
              _reportButton(context, 'تقرير شامل'),
              _action(context, Icons.edit_outlined, 'تعديل بيانات الطالب',
                  'التعديل يتم من شاشة الطلاب أو الإدخال.'),
              _action(context, Icons.phone_in_talk_outlined,
                  'التواصل مع ولي الأمر', student.parentPhone),
            ],
          ),
        ],
      ),
    );
  }

  Widget _reportButton(BuildContext context, String type) {
    return FilledButton.tonalIcon(
      onPressed: app.canViewReports
          ? () => type == 'تقرير جلسة'
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
      label: Text(type),
    );
  }

  Future<void> _chooseSessionReport(BuildContext context) async {
    if (app.sessions.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('لا توجد جلسات للطالب.')));
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('اختر جلسة للتقرير'),
        content: SizedBox(
          width: 560,
          child: ListView(
            shrinkWrap: true,
            children: app.sessions.map((session) {
              return ListTile(
                title: Text(session.cardTitle),
                subtitle: Text(
                    '${session.startedAt.split('T').first} - نجاح ${session.successRate}%'),
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
      'تقرير أسبوعي' => now.subtract(const Duration(days: 7)),
      'تقرير شهري' => DateTime(now.year, now.month, 1),
      'تقرير سنوي' => DateTime(now.year, 1, 1),
      _ => DateTime(1900),
    };
    return app.sessions.where((session) {
      final date = DateTime.tryParse(session.startedAt);
      return date != null && !date.isBefore(from);
    }).toList();
  }

  Widget _action(
      BuildContext context, IconData icon, String label, String message) {
    return FilledButton.tonalIcon(
      onPressed: () => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message))),
      icon: Icon(icon),
      label: Text(label),
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
          Text('الجلسات السابقة',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900)),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
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
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900)),
              ),
              Chip(label: Text('${session.successRate}%')),
            ],
          ),
          const SizedBox(height: 6),
          Text('التاريخ: ${session.startedAt.split('T').first}'),
          Text('البرنامج: ${session.sessionType}'),
          Text('الأنشطة: ${session.practiceItems}'),
          Text('التقييم السريع: ${session.quickResult}'),
          if (session.summary.isNotEmpty) Text('الملخص: ${session.summary}'),
          if (session.notes.isNotEmpty)
            Text('ملاحظة الأخصائي: ${session.notes}'),
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
          Text('التقارير',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          if (app.reports.isEmpty)
            const Text('لا توجد تقارير محفوظة بعد.')
          else
            ...app.reports.map((report) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.picture_as_pdf_outlined),
                  title: Text(report.type),
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
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الواجبات وملاحظات ولي الأمر',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          if (app.exercises.isEmpty)
            const Text('لا توجد واجبات بعد.')
          else
            ...app.exercises.take(8).map((exercise) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.assignment_outlined),
                  title: Text(exercise.title),
                  subtitle: Text(
                      '${exercise.status}${exercise.parentNote.isEmpty ? '' : '\nملاحظة: ${exercise.parentNote}'}'),
                  trailing: Text('⭐ ${exercise.stars}'),
                )),
        ],
      ),
    );
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
          Text('الخط الزمني',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          if (items.isEmpty)
            const Text('سيظهر هنا سجل الجلسات والتقييمات والواجبات والتقارير.')
          else
            ...items.map((item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(item.icon),
                  title: Text(item.title),
                  subtitle: Text(item.subtitle),
                  trailing: Text(item.date.split('T').first),
                )),
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

class _InfoTile extends StatelessWidget {
  const _InfoTile(this.label, this.value, {this.ltr = false});

  final String label;
  final String value;
  final bool ltr;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          Directionality(
            textDirection: ltr ? TextDirection.ltr : TextDirection.rtl,
            child: Text(
              value.isEmpty ? '-' : value,
              textAlign: ltr ? TextAlign.left : TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
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
