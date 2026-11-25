import 'package:intl/intl.dart';

import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/health/body_atlas.dart';
import 'package:prism_plurality/features/health/health_model.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/prism_shapes.dart';
import 'package:prism_plurality/shared/widgets/prism_datetime_pills.dart';
import 'package:prism_plurality/shared/widgets/prism_glass_icon_button.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import 'package:prism_plurality/shared/widgets/prism_inline_icon_button.dart';

bool healthEs(BuildContext c) => Localizations.localeOf(c).languageCode == 'es';

/// A structured intake-form label: small caps, quiet, with an optional
/// "optional" hint so forms read like a calm medical form.
class HealthFormLabel extends StatelessWidget {
  const HealthFormLabel(
    this.text, {
    super.key,
    this.optional = false,
    this.trailing,
    this.top = 18,
  });
  final String text;
  final bool optional;
  final Widget? trailing;
  final double top;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final es = healthEs(context);
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // "optional" stays next to the label and wraps with it.
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: text.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (optional)
                    TextSpan(
                      text: '  ${es ? 'opcional' : 'optional'}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A severity tag with a text label (colour only reinforces it).
class SeverityTag extends StatelessWidget {
  const SeverityTag(this.severity, {super.key, this.score});
  final Severity severity;
  final int? score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final es = healthEs(context);
    final c = severityColor(theme, severity);
    final text = score == null
        ? severityLabel(severity, es)
        : '${severityLabel(severity, es)} · $score/10';
    return _Tag(
      text: text,
      color: c,
      icon: severity == Severity.unsure ? PhosphorIcons.question() : null,
      level: severity.index,
    );
  }
}

/// Calm for mild, warmer as it gets stronger. Always paired with a word.
Color severityColor(ThemeData theme, Severity s) => switch (s) {
  Severity.unsure => theme.colorScheme.onSurfaceVariant,
  Severity.mild => theme.colorScheme.primary,
  Severity.moderate => Color.lerp(
    theme.colorScheme.primary,
    theme.colorScheme.error,
    0.5,
  )!,
  Severity.severe || Severity.verySevere => theme.colorScheme.error,
};

/// Status of a check-in or episode as a labelled tag.
class StatusTag extends StatelessWidget {
  const StatusTag({
    super.key,
    required this.text,
    required this.active,
    this.icon,
  });
  final String text;
  final bool active;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Tag(
      text: text,
      color: active
          ? theme.colorScheme.primary
          : theme.colorScheme.onSurfaceVariant,
      icon:
          icon ??
          (active
              ? PhosphorIcons.circle(PhosphorIconsStyle.fill)
              : PhosphorIcons.checkCircle()),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color, this.icon, this.level});
  final String text;
  final Color color;
  final IconData? icon;

  /// 1–4 severity bars (drawn as small ticks), or null for none.
  final int? level;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(PrismShapes.of(context).radius(8)),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (level != null && level! > 0) ...[
            for (var i = 1; i <= 4; i++)
              Container(
                width: 3,
                height: 4.0 + i * 2,
                margin: const EdgeInsets.only(right: 1.5),
                decoration: BoxDecoration(
                  color: i <= level! ? color : color.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            const SizedBox(width: 4),
          ] else if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Labelled severity choices (no colours without words).
class SeverityPicker extends StatelessWidget {
  const SeverityPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final Severity? value;
  final ValueChanged<Severity?> onChanged;

  @override
  Widget build(BuildContext context) {
    final es = healthEs(context);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final s in [
          Severity.mild,
          Severity.moderate,
          Severity.severe,
          Severity.verySevere,
          Severity.unsure,
        ])
          PrismChip(
            label: severityLabel(s, es),
            selected: value == s,
            selectedColor: severityColor(Theme.of(context), s),
            onTap: () => onChanged(value == s ? null : s),
          ),
      ],
    );
  }
}

