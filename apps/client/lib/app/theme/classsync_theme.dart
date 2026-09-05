import 'package:flutter/material.dart';

class ClassSyncTheme {
  static const _inkTeal = Color(0xFF24534F);
  static const _coral = Color(0xFFC85E42);
  static const _paper = Color(0xFFF6F1E7);
  static const _paperDark = Color(0xFF171B1A);

  static ThemeData light() => _theme(Brightness.light);
  static ThemeData dark() => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final generated = ColorScheme.fromSeed(
      seedColor: _inkTeal,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
    final scheme = generated.copyWith(
      primary: dark ? const Color(0xFF9CD1C9) : _inkTeal,
      onPrimary: dark ? const Color(0xFF083733) : Colors.white,
      primaryContainer: dark
          ? const Color(0xFF183F3B)
          : const Color(0xFFDCEAE4),
      onPrimaryContainer: dark
          ? const Color(0xFFC1EEE7)
          : const Color(0xFF173A37),
      secondary: dark ? const Color(0xFFFFB4A0) : _coral,
      onSecondary: dark ? const Color(0xFF592012) : Colors.white,
      secondaryContainer: dark
          ? const Color(0xFF733422)
          : const Color(0xFFF8DED5),
      onSecondaryContainer: dark
          ? const Color(0xFFFFDBD1)
          : const Color(0xFF542013),
      tertiary: dark ? const Color(0xFFE9C36D) : const Color(0xFF8B681D),
      surface: dark ? _paperDark : _paper,
      surfaceContainerLowest: dark
          ? const Color(0xFF111514)
          : const Color(0xFFFFFCF6),
      surfaceContainerLow: dark
          ? const Color(0xFF1D2220)
          : const Color(0xFFF0EADD),
      surfaceContainer: dark
          ? const Color(0xFF232826)
          : const Color(0xFFEAE2D3),
      outline: dark ? const Color(0xFF969F99) : const Color(0xFF77766E),
      outlineVariant: dark ? const Color(0xFF3E4844) : const Color(0xFFD4CBBE),
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.standard,
      fontFamily: 'Manrope',
    );
    const radius = BorderRadius.all(Radius.circular(20));
    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displaySmall: base.textTheme.displaySmall?.copyWith(
          fontFamily: 'Fraunces',
          fontWeight: FontWeight.w700,
          height: 1.04,
        ),
        headlineLarge: base.textTheme.headlineLarge?.copyWith(
          fontFamily: 'Fraunces',
          fontWeight: FontWeight.w700,
          height: 1.08,
        ),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontFamily: 'Fraunces',
          fontWeight: FontWeight.w700,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.45),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.4),
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: const OutlineInputBorder(borderRadius: radius),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.secondaryContainer,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        useIndicator: true,
        indicatorColor: scheme.secondaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onSecondaryContainer),
        selectedLabelTextStyle: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    );
  }
}
