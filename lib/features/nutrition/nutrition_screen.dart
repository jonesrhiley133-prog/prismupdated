import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import 'package:prism_plurality/features/nutrition/nutrition_data.dart';
import 'package:prism_plurality/features/nutrition/nutrition_meals.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

String _lang(BuildContext c) => Localizations.localeOf(c).languageCode;

enum NutriTab { today, meals, water, pantry, insights }

class NutritionScreen extends ConsumerStatefulWidget {
  const NutritionScreen({super.key, this.showBackButton = false});
  final bool showBackButton;
  @override
  ConsumerState<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends ConsumerState<NutritionScreen> {
  NutriTab _tab = NutriTab.today;
  String? _member;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: tr(context, 'Nourish', 'Nutrición'),
        showBackButton: widget.showBackButton,
        actions: [
          PrismTopBarAction(
            icon: PhosphorIcons.gearSix(),
            tooltip: tr(context, 'Nutrition settings', 'Ajustes de nutrición'),
            onPressed: () => showNutritionSettings(context),
          ),
          PrismTopBarAction(
            icon: AppIcons.add,
            tooltip: tr(context, 'Log a meal', 'Registrar comida'),
            onPressed: () => showMealEditor(context, memberId: _member),
          ),
        ],
      ),
      bodyPadding: EdgeInsets.zero,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: dark
                ? [const Color(0xFF2A1F17).withValues(alpha: 0.55), Colors.transparent]
                : [NutriColors.cream, NutriColors.cream.withValues(alpha: 0)],
            stops: const [0, 0.5],
          ),
        ),
        child: Column(
          children: [
            _NutriTabBar(tab: _tab, onTab: (t) => setState(() => _tab = t)),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(
                  key: ValueKey(_tab),
                  child: switch (_tab) {
                    NutriTab.today => _Today(member: _member, onMember: (m) => setState(() => _member = m), onTab: (t) => setState(() => _tab = t)),
                    NutriTab.meals => MealsView(member: _member, onMember: (m) => setState(() => _member = m)),
                    NutriTab.water => _WaterView(member: _member, onMember: (m) => setState(() => _member = m)),
                    NutriTab.pantry => const PantryView(),
                    NutriTab.insights => NutritionInsightsView(member: _member, onMember: (m) => setState(() => _member = m)),
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NutriTabBar extends StatelessWidget {
  const _NutriTabBar({required this.tab, required this.onTab});
  final NutriTab tab;
  final ValueChanged<NutriTab> onTab;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = [
      (NutriTab.today, PhosphorIcons.sunHorizon(), tr(context, 'Today', 'Hoy'), NutriColors.saffron),
      (NutriTab.meals, PhosphorIcons.forkKnife(), tr(context, 'Meals', 'Comidas'), NutriColors.tomato),
      (NutriTab.water, PhosphorIcons.drop(), tr(context, 'Water', 'Agua'), NutriColors.water),
      (NutriTab.pantry, PhosphorIcons.basket(), tr(context, 'Pantry', 'Despensa'), NutriColors.basil),
      (NutriTab.insights, PhosphorIcons.chartDonut(), tr(context, 'Insights', 'Resumen'), NutriColors.plum),
    ];
    return SizedBox(
      height: 64,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        children: [
          for (final (t, icon, label, color) in items)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Semantics(
                selected: tab == t,
                button: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => onTab(t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: tab == t ? color : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: tab == t ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 3))] : null,
                    ),
                    child: Row(
                      children: [
                        Icon(icon, size: 18, color: tab == t ? Colors.white : theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text(label, style: theme.textTheme.labelLarge?.copyWith(color: tab == t ? Colors.white : theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Hydration vessel that fills with today's total.
class WaterVessel extends StatelessWidget {
  const WaterVessel({super.key, required this.ml, required this.goal, required this.unit, this.size = 150});
  final int ml;
  final int? goal;
  final VolumeUnit unit;
  final double size;

  @override
  Widget build(BuildContext context) {
    final frac = goal == null || goal == 0 ? (ml / 2000).clamp(0.0, 1.0) : (ml / goal!).clamp(0.0, 1.0);
    final theme = Theme.of(context);
    return Semantics(
      label: goal == null ? fmtVolume(ml, unit) : '${fmtVolume(ml, unit)} / ${fmtVolume(goal!, unit)}',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: frac.toDouble()),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => SizedBox(
          width: size * 0.72,
          height: size,
          child: CustomPaint(
            painter: _VesselPainter(v, NutriColors.water, theme.colorScheme.outlineVariant),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(fmtVolume(ml, unit), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  if (goal != null) Text('${(ml * 100 / goal!).round()}%', style: theme.textTheme.labelMedium),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VesselPainter extends CustomPainter {
  _VesselPainter(this.frac, this.color, this.outline);
  final double frac;
  final Color color;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final glass = Path()
      ..moveTo(w * 0.08, h * 0.04)
      ..lineTo(w * 0.92, h * 0.04)
      ..lineTo(w * 0.80, h * 0.96)
      ..quadraticBezierTo(w * 0.5, h, w * 0.20, h * 0.96)
      ..close();
    canvas.save();
    canvas.clipPath(glass);
    canvas.drawRect(Offset.zero & size, Paint()..color = color.withValues(alpha: 0.08));
    final top = h * (0.96 - 0.92 * frac);
    final wave = Path()..moveTo(0, top);
    for (double x = 0; x <= w; x += 4) {
      wave.lineTo(x, top + math.sin(x / w * math.pi * 2) * 3);
    }
    wave
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      wave,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.55), color],
        ).createShader(Offset.zero & size),
    );
    canvas.restore();
    canvas.drawPath(glass, Paint()..color = outline..style = PaintingStyle.stroke..strokeWidth = 2.5);
  }

  @override
  bool shouldRepaint(_VesselPainter old) => old.frac != frac || old.color != color;
}

class QuickDrinks extends ConsumerWidget {
  const QuickDrinks({super.key, this.member});
  final String? member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bevs = ref.watch(beveragesProvider(_lang(context))).where((b) => b.quick).toList();
    final unit = ref.watch(nutriSettingsProvider).unit;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final b in bevs)
          ActionChipLike(
            icon: iconFor(b.icon),
            color: Color(b.color),
            label: '${b.title} · ${fmtVolume(b.serving, unit)}',
            onTap: () async {
              await ref.read(nutritionActionsProvider).logDrink(bev: b, ml: b.serving, memberId: member ?? currentFronterId(ref));
              if (!context.mounted) return;
              PrismToast.show(
                context,
                message: tr(context, 'Added ${b.title} · tap it in the list to change or remove', 'Añadido: ${b.title} · tócalo en la lista para cambiarlo o quitarlo'),
                icon: PhosphorIcons.drop(),
              );
            },
            onLongPress: () => showDrinkEditor(context, bev: b, member: member),
          ),
        ActionChipLike(
          icon: PhosphorIcons.plus(),
          color: Theme.of(context).colorScheme.primary,
          label: tr(context, 'Other…', 'Otro…'),
          onTap: () => showDrinkEditor(context, member: member),
        ),
      ],
    );
  }
}

/// Tappable pill with an icon (Prism-styled quick action).
class ActionChipLike extends StatelessWidget {
  const ActionChipLike({super.key, required this.icon, required this.color, required this.label, required this.onTap, this.onLongPress});
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) => Material(
    color: color.withValues(alpha: 0.14),
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [Icon(icon, size: 16, color: color), const SizedBox(width: 6), Text(label, style: Theme.of(context).textTheme.labelMedium)],
        ),
      ),
    ),
  );
}

Future<void> showDrinkEditor(BuildContext context, {Beverage? bev, String? member, TrackerRecord? editing}) => PrismSheet.show(
  context: context,
  title: tr(context, 'Log a drink', 'Registrar bebida'),
  builder: (ctx) => _DrinkEditor(bev: bev, member: member, editing: editing),
);

class _DrinkEditor extends ConsumerStatefulWidget {
  const _DrinkEditor({this.bev, this.member, this.editing});
  final Beverage? bev;
  final String? member;
  final TrackerRecord? editing;
  @override
  ConsumerState<_DrinkEditor> createState() => _DrinkEditorState();
}

class _DrinkEditorState extends ConsumerState<_DrinkEditor> {
  Beverage? _bev;
  late final _amount = TextEditingController();
  late String? _member = widget.editing?.memberId ?? widget.member ?? currentFronterId(ref);
  late DateTime _at = widget.editing?.occurredAt ?? DateTime.now();
  bool _init = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bevs = ref.watch(beveragesProvider(_lang(context)));
    final unit = ref.watch(nutriSettingsProvider).unit;
    if (!_init) {
      _init = true;
      _bev = widget.bev ?? bevs.where((b) => b.id == widget.editing?.str('bev')).firstOrNull ?? bevs.first;
      final ml = widget.editing?.integer('ml') ?? _bev!.serving;
      _amount.text = switch (unit) {
        VolumeUnit.ml => '$ml',
        VolumeUnit.oz => (ml / 29.5735).toStringAsFixed(1),
        VolumeUnit.cups => (ml / 240).toStringAsFixed(2),
      };
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final b in bevs)
                  PrismChip(
                    avatar: Icon(iconFor(b.icon), size: 14, color: Color(b.color)),
                    label: b.title,
                    selected: _bev?.id == b.id,
                    selectedColor: Color(b.color),
                    onTap: () => setState(() => _bev = b),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            PrismTextField(
              controller: _amount,
              labelText: '${tr(context, 'Amount', 'Cantidad')} (${unit.name})',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 8),
            TrackerMemberPicker(label: tr(context, 'Who', 'Quién'), value: _member, onChanged: (m) => setState(() => _member = m)),
            const SizedBox(height: 8),
            PrismButton(
              label: DateFormat.MMMd(context.dateLocale).add_jm().format(_at),
              icon: AppIcons.history,
              onPressed: () async {
                final t = await showPrismTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_at));
                if (t != null) setState(() => _at = DateTime(_at.year, _at.month, _at.day, t.hour, t.minute));
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (widget.editing != null)
                  PrismButton(
                    label: tr(context, 'Delete', 'Eliminar'),
                    tone: PrismButtonTone.destructive,
                    onPressed: () async {
                      await ref.read(trackerNotifierProvider.notifier).delete(widget.editing!.id, children: false);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                const Spacer(),
                PrismButton(
                  label: context.l10n.save,
                  tone: PrismButtonTone.filled,
                  onPressed: () async {
                    final v = double.tryParse(_amount.text.replaceAll(',', '.'));
                    if (v == null || v <= 0 || _bev == null) return;
                    final ml = toMl(v, unit);
                    if (widget.editing != null) {
                      await ref.read(trackerNotifierProvider.notifier).save(
                        widget.editing!.copyWith(title: _bev!.title, memberId: _member, occurredAt: _at).withFields({'bev': _bev!.id, 'ml': ml}),
                      );
                    } else {
                      await ref.read(nutritionActionsProvider).logDrink(bev: _bev!, ml: ml, memberId: _member, at: _at);
                    }
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Today extends ConsumerWidget {
  const _Today({required this.member, required this.onMember, required this.onTab});
  final String? member;
  final ValueChanged<String?> onMember;
  final ValueChanged<NutriTab> onTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(nutriSettingsProvider);
    final today = dayOf(DateTime.now());
    final meals = [
      for (final m in ref.watch(mealsProvider))
        if (dayOf(m.occurredAt ?? m.createdAt) == today && (member == null || m.memberId == member || m.strings('members').contains(member))) m,
    ];
    final drinks = [for (final d in ref.watch(drinksProvider)) if (dayOf(d.occurredAt ?? d.createdAt) == today && (member == null || d.memberId == member)) d];
    final ml = drinks.fold(0, (a, d) => a + drinkMl(d));
    final theme = Theme.of(context);
    final cards = <String, Widget>{
      'water': _Card(
        title: tr(context, 'Hydration', 'Hidratación'),
        icon: PhosphorIcons.drop(),
        color: NutriColors.water,
        onMore: () => onTab(NutriTab.water),
        child: Row(
          children: [
            WaterVessel(ml: ml, goal: s.goalMl, unit: s.unit, size: 130),
            const SizedBox(width: 12),
            Expanded(child: QuickDrinks(member: member)),
          ],
        ),
      ),
      'plate': _Card(
        title: tr(context, 'Today’s plate', 'El plato de hoy'),
        icon: PhosphorIcons.forkKnife(),
        color: NutriColors.tomato,
        onMore: () => onTab(NutriTab.meals),
        child: PlateRing(meals: meals, member: member),
      ),
      if (s.showNutrition && s.metrics.isNotEmpty)
        'metrics': _Card(
          title: tr(context, 'Nutrition today', 'Nutrición de hoy'),
          icon: PhosphorIcons.chartBar(),
          color: NutriColors.saffron,
          child: MetricTotals(meals: meals),
        ),
      'recent': _Card(
        title: tr(context, 'Logged today', 'Registrado hoy'),
        icon: PhosphorIcons.listChecks(),
        color: NutriColors.plum,
        child: meals.isEmpty && drinks.isEmpty
            ? Text(tr(context, 'Nothing logged yet today. That’s okay — log whatever is helpful.', 'Nada registrado hoy. Está bien: registra lo que te sirva.'),
                style: theme.textTheme.bodySmall)
            : Column(
                children: [
                  for (final m in meals) MealTile(meal: m),
                  for (final d in drinks.take(6))
                    PrismListRow(
                      dense: true,
                      leading: Icon(PhosphorIcons.drop(), color: NutriColors.water),
                      title: Text('${d.title} · ${fmtVolume(drinkMl(d), s.unit)}'),
                      subtitle: Text(DateFormat.jm(context.dateLocale).format(d.occurredAt ?? d.createdAt)),
                      onTap: () => showDrinkEditor(context, editing: d),
                    ),
                ],
              ),
      ),
      'favorites': _Card(
        title: tr(context, 'Favourites', 'Favoritos'),
        icon: PhosphorIcons.heart(),
        color: NutriColors.basil,
        onMore: () => onTab(NutriTab.pantry),
        child: FavoriteFoodsStrip(member: member),
      ),
    };
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, NavBarInset.of(context) + 24),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: PrismTokens.contentMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(DateFormat.MMMMEEEEd(context.dateLocale).format(today), style: theme.textTheme.titleMedium),
                    ),
                    PrismButton(
                      label: tr(context, 'Customise', 'Personalizar'),
                      icon: PhosphorIcons.slidersHorizontal(),
                      onPressed: () => _customise(context, ref, s),
                    ),
                  ],
                ),
                TrackerMemberFilter(value: member, onChanged: onMember),
                const SizedBox(height: 8),
                for (final k in s.dashboard)
                  if (cards[k] != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: cards[k]!),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _customise(BuildContext context, WidgetRef ref, NutriSettings s) async {
    final all = ['water', 'plate', 'metrics', 'recent', 'favorites'];
    final labels = {
      'water': tr(context, 'Hydration', 'Hidratación'),
      'plate': tr(context, 'Today’s plate', 'El plato de hoy'),
      'metrics': tr(context, 'Nutrition totals', 'Totales de nutrición'),
      'recent': tr(context, 'Logged today', 'Registrado hoy'),
      'favorites': tr(context, 'Favourites', 'Favoritos'),
    };
    var order = [...s.dashboard, for (final k in all) if (!s.dashboard.contains(k)) k];
    var on = {...s.dashboard};
    await PrismSheet.show(
      context: context,
      title: tr(context, 'Customise Today', 'Personalizar Hoy'),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => SizedBox(
          height: 360,
          child: ReorderableListView(
            onReorderItem: (a, b) => set(() {
              final x = order.removeAt(a);
              order.insert(b, x);
            }),
            children: [
              for (final k in order)
                PrismSwitchRow(
                  key: ValueKey(k),
                  title: labels[k]!,
                  value: on.contains(k),
                  onChanged: (v) => set(() => v ? on.add(k) : on.remove(k)),
                ),
            ],
          ),
        ),
      ),
    );
    await ref.read(nutritionActionsProvider).updateSettings({'dashboard': [for (final k in order) if (on.contains(k)) k]});
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.icon, required this.color, required this.child, this.onMore});
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
              if (onMore != null)
                IconButton(tooltip: tr(context, 'Open', 'Abrir'), icon: Icon(AppIcons.chevronRight, size: 18), onPressed: onMore),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _WaterView extends ConsumerStatefulWidget {
  const _WaterView({required this.member, required this.onMember});
  final String? member;
  final ValueChanged<String?> onMember;
  @override
  ConsumerState<_WaterView> createState() => _WaterViewState();
}

class _WaterViewState extends ConsumerState<_WaterView> {
  int _range = 7;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(nutriSettingsProvider);
    final drinks = ref.watch(drinksProvider);
    final byDay = hydrationByDay(drinks, memberId: widget.member);
    final today = dayOf(DateTime.now());
    final todays = [for (final d in drinks) if (dayOf(d.occurredAt ?? d.createdAt) == today && (widget.member == null || d.memberId == widget.member)) d];
    final days = [for (var i = _range - 1; i >= 0; i--) DateTime(today.year, today.month, today.day - i)];
    final values = [for (final d in days) byDay[d] ?? 0];
    final maxY = [...values, s.goalMl ?? 0].fold(500, math.max).toDouble() * 1.15;
    final logged = values.where((v) => v > 0).toList();
    final avg = logged.isEmpty ? 0 : logged.reduce((a, b) => a + b) ~/ logged.length;
    final goalDays = s.goalMl == null ? null : values.where((v) => v >= s.goalMl!).length;
    final theme = Theme.of(context);
    final bevCounts = <String, int>{};
    for (final d in drinks) {
      if (widget.member != null && d.memberId != widget.member) continue;
      bevCounts[d.title] = (bevCounts[d.title] ?? 0) + drinkMl(d);
    }
    final topBev = (bevCounts.entries.toList()..sort((a, b) => b.value - a.value)).take(5).toList();
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, NavBarInset.of(context) + 24),
      children: [
        TrackerMemberFilter(value: widget.member, onChanged: widget.onMember),
        const SizedBox(height: 8),
        Center(child: WaterVessel(ml: todays.fold(0, (a, d) => a + drinkMl(d)), goal: s.goalMl, unit: s.unit, size: 200)),
        if (s.goalMl == null)
          Center(
            child: PrismButton(
              label: tr(context, 'Set a personal goal (optional)', 'Fijar una meta personal (opcional)'),
              onPressed: () => showNutritionSettings(context),
            ),
          ),
        const SizedBox(height: 12),
        QuickDrinks(member: widget.member),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: Text(tr(context, 'History', 'Historial'), style: theme.textTheme.titleSmall)),
            for (final r in const [7, 30, 90])
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: PrismChip(label: tr(context, '$r days', '$r días'), selected: _range == r, onTap: () => setState(() => _range = r)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              maxY: maxY,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  if (s.goalMl != null) HorizontalLine(y: s.goalMl!.toDouble(), color: NutriColors.basil, strokeWidth: 2, dashArray: [6, 4]),
                ],
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: _range <= 30,
                    interval: _range <= 7 ? 1 : 5,
                    getTitlesWidget: (v, meta) {
                      final i = v.toInt();
                      if (i < 0 || i >= days.length) return const SizedBox.shrink();
                      return Text(_range <= 7 ? DateFormat.E(context.dateLocale).format(days[i]) : '${days[i].day}', style: theme.textTheme.labelSmall);
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (g, gi, rod, ri) => BarTooltipItem(
                    '${DateFormat.MMMd(context.dateLocale).format(days[g.x])}\n${fmtVolume(rod.toY.round(), s.unit)}',
                    theme.textTheme.labelSmall!.copyWith(color: Colors.white),
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < days.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: values[i].toDouble(),
                        width: _range <= 7 ? 18 : (_range <= 30 ? 6 : 2),
                        color: s.goalMl != null && values[i] >= s.goalMl! ? NutriColors.basil : NutriColors.water,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        TrackerStatGrid(
          children: [
            TrackerStatTile(label: tr(context, 'Daily average', 'Media diaria'), value: fmtVolume(avg, s.unit), icon: PhosphorIcons.drop()),
            if (goalDays != null)
              TrackerStatTile(label: tr(context, 'Days at goal', 'Días con meta'), value: '$goalDays/$_range', icon: PhosphorIcons.target()),
          ],
        ),
        if (topBev.isNotEmpty) ...[
          const SizedBox(height: 12),
          TrackerLabel(tr(context, 'Favourite drinks', 'Bebidas favoritas')),
          for (final e in topBev) PrismListRow(dense: true, title: Text(e.key), trailing: Text(fmtVolume(e.value, s.unit))),
        ],
        const SizedBox(height: 12),
        TrackerLabel(tr(context, 'Today', 'Hoy')),
        if (todays.isEmpty) Text(tr(context, 'No drinks logged today.', 'No hay bebidas hoy.'), style: theme.textTheme.bodySmall),
        for (final d in todays)
          PrismListRow(
            dense: true,
            leading: Icon(PhosphorIcons.drop(), color: NutriColors.water),
            title: Text('${d.title} · ${fmtVolume(drinkMl(d), s.unit)}'),
            subtitle: Text([DateFormat.jm(context.dateLocale).format(d.occurredAt ?? d.createdAt), ?memberNameFor(ref, d.memberId)].join(' · ')),
            onTap: () => showDrinkEditor(context, editing: d),
          ),
      ],
    );
  }
}

Future<void> showNutritionSettings(BuildContext context) => PrismSheet.showFullScreen(
  context: context,
  builder: (ctx, scroll) => _NutriSettingsSheet(scroll: scroll),
);

class _NutriSettingsSheet extends ConsumerStatefulWidget {
  const _NutriSettingsSheet({required this.scroll});
  final ScrollController scroll;
  @override
  ConsumerState<_NutriSettingsSheet> createState() => _NutriSettingsSheetState();
}

class _NutriSettingsSheetState extends ConsumerState<_NutriSettingsSheet> {
  late final s = ref.read(nutriSettingsProvider);
  late VolumeUnit _unit = s.unit;
  late final _goal = TextEditingController(text: s.goalMl == null ? '' : '${s.goalMl}');
  late final Set<String> _metrics = {...s.metrics};
  late final Map<String, TextEditingController> _metricGoals = {
    for (final m in nutriMetrics) m.key: TextEditingController(text: s.metricGoals[m.key]?.toString() ?? ''),
  };
  late bool _rem = s.remindersOn;
  late int _remStart = s.reminderStart, _remEnd = s.reminderEnd, _remEvery = s.reminderEvery;
  late final _prefs = TextEditingController(text: s.preferences);
  late final _restr = TextEditingController(text: s.restrictions.join(', '));
  late final _sens = TextEditingController(text: s.sensitivities.join(', '));
  late bool _cal = s.showCalendar;
  late bool _showN = s.showNutrition;

  @override
  void dispose() {
    for (final c in [_goal, _prefs, _restr, _sens, ..._metricGoals.values]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = _lang(context);
    String hm(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
    return TrackerEditorScaffold(
      title: tr(context, 'Nutrition settings', 'Ajustes de nutrición'),
      canSave: true,
      scrollController: widget.scroll,
      onSave: () async {
        await ref.read(nutritionActionsProvider).updateSettings({
          'unit': _unit.name,
          'goalMl': int.tryParse(_goal.text.trim()),
          'metrics': _metrics.toList(),
          'metricGoals': {for (final e in _metricGoals.entries) if (num.tryParse(e.value.text) != null) e.key: num.parse(e.value.text)},
          'reminders': _rem,
          'remStart': _remStart,
          'remEnd': _remEnd,
          'remEvery': _remEvery,
          'prefs': _prefs.text.trim().isEmpty ? null : _prefs.text.trim(),
          'restrictions': parseTagInput(_restr.text),
          'sensitivities': parseTagInput(_sens.text),
          'calendar': _cal,
          'showNutrition': _showN,
        });
        if (context.mounted) Navigator.of(context).pop();
      },
      children: [
        Text(
          tr(context, 'Everything here is optional. Prism doesn’t set targets for you — add your own only if they help.',
              'Todo es opcional. Prism no fija metas por ti; añade las tuyas solo si te ayudan.'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        TrackerLabel(tr(context, 'Units', 'Unidades')),
        PrismSegmentedControl<VolumeUnit>(
          segments: [for (final u in VolumeUnit.values) PrismSegment(value: u, label: u.name)],
          selected: _unit,
          onChanged: (u) => setState(() => _unit = u),
        ),
        const SizedBox(height: 12),
        PrismTextField(
          controller: _goal,
          labelText: tr(context, 'Personal hydration goal in ml (leave empty for none)', 'Meta personal de hidratación en ml (vacío = ninguna)'),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        PrismSwitchRow(
          title: tr(context, 'Track nutrition values', 'Registrar valores nutricionales'),
          subtitle: tr(context, 'Turn off to log meals without numbers.', 'Desactívalo para registrar comidas sin números.'),
          value: _showN,
          onChanged: (v) => setState(() => _showN = v),
        ),
        if (_showN) ...[
          TrackerLabel(tr(context, 'Metrics to show', 'Métricas a mostrar')),
          for (final m in nutriMetrics)
            Row(
              children: [
                Checkbox(value: _metrics.contains(m.key), onChanged: (v) => setState(() => v == true ? _metrics.add(m.key) : _metrics.remove(m.key))),
                Expanded(child: Text('${lang == 'es' ? m.es : m.en} (${m.unit})')),
                if (_metrics.contains(m.key))
                  SizedBox(
                    width: 110,
                    child: PrismTextField(controller: _metricGoals[m.key], hintText: tr(context, 'goal', 'meta'), keyboardType: TextInputType.number, isDense: true),
                  ),
              ],
            ),
        ],
        const SizedBox(height: 12),
        PrismSwitchRow(
          title: tr(context, 'Hydration reminders', 'Recordatorios de hidratación'),
          value: _rem,
          onChanged: (v) => setState(() => _rem = v),
        ),
        if (_rem)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PrismButton(
                label: '${tr(context, 'From', 'Desde')} ${hm(_remStart)}',
                onPressed: () async {
                  final t = await showPrismTimePicker(context: context, initialTime: TimeOfDay(hour: _remStart ~/ 60, minute: _remStart % 60));
                  if (t != null) setState(() => _remStart = t.hour * 60 + t.minute);
                },
              ),
              PrismButton(
                label: '${tr(context, 'Until', 'Hasta')} ${hm(_remEnd)}',
                onPressed: () async {
                  final t = await showPrismTimePicker(context: context, initialTime: TimeOfDay(hour: _remEnd ~/ 60, minute: _remEnd % 60));
                  if (t != null) setState(() => _remEnd = t.hour * 60 + t.minute);
                },
              ),
              for (final e in const [60, 90, 120, 180])
                PrismChip(label: tr(context, 'every ${e ~/ 60}h${e % 60 == 0 ? '' : '30'}', 'cada ${e ~/ 60}h${e % 60 == 0 ? '' : '30'}'), selected: _remEvery == e, onTap: () => setState(() => _remEvery = e)),
            ],
          ),
        const SizedBox(height: 12),
        TrackerLabel(tr(context, 'Food preferences & dietary notes', 'Preferencias y notas dietéticas')),
        PrismTextField(controller: _prefs, labelText: tr(context, 'Preferences, comfort foods, textures…', 'Preferencias, comidas reconfortantes, texturas…'), maxLines: 4, minLines: 2),
        const SizedBox(height: 8),
        PrismTextField(controller: _restr, labelText: tr(context, 'Dietary restrictions (optional)', 'Restricciones dietéticas (opcional)')),
        const SizedBox(height: 8),
        PrismTextField(controller: _sens, labelText: tr(context, 'Sensitivities or allergies (optional)', 'Sensibilidades o alergias (opcional)')),
        PrismSwitchRow(title: tr(context, 'Show meal calendar', 'Mostrar calendario de comidas'), value: _cal, onChanged: (v) => setState(() => _cal = v)),
        const SizedBox(height: 8),
        PrismButton(label: tr(context, 'Meal categories', 'Categorías de comida'), icon: PhosphorIcons.tag(), onPressed: () => showMealCategoryManager(context)),
        const SizedBox(height: 8),
        PrismButton(label: tr(context, 'Drinks & serving sizes', 'Bebidas y raciones'), icon: PhosphorIcons.drop(), onPressed: () => showBeverageManager(context)),
      ],
    );
  }
}

Future<void> showBeverageManager(BuildContext context) => PrismSheet.show(
  context: context,
  title: tr(context, 'Drinks', 'Bebidas'),
  builder: (ctx) => Consumer(
    builder: (ctx, ref, _) {
      final bevs = ref.watch(beveragesProvider(_lang(ctx)));
      final unit = ref.watch(nutriSettingsProvider).unit;
      return ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          for (final b in bevs)
            PrismListRow(
              leading: Icon(iconFor(b.icon), color: Color(b.color)),
              title: Text(b.title),
              subtitle: Text('${fmtVolume(b.serving, unit)}${b.quick ? tr(ctx, ' · quick add', ' · acceso rápido') : ''}'),
              showChevron: true,
              onTap: () => _editBeverage(ctx, ref, b),
            ),
          PrismButton(label: tr(ctx, 'New drink', 'Nueva bebida'), icon: AppIcons.add, tone: PrismButtonTone.filled, onPressed: () => _editBeverage(ctx, ref, null)),
        ],
      );
    },
  ),
);

Future<void> _editBeverage(BuildContext context, WidgetRef ref, Beverage? b) async {
  final builtin = b != null && builtInBeverages.any((x) => x.$1 == b.id) ? b.id : null;
  final name = TextEditingController(text: b?.title);
  final ml = TextEditingController(text: '${b?.serving ?? 250}');
  var icon = b?.icon ?? 'cup';
  var color = b?.color ?? 0xFF3A8DDE;
  var quick = b?.quick ?? true;
  await PrismSheet.show(
    context: context,
    title: b?.title ?? tr(context, 'New drink', 'Nueva bebida'),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (builtin == null) PrismTextField(controller: name, labelText: tr(ctx, 'Name', 'Nombre')),
            const SizedBox(height: 8),
            PrismTextField(controller: ml, labelText: tr(ctx, 'Serving size (ml)', 'Ración (ml)'), keyboardType: TextInputType.number),
            PrismSwitchRow(title: tr(ctx, 'Show as quick add', 'Mostrar en acceso rápido'), value: quick, onChanged: (v) => set(() => quick = v)),
            ColorChoiceRow(value: color, onChanged: (v) => set(() => color = v)),
            const SizedBox(height: 8),
            IconChoiceGrid(value: icon, color: Color(color), keys: const ['drop', 'cup', 'coffee', 'tea', 'orange', 'bottle', 'water', 'wine', 'beer', 'leaf', 'heart'], onChanged: (v) => set(() => icon = v)),
            const SizedBox(height: 12),
            PrismButton(
              label: ctx.l10n.save,
              tone: PrismButtonTone.filled,
              onPressed: () async {
                final t = ref.read(trackerNotifierProvider.notifier);
                final fields = {'icon': icon, 'color': color, 'ml': int.tryParse(ml.text) ?? 250, 'quick': quick, 'builtin': builtin};
                if (b?.record != null) {
                  await t.save(b!.record!.copyWith(title: builtin == null ? name.text.trim() : b.title).withFields(fields));
                } else if (builtin != null || name.text.trim().isNotEmpty) {
                  await t.create(kind: TrackerKind.nutriBeverage, title: builtin == null ? name.text.trim() : b!.title, fields: fields);
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
      ),
    ),
  );
  name.dispose();
  ml.dispose();
}

/// Compact Home card: today's hydration with quick-add buttons.
class HydrationDashboardCard extends ConsumerWidget {
  const HydrationDashboardCard({super.key, this.onOpen});
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(nutriSettingsProvider);
    final today = dayOf(DateTime.now());
    final ml = ref.watch(drinksProvider).where((d) => dayOf(d.occurredAt ?? d.createdAt) == today).fold(0, (a, d) => a + drinkMl(d));
    return PrismSurface(
      onTap: onOpen,
      child: Row(
        children: [
          WaterVessel(ml: ml, goal: s.goalMl, unit: s.unit, size: 96),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(context, 'Hydration', 'Hidratación'), style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                const QuickDrinks(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
