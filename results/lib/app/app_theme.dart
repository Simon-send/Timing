import 'package:flutter/material.dart';

enum AppThemeVariant {
  nordicDark,
  graphite,
  alpineLight,
  stadium;

  static AppThemeVariant fromName(String? name) {
    return AppThemeVariant.values.firstWhere(
      (variant) => variant.name == name,
      orElse: () => AppThemeVariant.nordicDark,
    );
  }

  String get label {
    return switch (this) {
      AppThemeVariant.nordicDark => 'Nordic dark',
      AppThemeVariant.graphite => 'Graphite',
      AppThemeVariant.alpineLight => 'Alpine light',
      AppThemeVariant.stadium => 'Stadium',
    };
  }
}

ThemeData buildAppTheme(AppThemeVariant variant) {
  final palette = AppPalette.forVariant(variant);

  final colorScheme = ColorScheme.fromSeed(
    seedColor: palette.primary,
    brightness: palette.brightness,
    primary: palette.primary,
    secondary: palette.secondary,
    surface: palette.panel,
  );

  return ThemeData(
    brightness: palette.brightness,
    scaffoldBackgroundColor: palette.background,
    colorScheme: colorScheme,
    extensions: [palette],
    useMaterial3: true,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.panelAlt,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: palette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: palette.primary, width: 1.4),
      ),
    ),
    cardTheme: CardThemeData(
      color: palette.panel,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: palette.border),
      ),
    ),
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStatePropertyAll(palette.panelAlt),
      dataRowColor: WidgetStatePropertyAll(palette.panel),
      dividerThickness: 0.7,
    ),
  );
}

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brightness,
    required this.background,
    required this.panel,
    required this.panelAlt,
    required this.border,
    required this.primary,
    required this.secondary,
    required this.mutedText,
    required this.logoForeground,
    required this.danger,
  });

  factory AppPalette.forVariant(AppThemeVariant variant) {
    return switch (variant) {
      AppThemeVariant.nordicDark => const AppPalette(
        brightness: Brightness.dark,
        background: Color(0xFF101418),
        panel: Color(0xFF171D23),
        panelAlt: Color(0xFF151B20),
        border: Color(0xFF2B333A),
        primary: Color(0xFF5CC8B2),
        secondary: Color(0xFFF4B45F),
        mutedText: Color(0xFFB7C1C9),
        logoForeground: Color(0xFF07110F),
        danger: Color(0xFFFFB4AB),
      ),
      AppThemeVariant.graphite => const AppPalette(
        brightness: Brightness.dark,
        background: Color(0xFF0F1115),
        panel: Color(0xFF1B1F27),
        panelAlt: Color(0xFF252A34),
        border: Color(0xFF383F4D),
        primary: Color(0xFFB8C0CC),
        secondary: Color(0xFFE7C16F),
        mutedText: Color(0xFFC3C9D1),
        logoForeground: Color(0xFF111318),
        danger: Color(0xFFFFB4AB),
      ),
      AppThemeVariant.alpineLight => const AppPalette(
        brightness: Brightness.light,
        background: Color(0xFFF4F7FA),
        panel: Color(0xFFFFFFFF),
        panelAlt: Color(0xFFEAF0F5),
        border: Color(0xFFD2DCE5),
        primary: Color(0xFF1E7C70),
        secondary: Color(0xFFB56B18),
        mutedText: Color(0xFF52606D),
        logoForeground: Color(0xFFFFFFFF),
        danger: Color(0xFFB3261E),
      ),
      AppThemeVariant.stadium => const AppPalette(
        brightness: Brightness.dark,
        background: Color(0xFF07130F),
        panel: Color(0xFF10211B),
        panelAlt: Color(0xFF173026),
        border: Color(0xFF2A4A3E),
        primary: Color(0xFF9DE36E),
        secondary: Color(0xFFFFCF5A),
        mutedText: Color(0xFFC2D0C8),
        logoForeground: Color(0xFF07130F),
        danger: Color(0xFFFFB4AB),
      ),
    };
  }

  final Brightness brightness;
  final Color background;
  final Color panel;
  final Color panelAlt;
  final Color border;
  final Color primary;
  final Color secondary;
  final Color mutedText;
  final Color logoForeground;
  final Color danger;

  @override
  AppPalette copyWith({
    Brightness? brightness,
    Color? background,
    Color? panel,
    Color? panelAlt,
    Color? border,
    Color? primary,
    Color? secondary,
    Color? mutedText,
    Color? logoForeground,
    Color? danger,
  }) {
    return AppPalette(
      brightness: brightness ?? this.brightness,
      background: background ?? this.background,
      panel: panel ?? this.panel,
      panelAlt: panelAlt ?? this.panelAlt,
      border: border ?? this.border,
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      mutedText: mutedText ?? this.mutedText,
      logoForeground: logoForeground ?? this.logoForeground,
      danger: danger ?? this.danger,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: Color.lerp(background, other.background, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      panelAlt: Color.lerp(panelAlt, other.panelAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      logoForeground: Color.lerp(logoForeground, other.logoForeground, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}
