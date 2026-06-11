# تقرير: تصحيح نتيجة جلسة — تحليل هندسي

> تاريخ التقرير: 11 يونيو 2026  
> الملفات التي تم تحليلها:  
> `student_profile_screen.dart`, `sessions_screen.dart`, `app_provider.dart`,  
> `sanad_repository.dart`, `app_models.dart`  
> **لم يتم تغيير أي كود.**

---

## 1. فهم البنية الحالية — تتبع خطوة بخطوة

### الحالة A: ضغط "متقن" (هدف بدون مهارات)

```
ضغط "متقن" ← _evaluateGoal('متقن')
  │
  ├── 1. steps.isEmpty == true
  │     └── updatePlanProgress(planId: goal.id, progress: 100)
  │           ├── TrainingPlan.progress = 100 (DB + in-memory)
  │           └── notifyListeners()
  │
  ├── 2. _recordGoalSession(app, student, goal, 'متقن')
  │     ├── summary = 'تقييم هدف: {goal.goal} - النتيجة: متقن'
  │     ├── session = TherapySession(
  │     │     quickResult: 'متقن',
  │     │     planId: goal.id,
  │     │     skillId: '',          ← فارغ
  │     │     notes: summary,       ← يُستخدم كملخص
  │     │     summary: '',          ← غير مستخدم
  │     │     cardTitle: goal.goal,
  │     │   )
  │     └── app.saveSession(session, autosave: false)
  │           ├── DB: upsert('sessions', session.toMap())
  │           ├── Audit log: 'إنشاء جلسة'
  │           ├── XP: _grantXp(studentId, 2)     ← متقن = 2 XP
  │           └── in-memory: sessions.add(session)
  │
  └── 3. UI rebuild
        ├── goalProgress(goal.id) → 100 (منذ quickResult == 'متقن')
        ├── goalStatus(goal.id) → 'متقن'
        └── الهدف ينتقل تلقائيًا إلى _MasteredGoalsSection
```

### الحالة B: ضغط "بمساعدة" (هدف بدون مهارات)

```
ضغط "بمساعدة" ← _evaluateGoal('بمساعدة')
  │
  ├── 1. steps.isEmpty == true
  │     └── status != 'متقن' && goalProgress >= 100?
  │           └── if yes → updatePlanProgress(50)
  │           └── if no → skip (progress stays as is)
  │
  ├── 2. _recordGoalSession(app, student, goal, 'بمساعدة')
  │     └── session.quickResult = 'بمساعدة'
  │     └── XP: _grantXp(studentId, 1)     ← بمساعدة = 1 XP
  │
  └── 3. UI rebuild
        ├── goalProgress(goal.id) → 50
        ├── goalStatus(goal.id) → 'يحتاج مساعدة'
        └── يبقى في الأهداف النشطة
```

### الحالة C: ضغط "يحتاج إعادة" (هدف بدون مهارات)

```
ضغط "يحتاج إعادة" ← _evaluateGoal('يحتاج إعادة')
  │
  ├── 1. steps.isEmpty == true
  │     └── status != 'متقن' → skip updatePlanProgress
  │
  ├── 2. _recordGoalSession(...)
  │     └── session.quickResult = 'يحتاج إعادة'
  │     └── XP: _grantXp(studentId, 0)     ← يحتاج إعادة = 0 XP
  │
  └── 3. UI rebuild
        ├── goalProgress(goal.id) → 0
        ├── goalStatus(goal.id) → 'يحتاج إعادة'
        └── يبقى في الأهداف النشطة
```

### الحالة D: ضغط "متقن" (هدف بمهارات)

