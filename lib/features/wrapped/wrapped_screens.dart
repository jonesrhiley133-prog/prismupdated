import 'dart:async';
import 'dart:typed_data';

import 'package:intl/intl.dart' show DateFormat;

import 'package:prism_plurality/features/companions/companion_data.dart';
import 'package:prism_plurality/features/companions/companion_screens.dart'
    show memberNamesProvider, pushPage, subsystemNamesProvider;
import 'package:prism_plurality/features/experiences/color_sheet.dart';
import 'package:prism_plurality/features/experiences/export_kit.dart';
import 'package:prism_plurality/features/games/engines/ambience_synth.dart';
import 'package:prism_plurality/features/games/engines/tone_player.dart';
import 'package:prism_plurality/features/passport/passport_data.dart';
import 'package:prism_plurality/features/passport/passport_screens.dart'
    show pickPassport;
import 'package:prism_plurality/features/social/models/social.dart'
    show PostType;
import 'package:prism_plurality/features/social/services/social_actions.dart';
import 'package:prism_plurality/features/wrapped/wrapped_cards.dart';
import 'package:prism_plurality/features/wrapped/wrapped_data.dart';
import 'package:prism_plurality/features/wrapped/wrapped_engine.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Names that "hide names" should mask in shared recaps.
List<String> _allNames(WidgetRef ref) => [
  ...ref.watch(memberNamesProvider).values,
  ...ref.watch(subsystemNamesProvider).values,
  for (final c in ref.watch(companionsProvider)) c.name,
];

WrapMask _maskFor(WidgetRef ref, WrapStyle s) => WrapMask(
  names: _allNames(ref),
  hideNames: s.hideNames,
  hideNumbers: s.hideNumbers,
);

String _range(DateTime from, DateTime to) {
  final last = to.subtract(const Duration(days: 1));
  if (from.year == last.year &&
      from.month == last.month &&
      from.day == last.day)
    return DateFormat.yMMMd().format(from);
  return '${DateFormat.MMMd().format(from)} – ${DateFormat.yMMMd().format(last)}';
}

// ---------------------------------------------------------------------------
// Archive

/// Every saved recap, newest first, with quick ways to make a new one.
class WrappedHomeScreen extends ConsumerStatefulWidget {
  const WrappedHomeScreen({super.key});
  @override
  ConsumerState<WrappedHomeScreen> createState() => _WrappedHomeScreenState();
}

