import 'dart:async';
import 'dart:convert';

import 'package:prism_plurality/shared/widgets/section_switcher.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:prism_plurality/core/constants/fronting_namespaces.dart';
import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/members/studio/profile_config.dart';
import 'package:prism_plurality/features/members/studio/profile_view.dart';
import 'package:prism_plurality/features/members/utils/birthday.dart';
import 'package:prism_plurality/features/social/services/social_media.dart'
    show prepareSocialImage;
import 'package:prism_plurality/features/subsystems/hub/subsystem_data.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/media/prism_media.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import 'package:prism_plurality/shared/utils/avatar_image_picker.dart';

/// Opens Profile Studio to create a new alter or edit [memberId].
Future<String?> openProfileStudio(BuildContext context, {String? memberId}) =>
    Navigator.of(context, rootNavigator: true).push<String>(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => ProfileStudioScreen(memberId: memberId),
        transitionsBuilder: (_, a, _, child) => SlideTransition(
          position: Tween(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(a),
          child: child,
        ),
      ),
    );

const _studioColors = [
  0xFFB9A6FF,
  0xFFFF8FD8,
  0xFF7FB6FF,
  0xFF8FF0D8,
  0xFFFFC37F,
  0xFFFF8A8A,
  0xFF9EE37F,
  0xFFE3E3FF,
  0xFF000000,
  0xFF120E2B,
  0xFF0B1A33,
  0xFF22402B,
  0xFFFFE3F1,
  0xFFE3ECFF,
  0xFFFFFFFF,
];
const _stickers = [
  '✦',
  '🌙',
  '⭐',
  '🌸',
  '☁️',
  '🦋',
  '🌿',
  '🍄',
  '🔥',
  '🌊',
  '❄️',
  '💜',
  '🎧',
  '🎨',
  '🕯️',
  '🐾',
];

/// Basic member fields edited by the studio (written through the member
/// repository so the main profile stays the single source for them).
class _Basic {
  _Basic({
    this.name = '',
    this.displayName = '',
    this.pronouns = '',
    this.emoji = '❔',
    this.age = '',
    this.bio = '',
    this.birthday,
    this.color,
    this.avatar,
    this.header,
  });
  String name, displayName, pronouns, emoji, age, bio;
  String? birthday;
  int? color;
  Uint8List? avatar, header;

  _Basic copy() => _Basic(
    name: name,
    displayName: displayName,
    pronouns: pronouns,
    emoji: emoji,
    age: age,
    bio: bio,
    birthday: birthday,
    color: color,
    avatar: avatar,
    header: header,
  );
  Map<String, Object?> toJson() => {
    'name': name,
    'displayName': displayName,
    'pronouns': pronouns,
    'emoji': emoji,
    'age': age,
    'bio': bio,
    'birthday': birthday,
    'color': color,
  };
  void fromJson(Map m) {
    name = '${m['name'] ?? name}';
    displayName = '${m['displayName'] ?? ''}';
    pronouns = '${m['pronouns'] ?? ''}';
    emoji = '${m['emoji'] ?? emoji}';
    age = '${m['age'] ?? ''}';
    bio = '${m['bio'] ?? ''}';
    birthday = m['birthday'] as String?;
    color = (m['color'] as num?)?.toInt();
  }

  static _Basic of(Member m) => _Basic(
    name: m.name,
    displayName: m.displayName ?? '',
    pronouns: m.pronouns ?? '',
    emoji: m.emoji,
    age: m.age ?? '',
    bio: m.bio ?? '',
    birthday: m.birthday,
    color: m.customColorEnabled ? _hexColor(m.customColorHex) : null,
    avatar: m.avatarImageData,
    header: m.profileHeaderImageData,
  );
}

int? _hexColor(String? hex) {
  final h = (hex ?? '').replaceAll('#', '').trim();
  if (h.length != 6 && h.length != 8) return null;
  final v = int.tryParse(h.length == 8 ? h.substring(2) : h, radix: 16);
  return v == null ? null : 0xFF000000 | v;
}

class _Snap {
  _Snap(this.basic, this.cfg);
  final _Basic basic;
  final ProfileConfig cfg;
}

enum _Section { identity, appearance, personality, advanced }

class ProfileStudioScreen extends ConsumerStatefulWidget {
  const ProfileStudioScreen({super.key, this.memberId});
  final String? memberId;
  @override
  ConsumerState<ProfileStudioScreen> createState() =>
      _ProfileStudioScreenState();
}

class _ProfileStudioScreenState extends ConsumerState<ProfileStudioScreen> {
  late final String _id = widget.memberId ?? const Uuid().v4();
  bool get _isNew => widget.memberId == null;
  Member? _original;
  _Basic _b = _Basic();
  ProfileConfig _cfg = ProfileConfig.empty();
  late _Snap _start;
  final _undo = <_Snap>[];
  final _redo = <_Snap>[];
  Timer? _coalesce;
  Timer? _autosave;
  bool _pendingSnap = false;
  int _rev = 0; // bumps when fields must reload their text (undo/import/reset)
  _Section _section = _Section.identity;
  bool _showPreview = false;
  bool _loading = true;
  bool _saving = false;
  bool _avatarChanged = false;
  bool _headerChanged = false;
  Map<String, Object?>? _draft;

