import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../widgets/app_widgets.dart';
import '../widgets/feedback.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  String query = '';
  String status = 'الكل';

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final filtered = app.students.where((student) {
      final matchesSearch = student.name.contains(query) || student.diagnosis.contains(query);
      final matchesStatus = status == 'الكل' || student.status == status;
      return matchesSearch && matchesStatus;
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'بحث بالاسم أو التشخيص'), onChanged: (value) => setState(() => query = value))),
            const SizedBox(width: 12),
            DropdownButton<String>(
              value: status,
              items: const ['الكل', 'نشط', 'متابعة', 'متوقف'].map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
              onChanged: (value) => setState(() => status = value ?? status),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(onPressed: () => _showStudentForm(context), icon: const Icon(Icons.person_add_alt), label: const Text('إضافة طالب')),
          ],
        ),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          const AppCard(child: Text('لا توجد نتائج.'))
        else
          ResponsiveGrid(
            children: filtered.map((student) {
              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        StudentAvatar(student: student),
                        const SizedBox(width: 10),
                        Expanded(child: Text(student.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                        Chip(label: Text(student.status)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('العمر: ${student.age}'),
                    Text('التشخيص: ${student.diagnosis}'),
                    Text('ولي الأمر: ${student.parentName} - ${student.parentPhone}'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton.tonalIcon(onPressed: () => app.selectStudent(student), icon: const Icon(Icons.check), label: const Text('اختيار')),
                        FilledButton.tonalIcon(onPressed: () => _showStudentForm(context, student: student), icon: const Icon(Icons.edit), label: const Text('تعديل')),
                        FilledButton.tonalIcon(onPressed: () => app.printCredentials(student), icon: const Icon(Icons.print), label: const Text('ورقة الدخول')),
                        IconButton(onPressed: () => app.deleteStudent(student.id), icon: const Icon(Icons.delete_outline)),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Future<void> _showStudentForm(BuildContext context, {Student? student}) async {
    final app = context.read<AppProvider>();
    final name = TextEditingController(text: student?.name ?? '');
    final age = TextEditingController(text: student?.age.toString() ?? '');
    final diagnosis = TextEditingController(text: student?.diagnosis ?? '');
    final parentName = TextEditingController(text: student?.parentName ?? '');
    final parentPhone = TextEditingController(text: student?.parentPhone ?? '');
    final notes = TextEditingController(text: student?.notes ?? '');
    String status = student?.status ?? 'نشط';
    String photoPath = student?.photoPath ?? '';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(student == null ? 'إضافة طالب' : 'تعديل طالب'),
            content: SizedBox(
              width: 620,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(width: 280, child: TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم الطالب'))),
                        SizedBox(width: 120, child: TextField(controller: age, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'العمر'))),
                        SizedBox(width: 180, child: DropdownButtonFormField<String>(initialValue: status, items: const ['نشط', 'متابعة', 'متوقف'].map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(), onChanged: (value) => setDialogState(() => status = value ?? status))),
                        SizedBox(width: 280, child: TextField(controller: diagnosis, decoration: const InputDecoration(labelText: 'التشخيص'))),
                        SizedBox(width: 280, child: TextField(controller: parentName, decoration: const InputDecoration(labelText: 'اسم ولي الأمر'))),
                        SizedBox(width: 280, child: TextField(controller: parentPhone, decoration: const InputDecoration(labelText: 'رقم ولي الأمر'))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.image_outlined),
                      title: Text(photoPath.isEmpty ? 'لا توجد صورة' : photoPath),
                      trailing: TextButton(
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(type: FileType.image);
                          final path = result?.files.single.path;
                          if (path != null) setDialogState(() => photoPath = path);
                        },
                        child: const Text('اختيار صورة'),
                      ),
                    ),
                    TextField(controller: notes, maxLines: 3, decoration: const InputDecoration(labelText: 'ملاحظات')),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
              FilledButton(
                onPressed: () async {
                  final now = DateTime.now().millisecondsSinceEpoch;
                  final id = student?.id ?? 'student_$now';
                  final portalEmail = student?.portalEmail ?? 'student.$now@sanad.local';
                  final portalPassword = student?.portalPassword ?? 'S${now.toString().substring(7)}';
                  await runWithFeedback(context, () async {
                    if (name.text.trim().isEmpty || diagnosis.text.trim().isEmpty || parentName.text.trim().isEmpty) {
                      throw StateError('اسم الطالب والتشخيص وولي الأمر مطلوبة.');
                    }
                    final draft = Student(
                      id: id,
                      centerId: app.activeCenterId,
                      name: name.text.trim(),
                      age: int.tryParse(age.text.trim()) ?? 0,
                      status: status,
                      diagnosis: diagnosis.text.trim(),
                      parentName: parentName.text.trim(),
                      parentPhone: parentPhone.text.trim(),
                      portalEmail: portalEmail,
                      portalPassword: portalPassword,
                      photoPath: photoPath,
                      notes: notes.text.trim(),
                    );
                    await app.saveStudent(draft);
                    if (student == null) await app.printCredentials(draft);
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  });
                },
                child: const Text('حفظ'),
              ),
            ],
          );
        },
      ),
    );
  }
}
