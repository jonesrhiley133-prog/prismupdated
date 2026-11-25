import 'dart:math' as math;

import 'package:prism_plurality/features/companions/companion_data.dart';
import 'package:prism_plurality/features/companions/companion_widgets.dart';
import 'package:prism_plurality/features/games/engines/tone_player.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

const ambientSounds = {
  'none': 'None',
  'rain': 'Rain',
  'wind': 'Wind',
  'waves': 'Waves',
  'fire': 'Crackling fire',
  'stream': 'Stream',
};

/// Decorate a habitat: place, move and resize decorations by dragging —
/// or with the buttons below the scene (no precise gestures needed).
class HabitatEditorScreen extends ConsumerStatefulWidget {
  const HabitatEditorScreen({super.key, required this.habitatId});
  final String habitatId;
  @override
  ConsumerState<HabitatEditorScreen> createState() =>
      _HabitatEditorScreenState();
}

class _HabitatEditorScreenState extends ConsumerState<HabitatEditorScreen> {
  List<HabitatItem>? _items;
  String? _selected;
  final _sound = TonePlayer();
  bool _playing = false;

  @override
  void dispose() {
    _sound.dispose();
    super.dispose();
  }

  Habitat? get _h => ref
      .read(habitatsProvider)
      .where((h) => h.id == widget.habitatId)
      .firstOrNull;

  Future<void> _saveItems() async {
    final h = _h;
    if (h == null || _items == null) return;
    await ref.read(companionActionsProvider).saveHabitat(h, {
      'items': [for (final i in _items!) i.toJson()],
    });
  }

  void _update(String id, HabitatItem Function(HabitatItem) f) =>
      setState(() => _items = [for (final i in _items!) i.id == id ? f(i) : i]);

