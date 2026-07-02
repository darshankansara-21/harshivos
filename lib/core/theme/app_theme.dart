import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Material 3 theme tuned for a soft, premium, low-stimulation feel.
class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.blobViolet,
      brightness: Brightness.dark,
    ).copyWith(
      surface: AppColors.bgMid,
      onSurface: AppColors.textPrimary,
    );

    return _common(base, Brightness.dark);
  }

  static ThemeData light() {
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.blobViolet,
      brightness: Brightness.light,
    );
    return _common(base, Brightness.light);
  }

  static ThemeData _common(ColorScheme scheme, Brightness brightness) {
    final textTheme = GoogleFonts.nunitoTextTheme(
      brightness == Brightness.dark
          ? ThemeData.dark().textTheme
          : ThemeData.light().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }
}
