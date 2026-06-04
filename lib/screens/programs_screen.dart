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
            .toList();
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
            ],
          ),
        const SizedBox(height: 12),
        if (app.programs.isEmpty)
          const EmptyState(
            icon: Icons.extension_outlined,
            title: 'لا توجد برامج علاجية',
            message:
                'أنشئ العلاج النطقي والتكامل الحسي، ثم أضف المراحل والمهارات والأنشطة.',
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
              final sectionSkills =
                  skills.where((skill) => skill.sectionId == section.id);
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
                            return ListTile(
                              leading: const Icon(Icons.play_circle_outline),
                              title: Text(activity.title),
                              subtitle: Text(activity.instructions),
                              trailing: Text(
                                  activity.evaluationType == 'sensory'
                                      ? 'تكامل حسي'
                                      : 'نطقي'),
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
                        child: Text('لا يؤدي / يؤدي بمساعدة / يؤدي جيدًا')),
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

  Future<void> _seedCorePrograms(AppProvider app) async {
    await runWithFeedback(context, () async {
      if (app.programs.any((program) => program.type == 'العلاج النطقي') ||
          app.programs.any((program) => program.type == 'التكامل الحسي')) {
        throw StateError('البرامج الأساسية موجودة مسبقًا.');
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final speech = TherapyProgram(
        id: 'program_speech_$now',
        centerId: app.activeCenterId,
        name: 'العلاج النطقي',
        type: 'العلاج النطقي',
        description:
            'الحروف، الكلمات، الجمل، أعضاء النطق، التمييز السمعي، التنفس، اللغة التعبيرية والاستقبالية.',
      );
      final sensory = TherapyProgram(
        id: 'program_sensory_$now',
        centerId: app.activeCenterId,
        name: 'التكامل الحسي',
        type: 'التكامل الحسي',
        description:
            'أنشطة سمعية وبصرية ولمسية وتوازن وحركة وإدراك وتكامل حركي.',
      );
      await app.saveProgram(speech);
      await app.saveProgram(sensory);

      await _seedProgramTree(
        app: app,
        program: speech,
        evaluationType: 'speech',
        areas: const [
          ['letters', 'الحروف', 'إنتاج الحرف', 'بطاقات حروف وكلمات قصيرة'],
          ['words', 'الكلمات', 'إنتاج كلمات', 'تدريب كلمات وظيفية'],
          ['sentences', 'الجمل', 'إنتاج جملة', 'جمل من كلمتين أو ثلاث'],
          [
            'organs',
            'أعضاء النطق',
            'تهيئة أعضاء النطق',
            'تمارين شفاه ولسان وفك'
          ],
          [
            'auditory',
            'التمييز السمعي',
            'تمييز الصوت',
            'استماع واختيار الصوت الصحيح'
          ],
          ['breathing', 'التنفس', 'تنظيم النفس', 'شهيق وزفير مضبوط قبل النطق'],
          [
            'expressive',
            'اللغة التعبيرية',
            'تسمية ووصف',
            'تسمية صورة أو وصف فعل'
          ],
          [
            'receptive',
            'اللغة الاستقبالية',
            'اتباع التعليمات',
            'تنفيذ أمر بسيط أو مركب'
          ],
        ],
      );
      await _seedProgramTree(
        app: app,
        program: sensory,
        evaluationType: 'sensory',
        areas: const [
          [
            'auditory',
            'الأنشطة السمعية',
            'تحمل المثير السمعي',
            'تمييز أصوات بيئية'
          ],
          ['visual', 'الأنشطة البصرية', 'تتبع بصري', 'متابعة هدف بصري متحرك'],
          ['tactile', 'الأنشطة اللمسية', 'تقبل اللمس', 'استكشاف خامات مختلفة'],
          ['balance', 'التوازن', 'توازن ثابت ومتحرك', 'مسار توازن بسيط'],
          ['movement', 'الحركة', 'تنظيم الحركة', 'نشاط حركة موجه'],
          [
            'perception',
            'الإدراك',
            'مطابقة وتصنيف',
            'تصنيف حسب اللون أو الشكل'
          ],
          ['motor', 'التكامل الحركي', 'تناسق حركي', 'نشاط يد وعين'],
        ],
      );
    }, success: 'تم إنشاء البرامج الأساسية.');
  }

  Future<void> _seedProgramTree({
    required AppProvider app,
    required TherapyProgram program,
    required String evaluationType,
    required List<List<String>> areas,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var index = 0; index < areas.length; index++) {
      final area = areas[index];
      final sectionId = 'section_${program.id}_${area[0]}_$now';
      final skillId = 'skill_${program.id}_${area[0]}_$now';
      await app.saveProgramSection(ProgramSection(
        id: sectionId,
        centerId: app.activeCenterId,
        programId: program.id,
        title: area[1],
        sortOrder: index + 1,
      ));
      await app.saveProgramSkill(ProgramSkill(
        id: skillId,
        centerId: app.activeCenterId,
        programId: program.id,
        sectionId: sectionId,
        title: area[2],
        description: area[3],
      ));
      await app.saveProgramActivity(ProgramActivity(
        id: 'activity_${program.id}_${area[0]}_$now',
        centerId: app.activeCenterId,
        programId: program.id,
        skillId: skillId,
        title: area[3],
        instructions: evaluationType == 'sensory'
            ? 'نفذ النشاط تدريجيًا ثم قيّم الأداء.'
            : 'اعرض النشاط ثم قيّم الاستجابة.',
        homework: evaluationType == 'sensory'
            ? 'نشاط منزلي قصير بإشراف ولي الأمر.'
            : 'تكرار التدريب في المنزل لمدة 5 دقائق.',
        evaluationType: evaluationType,
      ));
    }
  }
}
