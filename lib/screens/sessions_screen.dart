import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final sessionFocus = FocusNode();
  bool autoMoveToNext = true;
  _SessionSummary? lastSummary;

  @override
  void dispose() {
    timer?.cancel();
    notes.dispose();
    sessionFocus.dispose();
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
            title: 'تجهيز الجلسة',
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
                            lastSummary = null;
                          }),
                ),
                const SizedBox(height: 10),
                if (program == null)
                  const EmptyState(
                    icon: Icons.tune_outlined,
                    title: 'اختر الطالب والبرنامج',
                    message:
                        'بعد الاختيار ستظهر مكتبة الأنشطة المناسبة للجلسة.',
                  )
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
                        lastSummary = null;
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
          if (lastSummary != null) ...[
            _SessionSummaryCard(summary: lastSummary!),
            const SizedBox(height: 16),
          ],
          _PreviousSessions(app: app),
        ] else ...[
          Focus(
            focusNode: sessionFocus,
            autofocus: true,
            onKeyEvent: (node, event) => _handleSessionKey(event, activities),
            child: _ActiveSessionCard(
              activity: activities[activityIndex],
              index: activityIndex,
              total: activities.length,
              completedCount: activityResults.length,
              selectedValue: activityResults[activities[activityIndex].id],
              options: _options(activities[activityIndex]),
              elapsedSeconds: seconds,
              successRate: _successRate(activities),
              homeworkSentCount: homeworkSentCount,
              hasSessionHomework: _hasHomework(activities),
              hasEvaluations: activityResults.isNotEmpty,
              autoMoveToNext: autoMoveToNext,
              notes: notes,
              onEvaluate: (value) => _evaluateCurrent(value, activities),
              onPrevious: activityIndex == 0
                  ? null
                  : () => setState(() => activityIndex--),
              onNext: activityIndex >= activities.length - 1
                  ? null
                  : () => setState(() => activityIndex++),
              onToggleAutoMove: (value) =>
                  setState(() => autoMoveToNext = value),
              onQuickNote: _addQuickNote,
              onSendSessionHomework: () =>
                  _sendSessionHomework(app, activities),
              onSave: () => _saveSession(app, activities),
              onPrintReport: () => _printSessionReport(app, activities),
              onStop: () => setState(() {
                sessionStarted = false;
                timer?.cancel();
              }),
            ),
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
    return const ['تم الإنجاز', 'يحتاج مساعدة', 'لم ينجز'];
  }

  KeyEventResult _handleSessionKey(
      KeyEvent event, List<ProgramActivity> activities) {
    if (event is! KeyDownEvent || activities.isEmpty) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) {
      _evaluateCurrent('تم الإنجاز', activities);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) {
      _evaluateCurrent('يحتاج مساعدة', activities);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit3 || key == LogicalKeyboardKey.numpad3) {
      _evaluateCurrent('لم ينجز', activities);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight && activityIndex > 0) {
      setState(() => activityIndex--);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft &&
        activityIndex < activities.length - 1) {
      setState(() => activityIndex++);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _evaluateCurrent(String value, List<ProgramActivity> activities) {
    if (activities.isEmpty) return;
    setState(() {
      activityResults[activities[activityIndex].id] = value;
      if (autoMoveToNext && activityIndex < activities.length - 1) {
        activityIndex++;
      }
    });
  }

  void _addQuickNote(String value) {
    final current = notes.text.trim();
    notes.text = current.isEmpty ? value : '$current، $value';
    notes.selection = TextSelection.collapsed(offset: notes.text.length);
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
      if (value == 'صحيح' || value == 'جيد' || value == 'تم الإنجاز') {
        score += 1;
      }
      if (value == 'جزئي' || value == 'بمساعدة' || value == 'يحتاج مساعدة') {
        score += .5;
      }
    }
    return ((score / activities.length) * 100).round();
  }

  bool _hasHomework(List<ProgramActivity> activities) {
    return activities.any((activity) {
      final content = _StructuredActivityContent.tryParse(activity);
      return (content?.homework ?? activity.homework).trim().isNotEmpty;
    });
  }

  Future<void> _sendSessionHomework(
      AppProvider app, List<ProgramActivity> activities) {
    final student = app.selectedStudent;
    final program = _program(app);
    final items = activities
        .map((activity) {
          final content = _StructuredActivityContent.tryParse(activity);
          final homework = content?.homework ?? activity.homework;
          if (homework.trim().isEmpty) return '';
          return '${activity.title}: $homework';
        })
        .where((item) => item.isNotEmpty)
        .toList();
    if (student == null || items.isEmpty) return Future.value();
    return runWithFeedback(context, () async {
      await app.saveExercise(Exercise(
        id: 'exercise_${DateTime.now().millisecondsSinceEpoch}',
        centerId: student.centerId,
        studentId: student.id,
        title:
            '${program?.name ?? 'برنامج علاجي'} - واجب جلسة (${items.length} أنشطة)',
        instructions: _sessionHomeworkInstructions(activities),
        dueDate: DateTime.now()
            .add(const Duration(days: 1))
            .toIso8601String()
            .split('T')
            .first,
        status: 'مرسل',
      ));
      setState(() => homeworkSentCount++);
    }, success: 'تم إرسال واجب الجلسة لولي الأمر.');
  }

  String _sessionHomeworkInstructions(List<ProgramActivity> activities) {
    final payload = activities
        .map((activity) {
          final content = _StructuredActivityContent.tryParse(activity);
          final homework = content?.homework ?? activity.homework;
          if (homework.trim().isEmpty) return null;
          return {
            'title': activity.title,
            'homework': homework,
            'kind': content?.kind ?? 'other',
            'letter': content?.letter ?? '',
            'letterDisplay': content?.letterDisplay ?? '',
            'vocalization': content?.vocalization ?? '',
            'position': content?.position ?? '',
            'words': content?.words ?? const <String>[],
            'sentences': content?.sentences ?? const <String>[],
            'instructions': content?.instructions ?? activity.instructions,
          };
        })
        .whereType<Map<String, Object>>()
        .toList();
    return jsonEncode({'kind': 'sessionHomework', 'activities': payload});
  }

  Future<void> _saveSession(AppProvider app, List<ProgramActivity> activities) {
    final student = app.selectedStudent;
    final program = _program(app);
    final firstActivity = activities.isEmpty ? null : activities.first;
    final skill = firstActivity == null
        ? null
        : _findSkill(app.programSkills, firstActivity.skillId);
    final skillTitle = _skillTitlesForActivities(app, activities);
    return runWithFeedback(context, () async {
      if (student == null || program == null || skill == null) {
        throw StateError('اختر الطالب والبرنامج والأنشطة أولًا.');
      }
      if (activityResults.isEmpty) {
        throw StateError('قيّم نشاطًا واحدًا على الأقل قبل حفظ الجلسة.');
      }
      final savedSummary = _SessionSummary(
        activitiesCount: activities.length,
        evaluatedCount: activityResults.length,
        successRate: _successRate(activities),
        homeworkSentCount: homeworkSentCount,
        notes: notes.text.trim(),
      );
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
        cardTitle: skillTitle,
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
        lastSummary = savedSummary;
        notes.clear();
      });
    }, success: 'تم حفظ الجلسة.');
  }

  Future<void> _printSessionReport(
      AppProvider app, List<ProgramActivity> activities) {
    final program = _program(app);
    return runWithFeedback(
      context,
      () => app.printSessionReport(
        activities: activities,
        results: activityResults,
        successRate: _successRate(activities),
        durationSeconds: seconds,
        homeworkSentCount: homeworkSentCount,
        notes: notes.text.trim(),
        programName: program?.name ?? 'برنامج علاجي',
        skillTitle: _skillTitlesForActivities(app, activities),
      ),
      loading: 'جار إنشاء تقرير الجلسة...',
      success: 'تم إنشاء تقرير الجلسة.',
    );
  }

  ProgramSkill? _findSkill(List<ProgramSkill> skills, String id) {
    for (final skill in skills) {
      if (skill.id == id) return skill;
    }
    return null;
  }

  String _skillTitlesForActivities(
      AppProvider app, List<ProgramActivity> activities) {
    final names = <String>{};
    for (final activity in activities) {
      final skill = _findSkill(app.programSkills, activity.skillId);
      if (skill != null) names.add(skill.title);
    }
    return names.isEmpty ? 'مهارة علاجية' : names.join('، ');
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

class _SessionSummary {
  const _SessionSummary({
    required this.activitiesCount,
    required this.evaluatedCount,
    required this.successRate,
    required this.homeworkSentCount,
    required this.notes,
  });

  final int activitiesCount;
  final int evaluatedCount;
  final int successRate;
  final int homeworkSentCount;
  final String notes;
}

class _SessionSummaryCard extends StatelessWidget {
  const _SessionSummaryCard({required this.summary});

  final _SessionSummary summary;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ملخص آخر جلسة',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text('الأنشطة: ${summary.activitiesCount}')),
              Chip(label: Text('المقيّم: ${summary.evaluatedCount}')),
              Chip(label: Text('نسبة النجاح: ${summary.successRate}%')),
              Chip(label: Text('الواجبات: ${summary.homeworkSentCount}')),
            ],
          ),
          if (summary.notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('ملاحظة الأخصائي: ${summary.notes}'),
          ],
          const SizedBox(height: AppSpacing.md),
          SemanticAlertCard(
            kind: summary.successRate >= 70
                ? SemanticAlertKind.success
                : summary.successRate >= 40
                    ? SemanticAlertKind.warning
                    : SemanticAlertKind.error,
            icon: Icons.psychology_alt_outlined,
            title: 'قراءة سند للجلسة',
            message: _insight(summary),
          ),
        ],
      ),
    );
  }

  String _insight(_SessionSummary summary) {
    if (summary.successRate >= 70) {
      return 'الأداء جيد. حافظ على نفس المهارة مع زيادة بسيطة في الصعوبة أو عدد المحاولات.';
    }
    if (summary.successRate >= 40) {
      return 'الأداء متوسط. يفضل إعادة نفس المهارة مع دعم بصري أو نموذج صوتي أوضح.';
    }
    return 'الجلسة تحتاج تبسيط. ابدأ بمحاولات أقل، وركز على نشاط واحد مع واجب منزلي قصير.';
  }
}

