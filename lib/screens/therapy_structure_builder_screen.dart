import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../widgets/app_widgets.dart';
import '../widgets/feedback.dart';

class TherapyStructureBuilderScreen extends StatefulWidget {
  const TherapyStructureBuilderScreen({super.key});

  @override
  State<TherapyStructureBuilderScreen> createState() =>
      _TherapyStructureBuilderScreenState();
}

class _TherapyStructureBuilderScreenState
    extends State<TherapyStructureBuilderScreen> {
  String? selectedProgramId;
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    if (!app.canManageTherapyStructure) {
      return const EmptyState(
        icon: Icons.lock_outline,
        title: 'هذه الشاشة خاصة ببناء البرامج العلاجية',
        message:
            'مدير المركز أو المشرف الفني أو مدخل البرامج العلاجية يديرون القوالب. الأخصائي يستخدمها داخل تقييم الطالب.',
      );
    }

    final programs = app.therapyPrograms;
    final selected = programs.where((item) => item.id == selectedProgramId);
    final program = selected.isEmpty
        ? (programs.isEmpty ? null : programs.first)
        : selected.first;
    selectedProgramId = program?.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SemanticAlertCard(
          kind: SemanticAlertKind.info,
          icon: Icons.schema_outlined,
          title: app.isGlobalTherapyStructureMode
              ? 'مكتبة سند العلاجية العامة'
              : 'برامج المركز العلاجية',
          message: app.isGlobalTherapyStructureMode
              ? 'ابدأ بإنشاء برنامج علاجي عام. أي برنامج تضيفه هنا يظهر لكل المراكز.'
              : 'ابدأ بإنشاء برنامج خاص بالمركز أو استخدم برامج سند العامة. القوالب العامة تظهر للقراءة فقط داخل المركز.',
        ),
        const SizedBox(height: AppSpacing.md),
        _ProgramsPanel(
          app: app,
          selectedProgramId: selectedProgramId,
          onSelect: (id) => setState(() {
            selectedProgramId = id;
            tab = 0;
          }),
        ),
        const SizedBox(height: AppSpacing.md),
        if (program == null)
          const EmptyState(
            icon: Icons.add_box_outlined,
            title: 'أنشئ أول برنامج علاجي',
            message:
                'مثال: برنامج العلاج النطقي. بعد إنشاء البرنامج ستظهر أقسام التقييم وتقييم الحروف حسب نوع البرنامج.',
          )
        else
          _ProgramEditor(
            app: app,
            program: program,
            tab: tab,
            onTabChanged: (value) => setState(() => tab = value),
          ),
      ],
    );
  }
}

class _ProgramsPanel extends StatelessWidget {
  const _ProgramsPanel({
    required this.app,
    required this.selectedProgramId,
    required this.onSelect,
  });

