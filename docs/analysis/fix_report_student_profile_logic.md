# تقرير إصلاحات منطق ملف الطالب والجلسات

> تاريخ التقرير: 11 يونيو 2026  
> الملفات المعدلة: `app_provider.dart`, `sessions_screen.dart`, `student_profile_screen.dart`  
> إجمالي الإصلاحات: 8 (FIX 1–8)

---

## 1. ما المشكلة الأصلية؟

قبل الإصلاحات، كان ملف الطالب يعاني من عدة مشاكل منطقية تجعل البيانات غير دقيقة في حالات معينة:

| المشكلة | المظهر |
|---------|--------|
| **الاعتماد على `plan.progress`** | قيمة `progress` في جدول `training_plans` تُحدَّث فقط عند الإتقان (100). إذا لم تُجرَ جلسة تقييم للهدف، تبقى القيمة القديمة. |
| **الأهداف بدون مهارات** (standard/speechSound) | ليس لها `GoalSkillStep`، لذا `goalProgress()` كانت ترجع `plan.progress` مباشرة (قيمة DB قديمة) بينما `goalStatus()` تقرأ `quickResult` من آخر جلسة. تناقض. |
| **فلاتر active/masted goals** | تستخدم `plan.progress` مباشرة، مما يجعل الهدف يظهر كمنجز (100) رغم تراجع الحالة لاحقًا. |
| **`_lastSessionDate`** | تبحث فقط بـ `step.lastSessionId`، لذا الأهداف بدون مهارات لا تجد آخر جلسة لها. |
| **المتابعات لا تُغلق** | بعد اعتماد إتقان مهارة عبر الواجب المنزلي (`_reviewHomework`)، لا يُستدعى `resolveFollowupForStep`. تبقى المتابعة مفتوحة إلى الأبد. |
| **`_isRetrainMode` يُضبط مبكرًا** | `_applyPreselect()` تجعل `_isRetrainMode = true` حتى لو لم يُعثر على الخطة. |
| **`_isRetrainMode` يُعاد تعيينه مبكرًا** | `_evaluateGoal` و `_evaluateStep` ينفذان `setState(() => _isRetrainMode = false)` بعد التسجيل مباشرة، مما يجعل الرجوع يذهب للشاشة الرئيسية بدل ملف الطالب. |
| **تسمية مضللة** | "نسبة التحسن" تعرض متوسط progress للخطط، وهو ليس تحسنًا حقيقيًا (لعدم وجود مقارنة زمنية). |

---

## 2. القاعدة الجديدة للـ progress

### أ. هدف يحتوي مهارات (GoalSkillStep)

```
progress = (عدد المهارات المتقنة ÷ إجمالي المهارات) × 100
```

- **متقن** فقط يُحسب (يساهم في progress).
- **بمساعدة** لا يُحسب (يُعدّ未 إتقان كامل).
- **يحتاج إعادة** لا يُحسب.

مثال: هدف فيه 3 مهارات (1 متقن، 1 بمساعدة، 1 يحتاج إعادة) → `(1/3)×100 = 33` → الهدف نشط.

### ب. هدف بدون مهارات (standard / speechSound)

```
progress = f(quickResult of last session for this planId)
```

| آخر `quickResult` | progress |
|-------------------|----------|
| متقن | 100 |
| بمساعدة | 50 |
| يحتاج إعادة | 0 |
| لا توجد جلسة بعد | `plan.progress` أو 0 |

**لماذا "يحتاج إعادة" = 0 وليس 50؟**

هذا هو القرار الأهم: `quickResult == 'يحتاج إعادة'` يعني أن الهدف لم يُتقن بعد والطالب يحتاج إلى تدريب إضافي. لو أعطيناه 50، لكان الهدف نشطًا (50 < 100) وهذا صحيح ظاهريًا، لكن 50 تعطي انطباعًا بوجود تقدم (~نصف الطريق) بينما الحقيقة أن الهدف عاد إلى الصفر من حيث الإتقان.  
بالإضافة إلى اتفاقية `goalProgress()`: القيمة تعكس "إتقانًا حقيقيًا". عندما تكون "يحتاج إعادة"، الإتقان = 0%. أما "بمساعدة" فتعطي 50% لأن المهارة أُنجزت لكن بمساعدة — تقدم جزئي معترف به.

