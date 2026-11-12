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
/// Includes "Disconnected" and "Plural experiences" groups for states common
/// in plural systems that general-purpose mood apps omit. Keys are stable
/// storage values: never rename one, add a new key instead. (The original
/// 59 keys from the first library are all still present.)
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
      EmotionDef('cheerful', 'Cheerful'),
      EmotionDef('delighted', 'Delighted'),
      EmotionDef('joyful', 'Joyful'),
      EmotionDef('elated', 'Elated'),
      EmotionDef('euphoric', 'Euphoric'),
      EmotionDef('amused', 'Amused'),
      EmotionDef('optimistic', 'Optimistic'),
      EmotionDef('enthusiastic', 'Enthusiastic'),
      EmotionDef('satisfied', 'Satisfied'),
      EmotionDef('fulfilled', 'Fulfilled'),
      EmotionDef('blissful', 'Blissful'),
      EmotionDef('radiant', 'Radiant'),
      EmotionDef('giddy', 'Giddy'),
      EmotionDef('triumphant', 'Triumphant'),
      EmotionDef('eager', 'Eager'),
      EmotionDef('lighthearted', 'Lighthearted'),
    ],
  ),
  EmotionCategory(
    key: 'love',
    label: 'Love & connection',
    color: Color(0xFFE27FA8),
    emotions: [
      EmotionDef('affectionate', 'Affectionate'),
      EmotionDef('caring', 'Caring'),
      EmotionDef('tender', 'Tender'),
      EmotionDef('warm', 'Warm'),
      EmotionDef('compassionate', 'Compassionate'),
      EmotionDef('trusting', 'Trusting'),
      EmotionDef('accepted', 'Accepted'),
      EmotionDef('belonging', 'Belonging'),
      EmotionDef('cherished', 'Cherished'),
      EmotionDef('appreciated', 'Appreciated'),
      EmotionDef('admired', 'Admired'),
      EmotionDef('close', 'Close'),
      EmotionDef('devoted', 'Devoted'),
      EmotionDef('empathetic', 'Empathetic'),
      EmotionDef('supported', 'Supported'),
      EmotionDef('seen', 'Seen'),
      EmotionDef('understood', 'Understood'),
      EmotionDef('valued', 'Valued'),
      EmotionDef('nurtured', 'Nurtured'),
      EmotionDef('protective', 'Protective'),
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
      EmotionDef('serene', 'Serene'),
      EmotionDef('centered', 'Centered'),
      EmotionDef('balanced', 'Balanced'),
      EmotionDef('comfortable', 'Comfortable'),
      EmotionDef('cozy', 'Cozy'),
      EmotionDef('settled', 'Settled'),
      EmotionDef('at_ease', 'At ease'),
      EmotionDef('mellow', 'Mellow'),
      EmotionDef('patient', 'Patient'),
      EmotionDef('present', 'Present'),
      EmotionDef('steady', 'Steady'),
      EmotionDef('secure', 'Secure'),
      EmotionDef('soothed', 'Soothed'),
      EmotionDef('unburdened', 'Unburdened'),
    ],
  ),
  EmotionCategory(
    key: 'interest',
    label: 'Interest',
    color: Color(0xFF6C8EF0),
    emotions: [
      EmotionDef('curious', 'Curious'),
      EmotionDef('interested', 'Interested'),
      EmotionDef('engaged', 'Engaged'),
      EmotionDef('focused', 'Focused'),
      EmotionDef('fascinated', 'Fascinated'),
      EmotionDef('absorbed', 'Absorbed'),
      EmotionDef('alert', 'Alert'),
      EmotionDef('motivated', 'Motivated'),
      EmotionDef('determined', 'Determined'),
      EmotionDef('productive', 'Productive'),
      EmotionDef('creative', 'Creative'),
      EmotionDef('capable', 'Capable'),
      EmotionDef('empowered', 'Empowered'),
      EmotionDef('brave', 'Brave'),
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
      EmotionDef('shocked', 'Shocked'),
      EmotionDef('astonished', 'Astonished'),
      EmotionDef('awed', 'Awed'),
      EmotionDef('puzzled', 'Puzzled'),
      EmotionDef('perplexed', 'Perplexed'),
      EmotionDef('moved', 'Moved'),
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
      EmotionDef('melancholy', 'Melancholy'),
      EmotionDef('heartbroken', 'Heartbroken'),
      EmotionDef('gloomy', 'Gloomy'),
      EmotionDef('discouraged', 'Discouraged'),
      EmotionDef('dejected', 'Dejected'),
      EmotionDef('sorrowful', 'Sorrowful'),
      EmotionDef('wistful', 'Wistful'),
      EmotionDef('nostalgic', 'Nostalgic'),
      EmotionDef('abandoned', 'Abandoned'),
      EmotionDef('rejected', 'Rejected'),
      EmotionDef('isolated', 'Isolated'),
      EmotionDef('helpless', 'Helpless'),
      EmotionDef('powerless', 'Powerless'),
      EmotionDef('defeated', 'Defeated'),
      EmotionDef('despairing', 'Despairing'),
      EmotionDef('miserable', 'Miserable'),
      EmotionDef('tearful', 'Tearful'),
      EmotionDef('heavy_hearted', 'Heavy-hearted'),
      EmotionDef('longing', 'Longing'),
      EmotionDef('regretful_sad', 'Full of regret'),
      EmotionDef('unloved', 'Unloved'),
      EmotionDef('left_out', 'Left out'),
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
      EmotionDef('afraid', 'Afraid'),
      EmotionDef('terrified', 'Terrified'),
      EmotionDef('frightened', 'Frightened'),
      EmotionDef('uneasy', 'Uneasy'),
      EmotionDef('apprehensive', 'Apprehensive'),
      EmotionDef('tense', 'Tense'),
      EmotionDef('restless_fear', 'Keyed up'),
      EmotionDef('jittery', 'Jittery'),
      EmotionDef('dread', 'Dread'),
      EmotionDef('hypervigilant', 'Hypervigilant'),
      EmotionDef('threatened', 'Threatened'),
      EmotionDef('vulnerable', 'Vulnerable'),
      EmotionDef('exposed', 'Exposed'),
      EmotionDef('paranoid', 'Paranoid'),
      EmotionDef('on_edge', 'On edge'),
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
      EmotionDef('annoyed', 'Annoyed'),
      EmotionDef('furious', 'Furious'),
      EmotionDef('enraged', 'Enraged'),
      EmotionDef('bitter', 'Bitter'),
      EmotionDef('hostile', 'Hostile'),
      EmotionDef('impatient', 'Impatient'),
      EmotionDef('agitated', 'Agitated'),
      EmotionDef('aggravated', 'Aggravated'),
      EmotionDef('indignant', 'Indignant'),
      EmotionDef('spiteful', 'Spiteful'),
      EmotionDef('envious', 'Envious'),
      EmotionDef('disrespected', 'Disrespected'),
      EmotionDef('violated', 'Violated'),
      EmotionDef('provoked', 'Provoked'),
      EmotionDef('contemptuous', 'Contemptuous'),
    ],
  ),
  EmotionCategory(
    key: 'shame',
    label: 'Shame & guilt',
    color: Color(0xFFC77D99),
    emotions: [
      EmotionDef('ashamed', 'Ashamed'),
      EmotionDef('guilty', 'Guilty'),
      EmotionDef('embarrassed', 'Embarrassed'),
      EmotionDef('disgusted', 'Disgusted'),
      EmotionDef('self_conscious', 'Self-conscious'),
      EmotionDef('regretful', 'Regretful'),
      EmotionDef('humiliated', 'Humiliated'),
      EmotionDef('inadequate', 'Inadequate'),
      EmotionDef('worthless', 'Worthless'),
      EmotionDef('foolish', 'Foolish'),
      EmotionDef('awkward', 'Awkward'),
      EmotionDef('remorseful', 'Remorseful'),
      EmotionDef('judged', 'Judged'),
      EmotionDef('disgusted_self', 'Disgusted with self'),
      EmotionDef('small', 'Small'),
    ],
  ),
  EmotionCategory(
    key: 'stress',
    label: 'Stress',
    color: Color(0xFFD98C4A),
    emotions: [
      EmotionDef('stressed', 'Stressed'),
      EmotionDef('pressured', 'Pressured'),
      EmotionDef('rushed', 'Rushed'),
      EmotionDef('burnt_out', 'Burnt out'),
      EmotionDef('drained', 'Drained'),
      EmotionDef('stretched_thin', 'Stretched thin'),
      EmotionDef('frazzled', 'Frazzled'),
      EmotionDef('scattered', 'Scattered'),
      EmotionDef('stuck', 'Stuck'),
      EmotionDef('trapped', 'Trapped'),
      EmotionDef('torn', 'Torn'),
      EmotionDef('conflicted', 'Conflicted'),
      EmotionDef('indecisive', 'Indecisive'),
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
      EmotionDef('derealized', 'Derealized'),
      EmotionDef('spacey', 'Spacey'),
      EmotionDef('floaty', 'Floaty'),
      EmotionDef('distant', 'Distant'),
      EmotionDef('unreal', 'Unreal'),
      EmotionDef('blank', 'Blank'),
      EmotionDef('shut_down', 'Shut down'),
      EmotionDef('frozen', 'Frozen'),
      EmotionDef('checked_out', 'Checked out'),
      EmotionDef('autopilot', 'Autopilot'),
      EmotionDef('zoned_out', 'Zoned out'),
      EmotionDef('muted', 'Muted'),
    ],
  ),
  EmotionCategory(
    key: 'energy',
    label: 'Energy & body',
    color: Color(0xFF7FA34E),
    emotions: [
      EmotionDef('energized', 'Energized'),
      EmotionDef('refreshed', 'Refreshed'),
      EmotionDef('sluggish', 'Sluggish'),
      EmotionDef('exhausted', 'Exhausted'),
      EmotionDef('wired', 'Wired'),
      EmotionDef('sleepy', 'Sleepy'),
      EmotionDef('achy', 'Achy'),
      EmotionDef('sick', 'Sick'),
      EmotionDef('hungry', 'Hungry'),
      EmotionDef('thirsty', 'Thirsty'),
      EmotionDef('overstimulated', 'Overstimulated'),
      EmotionDef('understimulated', 'Understimulated'),
      EmotionDef('sensory_overloaded', 'Sensory overload'),
      EmotionDef('fidgety', 'Fidgety'),
      EmotionDef('lethargic', 'Lethargic'),
    ],
  ),
  EmotionCategory(
    key: 'plural',
    label: 'Plural experiences',
    color: Color(0xFF7C5F8E),
    emotions: [
      EmotionDef('co_conscious', 'Co-conscious'),
      EmotionDef('blurry', 'Blurry'),
      EmotionDef('pulled_forward', 'Pulled forward'),
      EmotionDef('front_stuck', 'Front-stuck'),
      EmotionDef('switchy', 'Switchy'),
      EmotionDef('passive_influence', 'Passive influence'),
      EmotionDef('headspace_quiet', 'Headspace quiet'),
      EmotionDef('headspace_busy', 'Headspace busy'),
      EmotionDef('lost_time', 'Lost time'),
      EmotionDef('disoriented_after_switch', 'Disoriented after a switch'),
      EmotionDef('unfamiliar_body', 'Body feels unfamiliar'),
      EmotionDef('ownership_unsure', 'Unsure whose feeling'),
      EmotionDef('triggered', 'Triggered'),
      EmotionDef('flooded', 'Flooded'),
      EmotionDef('young_feeling', 'Feeling young'),
      EmotionDef('protective_part_present', 'Protector nearby'),
      EmotionDef('amnesia_gap', 'Memory gap'),
    ],
  ),
  EmotionCategory(
    key: 'complex',
    label: 'Complex',
    color: Color(0xFF5E9C9C),
    emotions: [
      EmotionDef('bittersweet', 'Bittersweet'),
      EmotionDef('ambivalent', 'Ambivalent'),
      EmotionDef('mixed', 'Mixed'),
      EmotionDef('humbled', 'Humbled'),
      EmotionDef('relieved', 'Relieved'),
      EmotionDef('resigned', 'Resigned'),
      EmotionDef('reflective', 'Reflective'),
      EmotionDef('pensive', 'Pensive'),
      EmotionDef('sentimental', 'Sentimental'),
      EmotionDef('vulnerable_open', 'Open & vulnerable'),
      EmotionDef('grateful_sad', 'Grateful but sad'),
      EmotionDef('numb_relief', 'Numb relief'),
      EmotionDef('cautious_hope', 'Cautious hope'),
    ],
  ),
];

