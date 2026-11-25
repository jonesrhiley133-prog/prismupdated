import 'dart:math' as math;

import 'package:flutter/scheduler.dart' show Ticker;

import 'package:prism_plurality/features/companions/companion_data.dart';
import 'package:prism_plurality/features/companions/companion_widgets.dart';
import 'package:prism_plurality/features/companions/photo_mode.dart'
    show PhotoSceneView;
import 'package:prism_plurality/features/companions/companion_art.dart'
    show CompanionPose;
import 'package:prism_plurality/features/passport/passport_data.dart';
import 'package:prism_plurality/features/passport/passport_widgets.dart'
    show StampInstanceView;
import 'package:prism_plurality/features/wrapped/wrapped_data.dart';
import 'package:prism_plurality/features/wrapped/wrapped_engine.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Colours and type for a recap style. "prism" borrows the user's theme so
/// recaps never override their chosen look.
@immutable
class WrapTheme {
  const WrapTheme({
    required this.bg,
    required this.ink,
    required this.accent,
    required this.soft,
    this.font,
    this.paper = false,
  });
  final List<Color> bg;
  final Color ink, accent, soft;
  final String? font;
  final bool paper;

  static WrapTheme of(BuildContext context, WrapStyle s) {
    final cs = Theme.of(context).colorScheme;
    final custom = s.accent == null ? null : Color(s.accent!);
    final font = switch (s.font) {
      'serif' => 'serif',
      'mono' => 'monospace',
      _ => Theme.of(context).textTheme.bodyMedium?.fontFamily,
    };
    WrapTheme t(
      List<int> bg,
      int ink,
      int accent, {
      bool paper = false,
      String? f,
    }) => WrapTheme(
      bg: [for (final c in bg) Color(c)],
      ink: Color(ink),
      accent: custom ?? Color(accent),
      soft: Color(ink).withValues(alpha: 0.7),
      font: f ?? font,
      paper: paper,
    );
    return switch (s.style) {
      'minimal' => t([0xFFFAFAFA, 0xFFF1F1F1], 0xFF1C1C1E, 0xFF5B5BD6),
      'celestial' => t([0xFF141A3D, 0xFF3B2C6E], 0xFFF4F1FF, 0xFFFFD66B),
      'cozy' => t([0xFFF6E6D5, 0xFFE9CDB4], 0xFF4A2E22, 0xFFC2592E),
      'scrapbook' => t(
        [0xFFF4EBDD, 0xFFEADBC4],
        0xFF3E2C1C,
        0xFFE0607E,
        paper: true,
      ),
      'retro' => t(
        [0xFFFFE8B8, 0xFFFFB86B],
        0xFF3A1F5C,
        0xFFE8462F,
        f: 'monospace',
      ),
      'pastel' => t([0xFFFFE3F0, 0xFFDCEBFF], 0xFF3D3550, 0xFFB57EDC),
      'dark' => t([0xFF0E0E12, 0xFF1C1C24], 0xFFF2F2F7, 0xFF7DD3FC),
      'editorial' => t(
        [0xFFFFFFFF, 0xFFF5F2EC],
        0xFF111111,
        0xFFD72638,
        f: 'serif',
      ),
      'polaroid' => t(
        [0xFFECE8E1, 0xFFDAD4CA],
        0xFF262626,
        0xFF2F7DD1,
        paper: true,
      ),
      'magazine' => t(
        [0xFFFF5D8F, 0xFFFFB347],
        0xFFFFFFFF,
        0xFF1D1D1D,
        f: 'serif',
      ),
      _ => WrapTheme(
        bg: [cs.surface, cs.surfaceContainerHigh],
        ink: cs.onSurface,
        accent: custom ?? cs.primary,
        soft: cs.onSurfaceVariant,
        font: font,
      ),
    };
  }
}

/// Hides names and numbers for sharing.
class WrapMask {
  const WrapMask({
    this.names = const [],
    this.hideNames = false,
    this.hideNumbers = false,
  });
  final List<String> names;
  final bool hideNames, hideNumbers;
  String text(String s) {
    var out = s;
    if (hideNames) {
      for (final n in names.where((n) => n.trim().length > 1)) {
        out = out.replaceAll(
          RegExp(RegExp.escape(n), caseSensitive: false),
          '•••',
        );
      }
    }
    if (hideNumbers) out = out.replaceAll(RegExp(r'\d+'), '•');
    return out;
  }
}

