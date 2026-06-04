import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../widgets/app_widgets.dart';
import '../widgets/feedback.dart';

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('النسخ الاحتياطي', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        const Text('يمكن تصدير قاعدة البيانات كنسخة احتياطية أو استيراد نسخة محفوظة عند الحاجة.'),
        const SizedBox(height: 16),
        Wrap(spacing: 8, children: [
          FilledButton.icon(onPressed: () => _export(context), icon: const Icon(Icons.upload_file), label: const Text('تصدير Backup')),
          FilledButton.tonalIcon(onPressed: () => _import(context), icon: const Icon(Icons.download_for_offline_outlined), label: const Text('استيراد Backup')),
        ]),
      ]),
    );
  }

  Future<void> _export(BuildContext context) async {
    final path = await FilePicker.platform.saveFile(dialogTitle: 'حفظ نسخة سند', fileName: 'sanad-backup.db');
    if (path == null) return;
    if (context.mounted) await runWithFeedback(context, () => context.read<AppProvider>().exportBackup(path), success: 'تم تصدير النسخة الاحتياطية.');
  }

  Future<void> _import(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    final path = result?.files.single.path;
    if (path == null) return;
    if (context.mounted) await runWithFeedback(context, () => context.read<AppProvider>().importBackup(path), success: 'تم استيراد النسخة الاحتياطية.');
  }
}
