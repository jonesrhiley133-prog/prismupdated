import 'package:prism_plurality/shared/widgets/section_switcher.dart';
import 'package:intl/intl.dart';

import 'package:prism_plurality/features/settings/views/feature_data_screen.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/alter_status/status_providers.dart';
import 'package:prism_plurality/features/automations/automation_engine.dart';
import 'package:prism_plurality/features/automations/automation_models.dart';
import 'package:prism_plurality/features/links/providers/link_providers.dart';
import 'package:prism_plurality/features/locations/providers/location_providers.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

String triggerLabel(BuildContext c, String t) => switch (t) {
  AutoTrigger.frontStart => tr(
    c,
    'A fronting session begins',
    'Empieza una sesión al frente',
  ),
  AutoTrigger.frontEnd => tr(
    c,
    'A fronting session ends',
    'Termina una sesión al frente',
  ),
  AutoTrigger.alterActive => tr(
    c,
    'A specific alter becomes active',
    'Un alter concreto pasa al frente',
  ),
  AutoTrigger.mood => tr(c, 'A mood entry is logged', 'Se registra el ánimo'),
  AutoTrigger.journal => tr(
    c,
    'A journal entry is added',
    'Se añade una entrada al diario',
  ),
  AutoTrigger.dream => tr(c, 'A dream is recorded', 'Se registra un sueño'),
  AutoTrigger.eventSoon => tr(
    c,
    'A calendar event is coming up',
    'Se acerca un evento',
  ),
  AutoTrigger.hydrationMissing => tr(
    c,
    'Nothing drunk for a while',
    'Hace rato que no se bebe',
  ),
  AutoTrigger.time => tr(c, 'At a set time', 'A una hora concreta'),
  AutoTrigger.condition => tr(
    c,
    'A tracking condition is met',
    'Se cumple una condición',
  ),
  _ => t,
};

IconData triggerIcon(String t) => switch (t) {
  AutoTrigger.frontStart || AutoTrigger.alterActive => PhosphorIcons.signIn(),
  AutoTrigger.frontEnd => PhosphorIcons.signOut(),
  AutoTrigger.mood => PhosphorIcons.smiley(),
  AutoTrigger.journal => PhosphorIcons.notebook(),
  AutoTrigger.dream => PhosphorIcons.cloudMoon(),
  AutoTrigger.eventSoon => PhosphorIcons.calendarBlank(),
  AutoTrigger.hydrationMissing => PhosphorIcons.drop(),
  AutoTrigger.time => PhosphorIcons.clock(),
  _ => PhosphorIcons.funnel(),
};

String conditionLabel(BuildContext c, String t) => switch (t) {
  AutoCondition.alter => tr(c, 'Specific alters', 'Alters concretos'),
  AutoCondition.timeOfDay => tr(c, 'Time of day', 'Hora del día'),
  AutoCondition.weekday => tr(c, 'Day of the week', 'Día de la semana'),
  AutoCondition.fronting => tr(c, 'Who is fronting', 'Quién está al frente'),
  AutoCondition.mood => tr(c, 'Mood level', 'Nivel de ánimo'),
  AutoCondition.location => tr(c, 'Current location', 'Lugar actual'),
  AutoCondition.metric => tr(c, 'Tracking value', 'Valor registrado'),
  _ => t,
};

String actionLabel(BuildContext c, String t) => switch (t) {
  AutoAction.notify => tr(c, 'Send a notification', 'Enviar una notificación'),
  AutoAction.message => tr(
    c,
    'Show a message (and on Home)',
    'Mostrar un mensaje (y en Inicio)',
  ),
  AutoAction.createEntry => tr(c, 'Create an entry', 'Crear un registro'),
  AutoAction.setStatus => tr(c, 'Update a status', 'Actualizar un estado'),
  AutoAction.addEvent => tr(c, 'Add a calendar event', 'Añadir un evento'),
  AutoAction.reminder => tr(c, 'Set a reminder', 'Programar un recordatorio'),
  AutoAction.counter => tr(
    c,
    'Update a counter on Home',
    'Actualizar un contador en Inicio',
  ),
  AutoAction.link => tr(c, 'Connect related records', 'Conectar registros'),
  _ => t,
};

enum _Tab { rules, history, counters }

class AutomationsScreen extends ConsumerStatefulWidget {
  const AutomationsScreen({super.key});
  @override
  ConsumerState<AutomationsScreen> createState() => _AutomationsScreenState();
}

class _AutomationsScreenState extends ConsumerState<AutomationsScreen> {
  _Tab _tab = _Tab.rules;

