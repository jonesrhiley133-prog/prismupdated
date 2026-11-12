import 'package:intl/intl.dart';

/// Formats an amount stored in hundredths ("cents") of [currencyCode].
///
/// Prism always stores money as hundredths, whatever the currency, so the
/// value is `cents / 100`; the currency's own decimal digits (e.g. none for
/// JPY) only affect display.
String formatMoneyCents(int cents, String currencyCode, {String? locale}) {
  final f = NumberFormat.simpleCurrency(name: currencyCode, locale: locale);
  return f.format(cents / 100);
}

/// Parses user input like "18.25" or "18,25" into hundredths, or null if
/// invalid. Negative input is rejected (the minus sign is not accepted).
int? parseMoneyToCents(String input) {
  final cleaned = input.trim().replaceAll(RegExp(r'[^0-9.,]'), '');
  if (cleaned.isEmpty) return null;
  // Treat the last separator as the decimal point.
  final lastSep = cleaned.lastIndexOf(RegExp(r'[.,]'));
  String whole;
  String frac;
  if (lastSep >= 0 && cleaned.length - lastSep - 1 <= 2) {
    whole = cleaned.substring(0, lastSep).replaceAll(RegExp(r'[.,]'), '');
    frac = cleaned.substring(lastSep + 1);
  } else {
    whole = cleaned.replaceAll(RegExp(r'[.,]'), '');
    frac = '';
  }
  final w = int.tryParse(whole.isEmpty ? '0' : whole);
  if (w == null) return null;
  final f = int.tryParse(frac.padRight(2, '0').substring(0, 2)) ?? 0;
  return w * 100 + f;
}

/// Common currencies offered in the job editor.
const commonCurrencies = [
  'USD',
  'EUR',
  'GBP',
  'CAD',
  'AUD',
  'NZD',
  'JPY',
  'CHF',
  'SEK',
  'NOK',
  'DKK',
  'PLN',
  'MXN',
  'BRL',
  'INR',
  'ZAR',
  'SGD',
  'HKD',
  'KRW',
  'PHP',
];
