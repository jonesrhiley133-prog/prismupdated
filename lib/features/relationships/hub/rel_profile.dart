import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/links/models/record_ref.dart';
import 'package:prism_plurality/features/links/widgets/related_records.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/relationships/hub/rel_editor.dart';
import 'package:prism_plurality/features/relationships/hub/rel_insights.dart';
import 'package:prism_plurality/features/relationships/hub/rel_model.dart';
import 'package:prism_plurality/features/relationships/utils/relationships.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/media/prism_media.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Records removed by the last relationship delete, for the hub's undo bar.
class RelUndo {
  const RelUndo(this.records, this.at);
  final List<TrackerRecord> records;
  final DateTime at;
}

class RelUndoNotifier extends Notifier<RelUndo?> {
  @override
  RelUndo? build() => null;
  void set(RelUndo? v) => state = v;
}

final relUndoProvider = NotifierProvider<RelUndoNotifier, RelUndo?>(RelUndoNotifier.new);

String relRoute(String id) => '${AppRoutePaths.relationships}/r/$id';

/// Deletes after confirming; the hub offers an undo for a short while.
Future<bool> confirmDeleteRel(BuildContext context, WidgetRef ref, Rel rel) async {
  final ok = await PrismDialog.confirm(
    context: context,
    title: tr(context, 'Delete this relationship?', '¿Eliminar esta relación?'),
    message: tr(context, 'Its notes, timeline events and check-ins are removed too. You can undo this from the Relationships page for a short time.', 'También se quitan sus notas, eventos y registros. Puedes deshacerlo desde Relaciones durante un rato.'),
    destructive: true,
    confirmLabel: tr(context, 'Delete', 'Eliminar'),
    cancelLabel: context.l10n.cancel,
  );
  if (ok != true) return false;
  final removed = await ref.read(relActionsProvider).delete(rel);
  ref.read(relUndoProvider.notifier).set(RelUndo(removed, DateTime.now()));
  return true;
}

class RelationshipProfileScreen extends ConsumerStatefulWidget {
  const RelationshipProfileScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<RelationshipProfileScreen> createState() => _RelationshipProfileScreenState();
}

enum _Tab { overview, notes, timeline, checkins, summary }

class _RelationshipProfileScreenState extends ConsumerState<RelationshipProfileScreen> {
  _Tab _tab = _Tab.overview;

