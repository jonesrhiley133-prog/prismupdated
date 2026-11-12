import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/domain/models/location.dart';

final savedLocationsProvider = StreamProvider<List<SavedLocation>>((ref) {
  return ref.watch(savedLocationRepositoryProvider).watchAll();
});

/// Location sessions, newest first.
final locationSessionsProvider = StreamProvider<List<LocationSession>>((ref) {
  return ref.watch(locationSessionRepositoryProvider).watchAll();
});

/// The open location session, if any.
final activeLocationSessionProvider = Provider<LocationSession?>((ref) {
  final sessions = ref.watch(locationSessionsProvider).value ?? const [];
  return sessions.firstWhereOrNull((s) => s.isActive);
});

/// Saved locations sorted favourites first, then by sort order and name.
final sortedSavedLocationsProvider = Provider<List<SavedLocation>>((ref) {
  final list = [...?ref.watch(savedLocationsProvider).value];
  list.sort((a, b) {
    if (a.isFavorite != b.isFavorite) return a.isFavorite ? -1 : 1;
    final c = a.sortOrder.compareTo(b.sortOrder);
    return c != 0 ? c : a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return list;
});

class LocationsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<SavedLocation?> createLocation({
    required String name,
    String? emoji,
    String? colorHex,
    String? address,
    String? notes,
    bool isFavorite = false,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    final now = DateTime.now();
    final loc = SavedLocation(
      id: const Uuid().v4(),
      name: trimmed,
      emoji: emoji,
      colorHex: colorHex,
      address: _blank(address),
      notes: _blank(notes),
      isFavorite: isFavorite,
      createdAt: now,
      modifiedAt: now,
    );
    state = await AsyncValue.guard(
      () => ref.read(savedLocationRepositoryProvider).create(loc),
    );
    return state.hasError ? null : loc;
  }

  Future<void> saveLocation(SavedLocation loc) async {
    state = await AsyncValue.guard(
      () => ref
          .read(savedLocationRepositoryProvider)
          .update(loc.copyWith(modifiedAt: DateTime.now())),
    );
  }

  /// Deletes a location. Its history stays (shown as "Deleted location").
  Future<void> deleteLocation(String id) async {
    final active = ref.read(activeLocationSessionProvider);
    if (active?.locationId == id) await stopSession();
    state = await AsyncValue.guard(
      () => ref.read(savedLocationRepositoryProvider).delete(id),
    );
  }

  /// Starts a session at [locationId], ending any open session first.
  Future<void> startSession(String locationId, {DateTime? at}) async {
    final repo = ref.read(locationSessionRepositoryProvider);
    final now = at ?? DateTime.now();
    state = await AsyncValue.guard(() async {
      final active = (await repo.getAll()).where((s) => s.isActive);
      for (final s in active) {
        if (s.locationId == locationId) return; // already here
        await repo.update(s.copyWith(endedAt: now, modifiedAt: now));
      }
      await repo.create(
        LocationSession(
          id: const Uuid().v4(),
          locationId: locationId,
          startedAt: now,
          createdAt: now,
          modifiedAt: now,
        ),
      );
    });
  }

  Future<void> stopSession({DateTime? at}) async {
    final repo = ref.read(locationSessionRepositoryProvider);
    final now = at ?? DateTime.now();
    state = await AsyncValue.guard(() async {
      for (final s in (await repo.getAll()).where((s) => s.isActive)) {
        await repo.update(s.copyWith(endedAt: now, modifiedAt: now));
      }
    });
  }

  Future<void> saveSession(LocationSession session) async {
    state = await AsyncValue.guard(
      () => ref
          .read(locationSessionRepositoryProvider)
          .update(session.copyWith(modifiedAt: DateTime.now())),
    );
  }

  Future<void> addPastSession({
    required String locationId,
    required DateTime startedAt,
    required DateTime endedAt,
    String? note,
  }) async {
    final now = DateTime.now();
    state = await AsyncValue.guard(
      () => ref
          .read(locationSessionRepositoryProvider)
          .create(
            LocationSession(
              id: const Uuid().v4(),
              locationId: locationId,
              startedAt: startedAt,
              endedAt: endedAt,
              note: _blank(note),
              createdAt: now,
              modifiedAt: now,
            ),
          ),
    );
  }

  Future<void> deleteSession(String id) async {
    state = await AsyncValue.guard(
      () => ref.read(locationSessionRepositoryProvider).delete(id),
    );
  }
}

final locationsNotifierProvider =
    AsyncNotifierProvider<LocationsNotifier, void>(LocationsNotifier.new);

String? _blank(String? s) {
  final t = s?.trim();
  return (t == null || t.isEmpty) ? null : t;
}
