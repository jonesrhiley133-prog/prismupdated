import 'package:flutter/material.dart';

/// A named group of related emotions in the emotion library.
class EmotionCategory {
  const EmotionCategory({
    required this.key,
    required this.label,
    required this.color,
    required this.emotions,
  });

  final String key;
  final String label;
  final Color color;
  final List<EmotionDef> emotions;
}

class EmotionDef {
  const EmotionDef(this.key, this.label);

  /// Stable storage key. Never change an existing key; add new ones instead.
  final String key;
  final String label;
}

/// The built-in emotion library, grouped loosely after an emotion wheel.
///
/// Includes a "Disconnected" group for states common in plural systems
/// (numbness, fog, depersonalization) that general-purpose mood apps omit.
const emotionLibrary = <EmotionCategory>[
  EmotionCategory(
    key: 'joy',
    label: 'Joy',
    color: Color(0xFFF2B33D),
    emotions: [
      EmotionDef('happy', 'Happy'),
      EmotionDef('content', 'Content'),
      EmotionDef('grateful', 'Grateful'),
      EmotionDef('excited', 'Excited'),
      EmotionDef('proud', 'Proud'),
      EmotionDef('hopeful', 'Hopeful'),
      EmotionDef('playful', 'Playful'),
      EmotionDef('loved', 'Loved'),
      EmotionDef('confident', 'Confident'),
      EmotionDef('inspired', 'Inspired'),
    ],
  ),
  EmotionCategory(
    key: 'calm',
    label: 'Calm',
    color: Color(0xFF4FB59A),
    emotions: [
      EmotionDef('calm', 'Calm'),
      EmotionDef('relaxed', 'Relaxed'),
      EmotionDef('safe', 'Safe'),
      EmotionDef('grounded', 'Grounded'),
      EmotionDef('rested', 'Rested'),
      EmotionDef('peaceful', 'Peaceful'),
      EmotionDef('connected', 'Connected'),
    ],
  ),
  EmotionCategory(
    key: 'sadness',
    label: 'Sadness',
    color: Color(0xFF5B8DEF),
    emotions: [
      EmotionDef('sad', 'Sad'),
      EmotionDef('lonely', 'Lonely'),
      EmotionDef('disappointed', 'Disappointed'),
      EmotionDef('hurt', 'Hurt'),
      EmotionDef('grieving', 'Grieving'),
      EmotionDef('empty', 'Empty'),
      EmotionDef('hopeless', 'Hopeless'),
      EmotionDef('homesick', 'Homesick'),
    ],
  ),
  EmotionCategory(
    key: 'fear',
    label: 'Fear',
    color: Color(0xFF9B6FD6),
    emotions: [
      EmotionDef('anxious', 'Anxious'),
      EmotionDef('scared', 'Scared'),
      EmotionDef('worried', 'Worried'),
      EmotionDef('overwhelmed', 'Overwhelmed'),
      EmotionDef('nervous', 'Nervous'),
      EmotionDef('insecure', 'Insecure'),
      EmotionDef('panicked', 'Panicked'),
      EmotionDef('unsafe', 'Unsafe'),
    ],
  ),
  EmotionCategory(
    key: 'anger',
    label: 'Anger',
    color: Color(0xFFE5604D),
    emotions: [
      EmotionDef('angry', 'Angry'),
      EmotionDef('frustrated', 'Frustrated'),
      EmotionDef('irritated', 'Irritated'),
      EmotionDef('resentful', 'Resentful'),
      EmotionDef('jealous', 'Jealous'),
      EmotionDef('betrayed', 'Betrayed'),
      EmotionDef('defensive', 'Defensive'),
    ],
  ),
  EmotionCategory(
    key: 'shame',
    label: 'Shame',
    color: Color(0xFFC77D99),
    emotions: [
      EmotionDef('ashamed', 'Ashamed'),
      EmotionDef('guilty', 'Guilty'),
      EmotionDef('embarrassed', 'Embarrassed'),
      EmotionDef('disgusted', 'Disgusted'),
      EmotionDef('self_conscious', 'Self-conscious'),
      EmotionDef('regretful', 'Regretful'),
    ],
  ),
  EmotionCategory(
    key: 'surprise',
    label: 'Surprise',
    color: Color(0xFF3DB8D9),
    emotions: [
      EmotionDef('surprised', 'Surprised'),
      EmotionDef('confused', 'Confused'),
      EmotionDef('amazed', 'Amazed'),
      EmotionDef('startled', 'Startled'),
      EmotionDef('curious', 'Curious'),
    ],
  ),
  EmotionCategory(
    key: 'disconnected',
    label: 'Disconnected',
    color: Color(0xFF8A8F98),
    emotions: [
      EmotionDef('numb', 'Numb'),
      EmotionDef('foggy', 'Foggy'),
      EmotionDef('dissociated', 'Dissociated'),
      EmotionDef('detached', 'Detached'),
      EmotionDef('depersonalized', 'Depersonalized'),
      EmotionDef('tired', 'Tired'),
      EmotionDef('bored', 'Bored'),
      EmotionDef('restless', 'Restless'),
    ],
  ),
];

final Map<String, (EmotionDef, EmotionCategory)> _emotionIndex = {
  for (final c in emotionLibrary)
    for (final e in c.emotions) e.key: (e, c),
};

/// Display label for an emotion key. Unknown keys (custom labels or keys
/// from a newer app version) are shown as-is.
String emotionLabel(String key) => _emotionIndex[key]?.$1.label ?? key;

/// Category colour for an emotion key, or null for unknown keys.
Color? emotionColor(String key) => _emotionIndex[key]?.$2.color;

EmotionCategory? emotionCategoryOf(String key) => _emotionIndex[key]?.$2;
