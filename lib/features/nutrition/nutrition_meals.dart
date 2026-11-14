import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/links/models/record_ref.dart';
import 'package:prism_plurality/features/links/widgets/related_records.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/nutrition/nutrition_data.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/media/prism_media.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

String _lang(BuildContext c) => Localizations.localeOf(c).languageCode;

void registerNutritionOpeners(Map<String, void Function(BuildContext, String)> openers) {
  openers[TrackerKind.nutriMeal] = (c, id) => showMealDetail(c, id);
}

const mealFeelings = [
  ('satisfied', '😌', 'Satisfied', 'Satisfecho'),
  ('energised', '⚡', 'Energised', 'Con energía'),
  ('neutral', '😐', 'Neutral', 'Neutral'),
  ('heavy', '🥱', 'Heavy', 'Pesado'),
  ('unwell', '🤢', 'Unwell', 'Mal'),
  ('comforted', '🤗', 'Comforted', 'Reconfortado'),
];

/// Circular "plate" with a slice per meal category.
class PlateRing extends ConsumerWidget {
  const PlateRing({super.key, required this.meals, this.member});
  final List<TrackerRecord> meals;
  final String? member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(mealCategoriesProvider(_lang(context)));
    final theme = Theme.of(context);
    final counts = {for (final c in cats) c.id: meals.where((m) => (m.str('cat') ?? 'snack') == c.id).length};
    return Row(
      children: [
        SizedBox(
          width: 130,
          height: 130,
          child: CustomPaint(
            painter: _PlatePainter([for (final c in cats) (catColor(context, c), counts[c.id]! > 0)], theme.colorScheme.surfaceContainerHighest),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${meals.length}', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  Text(tr(context, 'logged', 'registradas'), style: theme.textTheme.labelSmall),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final c in cats)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => showMealEditor(context, category: c.id, memberId: member),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                    child: Row(
                      children: [
                        Icon(iconFor(c.icon), size: 16, color: catColor(context, c)),
                        const SizedBox(width: 6),
                        Expanded(child: Text(c.title, style: theme.textTheme.bodyMedium)),
                        Text(counts[c.id]! > 0 ? '✓ ${counts[c.id]}' : '+', style: theme.textTheme.labelLarge?.copyWith(color: catColor(context, c))),
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

class _PlatePainter extends CustomPainter {
  _PlatePainter(this.slices, this.empty);
  final List<(Color, bool)> slices;
  final Color empty;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2;
    canvas.drawCircle(c, r, Paint()..color = empty.withValues(alpha: 0.5));
    canvas.drawCircle(c, r * 0.72, Paint()..color = empty);
    final n = slices.length;
    for (var i = 0; i < n; i++) {
      final (color, filled) = slices[i];
      final p = Paint()
        ..color = filled ? color : color.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.22
        ..strokeCap = StrokeCap.round;
      final sweep = 2 * math.pi / n;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r * 0.86), -math.pi / 2 + i * sweep + 0.08, sweep - 0.16, false, p);
    }
  }

  @override
  bool shouldRepaint(_PlatePainter old) => true;
}

class MetricTotals extends ConsumerWidget {
  const MetricTotals({super.key, required this.meals});
  final List<TrackerRecord> meals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(nutriSettingsProvider);
    final lang = _lang(context);
    final totals = <String, num>{};
    for (final m in meals) {
      mealNutrition(m).forEach((k, v) => totals[k] = (totals[k] ?? 0) + v);
    }
    final theme = Theme.of(context);
    return Column(
      children: [
        for (final key in s.metrics)
          if (nutriMetrics.where((m) => m.key == key).firstOrNull case final metric?)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(width: 110, child: Text(lang == 'es' ? metric.es : metric.en, style: theme.textTheme.bodySmall)),
                  Expanded(
                    child: s.metricGoals[key] == null
                        ? const SizedBox.shrink()
                        : TrackerBar(value: ((totals[key] ?? 0) / s.metricGoals[key]!).clamp(0, 1).toDouble(), color: context.nutri.saffron),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(totals[key] ?? 0).round()}${s.metricGoals[key] == null ? '' : ' / ${s.metricGoals[key]!.round()}'} ${metric.unit}',
                    style: theme.textTheme.labelMedium,
                  ),
                ],
              ),
            ),
        if (totals.isEmpty)
          Text(tr(context, 'Add nutrition values to meals to see totals here.', 'Añade valores nutricionales a las comidas para ver totales.'), style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class MealTile extends ConsumerWidget {
  const MealTile({super.key, required this.meal});
  final TrackerRecord meal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = {for (final c in ref.watch(mealCategoriesProvider(_lang(context)))) c.id: c};
    final c = cats[meal.str('cat')] ?? cats['snack'];
    final media = meal.strings('media').where((m) => !m.startsWith('audio:')).toList();
    final feel = mealFeelings.where((f) => f.$1 == meal.str('feel')).firstOrNull;
    return PrismSurface(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      onTap: () => showMealDetail(context, meal.id),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 48,
              height: 48,
              child: media.isNotEmpty && !meal.isPrivate
                  ? PrismMediaView(id: media.first)
                  : ColoredBox(color: catColor(context, c).withValues(alpha: 0.18), child: Icon(iconFor(c?.icon), color: catColor(context, c))),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(meal.isPrivate ? '🔒 ${tr(context, 'Private meal', 'Comida privada')}' : meal.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  [
                    c?.title ?? '',
                    DateFormat.jm(context.dateLocale).format(meal.occurredAt ?? meal.createdAt),
                    ?memberNameFor(ref, meal.memberId),
                    if (mealNutrition(meal)['kcal'] != null) '${mealNutrition(meal)['kcal']!.round()} kcal',
                  ].join(' · '),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          if (feel != null) Text(feel.$2, style: const TextStyle(fontSize: 20)),
        ],
      ),
    );
  }
}

class FavoriteFoodsStrip extends ConsumerWidget {
  const FavoriteFoodsStrip({super.key, this.member});
  final String? member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foods = [for (final f in ref.watch(foodsProvider)) if (f.flag('favorite')) f];
    if (foods.isEmpty) {
      return Text(
        tr(context, 'Save meals you have often as favourites to log them in one tap.', 'Guarda comidas frecuentes como favoritas para registrarlas con un toque.'),
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return SizedBox(
      height: 92,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [for (final f in foods) _FoodChip(food: f, member: member)],
      ),
    );
  }
}

class _FoodChip extends ConsumerWidget {
  const _FoodChip({required this.food, this.member});
  final TrackerRecord food;
  final String? member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = food.strings('media');
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => logFood(context, ref, food, member),
        onLongPress: () => showMealEditor(context, food: food),
        child: SizedBox(
          width: 84,
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: media.isNotEmpty ? PrismMediaView(id: media.first) : ColoredBox(color: context.nutri.basil.withValues(alpha: 0.2), child: Icon(PhosphorIcons.bowlFood(), color: context.nutri.basil)),
                ),
              ),
              const SizedBox(height: 4),
              Text(food.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// Logs a saved food as a meal right now.
Future<void> logFood(BuildContext context, WidgetRef ref, TrackerRecord food, String? member) async {
  final hour = DateTime.now().hour;
  final cat = food.str('cat') ?? (hour < 11 ? 'breakfast' : hour < 15 ? 'lunch' : hour < 21 ? 'dinner' : 'snack');
  await ref.read(nutritionActionsProvider).saveMeal(
    title: food.title,
    body: food.body,
    memberId: member ?? currentFronterId(ref),
    fields: {'cat': cat, 'ingredients': food.strings('ingredients'), 'n': food.fields['n'], 'media': food.strings('media'), 'foodId': food.id},
  );
  await ref.read(trackerNotifierProvider.notifier).save(food.withFields({'uses': (food.integer('uses') ?? 0) + 1}));
  if (context.mounted) PrismToast.show(context, message: tr(context, 'Logged ${food.title}', 'Registrado: ${food.title}'), icon: PhosphorIcons.check());
}

class MealsView extends ConsumerStatefulWidget {
  const MealsView({super.key, required this.member, required this.onMember});
  final String? member;
  final ValueChanged<String?> onMember;
  @override
  ConsumerState<MealsView> createState() => _MealsViewState();
}

class _MealsViewState extends ConsumerState<MealsView> {
  DateTime _day = dayOf(DateTime.now());
  bool _calendar = false;
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(nutriSettingsProvider);
    final cats = ref.watch(mealCategoriesProvider(_lang(context)));
    final all = [
      for (final m in ref.watch(mealsProvider))
        if (widget.member == null || m.memberId == widget.member || m.strings('members').contains(widget.member)) m,
    ];
    final q = _q.text.trim().toLowerCase();
    final theme = Theme.of(context);
    final children = <Widget>[
      TrackerMemberFilter(value: widget.member, onChanged: widget.onMember),
      PrismTextField(controller: _q, hintText: tr(context, 'Search meals and ingredients', 'Buscar comidas e ingredientes'), prefixIcon: Icon(AppIcons.search), onChanged: (_) => setState(() {})),
      const SizedBox(height: 8),
    ];
    if (q.isNotEmpty) {
      final hits = [for (final m in all) if ('${m.title} ${m.body ?? ''} ${m.strings('ingredients').join(' ')} ${m.tags.join(' ')}'.toLowerCase().contains(q)) m];
      children.addAll([for (final m in hits.take(200)) MealTile(meal: m)]);
      if (hits.isEmpty) children.add(Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(tr(context, 'No matching meals', 'No hay comidas que coincidan')))));
    } else {
      children.add(
        Row(
          children: [
            IconButton(tooltip: tr(context, 'Previous day', 'Día anterior'), icon: Icon(PhosphorIcons.caretLeft()), onPressed: () => setState(() => _day = DateTime(_day.year, _day.month, _day.day - 1))),
            Expanded(
              child: Text(DateFormat.yMMMEd(context.dateLocale).format(_day), textAlign: TextAlign.center, style: theme.textTheme.titleSmall),
            ),
            IconButton(tooltip: tr(context, 'Next day', 'Día siguiente'), icon: Icon(PhosphorIcons.caretRight()), onPressed: () => setState(() => _day = DateTime(_day.year, _day.month, _day.day + 1))),
            if (s.showCalendar)
              IconButton(
                tooltip: tr(context, 'Meal calendar', 'Calendario de comidas'),
                icon: Icon(_calendar ? PhosphorIcons.list() : PhosphorIcons.calendarBlank()),
                onPressed: () => setState(() => _calendar = !_calendar),
              ),
          ],
        ),
      );
      if (_calendar && s.showCalendar) {
        children.add(_MealCalendar(meals: all, month: _day, onDay: (d) => setState(() {
          _day = d;
          _calendar = false;
        })));
      } else {
        final dayMeals = [for (final m in all) if (dayOf(m.occurredAt ?? m.createdAt) == _day) m];
        for (final c in cats) {
          final list = dayMeals.where((m) => (m.str('cat') ?? 'snack') == c.id).toList();
          children.add(
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Row(
                children: [
                  Icon(iconFor(c.icon), size: 18, color: catColor(context, c)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(c.title, style: theme.textTheme.titleSmall)),
                  IconButton(
                    tooltip: tr(context, 'Add to ${c.title}', 'Añadir a ${c.title}'),
                    icon: Icon(AppIcons.addCircleOutline, color: catColor(context, c)),
                    onPressed: () => showMealEditor(context, category: c.id, memberId: widget.member, date: _day),
                  ),
                ],
              ),
            ),
          );
          children.addAll([for (final m in list) MealTile(meal: m)]);
        }
        if (s.showNutrition && dayMeals.isNotEmpty) {
          children.addAll([const SizedBox(height: 8), TrackerLabel(tr(context, 'Day totals', 'Totales del día')), MetricTotals(meals: dayMeals)]);
        }
      }
    }
    return ListView(padding: EdgeInsets.fromLTRB(16, 0, 16, NavBarInset.of(context) + 24), children: children);
  }
}

