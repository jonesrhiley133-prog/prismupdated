import 'dart:math' as math;

import 'package:intl/intl.dart' show DateFormat;

import 'package:prism_plurality/features/wallets/id_shapes.dart';
import 'package:prism_plurality/shared/fonts/prism_fonts.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/wallets/wallet_data.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import 'package:prism_plurality/core/graphics/decor_clock.dart';

/// ID-1 card proportions (85.6 × 54 mm).
const idCardRatio = 85.6 / 54;

/// Field values for a card: the card's own overrides first, then the
/// headmate's profile and the system identity.
Map<String, String> resolveCardValues(IdCard c, Member? m, SystemIdentity id) {
  final v = c.values;
  String pick(String k, String fallback) =>
      (v[k] ?? '').isNotEmpty ? v[k]! : fallback;
  return {
    'name': pick(
      'name',
      m == null
          ? 'Name'
          : (m.displayName?.isNotEmpty == true ? m.displayName! : m.name),
    ),
    'pronouns': pick('pronouns', m?.pronouns ?? ''),
    'role': pick('role', ''),
    'age': pick('age', m?.age ?? ''),
    'birthday': pick('birthday', m?.birthday ?? ''),
    'number': pick('number', c.number),
    'signature': pick('signature', m?.name ?? ''),
    'issued': pick('issued', DateFormat.yMMMd().format(c.issued)),
    'expires': pick('expires', 'Forever'),
    'system': pick('system', id.systemName),
    'issuer': pick('issuer', id.issuer),
    'notes': pick('notes', ''),
    'emoji': pick('emoji', m?.emoji ?? id.emblem),
    'status': pick('status', ''),
    'flags': pick('flags', ''),
    'boundaries': pick('boundaries', ''),
    'interests': pick('interests', ''),
    'custom1': pick('custom1', ''),
    'custom2': pick('custom2', ''),
    'custom3': pick('custom3', ''),
  };
}

String fieldLabel(String k) => switch (k) {
  'number' => 'No.',
  'issued' => 'Issued',
  'expires' => 'Valid until',
  'birthday' => 'Born',
  'issuer' => 'Issued by',
  'age' => 'Age',
  'role' => 'Role',
  'status' => 'Status',
  'boundaries' => 'Boundaries',
  'interests' => 'Into',
  _ => '',
};

TextStyle _font(String f, TextStyle base) => switch (f) {
  'serif' => base.copyWith(
    fontFamily: 'Georgia',
    fontFamilyFallback: const ['Cambria', 'Times New Roman', 'serif'],
  ),
  'mono' => base.copyWith(
    fontFamily: 'ui-monospace',
    fontFamilyFallback: const ['Menlo', 'Consolas', 'monospace'],
  ),
  'rounded' => base.copyWith(
    fontFamily: 'ui-rounded',
    fontFamilyFallback: const ['SF Pro Rounded'],
  ),
  'script' => base.copyWith(
    fontFamily: 'Snell Roundhand',
    fontFamilyFallback: const ['Brush Script MT', 'cursive'],
    fontStyle: FontStyle.italic,
  ),
  _ => PrismFonts.style(f, base),
};

/// Draws one face of a card at [width].
class CardFaceView extends StatelessWidget {
  const CardFaceView({
    super.key,
    required this.face,
    required this.values,
    this.photo,
    this.width = 320,
    this.selected,
    this.onLayerTap,
    this.onLayerDrag,
    this.showGrid = false,
    this.ratio = idCardRatio,
  });

  /// Width ÷ height of the card (landscape, portrait, square or custom).
  final double ratio;
  final CardFace face;
  final Map<String, String> values;
  final Widget? photo;
  final double width;
  final String? selected;
  final ValueChanged<String>? onLayerTap;
  final void Function(String id, Offset deltaFraction)? onLayerDrag;
  final bool showGrid;