class _ActiveSessionCard extends StatelessWidget {
  const _ActiveSessionCard({
    required this.activity,
    required this.index,
    required this.total,
    required this.completedCount,
    required this.selectedValue,
    required this.options,
    required this.elapsedSeconds,
    required this.successRate,
    required this.homeworkSentCount,
    required this.hasSessionHomework,
    required this.hasEvaluations,
    required this.autoMoveToNext,
    required this.notes,
    required this.onEvaluate,
    required this.onPrevious,
    required this.onNext,
    required this.onToggleAutoMove,
    required this.onQuickNote,
    required this.onSendSessionHomework,
    required this.onSave,
    required this.onPrintReport,
    required this.onStop,
  });

  final ProgramActivity activity;
  final int index;
  final int total;
  final int completedCount;
  final String? selectedValue;
  final List<String> options;
  final int elapsedSeconds;
  final int successRate;
  final int homeworkSentCount;
  final bool hasSessionHomework;
  final bool hasEvaluations;
  final bool autoMoveToNext;
  final TextEditingController notes;
  final ValueChanged<String> onEvaluate;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<bool> onToggleAutoMove;
  final ValueChanged<String> onQuickNote;
  final VoidCallback onSendSessionHomework;
  final VoidCallback onSave;
  final VoidCallback onPrintReport;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final content = _StructuredActivityContent.tryParse(activity);
    final homework = content?.homework ?? activity.homework;
    final progress = total == 0 ? 0.0 : (index + 1) / total;
    final remaining = total - completedCount;
    final estimatedMinutes = remaining <= 0 ? 0 : remaining * 2;
    return TherapyCard(
      title: 'وضع التركيز العلاجي',
      icon: Icons.center_focus_strong_outlined,
      trailing: AppPill(
        label: Duration(seconds: elapsedSeconds).toString().split('.').first,
        icon: Icons.timer_outlined,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SmartSessionProgress(
            index: index,
            total: total,
            completedCount: completedCount,
            successRate: successRate,
            estimatedMinutes: estimatedMinutes,
          ),
          const SizedBox(height: AppSpacing.sm),
          LinearProgressIndicator(value: progress),
          const SizedBox(height: AppSpacing.lg),
          if (content == null)
            _PlainActivity(
                title: activity.title, instructions: activity.instructions)
          else
            _ActivityContentView(title: activity.title, content: content),
          if (homework.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _HomeworkSuggestion(
              homework: homework,
              selectedValue: selectedValue,
              content: content,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: autoMoveToNext,
                  onChanged: onToggleAutoMove,
                  title: const Text('انتقال تلقائي بعد التقييم'),
                  subtitle:
                      const Text('اختصارات: 1 إنجاز، 2 مساعدة، 3 لم ينجز'),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('سيتم تفعيل إرفاق صوت الأخصائي قريبًا.'),
                    ),
                  );
                },
                icon: const Icon(Icons.mic_none_outlined),
                label: const Text('إرفاق صوت'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'التقييم',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: options.map((option) {
              final selected = selectedValue == option;
              return SizedBox(
                height: 68,
                width: 172,
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
          const SizedBox(height: AppSpacing.md),
          _QuickNotes(onQuickNote: onQuickNote),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: notes,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'ملاحظة الأخصائي'),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton.icon(
                onPressed: onPrevious,
                icon: const Icon(Icons.arrow_back),
                label: const Text('السابق'),
              ),
              FilledButton.icon(
                onPressed: onNext,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('التالي'),
              ),
              FilledButton.tonalIcon(
                onPressed: hasSessionHomework ? onSendSessionHomework : null,
                icon: const Icon(Icons.playlist_add_check),
                label: const Text('إرسال واجب الجلسة'),
              ),
              FilledButton.icon(
                onPressed: hasEvaluations ? onSave : null,
                icon: const Icon(Icons.save_outlined),
                label: const Text('حفظ الجلسة'),
              ),
              FilledButton.tonalIcon(
                onPressed: hasEvaluations ? onPrintReport : null,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('تقرير PDF'),
              ),
              TextButton.icon(
                onPressed: onStop,
                icon: const Icon(Icons.close),
                label: const Text('إيقاف الجلسة'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AppPill(
                  label: 'المكتمل: $completedCount / $total',
                  icon: Icons.layers_outlined),
              AppPill(
                  label: 'واجبات مرسلة: $homeworkSentCount',
                  icon: Icons.assignment_turned_in_outlined),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlainActivity extends StatelessWidget {
  const _PlainActivity({required this.title, required this.instructions});

  final String title;
  final String instructions;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          _InstructionSteps(
            text: instructions.trim().isEmpty
                ? 'نشاط علاجي بدون تعليمات إضافية.'
                : instructions,
          ),
        ],
      ),
    );
  }
}

class _ActivityContentView extends StatelessWidget {
  const _ActivityContentView({required this.title, required this.content});

  final String title;
  final _StructuredActivityContent content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    if (content.kind == 'speechWord') {
      return _Panel(
        title: 'كلمات حرف ${content.letter}',
        subtitle: content.position,
        child: _wordCards(context, content.words),
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
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppRadii.card),
                      ),
                      child: Text(
                        sentence,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ))
              .toList(),
        ),
      );
    }
    if (content.kind != 'speechLetter') {
      return _PlainActivity(title: title, instructions: content.instructions);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(36),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border:
                Border.all(color: colorScheme.primary.withValues(alpha: .3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                content.letterDisplay,
                textAlign: TextAlign.center,
                style: theme.textTheme.displayLarge?.copyWith(
                  fontSize: 104,
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 8),
              AppPill(
                label: content.vocalization,
                icon: Icons.graphic_eq_outlined,
                selected: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (content.instructions.isNotEmpty)
          _InstructionSteps(text: content.instructions),
      ],
    );
  }

  Widget _wordCards(BuildContext context, List<String> values) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: values
          .map((value) => Container(
                constraints: const BoxConstraints(minWidth: 104),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(AppRadii.card),
                ),
                child: Text(
                  value,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ))
          .toList(),
    );
  }
}

