import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/fronting/providers/fronting_providers.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/members/utils/member_search_groups.dart';
import 'package:prism_plurality/features/settings/providers/terminology_provider.dart';
import 'package:prism_plurality/features/social/models/social.dart';
import 'package:prism_plurality/features/social/services/social_actions.dart';
import 'package:prism_plurality/features/social/services/social_data.dart';
import 'package:prism_plurality/features/social/services/social_media.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/widgets/member_avatar.dart';
import 'package:prism_plurality/shared/widgets/member_search_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';

/// The alter the social screens act as. Starts as the current fronter but
/// can be any alter: browsing, posting and reacting never need a switch.
class SocialActor extends Notifier<String?> {
  String? _picked;

  @override
  String? build() {
    final members = ref.watch(activeMemberListProvider).value ?? const <Member>[];
    final picked = members.where((m) => m.id == _picked && m.isActive && !m.isDeleted).firstOrNull;
    if (picked != null) return picked.id;
    final fronter = ref.watch(currentFronterProvider).value;
    return fronter != null && members.any((m) => m.id == fronter.id) ? fronter.id : members.firstOrNull?.id;
  }

  void set(String? id) {
    _picked = id;
    ref.invalidateSelf();
  }
}

final socialActorProvider = NotifierProvider<SocialActor, String?>(SocialActor.new);

Future<String?> pickAlter(BuildContext context, WidgetRef ref, {String? title}) async {
  final members = (ref.read(userVisibleMemberListProvider).value ?? const <Member>[]).where((m) => m.isActive).toList();
  if (members.isEmpty) return null;
  final result = await MemberSearchSheet.showSingle(
    context,
    members: members,
    termPlural: readTerminology(context, ref).plural,
    title: title,
    groups: readMemberSearchGroups(ref, members),
  );
  return result is MemberSearchResultSelected ? result.memberId : null;
}

/// Member avatar with an optional story ring (gradient = unseen, grey = seen).
class AlterAvatar extends ConsumerWidget {
  const AlterAvatar({super.key, required this.memberId, this.size = 40, this.ring, this.onTap});

  final String? memberId;
  final double size;

  /// null: no ring, true: unseen story, false: all seen.
  final bool? ring;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final m = memberId == null ? null : ref.watch(socialDataProvider.select((d) => d.members[memberId]));
    Widget avatar = MemberAvatar(
      memberId: m?.id,
      memberName: m?.name,
      avatarImageData: m?.avatarImageData,
      emoji: m?.emoji ?? '❔',
      customColorEnabled: m?.customColorEnabled ?? false,
      customColorHex: m?.customColorHex,
      size: size,
      deferAvatarLookup: m?.avatarImageData == null,
    );
    if (ring != null) {
      avatar = Container(
        padding: EdgeInsets.all(size * 0.06),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: ring! ? const SweepGradient(colors: [Color(0xFFFF6FA5), Color(0xFFFFB199), Color(0xFF7C4DFF), Color(0xFF18FFFF), Color(0xFFFF6FA5)]) : null,
          color: ring! ? null : theme.colorScheme.outlineVariant,
        ),
        child: Container(
          padding: EdgeInsets.all(size * 0.05),
          decoration: BoxDecoration(shape: BoxShape.circle, color: theme.scaffoldBackgroundColor),
          child: avatar,
        ),
      );
    }
    if (onTap == null) return avatar;
    return Semantics(
      button: true,
      label: m?.name,
      child: InkResponse(onTap: onTap, radius: size * 0.7, child: avatar),
    );
  }
}

String alterName(SocialData d, String? id, BuildContext context) => d.members[id]?.name ?? context.l10n.socUnknownAlter;