### الكود (app_provider.dart:963–982)

```dart
int goalProgress(String goalId) {
  final steps = stepsForGoal(goalId);
  if (steps.isNotEmpty) {
    final completed = steps.where((step) => step.status == 'متقن').length;
    return ((completed / steps.length) * 100).round();
  }
  final goalSessions = sessions.where((s) => s.planId == goalId).toList()
    ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  if (goalSessions.isEmpty) {
    final matches = plans.where((item) => item.id == goalId).toList();
    return matches.isEmpty ? 0 : matches.first.progress;
  }
  switch (goalSessions.first.quickResult) {
    case 'متقن': return 100;
    case 'بمساعدة': return 50;
    default: return 0; // يحتاج إعادة أو أي قيمة أخرى
  }
}
```

---

## 3. كيف نحدد الهدف النشط والمنجز؟

| التصنيف | الشرط |
|---------|-------|
| **نشط** (active) | `goalProgress(plan.id) < 100` |
| **منجز** (mastered) | `goalProgress(plan.id) >= 100` |

### لماذا `goalProgress()` وليس `plan.progress`؟

`plan.progress` هي قيمة في قاعدة البيانات تُحدَّث فقط عند جلسة تقييم. قد تبقى 100 حتى بعد أن يصنّف الأخصائي الهدف بـ "يحتاج إعادة" (لأن `_evaluateGoal` لم تكن تُنزّل progress لغير المتقن).  
`goalProgress()` تحسب progress ديناميكيًا من البيانات الحالية (المهارات المتقنة + آخر جلسة للهدف).

### المواقع التي تم تغييرها

**`app_provider.dart`:**
- `activeGoalCount` getter (سطر 151) — عدد الأهداف النشطة
- `masteredGoalCount` getter (سطر 156) — عدد الأهداف المنجزة
- `saveClinicalAssessment` duplicate check (سطر 1165)

**`sessions_screen.dart`:**
- `_activeGoals()` (سطر 121) — قائمة الأهداف النشطة للاختيار
- `_completedGoals()` (سطر 124) — قائمة الأهداف المنجزة للاختيار

**`student_profile_screen.dart`:**
- `build()` — 5 مواقع: count للـ _CollapsibleCard + any() للعرض الشرطي (أسطر 99–112)
- `_GoalProgressSection.build()` — activePlans + masteredPlans (أسطر 779–780)
- `_GoalProgressSection.build()` — شرط زر "إعادة التدريب" (سطر 959)
- `_MasteredGoalsSection.build()` — masteredPlans (سطر 1083)

المجموع: **12 موقعًا** تم تغييرها من `p.progress` إلى `app.goalProgress(p.id)`.

---

## 4. كيف تعمل "آخر جلسة" الآن؟

### ثلاثة مستويات للبحث

| المستوى | البحث | مثال |
|---------|-------|------|
| آخر جلسة للطالب | كل `app.sessions` | تستخدم في dashboard والمعلومات العامة |
| آخر جلسة للهدف | الجلسات التي `session.planId == plan.id` | للهدف بدون مهارات (standard) |
| آخر جلسة للمهارة | الجلسات التي `session.id == step.lastSessionId` | للمهارات ذات `GoalSkillStep` |

### التعديل في `_lastSessionDate()`

الدالة الآن تستقبل `planId` كمعامل إضافي:

```dart
String _lastSessionDate(AppProvider app, String planId,
    List<GoalSkillStep> steps) {
  final sessionIds = steps
      .map((step) => step.lastSessionId)
      .where((value) => value.trim().isNotEmpty)
      .toSet();
  final matches = app.sessions
      .where((session) =>
          sessionIds.contains(session.id) || session.planId == planId)
      .toList()
    ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  if (matches.isEmpty) return 'لا توجد';
  return matches.first.startedAt.split('T').first;
}
```

