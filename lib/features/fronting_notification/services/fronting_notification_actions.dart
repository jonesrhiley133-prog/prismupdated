import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/core/router/app_router.dart';
import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/domain/models/fronting_session.dart';
import 'package:prism_plurality/features/fronting/providers/fronting_providers.dart';
import 'package:prism_plurality/features/fronting/views/add_front_session_sheet.dart';
import 'package:prism_plurality/features/fronting_notification/models/fronting_notification_settings.dart';
import 'package:prism_plurality/features/fronting_notification/services/fronting_notification_controller.dart';
import 'package:prism_plurality/features/fronting_notification/views/fronting_notification_sheets.dart';
import 'package:prism_plurality/features/mood/views/log_mood_sheet.dart';

/// Routes notification button taps to the matching screen or sheet.
class FrontingNotificationActions {
  FrontingNotificationActions(this.ref);

  final Ref ref;

  BuildContext? get _context =>
      ref.read(routerProvider).routerDelegate.navigatorKey.currentContext;

  Future<void> handle(String action) async {
    // Give the router a frame to settle after the app resumes.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final router = ref.read(routerProvider);
    final context = _context;
    if (context == null || !context.mounted) return;
    switch (action) {
      case FnAction.quickFront:
        await showQuickFrontSheet(context);
      case FnAction.switchFronter:
        await AddFrontSessionSheet.show(context);
      case FnAction.mood:
        await showLogMoodSheet(context);
      case FnAction.status:
        await showFrontingStatusEditor(context);
      case FnAction.details:
        final sessions =
            ref.read(activeSessionsProvider).value ?? const <FrontingSession>[];
        final current = [
          for (final s in sessions)
            if (s.sessionType != SessionType.sleep) s,
        ]..sort((a, b) => b.startTime.compareTo(a.startTime));
        if (current.isEmpty) {
          router.go(AppRoutePaths.home);
        } else {
          unawaited(router.push(AppRoutePaths.session(current.first.id)));
        }
      default:
        break;
    }
  }
}

/// Hooks the native action channel up once, from the app root.
final frontingNotificationActionsProvider = Provider<void>((ref) {
  final platform = ref.watch(frontingStatusPlatformProvider);
  if (!platform.isSupported) return;
  final actions = FrontingNotificationActions(ref);
  platform.setActionHandler((a) => unawaited(actions.handle(a)));
  unawaited(() async {
    final pending = await platform.takePendingAction();
    if (pending != null) await actions.handle(pending);
  }());
});
