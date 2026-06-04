import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../widgets/app_widgets.dart';
import '../widgets/feedback.dart';

class ProgramsScreen extends StatefulWidget {
  const ProgramsScreen({super.key});

  @override
  State<ProgramsScreen> createState() => _ProgramsScreenState();
}

class _ProgramsScreenState extends State<ProgramsScreen> {
  String? selectedProgramId;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final selectedProgram = _selectedProgram(app);
    final sections = selectedProgram == null
        ? <ProgramSection>[]
        : app.programSections
            .where((section) => section.programId == selectedProgram.id)
            .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final skills = selectedProgram == null
        ? <ProgramSkill>[]
        : app.programSkills
            .where((skill) => skill.programId == selectedProgram.id)
            .toList();
    final activities = selectedProgram == null
        ? <ProgramActivity>[]
        : app.programActivities
            .where((activity) => activity.programId == selectedProgram.id)
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (app.canManagePrograms)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => _showProgramDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('إضافة برنامج'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _seedCorePrograms(app),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('إنشاء البرامج الأساسية'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _confirmRebuildCorePrograms(context, app),
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة إنشاء البرامج الأساسية'),
              ),
            ],
          ),
        const SizedBox(height: 12),
        if (app.programs.isEmpty)
          const EmptyState(
            icon: Icons.extension_outlined,
            title: 'لا توجد برامج علاجية',
            message:
                'أنشئ العلاج النطقي والتكامل الحسي، ثم جرّب المحتوى داخل الجلسات.',
          )
        else ...[
          AppCard(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: app.programs.map((program) {
                return ChoiceChip(
                  selected: program.id == selectedProgram?.id,
                  label: Text('${program.name} - ${program.type}'),
                  onSelected: (_) =>
                      setState(() => selectedProgramId = program.id),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(selectedProgram?.name ?? '',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900)),
                if (selectedProgram?.description.isNotEmpty == true)
                  Text(selectedProgram!.description),
                const SizedBox(height: 12),
                if (app.canManagePrograms)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: selectedProgram == null
                            ? null
                            : () => _showSectionDialog(context,
                                selectedProgram: selectedProgram),
                        icon: const Icon(Icons.view_agenda_outlined),
                        label: const Text('مرحلة'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: selectedProgram == null || sections.isEmpty
                            ? null
                            : () => _showSkillDialog(context,
                                selectedProgram: selectedProgram,
                                sections: sections),
                        icon: const Icon(Icons.psychology_outlined),
                        label: const Text('مهارة'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: selectedProgram == null || skills.isEmpty
                            ? null
                            : () => _showActivityDialog(context,
                                selectedProgram: selectedProgram,
                                skills: skills),
                        icon: const Icon(Icons.local_activity_outlined),
                        label: const Text('نشاط'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ResponsiveGrid(
            children: sections.map((section) {
              final sectionSkills = skills
                  .where((skill) => skill.sectionId == section.id)
                  .toList()
                ..sort((a, b) => a.title.compareTo(b.title));
              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(section.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 18)),
                    const SizedBox(height: 8),
                    if (sectionSkills.isEmpty)
                      const Text('لا توجد مهارات في هذه المرحلة.')
                    else
                      ...sectionSkills.map((skill) {
                        final skillActivities = activities
                            .where((activity) => activity.skillId == skill.id)
                            .toList();
                        return ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: Text(skill.title),
                          subtitle: Text(skill.description.isEmpty
                              ? 'مهارة علاجية'
                              : skill.description),
                          children: skillActivities.map((activity) {
                            final structured =
                                _StructuredLetterContent.tryParse(activity);
                            return ListTile(
                              leading: const Icon(Icons.play_circle_outline),
                              title: Text(activity.title),
                              subtitle: Text(structured == null
                                  ? activity.instructions
                                  : structured.preview),
                              trailing: Text(
                                activity.evaluationType == 'sensory'
                                    ? 'تكامل حسي'
                                    : 'نطقي',
                              ),
                            );
                          }).toList(),
                        );
                      }),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  TherapyProgram? _selectedProgram(AppProvider app) {
    if (app.programs.isEmpty) return null;
    if (selectedProgramId == null) return app.programs.first;
    for (final program in app.programs) {
      if (program.id == selectedProgramId) return program;
    }
    return app.programs.first;
  }

  Future<void> _showProgramDialog(BuildContext context) async {
    final name = TextEditingController();
    final description = TextEditingController();
    var type = 'العلاج النطقي';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إضافة برنامج علاجي'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'اسم البرنامج')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'نوع البرنامج'),
                items: const [
                  'العلاج النطقي',
                  'التكامل الحسي',
                  'لغة إشارة',
                  'أخرى'
                ]
                    .map((item) =>
                        DropdownMenuItem(value: item, child: Text(item)))
                    .toList(),
                onChanged: (value) => type = value ?? type,
              ),
              const SizedBox(height: 10),
              TextField(
                  controller: description,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'وصف مختصر')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () async {
                final app = context.read<AppProvider>();
                await runWithFeedback(context, () async {
                  if (name.text.trim().isEmpty) {
                    throw StateError('اسم البرنامج مطلوب.');
                  }
                  await app.saveProgram(TherapyProgram(
                    id: 'program_${DateTime.now().millisecondsSinceEpoch}',
                    centerId: app.activeCenterId,
                    name: name.text.trim(),
                    type: type,
                    description: description.text.trim(),
                  ));
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                });
              },
              child: const Text('حفظ')),
        ],
      ),
    );
  }

  Future<void> _showSectionDialog(BuildContext context,
      {required TherapyProgram selectedProgram}) async {
    final title = TextEditingController();
    await _simpleSaveDialog(
      context,
      titleText: 'إضافة مرحلة',
      labelText: 'عنوان المرحلة',
      controller: title,
      onSave: () => context.read<AppProvider>().saveProgramSection(
            ProgramSection(
              id: 'section_${DateTime.now().millisecondsSinceEpoch}',
              centerId: selectedProgram.centerId,
              programId: selectedProgram.id,
              title: title.text.trim(),
            ),
          ),
    );
  }

  Future<void> _showSkillDialog(BuildContext context,
      {required TherapyProgram selectedProgram,
      required List<ProgramSection> sections}) async {
    final title = TextEditingController();
    final description = TextEditingController();
    var sectionId = sections.first.id;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إضافة مهارة'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: sectionId,
                decoration: const InputDecoration(labelText: 'المرحلة'),
                items: sections
                    .map((section) => DropdownMenuItem(
                        value: section.id, child: Text(section.title)))
                    .toList(),
                onChanged: (value) => sectionId = value ?? sectionId,
              ),
              const SizedBox(height: 10),
              TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'اسم المهارة')),
              const SizedBox(height: 10),
              TextField(
                  controller: description,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'وصف المهارة')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () async {
                await runWithFeedback(context, () async {
                  if (title.text.trim().isEmpty) {
                    throw StateError('اسم المهارة مطلوب.');
                  }
                  await context.read<AppProvider>().saveProgramSkill(
                        ProgramSkill(
                          id: 'skill_${DateTime.now().millisecondsSinceEpoch}',
                          centerId: selectedProgram.centerId,
                          programId: selectedProgram.id,
                          sectionId: sectionId,
                          title: title.text.trim(),
                          description: description.text.trim(),
                        ),
                      );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                });
              },
              child: const Text('حفظ')),
        ],
      ),
    );
  }

  Future<void> _showActivityDialog(BuildContext context,
      {required TherapyProgram selectedProgram,
      required List<ProgramSkill> skills}) async {
    final title = TextEditingController();
    final instructions = TextEditingController();
    final homework = TextEditingController();
    var skillId = skills.first.id;
    var evaluationType =
        selectedProgram.type == 'التكامل الحسي' ? 'sensory' : 'speech';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إضافة نشاط'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: skillId,
                  decoration: const InputDecoration(labelText: 'المهارة'),
                  items: skills
                      .map((skill) => DropdownMenuItem(
                          value: skill.id, child: Text(skill.title)))
                      .toList(),
                  onChanged: (value) => skillId = value ?? skillId,
                ),
                const SizedBox(height: 10),
                TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'اسم النشاط')),
                const SizedBox(height: 10),
                TextField(
                    controller: instructions,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'تعليمات')),
                const SizedBox(height: 10),
                TextField(
                    controller: homework,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'واجب مقترح')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: evaluationType,
                  decoration: const InputDecoration(labelText: 'نوع التقييم'),
                  items: const [
                    DropdownMenuItem(
                        value: 'speech', child: Text('صحيح / جزئي / خطأ')),
                    DropdownMenuItem(
                        value: 'sensory',
                        child: Text('لا يؤدي / بمساعدة / جيد')),
                  ],
                  onChanged: (value) =>
                      evaluationType = value ?? evaluationType,
                ),
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
                await runWithFeedback(context, () async {
                  if (title.text.trim().isEmpty) {
                    throw StateError('اسم النشاط مطلوب.');
                  }
                  await context.read<AppProvider>().saveProgramActivity(
                        ProgramActivity(
                          id: 'activity_${DateTime.now().millisecondsSinceEpoch}',
                          centerId: selectedProgram.centerId,
                          programId: selectedProgram.id,
                          skillId: skillId,
                          title: title.text.trim(),
                          instructions: instructions.text.trim(),
                          homework: homework.text.trim(),
                          evaluationType: evaluationType,
                        ),
                      );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                });
              },
              child: const Text('حفظ')),
        ],
      ),
    );
  }

  Future<void> _simpleSaveDialog(
    BuildContext context, {
    required String titleText,
    required String labelText,
    required TextEditingController controller,
    required Future<void> Function() onSave,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(titleText),
        content: TextField(
            controller: controller,
            decoration: InputDecoration(labelText: labelText)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () async {
                await runWithFeedback(context, () async {
                  if (controller.text.trim().isEmpty) {
                    throw StateError(labelText);
                  }
                  await onSave();
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                });
              },
              child: const Text('حفظ')),
        ],
      ),
    );
  }

  Future<void> _confirmRebuildCorePrograms(
      BuildContext context, AppProvider app) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إعادة إنشاء البرامج الأساسية'),
        content: const Text(
            'سيتم حذف محتوى البرامج الأساسية القديم فقط، ثم إعادة زرع العلاج النطقي والتكامل الحسي بالمحتوى الجديد. لن يتم حذف الطلاب أو الحسابات أو الجلسات.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة الإنشاء'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _seedCorePrograms(app, rebuild: true);
    }
  }

  Future<void> _seedCorePrograms(AppProvider app,
      {bool rebuild = false}) async {
    await runWithFeedback(context, () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final speech = _findProgramByType(app, 'العلاج النطقي') ??
          TherapyProgram(
            id: 'program_speech_$now',
            centerId: app.activeCenterId,
            name: 'العلاج النطقي',
            type: 'العلاج النطقي',
            description:
                'الحروف العربية، الحركات الصوتية، أعضاء النطق، التمييز السمعي، الكلمات والجمل.',
          );
      final sensory = _findProgramByType(app, 'التكامل الحسي') ??
          TherapyProgram(
            id: 'program_sensory_$now',
            centerId: app.activeCenterId,
            name: 'التكامل الحسي',
            type: 'التكامل الحسي',
            description:
                'أنشطة سمعية وبصرية ولمسية وتوازن وحركة وتكامل بصري حركي.',
          );

      if (_findProgramByType(app, 'العلاج النطقي') == null) {
        await app.saveProgram(speech);
      }
      if (_findProgramByType(app, 'التكامل الحسي') == null) {
        await app.saveProgram(sensory);
      }

      final speechNeedsRebuild =
          rebuild || !_hasCompleteSpeechContent(app, speech);
      final sensoryNeedsRebuild =
          rebuild || !_hasCompleteSensoryContent(app, sensory);

      if (speechNeedsRebuild) {
        await app.deleteProgramContent(speech);
        await _seedSpeechProgram(app, speech, now);
      }
      if (sensoryNeedsRebuild) {
        await app.deleteProgramContent(sensory);
        await _seedSensoryProgram(app, sensory, now);
      }
    },
        success: rebuild
            ? 'تمت إعادة إنشاء البرامج الأساسية بالمحتوى الجديد.'
            : 'تم تجهيز البرامج الأساسية بمحتوى علاجي منظم.');
  }

  TherapyProgram? _findProgramByType(AppProvider app, String type) {
    for (final program in app.programs) {
      if (program.type == type) return program;
    }
    return null;
  }

  bool _hasCompleteSpeechContent(AppProvider app, TherapyProgram program) {
    final hasStructuredLetters = app.programActivities.any((activity) =>
        activity.programId == program.id &&
        activity.instructions.contains('"kind":"speechLetter"'));
    return hasStructuredLetters &&
        _hasSections(app, program, const [
          'الحروف',
          'أعضاء النطق',
          'التمييز السمعي',
          'الكلمات والجمل',
        ]);
  }

  bool _hasCompleteSensoryContent(AppProvider app, TherapyProgram program) {
    final hasActivities = app.programActivities
        .any((activity) => activity.programId == program.id);
    return hasActivities &&
        _hasSections(app, program, const [
          'أنشطة سمعية',
          'أنشطة بصرية',
          'أنشطة لمسية',
          'التوازن والحركة',
          'التكامل البصري الحركي',
        ]);
  }

  bool _hasSections(
      AppProvider app, TherapyProgram program, List<String> requiredTitles) {
    final titles = app.programSections
        .where((section) => section.programId == program.id)
        .map((section) => section.title)
        .toSet();
    return requiredTitles.every(titles.contains);
  }

  Future<void> _seedSpeechProgram(
      AppProvider app, TherapyProgram program, int stamp) async {
    final lettersSection = await _createSection(app, program,
        id: 'speech_letters_$stamp', title: 'الحروف', sortOrder: 1);
    for (final letter in _arabicLetterContent) {
      final skill = await _createSkill(
        app,
        program,
        lettersSection,
        id: 'speech_letter_${letter.id}_$stamp',
        title: 'حرف ${letter.letter}',
        description:
            'تدريب حرف ${letter.letter} بالحركات والمواضع داخل الكلمة والجملة.',
      );
      for (final vocalization in _vocalizations) {
        await _createActivity(
          app,
          program,
          skill,
          id: 'speech_${letter.id}_${vocalization.id}_$stamp',
          title:
              'حرف ${letter.letter}${vocalization.mark} - ${vocalization.name}',
          instructions: _letterStructuredContent(letter, vocalization),
          homework: letter.homework,
          evaluationType: 'speech',
        );
      }
    }

    final organs = await _createSection(app, program,
        id: 'speech_organs_$stamp', title: 'أعضاء النطق', sortOrder: 2);
    await _seedSimpleSpeechSection(app, program, organs, stamp, const [
      _ContentSkill('تمارين الشفاه', [
        _ContentActivity(
            'ضم الشفاه وفتحها',
            'اطلب من الطفل ضم الشفاه ثم فتحها 10 مرات أمام المرآة.',
            'كرر تمرين ضم وفتح الشفاه مرتين يوميًا.'),
        _ContentActivity(
            'ابتسامة ثم ضم',
            'انتقل بين الابتسامة وضم الشفاه ببطء مع العد.',
            'نفذ 10 محاولات ابتسامة ثم ضم مع ولي الأمر.'),
      ]),
      _ContentSkill('تمارين اللسان', [
        _ContentActivity(
            'رفع اللسان',
            'يرفع الطفل اللسان خلف الأسنان العلوية ثم يعود للوضع الطبيعي.',
            'كرر رفع اللسان 10 مرات أمام المرآة.'),
        _ContentActivity(
            'تحريك اللسان يمينًا ويسارًا',
            'حرك اللسان باتجاه زاويتي الفم مع ثبات الفك قدر الإمكان.',
            'نفذ 10 حركات يمين ويسار ببطء.'),
      ]),
      _ContentSkill('تمارين الفك', [
        _ContentActivity(
            'فتح وإغلاق الفك',
            'فتح الفم وإغلاقه ببطء مع مراقبة التحكم.',
            'كرر التمرين 10 مرات بدون استعجال.'),
      ]),
      _ContentSkill('النفخ والشفط والتنفس', [
        _ContentActivity(
            'نفخ الريشة',
            'ينفخ الطفل ريشة أو منديلًا خفيفًا لمسافة قصيرة.',
            'انفخ منديلًا خفيفًا 5 مرات.'),
        _ContentActivity(
            'الشفط بالشفاطة',
            'استخدم شفاطة لشرب كمية بسيطة أو نقل ورقة خفيفة.',
            'تدريب شفط قصير تحت إشراف ولي الأمر.'),
        _ContentActivity(
            'شهيق وزفير منظم',
            'خذ شهيقًا من الأنف ثم زفيرًا من الفم قبل النطق.',
            'كرر شهيق وزفير 5 مرات قبل التدريب المنزلي.'),
      ]),
    ]);

    final auditory = await _createSection(app, program,
        id: 'speech_auditory_$stamp', title: 'التمييز السمعي', sortOrder: 3);
    await _seedSimpleSpeechSection(app, program, auditory, stamp, const [
      _ContentSkill('تمييز صوت الحرف', [
        _ContentActivity(
            'اسمع حرف الهدف',
            'اعرض كلمات فيها صوت الهدف وأخرى لا تحتويه، والطفل يرفع يده عند سماعه.',
            'استمع إلى 6 كلمات وحدد هل يوجد صوت الهدف أم لا.'),
      ]),
      _ContentSkill('تمييز كلمتين متشابهتين', [
        _ContentActivity(
            'اختيار الكلمة الصحيحة',
            'قل كلمتين متقاربتين صوتيًا واطلب من الطفل الإشارة للصورة الصحيحة.',
            'كرر 5 أزواج كلمات متشابهة مع ولي الأمر.'),
      ]),
      _ContentSkill('اختيار الصوت الصحيح', [
        _ContentActivity(
            'أي صوت سمعت؟',
            'يشير الطفل إلى الحرف أو الصورة التي تمثل الصوت المسموع.',
            'اختر الصوت الصحيح من بين خيارين في 5 محاولات.'),
      ]),
    ]);

    final words = await _createSection(app, program,
        id: 'speech_words_sentences_$stamp',
        title: 'الكلمات والجمل',
        sortOrder: 4);
    await _seedSimpleSpeechSection(app, program, words, stamp, const [
      _ContentSkill('كلمات بسيطة', [
        _ContentActivity(
            'تسمية صور بسيطة',
            'سمّ صورًا يومية مثل باب، ماء، كرة، قلم.',
            'سمّ 5 أشياء في المنزل بصوت واضح.'),
      ]),
      _ContentSkill('جمل من كلمتين', [
        _ContentActivity(
            'بناء جملة قصيرة',
            'استخدم نمطًا مثل: أريد ماء، هذه كرة، باب مفتوح.',
            'كوّن 5 جمل من كلمتين مع ولي الأمر.'),
      ]),
      _ContentSkill('جمل من ثلاث كلمات', [
        _ContentActivity(
            'توسيع الجملة',
            'وسّع الجملة إلى ثلاث كلمات مثل: أريد ماء بارد.',
            'قل 3 جمل من ثلاث كلمات عن صور أو أشياء في المنزل.'),
      ]),
    ]);
  }

  Future<void> _seedSensoryProgram(
      AppProvider app, TherapyProgram program, int stamp) async {
    const sections = [
      _ContentSection('sensory_auditory', 'أنشطة سمعية', 1, [
        _ContentSkill('تمييز الأصوات', [
          _ContentActivity(
              'تمييز صوت الحيوان',
              'استمع إلى صوت حيوان واختر الصورة المناسبة.',
              'استمع إلى 3 أصوات حيوانات واختر اسم الحيوان.'),
          _ContentActivity(
              'تحديد مصدر الصوت',
              'حدد هل الصوت من اليمين أو اليسار أو الأمام.',
              'حدد مصدر صوت بسيط داخل الغرفة 5 مرات.'),
          _ContentActivity(
              'اتباع صوت معين',
              'تحرك أو أشر عند سماع الصوت المتفق عليه فقط.',
              'نفذ لعبة صوت الهدف لمدة 3 دقائق.'),
        ]),
      ]),
      _ContentSection('sensory_visual', 'أنشطة بصرية', 2, [
        _ContentSkill('انتباه بصري', [
          _ContentActivity(
              'تتبع جسم متحرك',
              'تتبع كرة أو ضوء متحرك بالعين دون تحريك الرأس قدر الإمكان.',
              'تتبع جسمًا متحركًا ببطء لمدة دقيقة.'),
          _ContentActivity('مطابقة ألوان', 'طابق بطاقات أو مكعبات حسب اللون.',
              'طابق 5 ألوان في المنزل.'),
          _ContentActivity(
              'فرز أشكال',
              'افرز دائرة ومربع ومثلث في مجموعات واضحة.',
              'افرز 6 أشكال أو ألعاب حسب الشكل.'),
        ]),
      ]),
      _ContentSection('sensory_tactile', 'أنشطة لمسية', 3, [
        _ContentSkill('استكشاف اللمس', [
          _ContentActivity(
              'لمس خامات مختلفة',
              'المس قطنًا وإسفنجًا وورقًا وخامة خشنة مع وصف الإحساس.',
              'المس 3 خامات وقل: ناعم أو خشن.'),
          _ContentActivity(
              'تمييز ناعم وخشن',
              'صنف خامات ناعمة وخشنة في مجموعتين.',
              'صنف 4 أشياء من المنزل حسب الملمس.'),
          _ContentActivity(
              'الصندوق الحسي',
              'ابحث عن شيء داخل صندوق يحتوي خامات آمنة ومختلفة.',
              'ابحث عن لعبتين داخل كيس أو صندوق حسي.'),
        ]),
      ]),
      _ContentSection('sensory_balance', 'التوازن والحركة', 4, [
        _ContentSkill('توازن وحركة كبيرة', [
          _ContentActivity('المشي على خط', 'امش على خط مستقيم مع النظر للأمام.',
              'امش على خط مرسوم على الأرض 3 مرات.'),
          _ContentActivity(
              'الوقوف على قدم واحدة',
              'قف على قدم واحدة لثوان قصيرة مع دعم عند الحاجة.',
              'حاول الوقوف على قدم واحدة 3 مرات لكل قدم.'),
          _ContentActivity('القفز', 'اقفز في مكان محدد مع الحفاظ على الأمان.',
              'اقفز 5 قفزات داخل دائرة مرسومة.'),
          _ContentActivity(
              'رمي والتقاط كرة',
              'ارم الكرة والتقطها من مسافة مناسبة.',
              'ارم والتقط كرة خفيفة 10 مرات.'),
        ]),
      ]),
      _ContentSection('sensory_visual_motor', 'التكامل البصري الحركي', 5, [
        _ContentSkill('عين ويد', [
          _ContentActivity('تتبع خط', 'تتبع خطًا مستقيمًا أو متعرجًا بالقلم.',
              'تتبع خطًا قصيرًا على ورقة.'),
          _ContentActivity('نسخ شكل', 'انسخ دائرة أو مربعًا حسب قدرة الطفل.',
              'انسخ شكلين بسيطين.'),
          _ContentActivity(
              'إدخال خرز في خيط',
              'أدخل خرزًا كبيرًا في خيط آمن مع متابعة اليد والعين.',
              'أدخل 5 خرزات كبيرة في خيط.'),
          _ContentActivity(
              'قص ولصق بسيط',
              'قص خطًا قصيرًا ثم ألصق الشكل في مكانه.',
              'قص شريطًا قصيرًا بمساعدة ولي الأمر.'),
        ]),
      ]),
    ];

    for (final sectionContent in sections) {
      final section = await _createSection(app, program,
          id: '${sectionContent.id}_$stamp',
          title: sectionContent.title,
          sortOrder: sectionContent.sortOrder);
      await _seedSimpleSensorySection(
          app, program, section, stamp, sectionContent.skills);
    }
  }

  Future<ProgramSection> _createSection(
    AppProvider app,
    TherapyProgram program, {
    required String id,
    required String title,
    required int sortOrder,
  }) async {
    final section = ProgramSection(
      id: 'section_${program.id}_$id',
      centerId: app.activeCenterId,
      programId: program.id,
      title: title,
      sortOrder: sortOrder,
    );
    await app.saveProgramSection(section);
    return section;
  }

  Future<ProgramSkill> _createSkill(
    AppProvider app,
    TherapyProgram program,
    ProgramSection section, {
    required String id,
    required String title,
    required String description,
  }) async {
    final skill = ProgramSkill(
      id: 'skill_${program.id}_$id',
      centerId: app.activeCenterId,
      programId: program.id,
      sectionId: section.id,
      title: title,
      description: description,
    );
    await app.saveProgramSkill(skill);
    return skill;
  }

  Future<void> _createActivity(
    AppProvider app,
    TherapyProgram program,
    ProgramSkill skill, {
    required String id,
    required String title,
    required String instructions,
    required String homework,
    required String evaluationType,
  }) {
    return app.saveProgramActivity(ProgramActivity(
      id: 'activity_${program.id}_$id',
      centerId: app.activeCenterId,
      programId: program.id,
      skillId: skill.id,
      title: title,
      instructions: instructions,
      homework: homework,
      evaluationType: evaluationType,
    ));
  }

  Future<void> _seedSimpleSpeechSection(
    AppProvider app,
    TherapyProgram program,
    ProgramSection section,
    int stamp,
    List<_ContentSkill> skills,
  ) async {
    for (final contentSkill in skills) {
      final skill = await _createSkill(
        app,
        program,
        section,
        id: '${section.id}_${contentSkill.title.hashCode}_$stamp',
        title: contentSkill.title,
        description: 'نشاط نطقي عملي قابل للتقييم السريع.',
      );
      for (var index = 0; index < contentSkill.activities.length; index++) {
        final activity = contentSkill.activities[index];
        await _createActivity(app, program, skill,
            id: '${skill.id}_$index',
            title: activity.title,
            instructions: activity.instructions,
            homework: activity.homework,
            evaluationType: 'speech');
      }
    }
  }

  Future<void> _seedSimpleSensorySection(
    AppProvider app,
    TherapyProgram program,
    ProgramSection section,
    int stamp,
    List<_ContentSkill> skills,
  ) async {
    for (final contentSkill in skills) {
      final skill = await _createSkill(
        app,
        program,
        section,
        id: '${section.id}_${contentSkill.title.hashCode}_$stamp',
        title: contentSkill.title,
        description: 'نشاط تكامل حسي بتدرج وملاحظة أداء واضحة.',
      );
      for (var index = 0; index < contentSkill.activities.length; index++) {
        final activity = contentSkill.activities[index];
        await _createActivity(app, program, skill,
            id: '${skill.id}_$index',
            title: activity.title,
            instructions: activity.instructions,
            homework: activity.homework,
            evaluationType: 'sensory');
      }
    }
  }

  String _letterStructuredContent(
      _LetterContent letter, _Vocalization vocalization) {
    return jsonEncode({
      'kind': 'speechLetter',
      'letter': letter.letter,
      'vocalization': vocalization.name,
      'letterDisplay': _displayLetterWithVocalization(letter, vocalization),
      'position': 'كل المواضع',
      'initialWords': letter.initial,
      'middleWords': letter.middle,
      'finalWords': letter.finalWords,
      'sentence': letter.sentence,
      'homework': letter.homework,
    });
  }

  String _displayLetterWithVocalization(
      _LetterContent letter, _Vocalization vocalization) {
    if (letter.id == 'alef') {
      return switch (vocalization.id) {
        'fatha' => 'أَ',
        'kasra' => 'إِ',
        'damma' => 'أُ',
        'alef_madd' => 'آ',
        'yaa_madd' => 'إي',
        'waw_madd' => 'أو',
        _ => '${letter.letter}${vocalization.mark}',
      };
    }
    return '${letter.letter}${vocalization.mark}';
  }
}

