import 'dart:async';

import 'package:prism_plurality/features/games/engines/tone_player.dart';

/// Plays a seasonal ambience quietly, fading in and out, alongside whatever
/// music is playing. Always optional: any failure is silent.
class SeasonalAudio {
  SeasonalAudio();

  final TonePlayer _player = TonePlayer();
  Timer? _fade;
  double _vol = 0;
  double _target = 0;
  String? _playing;
  bool _disposed = false;

  String? get playing => _playing;

  /// Brings the sound to the wanted state: [on] with [id] at [volume], or
  /// faded out and stopped.
  Future<void> apply({
    required bool on,
    String? id,
    required double volume,
  }) async {
    if (_disposed) return;
    if (!on || id == null) {
      await stop();
      return;
    }
    if (_playing != id) {
      // A different sound: fade the old one away first, then start the new.
      if (_playing != null) await stop();
      if (_disposed) return;
      _playing = id;
      _vol = 0;
      await _player.loop(id, volume: 0);
    }
    _fadeTo(volume.clamp(0.0, 1.0));
  }

  void _fadeTo(double target, {VoidCallback? done}) {
    _target = target;
    _fade?.cancel();
    _fade = Timer.periodic(const Duration(milliseconds: 60), (t) {
      if (_disposed) {
        t.cancel();
        return;
      }
      final diff = _target - _vol;
      if (diff.abs() < 0.015) {
        _vol = _target;
        _player.setVolume(_vol);
        t.cancel();
        done?.call();
        return;
      }
      _vol += diff * 0.18;
      _player.setVolume(_vol);
    });
  }

  /// Fades out, then stops.
  Future<void> stop() async {
    if (_playing == null) return;
    final c = Completer<void>();
    _fadeTo(0, done: () => c.complete());
    await c.future.timeout(const Duration(seconds: 3), onTimeout: () {});
    await _player.stop();
    _playing = null;
    _vol = 0;
  }

  /// Stops right away (the app went to the background).
  Future<void> hush() async {
    _fade?.cancel();
    _vol = 0;
    _playing = null;
    await _player.stop();
  }

  void dispose() {
    _disposed = true;
    _fade?.cancel();
    _player.dispose();
  }
}

typedef VoidCallback = void Function();
