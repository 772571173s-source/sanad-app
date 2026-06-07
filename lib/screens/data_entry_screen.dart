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

    return Column(
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
                        child: Text(username, textAlign: TextAlign.left),
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
                              DropdownMenuItem(value: item, child: Text(item)))
                          .toList(),
                      onChanged: (value) =>
                          setState(() => diagnosis = value ?? diagnosis),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _saveChild(context),
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('حفظ الطفل'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (familyChildren.isNotEmpty)
          ResponsiveGrid(
            children: familyChildren
                .map((student) => AppCard(
                      child: ListTile(
                        leading: const Icon(Icons.child_care_outlined),
                        title: Text(student.name),
                        subtitle:
                            Text('${student.age} سنوات - ${student.diagnosis}'),
                      ),
                    ))
                .toList(),
          ),
      ],
    );
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
      final now = DateTime.now().millisecondsSinceEpoch;
      await app.saveStudent(Student(
        id: 'student_$now',
        centerId: app.activeCenterId,
        name: name,
        age: int.tryParse(childAge.text.trim()) ?? 0,
        status: 'نشط',
        diagnosis: diagnosis,
        programType: diagnosis == 'إعاقة سمعية' ? 'لغة إشارة' : 'نطق وتخاطب',
        parentName: parent,
        parentPhone: phone,
        portalEmail: phone,
        portalPassword: phone,
        createdAt: DateTime.now().toIso8601String(),
      ));
      childName.clear();
      childAge.clear();
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
