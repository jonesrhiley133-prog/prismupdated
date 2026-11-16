import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:prism_plurality/features/whats_new/changelog.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_page_scaffold.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_surface.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar.dart';

/// Remembers which version's notes this device has seen (per device, not
/// synced: each install updates on its own).
class WhatsNewStore {
  const WhatsNewStore();

  static const _key = 'whats_new.last_seen_version';

  Future<String?> lastSeen() async {
    try {
      return (await SharedPreferences.getInstance()).getString(_key);
    } on Exception {
      return null;
    }
  }

  Future<void> markSeen(String version) async {
    try {
      await (await SharedPreferences.getInstance()).setString(_key, version);
    } on Exception {
      // Not fatal: the page simply shows again next launch.
    }
  }

  Future<String?> currentVersion() async {
    try {
      return (await PackageInfo.fromPlatform()).version;
    } on Exception {
      return null;
    }
  }
}

final whatsNewStoreProvider = Provider<WhatsNewStore>(
  (ref) => const WhatsNewStore(),
);

/// The release to show now, or null. Shown once per version; only for
/// versions that have notes.
final pendingWhatsNewProvider = FutureProvider<ChangelogRelease?>((ref) async {
  final store = ref.watch(whatsNewStoreProvider);
  final current = await store.currentVersion();
  if (current == null) return null;
  final release = releaseFor(current);
  if (release == null) return null;
  final seen = await store.lastSeen();
  return seen == current ? null : release;
});

/// Opens the notes for the current version once, after the first frame.
class WhatsNewLauncher extends ConsumerStatefulWidget {
  const WhatsNewLauncher({super.key});

  @override
  ConsumerState<WhatsNewLauncher> createState() => _WhatsNewLauncherState();
}

class _WhatsNewLauncherState extends ConsumerState<WhatsNewLauncher> {
  bool _shown = false;

  @override
  Widget build(BuildContext context) {
    ref.listen(pendingWhatsNewProvider, (_, next) {
      final release = next.value;
      if (release == null || _shown) return;
      _shown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await showWhatsNew(context, release);
        await ref.read(whatsNewStoreProvider).markSeen(release.version);
      });
    });
    return const SizedBox.shrink();
  }
}

Future<void> showWhatsNew(BuildContext context, ChangelogRelease release) =>
    PrismSheet.show(
      context: context,
      title: context.l10n.whatsNewTitle,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ReleaseNotes(release: release),
          const SizedBox(height: 16),
          Row(
            children: [
              PrismButton(
                label: ctx.l10n.whatsNewPrevious,
                onPressed: () {
                  Navigator.of(ctx).pop();
                  openChangelog(context);
                },
              ),
              const Spacer(),
              PrismButton(
                label: ctx.l10n.whatsNewDismiss,
                tone: PrismButtonTone.filled,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        ],
      ),
    );

Future<void> openChangelog(BuildContext context) => Navigator.of(
  context,
  rootNavigator: true,
).push(MaterialPageRoute<void>(builder: (_) => const ChangelogScreen()));

class ReleaseNotes extends StatelessWidget {
  const ReleaseNotes({super.key, required this.release});

  final ChangelogRelease release;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    Widget section(String title, IconData icon, List<LocalizedText> items) {
      if (items.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(title, style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 4),
            for (final i in items)
              Padding(
                padding: const EdgeInsets.only(left: 22, top: 4),
                child: Text(i.of(lang), style: theme.textTheme.bodyMedium),
              ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.whatsNewVersion(release.version),
          style: theme.textTheme.titleLarge,
        ),
        Text(
          DateFormat.yMMMMd(context.dateLocale).format(release.date),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        section(l10n.whatsNewFeatures, AppIcons.navInsights, release.features),
        section(
          l10n.whatsNewImprovements,
          AppIcons.check,
          release.improvements,
        ),
        section(l10n.whatsNewFixes, AppIcons.whatsNew, release.fixes),
      ],
    );
  }
}

/// Every release's notes, newest first.
class ChangelogScreen extends StatelessWidget {
  const ChangelogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: context.l10n.whatsNewChangelog,
        showBackButton: true,
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final r in prismChangelog)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: PrismTokens.contentMaxWidth,
                  ),
                  child: PrismSurface(child: ReleaseNotes(release: r)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// About-screen entry to reopen release notes.
class WhatsNewTile extends StatelessWidget {
  const WhatsNewTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: PrismSurface(
        onTap: () => openChangelog(context),
        child: Row(
          children: [
            Icon(
              AppIcons.whatsNew,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(context.l10n.whatsNewChangelog)),
            Icon(AppIcons.chevronRight, size: 18),
          ],
        ),
      ),
    );
  }
}
