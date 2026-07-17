import 'package:flutter_test/flutter_test.dart';
import 'package:results/features/results/presentation/result_locations.dart';

void main() {
  test('relay leg context survives result and athlete routes', () {
    final resultsUri = Uri.parse(
      resultsLocation(
        eventId: 'event',
        classId: 'class',
        stageId: 'stage',
        splitId: '__relay_leg_finish__',
        relayLegNumber: 2,
        compareBaseClassId: 'class',
        compareBaseResultId: 'team-a',
        compareBaseRelayLegNumber: 2,
      ),
    );
    final athleteUri = Uri.parse(
      athleteLocation(
        eventId: 'event',
        classId: 'class',
        resultId: 'team-a',
        stageId: 'stage',
        splitId: '__relay_leg_finish__',
        relayLegNumber: 2,
        compareWithResultId: 'team-b',
        compareWithRelayLegNumber: 3,
      ),
    );

    expect(resultsUri.queryParameters[relayLegQueryParameter], '2');
    expect(resultsUri.queryParameters[compareBaseRelayLegQueryParameter], '2');
    expect(athleteUri.queryParameters[relayLegQueryParameter], '2');
    expect(athleteUri.queryParameters[compareWithRelayLegQueryParameter], '3');
  });
}
