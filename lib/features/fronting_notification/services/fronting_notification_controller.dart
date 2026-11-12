import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:prism_plurality/core/services/local_notification_service.dart';
import 'package:prism_plurality/domain/models/fronting_session.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/fronting/providers/fronting_providers.dart';
import 'package:prism_plurality/features/fronting/providers/sleep_providers.dart';
import 'package:prism_plurality/features/fronting_notification/models/fronting_notification_settings.dart';
import 'package:prism_plurality/features/fronting_notification/services/fronting_notification_settings_store.dart';
import 'package:prism_plurality/features/fronting_notification/services/fronting_notification_snapshot.dart';
import 'package:prism_plurality/features/fronting_notification/services/fronting_status_platform.dart';
import 'package:prism_plurality/features/locations/providers/location_providers.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/mood/providers/mood_providers.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';
import 'package:prism_plurality/features/work/providers/work_providers.dart';
import 'package:prism_plurality/l10n/app_localizations.dart';

final frontingStatusPlatformProvider = Provider<FrontingStatusPlatform>(
  (ref) => FrontingStatusPlatform(),
);

/// Everything the notification can show, recomputed whenever any source
/// changes (database streams; no polling).
final frontingNotificationInputsProvider = Provider<FnInputs?>((ref) {
  final sessions = ref.watch(activeSessionsProvider);
  final members = ref.watch(allMembersProvider);
  if (!sessions.hasValue || !members.hasValue) return null;
  final moods = ref.watch(moodEntriesProvider).value ?? const [];
  final loc = ref.watch(activeLocationSessionProvider);
  final places = ref.watch(savedLocationsProvider).value ?? const [];
  final work = ref.watch(activeWorkSessionsProvider);
  final jobs = ref.watch(jobByIdProvider);
  final records =
      ref.watch(trackerRecordsProvider).value ?? const <TrackerRecord>[];
  TrackerRecord? live(String kind) => records
      .where((r) => r.kind == kind && r.flag('live') && r.endedAt == null)
      .firstOrNull;
  final workout = live(TrackerKind.fitnessWorkout);
  final study = live(TrackerKind.schoolStudy);
  final studyClass = study?.parentId == null
      ? null
      : records.where((r) => r.id == study!.parentId).firstOrNull;
  return FnInputs(
    sessions: [
      for (final s in sessions.value!)
        if (s.sessionType != SessionType.sleep) s,
    ],
    members: {for (final m in members.value!) m.id: m},
    sleep: ref.watch(activeSleepSessionProvider).value,
    latestMood: moods.isEmpty
        ? null
        : (moods.toList()..sort((a, b) => b.recordedAt.compareTo(a.recordedAt)))
              .first,
    locationName: loc == null
        ? null
        : places
              .where((p) => p.id == loc.locationId)
              .map((p) => p.name)
              .firstOrNull,
    workJob: work.isEmpty ? null : (jobs[work.first.jobId]?.name ?? ''),
    liveWorkout: workout?.title,
    liveStudy: study == null ? null : (studyClass?.title ?? study.title),
  );
});

AppLocalizations _l10n() {
  try {
    return lookupAppLocalizations(ui.PlatformDispatcher.instance.locale);
  } catch (_) {
    return lookupAppLocalizations(const Locale('en'));
  }
}

