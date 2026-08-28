import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Nirvana's palette, drawn from the app icon (assets/images/Nirvana_Icon_2.png):
/// a meditating figure glowing warm gold against a deep-teal dusk, ringed by
/// sage-green leaves and a teal water swirl. Light/dark ThemeData built from
/// this seed. See PROJECT_PLAN.md and lib/app_shell/, lib/screens/screen_scaffold.dart.
class NirvanaColors {
  NirvanaColors._();

  /// Deep teal — the icon's background wash. Primary brand color.
  static const teal = Color(0xFF0E4A5C);
  static const tealLight = Color(0xFF3E92A8);

  /// Sage/leaf green from the icon's leaf swirl. Secondary accent.
  static const sage = Color(0xFF5FA37B);

  /// Warm gold from the figure's glow. Tertiary accent — used sparingly,
  /// for highlights (streaks, active states), never as a base surface.
  static const gold = Color(0xFFE0A85C);

  static const creamGlow = Color(0xFFFBF3DE);

  /// Fixed brand green for the app bar and drawer — deliberately *not*
  /// derived from ColorScheme.surface, which goes near-black in dark mode
  /// and read as "the top bar is just black" (see PROJECT_PLAN.md). Keeping
  /// this one bar color constant across light/dark keeps the icon's green
  /// identity visible regardless of system theme.
  static const barGreen = Color(0xFF1E6B55);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      // Seeding from the brand green (not the deeper teal) so every
      // Material-generated surface — cards, scaffold, tonal containers —
      // reads green like the app bar/drawer, instead of the blue-leaning
      // neutrals a teal seed produces in dark mode.
      seedColor: NirvanaColors.barGreen,
      brightness: brightness,
      secondary: NirvanaColors.tealLight,
      tertiary: NirvanaColors.gold,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF0F231D)
          : const Color(0xFFF4FAF7),
      appBarTheme: const AppBarTheme(
        backgroundColor: NirvanaColors.barGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        // A visible green tint over the surface color, rather than the
        // near-neutral default surfaceContainerHigh, so cards read as part
        // of the same green identity as the app bar/drawer instead of
        // standing out as plain grey tiles.
        color: Color.alphaBlend(
          NirvanaColors.sage.withValues(alpha: isDark ? 0.22 : 0.10),
          colorScheme.surface,
        ),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: NirvanaColors.sage.withValues(alpha: 0.25)),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.secondaryContainer.withValues(alpha: 0.5),
        selectedColor: colorScheme.secondaryContainer,
        labelStyle: TextStyle(color: colorScheme.onSecondaryContainer),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide.none,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        iconColor: colorScheme.primary,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.primary.withValues(alpha: 0.15),
        circularTrackColor: colorScheme.primary.withValues(alpha: 0.15),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colorScheme.primary,
        thumbColor: colorScheme.primary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.primary
              : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.primary.withValues(alpha: 0.5)
              : null,
        ),
      ),
      drawerTheme: const DrawerThemeData(backgroundColor: NirvanaColors.barGreen),
      dividerTheme: DividerThemeData(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
      ),
    );
  }

  /// Leaf-green-to-brand-green wash for the drawer header. Used behind
  /// streaks/highlights too.
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [NirvanaColors.sage, NirvanaColors.barGreen],
  );
}