  @override
  Widget build(BuildContext context) {
    ref.watch(automationEngineProvider);
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: tr(context, 'Automations', 'Automatizaciones'),
        showBackButton: true,
        actions: [
          FeatureDataAction(featureId: 'automations'),
          PrismTopBarAction(
            icon: AppIcons.add,
            tooltip: tr(context, 'New automation', 'Nueva automatización'),
            onPressed: () => showAutomationBuilder(context),
          ),
        ],
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: PrismSegmentedControl<_Tab>(
              segments: [
                PrismSegment(
                  value: _Tab.rules,
                  label: tr(context, 'Rules', 'Reglas'),
                ),
                PrismSegment(
                  value: _Tab.history,
                  label: tr(context, 'History', 'Historial'),
                ),
                PrismSegment(
                  value: _Tab.counters,
                  label: tr(context, 'Counters', 'Contadores'),
                ),
              ],
              selected: _tab,
              onChanged: (t) => setState(() => _tab = t),
            ),
          ),
          Expanded(
            child: SectionSwitcher(
              id: _tab,
              child: switch (_tab) {
                _Tab.rules => const _RulesList(),
                _Tab.history => const _History(),
                _Tab.counters => const _Counters(),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RulesList extends ConsumerWidget {
  const _RulesList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(automationRulesProvider);
    final theme = Theme.of(context);
    return ListView(
      padding: EdgeInsets.only(bottom: NavBarInset.of(context) + 16),
      children: [
        Text(
          tr(
            context,
            'Automations run while Prism is open. Scheduled notifications from time-based rules also arrive when it’s closed. Nothing is deleted or overwritten without asking, and most runs can be undone from History.',
            'Las automatizaciones funcionan con Prism abierto. Las notificaciones programadas por hora llegan también con la app cerrada. Nada se borra ni se sobrescribe sin preguntar, y casi todo se puede deshacer desde Historial.',
          ),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        for (final r in rules)
          PrismSurface(
            margin: const EdgeInsets.only(bottom: 8),
            onTap: () => showAutomationBuilder(context, editing: r.record),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(
                      alpha: r.enabled ? 0.15 : 0.05,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    triggerIcon(r.triggerType),
                    color: r.enabled
                        ? theme.colorScheme.primary
                        : theme.disabledColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.name, style: theme.textTheme.titleSmall),
                      Text(
                        '${triggerLabel(context, r.triggerType)} → ${r.actions.map((a) => actionLabel(context, a['type'] as String? ?? '')).join(', ')}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall,
                      ),
                      if (r.record.str('disabledReason') == 'errors')
                        Text(
                          tr(
                            context,
                            'Turned off after repeated errors — check History.',
                            'Desactivada tras errores repetidos: revisa el Historial.',
                          ),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      if (r.lastRun != null)
                        Text(
                          tr(
                            context,
                            'Last ran ${DateFormat.MMMd(context.dateLocale).add_jm().format(r.lastRun!)}',
                            'Última vez ${DateFormat.MMMd(context.dateLocale).add_jm().format(r.lastRun!)}',
                          ),
                          style: theme.textTheme.labelSmall,
                        ),
                    ],
                  ),
                ),
                Switch(
                  value: r.enabled,
                  onChanged: (v) => ref
                      .read(trackerNotifierProvider.notifier)
                      .save(
                        r.record.withFields({
                          'enabled': v,
                          'errors': 0,
                          'disabledReason': null,
                        }),
                      ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Text(
          tr(context, 'Start from a template', 'Empezar con una plantilla'),
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        for (final (name, desc, def) in automationTemplates(context))
          PrismListRow(
            leading: Icon(
              triggerIcon((def['trigger'] as Map)['type'] as String),
            ),
            title: Text(name),
            subtitle: Text(desc),
            trailing: Icon(AppIcons.addCircleOutline),
            onTap: () => showAutomationBuilder(context, template: (name, def)),
          ),
      ],
    );
  }
}

class _History extends ConsumerWidget {
  const _History();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(automationLogProvider);
    final theme = Theme.of(context);
    if (logs.isEmpty) {
      return EmptyState(
        icon: Icon(PhosphorIcons.clockCounterClockwise()),
        title: tr(
          context,
          'Nothing has run yet',
          'Aún no se ha ejecutado nada',
        ),
        subtitle: tr(
          context,
          'Each time an automation runs it appears here, with what it did.',
          'Cada ejecución aparece aquí con lo que hizo.',
        ),
      );
    }
    final fmt = DateFormat.MMMd(context.dateLocale).add_jm();
    return ListView.builder(
      padding: EdgeInsets.only(bottom: NavBarInset.of(context) + 16),
      itemCount: logs.length,
      itemBuilder: (context, i) {
        final l = logs[i];
        final created = l.fields['created'] is List
            ? (l.fields['created'] as List).length
            : 0;
        final ok = l.fields['ok'] != false;
        return PrismSurface(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    ok
                        ? PhosphorIcons.checkCircle()
                        : PhosphorIcons.warningCircle(),
                    size: 18,
                    color: ok
                        ? const Color(0xFF3BA55C)
                        : theme.colorScheme.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(l.title, style: theme.textTheme.titleSmall),
                  ),
                  Text(
                    fmt.format(l.occurredAt ?? l.createdAt),
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
              Text(
                [
                  triggerLabel(context, l.str('trigger') ?? ''),
                  ?memberNameFor(ref, l.str('member')),
                  if (l.flag('test')) tr(context, 'test run', 'prueba'),
                  if (created > 0)
                    tr(context, '$created changes', '$created cambios'),
                  if (l.flag('undone')) tr(context, 'undone', 'deshecho'),
                ].join(' · '),
                style: theme.textTheme.labelSmall,
              ),
              if (l.str('message') != null) Text('💬 ${l.str('message')}'),
              if (l.body != null)
                Text(
                  l.body!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              if (created > 0 && !l.flag('undone'))
                Align(
                  alignment: Alignment.centerRight,
                  child: PrismButton(
                    label: tr(context, 'Undo', 'Deshacer'),
                    icon: PhosphorIcons.arrowCounterClockwise(),
                    density: PrismControlDensity.compact,
                    onPressed: () async {
                      final ok = await PrismDialog.confirm(
                        context: context,
                        title: tr(
                          context,
                          'Undo this run?',
                          '¿Deshacer esta ejecución?',
                        ),
                        message: tr(
                          context,
                          'Entries, events, reminders and links it created are removed; a status it set is put back if nothing changed it since.',
                          'Se quitan los registros, eventos, recordatorios y enlaces que creó; un estado que puso se restaura si nada lo cambió después.',
                        ),
                        confirmLabel: tr(context, 'Undo', 'Deshacer'),
                        cancelLabel: context.l10n.cancel,
                      );
                      if (!ok) return;
                      final n = await ref
                          .read(automationEngineProvider)
                          .undo(l);
                      if (context.mounted)
                        PrismToast.show(
                          context,
                          message: tr(
                            context,
                            'Reversed $n changes',
                            'Se revirtieron $n cambios',
                          ),
                        );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Counters extends ConsumerWidget {
  const _Counters();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counters = ref.watch(automationCountersProvider);
    if (counters.isEmpty) {
      return EmptyState(
        icon: Icon(PhosphorIcons.hash()),
        title: tr(context, 'No counters yet', 'Aún no hay contadores'),
        subtitle: tr(
          context,
          'Add a “Update a counter” action to an automation to keep custom statistics here and on Home.',
          'Añade la acción «Actualizar un contador» para llevar estadísticas propias aquí y en Inicio.',
        ),
      );
    }
    return ListView(
      children: [
        for (final c in counters)
          PrismListRow(
            leading: Icon(PhosphorIcons.hash()),
            title: Text(c.title),
            subtitle: c.str('lastAt') == null
                ? null
                : Text(
                    DateFormat.MMMd(
                      context.dateLocale,
                    ).add_jm().format(DateTime.parse(c.str('lastAt')!)),
                  ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${c.amount ?? 0}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  tooltip: tr(context, 'Reset', 'Reiniciar'),
                  icon: Icon(PhosphorIcons.arrowCounterClockwise()),
                  onPressed: () async {
                    final ok = await PrismDialog.confirm(
                      context: context,
                      title: tr(
                        context,
                        'Reset “${c.title}” to 0?',
                        '¿Reiniciar «${c.title}» a 0?',
                      ),
                      destructive: true,
                      confirmLabel: tr(context, 'Reset', 'Reiniciar'),
                      cancelLabel: context.l10n.cancel,
                    );
                    if (ok)
                      await ref
                          .read(trackerNotifierProvider.notifier)
                          .save(c.copyWith(amount: 0));
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Home card: automation messages and counters.
class AutomationDashboardCard extends ConsumerWidget {
  const AutomationDashboardCard({super.key, this.onOpen});
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(automationEngineProvider);
    final messages = ref.watch(automationMessagesProvider);
    final counters = ref.watch(automationCountersProvider);
    final theme = Theme.of(context);
    return PrismSurface(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.lightning(), color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr(
                    context,
                    'From your automations',
                    'De tus automatizaciones',
                  ),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Icon(AppIcons.chevronRight, size: 18),
            ],
          ),
          const SizedBox(height: 6),
          if (messages.isEmpty && counters.isEmpty)
            Text(
              tr(
                context,
                'Messages and counters from automations show up here.',
                'Aquí aparecen mensajes y contadores de las automatizaciones.',
              ),
              style: theme.textTheme.bodySmall,
            ),
          for (final m in messages.take(3))
            Row(
              children: [
                Expanded(
                  child: Text(
                    '💬 ${m.str('message')}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                IconButton(
                  tooltip: tr(context, 'Dismiss', 'Descartar'),
                  icon: Icon(AppIcons.close, size: 16),
                  onPressed: () => ref
                      .read(trackerNotifierProvider.notifier)
                      .save(m.withFields({'dismissed': true})),
                ),
              ],
            ),
          if (counters.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final c in counters.take(6))
                  PrismChip(
                    label: '${c.title}: ${c.amount ?? 0}',
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

Future<void> showAutomationBuilder(
  BuildContext context, {
  TrackerRecord? editing,
  (String, Map<String, Object?>)? template,
}) => PrismSheet.showFullScreen(
  context: context,
  builder: (ctx, scroll) =>
      _Builder(editing: editing, template: template, scroll: scroll),
);

class _Builder extends ConsumerStatefulWidget {
  const _Builder({this.editing, this.template, required this.scroll});
  final TrackerRecord? editing;
  final (String, Map<String, Object?>)? template;
  final ScrollController scroll;
  @override
  ConsumerState<_Builder> createState() => _BuilderState();
}

class _BuilderState extends ConsumerState<_Builder> {
  late final _name = TextEditingController(
    text: widget.editing?.title ?? widget.template?.$1 ?? '',
  );
  late final _desc = TextEditingController(text: widget.editing?.body);
  late Map<String, Object?> _trigger;
  late List<Map<String, Object?>> _conditions;
  late List<Map<String, Object?>> _actions;
  late bool _enabled;
  late int _priority;
  late int _cooldown;

  @override
  void initState() {
    super.initState();
    final src = widget.editing == null
        ? widget.template?.$2 ?? const {}
        : widget.editing!.fields;
    Map<String, Object?> copy(Object? o) => o is Map
        ? Map<String, Object?>.from(o.cast<String, Object?>())
        : <String, Object?>{};
    _trigger = src['trigger'] == null
        ? {'type': AutoTrigger.frontStart}
        : copy(src['trigger']);
    _conditions = [
      for (final c in (src['conditions'] as List?) ?? const []) copy(c),
    ];
    _actions = [for (final a in (src['actions'] as List?) ?? const []) copy(a)];
    _enabled = widget.editing?.flag('enabled') ?? true;
    _priority = (src['priority'] as num?)?.toInt() ?? 0;
    _cooldown = (src['cooldown'] as num?)?.toInt() ?? 1;
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  bool get _overwrites => _actions.any(
    (a) => a['type'] == AutoAction.setStatus && a['onlyIfNone'] == false,
  );

  Future<void> _save() async {
    if (_overwrites) {
      final ok = await PrismDialog.confirm(
        context: context,
        title: tr(
          context,
          'Allow replacing existing statuses?',
          '¿Permitir reemplazar estados existentes?',
        ),
        message: tr(
          context,
          'This automation may replace a status someone set. The old status is kept in history and the change can be undone.',
          'Esta automatización puede reemplazar un estado que alguien puso. El anterior queda en el historial y se puede deshacer.',
        ),
        confirmLabel: tr(context, 'Allow', 'Permitir'),
        cancelLabel: context.l10n.cancel,
      );
      if (!ok) return;
    }
    final fields = {
      'enabled': _enabled,
      'priority': _priority,
      'cooldown': _cooldown,
      'trigger': _trigger,
      'conditions': _conditions,
      'actions': _actions,
      'errors': 0,
      'disabledReason': null,
    };
    final t = ref.read(trackerNotifierProvider.notifier);
    if (widget.editing != null) {
      await t.save(
        widget.editing!
            .copyWith(
              title: _name.text.trim(),
              body: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
            )
            .withFields(fields),
      );
    } else {
      await t.create(
        kind: TrackerKind.autoRule,
        title: _name.text.trim(),
        body: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        fields: fields,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget stage(
      String label,
      Color color,
      IconData icon,
      List<Widget> children,
    ) => Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        color: color.withValues(alpha: 0.06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
    Widget arrow() => Center(
      child: Icon(PhosphorIcons.arrowDown(), color: theme.colorScheme.outline),
    );
    return TrackerEditorScaffold(
      title: widget.editing == null
          ? tr(context, 'New automation', 'Nueva automatización')
          : tr(context, 'Edit automation', 'Editar automatización'),
      canSave: _name.text.trim().isNotEmpty && _actions.isNotEmpty,
      scrollController: widget.scroll,
      onSave: _save,
      children: [
        PrismTextField(
          controller: _name,
          labelText: tr(context, 'Name', 'Nombre'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        PrismTextField(
          controller: _desc,
          labelText: tr(context, 'Notes (optional)', 'Notas (opcional)'),
        ),
        const SizedBox(height: 12),
        stage(
          tr(context, 'WHEN', 'CUANDO'),
          const Color(0xFF5865F2),
          PhosphorIcons.lightning(),
          [
            PrismSelect<String>(
              value: _trigger['type'] as String?,
              items: [
                for (final t in AutoTrigger.all)
                  PrismSelectItem(
                    value: t,
                    label: triggerLabel(context, t),
                    leading: Icon(triggerIcon(t), size: 18),
                  ),
              ],
              onChanged: (v) => setState(() => _trigger = {'type': v}),
            ),
            const SizedBox(height: 8),
            _TriggerParams(trigger: _trigger, onChanged: () => setState(() {})),
          ],
        ),
        arrow(),
        stage(
          tr(context, 'ONLY IF (optional)', 'SOLO SI (opcional)'),
          const Color(0xFFFAA61A),
          PhosphorIcons.funnel(),
          [
            for (final (i, c) in _conditions.indexed)
              _ConditionEditor(
                key: ValueKey('c$i${c['type']}'),
                condition: c,
                onChanged: () => setState(() {}),
                onRemove: () => setState(() => _conditions.removeAt(i)),
              ),
            PrismButton(
              label: tr(context, 'Add condition', 'Añadir condición'),
              icon: AppIcons.add,
              onPressed: () async {
                final t = await _pick(context, [
                  for (final c in AutoCondition.all)
                    (c, conditionLabel(context, c)),
                ]);
                if (t != null) setState(() => _conditions.add({'type': t}));
              },
            ),
          ],
        ),
        arrow(),
        stage(
          tr(context, 'THEN', 'ENTONCES'),
          const Color(0xFF3BA55C),
          PhosphorIcons.play(),
          [
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: true,
              onReorderItem: (a, b) => setState(() {
                final x = _actions.removeAt(a);
                _actions.insert(b, x);
              }),
              children: [
                for (final (i, a) in _actions.indexed)
                  _ActionEditor(
                    key: ValueKey('a$i${a['type']}'),
                    action: a,
                    onChanged: () => setState(() {}),
                    onRemove: () => setState(() => _actions.removeAt(i)),
                  ),
              ],
            ),
            PrismButton(
              label: tr(context, 'Add action', 'Añadir acción'),
              icon: AppIcons.add,
              onPressed: () async {
                final t = await _pick(context, [
                  for (final a in AutoAction.all) (a, actionLabel(context, a)),
                ]);
                if (t != null)
                  setState(
                    () => _actions.add({
                      'type': t,
                      if (t == AutoAction.setStatus) 'onlyIfNone': true,
                      if (t == AutoAction.setStatus) 'target': 'trigger',
                    }),
                  );
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        PrismSwitchRow(
          title: tr(context, 'Enabled', 'Activada'),
          value: _enabled,
          onChanged: (v) => setState(() => _enabled = v),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                tr(
                  context,
                  'Priority (higher runs first)',
                  'Prioridad (mayor va primero)',
                ),
              ),
            ),
            IconButton(
              tooltip: '-',
              icon: Icon(PhosphorIcons.minus()),
              onPressed: () => setState(() => _priority--),
            ),
            Text('$_priority'),
            IconButton(
              tooltip: '+',
              icon: Icon(PhosphorIcons.plus()),
              onPressed: () => setState(() => _priority++),
            ),
          ],
        ),
        TrackerLabel(
          tr(
            context,
            'Wait at least this long between runs',
            'Esperar al menos esto entre ejecuciones',
          ),
        ),
        Wrap(
          spacing: 6,
          children: [
            for (final (m, l) in [
              (1, '1 min'),
              (15, '15 min'),
              (60, '1 h'),
              (180, '3 h'),
              (720, '12 h'),
              (1440, '1 d'),
            ])
              PrismChip(
                label: l,
                selected: _cooldown == m,
                onTap: () => setState(() => _cooldown = m),
              ),
          ],
        ),
        Text(
          tr(
            context,
            'Placeholders: {alter}, {time}, {date}, {mood}, {title}',
            'Marcadores: {alter}, {time}, {date}, {mood}, {title}',
          ),
          style: theme.textTheme.labelSmall,
        ),
        if (widget.editing != null) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PrismButton(
                label: tr(context, 'Test now', 'Probar ahora'),
                icon: PhosphorIcons.play(),
                onPressed: () async {
                  final log = await ref
                      .read(automationEngineProvider)
                      .test(
                        AutoRule(
                          widget.editing!.withFields({'actions': _actions}),
                        ),
                      );
                  if (context.mounted) {
                    PrismToast.show(
                      context,
                      message: log == null
                          ? tr(
                              context,
                              'Could not run right now',
                              'No se pudo ejecutar ahora',
                            )
                          : tr(
                              context,
                              'Ran — see History (undo is available)',
                              'Ejecutada: mira el Historial (se puede deshacer)',
                            ),
                    );
                  }
                },
              ),
              PrismButton(
                label: tr(
                  context,
                  'Delete automation',
                  'Eliminar automatización',
                ),
                tone: PrismButtonTone.destructive,
                icon: AppIcons.delete,
                onPressed: () async {
                  final ok = await PrismDialog.confirm(
                    context: context,
                    title: tr(
                      context,
                      'Delete this automation?',
                      '¿Eliminar esta automatización?',
                    ),
                    message: tr(
                      context,
                      'Things it already created stay; its history remains.',
                      'Lo que ya creó se mantiene, igual que su historial.',
                    ),
                    destructive: true,
                    confirmLabel: tr(context, 'Delete', 'Eliminar'),
                    cancelLabel: context.l10n.cancel,
                  );
                  if (!ok) return;
                  await ref
                      .read(trackerNotifierProvider.notifier)
                      .delete(widget.editing!.id, children: false);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ],
      ],
    );
  }
}

Future<String?> _pick(BuildContext context, List<(String, String)> options) =>
    PrismSheet.show<String>(
      context: context,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          for (final (id, label) in options)
            PrismListRow(
              title: Text(label),
              onTap: () => Navigator.of(ctx).pop(id),
            ),
        ],
      ),
    );

/// Member multi-select stored as a list of ids under [key].
class _MemberIds extends ConsumerWidget {
  const _MemberIds({
    required this.map,
    required this.keyName,
    required this.onChanged,
  });
  final Map<String, Object?> map;
  final String keyName;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(activeMembersProvider).value ?? const <Member>[];
    final prefer = ref.watch(memberNamePreferDisplayProvider);
    final ids = map[keyName] is List
        ? (map[keyName] as List).cast<String>().toSet()
        : <String>{};
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final m in members)
          PrismChip(
            label: m.effectiveName(preferDisplayName: prefer),
            selected: ids.contains(m.id),
            onTap: () {
              ids.contains(m.id) ? ids.remove(m.id) : ids.add(m.id);
              map[keyName] = ids.toList();
              onChanged();
            },
          ),
      ],
    );
  }
}

Widget _num(
  BuildContext context,
  String label,
  Map<String, Object?> map,
  String key,
  num def,
  VoidCallback onChanged, {
  List<num> options = const [],
}) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    TrackerLabel(label),
    Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final o in options)
          PrismChip(
            label: '$o',
            selected: (map[key] as num? ?? def) == o,
            onTap: () {
              map[key] = o;
              onChanged();
            },
          ),
      ],
    ),
  ],
);

Widget _timeButton(
  BuildContext context,
  String label,
  Map<String, Object?> map,
  String key,
  int def,
  VoidCallback onChanged,
) {
  final m = (map[key] as num?)?.toInt() ?? def;
  return PrismButton(
    label:
        '$label ${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}',
    icon: PhosphorIcons.clock(),
    onPressed: () async {
      final t = await showPrismTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
      );
      if (t == null) return;
      map[key] = t.hour * 60 + t.minute;
      onChanged();
    },
  );
}

Widget _days(
  BuildContext context,
  Map<String, Object?> map,
  VoidCallback onChanged,
) {
  final days = map['days'] is List
      ? (map['days'] as List).cast<num>().map((e) => e.toInt()).toSet()
      : {1, 2, 3, 4, 5, 6, 7};
  return Wrap(
    spacing: 4,
    children: [
      for (var d = 1; d <= 7; d++)
        PrismChip(
          label: DateFormat.E(context.dateLocale).format(DateTime(2024, 1, d)),
          selected: days.contains(d),
          onTap: () {
            days.contains(d) ? days.remove(d) : days.add(d);
            map['days'] = (days.toList()..sort());
            onChanged();
          },
        ),
    ],
  );
}

Widget _metricPicker(
  BuildContext context,
  Map<String, Object?> map,
  VoidCallback onChanged,
) {
  final vc = TextEditingController(text: '${map['value'] ?? 0}');
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      PrismSelect<String>(
        value: map['metric'] as String? ?? 'hydrationToday',
        items: [
          for (final (k, en, es) in autoMetrics)
            PrismSelectItem(value: k, label: tr(context, en, es)),
        ],
        onChanged: (v) {
          map['metric'] = v;
          onChanged();
        },
      ),
      const SizedBox(height: 6),
      Row(
        children: [
          for (final op in const ['<', '<=', '=', '>=', '>'])
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: PrismChip(
                label: op,
                selected: (map['op'] ?? '<') == op,
                onTap: () {
                  map['op'] = op;
                  onChanged();
                },
              ),
            ),
          const SizedBox(width: 6),
          Expanded(
            child: PrismTextField(
              controller: vc,
              isDense: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (v) => map['value'] = num.tryParse(v) ?? 0,
            ),
          ),
        ],
      ),
    ],
  );
}

class _TriggerParams extends StatelessWidget {
  const _TriggerParams({required this.trigger, required this.onChanged});
  final Map<String, Object?> trigger;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return switch (trigger['type']) {
      AutoTrigger.frontStart || AutoTrigger.frontEnd => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr(
              context,
              'Limit to these alters (optional):',
              'Solo para estos alters (opcional):',
            ),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          _MemberIds(map: trigger, keyName: 'alters', onChanged: onChanged),
        ],
      ),
      AutoTrigger.alterActive => _MemberIds(
        map: trigger,
        keyName: 'alters',
        onChanged: onChanged,
      ),
      AutoTrigger.eventSoon => _num(
        context,
        tr(context, 'Minutes before', 'Minutos antes'),
        trigger,
        'minutes',
        30,
        onChanged,
        options: const [5, 15, 30, 60, 120],
      ),
      AutoTrigger.hydrationMissing => _num(
        context,
        tr(context, 'Hours without a drink', 'Horas sin beber'),
        trigger,
        'hours',
        3,
        onChanged,
        options: const [1, 2, 3, 4, 6],
      ),
      AutoTrigger.time => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _timeButton(
            context,
            tr(context, 'At', 'A las'),
            trigger,
            'time',
            9 * 60,
            onChanged,
          ),
          const SizedBox(height: 6),
          _days(context, trigger, onChanged),
        ],
      ),
      AutoTrigger.condition => _metricPicker(context, trigger, onChanged),
      _ => const SizedBox.shrink(),
    };
  }
}

class _ConditionEditor extends ConsumerWidget {
  const _ConditionEditor({
    super.key,
    required this.condition,
    required this.onChanged,
    required this.onRemove,
  });
  final Map<String, Object?> condition;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = condition;
    final type = c['type'] as String? ?? '';
    final body = switch (type) {
      AutoCondition.alter => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 6,
            children: [
              PrismChip(
                label: tr(context, 'The alter involved', 'El alter implicado'),
                selected: c['who'] != 'fronting',
                onTap: () {
                  c['who'] = 'trigger';
                  onChanged();
                },
              ),
              PrismChip(
                label: tr(context, 'Anyone fronting', 'Quien esté al frente'),
                selected: c['who'] == 'fronting',
                onTap: () {
                  c['who'] = 'fronting';
                  onChanged();
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          _MemberIds(map: c, keyName: 'ids', onChanged: onChanged),
        ],
      ),
      AutoCondition.timeOfDay => Wrap(
        spacing: 8,
        children: [
          _timeButton(
            context,
            tr(context, 'From', 'Desde'),
            c,
            'from',
            9 * 60,
            onChanged,
          ),
          _timeButton(
            context,
            tr(context, 'Until', 'Hasta'),
            c,
            'to',
            21 * 60,
            onChanged,
          ),
        ],
      ),
      AutoCondition.weekday => _days(context, c, onChanged),
      AutoCondition.fronting => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (m, l) in [
                ('any', tr(context, 'Any of', 'Alguno de')),
                ('all', tr(context, 'All of', 'Todos')),
                ('none', tr(context, 'None of', 'Ninguno de')),
                (
                  'cofronting',
                  tr(context, 'Anyone co-fronting', 'Hay co-frente'),
                ),
              ])
                PrismChip(
                  label: l,
                  selected: (c['mode'] ?? 'any') == m,
                  onTap: () {
                    c['mode'] = m;
                    onChanged();
                  },
                ),
            ],
          ),
          if (c['mode'] != 'cofronting') ...[
            const SizedBox(height: 6),
            _MemberIds(map: c, keyName: 'ids', onChanged: onChanged),
          ],
        ],
      ),
      AutoCondition.mood => Wrap(
        spacing: 6,
        children: [
          for (final op in const ['<=', '=', '>='])
            PrismChip(
              label: op,
              selected: (c['op'] ?? '<=') == op,
              onTap: () {
                c['op'] = op;
                onChanged();
              },
            ),
          for (var v = 1; v <= 5; v++)
            PrismChip(
              label: '$v',
              selected: (c['value'] as num? ?? 2) == v,
              onTap: () {
                c['value'] = v;
                onChanged();
              },
            ),
        ],
      ),
      AutoCondition.location => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final l in ref.watch(savedLocationsProvider).value ?? const [])
            PrismChip(
              label: l.name,
              selected: (c['ids'] as List?)?.contains(l.id) ?? false,
              onTap: () {
                final ids = {...?(c['ids'] as List?)?.cast<String>()};
                ids.contains(l.id) ? ids.remove(l.id) : ids.add(l.id);
                c['ids'] = ids.toList();
                onChanged();
              },
            ),
        ],
      ),
      AutoCondition.metric => _metricPicker(context, c, onChanged),
      _ => const SizedBox.shrink(),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  conditionLabel(context, type),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              IconButton(
                tooltip: tr(context, 'Remove', 'Quitar'),
                icon: Icon(AppIcons.close, size: 18),
                onPressed: onRemove,
              ),
            ],
          ),
          body,
        ],
      ),
    );
  }
}

