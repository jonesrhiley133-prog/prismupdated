import 'package:go_router/go_router.dart';

import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/companions/companion_screens.dart'
    show memberNamesProvider, pushPage;
import 'package:prism_plurality/features/experiences/color_sheet.dart';
import 'package:prism_plurality/features/intro_cards/intro_card_widget.dart';
import 'package:prism_plurality/features/intro_cards/intro_cards_screen.dart'
    show introCardsProvider, introTemplatesProvider, templateFor;
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/passport/passport_book.dart';
import 'package:prism_plurality/features/passport/passport_data.dart';
import 'package:prism_plurality/features/passport/passport_screens.dart'
    show pickPassport;
import 'package:prism_plurality/features/passport/passport_widgets.dart';
import 'package:prism_plurality/features/wallets/id_card_designer.dart';
import 'package:prism_plurality/features/wallets/id_card_view.dart';
import 'package:prism_plurality/features/wallets/wallet_data.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// All wallets: one or more per headmate, plus shared system wallets.
class WalletsHomeScreen extends ConsumerStatefulWidget {
  const WalletsHomeScreen({super.key});
  @override
  ConsumerState<WalletsHomeScreen> createState() => _WalletsHomeScreenState();
}

class _WalletsHomeScreenState extends ConsumerState<WalletsHomeScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final wallets = ref.watch(walletsProvider);
    final names = ref.watch(memberNamesProvider);
    final cards = ref.watch(idCardsProvider);
    final theme = Theme.of(context);
    final q = _q.toLowerCase();
    final hits = q.isEmpty
        ? const <IdCard>[]
        : [
            for (final c in cards)
              if (c.title.toLowerCase().contains(q) ||
                  (names[c.memberId] ?? '').toLowerCase().contains(q) ||
                  c.values.values.any((v) => v.toLowerCase().contains(q)))
                c,
          ];
    final favs = [
      for (final w in wallets)
        for (final i in w.items)
          if (i.favorite && !i.archived && i.kind == 'card')
            ?ref.watch(idCardByIdProvider(i.targetId)),
    ];
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: 'Wallets',
        showBackButton: true,
        actions: [
          IconButton(
            tooltip: 'System identity',
            icon: const Icon(Icons.verified_outlined),
            onPressed: () =>
                pushPage<void>(context, const SystemIdentityScreen()),
          ),
        ],
      ),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + NavBarInset.of(context)),
          children: [
            Text(
              'Wallets hold ID cards, introduction cards and passports. Cards are personal and fictional — just for you.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            PrismTextField(
              hintText: 'Search cards',
              prefixIcon: const Icon(Icons.search),
              onChanged: (v) => setState(() => _q = v),
            ),
            if (hits.isNotEmpty) ...[
              PrismSectionHeader(title: 'RESULTS'),
              for (final c in hits)
                _CardRow(card: c, subtitle: names[c.memberId] ?? 'System'),
            ],
            if (favs.isNotEmpty) ...[
              PrismSectionHeader(title: 'FAVOURITES'),
              SizedBox(
                height: 130,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: favs.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => IdCardView(card: favs[i], width: 200),
                ),
              ),
            ],
            PrismSectionHeader(title: 'WALLETS'),
            if (wallets.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No wallets yet. Make one for a headmate or the whole system.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            for (final w in wallets)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: PrismSurface(
                  onTap: () =>
                      pushPage<void>(context, WalletScreen(walletId: w.id)),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(w.color),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          w.emoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(w.name, style: theme.textTheme.titleSmall),
                            Text(
                              '${w.ownerId == null ? 'System' : names[w.ownerId] ?? 'Someone'} · ${w.items.where((i) => !i.archived).length} items',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            PrismButton(
              label: 'New wallet',
              icon: Icons.add,
              tone: PrismButtonTone.filled,
              expanded: true,
              onPressed: () => newWallet(context, ref),
            ),
            const SizedBox(height: 8),
            PrismButton(
              label: 'Passport library',
              icon: Icons.menu_book_outlined,
              expanded: true,
              onPressed: () => context.push(AppRoutePaths.passports),
            ),
          ],
        ),
      ),
    );
  }
}

