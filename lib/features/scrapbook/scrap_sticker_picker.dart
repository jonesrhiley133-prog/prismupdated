import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:prism_plurality/features/scrapbook/scrap_sticker_library.dart';
import 'package:prism_plurality/features/scrapbook/scrap_sticker_view.dart';
import 'package:prism_plurality/features/scrapbook/scrap_stickers.dart';
import 'package:prism_plurality/features/social/services/social_media.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// What a chosen sticker is: its id, plus the media id when it's one of
/// your own imports.
typedef StickerChoice = ({String id, String? media});

/// A built-in or imported sticker, drawn to fill its box.
class ScrapStickerContent extends ConsumerWidget {
  const ScrapStickerContent({
    super.key,
    required this.id,
    this.media,
    this.tint,
  });
  final String id;
  final String? media;
  final Color? tint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final built = scrapStickerById(id);
    if (built != null) return ScrapStickerView(built, tint: tint);
    if (media != null) return ScrapCustomStickerImage(media!);
    // Older pages stored the emoji itself.
    return FittedBox(child: Text(id, style: const TextStyle(fontSize: 100)));
  }
}

class ScrapCustomStickerImage extends ConsumerWidget {
  const ScrapCustomStickerImage(this.media, {super.key});
  final String media;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(socialImageProvider(media));
    if (bytes == null) return const Icon(Icons.image_not_supported_outlined);
    if (looksLikeSvg(bytes)) {
      return SvgPicture.memory(
        bytes,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
      );
    }
    return Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: true);
  }
}

Future<StickerChoice?> showScrapStickerPicker(BuildContext context) =>
    PrismSheet.show<StickerChoice>(
      context: context,
      title: tr(context, 'Stickers', 'Pegatinas'),
      maxHeightFactor: 0.92,
      builder: (_) => const _Picker(),
    );

class _Picker extends ConsumerStatefulWidget {
  const _Picker();
  @override
  ConsumerState<_Picker> createState() => _PickerState();
}

class _PickerState extends ConsumerState<_Picker> {
  String _tab = 'Kawaii'; // category, or ‘★’, ‘recent’, ‘mine’, ‘c:<id>’
  String _q = '';

  void _toast(String m) => PrismToast.show(context, message: m);

  Future<void> _import({bool pack = false}) async {
    final r = await FilePicker.pickFiles(
      allowMultiple: !pack,
      withData: true,
      type: FileType.custom,
      allowedExtensions: pack
          ? const ['json', 'txt']
          : const ['png', 'svg', 'gif', 'webp', 'jpg', 'jpeg'],
    );
    if (r == null || !mounted) return;
    final lib = ref.read(stickerLibraryProvider.notifier);
    var added = 0, refused = 0;
    for (final f in r.files) {
      final bytes = f.bytes;
      if (bytes == null) {
        refused++;
        continue;
      }
      if (pack) {
        final p = parseStickerPack(utf8.decode(bytes, allowMalformed: true));
        if (p == null) {
          refused++;
          continue;
        }
        final cid = lib.addCollection(p.name);
        for (final s in p.stickers) {
          final id = await lib.addCustom(s.name, s.file);
          lib.toggleInCollection(cid, id);
          added++;
        }
        refused += p.skipped;
      } else {
        final res = prepareStickerFile(bytes);
        if (res.ok == null) {
          refused++;
          continue;
        }
        await lib.addCustom(
          f.name.replaceAll(RegExp(r'\.[^.]+$'), ''),
          res.ok!,
        );
        added++;
      }
    }
    if (!mounted) return;
    if (added > 0) setState(() => _tab = 'mine');
    _toast(
      added == 0
          ? tr(
              context,
              'Nothing could be imported — use PNG, SVG, GIF, WebP or JPG.',
              'No se pudo importar nada — usa PNG, SVG, GIF, WebP o JPG.',
            )
          : refused == 0
          ? tr(context, 'Added $added.', 'Se añadieron $added.')
          : tr(
              context,
              'Added $added; $refused could not be used.',
              'Se añadieron $added; $refused no se pudieron usar.',
            ),
    );
  }

  Future<void> _sharePack() async {
    final lib = ref.read(stickerLibraryProvider);
    final files = <({String name, Uint8List bytes})>[];
    for (final c in lib.custom) {
      final b = ref.read(socialImageProvider(c.media));
      if (b != null) files.add((name: c.name, bytes: b));
    }
    if (files.isEmpty) {
      _toast(
        tr(
          context,
          'Import some stickers first.',
          'Importa algunas pegatinas primero.',
        ),
      );
      return;
    }
    await Clipboard.setData(
      ClipboardData(text: exportStickerPack('My stickers', files)),
    );
    if (mounted)
      _toast(
        tr(
          context,
          'Pack copied — paste it into a .json file to share.',
          'Paquete copiado — pégalo en un archivo .json para compartir.',
        ),
      );
  }

  List<String> _ids(StickerLibrary lib) {
    if (_q.trim().isNotEmpty) {
      return [
        for (final s in scrapStickerCatalog)
          if (s.matches(_q)) s.id,
        for (final c in lib.custom)
          if (c.name.toLowerCase().contains(_q.trim().toLowerCase())) c.id,
      ];
    }
    if (_tab == 'recent') return lib.recents;
    if (_tab == '★') return lib.favorites;
    if (_tab == 'mine') return [for (final c in lib.custom) c.id];
    if (_tab.startsWith('col:'))
      return lib.collections
              .where((c) => 'col:${c.id}' == _tab)
              .firstOrNull
              ?.items ??
          const [];
    return [for (final s in stickersIn(_tab)) s.id];
  }

