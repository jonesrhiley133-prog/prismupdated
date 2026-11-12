/// Body regions and sensations for body-sensation mapping.
///
/// Stored on a mood entry as `region` or `region:sensation` strings, e.g.
/// `chest:tight`.
class BodyRegion {
  const BodyRegion(this.key, this.label);
  final String key;
  final String label;
}

const bodyRegions = <BodyRegion>[
  BodyRegion('head', 'Head'),
  BodyRegion('face', 'Face / jaw'),
  BodyRegion('throat', 'Throat'),
  BodyRegion('shoulders', 'Shoulders'),
  BodyRegion('chest', 'Chest'),
  BodyRegion('stomach', 'Stomach'),
  BodyRegion('back', 'Back'),
  BodyRegion('arms', 'Arms'),
  BodyRegion('hands', 'Hands'),
  BodyRegion('legs', 'Legs'),
  BodyRegion('feet', 'Feet'),
  BodyRegion('whole', 'Whole body'),
];

const bodySensations = <String, String>{
  'tense': 'Tense',
  'tight': 'Tight',
  'aching': 'Aching',
  'pain': 'Pain',
  'warm': 'Warm',
  'cold': 'Cold',
  'tingling': 'Tingling',
  'numb': 'Numb',
  'heavy': 'Heavy',
  'light': 'Light',
  'buzzing': 'Buzzing',
  'shaky': 'Shaky',
  'nauseous': 'Nauseous',
  'fluttery': 'Fluttery',
};

/// Splits a stored `region[:sensation]` value.
(String region, String? sensation) parseBodySensation(String raw) {
  final i = raw.indexOf(':');
  if (i < 0) return (raw, null);
  return (raw.substring(0, i), raw.substring(i + 1));
}

String bodyRegionLabel(String key) {
  for (final r in bodyRegions) {
    if (r.key == key) return r.label;
  }
  return key;
}

/// "Chest · Tight" style label for a stored value.
String bodySensationLabel(String raw) {
  final (region, sensation) = parseBodySensation(raw);
  final regionLabel = bodyRegionLabel(region);
  if (sensation == null || sensation.isEmpty) return regionLabel;
  return '$regionLabel · ${bodySensations[sensation] ?? sensation}';
}
