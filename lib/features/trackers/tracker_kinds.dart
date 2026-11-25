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

  /// Daily totals imported from health apps (steps, distance, energy…).
  static const fitnessDaily = 'fitness.daily';
  static const fitnessSource = 'fitness.source';

  /// Prism-wide: feature switches, reset log and wiki import history.
  static const appFeatures = 'app.features';
  static const appResetLog = 'app.resetLog';
  static const dictImport = 'dict.import';

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

  // Health: check-ins (with their symptoms), Body Map spots, follow-ups,
  // illness episodes and custom vocabulary. Private by default.
  static const healthCheckin = 'health.checkin';
  static const healthSpot = 'health.spot';
  static const healthFollowup = 'health.followup';
  static const healthEpisode = 'health.episode';
  static const healthVocab = 'health.vocab';

  // Astro: per-alter birth details and privacy (one profile each), the
  // astrology journal, saved tarot readings, and system-wide settings.
  static const astroProfile = 'astro.profile';
  static const astroJournal = 'astro.journal';
  static const astroTarot = 'astro.tarot';
  static const astroSettings = 'astro.settings';

  // Games: results, saved progress, per-alter game profiles (favourites,
  // privacy), challenges left for other alters, game nights, custom games
  // and shared creative projects (stories, poems, worlds, drawings).
  static const gameResult = 'games.result';
  static const gameSave = 'games.save';
  static const gameProfile = 'games.profile';
  static const gameChallenge = 'games.challenge';
  static const gameNight = 'games.night';
  static const gameCustom = 'games.custom';
  static const gameProject = 'games.project';

  // Cozy: lounge posts and settings, rooms and their items, letters,
  // garden plants, shared lists (wishlists, jars, capsules, shelves…),
  // gifts, doodle-wall strokes and comfort kits.
  static const cozyPost = 'cozy.post';
  static const cozySettings = 'cozy.settings';
  static const cozyRoom = 'cozy.room';
  static const cozyRoomItem = 'cozy.roomItem';
  static const cozyLetter = 'cozy.letter';
  static const cozyPlant = 'cozy.plant';
  static const cozyListItem = 'cozy.listItem';
  static const cozyGift = 'cozy.gift';
  static const cozyDoodle = 'cozy.doodle';
  static const cozyComfort = 'cozy.comfort';

  // Fronting roles: custom fronting statuses (Primary / Co-front /
  // Co-conscious are built in), each alter's assigned status, and
  // Who's There settings (interval, last confirmation, snooze).
  static const frontStatusType = 'front.statusType';
  static const frontRole = 'front.role';
  static const frontRoleSettings = 'front.roleSettings';
  static const notifySettings = 'notify.settings';

  // Virtual Companions
  static const companion = 'comp.companion';
  static const companionOutfit = 'comp.outfit';
  static const companionHabitat = 'comp.habitat';
  static const companionInteraction = 'comp.interaction';
  static const companionMemory = 'comp.memory';
  static const companionSpecies = 'comp.species';
  static const companionSettings = 'comp.settings';

  // Prism Passport
  static const passport = 'pass.passport';
  static const passportPage = 'pass.page';
  static const passportElement = 'pass.element';
  static const passportStamp = 'pass.stamp';
  static const passportStampTemplate = 'pass.template';
  static const passportSettings = 'pass.settings';

  // Prism Wrapped
  static const wrapSnapshot = 'wrap.snapshot';
  static const wrapSettings = 'wrap.settings';

  // Personality & dialogue.
  static const voiceSettings = 'voice.settings';
  static const voiceTrack = 'voice.track';

  // Wallets & ID cards.
  static const wallet = 'wallet.wallet';
  static const walletCard = 'wallet.card';
  static const walletIdentity = 'wallet.identity';

  /// The section part of [kind] (`journal.entry` → `journal`).
  static String section(String kind) {
    final i = kind.indexOf('.');
    return i < 0 ? kind : kind.substring(0, i);
  }
}
