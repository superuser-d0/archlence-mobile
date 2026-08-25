/// Obsidian Prime — the Archlence Mobile design system.
///
/// Colour values come VERBATIM from the token block at the top of
/// `DESIGN.md`, never from its prose. The two disagree (the prose names
/// #0A0A0A / #10B981 / #F43F5E while the tokens say #131313 / #4edea3 /
/// #ffb4ab) and the generated reference screens follow the tokens, so the
/// tokens are the single source of truth here. Reading a value off the prose
/// would silently introduce a second green.
///
/// The token names are Material 3 role names, which Flutter's [ColorScheme]
/// carries natively — so the mapping below is one-to-one and needs no
/// approximation.
library;

import 'package:flutter/material.dart';

/// Raw palette. Prefer [Theme.of(context).colorScheme] in widgets; these are
/// exposed for the few places that need a colour outside a BuildContext.
abstract final class ObsidianPalette {
  static const surface = Color(0xFF131313);
  static const surfaceDim = Color(0xFF131313);
  static const surfaceBright = Color(0xFF3A3939);
  static const surfaceContainerLowest = Color(0xFF0E0E0E);
  static const surfaceContainerLow = Color(0xFF1C1B1B);
  static const surfaceContainer = Color(0xFF201F1F);
  static const surfaceContainerHigh = Color(0xFF2A2A2A);
  static const surfaceContainerHighest = Color(0xFF353534);

  static const onSurface = Color(0xFFE5E2E1);
  static const onSurfaceVariant = Color(0xFFC7C4D7);
  static const inverseSurface = Color(0xFFE5E2E1);
  static const inverseOnSurface = Color(0xFF313030);

  static const outline = Color(0xFF908FA0);
  static const outlineVariant = Color(0xFF464554);
  static const surfaceTint = Color(0xFFC0C1FF);

  static const primary = Color(0xFFC0C1FF);
  static const onPrimary = Color(0xFF1000A9);
  static const primaryContainer = Color(0xFF8083FF);
  static const onPrimaryContainer = Color(0xFF0D0096);
  static const inversePrimary = Color(0xFF494BD6);

  static const secondary = Color(0xFFD0BCFF);
  static const onSecondary = Color(0xFF3C0091);
  static const secondaryContainer = Color(0xFF571BC1);
  static const onSecondaryContainer = Color(0xFFC4ABFF);

  /// Positive money: income, growth, cash.
  static const tertiary = Color(0xFF4EDEA3);
  static const onTertiary = Color(0xFF003824);
  static const tertiaryContainer = Color(0xFF00885D);
  static const onTertiaryContainer = Color(0xFF000703);

  /// Negative money: expense, debt, critical alerts.
  static const error = Color(0xFFFFB4AB);
  static const onError = Color(0xFF690005);
  static const errorContainer = Color(0xFF93000A);
  static const onErrorContainer = Color(0xFFFFDAD6);

  static const primaryFixed = Color(0xFFE1E0FF);
  static const primaryFixedDim = Color(0xFFC0C1FF);
  static const onPrimaryFixed = Color(0xFF07006C);
  static const onPrimaryFixedVariant = Color(0xFF2F2EBE);

  static const secondaryFixed = Color(0xFFE9DDFF);
  static const secondaryFixedDim = Color(0xFFD0BCFF);
  static const onSecondaryFixed = Color(0xFF23005C);
  static const onSecondaryFixedVariant = Color(0xFF5516BE);

  static const tertiaryFixed = Color(0xFF6FFBBE);
  static const tertiaryFixedDim = Color(0xFF4EDEA3);
  static const onTertiaryFixed = Color(0xFF002113);
  static const onTertiaryFixedVariant = Color(0xFF005236);

  /// Hairline that separates a card from the backdrop (DESIGN.md: every card
  /// carries a 1px `rgba(255,255,255,0.08)` stroke).
  static const cardStroke = Color(0x14FFFFFF);

  /// The gradient behind primary buttons: indigo to violet.
  static const primaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFC0C1FF), Color(0xFF8083FF)],
  );
}

/// The 8px-based spacing scale from DESIGN.md.
abstract final class Spacing {
  static const containerMargin = 24.0;
  static const gutter = 16.0;
  static const stackSm = 8.0;
  static const stackMd = 16.0;
  static const stackLg = 32.0;
  static const sectionGap = 48.0;
}

/// Corner radii from DESIGN.md's shape language.
abstract final class Radii {
  static const sm = 4.0;
  static const base = 8.0;

  /// Buttons and inputs.
  static const md = 12.0;

  /// Standard cards and containers.
  static const lg = 16.0;
  static const xl = 24.0;

  /// Chips and status badges.
  static const full = 999.0;
}

const _fontFamily = 'PlusJakartaSans';

/// The type ramp from DESIGN.md, mapped onto Material's text roles so that
/// stock widgets pick up the right style without per-widget overrides.
const _textTheme = TextTheme(
  // display-lg — large financial totals.
  displayLarge: TextStyle(
    fontFamily: _fontFamily,
    fontSize: 40,
    fontWeight: FontWeight.w700,
    height: 48 / 40,
    letterSpacing: -0.02 * 40,
  ),
  // headline-lg
  headlineLarge: TextStyle(
    fontFamily: _fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 40 / 32,
    letterSpacing: -0.01 * 32,
  ),
  // headline-lg-mobile — the phone-sized page title.
  headlineMedium: TextStyle(
    fontFamily: _fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 36 / 28,
  ),
  // headline-md
  headlineSmall: TextStyle(
    fontFamily: _fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 32 / 24,
  ),
  // headline-sm — section and card titles.
  titleLarge: TextStyle(
    fontFamily: _fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 28 / 20,
  ),
  // body-lg
  bodyLarge: TextStyle(
    fontFamily: _fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 28 / 18,
  ),
  // body-md
  bodyMedium: TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 24 / 16,
  ),
  // body-sm
  bodySmall: TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 20 / 14,
  ),
  // label-md — data labels, chips, nav captions.
  labelMedium: TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 16 / 12,
    letterSpacing: 0.05 * 12,
  ),
);

