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
  static const relationshipNote = 'rel.note';
  static const relationshipCheckin = 'rel.checkin';
  static const relationshipSettings = 'rel.settings';
  static const relationshipFamilyNote = 'rel.familyNote';

  static const headspaceMap = 'headspace.map';
  static const headspaceArea = 'headspace.area';
  static const headspaceLink = 'headspace.link';

  static const subsystem = 'subsystem';

  /// Subsystem extensions: membership per alter (parent = subsystem),
  /// internal groups, rules, notes, journal and messages.
  static const subMember = 'subsystem.member';
  static const subGroup = 'subsystem.group';
  static const subRule = 'subsystem.rule';
  static const subNote = 'subsystem.note';
  static const subJournal = 'subsystem.journal';
  static const subMessage = 'subsystem.message';

  /// Extended alter profile (parent = member id) and saved templates.
  static const memberProfile = 'member.profile';
  static const profileTemplate = 'member.profileTemplate';

  static const sleepLog = 'sleep.log';
  static const cyclePhase = 'cycle.phase';
  static const cycleWellness = 'cycle.wellness';

  // Advanced expansion (0.24)
  static const linkEdge = 'link.edge';
  static const linkCategory = 'link.category';

  static const scrapBook = 'scrap.book';
  static const scrapPage = 'scrap.page';
  static const scrapTemplate = 'scrap.template';

  static const connMap = 'conn.map';
  static const connNode = 'conn.node';
  static const connEdge = 'conn.edge';

  static const nutriMeal = 'nutri.meal';
  static const nutriDrink = 'nutri.drink';
  static const nutriFood = 'nutri.food';
  static const nutriCollection = 'nutri.collection';
  static const nutriCategory = 'nutri.category';
  static const nutriBeverage = 'nutri.beverage';
  static const nutriSettings = 'nutri.settings';

  static const statusCurrent = 'status.current';
  static const statusLog = 'status.log';
  static const statusCustom = 'status.custom';
  static const statusSettings = 'status.settings';

  static const availRule = 'avail.rule';
  static const availOverride = 'avail.override';
  static const availCategory = 'avail.category';

  static const introCard = 'intro.card';
  static const introTemplate = 'intro.template';

  static const autoRule = 'auto.rule';
  static const autoLog = 'auto.log';
  static const autoCounter = 'auto.counter';

  static const dreamEntry = 'dream.entry';

  // Habit & Routine Center: extensions of the synced habits/completions.
  static const habitMeta = 'habit.meta';
  static const habitLog = 'habit.log';
  static const habitSkip = 'habit.skip';
  static const habitGroup = 'habit.group';
  static const habitTimer = 'habit.timer';

  /// The section part of [kind] (`journal.entry` → `journal`).
  static String section(String kind) {
    final i = kind.indexOf('.');
    return i < 0 ? kind : kind.substring(0, i);
  }
}
