import 'dart:math' as math;

import 'package:flutter/services.dart';

import 'package:prism_plurality/core/features/feature_state.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/seasonal/decor_models.dart'
    show arrangementForVariation;
import 'package:prism_plurality/features/seasonal/decor_preview.dart';
import 'package:prism_plurality/features/seasonal/seasonal_catalog.dart'
    show variationById;
import 'package:prism_plurality/features/seasonal/seasonal_providers.dart'
    show seasonalPrefsProvider;
import 'package:prism_plurality/features/social/widgets/social_widgets.dart'
    show SocialImage;
import 'package:prism_plurality/features/yumeships/yume_data.dart';
import 'package:prism_plurality/shared/fonts/font_prefs.dart';
import 'package:prism_plurality/shared/fonts/prism_fonts.dart';
import 'package:prism_plurality/shared/media/prism_media.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// The accent for an item: its own colour, else the app theme's primary.
Color yumeAccent(BuildContext context, int? accent) =>
    accent == null ? Theme.of(context).colorScheme.primary : Color(accent);

/// Readable text on top of [c].
Color yumeOn(Color c) =>
    ThemeData.estimateBrightnessForColor(c) == Brightness.dark
    ? Colors.white
    : Colors.black;

bool yumeReduceMotion(BuildContext context, WidgetRef ref) {
  if (MediaQuery.of(context).disableAnimations) return true;
  final p = ref.watch(seasonalPrefsProvider);
  return p.reducedMotion || p.integrations['batterySaver'] == true;
}

/// Applies a decorative font to headings only, so body text stays in the
/// app's own (readable) font. Honours the plain-font accessibility override.
class YumeFontScope extends ConsumerWidget {
  const YumeFontScope({super.key, required this.font, required this.child});
  final String? font;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(fontPrefsProvider);
    final key = PrismFonts.resolve(font, prefs);
    if (key == null) return child;
    if (!PrismFonts.isLoaded(key)) {
      PrismFonts.ensureLoaded(key, imported: prefs.imported);
    }
    return ValueListenableBuilder<int>(
      valueListenable: PrismFonts.loadTick,
      builder: (context, _, _) {
        final theme = Theme.of(context);
        final t = theme.textTheme;
        TextStyle? f(TextStyle? s) =>
            s == null ? null : PrismFonts.style(key, s);
        return Theme(
          data: theme.copyWith(
            textTheme: t.copyWith(
              displaySmall: f(t.displaySmall),
              headlineLarge: f(t.headlineLarge),
              headlineMedium: f(t.headlineMedium),
              headlineSmall: f(t.headlineSmall),
              titleLarge: f(t.titleLarge),
              titleMedium: f(t.titleMedium),
            ),
          ),
          child: child,
        );
      },
    );
  }
}

/// A round picture, or the symbol when there's no picture.
class YumeAvatar extends StatelessWidget {
  const YumeAvatar({
    super.key,
    this.media,
    this.symbol = '♡',
    this.size = 48,
    this.accent,
  });
  final String? media;
  final String symbol;
  final double size;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final a = accent ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: a.withValues(alpha: 0.16),
        border: Border.all(color: a.withValues(alpha: 0.55), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: media == null
          ? Text(symbol, style: TextStyle(fontSize: size * 0.46))
          : SocialImage(
              id: media!,
              fit: BoxFit.cover,
              width: size,
              height: size,
            ),
    );
  }
}

/// Two avatars overlapping: the matching-pair motif used on ship cards.
class YumePairAvatars extends StatelessWidget {
  const YumePairAvatars({
    super.key,
    required this.left,
    required this.right,
    this.size = 44,
    this.accent,
    this.symbol = '♡',
  });
  final String? left, right;
  final double size;
  final Color? accent;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final a = accent ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: size * 1.7,
      height: size,
      child: Stack(
        children: [
          YumeAvatar(media: left, size: size, accent: a, symbol: symbol),
          Positioned(
            left: size * 0.7,
            child: YumeAvatar(media: right, size: size, accent: a, symbol: '✦'),
          ),
        ],
      ),
    );
  }
}

