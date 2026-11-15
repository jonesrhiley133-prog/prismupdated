import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/features/social/models/social.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';

/// Feature categories shown in Settings › Features.
enum FeatureCategory { system, tracking, organization, social, knowledge, community, analytics }

/// What a feature stores, so it can be reset by date or cleared.
class FeatureData {
  const FeatureData({this.activityKinds = const [], this.permanentKinds = const [], this.sources = const [], this.note});

  /// Tracker record kinds that are dated activity (removed by period resets).
  final List<String> activityKinds;

  /// Tracker record kinds that are long-term (profiles, reference, config):
  /// only removed by "clear all", never by a date range.
  final List<String> permanentKinds;

  /// Dated records kept in their own tables (see reset sources).
  final List<String> sources;

  /// Explanation when a feature has nothing time-based to reset.
  final (String, String)? note;

  bool get hasActivity => activityKinds.isNotEmpty || sources.isNotEmpty;
  bool get hasAny => hasActivity || permanentKinds.isNotEmpty;
}

/// One Prism feature. Every feature must be listed in [prismFeatures]; the
/// Features settings page, navigation, route gates, background services and
/// data reset all read from this one registry.
class PrismFeature {
  const PrismFeature({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.icon,
    this.tabs = const [],
    this.route,
    this.defaultEnabled = true,
    this.core = false,
    this.essential = false,
    this.dependsOn = const [],
    this.legacyFlag,
    this.settingsRoute,
    this.permissions,
    this.data = const FeatureData(),
    this.background = const [],
  });

  final String id;
  final (String, String) name;
  final (String, String) description;
  final FeatureCategory category;
  final IconData icon;

  /// Navigation tabs owned by this feature (hidden when it is off).
  final List<AppShellTabId> tabs;

  /// Main route, for "Open" and for the route gate.
  final String? route;
  final bool defaultEnabled;

  /// Core features can't be turned off (Prism needs them).
  final bool core;

  /// Included in the default Minimal preset.
  final bool essential;

  /// Features this one needs.
  final List<String> dependsOn;

  /// Older on/off switch stored in system settings (kept for compatibility).
  final String? legacyFlag;

  /// Where this feature's own settings live, if anywhere.
  final String? settingsRoute;

  /// Device permissions the feature can ask for.
  final (String, String)? permissions;
  final FeatureData data;

  /// Background work that pauses while the feature is off (for display).
  final List<(String, String)> background;
}

const _notifications = ('Notifications', 'Notificaciones');