  @override
  Widget build(BuildContext context) {
    final h = width / ratio;
    return SizedBox(
      width: width,
      height: h,
      child: ClipRRect(
        borderRadius: prismCorners(context, width * 0.045),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(face.bg1), Color(face.bg2)],
                  ),
                ),
                child: CustomPaint(
                  painter: _PatternPainter(
                    face.pattern,
                    Color(face.bg2),
                    Color(face.bg1),
                  ),
                ),
              ),
            ),
            if (showGrid)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _GridPainter()),
                ),
              ),
            for (final l in face.layers) _layer(context, l, width, h),
          ],
        ),
      ),
    );
  }

  Widget _layer(BuildContext context, CardLayer l, double w, double h) {
    final lw = l.w * w;
    final lh = l.kind == 'text' || l.kind == 'field'
        ? l.size * w * 1.6
        : l.h * h;
    final left = switch (l.align) {
      'center' => l.x * w - lw / 2,
      'right' => l.x * w - lw,
      _ => l.kind == 'text' || l.kind == 'field' ? l.x * w : l.x * w - lw / 2,
    };
    final top = l.y * h - lh / 2;
    Widget child;
    final color = Color(l.color);
    switch (l.kind) {
      case 'text' || 'field':
        var text = l.kind == 'text' ? l.text : (values[l.field] ?? '');
        final label = l.kind == 'field' ? fieldLabel(l.field ?? '') : '';
        if (label.isNotEmpty && text.isNotEmpty) text = '$label  $text';
        child = Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: switch (l.align) {
            'center' => TextAlign.center,
            'right' => TextAlign.right,
            _ => TextAlign.left,
          },
          style: _font(
            l.font,
            TextStyle(
              color: color,
              fontSize: l.size * w,
              fontWeight: l.bold ? FontWeight.w800 : FontWeight.w500,
              height: 1.2,
            ),
          ),
        );
      case 'emoji':
        child = FittedBox(child: Text(l.text.isEmpty ? '⭐' : l.text));
      case 'shape':
        child = CustomPaint(
          painter: IdShapePainter(
            kind: l.text,
            color: color,
            color2: l.color2 == null ? null : Color(l.color2!),
            stroke: l.stroke,
          ),
        );
      case 'circle':
        child = DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: prismRound(context),
          ),
        );
      case 'line':
        child = Center(
          child: Container(height: math.max(1, lh * 0.08), color: color),
        );
      case 'photo':
        child = Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: prismCorners(context, lw * 0.08),
            border: Border.all(color: color, width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child:
              photo ??
              Center(
                child: Text(
                  values['emoji'] ?? '🙂',
                  style: TextStyle(fontSize: lw * 0.5),
                ),
              ),
        );
      case 'barcode':
        child = CustomPaint(
          painter: _BarcodePainter(values['number'] ?? 'prism', color),
        );
      default:
        child = const SizedBox.shrink();
    }
    child = Opacity(
      opacity: l.opacity.clamp(0, 1),
      child: Transform.rotate(
        angle: l.rotation * math.pi / 180,
        child: SizedBox(width: lw, height: lh, child: child),
      ),
    );
    if (selected == l.id) {
      child = DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.primary,
            width: 1.5,
          ),
        ),
        position: DecorationPosition.foreground,
        child: child,
      );
    }
    if (onLayerTap != null || onLayerDrag != null) {
      child = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onLayerTap?.call(l.id),
        onPanStart: (_) => onLayerTap?.call(l.id),
        onPanUpdate: l.locked
            ? null
            : (d) => onLayerDrag?.call(
                l.id,
                Offset(d.delta.dx / w, d.delta.dy / h),
              ),
        child: child,
      );
    }
    return Positioned(left: left, top: top, child: child);
  }
}

/// A full card that flips between front and back on tap.
class IdCardView extends ConsumerStatefulWidget {
  const IdCardView({
    super.key,
    required this.card,
    this.width = 320,
    this.flippable = true,
    this.showBack = false,
  });
  final IdCard card;
  final double width;
  final bool flippable;
  final bool showBack;
  @override
  ConsumerState<IdCardView> createState() => _IdCardViewState();
}