```
ضغط "متقن" على مهارة ← _evaluateStep(step, 'متقن')
  │
  ├── 1. updateGoalSkillStepStatus(step, 'متقن', notes)
  │     ├── GoalSkillStep.status = 'متقن' (DB + in-memory)
  │     ├── syncGoalProgress(step.goalId)
  │     │     └── progress = (completed/total) * 100
  │     │     └── TrainingPlan.progress = progress (DB)
  │     └── notifyListeners()
  │
  ├── 2. resolveFollowupForStep(student.id, step.id)
  │     ├── student_followups.status = 'completed'
  │     ├── student_followups.resolved_at = now
  │     └── studentFollowups reloaded from DB
  │
  ├── 3. _recordGoalSession(app, student, goal, 'متقن')
  │     └── XP: _grantXp(studentId, 2)
  │
  └── 4. UI rebuild
        ├── goalProgress → يعاد حسابه
        ├── إذا كل المهارات متقنة → 100% → ينتقل للمنجز
        └── المهارة تظهر بأيقونة ✔ خضراء
```

### الحالة E: ضغط "بمساعدة" على مهارة

```
_evaluateStep(step, 'بمساعدة')
  │
  ├── 1. updateGoalSkillStepStatus(step, 'بمساعدة', ...)
  │     └── syncGoalProgress()
  │
  ├── 2. upsertFollowup(reason: 'assisted')
  │     ├── إذا موجودة followup pending → تحديث lastOpenedAt
  │     └── إذا غير موجودة → إنشاء جديدة
  │
  ├── 3. _recordGoalSession(...)
  │     └── XP: _grantXp(studentId, 1)
  │
  └── 4. UI rebuild
        ├── goalProgress ← نقص (لأن متقن ← بمساعدة يقلل completed)
        └── followup جديد يظهر في قسم "يحتاج إعادة تدريب"
```

---

## 2. هل يمكن تصحيح النتيجة؟

**نعم، تقنيًا ممكن.** لكن التعديل لا يقتصر على `TherapySession.quickResult` فقط.

### هل يمكن تعديل quickResult فقط؟
**لا.** تعديل `quickResult` وحده يترك النظام في حالة غير متناسقة:

```
تعديل quickResult فقط ←
  ├── DB: quickResult يتغير ✅
  ├── goalProgress: ديناميكي سيتغير تلقائيًا ✅
  ├── goalSkillStep.status: لا يتغير ❌ (لازم تحديث يدوي)
  ├── followup: لا يتغير ❌ (لازم فتح/إغلاق يدوي)
  ├── XP: لا يتغير ❌ (مافيش عكس XP)
  └── plan.progress (في training_plans): لا يتغير ❌
```

### ما الذي يجب تحديثه معًا (Atomic):

| المكون | يتغير تلقائيًا؟ | يحتاج تحديث يدوي؟ |
|--------|----------------|-------------------|
| `session.quickResult` في DB | ❌ | ✅ upsert الجلسة |
| `goalProgress()` getter | ✅ (ديناميكي) | لا |
| `goalStatus()` getter | ✅ (ديناميكي) | لا |
| `GoalSkillStep.status` | ❌ | ✅ `updateGoalSkillStepStatus` |
| `TrainingPlan.progress` | ✅ عبر `syncGoalProgress` | ✅ استدعاؤه |
| `StudentFollowup` | ❌ | ✅ `upsertFollowup`/`resolveFollowupForStep` |
| XP | ❌ | ✅ حسب القرار |
| Audit log | ❌ | ✅ تسجيل جديد |

---

## 3. ما الذي يجب تحديثه — بالتفصيل

### التصحيح من "متقن" ← "بمساعدة"

#### أ. ماذا يحدث للهدف؟
```
قبل التصحيح:
  goalProgress = 100
  goalStatus = 'متقن'
  الهدف في _MasteredGoalsSection
بعد التصحيح:
  goalProgress = 50 (منذ quickResult == 'بمساعدة')
  goalStatus = 'يحتاج مساعدة'
  الهدف ينتقل تلقائيًا إلى _GoalProgressSection (نشط)
```

