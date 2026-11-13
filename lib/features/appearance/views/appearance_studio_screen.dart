import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:prism_plurality/features/appearance/models/look.dart';
import 'package:prism_plurality/features/appearance/services/appearance_store.dart';
import 'package:prism_plurality/features/appearance/views/look_editor_screen.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/look_theme.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/app_shell.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';
import 'package:prism_plurality/shared/widgets/prism_dialog.dart';
import 'package:prism_plurality/shared/widgets/prism_loading_state.dart';
import 'package:prism_plurality/shared/widgets/prism_page_scaffold.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_surface.dart';
import 'package:prism_plurality/shared/widgets/prism_switch_row.dart';
import 'package:prism_plurality/shared/widgets/prism_text_field.dart';
import 'package:prism_plurality/shared/widgets/prism_toast.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar.dart';

/// Theme presets: choose, preview, edit, share and schedule them.
class AppearanceStudioScreen extends ConsumerWidget {
  const AppearanceStudioScreen({super.key});

  Future<String?> _name(BuildContext context, String title, String initial) async {
    final c = TextEditingController(text: initial);
    final l10n = context.l10n;
    final ok = await PrismDialog.show<bool>(
      context: context,
      title: title,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrismTextField(controller: c, autofocus: true, labelText: l10n.apPresetName, onSubmitted: (_) => Navigator.of(context).pop(true)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              PrismButton(label: l10n.cancel, onPressed: () => Navigator.of(context).pop(false)),
              const SizedBox(width: 8),
              PrismButton(label: l10n.save, tone: PrismButtonTone.filled, onPressed: () => Navigator.of(context).pop(true)),
            ],
          ),
        ],
      ),
    );
    final v = c.text.trim();
    return ok == true && v.isNotEmpty ? v : null;
  }

  void _edit(BuildContext context, PrismLook look) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => LookEditorScreen(initial: look)));
  }

  Future<void> _share(BuildContext context, WidgetRef ref, PrismLook look) async {
    final l10n = context.l10n;
    final text = ref.read(appearanceProvider.notifier).export(look);
    try {
      final dir = await getTemporaryDirectory();
      final safe = look.name.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim();
      final f = File(p.join(dir.path, '${safe.isEmpty ? 'theme' : safe}.prismtheme.json'));
      await f.writeAsString(text);
      await SharePlus.instance.share(ShareParams(files: [XFile(f.path)], subject: look.name));
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) PrismToast.success(context, message: l10n.apCopied);
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final choice = await PrismDialog.show<String>(
      context: context,
      title: l10n.apImport,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.apImportHelp),
          const SizedBox(height: 12),
          PrismButton(label: l10n.apImportFile, tone: PrismButtonTone.filled, onPressed: () => Navigator.of(context).pop('file')),
          const SizedBox(height: 8),
          PrismButton(label: l10n.apImportPaste, onPressed: () => Navigator.of(context).pop('paste')),
        ],
      ),
    );
    String? text;
    if (choice == 'file') {
      try {
        final r = await FilePicker.pickFiles(type: FileType.any);
        final path = r?.files.firstOrNull?.path;
        if (path != null) text = await File(path).readAsString();
      } catch (_) {
        text = '';
      }
    } else if (choice == 'paste') {
      text = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
    }
    if (text == null || !context.mounted) return;
    final look = await ref.read(appearanceProvider.notifier).import(text);
    if (!context.mounted) return;
    if (look == null) {
      PrismToast.error(context, message: l10n.apImportInvalid);
    } else {
      PrismToast.success(context, message: l10n.apImported(look.name));
    }
  }

  void _menu(BuildContext context, WidgetRef ref, PrismLook look) {
    final l10n = context.l10n;
    final n = ref.read(appearanceProvider.notifier);
    PrismSheet.show<void>(
      context: context,
      title: look.name,
      builder: (sheet) {
        Widget row(IconData icon, String label, Future<void> Function() onTap, {bool destructive = false}) {
          final theme = Theme.of(sheet);
          final color = destructive ? theme.colorScheme.error : theme.colorScheme.onSurface;
          return Semantics(
            button: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                Navigator.of(sheet).pop();
                await onTap();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                child: Row(children: [Icon(icon, color: color), const SizedBox(width: 14), Expanded(child: Text(label, style: theme.textTheme.bodyLarge?.copyWith(color: color)))]),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              row(Icons.check_circle_outline_rounded, l10n.apApply, () => n.activate(look.id)),
              row(Icons.edit_rounded, look.builtIn ? l10n.apCustomizeCopy : l10n.apEdit, () async {
                _edit(context, look.builtIn ? look.copyWith(id: '', name: l10n.apCopyOf(look.name), builtIn: false) : look);
              }),
              row(Icons.copy_rounded, l10n.apDuplicate, () async {
                final name = await _name(context, l10n.apDuplicate, l10n.apCopyOf(look.name));
                if (name != null) await n.duplicate(look, name);
              }),
              if (!look.builtIn)
                row(Icons.drive_file_rename_outline_rounded, l10n.apRename, () async {
                  final name = await _name(context, l10n.apRename, look.name);
                  if (name != null) await n.rename(look.id, name);
                }),
              row(Icons.ios_share_rounded, l10n.apExport, () => _share(context, ref, look)),
              if (!look.builtIn)
                row(Icons.delete_outline_rounded, l10n.delete, () async {
                  final ok = await PrismDialog.confirm(
                    context: context,
                    title: l10n.apDeleteTitle,
                    message: l10n.apDeleteMessage(look.name),
                    confirmLabel: l10n.delete,
                    cancelLabel: l10n.cancel,
                    destructive: true,
                  );
                  if (ok) await n.deleteLook(look.id);
                }, destructive: true),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final async = ref.watch(appearanceProvider);
    final dark = theme.brightness == Brightness.dark;
    return PrismPageScaffold(
      topBar: PrismTopBar(title: l10n.apTopBar, showBackButton: true),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: async.when(
        loading: () => const PrismLoadingState(),
        error: (e, _) => Center(child: Text(l10n.errorWithDetail(e))),
        data: (state) {
          final n = ref.read(appearanceProvider.notifier);
          final active = state.active(dark: dark);
          final children = <Widget>[
            Text(l10n.apStudioIntro, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: PrismButton(
                    label: l10n.apNewTheme,
                    tone: PrismButtonTone.filled,
                    onPressed: () => _edit(context, active.copyWith(id: '', name: l10n.apMyTheme, builtIn: false)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: PrismButton(label: l10n.apImport, onPressed: () => _import(context, ref))),
              ],
            ),
            const SizedBox(height: 16),
            Text(l10n.apPresets, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, box) {
                final cols = box.maxWidth > 560 ? 3 : 2;
                final w = (box.maxWidth - (cols - 1) * 10) / cols;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final look in state.all)
                      SizedBox(
                        width: w,
                        child: _PresetCard(
                          look: look,
                          active: look.id == active.id,
                          onTap: () => n.activate(look.id),
                          onLongPress: () => _menu(context, ref, look),
                          onMore: () => _menu(context, ref, look),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            PrismSurface(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PrismSwitchRow(
                    title: l10n.apAuto,
                    subtitle: l10n.apAutoHelp,
                    value: state.auto,
                    onChanged: (v) => n.setAuto(auto: v, lightId: state.auto ? null : active.id, darkId: state.auto ? null : active.id),
                  ),
                  if (state.auto) ...[
                    _PresetPicker(label: l10n.apForLight, value: state.lightId, looks: state.all, onChanged: (id) => n.setAuto(lightId: id)),
                    _PresetPicker(label: l10n.apForDark, value: state.darkId, looks: state.all, onChanged: (id) => n.setAuto(darkId: id)),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(l10n.apPageThemes, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(l10n.apPageThemesHelp, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            for (final page in lookPages)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: PrismSurface(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  onTap: () => PrismSheet.show<void>(
                    context: context,
                    title: pageLabel(l10n, page),
                    builder: (sheet) => Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          PrismChip(
                            label: l10n.apSameAsApp,
                            selected: !state.pageLooks.containsKey(page),
                            onTap: () {
                              n.setPageLook(page, null);
                              Navigator.of(sheet).pop();
                            },
                          ),
                          for (final l in state.all)
                            PrismChip(
                              label: l.name,
                              selected: state.pageLooks[page] == l.id,
                              onTap: () {
                                n.setPageLook(page, l.id);
                                Navigator.of(sheet).pop();
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(pageLabel(l10n, page), style: theme.textTheme.bodyLarge)),
                      Text(
                        state.pageLooks.containsKey(page) ? state.look(state.pageLooks[page]!).name : l10n.apSameAsApp,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            SizedBox(height: NavBarInset.of(context) + 24),
          ];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: PrismTokens.contentMaxWidth),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PresetPicker extends StatelessWidget {
  const _PresetPicker({required this.label, required this.value, required this.looks, required this.onChanged});

  final String label;
  final String value;
  final List<PrismLook> looks;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final l in looks) PrismChip(label: l.name, selected: value == l.id, onTap: () => onChanged(l.id))],
          ),
        ],
      ),
    );
  }
}

/// A preset rendered as a tiny screen in its own colours.
class _PresetCard extends StatelessWidget {
  const _PresetCard({required this.look, required this.active, required this.onTap, required this.onLongPress, required this.onMore});

  final PrismLook look;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final base = theme.copyWith(extensions: const []);
    final styled = applyLook(base, look, backgroundDir: LookTheme.of(context)?.backgroundDir);
    final card = look.element(LookElement.card);
    final button = look.element(LookElement.button);
    return Semantics(
      button: true,
      selected: active,
      label: active ? l10n.apPresetActive(look.name) : look.name,
      hint: l10n.apPresetHint,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(width: active ? 3 : 1, color: active ? theme.colorScheme.primary : theme.colorScheme.outlineVariant),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 110,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (look.background.isCustom)
                        LookBackground(spec: look.background, dir: LookTheme.of(context)?.backgroundDir)
                      else
                        ColoredBox(color: styled.scaffoldBackgroundColor),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              height: 34,
                              decoration: BoxDecoration(
                                color: card.color == null ? styled.cardColor : Color(card.color!).withValues(alpha: card.opacity ?? 1),
                                borderRadius: BorderRadius.circular((card.radius ?? 14) / 2),
                                border: card.borderWidth == null || card.borderWidth == 0 ? null : Border.all(color: Color(card.borderColor ?? 0x33888888)),
                              ),
                            ),
                            const Spacer(),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                width: 54,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: Color(button.color ?? styled.colorScheme.primary.toARGB32()),
                                  gradient: button.color2 == null || button.color == null
                                      ? null
                                      : LinearGradient(colors: [Color(button.color!), Color(button.color2!)]),
                                  borderRadius: BorderRadius.circular((button.radius ?? 18) / 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: theme.colorScheme.surfaceContainerHigh,
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 8, 0, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(look.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelLarge),
                              Text(
                                active ? l10n.apActive : (look.builtIn ? l10n.apBuiltIn : l10n.apYours),
                                style: theme.textTheme.labelSmall?.copyWith(color: active ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ),
                      InkResponse(
                        onTap: onMore,
                        radius: 20,
                        child: const Padding(padding: EdgeInsets.all(10), child: Icon(Icons.more_vert_rounded, size: 20)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
