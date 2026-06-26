import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../widgets/app_widgets.dart';

class CoordinatorDashboardScreen extends StatelessWidget {
  const CoordinatorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    // Correct distribution: a student is fully assigned when each of their
    // active therapy programs has an active primary assignment.
    final assignmentsByStudent = <String, Set<String>>{};
    for (final a in app.studentProgramAssignments) {
      if (!a.isActive || a.role != 'primary') continue;
      assignmentsByStudent.putIfAbsent(a.studentId, () => {});
      assignmentsByStudent[a.studentId]!.add(a.programId);
    }
    final programsByStudent = <String, Set<String>>{};
    for (final p in app.studentTherapyPrograms) {
      if (!p.isActive) continue;
      programsByStudent.putIfAbsent(p.studentId, () => {});
      programsByStudent[p.studentId]!.add(p.programId);
    }
    final totalStudents = app.students.length;
    int fullyAssigned = 0;
    int partiallyAssigned = 0;
    int notReady = 0;
    for (final student in app.students) {
      final studentPrograms = programsByStudent[student.id] ?? <String>{};
      if (studentPrograms.isEmpty) {
        notReady++;
        continue;
      }
      final assignedPrograms = assignmentsByStudent[student.id] ?? <String>{};
      if (assignedPrograms.containsAll(studentPrograms)) {
        fullyAssigned++;
      } else {
        partiallyAssigned++;
      }
    }
    final assigned = fullyAssigned;
    final unassigned = notReady + partiallyAssigned;
    final specialists =
        app.staff.where((u) => u.role == UserRole.specialist).length;

    return SingleChildScrollView(
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CoordinatorHero(
          totalStudents: totalStudents,
          specialists: specialists,
          unassigned: unassigned,
          assigned: assigned,
        ),
        const SizedBox(height: AppSpacing.md),
        ResponsiveGrid(children: [
          _StatCard(
            label: 'إجمالي الطلاب',
            value: '$totalStudents',
            icon: Icons.groups_2_outlined,
            progress: totalStudents == 0 ? 0 : 1,
            trend: 'المركز',
          ),
          _StatCard(
            label: 'الأخصائيون',
            value: '$specialists',
            icon: Icons.medical_services_outlined,
            progress: (specialists / 10).clamp(0, 1),
            trend: 'فريق العمل',
          ),
          _StatCard(
            label: 'بانتظار الربط',
            value: '$unassigned',
            icon: Icons.person_search_outlined,
            progress: totalStudents == 0
                ? 0
                : (unassigned / totalStudents).clamp(0, 1),
            trend: 'يحتاجون توزيع',
          ),
          _StatCard(
            label: 'مرتبط بأخصائي',
            value: '$assigned',
            icon: Icons.people_outline,
            progress: totalStudents == 0
                ? 0
                : (assigned / totalStudents).clamp(0, 1),
            trend: 'مكتمل',
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 980;
            final timeline = _RecentCoordinatorActivity(app: app);
            final alerts = _Alerts(
              app: app,
              unassigned: unassigned,
            );
            if (!wide) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  timeline,
                  const SizedBox(height: AppSpacing.md),
                  alerts,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: timeline),
                const SizedBox(width: AppSpacing.md),
                Expanded(flex: 2, child: alerts),
              ],
            );
          },
        ),
        if (totalStudents == 0)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.lg),
            child: EmptyState(
              icon: Icons.rocket_launch_outlined,
              title: 'ابدأ بإضافة الطلاب وتوزيعهم على الأخصائيين',
              message:
                  'عندما يتم تسجيل طلاب جدد من السكرتارية، ستظهر هنا إحصائياتهم ويمكنك توزيعهم على الأخصائيين.',
            ),
          ),
      ],
      ),
    );
  }
}

class _CoordinatorHero extends StatelessWidget {
  const _CoordinatorHero({
    required this.totalStudents,
    required this.specialists,
    required this.unassigned,
    required this.assigned,
  });

  final int totalStudents;
  final int specialists;
  final int unassigned;
  final int assigned;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: .16),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final summary = Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _Metric(label: 'الطلاب', value: '$totalStudents',
                  icon: Icons.groups_2_outlined),
              _Metric(label: 'الأخصائيون', value: '$specialists',
                  icon: Icons.medical_services_outlined),
              _Metric(label: 'غير مرتبط', value: '$unassigned',
                  icon: Icons.person_search_outlined),
              _Metric(label: 'مرتبط', value: '$assigned',
                  icon: Icons.people_outline),
            ],
          );
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'لوحة التنسيق',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '$totalStudents طالب، $specialists أخصائي، $unassigned طالب بانتظار الربط.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: .86),
                      height: 1.5,
                    ),
              ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [copy, const SizedBox(height: AppSpacing.md), summary],
            );
          }
          return Row(
            children: [
              Expanded(child: copy),
              const SizedBox(width: AppSpacing.lg),
              summary,
            ],
          );
        },
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: Colors.white.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  TextStyle(color: Colors.white.withValues(alpha: .82))),
        ],
      ),
    );
  }
}

