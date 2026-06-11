# تقرير تشخيص: لماذا improvementRate = 0% رغم تحسن حرف أ

## الحالة المختبرة

| | التقييم الأول (4:24 م) | التقييم الثاني (4:26 م) |
|---|---|---|
| تماثل الوجه | مائل لليمين (ضعف) | مائل لليمين (ضعف) |
| حرف أ | إبدال (ضعف) | طبيعي |

المتوقع: improved=1, baseWeakness=2, rate=50%
الواقع: improved=0, baseWeakness=2, rate=0%

---

## السبب الجذري

**الحروف الطبيعية لا تنشئ `ClinicalFinding` أصلاً.**

الكود في `clinical_assessment_wizard_screen.dart` (حول السطر 1001):

```dart
if (isNormal) {
  strengths.add(...);      // ← فقط يضيف إلى strengths
  // لا ينشئ finding!
} else {
  findings.add(ClinicalFinding(   // ← فقط النتائج غير الطبيعية
    templateId: trigger?.id ?? '',
    isNormal: false,
    sourceType: 'speechSound',
    ...
  ));
}
```

عندما يكون حرف أ = طبيعي، **لا يُنشأ finding**. وبالتالي:

### التقييم الأول (4:24 م) — findings:
| finding | templateId | sourceType | isNormal |
|---------|-----------|------------|----------|
| تماثل الوجه = مائل لليمين | option_xxx | standard | false |
| حرف أ = إبدال | trigger_أ_إبدال_أول | speechSound | false |

### التقييم الثاني (4:26 م) — findings:
| finding | templateId | sourceType | isNormal |
|---------|-----------|------------|----------|
| تماثل الوجه = مائل لليمين | option_xxx (نفسه) | standard | false |
| *(حرف أ طبيعي → لا يوجد finding)* | — | — | — |

### ماذا يحدث في `compute()`:

`AssessmentImprovementSummary.compute()` يبني `prevByTemplate` و `currByTemplate` بمطابقة `templateId`:

```dart
// prevByTemplate (مفتاح = templateId):
'trigger_أ_إبدال_أول' → ClinicalFinding(isNormal: false)  // حرف أ
'option_xxx'          → ClinicalFinding(isNormal: false)  // تماثل الوجه

// currByTemplate (مفتاح = templateId):
'option_xxx'          → ClinicalFinding(isNormal: false)  // تماثل الوجه فقط
// لا يوجد مفتاح لـ trigger_أ_إبدال_أول لأن طبيعي لم ينشئ finding
```

ثم التكرار على `allIds`:

```dart
for (final id in allIds) {
  // id = 'trigger_أ_إبدال_أول'
  prev ≠ null (isNormal=false), curr = null
  → يدخل الفرع: else if (prev != null && curr == null)
    → missing++
    → baseWeakness++   // لأن !prev.isNormal

  // id = 'option_xxx'
  prev ≠ null (isNormal=false), curr ≠ null (isNormal=false)
  → يدخل الفرع: else if (!prev.isNormal && !curr.isNormal)
    → unchangedWeakness++
    → baseWeakness++
}
```

**النتيجة النهائية:**
- `baseWeakness` = 2 (تماثل الوجه + حرف أ)
- `improved` = 0
- `missing` = 1 (حرف أ)
- `improvementRate` = 0/2 = 0%

---

## لماذا التصنيف خطأ؟

`compute()` يصنف `(prev ≠ null, curr = null)` كـ **missing**.

لكن في الحقيقة، حرف أ لم يُفقد — تم تقييمه ووجد طبيعياً. الفرق أن الطبيعي لا يُسجل كـ `ClinicalFinding`.

**المعنى الحقيقي لـ (prev ≠ null, curr = null) لحالة weakness:**
- ✅ المهارة كانت ضعفاً سابقاً
- ✅ لم تُسجل كضعف حالي
- ✅ هذا يعني تحسناً (improved) في التقييم الحديث
- ❌ وليس فُقداناً (missing)

---

## الإجابة على الاحتمالات المطلوب فحصها

### 1. هل `templateId` لحرف "أ" مختلف بين التقييمين؟

الجواب: **لا يمكن المقارنة أصلاً.** في التقييم الثاني لا يوجد finding لحرف أ. لكن حتى لو افترضنا أن الطبيعي يُنشئ finding، فإن `templateId` لـ `SpeechSoundTriggerTemplate` مخصص فقط للحالات غير الطبيعية، ولا يوجد `templateId` يمثل "طبيعي".

### 2. هل finding الطبيعي لحرف "أ" لا يُحفظ؟

