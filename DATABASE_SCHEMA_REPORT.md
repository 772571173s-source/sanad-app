# [مُستبدل] تقرير قاعدة البيانات

> ⚠️ **هذا الملف قديم.** الرجاء الرجوع إلى `SCHEMA_REFERENCE.md` للـ Schema التفصيلي و `docs/project_master_reference.md` للمرجع المعماري الشامل.

## الإصدار الحالي: 29
## اسم الملف: `sanad_mvp.db`
## محرك التخزين: SQLite (عبر `sqflite` على Android، `sqflite_common_ffi` على Desktop)
## الموقع: `getDatabasesPath()/sanad_mvp.db`

---

## 1. كيف يعمل إدارة الـ Schema

### `onCreate` (إنشاء قاعدة جديدة)
```dart
onCreate: (db, version) async {
  await _createSchema(db);  // ينشئ جميع الجداول الـ 25 مرة واحدة
}
```

### `onUpgrade` (ترقية قاعدة موجودة)
```dart
onUpgrade: _upgrade,  // دالة تتحقق من oldVersion → newVersion
// ينفذ كل خطوة ترقية sequentially
// مثال: if (oldVersion < 2) { ... } if (oldVersion < 3) { ... }
// يضمن أن الترقية من أي إصدار سابق إلى v29 تعمل
```

### `onOpen` (عند فتح قاعدة موجودة)
```dart
onOpen: (db) async {
  await _repairStoredArabicText(db);  // إصلاح النصوص العربية المشوهة
  await _ensureLatestSchema(db);      // التأكد من وجود كل الأعمدة (للحالات التي فاتتها الترقية)
}
```

### `_ensureLatestSchema`
- يحوي 25 تعريف جدول مع كل أعمدة.
- يتحقق من وجود كل جدول (`PRAGMA table_info`).
- إذا الجدول ناقص: ينشئه.
- إذا العمود ناقص: يضيفه (`ALTER TABLE ADD COLUMN`).
- يضمن أن الفتح على أي جهاز (قديم/جديد) يعمل بدون أخطاء "no such column".

**هذا هو الحل النهائي لمشكلة Android/Windows**: لاحظنا أن بعض الأجهزة (خصوصًا بعد التحديثات) تفتقد أعمدة `program_id`، `source_type` في `clinical_findings`، `goal_skill_steps`، `training_plans`، `exercises`. `_ensureLatestSchema` يصحح ذلك تلقائيًا عند الفتح.

### `clearAllData()`
- أضيفت حديثًا للاختبار
- تعطل `PRAGMA foreign_keys = ON`
- تحذف كل الصفوف من كل الجداول
- تعيد تفعيل المفاتيح الخارجية
- لا تكسر الـ Schema

---

## 2. قائمة الجداول الكاملة (25 جدول)

### 2.1 `centers` — المراكز
| العمود | النوع | شرح |
|--------|------|------|
| id | TEXT PK | معرف فريد |
| name | TEXT NOT NULL | اسم المركز |
| logo_path | TEXT DEFAULT '' | شعار المركز |
| address | TEXT DEFAULT '' | العنوان |
| phone | TEXT DEFAULT '' | الهاتف |
| manager_name | TEXT DEFAULT '' | اسم المدير |
| is_active | INT DEFAULT 1 | نشط/غير نشط |
| created_at | TEXT | تاريخ الإنشاء |
| updated_at | TEXT | آخر تحديث |

**العلاقات**: مرجع لـ `users.center_id`، `students.center_id`، وجميع الجداول الأخرى
**يكتب فيه**: مالك سند فقط
**الاستخدام**: Android ✅ / Windows ✅

