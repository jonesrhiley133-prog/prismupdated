import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:prism_plurality/features/app_update/app_update_provider.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/widgets/info_banner.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';

String appUpdateErrorText(AppLocalizations l10n, String? code) =>
    switch (code) {
      'network' => l10n.appUpdateErrorNetwork,
      'checksum_mismatch' => l10n.appUpdateErrorChecksum,
      'download_failed' => l10n.appUpdateErrorDownload,
      'install_failed' => l10n.appUpdateErrorInstall,
      'no_apk' => l10n.appUpdateErrorNoApk,
      'rate_limited' => l10n.appUpdateErrorRateLimited,
      'not_public' => l10n.localeName.startsWith('es')
          ? 'No se pueden buscar actualizaciones: el registro de paquetes del proyecto de GitLab es privado. Hazlo público (o permite que cualquiera descargue del registro de paquetes) para recibir actualizaciones en la app.'
          : 'Can’t check for updates: the GitLab project’s package registry is private. Make it public (or allow anyone to pull from the package registry) to get in-app updates.',
      'signature_mismatch' => l10n.localeName.startsWith('es')
          ? 'Esta versión está firmada con otra clave, así que Android no puede instalarla encima de la app. Tendrías que desinstalar la app una vez (haz antes una copia de seguridad); las siguientes actualizaciones se instalarán encima.'
          : 'This build is signed with a different key, so Android can’t install it over the app. You’d need to uninstall once (back up first); updates after that install over it.',
      'older_build' => l10n.localeName.startsWith('es')
          ? 'Esta versión no es más nueva que la instalada.'
          : 'This build isn’t newer than the one installed.',
      _ => l10n.appUpdateErrorGeneric,
    };

String _size(int bytes) =>
    bytes <= 0 ? '' : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

class _ProgressBar extends StatelessWidget {
  const _ProgressBar(this.value);

  final double value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      value: '${(value * 100).round()}%',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Container(
          height: 6,
          color: scheme.surfaceContainerHighest,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value.clamp(0, 1).toDouble(),
            child: Container(color: scheme.primary),
          ),
        ),
      ),
    );
  }
}

/// Full update controls for the About screen: current build, check button,
/// download progress, install permission prompt and errors.
class AppUpdateCard extends ConsumerStatefulWidget {
  const AppUpdateCard({super.key});

  @override
  ConsumerState<AppUpdateCard> createState() => _AppUpdateCardState();
}

class _AppUpdateCardState extends ConsumerState<AppUpdateCard> {
  late final Future<PackageInfo?> _installed = PackageInfo.fromPlatform().then<PackageInfo?>((p) => p).catchError((Object _) => null);

