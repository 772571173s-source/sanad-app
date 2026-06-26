import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../widgets/app_widgets.dart';
import 'clinical_assessment_wizard_screen.dart';

class SpecialistAssessmentScreen extends StatefulWidget {
  const SpecialistAssessmentScreen({super.key});

  @override
  State<SpecialistAssessmentScreen> createState() =>
      _SpecialistAssessmentScreenState();
}

class _SpecialistAssessmentScreenState
    extends State<SpecialistAssessmentScreen> {
  String query = '';
  StudentProgramAssignment? _activeAssignment;

  @override
  Widget build(BuildContext context) {
    if (_activeAssignment != null) {
      return ClinicalAssessmentWizardScreen(
        initialStudentId: _activeAssignment!.studentId,
        initialProgramId: _activeAssignment!.programId,
        embedded: true,
        onBack: () => setState(() => _activeAssignment = null),
      );
    }

    final app = context.watch<AppProvider>();
    final user = app.user;

    final assignments = user == null
        ? <dynamic>[]
        : app.studentProgramAssignments
            .where((a) =>
                a.specialistId == user.id &&
                a.isActive &&
                a.centerId == app.activeCenterId)
            .toList();

    if (user == null) {
      return const Column(
        children: [
          Expanded(
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    final studentMap = {for (final s in app.students) s.id: s};
    final programMap = {for (final p in app.therapyPrograms) p.id: p};

    if (assignments.isEmpty) {
      return const Column(
        children: [
          Expanded(
            child: Center(
              child: EmptyState(
                icon: Icons.fact_check_outlined,
                title: 'لا توجد ارتباطات نشطة',
                message:
                    'لم يتم إسناد أي طالب أو برنامج إليك بعد. تواصل مع المنسق.',
              ),
            ),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        TherapyCard(
          title: 'التقييم العلاجي',
          icon: Icons.fact_check_outlined,
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'ابحث عن طالب...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => query = v),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: assignments.length,
          itemBuilder: (context, index) {
            final assignment = assignments[index];
            final student = studentMap[assignment.studentId];
            final program = programMap[assignment.programId];

            if (student == null || program == null) {
              final studentName = student?.name ?? 'طالب';
              final programName = program?.name ?? 'برنامج';
              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange.shade100,
                    child: Text(
                      studentName.isNotEmpty ? studentName.substring(0, 1) : '?',
                      style: TextStyle(color: Colors.orange.shade800),
                    ),
                  ),
                  title: Text(studentName),
                  subtitle: Text('البرنامج: $programName'),
                  trailing: const Icon(Icons.arrow_back),
                  onTap: () {
                    setState(() => _activeAssignment = assignment);
                  },
                ),
              );
            }

            if (query.isNotEmpty &&
                !student.name.contains(query) &&
                !student.diagnosis.contains(query)) {
              return const SizedBox.shrink();
            }

            return Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    student.name.isNotEmpty
                        ? student.name.substring(0, 1)
                        : '?',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                title: Row(
                  children: [
                    Flexible(child: Text(student.name, overflow: TextOverflow.ellipsis)),
                    if (student.id.startsWith('demo_'))
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Text(
                            'تجريبي',
                            style: TextStyle(fontSize: 10, color: Colors.orange.shade800),
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: Text(program.name),
                trailing: const Icon(Icons.arrow_back),
                onTap: () {
                  setState(() => _activeAssignment = assignment);
                },
              ),
            );
          },
        ),
      ],
      ),
    );
  }
}