import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:prism_plurality/features/yumeships/yume_data.dart';
import 'package:prism_plurality/features/yumeships/yume_widgets.dart';
import 'package:prism_plurality/shared/media/prism_media.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import 'package:prism_plurality/shared/utils/prism_image_picker.dart';
import 'package:prism_plurality/shared/utils/safe_link.dart';

/// Add or edit a gallery entry: fanart and commissions with credits,
/// photos, GIFs, videos, audio, moodboards, letters and stories.
Future<void> showYumeMediaEditor(
  BuildContext context, {
  required String shipId,
  YumeMedia? existing,
  String type = 'art',
}) => PrismSheet.showFullScreen<void>(
  context: context,
  builder: (ctx, scroll) => _MediaEditor(
    shipId: shipId,
    existing: existing,
    type: type,
    scroll: scroll,
  ),
);

class _MediaEditor extends ConsumerStatefulWidget {
  const _MediaEditor({
    required this.shipId,
    this.existing,
    required this.type,
    required this.scroll,
  });
  final String shipId;
  final YumeMedia? existing;
  final String type;
  final ScrollController scroll;
  @override
  ConsumerState<_MediaEditor> createState() => _MediaEditorState();
}

class _MediaEditorState extends ConsumerState<_MediaEditor> {
  late final x = widget.existing;
  late String _type = x?.type ?? widget.type;
  late List<String> _media = [...?x?.media];
  late final _title = TextEditingController(text: x?.title);
  late final _caption = TextEditingController(text: x?.caption);
  late final _artist = TextEditingController(text: x?.artist);
  late final _link = TextEditingController(text: x?.link);
  late final _credit = TextEditingController(text: x?.credit);
  late bool _commissioned = x?.commissioned ?? widget.type == 'commission';
  late DateTime? _date = x?.date;