**نعم.** هذا هو السبب الجذري. الكود في `clinical_assessment_wizard_screen.dart` لا ينشئ `ClinicalFinding` للنتائج الطبيعية مطلقاً (السطور 1001-1002 فقط `strengths.add`).

### 3. هل `isNormal` معكوس؟

لا، `isNormal` يُحفظ بشكل صحيح. لكن مشكلة `compute()` أعمق: إذا كان `prev != null && curr == null`، لا يهم قيمة `isNormal` في prev — التصنيف دائماً `missing`.

### 4. هل `compute()` يقارن آخر تقييمين لكن ليسا التقييمين الظاهرين؟

لا، الترتيب صحيح. `createdAt` كامل ISO 8601 والترتيب `compareTo` يعمل بشكل صحيح على الـ timestamp الكامل.

### 5. هل `programId` مختلف؟

لا، نفس البرنامج — `selectedProgram?.id ?? ''` لكلا التقييمين.

### 6. هل تقييم الحروف يستخدم `trigger.id` في حالة الضعف لكن يستخدم قيمة مختلفة في حالة الطبيعي؟

**نعم.** الحروف الطبيعية تستخدم `option.id`؟ لا — الحروف الطبيعية **لا تستخدم أي id** ولا تنشئ finding. 

(للتوضيح: استخدام `option.id` لا ينطبق على الحروف. قسم الحروف يستخدم `SpeechSoundTriggerTemplate` وليس `AssessmentOptionTemplate`.)

### 7. هل طبيعي الحروف يُسجل بطريقة مختلفة عن طبيعي الأقسام؟

**نعم.** فرق جوهري:

| | أقسام (مثل تماثل الوجه) | حروف (مثل حرف أ) |
|---|---|---|
| طبيعي → finding | **نعم** — ينشئ finding مع `option.id` كـ templateId و `isNormal=true` | **لا** — لا ينشئ finding نهائياً |
| غير طبيعي → finding | **نعم** — ينشئ finding مع `option.id` (مختلف!) و `isNormal=false` | **نعم** — ينشئ finding مع `trigger.id` و `isNormal=false` |
| templateId للطبيعي | `option.id` (نفس option لكن generatesTherapy=false) | لا يوجد |

---

## ملخص الخلل

```
compute() يفترض أن كل templateId موجود في prev
يجب أن يكون موجوداً أيضاً في curr (أو vice versa).

هذا صحيح للأقسام لأن كل اختيار (طبيعي/غير طبيعي)
ينشئ finding مع option.id مختلف.

هذا خطأ للحروف لأن الطبيعي لا ينشئ finding أصلاً.
```

النتيجة: **أي حرف يتحسن من ضعف إلى طبيعي سيُحسب كـ "missing" وليس "improved"**، مما يخفض improvementRate بشكل غير صحيح.

---

## اقتراح الإصلاح (أقل تدخل ممكن)

```dart
// في AssessmentImprovementSummary.compute()
// الفرع: prev != null && curr == null

} else if (prev != null && curr == null) {
  if (prev.sourceType == 'speechSound' && !prev.isNormal) {
    // حرف كان ضعفاً سابقاً وغائب حالياً
    // = تحسّن (لأن الطبيعي لا ينشئ finding)
    baseWeakness++;
    improved++;
  } else if (!prev.isNormal) {
    // بقية الحالات: ضعف سابق غير موجود حالياً
    // (قد يكون تحسناً أو فُقداناً — حسب الحالة)
    // حالياً يُصنف missing. يمكن مراجعة لاحقاً.
    missing++;
    baseWeakness++;
  } else {
    missing++;
  }
}
```

التغيير: **سطر واحد فقط** — إضافة `improved++` عندما `prev.sourceType == 'speechSound' && !prev.isNormal`.

هذا آمن لأن:
- `sourceType == 'speechSound'` يضمن أننا نتعامل مع حرف وليس قسم
- الحروف تُقيّم جميعها دائماً — لا يوجد "إغفال" لفحص حرف
- إذا لم يُنشئ finding للحرف في التقييم الحالي، فهذا يعني بالضرورة أنه طبيعي

### تنبيه: مشكلة مماثلة للأقسام

هذا الإصلاح لا يعالج حالة قسم يتحسن من "غير طبيعي" (option_A, generatesTherapy=true) إلى "طبيعي" (option_B, generatesTherapy=false). في هذه الحالة، option_A و option_B لهما `id` مختلفان، لذا `compute()` يراهما كـ item منفصلين:
- option_A → missing (prev فقط)
- option_B → newFinding (curr فقط)

لمعالجة هذا كاملاً، يحتاج `compute()` إلى ربط options بنفس الـ `itemId` أو `itemTitle`. لكن هذا خارج نطاق الإصلاح الأقل خطورة حالياً.
