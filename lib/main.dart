import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/app_provider.dart';
import 'repositories/sanad_repository.dart';
import 'screens/app_shell.dart';
import 'screens/first_setup_screen.dart';
import 'screens/login_screen.dart';
import 'screens/startup_error_screen.dart';
import 'services/database_service.dart';
import 'services/pdf_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SanadApp());
}

class SanadApp extends StatelessWidget {
  const SanadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          AppProvider(SanadRepository(DatabaseService.instance), PdfService()),
      child: Consumer<AppProvider>(
        builder: (context, app, _) {
          const seed = Color(0xFF19706C);
          final radius = BorderRadius.circular(8);
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Sanad',
            themeMode: app.darkMode ? ThemeMode.dark : ThemeMode.light,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(seedColor: seed),
              scaffoldBackgroundColor: const Color(0xFFF7FAF9),
              visualDensity: VisualDensity.standard,
              inputDecorationTheme: InputDecorationTheme(
                border: OutlineInputBorder(borderRadius: radius),
                filled: true,
                fillColor: Colors.white,
              ),
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(borderRadius: radius),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              chipTheme: ChipThemeData(
                shape: RoundedRectangleBorder(borderRadius: radius),
                side: BorderSide(color: Colors.teal.shade100),
              ),
              dialogTheme: DialogThemeData(
                shape: RoundedRectangleBorder(borderRadius: radius),
              ),
              cardTheme: const CardThemeData(margin: EdgeInsets.zero),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              colorScheme: ColorScheme.fromSeed(
                  seedColor: seed, brightness: Brightness.dark),
              visualDensity: VisualDensity.standard,
              inputDecorationTheme: InputDecorationTheme(
                border: OutlineInputBorder(borderRadius: radius),
                filled: true,
              ),
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(borderRadius: radius),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              chipTheme: ChipThemeData(
                shape: RoundedRectangleBorder(borderRadius: radius),
              ),
              dialogTheme: DialogThemeData(
                shape: RoundedRectangleBorder(borderRadius: radius),
              ),
              cardTheme: const CardThemeData(margin: EdgeInsets.zero),
            ),
            home: _HomeGate(app: app),
          );
        },
      ),
    );
  }
}

class _HomeGate extends StatefulWidget {
  const _HomeGate({required this.app});

  final AppProvider app;

  @override
  State<_HomeGate> createState() => _HomeGateState();
}

class _HomeGateState extends State<_HomeGate> {
  @override
  void initState() {
    super.initState();
    if (!widget.app.initialized) {
      Future.microtask(widget.app.initialize);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    if (!app.initialized) {
      return const Scaffold(
          body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(),
        SizedBox(height: 12),
        Text('جار تجهيز النظام...')
      ])));
    }
    if (app.startupError != null) {
      return StartupErrorScreen(message: app.startupError!);
    }
    if (app.setupRequired) return const FirstSetupScreen();
    return app.user == null ? const LoginScreen() : const AppShell();
  }
}
