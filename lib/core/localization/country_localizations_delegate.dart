import 'package:country_picker/country_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Loads the country picker names synchronously so changing the app language
/// does not briefly tear down overlays or visible page state.
class AppCountryLocalizationsDelegate
    extends LocalizationsDelegate<CountryLocalizations> {
  const AppCountryLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<CountryLocalizations> load(Locale locale) =>
      SynchronousFuture(CountryLocalizations(locale));

  @override
  bool shouldReload(AppCountryLocalizationsDelegate old) => false;
}

const appCountryLocalizationsDelegate = AppCountryLocalizationsDelegate();
