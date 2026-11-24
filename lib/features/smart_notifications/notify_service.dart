import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/core/services/local_notification_service.dart';
import 'package:prism_plurality/domain/models/calendar_event.dart';
import 'package:prism_plurality/domain/models/contact.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/astro/content/horoscope.dart';
import 'package:prism_plurality/features/astro/content/zodiac.dart';
import 'package:prism_plurality/features/astro/data/astro_model.dart';
import 'package:prism_plurality/features/astro/engine/events.dart';
import 'package:prism_plurality/features/calendar/providers/calendar_providers.dart';
import 'package:prism_plurality/features/contacts/providers/contact_providers.dart';
import 'package:prism_plurality/features/fronting_roles/roles_data.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/smart_notifications/notify_data.dart';

/// Notification ids 4,100,000–4,100,039 (clear of habits, fronting and
/// reminders). Kept small: iOS holds only 64 pending notifications in total.
const _idBase = 4100000;
const _maxScheduled = 40;

final _birthdayRe = RegExp(r"(['’]s)?\s*birthday", caseSensitive: false);

/// Everyone with a birthday the settings could remind about.
List<BirthdayItem> collectBirthdays({
  required NotifySettings settings,
  required List<Member> members,
  required List<Contact> contacts,
  required List<CalendarEvent> events,
  required bool preferDisplayName,
}) {
  final out = <BirthdayItem>[];
  for (final m in members) {
    final d = parseAnyBirthday(m.birthday);
    if (d != null)
      out.add(
        BirthdayItem(
          'm:${m.id}',
          m.effectiveName(preferDisplayName: preferDisplayName),
          d,
          BirthdaySource.alters,
        ),
      );
  }
  final sys = parseAnyBirthday(settings.systemBirthday);
  if (sys != null)
    out.add(
      BirthdayItem(
        'system',
        settings.systemBirthdayLabel,
        sys,
        BirthdaySource.system,
      ),
    );
  for (final c in contacts) {
    final d = parseAnyBirthday(c.birthday);
    if (d != null)
      out.add(
        BirthdayItem('c:${c.id}', c.displayName, d, BirthdaySource.contacts),
      );
  }
  for (final e in events) {
    final cat = (e.category ?? '').toLowerCase();
    if (!cat.contains('birthday') && !_birthdayRe.hasMatch(e.title)) continue;
    final name = e.title.replaceAll(_birthdayRe, '').trim();
    out.add(
      BirthdayItem(
        'e:${e.id}',
        name.isEmpty ? e.title : name,
        DateTime(e.startAt.year, e.startAt.month, e.startAt.day),
        BirthdaySource.calendar,
      ),
    );
  }
  return out;
}

DateTime _at(DateTime day, int minutes) =>
    DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);

/// Horoscope and Moon notifications for whoever is Primary. One per day at
/// most, so changing who fronts never doubles them up.
List<PlannedNotification> planSkyNotifications({
  required NotifySettings settings,
  required AstroAccess? primary,
  required DateTime now,
}) {
  final out = <PlannedNotification>[];
  final today = DateTime(now.year, now.month, now.day);
  final subject = primary != null && primary.canView ? primary.subject : null;
  final payload = primary == null ? null : 'prism:astro:${primary.member.id}';
  if (subject != null && settings.horoscopeDaily) {
    for (var i = 0; i < 7; i++) {
      final day = today.add(Duration(days: i));
      final when = applyQuietHours(
        _at(day, settings.horoscopeMinutes),
        settings,
      );
      if (!when.isAfter(now)) continue;
      try {
        final r = dailyReading(subject, day, false);
        final text =
            r.parts[ReadingPart.overall] ?? r.parts[ReadingPart.message] ?? '';
        out.add(
          PlannedNotification(
            key: 'horo:${day.toIso8601String().substring(0, 10)}',
            when: when,
            title: '🔮 ${primary!.name}: ${r.title}',
            body: text,
            category: NotifyCategory.horoscope,
            payload: payload,
          ),
        );
      } catch (_) {}
    }
  }
  if (subject != null && settings.horoscopeWeekly) {
    var monday = today;
    while (monday.weekday != DateTime.monday) {
      monday = monday.add(const Duration(days: 1));
    }
    for (final start in [monday, monday.add(const Duration(days: 7))]) {
      final when = applyQuietHours(
        _at(start, settings.horoscopeMinutes),
        settings,
      );
      if (!when.isAfter(now)) continue;
      try {
        final w = weeklyReading(subject, start, false);
        out.add(
          PlannedNotification(
            key: 'horoweek:${start.toIso8601String().substring(0, 10)}',
            when: when.add(const Duration(minutes: 1)),
            title: '✨ ${primary!.name}\'s week ahead',
            body: w.summary,
            category: NotifyCategory.horoscope,
            payload: payload,
          ),
        );
      } catch (_) {}
    }
  }
  if (settings.moonPhases) {
    try {
      for (final l in lunations(
        now.toUtc(),
        now.add(const Duration(days: 21)).toUtc(),
      )) {
        if (l.phase != MoonPhase.newMoon && l.phase != MoonPhase.fullMoon)
          continue;
        final local = l.utc.toLocal();
        final when = applyQuietHours(
          _at(local, settings.horoscopeMinutes),
          settings,
        );
        if (!when.isAfter(now)) continue;
        final isNew = l.phase == MoonPhase.newMoon;
        out.add(
          PlannedNotification(
            key: 'moon:${local.toIso8601String().substring(0, 10)}',
            when: when.add(const Duration(minutes: 2)),
            title:
                '${isNew ? '🌑 New Moon' : '🌕 Full Moon'} in ${signs[l.sign].name.of(false)}',
            body: isNew
                ? 'A fresh start — a good day to set an intention.'
                : 'A time to notice what has grown, and let something go.',
            category: NotifyCategory.moon,
            payload: payload,
          ),
        );
      }
    } catch (_) {}
  }
  return out;
}

