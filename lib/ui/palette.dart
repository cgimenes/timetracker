import 'package:flutter/material.dart';

/// Color for slot [slot] of a list of groups (projects, accounts), the same
/// in the Calendar and the Metrics chart. Hues walk the golden angle so that
/// neighbouring slots differ a lot, whatever the number of groups.
Color paletteColor(int slot, Brightness brightness) {
  final hue = (slot * 137.508 + 20) % 360;
  return brightness == Brightness.light
      ? HSLColor.fromAHSL(1, hue, 0.55, 0.40).toColor()
      : HSLColor.fromAHSL(1, hue, 0.50, 0.58).toColor();
}

/// Text color that reads on [background].
Color onPalette(Color background) =>
    ThemeData.estimateBrightnessForColor(background) == Brightness.dark
    ? Colors.white
    : Colors.black87;
