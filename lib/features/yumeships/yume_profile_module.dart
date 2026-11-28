import 'package:go_router/go_router.dart';

import 'package:prism_plurality/core/features/feature_state.dart';
import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/features/yumeships/yume_data.dart';
import 'package:prism_plurality/features/yumeships/yume_widgets.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// The optional Yumeships section on an alter's profile: the ships they own
/// or help with, limited to what the current viewer is allowed to see.
class YumeProfileModule extends ConsumerWidget {
  const YumeProfileModule({super.key, required this.memberId, this.accent});
  final String memberId;
  final Color? accent;

  static bool visible(WidgetRef ref, String memberId) =>
      yumeProfileVisible(ref, memberId);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ships = ref
        .watch(yumeShipsForMemberProvider(memberId))
        .where((s) => !s.archived)
        .toList();
    if (ships.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        YumeShelf(
          height: 104,
          children: [
            for (final s in ships)
              SizedBox(
                width: 210,
                child: yumeIsHidden(ref, s.locked, s.id)
                    ? YumeLockedTile(
                        onUnlock: () =>
                            context.push(AppRoutePaths.yumeShip(s.id)),
                      )
                    : YumeCard(
                        accent: yumeAccent(
                          context,
                          s.accent ?? accent?.toARGB32(),
                        ),
                        card: s.card,
                        onTap: () => context.push(AppRoutePaths.yumeShip(s.id)),
                        child: Row(
                          children: [
                            YumePairAvatars(
                              left: s.avatar,
                              right: s.fos.firstOrNull?.avatar,
                              accent: yumeAccent(context, s.accent),
                              symbol: s.symbol,
                              size: 36,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall,
                                  ),
                                  Text(
                                    s.sources.join(' · '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: YumeAction(
            label: tr(context, 'Open Yumeships', 'Abrir Yumeships'),
            onPressed: () => context.go(AppRoutePaths.yumeships),
          ),
        ),
      ],
    );
  }
}

/// Optional Home card: the next yumeship dates the viewer may see (dates
/// marked as countdowns first). Hidden when the feature is off or empty.
class YumeCountdownHomeCard extends ConsumerWidget {
  const YumeCountdownHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(featureEnabledProvider('yumeships'))) {
      return const SizedBox.shrink();
    }
    final up = [...ref.watch(yumeUpcomingProvider)]
      ..sort((a, b) {
        final ca = a.event?.countdown ?? false,
            cb = b.event?.countdown ?? false;
        return ca != cb ? (ca ? -1 : 1) : a.on.compareTo(b.on);
      });
    final shown = up
        .where((u) => !yumeIsHidden(ref, u.ship.locked, u.ship.id))
        .take(3)
        .toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    final now = DateTime.now();
    final theme = Theme.of(context);
    return PrismSurface(
      onTap: () => context.go(AppRoutePaths.yumeships),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr(context, 'Yumeship dates', 'Fechas de yumeships'),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          for (final u in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Text(u.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${u.label} · ${u.ship.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  YumeCountdownPill(
                    days: u.daysFrom(now),
                    accent: yumeAccent(context, u.ship.accent),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
