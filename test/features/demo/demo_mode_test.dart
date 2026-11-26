import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/features/demo/demo_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'entering and leaving demo restores every real setting exactly',
    () async {
      SharedPreferences.setMockInitialValues({
        'prism.pref.theme': 'dark',
        'dashboard.widgets': <String>['now', 'events'],
        'prism.count': 3,
        'prism.scale': 1.25,
        'prism.flag': true,
      });
      final prefs = await SharedPreferences.getInstance();
      // freshData false avoids touching the filesystem in this test.
      await DemoMode.enter(prefs, '1m', freshData: false);
      expect(prefs.getBool('prism.demo.active'), isTrue);

      // Changes made while in demo…
      await prefs.setString('prism.pref.theme', 'light');
      await prefs.setStringList('dashboard.widgets', ['stories']);
      await prefs.remove('prism.flag');
      await prefs.setString('demo.only.key', 'x');

      await DemoMode.exit(prefs);
      expect(prefs.getBool('prism.demo.active'), isFalse);
      expect(prefs.getString('prism.pref.theme'), 'dark');
      expect(prefs.getStringList('dashboard.widgets'), ['now', 'events']);
      expect(prefs.getInt('prism.count'), 3);
      expect(prefs.getDouble('prism.scale'), 1.25);
      expect(prefs.getBool('prism.flag'), isTrue);
      expect(prefs.containsKey('demo.only.key'), isFalse);
    },
  );

  test(
    'a second enter while active does not overwrite the real snapshot',
    () async {
      SharedPreferences.setMockInitialValues({'prism.pref.theme': 'dark'});
      final prefs = await SharedPreferences.getInstance();
      await DemoMode.enter(prefs, '1w', freshData: false);
      await prefs.setString('prism.pref.theme', 'light');
      await DemoMode.enter(prefs, '1y', freshData: false);
      await DemoMode.exit(prefs);
      expect(prefs.getString('prism.pref.theme'), 'dark');
    },
  );

  test('load reads the active flag', () async {
    SharedPreferences.setMockInitialValues({'prism.demo.active': true});
    DemoMode.load(await SharedPreferences.getInstance());
    expect(DemoMode.active, isTrue);
    SharedPreferences.setMockInitialValues({});
    DemoMode.load(await SharedPreferences.getInstance());
    expect(DemoMode.active, isFalse);
  });
}
