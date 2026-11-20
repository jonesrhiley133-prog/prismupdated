import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// The Body Map's anatomy: regions, the drawings they live on, and the
/// sensation vocabulary that fits each area.
///
/// Sides are always the **body's own** left and right. On the front view the
/// body's right is on the viewer's left; on the back view it is on the
/// viewer's right. Each drawing is authored in its own coordinate space
/// ([BodySheet.size]) and markers are stored normalised to 0–1 so they stay
/// put however large the drawing is shown.

enum BodySide { left, right, center }

extension BodySideText on BodySide {
  String get key => name;
  static BodySide parse(String? s) => BodySide.values.where((v) => v.name == s).firstOrNull ?? BodySide.center;
}

/// The drawings the map can show.
enum BodyView { front, back, face, handPalm, handBack, footTop, footSole }

extension BodyViewText on BodyView {
  static BodyView parse(String? s) => BodyView.values.where((v) => v.name == s).firstOrNull ?? BodyView.front;
  bool get isZoom => this != BodyView.front && this != BodyView.back;
}

/// Descriptor groups: which region-specific sensation words apply.
enum DescriptorGroup { none, head, ears, eyes, nose, jaw, mouth, throat, chest, abdomen, back, joint, hand, leg, skin }

/// One selectable place on the body.
class BodyRegion {
  const BodyRegion(this.id, this.en, this.es, {this.sided = false, this.group = DescriptorGroup.none, this.synonyms = const [], this.section = RegionSection.torso, this.anchor});
  final String id;
  final String en;
  final String es;

  /// Whether the region exists on both sides (left/right).
  final bool sided;
  final DescriptorGroup group;

  /// Extra search words (lower case).
  final List<String> synonyms;
  final RegionSection section;

  /// Where to show markers for this region on the front/back figure when
  /// it has no exact point (or lives on a zoom sheet): (view, x, y) in the
  /// figure's 200×460 space for the body's **right** side; left mirrors.
  final (BodyView, double, double)? anchor;

  String label(bool es, [BodySide side = BodySide.center]) {
    final base = es ? this.es : en;
    if (!sided || side == BodySide.center) return base;
    return es ? '$base (${side == BodySide.left ? 'izq.' : 'der.'})' : '${side == BodySide.left ? 'Left' : 'Right'} ${base[0].toLowerCase()}${base.substring(1)}';
  }
}

enum RegionSection { general, head, face, mouth, neck, torso, back, arm, hand, leg, foot }

String regionSectionLabel(RegionSection s, bool es) => switch (s) {
  RegionSection.general => es ? 'General' : 'General',
  RegionSection.head => es ? 'Cabeza' : 'Head',
  RegionSection.face => es ? 'Cara' : 'Face',
  RegionSection.mouth => es ? 'Boca' : 'Mouth',
  RegionSection.neck => es ? 'Cuello y garganta' : 'Neck & throat',
  RegionSection.torso => es ? 'Pecho, abdomen y pelvis' : 'Chest, abdomen & pelvis',
  RegionSection.back => es ? 'Espalda' : 'Back',
  RegionSection.arm => es ? 'Hombros y brazos' : 'Shoulders & arms',
  RegionSection.hand => es ? 'Manos y dedos' : 'Hands & fingers',
  RegionSection.leg => es ? 'Piernas' : 'Legs',
  RegionSection.foot => es ? 'Pies y dedos' : 'Feet & toes',
};

/// Special locations that aren't a place on the drawing.
const whole = 'whole_body';
const hardToLocate = 'hard_to_locate';
const customLocation = 'custom';

const _r = RegionSection.general;

