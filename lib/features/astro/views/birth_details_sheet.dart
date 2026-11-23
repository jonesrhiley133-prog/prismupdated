import 'package:intl/intl.dart' show DateFormat;

import 'package:prism_plurality/features/astro/data/astro_model.dart';
import 'package:prism_plurality/features/astro/engine/chart.dart';
import 'package:prism_plurality/features/astro/engine/ephemeris.dart';
import 'package:prism_plurality/features/astro/engine/places.dart';
import 'package:prism_plurality/features/astro/views/astro_widgets.dart';
import 'package:prism_plurality/features/members/utils/birthday.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

Future<void> showBirthDetails(BuildContext context, String memberId) => PrismSheet.show(
  context: context,
  title: tr(context, 'Birth details', 'Datos de nacimiento'),
  maxHeightFactor: 0.94,
  builder: (_) => _BirthDetails(memberId: memberId),
);

class _BirthDetails extends ConsumerStatefulWidget {
  const _BirthDetails({required this.memberId});
  final String memberId;

  @override
  ConsumerState<_BirthDetails> createState() => _BirthDetailsState();
}

class _BirthDetailsState extends ConsumerState<_BirthDetails> {
  late AstroProfile _p;
  DateTime? _date;
  bool _yearHidden = false;
  final _year = TextEditingController();
  final _search = TextEditingController();
  final _lat = TextEditingController();
  final _lon = TextEditingController();
  final _zone = TextEditingController();
  List<City> _results = const [];
  bool _manual = false;
  bool _saving = false;
  CityIndex? _index;

  @override
  void initState() {
    super.initState();
    final a = ref.read(astroAccessProvider(widget.memberId))!;
    _p = a.profile;
    final b = parseBirthday(a.member.birthday);
    _date = b;
    _yearHidden = b != null && isBirthdayYearHidden(b);
    if (_p.year != null) _year.text = '${_p.year}';
    final place = _p.place;
    if (place != null) {
      _lat.text = place.lat.toStringAsFixed(3);
      _lon.text = place.lon.toStringAsFixed(3);
      _zone.text = place.timeZone;
    }
    CityIndex.load().then((i) {
      if (mounted) setState(() => _index = i);
    });
  }

