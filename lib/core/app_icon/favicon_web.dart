import 'dart:js_interop';

@JS('document.querySelector')
external _Link? _query(String selector);

extension type _Link._(JSObject _) implements JSObject {
  external set href(String value);
}

/// Sets the browser tab icon.
void setFavicon(String href) {
  try {
    _query('link[rel="icon"]')?.href = href;
  } catch (_) {}
}
