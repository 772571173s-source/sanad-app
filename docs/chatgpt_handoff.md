# سند (Sanad) — ChatGPT Handoff Document

> أنسخ هذا الملف وأرسله لأي ChatGPT جديد ليفهم المشروع فوراً.

---

## 1. ما هو سند؟

**سند** هو تطبيق Flutter (Android + Windows) لإدارة التأهيل والتدخل المبكر لاضطرابات النطق والتخاطب. يعمل **كلياً على الجهاز** (SQLite محلي، لا backend).

**المستخدمون:** أخصائي نطق، ولي أمر، مدير مركز، منسق، مدخل بيانات.

**اللغة:** العربية (RTL).

---

## 2. المرحلة الحالية

- ✅ **التقييم العلاجي**: يعمل — ينشئ أهدافاً ومهارات تلقائياً من نتائج التقييم.
- ✅ **الجلسات العلاجية**: تعمل — تقييم ثلاثي الأزرار (متقن/بمساعدة/يحتاج إعادة) مع تقدم تلقائي.
- ✅ **المتابعات**: تعمل — إنشاء وإغلاق وإعادة تدريب للمهارات.
- ✅ **الواجبات المنزلية**: تعمل — يرسلها الأخصائي، يؤديها ولي الأمر، يراجعها الأخصائي.
- ✅ **ملف الطالب**: يعرض كل شيء (2959 سطر، 37 كلاس).
- ✅ **لوحة الأخصائي**: مؤشرات أداء مُصلحة.
- ✅ **بنّاء الهيكل العلاجي**: لبناء قوالب التقييم والبرامج.
- ✅ **49 اختباراً** — جميعها ناجحة.
- ✅ **`flutter analyze`**: 0 errors، 0 warnings.
- ⚠️ **مشكلة معروفة**: حساب التحسن بين التقييمات لا يعمل للحروف (انظر §7).

---

## 3. القرارات المعمارية المعتمدة

| القرار | التفاصيل |
|--------|----------|
| **Provider مفرد** | `AppProvider` (2025 سطر) — ChangeNotifier واحد لكل المنطق |
| **SQLite محلي** | لا backend، لا API، لا خادم |
| **الهدف = وحدة العلاج** | `TrainingPlan` هو وحدة التقارير والعلاج، وليس `GoalSkillStep` |
| **`goalProgress()` = مصدر واحد** | كل المؤشرات تستخدمه، لا `plan.progress` |
| **`AssessmentImprovementSummary` = وحيد للتحسن** | مستقل عن الجلسات والأهداف |
| **`templateId` للعلاج فقط** | وليس لمقارنة التحسن |
| **جميع التواريخ ISO 8601** | `DateTime.now().toIso8601String()` |
| **`ensureLatestSchema()`** | شبكة أمان عند كل تشغيل |
| **برنامج علاجي للطالب** | عبر `StudentTherapyProgram` |
| **ثلاثة أزرار تقييم** | متقن / بمساعدة / يحتاج إعادة |
| **تقييم حرف بحرف** | لا تقييم جماعي للحروف |

---

## 4. ما الذي تم الانتهاء منه

- التقييم العلاجي الكامل (أقسام + حروف + حفظ مسودة)
- توليد الأهداف والمهارات تلقائياً
- الجلسات العلاجية مع auto-advance و auto-homework
- المتابعات (إنشاء + إغلاق + إعادة تدريب)
- الواجبات المنزلية (ولي أمر ← أخصائي)
- ملف الطالب (11 قسماً)
- لوحة الأخصائي (مؤشرات مُصلحة)
- مقارنة التحسن بين التقييمات (موجود لكن فيه مشكلة)
- بنّاء الهيكل العلاجي
- 8 أدوار مستخدم
- نظام XP
- تقارير PDF
- عرض الوقت بجانب التاريخ (`_formatDateTime`)
- 49 اختباراً (CRUD + goalProgress + AssessmentImprovement + widget)

---

## 5. ما الذي تم تأجيله

- إصلاح مقارنة التحسن (موثّق، في انتظار الموافقة)
- تقسيم `AppProvider` (تحسين معماري، ليس ضرورياً عاجلاً)
- اختبارات UI/Flow الكامل
- تحسين `selectStudent()` (يعيد تحميل كل شيء)
- iOS support (لا sqflite)
- نظام إشعارات (غير مستخدم)

---

## 6. كيف يعمل التقييم العلاجي

**الملف:** `clinical_assessment_wizard_screen.dart` (3386 سطر — الأكثر تعقيداً).