  @override
  void dispose() {
    for (final c in [_title, _caption, _artist, _link, _credit]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _textType => _type == 'letter' || _type == 'story';

  Future<void> _addMedia() async {
    switch (_type) {
      case 'video':
        final r = await PrismMedia.pickVideoResult(ref);
        if (r.error != null && mounted)
          PrismToast.error(context, message: r.error!);
        if (r.id != null) setState(() => _media.add(r.id!));
      case 'audio':
        final id = await PrismMedia.pickAudio();
        if (id != null) setState(() => _media.add(id));
      case 'gif':
        // GIFs skip cropping so their animation is kept.
        final id = await PrismMedia.pickImage(ref, crop: false);
        if (id != null) setState(() => _media.add(id));
      default:
        final ids = await PrismMedia.pickImages(ref, spec: PrismCropSpec.free);
        setState(() => _media.addAll(ids));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TrackerEditorScaffold(
      title: x == null
          ? tr(context, 'Add to gallery', 'Añadir a la galería')
          : tr(context, 'Edit entry', 'Editar entrada'),
      canSave:
          _media.isNotEmpty ||
          _caption.text.trim().isNotEmpty ||
          _title.text.trim().isNotEmpty,
      scrollController: widget.scroll,
      onSave: () async {
        final a = ref.read(yumeActionsProvider);
        final fields = {
          'type': _type,
          'media': _media,
          'artist': _artist.text.trim(),
          'link': _link.text.trim(),
          'credit': _credit.text.trim(),
          'commissioned': _commissioned,
        };
        if (x == null) {
          await a.addMedia(
            widget.shipId,
            type: _type,
            media: _media,
            title: _title.text,
            caption: _caption.text,
            artist: _artist.text.trim(),
            link: _link.text.trim(),
            credit: _credit.text.trim(),
            commissioned: _commissioned,
            date: _date,
          );
        } else {
          await a.saveMedia(
            x!,
            fields,
            title: _title.text,
            caption: _caption.text,
            date: _date,
          );
        }
        if (context.mounted) Navigator.of(context).pop();
      },
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final t in yumeMediaTypes.entries)
              PrismChip(
                label: '${t.value.$3} ${tr(context, t.value.$1, t.value.$2)}',
                selected: _type == t.key,
                onTap: () => setState(() => _type = t.key),
              ),
          ],
        ),
        const SizedBox(height: 12),
        PrismTextField(
          controller: _title,
          labelText: tr(context, 'Title', 'Título'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        if (!_textType || _media.isNotEmpty) ...[
          if (_media.isNotEmpty)
            SizedBox(
              height: 110,
              child: ReorderableListView(
                scrollDirection: Axis.horizontal,
                onReorder: (a, b) => setState(() {
                  if (b > a) b--;
                  _media.insert(b, _media.removeAt(a));
                }),
                children: [
                  for (final id in _media)
                    Padding(
                      key: ValueKey(id),
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 100,
                              height: 100,
                              child: YumeMediaImage(id: id),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: IconButton(
                              tooltip: tr(context, 'Remove', 'Quitar'),
                              icon: const Icon(Icons.cancel),
                              onPressed: () =>
                                  setState(() => _media.remove(id)),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          if ((_type != 'video' && _type != 'audio') || !kIsWeb)
            Align(
              alignment: Alignment.centerLeft,
              child: YumeAction(
                label: switch (_type) {
                  'video' => tr(context, 'Add video', 'Añadir vídeo'),
                  'audio' => tr(context, 'Add audio', 'Añadir audio'),
                  'gif' => tr(context, 'Add GIF', 'Añadir GIF'),
                  _ => tr(context, 'Add pictures', 'Añadir imágenes'),
                },
                icon: Icons.add_photo_alternate_outlined,
                onPressed: _addMedia,
              ),
            )
          else
            Text(
              tr(
                context,
                'Videos and audio can be added on the app.',
                'Los vídeos y el audio se añaden en la app.',
              ),
              style: theme.textTheme.bodySmall,
            ),
        ],
        PrismTextField(
          controller: _caption,
          labelText: _textType
              ? tr(context, 'Text', 'Texto')
              : tr(context, 'Caption', 'Descripción'),
          minLines: _textType ? 8 : 2,
          maxLines: _textType ? 40 : 6,
          onChanged: (_) => setState(() {}),
        ),
        if (_textType)
          Align(
            alignment: Alignment.centerLeft,
            child: YumeAction(
              label: tr(context, 'Attach a picture', 'Adjuntar imagen'),
              icon: Icons.image_outlined,
              onPressed: () async {
                final id = await PrismMedia.pickImage(ref);
                if (id != null) setState(() => _media.add(id));
              },
            ),
          ),
        const SizedBox(height: 12),
        TrackerLabel(tr(context, 'Credits', 'Créditos')),
        PrismTextField(
          controller: _artist,
          labelText: tr(context, 'Artist / creator', 'Artista / autor'),
        ),
        const SizedBox(height: 8),
        PrismTextField(
          controller: _link,
          labelText: tr(context, 'Source link', 'Enlace a la fuente'),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 8),
        PrismTextField(
          controller: _credit,
          labelText: tr(context, 'Credit line / notes', 'Créditos / notas'),
        ),
        PrismSwitchRow(
          padding: EdgeInsets.zero,
          title: tr(context, 'Commissioned piece', 'Pieza encargada'),
          value: _commissioned,
          onChanged: (v) => setState(() => _commissioned = v),
        ),
        PrismListRow(
          padding: EdgeInsets.zero,
          leading: const Icon(Icons.event_outlined),
          title: Text(
            _date == null
                ? tr(context, 'Add a date', 'Añadir fecha')
                : yumeDate(_date!),
          ),
          onTap: () async {
            final d = await showPrismDatePicker(
              context: context,
              initialDate: _date ?? DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime(2200),
            );
            if (d != null) setState(() => _date = d);
          },
        ),
        if (x != null) ...[
          const SizedBox(height: 12),
          PrismButton(
            label: tr(context, 'Delete entry', 'Eliminar entrada'),
            icon: Icons.delete_outline,
            onPressed: () async {
              final ok = await PrismDialog.confirm(
                context: context,
                title: tr(
                  context,
                  'Delete this entry?',
                  '¿Eliminar esta entrada?',
                ),
                destructive: true,
                confirmLabel: tr(context, 'Delete', 'Eliminar'),
              );
              if (!ok) return;
              await ref.read(yumeActionsProvider).deleteMedia(x!);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ],
    );
  }
}

/// Full view of one entry with its credits.
Future<void> showYumeMediaView(
  BuildContext context,
  YumeMedia m, {
  required bool canEdit,
}) => Navigator.of(context, rootNavigator: true).push(
  MaterialPageRoute<void>(
    builder: (_) => _MediaView(id: m.id, shipId: m.shipId, canEdit: canEdit),
  ),
);

class _MediaView extends ConsumerWidget {
  const _MediaView({
    required this.id,
    required this.shipId,
    required this.canEdit,
  });
  final String id, shipId;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref
        .watch(yumeShipMediaProvider(shipId))
        .where((x) => x.id == id)
        .firstOrNull;
    final theme = Theme.of(context);
    if (m == null) {
      return const PrismPageScaffold(
        topBar: PrismTopBar(title: '', showBackButton: true),
        body: SizedBox.shrink(),
      );
    }
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: m.title.isEmpty ? (yumeMediaTypes[m.type]?.$1 ?? '') : m.title,
        showBackButton: true,
        actions: [
          if (canEdit)
            PrismTopBarAction(
              icon: Icons.edit_outlined,
              tooltip: tr(context, 'Edit', 'Editar'),
              onPressed: () =>
                  showYumeMediaEditor(context, shipId: shipId, existing: m),
            ),
        ],
      ),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            for (final id in m.media)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: id.startsWith('audio:')
                      ? AudioClip(id: id)
                      : YumeMediaImage(id: id, fit: BoxFit.contain),
                ),
              ),
            if (m.caption.isNotEmpty)
              SelectableText(m.caption, style: theme.textTheme.bodyLarge),
            if (m.artist.isNotEmpty ||
                m.link.isNotEmpty ||
                m.credit.isNotEmpty) ...[
              const SizedBox(height: 16),
              PrismSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(context, 'Credits', 'Créditos'),
                      style: theme.textTheme.titleSmall,
                    ),
                    if (m.artist.isNotEmpty)
                      Text('${m.commissioned ? '🖌️ ' : '🎨 '}${m.artist}'),
                    if (m.credit.isNotEmpty) Text(m.credit),
                    if (m.link.isNotEmpty)
                      YumeAction(
                        label: m.link,
                        icon: Icons.open_in_new,
                        onPressed: () => launchSafeExternalUri(m.link),
                      ),
                    if (m.date != null)
                      Text(yumeDate(m.date!), style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