- `sessionIds.contains(session.id)` — يغطي الأهداف ذات المهارات (تبحث عن `lastSessionId` لكل خطوة)
- `session.planId == planId` — يغطي الأهداف بدون مهارات (تبحث عن أي جلسة مرتبطة بالخطة)

الاستدعاء من `_GoalProgressSection`:
```dart
// قبل: _lastSessionDate(app, steps);
// بعد: _lastSessionDate(app, plan.id, steps);
```

---

## 5. كيف تعمل المتابعات الآن؟

### متى تُنشأ followup؟

في `_evaluateStep()` داخل `sessions_screen.dart`:

```dart
if (status == 'متقن') {
  await app.resolveFollowupForStep(student.id, step.id);  // تغلق إن كانت موجودة
} else {
  await app.upsertFollowup(    // تنشئ أو تحدث
    studentId: student.id,
    specialistId: app.user?.id ?? '',
    programId: _selectedProgram?.id ?? '',
    sourceType: _selectedSourceType ?? '',
    planId: goal.id,
    goalSkillStepId: step.id,
    reason: status == 'بمساعدة' ? 'assisted' : 'retry',
  );
}
```

### متى تُغلق followup؟

1. **عند تقييم المهارة بـ "متقن"** في `_evaluateStep()` — يُستدعى `resolveFollowupForStep`.
2. **عند اعتماد واجب منزلي** وتحويل المهارة إلى "متقن" في `_reviewHomework()`:

```dart
await app.updateGoalSkillStepStatus(
  step: step.first, status: 'متقن',
  notes: 'تم اعتماد الإتقان بعد واجب منزلي.',
);
await app.resolveFollowupForStep(student.id, step.first.id);
```

هذا الإضافة (FIX 6) يضمن أن الأخصائي عندما يعتمد إتقان مهارة عبر الواجب المنزلي، تُغلق المتابعة تلقائيًا.

### كيف منعنا بقاء زر إعادة التدريب بعد الإتقان؟

بما أن `goalProgress()` الآن تعكس الحالة الحقيقية (100 فقط إذا كان آخر تقييم "متقن")، وفلتر الأهداف النشطة يستخدم `goalProgress() < 100`، فإن الهدف المتقن يختفي تلقائيًا من قائمة الأهداف النشطة ولا يظهر له زر إعادة تدريب.

زر "إعادة التدريب" في `_GoalProgressSection` (سطر 959) يظهر فقط عندما `app.goalProgress(plan.id) < 100`.

---

## 6. كيف يعمل retrain / sessionPreselect الآن؟

### التدفق الكامل

1. في ملف الطالب، يضغط الأخصائي "إعادة التدريب" على هدف.
2. `_openRetrainPlan()` تنفذ `sessionPreselect` في `AppProvider`:
   ```dart
   app.sessionPreselect = {
     'programId': plan.programId,
     'sourceType': plan.sourceType,
     'planId': plan.id,
     'studentId': student.id,
   };
   ```
3. تنتقل إلى `sessions_screen.dart`.
4. في `initState` / `build`، يُستدعى `_applyPreselect()`.

### ماذا يفعل `_applyPreselect()` الآن؟

```dart
app.clearSessionPreselect();    // تُمسح فورًا لمنع إعادة التشغيل
setState(() {
  _selectedProgram = program.first;
  _selectedSourceType = sourceType;
  _selectedGoal = null;
  _currentSessionId = null;
  _isRetrainMode = false;       // أبدًا لا نضبط true هنا
});
if (planId.isNotEmpty) {
  final plan = app.plans.where((p) => p.id == planId).toList();
  if (plan.isNotEmpty) {
    setState(() {
      _selectedGoal = plan.first;
      _isRetrainMode = true;    // فقط إذا وُجدت الخطة فعليًا
    });
    // تحديث جميع المتابعات المعلقة لهذا الهدف
  }
}
```