1. الأخصائي يختار طالباً ← برنامجاً علاجياً
2. **مرحلة الأقسام:** بنود تقييم (مثل "تماثل الوجه") مع خيارات (مفرد/متعدد)
   - الخيار المفرد: يختار option واحد (طبيعي / غير طبيعي)
   - الخيار المتعدد: يضغط "نعم طبيعي" / "لا يحتاج تدخل" لكل option
3. **مرحلة الحروف:** إن كان البرنامج `usesSpeechSounds == true`
   - كل حرف يُقيّم على حدة
   - يضغط "طبيعي" أو يختار نوع خطأ + موضع
4. عند الحفظ:
   - ينشئ `ClinicalAssessment`
   - ينشئ `ClinicalFinding` لكل بند
   - **للحروف الطبيعية: لا ينشئ finding** (فقط `strengths.add()`) ← هذه مشكلة
   - لكل finding غير طبيعي: ينشئ `TrainingPlan` (هدف) + `GoalSkillStep` (مهارات)
5. `templateId` في finding:
   - للأقسام: `AssessmentOptionTemplate.id` (يختلف بين الطبيعي وغير الطبيعي!)
   - للحروف: `SpeechSoundTriggerTemplate.id` (فقط للحالات غير الطبيعية)

---

## 7. كيف يعمل التحسن بين التقييمات (وما المشكلة)

**الملف:** `lib/models/assessment_improvement_summary.dart`

**المنطق الحالي:**
- يأخذ آخر تقييمين للطالب
- يبني `Map<templateId, ClinicalFinding>` لكل تقييم
- يقارن: هل نفس templateId تحسّن؟ تراجع؟ بقي؟ فُقد؟ جديد؟
- `improvementRate = improved / baseWeakness * 100`

**المشكلة:**
1. **للحروف:** الطبيعي لا ينشئ finding → التقييم الثاني لا يحتوي finding للحرف → يُحسب `missing` وليس `improved`
2. **للأقسام:** الطبيعي وغير الطبيعي لهما `templateId` مختلفان → لا يتطابقان → يُحسب `missing + newFinding`

**مثال:** حرف أ: ضعف في التقييم الأول، طبيعي في الثاني → `improvementRate = 0%` (يجب أن يكون 50%).

**الحل المقترح (في انتظار الموافقة):**
1. تغيير `itemTitle` للحروف من `'حرف أ - إبدال - أول'` إلى `'حرف أ'`
2. إنشاء finding للحروف الطبيعية (بـ `isNormal=true`)
3. تغيير مفتاح المطابقة في `compute()` من `templateId` → `itemTitle`

**انظر:** `docs/analysis/comparison_key_redesign.md`

---

## 8. كيف تعمل الجلسات

**الملف:** `sessions_screen.dart` (~1050 سطر)

1. الأخصائي يختار: الطالب ← البرنامج ← نوع المصدر (standard/speechSound)
2. `_findCurrent()` يبحث عن أول مهارة غير متقنة في الأهداف غير المتقنة
3. ثلاثة أزرار تقييم:
   - **متقن** → `successRate = 100`, `quickResult = 'متقن'`, يغلق المتابعة إن وجدت
   - **بمساعدة** → `successRate = 60`, `quickResult = 'بمساعدة'`, ينشئ متابعة + واجب
   - **يحتاج إعادة** → `successRate = 20`, `quickResult = 'يحتاج إعادة'`, ينشئ متابعة + واجب
4. `goalProgress()` للهدف = نسبة المهارات المتقنة (أو آخر جلسة إن لم توجد مهارات)
5. `goalStatus()` = متقن / يحتاج إعادة / يحتاج مساعدة / قيد العلاج / جديد

---

## 9. كيف تعمل المتابعات

**الجدول:** `student_followups`

- **إنشاء:** عند تقييم مهارة بـ "بمساعدة" أو "يحتاج إعادة" ← `upsertFollowup(reason)`
- **إغلاق:** عند تقييم نفس المهارة بـ "متقن" ← `resolveFollowupForStep(studentId, stepId)`
- **عرض:** في ملف الطالب (`_FollowupsSection`) مع زر "إعادة التدريب"
- **إعادة التدريب:** زر ← `preselectSession()` ← ينتقل للجلسات ← يفتح المهارة مباشرة

الحقول: `studentId`, `specialistId`, `programId`, `planId`, `goalSkillStepId`, `reason` (assisted/retry), `status` (pending/completed).

---

## 10. كيف يعمل ملف الطالب

