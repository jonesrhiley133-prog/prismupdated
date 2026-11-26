import 'dart:math' as math;

import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';

import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/members/studio/profile_config.dart';
import 'package:prism_plurality/features/astro/views/astro_integrations.dart'
    show AstroProfileModule;
import 'package:prism_plurality/core/features/feature_state.dart'
    show featureEnabledProvider;
import 'package:prism_plurality/features/games/core/games_data.dart'
    show gameProfilesProvider, gameResultsProvider;
import 'package:prism_plurality/features/games/views/games_profile_view.dart'
    show AlterGamesProfile;
import 'package:prism_plurality/features/relationships/utils/relationships.dart';
import 'package:prism_plurality/features/relationships/views/relationship_labels.dart';
import 'package:prism_plurality/features/subsystems/hub/subsystem_data.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/media/prism_media.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import 'package:prism_plurality/shared/widgets/member_avatar.dart';

int? memberHexColor(String? hex) {
  final h = (hex ?? '').replaceAll('#', '').trim();
  if (h.length != 6 && h.length != 8) return null;
  final v = int.tryParse(h.length == 8 ? h.substring(2) : h, radix: 16);
  return v == null ? null : 0xFF000000 | v;
}

/// Banner role text: "Host · Protector · Caretaker".
String rolesLine(ProfileConfig cfg) =>
    cfg.roles.where((r) => r.visible).map((r) => r.name).join(' · ');

TextStyle? studioFont(String font, TextStyle? base) => switch (font) {
  'serif' => base?.copyWith(
    fontFamily: 'serif',
    fontFamilyFallback: const ['Georgia', 'Times New Roman'],
  ),
  'mono' => base?.copyWith(
    fontFamily: 'monospace',
    fontFamilyFallback: const ['Courier New', 'Menlo'],
  ),
  'rounded' => base?.copyWith(
    fontFamily: 'sans-serif-medium',
    letterSpacing: 0.3,
  ),
  'display' => base?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 0.6),
  _ => base,
};

class _Hexagon extends ShapeBorder {
  const _Hexagon();
  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;
  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect);
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final c = rect.center;
    final r = rect.shortestSide / 2;
    final p = Path();
    for (var i = 0; i < 6; i++) {
      final a = math.pi / 6 + i * math.pi / 3;
      final pt = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}
  @override
  ShapeBorder scale(double t) => this;
}

ShapeBorder avatarShape(String s) => switch (s) {
  'rounded' => RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
  'square' => RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
  'hexagon' => const _Hexagon(),
  _ => const CircleBorder(),
};

/// Renders a member profile designed in Profile Studio. Used both for the
/// live preview and on the member's profile page.
class StudioProfileView extends ConsumerWidget {
  const StudioProfileView({
    super.key,
    required this.member,
    required this.cfg,
    this.preview = false,
    this.showHeader = true,
    this.forceWide,
    this.inline = false,
  });
  final Member member;
  final ProfileConfig cfg;
  final bool preview;
  final bool showHeader;
  final bool? forceWide;

  /// On the member page, which already shows the bio and main pronouns.
  final bool inline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base = Theme.of(context);
    final accentInt =
        cfg.lookColor('accent') ??
        (member.customColorEnabled
            ? memberHexColor(member.customColorHex)
            : null);
    final accent = accentInt == null
        ? base.colorScheme.primary
        : Color(accentInt);
    final bgMode = cfg.lookStr('bgMode', 'none');
    final bg1 = Color(
      cfg.lookColor('bg1') ?? base.colorScheme.surface.toARGB32(),
    );
    final bg2 = Color(cfg.lookColor('bg2') ?? bg1.toARGB32());
    final dark = bgMode == 'none'
        ? base.brightness == Brightness.dark
        : Color.lerp(bg1, bg2, 0.5)!.computeLuminance() < 0.4;
    final scheme = bgMode == 'none'
        ? base.colorScheme.copyWith(primary: accent)
        : ColorScheme.fromSeed(
            seedColor: accent,
            brightness: dark ? Brightness.dark : Brightness.light,
          ).copyWith(primary: accent, surface: bg1);
    final theme = base.copyWith(
      colorScheme: scheme,
      textTheme: bgMode == 'none'
          ? base.textTheme
          : base.textTheme.apply(
              bodyColor: scheme.onSurface,
              displayColor: scheme.onSurface,
            ),
    );