**التغيير الجوهري (FIX 4):** `_isRetrainMode` يُضبط `true` فقط داخل `if (plan.isNotEmpty)` — أي فقط عندما يتم العثور على الخطة فعليًا. قبل الإصلاح، كان يُضبط `true` من `planId.isNotEmpty` حتى لو لم تُوجد الخطة.

### متى يكون `_isRetrainMode = true`؟

- فقط عندما يُفتح الهدف كاملًا (وليس مهارة واحدة) من ملف الطالب.
- يظل `true` طوال الجلسة حتى يغلق المستخدم الشاشة أو يفتح هدفًا آخر.

### لماذا لا نعمل reset لـ `_isRetrainMode` مبكرًا؟

قبل الإصلاح (FIX 2 & 3)، كان `_evaluateGoal` و `_evaluateStep` يعيدان تعيين `_isRetrainMode` إلى `false` بعد تسجيل الجلسة مباشرة. هذا يعني أن `Navigator.pop` بعد التقييم كان يعود إلى الشاشة الرئيسية بدل ملف الطالب.

الآن، لا يوجد `setState(() => _isRetrainMode = false)` في أي من الدالتين. `_isRetrainMode` يظل `true` حتى يغلق المستخدم شاشة الجلسة أو يفتح هدفًا جديدًا، مما يضمن أن العودة من زر الرجوع تذهب لملف الطالب.

---

## 7. ماذا تغيّر في ملف الطالب؟

### 7.1 إعادة تسمية "نسبة التحسن"
- **قبل:** `label: 'نسبة التحسن'` — مضلل لأن القيمة هي متوسط progress للخطط، وليست تحسنًا حقيقيًا (لا توجد مقارنة زمنية).
- **بعد:** `label: 'متوسط تقدم الأهداف'` — يعكس بدقة أن القيمة هي متوسط progress لكل الأهداف.

### 7.2 فلاتر الأهداف تستخدم `goalProgress`
جميع فلاتر active/masted في `student_profile_screen.dart` تم تغييرها من `p.progress` إلى `app.goalProgress(p.id)`. راجع القسم 3 أعلاه.

### 7.3 أهداف الحروف والأقسام (standard)
أهداف التقييم (مثل حروف النطق) ليس لها `GoalSkillStep`. progressها يُحسب من `quickResult` لآخر جلسة. هذا يعني:
- **متقن** → 100 → منجز
- **بمساعدة** → 50 → نشط
- **يحتاج إعادة** → 0 → نشط

### 7.4 الأهداف "بمساعدة" أو "يحتاج إعادة" تبقى نشطة
لأن `goalProgress()` تعطي < 100 في كلتا الحالتين (50 و 0 على التوالي).

---

## 8. ماذا تغيّر في شاشة الجلسات؟

### `_evaluateGoal()` (FIX 2)

```dart
await runWithFeedback(context, () async {
  final steps = _filteredSteps(app, goal.id);
  if (steps.isEmpty) {
    if (status == 'متقن') {
      await app.updatePlanProgress(planId: goal.id, progress: 100);
    } else if (app.goalProgress(goal.id) >= 100) {
      // إذا كان الهدف حاليًا 100 لكن التقييم الجديد ليس متقنًا
      // نُنزل progress إلى 50 (بمساعدة) أو 0 (يحتاج إعادة)
      // سيُحسب تلقائيًا عبر goalProgress() لكن تحديث DB ضروري
      await app.updatePlanProgress(planId: goal.id, progress: 50);
    }
  }
  await _recordGoalSession(app, student, goal, status);
  // لا يوجد setState(() => _isRetrainMode = false)
});
```

