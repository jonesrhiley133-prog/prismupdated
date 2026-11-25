import 'dart:async';
import 'dart:math' as math;

import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/companions/companion_art.dart';
import 'package:prism_plurality/features/companions/companion_data.dart';
import 'package:prism_plurality/features/companions/companion_species.dart';
import 'package:prism_plurality/features/companions/companion_widgets.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/subsystems/hub/subsystem_data.dart';
import 'package:prism_plurality/shared/media/prism_media.dart';
import 'package:prism_plurality/features/companions/custom_art_editor.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Adopt or hatch a companion, step by step. Every choice is made by you —
/// no random eggs, no purchases.
class AdoptScreen extends ConsumerStatefulWidget {
  const AdoptScreen({super.key, this.hatch = false});
  final bool hatch;
  @override
  ConsumerState<AdoptScreen> createState() => _AdoptScreenState();
}

class _AdoptScreenState extends ConsumerState<AdoptScreen> {
  int _step = 0;
  late bool _hatch = widget.hatch;
  String _egg = 'classic';
  Species _species = speciesCatalog.first;
  CustomSpecies? _custom;
  int _palette = 0;
  OwnerType _ownerType = OwnerType.system;
  List<String> _owners = [];
  final Set<String> _traits = {};
  final _customTrait = TextEditingController();
  final _name = TextEditingController();
  final _nick = TextEditingController();
  final _pronouns = TextEditingController();
  String? _birthday;
  CompanionLook _look = const CompanionLook();
  String _hatchWhen = 'now';
  DateTime? _hatchCustom;
  SpeciesCategory? _cat;
  bool _busy = false;

  static const _steps = [
    'Choose',
    'Look',
    'Owners',
    'Personality',
    'Name',
    'Style',
    'Finish',
  ];

  @override
  void initState() {
    super.initState();
    final fronter = currentFronterId(ref);
    if (fronter != null) {
      _ownerType = OwnerType.member;
      _owners = [fronter];
    }
  }

  @override
  void dispose() {
    for (final c in [_customTrait, _name, _nick, _pronouns]) {
      c.dispose();
    }
    super.dispose();
  }

  List<(Color, Color)> get _palettes => [
    (_species.primary, _species.secondary),
    ..._species.palettes,
  ];

  void _pickSpecies(Species s, {CustomSpecies? custom}) => setState(() {
    _species = s;
    _custom = custom;
    _palette = 0;
    _look = const CompanionLook();
    if (_traits.isEmpty) _traits.addAll(s.traits.take(2));
  });

  CompanionLook get _finalLook {
    final (p, s) = _palettes[_palette.clamp(0, _palettes.length - 1)];
    return _look.copyWith({
      'primary': _palette == 0 ? null : p.toARGB32(),
      'secondary': _palette == 0 ? null : s.toARGB32(),
    });
  }

  bool get _canNext => switch (_step) {
    2 =>
      _ownerType == OwnerType.system ||
          _ownerType == OwnerType.none ||
          _owners.isNotEmpty,
    4 => _name.text.trim().isNotEmpty,
    _ => true,
  };

  DateTime? get _hatchAt {
    if (!_hatch) return null;
    final now = DateTime.now();
    return switch (_hatchWhen) {
      'hour' => now.add(const Duration(hours: 1)),
      'tonight' =>
        DateTime(now.year, now.month, now.day, 20).isAfter(now)
            ? DateTime(now.year, now.month, now.day, 20)
            : now.add(const Duration(hours: 3)),
      'tomorrow' => DateTime(now.year, now.month, now.day + 1, 8),
      'custom' => _hatchCustom,
      _ => null,
    };
  }

