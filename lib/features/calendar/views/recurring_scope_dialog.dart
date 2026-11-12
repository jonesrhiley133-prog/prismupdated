import 'package:flutter/material.dart';

import 'package:prism_plurality/features/calendar/providers/calendar_providers.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/widgets/prism_list_row.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';

/// Asks whether an edit or delete applies to one occurrence, this and
/// following occurrences, or the whole series. Null when dismissed.
Future<RecurringEditScope?> showRecurringScopeDialog(
  BuildContext context, {
  required String title,
}) {
  final l10n = context.l10n;
  return PrismSheet.show<RecurringEditScope>(
    context: context,
    title: title,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (scope, label) in [
            (RecurringEditScope.thisOccurrence, l10n.calendarScopeThis),
            (RecurringEditScope.thisAndFollowing, l10n.calendarScopeFollowing),
            (RecurringEditScope.allOccurrences, l10n.calendarScopeAll),
          ])
            PrismListRow(
              title: Text(label),
              onTap: () => Navigator.of(context).pop(scope),
            ),
        ],
      ),
    ),
  );
}