### 2.2 `users` — المستخدمون
| id | TEXT PK | معرف فريد |
| center_id | TEXT DEFAULT '' | FK → centers.id |
| email | TEXT UNIQUE NOT NULL | البريد |
| password_hash | TEXT NOT NULL | SHA-256 |
| name | TEXT NOT NULL | الاسم |
| role | TEXT NOT NULL | sanadOwner/centerManager/... |
| student_id | TEXT NULL | إذا كان ولي أمر مرتبط بطالب |
| force_password_change | INT DEFAULT 0 | إجبار تغيير كلمة المرور |
| is_demo | INT DEFAULT 0 | حساب تجريبي |
| is_active | INT DEFAULT 1 | نشط/محظور |

**العلاقات**: يشير لـ `centers.id`
**ملاحظة**: `student_id` يُستخدم فقط لحسابات أولياء الأمور
**الاستخدام**: Android ✅ / Windows ✅

### 2.3 `students` — الطلاب
| id | TEXT PK | معرف فريد |
| center_id | TEXT NOT NULL FK | المركز |
| name | TEXT NOT NULL | اسم الطالب |
| age | INT NOT NULL | العمر |
| status | TEXT NOT NULL | الحالة |
| diagnosis | TEXT NOT NULL | التشخيص |
| program_type | TEXT DEFAULT 'نطق وتخاطب' | نوع البرنامج |
| parent_name | TEXT | اسم ولي الأمر |
| parent_phone | TEXT | هاتف ولي الأمر |
| portal_email | TEXT | بريد بوابة ولي الأمر |
| portal_password | TEXT | كلمة مرور البوابة |
| photo_path | TEXT | صورة الطالب |
| notes | TEXT | ملاحظات |
| deleted_at | TEXT DEFAULT '' | soft delete |

**الملاحظات**: نظام soft delete (لا يحذف فعليًا، `deleted_at` يُملأ بالتاريخ)
**الاستخدام**: Android ✅ / Windows ✅

### 2.4 `parents` — أولياء الأمور
| id | TEXT PK | |
| center_id | TEXT FK | |
| student_id | TEXT FK | |
| name | TEXT | |
| phone | TEXT | |
| email | TEXT | |

**ملاحظة**: هذا جدول منفصل عن `users`. ولي الأمر قد يكون له حساب دخول (في `users` مع `student_id`) وملف منفصل في `parents`.
**الاستخدام**: Android ✅ / Windows ✅

### 2.5 `sessions` — جلسات علاجية
| id | TEXT PK | |
| center_id | TEXT FK | |
| student_id | TEXT FK | |
| specialist_id | TEXT DEFAULT '' | أضيف في v25 |
| plan_id | TEXT DEFAULT '' | الخطة المرتبطة |
| program_id | TEXT DEFAULT '' | أضيف في v7 |
| skill_id | TEXT DEFAULT '' | v7 |
| activity_results | TEXT DEFAULT '' | v7 |
| session_type | TEXT DEFAULT 'نطق وتخاطب' | |
| target_letter | TEXT | |
| letter_position | TEXT | |
| error_type | TEXT | |
| practice_items | TEXT | |
| attempts | INT | |
| success_rate | INT | |
| started_at | TEXT | |
| duration_seconds | INT | |
| card_title | TEXT | |
| quick_result | TEXT | متقن/بمساعدة/يحتاج إعادة |
| notes | TEXT | |
| summary | TEXT | |

**الملاحظات**: كل تقييم لخطوة ينتج جلسة واحدة. العمود `quick_result` يسجل النتيجة (متقن/بمساعدة/يحتاج إعادة).
**الاستخدام**: Android ✅ / Windows ✅

### 2.6 `evaluations` — تقييمات حروف النطق
| الأعمدة: | id, center_id, student_id, letter, position, error_type, score, severity, recommendation, notes |
**الملاحظات**: هذا الجدول قديم نسبيًا (مرتبط بنظام الحروف قبل وجود الهيكل العلاجي المتكامل). يستخدم في شاشة التقييمات الصوتية المنفصلة.
**الاستخدام**: Android ✅ / Windows ✅

