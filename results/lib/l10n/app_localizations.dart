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

  /// No description provided for @biathlonStatistics.
  ///
  /// In en, this message translates to:
  /// **'Biathlon statistics'**
  String get biathlonStatistics;

  /// No description provided for @biathlonFinishTime.
  ///
  /// In en, this message translates to:
  /// **'Finish time'**
  String get biathlonFinishTime;

  /// No description provided for @biathlonSkiTime.
  ///
  /// In en, this message translates to:
  /// **'Ski time'**
  String get biathlonSkiTime;

  /// No description provided for @biathlonShootingTime.
  ///
  /// In en, this message translates to:
  /// **'Shooting time'**
  String get biathlonShootingTime;

  /// No description provided for @biathlonHitProneLabel.
  ///
  /// In en, this message translates to:
  /// **'Prone hit percentage'**
  String get biathlonHitProneLabel;

  /// No description provided for @biathlonHitStandingLabel.
  ///
  /// In en, this message translates to:
  /// **'Standing hit percentage'**
  String get biathlonHitStandingLabel;

  /// No description provided for @biathlonHitTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Total hit percentage'**
  String get biathlonHitTotalLabel;

  /// No description provided for @biathlonAllFinishers.
  ///
  /// In en, this message translates to:
  /// **'All finishers'**
  String get biathlonAllFinishers;

  /// No description provided for @biathlonTopHalf.
  ///
  /// In en, this message translates to:
  /// **'Top 50 %'**
  String get biathlonTopHalf;

  /// No description provided for @biathlonNetSkiTime.
  ///
  /// In en, this message translates to:
  /// **'Net ski time'**
  String get biathlonNetSkiTime;

  /// No description provided for @biathlonPenaltyTime.
  ///
  /// In en, this message translates to:
  /// **'Penalty time'**
  String get biathlonPenaltyTime;

  /// No description provided for @biathlonRangeTime.
  ///
  /// In en, this message translates to:
  /// **'Time on the range'**
  String get biathlonRangeTime;

  /// No description provided for @biathlonProneTime.
  ///
  /// In en, this message translates to:
  /// **'Prone shooting time'**
  String get biathlonProneTime;

  /// No description provided for @biathlonStandingTime.
  ///
  /// In en, this message translates to:
  /// **'Standing shooting time'**
  String get biathlonStandingTime;

  /// No description provided for @biathlonTotalMisses.
  ///
  /// In en, this message translates to:
  /// **'Total misses'**
  String get biathlonTotalMisses;

  /// No description provided for @biathlonProneMisses.
  ///
  /// In en, this message translates to:
  /// **'Prone misses'**
  String get biathlonProneMisses;

  /// No description provided for @biathlonStandingMisses.
  ///
  /// In en, this message translates to:
  /// **'Standing misses'**
  String get biathlonStandingMisses;

  /// No description provided for @biathlonSkiRank.
  ///
  /// In en, this message translates to:
  /// **'Ski rank'**
  String get biathlonSkiRank;

  /// No description provided for @biathlonNetSkiRank.
  ///
  /// In en, this message translates to:
  /// **'Net ski rank'**
  String get biathlonNetSkiRank;

  /// No description provided for @biathlonShootingRank.
  ///
  /// In en, this message translates to:
  /// **'Shooting rank'**
  String get biathlonShootingRank;

  /// No description provided for @biathlonRangeRank.
  ///
  /// In en, this message translates to:
  /// **'Range rank'**
  String get biathlonRangeRank;

  /// No description provided for @biathlonPenaltyRank.
  ///
  /// In en, this message translates to:
  /// **'Penalty rank'**
  String get biathlonPenaltyRank;

  /// No description provided for @biathlonFinishRank.
  ///
  /// In en, this message translates to:
  /// **'Finish rank'**
  String get biathlonFinishRank;

  /// No description provided for @biathlonPassingTime.
  ///
  /// In en, this message translates to:
  /// **'Passing time'**
  String get biathlonPassingTime;

  /// No description provided for @biathlonSplitTime.
  ///
  /// In en, this message translates to:
  /// **'Split time'**
  String get biathlonSplitTime;

  /// No description provided for @biathlonPassingRank.
  ///
  /// In en, this message translates to:
  /// **'Rank at passing'**
  String get biathlonPassingRank;

  /// No description provided for @biathlonSplitRank.
  ///
  /// In en, this message translates to:
  /// **'Split rank'**
  String get biathlonSplitRank;

  /// No description provided for @biathlonMissesLabel.
  ///
  /// In en, this message translates to:
  /// **'Misses'**
  String get biathlonMissesLabel;

  /// No description provided for @biathlonRangeExitTime.
  ///
  /// In en, this message translates to:
  /// **'Range exit time'**
  String get biathlonRangeExitTime;

  /// No description provided for @biathlonRangeApproach.
  ///
  /// In en, this message translates to:
  /// **'Approach to range'**
  String get biathlonRangeApproach;

  /// No description provided for @biathlonRangeEntry.
  ///
  /// In en, this message translates to:
  /// **'Entry to range'**
  String get biathlonRangeEntry;

  /// No description provided for @biathlonShootingDone.
  ///
  /// In en, this message translates to:
  /// **'Shooting completed'**
  String get biathlonShootingDone;

  /// No description provided for @biathlonShootingExit.
  ///
  /// In en, this message translates to:
  /// **'Exit from shooting'**
  String get biathlonShootingExit;

  /// No description provided for @biathlonRangeExitTotal.
  ///
  /// In en, this message translates to:
  /// **'Total time to range exit'**
  String get biathlonRangeExitTotal;

  /// No description provided for @biathlonCumulativeMisses.
  ///
  /// In en, this message translates to:
  /// **'Misses so far'**
  String get biathlonCumulativeMisses;

  /// No description provided for @biathlonStartTime.
  ///
  /// In en, this message translates to:
  /// **'Start time'**
  String get biathlonStartTime;

  /// No description provided for @biathlonDetailSelector.
  ///
  /// In en, this message translates to:
  /// **'More measurements: splits, shooting and laps'**
  String get biathlonDetailSelector;

  /// No description provided for @biathlonExtraDetails.
  ///
  /// In en, this message translates to:
  /// **'All splits, shooting bouts and ski laps'**
  String get biathlonExtraDetails;

  /// No description provided for @biathlonComparisonDescription.
  ///
  /// In en, this message translates to:
  /// **'Your individual races compared with {group} in the same class and stage.'**
  String biathlonComparisonDescription(String group);

  /// No description provided for @biathlonComparisonUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No comparison of {metric} with {group} yet. Reference data for this measurement is unavailable.'**
  String biathlonComparisonUnavailable(String metric, String group);

  /// No description provided for @biathlonPercentDifferenceCaption.
  ///
  /// In en, this message translates to:
  /// **'Difference in percentage points · above the line is better'**
  String get biathlonPercentDifferenceCaption;

  /// No description provided for @biathlonDifferenceCaption.
  ///
  /// In en, this message translates to:
  /// **'Difference from {group} · above the line is better'**
  String biathlonDifferenceCaption(String group);

  /// No description provided for @biathlonRaceLabel.
  ///
  /// In en, this message translates to:
  /// **'Race {id}'**
  String biathlonRaceLabel(String id);

  /// No description provided for @biathlonCohortSummary.
  ///
  /// In en, this message translates to:
  /// **'{group}: {count} of {total} finishers'**
  String biathlonCohortSummary(String group, int count, int total);

  /// No description provided for @biathlonShootingNumber.
  ///
  /// In en, this message translates to:
  /// **'Shooting {index}'**
  String biathlonShootingNumber(int index);

  /// No description provided for @biathlonSkiLap.
  ///
  /// In en, this message translates to:
  /// **'Ski lap {index}'**
  String biathlonSkiLap(int index);

  /// No description provided for @biathlonOwnValue.
  ///
  /// In en, this message translates to:
  /// **'You: {value}'**
  String biathlonOwnValue(String value);

  /// No description provided for @biathlonYourDifference.
  ///
  /// In en, this message translates to:
  /// **'Your difference: {value}'**
  String biathlonYourDifference(String value);

  /// No description provided for @biathlonDecimalMisses.
  ///
  /// In en, this message translates to:
  /// **'{value} misses'**
  String biathlonDecimalMisses(String value);

  /// No description provided for @biathlonPercentagePoints.
  ///
  /// In en, this message translates to:
  /// **'{value} percentage points'**
  String biathlonPercentagePoints(String value);

  /// No description provided for @biathlonAverageHitPercent.
  ///
  /// In en, this message translates to:
  /// **'Average hit percentage'**
  String get biathlonAverageHitPercent;

  /// No description provided for @biathlonAverageHitExplanation.
  ///
  /// In en, this message translates to:
  /// **'Your completed individual biathlon races. Each race has equal weight; missing shooting data is excluded.'**
  String get biathlonAverageHitExplanation;

  /// No description provided for @biathlonHitProne.
  ///
  /// In en, this message translates to:
  /// **'Prone'**
  String get biathlonHitProne;

  /// No description provided for @biathlonHitStanding.
  ///
  /// In en, this message translates to:
  /// **'Standing'**
  String get biathlonHitStanding;

  /// No description provided for @biathlonHitTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get biathlonHitTotal;

  /// No description provided for @biathlonAverageRaceCount.
  ///
  /// In en, this message translates to:
  /// **'{count} races'**
  String biathlonAverageRaceCount(int count);

  /// No description provided for @importWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for results'**
  String get importWaiting;

  /// No description provided for @importInProgress.
  ///
  /// In en, this message translates to:
  /// **'Importing'**
  String get importInProgress;

  /// No description provided for @importPartial.
  ///
  /// In en, this message translates to:
  /// **'Partially imported'**
  String get importPartial;

  /// No description provided for @importUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get importUpdated;

  /// No description provided for @regressionCompareWith.
  ///
  /// In en, this message translates to:
  /// **'Compare with: {target}'**
  String regressionCompareWith(String target);

  /// No description provided for @regressionChooseTarget.
  ///
  /// In en, this message translates to:
  /// **'Choose comparison'**
  String get regressionChooseTarget;

  /// No description provided for @regressionSelectFromList.
  ///
  /// In en, this message translates to:
  /// **'Choose a comparison value in the results list for {subject}, then press OK.'**
  String regressionSelectFromList(String subject);

  /// No description provided for @regressionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get regressionCancel;

  /// No description provided for @regressionApply.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get regressionApply;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Results'**
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

  /// No description provided for @biathlonShootingIn.
  ///
  /// In en, this message translates to:
  /// **'Into shooting {index}'**
  String biathlonShootingIn(int index);

  /// No description provided for @biathlonPositionProne.
  ///
  /// In en, this message translates to:
  /// **'prone'**
  String get biathlonPositionProne;

  /// No description provided for @biathlonPositionStanding.
  ///
  /// In en, this message translates to:
  /// **'standing'**
  String get biathlonPositionStanding;

  /// No description provided for @biathlonPositionUnknown.
  ///
  /// In en, this message translates to:
  /// **'unknown position'**
  String get biathlonPositionUnknown;

  /// No description provided for @biathlonMisses.
  ///
  /// In en, this message translates to:
  /// **'{count} misses'**
  String biathlonMisses(int count);

  /// No description provided for @biathlonPenalty.
  ///
  /// In en, this message translates to:
  /// **'Penalty {time}'**
  String biathlonPenalty(String time);

  /// No description provided for @biathlonRankNumber.
  ///
  /// In en, this message translates to:
  /// **'No. {rank}'**
  String biathlonRankNumber(int rank);

  /// No description provided for @biathlonRankUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No. –'**
  String get biathlonRankUnavailable;

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

  /// No description provided for @connectAthlete.
  ///
  /// In en, this message translates to:
  /// **'Link athlete'**
  String get connectAthlete;

  /// No description provided for @connectAthleteDescription.
  ///
  /// In en, this message translates to:
  /// **'Search by full name to link your account to the right athlete.'**
  String get connectAthleteDescription;

  /// No description provided for @connectAthleteOnboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'Find your athlete profile'**
  String get connectAthleteOnboardingTitle;

  /// No description provided for @connectAthleteOnboardingDescription.
  ///
  /// In en, this message translates to:
  /// **'Link your account to your own results, or choose Not now.'**
  String get connectAthleteOnboardingDescription;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// No description provided for @findAthlete.
  ///
  /// In en, this message translates to:
  /// **'Find athlete'**
  String get findAthlete;

  /// No description provided for @noAthleteMatches.
  ///
  /// In en, this message translates to:
  /// **'No athlete was found with this full name.'**
  String get noAthleteMatches;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @enterFullName.
  ///
  /// In en, this message translates to:
  /// **'Enter your full name first.'**
  String get enterFullName;

  /// No description provided for @athleteLinked.
  ///
  /// In en, this message translates to:
  /// **'{name} is linked to your account'**
  String athleteLinked(String name);

  /// No description provided for @couldNotReadAthleteLink.
  ///
  /// In en, this message translates to:
  /// **'Could not read the athlete link'**
  String get couldNotReadAthleteLink;

  /// No description provided for @settingsSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save or sync your settings. Your choice is still selected.'**
  String get settingsSyncFailed;

  /// No description provided for @settingsRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get settingsRetry;

  /// No description provided for @seasonTitle.
  ///
  /// In en, this message translates to:
  /// **'Seasons'**
  String get seasonTitle;

  /// No description provided for @seasonAll.
  ///
  /// In en, this message translates to:
  /// **'All seasons'**
  String get seasonAll;

  /// No description provided for @seasonUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unassigned season'**
  String get seasonUnknown;

  /// No description provided for @seasonRaceCount.
  ///
  /// In en, this message translates to:
  /// **'{count} races'**
  String seasonRaceCount(int count);

  /// No description provided for @seasonCompletedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} completed races'**
  String seasonCompletedCount(int count);

  /// No description provided for @seasonObservationCount.
  ///
  /// In en, this message translates to:
  /// **'{count} valid observations'**
  String seasonObservationCount(int count);

  /// No description provided for @seasonUnassignedNotice.
  ///
  /// In en, this message translates to:
  /// **'{count} races have no assigned season. They stay in the list; select All seasons to include them in statistics.'**
  String seasonUnassignedNotice(int count);

  /// No description provided for @seasonStatisticsHint.
  ///
  /// In en, this message translates to:
  /// **'Statistics exclude non-finishers and missing measurements.'**
  String get seasonStatisticsHint;

  /// No description provided for @shootingSelectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Selected shootings'**
  String get shootingSelectionTitle;

  /// No description provided for @shootingMetric.
  ///
  /// In en, this message translates to:
  /// **'Metric'**
  String get shootingMetric;

  /// No description provided for @shootingSelection.
  ///
  /// In en, this message translates to:
  /// **'Shootings'**
  String get shootingSelection;

  /// No description provided for @shootingAll.
  ///
  /// In en, this message translates to:
  /// **'All shootings'**
  String get shootingAll;

  /// No description provided for @shootingFirstProne.
  ///
  /// In en, this message translates to:
  /// **'1st prone'**
  String get shootingFirstProne;

  /// No description provided for @shootingSecondProne.
  ///
  /// In en, this message translates to:
  /// **'2nd prone'**
  String get shootingSecondProne;

  /// No description provided for @shootingFirstStanding.
  ///
  /// In en, this message translates to:
  /// **'1st standing'**
  String get shootingFirstStanding;

  /// No description provided for @shootingSecondStanding.
  ///
  /// In en, this message translates to:
  /// **'2nd standing'**
  String get shootingSecondStanding;

  /// No description provided for @shootingHits.
  ///
  /// In en, this message translates to:
  /// **'Hits'**
  String get shootingHits;

  /// No description provided for @shootingValidCount.
  ///
  /// In en, this message translates to:
  /// **'{valid} of {count} shootings have a measurement'**
  String shootingValidCount(int valid, int count);

  /// No description provided for @shootingNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No matching shooting is recorded.'**
  String get shootingNoMatch;

  /// No description provided for @shootingAmbiguous.
  ///
  /// In en, this message translates to:
  /// **'Missing or unknown earlier shootings prevent this numbered selection.'**
  String get shootingAmbiguous;

  /// No description provided for @shootingIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Some shootings, positions or measurements are missing.'**
  String get shootingIncomplete;

  /// No description provided for @shootingRelayUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Hits and misses are unavailable: relay data does not distinguish reserve shots from penalty loops. Range time is available when recorded.'**
  String get shootingRelayUnavailable;

  /// No description provided for @shootingExcluded.
  ///
  /// In en, this message translates to:
  /// **'This result is excluded from statistics.'**
  String get shootingExcluded;

  /// No description provided for @shootingRelayPositionsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Shooting positions are unavailable for whole-team relays. Choose All shootings for recorded range times.'**
  String get shootingRelayPositionsUnavailable;

  /// No description provided for @seasonShootingTitle.
  ///
  /// In en, this message translates to:
  /// **'Season shooting statistics'**
  String get seasonShootingTitle;

  /// No description provided for @seasonShootingExplanation.
  ///
  /// In en, this message translates to:
  /// **'For the selected shootings. Hit percentage uses known five-shot series; relay shots are excluded. Counts cover recorded series only. Missing series and uncertain order are not inferred.'**
  String get seasonShootingExplanation;

  /// No description provided for @seasonShootingHitPercent.
  ///
  /// In en, this message translates to:
  /// **'Hit percentage'**
  String get seasonShootingHitPercent;

  /// No description provided for @seasonShootingAverageMisses.
  ///
  /// In en, this message translates to:
  /// **'Average misses per series'**
  String get seasonShootingAverageMisses;

  /// No description provided for @seasonShootingMeanRangeTime.
  ///
  /// In en, this message translates to:
  /// **'Mean range time'**
  String get seasonShootingMeanRangeTime;

  /// No description provided for @seasonShootingMedianRangeTime.
  ///
  /// In en, this message translates to:
  /// **'Median range time'**
  String get seasonShootingMedianRangeTime;

  /// No description provided for @seasonShootingCoverage.
  ///
  /// In en, this message translates to:
  /// **'{valid} valid series · {missing} missing measurements'**
  String seasonShootingCoverage(int valid, int missing);

  /// No description provided for @seasonShootingUnavailableRaces.
  ///
  /// In en, this message translates to:
  /// **'Races without selectable recorded series: {count}'**
  String seasonShootingUnavailableRaces(int count);

  /// No description provided for @seasonShootingKnownShots.
  ///
  /// In en, this message translates to:
  /// **'{hits} hits / {shots} known shots'**
  String seasonShootingKnownShots(int hits, int shots);

  /// No description provided for @seasonDistributionTitle.
  ///
  /// In en, this message translates to:
  /// **'Season distribution'**
  String get seasonDistributionTitle;

  /// No description provided for @seasonDistributionSeriesCount.
  ///
  /// In en, this message translates to:
  /// **'n = {count} measured series · each observation is one series'**
  String seasonDistributionSeriesCount(int count);

  /// No description provided for @seasonDistributionSeconds.
  ///
  /// In en, this message translates to:
  /// **'{value} s'**
  String seasonDistributionSeconds(String value);

  /// No description provided for @seasonDistributionEmpty.
  ///
  /// In en, this message translates to:
  /// **'No valid measurements for this selection.'**
  String get seasonDistributionEmpty;

  /// No description provided for @seasonDistributionLowData.
  ///
  /// In en, this message translates to:
  /// **'Very little data: fewer than 5 series. Interpret the distribution with caution.'**
  String get seasonDistributionLowData;

  /// No description provided for @seasonDistributionMean.
  ///
  /// In en, this message translates to:
  /// **'Mean: {value}'**
  String seasonDistributionMean(String value);

  /// No description provided for @seasonDistributionMedian.
  ///
  /// In en, this message translates to:
  /// **'Median: {value}'**
  String seasonDistributionMedian(String value);

  /// No description provided for @seasonDistributionShowChart.
  ///
  /// In en, this message translates to:
  /// **'Show chart'**
  String get seasonDistributionShowChart;

  /// No description provided for @seasonDistributionShowTable.
  ///
  /// In en, this message translates to:
  /// **'Show accessible table'**
  String get seasonDistributionShowTable;

  /// No description provided for @seasonDistributionCount.
  ///
  /// In en, this message translates to:
  /// **'Count'**
  String get seasonDistributionCount;

  /// No description provided for @seasonDistributionShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get seasonDistributionShare;

  /// No description provided for @seasonDistributionSelectBin.
  ///
  /// In en, this message translates to:
  /// **'Select a bar or interval to see its contributing races and series.'**
  String get seasonDistributionSelectBin;

  /// No description provided for @seasonDistributionIntervals.
  ///
  /// In en, this message translates to:
  /// **'Target intervals: {count}'**
  String seasonDistributionIntervals(int count);

  /// No description provided for @seasonDistributionContributions.
  ///
  /// In en, this message translates to:
  /// **'Contributing races and series'**
  String get seasonDistributionContributions;

  /// No description provided for @seasonDistributionNoContributions.
  ///
  /// In en, this message translates to:
  /// **'No series in this interval.'**
  String get seasonDistributionNoContributions;
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
