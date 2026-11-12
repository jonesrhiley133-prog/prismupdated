import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/relationships/utils/relationships.dart';
import 'package:prism_plurality/features/relationships/views/relationship_editor.dart';
import 'package:prism_plurality/features/relationships/views/relationship_labels.dart';
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
import 'package:prism_plurality/shared/widgets/prism_date_picker.dart';
import 'package:prism_plurality/shared/widgets/prism_page_scaffold.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_surface.dart';
import 'package:prism_plurality/shared/widgets/prism_text_field.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar_action.dart';

enum _RelTab { overview, list, map }

class RelationshipsScreen extends ConsumerStatefulWidget {
  const RelationshipsScreen({super.key, this.showBackButton = false});

  final bool showBackButton;

  @override
  ConsumerState<RelationshipsScreen> createState() =>
      _RelationshipsScreenState();
}

class _RelationshipsScreenState extends ConsumerState<RelationshipsScreen> {
  _RelTab _tab = _RelTab.overview;
  String? _member;
  String? _type;
  bool _internalOnly = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final all =
        ref.watch(trackerKindProvider(TrackerKind.relationship)).value ??
        const <TrackerRecord>[];
    final events =
        ref.watch(trackerKindProvider(TrackerKind.relationshipEvent)).value ??
        const <TrackerRecord>[];
    final rels = [
      for (final r in all)
        if ((_member == null ||
                memberEnds(r).contains(_member) ||
                r.memberId == _member) &&
            (_type == null || r.str(RelField.type) == _type) &&
            (!_internalOnly || isInternal(r)))
          r,
    ];
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: l10n.navRelationships,
        showBackButton: widget.showBackButton,
        actions: [
          PrismTopBarAction(
            icon: AppIcons.add,
            tooltip: l10n.relNew,
            onPressed: () => showRelationshipEditor(context, memberId: _member),
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
              constraints: const BoxConstraints(
                maxWidth: PrismTokens.contentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final t in _RelTab.values)
                        PrismChip(
                          label: switch (t) {
                            _RelTab.overview => l10n.finTabOverview,
                            _RelTab.list => l10n.relTabAll,
                            _RelTab.map => l10n.relTabMap,
                          },
                          selected: _tab == t,
                          onTap: () => setState(() => _tab = t),
                        ),
                    ],
                  ),
                  TrackerMemberFilter(
                    value: _member,
                    onChanged: (m) => setState(() => _member = m),
                  ),
                  const SizedBox(height: 12),
                  if (all.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Text(l10n.relEmpty, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          PrismButton(
                            label: l10n.relNew,
                            icon: AppIcons.add,
                            tone: PrismButtonTone.filled,
                            onPressed: () => showRelationshipEditor(context),
                          ),
                        ],
                      ),
                    )
                  else
                    ...switch (_tab) {
                      _RelTab.overview => _overview(context, rels, events),
                      _RelTab.list => _list(context, rels),
                      _RelTab.map => _map(context, rels),
                    },
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _overview(
    BuildContext context,
    List<TrackerRecord> rels,
    List<TrackerRecord> events,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final relIds = {for (final r in rels) r.id};
    final ev = [
      for (final e in events)
        if (relIds.contains(e.parentId)) e,
    ];
    final s = RelationshipStats.of(rels, ev, DateTime.now());
    final members = {
      for (final m in ref.watch(allMembersProvider).value ?? const <Member>[])
        m.id: m,
    };
    final types = s.byType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final connected =
        s.connectionsByMember.entries
            .where((e) => members.containsKey(e.key))
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    final recent = [...ev]
      ..sort(
        (a, b) => (b.occurredAt ?? b.createdAt).compareTo(
          a.occurredAt ?? a.createdAt,
        ),
      );
    final relById = {for (final r in rels) r.id: r};
    return [
      TrackerStatGrid(
        children: [
          TrackerStatTile(
            label: l10n.relStatTotal,
            value: '${s.total}',
            icon: AppIcons.navRelationships,
          ),
          TrackerStatTile(
            label: l10n.relStatInternal,
            value: '${s.internal}',
            icon: AppIcons.navSubsystems,
          ),
          TrackerStatTile(
            label: l10n.relStatExternal,
            value: '${s.external}',
            icon: AppIcons.navContacts,
          ),
          TrackerStatTile(
            label: l10n.relStatCloseness,
            value: s.averageCloseness == null
                ? '–'
                : '${s.averageCloseness!.toStringAsFixed(1)} / 5',
            icon: AppIcons.heartOutline,
          ),
          TrackerStatTile(
            label: l10n.relStatTrust,
            value: s.averageTrust == null
                ? '–'
                : '${s.averageTrust!.toStringAsFixed(1)} / 5',
          ),
          TrackerStatTile(
            label: l10n.relStatEvents30,
            value: '${s.eventsLast30}',
          ),
          TrackerStatTile(
            label: l10n.relStatPositive,
            value: s.positiveShare == null
                ? '–'
                : '${(s.positiveShare! * 100).round()}%',
          ),
          TrackerStatTile(
            label: l10n.relStatEnded,
            value: '${s.byStatus['ended'] ?? 0}',
          ),
        ],
      ),
      TrackerLabel(l10n.relByType),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final t in types)
            PrismChip(
              label: '${relTypeLabel(l10n, t.key)} · ${t.value}',
              selected: _type == t.key,
              onTap: () =>
                  setState(() => _type = _type == t.key ? null : t.key),
            ),
        ],
      ),
      if (connected.isNotEmpty) ...[
        TrackerLabel(l10n.relMostConnected),
        for (final e in connected.take(6))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(memberLabel(members[e.key]!))),
                    Text(
                      l10n.relConnections(e.value),
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                TrackerBar(value: e.value / connected.first.value),
              ],
            ),
          ),
      ],
      TrackerLabel(l10n.relRecentHistory),
      if (recent.isEmpty)
        Text(l10n.relNoHistory, style: theme.textTheme.bodySmall),
      for (final e in recent.take(8))
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: PrismSurface(
            onTap: relById[e.parentId] == null
                ? null
                : () => _openProfile(context, relById[e.parentId]!),
            child: Row(
              children: [
                Icon(switch (e.integer(RelField.sentiment)) {
                  1 => AppIcons.heartOutline,
                  -1 => AppIcons.warningAmber,
                  _ => AppIcons.calendarToday,
                }, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.title, style: theme.textTheme.titleSmall),
                      Text(
                        '${DateFormat.yMMMd(context.dateLocale).format(e.occurredAt ?? e.createdAt)} · ${relById[e.parentId]?.title ?? ''}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    ];
  }

  List<Widget> _list(BuildContext context, List<TrackerRecord> rels) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final sorted = [...rels]
      ..sort(
        (a, b) => (b.integer(RelField.closeness) ?? 0).compareTo(
          a.integer(RelField.closeness) ?? 0,
        ),
      );
    return [
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          PrismChip(
            label: l10n.relInternalOnly,
            selected: _internalOnly,
            onTap: () => setState(() => _internalOnly = !_internalOnly),
          ),
          if (_type != null)
            PrismChip(
              label: '${relTypeLabel(l10n, _type!)}  ✕',
              selected: true,
              onTap: () => setState(() => _type = null),
            ),
        ],
      ),
      const SizedBox(height: 8),
      if (sorted.isEmpty)
        Text(l10n.relNoMatches, style: theme.textTheme.bodySmall),
      for (final r in sorted)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: PrismSurface(
            onTap: () => _openProfile(context, r),
            child: Row(
              children: [
                Icon(
                  isInternal(r) ? AppIcons.navSubsystems : AppIcons.navContacts,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.title, style: theme.textTheme.titleSmall),
                      Text(
                        [
                          relTypeLabel(l10n, r.str(RelField.type) ?? 'other'),
                          relStatusLabel(
                            l10n,
                            r.str(RelField.status) ?? 'active',
                          ),
                          if (r.integer(RelField.closeness) != null)
                            l10n.relClosenessValue(
                              r.integer(RelField.closeness)!,
                            ),
                        ].join(' · '),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (r.isPrivate) Icon(AppIcons.privateLock, size: 14),
              ],
            ),
          ),
        ),
    ];
  }

  List<Widget> _map(BuildContext context, List<TrackerRecord> rels) {
    final l10n = context.l10n;
    final members = ref.watch(activeMembersProvider).value ?? const <Member>[];
    final internal = rels.where(isInternal).toList();
    final involved = {for (final r in internal) ...memberEnds(r)};
    final nodes = [
      for (final m in members)
        if (involved.contains(m.id)) m,
    ];
    if (nodes.length < 2)
      return [
        Text(l10n.relMapEmpty, style: Theme.of(context).textTheme.bodySmall),
      ];
    return [
      Text(l10n.relMapHelp, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 8),
      PrismSurface(
        padding: EdgeInsets.zero,
        child: AspectRatio(
          aspectRatio: 1,
          child: InteractiveViewer(
            maxScale: 3,
            child: CustomPaint(
              painter: _RelationshipWebPainter(
                nodes: nodes,
                rels: internal,
                theme: Theme.of(context),
                typeLabel: (t) => relTypeLabel(l10n, t),
              ),
            ),
          ),
        ),
      ),
    ];
  }

  void _openProfile(BuildContext context, TrackerRecord r) =>
      PrismSheet.showFullScreen(
        context: context,
        builder: (context, scroll) =>
            RelationshipProfileSheet(relationshipId: r.id, scroll: scroll),
      );
}

