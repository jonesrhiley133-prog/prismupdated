import 'package:go_router/go_router.dart';

import 'package:prism_plurality/features/relationships/hub/rel_editor.dart';
import 'package:prism_plurality/features/relationships/hub/rel_hub_screen.dart';
import 'package:prism_plurality/features/relationships/hub/rel_model.dart';
import 'package:prism_plurality/features/relationships/hub/rel_profile.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Relationships section on an alter's profile. Each relationship is the
/// same single record shown in the hub, read from this alter's side.
class MemberRelationshipsSection extends ConsumerWidget {
  const MemberRelationshipsSection({super.key, required this.memberId});
  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(relSettingsProvider);
    final mine = [
      for (final r in ref.watch(relsProvider))
        if (r.involves(memberId)) r,
    ];
    final groups = <String, List<Rel>>{};
    for (final r in mine) {
      final cats = {
        for (final l in r.labelsFor(memberId)) categoryOf(l, settings),
      };
      final key = cats.contains('familial')
          ? 'familial'
          : (cats.contains('romantic')
                ? 'romantic'
                : (cats.contains('platonic') ? 'platonic' : cats.first));
      (groups[key] ??= []).add(r);
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tr(context, 'Relationships', 'Relaciones'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              PrismTopBarAction(
                icon: AppIcons.add,
                tooltip: tr(context, 'Add relationship', 'Añadir relación'),
                onPressed: () => showRelEditor(context, memberId: memberId),
              ),
            ],
          ),
          if (mine.isEmpty)
            Text(
              tr(
                context,
                'No documented relationships yet.',
                'Aún no hay relaciones documentadas.',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (final c in [
              ...settings.categories.where(groups.containsKey),
            ]) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 6),
                child: Text(
                  relCategoryLabel(context, c, settings),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              for (final r in groups[c]!)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: RelCard(
                    rel: r,
                    viewer: memberId,
                    onTap: () => context.push(relRoute(r.id)),
                  ),
                ),
            ],
        ],
      ),
    );
  }
}
