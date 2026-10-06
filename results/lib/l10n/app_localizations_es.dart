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
}