  @override
  void dispose() {
    _year.dispose();
    _search.dispose();
    _lat.dispose();
    _lon.dispose();
    _zone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final a = ref.read(astroAccessProvider(widget.memberId))!;
    final actions = ref.read(astroActionsProvider);
    var p = _p;
    if (_yearHidden) {
      final y = int.tryParse(_year.text.trim());
      p = y == null || y < 1800 || y > 2200 ? p.copyWith(clearYear: true) : p.copyWith(year: y);
    }
    if (_manual) {
      final lat = double.tryParse(_lat.text.trim().replaceAll(',', '.'));
      final lon = double.tryParse(_lon.text.trim().replaceAll(',', '.'));
      final zone = _zone.text.trim();
      if (lat != null && lon != null && lat.abs() <= 90 && lon.abs() <= 180 && allTimeZones().contains(zone)) {
        p = p.copyWith(place: BirthPlace(name: tr(context, 'Custom location', 'Ubicación personalizada'), lat: lat, lon: lon, timeZone: zone));
      }
    }
    final date = _date;
    final prev = parseBirthday(a.member.birthday);
    if (date != null && (prev == null || prev.month != date.month || prev.day != date.day || (!_yearHidden && prev.year != date.year))) {
      await actions.saveBirthday(a.member, date, hideYear: _yearHidden);
    }
    await actions.saveProfile(p);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = ref.watch(astroAccessProvider(widget.memberId));
    if (a == null) return const SizedBox.shrink();
    final dateLocale = context.dateLocale;
    final place = _p.place;
    Duration? offset;
    if (place != null && _date != null) {
      final y = _yearHidden ? int.tryParse(_year.text) : _date!.year;
      if (y != null) offset = utcOffsetAt(place.timeZone, y, _date!.month, _date!.day, _p.hour ?? 12, _p.minute ?? 0);
    }

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Text(
          tr(context, 'Only the birthday is needed. A birth time and birthplace unlock the Rising sign, houses and the full chart — nothing is guessed.',
              'Solo hace falta el cumpleaños. La hora y el lugar de nacimiento desbloquean el ascendente, las casas y la carta completa: no se adivina nada.'),
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        TrackerLabel(tr(context, 'Birthday', 'Cumpleaños')),
        Builder(
          builder: (anchor) => PrismButton(
            icon: PhosphorIcons.cake(),
            label: _date == null
                ? tr(context, 'Set birthday', 'Añadir cumpleaños')
                : _yearHidden
                ? DateFormat.MMMMd(dateLocale).format(_date!)
                : DateFormat.yMMMMd(dateLocale).format(_date!),
            onPressed: () async {
              final d = await showPrismDatePicker(context: context, anchorContext: anchor, initialDate: _date ?? DateTime(2000, 1, 1), firstDate: DateTime(1800), lastDate: DateTime.now());
              if (d != null) setState(() => _date = _yearHidden ? DateTime(birthdayNoYearSentinel, d.month, d.day) : d);
            },
          ),
        ),
        if (_yearHidden) ...[
          const SizedBox(height: 10),
          PrismTextField(
            controller: _year,
            keyboardType: TextInputType.number,
            labelText: tr(context, 'Birth year (kept private to Astro)', 'Año de nacimiento (solo para Astro)'),
            helperText: tr(context, 'This profile hides the year; it\'s used only for the chart.', 'Este perfil oculta el año; solo se usa para la carta.'),
            onChanged: (_) => setState(() {}),
          ),
        ],
        const SizedBox(height: 18),
        TrackerLabel(tr(context, 'Birth time', 'Hora de nacimiento')),
        Row(
          children: [
            Expanded(
              child: Builder(
                builder: (anchor) => PrismButton(
                  icon: PhosphorIcons.clock(),
                  label: _p.hour == null
                      ? tr(context, 'Unknown', 'Desconocida')
                      : context.formatTime(DateTime(2000, 1, 1, _p.hour!, _p.minute ?? 0)),
                  onPressed: () async {
                    final t = await showPrismTimePicker(context: context, anchorContext: anchor, initialTime: TimeOfDay(hour: _p.hour ?? 12, minute: _p.minute ?? 0));
                    if (t != null) setState(() => _p = _p.copyWith(hour: t.hour, minute: t.minute));
                  },
                ),
              ),
            ),
            if (_p.hour != null) ...[
              const SizedBox(width: 8),
              PrismButton(label: tr(context, 'Clear', 'Borrar'), onPressed: () => setState(() => _p = _p.copyWith(clearTime: true))),
            ],
          ],
        ),
        const SizedBox(height: 18),
        TrackerLabel(tr(context, 'Birthplace', 'Lugar de nacimiento')),
        if (place != null)
          PrismSurface(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(PhosphorIcons.mapPin(PhosphorIconsStyle.fill), color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(place.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        '${place.lat.toStringAsFixed(2)}°, ${place.lon.toStringAsFixed(2)}° · ${place.timeZone}${offset == null ? '' : ' · ${formatOffset(offset)}'}',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                PrismIconButton(icon: PhosphorIcons.x(), tooltip: tr(context, 'Remove', 'Quitar'), onPressed: () => setState(() => _p = _p.copyWith(clearPlace: true))),
              ],
            ),
          ),
        if (place == null) ...[
          PrismTextField(
            controller: _search,
            prefixIcon: Icon(PhosphorIcons.magnifyingGlass()),
            hintText: tr(context, 'Search a town or city', 'Busca un pueblo o ciudad'),
            onChanged: (q) => setState(() => _results = _index?.search(q, limit: 8) ?? const []),
          ),
          if (_index == null)
            Padding(padding: const EdgeInsets.all(12), child: Text(tr(context, 'Loading places…', 'Cargando lugares…'), style: theme.textTheme.bodySmall)),
          if (_results.isNotEmpty)
            PrismSurface(
              margin: const EdgeInsets.only(top: 8),
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final c in _results)
                    PrismListRow(
                      dense: true,
                      leading: Icon(PhosphorIcons.mapPin()),
                      title: Text(c.name),
                      subtitle: Text([if (c.region.isNotEmpty && c.region != c.name) c.region, c.country].join(', ')),
                      onTap: () => setState(() {
                        _p = _p.copyWith(place: c.toPlace());
                        _results = const [];
                        _search.clear();
                      }),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Text(
            tr(context, 'Places are searched on this device (GeoNames list of towns with 15,000+ people). Nothing is sent online.',
                'Los lugares se buscan en este dispositivo (lista de GeoNames con localidades de más de 15.000 habitantes). No se envía nada a internet.'),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          PrismSwitchRow(
            padding: const EdgeInsets.symmetric(vertical: 8),
            title: tr(context, 'Enter coordinates instead', 'Introducir coordenadas'),
            subtitle: tr(context, 'For smaller places not in the list.', 'Para lugares pequeños que no están en la lista.'),
            value: _manual,
            onChanged: (v) => setState(() => _manual = v),
          ),
          if (_manual) ...[
            Row(
              children: [
                Expanded(child: PrismTextField(controller: _lat, labelText: tr(context, 'Latitude (N +)', 'Latitud (N +)'), keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true))),
                const SizedBox(width: 10),
                Expanded(child: PrismTextField(controller: _lon, labelText: tr(context, 'Longitude (E +)', 'Longitud (E +)'), keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true))),
              ],
            ),
            const SizedBox(height: 10),
            PrismTextField(controller: _zone, labelText: tr(context, 'Time zone (e.g. Europe/Madrid)', 'Zona horaria (p. ej. Europe/Madrid)'), onChanged: (_) => setState(() {})),
            if (_zone.text.trim().length >= 2 && !allTimeZones().contains(_zone.text.trim()))
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final z in allTimeZones().where((z) => z.toLowerCase().contains(_zone.text.trim().toLowerCase())).take(6))
                    PrismChip(label: z, selected: false, onTap: () => setState(() => _zone.text = z)),
                ],
              ),
          ],
        ],
        const SizedBox(height: 18),
        TrackerLabel(tr(context, 'House system', 'Sistema de casas')),
        PrismSegmentedControl<HouseSystem>(
          segments: [
            const PrismSegment(value: HouseSystem.placidus, label: 'Placidus'),
            PrismSegment(value: HouseSystem.wholeSign, label: tr(context, 'Whole sign', 'Signo completo')),
            PrismSegment(value: HouseSystem.equal, label: tr(context, 'Equal', 'Iguales')),
          ],
          selected: _p.houseSystem,
          onChanged: (h) => setState(() => _p = _p.copyWith(houseSystem: h)),
        ),
        const SizedBox(height: 18),
        TrackerLabel(tr(context, 'Who can see this alter\'s astrology', 'Quién puede ver la astrología de este alter')),
        PrismSurface(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final v in AstroVisibility.values)
                PrismListRow(
                  leading: Text(v.emoji, style: const TextStyle(fontSize: 18)),
                  title: Text(trp(context, v.label)),
                  subtitle: Text(trp(context, v.description)),
                  selected: _p.visibility == v,
                  trailing: _p.visibility == v ? Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill), color: theme.colorScheme.primary) : null,
                  onTap: () => setState(() => _p = _p.copyWith(visibility: v)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        PrismButton(
          label: tr(context, 'Save', 'Guardar'),
          icon: PhosphorIcons.check(),
          tone: PrismButtonTone.filled,
          expanded: true,
          isLoading: _saving,
          enabled: _date != null && !_saving,
          onPressed: _save,
        ),
      ],
    );
  }
}
