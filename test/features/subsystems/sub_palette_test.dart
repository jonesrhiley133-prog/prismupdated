import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/subsystems/hub/subsystem_data.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';

TrackerRecord sub(String id, {String? parent, String mode = 'own', List<int> pal = const [0xFF000000, 0xFF000000, 0xFF000000, 0xFF000000, 0xFF000000]}) {
  final now = DateTime(2026);
  return TrackerRecord(id: id, kind: TrackerKind.subsystem, parentId: parent, createdAt: now, modifiedAt: now).withFields({'paletteMode': mode, 'palette': pal});
}

void main() {
  test('palette inheritance modes', () {
    final parent = sub('p', pal: [0xFFFF0000, 0xFF00FF00, 0xFF0000FF, 0xFFFFFFFF, 0xFF000000]);
    final child = sub('c', parent: 'p', mode: 'inherit');
    final blend = sub('b', parent: 'p', mode: 'blend', pal: [0xFF0000FF, 0xFF0000FF, 0xFF0000FF, 0xFF0000FF, 0xFF0000FF]);
    final grand = sub('g', parent: 'c', mode: 'inherit');
    final theme = sub('t', parent: 'p', mode: 'theme');
    subsystemIndex = {for (final s in [parent, child, blend, grand, theme]) s.id: s};
    expect(effectiveSubPalette(child), parent.fields['palette']);
    expect(effectiveSubPalette(grand), parent.fields['palette']);
    expect(effectiveSubPalette(theme), isNull);
    final b = effectiveSubPalette(blend)!;
    expect(b.first, isNot(0xFF0000FF));
    expect(b.first, isNot(0xFFFF0000));
    // A top-level subsystem set to inherit keeps its own colours.
    final lone = sub('l', mode: 'inherit', pal: [0xFF123456, 0xFF654321, 1, 2, 3]);
    subsystemIndex = {'l': lone};
    expect(effectiveSubPalette(lone)!.first, 0xFF123456);
  });
}
