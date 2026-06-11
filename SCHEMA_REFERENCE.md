# Database Schema Reference — Sanad App

## Purpose
Single source of truth for the SQLite database schema across all platforms (Windows, Android, Linux, macOS).

## DB Version: 31
Current version defined in `DatabaseService.currentVersion`.

---

## Table Index

| # | Table | Created in `_createSchema` | Also created in migration |
|---|-------|---------------------------|---------------------------|
| 1 | `centers` | Yes | v3 `_ensureMigrationTables` |
| 2 | `users` | Yes | (always exists) |
| 3 | `students` | Yes | (always exists) |
| 4 | `parents` | Yes | v3 `_ensureMigrationTables` |
| 5 | `sessions` | Yes | (always exists) |
| 6 | `evaluations` | Yes | v3 `_ensureMigrationTables` |
| 7 | `training_plans` | Yes | (always exists) |
| 8 | `goal_skill_steps` | Yes (via `_createGoalSkillStepsTable`) | v9 `_ensureGoalSkillStepsTable` |
| 9 | `exercises` | Yes | v3 `_ensureMigrationTables` |
| 10 | `rewards` | Yes | v3 `_ensureMigrationTables` |
| 11 | `reports` | Yes | v3 `_ensureMigrationTables` |
| 12 | `clinical_assessments` | Yes (via `_createClinicalAssessmentTables`) | v8 `_ensureClinicalAssessmentTables` |
| 13 | `clinical_findings` | Yes (via `_createClinicalAssessmentTables`) | v8 `_ensureClinicalAssessmentTables` |
| 14 | `therapy_program_templates` | Yes (via `_createTherapyStructureTables`) | v12 `_ensureTherapyStructureTables` |
| 15 | `assessment_section_templates` | Yes (via `_createTherapyStructureTables`) | v12 `_ensureTherapyStructureTables` |
| 16 | `assessment_item_templates` | Yes (via `_createTherapyStructureTables`) | v12 `_ensureTherapyStructureTables` |
| 17 | `assessment_option_templates` | Yes (via `_createTherapyStructureTables`) | v12 `_ensureTherapyStructureTables` |
| 18 | `skill_step_templates` | Yes (via `_createTherapyStructureTables`) | v12 `_ensureTherapyStructureTables` |
| 19 | `speech_sound_trigger_templates` | Yes (via `_createTherapyStructureTables`) | v12 `_ensureTherapyStructureTables` |
| 20 | `sign_resources` | Yes | v2 `_ensureTable` |
| 21 | `audit_logs` | Yes | v5 `_ensureTable` |
| 22 | `student_therapy_programs` | Yes | v19 `_ensureTable` |
| 23 | `assessment_drafts` | Yes | v16 `_ensureAssessmentDraftTable` |
| 24 | `student_specialists` | Yes | v23 `_ensureTable` |
| 25 | `student_followups` | Yes | v26 `_ensureTable` |

---

## Table Schemas

### 1. centers

| Column | Type | Nullable | Default | Used in model `toMap()` |
|--------|------|----------|---------|------------------------|
| id | TEXT | NO | — | yes |
| name | TEXT | NO | — | yes |
| logo_path | TEXT | NO | '' | yes |
| address | TEXT | NO | '' | yes |
| phone | TEXT | NO | '' | yes |
| manager_name | TEXT | NO | '' | yes |
| is_active | INTEGER | NO | 1 | yes (bool→0/1) |
| created_at | TEXT | NO | — | yes |
| updated_at | TEXT | NO | — | yes |

### 2. users

| Column | Type | Nullable | Default | Used in model `toMap()` |
|--------|------|----------|---------|------------------------|
| id | TEXT | NO | — | yes |
| center_id | TEXT | NO | '' | yes |
| email | TEXT | NO | — (UNIQUE) | yes |
| password_hash | TEXT | NO | — | yes |
| name | TEXT | NO | — | yes |
| role | TEXT | NO | — | yes |
| student_id | TEXT | YES | — | yes (nullable) |
| force_password_change | INTEGER | NO | 0 | yes (bool→0/1) |
| is_demo | INTEGER | NO | 0 | yes (bool→0/1) |
| is_active | INTEGER | NO | 1 | yes (bool→0/1) |
| created_at | TEXT | NO | — | yes |
| updated_at | TEXT | NO | — | yes |

### 3. students

