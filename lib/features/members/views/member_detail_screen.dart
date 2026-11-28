import 'dart:async';

import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:prism_plurality/shared/fonts/font_prefs.dart';
import 'package:prism_plurality/shared/fonts/prism_fonts.dart';
import 'package:prism_plurality/features/flags/flag_screens.dart'
    show FlagStrip;
import 'package:prism_plurality/features/wallets/wallet_screens.dart'
    show PrimaryIdCardTile;
import 'package:prism_plurality/features/appearance/services/appearance_store.dart';
import 'package:prism_plurality/features/members/studio/profile_config.dart';
import 'package:prism_plurality/shared/theme/palette_moods.dart';
import 'package:prism_plurality/shared/theme/theme_variants.dart';
import 'package:prism_plurality/features/members/studio/profile_studio.dart';
import 'package:prism_plurality/shared/l10n/tr.dart';
import 'package:prism_plurality/shared/widgets/prism_surface.dart';
import 'package:prism_plurality/features/members/studio/profile_view.dart';
import 'package:prism_plurality/features/relationships/hub/member_relationships.dart';
import 'package:prism_plurality/shared/theme/look_theme.dart';
import 'package:prism_plurality/features/alter_status/status_widgets.dart';
import 'package:prism_plurality/features/intro_cards/intro_cards_screen.dart';
import 'package:prism_plurality/features/links/models/record_ref.dart';
import 'package:prism_plurality/features/links/widgets/related_records.dart';
import 'package:flutter/material.dart';
import 'package:prism_plurality/features/astro/views/astro_integrations.dart'
    show AstroProfileModule;
import 'package:prism_plurality/features/yumeships/yume_profile_module.dart';
import 'package:intl/intl.dart';
import 'package:prism_plurality/shared/theme/prism_shapes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:prism_plurality/core/constants/fronting_namespaces.dart';
import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/domain/models/fronting_session.dart';
import 'package:prism_plurality/domain/models/conversation.dart';
import 'package:prism_plurality/domain/models/system_settings.dart';
import 'package:prism_plurality/features/chat/navigation/open_chat_conversation.dart';
import 'package:prism_plurality/features/chat/providers/chat_providers.dart';
import 'package:prism_plurality/features/fronting/providers/fronting_providers.dart';
import 'package:prism_plurality/features/fronting/views/session_detail_screen.dart';
import 'package:prism_plurality/features/members/navigation/member_navigation_branch.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/members/providers/member_stats_providers.dart';
import 'package:prism_plurality/features/members/utils/member_accent_color.dart';
import 'package:prism_plurality/features/members/views/add_edit_member_sheet.dart';
import 'package:prism_plurality/features/members/views/member_fronting_history_screen.dart';
import 'package:prism_plurality/shared/theme/app_colors.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/theme/app_theme.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';
import 'package:prism_plurality/shared/widgets/app_shell.dart';
import 'package:prism_plurality/shared/widgets/prism_page_scaffold.dart';
import 'package:prism_plurality/shared/widgets/prism_dialog.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar_action.dart';
import 'package:prism_plurality/features/settings/providers/settings_providers.dart';
import 'package:prism_plurality/features/settings/providers/terminology_provider.dart';
import 'package:prism_plurality/shared/widgets/prism_loading_state.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_section_card.dart';
import 'package:prism_plurality/shared/widgets/blur_popup.dart';
import 'package:prism_plurality/shared/widgets/prism_toast.dart';
import 'package:prism_plurality/shared/widgets/adaptive_detail_surface.dart';
import 'package:prism_plurality/shared/widgets/list_detail_layout.dart';
import 'package:prism_plurality/features/members/widgets/member_groups_section.dart';
import 'package:prism_plurality/features/members/widgets/proxy_tags_section.dart';
import 'package:prism_plurality/features/members/widgets/custom_fields_display.dart';
import 'package:prism_plurality/features/boards/widgets/board_message_section.dart';
import 'package:prism_plurality/features/members/widgets/notes_section.dart';
import 'package:prism_plurality/features/members/widgets/member_profile_header.dart';
import 'package:prism_plurality/features/members/widgets/custom_field_display_widgets.dart';
import 'package:prism_plurality/shared/widgets/prism_markdown_text.dart';
import 'package:prism_plurality/shared/widgets/prism_list_row.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/extensions/duration_extensions.dart';

