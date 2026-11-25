import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:prism_plurality/features/voice/voice_library.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

export 'package:prism_plurality/features/voice/voice_library.dart';

/// Where in Prism a line appears; each can have its own voice.
const voiceFeatures = <String, String>{
  'home': 'Home & greetings',
  'insights': 'Insights',
  'astro': 'Astro',
  'games': 'Games',
  'companions': 'Companions',
  'general': 'Everything else',
};

/// How Prism talks. Sliders shape any style a little further.
@immutable
class VoiceTuning {
  const VoiceTuning({
    this.style = VoiceStyle.natural,
    this.emoji = 0.3,
    this.energy = 0.5,
    this.warmth = 0.5,
    this.length = 0.5,
    this.formality = 0.3,
  });
  final VoiceStyle style;

  /// 0..1 each.
  final double emoji, energy, warmth, length, formality;

  VoiceTuning copyWith({
    VoiceStyle? style,
    double? emoji,
    double? energy,
    double? warmth,
    double? length,
    double? formality,
  }) => VoiceTuning(
    style: style ?? this.style,
    emoji: emoji ?? this.emoji,
    energy: energy ?? this.energy,
    warmth: warmth ?? this.warmth,
    length: length ?? this.length,
    formality: formality ?? this.formality,
  );

  Map<String, Object?> toJson() => {
    'style': style.name,
    'emoji': emoji,
    'energy': energy,
    'warmth': warmth,
    'length': length,
    'formality': formality,
  };
  static VoiceTuning fromJson(Object? raw) {
    final j = raw is Map ? raw : const {};
    double d(String k, double def) =>
        ((j[k] as num?)?.toDouble() ?? def).clamp(0, 1);
    return VoiceTuning(
      style:
          VoiceStyle.values.where((v) => v.name == j['style']).firstOrNull ??
          VoiceStyle.natural,
      emoji: d('emoji', 0.3),
      energy: d('energy', 0.5),
      warmth: d('warmth', 0.5),
      length: d('length', 0.5),
      formality: d('formality', 0.3),
    );
  }
}

/// Ready-made combinations.
const voicePresets = <String, VoiceTuning>{
  'Prism default': VoiceTuning(),
  'Cozy evening': VoiceTuning(
    style: VoiceStyle.cozy,
    emoji: 0.4,
    energy: 0.3,
    warmth: 0.9,
    length: 0.6,
  ),
  'Hype squad': VoiceTuning(
    style: VoiceStyle.chaotic,
    emoji: 0.8,
    energy: 1,
    warmth: 0.7,
    length: 0.5,
    formality: 0,
  ),
  'Calm & minimal': VoiceTuning(
    style: VoiceStyle.serious,
    emoji: 0,
    energy: 0.2,
    warmth: 0.4,
    length: 0.1,
    formality: 0.5,
  ),
  'Dry wit': VoiceTuning(
    style: VoiceStyle.deadpan,
    emoji: 0.1,
    energy: 0.2,
    warmth: 0.4,
    length: 0.4,
  ),
  'Storybook': VoiceTuning(
    style: VoiceStyle.poetic,
    emoji: 0.2,
    energy: 0.3,
    warmth: 0.8,
    length: 0.8,
    formality: 0.4,
  ),
  'Game night': VoiceTuning(
    style: VoiceStyle.gamer,
    emoji: 0.6,
    energy: 0.8,
    warmth: 0.5,
    length: 0.4,
    formality: 0,
  ),
  'Office hours': VoiceTuning(
    style: VoiceStyle.professional,
    emoji: 0,
    energy: 0.4,
    warmth: 0.3,
    length: 0.3,
    formality: 0.9,
  ),
};

@immutable
class VoiceSettings {
  const VoiceSettings({
    this.base = const VoiceTuning(),
    this.features = const {},
    this.profiles = const {},
    this.sensitiveStyle = VoiceStyle.natural,
    this.customTracks = true,
    this.enabled = true,
  });
  final VoiceTuning base;

  /// feature id → style override.
  final Map<String, VoiceStyle> features;

  /// member id → their own voice when they're fronting.
  final Map<String, VoiceTuning> profiles;

  /// Used in sensitive moments when the chosen style isn't gentle.
  final VoiceStyle sensitiveStyle;
  final bool customTracks;

