import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../widgets/app_widgets.dart';
import '../widgets/feedback.dart';

class SignLibraryScreen extends StatefulWidget {
  const SignLibraryScreen({super.key});

  @override
  State<SignLibraryScreen> createState() => _SignLibraryScreenState();
}

class _SignLibraryScreenState extends State<SignLibraryScreen> {
  final title = TextEditingController();
  final category = TextEditingController(text: 'أساسيات');
  final notes = TextEditingController();
  String mediaType = 'صورة';
  String mediaPath = '';

  @override
  void dispose() {
    title.dispose();
    category.dispose();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('مكتبة لغة الإشارة', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(width: 240, child: TextField(controller: title, decoration: const InputDecoration(labelText: 'اسم الإشارة'))),
                  SizedBox(width: 180, child: TextField(controller: category, decoration: const InputDecoration(labelText: 'التصنيف'))),
                  SizedBox(
                    width: 160,
                    child: DropdownButtonFormField<String>(
                      initialValue: mediaType,
                      decoration: const InputDecoration(labelText: 'نوع الملف'),
                      items: const ['صورة', 'فيديو'].map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                      onChanged: (value) => setState(() => mediaType = value ?? mediaType),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(mediaType == 'صورة' ? Icons.image_outlined : Icons.video_library_outlined),
                title: Text(mediaPath.isEmpty ? 'لم يتم اختيار ملف' : mediaPath),
                trailing: TextButton(onPressed: _pickMedia, child: const Text('اختيار')),
              ),
              TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'ملاحظات')),
              const SizedBox(height: 12),
              FilledButton.icon(onPressed: () => _save(app), icon: const Icon(Icons.add), label: const Text('إضافة للمكتبة')),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (app.signResources.isEmpty)
          const EmptyState(icon: Icons.sign_language_outlined, title: 'لا توجد إشارات', message: 'أضف إشارات مصورة لتظهر في الجلسات وواجبات الأهل.')
        else
          ResponsiveGrid(
            children: app.signResources.map((resource) {
              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (resource.mediaType == 'صورة' && File(resource.mediaPath).existsSync())
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(File(resource.mediaPath), height: 150, width: double.infinity, fit: BoxFit.cover),
                      )
                    else
                      Container(
                        height: 110,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Theme.of(context).colorScheme.surfaceContainerHighest),
                        child: Icon(resource.mediaType == 'صورة' ? Icons.image_outlined : Icons.play_circle_outline, size: 48),
                      ),
                    const SizedBox(height: 10),
                    Text(resource.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                    Text('${resource.category} - ${resource.mediaType}'),
                    if (resource.notes.isNotEmpty) Text(resource.notes),
                    Align(alignment: Alignment.centerLeft, child: IconButton(onPressed: () => runWithFeedback(context, () => app.deleteSignResource(resource.id), success: 'تم حذف الإشارة.'), icon: const Icon(Icons.delete_outline))),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Future<void> _pickMedia() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: mediaType == 'صورة' ? ['jpg', 'jpeg', 'png', 'webp'] : ['mp4', 'mov', 'avi', 'mkv'],
    );
    final path = result?.files.single.path;
    if (path != null) setState(() => mediaPath = path);
  }

  Future<void> _save(AppProvider app) async {
    await runWithFeedback(context, () async {
      if (title.text.trim().isEmpty || mediaPath.isEmpty) throw StateError('اسم الإشارة والصورة/الفيديو مطلوبة.');
      await app.saveSignResource(
        SignResource(
          id: 'sign_${DateTime.now().millisecondsSinceEpoch}',
          centerId: app.activeCenterId,
          title: title.text.trim(),
          category: category.text.trim(),
          mediaType: mediaType,
          mediaPath: mediaPath,
          notes: notes.text.trim(),
        ),
      );
      title.clear();
      notes.clear();
      setState(() => mediaPath = '');
    }, success: 'تمت إضافة الإشارة.', loading: 'جار حفظ الإشارة...');
  }
}
