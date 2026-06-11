# تصميم comparisonKey لحساب التحسن بين التقييمات

## المشكلة

`AssessmentImprovementSummary.compute()` يطابق findings بين تقييمين باستخدام `templateId`. لكن:

| الحالة | templateId | المشكلة |
|--------|-----------|---------|
| قسم: ضعف ← ضعف (نفس الخيار) | option.id (نفسه) | ✅ يعمل |
| قسم: ضعف ← طبيعي | option_ضعف.id ≠ option_طبيعي.id | ❌ لا يتطابق |
| حرف: ضعف ← طبيعي | trigger.id (موجود في السابق فقط) | ❌ لا يوجد finding في الحالي |
| حرف: ضعف ← ضعف (نوع خطأ مختلف) | trigger.id1 ≠ trigger.id2 | ❌ لا يتطابق |

**السبب الجذري:** `templateId` يعرّف **الخيار العلاجي** وليس **بند التقييم**. بينما نحتاج لمقارنة نفس بند التقييم عبر زمنين.

---

## 1. ما أفضل comparisonKey؟

### المعيار المطلوب
- **ثابت**: نفس القيمة لكل تقييمات نفس البند، بغض النظر عن الخيار المختار
- **شامل**: يغطي الأقسام والحروف معاً
- **قابل للحساب**: بدون تغيير كبير في البنية

### بند التقييم = ما هو الشيء الذي نقيم تغيره؟

بند التقييم في النظام نوعان:

#### أ. بند قسم: يمثله `AssessmentItemTemplate`
- له `id` ثابت (UUID)
- له `title` ثابت (مثل "تماثل الوجه")
- الخيارات المختلفة تنتمي لنفس البند عبر `option.itemId == item.id`

**comparisonKey للمقترح:** `item.id` (أو `itemTemplateId`)

#### ب. بند حرف: يمثله الحرف نفسه
- الحرف `'أ'` هو الثابت — بغض النظر عن نوع الخطأ أو موضعه
- `SpeechSoundTriggerTemplate.letter` يحدد الحرف

**comparisonKey للمقترح:** `'speechSound:$letter'` (مثل `'speechSound:أ'`)

### الجدول النهائي للمقارنة

| البند | comparisonKey | ثابت؟ | مثال |
|-------|---------------|-------|------|
| قسم | `itemTemplateId` (AssessmentItemTemplate.id) | ✅ | `'item_uuid_123'` |
| قسم (بديل) | `section + ':' + itemTitle` | ✅ (بافتراض titles فريدة) | `'الوجه:تماثل الوجه'` |
| حرف | `'speechSound:$letter'` | ✅ | `'speechSound:أ'` |
| legacy (بدون key) | templateId (fallback) | ❌ لكن أفضل ما لدينا | `'option_uuid_abc'` |

---

## 2. هل نحتاج field جديد في ClinicalFinding؟

### الخيارات

#### الخيار A: إضافة `itemTemplateId` (حقل جديد في DB)
```dart
final String itemTemplateId;  // في ClinicalFinding
```
- **للأقسام**: `AssessmentItemTemplate.id` (المتاح من `item.id` أثناء الحفظ)
- **للحروف**: `'speechSound:$letter'` (يُحتسب من `trigger.letter`)

**الإيجابيات:**
- صريح وواضح
- مفهرس يمكن الاستعلام به
- لا يعتمد على تنسيق نصي متغير

**السلبيات:**
- يحتاج migration (عمود جديد في `clinical_findings`)
- يحتاج تعبئة أثناء الحفظ (في 4 أماكن)
- البيانات القديمة لا تحتويه → fallback مطلوب

#### الخيار B: استخدام `itemTitle` كـ comparisonKey (حساب runtime)
- **للأقسام**: `item.title` ثابت بالفعل ✅
- **للحروف**: حالياً `'حرف $letter - $errorType - $position'` ← يحتاج تغيير إلى `'حرف $letter'`

**الإيجابيات:**
- لا يحتاج حقل جديد
- لا يحتاج migration
- يعمل مع البيانات الحالية (للأقسام فوراً)

**السلبيات:**
- للحروف: تغيير تنسيق `itemTitle` يؤثر على عرض `weaknessSummary` (`'${f.itemTitle}: ${f.weakness}'`)
- `itemTitle` ليس guaranteed ليكون unique لكل المقيمين (لكن عملياً هو unique داخل نفس التقييم)

#### الخيار C: خريطة ثنائية المستوى (templateId → itemId/letter) في compute()
بدلاً من تغيير البيانات، نضيف دالة في `compute()` تحوّل templateId إلى comparisonKey عبر query of templates:

