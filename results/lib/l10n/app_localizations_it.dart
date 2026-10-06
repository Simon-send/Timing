// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get biathlonStatistics => 'Statistiche di biathlon';

  @override
  String get biathlonFinishTime => 'Tempo finale';

  @override
  String get biathlonSkiTime => 'Tempo di sci';

  @override
  String get biathlonShootingTime => 'Tempo di tiro';

  @override
  String get biathlonHitProneLabel => 'Percentuale di colpi a terra';

  @override
  String get biathlonHitStandingLabel => 'Percentuale di colpi in piedi';

  @override
  String get biathlonHitTotalLabel => 'Percentuale totale di colpi';

  @override
  String get biathlonAllFinishers => 'Tutti gli arrivati';

  @override
  String get biathlonTopHalf => 'Miglior 50 %';

  @override
  String get biathlonNetSkiTime => 'Tempo netto di sci';

  @override
  String get biathlonPenaltyTime => 'Tempo di penalità';

  @override
  String get biathlonRangeTime => 'Tempo al poligono';

  @override
  String get biathlonProneTime => 'Tempo di tiro a terra';

  @override
  String get biathlonStandingTime => 'Tempo di tiro in piedi';

  @override
  String get biathlonTotalMisses => 'Errori totali';

  @override
  String get biathlonProneMisses => 'Errori a terra';

  @override
  String get biathlonStandingMisses => 'Errori in piedi';

  @override
  String get biathlonSkiRank => 'Posizione nello sci';

  @override
  String get biathlonNetSkiRank => 'Posizione nello sci netto';

  @override
  String get biathlonShootingRank => 'Posizione nel tiro';

  @override
  String get biathlonRangeRank => 'Posizione al poligono';

  @override
  String get biathlonPenaltyRank => 'Posizione nelle penalità';

  @override
  String get biathlonFinishRank => 'Posizione finale';

  @override
  String get biathlonPassingTime => 'Tempo di passaggio';

  @override
  String get biathlonSplitTime => 'Tempo parziale';

  @override
  String get biathlonPassingRank => 'Posizione al passaggio';

  @override
  String get biathlonSplitRank => 'Posizione nel parziale';

  @override
  String get biathlonMissesLabel => 'Errori';

  @override
  String get biathlonRangeExitTime => 'Tempo di uscita dal poligono';

  @override
  String get biathlonRangeApproach => 'Arrivo al poligono';

  @override
  String get biathlonRangeEntry => 'Ingresso al poligono';

  @override
  String get biathlonShootingDone => 'Tiro completato';

  @override
  String get biathlonShootingExit => 'Uscita dal tiro';

  @override
  String get biathlonRangeExitTotal => 'Tempo totale all’uscita dal poligono';

  @override
  String get biathlonCumulativeMisses => 'Errori accumulati';

  @override
  String get biathlonStartTime => 'Ora di partenza';

  @override
  String get biathlonDetailSelector => 'Altre misure: parziali, tiro e giri';

  @override
  String get biathlonExtraDetails =>
      'Tutti i parziali, le serie di tiro e i giri di sci';

  @override
  String biathlonComparisonDescription(String group) {
    return 'Le tue gare individuali confrontate con $group nella stessa categoria e fase.';
  }

  @override
  String biathlonComparisonUnavailable(String metric, String group) {
    return 'Confronto di $metric con $group non ancora disponibile. Mancano i dati di riferimento per questa misura.';
  }

  @override
  String get biathlonPercentDifferenceCaption =>
      'Differenza in punti percentuali · sopra la linea è meglio';

  @override
  String biathlonDifferenceCaption(String group) {
    return 'Differenza rispetto a $group · sopra la linea è meglio';
  }

  @override
  String biathlonRaceLabel(String id) {
    return 'Gara $id';
  }

  @override
  String biathlonCohortSummary(String group, int count, int total) {
    return '$group: $count su $total arrivati';
  }

  @override
  String biathlonShootingNumber(int index) {
    return 'Tiro $index';
  }

  @override
  String biathlonSkiLap(int index) {
    return 'Giro di sci $index';
  }

  @override
  String biathlonOwnValue(String value) {
    return 'Tu: $value';
  }

  @override
  String biathlonYourDifference(String value) {
    return 'La tua differenza: $value';
  }

  @override
  String biathlonDecimalMisses(String value) {
    return '$value errori';
  }

  @override
  String biathlonPercentagePoints(String value) {
    return '$value punti percentuali';
  }

  @override
  String get biathlonAverageHitPercent => 'Percentuale media di precisione';

  @override
  String get biathlonAverageHitExplanation =>
      'Le tue gare individuali di biathlon completate. Ogni gara ha lo stesso peso; i dati di tiro mancanti sono esclusi.';

  @override
  String get biathlonHitProne => 'A terra';

  @override
  String get biathlonHitStanding => 'In piedi';

  @override
  String get biathlonHitTotal => 'Totale';

  @override
  String biathlonAverageRaceCount(int count) {
    return '$count gare';
  }

  @override
  String get importWaiting => 'In attesa dei risultati';

  @override
  String get importInProgress => 'Importazione in corso';

  @override
  String get importPartial => 'Importazione parziale';

  @override
  String get importUpdated => 'Aggiornato';

  @override
  String regressionCompareWith(String target) {
    return 'Confronta con: $target';
  }

  @override
  String get regressionChooseTarget => 'Scegli il confronto';

  @override
  String regressionSelectFromList(String subject) {
    return 'Scegli un valore da confrontare con $subject nell\'elenco dei risultati, poi premi OK.';
  }

  @override
  String get regressionCancel => 'Annulla';

  @override
  String get regressionApply => 'OK';

  @override
  String get appTitle => 'Risultati';

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
  String get searchResults => 'Cerca atleta, club o squadra';

  @override
  String get athlete => 'Athlete';

  @override
  String get club => 'Club';

  @override
  String get shooting => 'Shooting';

  @override
  String biathlonShootingIn(int index) {
    return 'Ingresso al tiro $index';
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
  String get biathlonRankUnavailable => 'N. –';

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
      'Impossibile salvare o sincronizzare le impostazioni. La tua scelta rimane selezionata.';

  @override
  String get settingsRetry => 'Riprova';
}
