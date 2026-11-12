import 'package:flutter/material.dart';

/// The app theme. List tiles keep 16 dp at both ends, like cards and text
/// fields. Material 3 gives them 24 dp at the end, which pushed everything on
/// the right (icons, buttons, switches) further in than the content on the
/// left. A tile whose trailing widget is a 48 dp button needs less still:
/// see [trailingButtonTilePadding].
ThemeData appTheme([Brightness brightness = Brightness.light]) => ThemeData(
  colorSchemeSeed: Colors.indigo,
  brightness: brightness,
  useMaterial3: true,
  listTileTheme: const ListTileThemeData(
    contentPadding: EdgeInsetsDirectional.symmetric(horizontal: 16),
  ),
);

/// Padding for a [ListTile] that ends with an icon button or a text button.
/// The button is 48 dp wide with the glyph in the middle (a text button has
/// 12 dp of padding around its label), so the tile gives it 12 dp less: the
/// glyph then sits 16 dp from the edge, aligned with the text on the left.
const trailingButtonTilePadding = EdgeInsetsDirectional.only(start: 16, end: 4);

/// Same as [trailingButtonTilePadding] when the trailing button is filled
/// (or tonal): its visible circle is 40 dp inside the 48 dp box, 4 dp short
/// of the edge on each side, so the tile gives it 8 dp more.
const trailingFilledButtonTilePadding = EdgeInsetsDirectional.only(
  start: 16,
  end: 12,
);
