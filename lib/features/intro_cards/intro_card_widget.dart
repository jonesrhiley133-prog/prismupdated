import 'dart:math' as math;

import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/intro_cards/intro_models.dart';
import 'package:prism_plurality/shared/media/prism_media.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Tarot-proportioned card that flips between its front and back.
class IntroCardView extends StatefulWidget {
  const IntroCardView({
    super.key,
    required this.card,
    required this.member,
    required this.template,
    required this.displayName,
    this.width = 240,
    this.flippable = true,
    this.initiallyBack = false,
  });

  final TrackerRecord card;
  final Member? member;
  final IntroTemplate template;
  final String displayName;
  final double width;
  final bool flippable;
  final bool initiallyBack;

  @override
  State<IntroCardView> createState() => _IntroCardViewState();
}

class _IntroCardViewState extends State<IntroCardView> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 550), value: widget.initiallyBack ? 1 : 0);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _flip() {
    if (MediaQuery.of(context).disableAnimations) {
      _c.value = _c.value < 0.5 ? 1 : 0;
      return;
    }
    _c.value < 0.5 ? _c.forward() : _c.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.width * 1.72;
    return Semantics(
      button: widget.flippable,
      label: tr(context, 'Introduction card for ${widget.displayName}. Tap to flip.', 'Tarjeta de presentación de ${widget.displayName}. Toca para girar.'),
      child: GestureDetector(
        onTap: widget.flippable ? _flip : null,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = Curves.easeInOutCubic.transform(_c.value);
            final angle = t * math.pi;
            final showBack = angle > math.pi / 2;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateY(angle),
              child: SizedBox(
                width: widget.width,
                height: h,
                child: showBack
                    ? Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..rotateY(math.pi),
                        child: _CardFace(template: widget.template, child: _Back(card: widget.card, template: widget.template, name: widget.displayName)),
                      )
                    : _CardFace(
                        template: widget.template,
                        child: _Front(card: widget.card, member: widget.member, template: widget.template, name: widget.displayName),
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({required this.template, required this.child});
  final IntroTemplate template;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(template.bg1), Color(template.bg2)],
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: CustomPaint(
        foregroundPainter: _BorderPainter(Color(template.border)),
        painter: _PatternPainter(template.pattern, Color(template.border).withValues(alpha: 0.18)),
        child: Padding(padding: const EdgeInsets.fromLTRB(18, 18, 18, 18), child: child),
      ),
    );
  }
}

class _Front extends StatelessWidget {
  const _Front({required this.card, required this.member, required this.template, required this.name});
  final TrackerRecord card;
  final Member? member;
  final IntroTemplate template;
  final String name;

