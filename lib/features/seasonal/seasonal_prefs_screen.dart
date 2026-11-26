import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/features/contacts/utils/birthday_date.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/seasonal/decor_models.dart';
import 'package:prism_plurality/features/seasonal/seasonal_calendar.dart';
import 'package:prism_plurality/features/seasonal/seasonal_catalog.dart';
import 'package:prism_plurality/features/seasonal/seasonal_models.dart';
import 'package:prism_plurality/features/seasonal/seasonal_providers.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import 'package:prism_plurality/shared/widgets/prism_date_picker.dart';

String _fmt(BuildContext context, DateTime d) =>
    MaterialLocalizations.of(context).formatMediumDate(d);

/// Which parts of Prism Seasonal Living may decorate.
const seasonalIntegrations = <(String key, String en, String es)>[
  (
    'overlay',
    'Decorations over the whole app',
    'Decoraciones sobre toda la app',
  ),
  (
    'home',
    'Home: garlands, corners and greetings',
    'Inicio: guirnaldas, esquinas y saludos',
  ),
  (
    'profiles',
    'Alter profiles: picture frames and banners',
    'Perfiles: marcos y banners',
  ),
  (
    'scrapbook',
    'Scrapbooks: covers, textures, stickers, frames',
    'Álbumes: portadas, texturas, pegatinas, marcos',
  ),
  (
    'ids',
    'ID cards: seasonal templates and borders',
    'Tarjetas: plantillas y bordes de temporada',
  ),
  (
    'calendar',
    'Calendar: holidays, countdowns, celebrations',
    'Calendario: fiestas, cuentas atrás, celebraciones',
  ),
  (
    'companions',
    'Companions: outfits, toys and reactions',
    'Compañeros: atuendos, juguetes y reacciones',
  ),
  ('widgets', 'Widgets: borders and accents', 'Widgets: bordes y acentos'),
  (
    'boards',
    'Bulletin Board: post decorations and reactions',
    'Tablón: decoraciones y reacciones',
  ),
  (
    'games',
    'Games: seasonal trivia and puzzles',
    'Juegos: trivia y puzles de temporada',
  ),
  (
    'achievements',
    'Achievements: commemorative badges',
    'Logros: insignias conmemorativas',
  ),
];

class SeasonalPrefsScreen extends ConsumerWidget {
  const SeasonalPrefsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final p = ref.watch(seasonalPrefsProvider);
    final n = ref.read(seasonalPrefsProvider.notifier);
    final l = Localizations.localeOf(context).languageCode == 'es';
    final now = DateTime.now();
    final celebratedCols = [
      for (final c in seasonalCollections)
        if (p.celebrated.contains(c.id) && !p.hidden.contains(c.id)) c,
    ];