final List<BodyRegion> bodyRegions = [
  // General / special
  const BodyRegion(whole, 'Whole body', 'Todo el cuerpo', section: _r, synonyms: ['everywhere', 'all over', 'entire']),
  const BodyRegion(hardToLocate, 'Hard to locate', 'Difícil de ubicar', section: _r, synonyms: ['unsure', 'unknown', 'somewhere']),
  const BodyRegion(customLocation, 'Custom location', 'Ubicación personalizada', section: _r),
  // Coarse areas (also used by entries carried over from Mood).
  const BodyRegion('head', 'Head (general)', 'Cabeza (general)', section: _r, group: DescriptorGroup.head, anchor: (BodyView.front, 100, 36)),
  const BodyRegion('face_general', 'Face / jaw (general)', 'Cara / mandíbula (general)', section: _r, group: DescriptorGroup.jaw, anchor: (BodyView.front, 100, 48)),
  const BodyRegion('shoulders', 'Shoulders (general)', 'Hombros (general)', section: _r, anchor: (BodyView.front, 64, 94)),
  const BodyRegion('back', 'Back (general)', 'Espalda (general)', section: _r, group: DescriptorGroup.back, anchor: (BodyView.back, 100, 150)),
  const BodyRegion('arms', 'Arms (general)', 'Brazos (general)', section: _r, anchor: (BodyView.front, 52, 160)),
  const BodyRegion('hands', 'Hands (general)', 'Manos (general)', section: _r, group: DescriptorGroup.hand, anchor: (BodyView.front, 42, 250)),
  const BodyRegion('legs', 'Legs (general)', 'Piernas (general)', section: _r, group: DescriptorGroup.leg, anchor: (BodyView.front, 85, 330)),
  const BodyRegion('feet', 'Feet (general)', 'Pies (general)', section: _r, group: DescriptorGroup.leg, anchor: (BodyView.front, 88, 430)),

  // Head
  const BodyRegion('scalp', 'Scalp', 'Cuero cabelludo', section: RegionSection.head, group: DescriptorGroup.head, synonyms: ['skin of head', 'hair'], anchor: (BodyView.back, 100, 26)),
  const BodyRegion('crown', 'Crown', 'Coronilla', section: RegionSection.head, group: DescriptorGroup.head, synonyms: ['top of head', 'vertex'], anchor: (BodyView.front, 100, 15)),
  const BodyRegion('forehead', 'Forehead', 'Frente', section: RegionSection.head, group: DescriptorGroup.head, synonyms: ['brow'], anchor: (BodyView.front, 100, 25)),
  const BodyRegion('temple', 'Temple', 'Sien', sided: true, section: RegionSection.head, group: DescriptorGroup.head, anchor: (BodyView.front, 82, 31)),
  const BodyRegion('back_of_head', 'Back of head', 'Nuca / parte posterior de la cabeza', section: RegionSection.head, group: DescriptorGroup.head, synonyms: ['occipital', 'occiput'], anchor: (BodyView.back, 100, 46)),

  // Face
  const BodyRegion('eye', 'Eye', 'Ojo', sided: true, section: RegionSection.face, group: DescriptorGroup.eyes, synonyms: ['vision', 'eyeball'], anchor: (BodyView.front, 91, 38)),
  const BodyRegion('eyelid', 'Eyelid', 'Párpado', sided: true, section: RegionSection.face, group: DescriptorGroup.eyes, synonyms: ['lid'], anchor: (BodyView.front, 91, 35)),
  const BodyRegion('ear', 'Ear', 'Oído / oreja', sided: true, section: RegionSection.face, group: DescriptorGroup.ears, synonyms: ['hearing'], anchor: (BodyView.front, 79, 40)),
  const BodyRegion('nose', 'Nose', 'Nariz', section: RegionSection.face, group: DescriptorGroup.nose, synonyms: ['nostril'], anchor: (BodyView.front, 100, 44)),
  const BodyRegion('sinus', 'Sinuses', 'Senos nasales', sided: true, section: RegionSection.face, group: DescriptorGroup.nose, synonyms: ['sinus', 'behind eyes'], anchor: (BodyView.front, 93, 45)),
  const BodyRegion('cheek', 'Cheek', 'Mejilla', sided: true, section: RegionSection.face, group: DescriptorGroup.skin, anchor: (BodyView.front, 88, 48)),
  const BodyRegion('jaw', 'Jaw', 'Mandíbula', sided: true, section: RegionSection.face, group: DescriptorGroup.jaw, synonyms: ['tmj', 'chin'], anchor: (BodyView.front, 90, 56)),
  const BodyRegion('lips', 'Lips', 'Labios', section: RegionSection.face, group: DescriptorGroup.mouth, synonyms: ['mouth'], anchor: (BodyView.front, 100, 54)),
  // Mouth (inside — chosen from the face sheet's list)
  const BodyRegion('teeth', 'Teeth', 'Dientes', section: RegionSection.mouth, group: DescriptorGroup.jaw, synonyms: ['tooth', 'molar'], anchor: (BodyView.front, 100, 53)),
  const BodyRegion('gums', 'Gums', 'Encías', section: RegionSection.mouth, group: DescriptorGroup.mouth, anchor: (BodyView.front, 100, 53)),
  const BodyRegion('tongue', 'Tongue', 'Lengua', section: RegionSection.mouth, group: DescriptorGroup.mouth, synonyms: ['taste'], anchor: (BodyView.front, 100, 54)),

  // Neck
  const BodyRegion('throat', 'Throat', 'Garganta', section: RegionSection.neck, group: DescriptorGroup.throat, synonyms: ['swallowing', 'voice'], anchor: (BodyView.front, 100, 72)),
  const BodyRegion('neck_front', 'Front of neck', 'Parte delantera del cuello', section: RegionSection.neck, group: DescriptorGroup.back, anchor: (BodyView.front, 100, 66)),
  const BodyRegion('neck_back', 'Back of neck', 'Parte trasera del cuello', section: RegionSection.neck, group: DescriptorGroup.back, synonyms: ['nape'], anchor: (BodyView.back, 100, 70)),

  // Torso
  const BodyRegion('collarbone', 'Collarbone', 'Clavícula', sided: true, synonyms: ['clavicle'], group: DescriptorGroup.joint, anchor: (BodyView.front, 89, 83)),
  const BodyRegion('chest', 'Chest', 'Pecho', sided: true, group: DescriptorGroup.chest, synonyms: ['breast', 'pectoral', 'heart'], anchor: (BodyView.front, 84, 104)),
  const BodyRegion('sternum', 'Sternum', 'Esternón', group: DescriptorGroup.chest, synonyms: ['breastbone', 'centre of chest', 'center of chest'], anchor: (BodyView.front, 100, 108)),
  const BodyRegion('ribs', 'Ribs', 'Costillas', sided: true, group: DescriptorGroup.chest, synonyms: ['rib cage', 'side of chest'], anchor: (BodyView.front, 77, 136)),
  const BodyRegion('abdomen_upper', 'Upper abdomen', 'Abdomen superior', group: DescriptorGroup.abdomen, synonyms: ['stomach', 'upper belly', 'epigastric'], anchor: (BodyView.front, 100, 144)),
  const BodyRegion('abdomen_mid', 'Mid abdomen', 'Abdomen medio', group: DescriptorGroup.abdomen, synonyms: ['belly', 'stomach', 'navel', 'belly button'], anchor: (BodyView.front, 100, 171)),
  const BodyRegion('abdomen_lower', 'Lower abdomen', 'Abdomen inferior', group: DescriptorGroup.abdomen, synonyms: ['lower belly', 'bladder', 'gut'], anchor: (BodyView.front, 100, 198)),
  const BodyRegion('flank', 'Flank', 'Costado', sided: true, group: DescriptorGroup.abdomen, synonyms: ['side', 'kidney area'], anchor: (BodyView.front, 72, 178)),
  const BodyRegion('hip', 'Hip', 'Cadera', sided: true, group: DescriptorGroup.joint, anchor: (BodyView.front, 70, 218)),
  const BodyRegion('pelvis', 'Pelvis', 'Pelvis', group: DescriptorGroup.abdomen, synonyms: ['groin', 'pelvic'], anchor: (BodyView.front, 100, 226)),
  const BodyRegion('buttock', 'Buttock', 'Glúteo', sided: true, section: RegionSection.back, synonyms: ['bottom', 'glute', 'seat'], anchor: (BodyView.back, 84, 226)),

  // Back
  const BodyRegion('upper_back', 'Upper back', 'Espalda alta', sided: true, section: RegionSection.back, group: DescriptorGroup.back, anchor: (BodyView.back, 86, 98)),
  const BodyRegion('shoulder_blade', 'Shoulder blade', 'Omóplato', sided: true, section: RegionSection.back, group: DescriptorGroup.back, synonyms: ['scapula'], anchor: (BodyView.back, 84, 110)),
  const BodyRegion('mid_back', 'Mid-back', 'Espalda media', section: RegionSection.back, group: DescriptorGroup.back, synonyms: ['middle back'], anchor: (BodyView.back, 100, 144)),
  const BodyRegion('lower_back', 'Lower back', 'Zona lumbar', section: RegionSection.back, group: DescriptorGroup.back, synonyms: ['lumbar', 'low back'], anchor: (BodyView.back, 100, 186)),
  const BodyRegion('spine', 'Spine', 'Columna', section: RegionSection.back, group: DescriptorGroup.back, synonyms: ['backbone', 'vertebrae'], anchor: (BodyView.back, 100, 150)),
  const BodyRegion('tailbone', 'Tailbone', 'Coxis', section: RegionSection.back, group: DescriptorGroup.back, synonyms: ['coccyx', 'sacrum'], anchor: (BodyView.back, 100, 214)),

  // Arms
  const BodyRegion('shoulder_front', 'Front of shoulder', 'Parte delantera del hombro', sided: true, section: RegionSection.arm, group: DescriptorGroup.joint, anchor: (BodyView.front, 63, 96)),
  const BodyRegion('shoulder_back', 'Back of shoulder', 'Parte trasera del hombro', sided: true, section: RegionSection.arm, group: DescriptorGroup.joint, anchor: (BodyView.back, 63, 96)),
  const BodyRegion('upper_arm_front', 'Front of upper arm', 'Parte delantera del brazo', sided: true, section: RegionSection.arm, synonyms: ['bicep', 'biceps'], anchor: (BodyView.front, 53, 132)),
  const BodyRegion('upper_arm_back', 'Back of upper arm', 'Parte trasera del brazo', sided: true, section: RegionSection.arm, synonyms: ['tricep', 'triceps'], anchor: (BodyView.back, 53, 132)),
  const BodyRegion('elbow_front', 'Inner elbow', 'Pliegue del codo', sided: true, section: RegionSection.arm, group: DescriptorGroup.joint, synonyms: ['elbow crease', 'front of elbow'], anchor: (BodyView.front, 50, 167)),
  const BodyRegion('elbow_back', 'Back of elbow', 'Codo', sided: true, section: RegionSection.arm, group: DescriptorGroup.joint, synonyms: ['elbow', 'funny bone'], anchor: (BodyView.back, 50, 167)),
  const BodyRegion('forearm_front', 'Front of forearm', 'Antebrazo (interior)', sided: true, section: RegionSection.arm, anchor: (BodyView.front, 47, 198)),
  const BodyRegion('forearm_back', 'Back of forearm', 'Antebrazo (exterior)', sided: true, section: RegionSection.arm, anchor: (BodyView.back, 47, 198)),
  const BodyRegion('wrist_front', 'Front of wrist', 'Muñeca (interior)', sided: true, section: RegionSection.arm, group: DescriptorGroup.joint, synonyms: ['wrist', 'inner wrist'], anchor: (BodyView.front, 44, 231)),
  const BodyRegion('wrist_back', 'Back of wrist', 'Muñeca (exterior)', sided: true, section: RegionSection.arm, group: DescriptorGroup.joint, synonyms: ['wrist'], anchor: (BodyView.back, 44, 231)),

  // Hands
  const BodyRegion('palm', 'Palm', 'Palma', sided: true, section: RegionSection.hand, group: DescriptorGroup.hand, synonyms: ['hand'], anchor: (BodyView.front, 42, 250)),
  const BodyRegion('back_of_hand', 'Back of hand', 'Dorso de la mano', sided: true, section: RegionSection.hand, group: DescriptorGroup.hand, synonyms: ['hand', 'knuckles'], anchor: (BodyView.back, 42, 250)),
  const BodyRegion('thumb', 'Thumb', 'Pulgar', sided: true, section: RegionSection.hand, group: DescriptorGroup.hand, anchor: (BodyView.front, 46, 254)),
  const BodyRegion('finger_index', 'Index finger', 'Dedo índice', sided: true, section: RegionSection.hand, group: DescriptorGroup.hand, synonyms: ['pointer', 'first finger', 'forefinger'], anchor: (BodyView.front, 42, 262)),
  const BodyRegion('finger_middle', 'Middle finger', 'Dedo corazón', sided: true, section: RegionSection.hand, group: DescriptorGroup.hand, anchor: (BodyView.front, 42, 263)),
  const BodyRegion('finger_ring', 'Ring finger', 'Dedo anular', sided: true, section: RegionSection.hand, group: DescriptorGroup.hand, synonyms: ['fourth finger'], anchor: (BodyView.front, 41, 262)),
  const BodyRegion('finger_little', 'Little finger', 'Dedo meñique', sided: true, section: RegionSection.hand, group: DescriptorGroup.hand, synonyms: ['pinky', 'pinkie', 'small finger'], anchor: (BodyView.front, 40, 261)),
  const BodyRegion('fingertips', 'Fingertips', 'Yemas de los dedos', sided: true, section: RegionSection.hand, group: DescriptorGroup.hand, synonyms: ['tips of fingers', 'finger tip'], anchor: (BodyView.front, 42, 265)),

  // Legs
  const BodyRegion('thigh_front', 'Front of thigh', 'Muslo (delante)', sided: true, section: RegionSection.leg, group: DescriptorGroup.leg, synonyms: ['quad', 'quadriceps', 'thigh'], anchor: (BodyView.front, 85, 280)),
  const BodyRegion('thigh_back', 'Back of thigh', 'Muslo (detrás)', sided: true, section: RegionSection.leg, group: DescriptorGroup.leg, synonyms: ['hamstring', 'thigh'], anchor: (BodyView.back, 85, 280)),
  const BodyRegion('inner_thigh', 'Inner thigh', 'Cara interna del muslo', sided: true, section: RegionSection.leg, group: DescriptorGroup.leg, synonyms: ['groin'], anchor: (BodyView.front, 95, 268)),
  const BodyRegion('knee', 'Knee', 'Rodilla', sided: true, section: RegionSection.leg, group: DescriptorGroup.joint, synonyms: ['kneecap'], anchor: (BodyView.front, 84, 334)),
  const BodyRegion('knee_back', 'Back of knee', 'Corva', sided: true, section: RegionSection.leg, group: DescriptorGroup.joint, synonyms: ['behind knee'], anchor: (BodyView.back, 84, 334)),
  const BodyRegion('shin', 'Shin', 'Espinilla', sided: true, section: RegionSection.leg, group: DescriptorGroup.leg, synonyms: ['lower leg'], anchor: (BodyView.front, 85, 378)),
  const BodyRegion('calf', 'Calf', 'Pantorrilla', sided: true, section: RegionSection.leg, group: DescriptorGroup.leg, synonyms: ['lower leg'], anchor: (BodyView.back, 85, 378)),
  const BodyRegion('ankle', 'Ankle', 'Tobillo', sided: true, section: RegionSection.leg, group: DescriptorGroup.joint, anchor: (BodyView.front, 86, 416)),

  // Feet
  const BodyRegion('foot_top', 'Top of foot', 'Empeine', sided: true, section: RegionSection.foot, group: DescriptorGroup.leg, synonyms: ['instep', 'foot'], anchor: (BodyView.front, 88, 430)),
  const BodyRegion('heel', 'Heel', 'Talón', sided: true, section: RegionSection.foot, group: DescriptorGroup.leg, anchor: (BodyView.back, 88, 432)),
  const BodyRegion('arch', 'Arch', 'Arco del pie', sided: true, section: RegionSection.foot, group: DescriptorGroup.leg, anchor: (BodyView.back, 88, 428)),
  const BodyRegion('sole', 'Sole', 'Planta del pie', sided: true, section: RegionSection.foot, group: DescriptorGroup.leg, synonyms: ['bottom of foot', 'foot'], anchor: (BodyView.back, 88, 430)),
  const BodyRegion('ball_of_foot', 'Ball of foot', 'Almohadilla del pie', sided: true, section: RegionSection.foot, group: DescriptorGroup.leg, synonyms: ['forefoot'], anchor: (BodyView.back, 88, 426)),
  const BodyRegion('toe_big', 'Big toe', 'Dedo gordo', sided: true, section: RegionSection.foot, group: DescriptorGroup.leg, synonyms: ['first toe', 'hallux'], anchor: (BodyView.front, 90, 438)),
  const BodyRegion('toe_2', 'Second toe', 'Segundo dedo del pie', sided: true, section: RegionSection.foot, group: DescriptorGroup.leg, anchor: (BodyView.front, 88, 438)),
  const BodyRegion('toe_3', 'Third toe', 'Tercer dedo del pie', sided: true, section: RegionSection.foot, group: DescriptorGroup.leg, synonyms: ['middle toe'], anchor: (BodyView.front, 87, 438)),
  const BodyRegion('toe_4', 'Fourth toe', 'Cuarto dedo del pie', sided: true, section: RegionSection.foot, group: DescriptorGroup.leg, anchor: (BodyView.front, 86, 437)),
  const BodyRegion('toe_little', 'Little toe', 'Dedo pequeño del pie', sided: true, section: RegionSection.foot, group: DescriptorGroup.leg, synonyms: ['pinky toe', 'fifth toe'], anchor: (BodyView.front, 85, 436)),
];

