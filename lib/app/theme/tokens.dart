import 'package:flutter/material.dart';

/// Design tokens from the Stitch "Sacred Editorial" system
/// (stitch_devotion_reflections_of_faith/sacred_editorial/DESIGN.md).
abstract final class AppColors {
  // Primary — Deep Forest Pine.
  static const primary = Color(0xFF1A382B);
  static const primaryDeep = Color(0xFF11281E);
  static const primaryInk = Color(0xFF032217);
  static const onPrimary = Color(0xFFFFFFFF);
  static const onPrimaryMuted = Color(0xFF81A291);
  static const primaryFixed = Color(0xFFC8EAD7);

  // Secondary — Muted Warm Gold.
  static const gold = Color(0xFFC5A059);
  static const goldBright = Color(0xFFD4AF37);
  static const goldDeep = Color(0xFF775A19);
  static const goldContainer = Color(0xFFFED488);
  static const onGoldContainer = Color(0xFF5D4201);

  // Tertiary — Deep Teal.
  static const teal = Color(0xFF2B5E55);

  // Canvas & surfaces.
  static const canvas = Color(0xFFFBF9F5);
  static const card = Color(0xFFFFFFFF);
  static const recessed = Color(0xFFFAF7F2);
  static const surfaceLow = Color(0xFFF5F3EF);
  static const surfaceContainer = Color(0xFFEFEEEA);
  static const surfaceHigh = Color(0xFFEAE8E4);
  static const linen = Color(0xFFEAE5DC);

  // Ink.
  static const ink = Color(0xFF1C1E1B);
  static const inkSecondary = Color(0xFF5A605B);
  static const inkMuted = Color(0xFF8A918B);

  // Semantic status spectrum.
  static const approved = Color(0xFF1A382B);
  static const approvedBg = Color(0xFFEBF2EE);
  static const pending = Color(0xFFB88728);
  static const pendingBg = Color(0xFFFAF4E8);
  static const changes = Color(0xFF9E4336);
  static const changesBg = Color(0xFFFBF0EE);
  static const error = Color(0xFFBA1A1A);
  static const errorBg = Color(0xFFFFDAD6);
  static const neutralBg = Color(0xFFEFEEEA);
}

abstract final class AppSpacing {
  static const s2xs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const s2xl = 48.0;

  /// Horizontal page margin on phones.
  static const page = 20.0;
  static const gutter = 12.0;

  /// Minimum touch target (DESIGN.md: 48px).
  static const minTap = 48.0;
}

abstract final class AppRadii {
  static const sm = 4.0;
  static const base = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;

  static const card = BorderRadius.all(Radius.circular(lg));
  static const control = BorderRadius.all(Radius.circular(md));
  static const pill = BorderRadius.all(Radius.circular(999));
}

abstract final class AppShadows {
  static const level1 = [
    BoxShadow(
      color: Color(0x0A1A382B),
      offset: Offset(0, 2),
      blurRadius: 8,
      spreadRadius: -2,
    ),
    BoxShadow(color: Color(0x05000000), offset: Offset(0, 1), blurRadius: 3),
  ];

  static const level2 = [
    BoxShadow(
      color: Color(0x141A382B),
      offset: Offset(0, 8),
      blurRadius: 24,
      spreadRadius: -4,
    ),
    BoxShadow(
      color: Color(0x0DC5A059),
      offset: Offset(0, 3),
      blurRadius: 6,
      spreadRadius: -2,
    ),
  ];
}
