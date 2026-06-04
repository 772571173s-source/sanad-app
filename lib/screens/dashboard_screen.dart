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
    final evaluations =
        app.centerEvaluations.isEmpty ? app.evaluations : app.centerEvaluations;
    final success = evaluations
        .where((item) => item.score == 'ناجح' || item.score == 'صحيح')
        .length;
    final partial = evaluations.where((item) => item.score == 'جزئي').length;
    final improvement = evaluations.isEmpty
        ? 0
        : (((success + partial * .5) / evaluations.length) * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResponsiveGrid(
          children: [
            if (app.isOwner)
              StatTile(
                  label: 'المراكز',
                  value: '${app.centers.length}',
                  icon: Icons.business_outlined),
            StatTile(
                label: 'الطلاب',
                value: '${app.students.length}',
                icon: Icons.groups_2_outlined),
            if (app.canManageStaff)
              StatTile(
                  label: 'الحسابات',
                  value: '${app.staff.length}',
                  icon: Icons.manage_accounts_outlined),
            StatTile(
                label: 'الجلسات',
                value: '${app.centerSessions.length}',
                icon: Icons.timer_outlined),
            StatTile(
                label: 'التقييمات',
                value: '${evaluations.length}',
                icon: Icons.fact_check_outlined),
            StatTile(
                label: 'نسبة التحسن',
                value: '$improvement%',
                icon: Icons.trending_up),
            StatTile(
                label: 'الحرف الأصعب',
                value: app.hardestLetter,
                icon: Icons.psychology_outlined),
            StatTile(
                label: 'أكثر إشارة',
                value: app.mostUsedSign,
                icon: Icons.sign_language_outlined),
            StatTile(
                label: 'واجبات مكتملة',
                value: '${app.completedHomeworkCount}',
                icon: Icons.assignment_turned_in_outlined),
          ],
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الطالب الحالي',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
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
                          Text(selectedStudent.name,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w800)),
                          Text(
                              '${selectedStudent.diagnosis} - ${selectedStudent.status}'),
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
