// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get biathlonStatistics => 'Estadísticas de biatlón';

  @override
  String get biathlonFinishTime => 'Tiempo final';

  @override
  String get biathlonSkiTime => 'Tiempo de esquí';

  @override
  String get biathlonShootingTime => 'Tiempo de tiro';

  @override
  String get biathlonHitProneLabel => 'Porcentaje de aciertos en tendido';

  @override
  String get biathlonHitStandingLabel => 'Porcentaje de aciertos de pie';

  @override
  String get biathlonHitTotalLabel => 'Porcentaje total de aciertos';

  @override
  String get biathlonAllFinishers => 'Todos los que finalizaron';

  @override
  String get biathlonTopHalf => 'Mejor 50 %';

  @override
  String get biathlonNetSkiTime => 'Tiempo neto de esquí';

  @override
  String get biathlonPenaltyTime => 'Tiempo de penalización';

  @override
  String get biathlonRangeTime => 'Tiempo en el campo de tiro';

  @override
  String get biathlonProneTime => 'Tiempo de tiro en tendido';

  @override
  String get biathlonStandingTime => 'Tiempo de tiro de pie';

  @override
  String get biathlonTotalMisses => 'Fallos totales';

  @override
  String get biathlonProneMisses => 'Fallos en tendido';

  @override
  String get biathlonStandingMisses => 'Fallos de pie';

  @override
  String get biathlonSkiRank => 'Puesto en esquí';

  @override
  String get biathlonNetSkiRank => 'Puesto en esquí neto';

  @override
  String get biathlonShootingRank => 'Puesto en tiro';

  @override
  String get biathlonRangeRank => 'Puesto en el campo de tiro';

  @override
  String get biathlonPenaltyRank => 'Puesto por penalización';

  @override
  String get biathlonFinishRank => 'Puesto final';

  @override
  String get biathlonPassingTime => 'Tiempo de paso';

  @override
  String get biathlonSplitTime => 'Tiempo parcial';

  @override
  String get biathlonPassingRank => 'Puesto al pasar';

  @override
  String get biathlonSplitRank => 'Puesto parcial';

  @override
  String get biathlonMissesLabel => 'Fallos';

  @override
  String get biathlonRangeExitTime => 'Tiempo de salida del campo de tiro';

  @override
  String get biathlonRangeApproach => 'Llegada al campo de tiro';

  @override
  String get biathlonRangeEntry => 'Entrada al campo de tiro';

  @override
  String get biathlonShootingDone => 'Tiro completado';

  @override
  String get biathlonShootingExit => 'Salida del tiro';

  @override
  String get biathlonRangeExitTotal =>
      'Tiempo total hasta la salida del campo de tiro';

  @override
  String get biathlonCumulativeMisses => 'Fallos acumulados';

  @override
  String get biathlonStartTime => 'Hora de salida';

  @override
  String get biathlonDetailSelector => 'Más medidas: parciales, tiro y vueltas';

  @override
  String get biathlonExtraDetails =>
      'Todos los parciales, series de tiro y vueltas de esquí';

  @override
  String biathlonComparisonDescription(String group) {
    return 'Tus carreras individuales comparadas con $group en la misma categoría y fase.';
  }

  @override
  String biathlonComparisonUnavailable(String metric, String group) {
    return 'Aún no hay comparación de $metric con $group. No hay datos de referencia para esta medida.';
  }

  @override
  String get biathlonPercentDifferenceCaption =>
      'Diferencia en puntos porcentuales · por encima de la línea es mejor';

  @override
  String biathlonDifferenceCaption(String group) {
    return 'Diferencia respecto a $group · por encima de la línea es mejor';
  }

  @override
  String biathlonRaceLabel(String id) {
    return 'Carrera $id';
  }

  @override
  String biathlonCohortSummary(String group, int count, int total) {
    return '$group: $count de $total participantes que finalizaron';
  }

  @override
  String biathlonShootingNumber(int index) {
    return 'Tiro $index';
  }

  @override
  String biathlonSkiLap(int index) {
    return 'Vuelta de esquí $index';
  }

  @override
  String biathlonOwnValue(String value) {
    return 'Tú: $value';
  }

  @override
  String biathlonYourDifference(String value) {
    return 'Tu diferencia: $value';
  }

  @override
  String biathlonDecimalMisses(String value) {
    return '$value fallos';
  }

  @override
  String biathlonPercentagePoints(String value) {
    return '$value puntos porcentuales';
  }

  @override
  String get biathlonAverageHitPercent => 'Porcentaje medio de aciertos';

  @override
  String get biathlonAverageHitExplanation =>
      'Tus carreras individuales de biatlón completadas. Cada carrera cuenta igual; se excluyen los datos de tiro ausentes.';

  @override
  String get biathlonHitProne => 'Tumbado';

  @override
  String get biathlonHitStanding => 'De pie';

  @override
  String get biathlonHitTotal => 'Total';

  @override
  String biathlonAverageRaceCount(int count) {
    return '$count carreras';
  }

  @override
  String get importWaiting => 'Esperando resultados';

  @override
  String get importInProgress => 'Importando';

  @override
  String get importPartial => 'Importado parcialmente';

  @override
  String get importUpdated => 'Actualizado';

  @override
  String regressionCompareWith(String target) {
    return 'Comparar con: $target';
  }

  @override
  String get regressionChooseTarget => 'Elegir comparación';

  @override
  String regressionSelectFromList(String subject) {
    return 'Elige un valor de comparación en la lista de resultados para $subject y pulsa Aceptar.';
  }

  @override
  String get regressionCancel => 'Cancelar';

  @override
  String get regressionApply => 'Aceptar';

  @override
  String get appTitle => 'Resultados';

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
  String get searchResults => 'Buscar atleta, club o equipo';

  @override
  String get athlete => 'Athlete';

  @override
  String get club => 'Club';

  @override
  String get shooting => 'Shooting';

  @override
  String biathlonShootingIn(int index) {
    return 'Entrada al tiro $index';
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
  String get biathlonRankUnavailable => 'N.º –';

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
      'No se pudieron guardar o sincronizar los ajustes. Tu selección se mantiene.';

  @override
  String get settingsRetry => 'Reintentar';

  @override
  String get seasonTitle => 'Temporadas';

  @override
  String get seasonAll => 'Todas las temporadas';

  @override
  String get seasonUnknown => 'Temporada desconocida';

  @override
  String seasonRaceCount(int count) {
    return '$count carreras';
  }

  @override
  String seasonCompletedCount(int count) {
    return '$count carreras completadas';
  }

  @override
  String seasonObservationCount(int count) {
    return '$count observaciones válidas';
  }

  @override
  String seasonUnassignedNotice(int count) {
    return '$count carreras no tienen temporada asignada. Siguen en la lista; elige Todas las temporadas para incluirlas en las estadísticas.';
  }

  @override
  String get seasonStatisticsHint =>
      'Las estadísticas excluyen las carreras no completadas y las mediciones ausentes.';

  @override
  String get shootingSelectionTitle => 'Tandas de tiro seleccionadas';

  @override
  String get shootingMetric => 'Medida';

  @override
  String get shootingSelection => 'Tandas de tiro';

  @override
  String get shootingAll => 'Todas las tandas';

  @override
  String get shootingFirstProne => '1.ª tumbado';

  @override
  String get shootingSecondProne => '2.ª tumbado';

  @override
  String get shootingFirstStanding => '1.ª de pie';

  @override
  String get shootingSecondStanding => '2.ª de pie';

  @override
  String get shootingHits => 'Aciertos';

  @override
  String shootingValidCount(int valid, int count) {
    return '$valid de $count tandas tienen una medición';
  }

  @override
  String get shootingNoMatch =>
      'No hay ninguna tanda correspondiente registrada.';

  @override
  String get shootingAmbiguous =>
      'Faltan tandas anteriores o se desconoce su posición. No se puede determinar este número.';

  @override
  String get shootingIncomplete =>
      'Faltan algunas tandas, posiciones o mediciones.';

  @override
  String get shootingRelayUnavailable =>
      'Aciertos y fallos no disponibles: los datos de relevos no distinguen las balas de reserva de las vueltas de penalización. Se muestra el tiempo en el campo de tiro si está registrado.';

  @override
  String get shootingExcluded =>
      'Este resultado se excluye de las estadísticas.';

  @override
  String get shootingRelayPositionsUnavailable =>
      'Las posiciones de tiro no están disponibles para equipos de relevos completos. Elige Todas las tandas para ver los tiempos registrados en el campo de tiro.';

  @override
  String get seasonShootingTitle => 'Estadísticas de tiro de la temporada';

  @override
  String get seasonShootingExplanation =>
      'Para los tiros seleccionados. El porcentaje de acierto usa series conocidas de cinco disparos; se excluyen los disparos de relevos. Solo se cuentan las series registradas. No se deducen las series ausentes ni el orden incierto.';

  @override
  String get seasonShootingHitPercent => 'Porcentaje de acierto';

  @override
  String get seasonShootingAverageMisses => 'Media de fallos por serie';

  @override
  String get seasonShootingMeanRangeTime => 'Tiempo medio en el campo de tiro';

  @override
  String get seasonShootingMedianRangeTime =>
      'Mediana del tiempo en el campo de tiro';

  @override
  String seasonShootingCoverage(int valid, int missing) {
    return '$valid series válidas · $missing mediciones ausentes';
  }

  @override
  String seasonShootingUnavailableRaces(int count) {
    return 'Carreras sin series registradas seleccionables: $count';
  }

  @override
  String seasonShootingKnownShots(int hits, int shots) {
    return '$hits aciertos / $shots disparos conocidos';
  }

  @override
  String get seasonDistributionTitle => 'Distribución de la temporada';

  @override
  String seasonDistributionSeriesCount(int count) {
    return 'n = $count series medidas · cada observación es una serie';
  }

  @override
  String seasonDistributionSeconds(String value) {
    return '$value s';
  }

  @override
  String get seasonDistributionEmpty =>
      'No hay mediciones válidas para esta selección.';

  @override
  String get seasonDistributionLowData =>
      'Muy pocos datos: menos de 5 series. Interpreta la distribución con cautela.';

  @override
  String seasonDistributionMean(String value) {
    return 'Media: $value';
  }

  @override
  String seasonDistributionMedian(String value) {
    return 'Mediana: $value';
  }

  @override
  String get seasonDistributionShowChart => 'Mostrar gráfico';

  @override
  String get seasonDistributionShowTable => 'Mostrar tabla accesible';

  @override
  String get seasonDistributionCount => 'Cantidad';

  @override
  String get seasonDistributionShare => 'Proporción';

  @override
  String get seasonDistributionSelectBin =>
      'Selecciona una barra o un intervalo para ver las carreras y series correspondientes.';

  @override
  String seasonDistributionIntervals(int count) {
    return 'Número deseado de intervalos: $count';
  }

  @override
  String get seasonDistributionContributions =>
      'Carreras y series correspondientes';

  @override
  String get seasonDistributionNoContributions =>
      'No hay series en este intervalo.';

  @override
  String get comparisonTitle => 'Comparar temporadas';

  @override
  String get comparisonSport => 'Biatlón';

  @override
  String get comparisonProgram => 'Modalidad';

  @override
  String get comparisonSeasonA => 'Temporada A';

  @override
  String get comparisonSeasonB => 'Temporada B';

  @override
  String get comparisonNeedTwoSeasons =>
      'Se necesitan dos temporadas de biatlón con fechas conocidas para comparar.';

  @override
  String get comparisonNoProgram =>
      'No se conoce una modalidad comparable sin ambigüedades. Se requieren metadatos explícitos de disciplina de la categoría o del evento.';

  @override
  String comparisonUnknownCoverage(int unknownSeason, int unknownProgram) {
    return 'Datos excluidos: $unknownSeason carreras sin deporte de biatlón/fecha conocidos; $unknownProgram con modalidad desconocida o ambigua.';
  }

  @override
  String comparisonRaceCoverage(int finished, int excluded) {
    return '$finished carreras terminadas · $excluded carreras no terminadas excluidas';
  }

  @override
  String get comparisonShowCounts => 'Mostrar cantidades';

  @override
  String comparisonFilters(
    String sport,
    String program,
    String metric,
    String selection,
  ) {
    return 'Filtros: $sport · $program · $metric · $selection';
  }

  @override
  String get comparisonPositionCaution =>
      'Las selecciones por posición no están disponibles si no se pueden verificar las posiciones históricas. Todas conserva las series medidas conocidas.';

  @override
  String comparisonDeltaPoints(String value) {
    return 'Diferencia de acierto (B − A): $value puntos porcentuales';
  }

  @override
  String comparisonDeltaMisses(String value) {
    return 'Diferencia de fallos medios (B − A): $value por serie';
  }

  @override
  String comparisonDeltaSeconds(String value) {
    return 'Diferencia del tiempo medio en el campo de tiro (B − A): $value s';
  }

  @override
  String get comparisonCaution =>
      'Las diferencias describen series registradas, no una mejora demostrada. Las muestras pequeñas, los grupos y las condiciones pueden variar.';

  @override
  String get comparisonSprint => 'Esprint';

  @override
  String get comparisonIndividual => 'Individual';

  @override
  String get comparisonShortIndividual => 'Individual corto';

  @override
  String get comparisonPursuit => 'Persecución';

  @override
  String get comparisonMassStart => 'Salida en masa';

  @override
  String get comparisonSuperSprint => 'Superesprint';

  @override
  String get comparisonRelay => 'Relevo';
}
