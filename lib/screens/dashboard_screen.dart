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
    final improvement = _improvement(app);
    final todaySessions = _todaySessions(app);
    final alerts = _alerts(app, todaySessions);

    return AnimatedOpacity(
      opacity: 1,
      duration: const Duration(milliseconds: 220),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DashboardHero(
            app: app,
            improvement: improvement,
            todaySessions: todaySessions.length,
            alerts: alerts.length,
          ),
          const SizedBox(height: AppSpacing.md),
          ResponsiveGrid(
              children: _quickStats(app, improvement, todaySessions)),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 980;
              final timeline = _RecentActivityTimeline(app: app);
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

  int _improvement(AppProvider app) {
    final evaluations =
        app.centerEvaluations.isEmpty ? app.evaluations : app.centerEvaluations;
    final success = evaluations
        .where((item) => item.score == 'ظ†ط§ط¬ط­' || item.score == 'طµط­ظٹط­')
        .length;
    final partial =
        evaluations.where((item) => item.score == 'ط¬ط²ط¦ظٹ').length;
    if (evaluations.isEmpty) return 0;
    return (((success + partial * .5) / evaluations.length) * 100).round();
  }

  List<TherapySession> _todaySessions(AppProvider app) {
    final sessions = app.isOwner ? app.sessions : app.centerSessions;
    return sessions.where((session) => _isToday(session.startedAt)).toList();
  }

  bool _isToday(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return false;
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  List<_AlertItem> _alerts(
      AppProvider app, List<TherapySession> todaySessions) {
    final items = <_AlertItem>[];
    if (app.isOwner) {
      final stopped = app.centers.where((center) => !center.isActive).length;
      if (stopped > 0) {
        items.add(_AlertItem(
          icon: Icons.pause_circle_outline,
          title: 'ظ…ط±ط§ظƒط² ظ…ظˆظ‚ظˆظپط©',
          message:
              '$stopped ظ…ط±ظƒط² ظٹط­طھط§ط¬ ظ…طھط§ط¨ط¹ط© ط­ط§ظ„ط© ط§ظ„ط§ط´طھط±ط§ظƒ ط£ظˆ ط§ظ„ط¯ط¹ظ….',
          kind: SemanticAlertKind.warning,
        ));
      }
      final withoutManager = app.centers
          .where((center) => center.managerName.trim().isEmpty)
          .length;
      if (withoutManager > 0) {
        items.add(_AlertItem(
          icon: Icons.admin_panel_settings_outlined,
          title: 'ظ…ط¯ط±ط§ط، ط؛ظٹط± ظ…ظƒطھظ…ظ„ظٹظ†',
          message:
              '$withoutManager ظ…ط±ظƒط² ط¨ط¯ظˆظ† ظ…ط¯ظٹط± ظ…ط±طھط¨ط· ط¨ظˆط¶ظˆط­.',
          kind: SemanticAlertKind.info,
        ));
      }
    }
    final exercises = app.isParent ? app.exercises : app.centerExercises;
    final overdue = exercises.where((exercise) {
      final due = DateTime.tryParse(exercise.dueDate);
      return due != null &&
          due.isBefore(DateTime.now()) &&
          exercise.status != 'طھظ… ط§ظ„ط¥ظ†ط¬ط§ط²';
    }).length;
    if (overdue > 0) {
      items.add(_AlertItem(
        icon: Icons.assignment_late_outlined,
        title: 'ظˆط§ط¬ط¨ط§طھ طھط­طھط§ط¬ ظ…طھط§ط¨ط¹ط©',
        message:
            '$overdue ظˆط§ط¬ط¨ طھط¬ط§ظˆط² ظ…ظˆط¹ط¯ظ‡ ظˆظ„ظ… ظٹظƒطھظ…ظ„ ط¨ط¹ط¯.',
        kind: SemanticAlertKind.error,
      ));
    }
    if (todaySessions.length >= 6) {
      items.add(_AlertItem(
        icon: Icons.event_available_outlined,
        title: 'ظٹظˆظ… ط¹ظ„ط§ط¬ظٹ ظ…ط²ط¯ط­ظ…',
        message: '${todaySessions.length} ط¬ظ„ط³ط§طھ ظ…ط³ط¬ظ„ط© ط§ظ„ظٹظˆظ….',
        kind: SemanticAlertKind.success,
      ));
    }
    return items;
  }

  List<Widget> _quickStats(
    AppProvider app,
    int improvement,
    List<TherapySession> todaySessions,
  ) {
    if (app.isOwner) {
      final managers =
          app.staff.where((user) => user.role == UserRole.centerManager).length;
      final activeCenters =
          app.centers.where((center) => center.isActive).length;
      return [
        _PremiumStatCard(
          label: 'ط§ظ„ظ…ط±ط§ظƒط² ط§ظ„ظ†ط´ط·ط©',
          value: '$activeCenters',
          icon: Icons.business_outlined,
          progress:
              app.centers.isEmpty ? 0 : activeCenters / app.centers.length,
          trend: 'â†‘ ظ…طھط§ط¨ط¹ط© ظ…ط¨ط§ط´ط±ط©',
        ),
        _PremiumStatCard(
          label: 'ظ…ط¯ط±ط§ط، ط§ظ„ظ…ط±ط§ظƒط²',
          value: '$managers',
          icon: Icons.admin_panel_settings_outlined,
          progress: managers == 0 ? 0 : .82,
          trend: 'ظ…ط³طھظ‚ط±',
        ),
        _PremiumStatCard(
          label: 'ط§ظ„ط·ظ„ط§ط¨',
          value: '${app.totalStudentsCount}',
          icon: Icons.groups_2_outlined,
          progress: .68,
          trend: 'â†‘ ظ†ظ…ظˆ',
        ),
        _PremiumStatCard(
          label: 'ط§ظ„ط¬ظ„ط³ط§طھ',
          value: '${app.totalSessionsCount}',
          icon: Icons.timer_outlined,
          progress: .74,
          trend: 'ظ†ط´ط§ط· ط¹ظ„ط§ط¬ظٹ',
        ),
        _PremiumStatCard(
          label: 'ط¬ظ„ط³ط§طھ ط§ظ„ظٹظˆظ…',
          value: '${todaySessions.length}',
          icon: Icons.today_outlined,
          progress: (todaySessions.length / 10).clamp(0, 1).toDouble(),
          trend: 'ط§ظ„ظٹظˆظ…',
        ),
        _PremiumStatCard(
          label: 'ط§ظ„ط³ط¬ظ„ ط§ظ„ط¥ط¯ط§ط±ظٹ',
          value: '${app.auditLogs.length}',
          icon: Icons.history_outlined,
          progress: .55,
          trend: 'ط¢ط®ط± ظ†ط´ط§ط·',
        ),
      ];
    }
    if (app.isCenterManager) {
      final employees =
          app.staff.where((user) => user.role != UserRole.parent).length;
      return [
        _PremiumStatCard(
          label: 'ط§ظ„ط·ظ„ط§ط¨',
          value: '${app.students.length}',
          icon: Icons.groups_2_outlined,
          progress: .7,
          trend: 'ط¯ط§ط®ظ„ ط§ظ„ظ…ط±ظƒط²',
        ),
        _PremiumStatCard(
          label: 'ط§ظ„ظ…ظˆط¸ظپظˆظ†',
          value: '$employees',
          icon: Icons.badge_outlined,
          progress: .62,
          trend: 'ظپط±ظٹظ‚ ط§ظ„ط¹ظ…ظ„',
        ),
        _PremiumStatCard(
          label: 'ط¬ظ„ط³ط§طھ ط§ظ„ظٹظˆظ…',
          value: '${todaySessions.length}',
          icon: Icons.today_outlined,
          progress: (todaySessions.length / 8).clamp(0, 1).toDouble(),
          trend: 'ط¬ط¯ظˆظ„ ط§ظ„ظٹظˆظ…',
        ),
        _PremiumStatCard(
          label: 'ظ†ط³ط¨ط© ط§ظ„طھط­ط³ظ†',
          value: '$improvement%',
          icon: Icons.trending_up,
          progress: improvement / 100,
          trend: improvement >= 60 ? 'â†‘ ط¬ظٹط¯' : 'ظٹط­طھط§ط¬ ظ…طھط§ط¨ط¹ط©',
        ),
      ];
    }
    if (app.isSpecialist) {
      return [
        _PremiumStatCard(
          label: 'ط§ظ„ط·ظ„ط§ط¨',
          value: '${app.students.length}',
          icon: Icons.groups_2_outlined,
          progress: .68,
          trend: 'ظ…ظ„ظپط§طھ ظ…طھط§ط­ط©',
        ),
        _PremiumStatCard(
          label: 'ط¬ظ„ط³ط§طھ ط§ظ„ظٹظˆظ…',
          value: '${todaySessions.length}',
          icon: Icons.timer_outlined,
          progress: (todaySessions.length / 6).clamp(0, 1).toDouble(),
          trend: 'ط®ط·ط© ط§ظ„ظٹظˆظ…',
        ),
        _PremiumStatCard(
          label: 'ط§ظ„ظˆط§ط¬ط¨ط§طھ',
          value: '${app.centerExercises.length}',
          icon: Icons.assignment_outlined,
          progress: .58,
          trend: 'ظ…طھط§ط¨ط¹ط© ظ…ظ†ط²ظ„ظٹط©',
        ),
        _PremiumStatCard(
          label: 'ظ†ط³ط¨ط© ط§ظ„طھط­ط³ظ†',
          value: '$improvement%',
          icon: Icons.trending_up,
          progress: improvement / 100,
          trend: improvement >= 60 ? 'â†‘ طھظ‚ط¯ظ…' : 'ظ‚ظٹط¯ ط§ظ„ط¨ظ†ط§ط،',
        ),
      ];
    }
    if (app.isDataEntry) {
      return [
        _PremiumStatCard(
          label: 'ط§ظ„ط·ظ„ط§ط¨',
          value: '${app.students.length}',
          icon: Icons.groups_2_outlined,
          progress: .62,
          trend: 'ط¨ظٹط§ظ†ط§طھ ط§ظ„ظ…ط±ظƒط²',
        ),
        _PremiumStatCard(
          label: 'ط£ظˆظ„ظٹط§ط، ط§ظ„ط£ظ…ظˆط±',
          value:
              '${app.students.map((student) => student.parentPhone).toSet().length}',
          icon: Icons.family_restroom_outlined,
          progress: .52,
          trend: 'ط­ط³ط§ط¨ط§طھ ظ…ط±طھط¨ط·ط©',
        ),
        _PremiumStatCard(
          label: 'ط§ظ„ظ…ط±ظƒط²',
          value: app.currentCenter?.name ?? '-',
          icon: Icons.business_outlined,
          progress: .8,
          trend: 'ظ†ط·ط§ظ‚ ط§ظ„ط¹ظ…ظ„',
        ),
      ];
    }
    if (app.isProgramEntry) {
      return [
        _PremiumStatCard(
          label: 'التقييمات العلاجية',
          value: '${app.clinicalAssessments.length}',
          icon: Icons.fact_check_outlined,
          progress: .76,
          trend: 'بداية المسار السريري',
        ),
        _PremiumStatCard(
          label: 'الأهداف',
          value: '${app.plans.length}',
          icon: Icons.track_changes_outlined,
          progress: .66,
          trend: 'مرتبطة بنقاط الضعف',
        ),
        _PremiumStatCard(
          label: 'خطوات المهارات',
          value: '${app.goalSkillSteps.length}',
          icon: Icons.stairs_outlined,
          progress: .72,
          trend: 'تتبع تقدم الطفل',
        ),
      ];
    }
    return [
      _PremiumStatCard(
        label: 'ط§ظ„ط£ط·ظپط§ظ„',
        value: '${app.students.length}',
        icon: Icons.child_care_outlined,
        progress: app.students.isEmpty ? 0 : 1,
        trend: 'ط¯ط§ط®ظ„ ط§ظ„ط­ط³ط§ط¨',
      ),
      _PremiumStatCard(
        label: 'ط§ظ„ظˆط§ط¬ط¨ط§طھ ط§ظ„ط­ط§ظ„ظٹط©',
        value:
            '${app.exercises.where((item) => item.status != 'طھظ… ط§ظ„ط¥ظ†ط¬ط§ط²').length}',
        icon: Icons.assignment_outlined,
        progress: .55,
        trend: 'ظ…ط·ظ„ظˆط¨ طھظ†ظپظٹط°ظ‡ط§',
      ),
      _PremiumStatCard(
        label: 'ط§ظ„ظ…ظƒط§ظپط¢طھ',
        value: '${app.reward?.xp ?? 0} XP',
        icon: Icons.emoji_events_outlined,
        progress: ((app.reward?.xp ?? 0) % 100) / 100,
        trend: 'طھظ‚ط¯ظ… ظ…ظ†ط²ظ„ظٹ',
      ),
    ];
  }
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({
    required this.app,
    required this.improvement,
    required this.todaySessions,
    required this.alerts,
  });

  final AppProvider app;
  final int improvement;
  final int todaySessions;
  final int alerts;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeCenters = app.centers.where((center) => center.isActive).length;
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
                label: app.isOwner
                    ? 'ظ…ط±ط§ظƒط² ظ†ط´ط·ط©'
                    : 'ط¬ظ„ط³ط§طھ ط§ظ„ظٹظˆظ…',
                value: app.isOwner ? '$activeCenters' : '$todaySessions',
                icon: app.isOwner ? Icons.business : Icons.timer_outlined,
              ),
              _HeroMetric(
                label: 'ظ†ط³ط¨ط© ط§ظ„طھط­ط³ظ†',
                value: '$improvement%',
                icon: Icons.trending_up,
              ),
              _HeroMetric(
                label: 'طھظ†ط¨ظٹظ‡ط§طھ',
                value: '$alerts',
                icon: Icons.notifications_active_outlined,
              ),
            ],
          );
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _title(app),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _summary(app, todaySessions, alerts),
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

  String _title(AppProvider app) {
    if (app.isOwner) return 'ظ…ظ„ط®طµ ط³ظ†ط¯ ط§ظ„طھظ†ظپظٹط°ظٹ';
    if (app.isCenterManager) return 'ظ†ط¨ط¶ ط§ظ„ظ…ط±ظƒط² ط§ظ„ظٹظˆظ…';
    if (app.isSpecialist) return 'ظ…ط³ط§ط± ط¬ظ„ط³ط§طھظƒ ط§ظ„ط¹ظ„ط§ط¬ظٹط©';
    if (app.isParent) return 'ظ…طھط§ط¨ط¹ط© ط§ظ„ط·ظپظ„ ظپظٹ ط§ظ„ظ…ظ†ط²ظ„';
    if (app.isProgramEntry) return 'ظ…ظƒطھط¨ط© ط§ظ„ط¨ط±ط§ظ…ط¬ ط§ظ„ط¹ظ„ط§ط¬ظٹط©';
    return 'ظ„ظˆط­ط© ط§ظ„ظٹظˆظ…';
  }

  String _summary(AppProvider app, int todaySessions, int alerts) {
    if (app.isOwner) {
      return 'ظ†ط¸ط±ط© ط³ط±ظٹط¹ط© ط¹ظ„ظ‰ ط§ظ„ظ…ط±ط§ظƒط² ظˆط§ظ„ط­ط³ط§ط¨ط§طھ ظˆط§ظ„ظ†ط´ط§ط· ط§ظ„ط¥ط¯ط§ط±ظٹ ظپظٹ ط³ظ†ط¯.';
    }
    if (app.isParent) {
      return 'طھط§ط¨ط¹ ط§ظ„ظˆط§ط¬ط¨ط§طھ ط§ظ„ط­ط§ظ„ظٹط© ظˆط§ظ„طھظ‚ط¯ظ… ظˆط§ظ„ظ…ظƒط§ظپط¢طھ ظ…ظ† ظ…ظƒط§ظ† ظˆط§ط­ط¯.';
    }
    return 'ظ„ط¯ظٹظƒ $todaySessions ط¬ظ„ط³ط§طھ ظ…ط³ط¬ظ„ط© ط§ظ„ظٹظˆظ… ظˆ$alerts طھظ†ط¨ظٹظ‡ط§طھ طھط­طھط§ط¬ ط§ظ†طھط¨ط§ظ‡.';
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
      width: 150,
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
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),
          Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: .82)),
          ),
        ],
      ),
    );
  }
}