  /// Off = Prism's original fixed wording everywhere.
  final bool enabled;

  VoiceSettings copyWith({
    VoiceTuning? base,
    Map<String, VoiceStyle>? features,
    Map<String, VoiceTuning>? profiles,
    VoiceStyle? sensitiveStyle,
    bool? customTracks,
    bool? enabled,
  }) => VoiceSettings(
    base: base ?? this.base,
    features: features ?? this.features,
    profiles: profiles ?? this.profiles,
    sensitiveStyle: sensitiveStyle ?? this.sensitiveStyle,
    customTracks: customTracks ?? this.customTracks,
    enabled: enabled ?? this.enabled,
  );

  Map<String, Object?> toJson() => {
    'base': base.toJson(),
    'features': {for (final e in features.entries) e.key: e.value.name},
    'profiles': {for (final e in profiles.entries) e.key: e.value.toJson()},
    'sensitive': sensitiveStyle.name,
    'custom': customTracks,
    'enabled': enabled,
  };

  static VoiceSettings fromJson(Object? raw) {
    final j = raw is Map ? raw : const {};
    VoiceStyle? st(Object? v) =>
        VoiceStyle.values.where((x) => x.name == v).firstOrNull;
    final sens = st(j['sensitive']);
    return VoiceSettings(
      base: VoiceTuning.fromJson(j['base']),
      features: {
        for (final e in ((j['features'] as Map?) ?? const {}).entries)
          if (st(e.value) != null) '${e.key}': st(e.value)!,
      },
      profiles: {
        for (final e in ((j['profiles'] as Map?) ?? const {}).entries)
          '${e.key}': VoiceTuning.fromJson(e.value),
      },
      sensitiveStyle: sens != null && sens.gentle ? sens : VoiceStyle.natural,
      customTracks: j['custom'] != false,
      enabled: j['enabled'] != false,
    );
  }
}

/// A line the user wrote for a context (optionally for one style or one
/// headmate).
@immutable
class CustomLine {
  const CustomLine({
    required this.id,
    required this.text,
    required this.context,
    this.style,
    this.memberId,
    this.enabled = true,
  });
  final String id, text;
  final VoiceContext context;
  final VoiceStyle? style;
  final String? memberId;
  final bool enabled;
}

/// Picks and shapes lines. Pure and offline; remembers recent picks so the
/// same line doesn't repeat back-to-back.
class VoiceEngine {
  VoiceEngine(this.settings, {this.custom = const [], math.Random? random})
    : _rng = random ?? math.Random();
  final VoiceSettings settings;
  final List<CustomLine> custom;
  final math.Random _rng;

  static final Map<String, List<String>> _recent = {};
  static const _memory = 4;

  /// The tuning in effect for [feature] while [memberId] is fronting.
  VoiceTuning tuningFor({String feature = 'general', String? memberId}) {
    final own = memberId == null ? null : settings.profiles[memberId];
    var t = own ?? settings.base;
    final f = settings.features[feature];
    if (f != null && own == null) t = t.copyWith(style: f);
    return t;
  }

