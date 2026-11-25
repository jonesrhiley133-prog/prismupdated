import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Exposes `window.prismPerf(name, arg)` for the profiling harness.
void exposeDispatcher(String Function(String name, String arg) dispatch) {
  globalContext.setProperty(
    'prismPerf'.toJS,
    ((JSString name, JSString? arg) => dispatch(
      name.toDart,
      arg?.toDart ?? '',
    ).toJS).toJS,
  );
}