```dart
// البحث عن AssessmentOptionTemplate من templateId
final option = assessmentOptions.firstWhere(
  (o) => o.id == templateId, orElse: null);
if (option != null) return option.itemId; // ← itemTemplateId

// البحث عن SpeechSoundTriggerTemplate من templateId
final trigger = speechSoundTriggers.firstWhere(
  (t) => t.id == templateId, orElse: null);
if (trigger != null) return 'speechSound:${trigger.letter}';
```

**الإيجابيات:**
- لا تغيير في البيانات (لا migration)
- يعمل مع البيانات الحالية فوراً

**السلبيات:**
- يحتاج تغيير توقيع `compute()` لاستقبال `assessmentOptions` و `speechSoundTriggers`
- للحروف الطبيعية (لا يوجد finding) لا زلنا بحاجة لإنشاء finding
- أداء Query في runtime

### التوصية: الخيار A + B معاً

**للأقسام:** استخدام `itemTitle` كـ comparisonKey (لا تغيير مطلوب، `item.title` ثابت)
**للحروف:** 
1. تغيير `itemTitle` من `'حرف $letter - $errorType - $position'` إلى `'حرف $letter'`
2. إنشاء finding للحروف الطبيعية أيضاً

مع الاحتفاظ بـ `templateId` للعلاج كما هو.

---

## 3. هل يمكن حسابه runtime؟

نعم. يمكن حساب comparisonKey في `compute()` بدون حقل جديد:

### للقسم: `itemTitle` جاهز
```
comparisonKey = f.itemTitle  // ثابت لجميع خيارات نفس البند
```

### للحرف: extract من itemTitle
```
comparisonKey = 'حرف أ'  // strip '- $errorType - $position'
```
أو إذا بقيت itemTitle كما هي، نستخرج الحرف:
```dart
String _comparisonKey(ClinicalFinding f) {
  if (f.sourceType == 'speechSound') {
    // itemTitle = 'حرف أ - إبدال - أول'
    final letterMatch = RegExp(r'حرف (\S)').firstMatch(f.itemTitle);
    if (letterMatch != null) return 'حرف ${letterMatch.group(1)}';
  }
  return f.itemTitle; // للأقسام
}
```

### للحرف الطبيعي (لا finding موجود):
إذا لم ننشئ finding للطبيعي، فلا يوجد comparisonKey للمطابقة. **الحل الوحيد: إنشاء finding للطبيعي.**

---

## 4. كيف نجعل `ضعف → طبيعي = improved`؟

### الشرط المطلوب:
```
if (prev.comparisonKey == curr.comparisonKey) {
  // نفس البند
  if (!prev.isNormal && curr.isNormal) {
    improved++;  // ضعف سابق ← طبيعي حالي = تحسن
  }
}
```

### لكي يتحقق هذا، يجب أن:
1. **نفس comparisonKey** موجود في كلا التقييمين (لذا normal findings يجب أن تنشأ)
2. `prev.isNormal == false`
3. `curr.isNormal == true`

### الحالة: حرف أ (ضعف ← طبيعي)
```
prev: comparisonKey='حرف أ', isNormal=false
curr: comparisonKey='حرف أ', isNormal=true  // ← يجب إنشاء finding!
```
→ يدخل الفرع `!prev.isNormal && curr.isNormal` → `improved++`

### الحالة: قسم تماثل الوجه (ضعف ← طبيعي)
```
prev: comparisonKey='تماثل الوجه', isNormal=false
curr: comparisonKey='تماثل الوجه', isNormal=true  // موجود مسبقاً، option آخر
```
→ يدخل الفرع `!prev.isNormal && curr.isNormal` → `improved++`

---

## 5. كيف نعالج الأقسام والحروف معاً؟

### الخطة النهائية

#### التغيير 1: تغيير `itemTitle` للحروف (في wizard)

```
قبل:  'حرف $letter - $errorType - $position'
بعد:  'حرف $letter'
```
خطورة التغيير على `weaknessSummary`: سابقاً `'حرف أ - إبدال - أول: إبدال في أول الكلمة'`، بعد التغيير `'حرف أ: إبدال في أول الكلمة'` — الفرق ضئيل والمعلومة في `weakness` كافية.

#### التغيير 2: إنشاء finding للحروف الطبيعية (في wizard)

إضافة `findings.add()` في فرع `if (isNormal)`:

