import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_et.dart';
import 'app_localizations_fi.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';
import 'app_localizations_nb.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_sv.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('et'),
    Locale('fi'),
    Locale('fr'),
    Locale('it'),
    Locale('nb'),
    Locale('ru'),
    Locale('sv'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'EQ Results'**
  String get appTitle;

  /// No description provided for @eventsTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose an event'**
  String get eventsTitle;

  /// No description provided for @eventsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Find an event and open live results.'**
  String get eventsSubtitle;

  /// No description provided for @searchEvents.
  ///
  /// In en, this message translates to:
  /// **'Search events'**
  String get searchEvents;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get login;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @tableDensity.
  ///
  /// In en, this message translates to:
  /// **'Table density'**
  String get tableDensity;

  /// No description provided for @comfortable.
  ///
  /// In en, this message translates to:
  /// **'Comfortable'**
  String get comfortable;

  /// No description provided for @compact.
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get compact;

  /// No description provided for @noEventsTitle.
  ///
  /// In en, this message translates to:
  /// **'No events'**
  String get noEventsTitle;

  /// No description provided for @noEventsMessage.
  ///
  /// In en, this message translates to:
  /// **'Import an EQ Timing event first.'**
  String get noEventsMessage;

  /// No description provided for @couldNotReadEvents.
  ///
  /// In en, this message translates to:
  /// **'Could not read events'**
  String get couldNotReadEvents;

  /// No description provided for @couldNotReadResults.
  ///
  /// In en, this message translates to:
  /// **'Could not read results'**
  String get couldNotReadResults;

  /// No description provided for @loadingEvents.
  ///
  /// In en, this message translates to:
  /// **'Loading events'**
  String get loadingEvents;

  /// No description provided for @loadingResults.
  ///
  /// In en, this message translates to:
  /// **'Loading results'**
  String get loadingResults;

  /// No description provided for @results.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get results;

  /// No description provided for @classes.
  ///
  /// In en, this message translates to:
  /// **'Classes'**
  String get classes;

  /// No description provided for @classLabel.
  ///
  /// In en, this message translates to:
  /// **'Class'**
  String get classLabel;

  /// No description provided for @split.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get split;

  /// No description provided for @searchResults.
  ///
  /// In en, this message translates to:
  /// **'Search athlete, club or team'**
  String get searchResults;

  /// No description provided for @athlete.
  ///
  /// In en, this message translates to:
  /// **'Athlete'**
  String get athlete;

  /// No description provided for @club.
  ///
  /// In en, this message translates to:
  /// **'Club'**
  String get club;

  /// No description provided for @shooting.
  ///
  /// In en, this message translates to:
  /// **'Shooting'**
  String get shooting;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @gap.
  ///
  /// In en, this message translates to:
  /// **'Gap'**
  String get gap;

  /// No description provided for @place.
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get place;

  /// No description provided for @bib.
  ///
  /// In en, this message translates to:
  /// **'Bib'**
  String get bib;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @sport.
  ///
  /// In en, this message translates to:
  /// **'Sport'**
  String get sport;

  /// No description provided for @eventId.
  ///
  /// In en, this message translates to:
  /// **'Event ID'**
  String get eventId;

  /// No description provided for @noClassesTitle.
  ///
  /// In en, this message translates to:
  /// **'No classes'**
  String get noClassesTitle;

  /// No description provided for @noClassesMessage.
  ///
  /// In en, this message translates to:
  /// **'The import has not written class data yet.'**
  String get noClassesMessage;

  /// No description provided for @noResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get noResultsTitle;

  /// No description provided for @noResultsMessage.
  ///
  /// In en, this message translates to:
  /// **'The class has no timing rows yet.'**
  String get noResultsMessage;

  /// No description provided for @athleteDetails.
  ///
  /// In en, this message translates to:
  /// **'Athlete details'**
  String get athleteDetails;

  /// No description provided for @splitBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Split breakdown'**
  String get splitBreakdown;

  /// No description provided for @backToResults.
  ///
  /// In en, this message translates to:
  /// **'Back to results'**
  String get backToResults;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @signInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get signInWithGoogle;

  /// No description provided for @signInWithEmail.
  ///
  /// In en, this message translates to:
  /// **'Sign in with email'**
  String get signInWithEmail;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'de',
    'en',
    'es',
    'et',
    'fi',
    'fr',
    'it',
    'nb',
    'ru',
    'sv',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'et':
      return AppLocalizationsEt();
    case 'fi':
      return AppLocalizationsFi();
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
    case 'nb':
      return AppLocalizationsNb();
    case 'ru':
      return AppLocalizationsRu();
    case 'sv':
      return AppLocalizationsSv();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
