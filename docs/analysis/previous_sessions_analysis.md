# تحليل قسم "الجلسات السابقة" — قبل أي تعديل

> تاريخ التقرير: 11 يونيو 2026  
> الملفات التي تم تحليلها:
> - `lib/screens/student_profile_screen.dart` (سطور 1661–1751)
> - `lib/screens/sessions_screen.dart` (سطور 40–87, 164–257)
> - `lib/providers/app_provider.dart` (سطور 912–938, 976–1101, 1109–1152)
> - `lib/data/sanad_repository.dart` (سطور 256–265, 295–296, 321–322, 673–702)
> - `lib/models/app_models.dart` (سطور 361–463)

---

## 1. كيف تُعرض الجلسات السابقة حاليًا؟

### أين يظهر القسم؟
في `student_profile_screen.dart` كآخر قسم قبل `_ReportsFromProfile`:

```
student_profile_screen.dart:1661 — _PreviousSessions (StatelessWidget)
student_profile_screen.dart:1684 — _SessionTile (StatelessWidget)
```

يظهر بعد قسم "الواجبات المنزلية" وقبل "التقارير"، كـ `AppCard` بعنوان "الجلسات السابقة" وأيقونة `timeline_outlined`.

### هل يعرض كل الجلسات؟
نعم — `app.sessions` كلها بدون فلتر. لا تقتصر على جلسات هدف معين.

### ما المعلومات المعروضة في كل جلسة؟

| الحقل | المصدر | طريقة العرض |
|-------|--------|------------|
| عنوان الجلسة | `session.cardTitle` | `titleMedium` + `w900`، max 1 line |
| نسبة النجاح | `session.successRate` | `Chip` على اليمين |
| التاريخ | `session.startedAt.split('T').first` | `Chip` |
| النوع | `session.sessionType` | `Chip` |
| النتيجة السريعة | `session.quickResult` | `Chip` |
| الأنشطة (practice items) | `_activityTags(session.practiceItems)` | `Chip` لكل activity، حد أقصى 4 + "+N" |
| الملخص | `session.summary` | نص عادي، max 2 lines |
| ملاحظة الأخصائي | `session.notes` | نص عادي، max 2 lines |

التنسيق العام:
```
┌───────────────────────────────────┐
│ اسم الهدف / عنوان الجلسة     [85%]│ ← cardTitle + successRate
│ [2026-01-01] [نطق وتخاطب] [متقن] │ ← startedAt + sessionType + quickResult
│ [نشاط1] [نشاط2] [نشاط3] [+2]     │ ← practiceItems (max 4)
│ ملخص الجلسة...                    │ ← summary (max 2 lines)
│ ملاحظة الأخصائي: ...             │ ← notes (max 2 lines)
└───────────────────────────────────┘
```

### هل الجلسات مرتبة بالأحدث؟
حاليًا تعتمد على ترتيب `app.sessions` كما هو في الذاكرة. يتم تحميلها من DB بـ `ORDER BY started_at DESC`، لذا تأتي الأحدث أولًا. لكن عند إضافة جلسة جديدة عبر `saveSession()`، تُضاف إلى نهاية القائمة (`sessions.add(session)`)، مما يعني أن الجلسات الجديدة تظهر في الأسفل وليس الأعلى.

### هل تعرض الهدف المرتبط؟
نعم — عبر `session.cardTitle` الذي يتم تعيينه إلى `goal.goal` عند إنشاء الجلسة (في `_recordGoalSession`: `cardTitle: goal.goal`).

### هل تعرض المهارة المرتبطة؟
غير مباشر — `session.skillId` موجود في النموذج ولكن نادرًا ما يُستخدم. حاليًا `skillId: ''` عند إنشاء الجلسة. لا يوجد عرض للمهارات التي قيّمت داخل الجلسة. المهارات موجودة فقط في `session.notes` (نص السرد `'${step.title}: ${step.status}'`).

### هل تعرض quickResult؟
نعم — `Chip` مع `session.quickResult`.

### هل تعرض notes؟
نعم — `session.notes` كمحتوى السرد. لكن الوضع الحالي يستخدم `session.notes` لتخزين ملخص السرد (`summary`) وليس كملاحظات الأخصائي الفعلية. ملاحظة: الحقل `summary` في الجلسة غالبًا ما يكون فارغًا.

