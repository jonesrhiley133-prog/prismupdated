import 'dart:math' as math;

import 'package:intl/intl.dart' show DateFormat;

import 'package:prism_plurality/features/companions/companion_data.dart';
import 'package:prism_plurality/features/companions/companion_screens.dart'
    show memberNamesProvider, pushPage;
import 'package:prism_plurality/features/experiences/color_sheet.dart';
import 'package:prism_plurality/features/experiences/record_picker.dart';
import 'package:prism_plurality/features/passport/passport_data.dart';
import 'package:prism_plurality/features/passport/passport_export.dart';
import 'package:prism_plurality/features/passport/passport_screens.dart';
import 'package:prism_plurality/features/passport/passport_widgets.dart';
import 'package:prism_plurality/features/passport/stamp_art.dart';
import 'package:prism_plurality/shared/media/prism_media.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// A passport as an interactive book: cover, introduction, then pages.
class PassportBookScreen extends ConsumerStatefulWidget {
  const PassportBookScreen({super.key, required this.passportId});
  final String passportId;
  @override
  ConsumerState<PassportBookScreen> createState() => _PassportBookScreenState();
}

class _PassportBookScreenState extends ConsumerState<PassportBookScreen>
    with SingleTickerProviderStateMixin {
  final _pc = PageController();
  late final AnimationController _open = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = ref.read(passportByIdProvider(widget.passportId));
      final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (p != null && p.openingAnimation && !reduced) {
        _open.forward();
      } else {
        _open.value = 1;
      }
    });
  }

  @override
  void dispose() {
    _pc.dispose();
    _open.dispose();
    super.dispose();
  }

  void _go(int i, int count) {
    if (i < 0 || i >= count) return;
    final p = ref.read(passportByIdProvider(widget.passportId));
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (p?.transition == 'none' || reduced) {
      _pc.jumpToPage(i);
    } else {
      _pc.animateToPage(
        i,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(passportByIdProvider(widget.passportId));
    if (p == null)
      return const PrismPageScaffold(
        topBar: PrismTopBar(title: 'Passport', showBackButton: true),
        body: EmptyState(
          icon: Icon(Icons.book_outlined),
          title: 'Passport not found',
          subtitle: 'It may have been deleted.',
        ),
      );
    final pages = ref.watch(passportPagesProvider(p.id));
    final count = pages.length + 2;
    final theme = Theme.of(context);
    final names = ref.watch(memberNamesProvider);
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final currentPage = _index >= 2 && _index - 2 < pages.length
        ? pages[_index - 2]
        : null;

    Widget pageAt(int i) {
      if (i == 0) {
        return Center(
          child: AnimatedBuilder(
            animation: _open,
            builder: (context, child) => Transform(
              alignment: Alignment.centerLeft,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateY(-(1 - _open.value) * 0.9),
              child: child,
            ),
            child: LayoutBuilder(
              builder: (context, box) => PassportCoverView(
                cover: p.cover,
                name: p.name,
                subtitle: p.subtitle,
                width: math.min(box.maxWidth * 0.8, box.maxHeight / 1.45),
              ),
            ),
          ),
        );
      }
      if (i == 1)
        return _IntroPage(
          passport: p,
          owners: passportOwnerLabel(p, names, const {}),
        );
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: PassportPageView(passport: p, page: pages[i - 2]),
        ),
      );
    }

    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: p.name,
        showBackButton: true,
        actions: [
          PrismTopBarAction(
            icon: Icons.approval_outlined,
            tooltip: 'Add a stamp',
            onPressed: () =>
                addStampFlow(context, ref, p, pageId: currentPage?.id),
          ),
          PrismTopBarAction(
            icon: Icons.ios_share,
            tooltip: 'Export',
            onPressed: () =>
                pushPage<void>(context, PassportExportScreen(passportId: p.id)),
          ),
          PrismTopBarAction(
            icon: Icons.more_horiz,
            tooltip: 'More',
            onPressed: () => passportMenu(context, ref, p),
          ),
        ],
      ),
      bodyPadding: EdgeInsets.zero,
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: PageView.builder(
                controller: _pc,
                itemCount: count,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  if (reduced ||
                      p.transition == 'none' ||
                      p.transition == 'slide')
                    return pageAt(i);
                  return AnimatedBuilder(
                    animation: _pc,
                    builder: (context, child) {
                      final page = _pc.hasClients && _pc.position.haveDimensions
                          ? (_pc.page ?? 0)
                          : _index.toDouble();
                      final delta = (i - page).clamp(-1.0, 1.0);
                      if (p.transition == 'fade')
                        return Opacity(opacity: 1 - delta.abs(), child: child);
                      return Transform(
                        alignment: delta > 0
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0015)
                          ..rotateY(delta * 1.1),
                        child: Opacity(
                          opacity: (1 - delta.abs() * 0.6).clamp(0, 1),
                          child: child,
                        ),
                      );
                    },
                    child: pageAt(i),
                  );
                },
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Previous page',
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _index == 0
                        ? null
                        : () => _go(_index - 1, count),
                  ),
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _index == 0
                            ? 'Cover'
                            : (_index == 1
                                  ? 'Introduction'
                                  : '${currentPage?.title ?? ''} · ${_index - 1}/${pages.length}'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Pages',
                    icon: const Icon(Icons.view_carousel_outlined),
                    onPressed: () async {
                      final target = await pushPage<int>(
                        context,
                        PageManagerScreen(passportId: p.id),
                      );
                      if (target != null) _go(target + 2, count);
                    },
                  ),
                  if (currentPage != null)
                    IconButton(
                      tooltip: 'Edit this page',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => pushPage<void>(
                        context,
                        PageEditorScreen(
                          pageId: currentPage.id,
                          passportId: p.id,
                        ),
                      ),
                    ),
                  IconButton(
                    tooltip: 'Next page',
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _index >= count - 1
                        ? null
                        : () => _go(_index + 1, count),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntroPage extends ConsumerWidget {
  const _IntroPage({required this.passport, required this.owners});
  final Passport passport;
  final String owners;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final privacy = PrivacyScope.of(context);
    final stamps = ref.watch(passportStampsProvider(passport.id));
    final ink = Color.lerp(Color(passport.paper), Colors.black, 0.78)!;
    final font = fontFamilyFor(passport.cover.font);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: PaperBackground(
              color: passport.paper,
              texture: passport.texture,
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${passportTypes[passport.type]?.$2 ?? ''} ${passportTypes[passport.type]?.$1 ?? ''}'
                          .toUpperCase(),
                      style: TextStyle(
                        color: ink.withValues(alpha: 0.7),
                        letterSpacing: 2,
                        fontSize: 11,
                        fontFamily: font,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      privacy.text(passport.name),
                      style: TextStyle(
                        color: ink,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        fontFamily: font,
                      ),
                    ),
                    if (passport.subtitle.isNotEmpty)
                      Text(
                        privacy.text(passport.subtitle),
                        style: TextStyle(
                          color: ink.withValues(alpha: 0.8),
                          fontSize: 15,
                          fontFamily: font,
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'Belongs to',
                      style: TextStyle(
                        color: ink.withValues(alpha: 0.6),
                        fontSize: 12,
                        fontFamily: font,
                      ),
                    ),
                    Text(
                      privacy.names ? '•••' : owners,
                      style: TextStyle(
                        color: ink,
                        fontSize: 16,
                        fontFamily: font,
                      ),
                    ),
                    if (!privacy.dates) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Issued',
                        style: TextStyle(
                          color: ink.withValues(alpha: 0.6),
                          fontSize: 12,
                          fontFamily: font,
                        ),
                      ),
                      Text(
                        DateFormat.yMMMMd().format(passport.r.createdAt),
                        style: TextStyle(
                          color: ink,
                          fontSize: 16,
                          fontFamily: font,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (passport.intro.isNotEmpty && !privacy.notes)
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            privacy.text(passport.intro),
                            style: TextStyle(
                              color: ink,
                              fontSize: 15,
                              height: 1.4,
                              fontFamily: font,
                            ),
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    Text(
                      '${stamps.length} stamp${stamps.length == 1 ? '' : 's'} collected',
                      style: TextStyle(
                        color: ink.withValues(alpha: 0.7),
                        fontFamily: font,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Add, rename, duplicate, reorder and delete pages.
class PageManagerScreen extends ConsumerWidget {
  const PageManagerScreen({super.key, required this.passportId});
  final String passportId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(passportByIdProvider(passportId));
    final pages = ref.watch(passportPagesProvider(passportId));
    final actions = ref.read(passportActionsProvider);
    if (p == null) return const SizedBox.shrink();
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: 'Pages',
        showBackButton: true,
        actions: [
          PrismTopBarAction(
            icon: Icons.add,
            tooltip: 'Add a page',
            onPressed: () => _addPage(context, ref),
          ),
        ],
      ),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + NavBarInset.of(context)),
          children: [
            for (final (i, pg) in pages.indexed)
              PrismListRow(
                leading: SizedBox(
                  width: 42,
                  child: IgnorePointer(
                    child: PassportPageView(passport: p, page: pg),
                  ),
                ),
                title: Text(pg.title),
                subtitle: Text(
                  '${passportPageTypes[pg.type]?.$2 ?? ''} ${passportPageTypes[pg.type]?.$1 ?? ''} · ${pg.manual ? 'free layout' : 'auto layout'}',
                ),
                onTap: () => Navigator.of(context).pop(i),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Move up',
                      icon: const Icon(Icons.arrow_upward),
                      onPressed: i == 0 ? null : () => actions.movePage(pg, -1),
                    ),
                    IconButton(
                      tooltip: 'Move down',
                      icon: const Icon(Icons.arrow_downward),
                      onPressed: i == pages.length - 1
                          ? null
                          : () => actions.movePage(pg, 1),
                    ),
                    PrismPopupMenu<String>(
                      items: const [
                        PrismMenuItem(
                          value: 'rename',
                          label: 'Rename',
                          icon: Icons.drive_file_rename_outline,
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
                      onSelected: (v) async {
                        switch (v) {
                          case 'rename':
                            final t = TextEditingController(text: pg.title);
                            final ok = await PrismDialog.show<bool>(
                              context: context,
                              title: 'Rename page',
                              builder: (_) => PrismTextField(
                                controller: t,
                                autofocus: true,
                              ),
                              actions: [
                                PrismButton(
                                  label: 'Cancel',
                                  onPressed: () => Navigator.of(
                                    context,
                                    rootNavigator: true,
                                  ).pop(false),
                                ),
                                PrismButton(
                                  label: 'Save',
                                  tone: PrismButtonTone.filled,
                                  onPressed: () => Navigator.of(
                                    context,
                                    rootNavigator: true,
                                  ).pop(true),
                                ),
                              ],
                            );
                            if (ok == true)
                              await actions.savePage(
                                pg,
                                const {},
                                title: t.text.trim(),
                              );
                            t.dispose();
                          case 'dup':
                            await actions.duplicatePage(pg);
                          case 'delete':
                            final ok = await PrismDialog.confirm(
                              context: context,
                              title: 'Delete ${pg.title}?',
                              message:
                                  'Stamps stay in the passport (on the timeline); what\'s placed on this page is removed.',
                              confirmLabel: 'Delete',
                              destructive: true,
                            );
                            if (ok) await actions.deletePage(pg);
                        }
                      },
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            PrismButton(
              label: 'Add a page',
              icon: Icons.add,
              expanded: true,
              onPressed: () => _addPage(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addPage(BuildContext context, WidgetRef ref) async {
    final type = await PrismSheet.show<String>(
      context: context,
      title: 'New page',
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          for (final e in passportPageTypes.entries)
            PrismListRow(
              leading: Text(e.value.$2, style: const TextStyle(fontSize: 22)),
              title: Text(e.value.$1),
              onTap: () => Navigator.of(ctx).pop(e.key),
            ),
        ],
      ),
    );
    if (type != null)
      await ref.read(passportActionsProvider).addPage(passportId, type);
  }
}

/// Arrange one page: stamps, photos, stickers, text, companions and
/// attachments. Drag on a free-layout page, or use the buttons.
class PageEditorScreen extends ConsumerStatefulWidget {
  const PageEditorScreen({
    super.key,
    required this.pageId,
    required this.passportId,
  });
  final String pageId, passportId;
  @override
  ConsumerState<PageEditorScreen> createState() => _PageEditorScreenState();
}

class _PageEditorScreenState extends ConsumerState<PageEditorScreen> {
  String? _sel;
  final Map<String, Offset> _drag = {};

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(passportByIdProvider(widget.passportId));
    final page = p == null
        ? null
        : ref
              .watch(passportPagesProvider(p.id))
              .where((x) => x.id == widget.pageId)
              .firstOrNull;
    if (p == null || page == null)
      return const PrismPageScaffold(
        topBar: PrismTopBar(title: 'Page', showBackButton: true),
        body: SizedBox.shrink(),
      );
    final actions = ref.read(passportActionsProvider);
    final elements = ref.watch(pageElementsProvider(page.id));
    final sel = elements.where((e) => e.id == _sel).firstOrNull;
    final theme = Theme.of(context);

    Future<void> nudge(
      PassportElement e, {
      double dx = 0,
      double dy = 0,
      double ds = 0,
      double dr = 0,
    }) => actions.moveElement(
      e,
      x: (e.x + dx).clamp(0.05, 0.95),
      y: (e.y + dy).clamp(0.08, 0.95),
      scale: (e.scale + ds).clamp(0.3, 3),
      rotation: e.rotation + dr,
    );

    return PrismPageScaffold(
      topBar: PrismTopBar(title: 'Edit ${page.title}', showBackButton: true),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + NavBarInset.of(context)),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: PassportPageView(
                  passport: p,
                  page: page,
                  selected: _sel,
                  onSelect: (e) => setState(() => _sel = e.id),
                  onDrag: page.manual
                      ? (e, d, box) => setState(
                          () => _drag[e.id] =
                              (_drag[e.id] ?? Offset.zero) +
                              Offset(d.dx / box.width, d.dy / box.height),
                        )
                      : null,
                  onDragEnd: page.manual
                      ? (e) async {
                          final d = _drag.remove(e.id);
                          if (d != null)
                            await actions.moveElement(
                              e,
                              x: (e.x + d.dx).clamp(0.05, 0.95),
                              y: (e.y + d.dy).clamp(0.08, 0.95),
                            );
                        }
                      : null,
                ),
              ),
            ),
            if (sel != null) ...[
              const SizedBox(height: 8),
              PrismSurface(
                padding: const EdgeInsets.all(6),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    if (page.manual) ...[
                      IconButton(
                        tooltip: 'Move left',
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => nudge(sel, dx: -0.04),
                      ),
                      IconButton(
                        tooltip: 'Move up',
                        icon: const Icon(Icons.arrow_upward),
                        onPressed: () => nudge(sel, dy: -0.04),
                      ),
                      IconButton(
                        tooltip: 'Move down',
                        icon: const Icon(Icons.arrow_downward),
                        onPressed: () => nudge(sel, dy: 0.04),
                      ),
                      IconButton(
                        tooltip: 'Move right',
                        icon: const Icon(Icons.arrow_forward),
                        onPressed: () => nudge(sel, dx: 0.04),
                      ),
                    ],
                    IconButton(
                      tooltip: 'Smaller',
                      icon: const Icon(Icons.remove),
                      onPressed: () => nudge(sel, ds: -0.15),
                    ),
                    IconButton(
                      tooltip: 'Bigger',
                      icon: const Icon(Icons.add),
                      onPressed: () => nudge(sel, ds: 0.15),
                    ),
                    IconButton(
                      tooltip: 'Rotate left',
                      icon: const Icon(Icons.rotate_left),
                      onPressed: () => nudge(sel, dr: -8),
                    ),
                    IconButton(
                      tooltip: 'Rotate right',
                      icon: const Icon(Icons.rotate_right),
                      onPressed: () => nudge(sel, dr: 8),
                    ),
                    if (sel.type == 'text')
                      IconButton(
                        tooltip: 'Edit text',
                        icon: const Icon(Icons.edit),
                        onPressed: () async {
                          final t = await _askText(context, sel.text);
                          if (t != null)
                            await actions.moveElement(sel, text: t);
                        },
                      ),
                    if (sel.type == 'stamp' && sel.stampId != null)
                      IconButton(
                        tooltip: 'Edit stamp',
                        icon: const Icon(Icons.approval_outlined),
                        onPressed: () {
                          final s = ref.read(stampByIdProvider(sel.stampId!));
                          if (s != null)
                            pushPage<void>(
                              context,
                              StampDesignerScreen(
                                passportId: p.id,
                                stampId: s.id,
                              ),
                            );
                        },
                      ),
                    IconButton(
                      tooltip: 'Remove from page',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await actions.deleteElement(sel);
                        setState(() => _sel = null);
                      },
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text('Add to this page', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Add(
                  icon: '🔖',
                  label: 'Stamp',
                  onTap: () => addStampFlow(context, ref, p, pageId: page.id),
                ),
                _Add(
                  icon: '🖼️',
                  label: 'Photo',
                  onTap: () async {
                    final id = await PrismMedia.pickImage(ref);
                    if (id != null)
                      await actions.addElement(
                        page.id,
                        'photo',
                        media: id,
                        x: 0.5,
                        y: 0.45,
                      );
                  },
                ),
                _Add(
                  icon: '📸',
                  label: 'Companion photo',
                  onTap: () async {
                    final photos = [
                      for (final m in ref.read(companionMemoriesProvider))
                        if (m.scene != null) m,
                    ];
                    if (photos.isEmpty) {
                      PrismToast.show(
                        context,
                        message: 'No companion photos yet',
                      );
                      return;
                    }
                    final pick = await PrismSheet.show<String>(
                      context: context,
                      title: 'Companion photos',
                      builder: (ctx) => ListView(
                        shrinkWrap: true,
                        children: [
                          for (final m in photos)
                            PrismListRow(
                              title: Text(m.title.isEmpty ? 'Photo' : m.title),
                              subtitle: Text(DateFormat.yMMMd().format(m.at)),
                              onTap: () => Navigator.of(ctx).pop(m.id),
                            ),
                        ],
                      ),
                    );
                    if (pick != null)
                      await actions.addElement(
                        page.id,
                        'photo',
                        refKey: 'rec:$pick',
                        x: 0.5,
                        y: 0.45,
                      );
                  },
                ),
                _Add(
                  icon: '🌟',
                  label: 'Sticker',
                  onTap: () async {
                    const list = [
                      '⭐',
                      '💖',
                      '🌸',
                      '✨',
                      '🎀',
                      '🌙',
                      '☀️',
                      '🌈',
                      '🍰',
                      '🎈',
                      '🍂',
                      '❄️',
                      '🎵',
                      '💐',
                      '🦋',
                      '🍀',
                      '👑',
                      '💌',
                      '✈️',
                      '🗺️',
                      '🎟️',
                      '🏔️',
                      '🌊',
                      '🎂',
                      '🎮',
                      '🎨',
                      '📚',
                      '☕',
                      '🐾',
                      '🧩',
                    ];
                    final e = await PrismSheet.show<String>(
                      context: context,
                      title: 'Sticker',
                      builder: (ctx) => Wrap(
                        children: [
                          for (final s in list)
                            IconButton(
                              tooltip: s,
                              onPressed: () => Navigator.of(ctx).pop(s),
                              icon: Text(
                                s,
                                style: const TextStyle(fontSize: 26),
                              ),
                            ),
                        ],
                      ),
                    );
                    if (e != null)
                      await actions.addElement(
                        page.id,
                        'sticker',
                        emoji: e,
                        x: 0.3 + math.Random().nextDouble() * 0.4,
                        y: 0.3 + math.Random().nextDouble() * 0.4,
                      );
                  },
                ),
                _Add(
                  icon: '🔤',
                  label: 'Text',
                  onTap: () async {
                    final t = await _askText(context, '');
                    if (t == null || t.isEmpty) return;
                    final c = await showPrismColorPicker(
                      context: context,
                      initial: const Color(0xFF2B2B33),
                      title: 'Text colour',
                    );
                    await actions.addElement(
                      page.id,
                      'text',
                      text: t,
                      x: 0.5,
                      y: 0.7,
                      color: (c ?? const Color(0xFF2B2B33)).toARGB32(),
                    );
                  },
                ),
                _Add(
                  icon: '🐾',
                  label: 'Companion',
                  onTap: () async {
                    final cs = ref.read(companionsProvider);
                    if (cs.isEmpty) {
                      PrismToast.show(context, message: 'No companions yet');
                      return;
                    }
                    final pick = await PrismSheet.show<String>(
                      context: context,
                      title: 'Companion',
                      builder: (ctx) => ListView(
                        shrinkWrap: true,
                        children: [
                          for (final c in cs)
                            PrismListRow(
                              title: Text(c.name),
                              subtitle: Text(c.species.name),
                              onTap: () => Navigator.of(ctx).pop(c.id),
                            ),
                        ],
                      ),
                    );
                    if (pick != null)
                      await actions.addElement(
                        page.id,
                        'companion',
                        refKey: 'rec:$pick',
                        x: 0.5,
                        y: 0.5,
                      );
                  },
                ),
                _Add(
                  icon: '🔗',
                  label: 'Attachment',
                  onTap: () async {
                    final key = await pickRecordKey(context, ref);
                    if (key != null)
                      await actions.savePage(page, {
                        'attachments': {...page.attachments, key}.toList(),
                      });
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            PrismSurface(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  PrismSwitchRow(
                    title: 'Free layout',
                    subtitle: page.manual
                        ? 'Drag things anywhere (or use the arrow buttons).'
                        : 'Things arrange themselves neatly.',
                    value: page.manual,
                    onChanged: (v) => actions.savePage(page, {
                      'layout': v ? 'manual' : 'auto',
                    }),
                  ),
                  PrismListRow(
                    title: const Text('Page note'),
                    subtitle: Text(
                      page.note.isEmpty
                          ? 'Write something about this page'
                          : page.note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () async {
                      final t = await _askText(context, page.note, lines: 6);
                      if (t != null)
                        await actions.savePage(page, const {}, body: t);
                    },
                  ),
                  PrismListRow(
                    title: const Text('Page colour'),
                    trailing: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Color(page.background ?? p.paper),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                    onTap: () async {
                      final c = await showPrismColorPicker(
                        context: context,
                        initial: Color(page.background ?? p.paper),
                      );
                      if (c != null)
                        await actions.savePage(page, {
                          'background': c.toARGB32(),
                        });
                    },
                  ),
                  for (final k in page.attachments)
                    PrismListRow(
                      dense: true,
                      leading: const Icon(Icons.link),
                      title: Text(k),
                      trailing: IconButton(
                        tooltip: 'Remove attachment',
                        icon: const Icon(Icons.close),
                        onPressed: () => actions.savePage(page, {
                          'attachments': [
                            for (final x in page.attachments)
                              if (x != k) x,
                          ],
                        }),
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

  Future<String?> _askText(
    BuildContext context,
    String initial, {
    int lines = 3,
  }) async {
    final t = TextEditingController(text: initial);
    final ok = await PrismDialog.show<bool>(
      context: context,
      title: 'Text',
      builder: (_) =>
          PrismTextField(controller: t, autofocus: true, maxLines: lines),
      actions: [
        PrismButton(
          label: 'Cancel',
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(false),
        ),
        PrismButton(
          label: 'Done',
          tone: PrismButtonTone.filled,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
        ),
      ],
    );
    final v = ok == true ? t.text.trim() : null;
    t.dispose();
    return v;
  }
}

class _Add extends StatelessWidget {
  const _Add({required this.icon, required this.label, required this.onTap});
  final String icon, label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => PrismButton(
    label: '$icon  $label',
    density: PrismControlDensity.compact,
    onPressed: onTap,
  );
}

/// Add a stamp: design a new one, reuse a saved design, or take an idea.
Future<void> addStampFlow(
  BuildContext context,
  WidgetRef ref,
  Passport p, {
  String? pageId,
}) async {
  final templates = ref.read(stampTemplatesProvider);
  final ideas = ref.read(stampSuggestionsProvider);
  final pick = await PrismSheet.show<String>(
    context: context,
    title: 'Add a stamp',
    builder: (ctx) => ListView(
      shrinkWrap: true,
      children: [
        PrismListRow(
          leading: const Icon(Icons.brush_outlined),
          title: const Text('Design a new stamp'),
          onTap: () => Navigator.of(ctx).pop('new'),
        ),
        for (final c in stampCategories.entries.where((e) => e.key != 'custom'))
          PrismListRow(
            leading: Text(c.value.$2, style: const TextStyle(fontSize: 22)),
            title: Text('${c.value.$1} stamp'),
            onTap: () => Navigator.of(ctx).pop('cat:${c.key}'),
          ),
        if (templates.isNotEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text('Saved designs'),
          ),
        for (final t in templates)
          PrismListRow(
            leading: StampView(design: t.design, size: 40),
            title: Text(t.name),
            onTap: () => Navigator.of(ctx).pop('tpl:${t.r.id}'),
          ),
        if (ideas.isNotEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text('Ideas from recent moments'),
          ),
        for (final s in ideas.take(6))
          PrismListRow(
            leading: StampView(design: s.design, size: 40),
            title: Text(s.title),
            onTap: () => Navigator.of(ctx).pop('idea:${s.key}'),
          ),
      ],
    ),
  );
  if (pick == null || !context.mounted) return;
  if (pick.startsWith('idea:')) {
    final s = ideas.firstWhere((x) => 'idea:${x.key}' == pick);
    await ref
        .read(passportActionsProvider)
        .addStamp(
          p.id,
          title: s.title,
          category: s.category,
          design: styledStamp(p, s.design),
          at: s.at,
          attachments: s.attachments,
          suggestionKey: s.key,
          pageId: pageId,
        );
    return;
  }
  StampDesign? design;
  var category = 'custom';
  if (pick.startsWith('cat:')) {
    category = pick.substring(4);
    design = defaultStampFor(category, date: stampDate(DateTime.now()));
  } else if (pick.startsWith('tpl:')) {
    final t = templates.firstWhere((x) => 'tpl:${x.r.id}' == pick);
    design = t.design.copyWith({'date': stampDate(DateTime.now())});
    category = t.category;
  }
  await pushPage<void>(
    context,
    StampDesignerScreen(
      passportId: p.id,
      initial: design == null ? null : styledStamp(p, design),
      category: category,
      pageId: pageId,
    ),
  );
}

/// Design (or edit) a stamp, with its details and attachments.
class StampDesignerScreen extends ConsumerStatefulWidget {
  const StampDesignerScreen({
    super.key,
    required this.passportId,
    this.stampId,
    this.initial,
    this.category = 'custom',
    this.pageId,
  });
  final String passportId;
  final String? stampId;
  final StampDesign? initial;
  final String category;
  final String? pageId;
  @override
  ConsumerState<StampDesignerScreen> createState() =>
      _StampDesignerScreenState();
}

class _StampDesignerScreenState extends ConsumerState<StampDesignerScreen> {
  late final PassportStamp? _s = widget.stampId == null
      ? null
      : ref.read(stampByIdProvider(widget.stampId!));
  late StampDesign _d =
      _s?.design ??
      widget.initial ??
      defaultStampFor(widget.category, date: stampDate(DateTime.now()));
  late String _category = _s?.category ?? widget.category;
  late DateTime _at = _s?.at ?? DateTime.now();
  late final _title = TextEditingController(text: _s?.title ?? '');
  late final _text = TextEditingController(text: _d.text);
  late final _sub = TextEditingController(text: _d.subtext);
  late final _icon = TextEditingController(text: _d.icon);
  late final _location = TextEditingController(text: _s?.location ?? '');
  late final _note = TextEditingController(text: _s?.note ?? '');
  late List<String> _attachments = [...?_s?.attachments];
  late bool _showDate = _d.date.isNotEmpty;

  @override
  void dispose() {
    for (final c in [_title, _text, _sub, _icon, _location, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  void _set(String k, Object? v) => setState(() => _d = _d.copyWith({k: v}));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final catalog = ref.watch(recordCatalogProviderForStamps);
    Widget chips(
      String label,
      List<String> values,
      String current,
      String key,
    ) => Padding(
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
                  label: v[0].toUpperCase() + v.substring(1),
                  selected: v == current,
                  onTap: () => _set(key, v),
                ),
            ],
          ),
        ],
      ),
    );
    Widget slider(
      String label,
      double value,
      double min,
      double max,
      String key,
    ) => Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(label, style: theme.textTheme.labelLarge),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            label: label,
            onChanged: (v) => _set(key, v),
          ),
        ),
      ],
    );
    Widget colour(String label, int value, String key) => PrismListRow(
      title: Text(label),
      trailing: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: Color(value),
          shape: BoxShape.circle,
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
      ),
      onTap: () async {
        final c = await showPrismColorPicker(
          context: context,
          initial: Color(value),
        );
        if (c != null) _set(key, c.toARGB32());
      },
    );

    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: _s == null ? 'New stamp' : 'Edit stamp',
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
              child: Container(
                width: 220,
                height: 220,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFFBF7EF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: StampView(
                  design: _d,
                  size: 150,
                  imageWidget: _d.image == null
                      ? null
                      : SocialImageBox(id: _d.image!),
                ),
              ),
            ),
            const SizedBox(height: 12),
            PrismTextField(
              controller: _title,
              labelText: 'What is this stamp for?',
              hintText: 'Beach trip, Game night, Adopted Pip…',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in stampCategories.entries)
                  PrismChip(
                    label: '${c.value.$2} ${c.value.$1}',
                    selected: _category == c.key,
                    onTap: () => setState(() => _category = c.key),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Design', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            chips('Shape', StampDesign.shapes, _d.shape, 'shape'),
            if (_d.shape == 'custom')
              Text(
                'Custom shape uses an uploaded picture as the whole stamp.',
                style: theme.textTheme.bodySmall,
              ),
            Row(
              children: [
                Expanded(
                  child: PrismTextField(
                    controller: _icon,
                    labelText: 'Icon (emoji)',
                    onChanged: (v) => _set('icon', v.trim()),
                  ),
                ),
                const SizedBox(width: 8),
                PrismButton(
                  label: _d.image == null ? 'Picture' : 'Remove picture',
                  icon: Icons.image_outlined,
                  onPressed: () async {
                    if (_d.image != null) return _set('image', null);
                    final id = await PrismMedia.pickImage(ref);
                    if (id != null) _set('image', id);
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            PrismTextField(
              controller: _text,
              labelText: 'Stamp text',
              onChanged: (v) => _set('text', v),
            ),
            const SizedBox(height: 10),
            PrismTextField(
              controller: _sub,
              labelText: 'Small text',
              onChanged: (v) => _set('subtext', v),
            ),
            PrismSwitchRow(
              title: 'Show the date',
              value: _showDate,
              onChanged: (v) => setState(() {
                _showDate = v;
                _d = _d.copyWith({'date': v ? stampDate(_at) : ''});
              }),
            ),
            colour('Ink colour', _d.color, 'color'),
            colour('Paper colour', _d.color2, 'color2'),
            const SizedBox(height: 6),
            chips('Border', StampDesign.borders, _d.border, 'border'),
            chips('Texture', StampDesign.textures, _d.texture, 'texture'),
            chips('Effect', StampDesign.effects, _d.effect, 'effect'),
            slider('Rotation', _d.rotation, -45, 45, 'rotation'),
            slider('Opacity', _d.opacity, 0.2, 1, 'opacity'),
            slider('Size', _d.size, 0.5, 2, 'size'),
            const SizedBox(height: 10),
            Text('Details', style: theme.textTheme.titleSmall),
            Builder(
              builder: (row) => PrismListRow(
                leading: const Icon(Icons.event),
                title: const Text('Date'),
                subtitle: Text(DateFormat.yMMMMd().format(_at)),
                onTap: () async {
                  final d = await showPrismDatePicker(
                    context: context,
                    anchorContext: row,
                    initialDate: _at,
                  );
                  if (d != null)
                    setState(() {
                      _at = d;
                      if (_showDate) _d = _d.copyWith({'date': stampDate(d)});
                    });
                },
              ),
            ),
            PrismTextField(
              controller: _location,
              labelText: 'Place (optional, typed by you)',
              hintText: 'Grandma\'s house, the lake…',
            ),
            const SizedBox(height: 10),
            PrismTextField(controller: _note, labelText: 'Note', maxLines: 3),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text('Attached', style: theme.textTheme.labelLarge),
                ),
                PrismButton(
                  label: 'Attach',
                  icon: Icons.link,
                  density: PrismControlDensity.compact,
                  onPressed: () async {
                    final k = await pickRecordKey(context, ref);
                    if (k != null)
                      setState(
                        () => _attachments = {..._attachments, k}.toList(),
                      );
                  },
                ),
              ],
            ),
            for (final k in _attachments)
              PrismListRow(
                dense: true,
                leading: const Icon(Icons.link),
                title: Text(catalog[k]?.title ?? '(removed)'),
                trailing: IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _attachments.remove(k)),
                ),
              ),
            const SizedBox(height: 16),
            PrismButton(
              label: _s == null ? 'Add stamp' : 'Save stamp',
              tone: PrismButtonTone.filled,
              expanded: true,
              onPressed: _save,
            ),
            const SizedBox(height: 8),
            PrismButton(
              label: 'Save design for reuse',
              icon: Icons.bookmark_add_outlined,
              expanded: true,
              onPressed: () async {
                await ref
                    .read(passportActionsProvider)
                    .saveTemplate(
                      _title.text.trim().isEmpty
                          ? (_d.text.isEmpty ? 'Stamp' : _d.text)
                          : _title.text.trim(),
                      _d.copyWith({'date': ''}),
                      category: _category,
                    );
                if (context.mounted)
                  PrismToast.show(context, message: 'Design saved');
              },
            ),
            if (_s != null) ...[
              const SizedBox(height: 8),
              PrismButton(
                label: 'Delete stamp',
                icon: Icons.delete_outline,
                tone: PrismButtonTone.destructive,
                expanded: true,
                onPressed: () async {
                  final ok = await PrismDialog.confirm(
                    context: context,
                    title: 'Delete this stamp?',
                    confirmLabel: 'Delete',
                    destructive: true,
                  );
                  if (!ok) return;
                  await ref.read(passportActionsProvider).deleteStamp(_s);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final actions = ref.read(passportActionsProvider);
    final title = _title.text.trim().isEmpty
        ? (_d.text.isEmpty ? 'Stamp' : _d.text)
        : _title.text.trim();
    if (_s == null) {
      await actions.addStamp(
        widget.passportId,
        title: title,
        category: _category,
        design: _d,
        at: _at,
        location: _location.text,
        note: _note.text,
        attachments: _attachments,
        pageId: widget.pageId,
      );
    } else {
      await actions.saveStamp(
        _s,
        title: title,
        design: _d,
        at: _at,
        location: _location.text.trim(),
        note: _note.text.trim(),
        attachments: _attachments,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }
}
