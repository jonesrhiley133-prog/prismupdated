import 'package:intl/intl.dart' show DateFormat;

import 'package:prism_plurality/features/cozy/data/cozy_data.dart';
import 'package:prism_plurality/features/cozy/views/cozy_widgets.dart';
import 'package:prism_plurality/features/games/core/games_data.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Letters delivered to the current alter that they haven't opened.
final unreadLettersProvider = Provider<int>((ref) {
  final me = ref.watch(cozyMeProvider);
  if (me == null) return 0;
  return ref.watch(lettersProvider).where((l) => l.delivered && l.to.contains(me) && !l.readBy.contains(me)).length;
});

const stationery = <String, (String, Color, Color)>{
  'plain': ('📄', Color(0xFFFFFDF8), Color(0xFF3B3B58)),
  'floral': ('🌸', Color(0xFFFFEEF2), Color(0xFF6B3A4A)),
  'starry': ('✨', Color(0xFF1F2547), Color(0xFFEDE8FF)),
  'leafy': ('🌿', Color(0xFFEAF5EA), Color(0xFF2F4F35)),
  'sunny': ('🌻', Color(0xFFFFF6D9), Color(0xFF5A4414)),
  'ocean': ('🌊', Color(0xFFE3F2FA), Color(0xFF1D4560)),
  'postcard': ('🏞️', Color(0xFFFFF1E2), Color(0xFF4A3527)),
};

enum _Box { inbox, sent, drafts, scheduled, favourites }

class MailboxView extends ConsumerStatefulWidget {
  const MailboxView({super.key});
  @override
  ConsumerState<MailboxView> createState() => _MailboxViewState();
}

