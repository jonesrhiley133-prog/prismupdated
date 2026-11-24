import 'package:intl/intl.dart' show DateFormat;

import 'package:prism_plurality/core/services/local_notification_service.dart';
import 'package:prism_plurality/features/members/utils/birthday.dart';
import 'package:prism_plurality/features/smart_notifications/holidays.dart';
import 'package:prism_plurality/features/smart_notifications/notify_data.dart';
import 'package:prism_plurality/features/smart_notifications/notify_service.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Settings → Notifications → Birthdays, holidays & horoscopes.
class NotifySettingsScreen extends ConsumerWidget {
  const NotifySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(notifySettingsProvider);
    final plan = ref.watch(plannedNotificationsProvider);
    void save(NotifySettings n) => saveNotifySettings(ref, n);
    final theme = Theme.of(context);

    Widget timeRow(String label, int minutes, void Function(int) onPick) =>
        Builder(
          builder: (rowContext) => PrismListRow(
            title: Text(label),
            trailing: Text(
              _fmtMinutes(context, minutes),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () async {
              final t = await showPrismTimePicker(
                context: context,
                anchorContext: rowContext,
                initialTime: TimeOfDay(
                  hour: minutes ~/ 60,
                  minute: minutes % 60,
                ),
              );
              if (t != null) onPick(t.hour * 60 + t.minute);
            },
          ),
        );

    return PrismPageScaffold(
      topBar: const PrismTopBar(title: 'Birthdays, holidays & horoscopes'),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + NavBarInset.of(context)),
          children: [
            // ── Birthdays
            const PrismSectionHeader(title: 'BIRTHDAYS'),
            PrismSurface(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  PrismSwitchRow(
                    title: 'Birthday reminders',
                    subtitle:
                        'For alters, the system, contacts and birthday events.',
                    value: s.birthdaysOn,
                    onChanged: (v) => save(s.copyWith(birthdaysOn: v)),
                  ),
                  if (s.birthdaysOn) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final (d, label) in const [
                              (7, '1 week before'),
                              (3, '3 days before'),
                              (1, 'Day before'),
                              (0, 'On the day'),
                            ])
                              PrismChip(
                                label: label,
                                selected: s.birthdayOffsets.contains(d),
                                onTap: () => save(
                                  s.copyWith(
                                    birthdayOffsets: _toggle(
                                      s.birthdayOffsets,
                                      d,
                                    ),
                                  ),
                                ),
                              ),
                            for (final d in s.birthdayOffsets.where(
                              (d) => !const {0, 1, 3, 7}.contains(d),
                            ))
                              PrismChip(
                                label: '$d days before',
                                selected: true,
                                onTap: () => save(
                                  s.copyWith(
                                    birthdayOffsets: _toggle(
                                      s.birthdayOffsets,
                                      d,
                                    ),
                                  ),
                                ),
                              ),
                            PrismChip(
                              label: 'Custom…',
                              selected: false,
                              onTap: () async {
                                final d = await _askDays(context);
                                if (d != null)
                                  save(
                                    s.copyWith(
                                      birthdayOffsets: {
                                        ...s.birthdayOffsets,
                                        d,
                                      },
                                    ),
                                  );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    for (final src in BirthdaySource.values)
                      PrismSwitchRow(
                        title: src.label,
                        value: s.birthdaySources.contains(src),
                        onChanged: (_) => save(
                          s.copyWith(
                            birthdaySources: _toggle(s.birthdaySources, src),
                          ),
                        ),
                      ),
                    timeRow(
                      'Reminder time',
                      s.birthdayMinutes,
                      (m) => save(s.copyWith(birthdayMinutes: m)),
                    ),
                    Builder(
                      builder: (rowContext) {
                        final sys = parseAnyBirthday(s.systemBirthday);
                        return PrismListRow(
                          title: const Text('System birthday'),
                          subtitle: Text(
                            sys == null
                                ? 'Not set — e.g. the day you formed or found each other'
                                : _fmtBirthday(sys),
                          ),
                          trailing: sys == null
                              ? const Icon(Icons.add)
                              : IconButton(
                                  tooltip: 'Clear',
                                  icon: const Icon(Icons.close),
                                  onPressed: () => save(
                                    s.copyWith(clearSystemBirthday: true),
                                  ),
                                ),
                          onTap: () async {
                            final d = await showPrismDatePicker(
                              context: context,
                              anchorContext: rowContext,
                              initialDate:
                                  sys != null && !isBirthdayYearHidden(sys)
                                  ? sys
                                  : DateTime.now(),
                              firstDate: DateTime(1900),
                              lastDate: DateTime.now(),
                            );
                            if (d != null)
                              save(
                                s.copyWith(
                                  systemBirthday: formatBirthdayWire(d),
                                ),
                              );
                          },
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),

            // ── Holidays
            const PrismSectionHeader(title: 'HOLIDAYS'),
            PrismSurface(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  PrismSwitchRow(
                    title: 'Holiday notifications',
                    subtitle:
                        'A note on the morning of each holiday you choose.',
                    value: s.holidaysOn,
                    onChanged: (v) => save(s.copyWith(holidaysOn: v)),
                  ),
                  if (s.holidaysOn) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: PrismSelect<String>(
                        labelText: 'Country',
                        value: s.country,
                        items: [
                          for (final e in holidayCountries.entries)
                            PrismSelectItem(value: e.key, label: e.value),
                        ],
                        onChanged: (v) {
                          if (v != null) save(s.copyWith(country: v));
                        },
                      ),
                    ),
                    for (final c in HolidayCategory.values)
                      PrismSwitchRow(
                        title: '${c.emoji} ${c.label}',
                        value: s.holidayCategories.contains(c),
                        onChanged: (_) => save(
                          s.copyWith(
                            holidayCategories: _toggle(s.holidayCategories, c),
                          ),
                        ),
                      ),
                    timeRow(
                      'Notification time',
                      s.holidayMinutes,
                      (m) => save(s.copyWith(holidayMinutes: m)),
                    ),
                    PrismListRow(
                      title: const Text('Choose individual holidays'),
                      subtitle: Text('${s.disabledHolidays.length} turned off'),
                      showChevron: true,
                      onTap: () =>
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const _HolidayPickerScreen(),
                            ),
                          ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Horoscopes
            const PrismSectionHeader(title: 'HOROSCOPES'),
            PrismSurface(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  PrismSwitchRow(
                    title: 'Daily horoscope',
                    subtitle:
                        "For whoever is Primary. One a day — switching fronters won't send another.",
                    value: s.horoscopeDaily,
                    onChanged: (v) => save(s.copyWith(horoscopeDaily: v)),
                  ),
                  PrismSwitchRow(
                    title: 'Weekly horoscope',
                    subtitle: 'Monday mornings.',
                    value: s.horoscopeWeekly,
                    onChanged: (v) => save(s.copyWith(horoscopeWeekly: v)),
                  ),
                  PrismSwitchRow(
                    title: 'New & Full Moons',
                    value: s.moonPhases,
                    onChanged: (v) => save(s.copyWith(moonPhases: v)),
                  ),
                  if (s.horoscopeDaily || s.horoscopeWeekly || s.moonPhases)
                    timeRow(
                      'Notification time',
                      s.horoscopeMinutes,
                      (m) => save(s.copyWith(horoscopeMinutes: m)),
                    ),
                ],
              ),
            ),

            // ── Quiet hours
            const PrismSectionHeader(title: 'QUIET HOURS'),
            PrismSurface(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  PrismSwitchRow(
                    title: 'Quiet hours',
                    subtitle:
                        'Anything due in this window waits until it ends.',
                    value: s.quietOn,
                    onChanged: (v) => save(s.copyWith(quietOn: v)),
                  ),
                  if (s.quietOn) ...[
                    timeRow(
                      'From',
                      s.quietStart,
                      (m) => save(s.copyWith(quietStart: m)),
                    ),
                    timeRow(
                      'Until',
                      s.quietEnd,
                      (m) => save(s.copyWith(quietEnd: m)),
                    ),
                  ],
                ],
              ),
            ),

            // ── Preview
            const PrismSectionHeader(title: 'COMING UP'),
            PrismSurface(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: plan.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Nothing scheduled in the next three weeks.'),
                    )
                  : Column(
                      children: [
                        for (final p in plan.take(12))
                          PrismListRow(
                            dense: true,
                            title: Text(
                              p.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(_fmtWhen(context, p.when)),
                          ),
                        if (plan.length > 12)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              '+${plan.length - 12} more',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            Center(
              child: PrismButton(
                label: 'Allow notifications',
                icon: Icons.notifications_active_outlined,
                tone: PrismButtonTone.subtle,
                onPressed: () async {
                  final ok = await ref
                      .read(localNotificationServiceProvider)
                      .requestPermission();
                  if (context.mounted)
                    PrismToast.show(
                      context,
                      message: ok
                          ? 'Notifications are on'
                          : 'Notifications are off for Prism in system settings',
                    );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Set<T> _toggle<T>(Set<T> s, T v) =>
    s.contains(v) ? ({...s}..remove(v)) : {...s, v};

String _fmtMinutes(BuildContext context, int m) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay(hour: m ~/ 60, minute: m % 60),
      alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
    );

String _fmtBirthday(DateTime d) => isBirthdayYearHidden(d)
    ? DateFormat.MMMMd().format(DateTime(2000, d.month, d.day))
    : DateFormat.yMMMMd().format(d);

String _fmtWhen(BuildContext context, DateTime t) =>
    '${DateFormat.MMMEd().format(t)} · ${_fmtMinutes(context, t.hour * 60 + t.minute)}';

Future<int?> _askDays(BuildContext context) async {
  final controller = TextEditingController();
  final result = await PrismDialog.show<int>(
    context: context,
    title: 'Days before',
    builder: (ctx) => PrismTextField(
      controller: controller,
      keyboardType: TextInputType.number,
      autofocus: true,
      hintText: 'e.g. 14',
    ),
    actions: [
      PrismButton(
        label: 'Cancel',
        tone: PrismButtonTone.subtle,
        onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
      ),
      PrismButton(
        label: 'Add',
        onPressed: () {
          final n = int.tryParse(controller.text.trim());
          Navigator.of(
            context,
            rootNavigator: true,
          ).pop(n == null || n < 1 || n > 60 ? null : n);
        },
      ),
    ],
  );
  controller.dispose();
  return result;
}

class _HolidayPickerScreen extends ConsumerWidget {
  const _HolidayPickerScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(notifySettingsProvider);
    final now = DateTime.now();
    final year = holidaysBetween(
      now,
      now.add(const Duration(days: 366)),
      country: s.country,
      categories: s.holidayCategories.isEmpty
          ? HolidayCategory.values.toSet()
          : s.holidayCategories,
    );
    return PrismPageScaffold(
      topBar: const PrismTopBar(title: 'Holidays', showBackButton: true),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + NavBarInset.of(context)),
          children: [
            PrismSurface(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final (h, d) in year)
                    PrismSwitchRow(
                      title: '${h.emoji} ${h.name}',
                      subtitle:
                          '${DateFormat.MMMEd().format(d)}${h.approximate ? ' (approx.)' : ''} · ${h.category.label}',
                      value: !s.disabledHolidays.contains(h.id),
                      onChanged: (_) => saveNotifySettings(
                        ref,
                        s.copyWith(
                          disabledHolidays: _toggle(s.disabledHolidays, h.id),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