class _IdCardViewState extends ConsumerState<IdCardView>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
    value: widget.showBack ? 1 : 0,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final members =
        ref.watch(userVisibleMembersProvider).value ?? const <Member>[];
    final m = members.where((x) => x.id == widget.card.memberId).firstOrNull;
    final values = resolveCardValues(
      widget.card,
      m,
      ref.watch(systemIdentityProvider),
    );
    final photo = m?.avatarImageData == null
        ? null
        : Image.memory(
            m!.avatarImageData!,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          );
    final shine =
        widget.card.shine && !MediaQuery.of(context).disableAnimations;
    return Semantics(
      button: widget.flippable,
      label:
          '${widget.card.title} for ${values['name']}. ${widget.flippable ? 'Tap to flip.' : ''}',
      child: GestureDetector(
        onTap: !widget.flippable
            ? null
            : () {
                if (MediaQuery.of(context).disableAnimations) {
                  _c.value = _c.value < 0.5 ? 1 : 0;
                } else {
                  _c.value < 0.5 ? _c.forward() : _c.reverse();
                }
              },
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final a = _c.value * math.pi;
                final back = _c.value >= 0.5;
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0012)
                    ..rotateY(a),
                  child: back
                      ? Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.rotationY(math.pi),
                          child: CardFaceView(
                            face: widget.card.back,
                            values: values,
                            photo: photo,
                            width: widget.width,
                            ratio: widget.card.aspect,
                          ),
                        )
                      : CardFaceView(
                          face: widget.card.front,
                          values: values,
                          photo: photo,
                          width: widget.width,
                          ratio: widget.card.aspect,
                        ),
                );
              },
            ),
            if (shine)
              Positioned.fill(
                child: IgnorePointer(
                  child: _Shine(radius: widget.width * 0.045),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A slow highlight that sweeps across a card.
class _Shine extends StatefulWidget {
  const _Shine({required this.radius});
  final double radius;
  @override
  State<_Shine> createState() => _ShineState();
}

class _ShineState extends State<_Shine> with DecorClockListener {
  // A decorative sheen on the shared decor clock.
  late final _c = DecorLoop(const Duration(seconds: 5));

  @override
  void onDecorTick(double seconds) => _c.tick(seconds);

  @override
  void initState() {
    super.initState();
    setDecorRunning(true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: prismCorners(context, widget.radius),
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        // Sweep for the first 40% of the loop, then rest.
        final t = (_c.value / 0.4).clamp(0.0, 1.0);
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-2 + t * 4, -1),
              end: Alignment(-1 + t * 4, 1),
              colors: const [
                Color(0x00FFFFFF),
                Color(0x40FFFFFF),
                Color(0x00FFFFFF),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _PatternPainter extends CustomPainter {
  _PatternPainter(this.kind, this.a, this.b);
  final String kind;
  final Color a, b;

  @override
  void paint(Canvas canvas, Size s) {
    if (paintIdExtraPattern(canvas, s, kind, a, b)) return;
    final p = Paint()
      ..color = Color.lerp(a, Colors.black, 0.08)!.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    switch (kind) {
      case 'dots':
        for (var x = 8.0; x < s.width; x += 16) {
          for (var y = 8.0; y < s.height; y += 16) {
            canvas.drawCircle(Offset(x, y), 1.6, p..style = PaintingStyle.fill);
          }
        }
      case 'stripes':
        for (var x = -s.height; x < s.width; x += 14) {
          canvas.drawLine(
            Offset(x, s.height),
            Offset(x + s.height, 0),
            p..strokeWidth = 4,
          );
        }
      case 'waves':
        for (var y = 10.0; y < s.height; y += 14) {
          final path = Path()..moveTo(0, y);
          for (var x = 0.0; x < s.width; x += 20) {
            path.quadraticBezierTo(x + 5, y - 4, x + 10, y);
            path.quadraticBezierTo(x + 15, y + 4, x + 20, y);
          }
          canvas.drawPath(path, p);
        }
      case 'stars':
        final r = math.Random(7);
        final star = Paint()..color = Colors.white.withValues(alpha: 0.7);
        for (var i = 0; i < 40; i++) {
          canvas.drawCircle(
            Offset(r.nextDouble() * s.width, r.nextDouble() * s.height),
            r.nextDouble() * 1.4 + 0.3,
            star,
          );
        }
      case 'grid':
        final g = Paint()
          ..color = b.withValues(alpha: 0.18)
          ..strokeWidth = 0.6;
        for (var x = 0.0; x < s.width; x += 14) {
          canvas.drawLine(Offset(x, 0), Offset(x, s.height), g);
        }
        for (var y = 0.0; y < s.height; y += 14) {
          canvas.drawLine(Offset(0, y), Offset(s.width, y), g);
        }
      case 'holo':
        canvas.drawRect(
          Offset.zero & s,
          Paint()
            ..shader = const LinearGradient(
              colors: [
                Color(0x33FF9AE6),
                Color(0x339AE6FF),
                Color(0x33FFF59A),
                Color(0x33B39AFF),
              ],
            ).createShader(Offset.zero & s),
        );
      case 'guilloche':
        for (var i = 0; i < 18; i++) {
          final path = Path();
          for (var x = 0.0; x <= s.width; x += 4) {
            final y =
                s.height / 2 +
                math.sin(x / s.width * math.pi * 4 + i * 0.35) *
                    s.height *
                    0.35;
            x == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
          }
          canvas.drawPath(path, p..strokeWidth = 0.5);
        }
    }
  }

  @override
  bool shouldRepaint(_PatternPainter o) =>
      o.kind != kind || o.a != a || o.b != b;
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = const Color(0x332196F3)
      ..strokeWidth = 0.5;
    for (var i = 1; i < 20; i++) {
      canvas.drawLine(
        Offset(s.width * i / 20, 0),
        Offset(s.width * i / 20, s.height),
        p,
      );
      canvas.drawLine(
        Offset(0, s.height * i / 20),
        Offset(s.width, s.height * i / 20),
        p,
      );
    }
    final c = Paint()
      ..color = const Color(0x88E91E63)
      ..strokeWidth = 0.8;
    canvas.drawLine(Offset(s.width / 2, 0), Offset(s.width / 2, s.height), c);
    canvas.drawLine(Offset(0, s.height / 2), Offset(s.width, s.height / 2), c);
  }

  @override
  bool shouldRepaint(_GridPainter o) => false;
}

/// A decorative, non-scannable barcode derived from the card number.
class _BarcodePainter extends CustomPainter {
  _BarcodePainter(this.seed, this.color);
  final String seed;
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final r = math.Random(seed.hashCode);
    final p = Paint()..color = color;
    var x = 0.0;
    while (x < s.width) {
      final w = (r.nextInt(3) + 1) * s.width / 120;
      if (r.nextBool())
        canvas.drawRect(Rect.fromLTWH(x, 0, w, s.height * 0.8), p);
      x += w + s.width / 160;
    }
    final tp = TextPainter(
      text: TextSpan(
        text: seed,
        style: TextStyle(color: color, fontSize: s.height * 0.16),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: s.width);
    tp.paint(canvas, Offset((s.width - tp.width) / 2, s.height * 0.82));
  }

  @override
  bool shouldRepaint(_BarcodePainter o) => o.seed != seed || o.color != color;
}
