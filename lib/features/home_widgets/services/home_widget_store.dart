import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:prism_plurality/features/home_widgets/models/widget_config.dart';

const _prefsKey = 'home_widgets.state.v1';

/// Everything Prism remembers about home screen widgets on this device.
@immutable
class HomeWidgetsState {
  const HomeWidgetsState({
    this.configs = const {},
    this.presets = const [],
    this.recent = const [],
    this.defaults = const {},
  });

  /// Per placed widget (Android appWidgetId), so two widgets of the same
  /// type can look and behave differently.
  final Map<int, WidgetConfig> configs;

  /// Saved looks that can be applied to any widget of the same type.
  final List<WidgetConfig> presets;

  /// Recently customised widget types, newest first.
  final List<String> recent;

  /// What a newly added widget of each type starts with.
  final Map<String, WidgetConfig> defaults;

  /// The configuration used for widget [id] of [type].
  WidgetConfig configFor(int? id, String type) {
    final own = id == null ? null : configs[id];
    if (own != null && own.type == type) return own;
    return defaults[type] ?? WidgetConfig.defaultFor(type);
  }

  HomeWidgetsState copyWith({
    Map<int, WidgetConfig>? configs,
    List<WidgetConfig>? presets,
    List<String>? recent,
    Map<String, WidgetConfig>? defaults,
  }) => HomeWidgetsState(
    configs: configs ?? this.configs,
    presets: presets ?? this.presets,
    recent: recent ?? this.recent,
    defaults: defaults ?? this.defaults,
  );

  Map<String, Object?> toJson() => {
    'configs': {for (final e in configs.entries) '${e.key}': e.value.toJson()},
    'presets': [for (final p in presets) p.toJson()],
    'recent': recent,
    'defaults': {for (final e in defaults.entries) e.key: e.value.toJson()},
  };

  static HomeWidgetsState fromJson(Map<String, dynamic> j) {
    final configs = <int, WidgetConfig>{};
    if (j['configs'] is Map<String, dynamic>) {
      for (final e in (j['configs'] as Map<String, dynamic>).entries) {
        final id = int.tryParse(e.key);
        if (id != null && e.value is Map<String, dynamic>) {
          configs[id] = WidgetConfig.fromJson(e.value as Map<String, dynamic>);
        }
      }
    }
    final defaults = <String, WidgetConfig>{};
    if (j['defaults'] is Map<String, dynamic>) {
      for (final e in (j['defaults'] as Map<String, dynamic>).entries) {
        if (e.value is Map<String, dynamic>) {
          defaults[e.key] = WidgetConfig.fromJson(e.value as Map<String, dynamic>);
        }
      }
    }
    return HomeWidgetsState(
      configs: configs,
      presets: [
        if (j['presets'] is List)
          for (final p in j['presets'] as List)
            if (p is Map<String, dynamic>) WidgetConfig.fromJson(p),
      ],
      recent: [
        if (j['recent'] is List)
          for (final r in j['recent'] as List)
            if (r is String) r,
      ],
      defaults: defaults,
    );
  }
}

class HomeWidgetsNotifier extends AsyncNotifier<HomeWidgetsState> {
  @override
  Future<HomeWidgetsState> build() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_prefsKey);
      if (raw == null) return const HomeWidgetsState();
      final v = jsonDecode(raw);
      return v is Map<String, dynamic> ? HomeWidgetsState.fromJson(v) : const HomeWidgetsState();
    } on Exception {
      return const HomeWidgetsState();
    } on Error {
      return const HomeWidgetsState();
    }
  }

  Future<void> _save(HomeWidgetsState next) async {
    state = AsyncData(next);
    try {
      await (await SharedPreferences.getInstance()).setString(_prefsKey, jsonEncode(next.toJson()));
    } on Exception {
      // Kept in memory for this session.
    }
  }

  Future<HomeWidgetsState> _cur() async => state.value ?? await future;

  List<String> _touch(List<String> recent, String type) => [type, ...recent.where((t) => t != type)].take(6).toList();

  /// Saves the configuration of one placed widget.
  Future<void> saveConfig(int id, WidgetConfig cfg) async {
    final s = await _cur();
    await _save(s.copyWith(configs: {...s.configs, id: cfg}, recent: _touch(s.recent, cfg.type)));
  }

  /// Saves the starting configuration for new widgets of a type.
  Future<void> saveDefault(WidgetConfig cfg) async {
    final s = await _cur();
    await _save(s.copyWith(defaults: {...s.defaults, cfg.type: cfg}, recent: _touch(s.recent, cfg.type)));
  }

  Future<void> resetConfig(int? id, String type) async {
    final s = await _cur();
    if (id == null) {
      await _save(s.copyWith(defaults: {...s.defaults}..remove(type)));
    } else {
      await _save(s.copyWith(configs: {...s.configs}..remove(id)));
    }
  }

  Future<void> savePreset(WidgetConfig cfg) async {
    final s = await _cur();
    await _save(s.copyWith(presets: [cfg, ...s.presets.where((p) => !(p.type == cfg.type && p.name == cfg.name))]));
  }

  Future<void> deletePreset(WidgetConfig cfg) async {
    final s = await _cur();
    await _save(s.copyWith(presets: [...s.presets]..remove(cfg)));
  }

  /// Drops configurations of widgets that were removed from the home screen.
  Future<void> prune(Set<int> placed) async {
    final s = await _cur();
    if (s.configs.keys.every(placed.contains)) return;
    await _save(s.copyWith(configs: {for (final e in s.configs.entries) if (placed.contains(e.key)) e.key: e.value}));
  }
}

final homeWidgetsProvider = AsyncNotifierProvider<HomeWidgetsNotifier, HomeWidgetsState>(HomeWidgetsNotifier.new);
