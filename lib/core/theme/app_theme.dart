import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get theme {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.blue,
      primary: AppColors.blue,
      secondary: AppColors.greenDark,
      surface: AppColors.surface,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        scrolledUnderElevation: 0,
        centerTitle: false,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 19, fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.blue, width: 1.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.blue,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 52),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.blue,
          side: const BorderSide(color: AppColors.blue),
          minimumSize: const Size(0, 52),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
      chipTheme: ChipThemeData(
        side: const BorderSide(color: AppColors.border),
        backgroundColor: Colors.white,
        selectedColor: AppColors.lightBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        labelStyle: const TextStyle(color: AppColors.textPrimary),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
