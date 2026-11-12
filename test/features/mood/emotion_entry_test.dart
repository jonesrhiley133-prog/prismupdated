import 'package:flutter_test/flutter_test.dart';

import 'package:prism_plurality/features/mood/data/emotion_library.dart';
import 'package:prism_plurality/features/mood/widgets/emotion_picker.dart';

void main() {
  test('emotion entries round-trip with and without intensity', () {
    expect(parseEmotionEntry('anxious'), ('anxious', null));
    expect(parseEmotionEntry('anxious@7'), ('anxious', 7));
    expect(parseEmotionEntry('anxious@0'), ('anxious@0', null));
    expect(parseEmotionEntry('custom:me@home'), ('custom:me@home', null));
    expect(encodeEmotionEntry('calm', null), 'calm');
    expect(encodeEmotionEntry('calm', 12), 'calm@10');
    final sel = decodeEmotionSelection(['calm', 'anxious@4', 'custom:Fizzy@9']);
    expect(sel, {'calm': null, 'anxious': 4, 'custom:Fizzy': 9});
    expect(encodeEmotionSelection(sel), [
      'calm',
      'anxious@4',
      'custom:Fizzy@9',
    ]);
  });

  test('labels resolve for built-in, custom, intensity and unknown keys', () {
    expect(emotionLabel('anxious@7'), 'Anxious');
    expect(emotionLabel('custom:Sparkly'), 'Sparkly');
    expect(emotionLabel('some_future_key'), 'some future key');
  });

  test('library is large, unique, and keeps every original key', () {
    final keys = allBuiltInEmotions.map((e) => e.$1.key).toList();
    expect(keys.length, greaterThanOrEqualTo(250));
    expect(keys.toSet().length, keys.length);
    const original = [
      'happy',
      'content',
      'grateful',
      'excited',
      'proud',
      'hopeful',
      'playful',
      'loved',
      'confident',
      'inspired',
      'calm',
      'relaxed',
      'safe',
      'grounded',
      'rested',
      'peaceful',
      'connected',
      'sad',
      'lonely',
      'disappointed',
      'hurt',
      'grieving',
      'empty',
      'hopeless',
      'homesick',
      'anxious',
      'scared',
      'worried',
      'overwhelmed',
      'nervous',
      'insecure',
      'panicked',
      'unsafe',
      'angry',
      'frustrated',
      'irritated',
      'resentful',
      'jealous',
      'betrayed',
      'defensive',
      'ashamed',
      'guilty',
      'embarrassed',
      'disgusted',
      'self_conscious',
      'regretful',
      'surprised',
      'confused',
      'amazed',
      'startled',
      'curious',
      'numb',
      'foggy',
      'dissociated',
      'detached',
      'depersonalized',
      'tired',
      'bored',
      'restless',
    ];
    expect(keys.toSet().containsAll(original), isTrue);
  });
}
