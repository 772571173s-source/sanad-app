import 'dart:convert';

import 'package:sqflite/sqflite.dart' as mobile;

import '../models/center_report_settings.dart';
import 'database_service.dart';

class CenterReportSettingsService {
  final DatabaseService _db;

  CenterReportSettingsService(this._db);

  Future<CenterReportSettings> getForCenter(String centerId) async {
    final db = await _db.database;
    final rows = await db.query(
      'center_report_settings',
      where: 'center_id = ?',
      whereArgs: [centerId],
      limit: 1,
    );
    if (rows.isEmpty) return CenterReportSettings.defaults(centerId);
    return CenterReportSettings.fromMap(rows.first);
  }

  Future<void> save(CenterReportSettings settings) async {
    final db = await _db.database;
    await db.insert(
      'center_report_settings',
      settings.toMap(),
      conflictAlgorithm: mobile.ConflictAlgorithm.replace,
    );
  }

  Future<void> clearLogo(String centerId) async {
    final now = DateTime.now().toIso8601String();
    final existing = await _db.first('center_report_settings',
        where: 'center_id = ?', whereArgs: [centerId]);
    if (existing != null) {
      final db = await _db.database;
      await db.update(
        'center_report_settings',
        {
          'logo_base64': null,
          'logo_file_name': null,
          'updated_at': now,
        },
        where: 'center_id = ?',
        whereArgs: [centerId],
      );
    }
  }

  Future<void> updateLogo(
    String centerId,
    List<int> bytes,
    String fileName,
  ) async {
    final base64 = base64Encode(bytes);
    final now = DateTime.now().toIso8601String();
    final existing = await _db.first('center_report_settings',
        where: 'center_id = ?', whereArgs: [centerId]);
    final db = await _db.database;
    if (existing != null) {
      await db.update(
        'center_report_settings',
        {
          'logo_base64': base64,
          'logo_file_name': fileName,
          'updated_at': now,
        },
        where: 'center_id = ?',
        whereArgs: [centerId],
      );
    } else {
      await db.insert(
        'center_report_settings',
        {
          'center_id': centerId,
          'logo_base64': base64,
          'logo_file_name': fileName,
          'arabic_header_text': '',
          'english_header_text': '',
          'default_report_title': '',
          'default_technical_supervisor_name': '',
          'footer_notes': '',
          'reports_to_fund': 0,
          'fund_name': '',
          'show_fund_card_number': 0,
          'show_referral_date': 0,
          'show_referral_source': 0,
          'updated_at': now,
        },
        conflictAlgorithm: mobile.ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> delete(String centerId) async {
    final db = await _db.database;
    await db.delete(
      'center_report_settings',
      where: 'center_id = ?',
      whereArgs: [centerId],
    );
  }
}
