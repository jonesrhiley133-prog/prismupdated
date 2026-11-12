import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/domain/preferences/emotion_preferences.dart';
import 'package:prism_plurality/features/mood/data/emotion_library.dart';
import 'package:prism_plurality/features/mood/providers/mood_providers.dart';

final favoriteEmotionsProvider = StreamProvider<List<String>>((ref) {
  return ref
      .watch(appPreferenceRepositoryProvider)
      .watch(favoriteEmotionsPreference);
});

final customEmotionsProvider = StreamProvider<List<CustomEmotion>>((ref) {
  return ref
      .watch(appPreferenceRepositoryProvider)
      .watch(customEmotionsPreference);
});

/// Up to 24 distinct emotion keys from the newest check-ins.
final recentEmotionsProvider = Provider<List<String>>((ref) {
  final entries = ref.watch(moodEntriesProvider).value ?? const [];
  final seen = <String>{};
  final out = <String>[];
  for (final e in entries) {
    for (final raw in e.emotions) {
      final key = parseEmotionEntry(raw).$1;
      if (seen.add(key)) out.add(key);
      if (out.length >= 24) return out;
    }
  }
  return out;
});

class EmotionPrefsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> toggleFavorite(String key) async {
    final repo = ref.read(appPreferenceRepositoryProvider);
    state = await AsyncValue.guard(() async {
      final current = [...await repo.get(favoriteEmotionsPreference)];
      if (!current.remove(key)) current.insert(0, key);
      await repo.set(favoriteEmotionsPreference, current);
    });
  }

  /// Adds a custom emotion. Returns its key, or null if [label] is blank or
  /// matches an existing emotion (built-in or custom), case-insensitively.
  Future<String?> addCustom(String label, {String? categoryKey}) async {
    final trimmed = label.trim();
    if (trimmed.isEmpty || trimmed.length > 40) return null;
    final lower = trimmed.toLowerCase();
    if (allBuiltInEmotions.any((e) => e.$1.label.toLowerCase() == lower)) {
      return null;
    }
    final repo = ref.read(appPreferenceRepositoryProvider);
    String? created;
    state = await AsyncValue.guard(() async {
      final current = [...await repo.get(customEmotionsPreference)];
      if (current.any((e) => e.label.toLowerCase() == lower)) return;
      final emotion = CustomEmotion(
        key: CustomEmotion.keyFor(trimmed),
        label: trimmed,
        categoryKey: categoryKey,
      );
      current.add(emotion);
      await repo.set(customEmotionsPreference, current);
      created = emotion.key;
    });
    return created;
  }

  /// Removes a custom emotion definition. Past check-ins keep showing its
  /// label (the key carries it).
  Future<void> removeCustom(String key) async {
    final repo = ref.read(appPreferenceRepositoryProvider);
    state = await AsyncValue.guard(() async {
      final current = [...await repo.get(customEmotionsPreference)]
        ..removeWhere((e) => e.key == key);
      await repo.set(customEmotionsPreference, current);
      final favs = [...await repo.get(favoriteEmotionsPreference)];
      if (favs.remove(key)) await repo.set(favoriteEmotionsPreference, favs);
    });
  }
}

final emotionPrefsNotifierProvider =
    AsyncNotifierProvider<EmotionPrefsNotifier, void>(EmotionPrefsNotifier.new);
