import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../widgets/app_widgets.dart';
import '../widgets/feedback.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  Timer? timer;
  int seconds = 0;
  String? programId;
  bool sessionStarted = false;
  int activityIndex = 0;
  int homeworkSentCount = 0;
  final selectedActivityIds = <String>{};
  final activityResults = <String, String>{};
  final notes = TextEditingController();

  @override
  void dispose() {
    timer?.cancel();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final student = app.selectedStudent;
    final program = _program(app);
    final sections = program == null
        ? <ProgramSection>[]
        : app.programSections
            .where((section) => section.programId == program.id)
            .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final programSkills = program == null
        ? <ProgramSkill>[]
        : app.programSkills
            .where((skill) => skill.programId == program.id)
            .toList();
    final libraryActivities = program == null
        ? <ProgramActivity>[]
        : app.programActivities
            .where((activity) => activity.programId == program.id)
            .toList()
      ..sort(_compareActivities);
    final activities = libraryActivities
        .where((activity) => selectedActivityIds.contains(activity.id))
        .toList();
    if (activityIndex >= activities.length) activityIndex = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!sessionStarted) ...[
          _SetupCard(
            title: 'اختيار سريع للجلسة',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: student?.id,
                  decoration: const InputDecoration(labelText: 'الطالب'),
                  items: app.students
                      .map((item) => DropdownMenuItem(
                          value: item.id,
                          child:
                              Text(item.name, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (value) async {
                    final matches =
                        app.students.where((item) => item.id == value).toList();
                    await app
                        .selectStudent(matches.isEmpty ? null : matches.first);
                    setState(_resetSelectionAfterStudent);
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: programId,
                  decoration:
                      const InputDecoration(labelText: 'البرنامج العلاجي'),
                  items: app.programs
                      .map((item) => DropdownMenuItem(
                          value: item.id,
                          child:
                              Text(item.name, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: student == null
                      ? null
                      : (value) => setState(() {
                            programId = value;
                            activityIndex = 0;
                            selectedActivityIds.clear();
                            activityResults.clear();
                          }),
                ),
                const SizedBox(height: 10),
                if (program == null)
                  const Text('اختر الطالب والبرنامج أولًا.')
                else
                  _ActivityLibraryPicker(
                    sections: sections,
                    skills: programSkills,
                    activities: libraryActivities,
                    selectedActivityIds: selectedActivityIds,
                    onChanged: (activityId, selected) {
                      setState(() {
                        if (selected) {
                          selectedActivityIds.add(activityId);
                        } else {
                          selectedActivityIds.remove(activityId);
                          activityResults.remove(activityId);
                        }
                        activityIndex = 0;
                      });
                    },
                  ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed:
                        activities.isEmpty ? null : () => _startSession(),
                    icon: const Icon(Icons.play_arrow),
                    label: Text('ابدأ الجلسة (${activities.length})'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _PreviousSessions(app: app),
        ] else ...[
          _ActiveSessionCard(
            activity: activities[activityIndex],
            index: activityIndex,
            total: activities.length,
            selectedValue: activityResults[activities[activityIndex].id],
            options: _options(activities[activityIndex]),
            elapsedSeconds: seconds,
            successRate: _successRate(activities),
            homeworkSentCount: homeworkSentCount,
            notes: notes,
            onEvaluate: (value) => setState(
                () => activityResults[activities[activityIndex].id] = value),
            onPrevious: activityIndex == 0
                ? null
                : () => setState(() => activityIndex--),
            onNext: activityIndex >= activities.length - 1
                ? null
                : () => setState(() => activityIndex++),
            onSendHomework: () => _sendHomework(app, activities[activityIndex]),
            onSave: () => _saveSession(app, activities),
            onStop: () => setState(() {
              sessionStarted = false;
              timer?.cancel();
            }),
          ),
        ],
      ],
    );
  }

  void _resetSelectionAfterStudent() {
    programId = null;
    activityIndex = 0;
    selectedActivityIds.clear();
    activityResults.clear();
    sessionStarted = false;
  }

  void _startSession() {
    setState(() {
      sessionStarted = true;
      activityIndex = 0;
      homeworkSentCount = 0;
      seconds = 0;
    });
    _startTimer();
  }

  TherapyProgram? _program(AppProvider app) {
    if (programId == null) return null;
    for (final program in app.programs) {
      if (program.id == programId) return program;
    }
    return null;
  }

  List<String> _options(ProgramActivity activity) {
    if (activity.evaluationType == 'sensory') {
      return const ['لا يؤدي', 'بمساعدة', 'جيد'];
    }
    return const ['صحيح', 'جزئي', 'خطأ'];
  }

  void _startTimer() {
    timer?.cancel();
    timer = Timer.periodic(
        const Duration(seconds: 1), (_) => setState(() => seconds++));
  }

  int _successRate(List<ProgramActivity> activities) {
    if (activities.isEmpty) return 0;
    var score = 0.0;
    for (final activity in activities) {
      final value = activityResults[activity.id];
      if (value == null) continue;
      if (value == 'صحيح' || value == 'جيد') score += 1;
      if (value == 'جزئي' || value == 'بمساعدة') score += .5;
    }
    return ((score / activities.length) * 100).round();
  }

  Future<void> _sendHomework(AppProvider app, ProgramActivity activity) {
    final student = app.selectedStudent;
    final program = _program(app);
    final content = _StructuredActivityContent.tryParse(activity);
    final homework = content?.homework ?? activity.homework;
    if (student == null || homework.isEmpty) return Future.value();
    return runWithFeedback(context, () async {
      await app.saveExercise(Exercise(
        id: 'exercise_${DateTime.now().millisecondsSinceEpoch}',
        centerId: student.centerId,
        studentId: student.id,
        title: '${program?.name ?? 'برنامج علاجي'} - ${activity.title}',
        instructions: homework,
        dueDate: DateTime.now()
            .add(const Duration(days: 1))
            .toIso8601String()
            .split('T')
            .first,
        status: 'مرسل',
      ));
      setState(() => homeworkSentCount++);
    }, success: 'تم إرسال الواجب لولي الأمر.');
  }

  Future<void> _saveSession(AppProvider app, List<ProgramActivity> activities) {
    final student = app.selectedStudent;
    final program = _program(app);
    final firstActivity = activities.isEmpty ? null : activities.first;
    final skill = firstActivity == null
        ? null
        : _findSkill(app.programSkills, firstActivity.skillId);
    return runWithFeedback(context, () async {
      if (student == null || program == null || skill == null) {
        throw StateError('اختر الطالب والبرنامج والأنشطة أولًا.');
      }
      if (activityResults.isEmpty) {
        throw StateError('قيّم نشاطًا واحدًا على الأقل قبل حفظ الجلسة.');
      }
      await app.saveSession(TherapySession(
        id: 'session_${DateTime.now().millisecondsSinceEpoch}',
        centerId: student.centerId,
        studentId: student.id,
        programId: program.id,
        skillId: skill.id,
        activityResults: activityResults.entries
            .map((entry) => '${entry.key}:${entry.value}')
            .join('|'),
        sessionType: program.type,
        practiceItems: activities.map((activity) => activity.title).join('، '),
        attempts: activityResults.length,
        successRate: _successRate(activities),
        startedAt: DateTime.now().toIso8601String(),
        durationSeconds: seconds,
        cardTitle: skill.title,
        quickResult: firstActivity == null
            ? activityResults.values.first
            : activityResults[firstActivity.id] ?? activityResults.values.first,
        notes: notes.text.trim(),
        summary:
            'تم تقييم ${activityResults.length} من ${activities.length} نشاط، بنسبة نجاح ${_successRate(activities)}%. الواجبات المرسلة: $homeworkSentCount.',
      ));
      timer?.cancel();
      setState(() {
        sessionStarted = false;
        seconds = 0;
        activityIndex = 0;
        activityResults.clear();
        homeworkSentCount = 0;
        notes.clear();
      });
    }, success: 'تم حفظ الجلسة.');
  }

  ProgramSkill? _findSkill(List<ProgramSkill> skills, String id) {
    for (final skill in skills) {
      if (skill.id == id) return skill;
    }
    return null;
  }

  int _compareActivities(ProgramActivity a, ProgramActivity b) {
    final aContent = _StructuredActivityContent.tryParse(a);
    final bContent = _StructuredActivityContent.tryParse(b);
    final aOrder = aContent?.sortOrder ?? 0;
    final bOrder = bContent?.sortOrder ?? 0;
    if (aOrder != bOrder) return aOrder.compareTo(bOrder);
    return a.title.compareTo(b.title);
  }
}

class _ActivityLibraryPicker extends StatelessWidget {
  const _ActivityLibraryPicker({
    required this.sections,
    required this.skills,
    required this.activities,
    required this.selectedActivityIds,
    required this.onChanged,
  });

  final List<ProgramSection> sections;
  final List<ProgramSkill> skills;
  final List<ProgramActivity> activities;
  final Set<String> selectedActivityIds;
  final void Function(String activityId, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return const EmptyState(
        icon: Icons.library_books_outlined,
        title: 'لا توجد أنشطة في البرنامج',
        message: 'أضف أنشطة من شاشة البرامج أو أعد إنشاء البرامج الأساسية.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('اختر أنشطة من مكتبة البرنامج',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        ...sections.map((section) {
          final sectionSkills =
              skills.where((skill) => skill.sectionId == section.id).toList();
          return ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(section.title),
            children: sectionSkills.map((skill) {
              final skillActivities = activities
                  .where((activity) => activity.skillId == skill.id)
                  .toList();
              if (skillActivities.isEmpty) return const SizedBox.shrink();
              return ExpansionTile(
                tilePadding: const EdgeInsetsDirectional.only(start: 12),
                title: Text(skill.title),
                children: skillActivities.map((activity) {
                  final content = _StructuredActivityContent.tryParse(activity);
                  return CheckboxListTile(
                    value: selectedActivityIds.contains(activity.id),
                    onChanged: (value) =>
                        onChanged(activity.id, value ?? false),
                    title: Text(activity.title),
                    subtitle: Text(content?.summary ?? activity.instructions),
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                }).toList(),
              );
            }).toList(),
          );
        }),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Chip(label: Text('المحدد: ${selectedActivityIds.length}')),
        ),
      ],
    );
  }
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ActiveSessionCard extends StatelessWidget {
  const _ActiveSessionCard({
    required this.activity,
    required this.index,
    required this.total,
    required this.selectedValue,
    required this.options,
    required this.elapsedSeconds,
    required this.successRate,
    required this.homeworkSentCount,
    required this.notes,
    required this.onEvaluate,
    required this.onPrevious,
    required this.onNext,
    required this.onSendHomework,
    required this.onSave,
    required this.onStop,
  });

  final ProgramActivity activity;
  final int index;
  final int total;
  final String? selectedValue;
  final List<String> options;
  final int elapsedSeconds;
  final int successRate;
  final int homeworkSentCount;
  final TextEditingController notes;
  final ValueChanged<String> onEvaluate;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onSendHomework;
  final VoidCallback onSave;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final content = _StructuredActivityContent.tryParse(activity);
    final homework = content?.homework ?? activity.homework;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('نشاط ${index + 1} من $total',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900)),
              ),
              Text(Duration(seconds: elapsedSeconds)
                  .toString()
                  .split('.')
                  .first),
            ],
          ),
          const SizedBox(height: 12),
          Text(activity.title,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          if (content == null)
            Text(activity.instructions)
          else
            _ActivityContentView(content: content),
          if (homework.isNotEmpty) ...[
            const SizedBox(height: 12),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('الواجب المقترح'),
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(homework),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('سيتم تفعيل إرفاق صوت الأخصائي قريبًا.'),
                  ),
                );
              },
              icon: const Icon(Icons.mic_none_outlined),
              label: const Text('إرفاق صوت للأخصائي'),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: options.map((option) {
              final selected = selectedValue == option;
              return SizedBox(
                height: 54,
                child: selected
                    ? FilledButton(
                        onPressed: () => onEvaluate(option),
                        child: Text(option),
                      )
                    : FilledButton.tonal(
                        onPressed: () => onEvaluate(option),
                        child: Text(option),
                      ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: notes,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'ملاحظة الأخصائي'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: onPrevious,
                icon: const Icon(Icons.arrow_back),
                label: const Text('النشاط السابق'),
              ),
              FilledButton.tonalIcon(
                onPressed: onNext,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('النشاط التالي'),
              ),
              FilledButton.tonalIcon(
                onPressed: homework.isEmpty ? null : onSendHomework,
                icon: const Icon(Icons.assignment_add),
                label: const Text('إرسال واجب'),
              ),
              FilledButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.save_outlined),
                label: const Text('حفظ الجلسة'),
              ),
              TextButton.icon(
                onPressed: onStop,
                icon: const Icon(Icons.close),
                label: const Text('إنهاء العرض'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              Chip(label: Text('الأنشطة: $total')),
              Chip(label: Text('نسبة النجاح: $successRate%')),
              Chip(label: Text('واجبات مرسلة: $homeworkSentCount')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityContentView extends StatelessWidget {
  const _ActivityContentView({required this.content});

  final _StructuredActivityContent content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    if (content.kind == 'speechWord') {
      return _Panel(
        title: 'كلمات حرف ${content.letter}',
        subtitle: content.position,
        child: _chips(content.words),
      );
    }
    if (content.kind == 'speechSentence') {
      return _Panel(
        title: 'جمل حرف ${content.letter}',
        subtitle: content.instructions,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: content.sentences
              .map((sentence) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(sentence,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ))
              .toList(),
        ),
      );
    }
    if (content.kind != 'speechLetter') {
      return Text(content.instructions);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                content.letterDisplay,
                textAlign: TextAlign.center,
                style: theme.textTheme.displaySmall?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Chip(
                label: Text(content.vocalization),
                backgroundColor: colorScheme.surface,
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (content.instructions.isNotEmpty)
          Text(content.instructions,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _chips(List<String> values) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values
          .map((value) => Chip(
                label: Text(value),
                visualDensity: VisualDensity.compact,
              ))
          .toList(),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel(
      {required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900)),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(subtitle),
          ],
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _StructuredActivityContent {
  const _StructuredActivityContent({
    required this.kind,
    this.letter = '',
    this.letterDisplay = '',
    this.vocalization = '',
    this.position = '',
    this.words = const [],
    this.sentences = const [],
    this.instructions = '',
    this.homework = '',
    this.sortOrder = 0,
  });

  final String kind;
  final String letter;
  final String letterDisplay;
  final String vocalization;
  final String position;
  final List<String> words;
  final List<String> sentences;
  final String instructions;
  final String homework;
  final int sortOrder;

  String get summary {
    if (kind == 'speechLetter') return '$letterDisplay - $vocalization';
    if (kind == 'speechWord') return '$position: ${words.join(' - ')}';
    if (kind == 'speechSentence') return sentences.join(' / ');
    return instructions;
  }

  static _StructuredActivityContent? tryParse(ProgramActivity activity) {
    try {
      final json = jsonDecode(activity.instructions);
      if (json is! Map<String, dynamic>) {
        return null;
      }
      return _StructuredActivityContent(
        kind: json['kind'] as String? ?? 'other',
        letter: json['letter'] as String? ?? '',
        letterDisplay: json['letterDisplay'] as String? ?? '',
        vocalization: json['vocalization'] as String? ?? '',
        position: json['position'] as String? ?? '',
        words: _stringList(json['words']),
        sentences: _stringList(json['sentences']),
        instructions: json['instructions'] as String? ?? '',
        homework: json['homework'] as String? ?? activity.homework,
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  static List<String> _stringList(Object? value) {
    if (value is List) return value.map((item) => '$item').toList();
    return const [];
  }
}

class _PreviousSessions extends StatelessWidget {
  const _PreviousSessions({required this.app});

  final AppProvider app;

  @override
  Widget build(BuildContext context) {
    if (app.sessions.isEmpty) {
      return const EmptyState(
        icon: Icons.event_note_outlined,
        title: 'لا توجد جلسات',
        message: 'بعد حفظ أول جلسة ستظهر هنا.',
      );
    }
    return ResponsiveGrid(
      children: app.sessions.map((session) {
        return AppCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.record_voice_over_outlined),
            title: Text('${session.cardTitle} - ${session.quickResult}'),
            subtitle: Text('${session.startedAt}\n${session.notes}'),
            trailing: Text('${session.successRate}%'),
          ),
        );
      }).toList(),
    );
  }
}