class _StatCard extends StatefulWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.progress,
    required this.trend,
  });

  final String label;
  final String value;
  final IconData icon;
  final double progress;
  final String trend;

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tone = sanadAlertTone(context, SemanticAlertKind.success);
    return MouseRegion(
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 150),
        scale: hovered ? 1.01 : 1,
        child: AppCard(
          highlight: hovered,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tone.background,
                      borderRadius: BorderRadius.circular(AppRadii.control),
                      border: Border.all(color: tone.border),
                    ),
                    child: Icon(widget.icon, color: tone.icon),
                  ),
                  const Spacer(),
                  AppPill(label: widget.trend, icon: Icons.show_chart),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                widget.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: AppSpacing.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 7,
                  value: widget.progress.clamp(0, 1),
                  backgroundColor: colorScheme.surfaceContainerHighest,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentCoordinatorActivity extends StatelessWidget {
  const _RecentCoordinatorActivity({required this.app});

  final AppProvider app;

  @override
  Widget build(BuildContext context) {
    final items = _items(app);
    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.history_outlined,
        title: 'لا يوجد نشاط حديث',
        message: 'ستظهر هنا عمليات الربط وفك الارتباط وآخر نشاط.',
      );
    }
    return TherapyCard(
      icon: Icons.timeline_outlined,
      title: 'النشاط الأخير',
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            _TimelineRow(item: items[i], last: i == items.length - 1),
        ],
      ),
    );
  }

  List<_CoordActivity> _items(AppProvider app) {
    final logs = app.auditLogs
        .where((log) =>
            log.action.contains('ربط') ||
            log.action.contains('فك') ||
            log.action.contains('إسناد') ||
            log.action.contains('أخصائي'))
        .take(6)
        .map((log) => _CoordActivity(
              icon: Icons.swap_horiz_outlined,
              title: log.action,
              subtitle: log.details.isEmpty ? log.userName : log.details,
              time: _shortDate(log.createdAt),
            ))
        .toList();
    if (logs.isNotEmpty) return logs;

    final assignments = app.studentProgramAssignments
        .where((a) => a.isActive)
        .take(6);
    return assignments.map((a) {
      final student = app.students
          .where((s) => s.id == a.studentId)
          .firstOrNull;
      final specialist = app.staff
          .where((u) => u.id == a.specialistId)
          .firstOrNull;
      final program = app.therapyPrograms
          .where((p) => p.id == a.programId)
          .firstOrNull;
      return _CoordActivity(
        icon: Icons.link_outlined,
        title: 'إسناد برنامج',
        subtitle:
            '${student?.name ?? '-'} ← ${program?.name ?? a.programId} ← ${specialist?.name ?? '-'}',
        time: _shortDate(a.assignedAt),
      );
    }).toList();
  }

  String _shortDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value.isEmpty ? '-' : value;
    return '${date.year}/${date.month}/${date.day}';
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.item, required this.last});

  final _CoordActivity item;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tone = sanadAlertTone(context, SemanticAlertKind.info);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tone.background,
                borderRadius: BorderRadius.circular(AppRadii.control),
                border: Border.all(color: tone.border),
              ),
              child: Icon(item.icon, size: 20, color: tone.icon),
            ),
            if (!last)
              Container(
                width: 2,
                height: 34,
                color: colorScheme.outlineVariant,
              ),
          ],
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
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
                        style:
                            const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    Text(
                      item.time,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                              color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  item.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Alerts extends StatelessWidget {
  const _Alerts({
    required this.app,
    required this.unassigned,
  });

  final AppProvider app;
  final int unassigned;

  @override
  Widget build(BuildContext context) {
    final alerts = <_AlertItem>[];

    if (unassigned > 0) {
      alerts.add(_AlertItem(
        icon: Icons.person_search_outlined,
        title: 'طلاب جدد بدون ربط',
        message: '$unassigned طالب لم يتم ربطهم بأخصائي بعد.',
        kind: SemanticAlertKind.warning,
      ));
    }

    final studentIdsWithSession = app.centerSessions
        .map((s) => s.studentId)
        .toSet();
    final allAssignedStudentIds = app.studentProgramAssignments
        .where((a) => a.isActive)
        .map((a) => a.studentId)
        .toSet();
    final noSession = allAssignedStudentIds
        .where((id) => !studentIdsWithSession.contains(id))
        .length;
    if (noSession > 0) {
      alerts.add(_AlertItem(
        icon: Icons.timer_off_outlined,
        title: 'طلاب بدون جلسات',
        message: '$noSession طالب مرتبط لكن لم تبدأ جلساتهم.',
        kind: SemanticAlertKind.info,
      ));
    }

    final noAssessment = allAssignedStudentIds.where((id) {
      return !app.clinicalAssessments
          .any((a) => a.studentId == id);
    }).length;
    if (noAssessment > 0) {
      alerts.add(_AlertItem(
        icon: Icons.fact_check_outlined,
        title: 'لم يبدأ التقييم',
        message:
            '$noAssessment طالب مرتبط لكن لم يبدأ تقييمهم العلاجي.',
        kind: SemanticAlertKind.info,
      ));
    }

    if (alerts.isEmpty) {
      return const EmptyState(
        icon: Icons.verified_outlined,
        title: 'كل شيء مستقر',
        message: 'لا توجد تنبيهات مهمة الآن.',
      );
    }

    return TherapyCard(
      icon: Icons.notifications_active_outlined,
      title: 'تنبيهات',
      child: Column(
        children: [
          for (final alert in alerts) ...[
            SemanticAlertCard(
              kind: alert.kind,
              icon: alert.icon,
              title: alert.title,
              message: alert.message,
            ),
            if (alert != alerts.last)
              const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _CoordActivity {
  const _CoordActivity({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String time;
}

class _AlertItem {
  const _AlertItem({
    required this.icon,
    required this.title,
    required this.message,
    required this.kind,
  });

  final IconData icon;
  final String title;
  final String message;
  final SemanticAlertKind kind;
}
