import 'dart:io' show File;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import 'package:prism_plurality/features/games/engines/ambience_synth.dart';

/// Short tones and soft noise made on the device (no audio files). Uses its
/// own player that doesn't take audio focus, so Prism's music keeps playing.
class TonePlayer {
  TonePlayer();

  AudioPlayer? _player;
  static final Map<String, Uri> _cache = {};

  /// A pentatonic-ish scale (Hz): pleasant in any order.
  static const scale = [
    261.63,
    293.66,
    329.63,
    392.0,
    440.0,
    523.25,
    587.33,
    659.25,
  ];

  AudioPlayer get _p => _player ??= AudioPlayer(
    handleAudioSessionActivation: false,
    handleInterruptions: false,
  );

  /// Plays a soft note. Failures are silent: sound is always optional.
  Future<void> play(double hz, {int ms = 380, double volume = 0.6}) async {
    try {
      final uri = await _uriFor(
        't${hz.toStringAsFixed(1)}_$ms',
        () => _wav(_tone(hz, ms)),
      );
      await _p.setAudioSource(AudioSource.uri(uri));
      await _p.setVolume(volume);
      await _p.seek(Duration.zero);
      await _p.play();
    } catch (_) {}
  }

  /// Loops a generated ambience from [ambienceCatalog] (rain, chimes…).
  Future<void> loop(String kind, {double volume = 0.4}) async {
    try {
      final uri = await _ambienceUri(kind);
      await _p.setAudioSource(AudioSource.uri(uri));
      await _p.setLoopMode(LoopMode.one);
      await _p.setVolume(volume);
      await _p.play();
    } catch (_) {}
  }

  Future<void> setVolume(double v) async {
    try {
      await _player?.setVolume(v);
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _player?.stop();
    } catch (_) {}
  }

  void dispose() {
    _player?.dispose();
    _player = null;
  }

  static final Map<String, Future<Uri>> _pending = {};

  /// Ambiences take a moment to synthesize, so they're built off the UI
  /// thread (where possible) and cached on disk.
  static Future<Uri> _ambienceUri(String kind) {
    final key = 'amb3_$kind';
    final hit = _cache[key];
    if (hit != null) return Future.value(hit);
    return _pending[key] ??= () async {
      try {
        if (!kIsWeb) {
          final dir = await getTemporaryDirectory();
          final f = File('${dir.path}/prism_tone_$key.wav');
          if (await f.exists()) return _cache[key] = Uri.file(f.path);
        }
        final bytes = kIsWeb
            ? ambienceWav(kind)
            : await compute(ambienceWav, kind);
        return await _uriFor(key, () => bytes);
      } finally {
        _pending.remove(key);
      }
    }();
  }

  /// A finished WAV file for [kind].
  static Uint8List ambienceWav(String kind) =>
      _wav(AmbienceSynth.render(kind), rate: AmbienceSynth.sampleRate);

  static Future<Uri> _uriFor(String key, Uint8List Function() make) async {
    final cached = _cache[key];
    if (cached != null) return cached;
    final bytes = make();
    Uri uri;
    if (kIsWeb) {
      uri = Uri.dataFromBytes(bytes, mimeType: 'audio/wav');
    } else {
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/prism_tone_$key.wav');
      if (!await f.exists()) await f.writeAsBytes(bytes, flush: true);
      uri = Uri.file(f.path);
    }
    return _cache[key] = uri;
  }

  static const _rate = 22050;

  static Float32List _tone(double hz, int ms) {
    final n = _rate * ms ~/ 1000;
    final out = Float32List(n);
    for (var i = 0; i < n; i++) {
      final t = i / _rate;
      final env =
          math.min(1.0, i / (_rate * 0.01)) * math.exp(-3.5 * t / (ms / 1000));
      out[i] =
          (math.sin(2 * math.pi * hz * t) * 0.7 +
              math.sin(4 * math.pi * hz * t) * 0.15) *
          env;
    }
    return out;
  }

  static Uint8List _wav(Float32List s, {int rate = _rate}) {
    final data = ByteData(44 + s.length * 2);
    void str(int o, String v) {
      for (var i = 0; i < v.length; i++) {
        data.setUint8(o + i, v.codeUnitAt(i));
      }
    }

    str(0, 'RIFF');
    data.setUint32(4, 36 + s.length * 2, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, rate, Endian.little);
    data.setUint32(28, rate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    str(36, 'data');
    data.setUint32(40, s.length * 2, Endian.little);
    for (var i = 0; i < s.length; i++) {
      data.setInt16(
        44 + i * 2,
        (s[i].clamp(-1.0, 1.0) * 32767).round(),
        Endian.little,
      );
    }
    return data.buffer.asUint8List();
  }
}
