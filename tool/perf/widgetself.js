// Widget-level self time for one flow (profile build). usage: node widgetself.js <base> <dir> <flow>
const { chromium } = require('playwright');
const flow = process.argv[4];
const sleep = (ms) => new Promise(r => setTimeout(r, ms));
(async () => {
  const ctx = await chromium.launchPersistentContext(process.argv[3], { viewport: { width: 412, height: 915 }, deviceScaleFactor: 2, hasTouch: true, isMobile: true, colorScheme: 'dark' });
  const page = ctx.pages()[0] || await ctx.newPage();
  const cdp = await ctx.newCDPSession(page);
  const perf = (n, a = '') => page.evaluate(([n, a]) => window.prismPerf(n, a), [n, a]);
  const drag = async (y0, y1) => { await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: 206, y: y0 }] }); for (let i = 1; i <= 12; i++) { await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: 206, y: y0 + (y1 - y0) * i / 12 }] }); await sleep(16); } await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] }); };
  const tap = async (x, y) => { await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x, y }] }); await sleep(60); await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] }); };
  await page.goto(process.argv[2]);
  while (!(await page.evaluate(() => typeof window.prismPerf === 'function'))) await sleep(300);
  await sleep(3000); await page.keyboard.press('Escape'); await sleep(500);
  await perf('banners', 'on'); await sleep(800);
  const flows = {
    profile: [async () => { await perf('go', '/members'); await sleep(3000); }, async () => { await perf('push', '/members/stress-member-3'); await sleep(2000); }],
    back: [async () => { await perf('go', '/members'); await sleep(2500); await perf('push', '/members/stress-member-3'); await sleep(2500); }, async () => { await page.evaluate(() => history.back()); await sleep(1800); }],
    scroll: [async () => { await perf('go', '/members'); await sleep(3000); }, async () => { for (let i = 0; i < 3; i++) { await drag(760, 260); await sleep(800); } }],
    typing: [async () => { await perf('go', '/chat/stress-conv-1'); await sleep(3500); await tap(230, 884); await sleep(800); }, async () => { await page.keyboard.type('checking in', { delay: 120 }); await sleep(300); }],
    switch: [async () => { await perf('playMusic'); await sleep(1500); }, async () => { for (const r of ['/', '/members', '/chat', '/habits', '/', '/members']) { await perf('go', r); await sleep(1100); } }],
    music: [async () => { await perf('playMusic'); await sleep(1500); await perf('go', '/'); await sleep(2000); }, async () => { await sleep(2000); }],
    home: [async () => { await perf('go', '/'); await sleep(3000); }, async () => { await sleep(2000); }],
  };
  const [setup, run] = flows[flow];
  await setup();
  await cdp.send('Emulation.setCPUThrottlingRate', { rate: 4 });
  await page.evaluate(() => performance.clearMeasures());
  await perf('traceBuilds', 'on');
  await run();
  await perf('traceBuilds', 'off');
  const res = await page.evaluate(() => {
    const es = performance.getEntriesByType('measure').map(e => ({ n: e.name, s: e.startTime, e: e.startTime + e.duration, d: e.duration }));
    es.sort((a, b) => a.s - b.s || b.d - a.d);
    // exclusive time: subtract direct children (stack-based nesting).
    const stack = []; const self = new Map(); const cnt = new Map();
    for (const x of es) { x.c = 0; while (stack.length && stack[stack.length - 1].e <= x.s) stack.pop(); if (stack.length) stack[stack.length - 1].c += x.d; stack.push(x); }
    for (const x of es) { self.set(x.n, (self.get(x.n) || 0) + Math.max(0, x.d - x.c)); cnt.set(x.n, (cnt.get(x.n) || 0) + 1); }
    const frames = es.filter(x => x.n === 'Frame'); const ft = frames.reduce((a, b) => a + b.d, 0);
    return { frames: frames.length, frameMs: ft, top: [...self].sort((a, b) => b[1] - a[1]).slice(0, 45).map(([k, v]) => [k, cnt.get(k), +v.toFixed(1)]) };
  });
  console.log(`flow=${flow} frames=${res.frames} frameMs=${res.frameMs.toFixed(0)}`);
  for (const [k, n, v] of res.top) console.log(String(v).padStart(8), String(n).padStart(5), k.slice(0, 90));
  await ctx.close();
})();
