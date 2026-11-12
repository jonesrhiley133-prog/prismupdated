import 'package:prism_plurality/domain/preferences/preference_codec.dart';
import 'package:prism_plurality/domain/preferences/preference_definition.dart';

/// A user-created emotion. [key] is `custom:<label>` so check-ins that use
/// it still read sensibly on a device that hasn't synced the definition.
class CustomEmotion {
  const CustomEmotion({
    required this.key,
    required this.label,
    this.categoryKey,
  });

  final String key;
  final String label;

  /// Built-in category it's filed under, or null for "Custom".
  final String? categoryKey;

  static const prefix = 'custom:';

  static String keyFor(String label) => '$prefix${label.trim()}';

  Map<String, Object?> toJson() => {
    'key': key,
    'label': label,
    if (categoryKey != null) 'category': categoryKey,
  };

  static CustomEmotion? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final key = raw['key'];
    final label = raw['label'];
    if (key is! String || label is! String || label.trim().isEmpty) {
      return null;
    }
    final cat = raw['category'];
    return CustomEmotion(
      key: key,
      label: label.trim(),
      categoryKey: cat is String ? cat : null,
    );
  }
}

List<String> _decodeStringList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final v in value)
      if (v is String && v.isNotEmpty) v,
  ];
}

/// Emotion keys the system has starred. Order is the user's order.
const favoriteEmotionsPreference = PreferenceDefinition<List<String>>(
  key: 'mood.favorite_emotions',
  scope: PreferenceScope.appSynced,
  defaultValue: <String>[],
  codec: JsonPreferenceCodec<List<String>>(
    toJson: _encodeStringList,
    fromJson: _decodeStringList,
  ),
  introducedInAppVersion: '0.16.0',
  introducedInSchemaVersion: 43,
);

Object? _encodeStringList(List<String> v) => v;

/// User-created emotions.
const customEmotionsPreference = PreferenceDefinition<List<CustomEmotion>>(
  key: 'mood.custom_emotions',
  scope: PreferenceScope.appSynced,
  defaultValue: <CustomEmotion>[],
  codec: JsonPreferenceCodec<List<CustomEmotion>>(
    toJson: _encodeCustom,
    fromJson: _decodeCustom,
  ),
  introducedInAppVersion: '0.16.0',
  introducedInSchemaVersion: 43,
);

Object? _encodeCustom(List<CustomEmotion> v) => [for (final e in v) e.toJson()];

List<CustomEmotion> _decodeCustom(Object? value) {
  if (value is! List) return const [];
  return value.map(CustomEmotion.fromJson).whereType<CustomEmotion>().toList();
}
