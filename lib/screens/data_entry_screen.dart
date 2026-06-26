import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../widgets/app_widgets.dart';
import '../widgets/feedback.dart';

class DataEntryScreen extends StatefulWidget {
  const DataEntryScreen({super.key});

  @override
  State<DataEntryScreen> createState() => _DataEntryScreenState();
}

class _DataEntryScreenState extends State<DataEntryScreen> {
  final parentName = TextEditingController();
  final parentPhone = TextEditingController();
  final childName = TextEditingController();
  final childAge = TextEditingController();
  String diagnosis = 'توحد';
  final Set<String> _selectedProgramIds = {};

  static const diagnoses = [
    'توحد',
    'اضطرابات صوت ونطق',
    'صعوبة تعلم',
    'إعاقة سمعية',
    'إعاقة ذهنية',
    'إعاقة حركية',
    'إعاقة بصرية',
    'أخرى',
  ];

  @override
  void dispose() {
    parentName.dispose();
    parentPhone.dispose();
    childName.dispose();
    childAge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final phone = _normalizePhone(parentPhone.text);
    final username = phone.isEmpty ? 'رقم الجوال' : phone;
    final familyChildren = phone.isEmpty
        ? <Student>[]
        : app.students
            .where((student) => student.parentPhone == phone)
            .toList();

    return SingleChildScrollView(
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('بيانات ولي الأمر',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 280,
                    child: TextField(
                      controller: parentName,
                      decoration:
                          const InputDecoration(labelText: 'اسم ولي الأمر'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: parentPhone,
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.left,
                      decoration:
                          const InputDecoration(labelText: 'رقم الجوال'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  SizedBox(
                    width: 260,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                          labelText: 'اسم دخول ولي الأمر'),
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(username, textAlign: TextAlign.left, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('إضافة طفل',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 280,
                    child: TextField(
                      controller: childName,
                      decoration: const InputDecoration(labelText: 'اسم الطفل'),
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: childAge,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'العمر'),
                    ),
                  ),
                  SizedBox(
                    width: 240,
                    child: DropdownButtonFormField<String>(
                      initialValue: diagnosis,
                      decoration: const InputDecoration(labelText: 'التشخيص'),
                      items: diagnoses
                          .map((item) =>
                              DropdownMenuItem(value: item, child: Text(item, maxLines: 1, overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (value) =>
                          setState(() => diagnosis = value ?? diagnosis),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('البرامج العلاجية للطفل',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (sortedPrograms.isEmpty)
                const Text('لا توجد برامج علاجية متاحة.',
                    style: TextStyle(color: Colors.grey))
              else
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: sortedPrograms.map((program) {
                    final checked = _selectedProgramIds.contains(program.id);
                    return FilterChip(
                      label: Text(program.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      selected: checked,
                      onSelected: (value) {
                        setState(() {
                          if (value) {
                            _selectedProgramIds.add(program.id);
                          } else {
                            _selectedProgramIds.remove(program.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _saveChild(context),
                icon: const Icon(Icons.person_add_alt),
                label: const Text('حفظ الطفل'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (familyChildren.isNotEmpty)
          ResponsiveGrid(
            children: familyChildren
                .map((student) => AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.child_care_outlined),
                            title: Text(student.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                                '${student.age} سنوات - ${student.diagnosis}', maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () =>
                                _manageStudentPrograms(context, student),
                            icon: const Icon(Icons.auto_stories_outlined),
                            label: const Text('البرامج العلاجية'),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
      ],
      ),
    );
  }

  Future<void> _manageStudentPrograms(
      BuildContext context, Student student) async {
    final app = context.read<AppProvider>();
    await app.selectStudent(student);
    setState(() {});
    if (!context.mounted) return;
    final assignedIds = Set<String>.from(app.studentProgramIds);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('البرامج العلاجية: ${student.name}', maxLines: 1, overflow: TextOverflow.ellipsis),
            content: SizedBox(
              width: MediaQuery.of(context).size.width.clamp(300, 400).toDouble(),
              child: app.therapyPrograms.isEmpty
                  ? const Text('لا توجد برامج علاجية متاحة.')
                  : SingleChildScrollView(
                      child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: app.therapyPrograms.map((program) {
                        final isAssigned = assignedIds.contains(program.id);
                        return CheckboxListTile(
                          title: Text(program.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: program.description.isNotEmpty
                              ? Text(program.description, maxLines: 2, overflow: TextOverflow.ellipsis)
                              : null,
                          value: isAssigned,
                          onChanged: (value) async {
                            if (value == true) {
                              await app.assignStudentProgram(
                                  student.id, program.id);
                            } else {
                              await app.unassignStudentProgram(
                                  student.id, program.id);
                            }
                            setDialogState(() {
                              if (value == true) {
                                assignedIds.add(program.id);
                              } else {
                                assignedIds.remove(program.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إغلاق'),
              ),
            ],
          );
        },
      ),
    );
  }

  List<TherapyProgramTemplate> get sortedPrograms {
    final app = context.read<AppProvider>();
    final list = List<TherapyProgramTemplate>.from(app.therapyPrograms);
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  Future<void> _saveChild(BuildContext context) {
    return runWithFeedback(context, () async {
      final app = context.read<AppProvider>();
      final phone = _normalizePhone(parentPhone.text);
      final name = childName.text.trim();
      final parent = parentName.text.trim();
      if (parent.isEmpty || phone.isEmpty || name.isEmpty) {
        throw StateError('أكمل بيانات ولي الأمر واسم الطفل.');
      }
      if (_selectedProgramIds.isEmpty) {
        throw StateError(
            'يجب تحديد برنامج علاجي واحد على الأقل للطفل.');
      }
      final childNameOnly = childName.text.trim();
      final fullName = childNameOnly.contains(parent)
          ? childNameOnly
          : '$childNameOnly $parent';
      final now = DateTime.now().millisecondsSinceEpoch;
      final student = Student(
        id: 'student_$now',
        centerId: app.activeCenterId,
        name: fullName,
        age: int.tryParse(childAge.text.trim()) ?? 0,
        status: 'نشط',
        diagnosis: diagnosis,
        programType: diagnosis == 'إعاقة سمعية' ? 'لغة إشارة' : 'نطق وتخاطب',
        parentName: parent,
        parentPhone: phone,
        portalEmail: phone,
        portalPassword: phone,
        createdAt: DateTime.now().toIso8601String(),
      );
      await app.saveStudent(student);
      for (final programId in _selectedProgramIds) {
        await app.assignStudentProgram(student.id, programId);
      }
      childName.clear();
      childAge.clear();
      _selectedProgramIds.clear();
      setState(() {});
    }, success: 'تم حفظ الطفل وربطه بحساب ولي الأمر.');
  }

  String _normalizePhone(String value) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    var normalized = value.trim();
    for (var i = 0; i < arabic.length; i++) {
      normalized = normalized.replaceAll(arabic[i], '$i');
    }
    return normalized.replaceAll(RegExp(r'[^0-9]'), '');
  }
}
