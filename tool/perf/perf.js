// Repeatable Prism performance flows on a web build with PRISM_PERF=true.
// usage: node perf.js <baseUrl> <outJson> [--trace-builds] [--profile-dir DIR]
// Conditions: Chromium headless, 412x915 @ DPR 2, touch, CPU throttled 4x.
const { chromium } = require('playwright');
const fs = require('fs');

const [base, outFile, ...rest] = process.argv.slice(2);
const traceBuilds = rest.includes('--trace-builds');
const profIdx = rest.indexOf('--profile-dir');
const profileDir = profIdx >= 0 ? rest[profIdx + 1] : null;
const THROTTLE = +(process.env.THROTTLE || 4);
const W = 412, H = 915;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

(async () => {
  const opts = { viewport: { width: W, height: H }, deviceScaleFactor: 2, hasTouch: true, isMobile: true, colorScheme: 'dark' };
  const ctx = profileDir
    ? await chromium.launchPersistentContext(profileDir, opts)
    : await (await chromium.launch()).newContext(opts);
  const page = ctx.pages()[0] || (await ctx.newPage());
  const cdp = await ctx.newCDPSession(page);
  const errors = [];
  page.on('console', (m) => { const t = m.text(); if (/exception|RenderFlex|overflow/i.test(t)) errors.push(t.slice(0, 200)); });
  page.on('pageerror', (e) => errors.push(String(e).slice(0, 200)));

  const perf = (name, arg = '') => page.evaluate(([n, a]) => window.prismPerf(n, a), [name, arg]);
  const waitReady = async (timeout = 600000) => {
    const t0 = Date.now();
    while (Date.now() - t0 < timeout) {
      const ok = await page.evaluate(() => typeof window.prismPerf === 'function').catch(() => false);
      if (ok) return Date.now() - t0;
      await sleep(250);
    }
    throw new Error('app never became ready');
  };
  const settle = (ms = 1500) => sleep(ms);

  // rAF interval sampler: what the browser actually presented.
  const rafStart = () => page.evaluate(() => {
    window.__raf = []; let last = performance.now(); window.__rafOn = true;
    const tick = (t) => { window.__raf.push(t - last); last = t; if (window.__rafOn) requestAnimationFrame(tick); };
    requestAnimationFrame(tick);
  });
  const rafStop = () => page.evaluate(() => { window.__rafOn = false; return window.__raf.slice(1); });

  const summarize = (frames, raf) => {
    const tot = frames.map((f) => f.total).sort((a, b) => a - b);
    const pct = (p) => (tot.length ? tot[Math.min(tot.length - 1, Math.floor(p * tot.length))] : 0);
    const avg = (xs) => (xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : 0);
    return {
      frames: frames.length,
      slowFrames: frames.filter((f) => f.total > 16.7).length,
      slowPct: frames.length ? +(100 * frames.filter((f) => f.total > 16.7).length / frames.length).toFixed(1) : 0,
      avgBuild: +avg(frames.map((f) => f.build)).toFixed(2),
      avgRaster: +avg(frames.map((f) => f.raster)).toFixed(2),
      p50: +pct(0.5).toFixed(2),
      p90: +pct(0.9).toFixed(2),
      p99: +pct(0.99).toFixed(2),
      worst: +(tot[tot.length - 1] || 0).toFixed(2),
      // Browser-side: presentation gaps longer than 1.5 vsyncs = dropped.
      droppedVsyncs: raf.filter((d) => d > 25).reduce((n, d) => n + Math.round(d / 16.7) - 1, 0),
      longestGap: +Math.max(0, ...raf).toFixed(1),
    };
  };

  const builds = async (fn) => {
    // Counts widget builds per type during fn (profile builds only).
    await page.evaluate(() => performance.clearMeasures());
    await perf('traceBuilds', 'on');
    await fn();
    await perf('traceBuilds', 'off');
    return page.evaluate(() => {
      const c = {};
      for (const e of performance.getEntriesByType('measure')) {
        const v = c[e.name] || (c[e.name] = [0, 0]);
        v[0] += 1; v[1] += e.duration;
      }
      return Object.entries(c).map(([k, [n, ms]]) => [k, n, +ms.toFixed(1)]).sort((a, b) => b[1] - a[1]).slice(0, 60);
    });
  };

  const measure = async (label, fn) => {
    await rafStart();
    await perf('start');
    await fn();
    const frames = JSON.parse(await perf('stop'));
    const raf = await rafStop();
    const s = summarize(frames, raf);
    console.log(label.padEnd(26), JSON.stringify(s));
    return s;
  };

  const touchDrag = async (x, y0, y1, steps = 12) => {
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x, y: y0 }] });
    for (let i = 1; i <= steps; i++) {
      await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x, y: y0 + ((y1 - y0) * i) / steps }] });
      await sleep(16);
    }
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  };
  const tap = async (x, y) => {
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x, y }] });
    await sleep(60);
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  };

  const result = { conditions: { viewport: `${W}x${H}@2x`, cpuThrottle: THROTTLE, base }, flows: {}, builds: {} };

  // ---------------------------------------------------------------- startup
  // First load seeds the fixture (may take minutes); then measure a cached
  // reload under throttling.
  await page.goto(base, { waitUntil: 'load' });
  result.firstLoadMs = await waitReady();
  // Wait until seeding has finished: the home route exists and members load.
  for (let i = 0; i < 240; i++) {
    const r = await perf('route').catch(() => '');
    if (r && !/onboard|setup|welcome/i.test(r)) break;
    await sleep(1000);
  }
  await settle(4000);
  for (let i = 0; i < 2; i++) { await page.keyboard.press('Escape'); await sleep(500); }
  await cdp.send('Emulation.setCPUThrottlingRate', { rate: THROTTLE });
  const t0 = Date.now();
  await page.reload({ waitUntil: 'load' });
  const firstFrame = page.evaluate(() => new Promise((r) => {
    if (document.querySelector('flt-glass-pane, flutter-view')?.shadowRoot || document.querySelector('flt-scene-host *')) r(0);
    window.addEventListener('flutter-first-frame', () => r(performance.now()), { once: true });
  }));
  result.startup = { readyMs: await waitReady(), firstFramePerfNow: Math.round(await Promise.race([firstFrame, sleep(60000).then(() => -1)])) };
  result.startup.wallMs = Date.now() - t0;
  console.log('startup', JSON.stringify(result.startup));
  await settle(3000);
  // Dismiss the "What's new" sheet if it is showing.
  for (let i = 0; i < 2; i++) { await page.keyboard.press('Escape'); await sleep(500); }
  await perf('banners', 'on');
  await settle(1500);

  // ------------------------------------------------------- 1. Headmates scroll
  await perf('go', '/members');
  await settle(3000);
  result.flows.membersScroll = await measure('Headmates scroll', async () => {
    for (let i = 0; i < 6; i++) { await touchDrag(206, 760, 260); await sleep(900); }
    for (let i = 0; i < 3; i++) { await touchDrag(206, 260, 760); await sleep(900); }
  });
  if (traceBuilds) result.builds.membersScrollOne = await builds(async () => { await touchDrag(206, 700, 400); await sleep(800); });

  // ---------------------------------------------------- 2. Open alter profile
  result.flows.openProfile = await measure('Open alter profile', async () => {
    await perf('push', '/members/stress-member-3');
    await sleep(1800);
  });
  result.flows.profileScroll = await measure('Profile scroll', async () => {
    for (let i = 0; i < 3; i++) { await touchDrag(206, 760, 300); await sleep(900); }
  });
  result.flows.backToList = await measure('Back to list', async () => {
    await page.evaluate(() => history.back());
    await sleep(1500);
  });

  // ----------------------------------------------------- 3. Type in busy chat
  await perf('go', '/chat/stress-conv-1');
  await settle(3500);
  const text = 'Hey everyone, checking in about tonight, are we still on?';
  // Focus the composer: bottom of the screen.
  await tap(230, H - 31);
  await settle(800);
  result.flows.chatTyping = await measure('Chat typing', async () => {
    await page.keyboard.type(text, { delay: 90 });
    await sleep(500);
  });
  if (traceBuilds) result.builds.chatOneChar = await builds(async () => { await page.keyboard.type('x'); await sleep(400); });
  result.flows.chatScrollHistory = await measure('Chat scroll history', async () => {
    for (let i = 0; i < 5; i++) { await touchDrag(206, 250, 750); await sleep(900); }
  });

  // ------------------------------------- 4. Page switching with music playing
  await perf('playMusic');
  await settle(2000);
  if (traceBuilds) result.builds.musicTickIdle = await builds(async () => { await sleep(1000); });
  result.flows.pageSwitchMusic = await measure('Page switch + music', async () => {
    for (const r of ['/', '/members', '/chat', '/habits', '/', '/members']) { await perf('go', r); await sleep(1100); }
  });
  await perf('go', '/');
  await settle(2000);
  if (traceBuilds) result.builds.homeIdle1s = await builds(async () => { await sleep(1000); });
  result.flows.idleHomeMusic = await measure('Idle home + music (3s)', async () => { await sleep(3000); });

  result.errors = errors.slice(0, 10);
  fs.writeFileSync(outFile, JSON.stringify(result, null, 1));
  console.log('errors', errors.length);
  await ctx.close();
})().catch((e) => { console.error('FAILED', e); process.exit(1); });
