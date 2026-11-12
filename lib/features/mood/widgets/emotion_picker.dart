import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/features/mood/data/emotion_library.dart';
import 'package:prism_plurality/features/mood/providers/emotion_providers.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';
import 'package:prism_plurality/shared/widgets/prism_select.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_text_field.dart';

/// Selected emotions: key → optional per-emotion intensity (1–10).
typedef EmotionSelection = Map<String, int?>;

EmotionSelection decodeEmotionSelection(Iterable<String> stored) => {
  for (final raw in stored)
    parseEmotionEntry(raw).$1: parseEmotionEntry(raw).$2,
};

List<String> encodeEmotionSelection(EmotionSelection s) => [
  for (final e in s.entries) encodeEmotionEntry(e.key, e.value),
];

const _tabFavorites = '__favorites';
const _tabRecent = '__recent';
const _tabAll = '__all';
const _tabCustom = '__custom';

/// Full emotion picker: search, favourites, recently used, All, categories,
/// custom emotions, and per-emotion intensity. Reusable anywhere emotions
/// are logged.
class EmotionPicker extends ConsumerStatefulWidget {
  const EmotionPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final EmotionSelection selected;
  final ValueChanged<EmotionSelection> onChanged;

  @override
  ConsumerState<EmotionPicker> createState() => _EmotionPickerState();
}

class _EmotionPickerState extends ConsumerState<EmotionPicker> {
  final _search = TextEditingController();
  String? _tab;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggle(String key) {
    final next = {...widget.selected};
    if (next.containsKey(key)) {
      next.remove(key);
    } else {
      next[key] = null;
    }
    widget.onChanged(next);
  }

  Future<void> _editSelected(String key) async {
    final result = await PrismSheet.show<_IntensityResult>(
      context: context,
      title: emotionLabel(key),
      builder: (context) =>
          _IntensitySheet(emotionKey: key, initial: widget.selected[key]),
    );
    if (result == null || !mounted) return;
    final next = {...widget.selected};
    if (result.remove) {
      next.remove(key);
    } else {
      next[key] = result.intensity;
    }
    widget.onChanged(next);
  }

  Future<void> _addCustom() async {
    final created = await PrismSheet.show<String>(
      context: context,
      title: context.l10n.emotionsAddCustom,
      builder: (context) => const _CustomEmotionSheet(),
    );
    if (created != null && mounted) {
      widget.onChanged({...widget.selected, created: null});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final favorites = ref.watch(favoriteEmotionsProvider).value ?? const [];
    final custom = ref.watch(customEmotionsProvider).value ?? const [];
    final recent = ref.watch(recentEmotionsProvider);
    final tab = _tab ?? (favorites.isNotEmpty ? _tabFavorites : _tabAll);
    final query = _search.text.trim().toLowerCase();

    // All selectable emotions: built-in + custom.
    final all = <(String key, String label, Color? color)>[
      for (final (e, c) in allBuiltInEmotions) (e.key, e.label, c.color),
      for (final c in custom)
        (c.key, c.label, emotionColor(c.categoryKey ?? '')),
    ];
    final byKey = {for (final e in all) e.$1: e};

    List<(String, String, Color?)> visible;
    if (query.isNotEmpty) {
      visible = all.where((e) => e.$2.toLowerCase().contains(query)).toList();
    } else {
      visible = switch (tab) {
        _tabFavorites => [
          for (final k in favorites) byKey[k] ?? (k, emotionLabel(k), null),
        ],
        _tabRecent => [
          for (final k in recent) byKey[k] ?? (k, emotionLabel(k), null),
        ],
        _tabCustom => [for (final c in custom) byKey[c.key]!],
        _tabAll => all,
        _ => [
          for (final c in emotionLibrary.where((c) => c.key == tab))
            for (final e in c.emotions) (e.key, e.label, c.color),
          for (final c in custom.where((c) => c.categoryKey == tab))
            byKey[c.key]!,
        ],
      };
    }

    final tabs = <(String, String)>[
      (_tabFavorites, l10n.emotionsTabFavorites),
      (_tabRecent, l10n.emotionsTabRecent),
      (_tabAll, l10n.emotionsTabAll(all.length)),
      for (final c in emotionLibrary) (c.key, c.label),
      if (custom.isNotEmpty) (_tabCustom, l10n.emotionsTabCustom),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.selected.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in widget.selected.entries)
                Semantics(
                  hint: l10n.emotionsTapToSetIntensity,
                  child: PrismChip(
                    label: e.value == null
                        ? emotionLabel(e.key)
                        : '${emotionLabel(e.key)} · ${e.value}',
                    selected: true,
                    selectedColor: emotionColor(e.key),
                    avatar: favorites.contains(e.key)
                        ? Icon(AppIcons.star, size: 12, color: Colors.amber)
                        : null,
                    onTap: () => _editSelected(e.key),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.emotionsTapToSetIntensity,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
        ],
        PrismTextField(
          controller: _search,
          labelText: l10n.emotionsSearch,
          prefixIcon: Icon(AppIcons.search),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        if (query.isEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (key, label) in tabs)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: PrismChip(
                      label: label,
                      selected: tab == key,
                      onTap: () => setState(() => _tab = key),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              query.isNotEmpty
                  ? l10n.emotionsNoMatch
                  : tab == _tabFavorites
                  ? l10n.emotionsNoFavorites
                  : l10n.emotionsNoRecent,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (key, label, color) in visible)
                GestureDetector(
                  onLongPress: () => ref
                      .read(emotionPrefsNotifierProvider.notifier)
                      .toggleFavorite(key),
                  child: PrismChip(
                    label: label,
                    selected: widget.selected.containsKey(key),
                    selectedColor: color,
                    avatar: favorites.contains(key)
                        ? Icon(AppIcons.star, size: 12, color: Colors.amber)
                        : null,
                    onTap: () => _toggle(key),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.emotionsLongPressFavorite,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            PrismButton(
              label: l10n.emotionsAddCustom,
              icon: AppIcons.add,
              density: PrismControlDensity.compact,
              onPressed: _addCustom,
            ),
          ],
        ),
      ],
    );
  }
}

class _IntensityResult {
  const _IntensityResult({this.intensity, this.remove = false});
  final int? intensity;
  final bool remove;
}

class _IntensitySheet extends ConsumerStatefulWidget {
  const _IntensitySheet({required this.emotionKey, required this.initial});