#### ب. ماذا يحدث للمهارة؟
```
إذا كان الهدف بمهارات:
  GoalSkillStep.status: 'متقن' → 'بمساعدة'
  ← يحتاج استدعاء updateGoalSkillStepStatus()
  ← syncGoalProgress() سيعيد حساب progress
  ← احتمال نقص progress (completed - 1)

إذا كان الهدف بدون مهارات:
  لا يوجد GoalSkillStep لتحديثه
  ← فقط quickResult يؤثر على goalProgress
```

#### ج. ماذا يحدث للـ progress؟
```
للأهداف بدون مهارات: goalProgress() = 100 → 50 (تلقائي)
للأهداف بمهارات: يعاد حسابه عبر syncGoalProgress()
  مثلاً 3 مهارات كلها متقنة: 100% → 2/3 = 66%
```

#### د. ماذا يحدث للمتابعة (Followup)؟
```
يجب إنشاء followup جديد (reason: 'assisted')
  ← upsertFollowup() تنشئ أو تحديث الموجودة
```

#### هـ. ماذا يحدث للأهداف المنجزة؟
```
قبل: الهدف في _MasteredGoalsSection (لأن goalProgress >= 100)
بعد: الهدف ينتقل تلقائيًا لـ _GoalProgressSection
  (الفلاتر: goalProgress < 100 → نشط)
```

#### و. ماذا يحدث للأهداف النشطة؟
```
عكس ما سبق — الهدف يظهر تلقائيًا في النشطة
```

### التصحيح من "متقن" ← "يحتاج إعادة"

نفس المنطق لكن:
```
goalProgress = 0
goalStatus = 'يحتاج إعادة'
followup.reason = 'retry'
XP فرق: 2 → 0 (خسارة 2 XP)
```

### التصحيح من "بمساعدة" ← "متقن"
```
goalProgress: 50 → 100 (أو يزيد)
goalStatus: 'يحتاج مساعدة' → 'متقن'
followup: يجب إغلاق followup المرتبط
  ← resolveFollowupForStep()
XP فرق: 1 → 2 (زيادة 1 XP)
```

---

## 4. الهدف الذي عاد من المنجز

### مثال: 3 مهارات، كلها متقنة

```
قبل التصحيح: 3/3 متقنة → goalProgress = 100 → هدف منجز

يصحح الأخصائي مهارة واحدة: 'متقن' → 'بمساعدة'
  │
  ├── updateGoalSkillStepStatus(step, 'بمساعدة')
  │     └── GoalSkillStep.status = 'بمساعدة'
  │     └── syncGoalProgress()
  │           └── completed = 2, total = 3
  │           └── progress = (2/3) * 100 = 66
  │           └── TrainingPlan.progress = 66 (DB)
  │
  ├── upsertFollowup(reason: 'assisted')
  │     └── followup جديد للمهارة المصححة
  │
  └── UI rebuild:
        ├── goalProgress(goal.id) → 66
        ├── goalStatus(goal.id) → 'يحتاج إعادة' (لأن progress < 100)
        └── الفلتر goalProgress < 100 يلتقطه → **يعود نشطًا تلقائيًا**
```

**هل يحتاج أي منطق إضافي؟ لا.** الفلاتر ديناميكية:
```dart
// النشطة:
activePlans = plans.where((p) => app.goalProgress(p.id) < 100)
// المنجزة:
masteredPlans = plans.where((p) => app.goalProgress(p.id) >= 100)
```

بمجرد أن `goalProgress` يصبح < 100، الهدف يظهر في النشطة ويختفي من المنجزة. **Zero extra code.**

### ماذا لو الهدف بدون مهارات وعاد من المنجز؟
```
قبل: quickResult = 'متقن' → goalProgress = 100 → منجز
يصحح: quickResult ← 'بمساعدة'
  │
  ├── updateSessionResult(sessionId, 'بمساعدة') ← دالة جديدة
  │     └── TherapySession.quickResult = 'بمساعدة'
  │
  └── goalProgress() → 50 (تلقائي)
        └── الهدف يعود نشطًا تلقائيًا
```

**أيضًا تلقائي — بدون منطق إضافي.**

---

