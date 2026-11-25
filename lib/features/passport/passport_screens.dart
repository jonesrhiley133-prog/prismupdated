import 'dart:async';

import 'package:prism_plurality/features/companions/companion_data.dart';
import 'package:prism_plurality/features/companions/companion_screens.dart'
    show memberNamesProvider, pushPage;
import 'package:prism_plurality/features/experiences/color_sheet.dart';
import 'package:prism_plurality/features/passport/passport_book.dart';
import 'package:prism_plurality/features/passport/passport_data.dart';
import 'package:prism_plurality/features/passport/passport_export.dart';
import 'package:prism_plurality/features/passport/passport_widgets.dart';
import 'package:prism_plurality/features/passport/stamp_art.dart';
import 'package:prism_plurality/features/subsystems/hub/subsystem_data.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// All passports, shown by their covers.
class PassportLibraryScreen extends ConsumerStatefulWidget {
  const PassportLibraryScreen({super.key, this.ownerFilter});

  /// Show only passports this member owns (from a headmate profile).
  final String? ownerFilter;
  @override
  ConsumerState<PassportLibraryScreen> createState() =>
      _PassportLibraryScreenState();
}

class _PassportLibraryScreenState extends ConsumerState<PassportLibraryScreen> {
  final _search = TextEditingController();
  String _filter = 'all';
  late String? _owner = widget.ownerFilter;
  String? _folder;
  bool _arranging = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(passportsProvider);
    final settings = ref.watch(passportSettingsProvider);
    final suggestions = ref.watch(stampSuggestionsProvider);
    final names = ref.watch(memberNamesProvider);
    final theme = Theme.of(context);
    final q = _search.text.trim().toLowerCase();
    final fronter = currentFronterId(ref);
    var list = all.where((p) {
      if (!passportVisibleTo(p, fronter)) return false;
      if (_filter == 'archived' ? !p.archived : p.archived) return false;
      if (_filter == 'favorites' && !p.favorite) return false;
      if (_owner != null &&
          !(p.owners.contains(_owner) || p.ownerType == OwnerType.system))
        return false;
      if (_folder != null && p.folder != _folder) return false;
      if (q.isNotEmpty &&
          !'${p.name} ${p.subtitle} ${passportTypes[p.type]?.$1}'
              .toLowerCase()
              .contains(q))
        return false;
      return true;
    }).toList();
    if (_filter == 'recent') {
      list = list.where((p) => p.lastOpened != null).toList()
        ..sort((a, b) => b.lastOpened!.compareTo(a.lastOpened!));
    } else {
      list.sort(
        (a, b) => a.pinned != b.pinned
            ? (a.pinned ? -1 : 1)
            : a.order.compareTo(b.order),
      );
    }
    final folders = {
      ...settings.folders,
      for (final p in all)
        if (p.folder.isNotEmpty) p.folder,
    }.toList()..sort();
    final shelf = settings.view == 'shelf';
    final actions = ref.read(passportActionsProvider);

    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: 'Passports',
        showBackButton: true,
        actions: [
          PrismTopBarAction(
            icon: shelf ? Icons.grid_view : Icons.view_week_outlined,
            tooltip: shelf ? 'Grid view' : 'Bookshelf view',
            onPressed: () => actions.saveSettings(
              settings.copyWith(view: shelf ? 'grid' : 'shelf'),
            ),
          ),
          PrismTopBarAction(
            icon: Icons.tune,
            tooltip: 'Passport settings',
            onPressed: () =>
                pushPage<void>(context, const PassportSettingsScreen()),
          ),
          PrismTopBarAction(
            icon: Icons.add,
            tooltip: 'New passport',
            onPressed: () =>
                pushPage<void>(context, const PassportEditorScreen()),
          ),
        ],
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + NavBarInset.of(context)),
          children: [
            if (all.isEmpty) ...[
              const SizedBox(height: 12),
              Center(
                child: PassportCoverView(
                  cover: passportTemplates['classic']!.$2,
                  name: 'Your first passport',
                  width: 170,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'A souvenir book for your experiences',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Collect stamps for birthdays, game nights, trips, new companions and anything you want to remember. Achievements celebrate what you did — passports keep what you lived.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              PrismButton(
                label: 'Create a passport',
                icon: Icons.add,
                tone: PrismButtonTone.filled,
                expanded: true,
                onPressed: () =>
                    pushPage<void>(context, const PassportEditorScreen()),
              ),
              const SizedBox(height: 8),
              PrismButton(
                label: 'Import a passport file',
                icon: Icons.file_open_outlined,
                expanded: true,
                onPressed: () => importPassportFile(context, ref),
              ),
            ] else ...[
              PrismTextField(
                controller: _search,
                hintText: 'Search passports',
                prefixIcon: const Icon(Icons.search),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final (k, l) in const [
                      ('all', 'All'),
                      ('favorites', 'Favourites'),
                      ('recent', 'Recently opened'),
                      ('archived', 'Archived'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: PrismChip(
                          label: l,
                          selected: _filter == k,
                          onTap: () => setState(() => _filter = k),
                        ),
                      ),
                    if (names.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: PrismChip(
                          label: _owner == null
                              ? 'Any owner'
                              : 'Owner: ${names[_owner] ?? '?'}',
                          selected: _owner != null,
                          onTap: () => _pickOwner(context, names),
                        ),
                      ),
                    for (final f in folders)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: PrismChip(
                          label: '📁 $f',
                          selected: _folder == f,
                          onTap: () =>
                              setState(() => _folder = _folder == f ? null : f),
                        ),
                      ),
                  ],
                ),
              ),
              if (suggestions.isNotEmpty) ...[
                const SizedBox(height: 14),
                _SuggestionStrip(suggestions: suggestions),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _filter == 'archived' ? 'Archived' : 'Your passports',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (_filter != 'recent')
                    PrismButton(
                      label: _arranging ? 'Done' : 'Arrange',
                      density: PrismControlDensity.compact,
                      onPressed: () => setState(() => _arranging = !_arranging),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'No passports here.',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              if (_arranging)
                for (final (i, p) in list.indexed)
                  PrismListRow(
                    leading: SizedBox(
                      width: 36,
                      child: PassportCoverView(
                        cover: p.cover,
                        name: '',
                        width: 36,
                      ),
                    ),
                    title: Text(p.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Move up',
                          icon: const Icon(Icons.arrow_upward),
                          onPressed: i == 0
                              ? null
                              : () => _swap(list, i, i - 1),
                        ),
                        IconButton(
                          tooltip: 'Move down',
                          icon: const Icon(Icons.arrow_downward),
                          onPressed: i == list.length - 1
                              ? null
                              : () => _swap(list, i, i + 1),
                        ),
                      ],
                    ),
                  )
              else if (shelf)
                _Bookshelf(passports: list)
              else
                LayoutBuilder(
                  builder: (context, box) {
                    final cols = (box.maxWidth / 170).floor().clamp(2, 6);
                    final w = (box.maxWidth - 14 * (cols - 1)) / cols;
                    return Wrap(
                      spacing: 14,
                      runSpacing: 18,
                      children: [
                        for (final p in list)
                          SizedBox(
                            width: w,
                            child: _CoverTile(passport: p, width: w),
                          ),
                      ],
                    );
                  },
                ),
              const SizedBox(height: 16),
              PrismButton(
                label: 'Import a passport file',
                icon: Icons.file_open_outlined,
                onPressed: () => importPassportFile(context, ref),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _swap(List<Passport> list, int a, int b) async {
    final actions = ref.read(passportActionsProvider);
    final ordered = [...list];
    final x = ordered.removeAt(a);
    ordered.insert(b, x);
    for (final (i, p) in ordered.indexed) {
      if (p.order != i) await actions.save(p, const {}, order: i);
    }
  }

  Future<void> _pickOwner(
    BuildContext context,
    Map<String, String> names,
  ) async {
    final pick = await PrismSheet.show<String>(
      context: context,
      title: 'Show passports of…',
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          PrismListRow(
            title: const Text('Anyone'),
            onTap: () => Navigator.of(ctx).pop(''),
          ),
          for (final e in names.entries)
            PrismListRow(
              title: Text(e.value),
              onTap: () => Navigator.of(ctx).pop(e.key),
            ),
        ],
      ),
    );
    if (pick != null) setState(() => _owner = pick.isEmpty ? null : pick);
  }
}