class _SmartSessionProgress extends StatelessWidget {
  const _SmartSessionProgress({
    required this.index,
    required this.total,
    required this.completedCount,
    required this.successRate,
    required this.estimatedMinutes,
  });

  final int index;
  final int total;
  final int completedCount;
  final int successRate;
  final int estimatedMinutes;

  @override
  Widget build(BuildContext context) {
    final remaining = (total - completedCount).clamp(0, total);
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AppPill(
          label: 'النشاط ${index + 1} من $total',
          icon: Icons.playlist_play_outlined,
          selected: true,
        ),
        AppPill(
          label: 'اكتمل $completedCount',
          icon: Icons.check_circle_outline,
        ),
        AppPill(
          label: 'متبقي $remaining',
          icon: Icons.pending_actions_outlined,
        ),
        AppPill(
          label: '$successRate%',
          icon: Icons.trending_up,
          selected: successRate >= 70,
        ),
        AppPill(
          label: estimatedMinutes == 0
              ? 'جاهز للإنهاء'
              : 'حوالي $estimatedMinutes دقائق',
          icon: Icons.schedule_outlined,
        ),
      ],
    );
  }
}

class _QuickNotes extends StatelessWidget {
  const _QuickNotes({required this.onQuickNote});

  final ValueChanged<String> onQuickNote;