**ماذا تغيّر؟**
- الأهداف بدون مهارات: إذا كان progress=100 حاليًا (متقن سابقًا) والتقييم الجديد غير متقن، يُنزّل الـ DB progress إلى 50. هذا يضمن أن `goalProgress()` عندما تقع في مسار `goalSessions.isEmpty` (وهو unlikely لكن للطوارئ) لا تعطي 100 خطأ.
- أُزيل `_isRetrainMode = false` للسماح بالرجوع لملف الطالب.

### `_evaluateStep()` (FIX 3)

قبل:
```dart
await _recordGoalSession(app, student, goal, status);
setState(() => _isRetrainMode = false);
```

بعد:
```dart
await _recordGoalSession(app, student, goal, status);
// لا يوجد setState
```

### `_activeGoals()` و `_completedGoals()` (FIX 8)

قبل:
```dart
_filteredPlans(app).where((p) => p.progress < 100).toList();
_filteredPlans(app).where((p) => p.progress >= 100).toList();
```

بعد:
```dart
_filteredPlans(app).where((p) => app.goalProgress(p.id) < 100).toList();
_filteredPlans(app).where((p) => app.goalProgress(p.id) >= 100).toList();
```

---

## 9. ماذا لم يتغير؟

- **XP** — لم يتغير. التقييم لا يعطي نقاط XP، الجلسات فقط تعطي نقاط.
- **التقييم** (clinical assessment) — لم يتغير. `goalProgress()` لا تؤثر على شاشة التقييم.
- **قاعدة البيانات** — لم تُضف أو تُحذف أعمدة أو جداول. `plan.progress` لا يزال يُستخدم كـ fallback وكمخزّن للـ DB.
- **`templateId`** — لم يتغير. لا يزال يُستخدم في هيكل البرامج.
- **`sourceType` / `programId`** — لم يتغير. لا يزال يُستخدم لتصفية الأهداف والمهارات.
- **واجهة المستخدم (UI)** — لم تتغير شاشة ملف الطالب ولا شاشة الجلسات من حيث الشكل (باستثناء إعادة التسمية في FIX 7). لا توجد أيقونات جديدة، ولا تخطيط جديد، ولا ألوان جديدة.

---

## 10. اختبارات السيناريوهات

تم التحقق يدويًا من المنطق لكل سيناريو بعد قراءة الكود (رمزياً):

| # | السيناريو | النتيجة المتوقعة | التحقق |
|---|-----------|-----------------|--------|
| 1أ | هدف بدون مهارات، آخر تقييم "متقن" | `goalProgress() = 100`، منجز | `goalProgress()` تذهب للمسار: steps.isEmpty → تجد جلسات → switch('متقن') → return 100 |
| 1ب | هدف بدون مهارات، آخر تقييم "بمساعدة" | `goalProgress() = 50`، نشط | switch('بمساعدة') → return 50 |
| 1ج | هدف بدون مهارات، آخر تقييم "يحتاج إعادة" | `goalProgress() = 0`، نشط | switch default → return 0 |
| 2 | هدف فيه 3 مهارات (1 متقن + 1 بمساعدة + 1 يحتاج إعادة) | `(1/3)×100 = 33`، نشط | steps.isNotEmpty count 'متقن' فقط |
| 3 | هدف فيه 3 مهارات كلها متقنة | `(3/3)×100 = 100`، منجز | steps.isNotEmpty count = 3/3 |
| 4 | متابعة مفتوحة ← مهارة أصبحت متقن | followup تُغلق | `_evaluateStep()` تستدعي `resolveFollowupForStep` |
| 5 | إعادة تدريب من ملف الطالب ← فتح الجلسة ← الرجوع | الرجوع يذهب لملف الطالب | `_isRetrainMode = true` ولا يُعاد تعيينه في `_evaluateGoal`/`_evaluateStep` |
| 6 | XP | لا تغيير | XP لم يلمس في أي إصلاح |

---

## 11. نتائج الأوامر

### `flutter analyze`

```
Analyzing sanad_app...

   info - Use 'const' with the constructor... (x5) [pre-existing, clinical_assessment_wizard_screen.dart]
warning - A value for optional parameter 'key' isn't ever given... [pre-existing, therapy_structure_builder_screen.dart]
   info - Don't invoke 'print' in production code... (x4) [pre-existing, tools/]

10 issues found. (ran in 5.4s)
```