### 2.7 `training_plans` — الخطط العلاجية (الأهداف)
| id | TEXT PK | |
| center_id | TEXT FK | |
| student_id | TEXT FK | |
| goal | TEXT NOT NULL | الهدف |
| treatment | TEXT DEFAULT '' | أضيف في v21 |
| target_date | TEXT | تاريخ الاستهداف |
| progress | INT NOT NULL | 0-100 |
| program_id | TEXT DEFAULT '' | أضيف في v19 |
| source_type | TEXT DEFAULT 'standard' | v19 |

**الملاحظات**: `source_type` قد يكون `'standard'` أو `'speechSound'`.
**الاستخدام**: Android ✅ / Windows ✅

### 2.8 `goal_skill_steps` — خطوات المهارات
| id | TEXT PK | |
| center_id | TEXT FK | |
| student_id | TEXT FK | |
| goal_id | TEXT FK → training_plans.id | |
| title | TEXT | اسم الخطوة |
| status | TEXT DEFAULT 'لم يبدأ' | لم يبدأ/متقن/بمساعدة/يحتاج إعادة |
| sort_order | INT | ترتيب |
| notes | TEXT | ملاحظات |
| last_session_id | TEXT | |
| program_id | TEXT DEFAULT '' | v19 |
| source_type | TEXT DEFAULT 'standard' | v19 |

**الملاحظات**: الحالات الأربعة: `لم يبدأ` → `متقن` / `بمساعدة` / `يحتاج إعادة`.
**الاستخدام**: Android ✅ / Windows ✅

### 2.9 `exercises` — الواجبات المنزلية
| الأعمدة (مختصر): | id, center_id, student_id, title, instructions, due_date, status, program_id (v19), plan_id (v19), goal_skill_step_id (v19), source_type (v19), session_date, note_for_parent (v22), parent_completed_at (v22), specialist_reviewed_at (v22), created_from_session_result (v22) |
**ملاحظات**: الواجبات تُنشأ من شاشة الواجبات حصريًا، وليس من الجلسات.
**الاستخدام**: Android ✅ / Windows ✅

### 2.10 `rewards` — المكافآت/النقاط
| id, center_id, student_id, xp, level, badges, daily_streak |
**الاستخدام**: Android ✅ / Windows ✅

### 2.11 `reports` — التقارير
| id, center_id, student_id, type, created_at, improvement_rate, specialist_signature, manager_signature, file_path |
**الاستخدام**: Android ✅ / Windows ✅

### 2.12 `clinical_assessments` — التقييمات السريرية
| id, center_id, student_id, specialist_id, specialist_name, type, strengths_summary, weaknesses_summary, goals_summary, training_summary |
**الاستخدام**: Android ✅ / Windows ✅

### 2.13 `clinical_findings` — نتائج التقييم
| id, assessment_id FK, center_id, student_id, domain, item_title, result, is_normal, weakness, goal, training, program_id (v19), source_type (v19) |
**الملاحظات**: `program_id` و `source_type` أضيفا في v19 لربط النتائج بالبرنامج العلاجي.
**الاستخدام**: Android ✅ / Windows ✅

### 2.14 `therapy_program_templates` — البرامج العلاجية
| id, center_id, name, description, uses_speech_sounds, sort_order |

### 2.15 `assessment_section_templates` — أقسام التقييم
| id, center_id, program_id FK, title, description, sort_order |

### 2.16 `assessment_item_templates` — عناصر التقييم
| id, center_id, section_id FK, title, response_type, response_mode (v15), prompt, sort_order |

### 2.17 `assessment_option_templates` — خيارات التقييم
| id, center_id, item_id FK, label, generates_therapy, weakness_template, goal_template, therapy_template, sort_order |

### 2.18 `skill_step_templates` — قوالب خطوات المهارات
| id, center_id, owner_type ('option'/'sound'), owner_id, title, sort_order |

