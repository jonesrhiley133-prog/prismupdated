import 'package:prism_plurality/shared/widgets/section_switcher.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/links/models/record_ref.dart';
import 'package:prism_plurality/features/links/widgets/related_records.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/media/prism_media.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Field keys inside a dream record's data.
abstract final class DreamField {
  static const members = 'members';
  static const emotions = 'emotions';
  static const themes = 'themes';
  static const symbols = 'symbols';
  static const rating = 'rating';
  static const types = 'types';
  static const interpretation = 'interpretation';
  static const reflection = 'reflection';
  static const media = 'media';
  static const lucidity = 'lucidity';
}

const dreamTypes = [
  ('vivid', 'Vivid', 'Vívido', '✨'),
  ('lucid', 'Lucid', 'Lúcido', '🌀'),
  ('nightmare', 'Nightmare', 'Pesadilla', '🌩️'),
  ('recurring', 'Recurring', 'Recurrente', '🔁'),
  ('fragment', 'Fragment', 'Fragmento', '🧩'),
  ('shared', 'Shared with alters', 'Compartido con alters', '👥'),
  ('calm', 'Peaceful', 'Tranquilo', '🌙'),
];

const dreamEmotions = [
  ('joy', 'Joy', 'Alegría'),
  ('fear', 'Fear', 'Miedo'),
  ('sadness', 'Sadness', 'Tristeza'),
  ('anger', 'Anger', 'Enfado'),
  ('confusion', 'Confusion', 'Confusión'),
  ('wonder', 'Wonder', 'Asombro'),
  ('calm', 'Calm', 'Calma'),
  ('anxiety', 'Anxiety', 'Ansiedad'),
  ('love', 'Love', 'Amor'),
  ('shame', 'Shame', 'Vergüenza'),
  ('excitement', 'Excitement', 'Emoción'),
  ('nostalgia', 'Nostalgia', 'Nostalgia'),
];

String emotionLabel(BuildContext c, String key) {
  final e = dreamEmotions.where((x) => x.$1 == key).firstOrNull;
  return e == null ? key : tr(c, e.$2, e.$3);
}

void registerDreamOpener(
  Map<String, void Function(BuildContext, String)> openers,
) {
  openers[TrackerKind.dreamEntry] = (context, id) =>
      showDreamDetail(context, id);
}

enum _DreamView { list, calendar, insights }

class DreamJournalView extends ConsumerStatefulWidget {
  const DreamJournalView({super.key});
  @override
  ConsumerState<DreamJournalView> createState() => _DreamJournalViewState();
}

