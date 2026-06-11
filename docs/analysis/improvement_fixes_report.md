# تقرير إصلاح مؤشرات التحسن وتقدم الأهداف

## 1. المشاكل التي تم تشخيصها

### 1.1 `centerGoalImprovementRate` — يستخدم `plan.progress` من DB
- **الموقع**: `AppProvider.centerGoalImprovementRate`
- **المشكلة**: كان يحسب متوسط `plan.progress` (القيمة المخزنة في قاعدة البيانات)
- **السبب**: `plan.progress` هو snapshot قديم لا يعكس الحالة الحالية للهدف
- **التأثير**: مركز الأخصائي يظهر أرقام تقدم غير دقيقة

### 1.2 `studentGoalImprovementRate` — يستخدم `plan.progress` من DB
- **الموقع**: `AppProvider.studentGoalImprovementRate`
- **المشكلة**: نفس المشكلة — يعتمد على القيمة المخزنة في DB
- **التأثير**: أرقام تقدم الطالب غير دقيقة عند عدم مزامنة الـ DB

### 1.3 تسمية "نسبة التحسن" في لوحة الأخصائي
- **الموقع**: `SpecialistDashboardScreen._improvement()`
- **المشكلة**: كانت تعرض متوسط تقدم الأهداف (حسبة أداء) لكن التسمية توحي بتحسن سريري
- **الخلط المفاهيمي**: "نسبة التحسن" في الطب هي مقارنة بين تقييمين علاجيين، وليست متوسط تقدم أهداف

### 1.4 `_activeGoals` و `_masteredGoals` تستخدم `plan.progress`
- **الموقع**: `SpecialistDashboardScreen`
- **المشكلة**: تصنيف الأهداف إلى نشطة/متقنة يعتمد على `plan.progress` بدلاً من `goalProgress()`
- **التأثير**: أهداف تظهر في المكان الخطأ

### 1.5 `AssessmentImprovementSummary` غير معروض في ملف الطالب
- **الموقع**: `StudentProfileScreen`
- **المشكلة**: رغم وجود نموذج `AssessmentImprovementSummary` (يقارن آخر تقييمين عبر templateId)، لم يكن معروضاً في واجهة الطالب
- **النتيجة**: لا يوجد مؤشر تحسن سريري واضح للأهل والأخصائي

---

## 2. الإصلاحات المنفذة

### 2.1 `AppProvider.centerGoalImprovementRate` (السطور 109-115)
```
قبل:  avg(plan.progress for all plans of center students)
بعد:  avg(goalProgress(p.id) for all plans of center students)
```

### 2.2 `AppProvider.studentGoalAverageProgress` (السطور 124-131)
- أعيدت تسميته من `studentGoalImprovementRate` إلى `studentGoalAverageProgress`
```
قبل:  avg(plan.progress)
بعد:  avg(goalProgress(p.id))
```

### 2.3 `SpecialistDashboardScreen`
- تغيير تسمية "نسبة التحسن" إلى "متوسط تقدم أهداف طلابي"
- `_activeGoals`: `plan.progress < 100` ← `app.goalProgress(p.id) < 100`
- `_masteredGoals`: `plan.progress >= 100` ← `app.goalProgress(p.id) >= 100`

### 2.4 `StudentProfileScreen`
- تحديث استدعاء `studentGoalImprovementRate` إلى `studentGoalAverageProgress`
- إضافة `_ImprovementSummaryCard`: يعرض `AssessmentImprovementSummary` في قسم التقييم العلاجي
- إصلاح قوس إغلاق مفقود في `_ImprovementStat` (سبب 600+ خطأ تحليل)

---

## 3. الوضع الحالي (Single Source of Truth)

| المؤشر | المصدر | الوصف |
|--------|--------|-------|
| **تحسن الطالب** | `AssessmentImprovementSummary` | يقارن آخر تقييمين علاجيين. مستقل عن الجلسات والأهداف. |
| **تقدم الهدف** | `goalProgress(id)` | يحسب runtime من آخر جلسة / حالة المهارات. لا يعتمد على `plan.progress`. |
| **متوسط تقدم أهداف الأخصائي** | `centerGoalImprovementRate` (مُصلح) | `avg(goalProgress(id))` — مؤشر أداء وليس تحسناً |
| **متوسط تقدم أهداف الطالب** | `studentGoalAverageProgress` (مُسمّى جديداً) | `avg(goalProgress(id))` — مؤشر أداء وليس تحسناً |
| **حالة الهدف** | `goalStatus(id)` | يستخدم `goalProgress()` داخلياً |
| **تصنيف نشط/متقن** | `goalProgress(id) < 100 / >= 100` | موحّد في كل الشاشات |

### تدفق البيانات الآن
```
ClinicalAssessment + ClinicalFinding + templateId
        ↓
AssessmentImprovementSummary  ← التحسن السريري (وحيد)
        
TrainingPlan + GoalSkillStep + SessionSkillResult
        ↓
goalProgress()  ← تقدم الهدف (وحيد)
        ↓
goalStatus()  ← حالة الهدف (وحيد)
        ↓
centerGoalImprovementRate / studentGoalAverageProgress  ← متوسط الأداء
```

---

## 4. نتائج التحقق

- **`flutter analyze`**: 0 أخطاء، 1 تحذير غير متعلق (744 ← 105 issue، كلها info-level)
- **`flutter test`**: 49/49 نجاح (بما فيها اختبارات `AssessmentImprovementSummary` و `goalProgress()` الجديدة)
- **لم يتأثر**: اختبارات التكامل (48/48) لأنها لا تختبر `centerGoalImprovementRate` أو `studentGoalAverageProgress` مباشرة

---

## 5. نقاط لم يتم تغييرها

- **XP System**: لم يُمس — لا علاقة له بالمؤشرات
- **SessionSkillResult**: لم يُمس — `goalProgress()` تقرأ منه، لكن لا داعي لتغييره
- **GoalSkillStep**: لم يُمس — حالته (`status`) هو الذي يحدد progress
- **ClinicalAssessment**: لم يُمس — `AssessmentImprovementSummary` يقرأ منه فقط
- **PDF Reports**: لم تُمس
- **قاعدة البيانات**: لم تُغير — المنطق runtime فقط (`goalProgress()` لا تخزن)
- **التصميم**: لم يُغير — نفس الـ UI، فقط إضافة `_ImprovementSummaryCard` في ملف الطالب
