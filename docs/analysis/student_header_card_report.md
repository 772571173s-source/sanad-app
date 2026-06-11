# تقرير: إعادة بناء Header ملف الطالب — StudentHeaderCard

> تاريخ التقرير: 11 يونيو 2026  
> الملف المعدل: `lib/screens/student_profile_screen.dart`  
> `flutter analyze`: ✅ 0 errors, 0 new warnings  
> `flutter test`: ✅ 48/48 passed  

---

## 1. ماذا أزلت من الجزء العلوي؟

تم حذف 3 عناصر من الـ Header القديم:

| العنصر | السبب |
|--------|-------|
| **ولي الأمر** (`student.parentName`) | سينتقل لقسم معلومات منفصل لاحقًا |
| **رقم ولي الأمر** (`student.parentPhone`) | سينتقل لقسم معلومات منفصل لاحقًا |
| **البريد / اسم المستخدم** (`student.portalEmail`) | معلومات تواصل، ليست ضرورية في الـ Header |
| **ملاحظات الملف** (`student.notes`) | ستنتقل لقسم معلومات منفصل لاحقًا |
| **العمر** (`student.age`) | لم يعد ضروريًا في الـ Header (يمكن إضافته لاحقًا) |

كما تم حذف:

- **كلاس `_StudentOverview`** (136 سطرًا) — دمجت في `StudentHeaderCard`
- **كلاس `_CompactInfoTile`** (48 سطرًا) — لم يعد مستخدمًا
- **كلاس `_ProfileSummary`** (48 سطرًا) — دمجت في `StudentHeaderCard`

---

## 2. ماذا دمجت؟

تم دمج بطاقتين منفصلتين في **بطاقة واحدة**:

```
قبل:                                          بعد:
┌─────────────────┐                          ┌──────────────────────────────┐
│ _StudentOverview │                          │     StudentHeaderCard        │
│ (Avatar, Name,   │                          │ ┌────┐                      │
│  Status, Age,    │                          │ │Av  │ Name           Status│
│  Diagnosis,      │                          │ │atar│ Center              │
│  Programs,       │                          │ └────┘                      │
│  Parent, etc.)   │                          │ Diagnosis: xxx              │
└─────────────────┘                          │ [Prog1] [Prog2]             │
                                              │ ┌────────┐┌────────┐       │
┌─────────────────┐                          │ │آخر جلسة││جلسات   │       │
│ _ProfileSummary  │                          │ │تاريخ   ││12      │       │
│ (6 StatTile)     │                          │ └────────┘└────────┘       │
│                  │                          │ ┌────────┐┌────────┐       │
│ حالة التقييم     │                          │ │أهداف   ││متابعات │       │
│ الأهداف النشطة   │                          │ │3       ││2       │       │
│ الأهداف المتقنة  │                          │ └────────┘└────────┘       │
│ متوسط التقدم     │                          │ ┌────────┐┌────────┐       │
│ عدد الجلسات      │                          │ │تقييم   ││متوسط   │       │
│ واجبات للمراجعة  │                          │ │مقيّم   ││60%     │       │
└─────────────────┘                          │ └────────┘└────────┘       │
                                              └──────────────────────────────┘
```

---

## 3. كيف أصبحت البطاقة الجديدة؟

`StudentHeaderCard` تحتوي على 4 أقسام داخل `AppCard` واحدة:

### أ. الصورة الشخصية + الاسم + الحالة

```
[CircleAvatar] 	Name هنا مع ellipsis 	[Chip: نشط]
		اسم المركز
```

- الأيقونة ثابتة: `Icons.child_care` بلون `primaryContainer` (هوية سند)
- لا صورة حقيقية، لا أول حرف
- الاسم: `headlineSmall` + `FontWeight.w900`
- حالة الطالب: `Chip` مضغوط

### ب. التشخيص

```
🔍 التشخيص: xxx مع ellipsis إن طال
```

- يظهر فقط إذا `student.diagnosis.isNotEmpty`
- بـ `Row` مع `Icon` + `Flexible` Text

### ج. برامج الطالب

```
[برنامج نطق وتخاطب] [برنامج تعديل سلوك] [...]
```

- `Wrap` مع `spacing: 6, runSpacing: 6`
- خلفية `secondaryContainer`، خط صغير 12px
- بساطة ونظافة، بدون زحمة

### د. إحصائيات سريعة (Chips)

