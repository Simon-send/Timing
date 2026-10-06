// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get biathlonStatistics => 'Biathlonstatistik';

  @override
  String get biathlonFinishTime => 'Zielzeit';

  @override
  String get biathlonSkiTime => 'Laufzeit';

  @override
  String get biathlonShootingTime => 'Schießzeit';

  @override
  String get biathlonHitProneLabel => 'Trefferquote liegend';

  @override
  String get biathlonHitStandingLabel => 'Trefferquote stehend';

  @override
  String get biathlonHitTotalLabel => 'Trefferquote gesamt';

  @override
  String get biathlonAllFinishers => 'Alle Finisher';

  @override
  String get biathlonTopHalf => 'Beste 50 %';

  @override
  String get biathlonNetSkiTime => 'Netto-Laufzeit';

  @override
  String get biathlonPenaltyTime => 'Strafzeit';

  @override
  String get biathlonRangeTime => 'Zeit am Schießstand';

  @override
  String get biathlonProneTime => 'Schießzeit liegend';

  @override
  String get biathlonStandingTime => 'Schießzeit stehend';

  @override
  String get biathlonTotalMisses => 'Fehlschüsse gesamt';

  @override
  String get biathlonProneMisses => 'Fehlschüsse liegend';

  @override
  String get biathlonStandingMisses => 'Fehlschüsse stehend';

  @override
  String get biathlonSkiRank => 'Laufplatzierung';

  @override
  String get biathlonNetSkiRank => 'Netto-Laufplatzierung';

  @override
  String get biathlonShootingRank => 'Schießplatzierung';

  @override
  String get biathlonRangeRank => 'Schießstandplatzierung';

  @override
  String get biathlonPenaltyRank => 'Strafzeitplatzierung';

  @override
  String get biathlonFinishRank => 'Zielplatzierung';

  @override
  String get biathlonPassingTime => 'Durchgangszeit';

  @override
  String get biathlonSplitTime => 'Abschnittszeit';

  @override
  String get biathlonPassingRank => 'Platz beim Durchgang';

  @override
  String get biathlonSplitRank => 'Abschnittsplatz';

  @override
  String get biathlonMissesLabel => 'Fehlschüsse';

  @override
  String get biathlonRangeExitTime => 'Zeit bis zum Verlassen des Schießstands';

  @override
  String get biathlonRangeApproach => 'Ankunft am Schießstand';

  @override
  String get biathlonRangeEntry => 'Eintritt in den Schießstand';

  @override
  String get biathlonShootingDone => 'Schießen beendet';

  @override
  String get biathlonShootingExit => 'Verlassen des Schießbereichs';

  @override
  String get biathlonRangeExitTotal =>
      'Gesamtzeit bis zum Verlassen des Schießstands';

  @override
  String get biathlonCumulativeMisses => 'Bisherige Fehlschüsse';

  @override
  String get biathlonStartTime => 'Startzeit';

  @override
  String get biathlonDetailSelector =>
      'Weitere Messwerte: Zwischenzeiten, Schießen und Runden';

  @override
  String get biathlonExtraDetails =>
      'Alle Zwischenzeiten, Schießeinlagen und Laufrunden';

  @override
  String biathlonComparisonDescription(String group) {
    return 'Deine Einzelrennen im Vergleich mit $group in derselben Klasse und Wettkampfstufe.';
  }

  @override
  String biathlonComparisonUnavailable(String metric, String group) {
    return 'Noch kein Vergleich von $metric mit $group. Referenzdaten für diese Messung sind nicht verfügbar.';
  }

  @override
  String get biathlonPercentDifferenceCaption =>
      'Differenz in Prozentpunkten · oberhalb der Linie ist besser';

  @override
  String biathlonDifferenceCaption(String group) {
    return 'Differenz zu $group · oberhalb der Linie ist besser';
  }

  @override
  String biathlonRaceLabel(String id) {
    return 'Rennen $id';
  }

  @override
  String biathlonCohortSummary(String group, int count, int total) {
    return '$group: $count von $total Finishern';
  }

  @override
  String biathlonShootingNumber(int index) {
    return 'Schießen $index';
  }

  @override
  String biathlonSkiLap(int index) {
    return 'Laufrunde $index';
  }

  @override
  String biathlonOwnValue(String value) {
    return 'Du: $value';
  }

  @override
  String biathlonYourDifference(String value) {
    return 'Deine Differenz: $value';
  }

  @override
  String biathlonDecimalMisses(String value) {
    return '$value Fehlschüsse';
  }

  @override
  String biathlonPercentagePoints(String value) {
    return '$value Prozentpunkte';
  }

  @override
  String get biathlonAverageHitPercent => 'Durchschnittliche Trefferquote';

  @override
  String get biathlonAverageHitExplanation =>
      'Deine abgeschlossenen Einzelrennen im Biathlon. Jedes Rennen zählt gleich; fehlende Schießdaten werden ausgelassen.';

  @override
  String get biathlonHitProne => 'Liegend';

  @override
  String get biathlonHitStanding => 'Stehend';

  @override
  String get biathlonHitTotal => 'Gesamt';

  @override
  String biathlonAverageRaceCount(int count) {
    return '$count Rennen';
  }

  @override
  String get importWaiting => 'Warten auf Ergebnisse';

  @override
  String get importInProgress => 'Import läuft';

  @override
  String get importPartial => 'Teilweise importiert';

  @override
  String get importUpdated => 'Aktualisiert';

  @override
  String regressionCompareWith(String target) {
    return 'Vergleichen mit: $target';
  }

  @override
  String get regressionChooseTarget => 'Vergleich auswählen';

  @override
  String regressionSelectFromList(String subject) {
    return 'Wählen Sie den Vergleichswert in der Ergebnisliste für $subject, dann OK.';
  }

  @override
  String get regressionCancel => 'Abbrechen';

  @override
  String get regressionApply => 'OK';

  @override
  String get appTitle => 'Ergebnisse';

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
  String get searchResults => 'Athlet, Verein oder Team suchen';

  @override
  String get athlete => 'Athlete';

  @override
  String get club => 'Club';

  @override
  String get shooting => 'Shooting';

  @override
  String biathlonShootingIn(int index) {
    return 'Zum Schießen $index';
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
  String get biathlonRankUnavailable => 'Nr. –';

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
      'Die Einstellungen konnten nicht gespeichert oder synchronisiert werden. Ihre Auswahl bleibt bestehen.';

  @override
  String get settingsRetry => 'Erneut versuchen';
}
