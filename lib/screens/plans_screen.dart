import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../widgets/app_widgets.dart';
import '../widgets/feedback.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  final goal = TextEditingController();
  int progress = 0;

  @override
  void dispose() {
    goal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: app.selectedStudent == null
              ? const Text('اختر طالبًا أولًا.')
              : Column(
                  children: [
                    TextField(
                        controller: goal,
                        decoration:
                            const InputDecoration(labelText: 'هدف الخطة')),
                    Slider(
                        value: progress.toDouble(),
                        min: 0,
                        max: 100,
                        divisions: 10,
                        label: '$progress%',
                        onChanged: (value) =>
                            setState(() => progress = value.round())),
                    Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                            onPressed: () => _save(app),
                            icon: const Icon(Icons.add_task),
                            label: const Text('حفظ الهدف'))),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        ResponsiveGrid(
          children: app.plans
              .map((plan) => AppCard(
                  child: ListTile(
                      title: Text(plan.goal),
                      subtitle: Text('تاريخ الهدف: ${plan.targetDate}'),
                      trailing: Text('${plan.progress}%'))))
              .toList(),
        ),
      ],
    );
  }

  Future<void> _save(AppProvider app) async {
    final student = app.selectedStudent;
    if (student == null || goal.text.trim().isEmpty) return;
    await runWithFeedback(context, () async {
      await app.savePlan(
        TrainingPlan(
          id: 'plan_${DateTime.now().millisecondsSinceEpoch}',
          centerId: student.centerId,
          studentId: student.id,
          goal: goal.text.trim(),
          targetDate: DateTime.now()
              .add(const Duration(days: 30))
              .toIso8601String()
              .split('T')
              .first,
          progress: progress,
        ),
      );
      goal.clear();
      setState(() => progress = 0);
    });
  }
}
