import 'package:flutter/material.dart';

import 'package:prism_plurality/features/finance/utils/finance.dart';
import 'package:prism_plurality/l10n/app_localizations.dart';

/// Built-in category keys are translated; custom ones show as typed.
String financeCategoryLabel(AppLocalizations l10n, String key) => switch (key) {
  'housing' => l10n.finCatHousing,
  'groceries' => l10n.finCatGroceries,
  'dining' => l10n.finCatDining,
  'transport' => l10n.finCatTransport,
  'utilities' => l10n.finCatUtilities,
  'health' => l10n.finCatHealth,
  'personal' => l10n.finCatPersonal,
  'entertainment' => l10n.finCatEntertainment,
  'shopping' => l10n.finCatShopping,
  'education' => l10n.finCatEducation,
  'subscriptions' => l10n.finCatSubscriptions,
  'gifts' => l10n.finCatGifts,
  'pets' => l10n.finCatPets,
  'travel' => l10n.finCatTravel,
  'debt' => l10n.finCatDebt,
  'salary' => l10n.finCatSalary,
  'freelance' => l10n.finCatFreelance,
  'benefits' => l10n.finCatBenefits,
  'refunds' => l10n.finCatRefunds,
  'interest' => l10n.finCatInterest,
  'other' => l10n.finCatOther,
  _ => key,
};

String financeAccountTypeLabel(AppLocalizations l10n, String key) =>
    switch (key) {
      'cash' => l10n.finAccCash,
      'checking' => l10n.finAccChecking,
      'savings' => l10n.finAccSavings,
      'credit' => l10n.finAccCredit,
      'investment' => l10n.finAccInvestment,
      _ => key,
    };

String financeIntervalLabel(AppLocalizations l10n, String key) => switch (key) {
  RecurInterval.weekly => l10n.finEveryWeek,
  RecurInterval.biweekly => l10n.finEveryTwoWeeks,
  RecurInterval.quarterly => l10n.finEveryQuarter,
  RecurInterval.yearly => l10n.finEveryYear,
  _ => l10n.finEveryMonth,
};

String financeTypeLabel(AppLocalizations l10n, String type) => switch (type) {
  TxnType.income => l10n.finIncome,
  TxnType.transfer => l10n.finTransfer,
  _ => l10n.finExpense,
};

Color financeTypeColor(ThemeData theme, String type) => switch (type) {
  TxnType.income => const Color(0xFF2E9E5B),
  TxnType.transfer => theme.colorScheme.onSurfaceVariant,
  _ => theme.colorScheme.error,
};

/// Stable colour per category for charts.
Color financeCategoryColor(String key) {
  const palette = [
    Color(0xFF7E57C2),
    Color(0xFF42A5F5),
    Color(0xFF26A69A),
    Color(0xFF66BB6A),
    Color(0xFFFFCA28),
    Color(0xFFFFA726),
    Color(0xFFEF5350),
    Color(0xFFEC407A),
    Color(0xFF8D6E63),
    Color(0xFF78909C),
  ];
  final i = [...expenseCategories, ...incomeCategories].indexOf(key);
  return palette[(i >= 0 ? i : key.hashCode.abs()) % palette.length];
}
