import 'package:intl/intl.dart' show DateFormat;

import 'package:prism_plurality/domain/models/contact.dart';
import 'package:prism_plurality/features/astro/content/compat.dart';
import 'package:prism_plurality/features/astro/content/horoscope.dart';
import 'package:prism_plurality/features/astro/content/zodiac.dart';
import 'package:prism_plurality/features/astro/data/astro_model.dart';
import 'package:prism_plurality/features/astro/engine/chart.dart';
import 'package:prism_plurality/features/astro/engine/places.dart';
import 'package:prism_plurality/features/astro/views/astro_widgets.dart';
import 'package:prism_plurality/features/contacts/providers/contact_providers.dart';
import 'package:prism_plurality/features/contacts/utils/birthday_date.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Someone to compare with: another alter, a contact or anyone entered by
/// hand. Only birth data the viewer may see is used.
class CompatPartner {
  CompatPartner(this.name, this.subject, {this.kind = 'manual'});
  final String name;
  final AstroSubject subject;
  final String kind;
}

AstroSubject subjectFromBirth(String name, BirthData b) {
  final chart = b.hasYear ? NatalChart.of(b) : null;
  return AstroSubject(name: name, sunSign: chart?.sunSign ?? sunSignForDate(b.month, b.day).$1, chart: chart, seed: name.hashCode);
}

class CompatSection extends ConsumerStatefulWidget {
  const CompatSection({super.key, required this.access});
  final AstroAccess access;

  @override
  ConsumerState<CompatSection> createState() => _CompatSectionState();
}

class _CompatSectionState extends ConsumerState<CompatSection> {
  CompatPartner? _partner;

  @override
  Widget build(BuildContext context) {
    final es = astroEs(context);
    final theme = Theme.of(context);
    final a = widget.access;
    final accent = alterAccent(context, a);
    final p = _partner;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AstroHero(
          accent: accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr(context, 'COMPARE ME WITH…', 'COMPÁRAME CON…'), style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.1)),
              const SizedBox(height: 8),
              Row(
                children: [
                  AstroAvatar(a, size: 44),
                  const SizedBox(width: 10),
                  Text('+', style: theme.textTheme.titleLarge),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PrismButton(
                      icon: PhosphorIcons.userPlus(),
                      label: p == null ? tr(context, 'Choose someone', 'Elegir a alguien') : p.name,
                      onPressed: () async {
                        final picked = await _pickPartner(context, ref, a);
                        if (picked != null) setState(() => _partner = picked);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (p == null)
          AstroCard(
            child: Text(
              tr(context, 'Pick another alter, a contact with a birthday, or enter anyone by hand. More birth data on both sides unlocks a deeper comparison.',
                  'Elige otro alter, un contacto con cumpleaños o introduce a cualquiera a mano. Con más datos de nacimiento en ambos lados la comparación es más profunda.'),
              style: const TextStyle(height: 1.45),
            ),
          )
        else
          _CompatResult(reading: compareCharts(a.subject!, p.subject, es), a: a, partner: p),
        const AstroDisclaimer(),
      ],
    );
  }
}

class _CompatResult extends StatelessWidget {
  const _CompatResult({required this.reading, required this.a, required this.partner});
  final CompatReading reading;
  final AstroAccess a;
  final CompatPartner partner;