  @override
  Widget build(BuildContext context) {
    final h = ref
        .watch(habitatsProvider)
        .where((h) => h.id == widget.habitatId)
        .firstOrNull;
    if (h == null)
      return const PrismPageScaffold(
        topBar: PrismTopBar(title: 'Habitat', showBackButton: true),
        body: EmptyState(
          icon: Icon(Icons.house_outlined),
          title: 'Habitat not found',
          subtitle: 'It may have been removed.',
        ),
      );
    _items ??= h.items;
    final theme = Theme.of(context);
    final actions = ref.read(companionActionsProvider);
    final residents = [
      for (final c in ref.watch(companionsProvider))
        if (c.habitatId == h.id && !c.isEgg) c,
    ];
    final sel = _items!.where((i) => i.id == _selected).firstOrNull;
    final ambient = '${h.r.fields['ambient'] ?? 'none'}';

    Widget chips(
      String label,
      Map<String, String> values,
      String current,
      String key,
    ) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in values.entries)
                PrismChip(
                  label: e.value,
                  selected: current == e.key,
                  onTap: () => actions.saveHabitat(h, {key: e.key}),
                ),
            ],
          ),
        ],
      ),
    );

    return PopScope(
      onPopInvokedWithResult: (_, _) => _saveItems(),
      child: PrismPageScaffold(
        topBar: PrismTopBar(
          title: h.name,
          showBackButton: true,
          actions: [
            PrismTopBarAction(
              icon: Icons.drive_file_rename_outline,
              tooltip: 'Rename',
              onPressed: () => _rename(context, h),
            ),
            PrismTopBarAction(
              icon: Icons.delete_outline,
              tooltip: 'Delete habitat',
              onPressed: () async {
                final ok = await PrismDialog.confirm(
                  context: context,
                  title: 'Delete ${h.name}?',
                  message:
                      'Companions living here just move out — nothing else changes.',
                  confirmLabel: 'Delete',
                  destructive: true,
                );
                if (!ok) return;
                _items = null;
                await actions.deleteHabitat(h);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ],
        ),
        bodyPadding: EdgeInsets.zero,
        body: ClampedBody(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              32 + NavBarInset.of(context),
            ),
            children: [
              AspectRatio(
                aspectRatio: 4 / 3,
                child: LayoutBuilder(
                  builder: (context, box) => HabitatScene(
                    env: h.env,
                    time: h.timeOfDay,
                    weather: h.weather,
                    lighting: h.lighting,
                    items: const [],
                    children: [
                      for (final (i, c) in residents.take(4).indexed)
                        Positioned(
                          left: box.maxWidth * (0.12 + i * 0.22),
                          bottom: 8,
                          child: CompanionFigure(
                            companion: c,
                            size: math.min(110, box.maxWidth * 0.26),
                          ),
                        ),
                      for (final it in _items!)
                        Positioned(
                          left: it.x * box.maxWidth - 20 * it.scale,
                          top: it.y * box.maxHeight - 20 * it.scale,
                          child: Semantics(
                            button: true,
                            selected: _selected == it.id,
                            label: '${it.type} decoration',
                            child: GestureDetector(
                              onTap: () => setState(() => _selected = it.id),
                              onPanStart: (_) =>
                                  setState(() => _selected = it.id),
                              onPanUpdate: (d) => _update(
                                it.id,
                                (x) => x.copyWith(
                                  x: (x.x + d.delta.dx / box.maxWidth).clamp(
                                    0.02,
                                    0.98,
                                  ),
                                  y: (x.y + d.delta.dy / box.maxHeight).clamp(
                                    0.05,
                                    0.98,
                                  ),
                                ),
                              ),
                              onPanEnd: (_) => _saveItems(),
                              child: Container(
                                decoration: _selected == it.id
                                    ? BoxDecoration(
                                        border: Border.all(
                                          color: theme.colorScheme.primary,
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      )
                                    : null,
                                child: Text(
                                  habitatDecor[it.type] ?? '✨',
                                  style: TextStyle(fontSize: 34 * it.scale),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (sel != null) ...[
                const SizedBox(height: 8),
                PrismSurface(
                  padding: const EdgeInsets.all(8),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    children: [
                      Text(
                        '${habitatDecor[sel.type]} ',
                        style: const TextStyle(fontSize: 20),
                      ),
                      for (final (icon, tip, dx, dy) in [
                        (Icons.arrow_back, 'Move left', -0.05, 0.0),
                        (Icons.arrow_upward, 'Move up', 0.0, -0.05),
                        (Icons.arrow_downward, 'Move down', 0.0, 0.05),
                        (Icons.arrow_forward, 'Move right', 0.05, 0.0),
                      ])
                        IconButton(
                          tooltip: tip,
                          icon: Icon(icon),
                          onPressed: () {
                            _update(
                              sel.id,
                              (x) => x.copyWith(
                                x: (x.x + dx).clamp(0.02, 0.98),
                                y: (x.y + dy).clamp(0.05, 0.98),
                              ),
                            );
                            _saveItems();
                          },
                        ),
                      IconButton(
                        tooltip: 'Smaller',
                        icon: const Icon(Icons.remove),
                        onPressed: () {
                          _update(
                            sel.id,
                            (x) => x.copyWith(
                              scale: (x.scale - 0.15).clamp(0.4, 2.5),
                            ),
                          );
                          _saveItems();
                        },
                      ),
                      IconButton(
                        tooltip: 'Bigger',
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          _update(
                            sel.id,
                            (x) => x.copyWith(
                              scale: (x.scale + 0.15).clamp(0.4, 2.5),
                            ),
                          );
                          _saveItems();
                        },
                      ),
                      IconButton(
                        tooltip: 'Remove',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          setState(() {
                            _items = [
                              for (final i in _items!)
                                if (i.id != sel.id) i,
                            ];
                            _selected = null;
                          });
                          _saveItems();
                        },
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text('Add decorations', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final e in habitatDecor.entries)
                    Semantics(
                      button: true,
                      label: 'Add ${e.key}',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          final id = DateTime.now().microsecondsSinceEpoch
                              .toString();
                          final rnd = math.Random();
                          setState(() {
                            _items = [
                              ..._items!,
                              HabitatItem(
                                id,
                                e.key,
                                0.15 + rnd.nextDouble() * 0.7,
                                0.55 + rnd.nextDouble() * 0.35,
                              ),
                            ];
                            _selected = id;
                          });
                          _saveItems();
                        },
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Center(
                            child: Text(
                              e.value,
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              chips(
                'Place',
                {for (final e in habitatEnvs) e.id: '${e.emoji} ${e.name}'},
                h.env,
                'env',
              ),
              chips(
                'Time of day',
                const {
                  'auto': 'Follow the clock',
                  'morning': 'Morning',
                  'day': 'Day',
                  'evening': 'Evening',
                  'night': 'Night',
                },
                h.timeOfDay,
                'time',
              ),
              chips(
                'Weather',
                const {
                  'clear': 'Clear',
                  'rain': 'Rain',
                  'snow': 'Snow',
                  'leaves': 'Falling leaves',
                  'petals': 'Petals',
                  'stars': 'Twinkling stars',
                  'fog': 'Mist',
                  'bubbles': 'Bubbles',
                },
                h.weather,
                'weather',
              ),
              chips(
                'Lighting',
                const {
                  'soft': 'Soft',
                  'warm': 'Warm',
                  'cool': 'Cool',
                  'fairy': 'Fairy lights',
                  'none': 'Plain',
                },
                h.lighting,
                'lighting',
              ),
              chips('Ambient sound', ambientSounds, ambient, 'ambient'),
              if (ambient != 'none')
                PrismButton(
                  label: _playing ? 'Stop sound' : 'Play sound',
                  icon: _playing ? Icons.stop : Icons.play_arrow,
                  onPressed: () async {
                    if (_playing) {
                      await _sound.stop();
                    } else {
                      await _sound.loop(ambient, volume: 0.35);
                    }
                    setState(() => _playing = !_playing);
                  },
                ),
              const SizedBox(height: 10),
              Text(
                residents.isEmpty
                    ? 'Nobody lives here yet — move a companion in from their profile.'
                    : 'Living here: ${residents.map((c) => c.name).join(', ')}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context, Habitat h) async {
    final t = TextEditingController(text: h.r.title);
    final ok = await PrismDialog.show<bool>(
      context: context,
      title: 'Rename habitat',
      builder: (_) => PrismTextField(
        controller: t,
        hintText: habitatEnvById(h.env).name,
        autofocus: true,
      ),
      actions: [
        PrismButton(
          label: 'Cancel',
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(false),
        ),
        PrismButton(
          label: 'Save',
          tone: PrismButtonTone.filled,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
        ),
      ],
    );
    if (ok == true)
      await ref
          .read(companionActionsProvider)
          .saveHabitat(h, const {}, title: t.text.trim());
    t.dispose();
  }
}