  final AppProvider app;
  final String? selectedProgramId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return TherapyCard(
      icon: Icons.auto_stories_outlined,
      title: 'البرامج العلاجية',
      trailing: FilledButton.icon(
        onPressed: () => _showProgramDialog(context, app),
        icon: const Icon(Icons.add),
        label: const Text('إضافة برنامج علاجي'),
      ),
      child: app.therapyPrograms.isEmpty
          ? const Text('لا توجد برامج علاجية بعد.')
          : Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: app.therapyPrograms.map((program) {
                final selected = selectedProgramId == program.id;
                return FilterChip(
                  selected: selected,
                  label: Text(program.name),
                  avatar: Icon(program.usesSpeechSounds
                      ? Icons.record_voice_over_outlined
                      : Icons.psychology_alt_outlined),
                  onSelected: (_) => onSelect(program.id),
                );
              }).toList(),
            ),
    );
  }

  Future<void> _showProgramDialog(BuildContext context, AppProvider app) async {
    final name = TextEditingController(text: 'برنامج العلاج النطقي');
    final description = TextEditingController();
    var usesSpeechSounds = true;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إضافة برنامج علاجي'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'اسم البرنامج'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: description,
                  decoration: const InputDecoration(labelText: 'وصف مختصر'),
                ),
                const SizedBox(height: AppSpacing.sm),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: usesSpeechSounds,
                  title: const Text('يعتمد على تقييم الحروف'),
                  subtitle: const Text(
                      'فعّلها لبرنامج العلاج النطقي حتى تظهر مصفوفة الحروف.'),
                  onChanged: (value) =>
                      setDialogState(() => usesSpeechSounds = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => runWithFeedback(context, () async {
                if (name.text.trim().isEmpty) {
                  throw StateError('اكتب اسم البرنامج.');
                }
                final now = DateTime.now().toIso8601String();
                await app.saveTherapyProgramTemplate(
                  TherapyProgramTemplate(
                    id: 'program_${DateTime.now().microsecondsSinceEpoch}',
                    centerId: app.therapyStructureWriteCenterId,
                    name: name.text.trim(),
                    description: description.text.trim(),
                    usesSpeechSounds: usesSpeechSounds,
                    sortOrder: app.therapyPrograms.length,
                    createdAt: now,
                    updatedAt: now,
                  ),
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              }, success: 'تم حفظ البرنامج العلاجي.'),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgramEditor extends StatelessWidget {
  const _ProgramEditor({
    required this.app,
    required this.program,
    required this.tab,
    required this.onTabChanged,
  });

  final AppProvider app;
  final TherapyProgramTemplate program;
  final int tab;
  final ValueChanged<int> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const Tab(text: 'معلومات البرنامج'),
      const Tab(text: 'أقسام التقييم'),
      if (program.usesSpeechSounds) const Tab(text: 'تقييم الحروف'),
    ];
    final safeTab = tab >= tabs.length ? 0 : tab;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(program.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall),
                  ),
                  _ScopeBadge(centerId: program.centerId),
                ],
              ),
              if (program.description.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(program.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: SanadText.secondary(context)),
              ],
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  AppPill(
                    label: program.usesSpeechSounds
                        ? 'يعتمد على تقييم الحروف'
                        : 'لا يعتمد على الحروف',
                    icon: Icons.record_voice_over_outlined,
                    selected: program.usesSpeechSounds,
                  ),
                  if (app.canEditTherapyTemplate(program.centerId))
                    OutlinedButton.icon(
                      onPressed: () =>
                          app.deleteTherapyProgramTemplate(program.id),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('حذف البرنامج'),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        DefaultTabController(
          length: tabs.length,
          initialIndex: safeTab,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TabBar(
                tabs: tabs,
                onTap: onTabChanged,
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor:
                    Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: AppSpacing.md),
              if (safeTab == 0) _ProgramInfo(program: program),
              if (safeTab == 1) _SectionsEditor(app: app, program: program),
              if (safeTab == 2 && program.usesSpeechSounds)
                _SpeechSoundsEditor(app: app, program: program),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProgramInfo extends StatelessWidget {
  const _ProgramInfo({required this.program});

  final TherapyProgramTemplate program;

  @override
  Widget build(BuildContext context) {
    return const SemanticAlertCard(
      kind: SemanticAlertKind.success,
      icon: Icons.info_outline,
      title: 'معلومات البرنامج',
      message:
          'هذا هو الجذر العلاجي. الأقسام والبنود والحروف التي تضيفها لاحقًا ستكون مرتبطة بهذا البرنامج وتظهر بنفس ترتيب الإدخال.',
    );
  }
}

class _SectionsEditor extends StatelessWidget {
  const _SectionsEditor({required this.app, required this.program});

  final AppProvider app;
  final TherapyProgramTemplate program;

  @override
  Widget build(BuildContext context) {
    final sections = app.assessmentSections
        .where((section) => section.programId == program.id)
        .toList();
    final canEdit = app.canEditTherapyTemplate(program.centerId);
    return TherapyCard(
      icon: Icons.fact_check_outlined,
      title: 'أقسام التقييم',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (canEdit)
            _SectionAddRow(
                app: app, program: program, nextOrder: sections.length),
          const SizedBox(height: AppSpacing.md),
          if (sections.isEmpty)
            const EmptyState(
              icon: Icons.library_add_outlined,
              title: 'أضف أول قسم تقييم',
              message: 'مثال: الوجه، الفك، الشفاه، اللسان، التنفس، الصوت.',
            )
          else
            ...sections.map((section) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _SectionTemplateCard(app: app, section: section),
                )),
        ],
      ),
    );
  }
}

