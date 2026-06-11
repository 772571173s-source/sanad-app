# [مُستبدل] مشروع سند — نظرة عامة شاملة

> ⚠️ **هذا الملف قديم.** الرجاء الرجوع إلى `docs/project_master_reference.md` (Project Snapshot — June 2026) للمرجع الرسمي المحدث.

## 1. ما هو التطبيق؟

**سند (Sanad)** هو نظام متكامل لإدارة التأهيل والتدخل المبكر لاضطرابات النطق والتخاطب. يخدم التطبيق:
- **مراكز التأهيل**: إدارة المرضى والموظفين والجلسات
- **الأخصائيين**: تقييم الحالات، جلسات علاجية، واجبات منزلية
- **أولياء الأمور**: متابعة التمارين المنزلية والتقارير
- **المشرفين الفنيين**: الإشراف على الهياكل العلاجية والتقارير
- **المدراء**: إعدادات المركز والموظفين

## 2. المنصات المدعومة

| المنصة | الحالة |
|--------|--------|
| Android | ✅ يعمل (تم اختباره على NE2217) |
| Windows | ✅ يعمل (تم بناؤه وتشغيله) |
| Linux | غير مُختبر (مدعوم افتراضيًا عبر sqflite_ffi) |
| macOS | غير مُختبر (مدعوم افتراضيًا) |
| iOS | غير مدعوم (نفتقر إلى sqflite على iOS) |

## 3. التقنية المستخدمة

| المكون | التقنية |
|--------|---------|
| إطار العمل | Flutter 3.4+ (Dart SDK >=3.4.0) |
| إدارة الحالة | Provider (ChangeNotifier) — ملف واحد: `app_provider.dart` |
| قاعدة البيانات | SQLite عبر `sqflite` (Android) و `sqflite_common_ffi` (Desktop) |
| التوجيه | يدوي عبر `AppShell` (لا يوجد Navigator/GoRouter) |
| التقارير | `pdf` + `printing` + `file_picker` |
| التشفير | `crypto` package (SHA-256 لكلمات المرور) |
| نسخ احتياطي | تصدير/استيراد ملف `.db` مباشر |
| الأذونات/الأدوار | نظام `UserRole` + `AppPermission` مدمج في الـ Provider |

## 4. الهيكلة المعمارية

```
lib/
├── main.dart                         ← نقطة الدخول، MaterialApp، SanadApp
├── models/
│   └── app_models.dart               ← جميع الـ Models (19 كلاس)
├── providers/
│   └── app_provider.dart             ← ChangeNotifier وحيد (كل المنطق)
├── repositories/
│   └── sanad_repository.dart         ← طبقة الوصول للبيانات (CRUD)
├── services/
│   ├── database_service.dart         ← إدارة قاعدة البيانات (Schema, Migrations)
│   ├── auth_service.dart             ← هashing كلمات المرور
│   ├── notification_service.dart     ← (احتمال وهمي/غير مستخدم)
│   └── pdf_service.dart              ← توليد PDF
├── screens/
│   ├── app_shell.dart                ← السقالة الرئيسية + القائمة الجانبية
│   ├── login_screen.dart             ← تسجيل الدخول
│   ├── first_setup_screen.dart       ← الإعداد الأولي
│   ├── dashboard_screen.dart         ← لوحة المدير/المالك
│   ├── centers_screen.dart           ← إدارة المراكز
│   ├── staff_screen.dart             ← إدارة الموظفين
│   ├── students_screen.dart          ← قائمة الطلاب
│   ├── student_profile_screen.dart   ← ملف الطالب الكامل
│   ├── sessions_screen.dart          ← الجلسات العلاجية
│   ├── clinical_assessment_wizard_screen.dart ← معالج التقييم (طويل)
│   ├── specialist_dashboard_screen.dart ← لوحة الأخصائي
│   ├── coordinator_dashboard_screen.dart ← لوحة المنسق
│   ├── homework_screen.dart          ← إنشاء واجبات منزلية
│   ├── therapy_structure_builder_screen.dart ← بناء الهيكل العلاجي
│   ├── parent_dashboard_screen.dart  ← لوحة ولي الأمر
│   ├── reports_screen.dart           ← التقارير
│   └── ... (إجمالي 31 شاشة)
├── widgets/
│   ├── app_widgets.dart              ← أدوات واجهة مشتركة
│   └── feedback.dart                 ← أدوات التغذية الراجعة (Snackbar, Dialog)
```

## 5. تدفق البيانات

```
UI (Screens)
    ↓ (context.watch / context.read)
AppProvider (ChangeNotifier — المفرد)
    ↓ (يدعو methods)
SanadRepository (قراءة/كتابة SQLite)
    ↓ (يدعو)
DatabaseService (إدارة الاتصال، الـ Schema)
    ↓
SQLite DB (sanad_mvp.db)
```

