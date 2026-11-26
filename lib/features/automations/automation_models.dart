import 'package:prism_plurality/shared/ui_kit.dart';

/// Trigger, condition and action type ids (stored; keep stable).
abstract final class AutoTrigger {
  static const frontStart = 'frontStart';
  static const frontEnd = 'frontEnd';
  static const alterActive = 'alterActive';
  static const mood = 'mood';
  static const journal = 'journal';
  static const dream = 'dream';
  static const eventSoon = 'eventSoon';
  static const hydrationMissing = 'hydrationMissing';
  static const time = 'time';
  static const condition = 'condition';
  static const all = [
    frontStart,
    frontEnd,
    alterActive,
    mood,
    journal,
    dream,
    eventSoon,
    hydrationMissing,
    time,
    condition,
  ];
}

abstract final class AutoCondition {
  static const alter = 'alter';
  static const timeOfDay = 'timeOfDay';
  static const weekday = 'weekday';
  static const fronting = 'fronting';
  static const mood = 'mood';
  static const location = 'location';
  static const metric = 'metric';
  static const all = [
    alter,
    timeOfDay,
    weekday,
    fronting,
    mood,
    location,
    metric,
  ];
}

abstract final class AutoAction {
  static const notify = 'notify';
  static const message = 'message';
  static const createEntry = 'createEntry';
  static const setStatus = 'setStatus';
  static const addEvent = 'addEvent';
  static const reminder = 'reminder';
  static const counter = 'counter';
  static const link = 'link';
  static const all = [
    notify,
    message,
    createEntry,
    setStatus,
    addEvent,
    reminder,
    counter,
    link,
  ];
}

/// Metrics usable in conditions and condition triggers.
const autoMetrics = [
  ('hydrationToday', 'Hydration today (ml)', 'Hidratación hoy (ml)'),
  ('mealsToday', 'Meals logged today', 'Comidas registradas hoy'),
  ('moodToday', 'Average mood today', 'Ánimo medio hoy'),
  ('switchesToday', 'Switches today', 'Cambios hoy'),
  ('journalToday', 'Journal entries today', 'Entradas del diario hoy'),
  ('dreamsWeek', 'Dreams this week', 'Sueños esta semana'),
];

/// A parsed rule.
class AutoRule {
  AutoRule(this.record);
  final TrackerRecord record;

  String get id => record.id;
  String get name => record.title;
  bool get enabled => record.flag('enabled');
  int get priority => record.integer('priority') ?? 0;
  int get cooldownMin => record.integer('cooldown') ?? 1;
  Map<String, Object?> get trigger => record.fields['trigger'] is Map
      ? (record.fields['trigger'] as Map).cast<String, Object?>()
      : const {'type': AutoTrigger.frontStart};
  String get triggerType =>
      trigger['type'] as String? ?? AutoTrigger.frontStart;
  List<Map<String, Object?>> get conditions => _list('conditions');
  List<Map<String, Object?>> get actions => _list('actions');
  DateTime? get lastRun => DateTime.tryParse(record.str('lastRun') ?? '');
  int get errorStreak => record.integer('errors') ?? 0;

  List<Map<String, Object?>> _list(String k) {
    final v = record.fields[k];
    return v is List
        ? [
            for (final x in v)
              if (x is Map) x.cast<String, Object?>(),
          ]
        : const [];
  }
}

/// What happened when a rule fired, for conditions and placeholders.
class AutoContext {
  AutoContext({
    required this.trigger,
    this.memberId,
    this.record,
    this.moodValue,
    this.title,
    DateTime? at,
  }) : at = at ?? DateTime.now();
  final String trigger;
  final String? memberId;

  /// `type:id` of the record that caused the trigger, if any.
  final String? record;
  final int? moodValue;
  final String? title;
  final DateTime at;
}

