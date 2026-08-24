import 'package:flutter/widgets.dart';
import 'package:clashxy/l10n/app_localizations.dart';

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

Locale? localeForSetting(String localeCode) {
  if (localeCode == 'system') return null;
  for (final locale in AppLocalizations.supportedLocales) {
    if (locale.toLanguageTag() == localeCode ||
        locale.languageCode == localeCode) {
      return locale;
    }
  }
  return null;
}