/// One story card, drawn for its kind. [t] runs 0→1 as it enters (1 when
/// animations are off).
class WrapCardView extends ConsumerWidget {
  const WrapCardView({
    super.key,
    required this.card,
    required this.style,
    this.t = 1,
    this.mask = const WrapMask(),
    this.ratio,
    this.animateFigures = true,
  });
  final WrapCard card;
  final WrapStyle style;
  final double t;
  final WrapMask mask;
  final double? ratio;
  final bool animateFigures;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final th = WrapTheme.of(context, style);
    return AspectRatio(
      aspectRatio: ratio ?? style.ratio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: th.bg,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, box) {
              final u = box.maxWidth;
              final body = DefaultTextStyle(
                style: TextStyle(color: th.ink, fontFamily: th.font),
                child: _compose(context, ref, th, u),
              );
              return Stack(
                fit: StackFit.expand,
                children: [
                  if (style.effects)
                    IgnorePointer(
                      child: CustomPaint(
                        painter: _Confetti(card.kind, th.accent, t),
                      ),
                    ),
                  if (th.paper)
                    Positioned(
                      left: u * 0.06,
                      top: u * 0.05,
                      child: Transform.rotate(
                        angle: -0.06,
                        child: Container(
                          width: u * 0.22,
                          height: u * 0.06,
                          color: th.accent.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                  Padding(padding: EdgeInsets.all(u * 0.08), child: body),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _rise(double delay, Widget child) {
    final v = Curves.easeOutCubic.transform(
      ((t - delay) / (1 - delay)).clamp(0, 1),
    );
    if (style.animation == 'none') return child;
    return Opacity(
      opacity: v,
      child: switch (style.animation) {
        'zoom' => Transform.scale(scale: 0.85 + v * 0.15, child: child),
        'fade' => child,
        _ => Transform.translate(offset: Offset(0, (1 - v) * 24), child: child),
      },
    );
  }

  Widget _compose(BuildContext context, WidgetRef ref, WrapTheme th, double u) {
    final title = Text(
      mask.text(card.title),
      style: TextStyle(
        fontSize: u * 0.075,
        fontWeight: FontWeight.w800,
        height: 1.05,
      ),
    );
    TextStyle big(double f) => TextStyle(
      fontSize: u * f,
      fontWeight: FontWeight.w900,
      color: th.accent,
      height: 1,
    );
    switch (card.kind) {
      case 'intro':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _rise(
              0,
              Text(
                'PRISM WRAPPED',
                style: TextStyle(
                  letterSpacing: u * 0.012,
                  fontSize: u * 0.035,
                  color: th.soft,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Spacer(),
            _rise(
              0.1,
              Text(
                mask.text(card.title),
                style: TextStyle(
                  fontSize: u * 0.12,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
            SizedBox(height: u * 0.03),
            _rise(
              0.25,
              Text(
                mask.text(card.subtitle),
                style: TextStyle(fontSize: u * 0.05, color: th.soft),
              ),
            ),
            const Spacer(),
            _rise(0.4, Text(mask.text(card.headline), style: big(0.09))),
            SizedBox(height: u * 0.02),
            _rise(0.5, Text(card.note, style: TextStyle(fontSize: u * 0.042))),
          ],
        );
      case 'games' || 'musicNew' || 'highlights':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _rise(0, title),
            SizedBox(height: u * 0.02),
            if (card.headline.isNotEmpty)
              _rise(0.1, Text(mask.text(card.headline), style: big(0.1))),
            if (card.subtitle.isNotEmpty)
              _rise(
                0.15,
                Text(
                  mask.text(card.subtitle),
                  style: TextStyle(color: th.soft, fontSize: u * 0.04),
                ),
              ),
            const Spacer(),
            for (final (i, (label, value, emoji)) in card.items.indexed)
              _rise(
                0.25 + i * 0.1,
                Container(
                  margin: EdgeInsets.only(bottom: u * 0.025),
                  padding: EdgeInsets.all(u * 0.035),
                  decoration: BoxDecoration(
                    color: th.ink.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(u * 0.04),
                  ),
                  child: Row(
                    children: [
                      Text(emoji, style: TextStyle(fontSize: u * 0.07)),
                      SizedBox(width: u * 0.03),
                      Expanded(
                        child: Text(
                          mask.text(label),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: u * 0.045,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        mask.text(value),
                        style: TextStyle(fontSize: u * 0.038, color: th.soft),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      case 'gameCategories' || 'colors':
        final max = card.chart.fold<num>(1, (a, c) => math.max(a, c.$2));
        final colors = card.kind == 'colors';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _rise(0, title),
            const Spacer(),
            if (colors)
              Wrap(
                spacing: u * 0.03,
                runSpacing: u * 0.03,
                children: [
                  for (final (i, (c, n)) in card.chart.indexed)
                    _rise(
                      0.1 + i * 0.08,
                      Container(
                        width: u * (0.18 + 0.1 * n / max),
                        height: u * (0.18 + 0.1 * n / max),
                        decoration: BoxDecoration(
                          color: Color(int.tryParse(c) ?? 0xFF888888),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: th.ink.withValues(alpha: 0.2),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              )
            else
              for (final (i, (label, n)) in card.chart.indexed)
                Padding(
                  padding: EdgeInsets.only(bottom: u * 0.03),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mask.text(label),
                        style: TextStyle(
                          fontSize: u * 0.04,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: u * 0.01),
                      LayoutBuilder(
                        builder: (context, b) => Container(
                          height: u * 0.05,
                          width:
                              b.maxWidth *
                              (n / max) *
                              Curves.easeOutCubic.transform(
                                ((t - i * 0.08) / 0.7).clamp(0, 1),
                              ),
                          decoration: BoxDecoration(
                            color: th.accent,
                            borderRadius: BorderRadius.circular(u * 0.025),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            const Spacer(),
          ],
        );
      case 'gameMoments' || 'memories':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _rise(0, title),
            if (card.headline.isNotEmpty)
              _rise(0.1, Text(mask.text(card.headline), style: big(0.09))),
            const Spacer(),
            for (final (i, (label, value, emoji)) in card.items.indexed)
              _rise(
                0.2 + i * 0.12,
                Transform.rotate(
                  angle: (i.isEven ? -1 : 1) * 0.04,
                  child: Container(
                    margin: EdgeInsets.only(bottom: u * 0.03),
                    padding: EdgeInsets.fromLTRB(
                      u * 0.04,
                      u * 0.04,
                      u * 0.04,
                      u * 0.06,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x22000000),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Text(emoji, style: TextStyle(fontSize: u * 0.06)),
                        SizedBox(width: u * 0.03),
                        Expanded(
                          child: Text(
                            '“${mask.text(label)}”',
                            maxLines: 3,
                            style: TextStyle(
                              color: const Color(0xFF222222),
                              fontSize: u * 0.042,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        Text(
                          mask.text(value),
                          style: TextStyle(
                            color: const Color(0xFF666666),
                            fontSize: u * 0.034,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      case 'music':
        return Column(
          children: [
            _rise(0, title),
            SizedBox(height: u * 0.04),
            _Vinyl(size: u * 0.5, color: th.accent, spin: animateFigures),
            SizedBox(height: u * 0.04),
            _rise(0.2, Text(mask.text(card.headline), style: big(0.09))),
            if (card.subtitle.isNotEmpty)
              Text(
                mask.text(card.subtitle),
                textAlign: TextAlign.center,
                style: TextStyle(color: th.soft, fontSize: u * 0.038),
              ),
            const Spacer(),
            for (final (i, (label, value, _)) in card.items.indexed)
              _rise(
                0.3 + i * 0.1,
                Text(
                  '${i + 1}. ${mask.text(label)} · ${mask.text(value)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: u * 0.042,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        );
      case 'musicArtists':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _rise(0, title),
            const Spacer(),
            for (final (i, (label, _, emoji)) in card.items.indexed)
              _rise(
                0.1 + i * 0.08,
                Text(
                  '$emoji ${mask.text(label)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: u * (0.1 - i * 0.008).clamp(0.045, 0.1),
                    fontWeight: FontWeight.w900,
                    color: i == 0 ? th.accent : th.ink,
                  ),
                ),
              ),
            const Spacer(),
          ],
        );
      case 'creativity' || 'passport' || 'companions':
        final memories = ref.watch(companionMemoriesProvider);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _rise(0, title),
            _rise(0.1, Text(mask.text(card.headline), style: big(0.1))),
            SizedBox(height: u * 0.03),
            Expanded(
              child: Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: u * 0.02,
                  runSpacing: u * 0.02,
                  children: [
                    for (final (i, id) in card.refs.take(6).indexed)
                      _rise(0.2 + i * 0.07, switch (card.kind) {
                        'passport' => () {
                          final s = ref.watch(stampByIdProvider(id));
                          return s == null
                              ? const SizedBox.shrink()
                              : StampInstanceView(stamp: s, size: u * 0.24);
                        }(),
                        'companions' => () {
                          final c = ref.watch(companionByIdProvider(id));
                          return c == null
                              ? const SizedBox.shrink()
                              : CompanionFigure(
                                  companion: c,
                                  size: u * 0.3,
                                  animate: animateFigures,
                                  showParticles: false,
                                );
                        }(),
                        _ => () {
                          final m = memories
                              .where((m) => m.id == id)
                              .firstOrNull;
                          return m?.scene == null
                              ? const SizedBox.shrink()
                              : Transform.rotate(
                                  angle: (i.isEven ? -1 : 1) * 0.05,
                                  child: Container(
                                    color: Colors.white,
                                    padding: EdgeInsets.all(u * 0.012),
                                    width: u * 0.3,
                                    child: PhotoSceneView(
                                      scene: m!.scene!,
                                      animate: false,
                                    ),
                                  ),
                                );
                        }(),
                      }),
                  ],
                ),
              ),
            ),
            for (final (i, (label, value, emoji)) in card.items.indexed)
              _rise(
                0.4 + i * 0.06,
                Padding(
                  padding: EdgeInsets.only(bottom: u * 0.012),
                  child: Row(
                    children: [
                      Text(emoji, style: TextStyle(fontSize: u * 0.05)),
                      SizedBox(width: u * 0.02),
                      Expanded(
                        child: Text(
                          mask.text(label),
                          style: TextStyle(fontSize: u * 0.04),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          mask.text(value),
                          textAlign: TextAlign.end,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: u * 0.04,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      case 'companionStory':
        final c = card.refs.isEmpty
            ? null
            : ref.watch(companionByIdProvider(card.refs.first));
        return Column(
          children: [
            const Spacer(),
            if (c != null)
              _rise(
                0,
                CompanionFigure(
                  companion: c,
                  size: u * 0.62,
                  pose: CompanionPose.wave,
                  animate: animateFigures,
                ),
              ),
            SizedBox(height: u * 0.03),
            _rise(
              0.2,
              Text(
                mask.text(card.title),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: u * 0.1,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            _rise(0.3, Text(mask.text(card.headline), style: big(0.06))),
            if (card.subtitle.isNotEmpty)
              _rise(
                0.4,
                Padding(
                  padding: EdgeInsets.only(top: u * 0.02),
                  child: Text(
                    card.subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: th.soft, fontSize: u * 0.042),
                  ),
                ),
              ),
            const Spacer(),
          ],
        );
      case 'personalization':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _rise(0, title),
            const Spacer(),
            _rise(
              0.1,
              Center(
                child: Container(
                  width: u * 0.42,
                  height: u * 0.75,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(u * 0.06),
                    border: Border.all(
                      color: th.ink.withValues(alpha: 0.3),
                      width: 3,
                    ),
                  ),
                  padding: EdgeInsets.all(u * 0.03),
                  child: Column(
                    children: [
                      Container(
                        height: u * 0.08,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(u * 0.02),
                        ),
                      ),
                      SizedBox(height: u * 0.02),
                      for (var i = 0; i < 4; i++)
                        Container(
                          margin: EdgeInsets.only(bottom: u * 0.015),
                          height: u * 0.06,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(u * 0.02),
                          ),
                        ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final (c, _) in card.chart)
                            Container(
                              margin: EdgeInsets.all(u * 0.008),
                              width: u * 0.06,
                              height: u * 0.06,
                              decoration: BoxDecoration(
                                color: Color(int.tryParse(c) ?? 0),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: u * 0.04),
            _rise(0.3, Text(mask.text(card.headline), style: big(0.08))),
            if (card.subtitle.isNotEmpty)
              Text(
                mask.text(card.subtitle),
                style: TextStyle(color: th.soft, fontSize: u * 0.04),
              ),
            for (final (label, value, emoji) in card.items)
              Text(
                '$emoji $label · ${mask.text(value)}',
                style: TextStyle(fontSize: u * 0.04),
              ),
            const Spacer(),
          ],
        );
      case 'celebrations':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _rise(0, Text('🎉', style: TextStyle(fontSize: u * 0.16))),
            _rise(0.05, title),
            const Spacer(),
            for (final (i, (label, value, _)) in card.items.indexed)
              _rise(
                0.15 + i * 0.08,
                Padding(
                  padding: EdgeInsets.only(bottom: u * 0.02),
                  child: Row(
                    children: [
                      Container(
                        width: u * 0.14,
                        padding: EdgeInsets.symmetric(vertical: u * 0.015),
                        decoration: BoxDecoration(
                          color: th.accent,
                          borderRadius: BorderRadius.circular(u * 0.02),
                        ),
                        child: Text(
                          mask.text(value),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: u * 0.038,
                          ),
                        ),
                      ),
                      SizedBox(width: u * 0.03),
                      Expanded(
                        child: Text(
                          mask.text(label),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: u * 0.045,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      default: // closing
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _rise(0, Text('✨', style: TextStyle(fontSize: u * 0.18))),
            _rise(
              0.15,
              Text(
                card.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: u * 0.09,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            SizedBox(height: u * 0.03),
            _rise(
              0.3,
              Text(
                card.note,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: u * 0.045, color: th.soft),
              ),
            ),
          ],
        );
    }
  }
}

class _Vinyl extends StatefulWidget {
  const _Vinyl({required this.size, required this.color, this.spin = true});
  final double size;
  final Color color;
  final bool spin;
  @override
  State<_Vinyl> createState() => _VinylState();
}

class _VinylState extends State<_Vinyl> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(
    (e) => setState(() => _a = e.inMilliseconds / 3000 * math.pi * 2),
  );
  double _a = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final run =
        widget.spin && !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    if (run && !_ticker.isActive) _ticker.start();
    if (!run && _ticker.isActive) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: _a,
    child: Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [
            const Color(0xFF111111),
            const Color(0xFF333333),
            const Color(0xFF111111),
            const Color(0xFF2A2A2A),
            const Color(0xFF111111),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Container(
        width: widget.size * 0.34,
        height: widget.size * 0.34,
        decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
        alignment: Alignment.center,
        child: Container(
          width: widget.size * 0.05,
          height: widget.size * 0.05,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF111111),
          ),
        ),
      ),
    ),
  );
}

class _Confetti extends CustomPainter {
  _Confetti(this.kind, this.color, this.t);
  final String kind;
  final Color color;
  final double t;
  @override
  void paint(Canvas c, Size s) {
    final rnd = math.Random(kind.hashCode);
    final n = kind == 'celebrations' || kind == 'intro' || kind == 'closing'
        ? 26
        : 10;
    for (var i = 0; i < n; i++) {
      final x = rnd.nextDouble() * s.width,
          y = rnd.nextDouble() * s.height,
          r = 2 + rnd.nextDouble() * 4;
      final hue = HSVColor.fromColor(color);
      final col = hue
          .withHue((hue.hue + rnd.nextDouble() * 80 - 40) % 360)
          .toColor()
          .withValues(alpha: 0.18 + 0.25 * t);
      final dy = (1 - t) * 30;
      if (i.isEven) {
        c.drawCircle(Offset(x, y - dy), r, Paint()..color = col);
      } else {
        c.save();
        c.translate(x, y - dy);
        c.rotate(rnd.nextDouble() * math.pi);
        c.drawRect(
          Rect.fromCenter(center: Offset.zero, width: r * 2.4, height: r),
          Paint()..color = col,
        );
        c.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_Confetti old) => old.t != t || old.color != color;
}
