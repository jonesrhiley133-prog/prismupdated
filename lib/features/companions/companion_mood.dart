import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_plurality/features/companions/companion_data.dart';

/// How an emotion moves. All values are scaled by the companion's
/// expressiveness and the app-wide animation intensity.
class EmotionMotion {
  const EmotionMotion({
    this.speed = 1,
    this.bob = 1,
    this.bounce = 0,
    this.shake = 0,
    this.tilt = 0,
    this.sway = 0,
    this.droop = 0,
    this.stretch = 0,
  });

  /// Breathing speed multiplier.
  final double speed;

  /// Gentle up-and-down.
  final double bob;

  /// Little hops off the ground.
  final double bounce;

  /// Fast trembling side to side (scared, grumpy).
  final double shake;

  /// A held head-tilt in radians (curious, proud).
  final double tilt;

  /// Slow rocking (content, loving).
  final double sway;

  /// Sinking lower and smaller (sad, bored, sleepy).
  final double droop;

  /// Squash and stretch (excited, silly).
  final double stretch;
}

/// Something small drawn near the companion with an emotion.
enum Emote {
  none,
  tears,
  steam,
  hearts,
  question,
  sweat,
  sparkles,
  zzz,
  swirl,
  exclaim,
}

class EmotionSpec {
  const EmotionSpec(
    this.id,
    this.label,
    this.emoji,
    this.motion, {
    this.emote = Emote.none,
  });
  final String id, label, emoji;
  final EmotionMotion motion;
  final Emote emote;
}

/// Sixteen emotions. The ids double as face expressions, so a companion's
/// chosen resting expression is just its default emotion.
const companionEmotions = <EmotionSpec>[
  EmotionSpec(
    'happy',
    'Happy',
    '😊',
    EmotionMotion(speed: 1.15, bob: 1.2, bounce: 0.3),
  ),
  EmotionSpec(
    'content',
    'Content',
    '😌',
    EmotionMotion(speed: 0.85, sway: 0.6),
  ),
  EmotionSpec(
    'sleepy',
    'Sleepy',
    '😴',
    EmotionMotion(speed: 0.55, bob: 0.6, droop: 0.5),
    emote: Emote.zzz,
  ),
  EmotionSpec(
    'surprised',
    'Surprised',
    '😮',
    EmotionMotion(speed: 1.3, bounce: 0.5),
    emote: Emote.exclaim,
  ),
  EmotionSpec(
    'wink',
    'Playful',
    '😉',
    EmotionMotion(speed: 1.1, tilt: 0.12, sway: 0.4),
  ),
  EmotionSpec('smug', 'Smug', '😏', EmotionMotion(speed: 0.8, tilt: -0.1)),
  EmotionSpec(
    'excited',
    'Excited',
    '🤩',
    EmotionMotion(speed: 1.8, bob: 1.4, bounce: 1, stretch: 0.6),
    emote: Emote.sparkles,
  ),
  EmotionSpec(
    'blush',
    'Shy',
    '☺️',
    EmotionMotion(speed: 0.9, tilt: 0.08, sway: 0.3),
  ),
  EmotionSpec(
    'sad',
    'Sad',
    '😢',
    EmotionMotion(speed: 0.6, bob: 0.5, droop: 0.8),
    emote: Emote.tears,
  ),
  EmotionSpec(
    'grumpy',
    'Grumpy',
    '😠',
    EmotionMotion(speed: 1.2, bob: 0.4, shake: 0.35),
    emote: Emote.steam,
  ),
  EmotionSpec(
    'scared',
    'Scared',
    '😨',
    EmotionMotion(speed: 1.6, bob: 0.3, shake: 1, droop: 0.3),
    emote: Emote.sweat,
  ),
  EmotionSpec(
    'loving',
    'Loving',
    '🥰',
    EmotionMotion(speed: 0.9, sway: 1, bob: 1.1),
    emote: Emote.hearts,
  ),
  EmotionSpec(
    'curious',
    'Curious',
    '🤔',
    EmotionMotion(speed: 1.0, tilt: 0.22, sway: 0.2),
    emote: Emote.question,
  ),
  EmotionSpec(
    'proud',
    'Proud',
    '😤',
    EmotionMotion(speed: 0.9, tilt: -0.06, stretch: 0.3, bob: 0.8),
    emote: Emote.sparkles,
  ),
  EmotionSpec(
    'bored',
    'Bored',
    '😑',
    EmotionMotion(speed: 0.5, bob: 0.4, droop: 0.4, sway: 0.2),
  ),
  EmotionSpec(
    'silly',
    'Silly',
    '🤪',
    EmotionMotion(speed: 1.5, bob: 1.2, stretch: 0.8, sway: 0.8, tilt: 0.1),
    emote: Emote.swirl,
  ),
];

