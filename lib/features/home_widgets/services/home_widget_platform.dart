import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A widget the user has placed on their home screen.
@immutable
class PlacedWidget {
  const PlacedWidget({
    required this.id,
    required this.type,
    this.minWidth = 0,
    this.maxHeight = 0,
  });

  final int id;
  final String type;

  /// Current size in dp as reported by the launcher.
  final int minWidth;
  final int maxHeight;

  /// Same thresholds the native renderer uses.
  String get size => minWidth >= 250 && maxHeight >= 230
      ? 'large'
      : (minWidth < 180 || maxHeight < 100 ? 'small' : 'medium');
}

typedef WidgetActionHandler = Future<void> Function(int id, String action);

/// Bridge to the native AppWidget layer (Android only).
class HomeWidgetPlatform {
  HomeWidgetPlatform({MethodChannel? channel, bool? supported})
    : _channel =
          channel ?? const MethodChannel('com.prismplural.prism/widgets'),
      isSupported =
          supported ??
          (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  final MethodChannel _channel;
  final bool isSupported;

  Future<T?> _call<T>(String method, [Object? args]) async {
    if (!isSupported) return null;
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<List<PlacedWidget>> listWidgets() async {
    final raw = await _call<List<Object?>>('listWidgets') ?? const [];
    return [
      for (final w in raw)
        if (w is Map && w['id'] is int && w['type'] is String)
          PlacedWidget(
            id: w['id'] as int,
            type: w['type'] as String,
            minWidth: w['minWidth'] is int ? w['minWidth'] as int : 0,
            maxHeight: w['maxHeight'] is int ? w['maxHeight'] as int : 0,
          ),
    ];
  }

  Future<void> updateWidgets(Map<int, Map<String, Object?>> models) async {
    if (models.isEmpty) return;
    await _call<bool>('updateWidgets', {
      'models': {
        for (final e in models.entries) '${e.key}': jsonEncode(e.value),
      },
    });
  }

  /// Quick actions tapped while Prism was closed, oldest first.
  Future<List<({int id, String action})>> takeQueue() async {
    final raw = await _call<String>('takeQueue');
    if (raw == null) return const [];
    try {
      final v = jsonDecode(raw);
      return [
        if (v is List)
          for (final x in v)
            if (x is Map && x['action'] is String)
              (
                id: x['id'] is int ? x['id'] as int : -1,
                action: x['action'] as String,
              ),
      ];
    } on FormatException {
      return const [];
    }
  }

  Future<({int id, String action})?> takePendingOpen() async {
    final raw = await _call<Map<Object?, Object?>>('takePendingOpen');
    if (raw == null || raw['action'] is! String) return null;
    return (
      id: raw['id'] is int ? raw['id'] as int : -1,
      action: raw['action'] as String,
    );
  }

  Future<bool> canPin() async => await _call<bool>('canPin') ?? false;

  /// Asks the launcher to add a widget (One UI shows its own confirmation).
  Future<bool> pin(String type) async =>
      await _call<bool>('pin', {'type': type}) ?? false;

  void setHandlers({
    required VoidCallback onWidgetsChanged,
    required WidgetActionHandler onDataAction,
    required WidgetActionHandler onOpen,
  }) {
    if (!isSupported) return;
    _channel.setMethodCallHandler((call) async {
      final args = call.arguments;
      final id = args is Map && args['id'] is int ? args['id'] as int : -1;
      final action = args is Map && args['action'] is String
          ? args['action'] as String
          : '';
      switch (call.method) {
        case 'widgetsChanged':
          onWidgetsChanged();
        case 'widgetAction':
          await onDataAction(id, action);
        case 'widgetOpen':
          await onOpen(id, action);
      }
      return null;
    });
  }
}
