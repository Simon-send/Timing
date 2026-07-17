# EQ importer

Importøren skriver Firestore-skjema v3:

```text
events/{eventId}/classes/{classId}
events/{eventId}/stages/{stageId}
events/{eventId}/stages/{stageId}/classes/{classId}/splitDefs/{splitId}
events/{eventId}/stages/{stageId}/classes/{classId}/results/{resultId}
```

`primaryStageId` på klassedokumentet brukes av standardvisningen. Sprint og
stafett leser alle konkurranseledd. `null`, tom tekst og tomme samlinger fjernes
før skriving, mens `0` og `false` beholdes.

## Profil-overstyring

Backend kan overstyre EQ-klassifiseringen med miljøvariabelen
`RESULT_PROFILE_OVERRIDES`:

```json
{
  "74696": {"profile": "sprint"},
  "69431": {"stages": {"292034": "relay"}}
}
```

Gyldige profiler er `standard`, `sprint`, `relay` og `biathlon`. Dokumentene
lagrer om profilen kom fra `eq` eller `override`.

Stafett og skiskyting er kombinerbare egenskaper. En skiskytterstafett beholder
`resultProfile: biathlon`, men lagrer samtidig `isRelay: true`, lagoppstilling,
etappenummer på passeringene og full `analysis.biathlon`. Arrangementer som ble
importert før denne støtten må reimporteres før etappevisningen kan vise
skiskytinganalysen per løper.

## Migrering

1. Distribuer funksjoner og Firestore-regler.
2. Reimporter arrangementene med `start-import-events.ps1`.
3. Kontroller at stage-, klasse- og resultatantall stemmer. 74696 skal gi 12
   resultatledd (prolog og heat), mens 69431 skal gi to stafettetapper.
4. Distribuer Flutter-klienten.
5. Kjør `node scripts/cleanup-legacy-results.js <eventId...>` for å fjerne gamle
   `results`- og `splitDefs`-samlinger under klassene. Skriptet nekter å rydde en
   klasse dersom det ikke finner en tilsvarende v3-stageklasse.
