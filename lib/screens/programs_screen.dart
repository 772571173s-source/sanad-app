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
    final selectedProgram = selectedProgramId == null
        ? (app.programs.isEmpty ? null : app.programs.first)
        : app.programs
            .where((program) => program.id == selectedProgramId)
            .cast<TherapyProgram?>()
            .firstWhere((program) => program != null, orElse: () => null);
    selectedProgramId = selectedProgram?.id;
    final sections = app.programSections
        .where((section) => section.programId == selectedProgram?.id)
        .toList();
    final skills = app.programSkills
        .where((skill) => skill.programId == selectedProgram?.id)
        .toList();
    final activities = app.programActivities
        .where((activity) => activity.programId == selectedProgram?.id)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (app.canManagePrograms)
              FilledButton.icon(
                  onPressed: () => _showProgramDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('ط¥ط¶ط§ظپط© ط¨ط±ظ†ط§ظ…ط¬')),
            if (app.canManagePrograms)
              FilledButton.tonalIcon(
                  onPressed: () => _seedCorePrograms(app),
                  icon: const Icon(Icons.auto_awesome),
                  label:
                      const Text('ط¥ظ†ط´ط§ط، ط§ظ„ط¨ط±ط§ظ…ط¬ ط§ظ„ط£ط³ط§ط³ظٹط©')),
          ],
        ),
        const SizedBox(height: 12),
        if (app.programs.isEmpty)
          const EmptyState(
              icon: Icons.extension_outlined,
              title: 'ظ„ط§ طھظˆط¬ط¯ ط¨ط±ط§ظ…ط¬ ط¹ظ„ط§ط¬ظٹط©',
              message:
                  'ط§ط¨ط¯ط£ ط¨ط¥ظ†ط´ط§ط، ط§ظ„ط¹ظ„ط§ط¬ ط§ظ„ظ†ط·ظ‚ظٹ ظˆط§ظ„طھظƒط§ظ…ظ„ ط§ظ„ط­ط³ظٹ ط«ظ… ط£ط¶ظپ ط§ظ„ظ…ظ‡ط§ط±ط§طھ ظˆط§ظ„ط£ظ†ط´ط·ط©.')
        else ...[
          AppCard(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: app.programs
                  .map((program) => ChoiceChip(
                        selected: program.id == selectedProgram?.id,
                        label: Text('${program.name} - ${program.type}'),
                        onSelected: (_) =>
                            setState(() => selectedProgramId = program.id),
                      ))
                  .toList(),
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
                          label: const Text('ظ…ط±ط­ظ„ط©')),
                      FilledButton.tonalIcon(
                          onPressed: selectedProgram == null || sections.isEmpty
                              ? null
                              : () => _showSkillDialog(context,
                                  selectedProgram: selectedProgram,
                                  sections: sections),
                          icon: const Icon(Icons.psychology_outlined),
                          label: const Text('ظ…ظ‡ط§ط±ط©')),
                      FilledButton.tonalIcon(
                          onPressed: selectedProgram == null || skills.isEmpty
                              ? null
                              : () => _showActivityDialog(context,
                                  selectedProgram: selectedProgram,
                                  skills: skills),
                          icon: const Icon(Icons.local_activity_outlined),
                          label: const Text('ظ†ط´ط§ط·')),
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
                  .toList();
              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(section.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 18)),
                    const SizedBox(height: 8),
                    if (sectionSkills.isEmpty)
                      const Text(
                          'ظ„ط§ طھظˆط¬ط¯ ظ…ظ‡ط§ط±ط§طھ ظپظٹ ظ‡ط°ظ‡ ط§ظ„ظ…ط±ط­ظ„ط©.')
                    else
                      ...sectionSkills.map((skill) {
                        final skillActivities = activities
                            .where((activity) => activity.skillId == skill.id)
                            .toList();
                        return ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: Text(skill.title),
                          subtitle: Text(skill.description.isEmpty
                              ? 'ظ…ظ‡ط§ط±ط© ط¹ظ„ط§ط¬ظٹط©'
                              : skill.description),
                          children: skillActivities
                              .map((activity) => ListTile(
                                    leading:
                                        const Icon(Icons.play_circle_outline),
                                    title: Text(activity.title),
                                    subtitle: Text(activity.instructions),
                                    trailing: Text(
                                        activity.evaluationType == 'sensory'
                                            ? 'ط­ط³ظٹ'
                                            : 'ظ†ط·ظ‚ظٹ'),
                                  ))
                              .toList(),
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

  Future<void> _showProgramDialog(BuildContext context) async {
    final name = TextEditingController();
    final description = TextEditingController();
    var type = 'ط§ظ„ط¹ظ„ط§ط¬ ط§ظ„ظ†ط·ظ‚ظٹ';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ط¥ط¶ط§ظپط© ط¨ط±ظ†ط§ظ…ط¬ ط¹ظ„ط§ط¬ظٹ'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: name,
                  decoration: const InputDecoration(
                      labelText: 'ط§ط³ظ… ط§ظ„ط¨ط±ظ†ط§ظ…ط¬')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration:
                    const InputDecoration(labelText: 'ظ†ظˆط¹ ط§ظ„ط¨ط±ظ†ط§ظ…ط¬'),
                items: const [
                  'ط§ظ„ط¹ظ„ط§ط¬ ط§ظ„ظ†ط·ظ‚ظٹ',
                  'ط§ظ„طھظƒط§ظ…ظ„ ط§ظ„ط­ط³ظٹ',
                  'ظ„ط؛ط© ط¥ط´ط§ط±ط©',
                  'ط£ط®ط±ظ‰'
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
                  decoration:
                      const InputDecoration(labelText: 'ظˆطµظپ ظ…ط®طھطµط±')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ط¥ظ„ط؛ط§ط،')),
          FilledButton(
              onPressed: () async {
                final app = context.read<AppProvider>();
                await runWithFeedback(context, () async {
                  if (name.text.trim().isEmpty) {
                    throw StateError('ط§ط³ظ… ط§ظ„ط¨ط±ظ†ط§ظ…ط¬ ظ…ط·ظ„ظˆط¨.');
                  }
                  await app.saveProgram(TherapyProgram(
                      id: 'program_${DateTime.now().millisecondsSinceEpoch}',
                      centerId: app.activeCenterId,
                      name: name.text.trim(),
                      type: type,
                      description: description.text.trim()));
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                });
              },
              child: const Text('ط­ظپط¸')),
        ],
      ),
    );
  }

  Future<void> _showSectionDialog(BuildContext context,
      {required TherapyProgram selectedProgram}) async {
    final title = TextEditingController();
    await _simpleSaveDialog(
      context,
      titleText: 'ط¥ط¶ط§ظپط© ظ…ط±ط­ظ„ط©',
      labelText: 'ط¹ظ†ظˆط§ظ† ط§ظ„ظ…ط±ط­ظ„ط©',
      controller: title,
      onSave: () => context.read<AppProvider>().saveProgramSection(
            ProgramSection(
                id: 'section_${DateTime.now().millisecondsSinceEpoch}',
                centerId: selectedProgram.centerId,
                programId: selectedProgram.id,
                title: title.text.trim()),
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
        title: const Text('ط¥ط¶ط§ظپط© ظ…ظ‡ط§ط±ط©'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: sectionId,
                decoration: const InputDecoration(labelText: 'ط§ظ„ظ…ط±ط­ظ„ط©'),
                items: sections
                    .map((section) => DropdownMenuItem(
                        value: section.id, child: Text(section.title)))
                    .toList(),
                onChanged: (value) => sectionId = value ?? sectionId,
              ),
              const SizedBox(height: 10),
              TextField(
                  controller: title,
                  decoration: const InputDecoration(
                      labelText: 'ط§ط³ظ… ط§ظ„ظ…ظ‡ط§ط±ط©')),
              const SizedBox(height: 10),
              TextField(
                  controller: description,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'ظˆطµظپ ط§ظ„ظ…ظ‡ط§ط±ط©')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ط¥ظ„ط؛ط§ط،')),
          FilledButton(
              onPressed: () async {
                await runWithFeedback(context, () async {
                  if (title.text.trim().isEmpty) {
                    throw StateError('ط§ط³ظ… ط§ظ„ظ…ظ‡ط§ط±ط© ظ…ط·ظ„ظˆط¨.');
                  }
                  await context.read<AppProvider>().saveProgramSkill(
                        ProgramSkill(
                            id: 'skill_${DateTime.now().millisecondsSinceEpoch}',
                            centerId: selectedProgram.centerId,
                            programId: selectedProgram.id,
                            sectionId: sectionId,
                            title: title.text.trim(),
                            description: description.text.trim()),
                      );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                });
              },
              child: const Text('ط­ظپط¸')),
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
    var evaluationType = selectedProgram.type == 'ط§ظ„طھظƒط§ظ…ظ„ ط§ظ„ط­ط³ظٹ'
        ? 'sensory'
        : 'speech';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ط¥ط¶ط§ظپط© ظ†ط´ط§ط·'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: skillId,
                  decoration:
                      const InputDecoration(labelText: 'ط§ظ„ظ…ظ‡ط§ط±ط©'),
                  items: skills
                      .map((skill) => DropdownMenuItem(
                          value: skill.id, child: Text(skill.title)))
                      .toList(),
                  onChanged: (value) => skillId = value ?? skillId,
                ),
                const SizedBox(height: 10),
                TextField(
                    controller: title,
                    decoration: const InputDecoration(
                        labelText: 'ط§ط³ظ… ط§ظ„ظ†ط´ط§ط·')),
                const SizedBox(height: 10),
                TextField(
                    controller: instructions,
                    maxLines: 2,
                    decoration:
                        const InputDecoration(labelText: 'طھط¹ظ„ظٹظ…ط§طھ')),
                const SizedBox(height: 10),
                TextField(
                    controller: homework,
                    maxLines: 2,
                    decoration: const InputDecoration(
                        labelText: 'ظˆط§ط¬ط¨ ظ…ظ‚طھط±ط­')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: evaluationType,
                  decoration:
                      const InputDecoration(labelText: 'ظ†ظˆط¹ ط§ظ„طھظ‚ظٹظٹظ…'),
                  items: const [
                    DropdownMenuItem(
                        value: 'speech',
                        child: Text('طµط­ظٹط­ / ط¬ط²ط¦ظٹ / ط®ط·ط£')),
                    DropdownMenuItem(
                        value: 'sensory',
                        child: Text('ظ„ط§ ظٹط¤ط¯ظٹ / ط¨ظ…ط³ط§ط¹ط¯ط© / ط¬ظٹط¯')),
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
              child: const Text('ط¥ظ„ط؛ط§ط،')),
          FilledButton(
              onPressed: () async {
                await runWithFeedback(context, () async {
                  if (title.text.trim().isEmpty) {
                    throw StateError('ط§ط³ظ… ط§ظ„ظ†ط´ط§ط· ظ…ط·ظ„ظˆط¨.');
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
                            evaluationType: evaluationType),
                      );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                });
              },
              child: const Text('ط­ظپط¸')),
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
              child: const Text('ط¥ظ„ط؛ط§ط،')),
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
              child: const Text('ط­ظپط¸')),
        ],
      ),
    );
  }

  Future<void> _seedCorePrograms(AppProvider app) async {
    await runWithFeedback(context, () async {
      if (app.programs
              .any((program) => program.type == 'ط§ظ„ط¹ظ„ط§ط¬ ط§ظ„ظ†ط·ظ‚ظٹ') ||
          app.programs
              .any((program) => program.type == 'ط§ظ„طھظƒط§ظ…ظ„ ط§ظ„ط­ط³ظٹ')) {
        throw StateError(
            'ط§ظ„ط¨ط±ط§ظ…ط¬ ط§ظ„ط£ط³ط§ط³ظٹط© ظ…ظˆط¬ظˆط¯ط© ظ…ط³ط¨ظ‚ظ‹ط§.');
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      final speech = TherapyProgram(
          id: 'program_speech_$now',
          centerId: app.activeCenterId,
          name: 'ط§ظ„ط¹ظ„ط§ط¬ ط§ظ„ظ†ط·ظ‚ظٹ',
          type: 'ط§ظ„ط¹ظ„ط§ط¬ ط§ظ„ظ†ط·ظ‚ظٹ',
          description:
              'ط§ظ„ط­ط±ظˆظپطŒ ط§ظ„ظƒظ„ظ…ط§طھطŒ ط§ظ„ط¬ظ…ظ„طŒ ط§ظ„طھظ…ظٹظٹط² ط§ظ„ط³ظ…ط¹ظٹطŒ ط§ظ„ظ„ط؛ط© ط§ظ„طھط¹ط¨ظٹط±ظٹط© ظˆط§ظ„ط§ط³طھظ‚ط¨ط§ظ„ظٹط©.');
      final sensory = TherapyProgram(
          id: 'program_sensory_$now',
          centerId: app.activeCenterId,
          name: 'ط§ظ„طھظƒط§ظ…ظ„ ط§ظ„ط­ط³ظٹ',
          type: 'ط§ظ„طھظƒط§ظ…ظ„ ط§ظ„ط­ط³ظٹ',
          description:
              'ط£ظ†ط´ط·ط© ط³ظ…ط¹ظٹط© ظˆط¨طµط±ظٹط© ظˆظ„ظ…ط³ظٹط© ظˆطھظˆط§ط²ظ† ظˆط­ط±ظƒط© ظˆط¥ط¯ط±ط§ظƒ.');
      await app.saveProgram(speech);
      await app.saveProgram(sensory);
      await app.saveProgramSection(ProgramSection(
          id: 'section_speech_letters_$now',
          centerId: app.activeCenterId,
          programId: speech.id,
          title: 'ط§ظ„ط­ط±ظˆظپ ظˆط§ظ„ظƒظ„ظ…ط§طھ'));
      await app.saveProgramSkill(ProgramSkill(
          id: 'skill_speech_b_$now',
          centerId: app.activeCenterId,
          programId: speech.id,
          sectionId: 'section_speech_letters_$now',
          title: 'ط¥ظ†طھط§ط¬ ط§ظ„ط­ط±ظپ ظپظٹ ط§ظ„ظƒظ„ظ…ط©',
          description: 'ط£ظˆظ„ ظˆظˆط³ط· ظˆط¢ط®ط± ط§ظ„ظƒظ„ظ…ط©'));
      await app.saveProgramActivity(ProgramActivity(
          id: 'activity_speech_words_$now',
          centerId: app.activeCenterId,
          programId: speech.id,
          skillId: 'skill_speech_b_$now',
          title: 'ط¨ط·ط§ظ‚ط§طھ ظƒظ„ظ…ط§طھ ظ‚طµظٹط±ط©',
          instructions:
              'ط§ط¹ط±ط¶ ط¨ط·ط§ظ‚ط©طŒ ط«ظ… ظ‚ظٹظ‘ظ… طµط­ظٹط­ / ط¬ط²ط¦ظٹ / ط®ط·ط£.',
          homework: 'طھط¯ط±ظٹط¨ 5 ظƒظ„ظ…ط§طھ ط£ظ…ط§ظ… ظˆظ„ظٹ ط§ظ„ط£ظ…ط±',
          evaluationType: 'speech'));
      final speechAreas = [
        ['words', 'الكلمات', 'إنتاج كلمات قصيرة', 'تدريب كلمات وظيفية'],
        [
          'sentences',
          'الجمل',
          'إنتاج جملة قصيرة',
          'تدريب جمل من كلمتين أو ثلاث'
        ],
        ['organs', 'أعضاء النطق', 'تهيئة أعضاء النطق', 'تمارين شفاه ولسان وفك'],
        [
          'auditory',
          'التمييز السمعي',
          'تمييز الصوت المستهدف',
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
      ];
      for (var index = 0; index < speechAreas.length; index++) {
        final area = speechAreas[index];
        final sectionId = 'section_speech_${area[0]}_$now';
        final skillId = 'skill_speech_${area[0]}_$now';
        await app.saveProgramSection(ProgramSection(
            id: sectionId,
            centerId: app.activeCenterId,
            programId: speech.id,
            title: area[1],
            sortOrder: index + 2));
        await app.saveProgramSkill(ProgramSkill(
            id: skillId,
            centerId: app.activeCenterId,
            programId: speech.id,
            sectionId: sectionId,
            title: area[2],
            description: area[3]));
        await app.saveProgramActivity(ProgramActivity(
            id: 'activity_speech_${area[0]}_$now',
            centerId: app.activeCenterId,
            programId: speech.id,
            skillId: skillId,
            title: area[3],
            instructions: 'اختر بطاقة تدريب ثم قيّم الأداء: صحيح / جزئي / خطأ.',
            homework: 'تكرار النشاط في المنزل لمدة 5 دقائق',
            evaluationType: 'speech'));
      }
      await app.saveProgramSection(ProgramSection(
          id: 'section_sensory_balance_$now',
          centerId: app.activeCenterId,
          programId: sensory.id,
          title: 'ط§ظ„طھظˆط§ط²ظ† ظˆط§ظ„ط­ط±ظƒط©'));
      await app.saveProgramSkill(ProgramSkill(
          id: 'skill_sensory_balance_$now',
          centerId: app.activeCenterId,
          programId: sensory.id,
          sectionId: 'section_sensory_balance_$now',
          title: 'طھظ†ط¸ظٹظ… ط§ظ„ط§ط³طھط¬ط§ط¨ط© ط§ظ„ط­ط±ظƒظٹط©',
          description: 'طھط¯ط±ط¬ ط­ط±ظƒظٹ ط¢ظ…ظ† ظˆظ…ظ„ط§ط­ط¸ط§طھ ط£ط¯ط§ط،'));
      await app.saveProgramActivity(ProgramActivity(
          id: 'activity_sensory_path_$now',
          centerId: app.activeCenterId,
          programId: sensory.id,
          skillId: 'skill_sensory_balance_$now',
          title: 'ظ…ط³ط§ط± طھظˆط§ط²ظ† ط¨ط³ظٹط·',
          instructions:
              'ظٹظ…ط´ظٹ ط§ظ„ط·ظپظ„ ط¹ظ„ظ‰ ظ…ط³ط§ط± ظ…ط­ط¯ط¯ ظ…ط¹ ط¯ط¹ظ… طھط¯ط±ظٹط¬ظٹ.',
          homework: 'ظ†ط´ط§ط· طھظˆط§ط²ظ† ط¢ظ…ظ† ظ„ظ…ط¯ط© 3 ط¯ظ‚ط§ط¦ظ‚',
          evaluationType: 'sensory'));
      final sensoryAreas = [
        [
          'auditory',
          'الأنشطة السمعية',
          'تحمل المثير السمعي',
          'تمييز أصوات بيئية'
        ],
        ['visual', 'الأنشطة البصرية', 'تتبع بصري', 'متابعة هدف بصري متحرك'],
        ['tactile', 'الأنشطة اللمسية', 'تقبل اللمس', 'استكشاف خامات مختلفة'],
        ['movement', 'الحركة', 'تنظيم الحركة', 'نشاط حركة موجه'],
        [
          'perception',
          'الإدراك',
          'مطابقة وتصنيف',
          'تصنيف أشياء حسب اللون أو الشكل'
        ],
        ['motor', 'التكامل الحركي', 'تناسق حركي', 'نشاط يد وعين'],
      ];
      for (var index = 0; index < sensoryAreas.length; index++) {
        final area = sensoryAreas[index];
        final sectionId = 'section_sensory_${area[0]}_$now';
        final skillId = 'skill_sensory_${area[0]}_$now';
        await app.saveProgramSection(ProgramSection(
            id: sectionId,
            centerId: app.activeCenterId,
            programId: sensory.id,
            title: area[1],
            sortOrder: index + 2));
        await app.saveProgramSkill(ProgramSkill(
            id: skillId,
            centerId: app.activeCenterId,
            programId: sensory.id,
            sectionId: sectionId,
            title: area[2],
            description: area[3]));
        await app.saveProgramActivity(ProgramActivity(
            id: 'activity_sensory_${area[0]}_$now',
            centerId: app.activeCenterId,
            programId: sensory.id,
            skillId: skillId,
            title: area[3],
            instructions:
                'نفذ النشاط تدريجيًا ثم قيّم الأداء: لا يؤدي / يؤدي بمساعدة / يؤدي جيدًا.',
            homework: 'نشاط منزلي قصير بإشراف ولي الأمر',
            evaluationType: 'sensory'));
      }
    }, success: 'طھظ… ط¥ظ†ط´ط§ط، ط§ظ„ط¨ط±ط§ظ…ط¬ ط§ظ„ط£ط³ط§ط³ظٹط©.');
  }
}
