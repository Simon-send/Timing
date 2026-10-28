// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get biathlonStatistics => 'Statistiques de biathlon';

  @override
  String get biathlonFinishTime => 'Temps final';

  @override
  String get biathlonSkiTime => 'Temps de ski';

  @override
  String get biathlonShootingTime => 'Temps de tir';

  @override
  String get biathlonHitProneLabel => 'Précision au tir couché';

  @override
  String get biathlonHitStandingLabel => 'Précision au tir debout';

  @override
  String get biathlonHitTotalLabel => 'Précision totale';

  @override
  String get biathlonAllFinishers => 'Tous les arrivants';

  @override
  String get biathlonTopHalf => 'Meilleurs 50 %';

  @override
  String get biathlonNetSkiTime => 'Temps de ski net';

  @override
  String get biathlonPenaltyTime => 'Temps de pénalité';

  @override
  String get biathlonRangeTime => 'Temps au pas de tir';

  @override
  String get biathlonProneTime => 'Temps de tir couché';

  @override
  String get biathlonStandingTime => 'Temps de tir debout';

  @override
  String get biathlonTotalMisses => 'Erreurs totales';

  @override
  String get biathlonProneMisses => 'Erreurs au tir couché';

  @override
  String get biathlonStandingMisses => 'Erreurs au tir debout';

  @override
  String get biathlonSkiRank => 'Classement en ski';

  @override
  String get biathlonNetSkiRank => 'Classement en ski net';

  @override
  String get biathlonShootingRank => 'Classement au tir';

  @override
  String get biathlonRangeRank => 'Classement au pas de tir';

  @override
  String get biathlonPenaltyRank => 'Classement des pénalités';

  @override
  String get biathlonFinishRank => 'Classement final';

  @override
  String get biathlonPassingTime => 'Temps de passage';

  @override
  String get biathlonSplitTime => 'Temps intermédiaire';

  @override
  String get biathlonPassingRank => 'Classement au passage';

  @override
  String get biathlonSplitRank => 'Classement du secteur';

  @override
  String get biathlonMissesLabel => 'Erreurs';

  @override
  String get biathlonRangeExitTime => 'Temps de sortie du pas de tir';

  @override
  String get biathlonRangeApproach => 'Arrivée au pas de tir';

  @override
  String get biathlonRangeEntry => 'Entrée au pas de tir';

  @override
  String get biathlonShootingDone => 'Tir terminé';

  @override
  String get biathlonShootingExit => 'Sortie du tir';

  @override
  String get biathlonRangeExitTotal => 'Temps total à la sortie du pas de tir';

  @override
  String get biathlonCumulativeMisses => 'Erreurs cumulées';

  @override
  String get biathlonStartTime => 'Heure de départ';

  @override
  String get biathlonDetailSelector =>
      'Autres mesures : intermédiaires, tirs et tours';

  @override
  String get biathlonExtraDetails =>
      'Tous les intermédiaires, tirs et tours de ski';

  @override
  String biathlonComparisonDescription(String group) {
    return 'Vos courses individuelles comparées à $group dans la même catégorie et phase.';
  }

  @override
  String biathlonComparisonUnavailable(String metric, String group) {
    return 'Pas encore de comparaison de $metric avec $group. Les données de référence pour cette mesure sont indisponibles.';
  }

  @override
  String get biathlonPercentDifferenceCaption =>
      'Écart en points de pourcentage · au-dessus de la ligne signifie mieux';

  @override
  String biathlonDifferenceCaption(String group) {
    return 'Écart par rapport à $group · au-dessus de la ligne signifie mieux';
  }

  @override
  String biathlonRaceLabel(String id) {
    return 'Course $id';
  }

  @override
  String biathlonCohortSummary(String group, int count, int total) {
    return '$group : $count sur $total arrivants';
  }

  @override
  String biathlonShootingNumber(int index) {
    return 'Tir $index';
  }

  @override
  String biathlonSkiLap(int index) {
    return 'Tour de ski $index';
  }

  @override
  String biathlonOwnValue(String value) {
    return 'Vous : $value';
  }

  @override
  String biathlonYourDifference(String value) {
    return 'Votre écart : $value';
  }

  @override
  String biathlonDecimalMisses(String value) {
    return '$value erreurs';
  }

  @override
  String biathlonPercentagePoints(String value) {
    return '$value points de pourcentage';
  }

  @override
  String get biathlonAverageHitPercent => 'Pourcentage moyen de réussite';

  @override
  String get biathlonAverageHitExplanation =>
      'Vos courses individuelles de biathlon terminées. Chaque course compte autant ; les données de tir manquantes sont exclues.';

  @override
  String get biathlonHitProne => 'Couché';

  @override
  String get biathlonHitStanding => 'Debout';

  @override
  String get biathlonHitTotal => 'Total';

  @override
  String biathlonAverageRaceCount(int count) {
    return '$count courses';
  }

  @override
  String get importWaiting => 'En attente des résultats';

  @override
  String get importInProgress => 'Importation en cours';

  @override
  String get importPartial => 'Importation partielle';

  @override
  String get importUpdated => 'À jour';

  @override
  String regressionCompareWith(String target) {
    return 'Comparer à : $target';
  }

  @override
  String get regressionChooseTarget => 'Choisir la comparaison';

  @override
  String regressionSelectFromList(String subject) {
    return 'Choisissez une valeur à comparer à $subject dans la liste des résultats, puis validez.';
  }

  @override
  String get regressionCancel => 'Annuler';

  @override
  String get regressionApply => 'OK';

  @override
  String get appTitle => 'Résultats';

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
  String get searchResults => 'Rechercher un athlète, un club ou une équipe';

  @override
  String get athlete => 'Athlete';

  @override
  String get club => 'Club';

  @override
  String get shooting => 'Shooting';

  @override
  String biathlonShootingIn(int index) {
    return 'Entrée au tir $index';
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
  String get biathlonRankUnavailable => 'N° –';

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
      'Impossible d’enregistrer ou de synchroniser les paramètres. Votre choix reste sélectionné.';

  @override
  String get settingsRetry => 'Réessayer';

  @override
  String get seasonTitle => 'Saisons';

  @override
  String get seasonAll => 'Toutes les saisons';

  @override
  String get seasonUnknown => 'Saison inconnue';

  @override
  String seasonRaceCount(int count) {
    return '$count courses';
  }

  @override
  String seasonCompletedCount(int count) {
    return '$count courses terminées';
  }

  @override
  String seasonObservationCount(int count) {
    return '$count observations valides';
  }

  @override
  String seasonUnassignedNotice(int count) {
    return '$count courses n’ont pas de saison attribuée. Elles restent dans la liste ; choisissez Toutes les saisons pour les inclure dans les statistiques.';
  }

  @override
  String get seasonStatisticsHint =>
      'Les statistiques excluent les courses non terminées et les mesures manquantes.';

  @override
  String get shootingSelectionTitle => 'Tirs sélectionnés';

  @override
  String get shootingMetric => 'Mesure';

  @override
  String get shootingSelection => 'Tirs';

  @override
  String get shootingAll => 'Tous les tirs';

  @override
  String get shootingFirstProne => '1er couché';

  @override
  String get shootingSecondProne => '2e couché';

  @override
  String get shootingFirstStanding => '1er debout';

  @override
  String get shootingSecondStanding => '2e debout';

  @override
  String get shootingHits => 'Cibles touchées';

  @override
  String shootingValidCount(int valid, int count) {
    return '$valid tirs sur $count ont une mesure';
  }

  @override
  String get shootingNoMatch => 'Aucun tir correspondant enregistré.';

  @override
  String get shootingAmbiguous =>
      'Des tirs précédents manquent ou leur position est inconnue. Ce numéro ne peut pas être déterminé.';

  @override
  String get shootingIncomplete =>
      'Certains tirs, positions ou mesures manquent.';

  @override
  String get shootingRelayUnavailable =>
      'Les touches et les ratés sont indisponibles : les données de relais ne distinguent pas les balles de pioche des tours de pénalité. Le temps au pas de tir est affiché si enregistré.';

  @override
  String get shootingExcluded => 'Ce résultat est exclu des statistiques.';

  @override
  String get shootingRelayPositionsUnavailable =>
      'Les positions de tir sont indisponibles pour une équipe de relais entière. Choisissez Tous les tirs pour les temps au pas de tir enregistrés.';

  @override
  String get seasonShootingTitle => 'Statistiques de tir de la saison';

  @override
  String get seasonShootingExplanation =>
      'Pour les tirs sélectionnés. Le taux de réussite utilise les séries connues de cinq tirs ; les tirs de relais sont exclus. Seules les séries enregistrées sont comptées. Les séries absentes et les ordres incertains ne sont pas déduits.';

  @override
  String get seasonShootingHitPercent => 'Taux de réussite';

  @override
  String get seasonShootingAverageMisses =>
      'Moyenne des tirs manqués par série';

  @override
  String get seasonShootingMeanRangeTime => 'Temps moyen au pas de tir';

  @override
  String get seasonShootingMedianRangeTime => 'Temps médian au pas de tir';

  @override
  String seasonShootingCoverage(int valid, int missing) {
    return '$valid séries valides · $missing mesures manquantes';
  }

  @override
  String seasonShootingUnavailableRaces(int count) {
    return 'Courses sans série enregistrée sélectionnable : $count';
  }

  @override
  String seasonShootingKnownShots(int hits, int shots) {
    return '$hits réussites / $shots tirs connus';
  }

  @override
  String get seasonDistributionTitle => 'Distribution de la saison';

  @override
  String seasonDistributionSeriesCount(int count) {
    return 'n = $count séries mesurées · chaque observation est une série';
  }

  @override
  String seasonDistributionSeconds(String value) {
    return '$value s';
  }

  @override
  String get seasonDistributionEmpty =>
      'Aucune mesure valide pour cette sélection.';

  @override
  String get seasonDistributionLowData =>
      'Très peu de données : moins de 5 séries. Interprétez la distribution avec prudence.';

  @override
  String seasonDistributionMean(String value) {
    return 'Moyenne : $value';
  }

  @override
  String seasonDistributionMedian(String value) {
    return 'Médiane : $value';
  }

  @override
  String get seasonDistributionShowChart => 'Afficher le graphique';

  @override
  String get seasonDistributionShowTable => 'Afficher le tableau accessible';

  @override
  String get seasonDistributionCount => 'Nombre';

  @override
  String get seasonDistributionShare => 'Part';

  @override
  String get seasonDistributionSelectBin =>
      'Sélectionnez une barre ou un intervalle pour voir les courses et séries correspondantes.';

  @override
  String seasonDistributionIntervals(int count) {
    return 'Nombre souhaité d’intervalles : $count';
  }

  @override
  String get seasonDistributionContributions =>
      'Courses et séries correspondantes';

  @override
  String get seasonDistributionNoContributions =>
      'Aucune série dans cet intervalle.';

  @override
  String get comparisonTitle => 'Comparer les saisons';

  @override
  String get comparisonSport => 'Biathlon';

  @override
  String get comparisonProgram => 'Format';

  @override
  String get comparisonSeasonA => 'Saison A';

  @override
  String get comparisonSeasonB => 'Saison B';

  @override
  String get comparisonNeedTwoSeasons =>
      'Deux saisons de biathlon datées sont nécessaires pour comparer.';

  @override
  String get comparisonNoProgram =>
      'Aucun format comparable sans ambiguïté. Des métadonnées explicites de discipline de la catégorie ou de l’événement sont requises.';

  @override
  String comparisonUnknownCoverage(int unknownSeason, int unknownProgram) {
    return 'Données exclues : $unknownSeason courses sans sport biathlon/date connus ; $unknownProgram avec un format inconnu ou ambigu.';
  }

  @override
  String comparisonRaceCoverage(int finished, int excluded) {
    return '$finished courses terminées · $excluded courses non terminées exclues';
  }

  @override
  String get comparisonShowCounts => 'Afficher les nombres';

  @override
  String comparisonFilters(
    String sport,
    String program,
    String metric,
    String selection,
  ) {
    return 'Filtres : $sport · $program · $metric · $selection';
  }

  @override
  String get comparisonPositionCaution =>
      'Les sélections par position sont indisponibles si les positions historiques ne peuvent pas être vérifiées. Toutes conserve les séries mesurées connues.';

  @override
  String comparisonDeltaPoints(String value) {
    return 'Écart de taux de réussite (B − A) : $value points de pourcentage';
  }

  @override
  String comparisonDeltaMisses(String value) {
    return 'Écart des tirs manqués moyens (B − A) : $value par série';
  }

  @override
  String comparisonDeltaSeconds(String value) {
    return 'Écart du temps moyen au pas de tir (B − A) : $value s';
  }

  @override
  String get comparisonCaution =>
      'Les écarts décrivent les séries enregistrées, sans prouver une amélioration. Les petits échantillons, groupes et conditions peuvent différer.';

  @override
  String get comparisonSprint => 'Sprint';

  @override
  String get comparisonIndividual => 'Individuel';

  @override
  String get comparisonShortIndividual => 'Individuel court';

  @override
  String get comparisonPursuit => 'Poursuite';

  @override
  String get comparisonMassStart => 'Départ groupé';

  @override
  String get comparisonSuperSprint => 'Super sprint';

  @override
  String get comparisonRelay => 'Relais';
}