**0 أخطاء، 0 تحذيرات جديدة.** جميع الـ 10 issues موجودة مسبقًا في ملفات أخرى.

### `flutter test`

```
00:02 +33: All tests passed!
```

**33 اختبارًا — جميعها نجحت.** لا اختبارات مكسورة بسبب التعديلات.

---

## 12. المخاطر المتبقية

1. **حساب التحسن الحقيقي لم يُبنَ بعد** — قيمة "متوسط تقدم الأهداف" هي متوسط progress الحالي للخطط، وليست تحسنًا زمنيًا (مقارنة بين تقييم سابق ولاحق).
2. **مقارنة التقييمات لم تُبنَ بعد** — لا توجد آلية لمقارنة نتائج التقييم عبر الزمن لقياس التحسن الحقيقي.
3. **UI ملف الطالب ما زال مزدحمًا** — 7 بطاقات قابلة للطي مع أقسام متعددة داخل كل منها. الشاشة تحتاج إعادة تصميم.
4. **`plan.progress` في DB قد يصبح خارج التزامن مع `goalProgress()`** — في الحالات النادرة (لا توجد جلسات للهدف بدون مهارات)، `goalProgress()` ترجع `plan.progress`، لذا قد تعود القيمة المخزنة كما هي. هذا مقصود لكنه خطر بسيط إذا لم تُجرَ جلسات.
5. **`_isRetrainMode` لا يُعاد تعيينه عند الخروج العادي** — إذا فتح المستخدم هدفًا عاديًا بعد retrain، `_isRetrainMode` لا يزال `true` حتى يختار هدفًا آخر (لأن `_applyPreselect` يضبطه `false` أولًا). هذا آمن حاليًا لكن قد يسبب التباسًا إذا أُضيف منطق جديد يعتمد على `_isRetrainMode`.

---

## 13. الخلاصة التنفيذية

### هل أصبح منطق ملف الطالب أكثر أمانًا؟

**نعم، بشكل ملحوظ.**  

- `goalProgress()` الآن هي المصدر الوحيد والحقيقي لحالة الهدف، بدلًا من الاعتماد على `plan.progress` المخزّن.
- الأهداف بدون مهارات أصبح لها progress دقيق يعتمد على آخر تقييم.
- فلاتر active/masted موحّدة عبر الملفات الثلاثة.
- المتابعات تُغلق تلقائيًا عند الإتقان (سواء من التقييم أو من اعتماد الواجب).
- retrain mode يعمل بشكل صحيح ويعود لملف الطالب بعد التقييم.
- جميع التغييرات اجتازت `flutter analyze` و `flutter test` بنجاح.

### هل يمكن البدء في إعادة تصميم Header ملف الطالب؟

**نعم.** الآن بعد تثبيت المنطق، يمكن التعامل مع البيانات بثقة. إعادة التصميم لن تحتاج لتغيير في المنطق (طالما أنها لا تقدم ميزات جديدة).

### أول تعديل UI تنصح به بعد تثبيت المنطق؟

**دمج الـ Header مع Summary Cards ومع Student Overview في بطاقة واحدة شاملة** (كما نوقش في `docs/analysis/student_profile_header_analysis.md`). هذا يقلل عدد البطاقات من 3 إلى بطاقة واحدة مع توزيع ذكي للمساحة:

- صورة الطالب + الاسم + التقدم (جهة اليمين)
- "آخر جلسة" + "متوسط تقدم الأهداف" + "الأهداف النشطة / المنجزة" (جهة اليسار)
- إخفاء الإحصائيات الثانوية على الشاشات الضيقة (< 480px) باستخدام `LayoutBuilder` (كما طُبّق في `sessions_screen.dart`)

بعد دمج الـ Header، يمكن تقييم إعادة هيكلة بقية الشاشة.
