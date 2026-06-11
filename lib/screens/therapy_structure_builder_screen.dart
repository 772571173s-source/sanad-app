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
  bool _showDetail = false;

  @override
  void initState() {
    super.initState();
    _showDetail = false;
  }

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

    if (programs.isEmpty) _showDetail = false;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 800;

        if (isWide) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 320,
                  child: _ProgramListPanel(
                    app: app,
                    selectedProgramId: selectedProgramId,
                    onSelect: (id) => setState(() {
                      selectedProgramId = id;
                    }),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: program == null
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: EmptyState(
                            icon: Icons.add_box_outlined,
                            title: 'أنشئ أول برنامج علاجي',
                            message:
                                'مثال: برنامج العلاج النطقي. بعد إنشاء البرنامج ستظهر أقسام التقييم وتقييم الحروف حسب نوع البرنامج.',
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 40),
                          child: Center(
                            child: SizedBox(
                              width: 640,
                              child: _ProgramDetailPanel(
                                key: ValueKey(program.id),
                                app: app,
                                program: program,
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          );
        } else {
          if (!_showDetail || program == null) {
            return SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: _ProgramListPanel(
                app: app,
                selectedProgramId: selectedProgramId,
                onSelect: (id) => setState(() {
                  selectedProgramId = id;
                  _showDetail = true;
                }),
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 40),
            child: _ProgramDetailPanel(
              key: ValueKey(program.id),
              app: app,
              program: program,
              onBack: () => setState(() => _showDetail = false),
            ),
          );
        }
      },
    );
  }
}

class _ProgramListPanel extends StatelessWidget {
  const _ProgramListPanel({
    super.key,
    required this.app,
    required this.selectedProgramId,
    required this.onSelect,
  });

