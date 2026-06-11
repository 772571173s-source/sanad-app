# تقرير: إعادة تصميم قسم الأهداف النشطة — Dashboard مصغرة

> تاريخ التقرير: 11 يونيو 2026  
> الملف المعدل: `lib/screens/student_profile_screen.dart`  
> `flutter analyze`: ✅ 0 errors, 0 new warnings  
> `flutter test`: ✅ 48/48 passed  

---

## 1. كيف أصبح قسم الأهداف النشطة؟

**قبل:** قائمة بطاقات طولية، كل بطاقة تحتوي:
- اسم الهدف + Badge
- Progress بار رفيع
- 4 سطور من الـ `_progressRow` (نصوص طويلة)
- قائمة المهارات كاملة (لكل مهارة أيقونة + اسم + حالة + زر إعادة تدريب)
- خطة العلاج (نص طويل)
- زر إعادة التدريب

**بعد:** Dashboard مصغرة — كل هدف في **`_GoalCard`**:

```
┌──────────────────────────────────┐
│ اسم الهدف                     🔵 │ ← Badge جديد
│ ████████████████░░░░░░ 50%       │ ← Progress بار سميك 8px
│ 🕐 آخر جلسة: 2026-01-01  │  📋 5 مهارات  │  🔄 2 متابعات  │ ← Chips
│ [▶ تدريب / ↻ إعادة التدريب]      │ ← زر رئيسي واحد
└──────────────────────────────────┘
```

مكونات البطاقة الجديدة (`_GoalCard`):

| العنصر | التفاصيل |
|--------|----------|
| **Card** | `borderRadius: 24`، ظل `elevation: 0`، `BorderSide` حسب الحالة |
| **Border** | جديد=رمادي، قيد العلاج=Primary، بمساعدة=عنبر، يحتاج إعادة=أحمر |
| **Progress bar** | `minHeight: 8`، لون متغير حسب الحالة (رمادي/عنبر/أحمر/Primary) |
| **Chips** | `_MiniInfoChip` — 11px، خلفية `surfaceContainerHighest`، حد أدنى |
| **زر التدريب** | `FilledButton.tonalIcon` بعرض كامل، أيقونة حسب الحالة (▶ / ↻) |

---

## 2. هل استخدمت Screen أم Bottom Sheet؟

**Bottom Sheet** — `showModalBottomSheet` مع `DraggableScrollableSheet`:

- الـ BottomSheet هو `_GoalDetails`
- `initialChildSize: 0.65`، `minChildSize: 0.4`، `maxChildSize: 0.9`
- `useSafeArea: true` (للهواتف ذات الـ notch)
- `borderRadius.vertical(top: 24)` للتناسق مع هوية سند

محتوى الـ Sheet:

```
┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐
          ━━━  (drag handle)

  اسم الهدف                  🔵
  العلاج: ... (نص كامل، غير مقتطع)

  🕐 آخر جلسة  │  ▶ الجلسات  │  📋 المهارات
     2026-01-01          3              5

  ████████████░░░░░░░░ 50%
  التقدم: 50%

  المهارات:
  ✓ مهارة 1 - متقن
  ○ مهارة 2 - بمساعدة
  ↻ مهارة 3 - يحتاج إعادة  (bg: errorContainer)

  المتابعات المفتوحة:
  ↻ مهارة 3  (bg: errorContainer)
└ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘
```

**لماذا Bottom Sheet وليس Screen؟**
- أسرع — لا يحتاج Navigator push/pop
- يحافظ على سياق ملف الطالب (الخلفية مرئية)
- مناسب للهاتف (سحب للإغلاق)
- على ويندوز يظهر كـ BottomSheet طبيعي في Material 3
- لا داعي لشاشة كاملة لمعلومات عرض فقط

---

## 3. كيف أصبح التنقل؟

```
┌──────────────────┐
│  قائمة الأهداف    │
│  (Dashboard)      │
│                   │
│ ┌───────────────┐ │
│ │ Goal Card 1   │ │ ← الضغط على البطاقة ← يفتح Bottom Sheet
│ │ [▶ تدريب]     │ │ ← الضغط على الزر ← يفتح جلسة (session)
│ └───────────────┘ │
│ ┌───────────────┐ │
│ │ Goal Card 2   │ │
│ │ [↻ إعادة]     │ │
│ └───────────────┘ │
└──────────────────┘
        │
        ├── ضغط على البطاقة → Bottom Sheet (معلومات فقط)
        │
        └── ضغط على الزر → جلسة تدريب
```

