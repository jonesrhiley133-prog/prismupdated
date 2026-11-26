import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/domain/models/contact.dart';
import 'package:prism_plurality/features/calendar/providers/calendar_providers.dart';
import 'package:prism_plurality/features/chat/providers/chat_providers.dart';
import 'package:prism_plurality/features/companions/companion_screens.dart'
    show memberNamesProvider;
import 'package:prism_plurality/features/contacts/contact_extras.dart';
import 'package:prism_plurality/features/contacts/providers/contact_providers.dart';
import 'package:prism_plurality/features/contacts/utils/birthday_date.dart';
import 'package:prism_plurality/features/contacts/views/contact_editor_sheet.dart';
import 'package:prism_plurality/features/contacts/views/contact_extras_editor.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';
import 'package:prism_plurality/shared/media/prism_media.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// A contact's own page, in the spirit of a phone's native Contacts app:
/// a big centred picture, the name, one row of round actions for whatever
/// the contact actually has, then calm rounded sections that open and close.
/// No statistics, no dashboards.
class ContactProfileScreen extends ConsumerWidget {
  const ContactProfileScreen({super.key, required this.contactId});
  final String contactId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(contactsProvider).value ?? const <Contact>[];
    final contact = contacts.where((c) => c.id == contactId).firstOrNull;
    if (contact == null) {
      return PrismPageScaffold(
        topBar: PrismTopBar(
          title: tr(context, 'Contact', 'Contacto'),
          showBackButton: true,
        ),
        body: Center(
          child: Text(
            ref.watch(contactsProvider).isLoading
                ? ''
                : tr(
                    context,
                    'This contact was deleted.',
                    'Este contacto fue eliminado.',
                  ),
          ),
        ),
      );
    }
    return _Profile(contact: contact);
  }
}

class _Profile extends ConsumerWidget {
  const _Profile({required this.contact});
  final Contact contact;

  Future<void> _open(BuildContext context, Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        PrismToast.error(
          context,
          message: tr(
            context,
            'No app could open that.',
            'Ninguna app pudo abrirlo.',
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        PrismToast.error(
          context,
          message: tr(
            context,
            'No app could open that.',
            'Ninguna app pudo abrirlo.',
          ),
        );
      }
    }
  }

  /// A handle or link → something launchable.
  Uri? _socialUri(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    if (t.startsWith('http://') || t.startsWith('https://'))
      return Uri.tryParse(t);
    if (t.contains('.') && !t.contains(' ') && !t.startsWith('@'))
      return Uri.tryParse('https://$t');
    return null;
  }

