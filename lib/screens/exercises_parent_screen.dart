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
        if (!app.isParent)
          AppCard(
            child: student == null
                ? const Text('اختر طالبًا أولًا.')
                : Column(
                    children: [
                      TextField(
                          controller: title,
                          decoration: const InputDecoration(
                              labelText: 'عنوان الواجب اليومي')),
                      const SizedBox(height: 10),
                      TextField(
                          controller: instructions,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                              labelText: 'تعليمات الأهل')),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                            onPressed: () => _addExercise(app),
                            icon: const Icon(Icons.assignment_add),
                            label: const Text('إرسال واجب')),
                      ),
                    ],
                  ),
          ),
        const SizedBox(height: 16),
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
                    Text('تسجيل مرفوع: ${exercise.audioPath}',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (exercise.parentNote.isNotEmpty)
                    Text('ملاحظة ولي الأمر: ${exercise.parentNote}'),
                  Text('النجوم: ${exercise.stars}'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                          onPressed: () =>
                              _addParentNote(context, app, exercise),
                          icon: const Icon(Icons.note_add_outlined),
                          label: const Text('ملاحظة ولي الأمر')),
                      FilledButton.tonalIcon(
                          onPressed: () => _uploadAudio(app, exercise),
                          icon: const Icon(Icons.mic),
                          label: const Text('رفع تسجيل')),
                      if (!app.isParent)
                        FilledButton.tonalIcon(
                            onPressed: () => _markDone(app, exercise),
                            icon: const Icon(Icons.done_all),
                            label: const Text('اعتماد')),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        if (app.exercises.isEmpty)
          const AppCard(child: Text('لا توجد واجبات بعد.')),
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
    });
  }

  Future<void> _uploadAudio(AppProvider app, Exercise exercise) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    final path = result?.files.single.path;
    if (path == null) return;
    await app.saveExercise(
      Exercise(
        id: exercise.id,
        centerId: exercise.centerId,
        studentId: exercise.studentId,
        title: exercise.title,
        instructions: exercise.instructions,
        dueDate: exercise.dueDate,
        status: 'بانتظار المراجعة',
        audioPath: path,
        parentNote: exercise.parentNote,
        stars: exercise.stars + 1,
      ),
    );
  }

  Future<void> _addParentNote(
      BuildContext context, AppProvider app, Exercise exercise) async {
    final note = TextEditingController(text: exercise.parentNote);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ملاحظة ولي الأمر'),
        content: TextField(
            controller: note,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'الملاحظة')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              await app.saveExercise(
                Exercise(
                  id: exercise.id,
                  centerId: exercise.centerId,
                  studentId: exercise.studentId,
                  title: exercise.title,
                  instructions: exercise.instructions,
                  dueDate: exercise.dueDate,
                  status: exercise.status,
                  audioPath: exercise.audioPath,
                  parentNote: note.text.trim(),
                  stars: exercise.stars,
                ),
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
    return app.saveExercise(
      Exercise(
        id: exercise.id,
        centerId: exercise.centerId,
        studentId: exercise.studentId,
        title: exercise.title,
        instructions: exercise.instructions,
        dueDate: exercise.dueDate,
        status: 'مكتمل',
        audioPath: exercise.audioPath,
        parentNote: exercise.parentNote,
        stars: exercise.stars,
      ),
    );
  }
}
