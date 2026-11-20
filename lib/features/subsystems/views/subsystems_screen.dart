import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/domain/models/fronting_session.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/members/providers/member_groups_providers.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/relationships/utils/relationships.dart';
import 'package:prism_plurality/features/subsystems/utils/subsystems.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';
import 'package:prism_plurality/features/trackers/widgets/member_picker.dart';
import 'package:prism_plurality/features/trackers/widgets/tracker_widgets.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/app_shell.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';
import 'package:prism_plurality/shared/widgets/prism_dialog.dart';
import 'package:prism_plurality/shared/widgets/prism_page_scaffold.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_surface.dart';
import 'package:prism_plurality/shared/widgets/prism_switch_row.dart';
import 'package:prism_plurality/shared/widgets/prism_text_field.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar_action.dart';

/// Fronting sessions in the last 30 days, for subsystem shares.
final subsystemFrontingProvider =
    StreamProvider.autoDispose<List<FrontingSession>>((ref) {
      final now = DateTime.now();
      return ref
          .watch(frontingSessionRepositoryProvider)
          .watchSessionsOverlappingRange(
            now.subtract(const Duration(days: 30)),
            now.add(const Duration(minutes: 1)),
          );
    });

List<TrackerRecord> _subsystems(WidgetRef ref) =>
    ref.watch(trackerKindProvider(TrackerKind.subsystem)).value ??
    const <TrackerRecord>[];

Color subsystemColor(TrackerRecord s) =>
    Color(s.integer(SubField.color) ?? trackerPalette.first);

class SubsystemsScreen extends ConsumerWidget {
  const SubsystemsScreen({super.key, this.showBackButton = false});

