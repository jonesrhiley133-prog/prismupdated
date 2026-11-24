import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/features/launch/launch_settings.dart';

void main() {
  final morning = DateTime(2026, 11, 24, 9);
  test('default greeting uses the system name', () {
    expect(buildGreeting(preset: GreetingPreset.welcomeBack, custom: '', systemName: 'The Lanterns', now: morning), 'Welcome back, The Lanterns!');
    expect(buildGreeting(preset: GreetingPreset.welcomeBack, custom: '', systemName: '', now: morning), 'Welcome back!');
  });
  test('time of day and variables', () {
    expect(buildGreeting(preset: GreetingPreset.timeOfDay, custom: '', systemName: 'Lanterns', now: morning), 'Good morning, Lanterns');
    expect(buildGreeting(preset: GreetingPreset.timeOfDay, custom: '', systemName: 'Lanterns', now: DateTime(2026, 1, 1, 20)), 'Good evening, Lanterns');
    expect(
      buildGreeting(preset: GreetingPreset.custom, custom: 'Hi {primary_fronter}! Happy {day_of_week}', systemName: 'L', primaryFronter: 'Ash', now: morning, locale: 'en'),
      'Hi Ash! Happy Tuesday',
    );
    // A missing fronter leaves no dangling comma.
    expect(buildGreeting(preset: GreetingPreset.custom, custom: 'Hello, {primary_fronter}!', systemName: '', now: morning), 'Hello!');
    expect(buildGreeting(preset: GreetingPreset.none, custom: '', systemName: 'L', now: morning), '');
  });
  test('settings round-trip and duration scales with speed', () {
    const s = LaunchSettings(speed: 1.5, style: LaunchStyle.fade, greeting: GreetingPreset.custom, customGreeting: 'x');
    final r = LaunchSettings.fromJson(s.toJson());
    expect(r.style, LaunchStyle.fade);
    expect(r.customGreeting, 'x');
    expect(r.duration.inMilliseconds, 600);
  });
}