| Column | Type | Nullable | Default | Used in model `toMap()` |
|--------|------|----------|---------|------------------------|
| id | TEXT | NO | — | yes |
| center_id | TEXT | NO | — (FK→centers) | yes |
| name | TEXT | NO | — | yes |
| age | INTEGER | NO | — | yes |
| status | TEXT | NO | — | yes |
| diagnosis | TEXT | NO | — | yes |
| program_type | TEXT | NO | 'نطق وتخاطب' | yes |
| parent_name | TEXT | NO | — | yes |
| parent_phone | TEXT | NO | — | yes |
| portal_email | TEXT | NO | — | yes |
| portal_password | TEXT | NO | — | yes |
| photo_path | TEXT | NO | — | yes |
| notes | TEXT | NO | — | yes |
| deleted_at | TEXT | NO | '' | yes |
| created_at | TEXT | NO | — | yes |
| updated_at | TEXT | NO | — | yes |

### 4. parents

| Column | Type | Nullable | Default | Used in model `toMap()` |
|--------|------|----------|---------|------------------------|
| id | TEXT | NO | — | yes |
| center_id | TEXT | NO | '' (FK→centers) | yes |
| student_id | TEXT | NO | — (FK→students) | yes |
| name | TEXT | NO | — | yes |
| phone | TEXT | NO | — | yes |
| email | TEXT | NO | — | yes |
| created_at | TEXT | NO | '' | **NO** — model omits |
| updated_at | TEXT | NO | '' | **NO** — model omits |

### 5. sessions

| Column | Type | Nullable | Default | Used in model `toMap()` |
|--------|------|----------|---------|------------------------|
| id | TEXT | NO | — | yes |
| center_id | TEXT | NO | '' (FK→centers) | yes |
| student_id | TEXT | NO | — (FK→students) | yes |
| specialist_id | TEXT | NO | '' | yes |
| plan_id | TEXT | NO | '' | yes |
| program_id | TEXT | NO | '' | yes |
| skill_id | TEXT | NO | '' | yes |
| activity_results | TEXT | NO | '' | yes |
| session_type | TEXT | NO | 'نطق وتخاطب' | yes |
| target_letter | TEXT | NO | '' | yes |
| letter_position | TEXT | NO | '' | yes |
| error_type | TEXT | NO | '' | yes |
| practice_items | TEXT | NO | '' | yes |
| attempts | INTEGER | NO | 0 | yes |
| success_rate | INTEGER | NO | 0 | yes |
| started_at | TEXT | NO | — | yes |
| duration_seconds | INTEGER | NO | — | yes |
| card_title | TEXT | NO | — | yes |
| quick_result | TEXT | NO | — | yes |
| notes | TEXT | NO | — | yes |
| summary | TEXT | NO | '' | yes |
| created_at | TEXT | NO | — | yes |
| updated_at | TEXT | NO | — | yes |

### 6. evaluations

| Column | Type | Nullable | Default | Used in model `toMap()` |
|--------|------|----------|---------|------------------------|
| id | TEXT | NO | — | yes |
| center_id | TEXT | NO | '' (FK→centers) | yes |
| student_id | TEXT | NO | — (FK→students) | yes |
| letter | TEXT | NO | — | yes |
| position | TEXT | NO | — | yes |
| error_type | TEXT | NO | — | yes |
| score | TEXT | NO | — | yes |
| severity | INTEGER | NO | 1 | yes |
| recommendation | TEXT | NO | '' | yes |
| created_at | TEXT | NO | — | yes |
| updated_at | TEXT | NO | '' | yes |
| notes | TEXT | NO | — | yes |

### 7. training_plans

| Column | Type | Nullable | Default | Used in model `toMap()` |
|--------|------|----------|---------|------------------------|
| id | TEXT | NO | — | yes |
| center_id | TEXT | NO | '' (FK→centers) | yes |
| student_id | TEXT | NO | — (FK→students) | yes |
| goal | TEXT | NO | — | yes |
| treatment | TEXT | NO | '' | yes |
| target_date | TEXT | NO | — | yes |
| progress | INTEGER | NO | — | yes |
| program_id | TEXT | NO | '' | yes |
| source_type | TEXT | NO | 'standard' | yes |
| created_at | TEXT | NO | '' | yes |
| updated_at | TEXT | NO | '' | yes |

### 8. goal_skill_steps

