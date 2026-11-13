import 'package:intl/intl.dart';

import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/alter_status/status_models.dart';
import 'package:prism_plurality/features/alter_status/status_providers.dart';
import 'package:prism_plurality/features/alter_status/status_widgets.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import 'package:prism_plurality/shared/widgets/member_avatar.dart';

enum _Tab { now, history, custom, visibility }

class StatusesScreen extends ConsumerStatefulWidget {
  const StatusesScreen({super.key});

  @override
  ConsumerState<StatusesScreen> createState() => _StatusesScreenState();
}

class _StatusesScreenState extends ConsumerState<StatusesScreen> {
  _Tab _tab = _Tab.now;
  String? _member;

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: tr(context, 'Alter statuses', 'Estados de alters'),
        showBackButton: true,
        actions: [
          PrismTopBarAction(
            icon: AppIcons.add,
            tooltip: tr(context, 'New custom status', 'Nuevo estado personalizado'),
            onPressed: () => showCustomStatusEditor(context),
          ),
        ],
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: PrismSegmentedControl<_Tab>(
                segments: [
                  PrismSegment(value: _Tab.now, label: tr(context, 'Now', 'Ahora')),
                  PrismSegment(value: _Tab.history, label: tr(context, 'History', 'Historial')),
                  PrismSegment(value: _Tab.custom, label: tr(context, 'Custom', 'Propios')),
                  PrismSegment(value: _Tab.visibility, label: tr(context, 'Shown', 'Visibles')),
                ],
                selected: _tab,
                onChanged: (t) => setState(() => _tab = t),
              ),
            ),
            Expanded(
              child: switch (_tab) {
                _Tab.now => _NowList(lang: lang),
                _Tab.history => _History(lang: lang, member: _member, onMember: (m) => setState(() => _member = m)),
                _Tab.custom => _CustomList(lang: lang),
                _Tab.visibility => _Visibility(lang: lang),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NowList extends ConsumerWidget {
  const _NowList({required this.lang});
  final String lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(activeMembersProvider);
    final statuses = ref.watch(alterStatusesProvider(lang));
    final preferDisplay = ref.watch(memberNamePreferDisplayProvider);
    return members.when(
      loading: () => const PrismLoadingState(),
      error: (e, _) => Center(child: Text(context.l10n.errorWithDetail(e))),
      data: (list) {
        if (list.isEmpty) {
          return EmptyState(
            icon: Icon(PhosphorIcons.chatCircleDots()),
            title: tr(context, 'No alters yet', 'Aún no hay alters'),
            subtitle: tr(context, 'Add headmates to give them statuses.', 'Añade headmates para darles estados.'),
          );
        }
        final sorted = [...list]..sort((a, b) {
          final sa = statuses.containsKey(a.id) ? 0 : 1, sb = statuses.containsKey(b.id) ? 0 : 1;
          return sa != sb ? sa - sb : a.displayOrder.compareTo(b.displayOrder);
        });
        return ListView.builder(
          padding: EdgeInsets.fromLTRB(16, 0, 16, NavBarInset.of(context) + 16),
          itemCount: sorted.length,
          itemBuilder: (context, i) {
            final m = sorted[i];
            final s = statuses[m.id];
            return PrismSurface(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(12),
              onTap: () => showStatusEditor(context, m.id),
              child: Row(
                children: [
                  _Avatar(member: m, status: s, preferDisplay: preferDisplay),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.effectiveName(preferDisplayName: preferDisplay), style: Theme.of(context).textTheme.titleSmall),
                        if (s != null)
                          StatusLine(status: s)
                        else
                          Text(tr(context, 'No status', 'Sin estado'), style: Theme.of(context).textTheme.labelMedium),
                      ],
                    ),
                  ),
                  if (s?.isPrivate ?? false) Icon(AppIcons.lockOutline, size: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.member, required this.status, required this.preferDisplay});
  final Member member;
  final AlterStatus? status;
  final bool preferDisplay;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      MemberAvatar(
        avatarImageData: member.avatarImageData,
        memberName: member.effectiveName(preferDisplayName: preferDisplay),
        emoji: member.emoji,
        customColorEnabled: member.customColorEnabled,
        customColorHex: member.customColorHex,
        size: 44,
      ),
      if (status != null) Positioned(right: -2, bottom: -2, child: StatusDot(status: status!, size: 18)),
    ],
  );
}

class _History extends ConsumerWidget {
  const _History({required this.lang, required this.member, required this.onMember});
  final String lang;
  final String? member;
  final ValueChanged<String?> onMember;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final types = {for (final t in ref.watch(statusTypesProvider(lang))) t.key: t};
    final logs = ref.watch(trackerKindProvider(TrackerKind.statusLog)).value ?? const <TrackerRecord>[];
    final shown = [for (final r in logs) if (member == null || r.memberId == member) r];
    final fmt = DateFormat.MMMd(context.dateLocale).add_jm();
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, NavBarInset.of(context) + 16),
      children: [
        TrackerMemberFilter(value: member, onChanged: onMember, onlyIds: {for (final r in logs) ?r.memberId}),
        const SizedBox(height: 8),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: Text(tr(context, 'Status changes will appear here.', 'Los cambios de estado aparecerán aquí.'))),
          ),
        for (final r in shown.take(400))
          () {
            final s = statusFromRecord(r, types);
            if (s == null) return const SizedBox.shrink();
            final dur = r.endedAt?.difference(r.occurredAt ?? r.createdAt);
            return PrismListRow(
              dense: true,
              leading: StatusDot(status: s, size: 22),
              title: Text('${memberNameFor(ref, r.memberId) ?? '?'} · ${s.title}'),
              subtitle: Text([
                fmt.format(r.occurredAt ?? r.createdAt),
                if (dur != null) '${dur.inHours}h ${dur.inMinutes % 60}m',
                if (s.message != null) s.message!,
              ].join(' · ')),
            );
          }(),
      ],
    );
  }
}

