import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../widgets/app_widgets.dart';
import '../widgets/feedback.dart';

class CentersScreen extends StatefulWidget {
  const CentersScreen({super.key});

  @override
  State<CentersScreen> createState() => _CentersScreenState();
}

class _CentersScreenState extends State<CentersScreen> {
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
                label: const Text(
                    'ط·آ·ط¢آ¥ط·آ·ط¢آ¶ط·آ·ط¢آ§ط·آ¸ط¸آ¾ط·آ·ط¢آ© ط·آ¸أ¢â‚¬آ¦ط·آ·ط¢آ±ط·آ¸ط¦â€™ط·آ·ط¢آ²'))),
        const SizedBox(height: 12),
        if (app.centers.isEmpty)
          const EmptyState(
              icon: Icons.business_outlined,
              title:
                  'ط·آ¸أ¢â‚¬â€چط·آ·ط¢آ§ ط·آ·ط¹آ¾ط·آ¸ط«â€ ط·آ·ط¢آ¬ط·آ·ط¢آ¯ ط·آ¸أ¢â‚¬آ¦ط·آ·ط¢آ±ط·آ·ط¢آ§ط·آ¸ط¦â€™ط·آ·ط¢آ²',
              message:
                  'ط·آ·ط¢آ£ط·آ¸أ¢â‚¬آ ط·آ·ط¢آ´ط·آ·ط¢آ¦ ط·آ·ط¢آ£ط·آ¸ط«â€ ط·آ¸أ¢â‚¬â€چ ط·آ¸أ¢â‚¬آ¦ط·آ·ط¢آ±ط·آ¸ط¦â€™ط·آ·ط¢آ²ط·آ·ط¥â€™ ط·آ·ط¢آ«ط·آ¸أ¢â‚¬آ¦ ط·آ·ط¢آ£ط·آ¸أ¢â‚¬آ ط·آ·ط¢آ´ط·آ·ط¢آ¦ ط·آ¸أ¢â‚¬â€چط·آ¸أ¢â‚¬طŒ ط·آ¸أ¢â‚¬آ¦ط·آ·ط¢آ¯ط·آ¸ط¸آ¹ط·آ·ط¢آ± ط·آ¸أ¢â‚¬آ¦ط·آ·ط¢آ±ط·آ¸ط¦â€™ط·آ·ط¢آ² ط·آ¸أ¢â‚¬آ¦ط·آ¸أ¢â‚¬آ  ط·آ·ط¢آ´ط·آ·ط¢آ§ط·آ·ط¢آ´ط·آ·ط¢آ© ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ¸أ¢â‚¬آ¦ط·آ¸ط«â€ ط·آ·ط¢آ¸ط·آ¸ط¸آ¾ط·آ¸ط¸آ¹ط·آ¸أ¢â‚¬آ .')
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
                                  fontWeight: FontWeight.w800, fontSize: 18))),
                      Chip(
                          label: Text(center.isActive
                              ? 'ط·آ¸أ¢â‚¬آ ط·آ·ط¢آ´ط·آ·ط¢آ·'
                              : 'ط·آ¸أ¢â‚¬آ¦ط·آ·ط¹آ¾ط·آ¸ط«â€ ط·آ¸أ¢â‚¬ع‘ط·آ¸ط¸آ¾'))
                    ]),
                    Text(
                        'ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ¸أ¢â‚¬آ¦ط·آ·ط¢آ¯ط·آ¸ط¸آ¹ط·آ·ط¢آ±: ${center.managerName.isEmpty ? '-' : center.managerName}'),
                    Text(
                        'ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ¸أ¢â‚¬طŒط·آ·ط¢آ§ط·آ·ط¹آ¾ط·آ¸ط¸آ¾: ${center.phone.isEmpty ? '-' : center.phone}'),
                    Text(
                        'ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ·ط¢آ¹ط·آ¸أ¢â‚¬آ ط·آ¸ط«â€ ط·آ·ط¢آ§ط·آ¸أ¢â‚¬آ : ${center.address.isEmpty ? '-' : center.address}'),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, children: [
                      FilledButton.tonalIcon(
                          onPressed: () => app.switchCenter(center),
                          icon: const Icon(Icons.login),
                          label: const Text(
                              'ط·آ¸ط«â€ ط·آ·ط¢آ¶ط·آ·ط¢آ¹ ط·آ¸أ¢â‚¬آ¦ط·آ·ط¢آ³ط·آ·ط¢آ§ط·آ·ط¢آ¹ط·آ·ط¢آ¯ط·آ·ط¢آ©')),
                      FilledButton.tonalIcon(
                          onPressed: () =>
                              _showCenterForm(context, center: center),
                          icon: const Icon(Icons.edit),
                          label: const Text(
                              'ط·آ·ط¹آ¾ط·آ·ط¢آ¹ط·آ·ط¢آ¯ط·آ¸ط¸آ¹ط·آ¸أ¢â‚¬â€چ')),
                      FilledButton.tonalIcon(
                          onPressed: () => _toggle(context, center),
                          icon: Icon(center.isActive
                              ? Icons.pause_circle_outline
                              : Icons.play_circle_outline),
                          label: Text(center.isActive
                              ? 'ط·آ·ط¢آ¥ط·آ¸ط¸آ¹ط·آ¸أ¢â‚¬ع‘ط·آ·ط¢آ§ط·آ¸ط¸آ¾'
                              : 'ط·آ·ط¹آ¾ط·آ¸ط¸آ¾ط·آ·ط¢آ¹ط·آ¸ط¸آ¹ط·آ¸أ¢â‚¬â€چ')),
                      FilledButton.tonalIcon(
                          onPressed: () => _delete(context, center),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('ط·آ­ط·آ°ط¸ظ¾')),
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
            createdAt: center.createdAt)));
  }

  Future<void> _delete(BuildContext context, SanadCenter center) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('ط·آ­ط·آ°ط¸ظ¾ ط·آ§ط¸â€‍ط¸â€¦ط·آ±ط¸ئ’ط·آ²'),
            content:
                const Text('ط¸â€،ط¸â€‍ ط·ع¾ط·آ±ط¸ظ¹ط·آ¯ ط·آ­ط·آ°ط¸ظ¾ ط·ع؛'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('ط·آ¥ط¸â€‍ط·ط›ط·آ§ط·طŒ')),
              FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('ط·آ­ط·آ°ط¸ظ¾')),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;
    await runWithFeedback(
        context, () => context.read<AppProvider>().deleteCenter(center.id),
        success: 'ط·ع¾ط¸â€¦ ط·آ­ط·آ°ط¸ظ¾ ط·آ§ط¸â€‍ط¸â€¦ط·آ±ط¸ئ’ط·آ².');
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
        title: Text(center == null
            ? 'ط·آ·ط¢آ¥ط·آ·ط¢آ¶ط·آ·ط¢آ§ط·آ¸ط¸آ¾ط·آ·ط¢آ© ط·آ¸أ¢â‚¬آ¦ط·آ·ط¢آ±ط·آ¸ط¦â€™ط·آ·ط¢آ²'
            : 'ط·آ·ط¹آ¾ط·آ·ط¢آ¹ط·آ·ط¢آ¯ط·آ¸ط¸آ¹ط·آ¸أ¢â‚¬â€چ ط·آ¸أ¢â‚¬آ¦ط·آ·ط¢آ±ط·آ¸ط¦â€™ط·آ·ط¢آ²'),
        content: SizedBox(
          width: 520,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: name,
                decoration: const InputDecoration(
                    labelText:
                        'ط·آ·ط¢آ§ط·آ·ط¢آ³ط·آ¸أ¢â‚¬آ¦ ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ¸أ¢â‚¬آ¦ط·آ·ط¢آ±ط·آ¸ط¦â€™ط·آ·ط¢آ²')),
            const SizedBox(height: 10),
            TextField(
                controller: address,
                decoration: const InputDecoration(
                    labelText:
                        'ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ·ط¢آ¹ط·آ¸أ¢â‚¬آ ط·آ¸ط«â€ ط·آ·ط¢آ§ط·آ¸أ¢â‚¬آ ')),
            const SizedBox(height: 10),
            TextField(
                controller: phone,
                decoration: const InputDecoration(
                    labelText:
                        'ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ¸أ¢â‚¬طŒط·آ·ط¢آ§ط·آ·ط¹آ¾ط·آ¸ط¸آ¾')),
            const SizedBox(height: 10),
            TextField(
                controller: manager,
                decoration: const InputDecoration(
                    labelText:
                        'ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ¸أ¢â‚¬آ¦ط·آ·ط¢آ¯ط·آ¸ط¸آ¹ط·آ·ط¢آ±')),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child:
                  const Text('ط·آ·ط¢آ¥ط·آ¸أ¢â‚¬â€چط·آ·ط·â€؛ط·آ·ط¢آ§ط·آ·ط·إ’')),
          FilledButton(
            onPressed: () => runWithFeedback(context, () async {
              if (name.text.trim().isEmpty) {
                throw StateError(
                    'ط·آ·ط¢آ§ط·آ·ط¢آ³ط·آ¸أ¢â‚¬آ¦ ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ¸أ¢â‚¬آ¦ط·آ·ط¢آ±ط·آ¸ط¦â€™ط·آ·ط¢آ² ط·آ¸أ¢â‚¬آ¦ط·آ·ط¢آ·ط·آ¸أ¢â‚¬â€چط·آ¸ط«â€ ط·آ·ط¢آ¨.');
              }
              await context.read<AppProvider>().saveCenter(SanadCenter(
                  id: center?.id ??
                      'center_${DateTime.now().millisecondsSinceEpoch}',
                  name: name.text.trim(),
                  address: address.text.trim(),
                  phone: phone.text.trim(),
                  managerName: manager.text.trim(),
                  isActive: center?.isActive ?? true,
                  createdAt: center?.createdAt ?? ''));
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            }),
            child: const Text('ط·آ·ط¢آ­ط·آ¸ط¸آ¾ط·آ·ط¢آ¸'),
          ),
        ],
      ),
    );
  }
}