/// A decorated card in an item's chosen card style, frame and ribbon. Fills
/// and text always come from the current theme; the accent only tints.
class YumeCard extends StatelessWidget {
  const YumeCard({
    super.key,
    required this.child,
    this.accent,
    this.card = 'soft',
    this.frame = 'none',
    this.ribbon = 'none',
    this.stickers = const [],
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(14),
    this.radius = 18,
  });
  final Widget child;
  final Color? accent;
  final String card, frame, ribbon;
  final List<String> stickers;
  final VoidCallback? onTap, onLongPress;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final a = accent ?? cs.primary;
    final highContrast = MediaQuery.of(context).highContrast;
    final fill = switch (card) {
      'flat' => cs.surfaceContainerLow,
      'outlined' => cs.surface,
      'paper' => Color.alphaBlend(
        a.withValues(alpha: 0.06),
        cs.surfaceContainerLow,
      ),
      'glass' => cs.surfaceContainerHigh.withValues(alpha: 0.72),
      _ => Color.alphaBlend(a.withValues(alpha: 0.1), cs.surfaceContainerLow),
    };
    final border = switch (card) {
      'outlined' => Border.all(color: a.withValues(alpha: 0.8), width: 2),
      'paper' => Border.all(color: a.withValues(alpha: 0.25)),
      'glass' => Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      _ => highContrast ? Border.all(color: cs.outline) : null,
    };
    final shape = BorderRadius.circular(radius);
    Widget body = Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: shape,
        border: border,
        boxShadow: card == 'paper'
            ? [
                BoxShadow(
                  color: cs.shadow.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(1, 3),
                ),
              ]
            : null,
      ),
      child: CustomPaint(
        foregroundPainter: frame == 'none'
            ? null
            : _FramePainter(frame: frame, color: a, radius: radius),
        child: Padding(padding: padding, child: child),
      ),
    );
    if (onTap != null || onLongPress != null) {
      body = Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: shape,
          onTap: onTap,
          onLongPress: onLongPress,
          child: body,
        ),
      );
    }
    final ribbonGlyph = yumeRibbons[ribbon]?.$2 ?? '';
    if (ribbonGlyph.isEmpty && stickers.isEmpty) return body;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        body,
        if (ribbonGlyph.isNotEmpty)
          Positioned(
            top: -8,
            right: 14,
            child: IgnorePointer(
              child: Text(ribbonGlyph, style: const TextStyle(fontSize: 20)),
            ),
          ),
        for (var i = 0; i < math.min(stickers.length, 3); i++)
          Positioned(
            bottom: i == 1 ? -6 : 4,
            left: i == 0 ? -6 : null,
            right: i == 0 ? null : (i == 1 ? 18 : -6),
            child: IgnorePointer(
              child: Transform.rotate(
                angle: (i - 1) * 0.25,
                child: Text(stickers[i], style: const TextStyle(fontSize: 16)),
              ),
            ),
          ),
      ],
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter({
    required this.frame,
    required this.color,
    required this.radius,
  });
  final String frame;
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    ).deflate(5);
    switch (frame) {
      case 'tape':
        final tape = Paint()..color = color.withValues(alpha: 0.28);
        for (final (dx, ang) in [(0.12, -0.5), (0.88, 0.5)]) {
          canvas.save();
          canvas.translate(size.width * dx, 2);
          canvas.rotate(ang);
          canvas.drawRect(const Rect.fromLTWH(-18, -6, 36, 12), tape);
          canvas.restore();
        }
      case 'dotted':
        final path = Path()..addRRect(r);
        for (final m in path.computeMetrics()) {
          for (var d = 0.0; d < m.length; d += 7) {
            final t = m.getTangentForOffset(d);
            if (t != null) {
              canvas.drawCircle(
                t.position,
                1.2,
                Paint()..color = color.withValues(alpha: 0.6),
              );
            }
          }
        }
      case 'stamp':
        canvas.drawRRect(r, p);
        final notch = Paint()..color = color.withValues(alpha: 0.18);
        for (var x = 8.0; x < size.width - 4; x += 10) {
          canvas.drawCircle(Offset(x, 0), 2.4, notch);
          canvas.drawCircle(Offset(x, size.height), 2.4, notch);
        }
      case 'ornate':
        canvas.drawRRect(r, p);
        canvas.drawRRect(r.deflate(4), p..strokeWidth = 0.8);
        for (final c in [
          r.outerRect.topLeft,
          r.outerRect.topRight,
          r.outerRect.bottomLeft,
          r.outerRect.bottomRight,
        ]) {
          canvas.drawCircle(
            c,
            3,
            Paint()..color = color.withValues(alpha: 0.7),
          );
        }
      case 'panel':
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Offset.zero & size,
            const Radius.circular(4),
          ).deflate(3),
          p
            ..strokeWidth = 3
            ..color = color.withValues(alpha: 0.85),
        );
      case 'stars' || 'leaf' || 'cloud':
        final glyph = switch (frame) {
          'stars' => '✦',
          'leaf' => '❦',
          _ => '☁',
        };
        canvas.drawRRect(r, p..strokeWidth = 0.8);
        final tp = TextPainter(
          text: TextSpan(
            text: glyph,
            style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 12),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        for (final o in [
          const Offset(6, 2),
          Offset(size.width - 18, 2),
          Offset(6, size.height - 16),
          Offset(size.width - 18, size.height - 16),
        ]) {
          tp.paint(canvas, o);
        }
    }
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.frame != frame || old.color != color || old.radius != radius;
}