  @override
  Widget build(BuildContext context) {
    const values = [
      'تحسن ممتاز',
      'يحتاج متابعة',
      'تشتت',
      'نطق أفضل',
      'تعاون ممتاز',
      'يحتاج تدريب منزلي',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ملاحظات سريعة', style: SanadText.subtitle(context)),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: values
              .map(
                (value) => ActionChip(
                  label: Text(value),
                  avatar: const Icon(Icons.add_comment_outlined, size: 18),
                  onPressed: () => onQuickNote(value),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _HomeworkSuggestion extends StatelessWidget {
  const _HomeworkSuggestion({
    required this.homework,
    required this.selectedValue,
    required this.content,
  });

  final String homework;
  final String? selectedValue;
  final _StructuredActivityContent? content;

  @override
  Widget build(BuildContext context) {
    final tone = sanadAlertTone(context, SemanticAlertKind.info);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: tone.background,
        border: Border.all(color: tone.border),
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_outlined, color: tone.icon),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'اقتراح واجب ذكي',
                  style: TextStyle(
                    color: tone.foreground,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _suggestionText(),
            style: TextStyle(
              color: tone.foreground,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  String _suggestionText() {
    final base = homework.trim();
    if (selectedValue == 'لم ينجز') {
      return '$base\nخفف صعوبة التدريب وابدأ بتكرار قصير مع دعم ولي الأمر.';
    }
    if (selectedValue == 'يحتاج مساعدة') {
      return '$base\nيفضل تدريب منزلي قصير مع نموذج صوتي واضح.';
    }
    if (selectedValue == 'تم الإنجاز') {
      return '$base\nيمكن زيادة التحدي قليلًا أو استخدام كلمات مشابهة.';
    }
    if (content?.kind == 'speechLetter') {
      return '$base\nابدأ بصوت الحرف منفردًا ثم كرره بهدوء.';
    }
    return base;
  }
}

class _InstructionSteps extends StatelessWidget {
  const _InstructionSteps({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final steps = text
        .split(RegExp(r'[.\n،]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (steps.length <= 1) {
      return Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.55,
            ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppPill(label: '${i + 1}', selected: true),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  steps[i],
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.45,
                      ),
                ),
              ),
            ],
          ),
          if (i < steps.length - 1) const SizedBox(height: AppSpacing.sm),
        ],
      ],
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
