// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Norwegian Bokmål (`nb`).
class AppLocalizationsNb extends AppLocalizations {
  AppLocalizationsNb([String locale = 'nb']) : super(locale);

  @override
  String get biathlonStatistics => 'Skiskytterstatistikk';

  @override
  String get biathlonFinishTime => 'Sluttid';

  @override
  String get biathlonSkiTime => 'Skitid';

  @override
  String get biathlonShootingTime => 'Skytetid';

  @override
  String get biathlonHitProneLabel => 'Treff ligg';

  @override
  String get biathlonHitStandingLabel => 'Treff stå';

  @override
  String get biathlonHitTotalLabel => 'Treff totalt';

  @override
  String get biathlonAllFinishers => 'Alle fullførte';

  @override
  String get biathlonTopHalf => 'Topp 50 %';

  @override
  String get biathlonNetSkiTime => 'Netto skitid';

  @override
  String get biathlonPenaltyTime => 'Straffetid';

  @override
  String get biathlonRangeTime => 'Tid på standplass';

  @override
  String get biathlonProneTime => 'Tid liggende skyting';

  @override
  String get biathlonStandingTime => 'Tid stående skyting';

  @override
  String get biathlonTotalMisses => 'Bom totalt';

  @override
  String get biathlonProneMisses => 'Bom liggende';

  @override
  String get biathlonStandingMisses => 'Bom stående';

  @override
  String get biathlonSkiRank => 'Skiplass';

  @override
  String get biathlonNetSkiRank => 'Netto skiplass';

  @override
  String get biathlonShootingRank => 'Skyteplass';

  @override
  String get biathlonRangeRank => 'Standplassplass';

  @override
  String get biathlonPenaltyRank => 'Straffeplass';

  @override
  String get biathlonFinishRank => 'Sluttplass';

  @override
  String get biathlonPassingTime => 'Passeringstid';

  @override
  String get biathlonSplitTime => 'Deltid';

  @override
  String get biathlonPassingRank => 'Plass ved passering';

  @override
  String get biathlonSplitRank => 'Delplass';

  @override
  String get biathlonMissesLabel => 'Bom';

  @override
  String get biathlonRangeExitTime => 'Tid ut fra standplass';

  @override
  String get biathlonRangeApproach => 'Ankomst standplass';

  @override
  String get biathlonRangeEntry => 'Inn på standplass';

  @override
  String get biathlonShootingDone => 'Skyting ferdig';

  @override
  String get biathlonShootingExit => 'Ut fra skyting';

  @override
  String get biathlonRangeExitTotal => 'Ut fra standplass totalt';

  @override
  String get biathlonCumulativeMisses => 'Bom hittil';

  @override
  String get biathlonStartTime => 'Starttid';

  @override
  String get biathlonDetailSelector =>
      'Flere målinger: splitter, skyting og runder';

  @override
  String get biathlonExtraDetails => 'Alle splitter, skytinger og skirunder';

  @override
  String biathlonComparisonDescription(String group) {
    return 'Dine individuelle løp mot $group i samme klasse og konkurranseledd.';
  }

  @override
  String biathlonComparisonUnavailable(String metric, String group) {
    return 'Ingen sammenligning av $metric mot $group ennå. Referansedata for denne målingen er ikke tilgjengelige.';
  }

  @override
  String get biathlonPercentDifferenceCaption =>
      'Forskjell i prosentpoeng · over linjen er bedre';

  @override
  String biathlonDifferenceCaption(String group) {
    return 'Forskjell fra $group · over linjen er bedre';
  }

  @override
  String biathlonRaceLabel(String id) {
    return 'Løp $id';
  }

  @override
  String biathlonCohortSummary(String group, int count, int total) {
    return '$group: $count av $total fullførte';
  }

  @override
  String biathlonShootingNumber(int index) {
    return 'Skyting $index';
  }

  @override
  String biathlonSkiLap(int index) {
    return 'Skirunde $index';
  }

  @override
  String biathlonOwnValue(String value) {
    return 'Du: $value';
  }

  @override
  String biathlonYourDifference(String value) {
    return 'Din forskjell: $value';
  }

  @override
  String biathlonDecimalMisses(String value) {
    return '$value bom';
  }

  @override
  String biathlonPercentagePoints(String value) {
    return '$value prosentpoeng';
  }

  @override
  String get biathlonAverageHitPercent => 'Gjennomsnittlig treffprosent';

  @override
  String get biathlonAverageHitExplanation =>
      'Dine fullførte individuelle skiskytingsløp. Hvert løp teller likt; manglende skytingsdata utelates.';

  @override
  String get biathlonHitProne => 'Liggende';

  @override
  String get biathlonHitStanding => 'Stående';

  @override
  String get biathlonHitTotal => 'Totalt';

  @override
  String biathlonAverageRaceCount(int count) {
    return '$count løp';
  }

  @override
  String get importWaiting => 'Venter på resultater';

