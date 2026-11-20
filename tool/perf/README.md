# Prism performance harness (web build)

Repeatable measurements of the flows that matter for smoothness: scrolling a
long Headmates list with banners, opening an alter profile, typing in a busy
chat, and switching pages while music plays.

The harness drives a **web build** of Prism in headless Chromium. It is not a
substitute for profiling on a real Android phone (see the bottom of this
file), but it runs the same Flutter framework code, so build/layout costs and
"what rebuilds when" carry over.

## What `PRISM_PERF` adds

Builds made with `--dart-define=PRISM_PERF=true` (and only those):

- seed a fixed data set once (`StressPreset.perf`: 300 headmates, each with
  an avatar and a banner, 3 chats / 3000 messages, two people fronting);
- record Flutter frame timings (`FrameTiming`: build, raster, total);
- play a stand-in music track whose position ticks every 200 ms like
  just_audio, so the music UI works on web;
- expose `window.prismPerf(action, arg)` for the harness: `start`, `stop`,
  `go <path>`, `push <path>`, `playMusic`, `banners on|off`, `route`,
  `traceBuilds on|off` (profile builds: one browser performance measure per
  widget build).

Normal builds compile all of this out.

## Running

```bash
flutter build web --release --no-tree-shake-icons --dart-define=PRISM_PERF=true
```

Serve `build/web` (any static server with an SPA fallback), then:

```bash
cd tool/perf && npm install playwright source-map
node perf.js http://localhost:8100 result.json --profile-dir /tmp/prism-perf
```

The first run seeds the fixture into the browser profile (a minute or two);
reuse the same `--profile-dir` so later runs see identical data. Conditions:
412x915 viewport at 2x, touch input, CPU throttled 4x (`THROTTLE=n` to
change). Each flow prints frames, frames over 16.7 ms, average build and
raster time, p50/p90/p99/worst frame, and dropped vsyncs from the browser's
own presentation timing.

Attribution:

- `node widgetself.js <url> <profile-dir> <flow>` (profile build) counts
  widget builds per type during one flow — e.g. `typing` shows what one
  keystroke rebuilds, `music` what a playback tick rebuilds.
- `MAP=build/web/main.dart.js.map node cpuprof.js <url> <profile-dir> <flow>`
  (profile build with `--source-maps`) CPU-profiles a flow and maps samples
  back to Dart files and functions.

## Reading the numbers

The container this was built in has no GPU, so Chromium rasterizes in
software and `raster` (and `createImageBitmap` in CPU profiles) mostly
measures that, not Prism. Compare `avgBuild`, rebuild counts and app code in
CPU profiles between builds; treat raster as environment noise.

## On a phone

For Android numbers, run a profile build on a device and use DevTools'
performance view, or `tool/run_android_anr_harness.sh` for jank/ANR capture.
