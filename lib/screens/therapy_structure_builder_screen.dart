import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../widgets/app_widgets.dart';
import '../widgets/feedback.dart';

class TherapyStructureBuilderScreen extends StatelessWidget {
  const TherapyStructureBuilderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    if (!app.canManageTherapyStructure) {
      return const EmptyState(
        icon: Icons.lock_outline,
        title: 'هذه الشاشة خاصة ببناء الهيكل العلاجي',
        message:
            'القوالب العلاجية يديرها مدخل البرامج أو مدير المركز، أما الأخصائي فيستخدمها داخل تقييم الطالب.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SemanticAlertCard(
          kind: SemanticAlertKind.info,
          icon: Icons.schema_outlined,
          title: 'Therapy Structure Builder',
          message:
              'هذه الشاشة تبني القوالب العلاجية فقط. لا يوجد طالب هنا، ولا جلسة، ولا تقرير. التقييم يستخدم هذه القوالب لاحقًا لتوليد نقاط الضعف والأهداف والتدريبات.',
        ),
        const SizedBox(height: AppSpacing.md),
        _AssessmentStructureSheet(app: app),
        const SizedBox(height: AppSpacing.lg),
        _SpeechSoundMatrixSheet(app: app),
      ],
    );
  }
}

class _AssessmentStructureSheet extends StatelessWidget {
  const _AssessmentStructureSheet({required this.app});

  final AppProvider app;

  @override
  Widget build(BuildContext context) {
    return TherapyCard(
      icon: Icons.fact_check_outlined,
      title: 'Standard Assessment Structure',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionAddRow(app: app),
          const SizedBox(height: AppSpacing.md),
          if (app.assessmentSections.isEmpty)
            const EmptyState(
              icon: Icons.library_add_outlined,
              title: 'ابدأ بإضافة أول قسم',
              message:
                  'مثال: الوجه، الفك، الشفاه. بعد ذلك أضف البنود والاحتمالات العلاجية داخل القسم.',
            )
          else
            ...app.assessmentSections.map(
              (section) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _SectionTemplateCard(app: app, section: section),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionAddRow extends StatefulWidget {
  const _SectionAddRow({required this.app});

  final AppProvider app;

  @override
  State<_SectionAddRow> createState() => _SectionAddRowState();
}

class _SectionAddRowState extends State<_SectionAddRow> {
  final title = TextEditingController();
  final description = TextEditingController();

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('إضافة قسم تقييم', style: SanadText.subtitle(context)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'اسم القسم'),
                ),
              ),
              SizedBox(
                width: 360,
                child: TextField(
                  controller: description,
                  decoration:
                      const InputDecoration(labelText: 'وصف مختصر اختياري'),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _save(context),
                icon: const Icon(Icons.add),
                label: const Text('إضافة'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    if (title.text.trim().isEmpty) return;
    final now = DateTime.now().toIso8601String();
    await runWithFeedback(
      context,
      () => widget.app.saveAssessmentSectionTemplate(
        AssessmentSectionTemplate(
          id: 'section_${DateTime.now().microsecondsSinceEpoch}',
          centerId: widget.app.activeCenterId,
          title: title.text.trim(),
          description: description.text.trim(),
          sortOrder: widget.app.assessmentSections.length,
          createdAt: now,
          updatedAt: now,
        ),
      ),
      loading: 'جاري حفظ القسم...',
      success: 'تم حفظ القسم.',
    );
    title.clear();
    description.clear();
  }
}

class _SectionTemplateCard extends StatelessWidget {
  const _SectionTemplateCard({required this.app, required this.section});

  final AppProvider app;
  final AssessmentSectionTemplate section;

  @override
  Widget build(BuildContext context) {
    final items =
        app.assessmentItems.where((item) => item.sectionId == section.id);
    return AppCard(
      highlight: true,
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: Text(section.title, style: SanadText.title(context)),
        subtitle: section.description.isEmpty
            ? const Text('قسم تقييم')
            : Text(section.description),
        trailing: IconButton(
          tooltip: 'حذف القسم',
          onPressed: () => app.deleteAssessmentSectionTemplate(section.id),
          icon: const Icon(Icons.delete_outline),
        ),
        children: [
          _ItemAddRow(app: app, section: section, nextOrder: items.length),
          const SizedBox(height: AppSpacing.sm),
          if (items.isEmpty)
            const EmptyState(
              icon: Icons.playlist_add_outlined,
              title: 'أضف أول بند لهذا القسم',
              message: 'كل بند سيحتوي احتمالات، وبعض الاحتمالات تولد علاجًا.',
            )
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _ItemTemplateCard(app: app, item: item),
              ),
            ),
        ],
      ),
    );
  }
}

class _ItemAddRow extends StatefulWidget {
  const _ItemAddRow({
    required this.app,
    required this.section,
    required this.nextOrder,
  });

