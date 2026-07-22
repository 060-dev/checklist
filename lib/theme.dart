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

// Morro do Peão brand palette (based on the logo)
class AppColors {
  static const Color brandRed = Color(0xFF8B0000);
  static const Color brandRedDeep = Color(0xFF5C0000);
  static const Color brandCream = Color(0xFFFFF7F2);
  static const Color brandPaper = Color(0xFFFFFFFF);
  static const Color brandInk = Color(0xFF1B1B1B);
  static const Color brandMuted = Color(0xFF5F5F5F);
  static const Color brandBorder = Color(0xFFE9DED8);
  static const Color brandRoseTint = Color(0xFFFFE9E9);

  // Backward-compatible aliases (old prototype screens/components still compile).
  // These can be removed when the legacy screens are deleted.
  static const Color primaryGreen = brandRed;
  static const Color primaryGreenLight = Color(0xFFB31212);
  static const Color primaryGreenDark = brandRedDeep;
  static const Color secondaryOrange = brandRedDeep;
  static const Color secondaryOrangeLight = Color(0xFFB31212);
  static const Color secondaryOrangeDark = brandRedDeep;
  static const Color accentBlue = Color(0xFF1C3D5A);
  static const Color accentYellow = Color(0xFFD99A00);
  static const Color accentYellowDeep = Color(0xFFC98500);
  static const Color accentYellowTint = Color(0xFFFFF3CC);

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
  static const Color background = brandCream;
  static const Color surface = brandPaper;
  static const Color surfaceVariant = brandRoseTint;
  static const Color textPrimary = brandInk;
  static const Color textSecondary = brandMuted;
  static const Color textLight = Color(0xFF9E9E9E);
  static const Color divider = brandBorder;

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
    primary: AppColors.brandRed,
    onPrimary: AppColors.white,
    primaryContainer: AppColors.brandRoseTint,
    onPrimaryContainer: AppColors.brandRedDeep,
    secondary: AppColors.brandRedDeep,
    onSecondary: AppColors.white,
    secondaryContainer: AppColors.brandRoseTint,
    onSecondaryContainer: AppColors.brandRedDeep,
    tertiary: AppColors.brandInk,
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
  // Ensure readable defaults across the app (Dropdowns, Chips, TextFields, etc.).
  textTheme: _buildTextTheme().apply(bodyColor: AppColors.textPrimary, displayColor: AppColors.textPrimary),
  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.background,
    foregroundColor: AppColors.textPrimary,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: true,
    titleTextStyle: GoogleFonts.montserrat(
      fontSize: FontSizes.titleLarge,
      fontWeight: FontWeight.w800,
      color: AppColors.textPrimary,
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surface,
    labelStyle: GoogleFonts.inter(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
    hintStyle: GoogleFonts.inter(color: AppColors.textSecondary.withValues(alpha: 0.85)),
    floatingLabelStyle: GoogleFonts.inter(color: AppColors.brandRedDeep, fontWeight: FontWeight.w700),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg), borderSide: BorderSide(color: AppColors.divider)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg), borderSide: BorderSide(color: AppColors.divider.withValues(alpha: 0.8))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg), borderSide: const BorderSide(color: AppColors.brandRed, width: 1.6)),
  ),
  dropdownMenuTheme: DropdownMenuThemeData(
    textStyle: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
    menuStyle: MenuStyle(
      backgroundColor: WidgetStatePropertyAll(AppColors.surface),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg), side: BorderSide(color: AppColors.divider.withValues(alpha: 0.7)))),
    ),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: AppColors.surfaceVariant,
    selectedColor: AppColors.brandRed.withValues(alpha: 0.14),
    side: BorderSide(color: AppColors.divider.withValues(alpha: 0.8)),
    selectedShadowColor: Colors.transparent,
    showCheckmark: false,
    labelStyle: GoogleFonts.montserrat(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
    secondaryLabelStyle: GoogleFonts.montserrat(color: AppColors.brandRedDeep, fontWeight: FontWeight.w800),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
      backgroundColor: AppColors.brandRed,
      foregroundColor: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      textStyle: GoogleFonts.montserrat(
        fontSize: FontSizes.titleMedium,
        fontWeight: FontWeight.w800,
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.brandRedDeep,
      side: BorderSide(color: AppColors.divider.withValues(alpha: 0.9)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      textStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
    ),
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: AppColors.surface,
    contentTextStyle: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
    actionTextColor: AppColors.brandRedDeep,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg), side: BorderSide(color: AppColors.divider.withValues(alpha: 0.7))),
  ),
);