  final String emotionKey;
  final int? initial;

  @override
  ConsumerState<_IntensitySheet> createState() => _IntensitySheetState();
}

class _IntensitySheetState extends ConsumerState<_IntensitySheet> {
  late int? _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final favorites = ref.watch(favoriteEmotionsProvider).value ?? const [];
    final isFav = favorites.contains(widget.emotionKey);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(l10n.moodIntensityLabel)),
              Text(
                _value == null ? l10n.emotionsNoIntensity : '$_value / 10',
                style: theme.textTheme.labelLarge,
              ),
            ],
          ),
          Slider(
            value: (_value ?? 5).toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            label: '${_value ?? 5}',
            onChanged: (v) => setState(() => _value = v.round()),
          ),
          if (_value != null)
            PrismButton(
              label: l10n.emotionsClearIntensity,
              density: PrismControlDensity.compact,
              onPressed: () => setState(() => _value = null),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PrismButton(
                label: isFav ? l10n.emotionsUnfavorite : l10n.emotionsFavorite,
                icon: AppIcons.star,
                density: PrismControlDensity.compact,
                onPressed: () => ref
                    .read(emotionPrefsNotifierProvider.notifier)
                    .toggleFavorite(widget.emotionKey),
              ),
              PrismButton(
                label: l10n.emotionsRemove,
                tone: PrismButtonTone.destructive,
                density: PrismControlDensity.compact,
                onPressed: () => Navigator.of(
                  context,
                ).pop(const _IntensityResult(remove: true)),
              ),
              PrismButton(
                label: l10n.done,
                tone: PrismButtonTone.filled,
                density: PrismControlDensity.compact,
                onPressed: () => Navigator.of(
                  context,
                ).pop(_IntensityResult(intensity: _value)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CustomEmotionSheet extends ConsumerStatefulWidget {
  const _CustomEmotionSheet();

  @override
  ConsumerState<_CustomEmotionSheet> createState() =>
      _CustomEmotionSheetState();
}

class _CustomEmotionSheetState extends ConsumerState<_CustomEmotionSheet> {
  final _label = TextEditingController();
  String? _category;
  String? _error;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final created = await ref
        .read(emotionPrefsNotifierProvider.notifier)
        .addCustom(_label.text, categoryKey: _category);
    if (!mounted) return;
    if (created == null) {
      setState(() => _error = context.l10n.emotionsCustomExists);
      return;
    }
    Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PrismTextField(
            controller: _label,
            labelText: l10n.emotionsCustomLabel,
            autofocus: true,
            onChanged: (_) => setState(() => _error = null),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Text(l10n.emotionsCustomCategory)),
              PrismSelect<String>.compact(
                value: _category,
                menuWidth: 220,
                items: [
                  for (final c in emotionLibrary)
                    PrismSelectItem(value: c.key, label: c.label),
                ],
                onChanged: (v) => setState(() => _category = v),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: PrismButton(
              label: l10n.save,
              tone: PrismButtonTone.filled,
              enabled: _label.text.trim().isNotEmpty,
              onPressed: _save,
            ),
          ),
        ],
      ),
    );
  }
}