### هل القسم مزدحم؟
نعم، نسبيًا. `_SessionTile` يعرض 4–7 أجزاء من المعلومات في بطاقة صغيرة (padding 14px) مع حواف 8px. مع كثرة الجلسات، يصبح القسم طويلاً والقراءة مرهقة. لا يوجد `group by day` أو `timeline`. كل جلسة تأخذ ~120px بدون أنشطة، و~160px مع أنشطة.

---

## 2. ما مصدر بيانات الجلسات؟

### الجدول: `sessions` (في SQLite)

```sql
CREATE TABLE sessions (
  id              TEXT PRIMARY KEY,
  center_id       TEXT NOT NULL,
  student_id      TEXT NOT NULL,
  specialist_id   TEXT NOT NULL DEFAULT '',
  plan_id         TEXT NOT NULL DEFAULT '',
  program_id      TEXT NOT NULL DEFAULT '',
  skill_id        TEXT NOT NULL DEFAULT '',
  activity_results TEXT NOT NULL DEFAULT '',
  session_type    TEXT NOT NULL DEFAULT 'نطق وتخاطب',
  target_letter   TEXT NOT NULL DEFAULT '',
  letter_position TEXT NOT NULL DEFAULT '',
  error_type      TEXT NOT NULL DEFAULT '',
  practice_items   TEXT NOT NULL DEFAULT '',
  attempts         INTEGER NOT NULL DEFAULT 0,
  success_rate     INTEGER NOT NULL DEFAULT 0,
  started_at       TEXT NOT NULL,
  duration_seconds INTEGER NOT NULL,
  card_title       TEXT NOT NULL,
  quick_result     TEXT NOT NULL,
  notes           TEXT NOT NULL,
  summary         TEXT NOT NULL DEFAULT '',
  created_at      TEXT NOT NULL,
  updated_at      TEXT NOT NULL,
  FOREIGN KEY(center_id) REFERENCES centers(id),
  FOREIGN KEY(student_id) REFERENCES students(id)
)
```

### الحقول المستخدمة فعليًا:

| الحقل | مستخدم؟ | أين؟ |
|-------|---------|------|
| `id` | ✅ | أساسي |
| `center_id` | ✅ | أمان وصول |
| `student_id` | ✅ | فلترة |
| `specialist_id` | ✅ | `specialistSessions` getter |
| `plan_id` | ✅ | ربط الهدف |
| `program_id` | ✅ | ربط البرنامج |
| `skill_id` | ❌ | غير مستخدم (دائمًا `""`) |
| `activity_results` | ❌ | غير مستخدم |
| `session_type` | ✅ | عرض |
| `target_letter` | ❌ | غير مستخدم |
| `letter_position` | ❌ | غير مستخدم |
| `error_type` | ❌ | غير مستخدم |
| `practice_items` | ✅ | عرض (أنشطة) |
| `attempts` | ❌ | غير مستخدم |
| `success_rate` | ✅ | عرض |
| `started_at` | ✅ | عرض + ترتيب |
| `duration_seconds` | ❌ | غير مستخدم |
| `card_title` | ✅ | عرض |
| `quick_result` | ✅ | عرض + حساب progress |
| `notes` | ✅ | عرض (لكن يُستخدم كملخص) |
| `summary` | ❌ | غير مستخدم (دائمًا `""`) |
| `created_at` | ❌ | غير مستخدم |
| `updated_at` | ❌ | غير مستخدم |

### التناقض في `notes` و `summary`:
عند إنشاء الجلسة في `_recordGoalSession`:
```dart
notes: summary,   // <-- يُستخدم notes لتخزين ملخص السرد
```
والحقل `summary` لا يُعيّن أبدًا (`''`).

### تحميل البيانات:
- `_repository.sessions(studentId)` → `SELECT * FROM sessions WHERE student_id = ? ORDER BY started_at DESC`
- تحميل عند `selectStudent()` في `app_provider.dart:567`
- الحفظ: `_db.upsert('sessions', session.toMap())` — INSERT OR REPLACE
- لا يوجد حذف للجلسات في الكود

### النموذج: `TherapySession`
```dart
class TherapySession {
  final String id, centerId, studentId, specialistId;
  final String planId, programId, skillId;
  final String activityResults, sessionType;
  final String targetLetter, letterPosition, errorType;
  final String practiceItems;
  final int attempts, successRate;
  final String startedAt;
  final int durationSeconds;
  final String cardTitle, quickResult, notes, summary;
  final String createdAt, updatedAt;
}
```

