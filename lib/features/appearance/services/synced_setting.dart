import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';

/// Mirrors one JSON settings blob to Prism's synced store so it follows
/// the user across devices. The newest `modifiedAt` wins.
///
/// [local] is the current device value (null until loaded), [adopt] is
/// called when another device has a newer one.
void bindSyncedSetting(
  Ref ref, {
  required String kind,
  required Map<String, Object?>? Function() local,
  required void Function(Map<String, dynamic> remote) adopt,
  required void Function(void Function() onLocalChange) listenLocal,
}) {
  Timer? debounce;
  int stamp(Map<String, Object?>? j) =>
      j?['modifiedAt'] is int ? j!['modifiedAt']! as int : 0;

  Future<void> push() async {
    final mine = local();
    if (mine == null || stamp(mine) == 0) return;
    final records = ref.read(trackerKindProvider(kind)).value;
    if (records == null) return; // synced store not loaded yet
    final notifier = ref.read(trackerNotifierProvider.notifier);
    final body = jsonEncode(mine);
    try {
      if (records.isEmpty) {
        await notifier.create(kind: kind, title: kind, body: body);
      } else {
        final r = records.first;
        Object? theirs;
        try {
          theirs = jsonDecode(r.body ?? '');
        } on FormatException {
          theirs = null;
        }
        if (theirs is Map<String, dynamic> && stamp(theirs) >= stamp(mine))
          return;
        await notifier.save(r.copyWith(body: body));
      }
    } catch (_) {
      // Stays on this device; retried on the next change.
    }
  }

  void pull() {
    final records = ref.read(trackerKindProvider(kind)).value;
    if (records == null || records.isEmpty) {
      // Nothing synced yet: offer this device's settings.
      debounce?.cancel();
      debounce = Timer(const Duration(seconds: 2), () => unawaited(push()));
      return;
    }
    try {
      final theirs = jsonDecode(records.first.body ?? '');
      final mine = local();
      if (theirs is Map<String, dynamic> &&
          mine != null &&
          stamp(theirs) > stamp(mine))
        adopt(theirs);
    } on FormatException {
      // Ignore an unreadable blob.
    }
  }

  // Start a few seconds after launch so settings sync never competes with
  // opening the database and the first screen.
  final start = Timer(const Duration(seconds: 4), () {
    ref.listen(
      trackerKindProvider(kind),
      (_, _) => pull(),
      fireImmediately: true,
    );
    listenLocal(() {
      debounce?.cancel();
      debounce = Timer(const Duration(seconds: 1), () => unawaited(push()));
    });
  });
  ref.onDispose(() {
    start.cancel();
    debounce?.cancel();
  });
}
