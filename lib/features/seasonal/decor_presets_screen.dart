import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/features/companions/companion_screens.dart'
    show memberNamesProvider;
import 'package:prism_plurality/features/appearance/appearance_undo_banner.dart';
import 'package:prism_plurality/features/seasonal/decor_models.dart';
import 'package:prism_plurality/features/seasonal/digital_rooms.dart';
import 'package:prism_plurality/features/subsystems/hub/subsystem_data.dart'
    show subsystemsProvider;
import 'package:prism_plurality/features/seasonal/decor_preview.dart';
import 'package:prism_plurality/features/seasonal/seasonal_providers.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Pages a preset can be limited to.
const decorPages = <(String path, String en, String es)>[
  ('/home', 'Home', 'Inicio'),
  ('/members', 'Members', 'Miembros'),
  ('/calendar', 'Calendar', 'Calendario'),
  ('/journal', 'Journal', 'Diario'),
  ('/chat', 'Chat', 'Chat'),
  ('/contacts', 'Contacts', 'Contactos'),
  ('/settings', 'Settings', 'Ajustes'),
];

class DecorPresetsScreen extends ConsumerStatefulWidget {
  const DecorPresetsScreen({super.key, this.rooms = false});

  /// Shows only Digital Rooms, with room actions first.
  final bool rooms;
  @override
  ConsumerState<DecorPresetsScreen> createState() => _DecorPresetsScreenState();
}

class _DecorPresetsScreenState extends ConsumerState<DecorPresetsScreen> {
  String? _category;

