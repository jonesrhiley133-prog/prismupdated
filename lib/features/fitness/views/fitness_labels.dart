import 'package:prism_plurality/l10n/app_localizations.dart';

String fitnessActivityLabel(AppLocalizations l10n, String key) => switch (key) {
  'walk' => l10n.fitWalk,
  'run' => l10n.fitRun,
  'cycle' => l10n.fitCycle,
  'swim' => l10n.fitSwim,
  'strength' => l10n.fitStrength,
  'yoga' => l10n.fitYoga,
  'hiit' => l10n.fitHiit,
  'hike' => l10n.fitHike,
  'dance' => l10n.fitDance,
  'sports' => l10n.fitSports,
  'stretch' => l10n.fitStretch,
  'climb' => l10n.fitClimb,
  'row' => l10n.fitRow,
  _ => l10n.fitOther,
};

String fitnessMetricLabel(AppLocalizations l10n, String metric) =>
    switch (metric) {
      'minutes' => l10n.fitMetricMinutes,
      'distance' => l10n.fitMetricDistance,
      'calories' => l10n.fitMetricCalories,
      _ => l10n.fitMetricWorkouts,
    };