```dart
if (isNormal) {
  strengths.add('$domain - حرف $letter - طبيعي');
  findings.add(ClinicalFinding(
    id: 'finding_letter_${letter}_${DateTime.now().microsecondsSinceEpoch}',
    assessmentId: assessmentId,
    centerId: student.centerId,
    studentId: student.id,
    domain: domain,
    itemTitle: 'حرف $letter',
    result: 'طبيعي',
    isNormal: true,
    weakness: '',
    goal: '',
    training: '',
    programId: selectedProgram?.id ?? '',
    sourceType: 'speechSound',
    templateId: '',     // أو null — لا يوجد template للعلاج
    createdAt: now,
  ));
}
```

**لماذا `templateId: ''`؟** لأن الحرف الطبيعي لا يحتاج علاجاً. `_skillStepTemplatesForFinding` ستتخطاه لأن `templateId` فارغ. لا ضرر.

#### التغيير 3: تبديل المطابقة في `compute()` من `templateId` إلى `itemTitle`

```dart
// قبل: مطابقة بـ templateId
final prevByTemplate = <String, ClinicalFinding>{};
for (final f in prevFindings) {
  if (f.templateId.isNotEmpty) {
    prevByTemplate[f.templateId] = f;
  }
}
final currByTemplate = <String, ClinicalFinding>{};
for (final f in currFindings) {
  if (f.templateId.isNotEmpty) {
    currByTemplate[f.templateId] = f;
  }
}

// بعد: مطابقة بـ itemTitle (comparisonKey)
String _key(ClinicalFinding f) {
  if (f.sourceType == 'speechSound') {
    // استخراج 'حرف أ' من itemTitle
    final m = RegExp(r'حرف \S').firstMatch(f.itemTitle);
    if (m != null) return m.group(0)!;
  }
  return f.itemTitle;
}

final prevByKey = <String, ClinicalFinding>{};
for (final f in prevFindings) {
  final key = _key(f);
  if (key.isNotEmpty) prevByKey[key] = f;
}
final currByKey = <String, ClinicalFinding>{};
for (final f in currFindings) {
  final key = _key(f);
  if (key.isNotEmpty) currByKey[key] = f;
}

// ثم allIds = {...prevByKey.keys, ...currByKey.keys}
// ونفس منطق التصنيف (prev vs curr isNormal)
```

#### التغيير 4: لا حاجة لتغيير منطق التصنيف نفسه

الفرع `prev != null && curr == null` سيبقى للحالات النادرة (وجدنا قيماً في السابق لكن لا شيء يقابله في الحالي — إما حذف فعلي أو حرف طبيعي لم يتم تخزينه لسبب ما).

---

## ملخص الفرق بين الآلية الحالية والمقترحة

| | حالي | مقترح |
|---|---|---|
| **مفتاح المطابقة** | `templateId` (يعرّف الخيار) | `itemTitle` (يعرّف البند) |
| **حرف طبيعي → finding** | لا ينشئ | ينشئ finding مع `isNormal=true` |
| **حرف itemTitle** | `'حرف أ - إبدال - أول'` | `'حرف أ'` |
| **قسم ضعف ← طبيعي** | `missing` (خطأ) | `improved` (صحيح) |
| **حرف ضعف ← طبيعي** | `missing` (خطأ) | `improved` (صحيح) |
| **حرف ضعف ← ضعف (نوع خطأ مختلف)** | `missing` + `newFinding` (خطأ) | `unchangedWeakness` (صحيح) |
| **templateId** | يُستخدم للعلاج والمقارنة | للعلاج فقط (لم يتأثر) |

## ملفات التأثير

| الملف | التغيير |
|-------|---------|
| `clinical_assessment_wizard_screen.dart:1001-1002` | إضافة `findings.add()` للحروف الطبيعية |
| `clinical_assessment_wizard_screen.dart:1030` | تغيير `itemTitle` للحروف إلى `'حرف $letter'` |
| `assessment_improvement_summary.dart:54-67` | تبديل `templateId` → `itemTitle` في `prevByKey`/`currByKey` مع دالة مساعدة `_key()` |
| `assessment_improvement_summary.dart` | لا تغيير في منطق التصنيف (77-101) |
| `student_profile_screen.dart` | لا تغيير (لأن itemTitle فقط ما يتغير عرضياً في weaknessesSummary) |

## لا يتأثر

- `templateId` — يبقى للعلاج والـ skill steps
- `SpeechSoundTriggerTemplate` — لم يتغير
- `AssessmentItemTemplate` / `AssessmentOptionTemplate` — لم يتغير
- `AppProvider` — فقط إضافة optional parameters إلى استدعاء compute() إن لزم
- قاعدة البيانات — لا migration (للخيار B). مع الخيار A نحتاج عمود `item_template_id`.
- PDF Reports — لا تغيير
- XP — لا تغيير