  final bool showBackButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final all = _subsystems(ref);
    final members = ref.watch(activeMembersProvider).value ?? const <Member>[];
    final assigned = {
      for (final s in all)
        for (final m in subsystemMembers(s)) m.memberId,
    };
    final unassigned = [
      for (final m in members)
        if (!assigned.contains(m.id)) m,
    ];
    final tree = subsystemTree(all);
    final sessions =
        ref.watch(subsystemFrontingProvider).value ?? const <FrontingSession>[];
    final now = DateTime.now();
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: l10n.navSubsystems,
        showBackButton: showBackButton,
        actions: [
          PrismTopBarAction(
            icon: AppIcons.add,
            tooltip: l10n.subNew,
            onPressed: () => showSubsystemEditor(context),
          ),
        ],
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, NavBarInset.of(context) + 24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: PrismTokens.contentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TrackerStatGrid(
                    children: [
                      TrackerStatTile(
                        label: l10n.subStatSubsystems,
                        value: '${all.length}',
                        icon: AppIcons.navSubsystems,
                      ),
                      TrackerStatTile(
                        label: l10n.subStatTopLevel,
                        value: '${all.where((s) => s.parentId == null).length}',
                      ),
                      TrackerStatTile(
                        label: l10n.subStatAssigned,
                        value: '${assigned.length}',
                        icon: AppIcons.peopleOutline,
                      ),
                      TrackerStatTile(
                        label: l10n.subStatUnassigned,
                        value: '${unassigned.length}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (all.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Text(l10n.subEmpty, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          PrismButton(
                            label: l10n.subNew,
                            icon: AppIcons.add,
                            tone: PrismButtonTone.filled,
                            onPressed: () => showSubsystemEditor(context),
                          ),
                        ],
                      ),
                    ),
                  for (final (s, depth) in tree)
                    Padding(
                      padding: EdgeInsets.only(left: depth * 20.0, bottom: 6),
                      child: PrismSurface(
                        accentColor: subsystemColor(s),
                        onTap: () => PrismSheet.showFullScreen(
                          context: context,
                          builder: (context, scroll) => SubsystemProfileSheet(
                            subsystemId: s.id,
                            scroll: scroll,
                          ),
                        ),
                        child: Row(
                          children: [
                            s.str(SubField.emoji) == null
                                ? Icon(
                                    AppIcons.navSubsystems,
                                    color: subsystemColor(s),
                                  )
                                : Text(
                                    s.str(SubField.emoji)!,
                                    style: theme.textTheme.titleLarge,
                                  ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.title,
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  Text(
                                    [
                                      l10n.subMembersCount(
                                        allMemberIds(s, all).length,
                                      ),
                                      l10n.subFrontingShare(
                                        (frontingShare(
                                                  allMemberIds(s, all),
                                                  sessions,
                                                  now.subtract(
                                                    const Duration(days: 30),
                                                  ),
                                                  now,
                                                ) *
                                                100)
                                            .round(),
                                      ),
                                      ?s.str(SubField.purpose),
                                    ].join(' · '),
                                    style: theme.textTheme.bodySmall,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (s.isPrivate)
                              Icon(AppIcons.privateLock, size: 14),
                          ],
                        ),
                      ),
                    ),
                  if (unassigned.isNotEmpty && all.isNotEmpty) ...[
                    TrackerLabel(l10n.subUnassigned),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final m in unassigned)
                          PrismChip(
                            label: memberLabel(m),
                            selected: false,
                            onTap: () {},
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SubsystemProfileSheet extends ConsumerWidget {
  const SubsystemProfileSheet({
    super.key,
    required this.subsystemId,
    this.scroll,
  });

  final String subsystemId;
  final ScrollController? scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final all = _subsystems(ref);
    final s = all.where((x) => x.id == subsystemId).firstOrNull;
    if (s == null) {
      return SafeArea(
        child: Column(
          children: [
            PrismSheetTopBar(title: l10n.navSubsystems),
            Expanded(child: Center(child: Text(l10n.subGone))),
          ],
        ),
      );
    }
    final members = {
      for (final m in ref.watch(allMembersProvider).value ?? const <Member>[])
        m.id: m,
    };
    final direct = subsystemMembers(s);
    final ids = allMemberIds(s, all);
    final children = all.where((x) => x.parentId == s.id).toList();
    final parent = all.where((x) => x.id == s.parentId).firstOrNull;
    final connections = [
      for (final id in s.strings(SubField.connections))
        ?all.where((x) => x.id == id).firstOrNull,
    ];
    final rels =
        (ref.watch(trackerKindProvider(TrackerKind.relationship)).value ??
                const <TrackerRecord>[])
            .where((r) => isInternal(r) && memberEnds(r).every(ids.contains))
            .toList();
    final sessions =
        ref.watch(subsystemFrontingProvider).value ?? const <FrontingSession>[];
    final now = DateTime.now();
    final share = frontingShare(
      ids,
      sessions,
      now.subtract(const Duration(days: 30)),
      now,
    );
    final rules = s.strings(SubField.rules);
    void open(TrackerRecord x) => PrismSheet.showFullScreen(
      context: context,
      builder: (context, scroll) =>
          SubsystemProfileSheet(subsystemId: x.id, scroll: scroll),
    );
    return SafeArea(
      child: Column(
        children: [
          PrismSheetTopBar(
            title: '${s.str(SubField.emoji) ?? ''} ${s.title}'.trim(),
          ),
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    PrismButton(
                      label: l10n.edit,
                      icon: AppIcons.edit,
                      density: PrismControlDensity.compact,
                      onPressed: () => showSubsystemEditor(context, editing: s),
                    ),
                    PrismButton(
                      label: l10n.subAddChild,
                      icon: AppIcons.add,
                      density: PrismControlDensity.compact,
                      onPressed: () =>
                          showSubsystemEditor(context, parentId: s.id),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                PrivateReveal(
                  isPrivate: s.isPrivate,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TrackerStatGrid(
                        children: [
                          TrackerStatTile(
                            label: l10n.subStatMembers,
                            value: '${ids.length}',
                            icon: AppIcons.peopleOutline,
                            color: subsystemColor(s),
                          ),
                          TrackerStatTile(
                            label: l10n.subStatFronting30,
                            value: '${(share * 100).round()}%',
                            color: subsystemColor(s),
                          ),
                          TrackerStatTile(
                            label: l10n.subStatNested,
                            value: '${children.length}',
                            color: subsystemColor(s),
                          ),
                          TrackerStatTile(
                            label: l10n.subStatRelationships,
                            value: '${rels.length}',
                            color: subsystemColor(s),
                          ),
                        ],
                      ),
                      if (s.body != null) ...[
                        TrackerLabel(l10n.subDescription),
                        Text(s.body!),
                      ],
                      if (s.str(SubField.purpose) != null) ...[
                        TrackerLabel(l10n.subPurpose),
                        Text(s.str(SubField.purpose)!),
                      ],
                      if (s.str(SubField.origin) != null) ...[
                        TrackerLabel(l10n.subOrigin),
                        Text(s.str(SubField.origin)!),
                      ],
                      TrackerLabel(l10n.subMembersAndRoles),
                      if (direct.isEmpty)
                        Text(
                          l10n.subNoMembers,
                          style: theme.textTheme.bodySmall,
                        ),
                      for (final m in direct)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  members[m.memberId] == null
                                      ? '?'
                                      : memberLabel(members[m.memberId]!),
                                ),
                              ),
                              if (m.role != null)
                                Text(
                                  m.role!,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: subsystemColor(s),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      if (rules.isNotEmpty) ...[
                        TrackerLabel(l10n.subRules),
                        for (final r in rules)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text('• $r'),
                          ),
                      ],
                    ],
                  ),
                ),
                TrackerLabel(l10n.subStructure),
                if (parent != null)
                  PrismSurface(
                    onTap: () => open(parent),
                    child: Text(l10n.subPartOf(parent.title)),
                  ),
                for (final c in children)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: PrismSurface(
                      onTap: () => open(c),
                      child: Text(
                        '↳ ${c.title} · ${l10n.subMembersCount(allMemberIds(c, all).length)}',
                      ),
                    ),
                  ),
                if (parent == null && children.isEmpty)
                  Text(l10n.subNoStructure, style: theme.textTheme.bodySmall),
                if (connections.isNotEmpty) ...[
                  TrackerLabel(l10n.subConnections),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final c in connections)
                        PrismChip(
                          label: c.title,
                          selected: false,
                          onTap: () => open(c),
                        ),
                    ],
                  ),
                ],
                if (rels.isNotEmpty) ...[
                  TrackerLabel(l10n.subInternalRelationships),
                  for (final r in rels)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(r.title),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showSubsystemEditor(
  BuildContext context, {
  TrackerRecord? editing,
  String? parentId,
}) => PrismSheet.showFullScreen(
  context: context,
  builder: (context, scroll) => SubsystemEditorSheet(
    editing: editing,
    parentId: parentId,
    scroll: scroll,
  ),
);

class SubsystemEditorSheet extends ConsumerStatefulWidget {
  const SubsystemEditorSheet({
    super.key,
    this.editing,
    this.parentId,
    this.scroll,
  });

  final TrackerRecord? editing;
  final String? parentId;
  final ScrollController? scroll;

  @override
  ConsumerState<SubsystemEditorSheet> createState() => _SubsystemEditorState();
}

class _SubsystemEditorState extends ConsumerState<SubsystemEditorSheet> {
  late final TrackerRecord? _e = widget.editing;
  late final _name = TextEditingController(text: _e?.title ?? '');
  late final _emoji = TextEditingController(
    text: _e?.str(SubField.emoji) ?? '',
  );
  late final _desc = TextEditingController(text: _e?.body ?? '');
  late final _purpose = TextEditingController(
    text: _e?.str(SubField.purpose) ?? '',
  );
  late final _origin = TextEditingController(
    text: _e?.str(SubField.origin) ?? '',
  );
  late final _rules = TextEditingController(
    text: _e?.strings(SubField.rules).join('\n') ?? '',
  );
  late String? _parent = _e?.parentId ?? widget.parentId;
  late int _color =
      _e?.integer(SubField.color) ??
      trackerPalette[DateTime.now().second % trackerPalette.length];
  late final Map<String, TextEditingController> _roles = {
    for (final m
        in _e == null ? const <SubsystemMember>[] : subsystemMembers(_e))
      m.memberId: TextEditingController(text: m.role ?? ''),
  };
  late final Set<String> _connections = {...?_e?.strings(SubField.connections)};
  late String? _linkedGroup = _e?.str(SubField.linkedGroupId);
  late bool _private = _e?.isPrivate ?? false;

  @override
  void dispose() {
    for (final c in [
      _name,
      _emoji,
      _desc,
      _purpose,
      _origin,
      _rules,
      ..._roles.values,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    String? t(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    final fields = <String, Object?>{
      SubField.emoji: t(_emoji),
      SubField.color: _color,
      SubField.purpose: t(_purpose),
      SubField.origin: t(_origin),
      SubField.linkedGroupId: _linkedGroup,
      SubField.members: [
        for (final e in _roles.entries)
          SubsystemMember(memberId: e.key, role: e.value.text.trim()).toJson(),
      ],
      SubField.rules: [
        for (final r in _rules.text.split('\n'))
          if (r.trim().isNotEmpty) r.trim(),
      ],
      SubField.connections: _connections.toList(),
    };
    for (final k in [SubField.members, SubField.rules, SubField.connections]) {
      if ((fields[k] as List).isEmpty) fields[k] = null;
    }
    final n = ref.read(trackerNotifierProvider.notifier);
    final e = _e;
    if (e == null) {
      await n.create(
        kind: TrackerKind.subsystem,
        title: _name.text,
        body: _desc.text,
        parentId: _parent,
        isPrivate: _private,
        fields: fields,
      );
    } else {
      await n.save(
        e
            .copyWith(
              title: _name.text.trim(),
              body: _desc.text,
              parentId: _parent,
              isPrivate: _private,
            )
            .withFields(fields),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final all = _subsystems(ref);
    final members = ref.watch(activeMembersProvider).value ?? const <Member>[];
    final groups = ref.watch(allGroupsProvider).value ?? const [];
    final entries = ref.watch(allGroupEntriesProvider).value ?? const [];
    final parentOptions = [
      for (final s in all)
        if (_e == null || !wouldCycle(_e.id, s.id, all))
          if (s.id != _e?.id) s,
    ];
    return ListenableBuilder(
      listenable: _name,
      builder: (context, _) => TrackerEditorScaffold(
        title: _e == null ? l10n.subNew : l10n.subEdit,
        canSave: _name.text.trim().isNotEmpty,
        onSave: _save,
        scrollController: widget.scroll,
        children: [
          Row(
            children: [
              SizedBox(
                width: 80,
                child: PrismTextField(
                  controller: _emoji,
                  labelText: l10n.subEmoji,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PrismTextField(
                  controller: _name,
                  labelText: l10n.subName,
                  autofocus: _e == null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          PrismTextField(
            controller: _desc,
            labelText: l10n.subDescription,
            maxLines: 4,
          ),
          const SizedBox(height: 12),
          PrismTextField(
            controller: _purpose,
            labelText: l10n.subPurpose,
            helperText: l10n.subPurposeHelp,
          ),
          const SizedBox(height: 12),
          PrismTextField(
            controller: _origin,
            labelText: l10n.subOrigin,
            maxLines: 3,
          ),
          TrackerLabel(l10n.finColor),
          Wrap(
            spacing: 8,
            children: [
              for (final c in trackerPalette)
                InkResponse(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: Border.all(
                        width: _color == c ? 3 : 0,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          TrackerLabel(l10n.subPartOfLabel),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              PrismChip(
                label: l10n.subTopLevel,
                selected: _parent == null,
                onTap: () => setState(() => _parent = null),
              ),
              for (final s in parentOptions)
                PrismChip(
                  label: s.title,
                  selected: _parent == s.id,
                  onTap: () => setState(() => _parent = s.id),
                ),
            ],
          ),
          TrackerLabel(l10n.subMembersAndRoles),
          if (groups.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final g in groups)
                  PrismChip(
                    label: l10n.subImportGroup(g.name),
                    selected: _linkedGroup == g.id,
                    onTap: () => setState(() {
                      _linkedGroup = g.id;
                      for (final e in entries.where((e) => e.groupId == g.id)) {
                        _roles.putIfAbsent(
                          e.memberId,
                          TextEditingController.new,
                        );
                      }
                    }),
                  ),
              ],
            ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final m in members)
                PrismChip(
                  label: memberLabel(m),
                  selected: _roles.containsKey(m.id),
                  onTap: () => setState(
                    () => _roles.containsKey(m.id)
                        ? _roles.remove(m.id)?.dispose()
                        : _roles[m.id] = TextEditingController(),
                  ),
                ),
            ],
          ),
          for (final e in _roles.entries)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: PrismTextField(
                controller: e.value,
                labelText: l10n.subRoleFor(
                  members
                          .where((m) => m.id == e.key)
                          .map((m) => m.name)
                          .firstOrNull ??
                      '?',
                ),
                hintText: l10n.subRoleHint,
              ),
            ),
          if (all.where((s) => s.id != _e?.id).isNotEmpty) ...[
            TrackerLabel(l10n.subConnections),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in all)
                  if (s.id != _e?.id)
                    PrismChip(
                      label: s.title,
                      selected: _connections.contains(s.id),
                      onTap: () => setState(
                        () => _connections.contains(s.id)
                            ? _connections.remove(s.id)
                            : _connections.add(s.id),
                      ),
                    ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          PrismTextField(
            controller: _rules,
            labelText: l10n.subRules,
            helperText: l10n.subRulesHelp,
            maxLines: 6,
            minLines: 2,
          ),
          const SizedBox(height: 12),
          PrismSwitchRow(
            title: l10n.trackerPrivate,
            subtitle: l10n.trackerPrivateHelp,
            icon: AppIcons.privateLock,
            value: _private,
            onChanged: (v) => setState(() => _private = v),
          ),
          if (_e != null)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: PrismButton(
                label: l10n.trackerDelete,
                icon: AppIcons.delete,
                tone: PrismButtonTone.destructive,
                onPressed: () async {
                  final ok = await PrismDialog.confirm(
                    context: context,
                    title: l10n.subDeleteTitle(_e.title),
                    message: l10n.subDeleteMessage,
                    confirmLabel: l10n.trackerDelete,
                    cancelLabel: l10n.cancel,
                    destructive: true,
                  );
                  if (!ok) return;
                  final n = ref.read(trackerNotifierProvider.notifier);
                  for (final c in all.where((x) => x.parentId == _e.id)) {
                    await n.save(c.copyWith(parentId: _e.parentId));
                  }
                  await n.delete(_e.id, children: false);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ),
        ],
      ),
    );
  }
}