  void _choose(String id, StickerLibrary lib) {
    final custom = lib.customById(id);
    ref.read(stickerLibraryProvider.notifier).used(id);
    Navigator.of(context).pop((id: id, media: custom?.media));
  }

  Future<void> _menu(String id, StickerLibrary lib) async {
    final n = ref.read(stickerLibraryProvider.notifier);
    final isCustom = id.startsWith('c:');
    await PrismSheet.show<void>(
      context: context,
      title: tr(context, 'Sticker', 'Pegatina'),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PrismButton(
              label: lib.isFavorite(id)
                  ? tr(ctx, 'Remove from favorites', 'Quitar de favoritos')
                  : tr(ctx, 'Add to favorites', 'Añadir a favoritos'),
              icon: lib.isFavorite(id) ? Icons.star : Icons.star_border,
              onPressed: () {
                n.toggleFavorite(id);
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 8),
            for (final c in lib.collections) ...[
              PrismButton(
                label: '${c.items.contains(id) ? '✓ ' : ''}${c.name}',
                icon: Icons.collections_bookmark_outlined,
                onPressed: () {
                  n.toggleInCollection(c.id, id);
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 8),
            ],
            if (isCustom)
              PrismButton(
                label: tr(ctx, 'Delete this sticker', 'Eliminar esta pegatina'),
                icon: Icons.delete_outline,
                onPressed: () {
                  n.removeCustom(id);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _newCollection() async {
    final c = TextEditingController();
    final name = await PrismDialog.show<String>(
      context: context,
      title: tr(context, 'New collection', 'Nueva colección'),
      builder: (ctx) => PrismTextField(
        controller: c,
        autofocus: true,
        hintText: tr(ctx, 'Name', 'Nombre'),
      ),
      actions: [
        PrismButton(
          label: tr(context, 'Create', 'Crear'),
          onPressed: () => Navigator.pop(context, c.text),
          tone: PrismButtonTone.filled,
        ),
      ],
    );
    if (name != null && name.trim().isNotEmpty) {
      final id = ref.read(stickerLibraryProvider.notifier).addCollection(name);
      setState(() => _tab = 'col:$id');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lib = ref.watch(stickerLibraryProvider);
    final ids = _ids(lib);
    final searching = _q.trim().isNotEmpty;
    Widget chip(String key, String label, [Widget? avatar]) => Padding(
      padding: const EdgeInsets.only(right: 6),
      child: PrismChip(
        label: label,
        selected: !searching && _tab == key,
        avatar: avatar,
        onTap: () => setState(() {
          _tab = key;
          _q = '';
        }),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrismTextField(
            hintText: tr(context, 'Search stickers', 'Buscar pegatinas'),
            prefixIcon: const Icon(Icons.search),
            onChanged: (v) => setState(() => _q = v),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                chip('recent', tr(context, 'Recent', 'Recientes')),
                chip('★', tr(context, 'Favorites', 'Favoritos')),
                chip('mine', tr(context, 'Mine', 'Mías')),
                for (final c in lib.collections) chip('col:${c.id}', c.name),
                for (final c in scrapStickerCategories) chip(c, c),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PrismButton(
                label: tr(context, 'Import', 'Importar'),
                icon: Icons.add_photo_alternate_outlined,
                density: PrismControlDensity.compact,
                onPressed: _import,
              ),
              PrismButton(
                label: tr(context, 'Import pack', 'Importar paquete'),
                icon: Icons.inventory_2_outlined,
                density: PrismControlDensity.compact,
                onPressed: () => _import(pack: true),
              ),
              PrismButton(
                label: tr(context, 'Share my pack', 'Compartir mi paquete'),
                icon: Icons.ios_share,
                density: PrismControlDensity.compact,
                onPressed: _sharePack,
              ),
              PrismButton(
                label: tr(context, 'New collection', 'Nueva colección'),
                icon: Icons.create_new_folder_outlined,
                density: PrismControlDensity.compact,
                onPressed: _newCollection,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ids.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        searching
                            ? tr(
                                context,
                                'No stickers match.',
                                'Ninguna pegatina coincide.',
                              )
                            : tr(
                                context,
                                'Nothing here yet. Long-press any sticker to favorite it or add it to a collection.',
                                'Aún no hay nada. Mantén pulsada una pegatina para añadirla a favoritos o a una colección.',
                              ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : GridView.builder(
                    shrinkWrap: true,
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 76,
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 6,
                        ),
                    itemCount: ids.length,
                    itemBuilder: (_, i) {
                      final id = ids[i];
                      final built = scrapStickerById(id);
                      final custom = lib.customById(id);
                      if (built == null && custom == null)
                        return const SizedBox.shrink();
                      return Semantics(
                        button: true,
                        label: built?.name ?? custom!.name,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _choose(id, lib),
                          onLongPress: () => _menu(id, lib),
                          child: Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: SizedBox.expand(
                                  child: built != null
                                      ? ScrapStickerView(built)
                                      : ScrapCustomStickerImage(custom!.media),
                                ),
                              ),
                              if (lib.isFavorite(id))
                                const Positioned(
                                  top: 2,
                                  right: 2,
                                  child: Icon(
                                    Icons.star,
                                    size: 14,
                                    color: Color(0xFFFFB300),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