  Widget _thumb(DecorPreset pr) {
    final t = pr.thumbnail;
    if (t != null) {
      try {
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            base64Decode(t),
            width: 70,
            height: 124,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        );
      } catch (_) {}
    }
    return DecorPreview(items: pr.items, layers: pr.layers, width: 70);
  }

  Future<void> _import() async {
    final choice = await PrismSheet.show<String>(
      context: context,
      title: tr(context, 'Import an arrangement', 'Importar un arreglo'),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr(
              ctx,
              'Importing only adds a new arrangement. It never changes your theme, and nothing in it is run.',
              'Importar solo añade un arreglo nuevo. Nunca cambia tu tema y nada se ejecuta.',
            ),
            style: Theme.of(ctx).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          PrismButton(
            label: tr(ctx, 'Choose a file', 'Elegir un archivo'),
            icon: Icons.upload_file_outlined,
            tone: PrismButtonTone.filled,
            onPressed: () => Navigator.of(ctx).pop('file'),
          ),
          const SizedBox(height: 8),
          PrismButton(
            label: tr(ctx, 'Paste from clipboard', 'Pegar del portapapeles'),
            icon: Icons.content_paste,
            tone: PrismButtonTone.outlined,
            onPressed: () => Navigator.of(ctx).pop('paste'),
          ),
        ],
      ),
    );
    String? text;
    if (choice == 'file') {
      try {
        final r = await FilePicker.pickFiles(type: FileType.any);
        final path = r?.files.firstOrNull?.path;
        if (path != null) {
          if (await File(path).length() > 2 * 1024 * 1024) {
            if (mounted)
              PrismToast.error(
                context,
                message: tr(
                  context,
                  'That file is too large.',
                  'Ese archivo es demasiado grande.',
                ),
              );
            return;
          }
          text = await File(path).readAsString();
        }
      } catch (_) {
        text = '';
      }
    } else if (choice == 'paste') {
      text = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
    }
    if (text == null || !mounted) return;
    final preset = importPreset(text);
    if (preset == null) {
      PrismToast.error(
        context,
        message: tr(
          context,
          'That isn\'t a Prism decoration arrangement.',
          'Eso no es un arreglo de decoración de Prism.',
        ),
      );
      return;
    }
    await ref.read(decorPresetActionsProvider).create(preset);
    if (mounted)
      PrismToast.success(
        context,
        message: tr(
          context,
          '${preset.name} added. Your theme is unchanged.',
          '${preset.name} añadido. Tu tema no cambió.',
        ),
      );
  }

  Future<void> _export(DecorPreset pr) async {
    final b = exportPreset(pr);
    try {
      final dir = await getTemporaryDirectory();
      final safe = pr.name.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim();
      final f = File(
        p.join(
          dir.path,
          '${safe.isEmpty ? 'arrangement' : safe}.prismdecor.json',
        ),
      );
      await f.writeAsString(b.json);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(f.path)], subject: pr.name),
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: b.json));
      if (mounted)
        PrismToast.success(context, message: tr(context, 'Copied', 'Copiado'));
    }
    if (b.skipped > 0 && mounted) {
      PrismToast.show(
        context,
        message: tr(
          context,
          '${b.skipped} imported picture(s) stay on this device and weren\'t included.',
          '${b.skipped} imagen(es) importada(s) se quedan en este dispositivo y no se incluyeron.',
        ),
      );
    }
  }

  Future<void> _newRoom() async {
    final name = TextEditingController(text: tr(context, 'My room', 'Mi sala'));
    final ok = await PrismSheet.show<bool>(
      context: context,
      title: tr(context, 'New room', 'Nueva sala'),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr(
              ctx,
              'Saves the decorations, living look, layout, environment and ambience showing now.',
              'Guarda las decoraciones, estilo vivo, diseño, ambiente y sonido actuales.',
            ),
            style: Theme.of(ctx).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          PrismTextField(
            controller: name,
            labelText: tr(ctx, 'Name', 'Nombre'),
          ),
          const SizedBox(height: 12),
          PrismButton(
            label: tr(ctx, 'Create room', 'Crear sala'),
            tone: PrismButtonTone.filled,
            expanded: true,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    final text = name.text.trim();
    name.dispose();
    if (ok != true || !mounted) return;
    final id = await createRoomFromCurrent(
      ref,
      text.isEmpty ? tr(context, 'My room', 'Mi sala') : text,
    );
    if (!mounted) return;
    PrismToast.show(
      context,
      message: tr(context, 'Room saved.', 'Sala guardada.'),
    );
    enterRoom(ref, id);
  }

  Future<void> _menu(DecorPreset pr) async {
    final prefs = ref.read(seasonalPrefsProvider);
    final n = ref.read(seasonalPrefsProvider.notifier);
    final actions = ref.read(decorPresetActionsProvider);
    final names = ref.read(memberNamesProvider);
    final isActive = prefs.activePresetId == pr.id;
    final subs = ref.read(subsystemsProvider);
    await PrismSheet.show<void>(
      context: context,
      title: pr.name,
      builder: (ctx) {
        Widget row(
          IconData icon,
          String label,
          Future<void> Function() onTap, {
          bool destructive = false,
        }) => PrismListRow(
          dense: true,
          leading: Icon(
            icon,
            color: destructive ? Theme.of(ctx).colorScheme.error : null,
          ),
          title: Text(label),
          destructive: destructive,
          onTap: () async {
            Navigator.of(ctx).pop();
            await onTap();
          },
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            row(
              isActive ? Icons.check_circle : Icons.check_circle_outline,
              pr.isRoom
                  ? (isActive
                        ? tr(ctx, 'Leave this room', 'Salir de esta sala')
                        : tr(ctx, 'Enter this room', 'Entrar en esta sala'))
                  : isActive
                  ? tr(
                      ctx,
                      'Stop using everywhere',
                      'Dejar de usar en todas partes',
                    )
                  : tr(ctx, 'Use everywhere', 'Usar en todas partes'),
              () async {
                n.update(
                  (x) => x.copyWith(
                    activePresetId: isActive ? null : pr.id,
                    performance: x.performance == DecoPerformance.off
                        ? DecoPerformance.balanced
                        : x.performance,
                  ),
                );
              },
            ),
            if (names.isNotEmpty)
              row(
                Icons.person_outline,
                tr(ctx, 'Use for one alter…', 'Usar para un alter…'),
                () async {
                  final id = await PrismSheet.show<String>(
                    context: context,
                    title: tr(
                      context,
                      'Show it when this alter fronts',
                      'Mostrar cuando este alter está al frente',
                    ),
                    builder: (c2) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final e in names.entries)
                          PrismListRow(
                            title: Text(e.value),
                            selected: prefs.alterPresets[e.key] == pr.id,
                            onTap: () => Navigator.of(c2).pop(e.key),
                          ),
                      ],
                    ),
                  );
                  if (id != null)
                    n.update(
                      (x) => x.copyWith(
                        alterPresets: {...x.alterPresets, id: pr.id},
                        performance: x.performance == DecoPerformance.off
                            ? DecoPerformance.balanced
                            : x.performance,
                      ),
                    );
                },
              ),
            if (subs.isNotEmpty)
              row(
                Icons.hub_outlined,
                tr(ctx, 'Use for a subsystem…', 'Usar para un subsistema…'),
                () async {
                  final id = await PrismSheet.show<String>(
                    context: context,
                    title: tr(
                      context,
                      'Show it when someone from this subsystem fronts',
                      'Mostrar cuando alguien de este subsistema está al frente',
                    ),
                    builder: (c2) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final sub in subs)
                          PrismListRow(
                            title: Text(
                              sub.title.isEmpty
                                  ? tr(context, 'Subsystem', 'Subsistema')
                                  : sub.title,
                            ),
                            selected: prefs.subsystemPresets[sub.id] == pr.id,
                            onTap: () => Navigator.of(c2).pop(sub.id),
                          ),
                      ],
                    ),
                  );
                  if (id != null)
                    n.update(
                      (x) => x.copyWith(
                        subsystemPresets: {...x.subsystemPresets, id: pr.id},
                        performance: x.performance == DecoPerformance.off
                            ? DecoPerformance.balanced
                            : x.performance,
                      ),
                    );
                },
              ),
            row(
              Icons.web_asset_outlined,
              tr(ctx, 'Use on one page…', 'Usar en una página…'),
              () async {
                final path = await PrismSheet.show<String>(
                  context: context,
                  title: tr(context, 'Show only on', 'Mostrar solo en'),
                  builder: (c2) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final pg in decorPages)
                        PrismListRow(
                          title: Text(
                            Localizations.localeOf(context).languageCode == 'es'
                                ? pg.$3
                                : pg.$2,
                          ),
                          selected: prefs.pagePresets[pg.$1] == pr.id,
                          onTap: () => Navigator.of(c2).pop(pg.$1),
                        ),
                    ],
                  ),
                );
                if (path != null)
                  n.update(
                    (x) => x.copyWith(
                      pagePresets: {...x.pagePresets, path: pr.id},
                      performance: x.performance == DecoPerformance.off
                          ? DecoPerformance.balanced
                          : x.performance,
                    ),
                  );
              },
            ),
            if (prefs.alterPresets.containsValue(pr.id) ||
                prefs.subsystemPresets.containsValue(pr.id) ||
                prefs.pagePresets.containsValue(pr.id))
              row(
                Icons.link_off,
                tr(
                  ctx,
                  'Remove from alters, subsystems and pages',
                  'Quitar de alters, subsistemas y páginas',
                ),
                () async {
                  n.update(
                    (x) => x.copyWith(
                      alterPresets: {
                        for (final e in x.alterPresets.entries)
                          if (e.value != pr.id) e.key: e.value,
                      },
                      subsystemPresets: {
                        for (final e in x.subsystemPresets.entries)
                          if (e.value != pr.id) e.key: e.value,
                      },
                      pagePresets: {
                        for (final e in x.pagePresets.entries)
                          if (e.value != pr.id) e.key: e.value,
                      },
                    ),
                  );
                },
              ),
            row(
              Icons.meeting_room_outlined,
              pr.isRoom
                  ? tr(ctx, 'Room settings…', 'Ajustes de la sala…')
                  : tr(ctx, 'Make it a Digital Room…', 'Convertir en sala…'),
              () async => showRoomSettings(context, ref, pr),
            ),
            row(
              Icons.edit_outlined,
              tr(ctx, 'Edit in the Studio', 'Editar en el Estudio'),
              () async => context.push(
                AppRoutePaths.seasonalStudio,
                extra: 'preset:${pr.id}',
              ),
            ),
            row(
              Icons.copy_outlined,
              tr(ctx, 'Duplicate', 'Duplicar'),
              () async => actions.duplicate(pr),
            ),
            row(
              Icons.ios_share,
              tr(ctx, 'Export', 'Exportar'),
              () => _export(pr),
            ),
            row(Icons.delete_outline, tr(ctx, 'Delete', 'Eliminar'), () async {
              final ok = await PrismDialog.confirm(
                context: context,
                title: tr(
                  context,
                  'Delete ${pr.name}?',
                  '¿Eliminar ${pr.name}?',
                ),
                confirmLabel: tr(context, 'Delete', 'Eliminar'),
                destructive: true,
              );
              if (ok) await actions.delete(pr.id);
            }, destructive: true),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final presets = ref.watch(decorPresetsProvider);
    final prefs = ref.watch(seasonalPrefsProvider);
    final theme = Theme.of(context);
    final cats = {for (final p in presets) p.category};
    final shown = presets
        .where(
          (p) =>
              (!widget.rooms || p.isRoom) &&
              (_category == null || p.category == _category),
        )
        .toList();
    final subNames = {
      for (final sub in ref.watch(subsystemsProvider)) sub.id: sub.title,
    };
    final names = ref.watch(memberNamesProvider);
    String where(DecorPreset pr) {
      final w = <String>[
        if (prefs.activePresetId == pr.id)
          tr(context, 'Everywhere', 'En todas partes'),
        for (final e in prefs.alterPresets.entries)
          if (e.value == pr.id)
            names[e.key] ?? tr(context, 'An alter', 'Un alter'),
        for (final e in prefs.subsystemPresets.entries)
          if (e.value == pr.id)
            subNames[e.key] ?? tr(context, 'A subsystem', 'Un subsistema'),
        for (final e in prefs.pagePresets.entries)
          if (e.value == pr.id) e.key,
      ];
      return w.join(' · ');
    }

    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: widget.rooms
            ? tr(context, 'Digital Rooms', 'Salas digitales')
            : tr(context, 'My arrangements', 'Mis arreglos'),
        showBackButton: true,
      ),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 40 + NavBarInset.of(context)),
          children: [
            const AppearanceUndoBanner(),
            if (widget.rooms)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  tr(
                    context,
                    'A room is a whole decorated space: its furniture and decorations, living look, layout, weather and lighting, ambient sound and companions. Make as many as you like, give one to an alter or subsystem so it opens when they front, and share them as files. Rooms only decorate; your Headspace map stays separate.',
                    'Una sala es un espacio decorado completo: muebles, estilo vivo, diseño, clima, luz, sonido y compañeros. Asígnala a un alter o subsistema para que se abra al estar al frente. Tu mapa del Headspace sigue aparte.',
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: widget.rooms
                      ? PrismButton(
                          label: tr(
                            context,
                            'New room from what\'s showing',
                            'Nueva sala con lo que se ve',
                          ),
                          icon: Icons.add,
                          tone: PrismButtonTone.filled,
                          onPressed: _newRoom,
                        )
                      : PrismButton(
                          label: tr(
                            context,
                            'New in Studio',
                            'Nuevo en el Estudio',
                          ),
                          icon: Icons.add,
                          tone: PrismButtonTone.filled,
                          onPressed: () =>
                              context.push(AppRoutePaths.seasonalStudio),
                        ),
                ),
                const SizedBox(width: 8),
                PrismButton(
                  label: tr(context, 'Import', 'Importar'),
                  icon: Icons.download_outlined,
                  tone: PrismButtonTone.outlined,
                  onPressed: _import,
                ),
              ],
            ),
            if (cats.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    PrismChip(
                      label: tr(context, 'All', 'Todos'),
                      selected: _category == null,
                      onTap: () => setState(() => _category = null),
                    ),
                    for (final c in cats)
                      PrismChip(
                        label: c,
                        selected: _category == c,
                        onTap: () => setState(
                          () => _category = _category == c ? null : c,
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            if (shown.isEmpty && _category == null)
              PrismSurface(
                padding: const EdgeInsets.all(16),
                child: Text(
                  widget.rooms
                      ? tr(
                          context,
                          'No rooms yet. Decorate the way you like, then save it as a room here.',
                          'Aún no hay salas. Decora a tu gusto y guárdalo aquí como sala.',
                        )
                      : tr(
                          context,
                          'No arrangements yet. Build one in the Decoration Studio and save it here, or import one.',
                          'Aún no hay arreglos. Crea uno en el Estudio y guárdalo aquí, o importa uno.',
                        ),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            for (final pr in shown)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: PrismSurface(
                  padding: const EdgeInsets.all(10),
                  onTap: () => _menu(pr),
                  child: Row(
                    children: [
                      _thumb(pr),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(pr.name, style: theme.textTheme.titleMedium),
                            Text(
                              '${pr.category} · ${pr.items.length} ${tr(context, 'decorations', 'decoraciones')}',
                              style: theme.textTheme.bodySmall,
                            ),
                            if (pr.description.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  pr.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                            if (where(pr).isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '✓ ${where(pr)}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Icon(Icons.more_vert),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
