import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What the device reports about its graphics and power situation. Fields
/// the platform can't tell us stay at neutral defaults.
@immutable
class GraphicsDeviceInfo {
  const GraphicsDeviceInfo({
    this.supported = false,
    this.lowRam = false,
    this.memoryClassMb,
    this.totalRamMb,
    this.refreshRates = const [],
    this.thermal = 0,
    this.powerSave = false,
    this.renderer,
    this.sdk,
  });

  /// True when the native side answered (Android).
  final bool supported;
  final bool lowRam;
  final int? memoryClassMb, totalRamMb;

  /// Refresh rates the display offers at its current resolution.
  final List<double> refreshRates;

  /// Android thermal status: 0 none … 6 shutdown.
  final int thermal;
  final bool powerSave;

  /// The renderer this launch actually used ('auto', 'compatibility',
  /// 'software').
  final String? renderer;
  final int? sdk;

  static GraphicsDeviceInfo fromMap(Map<Object?, Object?> m) =>
      GraphicsDeviceInfo(
        supported: true,
        lowRam: m['lowRam'] == true,
        memoryClassMb: (m['memoryClass'] as num?)?.toInt(),
        totalRamMb: (m['totalRamMb'] as num?)?.toInt(),
        refreshRates: [
          for (final r in (m['refreshRates'] as List?) ?? const [])
            if (r is num) r.toDouble(),
        ]..sort(),
        thermal: (m['thermal'] as num?)?.toInt() ?? 0,
        powerSave: m['powerSave'] == true,
        renderer: m['renderer'] as String?,
        sdk: (m['sdk'] as num?)?.toInt(),
      );
}

/// Bridge to the Android side (MainActivity, channel "prism/graphics").
/// Other platforms answer with defaults.
abstract final class GraphicsPlatform {
  static const _ch = MethodChannel('prism/graphics');

  static bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<GraphicsDeviceInfo> info() async {
    if (!_android) return const GraphicsDeviceInfo();
    try {
      final m = await _ch.invokeMapMethod<Object?, Object?>('info');
      return m == null
          ? const GraphicsDeviceInfo()
          : GraphicsDeviceInfo.fromMap(m);
    } catch (_) {
      return const GraphicsDeviceInfo();
    }
  }

  /// Asks the display for [fps] (0 = the system's choice). Android picks
  /// the closest refresh rate the screen supports.
  static Future<void> setFrameRate(int fps) async {
    if (!_android) return;
    try {
      await _ch.invokeMethod<void>('setFrameRate', {'fps': fps});
    } catch (_) {}
  }

  /// Confirms this launch rendered its first frame, so a non-default
  /// renderer isn't rolled back on the next start.
  static Future<void> markRendered() async {
    if (!_android) return;
    try {
      await _ch.invokeMethod<void>('markRendered');
    } catch (_) {}
  }

  static bool get rendererChoiceSupported => _android;
  static bool get frameRateChoiceSupported => _android;
}
