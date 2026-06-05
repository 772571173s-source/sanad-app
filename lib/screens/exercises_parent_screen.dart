import 'dart:convert';

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
        if (student != null)
          AppCard(
            child: ListTile(
              leading: const Icon(Icons.child_care_outlined),
              title: Text(student.name),
              subtitle: Text('الواجبات الحالية: ${app.exercises.length}'),
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
              final parts = exercise.title.split(' - ');
              final programName =
                  parts.length > 1 ? parts.first : 'برنامج علاجي';
              final activityName = parts.length > 1
                  ? parts.sublist(1).join(' - ')
                  : exercise.title;
              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.home_work_outlined),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (student != null)
                                Text(
                                  student.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                              Text(
                                programName,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                activityName,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ],
                          ),
                        ),
                        Chip(label: Text(exercise.status)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color:
                                Theme.of(context).colorScheme.outlineVariant),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'التعليمات',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 6),
                          Text(exercise.instructions),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('تاريخ التسليم: ${exercise.dueDate}'),
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
                    const SizedBox(height: 10),
                    const Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          avatar: Icon(Icons.volume_up_outlined, size: 18),
                          label: Text('تشغيل الصوت لاحقًا'),
                        ),
                        Chip(
                          avatar: Icon(Icons.video_call_outlined, size: 18),
                          label: Text('رفع فيديو لاحقًا'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (app.isParent)
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: () => _openHomeworkFlow(app, exercise),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('فتح الواجب'),
                        ),
                      ),
                    if (app.isParent) const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: () =>
                              _addParentNote(context, app, exercise),
                          icon: const Icon(Icons.note_add_outlined),
                          label: const Text('ملاحظة للأخصائي'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () => _uploadAudio(app, exercise),
                          icon: const Icon(Icons.mic),
                          label: const Text('رفع صوت/فيديو لاحقًا'),
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
    final result = await FilePicker.platform.pickFiles(type: FileType.media);
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
      success: 'تم رفع الملف.',
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

  Future<void> _openHomeworkFlow(AppProvider app, Exercise exercise) async {
    final activities = _homeworkActivities(exercise.instructions);
    var index = 0;
    var status = 'تم الإنجاز';
    final note = TextEditingController(text: exercise.parentNote);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final current = activities[index];
          return AlertDialog(
            title: Text(exercise.title),
            content: SizedBox(
              width: 560,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('نشاط ${index + 1} من ${activities.length}',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  _HomeworkActivityView(step: current),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                          value: 'تم الإنجاز', label: Text('تم الإنجاز')),
                      ButtonSegment(
                          value: 'يحتاج مساعدة', label: Text('يحتاج مساعدة')),
                      ButtonSegment(value: 'لم ينجز', label: Text('لم ينجز')),
                    ],
                    selected: {status},
                    onSelectionChanged: (value) =>
                        setDialogState(() => status = value.first),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: note,
                    maxLines: 3,
                    decoration:
                        const InputDecoration(labelText: 'ملاحظة اختيارية'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed:
                      index == 0 ? null : () => setDialogState(() => index--),
                  child: const Text('السابق')),
              TextButton(
                  onPressed: index >= activities.length - 1
                      ? null
                      : () => setDialogState(() => index++),
                  child: const Text('التالي')),
              FilledButton(
                onPressed: () async {
                  await app.saveExercise(_copyExercise(
                    exercise,
                    status: status,
                    parentNote: note.text.trim(),
                    stars: status == 'تم الإنجاز'
                        ? exercise.stars + 1
                        : exercise.stars,
                  ));
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                },
                child: const Text('حفظ الواجب'),
              ),
            ],
          );
        },
      ),
    );
  }

  List<_HomeworkStep> _homeworkActivities(String instructions) {
    try {
      final json = jsonDecode(instructions);
      if (json is Map<String, dynamic> &&
          json['kind'] == 'sessionHomework' &&
          json['activities'] is List) {
        return (json['activities'] as List)
            .whereType<Map>()
            .map((item) => _HomeworkStep.fromJson(
                item.map((key, value) => MapEntry('$key', value))))
            .toList();
      }
    } catch (_) {}
    final lines = instructions
        .split('\n')
        .map((line) => line.trim().replaceFirst(RegExp(r'^\d+\.\s*'), ''))
        .where((line) => line.isNotEmpty)
        .toList();
    return (lines.isEmpty ? [instructions] : lines)
        .map((line) => _HomeworkStep(
              title: 'نشاط منزلي',
              kind: 'other',
              instructions: line,
              homework: line,
            ))
        .toList();
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

class _HomeworkActivityView extends StatelessWidget {
  const _HomeworkActivityView({required this.step});

  final _HomeworkStep step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (step.kind == 'speechLetter') {
      return _homeworkPanel(
        context,
        child: Column(
          children: [
            Text(
              step.letterDisplay.isEmpty ? step.letter : step.letterDisplay,
              textAlign: TextAlign.center,
              style: theme.textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.primary,
              ),
            ),
            if (step.vocalization.isNotEmpty)
              Chip(label: Text(step.vocalization)),
            const SizedBox(height: 12),
            Text(step.homework, textAlign: TextAlign.center),
          ],
        ),
      );
    }
    if (step.kind == 'speechWord') {
      return _homeworkPanel(
        context,
        title: '${step.letter} - ${step.position}',
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: step.words
              .map((word) => Chip(
                    label: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Text(word,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                  ))
              .toList(),
        ),
      );
    }
    if (step.kind == 'speechSentence') {
      return _homeworkPanel(
        context,
        title: 'الجمل',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: step.sentences
              .map((sentence) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(sentence,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800)),
                  ))
              .toList(),
        ),
      );
    }
    return _homeworkPanel(
      context,
      title: step.title,
      child: Text(step.homework.isEmpty ? step.instructions : step.homework,
          style: theme.textTheme.titleMedium),
    );
  }

  Widget _homeworkPanel(BuildContext context,
      {String? title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title?.isNotEmpty == true) ...[
            Text(title!,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

class _HomeworkStep {
  const _HomeworkStep({
    required this.title,
    required this.kind,
    this.homework = '',
    this.instructions = '',
    this.letter = '',
    this.letterDisplay = '',
    this.vocalization = '',
    this.position = '',
    this.words = const [],
    this.sentences = const [],
  });

  final String title;
  final String kind;
  final String homework;
  final String instructions;
  final String letter;
  final String letterDisplay;
  final String vocalization;
  final String position;
  final List<String> words;
  final List<String> sentences;

  factory _HomeworkStep.fromJson(Map<String, Object?> json) => _HomeworkStep(
        title: json['title'] as String? ?? 'نشاط منزلي',
        kind: json['kind'] as String? ?? 'other',
        homework: json['homework'] as String? ?? '',
        instructions: json['instructions'] as String? ?? '',
        letter: json['letter'] as String? ?? '',
        letterDisplay: json['letterDisplay'] as String? ?? '',
        vocalization: json['vocalization'] as String? ?? '',
        position: json['position'] as String? ?? '',
        words: _list(json['words']),
        sentences: _list(json['sentences']),
      );

  static List<String> _list(Object? value) {
    if (value is List) return value.map((item) => '$item').toList();
    return const [];
  }
}
