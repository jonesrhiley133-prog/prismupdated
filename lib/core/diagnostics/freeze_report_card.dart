import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:prism_plurality/core/diagnostics/freeze_watchdog.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_surface.dart';
import 'package:prism_plurality/shared/widgets/prism_toast.dart';

/// Shows the saved freeze report (if any) with copy / dismiss actions.
class FreezeReportCard extends StatefulWidget {
  const FreezeReportCard({super.key});

  @override
  State<FreezeReportCard> createState() => _FreezeReportCardState();
}

class _FreezeReportCardState extends State<FreezeReportCard> {
  String? _report;

  @override
  void initState() {
    super.initState();
    FreezeWatchdog.lastReport().then((r) {
      if (mounted) setState(() => _report = r);
    });
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    if (report == null || report.trim().isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: PrismSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  AppIcons.warningAmberRounded,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.freezeReportTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(l10n.freezeReportBody, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160),
              child: SingleChildScrollView(
                child: SelectableText(
                  report,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PrismButton(
                  label: l10n.freezeReportCopy,
                  icon: AppIcons.copy,
                  tone: PrismButtonTone.filled,
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: report));
                    if (context.mounted)
                      PrismToast.show(
                        context,
                        message: l10n.freezeReportCopied,
                      );
                  },
                ),
                PrismButton(
                  label: l10n.freezeReportDismiss,
                  onPressed: () async {
                    await FreezeWatchdog.clearReport();
                    if (mounted) setState(() => _report = null);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
