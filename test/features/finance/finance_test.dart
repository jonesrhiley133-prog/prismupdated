import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prism_plurality/core/database/app_database.dart';
import 'package:prism_plurality/core/database/database_provider.dart';
import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/core/sync/prism_sync_providers.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/finance/providers/finance_providers.dart';
import 'package:prism_plurality/features/finance/utils/finance.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';

final _t = DateTime(2026);

TrackerRecord _txn(
  String type,
  int cents,
  DateTime at, {
  String? cat,
  String? acc,
  String? to,
}) =>
    TrackerRecord(
      id: '$type$cents$at',
      kind: TrackerKind.financeTxn,
      amount: cents,
      occurredAt: at,
      createdAt: _t,
      modifiedAt: _t,
    ).withFields({
      FinField.type: type,
      FinField.category: cat,
      FinField.account: acc,
      FinField.toAccount: to,
    });

void main() {
  test('balances include opening balance, income, spending and transfers', () {
    final a = TrackerRecord(
      id: 'a',
      kind: TrackerKind.financeAccount,
      amount: 10000,
      createdAt: _t,
      modifiedAt: _t,
    );
    final txns = [
      _txn(TxnType.income, 5000, _t, acc: 'a'),
      _txn(TxnType.expense, 2500, _t, acc: 'a'),
      _txn(TxnType.transfer, 1000, _t, acc: 'a', to: 'b'),
      _txn(TxnType.transfer, 300, _t, acc: 'b', to: 'a'),
      _txn(TxnType.expense, 999, _t, acc: 'other'),
    ];
    expect(accountBalance(a, txns), 10000 + 5000 - 2500 - 1000 + 300);
  });

  test('month totals ignore transfers; budgets and savings rate', () {
    final txns = [
      _txn(TxnType.income, 300000, DateTime(2026, 3, 1)),
      _txn(TxnType.expense, 100000, DateTime(2026, 3, 2), cat: 'housing'),
      _txn(TxnType.expense, 45000, DateTime(2026, 3, 9), cat: 'groceries'),
      _txn(TxnType.transfer, 50000, DateTime(2026, 3, 9)),
      _txn(TxnType.expense, 7000, DateTime(2026, 4, 1), cat: 'groceries'),
    ];
    final m = monthTotals(txns, DateTime(2026, 3, 15));
    expect((m.income, m.expenses, m.net), (300000, 145000, 155000));
    expect(m.byCategory, {'housing': 100000, 'groceries': 45000});
    expect(m.savingsRate, closeTo(0.5167, 0.001));
    final b = TrackerRecord(
      id: 'b',
      kind: TrackerKind.financeBudget,
      title: 'groceries',
      amount: 40000,
      createdAt: _t,
      modifiedAt: _t,
    );
    final s = budgetStatuses([b], m).single;
    expect((s.spent, s.over, s.remaining), (45000, true, -5000));
    expect(
      monthHistory(
        txns,
        DateTime(2026, 4, 10),
        count: 2,
      ).map((h) => h.expenses),
      [145000, 7000],
    );
  });

  test('due dates advance by interval and clamp month ends', () {
    expect(
      advanceDue(DateTime(2026, 1, 31), RecurInterval.monthly),
      DateTime(2026, 2, 28),
    );
    expect(
      advanceDue(DateTime(2026, 11, 15), RecurInterval.quarterly),
      DateTime(2027, 2, 15),
    );
    expect(
      advanceDue(DateTime(2024, 2, 29), RecurInterval.yearly),
      DateTime(2025, 2, 28),
    );
    expect(
      advanceDue(DateTime(2026, 1, 1), RecurInterval.biweekly),
      DateTime(2026, 1, 15),
    );
    final r = TrackerRecord(
      id: 'r',
      kind: TrackerKind.financeRecurring,
      amount: 1200,
      occurredAt: DateTime(2026, 1, 10),
      createdAt: _t,
      modifiedAt: _t,
    ).withFields({FinField.interval: RecurInterval.monthly});
    expect(dueOccurrences(r, DateTime(2026, 3, 10)), [
      DateTime(2026, 1, 10),
      DateTime(2026, 2, 10),
      DateTime(2026, 3, 10),
    ]);
    expect(
      monthlyEquivalent(
        r.withFields({FinField.interval: RecurInterval.yearly}),
      ),
      100,
    );
  });

  test(
    'auto recurring items post missed periods once and move forward',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final c = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          prismSyncHandleProvider.overrideWithBuild((ref, notifier) => null),
        ],
      );
      addTearDown(c.dispose);
      final n = c.read(trackerNotifierProvider.notifier);
      final auto = await n.create(
        kind: TrackerKind.financeRecurring,
        title: 'Rent',
        amount: 90000,
        occurredAt: DateTime(2026, 1, 1),
        fields: {
          FinField.type: TxnType.expense,
          FinField.category: 'housing',
          FinField.interval: RecurInterval.monthly,
          FinField.autoAdd: true,
        },
      );
      final manual = await n.create(
        kind: TrackerKind.financeRecurring,
        title: 'Gym',
        amount: 3000,
        occurredAt: DateTime(2026, 1, 5),
        fields: {FinField.interval: RecurInterval.monthly},
      );
      final runner = c.read(financeRecurringRunnerProvider);
      expect(await runner.postDue([auto, manual], DateTime(2026, 3, 2)), 3);
      final all = await c.read(trackerRecordRepositoryProvider).getAll();
      final txns = all.where((r) => r.kind == TrackerKind.financeTxn).toList();
      expect(txns, hasLength(3));
      expect(
        txns.every(
          (t) => t.str(FinField.recurringId) == auto.id && t.amount == 90000,
        ),
        isTrue,
      );
      expect(
        all.firstWhere((r) => r.id == auto.id).occurredAt,
        DateTime(2026, 4, 1),
      );
      expect(
        all.firstWhere((r) => r.id == manual.id).occurredAt,
        DateTime(2026, 1, 5),
      );
    },
  );
}
