import 'package:prism_plurality/shared/theme/prism_shapes.dart';
import 'package:flutter/material.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/clamped_body.dart';
import 'package:intl/intl.dart';

import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';

typedef MonthGridDayBuilder =
    Widget Function(
      BuildContext context,
      DateTime day, {
      required bool inMonth,
      required bool isToday,
      required bool isSelected,
    });

/// First visible day of the 6-week grid for [month], honouring the locale's
/// first day of the week (0 = Sunday).
DateTime monthGridStart(DateTime month, int firstDayOfWeekIndex) {
  final first = DateTime(month.year, month.month);
  final weekday = first.weekday % 7; // 0 = Sunday
  final offset = (weekday - firstDayOfWeekIndex + 7) % 7;
  return DateTime(first.year, first.month, first.day - offset);
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// A 6×7 month grid with localized weekday headers. Cell content comes from
/// [dayBuilder]; the grid handles layout, headers and taps.
class MonthGrid extends StatelessWidget {
  const MonthGrid({
    super.key,
    required this.month,
    required this.dayBuilder,
    this.selectedDay,
    this.onDaySelected,
    this.onDayLongPressed,
    this.cellAspectRatio = 1,
  });

  final DateTime month;
  final DateTime? selectedDay;
  final ValueChanged<DateTime>? onDaySelected;
  final ValueChanged<DateTime>? onDayLongPressed;
  final MonthGridDayBuilder dayBuilder;

  /// Width / height of each cell.
  final double cellAspectRatio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstDow = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    final start = monthGridStart(month, firstDow);
    final today = DateTime.now();
    final weekdayFormat = DateFormat.E(context.dateLocale);

    return CompactCalendar(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      weekdayFormat.format(
                        DateTime(start.year, start.month, start.day + i),
                      ),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          for (var week = 0; week < 6; week++)
            Row(
              children: [
                for (var d = 0; d < 7; d++)
                  Expanded(
                    child: AspectRatio(
                      // Wide web windows: near-square cells keep the month compact.
                      aspectRatio:
                          PrismTokens.desktopWebContentWidth != null &&
                              cellAspectRatio < 1.2
                          ? 1.2
                          : cellAspectRatio,
                      child: Builder(
                        builder: (context) {
                          final day = DateTime(
                            start.year,
                            start.month,
                            start.day + week * 7 + d,
                          );
                          return InkWell(
                            borderRadius: prismCorners(context, 10),
                            onTap: onDaySelected == null
                                ? null
                                : () => onDaySelected!(day),
                            onLongPress: onDayLongPressed == null
                                ? null
                                : () => onDayLongPressed!(day),
                            child: dayBuilder(
                              context,
                              day,
                              inMonth: day.month == month.month,
                              isToday: isSameDay(day, today),
                              isSelected:
                                  selectedDay != null &&
                                  isSameDay(day, selectedDay!),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// "‹  November 2026  ›" header with previous/next buttons.
class MonthHeader extends StatelessWidget {
  const MonthHeader({
    super.key,
    required this.month,
    required this.onPrevious,
    required this.onNext,
    this.onTitleTap,
    this.trailing,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback? onTitleTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        IconButton(
          tooltip: context.l10n.moodPreviousMonth,
          icon: const Icon(Icons.chevron_left),
          onPressed: onPrevious,
        ),
        Expanded(
          child: InkWell(
            borderRadius: prismCorners(context, 8),
            onTap: onTitleTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                DateFormat.yMMMM(context.dateLocale).format(month),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: context.l10n.moodNextMonth,
          icon: const Icon(Icons.chevron_right),
          onPressed: onNext,
        ),
        ?trailing,
      ],
    );
  }
}
