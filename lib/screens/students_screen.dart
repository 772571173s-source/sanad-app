import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      final matchesSearch =
          student.name.contains(query) || student.diagnosis.contains(query);
      final matchesStatus = status == 'الكل' || student.status == status;
      return matchesSearch && matchesStatus;
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
                width: 360,
                child: TextField(
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'بحث بالاسم أو التشخيص'),
                    onChanged: (value) => setState(() => query = value))),
            SizedBox(
              width: 140,
              child: DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(labelText: 'الحالة'),
                items: const ['الكل', 'نشط', 'متابعة', 'متوقف']
                    .map((item) =>
                        DropdownMenuItem(value: item, child: Text(item)))
                    .toList(),
                onChanged: (value) => setState(() => status = value ?? status),
              ),
            ),
            FilledButton.icon(
                onPressed: () => _showStudentForm(context),
                icon: const Icon(Icons.person_add_alt),
                label: const Text('إضافة طالب')),
          ],
        ),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          EmptyState(
            icon: Icons.school_outlined,
            title: app.students.isEmpty ? 'لا يوجد طلاب' : 'لا توجد نتائج',
            message: app.students.isEmpty
                ? 'أضف أول طالب في هذا المركز لتبدأ إدارة الملف والجلسات.'
                : 'جرّب تغيير البحث أو التصفية.',
          )
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
                        Expanded(
                            child: Text(student.name,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800))),
                        Chip(label: Text(student.status)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('العمر: ${student.age}'),
                    Text('التشخيص: ${student.diagnosis}'),
                    Text(
                        'ولي الأمر: ${student.parentName} - ${student.parentPhone}'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                            onPressed: () => app.selectStudent(student),
                            icon: const Icon(Icons.check),
                            label: const Text('اختيار')),
                        FilledButton.tonalIcon(
                            onPressed: () =>
                                _showStudentForm(context, student: student),
                            icon: const Icon(Icons.edit),
                            label: const Text('تعديل')),
                        if (app.canDeleteStudents)
                          IconButton(
                              onPressed: () => app.deleteStudent(student.id),
                              icon: const Icon(Icons.delete_outline)),
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

  Future<void> _showStudentForm(BuildContext context,
      {Student? student}) async {
    final app = context.read<AppProvider>();
    final name = TextEditingController(text: student?.name ?? '');
    final age = TextEditingController(text: student?.age.toString() ?? '');
    final diagnosis = TextEditingController(text: student?.diagnosis ?? '');
    final parentName = TextEditingController(text: student?.parentName ?? '');
    final parentPhone = TextEditingController(text: student?.parentPhone ?? '');
    final notes = TextEditingController(text: student?.notes ?? '');
    String status = student?.status ?? 'نشط';
    String programType = student?.programType ?? 'نطق وتخاطب';
    String photoPath = student?.photoPath ?? '';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final dialogWidth =
              MediaQuery.sizeOf(context).width.clamp(320, 720).toDouble();
          final fieldWidth = dialogWidth < 520 ? dialogWidth - 48 : 300.0;
          return AlertDialog(
            title: Text(student == null ? 'إضافة طالب' : 'تعديل طالب'),
            content: SizedBox(
              width: dialogWidth,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                            width: fieldWidth,
                            child: TextField(
                                controller: name,
                                decoration: const InputDecoration(
                                    labelText: 'اسم الطالب'))),
                        SizedBox(
                            width: 130,
                            child: TextField(
                                controller: age,
                                keyboardType: TextInputType.number,
                                decoration:
                                    const InputDecoration(labelText: 'العمر'))),
                        SizedBox(
                            width: 170,
                            child: DropdownButtonFormField<String>(
                                initialValue: status,
                                decoration:
                                    const InputDecoration(labelText: 'الحالة'),
                                items: const ['نشط', 'متابعة', 'متوقف']
                                    .map((item) => DropdownMenuItem(
                                        value: item, child: Text(item)))
                                    .toList(),
                                onChanged: (value) => setDialogState(
                                    () => status = value ?? status))),
                        SizedBox(
                            width: fieldWidth,
                            child: DropdownButtonFormField<String>(
                                initialValue: programType,
                                decoration: const InputDecoration(
                                    labelText: 'نوع البرنامج'),
                                items: const [
                                  'نطق وتخاطب',
                                  'ضعف سمع / إعاقة سمعية',
                                  'لغة إشارة',
                                  'مهارات تعليمية',
                                  'مهارات سلوكية',
                                  'أخرى'
                                ]
                                    .map((item) => DropdownMenuItem(
                                        value: item,
                                        child: Text(item,
                                            overflow: TextOverflow.ellipsis)))
                                    .toList(),
                                onChanged: (value) => setDialogState(
                                    () => programType = value ?? programType))),
                        SizedBox(
                            width: fieldWidth,
                            child: TextField(
                                controller: diagnosis,
                                decoration: const InputDecoration(
                                    labelText: 'التشخيص'))),
                        SizedBox(
                            width: fieldWidth,
                            child: TextField(
                                controller: parentName,
                                decoration: const InputDecoration(
                                    labelText: 'اسم ولي الأمر'))),
                        SizedBox(
                            width: fieldWidth,
                            child: TextField(
                                controller: parentPhone,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                    labelText: 'رقم ولي الأمر'))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.image_outlined),
                      title:
                          Text(photoPath.isEmpty ? 'لا توجد صورة' : photoPath),
                      trailing: TextButton(
                        onPressed: () async {
                          final result = await FilePicker.platform
                              .pickFiles(type: FileType.image);
                          final path = result?.files.single.path;
                          if (path != null) {
                            setDialogState(() => photoPath = path);
                          }
                        },
                        child: const Text('اختيار صورة'),
                      ),
                    ),
                    TextField(
                        controller: notes,
                        maxLines: 3,
                        decoration:
                            const InputDecoration(labelText: 'ملاحظات')),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء')),
              FilledButton(
                onPressed: () async {
                  final now = DateTime.now().millisecondsSinceEpoch;
                  final id = student?.id ?? 'student_$now';
                  final parentPhoneValue = _normalizePhone(parentPhone.text);
                  final portalEmail =
                      student?.portalEmail ?? '$parentPhoneValue@sanad.com';
                  final portalPassword =
                      student == null ? parentPhoneValue : '';
                  await runWithFeedback(context, () async {
                    if (name.text.trim().isEmpty ||
                        diagnosis.text.trim().isEmpty ||
                        parentName.text.trim().isEmpty ||
                        parentPhoneValue.isEmpty) {
                      throw StateError(
                          'اسم الطالب والتشخيص وولي الأمر ورقمه مطلوبة.');
                    }
                    final draft = Student(
                      id: id,
                      centerId: app.activeCenterId,
                      name: name.text.trim(),
                      age: int.tryParse(age.text.trim()) ?? 0,
                      status: status,
                      diagnosis: diagnosis.text.trim(),
                      programType: programType,
                      parentName: parentName.text.trim(),
                      parentPhone: parentPhone.text.trim(),
                      portalEmail: portalEmail,
                      portalPassword: portalPassword,
                      photoPath: photoPath,
                      notes: notes.text.trim(),
                    );
                    await app.saveStudent(draft);
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                    if (student == null && context.mounted) {
                      await _showCredentialsDialog(context, app, draft);
                    }
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

  String _normalizePhone(String value) => value
      .replaceAll('٠', '0')
      .replaceAll('١', '1')
      .replaceAll('٢', '2')
      .replaceAll('٣', '3')
      .replaceAll('٤', '4')
      .replaceAll('٥', '5')
      .replaceAll('٦', '6')
      .replaceAll('٧', '7')
      .replaceAll('٨', '8')
      .replaceAll('٩', '9')
      .replaceAll(RegExp(r'[^0-9]'), '');

  Future<void> _showCredentialsDialog(
      BuildContext context, AppProvider app, Student student) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('بيانات دخول ولي الأمر'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('البريد'),
            const SizedBox(height: 4),
            SelectableText(
              student.portalEmail,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.left,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const Text('كلمة المرور المؤقتة'),
            const SizedBox(height: 4),
            SelectableText(
              student.portalPassword,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.left,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إغلاق')),
          FilledButton.tonalIcon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(
                  text:
                      'البريد: ${student.portalEmail}\nكلمة المرور: ${student.portalPassword}'));
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            icon: const Icon(Icons.copy),
            label: const Text('نسخ البيانات'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await app.printCredentials(student);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            icon: const Icon(Icons.print),
            label: const Text('طباعة'),
          ),
        ],
      ),
    );
  }
}