class _MailboxViewState extends ConsumerState<MailboxView> {
  String? _who;
  _Box _box = _Box.inbox;

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(gameMembersProvider);
    final names = ref.watch(gameNamesProvider);
    final me = _who ?? ref.watch(cozyMeProvider) ?? members.firstOrNull?.id;
    final letters = ref.watch(lettersProvider);
    final list = switch (_box) {
      _Box.inbox => letters.where((l) => l.delivered && l.to.contains(me)).toList(),
      _Box.sent => letters.where((l) => !l.draft && l.from == me).toList(),
      _Box.drafts => letters.where((l) => l.draft && l.from == me).toList(),
      _Box.scheduled => letters.where((l) => !l.draft && !l.delivered && l.from == me).toList(),
      _Box.favourites => letters.where((l) => l.favoritedBy.contains(me)).toList(),
    };
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr(context, 'Whose mailbox?', '¿El buzón de quién?'), style: theme.textTheme.labelMedium),
        const SizedBox(height: 6),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final m in members)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: PrismChip(
                    avatar: AlterDot(m.id, size: 22),
                    label:
                        '${names[m.id] ?? ''}${() {
                          final n = letters.where((l) => l.delivered && l.to.contains(m.id) && !l.readBy.contains(m.id)).length;
                          return n == 0 ? '' : ' · $n';
                        }()}',
                    selected: me == m.id,
                    onTap: () => setState(() => _who = m.id),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final (b, l) in [
              (_Box.inbox, tr(context, '📥 Inbox', '📥 Recibidas')),
              (_Box.sent, tr(context, '📤 Sent', '📤 Enviadas')),
              (_Box.drafts, tr(context, '📝 Drafts', '📝 Borradores')),
              (_Box.scheduled, tr(context, '⏰ Scheduled', '⏰ Programadas')),
              (_Box.favourites, tr(context, '⭐ Favourites', '⭐ Favoritas')),
            ])
              PrismChip(label: l, selected: _box == b, onTap: () => setState(() => _box = b)),
          ],
        ),
        const SizedBox(height: 10),
        PrismButton(
          tone: PrismButtonTone.filled,
          icon: PhosphorIcons.envelopeSimple(),
          label: tr(context, 'Write a letter', 'Escribir una carta'),
          onPressed: () => composeLetter(context, ref, from: me),
        ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          EmptyState(
            icon: Icon(PhosphorIcons.envelopeOpen()),
            title: tr(context, 'Nothing here', 'Nada por aquí'),
            subtitle: tr(context, 'Letters can be sent to one alter or many — even scheduled for later.', 'Puedes enviar cartas a uno o varios alters, incluso programarlas.'),
          )
        else
          for (final l in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PrismSurface(
                onTap: () => l.draft ? composeLetter(context, ref, draft: l) : openLetter(context, ref, l, viewer: me),
                child: Row(
                  children: [
                    Text(stationery[l.stationery]?.$1 ?? '📄', style: const TextStyle(fontSize: 26)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.subject.isEmpty ? tr(context, '(no subject)', '(sin asunto)') : l.subject,
                            style: TextStyle(fontWeight: _box == _Box.inbox && !l.readBy.contains(me) ? FontWeight.w800 : FontWeight.w600),
                          ),
                          Text(
                            _box == _Box.inbox || _box == _Box.favourites
                                ? '${tr(context, 'From', 'De')} ${l.anonymous ? tr(context, 'someone', 'alguien') : names[l.from] ?? tr(context, 'the system', 'el sistema')} · ${cozyAgo(context, l.when)}'
                                : '${tr(context, 'To', 'Para')} ${l.to.map((t) => names[t] ?? '?').join(', ')}${l.deliverAt != null && !l.delivered ? ' · ${DateFormat.MMMd().add_jm().format(l.deliverAt!)}' : ''}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (_box == _Box.inbox && !l.readBy.contains(me)) Icon(PhosphorIcons.circle(PhosphorIconsStyle.fill), size: 10, color: theme.colorScheme.primary),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

Future<void> openLetter(BuildContext context, WidgetRef ref, Letter l, {String? viewer}) async {
  if (viewer != null && l.to.contains(viewer) && !l.readBy.contains(viewer)) {
    await ref.read(cozyActionsProvider).toggleIn(l.r, 'read', viewer);
  }
  if (!context.mounted) return;
  await PrismSheet.show<void>(
    context: context,
    title: l.subject.isEmpty ? tr(context, 'A letter', 'Una carta') : l.subject,
    builder: (_) => _LetterView(letterId: l.r.id, viewer: viewer),
  );
}

class _LetterView extends ConsumerWidget {
  const _LetterView({required this.letterId, this.viewer});
  final String letterId;
  final String? viewer;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(lettersProvider).where((x) => x.r.id == letterId).firstOrNull;
    if (l == null) return const SizedBox(height: 80);
    final names = ref.watch(gameNamesProvider);
    final (emoji, bg, fg) = stationery[l.stationery] ?? stationery['plain']!;
    final fav = viewer != null && l.favoritedBy.contains(viewer);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Text(emoji, style: const TextStyle(fontSize: 24)),
                ),
                Text(
                  '${tr(context, 'Dear', 'Querido/a')} ${l.to.map((t) => names[t] ?? '?').join(', ')},',
                  style: TextStyle(color: fg, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text('${l.mood == null ? '' : '${l.mood} '}${l.body}', style: TextStyle(color: fg, height: 1.5)),
                const SizedBox(height: 14),
                Text(
                  '— ${l.anonymous ? tr(context, 'someone who cares', 'alguien que te quiere') : names[l.from] ?? tr(context, 'the system', 'el sistema')}',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: fg, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ReactionBar(record: l.r),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (viewer != null)
                PrismButton(
                  icon: fav ? PhosphorIcons.star(PhosphorIconsStyle.fill) : PhosphorIcons.star(),
                  label: fav ? tr(context, 'Favourite', 'Favorita') : tr(context, 'Add to favourites', 'Añadir a favoritas'),
                  onPressed: () => ref.read(cozyActionsProvider).toggleIn(l.r, 'fav', viewer!),
                ),
              if (viewer != null && l.from != null && !l.anonymous)
                PrismButton(
                  icon: PhosphorIcons.arrowBendUpLeft(),
                  label: tr(context, 'Reply', 'Responder'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    composeLetter(context, ref, from: viewer, to: [l.from!], subject: l.subject.startsWith('Re: ') ? l.subject : 'Re: ${l.subject}');
                  },
                ),
              PrismButton(
                icon: PhosphorIcons.notebook(),
                label: tr(context, 'Save to Journal', 'Guardar en el diario'),
                onPressed: () {
                  ref.read(cozyActionsProvider).toJournal(title: '💌 ${l.subject}', body: l.body, memberId: viewer);
                  PrismToast.show(context, message: tr(context, 'Saved to Journal', 'Guardado en el diario'));
                },
              ),
              PrismButton(
                icon: PhosphorIcons.trash(),
                label: tr(context, 'Delete', 'Eliminar'),
                onPressed: () {
                  ref.read(cozyActionsProvider).delete(l.r);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> composeLetter(BuildContext context, WidgetRef ref, {String? from, List<String> to = const [], String subject = '', Letter? draft}) => PrismSheet.show<void>(
  context: context,
  title: tr(context, 'Write a letter', 'Escribir una carta'),
  builder: (_) => _LetterComposer(from: draft?.from ?? from, to: draft?.to ?? to, subject: draft?.subject ?? subject, draft: draft),
);

class _LetterComposer extends ConsumerStatefulWidget {
  const _LetterComposer({this.from, this.to = const [], this.subject = '', this.draft});
  final String? from;
  final List<String> to;
  final String subject;
  final Letter? draft;
  @override
  ConsumerState<_LetterComposer> createState() => _LetterComposerState();
}

class _LetterComposerState extends ConsumerState<_LetterComposer> {
  late String? _from = widget.from;
  late List<String> _to = [...widget.to];
  late final _subject = TextEditingController(text: widget.subject);
  late final _body = TextEditingController(text: widget.draft?.body ?? '');
  late String _paper = widget.draft?.stationery ?? 'plain';
  late bool _anon = widget.draft?.anonymous ?? false;
  late DateTime? _deliverAt = widget.draft?.deliverAt;
  late String? _mood = widget.draft?.mood;

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save({required bool draft}) async {
    if (!draft && (_to.isEmpty || _body.text.trim().isEmpty)) {
      PrismToast.show(context, message: tr(context, 'Choose who it\'s for and write something first.', 'Elige destinatario y escribe algo primero.'));
      return;
    }
    final fields = {'to': _to, 'stationery': _paper, 'anonymous': _anon, 'draft': draft, 'deliverAt': _deliverAt?.toIso8601String(), 'mood': _mood};
    final t = ref.read(trackerNotifierProvider.notifier);
    if (widget.draft == null) {
      await t.create(kind: TrackerKind.cozyLetter, title: _subject.text.trim(), body: _body.text.trim(), memberId: _from, fields: fields);
    } else {
      await t.save(widget.draft!.r.copyWith(title: _subject.text.trim(), body: _body.text.trim(), memberId: _from).withFields({...widget.draft!.r.fields, ...fields}));
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    PrismToast.show(
      context,
      message: draft
          ? tr(context, 'Draft saved', 'Borrador guardado')
          : (_deliverAt != null && _deliverAt!.isAfter(DateTime.now()) ? tr(context, 'Scheduled 💌', 'Programada 💌') : tr(context, 'Letter sent 💌', 'Carta enviada 💌')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final names = ref.watch(gameNamesProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(tr(context, 'From', 'De'), style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(width: 8),
              PrismChip(
                avatar: AlterDot(_from, size: 20),
                label: _from == null ? tr(context, 'The system', 'El sistema') : names[_from] ?? '?',
                selected: false,
                onTap: () async {
                  final p = await pickAlters(context, ref, max: 1, selected: [?_from]);
                  if (p != null) setState(() => _from = p.firstOrNull);
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          AlterChips(
            ids: _to,
            emptyLabel: tr(context, 'To… (one or more)', 'Para… (uno o varios)'),
            onTap: () async {
              final p = await pickAlters(context, ref, selected: _to, title: tr(context, 'Send to', 'Enviar a'));
              if (p != null) setState(() => _to = p);
            },
          ),
          const SizedBox(height: 8),
          PrismTextField(controller: _subject, hintText: tr(context, 'Subject', 'Asunto')),
          const SizedBox(height: 8),
          PrismTextField(controller: _body, maxLines: 8, minLines: 4, hintText: tr(context, 'Your letter…', 'Tu carta…')),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            children: [for (final e in stationery.entries) PrismChip(label: e.value.$1, selected: _paper == e.key, onTap: () => setState(() => _paper = e.key))],
          ),
          Wrap(
            spacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(tr(context, 'Mood (optional)', 'Ánimo (opcional)'), style: Theme.of(context).textTheme.labelMedium),
              for (final m in cozyMoods) PrismChip(label: m, selected: _mood == m, onTap: () => setState(() => _mood = _mood == m ? null : m)),
            ],
          ),
          PrismSwitchRow(title: tr(context, 'Send anonymously', 'Enviar de forma anónima'), value: _anon, onChanged: (v) => setState(() => _anon = v)),
          PrismListRow(
            dense: true,
            leading: Icon(PhosphorIcons.clock()),
            title: Text(
              _deliverAt == null
                  ? tr(context, 'Deliver now', 'Entregar ahora')
                  : tr(context, 'Deliver ${DateFormat.MMMEd().add_jm().format(_deliverAt!)}', 'Entregar ${DateFormat.MMMEd().add_jm().format(_deliverAt!)}'),
            ),
            trailing: _deliverAt == null ? null : PrismIconButton(icon: PhosphorIcons.x(), tooltip: tr(context, 'Deliver now', 'Entregar ahora'), onPressed: () => setState(() => _deliverAt = null)),
            onTap: () async {
              final now = DateTime.now();
              final d = await showPrismDatePicker(context: context, initialDate: now.add(const Duration(days: 1)), firstDate: now, lastDate: now.add(const Duration(days: 3650)));
              if (d == null || !context.mounted) return;
              final t = await showPrismTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
              setState(() => _deliverAt = DateTime(d.year, d.month, d.day, t?.hour ?? 9, t?.minute ?? 0));
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: PrismButton(label: tr(context, 'Save draft', 'Guardar borrador'), onPressed: () => _save(draft: true)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PrismButton(tone: PrismButtonTone.filled, label: tr(context, 'Send', 'Enviar'), onPressed: () => _save(draft: false)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
