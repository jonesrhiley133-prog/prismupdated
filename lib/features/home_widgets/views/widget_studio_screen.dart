import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:prism_plurality/features/home_widgets/models/widget_catalog.dart';
import 'package:prism_plurality/features/home_widgets/models/widget_config.dart';
import 'package:prism_plurality/features/home_widgets/services/home_widget_controller.dart';
import 'package:prism_plurality/features/home_widgets/services/home_widget_data.dart';
import 'package:prism_plurality/features/home_widgets/services/home_widget_models.dart';
import 'package:prism_plurality/features/home_widgets/services/home_widget_store.dart';
import 'package:prism_plurality/features/home_widgets/views/widget_preview.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';
import 'package:prism_plurality/features/trackers/widgets/tracker_widgets.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';
import 'package:prism_plurality/shared/widgets/prism_color_picker_dialog.dart';
import 'package:prism_plurality/shared/widgets/prism_date_picker.dart';
import 'package:prism_plurality/shared/widgets/prism_loading_state.dart';
import 'package:prism_plurality/shared/widgets/prism_page_scaffold.dart';
import 'package:prism_plurality/shared/widgets/prism_segmented_control.dart';
import 'package:prism_plurality/shared/widgets/prism_surface.dart';
import 'package:prism_plurality/shared/widgets/prism_switch_row.dart';
import 'package:prism_plurality/shared/widgets/prism_text_field.dart';
import 'package:prism_plurality/shared/widgets/prism_toast.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar.dart';

const _swatches = [
  0xFF7E57C2, 0xFF5C6BC0, 0xFF29B6F6, 0xFF26A69A, 0xFF66BB6A, 0xFFFFCA28,
  0xFFFF7043, 0xFFEC407A, 0xFF000000, 0xFF263238, 0xFFFFFFFF, 0xFFFBF7F1,
];

/// Shrinks (and optionally blurs) a picked photo for use behind a widget.
Future<String?> prepareWidgetImage(List<int> bytes, {double blur = 0}) async {
  try {
    final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes), targetWidth: 360);
    final frame = await codec.getNextFrame();
    final w = frame.image.width, h = frame.image.height;
    final rec = ui.PictureRecorder();
    final paint = Paint()..filterQuality = FilterQuality.medium;
    if (blur > 0) paint.imageFilter = ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur, tileMode: TileMode.clamp);
    Canvas(rec).drawImage(frame.image, Offset.zero, paint);
    final img = await rec.endRecording().toImage(w, h);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data == null ? null : base64Encode(data.buffer.asUint8List());
  } catch (_) {
    return null;
  }
}

/// Per-widget customization with a live preview. With [widgetId] it edits
/// one placed widget; without, the starting look for new widgets of [type].
class WidgetStudioScreen extends ConsumerStatefulWidget {
  const WidgetStudioScreen({super.key, required this.type, this.widgetId});

  final String type;
  final int? widgetId;

  @override
  ConsumerState<WidgetStudioScreen> createState() => _WidgetStudioScreenState();
}

class _WidgetStudioScreenState extends ConsumerState<WidgetStudioScreen> {
  String _size = 'medium';
  bool? _previewDark;
  List<int>? _pickedImage;
  double _blur = 0;
  final _presetName = TextEditingController();

  @override
  void dispose() {
    _presetName.dispose();
    super.dispose();
  }

  Future<void> _save(WidgetConfig cfg) {
    final n = ref.read(homeWidgetsProvider.notifier);
    return widget.widgetId == null ? n.saveDefault(cfg) : n.saveConfig(widget.widgetId!, cfg);
  }