final List<PrismFeature> prismFeatures = [
  // ── System management ──
  PrismFeature(
    id: 'members',
    name: ('Alters & members', 'Alters y miembros'),
    description: ('Profiles, Profile Studio, custom fields and groups of your system’s members.', 'Perfiles, Profile Studio, campos propios y grupos de los miembros de tu sistema.'),
    category: FeatureCategory.system,
    icon: PhosphorIcons.users(),
    tabs: const [AppShellTabId.members],
    route: AppRoutePaths.members,
    core: true,
    essential: true,
    data: const FeatureData(permanentKinds: [TrackerKind.memberProfile, TrackerKind.profileTemplate], note: ('Alter profiles are long-term information and are never reset by date.', 'Los perfiles son información a largo plazo y nunca se restablecen por fecha.')),
  ),
  PrismFeature(
    id: 'fronting',
    name: ('Fronting', 'Frente'),
    description: ('Who is fronting, co-fronting, history and the fronting timeline.', 'Quién está al frente, co-frente, historial y cronología.'),
    category: FeatureCategory.system,
    icon: PhosphorIcons.userFocus(),
    tabs: const [AppShellTabId.timeline],
    route: AppRoutePaths.home,
    core: true,
    essential: true,
    settingsRoute: '/settings/features/fronting',
    data: const FeatureData(sources: ['fronting']),
  ),
  PrismFeature(
    id: 'groups',
    name: ('Member groups', 'Grupos de miembros'),
    description: ('Organise alters into groups.', 'Organiza a los alters en grupos.'),
    category: FeatureCategory.system,
    icon: PhosphorIcons.usersThree(),
    tabs: const [AppShellTabId.groups],
    route: AppRoutePaths.groups,
    dependsOn: const ['members'],
    data: const FeatureData(note: ('Groups are long-term information and aren’t reset by date.', 'Los grupos son información a largo plazo y no se restablecen por fecha.')),
  ),
  PrismFeature(
    id: 'subsystems',
    name: ('Subsystems', 'Subsistemas'),
    description: ('Small systems inside yours, with their own members, rules, journal and chat.', 'Pequeños sistemas dentro del tuyo, con miembros, normas, diario y chat propios.'),
    category: FeatureCategory.system,
    icon: PhosphorIcons.planet(),
    tabs: const [AppShellTabId.subsystems],
    route: AppRoutePaths.subsystems,
    dependsOn: const ['members'],
    background: const [('Fronting notifications for subsystems', 'Avisos de frente de subsistemas')],
    data: const FeatureData(
      activityKinds: [TrackerKind.subJournal, TrackerKind.subMessage, TrackerKind.subNote],
      permanentKinds: [TrackerKind.subsystem, TrackerKind.subMember, TrackerKind.subGroup, TrackerKind.subRule],
    ),
  ),
  PrismFeature(
    id: 'headspace',
    name: ('Headspace map', 'Mapa del headspace'),
    description: ('Map the inner world and its areas.', 'Mapea el mundo interior y sus zonas.'),
    category: FeatureCategory.system,
    icon: PhosphorIcons.mapTrifold(),
    tabs: const [AppShellTabId.headspace],
    route: AppRoutePaths.headspace,
    data: const FeatureData(permanentKinds: [TrackerKind.headspaceMap, TrackerKind.headspaceArea, TrackerKind.headspaceLink]),
  ),
  PrismFeature(
    id: 'statuses',
    name: ('Alter statuses', 'Estados de alters'),
    description: ('Short status messages and moods for each alter.', 'Mensajes de estado breves para cada alter.'),
    category: FeatureCategory.system,
    icon: PhosphorIcons.chatCircleText(),
    route: '/statuses',
    dependsOn: const ['members'],
    data: const FeatureData(activityKinds: [TrackerKind.statusLog], permanentKinds: [TrackerKind.statusCurrent, TrackerKind.statusCustom, TrackerKind.statusSettings]),
  ),
  PrismFeature(
    id: 'availability',
    name: ('Availability', 'Disponibilidad'),
    description: ('When alters are usually available, with optional reminders.', 'Cuándo suelen estar disponibles los alters, con avisos opcionales.'),
    category: FeatureCategory.system,
    icon: PhosphorIcons.calendarCheck(),
    tabs: const [AppShellTabId.availability],
    route: AppRoutePaths.availability,
    dependsOn: const ['members'],
    permissions: _notifications,
    background: const [('Availability reminders', 'Avisos de disponibilidad')],
    data: const FeatureData(activityKinds: [TrackerKind.availOverride], permanentKinds: [TrackerKind.availRule, TrackerKind.availCategory]),
  ),
  PrismFeature(
    id: 'introductions',
    name: ('Introduction cards', 'Tarjetas de presentación'),
    description: ('Shareable intro cards for alters.', 'Tarjetas de presentación compartibles para los alters.'),
    category: FeatureCategory.system,
    icon: PhosphorIcons.identificationCard(),
    tabs: const [AppShellTabId.introductions],
    route: AppRoutePaths.introductions,
    dependsOn: const ['members'],
    data: const FeatureData(permanentKinds: [TrackerKind.introCard, TrackerKind.introTemplate]),
  ),

  // ── Personal tracking ──
  PrismFeature(
    id: 'mood',
    name: ('Mood', 'Ánimo'),
    description: ('Log moods and emotions over time.', 'Registra ánimos y emociones a lo largo del tiempo.'),
    category: FeatureCategory.tracking,
    icon: PhosphorIcons.smiley(),
    tabs: const [AppShellTabId.mood],
    route: AppRoutePaths.mood,
    essential: true,
    data: const FeatureData(sources: ['mood']),
  ),
  PrismFeature(
    id: 'journal',
    name: ('Journal & dreams', 'Diario y sueños'),
    description: ('Journal entries and the dream journal.', 'Entradas de diario y diario de sueños.'),
    category: FeatureCategory.tracking,
    icon: PhosphorIcons.notebook(),
    tabs: const [AppShellTabId.journal],
    route: AppRoutePaths.journal,
    essential: true,
    data: const FeatureData(activityKinds: [TrackerKind.journalEntry, TrackerKind.dreamEntry], permanentKinds: [TrackerKind.journalCategory]),
  ),
  PrismFeature(
    id: 'sleep',
    name: ('Sleep', 'Sueño'),
    description: ('Sleep sessions, quality and the sleep log.', 'Sesiones de sueño, calidad y registro.'),
    category: FeatureCategory.tracking,
    icon: PhosphorIcons.moon(),
    tabs: const [AppShellTabId.sleep],
    route: AppRoutePaths.sleep,
    legacyFlag: 'sleep',
    settingsRoute: '/settings/features/sleep',
    data: const FeatureData(activityKinds: [TrackerKind.sleepLog], sources: ['sleepSessions']),
  ),
  PrismFeature(
    id: 'habits',
    name: ('Habits & routines', 'Hábitos y rutinas'),
    description: ('Habits with daily targets, routines, reminders and auto-logging.', 'Hábitos con metas diarias, rutinas, avisos y registro automático.'),
    category: FeatureCategory.tracking,
    icon: PhosphorIcons.checkSquareOffset(),
    tabs: const [AppShellTabId.habits],
    route: AppRoutePaths.habits,
    legacyFlag: 'habits',
    settingsRoute: '/settings/features/habits',
    permissions: _notifications,
    background: const [('Habit reminders and auto-logging', 'Avisos y registro automático de hábitos')],
    data: const FeatureData(activityKinds: [TrackerKind.habitLog, TrackerKind.habitSkip, TrackerKind.habitTimer], permanentKinds: [TrackerKind.habitMeta, TrackerKind.habitGroup], sources: ['habitCompletions']),
  ),
  PrismFeature(
    id: 'fitness',
    name: ('Fitness', 'Ejercicio'),
    description: ('Workouts, exercises and goals.', 'Entrenamientos, ejercicios y metas.'),
    category: FeatureCategory.tracking,
    icon: PhosphorIcons.barbell(),
    tabs: const [AppShellTabId.fitness],
    route: AppRoutePaths.fitness,
    data: const FeatureData(activityKinds: [TrackerKind.fitnessWorkout, TrackerKind.fitnessDaily], permanentKinds: [TrackerKind.fitnessGoal, TrackerKind.fitnessExercise]),
  ),
  PrismFeature(
    id: 'healthIntegration',
    name: ('Health app integration', 'Integración con apps de salud'),
    description: ('Import workouts, steps and more from Health Connect or Apple Health.', 'Importa entrenamientos, pasos y más desde Health Connect o Apple Health.'),
    category: FeatureCategory.tracking,
    icon: PhosphorIcons.heartbeat(),
    route: '/fitness/integrations',
    dependsOn: const ['fitness'],
    permissions: ('Health data (you choose which types)', 'Datos de salud (tú eliges cuáles)'),
    background: const [('Automatic health sync', 'Sincronización automática de salud')],
    data: const FeatureData(note: ('Imported workouts belong to Fitness — reset them from Fitness.', 'Los entrenamientos importados pertenecen a Ejercicio: restablécelos desde Ejercicio.')),
  ),
  PrismFeature(
    id: 'nutrition',
    name: ('Nourish', 'Nutrición'),
    description: ('Meals, drinks and hydration reminders.', 'Comidas, bebidas y avisos de hidratación.'),
    category: FeatureCategory.tracking,
    icon: PhosphorIcons.forkKnife(),
    tabs: const [AppShellTabId.nutrition],
    route: AppRoutePaths.nutrition,
    permissions: _notifications,
    background: const [('Hydration reminders', 'Avisos de hidratación')],
    data: const FeatureData(
      activityKinds: [TrackerKind.nutriMeal, TrackerKind.nutriDrink],
      permanentKinds: [TrackerKind.nutriFood, TrackerKind.nutriCollection, TrackerKind.nutriCategory, TrackerKind.nutriBeverage, TrackerKind.nutriSettings],
    ),
  ),
  PrismFeature(
    id: 'cycle',
    name: ('Cycle', 'Ciclo'),
    description: ('Menstrual cycle phases and wellness.', 'Fases del ciclo y bienestar.'),
    category: FeatureCategory.tracking,
    icon: PhosphorIcons.drop(),
    tabs: const [AppShellTabId.cycle],
    route: AppRoutePaths.cycle,
    data: const FeatureData(activityKinds: [TrackerKind.cyclePhase, TrackerKind.cycleWellness], sources: ['cycle']),
  ),
  PrismFeature(
    id: 'locations',
    name: ('Locations', 'Lugares'),
    description: ('Saved places and time spent there.', 'Lugares guardados y tiempo en ellos.'),
    category: FeatureCategory.tracking,
    icon: PhosphorIcons.mapPin(),
    tabs: const [AppShellTabId.locations],
    route: AppRoutePaths.locations,
    data: const FeatureData(sources: ['locations']),
  ),
  PrismFeature(
    id: 'work',
    name: ('Work', 'Trabajo'),
    description: ('Jobs, shifts and work sessions.', 'Trabajos, turnos y sesiones.'),
    category: FeatureCategory.tracking,
    icon: PhosphorIcons.briefcase(),
    tabs: const [AppShellTabId.work],
    route: AppRoutePaths.work,
    data: const FeatureData(sources: ['work']),
  ),
  PrismFeature(
    id: 'finance',
    name: ('Finance', 'Finanzas'),
    description: ('Transactions, accounts, budgets and savings goals.', 'Movimientos, cuentas, presupuestos y metas de ahorro.'),
    category: FeatureCategory.tracking,
    icon: PhosphorIcons.wallet(),
    tabs: const [AppShellTabId.finance],
    route: AppRoutePaths.finance,
    data: const FeatureData(activityKinds: [TrackerKind.financeTxn], permanentKinds: [TrackerKind.financeAccount, TrackerKind.financeBudget, TrackerKind.financeGoal, TrackerKind.financeRecurring]),
  ),

  // ── Organisation ──
  PrismFeature(
    id: 'calendar',
    name: ('Calendar', 'Calendario'),
    description: ('Events with overlays from your other features.', 'Eventos con capas de tus otras funciones.'),
    category: FeatureCategory.organization,
    icon: PhosphorIcons.calendar(),
    tabs: const [AppShellTabId.calendar],
    route: AppRoutePaths.calendar,
    essential: true,
    permissions: _notifications,
    data: const FeatureData(sources: ['calendar']),
  ),
  PrismFeature(
    id: 'reminders',
    name: ('Reminders', 'Recordatorios'),
    description: ('Scheduled and recurring reminders.', 'Recordatorios programados y recurrentes.'),
    category: FeatureCategory.organization,
    icon: PhosphorIcons.bell(),
    tabs: const [AppShellTabId.reminders],
    route: AppRoutePaths.reminders,
    essential: true,
    legacyFlag: 'reminders',
    settingsRoute: '/settings/features/reminders',
    permissions: _notifications,
    data: const FeatureData(sources: ['reminders']),
  ),
  PrismFeature(
    id: 'notes',
    name: ('Notes', 'Notas'),
    description: ('Notes about and from alters.', 'Notas sobre y de los alters.'),
    category: FeatureCategory.organization,
    icon: PhosphorIcons.note(),
    tabs: const [AppShellTabId.notes],
    route: AppRoutePaths.notes,
    essential: true,
    legacyFlag: 'notes',
    settingsRoute: '/settings/features/notes',
    data: const FeatureData(sources: ['notes']),
  ),
  PrismFeature(
    id: 'school',
    name: ('School', 'Estudios'),
    description: ('Academic terms, classes, assignments, grades and study sessions.', 'Periodos, clases, tareas, notas y sesiones de estudio.'),
    category: FeatureCategory.organization,
    icon: PhosphorIcons.graduationCap(),
    tabs: const [AppShellTabId.school],
    route: AppRoutePaths.school,
    data: const FeatureData(activityKinds: [TrackerKind.schoolAssignment, TrackerKind.schoolGrade, TrackerKind.schoolStudy], permanentKinds: [TrackerKind.schoolTerm, TrackerKind.schoolClass]),
  ),
  PrismFeature(
    id: 'automations',
    name: ('Automations', 'Automatizaciones'),
    description: ('“When this happens, do that” rules.', 'Reglas de «cuando pase esto, haz aquello».'),
    category: FeatureCategory.organization,
    icon: PhosphorIcons.lightning(),
    route: '/automations',
    permissions: _notifications,
    background: const [('Automation rules', 'Reglas de automatización')],
    data: const FeatureData(activityKinds: [TrackerKind.autoLog, TrackerKind.autoCounter], permanentKinds: [TrackerKind.autoRule]),
  ),

  // ── Social & relationships ──
  PrismFeature(
    id: 'relationships',
    name: ('Relationships', 'Relaciones'),
    description: ('Relationship map, profiles, family tree, timeline, check-ins and the randomizer.', 'Mapa de relaciones, perfiles, árbol familiar, cronología, registros y aleatorizador.'),
    category: FeatureCategory.social,
    icon: PhosphorIcons.heart(),
    tabs: const [AppShellTabId.relationships],
    route: AppRoutePaths.relationships,
    dependsOn: const ['members'],
    data: const FeatureData(
      activityKinds: [TrackerKind.relationshipEvent, TrackerKind.relationshipNote, TrackerKind.relationshipCheckin],
      permanentKinds: [TrackerKind.relationship, TrackerKind.relationshipFamilyNote, TrackerKind.relationshipSettings],
    ),
  ),
  PrismFeature(
    id: 'chat',
    name: ('Chat', 'Chat'),
    description: ('Conversations between alters.', 'Conversaciones entre alters.'),
    category: FeatureCategory.social,
    icon: PhosphorIcons.chatsCircle(),
    tabs: const [AppShellTabId.chat],
    route: AppRoutePaths.chat,
    legacyFlag: 'chat',
    settingsRoute: '/settings/features/chat',
    data: const FeatureData(sources: ['chat']),
  ),
  PrismFeature(
    id: 'boards',
    name: ('Bulletin boards', 'Tablones'),
    description: ('Message boards for each alter.', 'Tablones de mensajes para cada alter.'),
    category: FeatureCategory.social,
    icon: PhosphorIcons.pushPin(),
    tabs: const [AppShellTabId.boards],
    route: AppRoutePaths.boards,
    defaultEnabled: false,
    legacyFlag: 'boards',
    settingsRoute: '/settings/features/boards',
    data: const FeatureData(note: ('Board posts are kept as long-term messages.', 'Las publicaciones del tablón se guardan como mensajes a largo plazo.')),
  ),
  PrismFeature(
    id: 'stories',
    name: ('Feed & stories', 'Muro e historias'),
    description: ('Posts, comments and stories inside your system.', 'Publicaciones, comentarios e historias dentro de tu sistema.'),
    category: FeatureCategory.social,
    icon: PhosphorIcons.newspaper(),
    tabs: const [AppShellTabId.stories],
    route: AppRoutePaths.stories,
    data: const FeatureData(
      activityKinds: [SocialKind.post, SocialKind.comment, SocialKind.reaction, SocialKind.vote, SocialKind.seen, SocialKind.story, SocialKind.storyView],
      permanentKinds: [SocialKind.profile, SocialKind.follow, SocialKind.block, SocialKind.hide, SocialKind.report, SocialKind.highlight],
    ),
  ),
  PrismFeature(
    id: 'contacts',
    name: ('Contacts', 'Contactos'),
    description: ('People outside the system.', 'Personas fuera del sistema.'),
    category: FeatureCategory.social,
    icon: PhosphorIcons.addressBook(),
    tabs: const [AppShellTabId.contacts],
    route: AppRoutePaths.contacts,
    data: const FeatureData(note: ('Contacts are long-term information and aren’t reset by date.', 'Los contactos son información a largo plazo y no se restablecen por fecha.')),
  ),
  PrismFeature(
    id: 'connections',
    name: ('Connection maps', 'Mapas de conexiones'),
    description: ('Draw internal connections between alters, places and ideas.', 'Dibuja conexiones internas entre alters, lugares e ideas.'),
    category: FeatureCategory.social,
    icon: PhosphorIcons.graph(),
    tabs: const [AppShellTabId.connections],
    route: AppRoutePaths.connections,
    data: const FeatureData(permanentKinds: [TrackerKind.connMap, TrackerKind.connNode, TrackerKind.connEdge]),
  ),

  // ── Knowledge & documentation ──
  PrismFeature(
    id: 'dictionary',
    name: ('Dictionary', 'Diccionario'),
    description: ('Your own terms, collections and the wiki importer.', 'Tus propios términos, colecciones e importador de wikis.'),
    category: FeatureCategory.knowledge,
    icon: PhosphorIcons.bookOpenText(),
    tabs: const [AppShellTabId.dictionary],
    route: AppRoutePaths.dictionary,
    data: const FeatureData(permanentKinds: [TrackerKind.dictTerm, TrackerKind.dictCollection]),
  ),
  PrismFeature(
    id: 'scrapbook',
    name: ('Scrapbook', 'Álbum'),
    description: ('Scrapbooks with pages, photos and stickers.', 'Álbumes con páginas, fotos y pegatinas.'),
    category: FeatureCategory.knowledge,
    icon: PhosphorIcons.images(),
    tabs: const [AppShellTabId.scrapbook],
    route: AppRoutePaths.scrapbook,
    data: const FeatureData(activityKinds: [TrackerKind.scrapPage], permanentKinds: [TrackerKind.scrapBook, TrackerKind.scrapTemplate]),
  ),
  PrismFeature(
    id: 'links',
    name: ('Record links', 'Enlaces entre registros'),
    description: ('Connect any records to each other and explore them.', 'Conecta registros entre sí y explóralos.'),
    category: FeatureCategory.knowledge,
    icon: PhosphorIcons.linkSimple(),
    route: '/links',
    data: const FeatureData(permanentKinds: [TrackerKind.linkEdge, TrackerKind.linkCategory]),
  ),
  PrismFeature(
    id: 'media',
    name: ('Media library', 'Biblioteca multimedia'),
    description: ('Photos and files attached across Prism.', 'Fotos y archivos adjuntos en Prism.'),
    category: FeatureCategory.knowledge,
    icon: PhosphorIcons.folderSimple(),
    tabs: const [AppShellTabId.media],
    route: AppRoutePaths.media,
    data: const FeatureData(note: ('Media belongs to the records it’s attached to; reset those features instead.', 'Los archivos pertenecen a sus registros; restablece esas funciones.')),
  ),
  PrismFeature(
    id: 'music',
    name: ('Music', 'Música'),
    description: ('Playlists and listening for alters.', 'Listas y música para los alters.'),
    category: FeatureCategory.knowledge,
    icon: PhosphorIcons.musicNotes(),
    tabs: const [AppShellTabId.music],
    route: AppRoutePaths.music,
    data: const FeatureData(note: ('Music has no dated records to reset.', 'La música no tiene registros con fecha.')),
  ),

  // ── Community & interaction ──
  PrismFeature(
    id: 'polls',
    name: ('Polls', 'Encuestas'),
    description: ('Polls for system decisions.', 'Encuestas para decisiones del sistema.'),
    category: FeatureCategory.community,
    icon: PhosphorIcons.chartBar(),
    tabs: const [AppShellTabId.polls],
    route: AppRoutePaths.polls,
    legacyFlag: 'polls',
    settingsRoute: '/settings/features/polls',
    data: const FeatureData(sources: ['polls']),
  ),
  PrismFeature(
    id: 'achievements',
    name: ('Achievements', 'Logros'),
    description: ('Milestones unlocked as you use Prism.', 'Hitos que desbloqueas al usar Prism.'),
    category: FeatureCategory.community,
    icon: PhosphorIcons.trophy(),
    tabs: const [AppShellTabId.achievements],
    route: AppRoutePaths.achievements,
    data: const FeatureData(activityKinds: [TrackerKind.achievementUnlock]),
  ),

  // ── Analytics & insights ──
  PrismFeature(
    id: 'statistics',
    name: ('Statistics', 'Estadísticas'),
    description: ('Fronting and usage statistics.', 'Estadísticas de frente y de uso.'),
    category: FeatureCategory.analytics,
    icon: PhosphorIcons.chartLine(),
    tabs: const [AppShellTabId.statistics],
    route: AppRoutePaths.statistics,
    data: const FeatureData(note: ('Statistics are calculated from other features and store nothing themselves.', 'Las estadísticas se calculan desde otras funciones y no guardan nada.')),
  ),
  PrismFeature(
    id: 'insights',
    name: ('Daily insights', 'Perspectivas diarias'),
    description: ('A daily summary built from your records.', 'Un resumen diario a partir de tus registros.'),
    category: FeatureCategory.analytics,
    icon: PhosphorIcons.lightbulb(),
    tabs: const [AppShellTabId.insights],
    route: AppRoutePaths.insights,
    data: const FeatureData(note: ('Insights are calculated and store nothing themselves.', 'Las perspectivas se calculan y no guardan nada.')),
  ),
  PrismFeature(
    id: 'analytics',
    name: ('Analytics', 'Análisis'),
    description: ('Co-fronting patterns and mood correlations.', 'Patrones de co-frente y correlaciones de ánimo.'),
    category: FeatureCategory.analytics,
    icon: PhosphorIcons.chartPieSlice(),
    tabs: const [AppShellTabId.analytics],
    route: AppRoutePaths.analytics,
    dependsOn: const ['mood'],
    data: const FeatureData(note: ('Analytics are calculated and store nothing themselves.', 'Los análisis se calculan y no guardan nada.')),
  ),
];