  String get _draftKey => 'profile_studio_draft_${widget.memberId ?? 'new'}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_isNew) {
      final m = await ref.read(memberRepositoryProvider).getMemberById(_id);
      if (m != null) {
        _original = m;
        _b = _Basic.of(m);
      }
      // Wait for the saved records so the editor always opens on the
      // current profile (never on an empty one that would overwrite it).
      final keep = ref.listenManual(trackerRecordsProvider, (_, _) {});
      try {
        final all = await ref
            .read(trackerRecordsProvider.future)
            .timeout(const Duration(seconds: 10));
        final rec = all
            .where(
              (r) => r.kind == TrackerKind.memberProfile && r.parentId == _id,
            )
            .firstOrNull;
        final raw = rec?.fields['cfg'];
        if (raw is Map)
          _cfg = ProfileConfig(raw.cast<String, Object?>()).clone();
      } catch (_) {
        final existing = ref.read(memberProfileProvider(_id));
        if (existing != null) _cfg = existing.clone();
      } finally {
        keep.close();
      }
      // Older studio versions kept a separate description next to the bio,
      // which made the bio look appended. Fold it into the bio once.
      final desc = _cfg.str('description').trim();
      if (desc.isNotEmpty) {
        if (_b.bio.trim().isEmpty) {
          _b.bio = desc;
          _cfg = _cfg.set('description', null);
        } else if (_b.bio.contains(desc)) {
          _cfg = _cfg.set('description', null);
        }
      }
    }
    _start = _Snap(_b.copy(), _cfg.clone());
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftKey);
      if (raw != null) {
        final d = jsonDecode(raw) as Map<String, Object?>;
        if (jsonEncode(d['cfg']) != jsonEncode(_cfg.data) ||
            jsonEncode(d['basic']) != jsonEncode(_b.toJson()))
          _draft = d;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _coalesce?.cancel();
    _autosave?.cancel();
    super.dispose();
  }

  // ── Editing, undo/redo & autosave ──

  void _edit(void Function() change, {bool coalesce = false}) {
    if (!coalesce || !_pendingSnap) {
      _undo.add(_Snap(_b.copy(), _cfg.clone()));
      if (_undo.length > 100) _undo.removeAt(0);
      _redo.clear();
    }
    setState(change);
    if (coalesce) {
      _pendingSnap = true;
      _coalesce?.cancel();
      _coalesce = Timer(
        const Duration(milliseconds: 700),
        () => _pendingSnap = false,
      );
    } else {
      _pendingSnap = false;
    }
    _autosave?.cancel();
    _autosave = Timer(const Duration(milliseconds: 1200), _writeDraft);
  }

  void _setCfg(
    ProfileConfig Function(ProfileConfig c) f, {
    bool coalesce = false,
  }) => _edit(() => _cfg = f(_cfg), coalesce: coalesce);

  Future<void> _writeDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _draftKey,
        jsonEncode({
          'basic': _b.toJson(),
          'cfg': _cfg.data,
          'at': DateTime.now().toIso8601String(),
        }),
      );
    } catch (_) {}
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
    } catch (_) {}
  }

  void _restore(_Snap s) {
    _b = s.basic.copy();
    _cfg = s.cfg.clone();
    _rev++;
  }

  void _doUndo() {
    if (_undo.isEmpty) return;
    _redo.add(_Snap(_b.copy(), _cfg.clone()));
    setState(() => _restore(_undo.removeLast()));
  }

  void _doRedo() {
    if (_redo.isEmpty) return;
    _undo.add(_Snap(_b.copy(), _cfg.clone()));
    setState(() => _restore(_redo.removeLast()));
  }

  static const _sectionCfgKeys = {
    _Section.identity: [
      'altNames',
      'pronounSets',
      'gender',
      'ageRange',
      'species',
      'origin',
      'subtitle',
      'status',
      'description',
      'roles',
    ],
    _Section.appearance: ['appearance'],
    _Section.personality: ['traits', ...personalityListIds],
    _Section.advanced: [
      'frontPrefs',
      'coFronters',
      'internalRoles',
      'tags',
      'memories',
      'modules',
      'custom',
      'gallery',
      'music',
      'links',
      'pinned',
      'labels',
      'fieldOrder',
      'privacy',
    ],
  };

  void _resetSection(_Section s) => _edit(() {
    for (final k in _sectionCfgKeys[s]!) {
      _cfg = _cfg.set(k, _start.cfg[k]);
    }
    final o = _start.basic;
    if (s == _Section.identity) {
      _b
        ..name = o.name
        ..displayName = o.displayName
        ..pronouns = o.pronouns
        ..emoji = o.emoji
        ..age = o.age
        ..bio = o.bio
        ..birthday = o.birthday;
    } else if (s == _Section.appearance) {
      _b
        ..avatar = o.avatar
        ..header = o.header
        ..color = o.color;
      _avatarChanged = false;
      _headerChanged = false;
    }
    _rev++;
  });

  // ── Save ──

  Future<void> _save() async {
    if (_b.name.trim().isEmpty) {
      setState(() => _section = _Section.identity);
      PrismToast.show(
        context,
        message: tr(
          context,
          'Give this alter a name first.',
          'Primero ponle un nombre a este alter.',
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final hex = _b.color == null
        ? null
        : (_b.color! & 0xFFFFFF)
              .toRadixString(16)
              .padLeft(6, '0')
              .toUpperCase();
    final notifier = ref.read(membersNotifierProvider.notifier);
    String? opt(String v) => v.trim().isEmpty ? null : v.trim();
    if (_original == null) {
      await notifier.createMember(
        id: _id,
        name: _b.name.trim(),
        displayName: opt(_b.displayName),
        pronouns: opt(_b.pronouns),
        emoji: _b.emoji.trim().isEmpty ? '❔' : _b.emoji.trim(),
        age: opt(_b.age),
        bio: opt(_b.bio),
        birthday: _b.birthday,
        customColorHex: hex,
        avatarImageData: _b.avatar,
        profileHeaderImageData: _b.header,
      );
    } else {
      // Start from the member as saved right now so nothing edited elsewhere
      // is lost, and only touch images the user changed in the studio.
      final latest =
          await ref.read(memberRepositoryProvider).getMemberById(_id) ??
          _original!;
      await notifier.updateMember(
        latest.copyWith(
          name: _b.name.trim(),
          displayName: opt(_b.displayName),
          pronouns: opt(_b.pronouns),
          emoji: _b.emoji.trim().isEmpty ? '❔' : _b.emoji.trim(),
          age: opt(_b.age),
          bio: opt(_b.bio),
          birthday: _b.birthday,
          customColorEnabled: _b.color != _start.basic.color
              ? hex != null
              : latest.customColorEnabled,
          customColorHex: _b.color != _start.basic.color
              ? hex
              : latest.customColorHex,
          avatarImageData: _avatarChanged ? _b.avatar : latest.avatarImageData,
          profileHeaderImageData: _headerChanged
              ? _b.header
              : latest.profileHeaderImageData,
        ),
      );
    }
    await ref.read(profileStudioActionsProvider).saveProfile(_id, _cfg);
    await _clearDraft();
    if (!mounted) return;
    PrismToast.show(
      context,
      message: tr(context, 'Profile saved', 'Perfil guardado'),
      icon: PhosphorIcons.check(),
    );
    Navigator.of(context).pop(_id);
  }

  /// Leaves without saving (after confirming) and drops the draft.
  Future<void> _cancel() async {
    if (_undo.isNotEmpty) {
      final ok = await PrismDialog.confirm(
        context: context,
        title: tr(context, 'Discard changes?', '¿Descartar cambios?'),
        message: tr(
          context,
          'The profile stays exactly as it was last saved.',
          'El perfil queda tal como se guardó por última vez.',
        ),
        destructive: true,
        confirmLabel: tr(context, 'Discard', 'Descartar'),
        cancelLabel: tr(context, 'Keep editing', 'Seguir editando'),
      );
      if (ok != true) return;
    }
    await _clearDraft();
    if (mounted) Navigator.of(context).pop();
  }

  /// Puts every field back to the last saved values.
  Future<void> _resetAll() async {
    final ok = await PrismDialog.confirm(
      context: context,
      title: tr(
        context,
        'Reset all changes?',
        '¿Restablecer todos los cambios?',
      ),
      message: tr(
        context,
        'Every field goes back to what was last saved.',
        'Todos los campos vuelven a lo último guardado.',
      ),
      confirmLabel: tr(context, 'Reset', 'Restablecer'),
      cancelLabel: context.l10n.cancel,
    );
    if (ok != true) return;
    _edit(() {
      _restore(_start);
      _avatarChanged = false;
      _headerChanged = false;
    });
  }

  Future<bool> _confirmLeave() async {
    final dirty = _undo.isNotEmpty;
    if (!dirty) return true;
    final ok = await PrismDialog.confirm(
      context: context,
      title: tr(context, 'Leave Profile Studio?', '¿Salir de Profile Studio?'),
      message: tr(
        context,
        'Your changes are kept as a draft and offered next time.',
        'Tus cambios se guardan como borrador y se ofrecerán la próxima vez.',
      ),
      confirmLabel: tr(context, 'Leave', 'Salir'),
      cancelLabel: context.l10n.cancel,
    );
    if (ok == true) await _writeDraft();
    return ok == true;
  }

  Member get _previewMember {
    final hex = _b.color == null
        ? null
        : (_b.color! & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
    final base =
        _original ?? Member(id: _id, name: '', createdAt: DateTime.now());
    return base.copyWith(
      name: _b.name.trim().isEmpty
          ? tr(context, 'New alter', 'Nuevo alter')
          : _b.name.trim(),
      displayName: _b.displayName.trim().isEmpty ? null : _b.displayName.trim(),
      pronouns: _b.pronouns.trim().isEmpty ? null : _b.pronouns,
      emoji: _b.emoji,
      age: _b.age.trim().isEmpty ? null : _b.age,
      bio: _b.bio.trim().isEmpty ? null : _b.bio,
      birthday: _b.birthday,
      customColorEnabled: hex != null,
      customColorHex: hex,
      avatarImageData: _b.avatar,
      profileHeaderImageData: _b.header,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const PrismPageScaffold(body: PrismLoadingState());
    final sections = [
      (
        _Section.identity,
        '01',
        tr(context, 'Basic identity', 'Identidad básica'),
      ),
      (
        _Section.appearance,
        '02',
        tr(context, 'Profile appearance', 'Apariencia del perfil'),
      ),
      (
        _Section.personality,
        '03',
        tr(context, 'Personality & identity', 'Personalidad e identidad'),
      ),
      (
        _Section.advanced,
        '04',
        tr(context, 'Advanced settings', 'Ajustes avanzados'),
      ),
    ];
    final preview = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: StudioProfileView(
        member: _previewMember,
        cfg: _cfg,
        preview: true,
      ),
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmLeave()) nav.pop();
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
              _doUndo,
          const SingleActivator(
            LogicalKeyboardKey.keyZ,
            control: true,
            shift: true,
          ): _doRedo,
          const SingleActivator(LogicalKeyboardKey.keyY, control: true):
              _doRedo,
          const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
        },
        child: PrismPageScaffold(
          topBar: PrismTopBar(
            title: _isNew
                ? tr(context, 'New alter', 'Nuevo alter')
                : tr(context, 'Profile Studio', 'Profile Studio'),
            showBackButton: true,
            actions: [
              PrismTopBarAction(
                icon: PhosphorIcons.arrowCounterClockwise(),
                tooltip: tr(context, 'Undo', 'Deshacer'),
                onPressed: _undo.isEmpty ? null : _doUndo,
              ),
              PrismTopBarAction(
                icon: PhosphorIcons.arrowClockwise(),
                tooltip: tr(context, 'Redo', 'Rehacer'),
                onPressed: _redo.isEmpty ? null : _doRedo,
              ),
              PrismTopBarAction(
                icon: PhosphorIcons.floppyDisk(),
                tooltip: tr(context, 'Save', 'Guardar'),
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
          bodyPadding: EdgeInsets.zero,
          bottomBar: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: Row(
                children: [
                  PrismButton(label: context.l10n.cancel, onPressed: _cancel),
                  const SizedBox(width: 8),
                  PrismButton(
                    label: tr(context, 'Reset', 'Restablecer'),
                    icon: PhosphorIcons.arrowCounterClockwise(),
                    onPressed: _undo.isEmpty ? () {} : _resetAll,
                    enabled: _undo.isNotEmpty,
                  ),
                  const Spacer(),
                  PrismButton(
                    label: tr(context, 'Save', 'Guardar'),
                    icon: PhosphorIcons.check(),
                    tone: PrismButtonTone.filled,
                    isLoading: _saving,
                    onPressed: _saving ? () {} : _save,
                  ),
                ],
              ),
            ),
          ),
          body: LayoutBuilder(
            builder: (context, box) {
              final wide = box.maxWidth >= 980;
              final editor = Column(
                children: [
                  if (_draft != null)
                    _DraftBanner(
                      onRestore: _restoreDraft,
                      onDiscard: () async {
                        await _clearDraft();
                        setState(() => _draft = null);
                      },
                    ),
                  SizedBox(
                    height: 64,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      children: [
                        for (final (s, n, label) in sections)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _SectionTab(
                              number: n,
                              label: label,
                              selected: _section == s,
                              onTap: () => setState(() => _section = s),
                            ),
                          ),
                        if (!wide)
                          _SectionTab(
                            number: '◉',
                            label: tr(context, 'Preview', 'Vista previa'),
                            selected: _showPreview,
                            onTap: () =>
                                setState(() => _showPreview = !_showPreview),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SectionSwitcher(
                      id: !wide && _showPreview ? 'preview' : _section,
                      child: !wide && _showPreview
                          ? preview
                          : KeyedSubtree(
                              key: ValueKey('$_section-$_rev'),
                              child: ListView(
                                padding: EdgeInsets.fromLTRB(
                                  16,
                                  4,
                                  16,
                                  NavBarInset.of(context) + 40,
                                ),
                                children: [
                                  ...switch (_section) {
                                    _Section.identity => _identity(context),
                                    _Section.appearance => _appearance(context),
                                    _Section.personality => _personality(
                                      context,
                                    ),
                                    _Section.advanced => _advanced(context),
                                  },
                                  const SizedBox(height: 24),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: PrismButton(
                                      label: tr(
                                        context,
                                        'Reset this section',
                                        'Restablecer esta sección',
                                      ),
                                      icon:
                                          PhosphorIcons.arrowCounterClockwise(),
                                      onPressed: () => _resetSection(_section),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ],
              );
              if (!wide) return editor;
              return Row(
                children: [
                  SizedBox(width: box.maxWidth * 0.52, child: editor),
                  VerticalDivider(
                    width: 1,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  Expanded(
                    child: ColoredBox(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerLowest,
                      child: preview,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _restoreDraft() {
    final d = _draft;
    if (d == null) return;
    _edit(() {
      if (d['basic'] is Map) _b.fromJson(d['basic'] as Map);
      if (d['cfg'] is Map)
        _cfg = ProfileConfig((d['cfg'] as Map).cast<String, Object?>());
      _draft = null;
      _rev++;
    });
  }

  // ── Field helpers ──

  Widget _text(
    String label,
    String value,
    ValueChanged<String> onChanged, {
    int maxLines = 1,
    String? hint,
    String? helper,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: PrismTextField(
      key: ValueKey('$label-$_rev'),
      initialValue: value,
      labelText: label,
      hintText: hint,
      helperText: helper,
      minLines: maxLines > 1 ? 2 : 1,
      maxLines: maxLines,
      onChanged: (v) => _edit(() => onChanged(v), coalesce: true),
    ),
  );

  Widget _cfgText(
    String key, {
    int maxLines = 1,
    String? label,
    String? hint,
  }) => _text(
    label ?? fieldLabel(context, key, _cfg.labels),
    _cfg.str(key),
    (v) => _cfg = _cfg.set(key, v),
    maxLines: maxLines,
    hint: hint,
  );

  Widget _tags(String key, {String? label}) => _TagInput(
    key: ValueKey('$key-$_rev'),
    label: label ?? fieldLabel(context, key, _cfg.labels),
    values: _cfg.list(key),
    onChanged: (v) => _setCfg((c) => c.set(key, v)),
  );

  Widget _heading(String text, {String? sub}) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (sub != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              sub,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    ),
  );

  Widget _choice<T>(
    List<(T, String)> options,
    T selected,
    ValueChanged<T> onChanged,
  ) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final (v, l) in options)
        PrismChip(label: l, selected: v == selected, onTap: () => onChanged(v)),
    ],
  );

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    int? divisions,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TrackerLabel(label),
      Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        onChanged: (v) => _edit(() => onChanged(v), coalesce: true),
      ),
    ],
  );

  String _privacyLabel(String p) => switch (p) {
    'system' => tr(context, 'System', 'Sistema'),
    'private' => tr(context, 'Private', 'Privado'),
    _ => tr(context, 'Public', 'Público'),
  };

  Widget _privacy(String field) => _choice<String>(
    [
      for (final p in const ['public', 'system', 'private'])
        (p, _privacyLabel(p)),
    ],
    _cfg.privacyOf(field),
    (v) => _setCfg((c) => c.setIn('privacy', field, v == 'public' ? null : v)),
  );

  // ── 01 Basic identity ──

  List<Widget> _identity(BuildContext context) {
    final bday = parseBirthday(_b.birthday);
    return [
      _heading(tr(context, 'Name', 'Nombre')),
      _text(tr(context, 'Name *', 'Nombre *'), _b.name, (v) => _b.name = v),
      _text(
        tr(context, 'Display name', 'Nombre visible'),
        _b.displayName,
        (v) => _b.displayName = v,
      ),
      _tags('altNames'),
      Row(
        children: [
          SizedBox(
            width: 90,
            child: _text(
              tr(context, 'Emoji', 'Emoji'),
              _b.emoji,
              (v) => _b.emoji = v,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _cfgText(
              'subtitle',
              hint: tr(context, 'e.g. The night owl', 'p. ej. La ave nocturna'),
            ),
          ),
        ],
      ),
      _cfgText(
        'status',
        label: tr(context, 'Status message', 'Mensaje de estado'),
      ),
      _heading(
        tr(context, 'Roles', 'Roles'),
        sub: tr(
          context,
          'Type roles separated by spaces — each becomes a pill. Use “Add multi-word role” or "quotes" for roles with spaces.',
          'Escribe roles separados por espacios: cada uno será una píldora. Usa «Añadir rol de varias palabras» o "comillas" para roles con espacios.',
        ),
      ),
      _RoleEditor(
        key: ValueKey('roles-$_rev'),
        roles: _cfg.roles,
        fallback: _b.color == null
            ? Theme.of(context).colorScheme.primary
            : Color(_b.color!),
        onChanged: (r) => _setCfg((c) => c.withRoles(r)),
      ),
      _heading(tr(context, 'Identity', 'Identidad')),
      _text(
        tr(context, 'Main pronouns', 'Pronombres principales'),
        _b.pronouns,
        (v) => _b.pronouns = v,
        hint: 'she/her',
      ),
      _tags(
        'pronounSets',
        label: tr(context, 'More pronoun sets', 'Más pronombres'),
      ),
      _cfgText('gender'),
      Row(
        children: [
          Expanded(
            child: _text(tr(context, 'Age', 'Edad'), _b.age, (v) => _b.age = v),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _cfgText(
              'ageRange',
              label: tr(context, 'Age range', 'Rango de edad'),
              hint: '16–19',
            ),
          ),
        ],
      ),
      TrackerLabel(fieldLabel(context, 'birthday', _cfg.labels)),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          PrismButton(
            label: bday == null
                ? tr(context, 'Set birthday', 'Añadir cumpleaños')
                : formatBirthdayDisplay(bday, context.dateLocale),
            icon: PhosphorIcons.cake(),
            onPressed: () async {
              final d = await showPrismDatePicker(
                context: context,
                initialDate: bday == null || isBirthdayYearHidden(bday)
                    ? DateTime(2000)
                    : bday,
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
              );
              if (d != null) _edit(() => _b.birthday = formatBirthdayWire(d));
            },
          ),
          if (bday != null)
            PrismButton(
              label: tr(context, 'Clear', 'Quitar'),
              onPressed: () => _edit(() => _b.birthday = null),
            ),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        tr(context, 'Birthday visibility', 'Visibilidad del cumpleaños'),
        style: Theme.of(context).textTheme.labelMedium,
      ),
      const SizedBox(height: 6),
      _privacy('birthday'),
      const SizedBox(height: 12),
      _cfgText('species'),
      _cfgText('origin'),
      _heading(
        tr(context, 'Bio', 'Bio'),
        sub: tr(
          context,
          'This is the alter’s bio — editing it here changes the same bio shown on their profile.',
          'Esta es la bio del alter: editarla aquí cambia la misma bio de su perfil.',
        ),
      ),
      _text(tr(context, 'Bio', 'Bio'), _b.bio, (v) => _b.bio = v, maxLines: 12),
      if (_cfg.str('description').isNotEmpty ||
          _start.cfg.str('description').isNotEmpty)
        _cfgText(
          'description',
          maxLines: 4,
          label: tr(
            context,
            'Extra description (shown under About)',
            'Descripción extra (en «Sobre mí»)',
          ),
        ),
    ];
  }

  // ── 02 Appearance ──

  Future<void> _pickAvatar() async {
    final bytes = await AvatarImagePicker.pickCroppedAvatarBytes(context);
    if (bytes != null)
      _edit(() {
        _b.avatar = bytes;
        _avatarChanged = true;
      });
  }

  Future<void> _pickBanner() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null) return;
    final prepared = await compute(prepareSocialImage, await x.readAsBytes());
    if (prepared != null)
      _edit(() {
        _b.header = prepared.bytes;
        _headerChanged = true;
      });
  }

  Future<String?> _pickMedia() => PrismMedia.pickImage(ref, owner: _id);

  List<Widget> _appearance(BuildContext context) {
    final look = _cfg;
    final deco = [
      for (final d in (look.look('decorations') as List?) ?? const [])
        if (d is String) d,
    ];
    return [
      _heading(
        tr(context, 'Presets', 'Preajustes'),
        sub: tr(
          context,
          'Start from a look, then fine-tune it. Only appearance changes.',
          'Empieza con un estilo y ajústalo. Solo cambia la apariencia.',
        ),
      ),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final (_, en, es, data) in profilePresets)
            PrismChip(
              label: tr(context, en, es),
              selected: false,
              onTap: () => _setCfg(
                (c) => c.applyTemplate({...c.templatePart(), ...data}),
              ),
            ),
        ],
      ),
      _heading(tr(context, 'Avatar', 'Avatar')),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          PrismButton(
            label: tr(context, 'Photo', 'Foto'),
            icon: PhosphorIcons.image(),
            onPressed: _pickAvatar,
          ),
          PrismButton(
            label: tr(context, 'Animated (GIF)', 'Animado (GIF)'),
            icon: PhosphorIcons.filmStrip(),
            onPressed: () async {
              final id = await _pickMedia();
              if (id != null) _setCfg((c) => c.withLook('avatarMedia', id));
            },
          ),
          if (_b.avatar != null || look.look('avatarMedia') != null)
            PrismButton(
              label: tr(context, 'Remove', 'Quitar'),
              tone: PrismButtonTone.destructive,
              onPressed: () => _edit(() {
                _b.avatar = null;
                _avatarChanged = true;
                _cfg = _cfg.withLook('avatarMedia', null);
              }),
            ),
        ],
      ),
      const SizedBox(height: 10),
      TrackerLabel(tr(context, 'Avatar shape', 'Forma del avatar')),
      _choice<String>(
        [
          ('circle', tr(context, 'Circle', 'Círculo')),
          ('rounded', tr(context, 'Rounded', 'Redondeado')),
          ('square', tr(context, 'Square', 'Cuadrado')),
          ('hexagon', tr(context, 'Hexagon', 'Hexágono')),
        ],
        look.lookStr('avatarShape', 'circle'),
        (v) => _setCfg((c) => c.withLook('avatarShape', v)),
      ),
      _heading(tr(context, 'Banner', 'Banner')),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          PrismButton(
            label: tr(context, 'Banner image', 'Imagen del banner'),
            icon: PhosphorIcons.image(),
            onPressed: _pickBanner,
          ),
          PrismButton(
            label: tr(context, 'Animated banner', 'Banner animado'),
            icon: PhosphorIcons.filmStrip(),
            onPressed: () async {
              final id = await _pickMedia();
              if (id != null) _setCfg((c) => c.withLook('bannerMedia', id));
            },
          ),
          if (_b.header != null || look.look('bannerMedia') != null)
            PrismButton(
              label: tr(context, 'Remove', 'Quitar'),
              tone: PrismButtonTone.destructive,
              onPressed: () => _edit(() {
                _b.header = null;
                _headerChanged = true;
                _cfg = _cfg.withLook('bannerMedia', null);
              }),
            ),
        ],
      ),
      const SizedBox(height: 8),
      _slider(
        tr(context, 'Banner height', 'Altura del banner'),
        look.lookNum('bannerHeight', 170),
        100,
        320,
        (v) => _cfg = _cfg.withLook('bannerHeight', v.roundToDouble()),
      ),
      _slider(
        tr(context, 'Banner overlay', 'Capa del banner'),
        look.lookNum('bannerOverlay', 0.25),
        0,
        0.9,
        (v) => _cfg = _cfg.withLook(
          'bannerOverlay',
          double.parse(v.toStringAsFixed(2)),
        ),
      ),
      _slider(
        tr(context, 'Banner position', 'Posición del banner'),
        look.lookNum('bannerPosition', 0),
        -1,
        1,
        (v) => _cfg = _cfg.withLook(
          'bannerPosition',
          double.parse(v.toStringAsFixed(2)),
        ),
      ),
      TrackerLabel(tr(context, 'Alignment', 'Alineación')),
      _choice<String>(
        [
          ('left', tr(context, 'Left', 'Izquierda')),
          ('center', tr(context, 'Centre', 'Centro')),
          ('right', tr(context, 'Right', 'Derecha')),
        ],
        look.lookStr('bannerAlign', 'center'),
        (v) => _setCfg((c) => c.withLook('bannerAlign', v)),
      ),
      _heading(tr(context, 'Colours & background', 'Colores y fondo')),
      TrackerLabel(tr(context, 'Accent colour', 'Color de acento')),
      ColorChoiceRow(
        value: look.lookColor('accent') ?? _b.color,
        colors: _studioColors,
        onChanged: (v) => _setCfg((c) => c.withLook('accent', v)),
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        children: [
          PrismChip(
            label: tr(
              context,
              'Use as member colour too',
              'Usar también como color del miembro',
            ),
            selected: _b.color != null && _b.color == look.lookColor('accent'),
            onTap: () => _edit(() => _b.color = look.lookColor('accent')),
          ),
          PrismChip(
            label: tr(context, 'Follow app theme', 'Seguir el tema'),
            selected: look.lookColor('accent') == null,
            onTap: () => _setCfg((c) => c.withLook('accent', null)),
          ),
        ],
      ),
      const SizedBox(height: 10),
      TrackerLabel(tr(context, 'Background', 'Fondo')),
      _choice<String>(
        [
          ('none', tr(context, 'Theme', 'Tema')),
          ('gradient', tr(context, 'Gradient', 'Degradado')),
          ('image', tr(context, 'Image', 'Imagen')),
        ],
        look.lookStr('bgMode', 'none'),
        (v) => _setCfg((c) => c.withLook('bgMode', v)),
      ),
      if (look.lookStr('bgMode', 'none') != 'none') ...[
        const SizedBox(height: 8),
        ColorChoiceRow(
          value: look.lookColor('bg1'),
          colors: _studioColors,
          onChanged: (v) => _setCfg((c) => c.withLook('bg1', v)),
        ),
        const SizedBox(height: 6),
        ColorChoiceRow(
          value: look.lookColor('bg2'),
          colors: _studioColors,
          onChanged: (v) => _setCfg((c) => c.withLook('bg2', v)),
        ),
      ],
      if (look.lookStr('bgMode', 'none') == 'image') ...[
        const SizedBox(height: 8),
        PrismButton(
          label: tr(
            context,
            'Choose background image',
            'Elegir imagen de fondo',
          ),
          icon: PhosphorIcons.image(),
          onPressed: () async {
            final id = await _pickMedia();
            if (id != null) _setCfg((c) => c.withLook('bgMedia', id));
          },
        ),
      ],
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          tr(
            context,
            'Text colour adjusts to the background automatically so it stays readable.',
            'El color del texto se ajusta al fondo para que siempre se lea bien.',
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
      _heading(tr(context, 'Typography & borders', 'Tipografía y bordes')),
      _choice<String>(
        [
          ('standard', tr(context, 'Standard', 'Estándar')),
          ('display', tr(context, 'Display', 'Display')),
          ('serif', 'Serif'),
          ('mono', 'Mono'),
          ('rounded', tr(context, 'Rounded', 'Redondeada')),
        ],
        look.lookStr('font', 'standard'),
        (v) => _setCfg((c) => c.withLook('font', v)),
      ),
      const SizedBox(height: 10),
      _choice<String>(
        [
          ('none', tr(context, 'No border', 'Sin borde')),
          ('thin', tr(context, 'Thin', 'Fino')),
          ('glow', tr(context, 'Glow', 'Brillo')),
          ('double', tr(context, 'Bold', 'Grueso')),
        ],
        look.lookStr('border', 'thin'),
        (v) => _setCfg((c) => c.withLook('border', v)),
      ),
      _heading(
        tr(context, 'Decorations & stickers', 'Decoraciones y pegatinas'),
        sub: tr(
          context,
          'Up to six appear on the banner.',
          'Hasta seis aparecen en el banner.',
        ),
      ),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final s in _stickers)
            PrismChip(
              label: s,
              selected: deco.contains(s),
              onTap: () => _setCfg(
                (c) => c.withLook(
                  'decorations',
                  deco.contains(s)
                      ? (deco..remove(s))
                      : (deco.length >= 6 ? deco : (deco..add(s))),
                ),
              ),
            ),
        ],
      ),
    ];
  }

  // ── 03 Personality ──

  List<Widget> _personality(BuildContext context) {
    final traits = _cfg.traits;
    return [
      _heading(
        tr(context, 'Traits', 'Rasgos'),
        sub: tr(
          context,
          'With an intensity from 1 to 5.',
          'Con una intensidad de 1 a 5.',
        ),
      ),
      for (final (i, (name, level)) in traits.indexed)
        Row(
          children: [
            SizedBox(
              width: 120,
              child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              child: Slider(
                value: level.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                label: '$level',
                onChanged: (v) => _setCfg(
                  (c) => c.withTraits([...traits]..[i] = (name, v.round())),
                  coalesce: true,
                ),
              ),
            ),
            PrismTopBarAction(
              icon: AppIcons.close,
              tooltip: tr(context, 'Remove', 'Quitar'),
              onPressed: () =>
                  _setCfg((c) => c.withTraits([...traits]..removeAt(i))),
            ),
          ],
        ),
      _AddLine(
        hint: tr(
          context,
          'Add a trait (e.g. Curious)',
          'Añade un rasgo (p. ej. Curioso)',
        ),
        onAdd: (v) => _setCfg((c) => c.withTraits([...traits, (v, 3)])),
      ),
      _heading(tr(context, 'Likes & interests', 'Gustos e intereses')),
      for (final k in const [
        'likes',
        'dislikes',
        'hobbies',
        'favMusic',
        'favMedia',
        'favColors',
        'favFoods',
      ])
        _tags(k),
      _heading(tr(context, 'Character', 'Carácter')),
      for (final k in const [
        'strengths',
        'weaknesses',
        'habits',
        'communication',
        'boundaries',
      ])
        _tags(k),
      _heading(tr(context, 'Quotes & facts', 'Citas y datos')),
      for (final k in const ['quotes', 'facts']) _tags(k),
    ];
  }

  // ── 04 Advanced ──

  List<Widget> _advanced(BuildContext context) {
    final members = [
      for (final m
          in ref.watch(allMemberListProvider).value ?? const <Member>[])
        if (m.id != _id && m.id != unknownSentinelMemberId) m,
    ];
    final prefer = ref.watch(memberNamePreferDisplayProvider);
    final co = _cfg.list('coFronters');
    final subs = ref
        .watch(subMembershipsProvider)
        .where((m) => m.memberId == _id)
        .map((m) => m.subsystemId)
        .toSet();
    final subRecords = [
      for (final s in ref.watch(subsystemsProvider))
        if (subs.contains(s.id)) s,
    ];
    final modules = _cfg.modules;
    final custom = _cfg.records('custom');
    final order = _cfg.fieldOrder;
    final templates = ref.watch(profileTemplatesProvider);
    return [
      _heading(tr(context, 'System information', 'Información del sistema')),
      _cfgText('frontPrefs', maxLines: 4),
      TrackerLabel(tr(context, 'Usual co-fronters', 'Co-frentes habituales')),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final m in members)
            PrismChip(
              label: m.effectiveName(preferDisplayName: prefer),
              selected: co.contains(m.id),
              onTap: () => _setCfg(
                (c) => c.set(
                  'coFronters',
                  co.contains(m.id) ? (co..remove(m.id)) : (co..add(m.id)),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 10),
      _tags('internalRoles'),
      _tags('tags'),
      TrackerLabel(tr(context, 'Subsystems', 'Subsistemas')),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final s in subRecords)
            PrismChip(
              label: '${s.str('emoji') ?? '✦'} ${s.title}',
              selected: true,
              onTap: () => context.push('${AppRoutePaths.subsystems}/${s.id}'),
            ),
          PrismButton(
            label: tr(context, 'Manage subsystems', 'Gestionar subsistemas'),
            density: PrismControlDensity.compact,
            onPressed: () => context.push(AppRoutePaths.subsystems),
          ),
        ],
      ),
      _RecordList(
        key: ValueKey('memories-$_rev'),
        title: tr(context, 'Memories', 'Recuerdos'),
        fields: [
          ('title', tr(context, 'Title', 'Título')),
          ('body', tr(context, 'Memory', 'Recuerdo')),
        ],
        items: _cfg.records('memories'),
        onChanged: (v) => _setCfg((c) => c.set('memories', v)),
      ),
      _heading(tr(context, 'Pinned note', 'Nota fijada')),
      _cfgText(
        'pinned',
        maxLines: 4,
        label: tr(context, 'Pinned note', 'Nota fijada'),
      ),
      _heading(tr(context, 'Layout', 'Diseño')),
      TrackerLabel(tr(context, 'Phone layout', 'Diseño en teléfono')),
      _choice<String>(
        _layouts(context),
        _cfg.lookStr('layout', 'cards'),
        (v) => _setCfg((c) => c.withLook('layout', v)),
      ),
      const SizedBox(height: 8),
      TrackerLabel(
        tr(
          context,
          'Tablet & desktop layout',
          'Diseño en tableta y escritorio',
        ),
      ),
      _choice<String>(
        _layouts(context),
        _cfg.lookStr('layoutDesktop', _cfg.lookStr('layout', 'cards')),
        (v) => _setCfg((c) => c.withLook('layoutDesktop', v)),
      ),
      _heading(
        tr(context, 'Modules', 'Módulos'),
        sub: tr(
          context,
          'Drag to reorder; switch off to hide.',
          'Arrastra para reordenar; desactiva para ocultar.',
        ),
      ),
      ReorderableListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        onReorder: (a, b) => _setCfg((c) {
          final list = [...modules];
          final item = list.removeAt(a);
          list.insert(b > a ? b - 1 : b, item);
          return c.withModules(list);
        }),
        children: [
          for (final (i, (id, visible)) in modules.indexed)
            Row(
              key: ValueKey('mod-$id'),
              children: [
                ReorderableDragStartListener(
                  index: i,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(PhosphorIcons.dotsSixVertical(), size: 18),
                  ),
                ),
                Expanded(
                  child: PrismSwitchRow(
                    title: moduleLabel(context, id),
                    value: visible,
                    onChanged: (v) => _setCfg(
                      (c) => c.withModules([...modules]..[i] = (id, v)),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      _RecordList(
        key: ValueKey('custom-$_rev'),
        title: tr(
          context,
          'Custom cards & sections',
          'Tarjetas y secciones personalizadas',
        ),
        fields: [
          ('title', tr(context, 'Section title', 'Título de la sección')),
          ('body', tr(context, 'Text', 'Texto')),
        ],
        items: custom,
        reorderable: true,
        hideable: true,
        onChanged: (v) => _setCfg((c) => c.set('custom', v)),
      ),
      _heading(tr(context, 'Gallery', 'Galería')),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final g in _cfg.list('gallery'))
            GestureDetector(
              onLongPress: () => _setCfg(
                (c) => c.set('gallery', c.list('gallery')..remove(g)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: PrismMediaView(id: g),
                ),
              ),
            ),
          PrismButton(
            label: tr(context, 'Add photos', 'Añadir fotos'),
            icon: AppIcons.add,
            onPressed: () async {
              final ids = await PrismMedia.pickImages(ref, owner: _id);
              if (ids.isNotEmpty)
                _setCfg(
                  (c) => c.set('gallery', [...c.list('gallery'), ...ids]),
                );
            },
          ),
        ],
      ),
      if (_cfg.list('gallery').isNotEmpty)
        Text(
          tr(
            context,
            'Long-press a photo to remove it.',
            'Mantén pulsada una foto para quitarla.',
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      _RecordList(
        key: ValueKey('music-$_rev'),
        title: tr(context, 'Music & media', 'Música y medios'),
        fields: [
          ('title', tr(context, 'Title', 'Título')),
          ('artist', tr(context, 'Artist / creator', 'Artista / creador')),
          ('url', tr(context, 'Link (optional)', 'Enlace (opcional)')),
        ],
        items: _cfg.records('music'),
        onChanged: (v) => _setCfg((c) => c.set('music', v)),
      ),
      _RecordList(
        key: ValueKey('links-$_rev'),
        title: tr(context, 'Links', 'Enlaces'),
        fields: [('label', tr(context, 'Label', 'Etiqueta')), ('url', 'URL')],
        items: _cfg.records('links'),
        onChanged: (v) => _setCfg((c) => c.set('links', v)),
      ),
      _heading(
        tr(
          context,
          'Fields, labels & privacy',
          'Campos, etiquetas y privacidad',
        ),
        sub: tr(
          context,
          'Rename, reorder and choose who sees each field. Private fields stay hidden until tapped.',
          'Renombra, reordena y elige quién ve cada campo. Los privados se ocultan hasta tocarlos.',
        ),
      ),
      ReorderableListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        onReorder: (a, b) => _setCfg((c) {
          final list = [...order];
          final item = list.removeAt(a);
          list.insert(b > a ? b - 1 : b, item);
          return c.set('fieldOrder', list);
        }),
        children: [
          for (final (i, f) in order.indexed)
            Padding(
              key: ValueKey('field-$f'),
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ReorderableDragStartListener(
                    index: i,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 14, 8, 8),
                      child: Icon(PhosphorIcons.dotsSixVertical(), size: 18),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PrismTextField(
                          key: ValueKey('label-$f-$_rev'),
                          initialValue: _cfg.labels[f] ?? '',
                          hintText: fieldLabel(context, f),
                          onChanged: (v) => _setCfg(
                            (c) => c.setIn(
                              'labels',
                              f,
                              v.trim().isEmpty ? null : v.trim(),
                            ),
                            coalesce: true,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _privacy(f),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      TrackerLabel(
        tr(context, 'Other private fields', 'Otros campos privados'),
      ),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final f in const [
            'traits',
            'frontPrefs',
            'memories',
            'boundaries',
            'facts',
          ])
            PrismChip(
              label: '🔒 ${fieldLabel(context, f, _cfg.labels)}',
              selected: _cfg.privacyOf(f) == 'private',
              onTap: () => _setCfg(
                (c) => c.setIn(
                  'privacy',
                  f,
                  c.privacyOf(f) == 'private' ? null : 'private',
                ),
              ),
            ),
        ],
      ),
      _heading(
        tr(context, 'Templates', 'Plantillas'),
        sub: tr(
          context,
          'Templates keep appearance and module layout only — never personal information.',
          'Las plantillas guardan solo apariencia y módulos, nunca información personal.',
        ),
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          PrismButton(
            label: tr(context, 'Save as template', 'Guardar como plantilla'),
            icon: PhosphorIcons.copy(),
            onPressed: _saveTemplate,
          ),
          for (final t in templates)
            PrismChip(
              label: t.title,
              selected: false,
              onTap: () => _templateMenu(t),
            ),
        ],
      ),
      _heading(tr(context, 'Import & export', 'Importar y exportar')),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          PrismButton(
            label: tr(
              context,
              'Export configuration',
              'Exportar configuración',
            ),
            icon: PhosphorIcons.export(),
            onPressed: _export,
          ),
          PrismButton(
            label: tr(
              context,
              'Import configuration',
              'Importar configuración',
            ),
            icon: PhosphorIcons.downloadSimple(),
            onPressed: _import,
          ),
        ],
      ),
    ];
  }

  List<(String, String)> _layouts(BuildContext context) => [
    ('cards', tr(context, 'Cards', 'Tarjetas')),
    ('grid', tr(context, 'Grid', 'Cuadrícula')),
    ('sidebar', tr(context, 'Sidebar', 'Barra lateral')),
    ('full', tr(context, 'Full width', 'Ancho completo')),
  ];

  Future<void> _saveTemplate() async {
    final name = await promptLine(
      context,
      tr(context, 'Template name', 'Nombre de la plantilla'),
    );
    if (name == null || name.trim().isEmpty) return;
    await ref
        .read(profileStudioActionsProvider)
        .saveTemplate(name.trim(), _cfg);
    if (mounted)
      PrismToast.show(
        context,
        message: tr(context, 'Template saved', 'Plantilla guardada'),
        icon: PhosphorIcons.check(),
      );
  }

  Future<void> _templateMenu(TrackerRecord t) async {
    final apply = await PrismDialog.confirm(
      context: context,
      title: t.title,
      message: tr(
        context,
        'Apply this template’s appearance and module layout? Your text and details stay as they are.',
        '¿Aplicar la apariencia y los módulos de esta plantilla? Tus textos y datos se mantienen.',
      ),
      confirmLabel: tr(context, 'Apply', 'Aplicar'),
      cancelLabel: tr(context, 'Delete template', 'Eliminar plantilla'),
    );
    if (apply == true) {
      final raw = t.fields['cfg'];
      if (raw is Map)
        _setCfg((c) => c.applyTemplate(raw.cast<String, Object?>()));
    } else if (apply == false) {
      final del = await PrismDialog.confirm(
        context: context,
        title: tr(context, 'Delete “${t.title}”?', '¿Eliminar «${t.title}»?'),
        destructive: true,
        confirmLabel: tr(context, 'Delete', 'Eliminar'),
        cancelLabel: context.l10n.cancel,
      );
      if (del == true)
        await ref.read(profileStudioActionsProvider).deleteTemplate(t.id);
    }
  }

  Future<void> _export() async {
    final json = const JsonEncoder.withIndent(
      '  ',
    ).convert({'prismProfile': 1, 'basic': _b.toJson(), 'cfg': _cfg.data});
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    PrismToast.show(
      context,
      message: tr(
        context,
        'Copied to the clipboard',
        'Copiado al portapapeles',
      ),
      icon: PhosphorIcons.copy(),
    );
    try {
      await SharePlus.instance.share(ShareParams(text: json, subject: _b.name));
    } catch (_) {}
  }

  Future<void> _import() async {
    final raw = await promptLine(
      context,
      tr(
        context,
        'Paste a profile configuration',
        'Pega una configuración de perfil',
      ),
      multiline: true,
    );
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final d = jsonDecode(raw) as Map<String, Object?>;
      final cfg = d['cfg'];
      if (cfg is! Map) throw const FormatException();
      _edit(() {
        // Imported keys are merged over the current profile; nothing else is removed.
        var next = _cfg.clone();
        for (final e in cfg.entries) {
          next = next.set('${e.key}', e.value);
        }
        _cfg = next;
        if (d['basic'] is Map && _isNew) _b.fromJson(d['basic'] as Map);
        _rev++;
      });
      if (mounted)
        PrismToast.show(
          context,
          message: tr(
            context,
            'Configuration imported',
            'Configuración importada',
          ),
          icon: PhosphorIcons.check(),
        );
    } catch (_) {
      if (mounted)
        PrismToast.show(
          context,
          message: tr(
            context,
            'That doesn’t look like a profile configuration.',
            'Eso no parece una configuración de perfil.',
          ),
        );
    }
  }
}

/// Asks for a single line (or block) of text.
Future<String?> promptLine(
  BuildContext context,
  String title, {
  bool multiline = false,
  String? initial,
}) async {
  final c = TextEditingController(text: initial);
  String? out;
  await PrismSheet.show(
    context: context,
    title: title,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrismTextField(
            controller: c,
            autofocus: true,
            minLines: multiline ? 5 : 1,
            maxLines: multiline ? 12 : 1,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: PrismButton(
              label: tr(ctx, 'OK', 'Aceptar'),
              tone: PrismButtonTone.filled,
              onPressed: () {
                out = c.text;
                Navigator.of(ctx).pop();
              },
            ),
          ),
        ],
      ),
    ),
  );
  return out;
}