  Future<void> _applyImage(WidgetConfig cfg) async {
    final bytes = _pickedImage;
    if (bytes == null) return;
    final img = await prepareWidgetImage(bytes, blur: _blur);
    if (img != null) await _save(cfg.copyWith(style: cfg.style.copyWith(bgImage: img)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final async = ref.watch(homeWidgetsProvider);
    final data = ref.watch(homeWidgetDataProvider);
    return PrismPageScaffold(
      topBar: PrismTopBar(title: widgetTypeLabel(l10n, widget.type), showBackButton: true),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: async.when(
        loading: () => const PrismLoadingState(),
        error: (e, _) => Center(child: Text(l10n.errorWithDetail(e))),
        data: (state) {
          final cfg = state.configFor(widget.widgetId, widget.type);
          final s = cfg.style;
          void style(WidgetStyle next) => _save(cfg.copyWith(style: next));
          void privacy(WidgetPrivacy next) => _save(cfg.copyWith(privacy: next));
          final dark = _previewDark ?? theme.brightness == Brightness.dark;
          final model = data == null ? null : buildWidgetModel(cfg, data, l10n, l10n.localeName);
          final presets = [for (final p in state.presets) if (p.type == widget.type) p];

          Widget slider(String label, double value, double min, double max, ValueChanged<double> onChanged, {int? divisions, String Function(double)? fmt}) =>
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text('$label · ${fmt?.call(value) ?? value.round()}', style: theme.textTheme.labelLarge),
                  ),
                  Slider(value: value.clamp(min, max), min: min, max: max, divisions: divisions, onChanged: onChanged),
                ],
              );

          final children = <Widget>[
            // ---- preview
            PrismSurface(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: dark ? const [Color(0xFF1B2735), Color(0xFF090A0F)] : const [Color(0xFF9BC5F0), Color(0xFFE8C7E8)],
                      ),
                    ),
                    alignment: Alignment.center,
                    child: model == null
                        ? const SizedBox(height: 156, child: PrismLoadingState())
                        : FittedBox(
                            fit: BoxFit.scaleDown,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: WidgetPreview(key: ValueKey(_size), model: model, config: cfg, data: data, size: _size, dark: dark),
                            ),
                          ),
                  ),
                  const SizedBox(height: 10),
                  PrismSegmentedControl<String>(
                    segments: [
                      PrismSegment(value: 'small', label: l10n.hwSizeSmall),
                      PrismSegment(value: 'medium', label: l10n.hwSizeMedium),
                      PrismSegment(value: 'large', label: l10n.hwSizeLarge),
                    ],
                    selected: _size,
                    onChanged: (v) => setState(() => _size = v),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.widgetId == null ? l10n.hwEditingDefault : l10n.hwEditingPlaced,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  if (widget.widgetId == null && ref.watch(homeWidgetPlatformProvider).isSupported) ...[
                    const SizedBox(height: 8),
                    PrismButton(
                      label: l10n.hwAddToHome,
                      tone: PrismButtonTone.filled,
                      onPressed: () async {
                        final ok = await ref.read(homeWidgetPlatformProvider).pin(widget.type);
                        if (!ok && context.mounted) PrismToast.show(context, message: l10n.hwPinUnsupported);
                      },
                    ),
                  ],
                ],
              ),
            ),

            // ---- theme
            TrackerLabel(l10n.hwTheme),
            PrismSegmentedControl<WidgetTheme>(
              segments: [
                PrismSegment(value: WidgetTheme.system, label: l10n.hwThemeSystem),
                PrismSegment(value: WidgetTheme.light, label: l10n.hwThemeLight),
                PrismSegment(value: WidgetTheme.dark, label: l10n.hwThemeDark),
                PrismSegment(value: WidgetTheme.amoled, label: l10n.hwThemeAmoled),
              ],
              selected: s.theme,
              onChanged: (v) => style(s.copyWith(theme: v)),
            ),
            if (s.theme == WidgetTheme.system)
              PrismSwitchRow(
                title: l10n.hwPreviewDark,
                value: dark,
                onChanged: (v) => setState(() => _previewDark = v),
              ),

            // ---- colours
            TrackerLabel(
              l10n.hwColors,
              trailing: PrismButton(
                label: l10n.hwResetColors,
                density: PrismControlDensity.compact,
                onPressed: () => style(s.copyWith(clearColors: true, clearBorderColor: true)),
              ),
            ),
            PrismSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ColorRow(label: l10n.hwBackground, value: s.bg1, onChanged: (v) => style(_withColors(s, bg1: v, clearBg1: v == null))),
                  _ColorRow(label: l10n.hwGradientEnd, value: s.bg2, onChanged: (v) => style(_withColors(s, bg2: v, clearBg2: v == null))),
                  _ColorRow(label: l10n.hwTextColor, value: s.textColor, onChanged: (v) => style(_withColors(s, text: v, clearText: v == null))),
                  _ColorRow(label: l10n.hwAccentColor, value: s.accentColor, onChanged: (v) => style(_withColors(s, accent: v, clearAccent: v == null))),
                  slider(l10n.hwGradientAngle, s.gradientAngle, 0, 360, (v) => style(s.copyWith(gradientAngle: v)), divisions: 24, fmt: (v) => '${v.round()}°'),
                ],
              ),
            ),

            // ---- shape & glass
            TrackerLabel(l10n.hwShape),
            PrismSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  slider(l10n.hwOpacity, s.opacity, 0, 1, (v) => style(s.copyWith(opacity: v)), divisions: 20, fmt: (v) => '${(v * 100).round()}%'),
                  Text(l10n.hwOpacityHelp, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  slider(l10n.hwCorners, s.radius, 0, 40, (v) => style(s.copyWith(radius: v)), divisions: 20),
                  slider(l10n.hwBorder, s.borderWidth, 0, 6, (v) => style(s.copyWith(borderWidth: v)), divisions: 12, fmt: (v) => v.toStringAsFixed(1)),
                  if (s.borderWidth > 0)
                    _ColorRow(
                      label: l10n.hwBorderColor,
                      value: s.borderColor,
                      onChanged: (v) => style(v == null ? s.copyWith(clearBorderColor: true) : s.copyWith(borderColor: v)),
                    ),
                ],
              ),
            ),

            // ---- background image
            TrackerLabel(l10n.hwBgImage),
            PrismSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      PrismButton(
                        label: s.bgImage == null ? l10n.hwChooseImage : l10n.hwChangeImage,
                        onPressed: () async {
                          final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1080);
                          if (file == null) return;
                          _pickedImage = await file.readAsBytes();
                          await _applyImage(cfg);
                        },
                      ),
                      if (s.bgImage != null)
                        PrismButton(
                          label: l10n.hwRemoveImage,
                          tone: PrismButtonTone.destructive,
                          onPressed: () {
                            _pickedImage = null;
                            style(s.copyWith(clearImage: true));
                          },
                        ),
                    ],
                  ),
                  if (s.bgImage != null) ...[
                    if (_pickedImage != null)
                      slider(l10n.hwBlur, _blur, 0, 24, (v) => setState(() => _blur = v), divisions: 12),
                    if (_pickedImage != null)
                      PrismButton(label: l10n.hwApplyBlur, density: PrismControlDensity.compact, onPressed: () => _applyImage(cfg)),
                    slider(l10n.hwImageDim, s.imageDim, 0, 1, (v) => style(s.copyWith(imageDim: v)), divisions: 20, fmt: (v) => '${(v * 100).round()}%'),
                  ],
                ],
              ),
            ),

            // ---- text & layout
            TrackerLabel(l10n.hwTextLayout),
            PrismSegmentedControl<WidgetFont>(
              segments: [
                PrismSegment(value: WidgetFont.sans, label: l10n.hwFontSans),
                PrismSegment(value: WidgetFont.serif, label: l10n.hwFontSerif),
                PrismSegment(value: WidgetFont.mono, label: l10n.hwFontMono),
                PrismSegment(value: WidgetFont.condensed, label: l10n.hwFontCondensed),
              ],
              selected: s.font,
              onChanged: (v) => style(s.copyWith(font: v)),
            ),
            PrismSurface(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  slider(l10n.hwTextSize, s.textScale, 0.7, 1.6, (v) => style(s.copyWith(textScale: v)), divisions: 9, fmt: (v) => '${(v * 100).round()}%'),
                  PrismSwitchRow(title: l10n.hwCompact, subtitle: l10n.hwCompactHelp, value: s.compact, onChanged: (v) => style(s.copyWith(compact: v))),
                  PrismSwitchRow(title: l10n.hwCentered, value: s.centered, onChanged: (v) => style(s.copyWith(centered: v))),
                  PrismSwitchRow(title: l10n.hwShowRefresh, value: s.showRefresh, onChanged: (v) => style(s.copyWith(showRefresh: v))),
                  PrismSwitchRow(title: l10n.hwShowAvatars, subtitle: l10n.hwShowAvatarsHelp, value: s.showAvatars, onChanged: (v) => style(s.copyWith(showAvatars: v))),
                ],
              ),
            ),
            if (s.showAvatars) ...[
              TrackerLabel(l10n.hwAvatarShape),
              PrismSegmentedControl<AvatarShape>(
                segments: [
                  PrismSegment(value: AvatarShape.circle, label: l10n.hwShapeCircle),
                  PrismSegment(value: AvatarShape.rounded, label: l10n.hwShapeRounded),
                  PrismSegment(value: AvatarShape.square, label: l10n.hwShapeSquare),
                ],
                selected: s.avatarShape,
                onChanged: (v) => style(s.copyWith(avatarShape: v)),
              ),
            ],

            // ---- content options
            ..._options(context, cfg, data),

            // ---- privacy
            TrackerLabel(l10n.hwPrivacy),
            PrismSurface(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  PrismSwitchRow(
                    title: l10n.hwHideSensitive,
                    subtitle: l10n.hwHideSensitiveHelp,
                    value: cfg.privacy.hideSensitive,
                    onChanged: (v) => privacy(cfg.privacy.copyWith(hideSensitive: v)),
                  ),
                  PrismSwitchRow(
                    title: l10n.hwHideNames,
                    subtitle: l10n.hwHideNamesHelp,
                    value: cfg.privacy.hideNames,
                    onChanged: (v) => privacy(cfg.privacy.copyWith(hideNames: v)),
                  ),
                  PrismSwitchRow(
                    title: l10n.hwMaskNumbers,
                    subtitle: l10n.hwMaskNumbersHelp,
                    value: cfg.privacy.maskNumbers,
                    onChanged: (v) => privacy(cfg.privacy.copyWith(maskNumbers: v)),
                  ),
                ],
              ),
            ),

            // ---- presets
            TrackerLabel(l10n.hwPresets),
            PrismSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: PrismTextField(controller: _presetName, labelText: l10n.hwPresetName)),
                      const SizedBox(width: 8),
                      PrismButton(
                        label: l10n.save,
                        onPressed: () async {
                          final name = _presetName.text.trim();
                          if (name.isEmpty) return;
                          await ref.read(homeWidgetsProvider.notifier).savePreset(cfg.copyWith(name: name));
                          _presetName.clear();
                          if (context.mounted) PrismToast.success(context, message: l10n.hwPresetSaved);
                        },
                      ),
                    ],
                  ),
                  if (presets.isNotEmpty) const SizedBox(height: 10),
                  for (final p in presets)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Expanded(child: Text(p.name, style: theme.textTheme.bodyLarge)),
                          PrismButton(label: l10n.hwApply, density: PrismControlDensity.compact, onPressed: () => _save(p.copyWith(name: cfg.name))),
                          const SizedBox(width: 6),
                          PrismButton(
                            label: l10n.delete,
                            density: PrismControlDensity.compact,
                            tone: PrismButtonTone.destructive,
                            onPressed: () => ref.read(homeWidgetsProvider.notifier).deletePreset(p),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            PrismButton(
              label: l10n.hwResetDefault,
              tone: PrismButtonTone.outlined,
              expanded: true,
              onPressed: () {
                _pickedImage = null;
                ref.read(homeWidgetsProvider.notifier).resetConfig(widget.widgetId, widget.type);
              },
            ),
            const SizedBox(height: 32),
          ];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: PrismTokens.contentMaxWidth),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  WidgetStyle _withColors(
    WidgetStyle s, {
    int? bg1,
    int? bg2,
    int? text,
    int? accent,
    bool clearBg1 = false,
    bool clearBg2 = false,
    bool clearText = false,
    bool clearAccent = false,
  }) {
    // copyWith cannot null a single colour, so rebuild from JSON.
    final j = Map<String, dynamic>.of(s.toJson());
    if (bg1 != null || clearBg1) j['bg1'] = bg1;
    if (bg2 != null || clearBg2) j['bg2'] = bg2;
    if (text != null || clearText) j['textColor'] = text;
    if (accent != null || clearAccent) j['accentColor'] = accent;
    return WidgetStyle.fromJson(j);
  }

  List<Widget> _options(BuildContext context, WidgetConfig cfg, HomeWidgetData? data) {
    final l10n = context.l10n;
    if (data == null) return const [];

    Widget multi(String title, String key, List<({String id, String label})> items, String allLabel) {
      final sel = cfg.stringList(key);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TrackerLabel(title),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              PrismChip(label: allLabel, selected: sel.isEmpty, onTap: () => _save(cfg.withOption(key, null))),
              for (final i in items)
                PrismChip(
                  label: i.label,
                  selected: sel.contains(i.id),
                  onTap: () {
                    final next = sel.contains(i.id) ? (sel.toList()..remove(i.id)) : [...sel, i.id];
                    _save(cfg.withOption(key, next.isEmpty ? null : next));
                  },
                ),
            ],
          ),
        ],
      );
    }

    Widget days(String key, int fallback, List<int> choices) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TrackerLabel(l10n.hwTimeRange),
        PrismSegmentedControl<int>(
          segments: [for (final d in choices) PrismSegment(value: d, label: l10n.hwLastDays(d))],
          selected: choices.contains(cfg.intOption(key, fallback)) ? cfg.intOption(key, fallback) : fallback,
          onChanged: (v) => _save(cfg.withOption(key, v)),
        ),
      ],
    );

    Widget toggle(String title, String key, bool fallback) => PrismSwitchRow(
      title: title,
      value: cfg.boolOption(key, fallback),
      onChanged: (v) => _save(cfg.withOption(key, v)),
    );

    switch (cfg.type) {
      case 'quick_front':
        return [
          multi(l10n.hwOptMembers, 'memberIds', [
            for (final m in data.members.values)
              if (m.isActive) (id: m.id, label: '${m.emoji == '❔' ? '' : '${m.emoji} '}${m.name}'),
          ], l10n.hwOptAuto),
        ];
      case 'events':
        return [days('days', 14, const [7, 14, 30])];
      case 'stats':
        return [days('days', 7, const [7, 14, 30])];
      case 'todo':
        return [
          TrackerLabel(l10n.hwContent),
          toggle(l10n.hwOptShowDone, 'showDone', false),
          toggle(l10n.hwOptAssignments, 'includeAssignments', true),
        ];
      case 'headspace':
        final maps = data.kind(TrackerKind.headspaceMap);
        return [
          TrackerLabel(l10n.hwOptMap),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final m in maps)
                PrismChip(
                  label: m.title,
                  selected: (cfg.stringOption('mapId') ?? maps.first.id) == m.id,
                  onTap: () => _save(cfg.withOption('mapId', m.id)),
                ),
            ],
          ),
        ];
      case 'notes':
        return [
          multi(l10n.hwOptNotes, 'noteIds', [
            for (final n in data.notes.take(30)) (id: n.id, label: n.title.isEmpty ? l10n.journalUntitled : n.title),
          ], l10n.hwOptRecent),
        ];
      case 'subsystems':
        return [
          multi(l10n.navSubsystems, 'subsystemIds', [
            for (final x in data.kind(TrackerKind.subsystem)) (id: x.id, label: x.title),
          ], l10n.hwOptAll),
        ];
      case 'relationships':
        return [
          multi(l10n.navRelationships, 'relationshipIds', [
            for (final r in data.kind(TrackerKind.relationship))
              (id: r.id, label: '${data.members[r.memberId]?.name ?? '?'} ↔ ${data.members[r.str('otherId')]?.name ?? r.str('otherName') ?? '?'}'),
          ], l10n.hwOptAll),
        ];
      case 'countdown':
        final custom = [
          for (final x in cfg.options['countdowns'] as List? ?? const [])
            if (x is Map) Map<String, Object?>.from(x),
        ];
        return [
          TrackerLabel(l10n.hwContent),
          toggle(l10n.hwOptBirthdays, 'birthdays', true),
          toggle(l10n.hwOptEvents, 'events', true),
          TrackerLabel(l10n.hwOptCustomCountdowns),
          for (var i = 0; i < custom.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${custom[i]['title']} · ${MaterialLocalizations.of(context).formatMediumDate(DateTime.fromMillisecondsSinceEpoch(custom[i]['date'] as int? ?? 0))}',
                    ),
                  ),
                  PrismButton(
                    label: l10n.delete,
                    density: PrismControlDensity.compact,
                    tone: PrismButtonTone.destructive,
                    onPressed: () => _save(cfg.withOption('countdowns', [...custom]..removeAt(i))),
                  ),
                ],
              ),
            ),
          _CountdownAdder(onAdd: (title, date) => _save(cfg.withOption('countdowns', [...custom, {'title': title, 'date': date.millisecondsSinceEpoch}]))),
        ];
      default:
        return const [];
    }
  }
}