FnStrings frontingNotificationStrings(AppLocalizations l10n, String locale) =>
    FnStrings(
      nobodyFronting: l10n.fnNobodyFronting,
      frontingLine: l10n.fnLineFronting,
      cofrontingLine: l10n.fnLineCofronting,
      sinceLine: l10n.fnLineSince,
      asleepLine: l10n.fnLineAsleep,
      statusLine: l10n.fnLineStatus,
      moodLine: (label, level) => l10n.fnLineMood(label, level),
      emotionsLine: l10n.fnLineEmotions,
      locationLine: l10n.fnLineLocation,
      workingLine: l10n.fnLineWorking,
      workoutLine: l10n.fnLineWorkout,
      studyLine: l10n.fnLineStudying,
      publicTitle: l10n.fnPublicTitle,
      publicText: l10n.fnPublicText,
      actionLabels: {
        FnAction.quickFront: l10n.fnActionQuickFront,
        FnAction.switchFronter: l10n.fnActionSwitch,
        FnAction.open: l10n.fnActionOpen,
        FnAction.mood: l10n.fnActionMood,
        FnAction.status: l10n.fnActionStatus,
        FnAction.details: l10n.fnActionDetails,
      },
      moodLabel: (level) => switch (level.clamp(1, 5)) {
        1 => l10n.moodLevelAwful,
        2 => l10n.moodLevelBad,
        3 => l10n.moodLevelOkay,
        4 => l10n.moodLevelGood,
        _ => l10n.moodLevelGreat,
      },
      formatTime: (t) {
        try {
          return DateFormat.jm(locale).format(t);
        } catch (_) {
          // Locale data not loaded (e.g. very early after start).
          return DateFormat.jm().format(t);
        }
      },
    );

/// Draws an emoji on a tinted circle as PNG bytes for the large icon.
Future<Uint8List?> renderEmojiIcon(String emoji, int? background) async {
  try {
    const size = 128.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2,
      Paint()..color = Color(background ?? 0xFFEDE7F6),
    );
    final tp = TextPainter(
      text: TextSpan(text: emoji, style: const TextStyle(fontSize: 76)),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size - tp.width) / 2, (size - tp.height) / 2));
    final img = await recorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}

/// Native snapshot JSON for [snap] under [settings].
Future<Map<String, Object?>> nativeSnapshot(
  FnSnapshot snap,
  FrontingNotificationSettings settings,
  Map<String, Member> members,
) async {
  Uint8List? icon;
  var circle = true;
  final primary = snap.primaryMemberId == null
      ? null
      : members[snap.primaryMemberId];
  final hasStyleEmoji =
      primary != null && settings.memberStyles[primary.id]?.emoji != null;
  switch (settings.iconSource) {
    case FnIconSource.avatar:
      if (!hasStyleEmoji &&
          primary?.avatarImageData != null &&
          primary!.avatarImageData!.isNotEmpty) {
        icon = primary.avatarImageData;
      } else if (snap.iconEmoji != null &&
          snap.iconEmoji!.trim().isNotEmpty &&
          snap.iconEmoji != '❔') {
        icon = await renderEmojiIcon(snap.iconEmoji!, snap.accentColor);
        circle = false;
      }
    case FnIconSource.emoji:
      icon = await renderEmojiIcon(
        snap.iconEmoji ?? settings.iconEmoji,
        snap.accentColor,
      );
      circle = false;
    case FnIconSource.builtIn:
    case FnIconSource.none:
      icon = null;
  }
  return {
    'title': snap.title,
    'text': snap.text,
    'lines': snap.lines,
    'subText': snap.subText,
    'chronometerBase': snap.chronometerBase?.millisecondsSinceEpoch,
    'showChronometer': snap.chronometerBase != null,
    'smallIcon': settings.smallIcon,
    'largeIcon': icon == null ? null : base64Encode(icon),
    'largeIconCircle': circle,
    'accentColor': snap.accentColor,
    'backgroundColor': snap.backgroundColor,
    'textColor': snap.textColor,
    'colorized': settings.colorized,
    'style': settings.style.name,
    'layout': settings.layout.name,
    'visibility': switch (settings.lockScreen) {
      FnLockScreen.show => 'public',
      FnLockScreen.hideDetails => 'private',
      FnLockScreen.hide => 'secret',
    },
    'publicTitle': snap.publicTitle,
    'publicText': snap.publicText,
    'bypassDnd': settings.bypassDnd,
    'ongoing': !settings.allowDismiss,
    'foreground': settings.foregroundService,
    'restoreOnBoot': settings.restoreOnBoot,
    'actions': [
      for (final a in snap.actions) {'id': a.$1, 'label': a.$2},
    ],
    'tapAction': FnAction.open,
  };
}

