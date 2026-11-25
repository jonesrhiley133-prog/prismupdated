import 'package:go_router/go_router.dart';

import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/fronting_roles/roles_data.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import 'package:prism_plurality/shared/widgets/member_avatar.dart';

/// Home: who holds which fronting status, in one compact row. Tap to open
/// Who's There; long-press to manage statuses.
class FrontingRolesStrip extends ConsumerWidget {
  const FrontingRolesStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roles = ref.watch(currentRolesProvider);
    final types = ref.watch(frontStatusTypesProvider);
    final members = {
      for (final m
          in ref.watch(userVisibleMembersProvider).value ?? const <Member>[])
        m.id: m,
    };
    final prefer = ref.watch(memberNamePreferDisplayProvider);
    final groups = <FrontStatusType, List<Member>>{};
    for (final r in roles) {
      final t = statusById(types, r.statusId);
      final m = members[r.memberId];
      if (t == null || m == null || !t.onDashboard) continue;
      groups.putIfAbsent(t, () => []).add(m);
    }
    if (groups.isEmpty) return const SizedBox.shrink();
    final ordered = groups.entries.toList()
      ..sort((a, b) => a.key.order.compareTo(b.key.order));
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.zero,
      child: PrismSurface(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        onTap: () => context.push(AppRoutePaths.whosThere),
        onLongPress: () => context.push(AppRoutePaths.settingsFrontStatuses),
        semanticLabel: [
          for (final e in ordered)
            '${e.key.name}: ${e.value.map((m) => m.effectiveName(preferDisplayName: prefer)).join(', ')}',
        ].join('. '),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final e in ordered) ...[
                Text(
                  '${e.key.emoji} ${e.key.name}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color:
                        e.key.colorValue ?? theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
                for (final m in e.value.take(4)) ...[
                  MemberAvatar(
                    avatarImageData: m.avatarImageData,
                    memberName: m.name,
                    emoji: m.emoji,
                    customColorEnabled: m.customColorEnabled,
                    customColorHex: m.customColorHex,
                    size: 24,
                  ),
                  const SizedBox(width: 4),
                  if (e.value.length == 1)
                    Text(
                      m.effectiveName(preferDisplayName: prefer),
                      style: theme.textTheme.bodySmall,
                    ),
                ],
                if (e.value.length > 4)
                  Text(
                    '+${e.value.length - 4}',
                    style: theme.textTheme.bodySmall,
                  ),
                const SizedBox(width: 14),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