class _MealCalendar extends StatelessWidget {
  const _MealCalendar({required this.meals, required this.month, required this.onDay});
  final List<TrackerRecord> meals;
  final DateTime month;
  final ValueChanged<DateTime> onDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = DateTime(month.year, month.month);
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final counts = <int, int>{};
    for (final m in meals) {
      final d = m.occurredAt ?? m.createdAt;
      if (d.year == month.year && d.month == month.month) counts[d.day] = (counts[d.day] ?? 0) + 1;
    }
    return Column(
      children: [
        Text(DateFormat.yMMMM(context.dateLocale).format(first), style: theme.textTheme.titleSmall),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (var i = 0; i < first.weekday - 1; i++) const SizedBox.shrink(),
            for (var d = 1; d <= days; d++)
              InkWell(
                onTap: () => onDay(DateTime(month.year, month.month, d)),
                borderRadius: BorderRadius.circular(10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$d', style: theme.textTheme.labelMedium),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var k = 0; k < math.min(counts[d] ?? 0, 4); k++)
                          Container(width: 5, height: 5, margin: const EdgeInsets.all(1), decoration: BoxDecoration(color: context.nutri.tomato, shape: BoxShape.circle)),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

Future<void> showMealDetail(BuildContext context, String id) => PrismSheet.showFullScreen(
  context: context,
  builder: (ctx, scroll) => Consumer(
    builder: (ctx, ref, _) {
      final m = ref.watch(mealsProvider).where((x) => x.id == id).firstOrNull;
      if (m == null) return Center(child: Text(tr(ctx, 'This meal was deleted.', 'Esta comida fue eliminada.')));
      final cats = {for (final c in ref.watch(mealCategoriesProvider(_lang(ctx)))) c.id: c};
      final n = mealNutrition(m);
      final lang = _lang(ctx);
      final feel = mealFeelings.where((f) => f.$1 == m.str('feel')).firstOrNull;
      final theme = Theme.of(ctx);
      return SafeArea(
        child: Column(
          children: [
            PrismSheetTopBar(
              title: m.title,
              trailing: IconButton(tooltip: ctx.l10n.edit, icon: Icon(AppIcons.edit), onPressed: () => showMealEditor(ctx, editing: m)),
            ),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    [
                      cats[m.str('cat')]?.title ?? '',
                      DateFormat.yMMMEd(ctx.dateLocale).add_jm().format(m.occurredAt ?? m.createdAt),
                      ?memberNameFor(ref, m.memberId),
                    ].join(' · '),
                    style: theme.textTheme.labelMedium,
                  ),
                  if (m.strings('members').isNotEmpty)
                    Text('👥 ${[for (final x in m.strings('members')) ?memberNameFor(ref, x)].join(', ')}', style: theme.textTheme.bodySmall),
                  if (m.strings('media').isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 200,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final id in m.strings('media'))
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: id.startsWith('audio:')
                                  ? Center(child: AudioClip(id: id))
                                  : ClipRRect(borderRadius: BorderRadius.circular(16), child: SizedBox(width: 200, child: PrismMediaView(id: id))),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (m.body != null) ...[const SizedBox(height: 12), PrivateReveal(isPrivate: m.isPrivate, child: Text(m.body!))],
                  if (m.strings('ingredients').isNotEmpty) ...[
                    const SizedBox(height: 12),
                    TrackerLabel(tr(ctx, 'Ingredients', 'Ingredientes')),
                    Text(m.strings('ingredients').join(', ')),
                  ],
                  if (n.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    TrackerLabel(tr(ctx, 'Nutrition', 'Nutrición')),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final metric in nutriMetrics)
                          if (n[metric.key] != null) PrismChip(label: '${lang == 'es' ? metric.es : metric.en}: ${n[metric.key]} ${metric.unit}', selected: false, onTap: () {}),
                      ],
                    ),
                  ],
                  if (feel != null || m.str('experience') != null) ...[
                    const SizedBox(height: 12),
                    TrackerLabel(tr(ctx, 'How it felt', 'Cómo se sintió')),
                    if (feel != null) Text('${feel.$2} ${tr(ctx, feel.$3, feel.$4)}'),
                    if (m.str('experience') != null) Text(m.str('experience')!),
                  ],
                  if (m.tags.isNotEmpty) ...[const SizedBox(height: 8), TagWrap(tags: m.tags)],
                  RelatedRecordsSection(self: RecordRef(RecordRef.rec, m.id)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      PrismButton(
                        label: tr(ctx, 'Save as favourite', 'Guardar como favorita'),
                        icon: PhosphorIcons.heart(),
                        onPressed: () async {
                          await ref.read(nutritionActionsProvider).saveAsFood(m);
                          if (ctx.mounted) PrismToast.show(ctx, message: tr(ctx, 'Saved to your pantry', 'Guardado en tu despensa'));
                        },
                      ),
                      PrismButton(
                        label: tr(ctx, 'Log again', 'Registrar otra vez'),
                        icon: AppIcons.copy,
                        onPressed: () async {
                          await ref.read(nutritionActionsProvider).saveMeal(title: m.title, body: m.body, memberId: m.memberId, fields: {...m.fields, 'feel': null, 'experience': null}, tags: m.tags);
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        },
                      ),
                      PrismButton(
                        label: tr(ctx, 'Delete', 'Eliminar'),
                        tone: PrismButtonTone.destructive,
                        icon: AppIcons.delete,
                        onPressed: () async {
                          final ok = await PrismDialog.confirm(
                            context: ctx,
                            title: tr(ctx, 'Delete this meal?', '¿Eliminar esta comida?'),
                            destructive: true,
                            confirmLabel: tr(ctx, 'Delete', 'Eliminar'),
                            cancelLabel: ctx.l10n.cancel,
                          );
                          if (!ok) return;
                          await ref.read(trackerNotifierProvider.notifier).delete(m.id);
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  ),
);

/// Meal editor; [food] edits a saved pantry food instead of a meal.
Future<void> showMealEditor(BuildContext context, {TrackerRecord? editing, TrackerRecord? food, bool asFood = false, String? category, String? memberId, DateTime? date}) =>
    PrismSheet.showFullScreen(
      context: context,
      builder: (ctx, scroll) => _MealEditor(editing: editing ?? food, isFood: food != null || asFood, category: category, memberId: memberId, date: date, scroll: scroll),
    );

class _MealEditor extends ConsumerStatefulWidget {
  const _MealEditor({this.editing, required this.isFood, this.category, this.memberId, this.date, required this.scroll});
  final TrackerRecord? editing;
  final bool isFood;
  final String? category;
  final String? memberId;
  final DateTime? date;
  final ScrollController scroll;
  @override
  ConsumerState<_MealEditor> createState() => _MealEditorState();
}

class _MealEditorState extends ConsumerState<_MealEditor> {
  late final e = widget.editing;
  late final _title = TextEditingController(text: e?.title);
  late final _body = TextEditingController(text: e?.body);
  late final _ingredients = TextEditingController(text: e?.strings('ingredients').join(', '));
  late final _experience = TextEditingController(text: e?.str('experience'));
  late final _tags = TextEditingController(text: e?.tags.join(', '));
  late final Map<String, TextEditingController> _n = {
    for (final m in nutriMetrics) m.key: TextEditingController(text: e == null ? '' : (mealNutrition(e!)[m.key]?.toString() ?? '')),
  };
  late String _cat = e?.str('cat') ?? widget.category ?? _guessCat();
  late String? _member = widget.isFood ? null : (e?.memberId ?? widget.memberId ?? currentFronterId(ref));
  late final Set<String> _members = {...?e?.strings('members')};
  late DateTime _at = e?.occurredAt ?? (widget.date == null ? DateTime.now() : DateTime(widget.date!.year, widget.date!.month, widget.date!.day, DateTime.now().hour, DateTime.now().minute));
  late List<String> _media = [...?e?.strings('media')];
  late String? _feel = e?.str('feel');
  late bool _private = e?.isPrivate ?? false;
  late bool _favorite = e?.flag('favorite') ?? true;
  bool _showNutrition = false;

  static String _guessCat() {
    final h = DateTime.now().hour;
    return h < 11 ? 'breakfast' : h < 15 ? 'lunch' : h < 21 ? 'dinner' : 'snack';
  }

  @override
  void dispose() {
    for (final c in [_title, _body, _ingredients, _experience, _tags, ..._n.values]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(mealCategoriesProvider(_lang(context)));
    final s = ref.watch(nutriSettingsProvider);
    final lang = _lang(context);
    final members = ref.watch(activeMembersProvider).value ?? const <Member>[];
    final preferDisplay = ref.watch(memberNamePreferDisplayProvider);
    final foods = ref.watch(foodsProvider);
    final suggestions = _title.text.trim().length < 2 || widget.isFood
        ? const <TrackerRecord>[]
        : [for (final f in foods) if (f.title.toLowerCase().contains(_title.text.trim().toLowerCase())) f].take(4).toList();
    return TrackerEditorScaffold(
      title: widget.isFood
          ? tr(context, 'Pantry food', 'Comida de despensa')
          : (e == null ? tr(context, 'Log a meal', 'Registrar comida') : tr(context, 'Edit meal', 'Editar comida')),
      canSave: _title.text.trim().isNotEmpty,
      scrollController: widget.scroll,
      onSave: _save,
      children: [
        PrismTextField(controller: _title, labelText: tr(context, 'What did you have?', '¿Qué comiste?'), onChanged: (_) => setState(() {})),
        for (final f in suggestions)
          PrismListRow(
            dense: true,
            leading: Icon(PhosphorIcons.heart(), color: context.nutri.basil),
            title: Text(tr(context, 'Use saved: ${f.title}', 'Usar guardada: ${f.title}')),
            onTap: () => setState(() {
              _title.text = f.title;
              _body.text = f.body ?? '';
              _ingredients.text = f.strings('ingredients').join(', ');
              mealNutrition(f).forEach((k, v) => _n[k]?.text = '$v');
              if (f.str('cat') != null) _cat = f.str('cat')!;
              if (_media.isEmpty) _media = f.strings('media');
            }),
          ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in cats)
              PrismChip(
                avatar: Icon(iconFor(c.icon), size: 14, color: catColor(context, c)),
                label: c.title,
                selected: _cat == c.id,
                selectedColor: catColor(context, c),
                onTap: () => setState(() => _cat = c.id),
              ),
          ],
        ),
        if (!widget.isFood) ...[
          const SizedBox(height: 8),
          PrismButton(
            label: DateFormat.yMMMEd(context.dateLocale).add_jm().format(_at),
            icon: AppIcons.calendarToday,
            onPressed: () async {
              final d = await showPrismDatePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 365)), initialDate: _at);
              if (d == null || !context.mounted) return;
              final t = await showPrismTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_at));
              setState(() => _at = DateTime(d.year, d.month, d.day, t?.hour ?? _at.hour, t?.minute ?? _at.minute));
            },
          ),
          const SizedBox(height: 8),
          TrackerMemberPicker(label: tr(context, 'Logged by', 'Registrado por'), value: _member, onChanged: (m) => setState(() => _member = m)),
          if (members.length > 1) ...[
            TrackerLabel(tr(context, 'Shared with', 'Compartido con')),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in members)
                  if (m.id != _member)
                    PrismChip(
                      label: m.effectiveName(preferDisplayName: preferDisplay),
                      selected: _members.contains(m.id),
                      onTap: () => setState(() => _members.contains(m.id) ? _members.remove(m.id) : _members.add(m.id)),
                    ),
              ],
            ),
          ],
        ],
        const SizedBox(height: 10),
        PrismTextField(controller: _body, labelText: tr(context, 'Description (optional)', 'Descripción (opcional)'), maxLines: 4, minLines: 1),
        const SizedBox(height: 8),
        PrismTextField(controller: _ingredients, labelText: tr(context, 'Ingredients (comma separated)', 'Ingredientes (separados por comas)'), maxLines: 3, minLines: 1),
        const SizedBox(height: 10),
        TrackerLabel(tr(context, 'Photos', 'Fotos')),
        MediaAttachRow(ids: _media, allowVideo: false, owner: _member, onChanged: (v) => setState(() => _media = v)),
        if (s.showNutrition) ...[
          const SizedBox(height: 10),
          PrismButton(
            label: _showNutrition ? tr(context, 'Hide nutrition values', 'Ocultar valores') : tr(context, 'Add nutrition values (optional)', 'Añadir valores nutricionales (opcional)'),
            icon: PhosphorIcons.chartBar(),
            onPressed: () => setState(() => _showNutrition = !_showNutrition),
          ),
          if (_showNutrition)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in nutriMetrics)
                  if (s.metrics.contains(m.key) || _n[m.key]!.text.isNotEmpty)
                    SizedBox(
                      width: 150,
                      child: PrismTextField(
                        controller: _n[m.key],
                        labelText: '${lang == 'es' ? m.es : m.en} (${m.unit})',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        isDense: true,
                      ),
                    ),
              ],
            ),
        ],
        if (!widget.isFood) ...[
          const SizedBox(height: 10),
          TrackerLabel(tr(context, 'How did it feel? (optional)', '¿Cómo te sentiste? (opcional)')),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final f in mealFeelings)
                PrismChip(label: '${f.$2} ${tr(context, f.$3, f.$4)}', selected: _feel == f.$1, onTap: () => setState(() => _feel = _feel == f.$1 ? null : f.$1)),
            ],
          ),
          const SizedBox(height: 8),
          PrismTextField(controller: _experience, labelText: tr(context, 'Observations (textures, setting, how you felt after)', 'Observaciones (texturas, ambiente, cómo te sentiste)'), maxLines: 4, minLines: 1),
          const SizedBox(height: 8),
          PrismTextField(controller: _tags, labelText: tr(context, 'Tags', 'Etiquetas')),
          PrismSwitchRow(title: tr(context, 'Private', 'Privado'), value: _private, onChanged: (v) => setState(() => _private = v)),
        ] else
          PrismSwitchRow(title: tr(context, 'Favourite', 'Favorita'), value: _favorite, onChanged: (v) => setState(() => _favorite = v)),
        if (widget.isFood && e != null)
          PrismButton(
            label: tr(context, 'Delete from pantry', 'Eliminar de la despensa'),
            tone: PrismButtonTone.destructive,
            onPressed: () async {
              await ref.read(trackerNotifierProvider.notifier).delete(e!.id);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
      ],
    );
  }

  Future<void> _save() async {
    final n = {for (final e in _n.entries) if (num.tryParse(e.value.text.replaceAll(',', '.')) != null) e.key: num.parse(e.value.text.replaceAll(',', '.'))};
    final fields = <String, Object?>{
      'cat': _cat,
      'ingredients': parseTagInput(_ingredients.text),
      'n': n.isEmpty ? null : n,
      'media': _media,
    };
    final t = ref.read(trackerNotifierProvider.notifier);
    if (widget.isFood) {
      fields['favorite'] = _favorite;
      if (e != null) {
        await t.save(e!.copyWith(title: _title.text, body: _body.text).withFields(fields));
      } else {
        await t.create(kind: TrackerKind.nutriFood, title: _title.text, body: _body.text, fields: fields);
      }
    } else {
      fields['members'] = _members.toList();
      fields['feel'] = _feel;
      fields['experience'] = _experience.text.trim().isEmpty ? null : _experience.text.trim();
      await ref.read(nutritionActionsProvider).saveMeal(
        editing: e,
        title: _title.text,
        body: _body.text,
        memberId: _member,
        at: _at,
        tags: parseTagInput(_tags.text),
        isPrivate: _private,
        fields: fields,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }
}

class PantryView extends ConsumerStatefulWidget {
  const PantryView({super.key});
  @override
  ConsumerState<PantryView> createState() => _PantryViewState();
}

class _PantryViewState extends ConsumerState<PantryView> {
  String? _collection;

  @override
  Widget build(BuildContext context) {
    final foods = ref.watch(foodsProvider);
    final collections = ref.watch(collectionsProvider);
    final s = ref.watch(nutriSettingsProvider);
    final coll = collections.where((c) => c.id == _collection).firstOrNull;
    final shown = coll == null ? foods : [for (final f in foods) if (coll.strings('foods').contains(f.id)) f];
    shown.sort((a, b) => (b.integer('uses') ?? 0).compareTo(a.integer('uses') ?? 0));
    final theme = Theme.of(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, NavBarInset.of(context) + 24),
      children: [
        if (s.preferences != null || s.restrictions.isNotEmpty || s.sensitivities.isNotEmpty)
          PrismSurface(
            margin: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(context, 'Our food notes', 'Nuestras notas de comida'), style: theme.textTheme.titleSmall),
                if (s.preferences != null) Text(s.preferences!),
                if (s.restrictions.isNotEmpty) Text('${tr(context, 'Restrictions', 'Restricciones')}: ${s.restrictions.join(', ')}'),
                if (s.sensitivities.isNotEmpty) Text('${tr(context, 'Sensitivities', 'Sensibilidades')}: ${s.sensitivities.join(', ')}'),
              ],
            ),
          ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: PrismChip(label: tr(context, 'All foods', 'Todas'), selected: _collection == null, onTap: () => setState(() => _collection = null)),
              ),
              for (final c in collections)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onLongPress: () => _editCollection(context, c),
                    child: PrismChip(
                      label: c.title,
                      selected: _collection == c.id,
                      selectedColor: Color(c.integer('color') ?? context.nutri.basil.toARGB32()),
                      onTap: () => setState(() => _collection = c.id),
                    ),
                  ),
                ),
              PrismChip(label: tr(context, '+ Collection', '+ Colección'), selected: false, variant: PrismChipVariant.inline, onTap: () => _editCollection(context, null)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: Text(tr(context, '${shown.length} saved foods', '${shown.length} comidas guardadas'), style: theme.textTheme.titleSmall)),
            PrismButton(label: tr(context, 'New food', 'Nueva comida'), icon: AppIcons.add, onPressed: () => showMealEditor(context, asFood: true)),
          ],
        ),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              tr(context, 'Open any logged meal and tap “Save as favourite”, or add foods here.', 'Abre una comida y toca «Guardar como favorita», o añade comidas aquí.'),
              textAlign: TextAlign.center,
            ),
          ),
        for (final f in shown)
          PrismListRow(
            leading: f.strings('media').isEmpty
                ? Icon(f.flag('favorite') ? PhosphorIcons.heart(PhosphorIconsStyle.fill) : PhosphorIcons.bowlFood(), color: context.nutri.basil)
                : ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: 40, height: 40, child: PrismMediaView(id: f.strings('media').first))),
            title: Text(f.title),
            subtitle: Text([
              if (f.strings('ingredients').isNotEmpty) f.strings('ingredients').take(4).join(', '),
              tr(context, 'logged ${f.integer('uses') ?? 0}×', 'registrada ${f.integer('uses') ?? 0}×'),
            ].join(' · ')),
            trailing: IconButton(tooltip: tr(context, 'Log now', 'Registrar ahora'), icon: Icon(AppIcons.addCircleOutline), onPressed: () => logFood(context, ref, f, null)),
            onTap: () => showMealEditor(context, food: f),
            onLongPress: collections.isEmpty ? null : () => _addToCollection(context, f, collections),
          ),
      ],
    );
  }

  Future<void> _addToCollection(BuildContext context, TrackerRecord food, List<TrackerRecord> collections) async {
    await PrismSheet.show(
      context: context,
      title: tr(context, 'Collections', 'Colecciones'),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => ListView(
          shrinkWrap: true,
          children: [
            for (final c in ref.read(collectionsProvider))
              PrismSwitchRow(
                title: c.title,
                value: c.strings('foods').contains(food.id),
                onChanged: (v) async {
                  final ids = {...c.strings('foods')};
                  v ? ids.add(food.id) : ids.remove(food.id);
                  await ref.read(trackerNotifierProvider.notifier).save(c.withFields({'foods': ids.toList()}));
                  set(() {});
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _editCollection(BuildContext context, TrackerRecord? c) async {
    final name = await promptText(context, c == null ? tr(context, 'New collection', 'Nueva colección') : tr(context, 'Rename collection', 'Renombrar colección'), initial: c?.title);
    if (name == null || name.isEmpty) return;
    final t = ref.read(trackerNotifierProvider.notifier);
    if (c == null) {
      await t.create(kind: TrackerKind.nutriCollection, title: name, fields: {'color': colorChoices[ref.read(collectionsProvider).length % colorChoices.length], 'foods': <String>[]});
    } else {
      await t.save(c.copyWith(title: name));
    }
  }
}

Future<void> showMealCategoryManager(BuildContext context) => PrismSheet.show(
  context: context,
  title: tr(context, 'Meal categories', 'Categorías de comida'),
  builder: (ctx) => Consumer(
    builder: (ctx, ref, _) {
      final cats = ref.watch(mealCategoriesProvider(_lang(ctx)));
      return ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          for (final c in cats)
            PrismListRow(
              leading: Icon(iconFor(c.icon), color: catColor(context, c)),
              title: Text(c.title),
              subtitle: Text(c.record == null ? tr(ctx, 'Built-in', 'Predeterminada') : tr(ctx, 'Custom', 'Personalizada')),
              trailing: c.record == null
                  ? null
                  : IconButton(
                      tooltip: tr(ctx, 'Delete', 'Eliminar'),
                      icon: Icon(AppIcons.deleteOutline),
                      onPressed: () => ref.read(trackerNotifierProvider.notifier).delete(c.record!.id),
                    ),
            ),
          PrismButton(
            label: tr(ctx, 'New category', 'Nueva categoría'),
            icon: AppIcons.add,
            tone: PrismButtonTone.filled,
            onPressed: () async {
              final name = await promptText(ctx, tr(ctx, 'Category name (e.g. Second breakfast)', 'Nombre (p. ej. Merienda)'));
              if (name == null || name.isEmpty) return;
              await ref.read(trackerNotifierProvider.notifier).create(
                kind: TrackerKind.nutriCategory,
                title: name,
                fields: {'icon': 'bowl', 'color': colorChoices[cats.length % colorChoices.length]},
              );
            },
          ),
        ],
      );
    },
  ),
);

class NutritionInsightsView extends ConsumerStatefulWidget {
  const NutritionInsightsView({super.key, required this.member, required this.onMember});
  final String? member;
  final ValueChanged<String?> onMember;
  @override
  ConsumerState<NutritionInsightsView> createState() => _NutritionInsightsViewState();
}

class _NutritionInsightsViewState extends ConsumerState<NutritionInsightsView> {
  int _days = 7;
  String _metric = 'kcal';

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(nutriSettingsProvider);
    final cats = ref.watch(mealCategoriesProvider(_lang(context)));
    final lang = _lang(context);
    final today = dayOf(DateTime.now());
    final from = DateTime(today.year, today.month, today.day - _days + 1);
    bool mine(TrackerRecord r) => widget.member == null || r.memberId == widget.member || r.strings('members').contains(widget.member);
    final meals = [for (final m in ref.watch(mealsProvider)) if (mine(m) && !(m.occurredAt ?? m.createdAt).isBefore(from)) m];
    final drinks = [for (final d in ref.watch(drinksProvider)) if (mine(d) && !(d.occurredAt ?? d.createdAt).isBefore(from)) d];
    final days = [for (var i = 0; i < _days; i++) DateTime(from.year, from.month, from.day + i)];
    final perDayMetric = {for (final d in days) d: 0.0};
    final catCounts = <String, int>{};
    final foodCounts = <String, int>{};
    final ingCounts = <String, int>{};
    final feelCounts = <String, int>{};
    final hourCounts = List.filled(24, 0);
    for (final m in meals) {
      final d = dayOf(m.occurredAt ?? m.createdAt);
      final v = mealNutrition(m)[_metric];
      if (v != null && perDayMetric.containsKey(d)) perDayMetric[d] = perDayMetric[d]! + v;
      catCounts[m.str('cat') ?? 'snack'] = (catCounts[m.str('cat') ?? 'snack'] ?? 0) + 1;
      if (!m.isPrivate) foodCounts[m.title] = (foodCounts[m.title] ?? 0) + 1;
      for (final i in m.strings('ingredients')) {
        ingCounts[i.toLowerCase()] = (ingCounts[i.toLowerCase()] ?? 0) + 1;
      }
      if (m.str('feel') != null) feelCounts[m.str('feel')!] = (feelCounts[m.str('feel')!] ?? 0) + 1;
      hourCounts[(m.occurredAt ?? m.createdAt).hour]++;
    }
    final hyd = hydrationByDay(drinks);
    final totalMl = drinks.fold(0, (a, d) => a + drinkMl(d));
    final theme = Theme.of(context);
    List<MapEntry<String, int>> top(Map<String, int> m, [int n = 6]) => (m.entries.toList()..sort((a, b) => b.value - a.value)).take(n).toList();
    final daysWithMeals = {for (final m in meals) dayOf(m.occurredAt ?? m.createdAt)}.length;
    final metricDef = nutriMetrics.firstWhere((m) => m.key == _metric);
    final hasMetric = perDayMetric.values.any((v) => v > 0);

    String report() {
      final b = StringBuffer()
        ..writeln('Prism nutrition summary — last $_days days')
        ..writeln('Meals logged: ${meals.length} (on $daysWithMeals days)')
        ..writeln('Average meals per logged day: ${daysWithMeals == 0 ? 0 : (meals.length / daysWithMeals).toStringAsFixed(1)}')
        ..writeln('Hydration: ${fmtVolume(totalMl, s.unit)} total, ${fmtVolume(_days == 0 ? 0 : totalMl ~/ _days, s.unit)} per day on average');
      for (final c in cats) {
        b.writeln('${c.title}: ${catCounts[c.id] ?? 0}');
      }
      if (foodCounts.isNotEmpty) b.writeln('Most logged: ${top(foodCounts).map((e) => '${e.key} (${e.value})').join(', ')}');
      if (hasMetric) b.writeln('${metricDef.en} per day: ${days.map((d) => perDayMetric[d]!.round()).join(', ')} ${metricDef.unit}');
      return b.toString();
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, NavBarInset.of(context) + 24),
      children: [
        TrackerMemberFilter(value: widget.member, onChanged: widget.onMember),
        Row(
          children: [
            for (final d in const [7, 30, 90, 365])
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: PrismChip(label: tr(context, '$d days', '$d días'), selected: _days == d, onTap: () => setState(() => _days = d)),
              ),
            const Spacer(),
            IconButton(
              tooltip: tr(context, 'Share report', 'Compartir informe'),
              icon: Icon(AppIcons.shareOutlined),
              onPressed: () => SharePlus.instance.share(ShareParams(text: report(), subject: 'Prism nutrition summary')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TrackerStatGrid(
          children: [
            TrackerStatTile(label: tr(context, 'Meals logged', 'Comidas registradas'), value: '${meals.length}', icon: PhosphorIcons.forkKnife()),
            TrackerStatTile(
              label: tr(context, 'Per logged day', 'Por día registrado'),
              value: daysWithMeals == 0 ? '–' : (meals.length / daysWithMeals).toStringAsFixed(1),
              icon: PhosphorIcons.calendarCheck(),
            ),
            TrackerStatTile(label: tr(context, 'Avg. hydration', 'Hidratación media'), value: fmtVolume(totalMl ~/ _days, s.unit), icon: PhosphorIcons.drop()),
            TrackerStatTile(label: tr(context, 'Drinks', 'Bebidas'), value: '${drinks.length}', icon: PhosphorIcons.coffee()),
          ],
        ),
        const SizedBox(height: 14),
        TrackerLabel(tr(context, 'Meals by category', 'Comidas por categoría')),
        SizedBox(
          height: 160,
          child: Row(
            children: [
              Expanded(
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 34,
                    sections: [
                      for (final c in cats)
                        if ((catCounts[c.id] ?? 0) > 0)
                          PieChartSectionData(value: catCounts[c.id]!.toDouble(), color: catColor(context, c), radius: 34, title: '${catCounts[c.id]}', titleStyle: theme.textTheme.labelSmall?.copyWith(color: Colors.white)),
                    ],
                  ),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final c in cats)
                    Row(children: [Icon(iconFor(c.icon), size: 14, color: catColor(context, c)), const SizedBox(width: 4), Text('${c.title} ${catCounts[c.id] ?? 0}', style: theme.textTheme.labelSmall)]),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        TrackerLabel(tr(context, 'When meals happen', 'A qué hora se come')),
        SizedBox(
          height: 110,
          child: BarChart(
            BarChartData(
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true, interval: 6, getTitlesWidget: (v, m) => Text('${v.toInt()}h', style: theme.textTheme.labelSmall)),
                ),
              ),
              barGroups: [
                for (var h = 0; h < 24; h++)
                  BarChartGroupData(x: h, barRods: [BarChartRodData(toY: hourCounts[h].toDouble(), color: context.nutri.saffron, width: 6, borderRadius: BorderRadius.circular(2))]),
              ],
            ),
          ),
        ),
        if (s.showNutrition) ...[
          const SizedBox(height: 14),
          TrackerLabel(tr(context, 'Nutrition over time', 'Nutrición en el tiempo')),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final m in nutriMetrics)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: PrismChip(label: lang == 'es' ? m.es : m.en, selected: _metric == m.key, onTap: () => setState(() => _metric = m.key)),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 160,
            child: !hasMetric
                ? Center(child: Text(tr(context, 'No values recorded for this metric yet.', 'Aún no hay valores para esta métrica.'), style: theme.textTheme.bodySmall))
                : LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: const FlTitlesData(topTitles: AxisTitles(), rightTitles: AxisTitles(), bottomTitles: AxisTitles()),
                      extraLinesData: ExtraLinesData(
                        horizontalLines: [
                          if (s.metricGoals[_metric] != null) HorizontalLine(y: s.metricGoals[_metric]!.toDouble(), color: context.nutri.basil, dashArray: [6, 4]),
                        ],
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [for (var i = 0; i < days.length; i++) FlSpot(i.toDouble(), perDayMetric[days[i]]!)],
                          isCurved: true,
                          color: context.nutri.tomato,
                          barWidth: 3,
                          dotData: FlDotData(show: _days <= 30),
                          belowBarData: BarAreaData(show: true, color: context.nutri.tomato.withValues(alpha: 0.12)),
                        ),
                      ],
                    ),
                  ),
          ),
          Text('${metricDef.unit} · ${tr(context, 'per day', 'por día')}', style: theme.textTheme.labelSmall),
        ],
        const SizedBox(height: 14),
        TrackerLabel(tr(context, 'Hydration trend', 'Tendencia de hidratación')),
        SizedBox(
          height: 120,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: const FlTitlesData(topTitles: AxisTitles(), rightTitles: AxisTitles(), bottomTitles: AxisTitles(), leftTitles: AxisTitles()),
              lineBarsData: [
                LineChartBarData(
                  spots: [for (var i = 0; i < days.length; i++) FlSpot(i.toDouble(), (hyd[days[i]] ?? 0).toDouble())],
                  isCurved: true,
                  color: context.nutri.water,
                  barWidth: 3,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: true, color: context.nutri.water.withValues(alpha: 0.15)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (foodCounts.isNotEmpty) ...[
          TrackerLabel(tr(context, 'Most logged foods', 'Comidas más registradas')),
          for (final e in top(foodCounts)) PrismListRow(dense: true, title: Text(e.key), trailing: Text('${e.value}×')),
        ],
        if (ingCounts.isNotEmpty) ...[
          TrackerLabel(tr(context, 'Common ingredients', 'Ingredientes frecuentes')),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final e in top(ingCounts, 12)) PrismChip(label: '${e.key} · ${e.value}', selected: false, variant: PrismChipVariant.inline, onTap: () {})]),
        ],
        if (feelCounts.isNotEmpty) ...[
          const SizedBox(height: 10),
          TrackerLabel(tr(context, 'How meals felt', 'Cómo se sintieron las comidas')),
          Wrap(
            spacing: 10,
            children: [
              for (final f in mealFeelings)
                if ((feelCounts[f.$1] ?? 0) > 0) Text('${f.$2} ${tr(context, f.$3, f.$4)} · ${feelCounts[f.$1]}'),
            ],
          ),
        ],
      ],
    );
  }
}