    // The next time each celebrated holiday comes round.
    final upcoming = <(SeasonalCollection, DayRange)>[];
    for (final c in celebratedCols) {
      final custom = p.customDates[c.id];
      DayRange? r;
      if (custom != null) {
        final parts = custom.split('/');
        final a = DateTime.tryParse(parts.first),
            b = parts.length > 1 ? DateTime.tryParse(parts[1]) : null;
        if (a != null && b != null) r = DayRange(a, b);
      }
      r ??=
          [
                for (final y in [now.year, now.year + 1])
                  SeasonalWindows.windowFor(
                    c.id,
                    y,
                    region: p.region,
                    hemisphere: p.hemisphere,
                  ),
              ]
              .whereType<DayRange>()
              .where(
                (x) => !x
                    .shifted(after: p.extendDays[c.id] ?? 0)
                    .end
                    .isBefore(DateTime(now.year, now.month, now.day)),
              )
              .firstOrNull;
      if (r != null)
        upcoming.add((c, r.shifted(after: p.extendDays[c.id] ?? 0)));
    }
    upcoming.sort((a, b) => a.$2.start.compareTo(b.$2.start));

    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: tr(
          context,
          'Preferences & schedule',
          'Preferencias y programación',
        ),
        showBackButton: true,
      ),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 40 + NavBarInset.of(context)),
          children: [
            PrismSectionHeader(
              title: tr(context, 'WHERE YOU ARE', 'DÓNDE ESTÁS'),
            ),
            PrismSelect<SeasonalRegion>(
              labelText: tr(context, 'Region', 'Región'),
              value: p.region,
              items: [
                for (final r in SeasonalRegion.values)
                  PrismSelectItem(value: r, label: l ? r.es : r.en),
              ],
              onChanged: (v) {
                if (v != null) n.update((x) => x.copyWith(region: v));
              },
            ),
            const SizedBox(height: 10),
            PrismSelect<Hemisphere>(
              labelText: tr(
                context,
                'Seasons follow',
                'Las estaciones siguen al',
              ),
              value: p.hemisphere,
              items: [
                PrismSelectItem(
                  value: Hemisphere.auto,
                  label: tr(context, 'My region', 'Mi región'),
                ),
                PrismSelectItem(
                  value: Hemisphere.north,
                  label: tr(context, 'Northern hemisphere', 'Hemisferio norte'),
                ),
                PrismSelectItem(
                  value: Hemisphere.south,
                  label: tr(context, 'Southern hemisphere', 'Hemisferio sur'),
                ),
              ],
              onChanged: (v) {
                if (v != null) n.update((x) => x.copyWith(hemisphere: v));
              },
            ),
            PrismSectionHeader(
              title: tr(context, 'SCHEDULING', 'PROGRAMACIÓN'),
            ),
            PrismSurface(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: PrismSwitchRow(
                title: tr(
                  context,
                  'Change decorations automatically',
                  'Cambiar decoraciones automáticamente',
                ),
                subtitle: tr(
                  context,
                  'Off unless you turn it on. Only holidays you celebrate appear, only when they are in season, and your own arrangement comes back when they end. Your theme is never touched.',
                  'Apagado salvo que lo actives. Solo aparecen las fiestas que celebras, en su temporada, y tu arreglo vuelve al terminar. Tu tema nunca se toca.',
                ),
                value: p.autoSchedule,
                onChanged: (v) => n.update(
                  (x) => x.copyWith(
                    autoSchedule: v,
                    performance: v && x.performance == DecoPerformance.off
                        ? DecoPerformance.balanced
                        : x.performance,
                  ),
                ),
              ),
            ),
            PrismSurface(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: PrismSwitchRow(
                title: tr(
                  context,
                  'Seasonal greetings',
                  'Saludos de temporada',
                ),
                subtitle: tr(
                  context,
                  'Gentle greetings on Home, the launch screen and the calendar, in your chosen voice. Never assumes you celebrate anything.',
                  'Saludos suaves en Inicio, al abrir y en el calendario, con tu voz elegida.',
                ),
                value: p.greetingsOn,
                onChanged: (v) => n.update((x) => x.copyWith(greetingsOn: v)),
              ),
            ),
            PrismSectionHeader(
              title: tr(context, 'WHAT YOU CELEBRATE', 'QUÉ CELEBRAS'),
            ),
            Text(
              tr(
                context,
                'Tap the heart for what you celebrate, the eye to hide what you never want to see.',
                'Toca el corazón para lo que celebras y el ojo para ocultar lo que no quieres ver.',
              ),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            for (final c in seasonalCollections)
              PrismListRow(
                dense: true,
                leading: Text(c.emoji, style: const TextStyle(fontSize: 22)),
                title: Text(c.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: tr(
                        context,
                        'I celebrate ${c.name}',
                        'Celebro ${c.name}',
                      ),
                      isSelected: p.celebrated.contains(c.id),
                      icon: Icon(
                        p.celebrated.contains(c.id)
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: p.celebrated.contains(c.id)
                            ? theme.colorScheme.primary
                            : null,
                      ),
                      onPressed: () => n.update(
                        (x) => x.copyWith(
                          celebrated: x.celebrated.contains(c.id)
                              ? ({...x.celebrated}..remove(c.id))
                              : {...x.celebrated, c.id},
                          hidden: {...x.hidden}..remove(c.id),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: tr(
                        context,
                        'Hide ${c.name}',
                        'Ocultar ${c.name}',
                      ),
                      icon: Icon(
                        p.hidden.contains(c.id)
                            ? Icons.visibility_off
                            : Icons.visibility_outlined,
                        color: p.hidden.contains(c.id)
                            ? theme.colorScheme.error
                            : null,
                      ),
                      onPressed: () => n.update(
                        (x) => x.copyWith(
                          hidden: x.hidden.contains(c.id)
                              ? ({...x.hidden}..remove(c.id))
                              : {...x.hidden, c.id},
                          celebrated: {...x.celebrated}..remove(c.id),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (celebratedCols.isNotEmpty) ...[
              PrismSectionHeader(
                title: tr(context, 'YOUR SCHEDULE', 'TU CALENDARIO'),
              ),
              for (final c in celebratedCols)
                _ScheduleTile(
                  collection: c,
                  prefs: p,
                  next: upcoming.where((u) => u.$1.id == c.id).firstOrNull?.$2,
                ),
            ],
            if (upcoming.isNotEmpty) ...[
              PrismSectionHeader(
                title: tr(context, 'COMING UP', 'PRÓXIMAMENTE'),
              ),
              for (final u in upcoming.take(6))
                PrismListRow(
                  dense: true,
                  leading: Text(
                    u.$1.emoji,
                    style: const TextStyle(fontSize: 20),
                  ),
                  title: Text(u.$1.name),
                  subtitle: Text(
                    '${_fmt(context, u.$2.start)} – ${_fmt(context, u.$2.end)}${u.$1.approximateDates ? ' ~' : ''}',
                  ),
                ),
            ],
            PrismSectionHeader(
              title: tr(context, 'KEEP ONE ALL YEAR', 'UNO TODO EL AÑO'),
            ),
            PrismSelect<String>(
              labelText: tr(
                context,
                'A look I keep on permanently',
                'Un estilo permanente',
              ),
              value: p.permanentVariation == null
                  ? ''
                  : variationById(p.permanentVariation!)?.collectionId ?? '',
              items: [
                PrismSelectItem(
                  value: '',
                  label: tr(context, 'None', 'Ninguno'),
                ),
                for (final c in seasonalCollections)
                  PrismSelectItem(value: c.id, label: '${c.emoji} ${c.name}'),
              ],
              onChanged: (v) => n.update(
                (x) => x.copyWith(
                  permanentVariation: v == null || v.isEmpty
                      ? null
                      : (x.variationFor[v] ?? '$v.0'),
                ),
              ),
            ),
            PrismSectionHeader(
              title: tr(context, 'YOUR OWN CELEBRATIONS', 'TUS CELEBRACIONES'),
            ),
            Text(
              tr(
                context,
                'System anniversaries, alter birthdays, graduations, traditions — anything. They get the whole Decoration Studio, a schedule and their own greeting.',
                'Aniversarios del sistema, cumpleaños, graduaciones, tradiciones… Todo con el Estudio de decoración, calendario y saludo propios.',
              ),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            for (final c in p.celebrations)
              PrismListRow(
                leading: Text(c.emoji, style: const TextStyle(fontSize: 22)),
                title: Text(c.name),
                subtitle: Text(
                  '${c.month}/${c.day}${c.yearly ? '' : ' ${c.year ?? ''}'} · ${tr(context, c.kind, c.kind)}',
                ),
                trailing: IconButton(
                  tooltip: tr(context, 'Delete', 'Eliminar'),
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => n.update(
                    (x) => x.copyWith(
                      celebrations: x.celebrations
                          .where((e) => e.id != c.id)
                          .toList(),
                    ),
                  ),
                ),
                onTap: () => _editCelebration(context, ref, c),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PrismButton(
                  label: tr(context, 'New celebration', 'Nueva celebración'),
                  icon: Icons.add,
                  tone: PrismButtonTone.outlined,
                  onPressed: () => _editCelebration(context, ref, null),
                ),
                PrismButton(
                  label: tr(
                    context,
                    'System anniversary',
                    'Aniversario del sistema',
                  ),
                  icon: Icons.cake_outlined,
                  tone: PrismButtonTone.outlined,
                  onPressed: () => _editCelebration(
                    context,
                    ref,
                    null,
                    kind: 'anniversary',
                    name: tr(
                      context,
                      'System anniversary',
                      'Aniversario del sistema',
                    ),
                    emoji: '🎂',
                  ),
                ),
                PrismButton(
                  label: tr(
                    context,
                    'Add alter birthdays',
                    'Añadir cumpleaños',
                  ),
                  icon: Icons.card_giftcard_outlined,
                  tone: PrismButtonTone.outlined,
                  onPressed: () => _alterBirthdays(context, ref),
                ),
              ],
            ),
            PrismSectionHeader(
              title: tr(context, 'WHERE IT SHOWS UP', 'DÓNDE APARECE'),
            ),
            for (final i in seasonalIntegrations)
              PrismSurface(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: PrismSwitchRow(
                  title: l ? i.$3 : i.$2,
                  value: p.integrationOn(i.$1),
                  onChanged: (v) => n.update(
                    (x) =>
                        x.copyWith(integrations: {...x.integrations, i.$1: v}),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _alterBirthdays(BuildContext context, WidgetRef ref) async {
    final members = ref.read(allMembersProvider).value ?? const [];
    final n = ref.read(seasonalPrefsProvider.notifier);
    var added = 0;
    n.update((p) {
      final list = [...p.celebrations];
      for (final m in members) {
        final b = BirthdayDate.fromStorage(m.birthday);
        if (b == null ||
            list.any((c) => c.memberId == m.id && c.kind == 'birthday'))
          continue;
        list.add(
          CustomCelebration(
            id: 'bd-${m.id}',
            name: '${m.name}\'s birthday',
            emoji: '🎂',
            month: b.month,
            day: b.day,
            kind: 'birthday',
            memberId: m.id,
            variationId: 'valentine.8',
          ),
        );
        added++;
      }
      return p.copyWith(celebrations: list);
    });
    if (context.mounted) {
      PrismToast.show(
        context,
        message: added == 0
            ? tr(
                context,
                'No new birthdays to add.',
                'No hay cumpleaños nuevos.',
              )
            : tr(
                context,
                'Added $added birthday celebrations.',
                'Se añadieron $added cumpleaños.',
              ),
      );
    }
  }

  Future<void> _editCelebration(
    BuildContext context,
    WidgetRef ref,
    CustomCelebration? existing, {
    String kind = 'custom',
    String name = '',
    String emoji = '🎉',
  }) async {
    final n = ref.read(seasonalPrefsProvider.notifier);
    final presets = ref.read(decorPresetsProvider);
    final nameC = TextEditingController(text: existing?.name ?? name);
    final emojiC = TextEditingController(text: existing?.emoji ?? emoji);
    final greetC = TextEditingController(text: existing?.greeting ?? '');
    var month = existing?.month ?? DateTime.now().month,
        day = existing?.day ?? DateTime.now().day;
    var yearly = existing?.yearly ?? true;
    int? year = existing?.year;
    var lead = existing?.leadDays ?? 3, extend = existing?.extendDays ?? 1;
    var k = existing?.kind ?? kind;
    String? collection = existing?.variationId == null
        ? null
        : variationById(existing!.variationId!)?.collectionId;
    String? look = existing?.variationId;
    String? presetId = existing?.presetId;

    final ok = await PrismSheet.showFullScreen<bool>(
      context: context,
      builder: (ctx, scroll) => StatefulBuilder(
        builder: (ctx, set) {
          final col = collection == null ? null : collectionById(collection!);
          return ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: PrismTextField(
                      controller: emojiC,
                      labelText: tr(ctx, 'Emoji', 'Emoji'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PrismTextField(
                      controller: nameC,
                      labelText: tr(ctx, 'Name', 'Nombre'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final o in const [
                    ('custom', 'Custom'),
                    ('anniversary', 'Anniversary'),
                    ('birthday', 'Birthday'),
                    ('milestone', 'Milestone'),
                    ('fictional', 'Fictional holiday'),
                    ('tradition', 'Tradition'),
                  ])
                    PrismChip(
                      label: o.$2,
                      selected: k == o.$1,
                      onTap: () => set(() => k = o.$1),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: PrismSelect<int>(
                      labelText: tr(ctx, 'Month', 'Mes'),
                      value: month,
                      items: [
                        for (var i = 1; i <= 12; i++)
                          PrismSelectItem(
                            value: i,
                            label: MaterialLocalizations.of(ctx)
                                .formatMonthYear(DateTime(2026, i))
                                .split(' ')
                                .first,
                          ),
                      ],
                      onChanged: (v) => set(() => month = v ?? month),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PrismSelect<int>(
                      labelText: tr(ctx, 'Day', 'Día'),
                      value: day.clamp(1, 31),
                      items: [
                        for (var i = 1; i <= 31; i++)
                          PrismSelectItem(value: i, label: '$i'),
                      ],
                      onChanged: (v) => set(() => day = v ?? day),
                    ),
                  ),
                ],
              ),
              PrismSwitchRow(
                title: tr(ctx, 'Every year', 'Cada año'),
                subtitle: tr(
                  ctx,
                  'Turn off for a one-time event like a graduation.',
                  'Apágalo para un evento único.',
                ),
                value: yearly,
                onChanged: (v) => set(() {
                  yearly = v;
                  year = v ? null : (year ?? DateTime.now().year);
                }),
              ),
              if (!yearly)
                PrismSelect<int>(
                  labelText: tr(ctx, 'Year', 'Año'),
                  value: year ?? DateTime.now().year,
                  items: [
                    for (
                      var y = DateTime.now().year - 1;
                      y <= DateTime.now().year + 10;
                      y++
                    )
                      PrismSelectItem(value: y, label: '$y'),
                  ],
                  onChanged: (v) => set(() => year = v),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: PrismSelect<int>(
                      labelText: tr(
                        ctx,
                        'Starts days before',
                        'Empieza días antes',
                      ),
                      value: lead,
                      items: [
                        for (final d in const [0, 1, 2, 3, 5, 7, 14, 30])
                          PrismSelectItem(value: d, label: '$d'),
                      ],
                      onChanged: (v) => set(() => lead = v ?? lead),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PrismSelect<int>(
                      labelText: tr(
                        ctx,
                        'Lasts days after',
                        'Dura días después',
                      ),
                      value: extend,
                      items: [
                        for (final d in const [0, 1, 2, 3, 7, 14])
                          PrismSelectItem(value: d, label: '$d'),
                      ],
                      onChanged: (v) => set(() => extend = v ?? extend),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              PrismSelect<String>(
                labelText: tr(
                  ctx,
                  'Look from a collection',
                  'Estilo de una colección',
                ),
                value: collection ?? '',
                items: [
                  PrismSelectItem(value: '', label: tr(ctx, 'None', 'Ninguno')),
                  for (final c in seasonalCollections)
                    PrismSelectItem(value: c.id, label: '${c.emoji} ${c.name}'),
                ],
                onChanged: (v) => set(() {
                  collection = (v == null || v.isEmpty) ? null : v;
                  look = collection == null ? null : '$collection.0';
                }),
              ),
              if (col != null) ...[
                const SizedBox(height: 8),
                PrismSelect<String>(
                  labelText: tr(ctx, 'Look', 'Estilo'),
                  value: look ?? col.variations.first.id,
                  items: [
                    for (final v in col.variations)
                      PrismSelectItem(value: v.id, label: v.name),
                  ],
                  onChanged: (v) => set(() => look = v),
                ),
              ],
              if (presets.isNotEmpty) ...[
                const SizedBox(height: 8),
                PrismSelect<String>(
                  labelText: tr(
                    ctx,
                    'Or one of my arrangements',
                    'O uno de mis arreglos',
                  ),
                  value: presetId ?? '',
                  items: [
                    PrismSelectItem(
                      value: '',
                      label: tr(ctx, 'None', 'Ninguno'),
                    ),
                    for (final pr in presets)
                      PrismSelectItem(value: pr.id, label: pr.name),
                  ],
                  onChanged: (v) =>
                      set(() => presetId = (v == null || v.isEmpty) ? null : v),
                ),
              ],
              const SizedBox(height: 12),
              PrismTextField(
                controller: greetC,
                labelText: tr(ctx, 'Greeting (optional)', 'Saludo (opcional)'),
                hintText: tr(
                  ctx,
                  'Happy anniversary to us',
                  'Feliz aniversario a nosotros',
                ),
              ),
              const SizedBox(height: 16),
              PrismButton(
                label: tr(ctx, 'Save', 'Guardar'),
                tone: PrismButtonTone.filled,
                expanded: true,
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
            ],
          );
        },
      ),
    );
    final out = CustomCelebration(
      id:
          existing?.id ??
          'c${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
      name: nameC.text.trim().isEmpty
          ? tr(context, 'Celebration', 'Celebración')
          : nameC.text.trim(),
      emoji: emojiC.text.trim().isEmpty ? '🎉' : emojiC.text.trim(),
      month: month,
      day: day,
      year: yearly ? null : year,
      yearly: yearly,
      leadDays: lead,
      extendDays: extend,
      variationId: look,
      presetId: presetId,
      greeting: greetC.text.trim(),
      memberId: existing?.memberId,
      kind: k,
    );
    nameC.dispose();
    emojiC.dispose();
    greetC.dispose();
    if (ok != true) return;
    n.update(
      (p) => p.copyWith(
        celebrations: [
          for (final c in p.celebrations)
            if (c.id != out.id) c,
          out,
        ],
      ),
    );
  }
}

/// One celebrated collection: its next dates, how long to keep it, and
/// custom start and end dates.
class _ScheduleTile extends ConsumerWidget {
  const _ScheduleTile({
    required this.collection,
    required this.prefs,
    required this.next,
  });
  final SeasonalCollection collection;
  final SeasonalPrefs prefs;
  final DayRange? next;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = collection;
    final theme = Theme.of(context);
    final n = ref.read(seasonalPrefsProvider.notifier);
    final ext = prefs.extendDays[c.id] ?? 0;
    final custom = prefs.customDates[c.id];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PrismSurface(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${c.emoji} ${c.name}', style: theme.textTheme.titleSmall),
            Text(
              next == null
                  ? tr(
                      context,
                      'No automatic date — set your own below.',
                      'Sin fecha automática: pon la tuya.',
                    )
                  : '${_fmt(context, next!.start)} – ${_fmt(context, next!.end)}${custom != null ? '  ✎' : ''}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  tr(context, 'Keep going after:', 'Seguir después:'),
                  style: theme.textTheme.labelMedium,
                ),
                for (final d in const [0, 3, 7, 14, 30])
                  PrismChip(
                    label: d == 0
                        ? tr(context, 'Ends on time', 'Termina a tiempo')
                        : '+$d ${tr(context, 'days', 'días')}',
                    selected: ext == d,
                    onTap: () => n.update(
                      (x) => x.copyWith(extendDays: {...x.extendDays, c.id: d}),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Builder(
                  builder: (bc) => PrismButton(
                    label: custom == null
                        ? tr(context, 'Set my own dates', 'Poner mis fechas')
                        : tr(context, 'Change my dates', 'Cambiar mis fechas'),
                    icon: Icons.edit_calendar_outlined,
                    density: PrismControlDensity.compact,
                    tone: PrismButtonTone.outlined,
                    onPressed: () async {
                      final start = await showPrismDatePicker(
                        context: context,
                        anchorContext: bc,
                        initialDate: next?.start ?? DateTime.now(),
                        firstDate: DateTime(DateTime.now().year - 1),
                        lastDate: DateTime(DateTime.now().year + 3),
                      );
                      if (start == null || !context.mounted) return;
                      final end = await showPrismDatePicker(
                        context: context,
                        anchorContext: bc,
                        initialDate: start.add(const Duration(days: 7)),
                        firstDate: start,
                        lastDate: DateTime(DateTime.now().year + 3),
                      );
                      if (end == null) return;
                      String d(DateTime x) =>
                          '${x.year.toString().padLeft(4, '0')}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
                      n.update(
                        (x) => x.copyWith(
                          customDates: {
                            ...x.customDates,
                            c.id: '${d(start)}/${d(end)}',
                          },
                        ),
                      );
                    },
                  ),
                ),
                if (custom != null)
                  PrismButton(
                    label: tr(
                      context,
                      'Use the calendar',
                      'Usar el calendario',
                    ),
                    density: PrismControlDensity.compact,
                    tone: PrismButtonTone.outlined,
                    onPressed: () => n.update(
                      (x) => x.copyWith(
                        customDates: {...x.customDates}..remove(c.id),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