/// Keeps the OS notification in step with Prism's data. Event-driven: it
/// reacts to database streams and settings changes, debounced, and only
/// talks to Android when the content actually changed.
class FrontingNotificationController {
  FrontingNotificationController(this.ref);

  final Ref ref;
  Timer? _debounce;
  String? _lastPushed;
  bool _channelsReady = false;
  bool _cancelled = false;

  FrontingStatusPlatform get _platform =>
      ref.read(frontingStatusPlatformProvider);

  void dispose() => _debounce?.cancel();

  void schedule({bool force = false}) {
    if (force) _lastPushed = null;
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 250),
      () => unawaited(push()),
    );
  }

  Future<void> push() async {
    final settings = ref.read(frontingNotificationSettingsProvider).value;
    if (settings == null) return;
    if (!settings.enabled) {
      await stop();
      return;
    }
    final inputs = ref.read(frontingNotificationInputsProvider);
    if (inputs == null) return;
    final l10n = _l10n();
    final snap = buildFrontingSnapshot(
      settings,
      inputs,
      frontingNotificationStrings(l10n, l10n.localeName),
      DateTime.now(),
    );
    if (snap.hidden) {
      await stop();
      return;
    }
    final key = jsonEncode({...snap.toComparable(), 's': settings.toJson()});
    if (key == _lastPushed) return;
    if (_platform.isSupported) {
      if (!_channelsReady) {
        await _platform.ensureChannels(
          name: l10n.fnChannelName,
          dndName: l10n.fnChannelDndName,
          description: l10n.fnChannelDescription,
        );
        _channelsReady = true;
      }
      await _platform.show(
        await nativeSnapshot(snap, settings, inputs.members),
      );
    } else if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      // Fallback: Apple platforms have no persistent notifications, so
      // post (and replace) a quiet alert when the front changes.
      try {
        await ref
            .read(localNotificationServiceProvider)
            .showImmediate(
              id: fallbackNotificationId,
              title: snap.title,
              body: [
                snap.text,
                ...snap.lines.take(3),
              ].where((l) => l.isNotEmpty).toSet().join('\n'),
              details: const NotificationDetails(
                iOS: DarwinNotificationDetails(
                  presentSound: false,
                  threadIdentifier: 'fronting_status',
                ),
                macOS: DarwinNotificationDetails(
                  presentSound: false,
                  threadIdentifier: 'fronting_status',
                ),
              ),
              payload: 'prism:fronting-status:v1',
            );
      } catch (_) {}
    }
    _lastPushed = key;
    _cancelled = false;
  }

  Future<void> stop() async {
    if (_cancelled) return;
    _lastPushed = null;
    _cancelled = true;
    if (_platform.isSupported) {
      await _platform.cancel();
    } else {
      try {
        await ref
            .read(localNotificationServiceProvider)
            .cancel(fallbackNotificationId);
      } catch (_) {}
    }
  }

  static const fallbackNotificationId = 7314;
}

final frontingNotificationControllerProvider =
    Provider<FrontingNotificationController>((ref) {
      final c = FrontingNotificationController(ref);
      ref.onDispose(c.dispose);
      return c;
    });

/// Keep alive from the app root. Watches settings; only subscribes to the
/// data streams while the feature is turned on.
final frontingNotificationListenerProvider = Provider<void>((ref) {
  final settings = ref.watch(frontingNotificationSettingsProvider).value;
  final controller = ref.watch(frontingNotificationControllerProvider);
  if (settings == null) return;
  if (!settings.enabled) {
    // Clears a notification left from a previous run when turned off.
    unawaited(controller.push());
    return;
  }
  ref.listen(
    frontingNotificationInputsProvider,
    (_, _) => controller.schedule(),
    fireImmediately: true,
  );
  controller.schedule(force: true);
});
