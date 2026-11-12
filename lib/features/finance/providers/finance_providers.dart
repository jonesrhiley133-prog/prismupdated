import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/domain/preferences/finance_preferences.dart';
import 'package:prism_plurality/features/finance/utils/finance.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';
import 'package:prism_plurality/features/work/utils/money.dart';

final financeCurrencyProvider = StreamProvider<String>(
  (ref) => ref
      .watch(appPreferenceRepositoryProvider)
      .watch(financeCurrencyPreference),
);

final financeHideAmountsProvider = StreamProvider<bool>(
  (ref) => ref
      .watch(appPreferenceRepositoryProvider)
      .watch(financeHideAmountsPreference),
);

/// Formats cents in the Finance currency, or a mask when amounts are
/// hidden.
final financeMoneyFormatterProvider = Provider<String Function(int cents)>((
  ref,
) {
  final code = ref.watch(financeCurrencyProvider).value ?? 'USD';
  final hide = ref.watch(financeHideAmountsProvider).value ?? false;
  return (cents) => hide ? '••••' : formatMoneyCents(cents, code);
});

List<TrackerRecord> _kind(Ref ref, String kind) =>
    ref.watch(trackerKindProvider(kind)).value ?? const [];

final financeTxnsProvider = Provider<List<TrackerRecord>>(
  (ref) => _kind(ref, TrackerKind.financeTxn),
);
final financeAccountsProvider = Provider<List<TrackerRecord>>(
  (ref) =>
      [..._kind(ref, TrackerKind.financeAccount)]
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
);
final financeBudgetsProvider = Provider<List<TrackerRecord>>(
  (ref) => _kind(ref, TrackerKind.financeBudget),
);
final financeGoalsProvider = Provider<List<TrackerRecord>>(
  (ref) => _kind(ref, TrackerKind.financeGoal),
);
final financeRecurringProvider = Provider<List<TrackerRecord>>(
  (ref) => [..._kind(ref, TrackerKind.financeRecurring)]
    ..sort(
      (a, b) =>
          (a.occurredAt ?? a.createdAt).compareTo(b.occurredAt ?? b.createdAt),
    ),
);

/// Records due recurring transactions. Items with auto-add on are posted
/// automatically (catching up missed periods); the rest stay "due" until
/// the user adds or skips them.
class FinanceRecurringRunner {
  FinanceRecurringRunner(this._notifier);

  final TrackerNotifier _notifier;

  Future<int> postDue(
    Iterable<TrackerRecord> recurring,
    DateTime today, {
    bool onlyAuto = true,
  }) async {
    var posted = 0;
    for (final r in recurring) {
      if (onlyAuto && !r.flag(FinField.autoAdd)) continue;
      final due = dueOccurrences(r, today);
      if (due.isEmpty) continue;
      for (final d in due) {
        await postOccurrence(r, d);
        posted++;
      }
    }
    return posted;
  }

  Future<void> postOccurrence(TrackerRecord r, DateTime due) async {
    await _notifier.create(
      kind: TrackerKind.financeTxn,
      title: r.title,
      amount: r.amount,
      occurredAt: due,
      fields: {
        FinField.type: r.str(FinField.type) ?? TxnType.expense,
        FinField.category: r.str(FinField.category),
        FinField.account: r.str(FinField.account),
        FinField.toAccount: r.str(FinField.toAccount),
        FinField.recurringId: r.id,
      },
    );
    await skipOccurrence(r, due);
  }

  /// Moves the next due date past [due] without posting.
  Future<void> skipOccurrence(TrackerRecord r, DateTime due) => _notifier.save(
    r.copyWith(
      occurredAt: advanceDue(
        due,
        r.str(FinField.interval) ?? RecurInterval.monthly,
      ),
    ),
  );
}

final financeRecurringRunnerProvider = Provider<FinanceRecurringRunner>(
  (ref) => FinanceRecurringRunner(ref.read(trackerNotifierProvider.notifier)),
);
