/// Stable anatomical identifiers and normalized full-sheet anchors. Left/right
/// always refer to the body: left is screen-right in front view.
class AnatomicalRegion {
  const AnatomicalRegion(
    this.id,
    this.label,
    this.group,
    this.side,
    this.view,
    this.x,
    this.y,
  );
  final String id, label, group, side, view;
  final double x, y;
}

final anatomicalRegions = <AnatomicalRegion>[
  for (final view in ['front', 'back']) ...[
    for (final e in <String, (String, double, double)>{
      if (view == 'front') ...{
        'forehead': ('Forehead', .5, .065),
        'nose': ('Nose', .5, .105),
        'sinuses': ('Sinuses', .5, .09),
        'jaw': ('Jaw', .5, .13),
        'teeth': ('Teeth', .5, .12),
        'gums': ('Gums', .5, .125),
        'tongue': ('Tongue', .5, .13),
        'lips': ('Lips', .5, .115),
        'throat': ('Throat', .5, .165),
        'sternum': ('Sternum', .5, .265),
        'chest': ('Chest', .5, .245),
        'upper_abdomen': ('Upper abdomen', .5, .33),
        'mid_abdomen': ('Mid abdomen', .5, .37),
        'lower_abdomen': ('Lower abdomen', .5, .405),
        'pelvis': ('Pelvis', .5, .45),
      } else ...{
        'back_of_head': ('Back of head', .5, .09),
        'upper_back': ('Upper back', .5, .25),
        'mid_back': ('Mid-back', .5, .32),
        'lower_back': ('Lower back', .5, .39),
        'spine': ('Spine', .5, .31),
        'tailbone': ('Tailbone', .5, .46),
      },
      'scalp': ('Scalp', .5, .04),
      'crown': ('Crown', .5, .025),
      'neck': ('${view == 'front' ? 'Front' : 'Back'} of neck', .5, .17),
    }.entries)
      AnatomicalRegion(
        '${view}_${e.key}',
        e.value.$1,
        e.key,
        'midline',
        view,
        e.value.$2,
        e.value.$3,
      ),
    for (final side in ['left', 'right']) ..._pairedRegions(side, view),
  ],
  const AnatomicalRegion(
    'whole',
    'Whole body',
    'whole',
    'unspecified',
    'unspecified',
    .5,
    .5,
  ),
  const AnatomicalRegion(
    'hard_to_locate',
    'Hard to locate',
    'unknown',
    'unspecified',
    'unspecified',
    .5,
    .5,
  ),
  const AnatomicalRegion(
    'custom',
    'Custom location',
    'custom',
    'unspecified',
    'unspecified',
    .5,
    .5,
  ),
];

Iterable<AnatomicalRegion> _pairedRegions(String side, String view) sync* {
  final sign = (side == 'left') == (view == 'front') ? 1 : -1;
  final regions = <String, (String, double, double)>{
    'temple': ('Temple', .085, .07),
    'ear': ('Ear', .115, .1),
    if (view == 'front') ...{
      'eye': ('Eye', .045, .085),
      'eyelid': ('Eyelid', .045, .08),
      'cheek': ('Cheek', .065, .11),
      'collarbone': ('Collarbone', .095, .21),
      'ribs': ('Ribs', .105, .29),
    } else
      'shoulder_blade': ('Shoulder blade', .085, .26),
    'shoulder': (
      '${view == 'front' ? 'Front' : 'Back'} of shoulder',
      .15,
      .225,
    ),
    'flank': ('Flank', .12, .37),
    'hip': ('Hip', .13, .44),
    if (view == 'back') 'buttock': ('Buttock', .08, .48),
    'upper_arm': ('Upper arm', .19, .29),
    'elbow': ('Elbow', .22, .36),
    'forearm': ('Forearm', .255, .415),
    'wrist': ('Wrist', .285, .465),
    'hand': (view == 'front' ? 'Palm' : 'Back of hand', .30, .50),
    'thumb': ('Thumb', .267, .51),
    for (final e in ['index', 'middle', 'ring', 'little'].indexed) ...{
      '${e.$2}_finger': ('${e.$2} finger', .285 + e.$1 * .018, .54),
      '${e.$2}_fingertip': ('${e.$2} fingertip', .285 + e.$1 * .018, .56),
    },
    'thumb_tip': ('Thumb tip', .26, .53),
    'thigh': ('${view == 'front' ? 'Front' : 'Back'} of thigh', .085, .59),
    'inner_thigh': ('Inner thigh', .04, .59),
    'knee': (view == 'front' ? 'Knee' : 'Back of knee', .085, .70),
    if (view == 'front')
      'shin': ('Shin', .085, .79)
    else
      'calf': ('Calf', .085, .79),
    'ankle': ('Ankle', .085, .88),
    'heel': ('Heel', .085, .91),
    'arch': ('Arch', .07, .94),
    'sole': ('Sole', .085, .945),
    'ball_of_foot': ('Ball of foot', .085, .96),
    'top_of_foot': ('Top of foot', .085, .93),
    for (final e in ['big', 'second', 'third', 'fourth', 'little'].indexed)
      '${e.$2}_toe': ('${e.$2} toe', .05 + e.$1 * .018, .975),
  };
  for (final e in regions.entries) {
    yield AnatomicalRegion(
      '${view}_${side}_${e.key}',
      '${side == 'left' ? 'Left' : 'Right'} ${e.value.$1}',
      e.key,
      side,
      view,
      .5 + sign * e.value.$2,
      e.value.$3,
    );
  }
}