**الملف:** `student_profile_screen.dart` (2959 سطر، 37 كلاس/دالة)

**أقسام الشاشة (للمتخصص):**
| القسم | الكلاس |
|-------|--------|
| Header + إحصائيات | `StudentHeaderCard` |
| التقييم العلاجي (آخر 3) | `_ClinicalAssessmentProfileSection` |
| **التحسن بين التقييمات** | **`_ImprovementSummaryCard`** (جديد) |
| الأهداف مع progress | `_GoalProgressSection` ← `_GoalCard` |
| الأهداف المتقنة | `_MasteredGoalsSection` (جديد) |
| الجلسات السابقة | `_PreviousSessions` ← `_SessionTile` |
| المتابعات + إعادة تدريب | `_FollowupsSection` ← `_FollowupTile` (جديد) |
| الواجبات | `_HomeworkTile` |
| التقارير | `_ReportsFromProfile` |
| الخط الزمني | `_Timeline` |

**شاشة ولي الأمر (منفصلة):** `_ParentStudentProfile` — header + تمارين + جلسات + ملاحظات.

**عرض الوقت:** دالة `_formatDateTime()` تحوّل ISO 8601 إلى `DD-MM-YYYY — HH:MM ص/م`.

---

## 11. كيف تعمل لوحة الأخصائي

**الملف:** `specialist_dashboard_screen.dart` (705 سطر)

| المؤشر | المصدر |
|--------|--------|
| عدد الطلاب | `students` (مفلترة) |
| يحتاج تقييم | `studentsNeedingAssessment` |
| متوسط تقدم أهداف طلابي | `centerGoalImprovementRate` ← `goalProgress()` |
| أهداف نشطة | `centerPlans` حيث `goalProgress() < 100` |
| أهداف متقنة | `centerPlans` حيث `goalProgress() >= 100` |
| كل طالب مع إحصائياته | `studentGoalAverageProgress()` + `goalProgress()` لكل هدف |

**ملاحظة:** أُعيدت تسمية `studentGoalImprovementRate` → `studentGoalAverageProgress`. التسمية الصحيحة "متوسط تقدم أهداف طلابي" وليست "نسبة التحسن".

---

## 12. ما الذي لا يجب تغييره

| لا تغيّر | السبب |
|----------|-------|
| `templateId` | مطلوب لربط findings بالعلاج (SkillStepTemplate) |
| `sourceType` أو `programId` | مفاتيح الربط بين التقييم ← الخطط ← الجلسات |
| `plan.progress` في DB | `goalProgress()` هو المصدر الوحيد، `syncGoalProgress()` يحفظ نسخة فقط |
| منطق `AssessmentImprovementSummary` | إلا بعد الموافقة على التصميم الجديد |
| `XP` / `SessionSkillResult` | ليس له علاقة بالمؤشرات الحالية |
| `PDF Reports` | مستقل تماماً |
| ربط الواجبات بالجلسات تلقائياً | الواجبات تُنشأ فقط من شاشة الواجبات |
| قاعدة البيانات ← خادم | التطبيق محلي 100% |
| `Expanded` داخل `Column` داخل `SingleChildScrollView` | يسبب `RenderFlex unbounded constraints` ← شاشة بيضاء |

---

## 13. المشاكل المفتوحة

**P1 — حرجة:**
1. **مقارنة التحسن لا تعمل** للحروف (والأقسام في حال تغير option من ضعف إلى طبيعي). الإصلاح مقترح لكن لم يُنفذ بعد.

**P2 — متوسطة:**
2. `selectStudent()` تعيد تحميل كل شيء حتى بعد تغيير بسيط.
3. معالج التقييم معقد جداً (3386 سطر).
4. لا فصل بين UI والمنطق في StatefulWidgets.

**P3 — منخفضة:**
5. `notification_service.dart` غير مستخدم.
6. اختبارات غير كافية (لا UI tests).
7. Schema divergence محتملة بين Windows و Android عند التثبيت القديم.

---

## 14. الأولويات القادمة

| # | المهمة | التعقيد |
|---|--------|---------|
| 1 | إصلاح مقارنة التحسن (comparisonKey) | متوسط |
| 2 | إضافة اختبارات للتحسن بعد الإصلاح | سهل |
| 3 | تحسين `selectStudent()` | صعب |
| 4 | إعادة هيكلة معالج التقييم | صعب |
| 5 | إضافة اختبارات UI | متوسط |
| 6 | تقسيم `AppProvider` | صعب جداً |

---