### مبدأ التحديث بعد التعديل:
- **Targeted update**: تعديل القائمة المحلية مباشرة ← `notifyListeners()` ← إعادة بناء الـ UI فقط (سريع)
- **Targeted reload**: إعادة جلب قائمة محددة من الـ Repository ← `notifyListeners()`
- **Full reload**: `selectStudent(selectedStudent)` أو `loadHome()` — إعادة جلب كل بيانات الطالب أو كل النظام (ثقيل)
- المشكلة الحالية: بعض الـ methods (مثل `saveSession`, `saveEvaluation`, `savePlan`, `saveGoalSkillStep`, `saveExercise`, `saveReward`) تستخدم `selectStudent` الذي يعيد تحميل كل شيء، مما يسبب إعادة بناء غير ضرورية

## 6. الملفات الأكثر أهمية (للرجوع إليها)

| الملف | الحجم التقريبي | الوظيفة |
|-------|----------------|---------|
| `app_provider.dart` | 1800 سطر | كل منطق التطبيق، التحميل، الحفظ، الصلاحيات |
| `app_models.dart` | 1767 سطر | كل تعريفات البيانات (19 كلاس) |
| `database_service.dart` | 1774 سطر | Schema (25 جدول)، Migrations (v1→v29) |
| `sanad_repository.dart` | ~1200 سطر | CRUD لكل جدول |
| `clinical_assessment_wizard_screen.dart` | ~1100 سطر | معالج التقييم العلاجي (الأكثر تعقيدًا) |
| `student_profile_screen.dart` | ~1900 سطر | ملف الطالب (أكثر شاشة من حيث البيانات) |
| `sessions_screen.dart` | ~1050 سطر | الجلسات العلاجية |
| `app_shell.dart` | 715 سطر | التنقل والقائمة الجانبية |
| `app_widgets.dart` | ~500 سطر | أدوات عامة قابلة لإعادة الاستخدام |

## 7. الإحصائيات الأساسية

- **الجداول**: 25
- **الشاشات**: 31
- **النماذج (Models)**: 19
- **إصدار الـ Schema**: 29
- **عدد الترقيات (Migrations)**: 28 (من v1 إلى v29)
- **دور المستخدم**: 8 أدوار
- **صلاحية**: 16 صلاحية
- **لغة الواجهة**: العربية (RTL)
- **خط الأساس**: Segoe UI مع Tahoma/Arial كاحتياطي
- **اختبارات**: 33 اختبار (التكامل CRUD + اختبارات القطعة)

## 8. الاعتماديات الخارجية (Dependencies)

```yaml
path: ^1.9.0              # مسارات الملفات
sqflite: ^2.4.1           # SQLite على Android/iOS
sqflite_common_ffi: ^2.3.4+4  # SQLite على Desktop
file_picker: ^8.1.2       # اختيار الملفات (للتقارير)
pdf: ^3.11.1              # توليد PDF
printing: ^5.13.4         # طباعة PDF
provider: ^6.1.2          # إدارة الحالة
crypto: ^3.0.6            # SHA-256
```

## 9. المشاكل المعمارية المعروفة

1. **Provider واحد ضخم**: `AppProvider` يحوي كل شيء (~1800 سطر). يؤدي إلى:
   - إعادة بناء غير ضرورية للـ UI عند تغيير أي قيمة
   - صعوبة اختبار الأجزاء بشكل منفصل
   - coupling عالي بين كل أجزاء التطبيق

2. **`selectStudent` يعيد تحميل كل شيء**: حتى بعد تغيير حالة خطوة واحدة، يتم إعادة جلب كل جداول الطالب.

3. **`loadHome()` ثقيل**: يُستدعى بعد تسجيل الدخول ويجلب كل بيانات النظام (المراكز، الموظفين، الطلاب، الهيكل العلاجي، إلخ). مقبول مرة واحدة، لكنه يصبح مشكلة إذا استُدعي باستمرار.

4. **معالج التقييم معقد جدًا**: ثلاث مسارات متفرعة (اختيار مفرد، متعدد، أصوات) مع حفظ مسودة تلقائي في كل خطوة — زيادة الاحتمالية للأخطاء.

5. **لا يوجد فصل بين الـ UI والمنطق**: الـ StatefulWidgets فيه منطق أعمال مباشر (خاصة في `clinical_assessment_wizard_screen`).

6. **حفظ المسودة متكرر جدًا**: كل خطوة في التقييم تحفظ المسودة، حتى لو لم يتغير شيء. هذا قد يسبب مشاكل أداء.

7. **مكتبة الإشعارات `notification_service.dart`**: يبدو أنها غير مستخدمة فعليًا (مكانها فارغ أو احتياطي).

8. **الاختبارات تغطي فقط CRUD**: لا توجد اختبارات للـ UI الـ Flow الكامل (التقييم ← الجلسات ← إعادة التدريب).
