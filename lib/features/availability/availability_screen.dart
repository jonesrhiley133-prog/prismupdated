import 'package:prism_plurality/shared/widgets/section_switcher.dart';
import 'package:intl/intl.dart';

import 'package:prism_plurality/features/settings/views/feature_data_screen.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/availability/availability_models.dart';
import 'package:prism_plurality/features/availability/availability_providers.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/icon_choices.dart';
import 'package:prism_plurality/shared/pickers/style_pickers.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

enum _View { overview, schedule, upcoming, categories }

String _lang(BuildContext c) => Localizations.localeOf(c).languageCode;

class AvailabilityScreen extends ConsumerStatefulWidget {
  const AvailabilityScreen({super.key, this.showBackButton = false});
  final bool showBackButton;

  @override
  ConsumerState<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends ConsumerState<AvailabilityScreen> {
  _View _view = _View.overview;
  DateTime _day = DateTime.now();
  bool _week = false;
  String? _member;

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(activeMembersProvider).value ?? const <Member>[];
    _member ??= members.isEmpty ? null : members.first.id;
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: tr(context, 'Availability', 'Disponibilidad'),
        showBackButton: widget.showBackButton || Navigator.of(context).canPop(),
        actions: [
          FeatureDataAction(featureId: 'availability'),
          PrismTopBarAction(
            icon: AppIcons.add,
            tooltip: tr(context, 'Add availability', 'Añadir disponibilidad'),
            onPressed: members.isEmpty
                ? null
                : () => showRuleEditor(
                    context,
                    memberId: _member ?? members.first.id,
                  ),
          ),
        ],
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: members.isEmpty
          ? EmptyState(
              icon: Icon(PhosphorIcons.calendarCheck()),
              title: tr(context, 'No alters yet', 'Aún no hay alters'),
              subtitle: tr(
                context,
                'Add headmates to plan their availability.',
                'Añade headmates para planear su disponibilidad.',
              ),
            )
          : ClampedBody(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: PrismSegmentedControl<_View>(
                      segments: [
                        PrismSegment(
                          value: _View.overview,
                          label: tr(context, 'Everyone', 'Todos'),
                        ),
                        PrismSegment(
                          value: _View.schedule,
                          label: tr(context, 'Schedule', 'Horario'),
                        ),
                        PrismSegment(
                          value: _View.upcoming,
                          label: tr(context, 'Upcoming', 'Próximo'),
                        ),
                        PrismSegment(
                          value: _View.categories,
                          label: tr(context, 'Types', 'Tipos'),
                        ),
                      ],
                      selected: _view,
                      onChanged: (v) => setState(() => _view = v),
                    ),
                  ),
                  Expanded(
                    child: SectionSwitcher(
                      id: _view,
                      child: switch (_view) {
                        _View.overview => _Overview(
                          members: members,
                          day: _day,
                          week: _week,
                          onDay: (d) => setState(() => _day = d),
                          onWeek: (w) => setState(() => _week = w),
                        ),
                        _View.schedule => _Schedule(
                          members: members,
                          memberId: _member!,
                          onMember: (m) => setState(() => _member = m),
                        ),
                        _View.upcoming => _Upcoming(members: members),
                        _View.categories => const _Categories(),
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _Legend extends ConsumerWidget {
  const _Legend();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(availCategoriesProvider(_lang(context)));
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      children: [
        for (final c in cats)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(c.iconData, size: 14, color: Color(c.color)),
              const SizedBox(width: 4),
              Text(c.title, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
      ],
    );
  }
}

class _Overview extends ConsumerWidget {
  const _Overview({
    required this.members,
    required this.day,
    required this.week,
    required this.onDay,
    required this.onWeek,
  });
  final List<Member> members;
  final DateTime day;
  final bool week;
  final ValueChanged<DateTime> onDay;
  final ValueChanged<bool> onWeek;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(availRulesProvider);
    final ovs = ref.watch(availOverridesProvider);
    final cats = {
      for (final c in ref.watch(availCategoriesProvider(_lang(context))))
        c.id: c,
    };
    final preferDisplay = ref.watch(memberNamePreferDisplayProvider);
    final start = week
        ? DateTime(day.year, day.month, day.day - (day.weekday - 1))
        : DateTime(day.year, day.month, day.day);
    final end = start.add(Duration(days: week ? 7 : 1));
    final now = DateTime.now();
    final fmt = week
        ? DateFormat.MMMd(context.dateLocale)
        : DateFormat.yMMMEd(context.dateLocale);
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, NavBarInset.of(context) + 16),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: tr(context, 'Previous', 'Anterior'),
              icon: Icon(PhosphorIcons.caretLeft()),
              onPressed: () =>
                  onDay(day.subtract(Duration(days: week ? 7 : 1))),
            ),
            Expanded(
              child: Text(
                week
                    ? '${fmt.format(start)} – ${fmt.format(end.subtract(const Duration(days: 1)))}'
                    : fmt.format(start),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            IconButton(
              tooltip: tr(context, 'Next', 'Siguiente'),
              icon: Icon(PhosphorIcons.caretRight()),
              onPressed: () => onDay(day.add(Duration(days: week ? 7 : 1))),
            ),
          ],
        ),
        Row(
          children: [
            PrismChip(
              label: tr(context, 'Day', 'Día'),
              selected: !week,
              onTap: () => onWeek(false),
            ),
            const SizedBox(width: 6),
            PrismChip(
              label: tr(context, 'Week', 'Semana'),
              selected: week,
              onTap: () => onWeek(true),
            ),
            const Spacer(),
            PrismButton(
              label: tr(context, 'Today', 'Hoy'),
              onPressed: () => onDay(DateTime.now()),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const _Legend(),
        const SizedBox(height: 10),
        for (final m in members)
          () {
            final blocks = availabilityBlocks(
              memberId: m.id,
              from: start,
              to: end,
              rules: rules,
              overrides: ovs,
            );
            final cur = availabilityAt(m.id, now, rules, ovs);
            return PrismSurface(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          m.effectiveName(preferDisplayName: preferDisplay),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      if (cur != null && cats[cur] != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              cats[cur]!.iconData,
                              size: 14,
                              color: Color(cats[cur]!.color),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              tr(context, 'Now: ', 'Ahora: ') +
                                  cats[cur]!.title,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _TimelineBar(
                    start: start,
                    end: end,
                    blocks: blocks,
                    cats: cats,
                    now: now,
                    days: week ? 7 : 1,
                  ),
                ],
              ),
            );
          }(),
      ],
    );
  }
}

class _TimelineBar extends StatelessWidget {
  const _TimelineBar({
    required this.start,
    required this.end,
    required this.blocks,
    required this.cats,
    required this.now,
    required this.days,
  });
  final DateTime start;
  final DateTime end;
  final List<AvailBlock> blocks;
  final Map<String, AvailCategory> cats;
  final DateTime now;
  final int days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = end.difference(start).inMinutes.toDouble();
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        double x(DateTime t) =>
            (t.difference(start).inMinutes.clamp(0, total) / total) * w;
        return SizedBox(
          height: 34,
          child: Stack(
            children: [
              Positioned.fill(
                top: 0,
                bottom: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.6,
                    ),
                    borderRadius: prismCorners(context, 6),
                  ),
                ),
              ),
              for (final b in blocks)
                Positioned(
                  left: x(b.start),
                  width: (x(b.end) - x(b.start)).clamp(2, w),
                  top: 0,
                  bottom: 12,
                  child: Tooltip(
                    message:
                        '${cats[b.category]?.title ?? b.category} · ${DateFormat.jm().format(b.start)}–${DateFormat.jm().format(b.end)}${b.note == null ? '' : ' · ${b.note}'}',
                    child: Container(
                      decoration: BoxDecoration(
                        color: Color(
                          cats[b.category]?.color ?? 0xFF8C8C8C,
                        ).withValues(alpha: b.isOverride ? 1 : 0.75),
                        borderRadius: prismCorners(context, 4),
                        border: b.isOverride
                            ? Border.all(
                                color: theme.colorScheme.onSurface,
                                width: 1,
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              if (now.isAfter(start) && now.isBefore(end))
                Positioned(
                  left: x(now) - 1,
                  width: 2,
                  top: 0,
                  bottom: 10,
                  child: ColoredBox(color: theme.colorScheme.primary),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 11,
                child: Row(
                  children: [
                    for (var i = 0; i < (days == 1 ? 4 : 7); i++)
                      Expanded(
                        child: Text(
                          days == 1
                              ? fmtMinutes(i * 6 * 60)
                              : DateFormat.E(
                                  Localizations.localeOf(context).toString(),
                                ).format(start.add(Duration(days: i))),
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 9,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Schedule extends ConsumerWidget {
  const _Schedule({
    required this.members,
    required this.memberId,
    required this.onMember,
  });
  final List<Member> members;
  final String memberId;
  final ValueChanged<String> onMember;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = [
      for (final r in ref.watch(availRulesProvider))
        if (r.memberId == memberId) r,
    ];
    final now = DateTime.now();
    final ovs = [
      for (final o in ref.watch(availOverridesProvider))
        if (o.memberId == memberId && o.end.isAfter(now)) o,
    ]..sort((a, b) => a.start.compareTo(b.start));
    final cats = {
      for (final c in ref.watch(availCategoriesProvider(_lang(context))))
        c.id: c,
    };
    final locale = Localizations.localeOf(context).toString();
    final monday = DateTime(2024, 1, 1); // a Monday, for weekday names
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, NavBarInset.of(context) + 16),
      children: [
        TrackerMemberPicker(
          label: tr(context, 'Alter', 'Alter'),
          value: memberId,
          onChanged: (m) => m == null ? null : onMember(m),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                tr(context, 'Weekly schedule', 'Horario semanal'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            PrismButton(
              label: tr(context, 'Add block', 'Añadir bloque'),
              icon: AppIcons.add,
              onPressed: () => showRuleEditor(context, memberId: memberId),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (var d = 1; d <= 7; d++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 44,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      DateFormat.E(
                        locale,
                      ).format(monday.add(Duration(days: d - 1))),
                    ),
                  ),
                ),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final r
                          in (rules
                              .where((r) => r.weekdays.contains(d))
                              .toList()
                            ..sort((a, b) => a.startMin - b.startMin)))
                        PrismChip(
                          avatar: Icon(
                            cats[r.category]?.iconData,
                            size: 14,
                            color: Color(cats[r.category]?.color ?? 0xFF8C8C8C),
                          ),
                          label:
                              '${fmtMinutes(r.startMin)}–${fmtMinutes(r.endMin)} ${cats[r.category]?.title ?? ''}${r.notify ? ' 🔔' : ''}',
                          selected: true,
                          selectedColor: Color(
                            cats[r.category]?.color ?? 0xFF8C8C8C,
                          ),
                          onTap: () => showRuleEditor(
                            context,
                            memberId: memberId,
                            editing: r,
                          ),
                        ),
                      if (!rules.any((r) => r.weekdays.contains(d)))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '—',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                tr(context, 'Temporary changes', 'Cambios temporales'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            PrismButton(
              label: tr(context, 'Add change', 'Añadir cambio'),
              icon: AppIcons.add,
              onPressed: () => showOverrideEditor(context, memberId: memberId),
            ),
          ],
        ),
        if (ovs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              tr(
                context,
                'Use temporary changes for one-off days off, trips or rest periods.',
                'Usa cambios temporales para días libres, viajes o descansos.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        for (final o in ovs)
          PrismListRow(
            dense: true,
            leading: Icon(
              cats[o.category]?.iconData,
              color: Color(cats[o.category]?.color ?? 0xFF8C8C8C),
            ),
            title: Text(cats[o.category]?.title ?? o.category),
            subtitle: Text(
              '${DateFormat.MMMd(context.dateLocale).add_jm().format(o.start)} – ${DateFormat.MMMd(context.dateLocale).add_jm().format(o.end)}${o.note == null ? '' : ' · ${o.note}'}',
            ),
            showChevron: true,
            onTap: () =>
                showOverrideEditor(context, memberId: memberId, editing: o),
          ),
      ],
    );
  }
}

class _Upcoming extends ConsumerWidget {
  const _Upcoming({required this.members});
  final List<Member> members;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(availRulesProvider);
    final ovs = ref.watch(availOverridesProvider);
    final cats = {
      for (final c in ref.watch(availCategoriesProvider(_lang(context))))
        c.id: c,
    };
    final now = DateTime.now();
    final blocks = [
      for (final m in members)
        ...availabilityBlocks(
          memberId: m.id,
          from: now,
          to: now.add(const Duration(days: 7)),
          rules: rules,
          overrides: ovs,
        ),
    ]..sort((a, b) => a.start.compareTo(b.start));
    final fmt = DateFormat.MMMEd(context.dateLocale).add_jm();
    if (blocks.isEmpty) {
      return EmptyState(
        icon: Icon(PhosphorIcons.calendarCheck()),
        title: tr(
          context,
          'Nothing planned this week',
          'Nada planeado esta semana',
        ),
        subtitle: tr(
          context,
          'Add weekly blocks in Schedule.',
          'Añade bloques semanales en Horario.',
        ),
      );
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, NavBarInset.of(context) + 16),
      children: [
        for (final b in blocks.take(200))
          PrismListRow(
            dense: true,
            leading: Icon(
              cats[b.category]?.iconData,
              color: Color(cats[b.category]?.color ?? 0xFF8C8C8C),
            ),
            title: Text(
              '${memberNameFor(ref, b.memberId) ?? '?'} · ${cats[b.category]?.title ?? b.category}',
            ),
            subtitle: Text(
              '${fmt.format(b.start)} – ${DateFormat.jm().format(b.end)}${b.isOverride ? tr(context, ' · temporary', ' · temporal') : ''}',
            ),
          ),
      ],
    );
  }
}

class _Categories extends ConsumerWidget {
  const _Categories();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(availCategoriesProvider(_lang(context)));
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, NavBarInset.of(context) + 16),
      children: [
        for (final c in cats)
          PrismListRow(
            leading: PrismCircleAvatar(
              backgroundColor: Color(c.color),
              child: Icon(c.iconData, color: Colors.white, size: 18),
            ),
            title: Text(c.title),
            showChevron: true,
            onTap: () => _editCategory(context, ref, c),
          ),
        const SizedBox(height: 12),
        PrismButton(
          label: tr(
            context,
            'New availability type',
            'Nuevo tipo de disponibilidad',
          ),
          icon: AppIcons.add,
          tone: PrismButtonTone.filled,
          onPressed: () => _editCategory(context, ref, null),
        ),
      ],
    );
  }

  Future<void> _editCategory(
    BuildContext context,
    WidgetRef ref,
    AvailCategory? c,
  ) async {
    final builtin = c != null && builtInAvailability.any((b) => b.$1 == c.id)
        ? c.id
        : null;
    final name = TextEditingController(text: c?.title);
    var color = c?.color ?? colorChoices.first;
    var icon = c?.icon ?? 'circle';
    await PrismSheet.show(
      context: context,
      title: c == null ? tr(context, 'New type', 'Nuevo tipo') : c.title,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (builtin == null)
                  PrismTextField(
                    controller: name,
                    labelText: tr(ctx, 'Name', 'Nombre'),
                  ),
                const SizedBox(height: 12),
                ColorChoiceRow(
                  value: color,
                  onChanged: (v) => set(() => color = v),
                ),
                const SizedBox(height: 12),
                IconChoiceGrid(
                  value: icon,
                  color: Color(color),
                  onChanged: (v) => set(() => icon = v),
                ),
                const SizedBox(height: 16),
                PrismButton(
                  label: ctx.l10n.save,
                  tone: PrismButtonTone.filled,
                  onPressed: () async {
                    if (builtin == null && name.text.trim().isEmpty) return;
                    await ref
                        .read(availabilityActionsProvider)
                        .saveCategory(
                          editing: c?.record,
                          builtin: builtin,
                          title: builtin == null ? name.text.trim() : c!.title,
                          color: color,
                          icon: icon,
                        );
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    name.dispose();
  }
}

Future<void> showRuleEditor(
  BuildContext context, {
  required String memberId,
  AvailRule? editing,
}) => PrismSheet.showFullScreen(
  context: context,
  builder: (ctx, scroll) =>
      _RuleEditor(memberId: memberId, editing: editing, scroll: scroll),
);

class _RuleEditor extends ConsumerStatefulWidget {
  const _RuleEditor({
    required this.memberId,
    this.editing,
    required this.scroll,
  });
  final String memberId;
  final AvailRule? editing;
  final ScrollController scroll;
  @override
  ConsumerState<_RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends ConsumerState<_RuleEditor> {
  late String _member = widget.memberId;
  late final Set<int> _days = {...?widget.editing?.weekdays};
  late int _start = widget.editing?.startMin ?? 9 * 60;
  late int _end = widget.editing?.endMin ?? 17 * 60;
  late String _cat = widget.editing?.category ?? 'available';
  late bool _notify = widget.editing?.notify ?? false;
  late final _note = TextEditingController(text: widget.editing?.note);
  late DateTime? _from = widget.editing?.validFrom;
  late DateTime? _until = widget.editing?.validUntil;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<int?> _time(int m) async {
    final t = await showPrismTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
    );
    return t == null ? null : t.hour * 60 + t.minute;
  }

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(availCategoriesProvider(_lang(context)));
    final locale = Localizations.localeOf(context).toString();
    final monday = DateTime(2024, 1, 1);
    final dfmt = DateFormat.yMMMd(context.dateLocale);
    return TrackerEditorScaffold(
      title: widget.editing == null
          ? tr(context, 'Weekly availability', 'Disponibilidad semanal')
          : tr(context, 'Edit block', 'Editar bloque'),
      canSave: _days.isNotEmpty,
      scrollController: widget.scroll,
      onSave: () async {
        await ref
            .read(availabilityActionsProvider)
            .saveRule(
              editing: widget.editing?.record,
              memberId: _member,
              days: _days.toList()..sort(),
              start: _start,
              end: _end,
              category: _cat,
              note: _note.text.trim().isEmpty ? null : _note.text.trim(),
              notify: _notify,
              validFrom: _from,
              validUntil: _until,
            );
        if (context.mounted) Navigator.of(context).pop();
      },
      children: [
        TrackerMemberPicker(
          label: tr(context, 'Alter', 'Alter'),
          value: _member,
          onChanged: (m) => setState(() => _member = m ?? _member),
        ),
        const SizedBox(height: 12),
        TrackerLabel(tr(context, 'Days', 'Días')),
        Wrap(
          spacing: 6,
          children: [
            for (var d = 1; d <= 7; d++)
              PrismChip(
                label: DateFormat.E(
                  locale,
                ).format(monday.add(Duration(days: d - 1))),
                selected: _days.contains(d),
                onTap: () => setState(
                  () => _days.contains(d) ? _days.remove(d) : _days.add(d),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: PrismButton(
                label: '${tr(context, 'From', 'Desde')} ${fmtMinutes(_start)}',
                icon: AppIcons.history,
                onPressed: () async {
                  final v = await _time(_start);
                  if (v != null) setState(() => _start = v);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PrismButton(
                label: '${tr(context, 'To', 'Hasta')} ${fmtMinutes(_end)}',
                icon: AppIcons.history,
                onPressed: () async {
                  final v = await _time(_end);
                  if (v != null) setState(() => _end = v);
                },
              ),
            ),
          ],
        ),
        if (_end <= _start)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              tr(context, 'Ends the next day.', 'Termina al día siguiente.'),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        const SizedBox(height: 12),
        TrackerLabel(tr(context, 'Type', 'Tipo')),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in cats)
              PrismChip(
                avatar: Icon(c.iconData, size: 14, color: Color(c.color)),
                label: c.title,
                selected: _cat == c.id,
                selectedColor: Color(c.color),
                onTap: () => setState(() => _cat = c.id),
              ),
          ],
        ),
        const SizedBox(height: 12),
        PrismTextField(
          controller: _note,
          labelText: tr(context, 'Note', 'Nota'),
          maxLines: 3,
          minLines: 1,
        ),
        PrismSwitchRow(
          title: tr(
            context,
            'Notify me before it starts',
            'Avisarme antes de que empiece',
          ),
          value: _notify,
          onChanged: (v) => setState(() => _notify = v),
        ),
        Row(
          children: [
            Expanded(
              child: PrismButton(
                label: _from == null
                    ? tr(context, 'Starts: any time', 'Inicio: siempre')
                    : dfmt.format(_from!),
                onPressed: () async {
                  final d = await showPrismDatePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    initialDate: _from ?? DateTime.now(),
                  );
                  setState(() => _from = d);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PrismButton(
                label: _until == null
                    ? tr(context, 'Ends: never', 'Fin: nunca')
                    : dfmt.format(_until!),
                onPressed: () async {
                  final d = await showPrismDatePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    initialDate: _until ?? DateTime.now(),
                  );
                  setState(() => _until = d);
                },
              ),
            ),
          ],
        ),
        if (widget.editing != null) ...[
          const SizedBox(height: 16),
          PrismButton(
            label: tr(context, 'Delete block', 'Eliminar bloque'),
            tone: PrismButtonTone.destructive,
            icon: AppIcons.delete,
            onPressed: () async {
              await ref
                  .read(availabilityActionsProvider)
                  .delete(widget.editing!.record.id);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ],
    );
  }
}

Future<void> showOverrideEditor(
  BuildContext context, {
  required String memberId,
  AvailOverride? editing,
}) => PrismSheet.showFullScreen(
  context: context,
  builder: (ctx, scroll) =>
      _OverrideEditor(memberId: memberId, editing: editing, scroll: scroll),
);

class _OverrideEditor extends ConsumerStatefulWidget {
  const _OverrideEditor({
    required this.memberId,
    this.editing,
    required this.scroll,
  });
  final String memberId;
  final AvailOverride? editing;
  final ScrollController scroll;
  @override
  ConsumerState<_OverrideEditor> createState() => _OverrideEditorState();
}

class _OverrideEditorState extends ConsumerState<_OverrideEditor> {
  late String _member = widget.memberId;
  late DateTime _start = widget.editing?.start ?? DateTime.now();
  late DateTime _end =
      widget.editing?.end ?? DateTime.now().add(const Duration(hours: 4));
  late String _cat = widget.editing?.category ?? 'unavailable';
  late bool _notify = widget.editing?.record.flag('notify') ?? false;
  late final _note = TextEditingController(text: widget.editing?.note);

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<DateTime?> _pick(DateTime initial) async {
    final d = await showPrismDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: initial,
    );
    if (d == null || !mounted) return null;
    final t = await showPrismTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(availCategoriesProvider(_lang(context)));
    final fmt = DateFormat.yMMMd(context.dateLocale).add_jm();
    return TrackerEditorScaffold(
      title: tr(context, 'Temporary change', 'Cambio temporal'),
      canSave: _end.isAfter(_start),
      scrollController: widget.scroll,
      onSave: () async {
        await ref
            .read(availabilityActionsProvider)
            .saveOverride(
              editing: widget.editing?.record,
              memberId: _member,
              start: _start,
              end: _end,
              category: _cat,
              note: _note.text.trim().isEmpty ? null : _note.text.trim(),
              notify: _notify,
            );
        if (context.mounted) Navigator.of(context).pop();
      },
      children: [
        TrackerMemberPicker(
          label: tr(context, 'Alter', 'Alter'),
          value: _member,
          onChanged: (m) => setState(() => _member = m ?? _member),
        ),
        const SizedBox(height: 12),
        PrismButton(
          label: '${tr(context, 'Starts', 'Empieza')}: ${fmt.format(_start)}',
          onPressed: () async {
            final v = await _pick(_start);
            if (v != null) setState(() => _start = v);
          },
        ),
        const SizedBox(height: 8),
        PrismButton(
          label: '${tr(context, 'Ends', 'Termina')}: ${fmt.format(_end)}',
          onPressed: () async {
            final v = await _pick(_end);
            if (v != null) setState(() => _end = v);
          },
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in cats)
              PrismChip(
                avatar: Icon(c.iconData, size: 14, color: Color(c.color)),
                label: c.title,
                selected: _cat == c.id,
                selectedColor: Color(c.color),
                onTap: () => setState(() => _cat = c.id),
              ),
          ],
        ),
        const SizedBox(height: 12),
        PrismTextField(
          controller: _note,
          labelText: tr(context, 'Note', 'Nota'),
          maxLines: 3,
          minLines: 1,
        ),
        PrismSwitchRow(
          title: tr(
            context,
            'Notify me before it starts',
            'Avisarme antes de que empiece',
          ),
          value: _notify,
          onChanged: (v) => setState(() => _notify = v),
        ),
        if (widget.editing != null)
          PrismButton(
            label: tr(context, 'Delete change', 'Eliminar cambio'),
            tone: PrismButtonTone.destructive,
            icon: AppIcons.delete,
            onPressed: () async {
              await ref
                  .read(availabilityActionsProvider)
                  .delete(widget.editing!.record.id);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
      ],
    );
  }
}

/// Home card: who is available, resting or interested right now.
class AvailabilityNowCard extends ConsumerWidget {
  const AvailabilityNowCard({super.key, this.onOpen});
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(activeMembersProvider).value ?? const <Member>[];
    final rules = ref.watch(availRulesProvider);
    final ovs = ref.watch(availOverridesProvider);
    final cats = {
      for (final c in ref.watch(availCategoriesProvider(_lang(context))))
        c.id: c,
    };
    final prefer = ref.watch(memberNamePreferDisplayProvider);
    final now = DateTime.now();
    final rows = [
      for (final m in members)
        if (availabilityAt(m.id, now, rules, ovs) case final c?) (m, cats[c]),
    ];
    final theme = Theme.of(context);
    return PrismSurface(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                PhosphorIcons.calendarCheck(),
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr(context, 'Availability now', 'Disponibilidad ahora'),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Icon(AppIcons.chevronRight, size: 18),
            ],
          ),
          const SizedBox(height: 6),
          if (rows.isEmpty)
            Text(
              tr(
                context,
                'No availability planned for now.',
                'No hay disponibilidad planeada ahora.',
              ),
              style: theme.textTheme.bodySmall,
            ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (m, c) in rows)
                PrismChip(
                  avatar: Icon(
                    c?.iconData,
                    size: 14,
                    color: Color(c?.color ?? 0xFF8C8C8C),
                  ),
                  label:
                      '${m.effectiveName(preferDisplayName: prefer)} · ${c?.title ?? ''}',
                  selected: false,
                  variant: PrismChipVariant.inline,
                  onTap: onOpen ?? () {},
                ),
            ],
          ),
        ],
      ),
    );
  }
}
