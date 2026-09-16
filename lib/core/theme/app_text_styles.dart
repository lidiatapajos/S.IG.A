import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  static const TextStyle title = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    color: AppColors.textSecondary,
  );

  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static const siga = TextStyle(
    color: AppColors.blue,
    fontSize: 48,
    fontWeight: FontWeight.w900,
    letterSpacing: 2,
  );

  static const subtitleBlue = TextStyle(
    color: AppColors.blue,
    fontSize: 16,
    fontWeight: FontWeight.bold,
    height: 1.1,
  );

  static const belem = TextStyle(
    color: AppColors.blue,
    fontSize: 46,
    fontWeight: FontWeight.w900,
  );

  static const slogan = TextStyle(
    color: AppColors.blue,
    fontSize: 25,
    fontWeight: FontWeight.w600,
    height: 1.15,
  );

  static const buttonBlue = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: AppColors.blue,
  );
}