final Map<String, BodyRegion> regionById = {for (final r in bodyRegions) r.id: r};

/// Regions offered when asked to find something by name.
List<BodyRegion> searchRegions(String query, bool es) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return bodyRegions;
  return [
    for (final r in bodyRegions)
      if (r.en.toLowerCase().contains(q) || r.es.toLowerCase().contains(q) || r.synonyms.any((s) => s.contains(q))) r,
  ];
}

// ---------------------------------------------------------------------------
// Drawings
// ---------------------------------------------------------------------------

/// A hit area on one drawing.
class RegionShape {
  RegionShape(this.regionId, this.side, this.path, {this.zoomTo});
  final String regionId;
  final BodySide side;
  final Path path;

  /// Tapping opens this detail sheet instead of selecting the region.
  final BodyView? zoomTo;
  late final double area = _area(path);
  static double _area(Path p) {
    final b = p.getBounds();
    return b.width * b.height;
  }
}

/// One drawing: outline, hit areas and size.
class BodySheet {
  BodySheet(this.view, this.size, this.outline, this.shapes, {this.details = const []});
  final BodyView view;
  final Size size;
  final Path outline;

  /// Hit areas, smallest first (so a small region wins over a large one).
  final List<RegionShape> shapes;

  /// Thin anatomical guide lines drawn inside the outline.
  final List<Path> details;
}

