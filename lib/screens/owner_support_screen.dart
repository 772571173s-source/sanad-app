import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../widgets/app_widgets.dart';
import '../widgets/feedback.dart';

class OwnerSupportScreen extends StatelessWidget {
  const OwnerSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    if (app.centers.isEmpty) {
      return const EmptyState(
        icon: Icons.support_agent,
        title: 'لا توجد مراكز',
        message: 'أضف مركزًا أولًا حتى يظهر في لوحة المساعدة.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TherapyCard(
          title: 'لوحة دعم المراكز',
          icon: Icons.support_agent,
          child: Text(
            'اختر مركزًا للدخول إلى بيئته ومساعدته بصلاحيات مدير المركز دون الخروج من حساب مالك سند.',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ResponsiveGrid(
          children: app.centers
              .map((center) => _SupportCenterCard(
                    center: center,
                    studentsCount: app.centerStudentCounts[center.id] ?? 0,
                    specialistsCount:
                        app.centerSpecialistCounts[center.id] ?? 0,
                    sessionsCount: app.centerSessionCounts[center.id] ?? 0,
                    lastActivity: app.centerLastActivities[center.id] ?? '',
                    onAssist: () => _assist(context, center),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Future<void> _assist(BuildContext context, SanadCenter center) {
    return runWithFeedback(
      context,
      () => context.read<AppProvider>().enterSupportMode(center),
      success: 'تم الدخول إلى وضع مساعدة المركز.',
    );
  }
}

class _SupportCenterCard extends StatefulWidget {
  const _SupportCenterCard({
    required this.center,
    required this.studentsCount,
    required this.specialistsCount,
    required this.sessionsCount,
    required this.lastActivity,
    required this.onAssist,
  });

  final SanadCenter center;
  final int studentsCount;
  final int specialistsCount;
  final int sessionsCount;
  final String lastActivity;
  final VoidCallback onAssist;

  @override
  State<_SupportCenterCard> createState() => _SupportCenterCardState();
}

class _SupportCenterCardState extends State<_SupportCenterCard> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    final center = widget.center;
    return MouseRegion(
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),
      child: AnimatedScale(
        scale: hovering ? 1.01 : 1,
        duration: const Duration(milliseconds: 160),
        child: TherapyCard(
          title: center.name,
          icon: Icons.apartment_outlined,
          trailing: AppPill(
            label: center.isActive ? 'نشط' : 'موقوف',
            icon: center.isActive ? Icons.check_circle_outline : Icons.block,
            selected: center.isActive,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                center.managerName.isEmpty
                    ? 'لم يتم تحديد مدير'
                    : 'المدير: ${center.managerName}',
                style: const TextStyle(fontWeight: FontWeight.w800),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _SupportStat(
                    icon: Icons.groups_2_outlined,
                    label: 'الطلاب',
                    value: '${widget.studentsCount}',
                  ),
                  _SupportStat(
                    icon: Icons.psychology_outlined,
                    label: 'الأخصائيون',
                    value: '${widget.specialistsCount}',
                  ),
                  _SupportStat(
                    icon: Icons.timer_outlined,
                    label: 'الجلسات',
                    value: '${widget.sessionsCount}',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AppPill(
                label:
                    'آخر نشاط: ${widget.lastActivity.isEmpty ? 'لا يوجد' : widget.lastActivity.split('T').first}',
                icon: Icons.history_outlined,
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: widget.onAssist,
                  icon: const Icon(Icons.support_agent),
                  label: const Text('مساعدة المركز'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportStat extends StatelessWidget {
  const _SupportStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 100, maxWidth: 140),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            maxLines: 1, overflow: TextOverflow.ellipsis,
          ),
          Text(label,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
