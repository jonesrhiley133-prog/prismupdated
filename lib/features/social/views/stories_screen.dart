import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/features/settings/views/feature_data_screen.dart';
import 'package:prism_plurality/features/social/models/social.dart';
import 'package:prism_plurality/features/social/services/social_data.dart';
import 'package:prism_plurality/features/social/views/alter_blog_screen.dart';
import 'package:prism_plurality/features/social/views/story_viewer.dart';
import 'package:prism_plurality/features/social/widgets/social_widgets.dart';
import 'package:prism_plurality/features/social/widgets/stories_row.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/app_shell.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_page_scaffold.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar_action.dart';

/// Alter Stories: today's stories from every alter, plus the acting
/// alter's highlights and archive.
class StoriesScreen extends ConsumerWidget {
  const StoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final viewer = ref.watch(socialActorProvider);
    final d = ref.watch(socialDataProvider);
    final authors = ref.watch(storyAuthorsProvider);
    final archive = viewer == null ? const <Story>[] : d.archive(viewer);
    final highlights = viewer == null ? const <Highlight>[] : d.highlightsOf(viewer);
    final ids = [for (final a in authors) a.id];
    final active = d.activeStories(viewer);
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: l10n.stoTitle,
        actions: [FeatureDataAction(featureId: 'stories'), PrismTopBarAction(icon: Icons.add_circle_outline_rounded, tooltip: l10n.stoAddStory, onPressed: () => openStoryComposer(context, viewer))],
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: PrismTokens.contentMaxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(alignment: Alignment.centerLeft, child: ActorChip()),
                  const SizedBox(height: 6),
                  Text(l10n.stoIntro, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 10),
                  const StoriesRow(),
                  const SizedBox(height: 12),
                  if (authors.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          Icon(Icons.auto_awesome_rounded, size: 48, color: theme.colorScheme.primary),
                          const SizedBox(height: 8),
                          Text(l10n.stoEmpty, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
                          const SizedBox(height: 10),
                          PrismButton(label: l10n.stoAddStory, tone: PrismButtonTone.filled, onPressed: () => openStoryComposer(context, viewer)),
                        ],
                      ),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, box) {
                        final cols = (box.maxWidth / 130).floor().clamp(2, 6);
                        final w = (box.maxWidth - (cols - 1) * 8) / cols;
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (var i = 0; i < authors.length; i++)
                              Semantics(
                                button: true,
                                label: authors[i].unseen ? l10n.stoNewFrom(alterName(d, authors[i].id, context)) : l10n.stoSeenFrom(alterName(d, authors[i].id, context)),
                                excludeSemantics: true,
                                child: GestureDetector(
                                  onTap: () => openStories(context, ids, start: i),
                                  child: SizedBox(
                                    width: w,
                                    height: w * 16 / 9,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          StorySlideView(slide: active[authors[i].id]!.last.slides.first, mini: true),
                                          DecoratedBox(
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black38, Colors.transparent, Colors.black54]),
                                              border: authors[i].unseen ? Border.all(color: theme.colorScheme.primary, width: 3) : null,
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                          ),
                                          Positioned(left: 8, top: 8, child: AlterAvatar(memberId: authors[i].id, size: 30, ring: authors[i].unseen)),
                                          Positioned(
                                            left: 8,
                                            right: 8,
                                            bottom: 8,
                                            child: Text(alterName(d, authors[i].id, context), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  if (viewer != null) ...[
                    const SizedBox(height: 20),
                    HighlightsRow(memberId: viewer, highlights: highlights, editable: true),
                    const SizedBox(height: 16),
                    Text(l10n.stoArchive, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(l10n.stoArchiveIntro, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    if (archive.isEmpty) Text(l10n.stoArchiveEmpty, style: theme.textTheme.bodyMedium),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final s in archive)
                          Semantics(
                            button: true,
                            label: MaterialLocalizations.of(context).formatMediumDate(s.postedAt),
                            excludeSemantics: true,
                            child: GestureDetector(
                              onTap: () => openHighlight(context, Highlight(s.r.copyWith(kind: SocialKind.highlight, title: MaterialLocalizations.of(context).formatShortDate(s.postedAt)).withFields({'stories': [s.id]}))),
                              child: SizedBox(
                                width: 66,
                                height: 116,
                                child: ClipRRect(borderRadius: BorderRadius.circular(8), child: StorySlideView(slide: s.slides.first, mini: true)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  SizedBox(height: NavBarInset.of(context) + 90),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
