import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../widgets/app_widgets.dart';
import '../widgets/feedback.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  Timer? timer;
  int seconds = 0;
  int attempts = 0;
  int correct = 0;
  int partial = 0;
  int wrong = 0;
  int successRate = 0;
  String sessionType = 'نطق وتخاطب';
  String targetLetter = '';
  String letterPosition = 'أول الكلمة';
  String errorType = 'حذف';
  String cardTitle = 'بطاقة نطق الحرف';
  String result = 'صحيح';
  String planId = '';
  final notes = TextEditingController();
  final summary = TextEditingController();
  final practiceItems = TextEditingController();

  @override
  void dispose() {
    timer?.cancel();
    notes.dispose();
    summary.dispose();
    practiceItems.dispose();
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('جلسة ${student.name}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    AppCard(
                      padding: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('قبل البدء', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text('آخر تقييم: ${app.evaluations.isEmpty ? 'لا يوجد' : '${app.evaluations.first.letter} - ${app.evaluations.first.score} - ${app.evaluations.first.errorType}'}'),
                          Text('آخر جلسة: ${app.sessions.isEmpty ? 'لا يوجد' : '${app.sessions.first.sessionType} - ${app.sessions.first.quickResult} - ${app.sessions.first.successRate}%'}'),
                          Text('اقتراح Sanad: ${app.smartSessionSuggestion}'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('المؤقت: ${Duration(seconds: seconds).toString().split('.').first}', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(width: 260, child: TextField(decoration: const InputDecoration(labelText: 'بطاقة التدريب'), onChanged: (value) => cardTitle = value)),
                        SizedBox(
                          width: 220,
                          child: DropdownButtonFormField<String>(
                            initialValue: sessionType,
                            decoration: const InputDecoration(labelText: 'نوع الجلسة'),
                            items: const ['نطق وتخاطب', 'لغة إشارة', 'مهارات تعليمية', 'مهارات سلوكية', 'أخرى'].map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                            onChanged: (value) => setState(() => sessionType = value ?? sessionType),
                          ),
                        ),
                        SizedBox(
                          width: 260,
                          child: DropdownButtonFormField<String>(
                            initialValue: planId.isEmpty ? null : planId,
                            decoration: const InputDecoration(labelText: 'هدف من الخطة'),
                            items: app.plans.map((plan) => DropdownMenuItem(value: plan.id, child: Text(plan.goal, overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (value) => setState(() => planId = value ?? ''),
                          ),
                        ),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'صحيح', label: Text('صحيح')),
                            ButtonSegment(value: 'جزئي', label: Text('جزئي')),
                            ButtonSegment(value: 'خطأ', label: Text('خطأ')),
                          ],
                          selected: {result},
                          onSelectionChanged: (value) => setState(() => result = value.first),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: app.speechTrainingBank
                          .where((item) => targetLetter.isEmpty || item.letter == targetLetter)
                          .map(
                            (item) => InputChip(
                              label: Text('${item.title} (${item.level})'),
                              onPressed: () {
                                final current = practiceItems.text.trim();
                                practiceItems.text = current.isEmpty ? item.title : '$current، ${item.title}';
                                cardTitle = item.title;
                                if (item.letter.isNotEmpty) targetLetter = item.letter;
                                if (item.position.isNotEmpty) letterPosition = item.position;
                                setState(() {});
                              },
                            ),
                          )
                          .toList(),
                    ),
                    if (sessionType == 'نطق وتخاطب') ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(width: 120, child: TextField(decoration: const InputDecoration(labelText: 'الحرف'), onChanged: (value) => targetLetter = value)),
                          SizedBox(width: 180, child: DropdownButtonFormField<String>(initialValue: letterPosition, decoration: const InputDecoration(labelText: 'موضع الحرف'), items: const ['أول الكلمة', 'وسط الكلمة', 'آخر الكلمة'].map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(), onChanged: (value) => setState(() => letterPosition = value ?? letterPosition))),
                          SizedBox(width: 180, child: DropdownButtonFormField<String>(initialValue: errorType, decoration: const InputDecoration(labelText: 'نوع الخطأ'), items: const ['حذف', 'إبدال', 'تشويه', 'إضافة'].map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(), onChanged: (value) => setState(() => errorType = value ?? errorType))),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(controller: practiceItems, maxLines: 2, decoration: const InputDecoration(labelText: 'الكلمات / الجمل / الإشارات المستهدفة')),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      children: [
                        SizedBox(width: 180, child: TextField(keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'عدد التمارين'), onChanged: (value) => attempts = int.tryParse(value) ?? 0)),
                        SizedBox(width: 180, child: TextField(keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'نسبة النجاح %'), onChanged: (value) => successRate = int.tryParse(value) ?? 0)),
                        FilledButton.tonal(onPressed: () => _recordAttempt('صحيح'), child: Text('صحيح: $correct')),
                        FilledButton.tonal(onPressed: () => _recordAttempt('جزئي'), child: Text('جزئي: $partial')),
                        FilledButton.tonal(onPressed: () => _recordAttempt('خطأ'), child: Text('خطأ: $wrong')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('الملخص التلقائي: $attempts تمرين، نسبة النجاح ${_computedSuccessRate()}%'),
                    const SizedBox(height: 12),
                    TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'ملاحظات الجلسة', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(controller: summary, maxLines: 2, decoration: const InputDecoration(labelText: 'ملخص نهاية الجلسة', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton.icon(onPressed: _start, icon: const Icon(Icons.play_arrow), label: const Text('بدء جلسة')),
                        FilledButton.tonalIcon(onPressed: _pause, icon: const Icon(Icons.pause), label: const Text('إيقاف')),
                        FilledButton.icon(onPressed: () => _save(app), icon: const Icon(Icons.save_outlined), label: const Text('حفظ تلقائي')),
                      ],
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        if (app.sessions.isEmpty)
          const EmptyState(icon: Icons.event_note_outlined, title: 'لا توجد جلسات', message: 'بعد حفظ أول جلسة ستظهر هنا مع ملخصها ونسبة النجاح.')
        else
          ResponsiveGrid(
            children: app.sessions.map((session) {
              return AppCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.record_voice_over_outlined),
                  title: Text('${session.cardTitle} - ${session.quickResult}'),
                  subtitle: Text('${session.startedAt}\n${session.notes}'),
                  trailing: Text('${session.successRate}%'),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  void _recordAttempt(String value) {
    setState(() {
      attempts++;
      result = value;
      if (value == 'صحيح') correct++;
      if (value == 'جزئي') partial++;
      if (value == 'خطأ') wrong++;
      successRate = _computedSuccessRate();
    });
  }

  int _computedSuccessRate() {
    if (attempts == 0) return successRate.clamp(0, 100).toInt();
    return (((correct + partial * .5) / attempts) * 100).round().clamp(0, 100).toInt();
  }

  void _start() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => seconds++));
  }

  void _pause() {
    timer?.cancel();
  }

  Future<void> _save(AppProvider app) async {
    final student = app.selectedStudent;
    if (student == null) return;
    timer?.cancel();
    await runWithFeedback(context, () async {
      if (seconds == 0 || cardTitle.trim().isEmpty) throw StateError('ابدأ المؤقت واكتب بطاقة التدريب قبل الحفظ.');
      await app.saveSession(
        TherapySession(
        id: 'session_${DateTime.now().millisecondsSinceEpoch}',
        centerId: student.centerId,
        studentId: student.id,
        planId: planId,
        sessionType: sessionType,
        targetLetter: targetLetter,
        letterPosition: letterPosition,
        errorType: sessionType == 'نطق وتخاطب' ? errorType : '',
        practiceItems: practiceItems.text.trim(),
        attempts: attempts,
        successRate: _computedSuccessRate(),
        startedAt: DateTime.now().toIso8601String(),
          durationSeconds: seconds,
          cardTitle: cardTitle,
          quickResult: result,
          notes: notes.text.trim(),
          summary: summary.text.trim(),
        ),
      );
      setState(() {
        seconds = 0;
        notes.clear();
        summary.clear();
        practiceItems.clear();
        attempts = 0;
        successRate = 0;
        correct = 0;
        partial = 0;
        wrong = 0;
      });
    });
  }
}
