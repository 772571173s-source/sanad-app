# [مُستبدل] تقرير تدفقات العمل

> ⚠️ **هذا الملف قديم.** الرجاء الرجوع إلى `docs/project_master_reference.md` للمرجع الرسمي المحدث.

---

## 1. التنقل حسب الدور

```
مالك سند (sanadOwner):
  Dashboard → المراكز → المدراء → مكتبة سند العلاجية → المساعدة → الإعدادات

مدير مركز (centerManager):
  Dashboard → الطلاب → ملف الطالب → الموظفون → الأدوات → الإعدادات

مشرف فني (clinicalSupervisor):
  Dashboard → الطلاب → ملف الطالب → التقييم العلاجي → بناء الهيكل العلاجي → الإعدادات

مدخل برامج (therapyProgramEntry):
  Dashboard → بناء الهيكل العلاجي → الإعدادات

منسق (coordinator):
  لوحة التنسيق → توزيع الطلاب → إدارة الارتباطات → الإعدادات

أخصائي (specialist):
  لوحة الأخصائي → ملف الطالب → التقييم العلاجي → الجلسات → الواجبات → الإعدادات

مدخل بيانات (dataEntry):
  Dashboard → الإدخال → الطلاب → الإعدادات

ولي أمر (parent):
  لوحة ولي الأمر → الإعدادات

وضع الدعم (supportMode):
  Dashboard → الطلاب → ملف الطالب → الموظفون → الأدوات → الإعدادات
```

---

## 2. تدفق إدارة المركز والحسابات

### إنشاء مركز
```
مالك سند → CentersScreen → يضيف مركز
  ↓
app.saveCenter(center)
  ↓
repository.saveCenter() → INSERT INTO centers
  ↓
Targeted update: centers.add, currentCenter = center
```

### إضافة مستخدم
```
مدير مركز/مالك → StaffScreen → يضيف موظف
  ↓
app.saveStaffUser(user)
  ↓
repository.saveUser() → INSERT INTO users
  ↓
Targeted update: staff.add
```

### الإعداد الأولي
```
عند أول تشغيل (لا يوجد مستخدمين) → FirstSetupScreen
  ↓
ينشئ حساب المالك (sanadOwner)
  ↓
تسجيل الدخول → loadHome()
```

---

## 3. تدفق إدارة الطلاب

### إضافة طالب
```
مدخل بيانات/مدير → StudentsScreen → إضافة طالب
  ↓
app.saveStudent(student)
  ↓
repository.saveStudent() → INSERT INTO students
  ↓
Targeted update: students.add, selectedStudent = student
```

### توزيع طالب على أخصائي
```
منسق → StudentDistributionScreen / AssignmentManagementScreen
  ↓
app.assignStudentToSpecialist(studentId, specialistId)
  ↓
repository.saveStudentSpecialist() → INSERT INTO student_specialists
  ↓
Targeted reload: جلب studentSpecialists
```

### توزيع برنامج علاجي على طالب
```
منسق/مدير → يوزع برنامجًا للطالب
  ↓
app.assignStudentProgram(studentId, programId)
  ↓
repository.saveStudentTherapyProgram() → INSERT INTO student_therapy_programs
  ↓
Targeted update: studentProgramIds.add(programId)
```

---

## 4. تدفق بناء الهيكل العلاجي ⭐

هذا هو الأساس لكل التقييمات والجلسات.

### الخطوات (بالترتيب):
```
1. برنامج علاجي (TherapyProgramTemplate)
   ├── usesSpeechSounds: true/false ← يحدد مسار التقييم
   │
2. أقسام التقييم (AssessmentSectionTemplate) ← مرتبطة بالبرنامج
   │
3. عناصر التقييم (AssessmentItemTemplate) ← مرتبطة بالقسم
   │   ├── responseType: 'custom' / 'matrix'
   │   └── responseMode: 'singleChoice' / 'multiSelect'
   │
4. خيارات التقييم (AssessmentOptionTemplate) ← مرتبطة بالعنصر
   │   ├── generatesTherapy: true/false
   │   ├── weaknessTemplate
   │   ├── goalTemplate
   │   └── therapyTemplate
   │
5. قوالب خطوات المهارات (SkillStepTemplate) ← مرتبطة بـ option أو sound
   │   ├── ownerType: 'option' / 'sound'
   │   └── ownerId: معرف الخيار/الصوت
   │
6. (اختياري) مؤثرات الأصوات (SpeechSoundTriggerTemplate)
      ├── letter, errorType, position
      ├── skill_steps_json: قائمة inline بالخطوات
      └── مرتبطة بالبرنامج
```

### من يبني؟
- **مالك سند**: بناء عام (global, centerId = '')
- **مشرف فني**: بناء لمركز معين (إذا كان المركز يسمح)
- **مدخل برامج علاجية**: بناء عام فقط

