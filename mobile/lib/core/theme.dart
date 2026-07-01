import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Functional signal colors (§4) — priority/severity, always paired with a word.
@immutable
class SignalColors extends ThemeExtension<SignalColors> {
  final Color sigHigh;
  final Color sigMed;
  final Color sigLow;
  final Color sigLive;

  const SignalColors({
    required this.sigHigh,
    required this.sigMed,
    required this.sigLow,
    required this.sigLive,
  });

  static const light = SignalColors(
    sigHigh: Color(0xFFA6402F),
    sigMed: Color(0xFF9A6B24),
    sigLow: Color(0xFF6F7A66),
    sigLive: Color(0xFFA6402F),
  );

  @override
  SignalColors copyWith({
    Color? sigHigh,
    Color? sigMed,
    Color? sigLow,
    Color? sigLive,
  }) {
    return SignalColors(
      sigHigh: sigHigh ?? this.sigHigh,
      sigMed: sigMed ?? this.sigMed,
      sigLow: sigLow ?? this.sigLow,
      sigLive: sigLive ?? this.sigLive,
    );
  }

  @override
  SignalColors lerp(ThemeExtension<SignalColors>? other, double t) {
    if (other is! SignalColors) return this;
    return SignalColors(
      sigHigh: Color.lerp(sigHigh, other.sigHigh, t)!,
      sigMed: Color.lerp(sigMed, other.sigMed, t)!,
      sigLow: Color.lerp(sigLow, other.sigLow, t)!,
      sigLive: Color.lerp(sigLive, other.sigLive, t)!,
    );
  }
}

/// Geist Mono `meta`/`tag` text styles (§3) — deadlines, durations, counts, priority tags.
@immutable
class QuietTypeExtension extends ThemeExtension<QuietTypeExtension> {
  final TextStyle meta;
  final TextStyle tag;

  const QuietTypeExtension({required this.meta, required this.tag});

  @override
  QuietTypeExtension copyWith({TextStyle? meta, TextStyle? tag}) {
    return QuietTypeExtension(meta: meta ?? this.meta, tag: tag ?? this.tag);
  }

  @override
  QuietTypeExtension lerp(ThemeExtension<QuietTypeExtension>? other, double t) {
    if (other is! QuietTypeExtension) return this;
    return QuietTypeExtension(
      meta: TextStyle.lerp(meta, other.meta, t)!,
      tag: TextStyle.lerp(tag, other.tag, t)!,
    );
  }
}

/// "The Quiet Brief" theme — warm paper, near-monochrome ink, Fraunces/Inter/Geist Mono.
/// See docs/superpowers/specs/2026-07-01-meetingmind-design-language.md §10.
ThemeData buildQuietBriefTheme() {
  const paper = Color(0xFFF7F4EC);
  const ink = Color(0xFF1A1714);
  const inkSecondary = Color(0xFF5A544C);
  const inkTertiary = Color(0xFF6E665C);
  const hairline = Color(0xFFE4DDD0);
  const accent = Color(0xFF2E3B36);

  final colorScheme = ColorScheme.light(
    surface: paper,
    onSurface: ink,
    primary: accent,
    onPrimary: paper,
    outlineVariant: hairline,
    secondary: inkSecondary,
    onSecondary: paper,
  );

  final fraunces = GoogleFonts.frauncesTextTheme();
  final inter = GoogleFonts.interTextTheme();
  final geistMono = GoogleFonts.geistMonoTextTheme();

  final textTheme = TextTheme(
    // display — Record & Processing headlines
    displaySmall: fraunces.displaySmall?.copyWith(
      fontSize: 32,
      height: 1.12,
      letterSpacing: -0.5,
      color: ink,
    ),
    // title — Brief title
    headlineMedium: fraunces.headlineMedium?.copyWith(
      fontSize: 28,
      height: 1.15,
      letterSpacing: -0.3,
      fontWeight: FontWeight.w500,
      color: ink,
    ),
    // standfirst — summary as the lede
    titleLarge: fraunces.titleLarge?.copyWith(
      fontSize: 18,
      height: 1.55,
      color: inkSecondary,
    ),
    // body — reflective statements, questions
    bodyLarge: fraunces.bodyLarge?.copyWith(
      fontSize: 17,
      height: 1.55,
      color: ink,
    ),
    // label — section labels (SUMMARY, TASKS), uppercase
    labelSmall: inter.labelSmall?.copyWith(
      fontSize: 12,
      height: 1.0,
      letterSpacing: 1.2,
      fontWeight: FontWeight.w600,
      color: inkTertiary,
    ),
    // item — task/decision/risk titles
    titleMedium: inter.titleMedium?.copyWith(
      fontSize: 16,
      height: 1.35,
      fontWeight: FontWeight.w500,
      color: ink,
    ),
    // caption — status & helper copy
    bodyMedium: inter.bodyMedium?.copyWith(
      fontSize: 14,
      height: 1.4,
      color: inkSecondary,
    ),
  );

  final meta = (geistMono.bodySmall ?? const TextStyle()).copyWith(
    fontSize: 13,
    height: 1.3,
    color: inkTertiary,
  );

  final tag = (geistMono.labelSmall ?? const TextStyle()).copyWith(
    fontSize: 11,
    height: 1.0,
    letterSpacing: 0.6,
    fontWeight: FontWeight.w500,
    color: inkTertiary,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: paper,
    textTheme: textTheme,
    dividerColor: hairline,
    extensions: [
      SignalColors.light,
      QuietTypeExtension(meta: meta, tag: tag),
    ],
  );
}
