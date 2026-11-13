import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:prism_plurality/features/appearance/models/look.dart';
import 'package:prism_plurality/features/appearance/services/appearance_store.dart';
import 'package:prism_plurality/features/appearance/views/look_controls.dart';
import 'package:prism_plurality/l10n/app_localizations.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/look_theme.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';
import 'package:prism_plurality/shared/widgets/prism_dialog.dart';
import 'package:prism_plurality/shared/widgets/prism_page_scaffold.dart';
import 'package:prism_plurality/shared/widgets/prism_segmented_control.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_surface.dart';
import 'package:prism_plurality/shared/widgets/prism_text_field.dart';
import 'package:prism_plurality/shared/widgets/prism_toast.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar.dart';

String elementLabel(AppLocalizations l10n, String e) => switch (e) {
  LookElement.button => l10n.apElButtons,
  LookElement.card => l10n.apElCards,
  LookElement.nav => l10n.apElNav,
  LookElement.header => l10n.apElHeader,
  LookElement.input => l10n.apElInputs,
  LookElement.dialog => l10n.apElDialogs,
  LookElement.divider => l10n.apElDividers,
  LookElement.icon => l10n.apElIcons,
  LookElement.badge => l10n.apElBadges,
  _ => l10n.apElText,
};

/// Which style properties make sense for each element.
const _props = <String, List<String>>{
  LookElement.button: ['color', 'color2', 'radius', 'borderWidth', 'borderColor', 'shadow', 'padding'],
  LookElement.card: ['color', 'color2', 'opacity', 'radius', 'borderWidth', 'borderColor', 'shadow', 'padding'],
  LookElement.nav: ['color', 'color2', 'opacity', 'radius', 'borderWidth', 'borderColor', 'shadow'],
  LookElement.header: ['color', 'opacity'],
  LookElement.input: ['color', 'opacity', 'radius', 'borderWidth', 'borderColor'],
  LookElement.dialog: ['color', 'opacity', 'radius'],
  LookElement.divider: ['color', 'opacity', 'borderWidth'],
  LookElement.icon: ['color'],
  LookElement.badge: ['color'],
  LookElement.text: ['color'],
};

String pageLabel(AppLocalizations l10n, String page) => switch (page) {
  'home' => l10n.apPageHome,
  'members' => l10n.apPageMembers,
  'chat' => l10n.apPageChat,
  'journal' => l10n.navJournal,
  'notes' => l10n.hwNotes,
  'mood' => l10n.navMood,
  'calendar' => l10n.apPageCalendar,
  'sleep' => l10n.navSleep,
  'cycle' => l10n.navCycle,
  'fitness' => l10n.navFitness,
  'school' => l10n.navSchool,
  'finance' => l10n.navFinance,
  'relationships' => l10n.navRelationships,
  'subsystems' => l10n.navSubsystems,
  'headspace' => l10n.navHeadspace,
  'achievements' => l10n.navAchievements,
  'dictionary' => l10n.apPageDictionary,
  'polls' => l10n.apPagePolls,
  'habits' => l10n.apPageHabits,
  'music' => l10n.navMusic,
  'statistics' => l10n.apPageStatistics,
  _ => l10n.apPageSettings,
};

enum _Tab { background, elements, pages }

/// Edits one preset. While open, the draft is previewed across the whole
/// app; nothing is kept until Save.
class LookEditorScreen extends ConsumerStatefulWidget {
  const LookEditorScreen({super.key, required this.initial});

  final PrismLook initial;

  @override
  ConsumerState<LookEditorScreen> createState() => _LookEditorScreenState();
}

class _LookEditorScreenState extends ConsumerState<LookEditorScreen> {
  late PrismLook _draft = widget.initial;
  _Tab _tab = _Tab.background;
  String _element = LookElement.card;
  bool _dirty = false;
  late final LookPreview _preview;