### التخزين
- كل الجداول الـ template تستخدم `center_id` للتمييز بين العام (`''`) والخاص بالمركز.
- `therapyStructureWriteCenterId` يحدد أي center_id يُستخدم عند الحفظ.

---

## 5. تدفق التقييم العلاجي ⭐ (أكثر تدفق تعقيدًا)

### الدخول
```
أخصائي → التقييم العلاجي → يختار طالب + برنامج
  ↓
يتحقق من وجود مسودة (assessment_drafts)
  ├── إذا وجدت: يسأل "متابعة" أم "بداية جديدة"
  └── إذا لا: يبدأ من الصفر
```

### المسارات الثلاثة:

#### المسار A — عناصر تقييم عادية (standard + singleChoice)
```
لكل قسم ← لكل عنصر ← يختار خيارًا واحدًا
  ↓
يخزن في selections: Map<itemId, AssessmentOptionTemplate>
```

#### المسار B — عناصر متعددة الخيارات (standard + multiSelect)
```
لكل قسم ← لكل عنصر ← يختار عدة خيارات (نعم/لا)
  ↓
يخزن في multiSelections: Map<optionId, bool>
```

#### المسار C — أصوات النطق (speechSound)
```
إذا البرنامج usesSpeechSounds == true [فقط]
  ← لكل حرف ← لكل خطأ ← لكل موضع → يقيم
  ↓
يخزن في letterResults: Map<letter, Map>
```

### الحفظ النهائي

```
_saveAssessment()
  ↓
ينشئ ClinicalAssessment
  ↓
لكل ClinicalFinding:
  ├── sourceType = 'standard' (للمسار A, B)
  ├── sourceType = 'speechSound' (للمسار C)
  ├── programId = selectedProgram?.id ?? ''
  └── isNormal = !option.generatesTherapy
  ↓
يبحث في findings عن!isNormal && goal.isNotEmpty
  ↓
ينشئ TrainingPlan:
  ├── programId = finding.programId
  └── sourceType = finding.sourceType
  ↓
يبحث عن SkillStepTemplate المناسبة (عبر _skillStepTemplatesForFinding)
  ↓
ينشئ GoalSkillStep لكل قالب:
  ├── programId = finding.programId
  └── sourceType = finding.sourceType
  ↓
يحذف المسودة
  ↓
selectStudent(selectedStudent) ← إعادة تحميل كل بيانات الطالب
```

### متى يظهر الهدف؟

**في ملف الطالب (الأهداف النشطة)**:
- `app.plans.where((p) => p.progress < 100)` — مباشرة بعد `selectStudent` (فور الحفظ)

**في شاشة الجلسات**:
- يجب أن يختار الأخصائي نفس البرنامج (`programId`)
- يجب أن يختار نفس `sourceType` (`'standard'` أو `'speechSound'`)
- الشرطان أعلاه يحددان `_filteredPlans()` و `_filteredSteps()`
- إذا تطابقا ← يظهر الهدف مع أول خطوة `لم يبدأ`

### لماذا لا يظهر الهدف في الجلسات أحيانًا؟ (المشكلة التي حُلّت)
1. **السبب الأصلي**: `steps.every((s) => s.status == 'متقن')` يرجع `true` للقائمة الفارغة (vacuous truth) ← يتخطى الخطة ← `_allDone = true`
2. **الحل**: تغيير الترتيب — التحقق من `steps.isEmpty` أولاً، ثم `steps.isNotEmpty && steps.every(...)`

---

## 6. تدفق الجلسات ⭐

### مراحل شاشة الجلسات:
```
1. اختيار طالب (إذا لا يوجد طالب مختار)
2. إذا app.plans.isEmpty && _selectedProgram == null → "لا توجد خطط"
3. اختيار برنامج (قائمة programsForStudent)
4. إذا البرنامج usesSpeechSounds == true → اختيار مصدر (standard/speechSound)
5. _findCurrent() → تحديد الهدف والخطوة الحالية
6. جلسة علاجية (شاشة التقييم بثلاثة أزرار)
7. بعد انتهاء كل العناصر → "انتهت عناصر هذه الجلسة" → اختيار مسار آخر
```

### `_findCurrent()` منطق البحث:
```
لكل TrainingPlan في _filteredPlans(app):
  ├── يجلب GoalSkillSteps المرتبطة
  ├── يبحث عن أول خطوة:
  │     status != 'متقن'
  │     && status != 'بمساعدة'
  │     && status != 'يحتاج إعادة'
  │     && !_evaluatedStepIds.contains(step.id)
  │   → إن وُجدت: sets _currentGoal, _currentStep, _allDone=false
  │
  ├── إذا steps.isEmpty && progress < 100:
  │   → جلسة بدون خطوة (تقييم على مستوى الخطة)
  │
  ├── إذا steps.isNotEmpty && كل steps متقن:
  │   → continue (الخطة مكتملة)
  │
  └── إذا انتهت كل الخطط:
      → _allDone = true ← "انتهت عناصر هذه الجلسة"
```

