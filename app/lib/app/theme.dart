import 'package:flutter/material.dart';

/// The application theme (implement-android-capture-and-store, design §2).
///
/// Only what NFR-ACC-001 requires is set here: text large enough to read by
/// default, and touch targets at the platform minimum of 48 dp. Colours are the
/// framework's Material 3 defaults: this change takes no design decision, and a
/// palette invented in passing would be one.
abstract final class PaperdropTheme {
  /// The minimum edge of a tappable control, in logical pixels (NFR-ACC-001).
  static const double minimumTapTarget = 48;

  /// The base size of body text. Nothing in the app sets a text scale of its
  /// own, so the system setting multiplies this (NFR-ACC-001, large type).
  static const double bodyFontSize = 16;

  /// The size of the text of an action; above [bodyFontSize] because an action
  /// is read at arm's length.
  static const double actionFontSize = 18;

  /// The size of the screen heading.
  static const double headingFontSize = 28;

  /// The theme of the light (and only) appearance of the MVP.
  static ThemeData light() {
    final ThemeData base = ThemeData();
    final TextTheme text = base.textTheme;
    return base.copyWith(
      textTheme: text.copyWith(
        headlineSmall: text.headlineSmall?.copyWith(fontSize: headingFontSize),
        titleLarge: text.titleLarge?.copyWith(fontSize: 22),
        bodyLarge: text.bodyLarge?.copyWith(
          fontSize: bodyFontSize,
          height: 1.4,
        ),
        bodyMedium: text.bodyMedium?.copyWith(
          fontSize: bodyFontSize,
          height: 1.4,
        ),
      ),
      appBarTheme: base.appBarTheme.copyWith(
        titleTextStyle: text.titleLarge?.copyWith(fontSize: 22),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, minimumTapTarget),
          textStyle: const TextStyle(fontSize: actionFontSize),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, minimumTapTarget),
          textStyle: const TextStyle(fontSize: actionFontSize),
        ),
      ),
    );
  }
}
