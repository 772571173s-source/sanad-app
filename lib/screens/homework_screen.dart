import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../widgets/app_widgets.dart';
import '../widgets/feedback.dart';

class HomeworkScreen extends StatefulWidget {
  const HomeworkScreen({super.key});

  @override
  State<HomeworkScreen> createState() => _HomeworkScreenState();
}

class _HomeworkScreenState extends State<HomeworkScreen> {
  int _phase = 0;
  String query = '';

  Student? _selectedStudent;
  bool _isLinked = false;

  String? _selectedProgramId;
  TrainingPlan? _selectedPlan;
  GoalSkillStep? _selectedStep;

  final _titleCtl = TextEditingController();
  final _instructionsCtl = TextEditingController();
  final _noteCtl = TextEditingController();
  final _dateCtl = TextEditingController();
  String _dueDate = '';

  @override
  void dispose() {
    _titleCtl.dispose();
    _instructionsCtl.dispose();
    _noteCtl.dispose();
    _dateCtl.dispose();
    super.dispose();
  }

  List<Student> _myStudents(AppProvider app) {
    final uid = app.user?.id ?? '';
    final myIds = app.studentProgramAssignments
        .where((a) => a.isActive && a.specialistId == uid)
        .map((a) => a.studentId)
        .toSet();
    return app.students.where((s) {
      if (!myIds.contains(s.id)) return false;
      if (query.trim().isEmpty) return true;
      return s.name.contains(query) || s.diagnosis.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final students = _myStudents(app);

    return SingleChildScrollView(
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(app),
        const SizedBox(height: AppSpacing.md),
        if (_phase == 0)
          _buildStudentPicker(students)
        else if (_phase == 1)
          _buildTypePicker()
        else if (_phase == 2)
          _buildGoalPicker(app)
        else if (_phase == 3)
          _buildSkillPicker(app)
        else if (_phase == 4)
          _buildForm(app),
      ],
      ),
    );
  }

