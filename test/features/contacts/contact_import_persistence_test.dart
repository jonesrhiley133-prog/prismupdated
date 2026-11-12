import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prism_plurality/core/database/app_database.dart';
import 'package:prism_plurality/core/database/database_provider.dart';
import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/core/sync/prism_sync_providers.dart';
import 'package:prism_plurality/domain/preferences/dashboard_preferences.dart';
import 'package:prism_plurality/features/contacts/providers/contact_providers.dart';
import 'package:prism_plurality/features/contacts/utils/birthday_date.dart';
import 'package:prism_plurality/features/contacts/utils/contact_import.dart';
import 'package:prism_plurality/features/cycle/providers/cycle_providers.dart';

ProviderContainer _c(AppDatabase db) => ProviderContainer(
  overrides: [
    databaseProvider.overrideWithValue(db),
    prismSyncHandleProvider.overrideWithBuild((ref, notifier) => null),
  ],
);

void main() {
  test('import creates, updates and skips per the chosen actions', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final c = _c(db);
    addTearDown(c.dispose);
    final n = c.read(contactsNotifierProvider.notifier);
    final existing = await n.create(displayName: 'Ana');
    final cands = [
      const ContactCandidate(
        key: 'a',
        displayName: 'Ana',
        birthday: BirthdayDate(4, 2, 1990),
        source: 'birthday_import',
      ),
      const ContactCandidate(
        key: 'b',
        displayName: 'Ben',
        birthday: BirthdayDate(12, 25),
        source: 'birthday_import',
      ),
      const ContactCandidate(
        key: 'c',
        displayName: 'ben',
        source: 'birthday_import',
      ),
      const ContactCandidate(
        key: 'x',
        displayName: null,
        source: 'birthday_import',
        error: 'missing_name',
      ),
    ];
    final dups = findContactDuplicates(cands, [existing!]);
    final result = await n.importCandidates(cands, dups, {
      'a': DuplicateAction.updateExisting,
      'c': DuplicateAction.skip,
    });
    expect(result.created, 1);
    expect(result.updated, 1);
    expect(result.skipped, 2);
    final all = await c.read(contactRepositoryProvider).getAll();
    expect(all.map((x) => x.displayName).toSet(), {'Ana', 'Ben'});
    expect(
      all.firstWhere((x) => x.displayName == 'Ana').birthday,
      '1990-04-02',
    );
    expect(
      all.firstWhere((x) => x.displayName == 'Ben').birthday,
      '0004-12-25',
    );
    expect(
      upcomingContactBirthdays(
        all,
        DateTime(2026, 12, 20),
      ).single.contact.displayName,
      'Ben',
    );
  });

  test('cycle days save, update and delete when cleared', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final c = _c(db);
    addTearDown(c.dispose);
    final sub = c.listen(cycleEntriesProvider, (_, _) {});
    addTearDown(sub.close);
    final n = c.read(cycleNotifierProvider.notifier);
    final d = DateTime(2026, 3, 1);
    await n.saveDay(d, flow: 3, symptoms: ['cramps']);
    await c.read(cycleEntriesProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(
      (await c.read(cycleEntryRepositoryProvider).getAll()).single.flow,
      3,
    );
    await n.saveDay(d, flow: 2, symptoms: []);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(
      (await c.read(cycleEntryRepositoryProvider).getAll()).single.flow,
      2,
    );
    await n.saveDay(d, flow: 0, symptoms: []);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await c.read(cycleEntryRepositoryProvider).getAll(), isEmpty);
  });

  test('dashboard preferences persist and ignore unknown ids', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final c = _c(db);
    addTearDown(c.dispose);
    final repo = c.read(appPreferenceRepositoryProvider);
    expect(
      await repo.get(dashboardWidgetsPreference),
      DashboardWidgetId.defaults,
    );
    await repo.set(dashboardWidgetsPreference, ['events', 'cycle']);
    expect(await repo.get(dashboardWidgetsPreference), ['events', 'cycle']);
    expect(
      dashboardWidgetsPreference.codec.decode(['cycle', 'bogus', 'cycle']),
      ['cycle'],
    );
    await repo.reset(dashboardWidgetsPreference);
    expect(
      await repo.get(dashboardWidgetsPreference),
      DashboardWidgetId.defaults,
    );
  });
}