class _CountdownAdder extends StatefulWidget {
  const _CountdownAdder({required this.onAdd});

  final void Function(String title, DateTime date) onAdd;

  @override
  State<_CountdownAdder> createState() => _CountdownAdderState();
}

class _CountdownAdderState extends State<_CountdownAdder> {
  final _title = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(child: PrismTextField(controller: _title, labelText: l10n.hwCountdownTitle)),
        const SizedBox(width: 8),
        Builder(
          builder: (anchor) => PrismButton(
            label: l10n.hwPickDate,
            onPressed: () async {
              final title = _title.text.trim();
              if (title.isEmpty) return;
              final now = DateTime.now();
              final date = await showPrismDatePicker(
                context: context,
                anchorContext: anchor,
                initialDate: now.add(const Duration(days: 7)),
                firstDate: now,
                lastDate: DateTime(now.year + 20),
              );
              if (date == null) return;
              widget.onAdd(title, date);
              _title.clear();
            },
          ),
        ),
      ],
    );
  }
}

class _ColorRow extends StatelessWidget {
  const _ColorRow({required this.label, required this.value, required this.onChanged});

  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PrismChip(label: l10n.fnColorAuto, selected: value == null, onTap: () => onChanged(null)),
              for (final c in _swatches)
                InkResponse(
                  onTap: () => onChanged(c),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: Border.all(width: value == c ? 3 : 1, color: theme.colorScheme.outline),
                    ),
                  ),
                ),
              PrismButton(
                label: l10n.fnColorCustom,
                density: PrismControlDensity.compact,
                onPressed: () async {
                  final hex = await showPrismColorPickerDialog(context: context, initialColor: Color(value ?? 0xFF7E57C2));
                  if (hex == null) return;
                  final raw = hex.replaceFirst('#', '');
                  final v = int.tryParse(raw, radix: 16);
                  if (v != null) onChanged(raw.length <= 6 ? 0xFF000000 | v : v);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
