import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../widgets/app_widgets.dart';
import '../widgets/feedback.dart';

class CentersScreen extends StatelessWidget {
  const CentersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TherapyCard(
          title: 'المراكز',
          icon: Icons.business_outlined,
          trailing: FilledButton.icon(
            onPressed: () => _showCenterForm(context),
            icon: const Icon(Icons.add_business),
            label: const Text('إضافة مركز'),
          ),
          child: const Text(
            'إدارة المراكز، حالة التشغيل، والبيانات التشغيلية المختصرة لكل مركز.',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (app.centers.isEmpty)
          EmptyState(
            icon: Icons.business_outlined,
            title: 'لا توجد مراكز',
            message: 'أضف أول مركز ثم أنشئ مدير المركز من شاشة المدراء.',
            action: FilledButton.icon(
              onPressed: () => _showCenterForm(context),
              icon: const Icon(Icons.add_business),
              label: const Text('إضافة مركز'),
            ),
          )
        else
          ResponsiveGrid(
            children: app.centers
                .map((center) => _CenterDashboardCard(
                      center: center,
                      studentsCount: app.centerStudentCounts[center.id] ?? 0,
                      specialistsCount:
                          app.centerSpecialistCounts[center.id] ?? 0,
                      sessionsCount: app.centerSessionCounts[center.id] ?? 0,
                      lastActivity: app.centerLastActivities[center.id] ?? '',
                      onEdit: () => _showCenterForm(context, center: center),
                      onToggle: () => _toggle(context, center),
                      onDelete: () => _delete(context, center),
                    ))
                .toList(),
          ),
      ],
    );
  }

  Future<void> _toggle(BuildContext context, SanadCenter center) {
    return runWithFeedback(
      context,
      () => context.read<AppProvider>().saveCenter(SanadCenter(
            id: center.id,
            name: center.name,
            logoPath: center.logoPath,
            address: center.address,
            phone: center.phone,
            managerName: center.managerName,
            isActive: !center.isActive,
            createdAt: center.createdAt,
            updatedAt: DateTime.now().toIso8601String(),
          )),
      success: center.isActive
          ? 'تم إيقاف المركز وتعطيل دخول حساباته.'
          : 'تم تفعيل المركز.',
    );
  }

  Future<void> _delete(BuildContext context, SanadCenter center) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('حذف المركز'),
            content: Text('هل تريد حذف مركز ${center.name}؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('حذف'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;
    await runWithFeedback(
      context,
      () => context.read<AppProvider>().deleteCenter(center.id),
      success: 'تم حذف المركز.',
    );
  }

  Future<void> _showCenterForm(BuildContext context,
      {SanadCenter? center}) async {
    final name = TextEditingController(text: center?.name ?? '');
    final address = TextEditingController(text: center?.address ?? '');
    final phone = TextEditingController(text: center?.phone ?? '');
    final manager = TextEditingController(text: center?.managerName ?? '');
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(center == null ? 'إضافة مركز' : 'تعديل مركز'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'اسم المركز'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: address,
                decoration: const InputDecoration(labelText: 'العنوان'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(labelText: 'الهاتف'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: manager,
                decoration: const InputDecoration(labelText: 'المدير'),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => runWithFeedback(context, () async {
              if (name.text.trim().isEmpty) {
                throw StateError('اسم المركز مطلوب.');
              }
              await context.read<AppProvider>().saveCenter(SanadCenter(
                    id: center?.id ??
                        'center_${DateTime.now().millisecondsSinceEpoch}',
                    name: name.text.trim(),
                    address: address.text.trim(),
                    phone: phone.text.trim(),
                    managerName: manager.text.trim(),
                    isActive: center?.isActive ?? true,
                    createdAt: center?.createdAt ?? '',
                    updatedAt: DateTime.now().toIso8601String(),
                  ));
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            }),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

class _CenterDashboardCard extends StatefulWidget {
  const _CenterDashboardCard({
    required this.center,
    required this.studentsCount,
    required this.specialistsCount,
    required this.sessionsCount,
    required this.lastActivity,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final SanadCenter center;
  final int studentsCount;
  final int specialistsCount;
  final int sessionsCount;
  final String lastActivity;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  State<_CenterDashboardCard> createState() => _CenterDashboardCardState();
}

class _CenterDashboardCardState extends State<_CenterDashboardCard> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    final center = widget.center;
    final active = center.isActive;
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
            label: active ? 'نشط' : 'موقوف',
            icon: active ? Icons.check_circle_outline : Icons.block,
            selected: active,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          center.managerName.isEmpty
                              ? 'لم يتم تحديد مدير'
                              : 'المدير: ${center.managerName}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          center.address.isEmpty
                              ? 'العنوان غير محدد'
                              : center.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _MiniStat(
                      icon: Icons.groups_2_outlined,
                      label: 'الطلاب',
                      value: '${widget.studentsCount}'),
                  _MiniStat(
                      icon: Icons.psychology_outlined,
                      label: 'الأخصائيون',
                      value: '${widget.specialistsCount}'),
                  _MiniStat(
                      icon: Icons.timer_outlined,
                      label: 'الجلسات',
                      value: '${widget.sessionsCount}'),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  const AppPill(
                      label: 'الاشتراك: فعال', icon: Icons.verified_outlined),
                  AppPill(
                    label:
                        'آخر نشاط: ${widget.lastActivity.isEmpty ? 'لا يوجد' : widget.lastActivity.split('T').first}',
                    icon: Icons.history_outlined,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: widget.onEdit,
                    icon: const Icon(Icons.edit),
                    label: const Text('تعديل'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: widget.onToggle,
                    icon: Icon(active
                        ? Icons.pause_circle_outline
                        : Icons.play_circle_outline),
                    label: Text(active ? 'إيقاف' : 'تفعيل'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('حذف'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(
      {required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 118,
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
          Text(value,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
