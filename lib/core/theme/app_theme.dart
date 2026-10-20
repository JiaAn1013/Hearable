import 'package:flutter/material.dart';

/// HearAble colour palette: blue, white and dark navy.
class AppColors {
  static const navy = Color(0xFF0B1F3A);
  static const blue = Color(0xFF1E6FD9);
  static const lightBlue = Color(0xFFE8F1FC);
  static const border = Color(0xFFB8C7DB);
  static const textMuted = Color(0xFF3F4A5A);
  static const danger = Color(0xFFC62828);
  static const success = Color(0xFF2E7D32);
}

/// Large, high-contrast styles for quick, easy interaction.
class AppTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.blue,
      primary: AppColors.blue,
      secondary: AppColors.navy,
      error: AppColors.danger,
      surface: Colors.white,
      brightness: Brightness.light,
    );

    final roundedShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.white,

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),

      textTheme: const TextTheme(
        headlineLarge: TextStyle(
            fontSize: 34, fontWeight: FontWeight.w800, color: AppColors.navy),
        headlineMedium: TextStyle(
            fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.navy),
        titleLarge: TextStyle(
            fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.navy),
        bodyLarge: TextStyle(
            fontSize: 18, color: AppColors.navy, height: 1.4),
        bodyMedium: TextStyle(
            fontSize: 16, color: AppColors.textMuted, height: 1.4),
      ),

      // Big primary buttons (at least 60 px tall)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.blue,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(60),
          shape: roundedShape,
          textStyle:
              const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),

      // Big secondary buttons
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navy,
          minimumSize: const Size.fromHeight(60),
          side: const BorderSide(color: AppColors.navy, width: 2),
          shape: roundedShape,
          textStyle:
              const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),

      // Text links (still a 48 px minimum touch target)
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.blue,
          minimumSize: const Size(48, 48),
          textStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      // Form input boxes
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightBlue,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        labelStyle: const TextStyle(fontSize: 16, color: AppColors.textMuted),
        errorStyle: const TextStyle(fontSize: 14, color: AppColors.danger),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.blue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger, width: 2),
        ),
      ),
    );
  }
}