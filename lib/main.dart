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
import 'widgets/app_widgets.dart';

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

TextTheme _sanadTextTheme(TextTheme base, Color text, Color muted) {
  TextStyle apply(TextStyle? style, FontWeight weight, double height) {
    return (style ?? const TextStyle()).copyWith(
      color: text,
      fontWeight: weight,
      height: height,
      letterSpacing: 0,
    );
  }

  return base.copyWith(
    displayLarge: apply(base.displayLarge, FontWeight.w900, 1.16),
    displayMedium: apply(base.displayMedium, FontWeight.w900, 1.18),
    displaySmall: apply(base.displaySmall, FontWeight.w900, 1.2),
    headlineLarge: apply(base.headlineLarge, FontWeight.w900, 1.22),
    headlineMedium: apply(base.headlineMedium, FontWeight.w900, 1.24),
    headlineSmall: apply(base.headlineSmall, FontWeight.w900, 1.26),
    titleLarge: apply(base.titleLarge, FontWeight.w900, 1.28),
    titleMedium: apply(base.titleMedium, FontWeight.w800, 1.34),
    titleSmall: apply(base.titleSmall, FontWeight.w800, 1.36),
    bodyLarge: apply(base.bodyLarge, FontWeight.w500, 1.55),
    bodyMedium: apply(base.bodyMedium, FontWeight.w500, 1.5),
    bodySmall: (base.bodySmall ?? const TextStyle()).copyWith(
      color: muted,
      fontWeight: FontWeight.w500,
      height: 1.45,
      letterSpacing: 0,
    ),
    labelLarge: apply(base.labelLarge, FontWeight.w800, 1.25),
    labelMedium: apply(base.labelMedium, FontWeight.w800, 1.25),
    labelSmall: (base.labelSmall ?? const TextStyle()).copyWith(
      color: muted,
      fontWeight: FontWeight.w700,
      height: 1.25,
      letterSpacing: 0,
    ),
  );
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
          final radius = BorderRadius.circular(AppRadii.control);
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
          const darkScheme = ColorScheme(
            brightness: Brightness.dark,
            primary: Color(0xFF5EEAD4),
            onPrimary: Color(0xFF062F2B),
            primaryContainer: Color(0xFF134E4A),
            onPrimaryContainer: Color(0xFFCCFBF1),
            secondary: Color(0xFF7DD3FC),
            onSecondary: Color(0xFF082F49),
            secondaryContainer: Color(0xFF0C4A6E),
            onSecondaryContainer: Color(0xFFE0F2FE),
            tertiary: Color(0xFFFBBF24),
            onTertiary: Color(0xFF451A03),
            tertiaryContainer: Color(0xFF78350F),
            onTertiaryContainer: Color(0xFFFEF3C7),
            error: Color(0xFFFCA5A5),
            onError: Color(0xFF450A0A),
            errorContainer: Color(0xFF7F1D1D),
            onErrorContainer: Color(0xFFFEE2E2),
            surface: Color(0xFF111827),
            onSurface: Color(0xFFF8FAFC),
            surfaceContainerHighest: Color(0xFF1F2937),
            onSurfaceVariant: Color(0xFFCBD5E1),
            outline: Color(0xFF64748B),
            outlineVariant: Color(0xFF334155),
            shadow: Color(0x66000000),
            scrim: Color(0xCC000000),
            inverseSurface: Color(0xFFF8FAFC),
            onInverseSurface: Color(0xFF111827),
            inversePrimary: SanadPalette.primary,
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
              textTheme: _sanadTextTheme(
                ThemeData.light().textTheme,
                SanadPalette.text,
                const Color(0xFF475569),
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
                labelStyle: const TextStyle(
                  color: Color(0xFF475569),
                  fontWeight: FontWeight.w700,
                ),
                hintStyle: const TextStyle(color: Color(0xFF64748B)),
              ),
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(borderRadius: radius),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  textStyle:
                      const TextStyle(fontWeight: FontWeight.w900, height: 1.2),
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(borderRadius: radius),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  textStyle:
                      const TextStyle(fontWeight: FontWeight.w800, height: 1.2),
                ),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  shape: RoundedRectangleBorder(borderRadius: radius),
                  textStyle:
                      const TextStyle(fontWeight: FontWeight.w800, height: 1.2),
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
              snackBarTheme: SnackBarThemeData(
                behavior: SnackBarBehavior.floating,
                backgroundColor: SanadPalette.text,
                contentTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1.4,
                ),
                shape: RoundedRectangleBorder(borderRadius: radius),
              ),
              cardTheme: CardThemeData(
                margin: EdgeInsets.zero,
                color: SanadPalette.surface,
                shadowColor: Colors.black.withValues(alpha: .04),
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: darkScheme,
              scaffoldBackgroundColor: const Color(0xFF0F172A),
              visualDensity: VisualDensity.standard,
              fontFamily: 'Arial',
              textTheme: _sanadTextTheme(
                ThemeData.dark().textTheme,
                const Color(0xFFF8FAFC),
                const Color(0xFFCBD5E1),
              ),
              inputDecorationTheme: InputDecorationTheme(
                border: OutlineInputBorder(borderRadius: radius),
                enabledBorder: OutlineInputBorder(
                  borderRadius: radius,
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: radius,
                  borderSide:
                      const BorderSide(color: Color(0xFF5EEAD4), width: 1.4),
                ),
                filled: true,
                fillColor: const Color(0xFF111827),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                labelStyle: const TextStyle(
                  color: Color(0xFFCBD5E1),
                  fontWeight: FontWeight.w700,
                ),
                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
              ),
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(borderRadius: radius),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  textStyle:
                      const TextStyle(fontWeight: FontWeight.w900, height: 1.2),
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(borderRadius: radius),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  textStyle:
                      const TextStyle(fontWeight: FontWeight.w800, height: 1.2),
                ),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  shape: RoundedRectangleBorder(borderRadius: radius),
                  textStyle:
                      const TextStyle(fontWeight: FontWeight.w800, height: 1.2),
                ),
              ),
              chipTheme: ChipThemeData(
                shape: RoundedRectangleBorder(borderRadius: radius),
                backgroundColor: const Color(0xFF0C4A6E),
                selectedColor: const Color(0xFF134E4A),
                side: const BorderSide(color: Color(0xFF334155)),
                labelStyle: const TextStyle(
                  color: Color(0xFFF8FAFC),
                  fontWeight: FontWeight.w800,
                ),
              ),
              dialogTheme: DialogThemeData(
                shape: RoundedRectangleBorder(borderRadius: radius),
                backgroundColor: const Color(0xFF111827),
              ),
              snackBarTheme: SnackBarThemeData(
                behavior: SnackBarBehavior.floating,
                backgroundColor: const Color(0xFFE2E8F0),
                contentTextStyle: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w800,
                  height: 1.4,
                ),
                shape: RoundedRectangleBorder(borderRadius: radius),
              ),
              cardTheme: CardThemeData(
                margin: EdgeInsets.zero,
                color: const Color(0xFF111827),
                shadowColor: Colors.black.withValues(alpha: .12),
              ),
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