class _ActionEditor extends ConsumerStatefulWidget {
  const _ActionEditor({
    super.key,
    required this.action,
    required this.onChanged,
    required this.onRemove,
  });
  final Map<String, Object?> action;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  @override
  ConsumerState<_ActionEditor> createState() => _ActionEditorState();
}

class _ActionEditorState extends ConsumerState<_ActionEditor> {
  late final _title = TextEditingController(
    text: widget.action['title'] as String?,
  );
  late final _text = TextEditingController(
    text: widget.action['text'] as String?,
  );
  late final _name = TextEditingController(
    text: widget.action['name'] as String?,
  );

  @override
  void dispose() {
    _title.dispose();
    _text.dispose();
    _name.dispose();
    super.dispose();
  }

  Map<String, Object?> get a => widget.action;

  void _set(String k, Object? v) {
    a[k] = v;
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final type = a['type'] as String? ?? '';
    final lang = Localizations.localeOf(context).languageCode;
    Widget title() => PrismTextField(
      controller: _title,
      labelText: tr(context, 'Title', 'Título'),
      onChanged: (v) => a['title'] = v,
    );
    Widget text() => PrismTextField(
      controller: _text,
      labelText: tr(context, 'Text', 'Texto'),
      maxLines: 3,
      minLines: 1,
      onChanged: (v) => a['text'] = v,
    );
    final body = <Widget>[
      if (type == AutoAction.notify ||
          type == AutoAction.reminder ||
          type == AutoAction.addEvent ||
          type == AutoAction.createEntry) ...[
        title(),
        const SizedBox(height: 6),
      ],
      if (type != AutoAction.counter && type != AutoAction.link) text(),
      if (type == AutoAction.reminder || type == AutoAction.addEvent)
        _num(
          context,
          tr(context, 'Minutes from now', 'Minutos desde ahora'),
          a,
          'inMinutes',
          type == AutoAction.reminder ? 30 : 60,
          widget.onChanged,
          options: const [5, 15, 30, 60, 120, 240],
        ),
      if (type == AutoAction.addEvent)
        _num(
          context,
          tr(context, 'Length (minutes)', 'Duración (minutos)'),
          a,
          'duration',
          30,
          widget.onChanged,
          options: const [15, 30, 60, 120],
        ),
      if (type == AutoAction.createEntry) ...[
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: [
            for (final (k, l) in [
              (
                TrackerKind.journalEntry,
                tr(context, 'Journal note', 'Nota del diario'),
              ),
              (
                TrackerKind.nutriDrink,
                tr(context, 'Drink of water', 'Vaso de agua'),
              ),
            ])
              PrismChip(
                label: l,
                selected: (a['kind'] ?? TrackerKind.journalEntry) == k,
                onTap: () => _set('kind', k),
              ),
          ],
        ),
        Wrap(
          spacing: 6,
          children: [
            PrismChip(
              label: tr(context, 'Whole system', 'Todo el sistema'),
              selected: a['owner'] != 'trigger',
              onTap: () => _set('owner', null),
            ),
            PrismChip(
              label: tr(context, 'The alter involved', 'El alter implicado'),
              selected: a['owner'] == 'trigger',
              onTap: () => _set('owner', 'trigger'),
            ),
          ],
        ),
        if (a['kind'] == TrackerKind.nutriDrink)
          _num(
            context,
            'ml',
            a,
            'ml',
            250,
            widget.onChanged,
            options: const [150, 250, 330, 500],
          ),
      ],
      if (type == AutoAction.setStatus) ...[
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final t in ref.watch(statusTypesProvider(lang)))
              PrismChip(
                label: t.title,
                selected: a['status'] == t.key,
                selectedColor: Color(t.color),
                onTap: () => _set('status', t.key),
              ),
          ],
        ),
        Wrap(
          spacing: 6,
          children: [
            PrismChip(
              label: tr(context, 'The alter involved', 'El alter implicado'),
              selected: a['target'] != 'member',
              onTap: () => _set('target', 'trigger'),
            ),
            PrismChip(
              label: tr(context, 'A specific alter', 'Un alter concreto'),
              selected: a['target'] == 'member',
              onTap: () => _set('target', 'member'),
            ),
          ],
        ),
        if (a['target'] == 'member')
          TrackerMemberPicker(
            label: '',
            value: a['memberId'] as String?,
            onChanged: (m) => _set('memberId', m),
          ),
        _num(
          context,
          tr(context, 'Clear after (minutes)', 'Borrar tras (minutos)'),
          a,
          'minutes',
          0,
          widget.onChanged,
          options: const [30, 60, 240, 720],
        ),
        PrismSwitchRow(
          title: tr(
            context,
            'Only if they have no status',
            'Solo si no tiene estado',
          ),
          subtitle: tr(
            context,
            'Recommended — never replaces a status someone chose.',
            'Recomendado: nunca reemplaza un estado elegido.',
          ),
          value: a['onlyIfNone'] != false,
          onChanged: (v) => _set('onlyIfNone', v),
        ),
      ],
      if (type == AutoAction.counter) ...[
        PrismTextField(
          controller: _name,
          labelText: tr(context, 'Counter name', 'Nombre del contador'),
          onChanged: (v) => a['name'] = v,
        ),
        _num(
          context,
          tr(context, 'Add', 'Sumar'),
          a,
          'by',
          1,
          widget.onChanged,
          options: const [1, 2, 5, -1],
        ),
      ],
      if (type == AutoAction.link) ...[
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final (k, l) in [
              (
                'fronter',
                tr(context, 'Who is fronting', 'Quien está al frente'),
              ),
              (
                'trigger',
                tr(context, 'The alter involved', 'El alter implicado'),
              ),
              ('location', tr(context, 'Current location', 'Lugar actual')),
              (
                'session',
                tr(context, 'Current fronting session', 'Sesión actual'),
              ),
            ])
              PrismChip(
                label: l,
                selected: (a['target'] ?? 'fronter') == k,
                onTap: () => _set('target', k),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in ref.watch(linkCategoriesProvider(lang)))
              PrismChip(
                label: c.label,
                variant: PrismChipVariant.inline,
                selected: (a['cat'] ?? 'related') == c.id,
                onTap: () => _set('cat', c.id),
              ),
          ],
        ),
      ],
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  actionLabel(context, type),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              IconButton(
                tooltip: tr(context, 'Remove', 'Quitar'),
                icon: Icon(AppIcons.close, size: 18),
                onPressed: widget.onRemove,
              ),
            ],
          ),
          ...body,
        ],
      ),
    );
  }
}
