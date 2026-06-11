> ⚠️ **هذا الملف قديم (كان أداة تعقب مؤقتة).** الرجاء الرجوع إلى `docs/project_master_reference.md` للمرجع الرسمي الشامل.

## Goal
Implement a stable guided clinical sessions flow with three-button evaluation, auto-homework, and auto-advancement across goals/steps, plus a major architectural refactor to bind students to therapy programs, filter content by `sourceType`, and centralize student management through the data-entry screen.

## Constraints & Preferences
- `Expanded` MUST NOT be used inside a `Column` inside a `SingleChildScrollView` (→ `RenderFlex unbounded constraints` → blank screen in release mode).
- `context.read<AppProvider>()` may return `null` in `dispose()` → always cache reference before `dispose`.
- Student CRUD is exclusive to the data-entry screen (secretary role); the Students screen is readonly.
- Every student must be assigned one or more therapy programs at registration time (via data-entry screen).
- The Assessment Wizard must show only programs linked to the current student (via `studentProgramIds`).
- All clinical findings, training plans, and goal skill steps must carry `programId` + `sourceType` (`standard` or `speechSound`).
- The Guided Sessions screen must let the specialist pick which program to work on, then filter goals/steps by `sourceType` based on that program.
- Three-button logic: متقن → mark step `completed` + advance; بمساعدة → mark + auto-homework + advance; يحتاج إعادة → mark + auto-homework + advance.
- Homework (Exercise) must be linked to `studentId`, `programId`, `planId`, `goalSkillStepId`, `sourceType`, and `sessionDate`.
- Sorting must use `sort_order` (not `createdAt`) + program/source filters.

## Progress
### Done
- **Blank screen root cause fixed**: `Expanded` removed from wizard `Column`; nested `SingleChildScrollView` removed from phase widgets.
- **Removed responseType dropdown** from Therapy Structure Builder; `responseMode` saved via `normalized` in `saveAssessmentItemTemplate`.
- **Multi Response UI rebuilt**: each option shows independent "نعم" / "لا" buttons.
- **Wizard step-by-step navigation** with `_buildSteps()`, `_WizardProgressHeader`, and `LinearProgressIndicator`.
- **`AssessmentDraft` model** with JSON columns; v16-v18 DB migrations.
- **Auto-save draft** on step change, lifecycle pause/inactive, and dispose; `_restoreFromDraft` with resume dialog.
- **Sound evaluation phase rewritten** to one-letter-at-a-time with normal/error/position flow.
- **Therapy Structure Builder sound tab**: skill-steps entered per-trigger via "إضافة مهارة" button; inline edit/delete.
- **`_skillStepTemplatesForFinding`** (provider) falls back to inline `trigger.skillStepTemplates`.
- **Session screen: auto-advancement bug fixed** — `updateGoalSkillStepStatus` now updates `goalSkillSteps[idx]` in-memory + calls `notifyListeners()`; `_syncGoalProgress` updates `plans[idx]` in-memory.
- **DB migration v19**: new `student_therapy_programs` table; `program_id` + `source_type` columns on `training_plans`, `goal_skill_steps`, `clinical_findings`, `exercises`.
- **StudentTherapyProgram model** added.
- **Updated models**: `TrainingPlan`, `GoalSkillStep`, `ClinicalFinding`, `Exercise` — added `programId`, `sourceType` (and `planId`, `goalSkillStepId`, `sessionDate` on Exercise).
- **Repository**: `plansForProgram`, `goalStepsForProgramAndSource`, `studentProgramIds`, `studentTherapyPrograms`, `saveStudentTherapyProgram`, `removeStudentTherapyProgram`.
- **Provider**: `studentProgramIds` field loaded in `selectStudent`; `assignStudentProgram`, `unassignStudentProgram`, `programsForStudent()` methods; `saveClinicalAssessment` passes `programId` + `sourceType` to plans and steps.
- **Students screen**: made readonly — removed "إضافة طالب", "تعديل", `_showStudentForm`, `_showCredentialsDialog`, `_normalizePhone`, unused imports.
- **Assessment wizard**: `_ProgramSelectPhase` uses `app.programsForStudent()` (filtered by assigned programs); shows `EmptyState` when no programs assigned; all three `ClinicalFinding(...)` creation sites include `programId` + `sourceType`.
- **Data-entry screen**: added "البرامج العلاجية" button per student card → `_manageStudentPrograms` dialog with checkboxes for all `therapyPrograms` → `assignStudentProgram`/`unassignStudentProgram`.
- **Sessions screen redesigned**: 
  - Program picker → source type picker (auto-skipped for non-speech programs) → session view
  - `_filteredPlans` / `_filteredSteps` filter by `programId` + `sourceType`
  - Three-button evaluation (`_evaluate`) + auto-homework with full linkage (`programId`, `planId`, `goalSkillStepId`, `sourceType`, `sessionDate`)
  - `_findCurrent()` iterates filtered plans/steps, finds first non-`متقن` step
  - Handles edge cases: no plans, no assigned programs, all mastered.
- **Analyzer clean**: all unused imports removed, `const` constructors added, `flutter analyze` → 0 issues.

## Key Decisions
- `Expanded` + `SingleChildScrollView` → `RenderFlex unbounded constraints` → blank screen in release mode. Never nest in the same axis.
- `updateGoalSkillStepStatus` must update in-memory state + `notifyListeners`, not just the DB, so `_findCurrent` reads fresh data.
- Student management is centralized in the data-entry screen (secretary role) — the therapist's Students screen becomes readonly.
- `saveClinicalAssessment` derives `sourceType` from the selected program's `usesSpeechSounds` flag (`true` → `speechSound`, `false` → `standard`). Sound-trigger findings always use `sourceType = 'speechSound'` because they come from the speech-sound trigger table.
- Homework (Exercise) links back to `programId`, `planId`, `goalSkillStepId`, `sourceType`, and `sessionDate` to allow the parent dashboard and future reports to show context.
- Programs without `usesSpeechSounds` auto-set `sourceType = 'standard'` on selection (skips the source-type picker).
- Sessions screen `_findCurrent()` iterates all filtered plans/steps sorted by `createdAt`; picks the first non-متقن step.

## Relevant Files
- **`lib/screens/sessions_screen.dart`**: full redesign — program picker, source type picker (if speech-sound), filtered goal+step session, three-button evaluation, auto-homework with full linkage.
- **`lib/providers/app_provider.dart`**: `updateGoalSkillStepStatus` (in-memory fix), `studentProgramIds`, `programsForStudent()`, `assignStudentProgram`, `unassignStudentProgram` — entry point for all session/assignment logic.
- **`lib/repositories/sanad_repository.dart`**: `plansForProgram`, `goalStepsForProgramAndSource`, `studentProgramIds`, `saveStudentTherapyProgram`, `removeStudentTherapyProgram` — new filtered queries.
- **`lib/services/database_service.dart`**: v19 migration — `student_therapy_programs` table + new columns on 4 existing tables.
- **`lib/models/app_models.dart`**: `StudentTherapyProgram` (new); `TrainingPlan`, `GoalSkillStep`, `ClinicalFinding`, `Exercise` (updated with `programId`/`sourceType`/etc).
- **`lib/screens/students_screen.dart`**: readonly — no add/edit buttons, unused imports removed.
- **`lib/screens/data_entry_screen.dart`**: therapy-program multi-select via `_manageStudentPrograms` dialog on each student card.
- **`lib/screens/clinical_assessment_wizard_screen.dart`**: `_ProgramSelectPhase` uses `app.programsForStudent()`; all three `ClinicalFinding(...)` calls include `programId` + `sourceType`.
