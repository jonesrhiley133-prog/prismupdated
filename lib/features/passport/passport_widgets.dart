import 'dart:math' as math;

import 'package:intl/intl.dart' show DateFormat;

import 'package:prism_plurality/features/companions/companion_data.dart';
import 'package:prism_plurality/features/companions/companion_widgets.dart';
import 'package:prism_plurality/features/companions/photo_mode.dart'
    show PhotoSceneView;
import 'package:prism_plurality/features/links/models/record_ref.dart';
import 'package:prism_plurality/features/links/providers/link_providers.dart';
import 'package:prism_plurality/features/passport/passport_data.dart';
import 'package:prism_plurality/features/passport/stamp_art.dart';
import 'package:prism_plurality/features/social/widgets/social_widgets.dart'
    show SocialImage;
import 'package:prism_plurality/shared/ui_kit.dart';

String? fontFamilyFor(String font) => switch (font) {
  'serif' => 'serif',
  'mono' => 'monospace',
  'script' => 'cursive',
  _ => null,
};

/// What to hide when previewing or exporting.
@immutable
class PassportPrivacy {
  const PassportPrivacy({
    this.names = false,
    this.dates = false,
    this.locations = false,
    this.photos = false,
    this.notes = false,
    this.nameList = const [],
  });
  final bool names, dates, locations, photos, notes;
  final List<String> nameList;
  static const none = PassportPrivacy();

  String text(String s) {
    if (!names || s.isEmpty) return s;
    var out = s;
    for (final n in nameList.where((n) => n.trim().length > 1)) {
      out = out.replaceAll(
        RegExp(RegExp.escape(n), caseSensitive: false),
        '•••',
      );
    }
    return out;
  }

  PassportPrivacy copyWith({
    bool? names,
    bool? dates,
    bool? locations,
    bool? photos,
    bool? notes,
    List<String>? nameList,
  }) => PassportPrivacy(
    names: names ?? this.names,
    dates: dates ?? this.dates,
    locations: locations ?? this.locations,
    photos: photos ?? this.photos,
    notes: notes ?? this.notes,
    nameList: nameList ?? this.nameList,
  );
}

class PrivacyScope extends InheritedWidget {
  const PrivacyScope({super.key, required this.privacy, required super.child});
  final PassportPrivacy privacy;
  static PassportPrivacy of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PrivacyScope>()?.privacy ??
      PassportPrivacy.none;
  @override
  bool updateShouldNotify(PrivacyScope old) => old.privacy != privacy;
}

/// A passport cover.
class PassportCoverView extends StatelessWidget {
  const PassportCoverView({
    super.key,
    required this.cover,
    required this.name,
    this.subtitle = '',
    this.width = 180,
    this.badge,
  });
  final PassportCover cover;
  final String name;
  final String subtitle;
  final double width;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final h = width * 1.38;
    final ink = Color(cover.secondary);
    final privacy = PrivacyScope.of(context);
    return Semantics(
      label: 'Passport cover: ${privacy.text(name)}',
      child: SizedBox(
        width: width,
        height: h,
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _CoverPainter(cover))),
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  width * 0.12,
                  h * 0.1,
                  width * 0.1,
                  h * 0.08,
                ),
                child: Column(
                  children: [
                    Text(
                      'PASSPORT',
                      style: TextStyle(
                        color: ink,
                        letterSpacing: width * 0.025,
                        fontSize: width * 0.065,
                        fontWeight: FontWeight.w700,
                        fontFamily: fontFamilyFor(cover.font),
                      ),
                    ),
                    const Spacer(),
                    Text(cover.symbol, style: TextStyle(fontSize: width * 0.3)),
                    const Spacer(),
                    Text(
                      privacy.text(name),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ink,
                        fontSize: width * 0.1,
                        fontWeight: FontWeight.w700,
                        fontFamily: fontFamilyFor(cover.font),
                        height: 1.1,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        privacy.text(subtitle),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ink.withValues(alpha: 0.85),
                          fontSize: width * 0.06,
                          fontFamily: fontFamilyFor(cover.font),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (badge != null) Positioned(top: 6, right: 6, child: badge!),
          ],
        ),
      ),
    );
  }
}

