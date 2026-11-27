import 'package:flutter/material.dart';
import 'package:prism_plurality/features/scrapbook/scrap_editor_core.dart';
import 'package:prism_plurality/features/scrapbook/scrap_models.dart';
import 'package:prism_plurality/features/scrapbook/scrap_props.dart';
import 'package:prism_plurality/features/scrapbook/scrap_shapes.dart';
import 'package:prism_plurality/features/scrapbook/scrap_stickers.dart';
import 'package:prism_plurality/features/scrapbook/scrap_washi.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// A short readable name for a layer.
String scrapElementName(BuildContext context, ScrapElement e) =>
    switch (e.type) {
      ScrapType.text =>
        e.text == '{title}'
            ? tr(context, 'Title', 'Título')
            : e.text == '{subtitle}'
            ? tr(context, 'Subtitle', 'Subtítulo')
            : (e.text?.isEmpty ?? true
                  ? tr(context, 'Text', 'Texto')
                  : e.text!),
      ScrapType.note => tr(context, 'Note', 'Nota'),
      ScrapType.markdown => tr(context, 'Rentry note', 'Nota Rentry'),
      ScrapType.sticker => scrapStickerName(e.text),
      ScrapType.shape => scrapShapeName(e.text ?? 'heart'),
      ScrapType.photo => tr(context, 'Picture', 'Imagen'),
      ScrapType.video => tr(context, 'Video', 'Vídeo'),
      ScrapType.audio => tr(context, 'Audio', 'Audio'),
      ScrapType.drawing => tr(context, 'Drawing', 'Dibujo'),
      ScrapType.tape =>
        washiById(e.opt<String>('wp', ''))?.name ??
            tr(context, 'Washi tape', 'Cinta washi'),
    };

/// The row of actions for whatever is selected: settings, copy/paste, group,
/// lock, layer order, align, distribute, delete.
class ScrapSelectionBar extends StatelessWidget {
  const ScrapSelectionBar({
    super.key,
    required this.controller,
    this.extra = const [],
  });
  final ScrapEditorController controller;

  /// Extra buttons the host adds at the front (e.g. "Adjust picture").
  final List<Widget> extra;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final one = c.single;
    Widget tool(
      IconData icon,
      String tip,
      VoidCallback? onTap, {
      bool on = false,
    }) => IconButton(
      tooltip: tip,
      icon: Icon(
        icon,
        size: 20,
        color: on ? Theme.of(context).colorScheme.primary : null,
      ),
      onPressed: onTap,
    );
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          ...extra,
          if (one != null)
            tool(
              Icons.tune,
              tr(context, 'Settings', 'Ajustes'),
              () => showScrapElementProps(context, c, one),
            ),
          tool(Icons.copy, tr(context, 'Copy', 'Copiar'), c.copySelected),
          tool(
            Icons.paste,
            tr(context, 'Paste', 'Pegar'),
            c.canPaste ? c.paste : null,
          ),
          tool(
            Icons.control_point_duplicate,
            tr(context, 'Duplicate', 'Duplicar'),
            c.duplicateSelected,
          ),
          tool(
            Icons.group_work_outlined,
            tr(context, 'Group', 'Agrupar'),
            c.canGroup ? c.group : null,
          ),
          tool(
            Icons.workspaces_outline,
            tr(context, 'Ungroup', 'Desagrupar'),
            c.canUngroup ? c.ungroup : null,
          ),
          tool(
            c.allLocked ? Icons.lock : Icons.lock_open,
            tr(context, 'Lock', 'Bloquear'),
            c.toggleLock,
            on: c.allLocked,
          ),
          tool(
            Icons.flip_to_front,
            tr(context, 'Bring to front', 'Traer al frente'),
            c.toFront,
          ),
          tool(Icons.arrow_upward, tr(context, 'Forward', 'Subir'), c.forward),
          tool(
            Icons.arrow_downward,
            tr(context, 'Backward', 'Bajar'),
            c.backward,
          ),
          tool(
            Icons.flip_to_back,
            tr(context, 'Send to back', 'Enviar al fondo'),
            c.toBack,
          ),
          tool(
            Icons.align_horizontal_left,
            tr(context, 'Align left', 'Alinear izquierda'),
            () => c.align(ScrapAlign.left),
          ),
          tool(
            Icons.align_horizontal_center,
            tr(context, 'Align centre', 'Centrar'),
            () => c.align(ScrapAlign.hCenter),
          ),
          tool(
            Icons.align_horizontal_right,
            tr(context, 'Align right', 'Alinear derecha'),
            () => c.align(ScrapAlign.right),
          ),
          tool(
            Icons.align_vertical_top,
            tr(context, 'Align top', 'Alinear arriba'),
            () => c.align(ScrapAlign.top),
          ),
          tool(
            Icons.align_vertical_center,
            tr(context, 'Align middle', 'Centrar vertical'),
            () => c.align(ScrapAlign.vCenter),
          ),
          tool(
            Icons.align_vertical_bottom,
            tr(context, 'Align bottom', 'Alinear abajo'),
            () => c.align(ScrapAlign.bottom),
          ),
          tool(
            Icons.horizontal_distribute,
            tr(context, 'Space evenly across', 'Distribuir horizontal'),
            () => c.distribute(horizontal: true),
          ),
          tool(
            Icons.vertical_distribute,
            tr(context, 'Space evenly down', 'Distribuir vertical'),
            () => c.distribute(horizontal: false),
          ),
          tool(Icons.delete_outline, tr(context, 'Delete', 'Eliminar'), () {
            if (c.deleteSelected() == 0)
              PrismToast.show(
                context,
                message: tr(
                  context,
                  'Locked items can’t be deleted — unlock them first.',
                  'Los elementos bloqueados no se pueden eliminar.',
                ),
              );
          }),
        ],
      ),
    );
  }
}

/// Layers, top first: tap to select, drag to reorder, lock.
class ScrapLayersPanel extends StatelessWidget {
  const ScrapLayersPanel({super.key, required this.controller, this.filter});
  final ScrapEditorController controller;
  final bool Function(ScrapElement e)? filter;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final list = [
      for (final e in c.els)
        if (filter?.call(e) ?? true) e,
    ]..sort((a, b) => b.z.compareTo(a.z));
    if (list.isEmpty)
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(tr(context, 'Nothing here yet.', 'Nada aquí todavía.')),
        ),
      );
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      itemCount: list.length,
      onReorder: (from, to) {
        if (to > from) to--;
        final zs = [for (final e in list) e.z]..sort((a, b) => b.compareTo(a));
        final moved = list.removeAt(from);
        list.insert(to, moved);
        for (var i = 0; i < list.length; i++) {
          list[i].z = zs[i];
        }
        c.commit();
      },
      itemBuilder: (_, i) {
        final e = list[i];
        return PrismListRow(
          key: ValueKey(e.id),
          dense: true,
          selected: c.selected.contains(e.id),
          title: Text(
            scrapElementName(context, e),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          leading: Icon(
            e.group != null ? Icons.group_work_outlined : Icons.layers_outlined,
          ),
          trailing: IconButton(
            tooltip: e.locked
                ? tr(context, 'Unlock', 'Desbloquear')
                : tr(context, 'Lock', 'Bloquear'),
            icon: Icon(e.locked ? Icons.lock : Icons.lock_open, size: 18),
            onPressed: () {
              e.locked = !e.locked;
              c.commit();
            },
          ),
          onTap: () => c.select(e.id),
        );
      },
    );
  }
}