  @override
  Widget build(BuildContext context) {
    final rel = ref.watch(relByIdProvider(widget.id));
    final settings = ref.watch(relSettingsProvider);
    if (rel == null) {
      return PrismPageScaffold(
        topBar: PrismTopBar(title: tr(context, 'Relationship', 'Relación'), showBackButton: true),
        body: Center(child: Text(tr(context, 'This relationship isn’t available.', 'Esta relación no está disponible.'))),
      );
    }
    final alters = ref.watch(relAlterIndexProvider);
    final prefer = ref.watch(memberNamePreferDisplayProvider);
    String nm(String? id) => alters[id]?.effectiveName(preferDisplayName: prefer) ?? (rel.otherName ?? '—');
    final title = rel.title.isNotEmpty ? rel.title : '${nm(rel.a)} & ${rel.internal ? nm(rel.b) : (rel.otherName ?? '—')}';
    final tabs = [
      (_Tab.overview, tr(context, 'Overview', 'Resumen')),
      (_Tab.notes, tr(context, 'Notes', 'Notas')),
      (_Tab.timeline, tr(context, 'Timeline', 'Cronología')),
      (_Tab.checkins, tr(context, 'Check-ins', 'Registros')),
      if (settings.insightsEnabled) (_Tab.summary, tr(context, 'Summary', 'Síntesis')),
    ];
    final tab = tabs.any((t) => t.$1 == _tab) ? _tab : _Tab.overview;

    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: title,
        showBackButton: true,
        actions: [
          PrismTopBarAction(icon: AppIcons.editOutlined, tooltip: tr(context, 'Edit', 'Editar'), onPressed: () => showRelEditor(context, editing: rel)),
          PrismTopBarAction(
            icon: AppIcons.deleteOutline,
            tooltip: tr(context, 'Delete', 'Eliminar'),
            onPressed: () async {
              final router = GoRouter.of(context);
              if (await confirmDeleteRel(context, ref, rel)) {
                if (router.canPop()) router.pop();
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, NavBarInset.of(context) + 32),
        children: [
          ClampedBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(rel: rel, alters: alters, settings: settings),
                const SizedBox(height: 14),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [for (final (t, l) in tabs) Padding(padding: const EdgeInsets.only(right: 6), child: PrismChip(label: l, selected: t == tab, onTap: () => setState(() => _tab = t)))],
                  ),
                ),
                const SizedBox(height: 12),
                switch (tab) {
                  _Tab.overview => _Overview(rel: rel),
                  _Tab.notes => _Notes(rel: rel),
                  _Tab.timeline => _Timeline(rel: rel),
                  _Tab.checkins => _Checkins(rel: rel),
                  _Tab.summary => _Summary(rel: rel),
                },
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.rel, required this.alters, required this.settings});
  final Rel rel;
  final Map<String, Member> alters;
  final RelSettings settings;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final prefer = ref.watch(memberNamePreferDisplayProvider);
    final df = DateFormat.yMMMd(context.dateLocale);
    Widget person(String? id, String? fallback) {
      final m = alters[id];
      return Expanded(
        child: GestureDetector(
          onTap: m == null ? null : () => context.push(AppRoutePaths.member(m.id)),
          child: Column(
            children: [
              if (m != null) relAvatar(ref, m, 56) else CircleAvatar(radius: 28, child: Icon(PhosphorIcons.user())),
              const SizedBox(height: 6),
              Text(m?.effectiveName(preferDisplayName: prefer) ?? fallback ?? '—', textAlign: TextAlign.center, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              if ((m?.pronouns ?? '').isNotEmpty) Text(m!.pronouns!, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      );
    }

    final directional = rel.labels.any((l) => relLabelIndex[l]?.directional ?? false);
    return PrismSurface(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              person(rel.a, null),
              Padding(padding: const EdgeInsets.only(top: 18), child: Icon(directional ? PhosphorIcons.arrowRight() : PhosphorIcons.arrowsLeftRight(), color: theme.colorScheme.primary)),
              person(rel.b, rel.otherName),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final l in rel.labels) RelLabelPill(label: l, settings: settings),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 4,
            children: [
              _Meta(PhosphorIcons.pulse(), relStatusText(context, rel.status)),
              _Meta(PhosphorIcons.sealCheck(), relConfidenceText(context, rel.confidence)),
              if (rel.private) _Meta(PhosphorIcons.lockSimple(), tr(context, 'Private', 'Privada')),
              _Meta(PhosphorIcons.calendarBlank(), tr(context, 'Since ${df.format(rel.documented)}', 'Desde ${df.format(rel.documented)}')),
              _Meta(PhosphorIcons.clockCounterClockwise(), tr(context, 'Updated ${df.format(rel.updated)}', 'Actualizada ${df.format(rel.updated)}')),
            ],
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant), const SizedBox(width: 4), Text(text, style: theme.textTheme.bodySmall)]);
  }
}

/// A label with its style colour and a text name (never colour alone).
class RelLabelPill extends StatelessWidget {
  const RelLabelPill({super.key, required this.label, required this.settings});
  final String label;
  final RelSettings settings;
  @override
  Widget build(BuildContext context) {
    final c = relColor(settings, styleOf(label, settings));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(999), border: Border.all(color: c.withValues(alpha: 0.5))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(labelText(context, label, settings), style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.rel});
  final Rel rel;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final set = [for (final k in relDynamics) if (rel.dyn(k) != null) (k, rel.dyn(k)!)];
    final boundaries = rel.r.strings(RelField.boundaries);
    final dynNote = rel.r.str(RelField.dynamics);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(
          title: tr(context, 'Description', 'Descripción'),
          child: rel.description.isEmpty
              ? Text(tr(context, 'No description yet — tap edit to add one.', 'Aún no hay descripción: toca editar para añadirla.'), style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))
              : PrivateReveal(isPrivate: rel.private, child: Text(rel.description, style: theme.textTheme.bodyLarge?.copyWith(height: 1.5))),
        ),
        if (set.isNotEmpty)
          _Section(
            title: tr(context, 'Dynamics', 'Dinámica'),
            child: Column(
              children: [
                for (final (k, v) in set)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Semantics(
                      label: '${relDynamicLabel(context, k)}: $v / 5',
                      child: Row(
                        children: [
                          SizedBox(width: 150, child: Text(relDynamicLabel(context, k))),
                          Expanded(child: Row(children: [for (var i = 1; i <= 5; i++) Expanded(child: Container(height: 8, margin: const EdgeInsets.only(right: 3), decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: i <= v ? theme.colorScheme.primary : theme.colorScheme.primary.withValues(alpha: 0.15))))])),
                          const SizedBox(width: 8),
                          Text('$v/5', style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
                Text(tr(context, 'Set by you — not measured.', 'Definido por ti, no medido.'), style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        if ((dynNote ?? '').isNotEmpty) _Section(title: tr(context, 'Dynamics notes', 'Notas sobre la dinámica'), child: PrivateReveal(isPrivate: rel.private, child: Text(dynNote!))),
        if (boundaries.isNotEmpty) _Section(title: tr(context, 'Boundaries', 'Límites'), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final b in boundaries) Text('• $b')])),
        RelatedRecordsSection(self: RecordRef(RecordRef.rec, rel.id)),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PrismSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Notes ─────────────────────────

class _Notes extends ConsumerWidget {
  const _Notes({required this.rel});
  final Rel rel;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notes = ref.watch(relChildrenProvider((TrackerKind.relationshipNote, rel.id)));
    final df = DateFormat.yMMMd(context.dateLocale);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(alignment: Alignment.centerRight, child: PrismButton(label: tr(context, 'Add note', 'Añadir nota'), icon: AppIcons.add, tone: PrismButtonTone.filled, onPressed: () => _editNote(context, ref, rel, null))),
        const SizedBox(height: 10),
        if (notes.isEmpty) _empty(context, tr(context, 'No notes yet.', 'Aún no hay notas.')),
        for (final n in notes)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PrismSurface(
              onTap: () => _editNote(context, ref, rel, n),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [Expanded(child: Text(n.title.isEmpty ? tr(context, 'Untitled', 'Sin título') : n.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))), Text(df.format(n.occurredAt ?? n.createdAt), style: theme.textTheme.bodySmall)]),
                  if ((n.body ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: PrivateReveal(isPrivate: n.isPrivate, child: Text(n.body!, maxLines: 6, overflow: TextOverflow.ellipsis))),
                  if (n.tags.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Wrap(spacing: 4, children: [for (final t in n.tags) Text('#$t', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary))])),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

Widget _empty(BuildContext context, String text) => Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)));

/// Chips for the alters on a relationship (for notes and events).
Widget _alterChips(BuildContext context, WidgetRef ref, Rel rel, Set<String> sel, void Function(void Function()) set) {
  final alters = ref.read(relAlterIndexProvider);
  final prefer = ref.read(memberNamePreferDisplayProvider);
  return Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final id in [?rel.a, ?rel.b])
        if (alters[id] case final m?) PrismChip(label: m.effectiveName(preferDisplayName: prefer), selected: sel.contains(id), onTap: () => set(() => sel.contains(id) ? sel.remove(id) : sel.add(id))),
    ],
  );
}

