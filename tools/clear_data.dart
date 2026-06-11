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
  print('Clearing all data...');
  await dbService.clearAllData();
  print('All data cleared successfully!');

  exit(0);
}