| Column | Type | Nullable | Default | Used in model `toMap()` |
|--------|------|----------|---------|------------------------|
| id | TEXT | NO | — | yes |
| center_id | TEXT | NO | — (FK→centers) | yes |
| student_id | TEXT | NO | — (FK→students) | yes |
| goal_id | TEXT | NO | — (FK→training_plans) | yes |
| title | TEXT | NO | — | yes |
| status | TEXT | NO | 'لم يبدأ' | yes |
| sort_order | INTEGER | NO | 0 | yes |
| notes | TEXT | NO | '' | yes |
| last_session_id | TEXT | NO | '' | yes |
| program_id | TEXT | NO | '' | yes |
| source_type | TEXT | NO | 'standard' | yes |
| created_at | TEXT | NO | — | yes |
| updated_at | TEXT | NO | — | yes |

### 9. exercises

| Column | Type | Nullable | Default | Used in model `toMap()` |
|--------|------|----------|---------|------------------------|
| id | TEXT | NO | — | yes |
| center_id | TEXT | NO | '' (FK→centers) | yes |
| student_id | TEXT | NO | — (FK→students) | yes |
| title | TEXT | NO | — | yes |
| instructions | TEXT | NO | — | yes |
| due_date | TEXT | NO | — | yes |
| status | TEXT | NO | — | yes |
| audio_path | TEXT | NO | — | yes |
| program_id | TEXT | NO | '' | yes |
| plan_id | TEXT | NO | '' | yes |
| goal_skill_step_id | TEXT | NO | '' | yes |
| source_type | TEXT | NO | 'standard' | yes |
| session_date | TEXT | NO | '' | yes |
| parent_note | TEXT | NO | '' | yes |
| note_for_parent | TEXT | NO | '' | yes |
| parent_completed_at | TEXT | NO | '' | yes |
| specialist_reviewed_at | TEXT | NO | '' | yes |
| created_from_session_result | TEXT | NO | '' | yes |
| stars | INTEGER | NO | 0 | yes |
| created_at | TEXT | NO | '' | yes |
| updated_at | TEXT | NO | '' | yes |

### 10. rewards

| Column | Type | Nullable | Default | Used in model `toMap()` |
|--------|------|----------|---------|------------------------|
| id | TEXT | NO | — | yes |
| center_id | TEXT | NO | '' (FK→centers) | yes |
| student_id | TEXT | NO | — (FK→students) | yes |
| xp | INTEGER | NO | — | yes |
| level | INTEGER | NO | — | yes |
| badges | TEXT | NO | — | yes |
| daily_streak | INTEGER | NO | — | yes |
| created_at | TEXT | NO | '' | **NO** — model omits |
| updated_at | TEXT | NO | '' | **NO** — model omits |

### 11. reports

| Column | Type | Nullable | Default | Used in model `toMap()` |
|--------|------|----------|---------|------------------------|
| id | TEXT | NO | — | yes |
| center_id | TEXT | NO | '' (FK→centers) | yes |
| student_id | TEXT | NO | — (FK→students) | yes |
| type | TEXT | NO | — | yes |
| created_at | TEXT | NO | — | yes |
| improvement_rate | INTEGER | NO | — | yes |
| specialist_signature | TEXT | NO | — | yes |
| manager_signature | TEXT | NO | '' | yes |
| file_path | TEXT | NO | '' | yes |
| updated_at | TEXT | NO | '' | yes |

### 12. clinical_assessments

| Column | Type | Nullable | Default | Used in model `toMap()` |
|--------|------|----------|---------|------------------------|
| id | TEXT | NO | — | yes |
| center_id | TEXT | NO | — (FK→centers) | yes |
| student_id | TEXT | NO | — (FK→students) | yes |
| specialist_id | TEXT | NO | '' | yes |
| specialist_name | TEXT | NO | '' | yes |
| type | TEXT | NO | 'speech' | yes |
| strengths_summary | TEXT | NO | '' | yes |
| weaknesses_summary | TEXT | NO | '' | yes |
| goals_summary | TEXT | NO | '' | yes |
| training_summary | TEXT | NO | '' | yes |
| created_at | TEXT | NO | — | yes |
| updated_at | TEXT | NO | — | yes |

### 13. clinical_findings