  /// A line for [context]. [vars] fills {name}, {game}, {score}.
  String line(
    VoiceContext context, {
    String feature = 'general',
    String? memberId,
    Map<String, String> vars = const {},
    VoiceTuning? preview,
  }) {
    var t = preview ?? tuningFor(feature: feature, memberId: memberId);
    if (context.sensitive && !t.style.gentle)
      t = t.copyWith(style: settings.sensitiveStyle);
    final pool = <(String, String)>[];
    final lib = voiceLibrary[context] ?? const {};
    final own = lib[t.style] ?? lib[VoiceStyle.natural] ?? const <String>[];
    for (final (i, l) in own.indexed) {
      pool.add(('${t.style.name}:$i', l));
    }
    if (settings.customTracks) {
      for (final c in custom) {
        if (!c.enabled || c.context != context) continue;
        if (c.style != null && c.style != t.style) continue;
        if (c.memberId != null && c.memberId != memberId) continue;
        // Custom lines are weighted higher: they're yours.
        pool
          ..add(('c:${c.id}', c.text))
          ..add(('c:${c.id}', c.text));
      }
    }
    if (pool.isEmpty) return '';
    final key = '${context.name}/$feature';
    final recent = _recent.putIfAbsent(key, () => []);
    // Remember recent picks, but never so many that nothing fresh is left.
    final distinct = pool.map((p) => p.$1).toSet().length;
    final keep = math.min(_memory, distinct - 1);
    while (recent.length > keep && recent.isNotEmpty) {
      recent.removeAt(0);
    }
    final fresh = pool.where((p) => !recent.contains(p.$1)).toList();
    final from = fresh.isEmpty ? pool : fresh;
    final pick = from[_rng.nextInt(from.length)];
    recent.add(pick.$1);
    while (recent.length > keep && recent.isNotEmpty) {
      recent.removeAt(0);
    }
    var text = pick.$2;
    for (final e in vars.entries) {
      text = text.replaceAll('{${e.key}}', e.value);
    }
    text = text
        .replaceAll(RegExp(r'\{\w+\}'), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .replaceAll(' ,', ',')
        .trim();
    return shape(text, t, sensitive: context.sensitive);
  }

  /// Applies the sliders to a line.
  static String shape(String text, VoiceTuning t, {bool sensitive = false}) {
    var s = text;
    if (t.length < 0.25) {
      // Keep only the first sentence.
      final m = RegExp(r'^.*?[.!?](\s|$)').firstMatch(s);
      if (m != null && m.end < s.length) s = s.substring(0, m.end).trim();
    }
    if (t.formality > 0.7) {
      const exp = {
        "you're": 'you are',
        "don't": 'do not',
        "it's": 'it is',
        "that's": 'that is',
        "I'm": 'I am',
        "can't": 'cannot',
        "let's": 'let us',
        "won't": 'will not',
        "we're": 'we are',
        "you've": 'you have',
      };
      for (final e in exp.entries) {
        s = s
            .replaceAll(e.key, e.value)
            .replaceAll(
              '${e.key[0].toUpperCase()}${e.key.substring(1)}',
              '${e.value[0].toUpperCase()}${e.value.substring(1)}',
            );
      }
    }
    if (!sensitive) {
      if (t.energy > 0.75 && s.endsWith('.') && !s.endsWith('..'))
        s = '${s.substring(0, s.length - 1)}!';
      if (t.energy < 0.2) s = s.replaceAll(RegExp(r'!+'), '.');
    }
    if (t.warmth > 0.8 && t.length > 0.6 && !sensitive) {
      s = '$s ${t.style == VoiceStyle.internet ? 'ily' : 'Glad you\'re here.'}';
    }
    final hasEmoji = RegExp(
      r'[\u{1F300}-\u{1FAFF}☀-➿]',
      unicode: true,
    ).hasMatch(s);
    if (t.emoji < 0.1 && hasEmoji) {
      s = s
          .replaceAll(
            RegExp(r'\s*[\u{1F300}-\u{1FAFF}☀-➿]️?', unicode: true),
            '',
          )
          .trim();
    } else if (t.emoji > 0.6 && !hasEmoji) {
      s = '$s ${sensitive ? '💛' : _emojiFor(t.style)}';
    }
    return s;
  }

  static String _emojiFor(VoiceStyle s) => switch (s) {
    VoiceStyle.cozy => '☕',
    VoiceStyle.chaotic => '🤪',
    VoiceStyle.grumpy => '😤',
    VoiceStyle.cheerful => '🌈',
    VoiceStyle.poetic => '🌙',
    VoiceStyle.gamer => '🎮',
    VoiceStyle.internet => '✨',
    VoiceStyle.elegant => '🌹',
    VoiceStyle.sarcastic => '🙃',
    VoiceStyle.deadpan => '😐',
    _ => '🙂',
  };

  @visibleForTesting
  static void resetMemory() => _recent.clear();
}

// ── Storage ──────────────────────────────────────────────────────────────

final voiceSettingsRecordProvider = Provider<TrackerRecord?>(
  (ref) =>
      (ref.watch(trackerKindProvider(TrackerKind.voiceSettings)).value ??
              const <TrackerRecord>[])
          .firstOrNull,
);

final voiceSettingsProvider = Provider<VoiceSettings>(
  (ref) => VoiceSettings.fromJson(
    ref.watch(voiceSettingsRecordProvider)?.fields['settings'],
  ),
);