### 2.19 `speech_sound_trigger_templates` — مؤثرات الأصوات
| id, center_id, program_id, letter, error_type, position, generates_therapy, weakness_template, goal_template, therapy_template, skill_steps_json (v17), sort_order |

### 2.20 `sign_resources` — موارد لغة الإشارة
| id, center_id, title, category, media_type, media_path, notes, level (v6), is_favorite (v6) |

### 2.21 `audit_logs` — سجل التدقيق
| id, center_id, user_id, user_name, action, entity_type, entity_id, details |
**ملاحظة**: لا يستخدم حاليًا باستمرار. بعض الإجراءات تسجله والبعض الآخر لا.

### 2.22 `student_therapy_programs` — برامج الطالب
| id, student_id, program_id, assigned_at, assigned_by_user_id, is_active, sort_order, created_at (v20), updated_at (v20) |

### 2.23 `assessment_drafts` — مسودات التقييم
| student_id (PK), program_id (PK), phase, step_index, current_letter, selections_json, multi_selections_json, matrix_selections_json, letter_results_json (v18), created_at (v28) |
**ملاحظة**: مفتاح أساسي مركب `(student_id, program_id)` يعني طالب+برنامج واحد لكل مسودة.

### 2.24 `student_specialists` — تخصيص الأخصائيين
| id, student_id, specialist_id, assigned_by_user_id, assigned_at, is_active, created_at (v24), updated_at (v24) |
**ملاحظة**: جدول ربط بين الطالب والأخصائي (علاقة many-to-many مع is_active).

### 2.25 `student_followups` — متابعات إعادة التدريب
| id, student_id, specialist_id, program_id, source_type, plan_id, goal_skill_step_id, reason ('retry'/'assisted'), status ('pending'/'completed'), last_opened_at, updated_at (v27) |
**الملاحظات**: أضيف في v26. هذا هو المصدر الرسمي لتحديد ما إذا كانت الخطوة تحتاج إعادة تدريب.

---

## 3. ملخص الترقيات (v1 → v29)

| الإصدار | التغيير |
|---------|---------|
| 1 | الإنشاء الأولي |
| 2 | إضافة جدول `sign_resources` |
| 3 | ترحيل v3 (تفاصيل غير معروفة) |
| 4 | إزالة البيانات التجريبية |
| 5 | إضافة `audit_logs` |
| 6 | إضافة `level`، `is_favorite` → `sign_resources` |
| 7 | إضافة `program_id`, `skill_id`, `activity_results` → `sessions` |
| 8 | إنشاء جداول التقييم السريري |
| 9 | إنشاء جدول `goal_skill_steps` |
| 10 | حذف جداول البرامج القديمة `_dropLegacyProgramTables` |
| 11 | إصلاح النصوص العربية المشوهة `_repairStoredArabicText` |
| 12 | إنشاء جداول الهيكل العلاجي `_ensureTherapyStructureTables` |
| 13 | إعادة تعيين الحسابات وإعادة بناء الأدوار `_resetAccountsForRoleRebuild` |
| 14 | إنشاء جداول البرامج العلاجية |
| 15 | إضافة `response_mode` → `assessment_item_templates` |
| 16 | إنشاء `assessment_drafts` |
| 17 | إضافة `skill_steps_json` → `speech_sound_trigger_templates` |
| 18 | إضافة `letter_results_json` → `assessment_drafts` |
| 19 | **إضافة `program_id`, `source_type`** إلى `clinical_findings`, `goal_skill_steps`, `training_plans`, `exercises` ← العمود الأكثر أهمية |
| 20 | إضافة `created_at`, `updated_at` → `student_therapy_programs` |
| 21 | إضافة `treatment` → `training_plans` |
| 22 | إضافة أعمدة الواجبات → `exercises` |
| 23 | إنشاء `student_specialists` |
| 24 | إضافة `created_at`, `updated_at` → `student_specialists` |
| 25 | إضافة `specialist_id` → `sessions` |
| 26 | إنشاء `student_followups` |
| 27 | إضافة `updated_at` → `student_followups` |
| 28 | إضافة `created_at` → `assessment_drafts` |
| 29 | إعادة إضافة الأعمدة المفقودة (v19 فشل على بعض الأجهزة) |

