/// Record kinds stored in `tracker_records`. The prefix before the dot is
/// the section; keep these stable, they are synced and exported.
abstract final class TrackerKind {
  static const journalEntry = 'journal.entry';
  static const journalCategory = 'journal.category';

  static const dictTerm = 'dict.term';
  static const dictCollection = 'dict.collection';

  static const achievementUnlock = 'achieve.unlock';

  static const fitnessWorkout = 'fitness.workout';
  static const fitnessGoal = 'fitness.goal';
  static const fitnessExercise = 'fitness.exercise';

  static const financeTxn = 'finance.txn';
  static const financeAccount = 'finance.account';
  static const financeBudget = 'finance.budget';
  static const financeGoal = 'finance.goal';
  static const financeRecurring = 'finance.recurring';

  static const schoolTerm = 'school.term';
  static const schoolClass = 'school.class';
  static const schoolAssignment = 'school.assignment';
  static const schoolGrade = 'school.grade';
  static const schoolStudy = 'school.study';

  static const relationship = 'rel.person';
  static const relationshipEvent = 'rel.event';

  static const headspaceMap = 'headspace.map';
  static const headspaceArea = 'headspace.area';
  static const headspaceLink = 'headspace.link';

  static const subsystem = 'subsystem';

  static const sleepLog = 'sleep.log';
  static const cyclePhase = 'cycle.phase';
  static const cycleWellness = 'cycle.wellness';

  /// The section part of [kind] (`journal.entry` → `journal`).
  static String section(String kind) {
    final i = kind.indexOf('.');
    return i < 0 ? kind : kind.substring(0, i);
  }
}