    return Theme(
      data: theme,
      child: LayoutBuilder(
        builder: (context, box) {
          final wide = forceWide ?? box.maxWidth >= 700;
          final layout = wide
              ? cfg.lookStr('layoutDesktop', cfg.lookStr('layout', 'cards'))
              : cfg.lookStr('layout', 'cards');
          final bgMedia = cfg.look('bgMedia') as String?;
          final content = _Body(
            member: member,
            cfg: cfg,
            layout: layout,
            wide: wide,
            accent: accent,
            preview: preview,
            showHeader: showHeader,
            inline: inline,
          );
          if (bgMode == 'none') return content;
          return ClipRRect(
            borderRadius: prismCorners(context, preview ? 20 : 24),
            child: Stack(
              children: [
                Positioned.fill(
                  child: bgMode == 'image' && bgMedia != null
                      ? Opacity(
                          opacity: 0.55,
                          child: PrismMediaView(id: bgMedia),
                        )
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [bg1, bg2],
                            ),
                          ),
                        ),
                ),
                if (bgMode == 'image')
                  Positioned.fill(
                    child: ColoredBox(color: bg1.withValues(alpha: 0.45)),
                  ),
                content,
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.member,
    required this.cfg,
    required this.layout,
    required this.wide,
    required this.accent,
    required this.preview,
    required this.showHeader,
    this.inline = false,
  });
  final Member member;
  final ProfileConfig cfg;
  final String layout;
  final bool wide;
  final Color accent;
  final bool preview;
  final bool showHeader;
  final bool inline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modules = [
      for (final (id, visible) in cfg.modules)
        if (visible) ?_module(context, ref, id),
    ];
    final identity = _Identity(
      member: member,
      cfg: cfg,
      accent: accent,
      inline: inline,
    );
    final showIdentity = !inline || _hasIdentity(member, cfg, inline);
    final header = showHeader
        ? StudioHeader(member: member, cfg: cfg, accent: accent)
        : const SizedBox.shrink();
    final pad = EdgeInsets.all(preview ? 12 : 0);

    Widget card(Widget child) =>
        _Card(cfg: cfg, accent: accent, flat: layout == 'full', child: child);

    if (layout == 'sidebar' && wide) {
      return Padding(
        padding: pad,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 260,
                  child: showIdentity
                      ? card(identity)
                      : const SizedBox.shrink(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final m in modules)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: card(m),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
    if (layout == 'grid') {
      return Padding(
        padding: pad,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, box) {
                final cols = box.maxWidth >= 520 ? 2 : 1;
                final w = (box.maxWidth - (cols - 1) * 12) / cols;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (showIdentity) SizedBox(width: w, child: card(identity)),
                    for (final m in modules) SizedBox(width: w, child: card(m)),
                  ],
                );
              },
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: pad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SizedBox(height: 12),
          if (showIdentity) card(identity),
          for (final m in modules) ...[
            if (layout == 'full')
              const Divider(height: 28)
            else
              const SizedBox(height: 12),
            card(m),
          ],
        ],
      ),
    );
  }

  Widget? _module(BuildContext context, WidgetRef ref, String id) {
    final theme = Theme.of(context);
    final labels = cfg.labels;
    Widget titled(String title, List<Widget> children) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          moduleLabel(context, id) == title ? title : title,
          style: studioFont(
            cfg.lookStr('font', 'standard'),
            theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ),
        const SizedBox(height: 10),
        ...children,
      ],
    );
    Widget chips(String field) {
      final items = cfg.list(field);
      if (items.isEmpty) return const SizedBox.shrink();
      return _Private(
        cfg: cfg,
        field: field,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fieldLabel(context, field, labels),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final v in items) _Tag(v, color: accent)],
              ),
            ],
          ),
        ),
      );
    }

    switch (id) {
      case 'about':
        final desc = cfg.str('description');
        final bio = inline ? '' : (member.bio ?? '');
        if (desc.isEmpty && bio.isEmpty) return null;
        return titled(moduleLabel(context, id), [
          if (desc.isNotEmpty)
            Text(desc, style: theme.textTheme.bodyLarge?.copyWith(height: 1.5)),
          if (bio.isNotEmpty && bio != desc)
            Padding(
              padding: EdgeInsets.only(top: desc.isEmpty ? 0 : 8),
              child: Text(
                bio,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ),
        ]);
      case 'interests':
        final f = [
          'likes',
          'dislikes',
          'hobbies',
          'favMusic',
          'favMedia',
          'favColors',
          'favFoods',
        ];
        if (f.every((x) => cfg.list(x).isEmpty)) return null;
        return titled(moduleLabel(context, id), [for (final x in f) chips(x)]);
      case 'personality':
        final traits = cfg.traits;
        final f = [
          'strengths',
          'weaknesses',
          'habits',
          'communication',
          'boundaries',
          'quotes',
          'facts',
        ];
        if (traits.isEmpty && f.every((x) => cfg.list(x).isEmpty)) return null;
        return titled(moduleLabel(context, id), [
          if (traits.isNotEmpty)
            _Private(
              cfg: cfg,
              field: 'traits',
              child: Column(
                children: [
                  for (final (n, l) in traits)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 110,
                            child: Text(
                              n,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            child: Row(
                              children: [
                                for (var i = 1; i <= 5; i++)
                                  Expanded(
                                    child: Container(
                                      height: 7,
                                      margin: const EdgeInsets.only(right: 3),
                                      decoration: BoxDecoration(
                                        borderRadius: prismCorners(context, 4),
                                        color: i <= l
                                            ? accent
                                            : accent.withValues(alpha: 0.15),
                                      ),
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
          for (final x in f) chips(x),
        ]);
      case 'gallery':
        final ids = cfg.list('gallery');
        if (ids.isEmpty) return null;
        return titled(moduleLabel(context, id), [
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            children: [
              for (final m in ids)
                ClipRRect(
                  borderRadius: prismCorners(context, 10),
                  child: PrismMediaView(id: m),
                ),
            ],
          ),
        ]);
      case 'relationships':
        final all =
            ref.watch(trackerKindProvider(TrackerKind.relationship)).value ??
            const <TrackerRecord>[];
        final mine = [
          for (final r in all)
            if (r.memberId == member.id || r.str(RelField.otherId) == member.id)
              r,
        ];
        if (mine.isEmpty) return null;
        final index = {
          for (final m
              in ref.watch(allMemberListProvider).value ?? const <Member>[])
            m.id: m,
        };
        final prefer = ref.watch(memberNamePreferDisplayProvider);
        return titled(moduleLabel(context, id), [
          for (final r in mine.take(8))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(PhosphorIcons.heart(), size: 15, color: accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(() {
                      final otherId = r.memberId == member.id
                          ? r.str(RelField.otherId)
                          : r.memberId;
                      final other =
                          index[otherId]?.effectiveName(
                            preferDisplayName: prefer,
                          ) ??
                          r.str(RelField.otherName) ??
                          '—';
                      return '$other · ${relTypeLabel(context.l10n, r.str(RelField.type) ?? 'other')}';
                    }()),
                  ),
                ],
              ),
            ),
        ]);
      case 'fronting':
        final prefs = cfg.str('frontPrefs');
        final co = cfg.list('coFronters');
        final index = {
          for (final m
              in ref.watch(allMemberListProvider).value ?? const <Member>[])
            m.id: m,
        };
        final prefer = ref.watch(memberNamePreferDisplayProvider);
        final subs = ref
            .watch(subMembershipsProvider)
            .where((m) => m.memberId == member.id)
            .map((m) => m.subsystemId)
            .toSet();
        final subNames = [
          for (final s in ref.watch(subsystemsProvider))
            if (subs.contains(s.id)) s.title,
        ];
        return titled(moduleLabel(context, id), [
          if (prefs.isNotEmpty)
            _Private(
              cfg: cfg,
              field: 'frontPrefs',
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(prefs),
              ),
            ),
          if (co.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in co)
                    if (index[c] case final m?)
                      _Tag(
                        '⇄ ${m.effectiveName(preferDisplayName: prefer)}',
                        color: accent,
                      ),
                ],
              ),
            ),
          if (subNames.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${tr(context, 'Subsystems', 'Subsistemas')}: ${subNames.join(', ')}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (!preview)
            Align(
              alignment: Alignment.centerLeft,
              child: PrismButton(
                label: tr(context, 'Fronting history', 'Historial de frente'),
                icon: AppIcons.history,
                density: PrismControlDensity.compact,
                onPressed: () => context.push(
                  AppRoutePaths.memberFrontingHistory(member.id),
                ),
              ),
            ),
        ]);
      case 'memories':
        final mem = cfg.records('memories');
        if (mem.isEmpty) return null;
        return _Private(
          cfg: cfg,
          field: 'memories',
          child: titled(moduleLabel(context, id), [
            for (final m in mem)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${m['title'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if ('${m['body'] ?? ''}'.isNotEmpty)
                      Text(
                        '${m['body']}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          height: 1.45,
                        ),
                      ),
                  ],
                ),
              ),
          ]),
        );
      case 'custom':
        final cards = cfg
            .records('custom')
            .where((c) => c['hidden'] != true)
            .toList();
        if (cards.isEmpty) return null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, c) in cards.indexed) ...[
              if (i > 0) const SizedBox(height: 16),
              Text(
                '${c['title'] ?? ''}',
                style: studioFont(
                  cfg.lookStr('font', 'standard'),
                  theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text('${c['body'] ?? ''}', style: const TextStyle(height: 1.5)),
            ],
          ],
        );
      case 'music':
        final m = cfg.records('music');
        if (m.isEmpty) return null;
        return titled(moduleLabel(context, id), [
          for (final t in m)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: '${t['url'] ?? ''}'.isEmpty
                    ? null
                    : () => launchUrl(
                        Uri.parse('${t['url']}'),
                        mode: LaunchMode.externalApplication,
                      ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        borderRadius: prismCorners(context, 8),
                        color: accent.withValues(alpha: 0.18),
                      ),
                      child: Icon(
                        PhosphorIcons.musicNotes(),
                        size: 17,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${t['title'] ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if ('${t['artist'] ?? ''}'.isNotEmpty)
                            Text(
                              '${t['artist']}',
                              style: theme.textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ]);
      case 'links':
        final l = cfg.records('links');
        if (l.isEmpty) return null;
        return titled(moduleLabel(context, id), [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final x in l)
                _Tag(
                  '🔗 ${'${x['label'] ?? ''}'.isEmpty ? x['url'] : x['label']}',
                  color: accent,
                  onTap: () {
                    final u = Uri.tryParse('${x['url'] ?? ''}');
                    if (u != null && u.hasScheme)
                      launchUrl(u, mode: LaunchMode.externalApplication);
                  },
                ),
            ],
          ),
        ]);
      case 'pinned':
        final p = cfg.str('pinned');
        if (p.isEmpty) return null;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              PhosphorIcons.pushPin(PhosphorIconsStyle.fill),
              size: 18,
              color: accent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                p,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                ),
              ),
            ),
          ],
        );
      case 'astro':
        // Shows only when this alter's astrology is visible to the viewer.
        if (!AstroProfileModule.visible(ref, member.id)) return null;
        return AstroProfileModule(member: member, accent: accent);
      case 'games':
        // Optional: off by default, hidden when the alter hides their stats
        // or hasn't played anything yet.
        if (!ref.watch(featureEnabledProvider('games'))) return null;
        if (ref.watch(gameProfilesProvider)[member.id]?.hideStats ?? false)
          return null;
        if (!ref.watch(gameResultsProvider).any((r) => r.memberId == member.id))
          return null;
        return titled(moduleLabel(context, id), [
          AlterGamesProfile(memberId: member.id),
        ]);
      case 'journal':
        final entries =
            (ref.watch(trackerKindProvider(TrackerKind.journalEntry)).value ??
                    const <TrackerRecord>[])
                .where((e) => e.memberId == member.id && !e.isPrivate)
                .toList()
              ..sort(
                (a, b) => (b.occurredAt ?? b.createdAt).compareTo(
                  a.occurredAt ?? a.createdAt,
                ),
              );
        if (entries.isEmpty) return null;
        return titled(moduleLabel(context, id), [
          for (final e in entries.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.title.isEmpty
                        ? DateFormat.yMMMd(
                            context.dateLocale,
                          ).format(e.occurredAt ?? e.createdAt)
                        : e.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if ((e.body ?? '').isNotEmpty)
                    Text(
                      e.body!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
        ]);
    }
    return null;
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.cfg,
    required this.accent,
    required this.child,
    this.flat = false,
  });
  final ProfileConfig cfg;
  final Color accent;
  final Widget child;
  final bool flat;
  @override
  Widget build(BuildContext context) {
    if (flat) return child;
    final scheme = Theme.of(context).colorScheme;
    final border = cfg.lookStr('border', 'thin');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(
          alpha: cfg.lookStr('bgMode', 'none') == 'none' ? 1 : 0.55,
        ),
        borderRadius: prismCorners(context, 18),
        border: switch (border) {
          'none' => null,
          'double' => Border.all(
            color: accent.withValues(alpha: 0.6),
            width: 2.5,
          ),
          'glow' => Border.all(color: accent.withValues(alpha: 0.55)),
          _ => Border.all(color: scheme.outlineVariant),
        },
        boxShadow: border == 'glow'
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.3),
                  blurRadius: 18,
                  spreadRadius: -4,
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, {required this.color, this.onTap});
  final String label;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: color.withValues(alpha: 0.12),
    shape: const StadiumBorder(),
    child: InkWell(
      customBorder: const StadiumBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(label, style: const TextStyle(fontSize: 13)),
      ),
    ),
  );
}