  final AppProvider app;
  final String? selectedProgramId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
        const SizedBox(height: 20),
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.auto_stories_outlined,
                  color: colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('البرامج العلاجية',
                  style: SanadText.subtitle(context)),
            ),
            FilledButton.icon(
              onPressed: () => _showProgramDialog(context, app),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('إضافة برنامج'),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (app.therapyPrograms.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('لا توجد برامج علاجية بعد.',
                style: SanadText.secondary(context)),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: app.therapyPrograms.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final program = app.therapyPrograms[index];
              final canEditProgram =
                  app.canEditTherapyTemplate(program.centerId);
              final sectionCount = app.assessmentSections
                  .where((s) => s.programId == program.id)
                  .length;
              final letterCount = app.speechSoundTriggers
                  .where((t) => t.programId == program.id)
                  .map((t) => t.letter)
                  .toSet()
                  .length;

              return Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(program.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: SanadText.title(context)),
                              const SizedBox(height: 6),
                              _ScopeBadge(centerId: program.centerId),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (program.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(program.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: SanadText.secondary(context)),
                    ],
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StatChip(
                          icon: program.usesSpeechSounds
                              ? Icons.record_voice_over_outlined
                              : Icons.psychology_alt_outlined,
                          label: program.usesSpeechSounds
                              ? 'يعتمد على الحروف'
                              : 'بدون حروف',
                          selected: program.usesSpeechSounds,
                        ),
                        _StatChip(
                          icon: Icons.fact_check_outlined,
                          label: '$sectionCount أقسام',
                        ),
                        if (letterCount > 0)
                          _StatChip(
                            icon: Icons.grid_on_outlined,
                            label: '$letterCount حروف',
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        if (canEditProgram)
                          SizedBox(
                            height: 38,
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  app.deleteTherapyProgramTemplate(program.id),
                              icon: const Icon(Icons.delete_outline,
                                  size: 16),
                              label: const Text('حذف',
                                  style: TextStyle(fontSize: 13)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colorScheme.error,
                                side: BorderSide(
                                    color: colorScheme.error
                                        .withValues(alpha: .4)),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                              ),
                            ),
                          ),
                        const Spacer(),
                        FilledButton.tonalIcon(
                          onPressed: () => onSelect(program.id),
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('فتح',
                              style: TextStyle(fontSize: 13)),
                          style: FilledButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 14),
                            minimumSize: const Size(0, 38),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
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
                const SizedBox(height: 14),
                TextField(
                  controller: description,
                  decoration: const InputDecoration(labelText: 'وصف مختصر'),
                ),
                const SizedBox(height: 14),
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

class _ProgramDetailPanel extends StatefulWidget {
  const _ProgramDetailPanel({
    super.key,
    required this.app,
    required this.program,
    this.onBack,
  });

  final AppProvider app;
  final TherapyProgramTemplate program;
  final VoidCallback? onBack;

  @override
  State<_ProgramDetailPanel> createState() => _ProgramDetailPanelState();
}

class _ProgramDetailPanelState extends State<_ProgramDetailPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  int get _tabCount => 2 + (widget.program.usesSpeechSounds ? 1 : 0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void didUpdateWidget(_ProgramDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.program.id != widget.program.id ||
        oldWidget.program.usesSpeechSounds != widget.program.usesSpeechSounds) {
      final newCount = _tabCount;
      _tabController.removeListener(_onTabChanged);
      _tabController.dispose();
      _tabController = TabController(length: newCount, vsync: this);
      _tabController.addListener(_onTabChanged);
    }
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final app = widget.app;
    final program = widget.program;
    final canEdit = app.canEditTherapyTemplate(program.centerId);

    final tabs = [
      const Tab(text: 'معلومات البرنامج'),
      const Tab(text: 'أقسام التقييم'),
      if (program.usesSpeechSounds) const Tab(text: 'تقييم الحروف'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.onBack != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: widget.onBack,
                  tooltip: 'رجوع',
                  style: IconButton.styleFrom(
                    minimumSize: const Size(44, 44),
                  ),
                ),
              ],
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.schema_outlined,
                        color: colorScheme.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(program.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w900)),
                        if (program.description.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(program.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: SanadText.secondary(context)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _ScopeBadge(centerId: program.centerId),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  AppPill(
                    label: program.usesSpeechSounds
                        ? 'يعتمد على تقييم الحروف'
                        : 'لا يعتمد على الحروف',
                    icon: Icons.record_voice_over_outlined,
                    selected: program.usesSpeechSounds,
                  ),
                  if (canEdit)
                    OutlinedButton.icon(
                      onPressed: () =>
                          app.deleteTherapyProgramTemplate(program.id),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('حذف البرنامج'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.error,
                        side: BorderSide(
                            color: colorScheme.error.withValues(alpha: .4)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color:
                colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(3),
          child: Row(
            children: List.generate(tabs.length, (index) {
              final isSelected = _tabController.index == index;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    color: isSelected ? colorScheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(11),
                      onTap: () => _tabController.animateTo(index),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(tabs[index].text ?? '',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: isSelected
                                  ? colorScheme.onPrimary
                                  : colorScheme.onSurfaceVariant,
                            )),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 20),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          child: Builder(
            key: ValueKey(_tabController.index),
            builder: (context) {
              if (_tabController.index == 0) {
                return _ProgramInfo(program: program);
              }
              if (_tabController.index == 1) {
                return _SectionsView(app: app, program: program);
              }
              if (_tabController.index == 2 && program.usesSpeechSounds) {
                return _SpeechSoundsView(app: app, program: program);
              }
              return const SizedBox.shrink();
            },
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

class _SectionsView extends StatelessWidget {
  const _SectionsView({required this.app, required this.program});

  final AppProvider app;
  final TherapyProgramTemplate program;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sections = app.assessmentSections
        .where((section) => section.programId == program.id)
        .toList();
    final canEdit = app.canEditTherapyTemplate(program.centerId);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.fact_check_outlined,
                    color: colorScheme.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Text('أقسام التقييم',
                  style: SanadText.subtitle(context)),
              if (sections.isNotEmpty) ...[
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${sections.length}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: colorScheme.onPrimaryContainer,
                      )),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          if (canEdit)
            _SectionAddRow(
                app: app, program: program, nextOrder: sections.length),
          if (canEdit && sections.isNotEmpty)
            const SizedBox(height: 18),
          if (sections.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: const EmptyState(
                icon: Icons.library_add_outlined,
                title: 'أضف أول قسم تقييم',
                message: 'مثال: الوجه، الفك، الشفاه، اللسان، التنفس، الصوت.',
              ),
            )
          else
            ...sections.asMap().entries.map((entry) => Padding(
                  padding: EdgeInsets.only(top: entry.key > 0 ? 16 : 0),
                  child: _SectionCard(
                    app: app,
                    section: entry.value,
                  ),
                )),
        ],
      ),
    );
  }
}

class _SectionCard extends StatefulWidget {
  const _SectionCard({required this.app, required this.section});

  final AppProvider app;
  final AssessmentSectionTemplate section;

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  final _addItemKey = GlobalKey<_ItemAddRowState>();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final app = widget.app;
    final section = widget.section;
    final canEdit = app.canEditTherapyTemplate(section.centerId);
    final items =
        app.assessmentItems.where((item) => item.sectionId == section.id);
    final itemList = items.toList();

    return ExpansionTile(
      initiallyExpanded: false,
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: .5)),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: .5)),
      ),
      collapsedBackgroundColor: colorScheme.surface,
      backgroundColor: colorScheme.surface,
      tilePadding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      title: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 280;
          return Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.folder_outlined,
                    color: colorScheme.onSecondaryContainer, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(section.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SanadText.title(context)),
                    if (section.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(section.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: SanadText.secondary(context)),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: _ScopeBadge(
                    centerId: section.centerId, compact: compact),
              ),
            ],
          );
        },
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (itemList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${itemList.length}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: colorScheme.onSecondaryContainer,
                    )),
              ),
            ),
          Icon(Icons.expand_more, size: 20,
              color: colorScheme.onSurfaceVariant),
        ],
      ),
      children: [
        if (itemList.isEmpty && canEdit)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: EmptyState(
              icon: Icons.library_add_outlined,
              title: 'لا توجد بنود بعد',
              message: 'أضف أول بند تقييم داخل هذا القسم.',
              action: FilledButton.icon(
                onPressed: () => _addItemKey.currentState?.focusFirst(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('إضافة بند'),
              ),
            ),
          )
        else if (itemList.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: EmptyState(
              icon: Icons.inbox_outlined,
              title: 'لا توجد بنود',
              message: 'هذا القسم لا يحتوي على بنود تقييم بعد.',
            ),
          ),
        if (canEdit)
          Padding(
            padding: EdgeInsets.only(
                bottom: itemList.isNotEmpty ? 16 : 0),
            child: _ItemAddRow(
              key: _addItemKey,
              app: app,
              section: section,
              nextOrder: itemList.length,
            ),
          ),
        if (itemList.isNotEmpty)
          ...itemList.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ItemCard(app: app, item: item),
              )),
        if (canEdit && itemList.isNotEmpty)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () =>
                  app.deleteAssessmentSectionTemplate(section.id),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('حذف القسم'),
              style: TextButton.styleFrom(
                  foregroundColor: colorScheme.error),
            ),
          ),
      ],
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.app, required this.item});

  final AppProvider app;
  final AssessmentItemTemplate item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final canEdit = app.canEditTherapyTemplate(item.centerId);
    final options =
        app.assessmentOptions.where((option) => option.itemId == item.id);
    final optionCount = options.length;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.checklist_rtl_outlined,
                    size: 16, color: colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        )),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
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
                    if (item.prompt.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(item.prompt,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: SanadText.secondary(context)),
                    ],
                  ],
                ),
              ),
              if (canEdit)
                IconButton(
                  tooltip: 'حذف البند',
                  onPressed: () =>
                      app.deleteAssessmentItemTemplate(item.id),
                  icon: const Icon(Icons.delete_outline, size: 20),
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                      foregroundColor: colorScheme.error),
                )
              else
                Icon(Icons.lock_outline,
                    size: 20, color: colorScheme.onSurfaceVariant),
            ],
          ),
          if (optionCount > 0 || canEdit) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _showOptionsSheet(context),
                  icon: const Icon(Icons.list_alt_outlined, size: 18),
                  label: Text('$optionCount خيارات'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showOptionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => _OptionBottomSheet(
        app: app,
        item: item,
      ),
    );
  }
}