const generalDescriptors = [
  'aching',
  'dull',
  'sharp',
  'stabbing',
  'burning',
  'throbbing',
  'pulsing',
  'squeezing',
  'pulling',
  'tight',
  'tender',
  'hot',
  'cold',
  'crawling',
  'prickly',
  'electric',
  'tingly',
  'numb',
  'heavy',
  'weak',
  'shaky',
  'sore',
  'itchy',
  'stiff',
  'swollen',
  'relaxed',
  'warm',
  'loose',
  'light',
  'comfortably heavy',
  'neutral',
];
List<String> descriptorsFor(String group) => [
  ...generalDescriptors,
  ...switch (group) {
    'ear' => ['ringing', 'buzzing', 'muffled hearing', 'popping', 'fullness'],
    'eye' || 'eyelid' => [
      'gritty',
      'watery',
      'dry',
      'twitching',
      'strained',
      'light-sensitive',
    ],
    'nose' || 'sinuses' => [
      'blocked',
      'dripping',
      'pressure behind the eyes',
      'stinging',
    ],
    'jaw' ||
    'teeth' ||
    'gums' => ['clenching', 'clicking', 'locking', 'tooth sensitivity'],
    'throat' => [
      'scratchy',
      'hoarse',
      'dry',
      'lump sensation',
      'pain when swallowing',
    ],
    'chest' || 'ribs' || 'sternum' => [
      'fluttering',
      'pounding',
      'tightness',
      'discomfort when taking a deep breath',
    ],
    'upper_abdomen' || 'mid_abdomen' || 'lower_abdomen' => [
      'knotted',
      'cramping',
      'bloated',
      'gurgling',
      'rolling',
    ],
    'upper_back' || 'mid_back' || 'lower_back' || 'neck' || 'spine' => [
      'spasm',
      'seized up',
      'radiating',
      'tight band',
      'pain when turning',
    ],
    'knee' ||
    'elbow' ||
    'wrist' ||
    'ankle' ||
    'shoulder' => ['catching', 'locking', 'clicking', 'grinding', 'giving way'],
    _
        when group.contains('finger') ||
            group == 'hand' ||
            group.contains('thumb') =>
      ['pins and needles', 'reduced grip', 'numb fingertips', 'trembling'],
    _
        when [
              'thigh',
              'inner_thigh',
              'shin',
              'calf',
              'ankle',
              'heel',
              'arch',
              'sole',
              'ball_of_foot',
              'top_of_foot',
            ].contains(group) ||
            group.contains('toe') =>
      [
        'restless',
        'cramping',
        'dragging',
        'unsteady',
        'pressure when standing',
      ],
    _ => <String>[],
  },
];

const symptomCategories = <String, List<String>>{
  'General': [
    'fatigue',
    'feverishness',
    'chills',
    'sweating',
    'weakness',
    'feeling unwell',
  ],
  'Nose, throat, and breathing': [
    'congestion',
    'runny nose',
    'sore throat',
    'hoarseness',
    'cough',
    'shortness of breath',
  ],
  'Head, eyes, ears, and mouth': [
    'headache',
    'pressure',
    'dizziness',
    'light sensitivity',
    'ringing',
    'ear fullness',
    'dry mouth',
    'altered taste or smell',
  ],
  'Digestive': [
    'nausea',
    'vomiting',
    'reflux',
    'cramping',
    'bloating',
    'appetite changes',
    'constipation',
    'diarrhea',
  ],
  'Skin': [
    'itching',
    'burning',
    'tenderness',
    'redness',
    'dryness',
    'rash',
    'swelling',
  ],
  'Muscles and joints': [
    'aching',
    'stiffness',
    'soreness',
    'cramping',
    'weakness',
    'restricted movement',
  ],
  'Urinary': ['urgency', 'frequency', 'discomfort'],
  'Sensation and coordination': [
    'tingling',
    'numbness',
    'shakiness',
    'unsteadiness',
  ],
};
String healthSearchText(String text) {
  final lower = text.toLowerCase();
  const aliases = {
    'tingl': 'pins needles prickly',
    'fatigue': 'tired exhausted',
    'congestion': 'blocked stuffy nose',
    'nausea': 'sick queasy',
    'shortness of breath': 'breathless',
    'diarrhea': 'diarrhoea loose stool',
    'ringing': 'tinnitus',
  };
  return '$lower ${aliases.entries.where((e) => lower.contains(e.key)).map((e) => e.value).join(' ')}';
}