class _CustomList extends ConsumerWidget {
  const _CustomList({required this.lang});
  final String lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final types = ref.watch(statusTypesProvider(lang));
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, NavBarInset.of(context) + 16),
      children: [
        for (final t in types)
          PrismListRow(
            leading: CircleAvatar(backgroundColor: Color(t.color), child: Icon(iconForKey(t.iconKey), color: Colors.white, size: 18)),
            title: Text(t.title),
            subtitle: Text(t.record == null ? tr(context, 'Built-in', 'Predeterminado') : (t.description ?? tr(context, 'Custom', 'Personalizado'))),
            showChevron: t.record != null,
            onTap: t.record == null ? null : () => showCustomStatusEditor(context, editing: t.record),
          ),
        const SizedBox(height: 12),
        PrismButton(
          label: tr(context, 'New custom status', 'Nuevo estado personalizado'),
          icon: AppIcons.add,
          tone: PrismButtonTone.filled,
          onPressed: () => showCustomStatusEditor(context),
        ),
      ],
    );
  }
}

class _Visibility extends ConsumerWidget {
  const _Visibility({required this.lang});
  final String lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final types = ref.watch(statusTypesProvider(lang));
    final hidden = ref.watch(hiddenStatusTypesProvider);
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, NavBarInset.of(context) + 16),
      children: [
        Text(
          tr(context, 'Choose which statuses appear on Home and in lists. Hidden ones still show on the alter’s own profile.',
              'Elige qué estados aparecen en Inicio y en listas. Los ocultos se siguen viendo en el perfil del alter.'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        for (final t in types)
          PrismSwitchRow(
            icon: iconForKey(t.iconKey),
            iconColor: Color(t.color),
            title: t.title,
            value: !hidden.contains(t.key),
            onChanged: (v) {
              final next = {...hidden};
              v ? next.remove(t.key) : next.add(t.key);
              ref.read(statusActionsProvider).setHidden(next);
            },
          ),
      ],
    );
  }
}