  Future<void> _finish() async {
    setState(() => _busy = true);
    final hatchAt = _hatchAt;
    final traits = [..._traits];
    final rec = await ref
        .read(companionActionsProvider)
        .adopt(
          name: _name.text,
          nickname: _nick.text,
          speciesId: _species.id,
          customSpeciesId: _custom?.r.id,
          traits: traits,
          customPersonality: _customTrait.text,
          pronouns: _pronouns.text,
          ownerType: _ownerType,
          owners: _owners,
          look: _finalLook,
          egg: _hatch ? _egg : 'none',
          hatchAt: hatchAt != null && hatchAt.isAfter(DateTime.now())
              ? hatchAt
              : (_hatch ? DateTime.now() : null),
          birthday: _birthday,
        );
    if (!mounted) return;
    final scheduled = hatchAt != null && hatchAt.isAfter(DateTime.now());
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => _WelcomeScreen(
          companionId: rec.id,
          egg: _hatch ? _egg : null,
          scheduled: scheduled,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = CompanionView(
      species: _species,
      look: _finalLook,
      size: 132,
      traits: [..._traits],
    );
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: _hatch ? 'Hatch an egg' : 'Adopt a companion',
        showBackButton: true,
      ),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: Column(
          children: [
            // Progress
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Semantics(
                label:
                    'Step ${_step + 1} of ${_steps.length}: ${_steps[_step]}',
                child: Row(
                  children: [
                    for (var i = 0; i < _steps.length; i++)
                      Expanded(
                        child: Container(
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            borderRadius: prismCorners(context, 2),
                            color: i <= _step
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  4,
                  16,
                  24 + NavBarInset.of(context),
                ),
                children: [
                  if (_step > 0)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _hatch && _step < 6
                            ? Column(
                                children: [
                                  EggView(style: _egg, size: 84),
                                  Text(
                                    'Your ${_species.name.toLowerCase()} egg',
                                    style: theme.textTheme.labelMedium,
                                  ),
                                ],
                              )
                            : preview,
                      ),
                    ),
                  SectionSwitcher(id: _step, child: _stepBody(context)),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: Row(
                  children: [
                    if (_step > 0)
                      PrismButton(
                        label: 'Back',
                        onPressed: () => setState(() => _step--),
                      ),
                    const Spacer(),
                    PrismButton(
                      label: _step == _steps.length - 1
                          ? (_hatch
                                ? (_hatchAt != null &&
                                          _hatchAt!.isAfter(DateTime.now())
                                      ? 'Tuck in the egg'
                                      : 'Hatch!')
                                : 'Adopt!')
                          : 'Next',
                      tone: PrismButtonTone.filled,
                      isLoading: _busy,
                      enabled: _canNext,
                      onPressed: _step == _steps.length - 1
                          ? _finish
                          : () => setState(() => _step++),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepBody(BuildContext context) {
    final theme = Theme.of(context);
    switch (_step) {
      case 0:
        final customs = ref.watch(customSpeciesProvider);
        final list = speciesCatalog
            .where((s) => _cat == null || s.category == _cat)
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PrismSegmentedControl<bool>(
              segments: const [
                PrismSegment(value: false, label: 'Adopt'),
                PrismSegment(value: true, label: 'Hatch an egg'),
              ],
              selected: _hatch,
              onChanged: (v) => setState(() => _hatch = v),
            ),
            if (_hatch) ...[
              const SizedBox(height: 12),
              Text('Egg style', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              SizedBox(
                height: 96,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final e in eggStyles.entries)
                      Semantics(
                        selected: _egg == e.key,
                        button: true,
                        label: '${e.value.$1} egg',
                        child: GestureDetector(
                          onTap: () => setState(() => _egg = e.key),
                          child: Container(
                            width: 76,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              borderRadius: prismCorners(context, 14),
                              border: Border.all(
                                color: _egg == e.key
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outlineVariant,
                                width: _egg == e.key ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                EggView(style: e.key, size: 56),
                                Text(
                                  e.value.$1,
                                  style: theme.textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                'You choose what hatches — it\'s never random.',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                PrismChip(
                  label: 'All',
                  selected: _cat == null,
                  onTap: () => setState(() => _cat = null),
                ),
                for (final c in SpeciesCategory.values.where(
                  (c) => c != SpeciesCategory.custom,
                ))
                  PrismChip(
                    label: '${c.emoji} ${c.label}',
                    selected: _cat == c,
                    onTap: () => setState(() => _cat = c),
                  ),
                PrismChip(
                  label: '🎨 Custom',
                  selected: _cat == SpeciesCategory.custom,
                  onTap: () => setState(() => _cat = SpeciesCategory.custom),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_cat == SpeciesCategory.custom) ...[
              for (final cs in customs)
                PrismListRow(
                  leading: SizedBox(
                    width: 48,
                    child: CompanionView(
                      species: cs.base,
                      look: const CompanionLook(),
                      size: 48,
                      animate: false,
                    ),
                  ),
                  title: Text(cs.name),
                  subtitle: Text(
                    cs.media == null
                        ? 'Based on ${cs.base.name}'
                        : 'Uploaded artwork',
                  ),
                  selected: _custom?.r.id == cs.r.id,
                  onTap: () => _pickSpecies(cs.base, custom: cs),
                  trailing: cs.media == null
                      ? null
                      : IconButton(
                          tooltip: 'Adjust picture',
                          icon: const Icon(Icons.crop_rotate),
                          onPressed: () async {
                            final f = await CustomArtEditor.open(
                              context,
                              media: cs.media!,
                              base: cs.base,
                              initial: cs.fit,
                            );
                            if (f != null)
                              await ref
                                  .read(companionActionsProvider)
                                  .saveCustomFit(cs, f);
                          },
                        ),
                ),
              PrismButton(
                label: 'Create a custom creature',
                icon: Icons.add_photo_alternate_outlined,
                onPressed: () => _createCustom(context),
              ),
            ] else
              GridView.count(
                crossAxisCount: MediaQuery.sizeOf(context).width > 600 ? 5 : 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.82,
                children: [
                  for (final s in list)
                    Semantics(
                      button: true,
                      selected: _species.id == s.id && _custom == null,
                      label: '${s.name}. ${s.blurb}',
                      child: InkWell(
                        borderRadius: prismCorners(context, 16),
                        onTap: () => _pickSpecies(s),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: prismCorners(context, 16),
                            color: Color.lerp(
                              s.primary,
                              theme.colorScheme.surface,
                              0.82,
                            ),
                            border: Border.all(
                              color: _species.id == s.id && _custom == null
                                  ? theme.colorScheme.primary
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ExcludeSemantics(
                                child: CompanionView(
                                  species: s,
                                  look: const CompanionLook(),
                                  size: 72,
                                  animate: _species.id == s.id,
                                ),
                              ),
                              Text(
                                s.name,
                                style: theme.textTheme.labelMedium,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 8),
            Text(
              _species.blurb,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Pick a colourway', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (var i = 0; i < _palettes.length; i++)
                  Semantics(
                    button: true,
                    selected: _palette == i,
                    label: 'Colourway ${i + 1}',
                    child: GestureDetector(
                      onTap: () => setState(() => _palette = i),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          borderRadius: prismCorners(context, 16),
                          border: Border.all(
                            color: _palette == i
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outlineVariant,
                            width: _palette == i ? 2 : 1,
                          ),
                        ),
                        child: CompanionView(
                          species: _species,
                          look: CompanionLook(
                            primary: i == 0 ? null : _palettes[i].$1.toARGB32(),
                            secondary: i == 0
                                ? null
                                : _palettes[i].$2.toARGB32(),
                          ),
                          size: 76,
                          animate: false,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'You can change every colour later in the appearance editor.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        );
      case 2:
        final members =
            ref.watch(userVisibleMembersProvider).value ?? const <Member>[];
        final subs = ref.watch(subsystemsProvider);
        final prefer = ref.watch(memberNamePreferDisplayProvider);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Who does this companion belong to?',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final o in OwnerType.values)
                  if (o != OwnerType.subsystem || subs.isNotEmpty)
                    PrismChip(
                      label: o.label,
                      selected: _ownerType == o,
                      onTap: () => setState(() {
                        _ownerType = o;
                        if (o == OwnerType.member && _owners.length > 1)
                          _owners = [_owners.first];
                        if (o == OwnerType.subsystem ||
                            o == OwnerType.system ||
                            o == OwnerType.none)
                          _owners = [];
                      }),
                    ),
              ],
            ),
            const SizedBox(height: 10),
            if (_ownerType == OwnerType.member ||
                _ownerType == OwnerType.members)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final m in members)
                    PrismChip(
                      label: memberLabel(m, preferDisplayName: prefer),
                      selected: _owners.contains(m.id),
                      onTap: () => setState(() {
                        if (_ownerType == OwnerType.member) {
                          _owners = [m.id];
                        } else {
                          _owners.contains(m.id)
                              ? _owners.remove(m.id)
                              : _owners.add(m.id);
                        }
                      }),
                    ),
                ],
              ),
            if (_ownerType == OwnerType.subsystem)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in subs)
                    PrismChip(
                      label: s.title,
                      selected: _owners.contains(s.id),
                      onTap: () => setState(() => _owners = [s.id]),
                    ),
                ],
              ),
            const SizedBox(height: 8),
            Text(
              'You can change this any time without losing anything.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Personality', style: theme.textTheme.titleSmall),
            Text(
              'Just for fun — it changes little animations and lines, never how they feel about you.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in personalityTraits.entries)
                  PrismChip(
                    label: '${e.value} ${traitLabel(e.key)}',
                    selected: _traits.contains(e.key),
                    onTap: () => setState(
                      () => _traits.contains(e.key)
                          ? _traits.remove(e.key)
                          : _traits.add(e.key),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            PrismTextField(
              controller: _customTrait,
              labelText: 'In your own words (optional)',
              hintText: 'Loves rainy days and hums when happy',
              maxLines: 2,
            ),
          ],
        );
      case 4:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PrismTextField(
              controller: _name,
              labelText: 'Name',
              autofocus: true,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            PrismTextField(controller: _nick, labelText: 'Nickname (optional)'),
            const SizedBox(height: 10),
            PrismTextField(
              controller: _pronouns,
              labelText: 'Pronouns (optional)',
            ),
            const SizedBox(height: 10),
            Builder(
              builder: (rowContext) => PrismListRow(
                leading: const Icon(Icons.cake_outlined),
                title: const Text('Birthday (optional)'),
                subtitle: Text(_birthday ?? 'Not set'),
                trailing: _birthday == null
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _birthday = null),
                      ),
                onTap: () async {
                  final d = await showPrismDatePicker(
                    context: context,
                    anchorContext: rowContext,
                    initialDate: DateTime.now(),
                  );
                  if (d != null)
                    setState(
                      () => _birthday =
                          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
                    );
                },
              ),
            ),
          ],
        );
      case 5:
        Widget row(
          String label,
          List<String> options,
          String value,
          String key,
        ) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final o in options)
                    PrismChip(
                      label: traitLabel(o),
                      selected: value == o,
                      onTap: () =>
                          setState(() => _look = _look.copyWith({key: o})),
                    ),
                ],
              ),
            ],
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            row(
              'Expression',
              CompanionLook.expressions,
              _look.expression,
              'expression',
            ),
            row('Hat', CompanionLook.hats.take(7).toList(), _look.hat, 'hat'),
            row('Neck', CompanionLook.necks, _look.neck, 'neck'),
            row(
              'Sparkle',
              CompanionLook.particleList.take(4).toList(),
              _look.particles,
              'particles',
            ),
            Text(
              'Lots more in the appearance editor after adopting.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _hatch
                  ? 'When should it hatch?'
                  : 'Ready to welcome ${_name.text.trim()}?',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            if (_hatch) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  for (final (k, l) in const [
                    ('now', 'Right now'),
                    ('hour', 'In an hour'),
                    ('tonight', 'Tonight'),
                    ('tomorrow', 'Tomorrow morning'),
                    ('custom', 'Pick a time'),
                  ])
                    PrismChip(
                      label: l,
                      selected: _hatchWhen == k,
                      onTap: () async {
                        if (k == 'custom') {
                          final d = await showPrismDatePicker(
                            context: context,
                            initialDate: DateTime.now().add(
                              const Duration(days: 1),
                            ),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (d == null) return;
                          setState(
                            () => _hatchCustom = DateTime(
                              d.year,
                              d.month,
                              d.day,
                              9,
                            ),
                          );
                        }
                        setState(() => _hatchWhen = k);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'A scheduled egg just waits patiently — nothing happens if you\'re away, and you can hatch it early any time.',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 10),
            PrismSurface(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_name.text.trim()}${_nick.text.trim().isEmpty ? '' : ' "${_nick.text.trim()}"'} · ${_custom?.name ?? _species.name}',
                    style: theme.textTheme.titleSmall,
                  ),
                  if (_traits.isNotEmpty)
                    Text(
                      _traits.map(traitLabel).join(', '),
                      style: theme.textTheme.bodySmall,
                    ),
                  Text(_ownerType.label, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        );
    }
  }

  Future<void> _createCustom(BuildContext context) async {
    final name = TextEditingController();
    var base = 'slime';
    String? media;
    ArtFit? fit;
    final ok = await PrismSheet.show<bool>(
      context: context,
      title: 'Custom creature',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            PrismTextField(
              controller: name,
              labelText: 'Creature name',
              hintText: 'Moss dragon',
            ),
            const SizedBox(height: 10),
            Text(
              'Start from a shape (accessories and colours work on it):',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in speciesCatalog)
                  PrismChip(
                    label: '${s.emoji} ${s.name}',
                    selected: base == s.id,
                    onTap: () => set(() => base = s.id),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            PrismButton(
              label: media == null
                  ? 'Upload a transparent picture (optional)'
                  : 'Picture added ✓',
              icon: Icons.image_outlined,
              onPressed: () async {
                final id = await PrismMedia.pickImage(ref);
                if (id == null || !ctx.mounted) return;
                set(() => media = id);
                final f = await CustomArtEditor.open(
                  ctx,
                  media: id,
                  base: speciesById(base),
                  initial: fit ?? const ArtFit(),
                );
                if (f != null) set(() => fit = f);
              },
            ),
            if (media != null)
              PrismButton(
                label: 'Adjust picture (crop, size, anchors)',
                icon: Icons.crop_rotate,
                onPressed: () async {
                  final f = await CustomArtEditor.open(
                    ctx,
                    media: media!,
                    base: speciesById(base),
                    initial: fit ?? const ArtFit(),
                  );
                  if (f != null) set(() => fit = f);
                },
              ),
            const SizedBox(height: 6),
            Text(
              'A PNG with a transparent background looks best. It replaces the drawn body; hats and effects still fit on top.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            PrismButton(
              label: 'Save creature',
              tone: PrismButtonTone.filled,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      final rec = await ref
          .read(companionActionsProvider)
          .saveCustomSpecies(
            name: name.text,
            base: base,
            media: media,
            fit: fit,
          );
      _pickSpecies(speciesById(base), custom: CustomSpecies(rec));
    }
    name.dispose();
  }
}

/// The adoption / hatching moment.
class _WelcomeScreen extends ConsumerStatefulWidget {
  const _WelcomeScreen({
    required this.companionId,
    this.egg,
    this.scheduled = false,
  });
  final String companionId;
  final String? egg;
  final bool scheduled;
  @override
  ConsumerState<_WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<_WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (reduced || widget.scheduled) {
        _a.value = widget.scheduled ? 0 : 1;
      } else {
        unawaited(_a.forward());
      }
    });
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(companionByIdProvider(widget.companionId));
    final theme = Theme.of(context);
    if (c == null) return const PrismPageScaffold(body: PrismLoadingState());
    return PrismPageScaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: AnimatedBuilder(
                  animation: _a,
                  builder: (context, _) {
                    final v = _a.value;
                    if (widget.egg != null && (v < 0.62 || widget.scheduled)) {
                      final wob = widget.scheduled
                          ? 0.0
                          : math.sin(v * 40) * 0.12 * (v / 0.62);
                      return EggView(
                        style: widget.egg!,
                        size: 170,
                        wobble: wob,
                        crack: widget.scheduled ? 0 : (v / 0.62).clamp(0, 1),
                      );
                    }
                    final reveal = widget.egg == null
                        ? Curves.elasticOut.transform(v.clamp(0, 1))
                        : Curves.elasticOut.transform(
                            ((v - 0.62) / 0.38).clamp(0, 1),
                          );
                    return Transform.scale(
                      scale: 0.4 + reveal * 0.6,
                      child: CompanionFigure(
                        companion: c,
                        size: 210,
                        pose: CompanionPose.wave,
                        look: c.look.copyWith({
                          'particles': c.look.particles == 'none'
                              ? 'sparkles'
                              : c.look.particles,
                        }),
                      ),
                    );
                  },
                ),
              ),
            ),
            Text(
              widget.scheduled
                  ? '${c.name}\'s egg is tucked in'
                  : (widget.egg != null
                        ? '${c.name} hatched!'
                        : 'Welcome home, ${c.name}!'),
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Text(
                widget.scheduled
                    ? 'It will hatch on ${_fmt(c.hatchAt!)}. You can hatch it early from its profile.'
                    : '${c.species.name} · ${c.traits.map(traitLabel).join(', ')}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: PrismButton(
                label: widget.scheduled ? 'Done' : 'Say hello',
                tone: PrismButtonTone.filled,
                expanded: true,
                onPressed: () => Navigator.of(context).pop(widget.companionId),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(DateTime t) =>
      '${t.month}/${t.day} at ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
