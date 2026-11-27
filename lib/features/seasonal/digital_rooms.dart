import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/features/appearance/appearance_library.dart';
import 'package:prism_plurality/features/companions/companion_data.dart';
import 'package:prism_plurality/features/games/engines/ambience_synth.dart';
import 'package:prism_plurality/features/seasonal/decor_models.dart';
import 'package:prism_plurality/features/seasonal/decor_preview.dart';
import 'package:prism_plurality/features/seasonal/living_environment.dart';
import 'package:prism_plurality/features/seasonal/seasonal_catalog.dart';
import 'package:prism_plurality/features/seasonal/seasonal_providers.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Category Digital Rooms are filed under.
const roomCategory = 'Digital rooms';

/// Saves what's showing now (arrangement, living look, layout, environment
/// and ambience) as a new Digital Room and returns its id.
Future<String> createRoomFromCurrent(WidgetRef ref, String name) async {
  final prefs = ref.read(seasonalPrefsProvider);
  final current = ref.read(frontPresetProvider);
  final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final room = DecorPreset(
    id: '',
    name: name,
    category: roomCategory,
    items: [
      for (final i in current?.items ?? const <DecorItem>[])
        i.copy(newId: '${i.id}-$stamp')
          ..x = i.x
          ..y = i.y,
    ],
    layers: current?.layers ?? prefs.layers,
    room: RoomSettings(
      living: prefs.livingVariation,
      layout: prefs.layoutVariation,
      layoutParts: prefs.layoutParts,
      env: prefs.env.any ? prefs.env : null,
      audioId: prefs.audioOn ? prefs.audioId : null,
    ),
  );
  return ref.read(decorPresetActionsProvider).create(room);
}

/// Opens [roomId] now (shows it everywhere), keeping an undo.
void enterRoom(WidgetRef ref, String? roomId, {String? undoMessage}) {
  final prev = ref.read(seasonalPrefsProvider).activePresetId;
  if (undoMessage != null && prev != roomId) {
    ref
        .read(appearanceUndoProvider.notifier)
        .record(undoMessage, () => enterRoom(ref, prev));
  }
  ref
      .read(seasonalPrefsProvider.notifier)
      .update(
        (p) => p.copyWith(
          activePresetId: roomId,
          performance: roomId != null && p.performance == DecoPerformance.off
              ? DecoPerformance.balanced
              : p.performance,
        ),
      );
}

/// Edits a room's name, description and everything it brings with it.
/// Each setting can be left to follow the system's own choice.
Future<void> showRoomSettings(
  BuildContext context,
  WidgetRef ref,
  DecorPreset preset,
) => PrismSheet.showFullScreen<void>(
  context: context,
  builder: (ctx, scroll) => _RoomSettingsSheet(preset: preset, scroll: scroll),
);

class _RoomSettingsSheet extends ConsumerStatefulWidget {
  const _RoomSettingsSheet({required this.preset, required this.scroll});
  final DecorPreset preset;
  final ScrollController scroll;
  @override
  ConsumerState<_RoomSettingsSheet> createState() => _RoomSettingsSheetState();
}

class _RoomSettingsSheetState extends ConsumerState<_RoomSettingsSheet> {
  late final _name = TextEditingController(text: widget.preset.name);
  late final _desc = TextEditingController(text: widget.preset.description);
  late RoomSettings _room = widget.preset.room ?? const RoomSettings();

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final p = widget.preset
      ..name = _name.text.trim().isEmpty
          ? widget.preset.name
          : _name.text.trim()
      ..description = _desc.text.trim()
      ..category = roomCategory
      ..room = _room;
    await ref.read(decorPresetActionsProvider).update(p);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prefs = ref.watch(seasonalPrefsProvider);
    final es = Localizations.localeOf(context).languageCode == 'es';
    final companions = ref.watch(companionsProvider);
    String lookName(String? id) {
      final v = id == null ? null : variationById(id);
      return v == null
          ? tr(context, 'Follow the system', 'Seguir al sistema')
          : '${collectionById(v.collectionId)?.emoji ?? ''} ${v.name}';
    }

