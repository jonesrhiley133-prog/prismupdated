import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/fronting/providers/fronting_providers.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/trackers/widgets/tracker_widgets.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';

/// The member fronting right now, used to attribute new entries.
String? currentFronterId(WidgetRef ref) =>
    ref.read(currentFronterProvider).value?.id;

Color? _memberColor(Member m) {
  final hex = m.customColorHex;
  if (!m.customColorEnabled || hex == null) return null;
  final v = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
  if (v == null) return null;
  return Color(hex.replaceFirst('#', '').length <= 6 ? 0xFF000000 | v : v);
}

String memberLabel(Member m) {
  final e = m.emoji.trim();
  return e.isEmpty || e == '❔' ? m.name : '$e ${m.name}';
}

/// Chips to choose which alter something belongs to, or the whole system.
/// Hidden when the system has no members yet.
class TrackerMemberPicker extends ConsumerWidget {
  const TrackerMemberPicker({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.noneLabel,
  });

  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? noneLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(activeMembersProvider).value ?? const <Member>[];
    if (members.isEmpty) return const SizedBox.shrink();
    final fronterId = ref.watch(currentFronterProvider).value?.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TrackerLabel(label),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            PrismChip(
              label: noneLabel ?? context.l10n.trackerWholeSystem,
              selected: value == null,
              onTap: () => onChanged(null),
            ),
            for (final m in members)
              PrismChip(
                label: m.id == fronterId
                    ? context.l10n.trackerFrontingNow(memberLabel(m))
                    : memberLabel(m),
                selected: value == m.id,
                selectedColor: _memberColor(m),
                onTap: () => onChanged(m.id),
              ),
          ],
        ),
      ],
    );
  }
}

/// Horizontal filter chips: everyone, or one member's entries.
class TrackerMemberFilter extends ConsumerWidget {
  const TrackerMemberFilter({
    super.key,
    required this.value,
    required this.onChanged,
    this.onlyIds,
  });

  final String? value;
  final ValueChanged<String?> onChanged;

  /// Limit chips to members who have entries.
  final Set<String>? onlyIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = [
      for (final m in ref.watch(allMembersProvider).value ?? const <Member>[])
        if (onlyIds == null || onlyIds!.contains(m.id)) m,
    ];
    if (members.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: PrismChip(
                label: context.l10n.trackerEveryone,
                selected: value == null,
                onTap: () => onChanged(null),
              ),
            ),
            for (final m in members)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: PrismChip(
                  label: memberLabel(m),
                  selected: value == m.id,
                  selectedColor: _memberColor(m),
                  onTap: () => onChanged(value == m.id ? null : m.id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Member name for an id, if known.
String? memberNameFor(WidgetRef ref, String? id) {
  if (id == null) return null;
  for (final m in ref.watch(allMembersProvider).value ?? const <Member>[]) {
    if (m.id == id) return memberLabel(m);
  }
  return null;
}