EmotionSpec emotionById(String? id) => companionEmotions.firstWhere(
  (e) => e.id == id,
  orElse: () => companionEmotions[1],
);

/// A companion's temperament, 0–1 each. It shapes how lively they are and
/// which moods come naturally.
class CompanionPersonality {
  const CompanionPersonality({
    this.energy = 0.5,
    this.affection = 0.5,
    this.curiosity = 0.5,
    this.mischief = 0.3,
    this.expressiveness = 0.6,
    this.bravery = 0.5,
  });
  final double energy, affection, curiosity, mischief, expressiveness, bravery;

  static const labels = <String, String>{
    'energy': 'Energy',
    'affection': 'Affection',
    'curiosity': 'Curiosity',
    'mischief': 'Mischief',
    'expressiveness': 'Expressiveness',
    'bravery': 'Bravery',
  };

  double operator [](String k) => switch (k) {
    'energy' => energy,
    'affection' => affection,
    'curiosity' => curiosity,
    'mischief' => mischief,
    'expressiveness' => expressiveness,
    _ => bravery,
  };

  CompanionPersonality copyWithKey(String k, double v) => CompanionPersonality(
    energy: k == 'energy' ? v : energy,
    affection: k == 'affection' ? v : affection,
    curiosity: k == 'curiosity' ? v : curiosity,
    mischief: k == 'mischief' ? v : mischief,
    expressiveness: k == 'expressiveness' ? v : expressiveness,
    bravery: k == 'bravery' ? v : bravery,
  );

  Map<String, Object?> toJson() => {
    for (final k in labels.keys) k: double.parse(this[k].toStringAsFixed(2)),
  };

  /// Saved values, or sensible ones from the companion's traits.
  static CompanionPersonality of(Companion c) {
    final raw = c.r.fields['persona'];
    final t = c.traits;
    double base(String k) => switch (k) {
      'energy' =>
        t.contains('energetic') || t.contains('playful')
            ? 0.8
            : (t.contains('sleepy') || t.contains('calm') ? 0.25 : 0.5),
      'affection' =>
        t.contains('cuddly') || t.contains('affectionate') ? 0.85 : 0.55,
      'curiosity' =>
        t.contains('curious') || t.contains('adventurous') ? 0.85 : 0.5,
      'mischief' =>
        t.contains('mischievous') || t.contains('playful') ? 0.7 : 0.25,
      'expressiveness' => 0.6,
      _ => t.contains('shy') || t.contains('timid') ? 0.25 : 0.55,
    };
    double v(String k) => raw is Map && raw[k] is num
        ? (raw[k] as num).toDouble().clamp(0.0, 1.0)
        : base(k);
    return CompanionPersonality(
      energy: v('energy'),
      affection: v('affection'),
      curiosity: v('curiosity'),
      mischief: v('mischief'),
      expressiveness: v('expressiveness'),
      bravery: v('bravery'),
    );
  }
}

/// What's around the companion right now.
class CompanionEnvironment {
  const CompanionEnvironment({this.weather = 'clear', this.timeOfDay = 'day'});
  final String weather, timeOfDay;

  /// The habitat's time setting resolved against the clock.
  static String resolveTime(String setting, DateTime now) {
    if (setting != 'auto') return setting;
    final h = now.hour;
    if (h >= 5 && h < 11) return 'morning';
    if (h >= 11 && h < 17) return 'day';
    if (h >= 17 && h < 21) return 'evening';
    return 'night';
  }

  /// A short phrase for why the companion feels the way it does.
  String? get note => switch ((weather, timeOfDay)) {
    ('rain', _) => 'listening to the rain',
    ('snow', _) => 'watching the snow',
    ('leaves', _) => 'chasing falling leaves',
    ('petals', _) => 'catching petals',
    ('stars', _) => 'stargazing',
    ('fog', _) => 'peering into the mist',
    (_, 'night') => 'getting sleepy',
    (_, 'morning') => 'waking up',
    _ => null,
  };
}

