import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:prism_plurality/features/dictionary/views/dictionary_import_flow.dart';
import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/features/contacts/providers/contact_providers.dart';
import 'package:prism_plurality/features/import_center/views/contact_import_flow.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/prism_page_scaffold.dart';
import 'package:prism_plurality/shared/widgets/prism_surface.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar.dart';

/// One place for every way to bring data into Prism. Each importer follows
/// the same Select → Preview → Validate → Duplicates → Import → Done flow.
class ImportCenterScreen extends ConsumerWidget {
  const ImportCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final deviceSupported = ref
        .watch(deviceContactsServiceProvider)
        .isSupported;

    void openFlow(ContactImportKind kind) => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ContactImportFlow(kind: kind)),
    );

    final items = <(IconData, String, String, VoidCallback?)>[
      (
        AppIcons.navImport,
        l10n.importCenterPrismBackup,
        l10n.importCenterPrismBackupDesc,
        () => context.go(AppRoutePaths.settingsImportExport),
      ),
      (
        AppIcons.swapHoriz,
        l10n.importCenterOtherApps,
        l10n.importCenterOtherAppsDesc,
        () => context.go(AppRoutePaths.settingsMigration),
      ),
      (
        AppIcons.peopleOutline,
        l10n.importCenterPluralKit,
        l10n.importCenterPluralKitDesc,
        () => context.go(AppRoutePaths.settingsPluralkit),
      ),
      (
        AppIcons.cake,
        l10n.importBirthdaysTitle,
        l10n.importCenterBirthdaysDesc,
        () => openFlow(ContactImportKind.birthdayJson),
      ),
      (
        AppIcons.navContacts,
        l10n.importDeviceContactsTitle,
        deviceSupported
            ? l10n.importCenterDeviceDesc
            : l10n.importDeviceUnsupported,
        deviceSupported ? () => openFlow(ContactImportKind.device) : null,
      ),
      (
        AppIcons.navContacts,
        l10n.importVCardTitle,
        l10n.importCenterVCardDesc,
        () => openFlow(ContactImportKind.vcard),
      ),
      (
        AppIcons.navDictionary,
        l10n.dictImportTitle,
        l10n.importCenterDictionaryDesc,
        () => openDictionaryImport(context),
      ),
    ];

    return PrismPageScaffold(
      topBar: PrismTopBar(title: l10n.importCenterTitle, showBackButton: true),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: PrismTokens.contentMaxWidth),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(l10n.importCenterIntro, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              for (final (icon, title, desc, onTap) in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PrismSurface(
                    onTap: onTap,
                    padding: const EdgeInsets.all(14),
                    child: Opacity(
                      opacity: onTap == null ? 0.5 : 1,
                      child: Row(
                        children: [
                          Icon(icon, color: theme.colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, style: theme.textTheme.titleSmall),
                                Text(
                                  desc,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (onTap != null)
                            Icon(
                              Icons.chevron_right,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                        ],
                      ),
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