| Column | Type | Nullable | Default | Used in model `toMap()` |
|--------|------|----------|---------|------------------------|
| id | TEXT | NO | — | yes |
| assessment_id | TEXT | NO | — (FK→clinical_assessments) | yes |
| center_id | TEXT | NO | — (FK→centers) | yes |
| student_id | TEXT | NO | — (FK→students) | yes |
| domain | TEXT | NO | — | yes |
| item_title | TEXT | NO | — | yes |
| result | TEXT | NO | — | yes |
| is_normal | INTEGER | NO | 0 | yes (bool→0/1) |
| weakness | TEXT | NO | '' | yes |
| goal | TEXT | NO | '' | yes |
| training | TEXT | NO | '' | yes |
| program_id | TEXT | NO | '' | yes |
| source_type | TEXT | NO | 'standard' | yes |
| created_at | TEXT | NO | — | yes |
| updated_at | TEXT | NO | — | yes |

### 14. therapy_program_templates

| Column | Type | Nullable | Default | Used in model `toMap()` |
|--------|------|----------|---------|------------------------|
| id | TEXT | NO | — | yes |
| center_id | TEXT | NO | '' | yes |
| name | TEXT | NO | — | yes |
| description | TEXT | NO | '' | yes |
| uses_speech_sounds | INTEGER | NO | 0 | yes (bool→0/1) |
| sort_order | INTEGER | NO | 0 | yes |
| created_at | TEXT | NO | — | yes |
| updated_at | TEXT | NO | — | yes |

### 15. assessment_section_templates

| Column | Type | Nullable | Default | Used in model `toMap()` |
|--------|------|----------|---------|------------------------|
| id | TEXT | NO | — | yes |
| center_id | TEXT | NO | '' | yes |
| program_id | TEXT | NO | '' | yes |
| title | TEXT | NO | — | yes |
| description | TEXT | NO | '' | yes |
| sort_order | INTEGER | NO | 0 | yes |
| created_at | TEXT | NO | — | yes |
| updated_at | TEXT | NO | — | yes |

### 16. assessment_item_templates

| Column | Type | Nullable | Default | Used in model `toMap()` |
|--------|------|----------|---------|------------------------|
| id | TEXT | NO | — | yes |
| center_id | TEXT | NO | '' | yes |
| section_id | TEXT | NO | — (FK→assessment_section_templates) | yes |
| title | TEXT | NO | — | yes |
| response_type | TEXT | NO | 'custom' | yes |
| response_mode | TEXT | NO | 'singleChoice' | yes |
| prompt | TEXT | NO | '' | yes |
| sort_order | INTEGER | NO | 0 | yes |
| created_at | TEXT | NO | — | yes |
| updated_at | TEXT | NO | — | yes |

### 17. assessment_option_templates

| Column | Type | Nullable | Default | Used in model `toMap()` |
|--------|------|----------|---------|------------------------|
| id | TEXT | NO | — | yes |
| center_id | TEXT | NO | '' | yes |
| item_id | TEXT | NO | — (FK→assessment_item_templates) | yes |
| label | TEXT | NO | — | yes |
| generates_therapy | INTEGER | NO | 0 | yes (bool→0/1) |
| weakness_template | TEXT | NO | '' | yes |
| goal_template | TEXT | NO | '' | yes |
| therapy_template | TEXT | NO | '' | yes |
| sort_order | INTEGER | NO | 0 | yes |
| created_at | TEXT | NO | — | yes |
| updated_at | TEXT | NO | — | yes |

### 18. skill_step_templates

| Column | Type | Nullable | Default | Used in model `toMap()` |
|--------|------|----------|---------|------------------------|
| id | TEXT | NO | — | yes |
| center_id | TEXT | NO | '' | yes |
| owner_type | TEXT | NO | — | yes |
| owner_id | TEXT | NO | — | yes |
| title | TEXT | NO | — | yes |
| sort_order | INTEGER | NO | 0 | yes |
| created_at | TEXT | NO | — | yes |
| updated_at | TEXT | NO | — | yes |

### 19. speech_sound_trigger_templates

| Column | Type | Nullable | Default | Used in model `toMap()` |
|--------|------|----------|---------|------------------------|
| id | TEXT | NO | — | yes |
| center_id | TEXT | NO | '' | yes |
| program_id | TEXT | NO | '' | yes |
| letter | TEXT | NO | — | yes |
| error_type | TEXT | NO | — | yes |
| position | TEXT | NO | — | yes |
| generates_therapy | INTEGER | NO | 1 | yes (bool→0/1) |
| weakness_template | TEXT | NO | '' | yes |
| goal_template | TEXT | NO | '' | yes |
| therapy_template | TEXT | NO | '' | yes |
| skill_steps_json | TEXT | NO | '[]' | yes |
| sort_order | INTEGER | NO | 0 | yes |
| created_at | TEXT | NO | — | yes |
| updated_at | TEXT | NO | — | yes |

