# [Superseded] Sanad App Architecture

> ⚠️ **This file is outdated.** Refer to `docs/project_master_reference.md` (Project Snapshot — June 2026) for the official architecture reference.

## Overview

Sanad is a speech therapy management system with role-based access, session tracking, homework management, clinical assessments, and goal progress tracking.

---

## User Roles

| Role | Permissions |
|------|-------------|
| `sanadOwner` | Full system access, multi-center management |
| `centerManager` | Manage center staff, students, view all data |
| `clinicalSupervisor` | View clinical data, supervise specialists |
| `therapyProgramEntry` | Manage therapy structure (programs, assessment templates) |
| `coordinator` | Assign students to specialists, basic student management |
| `specialist` | Run sessions, create assessments, manage homework, view assigned students |
| `dataEntry` | Basic student data entry |
| `parent` | View child profile, complete homework, view progress |

---

## Navigation Flow

```
AppShell (scaffold + bottom nav)
├── Dashboard (specialist dashboard)
├── Sessions
├── Homework
├── Student Profile
├── Settings
└── (role-dependent items)
```

### Nav Items by Role

| Role | Nav Items |
|------|-----------|
| Specialist | Dashboard, Sessions, Homework, Profile, Settings |
| Coordinator | Students, Assignments, Settings |
| Manager | Dashboard, Students, Staff, Programs, Settings |
| Parent | Child Profile, Homework, Settings |

---

## Providers

### AppProvider (ChangeNotifier)

Central state management. Holds:
- **User & Role**: `user`, `isSpecialist`, `isParent`, etc.
- **Students**: `students` (filtered by role), `selectedStudent`
- **Sessions**: `sessions` (per-student), `centerSessions` (all specialist students)
- **Plans/Goals**: `plans`, `centerPlans`, `goalSkillSteps`
- **Exercises**: `exercises`, `centerExercises`
- **Assessments**: `clinicalAssessments`, `centerClinicalAssessments`
- **Followups**: `studentFollowups`, `centerStudentFollowups`
- **Preselect**: `sessionPreselect` (for retrain flow)

Key Methods:
- `loadHome()` — initial load, filters students for specialist
- `selectStudent(student)` — loads per-student data
- `saveSession()` — saves session with optional autosave
- `saveClinicalAssessment()` — creates assessment + auto-generates plans/steps
- `upsertFollowup()` — creates/updates pending followup
- `resolveFollowupForStep()` — closes followup on mastery

---

## Data Models

### TherapySession
- Linked to: student, session plan, specialist
- Key fields: `studentId`, `specialistId`, `planId`, `successRate`, `startedAt`
- specialistId added in v25 migration

### TrainingPlan
- A goal/plan for a student
- Linked to: student, program
- Key fields: `studentId`, `goal`, `progress` (0-100), `programId`, `sourceType`

### GoalSkillStep
- A step within a TrainingPlan
- Linked to: plan (via goalId)
- Key fields: `goalId`, `title`, `status` (لم يبدأ/متقن/بمساعدة/يحتاج إعادة)

### Exercise
- A homework assignment
- Linked to: student, optionally plan + step
- Key fields: `studentId`, `status`, `planId`, `goalSkillStepId`
- Statuses: `pending`, `completed_by_parent`, `specialist_reviewed`

### ClinicalAssessment
- Initial clinical evaluation
- Linked to: student, specialist
- Auto-generates TrainingPlans + GoalSkillSteps from abnormal findings

### StudentFollowup
- Tracks steps needing retrain
- Linked to: student, specialist, step
- Key fields: `goalSkillStepId`, `reason` (assisted/retry), `status` (pending/completed)
- Created on "بمساعدة" or "يحتاج إعادة" evaluation
- Resolved on "متقن" evaluation
- Created in v26 migration

### StudentSpecialist
- Join table linking students to specialists
- Key fields: `studentId`, `specialistId`, `isActive`

---

## Sessions Flow

1. User selects student → program → source type
2. System loads plans/steps for student
3. `_findCurrent()` identifies next unmastered step
4. Evaluation buttons: متقن / بمساعدة / يحتاج إعادة
5. On evaluation:
   - Update GoalSkillStep.status
   - Create/close StudentFollowup
   - Record TherapySession (with specialistId)
   - Advance to next step
6. End-of-path: show "تم إنهاء المسار" + option to pick another

---

## Homework Flow

1. Navigate to Homework screen
2. Select student → type (linked/free)
3. For linked: select goal → select skill → fill form
4. For free: fill form directly
5. Save Exercise with `createdFromSessionResult: 'homework'`
6. Parent sees homework, completes it (`completed_by_parent`)
7. Specialist reviews and approves (`specialist_reviewed`)

---

## Followup / Retrain Flow

1. During session, on "بمساعدة" or "يحتاج إعادة":
   - `upsertFollowup()` creates/updates a StudentFollowup (reason=assisted/retry)
2. On "متقن":
   - `resolveFollowupForStep()` closes any pending followup for that step
3. **Student Profile**: `_FollowupsSection` shows all pending followups
4. **Retrain button**: Sets `sessionPreselect` → navigates to Sessions → `_applyPreselect()` opens exact step
5. Followup persists in DB, not dependent on lifecycle or sessionPreselect timing

---

## Assessment Flow

1. Specialist creates ClinicalAssessment (with findings)
2. Each abnormal finding auto-generates:
   - TrainingPlan (progress=0)
   - GoalSkillSteps (from skill step templates)
3. Assessment appears in student profile
4. Student exits "يحتاج تقييم" list in dashboard

---

## Specialization & Filtering

- **Students per specialist**: Filtered via `StudentSpecialist` join table
- **Sessions per specialist**: Filtered by `TherapySession.specialistId`
- **Dashboard stats**: Only show data for current specialist's students + their sessions
- **Improvement rate**: Calculated from `TrainingPlan.progress`, not session `successRate`

---

## DB Schema

Current version: **26**

Tables:
- `users`, `centers`, `students`, `parents`
- `sessions`, `evaluations`, `training_plans`, `goal_skill_steps`
- `exercises`, `rewards`, `reports`
- `clinical_assessments`, `clinical_findings`
- `student_specialists`
- `student_followups` (v26)
- `therapy_programs`, `assessment_sections`, `assessment_items`, `assessment_options`
- `skill_step_templates`, `speech_sound_triggers`, `sign_resources`
- `audit_logs`, `notifications`, `student_therapy_programs`
