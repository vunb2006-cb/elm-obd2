import 'package:flutter/material.dart';

/// Dark automotive aesthetic theme.
class AppTheme {
  AppTheme._();

  static const Color _bg = Color(0xFF0D0D0F);
  static const Color _surface = Color(0xFF1A1A1F);
  static const Color _surfaceVariant = Color(0xFF242428);
  static const Color _accent = Color(0xFFE8B84B); // amber / warning light feel
  static const Color _accentGreen = Color(0xFF4CAF82);
  static const Color _accentRed = Color(0xFFCF4747);
  static const Color _onBg = Color(0xFFE8E8EC);
  static const Color _onSurface = Color(0xFFD0D0D8);
  static const Color _muted = Color(0xFF6B6B78);

  static const Color accent = _accent;
  static const Color accentGreen = _accentGreen;
  static const Color accentRed = _accentRed;
  static const Color muted = _muted;
  static const Color surface = _surface;
  static const Color surfaceVariant = _surfaceVariant;

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _bg,
        colorScheme: const ColorScheme.dark(
          primary: _accent,
          secondary: _accentGreen,
          error: _accentRed,
          surface: _surface,
          onPrimary: Colors.black,
          onSecondary: Colors.black,
          onSurface: _onSurface,
          onError: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _surface,
          foregroundColor: _onBg,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: _onBg,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        cardTheme:CardThemeData(
           
          color: _surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF2A2A30), width: 1),
          
        )
          
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _accent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              letterSpacing: 0.5,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _accent,
            side: const BorderSide(color: _accent),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
        listTileTheme: const ListTileThemeData(
          tileColor: _surface,
          iconColor: _accent,
          textColor: _onSurface,
        ),
        dividerColor: Color(0xFF2A2A30),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _surfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _accent),
          ),
          labelStyle: const TextStyle(color: _muted),
          hintStyle: const TextStyle(color: _muted),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(color: _onBg, fontWeight: FontWeight.w700),
          headlineMedium: TextStyle(color: _onBg, fontWeight: FontWeight.w600),
          titleLarge: TextStyle(color: _onBg, fontWeight: FontWeight.w600),
          titleMedium: TextStyle(color: _onSurface, fontWeight: FontWeight.w500),
          bodyLarge: TextStyle(color: _onSurface),
          bodyMedium: TextStyle(color: _onSurface),
          bodySmall: TextStyle(color: _muted),
          labelLarge: TextStyle(color: _accent, fontWeight: FontWeight.w600),
        ),
      );
}