لا `copyWith` ولا `toMap` معدّل — كائن غير قابل للتغيير (`final` fields). لتعديل جلسة، يجب إنشاء كائن `TherapySession` جديد.

---

## 3. كيف نعيد تصميم الجلسات السابقة؟

### الاقتراح: Timeline + Group by Day + Bottom Sheet

#### أ. الهيكل العام

```
┌──────────────────────────────────────────────┐
│  🕐 الجلسات السابقة                          │
├──────────────────────────────────────────────┤
│                                              │
│  اليوم — 10 يونيو 2026                       │
│  ┌────────────────────────────────────────┐  │
│  │  🟢  تعرف على الحيوانات      قيد العلاج│  │
│  │  🕐 10:30 ص  ·  🔄 2 متابعات          │  │
│  └────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────┐  │
│  │  🔵  الألوان الأساسية          تدريب   │  │
│  │  🕐 10:00 ص  ·  ✔ 3 من 5 مهارات      │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  أمس — 9 يونيو 2026                          │
│  ┌────────────────────────────────────────┐  │
│  │  🟠  نطق حرف الراء          بمساعدة   │  │
│  │  🕐 2:30 م                          │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  قبل 3 أيام — 7 يونيو 2026                   │
│  ┌────────────────────────────────────────┐  │
│  │  🔴  نطق حرف السين       يحتاج إعادة  │  │
│  │  🕐 11:15 ص                          │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  [عرض المزيد] ← إذا كان العدد كبيرًا         │
└──────────────────────────────────────────────┘
```

#### ب. البطاقة المختصرة لكل جلسة

| العنصر | التفاصيل |
|--------|----------|
| أيقونة النتيجة | 🟢 متقن / 🟠 بمساعدة / 🔴 يحتاج إعادة / ⚪ تدريب |
| اسم الهدف | `cardTitle` + `sessionType` |
| الوقت | `startedAt` بصيغة ساعة:دقيقة (ليس التاريخ كاملًا) |
| متابعات | أيقونة 🔄 إذا كانت الجلسة خلّفت متابعات مفتوحة |
| نتيجة مختصرة | Color-coded dot حسب `quickResult` |

#### ج. Bottom Sheet عند الضغط

```
┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐
          ━━━  (drag handle)

  🟢  اسم الهدف / عنوان الجلسة
  ──────────────────────────────────
  📅  10 يونيو 2026  |  🕐  10:30 ص
  🏷  نطق وتخاطب  |  📊  85%  |  ✅  متقن
  ⏱  15 دقيقة

  الهدف: تعرف على الحيوانات
  النتيجة للمهارات:
    ✔  مهارة 1 - متقن
    ✔  مهارة 2 - متقن
    ○  مهارة 3 - بمساعدة

  🔄  متابعات مفتوحة (1)
    ○  مهارة 3 - بمساعدة

  📝  ملاحظات الأخصائي:
     ... (نص كامل بدون قطع)

  ⚙️  [تصحيح النتيجة]  ← زر جديد (v2)
└ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘
```

#### د. خطة التنفيذ

المرحلة 1 — إعادة تصميم القسم فقط (لا تصحيح):
1. Group by day: أمس، اليوم، قبل X أيام
2. بطاقة مختصرة لكل جلسة (اسم + نتيجة + وقت + اختصار)
3. الضغط على البطاقة → Bottom Sheet بالتفاصيل الكاملة
4. داخل Bottom Sheet: اسم الهدف، التاريخ، النتيجة، المهارات التي قيّمت، الملاحظات، المتابعات
5. تقليل الزحمة في القائمة الرئيسية

المرحلة 2 — تصحيح النتيجة:
6. زر "تصحيح النتيجة" داخل Bottom Sheet
7. Modal تأكيد
8. منطق التصحيح (انظر القسم 5)

---

## 4. ميزة تصحيح نتيجة جلسة

### هل يمكن تعديل `TherapySession.quickResult`؟

**نعم**، تقنيًا:
- لا يوجد `updateSession` حاليًا في AppProvider
- لكن الـ Repository يدعم `upsert` (INSERT OR REPLACE) — `_db.upsert('sessions', session.toMap())`
- والنموذج `TherapySession` له `toMap()` و `fromMap()` كاملين
- يمكن إضافة دالة `updateSessionResult(String sessionId, String newResult)` في AppProvider
- التحديث سهل: إنشاء `TherapySession` جديد بنفس `id` (لأن `toMap()` يكتب `id` و upsert يستخدمه كمفتاح)