/// Detail screen for a single system member, pushed via go_router.
class MemberDetailScreen extends ConsumerWidget {
  const MemberDetailScreen({
    super.key,
    required this.memberId,
    this.branch = MemberNavigationBranch.settings,
    this.groupId,
    this.showBackButton = true,
    this.onEdit,
    this.onOpenCustomFieldGroupPage,
  });

  final String memberId;
  final MemberNavigationBranch branch;
  final String? groupId;
  final VoidCallback? onEdit;
  final ValueChanged<String>? onOpenCustomFieldGroupPage;

  /// Hidden when the screen is embedded as the detail pane of a two-pane
  /// list-detail layout, where there is no route to pop back to.
  final bool showBackButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberAsync = ref.watch(activeMemberByIdProvider(memberId));

    return memberAsync.when(
      loading: () => PrismPageScaffold(
        topBar: PrismTopBar(title: '', showBackButton: showBackButton),
        body: const PrismLoadingState(),
      ),
      error: (e, _) => PrismPageScaffold(
        topBar: PrismTopBar(title: '', showBackButton: showBackButton),
        body: Center(
          child: Text(
            'Error loading ${readTerminology(context, ref).singularLower}: $e',
          ),
        ),
      ),
      data: (member) {
        if (member == null) {
          return PrismPageScaffold(
            topBar: PrismTopBar(title: '', showBackButton: showBackButton),
            body: Center(
              child: Text(
                '${readTerminology(context, ref).singular} not found',
              ),
            ),
          );
        }
        return _MemberDetailBody(
          member: member,
          branch: branch,
          groupId: groupId,
          showBackButton: showBackButton,
          onEdit: onEdit,
          onOpenCustomFieldGroupPage: onOpenCustomFieldGroupPage,
        );
      },
    );
  }
}

class _MemberDetailBody extends ConsumerWidget {
  const _MemberDetailBody({
    required this.member,
    required this.branch,
    required this.groupId,
    required this.showBackButton,
    required this.onEdit,
    required this.onOpenCustomFieldGroupPage,
  });

  final Member member;
  final MemberNavigationBranch branch;
  final String? groupId;
  final bool showBackButton;
  final VoidCallback? onEdit;
  final ValueChanged<String>? onOpenCustomFieldGroupPage;

