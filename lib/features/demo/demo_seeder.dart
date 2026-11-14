import 'dart:math' as math;

import 'package:drift/drift.dart' show Batch;
import 'package:uuid/uuid.dart';

import 'package:prism_plurality/core/database/app_database.dart' hide Member, FrontingSession, Habit, HabitCompletion;
import 'package:prism_plurality/core/database/database_provider.dart';
import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/data/mappers/calendar_event_mapper.dart';
import 'package:prism_plurality/data/mappers/fronting_session_mapper.dart';
import 'package:prism_plurality/data/mappers/habit_completion_mapper.dart';
import 'package:prism_plurality/data/mappers/habit_mapper.dart';
import 'package:prism_plurality/data/mappers/location_session_mapper.dart';
import 'package:prism_plurality/data/mappers/member_mapper.dart';
import 'package:prism_plurality/data/mappers/mood_entry_mapper.dart';
import 'package:prism_plurality/data/mappers/saved_location_mapper.dart';
import 'package:prism_plurality/data/mappers/tracker_record_mapper.dart';
import 'package:prism_plurality/domain/models/calendar_event.dart';
import 'package:prism_plurality/domain/models/fronting_session.dart';
import 'package:prism_plurality/domain/models/habit.dart';
import 'package:prism_plurality/domain/models/habit_completion.dart';
import 'package:prism_plurality/domain/models/location.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/domain/models/mood_entry.dart';
import 'package:prism_plurality/features/scrapbook/scrap_models.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

const _uuid = Uuid();

/// Demo dataset lengths in days.
const demoDurations = {'1w': 7, '1m': 30, '6m': 182, '1y': 365, '3y': 1095};

class _Alter {
  _Alter(this.name, this.pronouns, this.emoji, this.age, this.color, this.bio, this.role);
  final String name, pronouns, emoji, age, bio, role;
  final String color;
  final String id = _uuid.v4();
}

/// Fills the (empty) demo database with realistic, interlinked sample data.
class DemoSeeder {
  DemoSeeder(this.ref, {required this.days, this.seed = 42, this.onProgress});
  final WidgetRef ref;
  final int days;
  final int seed;
  final void Function(double progress, String step)? onProgress;

  late final math.Random _r = math.Random(seed);
  final _members = <MembersCompanion>[];
  final _sessions = <FrontingSessionsCompanion>[];
  final _moods = <MoodEntriesCompanion>[];
  final _events = <CalendarEventsCompanion>[];
  final _places = <SavedLocationsCompanion>[];
  final _visits = <LocationSessionsCompanion>[];
  final _tracker = <TrackerRecordsCompanion>[];
  final _habits = <HabitsCompanion>[];
  final _habitDone = <HabitCompletionsCompanion>[];

  T _pick<T>(List<T> xs) => xs[_r.nextInt(xs.length)];
  bool _chance(double p) => _r.nextDouble() < p;
  int _between(int a, int b) => a + _r.nextInt(b - a + 1);

  TrackerRecord _rec(String kind, {String title = '', String? body, String? parentId, Map<String, Object?> fields = const {}, List<String> tags = const [], DateTime? at, DateTime? ended, int? amount, String? memberId, bool private = false, int sort = 0}) {
    final t = at ?? DateTime.now();
    final r = TrackerRecord(
      id: _uuid.v4(),
      kind: kind,
      parentId: parentId,
      title: title,
      body: body,
      tags: tags,
      occurredAt: at,
      endedAt: ended,
      amount: amount,
      memberId: memberId,
      isPrivate: private,
      sortOrder: sort,
      createdAt: t,
      modifiedAt: t,
    ).withFields({...fields, 'demo': true});
    _tracker.add(TrackerRecordMapper.toCompanion(r));
    return r;
  }

  void _link(String a, String b, String cat, DateTime at) => _rec(TrackerKind.linkEdge, fields: {'a': a, 'b': b, 'cat': cat}, at: at);