Future<String?> newWallet(
  BuildContext context,
  WidgetRef ref, {
  String? ownerId,
}) async {
  final name = TextEditingController();
  var owner = ownerId;
  var color = 0xFF7A5C3E;
  var emoji = '👛';
  final names = ref.read(memberNamesProvider);
  final ok = await PrismSheet.show<bool>(
    context: context,
    title: 'New wallet',
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        children: [
          PrismTextField(
            controller: name,
            labelText: 'Name',
            hintText: 'Everyday wallet',
          ),
          const SizedBox(height: 10),
          PrismSelect<String>(
            labelText: 'Belongs to',
            value: owner ?? '',
            items: [
              const PrismSelectItem(value: '', label: 'The whole system'),
              for (final n in names.entries)
                PrismSelectItem(value: n.key, label: n.value),
            ],
            onChanged: (v) =>
                set(() => owner = v == null || v.isEmpty ? null : v),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final e in const [
                '👛',
                '💼',
                '🎒',
                '👜',
                '🪙',
                '🌈',
                '🌙',
                '🐾',
              ])
                PrismChip(
                  label: e,
                  selected: emoji == e,
                  onTap: () => set(() => emoji = e),
                ),
              GestureDetector(
                onTap: () async {
                  final c = await showPrismColorPicker(
                    context: ctx,
                    initial: Color(color),
                    title: 'Wallet colour',
                  );
                  if (c != null) set(() => color = c.toARGB32());
                },
                child: Semantics(
                  button: true,
                  label: 'Wallet colour',
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: Color(color),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          PrismButton(
            label: 'Create',
            tone: PrismButtonTone.filled,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    ),
  );
  if (ok != true) return null;
  final r = await ref
      .read(walletActionsProvider)
      .createWallet(
        name: name.text.trim().isEmpty
            ? '${owner == null ? 'System' : names[owner]}\'s wallet'
            : name.text,
        ownerId: owner,
        color: color,
        emoji: emoji,
      );
  return r.id;
}

/// One wallet's contents.
class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key, required this.walletId});
  final String walletId;
  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  String _filter = 'all';
  String? _folder;

  @override
  Widget build(BuildContext context) {
    final w = ref.watch(walletByIdProvider(widget.walletId));
    if (w == null)
      return const PrismPageScaffold(
        topBar: PrismTopBar(title: 'Wallet', showBackButton: true),
        body: Center(child: Text('This wallet was deleted.')),
      );
    final theme = Theme.of(context);
    final a = ref.read(walletActionsProvider);
    final items = [
      for (final i in w.items)
        if ((_filter == 'archived') == i.archived &&
            (_filter == 'all' ||
                _filter == 'archived' ||
                (_filter == 'fav' && i.favorite) ||
                i.kind == _filter) &&
            (_folder == null || i.folder == _folder))
          i,
    ]..sort((x, y) => (y.pinned ? 1 : 0) - (x.pinned ? 1 : 0));
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: '${w.emoji} ${w.name}',
        showBackButton: true,
        actions: [
          PrismPopupMenu<String>(
            tooltip: 'Wallet options',
            onSelected: (v) async {
              if (v == 'rename') {
                final c = TextEditingController(text: w.name);
                final n = await PrismDialog.show<String>(
                  context: context,
                  title: 'Rename wallet',
                  builder: (_) => TextField(controller: c, autofocus: true),
                  actions: [
                    PrismButton(
                      label: 'Save',
                      tone: PrismButtonTone.filled,
                      onPressed: () => Navigator.of(
                        context,
                        rootNavigator: true,
                      ).pop(c.text),
                    ),
                  ],
                );
                if (n != null && n.trim().isNotEmpty)
                  await a.saveWallet(w, name: n.trim());
              } else if (v == 'delete') {
                if (await PrismDialog.confirm(
                  context: context,
                  title: 'Delete “${w.name}”?',
                  message:
                      'The wallet is removed. Cards, introduction cards and passports inside it are kept.',
                  confirmLabel: 'Delete',
                  destructive: true,
                )) {
                  await a.deleteWallet(w);
                  if (context.mounted) Navigator.of(context).pop();
                }
              }
            },
            items: const [
              PrismMenuItem(
                value: 'rename',
                label: 'Rename',
                icon: Icons.edit_outlined,
              ),
              PrismMenuItem(
                value: 'delete',
                label: 'Delete wallet',
                icon: Icons.delete_outline,
                destructive: true,
              ),
            ],
          ),
        ],
      ),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + NavBarInset.of(context)),
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (k, l) in const [
                  ('all', 'All'),
                  ('card', 'ID cards'),
                  ('intro', 'Intro cards'),
                  ('pass', 'Passports'),
                  ('fav', '★ Favourites'),
                  ('archived', 'Archived'),
                ])
                  PrismChip(
                    label: l,
                    selected: _filter == k,
                    onTap: () => setState(() => _filter = k),
                  ),
              ],
            ),
            if (w.folders.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final f in w.folders)
                    PrismChip(
                      label: '📁 $f',
                      selected: _folder == f,
                      onTap: () =>
                          setState(() => _folder = _folder == f ? null : f),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PrismButton(
                  label: 'New ID card',
                  icon: Icons.badge_outlined,
                  tone: PrismButtonTone.filled,
                  density: PrismControlDensity.compact,
                  onPressed: () => _newCard(w),
                ),
                PrismButton(
                  label: 'Add intro card',
                  icon: Icons.style_outlined,
                  density: PrismControlDensity.compact,
                  onPressed: () => _addIntro(w),
                ),
                PrismButton(
                  label: 'Add passport',
                  icon: Icons.menu_book_outlined,
                  density: PrismControlDensity.compact,
                  onPressed: () async {
                    final id = await pickPassport(
                      context,
                      ref,
                      title: 'Add a passport to ${w.name}',
                    );
                    if (id != null) await a.addItem(w, 'pass:$id');
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  _filter == 'archived'
                      ? 'Nothing archived.'
                      : 'This wallet is empty. Add an ID card, an introduction card or a passport.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            for (final i in items) _ItemTile(wallet: w, item: i),
          ],
        ),
      ),
    );
  }

  Future<void> _newCard(Wallet w) async {
    var type = 'member';
    var collection = ref.read(systemIdentityProvider).collection;
    var layout = 'badge';
    final fields = {'name', 'pronouns', 'number', 'photo', 'issued', 'emoji'};
    var member = w.ownerId;
    final names = ref.read(memberNamesProvider);
    final ok = await PrismSheet.show<bool>(
      context: context,
      title: 'New ID card',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text('Type', style: Theme.of(ctx).textTheme.titleSmall),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in idCardTypes.entries)
                  PrismChip(
                    label: '${e.value.$2} ${e.value.$1}',
                    selected: type == e.key,
                    onTap: () => set(() => type = e.key),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            PrismSelect<String>(
              labelText: 'For',
              value: member ?? '',
              items: [
                const PrismSelectItem(value: '', label: 'The system'),
                for (final n in names.entries)
                  PrismSelectItem(value: n.key, label: n.value),
              ],
              onChanged: (v) =>
                  set(() => member = v == null || v.isEmpty ? null : v),
            ),
            const SizedBox(height: 10),
            Text(
              'Show these fields',
              style: Theme.of(ctx).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in idFields.entries)
                  PrismChip(
                    label: e.value,
                    selected: fields.contains(e.key),
                    onTap: () => set(
                      () => fields.contains(e.key)
                          ? fields.remove(e.key)
                          : fields.add(e.key),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text('Look', style: Theme.of(ctx).textTheme.titleSmall),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in templateCollections)
                  PrismChip(
                    label: c.name,
                    selected: collection == c.id,
                    onTap: () => set(() => collection = c.id),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in templateLayouts.entries)
                  PrismChip(
                    label: e.value,
                    selected: layout == e.key,
                    onTap: () => set(() => layout = e.key),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Center(
              child: IgnorePointer(
                child: CardFaceView(
                  face: buildTemplate(
                    collection,
                    layout,
                    type: type,
                    fields: fields,
                  ).$1,
                  values: {
                    'name': member == null
                        ? 'The system'
                        : names[member] ?? 'Name',
                    'pronouns': 'they/them',
                    'number': 'PRM-0000-0000',
                    'issued': 'Today',
                    'emoji': '✨',
                  },
                  width: 260,
                ),
              ),
            ),
            const SizedBox(height: 12),
            PrismButton(
              label: 'Create and design',
              tone: PrismButtonTone.filled,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final a = ref.read(walletActionsProvider);
    final r = await a.createCard(
      type: type,
      memberId: member,
      collection: collection,
      layout: layout,
      fields: fields,
    );
    final fresh = ref.read(walletByIdProvider(w.id)) ?? w;
    await a.addItem(fresh, 'card:${r.id}');
    if (mounted) await pushPage<void>(context, IdCardDesigner(cardId: r.id));
  }

  Future<void> _addIntro(Wallet w) async {
    final cards = ref.read(introCardsProvider);
    final names = ref.read(memberNamesProvider);
    if (cards.isEmpty) {
      PrismToast.show(
        context,
        message:
            'No introduction cards yet — make one on the Introductions page.',
      );
      return;
    }
    var hide = false;
    final pick = await PrismSheet.show<String>(
      context: context,
      title: 'Add an introduction card',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => ListView(
          shrinkWrap: true,
          children: [
            PrismSwitchRow(
              title: 'Keep it only in this wallet',
              subtitle:
                  'Hidden from the Introductions page; always visible here',
              value: hide,
              onChanged: (v) => set(() => hide = v),
            ),
            for (final e in cards.entries)
              PrismListRow(
                title: Text(names[e.key] ?? 'Someone'),
                onTap: () => Navigator.of(ctx).pop(e.value.id),
              ),
          ],
        ),
      ),
    );
    if (pick == null) return;
    final rec = cards.values.firstWhere((r) => r.id == pick);
    await ref
        .read(walletActionsProvider)
        .addIntroCard(w, rec, hideFromIntroductions: hide);
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({required this.card, required this.subtitle});
  final IdCard card;
  final String subtitle;
  @override
  Widget build(BuildContext context) => PrismListRow(
    leading: SizedBox(
      width: 64,
      child: IgnorePointer(
        child: IdCardView(card: card, width: 64, flippable: false),
      ),
    ),
    title: Text(card.title),
    subtitle: Text(subtitle),
    showChevron: true,
    onTap: () => pushPage<void>(context, IdCardDesigner(cardId: card.id)),
  );
}

class _ItemTile extends ConsumerWidget {
  const _ItemTile({required this.wallet, required this.item});
  final Wallet wallet;
  final WalletItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.read(walletActionsProvider);
    final theme = Theme.of(context);
    Widget body;
    String title;
    VoidCallback? open;
    switch (item.kind) {
      case 'card':
        final c = ref.watch(idCardByIdProvider(item.targetId));
        if (c == null) return const SizedBox.shrink();
        title = c.title + (wallet.primaryCard == c.id ? ' · on profile' : '');
        body = IdCardView(card: c, width: 300);
        open = () => pushPage<void>(context, IdCardDesigner(cardId: c.id));
      case 'intro':
        final rec = ref
            .watch(introCardsProvider)
            .values
            .where((r) => r.id == item.targetId)
            .firstOrNull;
        if (rec == null) return const SizedBox.shrink();
        final members =
            ref.watch(userVisibleMembersProvider).value ?? const <Member>[];
        final m = members.where((x) => x.id == rec.memberId).firstOrNull;
        title =
            'Introduction card${rec.flag('walletOnly') ? ' · only in this wallet' : ''}';
        body = IntroCardView(
          card: rec,
          member: m,
          template: templateFor(rec, ref.watch(introTemplatesProvider)),
          displayName: m?.name ?? 'Someone',
          width: 260,
        );
      default:
        final p = ref.watch(passportByIdProvider(item.targetId));
        if (p == null) return const SizedBox.shrink();
        title = 'Passport · ${p.name}';
        body = PassportCoverView(
          cover: p.cover,
          name: p.name,
          subtitle: p.subtitle,
          width: 150,
        );
        open = () =>
            pushPage<void>(context, PassportBookScreen(passportId: p.id));
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            children: [
              if (item.pinned)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.push_pin, size: 16),
                ),
              if (item.favorite)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.star, size: 16),
                ),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (item.folder.isNotEmpty)
                Text('📁 ${item.folder}', style: theme.textTheme.labelSmall),
              PrismPopupMenu<String>(
                tooltip: 'Card options',
                onSelected: (v) async {
                  switch (v) {
                    case 'open':
                      open?.call();
                    case 'fav':
                      await a.updateItem(
                        wallet,
                        item.copyWith(favorite: !item.favorite),
                      );
                    case 'pin':
                      await a.updateItem(
                        wallet,
                        item.copyWith(pinned: !item.pinned),
                      );
                    case 'folder':
                      final c = TextEditingController(text: item.folder);
                      final f = await PrismDialog.show<String>(
                        context: context,
                        title: 'Folder',
                        message: 'Leave empty to remove from folders.',
                        builder: (_) => TextField(
                          controller: c,
                          autofocus: true,
                          decoration: const InputDecoration(
                            hintText: 'e.g. Clubs',
                          ),
                        ),
                        actions: [
                          PrismButton(
                            label: 'Save',
                            tone: PrismButtonTone.filled,
                            onPressed: () => Navigator.of(
                              context,
                              rootNavigator: true,
                            ).pop(c.text),
                          ),
                        ],
                      );
                      if (f != null)
                        await a.updateItem(
                          wallet,
                          item.copyWith(folder: f.trim()),
                        );
                    case 'archive':
                      await a.updateItem(
                        wallet,
                        item.copyWith(archived: !item.archived),
                      );
                    case 'dup':
                      final c = ref.read(idCardByIdProvider(item.targetId));
                      if (c != null) {
                        final r = await a.duplicateCard(c);
                        await a.addItem(
                          ref.read(walletByIdProvider(wallet.id)) ?? wallet,
                          'card:${r.id}',
                        );
                      }
                    case 'primary':
                      await a.saveWallet(wallet, primary: item.targetId);
                    case 'unprimary':
                      await a.saveWallet(wallet, clearPrimary: true);
                    case 'showIntro':
                      final rec = ref
                          .read(introCardsProvider)
                          .values
                          .where((r) => r.id == item.targetId)
                          .firstOrNull;
                      if (rec != null) await a.showIntroOnIntroductions(rec);
                    case 'remove':
                      await a.removeItem(wallet, item);
                    case 'delete':
                      final c = ref.read(idCardByIdProvider(item.targetId));
                      if (c != null &&
                          await PrismDialog.confirm(
                            context: context,
                            title: 'Delete this card?',
                            message: 'It will be removed from every wallet.',
                            confirmLabel: 'Delete',
                            destructive: true,
                          ))
                        await a.deleteCard(c);
                  }
                },
                items: [
                  if (open != null)
                    const PrismMenuItem(
                      value: 'open',
                      label: 'Open',
                      icon: Icons.open_in_new,
                    ),
                  PrismMenuItem(
                    value: 'fav',
                    label: item.favorite ? 'Unfavourite' : 'Favourite',
                    icon: Icons.star_outline,
                  ),
                  PrismMenuItem(
                    value: 'pin',
                    label: item.pinned ? 'Unpin' : 'Pin to top',
                    icon: Icons.push_pin_outlined,
                  ),
                  const PrismMenuItem(
                    value: 'folder',
                    label: 'Move to folder…',
                    icon: Icons.folder_outlined,
                  ),
                  PrismMenuItem(
                    value: 'archive',
                    label: item.archived ? 'Unarchive' : 'Archive',
                    icon: Icons.archive_outlined,
                  ),
                  if (item.kind == 'card') ...[
                    const PrismMenuItem(
                      value: 'dup',
                      label: 'Duplicate',
                      icon: Icons.copy,
                    ),
                    if (wallet.ownerId != null)
                      wallet.primaryCard == item.targetId
                          ? const PrismMenuItem(
                              value: 'unprimary',
                              label: 'Remove from profile',
                              icon: Icons.person_off_outlined,
                            )
                          : const PrismMenuItem(
                              value: 'primary',
                              label: 'Show on profile',
                              icon: Icons.person_pin_outlined,
                            ),
                  ],
                  if (item.kind == 'intro')
                    const PrismMenuItem(
                      value: 'showIntro',
                      label: 'Show on Introductions page too',
                      icon: Icons.visibility_outlined,
                    ),
                  const PrismMenuItem(
                    value: 'remove',
                    label: 'Remove from wallet',
                    icon: Icons.remove_circle_outline,
                  ),
                  if (item.kind == 'card')
                    const PrismMenuItem(
                      value: 'delete',
                      label: 'Delete card',
                      icon: Icons.delete_outline,
                      destructive: true,
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Center(child: body),
        ],
      ),
    );
  }
}