## 5. المتابعات Followups

### هل يجب إنشاء Followup إذا كانت النتيجة الجديدة "بمساعدة" أو "يحتاج إعادة"؟

**نعم** — نفس المنطق الموجود في `_evaluateStep`:
```dart
// موجود حاليًا في sessions_screen.dart:
if (status == 'متقن') {
  await app.resolveFollowupForStep(student.id, step.id);
} else {
  await app.upsertFollowup(..., reason: 'assisted'/'retry');
}
```

دوال التصحيح المقترحة ستستخدم نفس `upsertFollowup` / `resolveFollowupForStep`.

### هل يمكن إعادة فتح Followup مغلقة؟

نعم. `upsertFollowup()` تتحقق أولًا من وجود followup pending:
- إذا موجود → تحديث `lastOpenedAt` (يبقى pending)
- إذا غير موجود → إنشاء جديد

لكن followup المغلقة (`status = 'completed'`) لا تُعاد فتحها بهذه الآلية — لأن `upsertFollowup` يبحث فقط عن `status = 'pending'`. إذا كانت مغلقة سابقًا، سيتم إنشاء **جديدة** (id مختلف). هذا مقبول لأن followup المُغلقة هي سابقة منفصلة.

### هل توجد دوال حالية تدعم ذلك؟

| الدالة | موجودة؟ | تكفي؟ |
|--------|---------|-------|
| `upsertFollowup` | ✅ | ✅ — تنشئ أو تحدث المتابعة |
| `resolveFollowupForStep` | ✅ | ✅ — تغلق المتابعة |
| `updateGoalSkillStepStatus` | ✅ | ✅ — تغير حالة المهارة |
| `syncGoalProgress` | ✅ | ✅ — تعيد حساب progress |
| `updatePlanProgress` | ✅ | ❌ — لا تكفي وحدها، تحتاج syncGoalProgress |
| `saveSession` | ✅ | ✅ — upsert session |

**هل نحتاج دوال جديدة؟** نعم، دالة `updateSessionResult` في AppProvider:
```dart
// مقترحة − ليست منفذة
Future<void> updateSessionResult(
  String sessionId,
  String newResult,
) async { ... }
```

---

## 6. XP — تحليل الخيارات

### الوضع الحالي

```dart
await _grantXp(
  session.studentId,
  session.quickResult == 'متقن' ? 2 :
  session.quickResult == 'بمساعدة' ? 1 : 0
);
```

و `_grantXp`:
```dart
final xp = current.xp + value;  // value يمكن أن يكون سالب؟
final updated = Reward(xp: xp, level: (xp ~/ 100) + 1, ...);
```

**ملاحظة:** `_grantXp` يقبل `int value` — يمكن أن يكون سالبًا وسيشتغل (`current.xp + (-2)`). لكنه private method (`_grantXp`) ولا يمكن استدعاؤه من خارج AppProvider بسهولة.

### الخيار A: لا نغير XP إطلاقًا (مُوصى به لـ V1)

```
الإيجابيات:
  - لا خطر على مستوى الطالب
  - لا حاجة لإعادة حساب level/badges
  - لا تأثير نفسي (XP لا ينزل)
  - أبسط تنفيذ

السلبيات:
  - XP غير دقيق (يعطي 2 XP لجلسة صُححت إلى 0)
  - الأهل قد يلاحظون XP لا يتطابق مع النتائج الفعلية
```

### الخيار B: عكس XP القديم وإضافة الجديد

```
الإيجابيات:
  - XP دقيق

السلبيات:
  - level قد ينزل (xp ~/ 100) + 1
  - badge قد يُسحب (إذا كان مرتبطًا بـ 50 XP)
  - daily streak قد يتأثر
  - Logically complex: هل نطبق الفرق (delta) أم نعكس كامل؟
```

### الخيار C: تسجيل Adjustment مستقل