/// Optional 0–10 rating with words, starting unrated.
class IntensityRating extends StatelessWidget {
  const IntensityRating({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final int? value;
  final ValueChanged<int?> onChanged;

  static String words(int v, bool es) => switch (v) {
    0 => es ? 'Nada' : 'None',
    <= 3 => es ? 'Leve' : 'Mild',
    <= 6 => es ? 'Moderado' : 'Moderate',
    <= 8 => es ? 'Fuerte' : 'Severe',
    _ => es ? 'Muy fuerte' : 'Very severe',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final es = healthEs(context);
    final v = value;
    if (v == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: PrismButton(
          label: es ? 'Añadir puntuación 0–10' : 'Add a 0–10 rating',
          icon: PhosphorIcons.sliders(),
          density: PrismControlDensity.compact,
          onPressed: () => onChanged(5),
        ),
      );
    }
    return Row(
      children: [
        SizedBox(
          width: 98,
          child: Text(
            '$v/10 · ${words(v, es)}',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Slider(
            value: v.toDouble(),
            max: 10,
            divisions: 10,
            label: '$v',
            semanticFormatterCallback: (d) =>
                '${d.round()} of 10, ${words(d.round(), es)}',
            onChanged: (d) => onChanged(d.round()),
          ),
        ),
        PrismInlineIconButton(
          icon: PhosphorIcons.x(),
          onPressed: () => onChanged(null),
          tooltip: es ? 'Quitar puntuación' : 'Remove rating',
        ),
      ],
    );
  }
}

/// A time that may be exact, approximate or unknown.
class PreciseTimeField extends StatelessWidget {
  const PreciseTimeField({
    super.key,
    required this.label,
    required this.value,
    required this.precision,
    required this.onChanged,
    this.allowUnknown = true,
    this.emptyLabel,
  });
  final String label;
  final DateTime? value;
  final TimePrecision precision;
  final void Function(DateTime? at, TimePrecision precision) onChanged;
  final bool allowUnknown;
  final String? emptyLabel;

  @override
  Widget build(BuildContext context) {
    final es = healthEs(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (value == null || precision == TimePrecision.unknown)
          Row(
            children: [
              Expanded(
                child: Text(
                  precision == TimePrecision.unknown
                      ? (es ? 'No lo sé' : 'Not sure')
                      : (emptyLabel ?? (es ? 'Sin indicar' : 'Not set')),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              PrismButton(
                label: es ? 'Poner hora' : 'Set time',
                density: PrismControlDensity.compact,
                icon: PhosphorIcons.clock(),
                onPressed: () =>
                    onChanged(value ?? DateTime.now(), TimePrecision.exact),
              ),
            ],
          )
        else
          PrismDateTimePills(
            label: label,
            dateTime: value,
            lastDate: DateTime.now().add(const Duration(days: 1)),
            onChanged: (d) => onChanged(d, precision),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            PrismChip(
              label: es ? 'Exacta' : 'Exact',
              selected: value != null && precision == TimePrecision.exact,
              onTap: () =>
                  onChanged(value ?? DateTime.now(), TimePrecision.exact),
            ),
            PrismChip(
              label: es ? 'Aproximada' : 'Approximate',
              selected: value != null && precision == TimePrecision.approx,
              onTap: () =>
                  onChanged(value ?? DateTime.now(), TimePrecision.approx),
            ),
            if (allowUnknown)
              PrismChip(
                label: es ? 'No lo sé' : 'Unsure',
                selected: precision == TimePrecision.unknown,
                onTap: () => onChanged(null, TimePrecision.unknown),
              ),
          ],
        ),
      ],
    );
  }
}

/// "Who is this about?" — one alter, several, the whole system or unsure —
/// plus who is writing it and who may see it.
class AttributionPicker extends ConsumerWidget {
  const AttributionPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final Attribution value;
  final ValueChanged<Attribution> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final es = healthEs(context);
    final members =
        ref.watch(userVisibleMembersProvider).value ?? const <Member>[];
    final byId = {for (final m in members) m.id: m};
    final viewer = ref.watch(healthViewerProvider);
    final author = value.author == null ? null : byId[value.author!];
    final ordered = [
      ?byId[viewer],
      for (final m in members)
        if (m.id != viewer) m,
    ];
    final prefer = ref.watch(memberNamePreferDisplayProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final m in ordered)
              PrismChip(
                label: m.id == viewer
                    ? (es
                          ? '${memberLabel(m, preferDisplayName: prefer)} (al frente)'
                          : '${memberLabel(m, preferDisplayName: prefer)} (fronting)')
                    : memberLabel(m, preferDisplayName: prefer),
                selected:
                    value.scope == HealthScope.members &&
                    value.subjects.contains(m.id),
                onTap: () {
                  final next = value.scope == HealthScope.members
                      ? [...value.subjects]
                      : <String>[];
                  next.contains(m.id) ? next.remove(m.id) : next.add(m.id);
                  onChanged(
                    value.copyWith(
                      scope: next.isEmpty
                          ? HealthScope.unsure
                          : HealthScope.members,
                      subjects: next,
                    ),
                  );
                },
              ),
            PrismChip(
              label: context.l10n.trackerWholeSystem,
              selected: value.scope == HealthScope.system,
              onTap: () => onChanged(
                value.copyWith(scope: HealthScope.system, subjects: const []),
              ),
            ),
            PrismChip(
              label: es ? 'No estoy seguro' : 'Unsure',
              selected: value.scope == HealthScope.unsure,
              onTap: () => onChanged(
                value.copyWith(scope: HealthScope.unsure, subjects: const []),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(
              PhosphorIcons.pencilSimpleLine(),
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                author == null
                    ? (es
                          ? 'Registrado sin alter al frente'
                          : 'Logged with no one marked as fronting')
                    : (es
                          ? 'Registrado por ${author.effectiveName(preferDisplayName: prefer)}'
                          : 'Logged by ${author.effectiveName(preferDisplayName: prefer)}'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        if (value.scope == HealthScope.members) ...[
          const SizedBox(height: 4),
          PrismSwitchRow(
            title: es ? 'Solo para estos alters' : 'Only for these alters',
            subtitle: es
                ? 'Otros alters al frente no lo verán en Salud, búsquedas ni exportaciones.'
                : 'Other alters who front won’t see it in Health, search or exports.',
            value: value.visibility == HealthVisibility.private,
            onChanged: (v) => onChanged(
              value.copyWith(
                visibility: v
                    ? HealthVisibility.private
                    : HealthVisibility.system,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// "Mira", "Mira & Rowan", "Whole system", "Unsure who".
String attributionText(
  Attribution a,
  Map<String, Member> members,
  bool es, {
  bool preferDisplayName = false,
}) {
  switch (a.scope) {
    case HealthScope.system:
      return es ? 'Todo el sistema' : 'Whole system';
    case HealthScope.unsure:
      return es ? 'No se sabe quién' : 'Unsure who';
    case HealthScope.members:
      final names = [
        for (final id in a.subjects)
          members[id]?.effectiveName(preferDisplayName: preferDisplayName) ??
              'Alter',
      ];
      if (names.length <= 2) return names.join(es ? ' y ' : ' & ');
      return es
          ? '${names.first} y ${names.length - 1} más'
          : '${names.first} & ${names.length - 1} more';
  }
}

/// Descriptor chips for one region: region-specific words first, a search
/// box, and a way to type (and keep) a custom word.
class DescriptorPicker extends ConsumerStatefulWidget {
  const DescriptorPicker({
    super.key,
    required this.regionId,
    required this.selected,
    required this.onChanged,
  });
  final String regionId;
  final List<DescriptorRef> selected;
  final ValueChanged<List<DescriptorRef>> onChanged;

  @override
  ConsumerState<DescriptorPicker> createState() => _DescriptorPickerState();
}

class _DescriptorPickerState extends ConsumerState<DescriptorPicker> {
  final _q = TextEditingController();
  bool _all = false;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  void _toggle(Descriptor d, bool es) {
    final next = [...widget.selected];
    final i = next.indexWhere((x) => x.id == d.id);
    i >= 0 ? next.removeAt(i) : next.add((id: d.id, label: d.label(es)));
    widget.onChanged(next);
  }

  Future<void> _addCustom(bool es) async {
    final text = _q.text.trim();
    if (text.isEmpty) return;
    final r = await ref
        .read(healthStoreProvider)
        .addCustomTerm(
          type: 'descriptor',
          label: text,
          regionId: widget.regionId,
        );
    widget.onChanged([
      ...widget.selected,
      (id: 'custom:${r.id}', label: r.title),
    ]);
    _q.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final es = healthEs(context);
    final custom = ref
        .watch(healthVocabProvider)
        .descriptorsFor(widget.regionId);
    final q = _q.text.trim();
    final found = [...custom, ...searchDescriptors(widget.regionId, q, es)];
    final specific =
        regionDescriptors[regionById[widget.regionId]?.group]?.length ?? 0;
    final shown = q.isNotEmpty || _all
        ? found
        : found.take(custom.length + specific + 10).toList();
    final selectedIds = {for (final s in widget.selected) s.id};
    // Keep chosen words visible even if filtered out (e.g. renamed custom).
    final extra = [
      for (final s in widget.selected)
        if (!shown.any((d) => d.id == s.id)) Descriptor(s.id, s.label, s.label),
    ];
    final exact = found.any(
      (d) => d.label(es).toLowerCase() == q.toLowerCase(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrismTextField(
          controller: _q,
          hintText: es
              ? 'Buscar o escribir una palabra propia'
              : 'Search, or type your own word',
          prefixIcon: Icon(PhosphorIcons.magnifyingGlass()),
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => exact ? null : _addCustom(es),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final d in [...extra, ...shown])
              PrismChip(
                label: d.label(es),
                selected: selectedIds.contains(d.id),
                onTap: () => _toggle(d, es),
              ),
            if (q.isNotEmpty && !exact)
              PrismChip(
                label: es ? 'Añadir “$q”' : 'Add “$q”',
                selected: false,
                avatar: Icon(PhosphorIcons.plus(), size: 14),
                onTap: () => _addCustom(es),
              ),
          ],
        ),
        if (q.isEmpty && !_all && found.length > shown.length)
          Align(
            alignment: Alignment.centerLeft,
            child: PrismButton(
              label: es
                  ? 'Ver todas (${found.length})'
                  : 'Show all (${found.length})',
              density: PrismControlDensity.compact,
              onPressed: () => setState(() => _all = true),
            ),
          ),
      ],
    );
  }
}

/// "Today", "Yesterday", or a dated heading.
String dayHeading(BuildContext context, DateTime d) {
  final es = healthEs(context);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return es ? 'Hoy' : 'Today';
  if (diff == 1) return es ? 'Ayer' : 'Yesterday';
  return DateFormat(
    day.year == now.year ? 'EEEE d MMMM' : 'EEEE d MMMM y',
    context.dateLocale,
  ).format(day);
}

String clockTime(BuildContext context, DateTime t) =>
    DateFormat.jm(context.dateLocale).format(t);

/// Sheet header with a close button and a save check (Prism's editor bar).
class HealthSheetBar extends StatelessWidget {
  const HealthSheetBar({
    super.key,
    required this.title,
    required this.canSave,
    required this.onSave,
  });
  final String title;
  final bool canSave;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PrismSheetTopBar(
      title: title,
      trailing: PrismGlassIconButton(
        icon: AppIcons.check,
        tooltip: context.l10n.save,
        size: PrismTokens.topBarActionSize,
        tint: canSave ? theme.colorScheme.primary : null,
        accentIcon: canSave,
        onPressed: canSave ? onSave : null,
      ),
    );
  }
}

/// Asks for a short piece of text in a small sheet.
Future<String?> askHealthText(
  BuildContext context, {
  required String title,
  String? hint,
  String? initial,
  String? action,
}) {
  final c = TextEditingController(text: initial);
  final es = healthEs(context);
  return PrismSheet.show<String>(
    context: context,
    title: title,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrismTextField(
            controller: c,
            autofocus: true,
            hintText: hint,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
          ),
          const SizedBox(height: 14),
          PrismButton(
            label: action ?? (es ? 'Añadir' : 'Add'),
            tone: PrismButtonTone.filled,
            expanded: true,
            onPressed: () => Navigator.of(ctx).pop(c.text.trim()),
          ),
        ],
      ),
    ),
  );
}
