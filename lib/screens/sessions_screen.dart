import 'dart:async';

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
  String? sectionId;
  String? skillId;
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
            .toList();
    final sectionSkills = sectionId == null
        ? <ProgramSkill>[]
        : app.programSkills
            .where((skill) =>
                skill.programId == program?.id && skill.sectionId == sectionId)
            .toList();
    final skill = _skill(app);
    final activities = skill == null
        ? <ProgramActivity>[]
        : app.programActivities
            .where((activity) => activity.skillId == skill.id)
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepCard(
          number: 1,
          title: 'اختيار الطالب',
          child: DropdownButtonFormField<String>(
            initialValue: student?.id,
            decoration: const InputDecoration(labelText: 'الطالب'),
            items: app.students
                .map((item) => DropdownMenuItem(
                    value: item.id,
                    child: Text(item.name, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (value) async {
              final matches =
                  app.students.where((item) => item.id == value).toList();
              await app.selectStudent(matches.isEmpty ? null : matches.first);
              setState(() {
                activityResults.clear();
              });
            },
          ),
        ),
        const SizedBox(height: 12),
        if (student != null)
          _StepCard(
            number: 2,
            title: 'اختيار البرنامج',
            child: DropdownButtonFormField<String>(
              initialValue: programId,
              decoration: const InputDecoration(labelText: 'البرنامج العلاجي'),
              items: app.programs
                  .map((item) => DropdownMenuItem(
                      value: item.id,
                      child: Text(item.name, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (value) => setState(() {
                programId = value;
                sectionId = null;
                skillId = null;
                activityResults.clear();
              }),
            ),
          ),
        if (program != null) ...[
          const SizedBox(height: 12),
          _StepCard(
            number: 3,
            title: 'اختيار المرحلة',
            child: DropdownButtonFormField<String>(
              initialValue: sectionId,
              decoration: const InputDecoration(labelText: 'المرحلة'),
              items: sections
                  .map((item) => DropdownMenuItem(
                      value: item.id,
                      child: Text(item.title, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (value) => setState(() {
                sectionId = value;
                skillId = null;
                activityResults.clear();
              }),
            ),
          ),
        ],
        if (sectionId != null) ...[
          const SizedBox(height: 12),
          _StepCard(
            number: 4,
            title: 'اختيار المهارة',
            child: DropdownButtonFormField<String>(
              initialValue: skillId,
              decoration: const InputDecoration(labelText: 'المهارة'),
              items: sectionSkills
                  .map((item) => DropdownMenuItem(
                      value: item.id,
                      child: Text(item.title, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (value) => setState(() {
                skillId = value;
                activityResults.clear();
              }),
            ),
          ),
        ],
        if (activities.isNotEmpty) ...[
          const SizedBox(height: 12),
          _StepCard(
            number: 5,
            title: 'تقييم الأنشطة',
            child: ResponsiveGrid(
              children: activities.map((activity) {
                final options = _options(activity);
                return AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(activity.title,
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                      if (activity.instructions.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(activity.instructions),
                        ),
                      const SizedBox(height: 10),
                      SegmentedButton<String>(
                        segments: options
                            .map((item) =>
                                ButtonSegment(value: item, label: Text(item)))
                            .toList(),
                        selected: {
                          activityResults[activity.id] ?? options.first
                        },
                        onSelectionChanged: (value) => setState(
                            () => activityResults[activity.id] = value.first),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: activity.homework.isEmpty
                              ? null
                              : () => _sendHomework(app, activity),
                          icon: const Icon(Icons.assignment_add),
                          label: const Text('إرسال واجب'),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
        if (activities.isNotEmpty) ...[
          const SizedBox(height: 12),
          _StepCard(
            number: 6,
            title: 'حفظ الجلسة والتقرير',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: notes,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'ملاحظة مختصرة'),
                ),
                const SizedBox(height: 12),
                Text(
                    'مدة الجلسة: ${Duration(seconds: seconds).toString().split('.').first}'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _startTimer,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('بدء المؤقت'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => timer?.cancel(),
                      icon: const Icon(Icons.pause),
                      label: const Text('إيقاف'),
                    ),
                    FilledButton.icon(
                      onPressed: () => _saveSession(app),
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('حفظ الجلسة'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => app.printReport(
                          'تقرير جلسة', app.user?.name ?? '', ''),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('تقرير الجلسة PDF'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        _PreviousSessions(app: app),
      ],
    );
  }

  TherapyProgram? _program(AppProvider app) {
    if (programId == null) return null;
    for (final program in app.programs) {
      if (program.id == programId) return program;
    }
    return null;
  }

  ProgramSkill? _skill(AppProvider app) {
    if (skillId == null) return null;
    for (final skill in app.programSkills) {
      if (skill.id == skillId) return skill;
    }
    return null;
  }

  List<String> _options(ProgramActivity activity) {
    if (activity.evaluationType == 'sensory') {
      return const ['لا يؤدي', 'يؤدي بمساعدة', 'يؤدي جيدًا'];
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
      final value = activityResults[activity.id] ?? _options(activity).first;
      if (value == 'صحيح' || value == 'يؤدي جيدًا') score += 1;
      if (value == 'جزئي' || value == 'يؤدي بمساعدة') score += .5;
    }
    return ((score / activities.length) * 100).round();
  }

  Future<void> _sendHomework(AppProvider app, ProgramActivity activity) {
    final student = app.selectedStudent;
    if (student == null) return Future.value();
    return runWithFeedback(context, () async {
      await app.saveExercise(Exercise(
        id: 'exercise_${DateTime.now().millisecondsSinceEpoch}',
        centerId: student.centerId,
        studentId: student.id,
        title: activity.title,
        instructions: activity.homework,
        dueDate: DateTime.now().add(const Duration(days: 1)).toIso8601String(),
        status: 'مرسل',
      ));
    }, success: 'تم إرسال الواجب لولي الأمر.');
  }

  Future<void> _saveSession(AppProvider app) {
    final student = app.selectedStudent;
    final program = _program(app);
    final skill = _skill(app);
    final activities = skill == null
        ? <ProgramActivity>[]
        : app.programActivities
            .where((activity) => activity.skillId == skill.id)
            .toList();
    return runWithFeedback(context, () async {
      if (student == null || program == null || skill == null) {
        throw StateError('اختر الطالب والبرنامج والمرحلة والمهارة أولًا.');
      }
      if (activityResults.length < activities.length) {
        throw StateError('قيّم كل الأنشطة قبل حفظ الجلسة.');
      }
      final firstActivity = activities.isEmpty ? null : activities.first;
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
        attempts: activities.length,
        successRate: _successRate(activities),
        startedAt: DateTime.now().toIso8601String(),
        durationSeconds: seconds,
        cardTitle: skill.title,
        quickResult: firstActivity == null
            ? 'صحيح'
            : activityResults[firstActivity.id] ??
                _options(firstActivity).first,
        notes: notes.text.trim(),
        summary:
            'تم تنفيذ ${activities.length} نشاط بنسبة نجاح ${_successRate(activities)}%.',
      ));
      timer?.cancel();
      setState(() {
        seconds = 0;
        activityResults.clear();
        notes.clear();
      });
    }, success: 'تم حفظ الجلسة.');
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.number,
    required this.title,
    required this.child,
  });

  final int number;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 14, child: Text('$number')),
              const SizedBox(width: 8),
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
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
