# Athlete seasons and result eligibility

The profile result list and its analysis share one `AthleteSeasonDataset`, built from the full `watchAthleteRaces` repository stream before presentation paging. Available seasons are derived from event metadata for actual results. The existing repository queries both legacy and stage result collections without a result limit; tests cover more than 200 rows and stream disposal.

`seasonFor` is the central sport rule. Cross-country skiing and biathlon use May 1 through April 30 inclusive; a start year of 2025 displays as 2025/26. Unknown sports or dates have no inferred season. Unassigned rows remain visibly labelled in the list; they do not contribute to a specifically selected season's statistics. All-seasons includes them without assigning a season. Multiple selection uses the union of selected seasons.

`AthleteSeasonScope.races` supplies visible rows, including non-finish statuses. `statisticalRaces` supplies analyses and requires a completed result in the selected scope. Dart `result_status.dart` and importer `result-status.js` share the exclusion policy: DNF, DNS, DFQ, DSQ/DQ and existing non-classified aliases never contribute, even with valid partial splits. Missing measurements stay missing. Relay-leg derivation preserves a non-finishing team status. New analyses in tasks #9–#12 must reuse this scope and status contract.

History metrics report their own valid-point count; the selector distinguishes visible and completed races. Existing time/percentage comparison semantics are retained; this task does not implement pooled seasonal shooting statistics or histogram distributions.

The importer now applies the same status policy to class ranking and biathlon all/top-half cohorts. No production import, reimport, deployment or data rewrite is performed by this change. Previously materialized reference profiles are not rewritten by a client update; validating/rebuilding affected old profiles requires a separately authorized import operation. The additive UI feature and tests use synthetic input and existing read contracts.

The repository delegates combined live-query processing with `yield* ...asyncMap` so cancelling a profile subscription propagates to its underlying queries. The full-history repository test awaits subscription disposal; the previous `await for`/`yield` loop stalled that disposal in the test and the delegation completes it.