Path _ell(double cx, double cy, double rx, double ry) => Path()..addOval(Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2));
Path _rr(double l, double t, double r, double b, [double rad = 6]) => Path()..addRRect(RRect.fromLTRBR(l, t, r, b, Radius.circular(rad)));

/// A limb segment: a tapered capsule from (x1,y1) width w1 to (x2,y2) w2.
Path _capsule(double x1, double y1, double w1, double x2, double y2, double w2) {
  final a = math.atan2(y2 - y1, x2 - x1) + math.pi / 2;
  final dx = math.cos(a), dy = math.sin(a);
  final p = Path()
    ..moveTo(x1 + dx * w1 / 2, y1 + dy * w1 / 2)
    ..lineTo(x2 + dx * w2 / 2, y2 + dy * w2 / 2)
    ..lineTo(x2 - dx * w2 / 2, y2 - dy * w2 / 2)
    ..lineTo(x1 - dx * w1 / 2, y1 - dy * w1 / 2)
    ..close();
  return Path.combine(PathOperation.union, Path.combine(PathOperation.union, p, _ell(x1, y1, w1 / 2, w1 / 2)), _ell(x2, y2, w2 / 2, w2 / 2));
}

Path _union(Iterable<Path> paths) {
  Path? out;
  for (final p in paths) {
    out = out == null ? p : Path.combine(PathOperation.union, out, p);
  }
  return out ?? Path();
}

Path _mirror(Path p, double width) => p.transform(Float64List.fromList([-1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, width, 0, 0, 1]));

/// Torso outline for the half on the viewer's left, mirrored.
Path _torso() {
  final half = Path()
    ..moveTo(100, 74)
    ..lineTo(90, 76)
    ..cubicTo(80, 78, 64, 80, 57, 90)
    ..cubicTo(53, 98, 56, 110, 63, 118)
    ..cubicTo(66, 140, 72, 160, 74, 176)
    ..cubicTo(74, 192, 64, 206, 66, 222)
    ..cubicTo(68, 236, 84, 246, 100, 246)
    ..close();
  return Path.combine(PathOperation.union, half, _mirror(half, 200));
}

/// Limbs on the viewer's left side.
List<Path> _limbsLeft() => [
  _ell(60, 99, 10, 11),
  _capsule(59, 102, 18, 51, 165, 13),
  _capsule(51, 166, 13, 45, 232, 9),
  _ell(44, 247, 8.5, 14),
  _capsule(86, 234, 31, 85, 330, 18),
  _capsule(85, 336, 16, 86, 412, 10),
  _ell(87, 425, 8, 12),
];

Path _figureOutline() => _union([
  _ell(100, 38, 21, 26),
  _rr(90, 56, 110, 82, 4),
  _torso(),
  ..._limbsLeft(),
  for (final p in _limbsLeft()) _mirror(p, 200),
]);

/// Shapes for the viewer's left half; [sideLeft] is the body side that
/// appears there (right on the front view, left on the back view).
List<RegionShape> _sidedShapes(BodySide sideLeft, List<(String, Path, BodyView?)> leftHalf) {
  final sideRight = sideLeft == BodySide.right ? BodySide.left : BodySide.right;
  return [
    for (final (id, p, z) in leftHalf) ...[
      RegionShape(id, sideLeft, p, zoomTo: z),
      RegionShape(id, sideRight, _mirror(p, 200), zoomTo: z),
    ],
  ];
}

List<RegionShape> _sorted(List<RegionShape> s) => s..sort((a, b) => a.area.compareTo(b.area));