  Future<String?> _choose(
    BuildContext context,
    String title,
    List<(String label, String value)> options,
  ) async {
    if (options.length == 1) return options.first.$2;
    return PrismSheet.show<String>(
      context: context,
      title: title,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final o in options)
            PrismListRow(
              title: Text(o.$2),
              subtitle: o.$1.isEmpty ? null : Text(o.$1),
              onTap: () => Navigator.of(ctx).pop(o.$2),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final x = ref.watch(contactExtrasProvider(contact.id));
    final accent = x.accent == null
        ? theme.colorScheme.primary
        : Color(x.accent!);
    final names = ref.watch(memberNamesProvider);
    final b = BirthdayDate.fromStorage(contact.birthday);
    final display = x.nickname.isNotEmpty ? x.nickname : contact.displayName;

    // Actions exist only for information this contact actually has.
    final actions = <_Action>[
      if (contact.phones.isNotEmpty)
        _Action(Icons.call_outlined, tr(context, 'Call', 'Llamar'), () async {
          final v = await _choose(context, tr(context, 'Call', 'Llamar'), [
            for (final p in contact.phones) (x.phoneLabels[p] ?? '', p),
          ]);
          if (v != null && context.mounted)
            await _open(context, Uri(scheme: 'tel', path: v));
        }),
      if (contact.phones.isNotEmpty)
        _Action(
          Icons.sms_outlined,
          tr(context, 'Message', 'Mensaje'),
          () async {
            final v = await _choose(
              context,
              tr(context, 'Message', 'Mensaje'),
              [for (final p in contact.phones) (x.phoneLabels[p] ?? '', p)],
            );
            if (v != null && context.mounted)
              await _open(context, Uri(scheme: 'sms', path: v));
          },
        ),
      if (contact.emails.isNotEmpty)
        _Action(Icons.mail_outline, tr(context, 'Email', 'Correo'), () async {
          final v = await _choose(context, tr(context, 'Email', 'Correo'), [
            for (final e in contact.emails) (x.emailLabels[e] ?? '', e),
          ]);
          if (v != null && context.mounted)
            await _open(context, Uri(scheme: 'mailto', path: v));
        }),
      if (x.socials.any((s) => _socialUri(s['url'] ?? '') != null))
        _Action(Icons.public, tr(context, 'Profile', 'Perfil'), () async {
          final opts = [
            for (final s in x.socials)
              if (_socialUri(s['url'] ?? '') != null)
                (s['label'] ?? '', s['url']!),
          ];
          final v = await _choose(
            context,
            tr(context, 'Open profile', 'Abrir perfil'),
            opts,
          );
          final uri = v == null ? null : _socialUri(v);
          if (uri != null && context.mounted) await _open(context, uri);
        }),
      if (x.conversation != null)
        _Action(Icons.chat_bubble_outline, tr(context, 'Chat', 'Chat'), () {
          final exists = (ref.read(conversationsProvider).value ?? const [])
              .any((c) => c.id == x.conversation);
          if (!exists) {
            PrismToast.error(
              context,
              message: tr(
                context,
                'That conversation no longer exists.',
                'Esa conversación ya no existe.',
              ),
            );
            return;
          }
          context.push(AppRoutePaths.chatConversation(x.conversation!));
        }),
    ];

    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: '',
        showBackButton: true,
        actions: [
          IconButton(
            tooltip: contact.isFavorite
                ? tr(context, 'Remove from favorites', 'Quitar de favoritos')
                : tr(context, 'Favorite', 'Favorito'),
            icon: Icon(
              contact.isFavorite
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              color: contact.isFavorite ? Colors.amber : null,
            ),
            onPressed: () => ref
                .read(contactsNotifierProvider.notifier)
                .save(contact.copyWith(isFavorite: !contact.isFavorite)),
          ),
          IconButton(
            tooltip: tr(context, 'Edit', 'Editar'),
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => showContactEditor(context, editing: contact),
          ),
          PrismPopupMenu<String>(
            icon: Icons.more_vert,
            tooltip: tr(context, 'More', 'Más'),
            onSelected: (v) async {
              if (v == 'details')
                await showContactExtrasEditor(context, contact);
              if (v == 'delete') {
                final ok = await PrismDialog.confirm(
                  context: context,
                  title: tr(
                    context,
                    'Delete ${contact.displayName}?',
                    '¿Eliminar a ${contact.displayName}?',
                  ),
                  message: tr(
                    context,
                    'This removes the contact and its profile details.',
                    'Esto elimina el contacto y los detalles de su perfil.',
                  ),
                  confirmLabel: tr(context, 'Delete', 'Eliminar'),
                  destructive: true,
                );
                if (ok == true) {
                  await ref
                      .read(contactExtrasActionsProvider)
                      .remove(contact.id);
                  await ref
                      .read(contactsNotifierProvider.notifier)
                      .delete(contact.id);
                  if (context.mounted) context.pop();
                }
              }
            },
            items: [
              PrismMenuItem(
                value: 'details',
                label: tr(
                  context,
                  'Edit profile details',
                  'Editar detalles del perfil',
                ),
                icon: Icons.tune,
              ),
              PrismMenuItem(
                value: 'delete',
                label: tr(context, 'Delete contact', 'Eliminar contacto'),
                icon: Icons.delete_outline,
              ),
            ],
          ),
        ],
      ),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 40 + NavBarInset.of(context)),
          children: [
            _Header(contact: contact, x: x, accent: accent, display: display),
            if (actions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 18, bottom: 6),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 10,
                  children: [
                    for (final a in actions)
                      _RoundAction(action: a, accent: accent),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            // ── Contact information ───────────────────────────────────
            if (contact.phones.isNotEmpty ||
                contact.emails.isNotEmpty ||
                x.addresses.isNotEmpty ||
                x.socials.isNotEmpty)
              _Section(
                icon: Icons.contact_phone_outlined,
                title: tr(
                  context,
                  'Contact information',
                  'Información de contacto',
                ),
                initiallyOpen: true,
                accent: accent,
                children: [
                  for (final p in contact.phones)
                    _Row(
                      label:
                          x.phoneLabels[p] ?? tr(context, 'Phone', 'Teléfono'),
                      value: p,
                      icon: Icons.call_outlined,
                      onTap: () => _open(context, Uri(scheme: 'tel', path: p)),
                      copyable: true,
                    ),
                  for (final e in contact.emails)
                    _Row(
                      label: x.emailLabels[e] ?? tr(context, 'Email', 'Correo'),
                      value: e,
                      icon: Icons.mail_outline,
                      onTap: () =>
                          _open(context, Uri(scheme: 'mailto', path: e)),
                      copyable: true,
                    ),
                  for (final a in x.addresses)
                    _Row(
                      label: a['label'] ?? '',
                      value: a['text'] ?? '',
                      icon: Icons.place_outlined,
                      onTap: () => _open(
                        context,
                        Uri.https('www.google.com', '/maps/search/', {
                          'api': '1',
                          'query': a['text'] ?? '',
                        }),
                      ),
                      copyable: true,
                    ),
                  for (final s in x.socials)
                    _Row(
                      label: s['label'] ?? tr(context, 'Social', 'Social'),
                      value: s['url'] ?? '',
                      icon: Icons.alternate_email,
                      onTap: _socialUri(s['url'] ?? '') == null
                          ? null
                          : () => _open(context, _socialUri(s['url']!)!),
                      copyable: true,
                    ),
                ],
              ),
            // ── Dates ────────────────────────────────────────────────
            if (b != null || x.dates.isNotEmpty)
              _Section(
                icon: Icons.cake_outlined,
                title: tr(context, 'Dates', 'Fechas'),
                accent: accent,
                children: [
                  if (b != null)
                    _Row(
                      label: tr(context, 'Birthday', 'Cumpleaños'),
                      value: formatBirthday(context, b),
                      icon: Icons.cake_outlined,
                    ),
                  for (final d in x.dates)
                    _Row(
                      label: d['label']?.isEmpty ?? true
                          ? tr(context, 'Important date', 'Fecha importante')
                          : d['label']!,
                      value: _prettyDate(context, d['date']),
                      icon: Icons.event_outlined,
                    ),
                ],
              ),
            // ── About ────────────────────────────────────────────────
            if (x.relationship.isNotEmpty ||
                x.pronouns.isNotEmpty ||
                x.nickname.isNotEmpty ||
                x.custom.isNotEmpty)
              _Section(
                icon: Icons.person_outline,
                title: tr(context, 'About', 'Acerca de'),
                accent: accent,
                children: [
                  if (x.nickname.isNotEmpty)
                    _Row(
                      label: tr(context, 'Goes by', 'Se llama'),
                      value: x.nickname,
                      icon: Icons.badge_outlined,
                    ),
                  if (x.pronouns.isNotEmpty)
                    _Row(
                      label: tr(context, 'Pronouns', 'Pronombres'),
                      value: x.pronouns,
                      icon: Icons.record_voice_over_outlined,
                    ),
                  if (x.relationship.isNotEmpty)
                    _Row(
                      label: tr(context, 'Relationship', 'Relación'),
                      value: x.relationship,
                      icon: Icons.diversity_1_outlined,
                    ),
                  for (final c in x.custom)
                    _Row(
                      label: c['label'] ?? '',
                      value: c['value'] ?? '',
                      icon: Icons.label_outline,
                    ),
                ],
              ),
            // ── Communication ────────────────────────────────────────
            if (x.commPrefs.isNotEmpty ||
                x.boundaries.isNotEmpty ||
                x.reminders.isNotEmpty)
              _Section(
                icon: Icons.forum_outlined,
                title: tr(context, 'Communication', 'Comunicación'),
                accent: accent,
                children: [
                  if (x.commPrefs.isNotEmpty)
                    _Row(
                      label: tr(context, 'Preferences', 'Preferencias'),
                      value: x.commPrefs,
                      icon: Icons.tune,
                    ),
                  if (x.boundaries.isNotEmpty)
                    _Row(
                      label: tr(context, 'Boundaries', 'Límites'),
                      value: x.boundaries,
                      icon: Icons.shield_outlined,
                    ),
                  for (final r in x.reminders)
                    _Row(
                      label: r['date'] == null
                          ? tr(context, 'Reminder', 'Recordatorio')
                          : _prettyDate(context, r['date']),
                      value: r['text'] ?? '',
                      icon: Icons.notifications_none,
                    ),
                ],
              ),
            // ── Connected alters ─────────────────────────────────────
            if (x.alters.isNotEmpty)
              _Section(
                icon: Icons.hub_outlined,
                title: tr(context, 'Connected alters', 'Alters conectados'),
                accent: accent,
                children: [
                  for (final id in x.alters)
                    _Row(
                      label: names[id] ?? tr(context, 'Alter', 'Alter'),
                      value: (x.alterNotes[id] ?? '').isEmpty
                          ? tr(context, 'Knows ${display}', 'Conoce a $display')
                          : x.alterNotes[id]!,
                      icon: Icons.person_pin_outlined,
                    ),
                ],
              ),
            // ── Linked journal / scrapbook / events ──────────────────
            if (x.links.isNotEmpty || x.sharedMemories.isNotEmpty)
              _LinkedSection(x: x, accent: accent),
            // ── Interaction history ──────────────────────────────────
            _InteractionSection(contact: contact, x: x, accent: accent),
            // ── Gift ideas ───────────────────────────────────────────
            if (x.giftIdeas.isNotEmpty)
              _Section(
                icon: Icons.card_giftcard_outlined,
                title: tr(context, 'Gift ideas', 'Ideas de regalo'),
                accent: accent,
                children: [
                  for (final g in x.giftIdeas)
                    _Row(label: '', value: g, icon: Icons.redeem_outlined),
                ],
              ),
            // ── Private ──────────────────────────────────────────────
            if (x.safety.isNotEmpty)
              _Section(
                icon: Icons.lock_outline,
                title: tr(
                  context,
                  'Safety & comfort · private',
                  'Seguridad y comodidad · privado',
                ),
                accent: accent,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final s in x.safety)
                          PrismChip(label: s, selected: true, onTap: () {}),
                      ],
                    ),
                  ),
                ],
              ),
            if (x.privateNotes.isNotEmpty || (contact.notes ?? '').isNotEmpty)
              _Section(
                icon: Icons.sticky_note_2_outlined,
                title: tr(context, 'Notes', 'Notas'),
                accent: accent,
                children: [
                  if ((contact.notes ?? '').isNotEmpty)
                    _Row(
                      label: tr(context, 'Notes', 'Notas'),
                      value: contact.notes!,
                      icon: Icons.notes,
                    ),
                  if (x.privateNotes.isNotEmpty)
                    _Row(
                      label: tr(
                        context,
                        'Private · only you',
                        'Privado · solo tú',
                      ),
                      value: x.privateNotes,
                      icon: Icons.lock_outline,
                    ),
                ],
              ),
            if (x.isEmpty &&
                contact.phones.isEmpty &&
                contact.emails.isEmpty &&
                b == null &&
                (contact.notes ?? '').isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: PrismButton(
                  label: tr(context, 'Add details', 'Añadir detalles'),
                  icon: Icons.add,
                  expanded: true,
                  tone: PrismButtonTone.outlined,
                  onPressed: () => showContactExtrasEditor(context, contact),
                ),
              ),
            if (!x.isEmpty ||
                contact.phones.isNotEmpty ||
                contact.emails.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Center(
                  child: PrismButton(
                    label: tr(
                      context,
                      'Edit profile details',
                      'Editar detalles del perfil',
                    ),
                    icon: Icons.tune,
                    tone: PrismButtonTone.outlined,
                    onPressed: () => showContactExtrasEditor(context, contact),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _prettyDate(BuildContext context, String? iso) {
  final d = DateTime.tryParse(iso ?? '');
  if (d == null) return iso ?? '';
  return MaterialLocalizations.of(context).formatMediumDate(d);
}

class _Action {
  const _Action(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.action, required this.accent});
  final _Action action;
  final Color accent;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: action.label,
    child: InkWell(
      customBorder: prismCircleBorder(context),
      onTap: action.onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.16),
              ),
              child: Icon(action.icon, color: accent),
            ),
            const SizedBox(height: 6),
            Text(
              action.label,
              style: Theme.of(context).textTheme.labelMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    ),
  );
}