class _WrappedHomeScreenState extends ConsumerState<WrappedHomeScreen> {
  String _query = '';
  bool _favorites = false;
  String? _collection;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(wrapSnapshotsProvider);
    final theme = Theme.of(context);
    final collections = {
      for (final s in all)
        if (s.collection.isNotEmpty) s.collection,
    }.toList()..sort();
    final shown = [
      for (final s in all)
        if ((!_favorites || s.favorite) &&
            (_collection == null || s.collection == _collection) &&
            (_query.isEmpty ||
                s.title.toLowerCase().contains(_query.toLowerCase())))
          s,
    ];
    final byYear = <int, List<WrapSnapshot>>{};
    for (final s in shown) {
      byYear.putIfAbsent(s.from.year, () => []).add(s);
    }
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: 'Wrapped',
        showBackButton: true,
        actions: [
          IconButton(
            tooltip: 'Season dates',
            icon: const Icon(Icons.tune),
            onPressed: () =>
                pushPage<void>(context, const WrapSettingsScreen()),
          ),
        ],
      ),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + NavBarInset.of(context)),
          children: [
            Text(
              'Look back on what you played, made, saved and celebrated. Recaps are built on this device from what you recorded — nothing is judged or scored.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in [
                  WrapPeriod.weekly,
                  WrapPeriod.monthly,
                  WrapPeriod.seasonal,
                  WrapPeriod.yearly,
                ])
                  PrismChip(
                    label: switch (p) {
                      WrapPeriod.weekly => 'This week',
                      WrapPeriod.monthly => 'This month',
                      WrapPeriod.seasonal => 'This season',
                      _ => 'This year',
                    },
                    selected: false,
                    onTap: () => _quick(p),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            PrismButton(
              label: 'New recap',
              icon: Icons.auto_awesome,
              tone: PrismButtonTone.filled,
              expanded: true,
              onPressed: () =>
                  pushPage<void>(context, const WrapCreateScreen()),
            ),
            const SizedBox(height: 16),
            if (all.isNotEmpty) ...[
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search recaps',
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PrismChip(
                    label: '★ Favourites',
                    selected: _favorites,
                    onTap: () => setState(() => _favorites = !_favorites),
                  ),
                  for (final c in collections)
                    PrismChip(
                      label: c,
                      selected: _collection == c,
                      onTap: () => setState(
                        () => _collection = _collection == c ? null : c,
                      ),
                    ),
                ],
              ),
            ],
            if (all.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    const Text('🎁', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 8),
                    Text('No recaps yet', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Pick a period above to make your first one.',
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            for (final year
                in byYear.keys.toList()..sort((a, b) => b.compareTo(a))) ...[
              PrismSectionHeader(title: '$year'),
              for (final s in byYear[year]!) _SnapshotTile(s: s),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _quick(WrapPeriod p) async {
    final seasons = ref.read(wrapSettingsProvider).seasons;
    final (from, to) = periodRange(p, DateTime.now(), seasons: seasons);
    await pushPage<void>(
      context,
      WrapCreateScreen(period: p, from: from, to: to, autoGenerate: true),
    );
  }
}

class _SnapshotTile extends ConsumerWidget {
  const _SnapshotTile({required this.s});
  final WrapSnapshot s;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = s.style.arrange(s.cards);
    final a = ref.read(wrapActionsProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PrismSurface(
        padding: const EdgeInsets.all(10),
        onTap: () => pushPage<void>(context, WrapPlayerScreen.snapshot(s)),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: cards.isEmpty
                  ? const SizedBox.shrink()
                  : IgnorePointer(
                      child: WrapCardView(
                        card: cards.first,
                        style: s.style,
                        animateFigures: false,
                        mask: _maskFor(ref, s.style),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${s.favorite ? '★ ' : ''}${s.title}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    '${s.period.label} · ${_range(s.from, s.to)} · ${cards.length} cards',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (s.collection.isNotEmpty)
                    Text(
                      s.collection,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                ],
              ),
            ),
            PrismPopupMenu<String>(
              tooltip: 'More',
              onSelected: (v) async {
                switch (v) {
                  case 'play':
                    await pushPage<void>(context, WrapPlayerScreen.snapshot(s));
                  case 'edit':
                    await pushPage<void>(
                      context,
                      WrapStudioScreen(snapshotId: s.id),
                    );
                  case 'export':
                    await pushPage<void>(
                      context,
                      WrapExportScreen(snapshotId: s.id),
                    );
                  case 'fav':
                    await a.update(s, {'favorite': !s.favorite});
                  case 'collection':
                    final name = await _askText(
                      context,
                      'Collection',
                      s.collection,
                      hint: 'e.g. Summers, Big moments',
                    );
                    if (name != null)
                      await a.update(s, {'collection': name.trim()});
                  case 'dup':
                    await a.duplicate(s);
                  case 'delete':
                    if (await PrismDialog.confirm(
                      context: context,
                      title: 'Delete “${s.title}”?',
                      message:
                          'This recap will be removed. The things it summarised stay where they are.',
                      confirmLabel: 'Delete',
                      destructive: true,
                    ))
                      await a.delete(s);
                }
              },
              items: [
                PrismMenuItem(
                  value: 'play',
                  label: 'Play',
                  icon: Icons.play_arrow,
                ),
                PrismMenuItem(
                  value: 'edit',
                  label: 'Edit in studio',
                  icon: Icons.edit_outlined,
                ),
                PrismMenuItem(
                  value: 'export',
                  label: 'Export & share',
                  icon: Icons.ios_share,
                ),
                PrismMenuItem(
                  value: 'fav',
                  label: s.favorite ? 'Unfavourite' : 'Favourite',
                  icon: Icons.star_outline,
                ),
                PrismMenuItem(
                  value: 'collection',
                  label: 'Add to collection…',
                  icon: Icons.folder_outlined,
                ),
                PrismMenuItem(
                  value: 'dup',
                  label: 'Duplicate',
                  icon: Icons.copy,
                ),
                PrismMenuItem(
                  value: 'delete',
                  label: 'Delete',
                  icon: Icons.delete_outline,
                  destructive: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<String?> _askText(
  BuildContext context,
  String title,
  String initial, {
  String? hint,
  int lines = 1,
}) {
  final c = TextEditingController(text: initial);
  return PrismDialog.show<String>(
    context: context,
    title: title,
    builder: (_) => TextField(
      controller: c,
      autofocus: true,
      maxLines: lines,
      decoration: InputDecoration(hintText: hint),
    ),
    actions: [
      PrismButton(
        label: 'Cancel',
        onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
      ),
      PrismButton(
        label: 'Save',
        tone: PrismButtonTone.filled,
        onPressed: () => Navigator.of(context, rootNavigator: true).pop(c.text),
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Create

/// Choose a period, who it's about and what to include, then generate.
class WrapCreateScreen extends ConsumerStatefulWidget {
  const WrapCreateScreen({
    super.key,
    this.period = WrapPeriod.monthly,
    this.from,
    this.to,
    this.autoGenerate = false,
    this.scope,
  });
  final WrapPeriod period;
  final DateTime? from, to;
  final bool autoGenerate;
  final WrapScope? scope;
  @override
  ConsumerState<WrapCreateScreen> createState() => _WrapCreateScreenState();
}

class _WrapCreateScreenState extends ConsumerState<WrapCreateScreen> {
  late WrapPeriod _period = widget.period;
  late DateTime _from;
  late DateTime _to;
  late WrapScope _scope = widget.scope ?? const WrapScope();
  Set<String> _cats = {...wrapCategories.keys};
  final List<String> _highlights = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final seasons = ref.read(wrapSettingsProvider).seasons;
    final r = periodRange(_period, DateTime.now(), seasons: seasons);
    _from = widget.from ?? r.$1;
    _to = widget.to ?? r.$2;
    if (widget.autoGenerate)
      WidgetsBinding.instance.addPostFrameCallback((_) => _generate());
  }

  void _setPeriod(WrapPeriod p, [DateTime? anchor]) {
    final seasons = ref.read(wrapSettingsProvider).seasons;
    final r = periodRange(
      p,
      anchor ?? DateTime.now(),
      seasons: seasons,
      customEnd: p == WrapPeriod.custom
          ? _to.subtract(const Duration(days: 1))
          : null,
    );
    setState(() {
      _period = p;
      _from = r.$1;
      _to = r.$2;
    });
  }

  void _step(int dir) {
    if (_period == WrapPeriod.custom) return;
    final anchor = dir < 0 ? _from.subtract(const Duration(days: 1)) : _to;
    _setPeriod(_period, anchor);
  }

  Future<void> _generate() async {
    setState(() => _busy = true);
    try {
      final seasons = ref.read(wrapSettingsProvider).seasons;
      final title = wrapTitle(_period, _from, _to, seasons: seasons);
      final cards = await ref
          .read(wrapActionsProvider)
          .generate(
            from: _from,
            to: _to,
            scope: _scope,
            categories: _cats,
            highlights: _highlights,
            title: title,
          );
      if (!mounted) return;
      final r = await ref
          .read(wrapActionsProvider)
          .save(
            title: title,
            period: _period,
            from: _from,
            to: _to,
            scope: _scope,
            style: const WrapStyle(),
            cards: cards,
            categories: _cats,
            highlights: _highlights,
          );
      if (!mounted) return;
      final snap = WrapSnapshot(r);
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => WrapPlayerScreen.snapshot(snap, offerStudio: true),
        ),
      );
    } catch (e) {
      if (mounted)
        PrismToast.show(context, message: 'Couldn\'t make the recap: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final names = ref.watch(memberNamesProvider);
    final subs = ref.watch(subsystemNamesProvider);
    final companions = ref.watch(companionsProvider);
    return PrismPageScaffold(
      topBar: const PrismTopBar(title: 'New recap', showBackButton: true),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + NavBarInset.of(context)),
          children: [
            PrismSectionHeader(title: 'PERIOD'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in WrapPeriod.values)
                  PrismChip(
                    label: p.label,
                    selected: _period == p,
                    onTap: () => _setPeriod(p),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            PrismSurface(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Earlier',
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _period == WrapPeriod.custom
                        ? null
                        : () => _step(-1),
                  ),
                  Expanded(
                    child: Text(
                      _range(_from, _to),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Later',
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _period == WrapPeriod.custom
                        ? null
                        : () => _step(1),
                  ),
                ],
              ),
            ),
            if (_period == WrapPeriod.custom) ...[
              const SizedBox(height: 8),
              PrismButton(
                label: 'Choose dates',
                icon: Icons.date_range,
                onPressed: () async {
                  final r = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now().add(const Duration(days: 366)),
                    initialDateRange: DateTimeRange(
                      start: _from,
                      end: _to.subtract(const Duration(days: 1)),
                    ),
                  );
                  if (r != null) {
                    final (f, t) = periodRange(
                      WrapPeriod.custom,
                      r.start,
                      customEnd: r.end,
                    );
                    setState(() {
                      _from = f;
                      _to = t;
                    });
                  }
                },
              ),
            ],
            PrismSectionHeader(title: 'WHO IT\'S ABOUT'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PrismChip(
                  label: 'Whole system',
                  selected: _scope.type == 'system',
                  onTap: () => setState(() => _scope = const WrapScope()),
                ),
                for (final e in names.entries)
                  PrismChip(
                    label: e.value,
                    selected:
                        (_scope.type == 'member' || _scope.type == 'members') &&
                        _scope.ids.contains(e.key),
                    onTap: () => setState(() {
                      final ids =
                          (_scope.type == 'member' || _scope.type == 'members')
                          ? [..._scope.ids]
                          : <String>[];
                      ids.contains(e.key) ? ids.remove(e.key) : ids.add(e.key);
                      _scope = ids.isEmpty
                          ? const WrapScope()
                          : WrapScope(
                              type: ids.length == 1 ? 'member' : 'members',
                              ids: ids,
                            );
                    }),
                  ),
                for (final e in subs.entries)
                  PrismChip(
                    label: '◎ ${e.value}',
                    selected:
                        _scope.type == 'subsystem' &&
                        _scope.ids.contains(e.key),
                    onTap: () => setState(
                      () => _scope = WrapScope(type: 'subsystem', ids: [e.key]),
                    ),
                  ),
                for (final c in companions)
                  PrismChip(
                    label: '🐾 ${c.name}',
                    selected:
                        _scope.type == 'companion' && _scope.ids.contains(c.id),
                    onTap: () => setState(
                      () => _scope = WrapScope(type: 'companion', ids: [c.id]),
                    ),
                  ),
              ],
            ),
            PrismSectionHeader(title: 'INCLUDE'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in wrapCategories.entries)
                  PrismChip(
                    label: e.value,
                    selected: _cats.contains(e.key),
                    onTap: () => setState(
                      () => _cats = _cats.contains(e.key)
                          ? ({..._cats}..remove(e.key))
                          : {..._cats, e.key},
                    ),
                  ),
              ],
            ),
            if (_cats.contains('highlights')) ...[
              const SizedBox(height: 8),
              _HighlightPicker(
                selected: _highlights,
                from: _from,
                to: _to,
                onChanged: () => setState(() {}),
              ),
            ],
            const SizedBox(height: 20),
            PrismButton(
              label: _busy ? 'Making your recap…' : 'Make recap',
              icon: Icons.auto_awesome,
              tone: PrismButtonTone.filled,
              expanded: true,
              isLoading: _busy,
              onPressed: _generate,
              enabled: !_busy,
            ),
          ],
        ),
      ),
    );
  }
}

/// Journal entries to feature as hand-picked highlights.
class _HighlightPicker extends ConsumerWidget {
  const _HighlightPicker({
    required this.selected,
    required this.from,
    required this.to,
    required this.onChanged,
  });
  final List<String> selected;
  final DateTime from, to;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries =
        [
          for (final r
              in ref
                      .watch(trackerKindProvider(TrackerKind.journalEntry))
                      .value ??
                  const <TrackerRecord>[])
            if (!(r.occurredAt ?? r.createdAt).isBefore(from) &&
                (r.occurredAt ?? r.createdAt).isBefore(to))
              r,
        ]..sort(
          (a, b) => (a.occurredAt ?? a.createdAt).compareTo(
            b.occurredAt ?? b.createdAt,
          ),
        );
    if (entries.isEmpty)
      return Text(
        'No journal entries in this period to feature.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    return PrismSurface(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (final r in entries.take(40))
            CheckboxListTile(
              dense: true,
              value: selected.contains(r.id),
              title: Text(
                r.title.isEmpty ? 'Journal entry' : r.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                DateFormat.MMMd().format(r.occurredAt ?? r.createdAt),
              ),
              onChanged: (v) {
                v == true ? selected.add(r.id) : selected.remove(r.id);
                onChanged();
              },
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Player

/// Full-screen story: tap right for next, left for back, hold to pause.
class WrapPlayerScreen extends ConsumerStatefulWidget {
  const WrapPlayerScreen({
    super.key,
    required this.cards,
    required this.style,
    this.title = '',
    this.snapshotId,
    this.offerStudio = false,
  });
  WrapPlayerScreen.snapshot(
    WrapSnapshot s, {
    Key? key,
    bool offerStudio = false,
  }) : this(
         key: key,
         cards: s.style.arrange(s.cards),
         style: s.style,
         title: s.title,
         snapshotId: s.id,
         offerStudio: offerStudio,
       );
  final List<WrapCard> cards;
  final WrapStyle style;
  final String title;
  final String? snapshotId;
  final bool offerStudio;
  @override
  ConsumerState<WrapPlayerScreen> createState() => _WrapPlayerScreenState();
}

class _WrapPlayerScreenState extends ConsumerState<WrapPlayerScreen>
    with TickerProviderStateMixin {
  int _i = 0;
  late final AnimationController _progress;
  late final AnimationController _enter;
  final _sound = TonePlayer();
  bool _muted = false;

  WrapStyle get _style {
    final id = widget.snapshotId;
    if (id == null) return widget.style;
    return ref
            .watch(wrapSnapshotsProvider)
            .where((s) => s.id == id)
            .firstOrNull
            ?.style ??
        widget.style;
  }

  @override
  void initState() {
    super.initState();
    final per = Duration(milliseconds: (6500 / widget.style.speed).round());
    _progress = AnimationController(vsync: this, duration: per)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _next();
      });
    _enter = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (1100 / widget.style.speed).round()),
    );
    _start();
    if (widget.style.music != 'none' &&
        ambienceCatalog.any((a) => a.id == widget.style.music)) {
      unawaited(_sound.loop(widget.style.music, volume: 0.3));
    }
  }

  void _start() {
    final reduce = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    _enter.value = reduce ? 1 : 0;
    if (!reduce) _enter.forward();
    _progress.forward(from: 0);
  }

  void _next() {
    if (_i >= widget.cards.length - 1) {
      _progress.stop();
      return;
    }
    setState(() => _i++);
    _start();
  }

  void _prev() {
    if (_i == 0) {
      _start();
      return;
    }
    setState(() => _i--);
    _start();
  }

  @override
  void dispose() {
    _progress.dispose();
    _enter.dispose();
    _sound.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = _style;
    final mask = _maskFor(ref, style);
    if (widget.cards.isEmpty) {
      return PrismPageScaffold(
        topBar: const PrismTopBar(title: 'Recap', showBackButton: true),
        body: const Center(child: Text('This recap has no cards.')),
      );
    }
    final card = widget.cards[_i];
    final last = _i == widget.cards.length - 1;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: AnimatedBuilder(
                animation: _progress,
                builder: (context, _) => Row(
                  children: [
                    for (var k = 0; k < widget.cards.length; k++)
                      Expanded(
                        child: Container(
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: Colors.white24,
                          ),
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: k < _i
                                ? 1
                                : (k == _i ? _progress.value : 0),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(color: Colors.white70),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (style.music != 'none')
                  IconButton(
                    tooltip: _muted ? 'Sound on' : 'Sound off',
                    color: Colors.white,
                    icon: Icon(_muted ? Icons.volume_off : Icons.volume_up),
                    onPressed: () {
                      setState(() => _muted = !_muted);
                      _sound.setVolume(_muted ? 0 : 0.3);
                    },
                  ),
                if (widget.snapshotId != null)
                  IconButton(
                    tooltip: 'Export & share',
                    color: Colors.white,
                    icon: const Icon(Icons.ios_share),
                    onPressed: () {
                      _progress.stop();
                      pushPage<void>(
                        context,
                        WrapExportScreen(
                          snapshotId: widget.snapshotId!,
                          initialCard: card.id,
                        ),
                      );
                    },
                  ),
                IconButton(
                  tooltip: 'Close',
                  color: Colors.white,
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) {
                  final w = context.size?.width ?? 1;
                  d.localPosition.dx < w / 3 ? _prev() : _next();
                },
                onLongPressStart: (_) => _progress.stop(),
                onLongPressEnd: (_) => _progress.forward(),
                onHorizontalDragEnd: (d) {
                  if ((d.primaryVelocity ?? 0) < -200) _next();
                  if ((d.primaryVelocity ?? 0) > 200) _prev();
                },
                child: Semantics(
                  label:
                      'Card ${_i + 1} of ${widget.cards.length}: ${card.title}. Tap right for next, left for previous.',
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: AnimatedSwitcher(
                        duration: style.animation == 'none'
                            ? Duration.zero
                            : const Duration(milliseconds: 350),
                        transitionBuilder: (child, a) =>
                            switch (style.animation) {
                              'zoom' => ScaleTransition(
                                scale: Tween(begin: 0.92, end: 1.0).animate(a),
                                child: FadeTransition(opacity: a, child: child),
                              ),
                              'slide' => SlideTransition(
                                position: Tween(
                                  begin: const Offset(0.08, 0),
                                  end: Offset.zero,
                                ).animate(a),
                                child: FadeTransition(opacity: a, child: child),
                              ),
                              _ => FadeTransition(opacity: a, child: child),
                            },
                        child: AnimatedBuilder(
                          key: ValueKey(card.id),
                          animation: _enter,
                          builder: (context, _) => WrapCardView(
                            card: card,
                            style: style,
                            t: _enter.value,
                            mask: mask,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (last)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    PrismButton(
                      label: 'Replay',
                      icon: Icons.replay,
                      onPressed: () => setState(() {
                        _i = 0;
                        _start();
                      }),
                    ),
                    if (widget.snapshotId != null)
                      PrismButton(
                        label: 'Edit',
                        icon: Icons.edit_outlined,
                        onPressed: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) => WrapStudioScreen(
                              snapshotId: widget.snapshotId!,
                            ),
                          ),
                        ),
                      ),
                    if (widget.snapshotId != null)
                      PrismButton(
                        label: 'Share',
                        icon: Icons.ios_share,
                        tone: PrismButtonTone.filled,
                        onPressed: () => pushPage<void>(
                          context,
                          WrapExportScreen(snapshotId: widget.snapshotId!),
                        ),
                      ),
                  ],
                ),
              )
            else if (widget.offerStudio && _i == 0 && widget.snapshotId != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: PrismButton(
                  label: 'Customize',
                  icon: Icons.palette_outlined,
                  density: PrismControlDensity.compact,
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          WrapStudioScreen(snapshotId: widget.snapshotId!),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Studio

/// Restyle, reorder, rewrite and correct a saved recap.
class WrapStudioScreen extends ConsumerStatefulWidget {
  const WrapStudioScreen({super.key, required this.snapshotId});
  final String snapshotId;
  @override
  ConsumerState<WrapStudioScreen> createState() => _WrapStudioScreenState();
}

class _WrapStudioScreenState extends ConsumerState<WrapStudioScreen> {
  String? _preview;
  bool _busy = false;

  WrapSnapshot? get _s => ref
      .watch(wrapSnapshotsProvider)
      .where((s) => s.id == widget.snapshotId)
      .firstOrNull;
  WrapActions get _a => ref.read(wrapActionsProvider);

  Future<void> _style(WrapSnapshot s, WrapStyle st) =>
      _a.update(s, {'style': st.toJson()});

  Future<void> _editCard(WrapSnapshot s, WrapCard c) async {
    final title = TextEditingController(text: c.title);
    final headline = TextEditingController(text: c.headline);
    final subtitle = TextEditingController(text: c.subtitle);
    final note = TextEditingController(text: c.note);
    final ok = await PrismDialog.show<bool>(
      context: context,
      title: 'Edit card',
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: title,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          TextField(
            controller: headline,
            decoration: const InputDecoration(labelText: 'Big line'),
          ),
          TextField(
            controller: subtitle,
            decoration: const InputDecoration(labelText: 'Subtitle'),
          ),
          TextField(
            controller: note,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Note'),
          ),
        ],
      ),
      actions: [
        PrismButton(
          label: 'Cancel',
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(false),
        ),
        PrismButton(
          label: 'Save',
          tone: PrismButtonTone.filled,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
        ),
      ],
    );
    if (ok != true) return;
    final cards = [
      for (final x in s.cards)
        if (x.id == c.id)
          WrapCard(
            id: x.id,
            kind: x.kind,
            title: title.text,
            headline: headline.text,
            subtitle: subtitle.text,
            items: x.items,
            chart: x.chart,
            refs: x.refs,
            note: note.text,
          )
        else
          x,
    ];
    await _a.update(s, {
      'cards': [for (final x in cards) x.toJson()],
    });
  }

  Future<void> _regenerate(WrapSnapshot s) async {
    final ok = await PrismDialog.confirm(
      context: context,
      title: 'Regenerate from current data?',
      message:
          'Cards are rebuilt from what\'s recorded now, including attribution corrections. Your style stays; text edits to cards are replaced.',
      confirmLabel: 'Regenerate',
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      final cards = await _a.generate(
        from: s.from,
        to: s.to,
        scope: s.scope,
        categories: s.categories,
        highlights: s.highlights,
        title: s.title,
        attribution: s.attribution,
      );
      await _a.update(s, {
        'cards': [for (final c in cards) c.toJson()],
      });
      if (mounted) PrismToast.show(context, message: 'Recap regenerated');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    if (s == null)
      return const PrismPageScaffold(
        topBar: PrismTopBar(title: 'Studio', showBackButton: true),
        body: Center(child: Text('This recap was deleted.')),
      );
    final st = s.style;
    final ordered = [
      ...st.arrange(s.cards),
      for (final c in s.cards)
        if (st.removed.contains(c.id)) c,
    ];
    final visible = st.arrange(s.cards);
    final preview =
        visible.where((c) => c.id == _preview).firstOrNull ??
        visible.firstOrNull;
    final theme = Theme.of(context);
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: 'Studio',
        showBackButton: true,
        actions: [
          IconButton(
            tooltip: 'Play',
            icon: const Icon(Icons.play_arrow),
            onPressed: () =>
                pushPage<void>(context, WrapPlayerScreen.snapshot(s)),
          ),
          IconButton(
            tooltip: 'Export & share',
            icon: const Icon(Icons.ios_share),
            onPressed: () =>
                pushPage<void>(context, WrapExportScreen(snapshotId: s.id)),
          ),
        ],
      ),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + NavBarInset.of(context)),
          children: [
            if (preview != null)
              Center(
                child: SizedBox(
                  width: 230,
                  child: WrapCardView(
                    card: preview,
                    style: st,
                    mask: _maskFor(ref, st),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            PrismListRow(
              title: Text(s.title),
              subtitle: Text('${s.period.label} · ${_range(s.from, s.to)}'),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () async {
                final t = await _askText(context, 'Recap title', s.title);
                if (t != null && t.trim().isNotEmpty)
                  await _a.update(s, const {}, title: t.trim());
              },
            ),
            PrismSectionHeader(title: 'CARDS'),
            Text(
              'Drag to reorder. Tap a card to preview it.',
              style: theme.textTheme.bodySmall,
            ),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorder: (a, b) {
                final ids = [for (final c in ordered) c.id];
                final id = ids.removeAt(a);
                ids.insert(b > a ? b - 1 : b, id);
                _style(s, st.copyWith(order: ids));
              },
              children: [
                for (var k = 0; k < ordered.length; k++)
                  PrismListRow(
                    key: ValueKey(ordered[k].id),
                    dense: true,
                    selected: preview?.id == ordered[k].id,
                    leading: ReorderableDragStartListener(
                      index: k,
                      child: const Icon(Icons.drag_indicator),
                    ),
                    title: Text(
                      ordered[k].title.isEmpty
                          ? ordered[k].kind
                          : ordered[k].title,
                      style: st.removed.contains(ordered[k].id)
                          ? const TextStyle(
                              decoration: TextDecoration.lineThrough,
                            )
                          : null,
                    ),
                    onTap: () => setState(() => _preview = ordered[k].id),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit text',
                          icon: const Icon(Icons.edit_note),
                          onPressed: () => _editCard(s, ordered[k]),
                        ),
                        IconButton(
                          tooltip: st.removed.contains(ordered[k].id)
                              ? 'Show card'
                              : 'Hide card',
                          icon: Icon(
                            st.removed.contains(ordered[k].id)
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () => _style(
                            s,
                            st.copyWith(
                              removed: st.removed.contains(ordered[k].id)
                                  ? ({...st.removed}..remove(ordered[k].id))
                                  : {...st.removed, ordered[k].id},
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            PrismSectionHeader(title: 'LOOK'),
            _chips(
              'Style',
              wrapStyles,
              st.style,
              (v) => _style(s, st.copyWith(style: v)),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Accent colour',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (st.accent != null)
                  PrismButton(
                    label: 'Reset',
                    density: PrismControlDensity.compact,
                    onPressed: () => _style(s, st.copyWith(clearAccent: true)),
                  ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    final c = await showPrismColorPicker(
                      context: context,
                      initial: st.accent == null
                          ? theme.colorScheme.primary
                          : Color(st.accent!),
                    );
                    if (c != null)
                      await _style(s, st.copyWith(accent: c.toARGB32()));
                  },
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: st.accent == null
                        ? theme.colorScheme.primary
                        : Color(st.accent!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _chips(
              'Font',
              const {
                'sans': 'Your font',
                'serif': 'Serif',
                'mono': 'Typewriter',
              },
              st.font,
              (v) => _style(s, st.copyWith(font: v)),
            ),
            _chips(
              'Shape',
              const {
                'story': 'Story 9:16',
                'portrait': 'Portrait 4:5',
                'square': 'Square',
              },
              st.aspect,
              (v) => _style(s, st.copyWith(aspect: v)),
            ),
            PrismSectionHeader(title: 'MOTION & SOUND'),
            _chips(
              'Animation',
              const {
                'slide': 'Slide',
                'fade': 'Fade',
                'zoom': 'Zoom',
                'none': 'None',
              },
              st.animation,
              (v) => _style(s, st.copyWith(animation: v)),
            ),
            Row(
              children: [
                Text('Speed', style: theme.textTheme.titleSmall),
                Expanded(
                  child: Slider(
                    value: st.speed,
                    min: 0.5,
                    max: 2,
                    divisions: 6,
                    label: '${st.speed}×',
                    onChanged: (v) => _style(s, st.copyWith(speed: v)),
                  ),
                ),
              ],
            ),
            _chips(
              'Background sound',
              {
                'none': 'None',
                for (final a in ambienceCatalog) a.id: '${a.emoji} ${a.label}',
              },
              st.music,
              (v) => _style(s, st.copyWith(music: v)),
            ),
            PrismSurface(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  PrismSwitchRow(
                    title: 'Effects',
                    subtitle: 'Confetti, sparkles and moving figures',
                    value: st.effects,
                    onChanged: (v) => _style(s, st.copyWith(effects: v)),
                  ),
                  PrismSwitchRow(
                    title: 'Hide names',
                    subtitle: 'For sharing — names become •••',
                    value: st.hideNames,
                    onChanged: (v) => _style(s, st.copyWith(hideNames: v)),
                  ),
                  PrismSwitchRow(
                    title: 'Hide numbers',
                    value: st.hideNumbers,
                    onChanged: (v) => _style(s, st.copyWith(hideNumbers: v)),
                  ),
                ],
              ),
            ),
            PrismSectionHeader(title: 'CONTENT'),
            PrismSurface(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  PrismListRow(
                    leading: const Icon(Icons.person_search_outlined),
                    title: const Text('Correct attribution'),
                    subtitle: Text(
                      s.attribution.isEmpty
                          ? 'Fix who did what, or leave things out'
                          : '${s.attribution.length} correction${s.attribution.length == 1 ? '' : 's'}',
                    ),
                    showChevron: true,
                    onTap: () => pushPage<void>(
                      context,
                      WrapAttributionScreen(snapshotId: s.id),
                    ),
                  ),
                  PrismListRow(
                    leading: const Icon(Icons.star_outline),
                    title: const Text('Highlights'),
                    subtitle: Text(
                      s.highlights.isEmpty
                          ? 'Feature journal moments you choose'
                          : '${s.highlights.length} chosen',
                    ),
                    showChevron: true,
                    onTap: () async {
                      final picks = [...s.highlights];
                      await PrismSheet.show<void>(
                        context: context,
                        title: 'Highlights',
                        builder: (_) => StatefulBuilder(
                          builder: (ctx, set) => SingleChildScrollView(
                            child: _HighlightPicker(
                              selected: picks,
                              from: s.from,
                              to: s.to,
                              onChanged: () => set(() {}),
                            ),
                          ),
                        ),
                      );
                      await _a.update(s, {
                        'highlights': picks,
                        'categories': {
                          ...s.categories,
                          if (picks.isNotEmpty) 'highlights',
                        }.toList(),
                      });
                      if (mounted)
                        PrismToast.show(
                          context,
                          message: 'Saved — regenerate to update the cards',
                        );
                    },
                  ),
                  PrismListRow(
                    leading: const Icon(Icons.refresh),
                    title: const Text('Regenerate from current data'),
                    subtitle: const Text(
                      'Rebuild cards with corrections and highlights',
                    ),
                    enabled: !_busy,
                    onTap: () => _regenerate(s),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chips(
    String label,
    Map<String, String> options,
    String value,
    ValueChanged<String> pick,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final e in options.entries)
              PrismChip(
                label: e.value,
                selected: e.key == value,
                onTap: () => pick(e.key),
              ),
          ],
        ),
      ],
    ),
  );
}

/// Reassign recorded things to the right headmate — or leave them out —
/// before regenerating. Corrections only affect this recap.
class WrapAttributionScreen extends ConsumerStatefulWidget {
  const WrapAttributionScreen({super.key, required this.snapshotId});
  final String snapshotId;
  @override
  ConsumerState<WrapAttributionScreen> createState() =>
      _WrapAttributionScreenState();
}

class _WrapAttributionScreenState extends ConsumerState<WrapAttributionScreen> {
  Map<String, String>? _fix;

  @override
  Widget build(BuildContext context) {
    final s = ref
        .watch(wrapSnapshotsProvider)
        .where((x) => x.id == widget.snapshotId)
        .firstOrNull;
    if (s == null) return const SizedBox.shrink();
    final fix = _fix ??= {...s.attribution};
    final names = ref.watch(memberNamesProvider);
    final items = [
      for (final i in ref.watch(wrapItemsProvider))
        if (!i.at.isBefore(s.from) && i.at.isBefore(s.to) && i.kind != 'track')
          i,
    ]..sort((a, b) => b.at.compareTo(a.at));
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: 'Correct attribution',
        showBackButton: true,
        actions: [
          PrismButton(
            label: 'Save',
            density: PrismControlDensity.compact,
            tone: PrismButtonTone.filled,
            onPressed: () async {
              await ref.read(wrapActionsProvider).update(s, {
                'attribution': fix,
              });
              if (!context.mounted) return;
              PrismToast.show(
                context,
                message: 'Saved — regenerate to update the cards',
              );
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: items.isEmpty
            ? const Center(child: Text('Nothing recorded in this period.'))
            : ListView.builder(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  32 + NavBarInset.of(context),
                ),
                itemCount: items.length,
                itemBuilder: (context, k) {
                  final i = items[k];
                  final cur = fix[i.id];
                  final who = cur == ''
                      ? 'Left out'
                      : names[cur ?? i.memberId] ?? 'No one in particular';
                  return PrismListRow(
                    dense: true,
                    title: Text(
                      i.title.isEmpty ? i.kind : i.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${i.kind} · ${DateFormat.MMMd().format(i.at)} · $who${cur != null ? ' (corrected)' : ''}',
                    ),
                    trailing: PrismPopupMenu<String>(
                      tooltip: 'Change',
                      icon: Icons.swap_horiz,
                      onSelected: (v) => setState(() {
                        if (v == '_reset') {
                          fix.remove(i.id);
                        } else {
                          fix[i.id] = v;
                        }
                      }),
                      items: [
                        for (final e in names.entries)
                          PrismMenuItem(
                            value: e.key,
                            label: e.value,
                            icon: Icons.person_outline,
                          ),
                        PrismMenuItem(
                          value: '',
                          label: 'Leave this out',
                          icon: Icons.block,
                        ),
                        if (cur != null)
                          PrismMenuItem(
                            value: '_reset',
                            label: 'Undo correction',
                            icon: Icons.undo,
                          ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Export

/// Save recap cards as images or a PDF, post them to the Bulletin Board or
/// add them to a passport. Nothing leaves the device unless you choose.
class WrapExportScreen extends ConsumerStatefulWidget {
  const WrapExportScreen({
    super.key,
    required this.snapshotId,
    this.initialCard,
  });
  final String snapshotId;
  final String? initialCard;
  @override
  ConsumerState<WrapExportScreen> createState() => _WrapExportScreenState();
}

class _WrapExportScreenState extends ConsumerState<WrapExportScreen> {
  final Map<String, GlobalKey> _keys = {};
  Set<String>? _picked;
  bool? _hideNames;
  bool? _hideNumbers;
  bool _busy = false;

  Future<void> _run(Future<void> Function() f) async {
    setState(() => _busy = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      await f();
    } catch (e) {
      if (mounted) PrismToast.show(context, message: 'Export failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<List<Uint8List>> _images(List<WrapCard> cards) async => [
    for (final c in cards)
      if (_picked!.contains(c.id))
        ?await captureBoundary(_keys[c.id]!, pixelRatio: 3),
  ];

  @override
  Widget build(BuildContext context) {
    final s = ref
        .watch(wrapSnapshotsProvider)
        .where((x) => x.id == widget.snapshotId)
        .firstOrNull;
    if (s == null) return const SizedBox.shrink();
    final cards = s.style.arrange(s.cards);
    _picked ??= widget.initialCard != null
        ? {widget.initialCard!}
        : {for (final c in cards) c.id};
    final style = s.style.copyWith(
      hideNames: _hideNames ?? s.style.hideNames,
      hideNumbers: _hideNumbers ?? s.style.hideNumbers,
    );
    final mask = _maskFor(ref, style);
    for (final c in cards) {
      _keys.putIfAbsent(c.id, GlobalKey.new);
    }
    final slug = s.title.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '-');
    final picked = _picked!;
    final none = picked.isEmpty;
    return PrismPageScaffold(
      topBar: const PrismTopBar(title: 'Export & share', showBackButton: true),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + NavBarInset.of(context)),
          children: [
            PrismSectionHeader(title: 'PRIVACY REVIEW'),
            PrismSurface(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  PrismSwitchRow(
                    title: 'Hide names',
                    subtitle: 'Headmates, subsystems and companions become •••',
                    value: style.hideNames,
                    onChanged: (v) => setState(() => _hideNames = v),
                  ),
                  PrismSwitchRow(
                    title: 'Hide numbers',
                    value: style.hideNumbers,
                    onChanged: (v) => setState(() => _hideNumbers = v),
                  ),
                ],
              ),
            ),
            PrismSectionHeader(
              title: 'SHARE ${picked.length} OF ${cards.length} CARDS',
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PrismButton(
                  label: 'Save as images',
                  icon: Icons.image_outlined,
                  enabled: !none && !_busy,
                  onPressed: () => _run(() async {
                    final imgs = await _images(cards);
                    var n = 0;
                    for (var k = 0; k < imgs.length; k++) {
                      if (await saveImageBytes(ref, imgs[k], '$slug-${k + 1}'))
                        n++;
                    }
                    if (mounted)
                      PrismToast.show(
                        context,
                        message: n == 0
                            ? 'Nothing saved'
                            : 'Saved $n image${n == 1 ? '' : 's'}',
                      );
                  }),
                ),
                PrismButton(
                  label: 'Save as PDF',
                  icon: Icons.picture_as_pdf_outlined,
                  enabled: !none && !_busy,
                  onPressed: () => _run(() async {
                    final pdf = await imagesToPdf(
                      await _images(cards),
                      title: s.title,
                    );
                    final ok = await savePdfBytes(ref, pdf, slug);
                    if (mounted)
                      PrismToast.show(
                        context,
                        message: ok ? 'PDF saved' : 'Not saved',
                      );
                  }),
                ),
                PrismButton(
                  label: 'Post to Bulletin Board',
                  icon: Icons.push_pin_outlined,
                  enabled: !none && !_busy,
                  onPressed: () => _run(() async {
                    final actor = currentFronterId(ref);
                    if (actor == null) {
                      PrismToast.show(
                        context,
                        message:
                            'Set who\'s fronting first — posts need an author.',
                      );
                      return;
                    }
                    final ids = [
                      for (final img in await _images(cards))
                        ?await storeImage(ref, img, owner: actor),
                    ];
                    if (ids.isEmpty) return;
                    await ref
                        .read(socialActionsProvider)
                        .createPost(
                          actor: actor,
                          type: PostType.image,
                          title: s.title,
                          images: ids,
                          tags: const ['wrapped'],
                        );
                    if (mounted)
                      PrismToast.show(
                        context,
                        message: 'Posted to the Bulletin Board',
                      );
                  }),
                ),
                PrismButton(
                  label: 'Add to a passport',
                  icon: Icons.approval_outlined,
                  enabled: !none && !_busy,
                  onPressed: () => _run(() async {
                    final id = await pickPassport(
                      context,
                      ref,
                      title: 'Add recap to…',
                    );
                    if (id == null) return;
                    final imgs = await _images(cards);
                    final actions = ref.read(passportActionsProvider);
                    final page = await actions.addPage(
                      id,
                      'photos',
                      title: s.title,
                    );
                    for (var k = 0; k < imgs.length; k++) {
                      final media = await storeImage(ref, imgs[k]);
                      if (media == null) continue;
                      await actions.addElement(
                        page.id,
                        'photo',
                        media: media,
                        x: 0.25 + 0.5 * (k % 2),
                        y: 0.2 + 0.3 * ((k ~/ 2) % 3),
                        scale: 0.9,
                        rotation: (k.isEven ? -0.04 : 0.05),
                      );
                    }
                    if (mounted)
                      PrismToast.show(
                        context,
                        message: 'Added a page to the passport',
                      );
                  }),
                ),
              ],
            ),
            const SizedBox(height: 6),
            PrismListRow(
              dense: true,
              enabled: false,
              leading: const Icon(Icons.movie_outlined),
              title: const Text('Video export'),
              subtitle: const Text(
                'Not available yet — save images or a PDF for now.',
              ),
            ),
            PrismSectionHeader(title: 'CARDS'),
            Wrap(
              spacing: 8,
              children: [
                PrismButton(
                  label: 'Select all',
                  density: PrismControlDensity.compact,
                  onPressed: () =>
                      setState(() => _picked = {for (final c in cards) c.id}),
                ),
                PrismButton(
                  label: 'Select none',
                  density: PrismControlDensity.compact,
                  onPressed: () => setState(() => _picked = {}),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final c in cards)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    CheckboxListTile(
                      dense: true,
                      value: picked.contains(c.id),
                      title: Text(c.title.isEmpty ? c.kind : c.title),
                      onChanged: (v) => setState(
                        () =>
                            v == true ? picked.add(c.id) : picked.remove(c.id),
                      ),
                    ),
                    Center(
                      child: SizedBox(
                        width: 300,
                        child: RepaintBoundary(
                          key: _keys[c.id],
                          child: WrapCardView(
                            card: c,
                            style: style,
                            mask: mask,
                            animateFigures: false,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Settings

class WrapSettingsScreen extends ConsumerWidget {
  const WrapSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seasons = ref.watch(wrapSettingsProvider).seasons;
    const months = [
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
    return PrismPageScaffold(
      topBar: const PrismTopBar(title: 'Season dates', showBackButton: true),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'When each season starts, for seasonal recaps. Change these if your seasons differ (for example in the southern hemisphere).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            for (final name in ['spring', 'summer', 'autumn', 'winter'])
              PrismListRow(
                title: Text('${name[0].toUpperCase()}${name.substring(1)}'),
                trailing: PrismSelect<int>.compact(
                  value: seasons[name] ?? defaultSeasonStarts[name],
                  items: [
                    for (var m = 1; m <= 12; m++)
                      PrismSelectItem(value: m, label: months[m - 1]),
                  ],
                  onChanged: (v) {
                    if (v != null)
                      ref.read(wrapActionsProvider).saveSeasons({
                        ...seasons,
                        name: v,
                      });
                  },
                ),
              ),
            const SizedBox(height: 12),
            PrismButton(
              label: 'Southern hemisphere',
              onPressed: () => ref.read(wrapActionsProvider).saveSeasons(const {
                'spring': 9,
                'summer': 12,
                'autumn': 3,
                'winter': 6,
              }),
            ),
            const SizedBox(height: 8),
            PrismButton(
              label: 'Reset',
              onPressed: () => ref
                  .read(wrapActionsProvider)
                  .saveSeasons(defaultSeasonStarts),
            ),
          ],
        ),
      ),
    );
  }
}