class _OptionBottomSheet extends StatefulWidget {
  const _OptionBottomSheet({required this.app, required this.item});

  final AppProvider app;
  final AssessmentItemTemplate item;

  @override
  State<_OptionBottomSheet> createState() => _OptionBottomSheetState();
}

class _OptionBottomSheetState extends State<_OptionBottomSheet> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final app = widget.app;
    final item = widget.item;
    final canEdit = app.canEditTherapyTemplate(item.centerId);
    final options = app.assessmentOptions
        .where((option) => option.itemId == item.id)
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: .2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.list_alt_outlined,
                        color: colorScheme.primary, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('خيارات "${item.title}"',
                        style: SanadText.subtitle(context)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('${options.length}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        )),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    if (canEdit && item.responseType == 'custom')
                      _OptionAddRow(
                          app: app, item: item, nextOrder: options.length),
                    if (canEdit &&
                        item.responseType == 'custom' &&
                        options.isNotEmpty)
                      const SizedBox(height: 16),
                    if (options.isEmpty && item.responseType != 'custom')
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                            'خيارات هذا البند مضمنة مسبقاً.',
                            style: SanadText.secondary(context)),
                      )
                    else if (options.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text('أضف احتمالات هذا البند.',
                            style: SanadText.secondary(context)),
                      )
                    else
                      ...options.map((option) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child:
                                _OptionCard(app: app, option: option),
                          )),
                    SizedBox(
                        height: MediaQuery.of(context).viewInsets.bottom +
                            16),
                  ],
                ),
              ),
            ],
          ),
        ),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 240,
                child: TextField(
                  controller: title,
                  decoration: const InputDecoration(
                    labelText: 'اسم القسم',
                    isDense: true,
                  ),
                ),
              ),
              SizedBox(
                width: 280,
                child: TextField(
                  controller: description,
                  decoration: const InputDecoration(
                    labelText: 'وصف مختصر',
                    isDense: true,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _save(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('إضافة قسم'),
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
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

class _ItemAddRow extends StatefulWidget {
  const _ItemAddRow({
    super.key,
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
  final titleFocus = FocusNode();
  final prompt = TextEditingController();
  String responseType = 'custom';
  String responseMode = 'singleChoice';

  void focusFirst() {
    titleFocus.requestFocus();
  }

  @override
  void dispose() {
    title.dispose();
    titleFocus.dispose();
    prompt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 220,
                child: TextField(
                  controller: title,
                  focusNode: titleFocus,
                  decoration: const InputDecoration(
                    labelText: 'بند تقييم',
                    isDense: true,
                  ),
                ),
              ),
              SizedBox(
                width: 280,
                child: TextField(
                  controller: prompt,
                  decoration: const InputDecoration(
                    labelText: 'تعليمات الملاحظة',
                    isDense: true,
                  ),
                ),
              ),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String>(
                  initialValue: responseMode,
                  isExpanded: true,
                  alignment: AlignmentDirectional.centerStart,
                  decoration: const InputDecoration(
                    labelText: 'نوع الاستجابة',
                    helperText: 'اختيار واحد أم تقييم كل احتمال',
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                icon: const Icon(Icons.add, size: 18),
                label: const Text('إضافة بند'),
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
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
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 240,
          child: TextField(
            controller: label,
            decoration: const InputDecoration(
              labelText: 'احتمال',
              isDense: true,
            ),
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: _save,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('إضافة احتمال'),
          style: FilledButton.styleFrom(
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
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

class _OptionCard extends StatefulWidget {
  const _OptionCard({required this.app, required this.option});

  final AppProvider app;
  final AssessmentOptionTemplate option;

  @override
  State<_OptionCard> createState() => _OptionCardState();
}

class _OptionCardState extends State<_OptionCard> {
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
    final colorScheme = Theme.of(context).colorScheme;
    final option = widget.option;
    final app = widget.app;
    final canEdit = app.canEditTherapyTemplate(option.centerId);
    final steps = app.skillStepTemplates
        .where(
            (step) => step.ownerType == 'option' && step.ownerId == option.id)
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: generatesTherapy
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(option.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: generatesTherapy
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                    )),
              ),
              Switch.adaptive(
                value: generatesTherapy,
                onChanged: canEdit ? (value) => _save(value) : null,
              ),
              Text(generatesTherapy ? 'يولد علاج' : 'لا يولد علاج',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: generatesTherapy
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  )),
              if (canEdit)
                IconButton(
                  onPressed: () =>
                      app.deleteAssessmentOptionTemplate(option.id),
                  icon: const Icon(Icons.delete_outline, size: 20),
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                      foregroundColor: colorScheme.error),
                ),
            ],
          ),
          if (generatesTherapy) ...[
            const SizedBox(height: 16),
            _TherapyTemplateFields(
              enabled: canEdit,
              weakness: weakness,
              goal: goal,
              therapy: therapy,
              onSave: () => _save(true),
            ),
            if (canEdit) ...[
              const SizedBox(height: 16),
              _SkillStepAddRow(
                app: app,
                ownerType: 'option',
                ownerId: option.id,
                nextOrder: steps.length,
              ),
            ],
            if (steps.isNotEmpty) const SizedBox(height: 12),
            ...steps.asMap().entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _SkillStepTile(
                    app: app,
                    step: entry.value,
                    index: entry.key,
                    total: steps.length,
                  ),
                )),
          ],
        ],
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

class _SpeechSoundsView extends StatefulWidget {
  const _SpeechSoundsView({required this.app, required this.program});

  final AppProvider app;
  final TherapyProgramTemplate program;

  @override
  State<_SpeechSoundsView> createState() => _SpeechSoundsViewState();
}

class _SpeechSoundsViewState extends State<_SpeechSoundsView> {
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
    final colorScheme = Theme.of(context).colorScheme;
    final letters = _letters;
    final canEdit =
        widget.app.canEditTherapyTemplate(widget.program.centerId);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.grid_on_outlined,
                    color: colorScheme.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Text('تقييم الحروف',
                  style: SanadText.subtitle(context)),
              if (letters.isNotEmpty) ...[
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${letters.length}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: colorScheme.onPrimaryContainer,
                      )),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          if (canEdit)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
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
                            isDense: true,
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
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('إضافة حرف'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                        ),
                      ),
                      if (selectedLetter != null)
                        AppPill(
                          label: selectedLetter!,
                          icon: Icons.check,
                          selected: true,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          if (canEdit && letters.isNotEmpty) const SizedBox(height: 16),
          if (letters.isNotEmpty)
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: letters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final l = letters[index];
                  final isSelected = l == selectedLetter;
                  return FilterChip(
                    selected: isSelected,
                    label: Text(l,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w600,
                        )),
                    onSelected: (_) =>
                        setState(() => selectedLetter = l),
                    showCheckmark: false,
                    selectedColor: colorScheme.primaryContainer,
                    checkmarkColor: colorScheme.primary,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 20),
          if (selectedLetter == null)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: const EmptyState(
                icon: Icons.touch_app_outlined,
                title: 'اختر حرفاً',
                message:
                    'اختر حرفاً من القائمة أعلاه، أو أضف حرفاً جديداً ثم حدد له خلية.',
              ),
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
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: const EmptyState(
              icon: Icons.grid_view_outlined,
              title: 'لا توجد خلايا',
              message:
                  'لم يتم تعريف أي خلايا لهذا الحرف. أضف الخلية الأولى أدناه.',
            ),
          )
        else
          ...triggers.asMap().entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _TriggerCard(app: app, trigger: entry.value),
              )),
        if (canEdit)
          _TriggerAddRow(
            app: app,
            program: program,
            letter: letter,
            nextOrder: triggers.length,
          ),
      ],
    );
  }
}

