import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/finance/providers/finance_providers.dart';
import 'package:prism_plurality/features/finance/utils/finance.dart';
import 'package:prism_plurality/features/finance/views/finance_labels.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';
import 'package:prism_plurality/features/trackers/widgets/tracker_widgets.dart';
import 'package:prism_plurality/features/work/utils/money.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';
import 'package:prism_plurality/shared/widgets/prism_date_picker.dart';
import 'package:prism_plurality/shared/widgets/prism_dialog.dart';
import 'package:prism_plurality/shared/widgets/prism_segmented_control.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_switch_row.dart';
import 'package:prism_plurality/shared/widgets/prism_text_field.dart';

Future<void> _sheet(
  BuildContext context,
  Widget Function(ScrollController) b,
) => PrismSheet.showFullScreen(
  context: context,
  builder: (context, scroll) => b(scroll),
);

String _centsText(int? cents) => cents == null
    ? ''
    : (cents / 100).toStringAsFixed(cents % 100 == 0 ? 0 : 2);

/// Amount input with validation; reports cents or null.
class MoneyField extends StatelessWidget {
  const MoneyField({
    super.key,
    required this.controller,
    required this.label,
    this.allowZero = false,
  });

  final TextEditingController controller;
  final String label;
  final bool allowZero;

  static int? read(TextEditingController c) => parseMoneyToCents(c.text);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final v = parseMoneyToCents(controller.text);
        final bad =
            controller.text.trim().isNotEmpty &&
            (v == null || (!allowZero && v == 0));
        return PrismTextField(
          controller: controller,
          labelText: label,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          errorText: bad ? context.l10n.finInvalidAmount : null,
        );
      },
    );
  }
}

Widget _deleteButton(
  BuildContext context,
  WidgetRef ref,
  TrackerRecord? e,
  String title,
) {
  if (e == null) return const SizedBox.shrink();
  final l10n = context.l10n;
  return Padding(
    padding: const EdgeInsets.only(top: 24),
    child: PrismButton(
      label: l10n.trackerDelete,
      icon: AppIcons.delete,
      tone: PrismButtonTone.destructive,
      onPressed: () async {
        final ok = await PrismDialog.confirm(
          context: context,
          title: title,
          confirmLabel: l10n.trackerDelete,
          cancelLabel: l10n.cancel,
          destructive: true,
        );
        if (!ok) return;
        await ref.read(trackerNotifierProvider.notifier).delete(e.id);
        if (context.mounted) Navigator.of(context).pop();
      },
    ),
  );
}

Widget _categoryPicker(
  BuildContext context, {
  required List<String> builtIn,
  required List<String> used,
  required String? selected,
  required ValueChanged<String> onSelected,
}) {
  final l10n = context.l10n;
  final all = [
    ...builtIn,
    for (final u in used)
      if (!builtIn.contains(u)) u,
  ];
  return Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final c in all)
        PrismChip(
          label: financeCategoryLabel(l10n, c),
          selected: selected == c,
          selectedColor: financeCategoryColor(c),
          onTap: () => onSelected(c),
        ),
      PrismChip(
        label: l10n.finCustomCategory,
        selected: selected != null && !all.contains(selected),
        avatar: Icon(AppIcons.add, size: 14),
        onTap: () async {
          final c = TextEditingController();
          final ok = await PrismDialog.show<bool>(
            context: context,
            title: l10n.finCustomCategory,
            builder: (_) => PrismTextField(controller: c, autofocus: true),
            actions: [
              PrismButton(
                label: l10n.cancel,
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).pop(false),
              ),
              PrismButton(
                label: l10n.save,
                tone: PrismButtonTone.filled,
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).pop(true),
              ),
            ],
          );
          final t = c.text.trim();
          c.dispose();
          if (ok == true && t.isNotEmpty) onSelected(t);
        },
      ),
    ],
  );
}

