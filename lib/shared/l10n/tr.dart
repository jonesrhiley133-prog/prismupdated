import 'package:flutter/widgets.dart';

/// Inline English/Spanish text for the larger feature modules, picked from
/// the active locale. Keeps each module's copy next to its UI.
String tr(BuildContext context, String en, String es) =>
    Localizations.maybeLocaleOf(context)?.languageCode == 'es' ? es : en;