ThemeData get darkTheme => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.dark(
    primary: AppColors.brandRed,
    onPrimary: AppColors.white,
    primaryContainer: AppColors.darkSurfaceVariant,
    onPrimaryContainer: AppColors.darkTextPrimary,
    secondary: AppColors.brandRedDeep,
    onSecondary: AppColors.white,
    secondaryContainer: AppColors.darkSurfaceVariant,
    onSecondaryContainer: AppColors.darkTextPrimary,
    tertiary: AppColors.darkTextPrimary,
    onTertiary: AppColors.darkBackground,
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
  textTheme: _buildTextTheme().apply(bodyColor: AppColors.darkTextPrimary, displayColor: AppColors.darkTextPrimary),
  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.darkBackground,
    foregroundColor: AppColors.darkTextPrimary,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: true,
    titleTextStyle: GoogleFonts.montserrat(
      fontSize: FontSizes.titleLarge,
      fontWeight: FontWeight.w800,
      color: AppColors.darkTextPrimary,
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.darkSurface,
    labelStyle: GoogleFonts.inter(color: AppColors.darkTextSecondary, fontWeight: FontWeight.w600),
    hintStyle: GoogleFonts.inter(color: AppColors.darkTextSecondary.withValues(alpha: 0.85)),
    floatingLabelStyle: GoogleFonts.inter(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w700),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg), borderSide: BorderSide(color: AppColors.darkSurfaceVariant)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg), borderSide: BorderSide(color: AppColors.darkSurfaceVariant.withValues(alpha: 0.9))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg), borderSide: const BorderSide(color: AppColors.brandRed, width: 1.6)),
  ),
  dropdownMenuTheme: DropdownMenuThemeData(
    textStyle: GoogleFonts.inter(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w600),
    menuStyle: MenuStyle(
      backgroundColor: WidgetStatePropertyAll(AppColors.darkSurface),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg), side: BorderSide(color: AppColors.darkSurfaceVariant.withValues(alpha: 0.8)))),
    ),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: AppColors.darkSurfaceVariant,
    selectedColor: AppColors.brandRed.withValues(alpha: 0.22),
    side: BorderSide(color: AppColors.darkSurfaceVariant.withValues(alpha: 0.9)),
    selectedShadowColor: Colors.transparent,
    showCheckmark: false,
    labelStyle: GoogleFonts.montserrat(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w700),
    secondaryLabelStyle: GoogleFonts.montserrat(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w800),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
      backgroundColor: AppColors.brandRed,
      foregroundColor: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      textStyle: GoogleFonts.montserrat(
        fontSize: FontSizes.titleMedium,
        fontWeight: FontWeight.w800,
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.darkTextPrimary,
      side: BorderSide(color: AppColors.darkSurfaceVariant.withValues(alpha: 0.9)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      textStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
    ),
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: AppColors.darkSurface,
    contentTextStyle: GoogleFonts.inter(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w600),
    actionTextColor: AppColors.brandRed,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg), side: BorderSide(color: AppColors.darkSurfaceVariant.withValues(alpha: 0.8))),
  ),
);

TextTheme _buildTextTheme() => TextTheme(
  displayLarge: GoogleFonts.montserrat(
    fontSize: FontSizes.displayLarge,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
  ),
  displayMedium: GoogleFonts.montserrat(
    fontSize: FontSizes.displayMedium,
    fontWeight: FontWeight.w700,
  ),
  displaySmall: GoogleFonts.montserrat(
    fontSize: FontSizes.displaySmall,
    fontWeight: FontWeight.w700,
  ),
  headlineLarge: GoogleFonts.montserrat(
    fontSize: FontSizes.headlineLarge,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.25,
  ),
  headlineMedium: GoogleFonts.montserrat(
    fontSize: FontSizes.headlineMedium,
    fontWeight: FontWeight.w700,
  ),
  headlineSmall: GoogleFonts.montserrat(
    fontSize: FontSizes.headlineSmall,
    fontWeight: FontWeight.w700,
  ),
  titleLarge: GoogleFonts.montserrat(
    fontSize: FontSizes.titleLarge,
    fontWeight: FontWeight.w600,
  ),
  titleMedium: GoogleFonts.montserrat(
    fontSize: FontSizes.titleMedium,
    fontWeight: FontWeight.w600,
  ),
  titleSmall: GoogleFonts.montserrat(
    fontSize: FontSizes.titleSmall,
    fontWeight: FontWeight.w600,
  ),
  labelLarge: GoogleFonts.montserrat(
    fontSize: FontSizes.labelLarge,
    fontWeight: FontWeight.w600,
  ),
  labelMedium: GoogleFonts.montserrat(
    fontSize: FontSizes.labelMedium,
    fontWeight: FontWeight.w500,
  ),
  labelSmall: GoogleFonts.montserrat(
    fontSize: FontSizes.labelSmall,
    fontWeight: FontWeight.w500,
  ),
  bodyLarge: GoogleFonts.inter(
    fontSize: FontSizes.bodyLarge,
    fontWeight: FontWeight.w400,
    height: 1.5,
  ),
  bodyMedium: GoogleFonts.inter(
    fontSize: FontSizes.bodyMedium,
    fontWeight: FontWeight.w400,
    height: 1.5,
  ),
  bodySmall: GoogleFonts.inter(
    fontSize: FontSizes.bodySmall,
    fontWeight: FontWeight.w400,
    height: 1.4,
  ),
);
