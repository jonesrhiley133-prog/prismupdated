import 'package:intl/intl.dart' show DateFormat;

import 'package:prism_plurality/features/cozy/data/cozy_data.dart';
import 'package:prism_plurality/features/games/core/games_data.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// "5 min ago" style time.
String cozyAgo(BuildContext context, DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return tr(context, 'just now', 'ahora');
  if (d.inMinutes < 60) return tr(context, '${d.inMinutes} min ago', 'hace ${d.inMinutes} min');
  if (d.inHours < 24) return tr(context, '${d.inHours} h ago', 'hace ${d.inHours} h');
  if (d.inDays < 7) return tr(context, '${d.inDays} d ago', 'hace ${d.inDays} d');
  return DateFormat.MMMd().format(t);
}

/// An alter's accent colour (their custom colour, or the theme's).
final memberAccentProvider = Provider.family<Color?, String?>((ref, id) {
  final m = ref.watch(gameMembersProvider).where((x) => x.id == id).firstOrNull;
  if (m == null || !m.customColorEnabled || m.customColorHex == null) return null;
  final hex = m.customColorHex!.replaceAll('#', '');
  final v = int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
  return v == null ? null : Color(v);
});

/// Avatar + name + time line.
class AuthorLine extends ConsumerWidget {
  const AuthorLine({super.key, required this.memberId, required this.when, this.trailing, this.anonymous = false});
  final String? memberId;
  final DateTime when;
  final Widget? trailing;
  final bool anonymous;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = ref.watch(gameNamesProvider);
    final accent = anonymous ? null : ref.watch(memberAccentProvider(memberId));
    final theme = Theme.of(context);
    return Row(
      children: [
        if (anonymous) CircleAvatar(radius: 14, child: Text('?', style: theme.textTheme.labelLarge)) else AlterDot(memberId, size: 28),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: anonymous ? tr(context, 'Someone', 'Alguien') : (names[memberId] ?? tr(context, 'The system', 'El sistema')),
                  style: TextStyle(fontWeight: FontWeight.w700, color: accent),
                ),
                TextSpan(
                  text: '  ·  ${cozyAgo(context, when)}',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

const reactionEmoji = ['❤️', '🤗', '😂', '✨', '🌱', '☕'];

/// Reaction chips; tapping toggles the current alter's reaction.
class ReactionBar extends ConsumerWidget {
  const ReactionBar({super.key, required this.record});
  final TrackerRecord record;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final map = reactionsOf(record);
    final me = ref.watch(cozyMeProvider) ?? '';
    final theme = Theme.of(context);
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final e in reactionEmoji)
          Semantics(
            button: true,
            selected: map[e]?.contains(me) ?? false,
            label: '$e ${map[e]?.length ?? 0}',
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => ref.read(cozyActionsProvider).react(record, e, me),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (map[e]?.contains(me) ?? false) ? theme.colorScheme.primary.withValues(alpha: 0.16) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text('$e${(map[e]?.isNotEmpty ?? false) ? ' ${map[e]!.length}' : ''}', style: const TextStyle(fontSize: 13)),
              ),
            ),
          ),
      ],
    );
  }
}

