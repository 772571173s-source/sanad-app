import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../widgets/app_widgets.dart';

class AssignmentManagementScreen extends StatefulWidget {
  const AssignmentManagementScreen({super.key});

  @override
  State<AssignmentManagementScreen> createState() =>
      _AssignmentManagementScreenState();
}

class _AssignmentManagementScreenState
    extends State<AssignmentManagementScreen> {
  String query = '';
  String? selectedSpecialistId;
  String? selectedSpecialistName;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  List<AppUser> _filteredSpecialists(AppProvider app) {
    final activeAssignments =
        app.studentSpecialists.where((s) => s.isActive).toList();
    final specialistIds =
        activeAssignments.map((s) => s.specialistId).toSet();
    return app.staff
        .where((u) =>
            u.role == UserRole.specialist && specialistIds.contains(u.id))
        .where((u) => u.name.contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final specialists = _filteredSpecialists(app);
    final allSpecialists =
        app.staff.where((u) => u.role == UserRole.specialist).toList();
    final isPhase2 = selectedSpecialistId != null;

    debugPrint(
      '[AssignmentManagement] students=${app.students.length}, '
      'allSpecialists=${allSpecialists.length}, '
      'specialists=$specialists, '
      'phase2=$isPhase2',
    );

    if (_loading && app.studentSpecialists.isEmpty && allSpecialists.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final viewportH = MediaQuery.of(context).size.height;
    final overhead = isPhase2 ? 300.0 : 260.0;
    final contentHeight = (viewportH - overhead).clamp(200.0, viewportH);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(isPhase2),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: contentHeight,
          child: isPhase2
              ? _buildPhase2Content(context, app)
              : _buildPhase1Content(context, app, specialists, allSpecialists),
        ),
      ],
    );
  }

  // ─── Headers ────────────────────────────────────────────

  Widget _buildHeader(bool isPhase2) {
    if (isPhase2) {
      return Row(
        children: [
          TextButton.icon(
            onPressed: () => setState(() {
              selectedSpecialistId = null;
              selectedSpecialistName = null;
            }),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('رجوع'),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'إدارة طلاب $selectedSpecialistName',
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
          'إدارة الارتباطات',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'بحث باسم الأخصائي',
            isDense: true,
          ),
          onChanged: (value) => setState(() => query = value),
        ),
      ],
    );
  }

  // ─── Phase 1: Specialist list ───────────────────────────

  Widget _buildPhase1Content(
    BuildContext context,
    AppProvider app,
    List<AppUser> specialists,
    List<AppUser> allSpecialists,
  ) {
    if (allSpecialists.isEmpty) {
      return const EmptyState(
        icon: Icons.person_off_outlined,
        title: 'لا يوجد أخصائيون في المركز',
        message:
            'يجب إضافة أخصائيين أولًا من إدارة الموظفين قبل إمكانية ربط الطلاب.',
      );
    }

    if (specialists.isEmpty && query.trim().isEmpty) {
      return const EmptyState(
        icon: Icons.people_outline,
        title: 'لا توجد ارتباطات حالية',
        message:
            'لم يتم ربط أي طالب بأخصائي بعد. استخدم شاشة توزيع الطلاب لربط الطلاب.',
      );
    }

    if (specialists.isEmpty && query.trim().isNotEmpty) {
      return EmptyState(
        icon: Icons.search_off_outlined,
        title: 'لم يتم العثور على أخصائي بهذا الاسم',
        message:
            'لا يوجد أخصائي اسمه "${query.trim()}" في الارتباطات الحالية.',
      );
    }

    final activeAssignments =
        app.studentSpecialists.where((s) => s.isActive).toList();

    return ListView.builder(
      itemCount: specialists.length,
      itemBuilder: (context, index) {
        final specialist = specialists[index];
        final myCount = activeAssignments
            .where((s) => s.specialistId == specialist.id)
            .length;
        return _SpecialistCard(
          specialist: specialist,
          assignedCount: myCount,
          onTap: () => setState(() {
            selectedSpecialistId = specialist.id;
            selectedSpecialistName = specialist.name;
            query = '';
          }),
        );
      },
    );
  }

  // ─── Phase 2: Selected specialist's students ───────────

  Widget _buildPhase2Content(BuildContext context, AppProvider app) {
    final activeAssignments =
        app.studentSpecialists.where((s) => s.isActive).toList();
    final specialist = app.staff.firstWhere(
      (u) => u.id == selectedSpecialistId,
    );
    final myAssignments = activeAssignments
        .where((s) => s.specialistId == selectedSpecialistId)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SelectedSpecialistCard(
          specialist: specialist,
          assignedCount: myAssignments.length,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'الطلاب المرتبطون (${myAssignments.length})',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: myAssignments.isEmpty
              ? const SingleChildScrollView(
                  child: EmptyState(
                    icon: Icons.child_care_outlined,
                    title: 'لا يوجد طلاب مرتبطون بهذا الأخصائي',
                    message:
                        'لم يتم ربط أي طالب بهذا الأخصائي بعد. استخدم شاشة توزيع الطلاب لربط طالب.',
                  ),
                )
              : ListView.builder(
                  itemCount: myAssignments.length,
                  itemBuilder: (context, index) {
                    final assignment = myAssignments[index];
                    final student = app.students
                        .where((s) => s.id == assignment.studentId)
                        .firstOrNull;
                    if (student == null) {
                      return const SizedBox.shrink();
                    }
                    return _AssignedStudentCard(
                      student: student,
                      assignment: assignment,
                      onUnassign: () => _unassign(
                          context, app, student.id, specialist.id),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _unassign(BuildContext context, AppProvider app,
      String studentId, String specialistId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد فك الارتباط'),
        content: const Text(
            'سيتم فك ربط هذا الطالب من الأخصائي. سيعود الطالب إلى قائمة انتظار الربط.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد فك الارتباط'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await app.unassignStudentFromSpecialist(studentId, specialistId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم فك ارتباط الطالب.')),
      );
    }
  }
}

// ─── Phase 1: Specialist card ────────────────────────────

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
                        radius: 28),
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
                FilledButton.tonalIcon(
                  onPressed: onTap,
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('عرض الطلاب'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Phase 2: Selected specialist summary card ───────────

class _SelectedSpecialistCard extends StatelessWidget {
  const _SelectedSpecialistCard({
    required this.specialist,
    required this.assignedCount,
  });

  final AppUser specialist;
  final int assignedCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      highlight: true,
      child: Row(
        children: [
          RoleAvatar(
              role: specialist.role,
              name: specialist.name,
              radius: 28),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  specialist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
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
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
            child: Text(
              '$assignedCount طالب',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Phase 2: Assigned student card with unassign ────────

class _AssignedStudentCard extends StatelessWidget {
  const _AssignedStudentCard({
    required this.student,
    required this.assignment,
    required this.onUnassign,
  });

  final Student student;
  final StudentSpecialist assignment;
  final VoidCallback onUnassign;

  String _formatDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    return '${date.year}/${date.month}/${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        child: Column(
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
              ],
            ),
            if (student.programType.isNotEmpty ||
                assignment.assignedAt.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (student.programType.isNotEmpty)
                    _miniChip(
                      student.programType,
                      colorScheme.tertiaryContainer,
                      colorScheme.onTertiaryContainer,
                    ),
                  if (assignment.assignedAt.isNotEmpty)
                    _miniChip(
                      'الربط: ${_formatDate(assignment.assignedAt)}',
                      colorScheme.secondaryContainer,
                      colorScheme.onSecondaryContainer,
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: onUnassign,
              icon: const Icon(Icons.link_off, size: 18),
              label: const Text('فك الارتباط'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.error,
                side: BorderSide(color: colorScheme.error.withValues(alpha: 0.5)),
              ),
            ),
          ],
        ),
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
