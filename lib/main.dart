import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/app_provider.dart';
import 'repositories/sanad_repository.dart';
import 'screens/app_shell.dart';
import 'screens/first_setup_screen.dart';
import 'screens/login_screen.dart';
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
      create: (_) => AppProvider(SanadRepository(DatabaseService.instance), PdfService()),
      child: Consumer<AppProvider>(
        builder: (context, app, _) {
          final seed = const Color(0xFF19706C);
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Sanad',
            themeMode: app.darkMode ? ThemeMode.dark : ThemeMode.light,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(seedColor: seed),
              inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
              cardTheme: const CardThemeData(margin: EdgeInsets.zero),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
              inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (app.setupRequired) return const FirstSetupScreen();
    return app.user == null ? const LoginScreen() : const AppShell();
  }
}