```
الإيجابيات:
  - XP الكلي دقيق بعد التعديلات
  - لا يُغير XP الجلسة الأصلية
  - يُسجل كـ adjustment منفصل في audit log

السلبيات:
  - يحتاج حقل adjustment في Reward model أو جدول منفصل
  - تغيير في قاعدة البيانات ← محظور حاليًا
```

### التوصية

| المعيار | A (لا تغيير) | B (عكس) | C (Adjustment) |
|---------|-------------|---------|----------------|
| أمان | ✅ عالٍ جدًا | ⚠️ متوسط | ✅ عالٍ |
| تعقيد | ✅ لا شيء | ⚠️ متوسط | ❌ عالٍ |
| دقة XP | ❌ غير دقيق | ✅ دقيق | ✅ دقيق |
| تغيير DB | لا | لا | ✅ نعم |
| خطر على level | لا | ✅ ممكن | لا |

**الخيار A هو الأقل خطورة للمرحلة الأولى (V1).** XP نظام تحفيزي للطالب، ليس تشخيصيًا. عدم دقته المؤقتة مقبولة. يمكن إضافة adjustment في V2.

---

## 7. قيود الأمان — التوصية

### من يمكنه التصحيح؟

| الدور | مسموح؟ |
|-------|--------|
| الأخصائي (صاحب الجلسة) | ✅ نعم |
| أخصائي آخر للطالب نفسه | ✅ نعم |
| مدير المركز | ✅ نعم |
| ولي الأمر | ❌ لا |

التوصية: **أي أخصائي لديه حق الوصول للطالب** — لأن الهدف هو دقة البيانات، والتصحيح لا يضر أحدًا.

### متى يمكن التصحيح؟

| القيد | التوصية | السبب |
|-------|---------|-------|
| لآخر جلسة فقط | ❌ لا | الأخطاء تكتشف أحيانًا بعد عدة جلسات |
| خلال 24 ساعة | ❌ لا | قد يمر يوم قبل الملاحظة |
| خلال 7 أيام | ✅ نعم (مقترح) | حد معقول |
| بدون حد زمني | ❌ لا | جلسة عمرها سنة تغييرها يضر التقارير |

### رسالة تأكيد؟

**نعم** — Modal تأكيد إجباري:

```
⚠️  تأكيد تصحيح النتيجة

سيتم تغيير النتيجة من "متقن" إلى "بمساعدة"

هذا سيؤثر على:
• تقدم الهدف
• حالة المهارات
• المتابعات

لن يتغير XP.

[إلغاء]  [تأكيد التصحيح]

✓ سأتحمل المسؤولية
```

### Audit Log

إجباري:
```dart
// مقترح − غير منفذ
await _log(
  action: 'تصحيح نتيجة جلسة',
  entityType: 'session',
  entityId: session.id,
  details: 'من $oldResult إلى $newResult. الطالب: ${student.id}',
);
```

---

## 8. الجلسات متعددة المهارات — مشكلة جوهرية

### كيف تُحفظ المهارات حاليًا؟

في `_recordGoalSession`:
```dart
final evaluated = steps.where((s) => s.status != 'لم يبدأ' && s.status.isNotEmpty).toList();
if (steps.isEmpty) {
  summary = 'تقييم هدف: ${goal.goal} - النتيجة: $status';
} else if (evaluated.isEmpty) {
  summary = 'تقييم: $status';
} else {
  summary = evaluated.map((s) => '${s.title}: ${s.status}').join(' | ');
}

final session = TherapySession(
  skillId: '',           // ← دائمًا فارغ
  skillId: '',           // ← دائمًا فارغ
  notes: summary,        // ← يستخدم notes لتخزين ملخص السرد
  summary: '',           // ← غير مستخدم
  ...
);
```

**المهارات غير محفوظة بشكل منظم.** كل ما لدينا:
1. `notes` ← نص مثل `"مهارة 1: متقن | مهارة 2: بمساعدة"`
2. `skillId` ← دائمًا `""`

### أثر ذلك على تصحيح النتيجة