class _StructuredLetterContent {
  const _StructuredLetterContent({
    required this.letterDisplay,
    required this.initialWords,
    required this.middleWords,
    required this.finalWords,
    required this.sentence,
    required this.homework,
  });

  final String letterDisplay;
  final List<String> initialWords;
  final List<String> middleWords;
  final List<String> finalWords;
  final String sentence;
  final String homework;

  String get preview =>
      'الحرف: $letterDisplay\nأول: ${initialWords.join(' - ')}\nوسط: ${middleWords.join(' - ')}\nآخر: ${finalWords.join(' - ')}';

  static _StructuredLetterContent? tryParse(ProgramActivity activity) {
    try {
      final json = jsonDecode(activity.instructions);
      if (json is! Map<String, dynamic> || json['kind'] != 'speechLetter') {
        return null;
      }
      return _StructuredLetterContent(
        letterDisplay: json['letterDisplay'] as String? ?? '',
        initialWords: _stringList(json['initialWords']),
        middleWords: _stringList(json['middleWords']),
        finalWords: _stringList(json['finalWords']),
        sentence: json['sentence'] as String? ?? '',
        homework: json['homework'] as String? ?? activity.homework,
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

class _LetterContent {
  const _LetterContent({
    required this.id,
    required this.letter,
    required this.initial,
    required this.middle,
    required this.finalWords,
    required this.sentence,
    required this.homework,
  });

  final String id;
  final String letter;
  final List<String> initial;
  final List<String> middle;
  final List<String> finalWords;
  final String sentence;
  final String homework;
}

class _ContentSection {
  const _ContentSection(this.id, this.title, this.sortOrder, this.skills);

  final String id;
  final String title;
  final int sortOrder;
  final List<_ContentSkill> skills;
}

class _ContentSkill {
  const _ContentSkill(this.title, this.activities);

  final String title;
  final List<_ContentActivity> activities;
}

class _ContentActivity {
  const _ContentActivity(this.title, this.instructions, this.homework);

  final String title;
  final String instructions;
  final String homework;
}

class _Vocalization {
  const _Vocalization(this.id, this.name, this.mark);

  final String id;
  final String name;
  final String mark;
}

const _vocalizations = [
  _Vocalization('fatha', 'فتحة', 'َ'),
  _Vocalization('kasra', 'كسرة', 'ِ'),
  _Vocalization('damma', 'ضمة', 'ُ'),
  _Vocalization('sukoon', 'سكون', 'ْ'),
  _Vocalization('alef_madd', 'مد بالألف', 'ا'),
  _Vocalization('yaa_madd', 'مد بالياء', 'ي'),
  _Vocalization('waw_madd', 'مد بالواو', 'و'),
];

const _arabicLetterContent = [
  _LetterContent(
      id: 'alef',
      letter: 'أ',
      initial: ['أسد', 'أرنب', 'أذن'],
      middle: ['فأس', 'رأس', 'سأل'],
      finalWords: ['ملأ', 'بدأ', 'قرأ'],
      sentence: 'أحمد رأى أسدًا.',
      homework: 'كرر كلمات حرف أ 5 مرات مع ولي الأمر.'),
  _LetterContent(
      id: 'baa',
      letter: 'ب',
      initial: ['باب', 'بطة', 'برتقال'],
      middle: ['كبير', 'حبل', 'جبن'],
      finalWords: ['كتاب', 'كوب', 'ثوب'],
      sentence: 'باسم فتح الباب.',
      homework: 'كرر 5 كلمات فيها حرف ب بصوت واضح.'),
  _LetterContent(
      id: 'taa',
      letter: 'ت',
      initial: ['تمر', 'تاج', 'تفاح'],
      middle: ['كتاب', 'ستار', 'مفتاح'],
      finalWords: ['بيت', 'زيت', 'حوت'],
      sentence: 'تامر أكل تفاحة.',
      homework: 'درّب حرف ت في كلمات قصيرة.'),
  _LetterContent(
      id: 'thaa',
      letter: 'ث',
      initial: ['ثعلب', 'ثوب', 'ثلج'],
      middle: ['مثال', 'كثير', 'أثاث'],
      finalWords: ['مثلث', 'ليث', 'بحث'],
      sentence: 'ثامر لبس ثوبًا.',
      homework: 'كرر كلمات حرف ث ببطء مع الانتباه لموضع اللسان.'),
  _LetterContent(
      id: 'jeem',
      letter: 'ج',
      initial: ['جمل', 'جزر', 'جرس'],
      middle: ['عجلة', 'دجاجة', 'رجل'],
      finalWords: ['درج', 'ثلج', 'برج'],
      sentence: 'جنى سمعت الجرس.',
      homework: 'كرر 5 كلمات لحرف ج مع ولي الأمر.'),
  _LetterContent(
      id: 'haa',
      letter: 'ح',
      initial: ['حوت', 'حليب', 'حصان'],
      middle: ['بحر', 'نحلة', 'رحلة'],
      finalWords: ['تفاح', 'مفتاح', 'مصباح'],
      sentence: 'حسام شرب الحليب.',
      homework: 'كرر حرف ح مع نفس هادئ وواضح.'),
  _LetterContent(
      id: 'khaa',
      letter: 'خ',
      initial: ['خبز', 'خروف', 'خيار'],
      middle: ['أخضر', 'نخلة', 'بخار'],
      finalWords: ['مطبخ', 'خوخ', 'صاروخ'],
      sentence: 'خالد أكل خبزًا.',
      homework: 'درّب حرف خ في أول ووسط وآخر الكلمة.'),
  _LetterContent(
      id: 'dal',
      letter: 'د',
      initial: ['دار', 'دب', 'دجاج'],
      middle: ['مدرسة', 'حديقة', 'هدية'],
      finalWords: ['يد', 'ولد', 'برد'],
      sentence: 'دانا دخلت الدار.',
      homework: 'كرر كلمات حرف د أمام المرآة.'),
  _LetterContent(
      id: 'thal',
      letter: 'ذ',
      initial: ['ذرة', 'ذئب', 'ذهب'],
      middle: ['أذان', 'مذياع', 'حذاء'],
      finalWords: ['لذيذ', 'نافذ', 'تلميذ'],
      sentence: 'ذهب ذياب إلى البيت.',
      homework: 'كرر كلمات حرف ذ ببطء ووضوح.'),
  _LetterContent(
      id: 'raa',
      letter: 'ر',
      initial: ['رمان', 'رأس', 'ريشة'],
      middle: ['كرسي', 'وردة', 'قرد'],
      finalWords: ['نار', 'قمر', 'بحر'],
      sentence: 'رائد رسم وردة.',
      homework: 'كرر كلمات حرف ر دون استعجال.'),
  _LetterContent(
      id: 'zay',
      letter: 'ز',
      initial: ['زهرة', 'زيت', 'زر'],
      middle: ['جزرة', 'ميزان', 'غزال'],
      finalWords: ['موز', 'كنز', 'خبز'],
      sentence: 'زينب قطفت زهرة.',
      homework: 'كرر كلمات حرف ز 5 مرات.'),
  _LetterContent(
      id: 'seen',
      letter: 'س',
      initial: ['سمكة', 'سيارة', 'ساعة'],
      middle: ['عسل', 'بسمة', 'مدرسة'],
      finalWords: ['جرس', 'شمس', 'كأس'],
      sentence: 'سامي رأى سمكة.',
      homework: 'كرر 5 كلمات بصوت واضح مع ولي الأمر.'),
  _LetterContent(
      id: 'sheen',
      letter: 'ش',
      initial: ['شمس', 'شجرة', 'شاي'],
      middle: ['عشب', 'مشط', 'بشرة'],
      finalWords: ['عش', 'ريش', 'فراش'],
      sentence: 'شادي رأى الشمس.',
      homework: 'كرر كلمات حرف ش مع إطالة خفيفة للصوت.'),
  _LetterContent(
      id: 'sad',
      letter: 'ص',
      initial: ['صقر', 'صحن', 'صوت'],
      middle: ['عصفور', 'مصباح', 'قصة'],
      finalWords: ['قميص', 'لص', 'نص'],
      sentence: 'صالح سمع صوتًا.',
      homework: 'كرر حرف ص في كلمات قصيرة.'),
  _LetterContent(
      id: 'dad',
      letter: 'ض',
      initial: ['ضفدع', 'ضرس', 'ضوء'],
      middle: ['أخضر', 'مضرب', 'فضاء'],
      finalWords: ['بيض', 'أرض', 'حوض'],
      sentence: 'ضاري رأى ضفدعًا.',
      homework: 'درّب حرف ض في ثلاث كلمات.'),
  _LetterContent(
      id: 'taa_emphatic',
      letter: 'ط',
      initial: ['طائر', 'طاولة', 'طماطم'],
      middle: ['مطر', 'قطار', 'بطاطا'],
      finalWords: ['خيط', 'شاطئ', 'محيط'],
      sentence: 'طار الطائر عاليًا.',
      homework: 'كرر كلمات حرف ط مع فتح الفم جيدًا.'),
  _LetterContent(
      id: 'zaa_emphatic',
      letter: 'ظ',
      initial: ['ظرف', 'ظبي', 'ظل'],
      middle: ['نظارة', 'عظيم', 'حظيرة'],
      finalWords: ['حفظ', 'وعظ', 'لفظ'],
      sentence: 'ظل الظبي تحت الشجرة.',
      homework: 'كرر كلمات حرف ظ ببطء.'),
  _LetterContent(
      id: 'ain',
      letter: 'ع',
      initial: ['عين', 'عنب', 'عصفور'],
      middle: ['ملعب', 'سعيد', 'ساعة'],
      finalWords: ['شموع', 'ذراع', 'شارع'],
      sentence: 'علي أكل عنبًا.',
      homework: 'كرر حرف ع مع تنفس هادئ.'),
  _LetterContent(
      id: 'ghain',
      letter: 'غ',
      initial: ['غزال', 'غيمة', 'غرفة'],
      middle: ['مغسلة', 'صغير', 'بغداد'],
      finalWords: ['صمغ', 'فراغ', 'دماغ'],
      sentence: 'غادة دخلت الغرفة.',
      homework: 'كرر كلمات حرف غ دون ضغط زائد.'),
  _LetterContent(
      id: 'faa',
      letter: 'ف',
      initial: ['فيل', 'فراشة', 'فم'],
      middle: ['مفتاح', 'دفتر', 'سفينة'],
      finalWords: ['خروف', 'رف', 'كتف'],
      sentence: 'فهد رأى فيلًا.',
      homework: 'كرر كلمات حرف ف مع نفخ خفيف.'),
  _LetterContent(
      id: 'qaf',
      letter: 'ق',
      initial: ['قلم', 'قمر', 'قطة'],
      middle: ['عقرب', 'بقرة', 'مقعد'],
      finalWords: ['طبق', 'سوق', 'طريق'],
      sentence: 'قاسم حمل قلمًا.',
      homework: 'كرر حرف ق في أول ووسط وآخر الكلمة.'),
  _LetterContent(
      id: 'kaf',
      letter: 'ك',
      initial: ['كتاب', 'كرة', 'كأس'],
      middle: ['مكتب', 'سكين', 'بكرة'],
      finalWords: ['سمك', 'ملك', 'ضحك'],
      sentence: 'كريم رمى الكرة.',
      homework: 'كرر كلمات حرف ك بوضوح.'),
  _LetterContent(
      id: 'lam',
      letter: 'ل',
      initial: ['ليمون', 'لعبة', 'لبن'],
      middle: ['قلم', 'ملعب', 'حليب'],
      finalWords: ['جمل', 'فيل', 'حبل'],
      sentence: 'ليلى لعبت باللعبة.',
      homework: 'كرر كلمات حرف ل أمام المرآة.'),
  _LetterContent(
      id: 'meem',
      letter: 'م',
      initial: ['موز', 'ماء', 'مفتاح'],
      middle: ['سمكة', 'قمر', 'حمام'],
      finalWords: ['قلم', 'نجوم', 'علم'],
      sentence: 'مها شربت ماء.',
      homework: 'كرر 5 كلمات فيها حرف م.'),
  _LetterContent(
      id: 'noon',
      letter: 'ن',
      initial: ['نمر', 'نخلة', 'نجمة'],
      middle: ['منزل', 'عنب', 'كنبة'],
      finalWords: ['حصان', 'لبن', 'عين'],
      sentence: 'نورا رأت نجمة.',
      homework: 'كرر كلمات حرف ن مع ولي الأمر.'),
  _LetterContent(
      id: 'haa_soft',
      letter: 'ه',
      initial: ['هلال', 'هدية', 'هرم'],
      middle: ['ذهب', 'مهارة', 'زهرة'],
      finalWords: ['وجه', 'مياه', 'فمه'],
      sentence: 'هند حملت هدية.',
      homework: 'كرر حرف ه بهدوء ووضوح.'),
  _LetterContent(
      id: 'waw',
      letter: 'و',
      initial: ['وردة', 'ولد', 'وجه'],
      middle: ['حوت', 'موزة', 'طاولة'],
      finalWords: ['دلو', 'نمو', 'ضوء'],
      sentence: 'وسام شم وردة.',
      homework: 'كرر كلمات حرف و مع مد قصير.'),
  _LetterContent(
      id: 'yaa',
      letter: 'ي',
      initial: ['يد', 'ياسمين', 'يمامة'],
      middle: ['بيت', 'سيارة', 'خيار'],
      finalWords: ['كرسي', 'شاي', 'وادي'],
      sentence: 'ياسر غسل يده.',
      homework: 'كرر كلمات حرف ي في مواضع مختلفة.'),
];
