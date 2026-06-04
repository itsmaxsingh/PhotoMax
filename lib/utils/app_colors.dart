import 'package:flutter/material.dart';

/// App-wide color constants matching the PhotoMax design spec
class AppColors {
  // Prevent instantiation
  AppColors._();

  // Background Colors
  static const Color background = Color(0xFFFFFFFF); // True white
  static const Color surfaceGray = Color(0xFFF5F5F5); // Light gray for cards

  // Text Colors
  static const Color textPrimary = Color(0xFF000000); // Deep black
  static const Color textSecondary = Color(0xFF757575); // Muted gray
  static const Color textMuted = Color(0xFF9E9E9E); // Lighter gray

  // Accent Colors
  static const Color accentBlue =
      Color(0xFF2196F3); // Blue for links/active states
  static const Color iconGray = Color(0xFF616161); // Icon color

  // Navigation Colors
  static const Color navBackground = Color(0xFFF5F5F5); // Pill background
  static const Color navActive = Color(0xFF000000); // Active tab
  static const Color navInactive = Color(0xFF9E9E9E); // Inactive tab
}
