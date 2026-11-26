import 'package:intl/intl.dart' show DateFormat;

import 'package:prism_plurality/domain/models/mood_entry.dart';
import 'package:prism_plurality/features/astro/content/horoscope.dart';
import 'package:prism_plurality/features/astro/data/astro_model.dart';
import 'package:prism_plurality/features/astro/views/astro_widgets.dart';
import 'package:prism_plurality/features/mood/providers/mood_providers.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

const _moodFaces = ['😣', '🙁', '😐', '🙂', '😄'];

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Today's astrology-themed energies next to how the day actually felt,
/// and the history of those reflections.
class EnergyJournalSection extends ConsumerWidget {
  const EnergyJournalSection({super.key, required this.access});
  final AstroAccess access;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final es = astroEs(context);
    final theme = Theme.of(context);
    final a = access;
    final accent = alterAccent(context, a);
    final today = DateTime.now();
    final reading = dailyReading(a.subject!, today, es);
    final entries = ref.watch(astroJournalProvider(a.member.id));
    final todayEntry = entries.where((e) => _sameDay(e.day, today)).firstOrNull;
    final moods = [
      for (final m
          in ref.watch(moodEntriesProvider).value ?? const <MoodEntry>[])
        if (m.memberId == a.member.id) m,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AstroCard(
          title: tr(context, 'Energy of the day', 'Energía del día'),
          emoji: '⚡',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final k in EnergyKind.values)
                Tooltip(
                  message: k.description.of(es),
                  child: EnergyBar(
                    kind: k,
                    value: reading.scores[k]!,
                    compare: todayEntry?.felt[k],
                    color: accent,
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                todayEntry?.felt.isNotEmpty == true
                    ? tr(
                        context,
                        'Markers show how you said the day actually felt.',
                        'Las marcas muestran cómo dijiste que se sintió el día.',
                      )
                    : tr(
                        context,
                        'An astrology-themed reflection tool, not a measurement of your energy.',
                        'Una herramienta de reflexión con temática astrológica, no una medición de tu energía.',
                      ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AstroHero(
          accent: accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(context, 'ASTROLOGY JOURNAL', 'DIARIO ASTROLÓGICO'),
                style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.1),
              ),
              const SizedBox(height: 4),
              Text(
                tr(
                  context,
                  'How did today actually feel?',
                  '¿Cómo se sintió hoy de verdad?',
                ),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${tr(context, 'Today\'s reading', 'Lectura de hoy')}: ${reading.title} · ${reading.energy}%',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              PrismButton(
                tone: PrismButtonTone.filled,
                icon: todayEntry == null
                    ? PhosphorIcons.pencilSimple()
                    : PhosphorIcons.pencilSimpleLine(),
                label: todayEntry == null
                    ? tr(
                        context,
                        'Write today\'s reflection',
                        'Escribir la reflexión de hoy',
                      )
                    : tr(
                        context,
                        'Edit today\'s reflection',
                        'Editar la reflexión de hoy',
                      ),
                enabled: a.isOwner,
                onPressed: () =>
                    showJournalSheet(context, a, reading, existing: todayEntry),
              ),
              if (!a.isOwner)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    es
                        ? 'Solo ${a.name} puede escribir aquí, mientras está al frente.'
                        : 'Only ${a.name} can write here, while fronting.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
        PrismSectionHeader(
          title: tr(context, 'REFLECTION HISTORY', 'HISTORIAL DE REFLEXIONES'),
        ),
        if (entries.isEmpty)
          AstroCard(
            child: Text(
              tr(
                context,
                'Reflections you write will appear here, next to that day\'s astrology theme and any mood you logged.',
                'Las reflexiones que escribas aparecerán aquí, junto al tema astrológico del día y el ánimo que registraras.',
              ),
            ),
          )
        else
          PrismSurface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (i, e) in entries.take(40).indexed) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.4,
                      ),
                    ),
                  _HistoryRow(
                    entry: e,
                    mood: moods
                        .where((m) => _sameDay(m.recordedAt, e.day))
                        .firstOrNull,
                    accent: accent,
                  ),
                ],
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            tr(
              context,
              'Comparing readings with how days felt is for noticing yourself — it doesn\'t show that the stars caused anything.',
              'Comparar las lecturas con cómo se sintieron los días sirve para observarte; no demuestra que las estrellas causen nada.',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.entry,
    required this.mood,
    required this.accent,
  });
  final AstroJournalEntry entry;
  final MoodEntry? mood;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = entry;
    String energyLabel(String? v) => switch (v) {
      'low' => tr(context, 'Low', 'Baja'),
      'medium' => tr(context, 'Medium', 'Media'),
      'high' => tr(context, 'High', 'Alta'),
      _ => '—',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat.MMMMd(context.dateLocale).format(e.day),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '🌙 ${tr(context, 'Astrology theme', 'Tema astrológico')}: ${e.theme}${e.predicted == null ? '' : ' (${e.predicted}%)'}',
          ),
          if (e.mood != null)
            Text(
              '💭 ${tr(context, 'Reported mood', 'Ánimo indicado')}: ${_moodFaces[(e.mood! - 1).clamp(0, 4)]}',
            ),
          Text(
            '⚡ ${tr(context, 'Reported energy', 'Energía indicada')}: ${energyLabel(e.energy)}',
          ),
          if (mood != null)
            Text(
              '📈 ${tr(context, 'Mood log that day', 'Registro de ánimo ese día')}: ${_moodFaces[(mood!.mood - 1).clamp(0, 4)]}${mood!.emotions.isEmpty ? '' : ' · ${mood!.emotions.take(3).join(', ')}'}',
            ),
          if (e.reflection.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '📝 "${e.reflection}"',
              style: const TextStyle(fontStyle: FontStyle.italic, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> showJournalSheet(
  BuildContext context,
  AstroAccess a,
  DayReading reading, {
  AstroJournalEntry? existing,
}) => PrismSheet.show(
  context: context,
  title: tr(context, 'How did today feel?', '¿Cómo se sintió hoy?'),
  maxHeightFactor: 0.94,
  builder: (_) => _JournalForm(access: a, reading: reading, existing: existing),
);

class _JournalForm extends ConsumerStatefulWidget {
  const _JournalForm({
    required this.access,
    required this.reading,
    this.existing,
  });
  final AstroAccess access;
  final DayReading reading;
  final AstroJournalEntry? existing;

  @override
  ConsumerState<_JournalForm> createState() => _JournalFormState();
}

class _JournalFormState extends ConsumerState<_JournalForm> {
  int? _mood;
  String? _energy;
  final Map<EnergyKind, double> _felt = {};
  late final _text = TextEditingController(
    text: widget.existing?.reflection ?? '',
  );
  bool _private = true;
  bool _detail = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _mood = e?.mood;
    _energy = e?.energy ?? 'medium';
    for (final f in (e?.felt ?? const <EnergyKind, int>{}).entries) {
      _felt[f.key] = f.value.toDouble();
    }
    _detail = _felt.isNotEmpty;
    _private =
        e?.record.isPrivate ??
        (widget.access.visibility != AstroVisibility.system &&
            widget.access.visibility != AstroVisibility.shareable);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final es = astroEs(context);
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Text(
          '${tr(context, 'Today\'s astrology theme', 'Tema astrológico de hoy')}: ${widget.reading.title}',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 14),
        TrackerLabel(tr(context, 'Mood', 'Ánimo')),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 1; i <= 5; i++)
              Semantics(
                button: true,
                selected: _mood == i,
                label: '${tr(context, 'Mood', 'Ánimo')} $i',
                child: InkWell(
                  borderRadius: prismCorners(context, 24),
                  onTap: () => setState(() => _mood = i),
                  child: Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: prismRound(context),
                      color: _mood == i
                          ? theme.colorScheme.primary.withValues(alpha: 0.18)
                          : null,
                      border: Border.all(
                        color: _mood == i
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Text(
                      _moodFaces[i - 1],
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TrackerLabel(tr(context, 'Energy', 'Energía')),
        PrismSegmentedControl<String>(
          segments: [
            PrismSegment(value: 'low', label: tr(context, 'Low', 'Baja')),
            PrismSegment(
              value: 'medium',
              label: tr(context, 'Medium', 'Media'),
            ),
            PrismSegment(value: 'high', label: tr(context, 'High', 'Alta')),
          ],
          selected: _energy ?? 'medium',
          onChanged: (v) => setState(() => _energy = v),
        ),
        PrismSwitchRow(
          padding: const EdgeInsets.symmetric(vertical: 8),
          title: tr(context, 'Rate each energy', 'Valorar cada energía'),
          subtitle: tr(
            context,
            'Compare with the day\'s six energies.',
            'Compara con las seis energías del día.',
          ),
          value: _detail,
          onChanged: (v) => setState(() => _detail = v),
        ),
        if (_detail)
          for (final k in EnergyKind.values)
            Row(
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    '${k.emoji} ${k.label.of(es)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: _felt[k] ?? 50,
                    max: 100,
                    divisions: 10,
                    label: '${(_felt[k] ?? 50).round()}',
                    onChanged: (v) => setState(() => _felt[k] = v),
                  ),
                ),
              ],
            ),
        const SizedBox(height: 8),
        PrismTextField(
          controller: _text,
          labelText: tr(context, 'Reflection', 'Reflexión'),
          hintText: tr(
            context,
            'e.g. I felt more social than usual.',
            'p. ej. Me sentí más sociable de lo normal.',
          ),
          maxLines: 4,
        ),
        PrismSwitchRow(
          padding: const EdgeInsets.symmetric(vertical: 8),
          title: tr(
            context,
            'Private to this alter',
            'Privado para este alter',
          ),
          value: _private,
          onChanged: (v) => setState(() => _private = v),
        ),
        const SizedBox(height: 8),
        PrismButton(
          tone: PrismButtonTone.filled,
          expanded: true,
          icon: PhosphorIcons.check(),
          label: tr(context, 'Save reflection', 'Guardar reflexión'),
          onPressed: () async {
            await ref
                .read(astroActionsProvider)
                .saveJournal(
                  memberId: widget.access.member.id,
                  day: widget.reading.day,
                  theme: widget.reading.title,
                  predicted: widget.reading.energy,
                  mood: _mood,
                  energy: _energy,
                  felt: _detail
                      ? {for (final e in _felt.entries) e.key: e.value.round()}
                      : const {},
                  reflection: _text.text,
                  private: _private,
                  existing: widget.existing?.record,
                );
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
