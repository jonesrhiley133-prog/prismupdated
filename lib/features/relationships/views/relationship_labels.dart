import 'package:prism_plurality/l10n/app_localizations.dart';

String relTypeLabel(AppLocalizations l10n, String t) => switch (t) {
  'friend' => l10n.relFriend,
  'best_friend' => l10n.relBestFriend,
  'partner' => l10n.relPartner,
  'crush' => l10n.relCrush,
  'family' => l10n.relFamily,
  'sibling' => l10n.relSibling,
  'parent_figure' => l10n.relParentFigure,
  'child_figure' => l10n.relChildFigure,
  'caretaker' => l10n.relCaretaker,
  'protector' => l10n.relProtector,
  'mentor' => l10n.relMentor,
  'classmate' => l10n.relClassmate,
  'coworker' => l10n.relCoworker,
  'rival' => l10n.relRival,
  'acquaintance' => l10n.relAcquaintance,
  _ => l10n.finCatOther,
};

String relStatusLabel(AppLocalizations l10n, String s) => switch (s) {
  'close' => l10n.relStatusClose,
  'distant' => l10n.relStatusDistant,
  'complicated' => l10n.relStatusComplicated,
  'ended' => l10n.relStatusEnded,
  _ => l10n.relStatusActive,
};
