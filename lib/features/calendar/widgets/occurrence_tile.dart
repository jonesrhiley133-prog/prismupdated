import 'package:flutter/material.dart';

import 'package:prism_plurality/features/calendar/utils/recurrence.dart';
import 'package:prism_plurality/features/calendar/views/event_detail_sheet.dart';
import 'package:prism_plurality/features/calendar/widgets/calendar_colors.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/widgets/prism_surface.dart';

/// List row for one event occurrence (agenda and day lists).
class OccurrenceTile extends StatelessWidget {
  const OccurrenceTile({super.key, required this.occurrence, this.day});

  final CalendarOccurrence occurrence;

  /// The day the tile is listed under, for "continues" hints on multi-day
  /// events.
  final DateTime? day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = occurrence.event;
    final color = eventColor(context, e);
    final String when;
    if (occurrence.isAllDay) {
      when = context.l10n.calendarAllDay;
    } else if (day != null && !_sameDay(occurrence.start, day!)) {
      when = '… – ${context.formatTime(occurrence.end)}';
    } else {
      when =
          '${context.formatTime(occurrence.start)} – '
          '${context.formatTime(occurrence.end)}';
    }
    final meta = [
      when,
      if (e.location != null) e.location!,
      if (e.category != null) e.category!,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PrismSurface(
        padding: const EdgeInsets.fromLTRB(0, 0, 12, 0),
        onTap: () => showEventDetailSheet(context, occurrence),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 5,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(12),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        meta,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (e.isRecurring)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(
                    AppIcons.repeat,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
