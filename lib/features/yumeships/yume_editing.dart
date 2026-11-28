import 'package:prism_plurality/features/appearance/models/look.dart'
    show BgSpec, BgKind;
import 'package:prism_plurality/features/appearance/views/look_editor_screen.dart'
    show BackgroundEditor;
import 'package:prism_plurality/features/experiences/color_sheet.dart';
import 'package:prism_plurality/features/seasonal/seasonal_catalog.dart'
    show livingCollections, variationById;
import 'package:prism_plurality/features/yumeships/yume_data.dart';
import 'package:prism_plurality/features/yumeships/yume_widgets.dart';
import 'package:prism_plurality/shared/fonts/font_browser.dart';
import 'package:prism_plurality/shared/fonts/font_catalog.dart'
    show fontByFamily;
import 'package:prism_plurality/shared/media/prism_media.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import 'package:prism_plurality/shared/utils/prism_image_picker.dart';
import 'package:prism_plurality/shared/widgets/prism_emoji_picker.dart';

/// Pick, re-crop or remove one picture — always with Prism's shared cropper.
class YumeImageField extends ConsumerWidget {
  const YumeImageField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.spec = PrismCropSpec.square,
    this.round = false,
  });
  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;
  final PrismCropSpec spec;
  final bool round;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final wide = (spec.aspect ?? 1) > 1.5;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: wide ? 120 : 64,
            height: 64,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              shape: round ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: round ? null : BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: value == null
                ? Icon(
                    Icons.image_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                  )
                : YumeMediaImage(id: value!),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelLarge),
                Wrap(
                  spacing: 4,
                  children: [
                    YumeAction(
                      label: value == null
                          ? tr(context, 'Choose', 'Elegir')
                          : tr(context, 'Replace', 'Cambiar'),
                      onPressed: () async {
                        final id = await PrismMedia.pickImage(ref, spec: spec);
                        if (id != null) onChanged(id);
                      },
                    ),
                    if (value != null)
                      YumeAction(
                        label: tr(context, 'Crop', 'Recortar'),
                        onPressed: () async {
                          final id = await PrismMedia.recropImage(
                            ref,
                            value!,
                            spec: spec,
                          );
                          if (id != null) onChanged(id);
                        },
                      ),
                    if (value != null)
                      YumeAction(
                        label: tr(context, 'Remove', 'Quitar'),
                        onPressed: () => onChanged(null),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Edits a list of [YumeEntry] (custom fields, dates, AUs, headcanons...).
class YumeEntryListEditor extends ConsumerWidget {
  const YumeEntryListEditor({
    super.key,
    required this.label,
    required this.entries,
    required this.onChanged,
    this.titleLabel = 'Title',
    this.textLabel = 'Notes',
    this.showTitle = true,
    this.showText = true,
    this.showDate = false,
    this.showMedia = false,
    this.showLink = false,
    this.addLabel,
    this.multiline = true,
  });
  final String label, titleLabel, textLabel;
  final String? addLabel;
  final List<YumeEntry> entries;
  final ValueChanged<List<YumeEntry>> onChanged;
  final bool showTitle, showText, showDate, showMedia, showLink, multiline;

  void _set(int i, YumeEntry e) {
    final next = [...entries];
    next[i] = e;
    onChanged(next);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TrackerLabel(label),
        for (var i = 0; i < entries.length; i++)
          Padding(
            key: ValueKey(entries[i].id),
            padding: const EdgeInsets.only(bottom: 8),
            child: PrismSurface(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showTitle)
                          PrismTextField(
                            initialValue: entries[i].title,
                            labelText: titleLabel,
                            onChanged: (v) =>
                                _set(i, entries[i].copyWith(title: v)),
                          ),
                        if (showText) ...[
                          const SizedBox(height: 6),
                          PrismTextField(
                            initialValue: entries[i].text,
                            labelText: textLabel,
                            minLines: multiline ? 2 : 1,
                            maxLines: multiline ? 8 : 1,
                            onChanged: (v) =>
                                _set(i, entries[i].copyWith(text: v)),
                          ),
                        ],
                        if (showLink) ...[
                          const SizedBox(height: 6),
                          PrismTextField(
                            initialValue: entries[i].link,
                            labelText: tr(context, 'Link', 'Enlace'),
                            keyboardType: TextInputType.url,
                            onChanged: (v) =>
                                _set(i, entries[i].copyWith(link: v)),
                          ),
                        ],
                        if (showDate)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: YumeAction(
                              label: entries[i].date == null
                                  ? tr(context, 'Add a date', 'Añadir fecha')
                                  : yumeDate(entries[i].date!),
                              icon: Icons.event_outlined,
                              onPressed: () async {
                                final d = await showPrismDatePicker(
                                  context: context,
                                  initialDate:
                                      entries[i].date ?? DateTime.now(),
                                  firstDate: DateTime(1900),
                                  lastDate: DateTime(2200),
                                );
                                if (d != null)
                                  _set(i, entries[i].copyWith(date: d));
                              },
                            ),
                          ),
                        if (showMedia)
                          YumeImageField(
                            label: tr(context, 'Picture', 'Imagen'),
                            value: entries[i].media,
                            spec: PrismCropSpec.free,
                            onChanged: (v) => _set(
                              i,
                              v == null
                                  ? entries[i].copyWith(clearMedia: true)
                                  : entries[i].copyWith(media: v),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      IconButton(
                        tooltip: tr(context, 'Remove', 'Quitar'),
                        icon: const Icon(Icons.close),
                        onPressed: () => onChanged([...entries]..removeAt(i)),
                      ),
                      if (i > 0)
                        IconButton(
                          tooltip: tr(context, 'Move up', 'Subir'),
                          icon: const Icon(Icons.arrow_upward, size: 18),
                          onPressed: () {
                            final next = [...entries];
                            next.insert(i - 1, next.removeAt(i));
                            onChanged(next);
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: YumeAction(
            label: addLabel ?? tr(context, 'Add', 'Añadir'),
            icon: Icons.add,
            onPressed: () => onChanged([...entries, YumeEntry(id: yumeId())]),
          ),
        ),
      ],
    );
  }
}

/// Look settings shared by ships and sonas. Works on a field draft map.
class YumeLookEditor extends ConsumerWidget {
  const YumeLookEditor({
    super.key,
    required this.draft,
    required this.onChanged,
    this.showLayout = false,
  });
  final Map<String, Object?> draft;
  final ValueChanged<Map<String, Object?>> onChanged;
  final bool showLayout;

  void _set(Map<String, Object?> c) => onChanged({...draft, ...c});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final preset = yumePresetById(draft['theme'] as String?);
    final accent = (draft['accent'] as num?)?.toInt() ?? preset?.accent;
    final font = draft['font'] as String?;
    final fontLabel = font == null || font.isEmpty
        ? (preset?.font != null
              ? '${tr(context, 'From preset', 'Del estilo')}: ${preset!.font!.substring(2)}'
              : tr(context, 'App font', 'Fuente de la app'))
        : font == 'default'
        ? tr(context, 'App font', 'Fuente de la app')
        : (fontByFamily(
                font.startsWith('g:') ? font.substring(2) : font,
              )?.family ??
              font.replaceFirst(RegExp(r'^(g|imp):'), ''));
    final living = draft['living'] as String?;
    final bgRaw = draft['bg'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TrackerLabel(tr(context, 'Aesthetic preset', 'Estilo')),
        SizedBox(
          height: 92,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final p in yumePresets)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 112,
                    child: YumeCard(
                      accent: yumeAccent(context, p.accent),
                      card: p.card,
                      frame: draft['theme'] == p.id ? 'dotted' : 'none',
                      padding: const EdgeInsets.all(8),
                      onTap: () => _set({
                        'theme': p.id,
                        // A preset resets the parts it defines.
                        'accent': null,
                        'font': null,
                        'card': null,
                        'frame': null,
                        'ribbon': null,
                        'stickers': null,
                        'symbol': null,
                      }),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(p.symbol, style: const TextStyle(fontSize: 22)),
                          const SizedBox(height: 4),
                          Text(
                            p.name,
                            maxLines: 2,
                            textAlign: TextAlign.center,
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
        const SizedBox(height: 12),
        TrackerLabel(tr(context, 'Accent colour', 'Color de acento')),
        Row(
          children: [
            Expanded(
              child: ColorChoiceRow(
                value: accent,
                onChanged: (c) => _set({'accent': c}),
              ),
            ),
            IconButton(
              tooltip: tr(context, 'Custom colour', 'Color propio'),
              icon: const Icon(Icons.colorize_outlined),
              onPressed: () async {
                final c = await showPrismColorPicker(
                  context: context,
                  initial: yumeAccent(context, accent),
                );
                if (c != null) _set({'accent': c.toARGB32()});
              },
            ),
            IconButton(
              tooltip: tr(
                context,
                'Use the app colour',
                'Usar el color de la app',
              ),
              icon: const Icon(Icons.format_color_reset_outlined),
              onPressed: () => _set({'accent': null}),
            ),
          ],
        ),
        const SizedBox(height: 8),
        PrismListRow(
          padding: EdgeInsets.zero,
          title: Text(tr(context, 'Heading font', 'Fuente de títulos')),
          subtitle: Text(fontLabel),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            final pick = await showPrismFontBrowser(
              context,
              current: font,
              defaultLabel: tr(context, 'App font', 'Fuente de la app'),
            );
            if (pick != null) _set({'font': pick.key ?? 'default'});
          },
        ),
        PrismListRow(
          padding: EdgeInsets.zero,
          title: Text(tr(context, 'Symbol', 'Símbolo')),
          trailing: Text(
            '${draft['symbol'] ?? preset?.symbol ?? '♡'}',
            style: const TextStyle(fontSize: 22),
          ),
          onTap: () async {
            final e = await PrismEmojiPicker.showPicker(context);
            if (e != null) _set({'symbol': e});
          },
        ),
        const SizedBox(height: 8),
        PrismSelect<String>(
          labelText: tr(context, 'Card style', 'Estilo de tarjeta'),
          value: (draft['card'] as String?) ?? preset?.card ?? 'soft',
          items: [
            for (final e in yumeCardStyles.entries)
              PrismSelectItem(value: e.key, label: e.value),
          ],
          onChanged: (v) => _set({'card': v}),
        ),
        const SizedBox(height: 8),
        PrismSelect<String>(
          labelText: tr(context, 'Frame', 'Marco'),
          value: (draft['frame'] as String?) ?? preset?.frame ?? 'none',
          items: [
            for (final e in yumeFrames.entries)
              PrismSelectItem(value: e.key, label: e.value),
          ],
          onChanged: (v) => _set({'frame': v}),
        ),
        const SizedBox(height: 8),
        PrismSelect<String>(
          labelText: tr(context, 'Ribbon', 'Cinta'),
          value: (draft['ribbon'] as String?) ?? preset?.ribbon ?? 'none',
          items: [
            for (final e in yumeRibbons.entries)
              PrismSelectItem(
                value: e.key,
                label: '${e.value.$2} ${e.value.$1}'.trim(),
              ),
          ],
          onChanged: (v) => _set({'ribbon': v}),
        ),
        if (showLayout) ...[
          const SizedBox(height: 8),
          PrismSelect<String>(
            labelText: tr(context, 'Profile layout', 'Diseño del perfil'),
            value: (draft['layout'] as String?) ?? 'classic',
            items: [
              for (final e in yumeLayouts.entries)
                PrismSelectItem(value: e.key, label: e.value),
            ],
            onChanged: (v) => _set({'layout': v}),
          ),
        ],
        const SizedBox(height: 8),
        YumeStringListField(
          label: tr(context, 'Stickers', 'Pegatinas'),
          hint: tr(context, 'Add an emoji sticker', 'Añade una pegatina emoji'),
          values: draft['stickers'] is List
              ? [for (final s in draft['stickers'] as List) '$s']
              : (preset?.stickers ?? const []),
          suggestions: const [
            '💌',
            '🌹',
            '✨',
            '🌙',
            '🎀',
            '🥀',
            '🌼',
            '☁️',
            '💥',
            '🫧',
            '🕯️',
            '💕',
          ],
          onChanged: (v) => _set({'stickers': v}),
        ),
        const SizedBox(height: 12),
        PrismListRow(
          padding: EdgeInsets.zero,
          title: Text(tr(context, 'Page background', 'Fondo de la página')),
          subtitle: Text(
            bgRaw is Map
                ? tr(context, 'Custom background', 'Fondo propio')
                : tr(context, 'App background', 'Fondo de la app'),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            var spec = bgRaw is Map
                ? BgSpec.fromJson(bgRaw)
                : const BgSpec(kind: BgKind.theme);
            final keep = await PrismSheet.showFullScreen<bool>(
              context: context,
              builder: (ctx, scroll) => StatefulBuilder(
                builder: (ctx, set) => SafeArea(
                  child: Column(
                    children: [
                      PrismSheetTopBar(
                        title: tr(ctx, 'Page background', 'Fondo de la página'),
                        trailing: IconButton(
                          tooltip: tr(ctx, 'Done', 'Listo'),
                          icon: const Icon(Icons.check),
                          onPressed: () => Navigator.of(ctx).pop(true),
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          controller: scroll,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          children: [
                            BackgroundEditor(
                              spec: spec,
                              onChanged: (b) => set(() => spec = b),
                            ),
                            const SizedBox(height: 12),
                            PrismButton(
                              label: tr(
                                ctx,
                                'Use the app background',
                                'Usar el fondo de la app',
                              ),
                              expanded: true,
                              onPressed: () => Navigator.of(ctx).pop(false),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
            if (keep == null) return;
            _set({
              'bg': keep && spec.kind != BgKind.theme ? spec.toJson() : null,
            });
          },
        ),
        PrismListRow(
          padding: EdgeInsets.zero,
          title: Text(tr(context, 'Living decoration', 'Decoración viva')),
          subtitle: Text(
            living == null
                ? tr(context, 'None', 'Ninguna')
                : (variationById(living)?.name ?? living),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            final genre = await yumeChoose(
              context,
              title: tr(context, 'Living decoration', 'Decoración viva'),
              selected: living?.split('.').first,
              options: {
                '': tr(context, 'None', 'Ninguna'),
                for (final c in livingCollections) c.id: '${c.emoji} ${c.name}',
              },
            );
            if (genre == null || !context.mounted) return;
            if (genre.isEmpty) return _set({'living': null});
            final c = livingCollections.firstWhere((c) => c.id == genre);
            final look = await yumeChoose(
              context,
              title: c.name,
              selected: living,
              options: {for (final v in c.variations) v.id: v.name},
            );
            if (look != null) _set({'living': look});
          },
        ),
        if (living != null) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: YumeLivingBanner(lookId: living, height: 70),
          ),
        ],
      ],
    );
  }
}

/// Privacy settings shared by every kind of yumeship item.
class YumePrivacyEditor extends ConsumerWidget {
  const YumePrivacyEditor({
    super.key,
    required this.draft,
    required this.onChanged,
    this.collaborators = true,
  });
  final Map<String, Object?> draft;
  final ValueChanged<Map<String, Object?>> onChanged;
  final bool collaborators;

  List<String> _list(String k) => [
    for (final x in (draft[k] as List?) ?? const []) '$x',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vis = (draft['visibility'] as String?) ?? 'system';
    final owners = _list('owners');
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TrackerLabel(tr(context, 'Belongs to', 'Pertenece a')),
        YumeMemberChips(
          selected: owners,
          onChanged: (v) => onChanged({...draft, 'owners': v}),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text(
            owners.isEmpty
                ? tr(
                    context,
                    'No owner: it belongs to the whole system.',
                    'Sin dueño: pertenece a todo el sistema.',
                  )
                : tr(
                    context,
                    'Owners can always open and edit it.',
                    'Los dueños siempre pueden abrirlo y editarlo.',
                  ),
            style: theme.textTheme.bodySmall,
          ),
        ),
        if (collaborators) ...[
          TrackerLabel(
            tr(
              context,
              'Collaborators (can edit)',
              'Colaboradores (pueden editar)',
            ),
          ),
          YumeMemberChips(
            selected: _list('collab'),
            exclude: owners.toSet(),
            onChanged: (v) => onChanged({...draft, 'collab': v}),
          ),
          const SizedBox(height: 12),
        ],
        TrackerLabel(tr(context, 'Who can see it', 'Quién puede verlo')),
        for (final e in yumeVisibilities.entries)
          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            value: e.key,
            groupValue: vis,
            title: Text(tr(context, e.value.$1, e.value.$2)),
            subtitle: Text(e.value.$3),
            onChanged: (v) => onChanged({...draft, 'visibility': v}),
          ),
        if (vis == 'selective') ...[
          TrackerLabel(tr(context, 'Also visible to', 'También visible para')),
          YumeMemberChips(
            selected: _list('shared'),
            exclude: owners.toSet(),
            onChanged: (v) => onChanged({...draft, 'shared': v}),
          ),
        ],
        const SizedBox(height: 8),
        PrismSwitchRow(
          padding: EdgeInsets.zero,
          title: tr(context, 'Lock with PIN', 'Bloquear con PIN'),
          subtitle: tr(
            context,
            'Needs your Yumeships PIN to open, even for owners.',
            'Necesita tu PIN de Yumeships para abrirse, incluso para los dueños.',
          ),
          value: draft['locked'] == true,
          onChanged: (on) async {
            if (on && !ref.read(yumeSettingsProvider).hasPin) {
              final pin = await yumeAskPin(
                context,
                title: tr(
                  context,
                  'Choose a Yumeships PIN',
                  'Elige un PIN de Yumeships',
                ),
              );
              if (pin == null) return;
              await ref.read(yumeActionsProvider).setPin(pin);
            }
            onChanged({...draft, 'locked': on});
          },
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            tr(
              context,
              'Nothing here is ever shared outside Prism unless you export it yourself.',
              'Nada de esto sale de Prism a menos que lo exportes tú.',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// Section chips used at the top of the long editors.
class YumeEditorTabs extends StatelessWidget {
  const YumeEditorTabs({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelected,
  });
  final Map<String, String> tabs;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        for (final e in tabs.entries)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: PrismChip(
              label: e.value,
              selected: selected == e.key,
              onTap: () => onSelected(e.key),
            ),
          ),
      ],
    ),
  );
}