**مثال وهمي (غير منفذ):**
```dart
// AppProvider — دالة جديدة مقترحة
Future<void> updateSessionResult(String sessionId, String newResult) async {
  final matches = sessions.where((s) => s.id == sessionId).toList();
  if (matches.isEmpty) return;
  final old = matches.first;
  final updated = TherapySession(
    id: old.id,       // نفس id ← upsert سيعمل UPDATE
    // ... باقي الحقول نفس old
    quickResult: newResult,
    notes: '${old.notes} | صُححت النتيجة من ${old.quickResult} إلى $newResult',
  );
  await _repository.saveSession(updated);
  // تحديث الذاكرة
  final idx = sessions.indexWhere((s) => s.id == sessionId);
  if (idx != -1) sessions[idx] = updated;
  notifyListeners();
}
```

### هل يمكن إعادة حساب `goalProgress` بعد التصحيح؟

**نعم** — `goalProgress()` هو getter ديناميكي:
```dart
int goalProgress(String goalId) { ... }
```
لا يحتاج إلى استدعاء — هو يحسب من `sessions` و `goalSkillSteps` مباشرة. تغيير `quickResult` لجلسة سيؤثر تلقائيًا على `goalProgress()` للهدف المرتبط (عبر `sessions.where(s.planId == goalId).first.quickResult`).

**ملاحظة مهمة:** `goalProgress` لا يُحفظ في قاعدة البيانات للأهداف بدون مهارات (يُحسب runtime). للأهداف ذات المهارات، `syncGoalProgress` يُحفظ الـ progress في `training_plans.progress` بعد `updateGoalSkillStepStatus`. التصحيح سيحتاج إلى إعادة `syncGoalProgress`.

### هل يمكن إعادة الهدف من المنجز إلى النشط؟

**نعم** — `goalProgress()` سيعيد القيمة الجديدة تلقائيًا:
- تصحيح من "متقن" إلى "بمساعدة" → `goalProgress` سيتغير من 100 إلى 50
- الفلاتر في `_GoalProgressSection`: `app.goalProgress(p.id) < 100` ستلتقطه تلقائيًا
- `_MasteredGoalsSection`: `app.goalProgress(p.id) >= 100` ستخرجه تلقائيًا

**لا حاجة لأي منطق إضافي للفلاتر.** فقط `notifyListeners()` كافٍ.

### هل يمكن إعادة فتح followup إذا أصبحت النتيجة "بمساعدة" أو "يحتاج إعادة"؟

**نعم** — يمكن استدعاء `upsertFollowup()` مباشرة بعد التصحيح:
```dart
// منطق مقترح: بعد تغيير quickResult
if (newResult == 'بمساعدة' || newResult == 'يحتاج إعادة') {
  await app.upsertFollowup(
    studentId: session.studentId,
    specialistId: ...,
    programId: session.programId,
    sourceType: ..., // من plan المرتبط
    planId: session.planId,
    goalSkillStepId: ..., // المهارة المرتبطة
    reason: newResult == 'بمساعدة' ? 'assisted' : 'retry',
  );
}
```

لكن هناك تعقيد:
- إذا كان الهدف له **مهارات متعددة**، أي مهارة نعيد فتح متابعتها؟
- هل نعيد فتح متابعة لجميع المهارات التي كانت في تلك الجلسة؟
- المهارات المحددة غير مخزنة في `session.skillId` (دائمًا `""`)

**الحل المقترح:** تخزين `goalSkillStepId` في الجلسة عند الإنشاء، أو استخدام الـ `notes` (الذي يحتوي على `'مهارة 1: متقن | مهارة 2: بمساعدة'`) لاستخراج المهارات.

### هل يمكن إغلاق followup إذا صححها إلى "متقن"؟

**نعم** — `resolveFollowupForStep()` موجودة وجاهزة.

### ماذا يحدث للـ XP الذي أُضيف سابقًا؟

هذا هو **أخطر جزء** في التصحيح.

عند إنشاء الجلسة:
```dart
if (session.quickResult == 'متقن') → +2 XP
if (session.quickResult == 'بمساعدة') → +1 XP
if (session.quickResult == 'يحتاج إعادة') → 0 XP
```

