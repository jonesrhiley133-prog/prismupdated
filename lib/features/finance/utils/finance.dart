import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';

/// Field keys inside finance records' `data`.
abstract final class FinField {
  static const type = 'type';
  static const category = 'category';
  static const account = 'account';
  static const toAccount = 'toAccount';
  static const accountType = 'accountType';
  static const saved = 'saved';
  static const color = 'color';
  static const interval = 'interval';
  static const autoAdd = 'autoAdd';
  static const recurringId = 'recurringId';
  static const workJobId = 'workJobId';
}

abstract final class TxnType {
  static const income = 'income';
  static const expense = 'expense';
  static const transfer = 'transfer';
}

abstract final class RecurInterval {
  static const weekly = 'weekly';
  static const biweekly = 'biweekly';
  static const monthly = 'monthly';
  static const quarterly = 'quarterly';
  static const yearly = 'yearly';
  static const all = [weekly, biweekly, monthly, quarterly, yearly];
}

const expenseCategories = [
  'housing',
  'groceries',
  'dining',
  'transport',
  'utilities',
  'health',
  'personal',
  'entertainment',
  'shopping',
  'education',
  'subscriptions',
  'gifts',
  'pets',
  'travel',
  'debt',
  'other',
];

const incomeCategories = [
  'salary',
  'freelance',
  'benefits',
  'gifts',
  'refunds',
  'interest',
  'other',
];

const accountTypes = ['cash', 'checking', 'savings', 'credit', 'investment'];

String txnType(TrackerRecord t) => t.str(FinField.type) ?? TxnType.expense;

/// Signed effect of [t] on [accountId] (cents).
int effectOn(TrackerRecord t, String accountId) {
  final amount = t.amount ?? 0;
  final type = txnType(t);
  if (type == TxnType.transfer) {
    var v = 0;
    if (t.str(FinField.account) == accountId) v -= amount;
    if (t.str(FinField.toAccount) == accountId) v += amount;
    return v;
  }
  if (t.str(FinField.account) != accountId) return 0;
  return type == TxnType.income ? amount : -amount;
}

/// Opening balance ([TrackerRecord.amount]) plus every transaction.
int accountBalance(TrackerRecord account, Iterable<TrackerRecord> txns) {
  var b = account.amount ?? 0;
  for (final t in txns) {
    b += effectOn(t, account.id);
  }
  return b;
}

DateTime _monthStart(DateTime d) => DateTime(d.year, d.month);

class MonthTotals {
  const MonthTotals({
    required this.month,
    required this.income,
    required this.expenses,
    required this.byCategory,
  });

  final DateTime month;
  final int income;
  final int expenses;

  /// Expense category → cents.
  final Map<String, int> byCategory;

  int get net => income - expenses;

  /// Share of income kept, 0–1, or null without income.
  double? get savingsRate =>
      income <= 0 ? null : (net / income).clamp(-1, 1).toDouble();
}

/// Income/expense totals for the month containing [month]. Transfers are
/// neither income nor spending.
MonthTotals monthTotals(Iterable<TrackerRecord> txns, DateTime month) {
  final start = _monthStart(month);
  final end = DateTime(start.year, start.month + 1);
  var income = 0, expenses = 0;
  final byCat = <String, int>{};
  for (final t in txns) {
    final d = t.occurredAt ?? t.createdAt;
    if (d.isBefore(start) || !d.isBefore(end)) continue;
    final a = t.amount ?? 0;
    switch (txnType(t)) {
      case TxnType.income:
        income += a;
      case TxnType.expense:
        expenses += a;
        final c = t.str(FinField.category) ?? 'other';
        byCat[c] = (byCat[c] ?? 0) + a;
    }
  }
  return MonthTotals(
    month: start,
    income: income,
    expenses: expenses,
    byCategory: byCat,
  );
}

/// The last [count] months ending with [now]'s month, oldest first.
List<MonthTotals> monthHistory(
  Iterable<TrackerRecord> txns,
  DateTime now, {
  int count = 6,
}) => [
  for (var i = count - 1; i >= 0; i--)
    monthTotals(txns, DateTime(now.year, now.month - i)),
];

class BudgetStatus {
  const BudgetStatus({
    required this.budget,
    required this.category,
    required this.limit,
    required this.spent,
  });

  final TrackerRecord budget;
  final String category;
  final int limit;
  final int spent;

  int get remaining => limit - spent;
  double get fraction => limit <= 0 ? 1 : spent / limit;
  bool get over => spent > limit;
}

List<BudgetStatus> budgetStatuses(
  Iterable<TrackerRecord> budgets,
  MonthTotals month,
) => [
  for (final b in budgets)
    BudgetStatus(
      budget: b,
      category: b.title,
      limit: b.amount ?? 0,
      spent: month.byCategory[b.title] ?? 0,
    ),
]..sort((a, b) => b.fraction.compareTo(a.fraction));

/// The next due date after [from] for [interval]; month-based intervals
/// keep the day of month, clamped to shorter months.
DateTime advanceDue(DateTime from, String interval) {
  DateTime addMonths(int n) {
    final y = from.year + (from.month - 1 + n) ~/ 12;
    final m = (from.month - 1 + n) % 12 + 1;
    final last = DateTime(y, m + 1, 0).day;
    return DateTime(
      y,
      m,
      from.day > last ? last : from.day,
      from.hour,
      from.minute,
    );
  }

  return switch (interval) {
    RecurInterval.weekly => from.add(const Duration(days: 7)),
    RecurInterval.biweekly => from.add(const Duration(days: 14)),
    RecurInterval.quarterly => addMonths(3),
    RecurInterval.yearly => addMonths(12),
    _ => addMonths(1),
  };
}

/// Due dates of [recurring] up to and including [today] (at most [max]).
List<DateTime> dueOccurrences(
  TrackerRecord recurring,
  DateTime today, {
  int max = 24,
}) {
  var next = recurring.occurredAt;
  if (next == null) return const [];
  final end = DateTime(today.year, today.month, today.day + 1);
  final interval = recurring.str(FinField.interval) ?? RecurInterval.monthly;
  final out = <DateTime>[];
  while (next!.isBefore(end) && out.length < max) {
    out.add(next);
    next = advanceDue(next, interval);
  }
  return out;
}

/// Monthly cost of a recurring item, for the "fixed costs" summary.
int monthlyEquivalent(TrackerRecord recurring) {
  final a = recurring.amount ?? 0;
  return switch (recurring.str(FinField.interval)) {
    RecurInterval.weekly => (a * 52 / 12).round(),
    RecurInterval.biweekly => (a * 26 / 12).round(),
    RecurInterval.quarterly => (a / 3).round(),
    RecurInterval.yearly => (a / 12).round(),
    _ => a,
  };
}

bool isFinanceTxn(TrackerRecord r) => r.kind == TrackerKind.financeTxn;