## 15. آخر التعديلات المهمة

| التاريخ | التعديل |
|---------|---------|
| 11-06-2026 | إنشاء `_formatDateTime()` — عرض الوقت بجانب التاريخ في ملف الطالب |
| 11-06-2026 | تشخيص مشكلة التحسن بين التقييمات (سببها: الحروف الطبيعية لا تنشئ findings) |
| 11-06-2026 | تصميم comparisonKey (إصلاح مقترح في `docs/analysis/comparison_key_redesign.md`) |
| قبلها | `centerGoalImprovementRate` ← `goalProgress()` بدلاً من `plan.progress` |
| قبلها | `studentGoalImprovementRate` ← `studentGoalAverageProgress` (إعادة تسمية) |
| قبلها | لوحة الأخصائي: "نسبة التحسن" ← "متوسط تقدم أهداف طلابي" |
| قبلها | إضافة `_ImprovementSummaryCard` في ملف الطالب |
| قبلها | جميع الأخطاء في `flutter analyze` (744 → 0) (سببها `}` ناقص) |

---

## 16. الملفات الأكثر أهمية

| الملف | الأسطر | لماذا هو مهم |
|-------|--------|-------------|
| `lib/providers/app_provider.dart` | 2025 | كل منطق التطبيق |
| `lib/models/app_models.dart` | 1816 | 30 كلاس |
| `lib/models/assessment_improvement_summary.dart` | 121 | حساب التحسن بين التقييمات |
| `lib/services/database_service.dart` | 1867 | Schema v31, 26 جدول |
| `lib/repositories/sanad_repository.dart` | 744 | CRUD |
| `lib/screens/clinical_assessment_wizard_screen.dart` | 3386 | معالج التقييم |
| `lib/screens/student_profile_screen.dart` | 2959 | ملف الطالب |
| `lib/screens/sessions_screen.dart` | ~1050 | الجلسات |
| `lib/screens/specialist_dashboard_screen.dart` | 705 | لوحة الأخصائي |
| `docs/analysis/comparison_key_redesign.md` | — | التصميم المقترح لإصلاح التحسن |
| `docs/project_master_reference.md` | — | المرجع المعماري الشامل |

---

## 17. معلومات سريعة للمطور الجديد

### هيكل المشروع
```
lib/
├── main.dart
├── models/app_models.dart           ← كل النماذج
├── models/assessment_improvement_summary.dart
├── providers/app_provider.dart      ← كل المنطق
├── repositories/sanad_repository.dart
├── services/database_service.dart   ← Schema + Migrations
├── screens/                         ← ~31 شاشة
├── widgets/app_widgets.dart
└── widgets/feedback.dart
test/
├── assessment_improvement_test.dart  ← 7 اختبارات
├── goal_progress_logic_test.dart     ← 8 اختبارات
├── crud_integration_test.dart        ← 42 اختباراً
└── widget_test.dart                  ← اختبار 1
```

### أوامر مهمة
```bash
flutter analyze          # 0 errors, 0 warnings
flutter test             # 49/49 ✅
flutter run -d windows   # تشغيل على Windows
flutter run              # تشغيل على Android (جهاز متصل)
```

### قواعد أساسية
1. **شغّل `flutter analyze && flutter test` دائماً** قبل أي commit.
2. كل الـ migrations **إضافية فقط** (لا حذف أعمدة).
3. `goalProgress()` = مصدر الحقيقة للـ progress، وليس `plan.progress`.
4. `AssessmentImprovementSummary` = مصدر الحقيقة للتحسن، وليس الجلسات.
5. `templateId` = للعلاج فقط. لمقارنة التحسن، استخدم `itemTitle`.
6. التواريخ دائماً ISO 8601: `DateTime.now().toIso8601String()`.
7. `Expanded` + `SingleChildScrollView` = شاشة بيضاء. لا تفعلها.

### إذا بدأت من الصفر اليوم

1. اقرأ `docs/project_master_reference.md` (المرجع المعماري الشامل).
2. اقرأ `docs/analysis/comparison_key_redesign.md` (أهم مشكلة مفتوحة).
3. ركّز على `assessment_improvement_summary.dart` (المشكلة الأكثر إلحاحاً).
4. لا تلمس `app_models.dart` أو `database_service.dart` دون فهم كامل للتأثير.
5. اختبر على Android أولاً، ثم Windows.

---

> **Project Snapshot — June 2026**  
> أرسل هذا الملف لأي ChatGPT جديد لاستيعاب المشروع خلال دقائق.
