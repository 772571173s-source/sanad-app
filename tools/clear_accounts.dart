import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sanad_app/services/database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
  }

  final dbService = DatabaseService.instance;
  final db = await dbService.database;

  print('Clearing accounts (users + audit_logs)...');
  await db.delete('users');
  await db.delete('audit_logs');
  await db.update('students', {
    'portal_password': '',
    'updated_at': DateTime.now().toIso8601String(),
  });
  print('Accounts cleared safely. Therapy data preserved.');

  exit(0);
}
