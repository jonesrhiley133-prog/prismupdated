import 'dart:async';

import 'package:prism_plurality/shared/theme/prism_shapes.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:prism_plurality/features/calendar/utils/recurrence.dart';
import 'package:prism_plurality/features/calendar/views/event_detail_sheet.dart';
import 'package:prism_plurality/features/calendar/widgets/calendar_colors.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';

/// Hour-by-hour grid for one or more days (day and week views).
///
/// Timed occurrences are positioned by time and laid out side by side when
/// they overlap. All-day occurrences are not drawn here; callers show them
/// in an all-day lane above.
class TimeGrid extends StatefulWidget {
  const TimeGrid({
    super.key,
    required this.days,
    required this.occurrencesForDay,
    required this.onCreateAt,
    this.hourHeight = 52,
    this.initialHour = 7.5,
  });

  final List<DateTime> days;
  final List<CalendarOccurrence> Function(DateTime day) occurrencesForDay;
  final ValueChanged<DateTime> onCreateAt;
  final double hourHeight;
  final double initialHour;

  static const gutterWidth = 48.0;

  @override
  State<TimeGrid> createState() => _TimeGridState();
}

class _TimeGridState extends State<TimeGrid> {
  late final ScrollController _scroll = ScrollController(
    initialScrollOffset: widget.initialHour * widget.hourHeight,
  );
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Keep the "now" line moving.
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hourH = widget.hourHeight;
    final now = DateTime.now();
    final labelFormat = context.use24HourTime
        ? DateFormat.H(context.dateLocale)
        : DateFormat.j(context.dateLocale);

    return SingleChildScrollView(
      controller: _scroll,
      child: SizedBox(
        height: hourH * 24 + 8,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final dayWidth =
                (constraints.maxWidth - TimeGrid.gutterWidth) /
                widget.days.length;
            return Stack(
              children: [
                // Hour lines and labels.
                for (var h = 0; h < 24; h++) ...[
                  Positioned(
                    top: h * hourH,
                    left: 0,
                    width: TimeGrid.gutterWidth - 6,
                    child: Transform.translate(
                      offset: const Offset(0, -7),
                      child: h == 0
                          ? const SizedBox.shrink()
                          : Text(
                              labelFormat.format(DateTime(2000, 1, 1, h)),
                              textAlign: TextAlign.right,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                    ),
                  ),
                  Positioned(
                    top: h * hourH,
                    left: TimeGrid.gutterWidth,
                    right: 0,
                    child: Divider(
                      height: 1,
                      color: theme.colorScheme.outline.withValues(alpha: 0.15),
                    ),
                  ),
                ],
                for (var i = 0; i < widget.days.length; i++) ...[
                  // Tap empty space to create an event at that half hour.
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: TimeGrid.gutterWidth + i * dayWidth,
                    width: dayWidth,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTapUp: (d) {
                        final minutes =
                            ((d.localPosition.dy / hourH) * 60 / 30).floor() *
                            30;
                        final day = widget.days[i];
                        widget.onCreateAt(
                          DateTime(day.year, day.month, day.day, 0, minutes),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  ..._eventBlocks(
                    context,
                    widget.days[i],
                    left: TimeGrid.gutterWidth + i * dayWidth,
                    width: dayWidth,
                  ),
                  if (_sameDay(widget.days[i], now))
                    Positioned(
                      top: (now.hour + now.minute / 60) * hourH - 1,
                      left: TimeGrid.gutterWidth + i * dayWidth - 4,
                      width: dayWidth + 4,
                      child: IgnorePointer(
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.error,
                                borderRadius: prismRound(context),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 2,
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _eventBlocks(
    BuildContext context,
    DateTime day, {
    required double left,
    required double width,
  }) {
    final hourH = widget.hourHeight;
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = DateTime(day.year, day.month, day.day + 1);
    final timed = widget
        .occurrencesForDay(day)
        .where((o) => !o.isAllDay)
        .toList();
    final layout = layoutDayColumns(timed);
    final compact = width < 70;

    return [
      for (final o in timed)
        Builder(
          builder: (context) {
            final start = o.start.isBefore(dayStart) ? dayStart : o.start;
            final end = o.endExclusive.isAfter(dayEnd)
                ? dayEnd
                : o.endExclusive;
            final top = start.difference(dayStart).inMinutes / 60 * hourH;
            final height = (end.difference(start).inMinutes / 60 * hourH).clamp(
              18.0,
              hourH * 24,
            );
            final (col, cols) = layout[o] ?? (0, 1);
            final colWidth = (width - 4) / cols;
            final color = eventColor(context, o.event);
            final fg = onEventColor(color);
            return Positioned(
              top: top + 1,
              left: left + 2 + col * colWidth,
              width: colWidth - 2,
              height: height - 2,
              child: Material(
                color: color.withValues(alpha: 0.9),
                borderRadius: prismCorners(context, 6),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => showEventDetailSheet(context, o),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          o.event.title,
                          maxLines: height > 40 ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: fg,
                            fontSize: compact ? 10 : 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (height > 34 && !compact)
                          Text(
                            '${context.formatTime(o.start)} – '
                            '${context.formatTime(o.end)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: fg.withValues(alpha: 0.85),
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
    ];
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
