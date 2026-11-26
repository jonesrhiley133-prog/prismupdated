import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

bool _registered = false;

/// Adds the bundled Astro data and fonts to the app's licence page.
void registerAstroLicenses() {
  if (_registered) return;
  _registered = true;
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'Noto Sans Symbols (Prism Astro glyphs)',
    ], await rootBundle.loadString('assets/astro/fonts-OFL.txt'));
    yield const LicenseEntryWithLineBreaks(
      ['GeoNames (Prism Astro birthplaces)'],
      'Place names, coordinates and time zones from GeoNames (geonames.org), '
      'licensed under the Creative Commons Attribution 4.0 License '
      '(https://creativecommons.org/licenses/by/4.0/). The list was '
      'trimmed to towns with 15,000+ people.',
    );
  });
}
