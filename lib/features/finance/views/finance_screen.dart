import 'package:prism_plurality/shared/widgets/section_switcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:prism_plurality/features/settings/views/feature_data_screen.dart';
import 'package:prism_plurality/features/trackers/widgets/member_picker.dart';
import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/domain/preferences/finance_preferences.dart';
import 'package:prism_plurality/features/finance/providers/finance_providers.dart';
import 'package:prism_plurality/features/finance/utils/finance.dart';
import 'package:prism_plurality/features/finance/views/finance_editors.dart';
import 'package:prism_plurality/features/finance/views/finance_labels.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';
import 'package:prism_plurality/features/trackers/widgets/tracker_widgets.dart';
import 'package:prism_plurality/features/work/providers/work_providers.dart';
import 'package:prism_plurality/features/work/utils/money.dart';
import 'package:prism_plurality/features/work/utils/work_stats.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/app_shell.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';
import 'package:prism_plurality/shared/widgets/prism_dialog.dart';
import 'package:prism_plurality/shared/widgets/prism_page_scaffold.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_surface.dart';
import 'package:prism_plurality/shared/widgets/prism_text_field.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar_action.dart';

enum FinanceTab { overview, transactions, budgets, goals, recurring }

class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key, this.showBackButton = false});

  final bool showBackButton;

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  FinanceTab _tab = FinanceTab.overview;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  final _search = TextEditingController();
  String? _typeFilter;
  bool _postedRecurring = false;
  String? _member;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<TrackerRecord> _txns() => [
    for (final t in ref.watch(financeTxnsProvider))
      if (_member == null || t.memberId == _member) t,
  ];

  void _postAutoRecurring(List<TrackerRecord> recurring) {
    if (_postedRecurring) return;
    _postedRecurring = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(financeRecurringRunnerProvider)
          .postDue(recurring, DateTime.now());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final records = ref.watch(trackerRecordsProvider);
    final hide = ref.watch(financeHideAmountsProvider).value ?? false;
    final recurring = ref.watch(financeRecurringProvider);
    if (records.hasValue) _postAutoRecurring(recurring);
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: l10n.navFinance,
        showBackButton: widget.showBackButton,
        actions: [
          FeatureDataAction(featureId: 'finance'),
          PrismTopBarAction(
            icon: hide ? AppIcons.privateEyeSlash : AppIcons.visibility,
            tooltip: hide ? l10n.finShowAmounts : l10n.finHideAmounts,
            onPressed: () => ref
                .read(appPreferenceRepositoryProvider)
                .set(financeHideAmountsPreference, !hide),
          ),
          PrismTopBarAction(
            icon: AppIcons.add,
            tooltip: l10n.finNewTxn,
            onPressed: () => switch (_tab) {
              FinanceTab.budgets => showBudgetEditor(context),
              FinanceTab.goals => showGoalEditor(context),
              FinanceTab.recurring => showRecurringEditor(context),
              _ => showTxnEditor(context),
            },
          ),
        ],
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, NavBarInset.of(context) + 24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: PrismTokens.contentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final t in FinanceTab.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: PrismChip(
                              label: switch (t) {
                                FinanceTab.overview => l10n.finTabOverview,
                                FinanceTab.transactions =>
                                  l10n.finTabTransactions,
                                FinanceTab.budgets => l10n.finTabBudgets,
                                FinanceTab.goals => l10n.finTabGoals,
                                FinanceTab.recurring => l10n.finTabRecurring,
                              },
                              selected: _tab == t,
                              onTap: () => setState(() => _tab = t),
                            ),
                          ),
                      ],
                    ),
                  ),
                  TrackerMemberFilter(
                    value: _member,
                    onChanged: (m) => setState(() => _member = m),
                    onlyIds: {
                      for (final t in ref.watch(financeTxnsProvider))
                        ?t.memberId,
                    },
                  ),
                  const SizedBox(height: 12),
                  if (_tab == FinanceTab.overview || _tab == FinanceTab.budgets)
                    _MonthSwitcher(
                      month: _month,
                      onChanged: (m) => setState(() => _month = m),
                    ),
                  SectionSwitcher(
                    id: _tab,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ...switch (_tab) {
                          FinanceTab.overview => _overview(context),
                          FinanceTab.transactions => _transactions(context),
                          FinanceTab.budgets => _budgets(context),
                          FinanceTab.goals => _goals(context),
                          FinanceTab.recurring => _recurring(context),
                        },
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _overview(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final money = ref.watch(financeMoneyFormatterProvider);
    final txns = _txns();
    final accounts = ref.watch(financeAccountsProvider);
    final m = monthTotals(txns, _month);
    final history = monthHistory(txns, _month);
    final maxBar = history.fold<int>(
      1,
      (a, h) => [a, h.income, h.expenses].reduce((x, y) => x > y ? x : y),
    );
    final cats = m.byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final rate = m.savingsRate;
    return [
      TrackerStatGrid(
        children: [
          TrackerStatTile(
            label: l10n.finIncome,
            value: money(m.income),
            icon: AppIcons.arrowDownward,
            color: financeTypeColor(theme, TxnType.income),
          ),
          TrackerStatTile(
            label: l10n.finSpent,
            value: money(m.expenses),
            icon: AppIcons.arrowUpward,
            color: financeTypeColor(theme, TxnType.expense),
          ),
          TrackerStatTile(
            label: l10n.finNet,
            value: money(m.net),
            icon: AppIcons.navFinance,
          ),
          TrackerStatTile(
            label: l10n.finSavingsRate,
            value: rate == null ? '–' : '${(rate * 100).round()}%',
            icon: AppIcons.navAchievements,
          ),
        ],
      ),
      TrackerLabel(l10n.finSixMonths),
      PrismSurface(
        child: SizedBox(
          height: 140,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final h in history)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (final (v, type) in [
                              (h.income, TxnType.income),
                              (h.expenses, TxnType.expense),
                            ])
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 1.5,
                                ),
                                child: FractionallySizedBox(
                                  heightFactor: (v / maxBar).clamp(0.02, 1),
                                  child: Container(
                                    width: 10,
                                    decoration: BoxDecoration(
                                      color: financeTypeColor(theme, type),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat.MMM(context.dateLocale).format(h.month),
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      TrackerLabel(l10n.finSpendingByCategory),
      if (cats.isEmpty)
        Text(l10n.finNoSpending, style: theme.textTheme.bodySmall)
      else
        PrismSurface(
          child: Column(
            children: [
              for (final c in cats)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(financeCategoryLabel(l10n, c.key)),
                          ),
                          Text(money(c.value)),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 40,
                            child: Text(
                              '${(c.value * 100 / m.expenses).round()}%',
                              textAlign: TextAlign.end,
                              style: theme.textTheme.labelSmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      TrackerBar(
                        value: c.value / m.expenses,
                        color: financeCategoryColor(c.key),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ..._spendingByMember(context, money),
      TrackerLabel(
        l10n.finAccounts,
        trailing: PrismButton(
          label: l10n.finNewAccount,
          icon: AppIcons.add,
          density: PrismControlDensity.compact,
          onPressed: () => showAccountEditor(context),
        ),
      ),
      if (accounts.isEmpty)
        Text(l10n.finNoAccounts, style: theme.textTheme.bodySmall)
      else ...[
        for (final a in accounts)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: PrismSurface(
              onTap: () => showAccountEditor(context, editing: a),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.title, style: theme.textTheme.titleSmall),
                        Text(
                          financeAccountTypeLabel(
                            l10n,
                            a.str(FinField.accountType) ?? 'checking',
                          ),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    money(accountBalance(a, txns)),
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            l10n.finTotalBalance(
              money(accounts.fold(0, (s, a) => s + accountBalance(a, txns))),
            ),
            style: theme.textTheme.labelLarge,
          ),
        ),
      ],
      const _WorkEarningsCard(),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerLeft,
        child: PrismButton(
          label: l10n.finSettings,
          icon: AppIcons.navSettings,
          density: PrismControlDensity.compact,
          onPressed: () => PrismSheet.show(
            context: context,
            title: l10n.finSettings,
            builder: (_) => const _FinanceSettingsSheet(),
          ),
        ),
      ),
    ];
  }

  List<Widget> _spendingByMember(
    BuildContext context,
    String Function(int) money,
  ) {
    if (_member != null) return const [];
    final m = monthTotals(const [], _month);
    final start = m.month;
    final end = DateTime(start.year, start.month + 1);
    final by = <String?, int>{};
    for (final t in ref.watch(financeTxnsProvider)) {
      final d = t.occurredAt ?? t.createdAt;
      if (txnType(t) != TxnType.expense ||
          d.isBefore(start) ||
          !d.isBefore(end)) {
        continue;
      }
      by[t.memberId] = (by[t.memberId] ?? 0) + (t.amount ?? 0);
    }
    if (by.keys.every((k) => k == null)) return const [];
    final total = by.values.fold(0, (a, b) => a + b);
    final rows = by.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final l10n = context.l10n;
    return [
      TrackerLabel(l10n.finSpendingByMember),
      PrismSurface(
        child: Column(
          children: [
            for (final e in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            memberNameFor(ref, e.key) ??
                                l10n.trackerWholeSystem,
                          ),
                        ),
                        Text(money(e.value)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    TrackerBar(value: total == 0 ? 0 : e.value / total),
                  ],
                ),
              ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _transactions(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final money = ref.watch(financeMoneyFormatterProvider);
    final accounts = {
      for (final a in ref.watch(financeAccountsProvider)) a.id: a.title,
    };
    final q = _search.text.trim().toLowerCase();
    final txns = [
      for (final t in _txns())
        if ((_typeFilter == null || txnType(t) == _typeFilter) &&
            (q.isEmpty ||
                t.title.toLowerCase().contains(q) ||
                (t.body ?? '').toLowerCase().contains(q) ||
                financeCategoryLabel(
                  l10n,
                  t.str(FinField.category) ?? '',
                ).toLowerCase().contains(q) ||
                t.tags.any((x) => x.toLowerCase().contains(q))))
          t,
    ];
    final out = <Widget>[
      PrismTextField(
        controller: _search,
        hintText: l10n.finSearch,
        prefixIcon: Icon(AppIcons.search),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        children: [
          PrismChip(
            label: l10n.journalFilterAll,
            selected: _typeFilter == null,
            onTap: () => setState(() => _typeFilter = null),
          ),
          for (final t in [TxnType.expense, TxnType.income, TxnType.transfer])
            PrismChip(
              label: financeTypeLabel(l10n, t),
              selected: _typeFilter == t,
              onTap: () => setState(() => _typeFilter = t),
            ),
        ],
      ),
      if (txns.isEmpty)
        Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: Text(l10n.finNoTxns)),
        ),
    ];
    String? day;
    for (final t in txns) {
      final d = t.occurredAt ?? t.createdAt;
      final label = DateFormat.yMMMEd(context.dateLocale).format(d);
      if (label != day) {
        day = label;
        out.add(TrackerLabel(label));
      }
      final type = txnType(t);
      final sign = switch (type) {
        TxnType.income => '+',
        TxnType.expense => '−',
        _ => '',
      };
      out.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: PrismSurface(
            onTap: () => showTxnEditor(context, editing: t),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: type == TxnType.transfer
                        ? theme.colorScheme.outline
                        : financeCategoryColor(
                            t.str(FinField.category) ?? 'other',
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.title, style: theme.textTheme.titleSmall),
                      Text(
                        [
                          if (type == TxnType.transfer)
                            '${accounts[t.str(FinField.account)] ?? '?'} → ${accounts[t.str(FinField.toAccount)] ?? '?'}'
                          else ...[
                            financeCategoryLabel(
                              l10n,
                              t.str(FinField.category) ?? 'other',
                            ),
                            ?accounts[t.str(FinField.account)],
                          ],
                          if (t.str(FinField.recurringId) != null)
                            l10n.finRecurringBadge,
                          ?memberNameFor(ref, t.memberId),
                        ].join(' · '),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  '$sign${money(t.amount ?? 0)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: financeTypeColor(theme, type),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return out;
  }

  List<Widget> _budgets(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final money = ref.watch(financeMoneyFormatterProvider);
    final m = monthTotals(_txns(), _month);
    final statuses = budgetStatuses(ref.watch(financeBudgetsProvider), m);
    final totalLimit = statuses.fold(0, (s, b) => s + b.limit);
    final totalSpent = statuses.fold(0, (s, b) => s + b.spent);
    final unbudgeted = {
      for (final e in m.byCategory.entries)
        if (!statuses.any((s) => s.category == e.key)) e.key: e.value,
    };
    return [
      if (statuses.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(l10n.finNoBudgets),
        )
      else ...[
        PrismSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.finBudgetTotal(money(totalSpent), money(totalLimit)),
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              TrackerBar(
                value: totalLimit == 0 ? 0 : totalSpent / totalLimit,
                height: 10,
                color: totalSpent > totalLimit
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        for (final b in statuses)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: PrismSurface(
              onTap: () => showBudgetEditor(context, editing: b.budget),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          financeCategoryLabel(l10n, b.category),
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      Text('${money(b.spent)} / ${money(b.limit)}'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TrackerBar(
                    value: b.fraction,
                    color: b.over
                        ? theme.colorScheme.error
                        : b.fraction > 0.85
                        ? const Color(0xFFFFA726)
                        : financeCategoryColor(b.category),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    b.over
                        ? l10n.finOverBudget(money(-b.remaining))
                        : l10n.finLeftInBudget(money(b.remaining)),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: b.over ? theme.colorScheme.error : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
      if (unbudgeted.isNotEmpty) ...[
        TrackerLabel(l10n.finUnbudgeted),
        for (final e in unbudgeted.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(child: Text(financeCategoryLabel(l10n, e.key))),
                Text(money(e.value)),
              ],
            ),
          ),
      ],
      const SizedBox(height: 12),
      PrismButton(
        label: l10n.finNewBudget,
        icon: AppIcons.add,
        onPressed: () => showBudgetEditor(context),
      ),
    ];
  }

  List<Widget> _goals(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final money = ref.watch(financeMoneyFormatterProvider);
    final goals = ref.watch(financeGoalsProvider);
    final now = DateTime.now();
    return [
      if (goals.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(l10n.finNoGoals),
        ),
      for (final g in goals)
        Builder(
          builder: (context) {
            final saved = g.integer(FinField.saved) ?? 0;
            final target = g.amount ?? 0;
            final left = target - saved;
            final deadline = g.endedAt;
            final months = deadline == null
                ? null
                : ((deadline.year - now.year) * 12 + deadline.month - now.month)
                      .clamp(1, 1200);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PrismSurface(
                onTap: () => showGoalEditor(context, editing: g),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            g.title,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          '${target == 0 ? 0 : (saved * 100 / target).round()}%',
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TrackerBar(
                      value: target == 0 ? 0 : saved / target,
                      height: 10,
                      color: Color(
                        g.integer(FinField.color) ?? trackerPalette[2],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${money(saved)} / ${money(target)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (left > 0 && months != null)
                      Text(
                        l10n.finGoalPerMonth(
                          money((left / months).ceil()),
                          DateFormat.yMMM(context.dateLocale).format(deadline!),
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                    if (left <= 0)
                      Text(
                        l10n.finGoalReached,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    const SizedBox(height: 8),
                    PrismButton(
                      label: l10n.finAddToGoal,
                      icon: AppIcons.add,
                      density: PrismControlDensity.compact,
                      onPressed: () => _contribute(context, g),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      const SizedBox(height: 12),
      PrismButton(
        label: l10n.finNewGoal,
        icon: AppIcons.add,
        onPressed: () => showGoalEditor(context),
      ),
    ];
  }

  Future<void> _contribute(BuildContext context, TrackerRecord goal) async {
    final l10n = context.l10n;
    final c = TextEditingController();
    final ok = await PrismDialog.show<bool>(
      context: context,
      title: l10n.finAddToGoalTitle(goal.title),
      builder: (_) => MoneyField(controller: c, label: l10n.finAmount),
      actions: [
        PrismButton(
          label: l10n.cancel,
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(false),
        ),
        PrismButton(
          label: l10n.save,
          tone: PrismButtonTone.filled,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
        ),
      ],
    );
    final cents = MoneyField.read(c);
    c.dispose();
    if (ok != true || cents == null || cents <= 0) return;
    await ref
        .read(trackerNotifierProvider.notifier)
        .save(
          goal.withFields({
            FinField.saved: (goal.integer(FinField.saved) ?? 0) + cents,
          }),
        );
  }

  List<Widget> _recurring(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final money = ref.watch(financeMoneyFormatterProvider);
    final items = ref.watch(financeRecurringProvider);
    final runner = ref.read(financeRecurringRunnerProvider);
    final today = DateTime.now();
    final monthlyOut = items
        .where((r) => r.str(FinField.type) != TxnType.income)
        .fold(0, (s, r) => s + monthlyEquivalent(r));
    final monthlyIn = items
        .where((r) => r.str(FinField.type) == TxnType.income)
        .fold(0, (s, r) => s + monthlyEquivalent(r));
    return [
      TrackerStatGrid(
        children: [
          TrackerStatTile(
            label: l10n.finFixedCosts,
            value: money(monthlyOut),
            color: financeTypeColor(theme, TxnType.expense),
          ),
          TrackerStatTile(
            label: l10n.finRegularIncome,
            value: money(monthlyIn),
            color: financeTypeColor(theme, TxnType.income),
          ),
        ],
      ),
      const SizedBox(height: 8),
      if (items.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(l10n.finNoRecurring),
        ),
      for (final r in items)
        Builder(
          builder: (context) {
            final due = dueOccurrences(r, today);
            final next = r.occurredAt;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: PrismSurface(
                onTap: () => showRecurringEditor(context, editing: r),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            r.title,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        Text(
                          money(r.amount ?? 0),
                          style: TextStyle(
                            color: financeTypeColor(
                              theme,
                              r.str(FinField.type) ?? TxnType.expense,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      [
                        financeIntervalLabel(
                          l10n,
                          r.str(FinField.interval) ?? RecurInterval.monthly,
                        ),
                        if (next != null)
                          l10n.finNextOn(
                            DateFormat.MMMd(context.dateLocale).format(next),
                          ),
                        if (r.flag(FinField.autoAdd)) l10n.finAutoAdd,
                      ].join(' · '),
                      style: theme.textTheme.bodySmall,
                    ),
                    if (due.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        l10n.finDueNow(due.length),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [
                          PrismButton(
                            label: l10n.finAddNow,
                            tone: PrismButtonTone.filled,
                            density: PrismControlDensity.compact,
                            onPressed: () =>
                                runner.postOccurrence(r, due.first),
                          ),
                          PrismButton(
                            label: l10n.finSkip,
                            density: PrismControlDensity.compact,
                            onPressed: () =>
                                runner.skipOccurrence(r, due.first),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      const SizedBox(height: 12),
      PrismButton(
        label: l10n.finNewRecurring,
        icon: AppIcons.add,
        onPressed: () => showRecurringEditor(context),
      ),
    ];
  }
}

class _MonthSwitcher extends StatelessWidget {
  const _MonthSwitcher({required this.month, required this.onChanged});

  final DateTime month;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: l10n.finPreviousMonth,
            icon: Icon(AppIcons.arrowBackIos),
            onPressed: () => onChanged(DateTime(month.year, month.month - 1)),
          ),
          Expanded(
            child: Text(
              DateFormat.yMMMM(context.dateLocale).format(month),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            tooltip: l10n.finNextMonth,
            icon: Icon(AppIcons.chevronRight),
            onPressed: () => onChanged(DateTime(month.year, month.month + 1)),
          ),
        ],
      ),
    );
  }
}

/// Estimated earnings from Work this month, with a button to record them
/// as income (once per job and month).
class _WorkEarningsCard extends ConsumerWidget {
  const _WorkEarningsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final sessions = ref.watch(workSessionsProvider).value ?? const [];
    final jobs = ref.watch(jobByIdProvider);
    if (sessions.isEmpty) return const SizedBox.shrink();
    final now = DateTime.now();
    final from = DateTime(now.year, now.month);
    final stats = WorkStats.of(
      sessions,
      now: now,
      from: from,
      to: DateTime(now.year, now.month + 1),
    );
    final monthKey = DateFormat('yyyy-MM').format(from);
    final txns = ref.watch(financeTxnsProvider);
    final rows = [
      for (final e in stats.byJob.entries)
        if (e.value.earningsCents > 0) e,
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: PrismSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(AppIcons.navWork, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.finWorkEarnings,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (final e in rows)
              Builder(
                builder: (context) {
                  final job = jobs[e.key];
                  final recorded = txns.any(
                    (t) => t.str(FinField.workJobId) == '${e.key}:$monthKey',
                  );
                  final amount = formatMoneyCents(
                    e.value.earningsCents,
                    job?.currencyCode ?? 'USD',
                  );
                  return Row(
                    children: [
                      Expanded(child: Text(job?.name ?? '?')),
                      Text(amount),
                      const SizedBox(width: 8),
                      PrismButton(
                        label: recorded ? l10n.finRecorded : l10n.finRecord,
                        density: PrismControlDensity.compact,
                        enabled: !recorded,
                        onPressed: () => ref
                            .read(trackerNotifierProvider.notifier)
                            .create(
                              kind: TrackerKind.financeTxn,
                              title: job?.name ?? l10n.navWork,
                              amount: e.value.earningsCents,
                              occurredAt: now,
                              fields: {
                                FinField.type: TxnType.income,
                                FinField.category: 'salary',
                                FinField.workJobId: '${e.key}:$monthKey',
                              },
                            ),
                      ),
                    ],
                  );
                },
              ),
            Text(l10n.finWorkEarningsHelp, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _FinanceSettingsSheet extends ConsumerWidget {
  const _FinanceSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final current = ref.watch(financeCurrencyProvider).value ?? 'USD';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.finCurrency),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in commonCurrencies)
              PrismChip(
                label: c,
                selected: current == c,
                onTap: () => ref
                    .read(appPreferenceRepositoryProvider)
                    .set(financeCurrencyPreference, c),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          l10n.finCurrencyHelp,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
