import 'dart:math' as math;
import 'dart:typed_data';

/// One generated ambience. [musical] ones are tonal (no noise bed).
class AmbienceInfo {
  const AmbienceInfo(
    this.id,
    this.emoji,
    this.label,
    this.labelEs, {
    this.musical = false,
  });
  final String id;
  final String emoji;
  final String label;
  final String labelEs;
  final bool musical;
}

/// Every ambience Prism can make on the device, in display order.
const ambienceCatalog = <AmbienceInfo>[
  AmbienceInfo('rain', '🌧️', 'Rain', 'Lluvia'),
  AmbienceInfo('storm', '⛈️', 'Thunderstorm', 'Tormenta'),
  AmbienceInfo('wind', '🍃', 'Wind', 'Viento'),
  AmbienceInfo('waves', '🌊', 'Waves', 'Olas'),
  AmbienceInfo('fire', '🔥', 'Fireplace', 'Chimenea'),
  AmbienceInfo('stream', '💧', 'Stream', 'Arroyo'),
  AmbienceInfo('night', '🦗', 'Night crickets', 'Grillos'),
  AmbienceInfo('birds', '🐦', 'Morning birds', 'Pájaros'),
  AmbienceInfo('forest', '🌲', 'Forest', 'Bosque'),
  AmbienceInfo('cafe', '☕', 'Café', 'Café'),
  AmbienceInfo('room', '🛋️', 'Cozy room', 'Habitación acogedora'),
  AmbienceInfo('winter', '❄️', 'Winter wind', 'Viento de invierno'),
  AmbienceInfo('white', '☁️', 'Soft noise', 'Ruido suave'),
  AmbienceInfo(
    'chimes',
    '🎐',
    'Wind chimes',
    'Campanas de viento',
    musical: true,
  ),
  AmbienceInfo(
    'bowls',
    '🥣',
    'Singing bowls',
    'Cuencos tibetanos',
    musical: true,
  ),
  AmbienceInfo('musicbox', '🎶', 'Music box', 'Caja de música', musical: true),
  AmbienceInfo('harp', '🪕', 'Gentle harp', 'Arpa suave', musical: true),
  AmbienceInfo('pad', '🌌', 'Dreamy pads', 'Pads de ensueño', musical: true),
];

/// Builds seamless ambience loops sample by sample: shaped, filtered noise
/// for textures and individually synthesized events (drops, crackles, notes)
/// laid out on a circular buffer, so the loop point is inaudible.
class AmbienceSynth {
  AmbienceSynth._(this.sr, double secs, int seed)
    : n = (sr * secs).round(),
      rng = math.Random(seed);

  static const sampleRate = 32000;

  final int sr;
  final int n;
  final math.Random rng;

  /// Renders [kind] as mono samples in -1..1 at [sampleRate].
  static Float32List render(String kind) {
    final s = AmbienceSynth._(
      sampleRate,
      _length(kind),
      kind.hashCode & 0x7fffffff,
    );
    final out = switch (kind) {
      'rain' => s._rain(),
      'storm' => s._storm(),
      'wind' => s._wind(),
      'waves' => s._waves(),
      'fire' => s._fire(),
      'stream' => s._stream(),
      'night' => s._night(),
      'birds' => s._birds(),
      'forest' => s._forest(),
      'cafe' => s._cafe(),
      'room' => s._room(),
      'winter' => s._winter(),
      'chimes' => s._chimes(),
      'bowls' => s._bowls(),
      'musicbox' => s._musicBox(),
      'harp' => s._harp(),
      'pad' => s._pad(),
      _ => s._soft(),
    };
    s._finish(out, rms: kind == 'white' ? 0.10 : 0.12);
    return out;
  }

  static double _length(String kind) => switch (kind) {
    'storm' => 32,
    'waves' => 24,
    'birds' => 24,
    'wind' || 'night' || 'chimes' => 20,
    'forest' => 24,
    'cafe' => 20,
    'room' => 16,
    'winter' => 24,
    'bowls' => 30,
    'musicbox' => 19.2, // 6 bars at 75 bpm
    'harp' => 27.428571428571427, // 8 bars at 70 bpm
    'pad' => 32,
    'white' => 10,
    _ => 16,
  };

  // ---------------------------------------------------------------------------
  // Building blocks

  double get _r => rng.nextDouble();
  double _range(double a, double b) => a + (b - a) * _r;

  /// Periodic in the loop: k whole cycles across the buffer.
  double _cyc(int i, num k, [double phase = 0]) =>
      math.sin(2 * math.pi * k * i / n + phase);

  Float32List _white() {
    final o = Float32List(n);
    for (var i = 0; i < n; i++) {
      o[i] = _r * 2 - 1;
    }
    return o;
  }

