// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Estonian (`et`).
class AppLocalizationsEt extends AppLocalizations {
  AppLocalizationsEt([String locale = 'et']) : super(locale);

  @override
  String get biathlonStatistics => 'Laskesuusatamise statistika';

  @override
  String get biathlonFinishTime => 'Lõppaeg';

  @override
  String get biathlonSkiTime => 'Suusaaeg';

  @override
  String get biathlonShootingTime => 'Laskeaeg';

  @override
  String get biathlonHitProneLabel => 'Lamades tabamusprotsent';

  @override
  String get biathlonHitStandingLabel => 'Püsti tabamusprotsent';

  @override
  String get biathlonHitTotalLabel => 'Tabamusprotsent kokku';

  @override
  String get biathlonAllFinishers => 'Kõik lõpetanud';

  @override
  String get biathlonTopHalf => 'Parimad 50 %';

  @override
  String get biathlonNetSkiTime => 'Puhas suusaaeg';

  @override
  String get biathlonPenaltyTime => 'Trahviaeg';

  @override
  String get biathlonRangeTime => 'Aeg lasketiirus';

  @override
  String get biathlonProneTime => 'Lamades laskeaeg';

  @override
  String get biathlonStandingTime => 'Püsti laskeaeg';

  @override
  String get biathlonTotalMisses => 'Möödalasud kokku';

  @override
  String get biathlonProneMisses => 'Lamades möödalasud';

  @override
  String get biathlonStandingMisses => 'Püsti möödalasud';

  @override
  String get biathlonSkiRank => 'Suusatamise koht';

  @override
  String get biathlonNetSkiRank => 'Puhta suusaaja koht';

  @override
  String get biathlonShootingRank => 'Laskmise koht';

  @override
  String get biathlonRangeRank => 'Lasketiiru koht';

  @override
  String get biathlonPenaltyRank => 'Trahviaja koht';

  @override
  String get biathlonFinishRank => 'Lõppkoht';

  @override
  String get biathlonPassingTime => 'Läbimise aeg';

  @override
  String get biathlonSplitTime => 'Vaheaeg';

  @override
  String get biathlonPassingRank => 'Koht läbimisel';

  @override
  String get biathlonSplitRank => 'Lõigu koht';

  @override
  String get biathlonMissesLabel => 'Möödalasud';

  @override
  String get biathlonRangeExitTime => 'Lasketiirust väljumise aeg';

  @override
  String get biathlonRangeApproach => 'Lasketiiru saabumine';

  @override
  String get biathlonRangeEntry => 'Lasketiiru sisenemine';

  @override
  String get biathlonShootingDone => 'Laskmine lõpetatud';

  @override
  String get biathlonShootingExit => 'Laskmisest väljumine';

  @override
  String get biathlonRangeExitTotal => 'Koguaeg lasketiirust väljumiseni';

  @override
  String get biathlonCumulativeMisses => 'Senised möödalasud';

  @override
  String get biathlonStartTime => 'Stardiaeg';

  @override
  String get biathlonDetailSelector =>
      'Veel mõõdikuid: vaheajad, laskmine ja ringid';

  @override
  String get biathlonExtraDetails => 'Kõik vaheajad, laskmised ja suusaringid';

  @override
  String biathlonComparisonDescription(String group) {
    return 'Sinu individuaalsed võistlused võrreldes rühmaga $group samas klassis ja etapis.';
  }

  @override
  String biathlonComparisonUnavailable(String metric, String group) {
    return 'Mõõdiku $metric võrdlus rühmaga $group puudub. Selle mõõdiku võrdlusandmed pole saadaval.';
  }

  @override
  String get biathlonPercentDifferenceCaption =>
      'Erinevus protsendipunktides · joone kohal on parem';

  @override
  String biathlonDifferenceCaption(String group) {
    return 'Erinevus rühmast $group · joone kohal on parem';
  }

  @override
  String biathlonRaceLabel(String id) {
    return 'Võistlus $id';
  }

  @override
  String biathlonCohortSummary(String group, int count, int total) {
    return '$group: $count lõpetanut $total-st';
  }

  @override
  String biathlonShootingNumber(int index) {
    return 'Laskmine $index';
  }

  @override
  String biathlonSkiLap(int index) {
    return 'Suusaring $index';
  }

  @override
  String biathlonOwnValue(String value) {
    return 'Sina: $value';
  }

  @override
  String biathlonYourDifference(String value) {
    return 'Sinu erinevus: $value';
  }

  @override
  String biathlonDecimalMisses(String value) {
    return '$value möödalasku';
  }

  @override
  String biathlonPercentagePoints(String value) {
    return '$value protsendipunkti';
  }

  @override
  String get biathlonAverageHitPercent => 'Keskmine tabamusprotsent';

  @override
  String get biathlonAverageHitExplanation =>
      'Sinu lõpetatud individuaalsed laskesuusavõistlused. Igal võistlusel on võrdne kaal; puuduvad laskeandmed jäetakse välja.';

  @override
  String get biathlonHitProne => 'Lamades';

  @override
  String get biathlonHitStanding => 'Püsti';

  @override
  String get biathlonHitTotal => 'Kokku';

  @override
  String biathlonAverageRaceCount(int count) {
    return '$count võistlust';
  }

  @override
  String get importWaiting => 'Tulemuste ootel';

  @override
  String get importInProgress => 'Importimine';

  @override
  String get importPartial => 'Osaliselt imporditud';

  @override
  String get importUpdated => 'Uuendatud';

  @override
  String regressionCompareWith(String target) {
    return 'Võrdle: $target';
  }

  @override
  String get regressionChooseTarget => 'Vali võrdlus';

  @override
  String regressionSelectFromList(String subject) {
    return 'Vali tulemuste loendist väärtus, mida võrrelda näitajaga $subject, seejärel vajuta OK.';
  }

  @override
  String get regressionCancel => 'Tühista';

  @override
  String get regressionApply => 'OK';

  @override
  String get appTitle => 'Tulemused';

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
  String get searchResults => 'Otsi sportlast, klubi või meeskonda';

  @override
  String get athlete => 'Athlete';

  @override
  String get club => 'Club';

  @override
  String get shooting => 'Shooting';

  @override
  String biathlonShootingIn(int index) {
    return 'Laskmisele $index';
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
      'Seadeid ei saanud salvestada ega sünkroonida. Sinu valik jääb kehtima.';

  @override
  String get settingsRetry => 'Proovi uuesti';
}