class _CoverTile extends ConsumerWidget {
  const _CoverTile({required this.passport, required this.width});
  final Passport passport;
  final double width;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stamps = ref.watch(passportStampsProvider(passport.id)).length;
    return Semantics(
      button: true,
      label:
          '${passport.name}, $stamps stamps${passport.pinned ? ', pinned' : ''}${passport.favorite ? ', favourite' : ''}',
      child: GestureDetector(
        onTap: () => openPassport(context, ref, passport),
        onLongPress: () => passportMenu(context, ref, passport),
        child: Column(
          children: [
            ExcludeSemantics(
              child: PassportCoverView(
                cover: passport.cover,
                name: passport.name,
                subtitle: passport.subtitle,
                width: width * 0.88,
                badge: passport.pinned || passport.favorite
                    ? Text(
                        passport.pinned ? '📌' : '⭐',
                        style: const TextStyle(fontSize: 16),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    '${passportTypes[passport.type]?.$2 ?? ''} $stamps stamp${stamps == 1 ? '' : 's'}',
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Options for ${passport.name}',
                  icon: const Icon(Icons.more_horiz, size: 18),
                  onPressed: () => passportMenu(context, ref, passport),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Bookshelf extends ConsumerWidget {
  const _Bookshelf({required this.passports});
  final List<Passport> passports;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        final perShelf = (box.maxWidth / 54).floor().clamp(4, 20);
        final rows = <List<Passport>>[];
        for (var i = 0; i < passports.length; i += perShelf) {
          rows.add(
            passports.sublist(i, (i + perShelf).clamp(0, passports.length)),
          );
        }
        return Column(
          children: [
            for (final row in rows)
              Column(
                children: [
                  SizedBox(
                    height: 190,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final p in row)
                          Semantics(
                            button: true,
                            label: p.name,
                            child: GestureDetector(
                              onTap: () => openPassport(context, ref, p),
                              onLongPress: () => passportMenu(context, ref, p),
                              child: Container(
                                width: 46,
                                height: 150 + (p.name.length % 4) * 10,
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: Color(p.cover.primary),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Color(
                                      p.cover.secondary,
                                    ).withValues(alpha: 0.6),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    const SizedBox(height: 8),
                                    Text(
                                      p.cover.symbol,
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                    Expanded(
                                      child: RotatedBox(
                                        quarterTurns: 1,
                                        child: Center(
                                          child: Text(
                                            p.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Color(p.cover.secondary),
                                              fontWeight: FontWeight.w700,
                                              fontFamily: fontFamilyFor(
                                                p.cover.font,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (p.pinned)
                                      const Text(
                                        '📌',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    const SizedBox(height: 6),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _SuggestionStrip extends ConsumerWidget {
  const _SuggestionStrip({required this.suggestions});
  final List<StampSuggestion> suggestions;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return PrismSurface(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Stamp ideas', style: theme.textTheme.titleSmall),
          Text(
            'From recent moments. Nothing is added unless you choose it.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 150,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final s in suggestions.take(10))
                  Container(
                    width: 132,
                    margin: const EdgeInsets.only(right: 10),
                    child: Column(
                      children: [
                        StampView(design: s.design, size: 80),
                        Text(
                          s.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              tooltip: 'Not now',
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => ref
                                  .read(passportActionsProvider)
                                  .dismiss(s.key),
                            ),
                            IconButton(
                              tooltip: 'Add to a passport',
                              icon: const Icon(
                                Icons.add_circle_outline,
                                size: 20,
                              ),
                              onPressed: () =>
                                  acceptSuggestion(context, ref, s),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> acceptSuggestion(
  BuildContext context,
  WidgetRef ref,
  StampSuggestion s,
) async {
  final id = await pickPassport(context, ref, title: 'Add “${s.title}” to…');
  if (id == null) return;
  await ref.read(passportActionsProvider).accept(s, id);
  if (context.mounted) PrismToast.show(context, message: 'Stamp added');
}

/// Choose a passport (or make one). Returns its id.
Future<String?> pickPassport(
  BuildContext context,
  WidgetRef ref, {
  String title = 'Choose a passport',
}) async {
  final fronter = currentFronterId(ref);
  final list = [
    for (final p in ref.read(passportsProvider))
      if (!p.archived && passportVisibleTo(p, fronter)) p,
  ];
  if (list.length == 1) return list.first.id;
  final pick = await PrismSheet.show<String>(
    context: context,
    title: title,
    builder: (ctx) => ListView(
      shrinkWrap: true,
      children: [
        for (final p in list)
          PrismListRow(
            leading: SizedBox(
              width: 32,
              child: PassportCoverView(cover: p.cover, name: '', width: 32),
            ),
            title: Text(p.name),
            onTap: () => Navigator.of(ctx).pop(p.id),
          ),
        PrismListRow(
          leading: const Icon(Icons.add),
          title: const Text('A new passport'),
          onTap: () => Navigator.of(ctx).pop('__new'),
        ),
      ],
    ),
  );
  if (pick == '__new') {
    final rec = await ref
        .read(passportActionsProvider)
        .create(name: 'My passport');
    return rec.id;
  }
  return pick;
}

Future<void> openPassport(
  BuildContext context,
  WidgetRef ref,
  Passport p,
) async {
  unawaited(ref.read(passportActionsProvider).markOpened(p));
  await pushPage<void>(context, PassportBookScreen(passportId: p.id));
}

Future<void> passportMenu(
  BuildContext context,
  WidgetRef ref,
  Passport p,
) async {
  final actions = ref.read(passportActionsProvider);
  final pick = await PrismSheet.show<String>(
    context: context,
    title: p.name,
    builder: (ctx) => ListView(
      shrinkWrap: true,
      children: [
        PrismListRow(
          leading: const Icon(Icons.edit_outlined),
          title: const Text('Edit cover & details'),
          onTap: () => Navigator.of(ctx).pop('edit'),
        ),
        PrismListRow(
          leading: Icon(p.favorite ? Icons.star : Icons.star_border),
          title: Text(
            p.favorite ? 'Remove from favourites' : 'Add to favourites',
          ),
          onTap: () => Navigator.of(ctx).pop('fav'),
        ),
        PrismListRow(
          leading: const Icon(Icons.push_pin_outlined),
          title: Text(p.pinned ? 'Unpin' : 'Pin to top'),
          onTap: () => Navigator.of(ctx).pop('pin'),
        ),
        PrismListRow(
          leading: const Icon(Icons.folder_outlined),
          title: Text(
            p.folder.isEmpty ? 'Put in a folder' : 'Folder: ${p.folder}',
          ),
          onTap: () => Navigator.of(ctx).pop('folder'),
        ),
        PrismListRow(
          leading: const Icon(Icons.ios_share),
          title: const Text('Export'),
          onTap: () => Navigator.of(ctx).pop('export'),
        ),
        PrismListRow(
          leading: const Icon(Icons.archive_outlined),
          title: Text(p.archived ? 'Unarchive' : 'Archive'),
          onTap: () => Navigator.of(ctx).pop('archive'),
        ),
        PrismListRow(
          leading: const Icon(Icons.delete_outline),
          title: const Text('Delete'),
          destructive: true,
          onTap: () => Navigator.of(ctx).pop('delete'),
        ),
      ],
    ),
  );
  if (!context.mounted) return;
  switch (pick) {
    case 'edit':
      await pushPage<void>(context, PassportEditorScreen(passportId: p.id));
    case 'fav':
      await actions.save(p, {'favorite': !p.favorite});
    case 'pin':
      await actions.save(p, const {}, pinned: !p.pinned);
    case 'archive':
      await actions.save(p, {'archived': !p.archived});
    case 'export':
      await pushPage<void>(context, PassportExportScreen(passportId: p.id));
    case 'folder':
      final t = TextEditingController(text: p.folder);
      final ok = await PrismDialog.show<bool>(
        context: context,
        title: 'Folder',
        builder: (_) => PrismTextField(
          controller: t,
          hintText: 'e.g. Trips, 2026',
          autofocus: true,
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
            onPressed: () =>
                Navigator.of(context, rootNavigator: true).pop(true),
          ),
        ],
      );
      if (ok == true) await actions.save(p, {'folder': t.text.trim()});
      t.dispose();
    case 'delete':
      final ok = await PrismDialog.confirm(
        context: context,
        title: 'Delete ${p.name}?',
        message:
            'Its pages and stamps are deleted. Linked journal entries, photos and other records are not touched.',
        confirmLabel: 'Delete',
        destructive: true,
      );
      if (ok) await actions.delete(p);
  }
}

/// Create a passport, or edit an existing one's cover and details.
class PassportEditorScreen extends ConsumerStatefulWidget {
  const PassportEditorScreen({super.key, this.passportId});
  final String? passportId;
  @override
  ConsumerState<PassportEditorScreen> createState() =>
      _PassportEditorScreenState();
}

class _PassportEditorScreenState extends ConsumerState<PassportEditorScreen> {
  late final Passport? _p = widget.passportId == null
      ? null
      : ref.read(passportByIdProvider(widget.passportId!));
  late final _name = TextEditingController(text: _p?.name ?? '');
  late final _subtitle = TextEditingController(text: _p?.subtitle ?? '');
  late final _intro = TextEditingController(text: _p?.intro ?? '');
  late final _symbol = TextEditingController(text: _p?.cover.symbol ?? '🌍');
  late String _type = _p?.type ?? 'personal';
  late PassportCover _cover = _p?.cover ?? const PassportCover();
  late int _paper = _p?.paper ?? 0xFFFBF7EF;
  late String _texture = _p?.texture ?? 'plain';
  late String _transition = _p?.transition ?? 'flip';
  late bool _opening = _p?.openingAnimation ?? true;
  late String _visibility = _p?.visibility ?? 'system';
  late OwnerType _ownerType = _p?.ownerType ?? OwnerType.system;
  late List<String> _owners = [...?_p?.owners];

  @override
  void initState() {
    super.initState();
    if (_p == null) {
      final f = currentFronterId(ref);
      if (f != null) {
        _ownerType = OwnerType.member;
        _owners = [f];
      }
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _subtitle, _intro, _symbol]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final names = ref.watch(memberNamesProvider);
    final subs = ref.watch(subsystemsProvider);
    Widget chips(
      String label,
      List<String> values,
      String current,
      void Function(String) on, {
      String Function(String)? text,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final v in values)
                PrismChip(
                  label:
                      text?.call(v) ??
                      (v.isEmpty ? v : v[0].toUpperCase() + v.substring(1)),
                  selected: v == current,
                  onTap: () => setState(() => on(v)),
                ),
            ],
          ),
        ],
      ),
    );
    Widget colour(String label, Color c, void Function(Color) on) =>
        PrismListRow(
          title: Text(label),
          trailing: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
          ),
          onTap: () async {
            final picked = await showPrismColorPicker(
              context: context,
              initial: c,
            );
            if (picked != null) setState(() => on(picked));
          },
        );

    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: _p == null ? 'New passport' : 'Edit passport',
        showBackButton: true,
      ),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            32 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          children: [
            Center(
              child: PassportCoverView(
                cover: _cover.copyWith({
                  'symbol': _symbol.text.isEmpty ? '🌍' : _symbol.text,
                }),
                name: _name.text.isEmpty ? 'Passport' : _name.text,
                subtitle: _subtitle.text,
                width: 160,
              ),
            ),
            const SizedBox(height: 14),
            Text('Start from a template', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            SizedBox(
              height: 112,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final e in passportTemplates.entries)
                    Semantics(
                      button: true,
                      label: 'Template ${e.value.$1}',
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _cover = e.value.$2;
                          _symbol.text = e.value.$2.symbol;
                          _paper = e.value.$3;
                          _texture = e.value.$4;
                        }),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Column(
                            children: [
                              PassportCoverView(
                                cover: e.value.$2,
                                name: '',
                                width: 62,
                              ),
                              Text(
                                e.value.$1,
                                style: theme.textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            PrismTextField(
              controller: _name,
              labelText: 'Name',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            PrismTextField(
              controller: _subtitle,
              labelText: 'Subtitle',
              hintText: 'Adventures of 2026',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            chips(
              'Kind',
              passportTypes.keys.toList(),
              _type,
              (v) => _type = v,
              text: (v) =>
                  '${passportTypes[v]!.$2} ${passportTypes[v]!.$1.replaceAll(' passport', '')}',
            ),
            Text('Owners', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final o in OwnerType.values.where(
                  (o) => o != OwnerType.none,
                ))
                  if (o != OwnerType.subsystem || subs.isNotEmpty)
                    PrismChip(
                      label: o.label,
                      selected: _ownerType == o,
                      onTap: () => setState(() {
                        _ownerType = o;
                        _owners = o == OwnerType.member
                            ? _owners.take(1).toList()
                            : (o == OwnerType.members ? _owners : []);
                      }),
                    ),
              ],
            ),
            const SizedBox(height: 6),
            if (_ownerType == OwnerType.member ||
                _ownerType == OwnerType.members)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final e in names.entries)
                    PrismChip(
                      label: e.value,
                      selected: _owners.contains(e.key),
                      onTap: () => setState(
                        () => _ownerType == OwnerType.member
                            ? _owners = [e.key]
                            : (_owners.contains(e.key)
                                  ? _owners.remove(e.key)
                                  : _owners.add(e.key)),
                      ),
                    ),
                ],
              ),
            if (_ownerType == OwnerType.subsystem)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in subs)
                    PrismChip(
                      label: s.title,
                      selected: _owners.contains(s.id),
                      onTap: () => setState(() => _owners = [s.id]),
                    ),
                ],
              ),
            const SizedBox(height: 14),
            Text('Cover', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            chips(
              'Material',
              coverMaterials,
              _cover.material,
              (v) => _cover = _cover.copyWith({'material': v}),
            ),
            colour(
              'Cover colour',
              Color(_cover.primary),
              (c) => _cover = _cover.copyWith({'primary': c.toARGB32()}),
            ),
            colour(
              'Lettering colour',
              Color(_cover.secondary),
              (c) => _cover = _cover.copyWith({'secondary': c.toARGB32()}),
            ),
            const SizedBox(height: 6),
            chips(
              'Border',
              coverBorders,
              _cover.border,
              (v) => _cover = _cover.copyWith({'border': v}),
            ),
            PrismTextField(
              controller: _symbol,
              labelText: 'Cover symbol (an emoji)',
              maxLength: 4,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 6),
            chips(
              'Font',
              passportFonts,
              _cover.font,
              (v) => _cover = _cover.copyWith({'font': v}),
            ),
            Text('Pages', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            colour('Paper colour', Color(_paper), (c) => _paper = c.toARGB32()),
            const SizedBox(height: 6),
            chips(
              'Paper texture',
              paperTextures,
              _texture,
              (v) => _texture = v,
            ),
            chips(
              'Page turns',
              pageTransitions,
              _transition,
              (v) => _transition = v,
            ),
            PrismSwitchRow(
              title: 'Opening animation',
              subtitle: 'The cover swings open (skipped with reduced motion).',
              value: _opening,
              onChanged: (v) => setState(() => _opening = v),
            ),
            const SizedBox(height: 6),
            PrismTextField(
              controller: _intro,
              labelText: 'Introduction (first page)',
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            chips(
              'Who can open it',
              const ['system', 'owners', 'private'],
              _visibility,
              (v) => _visibility = v,
              text: (v) => switch (v) {
                'owners' => 'Its owners',
                'private' => 'Only me (hidden from lists while others front)',
                _ => 'Anyone in the system',
              },
            ),
            const SizedBox(height: 12),
            PrismButton(
              label: _p == null ? 'Create passport' : 'Save',
              tone: PrismButtonTone.filled,
              expanded: true,
              onPressed: () async {
                final actions = ref.read(passportActionsProvider);
                final cover = _cover.copyWith({
                  'symbol': _symbol.text.trim().isEmpty
                      ? '🌍'
                      : _symbol.text.trim(),
                });
                final name = _name.text.trim().isEmpty
                    ? 'My passport'
                    : _name.text.trim();
                if (_p == null) {
                  final rec = await actions.create(
                    name: name,
                    subtitle: _subtitle.text,
                    type: _type,
                    ownerType: _ownerType,
                    owners: _owners,
                    cover: cover,
                    paper: _paper,
                    texture: _texture,
                    transition: _transition,
                    opening: _opening,
                    intro: _intro.text,
                    visibility: _visibility,
                  );
                  if (!context.mounted) return;
                  await Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => PassportBookScreen(passportId: rec.id),
                    ),
                  );
                } else {
                  await actions.save(
                    _p,
                    {
                      'subtitle': _subtitle.text.trim(),
                      'type': _type,
                      'ownerType': _ownerType.name,
                      'owners': _owners,
                      'cover': cover.toJson(),
                      'paper': _paper,
                      'texture': _texture,
                      'transition': _transition,
                      'opening': _opening,
                      'visibility': _visibility,
                    },
                    title: name,
                    body: _intro.text.trim(),
                  );
                  if (context.mounted) Navigator.of(context).pop();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Suggestion categories and saved stamp templates.
class PassportSettingsScreen extends ConsumerWidget {
  const PassportSettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(passportSettingsProvider);
    final templates = ref.watch(stampTemplatesProvider);
    final actions = ref.read(passportActionsProvider);
    final theme = Theme.of(context);
    return PrismPageScaffold(
      topBar: const PrismTopBar(
        title: 'Passport settings',
        showBackButton: true,
      ),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + NavBarInset.of(context)),
          children: [
            PrismSectionHeader(title: 'STAMP IDEAS'),
            PrismSurface(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final e in stampCategories.entries.where(
                    (e) => e.key != 'custom',
                  ))
                    PrismSwitchRow(
                      title: '${e.value.$2} ${e.value.$1}',
                      value: s.suggest[e.key] ?? false,
                      onChanged: (v) => actions.saveSettings(
                        s.copyWith(suggest: {...s.suggest, e.key: v}),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
              child: Text(
                'Ideas are only suggested — never added for you. Journal entries, health records and location history are never used.',
                style: theme.textTheme.bodySmall,
              ),
            ),
            if (s.dismissed.isNotEmpty)
              PrismButton(
                label: 'Show dismissed ideas again',
                onPressed: () =>
                    actions.saveSettings(s.copyWith(dismissed: {})),
              ),
            PrismSectionHeader(title: 'SAVED STAMP DESIGNS'),
            if (templates.isEmpty)
              Text(
                'Save a design from the stamp designer to reuse it.',
                style: theme.textTheme.bodySmall,
              ),
            for (final t in templates)
              PrismListRow(
                leading: StampView(design: t.design, size: 48),
                title: Text(t.name),
                subtitle: Text(stampCategories[t.category]?.$1 ?? ''),
                trailing: IconButton(
                  tooltip: 'Delete design',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => actions.deleteTemplate(t),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Owners" and "private" passports only show while one of their owners
/// is fronting. System-wide passports always show.
bool passportVisibleTo(Passport p, String? fronter) {
  if (p.visibility == 'system' ||
      p.ownerType == OwnerType.system ||
      p.ownerType == OwnerType.none)
    return true;
  return fronter != null && p.owners.contains(fronter);
}

/// Default stamp look for the passport's stamp style.
StampDesign styledStamp(Passport p, StampDesign d) => switch (p.stampStyle) {
  'sticker' => d.copyWith({
    'texture': 'none',
    'effect': 'shine',
    'opacity': 1.0,
  }),
  'embossed' => d.copyWith({
    'texture': 'none',
    'effect': 'embossed',
    'color2': p.paper,
  }),
  _ => d,
};