const _colorScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: ObsidianPalette.primary,
  onPrimary: ObsidianPalette.onPrimary,
  primaryContainer: ObsidianPalette.primaryContainer,
  onPrimaryContainer: ObsidianPalette.onPrimaryContainer,
  primaryFixed: ObsidianPalette.primaryFixed,
  primaryFixedDim: ObsidianPalette.primaryFixedDim,
  onPrimaryFixed: ObsidianPalette.onPrimaryFixed,
  onPrimaryFixedVariant: ObsidianPalette.onPrimaryFixedVariant,
  secondary: ObsidianPalette.secondary,
  onSecondary: ObsidianPalette.onSecondary,
  secondaryContainer: ObsidianPalette.secondaryContainer,
  onSecondaryContainer: ObsidianPalette.onSecondaryContainer,
  secondaryFixed: ObsidianPalette.secondaryFixed,
  secondaryFixedDim: ObsidianPalette.secondaryFixedDim,
  onSecondaryFixed: ObsidianPalette.onSecondaryFixed,
  onSecondaryFixedVariant: ObsidianPalette.onSecondaryFixedVariant,
  tertiary: ObsidianPalette.tertiary,
  onTertiary: ObsidianPalette.onTertiary,
  tertiaryContainer: ObsidianPalette.tertiaryContainer,
  onTertiaryContainer: ObsidianPalette.onTertiaryContainer,
  tertiaryFixed: ObsidianPalette.tertiaryFixed,
  tertiaryFixedDim: ObsidianPalette.tertiaryFixedDim,
  onTertiaryFixed: ObsidianPalette.onTertiaryFixed,
  onTertiaryFixedVariant: ObsidianPalette.onTertiaryFixedVariant,
  error: ObsidianPalette.error,
  onError: ObsidianPalette.onError,
  errorContainer: ObsidianPalette.errorContainer,
  onErrorContainer: ObsidianPalette.onErrorContainer,
  surface: ObsidianPalette.surface,
  onSurface: ObsidianPalette.onSurface,
  surfaceDim: ObsidianPalette.surfaceDim,
  surfaceBright: ObsidianPalette.surfaceBright,
  surfaceContainerLowest: ObsidianPalette.surfaceContainerLowest,
  surfaceContainerLow: ObsidianPalette.surfaceContainerLow,
  surfaceContainer: ObsidianPalette.surfaceContainer,
  surfaceContainerHigh: ObsidianPalette.surfaceContainerHigh,
  surfaceContainerHighest: ObsidianPalette.surfaceContainerHighest,
  onSurfaceVariant: ObsidianPalette.onSurfaceVariant,
  outline: ObsidianPalette.outline,
  outlineVariant: ObsidianPalette.outlineVariant,
  inverseSurface: ObsidianPalette.inverseSurface,
  onInverseSurface: ObsidianPalette.inverseOnSurface,
  inversePrimary: ObsidianPalette.inversePrimary,
  surfaceTint: ObsidianPalette.surfaceTint,
);

/// The application theme. Obsidian Prime is a dark-only design, so there is
/// deliberately no light counterpart to fall back to.
ThemeData obsidianPrimeTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: _colorScheme,
    scaffoldBackgroundColor: ObsidianPalette.surface,
    fontFamily: _fontFamily,
    textTheme: _textTheme,

    // DESIGN.md puts hierarchy in translucency and strokes, not drop shadows.
    cardTheme: CardThemeData(
      color: ObsidianPalette.surfaceContainer,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
        side: const BorderSide(color: ObsidianPalette.cardStroke),
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: ObsidianPalette.cardStroke,
      thickness: 1,
      space: 1,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ObsidianPalette.surfaceContainerLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        borderSide: const BorderSide(
          color: ObsidianPalette.surfaceContainerHigh,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        borderSide: const BorderSide(
          color: ObsidianPalette.surfaceContainerHigh,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        borderSide: const BorderSide(color: ObsidianPalette.primary),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        borderSide: const BorderSide(color: ObsidianPalette.error),
      ),
      hintStyle: _textTheme.bodyMedium?.copyWith(
        color: ObsidianPalette.onSurfaceVariant,
      ),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: ObsidianPalette.surfaceContainerLow,
      indicatorColor: Colors.transparent,
      elevation: 0,
      height: 68,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return _textTheme.labelMedium?.copyWith(
          letterSpacing: 0,
          color: selected
              ? ObsidianPalette.primary
              : ObsidianPalette.onSurfaceVariant,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 24,
          color: selected
              ? ObsidianPalette.primary
              : ObsidianPalette.onSurfaceVariant,
        );
      }),
    ),

    // Ghost/secondary button: transparent with a hairline, per DESIGN.md.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ObsidianPalette.onSurface,
        side: const BorderSide(color: Color(0x33FFFFFF)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        textStyle: _textTheme.labelMedium?.copyWith(letterSpacing: 0),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: ObsidianPalette.primary,
        textStyle: _textTheme.labelMedium?.copyWith(letterSpacing: 0),
      ),
    ),

    iconTheme: const IconThemeData(
      color: ObsidianPalette.onSurfaceVariant,
      size: 24,
    ),

    splashFactory: InkSparkle.splashFactory,
  );
}
