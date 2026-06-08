import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../widgets/app_widgets.dart';
import 'exercises_parent_screen.dart';
import 'student_profile_screen.dart';

class ParentDashboardScreen extends StatelessWidget {
  const ParentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final student = app.selectedStudent;
    if (student == null) {
      return _ChildPicker(app: app);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SelectedChildHeader(app: app, student: student),
        const SizedBox(height: AppSpacing.md),
        const ExercisesParentScreen(),
        const SizedBox(height: AppSpacing.md),
        const StudentProfileScreen(),
      ],
    );
  }
}

class _ChildPicker extends StatelessWidget {
  const _ChildPicker({required this.app});

  final AppProvider app;

  @override
  Widget build(BuildContext context) {
    if (app.students.isEmpty) {
      return const EmptyState(
        icon: Icons.child_care_outlined,
        title: 'لا يوجد أطفال مرتبطون بهذا الحساب',
        message: 'راجع المركز للتأكد من ربط حساب ولي الأمر بملف الطفل.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const EmptyState(
          icon: Icons.family_restroom_outlined,
          title: 'اختر الطفل',
          message: 'اختر الطفل لعرض واجباته وجلساته وتقدمه.',
        ),
        const SizedBox(height: AppSpacing.md),
        ResponsiveGrid(
          children: app.students
              .map((student) => _ChildCard(app: app, student: student))
              .toList(),
        ),
      ],
    );
  }
}

class _ChildCard extends StatelessWidget {
  const _ChildCard({required this.app, required this.student});

  final AppProvider app;
  final Student student;

  @override
  Widget build(BuildContext context) {
    final latestHomework = app.centerExercises
        .where((item) => item.studentId == student.id)
        .toList()
      ..sort((a, b) => b.dueDate.compareTo(a.dueDate));
    return TherapyCard(
      title: student.name,
      icon: Icons.child_care_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StudentAvatar(student: student, radius: 34),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(student.programType, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    AppPill(label: student.status),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            latestHomework.isEmpty
                ? 'لا يوجد واجب حالي.'
                : 'آخر واجب: ${latestHomework.first.title}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => app.selectStudent(student),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('فتح لوحة الطفل'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedChildHeader extends StatelessWidget {
  const _SelectedChildHeader({required this.app, required this.student});

  final AppProvider app;
  final Student student;

  @override
  Widget build(BuildContext context) {
    return TherapyCard(
      title: 'لوحة ولي الأمر',
      icon: Icons.family_restroom_outlined,
      trailing: app.students.length > 1
          ? TextButton.icon(
              onPressed: () => app.selectStudent(null),
              icon: const Icon(Icons.switch_account),
              label: const Text('تغيير الطفل'),
            )
          : null,
      child: Row(
        children: [
          StudentAvatar(student: student, radius: 36),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text('${student.programType} - ${student.status}', maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