/// Hides private fields behind a tap-to-reveal.
class _Private extends StatelessWidget {
  const _Private({required this.cfg, required this.field, required this.child});
  final ProfileConfig cfg;
  final String field;
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      PrivateReveal(isPrivate: cfg.privacyOf(field) == 'private', child: child);
}

/// A role pill in its chosen colour and style.
class RolePill extends StatelessWidget {
  const RolePill({
    super.key,
    required this.role,
    required this.fallback,
    this.onTap,
    this.onDelete,
  });
  final ProfileRole role;
  final Color fallback;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  @override
  Widget build(BuildContext context) {
    final c = role.color == null ? fallback : Color(role.color!);
    final on = c.computeLuminance() > 0.5 ? Colors.black : Colors.white;
    final solid = role.style == 'solid';
    return Opacity(
      opacity: role.visible ? 1 : 0.45,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: prismCorners(context, 999),
          color: solid
              ? c
              : (role.style == 'outline'
                    ? Colors.transparent
                    : c.withValues(alpha: 0.16)),
          border: Border.all(
            color: c.withValues(alpha: role.style == 'soft' ? 0.35 : 0.9),
            width: role.style == 'outline' ? 1.5 : 1,
          ),
          boxShadow: role.style == 'glow'
              ? [
                  BoxShadow(
                    color: c.withValues(alpha: 0.55),
                    blurRadius: 12,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, 5, onDelete == null ? 12 : 4, 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    role.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: solid
                          ? on
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  if (onDelete != null) ...[
                    const SizedBox(width: 2),
                    InkWell(
                      customBorder: prismCircleBorder(context),
                      onTap: onDelete,
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: Icon(
                          PhosphorIcons.x(),
                          size: 13,
                          color: solid ? on : null,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Banner, avatar, name, roles line, subtitle and status.
class StudioHeader extends ConsumerWidget {
  const StudioHeader({
    super.key,
    required this.member,
    required this.cfg,
    required this.accent,
  });
  final Member member;
  final ProfileConfig cfg;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final prefer = ref.watch(memberNamePreferDisplayProvider);
    final height = cfg.lookNum('bannerHeight', 170).clamp(100, 320).toDouble();
    final overlay = cfg.lookNum('bannerOverlay', 0.25).clamp(0, 0.9).toDouble();
    final align = cfg.lookStr('bannerAlign', 'center');
    final pos = cfg.lookNum('bannerPosition', 0).clamp(-1, 1).toDouble();
    final bannerMedia = cfg.look('bannerMedia') as String?;
    final avatarMedia = cfg.look('avatarMedia') as String?;
    final shape = avatarShape(cfg.lookStr('avatarShape', 'circle'));
    final font = cfg.lookStr('font', 'standard');
    final decorations = [
      for (final d in (cfg.look('decorations') as List?) ?? const [])
        if (d is String) d,
    ];
    final roles = rolesLine(cfg);
    final cross = switch (align) {
      'left' => CrossAxisAlignment.start,
      'right' => CrossAxisAlignment.end,
      _ => CrossAxisAlignment.center,
    };
    final textAlign = switch (align) {
      'left' => TextAlign.left,
      'right' => TextAlign.right,
      _ => TextAlign.center,
    };
    final avatarSize = 92.0;

    Widget bannerImage() {
      if (bannerMedia != null) return PrismMediaView(id: bannerMedia);
      final bytes = member.profileHeaderImageData;
      if (bytes != null)
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          alignment: Alignment(0, pos),
          gaplessPlayback: true,
        );
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [accent, Color.lerp(accent, Colors.black, 0.55)!],
          ),
        ),
      );
    }

    final avatar = Container(
      width: avatarSize,
      height: avatarSize,
      decoration: ShapeDecoration(
        shape: shape,
        color: theme.colorScheme.surface,
        shadows: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: avatarMedia != null
            ? PrismMediaView(id: avatarMedia)
            : FittedBox(
                child: MemberAvatar(
                  avatarImageData: member.avatarImageData,
                  memberName: member.effectiveName(preferDisplayName: prefer),
                  emoji: member.emoji,
                  customColorEnabled: member.customColorEnabled,
                  customColorHex: member.customColorHex,
                  size: avatarSize,
                ),
              ),
      ),
    );

    return Column(
      crossAxisAlignment: cross,
      children: [
        SizedBox(
          height: height + avatarSize / 2,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: height,
                child: ClipRRect(
                  borderRadius: prismCorners(context, 20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      bannerImage(),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: overlay * 0.4),
                              Colors.black.withValues(alpha: overlay),
                            ],
                          ),
                        ),
                      ),
                      if (roles.isNotEmpty)
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 12,
                          child: Text(
                            roles,
                            textAlign: textAlign,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8,
                              shadows: [
                                Shadow(blurRadius: 8, color: Colors.black54),
                              ],
                            ),
                          ),
                        ),
                      for (final (i, d) in decorations.take(6).indexed)
                        Positioned(
                          left: (i.isEven ? 12.0 : null),
                          right: (i.isOdd ? 12.0 : null),
                          top: 10.0 + (i ~/ 2) * 28,
                          child: Text(d, style: const TextStyle(fontSize: 20)),
                        ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: height - avatarSize / 2,
                left: align == 'left' ? 16 : null,
                right: align == 'right' ? 16 : null,
                child: align == 'center' ? const SizedBox.shrink() : avatar,
              ),
              if (align == 'center')
                Positioned(
                  top: height - avatarSize / 2,
                  left: 0,
                  right: 0,
                  child: Center(child: avatar),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          member.effectiveName(preferDisplayName: prefer),
          textAlign: textAlign,
          style: studioFont(
            font,
            theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (cfg.str('subtitle').isNotEmpty)
          Text(
            cfg.str('subtitle'),
            textAlign: textAlign,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        if (cfg.str('status').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: prismCorners(context, 999),
                color: accent.withValues(alpha: 0.14),
              ),
              child: Text(
                '💬 ${cfg.str('status')}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
        if (cfg.roles.any((r) => r.visible)) ...[
          const SizedBox(height: 10),
          Wrap(
            alignment: switch (align) {
              'left' => WrapAlignment.start,
              'right' => WrapAlignment.end,
              _ => WrapAlignment.center,
            },
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final r in cfg.roles.where((r) => r.visible))
                RolePill(role: r, fallback: accent),
            ],
          ),
        ],
      ],
    );
  }
}

bool _hasIdentity(Member m, ProfileConfig cfg, bool inline) {
  bool t(String? v) => v != null && v.trim().isNotEmpty;
  return cfg.list('altNames').isNotEmpty ||
      cfg
          .list('pronounSets')
          .any(
            (p) =>
                p.trim().toLowerCase() !=
                (m.pronouns ?? '').trim().toLowerCase(),
          ) ||
      (!inline && t(m.pronouns)) ||
      t(cfg.str('gender')) ||
      t(m.age) ||
      t(cfg.str('ageRange')) ||
      t(m.birthday) ||
      t(cfg.str('species')) ||
      t(cfg.str('origin')) ||
      cfg.list('tags').isNotEmpty ||
      cfg.list('internalRoles').isNotEmpty;
}

class _Identity extends ConsumerWidget {
  const _Identity({
    required this.member,
    required this.cfg,
    required this.accent,
    this.inline = false,
  });
  final Member member;
  final ProfileConfig cfg;
  final Color accent;
  final bool inline;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final labels = cfg.labels;
    String? value(String f) => switch (f) {
      'altNames' => cfg.list('altNames').join(', '),
      'pronounSets' => {
        if (!inline) ?member.pronouns?.trim(),
        for (final p in cfg.list('pronounSets'))
          if (p.trim().toLowerCase() !=
              (member.pronouns ?? '').trim().toLowerCase())
            p.trim(),
      }.where((x) => x.isNotEmpty).join(' · '),
      'gender' => cfg.str('gender'),
      'age' => [
        ?member.age,
        if (cfg.str('ageRange').isNotEmpty) cfg.str('ageRange'),
      ].where((x) => x.trim().isNotEmpty).join(' · '),
      'birthday' => member.birthday ?? '',
      'species' => cfg.str('species'),
      'origin' => cfg.str('origin'),
      _ => '',
    };
    final rows = [
      for (final f in cfg.fieldOrder)
        if ((value(f) ?? '').trim().isNotEmpty) (f, value(f)!),
    ];
    final tags = cfg.list('tags');
    final internal = cfg.list('internalRoles');
    if (rows.isEmpty && tags.isEmpty && internal.isEmpty) {
      if (inline) return const SizedBox.shrink();
      return Text(
        tr(
          context,
          'No identity details yet.',
          'Aún no hay detalles de identidad.',
        ),
        style: theme.textTheme.bodySmall,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (f, v) in rows)
          _Private(
            cfg: cfg,
            field: f,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fieldLabel(context, f, labels),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(v, style: theme.textTheme.bodyLarge),
                ],
              ),
            ),
          ),
        if (internal.isNotEmpty) ...[
          Text(
            fieldLabel(context, 'internalRoles', labels),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final r in internal) _Tag(r, color: accent)],
          ),
          const SizedBox(height: 10),
        ],
        if (tags.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final t in tags) _Tag('#$t', color: accent)],
          ),
      ],
    );
  }
}

