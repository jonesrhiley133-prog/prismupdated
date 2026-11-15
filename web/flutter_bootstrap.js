{{flutter_js}}
{{flutter_build_config}}

// Picks how Prism draws on the web.
//
// Prism renders with CanvasKit. Its GPU (WebGL) mode is fastest, but some
// graphics drivers hand the browser a low-precision drawing surface or
// mis-draw Skia's text, which makes the whole app look dithered, noisy and
// "corrupted". Software (CPU) rendering always draws correctly.
//
//   ?renderer=cpu   always use software rendering (remembered)
//   ?renderer=gpu   always use the GPU (remembered)
//   ?renderer=auto  go back to automatic detection
//
// The same choice is available in Prism under Settings › Appearance.
(function () {
  var KEY = 'prism.renderer';

  function saved() {
    try {
      var q = new URLSearchParams(window.location.search).get('renderer');
      if (q === 'cpu' || q === 'gpu') window.localStorage.setItem(KEY, q);
      if (q === 'auto') window.localStorage.removeItem(KEY);
      return window.localStorage.getItem(KEY);
    } catch (e) {
      return null;
    }
  }

  // Returns a reason to avoid the GPU, or null when it looks healthy.
  function gpuProblem() {
    try {
      var canvas = document.createElement('canvas');
      var gl = canvas.getContext('webgl2') || canvas.getContext('webgl');
      if (!gl) return 'no-webgl';
      var bits = [gl.RED_BITS, gl.GREEN_BITS, gl.BLUE_BITS].map(function (b) {
        return gl.getParameter(b);
      });
      var reason = null;
      // 16-bit (RGB565) surfaces dither everything Flutter draws.
      if (bits.some(function (b) { return b < 8; })) reason = 'low-precision-surface';
      if (!reason) {
        var info = gl.getExtension('WEBGL_debug_renderer_info');
        var renderer = info ? String(gl.getParameter(info.UNMASKED_RENDERER_WEBGL)) : '';
        // Driver families with known Skia/WebGL text corruption.
        if (/Mali-4|Adreno \(TM\) [23]\d\d|PowerVR SGX|Intel\(R\) GMA/i.test(renderer)) {
          reason = 'gpu-blocklist:' + renderer;
        }
      }
      var lose = gl.getExtension('WEBGL_lose_context');
      if (lose) lose.loseContext();
      return reason;
    } catch (e) {
      return 'webgl-error';
    }
  }

  // The app icon chosen in Settings › Appearance (stored by shared_preferences).
  try {
    var icon = JSON.parse(window.localStorage.getItem('flutter.prism.appIcon') || 'null');
    var link = document.querySelector('link[rel="icon"]');
    if (link && icon === 'custom') {
      var png = JSON.parse(window.localStorage.getItem('flutter.prism.appIcon.custom') || 'null');
      if (typeof png === 'string') link.href = 'data:image/png;base64,' + png;
    } else if (link && typeof icon === 'string' && /^[a-z]+$/.test(icon)) {
      link.href = 'icons/app/' + icon + '.png';
    }
  } catch (e) {}

  var choice = saved();
  var reason = choice === 'cpu' ? 'chosen' : choice === 'gpu' ? null : gpuProblem();
  var cpuOnly = choice === 'cpu' || (choice !== 'gpu' && reason !== null);
  window.__prismRenderer = { mode: choice || 'auto', cpuOnly: cpuOnly, reason: reason };
  if (cpuOnly) console.info('[Prism] Using software rendering (' + reason + ').');

  _flutter.loader.load({
    config: { renderer: 'canvaskit', canvasKitForceCpuOnly: cpuOnly },
  });
})();