class _Header extends ConsumerWidget {
  const _Header({
    required this.contact,
    required this.x,
    required this.accent,
    required this.display,
  });
  final Contact contact;
  final ContactExtras x;
  final Color accent;
  final String display;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final chips = [
      if (x.pronouns.isNotEmpty) x.pronouns,
      if (x.relationship.isNotEmpty) x.relationship,
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: prismCorners(context, 28),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent.withValues(alpha: 0.14),
            accent.withValues(alpha: 0.02),
          ],
        ),
      ),
      child: Column(
        children: [
          if (x.banner != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
              child: PrismClipRound(
                child: SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: PrismMediaView(id: x.banner!),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              x.banner != null ? 14 : 24,
              16,
              22,
            ),
            child: Column(
              children: [
                _Avatar(contact: contact, avatar: x.avatar, accent: accent),
                const SizedBox(height: 14),
                Text(
                  contact.displayName,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (x.nickname.isNotEmpty && x.nickname != contact.displayName)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '“${x.nickname}”',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (chips.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final c in chips)
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.14),
                              borderRadius: prismRound(context),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              child: Text(
                                c,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: accent,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (x.status.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      x.status,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
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

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.contact,
    required this.avatar,
    required this.accent,
  });
  final Contact contact;
  final String? avatar;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    const size = 112.0;
    final initial = contact.displayName.isEmpty
        ? '?'
        : contact.displayName.characters.first.toUpperCase();
    return Semantics(
      label: contact.displayName,
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: accent.withValues(alpha: 0.5), width: 3),
        ),
        padding: const EdgeInsets.all(3),
        child: ClipOval(
          child: avatar != null
              ? PrismMediaView(id: avatar!)
              : ColoredBox(
                  color: accent.withValues(alpha: 0.2),
                  child: Center(
                    child: Text(
                      initial,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// A rounded, expandable card.
class _Section extends StatefulWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.children,
    required this.accent,
    this.initiallyOpen = false,
    this.trailing,
  });
  final IconData icon;
  final String title;
  final List<Widget> children;
  final Color accent;
  final bool initiallyOpen;
  final Widget? trailing;

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PrismSurface(
        padding: EdgeInsets.zero,
        borderRadius: 22,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              expanded: _open,
              label: widget.title,
              child: InkWell(
                borderRadius: prismCorners(context, 22),
                onTap: () => setState(() => _open = !_open),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Icon(widget.icon, color: widget.accent, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      if (widget.trailing != null) widget.trailing!,
                      AnimatedRotation(
                        turns: _open ? 0.5 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: const Icon(Icons.expand_more),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: _open
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(children: widget.children),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
    this.copyable = false,
  });
  final String label, value;
  final IconData icon;
  final VoidCallback? onTap;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      onLongPress: copyable
          ? () {
              Clipboard.setData(ClipboardData(text: value));
              PrismToast.show(
                context,
                message: tr(context, 'Copied', 'Copiado'),
              );
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: theme.textTheme.bodyLarge),
                  if (label.isNotEmpty)
                    Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
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

/// Journal entries, scrapbook pages and events linked to the contact, plus
/// memories you share.
class _LinkedSection extends ConsumerWidget {
  const _LinkedSection({required this.x, required this.accent});
  final ContactExtras x;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journal =
        ref.watch(trackerKindProvider(TrackerKind.journalEntry)).value ??
        const [];
    final pages =
        ref.watch(trackerKindProvider(TrackerKind.scrapPage)).value ?? const [];
    final events = ref.watch(calendarEventsProvider).value ?? const [];
    final rows = <Widget>[];
    for (final l in x.links) {
      final i = l.indexOf(':');
      final kind = l.substring(0, i), id = l.substring(i + 1);
      switch (kind) {
        case 'journal':
          final r = journal.where((e) => e.id == id).firstOrNull;
          if (r != null)
            rows.add(
              _Row(
                label: tr(context, 'Journal', 'Diario'),
                value: r.title.isEmpty
                    ? tr(context, 'Entry', 'Entrada')
                    : r.title,
                icon: Icons.menu_book_outlined,
                onTap: () => context.push(AppRoutePaths.journal),
              ),
            );
        case 'scrap':
          final r = pages.where((e) => e.id == id).firstOrNull;
          if (r != null)
            rows.add(
              _Row(
                label: tr(context, 'Scrapbook', 'Álbum'),
                value: r.title.isEmpty
                    ? tr(context, 'Page', 'Página')
                    : r.title,
                icon: Icons.auto_stories_outlined,
              ),
            );
        case 'cal':
          final e = events.where((e) => e.id == id).firstOrNull;
          if (e != null)
            rows.add(
              _Row(
                label: tr(context, 'Calendar', 'Calendario'),
                value: e.title,
                icon: Icons.event_outlined,
                onTap: () => context.push(AppRoutePaths.calendar),
              ),
            );
      }
    }
    for (final m in x.sharedMemories) {
      rows.add(
        _Row(
          label: tr(context, 'Shared memory', 'Recuerdo compartido'),
          value: m,
          icon: Icons.favorite_border,
        ),
      );
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return _Section(
      icon: Icons.photo_album_outlined,
      title: tr(context, 'Memories & links', 'Recuerdos y vínculos'),
      accent: accent,
      children: rows,
    );
  }
}

/// A light log of when you were in touch. You add entries yourself; there
/// are no streaks and no nagging.
class _InteractionSection extends ConsumerWidget {
  const _InteractionSection({
    required this.contact,
    required this.x,
    required this.accent,
  });
  final Contact contact;
  final ContactExtras x;
  final Color accent;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final c = TextEditingController();
    final note = await PrismSheet.show<String>(
      context: context,
      title: tr(context, 'Log a moment', 'Registrar un momento'),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrismTextField(
            controller: c,
            autofocus: true,
            maxLines: 3,
            minLines: 2,
            hintText: tr(
              ctx,
              'Had coffee, they called, we talked about…',
              'Tomamos café, me llamó…',
            ),
          ),
          const SizedBox(height: 12),
          PrismButton(
            label: tr(ctx, 'Save', 'Guardar'),
            tone: PrismButtonTone.filled,
            onPressed: () => Navigator.of(ctx).pop(c.text.trim()),
          ),
        ],
      ),
    );
    c.dispose();
    if (note == null || note.isEmpty) return;
    await ref
        .read(contactExtrasActionsProvider)
        .save(
          x.copyWith(
            interactions: [
              {'at': DateTime.now().toIso8601String(), 'note': note},
              ...x.interactions,
            ],
          ),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shown = x.interactions.take(6).toList();
    return _Section(
      icon: Icons.history,
      title: tr(context, 'Interaction history', 'Historial'),
      accent: accent,
      trailing: IconButton(
        tooltip: tr(context, 'Log a moment', 'Registrar un momento'),
        icon: const Icon(Icons.add_circle_outline),
        onPressed: () => _add(context, ref),
      ),
      children: [
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              tr(
                context,
                'Nothing logged yet. Add a moment whenever you like.',
                'Aún no hay nada. Añade un momento cuando quieras.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        for (final (i, it) in shown.indexed)
          Dismissible(
            key: ValueKey('${it['at']}-$i'),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete_outline),
            ),
            onDismissed: (_) => ref
                .read(contactExtrasActionsProvider)
                .save(
                  x.copyWith(interactions: [...x.interactions]..remove(it)),
                ),
            child: _Row(
              label: _prettyDate(context, it['at']),
              value: it['note'] ?? '',
              icon: Icons.chat_outlined,
            ),
          ),
      ],
    );
  }
}