**ملاحظة مهمة**: v29 يعيد تشغيل الإضافة لبعض الأعمدة التي كان v19 يفترض إضافتها، لكن بعض الأجهزة لم تحصل عليها بسبب مشاكل في الـ migration. `_ensureLatestSchema` في `onOpen` يضمن عدم تكرار هذه المشكلة مستقبلًا.

---

## 4. قواعد تعديل الـ Schema

1. **أي عمود جديد يجب إضافته في 3 أماكن**:
   - `_createSchema` (للجداول الجديدة)
   - `_upgrade` (للترقية من الإصدارات القديمة)
   - `_ensureLatestSchema` map (للحالات التي تفوتها الترقية)

2. **الترقيات تراكمية**: نستخدم `if (oldVersion < X)` وليس `else if`، لضمان عمل الترقية من أي إصدار سابق.

3. **جميع الترقيات إضافية فقط**: لا نحذف أعمدة ولا جداول. `_dropLegacyProgramTables` هو الاستثناء الوحيد (تم في v10).

4. **عند إضافة جدول جديد**:
   - أضف `CREATE TABLE` في `_createSchema`
   - أضف `await _ensureTable(db, 'name', 'CREATE TABLE...')` في `_upgrade` مع إصدار جديد
   - أضف تعريف الجدول في `_ensureLatestSchema` map بأحدث إصدار من الأعمدة
   - أضف `Model.fromMap` و `Model.toMap` في `app_models.dart`
   - أضف طرق CRUD في `sanad_repository.dart`
   - أضف طرق التحميل/الحفظ في `app_provider.dart`
   - زد `currentVersion` في `database_service.dart`

5. **زيادة `currentVersion`**:
   - يجب زيادته فقط عند إضافة تغيير حقيقي في الـ Schema
   - `_upgrade` سوف يُستدعى لكل الترقيات المفقودة بين الـ oldVersion والـ newVersion
   - `onOpen` يستدعي `_ensureLatestSchema` للتعامل مع الحالات الشاذة

6. **`PRAGMA foreign_keys = ON`**: مفعلة دائمًا عند فتح قاعدة البيانات. `clearAllData()` يعطلها مؤقتًا.

---

## 5. مشاكل الـ Schema السابقة (وكيف حُلّت)

| المشكلة | السبب | الحل |
|---------|-------|------|
| `no such table: student_specialists` | الجدول لم يُنشأ في بعض الأجهزة (v23 كان يعتمد على الترقية فقط، لكن بعض المستخدمين بدأوا من v23+ مباشرة) | `_ensureLatestSchema` يتحقق من وجود الجدول عند كل فتح |
| `no column named: program_id` | في `clinical_findings`, `goal_skill_steps`, `training_plans`, `exercises` — بعض الأجهزة فاتتها v19 | `_ensureLatestSchema` يضيف الأعمدة المفقودة |
| `no column named: source_type` | نفس المشكلة أعلاه | `_ensureLatestSchema` يضيفها |
| v29 إعادة تشغيل v19 | بعض الأجهزة لم تحصل على v19 بشكل صحيح (ربما بسبب توقف التطبيق أثناء الترقية) | v29 يعيد تنفيذ إضافة الأعمدة لجميع الجداول الأربعة |

---

## 6. هل نحتاج مسح بيانات مستقبلًا؟

- **لا نحتاج مسح بيانات بعد الآن** طالما أن `_ensureLatestSchema` يعمل بشكل صحيح.
- `clearAllData()` أضيفت فقط للاختبار (نظف قاعدة وأعد التشغيل من الصفر).
- في الإنتاج، الترقيات يجب أن تكون تراكمية وآمنة.
