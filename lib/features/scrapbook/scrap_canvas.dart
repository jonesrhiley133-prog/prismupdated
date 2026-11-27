import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:prism_plurality/features/scrapbook/scrap_sticker_picker.dart';
import 'package:prism_plurality/features/scrapbook/scrap_video.dart';
import 'package:prism_plurality/features/scrapbook/scrap_washi.dart';
import 'package:prism_plurality/features/scrapbook/scrap_frames.dart';
import 'package:prism_plurality/features/scrapbook/scrap_rentry.dart';
import 'package:prism_plurality/features/scrapbook/scrap_shapes.dart';
import 'package:prism_plurality/features/scrapbook/scrap_models.dart';
import 'package:prism_plurality/shared/media/prism_media.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Paints a page background.
class ScrapBackground extends CustomPainter {
  ScrapBackground(this.color, this.pattern, this.ink);
  final Color color;
  final String pattern;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = color);
    final p = Paint()
      ..color = ink.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    final step = size.width / 20;
    switch (pattern) {
      case 'dots':
        for (double x = step; x < size.width; x += step) {
          for (double y = step; y < size.height; y += step) {
            canvas.drawCircle(Offset(x, y), 1.2, p);
          }
        }
      case 'grid':
        for (double x = step; x < size.width; x += step) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
        }
        for (double y = step; y < size.height; y += step) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
        }
      case 'lines':
        for (double y = step * 2; y < size.height; y += step) {
          canvas.drawLine(Offset(step, y), Offset(size.width - step, y), p);
        }
        canvas.drawLine(
          Offset(step * 2.4, 0),
          Offset(step * 2.4, size.height),
          Paint()..color = const Color(0x55E74C3C),
        );
      case 'paper':
        final rnd = math.Random(3);
        for (var i = 0; i < 300; i++) {
          canvas.drawCircle(
            Offset(
              rnd.nextDouble() * size.width,
              rnd.nextDouble() * size.height,
            ),
            0.6,
            p,
          );
        }
      case 'kraft':
        final rnd = math.Random(9);
        final k = Paint()..color = const Color(0x22000000);
        for (var i = 0; i < 500; i++) {
          canvas.drawRect(
            Rect.fromLTWH(
              rnd.nextDouble() * size.width,
              rnd.nextDouble() * size.height,
              1.5,
              0.6,
            ),
            k,
          );
        }
      case 'stars':
        final rnd = math.Random(5);
        for (var i = 0; i < 40; i++) {
          canvas.drawCircle(
            Offset(
              rnd.nextDouble() * size.width,
              rnd.nextDouble() * size.height,
            ),
            rnd.nextDouble() * 1.8 + 0.4,
            Paint()..color = ink.withValues(alpha: 0.3),
          );
        }
    }
  }

  @override
  bool shouldRepaint(ScrapBackground old) =>
      old.color != color || old.pattern != pattern || old.ink != ink;
}

/// Draws a single element.
class ScrapElementView extends StatelessWidget {
  const ScrapElementView({
    super.key,
    required this.element,
    required this.pageWidth,
  });
  final ScrapElement element;
  final double pageWidth;

