import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../widgets/app_widgets.dart';
import '../widgets/feedback.dart';
import 'therapy_structure_builder_screen.dart';


double _rv(BuildContext context, {required double small, required double large}) {
  return MediaQuery.of(context).size.width > 720 ? large : small;
}

enum _WizardPhase { initialLoading, studentSelect, programSelect, sections, soundMatrix, summary }

class _AssessmentStep {
  const _AssessmentStep({
    required this.sectionTitle,
    required this.item,
    this.option,
  });

  final String sectionTitle;
  final AssessmentItemTemplate item;
  final AssessmentOptionTemplate? option;

  bool get isSingleChoice => option == null;
}

class ClinicalAssessmentWizardScreen extends StatefulWidget {
  const ClinicalAssessmentWizardScreen({
    super.key,
    this.initialStudentId,
    this.initialProgramId,
    this.embedded = true,
    this.onBack,
  });

  final String? initialStudentId;
  final String? initialProgramId;
  final bool embedded;
  final VoidCallback? onBack;

  @override
  State<ClinicalAssessmentWizardScreen> createState() =>
      _ClinicalAssessmentWizardScreenState();
}

class _ClinicalAssessmentWizardScreenState
    extends State<ClinicalAssessmentWizardScreen>
    with WidgetsBindingObserver {
  _WizardPhase phase = _WizardPhase.studentSelect;
  TherapyProgramTemplate? selectedProgram;
  int stepIndex = 0;

  String _studentSearchQuery = '';

  final selections = <String, AssessmentOptionTemplate>{};
  final multiSelections = <String, bool>{};

  /// Key = letter, value = {isNormal: bool, errorType?: String, position?: String, triggerId?: String}
  final letterResults = <String, Map<String, dynamic>>{};
  int soundLetterIndex = 0;
  bool _showPositionPicker = false;
  String? _selectedErrorType;

  /// Cached list of letters for the current program (populated when entering sound phase).
  List<String> lettersList = [];

  bool saved = false;
  bool isSaving = false;

  List<_AssessmentStep> _steps = [];

  /// Cached provider reference — set in [build] where context is guaranteed valid.
  /// Needed because [context.read] may not work reliably in [dispose].
  AppProvider? _app;

  String? _initializationError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final hasInitialIds =
        widget.initialStudentId != null && widget.initialProgramId != null;
    if (hasInitialIds) {
      phase = _WizardPhase.initialLoading;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _jumpToProgram(context);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoSaveDraftSync();
    super.dispose();
  }

  /// Synchronous save from [dispose]. Uses cached [_app] because
  /// [context.read] may fail after the element is deactivated.
  void _autoSaveDraftSync() {
    if (saved) return;
    if (selectedProgram == null) return;
    final app = _app;
    if (app == null) return;
    final student = app.selectedStudent;
    if (student == null) return;

    final selectionsMap = <String, String>{};
    for (final entry in selections.entries) {
      selectionsMap[entry.key] = entry.value.id;
    }

    final draft = AssessmentDraft(
      studentId: student.id,
      programId: selectedProgram!.id,
      phase: phase.name,
      stepIndex: stepIndex,
      currentLetter: lettersList.isNotEmpty && phase == _WizardPhase.soundMatrix
          ? lettersList[soundLetterIndex.clamp(0, lettersList.length - 1)]
          : '',
      selectionsJson: jsonEncode(selectionsMap),
      multiSelectionsJson: jsonEncode(multiSelections),
      matrixSelectionsJson: jsonEncode(const []),
      letterResultsJson: jsonEncode(letterResults),
      updatedAt: DateTime.now().toIso8601String(),
    );

// Fire-and-forget: start the DB write synchronously.
    // This is the last save for this widget's lifetime; it runs to completion
    // on the event loop even after super.dispose().
    app.saveAssessmentDraft(draft);
  }

  Future<void> _jumpToProgram(BuildContext ctx) async {
final app = ctx.read<AppProvider>();
    final studentId = widget.initialStudentId;
    final programId = widget.initialProgramId;
if (studentId == null || programId == null) {
return;
    }

    final student = app.students.cast<Student?>().firstWhere(
      (s) => s!.id == studentId,
      orElse: () => null,
    );
    final program = app.therapyPrograms.cast<TherapyProgramTemplate?>().firstWhere(
      (p) => p!.id == programId,
      orElse: () => null,
    );

if (student == null || program == null) {
      final msg = student == null && program == null
          ? 'لا يمكن فتح التقييم لأن بيانات الطالب والبرنامج غير موجودة.'
          : student == null
              ? 'لا يمكن فتح التقييم لأن بيانات الطالب غير موجودة أو لا تنتمي لهذا المركز.'
              : 'لا يمكن فتح التقييم لأن البرنامج العلاجي غير موجود في مكتبة سند.';
if (mounted) {
        setState(() => _initializationError = msg);
      }
      return;
    }

    try {
      await app.selectStudentProgramContext(
        studentId: student.id,
        programId: program.id,
        specialistId: app.isSpecialist ? app.user?.id : null,
      );
      if (!mounted) return;

      if (app.selectedStudent == null) {
        setState(() {
          _initializationError = 'فشل تحميل بيانات الطالب. قد لا تملك صلاحية الوصول أو حدث خطأ في قاعدة البيانات.';
        });
        return;
      }

      setState(() {
        selectedProgram = program;
        selections.clear();
        multiSelections.clear();
        letterResults.clear();
        saved = false;
        stepIndex = 0;
        soundLetterIndex = 0;
        _showPositionPicker = false;
        _selectedErrorType = null;
        lettersList = [];
        phase = _WizardPhase.programSelect;
        _buildSteps(app);
      });
await _checkForDraft(app);
if (!mounted) return;
      if (phase == _WizardPhase.programSelect) {
        final nextPhase = _steps.isNotEmpty
            ? _WizardPhase.sections
            : program.usesSpeechSounds
                ? _WizardPhase.soundMatrix
                : _WizardPhase.summary;
setState(() => phase = nextPhase);
        _autoSaveDraft();
      }
    } catch (e) {
if (mounted) {
        setState(() {
          _initializationError = 'حدث خطأ أثناء فتح التقييم: $e';
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
_autoSaveDraft();
    }
  }

  List<AssessmentSectionTemplate> _sectionsFor(AppProvider app) {
    if (selectedProgram == null) return [];
    final list = app.assessmentSections
        .where((s) => s.programId == selectedProgram!.id)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  List<AssessmentItemTemplate> _itemsForSection(
      AppProvider app, AssessmentSectionTemplate section) {
    final list = app.assessmentItems
        .where((item) => item.sectionId == section.id)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  List<AssessmentOptionTemplate> _optionsForItem(
      AppProvider app, AssessmentItemTemplate item) {
    final list = app.assessmentOptions
        .where((o) => o.itemId == item.id)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  List<SpeechSoundTriggerTemplate> _soundTriggersFor(AppProvider app) {
    if (selectedProgram == null) return [];
    return app.speechSoundTriggers
        .where((t) => t.programId == selectedProgram!.id)
        .toList();
  }

  List<String> _lettersFor(AppProvider app) {
    return _soundTriggersFor(app).map((t) => t.letter).toSet().toList();
  }

  List<SpeechSoundTriggerTemplate> _triggersForLetter(
      AppProvider app, String letter) {
    return _soundTriggersFor(app).where((t) => t.letter == letter).toList();
  }

  String get _centerId =>
      context.read<AppProvider>().therapyStructureWriteCenterId;

  void _buildSteps(AppProvider app) {
    final all = <_AssessmentStep>[];
    for (final section in _sectionsFor(app)) {
      for (final item in _itemsForSection(app, section)) {
        if (item.responseMode == 'multiResponse') {
          for (final option in _optionsForItem(app, item)) {
            all.add(_AssessmentStep(
              sectionTitle: section.title,
              item: item,
              option: option,
            ));
          }
        } else {
          all.add(_AssessmentStep(
            sectionTitle: section.title,
            item: item,
          ));
        }
      }
    }
    _steps = all;
}

  int get _totalSteps => _steps.length;

  String get _currentSectionTitle =>
      stepIndex < _steps.length ? _steps[stepIndex].sectionTitle : '';

  _AssessmentStep? get _currentStep =>
      _steps.isNotEmpty && stepIndex < _steps.length
          ? _steps[stepIndex]
          : null;

  void _goNext() {
    // 1. Compute target state BEFORE setState.
    final isLast = stepIndex >= _steps.length - 1;
    final nextStepIndex = isLast ? stepIndex : stepIndex + 1;
    _WizardPhase? nextPhase;
    if (isLast) {
      nextPhase = selectedProgram?.usesSpeechSounds == true
          ? _WizardPhase.soundMatrix
          : _WizardPhase.summary;
    }

    // 2. Apply in setState.
    setState(() {
      if (!isLast) {
        stepIndex = nextStepIndex;
      } else {
        if (nextPhase == _WizardPhase.soundMatrix) {
          final app = context.read<AppProvider>();
          lettersList = _lettersFor(app);
          soundLetterIndex = 0;
          _showPositionPicker = false;
          _selectedErrorType = null;
        }
        phase = nextPhase!;
      }
    });

// 3. Save with EXPLICIT values (not relying on instance fields after setState).
    _autoSaveDraft(
      explicitStepIndex: isLast ? null : nextStepIndex,
      explicitPhase: isLast ? nextPhase!.name : null,
    );
  }

  void _goPrevious() {
    setState(() {
      if (stepIndex > 0) {
        stepIndex--;
      }
    });
  }

  void _handleSelect(AssessmentItemTemplate item,
      AssessmentOptionTemplate option) {
    selections[item.id] = option;
    _goNext();
  }

  void _handleMultiSelect(String optionId, bool isNormal) {
    multiSelections[optionId] = isNormal;
    _goNext();
  }

  Future<void> _autoSaveDraft({
    int? explicitStepIndex,
    String? explicitPhase,
  }) async {
    if (saved) return;
    if (selectedProgram == null) return;
    if (!mounted) return;

    // No coalescing: each call builds its own draft with current state at this
    // moment. The DB's ConflictAlgorithm.replace ensures the last write wins.

    final app = context.read<AppProvider>();
    final student = app.selectedStudent;
    if (student == null) return;

    final selectionsMap = <String, String>{};
    for (final entry in selections.entries) {
      selectionsMap[entry.key] = entry.value.id;
    }

    // Use explicit value when provided; fall back to instance field.
    final saveStepIndex = explicitStepIndex ?? stepIndex;
    final savePhase = explicitPhase ?? phase.name;

    final draft = AssessmentDraft(
      studentId: student.id,
      programId: selectedProgram!.id,
      phase: savePhase,
      stepIndex: saveStepIndex,
      currentLetter: lettersList.isNotEmpty && phase == _WizardPhase.soundMatrix
          ? lettersList[soundLetterIndex.clamp(0, lettersList.length - 1)]
          : '',
      selectionsJson: jsonEncode(selectionsMap),
      multiSelectionsJson: jsonEncode(multiSelections),
      matrixSelectionsJson: jsonEncode(const []),
      letterResultsJson: jsonEncode(letterResults),
      updatedAt: DateTime.now().toIso8601String(),
    );

await app.saveAssessmentDraft(draft);
  }

  bool _hasAnyAnswer() {
    return selections.isNotEmpty ||
        multiSelections.isNotEmpty ||
        letterResults.isNotEmpty;
  }

  bool _isStepAnswered(int index) {
    if (index < 0 || index >= _steps.length) return false;
    final step = _steps[index];
    if (step.isSingleChoice) {
      return selections.containsKey(step.item.id);
    } else {
      return step.option != null && multiSelections.containsKey(step.option!.id);
    }
  }

  Future<void> _confirmBackToStudentSelect() async {
    if (_hasAnyAnswer()) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('تأكيد الرجوع'),
          content:
              const Text('سيتم فقدان التقييم الحالي، هل تريد الرجوع؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('رجوع'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    _goToStudentSelect();
  }

  Future<void> _confirmBackToProgramSelect() async {
    if (_hasAnyAnswer()) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('تأكيد الرجوع'),
          content:
              const Text('سيتم فقدان التقييم الحالي، هل تريد الرجوع؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('رجوع'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    _goToProgramSelect();
  }

  void _goToStudentSelect() {
    setState(() {
      phase = _WizardPhase.studentSelect;
      selectedProgram = null;
      selections.clear();
      multiSelections.clear();
      letterResults.clear();
      saved = false;
      stepIndex = 0;
      soundLetterIndex = 0;
      _showPositionPicker = false;
      _selectedErrorType = null;
      lettersList = [];
      _steps = [];
      _studentSearchQuery = '';
    });
  }

  void _goToProgramSelect() {
    setState(() {
      phase = _WizardPhase.programSelect;
      selections.clear();
      multiSelections.clear();
      letterResults.clear();
      saved = false;
      stepIndex = 0;
      soundLetterIndex = 0;
      _showPositionPicker = false;
      _selectedErrorType = null;
      lettersList = [];
      _steps = [];
    });
  }

  Future<void> _clearDraft() async {
    final app = context.read<AppProvider>();
    final student = app.selectedStudent;
    if (student == null || selectedProgram == null) return;
await app.deleteAssessmentDraft(student.id, selectedProgram!.id);
  }

  Future<void> _checkForDraft(AppProvider app) async {
    final student = app.selectedStudent;
    if (student == null || selectedProgram == null) return;

    final draft = await app.assessmentDraft(student.id, selectedProgram!.id);
if (draft == null || !mounted) {
return;
    }

final resume = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final dialogColors = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.info_outline, color: dialogColors.primary),
              const SizedBox(width: 8),
              const Text('تقييم غير مكتمل'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الطالب: ${student.name}'),
              const SizedBox(height: 4),
              Text('البرنامج: ${selectedProgram?.name ?? ''}'),
              const SizedBox(height: AppSpacing.md),
              Text(
                'لديك تقييم غير مكتمل لهذا الطالب والبرنامج.',
                style: SanadText.secondary(ctx),
              ),
              Text(
                'يمكنك المتابعة من حيث توقفت.',
                style: SanadText.secondary(ctx),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('بدء تقييم جديد'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('متابعة التقييم'),
            ),
          ],
        );
      },
    );

    if (resume == true && mounted) {
      _restoreFromDraft(draft);
    } else if (mounted) {
      await _clearDraft();
    }
  }

  void _restoreFromDraft(AssessmentDraft draft) {
    final phaseValue = _WizardPhase.values.firstWhere(
      (p) => p.name == draft.phase,
      orElse: () => _WizardPhase.sections,
    );

    selections.clear();
    multiSelections.clear();
    letterResults.clear();

    final selectionsMap = Map<String, String>.from(
        jsonDecode(draft.selectionsJson) as Map);
    final multiMap = Map<String, bool>.from(
        jsonDecode(draft.multiSelectionsJson) as Map);
    Map<String, dynamic> letterResultsRaw;
    final raw = draft.letterResultsJson.isNotEmpty
        ? draft.letterResultsJson
        : draft.matrixSelectionsJson;
    try {
      letterResultsRaw =
          Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      letterResultsRaw = {};
    }

    final app = context.read<AppProvider>();

    for (final entry in selectionsMap.entries) {
      final option = app.assessmentOptions.firstWhere(
        (o) => o.id == entry.value,
        orElse: () => AssessmentOptionTemplate(
          id: entry.value,
          centerId: _centerId,
          itemId: '',
          label: '',
          generatesTherapy: false,
          sortOrder: 0,
        ),
      );
      selections[entry.key] = option;
    }

    for (final entry in multiMap.entries) {
      multiSelections[entry.key] = entry.value;
    }

    for (final entry in letterResultsRaw.entries) {
      if (entry.value is Map) {
        letterResults[entry.key] =
            Map<String, dynamic>.from(entry.value as Map);
      }
    }

    var resolvedPhase = phaseValue;
    int restoredStepIndex = draft.stepIndex;
    int restoredSoundIndex = 0;

    if (resolvedPhase == _WizardPhase.sections && _steps.isEmpty) {
      resolvedPhase = selectedProgram?.usesSpeechSounds == true
          ? _WizardPhase.soundMatrix
          : _WizardPhase.summary;
    }

    if (resolvedPhase == _WizardPhase.soundMatrix) {
      lettersList = _lettersFor(app);
      final draftLetterIdx = draft.currentLetter.isEmpty
          ? 0
          : lettersList.indexOf(draft.currentLetter);
      restoredSoundIndex = draftLetterIdx >= 0 ? draftLetterIdx : 0;
      restoredStepIndex = 0;
    }

    // Advance past any answered items to the first unanswered one
    while (restoredStepIndex < _steps.length &&
        _isStepAnswered(restoredStepIndex)) {
      restoredStepIndex++;
    }
    if (restoredStepIndex >= _steps.length && _steps.isNotEmpty) {
      resolvedPhase = selectedProgram?.usesSpeechSounds == true
          ? _WizardPhase.soundMatrix
          : _WizardPhase.summary;
    }

setState(() {
      phase = resolvedPhase;
      stepIndex = _steps.isEmpty
          ? 0
          : restoredStepIndex.clamp(0, _steps.length - 1);
      soundLetterIndex = restoredSoundIndex;
      _showPositionPicker = false;
      _selectedErrorType = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final app = context.watch<AppProvider>();
    _app = app;
    final student = app.selectedStudent;

    if (app.loading) {
      return _wrap(child: const Center(child: CircularProgressIndicator()));
    }

    if (_initializationError != null) {
      return _wrap(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: EmptyState(
              icon: Icons.error_outline,
              title: 'تعذر فتح التقييم',
              message: _initializationError!,
            ),
          ),
        ),
      );
    }

    if (app.therapyPrograms.isEmpty) {
      return _wrap(
        child: EmptyState(
          icon: Icons.schema_outlined,
          title: 'لا توجد برامج علاجية',
          message:
              'يجب إنشاء برنامج علاجي في شاشة بناء الهيكل العلاجي أولاً قبل استخدام المعالج.',
          action: _buildAction(
            context,
            label: 'فتح بناء الهيكل العلاجي',
            icon: Icons.schema_outlined,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const TherapyStructureBuilderScreen(),
              ),
            ),
          ),
        ),
      );
    }

    final sections = _sectionsFor(app);

    final bool inSoundPhase = phase == _WizardPhase.soundMatrix;
    final int displayTotal = inSoundPhase
        ? (lettersList.isNotEmpty ? lettersList.length : 1)
        : _totalSteps;
    final int displayStep =
        inSoundPhase ? soundLetterIndex + 1 : stepIndex + 1;

    final showNavBar = phase == _WizardPhase.sections ||
        phase == _WizardPhase.soundMatrix ||
        phase == _WizardPhase.summary;

    const double maxWidth = 640;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 720;
    final isMobile = screenWidth < 600;

    final mainContent = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.surface,
            colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
            colorScheme.surface,
          ],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? maxWidth : double.infinity,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.onBack != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 4, top: 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_forward),
                          onPressed: widget.onBack,
                          tooltip: 'العودة إلى قائمة الإسنادات',
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    isMobile ? 12 : 16,
                    AppSpacing.lg,
                    0,
                  ),
                  child: Text(
                    selectedProgram != null ? 'تقييم ${selectedProgram!.name}' : 'التقييم العلاجي',
                    style: TextStyle(
                      fontSize: isMobile ? 22 : 28,
                      fontWeight: FontWeight.w900,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                _CompactHeader(
                  phase: phase,
                  programName: selectedProgram?.name ?? '',
                  studentName: student?.name ?? '',
                  sectionTitle:
                      phase == _WizardPhase.sections ? _currentSectionTitle : '',
                  totalSteps: displayTotal,
                  currentStep: displayStep,
                  onBackToStudentSelect: phase == _WizardPhase.programSelect
                      ? _confirmBackToStudentSelect
                      : null,
                  onBackToProgramSelect: (phase == _WizardPhase.sections ||
                          phase == _WizardPhase.soundMatrix ||
                          phase == _WizardPhase.summary)
                      ? _confirmBackToProgramSelect
                      : null,
                ),
                Expanded(
                  child: _buildPhaseContent(app, student, sections, lettersList),
                ),
                if (showNavBar) _buildNavBar(context),
              ],
            ),
          ),
        ),
      ),
    );

    if (widget.embedded) {
      return Material(color: Colors.transparent, child: mainContent);
    }
    return Scaffold(body: mainContent);
  }

  Widget _wrap({required Widget child}) {
    if (widget.embedded) {
      return Material(color: Colors.transparent, child: child);
    }
    return Scaffold(body: SafeArea(child: child));
  }

  Widget? _buildAction(BuildContext context,
      {required String label, required IconData icon, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  Widget _buildPhaseContent(AppProvider app, Student? student,
      List<AssessmentSectionTemplate> sections, List<String> letters) {
    try {
      return _buildPhaseContentUnsafe(app, student, sections, letters);
    } catch (e) {
return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: EmptyState(
            icon: Icons.error_outline,
            title: 'حدث خطأ في عرض التقييم',
            message: 'تفاصيل: $e',
          ),
        ),
      );
    }
  }

  Widget _buildPhaseContentUnsafe(AppProvider app, Student? student,
      List<AssessmentSectionTemplate> sections, List<String> letters) {
    switch (phase) {
      case _WizardPhase.initialLoading:
        return const Center(child: CircularProgressIndicator());
      case _WizardPhase.studentSelect:
        return _StudentSelectPhase(
          app: app,
          searchQuery: _studentSearchQuery,
          onSearchChanged: (q) => setState(() => _studentSearchQuery = q),
          onSelect: (s) {
            app.selectStudent(s);
            setState(() {
              phase = _WizardPhase.programSelect;
              selectedProgram = null;
              selections.clear();
              multiSelections.clear();
              letterResults.clear();
              saved = false;
              stepIndex = 0;
              soundLetterIndex = 0;
              _showPositionPicker = false;
              _selectedErrorType = null;
              lettersList = [];
              _steps = [];
            });
          },
        );
      case _WizardPhase.programSelect:
        return _ProgramSelectPhase(
          app: app,
          onSelect: (program) async {
            // 1. Select program and build steps in one synchronous setState.
            setState(() {
              selectedProgram = program;
              selections.clear();
              multiSelections.clear();
              letterResults.clear();
              saved = false;
              stepIndex = 0;
              soundLetterIndex = 0;
              _showPositionPicker = false;
              _selectedErrorType = null;
              lettersList = [];
              _buildSteps(app);
            });

            // 2. Switch to program-filtered context.
            final student = app.selectedStudent;
            if (student != null) {
              await app.selectStudentProgramContext(
                studentId: student.id,
                programId: program.id,
                specialistId: app.isSpecialist ? app.user?.id : null,
              );
            }
            if (!mounted) return;

            // 3. Check for a saved draft; user may click resume or start fresh.
            await _checkForDraft(app);
            if (!mounted) return;

            // 3. If no draft was restored (phase is still programSelect),
            //    transition to the first active phase.
            if (phase == _WizardPhase.programSelect) {
              setState(() {
                phase = _steps.isNotEmpty
                    ? _WizardPhase.sections
                    : program.usesSpeechSounds
                        ? _WizardPhase.soundMatrix
                        : _WizardPhase.summary;
              });
              // Save the initial draft so restart always picks up stepIndex=0.
              _autoSaveDraft();
            } else {
              // Draft was restored — save again with restored state as a checkpoint.
_autoSaveDraft();
            }
          },
        );
      case _WizardPhase.sections:
        if (_steps.isEmpty) {
          return const EmptyState(
            icon: Icons.fact_check_outlined,
            title: 'لا توجد بنود تقييم',
            message: 'أضف بنود تقييم في شاشة بناء الهيكل العلاجي أولاً.',
          );
        }
        final step = _currentStep;
        if (step == null) {
          return const EmptyState(
            icon: Icons.error_outline,
            title: 'خطأ في البند',
            message: 'لم يتم العثور على بند التقييم الحالي.',
          );
        }
        return _StepView(
          step: step,
          stepIndex: stepIndex + 1,
          totalSteps: _totalSteps,
          sectionTitle: _currentSectionTitle,
          selections: selections,
          multiSelections: multiSelections,
          optionsForItem: (item) => _optionsForItem(app, item),
          onSelect: (item, option) => _handleSelect(item, option),
          onMultiSelect: (optionId, isNormal) =>
              _handleMultiSelect(optionId, isNormal),
        );
      case _WizardPhase.soundMatrix:
        return _LetterEvalPhase(
          letters: lettersList,
          currentIndex: soundLetterIndex,
          letterResults: letterResults,
          showPositionPicker: _showPositionPicker,
          selectedErrorType: _selectedErrorType,
          triggersForLetter: (letter) => _triggersForLetter(app, letter),
          allTriggers: _soundTriggersFor(app),
          onLetterResult: (letter, result) {
            setState(() {
              letterResults[letter] = result;
              _autoSaveDraft();
            });
          },
          onAdvance: () {
            setState(() {
              if (soundLetterIndex < lettersList.length - 1) {
                soundLetterIndex++;
                _showPositionPicker = false;
                _selectedErrorType = null;
              } else {
                phase = _WizardPhase.summary;
              }
              _autoSaveDraft();
            });
          },
          onPrevious: () {
            setState(() {
              if (_showPositionPicker) {
                _showPositionPicker = false;
                _selectedErrorType = null;
              } else if (soundLetterIndex > 0) {
                soundLetterIndex--;
                _showPositionPicker = false;
                _selectedErrorType = null;
              } else {
                phase = _WizardPhase.sections;
                stepIndex = _steps.length - 1;
              }
              _autoSaveDraft();
            });
          },
          onSelectErrorType: (errorType) {
            setState(() {
              _selectedErrorType = errorType;
              _showPositionPicker = true;
            });
          },
        );
      case _WizardPhase.summary:
        if (student == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: EmptyState(
                icon: Icons.error_outline,
                title: 'لم يتم اختيار طالب',
                message: 'الرجاء العودة واختيار طالب.',
              ),
            ),
          );
        }
        return _SummaryPhase(
          app: app,
          student: student,
          selections: selections,
          multiSelections: multiSelections,
          letterResults: letterResults,
          sections: sections,
          program: selectedProgram,
          saved: saved || isSaving,
        );
    }
  }

  Future<void> _saveAssessment(AppProvider app, Student student) async {
    if (isSaving) return;
    if (selectedProgram == null) {
      throw StateError('لا يمكن حفظ التقييم بدون تحديد البرنامج العلاجي.');
    }
    isSaving = true;
    setState(() {});

    try {
      final now = DateTime.now().toIso8601String();
      final assessmentId =
          'clinical_${DateTime.now().millisecondsSinceEpoch}';

      final strengths = <String>[];
      final findings = <ClinicalFinding>[];

      for (final entry in selections.entries) {
        final itemId = entry.key;
        final option = entry.value;
        final item = app.assessmentItems.firstWhere(
          (i) => i.id == itemId,
          orElse: () => AssessmentItemTemplate(
            id: itemId,
            centerId: _centerId,
            sectionId: '',
            title: '',
            responseType: 'custom',
            sortOrder: 0,
            createdAt: now,
            updatedAt: now,
          ),
        );
        final section = app.assessmentSections.firstWhere(
          (s) => s.id == item.sectionId,
          orElse: () => AssessmentSectionTemplate(
            id: '',
            centerId: _centerId,
            programId: selectedProgram?.id ?? '',
            title: '',
            sortOrder: 0,
            createdAt: now,
            updatedAt: now,
          ),
        );
        final domain = selectedProgram == null
            ? item.title
            : '${selectedProgram!.name} - ${section.title}';

        if (!option.generatesTherapy) {
          strengths.add('$domain - ${item.title}: ${option.label} - طبيعي');
        }

        findings.add(ClinicalFinding(
          id: 'finding_${itemId}_${DateTime.now().microsecondsSinceEpoch}',
          assessmentId: assessmentId,
          centerId: student.centerId,
          studentId: student.id,
          domain: domain,
          itemTitle: item.title,
          result: option.label,
          isNormal: !option.generatesTherapy,
          weakness: option.weaknessTemplate,
          goal: option.goalTemplate.isNotEmpty
              ? option.goalTemplate
              : (option.weaknessTemplate.isNotEmpty
                  ? option.weaknessTemplate
                  : option.label),
          training: option.therapyTemplate,
          programId: selectedProgram?.id ?? '',
          sourceType: 'standard',
          templateId: option.id,
          createdAt: now,
        ));
      }

      for (final entry in multiSelections.entries) {
        final optionId = entry.key;
        final isNormal = entry.value;
        final option = app.assessmentOptions.firstWhere(
          (o) => o.id == optionId,
          orElse: () => AssessmentOptionTemplate(
            id: optionId,
            centerId: _centerId,
            itemId: '',
            label: '',
            generatesTherapy: false,
            sortOrder: 0,
          ),
        );
        final item = app.assessmentItems.firstWhere(
          (i) => i.id == option.itemId,
          orElse: () => AssessmentItemTemplate(
            id: option.itemId,
            centerId: _centerId,
            sectionId: '',
            title: option.label,
            responseType: 'custom',
            sortOrder: 0,
            createdAt: now,
            updatedAt: now,
          ),
        );
        final section = app.assessmentSections.firstWhere(
          (s) => s.id == item.sectionId,
          orElse: () => AssessmentSectionTemplate(
            id: '',
            centerId: _centerId,
            programId: selectedProgram?.id ?? '',
            title: '',
            sortOrder: 0,
            createdAt: now,
            updatedAt: now,
          ),
        );
        final domain = selectedProgram == null
            ? item.title
            : '${selectedProgram!.name} - ${section.title}';

        if (isNormal) {
          strengths.add('$domain - ${item.title}: ${option.label} - طبيعي');
        }

        findings.add(ClinicalFinding(
          id: 'finding_multi_${optionId}_${DateTime.now().microsecondsSinceEpoch}',
          assessmentId: assessmentId,
          centerId: student.centerId,
          studentId: student.id,
          domain: domain,
          itemTitle: item.title,
          result: '${option.label}: ${isNormal ? 'نعم' : 'لا'}',
          isNormal: isNormal,
          weakness: isNormal ? '' : option.weaknessTemplate,
          goal: isNormal ? '' : (option.goalTemplate.isNotEmpty ? option.goalTemplate : (option.weaknessTemplate.isNotEmpty ? option.weaknessTemplate : option.label)),
          training: isNormal ? '' : option.therapyTemplate,
          programId: selectedProgram?.id ?? '',
          sourceType: 'standard',
          templateId: option.id,
          createdAt: now,
        ));
      }

      for (final entry in letterResults.entries) {
        final letter = entry.key;
        final result = entry.value;
        final isNormal = result['isNormal'] as bool? ?? true;
        final domain = selectedProgram == null
            ? 'الحروف'
            : '${selectedProgram!.name} - الحروف';

        if (isNormal) {
          strengths.add('$domain - حرف $letter - طبيعي');
        } else {
          final errorType = result['errorType'] as String? ?? '';
          final position = result['position'] as String? ?? '';
          final triggerId = result['triggerId'] as String?;
          SpeechSoundTriggerTemplate? trigger;
          if (triggerId != null) {
            trigger = app.speechSoundTriggers.firstWhere(
              (t) => t.id == triggerId,
              orElse: () => SpeechSoundTriggerTemplate(
                id: triggerId,
                centerId: _centerId,
                programId: '',
                letter: letter,
                errorType: errorType,
                position: position,
                generatesTherapy: true,
                sortOrder: 0,
              ),
            );
          }

          findings.add(ClinicalFinding(
            id: 'finding_letter_${letter}_${DateTime.now().microsecondsSinceEpoch}',
            assessmentId: assessmentId,
            centerId: student.centerId,
            studentId: student.id,
            domain: domain,
            itemTitle: 'حرف $letter - $errorType - $position',
            result: '$errorType - $position',
            isNormal: false,
            weakness: trigger?.weaknessTemplate ?? '',
            goal: trigger?.goalTemplate ?? '',
            training: trigger?.therapyTemplate ?? '',
            programId: selectedProgram?.id ?? '',
            sourceType: 'speechSound',
            templateId: trigger?.id ?? '',
            createdAt: now,
          ));
        }
      }

      final weakFindings = findings.where((f) => !f.isNormal).toList();
      final goals = weakFindings
          .map((f) => f.goal)
          .where((g) => g.trim().isNotEmpty)
          .join('\n');
      final trainings = weakFindings
          .map((f) => f.training)
          .where((t) => t.trim().isNotEmpty)
          .join('\n');
      final weaknessText = weakFindings
          .map((f) => '${f.itemTitle}: ${f.weakness}')
          .join('\n');

      await runWithFeedback(
        context,
        () async {
          await app.saveClinicalAssessment(
            assessment: ClinicalAssessment(
              id: assessmentId,
              centerId: student.centerId,
              studentId: student.id,
              specialistId: app.user?.id ?? '',
              specialistName: app.user?.name ?? '',
              type: 'speech',
              programId: selectedProgram?.id ?? '',
              strengthsSummary: strengths.join('\n'),
              weaknessesSummary: weaknessText,
              goalsSummary: goals,
              trainingSummary: trainings,
              createdAt: now,
            ),
            findings: findings,
          );
          await _clearDraft();
          if (!mounted) return;
          if (widget.onBack != null) {
            widget.onBack!();
            return;
          }
          _goToStudentSelect();
        },
        loading: 'جار حفظ التقييم العلاجي وتوليد الأهداف...',
        success: () {
          final pc = weakFindings.where((f) => f.goal.trim().isNotEmpty).length;
          return pc > 0
              ? 'تم حفظ التقييم وتوليد $pc أهداف علاجية.'
              : 'تم حفظ التقييم، لكن لم يتم توليد أهداف علاجية لأن القوالب العلاجية غير مكتملة.';
        }(),
      );
    } catch (e) {
} finally {
      isSaving = false;
      if (mounted) setState(() {});
    }
  }

  Widget _buildNavBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    switch (phase) {
      case _WizardPhase.sections:
        final isFirst = stepIndex <= 0;
        final isLast = stepIndex >= _steps.length - 1;
        return _BottomActionBar(
          colorScheme: colorScheme,
          bottomInset: bottomInset,
          leftButton: isFirst
              ? null
              : _ActionBarButtonData(
                  label: 'السابق',
                  icon: isRtl ? Icons.arrow_forward_ios : Icons.arrow_back_ios,
                  onTap: _goPrevious,
                ),
          rightButton: isLast
              ? null
              : _ActionBarButtonData(
                  label: 'التالي',
                  icon: isRtl ? Icons.arrow_back_ios : Icons.arrow_forward_ios,
                  onTap: _goNext,
                  emphasized: true,
                ),
        );
      case _WizardPhase.soundMatrix:
        return _BottomActionBar(
          colorScheme: colorScheme,
          bottomInset: bottomInset,
          leftButton: _ActionBarButtonData(
            label: 'السابق',
            icon: isRtl ? Icons.arrow_forward_ios : Icons.arrow_back_ios,
            onTap: () {
              setState(() {
                if (soundLetterIndex > 0) {
                  soundLetterIndex--;
                  _showPositionPicker = false;
                  _selectedErrorType = null;
                }
                _autoSaveDraft();
              });
            },
          ),
          rightButton: _ActionBarButtonData(
            label: 'التالي',
            icon: isRtl ? Icons.arrow_back_ios : Icons.arrow_forward_ios,
            onTap: () {
              setState(() {
                if (soundLetterIndex < lettersList.length - 1) {
                  soundLetterIndex++;
                  _showPositionPicker = false;
                  _selectedErrorType = null;
                } else {
                  phase = _WizardPhase.summary;
                }
                _autoSaveDraft();
              });
            },
            emphasized: true,
          ),
        );
      case _WizardPhase.summary:
        return _BottomActionBar(
          colorScheme: colorScheme,
          bottomInset: bottomInset,
          leftButton: _ActionBarButtonData(
            label: 'مراجعة',
            icon: Icons.edit_outlined,
            onTap: () {
              if (_steps.isNotEmpty) {
                stepIndex = _steps.length - 1;
                phase = _WizardPhase.sections;
              } else if (selectedProgram?.usesSpeechSounds == true) {
                phase = _WizardPhase.soundMatrix;
                soundLetterIndex =
                    lettersList.isNotEmpty ? lettersList.length - 1 : 0;
              }
            },
          ),
          rightButton: _ActionBarButtonData(
            label: saved ? 'تم الحفظ ✓' : 'حفظ التقييم',
            icon: saved ? Icons.check_circle : Icons.save_outlined,
            onTap: saved ? null : () => _saveAssessment(context.read<AppProvider>(), context.read<AppProvider>().selectedStudent!),
            emphasized: true,
            disabled: saved,
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _CompactHeader extends StatelessWidget {
  const _CompactHeader({
    required this.phase,
    required this.programName,
    required this.studentName,
    required this.sectionTitle,
    required this.totalSteps,
    required this.currentStep,
    this.onBackToStudentSelect,
    this.onBackToProgramSelect,
  });

  final _WizardPhase phase;
  final String programName;
  final String studentName;
  final String sectionTitle;
  final int totalSteps;
  final int currentStep;
  final VoidCallback? onBackToStudentSelect;
  final VoidCallback? onBackToProgramSelect;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final showProgress = phase == _WizardPhase.sections || phase == _WizardPhase.soundMatrix;
    final showSection = phase == _WizardPhase.sections;

    final progress = totalSteps == 0 ? 0.0 : (currentStep / totalSteps).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3), width: 0.5),
        ),
      ),
      padding: EdgeInsets.only(
        top: 8,
        left: AppSpacing.sm,
        right: AppSpacing.sm,
        bottom: showProgress ? 10 : 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (onBackToStudentSelect != null)
                SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    onPressed: onBackToStudentSelect,
                    icon: Icon(Icons.arrow_forward, size: 16, color: colorScheme.onSurfaceVariant),
                    padding: EdgeInsets.zero,
                    splashRadius: 14,
                  ),
                )
              else if (onBackToProgramSelect != null)
                SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    onPressed: onBackToProgramSelect,
                    icon: Icon(Icons.arrow_forward, size: 16, color: colorScheme.onSurfaceVariant),
                    padding: EdgeInsets.zero,
                    splashRadius: 14,
                  ),
                )
              else
                const SizedBox(width: 28),
              const SizedBox(width: 6),
              if (programName.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    programName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (showSection && sectionTitle.isNotEmpty) ...[
                Flexible(
                  child: Text(
                    sectionTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              const Spacer(),
              if (showProgress)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.checklist, size: 12, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        '$currentStep / $totalSteps',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (showProgress) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                valueColor: AlwaysStoppedAnimation<Color>(
                  colorScheme.primary.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionBarButtonData {
  const _ActionBarButtonData({
    required this.label,
    required this.icon,
    required this.onTap,
    this.emphasized = false,
    this.disabled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool emphasized;
  final bool disabled;
}

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.colorScheme,
    required this.bottomInset,
    this.leftButton,
    this.rightButton,
  });

  final ColorScheme colorScheme;
  final double bottomInset;
  final _ActionBarButtonData? leftButton;
  final _ActionBarButtonData? rightButton;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 12,
        left: AppSpacing.sm,
        right: AppSpacing.sm,
        bottom: 12 + bottomInset,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3), width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (leftButton != null)
              Expanded(
                child: _ActionBarButton(data: leftButton!),
              ),
            if (leftButton != null && rightButton != null)
              const SizedBox(width: 10),
            if (rightButton != null)
              Expanded(
                flex: rightButton!.emphasized ? 2 : 1,
                child: _ActionBarButton(data: rightButton!),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionBarButton extends StatelessWidget {
  const _ActionBarButton({required this.data});

  final _ActionBarButtonData data;

  @override
  Widget build(BuildContext context) {
    final button = data.disabled
        ? FilledButton.icon(
            onPressed: null,
            icon: Icon(data.icon, size: 18),
            label: Text(data.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          )
        : data.emphasized
            ? FilledButton.icon(
                onPressed: data.onTap,
                icon: Icon(data.icon, size: 18),
                label: Text(data.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              )
            : FilledButton.tonalIcon(
                onPressed: data.onTap,
                icon: Icon(data.icon, size: 18),
                label: Text(data.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              );

    return button;
  }
}

class _ProgramSelectPhase extends StatelessWidget {
  const _ProgramSelectPhase({
    required this.app,
    required this.onSelect,
  });

  final AppProvider app;
  final ValueChanged<TherapyProgramTemplate> onSelect;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (app.isSpecialist) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: EmptyState(
          icon: Icons.error_outline,
          title: 'لا يمكن اختيار البرنامج',
          message: 'لا يوجد برنامج علاجي مسند لك لهذا الطالب.',
        ),
      );
    }
    final programs = app.programsForStudent();
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SemanticAlertCard(
            kind: SemanticAlertKind.info,
            icon: Icons.auto_stories_outlined,
            title: 'اختر البرنامج العلاجي المناسب',
            message:
                'سيوجهك المعالج عبر أسئلة التقييم خطوة بخطوة. اختر البرنامج المناسب للطالب.',
          ),
          const SizedBox(height: AppSpacing.md),
          if (programs.isEmpty)
            const EmptyState(
              icon: Icons.auto_stories_outlined,
              title: 'لا توجد برامج علاجية مخصصة لهذا الطالب',
              message:
                  'يرجى التواصل مع مدخل البيانات لتخصيص برامج علاجية للطالب.',
            )
          else
            ResponsiveGrid(
            children: programs.map((program) {
              final sectionCount = app.assessmentSections
                  .where((s) => s.programId == program.id)
                  .length;
              final itemCount = app.assessmentItems.where((item) {
                final section = app.assessmentSections.firstWhere(
                  (s) => s.id == item.sectionId,
                  orElse: () => const AssessmentSectionTemplate(
                    id: '',
                    centerId: '',
                    programId: '',
                    title: '',
                    sortOrder: 0,
                    createdAt: '',
                    updatedAt: '',
                  ),
                );
                return section.programId == program.id;
              }).length;
              final soundCount = app.speechSoundTriggers
                  .where((t) => t.programId == program.id)
                  .length;

              return InkWell(
                borderRadius: BorderRadius.circular(AppRadii.card),
                onTap: () => onSelect(program),
                child: AppCard(
                  highlight: true,
                  padding: _rv(context, small: AppSpacing.md, large: AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: _rv(context, small: 38, large: 44),
                            height: _rv(context, small: 38, large: 44),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              program.usesSpeechSounds
                                  ? Icons.record_voice_over_outlined
                                  : Icons.psychology_alt_outlined,
                              color: colorScheme.onPrimaryContainer,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              program.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: SanadText.subtitle(context),
                            ),
                          ),
                          if (program.usesSpeechSounds)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: colorScheme.tertiaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'حروف',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: colorScheme.onTertiaryContainer,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (program.description.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(program.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: SanadText.secondary(context)),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          _StatChip(
                            label: '$sectionCount',
                            sublabel: 'أقسام',
                            color: colorScheme.primaryContainer,
                            textColor: colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _StatChip(
                            label: '$itemCount',
                            sublabel: 'بند',
                            color: colorScheme.secondaryContainer,
                            textColor: colorScheme.onSecondaryContainer,
                          ),
                          if (program.usesSpeechSounds) ...[
                            const SizedBox(width: AppSpacing.sm),
                            _StatChip(
                              label: '$soundCount',
                              sublabel: 'حرف',
                              color: colorScheme.tertiaryContainer,
                              textColor: colorScheme.onTertiaryContainer,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: () => onSelect(program),
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('بدء التقييم'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.sublabel,
    required this.color,
    required this.textColor,
  });

  final String label;
  final String sublabel;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            sublabel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor.withValues(alpha: .8),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentSelectPhase extends StatefulWidget {
  const _StudentSelectPhase({
    required this.app,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onSelect,
  });

  final AppProvider app;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<Student> onSelect;

  @override
  State<_StudentSelectPhase> createState() => _StudentSelectPhaseState();
}

class _StudentSelectPhaseState extends State<_StudentSelectPhase> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(_StudentSelectPhase oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery &&
        widget.searchQuery != _controller.text) {
      _controller.text = widget.searchQuery;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final students = widget.app.students.where((s) {
      if (widget.searchQuery.isEmpty) return true;
      return s.name.contains(widget.searchQuery);
    }).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SemanticAlertCard(
            kind: SemanticAlertKind.info,
            icon: Icons.info_outline,
            title: 'اختر الطالب الذي تريد تقييمه',
            message: 'يمكنك البحث بالاسم. الطلاب المعروضون هم طلابك المسجلون.',
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'ابحث باسم الطالب...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.control),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: widget.onSearchChanged,
          ),
          const SizedBox(height: AppSpacing.md),
          if (students.isEmpty)
            EmptyState(
              icon: Icons.person_off_outlined,
              title: widget.searchQuery.isEmpty
                  ? 'لا يوجد طلاب'
                  : 'لا توجد نتائج',
              message: widget.searchQuery.isEmpty
                  ? 'لم يتم العثور على طلاب.'
                  : 'لم يتم العثور على طلاب بهذا الاسم.',
            )
          else
            ResponsiveGrid(
              children: students.map((student) {
                final studentPrograms = widget.app.programsForStudent();
                return InkWell(
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  onTap: () => widget.onSelect(student),
                  child: AppCard(
                    highlight: true,
                    padding: _rv(context, small: AppSpacing.md, large: AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            StudentAvatar(student: student, radius: _rv(context, small: 20, large: 24)),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    student.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: SanadText.subtitle(context),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      if (student.age > 0)
                                        Flexible(
                                          child: Text(
                                            '${student.age} سنة',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: colorScheme.onSurfaceVariant,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      if (student.age > 0 &&
                                          student.diagnosis.isNotEmpty)
                                        Text(
                                          '  •  ',
                                          style: TextStyle(
                                            color: colorScheme.outline,
                                          ),
                                        ),
                                      if (student.diagnosis.isNotEmpty)
                                        Expanded(
                                          child: Text(
                                            student.diagnosis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: colorScheme.onSurfaceVariant,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (studentPrograms.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          SizedBox(
                            height: 30,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: studentPrograms.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 6),
                              itemBuilder: (_, i) {
                                final p = studentPrograms[i];
                                return AppPill(
                                  label: p.name,
                                  icon: p.usesSpeechSounds
                                      ? Icons.record_voice_over_outlined
                                      : Icons.psychology_alt_outlined,
                                  selected: true,
                                );
                              },
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: () => widget.onSelect(student),
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('اختيار الطالب'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _StepView extends StatelessWidget {
  const _StepView({
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.sectionTitle,
    required this.selections,
    required this.multiSelections,
    required this.optionsForItem,
    required this.onSelect,
    required this.onMultiSelect,
  });

  final _AssessmentStep step;
  final int stepIndex;
  final int totalSteps;
  final String sectionTitle;
  final Map<String, AssessmentOptionTemplate> selections;
  final Map<String, bool> multiSelections;
  final List<AssessmentOptionTemplate> Function(AssessmentItemTemplate)
      optionsForItem;
  final void Function(AssessmentItemTemplate, AssessmentOptionTemplate)
      onSelect;
  final void Function(String optionId, bool isNormal) onMultiSelect;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final item = step.item;
    final isMulti = item.responseMode == 'multiResponse';
    final bool isAnswered = isMulti
        ? (step.option != null && multiSelections.containsKey(step.option!.id))
        : selections.containsKey(item.id);
    final narrow = MediaQuery.of(context).size.width < 400;
    final progress = totalSteps == 0 ? 0.0 : ((stepIndex + 1) / totalSteps).clamp(0.0, 1.0);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      child: SingleChildScrollView(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: Column(
          key: ValueKey('step_$stepIndex'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero Question Card
            Container(
              padding: EdgeInsets.all(narrow ? AppSpacing.md : AppSpacing.lg),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top row: progress + section chip
                  Row(
                    children: [
                      if (sectionTitle.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: colorScheme.tertiaryContainer.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            sectionTitle,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onTertiaryContainer,
                            ),
                          ),
                        ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline, size: 12, color: colorScheme.primary),
                            const SizedBox(width: 4),
                            Text(
                              '${stepIndex + 1} / $totalSteps',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: narrow ? AppSpacing.md : AppSpacing.lg),
                  // Icon with glow
                  Center(
                    child: Container(
                      width: narrow ? 56 : 64,
                      height: narrow ? 56 : 64,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isAnswered
                              ? [const Color(0xFFDCFCE7), const Color(0xFFBBF7D0)]
                              : [
                                  colorScheme.primaryContainer,
                                  colorScheme.primaryContainer.withValues(alpha: 0.7),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: isAnswered
                                ? const Color(0xFF22C55E).withValues(alpha: 0.15)
                                : colorScheme.primary.withValues(alpha: 0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        isMulti
                            ? Icons.list_alt_rounded
                            : Icons.checklist_rounded,
                        color: isAnswered
                            ? const Color(0xFF166534)
                            : colorScheme.onPrimaryContainer,
                        size: narrow ? 28 : 32,
                      ),
                    ),
                  ),
                  SizedBox(height: narrow ? AppSpacing.md : AppSpacing.lg),
                  // Question title
                  Text(
                    item.title,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: narrow ? 18 : 22,
                      fontWeight: FontWeight.w900,
                      height: 1.3,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  if (item.prompt.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      item.prompt,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                  SizedBox(height: narrow ? AppSpacing.md : AppSpacing.lg),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.primary.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  SizedBox(height: narrow ? AppSpacing.md : AppSpacing.lg),
                  // Options
                  if (isMulti)
                    _MultiResponseOption(
                      option: step.option!,
                      multiSelections: multiSelections,
                      onMultiSelect: onMultiSelect,
                    )
                  else
                    _SingleChoiceOptions(
                      item: item,
                      options: optionsForItem(item),
                      selected: selections[item.id],
                      onSelect: (option) => onSelect(item, option),
                    ),
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

class _SingleChoiceOptions extends StatelessWidget {
  const _SingleChoiceOptions({
    required this.item,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final AssessmentItemTemplate item;
  final List<AssessmentOptionTemplate> options;
  final AssessmentOptionTemplate? selected;
  final ValueChanged<AssessmentOptionTemplate> onSelect;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: options.map((option) {
        final active = selected?.id == option.id;
        final needsTherapy = option.generatesTherapy;

        final bgColor = active
            ? (needsTherapy
                ? const Color(0xFFFEF3C7)
                : const Color(0xFFDCFCE7))
            : colorScheme.surface;
        final borderColor = active
            ? (needsTherapy
                ? const Color(0xFFF59E0B)
                : const Color(0xFF22C55E))
            : colorScheme.outlineVariant.withValues(alpha: 0.5);
        final textColor = active
            ? (needsTherapy
                ? const Color(0xFF92400E)
                : const Color(0xFF166534))
            : colorScheme.onSurface;

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: GestureDetector(
            onTap: () => onSelect(option),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: borderColor,
                  width: active ? 2 : 1,
                ),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: borderColor.withValues(alpha: 0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: active ? 28 : 24,
                    height: active ? 28 : 24,
                    decoration: BoxDecoration(
                      color: active ? borderColor : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: active ? borderColor : colorScheme.outlineVariant,
                        width: active ? 0 : 2,
                      ),
                    ),
                    child: active
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          option.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                            height: 1.3,
                          ),
                        ),
                        if (needsTherapy) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7).withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              option.therapyTemplate.isNotEmpty
                                  ? 'سيولد هدفًا علاجيًا'
                                  : 'يحتاج علاجًا',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (needsTherapy)
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7).withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.psychology_alt_outlined,
                        size: 18,
                        color: const Color(0xFF92400E),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _MultiResponseOption extends StatelessWidget {
  const _MultiResponseOption({
    required this.option,
    required this.multiSelections,
    required this.onMultiSelect,
  });

  final AssessmentOptionTemplate option;
  final Map<String, bool> multiSelections;
  final void Function(String optionId, bool isNormal) onMultiSelect;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final result = multiSelections[option.id];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            option.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: colorScheme.onSurface,
            ),
          ),
          if (option.therapyTemplate.isNotEmpty && result == null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7).withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'سيولد تدريبًا',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF92400E),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 320;
              final buttons = [
                _buildToggle(context, 'نعم، طبيعي', Icons.check_circle_outline,
                    result == true, true, () {
                  if (result != true) onMultiSelect(option.id, true);
                }),
                const SizedBox(width: AppSpacing.sm),
                _buildToggle(context, 'لا، يحتاج تدخل', Icons.report_problem_outlined,
                    result == false, false, () {
                  if (result != false) onMultiSelect(option.id, false);
                }),
              ];

              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    buttons[0],
                    const SizedBox(height: AppSpacing.sm),
                    buttons[2],
                  ],
                );
              }
              return Row(children: buttons);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToggle(BuildContext context, String label, IconData icon,
      bool selected, bool positive, VoidCallback onTap) {
    final colorScheme = Theme.of(context).colorScheme;
    final bgColor = selected
        ? (positive
            ? const Color(0xFFDCFCE7)
            : const Color(0xFFFEF3C7))
        : colorScheme.surface;
    final borderColor = selected
        ? (positive
            ? const Color(0xFF22C55E)
            : const Color(0xFFF59E0B))
        : colorScheme.outlineVariant.withValues(alpha: 0.4);
    final fgColor = selected
        ? (positive
            ? const Color(0xFF166534)
            : const Color(0xFF92400E))
        : colorScheme.onSurfaceVariant;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: borderColor.withValues(alpha: 0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: fgColor),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: fgColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LetterEvalPhase extends StatelessWidget {
  const _LetterEvalPhase({
    required this.letters,
    required this.currentIndex,
    required this.letterResults,
    required this.showPositionPicker,
    required this.selectedErrorType,
    required this.triggersForLetter,
    required this.allTriggers,
    required this.onLetterResult,
    required this.onAdvance,
    required this.onPrevious,
    required this.onSelectErrorType,
  });

  final List<String> letters;
  final int currentIndex;
  final Map<String, Map<String, dynamic>> letterResults;
  final bool showPositionPicker;
  final String? selectedErrorType;
  final List<SpeechSoundTriggerTemplate> Function(String) triggersForLetter;
  final List<SpeechSoundTriggerTemplate> allTriggers;
  final void Function(String, Map<String, dynamic>) onLetterResult;
  final VoidCallback onAdvance;
  final VoidCallback onPrevious;
  final void Function(String) onSelectErrorType;

  static const errorTypes = ['حذف', 'إبدال', 'إضافة', 'تشويه'];

  String get _currentLetter =>
      currentIndex < letters.length ? letters[currentIndex] : '';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final letter = _currentLetter;
    if (letter.isEmpty) {
      return const EmptyState(
        icon: Icons.abc_outlined,
        title: 'لا توجد حروف',
        message:
            'لم يتم تعريف أي حروف لهذا البرنامج في بناء الهيكل العلاجي.',
      );
    }

    final existingResult = letterResults[letter];
    final isAlreadyNormal =
        existingResult != null && (existingResult['isNormal'] as bool?) == true;
    final isAlreadyError = existingResult != null &&
        (existingResult['isNormal'] as bool?) == false;
    final alreadyHasErrorType = existingResult?['errorType'] as String?;
    final alreadyHasPosition = existingResult?['position'] as String?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.all(_rv(context, small: AppSpacing.md, large: AppSpacing.xl)),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: _rv(context, small: 110, large: 150),
                    height: _rv(context, small: 110, large: 150),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isAlreadyError
                            ? [const Color(0xFFFEF3C7), const Color(0xFFFDE68A)]
                            : isAlreadyNormal
                                ? [const Color(0xFFDCFCE7), const Color(0xFFBBF7D0)]
                                : [colorScheme.surfaceContainerHighest, colorScheme.surfaceContainerHighest],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isAlreadyError
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.6)
                            : isAlreadyNormal
                                ? const Color(0xFF22C55E).withValues(alpha: 0.6)
                                : colorScheme.outlineVariant.withValues(alpha: 0.3),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isAlreadyError
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.1)
                              : isAlreadyNormal
                                  ? const Color(0xFF22C55E).withValues(alpha: 0.1)
                                  : Colors.transparent,
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      letter,
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            fontSize: _rv(context, small: 42, large: 64),
                            color: isAlreadyError
                                ? const Color(0xFF92400E)
                                : isAlreadyNormal
                                    ? const Color(0xFF166534)
                                    : colorScheme.onSurface,
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (isAlreadyNormal)
                  const AppPill(
                    label: 'تم التقييم: طبيعي ✓',
                    icon: Icons.check_circle,
                    selected: true,
                  ),
                if (isAlreadyError)
                  AppPill(
                    label: 'تم التقييم: $alreadyHasErrorType - $alreadyHasPosition',
                    icon: Icons.check_circle,
                    selected: true,
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          if (showPositionPicker) ...[
            SemanticAlertCard(
              kind: SemanticAlertKind.warning,
              icon: Icons.error_outline,
              title: 'نوع الخطأ: $selectedErrorType',
              message:
                  'اختر الموضع الذي يظهر فيه الخطأ في الحرف $letter.',
            ),
            const SizedBox(height: AppSpacing.md),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 360) {
                final positions = ['أول', 'وسط', 'آخر'];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: positions.map((pos) {
                    final isSelected = alreadyHasPosition == pos;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: SizedBox(
                        width: double.infinity,
                        height: 64,
                        child: FilledButton.tonal(
                          onPressed: isSelected
                              ? null
                              : () {
                                  final errorType = selectedErrorType ??
                                      alreadyHasErrorType ?? '';
                                  final matching =
                                      triggersForLetter(letter).where((t) =>
                                          t.errorType == errorType &&
                                          t.position == pos);
                                  final trigger = matching.isNotEmpty
                                      ? matching.first
                                      : null;
                                  onLetterResult(letter, {
                                    'isNormal': false,
                                    'errorType': errorType,
                                    'position': pos,
                                    'triggerId': trigger?.id ?? '',
                                  });
                                  onAdvance();
                                },
                          style: FilledButton.styleFrom(
                            backgroundColor: isSelected
                                ? colorScheme.primaryContainer
                                : null,
                          ),
                          child: Text(
                            pos,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              } else {
                return Row(
                  children: ['أول', 'وسط', 'آخر'].map((pos) {
                    final isSelected = alreadyHasPosition == pos;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: pos != 'آخر' ? AppSpacing.sm : 0,
                        ),
                        child: SizedBox(
                          height: 80,
                          child: FilledButton.tonal(
                            onPressed: isSelected
                                ? null
                                : () {
                                    final errorType = selectedErrorType ??
                                        alreadyHasErrorType ?? '';
                                    final matching =
                                        triggersForLetter(letter).where((t) =>
                                            t.errorType == errorType &&
                                            t.position == pos);
                                    final trigger = matching.isNotEmpty
                                        ? matching.first
                                        : null;
                                    onLetterResult(letter, {
                                      'isNormal': false,
                                      'errorType': errorType,
                                      'position': pos,
                                      'triggerId': trigger?.id ?? '',
                                    });
                                    onAdvance();
                                  },
                            style: FilledButton.styleFrom(
                              backgroundColor: isSelected
                                  ? colorScheme.primaryContainer
                                  : null,
                            ),
                            child: Text(
                              pos,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: TextButton.icon(
              onPressed: onPrevious,
              icon: const Icon(Icons.arrow_back),
              label: const Text('تغيير نوع الخطأ'),
            ),
          ),
        ] else ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              height: 64,
              child: FilledButton.icon(
                onPressed: isAlreadyNormal
                    ? null
                    : () {
                        onLetterResult(letter, {'isNormal': true});
                        onAdvance();
                      },
                icon: Icon(
                  isAlreadyNormal
                      ? Icons.check_circle
                      : Icons.check_circle_outline,
                  size: 28,
                ),
                label: Text(
                  isAlreadyNormal ? 'تم التقييم: طبيعي ✓' : 'طبيعي',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: isAlreadyNormal
                      ? const Color(0xFFDCFCE7)
                      : null,
                  foregroundColor: isAlreadyNormal
                      ? const Color(0xFF166534)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.3), height: 1),
            const SizedBox(height: AppSpacing.md),
            Text(
              'أو حدد نوع الخطأ:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...errorTypes.map((errorType) {
              final isActive = alreadyHasErrorType == errorType;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: isActive
                        ? null
                        : () => onSelectErrorType(errorType),
                    icon: Icon(
                        isActive ? Icons.check_circle : Icons.error_outline,
                        color: isActive
                            ? const Color(0xFF92400E)
                            : null),
                    label: Text(
                      errorType,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isActive
                            ? const Color(0xFF92400E)
                            : null,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: isActive
                          ? const Color(0xFFFEF3C7)
                          : null,
                      side: isActive
                          ? const BorderSide(color: Color(0xFFF59E0B), width: 2)
                          : BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],

          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _SummaryPhase extends StatelessWidget {
  const _SummaryPhase({
    required this.app,
    required this.student,
    required this.selections,
    required this.multiSelections,
    required this.letterResults,
    required this.sections,
    required this.program,
    required this.saved,
  });

  final AppProvider app;
  final Student student;
  final Map<String, AssessmentOptionTemplate> selections;
  final Map<String, bool> multiSelections;
  final Map<String, Map<String, dynamic>> letterResults;
  final List<AssessmentSectionTemplate> sections;
  final TherapyProgramTemplate? program;
  final bool saved;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final strengths = <String>[];
    final weaknesses = <_SummaryRow>[];

    for (final entry in selections.entries) {
      final item = app.assessmentItems.firstWhere(
        (i) => i.id == entry.key,
        orElse: () => AssessmentItemTemplate(
          id: entry.key,
          centerId: '',
          sectionId: '',
          title: entry.key,
          responseType: 'custom',
          sortOrder: 0,
          createdAt: '',
          updatedAt: '',
        ),
      );
      final option = entry.value;

      if (option.generatesTherapy) {
        weaknesses.add(_SummaryRow(
          title: item.title,
          weakness: option.weaknessTemplate,
          goal: option.goalTemplate,
          training: option.therapyTemplate,
        ));
      } else {
        strengths.add(item.title);
      }
    }

    for (final entry in multiSelections.entries) {
      final optionId = entry.key;
      final isNormal = entry.value;
      final option = app.assessmentOptions.firstWhere(
        (o) => o.id == optionId,
        orElse: () => AssessmentOptionTemplate(
          id: optionId,
          centerId: '',
          itemId: '',
          label: '',
          generatesTherapy: false,
          sortOrder: 0,
        ),
      );
      final item = app.assessmentItems.firstWhere(
        (i) => i.id == option.itemId,
        orElse: () => AssessmentItemTemplate(
          id: option.itemId,
          centerId: '',
          sectionId: '',
          title: option.label,
          responseType: 'custom',
          sortOrder: 0,
          createdAt: '',
          updatedAt: '',
        ),
      );

      if (isNormal) {
        strengths.add('${item.title} - ${option.label}');
      } else {
        weaknesses.add(_SummaryRow(
          title: '${item.title} - ${option.label}',
          weakness: option.weaknessTemplate,
          goal: option.goalTemplate,
          training: option.therapyTemplate,
        ));
      }
    }

    for (final entry in letterResults.entries) {
      final letter = entry.key;
      final result = entry.value;
      final isNormal = result['isNormal'] as bool? ?? true;
      if (isNormal) {
        strengths.add('حرف $letter - طبيعي');
      } else {
        final errorType = result['errorType'] as String? ?? '';
        final position = result['position'] as String? ?? '';
        final triggerId = result['triggerId'] as String? ?? '';
        SpeechSoundTriggerTemplate? trigger;
        if (triggerId.isNotEmpty) {
          trigger = app.speechSoundTriggers.firstWhere(
            (t) => t.id == triggerId,
            orElse: () => SpeechSoundTriggerTemplate(
              id: triggerId,
              centerId: '',
              programId: program?.id ?? '',
              letter: letter,
              errorType: errorType,
              position: position,
              generatesTherapy: true,
              sortOrder: 0,
            ),
          );
        }
        weaknesses.add(_SummaryRow(
          title: 'حرف $letter - $errorType - $position',
          weakness: trigger?.weaknessTemplate ?? '',
          goal: trigger?.goalTemplate ?? '',
          training: trigger?.therapyTemplate ?? '',
          skillSteps: trigger?.skillStepTemplates ?? [],
        ));
      }
    }

    final goals = weaknesses
        .where((w) => w.goal.trim().isNotEmpty)
        .map((w) => _SummaryGoalItem(goal: w.goal, training: w.training))
        .toList();

    final skillSteps = () {
      final result = <String>[];
      for (final w in weaknesses) {
        if (w.skillSteps.isNotEmpty) {
          result.addAll(w.skillSteps);
        } else if (w.goal.trim().isNotEmpty) {
          result.add(w.goal);
        }
      }
      return result;
    }();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Student and program info header
          Container(
            padding: EdgeInsets.all(_rv(context, small: AppSpacing.md, large: AppSpacing.lg)),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                StudentAvatar(student: student, radius: 24),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(student.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onSurface,
                          )),
                      const SizedBox(height: 2),
                      Text(
                        program?.name ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.checklist, size: 14,
                          color: colorScheme.onSecondaryContainer),
                      const SizedBox(width: 4),
                      Text(
                        '${selections.length + multiSelections.length + letterResults.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: _rv(context, small: AppSpacing.sm, large: AppSpacing.md)),
          // Summary info banner
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: colorScheme.primaryContainer.withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.summarize_outlined, size: 20, color: colorScheme.onPrimaryContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'ملخص التقييم — راجع النتائج قبل الحفظ',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: _rv(context, small: AppSpacing.sm, large: AppSpacing.md)),
          // Strengths
          _SummarySectionCard(
            title: 'نقاط القوة',
            icon: Icons.verified_outlined,
            headerColor: const Color(0xFFDCFCE7),
            headerIconColor: const Color(0xFF166534),
            itemCount: strengths.length,
            child: strengths.isEmpty
                ? Text('لا توجد نقاط قوة مسجلة',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: strengths.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.check, size: 14, color: Color(0xFF166534)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(s, maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: colorScheme.onSurface,
                                height: 1.4,
                              )),
                          ),
                        ],
                      ),
                    )).toList(),
                  ),
          ),
          SizedBox(height: _rv(context, small: AppSpacing.sm, large: AppSpacing.md)),
          // Weaknesses
          _SummarySectionCard(
            title: 'نقاط الضعف',
            icon: Icons.flag_outlined,
            headerColor: const Color(0xFFFEF3C7),
            headerIconColor: const Color(0xFF92400E),
            itemCount: weaknesses.length,
            child: weaknesses.isEmpty
                ? Text('لا توجد نقاط ضعف',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: weaknesses.map((w) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7).withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFFEF3C7).withValues(alpha: 0.5),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF59E0B),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(w.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        color: colorScheme.onSurface,
                                      )),
                                ),
                              ],
                            ),
                            if (w.weakness.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(w.weakness,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colorScheme.onSurfaceVariant,
                                    height: 1.4,
                                  )),
                            ],
                          ],
                        ),
                      ),
                    )).toList(),
                  ),
          ),
          SizedBox(height: _rv(context, small: AppSpacing.sm, large: AppSpacing.md)),
          // Goals
          _SummarySectionCard(
            title: 'الأهداف العلاجية',
            icon: Icons.track_changes_outlined,
            headerColor: colorScheme.primaryContainer,
            headerIconColor: colorScheme.onPrimaryContainer,
            itemCount: goals.length,
            child: goals.isEmpty
                ? Text('لا توجد أهداف',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: goals.map((g) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.flag_circle_outlined, size: 20, color: colorScheme.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(g.goal,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        color: colorScheme.onSurface,
                                        height: 1.4,
                                      )),
                                ),
                              ],
                            ),
                            if (g.training.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.fitness_center, size: 14, color: colorScheme.onSurfaceVariant),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text('تدريب: ${g.training}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: colorScheme.onSurfaceVariant,
                                          )),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )).toList(),
                  ),
          ),
          if (skillSteps.isNotEmpty) ...[
            SizedBox(height: _rv(context, small: AppSpacing.sm, large: AppSpacing.md)),
            _SummarySectionCard(
              title: 'الخطوات المهارية',
              icon: Icons.format_list_numbered_outlined,
              headerColor: colorScheme.secondaryContainer,
              headerIconColor: colorScheme.onSecondaryContainer,
              itemCount: skillSteps.length,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: skillSteps.asMap().entries.map((e) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: colorScheme.secondaryContainer.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Center(
                          child: Text(
                            '${e.key + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(e.value, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurface,
                        )),
                    ],
                  ),
                )).toList(),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _SummaryGoalItem {
  const _SummaryGoalItem({
    required this.goal,
    required this.training,
  });

  final String goal;
  final String training;
}

class _SummaryRow {
  const _SummaryRow({
    required this.title,
    required this.weakness,
    required this.goal,
    required this.training,
    this.skillSteps = const [],
  });

  final String title;
  final String weakness;
  final String goal;
  final String training;
  final List<String> skillSteps;
}

class _SummarySectionCard extends StatelessWidget {
  const _SummarySectionCard({
    required this.title,
    required this.icon,
    required this.headerColor,
    required this.headerIconColor,
    required this.itemCount,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Color headerColor;
  final Color headerIconColor;
  final int itemCount;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
            child: Row(
              children: [
                Container(
                  width: _rv(context, small: 32, large: 36),
                  height: _rv(context, small: 32, large: 36),
                  decoration: BoxDecoration(
                    color: headerColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: headerIconColor),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      )),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: headerColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$itemCount',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: headerIconColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: child,
          ),
        ],
      ),
    );
  }
}