### 20. sign_resources

| Column | Type | Nullable | Default | Used in model `toMap()` |
|--------|------|----------|---------|------------------------|
| id | TEXT | NO | — | yes |
| center_id | TEXT | NO | '' (FK→centers) | yes |
| title | TEXT | NO | — | yes |
| category | TEXT | NO | — | yes |
| media_type | TEXT | NO | — | yes |
| media_path | TEXT | NO | — | yes |
| notes | TEXT | NO | — | yes |
| level | TEXT | NO | 'مبتدئ' | yes |
| is_favorite | INTEGER | NO | 0 | yes (bool→0/1) |
| created_at | TEXT | NO | '' | **NO** — model omits |
| updated_at | TEXT | NO | '' | **NO** — model omits |

### 21. audit_logs

| Column | Type | Nullable | Default | Used in model `toMap()` |
|--------|------|----------|---------|------------------------|
| id | TEXT | NO | — | yes |
| center_id | TEXT | NO | '' | yes |
| user_id | TEXT | NO | — | yes |
| user_name | TEXT | NO | — | yes |
| action | TEXT | NO | — | yes |
| entity_type | TEXT | NO | — | yes |
| entity_id | TEXT | NO | — | yes |
| details | TEXT | NO | '' | yes |
| created_at | TEXT | NO | — | yes |
| updated_at | TEXT | NO | '' | yes |

### 22. student_therapy_programs

| Column | Type | Nullable | Default | Used in model `toMap()` |
|--------|------|----------|---------|------------------------|
| id | TEXT | NO | — | yes |
| student_id | TEXT | NO | — | yes |
| program_id | TEXT | NO | — | yes |
| assigned_at | TEXT | NO | — | yes |
| assigned_by_user_id | TEXT | NO | '' | yes |
| is_active | INTEGER | NO | 1 | yes (bool→0/1) |
| sort_order | INTEGER | NO | 0 | yes |
| created_at | TEXT | NO | '' | **NO** — model omits |
| updated_at | TEXT | NO | '' | **NO** — model omits |

### 23. assessment_drafts

| Column | Type | Nullable | Default | Used in model `toMap()` |
|--------|------|----------|---------|------------------------|
| student_id | TEXT | NO | — (PK) | yes |
| program_id | TEXT | NO | — (PK) | yes |
| phase | TEXT | NO | 'sections' | yes |
| step_index | INTEGER | NO | 0 | yes |
| current_letter | TEXT | NO | '' | yes |
| selections_json | TEXT | NO | '{}' | yes |
| multi_selections_json | TEXT | NO | '{}' | yes |
| matrix_selections_json | TEXT | NO | '[]' | yes |
| letter_results_json | TEXT | NO | '{}' | yes |
| created_at | TEXT | NO | '' | **NO** — model omits |
| updated_at | TEXT | NO | — | yes |

### 24. student_specialists

| Column | Type | Nullable | Default | Used in model `toMap()` |
|--------|------|----------|---------|------------------------|
| id | TEXT | NO | — | yes |
| student_id | TEXT | NO | — | yes |
| specialist_id | TEXT | NO | — | yes |
| assigned_by_user_id | TEXT | NO | '' | yes |
| assigned_at | TEXT | NO | '' | yes |
| is_active | INTEGER | NO | 1 | yes (bool→0/1) |
| created_at | TEXT | NO | '' | **NO** — model omits |
| updated_at | TEXT | NO | '' | **NO** — model omits |

### 25. student_followups

| Column | Type | Nullable | Default | Used in model `toMap()` |
|--------|------|----------|---------|------------------------|
| id | TEXT | NO | — | yes |
| student_id | TEXT | NO | — | yes |
| specialist_id | TEXT | NO | '' | yes |
| program_id | TEXT | NO | '' | yes |
| source_type | TEXT | NO | '' | yes |
| plan_id | TEXT | NO | '' | yes |
| goal_skill_step_id | TEXT | NO | '' | yes |
| reason | TEXT | NO | 'retry' | yes |
| status | TEXT | NO | 'pending' | yes |
| created_at | TEXT | NO | '' | yes |
| resolved_at | TEXT | NO | '' | yes |
| last_opened_at | TEXT | NO | '' | yes |
| updated_at | TEXT | NO | '' | yes |

---

## Column Summary

All columns NOT NULL by convention. No nullable columns except `users.student_id`.

---

## Schema Mismatches Found (onUpgrade vs _createSchema)

