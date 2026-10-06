// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get biathlonStatistics => 'Biathlon statistics';

  @override
  String get biathlonFinishTime => 'Finish time';

  @override
  String get biathlonSkiTime => 'Ski time';

  @override
  String get biathlonShootingTime => 'Shooting time';

  @override
  String get biathlonHitProneLabel => 'Prone hit percentage';

  @override
  String get biathlonHitStandingLabel => 'Standing hit percentage';

  @override
  String get biathlonHitTotalLabel => 'Total hit percentage';

  @override
  String get biathlonAllFinishers => 'All finishers';

  @override
  String get biathlonTopHalf => 'Top 50 %';

  @override
  String get biathlonNetSkiTime => 'Net ski time';

  @override
  String get biathlonPenaltyTime => 'Penalty time';

  @override
  String get biathlonRangeTime => 'Time on the range';

  @override
  String get biathlonProneTime => 'Prone shooting time';

  @override
  String get biathlonStandingTime => 'Standing shooting time';

  @override
  String get biathlonTotalMisses => 'Total misses';

  @override
  String get biathlonProneMisses => 'Prone misses';

  @override
  String get biathlonStandingMisses => 'Standing misses';

  @override
  String get biathlonSkiRank => 'Ski rank';

  @override
  String get biathlonNetSkiRank => 'Net ski rank';

  @override
  String get biathlonShootingRank => 'Shooting rank';

  @override
  String get biathlonRangeRank => 'Range rank';

  @override
  String get biathlonPenaltyRank => 'Penalty rank';

  @override
  String get biathlonFinishRank => 'Finish rank';

  @override
  String get biathlonPassingTime => 'Passing time';

  @override
  String get biathlonSplitTime => 'Split time';

  @override
  String get biathlonPassingRank => 'Rank at passing';

  @override
  String get biathlonSplitRank => 'Split rank';

  @override
  String get biathlonMissesLabel => 'Misses';

  @override
  String get biathlonRangeExitTime => 'Range exit time';

  @override
  String get biathlonRangeApproach => 'Approach to range';

  @override
  String get biathlonRangeEntry => 'Entry to range';

  @override
  String get biathlonShootingDone => 'Shooting completed';

  @override
  String get biathlonShootingExit => 'Exit from shooting';

  @override
  String get biathlonRangeExitTotal => 'Total time to range exit';

  @override
  String get biathlonCumulativeMisses => 'Misses so far';

  @override
  String get biathlonStartTime => 'Start time';

  @override
  String get biathlonDetailSelector =>
      'More measurements: splits, shooting and laps';

  @override
  String get biathlonExtraDetails => 'All splits, shooting bouts and ski laps';

  @override
  String biathlonComparisonDescription(String group) {
    return 'Your individual races compared with $group in the same class and stage.';
  }

  @override
  String biathlonComparisonUnavailable(String metric, String group) {
    return 'No comparison of $metric with $group yet. Reference data for this measurement is unavailable.';
  }

  @override
  String get biathlonPercentDifferenceCaption =>
      'Difference in percentage points · above the line is better';

  @override
  String biathlonDifferenceCaption(String group) {
    return 'Difference from $group · above the line is better';
  }

  @override
  String biathlonRaceLabel(String id) {
    return 'Race $id';
  }

  @override
  String biathlonCohortSummary(String group, int count, int total) {
    return '$group: $count of $total finishers';
  }

  @override
  String biathlonShootingNumber(int index) {
    return 'Shooting $index';
  }

  @override
  String biathlonSkiLap(int index) {
    return 'Ski lap $index';
  }

  @override
  String biathlonOwnValue(String value) {
    return 'You: $value';
  }

  @override
  String biathlonYourDifference(String value) {
    return 'Your difference: $value';
  }

  @override
  String biathlonDecimalMisses(String value) {
    return '$value misses';
  }

  @override
  String biathlonPercentagePoints(String value) {
    return '$value percentage points';
  }

  @override
  String get biathlonAverageHitPercent => 'Average hit percentage';

  @override
  String get biathlonAverageHitExplanation =>
      'Your completed individual biathlon races. Each race has equal weight; missing shooting data is excluded.';

  @override
  String get biathlonHitProne => 'Prone';

  @override
  String get biathlonHitStanding => 'Standing';

  @override
  String get biathlonHitTotal => 'Total';

  @override
  String biathlonAverageRaceCount(int count) {
    return '$count races';
  }

  @override
  String get importWaiting => 'Waiting for results';

  @override
  String get importInProgress => 'Importing';

  @override
  String get importPartial => 'Partially imported';

  @override
  String get importUpdated => 'Updated';

  @override
  String regressionCompareWith(String target) {
    return 'Compare with: $target';
  }

  @override
  String get regressionChooseTarget => 'Choose comparison';

  @override
  String regressionSelectFromList(String subject) {
    return 'Choose a comparison value in the results list for $subject, then press OK.';
  }

  @override
  String get regressionCancel => 'Cancel';

  @override
  String get regressionApply => 'OK';

  @override
  String get appTitle => 'Results';

  @override
  String get eventsTitle => 'Choose an event';

  @override
  String get eventsSubtitle => 'Find an event and open live results.';

  @override
  String get searchEvents => 'Search events';

  @override
  String get login => 'Log in';

  @override
  String get logout => 'Log out';

  @override
  String get account => 'Account';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get tableDensity => 'Table density';

  @override
  String get comfortable => 'Comfortable';

  @override
  String get compact => 'Compact';

  @override
  String get noEventsTitle => 'No events';

  @override
  String get noEventsMessage => 'Import an EQ Timing event first.';

  @override
  String get couldNotReadEvents => 'Could not read events';

  @override
  String get couldNotReadResults => 'Could not read results';

  @override
  String get loadingEvents => 'Loading events';

  @override
  String get loadingResults => 'Loading results';

  @override
  String get results => 'Results';

  @override
  String get classes => 'Classes';

  @override
  String get classLabel => 'Class';

  @override
  String get split => 'Split';

  @override
  String get searchResults => 'Search athlete, club or team';

  @override
  String get athlete => 'Athlete';

  @override
  String get club => 'Club';

  @override
  String get shooting => 'Shooting';

  @override
  String biathlonShootingIn(int index) {
    return 'Into shooting $index';
  }

  @override
  String get biathlonPositionProne => 'prone';

  @override
  String get biathlonPositionStanding => 'standing';

  @override
  String get biathlonPositionUnknown => 'unknown position';

  @override
  String biathlonMisses(int count) {
    return '$count misses';
  }

  @override
  String biathlonPenalty(String time) {
    return 'Penalty $time';
  }

  @override
  String biathlonRankNumber(int rank) {
    return 'No. $rank';
  }

  @override
  String get biathlonRankUnavailable => 'No. –';

  @override
  String get time => 'Time';

  @override
  String get gap => 'Gap';

  @override
  String get place => 'Place';

  @override
  String get bib => 'Bib';

  @override
  String get date => 'Date';

  @override
  String get sport => 'Sport';

  @override
  String get eventId => 'Event ID';

  @override
  String get noClassesTitle => 'No classes';

  @override
  String get noClassesMessage => 'The import has not written class data yet.';

  @override
  String get noResultsTitle => 'No results';

  @override
  String get noResultsMessage => 'The class has no timing rows yet.';

  @override
  String get athleteDetails => 'Athlete details';

  @override
  String get splitBreakdown => 'Split breakdown';

  @override
  String get backToResults => 'Back to results';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get signInWithGoogle => 'Continue with Google';

  @override
  String get signInWithEmail => 'Sign in with email';

  @override
  String get createAccount => 'Create account';

  @override
  String get connectAthlete => 'Link athlete';

  @override
  String get connectAthleteDescription =>
      'Search by full name to link your account to the right athlete.';

  @override
  String get connectAthleteOnboardingTitle => 'Find your athlete profile';

  @override
  String get connectAthleteOnboardingDescription =>
      'Link your account to your own results, or choose Not now.';

  @override
  String get fullName => 'Full name';

  @override
  String get findAthlete => 'Find athlete';

  @override
  String get noAthleteMatches => 'No athlete was found with this full name.';

  @override
  String get notNow => 'Not now';

  @override
  String get enterFullName => 'Enter your full name first.';

  @override
  String athleteLinked(String name) {
    return '$name is linked to your account';
  }

  @override
  String get couldNotReadAthleteLink => 'Could not read the athlete link';

  @override
  String get settingsSyncFailed =>
      'Could not save or sync your settings. Your choice is still selected.';

  @override
  String get settingsRetry => 'Try again';
}