  bool _isFronting(List<dynamic> sessions) {
    return sessions.any((s) => s.memberId == member.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final terms = watchTerminology(context, ref);
    final activeSessionsAsync = ref.watch(activeSessionsProvider);
    final perMemberAccentColors = ref.watch(perMemberAccentColorsProvider);
    final themeStyle = ref.watch(effectiveThemeStyleProvider);
    final paletteMood = ref.watch(paletteMoodProvider);
    final paletteContrast = ref.watch(paletteContrastProvider);
    final bioMarkdownEnabled = ref.watch(bioMarkdownEnabledProvider);
    final isFronting =
        activeSessionsAsync.whenOrNull(data: _isFronting) ?? false;

    final memberAccent = resolveMemberAccentColor(
      theme,
      member,
      perMemberAccentColors: perMemberAccentColors,
    );

    final body = Builder(
      builder: (context) => CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, NavBarInset.of(context)),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                _buildBodyChildren(
                  context,
                  isFronting,
                  bioMarkdownEnabled: bioMarkdownEnabled,
                  preferDisplayName: ref.watch(memberNamePreferDisplayProvider),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final screen = PrismPageScaffold(
      topBar: PrismTopBar(
        title: '',
        showBackButton: showBackButton,
        actions: [
          PrismTopBarAction(
            icon: AppIcons.editOutlined,
            tooltip: l10n.memberEditTooltip(terms.singularLower),
            onPressed: () => _openEditSheet(context),
          ),
          _MoreMenuButton(
            member: member,
            onAction: (action) => _handleMenuAction(context, ref, action),
          ),
        ],
      ),
      bodyPadding: EdgeInsets.zero,
      body: body,
    );

    return _MemberProfileTheme(
      baseTheme: theme,
      accentColor: memberAccent,
      usePaletteTheme: themeStyle == ThemeStyle.materialYou,
      paletteMood: paletteMood,
      paletteContrast: paletteContrast,
      paletteCustom: ref.watch(customPaletteAccentsProvider),
      // Light / medium / dark chosen for this alter's page in the studio.
      tone: PageTone.parse(
        ref.watch(
          memberProfileProvider(
            member.id,
          ).select((p) => p?.lookStr('pageMode', 'app')),
        ),
      ),
      child: AlterAccentScope(accent: memberAccent, child: screen),
    );
  }

  List<Widget> _buildBodyChildren(
    BuildContext context,
    bool isFronting, {
    required bool bioMarkdownEnabled,
    required bool preferDisplayName,
  }) {
    final theme = Theme.of(context);
    return [
      const SizedBox(height: 16),
      MemberProfileHeader(member: member, isFronting: isFronting),
      StudioHeaderExtras(member: member),
      if (member.pronouns?.trim().isNotEmpty ?? false) ...[
        const SizedBox(height: 12),
        Text(
          context.l10n.memberPronounsLabel,
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        FieldInlineMarkdownText(
          member.pronouns!.trim(),
          style: theme.textTheme.bodyLarge,
        ),
      ],
      if (member.bio != null && member.bio!.isNotEmpty) ...[
        const SizedBox(height: 12),
        FontSurfaceScope(
          surface: FontSurface.bio,
          child: PrismMarkdownText(
            data: member.bio!,
            // Global switch is the master off; per-member flag is the override.
            enabled: bioMarkdownEnabled && member.markdownEnabled,
            baseStyle: theme.textTheme.bodyLarge,
            memberId: member.id,
            // raw-name-ok: markdown mention rendering uses the canonical handle.
            memberName: member.name,
          ),
        ),
      ],
      StudioProfileSection(member: member),
      const SizedBox(height: 24),
      _RetainedProfileSection(
        key: const ValueKey('customFields'),
        child: CustomFieldsDisplay(
          memberId: member.id,
          branch: branch,
          groupId: groupId,
          onOpenGroupPage: onOpenCustomFieldGroupPage,
        ),
      ),
      _RetainedProfileSection(
        key: const ValueKey('notes'),
        child: NotesSection(memberId: member.id),
      ),
      _RetainedProfileSection(
        key: const ValueKey('groups'),
        child: MemberGroupsSection(
          memberId: member.id,
          memberName: member.effectiveName(
            preferDisplayName: preferDisplayName,
          ),
          branch: branch,
        ),
      ),
      ProxyTagsSection(member: member),
      _AstroSection(member: member),
      _YumeSection(member: member),
      _RetainedProfileSection(
        key: const ValueKey('frontingStats'),
        child: _FrontingStatsSection(memberId: member.id),
      ),
      const SizedBox(height: 8),
      _RetainedProfileSection(
        key: const ValueKey('recentSessions'),
        child: _RecentSessionsSection(
          memberId: member.id,
          branch: branch,
          groupId: groupId,
        ),
      ),
      const SizedBox(height: 8),
      _RetainedProfileSection(
        key: const ValueKey('conversations'),
        child: _ConversationsSection(
          memberId: member.id,
          branch: branch,
          groupId: groupId,
        ),
      ),
      _RetainedProfileSection(
        key: const ValueKey('boardMessages'),
        child: BoardMessageSection(memberId: member.id),
      ),
      MemberStatusPanel(memberId: member.id),
      MemberIntroCardTile(memberId: member.id),
      PrimaryIdCardTile(memberId: member.id),
      FlagStrip(owner: member.id),
      MemberRelationshipsSection(memberId: member.id),
      RelatedRecordsSection(self: RecordRef(RecordRef.member, member.id)),
      const SizedBox(height: 24),
      _MemberCreatedAtFooter(member: member),
      const SizedBox(height: 32),
    ];
  }

  void _openEditSheet(BuildContext context) {
    final openInPane = onEdit;
    if (openInPane != null) {
      openInPane();
      return;
    }

    PrismSheet.showFullScreen(
      context: context,
      builder: (context, scrollController) => AddEditMemberSheet(
        member: member,
        scrollController: scrollController,
      ),
    );
  }

  Future<void> _handleMenuAction(
    BuildContext context,
    WidgetRef ref,
    _MenuAction action,
  ) async {
    switch (action) {
      case _MenuAction.studio:
        await openProfileStudio(context, memberId: member.id);
      case _MenuAction.setFronter:
        try {
          await ref.read(frontingNotifierProvider.notifier).startFronting([
            member.id,
          ]);
          if (context.mounted) {
            final frontingTerms = readFrontingTerms(context, ref);
            PrismToast.show(
              context,
              message:
                  '${member.effectiveName(preferDisplayName: ref.read(memberNamePreferDisplayProvider))} '
                  'is ${frontingTerms.currentlyActivePhrase}.',
            );
          }
        } catch (e) {
          if (context.mounted) {
            PrismToast.error(
              context,
              message: context.l10n.frontingErrorWakingUp(e),
            );
          }
        }
      case _MenuAction.toggleActive:
        await ref
            .read(membersNotifierProvider.notifier)
            .updateMember(member.copyWith(isActive: !member.isActive));
      case _MenuAction.delete:
        await _confirmDelete(context, ref);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final terms = readTerminology(context, ref);
    final confirmed = await PrismDialog.confirm(
      context: context,
      title: 'Delete ${terms.singularLower}?',
      message:
          'Are you sure you want to delete '
          '${member.effectiveName(preferDisplayName: ref.read(memberNamePreferDisplayProvider))}? '
          'This action cannot be undone.',
      confirmLabel: context.l10n.delete,
      destructive: true,
    );
    if (confirmed) {
      unawaited(
        ref.read(membersNotifierProvider.notifier).deleteMember(member.id),
      );
      if (context.mounted) {
        closeDetailSurface(context, routeBacked: showBackButton);
      }
    }
  }
}

/// Keeps a data-backed profile section mounted once it has been built.
///
/// The profile list builds its lower sections lazily, so their queries wait
/// until the user scrolls near them. Without retention, scrolling back to the
/// top destroys those sections and disposes their providers; returning to the
/// bottom then reloads them and the answers resize the list beneath a resting
/// bottom position.
class _RetainedProfileSection extends StatefulWidget {
  const _RetainedProfileSection({super.key, required this.child});

  final Widget child;

  @override
  State<_RetainedProfileSection> createState() =>
      _RetainedProfileSectionState();
}

class _RetainedProfileSectionState extends State<_RetainedProfileSection>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _MemberCreatedAtFooter extends StatelessWidget {
  const _MemberCreatedAtFooter({required this.member});

  final Member member;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.dateLocale;
    final displayDate = DateFormat.yMMMd(locale).format(member.createdAt);
    final semanticsDate = DateFormat.yMMMMd(locale).format(member.createdAt);

    return Center(
      child: Semantics(
        label: context.l10n.memberAddedAtProfileFooterLabel(semanticsDate),
        child: Text(
          context.l10n.memberAddedAtProfileFooterLabel(displayDate),
          textAlign: TextAlign.center,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
          ),
        ),
      ),
    );
  }
}

class _MemberProfileTheme extends StatelessWidget {
  const _MemberProfileTheme({
    required this.baseTheme,
    required this.accentColor,
    required this.usePaletteTheme,
    required this.paletteMood,
    required this.paletteContrast,
    required this.paletteCustom,
    required this.tone,
    required this.child,
  });

  final CustomPaletteAccents paletteCustom;

  /// The page's own brightness, or null to follow the app.
  final PageTone? tone;
  final ThemeData baseTheme;
  final Color? accentColor;
  final bool usePaletteTheme;
  final PaletteMood paletteMood;
  final PaletteContrast paletteContrast;
  final Widget child;

  // Derived profile themes, newest last. Building one runs the palette
  // (ColorScheme.fromSeed) and the full appearance pipeline, so it is
  // computed once per base theme + colour, not on every rebuild. Base themes
  // are matched by identity (ThemeData's own hashCode is a deep walk).
  static final Map<
    (int, int, bool, PaletteMood, PaletteContrast, CustomPaletteAccents),
    (ThemeData, ThemeData)
  >
  _cache = {};

  static ThemeData _themeFor(
    ThemeData base,
    Color accent,
    bool usePalette,
    PaletteMood mood,
    PaletteContrast contrast,
    CustomPaletteAccents custom,
  ) {
    final key = (
      identityHashCode(base),
      accent.toARGB32(),
      usePalette,
      mood,
      contrast,
      custom,
    );
    final hit = _cache.remove(key);
    if (hit != null && identical(hit.$1, base)) {
      _cache[key] = hit;
      return hit.$2;
    }
    final theme = withAccent(
      base,
      accent,
      palette: usePalette
          ? AppTheme.localPaletteTheme(
              base,
              seedColor: accent,
              paletteMood: mood,
              paletteContrast: contrast,
              paletteCustom: custom,
            )
          : null,
    );
    if (_cache.length >= 12) _cache.remove(_cache.keys.first);
    _cache[key] = (base, theme);
    return theme;
  }

  @override
  Widget build(BuildContext context) {
    // A page tone different from the app's swaps in the app's theme for
    // that tone (same style, fonts, look), then the alter's accent applies.
    var base = baseTheme;
    final variants = PrismThemeVariantsScope.maybeOf(context);
    final wanted = tone;
    if (wanted != null &&
        variants != null &&
        wanted != variants.currentTone(context)) {
      base = variants.of(wanted);
    }
    final accent = accentColor;
    if (accent == null) {
      return identical(base, baseTheme)
          ? child
          : Theme(data: base, child: child);
    }

    // The alter's colour becomes the accent; the active appearance preset
    // (backgrounds, surfaces, text, element styles) keeps applying. Applied
    // in one step: lerping ThemeData per frame rebuilt the whole profile on
    // every frame of the page transition.
    return Theme(
      data: _themeFor(
        base,
        accent,
        usePaletteTheme,
        paletteMood,
        paletteContrast,
        paletteCustom,
      ),
      child: child,
    );
  }
}

// ── Astrology (only when visible to the current viewer) ─────────────────────

class _AstroSection extends ConsumerWidget {
  const _AstroSection({required this.member});
  final Member member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!AstroProfileModule.visible(ref, member.id))
      return const SizedBox.shrink();
    final theme = Theme.of(context);
    return _SectionCard(
      icon: AppIcons.navAstro,
      title: tr(context, 'Astrology', 'Astrología'),
      theme: theme,
      child: PrismSurface(
        child: AstroProfileModule(
          member: member,
          accent: theme.colorScheme.primary,
          showTitle: false,
        ),
      ),
    );
  }
}