final customLinesProvider = Provider<List<CustomLine>>(
  (ref) => [
    for (final r
        in ref.watch(trackerKindProvider(TrackerKind.voiceTrack)).value ??
            const <TrackerRecord>[])
      if (VoiceContext.values
              .where((c) => c.name == r.fields['context'])
              .firstOrNull
          case final ctx?)
        CustomLine(
          id: r.id,
          text: r.title,
          context: ctx,
          style: VoiceStyle.values
              .where((s) => s.name == r.fields['style'])
              .firstOrNull,
          memberId: r.memberId,
          enabled: r.fields['enabled'] != false,
        ),
  ],
);

final voiceEngineProvider = Provider<VoiceEngine>(
  (ref) => VoiceEngine(
    ref.watch(voiceSettingsProvider),
    custom: ref.watch(customLinesProvider),
  ),
);

class VoiceActions {
  VoiceActions(this.ref);
  final Ref ref;
  TrackerNotifier get _t => ref.read(trackerNotifierProvider.notifier);

  Future<void> save(VoiceSettings s) async {
    final rec = ref.read(voiceSettingsRecordProvider);
    if (rec == null) {
      await _t.create(
        kind: TrackerKind.voiceSettings,
        fields: {'settings': s.toJson()},
      );
    } else {
      await _t.save(rec.withFields({...rec.fields, 'settings': s.toJson()}));
    }
  }

  Future<void> addLine(
    String text,
    VoiceContext context, {
    VoiceStyle? style,
    String? memberId,
  }) => _t.create(
    kind: TrackerKind.voiceTrack,
    title: text.trim(),
    memberId: memberId,
    fields: {'context': context.name, 'style': style?.name, 'enabled': true},
  );

  Future<void> toggleLine(CustomLine l, bool on) async {
    final rows =
        ref.read(trackerKindProvider(TrackerKind.voiceTrack)).value ??
        const <TrackerRecord>[];
    final r = rows.where((x) => x.id == l.id).firstOrNull;
    if (r != null) await _t.save(r.withFields({...r.fields, 'enabled': on}));
  }

  Future<void> deleteLine(CustomLine l) => _t.delete(l.id, children: false);
}

final voiceActionsProvider = Provider<VoiceActions>(VoiceActions.new);

/// Convenience for widgets: a line for [context] in Prism's current voice,
/// or [fallback] when the voice engine is off or the app isn't in English.
String voiceLine(
  WidgetRef ref,
  BuildContext context,
  VoiceContext ctx, {
  required String fallback,
  String feature = 'general',
  Map<String, String> vars = const {},
  String? memberId,
}) {
  final s = ref.read(voiceSettingsProvider);
  if (!s.enabled ||
      !Localizations.localeOf(context).languageCode.startsWith('en'))
    return fallback;
  final out = ref
      .read(voiceEngineProvider)
      .line(ctx, feature: feature, memberId: memberId, vars: vars);
  return out.isEmpty ? fallback : out;
}

/// Text in Prism's voice. Picks its line once and keeps it (no flicker on
/// rebuilds) until the context or variables change.
class VoiceText extends ConsumerStatefulWidget {
  const VoiceText(
    this.ctx, {
    super.key,
    required this.fallback,
    this.feature = 'general',
    this.vars = const {},
    this.memberId,
    this.style,
    this.textAlign,
    this.maxLines,
  });
  final VoiceContext ctx;
  final String fallback;
  final String feature;
  final Map<String, String> vars;
  final String? memberId;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;

  @override
  ConsumerState<VoiceText> createState() => _VoiceTextState();
}

class _VoiceTextState extends ConsumerState<VoiceText> {
  String? _text;
  String _key = '';

  String _keyOf() =>
      '${widget.ctx.name}|${widget.fallback}|${widget.feature}|${widget.memberId}|${widget.vars}|${ref.read(voiceSettingsProvider).toJson()}';

  @override
  Widget build(BuildContext context) {
    ref.watch(voiceSettingsProvider);
    final k = _keyOf();
    if (_text == null || k != _key) {
      _key = k;
      _text = voiceLine(
        ref,
        context,
        widget.ctx,
        fallback: widget.fallback,
        feature: widget.feature,
        vars: widget.vars,
        memberId: widget.memberId,
      );
    }
    return Text(
      _text!,
      style: widget.style,
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      overflow: widget.maxLines == null ? null : TextOverflow.ellipsis,
    );
  }
}
