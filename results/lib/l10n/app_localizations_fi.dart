// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Finnish (`fi`).
class AppLocalizationsFi extends AppLocalizations {
  AppLocalizationsFi([String locale = 'fi']) : super(locale);

  @override
  String get biathlonStatistics => 'Ampumahiihtotilastot';

  @override
  String get biathlonFinishTime => 'Loppuaika';

  @override
  String get biathlonSkiTime => 'Hiihtoaika';

  @override
  String get biathlonShootingTime => 'Ampuma-aika';

  @override
  String get biathlonHitProneLabel => 'Makuuosumaprosentti';

  @override
  String get biathlonHitStandingLabel => 'Pystyosumaprosentti';

  @override
  String get biathlonHitTotalLabel => 'Kokonaisosumaprosentti';

  @override
  String get biathlonAllFinishers => 'Kaikki maaliin tulleet';

  @override
  String get biathlonTopHalf => 'Paras 50 %';

  @override
  String get biathlonNetSkiTime => 'Nettohiihtoaika';

  @override
  String get biathlonPenaltyTime => 'Sakkoaika';

  @override
  String get biathlonRangeTime => 'Aika ampumapaikalla';

  @override
  String get biathlonProneTime => 'Makuuammunnan aika';

  @override
  String get biathlonStandingTime => 'Pystyammunnan aika';

  @override
  String get biathlonTotalMisses => 'Ohilaukaukset yhteensä';

  @override
  String get biathlonProneMisses => 'Makuuammunnan ohilaukaukset';

  @override
  String get biathlonStandingMisses => 'Pystyammunnan ohilaukaukset';

  @override
  String get biathlonSkiRank => 'Hiihtosijoitus';

  @override
  String get biathlonNetSkiRank => 'Nettohiihtosijoitus';

  @override
  String get biathlonShootingRank => 'Ampumasijoitus';

  @override
  String get biathlonRangeRank => 'Ampumapaikan sijoitus';

  @override
  String get biathlonPenaltyRank => 'Sakkoajan sijoitus';

  @override
  String get biathlonFinishRank => 'Loppusijoitus';

  @override
  String get biathlonPassingTime => 'Ohitusaika';

  @override
  String get biathlonSplitTime => 'Väliaika';

  @override
  String get biathlonPassingRank => 'Sijoitus ohituksessa';

  @override
  String get biathlonSplitRank => 'Osuussijoitus';

  @override
  String get biathlonMissesLabel => 'Ohilaukaukset';

  @override
  String get biathlonRangeExitTime => 'Ampumapaikalta poistumisaika';

  @override
  String get biathlonRangeApproach => 'Saapuminen ampumapaikalle';

  @override
  String get biathlonRangeEntry => 'Ampumapaikalle tulo';

  @override
  String get biathlonShootingDone => 'Ammunta valmis';

  @override
  String get biathlonShootingExit => 'Poistuminen ammunnasta';

  @override
  String get biathlonRangeExitTotal =>
      'Kokonaisaika ampumapaikalta poistumiseen';

  @override
  String get biathlonCumulativeMisses => 'Ohilaukaukset tähän asti';

  @override
  String get biathlonStartTime => 'Lähtöaika';

  @override
  String get biathlonDetailSelector =>
      'Lisää mittareita: väliajat, ammunnat ja kierrokset';

  @override
  String get biathlonExtraDetails =>
      'Kaikki väliajat, ammunnat ja hiihtokierrokset';

  @override
  String biathlonComparisonDescription(String group) {
    return 'Omat yksilökilpailusi verrattuna ryhmään $group samassa sarjassa ja kilpailuvaiheessa.';
  }

  @override
  String biathlonComparisonUnavailable(String metric, String group) {
    return 'Mittarin $metric vertailu ryhmään $group ei ole vielä saatavilla. Tämän mittarin vertailutiedot puuttuvat.';
  }

  @override
  String get biathlonPercentDifferenceCaption =>
      'Ero prosenttiyksikköinä · viivan yläpuolella on parempi';

  @override
  String biathlonDifferenceCaption(String group) {
    return 'Ero ryhmään $group · viivan yläpuolella on parempi';
  }

  @override
  String biathlonRaceLabel(String id) {
    return 'Kilpailu $id';
  }

  @override
  String biathlonCohortSummary(String group, int count, int total) {
    return '$group: $count maaliin tullutta $total:stä';
  }

  @override
  String biathlonShootingNumber(int index) {
    return 'Ammunta $index';
  }

  @override
  String biathlonSkiLap(int index) {
    return 'Hiihtokierros $index';
  }

  @override
  String biathlonOwnValue(String value) {
    return 'Sinä: $value';
  }

  @override
  String biathlonYourDifference(String value) {
    return 'Oma erosi: $value';
  }

  @override
  String biathlonDecimalMisses(String value) {
    return '$value ohilaukausta';
  }

  @override
  String biathlonPercentagePoints(String value) {
    return '$value prosenttiyksikköä';
  }

  @override
  String get biathlonAverageHitPercent => 'Keskimääräinen osumaprosentti';

  @override
  String get biathlonAverageHitExplanation =>
      'Loppuun suoritetut henkilökohtaiset ampumahiihtokilpailusi. Jokaisella kilpailulla on sama paino; puuttuvat ammuntatiedot jätetään pois.';

  @override
  String get biathlonHitProne => 'Makuu';

  @override
  String get biathlonHitStanding => 'Pysty';

  @override
  String get biathlonHitTotal => 'Yhteensä';

  @override
  String biathlonAverageRaceCount(int count) {
    return '$count kilpailua';
  }

  @override
  String get importWaiting => 'Odotetaan tuloksia';

  @override
  String get importInProgress => 'Tuodaan';

  @override
  String get importPartial => 'Osittain tuotu';

  @override
  String get importUpdated => 'Päivitetty';

  @override
  String regressionCompareWith(String target) {
    return 'Vertaa kohteeseen: $target';
  }

  @override
  String get regressionChooseTarget => 'Valitse vertailu';

  @override
  String regressionSelectFromList(String subject) {
    return 'Valitse tulosluettelosta vertailuarvo kohteelle $subject ja paina OK.';
  }

  @override
  String get regressionCancel => 'Peruuta';

  @override
  String get regressionApply => 'OK';

  @override
  String get appTitle => 'Tulokset';

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
  String get searchResults => 'Hae urheilijaa, seuraa tai joukkuetta';

  @override
  String get athlete => 'Athlete';

  @override
  String get club => 'Club';

  @override
  String get shooting => 'Shooting';

  @override
  String biathlonShootingIn(int index) {
    return 'Ampumapaikalle $index';
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
  String get biathlonRankUnavailable => 'Nro –';

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
      'Asetuksia ei voitu tallentaa tai synkronoida. Valintasi säilyy.';

  @override
  String get settingsRetry => 'Yritä uudelleen';
}
