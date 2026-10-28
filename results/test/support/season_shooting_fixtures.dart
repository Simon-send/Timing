import 'package:results/features/profile/domain/athlete_profile.dart';
import 'package:results/features/profile/domain/biathlon_comparison.dart';
import 'package:results/features/profile/domain/season_shooting_distribution.dart';
import 'package:results/features/profile/domain/season_shooting_statistics.dart';
import 'package:results/features/results/domain/race_result.dart';
import 'package:results/features/results/domain/shooting_selection.dart';

AthleteRace race({
  String event = 'event',
  String stage = 'stage',
  String classId = 'class',
  String resultId = 'same-result-id',
  String status = '',
  List<String> programLabels = const [],
  int? relayLegNumber,
  bool relay = false,
  bool relayLeg = false,
  List<ShootingPass> passes = const [],
}) => AthleteRace(
  eventId: event,
  stageId: stage,
  relayLegNumber: relayLegNumber,
  classId: classId,
  resultId: resultId,
  athleteId: 'athlete',
  name: 'Athlete',
  className: 'Senior',
  clubName: '',
  teamName: '',
  bib: '1',
  rank: 1,
  finishRank: 1,
  totalText: '1:00',
  totalMs: 60000,
  shooting: '',
  status: status,
  programLabels: programLabels,
  isRelay: relay,
  biathlonMetrics: BiathlonRaceMetrics(
    shootingSeries: passes,
    isRelay: relay,
    isRelayLeg: relayLeg,
  ),
);

ShootingPass pass(
  int index, {
  int? misses = 0,
  int? time = 10000,
  String position = 'prone',
}) => ShootingPass(
  index: index,
  position: position,
  misses: misses,
  rangeMs: time,
);

SeasonShootingDistribution distribution(
  List<AthleteRace> races, {
  ShootingMetric metric = ShootingMetric.hits,
  ShootingSelection selection = ShootingSelection.all,
  ShootingDistributionScale? scale,
}) => SeasonShootingDistribution.fromStatistics(
  calculateSeasonShootingStatistics(races, selection).forMetric(metric),
  metric,
  scale: scale,
);
