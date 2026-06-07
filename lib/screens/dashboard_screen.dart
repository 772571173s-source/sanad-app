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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DashboardHero(
          app: app,
          improvement: improvement,
          todaySessions: todaySessions.length,
          alerts: alerts.length,
        ),
        const SizedBox(height: AppSpacing.md),
        ResponsiveGrid(children: _quickStats(app, improvement, todaySessions)),
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
    );
  }

  int _improvement(AppProvider app) {
    final sessions =
        app.centerSessions.isEmpty ? app.sessions : app.centerSessions;
    if (sessions.isNotEmpty) {
      final total =
          sessions.fold<int>(0, (sum, session) => sum + session.successRate);
      return (total / sessions.length).round();
    }
    final evaluations =
        app.centerEvaluations.isEmpty ? app.evaluations : app.centerEvaluations;
    if (evaluations.isEmpty) return 0;
    final good = evaluations
        .where((item) => item.score == 'ناجح' || item.score == 'صحيح')
        .length;
    final partial = evaluations.where((item) => item.score == 'جزئي').length;
    return (((good + partial * .5) / evaluations.length) * 100).round();
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
          title: 'مراكز موقوفة',
          message: '$stopped مركز يحتاج متابعة حالة الاشتراك أو الدعم.',
          kind: SemanticAlertKind.warning,
        ));
      }
      final withoutManager = app.centers
          .where((center) => center.managerName.trim().isEmpty)
          .length;
      if (withoutManager > 0) {
        items.add(_AlertItem(
          icon: Icons.admin_panel_settings_outlined,
          title: 'مدراء غير مكتملين',
          message: '$withoutManager مركز بدون مدير مرتبط بوضوح.',
          kind: SemanticAlertKind.info,
        ));
      }
    }

    final exercises = app.isParent ? app.exercises : app.centerExercises;
    final overdue = exercises.where((exercise) {
      final due = DateTime.tryParse(exercise.dueDate);
      return due != null &&
          due.isBefore(DateTime.now()) &&
          exercise.status != 'تم الإنجاز';
    }).length;
    if (overdue > 0) {
      items.add(_AlertItem(
        icon: Icons.assignment_late_outlined,
        title: 'واجبات تحتاج متابعة',
        message: '$overdue واجب تجاوز موعده ولم يكتمل بعد.',
        kind: SemanticAlertKind.error,
      ));
    }

    if (todaySessions.length >= 6) {
      items.add(_AlertItem(
        icon: Icons.event_available_outlined,
        title: 'يوم علاجي نشط',
        message: '${todaySessions.length} جلسات مسجلة اليوم.',
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
          label: 'المراكز النشطة',
          value: '$activeCenters',
          icon: Icons.business_outlined,
          progress:
              app.centers.isEmpty ? 0 : activeCenters / app.centers.length,
          trend: 'متابعة مباشرة',
        ),
        _PremiumStatCard(
          label: 'مدراء المراكز',
          value: '$managers',
          icon: Icons.admin_panel_settings_outlined,
          progress: managers == 0 ? 0 : .82,
          trend: 'مستقر',
        ),
        _PremiumStatCard(
          label: 'الطلاب',
          value: '${app.totalStudentsCount}',
          icon: Icons.groups_2_outlined,
          progress: .68,
          trend: 'نمو',
        ),
        _PremiumStatCard(
          label: 'الجلسات',
          value: '${app.totalSessionsCount}',
          icon: Icons.timer_outlined,
          progress: .74,
          trend: 'نشاط علاجي',
        ),
      ];
    }

    if (app.isCenterManager) {
      final employees =
          app.staff.where((user) => user.role != UserRole.parent).length;
      return [
        _PremiumStatCard(
          label: 'الطلاب',
          value: '${app.students.length}',
          icon: Icons.groups_2_outlined,
          progress: .7,
          trend: 'داخل المركز',
        ),
        _PremiumStatCard(
          label: 'الموظفون',
          value: '$employees',
          icon: Icons.badge_outlined,
          progress: .62,
          trend: 'فريق العمل',
        ),
        _PremiumStatCard(
          label: 'جلسات اليوم',
          value: '${todaySessions.length}',
          icon: Icons.today_outlined,
          progress: (todaySessions.length / 8).clamp(0, 1).toDouble(),
          trend: 'جدول اليوم',
        ),
        _PremiumStatCard(
          label: 'نسبة التحسن',
          value: '$improvement%',
          icon: Icons.trending_up,
          progress: improvement / 100,
          trend: improvement >= 60 ? 'تقدم جيد' : 'يحتاج متابعة',
        ),
      ];
    }

    if (app.isSpecialist) {
      return [
        _PremiumStatCard(
          label: 'الطلاب',
          value: '${app.students.length}',
          icon: Icons.groups_2_outlined,
          progress: .68,
          trend: 'ملفات متاحة',
        ),
        _PremiumStatCard(
          label: 'جلسات اليوم',
          value: '${todaySessions.length}',
          icon: Icons.timer_outlined,
          progress: (todaySessions.length / 6).clamp(0, 1).toDouble(),
          trend: 'خطة اليوم',
        ),
        _PremiumStatCard(
          label: 'الأهداف العلاجية',
          value: '${app.plans.length}',
          icon: Icons.track_changes_outlined,
          progress: .58,
          trend: 'مسار سريري',
        ),
        _PremiumStatCard(
          label: 'نسبة التحسن',
          value: '$improvement%',
          icon: Icons.trending_up,
          progress: improvement / 100,
          trend: improvement >= 60 ? 'تقدم' : 'قيد البناء',
        ),
      ];
    }

    if (app.isDataEntry) {
      return [
        _PremiumStatCard(
          label: 'الطلاب',
          value: '${app.students.length}',
          icon: Icons.groups_2_outlined,
          progress: .62,
          trend: 'بيانات المركز',
        ),
        _PremiumStatCard(
          label: 'أولياء الأمور',
          value:
              '${app.students.map((student) => student.parentPhone).toSet().length}',
          icon: Icons.family_restroom_outlined,
          progress: .52,
          trend: 'حسابات مرتبطة',
        ),
        _PremiumStatCard(
          label: 'المركز',
          value: app.currentCenter?.name ?? '-',
          icon: Icons.business_outlined,
          progress: .8,
          trend: 'نطاق العمل',
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
        label: 'الأطفال',
        value: '${app.students.length}',
        icon: Icons.child_care_outlined,
        progress: app.students.isEmpty ? 0 : 1,
        trend: 'داخل الحساب',
      ),
      _PremiumStatCard(
        label: 'الواجبات الحالية',
        value:
            '${app.exercises.where((item) => item.status != 'تم الإنجاز').length}',
        icon: Icons.assignment_outlined,
        progress: .55,
        trend: 'مطلوب تنفيذها',
      ),
      _PremiumStatCard(
        label: 'المكافآت',
        value: '${app.reward?.xp ?? 0} XP',
        icon: Icons.emoji_events_outlined,
        progress: ((app.reward?.xp ?? 0) % 100) / 100,
        trend: 'تقدم منزلي',
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
                label: app.isOwner ? 'مراكز نشطة' : 'جلسات اليوم',
                value: app.isOwner ? '$activeCenters' : '$todaySessions',
                icon: app.isOwner ? Icons.business : Icons.timer_outlined,
              ),
              _HeroMetric(
                label: 'نسبة التحسن',
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
    if (app.isOwner) return 'ملخص سند التنفيذي';
    if (app.isCenterManager) return 'نبض المركز اليوم';
    if (app.isSpecialist) return 'مسار جلساتك العلاجية';
    if (app.isParent) return 'متابعة الطفل في المنزل';
    if (app.isProgramEntry) return 'النواة العلاجية';
    return 'لوحة اليوم';
  }

  String _summary(AppProvider app, int todaySessions, int alerts) {
    if (app.isOwner) {
      return 'نظرة سريعة على المراكز والحسابات والنشاط الإداري في سند.';
    }
    if (app.isParent) {
      return 'تابع الواجبات الحالية والتقدم والمكافآت من مكان واحد.';
    }
    return 'لديك $todaySessions جلسات مسجلة اليوم و$alerts تنبيهات تحتاج انتباه.';
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
          Text(label,
              style: TextStyle(color: Colors.white.withValues(alpha: .82))),
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
        title: 'لا يوجد نشاط حديث',
        message: 'ستظهر هنا العمليات المهمة مثل الجلسات والواجبات والتقارير.',
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
        title: 'جلسة علاجية',
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
            if (alert != alerts.last) const SizedBox(height: AppSpacing.sm),
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
