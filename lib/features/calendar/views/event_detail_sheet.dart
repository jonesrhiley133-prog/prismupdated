import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/domain/models/calendar_event.dart';
import 'package:prism_plurality/features/calendar/providers/calendar_providers.dart';
import 'package:prism_plurality/features/calendar/utils/recurrence.dart';
import 'package:prism_plurality/features/calendar/views/edit_event_sheet.dart';
import 'package:prism_plurality/features/calendar/views/recurring_scope_dialog.dart';
import 'package:prism_plurality/features/calendar/widgets/calendar_colors.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/widgets/member_avatar.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_dialog.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_toast.dart';

Future<void> showEventDetailSheet(
  BuildContext context,
  CalendarOccurrence occurrence,
) {
  return PrismSheet.show(
    context: context,
    builder: (context) => EventDetailSheet(occurrence: occurrence),
  );
}

/// Read-only event details with edit / duplicate / delete actions.
class EventDetailSheet extends ConsumerWidget {
  const EventDetailSheet({super.key, required this.occurrence});

  final CalendarOccurrence occurrence;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final e = occurrence.event;
    final color = eventColor(context, e);
    final members = ref.watch(allMemberListProvider).value ?? const [];
    final prefer = ref.watch(memberNamePreferDisplayProvider);
    final attending = [
      for (final id in e.memberIds)
        ?members.firstWhereOrNull((m) => m.id == id),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 40,
                margin: const EdgeInsets.only(right: 12, top: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatOccurrenceWhen(context, occurrence),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (e.isRecurring)
            _InfoRow(
              icon: AppIcons.repeat,
              text: describeRecurrence(context, e),
            ),
          if (e.category != null)
            _InfoRow(icon: AppIcons.label, text: e.category!),
          if (e.location != null)
            _InfoRow(icon: AppIcons.locationOn, text: e.location!),
          if (e.alertMinutes.isNotEmpty)
            _InfoRow(
              icon: AppIcons.notificationsNoneRounded,
              text: e.alertMinutes
                  .map((m) => alertLabel(context, m))
                  .join(', '),
            ),
          if (attending.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in attending)
                  Chip(
                    avatar: MemberAvatar(
                      avatarImageData: m.avatarImageData,
                      memberName: m.effectiveName(preferDisplayName: prefer),
                      emoji: m.emoji,
                      customColorEnabled: m.customColorEnabled,
                      customColorHex: m.customColorHex,
                      size: 24,
                    ),
                    label: Text(m.effectiveName(preferDisplayName: prefer)),
                  ),
              ],
            ),
          ],
          if (e.description != null) ...[
            const SizedBox(height: 12),
            SelectableText(e.description!, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PrismButton(
                label: l10n.edit,
                icon: AppIcons.edit,
                tone: PrismButtonTone.filled,
                onPressed: () {
                  Navigator.of(context).pop();
                  showEditEventSheet(context, occurrence: occurrence);
                },
              ),
              PrismButton(
                label: l10n.calendarDuplicate,
                icon: AppIcons.copy,
                onPressed: () {
                  Navigator.of(context).pop();
                  showEditEventSheet(
                    context,
                    duplicateOf: e.copyWith(
                      startAt: occurrence.start,
                      endAt: occurrence.end,
                      recurrenceExceptions: const [],
                    ),
                  );
                },
              ),
              PrismButton(
                label: l10n.delete,
                icon: AppIcons.delete,
                tone: PrismButtonTone.destructive,
                onPressed: () => _delete(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final notifier = ref.read(calendarNotifierProvider.notifier);
    final navigator = Navigator.of(context);
    if (occurrence.event.isRecurring) {
      final scope = await showRecurringScopeDialog(
        context,
        title: l10n.calendarDeleteRecurringTitle,
      );
      if (scope == null) return;
      await notifier.deleteOccurrence(occurrence, scope);
    } else {
      final ok = await PrismDialog.confirm(
        context: context,
        title: l10n.calendarDeleteTitle,
        message: l10n.calendarDeleteMessage(occurrence.event.title),
        confirmLabel: l10n.delete,
        cancelLabel: l10n.cancel,
        destructive: true,
      );
      if (!ok) return;
      await notifier.delete(occurrence.event.id);
    }
    navigator.pop();
    if (context.mounted) {
      PrismToast.show(context, message: l10n.calendarDeletedToast);
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// "Tue, Nov 12 · 14:00 – 15:00" / "Nov 12 – Nov 14 · All day".
String formatOccurrenceWhen(BuildContext context, CalendarOccurrence o) {
  final l10n = context.l10n;
  final day = DateFormat.MMMEd(context.dateLocale);
  if (o.isAllDay) {
    final sameDay = calendarDateKey(o.start) == calendarDateKey(o.end);
    final dates = sameDay
        ? day.format(o.start)
        : '${day.format(o.start)} – ${day.format(o.end)}';
    return '$dates · ${l10n.calendarAllDay}';
  }
  final sameDay = calendarDateKey(o.start) == calendarDateKey(o.end);
  if (sameDay) {
    return '${day.format(o.start)} · ${context.formatTime(o.start)} – '
        '${context.formatTime(o.end)}';
  }
  return '${day.format(o.start)} ${context.formatTime(o.start)} – '
      '${day.format(o.end)} ${context.formatTime(o.end)}';
}

/// "Every 2 weeks on Mon, Wed · until Dec 31" style summary.
String describeRecurrence(BuildContext context, CalendarEvent e) {
  final l10n = context.l10n;
  final parts = <String>[
    recurrenceUnitLabel(context, e.recurrence, e.recurrenceInterval),
  ];
  if (e.recurrence == CalendarRecurrence.weekly &&
      e.recurrenceWeekdays.isNotEmpty) {
    final fmt = DateFormat.E(context.dateLocale);
    // 2023-01-01 was a Sunday, so day index d maps to Jan 1 + d.
    parts.add(
      e.recurrenceWeekdays
          .map((d) => fmt.format(DateTime(2023, 1, 1 + d)))
          .join(', '),
    );
  }
  if (e.recurrenceUntil != null) {
    parts.add(
      l10n.calendarUntilDate(
        DateFormat.yMMMd(context.dateLocale).format(e.recurrenceUntil!),
      ),
    );
  } else if (e.recurrenceCount != null) {
    parts.add(l10n.calendarTimesCount(e.recurrenceCount!));
  }
  return parts.join(' · ');
}