إذا صُححت النتيجة:
- من "متقن" (2 XP) إلى "يحتاج إعادة" (0 XP): الفرق = -2 XP
- من "متقن" (2 XP) إلى "بمساعدة" (1 XP): الفرق = -1 XP
- من "بمساعدة" (1 XP) إلى "متقن" (2 XP): الفرق = +1 XP
- من "يحتاج إعادة" (0 XP) إلى "متقن" (2 XP): الفرق = +2 XP

**الخيارات:**
1. **عكس XP بالضبط** — `_grantXp(studentId, -(oldXp))` ثم `_grantXp(studentId, newXp)`، لكن `_grantXp` ليس لديه منطق عكس.
2. **تطبيق الفرق** — `_grantXp(studentId, newXp - oldXp)`. لكن `_grantXp` لا يدعم القيم السالبة (يضيف إلى `reward.xp` مباشرة).
3. **تسجيل adjustment** — عدم لمس XP القديم، بل تسجيل تعديل منفصل في `audit_logs`.
4. **تجاهل XP** — عدم تغيير XP عند التصحيح (الأكثر أمانًا للمرحلة الأولى).

### هل نحتاج audit log؟

**نعم** — نظام الـ audit log موجود مسبقًا:
```dart
await _log(
  action: 'تصحيح نتيجة جلسة',
  entityType: 'session',
  entityId: session.id,
  centerId: session.centerId,
  details: 'من $oldResult إلى $newResult بواسطة ${app.user?.id}',
);
```

يجب إضافة audit log لكل تصحيح.

### هل نحتاج رسالة تأكيد؟

**نعم** — `showDialog` مع تحذير:
```
⚠️  تصحيح نتيجة الجلسة

سيتم:
• تغيير نتيجة الجلسة من "متقن" إلى "بمساعدة"
• إعادة حساب تقدم الهدف
• فتح متابعة جديدة للمهارة

هل تريد المتابعة؟
[إلغاء]  [تأكيد التصحيح]
```

---

## 5. قواعد مقترحة لتصحيح النتيجة

### من يمكنه التصحيح؟
- ✅ الأخصائي (صاحب الجلسة أو أي أخصائي للطالب)
- ✅ مدير المركز
- ❌ ولي الأمر
- ✅ مع تسجيل audit log

### أين يظهر التصحيح؟
- فقط داخل **Bottom Sheet** لتفاصيل الجلسة
- ليس في القائمة الرئيسية
- ليس في أي شاشة أخرى

### ماذا يفعل التصحيح؟
1. يغير `TherapySession.quickResult`
2. يحدث `goalSkillStep.status` (إذا كان الهدف له مهارات)
3. يستدعي `syncGoalProgress()` لإعادة حساب progress
4. يفتح/يغلق `StudentFollowup` حسب النتيجة الجديدة
5. يسجل audit log
6. لا يغير XP (للمرحلة الأولى — آمن)

### ماذا لا يفعل التصحيح؟
- ❌ لا يحذف الجلسة
- ❌ لا يغير التقييمات (ClinicalAssessment)
- ❌ لا يغير `templateId`
- ❌ لا يغير `sourceType` / `programId`
- ❌ لا يغير الملاحظات السابقة (يضيف إليها فقط)
- ❌ لا يؤثر على XP (للمرحلة الأولى)

### XP — المقترح للمرحلة الأولى:

**لا نغير XP على الإطلاق.** الأسباب:
- XP نظام ترفيهي للطالب، ليس تشخيصيًا
- عكس XP قد يسبب:
  - Level ينزل (محرج للطالب)
  - Badge يُسحب (غير جيد نفسيًا)
  - Daily streak يتأثر
- الـ XP أُعطي عن جلسة حقيقية (حتى لو كانت النتيجة خطأ)
- يمكن إضافة منطق XP في v2 إذا احتاج الأمر

### المقترح لـ v1 (بسيط):

```
تصحيح النتيجة:
  │
  ├── 1. تغيير session.quickResult (في DB + in-memory)
  ├── 2. تغيير skill step status (إن وجد)
  ├── 3. syncGoalProgress()
  ├── 4. upsertFollowup() أو resolveFollowupForStep()
  ├── 5. Audit log (تصحيح نتيجة)
  └── 6. notifyListeners()
       └── ← UI يتحدّث تلقائيًا (goalProgress, الفلاتر, إلخ)
```

---

## 6. المخاطر

### خطر تعديل جلسة قديمة بعد تقارير
إذا تم إنشاء تقرير (report) استنادًا إلى جلسة بقيمة "متقن"، ثم صُححت النتيجة لاحقًا، يصبح التقرير غير دقيق.

