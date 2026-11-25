import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/core/web/render_mode.dart' show reloadWebPage;
import 'package:prism_plurality/features/appearance/services/appearance_store.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/core/reset/reset_recovery_app.dart';
import 'package:prism_plurality/domain/preferences/fronting_terms.dart';
import 'package:prism_plurality/features/members/providers/custom_fields_providers.dart';
import 'package:prism_plurality/features/settings/providers/reset_data_provider.dart';
import 'package:prism_plurality/features/settings/providers/terminology_provider.dart';
import 'package:prism_plurality/shared/widgets/app_shell.dart';
import 'package:prism_plurality/shared/widgets/prism_dialog.dart';
import 'package:prism_plurality/shared/widgets/prism_page_scaffold.dart';
import 'package:prism_plurality/shared/widgets/prism_section.dart';
import 'package:prism_plurality/shared/widgets/prism_grouped_section_card.dart';
import 'package:prism_plurality/shared/widgets/prism_settings_row.dart';
import 'package:prism_plurality/shared/widgets/prism_toast.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';

class ResetDataScreen extends ConsumerWidget {
  const ResetDataScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fieldsAsync = ref.watch(topLevelCustomFieldsProvider);
    // while loading/error, disable optimistically — better than a stale-enabled tap target
    final customFieldsEmpty = fieldsAsync.maybeWhen(
      data: (fields) => fields.isEmpty,
      orElse: () => true,
    );

    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: context.l10n.resetDataTitle,
        showBackButton: true,
      ),
      bodyPadding: EdgeInsets.zero,
      body: ListView(
        padding: EdgeInsets.only(bottom: NavBarInset.of(context)),
        children: [
          PrismSection(
            title: 'Settings & looks',
            description: 'These keep all your records. Nothing synced is deleted.',
            child: PrismGroupedSectionCard(
              child: Column(
                children: [
                  PrismSettingsRow(
                    icon: Icons.tune,
                    iconColor: Colors.blueGrey,
                    title: 'App preferences',
                    subtitle: 'Settings stored on this device (launch screen, notifications choices, layout). Your records, appearance and account stay.',
                    onTap: () => _resetPreferences(context, ref),
                  ),
                  const Divider(height: 1, indent: 60, endIndent: 12),
                  PrismSettingsRow(
                    icon: Icons.palette_outlined,
                    iconColor: Colors.purple,
                    title: 'Appearance & themes',
                    subtitle: 'Back to the default Prism look. Saved looks and per-page themes are removed; records stay.',
                    onTap: () => _resetAppearance(context, ref),
                  ),
                  const Divider(height: 1, indent: 60, endIndent: 12),
                  PrismSettingsRow(
                    icon: Icons.extension_outlined,
                    iconColor: Colors.indigo,
                    title: 'One feature\'s data',
                    subtitle: 'Pick a feature in Settings › Features to reset just its data, with a recovery window.',
                    onTap: () => context.push(AppRoutePaths.settingsFeatures),
                  ),
                  const Divider(height: 1, indent: 60, endIndent: 12),
                  PrismSettingsRow(
                    icon: Icons.cloud_off_outlined,
                    iconColor: Colors.lightBlue,
                    title: 'Cloud backups',
                    subtitle: 'Delete backups or your whole account from Account & backup. This device\'s data stays.',
                    onTap: () => context.push(AppRoutePaths.account),
                  ),
                ],
              ),
            ),
          ),
          PrismSection(
            title: context.l10n.resetDataCategoriesSection,
            description: context.l10n.resetDataCategoriesDescription,
            child: PrismGroupedSectionCard(
              child: Column(
                children: [
                  for (var i = 0; i < _granularCategories.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, indent: 60, endIndent: 12),
                    _buildResetRow(
                      context,
                      ref,
                      icon: _granularCategories[i].icon,
                      iconColor: _granularCategories[i].color,
                      category: _granularCategories[i].category,
                      enabled:
                          _granularCategories[i].category ==
                              ResetCategory.customFields
                          ? !customFieldsEmpty
                          : true,
                    ),
                  ],
                ],
              ),
            ),
          ),
          PrismSection(
            title: context.l10n.resetDataDangerZone,
            child: PrismGroupedSectionCard(
              child: Column(
                children: [
                  _buildResetRow(
                    context,
                    ref,
                    icon: AppIcons.syncDisabled,
                    iconColor: Colors.deepOrange,
                    category: ResetCategory.sync,
                    destructive: true,
                  ),
                  const Divider(height: 1, indent: 60, endIndent: 12),
                  _buildResetRow(
                    context,
                    ref,
                    icon: AppIcons.deleteForever,
                    iconColor: Colors.red,
                    category: ResetCategory.all,
                    destructive: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResetRow(
    BuildContext context,
    WidgetRef ref, {
    required IconData icon,
    required Color iconColor,
    required ResetCategory category,
    bool destructive = false,
    bool enabled = true,
  }) {
    final terms = readTerminology(context, ref);
    final frontingTerms = watchFrontingTerms(context, ref);
    return PrismSettingsRow(
      icon: icon,
      iconColor: iconColor,
      title: _categoryLabel(context, category, terms, frontingTerms),
      subtitle: _categoryDescription(context, category, terms, frontingTerms),
      destructive: destructive,
      enabled: enabled,
      onTap: enabled ? () => _showConfirmation(context, ref, category) : null,
    );
  }

  Future<void> _showConfirmation(
    BuildContext context,
    WidgetRef ref,
    ResetCategory category,
  ) async {
    final isAll = category == ResetCategory.all;
    final isSync = category == ResetCategory.sync;
    if (isAll && !await _offerBackup(context)) return;
    if (!context.mounted) return;
    final isCustomFields = category == ResetCategory.customFields;
    final terms = readTerminology(context, ref);
    final frontingTerms = readFrontingTerms(context, ref);
    final label = _categoryLabel(context, category, terms, frontingTerms);
    final confirmed = await PrismDialog.confirm(
      context: context,
      title: isSync
          ? context.l10n.resetDataConfirmSyncTitle
          : isCustomFields
          ? context.l10n.resetDataConfirmCustomFieldsTitle
          : context.l10n.resetDataConfirmTitle(label),
      message: isAll
          ? context.l10n.resetDataConfirmAll(
              terms.pluralLower,
              frontingTerms.sessionPluralLower,
            )
          : isSync
          ? context.l10n.resetDataConfirmSync
          : isCustomFields
          ? context.l10n.resetDataConfirmCustomFieldsBody
          : context.l10n.resetDataConfirmCategory(label.toLowerCase()),
      confirmLabel: isAll
          ? context.l10n.resetDataConfirmEverything
          : isSync
          ? context.l10n.resetDataConfirmSync2
          : context.l10n.delete,
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    try {
      final isAndroid = ref.read(resetIsAndroidProvider);
      await ref.read(resetDataNotifierProvider.notifier).reset(category);
      if (!context.mounted) return;
      if (isAll && kIsWeb) {
        // The browser database is empty now; reload into onboarding.
        reloadWebPage();
        return;
      }
      if (isAll) {
        final restartRequired = await ref
            .read(fullResetServiceProvider)
            .isRestartRequired();
        if (!context.mounted) return;
        if (isAndroid && !restartRequired) {
          await Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute<void>(
              builder: (_) => const ResetRecoveryScreen(
                mode: ResetRecoveryScreenMode.androidClearing,
              ),
            ),
            (_) => false,
          );
          return;
        }
        if (!shouldShowResetRestartScreenAfterSuccess(
          category,
          isAndroid: isAndroid,
          restartRequired: restartRequired,
        )) {
          PrismToast.show(
            context,
            message: context.l10n.resetDataSuccess(label),
          );
          return;
        }
        await Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => const ResetRecoveryScreen(
              mode: ResetRecoveryScreenMode.restartRequired,
            ),
          ),
          (_) => false,
        );
        return;
      }
      PrismToast.show(
        context,
        message: isSync
            ? context.l10n.resetDataSyncDisconnected
            : context.l10n.resetDataSuccess(label),
      );
    } catch (e) {
      if (!context.mounted) return;
      PrismToast.error(context, message: context.l10n.resetDataFailed(e));
    }
  }

  /// Offers to make a backup first. Returns false if the user cancels.
  Future<bool> _offerBackup(BuildContext context) async {
    final pick = await PrismDialog.show<String>(
      context: context,
      title: 'Make a backup first?',
      message: 'A backup lets you undo this later by importing it. Deleted data can\'t be recovered otherwise.',
      builder: (_) => const SizedBox.shrink(),
      actions: [
        PrismButton(label: 'Cancel', onPressed: () => Navigator.of(context, rootNavigator: true).pop('cancel')),
        PrismButton(label: 'Back up first', onPressed: () => Navigator.of(context, rootNavigator: true).pop('backup')),
        PrismButton(label: 'Continue', tone: PrismButtonTone.destructive, onPressed: () => Navigator.of(context, rootNavigator: true).pop('go')),
      ],
    );
    if (pick == 'backup' && context.mounted) {
      await context.push(AppRoutePaths.settingsImportExport);
      return false;
    }
    return pick == 'go';
  }

  Future<void> _resetPreferences(BuildContext context, WidgetRef ref) async {
    final ok = await PrismDialog.confirm(context: context, title: 'Reset app preferences?', message: 'Device settings go back to their defaults. Records, appearance, accounts and synced data are kept.', confirmLabel: 'Reset preferences', destructive: true);
    if (!ok) return;
    final prefs = await SharedPreferences.getInstance();
    for (final k in prefs.getKeys().toList()) {
      if (k == 'appearance.state.v1') continue;
      await prefs.remove(k);
    }
    if (!context.mounted) return;
    if (kIsWeb) return reloadWebPage();
    PrismToast.show(context, message: 'Preferences reset. Some take effect the next time Prism opens.');
  }

  Future<void> _resetAppearance(BuildContext context, WidgetRef ref) async {
    final ok = await PrismDialog.confirm(context: context, title: 'Reset appearance?', message: 'Prism goes back to its default look. Saved looks and page themes are removed. Records are kept.', confirmLabel: 'Reset appearance', destructive: true);
    if (!ok) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('appearance.state.v1');
    final repo = ref.read(trackerRecordRepositoryProvider);
    for (final r in await repo.getAll()) {
      if (r.kind == appearanceSettingKind) await repo.delete(r.id);
    }
    ref.invalidate(appearanceProvider);
    if (context.mounted) PrismToast.show(context, message: 'Appearance reset');
  }

  String _categoryLabel(
    BuildContext context,
    ResetCategory category,
    Terminology terms,
    FrontingTermBundle frontingTerms,
  ) => switch (category) {
    ResetCategory.members => terms.plural,
    ResetCategory.fronting => frontingTerms.sessionPlural,
    _ => context.l10n.resetDataCategoryLabel(category.name),
  };

  String _categoryDescription(
    BuildContext context,
    ResetCategory category,
    Terminology terms,
    FrontingTermBundle frontingTerms,
  ) => switch (category) {
    ResetCategory.members => context.l10n.resetDataMembersDescription(
      terms.pluralLower,
      frontingTerms.sessionPlural,
    ),
    ResetCategory.fronting => context.l10n.resetDataFrontingDescription(
      frontingTerms.historyLabel,
    ),
    _ => context.l10n.resetDataCategoryDescription(category.name),
  };
}

class _CategoryEntry {
  const _CategoryEntry(this.category, this.icon, this.color);
  final ResetCategory category;
  final IconData icon;
  final Color color;
}

final _granularCategories = [
  _CategoryEntry(ResetCategory.members, AppIcons.peopleOutline, Colors.blue),
  _CategoryEntry(ResetCategory.fronting, AppIcons.swapHoriz, Colors.purple),
  _CategoryEntry(ResetCategory.chat, AppIcons.chatBubbleOutline, Colors.teal),
  _CategoryEntry(ResetCategory.polls, AppIcons.pollOutlined, Colors.orange),
  _CategoryEntry(
    ResetCategory.habits,
    AppIcons.checkCircleOutline,
    Colors.green,
  ),
  _CategoryEntry(ResetCategory.sleep, AppIcons.bedtimeOutlined, Colors.indigo),
  _CategoryEntry(ResetCategory.mood, AppIcons.navMood, Colors.amber),
  _CategoryEntry(ResetCategory.calendar, AppIcons.navCalendar, Colors.cyan),
  _CategoryEntry(ResetCategory.locations, AppIcons.navLocations, Colors.teal),
  _CategoryEntry(ResetCategory.work, AppIcons.navWork, Colors.brown),
  _CategoryEntry(ResetCategory.cycle, AppIcons.navCycle, Colors.redAccent),
  _CategoryEntry(ResetCategory.contacts, AppIcons.navContacts, Colors.blueGrey),
  _CategoryEntry(ResetCategory.lifeTrackers, AppIcons.navJournal, Colors.brown),
  _CategoryEntry(
    ResetCategory.customFields,
    AppIcons.tuneOutlined,
    Colors.pink,
  ),
];

@visibleForTesting
bool shouldShowResetRestartScreenAfterSuccess(
  ResetCategory category, {
  required bool isAndroid,
  bool restartRequired = false,
}) {
  return category == ResetCategory.all && (!isAndroid || restartRequired);
}
