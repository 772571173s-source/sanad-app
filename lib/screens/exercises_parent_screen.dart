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
                  if (item.id == value) selected = item;
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
          const EmptyState(
            icon: Icons.assignment_outlined,
            title: 'لا توجد واجبات بعد',
            message: 'ستظهر هنا الواجبات المرسلة من الأخصائي بشكل مبسط.',
          )
        else
          ResponsiveGrid(
            children: app.exercises
                .map((exercise) => _HomeworkCard(
                      app: app,
                      exercise: exercise,
                      studentName: student?.name,
                      onOpen: () => _openHomeworkFlow(app, exercise),
                      onNote: () => _addParentNote(context, app, exercise),
                      onUpload: () => _uploadAudio(app, exercise),
                      onApprove:
                          app.isParent ? null : () => _approve(app, exercise),
                    ))
                .toList(),
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
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final current = activities[index];
            return AlertDialog(
              title: Text(_cleanTitle(exercise.title)),
              contentPadding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
              content: SizedBox(
                width: 640,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text(
                            'نشاط ${index + 1} من ${activities.length}',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const Spacer(),
                          Chip(label: Text(current.typeLabel)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _HomeworkActivityView(step: current),
                      const SizedBox(height: 16),
                      _StatusSelector(
                        selected: status,
                        onChanged: (value) =>
                            setDialogState(() => status = value),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: note,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظة اختيارية للأخصائي',
                          hintText: 'مثال: كرر الطفل النشاط لكنه احتاج مساعدة.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      index == 0 ? null : () => setDialogState(() => index--),
                  child: const Text('السابق'),
                ),
                TextButton(
                  onPressed: index >= activities.length - 1
                      ? null
                      : () => setDialogState(() => index++),
                  child: const Text('التالي'),
                ),
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
      ),
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

class _HomeworkCard extends StatelessWidget {
  const _HomeworkCard({
    required this.app,
    required this.exercise,
    required this.onOpen,
    required this.onNote,
    required this.onUpload,
    required this.studentName,
    this.onApprove,
  });

  final AppProvider app;
  final Exercise exercise;
  final String? studentName;
  final VoidCallback onOpen;
  final VoidCallback onNote;
  final VoidCallback onUpload;
  final VoidCallback? onApprove;

  @override
  Widget build(BuildContext context) {
    final parts = exercise.title.split(' - ');
    final programName = parts.length > 1 ? parts.first : 'برنامج علاجي';
    final activityName =
        parts.length > 1 ? parts.sublist(1).join(' - ') : exercise.title;
    final activities = _homeworkActivities(exercise.instructions);
    final summary = _homeworkSummary(exercise.instructions);

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
                    if (studentName != null)
                      Text(
                        studentName!,
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
                    Text(activityName,
                        style: Theme.of(context).textTheme.bodyLarge),
                  ],
                ),
              ),
              Chip(label: Text(exercise.status)),
            ],
          ),
          const SizedBox(height: 12),
          _HomeworkPreview(summary: summary, activities: activities),
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
              height: 54,
              child: FilledButton.icon(
                onPressed: onOpen,
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
                onPressed: onNote,
                icon: const Icon(Icons.note_add_outlined),
                label: const Text('ملاحظة للأخصائي'),
              ),
              FilledButton.tonalIcon(
                onPressed: onUpload,
                icon: const Icon(Icons.mic),
                label: const Text('رفع صوت/فيديو لاحقًا'),
              ),
              if (onApprove != null)
                FilledButton.tonalIcon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.done_all),
                  label: const Text('اعتماد'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HomeworkPreview extends StatelessWidget {
  const _HomeworkPreview({required this.summary, required this.activities});

  final String summary;
  final List<_HomeworkStep> activities;

  @override
  Widget build(BuildContext context) {
    final visible = activities.take(3).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'محتوى الواجب',
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(summary),
          if (visible.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in visible)
                  Chip(
                      label: Text(
                          '${item.typeLabel}: ${_cleanTitle(item.title)}')),
                if (activities.length > visible.length)
                  Chip(label: Text('+${activities.length - visible.length}')),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HomeworkActivityView extends StatelessWidget {
  const _HomeworkActivityView({required this.step});

  final _HomeworkStep step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (step.kind == 'error') {
      return _homeworkPanel(
        context,
        color: theme.colorScheme.errorContainer,
        child: Column(
          children: [
            Icon(Icons.info_outline, color: theme.colorScheme.onErrorContainer),
            const SizedBox(height: 8),
            Text(
              'تعذر عرض تفاصيل هذا الواجب بشكل آمن.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'يرجى طلب إعادة إرسال الواجب من الأخصائي.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
          ],
        ),
      );
    }
    if (step.kind == 'speechLetter') {
      return _homeworkPanel(
        context,
        child: Column(
          children: [
            Text(
              step.letterDisplay.isEmpty ? step.letter : step.letterDisplay,
              textAlign: TextAlign.center,
              style: theme.textTheme.displayLarge?.copyWith(
                fontSize: 92,
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.primary,
                height: 1,
              ),
            ),
            if (step.vocalization.isNotEmpty) ...[
              const SizedBox(height: 8),
              Chip(
                avatar: const Icon(Icons.record_voice_over_outlined, size: 18),
                label: Text(step.vocalization),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: null,
              icon: const Icon(Icons.volume_up_outlined),
              label: const Text('تشغيل النطق لاحقًا'),
            ),
            const SizedBox(height: 16),
            Text(
              _safeText(step.homework, fallback: step.instructions),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      );
    }
    if (step.kind == 'speechWord') {
      return _homeworkPanel(
        context,
        title: 'كلمات ${step.letter} - ${step.position}',
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: step.words
              .map((word) => Container(
                    constraints: const BoxConstraints(minWidth: 96),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      border:
                          Border.all(color: theme.colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      word,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ))
              .toList(),
        ),
      );
    }
    if (step.kind == 'speechSentence') {
      return _homeworkPanel(
        context,
        title: 'الجملة',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: step.sentences
              .map((sentence) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      sentence,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.5,
                      ),
                    ),
                  ))
              .toList(),
        ),
      );
    }
    return _homeworkPanel(
      context,
      title: step.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            _simpleSteps(_safeText(step.homework, fallback: step.instructions))
                .map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(line, style: theme.textTheme.titleMedium),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
      ),
    );
  }

  Widget _homeworkPanel(
    BuildContext context, {
    String? title,
    required Widget child,
    Color? color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title?.isNotEmpty == true) ...[
            Text(
              title!,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

class _StatusSelector extends StatelessWidget {
  const _StatusSelector({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = ['تم الإنجاز', 'يحتاج مساعدة', 'لم ينجز'];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((option) {
        final active = option == selected;
        return SizedBox(
          height: 48,
          child: active
              ? FilledButton(
                  onPressed: () => onChanged(option),
                  child: Text(option),
                )
              : FilledButton.tonal(
                  onPressed: () => onChanged(option),
                  child: Text(option),
                ),
        );
      }).toList(),
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

  String get typeLabel {
    return switch (kind) {
      'speechLetter' => 'حرف',
      'speechWord' => 'كلمات',
      'speechSentence' => 'جملة',
      'oralMotor' => 'تمرين فموي',
      'auditoryDiscrimination' => 'تمييز سمعي',
      'sensoryActivity' => 'نشاط حسي',
      'error' => 'تنبيه',
      _ => 'نشاط',
    };
  }

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

List<_HomeworkStep> _homeworkActivities(String instructions) {
  final trimmed = instructions.trim();
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is Map<String, dynamic> &&
        decoded['kind'] == 'sessionHomework' &&
        decoded['activities'] is List) {
      final activities = (decoded['activities'] as List)
          .whereType<Map>()
          .map((item) => _HomeworkStep.fromJson(
              item.map((key, value) => MapEntry('$key', value))))
          .where((item) =>
              item.kind != 'other' ||
              _safeText(item.homework, fallback: item.instructions).isNotEmpty)
          .toList();
      if (activities.isNotEmpty) return activities;
    }
  } catch (_) {
    if (_looksLikeJson(trimmed)) {
      return const [
        _HomeworkStep(
          title: 'تعذر عرض الواجب',
          kind: 'error',
          instructions: 'يرجى إعادة إرسال الواجب من الأخصائي.',
        ),
      ];
    }
  }
  final lines = trimmed
      .split('\n')
      .map((line) => line.trim().replaceFirst(RegExp(r'^\d+\.\s*'), ''))
      .where((line) => line.isNotEmpty && !_looksLikeJson(line))
      .toList();
  return (lines.isEmpty ? const ['واجب منزلي بدون تفاصيل.'] : lines)
      .map((line) => _HomeworkStep(
            title: 'نشاط منزلي',
            kind: 'other',
            instructions: line,
            homework: line,
          ))
      .toList();
}

String _homeworkSummary(String instructions) {
  final steps = _homeworkActivities(instructions);
  if (steps.length == 1 && steps.first.kind == 'error') {
    return 'تعذر عرض تفاصيل الواجب. يرجى طلب إعادة إرساله من الأخصائي.';
  }
  if (steps.length > 1) return 'واجب جلسة يحتوي ${steps.length} أنشطة علاجية.';
  final text =
      _safeText(steps.first.homework, fallback: steps.first.instructions);
  if (text.isEmpty) return 'واجب منزلي جاهز للتنفيذ.';
  return text.length > 90 ? '${text.substring(0, 90)}...' : text;
}

String _cleanTitle(String value) {
  if (_looksLikeJson(value)) return 'واجب منزلي';
  return value.trim().isEmpty ? 'واجب منزلي' : value.trim();
}

String _safeText(String value, {String fallback = ''}) {
  final preferred = value.trim().isEmpty ? fallback.trim() : value.trim();
  if (_looksLikeJson(preferred)) return '';
  return preferred;
}

bool _looksLikeJson(String value) {
  final trimmed = value.trimLeft();
  return trimmed.startsWith('{') || trimmed.startsWith('[');
}

List<String> _simpleSteps(String text) {
  final parts = text
      .split(RegExp(r'[\n.،؛]+'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  return parts.isEmpty ? ['اتبع تعليمات الأخصائي بهدوء.'] : parts;
}