```
مشكلة: إذا صحح الأخصائي quickResult من "متقن" إلى "بمساعدة"،
ما هي المهارة (GoalSkillStep) التي يجب تغييرها؟

في الجلسة، quickResult هو نتيجة الهدف ككل.
لكن المهارات المتعددة قد يكون لكل منها نتيجة مختلفة.

إذا كانت الجلسة تضم 3 مهارات:
  - مهارة 1: متقن
  - مهارة 2: متقن
  - مهارة 3: بمساعدة ← فقط هذه تحتاج تصحيح

الحل بسيط: quickResult يشير إلى نتيجة الجلسة (أدنى نتيجة عادة).
تصحيحه لا يعني تغيير كل المهارات — بل تغيير تقييم الجلسة فقط.

لكن: إذا ضغط الأخصائي "متقن" بالخطأ على مهارة معينة،
فإن المشكلة ليست في quickResult فقط — بل في:
  GoalSkillStep.status = 'متقن' حيث يجب أن يكون 'بمساعدة'
```

### أثر ذلك على التقارير

```
حاليًا:
  - لا يمكن استخراج "كم جلسة تضمنت مهارة X"
  - لا يمكن حساب "كم مرة قيمت مهارة Y بـ متقن/بمساعدة"
  - skillId دائمًا فارغ ← لا ربط مباشر بين Session و GoalSkillStep

مستقبلًا:
  - يجب تخزين goalSkillStepId أو array من step IDs في الجلسة
  - أو استخدام جدول session_skills (many-to-many)
  - هذا خارج نطاق التصحيح الحالي
```

### أثر ذلك على الإحصائيات

```
بدون skillId منظم:
  - لا يمكن معرفة أي جلسة قيمت أي مهارة
  - تحليل "تحسن المهارة X عبر الوقت" غير ممكن
  - التقارير الحالية تعتمد على notes النصي فقط
```

**توصية:** لا نعالج هذه المشكلة في V1 للتصحيح. نركز على quickResult فقط. معالجة هيكل المهارات في الجلسة مشروع منفصل.

---

## 9. المخاطر — كاملة

### 9.1 إعادة حساب progress

| الخطر | الخطورة | التخفيف |
|-------|---------|---------|
| goalProgress يعاد حسابه تلقائيًا ← صحيح | منخفض | ديناميكي، لا خطأ |
| لكن TrainingPlan.progress في DB قد لا يتطابق مع goalProgress() | متوسط | `syncGoalProgress()` يحل هذا |

### 9.2 إعادة فتح followups

| الخطر | الخطورة | التخفيف |
|-------|---------|---------|
| upsertFollowup قد ينشئ followup مكرر | منخفض | الدالة تمنع التكرار (تفحص pending أولًا) |
| followup مغلقة سابقًا لا تُفتح مجددًا | منخفض | إنشاء جديدة كافٍ |

### 9.3 جلسات قديمة

| الخطر | الخطورة | التخفيف |
|-------|---------|---------|
| تصحيح جلسة قديمة يغير progress الحالي | متوسط | تحديد حد زمني (7 أيام) |
| تقارير سابقة أصبحت غير دقيقة | عالٍ | audit log + إشعار "تحتاج مراجعة" |

### 9.4 XP

| الخطر | الخطورة | التخفيف |
|-------|---------|---------|
| XP لا يعكس النتيجة المصححة | منخفض | مقبول في V1 (XP تحفيزي) |
| Level مبني على XP غير دقيق | منخفض | التأثير ضئيل (XP يتراكم) |

### 9.5 التقارير

| الخطر | الخطورة | التخفيف |
|-------|---------|---------|
| تقرير أسبوعي/شهري صدر بنتيجة قديمة | عالٍ | audit log + manual re-run |
| تقارير للأهل تظهر نتيجة غير دقيقة | عالٍ | التنبيه قبل التصحيح |

### 9.6 الأهداف المنجزة