  @override
  String get importInProgress => 'Importerer';

  @override
  String get importPartial => 'Delvis importert';

  @override
  String get importUpdated => 'Oppdatert';

  @override
  String regressionCompareWith(String target) {
    return 'Sammenlign med: $target';
  }

  @override
  String get regressionChooseTarget => 'Velg sammenligning';

  @override
  String regressionSelectFromList(String subject) {
    return 'Velg sammenligningsverdi i resultatlisten for $subject, og trykk OK.';
  }

  @override
  String get regressionCancel => 'Avbryt';

  @override
  String get regressionApply => 'OK';

  @override
  String get appTitle => 'Resultater';

  @override
  String get eventsTitle => 'Velg et event';

  @override
  String get eventsSubtitle => 'Finn et event og åpne resultatlisten.';

  @override
  String get searchEvents => 'Søk i events';

  @override
  String get login => 'Logg inn';

  @override
  String get logout => 'Logg ut';

  @override
  String get account => 'Konto';

  @override
  String get settings => 'Innstillinger';

  @override
  String get language => 'Språk';

  @override
  String get tableDensity => 'Tabelltetthet';

  @override
  String get comfortable => 'Luftig';

  @override
  String get compact => 'Kompakt';

  @override
  String get noEventsTitle => 'Ingen events';

  @override
  String get noEventsMessage => 'Importer et EQ Timing-event først.';

  @override
  String get couldNotReadEvents => 'Kunne ikke lese events';

  @override
  String get couldNotReadResults => 'Kunne ikke lese resultater';

  @override
  String get loadingEvents => 'Laster events';

  @override
  String get loadingResults => 'Laster resultater';

  @override
  String get results => 'Resultater';

  @override
  String get classes => 'Klasser';

  @override
  String get classLabel => 'Klasse';

  @override
  String get split => 'Split';

  @override
  String get searchResults => 'Søk etter utøver, klubb eller team';

  @override
  String get athlete => 'Utøver';

  @override
  String get club => 'Klubb';

  @override
  String get shooting => 'Skyting';

  @override
  String biathlonShootingIn(int index) {
    return 'Inn skyting $index';
  }

  @override
  String get biathlonPositionProne => 'liggende';

  @override
  String get biathlonPositionStanding => 'stående';

  @override
  String get biathlonPositionUnknown => 'ukjent stilling';

  @override
  String biathlonMisses(int count) {
    return '$count bom';
  }

  @override
  String biathlonPenalty(String time) {
    return 'Straff $time';
  }

  @override
  String biathlonRankNumber(int rank) {
    return 'Nr $rank';
  }

  @override
  String get biathlonRankUnavailable => 'Nr –';

  @override
  String get time => 'Tid';

  @override
  String get gap => 'Gap';

  @override
  String get place => 'Plass';

  @override
  String get bib => 'Startnr.';

  @override
  String get date => 'Dato';

  @override
  String get sport => 'Idrett';

  @override
  String get eventId => 'Event ID';

  @override
  String get noClassesTitle => 'Ingen klasser';

  @override
  String get noClassesMessage => 'Importen har ikke skrevet klasse-data enda.';

  @override
  String get noResultsTitle => 'Ingen resultater';

  @override
  String get noResultsMessage => 'Klassen har ingen tidsrader enda.';

  @override
  String get athleteDetails => 'Utøverdetaljer';

  @override
  String get splitBreakdown => 'Splitoversikt';

  @override
  String get backToResults => 'Tilbake til resultater';

  @override
  String get email => 'E-post';

  @override
  String get password => 'Passord';

  @override
  String get signInWithGoogle => 'Fortsett med Google';

  @override
  String get signInWithEmail => 'Logg inn med e-post';

  @override
  String get createAccount => 'Opprett konto';

  @override
  String get connectAthlete => 'Koble til utøver';

  @override
  String get connectAthleteDescription =>
      'Søk på fullt navn for å koble kontoen din til riktig utøver.';

  @override
  String get connectAthleteOnboardingTitle => 'Finn utøveren din';

  @override
  String get connectAthleteOnboardingDescription =>
      'Koble kontoen din til egne resultater, eller velg Ikke nå.';

  @override
  String get fullName => 'Fullt navn';

  @override
  String get findAthlete => 'Finn utøver';

  @override
  String get noAthleteMatches => 'Fant ingen utøver med dette fulle navnet.';

  @override
  String get notNow => 'Ikke nå';

  @override
  String get enterFullName => 'Skriv inn fullt navn først.';

  @override
  String athleteLinked(String name) {
    return '$name er koblet til kontoen';
  }

  @override
  String get couldNotReadAthleteLink => 'Kunne ikke lese utøverkoblingen';

  @override
  String get settingsSyncFailed =>
      'Kunne ikke lagre eller synkronisere innstillingene. Valget ditt er fortsatt valgt.';

  @override
  String get settingsRetry => 'Prøv igjen';
}
