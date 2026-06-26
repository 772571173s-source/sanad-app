import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../widgets/app_widgets.dart';

class SpecialistDashboardScreen extends StatefulWidget {
  const SpecialistDashboardScreen({super.key});

  @override
  State<SpecialistDashboardScreen> createState() =>
      _SpecialistDashboardScreenState();
}

class _SpecialistDashboardScreenState extends State<SpecialistDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = context.read<AppProvider>();
      app.loadCenterPlansAndSteps();
      app.loadCenterAssessments();
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final improvement = _improvement(app);
    final todaySessions = _todaySessions(app);
    final activeGoals = _activeGoals(app);
    final masteredGoals = _masteredGoals(app);
    final alerts = _alerts(app, todaySessions);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DashboardHero(
            app: app,
            improvement: improvement,
            todaySessions: todaySessions.length,
            alerts: alerts.length,
            studentCount: app.students.length,
          ),
          const SizedBox(height: AppSpacing.md),
          ResponsiveGrid(children: [
            _SpecialistStatCard(
              label: 'الطلاب',
              value: '${app.students.length}',
              icon: Icons.groups_2_outlined,
              progress: (app.students.length / 20).clamp(0, 1),
              trend: 'ملفات متاحة',
            ),
            _SpecialistStatCard(
              label: 'جلسات اليوم',
              value: '${todaySessions.length}',
              icon: Icons.timer_outlined,
              progress: (todaySessions.length / 8).clamp(0, 1),
              trend: 'جدول اليوم',
            ),
            _SpecialistStatCard(
              label: 'الأهداف النشطة',
              value: '$activeGoals',
              icon: Icons.track_changes_outlined,
              progress: _safeDiv(activeGoals, activeGoals + masteredGoals),
              trend: 'قيد التدريب',
            ),
            _SpecialistStatCard(
              label: 'الأهداف المتقنة',
              value: '$masteredGoals',
              icon: Icons.emoji_events_outlined,
              progress: masteredGoals == 0
                  ? 0
                  : _safeDiv(masteredGoals, activeGoals + masteredGoals),
              trend: 'مكتملة',
            ),
          ]),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 980;
              final timeline = _RecentActivity(app: app);
              final attention = _AttentionCard(alerts: alerts);
              if (!wide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    timeline,
                    const SizedBox(height: AppSpacing.md),
                    attention,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: timeline),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(flex: 2, child: attention),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  double _safeDiv(int a, int b) => b == 0 ? 0 : a / b;

  int _improvement(AppProvider app) {
    return app.centerGoalImprovementRate;
  }

  List<TherapySession> _todaySessions(AppProvider app) {
    return app.specialistSessions
        .where((session) => _isToday(session.startedAt))
        .toList();
  }

  bool _isToday(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return false;
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  int _activeGoals(AppProvider app) {
    if (app.centerPlans.isEmpty) return 0;
    return app.centerPlans.where((p) => app.goalProgress(p.id) < 100).length;
  }

  int _masteredGoals(AppProvider app) {
    if (app.centerPlans.isEmpty) return 0;
    return app.centerPlans.where((p) => app.goalProgress(p.id) >= 100).length;
  }

  List<_AlertItem> _alerts(
      AppProvider app, List<TherapySession> todaySessions) {
    final items = <_AlertItem>[];

    final needsAssessment = app.studentsNeedingAssessment;
    if (needsAssessment.isNotEmpty) {
      items.add(_AlertItem(
        icon: Icons.fact_check_outlined,
        title: 'طلاب يحتاجون تقييم',
        message:
            '${needsAssessment.length} طالب لم يعمل لهم تقييم علاجي بعد. ${needsAssessment.take(3).map((s) => s.name).join('، ')}${needsAssessment.length > 3 ? '...' : ''}',
        kind: SemanticAlertKind.warning,
      ));
    }

    final studentIdsWithSession = app.specialistSessions
        .map((s) => s.studentId)
        .toSet();

    final needsSession = app.students
        .where((s) => !studentIdsWithSession.contains(s.id))
        .length;
    if (needsSession > 0) {
      items.add(_AlertItem(
        icon: Icons.person_off_outlined,
        title: 'طلاب يحتاجون جلسة',
        message: '$needsSession طالب لم تسجل لهم أي جلسة بعد.',
        kind: SemanticAlertKind.info,
      ));
    }

    final sevenDaysAgo = DateTime.now()
        .subtract(const Duration(days: 7))
        .toIso8601String();
    final stale = <String>[];
    for (final student in app.students) {
      final studentSessions = app.specialistSessions
          .where((s) => s.studentId == student.id)
          .toList();
      if (studentSessions.isNotEmpty) {
        final last = studentSessions
            .map((s) => s.startedAt)
            .reduce((a, b) => a.compareTo(b) > 0 ? a : b);
        if (last.compareTo(sevenDaysAgo) < 0) {
          stale.add(student.name);
        }
      }
    }
    if (stale.isNotEmpty) {
      items.add(_AlertItem(
        icon: Icons.schedule_outlined,
        title: 'طلاب بدون جلسة منذ فترة',
        message:
            '${stale.length} طالب لم تعمل لهم جلسة منذ 7 أيام (${stale.take(3).join('، ')}${stale.length > 3 ? '...' : ''}).',
        kind: SemanticAlertKind.warning,
      ));
    }

    final pendingReview = app.centerExercises
        .where((e) => e.status == 'completed_by_parent')
        .length;
    if (pendingReview > 0) {
      items.add(_AlertItem(
        icon: Icons.assignment_turned_in_outlined,
        title: 'واجب مكتمل من ولي الأمر',
        message: '$pendingReview واجب يحتاج مراجعتك.',
        kind: SemanticAlertKind.success,
      ));
    }

    final needsRetrain = app.centerGoalSteps
        .where((step) => step.status == 'يحتاج إعادة')
        .length;
    if (needsRetrain > 0) {
      items.add(_AlertItem(
        icon: Icons.refresh_outlined,
        title: 'مهارات تحتاج إعادة تدريب',
        message: '$needsRetrain مهارة تحتاج إعادة تدريب.',
        kind: SemanticAlertKind.error,
      ));
    }

    if (todaySessions.length >= 4) {
      items.add(_AlertItem(
        icon: Icons.event_available_outlined,
        title: 'يوم علاجي نشط',
        message: '${todaySessions.length} جلسات مسجلة اليوم.',
        kind: SemanticAlertKind.success,
      ));
    }

    return items;
  }
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({
    required this.app,
    required this.improvement,
    required this.todaySessions,
    required this.alerts,
    required this.studentCount,
  });

  final AppProvider app;
  final int improvement;
  final int todaySessions;
  final int alerts;
  final int studentCount;

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
              _HeroMetric(
                label: 'عدد الطلاب',
                value: '$studentCount',
                icon: Icons.groups_2_outlined,
              ),
              _HeroMetric(
                label: 'جلسات اليوم',
                value: '$todaySessions',
                icon: Icons.timer_outlined,
              ),
              _HeroMetric(
                label: 'متوسط تقدم أهداف طلابي',
                value: '$improvement%',
                icon: Icons.trending_up,
              ),
              _HeroMetric(
                label: 'تنبيهات',
                value: '$alerts',
                icon: Icons.notifications_active_outlined,
              ),
            ],
          );
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'مسار جلساتك العلاجية',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'لديك $todaySessions جلسات مسجلة اليوم و$alerts تنبيهات تحتاج انتباه.',
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
              children: [
                copy,
                const SizedBox(height: AppSpacing.md),
                summary,
              ],
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

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
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