BodySheet _front() {
  final c = BodySide.center;
  final shapes = <RegionShape>[
    RegionShape('crown', c, _rr(78, 8, 122, 19, 8)),
    RegionShape('forehead', c, _rr(80, 19, 120, 31, 6)),
    RegionShape('face_general', c, _rr(80, 31, 120, 64, 10), zoomTo: BodyView.face),
    RegionShape('throat', c, _ell(100, 73, 6, 6)),
    RegionShape('neck_front', c, _rr(89, 58, 111, 82, 4)),
    RegionShape('sternum', c, _rr(95, 84, 105, 134, 4)),
    RegionShape('abdomen_upper', c, _rr(84, 134, 116, 160, 4)),
    RegionShape('abdomen_mid', c, _rr(80, 160, 120, 186, 4)),
    RegionShape('abdomen_lower', c, _rr(80, 186, 120, 212, 4)),
    RegionShape('pelvis', c, _rr(82, 212, 118, 248, 6)),
    ..._sidedShapes(BodySide.right, [
      ('temple', _ell(81, 30, 5, 6), null),
      ('collarbone', _rr(78, 78, 98, 87, 4), null),
      ('shoulder_front', _ell(62, 95, 11, 12), null),
      ('chest', _rr(68, 87, 97, 124, 6), null),
      ('ribs', _rr(64, 124, 88, 152, 6), null),
      ('flank', _rr(62, 152, 80, 206, 6), null),
      ('hip', _rr(58, 206, 82, 234, 8), null),
      ('upper_arm_front', _capsule(58, 108, 17, 51, 158, 13), null),
      ('elbow_front', _ell(51, 166, 8, 8), null),
      ('forearm_front', _capsule(50, 176, 12, 45, 226, 9), null),
      ('wrist_front', _ell(45, 232, 6, 5), null),
      ('palm', _ell(44, 247, 9, 15), BodyView.handPalm),
      ('inner_thigh', _rr(94, 246, 100, 304, 3), null),
      ('thigh_front', _capsule(86, 240, 30, 85, 322, 18), null),
      ('knee', _ell(85, 333, 10, 10), null),
      ('shin', _capsule(85, 346, 16, 86, 406, 10), null),
      ('ankle', _ell(86, 416, 7, 5), null),
      ('foot_top', _ell(87, 426, 9, 12), BodyView.footTop),
    ]),
  ];
  return BodySheet(BodyView.front, const Size(200, 460), _figureOutline(), _sorted(shapes), details: _figureDetails(front: true));
}

BodySheet _back() {
  final c = BodySide.center;
  final shapes = <RegionShape>[
    RegionShape('crown', c, _rr(78, 8, 122, 20, 8)),
    RegionShape('scalp', c, _rr(79, 20, 121, 36, 6)),
    RegionShape('back_of_head', c, _rr(79, 36, 121, 63, 10)),
    RegionShape('neck_back', c, _rr(89, 58, 111, 82, 4)),
    RegionShape('spine', c, _rr(96, 82, 104, 208, 3)),
    RegionShape('tailbone', c, _ell(100, 214, 6, 7)),
    RegionShape('mid_back', c, _rr(70, 124, 130, 166, 6)),
    RegionShape('lower_back', c, _rr(70, 166, 130, 206, 6)),
    ..._sidedShapes(BodySide.left, [
      ('shoulder_blade', _ell(84, 107, 10, 13), null),
      ('upper_back', _rr(66, 84, 100, 124, 6), null),
      ('shoulder_back', _ell(62, 95, 11, 12), null),
      ('buttock', _rr(64, 206, 100, 248, 12), null),
      ('upper_arm_back', _capsule(58, 108, 17, 51, 158, 13), null),
      ('elbow_back', _ell(51, 166, 8, 8), null),
      ('forearm_back', _capsule(50, 176, 12, 45, 226, 9), null),
      ('wrist_back', _ell(45, 232, 6, 5), null),
      ('back_of_hand', _ell(44, 247, 9, 15), BodyView.handBack),
      ('thigh_back', _capsule(86, 240, 30, 85, 322, 18), null),
      ('knee_back', _ell(85, 333, 10, 10), null),
      ('calf', _capsule(85, 346, 16, 86, 406, 10), null),
      ('ankle', _ell(86, 414, 7, 5), null),
      ('heel', _ell(87, 426, 9, 12), BodyView.footSole),
    ]),
  ];
  return BodySheet(BodyView.back, const Size(200, 460), _figureOutline(), _sorted(shapes), details: _figureDetails(front: false));
}

/// Subtle anatomical guides: midline, clavicles, ribcage curve, knees.
List<Path> _figureDetails({required bool front}) {
  final out = <Path>[];
  if (front) {
    final collar = Path()
      ..moveTo(78, 84)
      ..quadraticBezierTo(89, 80, 98, 85);
    out
      ..add(collar)
      ..add(_mirror(collar, 200));
    final rib = Path()
      ..moveTo(98, 132)
      ..quadraticBezierTo(84, 140, 72, 150);
    out
      ..add(rib)
      ..add(_mirror(rib, 200));
    out.add(Path()
      ..moveTo(100, 136)
      ..lineTo(100, 206));
    out.add(_ell(100, 176, 1.6, 1.6));
  } else {
    out.add(Path()
      ..moveTo(100, 82)
      ..lineTo(100, 206));
    final blade = Path()
      ..moveTo(78, 96)
      ..quadraticBezierTo(76, 112, 88, 120);
    out
      ..add(blade)
      ..add(_mirror(blade, 200));
    final glute = Path()
      ..moveTo(100, 220)
      ..quadraticBezierTo(100, 240, 90, 246);
    out
      ..add(glute)
      ..add(_mirror(glute, 200));
  }
  for (final p in [Path()..moveTo(78, 334)..quadraticBezierTo(84, 340, 90, 334)]) {
    out
      ..add(p)
      ..add(_mirror(p, 200));
  }
  return out;
}

BodySheet _face() {
  final c = BodySide.center;
  final outline = _union([
    _ell(100, 116, 70, 94),
    _ell(26, 122, 11, 22),
    _ell(174, 122, 11, 22),
    _rr(68, 196, 132, 240, 10),
  ]);
  final shapes = <RegionShape>[
    RegionShape('scalp', c, _rr(36, 22, 164, 46, 18)),
    RegionShape('crown', c, _ell(100, 26, 26, 6)),
    RegionShape('forehead', c, _rr(42, 46, 158, 80, 12)),
    RegionShape('nose', c, _ell(100, 128, 11, 24)),
    RegionShape('lips', c, _ell(100, 168, 22, 8)),
    RegionShape('throat', c, _rr(86, 212, 114, 238, 6)),
    RegionShape('neck_front', c, _rr(68, 200, 132, 240, 10)),
    ..._sidedShapes(BodySide.right, [
      ('temple', _ell(42, 92, 12, 14), null),
      ('eyelid', _ell(70, 97, 15, 5), null),
      ('eye', _ell(70, 108, 15, 7), null),
      ('ear', _ell(26, 122, 11, 22), null),
      ('sinus', _ell(80, 130, 9, 8), null),
      ('cheek', _ell(58, 142, 17, 18), null),
      ('jaw', _rr(36, 160, 82, 198, 16), null),
    ]),
  ];
  final details = <Path>[
    for (final x in [70.0, 130.0]) _ell(x, 108, 9, 4),
    Path()
      ..moveTo(95, 145)
      ..quadraticBezierTo(100, 150, 105, 145),
    Path()
      ..moveTo(82, 168)
      ..quadraticBezierTo(100, 174, 118, 168),
    for (final x in [70.0, 130.0])
      Path()
        ..moveTo(x - 14, 88)
        ..quadraticBezierTo(x, 82, x + 14, 88),
  ];
  return BodySheet(BodyView.face, const Size(200, 240), outline, _sorted(shapes), details: details);
}

