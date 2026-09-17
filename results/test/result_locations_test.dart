import 'package:flutter_test/flutter_test.dart';
import 'package:results/features/results/domain/split_def.dart';
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

  test('a contiguous split range survives a result URL round trip', () {
    final uri = Uri.parse(
      resultsLocation(
        eventId: 'event',
        classId: 'class',
        stageId: 'stage',
        splitRange: const SplitRangeSelection(
          fromSplitId: 'split-1',
          toSplitId: 'split-3',
        ),
      ),
    );

    expect(uri.queryParameters[resultSplitQueryParameter], 'split-3');
    expect(uri.queryParameters[resultSplitModeQueryParameter], 'range');
    expect(uri.queryParameters[resultSplitFromQueryParameter], 'split-1');
    expect(uri.queryParameters[resultSplitToQueryParameter], 'split-3');

    final selection = resultSplitRangeQueryValue(uri.queryParameters);
    expect(selection?.isIndependent, isFalse);
    expect(selection?.fromSplitId, 'split-1');
    expect(selection?.toSplitId, 'split-3');
  });

  test('a split range from the start omits only its start parameter', () {
    final uri = Uri.parse(
      resultsLocation(
        eventId: 'event',
        splitRange: const SplitRangeSelection(
          fromSplitId: null,
          toSplitId: 'split-2',
        ),
      ),
    );

    expect(
      uri.queryParameters.containsKey(resultSplitFromQueryParameter),
      isFalse,
    );
    final selection = resultSplitRangeQueryValue(uri.queryParameters);
    expect(selection?.fromSplitId, isNull);
    expect(selection?.toSplitId, 'split-2');
  });

  test('independent split selections survive result and athlete URLs', () {
    const splitRange = SplitRangeSelection(
      fromSplitId: null,
      toSplitId: 'finish',
      includedSplitIds: ['first', 'finish'],
      isIndependent: true,
    );
    final resultsUri = Uri.parse(
      resultsLocation(eventId: 'event', splitRange: splitRange),
    );
    final athleteUri = Uri.parse(
      athleteLocation(
        eventId: 'event',
        classId: 'class',
        resultId: 'result',
        splitRange: splitRange,
      ),
    );

    for (final uri in [resultsUri, athleteUri]) {
      expect(uri.queryParameters[resultSplitModeQueryParameter], 'independent');
      final selection = resultSplitRangeQueryValue(uri.queryParameters);
      expect(selection?.isIndependent, isTrue);
      expect(selection?.includedSplitIds, ['first', 'finish']);
      expect(selection?.toSplitId, 'finish');
    }
  });

  test('malformed or incomplete multi-split parameters fall back safely', () {
    expect(
      resultSplitRangeQueryValue({
        resultSplitModeQueryParameter: 'independent',
        resultSplitIdsQueryParameter: 'not-json',
      }),
      isNull,
    );
    expect(
      resultSplitRangeQueryValue({resultSplitModeQueryParameter: 'range'}),
      isNull,
    );
    expect(
      resultSplitRangeQueryValue({
        resultSplitModeQueryParameter: 'independent',
        resultSplitIdsQueryParameter: '[]',
      }),
      isNull,
    );
  });
}