/// Every built-in emotion, alphabetically by label.
final List<(EmotionDef, EmotionCategory)> allBuiltInEmotions = [
  for (final c in emotionLibrary)
    for (final e in c.emotions) (e, c),
]..sort((a, b) => a.$1.label.toLowerCase().compareTo(b.$1.label.toLowerCase()));

/// Splits a stored emotion entry `key` or `key@intensity` (1–10).
(String key, int? intensity) parseEmotionEntry(String raw) {
  final at = raw.lastIndexOf('@');
  if (at <= 0) return (raw, null);
  final n = int.tryParse(raw.substring(at + 1));
  if (n == null || n < 1 || n > 10) return (raw, null);
  return (raw.substring(0, at), n);
}

/// Stored form of an emotion with an optional per-emotion intensity.
String encodeEmotionEntry(String key, int? intensity) =>
    intensity == null ? key : '$key@${intensity.clamp(1, 10)}';

final Map<String, (EmotionDef, EmotionCategory)> _emotionIndex = {
  for (final c in emotionLibrary)
    for (final e in c.emotions) e.key: (e, c),
};

/// Display label for a stored emotion entry (any `@intensity` suffix is
/// ignored). Custom emotions (`custom:<label>`) show their label; unknown
/// keys from a newer app version are shown as-is.
String emotionLabel(String raw) {
  final (key, _) = parseEmotionEntry(raw);
  final builtIn = _emotionIndex[key];
  if (builtIn != null) return builtIn.$1.label;
  if (key.startsWith('custom:')) return key.substring(7);
  return key.replaceAll('_', ' ');
}

/// Category colour for an emotion entry, or null for custom/unknown keys.
Color? emotionColor(String raw) =>
    _emotionIndex[parseEmotionEntry(raw).$1]?.$2.color;

EmotionCategory? emotionCategoryOf(String raw) =>
    _emotionIndex[parseEmotionEntry(raw).$1]?.$2;

bool isBuiltInEmotion(String key) => _emotionIndex.containsKey(key);