/// A living decoration look drawn as a gentle banner (still when reduced
/// motion or battery saver is on).
class YumeLivingBanner extends ConsumerStatefulWidget {
  const YumeLivingBanner({super.key, required this.lookId, this.height = 96});
  final String lookId;
  final double height;
  @override
  ConsumerState<YumeLivingBanner> createState() => _YumeLivingBannerState();
}

class _YumeLivingBannerState extends ConsumerState<YumeLivingBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = variationById(widget.lookId);
    if (v == null) return const SizedBox.shrink();
    final still = yumeReduceMotion(context, ref);
    if (still) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
    final items = arrangementForVariation(v);
    return ExcludeSemantics(
      child: SizedBox(
        height: widget.height,
        child: LayoutBuilder(
          builder: (context, box) => RepaintBoundary(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => DecorPreview(
                items: items,
                width: box.maxWidth,
                height: widget.height,
                showMockUi: false,
                t: still ? 2.2 : _c.value * 60,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Heading for a dashboard or profile section.
class YumeSectionTitle extends StatelessWidget {
  const YumeSectionTitle(this.title, {super.key, this.trailing, this.emoji});
  final String title;
  final String? emoji;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
      child: Row(
        children: [
          if (emoji != null) ...[
            ExcludeSemantics(
              child: Text(emoji!, style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: theme.textTheme.titleMedium),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A horizontally scrolling shelf.
class YumeShelf extends StatelessWidget {
  const YumeShelf({
    super.key,
    required this.children,
    this.height = 180,
    this.spacing = 12,
  });
  final List<Widget> children;
  final double height, spacing;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      itemCount: children.length,
      separatorBuilder: (_, _) => SizedBox(width: spacing),
      itemBuilder: (_, i) => children[i],
    ),
  );
}

/// Shown in place of a PIN-locked item.
class YumeLockedTile extends StatelessWidget {
  const YumeLockedTile({
    super.key,
    required this.onUnlock,
    this.compact = false,
  });
  final VoidCallback onUnlock;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return YumeCard(
      card: 'flat',
      onTap: onUnlock,
      child: Row(
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Icon(Icons.lock_outline, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              tr(
                context,
                'Locked — tap to unlock',
                'Bloqueado — toca para abrir',
              ),
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// Asks for the Yumeships PIN. Returns true when it matches.
Future<bool> yumeUnlock(
  BuildContext context,
  WidgetRef ref, {
  String? id,
}) async {
  final settings = ref.read(yumeSettingsProvider);
  if (!settings.hasPin) {
    // Locked without a PIN (e.g. the PIN was removed): nothing to check.
    if (id != null) ref.read(yumeUnlocksProvider.notifier).unlock(id);
    return true;
  }
  final pin = await yumeAskPin(
    context,
    title: tr(
      context,
      'Enter your Yumeships PIN',
      'Introduce tu PIN de Yumeships',
    ),
  );
  if (pin == null) return false;
  if (!settings.checkPin(pin)) {
    if (context.mounted)
      PrismToast.error(
        context,
        message: tr(context, 'That PIN doesn’t match', 'Ese PIN no coincide'),
      );
    return false;
  }
  final n = ref.read(yumeUnlocksProvider.notifier);
  id == null ? n.unlockAll() : n.unlock(id);
  return true;
}

/// A small PIN entry dialog (4–8 digits).
Future<String?> yumeAskPin(BuildContext context, {required String title}) {
  final c = TextEditingController();
  return PrismDialog.show<String>(
    context: context,
    title: title,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrismTextField(
          controller: c,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(8),
          ],
          hintText: '••••',
          onSubmitted: (v) {
            if (v.length >= 4) Navigator.of(ctx).pop(v);
          },
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            PrismButton(
              label: tr(ctx, 'Cancel', 'Cancelar'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            const SizedBox(width: 8),
            PrismButton(
              label: tr(ctx, 'OK', 'OK'),
              tone: PrismButtonTone.filled,
              onPressed: () {
                if (c.text.length >= 4) Navigator.of(ctx).pop(c.text);
              },
            ),
          ],
        ),
      ],
    ),
  );
}

/// Choose several alters (owners, collaborators, shared-with).
class YumeMemberChips extends ConsumerWidget {
  const YumeMemberChips({
    super.key,
    required this.selected,
    required this.onChanged,
    this.exclude = const {},
  });
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final Set<String> exclude;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members =
        ref.watch(userVisibleMembersProvider).value ?? const <Member>[];
    if (members.isEmpty) {
      return Text(
        tr(context, 'No alters yet.', 'Aún no hay alters.'),
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    final prefer = ref.watch(memberNamePreferDisplayProvider);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final m in members)
          if (!exclude.contains(m.id))
            PrismChip(
              label: memberLabel(m, preferDisplayName: prefer),
              selected: selected.contains(m.id),
              onTap: () {
                final next = [...selected];
                next.contains(m.id) ? next.remove(m.id) : next.add(m.id);
                onChanged(next);
              },
            ),
      ],
    );
  }
}

/// Names of alters by id (for owners lines).
final yumeMemberNamesProvider = Provider<Map<String, String>>((ref) {
  final prefer = ref.watch(memberNamePreferDisplayProvider);
  return {
    for (final m in ref.watch(allMembersProvider).value ?? const <Member>[])
      m.id: memberLabel(m, preferDisplayName: prefer),
  };
});

/// A soft "x days" pill for countdowns.
class YumeCountdownPill extends StatelessWidget {
  const YumeCountdownPill({super.key, required this.days, this.accent});
  final int days;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final a = accent ?? Theme.of(context).colorScheme.primary;
    final label = days == 0
        ? tr(context, 'Today', 'Hoy')
        : days == 1
        ? tr(context, 'Tomorrow', 'Mañana')
        : tr(context, 'In $days days', 'En $days días');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: a.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

/// A text field that edits a list of short strings as chips.
class YumeStringListField extends StatefulWidget {
  const YumeStringListField({
    super.key,
    required this.label,
    required this.values,
    required this.onChanged,
    this.suggestions = const [],
    this.hint,
  });
  final String label;
  final String? hint;
  final List<String> values;
  final List<String> suggestions;
  final ValueChanged<List<String>> onChanged;

  @override
  State<YumeStringListField> createState() => _YumeStringListFieldState();
}

class _YumeStringListFieldState extends State<YumeStringListField> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _add(String v) {
    final t = v.trim();
    if (t.isEmpty || widget.values.contains(t)) return;
    widget.onChanged([...widget.values, t]);
    _c.clear();
  }

  @override
  Widget build(BuildContext context) {
    final rest = [
      for (final s in widget.suggestions)
        if (!widget.values.contains(s)) s,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TrackerLabel(widget.label),
        if (widget.values.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final v in widget.values)
                  PrismChip(
                    label: '${v}  ✕',
                    selected: false,
                    onTap: () =>
                        widget.onChanged([...widget.values]..remove(v)),
                  ),
              ],
            ),
          ),
        PrismTextField(
          controller: _c,
          hintText:
              widget.hint ??
              tr(context, 'Add and press enter', 'Añade y pulsa intro'),
          textInputAction: TextInputAction.done,
          onSubmitted: _add,
          suffix: IconButton(
            tooltip: tr(context, 'Add', 'Añadir'),
            icon: const Icon(Icons.add),
            onPressed: () => _add(_c.text),
          ),
        ),
        if (rest.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in rest.take(12))
                PrismChip(label: '+ $s', selected: false, onTap: () => _add(s)),
            ],
          ),
        ],
      ],
    );
  }
}

/// Short date label, e.g. "14 Feb 2025" (year left off when [noYear]).
String yumeDate(DateTime d, {bool noYear = false}) {
  const m = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return noYear
      ? '${d.day} ${m[d.month - 1]}'
      : '${d.day} ${m[d.month - 1]} ${d.year}';
}

/// A sheet of choices with the current one ticked. Returns the chosen key.
Future<String?> yumeChoose(
  BuildContext context, {
  required String title,
  required Map<String, String> options,
  String? selected,
}) => PrismSheet.show<String>(
  context: context,
  title: title,
  builder: (ctx) => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(ctx).size.height * 0.6,
    ),
    child: ListView(
      shrinkWrap: true,
      children: [
        for (final e in options.entries)
          PrismListRow(
            dense: true,
            title: Text(e.value),
            selected: e.key == selected,
            trailing: e.key == selected
                ? Icon(Icons.check, color: Theme.of(ctx).colorScheme.primary)
                : null,
            onTap: () => Navigator.of(ctx).pop(e.key),
          ),
      ],
    ),
  ),
);

/// A stored image or video by media id.
class YumeMediaImage extends StatelessWidget {
  const YumeMediaImage({super.key, required this.id, this.fit = BoxFit.cover});
  final String id;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) => PrismMediaView(id: id, fit: fit);
}

/// Whether an alter's profile shows its Yumeships (feature on + opted in).
bool yumeProfileVisible(WidgetRef ref, String memberId) =>
    ref.watch(featureEnabledProvider('yumeships')) &&
    ref.watch(yumeSettingsProvider).profileMembers.contains(memberId) &&
    ref.watch(yumeShipsForMemberProvider(memberId)).isNotEmpty;

/// A quiet inline action (Prism button, compact).
class YumeAction extends StatelessWidget {
  const YumeAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => PrismButton(
    label: label,
    icon: icon,
    enabled: onPressed != null,
    density: PrismControlDensity.compact,
    onPressed: onPressed ?? () {},
  );
}
