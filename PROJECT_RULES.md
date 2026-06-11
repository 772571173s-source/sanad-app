# Project Rules — Sanad App

## Core Principles

1. **No new features before core flows are stable.** Assessment → Goals → Sessions → Retrain → Homework must work flawlessly on both platforms.
2. **Every modification tested on Android AND Windows.** Never assume one platform's behavior.
3. **Always run `flutter analyze` and `flutter test` before any deploy.**
4. **Never change `sourceType` or `programId` semantics.** These are the linking keys between assessment, plans, steps, and sessions.
5. **Never re-link homework to sessions automatically.** Homework is created ONLY from HomeworkScreen.
6. **All DB migrations must be additive only.** No column drops or destructive operations.
7. **Never hide real save errors.** If a save fails, the user must know.
8. **Do not commit changes unless explicitly asked.**
9. **Do not create documentation files unless explicitly asked** (exceptions exist for PROJECT_RULES, FLOWS_REPORT, etc. if requested).
10. **Before adding a new library, check if it's already used in the codebase.**

---

## Schema & Migration Rules

1. **Any new column must be added in 3 places:**
   - `_createSchema()` — for new databases
   - `_upgrade()` with `if (oldVersion < X)` — for existing databases
   - `_ensureLatestSchema()` map — for databases that missed the migration

2. **Additive-only migrations:** Never drop columns or tables. `_dropLegacyProgramTables` (v10) is the sole exception.

3. **Increase `currentVersion`** only when schema actually changes.

4. **New table checklist:**
   - `CREATE TABLE` in `_createSchema()`
   - `_ensureTable()` in `_upgrade()` with new version
   - Table definition in `_ensureLatestSchema()` map
   - `Model.fromMap()` / `Model.toMap()` in `app_models.dart`
   - CRUD methods in `sanad_repository.dart`
   - Load/save methods in `app_provider.dart`
   - Increment `currentVersion` at top of `database_service.dart`

5. **`_ensureLatestSchema` runs on every `onOpen`** — it's the safety net for any missed migrations.

---

## State Management Rules

1. **`AppProvider` is a single monolithic `ChangeNotifier`.** Be aware that any `notifyListeners()` rebuilds all consumers.
2. **Prefer targeted updates over full reloads:**
   - ✅ Targeted: modify local list in-place + `notifyListeners()`
   - ✅ Targeted reload: re-fetch from repository + `notifyListeners()`
   - ❌ Full reload: `selectStudent()` or `loadHome()` — heavy, avoid after every save
3. **Many methods still call `selectStudent()` unnecessarily.** This is a known tech debt. Fix them gradually.
4. **Do NOT call `setState` from inside `build()`.** Use `initState` + `addPostFrameCallback`.

---

## Sessions Rules

1. Sessions screen has 5 phases: Student → Program → Source Type → Session View → Path Complete
2. Three evaluation buttons (`متقن` / `بمساعدة` / `يحتاج إعادة`) only update status and record session.
3. **NO automatic homework creation from session evaluation buttons.**
4. `_findCurrent()` excludes steps with status: `متقن`, `بمساعدة`, `يحتاج إعادة`.
5. `_findCurrent()` also excludes steps already in `_evaluatedStepIds` (same-session exclusion).
6. `_evaluatedStepIds` is cleared on: program change, source type change, back navigation, full reset.
7. `_evaluatedStepIds` is NOT cleared on "choose another path" (only source type changes).
8. `setState` must NOT be called from inside `build()` — use `initState` + `addPostFrameCallback`.
9. `_applyPreselect()` runs from `initState` → `addPostFrameCallback`, not from `build()`.
10. On end-of-path: show `_buildPathComplete()` with "انتهت عناصر هذه الجلسة" + "اختيار مسار آخر" button.
11. Back button steps back one phase at a time.
12. **BUG GUARD:** `steps.every((s) => s.status == 'متقن')` returns `true` for empty list. Always check `steps.isNotEmpty` first.

---

## Assessment Rules

1. `sourceType` = `'standard'` for assessment items, `'speechSound'` for speech sound triggers.
2. `programId` = `selectedProgram?.id ?? ''` (from the wizard).
3. These values propagate: ClinicalFinding → TrainingPlan → GoalSkillStep.
4. Only non-normal findings with non-empty `goal` generate plans.
5. `targetDate` is always 45 days from creation.
6. Drafts auto-save on every step change, lifecycle pause, and dispose.
7. Drafts are deleted after successful save.
8. Draft composite PK: `(student_id, program_id)` — one draft per student+program.

---

## Followup Rules

1. `StudentFollowup` is the canonical source for retrain tracking — NOT `GoalSkillStep.status` alone.
2. Created on "بمساعدة" (reason=`assisted`) and "يحتاج إعادة" (reason=`retry`).
3. Closed on "متقن" (status=`completed`, `resolvedAt` filled).
4. Use upsert — check for existing pending followup before creating duplicate.
5. Student profile `_FollowupsSection` shows all pending followups with retrain buttons.
6. Retrain uses `sessionPreselect` for navigation but followup persists in DB independently.
7. `pendingFollowups` getter filters `studentFollowups.where((f) => f.status == 'pending')`.

---

## Retrain Button Rules

1. **Decision logic (in `_GoalProgressSection`):**
   - `needsRetrain = app.pendingFollowups.any(f => f.goalSkillStepId == step.id && f.status == 'pending')`
   - DO NOT check `step.status` for retrain visibility.
2. Plan-level retrain: show button if `steps.isEmpty && plan.treatment.isNotEmpty && plan.progress < 100`.
3. `sessionPreselect` map: `{studentId, programId, sourceType, planId, stepId}` — used only for retrain navigation.

