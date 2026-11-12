import 'package:flutter/material.dart';

import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';

/// The six steps every Import Center importer follows.
enum ImportStep { select, preview, validate, duplicates, importing, done }

/// Compact progress header: Select → Preview → Validate → Duplicates →
/// Import → Done.
class ImportStepsHeader extends StatelessWidget {
  const ImportStepsHeader({super.key, required this.current});

  final ImportStep current;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final labels = [
      l10n.importStepSelect,
      l10n.importStepPreview,
      l10n.importStepValidate,
      l10n.importStepDuplicates,
      l10n.importStepImport,
      l10n.importStepDone,
    ];
    return Semantics(
      label: l10n.importStepOf(
        current.index + 1,
        labels.length,
        labels[current.index],
      ),
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Column(
                children: [
                  Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: i <= current.index
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    labels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: i == current.index
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: i <= current.index
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
