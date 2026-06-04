import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../widgets/app_widgets.dart';

class StudentProfileScreen extends StatelessWidget {
  const StudentProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final student = app.selectedStudent;
    if (student == null) return const AppCard(child: Text('اختر طالبًا أولًا.'));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [StudentAvatar(student: student, radius: 38), const SizedBox(width: 12), Expanded(child: Text(student.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)))]),
          const SizedBox(height: 16),
          Wrap(spacing: 16, runSpacing: 12, children: [
            _field('العمر', '${student.age}'),
            _field('الحالة', student.status),
            _field('نوع البرنامج', student.programType),
            _field('التشخيص', student.diagnosis),
            _field('ولي الأمر', student.parentName),
            _field('هاتف ولي الأمر', student.parentPhone),
            _field('بريد ولي الأمر', student.portalEmail),
          ]),
          const Divider(height: 28),
          Text('ملاحظات الملف الورقي', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          Text(student.notes.isEmpty ? 'لا توجد ملاحظات.' : student.notes),
        ]),
      ),
      const SizedBox(height: 16),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('سجل الزيارات والجلسات', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          if (app.sessions.isEmpty) const Text('لا توجد جلسات بعد.'),
          ...app.sessions.map((session) => ListTile(leading: const Icon(Icons.event_note_outlined), title: Text(session.cardTitle), subtitle: Text('${session.startedAt}\n${session.quickResult} - ${session.summary.isEmpty ? session.notes : session.summary}'))),
        ]),
      ),
      const SizedBox(height: 16),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('الخط الزمني للطالب', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          if (_timeline(app).isEmpty) const Text('سيظهر هنا سجل زمني للجلسات والتقييمات والواجبات والتقارير والمكافآت.') else ..._timeline(app).map((item) => ListTile(leading: Icon(item.icon), title: Text(item.title), subtitle: Text(item.subtitle), trailing: Text(item.date.split('T').first))),
        ]),
      ),
      const SizedBox(height: 16),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('سجل العمليات', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          if (app.auditLogs.isEmpty) const Text('لا توجد عمليات مسجلة لهذا الطالب.'),
          ...app.auditLogs.take(10).map((log) => ListTile(leading: const Icon(Icons.manage_history), title: Text(log.action), subtitle: Text('${log.userName} - ${log.details}'), trailing: Text(log.createdAt.split('T').first))),
        ]),
      ),
    ]);
  }

  Widget _field(String label, String value) => SizedBox(width: 240, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontWeight: FontWeight.w700)), Text(value.isEmpty ? '-' : value)]));

  List<_TimelineItem> _timeline(AppProvider app) {
    final items = <_TimelineItem>[
      ...app.sessions.map((session) => _TimelineItem(Icons.record_voice_over_outlined, 'جلسة ${session.sessionType}', '${session.cardTitle} - نجاح ${session.successRate}%', session.startedAt)),
      ...app.evaluations.map((evaluation) => _TimelineItem(Icons.fact_check_outlined, 'تقييم حرف ${evaluation.letter}', '${evaluation.position} - ${evaluation.errorType} - شدة ${evaluation.severity}', evaluation.createdAt)),
      ...app.exercises.map((exercise) => _TimelineItem(Icons.assignment_outlined, 'واجب منزلي', '${exercise.title} - ${exercise.status}', exercise.dueDate)),
      ...app.reports.map((report) => _TimelineItem(Icons.picture_as_pdf_outlined, 'تقرير ${report.type}', 'نسبة التحسن ${report.improvementRate}%', report.createdAt)),
    ];
    final reward = app.reward;
    if (reward != null) items.add(_TimelineItem(Icons.workspace_premium_outlined, 'مكافآت ونقاط', 'XP ${reward.xp} - المستوى ${reward.level}', DateTime.now().toIso8601String()));
    items.sort((a, b) => b.date.compareTo(a.date));
    return items;
  }
}

class _TimelineItem {
  const _TimelineItem(this.icon, this.title, this.subtitle, this.date);

  final IconData icon;
  final String title;
  final String subtitle;
  final String date;
}