class _DraftBanner extends StatelessWidget {
  const _DraftBanner({required this.onRestore, required this.onDiscard});
  final VoidCallback onRestore;
  final VoidCallback onDiscard;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            PhosphorIcons.clockCounterClockwise(),
            size: 18,
            color: scheme.onPrimaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tr(
                context,
                'You have an unsaved draft.',
                'Tienes un borrador sin guardar.',
              ),
              style: TextStyle(color: scheme.onPrimaryContainer),
            ),
          ),
          PrismButton(
            label: tr(context, 'Restore', 'Recuperar'),
            density: PrismControlDensity.compact,
            tone: PrismButtonTone.filled,
            onPressed: onRestore,
          ),
          const SizedBox(width: 4),
          PrismButton(
            label: tr(context, 'Discard', 'Descartar'),
            density: PrismControlDensity.compact,
            onPressed: onDiscard,
          ),
        ],
      ),
    );
  }
}

class _SectionTab extends StatelessWidget {
  const _SectionTab({
    required this.number,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String number;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? scheme.primary : scheme.surfaceContainerHigh,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  number,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: selected ? scheme.onPrimary : scheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: selected ? scheme.onPrimary : scheme.onSurface,
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

/// Role input: spaces split roles into pills; drag to reorder; tap a pill
/// to change its colour, style or visibility.
class _RoleEditor extends StatefulWidget {
  const _RoleEditor({
    super.key,
    required this.roles,
    required this.fallback,
    required this.onChanged,
  });
  final List<ProfileRole> roles;
  final Color fallback;
  final ValueChanged<List<ProfileRole>> onChanged;
  @override
  State<_RoleEditor> createState() => _RoleEditorState();
}

class _RoleEditorState extends State<_RoleEditor> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _commit(String text, {bool keepTail = false}) {
    // Keep an unfinished quoted role or the last word while typing.
    var input = text;
    var tail = '';
    if (keepTail) {
      final quotes = '"'.allMatches(input).length;
      if (quotes.isOdd) {
        final at = input.lastIndexOf('"');
        tail = input.substring(at);
        input = input.substring(0, at);
      } else if (!input.endsWith(' ') && !input.endsWith(',')) {
        final at = input.lastIndexOf(RegExp(r'[\s,]'));
        tail = input.substring(at + 1);
        input = at < 0 ? '' : input.substring(0, at + 1);
      }
    }
    final names = splitRoles(input);
    if (names.isNotEmpty) {
      final have = {for (final r in widget.roles) r.name.toLowerCase()};
      widget.onChanged([
        ...widget.roles,
        for (final n in names)
          if (have.add(n.toLowerCase())) ProfileRole(name: n),
      ]);
    }
    if (_c.text != tail) {
      _c.value = TextEditingValue(
        text: tail,
        selection: TextSelection.collapsed(offset: tail.length),
      );
    }
  }

  Future<void> _addMultiWord() async {
    final v = await promptLine(
      context,
      tr(context, 'Add a multi-word role', 'Añadir un rol de varias palabras'),
    );
    if (v == null || v.trim().isEmpty) return;
    if (widget.roles.any((r) => r.name.toLowerCase() == v.trim().toLowerCase()))
      return;
    widget.onChanged([...widget.roles, ProfileRole(name: v.trim())]);
  }

  Future<void> _editRole(int i) async {
    var r = widget.roles[i];
    final name = TextEditingController(text: r.name);
    await PrismSheet.show(
      context: context,
      title: r.name,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: RolePill(
                  role: r.copyWith(
                    name: name.text.trim().isEmpty ? r.name : name.text.trim(),
                  ),
                  fallback: widget.fallback,
                ),
              ),
              const SizedBox(height: 14),
              PrismTextField(
                controller: name,
                labelText: tr(ctx, 'Role', 'Rol'),
                onChanged: (_) => set(() {}),
              ),
              const SizedBox(height: 12),
              TrackerLabel(tr(ctx, 'Colour', 'Color')),
              ColorChoiceRow(
                value: r.color,
                colors: _studioColors,
                onChanged: (v) => set(() => r = r.copyWith(color: v)),
              ),
              const SizedBox(height: 6),
              PrismChip(
                label: tr(ctx, 'Use accent colour', 'Usar color de acento'),
                selected: r.color == null,
                onTap: () => set(() => r = r.copyWith(clearColor: true)),
              ),
              const SizedBox(height: 12),
              TrackerLabel(tr(ctx, 'Pill style', 'Estilo')),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final (k, en, es) in const [
                    ('soft', 'Soft', 'Suave'),
                    ('solid', 'Solid', 'Sólido'),
                    ('outline', 'Outline', 'Contorno'),
                    ('glow', 'Glow', 'Brillo'),
                  ])
                    PrismChip(
                      label: tr(ctx, en, es),
                      selected: r.style == k,
                      onTap: () => set(() => r = r.copyWith(style: k)),
                    ),
                ],
              ),
              PrismSwitchRow(
                title: tr(ctx, 'Visible on profile', 'Visible en el perfil'),
                value: r.visible,
                onChanged: (v) => set(() => r = r.copyWith(visible: v)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  PrismButton(
                    label: tr(ctx, 'Remove', 'Quitar'),
                    tone: PrismButtonTone.destructive,
                    onPressed: () {
                      widget.onChanged([...widget.roles]..removeAt(i));
                      Navigator.of(ctx).pop();
                    },
                  ),
                  const Spacer(),
                  PrismButton(
                    label: ctx.l10n.save,
                    tone: PrismButtonTone.filled,
                    onPressed: () {
                      widget.onChanged(
                        [...widget.roles]
                          ..[i] = r.copyWith(
                            name: name.text.trim().isEmpty
                                ? r.name
                                : name.text.trim(),
                          ),
                      );
                      Navigator.of(ctx).pop();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roles = widget.roles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrismTextField(
          controller: _c,
          hintText: tr(
            context,
            'Host Protector Caretaker…',
            'Anfitrión Protector Cuidador…',
          ),
          textInputAction: TextInputAction.done,
          onChanged: (v) {
            if (v.endsWith(' ') || v.endsWith(',') || splitRoles(v).length > 1)
              _commit(v, keepTail: true);
          },
          onSubmitted: (v) => _commit(v),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: PrismButton(
            label: tr(
              context,
              'Add multi-word role',
              'Añadir rol de varias palabras',
            ),
            icon: AppIcons.add,
            density: PrismControlDensity.compact,
            onPressed: _addMultiWord,
          ),
        ),
        if (roles.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: ReorderableListView(
              scrollDirection: Axis.horizontal,
              buildDefaultDragHandles: false,
              onReorder: (a, b) {
                final list = [...roles];
                final item = list.removeAt(a);
                list.insert(b > a ? b - 1 : b, item);
                widget.onChanged(list);
              },
              children: [
                for (final (i, r) in roles.indexed)
                  ReorderableDelayedDragStartListener(
                    key: ValueKey('role-${r.name}'),
                    index: i,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        right: 6,
                        top: 4,
                        bottom: 4,
                      ),
                      child: RolePill(
                        role: r,
                        fallback: widget.fallback,
                        onTap: () => _editRole(i),
                        onDelete: () =>
                            widget.onChanged([...roles]..removeAt(i)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            tr(
              context,
              'Long-press and drag to reorder · tap to style',
              'Mantén pulsado y arrastra para reordenar · toca para personalizar',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          Text(
            '${tr(context, 'Banner', 'Banner')}: ${roles.where((r) => r.visible).map((r) => r.name).join(' · ')}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ],
    );
  }
}

/// Chips with an add field (Enter or comma adds).
class _TagInput extends StatefulWidget {
  const _TagInput({
    super.key,
    required this.label,
    required this.values,
    required this.onChanged,
  });
  final String label;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;
  @override
  State<_TagInput> createState() => _TagInputState();
}

class _TagInputState extends State<_TagInput> {
  final _c = TextEditingController();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _add(String raw) {
    final parts = raw
        .split(RegExp(r'[,\n]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && !widget.values.contains(s))
        .toList();
    if (parts.isNotEmpty) widget.onChanged([...widget.values, ...parts]);
    _c.clear();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PrismTextField(
          controller: _c,
          labelText: widget.label,
          hintText: tr(
            context,
            'Type and press Enter',
            'Escribe y pulsa Intro',
          ),
          textInputAction: TextInputAction.done,
          onChanged: (v) {
            if (v.contains(',')) _add(v);
          },
          onSubmitted: _add,
        ),
        if (widget.values.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final v in widget.values)
                PrismChip(
                  label: '$v  ✕',
                  selected: true,
                  onTap: () => widget.onChanged([...widget.values]..remove(v)),
                ),
            ],
          ),
        ],
      ],
    ),
  );
}

class _AddLine extends StatefulWidget {
  const _AddLine({required this.hint, required this.onAdd});
  final String hint;
  final ValueChanged<String> onAdd;
  @override
  State<_AddLine> createState() => _AddLineState();
}

class _AddLineState extends State<_AddLine> {
  final _c = TextEditingController();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _go() {
    final v = _c.text.trim();
    if (v.isEmpty) return;
    widget.onAdd(v);
    _c.clear();
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: PrismTextField(
          controller: _c,
          hintText: widget.hint,
          onSubmitted: (_) => _go(),
        ),
      ),
      const SizedBox(width: 8),
      PrismButton(
        label: tr(context, 'Add', 'Añadir'),
        icon: AppIcons.add,
        onPressed: _go,
      ),
    ],
  );
}

/// Editable list of small records (memories, custom cards, music, links).
class _RecordList extends StatelessWidget {
  const _RecordList({
    super.key,
    required this.title,
    required this.fields,
    required this.items,
    required this.onChanged,
    this.reorderable = false,
    this.hideable = false,
  });
  final String title;
  final List<(String, String)> fields;
  final List<Map<String, Object?>> items;
  final ValueChanged<List<Map<String, Object?>>> onChanged;
  final bool reorderable;
  final bool hideable;

  Future<void> _edit(BuildContext context, int? index) async {
    final current = index == null ? <String, Object?>{} : {...items[index]};
    final ctrls = {
      for (final (k, _) in fields)
        k: TextEditingController(text: '${current[k] ?? ''}'),
    };
    var hidden = current['hidden'] == true;
    await PrismSheet.show(
      context: context,
      title: title,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (k, label) in fields)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: PrismTextField(
                    controller: ctrls[k],
                    labelText: label,
                    minLines: k == 'body' ? 3 : 1,
                    maxLines: k == 'body' ? 10 : 1,
                  ),
                ),
              if (hideable)
                PrismSwitchRow(
                  title: tr(ctx, 'Hidden', 'Oculto'),
                  value: hidden,
                  onChanged: (v) => set(() => hidden = v),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (index != null)
                    PrismButton(
                      label: tr(ctx, 'Delete', 'Eliminar'),
                      tone: PrismButtonTone.destructive,
                      onPressed: () {
                        onChanged([...items]..removeAt(index));
                        Navigator.of(ctx).pop();
                      },
                    ),
                  const Spacer(),
                  PrismButton(
                    label: ctx.l10n.save,
                    tone: PrismButtonTone.filled,
                    onPressed: () {
                      final next = {
                        ...current,
                        for (final (k, _) in fields) k: ctrls[k]!.text.trim(),
                        'hidden': hideable ? hidden : null,
                      }..removeWhere((_, v) => v == null);
                      if (fields.every((f) => '${next[f.$1] ?? ''}'.isEmpty))
                        return;
                      next['id'] ??= const Uuid().v4();
                      onChanged(
                        index == null
                            ? [...items, next]
                            : ([...items]..[index] = next),
                      );
                      Navigator.of(ctx).pop();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget row(int i) {
      final m = items[i];
      return PrismListRow(
        key: ValueKey('rec-${m['id'] ?? i}'),
        dense: true,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        leading: reorderable
            ? ReorderableDragStartListener(
                index: i,
                child: Icon(PhosphorIcons.dotsSixVertical(), size: 18),
              )
            : null,
        title: Text(
          '${m[fields.first.$1] ?? ''}'.isEmpty ? '—' : '${m[fields.first.$1]}',
          style: TextStyle(
            decoration: m['hidden'] == true ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: fields.length > 1 && '${m[fields[1].$1] ?? ''}'.isNotEmpty
            ? Text(
                '${m[fields[1].$1]}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        showChevron: true,
        onTap: () => _edit(context, i),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              PrismButton(
                label: tr(context, 'Add', 'Añadir'),
                icon: AppIcons.add,
                density: PrismControlDensity.compact,
                onPressed: () => _edit(context, null),
              ),
            ],
          ),
        ),
        if (reorderable && items.length > 1)
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorder: (a, b) {
              final list = [...items];
              final item = list.removeAt(a);
              list.insert(b > a ? b - 1 : b, item);
              onChanged(list);
            },
            children: [for (var i = 0; i < items.length; i++) row(i)],
          )
        else
          for (var i = 0; i < items.length; i++) row(i),
      ],
    );
  }
}
