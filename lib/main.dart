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

class SanadPalette {
  static const primary = Color(0xFF0F766E);
  static const secondary = Color(0xFF38BDF8);
  static const background = Color(0xFFF8FAF7);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF1F2937);
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
  static const accentBlue = Color(0xFFE0F2FE);
  static const accentGreen = Color(0xFFDCFCE7);
  static const accentAmber = Color(0xFFFEF3C7);
}

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
          final radius = BorderRadius.circular(8);
          const lightScheme = ColorScheme(
            brightness: Brightness.light,
            primary: SanadPalette.primary,
            onPrimary: Colors.white,
            primaryContainer: SanadPalette.accentGreen,
            onPrimaryContainer: SanadPalette.text,
            secondary: SanadPalette.secondary,
            onSecondary: SanadPalette.text,
            secondaryContainer: SanadPalette.accentBlue,
            onSecondaryContainer: SanadPalette.text,
            tertiary: SanadPalette.warning,
            onTertiary: SanadPalette.text,
            tertiaryContainer: SanadPalette.accentAmber,
            onTertiaryContainer: SanadPalette.text,
            error: SanadPalette.danger,
            onError: Colors.white,
            errorContainer: Color(0xFFFEE2E2),
            onErrorContainer: SanadPalette.text,
            surface: SanadPalette.surface,
            onSurface: SanadPalette.text,
            surfaceContainerHighest: Color(0xFFF1F5F4),
            onSurfaceVariant: Color(0xFF475569),
            outline: Color(0xFFCBD5E1),
            outlineVariant: Color(0xFFE2E8F0),
            shadow: Color(0x1F000000),
            scrim: Color(0x99000000),
            inverseSurface: SanadPalette.text,
            onInverseSurface: Colors.white,
            inversePrimary: Color(0xFF5EEAD4),
          );
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Sanad',
            themeMode: app.darkMode ? ThemeMode.dark : ThemeMode.light,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: lightScheme,
              scaffoldBackgroundColor: SanadPalette.background,
              visualDensity: VisualDensity.standard,
              fontFamily: 'Arial',
              textTheme: ThemeData.light().textTheme.apply(
                    bodyColor: SanadPalette.text,
                    displayColor: SanadPalette.text,
                  ),
              inputDecorationTheme: InputDecorationTheme(
                border: OutlineInputBorder(borderRadius: radius),
                enabledBorder: OutlineInputBorder(
                  borderRadius: radius,
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: radius,
                  borderSide:
                      const BorderSide(color: SanadPalette.primary, width: 1.4),
                ),
                filled: true,
                fillColor: SanadPalette.surface,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(borderRadius: radius),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              chipTheme: ChipThemeData(
                shape: RoundedRectangleBorder(borderRadius: radius),
                backgroundColor: SanadPalette.accentBlue,
                selectedColor: SanadPalette.accentGreen,
                side: const BorderSide(color: Color(0xFFBAE6FD)),
                labelStyle: const TextStyle(
                    color: SanadPalette.text, fontWeight: FontWeight.w800),
              ),
              dialogTheme: DialogThemeData(
                shape: RoundedRectangleBorder(borderRadius: radius),
                backgroundColor: SanadPalette.surface,
              ),
              cardTheme: CardThemeData(
                margin: EdgeInsets.zero,
                color: SanadPalette.surface,
                shadowColor: Colors.black.withValues(alpha: .05),
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              colorScheme: ColorScheme.fromSeed(
                  seedColor: SanadPalette.primary, brightness: Brightness.dark),
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