  /// Runs [step] over the buffer circularly: a warm-up lap over the tail
  /// first, so the filter state at index 0 matches the end (no click).
  void _circular(int warm, void Function(int i, bool keep) step) {
    final w = math.min(warm, n);
    for (var j = n - w; j < n; j++) {
      step(j, false);
    }
    for (var i = 0; i < n; i++) {
      step(i, true);
    }
  }

  Float32List _pink() {
    final w = _white();
    final o = Float32List(n);
    var b0 = 0.0, b1 = 0.0, b2 = 0.0, b3 = 0.0, b4 = 0.0, b5 = 0.0, b6 = 0.0;
    _circular(sr ~/ 2, (i, keep) {
      final x = w[i];
      b0 = 0.99886 * b0 + x * 0.0555179;
      b1 = 0.99332 * b1 + x * 0.0750759;
      b2 = 0.96900 * b2 + x * 0.1538520;
      b3 = 0.86650 * b3 + x * 0.3104856;
      b4 = 0.55000 * b4 + x * 0.5329522;
      b5 = -0.7616 * b5 - x * 0.0168980;
      final y = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + x * 0.5362) * 0.11;
      b6 = x * 0.115926;
      if (keep) o[i] = y;
    });
    return o;
  }

  Float32List _brown() {
    final w = _white();
    final o = Float32List(n);
    var y = 0.0;
    _circular(sr, (i, keep) {
      y = y * 0.985 + w[i] * 0.12;
      if (keep) o[i] = y;
    });
    return o;
  }

  /// Filters [src] through [chain] (circularly). [mod] can retune filters
  /// every 16 samples for sweeps.
  Float32List _filter(
    Float32List src,
    List<_Biquad> chain, {
    void Function(int i)? mod,
  }) {
    final o = Float32List(n);
    _circular(sr ~/ 2, (i, keep) {
      if (mod != null && (i & 15) == 0) mod(i);
      var x = src[i];
      for (final f in chain) {
        x = f.run(x);
      }
      if (keep) o[i] = x;
    });
    return o;
  }

  _Biquad _lp(double f, [double q = 0.707]) => _Biquad()..lowpass(f, q, sr);
  _Biquad _hp(double f, [double q = 0.707]) => _Biquad()..highpass(f, q, sr);
  _Biquad _bp(double f, double q) => _Biquad()..bandpass(f, q, sr);

  /// Adds [ev] into [out] at [start], wrapping around the loop.
  void _place(Float32List out, int start, Float32List ev, [double gain = 1]) {
    for (var k = 0; k < ev.length; k++) {
      out[(start + k) % n] += ev[k] * gain;
    }
  }

  void _mix(
    Float32List out,
    Float32List src,
    double gain, [
    double Function(int i)? env,
  ]) {
    for (var i = 0; i < n; i++) {
      out[i] += src[i] * gain * (env == null ? 1 : env(i));
    }
  }

  /// A slowly breathing 0..1 envelope, periodic in the loop.
  double _gust(int i, [double seed = 0]) {
    final g =
        0.5 +
        0.26 * _cyc(i, 1, 0.3 + seed) +
        0.16 * _cyc(i, 3, 1.7 + seed) +
        0.08 * _cyc(i, 7, 0.4 + seed * 2);
    final c = g.clamp(0.0, 1.0);
    return c * c * (3 - 2 * c);
  }

  /// A tonal partial set: [ratios] × [hz], each with its own amp and decay.
  Float32List _bell(
    double hz,
    List<double> ratios,
    List<double> amps,
    List<double> decays,
    double secs, {
    double attack = 0.002,
    double detune = 0,
  }) {
    final len = (secs * sr).round();
    final o = Float32List(len);
    final a = (attack * sr).clamp(1, len).toDouble();
    for (var p = 0; p < ratios.length; p++) {
      final f = hz * ratios[p];
      if (f > sr * 0.45) continue;
      final w = 2 * math.pi * f / sr;
      final w2 = 2 * math.pi * (f + detune * (p + 1)) / sr;
      final ph = _r * 2 * math.pi;
      final k = math.exp(-1 / (decays[p] * sr));
      var e = amps[p];
      for (var i = 0; i < len; i++) {
        final att = i < a ? i / a : 1.0;
        final s = detune == 0
            ? math.sin(w * i + ph)
            : 0.5 * (math.sin(w * i + ph) + math.sin(w2 * i));
        o[i] += s * e * att;
        e *= k;
      }
    }
    return o;
  }

  /// A plucked string (Karplus-Strong) — warm and natural.
  Float32List _pluck(
    double hz,
    double secs, {
    double bright = 0.5,
    double sustain = 0.996,
  }) {
    final len = (secs * sr).round();
    final o = Float32List(len);
    final period = sr / hz;
    final d = period.floor();
    final frac = period - d;
    final line = Float32List(d + 2);
    var lp = 0.0;
    for (var k = 0; k < line.length; k++) {
      final x = _r * 2 - 1;
      lp = lp + (x - lp) * (0.25 + bright * 0.6);
      line[k] = lp;
    }
    var idx = 0;
    var prev = 0.0;
    for (var i = 0; i < len; i++) {
      final a = line[idx];
      final b = line[(idx + 1) % line.length];
      final y = a + (b - a) * frac;
      o[i] = y;
      final nv = sustain * 0.5 * (y + prev);
      prev = y;
      line[idx] = nv;
      idx = (idx + 1) % (d + 1);
    }
    // gentle fade so wrapped tails don't click
    final f = math.min(len, sr ~/ 10);
    for (var i = 0; i < f; i++) {
      o[len - 1 - i] *= i / f;
    }
    return o;
  }

  /// Simple Schroeder reverb, run twice around the loop so the tail of the
  /// end flows into the start.
  Float32List _reverb(
    Float32List dry, {
    double mix = 0.3,
    double room = 0.84,
    double damp = 0.3,
  }) {
    final scale = sr / 44100;
    final combs = [
      1557,
      1617,
      1491,
      1422,
      1277,
      1356,
    ].map((d) => _Comb((d * scale).round(), room, damp)).toList();
    final alls = [
      556,
      441,
      341,
      225,
    ].map((d) => _Allpass((d * scale).round())).toList();
    final wet = Float32List(n);
    for (var pass = 0; pass < 2; pass++) {
      for (var i = 0; i < n; i++) {
        final x = dry[i] * 0.12;
        var y = 0.0;
        for (final c in combs) {
          y += c.run(x);
        }
        for (final a in alls) {
          y = a.run(y);
        }
        if (pass == 1) wet[i] = y;
      }
    }
    final o = Float32List(n);
    for (var i = 0; i < n; i++) {
      o[i] = dry[i] * (1 - mix * 0.5) + wet[i] * mix;
    }
    return o;
  }

  /// Level to a comfortable loudness, take off harsh top end, limit peaks.
  void _finish(Float32List o, {required double rms}) {
    final top = _lp(9000);
    final dc = _hp(45);
    final tmp = Float32List.fromList(o);
    _circular(sr ~/ 4, (i, keep) {
      final y = dc.run(top.run(tmp[i]));
      if (keep) o[i] = y;
    });
    var sum = 0.0, peak = 1e-9;
    for (final v in o) {
      sum += v * v;
      peak = math.max(peak, v.abs());
    }
    final cur = math.sqrt(sum / n) + 1e-9;
    final g = rms / cur;
    for (var i = 0; i < n; i++) {
      final x = o[i] * g;
      // soft knee above 0.6 so peaks round off instead of clipping
      o[i] = x.abs() < 0.6
          ? x
          : x.sign * (0.6 + 0.35 * _tanh((x.abs() - 0.6) / 0.35));
    }
  }

  static double _tanh(double x) {
    final e = math.exp(2 * x);
    return (e - 1) / (e + 1);
  }

  static const _penta = [0, 2, 4, 7, 9];
  static double _midi(num m) => 440.0 * math.pow(2, (m - 69) / 12);

  // ---------------------------------------------------------------------------
  // Nature

  Float32List _rain() {
    final out = Float32List(n);
    // A soft, filtered wash — the "body" of rain heard from indoors.
    final bed = _filter(_pink(), [_hp(350), _lp(2800), _lp(4200)]);
    _mix(out, bed, 0.55, (i) => 0.85 + 0.15 * _gust(i));
    _mix(out, _filter(_brown(), [_lp(160)]), 0.12);
    // Thousands of individual drops: soft taps plus a few bright plinks.
    final drops = (n / sr * 170).round();
    for (var d = 0; d < drops; d++) {
      final start = (_r * n).floor();
      final loud = math.pow(_r, 3).toDouble();
      if (_r < 0.9) {
        final len = (sr * _range(0.003, 0.012)).round();
        final ev = Float32List(len);
        final f = _bp(_range(1200, 4800), _range(1.2, 3));
        final tau = len / 3.5;
        for (var k = 0; k < len; k++) {
          ev[k] = f.run((_r * 2 - 1) * math.exp(-k / tau));
        }
        _place(out, start, ev, 0.05 + 0.35 * loud);
      } else {
        final len = (sr * _range(0.012, 0.03)).round();
        final ev = Float32List(len);
        final f0 = _range(1400, 3200);
        var ph = 0.0;
        for (var k = 0; k < len; k++) {
          final p = k / len;
          ph += 2 * math.pi * f0 * (1 + 0.6 * p) / sr;
          ev[k] = math.sin(ph) * math.exp(-p * 6) * math.min(1, k / 30);
        }
        _place(out, start, ev, 0.02 + 0.08 * loud);
      }
    }
    // A slow drip nearby, every second or so.
    for (var t = 0.0; t < n / sr; t += _range(0.8, 1.6)) {
      final len = (sr * 0.05).round();
      final ev = Float32List(len);
      final f0 = _range(900, 1400);
      var ph = 0.0;
      for (var k = 0; k < len; k++) {
        final p = k / len;
        ph += 2 * math.pi * f0 * (1 + 0.9 * p) / sr;
        ev[k] = math.sin(ph) * math.exp(-p * 7) * math.min(1, k / 20);
      }
      _place(out, (t * sr).round(), ev, 0.05);
    }
    return out;
  }

  Float32List _storm() {
    final out = _rain();
    // Rolling thunder: a crack that melts into a long, low rumble.
    for (final at in [3.0, 15.0, 25.5]) {
      final len = (sr * _range(5, 7)).round();
      final src = Float32List(len);
      var b = 0.0;
      for (var k = 0; k < len; k++) {
        b = b * 0.997 + (_r * 2 - 1) * 0.05;
        src[k] = b;
      }
      final lp = _lp(_range(220, 380));
      final lp2 = _lp(500);
      final ev = Float32List(len);
      for (var k = 0; k < len; k++) {
        final t = k / sr;
        final env =
            math.min(1, t / 0.15) *
            (0.55 * math.exp(-t * 2.5) + 0.45 * math.exp(-t * 0.55)) *
            (0.75 + 0.25 * math.sin(t * 5.3 + 1));
        ev[k] = lp2.run(lp.run(src[k])) * env;
      }
      _place(out, (at * sr).round(), ev, _range(1.8, 2.6));
    }
    return out;
  }

  Float32List _wind() {
    final out = Float32List(n);
    final pink = _pink();
    // The main body: a band of noise whose pitch rises as gusts build.
    final body = _bp(400, 1.1);
    final low = _bp(220, 0.9);
    _mix(
      out,
      _filter(pink, [
        body,
        _lp(1800),
      ], mod: (i) => body.bandpass(220 + 520 * _gust(i), 1.1, sr)),
      1.0,
      (i) => 0.25 + 0.9 * math.pow(_gust(i), 1.4),
    );
    _mix(
      out,
      _filter(pink, [
        low,
      ], mod: (i) => low.bandpass(140 + 160 * _gust(i, 1), 0.9, sr)),
      0.7,
      (i) => 0.4 + 0.6 * _gust(i, 1),
    );
    // A faint whistle through gaps, only in strong gusts.
    final whistle = _bp(900, 9);
    _mix(
      out,
      _filter(pink, [
        whistle,
      ], mod: (i) => whistle.bandpass(650 + 700 * _gust(i, 2), 9, sr)),
      0.35,
      (i) => math.pow(_gust(i, 2), 3).toDouble(),
    );
    // Leaves rustling when the wind is up.
    final rustle = _filter(_white(), [_hp(1800), _lp(5000)]);
    final mod = _filter(_white(), [_lp(12), _lp(12)]);
    _mix(out, rustle, 0.06, (i) => _gust(i) * (0.5 + 6 * mod[i].abs()));
    return out;
  }

  Float32List _waves() {
    final out = Float32List(n);
    final starts = [0.0, 7.7, 16.1].map((s) => (s * sr).round()).toList();
    double wave(int i) {
      var w = 0.0;
      for (final s in starts) {
        final t = ((i - s) % n + n) % n / sr;
        // swell 3 s, crash, then a long wash back out
        w += t < 3 ? math.pow(t / 3, 2.2).toDouble() : math.exp(-(t - 3) / 1.6);
      }
      return w.clamp(0.0, 1.2);
    }

    final surf = _lp(400);
    final env = Float32List(n);
    for (var i = 0; i < n; i++) {
      env[i] = wave(i);
    }
    _mix(
      out,
      _filter(_pink(), [
        surf,
        _lp(3000),
      ], mod: (i) => surf.lowpass(220 + 1600 * env[i], 0.6, sr)),
      1.0,
      (i) => 0.12 + 0.88 * env[i],
    );
    // Foam fizz as each wave pulls back over the sand.
    final fizz = _filter(_white(), [_bp(3800, 0.6)]);
    _mix(
      out,
      fizz,
      0.05,
      (i) =>
          math.max(0, env[i] - 0.15) *
          (env[(i + sr ~/ 4) % n] < env[i] ? 1.0 : 0.3),
    );
    _mix(out, _filter(_brown(), [_lp(110)]), 0.15);
    return out;
  }

  Float32List _fire() {
    final out = Float32List(n);
    // The low roar of burning wood, flickering.
    final flick = _filter(_white(), [_lp(3), _lp(3)]);
    var fpeak = 1e-9;
    for (final v in flick) {
      fpeak = math.max(fpeak, v.abs());
    }
    double fl(int i) => 0.75 + 0.25 * (flick[i] / fpeak);
    _mix(out, _filter(_brown(), [_hp(60), _lp(260), _lp(400)]), 0.2, fl);
    _mix(out, _filter(_pink(), [_bp(900, 0.8)]), 0.12, fl);
    // Crackles come in little clusters, like real embers.
    for (var t = 0.0; t < n / sr; t += -math.log(1 - _r) / 2.6) {
      var c = t;
      final count = 1 + (_r * 5).floor();
      for (var k = 0; k < count; k++) {
        c += _range(0.006, 0.07);
        final len = (sr * _range(0.0015, 0.005)).round();
        final hp = _hp(_range(1200, 2600));
        final res = _bp(_range(1800, 4200), 2);
        final ev = Float32List(len);
        final tau = len / _range(3, 6);
        for (var j = 0; j < len; j++) {
          final x = (_r * 2 - 1) * math.exp(-j / tau);
          ev[j] = hp.run(x) * 0.7 + res.run(x) * 0.6;
        }
        final big = math.pow(_r, 2.5).toDouble();
        _place(out, (c * sr).round(), ev, 0.3 + 2.2 * big);
      }
    }
    // Now and then a soft pop or log shift.
    for (var t = 0.0; t < n / sr; t += _range(2.5, 5)) {
      final len = (sr * 0.06).round();
      final ev = Float32List(len);
      final f = _bp(_range(250, 600), 3);
      for (var j = 0; j < len; j++) {
        ev[j] = f.run((_r * 2 - 1) * math.exp(-j / (len / 5)));
      }
      _place(out, (t * sr).round(), ev, 0.5);
    }
    return out;
  }

  Float32List _stream() {
    final out = Float32List(n);
    final pink = _pink();
    for (final (f, g) in [(500.0, 0.6), (1100.0, 0.45), (2300.0, 0.25)]) {
      final m = _filter(_white(), [_lp(_range(4, 9)), _lp(8)]);
      var mp = 1e-9;
      for (final v in m) {
        mp = math.max(mp, v.abs());
      }
      _mix(
        out,
        _filter(pink, [_bp(f, 1.4)]),
        g,
        (i) => 0.55 + 0.45 * m[i] / mp,
      );
    }
    // Little bubbles and burbles.
    for (var t = 0.0; t < n / sr; t += -math.log(1 - _r) / 14) {
      final len = (sr * _range(0.012, 0.04)).round();
      final ev = Float32List(len);
      final f0 = _range(350, 1100);
      var ph = 0.0;
      for (var k = 0; k < len; k++) {
        final p = k / len;
        ph += 2 * math.pi * f0 * (1 + 0.8 * p) / sr;
        ev[k] = math.sin(ph) * math.sin(math.pi * p);
      }
      _place(out, (t * sr).round(), ev, _range(0.02, 0.07));
    }
    return out;
  }

  Float32List _night() {
    final out = Float32List(n);
    _mix(
      out,
      _filter(_pink(), [_hp(120), _lp(450)]),
      0.12,
      (i) => 0.6 + 0.4 * _gust(i),
    );
    // Three crickets at different distances, each with its own rhythm.
    for (final (hz, gap, amp) in [
      (4400.0, 0.85, 0.05),
      (4750.0, 1.15, 0.03),
      (5100.0, 0.7, 0.018),
    ]) {
      final w = 2 * math.pi * hz / sr;
      for (var t = _r; t < n / sr; t += gap * _range(0.92, 1.08)) {
        final pulses = 3 + (_r * 2).floor();
        final len = (sr * pulses * 0.03).round();
        final ev = Float32List(len);
        for (var k = 0; k < len; k++) {
          final p = (k / sr) % 0.03;
          final on = p < 0.016 ? math.sin(math.pi * p / 0.016) : 0.0;
          ev[k] = math.sin(w * k) * on;
        }
        _place(out, (t * sr).round(), ev, amp);
      }
    }
    // A distant owl, once per loop.
    for (final at in [6.0, 6.55]) {
      final len = (sr * 0.45).round();
      final ev = Float32List(len);
      var ph = 0.0;
      for (var k = 0; k < len; k++) {
        final p = k / len;
        ph += 2 * math.pi * (380 - 40 * p) / sr;
        ev[k] =
            math.sin(ph) *
            math.sin(math.pi * p) *
            (0.8 + 0.2 * math.sin(ph * 0.02));
      }
      _place(out, (at * sr).round(), ev, 0.03);
    }
    return out;
  }

  Float32List _birds() {
    final out = Float32List(n);
    _mix(
      out,
      _filter(_pink(), [_bp(380, 0.7)]),
      0.18,
      (i) => 0.6 + 0.4 * _gust(i),
    );
    // Three kinds of bird, each singing its own recognisable phrase.
    final kinds = [
      (
        base: 3200.0,
        sweep: 900.0,
        dur: 0.09,
        notes: 4,
        vib: 0.0,
        amp: 0.06,
        every: 4.5,
      ),
      (
        base: 2400.0,
        sweep: -700.0,
        dur: 0.16,
        notes: 2,
        vib: 0.0,
        amp: 0.05,
        every: 6.0,
      ),
      (
        base: 4200.0,
        sweep: 300.0,
        dur: 0.05,
        notes: 7,
        vib: 35.0,
        amp: 0.03,
        every: 3.2,
      ),
    ];
    for (final b in kinds) {
      for (var t = _r * b.every; t < n / sr; t += b.every * _range(0.7, 1.3)) {
        var c = t;
        final dist = _range(0.5, 1.0);
        for (var k = 0; k < b.notes; k++) {
          final len = (sr * b.dur * _range(0.85, 1.15)).round();
          final ev = Float32List(len);
          final f0 = b.base * _range(0.96, 1.04);
          var ph = 0.0;
          for (var j = 0; j < len; j++) {
            final p = j / len;
            final f =
                f0 +
                b.sweep * p +
                (b.vib > 0 ? 120 * math.sin(2 * math.pi * b.vib * j / sr) : 0);
            ph += 2 * math.pi * f / sr;
            final e = math.pow(math.sin(math.pi * p), 2).toDouble();
            ev[j] = (math.sin(ph) + 0.15 * math.sin(2 * ph)) * e;
          }
          _place(out, (c * sr).round(), ev, b.amp * dist);
          c += b.dur + _range(0.03, 0.08);
        }
      }
    }
    return _reverb(out, mix: 0.25, room: 0.8);
  }

  /// Soft wind in the trees with birds now and then.
  Float32List _forest() {
    final wind = _wind(), birds = _birds();
    final out = Float32List(n);
    for (var i = 0; i < n; i++) {
      out[i] = wind[i] * 0.4 + birds[i] * 0.6;
    }
    // A little leaf rustle underneath.
    _mix(
      out,
      _filter(_white(), [_hp(2500), _lp(6500)]),
      0.025,
      (i) => 0.4 + 0.6 * _gust(i, 3),
    );
    return out;
  }

  /// A low murmur of conversation, cups and a distant machine.
  Float32List _cafe() {
    final out = Float32List(n);
    // Voices: speech-band noise swelling and fading in loose phrases.
    for (var v = 0; v < 5; v++) {
      final f = _range(300, 900);
      final band = _filter(_pink(), [_bp(f, 1.2), _lp(2600)]);
      _mix(
        out,
        band,
        0.22,
        (i) =>
            0.25 +
            0.75 *
                math
                    .pow(0.5 + 0.5 * _cyc(i, 2 + v * 3, v * 1.9), 2.2)
                    .toDouble(),
      );
    }
    _mix(out, _filter(_brown(), [_lp(180)]), 0.18);
    // Cups and spoons: short, bright, quiet pings.
    for (var t = 0.0; t < n / sr; t += -math.log(1 - _r) / 0.55) {
      final len = (sr * _range(0.08, 0.22)).round();
      final f = _range(2600, 5200);
      final res = _bp(f, 14);
      final ev = Float32List(len);
      final tau = len / _range(3, 5);
      for (var j = 0; j < len; j++) {
        ev[j] =
            res.run((_r * 2 - 1) * (j < 40 ? 1 : 0.02)) * math.exp(-j / tau);
      }
      _place(out, (t * sr).round(), ev, _range(0.5, 1.4));
    }
    return out;
  }

  /// Room tone with a quiet clock and a far-off fire.
  Float32List _room() {
    final out = Float32List(n);
    _mix(out, _filter(_brown(), [_lp(260)]), 0.5);
    _mix(out, _filter(_pink(), [_lp(900)]), 0.05);
    final seconds = n / sr;
    for (var t = 0.0; t < seconds - 0.01; t += 1.0) {
      final len = (sr * 0.045).round();
      final hp = _hp(1800), res = _bp(3200, 5);
      final tick = Float32List(len);
      for (var j = 0; j < len; j++) {
        final x = (_r * 2 - 1) * math.exp(-j / (len / 5));
        tick[j] = hp.run(x) * 0.6 + res.run(x) * 0.4;
      }
      _place(out, (t * sr).round(), tick, (t.round().isEven ? 1.0 : 0.8) * 1.4);
    }
    final fire = _fire();
    for (var i = 0; i < n; i++) {
      out[i] += fire[i] * 0.22;
    }
    return out;
  }

  /// Cold, low wind with a thin whistle.
  Float32List _winter() {
    final out = Float32List(n);
    final pink = _pink();
    final low = _bp(160, 0.8);
    _mix(
      out,
      _filter(pink, [
        low,
        _lp(700),
      ], mod: (i) => low.bandpass(110 + 140 * _gust(i, 4), 0.8, sr)),
      1.0,
      (i) => 0.3 + 0.8 * math.pow(_gust(i, 4), 1.3).toDouble(),
    );
    final mid = _bp(520, 1.2);
    _mix(
      out,
      _filter(pink, [
        mid,
        _lp(1500),
      ], mod: (i) => mid.bandpass(380 + 420 * _gust(i, 5), 1.2, sr)),
      0.5,
      (i) => math.pow(_gust(i, 5), 1.6).toDouble(),
    );
    final whistle = _bp(1100, 12);
    _mix(
      out,
      _filter(pink, [
        whistle,
      ], mod: (i) => whistle.bandpass(820 + 600 * _gust(i, 6), 12, sr)),
      0.28,
      (i) => math.pow(_gust(i, 6), 3.2).toDouble(),
    );
    return out;
  }

  Float32List _soft() {
    final out = Float32List(n);
    _mix(out, _filter(_brown(), [_lp(900)]), 0.5);
    _mix(out, _filter(_pink(), [_lp(1400), _lp(1800)]), 0.4);
    return out;
  }

  // ---------------------------------------------------------------------------
  // Musical

  Float32List _chimes() {
    final out = Float32List(n);
    final breeze = _filter(_pink(), [_bp(300, 0.8), _lp(1200)]);
    _mix(out, breeze, 0.25, (i) => 0.3 + 0.7 * _gust(i));
    final notes = [for (final p in _penta) _midi(84 + p)]..add(_midi(96));
    // More chimes ring when the breeze picks up.
    for (var t = 0.0; t < n / sr; t += _range(0.12, 0.5)) {
      final i = (t * sr).round() % n;
      if (_r > 0.25 + 0.75 * _gust(i)) continue;
      final hz = notes[(_r * notes.length).floor()];
      final ev = _bell(
        hz,
        const [1, 2.76, 5.40, 8.93],
        const [1, 0.45, 0.2, 0.08],
        const [3.2, 1.3, 0.5, 0.25],
        4.5,
        attack: 0.001,
      );
      _place(out, i, ev, _range(0.04, 0.12));
    }
    return _reverb(out, mix: 0.35, room: 0.86);
  }

  Float32List _bowls() {
    final out = Float32List(n);
    final pitches = [_midi(55), _midi(62), _midi(57), _midi(60)];
    for (var k = 0; k < pitches.length; k++) {
      final at = (k * n / pitches.length + _range(0, 0.8) * sr).round();
      final ev = _bell(
        pitches[k],
        const [1, 2.71, 5.14, 8.4],
        const [1, 0.55, 0.22, 0.08],
        const [11, 6, 2.8, 1.2],
        14,
        attack: 0.01,
        detune: 0.7,
      );
      _place(out, at, ev, 0.22);
      // The soft felt of the mallet.
      final thud = Float32List((sr * 0.04).round());
      final lp = _lp(500);
      for (var j = 0; j < thud.length; j++) {
        thud[j] = lp.run((_r * 2 - 1) * math.exp(-j / (thud.length / 4)));
      }
      _place(out, at, thud, 0.3);
    }
    return _reverb(out, mix: 0.3, room: 0.88);
  }

  /// I–vi–IV–V in C, as MIDI note numbers.
  static const _prog = [
    [48, 52, 55, 60, 64, 67, 72],
    [45, 48, 52, 57, 60, 64, 69],
    [41, 45, 48, 53, 57, 60, 65],
    [43, 47, 50, 55, 59, 62, 67],
  ];

  Float32List _musicBox() {
    final out = Float32List(n);
    const eighth = 0.4;
    final bars = (n / sr / (eighth * 8)).round();
    var last = 76;
    for (var bar = 0; bar < bars; bar++) {
      final chord = _prog[bar % 4];
      // Bass note on the downbeat.
      _place(
        out,
        (bar * 8 * eighth * sr).round(),
        _tine(_midi(chord[0] + 12)),
        0.12,
      );
      for (var e = 0; e < 8; e++) {
        if (e != 0 && _r < 0.35) continue;
        final strong = e % 4 == 0;
        final pool = strong
            ? chord.where((m) => m >= 64).map((m) => m + 12).toList()
            : [
                for (final o in [72, 84])
                  for (final p in _penta) o + p,
              ];
        pool.sort((a, b) => (a - last).abs().compareTo((b - last).abs()));
        final pick = pool[(_r * math.min(3, pool.length)).floor()];
        last = pick;
        _place(
          out,
          ((bar * 8 + e) * eighth * sr).round(),
          _tine(_midi(pick)),
          strong ? 0.16 : 0.11,
        );
      }
    }
    return _reverb(out, mix: 0.3, room: 0.82);
  }

  Float32List _tine(double hz) => _bell(
    hz,
    const [1, 2, 5.4],
    const [1, 0.22, 0.07],
    const [1.6, 0.5, 0.12],
    2.5,
    attack: 0.0008,
  );

  Float32List _harp() {
    final out = Float32List(n);
    final beat = 60 / 70;
    final bars = (n / sr / (beat * 4)).round();
    const pattern = [0, 2, 3, 4, 5, 4, 3, 2];
    for (var bar = 0; bar < bars; bar++) {
      final chord = _prog[bar % 4];
      for (var s = 0; s < 8; s++) {
        final m = chord[pattern[s]] + (s == 0 ? 0 : 12);
        final at = ((bar * 4 + s * 0.5) * beat * sr).round();
        _place(
          out,
          at,
          _pluck(_midi(m), 3.5, bright: 0.35, sustain: 0.997),
          s == 0 ? 0.45 : 0.3,
        );
      }
    }
    return _reverb(out, mix: 0.35, room: 0.86);
  }

  Float32List _pad() {
    final out = Float32List(n);
    const chords = [
      [48, 55, 59, 64, 67], // Cmaj7
      [45, 52, 55, 59, 64], // Am9-ish
      [41, 48, 52, 57, 64], // Fmaj7
      [43, 50, 55, 59, 62], // G
    ];
    final seg = n ~/ chords.length;
    final fade = (sr * 2.5).round();
    for (var c = 0; c < chords.length; c++) {
      for (final m in chords[c]) {
        final hz = _midi(m);
        for (final det in [-0.0018, 0.0, 0.0021]) {
          final w = 2 * math.pi * hz * (1 + det) / sr;
          final ph = _r * 2 * math.pi;
          final len = seg + fade;
          for (var k = 0; k < len; k++) {
            final env = k < fade
                ? 0.5 - 0.5 * math.cos(math.pi * k / fade)
                : (k > seg
                      ? 0.5 + 0.5 * math.cos(math.pi * (k - seg) / fade)
                      : 1.0);
            final s =
                math.sin(w * k + ph) +
                0.18 * math.sin(2 * (w * k + ph)) +
                0.05 * math.sin(3 * (w * k + ph));
            out[(c * seg + k) % n] += s * env * 0.02;
          }
        }
      }
    }
    for (var i = 0; i < n; i++) {
      out[i] *= 0.85 + 0.15 * _cyc(i, 8);
    }
    // A light shimmer of air on top.
    _mix(
      out,
      _filter(_pink(), [_bp(2400, 1.2)]),
      0.015,
      (i) => 0.5 + 0.5 * _cyc(i, 2),
    );
    return _reverb(out, mix: 0.4, room: 0.9, damp: 0.45);
  }
}