final Map<String, PrismFeature> prismFeatureIndex = {for (final f in prismFeatures) f.id: f};

/// Feature owning a navigation tab (if any).
final Map<AppShellTabId, PrismFeature> featureByTab = {
  for (final f in prismFeatures)
    for (final t in f.tabs) t: f,
};

String featureCategoryName(FeatureCategory c) => switch (c) {
  FeatureCategory.system => 'System management',
  FeatureCategory.tracking => 'Personal tracking',
  FeatureCategory.organization => 'Organisation',
  FeatureCategory.social => 'Social & relationships',
  FeatureCategory.knowledge => 'Knowledge & documentation',
  FeatureCategory.community => 'Community & interaction',
  FeatureCategory.analytics => 'Analytics & insights',
};

String featureCategoryNameEs(FeatureCategory c) => switch (c) {
  FeatureCategory.system => 'Gestión del sistema',
  FeatureCategory.tracking => 'Seguimiento personal',
  FeatureCategory.organization => 'Organización',
  FeatureCategory.social => 'Social y relaciones',
  FeatureCategory.knowledge => 'Conocimiento y documentación',
  FeatureCategory.community => 'Comunidad e interacción',
  FeatureCategory.analytics => 'Análisis y perspectivas',
};

/// Features that need [id] (to warn before turning it off).
List<PrismFeature> dependentsOf(String id) => [for (final f in prismFeatures) if (f.dependsOn.contains(id)) f];
