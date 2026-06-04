import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../widgets/app_widgets.dart';
import '../widgets/feedback.dart';

class CenterSettingsScreen extends StatefulWidget {
  const CenterSettingsScreen({super.key});

  @override
  State<CenterSettingsScreen> createState() => _CenterSettingsScreenState();
}

class _CenterSettingsScreenState extends State<CenterSettingsScreen> {
  final name = TextEditingController();
  final address = TextEditingController();
  final phone = TextEditingController();
  final manager = TextEditingController();
  String logoPath = '';

  @override
  void dispose() {
    name.dispose();
    address.dispose();
    phone.dispose();
    manager.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final center = context.read<AppProvider>().currentCenter;
    name.text = center?.name ?? '';
    address.text = center?.address ?? '';
    phone.text = center?.phone ?? '';
    manager.text = center?.managerName ?? '';
    logoPath = center?.logoPath ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final center = context.watch<AppProvider>().currentCenter;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('إعدادات المركز', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم المركز')),
        const SizedBox(height: 10),
        TextField(controller: address, decoration: const InputDecoration(labelText: 'العنوان')),
        const SizedBox(height: 10),
        TextField(controller: phone, decoration: const InputDecoration(labelText: 'الهاتف')),
        const SizedBox(height: 10),
        TextField(controller: manager, decoration: const InputDecoration(labelText: 'المدير')),
        const SizedBox(height: 10),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.image_outlined),
          title: Text(logoPath.isEmpty ? 'لا يوجد شعار' : logoPath),
          trailing: TextButton(
            onPressed: () async {
              final result = await FilePicker.platform.pickFiles(type: FileType.image);
              final picked = result?.files.single.path;
              if (picked != null) setState(() => logoPath = picked);
            },
            child: const Text('اختيار شعار'),
          ),
        ),
        FilledButton.icon(
          onPressed: center == null
              ? null
              : () => runWithFeedback(context, () async {
                    if (name.text.trim().isEmpty) throw StateError('اسم المركز مطلوب.');
                    await context.read<AppProvider>().saveCenter(SanadCenter(id: center.id, name: name.text.trim(), logoPath: logoPath, address: address.text.trim(), phone: phone.text.trim(), managerName: manager.text.trim(), isActive: center.isActive, createdAt: center.createdAt));
                  }),
          icon: const Icon(Icons.save),
          label: const Text('حفظ الإعدادات'),
        ),
      ]),
    );
  }
}