// ── Yumeships (opt-in per alter, only what the viewer may see) ──────────────

class _YumeSection extends ConsumerWidget {
  const _YumeSection({required this.member});
  final Member member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!YumeProfileModule.visible(ref, member.id))
      return const SizedBox.shrink();
    final theme = Theme.of(context);
    return _SectionCard(
      icon: AppIcons.navYumeships,
      title: 'Yumeships',
      theme: theme,
      child: PrismSurface(child: YumeProfileModule(memberId: member.id)),
    );
  }
}

// ── Fronting Stats Section ──────────────────────────────────────────────────

class _FrontingStatsSection extends ConsumerWidget {
  const _FrontingStatsSection({required this.memberId});

  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final frontingTerms = watchFrontingTerms(context, ref);
    final statsAsync = ref.watch(memberFrontingStatsProvider(memberId));

    return statsAsync.when(
      // Zero height like the sibling sections: a placeholder that collapses
      // when a member has no sessions would pull a resting bottom position
      // back up.
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (stats) {
        if (stats.totalSessions == 0) {
          return const SizedBox.shrink();
        }

        return _SectionCard(
          icon: AppIcons.barChartOutlined,
          title: frontingTerms.statsLabel,
          theme: theme,
          child: Column(
            children: [
              _StatRow(
                label: 'Total ${frontingTerms.sessionPlural.toLowerCase()}',
                value: '${stats.totalSessions}',
                theme: theme,
              ),
              const Divider(height: 1),
              _StatRow(
                label: frontingTerms.timeLabel,
                value: stats.totalDuration.toRoundedString(),
                theme: theme,
              ),
              if (stats.lastFronted != null) ...[
                const Divider(height: 1),
                _StatRow(
                  label: frontingTerms.lastActiveLabel,
                  value: _formatTimestamp(l10n, stats.lastFronted!),
                  theme: theme,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _formatTimestamp(dynamic l10n, DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inDays == 0) return l10n.memberStatsToday as String;
    if (diff.inDays == 1) return l10n.memberStatsYesterday as String;
    if (diff.inDays < 7) return l10n.memberStatsDaysAgo(diff.inDays) as String;
    if (diff.inDays < 30) {
      return l10n.memberStatsWeeksAgo(diff.inDays ~/ 7) as String;
    }
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}

// ── Recent Sessions Section ─────────────────────────────────────────────────

class _RecentSessionsSection extends ConsumerWidget {
  const _RecentSessionsSection({
    required this.memberId,
    required this.branch,
    required this.groupId,
  });

  final String memberId;
  final MemberNavigationBranch branch;
  final String? groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final frontingTerms = watchFrontingTerms(context, ref);
    final sessionsAsync = ref.watch(memberRecentSessionsProvider(memberId));

    return sessionsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (sessions) {
        if (sessions.isEmpty) return const SizedBox.shrink();

        return _SectionCard(
          icon: AppIcons.historyOutlined,
          title: frontingTerms.sessionPlural,
          theme: theme,
          trailing: PrismButton(
            label: context.l10n.memberSectionFrontingSessionsViewAll,
            onPressed: () => _openFrontingHistory(context),
            density: PrismControlDensity.compact,
          ),
          child: Column(
            children: [
              for (var i = 0; i < sessions.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _SessionTile(session: sessions[i]),
              ],
            ],
          ),
        );
      },
    );
  }

  String _frontingHistoryPath() =>
      branch.memberFrontingHistoryPath(memberId, groupId: groupId);

  void _openFrontingHistory(BuildContext context) {
    showAdaptiveDetailSurface<void>(
      context: context,
      builder: (_) => MemberFrontingHistoryScreen(memberId: memberId),
      route: (context) => context.go(_frontingHistoryPath()),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});

  final FrontingSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final startDate = _formatDate(context, session.startTime);
    final duration = session.duration.toRoundedString();

    return InkWell(
      onTap: () => _openSession(context),
      borderRadius: BorderRadius.circular(PrismShapes.of(context).radius(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              session.isActive ? AppIcons.flashOn : AppIcons.schedule,
              size: 18,
              color: session.isActive
                  ? AppColors.fronting(theme.brightness)
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(startDate, style: theme.textTheme.bodyMedium)),
            Text(
              session.isActive ? l10n.memberSessionActive : duration,
              style: theme.textTheme.bodySmall?.copyWith(
                color: session.isActive
                    ? AppColors.fronting(theme.brightness)
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: session.isActive
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              AppIcons.chevronRight,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(BuildContext context, DateTime dt) {
    final l10n = context.l10n;
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inDays == 0) {
      return l10n.memberSessionTodayAt(context.formatTime(dt));
    }
    if (diff.inDays == 1) return l10n.memberStatsYesterday;

    return DateFormat.yMd(context.dateLocale).format(dt);
  }

  void _openSession(BuildContext context) {
    showAdaptiveDetailSurface<void>(
      context: context,
      builder: (_) => SessionDetailScreen(sessionId: session.id),
      route: (context) => context.push(AppRoutePaths.session(session.id)),
    );
  }
}

// ── Conversations Section ───────────────────────────────────────────────────

class MemberConversationsScreen extends ConsumerWidget {
  const MemberConversationsScreen({super.key, required this.memberId});

  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatEnabled = ref.watch(chatEnabledProvider);
    if (!chatEnabled) {
      return PrismPageScaffold(
        topBar: PrismTopBar(
          title: context.l10n.memberSectionConversations,
          showBackButton: true,
        ),
        body: const SizedBox.shrink(),
      );
    }

    final memberAsync = ref.watch(activeMemberByIdProvider(memberId));

    return memberAsync.when(
      loading: () => const PrismPageScaffold(
        topBar: PrismTopBar(title: '', showBackButton: true),
        body: PrismLoadingState(),
      ),
      error: (e, _) => PrismPageScaffold(
        topBar: const PrismTopBar(title: '', showBackButton: true),
        body: Center(
          child: Text(
            'Error loading ${readTerminology(context, ref).singularLower}: $e',
          ),
        ),
      ),
      data: (member) {
        if (member == null) {
          return PrismPageScaffold(
            topBar: const PrismTopBar(title: '', showBackButton: true),
            body: Center(
              child: Text(
                '${readTerminology(context, ref).singular} not found',
              ),
            ),
          );
        }

        return PrismPageScaffold(
          topBar: PrismTopBar(
            title: context.l10n.memberSectionConversations,
            showBackButton: true,
          ),
          bodyPadding: EdgeInsets.zero,
          safeAreaBottom: false,
          body: _MemberConversationsList(memberId: member.id),
        );
      },
    );
  }
}

class _ConversationsSection extends ConsumerWidget {
  const _ConversationsSection({
    required this.memberId,
    required this.branch,
    required this.groupId,
  });

  final String memberId;
  final MemberNavigationBranch branch;
  final String? groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatEnabled = ref.watch(chatEnabledProvider);
    if (!chatEnabled) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final activityAsync = ref.watch(
      memberConversationPreviewActivityProvider(memberId),
    );

    return activityAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (activity) {
        if (activity.isEmpty) return const SizedBox.shrink();
        final preview = activity.take(memberConversationPreviewCount).toList();
        final showViewAll = activity.length > preview.length;

        return _SectionCard(
          icon: AppIcons.chatOutlined,
          title: context.l10n.memberSectionConversations,
          theme: theme,
          trailing: showViewAll
              ? PrismButton(
                  label: context.l10n.memberSectionFrontingSessionsViewAll,
                  onPressed: () => _openConversations(context),
                  density: PrismControlDensity.compact,
                )
              : null,
          child: Column(
            children: [
              for (var i = 0; i < preview.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _ConversationTile(
                  conversation: preview[i].conversation,
                  memberId: memberId,
                  messageCount: preview[i].messageCount,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _conversationsPath() =>
      branch.memberConversationsPath(memberId, groupId: groupId);

  void _openConversations(BuildContext context) {
    showAdaptiveDetailSurface<void>(
      context: context,
      builder: (_) => MemberConversationsScreen(memberId: memberId),
      route: (context) => context.go(_conversationsPath()),
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({
    required this.conversation,
    required this.memberId,
    required this.messageCount,
  });

  final Conversation conversation;
  final String memberId;
  final int messageCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final title =
        conversation.title ??
        conversation.emoji ??
        context.l10n.memberConversationFallback;

    final allMembersAsync = ref.watch(allMemberListProvider);
    final prefer = ref.watch(memberNamePreferDisplayProvider);
    final participantsSubtitle = allMembersAsync.whenOrNull(
      data: (members) {
        final others = members
            .where(
              (m) =>
                  m.id != memberId &&
                  m.id != unknownSentinelMemberId &&
                  isImplicitParticipantOf(conversation, m.id),
            )
            .toList();
        if (others.isEmpty) return '';
        String nameOf(int i) =>
            others[i].effectiveName(preferDisplayName: prefer);
        if (others.length == 1) return nameOf(0);
        if (others.length == 2) return '${nameOf(0)}, ${nameOf(1)}';
        final extra = others.length - 2;
        return '${nameOf(0)}, ${nameOf(1)} +$extra more';
      },
    );
    final messageCountText = context.l10n.settingsDataBrowserMessageCount(
      messageCount,
    );
    final subtitle =
        participantsSubtitle != null && participantsSubtitle.isNotEmpty
        ? '$participantsSubtitle - $messageCountText'
        : messageCountText;

    return InkWell(
      onTap: () =>
          openChatConversation(context, ref, conversationId: conversation.id),
      borderRadius: BorderRadius.circular(PrismShapes.of(context).radius(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (conversation.emoji != null) ...[
              Text(conversation.emoji!, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
            ] else ...[
              Icon(
                AppIcons.chatBubbleOutline,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              AppIcons.chevronRight,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberConversationsList extends ConsumerWidget {
  const _MemberConversationsList({required this.memberId});

  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(
      memberConversationActivityProvider(memberId),
    );

    return activityAsync.when(
      loading: () => const PrismLoadingState(),
      error: (_, _) => const SizedBox.shrink(),
      data: (activity) {
        if (activity.isEmpty) {
          return Center(child: Text(context.l10n.memberConversationFallback));
        }

        return ListView.separated(
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            NavBarInset.of(context) + 16,
          ),
          itemCount: activity.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = activity[index];
            return _ConversationTile(
              conversation: item.conversation,
              memberId: memberId,
              messageCount: item.messageCount,
            );
          },
        );
      },
    );
  }
}

// ── Shared helpers ──────────────────────────────────────────────────────────

enum _MenuAction { setFronter, studio, toggleActive, delete }

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.theme,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final ThemeData theme;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: PrismSectionCard(child: child),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    required this.theme,
  });

  final String label;
  final String value;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreMenuButton extends ConsumerWidget {
  const _MoreMenuButton({required this.member, required this.onAction});

  final Member member;
  final ValueChanged<_MenuAction> onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final frontingTerms = watchFrontingTerms(context, ref);
    final items = [
      (
        action: _MenuAction.setFronter,
        label: frontingTerms.setAsAction,
        icon: AppIcons.flashOn,
        destructive: false,
      ),
      (
        action: _MenuAction.studio,
        label: tr(context, 'Profile Studio', 'Profile Studio'),
        icon: PhosphorIcons.paintBrushBroad(),
        destructive: false,
      ),
      (
        action: _MenuAction.toggleActive,
        label: member.isActive ? l10n.deactivate : l10n.activate,
        icon: member.isActive ? AppIcons.visibilityOff : AppIcons.visibility,
        destructive: false,
      ),
      (
        action: _MenuAction.delete,
        label: l10n.delete,
        icon: AppIcons.deleteOutline,
        destructive: true,
      ),
    ];

    return BlurPopupAnchor(
      trigger: BlurPopupTrigger.tap,
      preferredDirection: BlurPopupDirection.down,
      width: 200,
      maxHeight: 300,
      itemCount: items.length,
      itemBuilder: (context, index, close) {
        final item = items[index];
        final theme = Theme.of(context);
        final color = item.destructive
            ? theme.colorScheme.error
            : theme.colorScheme.onSurface;
        return PrismListRow(
          dense: true,
          leading: Icon(item.icon, size: 20, color: color),
          title: Text(item.label, style: TextStyle(fontSize: 14, color: color)),
          onTap: () {
            close();
            onAction(item.action);
          },
        );
      },
      child: PrismTopBarAction(
        icon: AppIcons.moreVert,
        tooltip: l10n.memberMoreOptionsTooltip,
        onPressed: null,
      ),
    );
  }
}

/// Tells picture backgrounds which alter's accent to follow while this
/// profile is on screen, and lets go when it leaves.
class AlterAccentScope extends StatefulWidget {
  const AlterAccentScope({
    super.key,
    required this.accent,
    required this.child,
  });
  final Color? accent;
  final Widget child;
  @override
  State<AlterAccentScope> createState() => _AlterAccentScopeState();
}

class _AlterAccentScopeState extends State<AlterAccentScope> {
  ModalRoute<Object?>? _route;

  /// The profile owns the tint only while its page is the one in front:
  /// it lets go the moment you start going back, or when another page opens
  /// on top, instead of after the page has finished closing.
  bool get _showing {
    final r = _route;
    if (r == null) return true;
    final leaving =
        r.animation?.status == AnimationStatus.reverse ||
        r.animation?.status == AnimationStatus.dismissed;
    final sec = r.secondaryAnimation?.status;
    final covered =
        sec == AnimationStatus.forward || sec == AnimationStatus.completed;
    return r.isActive && !leaving && !covered;
  }

  void _sync() {
    if (!mounted) return;
    if (_showing) {
      viewedAlterAccent.value = widget.accent;
    } else if (viewedAlterAccent.value == widget.accent) {
      viewedAlterAccent.value = null;
    }
  }

  void _onRouteAnimation(AnimationStatus _) => _sync();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final r = ModalRoute.of(context);
    if (r != _route) {
      _route?.animation?.removeStatusListener(_onRouteAnimation);
      _route?.secondaryAnimation?.removeStatusListener(_onRouteAnimation);
      _route = r;
      r?.animation?.addStatusListener(_onRouteAnimation);
      r?.secondaryAnimation?.addStatusListener(_onRouteAnimation);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didUpdateWidget(AlterAccentScope old) {
    super.didUpdateWidget(old);
    if (old.accent != widget.accent) {
      if (viewedAlterAccent.value == old.accent) viewedAlterAccent.value = null;
      _sync();
    }
  }

  @override
  void dispose() {
    _route?.animation?.removeStatusListener(_onRouteAnimation);
    _route?.secondaryAnimation?.removeStatusListener(_onRouteAnimation);
    if (viewedAlterAccent.value == widget.accent) {
      viewedAlterAccent.value = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