  @override
  void initState() {
    super.initState();
    _preview = ref.read(lookPreviewProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) => _preview.show(_draft));
  }

  @override
  void dispose() {
    final p = _preview;
    Future.microtask(() => p.show(null));
    super.dispose();
  }

  void _set(PrismLook next) {
    setState(() {
      _draft = next;
      _dirty = true;
    });
    _preview.show(next);
  }

  Future<void> _save() async {
    final saved = await ref.read(appearanceProvider.notifier).saveLook(_draft);
    await ref.read(appearanceProvider.notifier).activate(saved.id);
    _dirty = false;
    if (mounted) {
      PrismToast.success(context, message: context.l10n.apSaved(saved.name));
      Navigator.of(context).pop();
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final l10n = context.l10n;
    return PrismDialog.confirm(
      context: context,
      title: l10n.apDiscardTitle,
      message: l10n.apDiscardMessage,
      confirmLabel: l10n.apDiscard,
      cancelLabel: l10n.apKeepEditing,
      destructive: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final children = <Widget>[
      PrismTextField(
        initialValue: _draft.name,
        labelText: l10n.apPresetName,
        onChanged: (v) => _set(_draft.copyWith(name: v.trim().isEmpty ? _draft.name : v.trim())),
      ),
      const SizedBox(height: 12),
      const LookSample(),
      const SizedBox(height: 12),
      PrismSegmentedControl<_Tab>(
        segments: [
          PrismSegment(value: _Tab.background, label: l10n.apBackground),
          PrismSegment(value: _Tab.elements, label: l10n.apElements),
          PrismSegment(value: _Tab.pages, label: l10n.apPages),
        ],
        selected: _tab,
        onChanged: (v) => setState(() => _tab = v),
      ),
      const SizedBox(height: 8),
      ...switch (_tab) {
        _Tab.background => [BackgroundEditor(spec: _draft.background, onChanged: (b) => _set(_draft.copyWith(background: b)))],
        _Tab.elements => _elements(l10n),
        _Tab.pages => _pages(l10n),
      },
      const SizedBox(height: 24),
    ];
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          _dirty = false;
          Navigator.of(context).pop();
        }
      },
      child: PrismPageScaffold(
        topBar: PrismTopBar(
          title: l10n.apEditTitle,
          showBackButton: true,
          trailing: PrismButton(label: l10n.save, tone: PrismButtonTone.filled, density: PrismControlDensity.compact, onPressed: _save),
        ),
        topBarMaxWidth: PrismTokens.contentMaxWidth,
        bodyPadding: EdgeInsets.zero,
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: PrismTokens.contentMaxWidth),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _elements(AppLocalizations l10n) {
    final s = _draft.element(_element);
    final props = _props[_element]!;
    void put(String key, Object? value) => _set(_draft.withElement(_element, s.set(key, value)));
    return [
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final e in LookElement.all)
            PrismChip(
              label: '${elementLabel(l10n, e)}${_draft.element(e).isEmpty ? '' : ' •'}',
              selected: _element == e,
              onTap: () => setState(() => _element = e),
            ),
        ],
      ),
      const SizedBox(height: 8),
      PrismSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (props.contains('color')) ColorChoiceRow(label: l10n.apColor, value: s.color, onChanged: (v) => put('color', v)),
            if (props.contains('color2') && s.color != null)
              ColorChoiceRow(label: l10n.apGradientWith, value: s.color2, onChanged: (v) => put('color2', v)),
            if (props.contains('opacity'))
              LabeledSlider(
                label: l10n.apTransparency,
                value: 1 - (s.opacity ?? 1),
                min: 0,
                max: 0.95,
                divisions: 19,
                format: (v) => '${(v * 100).round()}%',
                onChanged: (v) => put('opacity', 1 - v),
              ),
            if (props.contains('radius'))
              LabeledSlider(
                label: l10n.apCorners,
                value: s.radius ?? 16,
                min: 0,
                max: 40,
                divisions: 20,
                format: (v) => s.radius == null ? l10n.apDefault : v.round().toString(),
                onChanged: (v) => put('radius', v),
                onReset: s.radius == null ? null : () => put('radius', null),
              ),
            if (props.contains('borderWidth'))
              LabeledSlider(
                label: _element == LookElement.divider ? l10n.apThickness : l10n.apBorder,
                value: s.borderWidth ?? 0,
                min: 0,
                max: 6,
                divisions: 12,
                format: (v) => v.toStringAsFixed(1),
                onChanged: (v) => put('borderWidth', v),
              ),
            if (props.contains('borderColor') && (s.borderWidth ?? 0) > 0)
              ColorChoiceRow(label: l10n.apBorderColor, value: s.borderColor, onChanged: (v) => put('borderColor', v)),
            if (props.contains('shadow'))
              LabeledSlider(
                label: l10n.apShadow,
                value: s.shadow ?? 0,
                min: 0,
                max: 1,
                divisions: 10,
                format: (v) => '${(v * 100).round()}%',
                onChanged: (v) => put('shadow', v),
              ),
            if (props.contains('padding'))
              LabeledSlider(
                label: l10n.apSpacing,
                value: s.padding ?? 1,
                min: 0.5,
                max: 2,
                divisions: 15,
                format: (v) => '${(v * 100).round()}%',
                onChanged: (v) => put('padding', v),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: PrismButton(
                label: l10n.apResetElement(elementLabel(l10n, _element)),
                tone: PrismButtonTone.outlined,
                onPressed: () => _set(_draft.withElement(_element, const ElementStyle())),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _pages(AppLocalizations l10n) {
    final theme = Theme.of(context);
    return [
      Text(l10n.apPagesHelp, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      const SizedBox(height: 8),
      for (final page in lookPages)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: PrismSurface(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            onTap: () => _editPage(page),
            child: Row(
              children: [
                SizedBox(
                  width: 34,
                  height: 34,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LookBackground(spec: _draft.backgroundFor(page), dir: LookTheme.of(context)?.backgroundDir),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(pageLabel(l10n, page), style: theme.textTheme.bodyLarge)),
                Text(
                  _draft.pageBackgrounds.containsKey(page) ? l10n.apOwnBackground : l10n.apSameAsApp,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
    ];
  }

  Future<void> _editPage(String page) async {
    final l10n = context.l10n;
    var spec = _draft.pageBackgrounds[page] ?? _draft.background;
    await PrismSheet.showFullScreen<void>(
      context: context,
      builder: (context, scroll) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: Column(
            children: [
              PrismSheetTopBar(title: pageLabel(l10n, page)),
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    BackgroundEditor(
                      spec: spec,
                      onChanged: (b) {
                        setSheet(() => spec = b);
                        _set(_draft.withPageBackground(page, b));
                      },
                    ),
                    const SizedBox(height: 12),
                    PrismButton(
                      label: l10n.apUseAppBackground,
                      tone: PrismButtonTone.outlined,
                      expanded: true,
                      onPressed: () {
                        _set(_draft.withPageBackground(page, null));
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A miniature page that shows the current look's elements.
class LookSample extends StatelessWidget {
  const LookSample({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final look = LookTheme.of(context);
    return Semantics(
      label: l10n.apPreview,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 210,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (look != null && look.look.background.isCustom)
                LookBackground(spec: look.look.background, dir: look.backgroundDir, reduceEffects: look.reduceEffects)
              else
                ColoredBox(color: theme.scaffoldBackgroundColor),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.apPreview, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    PrismSurface(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          Icon(Icons.favorite_rounded, color: theme.iconTheme.color),
                          const SizedBox(width: 8),
                          Expanded(child: Text(l10n.apSampleCard, style: theme.textTheme.bodyMedium)),
                          Badge(label: const Text('3'), child: Icon(Icons.notifications_rounded, color: theme.iconTheme.color)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    IgnorePointer(child: PrismTextField(hintText: l10n.apSampleInput, isDense: true)),
                    const Spacer(),
                    Row(
                      children: [
                        PrismButton(label: l10n.apSampleButton, tone: PrismButtonTone.filled, density: PrismControlDensity.compact, onPressed: () {}),
                        const SizedBox(width: 8),
                        PrismButton(label: l10n.cancel, density: PrismControlDensity.compact, onPressed: () {}),
                        const Spacer(),
                        Container(
                          width: 70,
                          height: 30,
                          decoration: BoxDecoration(
                            color: look?.fill(LookElement.nav) ?? theme.colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(look?.style(LookElement.nav).radius ?? 15),
                            border: look?.border(LookElement.nav),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Icon(Icons.home_rounded, size: 16, color: theme.colorScheme.primary),
                              Icon(Icons.person_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Background controls shared by the app background and page backgrounds.
class BackgroundEditor extends ConsumerWidget {
  const BackgroundEditor({super.key, required this.spec, required this.onChanged});

  final BgSpec spec;
  final ValueChanged<BgSpec> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final dir = LookTheme.of(context)?.backgroundDir;
    final s = spec;
    final hasImageControls = s.kind == BgKind.image || s.kind == BgKind.builtin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final k in BgKind.values)
              PrismChip(
                label: switch (k) {
                  BgKind.theme => l10n.apBgTheme,
                  BgKind.color => l10n.apBgColor,
                  BgKind.gradient => l10n.apBgGradient,
                  BgKind.image => l10n.apBgImage,
                  BgKind.builtin => l10n.apBgCollection,
                },
                selected: s.kind == k,
                onTap: () => onChanged(s.copyWith(kind: k)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (s.kind != BgKind.theme)
          PrismSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (s.kind == BgKind.color)
                  ColorChoiceRow(label: l10n.apBgColor, value: s.color, allowDefault: false, onChanged: (v) => onChanged(s.copyWith(color: v))),
                if (s.kind == BgKind.gradient) ...[
                  PrismSegmentedControl<GradientKind>(
                    segments: [
                      PrismSegment(value: GradientKind.linear, label: l10n.apGradLinear),
                      PrismSegment(value: GradientKind.diagonal, label: l10n.apGradDiagonal),
                      PrismSegment(value: GradientKind.radial, label: l10n.apGradRadial),
                    ],
                    selected: s.gradient,
                    onChanged: (v) => onChanged(s.copyWith(gradient: v)),
                  ),
                  for (var i = 0; i < s.colors.length; i++)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: ColorChoiceRow(
                            label: l10n.apGradColorN(i + 1),
                            value: s.colors[i],
                            allowDefault: false,
                            onChanged: (v) => onChanged(s.copyWith(colors: [...s.colors]..[i] = v!)),
                          ),
                        ),
                        if (s.colors.length > 2)
                          IconButtonLike(
                            icon: Icons.remove_circle_outline_rounded,
                            label: l10n.apRemoveColor,
                            onTap: () => onChanged(s.copyWith(colors: [...s.colors]..removeAt(i))),
                          ),
                      ],
                    ),
                  if (s.colors.length < 5)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: PrismButton(
                        label: l10n.apAddColor,
                        density: PrismControlDensity.compact,
                        onPressed: () => onChanged(s.copyWith(colors: [...s.colors, s.colors.last])),
                      ),
                    ),
                  if (s.gradient == GradientKind.linear)
                    LabeledSlider(
                      label: l10n.apDirection,
                      value: s.angle,
                      min: 0,
                      max: 360,
                      divisions: 24,
                      format: (v) => '${v.round()}°',
                      onChanged: (v) => onChanged(s.copyWith(angle: v)),
                    ),
                  LabeledSlider(
                    label: l10n.apIntensity,
                    value: s.intensity,
                    min: 0.1,
                    max: 1,
                    divisions: 18,
                    format: (v) => '${(v * 100).round()}%',
                    onChanged: (v) => onChanged(s.copyWith(intensity: v)),
                  ),
                ],
                if (s.kind == BgKind.builtin)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final e in builtInBackgrounds.entries)
                        Semantics(
                          button: true,
                          selected: s.builtin == e.key,
                          label: e.value.name,
                          excludeSemantics: true,
                          child: GestureDetector(
                            onTap: () => onChanged(s.copyWith(builtin: e.key)),
                            child: Column(
                              children: [
                                Container(
                                  width: 76,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(width: s.builtin == e.key ? 3 : 1, color: s.builtin == e.key ? theme.colorScheme.primary : theme.colorScheme.outlineVariant),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: LookBackground(spec: BgSpec(kind: BgKind.builtin, builtin: e.key)),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(e.value.name, style: theme.textTheme.labelSmall),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                if (s.kind == BgKind.image) ...[
                  if (s.image != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(height: 140, child: LookBackground(spec: s, dir: dir)),
                    ),
                  const SizedBox(height: 8),
                  PrismButton(
                    label: s.image == null ? l10n.apUploadImage : l10n.apChangeImage,
                    onPressed: () async {
                      final f = await ImagePicker().pickImage(source: ImageSource.gallery);
                      if (f == null) return;
                      final name = await ref.read(appearanceProvider.notifier).addBackgroundImage(await f.readAsBytes());
                      if (name == null) {
                        if (context.mounted) PrismToast.error(context, message: l10n.apImageFailed);
                        return;
                      }
                      onChanged(s.copyWith(image: name));
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(l10n.apImageHelp, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
                if (hasImageControls || s.kind == BgKind.gradient) ...[
                  const Divider(height: 24),
                  LabeledSlider(
                    label: l10n.apOpacity,
                    value: s.opacity,
                    min: 0.1,
                    max: 1,
                    divisions: 18,
                    format: (v) => '${(v * 100).round()}%',
                    onChanged: (v) => onChanged(s.copyWith(opacity: v)),
                  ),
                ],
                if (hasImageControls) ...[
                  LabeledSlider(
                    label: l10n.apBlur,
                    value: s.blur,
                    min: 0,
                    max: 30,
                    divisions: 30,
                    format: (v) => v.round().toString(),
                    onChanged: (v) => onChanged(s.copyWith(blur: v)),
                  ),
                  LabeledSlider(
                    label: l10n.apBrightness,
                    value: s.brightness,
                    min: -0.6,
                    max: 0.6,
                    divisions: 24,
                    format: (v) => '${v >= 0 ? '+' : ''}${(v * 100).round()}',
                    onChanged: (v) => onChanged(s.copyWith(brightness: v)),
                  ),
                  LabeledSlider(
                    label: l10n.apContrast,
                    value: s.contrast,
                    min: 0.4,
                    max: 1.8,
                    divisions: 28,
                    format: (v) => '${(v * 100).round()}%',
                    onChanged: (v) => onChanged(s.copyWith(contrast: v)),
                  ),
                  LabeledSlider(
                    label: l10n.apSaturation,
                    value: s.saturation,
                    min: 0,
                    max: 2,
                    divisions: 20,
                    format: (v) => '${(v * 100).round()}%',
                    onChanged: (v) => onChanged(s.copyWith(saturation: v)),
                  ),
                ],
                const Divider(height: 24),
                Text(l10n.apOverlay, style: theme.textTheme.labelLarge),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final o in BgOverlay.values)
                      PrismChip(
                        label: switch (o) {
                          BgOverlay.none => l10n.apOverlayNone,
                          BgOverlay.scrim => l10n.apOverlayScrim,
                          BgOverlay.vignette => l10n.apOverlayVignette,
                          BgOverlay.glow => l10n.apOverlayGlow,
                        },
                        selected: s.overlay == o,
                        onTap: () => onChanged(s.copyWith(overlay: o)),
                      ),
                  ],
                ),
                if (s.overlay != BgOverlay.none) ...[
                  ColorChoiceRow(label: l10n.apOverlayColor, value: s.overlayColor, allowDefault: false, onChanged: (v) => onChanged(s.copyWith(overlayColor: v))),
                  LabeledSlider(
                    label: l10n.apOverlayStrength,
                    value: s.overlayStrength,
                    min: 0.05,
                    max: 0.9,
                    divisions: 17,
                    format: (v) => '${(v * 100).round()}%',
                    onChanged: (v) => onChanged(s.copyWith(overlayStrength: v)),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// Small icon button with a screen-reader label (no tooltip overlay).
class IconButtonLike extends StatelessWidget {
  const IconButtonLike({super.key, required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: InkResponse(onTap: onTap, radius: 22, child: Padding(padding: const EdgeInsets.all(10), child: Icon(icon))),
  );
}
