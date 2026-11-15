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

  // Startup check: if Prism hasn't opened after a while, explain what
  // happened instead of leaving a blank page.
  var startup = (window.__prismStartup = {
    stages: ['page'],
    errors: [],
    stage: function (name) {
      if (startup.stages[startup.stages.length - 1] !== name) startup.stages.push(name);
      if (name === 'app') hidePanel();
    },
    error: function (message) {
      startup.errors.push(String(message));
      if (startup.errors.length > 8) startup.errors.shift();
      if (panel) showPanel();
    },
  });
  window.addEventListener('error', function (e) {
    startup.error((e && (e.message || (e.target && e.target.src))) || 'Script error');
  }, true);
  window.addEventListener('unhandledrejection', function (e) {
    startup.error('Unhandled: ' + (e && e.reason && (e.reason.message || e.reason)));
  });

  var panel = null;
  function hidePanel() {
    if (panel) panel.remove();
    panel = null;
  }
  function stageText() {
    var last = startup.stages[startup.stages.length - 1];
    return {
      page: 'Downloading Prism',
      engine: 'Starting the graphics engine',
      running: 'Starting Prism',
      dart: 'Starting Prism',
      'db-open': 'Opening your data (browser database)',
      'db-ready': 'Loading your workspace',
    }[last] || last;
  }
  function button(label, onClick, primary) {
    var b = document.createElement('button');
    b.textContent = label;
    b.style.cssText = 'margin:6px 8px 0 0;padding:9px 14px;border-radius:10px;border:1px solid #6b5a86;cursor:pointer;font:600 14px system-ui,sans-serif;' +
      (primary ? 'background:#8b6cc4;color:#fff;border-color:#8b6cc4;' : 'background:transparent;color:#eee;');
    b.onclick = onClick;
    return b;
  }
  function go(renderer) {
    var u = new URL(window.location.href);
    if (renderer) u.searchParams.set('renderer', renderer);
    window.location.href = u.toString();
  }
  function showPanel() {
    if (startup.stages[startup.stages.length - 1] === 'app') return;
    if (!panel) {
      panel = document.createElement('div');
      panel.setAttribute('role', 'alert');
      panel.style.cssText = 'position:fixed;inset:0;z-index:2147483647;display:flex;align-items:center;justify-content:center;background:rgba(20,18,16,.92);color:#eee;font:15px/1.45 system-ui,sans-serif;padding:16px;';
      document.body.appendChild(panel);
    }
    var r = window.__prismRenderer || {};
    var card = document.createElement('div');
    card.style.cssText = 'max-width:560px;width:100%;background:#2a2723;border:1px solid #4a4540;border-radius:16px;padding:22px 24px;box-shadow:0 12px 40px rgba(0,0,0,.5);';
    card.innerHTML =
      '<div style="font:800 20px system-ui,sans-serif;margin-bottom:6px">Prism is taking longer than usual</div>' +
      '<div style="opacity:.8;margin-bottom:12px">Stuck at: <b></b></div>' +
      '<ul style="margin:0 0 12px 18px;padding:0;opacity:.85"><li>Close any other Prism tabs and the installed Prism app window, then reload.</li>' +
      '<li>If that doesn\u2019t help, try the other drawing mode below.</li></ul>' +
      '<pre style="white-space:pre-wrap;max-height:160px;overflow:auto;background:#1c1a17;border-radius:10px;padding:10px;font:12px ui-monospace,monospace;margin:0 0 6px"></pre>';
    card.querySelector('b').textContent = stageText();
    card.querySelector('pre').textContent =
      'Drawing: ' + (r.cpuOnly ? 'compatibility (software)' : 'graphics card') + (r.reason ? ' \u2014 ' + r.reason : '') +
      '\nSteps: ' + startup.stages.join(' \u2192 ') +
      (startup.errors.length ? '\nErrors:\n' + startup.errors.join('\n') : '\nErrors: none');
    card.appendChild(button('Reload', function () { go(null); }, true));
    card.appendChild(button(r.cpuOnly ? 'Use graphics card' : 'Use compatibility mode', function () { go(r.cpuOnly ? 'gpu' : 'cpu'); }));
    card.appendChild(button('Keep waiting', hidePanel));
    panel.innerHTML = '';
    panel.appendChild(card);
  }
  setTimeout(showPanel, 20000);

  var engineConfig = { renderer: 'canvaskit', canvasKitForceCpuOnly: cpuOnly };
  _flutter.loader.load({
    config: engineConfig,
    onEntrypointLoaded: async function (engineInitializer) {
      try {
        startup.stage('engine');
        var appRunner = await engineInitializer.initializeEngine(engineConfig);
        startup.stage('running');
        await appRunner.runApp();
      } catch (e) {
        startup.error('Engine failed to start: ' + (e && (e.message || e)));
        showPanel();
      }
    },
  });
})();
