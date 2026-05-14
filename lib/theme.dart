import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  static const EdgeInsets paddingXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);

  static const EdgeInsets horizontalXs = EdgeInsets.symmetric(horizontal: xs);
  static const EdgeInsets horizontalSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets horizontalMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets horizontalLg = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets horizontalXl = EdgeInsets.symmetric(horizontal: xl);

  static const EdgeInsets verticalXs = EdgeInsets.symmetric(vertical: xs);
  static const EdgeInsets verticalSm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets verticalMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets verticalLg = EdgeInsets.symmetric(vertical: lg);
  static const EdgeInsets verticalXl = EdgeInsets.symmetric(vertical: xl);
}

class AppRadius {
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

extension TextStyleContext on BuildContext {
  TextTheme get textStyles => Theme.of(this).textTheme;
}

extension TextStyleExtensions on TextStyle {
  TextStyle get bold => copyWith(fontWeight: FontWeight.bold);
  TextStyle get semiBold => copyWith(fontWeight: FontWeight.w600);
  TextStyle get medium => copyWith(fontWeight: FontWeight.w500);
  TextStyle get normal => copyWith(fontWeight: FontWeight.w400);
  TextStyle get light => copyWith(fontWeight: FontWeight.w300);
  TextStyle withColor(Color color) => copyWith(color: color);
  TextStyle withSize(double size) => copyWith(fontSize: size);
}

// Farm-themed vibrant color palette
class AppColors {
  // Primary: Earthy green for agriculture
  static const Color primaryGreen = Color(0xFF2E7D32);
  static const Color primaryGreenLight = Color(0xFF60AD5E);
  static const Color primaryGreenDark = Color(0xFF005005);

  // Secondary: Warm brown/orange for livestock
  static const Color secondaryOrange = Color(0xFFE65100);
  static const Color secondaryOrangeLight = Color(0xFFFF833A);
  static const Color secondaryOrangeDark = Color(0xFFAC1900);

  // Accent colors
  // Rotina (yellow theme) - tuned for stronger contrast on light surfaces
  // Suggested range: #E5A900 / #D99A00 / #C98500
  static const Color accentYellow = Color(0xFFD99A00);
  static const Color accentYellowDeep = Color(0xFFC98500);
  static const Color accentYellowTint = Color(0xFFFFF3CC);
  static const Color accentBlue = Color(0xFF1976D2);

  // Semantic colors
  static const Color success = Color(0xFF4CAF50);
  static const Color successLight = Color(0xFFE8F5E9);
  static const Color warning = Color(0xFFFF9800);
  static const Color warningLight = Color(0xFFFFF3E0);
  static const Color error = Color(0xFFE53935);
  static const Color errorLight = Color(0xFFFFEBEE);
  static const Color info = Color(0xFF2196F3);
  static const Color infoLight = Color(0xFFE3F2FD);

  // Neutral colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF5F7F0);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF0F4E8);
  static const Color textPrimary = Color(0xFF1B1B1B);
  static const Color textSecondary = Color(0xFF5F5F5F);
  static const Color textLight = Color(0xFF9E9E9E);
  static const Color divider = Color(0xFFE0E0E0);

  // Dark mode colors
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkSurfaceVariant = Color(0xFF2C2C2C);
  static const Color darkTextPrimary = Color(0xFFF5F5F5);
  static const Color darkTextSecondary = Color(0xFFB0B0B0);

  /// Returns a readable foreground color (black/white) for the given background.
  /// Useful when the background color varies by checklist area (e.g., Rotina).
  static Color onColorFor(Color background) {
    final luminance = background.computeLuminance();
    // Threshold tuned so warm yellows pick dark text.
    return luminance > 0.55 ? textPrimary : white;
  }

  /// For very bright base colors (like yellow), returns a darker variant suitable
  /// for text/icons on light surfaces.
  static Color emphasisColor(Color base) {
    if (base.computeLuminance() <= 0.6) return base;
    final hsl = HSLColor.fromColor(base);
    final darker = hsl.withLightness((hsl.lightness - 0.22).clamp(0.0, 1.0));
    return darker.toColor();
  }
}

// Button sizes for accessibility
class AppButtonSizes {
  static const double largeHeight = 80.0;
  static const double mediumHeight = 64.0;
  static const double smallHeight = 48.0;
  static const double iconSizeLarge = 40.0;
  static const double iconSizeMedium = 32.0;
  static const double iconSizeSmall = 24.0;
}

class FontSizes {
  static const double displayLarge = 48.0;
  static const double displayMedium = 40.0;
  static const double displaySmall = 32.0;
  static const double headlineLarge = 28.0;
  static const double headlineMedium = 24.0;
  static const double headlineSmall = 20.0;
  static const double titleLarge = 22.0;
  static const double titleMedium = 18.0;
  static const double titleSmall = 16.0;
  static const double labelLarge = 16.0;
  static const double labelMedium = 14.0;
  static const double labelSmall = 12.0;
  static const double bodyLarge = 18.0;
  static const double bodyMedium = 16.0;
  static const double bodySmall = 14.0;
}

ThemeData get lightTheme => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.light(
    primary: AppColors.primaryGreen,
    onPrimary: AppColors.white,
    primaryContainer: AppColors.primaryGreenLight,
    onPrimaryContainer: AppColors.primaryGreenDark,
    secondary: AppColors.secondaryOrange,
    onSecondary: AppColors.white,
    secondaryContainer: AppColors.secondaryOrangeLight,
    onSecondaryContainer: AppColors.secondaryOrangeDark,
    tertiary: AppColors.accentBlue,
    onTertiary: AppColors.white,
    error: AppColors.error,
    onError: AppColors.white,
    errorContainer: AppColors.errorLight,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    surfaceContainerHighest: AppColors.surfaceVariant,
    onSurfaceVariant: AppColors.textSecondary,
    outline: AppColors.divider,
  ),
  brightness: Brightness.light,
  scaffoldBackgroundColor: AppColors.background,
  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.primaryGreen,
    foregroundColor: AppColors.white,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: true,
    titleTextStyle: GoogleFonts.nunito(
      fontSize: FontSizes.titleLarge,
      fontWeight: FontWeight.w700,
      color: AppColors.white,
    ),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      side: BorderSide(color: AppColors.divider.withValues(alpha: 0.5)),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      minimumSize: const Size(double.infinity, AppButtonSizes.largeHeight),
      backgroundColor: AppColors.primaryGreen,
      foregroundColor: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      textStyle: GoogleFonts.nunito(
        fontSize: FontSizes.titleMedium,
        fontWeight: FontWeight.w700,
      ),
    ),
  ),
  textTheme: _buildTextTheme(),
);

