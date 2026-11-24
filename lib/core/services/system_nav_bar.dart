import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Optional: hide the phone's own navigation bar (Android). It slides back
/// in with a swipe from the bottom edge and hides again after a moment.
/// The app's own navigation is unaffected.
class SystemNavBar with WidgetsBindingObserver {
  SystemNavBar._();
  static final instance = SystemNavBar._();
  static const _key = 'prism_hide_phone_nav_bar';

  bool _hidden = false;
  bool _observing = false;

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Reads the saved choice and applies it. Call once after binding init.
  Future<bool> restore() async {
    if (!supported) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      _hidden = prefs.getBool(_key) ?? false;
    } catch (_) {}
    _observe();
    await _apply();
    return _hidden;
  }

  Future<void> setHidden(bool hidden) async {
    _hidden = hidden;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, hidden);
    } catch (_) {}
    _observe();
    await _apply();
  }

  void _observe() {
    if (_observing) return;
    WidgetsBinding.instance.addObserver(this);
    _observing = true;
  }

  Future<void> _apply() async {
    if (!supported) return;
    if (_hidden) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky, overlays: const [SystemUiOverlay.top]);
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  // Android can restore the bar after the app returns from the background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _hidden) _apply();
  }
}

class HidePhoneNavBarNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => SystemNavBar.instance.restore();

  Future<void> set(bool hidden) async {
    state = AsyncData(hidden);
    await SystemNavBar.instance.setHidden(hidden);
  }
}

final hidePhoneNavBarProvider = AsyncNotifierProvider<HidePhoneNavBarNotifier, bool>(HidePhoneNavBarNotifier.new);