class SmartNotificationService {
  SmartNotificationService(this._local);
  final LocalNotificationService _local;
  int _generation = 0;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'prism_moments',
      'Birthdays, holidays & horoscopes',
      channelDescription: 'Birthday reminders, holidays and daily horoscopes',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: DarwinNotificationDetails(),
    macOS: DarwinNotificationDetails(),
  );

  Future<void> apply(List<PlannedNotification> plan) async {
    if (kIsWeb) return;
    final gen = ++_generation;
    await _local.cancelRange(_idBase, _maxScheduled);
    if (gen != _generation) return;
    final items = plan.take(_maxScheduled).toList();
    for (var i = 0; i < items.length; i++) {
      if (gen != _generation) return;
      final p = items[i];
      await _local.scheduleOneShot(
        id: _idBase + i,
        title: p.title,
        body: p.body,
        scheduledFor: p.when,
        details: _details,
        payload: p.payload,
      );
    }
  }
}

final smartNotificationServiceProvider = Provider<SmartNotificationService>(
  (ref) =>
      SmartNotificationService(ref.watch(localNotificationServiceProvider)),
);

/// Everything that would be scheduled right now, soonest first.
final plannedNotificationsProvider = Provider<List<PlannedNotification>>((ref) {
  final settings = ref.watch(notifySettingsProvider);
  if (!settings.anyOn) return const [];
  final now = DateTime.now();
  final birthdays = collectBirthdays(
    settings: settings,
    members: ref.watch(userVisibleMembersProvider).value ?? const [],
    contacts: ref.watch(contactsProvider).value ?? const [],
    events: ref.watch(calendarEventsProvider).value ?? const [],
    preferDisplayName: ref.watch(memberNamePreferDisplayProvider),
  );
  final primaryId = (settings.horoscopeDaily || settings.horoscopeWeekly)
      ? ref.watch(primaryFronterIdProvider)
      : null;
  final primary = primaryId == null
      ? null
      : ref.watch(astroAccessProvider(primaryId));
  return dedupeAndSort([
    ...planCalendarNotifications(
      settings: settings,
      birthdays: birthdays,
      now: now,
    ),
    ...planSkyNotifications(settings: settings, primary: primary, now: now),
  ]);
});

/// Keeps the scheduled reminders in step with settings and data.
final smartNotificationListenerProvider = Provider<void>((ref) {
  final service = ref.watch(smartNotificationServiceProvider);
  Timer? debounce;
  ref.onDispose(() => debounce?.cancel());
  var lastSignature = '';
  void schedule(List<PlannedNotification> plan) {
    final sig = plan
        .take(_maxScheduled)
        .map((p) => '${p.key}@${p.when.millisecondsSinceEpoch}|${p.title}')
        .join(';');
    if (sig == lastSignature) return;
    debounce?.cancel();
    debounce = Timer(const Duration(seconds: 2), () {
      lastSignature = sig;
      service
          .apply(plan)
          .catchError(
            (Object e) => debugPrint(
              'Smart notification schedule failed (non-fatal): $e',
            ),
          );
    });
  }

  ref.listen(
    plannedNotificationsProvider,
    (_, next) => schedule(next),
    fireImmediately: true,
  );
});
