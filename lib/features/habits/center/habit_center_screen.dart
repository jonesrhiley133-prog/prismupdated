import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/domain/models/habit.dart';
import 'package:prism_plurality/features/habits/center/habit_center_data.dart';
import 'package:prism_plurality/features/habits/center/habit_visuals.dart';
import 'package:prism_plurality/features/habits/providers/habit_providers.dart';
import 'package:prism_plurality/features/habits/views/add_edit_habit_sheet.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

const _uuid = Uuid();

/// The Habit & Routine Center: today's habits grouped into routines with
/// one-tap completion, partial progress and "up next" suggestions.
class HabitCenterScreen extends ConsumerStatefulWidget {
  const HabitCenterScreen({super.key, this.inSettings = false});

  /// Opened from Settings (habit pages live under /settings/habits).
  final bool inSettings;

  @override
  ConsumerState<HabitCenterScreen> createState() => _HabitCenterScreenState();
}

class _HabitCenterScreenState extends ConsumerState<HabitCenterScreen> {
  bool _showOther = false;

  String _path(String id) => widget.inSettings ? AppRoutePaths.settingsHabit(id) : AppRoutePaths.habit(id);

  @override
  Widget build(BuildContext context) {
    final views = ref.watch(habitViewsProvider);
    final groups = ref.watch(habitGroupsProvider);
    final theme = Theme.of(context);
    final active = [for (final v in views.values) if (v.habit.isActive) v];
    final dueToday = [
      for (final v in active)
        if (v.stateOn(DateTime.now()) case final s when s == DayState.met || s == DayState.partial || s == DayState.missed) v,
    ];
    final notToday = [for (final v in active) if (!dueToday.contains(v)) v];
    final done = dueToday.where((v) => v.stateOn(DateTime.now()) == DayState.met).length;
    final overall = dueToday.isEmpty ? 0.0 : dueToday.fold<double>(0, (a, v) => a + v.todayFraction) / dueToday.length;
    // Suggestions: habits whose prerequisite is finished today.
    final upNext = <HabitView>{};
    for (final v in dueToday) {
      if (v.stateOn(DateTime.now()) != DayState.met) continue;
      for (final id in v.meta.nextHabits) {
        final n = views[id];
        if (n != null && n.isDueToday) upNext.add(n);
      }
    }
    final grouped = <String?, List<HabitView>>{};
    for (final v in dueToday) {
      final g = groups.any((x) => x.id == v.meta.groupId) ? v.meta.groupId : null;
      grouped.putIfAbsent(g, () => []).add(v);
    }
    for (final list in grouped.values) {
      list.sort((a, b) {
        final am = a.stateOn(DateTime.now()) == DayState.met ? 1 : 0, bm = b.stateOn(DateTime.now()) == DayState.met ? 1 : 0;
        return am != bm ? am - bm : a.habit.name.compareTo(b.habit.name);
      });
    }
    final challenges = [for (final v in active) if (v.meta.challengeTarget != null) v];
    final primary = theme.colorScheme.primary;
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: tr(context, 'Habits & Routines', 'Hábitos y rutinas'),
        showBackButton: widget.inSettings || Navigator.of(context).canPop(),
        actions: [
          PrismTopBarAction(icon: PhosphorIcons.squaresFour(), tooltip: tr(context, 'Templates', 'Plantillas'), onPressed: () => showHabitTemplates(context)),
          PrismTopBarAction(icon: AppIcons.add, tooltip: tr(context, 'New habit', 'Nuevo hábito'), onPressed: _newHabit),
        ],
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: views.isEmpty
          ? EmptyState(
              icon: Icon(PhosphorIcons.checkSquareOffset()),
              title: tr(context, 'Build your first routine', 'Crea tu primera rutina'),
              subtitle: tr(context, 'Track habits you do once or many times a day — water, practice, breaks, meds — and see how they connect to mood, sleep and more.',
                  'Registra hábitos que haces una o muchas veces al día —agua, práctica, descansos, medicación— y mira cómo se relacionan con el ánimo, el sueño y más.'),
              actionLabel: tr(context, 'Start from a template', 'Empezar con una plantilla'),
              onAction: () => showHabitTemplates(context),
            )
          : Stack(
              children: [
                ListView(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, NavBarInset.of(context) + 24),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: PrismTokens.contentMaxWidth),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                GlowRing(
                                  fraction: overall,
                                  color: primary,
                                  size: 112,
                                  stroke: 10,
                                  child: Text('${(overall * 100).round()}%', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(DateFormat.MMMMEEEEd(context.dateLocale).format(DateTime.now()), style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                      const SizedBox(height: 4),
                                      Text(
                                        dueToday.isEmpty
                                            ? tr(context, 'Nothing scheduled today', 'Nada programado hoy')
                                            : tr(context, '$done of ${dueToday.length} habits on target', '$done de ${dueToday.length} hábitos con meta'),
                                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                                      ),
                                      if (upNext.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text('${tr(context, 'Up next', 'A continuación')}: ${upNext.map((v) => v.habit.name).join(', ')}', style: theme.textTheme.bodyMedium?.copyWith(color: habitGold(context))),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            for (final g in groups)
                              if (grouped[g.id] case final list?) ...[
                                _routineHeader(g.title, list, () => _editGroup(g)),
                                for (final v in list) _HabitRow(view: v, onOpen: () => context.push(_path(v.habit.id)), highlighted: upNext.contains(v)),
                                const SizedBox(height: 8),
                              ],
                            if (grouped[null] case final list?) ...[
                              if (groups.isNotEmpty && grouped.keys.any((k) => k != null)) _routineHeader(tr(context, 'Other habits', 'Otros hábitos'), list, null),
                              for (final v in list) _HabitRow(view: v, onOpen: () => context.push(_path(v.habit.id)), highlighted: upNext.contains(v)),
                            ],
                            if (challenges.isNotEmpty) ...[
                              HabitSectionTitle(icon: PhosphorIcons.flag(), title: tr(context, 'Challenges', 'Retos')),
                              for (final v in challenges)
                                Builder(
                                  builder: (context) {
                                    final start = v.meta.record?.createdAt ?? v.habit.createdAt;
                                    final n = v.completions.where((c) => c.completedAt.isAfter(start)).length;
                                    return HabitCard(
                                      accent: habitGold(context),
                                      onTap: () => context.push(_path(v.habit.id)),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          Text('${v.habit.icon ?? ''} ${v.habit.name} · $n / ${v.meta.challengeTarget}'.trim(), style: theme.textTheme.titleSmall),
                                          const SizedBox(height: 6),
                                          TrackerBar(value: (n / v.meta.challengeTarget!).clamp(0, 1).toDouble(), color: habitGold(context), height: 8),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                            ],
                            if (notToday.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () => setState(() => _showOther = !_showOther),
                                child: HabitSectionTitle(
                                  icon: _showOther ? PhosphorIcons.caretDown() : PhosphorIcons.caretRight(),
                                  title: tr(context, 'Not today (${notToday.length})', 'Hoy no (${notToday.length})'),
                                ),
                              ),
                              if (_showOther) for (final v in notToday) _HabitRow(view: v, onOpen: () => context.push(_path(v.habit.id))),
                            ],
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                PrismButton(label: tr(context, 'New routine', 'Nueva rutina'), icon: PhosphorIcons.stack(), onPressed: () => _editGroup(null)),
                                PrismButton(label: tr(context, 'Templates', 'Plantillas'), icon: PhosphorIcons.squaresFour(), onPressed: () => showHabitTemplates(context)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _routineHeader(String title, List<HabitView> list, VoidCallback? onEdit) {
    final theme = Theme.of(context);
    final met = list.where((v) => v.stateOn(DateTime.now()) == DayState.met).length;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      child: Row(
        children: [
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Text('$met/${list.length}', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(width: 10),
          Expanded(child: TrackerBar(value: list.isEmpty ? 0 : met / list.length, color: theme.colorScheme.primary, height: 4)),
          if (onEdit != null) IconButton(tooltip: tr(context, 'Edit routine', 'Editar rutina'), icon: Icon(AppIcons.edit, size: 18), onPressed: onEdit),
        ],
      ),
    );
  }

  void _newHabit() => PrismSheet.showFullScreen(context: context, builder: (ctx, scroll) => AddEditHabitSheet(scrollController: scroll));

  Future<void> _editGroup(TrackerRecord? g) async {
    final views = ref.read(habitViewsProvider).values.where((v) => v.habit.isActive).toList();
    final name = TextEditingController(text: g?.title);
    final chosen = {for (final v in views) if (g != null && v.meta.groupId == g.id) v.habit.id};
    await PrismSheet.show(
      context: context,
      title: g == null ? tr(context, 'New routine', 'Nueva rutina') : g.title,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PrismTextField(controller: name, labelText: tr(ctx, 'Routine name', 'Nombre de la rutina')),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final v in views)
                    PrismChip(label: '${v.habit.icon ?? ''} ${v.habit.name}'.trim(), selected: chosen.contains(v.habit.id), onTap: () => set(() => chosen.contains(v.habit.id) ? chosen.remove(v.habit.id) : chosen.add(v.habit.id))),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (g != null)
                    PrismButton(
                      label: tr(ctx, 'Delete routine', 'Eliminar rutina'),
                      tone: PrismButtonTone.destructive,
                      onPressed: () async {
                        for (final v in views.where((v) => v.meta.groupId == g.id)) {
                          await ref.read(habitCenterActionsProvider).saveMeta(v.habit.id, {'group': null});
                        }
                        await ref.read(trackerNotifierProvider.notifier).delete(g.id, children: false);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                    ),
                  const Spacer(),
                  PrismButton(
                    label: ctx.l10n.save,
                    tone: PrismButtonTone.filled,
                    onPressed: () async {
                      if (name.text.trim().isEmpty) return;
                      final actions = ref.read(habitCenterActionsProvider);
                      final saved = await actions.saveGroup(editing: g, name: name.text.trim(), habitIds: chosen.toList());
                      for (final v in views) {
                        final inIt = chosen.contains(v.habit.id);
                        if (inIt && v.meta.groupId != saved.id) await actions.saveMeta(v.habit.id, {'group': saved.id});
                        if (!inIt && v.meta.groupId == saved.id) await actions.saveMeta(v.habit.id, {'group': null});
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
    name.dispose();
  }
}

class _HabitRow extends ConsumerWidget {
  const _HabitRow({required this.view, required this.onOpen, this.highlighted = false});
  final HabitView view;
  final VoidCallback onOpen;
  final bool highlighted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = view.habit, m = view.meta;
    final theme = Theme.of(context);
    final color = habitColor(context, h);
    final state = view.stateOn(DateTime.now());
    final met = state == DayState.met;
    final status = switch (state) {
      DayState.skipped => tr(context, 'Skipped today', 'Omitido hoy'),
      DayState.rest => tr(context, 'Rest day', 'Descanso'),
      DayState.paused => tr(context, 'Paused', 'En pausa'),
      _ => '${fmtNum(view.todayProgress)} / ${m.target} ${unitWord(context, m, m.target)}',
    };
    final streak = view.currentStreak;
    return HabitCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      accent: highlighted ? habitGold(context) : color,
      onTap: onOpen,
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                GlowRing(fraction: view.todayFraction, color: color, size: 52, stroke: 4),
                HabitIconBadge(habit: h, size: 38),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                Text(
                  [status, if (streak > 0) '🔥 $streak', if (highlighted) tr(context, 'up next', 'siguiente')].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                if (m.target > 1 && m.unit == HabitUnit.times && m.target <= 12) ...[
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      for (var i = 0; i < m.target; i++)
                        Expanded(
                          child: Container(
                            height: 4,
                            margin: const EdgeInsets.only(right: 3),
                            decoration: BoxDecoration(
                              color: i < view.todayProgress ? color : theme.colorScheme.onSurface.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _QuickButton(view: view, met: met, color: color),
        ],
      ),
    );
  }
}

class _QuickButton extends ConsumerWidget {
  const _QuickButton({required this.view, required this.met, required this.color});
  final HabitView view;
  final bool met;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = view.meta;
    return Tooltip(
      message: tr(context, 'Log one more', 'Registrar uno más'),
      child: Material(
        color: met ? color : color.withValues(alpha: 0.14),
        shape: CircleBorder(side: BorderSide(color: color.withValues(alpha: 0.7), width: 1.4)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            await ref.read(habitCenterActionsProvider).log(
              habit: view.habit,
              memberId: currentFronterId(ref),
              minutes: m.unit == HabitUnit.minutes ? m.defaultMinutes : null,
            );
            if (!context.mounted) return;
            final now = ref.read(habitViewsProvider)[view.habit.id];
            if (now != null && !met && now.todayProgress >= m.target) {
              final next = [for (final id in m.nextHabits) ?ref.read(habitViewsProvider)[id]].where((v) => v.isDueToday).toList();
              PrismToast.show(
                context,
                message: next.isEmpty
                    ? tr(context, '${view.habit.name}: target reached 🎉', '${view.habit.name}: meta alcanzada 🎉')
                    : tr(context, 'Done! Up next: ${next.first.habit.name}', '¡Hecho! Siguiente: ${next.first.habit.name}'),
                icon: PhosphorIcons.sparkle(),
              );
            }
          },
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(met ? PhosphorIcons.check(PhosphorIconsStyle.bold) : PhosphorIcons.plus(PhosphorIconsStyle.bold), color: met ? (ThemeData.estimateBrightnessForColor(color) == Brightness.dark ? Colors.white : Colors.black) : color),
          ),
        ),
      ),
    );
  }
}

/// Prebuilt routines.
Future<void> showHabitTemplates(BuildContext context) => PrismSheet.showFullScreen(
  context: context,
  builder: (ctx, scroll) => _Templates(scroll: scroll),
);

class _TplHabit {
  const _TplHabit(this.en, this.es, this.icon, {this.target = 1, this.unit = HabitUnit.times, this.label, this.minutes, this.auto});
  final String en, es, icon;
  final int target;
  final HabitUnit unit;
  final String? label;
  final int? minutes;
  final String? auto;
}

const _templates = <(String, String, String, String, List<_TplHabit>)>[
  ('morning', 'Morning routine', 'Rutina de mañana', '🌅', [
    _TplHabit('Glass of water', 'Vaso de agua', '💧', label: 'glass', auto: 'nutri.drink'),
    _TplHabit('Stretch', 'Estirar', '🧘', unit: HabitUnit.minutes, target: 10, minutes: 10),
    _TplHabit('Make the bed', 'Hacer la cama', '🛏️'),
    _TplHabit('Breakfast', 'Desayuno', '🍳', auto: 'nutri.meal'),
  ]),
  ('evening', 'Evening routine', 'Rutina de noche', '🌙', [
    _TplHabit('Wind down', 'Relajarse', '🕯️', unit: HabitUnit.minutes, target: 20, minutes: 20),
    _TplHabit('Brush teeth', 'Cepillarse los dientes', '🪥'),
    _TplHabit('Journal', 'Diario', '📓', auto: 'journal.entry'),
    _TplHabit('Lights out on time', 'Apagar la luz a tiempo', '💤', auto: 'sleep'),
  ]),
  ('school', 'School', 'Estudios', '🎒', [
    _TplHabit('Study session', 'Sesión de estudio', '📚', target: 3, label: 'session', minutes: 25),
    _TplHabit('Review notes', 'Repasar apuntes', '📝'),
    _TplHabit('Pack bag', 'Preparar la mochila', '🎒'),
  ]),
  ('selfcare', 'Daily self-care', 'Autocuidado diario', '💜', [
    _TplHabit('Drink water', 'Beber agua', '💧', target: 8, label: 'glass', auto: 'nutri.drink'),
    _TplHabit('Take meds', 'Tomar la medicación', '💊', target: 2, label: 'dose'),
    _TplHabit('System check-in', 'Revisión del sistema', '💬', auto: 'mood'),
    _TplHabit('Step outside', 'Salir afuera', '🌤️'),
  ]),
  ('music', 'Music practice', 'Práctica musical', '🎵', [
    _TplHabit('Practice', 'Práctica', '🎵', target: 3, label: 'session', minutes: 25),
    _TplHabit('Scales & warm-up', 'Escalas y calentamiento', '🎼', unit: HabitUnit.minutes, target: 10, minutes: 10),
  ]),
  ('wellness', 'Wellness', 'Bienestar', '🌿', [
    _TplHabit('Move', 'Moverse', '🏃', unit: HabitUnit.minutes, target: 30, minutes: 30, auto: 'fitness.workout'),
    _TplHabit('Take a break', 'Tomar un descanso', '⏸️', target: 5, label: 'break', minutes: 5),
    _TplHabit('Eat a meal', 'Comer', '🍽️', target: 3, label: 'meal', auto: 'nutri.meal'),
  ]),
];

class _Templates extends ConsumerStatefulWidget {
  const _Templates({required this.scroll});
  final ScrollController scroll;
  @override
  ConsumerState<_Templates> createState() => _TemplatesState();
}

class _TemplatesState extends ConsumerState<_Templates> {
  final Set<String> _busy = {};

  Future<void> _add(String id, String name, List<_TplHabit> habits) async {
    setState(() => _busy.add(id));
    final actions = ref.read(habitCenterActionsProvider);
    final group = await actions.saveGroup(name: name, habitIds: const []);
    final es = Localizations.localeOf(context).languageCode == 'es';
    for (final t in habits) {
      final now = DateTime.now();
      final habit = Habit(id: _uuid.v4(), name: es ? t.es : t.en, icon: t.icon, createdAt: now, modifiedAt: now);
      await ref.read(habitNotifierProvider.notifier).createHabit(habit);
      await actions.saveMeta(habit.id, {
        'target': t.target,
        'unit': t.unit.name,
        'unitLabel': t.label,
        'defaultMinutes': t.minutes ?? 25,
        'group': group.id,
        'autoLog': t.auto,
      });
    }
    if (mounted) {
      setState(() => _busy.remove(id));
      PrismToast.show(context, message: tr(context, 'Added “$name”', 'Añadida «$name»'), icon: PhosphorIcons.check());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        children: [
          PrismSheetTopBar(title: tr(context, 'Routine templates', 'Plantillas de rutinas')),
          Expanded(
            child: ListView(
              controller: widget.scroll,
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  tr(context, 'Each template adds a routine with its habits, targets and automatic counting where it fits. Change anything afterwards.',
                      'Cada plantilla añade una rutina con sus hábitos, metas y conteo automático cuando encaja. Puedes cambiarlo todo después.'),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                for (final (id, en, es, icon, habits) in _templates)
                  HabitCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Text(icon, style: const TextStyle(fontSize: 28)),
                            const SizedBox(width: 10),
                            Expanded(child: Text(tr(context, en, es), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))),
                            PrismButton(
                              label: _busy.contains(id) ? '…' : tr(context, 'Add', 'Añadir'),
                              icon: AppIcons.add,
                              tone: PrismButtonTone.filled,
                              density: PrismControlDensity.compact,
                              onPressed: _busy.contains(id) ? () {} : () => _add(id, tr(context, en, es), habits),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        for (final t in habits)
                          Text(
                            '${t.icon} ${tr(context, t.en, t.es)} · ${t.unit == HabitUnit.minutes ? '${t.target} min' : '${t.target}× ${t.label ?? ''}'.trim()}${t.auto != null ? tr(context, ' · counts automatically', ' · cuenta solo') : ''}',
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Habits scheduled on [day], for the calendar's day panel.
class CalendarHabitsForDay extends ConsumerWidget {
  const CalendarHabitsForDay({super.key, required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final views = [
      for (final v in ref.watch(habitViewsProvider).values)
        if (v.habit.isActive)
          if (v.stateOn(day) case final s when s != DayState.rest && s != DayState.paused && !(s == DayState.future && !scheduledOn(v.habit, v.meta, day, v.completions))) (v, s),
    ];
    if (views.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr(context, 'Habits', 'Hábitos'), style: theme.textTheme.labelLarge),
          for (final (v, s) in views)
            InkWell(
              onTap: () => context.push(AppRoutePaths.habit(v.habit.id)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text(v.habit.icon?.isNotEmpty == true ? v.habit.icon! : '✓'),
                    const SizedBox(width: 8),
                    Expanded(child: Text(v.habit.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text(
                      switch (s) {
                        DayState.met => '✓ ${fmtNum(v.progressOn(day))}/${v.meta.target}',
                        DayState.skipped => tr(context, 'skipped', 'omitido'),
                        DayState.future => tr(context, 'scheduled', 'programado'),
                        _ => '${fmtNum(v.progressOn(day))}/${v.meta.target}',
                      },
                      style: theme.textTheme.labelMedium?.copyWith(color: s == DayState.met ? habitColor(context, v.habit) : theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
