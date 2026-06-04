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
    ]);
  }

  Widget _field(String label, String value) => SizedBox(width: 240, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontWeight: FontWeight.w700)), Text(value.isEmpty ? '-' : value)]));
}
