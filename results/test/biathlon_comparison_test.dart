import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:results/app/app_theme.dart';
import 'package:results/features/events/domain/result_event.dart';
import 'package:results/features/profile/domain/athlete_profile.dart';
import 'package:results/features/profile/domain/biathlon_aggregate_profile.dart';
import 'package:results/features/profile/domain/biathlon_comparison.dart';
import 'package:results/features/profile/presentation/biathlon_comparison_panel.dart';
import 'package:results/features/results/domain/race_result.dart';
import 'package:results/l10n/app_localizations.dart';

void main() {
  for (final detailed in [false, true]) {
    test('maps completed finish rank with detailed analysis: $detailed', () {
      final result = RaceResult.fromMap('ranked', {
        'totalMs': 1200000,
        'finishRank': 2,
        if (detailed)
          'analysisSummary': {
            'biathlon': {
              'metrics': {'skiTimeMs': 1000000},
            },
          },
      });
      final own = BiathlonRaceMetrics.fromResult(result);
      expect(own?.valueForMetricField('finishRank'), 2);
    });
  }

  for (final rank in [null, 0, -1]) {
    test('missing or invalid finish rank stays unavailable: $rank', () {
      final own = BiathlonRaceMetrics.fromResult(
        RaceResult.fromMap('unranked', {
          'totalMs': 1200000,
          'rank': 4,
          'finishRank': rank,
          'analysisSummary': {
            'biathlon': {
              'metrics': {'skiTimeMs': 1000000},
            },
          },
        }),
        publicMetrics: {'finishRank': 99},
      );
      expect(own?.valueForMetricField('finishRank'), isNull);
    });
  }

  for (final status in ['DNF', 'DNS', 'DSQ']) {
    test('nonfinishers have no finish-rank comparison: $status', () {
      final own = BiathlonRaceMetrics.fromResult(
        RaceResult.fromMap('nonfinisher', {
          'totalMs': 1200000,
          'finishRank': 2,
          'status': status,
          'analysisSummary': {
            'biathlon': {
              'metrics': {'skiTimeMs': 1000000},
            },
          },
        }),
      );
      expect(own?.valueForMetricField('finishRank'), isNull);
    });
  }

  testWidgets('finish rank choice shows the mapped value and difference', (
    tester,
  ) async {
    final own = BiathlonRaceMetrics.fromResult(
      RaceResult.fromMap('ranked', {'totalMs': 1200000, 'finishRank': 2}),
    );
    final profile = BiathlonAggregateProfile(
      group: BiathlonReferenceGroup.topHalf,
      finishersCount: 4,
      cohortCount: 2,
      metrics: const {
        'finishTimeMs': BiathlonBenchmarkValue(mean: 1200000, count: 2),
        'finishRank': BiathlonBenchmarkValue(mean: 1.5, count: 2),
      },
    );
    await tester.pumpWidget(
      _app([_race('ranked', ownMetrics: own, topHalfProfile: profile)]),
    );
    await tester.tap(find.byKey(const Key('biathlon-detail-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sluttplass').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('biathlon-comparison-chart')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('biathlon-extra-details')));
    await tester.tap(find.byKey(const Key('biathlon-extra-details')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Du: 2.0  ·  Topp 50 %: 1.5'), findsOneWidget);
    expect(find.text('Din forskjell: +0.5'), findsOneWidget);
  });

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets(
      'comparison controls and unavailable state use ${locale.languageCode}',
      (tester) async {
        await tester.pumpWidget(
          _app([_race('missing', withBenchmark: false)], locale: locale),
        );
        final l10n = AppLocalizations.of(
          tester.element(find.byType(BiathlonComparisonPanel)),
        );
        expect(find.text(l10n.biathlonStatistics), findsOneWidget);
        expect(find.text(l10n.biathlonAllFinishers), findsOneWidget);
        expect(find.text(l10n.biathlonTopHalf), findsOneWidget);
        expect(find.text(l10n.biathlonFinishTime), findsWidgets);
        expect(
          find.text(
            l10n.biathlonComparisonUnavailable(
              l10n.biathlonFinishTime,
              l10n.biathlonTopHalf,
            ),
          ),
          findsOneWidget,
        );
        if (locale.languageCode != 'nb') {
          expect(find.text('Skiskytterstatistikk'), findsNothing);
          expect(find.text('Alle fullførte'), findsNothing);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'averages valid race percentages equally, retaining zero and excluding missing data',
    () {
      final races = [
        const BiathlonRaceMetrics(totalHitPercent: 100, proneHitPercent: 80),
        const BiathlonRaceMetrics(totalHitPercent: 0, proneHitPercent: 60),
        const BiathlonRaceMetrics(),
        const BiathlonRaceMetrics(totalHitPercent: double.nan),
        const BiathlonRaceMetrics(totalHitPercent: 101),
      ];
      final total = averageBiathlonHitPercent(
        races,
        BiathlonMetric.totalHitPercent,
      );
      expect(total?.mean, 50);
      expect(total?.count, 2);
      expect(
        averageBiathlonHitPercent(races, BiathlonMetric.proneHitPercent)?.mean,
        70,
      );
      expect(
        averageBiathlonHitPercent(races, BiathlonMetric.standingHitPercent),
        isNull,
      );
    },
  );
  testWidgets(
    'shows hit averages without reference profiles and excludes nonfinishers and relay',
    (tester) async {
      await tester.pumpWidget(
        _app([
          _race('first', withBenchmark: false),
          _race(
            'second',
            withBenchmark: false,
            ownMetrics: const BiathlonRaceMetrics(totalHitPercent: 40),
          ),
          _race('dns', status: 'DNS'),
          _race('relay', isRelay: true),
        ]),
      );
      final summary = find.byKey(const Key('biathlon-average-hit-percent'));
      expect(summary, findsOneWidget);
      expect(
        find.descendant(of: summary, matching: find.text('60.0 %')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: summary, matching: find.text('2 løp')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: summary, matching: find.text('1 løp')),
        findsNWidgets(2),
      );
    },
  );
  test('derives own hit percentages from complete public pass misses', () {
    final metrics = BiathlonRaceMetrics.fromResult(
      RaceResult.fromMap('r1', {
        'totalMs': 1200000,
        'analysisSummary': {
          'biathlon': {
            'metrics': {'skiTimeMs': 1000000, 'shootingTimeMs': 100000},
            'passes': {
              'shoot1': {'index': 1, 'misses': 1, 'position': 'prone'},
              'shoot2': {'index': 2, 'misses': 2, 'position': 'standing'},
              'shoot3': {'index': 3, 'misses': 0, 'position': 'prone'},
              'shoot4': {'index': 4, 'misses': 1, 'position': 'standing'},
            },
          },
        },
      }),
    );

    expect(metrics?.finishTimeMs, 1200000);
    expect(metrics?.skiTimeMs, 1000000);
    expect(metrics?.shootingTimeMs, 100000);
    expect(metrics?.proneHitPercent, 90);
    expect(metrics?.standingHitPercent, 70);
    expect(metrics?.totalHitPercent, 80);
  });

  test(
    'does not invent hit rates from incomplete passes or unknown positions',
    () {
      final incomplete = BiathlonRaceMetrics.fromResult(
        RaceResult.fromMap('r1', {
          'totalMs': 1200000,
          'analysisSummary': {
            'biathlon': {
              'passes': {
                'shoot1': {'index': 1, 'misses': 0, 'position': 'prone'},
                'shoot2': {
                  'index': 2,
                  'rangeMs': 30000,
                  'position': 'standing',
                },
              },
            },
          },
        }),
      );
      expect(incomplete?.totalHitPercent, isNull);
      expect(incomplete?.proneHitPercent, isNull);

      final unknownPosition = BiathlonRaceMetrics.fromResult(
        RaceResult.fromMap('r2', {
          'totalMs': 1200000,
          'analysisSummary': {
            'biathlon': {
              'passes': {
                'shoot1': {'index': 1, 'misses': 0, 'position': ''},
              },
            },
          },
        }),
      );
      expect(unknownPosition?.totalHitPercent, 100);
      expect(unknownPosition?.proneHitPercent, isNull);
      expect(unknownPosition?.standingHitPercent, isNull);
    },
  );

  test('parses only valid versioned top-half class summaries', () {
    final benchmark = BiathlonTopHalfBenchmark.fromMap({
      'version': 1,
      'finishersCount': 7,
      'cohortCount': 4,
      'metrics': {
        'finishTimeMs': {'mean': 1200000.5, 'count': 4},
        'totalHitPercent': {'mean': 85, 'count': 3},
        'skiTimeMs': {'mean': 0, 'count': 4},
        'standingHitPercent': {'mean': 105, 'count': 4},
      },
    });
    expect(benchmark?.cohortCount, 4);
    expect(benchmark?.valueFor(BiathlonMetric.finishTime)?.mean, 1200000.5);
    expect(benchmark?.valueFor(BiathlonMetric.totalHitPercent)?.count, 3);
    expect(benchmark?.valueFor(BiathlonMetric.skiTime), isNull);
    expect(benchmark?.valueFor(BiathlonMetric.standingHitPercent), isNull);
    expect(BiathlonTopHalfBenchmark.fromMap({'version': 2}), isNull);
    expect(
      BiathlonTopHalfBenchmark.fromMap({
        'version': 1,
        'finishersCount': 7,
        'cohortCount': 3,
        'metrics': {
          'finishTimeMs': {'mean': 1200000, 'count': 3},
        },
      }),
      isNull,
    );
  });

  test('time and percentage comparisons use correct better direction', () {
    const own = BiathlonRaceMetrics(finishTimeMs: 1100000, proneHitPercent: 70);
    final benchmark = _benchmark();
    expect(
      compareBiathlonMetric(
        own,
        benchmark,
        BiathlonMetric.finishTime,
      )?.advantage,
      100000,
    );
    expect(
      compareBiathlonMetric(
        own,
        benchmark,
        BiathlonMetric.proneHitPercent,
      )?.advantage,
      -10,
    );
  });

  test('reads complete aggregate profiles without rounding zero or misses', () {
    final profile = BiathlonAggregateProfile.fromMap({
      'schemaVersion': 1,
      'kind': 'biathlon-all',
      'finishersCount': 5,
      'cohortCount': 5,
      'metrics': {
        'finishTimeMs': {'mean': 1200000.5, 'count': 5},
        'proneHitPercent': {'mean': 81.2, 'count': 4},
      },
      'timingPoints': {
        'split-1': {
          'sort': 2,
          'label': 'Inn skyting 1',
          'values': {
            'cumMs': {'mean': 300000.5, 'count': 5},
          },
        },
      },
      'shootingPasses': {
        'shoot1-prone': {
          'index': 1,
          'position': 'prone',
          'values': {
            'misses': {'mean': 0.5, 'count': 4},
            'rangeMs': {'mean': 31000.2, 'count': 5},
          },
        },
      },
      'laps': {
        'lap1': {
          'index': 1,
          'values': {
            'startCumMs': {'mean': 0, 'count': 5},
          },
        },
      },
    }, BiathlonReferenceGroup.all);

    expect(profile?.valueForMetric(BiathlonMetric.finishTime)?.mean, 1200000.5);
    expect(
      profile?.shootingPasses['shoot1-prone']?.valueFor('misses')?.mean,
      0.5,
    );
    expect(profile?.timingPoints['split-1']?.valueFor('cumMs')?.count, 5);
    expect(profile?.laps['lap1']?.valueFor('startCumMs')?.mean, 0);
  });

  test('rejects mismatched or incomplete aggregate documents', () {
    final raw = {
      'schemaVersion': 1,
      'kind': 'biathlon-all',
      'finishersCount': 5,
      'cohortCount': 5,
      'metrics': {
        'finishTimeMs': {'mean': 1200000, 'count': 5},
      },
    };
    expect(
      BiathlonAggregateProfile.fromMap(raw, BiathlonReferenceGroup.topHalf),
      isNull,
    );
    expect(
      BiathlonAggregateProfile.fromMap({
        ...raw,
        'cohortCount': 4,
      }, BiathlonReferenceGroup.all),
      isNull,
    );
    expect(
      BiathlonAggregateProfile.fromMap({
        ...raw,
        'metrics': const {},
      }, BiathlonReferenceGroup.all),
      isNull,
    );
  });

  test('merges all declared profile sections and rejects missing parts', () {
    final root = <String, dynamic>{
      'schemaVersion': 1,
      'kind': 'biathlon-all',
      'finishersCount': 4,
      'cohortCount': 4,
      'metrics': {
        'finishTimeMs': {'mean': 1200000, 'count': 4},
      },
      'timingPoints': <String, dynamic>{},
      'shootingPasses': <String, dynamic>{},
      'laps': <String, dynamic>{},
      'sections': {
        'timingPoints': ['timingPoints-0-a'],
        'shootingPasses': ['shootingPasses-0-b'],
      },
    };
    final sections = <String, Map<String, dynamic>>{
      'timingPoints-0-a': {
        'schemaVersion': 1,
        'field': 'timingPoints',
        'entries': {
          'station-1': {
            'code': 'MT1-1',
            'values': {
              'cumMs': {'mean': 302000, 'count': 4},
            },
          },
        },
      },
      'shootingPasses-0-b': {
        'schemaVersion': 1,
        'field': 'shootingPasses',
        'entries': {
          'shoot1-prone': {
            'index': 1,
            'position': 'prone',
            'values': {
              'misses': {'mean': 0.75, 'count': 4},
            },
          },
        },
      },
    };
    final merged = mergeBiathlonAggregateSections(root, sections);
    final profile = BiathlonAggregateProfile.fromMap(
      merged,
      BiathlonReferenceGroup.all,
    );
    expect(profile?.timingPoints['station-1']?.valueFor('cumMs')?.mean, 302000);
    expect(
      profile?.shootingPasses['shoot1-prone']?.valueFor('misses')?.mean,
      0.75,
    );
    expect(
      mergeBiathlonAggregateSections(root, {
        'timingPoints-0-a': sections['timingPoints-0-a']!,
      }),
      isNull,
    );
    expect(
      mergeBiathlonAggregateSections(root, {
        ...sections,
        'shootingPasses-0-b': {
          ...sections['shootingPasses-0-b']!,
          'field': 'laps',
        },
      }),
      isNull,
    );
  });

  test('matches own shooting, split and lap by stable identity', () {
    final metrics = BiathlonRaceMetrics.fromResult(
      RaceResult.fromMap('r1', {
        'totalMs': 1200000,
        'analysisSummary': {
          'biathlon': {
            'metrics': {'skiTimeMs': 1000000, 'netSkiTimeMs': 900000},
            'passes': {
              'shoot1': {
                'index': 1,
                'position': 'prone',
                'misses': 1,
                'rangeMs': 30000,
                'rangeExitMs': 334000,
                'cumulativeMisses': 1,
              },
            },
            'laps': {
              'lap1': {
                'index': 1,
                'skiMs': 250000,
                'startCumMs': 0,
                'beforeShooting': 1,
                'startCode': 'START',
                'endCode': 'IN1',
              },
            },
          },
        },
        'timingPoints': [
          {'setupUid': 'split-1', 'code': 'INS1', 'cumMs': 300000},
        ],
      }),
      publicPasses: {
        'shoot1': {
          'index': 1,
          'position': 'prone',
          'rangeExitMs': 334000,
          'cumulativeMisses': 1,
        },
      },
    );

    expect(metrics?.valueForMetricField('netSkiTimeMs'), 900000);
    expect(metrics?.valueForTimingPoint('split-1', 'cumMs'), 300000);
    expect(metrics?.valueForShootingPass(1, 'prone', 'misses'), 1);
    expect(metrics?.valueForShootingPass(1, 'prone', 'rangeExitMs'), 334000);
    expect(metrics?.valueForShootingPass(1, 'prone', 'cumulativeMisses'), 1);
    expect(metrics?.valueForShootingPass(1, 'standing', 'misses'), isNull);
    expect(
      metrics?.valueForLap(
        1,
        'startCumMs',
        beforeShooting: 1,
        startCode: 'START',
        endCode: 'IN1',
      ),
      0,
    );
    expect(
      metrics?.valueForLap(
        1,
        'startCumMs',
        beforeShooting: 2,
        startCode: 'START',
        endCode: 'IN1',
      ),
      isNull,
    );
    expect(
      metrics?.valueForLap(
        1,
        'startCumMs',
        beforeShooting: 1,
        startCode: 'START',
        endCode: 'OTHER',
      ),
      isNull,
    );
  });

  test(
    'does not compute hit rate when a declared shooting pass is missing',
    () {
      final metrics = BiathlonRaceMetrics.fromResult(
        RaceResult.fromMap('r1', {
          'totalMs': 1200000,
          'analysisSummary': {
            'biathlon': {
              'metrics': {'shootingCount': 2},
              'passes': {
                'shoot1': {'index': 1, 'position': 'prone', 'misses': 0},
              },
            },
          },
        }),
        publicMetrics: {'shootingCount': 2},
      );
      expect(metrics?.totalHitPercent, isNull);
      expect(metrics?.proneHitPercent, isNull);
    },
  );

  test('retains finish-time comparison when detailed analysis is absent', () {
    final metrics = BiathlonRaceMetrics.fromResult(
      RaceResult.fromMap('r1', {'totalMs': 1200000}),
    );
    expect(metrics?.finishTimeMs, 1200000);
    expect(metrics?.shootingTimeMs, isNull);
  });

  test('uses class shooting count when own count is incomplete', () {
    final result = RaceResult.fromMap('r1', {
      'totalMs': 1200000,
      'analysisSummary': {
        'biathlon': {
          'metrics': {'shootingCount': 1},
          'passes': {
            'shoot1': {'index': 1, 'position': 'prone', 'misses': 0},
          },
        },
      },
    });
    expect(
      BiathlonRaceMetrics.fromResult(
        result,
        publicMetrics: {'shootingCount': 1},
        expectedShootingCount: 2,
      )?.totalHitPercent,
      isNull,
    );
  });

  test('rejects DNS, DNF and relay placeholder races', () {
    expect(_race('ok').isCompletedIndividualBiathlonRace, isTrue);
    expect(
      _race('dns', status: 'DNS').isCompletedIndividualBiathlonRace,
      isFalse,
    );
    expect(
      _race('dnf', status: 'DNF').isCompletedIndividualBiathlonRace,
      isFalse,
    );
    expect(
      _race('brutt', status: 'Brutt').isCompletedIndividualBiathlonRace,
      isFalse,
    );
    expect(
      _race('relay', isRelay: true).isCompletedIndividualBiathlonRace,
      isFalse,
    );
    expect(
      _race('zero', totalMs: 0).isCompletedIndividualBiathlonRace,
      isFalse,
    );
  });

  testWidgets('shows finish difference by default and can switch to hit rate', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app([_race('completed'), _race('dns', status: 'DNS')]),
    );

    expect(find.text('Skiskytterstatistikk'), findsOneWidget);
    expect(find.byKey(const Key('biathlon-comparison-chart')), findsOneWidget);
    expect(
      find.byKey(const Key('biathlon-bar-event-1/class-1/stage-1/completed')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('biathlon-bar-event-1/class-1/stage-1/dns')),
      findsNothing,
    );
    final finishChip = tester.widget<ChoiceChip>(
      find.byKey(const Key('biathlon-metric-finishTime')),
    );
    expect(finishChip.selected, isTrue);

    await tester.tap(find.byKey(const Key('biathlon-metric-proneHitPercent')));
    await tester.pump();
    final proneChip = tester.widget<ChoiceChip>(
      find.byKey(const Key('biathlon-metric-proneHitPercent')),
    );
    expect(proneChip.selected, isTrue);
    expect(find.textContaining('prosentpoeng'), findsWidgets);
    expect(
      find.byKey(const Key('biathlon-detail-standingHitPercent')),
      findsOneWidget,
    );
  });

  testWidgets('shows own data and reimport notice when baseline is missing', (
    tester,
  ) async {
    await tester.pumpWidget(_app([_race('old', withBenchmark: false)]));
    expect(
      find.byKey(const Key('biathlon-comparison-unavailable')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('biathlon-detail-finishTime')), findsOneWidget);
    expect(find.textContaining('Du: 20:00.0'), findsOneWidget);
  });

  testWidgets('switches between all and top-half profiles', (tester) async {
    await tester.pumpWidget(
      _app([
        _race(
          'new',
          allProfile: _aggregateProfile(BiathlonReferenceGroup.all),
          topHalfProfile: _aggregateProfile(BiathlonReferenceGroup.topHalf),
        ),
      ]),
    );

    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const Key('biathlon-reference-topHalf')),
          )
          .selected,
      isTrue,
    );
    expect(find.textContaining('Topp 50 %: 19:00.0'), findsOneWidget);
    await tester.tap(find.byKey(const Key('biathlon-reference-all')));
    await tester.pump();
    expect(find.textContaining('Alle fullførte: 21:00.0'), findsOneWidget);
    expect(find.byKey(const Key('biathlon-comparison-chart')), findsOneWidget);
  });

  testWidgets('compares fractional misses at the same shooting pass', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app([
        _race(
          'new',
          ownMetrics: BiathlonRaceMetrics.fromResult(
            RaceResult.fromMap('new', {
              'totalMs': 1200000,
              'analysisSummary': {
                'biathlon': {
                  'metrics': {'skiTimeMs': 1000000},
                  'passes': {
                    'shoot1': {'index': 1, 'position': 'prone', 'misses': 1},
                  },
                },
              },
            }),
          ),
          topHalfProfile: _aggregateProfile(BiathlonReferenceGroup.topHalf),
        ),
      ]),
    );

    await tester.tap(find.byKey(const Key('biathlon-detail-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skyting 1 · Bom').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('biathlon-comparison-chart')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('biathlon-extra-details')));
    await tester.tap(find.byKey(const Key('biathlon-extra-details')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Topp 50 %: 1.2 bom'), findsOneWidget);
  });

  testWidgets('missing all-profile does not hide the legacy top-half chart', (
    tester,
  ) async {
    await tester.pumpWidget(_app([_race('old')]));
    await tester.tap(find.byKey(const Key('biathlon-reference-all')));
    await tester.pump();
    expect(
      find.byKey(const Key('biathlon-comparison-unavailable')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('biathlon-reference-topHalf')));
    await tester.pump();
    expect(find.byKey(const Key('biathlon-comparison-chart')), findsOneWidget);
  });

  testWidgets('metric chooser and chart fit a 320 px screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app([_race('completed')]));
    expect(find.byKey(const Key('biathlon-comparison-chart')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('both reference selector and details fit a 320 px screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app([
        _race(
          'mobile',
          allProfile: _aggregateProfile(BiathlonReferenceGroup.all),
          topHalfProfile: _aggregateProfile(BiathlonReferenceGroup.topHalf),
        ),
      ]),
    );
    await tester.tap(find.byKey(const Key('biathlon-reference-all')));
    await tester.pump();
    expect(find.byKey(const Key('biathlon-detail-selector')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

BiathlonTopHalfBenchmark _benchmark() => const BiathlonTopHalfBenchmark(
  finishersCount: 7,
  cohortCount: 4,
  metrics: {
    BiathlonMetric.finishTime: BiathlonBenchmarkValue(mean: 1200000, count: 4),
    BiathlonMetric.skiTime: BiathlonBenchmarkValue(mean: 1000000, count: 4),
    BiathlonMetric.shootingTime: BiathlonBenchmarkValue(mean: 100000, count: 4),
    BiathlonMetric.proneHitPercent: BiathlonBenchmarkValue(mean: 80, count: 4),
    BiathlonMetric.standingHitPercent: BiathlonBenchmarkValue(
      mean: 75,
      count: 4,
    ),
    BiathlonMetric.totalHitPercent: BiathlonBenchmarkValue(mean: 78, count: 4),
  },
);

AthleteRace _race(
  String resultId, {
  String status = '',
  bool isRelay = false,
  int totalMs = 1200000,
  bool withBenchmark = true,
  BiathlonAggregateProfile? allProfile,
  BiathlonAggregateProfile? topHalfProfile,
  BiathlonRaceMetrics? ownMetrics,
}) => AthleteRace(
  eventId: 'event-1',
  classId: 'class-1',
  resultId: resultId,
  stageId: 'stage-1',
  athleteId: 'athlete-1',
  name: 'Utøver',
  className: 'Senior',
  clubName: '',
  teamName: '',
  bib: '1',
  rank: 1,
  finishRank: 1,
  totalText: '',
  shooting: '',
  status: status,
  totalMs: totalMs,
  isRelay: isRelay,
  biathlonMetrics:
      ownMetrics ??
      const BiathlonRaceMetrics(
        finishTimeMs: 1200000,
        skiTimeMs: 990000,
        shootingTimeMs: 110000,
        proneHitPercent: 90,
        standingHitPercent: 70,
        totalHitPercent: 80,
      ),
  biathlonBenchmark: withBenchmark ? _benchmark() : null,
  biathlonAllProfile: allProfile,
  biathlonTopHalfProfile: topHalfProfile,
);

BiathlonAggregateProfile _aggregateProfile(BiathlonReferenceGroup group) =>
    BiathlonAggregateProfile(
      group: group,
      finishersCount: 5,
      cohortCount: group == BiathlonReferenceGroup.all ? 5 : 3,
      metrics: {
        'finishTimeMs': BiathlonBenchmarkValue(
          mean: group == BiathlonReferenceGroup.all ? 1260000 : 1140000,
          count: group == BiathlonReferenceGroup.all ? 5 : 3,
        ),
      },
      shootingPasses: {
        'shoot1-prone': BiathlonAggregatePoint(
          id: 'shoot1-prone',
          index: 1,
          position: 'prone',
          values: {
            'misses': BiathlonBenchmarkValue(
              mean: 1.2,
              count: group == BiathlonReferenceGroup.all ? 5 : 3,
            ),
          },
        ),
      },
    );

Widget _app(List<AthleteRace> races, {Locale locale = const Locale('nb')}) =>
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      theme: buildAppTheme(AppThemeVariant.nordicDark),
      home: Scaffold(
        body: SingleChildScrollView(
          child: BiathlonComparisonPanel(
            races: races,
            events: [
              ResultEvent(
                id: 'event-1',
                name: 'Testløp',
                sportName: 'Skiskyting',
                date: DateTime(2026, 2, 1),
                place: 'Oslo',
              ),
            ],
          ),
        ),
      ),
    );
