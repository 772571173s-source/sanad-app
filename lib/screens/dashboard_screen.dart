import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../widgets/app_widgets.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
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
        ResponsiveGrid(children: _stats(app, improvement)),
        const SizedBox(height: 16),
        _ActivityCard(app: app),
      ],
    );
  }

  List<Widget> _stats(AppProvider app, int improvement) {
    if (app.isOwner) {
      final managers =
          app.staff.where((user) => user.role == UserRole.centerManager).length;
      final employees =
          app.staff.where((user) => user.role != UserRole.parent).length;
      return [
        StatTile(
            label: 'المراكز',
            value: '${app.centers.length}',
            icon: Icons.business_outlined),
        StatTile(
            label: 'المدراء',
            value: '$managers',
            icon: Icons.admin_panel_settings_outlined),
        StatTile(
            label: 'الموظفون', value: '$employees', icon: Icons.badge_outlined),
        StatTile(
            label: 'الطلاب',
            value: '${app.totalStudentsCount}',
            icon: Icons.groups_2_outlined),
        StatTile(
            label: 'الجلسات',
            value: '${app.totalSessionsCount}',
            icon: Icons.timer_outlined),
        StatTile(
            label: 'النشاط',
            value: '${app.auditLogs.length}',
            icon: Icons.history_outlined),
      ];
    }
    if (app.isCenterManager) {
      return [
        StatTile(
            label: 'الطلاب',
            value: '${app.students.length}',
            icon: Icons.groups_2_outlined),
        StatTile(
            label: 'الموظفون',
            value: '${app.staff.length}',
            icon: Icons.badge_outlined),
        StatTile(
            label: 'الجلسات',
            value: '${app.centerSessions.length}',
            icon: Icons.timer_outlined),
        StatTile(
            label: 'النشاط اليومي',
            value: '${app.auditLogs.length}',
            icon: Icons.today_outlined),
      ];
    }
    if (app.isSpecialist) {
      return [
        StatTile(
            label: 'الطلاب',
            value: '${app.students.length}',
            icon: Icons.groups_2_outlined),
        StatTile(
            label: 'جلسات اليوم',
            value: '${app.centerSessions.length}',
            icon: Icons.timer_outlined),
        StatTile(
            label: 'الواجبات',
            value: '${app.centerExercises.length}',
            icon: Icons.assignment_outlined),
        StatTile(
            label: 'نسبة التحسن',
            value: '$improvement%',
            icon: Icons.trending_up),
      ];
    }
    if (app.isDataEntry) {
      return [
        StatTile(
            label: 'الطلاب',
            value: '${app.students.length}',
            icon: Icons.groups_2_outlined),
        StatTile(
            label: 'أولياء الأمور',
            value: '${app.students.map((s) => s.parentPhone).toSet().length}',
            icon: Icons.family_restroom_outlined),
        StatTile(
            label: 'المركز',
            value: app.currentCenter?.name ?? '-',
            icon: Icons.business_outlined),
      ];
    }
    if (app.isProgramEntry) {
      return [
        StatTile(
            label: 'البرامج',
            value: '${app.programs.length}',
            icon: Icons.extension_outlined),
        StatTile(
            label: 'المهارات',
            value: '${app.programSkills.length}',
            icon: Icons.psychology_outlined),
        StatTile(
            label: 'الأنشطة',
            value: '${app.programActivities.length}',
            icon: Icons.local_activity_outlined),
      ];
    }
    return [
      StatTile(
          label: 'الأطفال',
          value: '${app.students.length}',
          icon: Icons.child_care_outlined),
      StatTile(
          label: 'الواجبات',
          value: '${app.exercises.length}',
          icon: Icons.assignment_outlined),
      StatTile(
          label: 'المكافآت',
          value: '${app.reward?.xp ?? 0} XP',
          icon: Icons.emoji_events_outlined),
    ];
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.app});

  final AppProvider app;

  @override
  Widget build(BuildContext context) {
    final student = app.selectedStudent;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('النشاط',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          if (app.isOwner)
            Text('آخر عمليات مسجلة: ${app.auditLogs.length}')
          else if (student == null)
            const Text('اختر طالبًا أو أضف بيانات للبدء.')
          else
            Row(
              children: [
                StudentAvatar(student: student, radius: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(student.name,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                      Text('${student.diagnosis} - ${student.status}'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
