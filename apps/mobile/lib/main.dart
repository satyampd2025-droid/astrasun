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
        theme: ThemeData(
          fontFamily: 'NotoSans',
          fontFamilyFallback: const ['NotoSansDevanagari'],
          colorScheme: ColorScheme.fromSeed(
            seedColor: brandGreen,
            primary: brandGreen,
          ),
          scaffoldBackgroundColor: const Color(0xFFF3F4F0),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(60),
              textStyle: const TextStyle(
                fontFamily: 'NotoSans',
                fontFamilyFallback: ['NotoSansDevanagari'],
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        // Larger text everywhere for floor staff.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.15)),
          child: child!,
        ),
        home: state.loggedIn
            ? HomeScreen(state: state)
            : LoginScreen(state: state),
      ),
    );
  }
}