  @override
  Widget build(BuildContext context) {
    final es = astroEs(context);
    final theme = Theme.of(context);
    final accent = alterAccent(context, a);
    final r = reading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AstroCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${a.name} + ${partner.name}', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text(r.headline, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: accent)),
              const SizedBox(height: 6),
              Text(r.summary, style: const TextStyle(height: 1.45)),
            ],
          ),
        ),
        PrismSectionHeader(title: tr(context, 'BASICS', 'LO BÁSICO')),
        PrismSurface(
          padding: EdgeInsets.zero,
          child: Column(children: [for (final b in r.basics) PrismListRow(dense: true, title: Text(b.$1), subtitle: Text(b.$2))]),
        ),
        PrismSectionHeader(title: tr(context, 'HOW YOU CONNECT', 'CÓMO CONECTÁIS')),
        PrismSurface(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final e in r.areas.entries)
                PrismListRow(
                  leading: Text(e.key.emoji, style: const TextStyle(fontSize: 18)),
                  title: Row(
                    children: [
                      Expanded(child: Text(e.key.label.of(es))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                        child: Text('${e.value.$1.emoji} ${e.value.$1.label.of(es)}', style: theme.textTheme.labelSmall),
                      ),
                    ],
                  ),
                  subtitle: Text(e.value.$2),
                ),
            ],
          ),
        ),
        if (r.advanced && r.aspects.isNotEmpty) ...[
          PrismSectionHeader(title: tr(context, 'SYNASTRY ASPECTS', 'ASPECTOS DE SINASTRÍA')),
          PrismSurface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final s in r.aspects.take(12))
                  PrismListRow(
                    dense: true,
                    leading: SizedBox(width: 28, child: Center(child: AstroGlyph(aspectNames[s.type.index].glyph, size: 16, color: s.type.harmonious == false ? theme.colorScheme.tertiary : accent))),
                    title: Text('${a.name} ${pointName(s.a, es)} ${aspectNames[s.type.index].name.of(es).toLowerCase()} ${partner.name} ${pointName(s.b, es)}'),
                    subtitle: Text('${es ? 'orbe' : 'orb'} ${s.orb.toStringAsFixed(1)}° · ${aspectNames[s.type.index].meaning.of(es)}'),
                  ),
              ],
            ),
          ),
        ] else if (!r.advanced)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              tr(context, 'With a birth year (and ideally time and place) for both, Prism can compare Moon, Venus, Mars and Rising signs too.',
                  'Con el año de nacimiento de ambos (y mejor aún hora y lugar), Prism puede comparar también Luna, Venus, Marte y ascendente.'),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

Future<CompatPartner?> _pickPartner(BuildContext context, WidgetRef ref, AstroAccess me) {
  final alters = [
    for (final x in ref.read(astroAllProvider))
      if (x.member.id != me.member.id && x.listed && x.subject != null) x,
  ];
  final contacts = [
    for (final c in ref.read(contactsProvider).value ?? const <Contact>[])
      if (BirthdayDate.fromStorage(c.birthday) case final b?) (c, b),
  ];
  return PrismSheet.show<CompatPartner>(
    context: context,
    title: tr(context, 'Compare with', 'Comparar con'),
    maxHeightFactor: 0.9,
    builder: (ctx) {
      final es = astroEs(ctx);
      return ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          PrismSectionHeader(title: tr(ctx, 'ALTERS', 'ALTERS')),
          if (alters.isEmpty)
            Text(tr(ctx, 'No other alters share their astrology yet.', 'Ningún otro alter comparte su astrología todavía.'), style: Theme.of(ctx).textTheme.bodySmall)
          else
            PrismSurface(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final x in alters)
                    PrismListRow(
                      leading: AstroAvatar(x, size: 32),
                      title: Text(x.name),
                      subtitle: Text(signs[x.sunSign!].name.of(es)),
                      onTap: () => Navigator.of(ctx).pop(CompatPartner(x.name, x.subject!, kind: 'alter')),
                    ),
                ],
              ),
            ),
          if (contacts.isNotEmpty) ...[
            PrismSectionHeader(title: tr(ctx, 'CONTACTS', 'CONTACTOS')),
            PrismSurface(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final (c, b) in contacts)
                    PrismListRow(
                      leading: Icon(PhosphorIcons.addressBook()),
                      title: Text(c.displayName),
                      subtitle: Text(signs[sunSignForDate(b.month, b.day).$1].name.of(es)),
                      onTap: () => Navigator.of(ctx).pop(CompatPartner(c.displayName, subjectFromBirth(c.displayName, BirthData(month: b.month, day: b.day, year: b.year)), kind: 'contact')),
                    ),
                ],
              ),
            ),
          ],
          PrismSectionHeader(title: tr(ctx, 'SOMEONE ELSE', 'OTRA PERSONA')),
          _ManualPerson(onDone: (p) => Navigator.of(ctx).pop(p)),
        ],
      );
    },
  );
}

