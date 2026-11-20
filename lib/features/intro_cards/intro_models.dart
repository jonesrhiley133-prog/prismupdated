import 'package:prism_plurality/shared/ui_kit.dart';

/// Visual design of a card.
class IntroTemplate {
  const IntroTemplate({
    required this.id,
    required this.name,
    required this.bg1,
    required this.bg2,
    required this.border,
    required this.ink,
    this.font = 'serif',
    this.pattern = 'stars',
    this.record,
  });

  final String id;
  final String name;
  final int bg1;
  final int bg2;
  final int border;
  final int ink;

  /// serif, display, mono, rounded, standard
  final String font;

  /// stars, moons, suns, leaves, waves, none
  final String pattern;
  final TrackerRecord? record;

  TextStyle style(TextStyle base) => switch (font) {
    'serif' => base.copyWith(fontFamily: 'Georgia', fontFamilyFallback: const ['Cambria', 'Times New Roman', 'serif']),
    'display' => base.copyWith(fontFamily: 'Unbounded'),
    'mono' => base.copyWith(fontFamily: 'ui-monospace', fontFamilyFallback: const ['Menlo', 'Consolas', 'monospace']),
    'rounded' => base.copyWith(fontFamily: 'ui-rounded', fontFamilyFallback: const ['SF Pro Rounded']),
    _ => base,
  };

  /// This design with the card's own colours (Card colours in the editor).
  IntroTemplate withCardColors(TrackerRecord card) {
    final c = card.fields['colors'];
    if (c is! Map) return this;
    int pick(String k, int fallback) => (c[k] as num?)?.toInt() ?? fallback;
    return IntroTemplate(id: id, name: name, bg1: pick('bg1', bg1), bg2: pick('bg2', bg2), border: pick('border', border), ink: pick('ink', ink), font: font, pattern: pattern, record: record);
  }

  Map<String, Object?> toFields() => {'bg1': bg1, 'bg2': bg2, 'border': border, 'ink': ink, 'font': font, 'pattern': pattern};

  static IntroTemplate fromRecord(TrackerRecord r) => IntroTemplate(
    id: r.id,
    name: r.title,
    bg1: r.integer('bg1') ?? 0xFF1E1B3A,
    bg2: r.integer('bg2') ?? 0xFF3D2C6B,
    border: r.integer('border') ?? 0xFFD4AF37,
    ink: r.integer('ink') ?? 0xFFF6EBD0,
    font: r.str('font') ?? 'serif',
    pattern: r.str('pattern') ?? 'stars',
    record: r,
  );
}

const builtInTemplates = [
  IntroTemplate(id: 'celestial', name: 'Celestial', bg1: 0xFF1E1B3A, bg2: 0xFF3D2C6B, border: 0xFFD4AF37, ink: 0xFFF6EBD0, pattern: 'stars'),
  IntroTemplate(id: 'sun', name: 'The Sun', bg1: 0xFFFFE29A, bg2: 0xFFF6A44C, border: 0xFF8A4B08, ink: 0xFF3B2005, pattern: 'suns'),
  IntroTemplate(id: 'moon', name: 'The Moon', bg1: 0xFF0F2027, bg2: 0xFF2C5364, border: 0xFFC0C8D6, ink: 0xFFE8EEF5, pattern: 'moons'),
  IntroTemplate(id: 'forest', name: 'Forest', bg1: 0xFF1D3B2A, bg2: 0xFF4E7A4F, border: 0xFFE3D5A3, ink: 0xFFF3EEDA, pattern: 'leaves'),
  IntroTemplate(id: 'ember', name: 'Ember', bg1: 0xFF3A0F0F, bg2: 0xFF8E2C1B, border: 0xFFF2B36B, ink: 0xFFFBE7D2, pattern: 'suns', font: 'display'),
  IntroTemplate(id: 'ocean', name: 'Ocean', bg1: 0xFF03396C, bg2: 0xFF6497B1, border: 0xFFE0F4FF, ink: 0xFFF2FBFF, pattern: 'waves', font: 'rounded'),
  IntroTemplate(id: 'parchment', name: 'Parchment', bg1: 0xFFF4E9D0, bg2: 0xFFE2CFA4, border: 0xFF6B4E2E, ink: 0xFF3A2A17, pattern: 'none'),
];

/// Information fields shown on a card.
class IntroField {
  const IntroField(this.key, this.en, this.es, {this.multiline = false});
  final String key;
  final String en;
  final String es;
  final bool multiline;
}

const introFields = [
  IntroField('aliases', 'Aliases', 'Alias'),
  IntroField('pronouns', 'Pronouns', 'Pronombres'),
  IntroField('age', 'Age or age range', 'Edad o rango de edad'),
  IntroField('roles', 'Roles', 'Roles'),
  IntroField('personality', 'Personality', 'Personalidad', multiline: true),
  IntroField('interests', 'Interests & hobbies', 'Intereses y aficiones', multiline: true),
  IntroField('likes', 'Likes', 'Le gusta', multiline: true),
  IntroField('dislikes', 'Dislikes', 'No le gusta', multiline: true),
  IntroField('favorites', 'Favourite things', 'Cosas favoritas', multiline: true),
  IntroField('description', 'About me', 'Sobre mí', multiline: true),
  IntroField('intro', 'Introduction message', 'Mensaje de presentación', multiline: true),
];
