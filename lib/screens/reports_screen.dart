import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../widgets/app_widgets.dart';
import '../widgets/feedback.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String type = 'تقرير شهري';
  String? sessionId;
  final fromDate = TextEditingController();
  final toDate = TextEditingController();
  final signature = TextEditingController(text: 'الأخصائي');
  final manager = TextEditingController(text: 'المدير');

  @override
  void dispose() {
    fromDate.dispose();
    toDate.dispose();
    signature.dispose();
    manager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final sessions = _sessionsForType(app.sessions);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('نظام التقارير',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          if (app.selectedStudent == null)
            const Text('اختر طالبًا أولًا.')
          else ...[
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: const InputDecoration(labelText: 'نوع التقرير'),
              items: const [
                'تقرير جلسة',
                'تقرير أسبوعي',
                'تقرير شهري',
                'تقرير ثلاثة أشهر',
                'تقرير سنة',
                'تقرير شامل',
                'تقرير مخصص',
              ]
                  .map((item) =>
                      DropdownMenuItem(value: item, child: Text(item)))
                  .toList(),
              onChanged: (value) => setState(() {
                type = value ?? type;
                sessionId = null;
              }),
            ),
            const SizedBox(height: 12),
            if (type == 'تقرير جلسة')
              DropdownButtonFormField<String>(
                initialValue: sessionId,
                decoration: const InputDecoration(labelText: 'اختر الجلسة'),
                items: app.sessions
                    .map((session) => DropdownMenuItem(
                          value: session.id,
                          child: Text(
                              '${session.startedAt.split('T').first} - ${session.cardTitle}'),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => sessionId = value),
              ),
            if (type == 'تقرير مخصص') ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: fromDate,
                      decoration: const InputDecoration(
                          labelText: 'تاريخ البداية', hintText: 'YYYY-MM-DD'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: toDate,
                      decoration: const InputDecoration(
                          labelText: 'تاريخ النهاية', hintText: 'YYYY-MM-DD'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextField(
                controller: signature,
                decoration: const InputDecoration(labelText: 'توقيع الأخصائي')),
            const SizedBox(height: 12),
            TextField(
                controller: manager,
                decoration: const InputDecoration(labelText: 'توقيع المدير')),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: sessions.isEmpty
                      ? null
                      : () => runWithFeedback(
                            context,
                            () => app.printReportForSessions(
                              type: type,
                              selectedSessions: sessions,
                              specialistSignature: signature.text.trim(),
                              managerSignature: manager.text.trim(),
                            ),
                            success: 'تم إنشاء التقرير.',
                            loading: 'جار إنشاء التقرير...',
                          ),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: Text('إصدار PDF (${sessions.length} جلسات)'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('الجلسات داخل التقرير',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            if (sessions.isEmpty)
              const Text('لا توجد جلسات مطابقة لهذا التقرير.')
            else
              ...sessions.take(8).map((session) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_note_outlined),
                    title: Text(session.cardTitle),
                    subtitle: Text(session.practiceItems,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: Text('${session.successRate}%'),
                  )),
            const Divider(height: 28),
            if (app.reports.isEmpty)
              const Text('لا توجد تقارير محفوظة بعد.')
            else
              ...app.reports.map((report) => ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(report.type),
                  subtitle: Text('نسبة التقدم ${report.improvementRate}%'),
                  trailing: Text(report.createdAt.split('T').first))),
          ],
        ],
      ),
    );
  }

  List<TherapySession> _sessionsForType(List<TherapySession> sessions) {
    final sorted = [...sessions]
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    if (type == 'تقرير جلسة') {
      return sorted.where((session) => session.id == sessionId).toList();
    }
    if (type == 'تقرير شامل') return sorted;
    final now = DateTime.now();
    final from = switch (type) {
      'تقرير أسبوعي' => now.subtract(const Duration(days: 7)),
      'تقرير شهري' => DateTime(now.year, now.month, 1),
      'تقرير ثلاثة أشهر' => DateTime(now.year, now.month - 2, 1),
      'تقرير سنة' => DateTime(now.year, 1, 1),
      'تقرير مخصص' => DateTime.tryParse(fromDate.text.trim()) ?? DateTime(1900),
      _ => DateTime(1900),
    };
    final to = type == 'تقرير مخصص'
        ? DateTime.tryParse(toDate.text.trim()) ??
            DateTime.now().add(const Duration(days: 1))
        : DateTime.now().add(const Duration(days: 1));
    return sorted.where((session) {
      final date = DateTime.tryParse(session.startedAt);
      if (date == null) return false;
      return !date.isBefore(from) && !date.isAfter(to);
    }).toList();
  }
}
