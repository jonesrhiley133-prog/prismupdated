import 'package:prism_plurality/shared/theme/prism_shapes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/domain/models/contact.dart';
import 'package:prism_plurality/features/contacts/providers/contact_providers.dart';
import 'package:prism_plurality/features/contacts/utils/birthday_date.dart';
import 'package:prism_plurality/features/contacts/views/contact_editor_sheet.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/app_shell.dart';
import 'package:prism_plurality/shared/widgets/clamped_body.dart';
import 'package:prism_plurality/shared/widgets/empty_state.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_loading_state.dart';
import 'package:prism_plurality/shared/widgets/prism_page_scaffold.dart';
import 'package:prism_plurality/shared/widgets/prism_surface.dart';
import 'package:prism_plurality/shared/widgets/prism_text_field.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar_action.dart';

/// People outside the system, with their (yearly recurring) birthdays.
class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key, this.showBackButton = false});

  final bool showBackButton;

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final async = ref.watch(contactsProvider);
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: l10n.contactsTitle,
        showBackButton: widget.showBackButton,
        actions: [
          PrismTopBarAction(
            icon: AppIcons.navImport,
            tooltip: l10n.importCenterTitle,
            onPressed: () => context.push(AppRoutePaths.importCenter),
          ),
          PrismTopBarAction(
            icon: AppIcons.add,
            tooltip: l10n.contactsNew,
            onPressed: () => showContactEditor(context),
          ),
        ],
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: async.when(
        loading: () => const PrismLoadingState(),
        error: (e, _) => Center(child: Text(l10n.errorWithDetail(e))),
        data: (contacts) {
          if (contacts.isEmpty) {
            return ClampedBody(
              child: EmptyState(
                icon: Icon(AppIcons.navContacts),
                title: l10n.contactsEmptyTitle,
                subtitle: l10n.contactsEmptySubtitle,
                actionLabel: l10n.contactsNew,
                onAction: () => showContactEditor(context),
              ),
            );
          }
          final q = _search.text.trim().toLowerCase();
          final filtered =
              contacts
                  .where(
                    (c) =>
                        q.isEmpty ||
                        c.displayName.toLowerCase().contains(q) ||
                        c.phones.any((p) => p.contains(q)) ||
                        c.emails.any((e) => e.toLowerCase().contains(q)),
                  )
                  .toList()
                ..sort((a, b) {
                  if (a.isFavorite != b.isFavorite) {
                    return a.isFavorite ? -1 : 1;
                  }
                  return a.displayName.toLowerCase().compareTo(
                    b.displayName.toLowerCase(),
                  );
                });
          final upcoming = upcomingContactBirthdays(contacts, DateTime.now());
          return ClampedBody(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                24 + NavBarInset.of(context),
              ),
              children: [
                PrismTextField(
                  controller: _search,
                  labelText: l10n.contactsSearch,
                  prefixIcon: Icon(AppIcons.search),
                  onChanged: (_) => setState(() {}),
                ),
                if (q.isEmpty && upcoming.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    l10n.contactsUpcomingBirthdays,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  for (final u in upcoming.take(5)) _BirthdayRow(item: u),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.contactsCount(filtered.length),
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    PrismButton(
                      label: l10n.importCenterTitle,
                      icon: AppIcons.navImport,
                      density: PrismControlDensity.compact,
                      onPressed: () => context.push(AppRoutePaths.importCenter),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final c in filtered) _ContactRow(contact: c),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BirthdayRow extends StatelessWidget {
  const _BirthdayRow({required this.item});
  final UpcomingBirthday item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final today = DateTime.now();
    final days = DateTime.utc(
      item.date.year,
      item.date.month,
      item.date.day,
    ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: PrismSurface(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        onTap: () => context.push(AppRoutePaths.contact(item.contact.id)),
        child: Row(
          children: [
            Icon(AppIcons.cake, color: Colors.pinkAccent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.turning == null
                    ? item.contact.displayName
                    : l10n.calendarBirthdayTurning(
                        item.contact.displayName,
                        item.turning!,
                      ),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Text(
              days == 0
                  ? l10n.calendarToday
                  : days == 1
                  ? l10n.contactsTomorrow
                  : DateFormat.MMMd(context.dateLocale).format(item.date),
              style: theme.textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.contact});
  final Contact contact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = BirthdayDate.fromStorage(contact.birthday);
    final details = [
      if (contact.phones.isNotEmpty) contact.phones.first,
      if (contact.emails.isNotEmpty) contact.emails.first,
      if (b != null) '🎂 ${formatBirthday(context, b)}',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: PrismSurface(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        onTap: () => context.push(AppRoutePaths.contact(contact.id)),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: prismRound(context),
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
              ),
              child: Text(
                contact.displayName.characters.first.toUpperCase(),
                style: theme.textTheme.titleSmall,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          contact.displayName,
                          style: theme.textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (contact.isFavorite) ...[
                        const SizedBox(width: 4),
                        Icon(AppIcons.star, size: 14, color: Colors.amber),
                      ],
                    ],
                  ),
                  if (details.isNotEmpty)
                    Text(
                      details.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