ThemeData get darkTheme => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.dark(
    primary: AppColors.primaryGreenLight,
    onPrimary: AppColors.primaryGreenDark,
    primaryContainer: AppColors.primaryGreen,
    onPrimaryContainer: AppColors.white,
    secondary: AppColors.secondaryOrangeLight,
    onSecondary: AppColors.secondaryOrangeDark,
    secondaryContainer: AppColors.secondaryOrange,
    onSecondaryContainer: AppColors.white,
    tertiary: AppColors.accentBlue,
    onTertiary: AppColors.white,
    error: AppColors.error,
    onError: AppColors.white,
    errorContainer: AppColors.errorLight,
    surface: AppColors.darkSurface,
    onSurface: AppColors.darkTextPrimary,
    surfaceContainerHighest: AppColors.darkSurfaceVariant,
    onSurfaceVariant: AppColors.darkTextSecondary,
    outline: AppColors.darkSurfaceVariant,
  ),
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.darkBackground,
  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.primaryGreen,
    foregroundColor: AppColors.white,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: true,
    titleTextStyle: GoogleFonts.nunito(
      fontSize: FontSizes.titleLarge,
      fontWeight: FontWeight.w700,
      color: AppColors.white,
    ),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: AppColors.darkSurface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      side: BorderSide(color: AppColors.darkSurfaceVariant),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      minimumSize: const Size(double.infinity, AppButtonSizes.largeHeight),
      backgroundColor: AppColors.primaryGreenLight,
      foregroundColor: AppColors.darkBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      textStyle: GoogleFonts.nunito(
        fontSize: FontSizes.titleMedium,
        fontWeight: FontWeight.w700,
      ),
    ),
  ),
  textTheme: _buildTextTheme(),
);

TextTheme _buildTextTheme() => TextTheme(
  displayLarge: GoogleFonts.nunito(
    fontSize: FontSizes.displayLarge,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
  ),
  displayMedium: GoogleFonts.nunito(
    fontSize: FontSizes.displayMedium,
    fontWeight: FontWeight.w700,
  ),
  displaySmall: GoogleFonts.nunito(
    fontSize: FontSizes.displaySmall,
    fontWeight: FontWeight.w700,
  ),
  headlineLarge: GoogleFonts.nunito(
    fontSize: FontSizes.headlineLarge,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.25,
  ),
  headlineMedium: GoogleFonts.nunito(
    fontSize: FontSizes.headlineMedium,
    fontWeight: FontWeight.w700,
  ),
  headlineSmall: GoogleFonts.nunito(
    fontSize: FontSizes.headlineSmall,
    fontWeight: FontWeight.w700,
  ),
  titleLarge: GoogleFonts.nunito(
    fontSize: FontSizes.titleLarge,
    fontWeight: FontWeight.w600,
  ),
  titleMedium: GoogleFonts.nunito(
    fontSize: FontSizes.titleMedium,
    fontWeight: FontWeight.w600,
  ),
  titleSmall: GoogleFonts.nunito(
    fontSize: FontSizes.titleSmall,
    fontWeight: FontWeight.w600,
  ),
  labelLarge: GoogleFonts.nunito(
    fontSize: FontSizes.labelLarge,
    fontWeight: FontWeight.w600,
  ),
  labelMedium: GoogleFonts.nunito(
    fontSize: FontSizes.labelMedium,
    fontWeight: FontWeight.w500,
  ),
  labelSmall: GoogleFonts.nunito(
    fontSize: FontSizes.labelSmall,
    fontWeight: FontWeight.w500,
  ),
  bodyLarge: GoogleFonts.nunito(
    fontSize: FontSizes.bodyLarge,
    fontWeight: FontWeight.w400,
    height: 1.5,
  ),
  bodyMedium: GoogleFonts.nunito(
    fontSize: FontSizes.bodyMedium,
    fontWeight: FontWeight.w400,
    height: 1.5,
  ),
  bodySmall: GoogleFonts.nunito(
    fontSize: FontSizes.bodySmall,
    fontWeight: FontWeight.w400,
    height: 1.4,
  ),
);
