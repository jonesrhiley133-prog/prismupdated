import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Talks to the native Android notification (FrontingStatus.kt).
class FrontingStatusPlatform {
  FrontingStatusPlatform({MethodChannel? channel})
    : _channel =
          channel ??
          const MethodChannel('com.prismplural.prism/fronting_status');

  final MethodChannel _channel;

  /// Real persistent notifications need Android.
  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<T?> _call<T>(String method, [Object? args]) async {
    if (!isSupported) return null;
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      debugPrint('Fronting status $method failed: ${e.message}');
      return null;
    }
  }

  Future<void> ensureChannels({
    required String name,
    required String dndName,
    required String description,
  }) => _call<bool>('ensureChannels', {
    'name': name,
    'dndName': dndName,
    'description': description,
  });

  /// Posts or replaces the notification. Returns false when the OS blocks
  /// notifications for Prism.
  Future<bool> show(Map<String, Object?> snapshot) async =>
      await _call<bool>('show', {'snapshot': jsonEncode(snapshot)}) ?? false;

  Future<void> cancel() => _call<bool>('cancel');

  Future<bool> isShowing() async => await _call<bool>('isShowing') ?? false;

  Future<bool> wasDismissed() async =>
      await _call<bool>('wasDismissed') ?? false;

  Future<bool> notificationsEnabled() async =>
      await _call<bool>('notificationsEnabled') ?? false;

  Future<void> openChannelSettings({bool dnd = false}) => _call<bool>(
    'openChannelSettings',
    {'channel': dnd ? 'fronting_status_dnd' : 'fronting_status'},
  );

  Future<void> openBatterySettings() => _call<bool>('openBatterySettings');

  Future<bool> isIgnoringBatteryOptimizations() async =>
      await _call<bool>('isIgnoringBatteryOptimizations') ?? false;

  /// Action that launched or resumed the app from the notification.
  Future<String?> takePendingAction() => _call<String>('takePendingAction');

  /// Receives action taps while the app is running.
  void setActionHandler(void Function(String action) onAction) {
    if (!isSupported) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onAction' && call.arguments is String)
        onAction(call.arguments as String);
      return null;
    });
  }
}