/// System-wide details printed on cards.
class SystemIdentityScreen extends ConsumerStatefulWidget {
  const SystemIdentityScreen({super.key});
  @override
  ConsumerState<SystemIdentityScreen> createState() =>
      _SystemIdentityScreenState();
}

class _SystemIdentityScreenState extends ConsumerState<SystemIdentityScreen> {
  late SystemIdentity _s = ref.read(systemIdentityProvider);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: 'System identity',
        showBackButton: true,
        actions: [
          PrismButton(
            label: 'Save',
            tone: PrismButtonTone.filled,
            density: PrismControlDensity.compact,
            onPressed: () async {
              await ref.read(walletActionsProvider).saveIdentity(_s);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Used on every card unless a card overrides it. All cards are personal and fictional; exports say so.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            PrismTextField(
              initialValue: _s.systemName,
              labelText: 'System name',
              onChanged: (v) => _s = _s.copyWith(systemName: v),
            ),
            const SizedBox(height: 10),
            PrismTextField(
              initialValue: _s.issuer,
              labelText: '“Issued by” (fictional)',
              hintText: 'The Prism Collective',
              onChanged: (v) => _s = _s.copyWith(issuer: v),
            ),
            const SizedBox(height: 10),
            PrismTextField(
              initialValue: _s.emblem,
              labelText: 'Emblem (emoji or symbol)',
              onChanged: (v) => _s = _s.copyWith(emblem: v),
            ),
            const SizedBox(height: 10),
            PrismTextField(
              initialValue: _s.prefix,
              labelText: 'Card number prefix',
              onChanged: (v) => _s = _s.copyWith(
                prefix: v.trim().isEmpty ? 'PRM' : v.trim().toUpperCase(),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Default look for new cards',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in templateCollections)
                  PrismChip(
                    label: c.name,
                    selected: _s.collection == c.id,
                    onTap: () =>
                        setState(() => _s = _s.copyWith(collection: c.id)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Profile: the headmate's chosen card, flippable.
class PrimaryIdCardTile extends ConsumerWidget {
  const PrimaryIdCardTile({super.key, required this.memberId});
  final String memberId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(primaryIdCardProvider(memberId));
    if (c == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(child: IdCardView(card: c, width: 300)),
    );
  }
}
