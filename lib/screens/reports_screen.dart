import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../widgets/app_widgets.dart';

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
          Text('التقارير الاحترافية', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          if (app.selectedStudent == null)
            const Text('اختر طالبًا أولًا.')
          else ...[
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: const InputDecoration(labelText: 'نوع التقرير'),
              items: const ['تقرير جلسة', 'تقرير شهري', 'تقرير ربع سنوي', 'تقرير ختامي'].map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
              onChanged: (value) => setState(() => type = value ?? type),
            ),
            const SizedBox(height: 12),
            TextField(controller: signature, decoration: const InputDecoration(labelText: 'توقيع الأخصائي')),
            const SizedBox(height: 12),
            TextField(controller: manager, decoration: const InputDecoration(labelText: 'توقيع المدير')),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(onPressed: () => app.printReport(type, signature.text.trim(), manager.text.trim()), icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text('إصدار PDF')),
                FilledButton.tonalIcon(onPressed: () => app.printCredentials(app.selectedStudent!), icon: const Icon(Icons.badge_outlined), label: const Text('ورقة البريد وكلمة السر')),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