class _PremiumStatCard extends StatefulWidget {
  const _PremiumStatCard({
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
  State<_PremiumStatCard> createState() => _PremiumStatCardState();
}

class _PremiumStatCardState extends State<_PremiumStatCard> {
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
              Text(widget.label, style: Theme.of(context).textTheme.bodyMedium),
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

class _RecentActivityTimeline extends StatelessWidget {
  const _RecentActivityTimeline({required this.app});

  final AppProvider app;

  @override
  Widget build(BuildContext context) {
    final items = _items(app);
    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.history_outlined,
        title: 'ظ„ط§ ظٹظˆط¬ط¯ ظ†ط´ط§ط· ط­ط¯ظٹط«',
        message:
            'ط³طھط¸ظ‡ط± ظ‡ظ†ط§ ط§ظ„ط¹ظ…ظ„ظٹط§طھ ط§ظ„ظ…ظ‡ظ…ط© ظ…ط«ظ„ ط§ظ„ط¬ظ„ط³ط§طھ ظˆط§ظ„ظˆط§ط¬ط¨ط§طھ ظˆط§ظ„طھظ‚ط§ط±ظٹط±.',
      );
    }
    return TherapyCard(
      icon: Icons.timeline_outlined,
      title: 'ط§ظ„ظ†ط´ط§ط· ط§ظ„ط£ط®ظٹط±',
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            _TimelineRow(item: items[i], last: i == items.length - 1),
        ],
      ),
    );
  }

  List<_ActivityItem> _items(AppProvider app) {
    final logs = app.auditLogs.take(6).map((log) {
      return _ActivityItem(
        icon: Icons.manage_history_outlined,
        title: log.action,
        subtitle: log.details.isEmpty ? log.userName : log.details,
        time: _shortDate(log.createdAt),
      );
    }).toList();
    if (logs.isNotEmpty) return logs;

    final sessions = (app.isOwner ? app.sessions : app.centerSessions).take(6);
    final sessionItems = sessions.map((session) {
      return _ActivityItem(
        icon: Icons.timer_outlined,
        title: 'ط¬ظ„ط³ط© ط¹ظ„ط§ط¬ظٹط©',
        subtitle:
            session.cardTitle.isEmpty ? session.sessionType : session.cardTitle,
        time: _shortDate(session.startedAt),
      );
    }).toList();
    if (sessionItems.isNotEmpty) return sessionItems;

    final exercises =
        (app.isParent ? app.exercises : app.centerExercises).take(6);
    return exercises.map((exercise) {
      return _ActivityItem(
        icon: Icons.assignment_outlined,
        title: exercise.title,
        subtitle: exercise.status,
        time: _shortDate(exercise.dueDate),
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
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    Text(
                      item.time,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
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
        title: 'ظƒظ„ ط´ظٹط، ظ…ط³طھظ‚ط±',
        message:
            'ظ„ط§ طھظˆط¬ط¯ طھظ†ط¨ظٹظ‡ط§طھ ظ…ظ‡ظ…ط© ط§ظ„ط¢ظ†. ط§ظ„ظ†ط¸ط§ظ… ظٹط¹ط·ظٹظƒ ظ…ط³ط§ط­ط© ظ‡ط§ط¯ط¦ط© ظ„ظ„ط¹ظ…ظ„.',
      );
    }
    return TherapyCard(
      icon: Icons.notifications_active_outlined,
      title: 'طھط­طھط§ط¬ ط§ظ†طھط¨ط§ظ‡',
      child: Column(
        children: [
          for (final alert in alerts) ...[
            _AlertTile(alert: alert),
            if (alert != alerts.last) const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert});

  final _AlertItem alert;

  @override
  Widget build(BuildContext context) {
    return SemanticAlertCard(
      kind: alert.kind,
      icon: alert.icon,
      title: alert.title,
      message: alert.message,
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