/// "Acting as" chip: who is reading, posting and reacting right now.
class ActorChip extends ConsumerWidget {
  const ActorChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final actor = ref.watch(socialActorProvider);
    final name = ref.watch(socialDataProvider.select((d) => d.members[actor]?.name));
    return Semantics(
      button: true,
      label: l10n.socActingAsLabel(name ?? l10n.socNobody),
      hint: l10n.socSwitchActorHint,
      excludeSemantics: true,
      child: Material(
        color: theme.colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () async {
            final id = await pickAlter(context, ref, title: l10n.socActAs);
            if (id != null) ref.read(socialActorProvider.notifier).set(id);
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AlterAvatar(memberId: actor, size: 28),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    name == null ? l10n.socPickAlter : l10n.socActingAs(name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.swap_horiz_rounded, size: 18, color: theme.colorScheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String relativeTime(BuildContext context, DateTime t, {DateTime? now}) {
  final l10n = context.l10n;
  final n = now ?? DateTime.now();
  final d = n.difference(t);
  if (d.isNegative) {
    try {
      return DateFormat.MMMd(l10n.localeName).add_jm().format(t);
    } catch (_) {
      return DateFormat.MMMd().add_jm().format(t);
    }
  }
  if (d.inMinutes < 1) return l10n.socJustNow;
  if (d.inMinutes < 60) return l10n.hwMinutesShort(d.inMinutes);
  if (d.inHours < 24) return l10n.hwHoursShort(d.inHours);
  if (d.inDays < 7) return l10n.hwDaysShort(d.inDays);
  try {
    return DateFormat.MMMd(l10n.localeName).format(t);
  } catch (_) {
    return DateFormat.MMMd().format(t);
  }
}

/// Image from the synced social media store, with a placeholder.
class SocialImage extends ConsumerWidget {
  const SocialImage({super.key, required this.id, this.fit = BoxFit.cover, this.height, this.width, this.semanticLabel});

  final String id;
  final BoxFit fit;
  final double? height;
  final double? width;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bytes = ref.watch(socialImageProvider(id));
    if (bytes == null) {
      return Container(
        height: height,
        width: width,
        color: theme.colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Semantics(label: context.l10n.socImageMissing, child: Icon(Icons.image_not_supported_outlined, color: theme.colorScheme.onSurfaceVariant)),
      );
    }
    return Image.memory(
      bytes,
      fit: fit,
      height: height,
      width: width,
      gaplessPlayback: true,
      semanticLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
      errorBuilder: (_, _, _) => SizedBox(height: height, width: width),
    );
  }
}

/// Emoji reactions under a post, comment or story, plus the add button.
class ReactionBar extends ConsumerWidget {
  const ReactionBar({super.key, required this.targetId, this.dense = false});

  final String targetId;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final actor = ref.watch(socialActorProvider);
    final r = ref.watch(socialDataProvider.select((d) => d.reactions(targetId, actor)));
    final entries = r.counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    Future<void> toggle(String e) async {
      if (actor == null) return;
      await ref.read(socialActionsProvider).toggleReaction(actor: actor, targetId: targetId, emoji: e);
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final e in entries)
          Semantics(
            button: true,
            toggled: r.mine.contains(e.key),
            label: l10n.socReactionCount(e.key, e.value),
            excludeSemantics: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: actor == null ? null : () => toggle(e.key),
              onLongPress: () => showReactors(context, ref, targetId, e.key),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 8, vertical: dense ? 2 : 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: r.mine.contains(e.key) ? theme.colorScheme.primary.withValues(alpha: 0.18) : theme.colorScheme.surfaceContainerHighest,
                  border: Border.all(color: r.mine.contains(e.key) ? theme.colorScheme.primary : Colors.transparent),
                ),
                child: Text('${e.key} ${e.value}', style: theme.textTheme.labelMedium),
              ),
            ),
          ),
        Semantics(
          button: true,
          label: l10n.socAddReaction,
          excludeSemantics: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: actor == null
                ? null
                : () async {
                    final e = await pickReaction(context, ref);
                    if (e != null) await toggle(e);
                  },
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.add_reaction_outlined, size: dense ? 18 : 20, color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> showReactors(BuildContext context, WidgetRef ref, String targetId, String emoji) {
  final d = ref.read(socialDataProvider);
  final who = [for (final r in d.reactionsOn[targetId] ?? const []) if (r.title == emoji) r.memberId];
  return PrismSheet.show<void>(
    context: context,
    title: emoji,
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final id in who)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [AlterAvatar(memberId: id, size: 44), const SizedBox(height: 4), Text(alterName(d, id, context))],
            ),
        ],
      ),
    ),
  );
}

/// Default reactions, the alter's own custom ones, and any emoji typed in.
Future<String?> pickReaction(BuildContext context, WidgetRef ref) {
  final l10n = context.l10n;
  final actor = ref.read(socialActorProvider);
  final custom = actor == null ? const <String>[] : ref.read(socialDataProvider).profile(actor).customReactions;
  final controller = TextEditingController();
  return PrismSheet.show<String>(
    context: context,
    title: l10n.socReact,
    builder: (sheet) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final e in {...custom, ...defaultReactions})
                Semantics(
                  button: true,
                  label: e,
                  child: InkResponse(
                    onTap: () => Navigator.of(sheet).pop(e),
                    radius: 28,
                    child: Padding(padding: const EdgeInsets.all(8), child: Text(e, style: const TextStyle(fontSize: 30))),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            decoration: InputDecoration(labelText: l10n.socAnyEmoji, hintText: '🌈'),
            onSubmitted: (v) {
              final e = v.trim().characters.take(2).toString();
              if (e.isNotEmpty) Navigator.of(sheet).pop(e);
            },
          ),
        ],
      ),
    ),
  );
}

String audienceLabel(BuildContext context, Audience a) {
  final l10n = context.l10n;
  return switch (a) {
    Audience.everyone => l10n.socAudEveryone,
    Audience.followers => l10n.socAudFollowers,
    Audience.selected => l10n.socAudSelected,
    Audience.self => l10n.socAudSelf,
  };
}

IconData audienceIcon(Audience a) => switch (a) {
  Audience.everyone => Icons.public_rounded,
  Audience.followers => Icons.group_rounded,
  Audience.selected => Icons.people_alt_outlined,
  Audience.self => Icons.lock_outline_rounded,
};

/// Text with tappable #tags and highlighted @mentions.
class RichPostText extends StatelessWidget {
  const RichPostText({super.key, required this.text, this.style, this.onTag, this.maxLines});

  final String text;
  final TextStyle? style;
  final ValueChanged<String>? onTag;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = style ?? theme.textTheme.bodyLarge;
    final accent = base?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600);
    final pattern = RegExp('${hashtagPattern.pattern}|${mentionPattern.pattern}', unicode: true);
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in pattern.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      final word = m.group(0)!;
      final tag = m.group(1);
      spans.add(
        tag != null && onTag != null
            ? WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: Semantics(
                  link: true,
                  child: GestureDetector(onTap: () => onTag!(tag), child: Text(word, style: accent)),
                ),
              )
            : TextSpan(text: word, style: accent),
      );
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return Text.rich(TextSpan(style: base, children: spans), maxLines: maxLines, overflow: maxLines == null ? null : TextOverflow.ellipsis);
  }
}