/// Hand drawing with the thumb on the viewer's left.
(Path, List<(String, Path)>, List<Path>) _handParts({required bool palm}) {
  final fingers = <(String, double, double, double)>[
    ('finger_index', 54, 34, 15),
    ('finger_middle', 72, 22, 15),
    ('finger_ring', 90, 30, 14.5),
    ('finger_little', 107, 50, 13),
  ];
  final palmShape = _rr(42, 104, 120, 190, 22);
  final thumb = _capsule(46, 156, 18, 20, 108, 14);
  final wrist = _rr(54, 186, 108, 218, 10);
  final parts = <(String, Path)>[
    for (final (id, x, top, w) in fingers) ...[
      ('fingertips', _rr(x - w / 2, top, x + w / 2, top + 20, w / 2)),
      (id, _rr(x - w / 2, top, x + w / 2, 112, w / 2)),
    ],
    ('fingertips', _ell(17, 103, 8, 8)),
    ('thumb', thumb),
    (palm ? 'palm' : 'back_of_hand', palmShape),
    (palm ? 'wrist_front' : 'wrist_back', wrist),
  ];
  final outline = _union([for (final (_, x, top, w) in fingers) _rr(x - w / 2, top, x + w / 2, 116, w / 2), palmShape, thumb, wrist]);
  final details = <Path>[
    if (palm) ...[
      Path()
        ..moveTo(52, 150)
        ..quadraticBezierTo(70, 140, 92, 112),
      Path()
        ..moveTo(60, 128)
        ..quadraticBezierTo(90, 124, 118, 122),
    ] else ...[
      for (final (_, x, top, w) in fingers) _ell(x, top + 6, w / 2 - 3, 4),
    ],
    for (final (_, x, top, w) in fingers)
      for (final y in [top + 30, top + 52])
        if (y < 108)
          Path()
            ..moveTo(x - w / 2 + 2, y)
            ..lineTo(x + w / 2 - 2, y),
  ];
  return (outline, parts, details);
}

/// Foot drawing with the big toe on the viewer's left.
(Path, List<(String, Path)>, List<Path>) _footParts({required bool top}) {
  final toes = <(String, double, double, double, double)>[
    ('toe_big', 50, 58, 13, 17),
    ('toe_2', 74, 50, 8, 11),
    ('toe_3', 91, 54, 7.5, 10),
    ('toe_4', 106, 61, 7, 9),
    ('toe_little', 119, 71, 6, 8),
  ];
  final foot = Path()
    ..moveTo(34, 76)
    ..cubicTo(40, 64, 110, 62, 125, 78)
    ..cubicTo(130, 110, 112, 150, 108, 176)
    ..cubicTo(106, 210, 96, 228, 76, 228)
    ..cubicTo(56, 228, 48, 210, 48, 186)
    ..cubicTo(46, 150, 30, 110, 34, 70)
    ..close();
  final parts = <(String, Path)>[
    for (final (id, x, y, rx, ry) in toes) (id, _ell(x, y, rx, ry)),
    if (top) ...[
      ('ankle', _rr(50, 196, 104, 228, 14)),
      ('foot_top', foot),
    ] else ...[
      ('heel', _ell(77, 202, 28, 26)),
      ('ball_of_foot', _rr(34, 72, 126, 108, 18)),
      ('arch', _rr(40, 108, 82, 176, 14)),
      ('sole', foot),
    ],
  ];
  final outline = _union([foot, for (final (_, x, y, rx, ry) in toes) _ell(x, y, rx, ry)]);
  final details = <Path>[
    if (top)
      for (final (_, x, y, rx, ry) in toes) _ell(x, y - ry * 0.35, rx * 0.55, ry * 0.3)
    else ...[
      Path()
        ..moveTo(42, 104)
        ..quadraticBezierTo(80, 112, 120, 102),
      Path()
        ..moveTo(52, 178)
        ..quadraticBezierTo(78, 170, 104, 178),
    ],
  ];
  return (outline, parts, details);
}

/// The drawing for [view]. Hand and foot sheets depend on [side].
BodySheet sheetFor(BodyView view, {BodySide side = BodySide.right}) {
  switch (view) {
    case BodyView.front:
      return _frontSheet;
    case BodyView.back:
      return _backSheet;
    case BodyView.face:
      return _faceSheet;
    case BodyView.handPalm:
    case BodyView.handBack:
      // Front-view convention: the right palm shows the thumb on the
      // viewer's left; the back of the right hand shows it on the right.
      final palm = view == BodyView.handPalm;
      final mirror = palm ? side == BodySide.left : side == BodySide.right;
      final (outline, parts, details) = _handParts(palm: palm);
      return _zoomSheet(view, const Size(160, 230), outline, parts, details, side, mirror);
    case BodyView.footTop:
    case BodyView.footSole:
      // Top: the left foot has its big toe on the viewer's left. Sole
      // (seen from behind): the right foot does.
      final top = view == BodyView.footTop;
      final mirror = top ? side == BodySide.right : side == BodySide.left;
      final (outline, parts, details) = _footParts(top: top);
      return _zoomSheet(view, const Size(160, 240), outline, parts, details, side, mirror);
  }
}

BodySheet _zoomSheet(BodyView view, Size size, Path outline, List<(String, Path)> parts, List<Path> details, BodySide side, bool mirror) {
  Path m(Path p) => mirror ? _mirror(p, size.width) : p;
  return BodySheet(view, size, m(outline), _sorted([for (final (id, p) in parts) RegionShape(id, side, m(p))]), details: [for (final d in details) m(d)]);
}

final BodySheet _frontSheet = _front();
final BodySheet _backSheet = _back();
final BodySheet _faceSheet = _face();

/// Body side shown on the viewer's left half of [view].
BodySide viewerLeftSide(BodyView view) => view == BodyView.back ? BodySide.left : BodySide.right;

/// What a tap at [p] (in sheet space) could mean.
class HitResult {
  const HitResult(this.primary, this.alternatives);
  final RegionShape? primary;

  /// Other regions close enough to the tap that the user may have meant
  /// them (shown as choices when not empty).
  final List<RegionShape> alternatives;
}

HitResult hitTestSheet(BodySheet sheet, Offset p, {double slop = 7}) {
  if (!sheet.outline.contains(p)) {
    // Allow a near miss just outside a thin limb.
    final near = [for (final s in sheet.shapes) if (_nearAny(s.path, p, slop)) s];
    if (near.isEmpty) return const HitResult(null, []);
    return HitResult(near.first, _distinct(near.skip(1), near.first));
  }
  final inside = [for (final s in sheet.shapes) if (s.path.contains(p)) s];
  if (inside.isEmpty) return const HitResult(null, []);
  final primary = inside.first;
  final probes = [for (var i = 0; i < 8; i++) p + Offset(math.cos(i * math.pi / 4) * slop, math.sin(i * math.pi / 4) * slop)];
  final nearby = [
    for (final s in sheet.shapes)
      if (s != primary && (inside.contains(s) || probes.any(s.path.contains))) s,
  ];
  final edge = probes.any((q) => !primary.path.contains(q));
  return HitResult(primary, edge ? _distinct(nearby, primary) : const []);
}

