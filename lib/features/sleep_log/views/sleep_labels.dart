import 'package:prism_plurality/l10n/app_localizations.dart';

String sleepOptionLabel(AppLocalizations l10n, String key) => switch (key) {
  'dark' => l10n.slpDark,
  'dim' => l10n.slpDim,
  'nightlight' => l10n.slpNightlight,
  'bright' => l10n.slpBright,
  'screen' => l10n.slpScreenOn,
  'bed' => l10n.slpBed,
  'couch' => l10n.slpCouch,
  'guest' => l10n.slpGuestBed,
  'travel' => l10n.slpTravel,
  'floor' => l10n.slpFloor,
  'silent' => l10n.slpSilent,
  'quiet' => l10n.slpQuiet,
  'white_noise' => l10n.slpWhiteNoise,
  'music' => l10n.slpMusic,
  'noisy' => l10n.slpNoisy,
  'alone' => l10n.slpAlone,
  'partner' => l10n.slpPartner,
  'pet' => l10n.slpPet,
  'child' => l10n.slpChild,
  'others' => l10n.slpOthers,
  'none' => l10n.slpNoDreams,
  'neutral' => l10n.slpNeutralDreams,
  'pleasant' => l10n.slpPleasant,
  'vivid' => l10n.slpVivid,
  'nightmare' => l10n.slpNightmare,
  'caffeine' => l10n.slpCaffeine,
  'alcohol' => l10n.slpAlcohol,
  'screens' => l10n.slpScreens,
  'exercise' => l10n.slpExercise,
  'late_meal' => l10n.slpLateMeal,
  'nap' => l10n.slpNap,
  'medication' => l10n.slpMedication,
  'stress' => l10n.slpStress,
  'pain' => l10n.slpPain,
  'reading' => l10n.slpReading,
  'meditation' => l10n.slpMeditation,
  'shower' => l10n.slpShower,
  'bathroom' => l10n.slpBathroom,
  'noise' => l10n.slpNoiseWake,
  'temperature' => l10n.slpTooHotCold,
  'switch' => l10n.slpSwitch,
  'anxiety' => l10n.slpAnxiety,
  _ => l10n.finCatOther,
};

/// Label for a factor-impact key such as `factor:caffeine` or `temp:16_19`.
String sleepImpactLabel(AppLocalizations l10n, String key) {
  final i = key.indexOf(':');
  final kind = key.substring(0, i), v = key.substring(i + 1);
  return switch (kind) {
    'temp' => l10n.slpTempRange(switch (v) {
      'lt16' => '< 16 °C',
      '16_19' => '16–19 °C',
      '19_22' => '19–22 °C',
      _ => '≥ 22 °C',
    }),
    'comfort' => l10n.slpComfortIs(v),
    _ => sleepOptionLabel(l10n, v),
  };
}