class _Biquad {
  double _b0 = 1, _b1 = 0, _b2 = 0, _a1 = 0, _a2 = 0;
  double _x1 = 0, _x2 = 0, _y1 = 0, _y2 = 0;

  void _set(double b0, double b1, double b2, double a0, double a1, double a2) {
    _b0 = b0 / a0;
    _b1 = b1 / a0;
    _b2 = b2 / a0;
    _a1 = a1 / a0;
    _a2 = a2 / a0;
  }

  (double, double) _wc(double f, double q, int sr) {
    final w = 2 * math.pi * f.clamp(10, sr * 0.45) / sr;
    return (math.cos(w), math.sin(w) / (2 * q));
  }

  void lowpass(double f, double q, int sr) {
    final (c, a) = _wc(f, q, sr);
    _set((1 - c) / 2, 1 - c, (1 - c) / 2, 1 + a, -2 * c, 1 - a);
  }

  void highpass(double f, double q, int sr) {
    final (c, a) = _wc(f, q, sr);
    _set((1 + c) / 2, -(1 + c), (1 + c) / 2, 1 + a, -2 * c, 1 - a);
  }

  void bandpass(double f, double q, int sr) {
    final (c, a) = _wc(f, q, sr);
    _set(a, 0, -a, 1 + a, -2 * c, 1 - a);
  }

  double run(double x) {
    final y = _b0 * x + _b1 * _x1 + _b2 * _x2 - _a1 * _y1 - _a2 * _y2;
    _x2 = _x1;
    _x1 = x;
    _y2 = _y1;
    _y1 = y;
    return y;
  }
}

class _Comb {
  _Comb(int len, this.feedback, this.damp)
    : _buf = Float32List(math.max(1, len));
  final Float32List _buf;
  final double feedback;
  final double damp;
  int _i = 0;
  double _store = 0;

  double run(double x) {
    final y = _buf[_i];
    _store = y * (1 - damp) + _store * damp;
    _buf[_i] = x + _store * feedback;
    _i = (_i + 1) % _buf.length;
    return y;
  }
}

class _Allpass {
  _Allpass(int len) : _buf = Float32List(math.max(1, len));
  final Float32List _buf;
  int _i = 0;

  double run(double x) {
    final b = _buf[_i];
    final y = -x + b;
    _buf[_i] = x + b * 0.5;
    _i = (_i + 1) % _buf.length;
    return y;
  }
}