class _SectionAddRow extends StatefulWidget {
  const _SectionAddRow({
    required this.app,
    required this.program,
    required this.nextOrder,
  });

  final AppProvider app;
  final TherapyProgramTemplate program;
  final int nextOrder;

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
      child: Wrap(
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
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: TextField(
              controller: description,
              decoration: const InputDecoration(labelText: 'وصف مختصر'),
            ),
          ),
          FilledButton.icon(
            onPressed: () => _save(context),
            icon: const Icon(Icons.add),
            label: const Text('إضافة قسم'),
          ),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    if (title.text.trim().isEmpty) return;
    final now = DateTime.now().toIso8601String();
    await widget.app.saveAssessmentSectionTemplate(
      AssessmentSectionTemplate(
        id: 'section_${DateTime.now().microsecondsSinceEpoch}',
        centerId: widget.program.centerId,
        programId: widget.program.id,
        title: title.text.trim(),
        description: description.text.trim(),
        sortOrder: widget.nextOrder,
        createdAt: now,
        updatedAt: now,
      ),
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
    final canEdit = app.canEditTherapyTemplate(section.centerId);
    final items =
        app.assessmentItems.where((item) => item.sectionId == section.id);
    return AppCard(
      highlight: true,
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: Row(
          children: [
            Expanded(
                child: Text(section.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SanadText.title(context))),
            _ScopeBadge(centerId: section.centerId),
          ],
        ),
        subtitle: section.description.isEmpty
            ? const Text('قسم تقييم')
            : Text(section.description, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: canEdit
            ? IconButton(
                tooltip: 'حذف القسم',
                onPressed: () =>
                    app.deleteAssessmentSectionTemplate(section.id),
                icon: const Icon(Icons.delete_outline),
              )
            : const Icon(Icons.lock_outline),
        children: [
          if (canEdit)
            _ItemAddRow(app: app, section: section, nextOrder: items.length),
          const SizedBox(height: AppSpacing.sm),
          if (items.isEmpty)
            const Text('أضف بنود التقييم داخل هذا القسم.')
          else
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _ItemTemplateCard(app: app, item: item),
                )),
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
  String responseType = 'custom';
  String responseMode = 'singleChoice';

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
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: TextField(
              controller: prompt,
              decoration: const InputDecoration(labelText: 'تعليمات الملاحظة'),
            ),
          ),
          SizedBox(
            width: 260,
            child: DropdownButtonFormField<String>(
              initialValue: responseMode,
              isExpanded: true,
              alignment: AlignmentDirectional.centerStart,
              decoration: const InputDecoration(
                labelText: 'نوع الاستجابة',
                helperText: 'اختيار واحد أم تقييم كل احتمال',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'singleChoice',
                  child: Text('اختيار واحد'),
                ),
                DropdownMenuItem(
                  value: 'multiResponse',
                  child: Text('تقييم كل احتمال'),
                ),
              ],
              onChanged: (value) =>
                  setState(() => responseMode = value ?? responseMode),
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
    final itemId = 'item_${DateTime.now().microsecondsSinceEpoch}';
    await widget.app.saveAssessmentItemTemplate(
      AssessmentItemTemplate(
        id: itemId,
        centerId: widget.section.centerId,
        sectionId: widget.section.id,
        title: title.text.trim(),
        responseType: responseType,
        responseMode: responseMode,
        prompt: prompt.text.trim(),
        sortOrder: widget.nextOrder,
        createdAt: now,
        updatedAt: now,
      ),
    );
    if (responseType == 'yesNo') {
      for (final label in ['نعم', 'لا']) {
        await widget.app.saveAssessmentOptionTemplate(
          AssessmentOptionTemplate(
            id: 'option_${DateTime.now().microsecondsSinceEpoch}_$label',
            centerId: widget.section.centerId,
            itemId: itemId,
            label: label,
            generatesTherapy: false,
            sortOrder: label == 'نعم' ? 0 : 1,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    }
    title.clear();
    prompt.clear();
    setState(() => responseMode = 'singleChoice');
  }
}

String _responseTypeLabel(String value) {
  switch (value) {
    case 'yesNo':
      return 'نعم / لا';
    case 'speechMatrix':
      return 'تقييم الحروف';
    case 'scale':
      return 'درجات / Scale';
    case 'custom':
    default:
      return 'احتمالات مخصصة';
  }
}

String _responseModeLabel(String value) {
  switch (value) {
    case 'multiResponse':
      return 'تقييم كل احتمال';
    case 'singleChoice':
    default:
      return 'اختيار واحد';
  }
}

class _ItemTemplateCard extends StatelessWidget {
  const _ItemTemplateCard({required this.app, required this.item});

  final AppProvider app;
  final AssessmentItemTemplate item;

  @override
  Widget build(BuildContext context) {
    final canEdit = app.canEditTherapyTemplate(item.centerId);
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
                    Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: SanadText.subtitle(context)),
                    Wrap(
                      spacing: AppSpacing.xs,
                      children: [
                        AppPill(
                          label: _responseTypeLabel(item.responseType),
                          icon: Icons.tune_outlined,
                        ),
                        AppPill(
                          label: _responseModeLabel(item.responseMode),
                          icon: item.responseMode == 'multiResponse'
                              ? Icons.list_alt_outlined
                              : Icons.radio_button_checked_outlined,
                          selected: item.responseMode == 'multiResponse',
                        ),
                      ],
                    ),
                    if (item.prompt.isNotEmpty)
                      Text(item.prompt, maxLines: 2, overflow: TextOverflow.ellipsis, style: SanadText.secondary(context)),
                  ],
                ),
              ),
              if (canEdit)
                IconButton(
                  tooltip: 'حذف البند',
                  onPressed: () => app.deleteAssessmentItemTemplate(item.id),
                  icon: const Icon(Icons.delete_outline),
                )
              else
                const Icon(Icons.lock_outline),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (canEdit && item.responseType == 'custom')
            _OptionAddRow(app: app, item: item, nextOrder: options.length),
          const SizedBox(height: AppSpacing.sm),
          if (options.isEmpty)
            const Text('أضف احتمالات هذا البند.')
          else
            ...options.map((option) => _OptionPanel(app: app, option: option)),
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

  @override
  void dispose() {
    label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      children: [
        SizedBox(
          width: 240,
          child: TextField(
            controller: label,
            decoration: const InputDecoration(labelText: 'احتمال'),
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: () => _save(),
          icon: const Icon(Icons.add),
          label: const Text('إضافة احتمال'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (label.text.trim().isEmpty) return;
    final now = DateTime.now().toIso8601String();
    await widget.app.saveAssessmentOptionTemplate(
      AssessmentOptionTemplate(
        id: 'option_${DateTime.now().microsecondsSinceEpoch}',
        centerId: widget.item.centerId,
        itemId: widget.item.id,
        label: label.text.trim(),
        generatesTherapy: false,
        sortOrder: widget.nextOrder,
        createdAt: now,
        updatedAt: now,
      ),
    );
    label.clear();
  }
}

class _OptionPanel extends StatefulWidget {
  const _OptionPanel({required this.app, required this.option});

  final AppProvider app;
  final AssessmentOptionTemplate option;

  @override
  State<_OptionPanel> createState() => _OptionPanelState();
}

class _OptionPanelState extends State<_OptionPanel> {
  late bool generatesTherapy = widget.option.generatesTherapy;
  late final weakness =
      TextEditingController(text: widget.option.weaknessTemplate);
  late final goal = TextEditingController(text: widget.option.goalTemplate);
  late final therapy =
      TextEditingController(text: widget.option.therapyTemplate);

  @override
  void dispose() {
    weakness.dispose();
    goal.dispose();
    therapy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final option = widget.option;
    final app = widget.app;
    final canEdit = app.canEditTherapyTemplate(option.centerId);
    final steps = app.skillStepTemplates
        .where(
            (step) => step.ownerType == 'option' && step.ownerId == option.id)
        .toList();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: AppCard(
        padding: AppSpacing.md,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                    child:
                        Text(option.label, maxLines: 2, overflow: TextOverflow.ellipsis, style: SanadText.subtitle(context))),
                Switch.adaptive(
                  value: generatesTherapy,
                  onChanged: canEdit ? (value) => _save(value) : null,
                ),
                Text(generatesTherapy ? 'يولد علاج' : 'لا يولد علاج',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if (canEdit)
                  IconButton(
                    onPressed: () =>
                        app.deleteAssessmentOptionTemplate(option.id),
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            if (generatesTherapy) ...[
              const SizedBox(height: AppSpacing.sm),
              _TherapyTemplateFields(
                enabled: canEdit,
                weakness: weakness,
                goal: goal,
                therapy: therapy,
                onSave: () => _save(true),
              ),
              if (canEdit)
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

  Future<void> _save(bool value) async {
    setState(() => generatesTherapy = value);
    await widget.app.saveAssessmentOptionTemplate(
      AssessmentOptionTemplate(
        id: widget.option.id,
        centerId: widget.option.centerId,
        itemId: widget.option.itemId,
        label: widget.option.label,
        generatesTherapy: value,
        weaknessTemplate: value ? weakness.text.trim() : '',
        goalTemplate: value ? goal.text.trim() : '',
        therapyTemplate: value ? therapy.text.trim() : '',
        sortOrder: widget.option.sortOrder,
        createdAt: widget.option.createdAt,
        updatedAt: DateTime.now().toIso8601String(),
      ),
    );
  }
}

class _SpeechSoundsEditor extends StatefulWidget {
  const _SpeechSoundsEditor({required this.app, required this.program});

  final AppProvider app;
  final TherapyProgramTemplate program;

  @override
  State<_SpeechSoundsEditor> createState() => _SpeechSoundsEditorState();
}

class _SpeechSoundsEditorState extends State<_SpeechSoundsEditor> {
  String? selectedLetter;
  final letterField = TextEditingController();

  List<String> get _letters {
    final letters = widget.app.speechSoundTriggers
        .where((t) => t.programId == widget.program.id)
        .map((t) => t.letter)
        .toSet()
        .toList();
    letters.sort();
    return letters;
  }

  List<SpeechSoundTriggerTemplate> _triggersFor(String letter) =>
      widget.app.speechSoundTriggers
          .where((t) =>
              t.programId == widget.program.id && t.letter == letter)
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  @override
  void dispose() {
    letterField.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final letters = _letters;
    final canEdit =
        widget.app.canEditTherapyTemplate(widget.program.centerId);
    return TherapyCard(
      icon: Icons.grid_on_outlined,
      title: 'تقييم الحروف',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (canEdit)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: letterField,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        labelText: 'إضافة حرف',
                        hintText: 'مثال: أ',
                      ),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      final l = letterField.text.trim();
                      if (l.isEmpty) return;
                      setState(() {
                        selectedLetter = l;
                        letterField.clear();
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة حرف'),
                  ),
                  if (selectedLetter != null)
                    AppPill(
                      label: selectedLetter!,
                      icon: Icons.check,
                      selected: true,
                    ),
                ],
              ),
            ),
          if (letters.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: letters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final l = letters[index];
                  return FilterChip(
                    selected: l == selectedLetter,
                    label: Text(l),
                    onSelected: (_) =>
                        setState(() => selectedLetter = l),
                  );
                },
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          if (selectedLetter == null)
            const EmptyState(
              icon: Icons.touch_app_outlined,
              title: 'اختر حرفاً',
              message:
                  'اختر حرفاً من القائمة أعلاه، أو أضف حرفاً جديداً ثم حدد له خلية.',
            )
          else
            _LetterDetail(
              app: widget.app,
              program: widget.program,
              letter: selectedLetter!,
              triggers: _triggersFor(selectedLetter!),
            ),
        ],
      ),
    );
  }
}

class _LetterDetail extends StatelessWidget {
  const _LetterDetail({
    required this.app,
    required this.program,
    required this.letter,
    required this.triggers,
  });

  final AppProvider app;
  final TherapyProgramTemplate program;
  final String letter;
  final List<SpeechSoundTriggerTemplate> triggers;

  @override
  Widget build(BuildContext context) {
    final canEdit = app.canEditTherapyTemplate(program.centerId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (triggers.isEmpty)
          const EmptyState(
            icon: Icons.grid_view_outlined,
            title: 'لا توجد خلايا',
            message:
                'لم يتم تعريف أي خلايا لهذا الحرف. أضف الخلية الأولى أدناه.',
          )
        else
          ...triggers.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _SoundCard(app: app, trigger: t),
              )),
        if (canEdit)
          _SoundAddRow(
            app: app,
            program: program,
            letter: letter,
            nextOrder: triggers.length,
          ),
      ],
    );
  }
}

class _SoundAddRow extends StatefulWidget {
  const _SoundAddRow({
    required this.app,
    required this.program,
    required this.letter,
    required this.nextOrder,
  });