  final AppProvider app;
  final AssessmentSectionTemplate section;
  final int nextOrder;

  @override
  State<_ItemAddRow> createState() => _ItemAddRowState();
}

class _ItemAddRowState extends State<_ItemAddRow> {
  final title = TextEditingController();
  final prompt = TextEditingController();

  @override
  void dispose() {
    title.dispose();
    prompt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          SizedBox(
            width: 240,
            child: TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'بند تقييم'),
            ),
          ),
          SizedBox(
            width: 420,
            child: TextField(
              controller: prompt,
              decoration: const InputDecoration(labelText: 'تعليمات الملاحظة'),
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: () => _save(context),
            icon: const Icon(Icons.add),
            label: const Text('إضافة بند'),
          ),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    if (title.text.trim().isEmpty) return;
    final now = DateTime.now().toIso8601String();
    await widget.app.saveAssessmentItemTemplate(
      AssessmentItemTemplate(
        id: 'item_${DateTime.now().microsecondsSinceEpoch}',
        centerId: widget.app.activeCenterId,
        sectionId: widget.section.id,
        title: title.text.trim(),
        prompt: prompt.text.trim(),
        sortOrder: widget.nextOrder,
        createdAt: now,
        updatedAt: now,
      ),
    );
    title.clear();
    prompt.clear();
  }
}

class _ItemTemplateCard extends StatelessWidget {
  const _ItemTemplateCard({required this.app, required this.item});

  final AppProvider app;
  final AssessmentItemTemplate item;

  @override
  Widget build(BuildContext context) {
    final options =
        app.assessmentOptions.where((option) => option.itemId == item.id);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: SanadText.subtitle(context)),
                    if (item.prompt.isNotEmpty)
                      Text(item.prompt, style: SanadText.secondary(context)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'حذف البند',
                onPressed: () => app.deleteAssessmentItemTemplate(item.id),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _OptionAddRow(app: app, item: item, nextOrder: options.length),
          const SizedBox(height: AppSpacing.sm),
          if (options.isEmpty)
            const Text('أضف احتمالات هذا البند مثل: طبيعي، مائل لليمين...')
          else
            ...options.map(
              (option) => _OptionTemplatePanel(app: app, option: option),
            ),
        ],
      ),
    );
  }
}

class _OptionAddRow extends StatefulWidget {
  const _OptionAddRow({
    required this.app,
    required this.item,
    required this.nextOrder,
  });

  final AppProvider app;
  final AssessmentItemTemplate item;
  final int nextOrder;

  @override
  State<_OptionAddRow> createState() => _OptionAddRowState();
}

class _OptionAddRowState extends State<_OptionAddRow> {
  final label = TextEditingController();
  final weakness = TextEditingController();
  final goal = TextEditingController();
  final therapy = TextEditingController();
  bool generatesTherapy = false;

  @override
  void dispose() {
    label.dispose();
    weakness.dispose();
    goal.dispose();
    therapy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: AppSpacing.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 240,
                child: TextField(
                  controller: label,
                  decoration: const InputDecoration(labelText: 'احتمال'),
                ),
              ),
              FilterChip(
                selected: generatesTherapy,
                label: const Text('يولد علاج'),
                avatar: const Icon(Icons.auto_awesome_outlined),
                onSelected: (value) => setState(() => generatesTherapy = value),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _save(context),
                icon: const Icon(Icons.add),
                label: const Text('إضافة احتمال'),
              ),
            ],
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: generatesTherapy
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: _TherapyTemplateFields(
                weakness: weakness,
                goal: goal,
                therapy: therapy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    if (label.text.trim().isEmpty) return;
    final now = DateTime.now().toIso8601String();
    await widget.app.saveAssessmentOptionTemplate(
      AssessmentOptionTemplate(
        id: 'option_${DateTime.now().microsecondsSinceEpoch}',
        centerId: widget.app.activeCenterId,
        itemId: widget.item.id,
        label: label.text.trim(),
        generatesTherapy: generatesTherapy,
        weaknessTemplate: weakness.text.trim(),
        goalTemplate: goal.text.trim(),
        therapyTemplate: therapy.text.trim(),
        sortOrder: widget.nextOrder,
        createdAt: now,
        updatedAt: now,
      ),
    );
    label.clear();
    weakness.clear();
    goal.clear();
    therapy.clear();
    setState(() => generatesTherapy = false);
  }
}