- **بطاقة ← ضغط**: `_showGoalDetails()` → `showModalBottomSheet`
- **زر تدريب**: `onTrainPressed` → `_openRetrainPlan()` → `app.selectStudent()` + `app.preselectSession()` → `onOpenSession()`
- الـ Bottom Sheet **لا يحتوي** على زر تدريب — معلومات فقط كما طلبت

---

## 4. كيف يظهر الهدف الجديد؟

| الخاصية | القيمة لهدف جديد |
|---------|-----------------|
| Border | `colors.outlineVariant` (رمادي هادئ) |
| Badge | `_StatusBadge` خلفية `surfaceContainerHighest` + أيقونة `fiber_new` |
| Progress bar | لون `outlineVariant` (رمادي) |
| لون التقدم | 0% |
| زر | **"تدريب"** مع أيقونة ▶ |
| تاريخ آخر جلسة | "لا توجد" |

---

## 5. كيف يظهر الهدف الذي يحتاج إعادة؟

| الخاصية | القيمة |
|---------|--------|
| Border | `colors.error.withValues(alpha: 0.5)` (أحمر هادئ) |
| Badge | خلفية `errorContainer` + أيقونة `refresh` |
| Progress bar | لون `colors.error` (أحمر) |
| زر | **"إعادة التدريب"** مع أيقونة ↻ |
| Chip المتابعات | يظهر بعدد المتابعات بلون برتقالي (`highlight: true`) |

---

## 6. كيف تظهر المتابعات؟

**في Dashboard (بطاقة الهدف):**
- Chip واحد: `🔄 2 متابعات` بلون برتقالي (`highlight: true`)
- يظهر فقط إذا `followupsCount > 0`

**في Bottom Sheet (`_GoalDetails`):**
- قسم منفصل بعنوان "**المتابعات المفتوحة:**" بلون `error`
- كل متابعة في `Container` بخلفية `errorContainer` وأيقونة برتقالية ↻
- اسم المهارة المرتبطة بالـ followup

لم يتغير منطق الـ followups نفسه — فقط العرض.

---

## 7. كيف تعاملت مع الهاتف؟

**Responsive layout** عبر `LayoutBuilder` في `_GoalProgressSection`:

| عرض الشاشة | عدد الأعمدة |
|-----------|------------|
| < 500px | عمود واحد (Column) |
| 500px – 749px | عمودان (Wrap) |
| ≥ 750px | 3 أعمدة (Wrap) |

**تجنب Overflow:**
- كل `_GoalCard` داخل `SizedBox` بعرض محسوب: `(width - spacing * (columns - 1)) / columns`
- على الشاشات الضيقة (< 500px): `Column` بعرض كامل
- اسم الهدف: `maxLines: 2` + `TextOverflow.ellipsis`
- `Wrap` على الـ MiniInfoChips — تتدفق للأسفل تلقائيًا
- لا `SingleChildScrollView` داخل البطاقة (مضغوطة أصلاً)

**اختبار يدوي على 360px:**
```
Row 1: اسم (max 2 lines) + Badge = ~56px + ~30px
Row 2: Progress bar (8px) + 10px gap = 18px
Row 3: Wrap chips — تنتقل للأسفل إن ضاقت
Row 4: زر بعرض كامل = 36px
Total: ~140px لكل بطاقة
```

---

## 8. كيف تعاملت مع الويندوز؟

نفس `showModalBottomSheet` يعمل على ويندوز في Material 3:
- يظهر كلوحة من الأسفل بدلاً من منتصف الشاشة
- `DraggableScrollableSheet` يسمح بتغيير الحجم بالماوس
- `constraints.maxWidth` يضمن استخدام 2-3 أعمدة على الشاشات العريضة
- البطاقات لا تتمدد بعرض الصفحة — محدودة بـ `cardWidth` المحسوبة

