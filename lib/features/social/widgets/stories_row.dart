import 'package:prism_plurality/shared/theme/prism_shapes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/features/social/services/social_data.dart';
import 'package:prism_plurality/features/social/views/story_viewer.dart';
import 'package:prism_plurality/features/social/widgets/social_widgets.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';

/// Authors with visible active stories, unseen first, then most recent.
final storyAuthorsProvider = Provider<List<({String id, bool unseen})>>((ref) {
  final viewer = ref.watch(socialActorProvider);
  final d = ref.watch(socialDataProvider);
  final active = d.activeStories(viewer);
  final list =
      [
        for (final e in active.entries)
          (
            id: e.key,
            unseen: e.value.any(
              (s) => !d.hasSeen(s.id, viewer) && s.author != viewer,
            ),
            latest: e.value.last.postedAt,
          ),
      ]..sort((a, b) {
        if (a.unseen != b.unseen) return a.unseen ? -1 : 1;
        return b.latest.compareTo(a.latest);
      });
  return [for (final x in list) (id: x.id, unseen: x.unseen)];
});

/// Horizontal story avatars. Every alter's stories open from here without
/// switching front.
class StoriesRow extends ConsumerWidget {
  const StoriesRow({super.key, this.showAdd = true});
  final bool showAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final authors = ref.watch(storyAuthorsProvider);
    final viewer = ref.watch(socialActorProvider);
    final d = ref.watch(socialDataProvider);
    final mineActive = viewer != null && authors.any((a) => a.id == viewer);
    final others = [
      for (final a in authors)
        if (a.id != viewer) a,
    ];
    if (others.isEmpty && !showAdd) return const SizedBox.shrink();
    final ids = [if (mineActive) viewer, for (final a in others) a.id];
    return Semantics(
      container: true,
      label: l10n.stoTitle,
      child: SizedBox(
        height: 98,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            if (showAdd && viewer != null)
              _Bubble(
                label: l10n.stoYourStory,
                semantics: mineActive ? l10n.stoViewYours : l10n.stoAddStory,
                onTap: () => mineActive
                    ? openStories(context, ids, start: 0)
                    : openStoryComposer(context, viewer),
                onLongPress: () => openStoryComposer(context, viewer),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AlterAvatar(
                      memberId: viewer,
                      size: 58,
                      ring: mineActive ? false : null,
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Semantics(
                        button: true,
                        label: l10n.stoAddStory,
                        excludeSemantics: true,
                        child: GestureDetector(
                          onTap: () => openStoryComposer(context, viewer),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: prismRound(context),
                              color: theme.colorScheme.primary,
                              border: Border.all(
                                color: theme.scaffoldBackgroundColor,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              size: 18,
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            for (var i = 0; i < others.length; i++)
              _Bubble(
                label: alterName(d, others[i].id, context),
                semantics: others[i].unseen
                    ? l10n.stoNewFrom(alterName(d, others[i].id, context))
                    : l10n.stoSeenFrom(alterName(d, others[i].id, context)),
                onTap: () =>
                    openStories(context, ids, start: ids.indexOf(others[i].id)),
                child: AlterAvatar(
                  memberId: others[i].id,
                  size: 58,
                  ring: others[i].unseen,
                ),
              ),
            if (others.isEmpty && showAdd)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    l10n.stoNoneYet,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.label,
    required this.semantics,
    required this.onTap,
    required this.child,
    this.onLongPress,
  });
  final String label;
  final String semantics;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 12),
    child: Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: SizedBox(
          width: 70,
          child: Column(
            children: [
              child,
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Story count helpers for badges.
int unseenStoryAuthors(List<({String id, bool unseen})> a) =>
    a.where((x) => x.unseen).length;