### `_evaluate(status)` منطق التقييم:
```
إذا step == null (تقييم مستوى الخطة):
  ├── إذا status == 'متقن': progress = 100
  └── يسجل جلسة

إذا step != null (تقييم مستوى خطوة):
  ├── updateGoalSkillStepStatus(step, status, notes)
  ├── إذا status == 'متقن':
  │     resolveFollowupForStep(studentId, step.id) ← يغلق المتابعة
  ├── إذا status == 'بمساعدة':
  │     upsertFollowup(reason: 'assisted') ← ينشئ متابعة
  ├── إذا status == 'يحتاج إعادة':
  │     upsertFollowup(reason: 'retry') ← ينشئ متابعة
  ├── _evaluatedStepIds.add(step.id) ← يمنع ظهورها مرة أخرى في نفس الجلسة
  └── _findCurrent() ← يبحث عن التالي
```

### أوزان النتائج الثلاثة:

| النتيجة | التأثير على GoalSkillStep | التأثير على Followup | المتابعة |
|---------|---------------------------|----------------------|----------|
| **متقن** | status = 'متقن' | يُغلق أي followup موجود | لا تظهر إعادة تدريب |
| **بمساعدة** | status = 'بمساعدة' | يُنشئ followup (reason='assisted') | يظهر زر إعادة التدريب |
| **يحتاج إعادة** | status = 'يحتاج إعادة' | يُنشئ followup (reason='retry') | يظهر زر إعادة التدريب |

### حساب progress:
- **مستوى الخطة (بدون خطوات)**: `updatePlanProgress(planId, progress: 100)` مباشرة عند 'متقن'
- **مستوى الخطوات**: لا يوجد `updatePlanProgress` مباشر. يُحسب progress عبر `app.goalProgress(planId)` الذي يحسب النسبة المئوية للخطوات المتقنة.

ملاحظة: هذا يعني أن progress قد لا يتغير فورًا بعد تقييم خطوة كـ 'متقن' إذا كان progress يُحسب بشكل منفصل — يحتاج مراجعة.

### `_evaluatedStepIds`:
- `Set<String>` يحفظ معرفات الخطوات التي قُيّمت في الجلسة الحالية
- يُمسح عند: تغيير البرنامج، تغيير المصدر، الرجوع، إعادة تعيين
- لا يُمسح عند الضغط على "اختيار مسار آخر" في `_buildPathComplete` (لأنه يغير المصدر فقط)
- الغرض: منع ظهور نفس الخطوة مرة أخرى في نفس الجلسة بعد تقييمها

---

## 7. تدفق المتابعة وإعادة التدريب

### إنشاء Followup
```
عند تقييم خطوة بـ 'بمساعدة' أو 'يحتاج إعادة':
  upsertFollowup( studentId, specialistId, programId, sourceType, planId, goalSkillStepId, reason )
    ↓
  يبحث عن followup pending موجود لهذه الخطوة
    ├── إذا موجود: لا ينشئ جديد (upsert)
    └── إذا لا: ينشئ StudentFollowup جديد
```

### إغلاق Followup
```
عند تقييم خطوة بـ 'متقن':
  resolveFollowupForStep(studentId, step.id)
    ↓
  يبحث عن followup pending
    ├── إذا موجود: status = 'completed', resolvedAt = now
    └── إذا لا: لا يفعل شيئًا
```

### عرض زر إعادة التدريب في ملف الطالب

**المنطق الحالي (بعد الإصلاح)**:
```
لكل خطوة في القسم النشط:
  hasPending = app.pendingFollowups.any(f => f.goalSkillStepId == step.id && f.status == 'pending')
  if hasPending → إظهار زر "إعادة التدريب"
  if step.status == 'متقن' → إظهار أيقونة خضراء (بدون زر)
  else → أيقونة رمادية (بدون زر)
```

**المشكلة القديمة**: كان يعتمد على `step.status` فقط، مما جعل زر إعادة التدريب يظهر مباشرة بعد التقييم (حتى قبل إنشاء الـ followup). الحل: استخدام `pendingFollowups` كمصدر رسمي.