| الخطر | الخطورة | التخفيف |
|-------|---------|---------|
| هدف منجز يعود نشطًا ← يفاجئ الأخصائي | متوسط | عرض رسالة "الهدف سيعود لقيد العلاج" |
| والدا الطالب رأى الهدف منجزًا ثم عاد نشطًا | متوسط | إشعار للأخصائي فقط في V1 |

### 9.7 تعديل متزامن

| الخطر | الخطورة | التخفيف |
|-------|---------|---------|
| أخصائي يصحح النتيجة في نفس وقت تحديث آخر | منخفض | upsert يتعامل مع هذا (last write wins) |

---

## 10. التوصية النهائية

### هل ننفذ الآن؟

**نعم — بتنفيذ محدود جدًا (V1).**

### لماذا الآن؟

1. النظام الحالي يدعمه بنسبة ~80% — `goalProgress` ديناميكي، `goalStatus` ديناميكي، `upsertFollowup` و `resolveFollowupForStep` جاهزان.
2. لا يحتاج تغيير قاعدة بيانات.
3. لا يحتاج migration.
4. التأثير متمركز في دالة واحدة جديدة (`updateSessionResult`).
5. XP معزول (لا نغيره).
6. الفلاتر تلقائية — الهدف يعود نشطًا بدون كود إضافي.

### أقل نسخة آمنة ممكنة (V1)

```
V1 — التصحيح:
  │
  ├── 1. 【جديد】updateSessionResult(sessionId, newResult) في AppProvider
  │     ├── يجد الجلسة القديمة
  │     ├── ينشئ TherapySession جديد بنفس id + quickResult جديد
  │     ├── يُلحق ملاحظة: "صُححت من X إلى Y في {date}"
  │     ├── upsert إلى DB
  │     └── يحدث in-memory
  │
  ├── 2. 【موجود】updateGoalSkillStepStatus()
  │     └── فقط إذا كان الهدف له مهارات والجلسة مرتبطة بمهارة محددة
  │
  ├── 3. 【موجود】syncGoalProgress() ← إعادة حساب progress
  │
  ├── 4. 【موجود】upsertFollowup() أو resolveFollowupForStep()
  │     └── حسب النتيجة الجديدة
  │
  ├── 5. 【موجود】_log() ← audit log
  │
  ├── 6. 【موجود】notifyListeners() ← UI يتحدّث تلقائيًا
  │
  └── 7. 【لا نفعل】لا تغيير XP
```

### ما الذي لن يكون في V1؟

- ❌ تغيير XP
- ❌ إعادة إنشاء تقارير
- ❌ إشعارات للأهل
- ❌ حد زمني (اختياري — يمكن إضافته بسهولة)
- ❌ إصلاح هيكل المهارات في الجلسة

### أين سيظهر زر التصحيح؟

فقط داخل **Bottom Sheet** تفاصيل الجلسة (الذي صممناه في المرحلة السابقة). ليس في القائمة الرئيسية. ليس في شاشة الجلسات.

### مسار العمل النهائي

```
الآن:
  │
  ├── ✅ تحليل الميزة (هذا التقرير)
  │
  ├── المرحلة 1: إعادة تصميم الجلسات السابقة (تم تحليلها سابقًا)
  │     └── Timeline + Bottom Sheet + زر تصحيح معطل
  │
  ├── المرحلة 2: تنفيذ V1 للتصحيح
  │     ├── دالة updateSessionResult()
  │     ├── تفعيل زر التصحيح
  │     ├── Modal تأكيد
  │     ├── ربط المنطق (goalSkillStepStatus, followup, syncGoalProgress)
  │     ├── Audit log
  │     └── XP: لا تغيير
  │
  └── المرحلة 3: تحسينات (V2)
        ├── XP adjustment
        ├── إعادة تقارير
        ├── إشعارات
        └── حد زمني
```

**الخلاصة: V1 آمن وقابل للتنفيذ. الخطر الوحيد الحقيقي هو XP ونحن نعزله. الباقي تلقائي عبر goalProgress() والفلاتر.**