/// Ready-made rules users can start from.
List<(String, String, Map<String, Object?>)> automationTemplates(
  BuildContext context,
) => [
  (
    tr(
      context,
      'Welcome the new fronter',
      'Dar la bienvenida a quien llega al frente',
    ),
    tr(
      context,
      'Shows a hello and sets them Online if they have no status.',
      'Muestra un saludo y le pone En línea si no tiene estado.',
    ),
    {
      'trigger': {'type': AutoTrigger.frontStart},
      'actions': [
        {
          'type': AutoAction.message,
          'text': tr(
            context,
            'Welcome, {alter}! 💜',
            '¡Bienvenido/a, {alter}! 💜',
          ),
        },
        {
          'type': AutoAction.setStatus,
          'status': 'builtin:online',
          'target': 'trigger',
          'onlyIfNone': true,
        },
      ],
    },
  ),
  (
    tr(context, 'Gentle hydration nudge', 'Recordatorio suave de hidratación'),
    tr(
      context,
      'If nothing was drunk for 3 hours during the day, send a reminder.',
      'Si no se bebió nada en 3 horas durante el día, envía un aviso.',
    ),
    {
      'trigger': {'type': AutoTrigger.hydrationMissing, 'hours': 3},
      'conditions': [
        {'type': AutoCondition.timeOfDay, 'from': 9 * 60, 'to': 21 * 60},
      ],
      'actions': [
        {
          'type': AutoAction.notify,
          'title': tr(context, 'Water break?', '¿Un poco de agua?'),
          'text': tr(
            context,
            'Nothing logged for a while 💧',
            'Hace rato que no se registra nada 💧',
          ),
        },
      ],
      'cooldown': 180,
    },
  ),
  (
    tr(context, 'Support after a low mood', 'Apoyo tras un ánimo bajo'),
    tr(
      context,
      'When a mood of 2 or lower is logged, offer to journal.',
      'Cuando se registra un ánimo de 2 o menos, ofrece escribir.',
    ),
    {
      'trigger': {'type': AutoTrigger.mood},
      'conditions': [
        {'type': AutoCondition.mood, 'op': '<=', 'value': 2},
      ],
      'actions': [
        {
          'type': AutoAction.message,
          'text': tr(
            context,
            'That sounds hard. Writing it down in the journal might help. 🫂',
            'Suena difícil. Escribirlo en el diario podría ayudar. 🫂',
          ),
        },
      ],
    },
  ),
  (
    tr(
      context,
      'Link journal entries to the fronter',
      'Enlazar entradas al alter al frente',
    ),
    tr(
      context,
      'Connects each new journal entry with whoever is fronting.',
      'Conecta cada entrada nueva con quien está al frente.',
    ),
    {
      'trigger': {'type': AutoTrigger.journal},
      'actions': [
        {'type': AutoAction.link, 'target': 'fronter', 'cat': 'during'},
      ],
    },
  ),
  (
    tr(context, 'Dream tally', 'Contador de sueños'),
    tr(
      context,
      'Counts recorded dreams on a Home counter.',
      'Cuenta los sueños registrados en un contador de Inicio.',
    ),
    {
      'trigger': {'type': AutoTrigger.dream},
      'actions': [
        {
          'type': AutoAction.counter,
          'name': tr(context, 'Dreams recorded', 'Sueños registrados'),
          'by': 1,
        },
      ],
    },
  ),
  (
    tr(context, 'Event heads-up', 'Aviso de evento'),
    tr(
      context,
      '30 minutes before a calendar event, send a notification.',
      '30 minutos antes de un evento, envía una notificación.',
    ),
    {
      'trigger': {'type': AutoTrigger.eventSoon, 'minutes': 30},
      'actions': [
        {
          'type': AutoAction.notify,
          'title': '{title}',
          'text': tr(context, 'Starts in 30 minutes', 'Empieza en 30 minutos'),
        },
      ],
    },
  ),
  (
    tr(context, 'Evening check-in', 'Registro de la tarde'),
    tr(
      context,
      'Every evening at 21:00, ask how the day went.',
      'Cada tarde a las 21:00, pregunta qué tal el día.',
    ),
    {
      'trigger': {
        'type': AutoTrigger.time,
        'time': 21 * 60,
        'days': [1, 2, 3, 4, 5, 6, 7],
      },
      'actions': [
        {
          'type': AutoAction.notify,
          'title': tr(context, 'Evening check-in', 'Registro de la tarde'),
          'text': tr(
            context,
            'How did today go? A quick mood log helps.',
            '¿Qué tal hoy? Un registro rápido ayuda.',
          ),
        },
      ],
    },
  ),
  (
    tr(context, 'Away after fronting', 'Ausente tras estar al frente'),
    tr(
      context,
      'When someone stops fronting, set them Away for an hour.',
      'Cuando alguien deja el frente, ponle Ausente una hora.',
    ),
    {
      'trigger': {'type': AutoTrigger.frontEnd},
      'actions': [
        {
          'type': AutoAction.setStatus,
          'status': 'builtin:away',
          'target': 'trigger',
          'minutes': 60,
          'onlyIfNone': true,
        },
      ],
    },
  ),
];
