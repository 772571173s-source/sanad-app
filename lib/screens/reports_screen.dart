import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  final signature = TextEditingController(text: 'الأخصائي');
  final manager = TextEditingController(text: 'المدير');

  @override
  void dispose() {
    signature.dispose();
    manager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('التقارير الاحترافية',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
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
                'تقرير ختامي',
              ]
                  .map((item) =>
                      DropdownMenuItem(value: item, child: Text(item)))
                  .toList(),
              onChanged: (value) => setState(() => type = value ?? type),
            ),
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
                    onPressed: () => runWithFeedback(
                        context,
                        () => app.printReport(
                            type, signature.text.trim(), manager.text.trim()),
                        success: 'تم إنشاء التقرير.',
                        loading: 'جار إنشاء التقرير...'),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('إصدار PDF')),
                FilledButton.tonalIcon(
                    onPressed: () => setState(() => type = 'تقرير شامل'),
                    icon: const Icon(Icons.date_range_outlined),
                    label: const Text('شامل حسب الفترة لاحقًا')),
              ],
            ),
            const SizedBox(height: 16),
            if (app.reports.isEmpty)
              const Text(
                  'لا توجد تقارير بعد. بعد إصدار أول تقرير سيتم حفظه داخل سجل الطالب.')
            else
              ...app.reports.map((report) => ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(report.type),
                  subtitle: Text('نسبة التحسن ${report.improvementRate}%'),
                  trailing: Text(report.createdAt.split('T').first))),
          ],
        ],
      ),
    );
  }
}
