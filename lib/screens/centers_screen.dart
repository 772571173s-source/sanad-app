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
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => _showCenterForm(context),
            icon: const Icon(Icons.add_business),
            label: const Text('إضافة مركز'),
          ),
        ),
        const SizedBox(height: 12),
        if (app.centers.isEmpty)
          const EmptyState(
            icon: Icons.business_outlined,
            title: 'لا توجد مراكز',
            message: 'أضف أول مركز ثم أنشئ مدير المركز من شاشة الموظفين.',
          )
        else
          ResponsiveGrid(
            children: app.centers.map((center) {
              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(center.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 18)),
                      ),
                      Chip(label: Text(center.isActive ? 'نشط' : 'متوقف')),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                        'المدير: ${center.managerName.isEmpty ? '-' : center.managerName}'),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                            'الهاتف: ${center.phone.isEmpty ? '-' : center.phone}'),
                      ),
                    ),
                    Text(
                        'العنوان: ${center.address.isEmpty ? '-' : center.address}'),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      FilledButton.tonalIcon(
                        onPressed: () => app.switchCenter(center),
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('وضع مساعدة'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () =>
                            _showCenterForm(context, center: center),
                        icon: const Icon(Icons.edit),
                        label: const Text('تعديل'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => _toggle(context, center),
                        icon: Icon(center.isActive
                            ? Icons.pause_circle_outline
                            : Icons.play_circle_outline),
                        label: Text(center.isActive ? 'إيقاف' : 'تفعيل'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => _delete(context, center),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('حذف'),
                      ),
                    ]),
                  ],
                ),
              );
            }).toList(),
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
      success: center.isActive ? 'تم إيقاف المركز.' : 'تم تفعيل المركز.',
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
              const SizedBox(height: 10),
              TextField(
                controller: address,
                decoration: const InputDecoration(labelText: 'العنوان'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(labelText: 'الهاتف'),
              ),
              const SizedBox(height: 10),
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