    Widget section(String t) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 4),
      child: Text(t, style: theme.textTheme.titleSmall),
    );

    return Column(
      children: [
        PrismSheetTopBar(
          title: tr(context, 'Room settings', 'Ajustes de la sala'),
          trailing: PrismButton(
            label: tr(context, 'Save', 'Guardar'),
            tone: PrismButtonTone.filled,
            density: PrismControlDensity.compact,
            onPressed: _save,
          ),
        ),
        Expanded(
          child: ListView(
            controller: widget.scroll,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Center(
                child: DecorPreview(
                  items: [
                    ...widget.preset.items,
                    if (_room.living != null &&
                        variationById(_room.living!) != null)
                      ...arrangementForVariation(variationById(_room.living!)!),
                  ],
                  width: 140,
                  height: 230,
                ),
              ),
              const SizedBox(height: 10),
              PrismTextField(
                controller: _name,
                labelText: tr(context, 'Name', 'Nombre'),
              ),
              const SizedBox(height: 8),
              PrismTextField(
                controller: _desc,
                labelText: tr(context, 'Description', 'Descripción'),
                maxLines: 3,
              ),
              section(tr(context, 'Living look', 'Estilo vivo')),
              Text(lookName(_room.living), style: theme.textTheme.bodyMedium),
              Wrap(
                spacing: 6,
                children: [
                  if (prefs.livingVariation != null &&
                      prefs.livingVariation != _room.living)
                    PrismChip(
                      label: tr(
                        context,
                        'Use my current look',
                        'Usar mi estilo actual',
                      ),
                      selected: false,
                      onTap: () => setState(
                        () => _room = _room.copyWith(
                          living: prefs.livingVariation,
                        ),
                      ),
                    ),
                  if (_room.living != null)
                    PrismChip(
                      label: tr(
                        context,
                        'Follow the system',
                        'Seguir al sistema',
                      ),
                      selected: false,
                      onTap: () =>
                          setState(() => _room = _room.copyWith(living: null)),
                    ),
                ],
              ),
              section(tr(context, 'Layout', 'Diseño')),
              Text(lookName(_room.layout), style: theme.textTheme.bodyMedium),
              Wrap(
                spacing: 6,
                children: [
                  if (prefs.layoutVariation != null &&
                      prefs.layoutVariation != _room.layout)
                    PrismChip(
                      label: tr(
                        context,
                        'Use my current layout',
                        'Usar mi diseño actual',
                      ),
                      selected: false,
                      onTap: () => setState(
                        () => _room = _room.copyWith(
                          layout: prefs.layoutVariation,
                          layoutParts: prefs.layoutParts,
                        ),
                      ),
                    ),
                  if (_room.layout != null)
                    PrismChip(
                      label: tr(
                        context,
                        'Follow the system',
                        'Seguir al sistema',
                      ),
                      selected: false,
                      onTap: () =>
                          setState(() => _room = _room.copyWith(layout: null)),
                    ),
                ],
              ),
              section(tr(context, 'Environment', 'Ambiente')),
              PrismSwitchRow(
                title: tr(
                  context,
                  'Room has its own weather and effects',
                  'La sala tiene su propio clima y efectos',
                ),
                subtitle: tr(
                  context,
                  'Starts from your current environmental effects.',
                  'Empieza con tus efectos ambientales actuales.',
                ),
                value: _room.env != null,
                onChanged: (v) => setState(
                  () => _room = _room.copyWith(env: v ? prefs.env : null),
                ),
              ),
              if (_room.env != null)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    PrismChip(
                      label: tr(context, 'No weather', 'Sin clima'),
                      selected: _room.env!.mode == WeatherMode.off,
                      onTap: () => setState(
                        () => _room = _room.copyWith(
                          env: _room.env!.copyWith(mode: WeatherMode.off),
                        ),
                      ),
                    ),
                    for (final w in WeatherKind.values)
                      PrismChip(
                        label: '${w.emoji} ${es ? w.es : w.en}',
                        selected:
                            _room.env!.mode == WeatherMode.manual &&
                            _room.env!.weather == w,
                        onTap: () => setState(
                          () => _room = _room.copyWith(
                            env: _room.env!.copyWith(
                              mode: WeatherMode.manual,
                              weather: w,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              section(tr(context, 'Lighting', 'Iluminación')),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  PrismChip(
                    label: tr(context, 'Real time of day', 'Hora real'),
                    selected: _room.lighting == null,
                    onTap: () =>
                        setState(() => _room = _room.copyWith(lighting: null)),
                  ),
                  for (final ph in TimePhase.values)
                    PrismChip(
                      label: es ? ph.es : ph.en,
                      selected: _room.lighting == ph.name,
                      onTap: () => setState(
                        () => _room = _room.copyWith(lighting: ph.name),
                      ),
                    ),
                ],
              ),
              if (_room.lighting != null && _room.env?.phases != true)
                Text(
                  tr(
                    context,
                    'Fixed lighting shows when the room has time-of-day light on (Environmental effects).',
                    'La luz fija se ve cuando la sala tiene activada la luz del día.',
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              section(tr(context, 'Ambient sound', 'Sonido ambiental')),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  PrismChip(
                    label: tr(
                      context,
                      'Follow the system',
                      'Seguir al sistema',
                    ),
                    selected: _room.audioId == null,
                    onTap: () =>
                        setState(() => _room = _room.copyWith(audioId: null)),
                  ),
                  for (final a in ambienceCatalog)
                    PrismChip(
                      label: '${a.emoji} ${es ? a.labelEs : a.label}',
                      selected: _room.audioId == a.id,
                      onTap: () =>
                          setState(() => _room = _room.copyWith(audioId: a.id)),
                    ),
                ],
              ),
              Text(
                tr(
                  context,
                  'Plays only when ambient sound is on in Seasonal Living.',
                  'Solo suena si el sonido ambiental está activado.',
                ),
                style: theme.textTheme.bodySmall,
              ),
              if (companions.isNotEmpty) ...[
                section(tr(context, 'Companions here', 'Compañeros aquí')),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in companions)
                      PrismChip(
                        label: c.name,
                        selected: _room.companions.contains(c.id),
                        onTap: () => setState(
                          () => _room = _room.copyWith(
                            companions: _room.companions.contains(c.id)
                                ? [
                                    for (final x in _room.companions)
                                      if (x != c.id) x,
                                  ]
                                : [..._room.companions, c.id],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              PrismButton(
                label: tr(
                  context,
                  'Arrange furniture in the Studio',
                  'Colocar muebles en el Estudio',
                ),
                icon: Icons.chair_outlined,
                tone: PrismButtonTone.outlined,
                expanded: true,
                onPressed: () async {
                  await _save();
                  if (!context.mounted) return;
                  context.push(
                    AppRoutePaths.seasonalStudio,
                    extra: 'preset:${widget.preset.id}',
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Home shortcut: which room you're in, and a quick switch.
class DigitalRoomsHomeCard extends ConsumerWidget {
  const DigitalRoomsHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rooms = [
      for (final p in ref.watch(decorPresetsProvider))
        if (p.isRoom) p,
    ];
    final active = ref.watch(seasonalPrefsProvider).activePresetId;
    return PrismSurface(
      padding: const EdgeInsets.all(12),
      onTap: () => context.push(AppRoutePaths.digitalRooms),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🏠', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  tr(context, 'Digital Rooms', 'Salas digitales'),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.outline),
            ],
          ),
          const SizedBox(height: 8),
          if (rooms.isEmpty)
            Text(
              tr(
                context,
                'Save your favourite decorations as rooms to switch between them here.',
                'Guarda tus decoraciones favoritas como salas para cambiar entre ellas aquí.',
              ),
              style: theme.textTheme.bodySmall,
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final r in rooms)
                  PrismChip(
                    label: r.name,
                    selected: active == r.id,
                    onTap: () => enterRoom(
                      ref,
                      active == r.id ? null : r.id,
                      undoMessage: tr(
                        context,
                        'Room changed.',
                        'Sala cambiada.',
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
