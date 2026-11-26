import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:prism_plurality/core/services/local_notification_service.dart';
import 'package:prism_plurality/shared/notify.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Nutrition colours, taken from the active app theme so Nourish matches
/// every preset (and the user's own palette) instead of a fixed palette.
class NutriPalette {
  const NutriPalette(this.s);
  final ColorScheme s;
  Color get water => s.primary;
  Color get tomato => s.primary;
  Color get saffron => s.tertiary;
  Color get basil => s.secondary;
  Color get plum => Color.lerp(s.primary, s.tertiary, 0.5)!;

  /// Theme-derived colours for built-in categories and drinks, by index.
  Color indexed(int i) => [
    s.primary,
    s.secondary,
    s.tertiary,
    Color.lerp(s.primary, s.secondary, 0.5)!,
    Color.lerp(s.secondary, s.tertiary, 0.5)!,
  ][i % 5];
}

extension NutriThemeX on BuildContext {
  NutriPalette get nutri => NutriPalette(Theme.of(this).colorScheme);
}

/// Built-in categories and drinks store 0 as their colour, meaning "use
/// the theme"; custom ones keep the colour the user chose.
Color catColor(BuildContext context, MealCategory? c) {
  if (c == null) return Theme.of(context).colorScheme.outline;
  if (c.color != 0) return Color(c.color);
  final i = builtInMealCategories.indexWhere((b) => b.$1 == c.id);
  return context.nutri.indexed(i < 0 ? 0 : i);
}

Color bevColor(BuildContext context, Beverage b) {
  if (b.color != 0) return Color(b.color);
  final i = builtInBeverages.indexWhere((x) => x.$1 == b.id);
  return context.nutri.indexed(i < 0 ? 0 : i);
}

class MealCategory {
  const MealCategory(this.id, this.title, this.icon, this.color, {this.record});
  final String id;
  final String title;
  final String icon;
  final int color;
  final TrackerRecord? record;
}

const builtInMealCategories = [
  ('breakfast', 'Breakfast', 'Desayuno', 'egg', 0),
  ('lunch', 'Lunch', 'Almuerzo', 'bowl', 0),
  ('dinner', 'Dinner', 'Cena', 'pizza', 0),
  ('snack', 'Snacks', 'Tentempiés', 'cookie', 0),
];

/// Nutrition metrics users may track; none are required.
class NutriMetric {
  const NutriMetric(this.key, this.en, this.es, this.unit);
  final String key;
  final String en;
  final String es;
  final String unit;
}

const nutriMetrics = [
  NutriMetric('kcal', 'Energy', 'Energía', 'kcal'),
  NutriMetric('protein', 'Protein', 'Proteína', 'g'),
  NutriMetric('carbs', 'Carbohydrates', 'Carbohidratos', 'g'),
  NutriMetric('fat', 'Fat', 'Grasa', 'g'),
  NutriMetric('fiber', 'Fibre', 'Fibra', 'g'),
  NutriMetric('sugar', 'Sugar', 'Azúcar', 'g'),
  NutriMetric('sodium', 'Sodium', 'Sodio', 'mg'),
  NutriMetric('iron', 'Iron', 'Hierro', 'mg'),
  NutriMetric('calcium', 'Calcium', 'Calcio', 'mg'),
  NutriMetric('caffeine', 'Caffeine', 'Cafeína', 'mg'),
];

class Beverage {
  const Beverage(
    this.id,
    this.title,
    this.icon,
    this.color,
    this.serving, {
    this.quick = true,
    this.record,
  });
  final String id;
  final String title;
  final String icon;
  final int color;

  /// Default serving in ml.
  final int serving;
  final bool quick;
  final TrackerRecord? record;
}

const builtInBeverages = [
  ('water', 'Water', 'Agua', 'drop', 0, 250),
  ('tea', 'Tea', 'Té', 'tea', 0, 250),
  ('coffee', 'Coffee', 'Café', 'coffee', 0, 200),
  ('juice', 'Juice', 'Zumo', 'orange', 0, 200),
  ('milk', 'Milk', 'Leche', 'bottle', 0, 250),
  ('sparkling', 'Sparkling water', 'Agua con gas', 'water', 0, 330),
  ('smoothie', 'Smoothie', 'Batido', 'cup', 0, 300),
  ('soda', 'Soft drink', 'Refresco', 'bottle', 0, 330),
];

