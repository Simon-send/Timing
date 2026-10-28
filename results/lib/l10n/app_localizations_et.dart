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

  @override
  String get seasonTitle => 'Hooajad';

  @override
  String get seasonAll => 'Kõik hooajad';

  @override
  String get seasonUnknown => 'Teadmata hooaeg';

  @override
  String seasonRaceCount(int count) {
    return '$count võistlust';
  }

  @override
  String seasonCompletedCount(int count) {
    return '$count lõpetatud võistlust';
  }

  @override
  String seasonObservationCount(int count) {
    return '$count kehtivat vaatlust';
  }

  @override
  String seasonUnassignedNotice(int count) {
    return '$count võistlusel puudub hooaeg. Need jäävad nimekirja; statistikas kaasamiseks vali Kõik hooajad.';
  }

  @override
  String get seasonStatisticsHint =>
      'Statistika ei hõlma lõpetamata võistlusi ega puuduvaid mõõtmisi.';

  @override
  String get shootingSelectionTitle => 'Valitud laskmised';

  @override
  String get shootingMetric => 'Mõõdik';

  @override
  String get shootingSelection => 'Laskmised';

  @override
  String get shootingAll => 'Kõik laskmised';

  @override
  String get shootingFirstProne => '1. lamades';

  @override
  String get shootingSecondProne => '2. lamades';

  @override
  String get shootingFirstStanding => '1. püsti';

  @override
  String get shootingSecondStanding => '2. püsti';

  @override
  String get shootingHits => 'Tabamused';

  @override
  String shootingValidCount(int valid, int count) {
    return '$valid laskmisel $count-st on mõõtmistulemus';
  }

  @override
  String get shootingNoMatch => 'Vastavat laskmist pole salvestatud.';

  @override
  String get shootingAmbiguous =>
      'Varasemad laskmised puuduvad või nende asend on teadmata. Järjekorranumbrit ei saa määrata.';

  @override
  String get shootingIncomplete =>
      'Mõned laskmised, asendid või mõõtmised puuduvad.';

  @override
  String get shootingRelayUnavailable =>
      'Tabamused ja möödalasud pole saadaval: teatevõistluse andmed ei erista varupadruneid trahviringidest. Lasketiiru aeg kuvatakse, kui see on salvestatud.';

  @override
  String get shootingExcluded => 'See tulemus on statistikast välja jäetud.';

  @override
  String get shootingRelayPositionsUnavailable =>
      'Laskmisasendid pole terve teatevõistkonna kohta saadaval. Salvestatud lasketiiruaegade nägemiseks vali Kõik laskmised.';

  @override
  String get seasonShootingTitle => 'Hooaja laskestatistika';

  @override
  String get seasonShootingExplanation =>
      'Valitud laskmiste kohta. Tabamusprotsent kasutab teadaolevaid viielasulisi seeriaid; teatesõidu lasud on välja jäetud. Arvud hõlmavad ainult salvestatud seeriaid. Puuduvaid seeriaid ja ebaselget järjekorda ei oletata.';

  @override
  String get seasonShootingHitPercent => 'Tabamusprotsent';

  @override
  String get seasonShootingAverageMisses => 'Keskmine möödalaskude arv seerias';

  @override
  String get seasonShootingMeanRangeTime => 'Keskmine lasketiiruaeg';

  @override
  String get seasonShootingMedianRangeTime => 'Lasketiiruaja mediaan';

  @override
  String seasonShootingCoverage(int valid, int missing) {
    return '$valid kehtivat seeriat · $missing puuduvat mõõtmist';
  }

  @override
  String seasonShootingUnavailableRaces(int count) {
    return 'Võistlused ilma valitavate salvestatud seeriateta: $count';
  }

  @override
  String seasonShootingKnownShots(int hits, int shots) {
    return '$hits tabamust / $shots teadaolevat lasku';
  }

  @override
  String get seasonDistributionTitle => 'Hooaja jaotus';

  @override
  String seasonDistributionSeriesCount(int count) {
    return 'n = $count mõõdetud seeriat · iga vaatlus on üks seeria';
  }

  @override
  String seasonDistributionSeconds(String value) {
    return '$value s';
  }

  @override
  String get seasonDistributionEmpty =>
      'Selle valiku jaoks pole kehtivaid mõõtmisi.';

  @override
  String get seasonDistributionLowData =>
      'Väga vähe andmeid: alla 5 seeria. Tõlgenda jaotust ettevaatlikult.';

  @override
  String seasonDistributionMean(String value) {
    return 'Keskmine: $value';
  }

  @override
  String seasonDistributionMedian(String value) {
    return 'Mediaan: $value';
  }

  @override
  String get seasonDistributionShowChart => 'Näita diagrammi';

  @override
  String get seasonDistributionShowTable => 'Näita ligipääsetavat tabelit';

  @override
  String get seasonDistributionCount => 'Arv';

  @override
  String get seasonDistributionShare => 'Osakaal';

  @override
  String get seasonDistributionSelectBin =>
      'Vali tulp või vahemik, et näha sellesse kuuluvaid võistlusi ja seeriaid.';

  @override
  String seasonDistributionIntervals(int count) {
    return 'Soovitud vahemike arv: $count';
  }

  @override
  String get seasonDistributionContributions =>
      'Jaotusse kuuluvad võistlused ja seeriad';

  @override
  String get seasonDistributionNoContributions =>
      'Selles vahemikus pole seeriaid.';

  @override
  String get comparisonTitle => 'Võrdle hooaegu';

  @override
  String get comparisonSport => 'Laskesuusatamine';

  @override
  String get comparisonProgram => 'Võistlusvorm';

  @override
  String get comparisonSeasonA => 'Hooaeg A';

  @override
  String get comparisonSeasonB => 'Hooaeg B';

  @override
  String get comparisonNeedTwoSeasons =>
      'Võrdlemiseks on vaja kahte teadaolevate kuupäevadega laskesuusahooaega.';

  @override
  String get comparisonNoProgram =>
      'Üheselt võrreldav võistlusvorm pole teada. Vaja on klassi või ürituse selgeid distsipliiniandmeid.';

  @override
  String comparisonUnknownCoverage(int unknownSeason, int unknownProgram) {
    return 'Välja jäetud andmed: $unknownSeason võistlust ilma teadaoleva laskesuusaala/kuupäevata; $unknownProgram teadmata või mitmetähendusliku võistlusvormiga.';
  }

  @override
  String comparisonRaceCoverage(int finished, int excluded) {
    return '$finished lõpetatud võistlust · $excluded lõpetamata võistlust välja jäetud';
  }

  @override
  String get comparisonShowCounts => 'Näita arve';

  @override
  String comparisonFilters(
    String sport,
    String program,
    String metric,
    String selection,
  ) {
    return 'Filtrid: $sport · $program · $metric · $selection';
  }

  @override
  String get comparisonPositionCaution =>
      'Asendivalikud pole saadaval, kui ajaloolisi laskeasendeid ei saa kontrollida. Kõik säilitab teadaolevad mõõdetud seeriad.';

  @override
  String comparisonDeltaPoints(String value) {
    return 'Tabamusprotsendi erinevus (B − A): $value protsendipunkti';
  }

  @override
  String comparisonDeltaMisses(String value) {
    return 'Keskmiste möödalaskude erinevus (B − A): $value seeria kohta';
  }

  @override
  String comparisonDeltaSeconds(String value) {
    return 'Keskmise lasketiiruaja erinevus (B − A): $value s';
  }

  @override
  String get comparisonCaution =>
      'Erinevused kirjeldavad salvestatud seeriaid, mitte tõestatud paranemist. Väikesed valimid, rühmad ja tingimused võivad erineda.';

  @override
  String get comparisonSprint => 'Sprint';

  @override
  String get comparisonIndividual => 'Tavadistants';

  @override
  String get comparisonShortIndividual => 'Lühike tavadistants';

  @override
  String get comparisonPursuit => 'Jälitussõit';

  @override
  String get comparisonMassStart => 'Ühisstart';

  @override
  String get comparisonSuperSprint => 'Supersprint';

  @override
  String get comparisonRelay => 'Teatesõit';
}
