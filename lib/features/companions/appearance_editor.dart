import 'package:prism_plurality/features/companions/companion_art.dart';
import 'package:prism_plurality/features/companions/companion_data.dart';
import 'package:prism_plurality/features/companions/companion_species.dart';
import 'package:prism_plurality/features/companions/companion_widgets.dart';
import 'package:prism_plurality/features/experiences/color_sheet.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

const _swatches = <int>[
  0xFFF2A65A,
  0xFFE8743B,
  0xFFC8572E,
  0xFF8B5E3C,
  0xFF5B4B40,
  0xFF2F2A28,
  0xFF8D96A6,
  0xFFEDE3DA,
  0xFFFFFFFF,
  0xFFFFE07A,
  0xFFFFD1DC,
  0xFFFF9EC7,
  0xFFE86A92,
  0xFFB565F0,
  0xFF8E6BD9,
  0xFF4B4FA8,
  0xFF3D7FE0,
  0xFF5EC8FF,
  0xFF7FE0A8,
  0xFF35B36B,
  0xFF6FBF73,
  0xFF9CCB7E,
  0xFFFF7A3D,
  0xFFE84C4C,
  0xFF2B2B33,
];

/// Everything about how a companion looks, with saved outfits. All
/// options are free — nothing is locked behind streaks or purchases.
class AppearanceEditorScreen extends ConsumerStatefulWidget {
  const AppearanceEditorScreen({super.key, required this.companionId});
  final String companionId;
  @override
  ConsumerState<AppearanceEditorScreen> createState() =>
      _AppearanceEditorScreenState();
}