/// Picks a mood from personality, what's around, and what just happened.
/// Deterministic for a given [seed] (so it doesn't flicker between builds);
/// pass a new seed to let the mood drift.
String chooseEmotion({
  required CompanionPersonality p,
  required CompanionEnvironment env,
  String? lastInteraction,
  String resting = 'content',
  int seed = 0,
}) {
  final w = <String, double>{for (final e in companionEmotions) e.id: 0.02};
  void add(String id, double v) => w[id] = (w[id] ?? 0) + v;
  add(resting, 1.2);
  add('happy', 0.4 + p.affection * 0.4);
  add('excited', p.energy * 0.6);
  add('silly', p.mischief * 0.6);
  add('wink', p.mischief * 0.4);
  add('curious', p.curiosity * 0.6);
  add('content', (1 - p.energy) * 0.5);
  add('blush', (1 - p.bravery) * 0.3);
  switch (env.timeOfDay) {
    case 'night':
      // Even lively companions get drowsy late at night.
      add('sleepy', 2.6 - p.energy);
      add('content', 0.1);
    case 'morning':
      add('sleepy', 0.3);
      add('happy', 0.4);
  }
  switch (env.weather) {
    case 'rain':
      add('content', 0.4);
      add('bored', 0.4 * (1 - p.curiosity));
      add('curious', 0.3);
      add('loving', 0.3 * p.affection);
    case 'snow':
      add('excited', 0.8 * p.energy);
      add('scared', 0.5 * (1 - p.bravery));
      add('surprised', 0.3);
    case 'leaves' || 'petals' || 'bubbles':
      add('curious', 0.6);
      add('excited', 0.4 * p.energy);
    case 'stars':
      add('content', 0.6);
      add('loving', 0.3);
    case 'fog':
      add('curious', 0.5);
      add('scared', 0.4 * (1 - p.bravery));
  }
  switch (lastInteraction) {
    case 'pet' || 'sit':
      add('loving', 2 + p.affection * 2);
      add('blush', 0.6);
    case 'play' || 'toy':
      add('excited', 2);
      add('silly', 1 + p.mischief);
    case 'treat':
      add('happy', 2);
      add('content', 1);
    case 'music':
      add('happy', 1.5);
      add('silly', 0.6);
    case 'read':
      add('curious', 2);
      add('content', 0.8);
    case 'sleep':
      add('sleepy', 3);
    case 'wave':
      add('happy', 2);
      add('surprised', 0.5);
    case 'explore':
      add('curious', 2.5);
      add('proud', 0.8);
    case 'dance' || 'spin':
      add('silly', 1.5 + p.mischief);
      add('excited', 1.5);
    case 'stretch':
      add('content', 2);
      add('proud', 0.6);
    case 'peekaboo':
      add('surprised', 2);
      add('silly', 1);
    case 'celebrate':
      add('excited', 2.5);
      add('proud', 1.5);
    case 'comfort':
      add('loving', 2.5);
      add('content', 1);
  }
  final total = w.values.fold<double>(0, (a, b) => a + b);
  var roll = math.Random(seed).nextDouble() * total;
  for (final e in w.entries) {
    roll -= e.value;
    if (roll <= 0) return e.key;
  }
  return resting;
}

/// App-wide companion animation strength (0 = still, 1 = full). Reduced
/// motion on the device always wins.
class CompanionMotionSettings {
  const CompanionMotionSettings({this.intensity = 1, this.environment = true});
  final double intensity;

  /// Whether companions react to their habitat's weather and time of day.
  final bool environment;

  static CompanionMotionSettings of(CompanionSettings s) {
    final raw = s.record?.fields['anim'];
    if (raw is! Map) return const CompanionMotionSettings();
    return CompanionMotionSettings(
      intensity: raw['i'] is num
          ? (raw['i'] as num).toDouble().clamp(0.0, 1.0)
          : 1,
      environment: raw['env'] != false,
    );
  }

  Map<String, Object?> toJson() => {
    'i': double.parse(intensity.toStringAsFixed(2)),
    'env': environment,
  };
}

final companionMotionProvider = Provider<CompanionMotionSettings>(
  (ref) => CompanionMotionSettings.of(ref.watch(companionSettingsProvider)),
);
