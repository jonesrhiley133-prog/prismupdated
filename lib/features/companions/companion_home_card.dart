import 'package:go_router/go_router.dart';

import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/domain/preferences/dashboard_preferences.dart';
import 'package:prism_plurality/features/home/widgets/home_dashboard.dart'
    show homeCardSizesProvider;
import 'package:prism_plurality/features/companions/companion_data.dart';
import 'package:prism_plurality/features/companions/companion_screens.dart';
import 'package:prism_plurality/features/companions/companion_widgets.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Home: the chosen companion, if there is one and the Home card is on.
class CompanionHomeCard extends ConsumerWidget {
  const CompanionHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compact =
        ref.watch(homeCardSizesProvider)[DashboardWidgetId.companion] ==
        'compact';
    final c = ref.watch(shownCompanionProvider(currentFronterId(ref)));
    if (c == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.zero,
      child: PrismSurface(
        padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
        onTap: () =>
            pushPage<void>(context, CompanionProfileScreen(companionId: c.id)),
        onLongPress: () => context.push(AppRoutePaths.companions),
        semanticLabel: 'Visit ${c.name}',
        child: Row(
          children: [
            CompanionFigure(
              companion: c,
              size: compact ? 40 : 64,
              showParticles: false,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name, style: theme.textTheme.titleSmall),
                  Text(
                    c.status.isNotEmpty
                        ? c.status
                        : 'Say hi, play, or take a photo',
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'All companions',
              icon: const Icon(Icons.pets_outlined),
              onPressed: () => context.push(AppRoutePaths.companions),
            ),
            IconButton(
              tooltip: 'Passports',
              icon: const Icon(Icons.approval_outlined),
              onPressed: () => context.push(AppRoutePaths.passports),
            ),
          ],
        ),
      ),
    );
  }
}