class _TriggerAddRow extends StatefulWidget {
  const _TriggerAddRow({
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
  State<_TriggerAddRow> createState() => _TriggerAddRowState();
}

class _TriggerAddRowState extends State<_TriggerAddRow> {
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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(widget.letter,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: colorScheme.onPrimaryContainer,
                    )),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 140,
                      child: DropdownButtonFormField<String>(
                        initialValue: errorType,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'نوع الخطأ',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        items: ['حذف', 'إبدال', 'إضافة', 'تشويه']
                            .map((item) => DropdownMenuItem(
                                value: item, child: Text(item)))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => errorType = value ?? errorType),
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      child: DropdownButtonFormField<String>(
                        initialValue: position,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'الموضع',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        items: ['أول', 'وسط', 'آخر']
                            .map((item) => DropdownMenuItem(
                                value: item, child: Text(item)))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => position = value ?? position),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: weakness,
            decoration: const InputDecoration(labelText: 'نقطة الضعف'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: goal,
            decoration: const InputDecoration(labelText: 'الهدف العلاجي'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: therapy,
            decoration: const InputDecoration(labelText: 'العلاج / التدريب'),
          ),
          const SizedBox(height: 20),
          Text('الخطوات المهارية',
              style: SanadText.subtitle(context)),
          const SizedBox(height: 12),
          if (_skillStepList.isNotEmpty)
            ..._skillStepList.asMap().entries.map((entry) =>
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildSkillStepTimeline(
                    context: context,
                    index: entry.key,
                    total: _skillStepList.length,
                    text: entry.value,
                    isEditing: _editingIndex == entry.key,
                    editingController: skillInput,
                    onSave: () => _saveEdit(entry.key),
                    onCancel: () {
                      setState(() {
                        _editingIndex = null;
                        skillInput.clear();
                      });
                    },
                    onEdit: () {
                      setState(() {
                        _editingIndex = entry.key;
                        skillInput.text = entry.value;
                      });
                    },
                    onDelete: () => _deleteStep(entry.key),
                    colorScheme: colorScheme,
                  ),
                )),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: skillInput,
                  decoration: const InputDecoration(
                    labelText: 'مهارة علاجية',
                    hintText: 'اكتب مهارة ثم اضغط إضافة',
                    isDense: true,
                  ),
                  onSubmitted: (_) => _addStep(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.tonalIcon(
                onPressed: _addStep,
                icon: const Icon(Icons.add_task_outlined, size: 18),
                label: const Text('إضافة مهارة'),
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('إضافة خلية'),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
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

  Future<void> _save() async {
    final now = DateTime.now().toIso8601String();
    final triggerId = 'sound_${DateTime.now().microsecondsSinceEpoch}';
    await widget.app.saveSpeechSoundTriggerTemplate(
      SpeechSoundTriggerTemplate(
        id: triggerId,
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
    for (var i = 0; i < _skillStepList.length; i++) {
      await widget.app.saveSkillStepTemplate(SkillStepTemplate(
        id: '${triggerId}_step_$i',
        centerId: widget.program.centerId,
        ownerType: 'sound',
        ownerId: triggerId,
        title: _skillStepList[i],
        sortOrder: i,
        createdAt: now,
        updatedAt: now,
      ));
    }
    weakness.clear();
    goal.clear();
    therapy.clear();
    _skillStepList.clear();
    skillInput.clear();
  }
}

class _TriggerCard extends StatefulWidget {
  const _TriggerCard({required this.app, required this.trigger});

  final AppProvider app;
  final SpeechSoundTriggerTemplate trigger;

  @override
  State<_TriggerCard> createState() => _TriggerCardState();
}

class _TriggerCardState extends State<_TriggerCard> {
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
    final triggerId = _trigger.id;
    await _app.saveSpeechSoundTriggerTemplate(
      _trigger.copyWith(
        skillStepTemplates: steps,
        updatedAt: now,
      ),
    );
    final existing = _app.skillStepTemplates
        .where((s) => s.ownerType == 'sound' && s.ownerId == triggerId)
        .toList();
    for (final step in existing) {
      await _app.deleteSkillStepTemplate(step.id);
    }
    for (var i = 0; i < steps.length; i++) {
      await _app.saveSkillStepTemplate(SkillStepTemplate(
        id: '${triggerId}_step_$i',
        centerId: _trigger.centerId,
        ownerType: 'sound',
        ownerId: triggerId,
        title: steps[i],
        sortOrder: i,
        createdAt: now,
        updatedAt: now,
      ));
    }
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
    final colorScheme = Theme.of(context).colorScheme;
    final canEdit = _app.canEditTherapyTemplate(_trigger.centerId);
    final steps = _trigger.skillStepTemplates;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_trigger.letter,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: colorScheme.onPrimaryContainer,
                    )),
              ),
              AppPill(label: _trigger.errorType, selected: true),
              AppPill(label: _trigger.position),
              _ScopeBadge(centerId: _trigger.centerId),
              if (canEdit)
                IconButton(
                  onPressed: () =>
                      _app.deleteSpeechSoundTriggerTemplate(_trigger.id),
                  icon: const Icon(Icons.delete_outline, size: 20),
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                      foregroundColor: colorScheme.error),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildFieldPreview(context, 'نقطة الضعف', _trigger.weaknessTemplate),
          _buildFieldPreview(
              context, 'الهدف العلاجي', _trigger.goalTemplate),
          _buildFieldPreview(
              context, 'العلاج / التدريب', _trigger.therapyTemplate),
          if (steps.isNotEmpty || canEdit) const SizedBox(height: 18),
          if (steps.isNotEmpty || canEdit)
            Text('الخطوات المهارية',
                style: SanadText.subtitle(context)),
          if (steps.isNotEmpty || canEdit) const SizedBox(height: 12),
          if (steps.isNotEmpty)
            ...steps.asMap().entries.map((entry) =>
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildSkillStepTimeline(
                    context: context,
                    index: entry.key,
                    total: steps.length,
                    text: entry.value,
                    isEditing: _editingIndex == entry.key,
                    editingController: skillInput,
                    onSave: () => _saveEdit(entry.key),
                    onCancel: () {
                      setState(() {
                        _editingIndex = null;
                        skillInput.clear();
                      });
                    },
                    onEdit: () {
                      setState(() {
                        _editingIndex = entry.key;
                        skillInput.text = entry.value;
                      });
                    },
                    onDelete: () => _deleteStep(entry.key),
                    canEdit: canEdit,
                    colorScheme: colorScheme,
                  ),
                )),
          if (canEdit) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: skillInput,
                    decoration: const InputDecoration(
                      labelText: 'مهارة علاجية',
                      hintText: 'اكتب مهارة ثم اضغط إضافة',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _addStep(),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.tonalIcon(
                  onPressed: _addStep,
                  icon: const Icon(Icons.add_task_outlined, size: 18),
                  label: const Text('إضافة مهارة'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = selected
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;
    final foreground = selected
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected
              ? colorScheme.primary.withValues(alpha: .3)
              : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 4),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: foreground,
              )),
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
        const SizedBox(height: 14),
        TextField(
          enabled: enabled,
          controller: goal,
          decoration: const InputDecoration(labelText: 'الهدف العلاجي'),
        ),
        const SizedBox(height: 14),
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
              icon: const Icon(Icons.save_outlined, size: 18),
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
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 360,
          child: TextField(
            controller: title,
            decoration: const InputDecoration(
              labelText: 'مهارة علاجية',
              isDense: true,
            ),
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: _save,
          icon: const Icon(Icons.add_task_outlined, size: 18),
          label: const Text('إضافة مهارة'),
          style: FilledButton.styleFrom(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
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
  const _SkillStepTile({
    required this.app,
    required this.step,
    this.index = 0,
    this.total = 1,
  });

  final AppProvider app;
  final SkillStepTemplate step;
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final canEdit = app.canEditTherapyTemplate(step.centerId);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text('${index + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: colorScheme.onPrimary,
                      )),
                ),
                if (index < total - 1)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: colorScheme.surfaceContainerHighest,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(step.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    height: 1.4,
                  )),
            ),
          ),
          if (canEdit)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  onPressed: () => _edit(context),
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                      foregroundColor: colorScheme.onSurfaceVariant),
                ),
                IconButton(
                  onPressed: () =>
                      app.deleteSkillStepTemplate(step.id),
                  icon: const Icon(Icons.delete_outline, size: 17),
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                      foregroundColor: colorScheme.error),
                ),
              ],
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Icon(Icons.lock_outline,
                  size: 18, color: colorScheme.onSurfaceVariant),
            ),
        ],
      ),
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
          decoration:
              const InputDecoration(labelText: 'المهارة العلاجية'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, controller.text.trim()),
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

