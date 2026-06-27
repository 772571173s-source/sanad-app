import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart' as mobile;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import 'auth_service.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();
  static const currentVersion = 34;

  mobile.Database? _database;

  Future<mobile.Database> get database async {
    if (_database != null) return _database!;
    final factory = _databaseFactory();
    final dbPath = await factory.getDatabasesPath();
    _database = await factory.openDatabase(
      path.join(dbPath, 'sanad_mvp.db'),
      options: mobile.OpenDatabaseOptions(
        version: currentVersion,
        onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await _createSchema(db);
        },
        onUpgrade: _upgrade,
        onOpen: (db) async {
          await _repairStoredArabicText(db);
          await _ensureLatestSchema(db);
        },
      ),
    );
    return _database!;
  }

  dynamic _databaseFactory() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      ffi.sqfliteFfiInit();
      return ffi.databaseFactoryFfi;
    }
    return mobile.databaseFactory;
  }

  Future<String> databaseFilePath() async {
    final factory = _databaseFactory();
    final dbPath = await factory.getDatabasesPath();
    return path.join(dbPath, 'sanad_mvp.db');
  }

  Future<void> exportBackup(String targetPath) async {
    await database;
    final source = File(await databaseFilePath());
    await source.copy(targetPath);
  }

  /// Exports all data belonging to a single center as a JSON map.
  /// Does NOT include full DB copy – only center-scoped records.
  Future<Map<String, dynamic>> exportCenterBackup(String centerId) async {
    final db = await database;
    final backup = <String, dynamic>{};
    final tables = <String, String>{
      'centers': "id = '$centerId'",
      'users': "center_id = '$centerId'",
      'students': "center_id = '$centerId'",
      'parents': "center_id = '$centerId'",
      'student_therapy_programs': "center_id = '$centerId'",
      'student_program_assignments': "center_id = '$centerId'",
      'clinical_assessments': "center_id = '$centerId'",
      'clinical_findings': "center_id = '$centerId'",
      'evaluations': "center_id = '$centerId'",
      'training_plans': "center_id = '$centerId'",
      'goal_skill_steps': "center_id = '$centerId'",
      'sessions': "center_id = '$centerId'",
      'session_skill_results':
          "session_id IN (SELECT id FROM sessions WHERE center_id = '$centerId')",
      'exercises': "center_id = '$centerId'",
      'rewards': "center_id = '$centerId'",
      'reports': "center_id = '$centerId'",
      'student_followups': "center_id = '$centerId'",
      'audit_logs': "center_id = '$centerId'",
      'sign_resources': "center_id = '$centerId'",
    };
    for (final entry in tables.entries) {
      final rows = await db.rawQuery(
          'SELECT * FROM "${entry.key}" WHERE ${entry.value}');
      backup[entry.key] = rows;
    }
    return backup;
  }

  /// Writes [backup] (from [exportCenterBackup]) into [targetFile] as JSON.
  Future<void> saveCenterBackupToFile(
      Map<String, dynamic> backup, String targetPath) async {
    final file = File(targetPath);
    await file.writeAsString(jsonEncode(backup));
  }

  /// Reads a center backup JSON file and returns the parsed map.
  Future<Map<String, dynamic>> loadCenterBackupFromFile(
      String sourcePath) async {
    final file = File(sourcePath);
    final content = await file.readAsString();
    return jsonDecode(content) as Map<String, dynamic>;
  }

  /// Imports a previously exported center backup into the current database.
  /// Does NOT import the center itself (assumes it already exists or will be
  /// created separately). Inserts all child records under the same IDs.
  Future<void> importCenterBackup(Map<String, dynamic> backup) async {
    final db = await database;
    final order = [
      'students',
      'parents',
      'student_therapy_programs',
      'student_program_assignments',
      'clinical_assessments',
      'clinical_findings',
      'evaluations',
      'training_plans',
      'goal_skill_steps',
      'sessions',
      'session_skill_results',
      'exercises',
      'rewards',
      'reports',
      'student_followups',
      'audit_logs',
      'sign_resources',
      'users',
    ];
    for (final table in order) {
      final rows = backup[table];
      if (rows is! List) continue;
      for (final row in rows) {
        if (row is! Map) continue;
        try {
          await db.insert(table, row.cast<String, Object?>(),
              conflictAlgorithm: mobile.ConflictAlgorithm.replace);
        } catch (_) {
          // Skip rows that fail (e.g. missing FK references)
        }
      }
    }
  }

  Future<void> importBackup(String sourcePath) async {
    await _database?.close();
    _database = null;
    await File(sourcePath).copy(await databaseFilePath());
    await database;
  }

  Future<void> resetLocalDatabase() async {
    await _database?.close();
    _database = null;
    final file = File(await databaseFilePath());
    if (await file.exists()) await file.delete();
  }

  Future<void> _createSchema(mobile.Database db) async {
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
        program_id TEXT NOT NULL DEFAULT '',
        specialist_id TEXT NOT NULL DEFAULT '',
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
        specialist_id TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(center_id) REFERENCES centers(id),
        FOREIGN KEY(student_id) REFERENCES students(id)
      )
    ''');
    await _createGoalSkillStepsTable(db);
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
        specialist_id TEXT NOT NULL DEFAULT '',
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
    '''    );
    await db.execute('''
      CREATE TABLE session_skill_results (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        goal_skill_step_id TEXT NOT NULL,
        goal_id TEXT NOT NULL,
        step_title TEXT NOT NULL,
        result TEXT NOT NULL DEFAULT 'لم يبدأ',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(session_id) REFERENCES sessions(id)
      )
    ''');
    await _createClinicalAssessmentTables(db);
    await _createTherapyStructureTables(db);
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
        center_id TEXT NOT NULL DEFAULT '',
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
        center_id TEXT NOT NULL DEFAULT '',
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
    '''    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS student_program_assignments (
        id TEXT PRIMARY KEY,
        center_id TEXT NOT NULL,
        student_id TEXT NOT NULL,
        program_id TEXT NOT NULL,
        specialist_id TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'primary',
        status TEXT NOT NULL DEFAULT 'active',
        notes TEXT NOT NULL DEFAULT '',
        assigned_by_user_id TEXT NOT NULL DEFAULT '',
        assigned_at TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL DEFAULT '',
        updated_at TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS student_followups (
        id TEXT PRIMARY KEY,
        center_id TEXT NOT NULL DEFAULT '',
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
      CREATE TABLE IF NOT EXISTS specialist_program_capabilities (
        id TEXT PRIMARY KEY,
        center_id TEXT NOT NULL DEFAULT '',
        specialist_id TEXT NOT NULL,
        program_id TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'active',
        created_by_user_id TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL DEFAULT '',
        updated_at TEXT NOT NULL DEFAULT ''
      )
    ''');
  }

  Future<void> _upgrade(
      mobile.Database db, int oldVersion, int newVersion) async {
    // ignore: avoid_print
    print('[Database] _upgrade: old=$oldVersion new=$newVersion');
    if (oldVersion < 2) {
      await _ensureTable(db, 'sign_resources', '''
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
          updated_at TEXT NOT NULL DEFAULT ''
        )
      ''');
    }
    if (oldVersion < 3) {
      await _migrateToVersion3(db);
    }
    if (oldVersion < 4) {
      await _removeDemoData(db);
    }
    if (oldVersion < 5) {
      await _ensureTable(db, 'audit_logs', '''
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
    }
    if (oldVersion < 6) {
      await _addColumns(db, {
        'sign_resources': {
          'level': "TEXT NOT NULL DEFAULT 'مبتدئ'",
          'is_favorite': 'INTEGER NOT NULL DEFAULT 0',
        },
      });
    }
    if (oldVersion < 7) {
      await _addColumns(db, {
        'sessions': {
          'program_id': "TEXT NOT NULL DEFAULT ''",
          'skill_id': "TEXT NOT NULL DEFAULT ''",
          'activity_results': "TEXT NOT NULL DEFAULT ''",
        },
      });
    }
    if (oldVersion < 8) {
      await _ensureClinicalAssessmentTables(db);
    }
    if (oldVersion < 9) {
      await _ensureGoalSkillStepsTable(db);
    }
    if (oldVersion < 10) {
      await _dropLegacyProgramTables(db);
    }
    if (oldVersion < 11) {
      await _repairStoredArabicText(db);
    }
    if (oldVersion < 12) {
      await _ensureTherapyStructureTables(db);
    }
    if (oldVersion < 13) {
      await _resetAccountsForRoleRebuild(db);
    }
    if (oldVersion < 14) {
      await _ensureTherapyProgramTables(db);
    }
    if (oldVersion < 15) {
      await _addColumns(db, {
        'assessment_item_templates': {
          'response_mode': "TEXT NOT NULL DEFAULT 'singleChoice'",
        },
      });
    }
    if (oldVersion < 16) {
      await _ensureAssessmentDraftTable(db);
    }
    if (oldVersion < 17) {
      await _addColumns(db, {
        'speech_sound_trigger_templates': {
          'skill_steps_json': "TEXT NOT NULL DEFAULT '[]'",
        },
      });
    }
    if (oldVersion < 18) {
      await _addColumns(db, {
        'assessment_drafts': {
          'letter_results_json': "TEXT NOT NULL DEFAULT '{}'",
        },
      });
    }
    if (oldVersion < 19) {
      await _ensureTable(db, 'student_therapy_programs', '''
        CREATE TABLE student_therapy_programs (
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
      await _addColumns(db, {
        'training_plans': {
          'program_id': "TEXT NOT NULL DEFAULT ''",
          'source_type': "TEXT NOT NULL DEFAULT 'standard'",
        },
        'goal_skill_steps': {
          'program_id': "TEXT NOT NULL DEFAULT ''",
          'source_type': "TEXT NOT NULL DEFAULT 'standard'",
        },
        'clinical_findings': {
          'program_id': "TEXT NOT NULL DEFAULT ''",
          'source_type': "TEXT NOT NULL DEFAULT 'standard'",
        },
        'exercises': {
          'program_id': "TEXT NOT NULL DEFAULT ''",
          'plan_id': "TEXT NOT NULL DEFAULT ''",
          'goal_skill_step_id': "TEXT NOT NULL DEFAULT ''",
          'source_type': "TEXT NOT NULL DEFAULT 'standard'",
          'session_date': "TEXT NOT NULL DEFAULT ''",
        },
      });
    }
    if (oldVersion < 20) {
      await _addColumns(db, {
        'student_therapy_programs': {
          'created_at': "TEXT NOT NULL DEFAULT ''",
          'updated_at': "TEXT NOT NULL DEFAULT ''",
        },
      });
    }
    if (oldVersion < 21) {
      await _addColumns(db, {
        'training_plans': {
          'treatment': "TEXT NOT NULL DEFAULT ''",
        },
      });
    }
    if (oldVersion < 22) {
      await _addColumns(db, {
        'exercises': {
          'note_for_parent': "TEXT NOT NULL DEFAULT ''",
          'parent_completed_at': "TEXT NOT NULL DEFAULT ''",
          'specialist_reviewed_at': "TEXT NOT NULL DEFAULT ''",
          'created_from_session_result': "TEXT NOT NULL DEFAULT ''",
        },
      });
    }
    if (oldVersion < 23) {
      await _ensureTable(db, 'student_specialists', '''
        CREATE TABLE student_specialists (
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
    }
    if (oldVersion < 24) {
      await _addColumns(db, {
        'student_specialists': {
          'created_at': "TEXT NOT NULL DEFAULT ''",
          'updated_at': "TEXT NOT NULL DEFAULT ''",
        },
      });
    }
    if (oldVersion < 25) {
      await _addColumns(db, {
        'sessions': {
          'specialist_id': "TEXT NOT NULL DEFAULT ''",
        },
      });
    }
    if (oldVersion < 26) {
      await _ensureTable(db, 'student_followups', '''
        CREATE TABLE student_followups (
          id TEXT PRIMARY KEY,
          center_id TEXT NOT NULL DEFAULT '',
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
    }
    if (oldVersion < 27) {
      await _addColumns(db, {
        'student_followups': {
          'updated_at': "TEXT NOT NULL DEFAULT ''",
        },
      });
    }
    if (oldVersion < 28) {
      await _addColumns(db, {
        'assessment_drafts': {
          'created_at': "TEXT NOT NULL DEFAULT ''",
        },
      });
    }
    if (oldVersion < 29) {
      // ignore: avoid_print
      print('[Database] Running migration v29: adding missing columns');
      final allTables = [
        'clinical_findings', 'goal_skill_steps', 'training_plans', 'exercises',
      ];
      final columnDefs = <String, Map<String, String>>{
        'clinical_findings': {
          'program_id': "TEXT NOT NULL DEFAULT ''",
          'source_type': "TEXT NOT NULL DEFAULT 'standard'",
        },
        'goal_skill_steps': {
          'program_id': "TEXT NOT NULL DEFAULT ''",
          'source_type': "TEXT NOT NULL DEFAULT 'standard'",
        },
        'training_plans': {
          'treatment': "TEXT NOT NULL DEFAULT ''",
          'program_id': "TEXT NOT NULL DEFAULT ''",
          'source_type': "TEXT NOT NULL DEFAULT 'standard'",
        },
        'exercises': {
          'program_id': "TEXT NOT NULL DEFAULT ''",
          'plan_id': "TEXT NOT NULL DEFAULT ''",
          'goal_skill_step_id': "TEXT NOT NULL DEFAULT ''",
          'source_type': "TEXT NOT NULL DEFAULT 'standard'",
          'session_date': "TEXT NOT NULL DEFAULT ''",
          'note_for_parent': "TEXT NOT NULL DEFAULT ''",
          'parent_completed_at': "TEXT NOT NULL DEFAULT ''",
          'specialist_reviewed_at': "TEXT NOT NULL DEFAULT ''",
          'created_from_session_result': "TEXT NOT NULL DEFAULT ''",
        },
      };
      for (final table in allTables) {
        final existing = <String>{};
        try {
          final info = await db.rawQuery('PRAGMA table_info($table)');
          for (final row in info) {
            final name = row['name'] as String?;
            if (name != null) existing.add(name);
          }
        } catch (_) {}
        final defs = columnDefs[table] ?? {};
        for (final col in defs.entries) {
          if (!existing.contains(col.key)) {
            try {
              await db.execute('ALTER TABLE $table ADD COLUMN ${col.key} ${col.value}');
            } catch (e) {
              // Column may already exist or table doesn't exist; skip.
            }
          }
        }
      }
    }
    if (oldVersion < 30) {
      await _addColumns(db, {
        'clinical_findings': {
          'template_id': "TEXT NOT NULL DEFAULT ''",
        },
      });
    }
    if (oldVersion < 32) {
      await _ensureTable(db, 'student_program_assignments', '''
        CREATE TABLE student_program_assignments (
          id TEXT PRIMARY KEY,
          center_id TEXT NOT NULL,
          student_id TEXT NOT NULL,
          program_id TEXT NOT NULL,
          specialist_id TEXT NOT NULL,
          role TEXT NOT NULL DEFAULT 'primary',
          status TEXT NOT NULL DEFAULT 'active',
          notes TEXT NOT NULL DEFAULT '',
          assigned_by_user_id TEXT NOT NULL DEFAULT '',
          assigned_at TEXT NOT NULL DEFAULT '',
          created_at TEXT NOT NULL DEFAULT '',
          updated_at TEXT NOT NULL DEFAULT ''
        )
      ''');
    }
    if (oldVersion < 34) {
      await _ensureTable(db, 'specialist_program_capabilities', '''
        CREATE TABLE specialist_program_capabilities (
          id TEXT PRIMARY KEY,
          center_id TEXT NOT NULL DEFAULT '',
          specialist_id TEXT NOT NULL,
          program_id TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'active',
          created_by_user_id TEXT NOT NULL DEFAULT '',
          created_at TEXT NOT NULL DEFAULT '',
          updated_at TEXT NOT NULL DEFAULT ''
        )
      ''');
    }
    if (oldVersion < 33) {
      await _addColumns(db, {
        'evaluations': {
          'program_id': "TEXT NOT NULL DEFAULT ''",
          'specialist_id': "TEXT NOT NULL DEFAULT ''",
        },
        'clinical_assessments': {
          'program_id': "TEXT NOT NULL DEFAULT ''",
        },
        'training_plans': {
          'specialist_id': "TEXT NOT NULL DEFAULT ''",
        },
        'assessment_drafts': {
          'center_id': "TEXT NOT NULL DEFAULT ''",
        },
        'student_therapy_programs': {
          'center_id': "TEXT NOT NULL DEFAULT ''",
        },
        'student_followups': {
          'center_id': "TEXT NOT NULL DEFAULT ''",
        },
        'exercises': {
          'specialist_id': "TEXT NOT NULL DEFAULT ''",
        },
        'goal_skill_steps': {
          'specialist_id': "TEXT NOT NULL DEFAULT ''",
        },
      });
    }
    if (oldVersion < 34) {
      await _addColumns(db, {
        'clinical_assessments': {
          'specialist_id': "TEXT NOT NULL DEFAULT ''",
        },
      });
    }
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.execute('PRAGMA foreign_keys = OFF');
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
    );
    for (final tableRow in tables) {
      final table = tableRow['name'] as String?;
      if (table == null || table.isEmpty) continue;
      await db.delete(table);
    }
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _resetAccountsForRoleRebuild(mobile.Database db) async {
    await db.delete('users');
    await db.delete('audit_logs');
    await db.update('students', {
      'portal_password': '',
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> clearAccounts() async {
    final db = await database;
    await db.execute('PRAGMA foreign_keys = OFF');
    await db.delete('users');
    await db.delete('audit_logs');
    await db.update('students', {
      'portal_password': '',
      'updated_at': DateTime.now().toIso8601String(),
    });
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _repairStoredArabicText(mobile.Database db) async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
    );
    for (final tableRow in tables) {
      final table = tableRow['name'] as String?;
      if (table == null || table.isEmpty) continue;
      final columnsInfo =
          await db.rawQuery('PRAGMA table_info(${_quote(table)})');
      final textColumns = columnsInfo
          .where((column) => ((column['type'] as String?) ?? '')
              .toUpperCase()
              .contains('TEXT'))
          .map((column) => column['name'] as String?)
          .whereType<String>()
          .toList();
      if (textColumns.isEmpty) continue;

      final selectColumns = [
        'rowid AS _rowid',
        ...textColumns.map(_quote),
      ].join(', ');
      final rows =
          await db.rawQuery('SELECT $selectColumns FROM ${_quote(table)}');
      for (final row in rows) {
        final updates = <String, Object?>{};
        for (final column in textColumns) {
          final value = row[column];
          if (value is! String || value.isEmpty) continue;
          final repaired = _repairMojibake(value);
          if (repaired != value) updates[column] = repaired;
        }
        if (updates.isNotEmpty) {
          await db.update(
            table,
            updates,
            where: 'rowid = ?',
            whereArgs: [row['_rowid']],
          );
        }
      }
    }
  }

  String _quote(String identifier) => '"${identifier.replaceAll('"', '""')}"';

  String _repairMojibake(String value) {
    if (!_looksLikeBrokenArabic(value)) return value;
    final bytes = <int>[];
    for (final unit in value.runes) {
      final byte = _mojibakeByte(unit);
      if (byte == null) return value;
      bytes.add(byte);
    }
    try {
      final repaired = utf8.decode(bytes, allowMalformed: false);
      return repaired.contains('\uFFFD') ? value : repaired;
    } on FormatException {
      return value;
    }
  }

  bool _looksLikeBrokenArabic(String value) {
    return RegExp(
      r'[طظ][\u0080-\u00ff\u0152\u0153\u0160\u0161\u0178\u017d\u017e\u0192\u02c6\u02dc\u2018-\u201e\u2020-\u2022\u2030\u2039\u203a\u20ac]',
    ).hasMatch(value);
  }

  int? _mojibakeByte(int unit) {
    if (unit <= 0x7F) return unit;
    if (unit >= 0xA0 && unit <= 0xBF) return unit;
    if (unit == 0x0637) return 0xD8;
    if (unit == 0x0638) return 0xD9;
    const cp1252 = {
      0x20AC: 0x80,
      0x201A: 0x82,
      0x0192: 0x83,
      0x201E: 0x84,
      0x2026: 0x85,
      0x2020: 0x86,
      0x2021: 0x87,
      0x02C6: 0x88,
      0x2030: 0x89,
      0x0160: 0x8A,
      0x2039: 0x8B,
      0x0152: 0x8C,
      0x017D: 0x8E,
      0x2018: 0x91,
      0x2019: 0x92,
      0x201C: 0x93,
      0x201D: 0x94,
      0x2022: 0x95,
      0x2013: 0x96,
      0x2014: 0x97,
      0x02DC: 0x98,
      0x2122: 0x99,
      0x0161: 0x9A,
      0x203A: 0x9B,
      0x0153: 0x9C,
      0x017E: 0x9E,
      0x0178: 0x9F,
    };
    return cp1252[unit];
  }

  Future<void> _migrateToVersion3(mobile.Database db) async {
    final now = DateTime.now().toIso8601String();
    await _ensureTable(db, 'centers', '''
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
    await _ensureMigrationTables(db);
    await _addColumns(db, {
      'users': {
        'center_id': "TEXT NOT NULL DEFAULT ''",
        'password_hash': "TEXT NOT NULL DEFAULT ''",
        'force_password_change': 'INTEGER NOT NULL DEFAULT 0',
        'is_demo': 'INTEGER NOT NULL DEFAULT 0',
        'is_active': 'INTEGER NOT NULL DEFAULT 1',
        'created_at': "TEXT NOT NULL DEFAULT ''",
        'updated_at': "TEXT NOT NULL DEFAULT ''",
      },
      'students': {
        'center_id': "TEXT NOT NULL DEFAULT ''",
        'program_type': "TEXT NOT NULL DEFAULT 'نطق وتخاطب'",
        'deleted_at': "TEXT NOT NULL DEFAULT ''",
        'created_at': "TEXT NOT NULL DEFAULT ''",
        'updated_at': "TEXT NOT NULL DEFAULT ''",
      },
      'parents': {
        'center_id': "TEXT NOT NULL DEFAULT ''",
        'created_at': "TEXT NOT NULL DEFAULT ''",
        'updated_at': "TEXT NOT NULL DEFAULT ''",
      },
      'sessions': {
        'center_id': "TEXT NOT NULL DEFAULT ''",
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
        'summary': "TEXT NOT NULL DEFAULT ''",
        'created_at': "TEXT NOT NULL DEFAULT ''",
        'updated_at': "TEXT NOT NULL DEFAULT ''",
      },
      'evaluations': {
        'center_id': "TEXT NOT NULL DEFAULT ''",
        'severity': 'INTEGER NOT NULL DEFAULT 1',
        'recommendation': "TEXT NOT NULL DEFAULT ''",
        'updated_at': "TEXT NOT NULL DEFAULT ''",
      },
      'training_plans': {
        'center_id': "TEXT NOT NULL DEFAULT ''",
        'created_at': "TEXT NOT NULL DEFAULT ''",
        'updated_at': "TEXT NOT NULL DEFAULT ''",
      },
      'exercises': {
        'center_id': "TEXT NOT NULL DEFAULT ''",
        'parent_note': "TEXT NOT NULL DEFAULT ''",
        'stars': 'INTEGER NOT NULL DEFAULT 0',
        'created_at': "TEXT NOT NULL DEFAULT ''",
        'updated_at': "TEXT NOT NULL DEFAULT ''",
      },
      'rewards': {
        'center_id': "TEXT NOT NULL DEFAULT ''",
        'created_at': "TEXT NOT NULL DEFAULT ''",
        'updated_at': "TEXT NOT NULL DEFAULT ''",
      },
      'reports': {
        'center_id': "TEXT NOT NULL DEFAULT ''",
        'manager_signature': "TEXT NOT NULL DEFAULT ''",
        'file_path': "TEXT NOT NULL DEFAULT ''",
        'updated_at': "TEXT NOT NULL DEFAULT ''",
      },
      'sign_resources': {
        'center_id': "TEXT NOT NULL DEFAULT ''",
        'level': "TEXT NOT NULL DEFAULT 'مبتدئ'",
        'is_favorite': 'INTEGER NOT NULL DEFAULT 0',
        'created_at': "TEXT NOT NULL DEFAULT ''",
        'updated_at': "TEXT NOT NULL DEFAULT ''",
      },
    });
    final users = await db.query('users');
    for (final user in users) {
      final existingHash = (user['password_hash'] ?? '') as String;
      final legacyPassword = (user['password'] ?? '') as String;
      if (existingHash.isEmpty && legacyPassword.isNotEmpty) {
        await db.update(
          'users',
          {
            'password_hash': AuthService.hashPassword(legacyPassword),
            'password': '',
            'updated_at': now
          },
          where: 'id = ?',
          whereArgs: [user['id']],
        );
      }
    }
    await db.update(
      'students',
      {'portal_password': '', 'updated_at': now},
      where: 'portal_password != ?',
      whereArgs: [''],
    );
  }

  Future<void> _removeDemoData(mobile.Database db) async {
    await db.delete('users', where: 'is_demo = 1');
    await db.delete('centers', where: 'name LIKE ?', whereArgs: ['%تجريبي%']);
  }

  Future<void> _dropLegacyProgramTables(mobile.Database db) async {
    await db.execute('DROP TABLE IF EXISTS program_activities');
    await db.execute('DROP TABLE IF EXISTS program_skills');
    await db.execute('DROP TABLE IF EXISTS program_sections');
    await db.execute('DROP TABLE IF EXISTS therapy_programs');
  }

  Future<void> _ensureMigrationTables(mobile.Database db) async {
    await _ensureTable(db, 'parents', '''
      CREATE TABLE parents (
        id TEXT PRIMARY KEY,
        center_id TEXT NOT NULL DEFAULT '',
        student_id TEXT NOT NULL,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        email TEXT NOT NULL,
        created_at TEXT NOT NULL DEFAULT '',
        updated_at TEXT NOT NULL DEFAULT ''
      )
    ''');
    await _ensureTable(db, 'evaluations', '''
      CREATE TABLE evaluations (
        id TEXT PRIMARY KEY,
        center_id TEXT NOT NULL DEFAULT '',
        student_id TEXT NOT NULL,
        letter TEXT NOT NULL,
        position TEXT NOT NULL,
        error_type TEXT NOT NULL,
        score TEXT NOT NULL,
        severity INTEGER NOT NULL DEFAULT 1,
        recommendation TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL
      )
    ''');
    await _ensureTable(db, 'exercises', '''
      CREATE TABLE exercises (
        id TEXT PRIMARY KEY,
        center_id TEXT NOT NULL DEFAULT '',
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
        created_at TEXT NOT NULL DEFAULT '',
        updated_at TEXT NOT NULL DEFAULT ''
      )
    ''');
    await _ensureTable(db, 'rewards', '''
      CREATE TABLE rewards (
        id TEXT PRIMARY KEY,
        center_id TEXT NOT NULL DEFAULT '',
        student_id TEXT NOT NULL,
        xp INTEGER NOT NULL,
        level INTEGER NOT NULL,
        badges TEXT NOT NULL,
        daily_streak INTEGER NOT NULL,
        created_at TEXT NOT NULL DEFAULT '',
        updated_at TEXT NOT NULL DEFAULT ''
      )
    ''');
    await _ensureTable(db, 'reports', '''
      CREATE TABLE reports (
        id TEXT PRIMARY KEY,
        center_id TEXT NOT NULL DEFAULT '',
        student_id TEXT NOT NULL,
        type TEXT NOT NULL,
        created_at TEXT NOT NULL,
        improvement_rate INTEGER NOT NULL,
        specialist_signature TEXT NOT NULL,
        manager_signature TEXT NOT NULL DEFAULT '',
        file_path TEXT NOT NULL DEFAULT '',
        updated_at TEXT NOT NULL DEFAULT ''
      )
    ''');
  }

  Future<void> _createClinicalAssessmentTables(mobile.Database db) async {
    await db.execute('''
      CREATE TABLE clinical_assessments (
        id TEXT PRIMARY KEY,
        center_id TEXT NOT NULL,
        student_id TEXT NOT NULL,
        specialist_id TEXT NOT NULL DEFAULT '',
        specialist_name TEXT NOT NULL DEFAULT '',
        type TEXT NOT NULL DEFAULT 'speech',
        program_id TEXT NOT NULL DEFAULT '',
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
        template_id TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(assessment_id) REFERENCES clinical_assessments(id),
        FOREIGN KEY(center_id) REFERENCES centers(id),
        FOREIGN KEY(student_id) REFERENCES students(id)
      )
    ''');
  }

  Future<void> _createTherapyStructureTables(mobile.Database db) async {
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
  }

  Future<void> _ensureTherapyStructureTables(mobile.Database db) async {
    await _ensureTable(db, 'therapy_program_templates', '''
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
    await _ensureTable(db, 'assessment_section_templates', '''
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
    await _ensureTable(db, 'assessment_item_templates', '''
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
        updated_at TEXT NOT NULL
      )
    ''');
    await _ensureTable(db, 'assessment_option_templates', '''
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
        updated_at TEXT NOT NULL
      )
    ''');
    await _ensureTable(db, 'skill_step_templates', '''
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
    await _ensureTable(db, 'speech_sound_trigger_templates', '''
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
    await _addColumns(db, {
      'assessment_section_templates': {
        'program_id': "TEXT NOT NULL DEFAULT ''",
      },
      'assessment_item_templates': {
        'response_type': "TEXT NOT NULL DEFAULT 'custom'",
      },
      'speech_sound_trigger_templates': {
        'program_id': "TEXT NOT NULL DEFAULT ''",
        'skill_steps_json': "TEXT NOT NULL DEFAULT '[]'",
      },
    });
  }

  Future<void> _ensureAssessmentDraftTable(mobile.Database db) async {
    await _ensureTable(db, 'assessment_drafts', '''
      CREATE TABLE assessment_drafts (
        student_id TEXT NOT NULL,
        program_id TEXT NOT NULL,
        center_id TEXT NOT NULL DEFAULT '',
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
  }

  Future<void> _ensureTherapyProgramTables(mobile.Database db) async {
    await _ensureTherapyStructureTables(db);
  }

  Future<void> _ensureClinicalAssessmentTables(mobile.Database db) async {
    await _ensureTable(db, 'clinical_assessments', '''
      CREATE TABLE clinical_assessments (
        id TEXT PRIMARY KEY,
        center_id TEXT NOT NULL,
        student_id TEXT NOT NULL,
        specialist_id TEXT NOT NULL DEFAULT '',
        specialist_name TEXT NOT NULL DEFAULT '',
        type TEXT NOT NULL DEFAULT 'speech',
        program_id TEXT NOT NULL DEFAULT '',
        strengths_summary TEXT NOT NULL DEFAULT '',
        weaknesses_summary TEXT NOT NULL DEFAULT '',
        goals_summary TEXT NOT NULL DEFAULT '',
        training_summary TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await _ensureTable(db, 'clinical_findings', '''
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
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createGoalSkillStepsTable(mobile.Database db) async {
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
        specialist_id TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(center_id) REFERENCES centers(id),
        FOREIGN KEY(student_id) REFERENCES students(id),
        FOREIGN KEY(goal_id) REFERENCES training_plans(id)
      )
    ''');
  }

  Future<void> _ensureGoalSkillStepsTable(mobile.Database db) async {
    await _ensureTable(db, 'goal_skill_steps', '''
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
        specialist_id TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _ensureTable(
      mobile.Database db, String table, String createSql) async {
    final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [table]);
    if (rows.isEmpty) await db.execute(createSql);
  }

  Future<void> _addColumns(mobile.Database db,
      Map<String, Map<String, String>> columnsByTable) async {
    for (final entry in columnsByTable.entries) {
      final existing = await db.rawQuery('PRAGMA table_info(${entry.key})');
      final names = existing.map((row) => row['name']).toSet();
      for (final column in entry.value.entries) {
        if (!names.contains(column.key)) {
          await db.execute(
              'ALTER TABLE ${entry.key} ADD COLUMN ${column.key} ${column.value}');
        }
      }
    }
  }

  Future<void> _ensureLatestSchema(mobile.Database db) async {
    final tables = {
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
        'program_type': "TEXT NOT NULL DEFAULT '\u0646\u0637\u0642 \u0648\u062A\u062E\u0627\u0637\u0628'",
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
        'session_type': "TEXT NOT NULL DEFAULT '\u0646\u0637\u0642 \u0648\u062A\u062E\u0627\u0637\u0628'",
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
        'program_id': "TEXT NOT NULL DEFAULT ''",
        'specialist_id': "TEXT NOT NULL DEFAULT ''",
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
        'specialist_id': "TEXT NOT NULL DEFAULT ''",
        'created_at': "TEXT NOT NULL DEFAULT ''",
        'updated_at': "TEXT NOT NULL DEFAULT ''",
      },
      'goal_skill_steps': {
        'id': 'TEXT PRIMARY KEY',
        'center_id': 'TEXT NOT NULL',
        'student_id': 'TEXT NOT NULL',
        'goal_id': 'TEXT NOT NULL',
        'title': 'TEXT NOT NULL',
        'status': "TEXT NOT NULL DEFAULT '\u0644\u0645 \u064A\u0628\u062F\u0623'",
        'sort_order': 'INTEGER NOT NULL DEFAULT 0',
        'notes': "TEXT NOT NULL DEFAULT ''",
        'last_session_id': "TEXT NOT NULL DEFAULT ''",
        'program_id': "TEXT NOT NULL DEFAULT ''",
        'source_type': "TEXT NOT NULL DEFAULT 'standard'",
        'specialist_id': "TEXT NOT NULL DEFAULT ''",
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
        'specialist_id': "TEXT NOT NULL DEFAULT ''",
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
        'program_id': 'TEXT',
        'specialist_id': 'TEXT',
        'created_by_user_id': "TEXT NOT NULL DEFAULT ''",
        'type': 'TEXT NOT NULL',
        'report_title': "TEXT NOT NULL DEFAULT ''",
        'created_at': 'TEXT NOT NULL',
        'improvement_rate': 'INTEGER NOT NULL DEFAULT 0',
        'specialist_signature': "TEXT NOT NULL DEFAULT ''",
        'manager_signature': "TEXT NOT NULL DEFAULT ''",
        'scope': "TEXT NOT NULL DEFAULT ''",
        'date_from': "TEXT NOT NULL DEFAULT ''",
        'date_to': "TEXT NOT NULL DEFAULT ''",
        'report_status': "TEXT NOT NULL DEFAULT 'exported'",
        'data_json': "TEXT NOT NULL DEFAULT ''",
        'file_path': "TEXT NOT NULL DEFAULT ''",
        'updated_at': "TEXT NOT NULL DEFAULT ''",
        'report_category': "TEXT NOT NULL DEFAULT 'general'",
        'previous_report_id': 'TEXT',
        'quarter': 'TEXT',
        'year': 'TEXT',
        'snapshot_json': "TEXT NOT NULL DEFAULT ''",
        'sequence_number': "INTEGER NOT NULL DEFAULT 0",
      },
      'clinical_assessments': {
        'id': 'TEXT PRIMARY KEY',
        'center_id': 'TEXT NOT NULL',
        'student_id': 'TEXT NOT NULL',
        'specialist_id': "TEXT NOT NULL DEFAULT ''",
        'specialist_name': "TEXT NOT NULL DEFAULT ''",
        'type': "TEXT NOT NULL DEFAULT 'speech'",
        'program_id': "TEXT NOT NULL DEFAULT ''",
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
        'template_id': "TEXT NOT NULL DEFAULT ''",
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
        'level': "TEXT NOT NULL DEFAULT '\u0645\u0628\u062A\u062F\u0626'",
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
        'center_id': "TEXT NOT NULL DEFAULT ''",
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
        'center_id': "TEXT NOT NULL DEFAULT ''",
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
      'student_program_assignments': {
        'id': 'TEXT PRIMARY KEY',
        'center_id': 'TEXT NOT NULL',
        'student_id': 'TEXT NOT NULL',
        'program_id': 'TEXT NOT NULL',
        'specialist_id': 'TEXT NOT NULL',
        'role': "TEXT NOT NULL DEFAULT 'primary'",
        'status': "TEXT NOT NULL DEFAULT 'active'",
        'notes': "TEXT NOT NULL DEFAULT ''",
        'assigned_by_user_id': "TEXT NOT NULL DEFAULT ''",
        'assigned_at': "TEXT NOT NULL DEFAULT ''",
        'created_at': "TEXT NOT NULL DEFAULT ''",
        'updated_at': "TEXT NOT NULL DEFAULT ''",
      },
      'student_followups': {
        'id': 'TEXT PRIMARY KEY',
        'center_id': "TEXT NOT NULL DEFAULT ''",
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
        'result': "TEXT NOT NULL DEFAULT 'لم يبدأ'",
        'created_at': 'TEXT NOT NULL',
        'updated_at': 'TEXT NOT NULL',
      },
      'specialist_program_capabilities': {
        'id': 'TEXT PRIMARY KEY',
        'center_id': "TEXT NOT NULL DEFAULT ''",
        'specialist_id': 'TEXT NOT NULL',
        'program_id': 'TEXT NOT NULL',
        'status': "TEXT NOT NULL DEFAULT 'active'",
        'created_by_user_id': "TEXT NOT NULL DEFAULT ''",
        'created_at': "TEXT NOT NULL DEFAULT ''",
        'updated_at': "TEXT NOT NULL DEFAULT ''",
      },
      'demo_time_state': {
        'center_id': 'TEXT PRIMARY KEY',
        'current_date': 'TEXT NOT NULL',
        'initial_date': 'TEXT NOT NULL',
        'last_action': "TEXT NOT NULL DEFAULT ''",
        'created_at': 'TEXT NOT NULL',
        'updated_at': 'TEXT NOT NULL',
      },
    };
    for (final entry in tables.entries) {
      final table = entry.key;
      final columns = entry.value;
      try {
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
              try {
                await db.execute(
                    'ALTER TABLE "$table" ADD COLUMN ${col.key} ${col.value}');
              } catch (_) {}
            }
          }
        }
      } catch (_) {}
    }
  }

  Future<int> count(String table) async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) AS total FROM $table');
    return (result.first['total'] as int?) ?? 0;
  }

  Future<int> countWhere(
      String table, String where, List<Object?> whereArgs) async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) AS total FROM $table WHERE $where', whereArgs);
    return (result.first['total'] as int?) ?? 0;
  }

  Future<List<Map<String, Object?>>> all(String table,
      {String? orderBy}) async {
    final db = await database;
    return db.query(table, orderBy: orderBy);
  }

  Future<List<Map<String, Object?>>> where(
    String table, {
    required String where,
    required List<Object?> whereArgs,
    String? orderBy,
  }) async {
    final db = await database;
    return db.query(table,
        where: where, whereArgs: whereArgs, orderBy: orderBy);
  }

  Future<Map<String, Object?>?> first(
    String table, {
    required String where,
    required List<Object?> whereArgs,
  }) async {
    final rows = await this.where(table, where: where, whereArgs: whereArgs);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> upsert(String table, Map<String, Object?> data) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final normalized = Map<String, Object?>.from(data);
    normalized['updated_at'] = now;
    normalized['created_at'] =
        (normalized['created_at'] as String?)?.isNotEmpty == true
            ? normalized['created_at']
            : now;
    await db.insert(table, normalized,
        conflictAlgorithm: mobile.ConflictAlgorithm.replace);
  }

  Future<void> updateWhere(String table, Map<String, Object?> data,
      String where, List<Object?> whereArgs) async {
    final db = await database;
    final normalized = Map<String, Object?>.from(data)
      ..['updated_at'] = DateTime.now().toIso8601String();
    await db.update(table, normalized, where: where, whereArgs: whereArgs);
  }

  Future<void> delete(String table, String id) async {
    final db = await database;
    await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> ensureTable(String name, String createSql) async {
    final db = await database;
    await _ensureTable(db, name, createSql);
  }

  Future<void> deleteWhere(
      String table, String where, List<Object?> whereArgs) async {
    final db = await database;
    await db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<void> deleteCenter(String centerId) async {
    final db = await database;
    await db.execute('PRAGMA foreign_keys = OFF');
    try {
      // Tables with center_id column – delete all child records first
      await db.delete('users', where: 'center_id = ?', whereArgs: [centerId]);
      await db.delete('parents', where: 'center_id = ?', whereArgs: [centerId]);
      await db.delete('sessions', where: 'center_id = ?', whereArgs: [centerId]);
      await db.delete('evaluations', where: 'center_id = ?', whereArgs: [centerId]);
      await db.delete('training_plans', where: 'center_id = ?', whereArgs: [centerId]);
      await db.delete('goal_skill_steps', where: 'center_id = ?', whereArgs: [centerId]);
      await db.delete('exercises', where: 'center_id = ?', whereArgs: [centerId]);
      await db.delete('rewards', where: 'center_id = ?', whereArgs: [centerId]);
      await db.delete('reports', where: 'center_id = ?', whereArgs: [centerId]);
      await db.delete('clinical_assessments', where: 'center_id = ?', whereArgs: [centerId]);
      await db.delete('clinical_findings', where: 'center_id = ?', whereArgs: [centerId]);
      await db.delete('sign_resources', where: 'center_id = ?', whereArgs: [centerId]);
      await db.delete('therapy_program_templates', where: 'center_id = ?', whereArgs: [centerId]);
      await db.delete('assessment_section_templates', where: 'center_id = ?', whereArgs: [centerId]);
      await db.delete('assessment_item_templates', where: 'center_id = ?', whereArgs: [centerId]);
      await db.delete('assessment_option_templates', where: 'center_id = ?', whereArgs: [centerId]);
      await db.delete('skill_step_templates', where: 'center_id = ?', whereArgs: [centerId]);
      await db.delete('speech_sound_trigger_templates', where: 'center_id = ?', whereArgs: [centerId]);
      await db.delete('audit_logs', where: 'center_id = ?', whereArgs: [centerId]);
      await db.delete('student_program_assignments',
          where: 'center_id = ?', whereArgs: [centerId]);

      // Tables that now have center_id – delete directly
      await db.delete('demo_time_state',
          where: 'center_id = ?', whereArgs: [centerId]);
      await db.delete('student_followups',
          where: 'center_id = ?', whereArgs: [centerId]);
      await db.delete('student_therapy_programs',
          where: 'center_id = ?', whereArgs: [centerId]);
      await db.delete('assessment_drafts',
          where: 'center_id = ?', whereArgs: [centerId]);

      // Students (depends on center)
      await db.delete('students', where: 'center_id = ?', whereArgs: [centerId]);

      // Finally the center itself
      await db.delete('centers', where: 'id = ?', whereArgs: [centerId]);
    } finally {
      await db.execute('PRAGMA foreign_keys = ON');
      }
    }
  }