---

## 9. هيكل الشاشة الجديدة

```
_GoalProgressSection (الكلاس الرئيسي)
│
├── build()
│   ├── AppCard
│   │   ├── _sectionHeader (title + icon)
│   │   ├── LayoutBuilder
│   │   │   ├── if < 500px: Column (1 عمود)
│   │   │   ├── if < 750px: Wrap (عمودان)
│   │   │   └── else: Wrap (3 أعمدة)
│   │   │       └── _GoalCard × N
│   │   │
│   └── _openRetrainPlan()  ← منطق sessionPreselect (لم يتغير)
│
├── _GoalCard (Widget)
│   ├── GestureDetector → _showGoalDetails()
│   ├── Card (borderRadius: 24, border حسب الحالة)
│   │   ├── Row 1: اسم الهدف + _StatusBadge
│   │   ├── Row 2: LinearProgressIndicator (8px)
│   │   ├── Row 3: Wrap → _MiniInfoChip × N
│   │   └── Row 4: FilledButton.tonalIcon → تدريب/إعادة
│   └── helpers: _borderColor(), _progressColor(), _lastSessionDate()
│
├── _GoalDetails (Widget — Bottom Sheet)
│   ├── Drag Handle
│   ├── اسم الهدف + _StatusBadge
│   ├── العلاج (نص كامل)
│   ├── _DetailStat × 3: آخر جلسة, الجلسات, المهارات
│   ├── LinearProgressIndicator
│   ├── قائمة المهارات (أيقونة + اسم + حالة)
│   └── قائمة المتابعات (إن وجدت)
│
├── _StatusBadge (Widget — reusable)
│   └── Container مع أيقونة + نص حسب الحالة
│
├── _MiniInfoChip (Widget — reusable)
│   └── أيقونة + نص (للإحصائيات الصغيرة)
│
└── _DetailStat (Widget — reusable)
    └── أيقونة + عنوان + قيمة (للإحصائيات في Bottom Sheet)
```

---

## 10. ماذا أزيل؟

| العنصر المحذوف | السطور | السبب |
|---------------|--------|-------|
| `_progressRow()` | 28 سطرًا | لم يعد مستخدمًا — استبدل بـ `_MiniInfoChip` |
| `_trainingButtonLabel()` | 6 أسطر | نُقل منطقها إلى `_GoalCard` مباشرة |
| `_lastSessionDate()` (في `_GoalProgressSection`) | 16 سطرًا | نُقل إلى `_GoalCard` |
| `_openRetrain(context, plan, step)` | 24 سطرًا | لم يعد مستخدمًا — كل التدريب الآن عبر `_openRetrainPlan` |
| قائمة المهارات الداخلية (steps.map) | 60 سطرًا | انتقلت إلى Bottom Sheet |
| خطة العلاج داخل البطاقة | 16 سطرًا | انتقلت إلى Bottom Sheet |
| LayoutBuilder القديم (narrow < 380) | 150 سطرًا | استبدل بـ LayoutBuilder خارجي مع Grid |
| `AppPill` في الإحصائيات | — | استبدل بـ `_MiniInfoChip` الأصغر |
| `SanadText.subtitle/secondary` | — | استبدل بنصوص مباشرة |

---

## 11. ما بقي كما هو (لم يتغير)

- ✅ `goalProgress()` في AppProvider
- ✅ `goalStatus()` في AppProvider
- ✅ `activeGoalCount` / `masteredGoalCount` في AppProvider
- ✅ فلاتر activePlans (`app.goalProgress(p.id) < 100`)
- ✅ `_MasteredGoalsSection` — لم يمس
- ✅ `_openRetrainPlan()` في `_GoalProgressSection` (logic unchanged)
- ✅ `app.preselectSession()` — لم يمس
- ✅ قاعدة البيانات — لا تغيير
- ✅ `app.sessions` — لا تغيير
- ✅ `app.pendingFollowups` — لا تغيير
- ✅ `StudentFollowup` منطق — لا تغيير
- ✅ XP — لا تغيير

---

## 12. التحقق النهائي

```
flutter analyze  → 0 errors, 0 new warnings ✅
flutter test     → 48/48 passed ✅
```
