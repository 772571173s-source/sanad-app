import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../widgets/app_widgets.dart';
import '../widgets/feedback.dart';

class ExercisesParentScreen extends StatefulWidget {
  const ExercisesParentScreen({super.key});

  @override
  State<ExercisesParentScreen> createState() => _ExercisesParentScreenState();
}

class _ExercisesParentScreenState extends State<ExercisesParentScreen> {
  final title = TextEditingController();
  final instructions = TextEditingController();

  @override
  void dispose() {
    title.dispose();
    instructions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final student = app.selectedStudent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (app.isParent && app.students.length > 1)
          AppCard(
            child: DropdownButtonFormField<String>(
              initialValue: student?.id,
              decoration: const InputDecoration(labelText: 'اختر الطفل'),
              items: app.students
                  .map((item) => DropdownMenuItem<String>(
                        value: item.id,
                        child: Text(item.name),
                      ))
                  .toList(),
              onChanged: (value) {
                Student? selected;
                for (final item in app.students) {
                  if (item.id == value) {
                    selected = item;
                    break;
                  }
                }
                app.selectStudent(selected);
              },
            ),
          ),
        if (!app.isParent)
          AppCard(
            child: student == null
                ? const Text('اختر طالبًا أولًا.')
                : Column(
                    children: [
                      TextField(
                        controller: title,
                        decoration:
                            const InputDecoration(labelText: 'عنوان الواجب'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: instructions,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                            labelText: 'تعليمات واضحة لولي الأمر'),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: () => _addExercise(app),
                          icon: const Icon(Icons.assignment_add),
                          label: const Text('إرسال واجب'),
                        ),
                      ),
                    ],
                  ),
          ),
        const SizedBox(height: 16),
        if (app.exercises.isEmpty)
          const AppCard(child: Text('لا توجد واجبات بعد.'))
        else
          ResponsiveGrid(
            children: app.exercises.map((exercise) {
              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.home_work_outlined),
                      title: Text(exercise.title),
                      subtitle: Text(
                          '${exercise.instructions}\nتاريخ التسليم: ${exercise.dueDate}'),
                      trailing: Chip(label: Text(exercise.status)),
                    ),
                    if (exercise.audioPath.isNotEmpty)
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          exercise.audioPath,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.left,
                        ),
                      ),
                    if (exercise.parentNote.isNotEmpty)
                      Text('ملاحظة ولي الأمر: ${exercise.parentNote}'),
                    Text('النجوم: ${exercise.stars}'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (app.isParent)
                          FilledButton.icon(
                            onPressed: () => _markDone(app, exercise),
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('تم الإنجاز'),
                          ),
                        FilledButton.tonalIcon(
                          onPressed: () =>
                              _addParentNote(context, app, exercise),
                          icon: const Icon(Icons.note_add_outlined),
                          label: const Text('ملاحظة للأخصائي'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () => _uploadAudio(app, exercise),
                          icon: const Icon(Icons.mic),
                          label: const Text('رفع/تسجيل صوت لاحقًا'),
                        ),
                        if (!app.isParent)
                          FilledButton.tonalIcon(
                            onPressed: () => _approve(app, exercise),
                            icon: const Icon(Icons.done_all),
                            label: const Text('اعتماد'),
                          ),
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

  Future<void> _addExercise(AppProvider app) async {
    final student = app.selectedStudent;
    if (student == null || title.text.trim().isEmpty) return;
    await runWithFeedback(context, () async {
      await app.saveExercise(
        Exercise(
          id: 'exercise_${DateTime.now().millisecondsSinceEpoch}',
          centerId: student.centerId,
          studentId: student.id,
          title: title.text.trim(),
          instructions: instructions.text.trim(),
          dueDate: DateTime.now()
              .add(const Duration(days: 1))
              .toIso8601String()
              .split('T')
              .first,
          status: 'مرسل',
        ),
      );
      title.clear();
      instructions.clear();
    }, success: 'تم إرسال الواجب.');
  }

  Future<void> _uploadAudio(AppProvider app, Exercise exercise) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    final path = result?.files.single.path;
    if (path == null) return;
    if (!mounted) return;
    await runWithFeedback(
      context,
      () => app.saveExercise(_copyExercise(
        exercise,
        status: 'بانتظار المراجعة',
        audioPath: path,
        stars: exercise.stars + 1,
      )),
      success: 'تم رفع التسجيل.',
    );
  }

  Future<void> _addParentNote(
      BuildContext context, AppProvider app, Exercise exercise) async {
    final note = TextEditingController(text: exercise.parentNote);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ملاحظة للأخصائي'),
        content: TextField(
          controller: note,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'اكتب الملاحظة'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () async {
              await app.saveExercise(
                _copyExercise(exercise, parentNote: note.text.trim()),
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _markDone(AppProvider app, Exercise exercise) {
    return runWithFeedback(
      context,
      () => app.saveExercise(_copyExercise(
        exercise,
        status: 'مكتمل',
        stars: exercise.stars + 1,
      )),
      success: 'تم تسجيل إنجاز الواجب.',
    );
  }

  Future<void> _approve(AppProvider app, Exercise exercise) {
    return runWithFeedback(
      context,
      () => app.saveExercise(_copyExercise(exercise, status: 'معتمد')),
      success: 'تم اعتماد الواجب.',
    );
  }

  Exercise _copyExercise(
    Exercise exercise, {
    String? status,
    String? audioPath,
    String? parentNote,
    int? stars,
  }) {
    return Exercise(
      id: exercise.id,
      centerId: exercise.centerId,
      studentId: exercise.studentId,
      title: exercise.title,
      instructions: exercise.instructions,
      dueDate: exercise.dueDate,
      status: status ?? exercise.status,
      audioPath: audioPath ?? exercise.audioPath,
      parentNote: parentNote ?? exercise.parentNote,
      stars: stars ?? exercise.stars,
      createdAt: exercise.createdAt,
      updatedAt: DateTime.now().toIso8601String(),
    );
  }
}
