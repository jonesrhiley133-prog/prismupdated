import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/core/router/app_router.dart';
import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/domain/models/system_settings.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/calendar/views/edit_event_sheet.dart';
import 'package:prism_plurality/features/cycle/views/cycle_screen.dart';
import 'package:prism_plurality/features/finance/views/finance_editors.dart';
import 'package:prism_plurality/features/fitness/views/fitness_editors.dart';
import 'package:prism_plurality/features/fronting/providers/fronting_providers.dart';
import 'package:prism_plurality/features/fronting/providers/sleep_providers.dart';
import 'package:prism_plurality/features/fronting/views/add_front_session_sheet.dart';
import 'package:prism_plurality/features/headspace/utils/headspace.dart';
import 'package:prism_plurality/features/home_widgets/models/widget_config.dart';
import 'package:prism_plurality/features/home_widgets/services/home_widget_data.dart';
import 'package:prism_plurality/features/home_widgets/services/home_widget_models.dart';
import 'package:prism_plurality/features/home_widgets/services/home_widget_platform.dart';
import 'package:prism_plurality/features/home_widgets/services/home_widget_store.dart';
import 'package:prism_plurality/features/journal/views/journal_editor_sheet.dart';
import 'package:prism_plurality/features/locations/providers/location_providers.dart';
import 'package:prism_plurality/features/mood/providers/mood_providers.dart';
import 'package:prism_plurality/features/mood/views/log_mood_sheet.dart';
import 'package:prism_plurality/features/school/views/school_editors.dart';
import 'package:prism_plurality/features/settings/providers/settings_providers.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';
import 'package:prism_plurality/l10n/app_localizations.dart';

final homeWidgetPlatformProvider = Provider<HomeWidgetPlatform>((ref) => HomeWidgetPlatform());

AppLocalizations _l10n() {
  try {
    return lookupAppLocalizations(ui.PlatformDispatcher.instance.locale);
  } catch (_) {
    return lookupAppLocalizations(const Locale('en'));
  }
}

final _avatarCache = <String, ({int length, String data})>{};

Future<String?> _png(ui.Picture picture, int w, int h) async {
  final img = await picture.toImage(w, h);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  return data == null ? null : base64Encode(data.buffer.asUint8List());
}

/// Small PNG of a member's avatar, cached until the avatar changes.
Future<String?> _avatar(String memberId, HomeWidgetData d) async {
  final bytes = d.members[memberId]?.avatarImageData;
  if (bytes == null || bytes.isEmpty) return null;
  final hit = _avatarCache[memberId];
  if (hit != null && hit.length == bytes.length) return hit.data;
  try {
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 96);
    final frame = await codec.getNextFrame();
    final rec = ui.PictureRecorder();
    final side = frame.image.width < frame.image.height ? frame.image.width : frame.image.height;
    Canvas(rec).drawImageRect(
      frame.image,
      Rect.fromLTWH((frame.image.width - side) / 2, (frame.image.height - side) / 2, side.toDouble(), side.toDouble()),
      const Rect.fromLTWH(0, 0, 96, 96),
      Paint()..filterQuality = FilterQuality.medium,
    );
    final out = await _png(rec.endRecording(), 96, 96);
    if (out != null) _avatarCache[memberId] = (length: bytes.length, data: out);
    return out;
  } catch (_) {
    return null;
  }
}