class _DreamJournalViewState extends ConsumerState<DreamJournalView> {
  _DreamView _view = _DreamView.list;
  final _q = TextEditingController();
  String? _member;
  String? _type;
  String? _tag;
  DateTime _month = DateTime.now();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  bool _match(TrackerRecord r) {
    final q = _q.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      final hay = [
        r.title,
        r.body ?? '',
        ...r.tags,
        ...r.strings(DreamField.themes),
        ...r.strings(DreamField.symbols),
      ].join(' ').toLowerCase();
      if (!hay.contains(q)) return false;
    }
    if (_member != null &&
        r.memberId != _member &&
        !r.strings(DreamField.members).contains(_member))
      return false;
    if (_type != null && !r.strings(DreamField.types).contains(_type))
      return false;
    if (_tag != null &&
        !r.tags.contains(_tag) &&
        !r.strings(DreamField.themes).contains(_tag))
      return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(trackerKindProvider(TrackerKind.dreamEntry));
    return async.when(
      loading: () => const PrismLoadingState(),
      error: (e, _) => Center(child: Text(context.l10n.errorWithDetail(e))),
      data: (dreams) {
        if (dreams.isEmpty) {
          return EmptyState(
            icon: Icon(PhosphorIcons.cloudMoon()),
            title: tr(
              context,
              'Your dream journal is empty',
              'Tu diario de sueños está vacío',
            ),
            subtitle: tr(
              context,
              'Write dreams down soon after waking — even fragments help you notice patterns.',
              'Escribe los sueños al despertar; incluso los fragmentos ayudan a notar patrones.',
            ),
            actionLabel: tr(context, 'Record a dream', 'Registrar un sueño'),
            onAction: () => showDreamEditor(context),
          );
        }
        final shown = [
          for (final d in dreams)
            if (_match(d)) d,
        ];
        return ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, NavBarInset.of(context) + 24),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: PrismTokens.contentMaxWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        for (final v in _DreamView.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: PrismChip(
                              label: switch (v) {
                                _DreamView.list => tr(
                                  context,
                                  'Entries',
                                  'Entradas',
                                ),
                                _DreamView.calendar => tr(
                                  context,
                                  'Calendar',
                                  'Calendario',
                                ),
                                _DreamView.insights => tr(
                                  context,
                                  'Patterns',
                                  'Patrones',
                                ),
                              },
                              selected: _view == v,
                              onTap: () => setState(() => _view = v),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_view != _DreamView.insights) ...[
                      PrismTextField(
                        controller: _q,
                        hintText: tr(
                          context,
                          'Search dreams, themes, symbols',
                          'Buscar sueños, temas, símbolos',
                        ),
                        prefixIcon: Icon(AppIcons.search),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final t in dreamTypes)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: PrismChip(
                                  label: '${t.$4} ${tr(context, t.$2, t.$3)}',
                                  selected: _type == t.$1,
                                  onTap: () => setState(
                                    () => _type = _type == t.$1 ? null : t.$1,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      TrackerMemberFilter(
                        value: _member,
                        onChanged: (m) => setState(() => _member = m),
                        onlyIds: {
                          for (final d in dreams) ?d.memberId,
                          for (final d in dreams)
                            ...d.strings(DreamField.members),
                        },
                      ),
                      if (_tag != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: PrismChip(
                            label: '#$_tag ✕',
                            selected: true,
                            onTap: () => setState(() => _tag = null),
                          ),
                        ),
                    ],
                    const SizedBox(height: 8),
                    SectionSwitcher(
                      id: _view,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ...switch (_view) {
                            _DreamView.list => _list(shown),
                            _DreamView.calendar => [
                              _DreamCalendar(
                                dreams: shown,
                                month: _month,
                                onMonth: (m) => setState(() => _month = m),
                              ),
                            ],
                            _DreamView.insights => [
                              _DreamInsights(
                                dreams: dreams,
                                onTag: (t) => setState(() {
                                  _tag = t;
                                  _view = _DreamView.list;
                                }),
                              ),
                            ],
                          },
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _list(List<TrackerRecord> shown) {
    if (shown.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              tr(context, 'No matching dreams', 'No hay sueños que coincidan'),
            ),
          ),
        ),
      ];
    }
    final out = <Widget>[];
    String? month;
    for (final d in shown) {
      final m = DateFormat.yMMMM(
        context.dateLocale,
      ).format(d.occurredAt ?? d.createdAt);
      if (m != month) {
        month = m;
        out.add(TrackerLabel(m));
      }
      out.add(DreamCard(dream: d));
    }
    return out;
  }
}

class DreamCard extends ConsumerWidget {
  const DreamCard({super.key, required this.dream});
  final TrackerRecord dream;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final d = dream.occurredAt ?? dream.createdAt;
    final types = dream.strings(DreamField.types);
    final rating = dream.integer(DreamField.rating);
    final media = dream
        .strings(DreamField.media)
        .where((m) => !m.startsWith('audio:'))
        .toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PrismSurface(
        onTap: () => showDreamDetail(context, dream.id),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [
                      DateFormat.MMMEd(context.dateLocale).format(d),
                      for (final t in types)
                        dreamTypes.where((x) => x.$1 == t).firstOrNull?.$4 ??
                            '',
                      if (rating != null) '★' * rating,
                    ].join(' · '),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dream.title.isEmpty
                        ? tr(context, 'Untitled dream', 'Sueño sin título')
                        : dream.title,
                    style: theme.textTheme.titleSmall,
                  ),
                  if (dream.body != null)
                    PrivateReveal(
                      isPrivate: dream.isPrivate,
                      child: Text(
                        dream.body!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  if (dream.strings(DreamField.themes).isNotEmpty) ...[
                    const SizedBox(height: 4),
                    TagWrap(tags: dream.strings(DreamField.themes)),
                  ],
                ],
              ),
            ),
            if (media.isNotEmpty && !dream.isPrivate) ...[
              const SizedBox(width: 10),
              ClipRRect(
                borderRadius: prismCorners(context, 10),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: PrismMediaView(id: media.first),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DreamCalendar extends StatelessWidget {
  const _DreamCalendar({
    required this.dreams,
    required this.month,
    required this.onMonth,
  });
  final List<TrackerRecord> dreams;
  final DateTime month;
  final ValueChanged<DateTime> onMonth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = DateTime(month.year, month.month);
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final byDay = <int, List<TrackerRecord>>{};
    for (final d in dreams) {
      final t = d.occurredAt ?? d.createdAt;
      if (t.year == month.year && t.month == month.month)
        byDay.putIfAbsent(t.day, () => []).add(d);
    }
    final lead = first.weekday - 1;
    final monday = DateTime(2024, 1, 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: tr(context, 'Previous month', 'Mes anterior'),
              icon: Icon(PhosphorIcons.caretLeft()),
              onPressed: () => onMonth(DateTime(month.year, month.month - 1)),
            ),
            Expanded(
              child: Text(
                DateFormat.yMMMM(context.dateLocale).format(first),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall,
              ),
            ),
            IconButton(
              tooltip: tr(context, 'Next month', 'Mes siguiente'),
              icon: Icon(PhosphorIcons.caretRight()),
              onPressed: () => onMonth(DateTime(month.year, month.month + 1)),
            ),
          ],
        ),
        CompactCalendar(
          child: Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      DateFormat.E(
                        context.dateLocale,
                      ).format(monday.add(Duration(days: i))),
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        CompactCalendar(
          child: GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (var i = 0; i < lead; i++) const SizedBox.shrink(),
              for (var d = 1; d <= days; d++)
                InkWell(
                  borderRadius: prismCorners(context, 10),
                  onTap: byDay[d] == null
                      ? () => showDreamEditor(
                          context,
                          date: DateTime(month.year, month.month, d, 7),
                        )
                      : () => byDay[d]!.length == 1
                            ? showDreamDetail(context, byDay[d]!.first.id)
                            : PrismSheet.show(
                                context: context,
                                builder: (ctx) => ListView(
                                  shrinkWrap: true,
                                  padding: const EdgeInsets.all(16),
                                  children: [
                                    for (final x in byDay[d]!)
                                      DreamCard(dream: x),
                                  ],
                                ),
                              ),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      borderRadius: prismCorners(context, 10),
                      color: byDay[d] == null
                          ? null
                          : const Color(0xFF7E6BD6).withValues(
                              alpha: (0.25 + byDay[d]!.length * 0.2).clamp(
                                0.25,
                                0.9,
                              ),
                            ),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$d', style: theme.textTheme.labelMedium),
                        if (byDay[d] != null)
                          Text(
                            byDay[d]!.any(
                                  (x) => x
                                      .strings(DreamField.types)
                                      .contains('nightmare'),
                                )
                                ? '🌩️'
                                : '🌙',
                            style: const TextStyle(fontSize: 10),
                          ),
                      ],
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

class _DreamInsights extends StatelessWidget {
  const _DreamInsights({required this.dreams, required this.onTag});
  final List<TrackerRecord> dreams;
  final ValueChanged<String> onTag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Map<String, int> count(Iterable<String> xs) {
      final m = <String, int>{};
      for (final x in xs) {
        final k = x.trim().toLowerCase();
        if (k.isNotEmpty) m[k] = (m[k] ?? 0) + 1;
      }
      return m;
    }

    final themes = count(
      dreams.expand((d) => [...d.strings(DreamField.themes), ...d.tags]),
    );
    final symbols = count(dreams.expand((d) => d.strings(DreamField.symbols)));
    final emotions = count(
      dreams.expand((d) => d.strings(DreamField.emotions)),
    );
    final types = count(dreams.expand((d) => d.strings(DreamField.types)));
    List<MapEntry<String, int>> top(Map<String, int> m, [int n = 8]) =>
        (m.entries.toList()..sort((a, b) => b.value - a.value))
            .take(n)
            .toList();

    // Monthly counts, last 12 months.
    final now = DateTime.now();
    final months = [
      for (var i = 11; i >= 0; i--) DateTime(now.year, now.month - i),
    ];
    final perMonth = [
      for (final m in months)
        dreams
            .where(
              (d) =>
                  (d.occurredAt ?? d.createdAt).year == m.year &&
                  (d.occurredAt ?? d.createdAt).month == m.month,
            )
            .length,
    ];
    final maxY = perMonth.fold(1, (a, b) => a > b ? a : b).toDouble();
    final ratings = [for (final d in dreams) ?d.integer(DreamField.rating)];

    // Plain-language suggestions drawn only from counts in the entries.
    final suggestions = <String>[];
    for (final e in top(themes, 3).where((e) => e.value >= 3)) {
      suggestions.add(
        tr(
          context,
          '“${e.key}” appears in ${e.value} dreams. You might look back at those entries together.',
          '«${e.key}» aparece en ${e.value} sueños. Podrías revisar esas entradas juntas.',
        ),
      );
    }
    for (final e in top(symbols, 2).where((e) => e.value >= 3)) {
      suggestions.add(
        tr(
          context,
          'The symbol “${e.key}” comes up ${e.value} times. Only you can say what it means to you.',
          'El símbolo «${e.key}» aparece ${e.value} veces. Solo tú sabes qué significa para ti.',
        ),
      );
    }
    final nightmares = types['nightmare'] ?? 0;
    if (dreams.length >= 5 && nightmares / dreams.length >= 0.3) {
      suggestions.add(
        tr(
          context,
          'About ${(nightmares * 100 / dreams.length).round()}% of recorded dreams are marked as nightmares. If they feel heavy, it may help to talk with someone you trust.',
          'Cerca del ${(nightmares * 100 / dreams.length).round()}% de los sueños están marcados como pesadillas. Si pesan, puede ayudar hablar con alguien de confianza.',
        ),
      );
    }

    Widget cloud(
      String title,
      List<MapEntry<String, int>> items, {
      bool tappable = true,
      String Function(String)? label,
    }) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TrackerLabel(title),
        if (items.isEmpty) Text('—', style: theme.textTheme.bodySmall),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final e in items)
              PrismChip(
                label: '${label?.call(e.key) ?? e.key} · ${e.value}',
                selected: false,
                variant: PrismChipVariant.inline,
                onTap: tappable ? () => onTag(e.key) : () {},
              ),
          ],
        ),
        const SizedBox(height: 10),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TrackerStatGrid(
          children: [
            TrackerStatTile(
              label: tr(context, 'Dreams recorded', 'Sueños registrados'),
              value: '${dreams.length}',
              icon: PhosphorIcons.cloudMoon(),
            ),
            TrackerStatTile(
              label: tr(context, 'Nightmares', 'Pesadillas'),
              value: '$nightmares',
              icon: PhosphorIcons.lightning(),
            ),
            TrackerStatTile(
              label: tr(context, 'Lucid', 'Lúcidos'),
              value: '${types['lucid'] ?? 0}',
              icon: PhosphorIcons.spiral(),
            ),
            TrackerStatTile(
              label: tr(context, 'Average rating', 'Valoración media'),
              value: ratings.isEmpty
                  ? '–'
                  : (ratings.reduce((a, b) => a + b) / ratings.length)
                        .toStringAsFixed(1),
              icon: AppIcons.star,
            ),
          ],
        ),
        const SizedBox(height: 12),
        TrackerLabel(tr(context, 'Dreams per month', 'Sueños por mes')),
        SizedBox(
          height: 140,
          child: BarChart(
            BarChartData(
              maxY: maxY + 1,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 24),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, meta) => Text(
                      DateFormat.MMM(
                        context.dateLocale,
                      ).format(months[v.toInt()]).substring(0, 1),
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < 12; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: perMonth[i].toDouble(),
                        color: const Color(0xFF7E6BD6),
                        width: 12,
                        borderRadius: prismCorners(context, 4),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        cloud(
          tr(context, 'Recurring themes', 'Temas recurrentes'),
          top(themes),
        ),
        cloud(tr(context, 'Symbols', 'Símbolos'), top(symbols)),
        cloud(
          tr(context, 'Emotions', 'Emociones'),
          top(emotions),
          tappable: false,
          label: (k) => emotionLabel(context, k),
        ),
        if (suggestions.isNotEmpty) ...[
          PrismSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      PhosphorIcons.sparkle(),
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tr(context, 'Suggestions', 'Sugerencias'),
                      style: theme.textTheme.titleSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  tr(
                    context,
                    'Generated on this device from counts in your entries. They are prompts, not interpretations.',
                    'Generadas en este dispositivo a partir de tus entradas. Son ideas, no interpretaciones.',
                  ),
                  style: theme.textTheme.labelSmall,
                ),
                const SizedBox(height: 8),
                for (final s in suggestions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• $s'),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

Future<void> showDreamDetail(BuildContext context, String id) =>
    PrismSheet.showFullScreen(
      context: context,
      builder: (ctx, scroll) => _DreamDetail(id: id, scroll: scroll),
    );

class _DreamDetail extends ConsumerWidget {
  const _DreamDetail({required this.id, required this.scroll});
  final String id;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d =
        (ref.watch(trackerKindProvider(TrackerKind.dreamEntry)).value ??
                const <TrackerRecord>[])
            .where((x) => x.id == id)
            .firstOrNull;
    final theme = Theme.of(context);
    if (d == null) return const Center(child: PrismLoadingState());
    final at = d.occurredAt ?? d.createdAt;
    final members = [
      for (final m in {?d.memberId, ...d.strings(DreamField.members)})
        ?memberNameFor(ref, m),
    ];
    Widget section(String label, String? text) =>
        text == null || text.trim().isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TrackerLabel(label),
                PrivateReveal(
                  isPrivate: d.isPrivate,
                  child: SelectableText(text),
                ),
              ],
            ),
          );
    return SafeArea(
      child: Column(
        children: [
          PrismSheetTopBar(
            title: d.title.isEmpty ? tr(context, 'Dream', 'Sueño') : d.title,
            trailing: IconButton(
              tooltip: context.l10n.edit,
              icon: Icon(AppIcons.edit),
              onPressed: () => showDreamEditor(context, editing: d),
            ),
          ),
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  DateFormat.yMMMMEEEEd(context.dateLocale).add_jm().format(at),
                  style: theme.textTheme.labelMedium,
                ),
                if (members.isNotEmpty)
                  Text(
                    '👥 ${members.join(', ')}',
                    style: theme.textTheme.bodySmall,
                  ),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final t in d.strings(DreamField.types))
                      if (dreamTypes.where((x) => x.$1 == t).firstOrNull
                          case final x?)
                        PrismChip(
                          label: '${x.$4} ${tr(context, x.$2, x.$3)}',
                          selected: true,
                          onTap: () {},
                        ),
                    if (d.integer(DreamField.rating) != null)
                      PrismChip(
                        label: '★' * d.integer(DreamField.rating)!,
                        selected: false,
                        onTap: () {},
                      ),
                  ],
                ),
                section(tr(context, 'What happened', 'Qué pasó'), d.body),
                if (d.strings(DreamField.media).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in d.strings(DreamField.media))
                        m.startsWith('audio:')
                            ? AudioClip(id: m)
                            : ClipRRect(
                                borderRadius: prismCorners(context, 12),
                                child: SizedBox(
                                  width: 150,
                                  height: 150,
                                  child: PrismMediaView(id: m),
                                ),
                              ),
                    ],
                  ),
                ],
                if (d.strings(DreamField.emotions).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  TrackerLabel(tr(context, 'Emotions', 'Emociones')),
                  Text(
                    d
                        .strings(DreamField.emotions)
                        .map((e) => emotionLabel(context, e))
                        .join(', '),
                  ),
                ],
                if (d.strings(DreamField.themes).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  TrackerLabel(tr(context, 'Themes', 'Temas')),
                  TagWrap(tags: d.strings(DreamField.themes)),
                ],
                if (d.strings(DreamField.symbols).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  TrackerLabel(tr(context, 'Symbols', 'Símbolos')),
                  TagWrap(tags: d.strings(DreamField.symbols)),
                ],
                section(
                  tr(context, 'My interpretation', 'Mi interpretación'),
                  d.str(DreamField.interpretation),
                ),
                section(
                  tr(context, 'Reflection', 'Reflexión'),
                  d.str(DreamField.reflection),
                ),
                if (d.tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  TagWrap(tags: d.tags),
                ],
                RelatedRecordsSection(self: RecordRef(RecordRef.rec, d.id)),
                const SizedBox(height: 16),
                PrismButton(
                  label: tr(context, 'Delete dream', 'Eliminar sueño'),
                  tone: PrismButtonTone.destructive,
                  icon: AppIcons.delete,
                  onPressed: () async {
                    final ok = await PrismDialog.confirm(
                      context: context,
                      title: tr(
                        context,
                        'Delete this dream?',
                        '¿Eliminar este sueño?',
                      ),
                      destructive: true,
                      confirmLabel: tr(context, 'Delete', 'Eliminar'),
                      cancelLabel: context.l10n.cancel,
                    );
                    if (!ok) return;
                    await ref
                        .read(trackerNotifierProvider.notifier)
                        .delete(d.id);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showDreamEditor(
  BuildContext context, {
  TrackerRecord? editing,
  DateTime? date,
}) => PrismSheet.showFullScreen(
  context: context,
  builder: (ctx, scroll) =>
      _DreamEditor(editing: editing, date: date, scroll: scroll),
);

class _DreamEditor extends ConsumerStatefulWidget {
  const _DreamEditor({this.editing, this.date, required this.scroll});
  final TrackerRecord? editing;
  final DateTime? date;
  final ScrollController scroll;
  @override
  ConsumerState<_DreamEditor> createState() => _DreamEditorState();
}

class _DreamEditorState extends ConsumerState<_DreamEditor> {
  late final TrackerRecord? e = widget.editing;
  late final _title = TextEditingController(text: e?.title);
  late final _body = TextEditingController(text: e?.body);
  late final _themes = TextEditingController(
    text: e?.strings(DreamField.themes).join(', '),
  );
  late final _symbols = TextEditingController(
    text: e?.strings(DreamField.symbols).join(', '),
  );
  late final _tags = TextEditingController(text: e?.tags.join(', '));
  late final _interp = TextEditingController(
    text: e?.str(DreamField.interpretation),
  );
  late final _reflect = TextEditingController(
    text: e?.str(DreamField.reflection),
  );
  late DateTime _at = e?.occurredAt ?? widget.date ?? DateTime.now();
  late String? _member = e?.memberId ?? currentFronterId(ref);
  late final Set<String> _members = {...?e?.strings(DreamField.members)};
  late final Set<String> _emotions = {...?e?.strings(DreamField.emotions)};
  late final Set<String> _types = {...?e?.strings(DreamField.types)};
  late int? _rating = e?.integer(DreamField.rating);
  late List<String> _media = [...?e?.strings(DreamField.media)];
  late bool _private = e?.isPrivate ?? false;

  @override
  void dispose() {
    for (final c in [
      _title,
      _body,
      _themes,
      _symbols,
      _tags,
      _interp,
      _reflect,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allMembers =
        ref.watch(activeMembersProvider).value ?? const <Member>[];
    final preferDisplay = ref.watch(memberNamePreferDisplayProvider);
    return TrackerEditorScaffold(
      title: e == null
          ? tr(context, 'New dream', 'Nuevo sueño')
          : tr(context, 'Edit dream', 'Editar sueño'),
      canSave: _title.text.trim().isNotEmpty || _body.text.trim().isNotEmpty,
      scrollController: widget.scroll,
      onSave: _save,
      children: [
        PrismTextField(
          controller: _title,
          labelText: tr(context, 'Title', 'Título'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        PrismButton(
          label: DateFormat.yMMMEd(context.dateLocale).add_jm().format(_at),
          icon: AppIcons.calendarToday,
          onPressed: () async {
            final d = await showPrismDatePicker(
              context: context,
              firstDate: DateTime(2000),
              lastDate: DateTime.now().add(const Duration(days: 1)),
              initialDate: _at,
            );
            if (d == null || !context.mounted) return;
            final t = await showPrismTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(_at),
            );
            setState(
              () => _at = DateTime(
                d.year,
                d.month,
                d.day,
                t?.hour ?? _at.hour,
                t?.minute ?? _at.minute,
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        PrismTextField(
          controller: _body,
          labelText: tr(
            context,
            'What happened in the dream?',
            '¿Qué pasó en el sueño?',
          ),
          maxLines: 10,
          minLines: 4,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TrackerMemberPicker(
          label: tr(context, 'Who dreamed it', 'Quién lo soñó'),
          value: _member,
          onChanged: (m) => setState(() => _member = m),
        ),
        if (allMembers.length > 1) ...[
          const SizedBox(height: 8),
          TrackerLabel(
            tr(context, 'Alters in the dream', 'Alters en el sueño'),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final m in allMembers)
                PrismChip(
                  label: m.effectiveName(preferDisplayName: preferDisplay),
                  selected: _members.contains(m.id),
                  onTap: () => setState(
                    () => _members.contains(m.id)
                        ? _members.remove(m.id)
                        : _members.add(m.id),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        TrackerLabel(tr(context, 'Kind of dream', 'Tipo de sueño')),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final t in dreamTypes)
              PrismChip(
                label: '${t.$4} ${tr(context, t.$2, t.$3)}',
                selected: _types.contains(t.$1),
                onTap: () => setState(
                  () => _types.contains(t.$1)
                      ? _types.remove(t.$1)
                      : _types.add(t.$1),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TrackerLabel(
          tr(
            context,
            'Rating (how vivid or memorable)',
            'Valoración (qué tan vívido o memorable)',
          ),
        ),
        Row(
          children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                tooltip: '$i',
                icon: Icon(
                  i <= (_rating ?? 0)
                      ? AppIcons.starRounded
                      : AppIcons.starBorder,
                  color: const Color(0xFFF1C40F),
                ),
                onPressed: () =>
                    setState(() => _rating = _rating == i ? null : i),
              ),
          ],
        ),
        TrackerLabel(tr(context, 'Emotions', 'Emociones')),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final em in dreamEmotions)
              PrismChip(
                label: tr(context, em.$2, em.$3),
                selected: _emotions.contains(em.$1),
                onTap: () => setState(
                  () => _emotions.contains(em.$1)
                      ? _emotions.remove(em.$1)
                      : _emotions.add(em.$1),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        PrismTextField(
          controller: _themes,
          labelText: tr(
            context,
            'Themes (comma separated)',
            'Temas (separados por comas)',
          ),
        ),
        const SizedBox(height: 8),
        PrismTextField(
          controller: _symbols,
          labelText: tr(
            context,
            'Symbols (comma separated)',
            'Símbolos (separados por comas)',
          ),
        ),
        const SizedBox(height: 8),
        PrismTextField(
          controller: _tags,
          labelText: tr(context, 'Tags', 'Etiquetas'),
        ),
        const SizedBox(height: 12),
        TrackerLabel(
          tr(
            context,
            'Pictures, artwork & voice notes',
            'Imágenes, arte y notas de voz',
          ),
        ),
        MediaAttachRow(
          ids: _media,
          owner: _member,
          onChanged: (v) => setState(() => _media = v),
        ),
        const SizedBox(height: 12),
        PrismTextField(
          controller: _interp,
          labelText: tr(
            context,
            'My interpretation (optional)',
            'Mi interpretación (opcional)',
          ),
          maxLines: 6,
          minLines: 2,
        ),
        const SizedBox(height: 8),
        PrismTextField(
          controller: _reflect,
          labelText: tr(
            context,
            'Reflection (optional)',
            'Reflexión (opcional)',
          ),
          maxLines: 6,
          minLines: 2,
        ),
        PrismSwitchRow(
          title: tr(context, 'Private', 'Privado'),
          subtitle: tr(
            context,
            'Hidden behind a tap and left out of summaries.',
            'Oculto tras un toque y fuera de los resúmenes.',
          ),
          value: _private,
          onChanged: (v) => setState(() => _private = v),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final t = ref.read(trackerNotifierProvider.notifier);
    final fields = <String, Object?>{
      DreamField.members: _members.toList(),
      DreamField.emotions: _emotions.toList(),
      DreamField.types: _types.toList(),
      DreamField.rating: _rating,
      DreamField.themes: parseTagInput(_themes.text),
      DreamField.symbols: parseTagInput(_symbols.text),
      DreamField.interpretation: _interp.text.trim().isEmpty
          ? null
          : _interp.text.trim(),
      DreamField.reflection: _reflect.text.trim().isEmpty
          ? null
          : _reflect.text.trim(),
      DreamField.media: _media,
    };
    if (e != null) {
      await t.save(
        e!
            .copyWith(
              title: _title.text,
              body: _body.text,
              occurredAt: _at,
              memberId: _member,
              isPrivate: _private,
              tags: parseTagInput(_tags.text),
            )
            .withFields(fields),
      );
    } else {
      await t.create(
        kind: TrackerKind.dreamEntry,
        title: _title.text,
        body: _body.text,
        occurredAt: _at,
        memberId: _member,
        isPrivate: _private,
        tags: parseTagInput(_tags.text),
        fields: fields,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }
}