class _OptionTemplatePanel extends StatelessWidget {
  const _OptionTemplatePanel({required this.app, required this.option});

  final AppProvider app;
  final AssessmentOptionTemplate option;

  @override
  Widget build(BuildContext context) {
    final steps = app.skillStepTemplates
        .where(
            (step) => step.ownerType == 'option' && step.ownerId == option.id)
        .toList();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                AppPill(
                  label: option.generatesTherapy ? 'يولد علاج' : 'لا يولد علاج',
                  icon: option.generatesTherapy
                      ? Icons.flag_outlined
                      : Icons.verified_outlined,
                  selected: option.generatesTherapy,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(option.label, style: SanadText.subtitle(context)),
                ),
                IconButton(
                  tooltip: 'حذف الاحتمال',
                  onPressed: () =>
                      app.deleteAssessmentOptionTemplate(option.id),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            if (option.generatesTherapy) ...[
              const SizedBox(height: AppSpacing.sm),
              _TemplatePreview(
                  label: 'Weakness', value: option.weaknessTemplate),
              _TemplatePreview(label: 'Goal', value: option.goalTemplate),
              _TemplatePreview(label: 'Therapy', value: option.therapyTemplate),
              const SizedBox(height: AppSpacing.sm),
              _SkillStepAddRow(
                app: app,
                ownerType: 'option',
                ownerId: option.id,
                nextOrder: steps.length,
              ),
              ...steps.map((step) => _SkillStepTile(app: app, step: step)),
            ],
          ],
        ),
      ),
    );
  }
}

class _SpeechSoundMatrixSheet extends StatelessWidget {
  const _SpeechSoundMatrixSheet({required this.app});

  final AppProvider app;