/// Mini picture of a headspace map, drawn from its areas and connections.
Future<String?> renderHeadspaceMap(String mapId, HomeWidgetData d, {required bool hidePrivate, required int textColor}) async {
  try {
    final areas = [
      for (final a in d.kind(TrackerKind.headspaceArea))
        if (a.parentId == mapId && !(a.isPrivate && hidePrivate)) a,
    ];
    if (areas.isEmpty) return null;
    final rects = {for (final a in areas) a.id: areaRect(a)};
    var bounds = rects.values.first;
    for (final r in rects.values) {
      bounds = bounds.expandToInclude(r);
    }
    bounds = bounds.inflate(24);
    const w = 480, h = 300;
    final scale = (w / bounds.width) < (h / bounds.height) ? w / bounds.width : h / bounds.height;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec)
      ..translate((w - bounds.width * scale) / 2, (h - bounds.height * scale) / 2)
      ..scale(scale)
      ..translate(-bounds.left, -bounds.top);
    final line = Paint()
      ..color = Color(textColor).withValues(alpha: 0.5)
      ..strokeWidth = 2 / scale
      ..style = PaintingStyle.stroke;
    for (final l in d.kind(TrackerKind.headspaceLink)) {
      final a = rects[l.str(HsField.from)], b = rects[l.str(HsField.to)];
      if (l.parentId == mapId && a != null && b != null) canvas.drawLine(a.center, b.center, line);
    }
    for (final a in areas) {
      final r = rects[a.id]!;
      final color = Color(a.integer(HsField.color) ?? 0xFF7E57C2);
      final shape = a.str(HsField.shape);
      final rr = shape == 'circle'
          ? RRect.fromRectAndRadius(r, Radius.circular(r.shortestSide / 2))
          : RRect.fromRectAndRadius(r, Radius.circular(shape == 'rect' ? 4 : 18));
      canvas.drawRRect(rr, Paint()..color = color.withValues(alpha: 0.85));
      final tp = TextPainter(
        text: TextSpan(
          text: a.title,
          style: TextStyle(
            fontSize: (13 / scale).clamp(12, 60).toDouble(),
            fontWeight: FontWeight.w600,
            color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: r.width - 8);
      tp.paint(canvas, Offset(r.left + (r.width - tp.width) / 2, r.top + (r.height - tp.height) / 2));
    }
    return _png(rec.endRecording(), w, h);
  } catch (_) {
    return null;
  }
}

/// Adds avatars and pictures to a model built by [buildWidgetModel].
Future<Json> enrichWidgetModel(Json model, WidgetConfig cfg, HomeWidgetData d) async {
  Future<void> avatar(Object? node) async {
    if (node is! Map<String, Object?>) return;
    final id = node.remove('memberId');
    if (id is String && cfg.style.showAvatars) {
      final img = await _avatar(id, d);
      if (img != null) node['image'] = img;
    }
  }

  await avatar(model['header']);
  for (final r in model['rows'] as List? ?? const []) {
    await avatar(r);
  }
  final mapId = model.remove('headspaceMapId');
  if (mapId is String) {
    final dark = cfg.style.theme != WidgetTheme.light;
    final img = await renderHeadspaceMap(
      mapId,
      d,
      hidePrivate: cfg.privacy.hideSensitive,
      textColor: paletteFor(cfg.style, dark: dark).text,
    );
    if (img != null) model['image'] = img;
  }
  return model;
}

/// Keeps placed widgets in step with Prism's data and runs their actions.
class HomeWidgetController {
  HomeWidgetController(this.ref);

  final Ref ref;
  Timer? _debounce;
  bool _running = false;
  bool _again = false;
  final _sent = <int, String>{};

  HomeWidgetPlatform get _platform => ref.read(homeWidgetPlatformProvider);

  /// Coalesces bursts of data changes into one widget refresh.
  void schedule({bool force = false, Duration delay = const Duration(milliseconds: 1500)}) {
    if (!_platform.isSupported) return;
    if (force) _sent.clear();
    _debounce?.cancel();
    _debounce = Timer(delay, () => unawaited(sync()));
  }

  Future<void> sync() async {
    if (!_platform.isSupported) return;
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      final placed = await _platform.listWidgets();
      final data = ref.read(homeWidgetDataProvider);
      final store = ref.read(homeWidgetsProvider).value;
      if (data == null || store == null) return;
      unawaited(ref.read(homeWidgetsProvider.notifier).prune({for (final p in placed) p.id}));
      _sent.removeWhere((id, _) => !placed.any((p) => p.id == id));
      final l10n = _l10n();
      final out = <int, Json>{};
      for (final w in placed) {
        final cfg = store.configFor(w.id, w.type);
        final model = await enrichWidgetModel(buildWidgetModel(cfg, data, l10n, l10n.localeName), cfg, data);
        final encoded = jsonEncode(model);
        if (_sent[w.id] == encoded) continue;
        _sent[w.id] = encoded;
        out[w.id] = model;
      }
      await _platform.updateWidgets(out);
    } catch (_) {
      // Widgets keep showing their cached content.
    } finally {
      _running = false;
      if (_again) {
        _again = false;
        schedule(delay: const Duration(milliseconds: 300));
      }
    }
  }

  /// A quick action that changes data without opening Prism's UI.
  Future<void> runDataAction(int id, String action) async {
    try {
      final parts = action.split(':');
      switch (parts.first) {
        case 'quickfront' when parts.length > 1:
          final member = parts[1];
          final active = ref.read(activeSessionsProvider).value ?? const [];
          final fronting = active.any((s) => s.memberId == member && !s.isSleep);
          final n = ref.read(frontingNotifierProvider.notifier);
          if (fronting) {
            await n.endFronting([member]);
          } else if (ref.read(quickFrontDefaultBehaviorProvider) == FrontStartBehavior.replace) {
            await n.replaceFronting([member]);
          } else {
            await n.startFronting([member]);
          }
        case 'mood' when parts.length > 1:
          final mood = int.tryParse(parts[1]);
          if (mood != null && mood >= 1 && mood <= 5) {
            final data = ref.read(homeWidgetDataProvider);
            final fronters = [...?data?.activeSessions]..sort((a, b) => b.startTime.compareTo(a.startTime));
            await ref
                .read(moodNotifierProvider.notifier)
                .create(mood: mood, intensity: 3, memberId: fronters.firstOrNull?.memberId);
          }
        case 'location' when parts.length > 1:
          final n = ref.read(locationsNotifierProvider.notifier);
          final current = ref.read(activeLocationSessionProvider)?.locationId;
          if (parts[1] == 'stop' || parts[1] == current) {
            await n.stopSession();
          } else {
            await n.startSession(parts[1]);
          }
        case 'todo' when parts.length > 1:
          final records = ref.read(trackerRecordsProvider).value ?? const <TrackerRecord>[];
          final item = records.where((r) => r.id == parts[1]).firstOrNull;
          if (item != null) {
            await ref.read(trackerNotifierProvider.notifier).save(item.withFields({'done': !item.flag('done')}));
          }
        case 'sleep' when parts.length > 1:
          final n = ref.read(sleepNotifierProvider.notifier);
          if (parts[1] == 'start') {
            if (ref.read(activeSleepSessionProvider).value == null) await n.startSleep();
          } else if (parts[1] == 'end' && parts.length > 2) {
            await n.endSleep(parts[2]);
          }
      }
    } catch (_) {
      // The next sync redraws the widget from real data.
    }
    schedule(force: true, delay: const Duration(milliseconds: 400));
  }

  BuildContext? get _context => ref.read(routerProvider).routerDelegate.navigatorKey.currentContext;

  /// A tap that brings Prism to the front on a screen or editor.
  Future<void> open(int id, String action) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final router = ref.read(routerProvider);
    final context = _context;
    if (context == null || !context.mounted) return;
    if (action.startsWith('route:')) {
      final path = action.substring(6);
      // Overlay screens are pushed; tab destinations are switched to.
      const pushed = ['/session/', '/sleep/session/', AppRoutePaths.todos, AppRoutePaths.homeWidgets];
      if (pushed.any(path.startsWith)) {
        unawaited(router.push(path));
      } else {
        router.go(path);
      }
      return;
    }
    if (action.startsWith('configure:')) {
      final wid = int.tryParse(action.substring(10)) ?? id;
      final placed = await _platform.listWidgets();
      final type = placed.where((p) => p.id == wid).firstOrNull?.type;
      unawaited(router.push(type == null ? AppRoutePaths.homeWidgets : AppRoutePaths.widgetStudio(type, id: wid)));
      schedule(force: true, delay: const Duration(milliseconds: 200));
      return;
    }
    switch (action) {
      case 'front:switch':
        await AddFrontSessionSheet.show(context);
      case 'mood:open':
        await showLogMoodSheet(context);
      case 'journal:new':
        await showJournalEditor(context);
      case 'note:new':
        unawaited(router.push(AppRoutePaths.notes));
      case 'todo:new':
        unawaited(router.push('${AppRoutePaths.todos}?new=1'));
      case 'event:new':
        await showEditEventSheet(context, initialStart: DateTime.now().add(const Duration(hours: 1)));
      case 'finance:new':
        await showTxnEditor(context);
      case 'fitness:new':
        await showWorkoutEditor(context);
      case 'school:new':
        await showAssignmentEditor(context);
      case 'cycle:today':
        await showCycleDaySheet(context, DateTime.now());
    }
  }

  void dispose() => _debounce?.cancel();
}

