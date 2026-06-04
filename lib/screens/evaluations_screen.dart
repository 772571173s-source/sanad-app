import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../widgets/app_widgets.dart';
import '../widgets/feedback.dart';

class EvaluationsScreen extends StatefulWidget {
  const EvaluationsScreen({super.key});

  @override
  State<EvaluationsScreen> createState() => _EvaluationsScreenState();
}

class _EvaluationsScreenState extends State<EvaluationsScreen> {
  final letter = TextEditingController();
  final notes = TextEditingController();
  String position = 'أول الكلمة';
  String errorType = 'حذف';
  String score = 'صحيح';
  int severity = 1;

  @override
  void dispose() {
    letter.dispose();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final student = app.selectedStudent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: student == null
              ? const Text('اختر طالبًا أولًا.')
              : Column(
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                            width: 130,
                            child: TextField(
                                controller: letter,
                                decoration:
                                    const InputDecoration(labelText: 'الحرف'))),
                        _select(
                            'الموضع',
                            position,
                            const ['أول الكلمة', 'وسط الكلمة', 'آخر الكلمة'],
                            (value) => setState(() => position = value)),
                        _select(
                            'نوع الخطأ',
                            errorType,
                            const ['حذف', 'إبدال', 'تشويه', 'إضافة'],
                            (value) => setState(() => errorType = value)),
                        _select('التقييم', score, const ['صحيح', 'جزئي', 'خطأ'],
                            (value) => setState(() => score = value)),
                        SizedBox(
                            width: 180,
                            child: DropdownButtonFormField<int>(
                                initialValue: severity,
                                decoration: const InputDecoration(
                                    labelText: 'درجة الشدة'),
                                items: List.generate(
                                    5,
                                    (index) => DropdownMenuItem(
                                        value: index + 1,
                                        child: Text('${index + 1}'))),
                                onChanged: (value) =>
                                    setState(() => severity = value ?? 1))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                        controller: notes,
                        maxLines: 2,
                        decoration: const InputDecoration(
                            labelText: 'ملاحظات',
                            border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                            onPressed: () => _save(app),
                            icon: const Icon(Icons.save),
                            label: const Text('حفظ التقييم'))),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        ResponsiveGrid(
          children: app.evaluations.map((evaluation) {
            return AppCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.hearing_outlined),
                title: Text('${evaluation.letter} - ${evaluation.position}'),
                subtitle: Text(
                    '${evaluation.errorType} - ${evaluation.score} - شدة ${evaluation.severity}\n${evaluation.recommendation}\n${evaluation.notes}'),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _select(String label, String value, List<String> values,
      ValueChanged<String> onChanged) {
    return SizedBox(
      width: 180,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: values
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: (value) => onChanged(value ?? values.first),
      ),
    );
  }

  Future<void> _save(AppProvider app) async {
    final student = app.selectedStudent;
    if (student == null || letter.text.trim().isEmpty) return;
    await runWithFeedback(context, () async {
      if (letter.text.trim().isEmpty) throw StateError('الحرف مطلوب.');
      await app.saveEvaluation(
        Evaluation(
          id: 'evaluation_${DateTime.now().millisecondsSinceEpoch}',
          centerId: student.centerId,
          studentId: student.id,
          letter: letter.text.trim(),
          position: position,
          errorType: errorType,
          score: score,
          severity: severity,
          recommendation:
              app.recommendationFor(errorType: errorType, severity: severity),
          createdAt: DateTime.now().toIso8601String(),
          notes: notes.text.trim(),
        ),
      );
      letter.clear();
      notes.clear();
    });
  }
}