### فتح إعادة التدريب
```
ضغط "إعادة التدريب"
  ↓
_OpenRetrainDialog (أو مباشرة)
  ↓
app.preselectSession({
  'studentId': student.id,
  'programId': plan.programId,
  'sourceType': plan.sourceType,
  'planId': plan.id,
  'stepId': step.id
})
  ↓
ينتقل إلى شاشة الجلسات
  ↓
_applyPreselect() يقرأ الخريطة ويختار الطالب/البرنامج/المصدر
↓
setState مع _isRetrainMode = true (ربما)
  ↓
عند التقييم: إذا 'متقن' → resolveFollowup, إذا 'بمساعدة'/'يحتاج إعادة' → upsert
```

ملاحظة: `sessionPreselect` مؤقتة — تُمسح بعد التطبيق (أو عند close التطبيق).

---

## 8. تدفق الواجبات المنزلية

### الإنشاء
```
أخصائي → شاشة الواجبات → 5 مراحل:
  1. اختيار طالب
  2. اختيار نوع: تمرين عام / تمرين هدف / تمرين خطوة
  3. اختيار هدف (TrainingPlan)
  4. اختيار خطوة (GoalSkillStep) [اختياري]
  5. تعبئة النموذج (العنوان، التعليمات، تاريخ الاستحقاق)
  ↓
app.saveExercise(exercise)
  ↓
repository.saveExercise() → INSERT INTO exercises
  ↓
createdFromSessionResult = 'homework' ← ثابت
  ↓
selectStudent(selectedStudent) ← إعادة تحميل
```

### حالات الواجب:
```
pending → (parent completes) → completed_by_parent → (specialist reviews) → specialist_reviewed
```

### عرض الواجبات:
- **في ملف الطالب**: قسم "الواجبات" يعرض حسب الحالة
- **في ولي الأمر**: لوحة ولي الأمر تعرض الواجبات pending
- **المراجعة**: الأخصائي يستعرض الواجبات المنجزة ويقيمها (نجوم، ملاحظات)

هام: الواجبات لا تُنشأ تلقائيًا من الجلسات (تم إيقاف هذه الميزة عمدًا).

---

## 9. تدفق ملف الطالب ⭐

### الأقسام (بالترتيب)
```
1. البيانات التعريفية: name, age, diagnosis, status, program_type
2. ملخص التقدم: studentAssessmentStatus, goalImprovementRate, lastSessionDate, إلخ
3. التقييمات السريرية: قائمة ClinicalAssessment مع نتائجها
4. الأهداف النشطة: plans.where(progress < 100) → كل خطة + خطواتها
5. الأهداف المنجزة: plans.where(progress >= 100) ← Collapsible (يظهر فقط إذا وجد)
6. يحتاج إعادة تدريب: followups (pending) ← Collapsible
7. الواجبات: exercises مقسمة حسب الحالة
8. الجلسات السابقة: قائمة sessions مرتبة
9. التقارير: قائمة reports
10. الإنجازات: reward (XP, level, badges, streak)
11. التقييمات الصوتية: evaluations (للحروف)
```

### مصادر البيانات
- كلها من `AppProvider` بعد `selectStudent` (تحميل مرة واحدة)
- `_GoalProgressSection` يعرض الأهداف النشطة مع كل خطوة
- `_MasteredGoalsSection` يعرض الأهداف المنجزة
- `_FollowupsSection` يعرض المتابعات pending

---

## 10. تدفق لوحة الأخصائي

```
SpecialistDashboardScreen
  ← يستخدم app.sessions (مفلترة بواسطة specialistId)
  ← يستخدم app.plans
  ← يستخدم app.exercises
  ← يستخدم app.studentFollowups

يظهر:
  - عدد الجلسات اليوم
  - الطلاب الذين يحتاجون تقييم
  - المتابعات pending
  - الواجبات pending
  - آخر الأنشطة
  - rate التحسن
```

---

## 11. تدفق لوحة ولي الأمر

```
ParentDashboardScreen
  ← يستخدم app.exercises لطفله
  ← يستخدم app.reports

يظهر:
  - الواجبات pending (يمكن تنفيذها)
  - الواجبات المنجزة
  - التقارير
  - يمكنه إكمال واجب (تسجيل الصوت، ملاحظات)
```

---

## 12. تدفق التقارير

```
يقوم الأخصائي بإنشاء تقرير:
  ← يختار نوع التقرير (تقدم، ختامي، إحالة)
  ← يختار الجلسات المطلوبة
  ← يوقع إلكترونيًا
  ← يتم حفظ الـ report + توليد PDF
  ← يمكن طباعته أو تصديره
```

---

## 13. تدفق النسخ الاحتياطي

```
تصدير:
  DatabaseService.exportBackup(targetPath)
    ← ينسخ ملف sanad_mvp.db إلى المسار المطلوب
  ↓
استيراد:
  DatabaseService.importBackup(sourcePath)
    ← يغلق قاعدة البيانات الحالية
    ← ينسخ الملف المصدر مكانها
    ← يعيد فتحها
```