/// Display units for volumes.
enum VolumeUnit { ml, oz, cups }

String fmtVolume(int ml, VolumeUnit u) => switch (u) {
  VolumeUnit.ml =>
    ml >= 1000
        ? '${(ml / 1000).toStringAsFixed(ml % 1000 == 0 ? 0 : 1)} L'
        : '$ml ml',
  VolumeUnit.oz => '${(ml / 29.5735).toStringAsFixed(1)} oz',
  VolumeUnit.cups => '${(ml / 240).toStringAsFixed(1)} cups',
};

int toMl(double v, VolumeUnit u) => switch (u) {
  VolumeUnit.ml => v.round(),
  VolumeUnit.oz => (v * 29.5735).round(),
  VolumeUnit.cups => (v * 240).round(),
};

/// Page settings stored in one synced record.
class NutriSettings {
  const NutriSettings(this.record);
  final TrackerRecord? record;
  VolumeUnit get unit => VolumeUnit.values.firstWhere(
    (u) => u.name == record?.str('unit'),
    orElse: () => VolumeUnit.ml,
  );
  int? get goalMl => record?.integer('goalMl');
  List<String> get metrics =>
      record?.strings('metrics') ?? const ['kcal', 'protein', 'carbs', 'fat'];
  Map<String, num> get metricGoals => record?.fields['metricGoals'] is Map
      ? (record!.fields['metricGoals'] as Map).cast<String, num>()
      : const {};
  bool get remindersOn => record?.flag('reminders') ?? false;
  int get reminderStart => record?.integer('remStart') ?? 9 * 60;
  int get reminderEnd => record?.integer('remEnd') ?? 21 * 60;
  int get reminderEvery => record?.integer('remEvery') ?? 120;
  String? get preferences => record?.str('prefs');
  List<String> get restrictions => record?.strings('restrictions') ?? const [];
  List<String> get sensitivities =>
      record?.strings('sensitivities') ?? const [];
  bool get showCalendar => record?.flag('calendar') ?? true;
  bool get showNutrition => record?.fields['showNutrition'] != false;
  List<String> get dashboard =>
      record?.strings('dashboard') ??
      const ['water', 'plate', 'metrics', 'recent', 'favorites'];
}

final nutriSettingsProvider = Provider<NutriSettings>((ref) {
  final rows =
      ref.watch(trackerKindProvider(TrackerKind.nutriSettings)).value ??
      const [];
  return NutriSettings(rows.isEmpty ? null : rows.first);
});

final mealCategoriesProvider = Provider.family<List<MealCategory>, String>((
  ref,
  lang,
) {
  final custom =
      ref.watch(trackerKindProvider(TrackerKind.nutriCategory)).value ??
      const [];
  return [
    for (final (id, en, es, icon, color) in builtInMealCategories)
      MealCategory(id, lang == 'es' ? es : en, icon, color),
    for (final c in custom.reversed)
      MealCategory(
        c.id,
        c.title,
        c.str('icon') ?? 'bowl',
        c.integer('color') ?? 0xFF8C8C8C,
        record: c,
      ),
  ];
});

final beveragesProvider = Provider.family<List<Beverage>, String>((ref, lang) {
  final custom =
      ref.watch(trackerKindProvider(TrackerKind.nutriBeverage)).value ??
      const [];
  final edits = {
    for (final c in custom)
      if (c.str('builtin') != null) c.str('builtin')!: c,
  };
  return [
    for (final (id, en, es, icon, color, ml) in builtInBeverages)
      if (edits[id]?.flag('hidden') != true)
        Beverage(
          id,
          lang == 'es' ? es : en,
          icon,
          color,
          edits[id]?.integer('ml') ?? ml,
          quick: edits[id]?.fields['quick'] != false,
          record: edits[id],
        ),
    for (final c in custom.reversed)
      if (c.str('builtin') == null)
        Beverage(
          c.id,
          c.title,
          c.str('icon') ?? 'cup',
          c.integer('color') ?? 0xFF3A8DDE,
          c.integer('ml') ?? 250,
          quick: c.fields['quick'] != false,
          record: c,
        ),
  ];
});

