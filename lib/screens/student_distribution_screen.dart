import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../widgets/app_widgets.dart';
import '../widgets/feedback.dart';

class StudentDistributionScreen extends StatefulWidget {
  const StudentDistributionScreen({super.key});

  @override
  State<StudentDistributionScreen> createState() =>
      _StudentDistributionScreenState();
}

class _StudentDistributionScreenState
    extends State<StudentDistributionScreen> {
  String query = '';
  String? selectedStudentId;
  String? selectedStudentName;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  List<Student> _unassigned(AppProvider app) {
    final assignedIds = app.studentSpecialists
        .where((s) => s.isActive)
        .map((s) => s.studentId)
        .toSet();
    return app.students
        .where((s) => !assignedIds.contains(s.id))
        .where((s) => s.name.contains(query) || s.diagnosis.contains(query))
        .toList();
  }

  List<AppUser> _specialists(AppProvider app) {
    return app.staff.where((u) => u.role == UserRole.specialist).toList();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final unassigned = _unassigned(app);
    final specialists = _specialists(app);
    final isPhase2 = selectedStudentId != null;

    debugPrint(
      '[StudentDistribution] students=${app.students.length}, '
      'specialists=${specialists.length}, '
      'studentSpecialists=${app.studentSpecialists.length}, '
      'unassigned=${unassigned.length}, '
      'phase2=$isPhase2',
    );

    if (_loading && app.students.isEmpty && app.studentSpecialists.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final viewportH = MediaQuery.of(context).size.height;
    final contentHeight = (viewportH - 260).clamp(200.0, viewportH);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(context, app, unassigned.length, isPhase2),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: contentHeight,
          child: isPhase2
              ? _buildPhase2Content(context, app, specialists)
              : _buildPhase1Content(context, app, unassigned),
        ),
      ],
    );
  }

  // ─── Headers ────────────────────────────────────────────

  Widget _buildHeader(
    BuildContext context,
    AppProvider app,
    int count,
    bool isPhase2,
  ) {
    if (isPhase2) {
      return Row(
        children: [
          TextButton.icon(
            onPressed: () => setState(() {
              selectedStudentId = null;
              selectedStudentName = null;
            }),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('رجوع'),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'اختيار أخصائي لـ $selectedStudentName',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'توزيع الطلاب - بانتظار الربط ($count)',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'ابحث عن طالب',
            isDense: true,
          ),
          onChanged: (value) => setState(() => query = value),
        ),
      ],
    );
  }

  // ─── Phase 1: Student list ─────────────────────────────

  Widget _buildPhase1Content(
    BuildContext context,
    AppProvider app,
    List<Student> unassigned,
  ) {
    if (app.students.isEmpty) {
      return const EmptyState(
        icon: Icons.child_care_outlined,
        title: 'لا يوجد طلاب في المركز',
        message:
            'يتم إضافة الطلاب من شاشة إدخال البيانات (السكرتارية). بعد التسجيل، سيظهرون هنا لربطهم بأخصائي.',
      );
    }

    if (unassigned.isEmpty && query.trim().isEmpty) {
      return const EmptyState(
        icon: Icons.check_circle_outline,
        title: 'جميع الطلاب مرتبطون',
        message:
            'لا يوجد طلاب بانتظار التوزيع حاليًا. أي طالب جديد يتم تسجيله سيظهر هنا ليتم ربطه بأخصائي.',
      );
    }

    if (unassigned.isEmpty && query.trim().isNotEmpty) {
      return EmptyState(
        icon: Icons.search_off_outlined,
        title: 'لم يتم العثور على طالب بهذا الاسم',
        message: 'لا يوجد طالب اسمه "${query.trim()}" في قائمة الانتظار.',
      );
    }

    return ListView.builder(
      itemCount: unassigned.length,
      itemBuilder: (context, index) {
        final student = unassigned[index];
        return _StudentCard(
          student: student,
          onTap: () => setState(() {
            selectedStudentId = student.id;
            selectedStudentName = student.name;
            query = '';
          }),
        );
      },
    );
  }

  // ─── Phase 2: Selected student + Specialists ──────────

  Widget _buildPhase2Content(
    BuildContext context,
    AppProvider app,
    List<AppUser> specialists,
  ) {
    final student = app.students.firstWhere(
      (s) => s.id == selectedStudentId,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SelectedStudentCard(student: student),
        const SizedBox(height: AppSpacing.md),
        Text(
          'اختر الأخصائي المناسب',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: specialists.isEmpty
              ? const SingleChildScrollView(
                  child: EmptyState(
                    icon: Icons.person_off_outlined,
                    title: 'لا يوجد أخصائيون متاحون في المركز',
                    message:
                        'يجب إضافة أخصائيين أولًا من إدارة الموظفين ليتم ربط الطلاب بهم.',
                  ),
                )
              : ListView.builder(
                  itemCount: specialists.length,
                  itemBuilder: (context, index) {
                    final specialist = specialists[index];
                    final myCount = app.studentSpecialists
                        .where((s) =>
                            s.specialistId == specialist.id && s.isActive)
                        .length;
                    return _SpecialistCard(
                      specialist: specialist,
                      assignedCount: myCount,
                      onTap: () => _assign(
                          context, app, selectedStudentId!, specialist.id),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _assign(BuildContext context, AppProvider app,
      String studentId, String specialistId) async {
    await runWithFeedback(context, () async {
      await app.assignStudentToSpecialist(studentId, specialistId);
      setState(() {
        selectedStudentId = null;
        selectedStudentName = null;
      });
    }, success: 'تم ربط الطالب بالأخصائي بنجاح.');
  }
}

// ─── Phase 1: Student card (full info) ───────────────────

class _StudentCard extends StatelessWidget {
  const _StudentCard({required this.student, required this.onTap});

  final Student student;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.card),
          onTap: onTap,
          child: AppCard(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 500;
                if (narrow) {
                  return _mobileLayout(colorScheme, textTheme);
                }
                return _wideLayout(colorScheme, textTheme);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _mobileLayout(ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            StudentAvatar(student: student, radius: 28),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '${student.age} سنة',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_back_ios_new_outlined,
              color: colorScheme.onSurfaceVariant,
              size: 18,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _infoTile(
          Icons.medical_information_outlined,
          student.diagnosis,
          colorScheme.secondaryContainer,
          colorScheme.onSecondaryContainer,
        ),
        if (student.parentName.isNotEmpty) ...[
          const SizedBox(height: 6),
          _infoTile(
            Icons.person_outline,
            'ولي الأمر: ${student.parentName}',
            Colors.transparent,
            colorScheme.onSurfaceVariant,
            noBg: true,
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            if (student.programType.isNotEmpty)
              _miniChip(
                student.programType,
                colorScheme.tertiaryContainer,
                colorScheme.onTertiaryContainer,
              ),
            const Spacer(),
            Text(
              'اختيار الطالب',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_back_ios_new_outlined,
              size: 14,
              color: colorScheme.primary,
            ),
          ],
        ),
      ],
    );
  }

  Widget _wideLayout(ColorScheme colorScheme, TextTheme textTheme) {
    return IntrinsicHeight(
      child: Row(
        children: [
          StudentAvatar(student: student, radius: 32),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _miniChip(
                      '${student.age} سنة',
                      colorScheme.secondaryContainer,
                      colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: _miniChip(
                        student.diagnosis,
                        colorScheme.secondaryContainer,
                        colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
                if (student.programType.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _miniChip(
                    student.programType,
                    colorScheme.tertiaryContainer,
                    colorScheme.onTertiaryContainer,
                  ),
                ],
                if (student.parentName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'ولي الأمر: ${student.parentName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(
            Icons.arrow_back_ios_new_outlined,
            color: colorScheme.onSurfaceVariant,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, Color bg, Color fg,
      {bool noBg = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: noBg ? Colors.transparent : bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          if (!noBg) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: fg),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniChip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

// ─── Phase 2: Selected student summary card ─────────────

class _SelectedStudentCard extends StatelessWidget {
  const _SelectedStudentCard({required this.student});

  final Student student;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      highlight: true,
      child: Row(
        children: [
          StudentAvatar(student: student, radius: 28),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${student.age} سنة - ${student.diagnosis}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle, color: colorScheme.primary, size: 22),
        ],
      ),
    );
  }
}

// ─── Phase 2: Specialist card with assign button ────────

class _SpecialistCard extends StatelessWidget {
  const _SpecialistCard({
    required this.specialist,
    required this.assignedCount,
    required this.onTap,
  });

  final AppUser specialist;
  final int assignedCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.card),
          onTap: onTap,
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    RoleAvatar(
                        role: specialist.role,
                        name: specialist.name,
                        radius: 26),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            specialist.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            specialist.role.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius:
                            BorderRadius.circular(AppRadii.control),
                      ),
                      child: Text(
                        '$assignedCount طالب',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                FilledButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.person_add_alt, size: 18),
                  label: const Text('ربط بهذا الأخصائي'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