  @override
  void initState() {
    super.initState();
    // Opening the card always shows a fresh answer, not one remembered
    // from an earlier automatic check.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final n = ref.read(appUpdateNotifierProvider.notifier);
      final s = ref.read(appUpdateNotifierProvider);
      final stale = s.lastChecked == null || DateTime.now().difference(s.lastChecked!) > const Duration(minutes: 1);
      if (n.isSupported && stale && !s.busy && s.phase != AppUpdatePhase.available) n.check();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(appUpdateNotifierProvider.notifier);
    if (!notifier.isSupported) return const SizedBox.shrink();
    final s = ref.watch(appUpdateNotifierProvider);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final info = s.info;

    final status = switch (s.phase) {
      AppUpdatePhase.idle => l10n.appUpdateTapToCheck,
      AppUpdatePhase.checking => l10n.appUpdateChecking,
      AppUpdatePhase.upToDate => l10n.appUpdateUpToDate,
      AppUpdatePhase.available || AppUpdatePhase.installing =>
        l10n.appUpdateAvailable(info?.version ?? '', info?.buildNumber ?? 0),
      AppUpdatePhase.downloading => l10n.appUpdateDownloading(
        (s.progress * 100).round(),
      ),
      AppUpdatePhase.needsPermission => l10n.appUpdateNeedsPermission,
      AppUpdatePhase.error => appUpdateErrorText(l10n, s.errorCode),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(AppIcons.cloudDownload, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.appUpdateTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              status,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: s.phase == AppUpdatePhase.error
                    ? theme.colorScheme.error
                    : null,
              ),
            ),
            if (info != null &&
                (s.phase == AppUpdatePhase.available ||
                    s.phase == AppUpdatePhase.needsPermission)) ...[
              const SizedBox(height: 4),
              Text(
                [
                  if (info.publishedAt != null)
                    DateFormat.yMMMd(
                      context.dateLocale,
                    ).format(info.publishedAt!.toLocal()),
                  _size(info.sizeBytes),
                ].where((x) => x.isNotEmpty).join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (s.phase == AppUpdatePhase.downloading) ...[
              const SizedBox(height: 12),
              _ProgressBar(s.progress),
            ],
            FutureBuilder<PackageInfo?>(
              future: _installed,
              builder: (context, snap) {
                final p = snap.data;
                if (p == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l10n.appUpdateInstalled(p.version, p.buildNumber),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              l10n.appUpdateKeepsData,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (s.phase == AppUpdatePhase.needsPermission) ...[
                  PrismButton(
                    label: l10n.appUpdateOpenSettings,
                    tone: PrismButtonTone.filled,
                    onPressed: notifier.openPermissionSettings,
                  ),
                  PrismButton(
                    label: l10n.appUpdateInstallNow,
                    onPressed: notifier.downloadAndInstall,
                  ),
                ] else if (info != null &&
                    s.phase != AppUpdatePhase.upToDate &&
                    s.phase != AppUpdatePhase.checking)
                  PrismButton(
                    label: s.downloadedPath == null
                        ? l10n.appUpdateDownloadInstall
                        : l10n.appUpdateInstallNow,
                    icon: AppIcons.download,
                    tone: PrismButtonTone.filled,
                    isLoading: s.busy,
                    enabled: !s.busy,
                    onPressed: notifier.downloadAndInstall,
                  ),
                PrismButton(
                  label: l10n.appUpdateCheckNow,
                  icon: AppIcons.refresh,
                  isLoading: s.phase == AppUpdatePhase.checking,
                  enabled: !s.busy,
                  onPressed: notifier.check,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Home banner shown only when a newer build exists. Checks in the
/// background at most every few hours.
class AppUpdateBanner extends ConsumerStatefulWidget {
  const AppUpdateBanner({super.key});

  @override
  ConsumerState<AppUpdateBanner> createState() => _AppUpdateBannerState();
}

class _AppUpdateBannerState extends ConsumerState<AppUpdateBanner> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(appUpdateNotifierProvider.notifier).autoCheck();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(appUpdateNotifierProvider.notifier);
    if (!notifier.isSupported) return const SizedBox.shrink();
    final s = ref.watch(appUpdateNotifierProvider);
    final info = s.info;
    final show =
        info != null &&
        s.dismissedBuild != info.buildNumber &&
        s.phase != AppUpdatePhase.upToDate &&
        s.phase != AppUpdatePhase.checking;
    if (!show) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final String message = switch (s.phase) {
      AppUpdatePhase.downloading => l10n.appUpdateDownloading(
        (s.progress * 100).round(),
      ),
      AppUpdatePhase.needsPermission => l10n.appUpdateNeedsPermission,
      AppUpdatePhase.error => appUpdateErrorText(l10n, s.errorCode),
      _ => l10n.appUpdateKeepsData,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InfoBanner(
        icon: AppIcons.cloudDownload,
        iconColor: theme.colorScheme.primary,
        title: l10n.appUpdateAvailable(info.version, info.buildNumber),
        message: message,
        actionsBelow: true,
        buttonText: s.busy
            ? null
            : s.phase == AppUpdatePhase.needsPermission
            ? l10n.appUpdateOpenSettings
            : l10n.appUpdateDownloadInstall,
        onButtonPressed: s.busy
            ? null
            : s.phase == AppUpdatePhase.needsPermission
            ? notifier.openPermissionSettings
            : notifier.downloadAndInstall,
        onDismiss: s.busy ? null : notifier.dismiss,
        dismissLabel: l10n.appUpdateLater,
        dismissTooltip: l10n.appUpdateLater,
      ),
    );
  }
}
