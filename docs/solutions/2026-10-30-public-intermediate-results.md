# Public intermediate results and confirmed finishes

Simon approved importing public intermediate-only entrants on 30 October 2026,
provided they contribute no statistics until a finish is confirmed.

Verified manifest imports use the union of complete default and station public
lists, checking pagination and stable participant identity before deduplicating
across stations. Only a positive finish-station time and an eligible status set
`finishConfirmed: true`. A `TIME` status or maximum intermediate time is not
finish evidence.

An explicit false keeps genuine timing points and source status but removes
finish time, rank and public/private derived analysis. Backend rankings and
aggregate profiles, client result comparisons and athlete season statistics
exclude that row. No DNS or DNF is invented. Athlete event summaries replace
the same event transactionally while preserving other history.

Missing/null `finishConfirmed` retains legacy reading behavior, including old
nonverified import jobs. Already stored rows and aggregates require a new
verified reimport. `PUBLISHED_RESULTS_DISAPPEARED` remains enforced; removing
unrelated stale results requires a separately approved archive/removal operation.
The new public boolean needs no rule change: results remain backend-only writes
and private analysis remains unreadable to clients.

Regression coverage includes the real failure shape (default finish list omits
a public intermediate athlete), stale finish/analysis removal, event-summary
replacement, station identity/pagination rejection, aggregate cohort exclusion
and Dart result/season exclusion with legacy compatibility.