/// Profile Studio content on a member's profile page (nothing when the
/// member has no studio profile yet).
class StudioProfileSection extends ConsumerWidget {
  const StudioProfileSection({super.key, required this.member});
  final Member member;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(memberProfileProvider(member.id));
    if (cfg == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: StudioProfileView(
        member: member,
        cfg: cfg,
        showHeader: false,
        inline: true,
      ),
    );
  }
}

/// Subtitle, roles line, status and role pills under the regular profile
/// header (members with a studio profile only).
class StudioHeaderExtras extends ConsumerWidget {
  const StudioHeaderExtras({super.key, required this.member});
  final Member member;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(memberProfileProvider(member.id));
    if (cfg == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final accent = cfg.lookColor('accent') == null
        ? theme.colorScheme.primary
        : Color(cfg.lookColor('accent')!);
    final roles = rolesLine(cfg);
    final visible = cfg.roles.where((r) => r.visible).toList();
    if (roles.isEmpty &&
        cfg.str('subtitle').isEmpty &&
        cfg.str('status').isEmpty)
      return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        children: [
          if (cfg.str('subtitle').isNotEmpty)
            Text(
              cfg.str('subtitle'),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (roles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                roles,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (cfg.str('status').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '💬 ${cfg.str('status')}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (visible.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final r in visible) RolePill(role: r, fallback: accent),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