class _ScopeBadge extends StatelessWidget {
  const _ScopeBadge({required this.centerId, this.compact = false});

  final String centerId;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final global = centerId.isEmpty;
    return AppPill(
      label: global
          ? (compact ? 'عام' : 'عام من سند')
          : (compact ? 'خاص' : 'خاص بالمركز'),
      icon: global ? Icons.public_outlined : Icons.business_outlined,
      selected: global,
    );
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

Widget _buildSkillStepTimeline({
  required BuildContext context,
  required int index,
  required int total,
  required String text,
  required bool isEditing,
  required TextEditingController editingController,
  required VoidCallback onSave,
  required VoidCallback onCancel,
  required VoidCallback onEdit,
  required VoidCallback onDelete,
  bool canEdit = true,
  required ColorScheme colorScheme,
}) {
  return IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 32,
          child: Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text('${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: colorScheme.onPrimary,
                    )),
              ),
              if (index < total - 1)
                Expanded(
                  child: Container(
                    width: 2,
                    color: colorScheme.surfaceContainerHighest,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: isEditing
              ? TextField(
                  controller: editingController,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                  onSubmitted: (_) => onSave(),
                )
              : Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        height: 1.4,
                      )),
                ),
        ),
        if (canEdit)
          if (isEditing) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.check, size: 18),
              onPressed: onSave,
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                  foregroundColor: colorScheme.primary),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onCancel,
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                  foregroundColor: colorScheme.onSurfaceVariant),
            ),
          ] else ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 17),
              onPressed: onEdit,
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                  foregroundColor:
                      colorScheme.onSurfaceVariant),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 17),
              onPressed: onDelete,
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                  foregroundColor: colorScheme.error),
            ),
          ],
      ],
    ),
  );
}

Widget _buildFieldPreview(
    BuildContext context, String label, String value) {
  if (value.trim().isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            )),
        Expanded(
          child: Text(value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: SanadText.secondary(context)),
        ),
      ],
    ),
  );
}
