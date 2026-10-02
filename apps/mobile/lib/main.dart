import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_state.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

const brandGreen = Color(0xFF1E5B45);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  await state.load();
  runApp(MillApp(state: state));
}

class MillApp extends StatelessWidget {
  const MillApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => MaterialApp(
        title: 'Atulyaa Mill',
        debugShowCheckedModeBanner: false,
        locale: state.locale,
        supportedLocales: const [Locale('hi'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: _theme(),
        // Larger text everywhere for floor staff.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.1)),
          child: child!,
        ),
        home: state.loggedIn
            ? HomeScreen(state: state)
            : LoginScreen(state: state),
      ),
    );
  }
}

const _ink = Color(0xFF1B1F1C);
const _line = Color(0xFFE3E6E1);
const _font = 'NotoSans';
const _fallback = ['NotoSansDevanagari'];

/// Modern and simple: light background, white rounded cards with a thin
/// border, flat app bar, big rounded buttons.
ThemeData _theme() {
  const bg = Color(0xFFF6F7F5);
  final scheme = ColorScheme.fromSeed(
    seedColor: brandGreen,
    primary: brandGreen,
    primaryContainer: const Color(0xFFE3F1EA),
    onPrimaryContainer: brandGreen,
    surface: Colors.white,
    onSurface: _ink,
  );
  final rounded16 = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: _font,
    fontFamilyFallback: _fallback,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: bg,
      foregroundColor: _ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: _font,
        fontFamilyFallback: _fallback,
        color: _ink,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: _line),
      ),
    ),
    listTileTheme: const ListTileThemeData(iconColor: _ink),
    dividerTheme: const DividerThemeData(color: _line, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: rounded16,
        textStyle: const TextStyle(
          fontFamily: _font,
          fontFamilyFallback: _fallback,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: rounded16,
        side: const BorderSide(color: _line),
        backgroundColor: Colors.white,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        side: const BorderSide(color: _line),
        backgroundColor: Colors.white,
        selectedBackgroundColor: scheme.primaryContainer,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: brandGreen, width: 2),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: rounded16,
    ),
  );
}