  final AppProvider app;
  final TherapyProgramTemplate program;
  final String letter;
  final int nextOrder;

  @override
  State<_SoundAddRow> createState() => _SoundAddRowState();
}

class _SoundAddRowState extends State<_SoundAddRow> {
  final weakness = TextEditingController();
  final goal = TextEditingController();
  final therapy = TextEditingController();
  final skillInput = TextEditingController();
  final _skillStepList = <String>[];
  String errorType = 'إبدال';
  String position = 'أول';
  int? _editingIndex;

  @override
  void dispose() {
    weakness.dispose();
    goal.dispose();
    therapy.dispose();
    skillInput.dispose();
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
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(widget.letter,
                  style: Theme.of(context).textTheme.titleLarge),
              _menu('نوع الخطأ', errorType,
                  ['حذف', 'إبدال', 'إضافة', 'تشويه'],
                  (value) => setState(() => errorType = value)),
              _menu('الموضع', position, ['أول', 'وسط', 'آخر'],
                  (value) => setState(() => position = value)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: weakness,
            decoration: const InputDecoration(labelText: 'نقطة الضعف'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: goal,
            decoration: const InputDecoration(labelText: 'الهدف العلاجي'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: therapy,
            decoration: const InputDecoration(labelText: 'العلاج / التدريب'),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('الخطوات المهارية:',
              style: SanadText.subtitle(context)),
          const SizedBox(height: AppSpacing.xs),
          if (_skillStepList.isNotEmpty)
            ..._skillStepList.asMap().entries.map((entry) =>
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        child: Text('${entry.key + 1}',
                            style: const TextStyle(fontSize: 11)),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _editingIndex == entry.key
                            ? TextField(
                                controller: skillInput,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 8),
                                ),
                                autofocus: true,
                                onSubmitted: (_) => _saveEdit(entry.key),
                              )
                            : Text(entry.value, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                      if (_editingIndex == entry.key) ...[
                        IconButton(
                          icon: const Icon(Icons.check, size: 20),
                          onPressed: () => _saveEdit(entry.key),
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () {
                            setState(() {
                              _editingIndex = null;
                              skillInput.clear();
                            });
                          },
                          visualDensity: VisualDensity.compact,
                        ),
                      ] else ...[
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () {
                            setState(() {
                              _editingIndex = entry.key;
                              skillInput.text = entry.value;
                            });
                          },
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => _deleteStep(entry.key),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ],
                  ),
                )),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: skillInput,
                  decoration: const InputDecoration(
                    labelText: 'مهارة علاجية',
                    hintText: 'اكتب مهارة ثم اضغط إضافة',
                  ),
                  onSubmitted: (_) => _addStep(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton.tonalIcon(
                onPressed: _addStep,
                icon: const Icon(Icons.add_task_outlined),
                label: const Text('إضافة مهارة'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.add),
              label: const Text('إضافة خلية'),
            ),
          ),
        ],
      ),
    );
  }

  void _addStep() {
    final text = skillInput.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _skillStepList.add(text);
      skillInput.clear();
    });
  }

  void _deleteStep(int index) {
    setState(() {
      _skillStepList.removeAt(index);
      if (_editingIndex == index) {
        _editingIndex = null;
        skillInput.clear();
      }
    });
  }

  void _saveEdit(int index) {
    final text = skillInput.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _skillStepList[index] = text;
      _editingIndex = null;
      skillInput.clear();
    });
  }

  Widget _menu(String label, String value, List<String> values,
      ValueChanged<String> onChanged) {
    return SizedBox(
      width: 140,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: values
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: (item) => onChanged(item ?? value),
      ),
    );
  }

  Future<void> _save() async {
    final now = DateTime.now().toIso8601String();
    await widget.app.saveSpeechSoundTriggerTemplate(
      SpeechSoundTriggerTemplate(
        id: 'sound_${DateTime.now().microsecondsSinceEpoch}',
        centerId: widget.program.centerId,
        programId: widget.program.id,
        letter: widget.letter,
        errorType: errorType,
        position: position,
        generatesTherapy: true,
        weaknessTemplate: weakness.text.trim(),
        goalTemplate: goal.text.trim(),
        therapyTemplate: therapy.text.trim(),
        skillStepTemplates: List.from(_skillStepList),
        sortOrder: widget.nextOrder,
        createdAt: now,
        updatedAt: now,
      ),
    );
    weakness.clear();
    goal.clear();
    therapy.clear();
    _skillStepList.clear();
    skillInput.clear();
  }
}