```
┌────────────┐ ┌───────────┐ ┌──────────┐ ┌───────────┐
│ آخر جلسة   │ │ النتيجة   │ │ جلسات    │ │ أهداف     │
│ 2026-01-01 │ │ متقن     │ │ 12       │ │ 5         │
└────────────┘ └───────────┘ └──────────┘ └───────────┘
┌────────────┐ ┌───────────┐ ┌──────────┐ ┌───────────┐
│ متابعات    │ │ للمراجعة  │ │ تقييم    │ │ متوسط     │
│ 2          │ │ 1         │ │ مقيّم    │ │ 60%       │
└────────────┘ └───────────┘ └──────────┘ └───────────┘
```

- تستخدم `Wrap` مع `spacing: 8, runSpacing: 8`
- كل chip عرضه `minWidth: 90` وارتفاعه مضبوط بـ `padding: 8`
- خلفية `surfaceContainerHighest`
- أيقونة + تسمية صغيرة (10px) + قيمة (13px bold)
- **حذف "الأهداف المتقنة"** من العرض الافتراضي وإظهارها فقط إذا `masteredCount != '0'`
- لون أيقونة النتيجة يتغير حسب `quickResult` (primary=متقن, tertiary=بمساعدة, error=يحتاج إعادة)
- جميع النصوص بـ `TextOverflow.ellipsis` و `maxLines: 1`

---

## 4. هل بقيت البيانات صحيحة؟

**نعم.** لم يتغير أي منطق بيانات:

| البيان | المصدر | لم يتغير |
|--------|--------|---------|
| آخر جلسة | `app.sessions.first.startedAt` | نفس المصدر |
| نتيجة الجلسة | `app.sessions.first.quickResult` | نفس المصدر |
| عدد الجلسات | `app.sessions.length` | نفس المصدر |
| الأهداف النشطة | `app.activeGoalCount` | نفس getter |
| الأهداف المنجزة | `app.masteredGoalCount` | نفس getter |
| المتابعات | `app.pendingFollowups.length` | نفس المصدر |
| واجبات للمراجعة | `app.pendingHomeworkReviewCount` | نفس getter |
| حالة التقييم | `app.studentAssessmentStatus` | نفس getter |
| متوسط تقدم الأهداف | `app.studentGoalImprovementRate()` | نفس getter |
| برامج الطالب | `app.programsForStudent()` | نفس getter |
| اسم الطالب | `student.name` | نفس الحقل |
| حالة الطالب | `student.status` | نفس الحقل |
| التشخيص | `student.diagnosis` | نفس الحقل |

**التحسن بين التقييمات** لا يزال موجودًا في `app.studentAssessmentImprovement` ولا يُعرض في الـ Header (كما طلبت).

**التراجع (regression)** محسوب داخليًا فقط في `AssessmentImprovementSummary` ولا يُعرض.

---

## 5. هل يوجد overflow على الهاتف؟

**لا.** تم استخدام:

- `Wrap` للبرامج والإحصائيات — تتدفق تلقائيًا للأسفل
- `Expanded` + `Flexible` للنصوص — تمنع overflow
- `TextOverflow.ellipsis` على كل النصوص الطويلة
- `maxLines: 1` عالميًا للنصوص
- `minWidth` على `_StatChip` (90px) بدون ارتفاع ثابت — يتكيف مع المحتوى

عرض المحتوى على شاشة 360px:
- الأيقونة (68px) + spacing (14px) + الاسم (≈ 200px بعد خصم الـ Chip) + Chip (≈ 60px) = مناسب
- `Wrap` يضمن أن الـ 8-9 chips تتوزع على سطرين أو ثلاثة
- لا `SingleChildScrollView` مطلوب داخل الـ Card نفسه لأن المحتوى مضغوط

---

## ملخص التعديلات

| المقياس | قبل | بعد |
|---------|-----|-----|
| عدد البطاقات في الـ Header | 2 | 1 |
| أيقونة Avatar | `Icons.child_care` | `Icons.child_care` (ثابت) |
| معلومات ولي الأمر | معروضة | محذوفة (لاحقًا) |
| ملاحظات الملف | معروضة | محذوفة (لاحقًا) |
| العمر | معروض | محذوف (لاحقًا) |
| الإحصائيات | 6 StatTile (بطاقات كاملة) | 8-9 _StatChip (مضغوطة) |
| overflow محتمل | ممكن (نصوص طويلة) | مؤمن (Wrap + ellipsis) |
| `flutter analyze` | — | ✅ 0 errors |
| `flutter test` | — | ✅ 48/48 |