  Widget _buildHeader(AppProvider app) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          if (_phase > 0)
            IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: () => setState(() => _phase--),
            ),
          Expanded(
            child: Text(
              _phase == 0
                  ? 'اختر طالب'
                  : _phase == 1
                      ? 'نوع الواجب'
                      : _phase == 4
                          ? 'إرسال واجب'
                          : 'اختر الهدف والمهارة',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          if (_selectedStudent != null)
            Chip(
              avatar: CircleAvatar(
                radius: 12,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(Icons.person, size: 14, color: Theme.of(context).colorScheme.primary),
              ),
              label: Text(_selectedStudent!.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
        ],
      ),
    );
  }

  // ─── Phase 0: Student picker ──────────────────────────────

  Widget _buildStudentPicker(List<Student> students) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'ابحث باسم الطالب',
          ),
          onChanged: (v) => setState(() => query = v),
        ),
        const SizedBox(height: AppSpacing.md),
        if (students.isEmpty)
          const EmptyState(
            icon: Icons.search_off_outlined,
            title: 'لا يوجد طلاب',
            message: 'لم يتم تعيين طلاب لك بعد.',
          )
        else
          ...students.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _StudentHomeworkCard(
                  student: s,
                  selected: _selectedStudent?.id == s.id,
                  onTap: () {
                    setState(() {
                      _selectedStudent = s;
                      _selectedProgramId = null;
                      _phase = 1;
                      query = '';
                    });
                  },
                ),
              )),
      ],
    );
  }

  // ─── Phase 1: Homework type ───────────────────────────────

  Widget _buildTypePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.md),
        _TypeOptionCard(
          icon: Icons.link_outlined,
          title: 'مرتبط بهدف علاجي',
          subtitle: 'اختر هدفاً ومهارة من خطة الطالب العلاجية',
          onTap: () => setState(() {
            _isLinked = true;
            _phase = 2;
          }),
        ),
        const SizedBox(height: AppSpacing.sm),
        _TypeOptionCard(
          icon: Icons.edit_note_outlined,
          title: 'واجب حر',
          subtitle: 'اكتب واجباً مخصصاً من اختيارك',
          onTap: () {
            setState(() {
              _isLinked = false;
              _phase = 4;
            });
            _syncFormFromSelection();
          },
        ),
      ],
    );
  }

  void _syncFormFromSelection() {
    if (_selectedStep != null) {
      _titleCtl.text = 'واجب: ${_selectedStep!.title}';
      _instructionsCtl.text = 'تدريب: ${_selectedStep!.title}';
    } else {
      _titleCtl.text = '';
      _instructionsCtl.text = '';
    }
    _noteCtl.text = '';
    _dueDate = '';
    _dateCtl.text = '';
  }

  List<TherapyProgramTemplate> _availablePrograms(AppProvider app) {
    if (_selectedStudent == null) return [];
    final uid = app.user?.id ?? '';
    final programIds = app.studentProgramAssignments
        .where((a) =>
            a.studentId == _selectedStudent!.id &&
            a.specialistId == uid &&
            a.isActive)
        .map((a) => a.programId)
        .toSet();
    if (programIds.isEmpty) return [];
    return app.therapyPrograms
        .where((p) => programIds.contains(p.id))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  // ─── Phase 2: Goal picker ─────────────────────────────────

  Widget _buildGoalPicker(AppProvider app) {
    final programs = _availablePrograms(app);
    final plans = app.plans.where((p) =>
        _selectedProgramId == null || p.programId == _selectedProgramId
    ).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.md),
        if (programs.length > 1) ...[
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: programs.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return FilterChip(
                    label: const Text('الكل'),
                    selected: _selectedProgramId == null,
                    onSelected: (_) =>
                        setState(() => _selectedProgramId = null),
                  );
                }
                final p = programs[index - 1];
                return FilterChip(
                  label: Text(p.name),
                  selected: _selectedProgramId == p.id,
                  onSelected: (_) =>
                      setState(() => _selectedProgramId = p.id),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (plans.isEmpty)
          const EmptyState(
            icon: Icons.track_changes_outlined,
            title: 'لا توجد أهداف',
            message: 'هذا الطالب ليس لديه أهداف علاجية بعد.',
          )
        else
          ...plans.map((plan) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _GoalCard(
                  plan: plan,
                  selected: _selectedPlan?.id == plan.id,
                  onTap: () {
                    setState(() {
                      _selectedPlan = plan;
                      _phase = 3;
                    });
                  },
                ),
              )),
      ],
    );
  }

  // ─── Phase 3: Skill step picker ────────────────────────────

  Widget _buildSkillPicker(AppProvider app) {
    if (_selectedPlan == null) return const SizedBox.shrink();
    final steps = app.stepsForGoal(_selectedPlan!.id);
    final activeSteps = steps.where((s) =>
        s.status == 'لم يبدأ' ||
        s.status == 'بمساعدة' ||
        s.status == 'يحتاج إعادة').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _GoalCard(
            plan: _selectedPlan!,
            selected: true,
            compact: true,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'اختر المهارة المراد التدرب عليها:',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (activeSteps.isEmpty)
          const EmptyState(
            icon: Icons.task_alt_outlined,
            title: 'لا توجد مهارات متاحة',
            message:
                'جميع مهارات هذا الهدف متقنة أو لا توجد مهارات بعد.',
          )
        else
          ...activeSteps.map((step) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _SkillStepCard(
                  step: step,
                  selected: _selectedStep?.id == step.id,
                  onTap: () {
                    setState(() {
                      _selectedStep = step;
                      _phase = 4;
                    });
                    _syncFormFromSelection();
                  },
                ),
              )),
      ],
    );
  }

  // ─── Phase 4: Form ──────────────────────────────────────────

  Widget _buildForm(AppProvider app) {
    final student = _selectedStudent;
    if (student == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isLinked && _selectedPlan != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _GoalCard(
              plan: _selectedPlan!,
              selected: true,
              compact: true,
            ),
          ),
        if (_isLinked && _selectedStep != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _SkillStepCard(
              step: _selectedStep!,
              selected: true,
            ),
          ),
        TextField(
          controller: _titleCtl,
          decoration: const InputDecoration(
            labelText: 'عنوان الواجب *',
            hintText: 'أدخل عنوان الواجب',
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _instructionsCtl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'التعليمات *',
            hintText: 'أدخل تعليمات الواجب',
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const TextField(
          decoration: InputDecoration(
            labelText: 'مدة التدريب المقترحة',
            hintText: 'مثال: 10 دقائق يومياً',
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          decoration: InputDecoration(
            labelText: 'تاريخ الاستحقاق',
            hintText: 'اختر تاريخ الاستحقاق',
            suffixIcon: IconButton(
              icon: const Icon(Icons.calendar_today_outlined),
              onPressed: () => _pickDate(context),
            ),
          ),
          readOnly: true,
          controller: _dateCtl,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _noteCtl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'ملاحظة لولي الأمر (اختياري)',
            hintText: 'أضف ملاحظة تود إرسالها لولي الأمر',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          onPressed: () => _sendHomework(context),
          icon: const Icon(Icons.send_outlined),
          label: const Text('إرسال الواجب',
              maxLines: 1, overflow: TextOverflow.ellipsis),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      final dateStr = picked.toIso8601String().split('T').first;
      setState(() {
        _dueDate = dateStr;
        _dateCtl.text = dateStr;
      });
    }
  }

  Future<void> _sendHomework(BuildContext context) async {
    final app = context.read<AppProvider>();
    final student = _selectedStudent;
    if (student == null) return;

    final title = _titleCtl.text.trim();
    final instructions = _instructionsCtl.text.trim();
    if (title.isEmpty || instructions.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى إدخال عنوان الواجب والتعليمات.')),
        );
      }
      return;
    }

    final now = DateTime.now();
    final exercise = Exercise(
      id: 'exercise_${now.millisecondsSinceEpoch}',
      centerId: student.centerId,
      studentId: student.id,
      title: title,
      instructions: instructions,
      dueDate: _dueDate.isEmpty
          ? now.add(const Duration(days: 7)).toIso8601String().split('T').first
          : _dueDate,
      status: 'pending',
      noteForParent: _noteCtl.text.trim(),
      programId: _selectedPlan?.programId ?? '',
      planId: _selectedPlan?.id ?? '',
      goalSkillStepId: _selectedStep?.id ?? '',
      sourceType: _selectedPlan?.sourceType ?? 'standard',
      sessionDate: now.toIso8601String().split('T').first,
      createdFromSessionResult: 'homework',
      specialistId: app.user?.id ?? '',
    );

    await runWithFeedback(context, () async {
      await app.saveExercise(exercise);
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم إرسال الواجب "$title" بنجاح.')),
      );
    }

    _reset();
  }

  void _reset() {
    setState(() {
      _phase = 0;
      _selectedStudent = null;
      _selectedProgramId = null;
      _selectedPlan = null;
      _selectedStep = null;
      _isLinked = false;
      _titleCtl.clear();
      _instructionsCtl.clear();
      _noteCtl.clear();
      _dueDate = '';
      _dateCtl.text = '';
      query = '';
    });
  }
}

