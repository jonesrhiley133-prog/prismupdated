import 'dart:js_interop';
import 'dart:typed_data';

@JS('window.__prismRenderer')
external _RendererInfo? get _info;

extension type _RendererInfo._(JSObject _) implements JSObject {
  external String? get mode;
  external bool? get cpuOnly;
  external String? get reason;
}

@JS('localStorage')
external _Storage get _storage;

extension type _Storage._(JSObject _) implements JSObject {
  external void setItem(String key, String value);
  external void removeItem(String key);
}

@JS('location')
external _Location get _location;

extension type _Location._(JSObject _) implements JSObject {
  external void reload();
}

String webRendererMode() => _info?.mode ?? 'auto';

bool webUsesCpuRendering() => _info?.cpuOnly ?? false;

String? webRendererReason() => _info?.reason;

void setWebRendererMode(String mode) {
  try {
    if (mode == 'auto') {
      _storage.removeItem('prism.renderer');
    } else {
      _storage.setItem('prism.renderer', mode);
    }
  } catch (_) {}
  _location.reload();
}

@JS('window.__prismStartup')
external _Startup? get _startup;

extension type _Startup._(JSObject _) implements JSObject {
  external void stage(String name);
  external void error(String message);
}

void markWebStage(String stage) {
  try {
    _startup?.stage(stage);
  } catch (_) {}
}

void reportWebError(String message) {
  try {
    _startup?.error(message.length > 800 ? message.substring(0, 800) : message);
  } catch (_) {}
}

@JS('window.prismSetChrome')
external JSFunction? get _setChrome;

int? _lastChrome;

void setWebChromeColor(int argb) {
  if (_lastChrome == argb) return;
  final fn = _setChrome;
  if (fn == null) return;
  _lastChrome = argb;
  final hex = (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
  fn.callAsFunction(null, '#$hex'.toJS);
}

@JS('window.prismDownload')
external JSFunction? get _download;

bool downloadWebFile(List<int> bytes, String name, String mimeType) {
  final fn = _download;
  if (fn == null) return false;
  final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  final ok = fn.callAsFunction(null, data.toJS, name.toJS, mimeType.toJS);
  return ok.dartify() == true;
}
