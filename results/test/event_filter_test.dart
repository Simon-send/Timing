import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:results/app/app_theme.dart';
import 'package:results/features/events/domain/result_event.dart';
import 'package:results/features/events/presentation/event_filters.dart';
import 'package:results/l10n/app_localizations.dart';

void main() {
  for (final width in [390.0, 1000.0]) {
    testWidgets('sport shortcuts filter without opening the panel at $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      var criteria = const EventFilterCriteria();
      final events = [
        for (final (id, name, sport) in [
          ('ski', 'Skirennet', 'Langrenn'),
          ('biathlon', 'Skiskytterrennet', 'Skiskyting'),
          ('run', 'Løpet', 'Friidrett'),
        ])
          ResultEvent(
            id: id,
            name: name,
            sportName: sport,
            date: DateTime(2026, 2),
            place: 'Teststed',
          ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(AppThemeVariant.nordicDark),
          locale: const Locale('nb'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SingleChildScrollView(
                child: Column(
                  children: [
                    EventFilters(
                      controller: controller,
                      criteria: criteria,
                      options: EventFilterOptions.fromEvents(events),
                      filteredCount: events
                          .where((event) => criteria.matches(event, ''))
                          .length,
                      totalCount: events.length,
                      onChanged: (next) => setState(() => criteria = next),
                      onReset: () => setState(
                        () => criteria = const EventFilterCriteria(),
                      ),
                    ),
                    for (final event in events.where(
                      (event) => criteria.matches(event, ''),
                    ))
                      Text(event.name),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final ski = find.byKey(const Key('event-sport-langrenn'));
      final biathlon = find.byKey(const Key('event-sport-skiskyting'));
      expect(ski, findsOneWidget);
      expect(biathlon, findsOneWidget);
      final neutral = tester
          .widget<IconButton>(ski)
          .style!
          .backgroundColor!
          .resolve({});
      expect(find.byTooltip('Vis filtre'), findsOneWidget);
      await tester.tap(ski);
      await tester.pumpAndSettle();
      expect(find.text('Skirennet'), findsOneWidget);
      expect(find.text('Skiskytterrennet'), findsNothing);
      expect(find.text('Løpet'), findsNothing);
      expect(tester.widget<IconButton>(ski).isSelected, isTrue);
      expect(
        tester.widget<IconButton>(ski).style!.backgroundColor!.resolve({}),
        isNot(neutral),
      );
      expect(find.byTooltip('Vis filtre'), findsOneWidget);
      await tester.tap(biathlon);
      await tester.pumpAndSettle();
      expect(find.text('Skiskytterrennet'), findsOneWidget);
      expect(find.text('Skirennet'), findsNothing);
      expect(tester.widget<IconButton>(ski).isSelected, isFalse);
      await tester.tap(biathlon);
      await tester.pumpAndSettle();
      expect(find.text('Skirennet'), findsOneWidget);
      expect(find.text('Skiskytterrennet'), findsOneWidget);
      expect(find.text('Løpet'), findsOneWidget);
    });
  }

  for (final sports in [
    <String>[],
    ['Skiskyting'],
    ['langrenn'],
  ]) {
    testWidgets('sport shortcut stays valid with options $sports', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1000, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      var criteria = const EventFilterCriteria();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(AppThemeVariant.nordicDark),
          locale: const Locale('nb'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SingleChildScrollView(
                child: EventFilters(
                  controller: controller,
                  criteria: criteria,
                  options: EventFilterOptions(
                    countries: const [],
                    sports: sports,
                    disciplines: const [],
                    counties: const [],
                  ),
                  filteredCount: 0,
                  totalCount: sports.length,
                  onChanged: (next) => setState(() => criteria = next),
                  onReset: () =>
                      setState(() => criteria = const EventFilterCriteria()),
                ),
              ),
            ),
          ),
        ),
      );
      final ski = find.byKey(const Key('event-sport-langrenn'));
      await tester.tap(ski);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Vis filtre'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final selector = tester.widget<DropdownButton<String>>(
        find.byWidgetPredicate(
          (widget) =>
              widget is DropdownButton<String> && widget.value == 'Langrenn',
        ),
      );
      expect(
        selector.items!.where((item) => item.value == 'Langrenn'),
        hasLength(1),
      );
      await tester.tap(ski);
      await tester.pumpAndSettle();
      expect(criteria.sport, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  test('maps optional event filter metadata from Firestore data', () {
    final event = ResultEvent.fromMap('event-1', {
      'name': 'Sommerløpet',
      'sportName': 'Friidrett',
      'date': '2026-06-20',
      'place': 'Lillehammer',
      'country': {'name': 'Norge'},
      'county': 'Innlandet',
      'municipality': 'Lillehammer',
      'participantCount': 245,
      'discipline': {'name': 'Terrengløp'},
      'disciplines': ['5 km', '10 km', '5 km'],
      'ageFrom': 12,
      'ageTo': 80,
    });

    expect(event.country, 'Norge');
    expect(event.county, 'Innlandet');
    expect(event.area, 'Lillehammer');
    expect(event.participantCount, 245);
    expect(event.disciplines, ['10 km', '5 km', 'Terrengløp']);
    expect(event.ageFrom, 12);
    expect(event.ageTo, 80);
  });

  test('combines event filters and treats age as an overlapping interval', () {
    final event = ResultEvent(
      id: 'event-1',
      name: 'Sommerløpet',
      sportName: 'Friidrett',
      date: DateTime(2026, 6, 20),
      place: 'Lillehammer stadion',
      country: 'Norge',
      county: 'Innlandet',
      area: 'Lillehammer',
      participantCount: 245,
      disciplines: const ['10 km'],
      ageFrom: 12,
      ageTo: 80,
    );
    final filters = EventFilterCriteria(
      country: 'Norge',
      sport: 'Friidrett',
      discipline: '10 km',
      county: 'Innlandet',
      area: 'stadion',
      dateFrom: DateTime(2026, 6, 1),
      dateTo: DateTime(2026, 6, 30),
      participantsFrom: 200,
      participantsTo: 300,
      ageFrom: 65,
      ageTo: 90,
    );

    expect(filters.matches(event, 'sommer'), isTrue);
    expect(filters.copyWith(country: 'Sverige').matches(event, ''), isFalse);
    expect(filters.copyWith(participantsFrom: 300).matches(event, ''), isFalse);
    expect(filters.copyWith(ageFrom: 81).matches(event, ''), isFalse);
  });

  test('excludes unknown metadata only when its filter is active', () {
    final event = ResultEvent(
      id: 'legacy-event',
      name: 'Eldre event',
      sportName: 'Ski',
      date: DateTime(2025),
      place: 'Oslo',
    );

    expect(const EventFilterCriteria().matches(event, ''), isTrue);
    expect(
      const EventFilterCriteria(participantsFrom: 1).matches(event, ''),
      isFalse,
    );
    expect(const EventFilterCriteria(ageFrom: 10).matches(event, ''), isFalse);
  });
}
