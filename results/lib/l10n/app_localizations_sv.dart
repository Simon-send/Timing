// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swedish (`sv`).
class AppLocalizationsSv extends AppLocalizations {
  AppLocalizationsSv([String locale = 'sv']) : super(locale);

  @override
  String get biathlonStatistics => 'Skidskyttestatistik';

  @override
  String get biathlonFinishTime => 'Sluttid';

  @override
  String get biathlonSkiTime => 'Skidtid';

  @override
  String get biathlonShootingTime => 'Skjuttid';

  @override
  String get biathlonHitProneLabel => 'Träffprocent liggande';

  @override
  String get biathlonHitStandingLabel => 'Träffprocent stående';

  @override
  String get biathlonHitTotalLabel => 'Total träffprocent';

  @override
  String get biathlonAllFinishers => 'Alla som gått i mål';

  @override
  String get biathlonTopHalf => 'Bästa 50 %';

  @override
  String get biathlonNetSkiTime => 'Netto skidtid';

  @override
  String get biathlonPenaltyTime => 'Strafftid';

  @override
  String get biathlonRangeTime => 'Tid på skjutvallen';

  @override
  String get biathlonProneTime => 'Tid för liggande skytte';

  @override
  String get biathlonStandingTime => 'Tid för stående skytte';

  @override
  String get biathlonTotalMisses => 'Bom totalt';

  @override
  String get biathlonProneMisses => 'Bom liggande';

  @override
  String get biathlonStandingMisses => 'Bom stående';

  @override
  String get biathlonSkiRank => 'Skidplacering';

  @override
  String get biathlonNetSkiRank => 'Netto skidplacering';

  @override
  String get biathlonShootingRank => 'Skjutplacering';

  @override
  String get biathlonRangeRank => 'Placering på skjutvallen';

  @override
  String get biathlonPenaltyRank => 'Straffplacering';

  @override
  String get biathlonFinishRank => 'Slutplacering';

  @override
  String get biathlonPassingTime => 'Passeringstid';

  @override
  String get biathlonSplitTime => 'Deltid';

  @override
  String get biathlonPassingRank => 'Placering vid passering';

  @override
  String get biathlonSplitRank => 'Delplacering';

  @override
  String get biathlonMissesLabel => 'Bom';

  @override
  String get biathlonRangeExitTime => 'Tid ut från skjutvallen';

  @override
  String get biathlonRangeApproach => 'Ankomst till skjutvallen';

  @override
  String get biathlonRangeEntry => 'In på skjutvallen';

  @override
  String get biathlonShootingDone => 'Skytte klart';

  @override
  String get biathlonShootingExit => 'Ut från skyttet';

  @override
  String get biathlonRangeExitTotal => 'Total tid ut från skjutvallen';

  @override
  String get biathlonCumulativeMisses => 'Bom hittills';

  @override
  String get biathlonStartTime => 'Starttid';

  @override
  String get biathlonDetailSelector =>
      'Fler mätningar: mellantider, skytte och varv';

  @override
  String get biathlonExtraDetails =>
      'Alla mellantider, skjutningar och skidvarv';

  @override
  String biathlonComparisonDescription(String group) {
    return 'Dina individuella lopp jämfört med $group i samma klass och tävlingsdel.';
  }

  @override
  String biathlonComparisonUnavailable(String metric, String group) {
    return 'Ingen jämförelse av $metric med $group ännu. Referensdata för denna mätning saknas.';
  }

  @override
  String get biathlonPercentDifferenceCaption =>
      'Skillnad i procentenheter · över linjen är bättre';

  @override
  String biathlonDifferenceCaption(String group) {
    return 'Skillnad från $group · över linjen är bättre';
  }

  @override
  String biathlonRaceLabel(String id) {
    return 'Lopp $id';
  }

  @override
  String biathlonCohortSummary(String group, int count, int total) {
    return '$group: $count av $total som gått i mål';
  }

  @override
  String biathlonShootingNumber(int index) {
    return 'Skjutning $index';
  }

  @override
  String biathlonSkiLap(int index) {
    return 'Skidvarv $index';
  }

  @override
  String biathlonOwnValue(String value) {
    return 'Du: $value';
  }

  @override
  String biathlonYourDifference(String value) {
    return 'Din skillnad: $value';
  }

  @override
  String biathlonDecimalMisses(String value) {
    return '$value bom';
  }

  @override
  String biathlonPercentagePoints(String value) {
    return '$value procentenheter';
  }

  @override
  String get biathlonAverageHitPercent => 'Genomsnittlig träffprocent';

  @override
  String get biathlonAverageHitExplanation =>
      'Dina fullföljda individuella skidskyttelopp. Varje lopp väger lika; saknade skjutdata utelämnas.';

  @override
  String get biathlonHitProne => 'Liggande';

  @override
  String get biathlonHitStanding => 'Stående';

  @override
  String get biathlonHitTotal => 'Totalt';

  @override
  String biathlonAverageRaceCount(int count) {
    return '$count lopp';
  }

  @override
  String get importWaiting => 'Väntar på resultat';

  @override
  String get importInProgress => 'Importerar';

  @override
  String get importPartial => 'Delvis importerat';

  @override
  String get importUpdated => 'Uppdaterat';

  @override
  String regressionCompareWith(String target) {
    return 'Jämför med: $target';
  }

  @override
  String get regressionChooseTarget => 'Välj jämförelse';

  @override
  String regressionSelectFromList(String subject) {
    return 'Välj ett jämförelsevärde i resultatlistan för $subject och tryck på OK.';
  }

  @override
  String get regressionCancel => 'Avbryt';

  @override
  String get regressionApply => 'OK';

  @override
  String get appTitle => 'Resultat';

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
  String get searchResults => 'Sök efter idrottare, klubb eller lag';

  @override
  String get athlete => 'Athlete';

  @override
  String get club => 'Club';

  @override
  String get shooting => 'Shooting';

  @override
  String biathlonShootingIn(int index) {
    return 'In till skjutning $index';
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
  String get biathlonRankUnavailable => 'Nr –';

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
      'Det gick inte att spara eller synkronisera inställningarna. Ditt val finns kvar.';

  @override
  String get settingsRetry => 'Försök igen';
}
