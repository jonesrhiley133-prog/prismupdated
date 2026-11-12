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
