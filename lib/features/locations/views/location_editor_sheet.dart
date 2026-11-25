import 'package:prism_plurality/shared/theme/prism_shapes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/domain/models/location.dart';
import 'package:prism_plurality/features/calendar/widgets/calendar_colors.dart';
import 'package:prism_plurality/features/locations/providers/location_providers.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_dialog.dart';
import 'package:prism_plurality/shared/widgets/prism_emoji_picker.dart';
import 'package:prism_plurality/shared/widgets/prism_glass_icon_button.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_switch_row.dart';
import 'package:prism_plurality/shared/widgets/prism_text_field.dart';

Future<void> showLocationEditor(
  BuildContext context, {
  SavedLocation? editing,
}) {
  return PrismSheet.showFullScreen(
    context: context,
    builder: (context, scroll) =>
        LocationEditorSheet(editing: editing, scrollController: scroll),
  );
}

/// Create or edit a saved location.
class LocationEditorSheet extends ConsumerStatefulWidget {
  const LocationEditorSheet({super.key, this.editing, this.scrollController});

  final SavedLocation? editing;
  final ScrollController? scrollController;

  @override
  ConsumerState<LocationEditorSheet> createState() =>
      _LocationEditorSheetState();
}

class _LocationEditorSheetState extends ConsumerState<LocationEditorSheet> {
  late final _name = TextEditingController(text: widget.editing?.name ?? '');
  late final _address = TextEditingController(
    text: widget.editing?.address ?? '',
  );
  late final _notes = TextEditingController(text: widget.editing?.notes ?? '');
  late String? _emoji = widget.editing?.emoji ?? '📍';
  late String? _color = widget.editing?.colorHex;
  late bool _favorite = widget.editing?.isFavorite ?? false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _saving) return;
    setState(() => _saving = true);
    final n = ref.read(locationsNotifierProvider.notifier);
    final e = widget.editing;
    if (e == null) {
      await n.createLocation(
        name: _name.text,
        emoji: _emoji,
        colorHex: _color,
        address: _address.text,
        notes: _notes.text,
        isFavorite: _favorite,
      );
    } else {
      await n.saveLocation(
        e.copyWith(
          name: _name.text.trim(),
          emoji: _emoji,
          colorHex: _color,
          address: _address.text.trim().isEmpty ? null : _address.text.trim(),
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          isFavorite: _favorite,
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    final ok = await PrismDialog.confirm(
      context: context,
      title: l10n.locationsDeleteTitle,
      message: l10n.locationsDeleteMessage(widget.editing!.name),
      confirmLabel: l10n.delete,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    if (!ok || !mounted) return;
    await ref
        .read(locationsNotifierProvider.notifier)
        .deleteLocation(widget.editing!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: _name,
      builder: (context, _) {
        final canSave = _name.text.trim().isNotEmpty && !_saving;
        return SafeArea(
          child: Column(
            children: [
              PrismSheetTopBar(
                title: widget.editing == null
                    ? l10n.locationsNewTitle
                    : l10n.locationsEditTitle,
                trailing: PrismGlassIconButton(
                  icon: AppIcons.check,
                  tooltip: l10n.save,
                  size: PrismTokens.topBarActionSize,
                  tint: canSave ? theme.colorScheme.primary : null,
                  accentIcon: canSave,
                  onPressed: canSave ? _save : null,
                ),
              ),
              Expanded(
                child: ListView(
                  controller: widget.scrollController,
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  children: [
                    Row(
                      children: [
                        Semantics(
                          button: true,
                          label: l10n.locationsChooseIcon,
                          child: InkWell(
                            borderRadius: prismCorners(context, 16),
                            onTap: () async {
                              final picked = await PrismEmojiPicker.showPicker(
                                context,
                              );
                              if (picked != null) {
                                setState(() => _emoji = picked);
                              }
                            },
                            child: Container(
                              width: 56,
                              height: 56,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color:
                                    (parseHexColor(_color) ??
                                            theme.colorScheme.primary)
                                        .withValues(alpha: 0.18),
                                borderRadius: prismCorners(context, 16),
                              ),
                              child: Text(
                                _emoji ?? '📍',
                                style: const TextStyle(fontSize: 28),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PrismTextField(
                            controller: _name,
                            labelText: l10n.locationsNameLabel,
                            autofocus: widget.editing == null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final hex in [null, ...calendarColorSwatches])
                          InkWell(
                            customBorder: prismCircleBorder(context),
                            onTap: () => setState(() => _color = hex),
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                borderRadius: prismRound(context),
                                color:
                                    parseHexColor(hex) ??
                                    theme.colorScheme.primary,
                                border: Border.all(
                                  width: 3,
                                  color: _color == hex
                                      ? theme.colorScheme.onSurface
                                      : Colors.transparent,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    PrismTextField(
                      controller: _address,
                      labelText: l10n.locationsAddressLabel,
                    ),
                    const SizedBox(height: 12),
                    PrismTextField(
                      controller: _notes,
                      labelText: l10n.locationsNotesLabel,
                      maxLines: 4,
                      minLines: 2,
                    ),
                    const SizedBox(height: 12),
                    PrismSwitchRow(
                      title: l10n.locationsFavorite,
                      icon: AppIcons.star,
                      value: _favorite,
                      onChanged: (v) => setState(() => _favorite = v),
                    ),
                    if (widget.editing != null) ...[
                      const SizedBox(height: 24),
                      PrismButton(
                        label: l10n.delete,
                        tone: PrismButtonTone.destructive,
                        onPressed: _delete,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
