// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get biathlonStatistics => 'Статистика биатлона';

  @override
  String get biathlonFinishTime => 'Итоговое время';

  @override
  String get biathlonSkiTime => 'Время на лыжне';

  @override
  String get biathlonShootingTime => 'Время стрельбы';

  @override
  String get biathlonHitProneLabel => 'Точность лёжа';

  @override
  String get biathlonHitStandingLabel => 'Точность стоя';

  @override
  String get biathlonHitTotalLabel => 'Общая точность';

  @override
  String get biathlonAllFinishers => 'Все финишировавшие';

  @override
  String get biathlonTopHalf => 'Лучшие 50 %';

  @override
  String get biathlonNetSkiTime => 'Чистое время на лыжне';

  @override
  String get biathlonPenaltyTime => 'Штрафное время';

  @override
  String get biathlonRangeTime => 'Время на стрельбище';

  @override
  String get biathlonProneTime => 'Время стрельбы лёжа';

  @override
  String get biathlonStandingTime => 'Время стрельбы стоя';

  @override
  String get biathlonTotalMisses => 'Всего промахов';

  @override
  String get biathlonProneMisses => 'Промахи лёжа';

  @override
  String get biathlonStandingMisses => 'Промахи стоя';

  @override
  String get biathlonSkiRank => 'Место на лыжне';

  @override
  String get biathlonNetSkiRank => 'Место по чистому времени';

  @override
  String get biathlonShootingRank => 'Место по стрельбе';

  @override
  String get biathlonRangeRank => 'Место на стрельбище';

  @override
  String get biathlonPenaltyRank => 'Место по штрафам';

  @override
  String get biathlonFinishRank => 'Итоговое место';

  @override
  String get biathlonPassingTime => 'Время прохождения';

  @override
  String get biathlonSplitTime => 'Время отрезка';

  @override
  String get biathlonPassingRank => 'Место при прохождении';

  @override
  String get biathlonSplitRank => 'Место на отрезке';

  @override
  String get biathlonMissesLabel => 'Промахи';

  @override
  String get biathlonRangeExitTime => 'Время выхода со стрельбища';

  @override
  String get biathlonRangeApproach => 'Прибытие на стрельбище';

  @override
  String get biathlonRangeEntry => 'Вход на стрельбище';

  @override
  String get biathlonShootingDone => 'Стрельба завершена';

  @override
  String get biathlonShootingExit => 'Выход после стрельбы';

  @override
  String get biathlonRangeExitTotal => 'Общее время до выхода со стрельбища';

  @override
  String get biathlonCumulativeMisses => 'Накопленные промахи';

  @override
  String get biathlonStartTime => 'Время старта';

  @override
  String get biathlonDetailSelector =>
      'Другие показатели: отрезки, стрельба и круги';

  @override
  String get biathlonExtraDetails => 'Все отрезки, стрельбы и лыжные круги';

  @override
  String biathlonComparisonDescription(String group) {
    return 'Ваши индивидуальные гонки в сравнении с $group в том же классе и этапе.';
  }

  @override
  String biathlonComparisonUnavailable(String metric, String group) {
    return 'Сравнение показателя $metric с $group пока недоступно. Для этого показателя нет эталонных данных.';
  }

  @override
  String get biathlonPercentDifferenceCaption =>
      'Разница в процентных пунктах · выше линии лучше';

  @override
  String biathlonDifferenceCaption(String group) {
    return 'Разница относительно $group · выше линии лучше';
  }

  @override
  String biathlonRaceLabel(String id) {
    return 'Гонка $id';
  }

  @override
  String biathlonCohortSummary(String group, int count, int total) {
    return '$group: $count из $total финишировавших';
  }

  @override
  String biathlonShootingNumber(int index) {
    return 'Стрельба $index';
  }

  @override
  String biathlonSkiLap(int index) {
    return 'Лыжный круг $index';
  }

  @override
  String biathlonOwnValue(String value) {
    return 'Вы: $value';
  }

  @override
  String biathlonYourDifference(String value) {
    return 'Ваша разница: $value';
  }

  @override
  String biathlonDecimalMisses(String value) {
    return '$value промахов';
  }

  @override
  String biathlonPercentagePoints(String value) {
    return '$value процентных пункта';
  }

  @override
  String get biathlonAverageHitPercent => 'Средний процент попаданий';

  @override
  String get biathlonAverageHitExplanation =>
      'Ваши завершённые индивидуальные гонки по биатлону. Каждая гонка имеет одинаковый вес; отсутствующие данные стрельбы не учитываются.';

  @override
  String get biathlonHitProne => 'Лёжа';

  @override
  String get biathlonHitStanding => 'Стоя';

  @override
  String get biathlonHitTotal => 'Всего';

  @override
  String biathlonAverageRaceCount(int count) {
    return 'Гонок: $count';
  }

  @override
  String get importWaiting => 'Ожидание результатов';

  @override
  String get importInProgress => 'Импорт';

  @override
  String get importPartial => 'Частично импортировано';

  @override
  String get importUpdated => 'Обновлено';

  @override
  String regressionCompareWith(String target) {
    return 'Сравнить с: $target';
  }

  @override
  String get regressionChooseTarget => 'Выбрать сравнение';

  @override
  String regressionSelectFromList(String subject) {
    return 'Выберите в списке результатов значение для сравнения с $subject, затем нажмите ОК.';
  }

  @override
  String get regressionCancel => 'Отмена';

  @override
  String get regressionApply => 'ОК';

  @override
  String get appTitle => 'Результаты';

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
  String get searchResults => 'Поиск спортсмена, клуба или команды';

  @override
  String get athlete => 'Athlete';

  @override
  String get club => 'Club';

  @override
  String get shooting => 'Shooting';

  @override
  String biathlonShootingIn(int index) {
    return 'На огневой рубеж $index';
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
  String get biathlonRankUnavailable => '№ –';

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
      'Не удалось сохранить или синхронизировать настройки. Ваш выбор остаётся выбранным.';

  @override
  String get settingsRetry => 'Повторить';
}