### Critical — Migration `_ensureTable` CREATE TABLE statements that are OUTDATED:

1. **`exercises` in `_ensureMigrationTables` (v3)** — Missing 9 columns:
   `program_id`, `plan_id`, `goal_skill_step_id`, `source_type`, `session_date`,
   `note_for_parent`, `parent_completed_at`, `specialist_reviewed_at`, `created_from_session_result`
   *(Added later in v19, v22 — but if v19 and v22 migrations already ran, these columns were added via `_addColumns`)*

2. **`sign_resources` in v2 migration** — Missing 5 columns:
   `center_id`, `level`, `is_favorite`, `created_at`, `updated_at`
   *(Added later in v3 and v6 `_addColumns` — same caveat)*

### Schema differences between `_createSchema` and migration `_ensureTable`:

| Table | `_createSchema` has FK? | Migration `_ensureTable` has FK? | Impact |
|-------|------------------------|----------------------------------|--------|
| clinical_assessments | Yes (center_id, student_id) | **No** | Minor — no referential integrity |
| clinical_findings | Yes (assessment_id, center_id, student_id) | **No** | Minor — no referential integrity |
| assessment_item_templates | Yes (section_id) | No | Minor |
| assessment_option_templates | Yes (item_id) | No | Minor |

---

## How Schema Divergence Happens on Device

1. **Fresh install at current version**: `_createSchema` runs — all columns present. ✓
2. **Upgrade from old version**: Each migration block `if (oldVersion < X)` runs — columns added cumulatively. ✓
3. **Fresh install at OLD version** (e.g., version 19 was latest when user first installed):
   - `onCreate` runs `_createSchema` as it existed at that version (without later columns)
   - When upgrading to version 29, only blocks `if (oldVersion < X)` where `X > 19` run
   - **Columns added in v19 block DO NOT re-run** because `oldVersion=19` is NOT `< 19`
   - If later `_addColumns` in v20-v28 missed some columns, they stay missing forever!

This is **the root cause** of the schema divergence between Windows and Android.

---

## Migration History by Version

| Version | Changes |
|---------|---------|
| 1 | Initial schema |
| 2 | Add `sign_resources` table |
| 3 | Multi-center support: add FK columns, hash passwords, add tables via `_ensureMigrationTables` |
| 4 | Remove demo data |
| 5 | Add `audit_logs` table |
| 6 | Add `sign_resources.level`, `sign_resources.is_favorite` |
| 7 | Add `sessions.program_id`, `sessions.skill_id`, `sessions.activity_results` |
| 8 | Add `clinical_assessments`, `clinical_findings` tables |
| 9 | Add `goal_skill_steps` table |
| 10 | Drop legacy program tables |
| 11 | Repair Arabic text mojibake |
| 12 | Add therapy structure tables (`_ensureTherapyStructureTables`) |
| 13 | Reset accounts for role rebuild |
| 14 | Ensure therapy program tables (same as v12) |
| 15 | Add `assessment_item_templates.response_mode` |
| 16 | Add `assessment_drafts` table |
| 17 | Add `speech_sound_trigger_templates.skill_steps_json` |
| 18 | Add `assessment_drafts.letter_results_json` |
| 19 | Add `student_therapy_programs` table; add `program_id`, `source_type` to `training_plans`, `goal_skill_steps`, `clinical_findings`; add program fields to `exercises` |
| 20 | Add `student_therapy_programs.created_at`, `student_therapy_programs.updated_at` |
| 21 | Add `training_plans.treatment` |
| 22 | Add `exercises.note_for_parent`, `exercises.parent_completed_at`, `exercises.specialist_reviewed_at`, `exercises.created_from_session_result` |
| 23 | Add `student_specialists` table |
| 24 | Add `student_specialists.created_at`, `student_specialists.updated_at` |
| 25 | Add `sessions.specialist_id` |
| 26 | Add `student_followups` table |
| 27 | Add `student_followups.updated_at` |
| 28 | Add `assessment_drafts.created_at` |
| 29 | **Schema unification migration**: brute-force ADD COLUMN for all known missing columns across all critical tables |

---

## ensureLatestSchema() — Safety Net

Runs at every app startup (onOpen). For every table that should exist, ensures:
- `CREATE TABLE IF NOT EXISTS` with complete schema
- `ALTER TABLE ADD COLUMN IF NOT EXISTS` for every known column

See `DatabaseService._ensureLatestSchema()` in `database_service.dart`.
