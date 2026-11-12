import 'package:flutter/material.dart';

import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/prism_glass_icon_button.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_surface.dart';

/// A small labelled number for section dashboards.
class TrackerStatTile extends StatelessWidget {
  const TrackerStatTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.primary;
    return PrismSurface(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: c),
            const SizedBox(height: 6),
          ],
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Lays out [TrackerStatTile]s in 2–4 columns depending on width.
class TrackerStatGrid extends StatelessWidget {
  const TrackerStatGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 720
            ? 4
            : c.maxWidth >= 420
            ? 3
            : 2;
        const gap = 8.0;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children) SizedBox(width: w, child: child),
          ],
        );
      },
    );
  }
}

/// Shows [child] unless [isPrivate] and not yet revealed, in which case a
/// "Private · tap to reveal" placeholder stands in.
class PrivateReveal extends StatefulWidget {
  const PrivateReveal({
    super.key,
    required this.isPrivate,
    required this.child,
  });

  final bool isPrivate;
  final Widget child;

  @override
  State<PrivateReveal> createState() => _PrivateRevealState();
}

class _PrivateRevealState extends State<PrivateReveal> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.isPrivate || _revealed) return widget.child;
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: context.l10n.trackerPrivateReveal,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _revealed = true),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                AppIcons.privateLock,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  context.l10n.trackerPrivateReveal,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Read-only tag pills.
class TagWrap extends StatelessWidget {
  const TagWrap({super.key, required this.tags, this.onTap});

  final List<String> tags;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final t in tags)
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap == null ? null : () => onTap!(t),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer.withValues(
                  alpha: 0.6,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '#$t',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Full-screen editor chrome: top bar with a save check, scrolling body.
class TrackerEditorScaffold extends StatelessWidget {
  const TrackerEditorScaffold({
    super.key,
    required this.title,
    required this.canSave,
    required this.onSave,
    required this.children,
    this.scrollController,
    this.leading,
  });

  final String title;
  final bool canSave;
  final VoidCallback onSave;
  final List<Widget> children;
  final ScrollController? scrollController;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        children: [
          PrismSheetTopBar(
            title: title,
            leading: leading,
            trailing: PrismGlassIconButton(
              icon: AppIcons.check,
              tooltip: context.l10n.save,
              size: PrismTokens.topBarActionSize,
              tint: canSave ? theme.colorScheme.primary : null,
              accentIcon: canSave,
              onPressed: canSave ? onSave : null,
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

/// Section label used inside editors and dashboards.
class TrackerLabel extends StatelessWidget {
  const TrackerLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A simple horizontal bar showing [value] out of 1.
class TrackerBar extends StatelessWidget {
  const TrackerBar({
    super.key,
    required this.value,
    this.color,
    this.height = 6,
  });

  final double value;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Container(
        height: height,
        color: scheme.surfaceContainerHighest,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value.isNaN ? 0 : value.clamp(0, 1).toDouble(),
          child: Container(color: color ?? scheme.primary),
        ),
      ),
    );
  }
}

/// Fixed palette for categories and collections (ARGB ints, synced).
const trackerPalette = <int>[
  0xFF7E57C2,
  0xFF42A5F5,
  0xFF26A69A,
  0xFF66BB6A,
  0xFFFFCA28,
  0xFFFFA726,
  0xFFEF5350,
  0xFFEC407A,
  0xFF8D6E63,
  0xFF78909C,
];
