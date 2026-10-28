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

  @override
  String get seasonTitle => 'Seasons';

  @override
  String get seasonAll => 'All seasons';

  @override
  String get seasonUnknown => 'Unassigned season';

  @override
  String seasonRaceCount(int count) {
    return '$count races';
  }

  @override
  String seasonCompletedCount(int count) {
    return '$count completed races';
  }

  @override
  String seasonObservationCount(int count) {
    return '$count valid observations';
  }

  @override
  String seasonUnassignedNotice(int count) {
    return '$count races have no assigned season. They stay in the list; select All seasons to include them in statistics.';
  }

  @override
  String get seasonStatisticsHint =>
      'Statistics exclude non-finishers and missing measurements.';

  @override
  String get shootingSelectionTitle => 'Selected shootings';

  @override
  String get shootingMetric => 'Metric';

  @override
  String get shootingSelection => 'Shootings';

  @override
  String get shootingAll => 'All shootings';

  @override
  String get shootingFirstProne => '1st prone';

  @override
  String get shootingSecondProne => '2nd prone';

  @override
  String get shootingFirstStanding => '1st standing';

  @override
  String get shootingSecondStanding => '2nd standing';

  @override
  String get shootingHits => 'Hits';

  @override
  String shootingValidCount(int valid, int count) {
    return '$valid of $count shootings have a measurement';
  }

  @override
  String get shootingNoMatch => 'No matching shooting is recorded.';

  @override
  String get shootingAmbiguous =>
      'Missing or unknown earlier shootings prevent this numbered selection.';

  @override
  String get shootingIncomplete =>
      'Some shootings, positions or measurements are missing.';

  @override
  String get shootingRelayUnavailable =>
      'Hits and misses are unavailable: relay data does not distinguish reserve shots from penalty loops. Range time is available when recorded.';

  @override
  String get shootingExcluded => 'This result is excluded from statistics.';

  @override
  String get shootingRelayPositionsUnavailable =>
      'Shooting positions are unavailable for whole-team relays. Choose All shootings for recorded range times.';

  @override
  String get seasonShootingTitle => 'Season shooting statistics';

  @override
  String get seasonShootingExplanation =>
      'For the selected shootings. Hit percentage uses known five-shot series; relay shots are excluded. Counts cover recorded series only. Missing series and uncertain order are not inferred.';

  @override
  String get seasonShootingHitPercent => 'Hit percentage';

  @override
  String get seasonShootingAverageMisses => 'Average misses per series';

  @override
  String get seasonShootingMeanRangeTime => 'Mean range time';

  @override
  String get seasonShootingMedianRangeTime => 'Median range time';

  @override
  String seasonShootingCoverage(int valid, int missing) {
    return '$valid valid series · $missing missing measurements';
  }

  @override
  String seasonShootingUnavailableRaces(int count) {
    return 'Races without selectable recorded series: $count';
  }

  @override
  String seasonShootingKnownShots(int hits, int shots) {
    return '$hits hits / $shots known shots';
  }

  @override
  String get seasonDistributionTitle => 'Season distribution';

  @override
  String seasonDistributionSeriesCount(int count) {
    return 'n = $count measured series · each observation is one series';
  }

  @override
  String seasonDistributionSeconds(String value) {
    return '$value s';
  }

  @override
  String get seasonDistributionEmpty =>
      'No valid measurements for this selection.';

  @override
  String get seasonDistributionLowData =>
      'Very little data: fewer than 5 series. Interpret the distribution with caution.';

  @override
  String seasonDistributionMean(String value) {
    return 'Mean: $value';
  }

  @override
  String seasonDistributionMedian(String value) {
    return 'Median: $value';
  }

  @override
  String get seasonDistributionShowChart => 'Show chart';

  @override
  String get seasonDistributionShowTable => 'Show accessible table';

  @override
  String get seasonDistributionCount => 'Count';

  @override
  String get seasonDistributionShare => 'Share';

  @override
  String get seasonDistributionSelectBin =>
      'Select a bar or interval to see its contributing races and series.';

  @override
  String seasonDistributionIntervals(int count) {
    return 'Target intervals: $count';
  }

  @override
  String get seasonDistributionContributions => 'Contributing races and series';

  @override
  String get seasonDistributionNoContributions => 'No series in this interval.';

  @override
  String get comparisonTitle => 'Compare seasons';

  @override
  String get comparisonSport => 'Biathlon';

  @override
  String get comparisonProgram => 'Program';

  @override
  String get comparisonSeasonA => 'Season A';

  @override
  String get comparisonSeasonB => 'Season B';

  @override
  String get comparisonNeedTwoSeasons =>
      'Two dated biathlon seasons are needed for comparison.';

  @override
  String get comparisonNoProgram =>
      'No unambiguous comparable program is known. Explicit class or event discipline metadata is required.';

  @override
  String comparisonUnknownCoverage(int unknownSeason, int unknownProgram) {
    return 'Excluded coverage: $unknownSeason races without a known biathlon sport/date; $unknownProgram with an unknown or ambiguous program.';
  }

  @override
  String comparisonRaceCoverage(int finished, int excluded) {
    return '$finished finished races · $excluded unfinished races excluded';
  }

  @override
  String get comparisonShowCounts => 'Show counts';

  @override
  String comparisonFilters(
    String sport,
    String program,
    String metric,
    String selection,
  ) {
    return 'Filters: $sport · $program · $metric · $selection';
  }

  @override
  String get comparisonPositionCaution =>
      'Position selections are unavailable when historical shooting positions cannot be verified. All retains known measured series.';

  @override
  String comparisonDeltaPoints(String value) {
    return 'Hit rate difference (B − A): $value percentage points';
  }

  @override
  String comparisonDeltaMisses(String value) {
    return 'Mean misses difference (B − A): $value per series';
  }

  @override
  String comparisonDeltaSeconds(String value) {
    return 'Mean range time difference (B − A): $value s';
  }

  @override
  String get comparisonCaution =>
      'Differences describe recorded series, not proven improvement. Small samples, cohorts and conditions can differ.';

  @override
  String get comparisonSprint => 'Sprint';

  @override
  String get comparisonIndividual => 'Individual';

  @override
  String get comparisonShortIndividual => 'Short individual';

  @override
  String get comparisonPursuit => 'Pursuit';

  @override
  String get comparisonMassStart => 'Mass start';

  @override
  String get comparisonSuperSprint => 'Super sprint';

  @override
  String get comparisonRelay => 'Relay';
}
