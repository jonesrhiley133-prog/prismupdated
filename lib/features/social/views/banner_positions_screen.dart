import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/domain/preferences/member_name_presentation.dart';
import 'package:prism_plurality/features/settings/providers/settings_providers.dart';
import 'package:prism_plurality/features/appearance/services/appearance_store.dart';
import 'package:prism_plurality/features/appearance/views/look_controls.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/providers/member_avatar_image_provider.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/member_card.dart';
import 'package:prism_plurality/shared/widgets/prism_page_scaffold.dart';
import 'package:prism_plurality/shared/widgets/prism_surface.dart';
import 'package:prism_plurality/shared/widgets/prism_switch_row.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar.dart';

/// Show Alter Banners, plus per-alter cropping (drag to position, zoom)
/// with a live preview of the Headmates card.
class BannerPositionsScreen extends ConsumerWidget {
  const BannerPositionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final show = ref.watch(showMemberBannersProvider);
    final members =
        (ref.watch(userVisibleMemberListProvider).value ?? const <Member>[])
            .where((m) => m.isActive)
            .toList();
    return PrismPageScaffold(
      topBar: PrismTopBar(title: l10n.socBannersTitle, showBackButton: true),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: PrismTokens.contentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PrismSurface(
                    padding: EdgeInsets.zero,
                    child: PrismSwitchRow(
                      title: l10n.socShowBanners,
                      subtitle: l10n.socShowBannersHelp,
                      value: show,
                      onChanged: (v) => ref
                          .read(appearanceProvider.notifier)
                          .setShowMemberBanners(v),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.socBannersAdjustHelp,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final m in members) _MemberBannerEditor(member: m),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberBannerEditor extends ConsumerWidget {
  const _MemberBannerEditor({required this.member});
  final Member member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final banner = ref.watch(memberBannerImageDataProvider(member.id)).value;
    if (banner == null) return const SizedBox.shrink();
    final pos =
        ref.watch(memberBannerPositionsProvider)[member.id] ??
        (x: 0.0, y: 0.0, zoom: 1.0);
    void save(double x, double y, double zoom) => ref
        .read(appearanceProvider.notifier)
        .setBannerPosition(member.id, x, y, zoom);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: l10n.socBannerPositionFor(member.name),
            hint: l10n.socBannerPositionHint,
            onIncrease: () => save(pos.x, (pos.y + 0.1).clamp(-1, 1), pos.zoom),
            onDecrease: () => save(pos.x, (pos.y - 0.1).clamp(-1, 1), pos.zoom),
            child: LayoutBuilder(
              builder: (context, box) => GestureDetector(
                onPanUpdate: (d) => save(
                  (pos.x - d.delta.dx / (box.maxWidth * 0.68) * 2 / pos.zoom)
                      .clamp(-1, 1),
                  (pos.y - d.delta.dy / 68 * 2 / pos.zoom).clamp(-1, 1),
                  pos.zoom,
                ),
                child: AbsorbPointer(
                  child: MemberCard(
                    member: member,
                    resolvedName: primaryNameFor(
                      member,
                      ref.watch(memberNamePresentationProvider),
                    ),
                    bannerImageData: banner,
                    bannerAlignment: Alignment(pos.x, pos.y),
                    bannerZoom: pos.zoom,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LabeledSlider(
              label: l10n.socBannerZoom,
              value: pos.zoom,
              min: 1,
              max: 3,
              divisions: 20,
              format: (v) => '${(v * 100).round()}%',
              onChanged: (v) => save(pos.x, pos.y, v),
              onReset: pos.x == 0 && pos.y == 0 && pos.zoom == 1
                  ? null
                  : () => save(0, 0, 1),
            ),
          ),
        ],
      ),
    );
  }
}
