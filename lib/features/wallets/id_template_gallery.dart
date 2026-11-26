import 'package:flutter/material.dart';

import 'package:prism_plurality/features/wallets/id_card_view.dart';
import 'package:prism_plurality/features/wallets/id_shapes.dart';
import 'package:prism_plurality/features/wallets/id_templates.dart';
import 'package:prism_plurality/features/wallets/wallet_data.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Sample values for template previews.
const idPreviewValues = <String, String>{
  'name': 'Sam Rivers',
  'pronouns': 'they/them',
  'number': 'PRM-0000',
  'issued': 'Today',
  'expires': 'Forever',
  'emoji': '✨',
  'role': 'Navigator',
  'birthday': 'Mar 14',
  'status': 'Fronting',
  'interests': 'Stars · Tea',
  'notes': 'Be kind to me',
  'signature': 'Sam',
  'custom1': '@sam',
  'custom2': 'prism.example',
  'flags': '🏳️‍🌈',
  'boundaries': 'Ask first',
  'system': 'Prism',
  'issuer': 'The system',
};

/// Every card design in one browsable gallery: 60+ new templates grouped by
/// category, plus the original collections. Tapping one calls [onPick] with
/// the template id (`collection.layout`).
class IdTemplateGallery extends StatefulWidget {
  const IdTemplateGallery({
    super.key,
    required this.type,
    required this.selected,
    required this.onPick,
    this.fields = const {
      'name',
      'pronouns',
      'number',
      'photo',
      'issued',
      'emoji',
      'role',
    },
    this.shrinkWrap = false,
    this.custom = const [],
    this.onDeleteCustom,
  });

  /// The person's own saved templates (shown first, as "My templates").
  final List<SavedIdTemplate> custom;
  final ValueChanged<SavedIdTemplate>? onDeleteCustom;
  final String type;
  final String selected;
  final Set<String> fields;
  final ValueChanged<String> onPick;
  final bool shrinkWrap;

  @override
  State<IdTemplateGallery> createState() => _IdTemplateGalleryState();
}

class _IdTemplateGalleryState extends State<IdTemplateGallery> {
  String? _cat;
  static const _classic = 'Classic collections';
  static const _mine = 'My templates';

  List<(String id, String name, String cat)> get _items => [
    for (final c in widget.custom) ('my.${c.id}', c.name, _mine),
    for (final t in idTemplates) (t.id, t.name, t.category),
    for (final c in templateCollections)
      for (final l in templateLayouts.entries)
        ('${c.id}.${l.key}', '${c.name} · ${l.value}', _classic),
  ];

  @override
  Widget build(BuildContext context) {
    final cats = [
      if (widget.custom.isNotEmpty) _mine,
      ...idTemplateCategories,
      _classic,
    ];
    final items = _items.where((e) => _cat == null || e.$3 == _cat).toList();
    return Column(
      mainAxisSize: widget.shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: PrismChip(
                  label: 'All (${_items.length})',
                  selected: _cat == null,
                  onTap: () => setState(() => _cat = null),
                ),
              ),
              for (final c in cats)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: PrismChip(
                    label: c,
                    selected: _cat == c,
                    onTap: () => setState(() => _cat = _cat == c ? null : c),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          flex: widget.shrinkWrap ? 0 : 1,
          child: SizedBox(
            height: widget.shrinkWrap ? 340 : null,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 190,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                mainAxisExtent: 170,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final (id, name, _) = items[i];
                final parts = id.split('.');
                final mine = parts.first == 'my'
                    ? widget.custom.where((c) => c.id == parts.last).firstOrNull
                    : null;
                final front = mine != null
                    ? mine.front
                    : buildAnyTemplate(
                        parts.first,
                        parts.last,
                        type: widget.type,
                        fields: widget.fields,
                      ).$1;
                final aspect = mine != null
                    ? (mine.front.aspect > 0 ? mine.front.aspect : idCardRatio)
                    : idTemplateAspect(parts.first, parts.last);
                final sel = widget.selected == id;
                return Semantics(
                  button: true,
                  selected: sel,
                  label: name,
                  child: InkWell(
                    borderRadius: prismCorners(context, 12),
                    onTap: () => widget.onPick(id),
                    child: DecoratedBox(
                      position: DecorationPosition.foreground,
                      decoration: BoxDecoration(
                        borderRadius: prismCorners(context, 12),
                        border: sel
                            ? Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 3,
                              )
                            : null,
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: Center(
                              child: LayoutBuilder(
                                builder: (context, box) {
                                  // Fit the whole card inside the cell, whatever its shape.
                                  final w =
                                      aspect >=
                                          box.maxWidth / (box.maxHeight - 2)
                                      ? box.maxWidth - 4
                                      : (box.maxHeight - 2) * aspect;
                                  return IgnorePointer(
                                    child: CardFaceView(
                                      face: front,
                                      values: idPreviewValues,
                                      width: w,
                                      ratio: aspect,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.labelMedium,
                                ),
                              ),
                              if (mine != null && widget.onDeleteCustom != null)
                                InkWell(
                                  onTap: () => widget.onDeleteCustom!(mine),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.delete_outline, size: 16),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Grid of decorative shapes to add or change to.
Future<String?> showIdShapePicker(
  BuildContext context, {
  String? current,
  Color? color,
}) => PrismSheet.show<String>(
  context: context,
  title: 'Shapes',
  builder: (ctx) => SizedBox(
    height: 380,
    child: GridView.count(
      crossAxisCount: 5,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        for (final e in idShapeKinds.entries)
          Semantics(
            button: true,
            selected: current == e.key,
            label: e.value,
            child: InkWell(
              borderRadius: prismCorners(ctx, 10),
              onTap: () => Navigator.of(ctx).pop(e.key),
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: CustomPaint(
                        size: const Size.square(48),
                        painter: IdShapePainter(
                          kind: e.key,
                          color: color ?? Theme.of(ctx).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    e.value,
                    style: Theme.of(ctx).textTheme.labelSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  ),
);