---

## Navigation Rules

1. `sessionPreselect` is used ONLY for retrain navigation (temporary, cleared after application).
2. Preselect map: `{studentId, programId, sourceType, planId, stepId}`.
3. `onOpenSession` callback navigates to sessions tab.
4. Back navigation respects context: source type → program → student (not full reset).

---

## Responsive Design Rules

1. **Mobile-first**: All layouts must work at 320px width minimum.
2. **NO `Expanded` inside `Column` inside `SingleChildScrollView`**: Causes silent `RenderFlex unbounded constraints` → white screen in release mode.
3. Use `LayoutBuilder` for responsive breakpoints:
   - 380px: goal progress card (narrow/wide layout)
   - 500px: student cards
   - 460px: source type picker
   - 400px: evaluation buttons
   - 720px: ResponsiveGrid (1→2 columns)
   - 1100px: ResponsiveGrid (2→3 columns)
   - 760px: Dashboard hero compact layout
   - 980px: Dashboard timeline/attention side-by-side
4. `Wrap` for all chip/pill collections (not hardcoded `Row`).
5. All dynamic `Text` must have `maxLines` + `overflow: TextOverflow.ellipsis`.
6. No vertical text (rotated labels).
7. No crowded `Row`s on narrow screens — use `Column` + `LayoutBuilder`.

---

## Statistics & Dashboard Rules

1. **Specialist statistics filter by `specialistId`** on `TherapySession`, not just student association.
2. **Improvement rate** calculated from `TrainingPlan.progress` and `GoalSkillStep` mastery, not from session `successRate`.
3. **Students needing assessment**: no `ClinicalAssessment` exists for that student.
4. **Assessment status**: If no assessment or no goals/plans, show "يحتاج تقييم" instead of fake percentage.
5. Dashboard shows data for current specialist only (filtered via `StudentSpecialist` join table).
6. `app.goalProgress(planId)` computes progress from GoalSkillStep statuses (not hardcoded).

---

## Homework Rules

1. Homework is created ONLY from `HomeworkScreen` — never auto-created from sessions.
2. All exercises get `createdFromSessionResult: 'homework'`.
3. Homework screen: 5 phases (Student → Type → Goal → Skill → Form).
4. No `Expanded` in homework screen layout.
5. TextEditingController for date field must be persistent (not inline).
6. Status flow: `pending` → `completed_by_parent` → `specialist_reviewed`.

---

## Code Style Rules

1. Match existing code style (naming, patterns, imports).
2. Use `LayoutBuilder` + `constraints.maxWidth` for responsive layouts.
3. No comments in code unless absolutely necessary for clarity.
4. Use `sanad` prefix for app-specific naming (SanadPalette, SanadText, etc.).
5. All durations are ISO 8601 strings. All dates are `yyyy-MM-dd`.
6. Arabic text uses RTL (`TextDirection.rtl` at app level).

---

## Platform-Specific Rules

1. **Android**: `sqflite` (mobile), standard Flutter build.
2. **Windows**: `sqflite_common_ffi` (desktop), requires `flutter build windows`.
3. **Database path**: different per platform. Both use `sanad_mvp.db`.
4. **File picker**: works on both. Test `file_picker` behavior on Windows.
5. **PDF/Printing**: tested on Android. Windows needs explicit testing.
6. **Do NOT change Gradle/Android config unless absolutely necessary.**
7. **Hot reload** works for UI changes. **Hot restart** needed for state reset. **Full rebuild** for platform-specific changes.

---

## Testing Checklist

### Every deploy:
- [ ] `flutter analyze` — no errors (infos allowed for tool scripts)
- [ ] `flutter test` — 33/33 all passed
- [ ] Build Android: `flutter build apk --debug` or `flutter run`
- [ ] Build Windows: `flutter build windows --debug`

### Core flows (test on both platforms):
- [ ] Retrain flow: profile → button → exact step opens → evaluate → state correct
- [ ] End-of-path: all steps done → path complete → choose another path
- [ ] Assessment → goals appear in sessions immediately
- [ ] No session looping after evaluation
- [ ] Empty steps plan (no GoalSkillSteps) still appears in sessions
- [ ] Homework: student → type → goal → skill → form → send → appears in profile
- [ ] Student profile homework: pending → completed_by_parent → specialist_reviewed

### Layout:
- [ ] 320/360/390/430/tablet/desktop — no overflow, no white screens
- [ ] No `RenderFlex overflowed` errors in logs

### Statistics:
- [ ] Needs assessment: coordinator assigns → specialist sees "يحتاج تقييم" → assess → disappears
- [ ] Improvement: no assessment → "يحتاج تقييم"; with goals → real percentage from progress
- [ ] Specialist sessions: only this specialist's sessions counted

---

## Known Issues & Risks

1. **`selectStudent()` called after many saves** — causes unnecessary full reload. Affected: `saveSession`, `saveEvaluation`, `savePlan`, `saveGoalSkillStep`, `saveExercise`, `saveReward`, `saveClinicalAssessment`, `printReport*`.
2. **`loadHome()` is heavy** — acceptable on login, but should not be called during normal operation.
3. **`app.goalProgress()` derivation logic** — needs verification that it correctly counts mastered steps.
4. **No integration tests for full flows** — only CRUD unit tests exist.
5. **`_ensureLatestSchema()` runs on every open** — safety net is good, but adds ~200ms to startup on large DBs.
6. **`_repairStoredArabicText()` on every open** — may be unnecessary if all data is already fixed. Could be optimized to run once.
7. **Auto-save on every assessment step** — frequent DB writes. OK for now but may cause lag on slow devices.
8. **`clearAllData()` for testing** — safe on development, but should never be exposed in production.
