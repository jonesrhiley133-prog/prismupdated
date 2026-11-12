import 'package:flutter/material.dart';

import 'package:prism_plurality/domain/models/calendar_event.dart';

/// Event colour swatches offered in the editor.
const calendarColorSwatches = <String>[
  '#5B8DEF',
  '#3DB8D9',
  '#3FAF7A',
  '#8CC269',
  '#F2C14E',
  '#F0954A',
  '#E5604D',
  '#D9578E',
  '#9B6FD6',
  '#8A8F98',
];

Color? parseHexColor(String? hex) {
  if (hex == null) return null;
  final h = hex.replaceFirst('#', '');
  if (h.length != 6) return null;
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(0xFF000000 | v);
}

/// The colour an event is drawn with.
Color eventColor(BuildContext context, CalendarEvent event) =>
    parseHexColor(event.colorHex) ?? Theme.of(context).colorScheme.primary;

/// Readable text colour on top of [background].
Color onEventColor(Color background) =>
    ThemeData.estimateBrightnessForColor(background) == Brightness.dark
    ? Colors.white
    : Colors.black87;