class _CoverPainter extends CustomPainter {
  _CoverPainter(this.c);
  final PassportCover c;

  @override
  void paint(Canvas canvas, Size s) {
    final r = RRect.fromRectAndCorners(
      Offset.zero & s,
      topLeft: const Radius.circular(6),
      bottomLeft: const Radius.circular(6),
      topRight: Radius.circular(s.width * 0.08),
      bottomRight: Radius.circular(s.width * 0.08),
    );
    final base = Color(c.primary);
    canvas.drawRRect(
      r.shift(const Offset(2, 3)),
      Paint()..color = const Color(0x33000000),
    );
    final shader = switch (c.material) {
      'metallic' => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(base, Colors.white, 0.35)!,
          base,
          Color.lerp(base, Colors.white, 0.2)!,
          Color.lerp(base, Colors.black, 0.2)!,
        ],
      ).createShader(Offset.zero & s),
      'holographic' => SweepGradient(
        center: Alignment.topLeft,
        colors: [
          base,
          const Color(0xFFFFD1F0),
          const Color(0xFFB8F2FF),
          const Color(0xFFFFF5B8),
          base,
        ],
      ).createShader(Offset.zero & s),
      'velvet' => RadialGradient(
        center: const Alignment(-0.3, -0.4),
        radius: 1.2,
        colors: [
          Color.lerp(base, Colors.white, 0.18)!,
          base,
          Color.lerp(base, Colors.black, 0.3)!,
        ],
      ).createShader(Offset.zero & s),
      _ => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(base, Colors.white, 0.06)!,
          Color.lerp(base, Colors.black, 0.12)!,
        ],
      ).createShader(Offset.zero & s),
    };
    canvas.drawRRect(r, Paint()..shader = shader);
    canvas.save();
    canvas.clipRRect(r);
    final rnd = math.Random(c.material.hashCode);
    switch (c.material) {
      case 'leather' || 'kraft':
        for (var i = 0; i < 220; i++) {
          canvas.drawCircle(
            Offset(rnd.nextDouble() * s.width, rnd.nextDouble() * s.height),
            rnd.nextDouble() * 1.2,
            Paint()
              ..color = (c.material == 'kraft' ? Colors.black : Colors.white)
                  .withValues(alpha: 0.06 + rnd.nextDouble() * 0.06),
          );
        }
      case 'linen':
        final p = Paint()
          ..color = Colors.white.withValues(alpha: 0.05)
          ..strokeWidth = 1;
        for (var x = 0.0; x < s.width; x += 3) {
          canvas.drawLine(Offset(x, 0), Offset(x, s.height), p);
        }
        for (var y = 0.0; y < s.height; y += 3) {
          canvas.drawLine(Offset(0, y), Offset(s.width, y), p);
        }
      case 'denim':
        final p = Paint()
          ..color = Colors.white.withValues(alpha: 0.07)
          ..strokeWidth = 1.2;
        for (var x = -s.height; x < s.width; x += 4) {
          canvas.drawLine(Offset(x, s.height), Offset(x + s.height, 0), p);
        }
    }
    // Spine.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, s.width * 0.06, s.height),
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );
    canvas.restore();
    final ink = Color(c.secondary);
    final inset = r.deflate(s.width * 0.05);
    switch (c.border) {
      case 'gold' || 'silver':
        canvas.drawRRect(
          inset,
          Paint()
            ..color = c.border == 'gold'
                ? const Color(0xFFD4AF37)
                : const Color(0xFFC9CED6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
      case 'stitched':
        final path = Path()..addRRect(inset);
        for (final m in path.computeMetrics()) {
          for (var d = 0.0; d < m.length; d += 7) {
            canvas.drawPath(
              m.extractPath(d, d + 4),
              Paint()
                ..color = ink.withValues(alpha: 0.8)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.2,
            );
          }
        }
      case 'dotted':
        final path = Path()..addRRect(inset);
        for (final m in path.computeMetrics()) {
          for (var d = 0.0; d < m.length; d += 6) {
            canvas.drawCircle(
              m.getTangentForOffset(d)!.position,
              1,
              Paint()..color = ink,
            );
          }
        }
      case 'double':
        canvas.drawRRect(
          inset,
          Paint()
            ..color = ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
        canvas.drawRRect(
          inset.deflate(4),
          Paint()
            ..color = ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8,
        );
      case 'ornate':
        canvas.drawRRect(
          inset,
          Paint()
            ..color = ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
        for (final o in [
          inset.outerRect.topLeft,
          inset.outerRect.topRight,
          inset.outerRect.bottomLeft,
          inset.outerRect.bottomRight,
        ]) {
          canvas.drawCircle(o, 5, Paint()..color = ink);
          canvas.drawCircle(
            o,
            9,
            Paint()
              ..color = ink
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.8,
          );
        }
    }
  }

  @override
  bool shouldRepaint(_CoverPainter old) => old.c != c;
}

/// Paper with an optional texture.
class PaperBackground extends StatelessWidget {
  const PaperBackground({
    super.key,
    required this.color,
    required this.texture,
    this.child,
  });
  final int color;
  final String texture;
  final Widget? child;
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _PaperPainter(Color(color), texture), child: child);
}

class _PaperPainter extends CustomPainter {
  _PaperPainter(this.color, this.texture);
  final Color color;
  final String texture;
  @override
  void paint(Canvas c, Size s) {
    c.drawRect(Offset.zero & s, Paint()..color = color);
    final ink = Paint()
      ..color = Color.lerp(color, Colors.black, 0.12)!
      ..strokeWidth = 0.6;
    switch (texture) {
      case 'dotted':
        for (var x = 12.0; x < s.width; x += 16) {
          for (var y = 12.0; y < s.height; y += 16) {
            c.drawCircle(Offset(x, y), 0.9, ink);
          }
        }
      case 'grid':
        for (var x = 0.0; x < s.width; x += 16) {
          c.drawLine(Offset(x, 0), Offset(x, s.height), ink);
        }
        for (var y = 0.0; y < s.height; y += 16) {
          c.drawLine(Offset(0, y), Offset(s.width, y), ink);
        }
      case 'lined':
        for (var y = 28.0; y < s.height; y += 18) {
          c.drawLine(Offset(0, y), Offset(s.width, y), ink);
        }
      case 'kraft':
        final rnd = math.Random(2);
        for (var i = 0; i < 260; i++) {
          c.drawCircle(
            Offset(rnd.nextDouble() * s.width, rnd.nextDouble() * s.height),
            rnd.nextDouble() * 0.9,
            Paint()..color = const Color(0x22000000),
          );
        }
      case 'watercolor':
        final rnd = math.Random(5);
        for (var i = 0; i < 6; i++) {
          c.drawCircle(
            Offset(rnd.nextDouble() * s.width, rnd.nextDouble() * s.height),
            40 + rnd.nextDouble() * 60,
            Paint()
              ..color = HSVColor.fromAHSV(
                0.06,
                rnd.nextDouble() * 360,
                0.5,
                0.9,
              ).toColor(),
          );
        }
      case 'linen':
        for (var x = 0.0; x < s.width; x += 3) {
          c.drawLine(
            Offset(x, 0),
            Offset(x, s.height),
            Paint()..color = const Color(0x08000000),
          );
        }
    }
  }

  @override
  bool shouldRepaint(_PaperPainter old) =>
      old.color != color || old.texture != texture;
}

/// A stamp instance, with its uploaded picture if any.
class StampInstanceView extends StatelessWidget {
  const StampInstanceView({
    super.key,
    required this.stamp,
    this.size = 100,
    this.rotationOverride,
  });
  final PassportStamp stamp;
  final double size;
  final double? rotationOverride;
  @override
  Widget build(BuildContext context) {
    final p = PrivacyScope.of(context);
    var d = stamp.design;
    if (rotationOverride != null)
      d = d.copyWith({'rotation': rotationOverride});
    if (p.names)
      d = d.copyWith({'text': p.text(d.text), 'subtext': p.text(d.subtext)});
    return StampView(
      design: d,
      size: size,
      hideDate: p.dates,
      imageWidget: d.image == null || p.photos
          ? null
          : SocialImage(id: d.image!, fit: BoxFit.cover),
    );
  }
}

/// One page: paper, its header, and what's on it. Stamps on a timeline page
/// are listed by date automatically.
class PassportPageView extends ConsumerWidget {
  const PassportPageView({
    super.key,
    required this.passport,
    required this.page,
    this.selected,
    this.onSelect,
    this.onDrag,
    this.onDragEnd,
  });
  final Passport passport;
  final PassportPage page;
  final String? selected;
  final void Function(PassportElement)? onSelect;
  final void Function(PassportElement, Offset delta, Size box)? onDrag;
  final void Function(PassportElement)? onDragEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = PrivacyScope.of(context);
    final elements = ref.watch(pageElementsProvider(page.id));
    final font = fontFamilyFor(passport.cover.font);
    final ink = Color.lerp(
      Color(page.background ?? passport.paper),
      Colors.black,
      0.75,
    )!;
    final (typeLabel, emoji) = passportPageTypes[page.type] ?? ('Page', '📄');
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: ClipRRect(
        borderRadius: prismCorners(context, 10),
        child: PaperBackground(
          color: page.background ?? passport.paper,
          texture: passport.texture,
          child: LayoutBuilder(
            builder: (context, box) {
              final unit = box.maxWidth;
              final size = Size(box.maxWidth, box.maxHeight);
              final header = Padding(
                padding: EdgeInsets.fromLTRB(
                  unit * 0.05,
                  unit * 0.04,
                  unit * 0.05,
                  0,
                ),
                child: Row(
                  children: [
                    Text(emoji, style: TextStyle(fontSize: unit * 0.05)),
                    SizedBox(width: unit * 0.02),
                    Expanded(
                      child: Text(
                        p.text(page.title.isEmpty ? typeLabel : page.title),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ink,
                          fontSize: unit * 0.05,
                          fontWeight: FontWeight.w700,
                          fontFamily: font,
                        ),
                      ),
                    ),
                  ],
                ),
              );
              if (page.type == 'timeline') {
                final stamps = ref.watch(passportStampsProvider(passport.id));
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    Expanded(
                      child: stamps.isEmpty
                          ? Center(
                              child: Text(
                                'Stamps appear here in date order.',
                                style: TextStyle(
                                  color: ink.withValues(alpha: 0.6),
                                  fontFamily: font,
                                ),
                              ),
                            )
                          : ListView(
                              padding: EdgeInsets.all(unit * 0.04),
                              children: [
                                for (final s in stamps)
                                  Padding(
                                    padding: EdgeInsets.only(
                                      bottom: unit * 0.02,
                                    ),
                                    child: Row(
                                      children: [
                                        StampInstanceView(
                                          stamp: s,
                                          size: unit * 0.18,
                                          rotationOverride: 0,
                                        ),
                                        SizedBox(width: unit * 0.03),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                p.text(s.title),
                                                style: TextStyle(
                                                  color: ink,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: unit * 0.04,
                                                  fontFamily: font,
                                                ),
                                              ),
                                              if (!p.dates)
                                                Text(
                                                  DateFormat.yMMMd().format(
                                                    s.at,
                                                  ),
                                                  style: TextStyle(
                                                    color: ink.withValues(
                                                      alpha: 0.7,
                                                    ),
                                                    fontSize: unit * 0.033,
                                                  ),
                                                ),
                                              if (!p.locations &&
                                                  s.location.isNotEmpty)
                                                Text(
                                                  '📍 ${s.location}',
                                                  style: TextStyle(
                                                    color: ink.withValues(
                                                      alpha: 0.7,
                                                    ),
                                                    fontSize: unit * 0.033,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ],
                );
              }
              Widget element(PassportElement e, {double? fixedSize}) =>
                  _ElementView(
                    element: e,
                    unit: fixedSize ?? unit,
                    ink: ink,
                    font: font,
                  );
              final note = page.note.isNotEmpty && !p.notes
                  ? Padding(
                      padding: EdgeInsets.fromLTRB(
                        unit * 0.05,
                        unit * 0.02,
                        unit * 0.05,
                        unit * 0.03,
                      ),
                      child: Text(
                        p.text(page.note),
                        maxLines: 8,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ink,
                          fontSize: unit * 0.038,
                          fontFamily: font,
                          height: 1.35,
                        ),
                      ),
                    )
                  : null;
              final attach = page.attachments.isNotEmpty && !p.notes
                  ? _Attachments(keys: page.attachments, ink: ink, unit: unit)
                  : null;
              if (!page.manual) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    Expanded(
                      child: elements.isEmpty && note == null
                          ? Center(
                              child: Text(
                                'Empty page',
                                style: TextStyle(
                                  color: ink.withValues(alpha: 0.45),
                                  fontFamily: font,
                                ),
                              ),
                            )
                          : SingleChildScrollView(
                              padding: EdgeInsets.all(unit * 0.04),
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                spacing: unit * 0.03,
                                runSpacing: unit * 0.03,
                                children: [
                                  for (final e in elements)
                                    GestureDetector(
                                      onTap: onSelect == null
                                          ? null
                                          : () => onSelect!(e),
                                      child: Container(
                                        decoration: selected == e.id
                                            ? BoxDecoration(
                                                border: Border.all(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                                  width: 2,
                                                ),
                                                borderRadius: prismCorners(
                                                  context,
                                                  8,
                                                ),
                                              )
                                            : null,
                                        child: element(e),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                    ),
                    ?attach,
                    ?note,
                  ],
                );
              }
              return Stack(
                children: [
                  Positioned(left: 0, right: 0, top: 0, child: header),
                  for (final e in elements)
                    Positioned(
                      left: e.x * size.width - unit * 0.12 * e.scale,
                      top: e.y * size.height - unit * 0.12 * e.scale,
                      child: GestureDetector(
                        onTap: onSelect == null ? null : () => onSelect!(e),
                        onPanStart: onSelect == null
                            ? null
                            : (_) => onSelect!(e),
                        onPanUpdate: onDrag == null
                            ? null
                            : (d) => onDrag!(e, d.delta, size),
                        onPanEnd: onDragEnd == null
                            ? null
                            : (_) => onDragEnd!(e),
                        child: Container(
                          decoration: selected == e.id
                              ? BoxDecoration(
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    width: 2,
                                  ),
                                  borderRadius: prismCorners(context, 8),
                                )
                              : null,
                          child: element(e),
                        ),
                      ),
                    ),
                  if (note != null || attach != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Column(children: [?attach, ?note]),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ElementView extends ConsumerWidget {
  const _ElementView({
    required this.element,
    required this.unit,
    required this.ink,
    this.font,
  });
  final PassportElement element;
  final double unit;
  final Color ink;
  final String? font;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = PrivacyScope.of(context);
    final e = element;
    final base = unit * 0.24 * e.scale;
    Widget child;
    switch (e.type) {
      case 'stamp':
        final s = e.stampId == null
            ? null
            : ref.watch(stampByIdProvider(e.stampId!));
        if (s == null) return const SizedBox.shrink();
        child = StampInstanceView(
          stamp: s,
          size: base,
          rotationOverride: e.rotation,
        );
        return child;
      case 'photo':
        final ref0 = RecordRef.parse(e.refKey);
        final memory = ref0 == null
            ? null
            : ref
                  .watch(companionMemoriesProvider)
                  .where((m) => m.id == ref0.id)
                  .firstOrNull;
        if (p.photos) {
          child = Container(
            width: base * 1.3,
            height: base * 1.3,
            color: const Color(0xFFE5E5E5),
            alignment: Alignment.center,
            child: const Icon(Icons.image_not_supported_outlined),
          );
        } else if (memory?.scene != null) {
          child = SizedBox(
            width: base * 1.3,
            child: PhotoSceneView(scene: memory!.scene!, animate: false),
          );
        } else if (e.media != null) {
          child = SizedBox(
            width: base * 1.3,
            height: base * 1.3,
            child: SocialImage(id: e.media!, fit: BoxFit.cover),
          );
        } else {
          return const SizedBox.shrink();
        }
        child = Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(
            base * 0.05,
            base * 0.05,
            base * 0.05,
            base * 0.16,
          ),
          child: child,
        );
      case 'sticker':
        child = Text(e.emoji, style: TextStyle(fontSize: base * 0.6));
      case 'text':
        if (p.notes) return const SizedBox.shrink();
        child = ConstrainedBox(
          constraints: BoxConstraints(maxWidth: unit * 0.8),
          child: Text(
            p.text(e.text),
            style: TextStyle(
              color: Color(e.color),
              fontSize: unit * 0.045 * e.scale,
              fontFamily: font,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      case 'companion':
        final id = RecordRef.parse(e.refKey)?.id;
        final c = id == null ? null : ref.watch(companionByIdProvider(id));
        if (c == null) return _missing(context, 'Companion no longer here');
        child = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CompanionFigure(
              companion: c,
              size: base * 1.2,
              animate: false,
              showParticles: false,
            ),
            Text(
              p.text(c.name),
              style: TextStyle(
                color: ink,
                fontSize: unit * 0.035,
                fontFamily: font,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        );
      case 'attachment':
        if (p.notes) return const SizedBox.shrink();
        child = _Attachments(keys: [?e.refKey], ink: ink, unit: unit);
      default:
        return const SizedBox.shrink();
    }
    return Transform.rotate(angle: e.rotation * math.pi / 180, child: child);
  }

  Widget _missing(BuildContext context, String text) => Text(
    text,
    style: TextStyle(
      color: ink.withValues(alpha: 0.5),
      fontSize: unit * 0.03,
      fontStyle: FontStyle.italic,
    ),
  );
}

/// Linked records shown by name. A deleted record reads as "removed" and
/// never breaks the page.
class _Attachments extends ConsumerWidget {
  const _Attachments({
    required this.keys,
    required this.ink,
    required this.unit,
  });
  final List<String> keys;
  final Color ink;
  final double unit;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(recordCatalogProvider);
    final p = PrivacyScope.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: unit * 0.04,
        vertical: unit * 0.01,
      ),
      child: Wrap(
        spacing: unit * 0.015,
        runSpacing: unit * 0.015,
        children: [
          for (final k in keys)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: unit * 0.02,
                vertical: unit * 0.008,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: ink.withValues(alpha: 0.4)),
                borderRadius: prismCorners(context, unit * 0.02),
              ),
              child: Text(
                catalog[k] == null
                    ? '🔗 (removed)'
                    : '🔗 ${p.text(catalog[k]!.title)}',
                style: TextStyle(
                  color: ink.withValues(alpha: catalog[k] == null ? 0.5 : 0.85),
                  fontSize: unit * 0.032,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small helper for owner text on passports.
String passportOwnerLabel(
  Passport p,
  Map<String, String> names,
  Map<String, String> subs,
) => switch (p.ownerType) {
  OwnerType.system => 'Whole system',
  OwnerType.none => 'Unassigned',
  OwnerType.subsystem =>
    p.owners.map((id) => subs[id] ?? 'Subsystem').join(', '),
  _ => p.owners.map((id) => names[id] ?? '?').join(', '),
};

/// An uploaded picture filling its box.
class SocialImageBox extends StatelessWidget {
  const SocialImageBox({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) => SocialImage(id: id, fit: BoxFit.cover);
}

/// The record catalogue (re-exported for stamp attachment names).
final recordCatalogProviderForStamps = recordCatalogProvider;