  @override
  Widget build(BuildContext context) {
    return TherapyCard(
      icon: Icons.grid_on_outlined,
      title: 'Speech Sound Matrix Builder',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'هذا الجزء يبني قوالب الحروف. كل خلية تمثل: حرف + نوع خطأ + موقع داخل الكلمة، ثم ترتبط بقوالب الضعف والهدف والتدريب وخطوات المهارة.',
          ),
          const SizedBox(height: AppSpacing.md),
          _SoundTriggerAddRow(app: app),
          const SizedBox(height: AppSpacing.md),
          if (app.speechSoundTriggers.isEmpty)
            const EmptyState(
              icon: Icons.grid_view_outlined,
              title: 'لا توجد خلايا في المصفوفة بعد',
              message:
                  'أضف حرفًا ونوع خطأ وموقعًا حتى يستخدمه التقييم لاحقًا لتوليد الهدف تلقائيًا.',
            )
          else
            ResponsiveGrid(
              children: app.speechSoundTriggers
                  .map((trigger) =>
                      _SoundTriggerCard(app: app, trigger: trigger))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _SoundTriggerAddRow extends StatefulWidget {
  const _SoundTriggerAddRow({required this.app});

  final AppProvider app;

  @override
  State<_SoundTriggerAddRow> createState() => _SoundTriggerAddRowState();
}

class _SoundTriggerAddRowState extends State<_SoundTriggerAddRow> {
  final letter = TextEditingController();
  final weakness = TextEditingController();
  final goal = TextEditingController();
  final therapy = TextEditingController();
  String errorType = 'إبدال';
  String position = 'أول الكلمة';

  @override
  void dispose() {
    letter.dispose();
    weakness.dispose();
    goal.dispose();
    therapy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              SizedBox(
                width: 120,
                child: TextField(
                  controller: letter,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(labelText: 'الحرف'),
                ),
              ),
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<String>(
                  initialValue: errorType,
                  decoration: const InputDecoration(labelText: 'نوع الخطأ'),
                  items: const ['حذف', 'إبدال', 'إضافة', 'تشويه']
                      .map((value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => errorType = value ?? errorType),
                ),
              ),
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<String>(
                  initialValue: position,
                  decoration: const InputDecoration(labelText: 'الموقع'),
                  items: const ['أول الكلمة', 'وسط الكلمة', 'آخر الكلمة']
                      .map((value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => position = value ?? position),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _TherapyTemplateFields(
            weakness: weakness,
            goal: goal,
            therapy: therapy,
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.icon(
              onPressed: () => _save(context),
              icon: const Icon(Icons.add),
              label: const Text('إضافة خلية للمصفوفة'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    if (letter.text.trim().isEmpty) return;
    final now = DateTime.now().toIso8601String();
    await widget.app.saveSpeechSoundTriggerTemplate(
      SpeechSoundTriggerTemplate(
        id: 'sound_${DateTime.now().microsecondsSinceEpoch}',
        centerId: widget.app.activeCenterId,
        letter: letter.text.trim(),
        errorType: errorType,
        position: position,
        generatesTherapy: true,
        weaknessTemplate: weakness.text.trim(),
        goalTemplate: goal.text.trim(),
        therapyTemplate: therapy.text.trim(),
        sortOrder: widget.app.speechSoundTriggers.length,
        createdAt: now,
        updatedAt: now,
      ),
    );
    letter.clear();
    weakness.clear();
    goal.clear();
    therapy.clear();
  }
}

class _SoundTriggerCard extends StatelessWidget {
  const _SoundTriggerCard({required this.app, required this.trigger});

  final AppProvider app;
  final SpeechSoundTriggerTemplate trigger;

  @override
  Widget build(BuildContext context) {
    final steps = app.skillStepTemplates
        .where(
            (step) => step.ownerType == 'sound' && step.ownerId == trigger.id)
        .toList();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                trigger.letter,
                style: Theme.of(context)
                    .textTheme
                    .displaySmall
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    AppPill(label: trigger.errorType, selected: true),
                    AppPill(label: trigger.position),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'حذف الخلية',
                onPressed: () =>
                    app.deleteSpeechSoundTriggerTemplate(trigger.id),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _TemplatePreview(label: 'Weakness', value: trigger.weaknessTemplate),
          _TemplatePreview(label: 'Goal', value: trigger.goalTemplate),
          _TemplatePreview(label: 'Therapy', value: trigger.therapyTemplate),
          const SizedBox(height: AppSpacing.sm),
          _SkillStepAddRow(
            app: app,
            ownerType: 'sound',
            ownerId: trigger.id,
            nextOrder: steps.length,
          ),
          ...steps.map((step) => _SkillStepTile(app: app, step: step)),
        ],
      ),
    );
  }
}

class _TherapyTemplateFields extends StatelessWidget {
  const _TherapyTemplateFields({
    required this.weakness,
    required this.goal,
    required this.therapy,
  });

  final TextEditingController weakness;
  final TextEditingController goal;
  final TextEditingController therapy;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: weakness,
          decoration: const InputDecoration(labelText: 'Weakness Template'),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: goal,
          decoration: const InputDecoration(labelText: 'Goal Template'),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: therapy,
          decoration: const InputDecoration(labelText: 'Therapy Template'),
        ),
      ],
    );
  }
}

class _SkillStepAddRow extends StatefulWidget {
  const _SkillStepAddRow({
    required this.app,
    required this.ownerType,
    required this.ownerId,
    required this.nextOrder,
  });

  final AppProvider app;
  final String ownerType;
  final String ownerId;
  final int nextOrder;

  @override
  State<_SkillStepAddRow> createState() => _SkillStepAddRowState();
}

class _SkillStepAddRowState extends State<_SkillStepAddRow> {
  final title = TextEditingController();

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        SizedBox(
          width: 420,
          child: TextField(
            controller: title,
            decoration: const InputDecoration(labelText: 'Skill Step'),
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: () => _save(),
          icon: const Icon(Icons.add_task_outlined),
          label: const Text('إضافة خطوة'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (title.text.trim().isEmpty) return;
    final now = DateTime.now().toIso8601String();
    await widget.app.saveSkillStepTemplate(
      SkillStepTemplate(
        id: 'skill_template_${DateTime.now().microsecondsSinceEpoch}',
        centerId: widget.app.activeCenterId,
        ownerType: widget.ownerType,
        ownerId: widget.ownerId,
        title: title.text.trim(),
        sortOrder: widget.nextOrder,
        createdAt: now,
        updatedAt: now,
      ),
    );
    title.clear();
  }
}

class _SkillStepTile extends StatelessWidget {
  const _SkillStepTile({required this.app, required this.step});

  final AppProvider app;
  final SkillStepTemplate step;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Text('${step.sortOrder + 1}')),
      title: Text(step.title),
      trailing: IconButton(
        tooltip: 'حذف الخطوة',
        onPressed: () => app.deleteSkillStepTemplate(step.id),
        icon: const Icon(Icons.close),
      ),
    );
  }
}

class _TemplatePreview extends StatelessWidget {
  const _TemplatePreview({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text('$label: $value', style: SanadText.secondary(context)),
    );
  }
}
