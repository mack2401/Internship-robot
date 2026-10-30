import 'package:flutter/material.dart';

class AppColors {
  // Stitch Exact Canvas & Surface Palette (Slate-50 & Pure White)
  static const Color background = Color(0xFFF8FAFC); // slate-50
  static const Color surface = Color(0xFFFFFFFF);    // pure white
  static const Color surfaceDim = Color(0xFFF1F5F9); // slate-100
  static const Color surfaceBright = Color(0xFFFFFFFF);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF8FAFC);
  static const Color surfaceContainer = Color(0xFFFFFFFF);
  static const Color surfaceContainerHigh = Color(0xFFF1F5F9);
  static const Color surfaceContainerHighest = Color(0xFFE2E8F0);

  // Stitch Sky Blue Primary
  static const Color primary = Color(0xFF0284C7);       // sky-600
  static const Color primaryLight = Color(0xFF0EA5E9);  // sky-500
  static const Color primaryGradientStart = Color(0xFF0EA5E9);
  static const Color primaryGradientEnd = Color(0xFF0284C7);
  static const Color primaryTint = Color(0xFF38BDF8);   // sky-400
  static const Color primaryContainer = Color(0xFFE0F2FE); // sky-100
  static const Color primaryContainerLow = Color(0xFFF0F9FF); // sky-50
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Neutral Slate Typography Tokens
  static const Color onSurface = Color(0xFF0F172A);        // slate-900
  static const Color onSurfaceVariant = Color(0xFF64748B); // slate-500
  static const Color outline = Color(0xFFE2E8F0);          // slate-200
  static const Color outlineVariant = Color(0xFFF1F5F9);   // slate-100
  static const Color subtleText = Color(0xFF94A3B8);       // slate-400

  // Signal & Status Accents
  static const Color success = Color(0xFF059669);          // emerald-600
  static const Color successLight = Color(0xFF10B981);     // emerald-500
  static const Color successContainer = Color(0xFFECFDF5); // emerald-50
  static const Color successBorder = Color(0xFFA7F3D0);    // emerald-200

  static const Color danger = Color(0xFFDC2626);           // red-600
  static const Color dangerLight = Color(0xFFEF4444);      // red-500
  static const Color dangerContainer = Color(0xFFFEF2F2);  // red-50
  static const Color dangerBorder = Color(0xFFFECACA);     // red-200

  static const Color warning = Color(0xFFD97706);          // amber-600
  static const Color warningLight = Color(0xFFF59E0B);     // amber-500
  static const Color warningContainer = Color(0xFFFFFBEB); // amber-50
  static const Color warningBorder = Color(0xFFFDE68A);    // amber-200

  static const Color purple = Color(0xFF9333EA);           // purple-600
  static const Color purpleContainer = Color(0xFFFAF5FF);  // purple-50
  static const Color pink = Color(0xFFDB2777);             // pink-600
  static const Color pinkContainer = Color(0xFFFDF2F8);    // pink-50

  // Card Borders & Box Shadows
  static const Color cardBorder = Color(0xFFF1F5F9);
  static const Color cardShadow = Color(0x0D0F172A); // 0 4px 20px -2px rgba(15, 23, 42, 0.05)
  static const Color hudCyanBorder = Color(0xFFBAE6FD); // sky-200 border
}
