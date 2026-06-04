import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../widgets/app_widgets.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final selectedStudent = app.selectedStudent;
    final success = app.evaluations.where((item) => item.score == 'ناجح').length;
    final partial = app.evaluations.where((item) => item.score == 'جزئي').length;
    final improvement = app.evaluations.isEmpty ? 0 : (((success + partial * .5) / app.evaluations.length) * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResponsiveGrid(
          children: [
            if (app.isOwner) StatTile(label: 'المراكز', value: '${app.centers.length}', icon: Icons.business_outlined),
            StatTile(label: 'الطلاب', value: '${app.students.length}', icon: Icons.groups_2_outlined),
            if (app.canManageStaff) StatTile(label: 'الحسابات', value: '${app.staff.length}', icon: Icons.manage_accounts_outlined),
            StatTile(label: 'الجلسات', value: '${app.sessions.length}', icon: Icons.timer_outlined),
            StatTile(label: 'التقييمات', value: '${app.evaluations.length}', icon: Icons.fact_check_outlined),
            StatTile(label: 'نسبة التحسن', value: '$improvement%', icon: Icons.trending_up),
          ],
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الطالب الحالي', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              if (selectedStudent == null)
                const Text('ابدأ بإضافة طالب ثم اختره من شاشة الطلاب.')
              else
                Row(
                  children: [
                    StudentAvatar(student: selectedStudent, radius: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(selectedStudent.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          Text('${selectedStudent.diagnosis} - ${selectedStudent.status}'),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
