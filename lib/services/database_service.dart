import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart' as mobile;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import 'auth_service.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();
  static const currentVersion = 9;

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
        target_date TEXT NOT NULL,
        progress INTEGER NOT NULL,
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
        parent_note TEXT NOT NULL DEFAULT '',
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
    await _createClinicalAssessmentTables(db);
    await db.execute('''
      CREATE TABLE therapy_programs (
        id TEXT PRIMARY KEY,
        center_id TEXT NOT NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(center_id) REFERENCES centers(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE program_sections (
        id TEXT PRIMARY KEY,
        center_id TEXT NOT NULL,
        program_id TEXT NOT NULL,
        title TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(center_id) REFERENCES centers(id),
        FOREIGN KEY(program_id) REFERENCES therapy_programs(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE program_skills (
        id TEXT PRIMARY KEY,
        center_id TEXT NOT NULL,
        program_id TEXT NOT NULL,
        section_id TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(center_id) REFERENCES centers(id),
        FOREIGN KEY(program_id) REFERENCES therapy_programs(id),
        FOREIGN KEY(section_id) REFERENCES program_sections(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE program_activities (
        id TEXT PRIMARY KEY,
        center_id TEXT NOT NULL,
        program_id TEXT NOT NULL,
        skill_id TEXT NOT NULL,
        title TEXT NOT NULL,
        instructions TEXT NOT NULL DEFAULT '',
        homework TEXT NOT NULL DEFAULT '',
        evaluation_type TEXT NOT NULL DEFAULT 'speech',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(center_id) REFERENCES centers(id),
        FOREIGN KEY(program_id) REFERENCES therapy_programs(id),
        FOREIGN KEY(skill_id) REFERENCES program_skills(id)
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
  }

  Future<void> _upgrade(
      mobile.Database db, int oldVersion, int newVersion) async {
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
      await _ensureProgramTables(db);
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

  Future<void> _ensureMigrationTables(mobile.Database db) async {
    await _ensureProgramTables(db);
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
        parent_note TEXT NOT NULL DEFAULT '',
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

  Future<void> _ensureProgramTables(mobile.Database db) async {
    await _ensureTable(db, 'therapy_programs', '''
      CREATE TABLE therapy_programs (
        id TEXT PRIMARY KEY,
        center_id TEXT NOT NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await _ensureTable(db, 'program_sections', '''
      CREATE TABLE program_sections (
        id TEXT PRIMARY KEY,
        center_id TEXT NOT NULL,
        program_id TEXT NOT NULL,
        title TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await _ensureTable(db, 'program_skills', '''
      CREATE TABLE program_skills (
        id TEXT PRIMARY KEY,
        center_id TEXT NOT NULL,
        program_id TEXT NOT NULL,
        section_id TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await _ensureTable(db, 'program_activities', '''
      CREATE TABLE program_activities (
        id TEXT PRIMARY KEY,
        center_id TEXT NOT NULL,
        program_id TEXT NOT NULL,
        skill_id TEXT NOT NULL,
        title TEXT NOT NULL,
        instructions TEXT NOT NULL DEFAULT '',
        homework TEXT NOT NULL DEFAULT '',
        evaluation_type TEXT NOT NULL DEFAULT 'speech',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
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
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(assessment_id) REFERENCES clinical_assessments(id),
        FOREIGN KEY(center_id) REFERENCES centers(id),
        FOREIGN KEY(student_id) REFERENCES students(id)
      )
    ''');
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

  Future<void> deleteWhere(
      String table, String where, List<Object?> whereArgs) async {
    final db = await database;
    await db.delete(table, where: where, whereArgs: whereArgs);
  }
}