  Future<void> run() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));
    final alters = [
      _Alter('Juniper', 'she/her', '🌿', '27', '#5E9E6E', 'Host. Loves tea, long walks and organising things into tidy lists.', 'Host'),
      _Alter('Kai', 'he/they', '🛡️', '24', '#4E79A7', 'Protector. Handles work, phone calls and anything stressful.', 'Protector'),
      _Alter('Mira', 'she/her', '🧸', '7', '#F28E2B', 'Little. Likes stickers, cartoons and colouring. Gentle voices please!', 'Little'),
      _Alter('Rowan', 'they/them', '🗝️', 'unknown', '#76B7B2', 'Gatekeeper. Quiet, observant, keeps track of who is around.', 'Gatekeeper'),
      _Alter('Sol', 'he/him', '☀️', '30', '#EDC948', 'Caretaker. Cooks, reminds everyone to drink water.', 'Caretaker'),
      _Alter('Ash', 'they/she', '🔥', '19', '#E15759', 'Protector with a sharp tongue and a soft heart.', 'Protector'),
      _Alter('Wren', 'she/they', '🎨', '22', '#B07AA1', 'Artist. Draws, paints and fills the scrapbook.', 'Artist'),
    ];
    onProgress?.call(0.02, 'alters');
    for (final (i, a) in alters.indexed) {
      _members.add(MemberMapper.toCompanion(Member(
        id: a.id,
        name: a.name,
        pronouns: a.pronouns,
        emoji: a.emoji,
        age: a.age,
        bio: a.bio,
        customColorEnabled: true,
        customColorHex: a.color,
        displayOrder: i,
        createdAt: start.subtract(const Duration(days: 30)),
      )));
    }
    final byName = {for (final a in alters) a.name: a};

    // Places.
    final places = [('Home', '🏠'), ('Work', '💼'), ('Café', '☕'), ('Park', '🌳'), ('Therapy', '🛋️')];
    final placeIds = <String, String>{};
    for (final (i, (name, emoji)) in places.indexed) {
      final id = _uuid.v4();
      placeIds[name] = id;
      _places.add(SavedLocationMapper.toCompanion(SavedLocation(id: id, name: name, emoji: emoji, sortOrder: i, isFavorite: i < 2, createdAt: start, modifiedAt: start)));
    }

    // Recurring therapy and a few one-off events.
    final therapyStart = DateTime(start.year, start.month, start.day + ((DateTime.thursday - start.weekday) % 7), 16);
    final therapy = CalendarEvent(
      id: _uuid.v4(),
      title: 'Therapy',
      location: 'Therapy',
      startAt: therapyStart,
      endAt: therapyStart.add(const Duration(minutes: 50)),
      recurrence: CalendarRecurrence.weekly,
      colorHex: '#8E7CC3',
      category: 'Health',
      memberIds: [byName['Juniper']!.id, byName['Kai']!.id],
      createdAt: start,
      modifiedAt: start,
    );
    _events.add(CalendarEventMapper.toCompanion(therapy));

    // Fixed records referenced later.
    final garden = _rec(TrackerKind.subsystem, title: 'The Garden', body: 'A sunny inner space where Mira and Wren spend most of their time.', at: start, fields: {'members': [byName['Mira']!.id, byName['Wren']!.id], 'color': 0xFF5E9E6E});
    _rec(TrackerKind.nutriSettings, fields: {'unit': 'ml', 'goalMl': 2000, 'metrics': ['kcal', 'protein', 'carbs', 'fat'], 'calendar': true, 'reminders': false, 'prefs': 'Warm breakfasts help mornings. Mira likes pancakes; Kai skips lunch when stressed.', 'restrictions': ['vegetarian'], 'sensitivities': ['lactose']}, at: start);

    // Habits with several completions a day.
    final routine = _rec(TrackerKind.habitGroup, title: 'Daily self-care', fields: {'habits': <String>[]}, at: start);
    final demoHabits = [
      ('Drink water', '💧', 8, 'glass', HabitFrequency.daily, null, 'nutri.drink'),
      ('Practice', '🎵', 3, 'session', HabitFrequency.weekly, [1, 2, 3, 4, 5], null),
      ('Take meds', '💊', 2, 'dose', HabitFrequency.daily, null, null),
      ('Stretch', '🧘', 1, null, HabitFrequency.daily, null, null),
    ];
    final habitIds = <String>[];
    for (final (name, icon, target, label, freq, days, auto) in demoHabits) {
      final id = _uuid.v4();
      habitIds.add(id);
      _habits.add(HabitMapper.toCompanion(Habit(id: id, name: name, icon: icon, frequency: freq, weeklyDays: days, createdAt: start, modifiedAt: start)));
      _rec(TrackerKind.habitMeta, parentId: id, at: start, fields: {
        'target': target,
        'unit': 'times',
        'unitLabel': ?label,
        'defaultMinutes': name == 'Practice' ? 25 : 10,
        'group': routine.id,
        'autoLog': ?auto,
        if (name == 'Practice') 'recovery': ['6', '7'],
      });
    }

    // Per-day simulation.
    final weights = {
      'Juniper': 5.0, 'Kai': 3.5, 'Mira': 1.2, 'Rowan': 0.8, 'Sol': 1.6, 'Ash': 1.0, 'Wren': 1.5,
    };
    final foods = [
      ('Porridge with berries', 'breakfast', 320, 9), ('Toast and peanut butter', 'breakfast', 380, 14), ('Pancakes', 'breakfast', 450, 10), ('Yoghurt and granola', 'breakfast', 300, 12),
      ('Veggie wrap', 'lunch', 520, 18), ('Lentil soup', 'lunch', 410, 22), ('Pasta salad', 'lunch', 560, 15), ('Cheese sandwich', 'lunch', 480, 20),
      ('Stir-fry with tofu', 'dinner', 610, 28), ('Vegetable curry', 'dinner', 650, 18), ('Mac and cheese', 'dinner', 700, 24), ('Bean chilli', 'dinner', 590, 26), ('Pizza night', 'dinner', 820, 30),
      ('Apple', 'snack', 95, 0), ('Biscuits', 'snack', 210, 3), ('Crisps', 'snack', 160, 2), ('Hot chocolate', 'snack', 230, 6),
    ];
    final journalTitles = ['Rough morning, better afternoon', 'Notes from therapy', 'Small wins', 'Who was here today', 'A quiet evening', 'Work was a lot', 'Garden time', 'Things we want to remember', 'Letter to the system', 'Grateful for'];
    final dreamThemes = ['water', 'house', 'school', 'falling', 'being chased', 'forest', 'flying', 'lost', 'train', 'old friends'];
    final dreamSymbols = ['keys', 'doors', 'stairs', 'ocean', 'a red bird', 'mirrors', 'a lighthouse', 'clocks'];
    final emotionsGood = ['happy', 'calm', 'grateful', 'proud', 'content'];
    final emotionsBad = ['anxious', 'sad', 'tired', 'overwhelmed', 'frustrated'];
    var lastJournal = start;
    for (var di = 0; di < days; di++) {
      final day = start.add(Duration(days: di));
      if (di % 7 == 0) {
        onProgress?.call(0.05 + 0.75 * di / days, 'history');
        // Let the screen draw between weeks of generated history; doing
        // years in one go blocked the app for several seconds.
        await Future<void>.delayed(Duration.zero);
      }
      final weekend = day.weekday >= 6;
      // Sleep for the night before this day.
      final bed = day.subtract(Duration(minutes: 60 + _between(0, 120)));
      final sleepHours = 5.5 + _r.nextDouble() * 3.5;
      final wake = bed.add(Duration(minutes: (sleepHours * 60).round()));
      final quality = sleepHours > 8 ? SleepQuality.good : sleepHours > 7 ? (_chance(0.6) ? SleepQuality.good : SleepQuality.fair) : sleepHours > 6 ? SleepQuality.fair : SleepQuality.poor;
      _sessions.add(FrontingSessionMapper.toCompanion(FrontingSession(id: _uuid.v4(), startTime: bed, endTime: wake, sessionType: SessionType.sleep, quality: quality)));
      // Fronting through the day.
      var t = wake.add(Duration(minutes: _between(5, 40)));
      final endOfDay = DateTime(day.year, day.month, day.day, 23, _between(0, 40));
      final todaysFronters = <String>[];
      final w = Map.of(weights);
      if (!weekend) w['Kai'] = w['Kai']! * 1.8;
      if (weekend) {
        w['Mira'] = w['Mira']! * 2;
        w['Wren'] = w['Wren']! * 1.6;
      }
      if (sleepHours < 6.2) w['Ash'] = w['Ash']! * 2.5;
      String weighted() {
        final total = w.values.reduce((a, b) => a + b);
        var x = _r.nextDouble() * total;
        for (final e in w.entries) {
          x -= e.value;
          if (x <= 0) return e.key;
        }
        return 'Juniper';
      }

      String? previous;
      final daySessionIds = <String>[];
      while (t.isBefore(endOfDay)) {
        var name = weighted();
        if (name == previous) name = weighted();
        previous = name;
        final len = Duration(minutes: _between(45, 300));
        final end = t.add(len).isAfter(endOfDay) ? endOfDay : t.add(len);
        final isNow = di == days - 1 && end.isAfter(now);
        if (t.isAfter(now)) break;
        final sid = _uuid.v4();
        daySessionIds.add(sid);
        _sessions.add(FrontingSessionMapper.toCompanion(FrontingSession(
          id: sid,
          startTime: t,
          endTime: isNow ? null : end,
          memberId: byName[name]!.id,
          confidence: _chance(0.1) ? FrontConfidence.unsure : (_chance(0.5) ? FrontConfidence.certain : FrontConfidence.strong),
          notes: _chance(0.08) ? _pick(['Busy shift', 'Felt foggy', 'Good chat with a friend', 'Needed a break', 'Painting']) : null,
        )));
        todaysFronters.add(name);
        // Co-fronting.
        if (_chance(0.28)) {
          final partner = weighted();
          if (partner != name) {
            final cs = t.add(Duration(minutes: _between(0, len.inMinutes ~/ 2)));
            final ce = cs.add(Duration(minutes: _between(20, 110)));
            if (cs.isBefore(now)) {
              _sessions.add(FrontingSessionMapper.toCompanion(FrontingSession(
                id: _uuid.v4(),
                startTime: cs,
                endTime: ce.isAfter(now) ? null : ce,
                memberId: byName[partner]!.id,
                confidence: _chance(0.25) ? FrontConfidence.unsure : FrontConfidence.strong,
              )));
              todaysFronters.add(partner);
            }
          }
        }
        // Places.
        if (!weekend && name == 'Kai' && t.hour < 12 && _chance(0.7)) {
          _visits.add(LocationSessionMapper.toCompanion(LocationSession(id: _uuid.v4(), locationId: placeIds['Work']!, startedAt: t, endedAt: end.isAfter(now) ? null : end, createdAt: t, modifiedAt: t)));
        }
        if (weekend && _chance(0.3) && t.hour >= 10 && t.hour < 17) {
          final where = _pick(['Café', 'Park']);
          final ve = t.add(Duration(minutes: _between(40, 150)));
          if (ve.isBefore(now)) _visits.add(LocationSessionMapper.toCompanion(LocationSession(id: _uuid.v4(), locationId: placeIds[where]!, startedAt: t, endedAt: ve, createdAt: t, modifiedAt: t)));
        }
        t = end.add(Duration(minutes: _between(0, 10)));
      }
      if (day.weekday == DateTime.thursday && therapyStart.isBefore(day.add(const Duration(days: 1)))) {
        final ts = DateTime(day.year, day.month, day.day, 16);
        if (ts.isBefore(now)) _visits.add(LocationSessionMapper.toCompanion(LocationSession(id: _uuid.v4(), locationId: placeIds['Therapy']!, startedAt: ts, endedAt: ts.add(const Duration(minutes: 50)), createdAt: ts, modifiedAt: ts)));
      }

      // Hydration.
      var ml = 0;
      final drinks = _between(weekend ? 3 : 4, 9);
      for (var k = 0; k < drinks; k++) {
        final at = DateTime(day.year, day.month, day.day, 8 + (k * 14 ~/ drinks), _between(0, 59));
        if (at.isAfter(now)) break;
        final coffee = k == 0 && _chance(0.7);
        final amount = coffee ? 200 : _pick([250, 250, 330, 500]);
        ml += coffee ? 0 : amount;
        _rec(TrackerKind.nutriDrink, title: coffee ? 'Coffee' : (_chance(0.15) ? 'Tea' : 'Water'), fields: {'bev': coffee ? 'coffee' : 'water', 'ml': amount}, at: at, memberId: byName[todaysFronters.isEmpty ? 'Juniper' : _pick(todaysFronters)]!.id);
      }
      // Meals.
      for (final cat in ['breakfast', 'lunch', 'dinner', if (_chance(0.55)) 'snack']) {
        if (cat == 'lunch' && !weekend && todaysFronters.contains('Kai') && _chance(0.35)) continue; // Kai skips lunch
        final options = foods.where((f) => f.$2 == cat).toList();
        final f = _pick(options);
        final hour = switch (cat) {
          'breakfast' => 8,
          'lunch' => 13,
          'dinner' => 19,
          _ => 16,
        };
        final at = DateTime(day.year, day.month, day.day, hour, _between(0, 50));
        if (at.isAfter(now)) continue;
        final who = todaysFronters.isEmpty ? 'Juniper' : _pick(todaysFronters);
        _rec(TrackerKind.nutriMeal, title: f.$1, fields: {
          'cat': cat,
          'n': {'kcal': f.$3, 'protein': f.$4},
          if (_chance(0.3)) 'feel': _pick(['satisfied', 'energised', 'comforted', 'neutral', 'heavy']),
          if (who == 'Sol' && _chance(0.5)) 'members': [byName['Mira']!.id],
        }, at: at, memberId: byName[who]!.id);
      }
      // Mood check-ins, nudged by sleep, hydration and workdays.
      final checkins = _between(1, 3);
      for (var k = 0; k < checkins; k++) {
        final at = DateTime(day.year, day.month, day.day, 10 + k * 5, _between(0, 59));
        if (at.isAfter(now)) break;
        final who = todaysFronters.isEmpty ? 'Juniper' : _pick(todaysFronters);
        var base = 3.0 + (sleepHours - 7) * 0.45 + (ml - 1500) / 2500 + (weekend ? 0.3 : -0.15) + (who == 'Mira' ? 0.4 : 0) + (who == 'Ash' ? -0.5 : 0) + (_r.nextDouble() - 0.5) * 1.6;
        final mood = base.round().clamp(1, 5);
        _moods.add(MoodEntryMapper.toCompanion(MoodEntry(
          id: _uuid.v4(),
          memberId: byName[who]!.id,
          mood: mood,
          intensity: _between(3, 8),
          emotions: [for (var e = 0; e < _between(1, 2); e++) mood >= 3 ? _pick(emotionsGood) : _pick(emotionsBad)],
          energy: (mood + _between(-1, 1)).clamp(1, 5),
          stress: (6 - mood + _between(-1, 1)).clamp(1, 5),
          sleepQuality: k == 0 ? (sleepHours / 2).round().clamp(1, 5) : null,
          note: _chance(0.12) ? _pick(['Slept badly', 'Lovely walk', 'Work stress', 'Felt connected today', 'Headache']) : null,
          recordedAt: at,
          createdAt: at,
          modifiedAt: at,
        )));
      }
      // Habit completions (water, practice, meds, stretch).
      for (final (hi, (name, _, target, _, freq, days, _)) in demoHabits.indexed) {
        if (freq == HabitFrequency.weekly && !(days ?? const <int>[]).contains(day.weekday % 7)) continue;
        final n = _between((target * 0.4).round(), target + (name == 'Drink water' ? 1 : 0));
        for (var k = 0; k < n; k++) {
          final at = DateTime(day.year, day.month, day.day, 8 + (k * 13 ~/ math.max(1, n)), _between(0, 59));
          if (at.isAfter(now)) break;
          final who = todaysFronters.isEmpty ? 'Juniper' : _pick(todaysFronters);
          final cid = _uuid.v4();
          _habitDone.add(HabitCompletionMapper.toCompanion(HabitCompletion(
            id: cid,
            habitId: habitIds[hi],
            completedAt: at,
            completedByMemberId: byName[who]!.id,
            rating: name == 'Practice' ? _between(2, 5) : null,
            notes: name == 'Practice' && _chance(0.3) ? _pick(['Scales felt smoother', 'Learned a new bar', 'Hard focus today']) : null,
            createdAt: at,
            modifiedAt: at,
          )));
          if (name == 'Practice') _rec(TrackerKind.habitLog, parentId: cid, at: at, memberId: byName[who]!.id, fields: {'habitId': habitIds[hi], 'minutes': _pick([20, 25, 30, 40])});
        }
      }
      // Activity.
      if (_chance(0.28)) {
        final at = DateTime(day.year, day.month, day.day, 18, 0);
        if (at.isBefore(now)) _rec(TrackerKind.fitnessWorkout, title: _pick(['Walk', 'Yoga', 'Swim', 'Cycling']), fields: {'minutes': _between(20, 70)}, at: at, memberId: byName[_pick(['Juniper', 'Sol', 'Kai'])]!.id);
      }
      // Journal (about every 2–3 days), linked to its author and session.
      if (day.difference(lastJournal).inDays >= _between(2, 3)) {
        lastJournal = day;
        final at = DateTime(day.year, day.month, day.day, 21, _between(0, 50));
        if (at.isBefore(now)) {
          final author = todaysFronters.isEmpty ? 'Juniper' : _pick(todaysFronters);
          final others = todaysFronters.toSet().where((n) => n != author).take(2).toList();
          final j = _rec(TrackerKind.journalEntry, title: _pick(journalTitles), body: 'Today ${others.isEmpty ? 'it was mostly just me' : '${others.join(' and ')} were around too'}. Slept about ${sleepHours.toStringAsFixed(1)} hours and drank ${(ml / 1000).toStringAsFixed(1)} L. ${_pick(['Trying to be gentle with ourselves.', 'Proud we got through it.', 'Need an early night.', 'Wren drew something lovely.', 'Sol made dinner for everyone.'])}', fields: {'mood': _between(2, 5)}, tags: [_pick(['daily', 'therapy', 'work', 'system', 'gratitude'])], at: at, memberId: byName[author]!.id);
          _link('rec:${j.id}', 'member:${byName[author]!.id}', 'related', at);
          if (daySessionIds.isNotEmpty) _link('rec:${j.id}', 'front:${daySessionIds.last}', 'during', at);
        }
      }
      // Dreams (about twice a week).
      if (_chance(0.28)) {
        final at = wake.subtract(const Duration(minutes: 10));
        final nightmare = sleepHours < 6.3 && _chance(0.5);
        final who = _pick(['Juniper', 'Wren', 'Mira', 'Rowan']);
        final themes = {_pick(dreamThemes), if (_chance(0.4)) _pick(dreamThemes)}.toList();
        final d = _rec(TrackerKind.dreamEntry, title: nightmare ? _pick(['Running through the school', 'The flooding house', 'Locked doors']) : _pick(['Flying over the garden', 'A train to the sea', 'The lighthouse', 'Tea with everyone']), body: 'We were somewhere ${_pick(['familiar', 'strange', 'bright', 'dark'])} and ${_pick(['there was water everywhere', 'everyone was talking at once', 'Mira was holding a red bird', 'the doors kept changing'])}.', fields: {
          'types': [if (nightmare) 'nightmare' else _pick(['vivid', 'calm', 'fragment']), if (themes.contains('school') && _chance(0.5)) 'recurring'],
          'themes': themes,
          'symbols': [if (_chance(0.6)) _pick(dreamSymbols)],
          'emotions': nightmare ? ['fear', 'anxiety'] : [_pick(['wonder', 'calm', 'joy', 'nostalgia'])],
          'rating': _between(2, 5),
          'members': [if (_chance(0.4)) byName[_pick(['Kai', 'Sol', 'Ash'])]!.id],
        }, at: at, memberId: byName[who]!.id);
        _link('rec:${d.id}', 'member:${byName[who]!.id}', 'related', at);
      }
    }
    onProgress?.call(0.82, 'extras');

    // One-off events across the range.
    for (var k = 0; k < math.max(2, days ~/ 10); k++) {
      final d = start.add(Duration(days: _between(0, days + 14)));
      final s = DateTime(d.year, d.month, d.day, _between(10, 18));
      final title = _pick(['Coffee with Sam', 'Dentist', 'Art class', 'Family dinner', 'Concert', 'Library trip', 'Movie night']);
      final ev = CalendarEvent(id: _uuid.v4(), title: title, startAt: s, endAt: s.add(const Duration(hours: 2)), category: title == 'Dentist' ? 'Health' : 'Social', memberIds: [byName[_pick(['Juniper', 'Wren', 'Sol'])]!.id], createdAt: s, modifiedAt: s);
      _events.add(CalendarEventMapper.toCompanion(ev));
    }

    // Statuses and history.
    final st = [('Juniper', 'builtin:online', 'Making tea ☕'), ('Kai', 'builtin:busy', 'Work until 5'), ('Mira', 'builtin:resting', 'Nap time'), ('Wren', 'builtin:available', 'Painting the garden')];
    for (final (name, type, msg) in st) {
      _rec(TrackerKind.statusCurrent, memberId: byName[name]!.id, body: msg, at: now.subtract(Duration(minutes: _between(10, 200))), fields: {'type': type, if (name == 'Wren') 'activity': 'Watercolours'});
      for (var k = 1; k <= 6; k++) {
        final s = now.subtract(Duration(days: k, hours: _between(0, 8)));
        _rec(TrackerKind.statusLog, memberId: byName[name]!.id, at: s, ended: s.add(Duration(hours: _between(1, 6))), fields: {'type': _pick(['builtin:online', 'builtin:idle', 'builtin:away', 'builtin:busy'])});
      }
    }
    final customStatus = _rec(TrackerKind.statusCustom, title: 'In the Garden', body: 'Spending time in the inner garden', fields: {'icon': 'flower', 'color': 0xFF5E9E6E});
    _rec(TrackerKind.statusCurrent, memberId: byName['Rowan']!.id, at: now.subtract(const Duration(hours: 1)), fields: {'type': 'custom:${customStatus.id}'});

    // Availability.
    void rule(String name, List<int> days, int s, int e, String cat, {String? note}) =>
        _rec(TrackerKind.availRule, memberId: byName[name]!.id, body: note, fields: {'days': [for (final d in days) '$d'], 'start': s * 60, 'end': e * 60, 'cat': cat});
    rule('Kai', [1, 2, 3, 4, 5], 8, 17, 'available', note: 'Work hours');
    rule('Kai', [6, 7], 9, 20, 'resting');
    rule('Juniper', [1, 2, 3, 4, 5, 6, 7], 17, 23, 'available');
    rule('Mira', [6, 7], 10, 16, 'interested', note: 'Weekend play time');
    rule('Mira', [1, 2, 3, 4, 5], 9, 17, 'unavailable', note: 'Stays inside while Kai works');
    rule('Sol', [1, 3, 5], 17, 20, 'available', note: 'Cooking nights');
    rule('Wren', [2, 4, 6], 14, 19, 'interested', note: 'Art time');
    rule('Rowan', [1, 2, 3, 4, 5, 6, 7], 0, 24, 'resting');
    rule('Ash', [1, 2, 3, 4, 5, 6, 7], 20, 23, 'available');
    final trip = now.add(const Duration(days: 3));
    _rec(TrackerKind.availOverride, memberId: byName['Kai']!.id, body: 'Day off', at: DateTime(trip.year, trip.month, trip.day, 8), ended: DateTime(trip.year, trip.month, trip.day, 20), fields: {'cat': 'unavailable'});

    // Intro cards.
    final cards = [
      ('Juniper', 'forest', 'The Gardener', 'I', {'roles': 'Host', 'personality': 'Organised, warm, a bit anxious', 'likes': 'Tea, plants, tidy lists', 'dislikes': 'Loud surprises', 'intro': 'Hi! I’m usually the one around. Say hello any time.'}),
      ('Kai', 'moon', 'The Shield', 'VII', {'roles': 'Protector, work', 'personality': 'Steady, direct, protective', 'interests': 'Running, podcasts', 'intro': 'If something feels unsafe, I step in.'}),
      ('Mira', 'sun', 'The Star', 'XVII', {'age': '7', 'likes': 'Stickers! Pancakes! Cartoons!', 'favorites': 'The colour orange and the cat next door', 'intro': 'Hello!! Do you want to colour with me?'}),
      ('Wren', 'celestial', 'The Dreamer', 'XVIII', {'roles': 'Artist', 'interests': 'Watercolour, scrapbooking, music', 'personality': 'Creative, dreamy, kind', 'intro': 'I fill the scrapbook — come look!'}),
    ];
    for (final (name, tpl, arcana, numeral, values) in cards) {
      _rec(TrackerKind.introCard, title: name, memberId: byName[name]!.id, fields: {'enabled': true, 'template': tpl, 'arcana': arcana, 'numeral': numeral, 'values': {...values, 'pronouns': byName[name]!.pronouns}, 'shown': <String>[], 'custom': <Map<String, String>>[]});
    }

    // Internal connections map.
    final map = _rec(TrackerKind.connMap, title: 'Our inner world', body: 'Who looks out for whom, and where everyone spends time.', fields: {'color': 0xFF8E7CC3, 'layout': 'free'});
    final c = const Offset(2000, 2000);
    final nodePos = <String, Offset>{};
    final nodeIds = <String, String>{};
    for (final (i, a) in alters.indexed) {
      final ang = 2 * math.pi * i / alters.length;
      final pos = c + Offset(math.cos(ang) * 320, math.sin(ang) * 320);
      nodePos[a.name] = pos;
      nodeIds[a.name] = _rec(TrackerKind.connNode, parentId: map.id, fields: {'type': 'alter', 'ref': 'member:${a.id}', 'x': pos.dx, 'y': pos.dy}).id;
    }
    final gardenNode = _rec(TrackerKind.connNode, parentId: map.id, title: '', fields: {'type': 'subsystem', 'ref': 'rec:${garden.id}', 'x': c.dx, 'y': c.dy}).id;
    final lighthouse = _rec(TrackerKind.connNode, parentId: map.id, title: 'The Lighthouse', body: 'A safe place in the headspace.', fields: {'type': 'location', 'icon': 'castle', 'x': c.dx + 600, 'y': c.dy - 120}).id;
    void edge(String a, String b, String type, {String? label}) =>
        _rec(TrackerKind.connEdge, parentId: map.id, title: label ?? '', fields: {'from': a, 'to': b, 'ctype': type});
    edge(nodeIds['Kai']!, nodeIds['Mira']!, 'protects');
    edge(nodeIds['Sol']!, nodeIds['Mira']!, 'cares');
    edge(nodeIds['Juniper']!, nodeIds['Kai']!, 'friends');
    edge(nodeIds['Ash']!, nodeIds['Kai']!, 'tension', label: 'working on it');
    edge(nodeIds['Mira']!, gardenNode, 'memberOf');
    edge(nodeIds['Wren']!, gardenNode, 'memberOf');
    edge(nodeIds['Rowan']!, lighthouse, 'livesIn');
    edge(gardenNode, lighthouse, 'path');

    // Scrapbook.
    final book = _rec(TrackerKind.scrapBook, title: 'Our year together', body: 'Memories everyone wanted to keep.', fields: {'theme': 'pastel', 'emoji': '🌸', 'font': 'hand', 'pattern': 'dots', 'contributors': <String>[], 'for': 'system'}, at: start);
    final pages = [
      ('First day of spring', [
        ScrapElement(type: ScrapType.text, text: 'First day of spring 🌷', x: 0.08, y: 0.05, w: 0.84, h: 0.1, font: 'display', size: 1.4),
        ScrapElement(type: ScrapType.note, text: 'Mira found a ladybird and named it Dot.', x: 0.1, y: 0.2, w: 0.5, h: 0.2, color: 0xFFFFF3A3, rot: -0.05, by: byName['Mira']!.id),
        ScrapElement(type: ScrapType.sticker, text: '🐞', x: 0.65, y: 0.22, w: 0.2, h: 0.14),
        ScrapElement(type: ScrapType.shape, text: 'heart', x: 0.6, y: 0.5, w: 0.25, h: 0.18, color: 0xFFEB459E),
        ScrapElement(type: ScrapType.text, text: 'We walked to the park and sat by the pond for an hour. Everyone was calm.', x: 0.08, y: 0.72, w: 0.84, h: 0.2, font: 'hand', by: byName['Juniper']!.id),
        ScrapElement(type: ScrapType.tape, x: 0.3, y: 0.17, w: 0.35, h: 0.05, rot: -0.1, color: 0xFFF8B6C9),
      ]),
      ('Art day', [
        ScrapElement(type: ScrapType.text, text: 'Wren’s art day 🎨', x: 0.08, y: 0.05, w: 0.84, h: 0.1, font: 'display', size: 1.3),
        for (var k = 0; k < 6; k++) ScrapElement(type: ScrapType.sticker, text: ['🎨', '✨', '🖌️', '🌈', '💫', '🦋'][k], x: 0.1 + (k % 3) * 0.28, y: 0.25 + (k ~/ 3) * 0.2, w: 0.18, h: 0.13, rot: (k - 3) * 0.08),
        ScrapElement(type: ScrapType.note, text: 'Painted the lighthouse from our dream. Kai said it looked “actually really good”.', x: 0.12, y: 0.68, w: 0.76, h: 0.22, color: 0xFFCDE7FF, rot: 0.03, by: byName['Wren']!.id),
      ]),
      ('Kai’s promotion', [
        ScrapElement(type: ScrapType.shape, text: 'banner', x: 0.1, y: 0.06, w: 0.8, h: 0.09, color: 0xFF4E79A7),
        ScrapElement(type: ScrapType.text, text: 'KAI GOT THE PROMOTION', x: 0.14, y: 0.075, w: 0.72, h: 0.07, font: 'display', color: 0xFFFFFFFF),
        ScrapElement(type: ScrapType.sticker, text: '🎉', x: 0.4, y: 0.25, w: 0.22, h: 0.16),
        ScrapElement(type: ScrapType.note, text: 'Sol made a cake. Ash said congrats (!!)', x: 0.15, y: 0.5, w: 0.7, h: 0.18, color: 0xFFC9F2D9, by: byName['Sol']!.id),
        ScrapElement(type: ScrapType.shape, text: 'star', x: 0.7, y: 0.75, w: 0.2, h: 0.14, color: 0xFFF1C40F),
      ]),
    ];
    for (final (i, (cap, els)) in pages.indexed) {
      final at = start.add(Duration(days: (days * (i + 1)) ~/ (pages.length + 1)));
      final pg = _rec(TrackerKind.scrapPage, parentId: book.id, title: cap, at: at, sort: i, memberId: byName[i == 1 ? 'Wren' : 'Juniper']!.id, fields: {'els': [for (final e in els) e.toJson()], 'members': [byName['Mira']!.id, byName['Wren']!.id]});
      if (i == 1) _link('rec:${pg.id}', 'member:${byName['Wren']!.id}', 'related', at);
    }
    _rec(TrackerKind.scrapBook, title: 'Mira’s sticker book', fields: {'theme': 'classic', 'emoji': '🧸', 'contributors': [byName['Mira']!.id, byName['Sol']!.id], 'for': 'alter', 'forRef': 'member:${byName['Mira']!.id}'}, at: start);

    // Automations.
    _rec(TrackerKind.autoRule, title: 'Welcome the new fronter', fields: {
      'enabled': true,
      'trigger': {'type': 'frontStart'},
      'actions': [
        {'type': 'message', 'text': 'Welcome, {alter}! 💜'},
      ],
      'cooldown': 1,
    });
    _rec(TrackerKind.autoRule, title: 'Link journal entries to the fronter', fields: {
      'enabled': true,
      'trigger': {'type': 'journal'},
      'actions': [
        {'type': 'link', 'target': 'fronter', 'cat': 'during'},
      ],
    });
    _rec(TrackerKind.autoCounter, title: 'Dreams recorded', amount: _tracker.length > 0 ? _tracker.where((x) => x.kind.value == TrackerKind.dreamEntry).length : 0);

    onProgress?.call(0.86, 'saving');
    await _write();
    onProgress?.call(0.98, 'settings');
    final settingsRepo = ref.read(systemSettingsRepositoryProvider);
    final s = await settingsRepo.getSettings();
    await settingsRepo.updateSettings(s.copyWith(hasCompletedOnboarding: true, systemName: 'Demo System'));
    onProgress?.call(1, 'done');
  }

  Future<void> _write() async {
    final AppDatabase db = ref.read(databaseProvider);
    Future<void> chunked<T>(List<T> rows, void Function(Batch b, List<T> part) add) async {
      for (var i = 0; i < rows.length; i += 400) {
        final part = rows.sublist(i, math.min(i + 400, rows.length));
        await db.batch((b) => add(b, part));
        await Future<void>.delayed(Duration.zero);
      }
    }

    await chunked(_members, (b, p) => b.insertAll(db.members, p));
    await chunked(_places, (b, p) => b.insertAll(db.savedLocations, p));
    await chunked(_sessions, (b, p) => b.insertAll(db.frontingSessions, p));
    await chunked(_moods, (b, p) => b.insertAll(db.moodEntries, p));
    await chunked(_events, (b, p) => b.insertAll(db.calendarEvents, p));
    await chunked(_visits, (b, p) => b.insertAll(db.locationSessions, p));
    await chunked(_tracker, (b, p) => b.insertAll(db.trackerRecords, p));
    await chunked(_habits, (b, p) => b.insertAll(db.habits, p));
    await chunked(_habitDone, (b, p) => b.insertAll(db.habitCompletions, p));
  }
}

