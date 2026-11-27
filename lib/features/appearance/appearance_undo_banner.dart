import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/features/appearance/appearance_library.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Shows the last appearance change with an Undo button, for a few minutes.
class AppearanceUndoBanner extends ConsumerWidget {
  const AppearanceUndoBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = ref.watch(appearanceUndoProvider);
    if (u == null ||
        DateTime.now().difference(u.at) > const Duration(minutes: 10)) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer,
          borderRadius: prismCorners(context, 12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                u.message,
                style: TextStyle(color: theme.colorScheme.onSecondaryContainer),
              ),
            ),
            PrismButton(
              label: tr(context, 'Undo', 'Deshacer'),
              density: PrismControlDensity.compact,
              onPressed: () => ref.read(appearanceUndoProvider.notifier).undo(),
            ),
            PrismTopBarAction(
              icon: Icons.close,
              tooltip: tr(context, 'Dismiss', 'Descartar'),
              onPressed: () =>
                  ref.read(appearanceUndoProvider.notifier).clear(),
            ),
          ],
        ),
      ),
    );
  }
}