Future<void> _editNote(BuildContext context, WidgetRef ref, Rel rel, TrackerRecord? n) async {
  final title = TextEditingController(text: n?.title);
  final body = TextEditingController(text: n?.body);
  final tags = TextEditingController(text: n?.tags.join(' '));
  var date = n?.occurredAt ?? DateTime.now();
  var private = n?.isPrivate ?? false;
  final sel = {...?n?.strings('alters')};
  String? error;
  await PrismSheet.show(
    context: context,
    title: n == null ? tr(context, 'New note', 'Nueva nota') : tr(context, 'Edit note', 'Editar nota'),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PrismTextField(controller: title, labelText: tr(ctx, 'Title', 'Título')),
            const SizedBox(height: 10),
            PrismTextField(controller: body, labelText: tr(ctx, 'Note', 'Nota'), minLines: 4, maxLines: 14),
            const SizedBox(height: 10),
            PrismTextField(controller: tags, labelText: tr(ctx, 'Tags (space-separated)', 'Etiquetas (separadas por espacios)')),
            const SizedBox(height: 10),
            TrackerLabel(tr(ctx, 'About', 'Sobre')),
            _alterChips(ctx, ref, rel, sel, set),
            const SizedBox(height: 10),
            PrismButton(
              label: DateFormat.yMMMd(ctx.dateLocale).format(date),
              icon: PhosphorIcons.calendar(),
              onPressed: () async {
                final d = await showPrismDatePicker(context: ctx, initialDate: date, firstDate: DateTime(1990), lastDate: DateTime.now().add(const Duration(days: 1)));
                if (d != null) set(() => date = d);
              },
            ),
            PrismSwitchRow(title: tr(ctx, 'Private note', 'Nota privada'), value: private, onChanged: (v) => set(() => private = v)),
            if (error != null) Text(error!, style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
            const SizedBox(height: 8),
            Row(
              children: [
                if (n != null)
                  PrismButton(
                    label: tr(ctx, 'Delete', 'Eliminar'),
                    tone: PrismButtonTone.destructive,
                    onPressed: () async {
                      final ok = await PrismDialog.confirm(context: ctx, title: tr(ctx, 'Delete this note?', '¿Eliminar esta nota?'), destructive: true, confirmLabel: tr(ctx, 'Delete', 'Eliminar'), cancelLabel: ctx.l10n.cancel);
                      if (ok != true) return;
                      await ref.read(trackerNotifierProvider.notifier).delete(n.id);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                  ),
                const Spacer(),
                PrismButton(
                  label: ctx.l10n.save,
                  tone: PrismButtonTone.filled,
                  onPressed: () async {
                    if (title.text.trim().isEmpty && body.text.trim().isEmpty) {
                      set(() => error = tr(ctx, 'Add a title or some text.', 'Añade un título o algo de texto.'));
                      return;
                    }
                    final t = ref.read(trackerNotifierProvider.notifier);
                    final tagList = [for (final x in tags.text.split(RegExp(r'[\s,]+'))) if (x.trim().isNotEmpty) x.trim()];
                    if (n == null) {
                      await t.create(kind: TrackerKind.relationshipNote, parentId: rel.id, title: title.text.trim(), body: body.text.trim(), tags: tagList, occurredAt: date, isPrivate: private, fields: {'alters': sel.toList()});
                    } else {
                      await t.save(n.copyWith(title: title.text.trim(), body: body.text.trim(), tags: tagList, occurredAt: date, isPrivate: private).withFields({'alters': sel.toList()}));
                    }
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

// ───────────────────────── Timeline ─────────────────────────

const relEventCategories = ['met', 'friends', 'changed', 'conversation', 'conflict', 'reconciliation', 'milestone', 'closeness', 'memory', 'ended', 'restarted', 'other'];

String relEventCategoryText(BuildContext c, String k) => switch (k) {
  'met' => tr(c, 'First met', 'Se conocieron'),
  'friends' => tr(c, 'Became friends', 'Se hicieron amigos'),
  'changed' => tr(c, 'Relationship changed', 'Cambió la relación'),
  'conversation' => tr(c, 'Important conversation', 'Conversación importante'),
  'conflict' => tr(c, 'Conflict', 'Conflicto'),
  'reconciliation' => tr(c, 'Reconciliation', 'Reconciliación'),
  'milestone' => tr(c, 'Milestone', 'Hito'),
  'closeness' => tr(c, 'Closeness changed', 'Cambió la cercanía'),
  'memory' => tr(c, 'Memory', 'Recuerdo'),
  'ended' => tr(c, 'Ended', 'Terminó'),
  'restarted' => tr(c, 'Restarted', 'Se retomó'),
  _ => tr(c, 'Other', 'Otro'),
};

class _Timeline extends ConsumerWidget {
  const _Timeline({required this.rel});
  final Rel rel;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final events = [...ref.watch(relChildrenProvider((TrackerKind.relationshipEvent, rel.id)))].reversed.toList();
    final df = DateFormat.yMMMd(context.dateLocale);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(alignment: Alignment.centerRight, child: PrismButton(label: tr(context, 'Add event', 'Añadir evento'), icon: AppIcons.add, tone: PrismButtonTone.filled, onPressed: () => _editEvent(context, ref, rel, null))),
        const SizedBox(height: 10),
        if (events.isEmpty) _empty(context, tr(context, 'Record when they met, milestones, conflicts and changes — in your own words.', 'Registra cuándo se conocieron, hitos, conflictos y cambios, con tus palabras.')),
        for (final (i, e) in events.indexed)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 24,
                  child: Column(
                    children: [
                      Container(width: 12, height: 12, margin: const EdgeInsets.only(top: 6), decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.primary)),
                      if (i < events.length - 1) Expanded(child: Container(width: 2, color: theme.colorScheme.outlineVariant)),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12, left: 4),
                    child: PrismSurface(
                      onTap: () => _editEvent(context, ref, rel, e),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(df.format(e.occurredAt ?? e.createdAt), style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
                          Text(e.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                          if (e.str('category') != null) Text(relEventCategoryText(context, e.str('category')!), style: theme.textTheme.bodySmall),
                          if ((e.body ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(e.body!, maxLines: 5, overflow: TextOverflow.ellipsis)),
                          if (e.strings('media').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Wrap(spacing: 6, children: [for (final m in e.strings('media').take(4)) ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: 56, height: 56, child: PrismMediaView(id: m)))]),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

Future<void> _editEvent(BuildContext context, WidgetRef ref, Rel rel, TrackerRecord? e) async {
  final title = TextEditingController(text: e?.title);
  final body = TextEditingController(text: e?.body);
  var date = e?.occurredAt ?? DateTime.now();
  String? cat = e?.str('category');
  var sentiment = e?.integer(RelField.sentiment) ?? 0;
  var media = [...?e?.strings('media')];
  final sel = {...?e?.strings('alters'), if (e == null) ...[?rel.a, ?rel.b]};
  String? error;
  await PrismSheet.showFullScreen(
    context: context,
    builder: (ctx, scroll) => StatefulBuilder(
      builder: (ctx, set) => ListView(
        controller: scroll,
        padding: const EdgeInsets.all(16),
        children: [
          Text(e == null ? tr(ctx, 'New timeline event', 'Nuevo evento') : tr(ctx, 'Edit event', 'Editar evento'), style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          PrismTextField(controller: title, labelText: tr(ctx, 'Title', 'Título')),
          const SizedBox(height: 10),
          PrismButton(
            label: DateFormat.yMMMd(ctx.dateLocale).format(date),
            icon: PhosphorIcons.calendar(),
            onPressed: () async {
              final d = await showPrismDatePicker(context: ctx, initialDate: date, firstDate: DateTime(1950), lastDate: DateTime.now().add(const Duration(days: 1)));
              if (d != null) set(() => date = d);
            },
          ),
          const SizedBox(height: 10),
          TrackerLabel(tr(ctx, 'Category (optional)', 'Categoría (opcional)')),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final c in relEventCategories) PrismChip(label: relEventCategoryText(ctx, c), selected: cat == c, onTap: () => set(() => cat = cat == c ? null : c))]),
          const SizedBox(height: 10),
          TrackerLabel(tr(ctx, 'How it felt', 'Cómo se sintió')),
          PrismSegmentedControl<int>(
            segments: [PrismSegment(value: -1, label: tr(ctx, 'Hard', 'Difícil')), PrismSegment(value: 0, label: tr(ctx, 'Neutral', 'Neutral')), PrismSegment(value: 1, label: tr(ctx, 'Good', 'Bien'))],
            selected: sentiment,
            onChanged: (v) => set(() => sentiment = v),
          ),
          const SizedBox(height: 10),
          PrismTextField(controller: body, labelText: tr(ctx, 'Description', 'Descripción'), minLines: 3, maxLines: 12),
          const SizedBox(height: 10),
          TrackerLabel(tr(ctx, 'Alters involved', 'Alters implicados')),
          _alterChips(ctx, ref, rel, sel, set),
          const SizedBox(height: 10),
          MediaAttachRow(ids: media, allowAudio: true, onChanged: (v) => set(() => media = v)),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: TextStyle(color: Theme.of(ctx).colorScheme.error))),
          const SizedBox(height: 16),
          Row(
            children: [
              if (e != null)
                PrismButton(
                  label: tr(ctx, 'Delete', 'Eliminar'),
                  tone: PrismButtonTone.destructive,
                  onPressed: () async {
                    final ok = await PrismDialog.confirm(context: ctx, title: tr(ctx, 'Delete this event?', '¿Eliminar este evento?'), destructive: true, confirmLabel: tr(ctx, 'Delete', 'Eliminar'), cancelLabel: ctx.l10n.cancel);
                    if (ok != true) return;
                    await ref.read(trackerNotifierProvider.notifier).delete(e.id);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                ),
              const Spacer(),
              PrismButton(label: ctx.l10n.cancel, onPressed: () => Navigator.of(ctx).pop()),
              const SizedBox(width: 8),
              PrismButton(
                label: ctx.l10n.save,
                tone: PrismButtonTone.filled,
                onPressed: () async {
                  if (title.text.trim().isEmpty) {
                    set(() => error = tr(ctx, 'Give the event a title.', 'Ponle un título al evento.'));
                    return;
                  }
                  final t = ref.read(trackerNotifierProvider.notifier);
                  final f = {RelField.sentiment: sentiment, 'category': cat, 'media': media.isEmpty ? null : media, 'alters': sel.toList()};
                  if (e == null) {
                    await t.create(kind: TrackerKind.relationshipEvent, parentId: rel.id, memberId: rel.a, title: title.text.trim(), body: body.text.trim(), occurredAt: date, fields: f);
                  } else {
                    await t.save(e.copyWith(title: title.text.trim(), body: body.text.trim(), occurredAt: date).withFields(f));
                  }
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

// ───────────────────────── Check-ins ─────────────────────────

String checkinRatingText(BuildContext c, String k) => switch (k) {
  'feel' => tr(c, 'How it feels', 'Cómo se siente'),
  'comfort' => tr(c, 'Comfort', 'Comodidad'),
  'communication' => tr(c, 'Communication', 'Comunicación'),
  'conflict' => tr(c, 'Conflict', 'Conflicto'),
  _ => k,
};

Map<String, int> checkinRatingsOf(TrackerRecord c) {
  final m = c.fields['ratings'];
  if (m is! Map) return const {};
  return {for (final e in m.entries) if (e.value is num) '${e.key}': (e.value as num).toInt()};
}

class _Checkins extends ConsumerStatefulWidget {
  const _Checkins({required this.rel});
  final Rel rel;
  @override
  ConsumerState<_Checkins> createState() => _CheckinsState();
}

class _CheckinsState extends ConsumerState<_Checkins> {
  final _compare = <String>{};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final list = ref.watch(relChildrenProvider((TrackerKind.relationshipCheckin, widget.rel.id)));
    final df = DateFormat.yMMMd(context.dateLocale);
    final chrono = list.reversed.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr(context, 'Optional, dated reflections. Ratings are your impressions, not measurements.', 'Reflexiones opcionales y fechadas. Las puntuaciones son impresiones, no mediciones.'), style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        Row(
          children: [
            if (_compare.length == 2)
              PrismButton(
                label: tr(context, 'Compare', 'Comparar'),
                icon: PhosphorIcons.columns(),
                onPressed: () => _showCompare(context, [for (final c in chrono) if (_compare.contains(c.id)) c]),
              ),
            const Spacer(),
            PrismButton(label: tr(context, 'New check-in', 'Nuevo registro'), icon: AppIcons.add, tone: PrismButtonTone.filled, onPressed: () => _editCheckin(context, ref, widget.rel, null)),
          ],
        ),
        if (chrono.where((c) => checkinRatingsOf(c).isNotEmpty).length >= 2) ...[
          const SizedBox(height: 12),
          PrismSurface(
            child: SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  minY: 1,
                  maxY: 5,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: const FlTitlesData(topTitles: AxisTitles(), rightTitles: AxisTitles(), bottomTitles: AxisTitles()),
                  lineBarsData: [
                    for (final (i, k) in checkinRatings.indexed)
                      LineChartBarData(
                        spots: [for (final (j, c) in chrono.indexed) if (checkinRatingsOf(c)[k] != null) FlSpot(j.toDouble(), checkinRatingsOf(c)[k]!.toDouble())],
                        color: [theme.colorScheme.primary, theme.colorScheme.secondary, theme.colorScheme.tertiary, theme.colorScheme.error][i],
                        barWidth: 2,
                        dotData: const FlDotData(show: true),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(spacing: 10, children: [for (final (i, k) in checkinRatings.indexed) Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 10, height: 3, color: [theme.colorScheme.primary, theme.colorScheme.secondary, theme.colorScheme.tertiary, theme.colorScheme.error][i]), const SizedBox(width: 4), Text(checkinRatingText(context, k), style: theme.textTheme.labelSmall)])]),
        ],
        const SizedBox(height: 10),
        if (list.isEmpty) _empty(context, tr(context, 'No check-ins yet.', 'Aún no hay registros.')),
        if (list.length >= 2) Text(tr(context, 'Select two check-ins to compare them.', 'Selecciona dos registros para compararlos.'), style: theme.textTheme.bodySmall),
        for (final c in list)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: PrismSurface(
              onTap: () => _editCheckin(context, ref, widget.rel, c),
              child: Row(
                children: [
                  if (list.length >= 2)
                    Checkbox(value: _compare.contains(c.id), onChanged: (v) => setState(() => v == true ? (_compare.length < 2 ? _compare.add(c.id) : null) : _compare.remove(c.id))),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(df.format(c.occurredAt ?? c.createdAt), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        if (checkinRatingsOf(c).isNotEmpty) Text(checkinRatingsOf(c).entries.map((e) => '${checkinRatingText(context, e.key)} ${e.value}/5').join(' · '), style: theme.textTheme.bodySmall),
                        if ((c.body ?? '').isNotEmpty) Text(c.body!, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _showCompare(BuildContext context, List<TrackerRecord> two) {
    final df = DateFormat.yMMMd(context.dateLocale);
    final qs = {for (final c in two) ...((c.fields['answers'] as Map?)?.keys.map((k) => '$k') ?? const <String>[])};
    PrismSheet.showFullScreen(
      context: context,
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.all(16),
        children: [
          Text(tr(ctx, 'Compare check-ins', 'Comparar registros'), style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(children: [const Expanded(flex: 2, child: SizedBox()), for (final c in two) Expanded(flex: 3, child: Text(df.format(c.occurredAt ?? c.createdAt), style: const TextStyle(fontWeight: FontWeight.w700)))]),
          const Divider(),
          for (final k in checkinRatings)
            if (two.any((c) => checkinRatingsOf(c)[k] != null))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [Expanded(flex: 2, child: Text(checkinRatingText(ctx, k))), for (final c in two) Expanded(flex: 3, child: Text(checkinRatingsOf(c)[k] == null ? '—' : '${checkinRatingsOf(c)[k]}/5'))]),
              ),
          const Divider(),
          for (final q in qs)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(q, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final c in two) Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: Text('${(c.fields['answers'] as Map?)?[q] ?? '—'}')))]),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> _editCheckin(BuildContext context, WidgetRef ref, Rel rel, TrackerRecord? c) async {
  final settings = ref.read(relSettingsProvider);
  final answersRaw = (c?.fields['answers'] as Map?) ?? const {};
  final questions = [...settings.checkinQuestions, for (final k in answersRaw.keys) if (!settings.checkinQuestions.contains('$k')) '$k'];
  final ctrls = {for (final q in questions) q: TextEditingController(text: '${answersRaw[q] ?? ''}')};
  final ratings = <String, int?>{for (final k in checkinRatings) k: c == null ? null : checkinRatingsOf(c)[k]};
  final notes = TextEditingController(text: c?.body);
  final custom = TextEditingController();
  var date = c?.occurredAt ?? DateTime.now();
  await PrismSheet.showFullScreen(
    context: context,
    builder: (ctx, scroll) => StatefulBuilder(
      builder: (ctx, set) => ListView(
        controller: scroll,
        padding: const EdgeInsets.all(16),
        children: [
          Text(c == null ? tr(ctx, 'Relationship check-in', 'Registro de la relación') : tr(ctx, 'Edit check-in', 'Editar registro'), style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          PrismButton(
            label: DateFormat.yMMMd(ctx.dateLocale).format(date),
            icon: PhosphorIcons.calendar(),
            onPressed: () async {
              final d = await showPrismDatePicker(context: ctx, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 1)));
              if (d != null) set(() => date = d);
            },
          ),
          const SizedBox(height: 12),
          for (final q in ctrls.keys) Padding(padding: const EdgeInsets.only(bottom: 10), child: PrismTextField(controller: ctrls[q], labelText: q, minLines: 1, maxLines: 5)),
          Row(
            children: [
              Expanded(child: PrismTextField(controller: custom, hintText: tr(ctx, 'Add your own question', 'Añade tu propia pregunta'))),
              const SizedBox(width: 8),
              PrismButton(
                label: tr(ctx, 'Add', 'Añadir'),
                onPressed: () => set(() {
                  final q = custom.text.trim();
                  if (q.isEmpty || ctrls.containsKey(q)) return;
                  ctrls[q] = TextEditingController();
                  custom.clear();
                }),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(tr(ctx, 'Optional ratings', 'Puntuaciones opcionales'), style: Theme.of(ctx).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          for (final k in checkinRatings)
            Row(
              children: [
                SizedBox(width: 130, child: Text(checkinRatingText(ctx, k))),
                Expanded(
                  child: ratings[k] == null
                      ? Align(alignment: Alignment.centerLeft, child: PrismChip(label: tr(ctx, 'Not set', 'Sin valorar'), selected: false, onTap: () => set(() => ratings[k] = 3)))
                      : Slider(value: ratings[k]!.toDouble(), min: 1, max: 5, divisions: 4, label: '${ratings[k]}', onChanged: (v) => set(() => ratings[k] = v.round())),
                ),
                if (ratings[k] != null) PrismTopBarAction(icon: AppIcons.close, tooltip: tr(ctx, 'Clear', 'Quitar'), onPressed: () => set(() => ratings[k] = null)),
              ],
            ),
          const SizedBox(height: 10),
          PrismTextField(controller: notes, labelText: tr(ctx, 'Notes', 'Notas'), minLines: 2, maxLines: 8),
          const SizedBox(height: 16),
          Row(
            children: [
              if (c != null)
                PrismButton(
                  label: tr(ctx, 'Delete', 'Eliminar'),
                  tone: PrismButtonTone.destructive,
                  onPressed: () async {
                    final ok = await PrismDialog.confirm(context: ctx, title: tr(ctx, 'Delete this check-in?', '¿Eliminar este registro?'), destructive: true, confirmLabel: tr(ctx, 'Delete', 'Eliminar'), cancelLabel: ctx.l10n.cancel);
                    if (ok != true) return;
                    await ref.read(trackerNotifierProvider.notifier).delete(c.id);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                ),
              const Spacer(),
              PrismButton(label: ctx.l10n.cancel, onPressed: () => Navigator.of(ctx).pop()),
              const SizedBox(width: 8),
              PrismButton(
                label: ctx.l10n.save,
                tone: PrismButtonTone.filled,
                onPressed: () async {
                  final answers = {for (final e in ctrls.entries) if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim()};
                  final r = {for (final e in ratings.entries) if (e.value != null) e.key: e.value};
                  final f = {'answers': answers.isEmpty ? null : answers, 'ratings': r.isEmpty ? null : r};
                  final t = ref.read(trackerNotifierProvider.notifier);
                  if (c == null) {
                    await t.create(kind: TrackerKind.relationshipCheckin, parentId: rel.id, body: notes.text.trim(), occurredAt: date, fields: f);
                  } else {
                    await t.save(c.copyWith(body: notes.text.trim(), occurredAt: date).withFields(f));
                  }
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

// ───────────────────────── Summary ─────────────────────────

class _Summary extends ConsumerWidget {
  const _Summary({required this.rel});
  final Rel rel;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final lines = summarizeRelationship(
      rel: rel,
      events: ref.watch(relChildrenProvider((TrackerKind.relationshipEvent, rel.id))),
      checkins: ref.watch(relChildrenProvider((TrackerKind.relationshipCheckin, rel.id))),
      notes: ref.watch(relChildrenProvider((TrackerKind.relationshipNote, rel.id))),
      locale: context.dateLocale,
    );
    return _Section(
      title: tr(context, 'From your records', 'Según tus registros'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final l in lines) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('• ${tr(context, l.$1, l.$2)}')),
          const SizedBox(height: 6),
          Text(
            tr(context, 'This summary only restates what is documented here (dates, timeline events, check-ins, notes). It makes no judgement about the alters.', 'Esta síntesis solo resume lo documentado aquí (fechas, eventos, registros, notas). No juzga a los alters.'),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