bool _nearAny(Path path, Offset p, double slop) {
  for (var i = 0; i < 8; i++) {
    if (path.contains(p + Offset(math.cos(i * math.pi / 4) * slop, math.sin(i * math.pi / 4) * slop))) return true;
  }
  return false;
}

List<RegionShape> _distinct(Iterable<RegionShape> shapes, RegionShape primary) {
  final seen = <String>{'${primary.regionId}/${primary.side.name}'};
  return [
    for (final s in shapes)
      if (s.zoomTo == null && seen.add('${s.regionId}/${s.side.name}')) s,
  ].take(3).toList();
}

/// Where a spot on [view] shows up on the front/back figure.
Offset? figureAnchor(String regionId, BodySide side, BodyView figure) {
  final r = regionById[regionId];
  final a = r?.anchor;
  if (a == null || a.$1 != figure) return null;
  // Anchors are authored for the body's right side.
  final viewerLeftIsBodyRight = figure == BodyView.front;
  var x = a.$2;
  if (r!.sided) {
    final onViewerLeft = (side == BodySide.right) == viewerLeftIsBodyRight;
    if (!onViewerLeft) x = 200 - x;
  }
  return Offset(x, a.$3);
}

/// Which sheet to open first for a region (for list selections).
BodyView preferredViewFor(String regionId) {
  final r = regionById[regionId];
  if (r == null) return BodyView.front;
  return switch (r.section) {
    RegionSection.face || RegionSection.mouth => BodyView.face,
    RegionSection.hand => regionId == 'back_of_hand' ? BodyView.handBack : BodyView.handPalm,
    RegionSection.foot => const {'heel', 'arch', 'sole', 'ball_of_foot'}.contains(regionId) ? BodyView.footSole : BodyView.footTop,
    RegionSection.back => BodyView.back,
    _ => r.anchor?.$1 ?? BodyView.front,
  };
}

// ---------------------------------------------------------------------------
// Vocabulary
// ---------------------------------------------------------------------------

/// A sensation word. [id] is stored; labels may change without changing
/// what a past entry meant.
class Descriptor {
  const Descriptor(this.id, this.en, this.es, {this.synonyms = const [], this.neutral = false});
  final String id;
  final String en;
  final String es;
  final List<String> synonyms;

  /// Ordinary, non-symptom feelings (relaxed, warm…).
  final bool neutral;
  String label(bool es) => es ? this.es : en;
}

const generalDescriptors = <Descriptor>[
  Descriptor('aching', 'Aching', 'Dolorido', synonyms: ['ache', 'achy']),
  Descriptor('dull', 'Dull', 'Sordo'),
  Descriptor('sharp', 'Sharp', 'Agudo'),
  Descriptor('stabbing', 'Stabbing', 'Punzante', synonyms: ['knife']),
  Descriptor('burning', 'Burning', 'Ardor', synonyms: ['hot', 'fire']),
  Descriptor('throbbing', 'Throbbing', 'Palpitante'),
  Descriptor('pulsing', 'Pulsing', 'Pulsátil'),
  Descriptor('squeezing', 'Squeezing', 'Opresivo', synonyms: ['pressure', 'crushing']),
  Descriptor('pulling', 'Pulling', 'Tirante'),
  Descriptor('tight', 'Tight', 'Tenso', synonyms: ['tense', 'tension']),
  Descriptor('tender', 'Tender', 'Sensible al tacto', synonyms: ['sore to touch']),
  Descriptor('hot', 'Hot', 'Caliente'),
  Descriptor('cold', 'Cold', 'Frío', synonyms: ['chilly']),
  Descriptor('crawling', 'Crawling', 'Hormigueo reptante', synonyms: ['bugs', 'creeping']),
  Descriptor('prickly', 'Prickly', 'Picante / punzadas leves'),
  Descriptor('electric', 'Electric', 'Eléctrico', synonyms: ['shock', 'zap', 'zing']),
  Descriptor('tingly', 'Tingly', 'Hormigueo', synonyms: ['tingling']),
  Descriptor('numb', 'Numb', 'Entumecido', synonyms: ['no feeling', 'numbness']),
  Descriptor('heavy', 'Heavy', 'Pesado'),
  Descriptor('weak', 'Weak', 'Débil'),
  Descriptor('shaky', 'Shaky', 'Tembloroso', synonyms: ['trembling', 'tremor']),
  Descriptor('sore', 'Sore', 'Adolorido'),
  Descriptor('itchy', 'Itchy', 'Picazón', synonyms: ['itch']),
  Descriptor('stiff', 'Stiff', 'Rígido'),
  Descriptor('swollen', 'Swollen', 'Hinchado', synonyms: ['puffy', 'swelling']),
  Descriptor('relaxed', 'Relaxed', 'Relajado', neutral: true),
  Descriptor('warm', 'Warm', 'Cálido', neutral: true),
  Descriptor('loose', 'Loose', 'Suelto', neutral: true),
  Descriptor('light', 'Light', 'Ligero', neutral: true),
  Descriptor('comfortably_heavy', 'Comfortably heavy', 'Agradablemente pesado', neutral: true),
  Descriptor('neutral', 'Neutral', 'Neutro', neutral: true),
];

