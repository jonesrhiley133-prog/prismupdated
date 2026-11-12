import 'package:flutter/foundation.dart';

/// Text in each supported language; falls back to English.
@immutable
class LocalizedText {
  const LocalizedText(this.en, [this.es]);

  final String en;
  final String? es;

  String of(String languageCode) => languageCode == 'es' ? (es ?? en) : en;
}

@immutable
class ChangelogRelease {
  const ChangelogRelease({
    required this.version,
    required this.date,
    this.features = const [],
    this.improvements = const [],
    this.fixes = const [],
  });

  /// Matches `version:` in pubspec.yaml (without the build number).
  final String version;
  final DateTime date;
  final List<LocalizedText> features;
  final List<LocalizedText> improvements;
  final List<LocalizedText> fixes;
}

/// Newest first. Add an entry (and bump pubspec.yaml) with every release.
final List<ChangelogRelease> prismChangelog = [
  ChangelogRelease(
    version: '0.21.0',
    date: DateTime(2026, 11, 12),
    features: const [
      LocalizedText(
        'Home screen widgets (Android, tuned for Samsung One UI): 20 '
            'widgets across fronting, wellness, productivity and system '
            'tools, each in small, medium and large sizes that switch as '
            'you resize. Settings → Home screen widgets.',
        'Widgets de inicio (Android, pensados para Samsung One UI): 20 '
            'widgets de frente, bienestar, productividad y sistema, cada '
            'uno en tamaño pequeño, mediano y grande. Ajustes → Widgets '
            'de inicio.',
      ),
      LocalizedText(
        'Widget Customization Studio with live preview: themes (light, '
            'dark, AMOLED), colours and gradients, glass transparency, '
            'corners, borders, fonts, text size, avatar shapes, background '
            'images with blur, compact or detailed layouts, and saved '
            'configurations. Add the same widget several times, each with '
            'its own look.',
        'Estudio de personalización con vista previa en vivo: temas '
            '(claro, oscuro, AMOLED), colores y degradados, transparencia, '
            'esquinas, bordes, fuentes, tamaño de texto, forma de avatar, '
            'imágenes de fondo con desenfoque, diseño compacto o detallado '
            'y configuraciones guardadas.',
      ),
      LocalizedText(
        'Quick actions from the home screen: switch fronters, log a mood, '
            'check in to a place, start or end sleep and tick off tasks '
            'without opening Prism.',
        'Acciones rápidas desde la pantalla de inicio: cambiar el frente, '
            'registrar ánimo, registrarte en un lugar, dormir o despertar y '
            'marcar tareas sin abrir Prism.',
      ),
      LocalizedText(
        'New To-do list with per-member tasks and due dates.',
        'Nueva lista de tareas con tareas por miembro y fechas límite.',
      ),
    ],
    improvements: const [
      LocalizedText(
        'Widgets are private by default: journal and note text, finances, '
            'symptoms and private entries stay hidden until you turn them '
            'on for a specific widget. You can also show initials instead '
            'of names and mask amounts.',
        'Los widgets son privados por defecto: el texto del diario y las '
            'notas, las finanzas, los síntomas y las entradas privadas '
            'permanecen ocultos hasta que los actives en un widget concreto.',
      ),
    ],
  ),
  ChangelogRelease(
    version: '0.20.0',
    date: DateTime(2026, 11, 12),
    features: const [
      LocalizedText(
        'Fronting notification (Android): a live notification showing who '
            'is fronting, co-fronters, a running timer, mood, location, '
            'activity and your own status, updated the moment the front '
            'changes. Customise the title, greeting, icon, colours, layout, '
            'buttons (switch, quick front, mood, status, details), lock '
            'screen privacy and per-member styles. Settings → Fronting '
            'notification.',
        'Notificación de frente (Android): una notificación continua con '
            'quién está al frente, co-frente, cronómetro, ánimo, ubicación, '
            'actividad y tu estado, que se actualiza al cambiar el frente. '
            'Personaliza título, saludo, icono, colores, diseño, botones, '
            'privacidad en la pantalla de bloqueo y estilos por miembro. '
            'Ajustes → Notificación de frente.',
      ),
    ],
  ),
  ChangelogRelease(
    version: '0.19.0',
    date: DateTime(2026, 11, 12),
    features: const [
      LocalizedText(
        'Relationships: between headmates and with people outside the '
            'system, with types, status, closeness, trust, dynamics, '
            'boundaries, event history, statistics and a relationship map.',
        'Relaciones: entre miembros y con personas de fuera, con tipo, '
            'estado, cercanía, confianza, dinámica, límites, historial, '
            'estadísticas y un mapa de relaciones.',
      ),
      LocalizedText(
        'Subsystems: nested subsystems with members and roles, purpose, '
            'origin, rules, connections, internal relationships and share '
            'of fronting; members can be brought in from a group.',
        'Subsistemas: subsistemas anidados con miembros y roles, propósito, '
            'origen, normas, conexiones, relaciones internas y parte del '
            'frente; se pueden traer miembros de un grupo.',
      ),
      LocalizedText(
        'Headspace Mapper: draw your inner world with draggable areas, '
            'connections, descriptions, residents and a list view.',
        'Mapa del espacio interior: dibuja tu mundo interior con zonas que '
            'se arrastran, conexiones, descripciones, residentes y vista de '
            'lista.',
      ),
    ],
  ),
  ChangelogRelease(
    version: '0.18.0',
    date: DateTime(2026, 11, 12),
    features: const [
      LocalizedText(
        'Sleep analysis: log room temperature, lighting, noise, comfort, '
            'interruptions, habits, dreams and who woke up; set a sleep '
            'schedule; see sleep debt, regularity and what goes with better '
            'sleep.',
        'Análisis del sueño: registra temperatura, luz, ruido, comodidad, '
            'interrupciones, hábitos, sueños y quién despertó; define un '
            'horario; ve la deuda de sueño, la regularidad y qué acompaña a '
            'un mejor descanso.',
      ),
      LocalizedText(
        'Cycle insights: customizable phases, your own symptoms, body signs '
            '(energy, pain, basal temperature, tests), cycle history, '
            'fertile-window estimates and personal patterns.',
        'Análisis del ciclo: fases personalizables, síntomas propios, señales '
            'del cuerpo (energía, dolor, temperatura basal, tests), historial, '
            'ventana fértil estimada y patrones personales.',
      ),
      LocalizedText(
        'Polls: yes/no, numeric scale, ranked-choice and rating polls, '
            'categories, results analytics with turnout, and poll history '
            'with participation per member.',
        'Encuestas: sí/no, escala numérica, por orden y valoración, '
            'categorías, análisis de resultados con participación e historial '
            'con participación por miembro.',
      ),
    ],
    improvements: const [
      LocalizedText(
        'Journal entries, workouts, transactions, classes and study sessions '
            'are attributed to the current fronter and can be filtered by '
            'member.',
        'Entradas, ejercicios, movimientos, clases y sesiones de estudio se '
            'atribuyen a quien está al frente y se pueden filtrar por miembro.',
      ),
    ],
  ),
  ChangelogRelease(
    version: '0.17.0',
    date: DateTime(2026, 11, 12),
    features: const [
      LocalizedText(
        'Finance: income, expenses, transfers, accounts and balances, '
            'monthly budgets, savings goals, recurring payments, statistics '
            'and a privacy toggle to hide amounts.',
        'Finanzas: ingresos, gastos, transferencias, cuentas y saldos, '
            'presupuestos mensuales, metas de ahorro, pagos recurrentes, '
            'estadísticas y un botón para ocultar importes.',
      ),
      LocalizedText(
        'Fitness: workouts with a live timer, distance, calories, effort, '
            'sets and reps, exercise history, personal bests and goals.',
        'Ejercicio: sesiones con cronómetro, distancia, calorías, esfuerzo, '
            'series y repeticiones, historial, mejores marcas y metas.',
      ),
      LocalizedText(
        'School: classes with weekly schedules, assignments and deadlines, '
            'grades and GPA, study timer and progress.',
        'Escuela: clases con horario, tareas y entregas, notas y promedio, '
            'cronómetro de estudio y progreso.',
      ),
    ],
    improvements: const [
      LocalizedText(
        'Finance can record estimated Work earnings as income.',
        'Finanzas puede registrar las ganancias estimadas de Trabajo como '
            'ingreso.',
      ),
    ],
  ),
  ChangelogRelease(
    version: '0.16.0',
    date: DateTime(2026, 11, 12),
    features: const [
      LocalizedText(
        'Journal: entries with categories, tags, mood, writing prompts, '
            'search, pinning, private entries and version history.',
        'Diario: entradas con categorías, etiquetas, ánimo, ideas para '
            'escribir, búsqueda, fijado, entradas privadas e historial de '
            'versiones.',
      ),
      LocalizedText(
        'Dictionary: your own terms and collections, plus import from '
            'wikis (any MediaWiki or Fandom page or category), files or '
            'pasted text.',
        'Diccionario: tus propios términos y colecciones, e importación '
            'desde wikis (cualquier página o categoría de MediaWiki o '
            'Fandom), archivos o texto pegado.',
      ),
      LocalizedText(
        'Achievements: milestones across fronting, wellbeing, journaling, '
            'habits and more, with tiers, progress and unlock history.',
        'Logros: metas de frente, bienestar, diario, hábitos y más, con '
            'niveles, progreso e historial.',
      ),
      LocalizedText(
        "What's New: this page, shown once after each update.",
        'Novedades: esta página, que aparece una vez tras cada '
            'actualización.',
      ),
    ],
    improvements: const [
      LocalizedText(
        'The Home journal quick action now opens the new Journal.',
        'La acción rápida de diario en Inicio ahora abre el nuevo Diario.',
      ),
      LocalizedText(
        'New data is included in backups, sync and Reset data.',
        'Los nuevos datos se incluyen en copias de seguridad, '
            'sincronización y Restablecer datos.',
      ),
    ],
  ),
  ChangelogRelease(
    version: '0.15.3',
    date: DateTime(2026, 11, 12),
    features: const [
      LocalizedText(
        'In-app updates: new versions install over the current app and '
            'keep your data.',
        'Actualizaciones en la app: las nuevas versiones se instalan sobre '
            'la actual y conservan tus datos.',
      ),
      LocalizedText(
        'Customisable Home dashboard, System Timeline, Pattern Explorer '
            'and How We Feel.',
        'Panel de Inicio personalizable, Línea de tiempo del sistema, '
            'Explorador de patrones y Cómo nos sentimos.',
      ),
      LocalizedText(
        'Cycle tracking, contacts with birthdays and the Import Center.',
        'Seguimiento del ciclo, contactos con cumpleaños y el Centro de '
            'importación.',
      ),
      LocalizedText(
        'Daily Insights, emotion library, locations and work tracking.',
        'Resumen diario, biblioteca de emociones, lugares y trabajo.',
      ),
    ],
    fixes: const [
      LocalizedText(
        'Reminders can repeat several times a day.',
        'Los recordatorios pueden repetirse varias veces al día.',
      ),
    ],
  ),
];

/// The release for [version], if it has notes.
ChangelogRelease? releaseFor(String version) {
  for (final r in prismChangelog) {
    if (r.version == version) return r;
  }
  return null;
}