  @override
  Widget build(BuildContext context) {
    final ink = Color(template.ink);
    final art = card.str('art');
    final numeral = card.str('numeral');
    final arcana = card.str('arcana');
    final base = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, c) {
        final scale = c.maxWidth / 204;
        return Column(
          children: [
            if (numeral != null)
              Text(numeral, style: template.style(base.titleMedium!.copyWith(color: ink, letterSpacing: 3, fontSize: 14 * scale))),
            SizedBox(height: 6 * scale),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Color(template.border), width: 1.5),
                  borderRadius: BorderRadius.circular(c.maxWidth),
                ),
                clipBehavior: Clip.antiAlias,
                child: art != null
                    ? PrismMediaView(id: art)
                    : member?.avatarImageData != null
                    ? Image.memory(member!.avatarImageData!, fit: BoxFit.cover, gaplessPlayback: true)
                    : Center(
                        child: Text(
                          (member?.emoji.trim().isNotEmpty ?? false) && member!.emoji != '❔' ? member!.emoji : '✦',
                          style: TextStyle(fontSize: 64 * scale, color: ink),
                        ),
                      ),
              ),
            ),
            SizedBox(height: 10 * scale),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 6 * scale, horizontal: 6),
              decoration: BoxDecoration(
                border: Border.symmetric(horizontal: BorderSide(color: Color(template.border), width: 1.2)),
              ),
              child: Column(
                children: [
                  Text(
                    name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: template.style(base.titleMedium!.copyWith(color: ink, letterSpacing: 2.5, fontSize: 17 * scale, fontWeight: FontWeight.w700)),
                  ),
                  if (arcana != null)
                    Text(
                      arcana,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: template.style(base.labelMedium!.copyWith(color: ink.withValues(alpha: 0.85), fontStyle: FontStyle.italic, fontSize: 12 * scale)),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Back extends StatelessWidget {
  const _Back({required this.card, required this.template, required this.name});
  final TrackerRecord card;
  final IntroTemplate template;
  final String name;

  @override
  Widget build(BuildContext context) {
    final ink = Color(template.ink);
    final base = Theme.of(context).textTheme;
    final values = card.fields['values'] is Map ? (card.fields['values'] as Map).cast<String, Object?>() : const <String, Object?>{};
    final shown = card.strings('shown');
    final custom = card.fields['custom'] is List ? (card.fields['custom'] as List).whereType<Map>().toList() : const <Map>[];
    final lang = Localizations.localeOf(context).languageCode;
    final rows = <(String, String)>[
      for (final f in introFields)
        if ((shown.isEmpty || shown.contains(f.key)) && (values[f.key] as String?)?.trim().isNotEmpty == true)
          (lang == 'es' ? f.es : f.en, (values[f.key] as String).trim()),
      for (final c in custom)
        if ((c['label'] as String?)?.isNotEmpty == true && (c['value'] as String?)?.isNotEmpty == true)
          (c['label'] as String, c['value'] as String),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(name, textAlign: TextAlign.center, style: template.style(base.titleMedium!.copyWith(color: ink, fontWeight: FontWeight.w700))),
        Divider(color: Color(template.border), height: 14),
        Expanded(
          child: rows.isEmpty
              ? Center(
                  child: Text(
                    tr(context, 'Add details in the card editor.', 'Añade detalles en el editor.'),
                    textAlign: TextAlign.center,
                    style: template.style(base.bodySmall!.copyWith(color: ink)),
                  ),
                )
              : ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    for (final (label, value) in rows)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label.toUpperCase(), style: template.style(base.labelSmall!.copyWith(color: Color(template.border), letterSpacing: 1.4))),
                            Text(value, style: template.style(base.bodySmall!.copyWith(color: ink))),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _BorderPainter extends CustomPainter {
  _BorderPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final outer = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)).deflate(6);
    canvas.drawRRect(outer, p);
    canvas.drawRRect(outer.deflate(4), p..strokeWidth = 0.8);
    // Corner ornaments.
    final fill = Paint()..color = color;
    for (final c in [
      Offset(14, 14),
      Offset(size.width - 14, 14),
      Offset(14, size.height - 14),
      Offset(size.width - 14, size.height - 14),
    ]) {
      final path = Path()
        ..moveTo(c.dx, c.dy - 6)
        ..lineTo(c.dx + 3, c.dy)
        ..lineTo(c.dx, c.dy + 6)
        ..lineTo(c.dx - 3, c.dy)
        ..close();
      canvas.drawPath(path, fill);
      canvas.drawPath(
        Path()
          ..moveTo(c.dx - 6, c.dy)
          ..lineTo(c.dx, c.dy + 3)
          ..lineTo(c.dx + 6, c.dy)
          ..lineTo(c.dx, c.dy - 3)
          ..close(),
        fill,
      );
    }
  }

  @override
  bool shouldRepaint(_BorderPainter old) => old.color != color;
}

class _PatternPainter extends CustomPainter {
  _PatternPainter(this.pattern, this.color);
  final String pattern;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (pattern == 'none') return;
    final rnd = math.Random(pattern.hashCode);
    final p = Paint()..color = color;
    for (var i = 0; i < 26; i++) {
      final o = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
      final r = 2 + rnd.nextDouble() * 5;
      switch (pattern) {
        case 'stars':
          final path = Path();
          for (var k = 0; k < 10; k++) {
            final rr = k.isEven ? r : r * 0.45;
            final a = -math.pi / 2 + k * math.pi / 5;
            final pt = o + Offset(math.cos(a) * rr, math.sin(a) * rr);
            k == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
          }
          canvas.drawPath(path..close(), p);
        case 'moons':
          canvas.drawPath(
            Path.combine(
              PathOperation.difference,
              Path()..addOval(Rect.fromCircle(center: o, radius: r)),
              Path()..addOval(Rect.fromCircle(center: o + Offset(r * 0.5, -r * 0.2), radius: r)),
            ),
            p,
          );
        case 'suns':
          canvas.drawCircle(o, r * 0.6, p);
          for (var k = 0; k < 8; k++) {
            final a = k * math.pi / 4;
            canvas.drawLine(o + Offset(math.cos(a), math.sin(a)) * r * 0.9, o + Offset(math.cos(a), math.sin(a)) * r * 1.5, p..strokeWidth = 1);
          }
        case 'leaves':
          canvas.save();
          canvas.translate(o.dx, o.dy);
          canvas.rotate(rnd.nextDouble() * math.pi);
          canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 1.2, height: r * 2.6), p);
          canvas.restore();
        case 'waves':
          final path = Path()..moveTo(o.dx - r * 2, o.dy);
          path.quadraticBezierTo(o.dx - r, o.dy - r, o.dx, o.dy);
          path.quadraticBezierTo(o.dx + r, o.dy + r, o.dx + r * 2, o.dy);
          canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.4);
      }
    }
  }

  @override
  bool shouldRepaint(_PatternPainter old) => old.pattern != pattern || old.color != color;
}