const regionDescriptors = <DescriptorGroup, List<Descriptor>>{
  DescriptorGroup.ears: [
    Descriptor('ringing', 'Ringing', 'Zumbido', synonyms: ['tinnitus']),
    Descriptor('buzzing', 'Buzzing', 'Murmullo'),
    Descriptor('muffled', 'Muffled hearing', 'Audición apagada'),
    Descriptor('popping', 'Popping', 'Chasquidos'),
    Descriptor('fullness', 'Fullness', 'Sensación de oído tapado', synonyms: ['blocked ear', 'plugged']),
  ],
  DescriptorGroup.eyes: [
    Descriptor('gritty', 'Gritty', 'Arenilla', synonyms: ['sandy']),
    Descriptor('watery', 'Watery', 'Lloroso', synonyms: ['tearing']),
    Descriptor('dry_eye', 'Dry', 'Seco'),
    Descriptor('twitching', 'Twitching', 'Tic / temblor del párpado', synonyms: ['twitch']),
    Descriptor('strained', 'Strained', 'Forzado / cansado'),
    Descriptor('light_sensitive', 'Light-sensitive', 'Sensible a la luz', synonyms: ['photophobia', 'bright']),
  ],
  DescriptorGroup.nose: [
    Descriptor('blocked', 'Blocked', 'Tapado', synonyms: ['stuffy', 'congested']),
    Descriptor('dripping', 'Dripping', 'Goteo', synonyms: ['runny']),
    Descriptor('pressure_eyes', 'Pressure behind the eyes', 'Presión detrás de los ojos'),
    Descriptor('stinging', 'Stinging', 'Escozor'),
  ],
  DescriptorGroup.jaw: [
    Descriptor('clenching', 'Clenching', 'Apretando', synonyms: ['grinding teeth', 'bruxism']),
    Descriptor('clicking_jaw', 'Clicking', 'Chasquido'),
    Descriptor('locking_jaw', 'Locking', 'Bloqueo'),
    Descriptor('tooth_sensitive', 'Tooth sensitivity', 'Sensibilidad dental'),
  ],
  DescriptorGroup.mouth: [
    Descriptor('dry_mouth', 'Dry', 'Seco'),
    Descriptor('altered_taste', 'Altered taste', 'Sabor alterado', synonyms: ['metallic']),
    Descriptor('stinging', 'Stinging', 'Escozor'),
  ],
  DescriptorGroup.throat: [
    Descriptor('scratchy', 'Scratchy', 'Raspa', synonyms: ['itchy throat']),
    Descriptor('hoarse', 'Hoarse', 'Ronco', synonyms: ['voice']),
    Descriptor('dry_throat', 'Dry', 'Seco'),
    Descriptor('lump', 'Lump sensation', 'Sensación de nudo', synonyms: ['globus']),
    Descriptor('painful_swallow', 'Pain when swallowing', 'Dolor al tragar', synonyms: ['swallow']),
  ],
  DescriptorGroup.chest: [
    Descriptor('fluttering', 'Fluttering', 'Aleteo', synonyms: ['palpitations', 'flutter']),
    Descriptor('pounding', 'Pounding', 'Golpeteo', synonyms: ['racing heart']),
    Descriptor('tightness', 'Tightness', 'Opresión'),
    Descriptor('deep_breath', 'Discomfort when taking a deep breath', 'Molestia al respirar hondo', synonyms: ['breathing']),
  ],
  DescriptorGroup.abdomen: [
    Descriptor('knotted', 'Knotted', 'Hecho un nudo', synonyms: ['butterflies']),
    Descriptor('cramping', 'Cramping', 'Calambres', synonyms: ['cramps']),
    Descriptor('bloated', 'Bloated', 'Hinchado', synonyms: ['gassy']),
    Descriptor('gurgling', 'Gurgling', 'Ruidos'),
    Descriptor('rolling', 'Rolling', 'Revuelto', synonyms: ['churning', 'queasy']),
  ],
  DescriptorGroup.back: [
    Descriptor('spasm', 'Spasm', 'Espasmo'),
    Descriptor('seized', 'Seized up', 'Bloqueado'),
    Descriptor('radiating', 'Radiating', 'Irradiado', synonyms: ['spreading', 'shooting']),
    Descriptor('tight_band', 'Tight band', 'Banda tensa'),
    Descriptor('pain_turning', 'Pain when turning', 'Dolor al girar'),
  ],
  DescriptorGroup.joint: [
    Descriptor('catching', 'Catching', 'Enganche'),
    Descriptor('locking', 'Locking', 'Bloqueo'),
    Descriptor('clicking', 'Clicking', 'Chasquido', synonyms: ['popping', 'cracking']),
    Descriptor('grinding', 'Grinding', 'Crujido', synonyms: ['crepitus']),
    Descriptor('giving_way', 'Giving way', 'Fallo / cede'),
  ],
  DescriptorGroup.hand: [
    Descriptor('pins_needles', 'Pins and needles', 'Hormigueo (alfileres)', synonyms: ['asleep']),
    Descriptor('reduced_grip', 'Reduced grip', 'Menos fuerza de agarre', synonyms: ['clumsy', 'dropping things']),
    Descriptor('numb_tips', 'Numb fingertips', 'Yemas entumecidas'),
    Descriptor('trembling', 'Trembling', 'Temblor'),
  ],
  DescriptorGroup.leg: [
    Descriptor('restless', 'Restless', 'Inquieto', synonyms: ['restless legs']),
    Descriptor('cramping', 'Cramping', 'Calambres', synonyms: ['charley horse']),
    Descriptor('dragging', 'Dragging', 'Arrastre'),
    Descriptor('unsteady', 'Unsteady', 'Inestable', synonyms: ['wobbly']),
    Descriptor('pressure_standing', 'Pressure when standing', 'Presión al estar de pie'),
  ],
  DescriptorGroup.head: [
    Descriptor('pressure', 'Pressure', 'Presión'),
    Descriptor('band', 'Band-like', 'Como una banda'),
    Descriptor('dizzy', 'Dizzy', 'Mareo', synonyms: ['spinning', 'lightheaded']),
  ],
  DescriptorGroup.skin: [
    Descriptor('flushed', 'Flushed', 'Enrojecido', synonyms: ['red']),
    Descriptor('dry_skin', 'Dry', 'Seco'),
  ],
};

final Map<String, Descriptor> _allDescriptors = {
  for (final d in generalDescriptors) d.id: d,
  for (final list in regionDescriptors.values)
    for (final d in list) d.id: d,
};

Descriptor? descriptorById(String id) => _allDescriptors[id];

/// Region-specific words first, then the general list (neutral feelings last).
List<Descriptor> descriptorsFor(String? regionId) {
  final group = regionById[regionId]?.group ?? DescriptorGroup.none;
  final specific = regionDescriptors[group] ?? const [];
  final ids = {for (final d in specific) d.id};
  return [...specific, for (final d in generalDescriptors) if (!ids.contains(d.id)) d];
}

List<Descriptor> searchDescriptors(String regionId, String query, bool es) {
  final q = query.trim().toLowerCase();
  final all = descriptorsFor(regionId);
  if (q.isEmpty) return all;
  return [
    for (final d in all)
      if (d.en.toLowerCase().contains(q) || d.es.toLowerCase().contains(q) || d.synonyms.any((s) => s.contains(q))) d,
  ];
}

/// Mood's old coarse body regions → Body Map regions.
const legacyMoodRegions = <String, String>{
  'head': 'head',
  'face': 'face_general',
  'throat': 'throat',
  'shoulders': 'shoulders',
  'chest': 'chest',
  'stomach': 'abdomen_mid',
  'back': 'back',
  'arms': 'arms',
  'hands': 'hands',
  'legs': 'legs',
  'feet': 'feet',
  'whole': whole,
};

/// Mood's old sensation keys → descriptor ids (labels kept for the rest).
const legacyMoodSensations = <String, String>{
  'tense': 'tight',
  'tight': 'tight',
  'aching': 'aching',
  'warm': 'warm',
  'cold': 'cold',
  'tingling': 'tingly',
  'numb': 'numb',
  'heavy': 'heavy',
  'light': 'light',
  'shaky': 'shaky',
};
