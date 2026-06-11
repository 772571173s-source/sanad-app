import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Creates the full schema identical to DatabaseService._createSchema()
Future<void> createSchema(Database db) async {
  await db.execute('''
    CREATE TABLE centers (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      logo_path TEXT NOT NULL DEFAULT '',
      address TEXT NOT NULL DEFAULT '',
      phone TEXT NOT NULL DEFAULT '',
      manager_name TEXT NOT NULL DEFAULT '',
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE users (
      id TEXT PRIMARY KEY,
      center_id TEXT NOT NULL DEFAULT '',
      email TEXT NOT NULL UNIQUE,
      password_hash TEXT NOT NULL,
      name TEXT NOT NULL,
      role TEXT NOT NULL,
      student_id TEXT,
      force_password_change INTEGER NOT NULL DEFAULT 0,
      is_demo INTEGER NOT NULL DEFAULT 0,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE students (
      id TEXT PRIMARY KEY,
      center_id TEXT NOT NULL,
      name TEXT NOT NULL,
      age INTEGER NOT NULL,
      status TEXT NOT NULL,
      diagnosis TEXT NOT NULL,
      program_type TEXT NOT NULL DEFAULT 'نطق وتخاطب',
      parent_name TEXT NOT NULL,
      parent_phone TEXT NOT NULL,
      portal_email TEXT NOT NULL,
      portal_password TEXT NOT NULL,
      photo_path TEXT NOT NULL,
      notes TEXT NOT NULL,
      deleted_at TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY(center_id) REFERENCES centers(id)
    )
  ''');
  await db.execute('''
    CREATE TABLE parents (
      id TEXT PRIMARY KEY,
      center_id TEXT NOT NULL,
      student_id TEXT NOT NULL,
      name TEXT NOT NULL,
      phone TEXT NOT NULL,
      email TEXT NOT NULL,
      created_at TEXT NOT NULL DEFAULT '',
      updated_at TEXT NOT NULL DEFAULT '',
      FOREIGN KEY(center_id) REFERENCES centers(id),
      FOREIGN KEY(student_id) REFERENCES students(id)
    )
  ''');
  await db.execute('''
    CREATE TABLE sessions (
      id TEXT PRIMARY KEY,
      center_id TEXT NOT NULL,
      student_id TEXT NOT NULL,
      specialist_id TEXT NOT NULL DEFAULT '',
      plan_id TEXT NOT NULL DEFAULT '',
      program_id TEXT NOT NULL DEFAULT '',
      skill_id TEXT NOT NULL DEFAULT '',
      activity_results TEXT NOT NULL DEFAULT '',
      session_type TEXT NOT NULL DEFAULT 'نطق وتخاطب',
      target_letter TEXT NOT NULL DEFAULT '',
      letter_position TEXT NOT NULL DEFAULT '',
      error_type TEXT NOT NULL DEFAULT '',
      practice_items TEXT NOT NULL DEFAULT '',
      attempts INTEGER NOT NULL DEFAULT 0,
      success_rate INTEGER NOT NULL DEFAULT 0,
      started_at TEXT NOT NULL,
      duration_seconds INTEGER NOT NULL,
      card_title TEXT NOT NULL,
      quick_result TEXT NOT NULL,
      notes TEXT NOT NULL,
      summary TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY(center_id) REFERENCES centers(id),
      FOREIGN KEY(student_id) REFERENCES students(id)
    )
  ''');
  await db.execute('''
    CREATE TABLE evaluations (
      id TEXT PRIMARY KEY,
      center_id TEXT NOT NULL,
      student_id TEXT NOT NULL,
      letter TEXT NOT NULL,
      position TEXT NOT NULL,
      error_type TEXT NOT NULL,
      score TEXT NOT NULL,
      severity INTEGER NOT NULL DEFAULT 1,
      recommendation TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      notes TEXT NOT NULL,
      FOREIGN KEY(center_id) REFERENCES centers(id),
      FOREIGN KEY(student_id) REFERENCES students(id)
    )
  ''');
  await db.execute('''
    CREATE TABLE training_plans (
      id TEXT PRIMARY KEY,
      center_id TEXT NOT NULL,
      student_id TEXT NOT NULL,
      goal TEXT NOT NULL,
      treatment TEXT NOT NULL DEFAULT '',
      target_date TEXT NOT NULL,
      progress INTEGER NOT NULL,
      program_id TEXT NOT NULL DEFAULT '',
      source_type TEXT NOT NULL DEFAULT 'standard',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY(center_id) REFERENCES centers(id),
      FOREIGN KEY(student_id) REFERENCES students(id)
    )
  ''');
  await db.execute('''
    CREATE TABLE goal_skill_steps (
      id TEXT PRIMARY KEY,
      center_id TEXT NOT NULL,
      student_id TEXT NOT NULL,
      goal_id TEXT NOT NULL,
      title TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'لم يبدأ',
      sort_order INTEGER NOT NULL DEFAULT 0,
      notes TEXT NOT NULL DEFAULT '',
      last_session_id TEXT NOT NULL DEFAULT '',
      program_id TEXT NOT NULL DEFAULT '',
      source_type TEXT NOT NULL DEFAULT 'standard',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY(center_id) REFERENCES centers(id),
      FOREIGN KEY(student_id) REFERENCES students(id),
      FOREIGN KEY(goal_id) REFERENCES training_plans(id)
    )
  ''');
  await db.execute('''
    CREATE TABLE exercises (
      id TEXT PRIMARY KEY,
      center_id TEXT NOT NULL,
      student_id TEXT NOT NULL,
      title TEXT NOT NULL,
      instructions TEXT NOT NULL,
      due_date TEXT NOT NULL,
      status TEXT NOT NULL,
      audio_path TEXT NOT NULL,
      program_id TEXT NOT NULL DEFAULT '',
      plan_id TEXT NOT NULL DEFAULT '',
      goal_skill_step_id TEXT NOT NULL DEFAULT '',
      source_type TEXT NOT NULL DEFAULT 'standard',
      session_date TEXT NOT NULL DEFAULT '',
      parent_note TEXT NOT NULL DEFAULT '',
      note_for_parent TEXT NOT NULL DEFAULT '',
      parent_completed_at TEXT NOT NULL DEFAULT '',
      specialist_reviewed_at TEXT NOT NULL DEFAULT '',
      created_from_session_result TEXT NOT NULL DEFAULT '',
      stars INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY(center_id) REFERENCES centers(id),
      FOREIGN KEY(student_id) REFERENCES students(id)
    )
  ''');
  await db.execute('''
    CREATE TABLE rewards (
      id TEXT PRIMARY KEY,
      center_id TEXT NOT NULL,
      student_id TEXT NOT NULL,
      xp INTEGER NOT NULL,
      level INTEGER NOT NULL,
      badges TEXT NOT NULL,
      daily_streak INTEGER NOT NULL,
      created_at TEXT NOT NULL DEFAULT '',
      updated_at TEXT NOT NULL DEFAULT '',
      FOREIGN KEY(center_id) REFERENCES centers(id),
      FOREIGN KEY(student_id) REFERENCES students(id)
    )
  ''');
  await db.execute('''
    CREATE TABLE reports (
      id TEXT PRIMARY KEY,
      center_id TEXT NOT NULL,
      student_id TEXT NOT NULL,
      type TEXT NOT NULL,
      created_at TEXT NOT NULL,
      improvement_rate INTEGER NOT NULL,
      specialist_signature TEXT NOT NULL,
      manager_signature TEXT NOT NULL DEFAULT '',
      file_path TEXT NOT NULL DEFAULT '',
      updated_at TEXT NOT NULL DEFAULT '',
      FOREIGN KEY(center_id) REFERENCES centers(id),
      FOREIGN KEY(student_id) REFERENCES students(id)
    )
  ''');
  await db.execute('''
    CREATE TABLE clinical_assessments (
      id TEXT PRIMARY KEY,
      center_id TEXT NOT NULL,
      student_id TEXT NOT NULL,
      specialist_id TEXT NOT NULL DEFAULT '',
      specialist_name TEXT NOT NULL DEFAULT '',
      type TEXT NOT NULL DEFAULT 'speech',
      strengths_summary TEXT NOT NULL DEFAULT '',
      weaknesses_summary TEXT NOT NULL DEFAULT '',
      goals_summary TEXT NOT NULL DEFAULT '',
      training_summary TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY(center_id) REFERENCES centers(id),
      FOREIGN KEY(student_id) REFERENCES students(id)
    )
  ''');
  await db.execute('''
    CREATE TABLE clinical_findings (
      id TEXT PRIMARY KEY,
      assessment_id TEXT NOT NULL,
      center_id TEXT NOT NULL,
      student_id TEXT NOT NULL,
      domain TEXT NOT NULL,
      item_title TEXT NOT NULL,
      result TEXT NOT NULL,
      is_normal INTEGER NOT NULL DEFAULT 0,
      weakness TEXT NOT NULL DEFAULT '',
      goal TEXT NOT NULL DEFAULT '',
      training TEXT NOT NULL DEFAULT '',
      program_id TEXT NOT NULL DEFAULT '',
      source_type TEXT NOT NULL DEFAULT 'standard',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY(assessment_id) REFERENCES clinical_assessments(id),
      FOREIGN KEY(center_id) REFERENCES centers(id),
      FOREIGN KEY(student_id) REFERENCES students(id)
    )
  ''');
  await db.execute('''
    CREATE TABLE therapy_program_templates (
      id TEXT PRIMARY KEY,
      center_id TEXT NOT NULL DEFAULT '',
      name TEXT NOT NULL,
      description TEXT NOT NULL DEFAULT '',
      uses_speech_sounds INTEGER NOT NULL DEFAULT 0,
      sort_order INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE assessment_section_templates (
      id TEXT PRIMARY KEY,
      center_id TEXT NOT NULL DEFAULT '',
      program_id TEXT NOT NULL DEFAULT '',
      title TEXT NOT NULL,
      description TEXT NOT NULL DEFAULT '',
      sort_order INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE assessment_item_templates (
      id TEXT PRIMARY KEY,
      center_id TEXT NOT NULL DEFAULT '',
      section_id TEXT NOT NULL,
      title TEXT NOT NULL,
      response_type TEXT NOT NULL DEFAULT 'custom',
      response_mode TEXT NOT NULL DEFAULT 'singleChoice',
      prompt TEXT NOT NULL DEFAULT '',
      sort_order INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY(section_id) REFERENCES assessment_section_templates(id)
    )
  ''');
  await db.execute('''
    CREATE TABLE assessment_option_templates (
      id TEXT PRIMARY KEY,
      center_id TEXT NOT NULL DEFAULT '',
      item_id TEXT NOT NULL,
      label TEXT NOT NULL,
      generates_therapy INTEGER NOT NULL DEFAULT 0,
      weakness_template TEXT NOT NULL DEFAULT '',
      goal_template TEXT NOT NULL DEFAULT '',
      therapy_template TEXT NOT NULL DEFAULT '',
      sort_order INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY(item_id) REFERENCES assessment_item_templates(id)
    )
  ''');
  await db.execute('''
    CREATE TABLE skill_step_templates (
      id TEXT PRIMARY KEY,
      center_id TEXT NOT NULL DEFAULT '',
      owner_type TEXT NOT NULL,
      owner_id TEXT NOT NULL,
      title TEXT NOT NULL,
      sort_order INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE speech_sound_trigger_templates (
      id TEXT PRIMARY KEY,
      center_id TEXT NOT NULL DEFAULT '',
      program_id TEXT NOT NULL DEFAULT '',
      letter TEXT NOT NULL,
      error_type TEXT NOT NULL,
      position TEXT NOT NULL,
      generates_therapy INTEGER NOT NULL DEFAULT 1,
      weakness_template TEXT NOT NULL DEFAULT '',
      goal_template TEXT NOT NULL DEFAULT '',
      therapy_template TEXT NOT NULL DEFAULT '',
      skill_steps_json TEXT NOT NULL DEFAULT '[]',
      sort_order INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE sign_resources (
      id TEXT PRIMARY KEY,
      center_id TEXT NOT NULL DEFAULT '',
      title TEXT NOT NULL,
      category TEXT NOT NULL,
      media_type TEXT NOT NULL,
      media_path TEXT NOT NULL,
      notes TEXT NOT NULL,
      level TEXT NOT NULL DEFAULT 'مبتدئ',
      is_favorite INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT '',
      updated_at TEXT NOT NULL DEFAULT '',
      FOREIGN KEY(center_id) REFERENCES centers(id)
    )
  ''');
  await db.execute('''
    CREATE TABLE audit_logs (
      id TEXT PRIMARY KEY,
      center_id TEXT NOT NULL DEFAULT '',
      user_id TEXT NOT NULL,
      user_name TEXT NOT NULL,
      action TEXT NOT NULL,
      entity_type TEXT NOT NULL,
      entity_id TEXT NOT NULL,
      details TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL DEFAULT ''
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS student_therapy_programs (
      id TEXT PRIMARY KEY,
      student_id TEXT NOT NULL,
      program_id TEXT NOT NULL,
      assigned_at TEXT NOT NULL,
      assigned_by_user_id TEXT NOT NULL DEFAULT '',
      is_active INTEGER NOT NULL DEFAULT 1,
      sort_order INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT '',
      updated_at TEXT NOT NULL DEFAULT ''
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS assessment_drafts (
      student_id TEXT NOT NULL,
      program_id TEXT NOT NULL,
      phase TEXT NOT NULL DEFAULT 'sections',
      step_index INTEGER NOT NULL DEFAULT 0,
      current_letter TEXT NOT NULL DEFAULT '',
      selections_json TEXT NOT NULL DEFAULT '{}',
      multi_selections_json TEXT NOT NULL DEFAULT '{}',
      matrix_selections_json TEXT NOT NULL DEFAULT '[]',
      letter_results_json TEXT NOT NULL DEFAULT '{}',
      created_at TEXT NOT NULL DEFAULT '',
      updated_at TEXT NOT NULL,
      PRIMARY KEY (student_id, program_id)
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS student_specialists (
      id TEXT PRIMARY KEY,
      student_id TEXT NOT NULL,
      specialist_id TEXT NOT NULL,
      assigned_by_user_id TEXT NOT NULL DEFAULT '',
      assigned_at TEXT NOT NULL DEFAULT '',
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL DEFAULT '',
      updated_at TEXT NOT NULL DEFAULT ''
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS student_followups (
      id TEXT PRIMARY KEY,
      student_id TEXT NOT NULL,
      specialist_id TEXT NOT NULL DEFAULT '',
      program_id TEXT NOT NULL DEFAULT '',
      source_type TEXT NOT NULL DEFAULT '',
      plan_id TEXT NOT NULL DEFAULT '',
      goal_skill_step_id TEXT NOT NULL DEFAULT '',
      reason TEXT NOT NULL DEFAULT 'retry',
      status TEXT NOT NULL DEFAULT 'pending',
      created_at TEXT NOT NULL DEFAULT '',
      resolved_at TEXT NOT NULL DEFAULT '',
      last_opened_at TEXT NOT NULL DEFAULT '',
      updated_at TEXT NOT NULL DEFAULT ''
    )
  ''');
  await db.execute('''
    CREATE TABLE session_skill_results (
      id TEXT PRIMARY KEY,
      session_id TEXT NOT NULL,
      goal_skill_step_id TEXT NOT NULL DEFAULT '',
      goal_id TEXT NOT NULL DEFAULT '',
      step_title TEXT NOT NULL DEFAULT '',
      result TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');
}

/// Replicates DatabaseService._ensureLatestSchema() logic:
/// PRAGMA table_info; if table missing → CREATE TABLE; if column missing → ALTER TABLE ADD COLUMN
Future<void> ensureLatestSchema(Database db) async {
  const tables = <String, Map<String, String>>{
    'centers': {
      'id': 'TEXT PRIMARY KEY',
      'name': 'TEXT NOT NULL',
      'logo_path': "TEXT NOT NULL DEFAULT ''",
      'address': "TEXT NOT NULL DEFAULT ''",
      'phone': "TEXT NOT NULL DEFAULT ''",
      'manager_name': "TEXT NOT NULL DEFAULT ''",
      'is_active': 'INTEGER NOT NULL DEFAULT 1',
      'created_at': 'TEXT NOT NULL',
      'updated_at': 'TEXT NOT NULL',
    },
    'users': {
      'id': 'TEXT PRIMARY KEY',
      'center_id': "TEXT NOT NULL DEFAULT ''",
      'email': 'TEXT NOT NULL UNIQUE',
      'password_hash': 'TEXT NOT NULL',
      'name': 'TEXT NOT NULL',
      'role': 'TEXT NOT NULL',
      'student_id': 'TEXT',
      'force_password_change': 'INTEGER NOT NULL DEFAULT 0',
      'is_demo': 'INTEGER NOT NULL DEFAULT 0',
      'is_active': 'INTEGER NOT NULL DEFAULT 1',
      'created_at': 'TEXT NOT NULL',
      'updated_at': 'TEXT NOT NULL',
    },
    'students': {
      'id': 'TEXT PRIMARY KEY',
      'center_id': 'TEXT NOT NULL',
      'name': 'TEXT NOT NULL',
      'age': 'INTEGER NOT NULL',
      'status': 'TEXT NOT NULL',
      'diagnosis': 'TEXT NOT NULL',
      'program_type': "TEXT NOT NULL DEFAULT 'نطق وتخاطب'",
      'parent_name': 'TEXT NOT NULL',
      'parent_phone': 'TEXT NOT NULL',
      'portal_email': 'TEXT NOT NULL',
      'portal_password': 'TEXT NOT NULL',
      'photo_path': 'TEXT NOT NULL',
      'notes': 'TEXT NOT NULL',
      'deleted_at': "TEXT NOT NULL DEFAULT ''",
      'created_at': 'TEXT NOT NULL',
      'updated_at': 'TEXT NOT NULL',
    },
    'parents': {
      'id': 'TEXT PRIMARY KEY',
      'center_id': "TEXT NOT NULL DEFAULT ''",
      'student_id': 'TEXT NOT NULL',
      'name': 'TEXT NOT NULL',
      'phone': 'TEXT NOT NULL',
      'email': 'TEXT NOT NULL',
      'created_at': "TEXT NOT NULL DEFAULT ''",
      'updated_at': "TEXT NOT NULL DEFAULT ''",
    },
    'sessions': {
      'id': 'TEXT PRIMARY KEY',
      'center_id': "TEXT NOT NULL DEFAULT ''",
      'student_id': 'TEXT NOT NULL',
      'specialist_id': "TEXT NOT NULL DEFAULT ''",
      'plan_id': "TEXT NOT NULL DEFAULT ''",
      'program_id': "TEXT NOT NULL DEFAULT ''",
      'skill_id': "TEXT NOT NULL DEFAULT ''",
      'activity_results': "TEXT NOT NULL DEFAULT ''",
      'session_type': "TEXT NOT NULL DEFAULT 'نطق وتخاطب'",
      'target_letter': "TEXT NOT NULL DEFAULT ''",
      'letter_position': "TEXT NOT NULL DEFAULT ''",
      'error_type': "TEXT NOT NULL DEFAULT ''",
      'practice_items': "TEXT NOT NULL DEFAULT ''",
      'attempts': 'INTEGER NOT NULL DEFAULT 0',
      'success_rate': 'INTEGER NOT NULL DEFAULT 0',
      'started_at': 'TEXT NOT NULL',
      'duration_seconds': 'INTEGER NOT NULL',
      'card_title': 'TEXT NOT NULL',
      'quick_result': 'TEXT NOT NULL',
      'notes': 'TEXT NOT NULL',
      'summary': "TEXT NOT NULL DEFAULT ''",
      'created_at': 'TEXT NOT NULL',
      'updated_at': 'TEXT NOT NULL',
    },
    'evaluations': {
      'id': 'TEXT PRIMARY KEY',
      'center_id': "TEXT NOT NULL DEFAULT ''",
      'student_id': 'TEXT NOT NULL',
      'letter': 'TEXT NOT NULL',
      'position': 'TEXT NOT NULL',
      'error_type': 'TEXT NOT NULL',
      'score': 'TEXT NOT NULL',
      'severity': 'INTEGER NOT NULL DEFAULT 1',
      'recommendation': "TEXT NOT NULL DEFAULT ''",
      'created_at': 'TEXT NOT NULL',
      'updated_at': "TEXT NOT NULL DEFAULT ''",
      'notes': 'TEXT NOT NULL',
    },
    'training_plans': {
      'id': 'TEXT PRIMARY KEY',
      'center_id': "TEXT NOT NULL DEFAULT ''",
      'student_id': 'TEXT NOT NULL',
      'goal': 'TEXT NOT NULL',
      'treatment': "TEXT NOT NULL DEFAULT ''",
      'target_date': 'TEXT NOT NULL',
      'progress': 'INTEGER NOT NULL',
      'program_id': "TEXT NOT NULL DEFAULT ''",
      'source_type': "TEXT NOT NULL DEFAULT 'standard'",
      'created_at': "TEXT NOT NULL DEFAULT ''",
      'updated_at': "TEXT NOT NULL DEFAULT ''",
    },
    'goal_skill_steps': {
      'id': 'TEXT PRIMARY KEY',
      'center_id': 'TEXT NOT NULL',
      'student_id': 'TEXT NOT NULL',
      'goal_id': 'TEXT NOT NULL',
      'title': 'TEXT NOT NULL',
      'status': "TEXT NOT NULL DEFAULT 'لم يبدأ'",
      'sort_order': 'INTEGER NOT NULL DEFAULT 0',
      'notes': "TEXT NOT NULL DEFAULT ''",
      'last_session_id': "TEXT NOT NULL DEFAULT ''",
      'program_id': "TEXT NOT NULL DEFAULT ''",
      'source_type': "TEXT NOT NULL DEFAULT 'standard'",
      'created_at': 'TEXT NOT NULL',
      'updated_at': 'TEXT NOT NULL',
    },
    'exercises': {
      'id': 'TEXT PRIMARY KEY',
      'center_id': "TEXT NOT NULL DEFAULT ''",
      'student_id': 'TEXT NOT NULL',
      'title': 'TEXT NOT NULL',
      'instructions': 'TEXT NOT NULL',
      'due_date': 'TEXT NOT NULL',
      'status': 'TEXT NOT NULL',
      'audio_path': 'TEXT NOT NULL',
      'program_id': "TEXT NOT NULL DEFAULT ''",
      'plan_id': "TEXT NOT NULL DEFAULT ''",
      'goal_skill_step_id': "TEXT NOT NULL DEFAULT ''",
      'source_type': "TEXT NOT NULL DEFAULT 'standard'",
      'session_date': "TEXT NOT NULL DEFAULT ''",
      'parent_note': "TEXT NOT NULL DEFAULT ''",
      'note_for_parent': "TEXT NOT NULL DEFAULT ''",
      'parent_completed_at': "TEXT NOT NULL DEFAULT ''",
      'specialist_reviewed_at': "TEXT NOT NULL DEFAULT ''",
      'created_from_session_result': "TEXT NOT NULL DEFAULT ''",
      'stars': 'INTEGER NOT NULL DEFAULT 0',
      'created_at': "TEXT NOT NULL DEFAULT ''",
      'updated_at': "TEXT NOT NULL DEFAULT ''",
    },
    'rewards': {
      'id': 'TEXT PRIMARY KEY',
      'center_id': "TEXT NOT NULL DEFAULT ''",
      'student_id': 'TEXT NOT NULL',
      'xp': 'INTEGER NOT NULL',
      'level': 'INTEGER NOT NULL',
      'badges': 'TEXT NOT NULL',
      'daily_streak': 'INTEGER NOT NULL',
      'created_at': "TEXT NOT NULL DEFAULT ''",
      'updated_at': "TEXT NOT NULL DEFAULT ''",
    },
    'reports': {
      'id': 'TEXT PRIMARY KEY',
      'center_id': "TEXT NOT NULL DEFAULT ''",
      'student_id': 'TEXT NOT NULL',
      'type': 'TEXT NOT NULL',
      'created_at': 'TEXT NOT NULL',
      'improvement_rate': 'INTEGER NOT NULL',
      'specialist_signature': 'TEXT NOT NULL',
      'manager_signature': "TEXT NOT NULL DEFAULT ''",
      'file_path': "TEXT NOT NULL DEFAULT ''",
      'updated_at': "TEXT NOT NULL DEFAULT ''",
    },
    'clinical_assessments': {
      'id': 'TEXT PRIMARY KEY',
      'center_id': 'TEXT NOT NULL',
      'student_id': 'TEXT NOT NULL',
      'specialist_id': "TEXT NOT NULL DEFAULT ''",
      'specialist_name': "TEXT NOT NULL DEFAULT ''",
      'type': "TEXT NOT NULL DEFAULT 'speech'",
      'strengths_summary': "TEXT NOT NULL DEFAULT ''",
      'weaknesses_summary': "TEXT NOT NULL DEFAULT ''",
      'goals_summary': "TEXT NOT NULL DEFAULT ''",
      'training_summary': "TEXT NOT NULL DEFAULT ''",
      'created_at': 'TEXT NOT NULL',
      'updated_at': 'TEXT NOT NULL',
    },
    'clinical_findings': {
      'id': 'TEXT PRIMARY KEY',
      'assessment_id': 'TEXT NOT NULL',
      'center_id': 'TEXT NOT NULL',
      'student_id': 'TEXT NOT NULL',
      'domain': 'TEXT NOT NULL',
      'item_title': 'TEXT NOT NULL',
      'result': 'TEXT NOT NULL',
      'is_normal': 'INTEGER NOT NULL DEFAULT 0',
      'weakness': "TEXT NOT NULL DEFAULT ''",
      'goal': "TEXT NOT NULL DEFAULT ''",
      'training': "TEXT NOT NULL DEFAULT ''",
      'program_id': "TEXT NOT NULL DEFAULT ''",
      'source_type': "TEXT NOT NULL DEFAULT 'standard'",
      'created_at': 'TEXT NOT NULL',
      'updated_at': 'TEXT NOT NULL',
    },
    'therapy_program_templates': {
      'id': 'TEXT PRIMARY KEY',
      'center_id': "TEXT NOT NULL DEFAULT ''",
      'name': 'TEXT NOT NULL',
      'description': "TEXT NOT NULL DEFAULT ''",
      'uses_speech_sounds': 'INTEGER NOT NULL DEFAULT 0',
      'sort_order': 'INTEGER NOT NULL DEFAULT 0',
      'created_at': 'TEXT NOT NULL',
      'updated_at': 'TEXT NOT NULL',
    },
    'assessment_section_templates': {
      'id': 'TEXT PRIMARY KEY',
      'center_id': "TEXT NOT NULL DEFAULT ''",
      'program_id': "TEXT NOT NULL DEFAULT ''",
      'title': 'TEXT NOT NULL',
      'description': "TEXT NOT NULL DEFAULT ''",
      'sort_order': 'INTEGER NOT NULL DEFAULT 0',
      'created_at': 'TEXT NOT NULL',
      'updated_at': 'TEXT NOT NULL',
    },
    'assessment_item_templates': {
      'id': 'TEXT PRIMARY KEY',
      'center_id': "TEXT NOT NULL DEFAULT ''",
      'section_id': 'TEXT NOT NULL',
      'title': 'TEXT NOT NULL',
      'response_type': "TEXT NOT NULL DEFAULT 'custom'",
      'response_mode': "TEXT NOT NULL DEFAULT 'singleChoice'",
      'prompt': "TEXT NOT NULL DEFAULT ''",
      'sort_order': 'INTEGER NOT NULL DEFAULT 0',
      'created_at': 'TEXT NOT NULL',
      'updated_at': 'TEXT NOT NULL',
    },
    'assessment_option_templates': {
      'id': 'TEXT PRIMARY KEY',
      'center_id': "TEXT NOT NULL DEFAULT ''",
      'item_id': 'TEXT NOT NULL',
      'label': 'TEXT NOT NULL',
      'generates_therapy': 'INTEGER NOT NULL DEFAULT 0',
      'weakness_template': "TEXT NOT NULL DEFAULT ''",
      'goal_template': "TEXT NOT NULL DEFAULT ''",
      'therapy_template': "TEXT NOT NULL DEFAULT ''",
      'sort_order': 'INTEGER NOT NULL DEFAULT 0',
      'created_at': 'TEXT NOT NULL',
      'updated_at': 'TEXT NOT NULL',
    },
    'skill_step_templates': {
      'id': 'TEXT PRIMARY KEY',
      'center_id': "TEXT NOT NULL DEFAULT ''",
      'owner_type': 'TEXT NOT NULL',
      'owner_id': 'TEXT NOT NULL',
      'title': 'TEXT NOT NULL',
      'sort_order': 'INTEGER NOT NULL DEFAULT 0',
      'created_at': 'TEXT NOT NULL',
      'updated_at': 'TEXT NOT NULL',
    },
    'speech_sound_trigger_templates': {
      'id': 'TEXT PRIMARY KEY',
      'center_id': "TEXT NOT NULL DEFAULT ''",
      'program_id': "TEXT NOT NULL DEFAULT ''",
      'letter': 'TEXT NOT NULL',
      'error_type': 'TEXT NOT NULL',
      'position': 'TEXT NOT NULL',
      'generates_therapy': 'INTEGER NOT NULL DEFAULT 1',
      'weakness_template': "TEXT NOT NULL DEFAULT ''",
      'goal_template': "TEXT NOT NULL DEFAULT ''",
      'therapy_template': "TEXT NOT NULL DEFAULT ''",
      'skill_steps_json': "TEXT NOT NULL DEFAULT '[]'",
      'sort_order': 'INTEGER NOT NULL DEFAULT 0',
      'created_at': 'TEXT NOT NULL',
      'updated_at': 'TEXT NOT NULL',
    },
    'sign_resources': {
      'id': 'TEXT PRIMARY KEY',
      'center_id': "TEXT NOT NULL DEFAULT ''",
      'title': 'TEXT NOT NULL',
      'category': 'TEXT NOT NULL',
      'media_type': 'TEXT NOT NULL',
      'media_path': 'TEXT NOT NULL',
      'notes': 'TEXT NOT NULL',
      'level': "TEXT NOT NULL DEFAULT 'مبتدئ'",
      'is_favorite': 'INTEGER NOT NULL DEFAULT 0',
      'created_at': "TEXT NOT NULL DEFAULT ''",
      'updated_at': "TEXT NOT NULL DEFAULT ''",
    },
    'audit_logs': {
      'id': 'TEXT PRIMARY KEY',
      'center_id': "TEXT NOT NULL DEFAULT ''",
      'user_id': 'TEXT NOT NULL',
      'user_name': 'TEXT NOT NULL',
      'action': 'TEXT NOT NULL',
      'entity_type': 'TEXT NOT NULL',
      'entity_id': 'TEXT NOT NULL',
      'details': "TEXT NOT NULL DEFAULT ''",
      'created_at': 'TEXT NOT NULL',
      'updated_at': "TEXT NOT NULL DEFAULT ''",
    },
    'student_therapy_programs': {
      'id': 'TEXT PRIMARY KEY',
      'student_id': 'TEXT NOT NULL',
      'program_id': 'TEXT NOT NULL',
      'assigned_at': 'TEXT NOT NULL',
      'assigned_by_user_id': "TEXT NOT NULL DEFAULT ''",
      'is_active': 'INTEGER NOT NULL DEFAULT 1',
      'sort_order': 'INTEGER NOT NULL DEFAULT 0',
      'created_at': "TEXT NOT NULL DEFAULT ''",
      'updated_at': "TEXT NOT NULL DEFAULT ''",
    },
    'assessment_drafts': {
      'student_id': 'TEXT NOT NULL',
      'program_id': 'TEXT NOT NULL',
      'phase': "TEXT NOT NULL DEFAULT 'sections'",
      'step_index': 'INTEGER NOT NULL DEFAULT 0',
      'current_letter': "TEXT NOT NULL DEFAULT ''",
      'selections_json': "TEXT NOT NULL DEFAULT '{}'",
      'multi_selections_json': "TEXT NOT NULL DEFAULT '{}'",
      'matrix_selections_json': "TEXT NOT NULL DEFAULT '[]'",
      'letter_results_json': "TEXT NOT NULL DEFAULT '{}'",
      'created_at': "TEXT NOT NULL DEFAULT ''",
      'updated_at': 'TEXT NOT NULL',
    },
    'student_specialists': {
      'id': 'TEXT PRIMARY KEY',
      'student_id': 'TEXT NOT NULL',
      'specialist_id': 'TEXT NOT NULL',
      'assigned_by_user_id': "TEXT NOT NULL DEFAULT ''",
      'assigned_at': "TEXT NOT NULL DEFAULT ''",
      'is_active': 'INTEGER NOT NULL DEFAULT 1',
      'created_at': "TEXT NOT NULL DEFAULT ''",
      'updated_at': "TEXT NOT NULL DEFAULT ''",
    },
    'student_followups': {
      'id': 'TEXT PRIMARY KEY',
      'student_id': 'TEXT NOT NULL',
      'specialist_id': "TEXT NOT NULL DEFAULT ''",
      'program_id': "TEXT NOT NULL DEFAULT ''",
      'source_type': "TEXT NOT NULL DEFAULT ''",
      'plan_id': "TEXT NOT NULL DEFAULT ''",
      'goal_skill_step_id': "TEXT NOT NULL DEFAULT ''",
      'reason': "TEXT NOT NULL DEFAULT 'retry'",
      'status': "TEXT NOT NULL DEFAULT 'pending'",
      'created_at': "TEXT NOT NULL DEFAULT ''",
      'resolved_at': "TEXT NOT NULL DEFAULT ''",
      'last_opened_at': "TEXT NOT NULL DEFAULT ''",
      'updated_at': "TEXT NOT NULL DEFAULT ''",
    },
    'session_skill_results': {
      'id': 'TEXT PRIMARY KEY',
      'session_id': 'TEXT NOT NULL',
      'goal_skill_step_id': "TEXT NOT NULL DEFAULT ''",
      'goal_id': "TEXT NOT NULL DEFAULT ''",
      'step_title': "TEXT NOT NULL DEFAULT ''",
      'result': "TEXT NOT NULL DEFAULT ''",
      'created_at': 'TEXT NOT NULL',
      'updated_at': 'TEXT NOT NULL',
    },
  };

  for (final entry in tables.entries) {
    final table = entry.key;
    final columns = entry.value;
    final info = await db.rawQuery('PRAGMA table_info("$table")');
    final existing =
        info.map((r) => r['name'] as String?).whereType<String>().toSet();
    if (existing.isEmpty) {
      final colDefs = columns.entries
          .map((c) => '${c.key} ${c.value}')
          .join(',\n');
      await db.execute('CREATE TABLE IF NOT EXISTS "$table" ($colDefs)');
    } else {
      for (final col in columns.entries) {
        if (!existing.contains(col.key)) {
          await db.execute(
              'ALTER TABLE "$table" ADD COLUMN ${col.key} ${col.value}');
        }
      }
    }
  }
}

/// Verifies a table exists and has all expected columns via PRAGMA table_info.
Future<void> verifyTableSchema(
    Database db, String table, Map<String, String> expectedColumns) async {
  final info = await db.rawQuery('PRAGMA table_info("$table")');
  expect(info.isNotEmpty, isTrue, reason: 'Table $table should exist');
  final actualColumns = {
    for (final row in info) row['name'] as String: row['type'] as String,
  };
  for (final col in expectedColumns.entries) {
    expect(actualColumns.containsKey(col.key), isTrue,
        reason: 'Table $table should have column ${col.key}');
  }
  expect(actualColumns.length, expectedColumns.length,
      reason:
          'Table $table should have exactly ${expectedColumns.length} columns');
}

/// Returns expected column schema for a table (same as ensureLatestSchema).
Map<String, String> expectedColumns(String table) {
  const all = <String, Map<String, String>>{
    'centers': {
      'id': 'TEXT PRIMARY KEY',
      'name': 'TEXT NOT NULL',
      'logo_path': "TEXT NOT NULL DEFAULT ''",
      'address': "TEXT NOT NULL DEFAULT ''",
      'phone': "TEXT NOT NULL DEFAULT ''",
      'manager_name': "TEXT NOT NULL DEFAULT ''",
      'is_active': 'INTEGER NOT NULL DEFAULT 1',
      'created_at': 'TEXT NOT NULL',
      'updated_at': 'TEXT NOT NULL',
    },
    'users': {
      'id': 'TEXT PRIMARY KEY',
      'center_id': "TEXT NOT NULL DEFAULT ''",
      'email': 'TEXT NOT NULL UNIQUE',
      'password_hash': 'TEXT NOT NULL',
      'name': 'TEXT NOT NULL',
      'role': 'TEXT NOT NULL',
      'student_id': 'TEXT',
      'force_password_change': 'INTEGER NOT NULL DEFAULT 0',
      'is_demo': 'INTEGER NOT NULL DEFAULT 0',
      'is_active': 'INTEGER NOT NULL DEFAULT 1',
      'created_at': 'TEXT NOT NULL',
      'updated_at': 'TEXT NOT NULL',
    },
    'students': {
      'id': 'TEXT PRIMARY KEY',
      'center_id': 'TEXT NOT NULL',
      'name': 'TEXT NOT NULL',
      'age': 'INTEGER NOT NULL',
      'status': 'TEXT NOT NULL',
      'diagnosis': 'TEXT NOT NULL',
      'program_type': "TEXT NOT NULL DEFAULT 'نطق وتخاطب'",
      'parent_name': 'TEXT NOT NULL',
      'parent_phone': 'TEXT NOT NULL',
      'portal_email': 'TEXT NOT NULL',
      'portal_password': 'TEXT NOT NULL',
      'photo_path': 'TEXT NOT NULL',
      'notes': 'TEXT NOT NULL',
      'deleted_at': "TEXT NOT NULL DEFAULT ''",
      'created_at': 'TEXT NOT NULL',
      'updated_at': 'TEXT NOT NULL',
    },
    'parents': {
      'id': 'TEXT PRIMARY KEY',
      'center_id': "TEXT NOT NULL DEFAULT ''",
      'student_id': 'TEXT NOT NULL',
      'name': 'TEXT NOT NULL',
      'phone': 'TEXT NOT NULL',
      'email': 'TEXT NOT NULL',
      'created_at': "TEXT NOT NULL DEFAULT ''",
      'updated_at': "TEXT NOT NULL DEFAULT ''",
    },
    'sessions': {
      'id': 'TEXT PRIMARY KEY',
      'center_id': "TEXT NOT NULL DEFAULT ''",
      'student_id': 'TEXT NOT NULL',
      'specialist_id': "TEXT NOT NULL DEFAULT ''",
      'plan_id': "TEXT NOT NULL DEFAULT ''",
      'program_id': "TEXT NOT NULL DEFAULT ''",
      'skill_id': "TEXT NOT NULL DEFAULT ''",
      'activity_results': "TEXT NOT NULL DEFAULT ''",
      'session_type': "TEXT NOT NULL DEFAULT 'نطق وتخاطب'",
      'target_letter': "TEXT NOT NULL DEFAULT ''",
      'letter_position': "TEXT NOT NULL DEFAULT ''",
      'error_type': "TEXT NOT NULL DEFAULT ''",
      'practice_items': "TEXT NOT NULL DEFAULT ''",
      'attempts': 'INTEGER NOT NULL DEFAULT 0',
      'success_rate': 'INTEGER NOT NULL DEFAULT 0',
      'started_at': 'TEXT NOT NULL',
      'duration_seconds': 'INTEGER NOT NULL',
      'card_title': 'TEXT NOT NULL',
      'quick_result': 'TEXT NOT NULL',
      'notes': 'TEXT NOT NULL',
      'summary': "TEXT NOT NULL DEFAULT ''",
      'created_at': 'TEXT NOT NULL',
      'updated_at': 'TEXT NOT NULL',
    },
    'evaluations': {
      'id': 'TEXT PRIMARY KEY',
      'center_id': "TEXT NOT NULL DEFAULT ''",
      'student_id': 'TEXT NOT NULL',
      'letter': 'TEXT NOT NULL',
      'position': 'TEXT NOT NULL',
      'error_type': 'TEXT NOT NULL',
      'score': 'TEXT NOT NULL',
      'severity': 'INTEGER NOT NULL DEFAULT 1',
      'recommendation': "TEXT NOT NULL DEFAULT ''",
      'created_at': 'TEXT NOT NULL',
      'updated_at': "TEXT NOT NULL DEFAULT ''",
      'notes': 'TEXT NOT NULL',
    },
    'training_plans': {
      'id': 'TEXT PRIMARY KEY',
      'center_id': "TEXT NOT NULL DEFAULT ''",
      'student_id': 'TEXT NOT NULL',
      'goal': 'TEXT NOT NULL',
      'treatment': "TEXT NOT NULL DEFAULT ''",
      'target_date': 'TEXT NOT NULL',
      'progress': 'INTEGER NOT NULL',
      'program_id': "TEXT NOT NULL DEFAULT ''",
      'source_type': "TEXT NOT NULL DEFAULT 'standard'",
      'created_at': "TEXT NOT NULL DEFAULT ''",
      'updated_at': "TEXT NOT NULL DEFAULT ''",
    },
    'goal_skill_steps': {
      'id': 'TEXT PRIMARY KEY',
      'center_id': 'TEXT NOT NULL',
      'student_id': 'TEXT NOT NULL',
      'goal_id': 'TEXT NOT NULL',
      'title': 'TEXT NOT NULL',
      'status': "TEXT NOT NULL DEFAULT 'لم يبدأ'",
      'sort_order': 'INTEGER NOT NULL DEFAULT 0',
      'notes': "TEXT NOT NULL DEFAULT ''",
      'last_session_id': "TEXT NOT NULL DEFAULT ''",
      'program_id': "TEXT NOT NULL DEFAULT ''",
      'source_type': "TEXT NOT NULL DEFAULT 'standard'",
      'created_at': 'TEXT NOT NULL',
      'updated_at': 'TEXT NOT NULL',
    },
    'exercises': {
      'id': 'TEXT PRIMARY KEY',
      'center_id': "TEXT NOT NULL DEFAULT ''",
      'student_id': 'TEXT NOT NULL',
      'title': 'TEXT NOT NULL',
      'instructions': 'TEXT NOT NULL',
      'due_date': 'TEXT NOT NULL',
      'status': 'TEXT NOT NULL',
      'audio_path': 'TEXT NOT NULL',
      'program_id': "TEXT NOT NULL DEFAULT ''",
      'plan_id': "TEXT NOT NULL DEFAULT ''",
      'goal_skill_step_id': "TEXT NOT NULL DEFAULT ''",
      'source_type': "TEXT NOT NULL DEFAULT 'standard'",
      'session_date': "TEXT NOT NULL DEFAULT ''",
      'parent_note': "TEXT NOT NULL DEFAULT ''",
      'note_for_parent': "TEXT NOT NULL DEFAULT ''",
      'parent_completed_at': "TEXT NOT NULL DEFAULT ''",
      'specialist_reviewed_at': "TEXT NOT NULL DEFAULT ''",
      'created_from_session_result': "TEXT NOT NULL DEFAULT ''",
      'stars': 'INTEGER NOT NULL DEFAULT 0',
      'created_at': "TEXT NOT NULL DEFAULT ''",
      'updated_at': "TEXT NOT NULL DEFAULT ''",
    },
    'rewards': {
      'id': 'TEXT PRIMARY KEY',
      'center_id': "TEXT NOT NULL DEFAULT ''",
      'student_id': 'TEXT NOT NULL',
      'xp': 'INTEGER NOT NULL',
      'level': 'INTEGER NOT NULL',
      'badges': 'TEXT NOT NULL',
      'daily_streak': 'INTEGER NOT NULL',
      'created_at': "TEXT NOT NULL DEFAULT ''",
      'updated_at': "TEXT NOT NULL DEFAULT ''",
    },
    'reports': {
      'id': 'TEXT PRIMARY KEY',
      'center_id': "TEXT NOT NULL DEFAULT ''",
      'student_id': 'TEXT NOT NULL',
      'type': 'TEXT NOT NULL',
      'created_at': 'TEXT NOT NULL',
      'improvement_rate': 'INTEGER NOT NULL',
      'specialist_signature': 'TEXT NOT NULL',
      'manager_signature': "TEXT NOT NULL DEFAULT ''",
      'file_path': "TEXT NOT NULL DEFAULT ''",
      'updated_at': "TEXT NOT NULL DEFAULT ''",
    },
    'clinical_assessments': {
      'id': 'TEXT PRIMARY KEY',
      'center_id': 'TEXT NOT NULL',
      'student_id': 'TEXT NOT NULL',
      'specialist_id': "TEXT NOT NULL DEFAULT ''",
      'specialist_name': "TEXT NOT NULL DEFAULT ''",
      'type': "TEXT NOT NULL DEFAULT 'speech'",
      'strengths_summary': "TEXT NOT NULL DEFAULT ''",
      'weaknesses_summary': "TEXT NOT NULL DEFAULT ''",
      'goals_summary': "TEXT NOT NULL DEFAULT ''",
      'training_summary': "TEXT NOT NULL DEFAULT ''",
      'created_at': 'TEXT NOT NULL',
      'updated_at': 'TEXT NOT NULL',
    },
    'clinical_findings': {
      'id': 'TEXT PRIMARY KEY',
      'assessment_id': 'TEXT NOT NULL',
      'center_id': 'TEXT NOT NULL',
      'student_id': 'TEXT NOT NULL',
      'domain': 'TEXT NOT NULL',
      'item_title': 'TEXT NOT NULL',
      'result': 'TEXT NOT NULL',
      'is_normal': 'INTEGER NOT NULL DEFAULT 0',
      'weakness': "TEXT NOT NULL DEFAULT ''",
      'goal': "TEXT NOT NULL DEFAULT ''",
      'training': "TEXT NOT NULL DEFAULT ''",
      'program_id': "TEXT NOT NULL DEFAULT ''",
      'source_type': "TEXT NOT NULL DEFAULT 'standard'",
      'created_at': 'TEXT NOT NULL',
      'updated_at': 'TEXT NOT NULL',
    },
    'therapy_program_templates': {
      'id': 'TEXT PRIMARY KEY',
      'center_id': "TEXT NOT NULL DEFAULT ''",
      'name': 'TEXT NOT NULL',
      'description': "TEXT NOT NULL DEFAULT ''",
      'uses_speech_sounds': 'INTEGER NOT NULL DEFAULT 0',
      'sort_order': 'INTEGER NOT NULL DEFAULT 0',
      'created_at': 'TEXT NOT NULL',
      'updated_at': 'TEXT NOT NULL',
    },
    'assessment_section_templates': {
      'id': 'TEXT PRIMARY KEY',
      'center_id': "TEXT NOT NULL DEFAULT ''",
      'program_id': "TEXT NOT NULL DEFAULT ''",
      'title': 'TEXT NOT NULL',
      'description': "TEXT NOT NULL DEFAULT ''",
      'sort_order': 'INTEGER NOT NULL DEFAULT 0',
      'created_at': 'TEXT NOT NULL',
      'updated_at': 'TEXT NOT NULL',
    },
    'assessment_item_templates': {
      'id': 'TEXT PRIMARY KEY',
      'center_id': "TEXT NOT NULL DEFAULT ''",
      'section_id': 'TEXT NOT NULL',
      'title': 'TEXT NOT NULL',
      'response_type': "TEXT NOT NULL DEFAULT 'custom'",
      'response_mode': "TEXT NOT NULL DEFAULT 'singleChoice'",
      'prompt': "TEXT NOT NULL DEFAULT ''",
      'sort_order': 'INTEGER NOT NULL DEFAULT 0',
      'created_at': 'TEXT NOT NULL',
      'updated_at': 'TEXT NOT NULL',
    },
    'assessment_option_templates': {
      'id': 'TEXT PRIMARY KEY',
      'center_id': "TEXT NOT NULL DEFAULT ''",
      'item_id': 'TEXT NOT NULL',
      'label': 'TEXT NOT NULL',
      'generates_therapy': 'INTEGER NOT NULL DEFAULT 0',
      'weakness_template': "TEXT NOT NULL DEFAULT ''",
      'goal_template': "TEXT NOT NULL DEFAULT ''",
      'therapy_template': "TEXT NOT NULL DEFAULT ''",
      'sort_order': 'INTEGER NOT NULL DEFAULT 0',
      'created_at': 'TEXT NOT NULL',
      'updated_at': 'TEXT NOT NULL',
    },
    'skill_step_templates': {
      'id': 'TEXT PRIMARY KEY',
      'center_id': "TEXT NOT NULL DEFAULT ''",
      'owner_type': 'TEXT NOT NULL',
      'owner_id': 'TEXT NOT NULL',
      'title': 'TEXT NOT NULL',
      'sort_order': 'INTEGER NOT NULL DEFAULT 0',
      'created_at': 'TEXT NOT NULL',
      'updated_at': 'TEXT NOT NULL',
    },
    'speech_sound_trigger_templates': {
      'id': 'TEXT PRIMARY KEY',
      'center_id': "TEXT NOT NULL DEFAULT ''",
      'program_id': "TEXT NOT NULL DEFAULT ''",
      'letter': 'TEXT NOT NULL',
      'error_type': 'TEXT NOT NULL',
      'position': 'TEXT NOT NULL',
      'generates_therapy': 'INTEGER NOT NULL DEFAULT 1',
      'weakness_template': "TEXT NOT NULL DEFAULT ''",
      'goal_template': "TEXT NOT NULL DEFAULT ''",
      'therapy_template': "TEXT NOT NULL DEFAULT ''",
      'skill_steps_json': "TEXT NOT NULL DEFAULT '[]'",
      'sort_order': 'INTEGER NOT NULL DEFAULT 0',
      'created_at': 'TEXT NOT NULL',
      'updated_at': 'TEXT NOT NULL',
    },
    'sign_resources': {
      'id': 'TEXT PRIMARY KEY',
      'center_id': "TEXT NOT NULL DEFAULT ''",
      'title': 'TEXT NOT NULL',
      'category': 'TEXT NOT NULL',
      'media_type': 'TEXT NOT NULL',
      'media_path': 'TEXT NOT NULL',
      'notes': 'TEXT NOT NULL',
      'level': "TEXT NOT NULL DEFAULT 'مبتدئ'",
      'is_favorite': 'INTEGER NOT NULL DEFAULT 0',
      'created_at': "TEXT NOT NULL DEFAULT ''",
      'updated_at': "TEXT NOT NULL DEFAULT ''",
    },
    'audit_logs': {
      'id': 'TEXT PRIMARY KEY',
      'center_id': "TEXT NOT NULL DEFAULT ''",
      'user_id': 'TEXT NOT NULL',
      'user_name': 'TEXT NOT NULL',
      'action': 'TEXT NOT NULL',
      'entity_type': 'TEXT NOT NULL',
      'entity_id': 'TEXT NOT NULL',
      'details': "TEXT NOT NULL DEFAULT ''",
      'created_at': 'TEXT NOT NULL',
      'updated_at': "TEXT NOT NULL DEFAULT ''",
    },
    'student_therapy_programs': {
      'id': 'TEXT PRIMARY KEY',
      'student_id': 'TEXT NOT NULL',
      'program_id': 'TEXT NOT NULL',
      'assigned_at': 'TEXT NOT NULL',
      'assigned_by_user_id': "TEXT NOT NULL DEFAULT ''",
      'is_active': 'INTEGER NOT NULL DEFAULT 1',
      'sort_order': 'INTEGER NOT NULL DEFAULT 0',
      'created_at': "TEXT NOT NULL DEFAULT ''",
      'updated_at': "TEXT NOT NULL DEFAULT ''",
    },
    'assessment_drafts': {
      'student_id': 'TEXT NOT NULL',
      'program_id': 'TEXT NOT NULL',
      'phase': "TEXT NOT NULL DEFAULT 'sections'",
      'step_index': 'INTEGER NOT NULL DEFAULT 0',
      'current_letter': "TEXT NOT NULL DEFAULT ''",
      'selections_json': "TEXT NOT NULL DEFAULT '{}'",
      'multi_selections_json': "TEXT NOT NULL DEFAULT '{}'",
      'matrix_selections_json': "TEXT NOT NULL DEFAULT '[]'",
      'letter_results_json': "TEXT NOT NULL DEFAULT '{}'",
      'created_at': "TEXT NOT NULL DEFAULT ''",
      'updated_at': 'TEXT NOT NULL',
    },
    'student_specialists': {
      'id': 'TEXT PRIMARY KEY',
      'student_id': 'TEXT NOT NULL',
      'specialist_id': 'TEXT NOT NULL',
      'assigned_by_user_id': "TEXT NOT NULL DEFAULT ''",
      'assigned_at': "TEXT NOT NULL DEFAULT ''",
      'is_active': 'INTEGER NOT NULL DEFAULT 1',
      'created_at': "TEXT NOT NULL DEFAULT ''",
      'updated_at': "TEXT NOT NULL DEFAULT ''",
    },
    'student_followups': {
      'id': 'TEXT PRIMARY KEY',
      'student_id': 'TEXT NOT NULL',
      'specialist_id': "TEXT NOT NULL DEFAULT ''",
      'program_id': "TEXT NOT NULL DEFAULT ''",
      'source_type': "TEXT NOT NULL DEFAULT ''",
      'plan_id': "TEXT NOT NULL DEFAULT ''",
      'goal_skill_step_id': "TEXT NOT NULL DEFAULT ''",
      'reason': "TEXT NOT NULL DEFAULT 'retry'",
      'status': "TEXT NOT NULL DEFAULT 'pending'",
      'created_at': "TEXT NOT NULL DEFAULT ''",
      'resolved_at': "TEXT NOT NULL DEFAULT ''",
      'last_opened_at': "TEXT NOT NULL DEFAULT ''",
        'updated_at': "TEXT NOT NULL DEFAULT ''",
      },
      'session_skill_results': {
        'id': 'TEXT PRIMARY KEY',
        'session_id': 'TEXT NOT NULL',
        'goal_skill_step_id': 'TEXT NOT NULL',
        'goal_id': 'TEXT NOT NULL',
        'step_title': 'TEXT NOT NULL',
        "result": "TEXT NOT NULL DEFAULT 'لم يبدأ'",
        'created_at': 'TEXT NOT NULL',
        'updated_at': 'TEXT NOT NULL',
      },
    };
  return all[table]!;
}

/// All 26 table names in order.
List<String> allTableNames() => [
      'centers',
      'users',
      'students',
      'parents',
      'sessions',
      'evaluations',
      'training_plans',
      'goal_skill_steps',
      'exercises',
      'rewards',
      'reports',
      'clinical_assessments',
      'clinical_findings',
      'therapy_program_templates',
      'assessment_section_templates',
      'assessment_item_templates',
      'assessment_option_templates',
      'skill_step_templates',
      'speech_sound_trigger_templates',
      'sign_resources',
      'audit_logs',
      'student_therapy_programs',
      'assessment_drafts',
      'student_specialists',
      'student_followups',
      'session_skill_results',
    ];

void main() {
  sqfliteFfiInit();

  late Database db;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('PRAGMA foreign_keys = ON');
  });

  tearDown(() async {
    await db.close();
  });

  group('Full schema creation (all 25 tables)', () {
    test('createSchema creates all tables and ensureLatestSchema does not break anything', () async {
      await createSchema(db);

      // Verify all tables exist via sqlite_master
      final masterResult = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'");
      final createdTables = masterResult.map((r) => r['name'] as String).toSet();
      for (final table in allTableNames()) {
        expect(createdTables.contains(table), isTrue,
            reason: 'Table $table should exist after createSchema');
      }

      // Verify each table's columns via PRAGMA table_info
      for (final table in allTableNames()) {
        await verifyTableSchema(db, table, expectedColumns(table));
      }

      // Run ensureLatestSchema on top — should not throw and not add anything
      await ensureLatestSchema(db);

      // Verify still correct after ensureLatestSchema
      for (final table in allTableNames()) {
        await verifyTableSchema(db, table, expectedColumns(table));
      }
    });
  });

  group('Schema repair logic (ensureLatestSchema handles missing tables/columns)', () {
    test('creates table if missing', () async {
      // Don't create any tables; run ensureLatestSchema directly
      await ensureLatestSchema(db);

      for (final table in allTableNames()) {
        await verifyTableSchema(db, table, expectedColumns(table));
      }
    });

    test('adds missing columns to existing table', () async {
      // Create a minimal version of centers with only id and name
      await db.execute('''
        CREATE TABLE centers (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL
        )
      ''');

      // Run ensureLatestSchema — should add missing columns
      await ensureLatestSchema(db);

      final fullCols = expectedColumns('centers');
      await verifyTableSchema(db, 'centers', fullCols);

      // Verify we can insert with all default columns
      await db.insert('centers', {
        'id': 'test_center',
        'name': 'Test Center',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      final row = (await db.query('centers', where: 'id = ?', whereArgs: ['test_center'])).first;
      expect(row['name'], 'Test Center');
      expect(row['logo_path'], '');
      expect(row['address'], '');
      expect(row['phone'], '');
      expect(row['manager_name'], '');
      expect(row['is_active'], 1);
    });

    test('ensureLatestSchema is idempotent when called multiple times', () async {
      await createSchema(db);
      await ensureLatestSchema(db);
      await ensureLatestSchema(db);
      await ensureLatestSchema(db);

      for (final table in allTableNames()) {
        await verifyTableSchema(db, table, expectedColumns(table));
      }
    });
  });

  group('CRUD operations for each table', () {
    test('centers CRUD', () async {
      await createSchema(db);
      final now = DateTime.now().toIso8601String();

      // Insert
      await db.insert('centers', {
        'id': 'center_1',
        'name': 'Sanad Center',
        'logo_path': '/logos/center1.png',
        'address': '123 Main St',
        'phone': '555-0100',
        'manager_name': 'Ahmed',
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });

      // Query
      final rows = await db.query('centers', where: 'id = ?', whereArgs: ['center_1']);
      expect(rows.length, 1);
      expect(rows.first['name'], 'Sanad Center');
      expect(rows.first['logo_path'], '/logos/center1.png');
      expect(rows.first['address'], '123 Main St');
      expect(rows.first['phone'], '555-0100');
      expect(rows.first['manager_name'], 'Ahmed');
      expect(rows.first['is_active'], 1);

      // Update
      await db.update('centers', {'name': 'Sanad Center Updated'},
          where: 'id = ?', whereArgs: ['center_1']);
      final updated = (await db.query('centers', where: 'id = ?', whereArgs: ['center_1'])).first;
      expect(updated['name'], 'Sanad Center Updated');

      // Delete
      await db.delete('centers', where: 'id = ?', whereArgs: ['center_1']);
      final afterDelete = await db.query('centers', where: 'id = ?', whereArgs: ['center_1']);
      expect(afterDelete, isEmpty);
    });

    test('users CRUD', () async {
      await createSchema(db);
      final now = DateTime.now().toIso8601String();

      await db.insert('centers', {
        'id': 'center_u1', 'name': 'C', 'created_at': now, 'updated_at': now,
      });

      await db.insert('users', {
        'id': 'user_1',
        'center_id': 'center_u1',
        'email': 'user1@test.com',
        'password_hash': 'hash123',
        'name': 'User One',
        'role': 'specialist',
        'student_id': null,
        'force_password_change': 0,
        'is_demo': 0,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });

      final rows = await db.query('users', where: 'id = ?', whereArgs: ['user_1']);
      expect(rows.length, 1);
      expect(rows.first['email'], 'user1@test.com');
      expect(rows.first['name'], 'User One');
      expect(rows.first['role'], 'specialist');

      await db.update('users', {'name': 'User One Updated'},
          where: 'id = ?', whereArgs: ['user_1']);
      final updated = (await db.query('users', where: 'id = ?', whereArgs: ['user_1'])).first;
      expect(updated['name'], 'User One Updated');

      await db.delete('users', where: 'id = ?', whereArgs: ['user_1']);
      final afterDelete = await db.query('users', where: 'id = ?', whereArgs: ['user_1']);
      expect(afterDelete, isEmpty);
    });

    test('students CRUD', () async {
      await createSchema(db);
      final now = DateTime.now().toIso8601String();

      await db.insert('centers', {
        'id': 'center_s1', 'name': 'C', 'created_at': now, 'updated_at': now,
      });

      await db.insert('students', {
        'id': 'student_1',
        'center_id': 'center_s1',
        'name': 'Student One',
        'age': 7,
        'status': 'نشط',
        'diagnosis': 'تأخر نطقي',
        'program_type': 'نطق وتخاطب',
        'parent_name': 'Parent One',
        'parent_phone': '555-1000',
        'portal_email': 'parent1@test.com',
        'portal_password': 'pass123',
        'photo_path': '/photos/s1.jpg',
        'notes': 'Some notes',
        'deleted_at': '',
        'created_at': now,
        'updated_at': now,
      });

      final rows = await db.query('students', where: 'id = ?', whereArgs: ['student_1']);
      expect(rows.length, 1);
      expect(rows.first['name'], 'Student One');
      expect(rows.first['age'], 7);
      expect(rows.first['diagnosis'], 'تأخر نطقي');

      await db.update('students', {'name': 'Student One Updated'},
          where: 'id = ?', whereArgs: ['student_1']);
      final updated = (await db.query('students', where: 'id = ?', whereArgs: ['student_1'])).first;
      expect(updated['name'], 'Student One Updated');

      await db.delete('students', where: 'id = ?', whereArgs: ['student_1']);
      final afterDelete = await db.query('students', where: 'id = ?', whereArgs: ['student_1']);
      expect(afterDelete, isEmpty);
    });

    test('parents CRUD', () async {
      await createSchema(db);
      final now = DateTime.now().toIso8601String();

      await db.insert('centers', {
        'id': 'center_p1', 'name': 'C', 'created_at': now, 'updated_at': now,
      });
      await db.insert('students', {
        'id': 'student_p1', 'center_id': 'center_p1', 'name': 'S', 'age': 5,
        'status': 'نشط', 'diagnosis': '', 'parent_name': 'P', 'parent_phone': '555',
        'portal_email': 'p@t.com', 'portal_password': '', 'photo_path': '', 'notes': '',
        'created_at': now, 'updated_at': now,
      });

      await db.insert('parents', {
        'id': 'parent_1',
        'center_id': 'center_p1',
        'student_id': 'student_p1',
        'name': 'Parent One',
        'phone': '555-2000',
        'email': 'parent1@test.com',
        'created_at': now,
        'updated_at': now,
      });

      final rows = await db.query('parents', where: 'id = ?', whereArgs: ['parent_1']);
      expect(rows.length, 1);
      expect(rows.first['name'], 'Parent One');
      expect(rows.first['email'], 'parent1@test.com');

      await db.update('parents', {'name': 'Parent Updated'},
          where: 'id = ?', whereArgs: ['parent_1']);
      final updated = (await db.query('parents', where: 'id = ?', whereArgs: ['parent_1'])).first;
      expect(updated['name'], 'Parent Updated');

      await db.delete('parents', where: 'id = ?', whereArgs: ['parent_1']);
      final afterDelete = await db.query('parents', where: 'id = ?', whereArgs: ['parent_1']);
      expect(afterDelete, isEmpty);
    });

    test('sessions CRUD', () async {
      await createSchema(db);
      final now = DateTime.now().toIso8601String();

      await db.insert('centers', {
        'id': 'center_se1', 'name': 'C', 'created_at': now, 'updated_at': now,
      });
      await db.insert('students', {
        'id': 'student_se1', 'center_id': 'center_se1', 'name': 'S', 'age': 5,
        'status': '', 'diagnosis': '', 'parent_name': '', 'parent_phone': '',
        'portal_email': '', 'portal_password': '', 'photo_path': '', 'notes': '',
        'created_at': now, 'updated_at': now,
      });

      await db.insert('sessions', {
        'id': 'session_1',
        'center_id': 'center_se1',
        'student_id': 'student_se1',
        'specialist_id': 'spec_1',
        'plan_id': '',
        'program_id': '',
        'skill_id': '',
        'activity_results': '',
        'session_type': 'نطق وتخاطب',
        'target_letter': 'ر',
        'letter_position': 'بداية',
        'error_type': 'قلقلة',
        'practice_items': '',
        'attempts': 10,
        'success_rate': 80,
        'started_at': now,
        'duration_seconds': 1800,
        'card_title': 'Session 1',
        'quick_result': 'جيد',
        'notes': 'Good progress',
        'summary': '',
        'created_at': now,
        'updated_at': now,
      });

      final rows = await db.query('sessions', where: 'id = ?', whereArgs: ['session_1']);
      expect(rows.length, 1);
      expect(rows.first['card_title'], 'Session 1');
      expect(rows.first['duration_seconds'], 1800);
      expect(rows.first['attempts'], 10);
      expect(rows.first['success_rate'], 80);

      await db.update('sessions', {'notes': 'Updated notes'},
          where: 'id = ?', whereArgs: ['session_1']);
      final updated = (await db.query('sessions', where: 'id = ?', whereArgs: ['session_1'])).first;
      expect(updated['notes'], 'Updated notes');

      await db.delete('sessions', where: 'id = ?', whereArgs: ['session_1']);
      final afterDelete = await db.query('sessions', where: 'id = ?', whereArgs: ['session_1']);
      expect(afterDelete, isEmpty);
    });

    test('evaluations CRUD', () async {
      await createSchema(db);
      final now = DateTime.now().toIso8601String();

      await db.insert('centers', {
        'id': 'center_e1', 'name': 'C', 'created_at': now, 'updated_at': now,
      });
      await db.insert('students', {
        'id': 'student_e1', 'center_id': 'center_e1', 'name': 'S', 'age': 5,
        'status': '', 'diagnosis': '', 'parent_name': '', 'parent_phone': '',
        'portal_email': '', 'portal_password': '', 'photo_path': '', 'notes': '',
        'created_at': now, 'updated_at': now,
      });

      await db.insert('evaluations', {
        'id': 'eval_1',
        'center_id': 'center_e1',
        'student_id': 'student_e1',
        'letter': 'س',
        'position': 'وسط',
        'error_type': 'إبدال',
        'score': '2',
        'severity': 2,
        'recommendation': 'تمارين نطق',
        'created_at': now,
        'updated_at': now,
        'notes': 'Needs practice',
      });

      final rows = await db.query('evaluations', where: 'id = ?', whereArgs: ['eval_1']);
      expect(rows.length, 1);
      expect(rows.first['letter'], 'س');
      expect(rows.first['severity'], 2);
      expect(rows.first['score'], '2');

      await db.update('evaluations', {'score': '3'},
          where: 'id = ?', whereArgs: ['eval_1']);
      final updated = (await db.query('evaluations', where: 'id = ?', whereArgs: ['eval_1'])).first;
      expect(updated['score'], '3');

      await db.delete('evaluations', where: 'id = ?', whereArgs: ['eval_1']);
      expect(await db.query('evaluations', where: 'id = ?', whereArgs: ['eval_1']), isEmpty);
    });

    test('training_plans CRUD', () async {
      await createSchema(db);
      final now = DateTime.now().toIso8601String();

      await db.insert('centers', {
        'id': 'center_t1', 'name': 'C', 'created_at': now, 'updated_at': now,
      });
      await db.insert('students', {
        'id': 'student_t1', 'center_id': 'center_t1', 'name': 'S', 'age': 5,
        'status': '', 'diagnosis': '', 'parent_name': '', 'parent_phone': '',
        'portal_email': '', 'portal_password': '', 'photo_path': '', 'notes': '',
        'created_at': now, 'updated_at': now,
      });

      await db.insert('training_plans', {
        'id': 'plan_1',
        'center_id': 'center_t1',
        'student_id': 'student_t1',
        'goal': 'تحسين نطق حرف الراء',
        'treatment': 'تمارين يومية',
        'target_date': '2025-06-01',
        'progress': 50,
        'program_id': '',
        'source_type': 'standard',
        'created_at': now,
        'updated_at': now,
      });

      final rows = await db.query('training_plans', where: 'id = ?', whereArgs: ['plan_1']);
      expect(rows.length, 1);
      expect(rows.first['goal'], 'تحسين نطق حرف الراء');
      expect(rows.first['progress'], 50);

      await db.update('training_plans', {'progress': 75},
          where: 'id = ?', whereArgs: ['plan_1']);
      final updated = (await db.query('training_plans', where: 'id = ?', whereArgs: ['plan_1'])).first;
      expect(updated['progress'], 75);

      await db.delete('training_plans', where: 'id = ?', whereArgs: ['plan_1']);
      expect(await db.query('training_plans', where: 'id = ?', whereArgs: ['plan_1']), isEmpty);
    });

    test('goal_skill_steps CRUD', () async {
      await createSchema(db);
      final now = DateTime.now().toIso8601String();

      await db.insert('centers', {
        'id': 'center_g1', 'name': 'C', 'created_at': now, 'updated_at': now,
      });
      await db.insert('students', {
        'id': 'student_g1', 'center_id': 'center_g1', 'name': 'S', 'age': 5,
        'status': '', 'diagnosis': '', 'parent_name': '', 'parent_phone': '',
        'portal_email': '', 'portal_password': '', 'photo_path': '', 'notes': '',
        'created_at': now, 'updated_at': now,
      });
      await db.insert('training_plans', {
        'id': 'goal_g1', 'center_id': 'center_g1', 'student_id': 'student_g1',
        'goal': 'G', 'target_date': now, 'progress': 0,
        'created_at': now, 'updated_at': now,
      });

      await db.insert('goal_skill_steps', {
        'id': 'gstep_1',
        'center_id': 'center_g1',
        'student_id': 'student_g1',
        'goal_id': 'goal_g1',
        'title': 'Step 1',
        'status': 'لم يبدأ',
        'sort_order': 1,
        'notes': '',
        'last_session_id': '',
        'program_id': '',
        'source_type': 'standard',
        'created_at': now,
        'updated_at': now,
      });

      final rows = await db.query('goal_skill_steps', where: 'id = ?', whereArgs: ['gstep_1']);
      expect(rows.length, 1);
      expect(rows.first['title'], 'Step 1');
      expect(rows.first['sort_order'], 1);

      await db.update('goal_skill_steps', {'status': 'قيد التنفيذ'},
          where: 'id = ?', whereArgs: ['gstep_1']);
      final updated = (await db.query('goal_skill_steps', where: 'id = ?', whereArgs: ['gstep_1'])).first;
      expect(updated['status'], 'قيد التنفيذ');

      await db.delete('goal_skill_steps', where: 'id = ?', whereArgs: ['gstep_1']);
      expect(await db.query('goal_skill_steps', where: 'id = ?', whereArgs: ['gstep_1']), isEmpty);
    });

    test('exercises CRUD', () async {
      await createSchema(db);
      final now = DateTime.now().toIso8601String();

      await db.insert('centers', {
        'id': 'center_ex1', 'name': 'C', 'created_at': now, 'updated_at': now,
      });
      await db.insert('students', {
        'id': 'student_ex1', 'center_id': 'center_ex1', 'name': 'S', 'age': 5,
        'status': '', 'diagnosis': '', 'parent_name': '', 'parent_phone': '',
        'portal_email': '', 'portal_password': '', 'photo_path': '', 'notes': '',
        'created_at': now, 'updated_at': now,
      });

      await db.insert('exercises', {
        'id': 'exercise_1',
        'center_id': 'center_ex1',
        'student_id': 'student_ex1',
        'title': 'تمرين نطق',
        'instructions': 'كرر الحرف 10 مرات',
        'due_date': '2025-06-15',
        'status': 'pending',
        'audio_path': '/audio/ex1.mp3',
        'program_id': '',
        'plan_id': '',
        'goal_skill_step_id': '',
        'source_type': 'standard',
        'session_date': '',
        'parent_note': '',
        'note_for_parent': '',
        'parent_completed_at': '',
        'specialist_reviewed_at': '',
        'created_from_session_result': '',
        'stars': 0,
        'created_at': now,
        'updated_at': now,
      });

      final rows = await db.query('exercises', where: 'id = ?', whereArgs: ['exercise_1']);
      expect(rows.length, 1);
      expect(rows.first['title'], 'تمرين نطق');
      expect(rows.first['status'], 'pending');

      await db.update('exercises', {'stars': 3},
          where: 'id = ?', whereArgs: ['exercise_1']);
      final updated = (await db.query('exercises', where: 'id = ?', whereArgs: ['exercise_1'])).first;
      expect(updated['stars'], 3);

      await db.delete('exercises', where: 'id = ?', whereArgs: ['exercise_1']);
      expect(await db.query('exercises', where: 'id = ?', whereArgs: ['exercise_1']), isEmpty);
    });

    test('rewards CRUD', () async {
      await createSchema(db);
      final now = DateTime.now().toIso8601String();

      await db.insert('centers', {
        'id': 'center_r1', 'name': 'C', 'created_at': now, 'updated_at': now,
      });
      await db.insert('students', {
        'id': 'student_r1', 'center_id': 'center_r1', 'name': 'S', 'age': 5,
        'status': '', 'diagnosis': '', 'parent_name': '', 'parent_phone': '',
        'portal_email': '', 'portal_password': '', 'photo_path': '', 'notes': '',
        'created_at': now, 'updated_at': now,
      });

      await db.insert('rewards', {
        'id': 'reward_1',
        'center_id': 'center_r1',
        'student_id': 'student_r1',
        'xp': 100,
        'level': 2,
        'badges': 'star,super',
        'daily_streak': 5,
        'created_at': now,
        'updated_at': now,
      });

      final rows = await db.query('rewards', where: 'id = ?', whereArgs: ['reward_1']);
      expect(rows.length, 1);
      expect(rows.first['xp'], 100);
      expect(rows.first['level'], 2);
      expect(rows.first['daily_streak'], 5);

      await db.update('rewards', {'xp': 200},
          where: 'id = ?', whereArgs: ['reward_1']);
      final updated = (await db.query('rewards', where: 'id = ?', whereArgs: ['reward_1'])).first;
      expect(updated['xp'], 200);

      await db.delete('rewards', where: 'id = ?', whereArgs: ['reward_1']);
      expect(await db.query('rewards', where: 'id = ?', whereArgs: ['reward_1']), isEmpty);
    });

    test('reports CRUD', () async {
      await createSchema(db);
      final now = DateTime.now().toIso8601String();

      await db.insert('centers', {
        'id': 'center_rp1', 'name': 'C', 'created_at': now, 'updated_at': now,
      });
      await db.insert('students', {
        'id': 'student_rp1', 'center_id': 'center_rp1', 'name': 'S', 'age': 5,
        'status': '', 'diagnosis': '', 'parent_name': '', 'parent_phone': '',
        'portal_email': '', 'portal_password': '', 'photo_path': '', 'notes': '',
        'created_at': now, 'updated_at': now,
      });

      await db.insert('reports', {
        'id': 'report_1',
        'center_id': 'center_rp1',
        'student_id': 'student_rp1',
        'type': 'monthly',
        'created_at': now,
        'improvement_rate': 75,
        'specialist_signature': 'Dr. Ahmed',
        'manager_signature': 'Manager',
        'file_path': '/reports/r1.pdf',
        'updated_at': now,
      });

      final rows = await db.query('reports', where: 'id = ?', whereArgs: ['report_1']);
      expect(rows.length, 1);
      expect(rows.first['type'], 'monthly');
      expect(rows.first['improvement_rate'], 75);

      await db.update('reports', {'improvement_rate': 85},
          where: 'id = ?', whereArgs: ['report_1']);
      final updated = (await db.query('reports', where: 'id = ?', whereArgs: ['report_1'])).first;
      expect(updated['improvement_rate'], 85);

      await db.delete('reports', where: 'id = ?', whereArgs: ['report_1']);
      expect(await db.query('reports', where: 'id = ?', whereArgs: ['report_1']), isEmpty);
    });

    test('clinical_assessments CRUD', () async {
      await createSchema(db);
      final now = DateTime.now().toIso8601String();

      await db.insert('centers', {
        'id': 'center_ca1', 'name': 'C', 'created_at': now, 'updated_at': now,
      });
      await db.insert('students', {
        'id': 'student_ca1', 'center_id': 'center_ca1', 'name': 'S', 'age': 5,
        'status': '', 'diagnosis': '', 'parent_name': '', 'parent_phone': '',
        'portal_email': '', 'portal_password': '', 'photo_path': '', 'notes': '',
        'created_at': now, 'updated_at': now,
      });

      await db.insert('clinical_assessments', {
        'id': 'ca_1',
        'center_id': 'center_ca1',
        'student_id': 'student_ca1',
        'specialist_id': 'spec_1',
        'specialist_name': 'Dr. Ahmed',
        'type': 'speech',
        'strengths_summary': 'Good vocabulary',
        'weaknesses_summary': 'Letter pronunciation',
        'goals_summary': 'Improve speech',
        'training_summary': 'Daily exercises',
        'created_at': now,
        'updated_at': now,
      });

      final rows = await db.query('clinical_assessments', where: 'id = ?', whereArgs: ['ca_1']);
      expect(rows.length, 1);
      expect(rows.first['type'], 'speech');
      expect(rows.first['specialist_name'], 'Dr. Ahmed');

      await db.update('clinical_assessments', {'type': 'language'},
          where: 'id = ?', whereArgs: ['ca_1']);
      final updated = (await db.query('clinical_assessments', where: 'id = ?', whereArgs: ['ca_1'])).first;
      expect(updated['type'], 'language');

      await db.delete('clinical_assessments', where: 'id = ?', whereArgs: ['ca_1']);
      expect(await db.query('clinical_assessments', where: 'id = ?', whereArgs: ['ca_1']), isEmpty);
    });

    test('clinical_findings CRUD', () async {
      await createSchema(db);
      final now = DateTime.now().toIso8601String();

      await db.insert('centers', {
        'id': 'center_cf1', 'name': 'C', 'created_at': now, 'updated_at': now,
      });
      await db.insert('students', {
        'id': 'student_cf1', 'center_id': 'center_cf1', 'name': 'S', 'age': 5,
        'status': '', 'diagnosis': '', 'parent_name': '', 'parent_phone': '',
        'portal_email': '', 'portal_password': '', 'photo_path': '', 'notes': '',
        'created_at': now, 'updated_at': now,
      });
      await db.insert('clinical_assessments', {
        'id': 'ca_cf1', 'center_id': 'center_cf1', 'student_id': 'student_cf1',
        'type': 'speech', 'created_at': now, 'updated_at': now,
      });

      await db.insert('clinical_findings', {
        'id': 'cf_1',
        'assessment_id': 'ca_cf1',
        'center_id': 'center_cf1',
        'student_id': 'student_cf1',
        'domain': 'نطق',
        'item_title': 'حرف الراء',
        'result': 'ضعيف',
        'is_normal': 0,
        'weakness': 'صعوبة في نطق الراء',
        'goal': 'نطق الراء بشكل صحيح',
        'training': 'تمارين يومية',
        'program_id': '',
        'source_type': 'standard',
        'created_at': now,
        'updated_at': now,
      });

      final rows = await db.query('clinical_findings', where: 'id = ?', whereArgs: ['cf_1']);
      expect(rows.length, 1);
      expect(rows.first['domain'], 'نطق');
      expect(rows.first['is_normal'], 0);

      await db.update('clinical_findings', {'is_normal': 1},
          where: 'id = ?', whereArgs: ['cf_1']);
      final updated = (await db.query('clinical_findings', where: 'id = ?', whereArgs: ['cf_1'])).first;
      expect(updated['is_normal'], 1);

      await db.delete('clinical_findings', where: 'id = ?', whereArgs: ['cf_1']);
      expect(await db.query('clinical_findings', where: 'id = ?', whereArgs: ['cf_1']), isEmpty);
    });

    test('therapy_program_templates CRUD', () async {
      await createSchema(db);
      final now = DateTime.now().toIso8601String();

      await db.insert('therapy_program_templates', {
        'id': 'tpt_1',
        'center_id': '',
        'name': 'برنامج نطق',
        'description': 'تمارين نطق الحروف',
        'uses_speech_sounds': 1,
        'sort_order': 1,
        'created_at': now,
        'updated_at': now,
      });

      final rows = await db.query('therapy_program_templates', where: 'id = ?', whereArgs: ['tpt_1']);
      expect(rows.length, 1);
      expect(rows.first['name'], 'برنامج نطق');
      expect(rows.first['uses_speech_sounds'], 1);

      await db.update('therapy_program_templates', {'sort_order': 2},
          where: 'id = ?', whereArgs: ['tpt_1']);
      final updated = (await db.query('therapy_program_templates', where: 'id = ?', whereArgs: ['tpt_1'])).first;
      expect(updated['sort_order'], 2);

      await db.delete('therapy_program_templates', where: 'id = ?', whereArgs: ['tpt_1']);
      expect(await db.query('therapy_program_templates', where: 'id = ?', whereArgs: ['tpt_1']), isEmpty);
    });

    test('assessment_section_templates CRUD', () async {
      await createSchema(db);
      final now = DateTime.now().toIso8601String();

      await db.insert('assessment_section_templates', {
        'id': 'ast_1',
        'center_id': '',
        'program_id': '',
        'title': 'مهارات النطق',
        'description': 'تقييم مخارج الحروف',
        'sort_order': 1,
        'created_at': now,
        'updated_at': now,
      });

      final rows = await db.query('assessment_section_templates', where: 'id = ?', whereArgs: ['ast_1']);
      expect(rows.length, 1);
      expect(rows.first['title'], 'مهارات النطق');

      await db.update('assessment_section_templates', {'sort_order': 2},
          where: 'id = ?', whereArgs: ['ast_1']);
      final updated = (await db.query('assessment_section_templates', where: 'id = ?', whereArgs: ['ast_1'])).first;
      expect(updated['sort_order'], 2);

      await db.delete('assessment_section_templates', where: 'id = ?', whereArgs: ['ast_1']);
      expect(await db.query('assessment_section_templates', where: 'id = ?', whereArgs: ['ast_1']), isEmpty);
    });

    test('assessment_item_templates CRUD', () async {
      await createSchema(db);
      final now = DateTime.now().toIso8601String();

      await db.insert('assessment_section_templates', {
        'id': 'ast_item1', 'center_id': '', 'title': 'S', 'created_at': now, 'updated_at': now,
      });

      await db.insert('assessment_item_templates', {
        'id': 'ait_1',
        'center_id': '',
        'section_id': 'ast_item1',
        'title': 'نطق حرف الراء',
        'response_type': 'custom',
        'response_mode': 'singleChoice',
        'prompt': 'كيف ينطق الراء؟',
        'sort_order': 1,
        'created_at': now,
        'updated_at': now,
      });

      final rows = await db.query('assessment_item_templates', where: 'id = ?', whereArgs: ['ait_1']);
      expect(rows.length, 1);
      expect(rows.first['title'], 'نطق حرف الراء');

      await db.update('assessment_item_templates', {'sort_order': 2},
          where: 'id = ?', whereArgs: ['ait_1']);
      final updated = (await db.query('assessment_item_templates', where: 'id = ?', whereArgs: ['ait_1'])).first;
      expect(updated['sort_order'], 2);

      await db.delete('assessment_item_templates', where: 'id = ?', whereArgs: ['ait_1']);
      expect(await db.query('assessment_item_templates', where: 'id = ?', whereArgs: ['ait_1']), isEmpty);
    });

    test('assessment_option_templates CRUD', () async {
      await createSchema(db);
      final now = DateTime.now().toIso8601String();

      await db.insert('assessment_section_templates', {
        'id': 'ast_opt1', 'center_id': '', 'title': 'S', 'created_at': now, 'updated_at': now,
      });
      await db.insert('assessment_item_templates', {
        'id': 'ait_opt1', 'center_id': '', 'section_id': 'ast_opt1',
        'title': 'T', 'created_at': now, 'updated_at': now,
      });

      await db.insert('assessment_option_templates', {
        'id': 'aot_1',
        'center_id': '',
        'item_id': 'ait_opt1',
        'label': 'جيد',
        'generates_therapy': 1,
        'weakness_template': 'ضعف في النطق',
        'goal_template': 'تحسين النطق',
        'therapy_template': 'تمارين يومية',
        'sort_order': 1,
        'created_at': now,
        'updated_at': now,
      });

      final rows = await db.query('assessment_option_templates', where: 'id = ?', whereArgs: ['aot_1']);
      expect(rows.length, 1);
      expect(rows.first['label'], 'جيد');
      expect(rows.first['generates_therapy'], 1);

      await db.update('assessment_option_templates', {'generates_therapy': 0},
          where: 'id = ?', whereArgs: ['aot_1']);
      final updated = (await db.query('assessment_option_templates', where: 'id = ?', whereArgs: ['aot_1'])).first;
      expect(updated['generates_therapy'], 0);

      await db.delete('assessment_option_templates', where: 'id = ?', whereArgs: ['aot_1']);
      expect(await db.query('assessment_option_templates', where: 'id = ?', whereArgs: ['aot_1']), isEmpty);
    });

    test('skill_step_templates CRUD', () async {
      await createSchema(db);
      final now = DateTime.now().toIso8601String();

      await db.insert('skill_step_templates', {
        'id': 'sst_1',
        'center_id': '',
        'owner_type': 'option',
        'owner_id': 'opt_1',
        'title': 'الخطوة الأولى',
        'sort_order': 1,
        'created_at': now,
        'updated_at': now,
      });

      final rows = await db.query('skill_step_templates', where: 'id = ?', whereArgs: ['sst_1']);
      expect(rows.length, 1);
      expect(rows.first['title'], 'الخطوة الأولى');
      expect(rows.first['owner_type'], 'option');

      await db.update('skill_step_templates', {'sort_order': 2},
          where: 'id = ?', whereArgs: ['sst_1']);
      final updated = (await db.query('skill_step_templates', where: 'id = ?', whereArgs: ['sst_1'])).first;
      expect(updated['sort_order'], 2);

      await db.delete('skill_step_templates', where: 'id = ?', whereArgs: ['sst_1']);
      expect(await db.query('skill_step_templates', where: 'id = ?', whereArgs: ['sst_1']), isEmpty);
    });

    test('speech_sound_trigger_templates CRUD', () async {
      await createSchema(db);
      final now = DateTime.now().toIso8601String();

      await db.insert('speech_sound_trigger_templates', {
        'id': 'sstt_1',
        'center_id': '',
        'program_id': '',
        'letter': 'ر',
        'error_type': 'قلقلة',
        'position': 'بداية',
        'generates_therapy': 1,
        'weakness_template': 'ضعف في الراء',
        'goal_template': 'تحسين الراء',
        'therapy_template': 'تمارين الراء',
        'skill_steps_json': '[]',
        'sort_order': 1,
        'created_at': now,
        'updated_at': now,
      });

      final rows = await db.query('speech_sound_trigger_templates', where: 'id = ?', whereArgs: ['sstt_1']);
      expect(rows.length, 1);
      expect(rows.first['letter'], 'ر');
      expect(rows.first['generates_therapy'], 1);

      await db.update('speech_sound_trigger_templates', {'generates_therapy': 0},
          where: 'id = ?', whereArgs: ['sstt_1']);
      final updated = (await db.query('speech_sound_trigger_templates', where: 'id = ?', whereArgs: ['sstt_1'])).first;
      expect(updated['generates_therapy'], 0);

      await db.delete('speech_sound_trigger_templates', where: 'id = ?', whereArgs: ['sstt_1']);
      expect(await db.query('speech_sound_trigger_templates', where: 'id = ?', whereArgs: ['sstt_1']), isEmpty);
    });

    test('sign_resources CRUD', () async {
      await createSchema(db);
      final now = DateTime.now().toIso8601String();

      await db.insert('centers', {
        'id': 'center_sr1', 'name': 'C', 'created_at': now, 'updated_at': now,
      });

      await db.insert('sign_resources', {
        'id': 'sr_1',
        'center_id': 'center_sr1',
        'title': 'إشارة السلام',
        'category': 'تحية',
        'media_type': 'image',
        'media_path': '/media/salam.jpg',
        'notes': 'شرح الإشارة',
        'level': 'مبتدئ',
        'is_favorite': 0,
        'created_at': now,
        'updated_at': now,
      });

      final rows = await db.query('sign_resources', where: 'id = ?', whereArgs: ['sr_1']);
      expect(rows.length, 1);
      expect(rows.first['title'], 'إشارة السلام');
      expect(rows.first['is_favorite'], 0);

      await db.update('sign_resources', {'is_favorite': 1},
          where: 'id = ?', whereArgs: ['sr_1']);
      final updated = (await db.query('sign_resources', where: 'id = ?', whereArgs: ['sr_1'])).first;
      expect(updated['is_favorite'], 1);

      await db.delete('sign_resources', where: 'id = ?', whereArgs: ['sr_1']);
      expect(await db.query('sign_resources', where: 'id = ?', whereArgs: ['sr_1']), isEmpty);
    });

    test('audit_logs CRUD', () async {
      await createSchema(db);
      final now = DateTime.now().toIso8601String();

      await db.insert('audit_logs', {
        'id': 'al_1',
        'center_id': '',
        'user_id': 'user_1',
        'user_name': 'Admin',
        'action': 'create',
        'entity_type': 'student',
        'entity_id': 'student_1',
        'details': 'Created student record',
        'created_at': now,
        'updated_at': now,
      });

      final rows = await db.query('audit_logs', where: 'id = ?', whereArgs: ['al_1']);
      expect(rows.length, 1);
      expect(rows.first['action'], 'create');
      expect(rows.first['entity_type'], 'student');

      await db.update('audit_logs', {'details': 'Updated details'},
          where: 'id = ?', whereArgs: ['al_1']);
      final updated = (await db.query('audit_logs', where: 'id = ?', whereArgs: ['al_1'])).first;
      expect(updated['details'], 'Updated details');

      await db.delete('audit_logs', where: 'id = ?', whereArgs: ['al_1']);
      expect(await db.query('audit_logs', where: 'id = ?', whereArgs: ['al_1']), isEmpty);
    });

    test('student_therapy_programs CRUD', () async {
      await createSchema(db);
      final now = DateTime.now().toIso8601String();

      await db.insert('centers', {
        'id': 'center_stp1', 'name': 'C', 'created_at': now, 'updated_at': now,
      });
      await db.insert('students', {
        'id': 'student_stp1', 'center_id': 'center_stp1', 'name': 'S', 'age': 5,
        'status': '', 'diagnosis': '', 'parent_name': '', 'parent_phone': '',
        'portal_email': '', 'portal_password': '', 'photo_path': '', 'notes': '',
        'created_at': now, 'updated_at': now,
      });

      await db.insert('student_therapy_programs', {
        'id': 'stp_1',
        'student_id': 'student_stp1',
        'program_id': 'prog_1',
        'assigned_at': now,
        'assigned_by_user_id': 'user_1',
        'is_active': 1,
        'sort_order': 0,
        'created_at': now,
        'updated_at': now,
      });

      final rows = await db.query('student_therapy_programs', where: 'id = ?', whereArgs: ['stp_1']);
      expect(rows.length, 1);
      expect(rows.first['program_id'], 'prog_1');
      expect(rows.first['is_active'], 1);

      await db.update('student_therapy_programs', {'is_active': 0},
          where: 'id = ?', whereArgs: ['stp_1']);
      final updated = (await db.query('student_therapy_programs', where: 'id = ?', whereArgs: ['stp_1'])).first;
      expect(updated['is_active'], 0);

      await db.delete('student_therapy_programs', where: 'id = ?', whereArgs: ['stp_1']);
      expect(await db.query('student_therapy_programs', where: 'id = ?', whereArgs: ['stp_1']), isEmpty);
    });

    test('assessment_drafts CRUD', () async {
      await createSchema(db);
      final now = DateTime.now().toIso8601String();

      await db.insert('centers', {
        'id': 'center_ad1', 'name': 'C', 'created_at': now, 'updated_at': now,
      });
      await db.insert('students', {
        'id': 'student_ad1', 'center_id': 'center_ad1', 'name': 'S', 'age': 5,
        'status': '', 'diagnosis': '', 'parent_name': '', 'parent_phone': '',
        'portal_email': '', 'portal_password': '', 'photo_path': '', 'notes': '',
        'created_at': now, 'updated_at': now,
      });

      // assessment_drafts has composite PK (student_id, program_id)
      await db.insert('assessment_drafts', {
        'student_id': 'student_ad1',
        'program_id': 'prog_ad1',
        'phase': 'sections',
        'step_index': 0,
        'current_letter': '',
        'selections_json': '{}',
        'multi_selections_json': '{}',
        'matrix_selections_json': '[]',
        'letter_results_json': '{}',
        'created_at': now,
        'updated_at': now,
      });

      final rows = await db.query('assessment_drafts',
          where: 'student_id = ? AND program_id = ?',
          whereArgs: ['student_ad1', 'prog_ad1']);
      expect(rows.length, 1);
      expect(rows.first['phase'], 'sections');
      expect(rows.first['step_index'], 0);

      await db.update('assessment_drafts', {'step_index': 2},
          where: 'student_id = ? AND program_id = ?',
          whereArgs: ['student_ad1', 'prog_ad1']);
      final updated = (await db.query('assessment_drafts',
          where: 'student_id = ? AND program_id = ?',
          whereArgs: ['student_ad1', 'prog_ad1'])).first;
      expect(updated['step_index'], 2);

      await db.delete('assessment_drafts',
          where: 'student_id = ? AND program_id = ?',
          whereArgs: ['student_ad1', 'prog_ad1']);
      expect(await db.query('assessment_drafts',
          where: 'student_id = ? AND program_id = ?',
          whereArgs: ['student_ad1', 'prog_ad1']), isEmpty);
    });

    test('student_specialists CRUD', () async {
      await createSchema(db);
      final now = DateTime.now().toIso8601String();

      await db.insert('centers', {
        'id': 'center_ss1', 'name': 'C', 'created_at': now, 'updated_at': now,
      });
      await db.insert('students', {
        'id': 'student_ss1', 'center_id': 'center_ss1', 'name': 'S', 'age': 5,
        'status': '', 'diagnosis': '', 'parent_name': '', 'parent_phone': '',
        'portal_email': '', 'portal_password': '', 'photo_path': '', 'notes': '',
        'created_at': now, 'updated_at': now,
      });

      await db.insert('student_specialists', {
        'id': 'ss_1',
        'student_id': 'student_ss1',
        'specialist_id': 'spec_ss1',
        'assigned_by_user_id': 'admin_1',
        'assigned_at': now,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });

      final rows = await db.query('student_specialists', where: 'id = ?', whereArgs: ['ss_1']);
      expect(rows.length, 1);
      expect(rows.first['specialist_id'], 'spec_ss1');
      expect(rows.first['is_active'], 1);

      await db.update('student_specialists', {'is_active': 0},
          where: 'id = ?', whereArgs: ['ss_1']);
      final updated = (await db.query('student_specialists', where: 'id = ?', whereArgs: ['ss_1'])).first;
      expect(updated['is_active'], 0);

      await db.delete('student_specialists', where: 'id = ?', whereArgs: ['ss_1']);
      expect(await db.query('student_specialists', where: 'id = ?', whereArgs: ['ss_1']), isEmpty);
    });

    test('student_followups CRUD', () async {
      await createSchema(db);
      final now = DateTime.now().toIso8601String();

      await db.insert('centers', {
        'id': 'center_sf1', 'name': 'C', 'created_at': now, 'updated_at': now,
      });
      await db.insert('students', {
        'id': 'student_sf1', 'center_id': 'center_sf1', 'name': 'S', 'age': 5,
        'status': '', 'diagnosis': '', 'parent_name': '', 'parent_phone': '',
        'portal_email': '', 'portal_password': '', 'photo_path': '', 'notes': '',
        'created_at': now, 'updated_at': now,
      });

      await db.insert('student_followups', {
        'id': 'sf_1',
        'student_id': 'student_sf1',
        'specialist_id': '',
        'program_id': '',
        'source_type': '',
        'plan_id': '',
        'goal_skill_step_id': '',
        'reason': 'retry',
        'status': 'pending',
        'created_at': now,
        'resolved_at': '',
        'last_opened_at': '',
        'updated_at': now,
      });

      final rows = await db.query('student_followups', where: 'id = ?', whereArgs: ['sf_1']);
      expect(rows.length, 1);
      expect(rows.first['reason'], 'retry');
      expect(rows.first['status'], 'pending');

      await db.update('student_followups', {'status': 'completed'},
          where: 'id = ?', whereArgs: ['sf_1']);
      final updated = (await db.query('student_followups', where: 'id = ?', whereArgs: ['sf_1'])).first;
      expect(updated['status'], 'completed');

      await db.delete('student_followups', where: 'id = ?', whereArgs: ['sf_1']);
      expect(await db.query('student_followups', where: 'id = ?', whereArgs: ['sf_1']), isEmpty);
    });

    test('session_skill_results CRUD', () async {
      await createSchema(db);
      final now = DateTime.now().toIso8601String();

      await db.insert('centers', {
        'id': 'center_ssr1', 'name': 'C', 'created_at': now, 'updated_at': now,
      });
      await db.insert('students', {
        'id': 'student_ssr1', 'center_id': 'center_ssr1', 'name': 'S', 'age': 5,
        'status': '', 'diagnosis': '', 'parent_name': '', 'parent_phone': '',
        'portal_email': '', 'portal_password': '', 'photo_path': '', 'notes': '',
        'created_at': now, 'updated_at': now,
      });
      await db.insert('sessions', {
        'id': 'session_ssr1', 'center_id': 'center_ssr1', 'student_id': 'student_ssr1',
        'started_at': now, 'duration_seconds': 0, 'card_title': 'Test',
        'quick_result': 'متقن', 'notes': '', 'created_at': now, 'updated_at': now,
      });

      await db.insert('session_skill_results', {
        'id': 'ssr_1',
        'session_id': 'session_ssr1',
        'goal_skill_step_id': 'step_1',
        'goal_id': 'goal_1',
        'step_title': 'مهارة 1',
        'result': 'متقن',
        'created_at': now,
        'updated_at': now,
      });

      var rows = await db.query('session_skill_results', where: 'id = ?', whereArgs: ['ssr_1']);
      expect(rows.length, 1);
      expect(rows.first['step_title'], 'مهارة 1');
      expect(rows.first['result'], 'متقن');

      await db.update('session_skill_results', {'result': 'بمساعدة'},
          where: 'id = ?', whereArgs: ['ssr_1']);
      var updated = (await db.query('session_skill_results', where: 'id = ?', whereArgs: ['ssr_1'])).first;
      expect(updated['result'], 'بمساعدة');

      await db.delete('session_skill_results', where: 'id = ?', whereArgs: ['ssr_1']);
      expect(await db.query('session_skill_results', where: 'id = ?', whereArgs: ['ssr_1']), isEmpty);
    });
  });

  group('Key workflow: create center → user → student → assign specialist → program → clinical assessment → findings → training plans → goal_skill_steps → exercises → sessions → evaluations → rewards → reports', () {
    test('full end-to-end workflow', () async {
      await createSchema(db);
      final now = DateTime.now().toIso8601String();

      // 1. Create center
      await db.insert('centers', {
        'id': 'center_wf',
        'name': 'Sanad Speech Center',
        'logo_path': '/logos/sanad.png',
        'address': 'Cairo, Egypt',
        'phone': '+20-100-000-000',
        'manager_name': 'Dr. Ali',
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });
      var centerRows = await db.query('centers', where: 'id = ?', whereArgs: ['center_wf']);
      expect(centerRows.length, 1);
      expect(centerRows.first['name'], 'Sanad Speech Center');
      expect(centerRows.first['is_active'], 1);

      // 2. Create user (specialist)
      await db.insert('users', {
        'id': 'user_wf_spec',
        'center_id': 'center_wf',
        'email': 'specialist@sanad.com',
        'password_hash': 'hashed_pwd',
        'name': 'Dr. Specialist',
        'role': 'specialist',
        'student_id': null,
        'force_password_change': 0,
        'is_demo': 0,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });
      var userRows = await db.query('users', where: 'id = ?', whereArgs: ['user_wf_spec']);
      expect(userRows.length, 1);
      expect(userRows.first['email'], 'specialist@sanad.com');

      // 3. Create student
      await db.insert('students', {
        'id': 'student_wf',
        'center_id': 'center_wf',
        'name': 'Ahmed',
        'age': 8,
        'status': 'نشط',
        'diagnosis': 'تأخر نطقي',
        'program_type': 'نطق وتخاطب',
        'parent_name': 'Parent Ahmed',
        'parent_phone': '+20-111-111-111',
        'portal_email': 'parent_ahmed@test.com',
        'portal_password': 'temp123',
        'photo_path': '/photos/ahmed.jpg',
        'notes': 'تحسن ملحوظ',
        'deleted_at': '',
        'created_at': now,
        'updated_at': now,
      });
      var studentRows = await db.query('students', where: 'id = ?', whereArgs: ['student_wf']);
      expect(studentRows.length, 1);
      expect(studentRows.first['name'], 'Ahmed');
      expect(studentRows.first['age'], 8);

      // 4. Create parent profile
      await db.insert('parents', {
        'id': 'parent_wf',
        'center_id': 'center_wf',
        'student_id': 'student_wf',
        'name': 'Parent Ahmed',
        'phone': '+20-111-111-111',
        'email': 'parent_ahmed@test.com',
        'created_at': now,
        'updated_at': now,
      });
      var parentRows = await db.query('parents', where: 'id = ?', whereArgs: ['parent_wf']);
      expect(parentRows.length, 1);
      expect(parentRows.first['name'], 'Parent Ahmed');

      // 5. Assign specialist to student
      await db.insert('student_specialists', {
        'id': 'ss_wf',
        'student_id': 'student_wf',
        'specialist_id': 'user_wf_spec',
        'assigned_by_user_id': 'user_wf_spec',
        'assigned_at': now,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });
      var ssRows = await db.query('student_specialists', where: 'id = ?', whereArgs: ['ss_wf']);
      expect(ssRows.length, 1);
      expect(ssRows.first['is_active'], 1);

      // 6. Create therapy program template
      await db.insert('therapy_program_templates', {
        'id': 'prog_wf',
        'center_id': 'center_wf',
        'name': 'برنامج نطق متقدم',
        'description': 'لتحسين مخارج الحروف',
        'uses_speech_sounds': 1,
        'sort_order': 1,
        'created_at': now,
        'updated_at': now,
      });
      var progRows = await db.query('therapy_program_templates', where: 'id = ?', whereArgs: ['prog_wf']);
      expect(progRows.length, 1);
      expect(progRows.first['name'], 'برنامج نطق متقدم');

      // 7. Assign program to student
      await db.insert('student_therapy_programs', {
        'id': 'stp_wf',
        'student_id': 'student_wf',
        'program_id': 'prog_wf',
        'assigned_at': now,
        'assigned_by_user_id': 'user_wf_spec',
        'is_active': 1,
        'sort_order': 0,
        'created_at': now,
        'updated_at': now,
      });
      var stpRows = await db.query('student_therapy_programs', where: 'id = ?', whereArgs: ['stp_wf']);
      expect(stpRows.length, 1);
      expect(stpRows.first['is_active'], 1);

      // 8. Create clinical assessment
      await db.insert('clinical_assessments', {
        'id': 'ca_wf',
        'center_id': 'center_wf',
        'student_id': 'student_wf',
        'specialist_id': 'user_wf_spec',
        'specialist_name': 'Dr. Specialist',
        'type': 'speech',
        'strengths_summary': 'مفردات جيدة',
        'weaknesses_summary': 'صعوبة في نطق بعض الحروف',
        'goals_summary': 'تحسين نطق الحروف',
        'training_summary': 'تمارين يومية لمدة 15 دقيقة',
        'created_at': now,
        'updated_at': now,
      });
      var caRows = await db.query('clinical_assessments', where: 'id = ?', whereArgs: ['ca_wf']);
      expect(caRows.length, 1);
      expect(caRows.first['specialist_name'], 'Dr. Specialist');

      // 9. Create clinical findings
      await db.insert('clinical_findings', {
        'id': 'cf_wf_1',
        'assessment_id': 'ca_wf',
        'center_id': 'center_wf',
        'student_id': 'student_wf',
        'domain': 'نطق',
        'item_title': 'حرف الراء',
        'result': 'ضعيف',
        'is_normal': 0,
        'weakness': 'عدم القدرة على نطق الراء',
        'goal': 'نطق الراء بشكل صحيح في 80% من المحاولات',
        'training': 'تمارين اللسان',
        'program_id': 'prog_wf',
        'source_type': 'standard',
        'created_at': now,
        'updated_at': now,
      });
      await db.insert('clinical_findings', {
        'id': 'cf_wf_2',
        'assessment_id': 'ca_wf',
        'center_id': 'center_wf',
        'student_id': 'student_wf',
        'domain': 'نطق',
        'item_title': 'حرف السين',
        'result': 'متوسط',
        'is_normal': 0,
        'weakness': 'إبدال السين بالثاء',
        'goal': 'نطق السين بشكل صحيح',
        'training': 'تمارين أمام المرآة',
        'program_id': 'prog_wf',
        'source_type': 'standard',
        'created_at': now,
        'updated_at': now,
      });
      var cfRows = await db.query('clinical_findings',
          where: 'assessment_id = ?', whereArgs: ['ca_wf']);
      expect(cfRows.length, 2);

      // 10. Create training plans
      await db.insert('training_plans', {
        'id': 'plan_wf_1',
        'center_id': 'center_wf',
        'student_id': 'student_wf',
        'goal': 'نطق حرف الراء',
        'treatment': 'تمارين يومية',
        'target_date': '2025-07-01',
        'progress': 30,
        'program_id': 'prog_wf',
        'source_type': 'standard',
        'created_at': now,
        'updated_at': now,
      });
      await db.insert('training_plans', {
        'id': 'plan_wf_2',
        'center_id': 'center_wf',
        'student_id': 'student_wf',
        'goal': 'نطق حرف السين',
        'treatment': 'تمارين أسبوعية',
        'target_date': '2025-08-01',
        'progress': 10,
        'program_id': 'prog_wf',
        'source_type': 'standard',
        'created_at': now,
        'updated_at': now,
      });
      var planRows = await db.query('training_plans',
          where: 'student_id = ?', whereArgs: ['student_wf']);
      expect(planRows.length, 2);

      // 11. Create goal_skill_steps
      await db.insert('goal_skill_steps', {
        'id': 'gstep_wf_1',
        'center_id': 'center_wf',
        'student_id': 'student_wf',
        'goal_id': 'plan_wf_1',
        'title': 'نطق الراء منفرداً',
        'status': 'قيد التنفيذ',
        'sort_order': 1,
        'notes': 'يحتاج إلى متابعة',
        'last_session_id': '',
        'program_id': 'prog_wf',
        'source_type': 'standard',
        'created_at': now,
        'updated_at': now,
      });
      await db.insert('goal_skill_steps', {
        'id': 'gstep_wf_2',
        'center_id': 'center_wf',
        'student_id': 'student_wf',
        'goal_id': 'plan_wf_1',
        'title': 'نطق الراء في كلمات',
        'status': 'لم يبدأ',
        'sort_order': 2,
        'notes': '',
        'last_session_id': '',
        'program_id': 'prog_wf',
        'source_type': 'standard',
        'created_at': now,
        'updated_at': now,
      });
      var gstepRows = await db.query('goal_skill_steps',
          where: 'goal_id = ?', whereArgs: ['plan_wf_1']);
      expect(gstepRows.length, 2);

      // 12. Create exercises
      await db.insert('exercises', {
        'id': 'ex_wf_1',
        'center_id': 'center_wf',
        'student_id': 'student_wf',
        'title': 'تمرين نطق الراء',
        'instructions': 'كرر حرف الراء 10 مرات أمام المرآة',
        'due_date': '2025-06-20',
        'status': 'pending',
        'audio_path': '/audio/ex_r.mp3',
        'program_id': 'prog_wf',
        'plan_id': 'plan_wf_1',
        'goal_skill_step_id': 'gstep_wf_1',
        'source_type': 'standard',
        'session_date': '',
        'parent_note': '',
        'note_for_parent': 'ساعد طفلك في التمارين',
        'parent_completed_at': '',
        'specialist_reviewed_at': '',
        'created_from_session_result': '',
        'stars': 0,
        'created_at': now,
        'updated_at': now,
      });
      var exRows = await db.query('exercises',
          where: 'student_id = ?', whereArgs: ['student_wf']);
      expect(exRows.length, 1);
      expect(exRows.first['title'], 'تمرين نطق الراء');

      // 13. Create sessions
      await db.insert('sessions', {
        'id': 'session_wf_1',
        'center_id': 'center_wf',
        'student_id': 'student_wf',
        'specialist_id': 'user_wf_spec',
        'plan_id': 'plan_wf_1',
        'program_id': 'prog_wf',
        'skill_id': 'gstep_wf_1',
        'activity_results': '{"result": "good"}',
        'session_type': 'نطق وتخاطب',
        'target_letter': 'ر',
        'letter_position': 'بداية',
        'error_type': 'قلقلة',
        'practice_items': 'كرر 10 مرات',
        'attempts': 10,
        'success_rate': 60,
        'started_at': now,
        'duration_seconds': 1800,
        'card_title': 'جلسة تقييم الراء',
        'quick_result': 'متوسط',
        'notes': 'بدأ يتحسن',
        'summary': 'تم التركيز على نطق الراء',
        'created_at': now,
        'updated_at': now,
      });
      await db.insert('sessions', {
        'id': 'session_wf_2',
        'center_id': 'center_wf',
        'student_id': 'student_wf',
        'specialist_id': 'user_wf_spec',
        'plan_id': 'plan_wf_2',
        'program_id': 'prog_wf',
        'skill_id': '',
        'activity_results': '',
        'session_type': 'نطق وتخاطب',
        'target_letter': 'س',
        'letter_position': 'وسط',
        'error_type': 'إبدال',
        'practice_items': '',
        'attempts': 8,
        'success_rate': 40,
        'started_at': now,
        'duration_seconds': 1500,
        'card_title': 'جلسة تقييم السين',
        'quick_result': 'تحتاج متابعة',
        'notes': 'صعوبة في إخراج السين',
        'summary': '',
        'created_at': now,
        'updated_at': now,
      });
      var sessionRows = await db.query('sessions',
          where: 'student_id = ?', whereArgs: ['student_wf']);
      expect(sessionRows.length, 2);

      // 14. Create evaluations
      await db.insert('evaluations', {
        'id': 'eval_wf_1',
        'center_id': 'center_wf',
        'student_id': 'student_wf',
        'letter': 'ر',
        'position': 'بداية',
        'error_type': 'قلقلة',
        'score': '2',
        'severity': 2,
        'recommendation': 'استمرار تمارين الراء',
        'created_at': now,
        'updated_at': now,
        'notes': 'تحسن من الدرجة 1',
      });
      await db.insert('evaluations', {
        'id': 'eval_wf_2',
        'center_id': 'center_wf',
        'student_id': 'student_wf',
        'letter': 'س',
        'position': 'وسط',
        'error_type': 'إبدال',
        'score': '3',
        'severity': 3,
        'recommendation': 'تمارين السين',
        'created_at': now,
        'updated_at': now,
        'notes': 'يحتاج تركيز أكثر',
      });
      var evalRows = await db.query('evaluations',
          where: 'student_id = ?', whereArgs: ['student_wf']);
      expect(evalRows.length, 2);
      expect(evalRows.first['letter'], 'ر');

      // 15. Create rewards
      await db.insert('rewards', {
        'id': 'reward_wf',
        'center_id': 'center_wf',
        'student_id': 'student_wf',
        'xp': 250,
        'level': 3,
        'badges': 'star,lightning',
        'daily_streak': 7,
        'created_at': now,
        'updated_at': now,
      });
      var rewardRows = await db.query('rewards',
          where: 'student_id = ?', whereArgs: ['student_wf']);
      expect(rewardRows.length, 1);
      expect(rewardRows.first['xp'], 250);
      expect(rewardRows.first['level'], 3);

      // 16. Create reports
      await db.insert('reports', {
        'id': 'report_wf',
        'center_id': 'center_wf',
        'student_id': 'student_wf',
        'type': 'monthly',
        'created_at': now,
        'improvement_rate': 65,
        'specialist_signature': 'Dr. Specialist',
        'manager_signature': 'Dr. Manager',
        'file_path': '/reports/ahmed_monthly.pdf',
        'updated_at': now,
      });
      var reportRows = await db.query('reports',
          where: 'student_id = ?', whereArgs: ['student_wf']);
      expect(reportRows.length, 1);
      expect(reportRows.first['improvement_rate'], 65);

      // 17. Create followup
      await db.insert('student_followups', {
        'id': 'sf_wf',
        'student_id': 'student_wf',
        'specialist_id': 'user_wf_spec',
        'program_id': 'prog_wf',
        'source_type': 'session',
        'plan_id': 'plan_wf_1',
        'goal_skill_step_id': 'gstep_wf_1',
        'reason': 'needs_review',
        'status': 'pending',
        'created_at': now,
        'resolved_at': '',
        'last_opened_at': '',
        'updated_at': now,
      });
      var sfRows = await db.query('student_followups',
          where: 'student_id = ?', whereArgs: ['student_wf']);
      expect(sfRows.length, 1);
      expect(sfRows.first['status'], 'pending');

      // 18. Audit log
      await db.insert('audit_logs', {
        'id': 'al_wf',
        'center_id': 'center_wf',
        'user_id': 'user_wf_spec',
        'user_name': 'Dr. Specialist',
        'action': 'create',
        'entity_type': 'student',
        'entity_id': 'student_wf',
        'details': 'تم إنشاء ملف الطالب وكافة السجلات المرتبطة',
        'created_at': now,
        'updated_at': now,
      });
      var alRows = await db.query('audit_logs', where: 'id = ?', whereArgs: ['al_wf']);
      expect(alRows.length, 1);
      expect(alRows.first['action'], 'create');

      // Final: verify counts across all 18 used tables
      expect((await db.query('centers')).length, 1);
      expect((await db.query('users')).length, 1);
      expect((await db.query('students')).length, 1);
      expect((await db.query('parents')).length, 1);
      expect((await db.query('student_specialists')).length, 1);
      expect((await db.query('therapy_program_templates')).length, 1);
      expect((await db.query('student_therapy_programs')).length, 1);
      expect((await db.query('clinical_assessments')).length, 1);
      expect((await db.query('clinical_findings')).length, 2);
      expect((await db.query('training_plans')).length, 2);
      expect((await db.query('goal_skill_steps')).length, 2);
      expect((await db.query('exercises')).length, 1);
      expect((await db.query('sessions')).length, 2);
      expect((await db.query('evaluations')).length, 2);
      expect((await db.query('rewards')).length, 1);
      expect((await db.query('reports')).length, 1);
      expect((await db.query('student_followups')).length, 1);
      expect((await db.query('audit_logs')).length, 1);
    });
  });

  group('Foreign key constraints', () {
    test('PRAGMA foreign_keys is ON', () async {
      await createSchema(db);
      final result = await db.rawQuery('PRAGMA foreign_keys');
      expect(result.first['foreign_keys'], 1);
    });

    test('inserting student without center_id fails', () async {
      await createSchema(db);
      final now = DateTime.now().toIso8601String();
      expect(() async {
        await db.insert('students', {
          'id': 'orphan_student',
          'center_id': 'nonexistent_center',
          'name': 'Orphan',
          'age': 5,
          'status': '',
          'diagnosis': '',
          'parent_name': '',
          'parent_phone': '',
          'portal_email': '',
          'portal_password': '',
          'photo_path': '',
          'notes': '',
          'created_at': now,
          'updated_at': now,
        });
      }, throwsA(isA<DatabaseException>()));
    });
  });
}