// ─── Supporting widgets ─────────────────────────────────────

class _StudentHomeworkCard extends StatelessWidget {
  const _StudentHomeworkCard({
    required this.student,
    required this.selected,
    required this.onTap,
  });

  final Student student;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.card),
          color: selected ? SanadUiColors.accentBlue : null,
        ),
        child: AppCard(
          child: Row(
            children: [
              StudentAvatar(student: student, radius: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(student.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(
                      '${student.age} سنة  |  ${student.diagnosis}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeOptionCard extends StatelessWidget {
  const _TypeOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: SanadUiColors.accentBlue,
              child: Icon(icon, color: SanadUiColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_left),
          ],
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.plan,
    this.selected = false,
    this.compact = false,
    this.onTap,
  });

  final TrainingPlan plan;
  final bool selected;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(plan.goal,
                    maxLines: compact ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              if (!compact) const SizedBox(width: 8),
              if (!compact)
                Chip(
                  label: Text('${plan.progress}%',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
            ],
          ),
          if (!compact && plan.treatment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(plan.treatment,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.card),
            color: selected ? SanadUiColors.accentBlue : null,
          ),
          child: card,
        ),
      );
    }
    return card;
  }
}

class _SkillStepCard extends StatelessWidget {
  const _SkillStepCard({
    required this.step,
    this.selected = false,
    this.onTap,
  });

  final GoalSkillStep step;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color statusColor;
    switch (step.status) {
      case 'بمساعدة':
        statusColor = Colors.orange;
        break;
      case 'يحتاج إعادة':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.grey;
    }

    final card = AppCard(
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(step.status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: statusColor, fontSize: 12)),
              ],
            ),
          ),
          if (onTap != null) const Icon(Icons.chevron_left),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.card),
            color: selected ? SanadUiColors.accentAmber : null,
          ),
          child: card,
        ),
      );
    }
    return card;
  }
}