class _SoundCard extends StatefulWidget {
  const _SoundCard({required this.app, required this.trigger});

  final AppProvider app;
  final SpeechSoundTriggerTemplate trigger;

  @override
  State<_SoundCard> createState() => _SoundCardState();
}

class _SoundCardState extends State<_SoundCard> {
  final skillInput = TextEditingController();
  int? _editingIndex;

  SpeechSoundTriggerTemplate get _trigger => widget.trigger;
  AppProvider get _app => widget.app;

  @override
  void dispose() {
    skillInput.dispose();
    super.dispose();
  }

  Future<void> _updateSteps(List<String> steps) async {
    final now = DateTime.now().toIso8601String();
    await _app.saveSpeechSoundTriggerTemplate(
      _trigger.copyWith(
        skillStepTemplates: steps,
        updatedAt: now,
      ),
    );
  }

  Future<void> _addStep() async {
    final text = skillInput.text.trim();
    if (text.isEmpty) return;
    final updated = List<String>.from(_trigger.skillStepTemplates)
      ..add(text);
    await _updateSteps(updated);
    skillInput.clear();
  }

  Future<void> _deleteStep(int index) async {
    final updated = List<String>.from(_trigger.skillStepTemplates)
      ..removeAt(index);
    await _updateSteps(updated);
  }

