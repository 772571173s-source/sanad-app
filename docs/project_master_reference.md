# سند (Sanad) — المرجع المعماري الشامل

> **إصدار الوثيقة:** يونيو 2026  
> **آخر تحديث:** 11-06-2026  
> **الغرض:** المرجع الرسمي الوحيد للمشروع عند العودة بعد فترة طويلة.

---

## فهرس المحتويات

1. [الرؤية العامة](#1-الرؤية-العامة)
2. [الأدوار والصلاحيات](#2-الأدوار-والصلاحيات)
3. [الهيكل المعماري](#3-الهيكل-المعماري)
4. [مخطط تدفق النظام](#4-مخطط-تدفق-النظام)
5. [قاعدة البيانات (Database)](#5-قاعدة-البيانات-database)
6. [النماذج (Models)](#6-النماذج-models)
7. [المزوّد (Provider)](#7-المزوّد-provider)
8. [الشاشات (Screens)](#8-الشاشات-screens)
9. [التقييم العلاجي](#9-التقييم-العلاجي)
10. [الأهداف العلاجية](#10-الأهداف-العلاجية)
11. [المهارات (GoalSkillStep)](#11-المهارات-goalskillstep)
12. [الجلسات](#12-الجلسات)
13. [المتابعات (Followups)](#13-المتابعات-followups)
14. [ملف الطالب](#14-ملف-الطالب)
15. [لوحة الأخصائي](#15-لوحة-الأخصائي)
16. [التحسن بين التقييمات](#16-التحسن-بين-التقييمات)
17. [القرارات المعمارية النهائية](#17-القرارات-المعمارية-النهائية)
18. [المشاكل المفتوحة](#18-المشاكل-المفتوحة)
19. [خطة العمل القادمة](#19-خطة-العمل-القادمة)
20. [آخر حالة للمشروع (Project Snapshot)](#20-آخر-حالة-للمشروع-project-snapshot)

---

## 1. الرؤية العامة

### ما هو سند؟

**سند (Sanad)** هو نظام متكامل لإدارة التأهيل والتدخل المبكر لاضطرابات النطق والتخاطب. يوفّر بيئة رقمية للأخصائيين وأولياء الأمور والمراكز لمتابعة التقييم والعلاج والتقدم.

### من المستخدمون؟

| المستخدم | الدور في النظام |
|----------|----------------|
| **الأخصائي** | يجري التقييمات، يدير الجلسات، يتابع التمارين المنزلية |
| **ولي الأمر** | يشاهد ملف الطالب، يؤدي التمارين المنزلية، يتابع التقارير |
| **مدير المركز** | يدير الموظفين والطلاب والبرامج العلاجية |
| **المشرف الفني** | يشرف على الهياكل العلاجية والتقارير |
| **المنسق** | يوزع الطلاب على الأخصائيين |
| **المالك (Owner)** | يملك النظام، يدير المراكز |
| **مدخل بيانات** | إدخال بيانات الطلاب الأساسية |

### ما المشكلة التي يحلها؟

قبل سند، كانت مراكز التأهيل تعتمد على:
- السجلات الورقية (تضيع مع الوقت)
- متابعة يدوية (يصعب تتبع تقدم الطالب)
- لا يوجد تكامل بين التقييم والعلاج والتقارير
- لا يوجد نظام للمتابعات المنزلية
- لا يوجد طريقة موحدة لقياس التحسن

سند يوفّر:
- تقييم علاجي رقمي → يولد أهدافاً ومهارات تلقائياً
- جلسات علاجية مع تقييم ثلاثي الأزرار (متقن / بمساعدة / يحتاج إعادة)
- واجبات منزلية متصلة بالمهارات
- متابعات للمهارات التي تحتاج إعادة تدريب
- مؤشرات أداء (متوسط تقدم الأهداف، تحسن بين التقييمات)
- تقارير PDF

---

## 2. الأدوار والصلاحيات

### قائمة الأدوار

| الدور | الكود | المستوى |
|-------|-------|---------|
| مالك النظام | `sanadOwner` | 0 (أعلى) |
| مدير مركز | `centerManager` | 1 |
| مشرف فني | `clinicalSupervisor` | 2 |
| مدخل الهيكل | `therapyProgramEntry` | 3 |
| منسق | `coordinator` | 4 |
| أخصائي | `specialist` | 5 |
| مدخل بيانات | `dataEntry` | 6 |
| ولي أمر | `parent` | 7 |

### الصلاحيات الأساسية

| الصلاحية | الأدوار التي تملكها |
|----------|---------------------|
| إنشاء/تعديل مركز | `sanadOwner` |
| إدارة الموظفين | `sanadOwner`, `centerManager` |
| إدارة الهيكل العلاجي | `therapyProgramEntry`, `sanadOwner` |
| تقييم علاجي | `specialist` |
| جلسات علاجية | `specialist` |
| متابعة ولي الأمر | `parent` |

### مبدأ الفلترة

- الأخصائي يرى فقط الطلاب المرتبطين به عبر `StudentSpecialist`
- الجلسات تُفلتر عبر `TherapySession.specialistId`
- البرامج العلاجية تُفلتر عبر `StudentTherapyProgram`
- ولي الأمر يرى طفله فقط (via `user.studentId`)

---

## 3. الهيكل المعماري

### الطبقات

```
┌──────────────────────────────────────────────────────┐
│                   UI (Screens)                        │
│  student_profile_screen.dart (2959 سطر)               │
│  clinical_assessment_wizard_screen.dart (3386 سطر)    │
│  sessions_screen.dart (1050 سطر)                      │
│  specialist_dashboard_screen.dart (705 سطر)           │
│  ... (إجمالي ~31 شاشة)                                │
├──────────────────────────────────────────────────────┤
│              State Management (Provider)               │
│  AppProvider (ChangeNotifier, ملف واحد: 2025 سطر)     │
│  يحتوي على:                                            │
│  - كل منطق التطبيق                                     │
│  - التحميل والحفظ                                      │
│  - حساب المؤشرات (goalProgress, goalStatus, ...)      │
│  - الصلاحيات                                           │
├──────────────────────────────────────────────────────┤
│              Repository Layer                          │
│  SanadRepository (~744 سطر)                            │
│  - CRUD مباشر لكل جدول                                 │
│  - استعلامات مركبة (plansForProgram, etc.)             │
├──────────────────────────────────────────────────────┤
│              Services Layer                             │
│  DatabaseService (1867 سطر)                             │
│  - Schema (26 جدول)                                     │
│  - Migrations (v1→v31)                                 │
│  - ensureLatestSchema (startup safety net)             │
│                                                        │
│  AuthService                                            │
│  - SHA-256 لكلمات المرور                                │
│                                                        │
│  PdfService                                             │
│  - تقارير PDF                                           │
├──────────────────────────────────────────────────────┤
│              SQLite DB (sanad_mvp.db)                  │
└──────────────────────────────────────────────────────┘
```

### تدفق البيانات

```
Screen (context.watch / context.read)
    ↓
AppProvider (يقوم بالعملية + notifyListeners)
    ↓
SanadRepository (قراءة/كتابة)
    ↓
DatabaseService (SQLite)
```

### مبادئ التحديث

| النوع | الآلية | الاستخدام |
|-------|--------|-----------|
| **Targeted update** | تعديل القائمة في الذاكرة + `notifyListeners()` | تغيير حالة خطوة، إضافة متابعة |
| **Targeted reload** | إعادة جلب قائمة محددة + `notifyListeners()` | بعد إضافة واجب |
| **Full reload** | `selectStudent()` أو `loadHome()` | تغيير الطالب، تسجيل الدخول |

### الملفات الأكثر أهمية

| الملف | الأسطر | الوظيفة |
|-------|--------|---------|
| `app_provider.dart` | 2025 | كل منطق التطبيق |
| `app_models.dart` | 1816 | 30 كلاس/ enum |
| `database_service.dart` | 1867 | Schema v31, 26 جدول |
| `sanad_repository.dart` | 744 | CRUD لكل جدول |
| `clinical_assessment_wizard_screen.dart` | 3386 | معالج التقييم (الأكثر تعقيداً) |
| `student_profile_screen.dart` | 2959 | ملف الطالب (أكثر شاشة بيانات) |
| `sessions_screen.dart` | ~1050 | الجلسات العلاجية |
| `app_shell.dart` | ~715 | التنقل والقائمة الجانبية |
| `app_widgets.dart` | ~500 | أدوات عامة |

### الإحصائيات الأساسية

- **الجداول**: 26
- **الشاشات**: ~31
- **النماذج**: 30
- **إصدار الـ Schema**: 31
- **عدد الترقيات**: 30
- **دور المستخدم**: 8 أدوار
- **لغة الواجهة**: العربية (RTL)
- **خط الأساس**: Segoe UI مع Tahoma/Arial احتياطي

### التقنية

| المكون | التقنية |
|--------|---------|
| إطار العمل | Flutter 3.4+ (Dart >=3.4.0) |
| إدارة الحالة | Provider (ChangeNotifier) — ملف واحد |
| قاعدة البيانات | SQLite عبر sqflite (Android) / sqflite_common_ffi (Desktop) |
| التوجيه | يدوي عبر AppShell (بدون Navigator/GoRouter) |
| التقارير | pdf + printing + file_picker |
| التشفير | crypto (SHA-256) |
| نسخ احتياطي | تصدير/استيراد .db مباشر |

### المنصات المدعومة

| المنصة | الحالة |
|--------|--------|
| Android | ✅ يعمل |
| Windows | ✅ يعمل |
| Linux | غير مختبر (مدعوم افتراضياً) |
| macOS | غير مختبر (مدعوم افتراضياً) |
| iOS | ❌ غير مدعوم (لا sqflite على iOS) |

---

## 4. مخطط تدفق النظام

```
                    ┌──────────────────┐
                    │  تقييم علاجي      │
                    │  (Assessment)     │
                    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │  ClinicalFinding  │
                    │  (نتائج التقييم)   │
                    └────────┬─────────┘
                             │
              ┌──────────────┴──────────────┐
              │  abnormal findings فقط       │
              ▼                              ▼
     ┌──────────────────┐          ┌──────────────────┐
     │  TrainingPlan    │          │  GoalSkillStep    │
     │  (هدف علاجي)     │          │  (مهارات الهدف)   │
     └────────┬─────────┘          └────────┬─────────┘
              │                             │
              ▼                             ▼
     ┌──────────────────┐                   │
     │  TherapySession  │◄──────────────────┘
     │  (جلسة علاجية)    │
     └────────┬─────────┘
              │
     ┌────────┴──────────────┐
     │                       │
     ▼                       ▼
┌──────────────┐    ┌──────────────────┐
│  Exercise    │    │  StudentFollowup │
│  (واجب منزلي) │    │  (متابعة)        │
└──────────────┘    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │  ملف الطالب       │
                    │  (عرض كل شيء)     │
                    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │  لوحة الأخصائي    │
                    │  (مؤشرات الأداء)   │
                    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │  تقارير PDF       │
                    └──────────────────┘
```

---

## 5. قاعدة البيانات (Database)

### الإصدار الحالي: **31**

(`DatabaseService.currentVersion = 31`)

### قائمة الجداول (26 جدولاً)

| # | الجدول | الغرض |
|---|--------|-------|
| 1 | `centers` | مراكز التأهيل |
| 2 | `users` | المستخدمين (أخصائيين، مدراء، أولياء أمور) |
| 3 | `students` | الطلاب |
| 4 | `parents` | أولياء الأمور (legacy, يُستخدم جزئياً) |
| 5 | `sessions` | الجلسات العلاجية |
| 6 | `evaluations` | تقييمات قديمة (legacy) |
| 7 | `training_plans` | الأهداف العلاجية (وحدة العلاج الأساسية) |
| 8 | `goal_skill_steps` | المهارات الفرعية لكل هدف |
| 9 | `exercises` | الواجبات المنزلية |
| 10 | `rewards` | نقاط XP (نظام تحفيزي) |
| 11 | `reports` | تقارير PDF محفوظة |
| 12 | `clinical_assessments` | التقييمات العلاجية |
| 13 | `clinical_findings` | نتائج التقييم المفصلة |
| 14 | `therapy_program_templates` | قوالب البرامج العلاجية |
| 15 | `assessment_section_templates` | أقسام التقييم (مثل الوجه، الفم) |
| 16 | `assessment_item_templates` | بنود التقييم (مثل تماثل الوجه) |
| 17 | `assessment_option_templates` | خيارات كل بند (طبيعي / غير طبيعي) |
| 18 | `skill_step_templates` | قوالب المهارات العلاجية |
| 19 | `speech_sound_trigger_templates` | مشغلات الحروف (letter × error × position) |
| 20 | `sign_resources` | موارد لغة الإشارة |
| 21 | `audit_logs` | سجل التدقيق |
| 22 | `student_therapy_programs` | ربط الطالب بالبرامج |
| 23 | `assessment_drafts` | مسودات التقييم |
| 24 | `student_specialists` | ربط الطالب بالأخصائيين |
| 25 | `student_followups` | متابعات إعادة التدريب |
| 26 | *(جدول مؤقت/آخر)* | |

### أهم الحقول الرئيسية

| الجدول | PK | FKs |
|--------|----|-----|
| `centers` | `id` | — |
| `users` | `id` | `center_id → centers` |
| `students` | `id` | `center_id → centers` |
| `sessions` | `id` | `student_id → students`, `plan_id → training_plans` |
| `training_plans` | `id` | `student_id → students`, `program_id → therapy_program_templates` |
| `goal_skill_steps` | `id` | `goal_id → training_plans` |
| `clinical_assessments` | `id` | `student_id → students` |
| `clinical_findings` | `id` | `assessment_id → clinical_assessments` |
| `student_followups` | `id` | `student_id → students`, `plan_id → training_plans`, `goal_skill_step_id → goal_skill_steps` |
| `student_specialists` | `id` | `student_id → students`, `specialist_id → users` |

### ملاحظات على الـ Schema

- كل الأعمدة `NOT NULL` باستثناء `users.student_id`
- التواريخ مخزنة كـ `TEXT` (ISO 8601)
- القيم البوليانية مخزنة كـ `INTEGER` (0/1)
- التطبيق يستخدم `ensureLatestSchema()` عند كل تشغيل كشبكة أمان

### أهم الـ Migrations

| الإصدار | التغيير |
|---------|---------|
| 8 | إضافة `clinical_assessments` و `clinical_findings` |
| 9 | إضافة `goal_skill_steps` |
| 12 | إضافة جداول الهيكل العلاجي (6 جداول) |
| 16 | إضافة `assessment_drafts` |
| 19 | إضافة `student_therapy_programs` + أعمدة `program_id`/`source_type` في 4 جداول |
| 23 | إضافة `student_specialists` |
| 26 | إضافة `student_followups` |
| 29 | توحيد الـ Schema (إضافة أعمدة ناقصة) |
| 31 | *(آخر إصدار)* |

---

## 6. النماذج (Models)

كل النماذج في ملف واحد: `lib/models/app_models.dart` (~1816 سطر، 30 كلاس/enum).

### قائمة النماذج

| # | النموذج | الحقول الأساسية | ملاحظات |
|---|---------|----------------|---------|
| 1 | `Center` | id, name, logo_path, address, phone, manager_name, is_active | |
| 2 | `User` | id, center_id, email, password_hash, name, role, student_id | |
| 3 | `Student` | id, center_id, name, age, status, diagnosis, program_type, parent_name, parent_phone, portal_email, portal_password, deleted_at | |
| 4 | `Parent` | id, center_id, student_id, name, phone, email | نموذج قديم |
| 5 | `TherapySession` | id, student_id, specialist_id, plan_id, program_id, skill_id, activity_results, session_type, practice_items, attempts, success_rate, started_at, duration_seconds, card_title, quick_result | |
| 6 | `TherapyEvaluation` | id, student_id, letter, position, error_type, score, severity | نموذج قديم (legacy) |
| 7 | `TrainingPlan` | id, center_id, student_id, goal, treatment, target_date, progress, program_id, source_type | **وحدة العلاج الأساسية** |
| 8 | `GoalSkillStep` | id, goal_id, title, status (لم يبدأ/متقن/بمساعدة/يحتاج إعادة), sort_order, last_session_id | **أداة مساعدة** |
| 9 | `Exercise` | id, student_id, title, instructions, due_date, status, plan_id, goal_skill_step_id, program_id, source_type, parent_note, note_for_parent | |
| 10 | `Reward` | id, student_id, xp, level, badges, daily_streak | نظام XP |
| 11 | `Report` | id, student_id, type, improvement_rate, specialist_signature, file_path | |
| 12 | `ClinicalAssessment` | id, center_id, student_id, specialist_id, type, strengths_summary, weaknesses_summary, goals_summary, training_summary, created_at | |
| 13 | `ClinicalFinding` | id, assessment_id, domain, item_title, result, isNormal, weakness, goal, training, program_id, source_type, templateId | |
| 14 | `TherapyProgramTemplate` | id, center_id, name, description, uses_speech_sounds, sort_order | قالب البرنامج |
| 15 | `AssessmentSectionTemplate` | id, program_id, title, description, sort_order | قالب قسم التقييم |
| 16 | `AssessmentItemTemplate` | id, section_id, title, response_type, response_mode, prompt, sort_order | قالب بند التقييم |
| 17 | `AssessmentOptionTemplate` | id, item_id, label, generates_therapy, weakness_template, goal_template, therapy_template | قالب خيار |
| 18 | `SkillStepTemplate` | id, owner_type, owner_id, title, sort_order | قالب مهارة |
| 19 | `SpeechSoundTriggerTemplate` | id, program_id, letter, error_type, position, generates_therapy, weakness_template, goal_template, skill_steps_json | مشغل حرف |
| 20 | `SignResource` | id, title, category, media_type, media_path | موارد الإشارة |
| 21 | `AuditLog` | id, user_id, user_name, action, entity_type, entity_id, details | |
| 22 | `StudentTherapyProgram` | id, student_id, program_id, is_active | ربط طالب ببرنامج |
| 23 | `AssessmentDraft` | (student_id, program_id) PK, phase, step_index, selections_json, multi_selections_json, letter_results_json | |
| 24 | `StudentSpecialist` | id, student_id, specialist_id, is_active | ربط طالب بأخصائي |
| 25 | `StudentFollowup` | id, student_id, specialist_id, program_id, plan_id, goal_skill_step_id, reason, status, created_at, resolved_at | متابعة مهارة |
| 26 | `UserRole` (enum) | sanadOwner, centerManager, clinicalSupervisor, therapyProgramEntry, coordinator, specialist, dataEntry, parent | |
| 27 | `AppPermission` (enum) | manageCenters, manageStaff, ... (16 صلاحية) | |
| 28 | `GoalStatus` (enum-like) | جديد, قيد العلاج, متقن, يحتاج مساعدة, يحتاج إعادة | |
| 29 | `AssessmentImprovementSummary` | **(في ملف منفصل)** | |

### نموذج منفصل

- `lib/models/assessment_improvement_summary.dart` — تحليل التحسن بين التقييمات

### `ClinicalFinding` — الحقول الأكثر أهمية

```dart
final String id;
final String assessmentId;
final String domain;        // eg 'برنامج نطق وتخاطب - الوجه'
final String itemTitle;     // للأقسام: عنوان البند، للحروف: 'حرف أ'
final String result;        // الخيار المختار
final bool isNormal;        // هل النتيجة طبيعية؟
final String weakness;      // وصف الضعف
final String goal;          // الهدف العلاجي
final String training;      // خطة العلاج
final String programId;     // البرنامج المرتبط
final String sourceType;    // 'standard' أو 'speechSound'
final String templateId;    // link إلى option.id أو trigger.id (للهيكل العلاجي)
```

### `AssessmentImprovementSummary` — الحقول

```dart
final bool hasEnoughData;
final String? previousAssessmentId;
final String? currentAssessmentId;
final String? previousDate;     // ISO 8601
final String? currentDate;      // ISO 8601
final int baseWeaknessCount;    // إجمالي نقاط الضعف في التقييم السابق
final int improvedCount;        // تحسنت
final int unchangedWeaknessCount; // لم تتحسن
final double improvementRate;   // improved / baseWeakness * 100
final int regressionCount;      // تراجعت
final int newFindingCount;      // مشاكل جديدة
final int missingCount;         // نقاط ضعف سابقة غير موجودة في الحالي
final int stableNormalCount;    // طبيعي في كلا التقييمين
```

---

## 7. المزوّد (Provider)

### `AppProvider` (ملف واحد: `lib/providers/app_provider.dart` — 2025 سطر)

**النوع:** `ChangeNotifier` (مفرد — لا يوجد providers متعددة)

### المسؤوليات

1. **إدارة المستخدم والجلسة**: تسجيل الدخول، تسجيل الخروج، التحقق من الصلاحيات
2. **إدارة البيانات**: تحميل، حفظ، تعديل جميع الكيانات
3. **حساب المؤشرات**: `goalProgress()`, `goalStatus()`, `centerGoalImprovementRate`, `studentGoalAverageProgress`, `studentAssessmentImprovement`
4. **التزامن**: `syncGoalProgress()` — يحفظ progress محسوب إلى DB
5. **الفلترة**: تصفية الطلاب والجلسات حسب الدور

### أهم الـ Getters

```dart
// مؤشرات الأداء — كلها تستخدم goalProgress() وليس plan.progress
int get centerGoalImprovementRate   // متوسط تقدم أهداف جميع طلاب الأخصائي
int studentGoalAverageProgress(id)  // متوسط تقدم أهداف طالب معين
AssessmentImprovementSummary get studentAssessmentImprovement  // تحسن الطالب بين التقييمات
int get activeGoalCount             // عدد الأهداف النشطة (progress < 100)
int get masteredGoalCount           // عدد الأهداف المتقنة (progress >= 100)
```

### أهم الـ Methods

```dart
// تحميل
Future<void> loadHome()                           // تحميل أولي بعد تسجيل الدخول
Future<void> selectStudent(Student)               // تحميل بيانات طالب معين

// التقييم العلاجي
Future<void> saveClinicalAssessment({assessment, findings})  // حفظ تقييم + توليد أهداف/مهارات

// الجلسات
Future<void> saveSession({...})                   // حفظ جلسة علاجية
Future<void> correctSessionResult({...})          // تصحيح نتيجة جلسة

// الأهداف والمهارات
int goalProgress(String goalId)                   // حساب progress runtime
String goalStatus(String goalId)                  // حساب حالة الهدف
List<GoalSkillStep> stepsForGoal(String goalId)   // مهارات هدف معين
Future<void> syncGoalProgress(String goalId)      // مزامنة progress مع DB

// المتابعات
Future<void> upsertFollowup({...})                // إنشاء/تحديث متابعة
Future<void> resolveFollowupForStep(studentId, stepId)  // إغلاق متابعة

// البرامج العلاجية
List<TherapyProgramTemplate> programsForStudent()  // برامج الطالب

// الأدوات المساعدة
List<SkillStepTemplate> _skillStepTemplatesForFinding(finding)  // قالب المهارات لنتيجة
```

### `goalProgress()` — منطق الحساب

```dart
int goalProgress(String goalId) {
  final steps = stepsForGoal(goalId);
  if (steps.isNotEmpty) {
    // إذا كان للهدف مهارات → progress = نسبة المهارات المتقنة
    final completed = steps.where((step) => step.status == 'متقن').length;
    return ((completed / steps.length) * 100).round();
  }
  // إذا لا توجد مهارات → آخر جلسة
  final goalSessions = sessions.where((s) => s.planId == goalId).toList()
    ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  if (goalSessions.isEmpty) {
    // لا مهارات ولا جلسات → plan.progress (fallback)
    final matches = plans.where((item) => item.id == goalId).toList();
    return matches.isEmpty ? 0 : matches.first.progress;
  }
  switch (goalSessions.first.quickResult) {
    case 'متقن': return 100;
    case 'بمساعدة': return 50;
    default: return 0;
  }
}
```

### `syncGoalProgress()` — مزامنة مع DB

```dart
Future<void> syncGoalProgress(String goalId) async {
  // يحسب progress من المهارات ويحفظه في training_plans.progress
  final goalSteps = await _repository.goalStepsForGoal(goalId);
  final completed = goalSteps.where((step) => step.status == 'متقن').length;
  final progress = goalSteps.isEmpty
      ? plan.progress   // لا مهارات → يحافظ على القيمة الحالية
      : ((completed / goalSteps.length) * 100).round();
  // يحفظ الـ plan المحدث
}
```

---

## 8. الشاشات (Screens)

### قائمة الشاشات الرئيسية

| الشاشة | الملف | الأسطر | الوظيفة |
|--------|-------|--------|---------|
| AppShell | `app_shell.dart` | ~715 | السقالة الرئيسية + القائمة الجانبية + التنقل |
| Login | `login_screen.dart` | ~450 | تسجيل الدخول |
| لوحة الأخصائي | `specialist_dashboard_screen.dart` | 705 | مؤشرات أداء الأخصائي |
| معالج التقييم | `clinical_assessment_wizard_screen.dart` | 3386 | تقييم علاجي → توليد أهداف |
| ملف الطالب | `student_profile_screen.dart` | 2959 | كل بيانات الطالب |
| الجلسات | `sessions_screen.dart` | ~1050 | جلسة علاجية بتقييم ثلاثي الأزرار |
| الواجبات | `homework_screen.dart` | ~600 | إنشاء واجبات منزلية |
| بنّاء الهيكل | `therapy_structure_builder_screen.dart` | ~1300 | بناء القوالب العلاجية |
| لوحة المدير | `dashboard_screen.dart` | ~300 | إدارة المركز |
| لوحة ولي الأمر | `parent_dashboard_screen.dart` | ~500 | متابعة الطالب |
| التقارير | `reports_screen.dart` | ~400 | تقارير PDF |
| شاشات أخرى | متنوعة | — | المراكز، الموظفين، الطلاب، إلخ |

### وصف الشاشات الأكثر أهمية

#### `app_shell.dart`
- يحتوي على `BottomNavigationBar` مع عناصر حسب الدور
- يستخدم `IndexedStack` للحفاظ على حالة كل تبويب
- يتضمن القائمة الجانبية (Drawer) للملاحة الثانوية

#### `login_screen.dart`
- إدخال البريد الإلكتروني + كلمة المرور
- SHA-256 للمصادقة
- لا يدعم تسجيل مستخدم جديد من الواجهة

#### `clinical_assessment_wizard_screen.dart`
- **أكثر شاشة تعقيداً** (3386 سطر)
- ثلاث مراحل: اختيار البرنامج ← تقييم الأقسام ← تقييم الحروف
- مساران للتقييم: خيار مفرد (singleChoice) وخيار متعدد (multiResponse)
- الحروف تُقيّم حرفاً حرفاً (letter-by-letter)
- حفظ مسودة تلقائي في كل خطوة (`AssessmentDraft`)
- عند الحفظ: ينشئ `ClinicalAssessment` + `ClinicalFinding` لكل بند
- ثم تلقائياً: ينشئ `TrainingPlan` + `GoalSkillStep` لكل finding غير طبيعي

#### `sessions_screen.dart`
- يختار الأخصائي: الطالب ← البرنامج ← نوع المصدر
- `_findCurrent()` يحدد المهارة التالية غير المتقنة
- ثلاثة أزرار تقييم: متقن / بمساعدة / يحتاج إعادة
- عند التقييم: تحديث حالة المهارة، إنشاء/إغلاق متابعة، تسجيل الجلسة
- عند "بمساعدة" أو "يحتاج إعادة": إنشاء واجب منزلي تلقائي

#### `student_profile_screen.dart`
- **أكثر شاشة من حيث البيانات** (2959 سطر)
- 37 كلاس/دالة على مستوى الملف
- الأقسام: Header + تقييم علاجي + تحسن بين التقييمات + أهداف + مهارات + جلسات سابقة + متابعات + واجبات + تقارير
- شاشتان فرعيتان: الأخصائي وولي الأمر (لكل منهما عرض مختلف)

---

## 9. التقييم العلاجي

### كيف يعمل؟

1. الأخصائي يختار طالباً ← برنامجاً علاجياً ← يبدأ التقييم
2. **مرحلة الأقسام**: يعرض بنود التقييم حسب القالب العلاجي
   - الخيار المفرد (singleChoice): يختار الأخصائي option واحد
   - الخيار المتعدد (multiResponse): يضغط "نعم طبيعي" / "لا يحتاج تدخل" لكل option
3. **مرحلة الحروف**: إن كان البرنامج `usesSpeechSounds == true`
   - يعرض كل حرف على حدة
   - الأخصائي يضغط "طبيعي" أو يختار نوع خطأ + موضع
4. عند الحفظ:
   - لكل بند: ينشئ `ClinicalFinding`
   - لكل finding غير طبيعي (`isNormal == false`):
     - ينشئ `TrainingPlan` (هدف علاجي) مع `progress = 0`
     - ينشئ `GoalSkillStep` (مهارات) حسب قالب المهارات
   - `templateId` في `ClinicalFinding` = `AssessmentOptionTemplate.id` (للأقسام) أو `SpeechSoundTriggerTemplate.id` (للحروف)

### كيف يمنع التكرار؟

- عند بدء تقييم جديد لطالب:
  - إذا كان للطالب تقييم سابق، يتم مقارنة `templateId` المطابقة لتجنب إعادة إنشاء أهداف مكررة
  - آلية منع التكرار: `_skillStepTemplatesForFinding` تستخدم `templateId` للبحث عن `SkillStepTemplate`

### المشكلة المعروفة

- **الحروف الطبيعية لا تنشئ `ClinicalFinding`**: عندما يكون حرف = طبيعي، يُضاف فقط إلى `strengths` ولا يُنشأ finding. هذا يسبب مشكلة في حساب التحسن بين التقييمات (انظر القسم 16).

---

## 10. الأهداف العلاجية

### القرار المعماري النهائي

> **الهدف (`TrainingPlan`) هو وحدة العلاج والتقارير الأساسية.**

- الهدف = ما يسعى العلاج لتحقيقه (مثلاً: "تحسين نطق حرف أ في أول الكلمة")
- الهدف يُنشأ تلقائياً من التقييم العلاجي
- لكل هدف: `progress` (0-100)، `goalStatus`، `GoalSkillStep` (مهارات)
- التقارير تعتمد على `goalProgress()` للحالة الرقمية

### خصائص الهدف

| الخاصية | الشرح |
|---------|-------|
| المعرف | `TrainingPlan.id` (UUID) |
| المحتوى | `goal` (نص الهدف)، `treatment` (خطة العلاج) |
| التقدم | `progress` (0-100، يُحدّث عبر `syncGoalProgress`) |
| الربط | `studentId → Student`، `programId → TherapyProgramTemplate` |
| المصدر | `sourceType` ('standard' أو 'speechSound') |

### كيف يُحسب `goalStatus()`؟

1. `goalProgress() >= 100` → `'متقن'`
2. أي مهارة حالتها `'يحتاج إعادة'` → `'يحتاج إعادة'`
3. أي مهارة حالتها `'بمساعدة'` → `'يحتاج مساعدة'`
4. لا مهارات لكن آخر جلسة إعادة → `'يحتاج إعادة'`
5. لا مهارات لكن آخر جلسة بمساعدة → `'يحتاج مساعدة'`
6. `progress > 0` → `'قيد العلاج'`
7. وإلا → `'جديد'`

---

## 11. المهارات (GoalSkillStep)

### القرار الرسمي الحالي

> **`GoalSkillStep` ليست وحدة تقرير. ليست وحدة تحسن. ليست وحدة علاج مستقلة. هي أداة مساعدة للأخصائي فقط.**

- المهارة = خطوة فرعية ضمن الهدف
- الهدف هو وحدة التقارير والعلاج
- المهارات تساعد الأخصائي في تتبع التفاصيل الدقيقة
- `goalProgress()` يحسب النسبة المئوية للمهارات المتقنة

### حالات المهارة

| الحالة | المعنى |
|--------|--------|
| `لم يبدأ` | المهارة لم تُعمل بعد |
| `متقن` | أتقنها الطالب |
| `بمساعدة` | يحتاج مساعدة لأدائها |
| `يحتاج إعادة` | يحتاج إعادة تدريب |

### تأثير المهارة على النظام

| الحدث | التأثير |
|-------|---------|
| المهارة ← `متقن` | إغلاق المتابعة إن وجدت، تقدم في الهدف |
| المهارة ← `بمساعدة` | إنشاء متابعة (reason=assisted)، إنشاء واجب منزلي |
| المهارة ← `يحتاج إعادة` | إنشاء متابعة (reason=retry)، إنشاء واجب منزلي |

### مصدر المهارات

- من `SkillStepTemplate` المرتبطة بـ `AssessmentOptionTemplate` أو `SpeechSoundTriggerTemplate`
- تخزّن inline في `SpeechSoundTriggerTemplate.skill_steps_json` أو كسجلات منفصلة في `skill_step_templates`
- `_skillStepTemplatesForFinding()` في الـ Provider تبحث بالترتيب:
  1. `assessmentOptions` حيث `templateId == option.id` → `skill_step_templates` حيث `ownerType == 'option'`
  2. `speechSoundTriggers` حيث `templateId == trigger.id` → `skill_step_templates` حيث `ownerType == 'sound'`
  3. fallback: `trigger.skillStepTemplates` (inline JSON)

---

## 12. الجلسات

### كيف تحفظ؟

- `TherapySession` يُنشأ في `sessions_screen.dart`
- الحقول الأساسية: `studentId`, `specialistId`, `planId`, `programId`, `skillId`, `quickResult`, `successRate`, `startedAt`, `durationSeconds`, `cardTitle`, `practiceItems`, `activityResults`
- الحقول الاختيارية: `notes`, `summary`, `targetLetter`, `letterPosition`, `errorType`

### كيف تحسب؟

- `successRate` = حسب زر التقييم:
  - متقن → 100
  - بمساعدة → 60
  - يحتاج إعادة → 20
- `quickResult` = `'متقن'` أو `'بمساعدة'` أو `'يحتاج إعادة'`
- `cardTitle` = اسم المهارة (من `GoalSkillStep.title`)

### كيف تؤثر على progress؟

- `goalProgress()` تستخدم:
  1. **إذا كان للهدف مهارات**: `completed / total * 100`
  2. **إذا لا مهارات**: آخر جلسة (`quickResult`)
  3. **إذا لا مهارات ولا جلسات**: `plan.progress` (fallback تخزين)
- `syncGoalProgress()` تحفظ `progress` المحسوب إلى جدول `training_plans`

---

## 13. المتابعات (Followups)

### كيف تنشأ؟

- أثناء الجلسة، عند تقييم مهارة:
  - `'بمساعدة'` ← `upsertFollowup(reason: 'assisted')`
  - `'يحتاج إعادة'` ← `upsertFollowup(reason: 'retry')`

### كيف تغلق؟

- أثناء الجلسة، عند تقييم مهارة:
  - `'متقن'` ← `resolveFollowupForStep(studentId, stepId)`
  - تغلق جميع المتابعات المفتوحة لتلك المهارة

### هيكل `StudentFollowup`

```dart
final String id;
final String studentId;
final String specialistId;
final String programId;
final String sourceType;
final String planId;          // الهدف المرتبط
final String goalSkillStepId; // المهارة المرتبطة
final String reason;          // 'assisted' أو 'retry'
final String status;          // 'pending' أو 'completed'
final String createdAt;
final String resolvedAt;      // وقت الحل
final String lastOpenedAt;    // آخر فتح للتدريب
```

### تدفق إعادة التدريب

1. في ملف الطالب: `_FollowupsSection` يعرض المتابعات المفتوحة
2. زر "إعادة التدريب" ← `preselectSession()` ← يخزّن معلومات الجلسة
3. `onOpenSession` ← ينتقل إلى شاشة الجلسات
4. `_applyPreselect()` يفتح المهارة المحددة مباشرة

---

## 14. ملف الطالب

### ما الذي يعرضه؟

`student_profile_screen.dart` (2959 سطر، 37 كلاس/دالة)

### أقسام الشاشة (للمتخصص)

| القسم | المحتوى |
|-------|---------|
| **Header** | اسم الطالب، التشخيص، البرامج، آخر جلسة، النتيجة، عدد الجلسات، أهداف نشطة، متقنة، متابعات، للمراجعة، حالة التقييم، متوسط التقدم |
| **التقييم العلاجي** | آخر 3 تقييمات مع强弱 النقاط |
| **التحسن بين التقييمات** | `AssessmentImprovementSummary` — نسبة التحسن، العدد المحسن، غير المحسن، التراجع، المستجد |
| **الأهداف** | `_GoalProgressSection` ← `_GoalCard` لكل هدف مع progress bar + زر تدريب |
| **الأهداف المتقنة** | `_MasteredGoalsSection` — أهداف حققت 100% |
| **الجلسات السابقة** | `_PreviousSessions` ← `_SessionTile` لكل جلسة (قابلة للنقر للتفاصيل) |
| **المتابعات** | `_FollowupsSection` ← `_FollowupTile` مع زر إعادة التدريب |
| **الواجبات المنزلية** | `_HomeworkTile` — حالة الواجبات |
| **التقارير** | `_ReportsFromProfile` — تقارير PDF |
| **الخط الزمني** | `_Timeline` — سجل زمني للجلسات والتقييمات |

### أقسام شاشة ولي الأمر (شاشة منفصلة)

| القسم | المحتوى |
|-------|---------|
| Header | اسم الطالب + إحصائيات مختصرة |
| قائمة التمارين | `_ParentHomeworkTile` لكل تمرين مع حالة الإنجاز |
| الجلسات السابقة | `_ParentSessionCard` |
| ملاحظات الأخصائي | `_ParentNotesCard` |

### ما الذي تم إعادة تصميمه؟

- **قسم التقييم العلاجي**: إضافة `_ImprovementSummaryCard` يعرض `AssessmentImprovementSummary`
- **الأهداف**: إعادة تصميم كاملة ← `_GoalCard` مع progress bar، status badge، mini info chips، زر تدريب
- **الأهداف المتقنة**: `_MasteredGoalsSection` جديد
- **المتابعات**: `_FollowupsSection` + `_FollowupTile` مع زر إعادة التدريب
- **الجلسات**: `_SessionTile` معرف مع specialistId support، تصحيح النتيجة، عرض تفاصيل
- **عرض الوقت**: `_formatDateTime()` يعرض الوقت بجانب التاريخ (مثال: `11-06-2026 — 09:30 ص`)

### دوال مساعدة

```dart
String _formatDateTime(String iso) {
  // تحويل ISO 8601 إلى صيغة عربية: DD-MM-YYYY — HH:MM AM/PM
}
```

---

## 15. لوحة الأخصائي

### ما الذي يعرضه؟

`specialist_dashboard_screen.dart` (705 سطر)

| المؤشر | الشرح | المصدر |
|--------|-------|--------|
| عدد الطلاب | الطلاب المرتبطون بالأخصائي | `students` (مفلترة) |
| يحتاج تقييم | طلاب بلا تقييم علاجي | `studentsNeedingAssessment` |
| يحتاج متابعة | طلاب لديهم متابعات مفتوحة | `students` مع `followups` |
| متوسط تقدم أهداف طلابي | `centerGoalImprovementRate` | `goalProgress()` |
| الأهداف النشطة | كل أهداف طلاب الأخصائي (progress < 100) | `centerPlans` + `goalProgress()` |
| الأهداف المتقنة | كل أهداف طلاب الأخصائي (progress >= 100) | `centerPlans` + `goalProgress()` |
| قائمة الطلاب | قائمة مع إحصائيات مختصرة | لكل طالب: `studentGoalAverageProgress()`, `goalProgress()` لكل هدف |

### المؤشرات الصحيحة

| المؤشر | هل هو صحيح؟ | ملاحظات |
|--------|------------|---------|
| `centerGoalImprovementRate` | ✅ | يستخدم `goalProgress()` بعد الإصلاح |
| `studentGoalAverageProgress` | ✅ | (أُعيدت تسميته من `studentGoalImprovementRate`) |
| `_activeGoals` / `_masteredGoals` | ✅ | تستخدم `goalProgress()` بعد الإصلاح |
| تسمية "متوسط تقدم أهداف طلابي" | ✅ | (بدلاً من "نسبة التحسن") |

---

## 16. التحسن بين التقييمات

### `AssessmentImprovementSummary` — الشرح الكامل

- **الموقع**: `lib/models/assessment_improvement_summary.dart`
- **الغرض**: مقارنة آخر تقييمين علاجيين لقياس تحسن الطالب
- **مستقل تماماً عن**: الجلسات، الأهداف، المهارات، XP

### كيف يعمل؟

```dart
AssessmentImprovementSummary.compute(
  studentId,
  allAssessments,      // List<ClinicalAssessment>
  findingsByAssessment // Map<assessmentId, List<ClinicalFinding>>
)
```

1. **فلترة** تقييمات الطالب ← `where(studentId)`
2. **ترتيب** تصاعدي بـ `createdAt` (ISO 8601 كامل — يتضمن الوقت) ← `sort(compareTo)`
3. **اختيار** آخر تقييمين ← `[length-2]` و `[last]`
4. **بناء خريطة** للنتائج لكل تقييم:
   - المفتاح = `templateId` **(مشكلة — انظر أدناه)**
   - القيمة = `ClinicalFinding`
5. **مقارنة** كل `templateId` عبر التقييمين:

| الشرط | التصنيف |
|-------|---------|
| prev≠null, curr≠null, !prev.isNormal, curr.isNormal | `improved++` |
| prev≠null, curr≠null, !prev.isNormal, !curr.isNormal | `unchangedWeakness++` |
| prev≠null, curr≠null, prev.isNormal, !curr.isNormal | `regression++` |
| prev≠null, curr≠null, prev.isNormal, curr.isNormal | `stableNormal++` |
| prev≠null, curr==null | `missing++` (و `baseWeakness++` إن كان ضعفاً) |
| prev==null, curr≠null | `newFinding++` |

6. **حساب النسبة**: `improvementRate = (improved / baseWeakness) * 100`

### المشكلة المعروفة (لم تُصلح بعد)

> **`compute()` يطابق findings باستخدام `templateId`. لكن `templateId` يعرّف الخيار العلاجي وليس بند التقييم.**

#### مثال: حرف أ (ضعف ← طبيعي)

| التقييم | حرف أ | `templateId` |
|---------|-------|-------------|
| الأول (4:24م) | إبدال (ضعف) | `trigger_أ_إبدال_أول` |
| الثاني (4:26م) | طبيعي | **لا يوجد finding** |

النتيجة: `missing++` وليس `improved++`. `improvementRate = 0%` رغم تحسن الطالب.

#### مثال: قسم (ضعف ← طبيعي)

| التقييم | تماثل الوجه | `templateId` |
|---------|------------|-------------|
| الأول | مائل لليمين | `option_مائل` |
| الثاني | طبيعي | `option_طبيعي` (مختلف!) |

النتيجة: `missing++` و `newFinding++` وليس `improved++`.

#### الحل المقترح (في انتظار الموافقة)

1. تغيير `itemTitle` للحروف من `'حرف أ - إبدال - أول'` إلى `'حرف أ'`
2. إنشاء `ClinicalFinding` للحروف الطبيعية أيضاً (بـ `isNormal=true`)
3. تغيير مفتاح المطابقة في `compute()` من `templateId` → `itemTitle`

انظر `docs/analysis/comparison_key_redesign.md` للتفاصيل.

### اختبارات التحسن

- `test/assessment_improvement_test.dart` (7 اختبارات)
- تغطي: تقييم واحد فقط، 6 من 10 تحسنت، regression، newFinding، missing

---

## 17. القرارات المعمارية النهائية

### ما تم اعتماده نهائياً

| القرار | الشرح |
|--------|-------|
| **الهدف (TrainingPlan) = وحدة العلاج والتقارير** | وليس المهارة (GoalSkillStep) |
| **`goalProgress()` هو المصدر الوحيد لتقدم الهدف** | يحسب runtime، لا يعتمد على `plan.progress` من DB |
| **`AssessmentImprovementSummary` هو المرجع الوحيد للتحسن السريري** | مستقل عن الجلسات والأهداف |
| **`templateId` للعلاج فقط** | يُستخدم لربط findings بـ SkillStepTemplate، وليس لمقارنة التحسن |
| **Provider مفرد (AppProvider)** | ملف واحد لكل منطق التطبيق |
| **SQLite محلي** | لا يوجد backend/server |
| **Arabic RTL** | واجهة كاملة بالعربية |
| **ثلاثة أزرار تقييم** | متقن / بمساعدة / يحتاج إعادة |
| **StudentFollowup للمتابعات** | بدلاً من الاعتماد على حالة الجلسات فقط |
| **حفظ جميع التواريخ كـ ISO 8601** | `DateTime.now().toIso8601String()` |
| **`ensureLatestSchema()` عند كل تشغيل** | شبكة أمان للـ Schema |
| **تقييم حرف بحرف** | الحروف تُقيّم فردياً في واجهة منفصلة |
| **برنامج علاجي للطالب** | عبر `StudentTherapyProgram` |

### ما تم رفضه

| القرار المرفوض | السبب |
|----------------|-------|
| **مقارنة التحسن بـ templateId** | لا يعمل لأن templateId يختلف بين normal/abnormal |
| **الاعتماد على `plan.progress`** | قيمة قديمة في DB، لا تعكس الحالة الحالية |
| **`GoalSkillStep` كوحدة تقارير** | المهارة أداة مساعدة، الهدف هو الأساس |
| **تحسين الطالب من الجلسات** | الجلسات تقيس أداءً وليس تحسناً سريرياً |
| **نظام خادم/عميل** | التطبيق يعمل محلياً 100% |
| **قاعدة بيانات خارجية** | SQLite محلي — كل شيء على الجهاز |

### ما تم تأجيله

| المؤجل | السبب |
|--------|-------|
| **إصلاح مقارنة التحسن** | يحتاج تصميم + 3 تغييرات في الكود (في انتظار الموافقة) |
| **تقسيم AppProvider** | تحسين معماري لكنه كبير ولا يؤثر على الأداء حالياً |
| **اختبارات UI/Flow الكامل** | فقط اختبارات CRUD + goalProgress + assessmentImprovement موجودة |
| **تحسين أداء `selectStudent`** | يعيد تحميل كل شيء؛ مقبول حالياً |
| **iOS support** | لا sqflite على iOS |
| **نظام إشعارات** | `notification_service.dart` غير مستخدم |

---

## 18. المشاكل المفتوحة

### P1 — حرجة

1. **حساب التحسن بين التقييمات لا يعمل للحروف والأقسام** (موثّق في `docs/analysis/improvement_bug_diagnosis.md`)
   - الحروف الطبيعية لا تنشئ finding
   - الأقسام الطبيعية لها templateId مختلف
   - الإصلاح المقترح في `docs/analysis/comparison_key_redesign.md`

### P2 — متوسطة

2. **`selectStudent()` تعيد تحميل كل شيء** — حتى بعد تغيير حالة خطوة واحدة
3. **معالج التقييم معقد جداً** (3386 سطر) — ثلاث مسارات متفرعة مع حفظ مسودة تلقائي
4. **لا يوجد فصل بين UI والمنطق** — StatefulWidgets فيه منطق أعمال مباشر
5. **حفظ المسودة متكرر جداً** — كل خطوة في التقييم تحفظ المسودة حتى لو لم يتغير شيء

### P3 — منخفضة

6. **`notification_service.dart` غير مستخدم** — مكانه فارغ أو احتياطي
7. **بعض الحقول في `parents` و `rewards` و `sign_resources`** لا تُقرأ من DB (`created_at`, `updated_at` مفقودة في `fromMap`)
8. **اختبارات غير كافية** — لا توجد اختبارات للـ UI أو التدفق الكامل
9. **Schema divergence محتملة** بين Windows و Android عند التثبيت القديم ثم الترقية

---

## 19. خطة العمل القادمة

### الترتيب الصحيح

| الأولوية | المهمة | التعقيد | الملفات المتأثرة |
|----------|--------|---------|-----------------|
| **1** | إصلاح مقارنة التحسن (comparisonKey) | متوسط | `assessment_improvement_summary.dart`, `clinical_assessment_wizard_screen.dart` |
| **2** | إضافة اختبارات للتحسن بعد الإصلاح | سهل | `test/assessment_improvement_test.dart` |
| **3** | توثيق القرارات المعمارية في ADR | سهل | `docs/` |
| **4** | تحسين `selectStudent()` لتحديث targeted | صعب | `app_provider.dart` |
| **5** | إعادة هيكلة `clinical_assessment_wizard_screen.dart` | صعب | wizard |
| **6** | إضافة اختبارات UI للتقييم ← الجلسات | متوسط | `test/` |
| **7** | تقسيم `AppProvider` | صعب جداً | `app_provider.dart` |

---

## 20. آخر حالة للمشروع (Project Snapshot)

### ما الذي اكتمل؟

- ✅ **التقييم العلاجي الكامل** مع الأقسام والحروف والحفظ التلقائي
- ✅ **توليد الأهداف والمهارات** تلقائياً من التقييم
- ✅ **الجلسات العلاجية** مع تقييم ثلاثي الأزرار وتقدم تلقائي
- ✅ **المتابعات** (إنشاء + إغلاق + إعادة تدريب)
- ✅ **الواجبات المنزلية** مع حالة متابعة (ولي أمر ← أخصائي)
- ✅ **ملف الطالب** مع 11 قسماً
- ✅ **لوحة الأخصائي** مع مؤشرات أداء مُصلحة
- ✅ **تحسن بين التقييمات** (مع مشكلة معروفة)
- ✅ **بنّاء الهيكل العلاجي** (برامج، أقسام، بنود، خيارات، حروف)
- ✅ **أدوار المستخدمين** (8 أدوار)
- ✅ **إدارة الطلاب** للأخصائي
- ✅ **إدارة البرامج العلاجية** للطلاب
- ✅ **عرض الوقت بجانب التاريخ** في ملف الطالب
- ✅ **تقارير PDF**

### ما الذي يعمل؟

- ✅ تسجيل الدخول
- ✅ إدارة المركز (للمالك)
- ✅ إدارة الموظفين
- ✅ التقييم العلاجي الكامل
- ✅ الجلسات العلاجية
- ✅ الواجبات المنزلية
- ✅ متابعة ولي الأمر
- ✅ ملف الطالب (جميع الأقسام)
- ✅ لوحة الأخصائي (جميع المؤشرات)
- ✅ نظام XP
- ✅ التقارير

### ما الذي تم اختباره؟

- **49 اختباراً** — جميعها ناجحة ✅
- **اختبارات CRUD:** 42 اختباراً (إنشاء + قراءة + تحديث + حذف لكل جدول)
- **اختبارات AssessmentImprovementSummary:** 7 اختبارات (حالات مختلفة للتحسن)
- **اختبارات goalProgress logic:** 8 اختبارات (مع/بدون مهارات، حالات مختلفة)
- **اختبارات الـ Widget:** اختبار 1 (انطلاقة التطبيق)

### نتائج `flutter analyze`

```
0 errors
0 warnings (في ملفاتنا)
1 warning (غير متعلق — therapy_structure_builder_screen.dart:130)
105 info-level issues (prefer_const_constructors, avoid_print, إلخ)
```

### نتائج `flutter test`

```
00:03 +49: All tests passed!
```

### إحصائيات الكود

| المقياس | القيمة |
|---------|--------|
| إجمالي الأسطر (Dart) | ~18,000 |
| ملفات الـ Screens | 31 |
| ملفات الـ Models | 2 (app_models + assessment_improvement_summary) |
| ملفات الـ Providers | 1 |
| ملفات الـ Repositories | 1 |
| ملفات الـ Services | 4 |
| Widgets | 2 ملفات |
| أدوار المستخدم | 8 |
| صلاحيات | 16 |
| جداول DB | 26 |
| إصدار Schema | 31 |
| الاختبارات | 49 |
| منصات مدعومة | Android + Windows |

---

> **Project Snapshot — June 2026**  
> هذا الملف هو المرجع الرسمي الوحيد للمشروع.  
> أي تغيير بعد هذا التاريخ يجب أن يحدّث هذا الملف.  
> **آخر تحديث:** 11-06-2026
