import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/core/features/feature_state.dart';
import 'package:prism_plurality/core/services/local_notification_service.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/prism_social/social_core.dart';

/// Text for a device notification (no BuildContext in the background).
String socialPushText(String type, String who) => switch (type) {
  'request' => '$who sent a friend request',
  'accepted' => '$who accepted your friend request',
  'message' || 'alterMessage' => '$who sent a message',
  'like' => '$who liked your post',
  'milestoneLike' => '$who reacted to your milestone',
  'comment' => '$who commented on your post',
  'reply' => '$who replied to your comment',
  'reblog' => '$who reblogged your post',
  'mention' => '$who mentioned you',
  _ => 'New activity from $who',
};

/// Which new social notifications deserve a device notification: unread,
/// newer than [since], not already shown, and not caused by the identity
/// acting on this device (your own actions never ping you). Respects the
/// recipient profile's "Device notifications" setting.
List<SocialNotification> pushable({
  required List<TrackerRecord> rows,
  required List<SocialProfile> profiles,
  required DateTime since,
  required Set<String> shown,
  String? actingProfile,
}) {
  final byId = {for (final p in profiles) p.id: p};
  return [
    for (final r in rows)
      if (!shown.contains(r.id))
        if (SocialNotification(r) case final n
            when !n.read &&
                n.at.isAfter(since) &&
                (byId[n.recipient]?.pushEnabled ?? false) &&
                n.actor?.profileId != actingProfile)
          n,
  ];
}

/// Shows device notifications for Social activity that arrives (e.g. synced
/// from another of your devices). Off when Social is turned off.
final socialNotificationListenerProvider = Provider<void>((ref) {
  final since = DateTime.now();
  final shown = <String>{};
  ref.listen<List<TrackerRecord>>(socialNotificationRowsProvider, (_, rows) {
    if (!isFeatureOn(ref, 'prismSocial')) return;
    final profiles = ref.read(socialProfilesProvider);
    final acting = ref.read(actingProvider)?.profileId;
    final alters = ref.read(socialAltersProvider);
    for (final n in pushable(
      rows: rows,
      profiles: profiles,
      since: since,
      shown: shown,
      actingProfile: acting,
    )) {
      shown.add(n.id);
      final a = n.actor;
      final sys = a == null
          ? null
          : profiles.where((p) => p.id == a.profileId).firstOrNull;
      final alt = a?.alterId == null
          ? null
          : alters.where((x) => x.id == a!.alterId).firstOrNull;
      final who = alt != null
          ? '${alt.name} (${sys?.systemName ?? ''})'
          : (sys?.systemName ?? 'Someone');
      final to = profiles.where((p) => p.id == n.recipient).firstOrNull;
      ref
          .read(localNotificationServiceProvider)
          .showImmediate(
            id: 0x50C00000 | (n.id.hashCode & 0xFFFFF),
            title: to == null || profiles.length < 2
                ? 'Prism Social'
                : 'Prism Social · ${to.systemName}',
            body:
                '${socialPushText(n.type, who)}${(n.preview ?? '').isNotEmpty && n.type != 'request' ? ': ${n.preview}' : ''}',
            details: const NotificationDetails(
              android: AndroidNotificationDetails(
                'prism_social',
                'Social',
                channelDescription:
                    'Friend requests, messages and activity in Prism Social',
                importance: Importance.high,
                priority: Priority.high,
              ),
              iOS: DarwinNotificationDetails(),
              macOS: DarwinNotificationDetails(),
            ),
          )
          .catchError((Object _) {});
    }
  });
});

final socialNotificationRowsProvider = Provider<List<TrackerRecord>>(
  (ref) => ref.watch(socRowsProvider(SocKind.notif)),
);