class _SpecialistStatCard extends StatefulWidget {
  const _SpecialistStatCard({
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
  State<_SpecialistStatCard> createState() => _SpecialistStatCardState();
}

class _SpecialistStatCardState extends State<_SpecialistStatCard> {
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

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.app});

  final AppProvider app;

  @override
  Widget build(BuildContext context) {
    final items = _activityItems(app);
    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.history_outlined,
        title: 'لا يوجد نشاط حديث',
        message:
            'ستظهر هنا آخر جلسة وآخر تقييم وآخر واجب مكتمل من ولي الأمر.',
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

  List<_ActivityItem> _activityItems(AppProvider app) {
    final items = <_ActivityItem>[];

    final lastSession = app.specialistSessions.isNotEmpty
        ? app.specialistSessions
            .reduce((a, b) =>
                a.startedAt.compareTo(b.startedAt) > 0 ? a : b)
        : null;
    if (lastSession != null) {
      final student = app.students
          .where((s) => s.id == lastSession.studentId)
          .firstOrNull;
      items.add(_ActivityItem(
        icon: Icons.timer_outlined,
        title: 'آخر جلسة',
        subtitle: student?.name ?? lastSession.studentId,
        time: _formatDate(lastSession.startedAt),
      ));
    }

    final lastAssessment = app.clinicalAssessments.isNotEmpty
        ? app.clinicalAssessments
            .reduce((a, b) =>
                a.createdAt.compareTo(b.createdAt) > 0 ? a : b)
        : null;
    if (lastAssessment != null) {
      final student = app.students
          .where((s) => s.id == lastAssessment.studentId)
          .firstOrNull;
      items.add(_ActivityItem(
        icon: Icons.fact_check_outlined,
        title: 'آخر تقييم',
        subtitle: student?.name ?? lastAssessment.studentId,
        time: _formatDate(lastAssessment.createdAt),
      ));
    }

    final completedByParent = app.centerExercises
        .where((e) => e.status == 'completed_by_parent')
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (completedByParent.isNotEmpty) {
      final lastDone = completedByParent.first;
      final student = app.students
          .where((s) => s.id == lastDone.studentId)
          .firstOrNull;
      items.add(_ActivityItem(
        icon: Icons.assignment_turned_in_outlined,
        title: 'آخر واجب مكتمل من ولي الأمر',
        subtitle: student?.name ?? lastDone.studentId,
        time: _formatDate(lastDone.updatedAt),
      ));
    }

    return items;
  }

  String _formatDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value.isEmpty ? '-' : value;
    return '${date.year}/${date.month}/${date.day}';
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.item, required this.last});

  final _ActivityItem item;
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

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({required this.alerts});

  final List<_AlertItem> alerts;

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return const EmptyState(
        icon: Icons.verified_outlined,
        title: 'كل شيء مستقر',
        message: 'لا توجد تنبيهات مهمة الآن.',
      );
    }
    return TherapyCard(
      icon: Icons.notifications_active_outlined,
      title: 'تحتاج انتباه',
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

class _ActivityItem {
  const _ActivityItem({
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