  Future<void> _saveEdit(int index) async {
    final text = skillInput.text.trim();
    if (text.isEmpty) return;
    final updated = List<String>.from(_trigger.skillStepTemplates);
    updated[index] = text;
    await _updateSteps(updated);
    setState(() {
      _editingIndex = null;
      skillInput.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = _app.canEditTherapyTemplate(_trigger.centerId);
    final steps = _trigger.skillStepTemplates;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(_trigger.letter,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(width: AppSpacing.md),
              AppPill(label: _trigger.errorType, selected: true),
              const SizedBox(width: AppSpacing.xs),
              AppPill(label: _trigger.position),
              const Spacer(),
              _ScopeBadge(centerId: _trigger.centerId),
              if (canEdit)
                IconButton(
                  onPressed: () =>
                      _app.deleteSpeechSoundTriggerTemplate(_trigger.id),
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          _TemplatePreview(
              label: 'نقطة الضعف', value: _trigger.weaknessTemplate),
          _TemplatePreview(
              label: 'الهدف العلاجي', value: _trigger.goalTemplate),
          _TemplatePreview(
              label: 'العلاج / التدريب', value: _trigger.therapyTemplate),
          const SizedBox(height: AppSpacing.sm),
          Text('الخطوات المهارية:',
              style: SanadText.subtitle(context)),
          const SizedBox(height: AppSpacing.xs),
          if (steps.isNotEmpty)
            ...steps.asMap().entries.map((entry) =>
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        child: Text('${entry.key + 1}',
                            style: const TextStyle(fontSize: 11)),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _editingIndex == entry.key
                            ? TextField(
                                controller: skillInput,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 8),
                                ),
                                autofocus: true,
                                onSubmitted: (_) => _saveEdit(entry.key),
                              )
                            : Text(entry.value, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                      if (canEdit)
                        if (_editingIndex == entry.key) ...[
                          IconButton(
                            icon: const Icon(Icons.check, size: 20),
                            onPressed: () => _saveEdit(entry.key),
                            visualDensity: VisualDensity.compact,
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () {
                              setState(() {
                                _editingIndex = null;
                                skillInput.clear();
                              });
                            },
                            visualDensity: VisualDensity.compact,
                          ),
                        ] else ...[
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            onPressed: () {
                              setState(() {
                                _editingIndex = entry.key;
                                skillInput.text = entry.value;
                              });
                            },
                            visualDensity: VisualDensity.compact,
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => _deleteStep(entry.key),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                    ],
                  ),
                )),
          if (canEdit) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: skillInput,
                    decoration: const InputDecoration(
                      labelText: 'مهارة علاجية',
                      hintText: 'اكتب مهارة ثم اضغط إضافة',
                    ),
                    onSubmitted: (_) => _addStep(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton.tonalIcon(
                  onPressed: _addStep,
                  icon: const Icon(Icons.add_task_outlined),
                  label: const Text('إضافة مهارة'),
                ),
              ],
            ),
          ],
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
    required this.onSave,
    this.enabled = true,
  });

  final TextEditingController weakness;
  final TextEditingController goal;
  final TextEditingController therapy;
  final VoidCallback onSave;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          enabled: enabled,
          controller: weakness,
          decoration: const InputDecoration(labelText: 'نقطة الضعف'),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          enabled: enabled,
          controller: goal,
          decoration: const InputDecoration(labelText: 'الهدف العلاجي'),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          enabled: enabled,
          controller: therapy,
          decoration: const InputDecoration(labelText: 'العلاج / التدريب'),
        ),
        if (enabled)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: onSave,
              icon: const Icon(Icons.save_outlined),
              label: const Text('حفظ القالب العلاجي'),
            ),
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
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: TextField(
            controller: title,
            decoration: const InputDecoration(labelText: 'مهارة علاجية'),
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: _save,
          icon: const Icon(Icons.add_task_outlined),
          label: const Text('إضافة مهارة'),
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
        centerId: widget.app.therapyStructureWriteCenterId,
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
    final canEdit = app.canEditTherapyTemplate(step.centerId);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Text('${step.sortOrder + 1}')),
      title: Text(step.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: canEdit
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => _edit(context),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  onPressed: () => app.deleteSkillStepTemplate(step.id),
                  icon: const Icon(Icons.close, size: 20),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            )
          : const Icon(Icons.lock_outline),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final controller = TextEditingController(text: step.title);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل المهارة'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'المهارة العلاجية'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await app.saveSkillStepTemplate(step.copyWith(title: result));
    }
    controller.dispose();
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
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Text('$label: $value', maxLines: 2, overflow: TextOverflow.ellipsis, style: SanadText.secondary(context)),
    );
  }
}

class _ScopeBadge extends StatelessWidget {
  const _ScopeBadge({required this.centerId});

  final String centerId;

  @override
  Widget build(BuildContext context) {
    final global = centerId.isEmpty;
    return AppPill(
      label: global ? 'عام من سند' : 'خاص بالمركز',
      icon: global ? Icons.public_outlined : Icons.business_outlined,
      selected: global,
    );
  }
}