final homeWidgetControllerProvider = Provider<HomeWidgetController>((ref) {
  final c = HomeWidgetController(ref);
  ref.onDispose(c.dispose);
  return c;
});

/// Whether any Prism widget is on the home screen. Until one is, Prism
/// does not gather widget data at all.
class HasPlacedWidgets extends Notifier<bool> {
  @override
  bool build() => false;

  Future<void> refresh() async {
    final any = (await ref.read(homeWidgetPlatformProvider).listWidgets()).isNotEmpty;
    if (ref.mounted && state != any) state = any;
  }
}

final hasPlacedWidgetsProvider = NotifierProvider<HasPlacedWidgets, bool>(HasPlacedWidgets.new);

/// Keep alive from the app root: wires up widget taps.
final homeWidgetListenerProvider = Provider<void>((ref) {
  final platform = ref.watch(homeWidgetPlatformProvider);
  if (!platform.isSupported) return;
  final controller = ref.watch(homeWidgetControllerProvider);
  platform.setHandlers(
    onWidgetsChanged: () {
      unawaited(ref.read(hasPlacedWidgetsProvider.notifier).refresh());
      controller.schedule(force: true, delay: const Duration(milliseconds: 300));
    },
    onDataAction: controller.runDataAction,
    onOpen: controller.open,
  );
  unawaited(() async {
    await ref.read(hasPlacedWidgetsProvider.notifier).refresh();
    // Quick actions tapped while Prism was closed run now, in order.
    for (final q in await platform.takeQueue()) {
      await controller.runDataAction(q.id, q.action);
    }
    final pending = await platform.takePendingOpen();
    if (pending != null) await controller.open(pending.id, pending.action);
  }());
});

/// Keep alive from the app root: refreshes widgets on every data or
/// configuration change, but only while widgets are actually placed.
final homeWidgetSyncProvider = Provider<void>((ref) {
  if (!ref.watch(hasPlacedWidgetsProvider)) return;
  final controller = ref.watch(homeWidgetControllerProvider);
  ref.listen(homeWidgetDataProvider, (_, _) => controller.schedule(), fireImmediately: true);
  ref.listen(homeWidgetsProvider, (_, _) => controller.schedule(delay: const Duration(milliseconds: 250)));
  // Relative times ("5 min ago", countdowns) move even when data does not.
  final tick = Timer.periodic(const Duration(minutes: 15), (_) {
    ref.invalidate(homeWidgetDataProvider);
  });
  ref.onDispose(tick.cancel);
});