class _AppearanceEditorScreenState
    extends ConsumerState<AppearanceEditorScreen> {
  late final Companion _c = ref.read(
    companionByIdProvider(widget.companionId),
  )!;
  late CompanionLook _look = _c.look;
  String _tab = 'Colours';
  String _slot = 'hat';

  static const _tabs = [
    'Colours',
    'Body',
    'Face',
    'Wear',
    'Adjust',
    'Effects',
    'Outfits',
  ];

  void _set(String key, Object? value) => setState(() {
    if (key == 'wingsChoice') {
      _look = _look.copyWith({
        'wings': value == 'default' ? null : value == 'on',
      });
    } else if ((key == 'ear' || key == 'tail') && value == 'default') {
      _look = _look.copyWith({key: null});
    } else {
      _look = _look.copyWith({key: value});
    }
  });

  void _setAdjust(AccessoryAdjust a) => setState(() {
    _look = _look.copyWith({
      'adjust': {
        for (final e in _look.adjust.entries) e.key: e.value.toJson(),
        _slot: a.toJson(),
      },
    });
  });

  String _slotValue(String slot) => switch (slot) {
    'hat' => _look.hat,
    'glasses' => _look.glasses,
    'neck' => _look.neck,
    'body' => _look.body,
    _ => _look.floating,
  };

  /// Fine-tune where each accessory sits: position, size, angle, mirror,
  /// opacity and which goes in front. Buttons work without dragging.
  List<Widget> _adjustControls(ThemeData theme) {
    final a = _look.adjustOf(_slot);
    const labels = {
      'hat': 'Hat',
      'glasses': 'Glasses',
      'neck': 'Neck',
      'body': 'Outfit',
      'floating': 'Floating friend',
    };
    Widget slider(
      String label,
      double v,
      double min,
      double max,
      String unit,
      ValueChanged<double> on,
    ) => Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(label, style: theme.textTheme.bodySmall),
        ),
        Expanded(
          child: Slider(
            value: v.clamp(min, max),
            min: min,
            max: max,
            onChanged: on,
            semanticFormatterCallback: (x) =>
                '$label ${x.toStringAsFixed(unit == '×' ? 2 : 0)}$unit',
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            '${v.toStringAsFixed(unit == '×' ? 2 : 0)}$unit',
            style: theme.textTheme.labelSmall,
          ),
        ),
      ],
    );
    return [
      Text(
        'Pick an accessory, then nudge it into place for this companion.',
        style: theme.textTheme.bodySmall,
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final k in CompanionLook.accessorySlots)
            PrismChip(
              label:
                  '${labels[k]}${_slotValue(k) == 'none' ? ' (none)' : ''}${_look.adjustOf(k).isIdentity ? '' : ' •'}',
              selected: _slot == k,
              onTap: () => setState(() => _slot = k),
            ),
        ],
      ),
      const SizedBox(height: 8),
      if (_slotValue(_slot) == 'none')
        Text(
          'Nothing is worn here yet — choose one under Wear or Effects.',
          style: theme.textTheme.bodySmall,
        ),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Move left',
            icon: const Icon(Icons.arrow_back),
            onPressed: () =>
                _setAdjust(a.copyWith(dx: (a.dx - 1).clamp(-40, 40))),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Move up',
                icon: const Icon(Icons.arrow_upward),
                onPressed: () =>
                    _setAdjust(a.copyWith(dy: (a.dy - 1).clamp(-40, 40))),
              ),
              IconButton(
                tooltip: 'Move down',
                icon: const Icon(Icons.arrow_downward),
                onPressed: () =>
                    _setAdjust(a.copyWith(dy: (a.dy + 1).clamp(-40, 40))),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Move right',
            icon: const Icon(Icons.arrow_forward),
            onPressed: () =>
                _setAdjust(a.copyWith(dx: (a.dx + 1).clamp(-40, 40))),
          ),
        ],
      ),
      slider(
        'Left/right',
        a.dx,
        -40,
        40,
        '',
        (v) => _setAdjust(a.copyWith(dx: v.roundToDouble())),
      ),
      slider(
        'Up/down',
        a.dy,
        -40,
        40,
        '',
        (v) => _setAdjust(a.copyWith(dy: v.roundToDouble())),
      ),
      slider(
        'Size',
        a.scale,
        0.3,
        2.5,
        '×',
        (v) => _setAdjust(a.copyWith(scale: v)),
      ),
      slider(
        'Angle',
        a.rotation,
        -180,
        180,
        '°',
        (v) => _setAdjust(a.copyWith(rotation: v.roundToDouble())),
      ),
      slider(
        'Opacity',
        a.opacity * 100,
        5,
        100,
        '%',
        (v) => _setAdjust(a.copyWith(opacity: v / 100)),
      ),
      Row(
        children: [
          SizedBox(
            width: 72,
            child: Text('Layer', style: theme.textTheme.bodySmall),
          ),
          IconButton(
            tooltip: 'Send backward',
            icon: const Icon(Icons.flip_to_back),
            onPressed: () =>
                _setAdjust(a.copyWith(layer: (a.layer - 1).clamp(-5, 5))),
          ),
          Text('${a.layer}'),
          IconButton(
            tooltip: 'Bring forward',
            icon: const Icon(Icons.flip_to_front),
            onPressed: () =>
                _setAdjust(a.copyWith(layer: (a.layer + 1).clamp(-5, 5))),
          ),
          const Spacer(),
          PrismChip(
            label: 'Mirror',
            selected: a.mirror,
            onTap: () => _setAdjust(a.copyWith(mirror: !a.mirror)),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        children: [
          PrismButton(
            label: 'Reset this',
            icon: Icons.restart_alt,
            density: PrismControlDensity.compact,
            onPressed: () => _setAdjust(const AccessoryAdjust()),
          ),
          PrismButton(
            label: 'Reset all',
            density: PrismControlDensity.compact,
            onPressed: () => setState(
              () =>
                  _look = _look.copyWith({'adjust': const <String, Object?>{}}),
            ),
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final species = _c.species;
    final outfits = ref.watch(companionOutfitsProvider(_c.id));
    final dirty = _look.toJson().toString() != _c.look.toJson().toString();

    Widget options(
      String label,
      List<String> values,
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
              for (final v in values)
                PrismChip(
                  label: traitLabel(v),
                  selected: current == v,
                  onTap: () => _set(key, v),
                ),
            ],
          ),
        ],
      ),
    );

    Widget colours(
      String label,
      String key,
      Color current, {
      bool allowReset = true,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: theme.textTheme.labelLarge),
              const Spacer(),
              if (allowReset)
                PrismButton(
                  label: 'Species default',
                  density: PrismControlDensity.compact,
                  onPressed: () => _set(key, null),
                ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in _swatches)
                Semantics(
                  button: true,
                  selected: current.toARGB32() == s,
                  label: '$label colour #${s.toRadixString(16).substring(2)}',
                  child: GestureDetector(
                    onTap: () => _set(key, s),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(s),
                        borderRadius: prismRound(context),
                        border: Border.all(
                          color: current.toARGB32() == s
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outlineVariant,
                          width: current.toARGB32() == s ? 3 : 1,
                        ),
                      ),
                    ),
                  ),
                ),
              Semantics(
                button: true,
                label: 'Custom $label colour',
                child: GestureDetector(
                  onTap: () async {
                    final picked = await showPrismColorPicker(
                      context: context,
                      initial: current,
                    );
                    if (picked != null) _set(key, picked.toARGB32());
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: prismRound(context),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: const Icon(Icons.colorize, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final body = switch (_tab) {
      'Colours' => [
        colours('Main colour', 'primary', _look.primaryOf(species)),
        colours('Second colour', 'secondary', _look.secondaryOf(species)),
        colours('Belly', 'belly', _look.bellyOf(species)),
        colours('Eyes', 'eye', Color(_look.eye), allowReset: false),
        colours(
          'Accessory colour',
          'accent',
          Color(_look.accent),
          allowReset: false,
        ),
      ],
      'Body' => [
        options(
          species.covering == Covering.feathers
              ? 'Feather pattern'
              : (species.covering == Covering.scales
                    ? 'Scale pattern'
                    : 'Pattern'),
          CompanionLook.patterns,
          _look.pattern,
          'pattern',
        ),
        options(
          'Ears',
          ['default', ...EarKind.values.map((e) => e.name)],
          _look.ear ?? 'default',
          'ear',
        ),
        options(
          'Tail',
          ['default', ...TailKind.values.map((e) => e.name)],
          _look.tail ?? 'default',
          'tail',
        ),
        options(
          'Wings',
          const ['default', 'on', 'off'],
          _look.wings == null ? 'default' : (_look.wings! ? 'on' : 'off'),
          'wingsChoice',
        ),
        options('Horns', CompanionLook.hornsList, _look.horns, 'horns'),
      ],
      'Face' => [
        options(
          'Expression',
          CompanionLook.expressions,
          _look.expression,
          'expression',
        ),
        options('Markings', CompanionLook.markings, _look.marking, 'marking'),
      ],
      'Wear' => [
        options('Hat', CompanionLook.hats, _look.hat, 'hat'),
        options('Glasses', CompanionLook.glassesList, _look.glasses, 'glasses'),
        options('Neck', CompanionLook.necks, _look.neck, 'neck'),
        options('Outfit', CompanionLook.bodies, _look.body, 'body'),
      ],
      'Adjust' => _adjustControls(theme),
      'Effects' => [
        options(
          'Floating friend',
          CompanionLook.floatings,
          _look.floating,
          'floating',
        ),
        options(
          'Particles',
          CompanionLook.particleList,
          _look.particles,
          'particles',
        ),
        options('Photo frame', CompanionLook.frames, _look.frame, 'frame'),
      ],
      _ => [
        if (outfits.isEmpty)
          Text(
            'No saved outfits yet. Dress up, then save the look here.',
            style: theme.textTheme.bodySmall,
          ),
        for (final o in outfits)
          PrismListRow(
            leading: SizedBox(
              width: 56,
              child: CompanionFigure(
                companion: _c,
                look: o.look,
                size: 56,
                animate: false,
                showParticles: false,
              ),
            ),
            title: Text(o.name),
            subtitle: Text(
              _c.outfitId == o.r.id ? 'Wearing now' : 'Tap to try on',
            ),
            onTap: () => setState(() => _look = o.look),
            trailing: IconButton(
              tooltip: 'Delete outfit',
              icon: const Icon(Icons.delete_outline),
              onPressed: () =>
                  ref.read(companionActionsProvider).deleteOutfit(o),
            ),
          ),
        const SizedBox(height: 8),
        PrismButton(
          label: 'Save this look as an outfit',
          icon: Icons.checkroom,
          onPressed: () => _saveOutfit(context),
        ),
      ],
    };

    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: 'Appearance',
        showBackButton: true,
        actions: [
          PrismTopBarAction(
            icon: Icons.undo,
            tooltip: 'Undo changes',
            onPressed: () => setState(() => _look = _c.look),
          ),
        ],
      ),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: Column(
          children: [
            Container(
              height: 210,
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              decoration: BoxDecoration(
                borderRadius: prismCorners(context, 20),
                color: Color.lerp(
                  _look.primaryOf(species),
                  theme.colorScheme.surface,
                  0.85,
                ),
              ),
              child: Center(
                child: CompanionFigure(companion: _c, look: _look, size: 190),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final t in _tabs)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: PrismChip(
                        label: t,
                        selected: _tab == t,
                        onTap: () => setState(() => _tab = t),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: body,
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: PrismButton(
                  label: dirty ? 'Save look' : 'Done',
                  tone: PrismButtonTone.filled,
                  expanded: true,
                  onPressed: () async {
                    if (dirty)
                      await ref.read(companionActionsProvider).save(_c, {
                        'look': _look.toJson(),
                        'outfit': null,
                      });
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveOutfit(BuildContext context) async {
    final t = TextEditingController();
    final ok = await PrismDialog.show<bool>(
      context: context,
      title: 'Name this outfit',
      builder: (_) =>
          PrismTextField(controller: t, hintText: 'Rainy day', autofocus: true),
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
    if (ok == true) {
      final current = ref.read(companionByIdProvider(_c.id)) ?? _c;
      await ref.read(companionActionsProvider).save(current, {
        'look': _look.toJson(),
      });
      await ref
          .read(companionActionsProvider)
          .saveOutfit(
            ref.read(companionByIdProvider(_c.id)) ?? current,
            t.text.trim().isEmpty ? 'Outfit' : t.text,
            _look,
          );
    }
    t.dispose();
  }
}
