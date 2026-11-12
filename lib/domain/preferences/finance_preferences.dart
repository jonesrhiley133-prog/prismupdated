import 'package:prism_plurality/domain/preferences/preference_codec.dart';
import 'package:prism_plurality/domain/preferences/preference_definition.dart';

/// ISO 4217 code used to display Finance amounts.
const financeCurrencyPreference = PreferenceDefinition<String>(
  key: 'finance.currency',
  scope: PreferenceScope.appSynced,
  defaultValue: 'USD',
  codec: StringPreferenceCodec(),
  introducedInAppVersion: '0.17.0',
  introducedInSchemaVersion: 45,
);

/// Masks amounts in Finance until the eye button is tapped.
const financeHideAmountsPreference = PreferenceDefinition<bool>(
  key: 'finance.hide_amounts',
  scope: PreferenceScope.appSynced,
  defaultValue: false,
  codec: BoolPreferenceCodec(),
  introducedInAppVersion: '0.17.0',
  introducedInSchemaVersion: 45,
);
