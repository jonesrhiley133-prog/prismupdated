// CPU-profiles one flow and prints self time by function.
// usage: node cpuprof.js <base> <profileDir> <flow> [top]
const { chromium } = require('playwright');
const fs = require('fs');
const { SourceMapConsumer } = require('source-map');
const MAP = process.env.MAP;
const flow = process.argv[4], TOP = +(process.argv[5] || 45);
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
    profile: { setup: async () => { await perf('go', '/members'); await sleep(3000); }, run: async () => { await perf('push', '/members/stress-member-3'); await sleep(2000); } },
    back: { setup: async () => { await perf('go', '/members'); await sleep(2500); await perf('push', '/members/stress-member-3'); await sleep(2500); }, run: async () => { await page.evaluate(() => history.back()); await sleep(1800); } },
    scroll: { setup: async () => { await perf('go', '/members'); await sleep(3000); }, run: async () => { for (let i = 0; i < 4; i++) { await drag(760, 260); await sleep(800); } } },
    typing: { setup: async () => { await perf('go', '/chat/stress-conv-1'); await sleep(3500); await tap(230, 884); await sleep(800); }, run: async () => { await page.keyboard.type('checking in about tonight, are we on', { delay: 90 }); } },
    switch: { setup: async () => { await perf('playMusic'); await sleep(1500); }, run: async () => { for (const r of ['/', '/members', '/chat', '/habits', '/', '/members']) { await perf('go', r); await sleep(1100); } } },
  };
  const f = flows[flow];
  await f.setup();
  await cdp.send('Emulation.setCPUThrottlingRate', { rate: 4 });
  await cdp.send('Profiler.enable');
  await cdp.send('Profiler.setSamplingInterval', { interval: 200 });
  await cdp.send('Profiler.start');
  await f.run();
  const { profile } = await cdp.send('Profiler.stop');
  const consumer = MAP ? await new SourceMapConsumer(JSON.parse(fs.readFileSync(MAP, 'utf8'))) : null;
  const byId = new Map(profile.nodes.map(n => [n.id, n]));
  const parent = new Map(); for (const n of profile.nodes) for (const c of n.children || []) parent.set(c, n.id);
  const loc = new Map();
  const where = (n) => {
    if (loc.has(n.id)) return loc.get(n.id);
    const cf = n.callFrame; let r = { file: cf.url.split('/').pop() || '(native)', fn: cf.functionName || '(anon)' };
    if (consumer && /main\.dart\.js/.test(cf.url) && cf.lineNumber >= 0) {
      const o = consumer.originalPositionFor({ line: cf.lineNumber + 1, column: cf.columnNumber });
      if (o.source) r = { file: o.source.replace(/^.*?(lib\/|packages\/)/, '$1'), fn: o.name || cf.functionName || '?' , line: o.line };
    }
    loc.set(n.id, r); return r;
  };
  const dt = profile.timeDeltas; const selfFile = new Map(); const inclFile = new Map(); const selfFn = new Map();
  profile.samples.forEach((id, i) => {
    const d = (dt[i + 1] || 0) / 1000; const w = where(byId.get(id));
    selfFile.set(w.file, (selfFile.get(w.file) || 0) + d);
    const key = `${w.file}:${w.line || ''} ${w.fn}`; selfFn.set(key, (selfFn.get(key) || 0) + d);
    const seen = new Set(); let cur = id;
    while (cur != null) { const f = where(byId.get(cur)).file; if (f.startsWith('lib/') && !seen.has(f)) { inclFile.set(f, (inclFile.get(f) || 0) + d); seen.add(f); } cur = parent.get(cur); }
  });
  const total = [...selfFile.values()].reduce((a, b) => a + b, 0);
  console.log(`flow=${flow} sampled=${total.toFixed(0)}ms`);
  const show = (title, m, n) => { console.log('-- ' + title); for (const [k, v] of [...m].sort((a, b) => b[1] - a[1]).slice(0, n)) console.log(v.toFixed(1).padStart(8), k.slice(0, 120)); };
  show('self by file', selfFile, 25);
  show('self by function', selfFn, 30);
  show('inclusive by app file (lib/)', inclFile, TOP);
  await ctx.close();
})();