Widget _accountPicker(
  BuildContext context,
  List<TrackerRecord> accounts,
  String? selected,
  ValueChanged<String?> onSelected, {
  bool allowNone = true,
}) {
  final l10n = context.l10n;
  return Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      if (allowNone)
        PrismChip(
          label: l10n.finNoAccount,
          selected: selected == null,
          onTap: () => onSelected(null),
        ),
      for (final a in accounts)
        PrismChip(
          label: a.title,
          selected: selected == a.id,
          onTap: () => onSelected(a.id),
        ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Transaction
// ---------------------------------------------------------------------------

Future<void> showTxnEditor(
  BuildContext context, {
  TrackerRecord? editing,
  String type = TxnType.expense,
}) => _sheet(
  context,
  (s) => TxnEditorSheet(editing: editing, initialType: type, scroll: s),
);

class TxnEditorSheet extends ConsumerStatefulWidget {
  const TxnEditorSheet({
    super.key,
    this.editing,
    this.initialType = TxnType.expense,
    this.scroll,
  });

  final TrackerRecord? editing;
  final String initialType;
  final ScrollController? scroll;

  @override
  ConsumerState<TxnEditorSheet> createState() => _TxnEditorSheetState();
}

class _TxnEditorSheetState extends ConsumerState<TxnEditorSheet> {
  late final TrackerRecord? _e = widget.editing;
  late String _type = widget.editing == null
      ? widget.initialType
      : txnType(widget.editing!);
  late final _amount = TextEditingController(text: _centsText(_e?.amount));
  late final _title = TextEditingController(text: _e?.title ?? '');
  late final _note = TextEditingController(text: _e?.body ?? '');
  late final _tags = TextEditingController(text: _e?.tags.join(', ') ?? '');
  late String? _category = _e?.str(FinField.category);
  late String? _account = _e?.str(FinField.account);
  late String? _toAccount = _e?.str(FinField.toAccount);
  late DateTime _date = _e?.occurredAt ?? DateTime.now();
  bool _saving = false;

  int? get _cents => MoneyField.read(_amount);
  bool get _valid =>
      (_cents ?? 0) > 0 &&
      (_type != TxnType.transfer ||
          (_account != null && _toAccount != null && _account != _toAccount));

  @override
  void dispose() {
    _amount.dispose();
    _title.dispose();
    _note.dispose();
    _tags.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    final l10n = context.l10n;
    final fields = <String, Object?>{
      FinField.type: _type,
      FinField.category: _type == TxnType.transfer
          ? null
          : (_category ?? 'other'),
      FinField.account: _account,
      FinField.toAccount: _type == TxnType.transfer ? _toAccount : null,
    };
    final title = _title.text.trim().isNotEmpty
        ? _title.text.trim()
        : _type == TxnType.transfer
        ? l10n.finTransfer
        : financeCategoryLabel(l10n, _category ?? 'other');
    final n = ref.read(trackerNotifierProvider.notifier);
    final e = _e;
    if (e == null) {
      await n.create(
        kind: TrackerKind.financeTxn,
        title: title,
        body: _note.text,
        amount: _cents,
        occurredAt: _date,
        tags: parseTagInput(_tags.text),
        fields: fields,
      );
    } else {
      await n.save(
        e
            .copyWith(
              title: title,
              body: _note.text,
              amount: _cents,
              occurredAt: _date,
              tags: parseTagInput(_tags.text),
            )
            .withFields(fields),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accounts = ref.watch(financeAccountsProvider);
    final used = {
      for (final t in ref.watch(financeTxnsProvider))
        if (txnType(t) == _type) ?t.str(FinField.category),
    }.toList()..sort();
    return ListenableBuilder(
      listenable: _amount,
      builder: (context, _) => TrackerEditorScaffold(
        title: _e == null ? l10n.finNewTxn : l10n.finEditTxn,
        canSave: _valid && !_saving,
        onSave: _save,
        scrollController: widget.scroll,
        children: [
          PrismSegmentedControl<String>(
            segments: [
              PrismSegment(value: TxnType.expense, label: l10n.finExpense),
              PrismSegment(value: TxnType.income, label: l10n.finIncome),
              PrismSegment(value: TxnType.transfer, label: l10n.finTransfer),
            ],
            selected: _type,
            onChanged: (t) => setState(() {
              _type = t;
              _category = null;
            }),
          ),
          const SizedBox(height: 12),
          MoneyField(controller: _amount, label: l10n.finAmount),
          const SizedBox(height: 12),
          PrismTextField(
            controller: _title,
            labelText: _type == TxnType.income
                ? l10n.finFrom
                : _type == TxnType.transfer
                ? l10n.finDescription
                : l10n.finPayee,
          ),
          const SizedBox(height: 12),
          PrismButton(
            label: DateFormat.yMMMEd(context.dateLocale).format(_date),
            icon: AppIcons.calendarToday,
            density: PrismControlDensity.compact,
            onPressed: () async {
              final d = await showPrismDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(1990),
                lastDate: DateTime.now().add(const Duration(days: 366)),
              );
              if (d != null) setState(() => _date = d);
            },
          ),
          if (_type != TxnType.transfer) ...[
            TrackerLabel(l10n.finCategory),
            _categoryPicker(
              context,
              builtIn: _type == TxnType.income
                  ? incomeCategories
                  : expenseCategories,
              used: used,
              selected: _category,
              onSelected: (c) => setState(() => _category = c),
            ),
          ],
          TrackerLabel(
            _type == TxnType.transfer ? l10n.finFromAccount : l10n.finAccount,
          ),
          _accountPicker(
            context,
            accounts,
            _account,
            (a) => setState(() => _account = a),
            allowNone: _type != TxnType.transfer,
          ),
          if (_type == TxnType.transfer) ...[
            TrackerLabel(l10n.finToAccount),
            _accountPicker(
              context,
              accounts,
              _toAccount,
              (a) => setState(() => _toAccount = a),
              allowNone: false,
            ),
            if (accounts.length < 2)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(l10n.finTransferNeedsAccounts),
              ),
          ],
          const SizedBox(height: 12),
          PrismTextField(
            controller: _note,
            labelText: l10n.finNote,
            maxLines: 4,
          ),
          const SizedBox(height: 12),
          PrismTextField(
            controller: _tags,
            labelText: l10n.trackerTags,
            helperText: l10n.trackerTagsHelp,
          ),
          _deleteButton(context, ref, _e, l10n.finDeleteTxn),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Account
// ---------------------------------------------------------------------------

Future<void> showAccountEditor(
  BuildContext context, {
  TrackerRecord? editing,
}) => _sheet(context, (s) => AccountEditorSheet(editing: editing, scroll: s));

class AccountEditorSheet extends ConsumerStatefulWidget {
  const AccountEditorSheet({super.key, this.editing, this.scroll});

  final TrackerRecord? editing;
  final ScrollController? scroll;

  @override
  ConsumerState<AccountEditorSheet> createState() => _AccountEditorState();
}

class _AccountEditorState extends ConsumerState<AccountEditorSheet> {
  late final TrackerRecord? _e = widget.editing;
  late final _name = TextEditingController(text: _e?.title ?? '');
  late final _opening = TextEditingController(
    text: _centsText(_e?.amount?.abs()),
  );
  late bool _negative = (_e?.amount ?? 0) < 0;
  late String _type = _e?.str(FinField.accountType) ?? 'checking';

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      (_opening.text.trim().isEmpty || MoneyField.read(_opening) != null);

  @override
  void dispose() {
    _name.dispose();
    _opening.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final cents = (MoneyField.read(_opening) ?? 0) * (_negative ? -1 : 1);
    final n = ref.read(trackerNotifierProvider.notifier);
    final e = _e;
    if (e == null) {
      await n.create(
        kind: TrackerKind.financeAccount,
        title: _name.text,
        amount: cents,
        sortOrder: ref.read(financeAccountsProvider).length,
        fields: {FinField.accountType: _type},
      );
    } else {
      await n.save(
        e.copyWith(title: _name.text.trim(), amount: cents).withFields({
          FinField.accountType: _type,
        }),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: Listenable.merge([_name, _opening]),
      builder: (context, _) => TrackerEditorScaffold(
        title: _e == null ? l10n.finNewAccount : l10n.finEditAccount,
        canSave: _valid,
        onSave: _save,
        scrollController: widget.scroll,
        children: [
          PrismTextField(
            controller: _name,
            labelText: l10n.finAccountName,
            autofocus: _e == null,
          ),
          TrackerLabel(l10n.finAccountType),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in accountTypes)
                PrismChip(
                  label: financeAccountTypeLabel(l10n, t),
                  selected: _type == t,
                  onTap: () => setState(() {
                    _type = t;
                    if (t == 'credit') _negative = true;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          MoneyField(
            controller: _opening,
            label: l10n.finOpeningBalance,
            allowZero: true,
          ),
          PrismSwitchRow(
            title: l10n.finOwed,
            subtitle: l10n.finOwedHelp,
            value: _negative,
            onChanged: (v) => setState(() => _negative = v),
          ),
          _deleteButton(context, ref, _e, l10n.finDeleteAccount),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Budget
// ---------------------------------------------------------------------------

Future<void> showBudgetEditor(BuildContext context, {TrackerRecord? editing}) =>
    _sheet(context, (s) => BudgetEditorSheet(editing: editing, scroll: s));

class BudgetEditorSheet extends ConsumerStatefulWidget {
  const BudgetEditorSheet({super.key, this.editing, this.scroll});

  final TrackerRecord? editing;
  final ScrollController? scroll;

  @override
  ConsumerState<BudgetEditorSheet> createState() => _BudgetEditorState();
}

class _BudgetEditorState extends ConsumerState<BudgetEditorSheet> {
  late final TrackerRecord? _e = widget.editing;
  late String? _category = _e?.title;
  late final _limit = TextEditingController(text: _centsText(_e?.amount));

  bool get _valid => _category != null && (MoneyField.read(_limit) ?? 0) > 0;

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final n = ref.read(trackerNotifierProvider.notifier);
    final e = _e;
    if (e == null) {
      await n.create(
        kind: TrackerKind.financeBudget,
        title: _category!,
        amount: MoneyField.read(_limit),
      );
    } else {
      await n.save(
        e.copyWith(title: _category!, amount: MoneyField.read(_limit)),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final taken = {
      for (final b in ref.watch(financeBudgetsProvider))
        if (b.id != _e?.id) b.title,
    };
    final used = {
      for (final t in ref.watch(financeTxnsProvider))
        if (txnType(t) == TxnType.expense) ?t.str(FinField.category),
    }.where((c) => !taken.contains(c)).toList();
    return ListenableBuilder(
      listenable: _limit,
      builder: (context, _) => TrackerEditorScaffold(
        title: _e == null ? l10n.finNewBudget : l10n.finEditBudget,
        canSave: _valid,
        onSave: _save,
        scrollController: widget.scroll,
        children: [
          TrackerLabel(l10n.finCategory),
          _categoryPicker(
            context,
            builtIn: [
              for (final c in expenseCategories)
                if (!taken.contains(c)) c,
            ],
            used: used,
            selected: _category,
            onSelected: (c) => setState(() => _category = c),
          ),
          const SizedBox(height: 12),
          MoneyField(controller: _limit, label: l10n.finMonthlyLimit),
          _deleteButton(context, ref, _e, l10n.finDeleteBudget),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Savings goal
// ---------------------------------------------------------------------------

Future<void> showGoalEditor(BuildContext context, {TrackerRecord? editing}) =>
    _sheet(context, (s) => GoalEditorSheet(editing: editing, scroll: s));

class GoalEditorSheet extends ConsumerStatefulWidget {
  const GoalEditorSheet({super.key, this.editing, this.scroll});

  final TrackerRecord? editing;
  final ScrollController? scroll;

  @override
  ConsumerState<GoalEditorSheet> createState() => _GoalEditorState();
}

class _GoalEditorState extends ConsumerState<GoalEditorSheet> {
  late final TrackerRecord? _e = widget.editing;
  late final _name = TextEditingController(text: _e?.title ?? '');
  late final _target = TextEditingController(text: _centsText(_e?.amount));
  late final _saved = TextEditingController(
    text: _centsText(_e?.integer(FinField.saved)),
  );
  late DateTime? _deadline = _e?.endedAt;
  late int _color = _e?.integer(FinField.color) ?? trackerPalette[2];

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      (MoneyField.read(_target) ?? 0) > 0 &&
      (_saved.text.trim().isEmpty || MoneyField.read(_saved) != null);

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _saved.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final n = ref.read(trackerNotifierProvider.notifier);
    final fields = {
      FinField.saved: MoneyField.read(_saved) ?? 0,
      FinField.color: _color,
    };
    final e = _e;
    if (e == null) {
      await n.create(
        kind: TrackerKind.financeGoal,
        title: _name.text,
        amount: MoneyField.read(_target),
        endedAt: _deadline,
        fields: fields,
      );
    } else {
      await n.save(
        e
            .copyWith(
              title: _name.text.trim(),
              amount: MoneyField.read(_target),
              endedAt: _deadline,
            )
            .withFields(fields),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: Listenable.merge([_name, _target, _saved]),
      builder: (context, _) => TrackerEditorScaffold(
        title: _e == null ? l10n.finNewGoal : l10n.finEditGoal,
        canSave: _valid,
        onSave: _save,
        scrollController: widget.scroll,
        children: [
          PrismTextField(
            controller: _name,
            labelText: l10n.finGoalName,
            autofocus: _e == null,
          ),
          const SizedBox(height: 12),
          MoneyField(controller: _target, label: l10n.finGoalTarget),
          const SizedBox(height: 12),
          MoneyField(
            controller: _saved,
            label: l10n.finGoalSaved,
            allowZero: true,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Text(l10n.finGoalDeadline)),
              PrismButton(
                label: _deadline == null
                    ? l10n.finNoDeadline
                    : DateFormat.yMMMd(context.dateLocale).format(_deadline!),
                density: PrismControlDensity.compact,
                onPressed: () async {
                  final d = await showPrismDatePicker(
                    context: context,
                    initialDate:
                        _deadline ??
                        DateTime.now().add(const Duration(days: 180)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) setState(() => _deadline = d);
                },
              ),
              if (_deadline != null)
                IconButton(
                  tooltip: l10n.finNoDeadline,
                  icon: Icon(AppIcons.close, size: 18),
                  onPressed: () => setState(() => _deadline = null),
                ),
            ],
          ),
          TrackerLabel(l10n.finColor),
          Wrap(
            spacing: 8,
            children: [
              for (final c in trackerPalette)
                InkResponse(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: Border.all(
                        width: _color == c ? 3 : 0,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          _deleteButton(context, ref, _e, l10n.finDeleteGoal),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recurring
// ---------------------------------------------------------------------------

Future<void> showRecurringEditor(
  BuildContext context, {
  TrackerRecord? editing,
}) => _sheet(context, (s) => RecurringEditorSheet(editing: editing, scroll: s));

class RecurringEditorSheet extends ConsumerStatefulWidget {
  const RecurringEditorSheet({super.key, this.editing, this.scroll});

  final TrackerRecord? editing;
  final ScrollController? scroll;

  @override
  ConsumerState<RecurringEditorSheet> createState() => _RecurringEditorState();
}

class _RecurringEditorState extends ConsumerState<RecurringEditorSheet> {
  late final TrackerRecord? _e = widget.editing;
  late String _type = _e?.str(FinField.type) ?? TxnType.expense;
  late final _title = TextEditingController(text: _e?.title ?? '');
  late final _amount = TextEditingController(text: _centsText(_e?.amount));
  late String? _category = _e?.str(FinField.category);
  late String? _account = _e?.str(FinField.account);
  late String _interval = _e?.str(FinField.interval) ?? RecurInterval.monthly;
  late DateTime _next = _e?.occurredAt ?? DateTime.now();
  late bool _auto = _e?.flag(FinField.autoAdd) ?? false;

  bool get _valid =>
      _title.text.trim().isNotEmpty && (MoneyField.read(_amount) ?? 0) > 0;

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final n = ref.read(trackerNotifierProvider.notifier);
    final fields = <String, Object?>{
      FinField.type: _type,
      FinField.category: _category ?? 'other',
      FinField.account: _account,
      FinField.interval: _interval,
      FinField.autoAdd: _auto ? true : null,
    };
    final e = _e;
    if (e == null) {
      await n.create(
        kind: TrackerKind.financeRecurring,
        title: _title.text,
        amount: MoneyField.read(_amount),
        occurredAt: _next,
        fields: fields,
      );
    } else {
      await n.save(
        e
            .copyWith(
              title: _title.text.trim(),
              amount: MoneyField.read(_amount),
              occurredAt: _next,
            )
            .withFields(fields),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: Listenable.merge([_title, _amount]),
      builder: (context, _) => TrackerEditorScaffold(
        title: _e == null ? l10n.finNewRecurring : l10n.finEditRecurring,
        canSave: _valid,
        onSave: _save,
        scrollController: widget.scroll,
        children: [
          PrismSegmentedControl<String>(
            segments: [
              PrismSegment(value: TxnType.expense, label: l10n.finExpense),
              PrismSegment(value: TxnType.income, label: l10n.finIncome),
            ],
            selected: _type,
            onChanged: (t) => setState(() {
              _type = t;
              _category = null;
            }),
          ),
          const SizedBox(height: 12),
          PrismTextField(
            controller: _title,
            labelText: l10n.finRecurringName,
            autofocus: _e == null,
          ),
          const SizedBox(height: 12),
          MoneyField(controller: _amount, label: l10n.finAmount),
          TrackerLabel(l10n.finRepeats),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final i in RecurInterval.all)
                PrismChip(
                  label: financeIntervalLabel(l10n, i),
                  selected: _interval == i,
                  onTap: () => setState(() => _interval = i),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Text(l10n.finNextDue)),
              PrismButton(
                label: DateFormat.yMMMd(context.dateLocale).format(_next),
                density: PrismControlDensity.compact,
                onPressed: () async {
                  final d = await showPrismDatePicker(
                    context: context,
                    initialDate: _next,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) setState(() => _next = d);
                },
              ),
            ],
          ),
          TrackerLabel(l10n.finCategory),
          _categoryPicker(
            context,
            builtIn: _type == TxnType.income
                ? incomeCategories
                : expenseCategories,
            used: const [],
            selected: _category,
            onSelected: (c) => setState(() => _category = c),
          ),
          TrackerLabel(l10n.finAccount),
          _accountPicker(
            context,
            ref.watch(financeAccountsProvider),
            _account,
            (a) => setState(() => _account = a),
          ),
          const SizedBox(height: 12),
          PrismSwitchRow(
            title: l10n.finAutoAdd,
            subtitle: l10n.finAutoAddHelp,
            value: _auto,
            onChanged: (v) => setState(() => _auto = v),
          ),
          _deleteButton(context, ref, _e, l10n.finDeleteRecurring),
        ],
      ),
    );
  }
}