final mealsProvider = Provider<List<TrackerRecord>>(
  (ref) =>
      ref.watch(trackerKindProvider(TrackerKind.nutriMeal)).value ?? const [],
);
final drinksProvider = Provider<List<TrackerRecord>>(
  (ref) =>
      ref.watch(trackerKindProvider(TrackerKind.nutriDrink)).value ?? const [],
);
final foodsProvider = Provider<List<TrackerRecord>>(
  (ref) =>
      ref.watch(trackerKindProvider(TrackerKind.nutriFood)).value ?? const [],
);
final collectionsProvider = Provider<List<TrackerRecord>>(
  (ref) =>
      ref.watch(trackerKindProvider(TrackerKind.nutriCollection)).value ??
      const [],
);

int drinkMl(TrackerRecord r) => r.integer('ml') ?? 0;

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// Total ml per day.
Map<DateTime, int> hydrationByDay(
  List<TrackerRecord> drinks, {
  String? memberId,
}) {
  final out = <DateTime, int>{};
  for (final d in drinks) {
    if (memberId != null && d.memberId != memberId) continue;
    final k = dayOf(d.occurredAt ?? d.createdAt);
    out[k] = (out[k] ?? 0) + drinkMl(d);
  }
  return out;
}

Map<String, num> mealNutrition(TrackerRecord m) => m.fields['n'] is Map
    ? (m.fields['n'] as Map).map((k, v) => MapEntry(k as String, v as num))
    : const {};

class NutritionActions {
  NutritionActions(this.ref);
  final Ref ref;
  TrackerNotifier get _t => ref.read(trackerNotifierProvider.notifier);

  Future<TrackerRecord> logDrink({
    required Beverage bev,
    required int ml,
    String? memberId,
    DateTime? at,
    String? note,
  }) => _t.create(
    kind: TrackerKind.nutriDrink,
    title: bev.title,
    body: note,
    memberId: memberId,
    occurredAt: at ?? DateTime.now(),
    fields: {'bev': bev.id, 'ml': ml},
  );

  Future<void> saveMeal({
    TrackerRecord? editing,
    required String title,
    required Map<String, Object?> fields,
    String? body,
    String? memberId,
    DateTime? at,
    List<String> tags = const [],
    bool isPrivate = false,
  }) async {
    if (editing != null) {
      await _t.save(
        editing
            .copyWith(
              title: title,
              body: body,
              memberId: memberId,
              occurredAt: at,
              tags: tags,
              isPrivate: isPrivate,
            )
            .withFields(fields),
      );
    } else {
      await _t.create(
        kind: TrackerKind.nutriMeal,
        title: title,
        body: body,
        memberId: memberId,
        occurredAt: at ?? DateTime.now(),
        tags: tags,
        isPrivate: isPrivate,
        fields: fields,
      );
    }
  }

  /// Saves [meal] as a reusable food (favourite).
  Future<TrackerRecord> saveAsFood(TrackerRecord meal) => _t.create(
    kind: TrackerKind.nutriFood,
    title: meal.title,
    body: meal.body,
    fields: {
      'cat': meal.str('cat'),
      'ingredients': meal.strings('ingredients'),
      'n': meal.fields['n'],
      'media': meal.strings('media').take(1).toList(),
      'favorite': true,
    },
  );

  Future<void> updateSettings(Map<String, Object?> changes) async {
    final s = ref.read(nutriSettingsProvider).record;
    if (s == null) {
      await _t.create(kind: TrackerKind.nutriSettings, fields: changes);
    } else {
      await _t.save(s.withFields(changes));
    }
    if (changes.keys.any((k) => k.startsWith('rem')))
      await rescheduleReminders();
  }

  /// Daily hydration nudges between the chosen hours.
  Future<void> rescheduleReminders() async {
    if (kIsWeb) return;
    final svc = ref.read(localNotificationServiceProvider);
    try {
      await svc.cancelRange(PrismNotify.hydrationBase, PrismNotify.range);
    } catch (_) {
      return;
    }
    final s = ref.read(nutriSettingsProvider);
    if (!s.remindersOn) return;
    var i = 0;
    for (
      var m = s.reminderStart;
      m <= s.reminderEnd && i < 48;
      m += s.reminderEvery.clamp(30, 600)
    ) {
      await svc.scheduleExactDaily(
        id: PrismNotify.hydrationBase + i++,
        title: 'Hydration',
        body: 'A gentle reminder to have something to drink 💧',
        time: TimeOfDay(hour: m ~/ 60, minute: m % 60),
        details: PrismNotify.details('prism_hydration', 'Hydration reminders'),
      );
    }
  }
}

final nutritionActionsProvider = Provider<NutritionActions>(
  NutritionActions.new,
);