  @override
  Widget build(BuildContext context) {
    final e = element;
    final scale = pageWidth / 360;
    final base = Theme.of(context).textTheme.bodyMedium!.copyWith(
      fontSize: 14 * scale * e.size,
      color: e.color == null ? Colors.black87 : Color(e.color!),
    );
    Widget mediaOrPlaceholder() => e.media == null
        ? ColoredBox(
            color: Colors.black.withValues(alpha: 0.06),
            child: Center(
              child: Icon(
                PhosphorIcons.imageSquare(),
                color: Colors.black26,
                size: 28 * scale,
              ),
            ),
          )
        : (e.media!.startsWith('audio:')
              ? Center(child: AudioClip(id: e.media!))
              : PrismMediaView(id: e.media!));
    final content = switch (e.type) {
      ScrapType.video =>
        e.media == null
            ? mediaOrPlaceholder()
            : ScrapVideoView(key: ValueKey('vid-${e.id}'), element: e),
      ScrapType.photo ||
      ScrapType.drawing => _framedMedia(mediaOrPlaceholder(), e),
      ScrapType.audio => Center(
        child: e.media == null
            ? Icon(PhosphorIcons.microphone())
            : AudioClip(id: e.media!, label: e.text),
      ),
      ScrapType.text => _text(context, e, base, scale),
      ScrapType.markdown => ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          maxHeight: double.infinity,
          child: Padding(
            padding: EdgeInsets.all(6 * scale),
            child: RentryMarkdownView(
              e.text ?? '',
              scale: scale * e.size,
              color: e.color == null ? null : Color(e.color!),
            ),
          ),
        ),
      ),
      ScrapType.note => Container(
        padding: EdgeInsets.all(8 * scale),
        decoration: BoxDecoration(
          color: Color(e.color ?? 0xFFFFF3A3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 6 * scale,
              offset: Offset(2 * scale, 3 * scale),
            ),
          ],
        ),
        child: Text(
          (e.text?.isEmpty ?? true) ? tr(context, 'Note…', 'Nota…') : e.text!,
          style: scrapFont(
            e.font ?? 'hand',
            base.copyWith(color: Colors.black87),
          ),
          overflow: TextOverflow.fade,
        ),
      ),
      ScrapType.sticker => ScrapStickerContent(
        id: e.text ?? '⭐',
        media: e.media,
        tint: e.color == null ? null : Color(e.color!),
      ),
      ScrapType.tape => Opacity(
        opacity: 0.85,
        child: CustomPaint(
          size: Size.infinite,
          painter: washiById(e.opt<String>('wp', '')) != null
              ? WashiPainter(
                  washiById(e.opt<String>('wp', ''))!,
                  tint: e.opt<int>('wt', 0) == 0
                      ? null
                      : Color(e.opt<int>('wt', 0)),
                )
              : _TapePainter(Color(e.color ?? 0xFFF8B6C9)),
        ),
      ),
      ScrapType.shape => CustomPaint(
        painter: ScrapShapePainter(
          shape: switch (e.text) {
            null => 'heart',
            'circle' => 'ellipse',
            'banner' => 'ribbon',
            final id => id,
          },
          fill: Color(e.color ?? 0xFFE74C3C),
          fill2: e.opt<int>('c2', 0) == 0 ? null : Color(e.opt<int>('c2', 0)),
          border: e.opt<int>('bc', 0) == 0 ? null : Color(e.opt<int>('bc', 0)),
          borderWidth: e.opt<double>('bw', 0) * scale,
          shadow: e.opt<double>('sh', 0) * scale,
          filled: !e.opt<bool>('nf', false),
        ),
        size: Size.infinite,
      ),
    };
    final framed = switch (e.frame) {
      ScrapFrame.none => content,
      ScrapFrame.polaroid => Container(
        padding: EdgeInsets.fromLTRB(
          6 * scale,
          6 * scale,
          6 * scale,
          22 * scale,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 6 * scale,
              offset: Offset(0, 3 * scale),
            ),
          ],
        ),
        child: content,
      ),
      ScrapFrame.round => PrismClipRound(child: content),
      ScrapFrame.shadow => DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10 * scale,
              offset: Offset(0, 4 * scale),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: prismCorners(context, 6 * scale),
          child: content,
        ),
      ),
      ScrapFrame.border => Container(
        padding: EdgeInsets.all(3 * scale),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black26),
        ),
        child: content,
      ),
      ScrapFrame.tape => Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: content),
          Positioned(
            top: -8 * scale,
            left: 0,
            right: 0,
            child: Center(
              child: Transform.rotate(
                angle: -0.08,
                child: SizedBox(
                  width: 60 * scale,
                  height: 18 * scale,
                  child: Opacity(
                    opacity: 0.8,
                    child: CustomPaint(
                      painter: _TapePainter(const Color(0xFFF7E3A1)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    };
    final decorated = _decorate(framed, e, scale);
    return e.opacity < 1
        ? Opacity(opacity: e.opacity.clamp(0.0, 1.0), child: decorated)
        : decorated;
  }

  static Widget _framedMedia(Widget media, ScrapElement e) {
    final f = scrapFrameById(e.opt<String>('fr2', ''));
    if (f == null) return media;
    return ScrapFramedImage(
      frame: f,
      fit: ScrapImageFit.fromJson(e.opts['fit']),
      child: media,
    );
  }

  /// Drop shadow and outline for stickers, pictures and the like.
  static Widget _decorate(Widget child, ScrapElement e, double scale) {
    final shd = e.opt<double>('shd', 0);
    final ow = e.opt<double>('ow', 0);
    if ((shd <= 0 && ow <= 0) ||
        e.type == ScrapType.text ||
        e.type == ScrapType.shape) {
      return child;
    }
    Widget tint(Color c) => ColorFiltered(
      colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
      child: child,
    );
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.passthrough,
      children: [
        if (shd > 0)
          Transform.translate(
            offset: Offset(shd * 3 * scale, shd * 5 * scale),
            child: Opacity(
              opacity: 0.4,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(
                  sigmaX: math.max(0.1, shd * 4 * scale),
                  sigmaY: math.max(0.1, shd * 4 * scale),
                ),
                child: tint(Colors.black),
              ),
            ),
          ),
        if (ow > 0)
          for (var i = 0; i < 8; i++)
            Transform.translate(
              offset: Offset.fromDirection(i * math.pi / 4, ow * scale),
              child: tint(Color(e.opt<int>('oc', 0xFFFFFFFF))),
            ),
        child,
      ],
    );
  }

  static Widget _text(
    BuildContext context,
    ScrapElement e,
    TextStyle base,
    double scale,
  ) {
    final empty = e.text?.isEmpty ?? true;
    final ow = e.opt<double>('ow', 0);
    final shd = e.opt<double>('shd', 0);
    var style = scrapFont(e.font, base).copyWith(
      color: empty ? base.color!.withValues(alpha: 0.4) : null,
      fontWeight: e.opt<bool>('bd', false) ? FontWeight.w800 : null,
      fontStyle: e.opt<bool>('it', false) ? FontStyle.italic : null,
      letterSpacing: e.opt<double>('ls', 0) * scale,
      height: e.opt<double>('lh', 0) == 0 ? null : e.opt<double>('lh', 0),
      shadows: shd > 0
          ? [
              Shadow(
                color: Colors.black45,
                blurRadius: shd * 5 * scale,
                offset: Offset(shd * 1.5 * scale, shd * 2.5 * scale),
              ),
            ]
          : null,
    );
    final txt = empty
        ? tr(context, 'Double-tap to write…', 'Doble toque para escribir…')
        : e.text!;
    final align = switch (e.opt<String>('ta', 'left')) {
      'center' => TextAlign.center,
      'right' => TextAlign.right,
      _ => TextAlign.left,
    };
    final fill = Text(
      txt,
      style: style,
      textAlign: align,
      overflow: TextOverflow.fade,
    );
    final box = Align(
      alignment: switch (e.opt<String>('ta', 'left')) {
        'center' => Alignment.topCenter,
        'right' => Alignment.topRight,
        _ => Alignment.topLeft,
      },
      child: ow > 0
          ? Stack(
              children: [
                Text(
                  txt,
                  textAlign: align,
                  overflow: TextOverflow.fade,
                  style: style.copyWith(
                    shadows: null,
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = ow * 2 * scale
                      ..strokeJoin = StrokeJoin.round
                      ..color = Color(e.opt<int>('oc', 0xFFFFFFFF)),
                  ),
                ),
                fill,
              ],
            )
          : fill,
    );
    return e.opt<bool>('fit', false)
        ? FittedBox(fit: BoxFit.scaleDown, child: box)
        : box;
  }
}

class _TapePainter extends CustomPainter {
  _TapePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    const teeth = 6;
    path.moveTo(0, 0);
    for (var i = 0; i <= teeth; i++) {
      path.lineTo(0 + (i.isEven ? 0 : 3), size.height * i / teeth);
    }
    path.lineTo(size.width, size.height);
    for (var i = teeth; i >= 0; i--) {
      path.lineTo(size.width - (i.isEven ? 0 : 3), size.height * i / teeth);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
    final stripe = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 3;
    for (double x = -size.height; x < size.width; x += 10) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        stripe,
      );
    }
  }

  @override
  bool shouldRepaint(_TapePainter old) => old.color != color;
}