class _RelationshipWebPainter extends CustomPainter {
  _RelationshipWebPainter({
    required this.nodes,
    required this.rels,
    required this.theme,
    required this.typeLabel,
  });

  final List<Member> nodes;
  final List<TrackerRecord> rels;
  final ThemeData theme;
  final String Function(String) typeLabel;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final radius = size.shortestSide * 0.36;
    final pos = <String, Offset>{};
    for (var i = 0; i < nodes.length; i++) {
      final a = -math.pi / 2 + 2 * math.pi * i / nodes.length;
      pos[nodes[i].id] = c + Offset(math.cos(a), math.sin(a)) * radius;
    }
    for (final r in rels) {
      final a = pos[r.memberId], b = pos[r.str(RelField.otherId)];
      if (a == null || b == null) continue;
      final closeness = r.integer(RelField.closeness) ?? 3;
      final ended = r.str(RelField.status) == 'ended';
      final paint = Paint()
        ..color =
            (ended ? theme.colorScheme.outline : theme.colorScheme.primary)
                .withValues(alpha: 0.35 + closeness * 0.12)
        ..strokeWidth = 1 + closeness * 0.8
        ..style = PaintingStyle.stroke;
      canvas.drawLine(a, b, paint);
      final mid = Offset.lerp(a, b, 0.5)!;
      final tp = TextPainter(
        text: TextSpan(
          text: typeLabel(r.str(RelField.type) ?? 'other'),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 90);
      tp.paint(canvas, mid - Offset(tp.width / 2, tp.height / 2));
    }
    for (final m in nodes) {
      final p = pos[m.id]!;
      canvas.drawCircle(
        p,
        22,
        Paint()..color = theme.colorScheme.primaryContainer,
      );
      canvas.drawCircle(
        p,
        22,
        Paint()
          ..color = theme.colorScheme.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      final tp = TextPainter(
        text: TextSpan(text: m.name, style: theme.textTheme.labelMedium),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: 100);
      tp.paint(canvas, p + Offset(-tp.width / 2, 26));
      final initial = TextPainter(
        text: TextSpan(
          text: m.name.isEmpty ? '?' : m.name.characters.first.toUpperCase(),
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      initial.paint(canvas, p - Offset(initial.width / 2, initial.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _RelationshipWebPainter old) =>
      old.nodes != nodes || old.rels != rels;
}

/// Full profile of one relationship with its history of events.
class RelationshipProfileSheet extends ConsumerWidget {
  const RelationshipProfileSheet({
    super.key,
    required this.relationshipId,
    this.scroll,
  });

  final String relationshipId;
  final ScrollController? scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final r =
        (ref.watch(trackerKindProvider(TrackerKind.relationship)).value ??
                const <TrackerRecord>[])
            .where((x) => x.id == relationshipId)
            .firstOrNull;
    if (r == null) {
      return SafeArea(
        child: Column(
          children: [
            PrismSheetTopBar(title: l10n.navRelationships),
            Expanded(child: Center(child: Text(l10n.relGone))),
          ],
        ),
      );
    }
    final events =
        (ref.watch(trackerKindProvider(TrackerKind.relationshipEvent)).value ??
                const <TrackerRecord>[])
            .where((e) => e.parentId == r.id)
            .toList();
    final boundaries = r.strings(RelField.boundaries);
    return SafeArea(
      child: Column(
        children: [
          PrismSheetTopBar(title: r.title),
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
                      onPressed: () =>
                          showRelationshipEditor(context, editing: r),
                    ),
                    PrismButton(
                      label: l10n.relAddEvent,
                      icon: AppIcons.add,
                      density: PrismControlDensity.compact,
                      onPressed: () => _addEvent(context, ref, r),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                PrivateReveal(
                  isPrivate: r.isPrivate,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        [
                          relTypeLabel(l10n, r.str(RelField.type) ?? 'other'),
                          relStatusLabel(
                            l10n,
                            r.str(RelField.status) ?? 'active',
                          ),
                          if (r.occurredAt != null)
                            l10n.relSinceDate(
                              DateFormat.yMMMd(
                                context.dateLocale,
                              ).format(r.occurredAt!),
                            ),
                          if (isInternal(r) && r.flag(RelField.mutual))
                            l10n.relMutual,
                        ].join(' · '),
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.relCloseness,
                                  style: theme.textTheme.labelSmall,
                                ),
                                TrackerBar(
                                  value:
                                      (r.integer(RelField.closeness) ?? 0) / 5,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.relTrust,
                                  style: theme.textTheme.labelSmall,
                                ),
                                TrackerBar(
                                  value: (r.integer(RelField.trust) ?? 0) / 5,
                                  color: theme.colorScheme.tertiary,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (r.str(RelField.dynamics) != null) ...[
                        TrackerLabel(l10n.relDynamics),
                        Text(r.str(RelField.dynamics)!),
                      ],
                      if (boundaries.isNotEmpty) ...[
                        TrackerLabel(l10n.relBoundaries),
                        for (final b in boundaries)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  AppIcons.privateLock,
                                  size: 14,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(b)),
                              ],
                            ),
                          ),
                      ],
                      if (r.body != null) ...[
                        TrackerLabel(l10n.finNote),
                        Text(r.body!),
                      ],
                      if (r.tags.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        TagWrap(tags: r.tags),
                      ],
                    ],
                  ),
                ),
                TrackerLabel(l10n.relHistory(events.length)),
                if (events.isEmpty)
                  Text(l10n.relNoHistory, style: theme.textTheme.bodySmall),
                for (final e in events)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: PrismSurface(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(switch (e.integer(RelField.sentiment)) {
                            1 => AppIcons.heartOutline,
                            -1 => AppIcons.warningAmber,
                            _ => AppIcons.calendarToday,
                          }, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.title,
                                  style: theme.textTheme.titleSmall,
                                ),
                                Text(
                                  DateFormat.yMMMd(
                                    context.dateLocale,
                                  ).format(e.occurredAt ?? e.createdAt),
                                  style: theme.textTheme.bodySmall,
                                ),
                                if (e.body != null) Text(e.body!),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: l10n.trackerDelete,
                            icon: Icon(AppIcons.close, size: 16),
                            onPressed: () => ref
                                .read(trackerNotifierProvider.notifier)
                                .delete(e.id),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addEvent(
    BuildContext context,
    WidgetRef ref,
    TrackerRecord r,
  ) => PrismSheet.show(
    context: context,
    title: context.l10n.relAddEvent,
    builder: (_) => _EventForm(relationship: r),
  );
}

class _EventForm extends ConsumerStatefulWidget {
  const _EventForm({required this.relationship});

  final TrackerRecord relationship;

  @override
  ConsumerState<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends ConsumerState<_EventForm> {
  final _title = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateTime.now();
  int _sentiment = 0;

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: _title,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrismTextField(
            controller: _title,
            labelText: l10n.relEventTitle,
            hintText: l10n.relEventHint,
            autofocus: true,
          ),
          const SizedBox(height: 8),
          PrismTextField(
            controller: _note,
            labelText: l10n.finNote,
            maxLines: 3,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              PrismChip(
                label: l10n.relPositive,
                selected: _sentiment == 1,
                onTap: () => setState(() => _sentiment = 1),
              ),
              PrismChip(
                label: l10n.relNeutral,
                selected: _sentiment == 0,
                onTap: () => setState(() => _sentiment = 0),
              ),
              PrismChip(
                label: l10n.relDifficult,
                selected: _sentiment == -1,
                onTap: () => setState(() => _sentiment = -1),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(DateFormat.yMMMd(context.dateLocale).format(_date)),
              ),
              PrismButton(
                label: l10n.edit,
                density: PrismControlDensity.compact,
                onPressed: () async {
                  final d = await showPrismDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) setState(() => _date = d);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          PrismButton(
            label: l10n.save,
            tone: PrismButtonTone.filled,
            enabled: _title.text.trim().isNotEmpty,
            onPressed: () async {
              await ref
                  .read(trackerNotifierProvider.notifier)
                  .create(
                    kind: TrackerKind.relationshipEvent,
                    parentId: widget.relationship.id,
                    title: _title.text,
                    body: _note.text,
                    occurredAt: _date,
                    memberId: widget.relationship.memberId,
                    fields: {RelField.sentiment: _sentiment},
                  );
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