**التخفيف:**
- عرض تحذير في Audit log
- إضافة ملاحظة في الجلسة: `"صُححت النتيجة من متقن إلى بمساعدة في 2026-06-11"`
- في الإصدارات المستقبلية: إعادة إنشاء التقرير أو وضع علامة "بحاجة مراجعة"

### خطر تغيير progress بدون audit
بدون audit log، لا يمكن تتبع من صَحح ومتى.

**الحل:** audit log إجباري مع كل تصحيح.

### خطر XP
كما نوقش أعلاه. تجاهل XP في v1 يزيل هذا الخطر تمامًا.

### خطر followups
إذا صُححت النتيجة من "متقن" إلى "بمساعدة"، يجب فتح followup جديد. إذا كان هناك followup سابق قد أُغلق، يجب إعادة فتحه بدل إنشاء جديد.

**الحل:** استخدام `upsertFollowup()` الذي يتحقق من وجود followup pending مسبقًا.

### خطر هدف منجز يرجع نشط
هذا تلقائي وآمن — `goalProgress()` والفلاتر ديناميكية. لا خطر.

### خطر أن يكون التصحيح بعد أيام كثيرة
كلما زاد الوقت، زادت الآثار الجانبية:
- تقارير صدرت بناءً على النتيجة القديمة
- متابعات أُغلقت أو أُنشئت بناءً عليها
- مدرب آخر اطّلع على النتيجة القديمة

**التخفيف:**
- تحديد حد زمني للتصحيح (مثلاً 7 أيام من تاريخ الجلسة)
- عرض تحذير إذا مر أكثر من 3 أيام
- تسجيل كل شيء في audit log

---

## 7. توصية تنفيذية

### الترتيب المقترح:

**المرحلة 1 — إعادة تصميم الجلسات السابقة فقط (بدون تصحيح):**
1. Group by day (today, yesterday, earlier)
2. بطاقة مختصرة لكل جلسة
3. Bottom Sheet للتفاصيل
4. عرض المهارات والمتابعات داخل الـ Sheet
5. **زر "تصحيح النتيجة" موجود لكنه معطل أو مخفي** ← استعدادًا للمرحلة 2

**المرحلة 2 — تصحيح النتيجة:**
1. تفعيل زر "تصحيح النتيجة" في Bottom Sheet
2. Modal تأكيد وتحذير
3. تغيير session.quickResult
4. تحديث skill step status + syncGoalProgress
5. إدارة followups
6. Audit log
7. تجاهل XP (v1)
8. في v2: تسجيل adjustment XP

### لماذا التصميم أولًا؟
- تحسين UX فوري لمستخدمي التطبيق
- لا يحتاج تغيير منطق
- بدون مخاطر
- يهيئ المكان لزر التصحيح

### لماذا التصحيح لاحقًا؟
- يحتاج دراسة XP
- يحتاج إدارة followups المعقدة
- يحتاج audit log
- قد يحتاج حد زمني
- يمكن اختباره بشكل منفصل دون تغيير التصميم

### نعم، v1 بسيط:
- تجاهل XP (أكثر قرار أمانًا للمرحلة الأولى)
- Audit log إجباري
- حد زمني 7 أيام (اختياري، مقترح)
- التحذير: "تم تغيير النتيجة. لن يتغير XP."

### مسار العمل المقترح:

```
الآن                    المرحلة 1            المرحلة 2 (v1)        المرحلة 2 (v2)
│                       │                    │                     │
├── تحليل ← أنت هنا    ├── Timeline UI       ├── تصحيح النتيجة     ├── XP adjustment
│                       │  + Bottom Sheet    │  + Modal تأكيد      │  + إعادة تقارير
│                       │  + استعداد للزر    │  + Log + Followups  │  + إشعارات
│                       │  + 0 خطر           │  + 0 XP             │  + حد زمني
└───────────────────────┴────────────────────┴─────────────────────┴────────────────────
```

**التوصية النهائية:** ابدأ بالمرحلة 1 فورًا (إعادة تصميم عرض الجلسات السابقة). هذا يحسّن تجربة الأخصائي اليومية بدون أي مخاطرة. أضف زر تصحيح النتيجة معطلًا (greyed out) في Bottom Sheet استعدادًا للمرحلة 2. نفّذ المرحلة 2 في sprint منفصل بعد اختبار المرحلة 1.