class _ManualPerson extends StatefulWidget {
  const _ManualPerson({required this.onDone});
  final ValueChanged<CompatPartner> onDone;

  @override
  State<_ManualPerson> createState() => _ManualPersonState();
}

class _ManualPersonState extends State<_ManualPerson> {
  final _name = TextEditingController();
  final _search = TextEditingController();
  DateTime? _date;
  bool _yearKnown = true;
  TimeOfDay? _time;
  BirthPlace? _place;
  List<City> _results = const [];
  CityIndex? _index;

  @override
  void initState() {
    super.initState();
    CityIndex.load().then((i) {
      if (mounted) setState(() => _index = i);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PrismSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrismTextField(controller: _name, labelText: tr(context, 'Name', 'Nombre'), onChanged: (_) => setState(() {})),
          const SizedBox(height: 10),
          Builder(
            builder: (anchor) => PrismButton(
              icon: PhosphorIcons.cake(),
              label: _date == null ? tr(context, 'Birthday', 'Cumpleaños') : (_yearKnown ? DateFormat.yMMMd(context.dateLocale) : DateFormat.MMMd(context.dateLocale)).format(_date!),
              onPressed: () async {
                final d = await showPrismDatePicker(context: context, anchorContext: anchor, initialDate: _date ?? DateTime(2000), firstDate: DateTime(1800), lastDate: DateTime.now());
                if (d != null) setState(() => _date = d);
              },
            ),
          ),
          PrismSwitchRow(padding: const EdgeInsets.symmetric(vertical: 6), title: tr(context, 'Birth year known', 'Se sabe el año'), value: _yearKnown, onChanged: (v) => setState(() => _yearKnown = v)),
          if (_yearKnown) ...[
            Builder(
              builder: (anchor) => PrismButton(
                icon: PhosphorIcons.clock(),
                label: _time == null ? tr(context, 'Birth time (optional)', 'Hora (opcional)') : _time!.format(context),
                onPressed: () async {
                  final t = await showPrismTimePicker(context: context, anchorContext: anchor, initialTime: _time ?? const TimeOfDay(hour: 12, minute: 0));
                  if (t != null) setState(() => _time = t);
                },
              ),
            ),
            const SizedBox(height: 10),
            if (_place != null)
              PrismListRow(dense: true, leading: Icon(PhosphorIcons.mapPin()), title: Text(_place!.name), trailing: PrismIconButton(icon: PhosphorIcons.x(), tooltip: tr(context, 'Remove', 'Quitar'), onPressed: () => setState(() => _place = null)))
            else ...[
              PrismTextField(controller: _search, hintText: tr(context, 'Birthplace (optional)', 'Lugar de nacimiento (opcional)'), prefixIcon: Icon(PhosphorIcons.magnifyingGlass()), onChanged: (q) => setState(() => _results = _index?.search(q, limit: 5) ?? const [])),
              for (final c in _results)
                PrismListRow(dense: true, title: Text(c.label), onTap: () => setState(() {
                  _place = c.toPlace();
                  _results = const [];
                })),
            ],
          ],
          const SizedBox(height: 12),
          PrismButton(
            label: tr(context, 'Compare', 'Comparar'),
            tone: PrismButtonTone.filled,
            enabled: _date != null && _name.text.trim().isNotEmpty,
            onPressed: () {
              final d = _date!;
              final b = BirthData(month: d.month, day: d.day, year: _yearKnown ? d.year : null, hour: _yearKnown ? _time?.hour : null, minute: _yearKnown ? _time?.minute : null, place: _yearKnown ? _place : null);
              widget.onDone(CompatPartner(_name.text.trim(), subjectFromBirth(_name.text.trim(), b)));
            },
          ),
          const SizedBox(height: 6),
          Text(tr(context, 'Not saved anywhere.', 'No se guarda en ningún sitio.'), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
