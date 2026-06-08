import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../widgets/app_widgets.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key, this.onOpenProfile, this.onStartSession});

  final VoidCallback? onOpenProfile;
  final VoidCallback? onStartSession;

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
            ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
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
            // إضافة الطالب تتم فقط من شاشة إدخال البيانات
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800))),
                        Flexible(
                          child: Chip(label: Text(student.status,
                              maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('العمر: ${student.age}',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('التشخيص: ${student.diagnosis}',
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    Text(
                        'ولي الأمر: ${student.parentName} - ${student.parentPhone}',
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                            onPressed: () => app.selectStudent(student),
                            icon: const Icon(Icons.check),
                            label: const Text('اختيار')),
                        FilledButton.icon(
                            onPressed: () async {
                              await app.selectStudent(student);
                              widget.onOpenProfile?.call();
                            },
                            icon: const Icon(Icons.folder_shared_outlined),
                            label: const Text('فتح الملف')),
                        if (app.canRunSessions && widget.onStartSession != null)
                          FilledButton.tonalIcon(
                              onPressed: () async {
                                await app.selectStudent(student);
                                widget.onStartSession?.call();
                              },
                              icon: const Icon(Icons.play_circle_outline),
                              label: const Text('بدء جلسة')),
                        // تعديل الطالب يتم فقط من شاشة إدخال البيانات
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

}
