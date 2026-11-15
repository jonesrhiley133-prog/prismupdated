import 'package:flutter_test/flutter_test.dart';

import 'package:prism_plurality/features/members/studio/profile_config.dart';
import 'package:prism_plurality/features/members/studio/profile_view.dart';

void main() {
  test('roles split into pills and render as a plain banner line', () {
    expect(splitRoles('Host Protector “Inner Helper” Caretaker'), ['Host', 'Protector', 'Inner Helper', 'Caretaker']);
    final cfg = ProfileConfig.empty().withRoles([
      const ProfileRole(name: 'Host'),
      const ProfileRole(name: 'Protector', color: 0xFFFF0000, style: 'glow'),
      const ProfileRole(name: 'Secret', visible: false),
    ]);
    expect(rolesLine(cfg), 'Host · Protector');
    expect(cfg.roles[1].color, 0xFFFF0000);
    expect(cfg.roles[1].style, 'glow');
  });

  test('templates keep appearance and modules but no personal info', () {
    final cfg = ProfileConfig.empty()
        .set('gender', 'nonbinary')
        .set('likes', ['tea'])
        .withLook('accent', 0xFF123456)
        .withModules([('pinned', true), ('about', false)]);
    final t = cfg.templatePart();
    expect(t.keys, containsAll(['appearance', 'modules']));
    expect(t.containsKey('gender'), isFalse);
    expect(t.containsKey('likes'), isFalse);

    final other = ProfileConfig.empty().set('gender', 'woman').applyTemplate(t);
    expect(other.str('gender'), 'woman');
    expect(other.lookColor('accent'), 0xFF123456);
    expect(other.modules.first, ('pinned', true));
  });

  test('modules fill in missing ids and keep unknown data', () {
    final cfg = const ProfileConfig({'future': 1, 'modules': [{'id': 'gallery', 'visible': true}]});
    expect(cfg.modules.first.$1, 'gallery');
    expect(cfg.modules.length, profileModuleIds.length);
    expect(cfg.set('gender', 'x').data['future'], 1);
  });

  test('privacy and labels', () {
    final cfg = ProfileConfig.empty().setIn('privacy', 'birthday', 'private').setIn('labels', 'species', 'Kin');
    expect(cfg.privacyOf('birthday'), 'private');
    expect(cfg.privacyOf('gender'), 'public');
    expect(cfg.labels['species'], 'Kin');
    expect(cfg.fieldOrder.length, identityFieldIds.length);
  });

  test('traits clamp intensity', () {
    final cfg = ProfileConfig.empty().withTraits([('Curious', 9), ('Calm', 0)]);
    expect(cfg.traits, [('Curious', 5), ('Calm', 1)]);
  });
}