/// One lounge or room post.
class PostCard extends ConsumerWidget {
  const PostCard({super.key, required this.post});
  final TrackerRecord post;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(memberAccentProvider(post.memberId));
    final starter = post.fields['starter'] as String?;
    final mood = post.fields['mood'] as String?;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PrismSurface(
        accentColor: accent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthorLine(
              memberId: post.memberId,
              when: post.createdAt,
              trailing: PrismIconButton(
                icon: PhosphorIcons.dotsThree(),
                tooltip: tr(context, 'More', 'Más'),
                onPressed: () => PrismSheet.show<void>(
                  context: context,
                  title: tr(context, 'Post', 'Publicación'),
                  builder: (ctx) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PrismListRow(
                        leading: Icon(PhosphorIcons.notebook()),
                        title: Text(tr(ctx, 'Save to Journal', 'Guardar en el diario')),
                        onTap: () {
                          ref.read(cozyActionsProvider).toJournal(title: '☕ Cozy', body: post.body ?? '', memberId: post.memberId);
                          Navigator.of(ctx).pop();
                          PrismToast.show(context, message: tr(context, 'Saved to Journal', 'Guardado en el diario'));
                        },
                      ),
                      PrismListRow(
                        destructive: true,
                        leading: Icon(PhosphorIcons.trash()),
                        title: Text(tr(ctx, 'Delete', 'Eliminar')),
                        onTap: () {
                          ref.read(cozyActionsProvider).delete(post);
                          Navigator.of(ctx).pop();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (starter != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('“$starter”', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
              ),
            const SizedBox(height: 8),
            Text('${mood == null ? '' : '$mood  '}${post.body ?? ''}', style: const TextStyle(height: 1.4)),
            const SizedBox(height: 8),
            ReactionBar(record: post),
          ],
        ),
      ),
    );
  }
}

/// Result of [composeSheet].
class Composed {
  const Composed(this.text, this.author, this.mood);
  final String text;
  final String? author;
  final String? mood;
}

/// A text composer with "posting as" (any alter, fronting or not) and an
/// optional mood tag.
Future<Composed?> composeSheet(BuildContext context, WidgetRef ref, {required String title, String? hint, String? prompt, bool allowMood = true}) {
  return PrismSheet.show<Composed>(
    context: context,
    title: title,
    builder: (ctx) => _Composer(hint: hint, prompt: prompt, allowMood: allowMood),
  );
}

class _Composer extends ConsumerStatefulWidget {
  const _Composer({this.hint, this.prompt, this.allowMood = true});
  final String? hint;
  final String? prompt;
  final bool allowMood;
  @override
  ConsumerState<_Composer> createState() => _ComposerState();
}

class _ComposerState extends ConsumerState<_Composer> {
  final _ctl = TextEditingController();
  late String? _author = ref.read(cozyMeProvider);
  String? _mood;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final names = ref.watch(gameNamesProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.prompt != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(widget.prompt!, style: const TextStyle(fontStyle: FontStyle.italic)),
            ),
          PrismTextField(controller: _ctl, autofocus: true, maxLines: 5, minLines: 2, hintText: widget.hint ?? tr(context, 'Write something…', 'Escribe algo…')),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(tr(context, 'As', 'Como'), style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(width: 8),
              Expanded(
                child: PrismChip(
                  avatar: AlterDot(_author, size: 20),
                  label: _author == null ? tr(context, 'The system', 'El sistema') : (names[_author] ?? '?'),
                  selected: false,
                  onTap: () async {
                    final p = await pickAlters(context, ref, max: 1, selected: [?_author]);
                    if (p != null) setState(() => _author = p.firstOrNull);
                  },
                ),
              ),
            ],
          ),
          if (widget.allowMood) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(tr(context, 'Mood (optional)', 'Ánimo (opcional)'), style: Theme.of(context).textTheme.labelMedium),
                for (final m in cozyMoods) PrismChip(label: m, selected: _mood == m, onTap: () => setState(() => _mood = _mood == m ? null : m)),
              ],
            ),
          ],
          const SizedBox(height: 12),
          PrismButton(
            tone: PrismButtonTone.filled,
            label: tr(context, 'Share', 'Compartir'),
            onPressed: () {
              if (_ctl.text.trim().isEmpty) return;
              Navigator.of(context).pop(Composed(_ctl.text.trim(), _author, _mood));
            },
          ),
        ],
      ),
    );
  }
}

/// Little horizontal list of recent participants' avatars.
class ParticipantsRow extends ConsumerWidget {
  const ParticipantsRow({super.key, required this.ids});
  final List<String> ids;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = ref.watch(gameNamesProvider);
    if (ids.isEmpty) return Text(tr(context, 'Quiet this week — it\'s always open.', 'Tranquilo esta semana: siempre está abierto.'), style: Theme.of(context).textTheme.bodySmall);
    return SizedBox(
      height: 62,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final id in ids.take(12))
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Column(
                children: [
                  AlterDot(id, size: 38),
                  const SizedBox(height: 2),
                  SizedBox(
                    width: 52,
                    child: Text(names[id] ?? '', textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
