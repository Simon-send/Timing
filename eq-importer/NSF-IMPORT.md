# Import av NSF Timing

NSF-importen er et operatørverktøy for avsluttede individuelle langrenn. Results
bruker de samme resultatlistene, konkurranseleddene, utøverdetaljene og
splittvisningene som for EQ Timing. Import av stafett og kontinuerlige
liveoppdateringer er ikke en del av denne flyten.

## Forhåndsvis et renn

Kjør med Node 22 fra `eq-importer/functions`. Installer først avhengighetene
med `npm ci` og nettleseren med `npx playwright install chromium`. På en
maskin med Google Chrome kan du bruke `--channel chrome`.

```sh
npm run import:nsf -- --url 'https://live.nsftiming.no/live/2290' \
  --channel chrome --preview-out /tmp/nsf-2290.json
```

Én lenke identifiserer ett renn. Både NSF LiveTiming og den utvidede CIS-lenken
kan brukes. Verktøyet leser de offentlige nettsidene. Forhåndsvisningen viser
klasse-ID-er, avstemte deltakerantall, hvilke mellomtider som finnes, og
eventuelle avvik. Den skriver ingenting til Firestore.

- **Dato og sted:** Bruk `--date YYYY-MM-DD --place <sted>` når metadata ikke
  finnes i livevisningen eller den offisielle lista.
- **Offisiell liste:** Bruk `--official 'klasse-id=sti-eller-lenke-til-PDF'`
  én gang per klasse. I sprint kreves en offisiell sluttliste, ikke bare
  prolog eller A-finale. For distanse kan en offisiell liste avstemme
  målplassering, sluttider og deltakerantall. Gi prologlista separat med
  `--official-stage 'prolog/klasse-id=sti-eller-lenke-til-PDF'` når du vil
  avstemme prologplassering og sluttid. Offisiell tid går foran ved avvik;
  mellomtider fra live beholdes.
- **Fil:** Bruk `--export /tmp/nsf-2290.json` for å forhåndsvise en lagret
  kilde eller en kompatibel eksport. Du kan supplere en ufullstendig eksport
  med offisielle lister og skrive en ny fil med `--preview-out`.
  Verktøyet overskriver ikke eksisterende eksportfiler.

Rå eksportfiler er arbeidsdata. Oppbevar dem utenfor repoet. Bare den avgrensede
resultatmodellen skrives til de offentlige Firestore-dokumentene.

## Skriv i testmiljø

Bruk bare en forhåndsvisning med `ready: true` og den oppgitte kontrollsummen.
Med Firestore-emulatoren startet på port 8081:

```sh
FIRESTORE_EMULATOR_HOST=127.0.0.1:8081 npm run import:nsf -- \
  --export /tmp/nsf-2290.json --apply --confirm <kontrollsum> \
  --project demo-nsf-results
```

Skriving krever eksplisitt prosjekt og bekreftet innhold. Samme innhold er
idempotent. En svakere eksport kan ikke fjerne tidligere importerte rader eller
målinger, plasseringer eller autoriteten til en offisiell rettelse. En offisiell
DNF-rettelse kan fjerne målpasseringen, men må beholde tidligere mellomtider.
Alle offentlige dokumenter byttes samlet i én transaksjon. Ved avbrudd står
forrige komplette resultatsett urørt. Gjenoppta med samme fil, kontrollsum og
`--resume`. Kvitteringer er interne. Publisering i produksjon avtales separat.

Operatørverktøyet avviser datasett over 6 MiB beregnet JSON, inkludert
dekningskvitteringen, og kvitteringer over 850 kB før noen skriving. Dette gir
margin til Firestores [grense for forespørselsstørrelse](https://firebase.google.com/docs/firestore/quotas).
Den tidligere grensen på 500 skriv per transaksjon ble
[fjernet i 2023](https://docs.cloud.google.com/firestore/docs/release-notes).
Indeksunntaket for `nsfImportReceipts.coverage` i `firestore.indexes.json` skal
følge med når importen senere settes i drift.

## Eksportformat v1

Kilden er en JSON med `schemaVersion: 1`, `event`, `classes` og `stages`.
Hver klasse har `id` og `name`, og kan ha `expectedCount` og `official`
(offisielle resultatrader). Offisielle tidslister krever både plassering og
sluttid for fullførte utøvere. Et konkurranseledd har `id`, `name`, `phase` og
`classes`. Hver leddklasse har `classId`, `points` og `rows`. En rad har
navn og den tilgjengelige kombinasjonen av startnummer, klubb, nasjon,
plassering, sluttid, status, kilde-ID og mellomtider.

```json
{
  "schemaVersion": 1,
  "event": {"id": "2290", "name": "Eksempel 30 km", "date": "2026-03-08", "place": "Skeikampen"},
  "classes": [{"id": "senior", "name": "Senior", "expectedCount": 1}],
  "stages": [{
    "id": "distance",
    "name": "30 km",
    "phase": "distance",
    "classes": [{
      "classId": "senior",
      "points": [{"id": "km33", "label": "3,3 km", "km": 3.3, "kind": "split"}],
      "rows": [{"name": "Testløper", "bib": "140", "rank": 1, "totalMs": 3964900,
        "points": {"km33": {"cumMs": 427800, "rank": 1}}}]
    }]
  }]
}
```

Tider er hele millisekunder. Definer punktene i løyperekkefølge. `finish` kan
oppgis som punkt med `kind: "finish"`; ellers lages det fra sluttiden.
NSF-resultater har `splitLegsAuthoritative: true`: en utelatt segmenttid er
ukjent og skal ikke beregnes fra et tidligere tilgjengelig punkt i klienten.
`resultAuthority` skiller offisielt avstemte resultater fra liveverdier.
Sprint bruker fasene `prolog`, `quarterfinal`, `semifinal` og `final`.
Samme `courseKey` skal bare brukes når heatene følger samme løype. Målepunktene
må også være kompatible. Utøverens identitet kobles per klasse på tvers av heat;
startnummeret bevares per ledd. Appen viser den offisielle sluttlista som eget
ledd uten å summere tider fra flere heat.

## Kilder til kontroll

- [Skeikampen 30 km](https://live.nsftiming.no/live/splits/2290)
- [Skeikampen sprint](https://live.nsftiming.no/live/sprint/2279)
- [Skeikampen 5 km](https://live.nsftiming.no/live/2231)
- [Offisielle resultatlister](https://www.skiforbundet.no/arrangement/2025-2026/skeikampen26/start--og-resultatlister/)

## Verifisert 11. november 2026

De offentlige nettsidene og åtte offisielle PDF-lister ble lest med denne
importøren. Begge lenkeformatene ble prøvd. Følgende ble avstemt og importert
i lokal Firestore-emulator, uten produksjonsskriving:

| Renn | Menn | Kvinner | Konkurranseledd og målepunkter |
| --- | ---: | ---: | --- |
| 2231, 5 km | 152 | 67 | Distanse, tre mellomtider og mål |
| 2279, sprint | 108 | 50 | Sluttresultat, prolog, fem kvartfinaler, to semifinaler og A-finale per klasse |
| 2290, 30 km | 148 | 63 | Distanse, 15 mellomtider og mål |

Sprintens offisielle prologliste retter ett live-resultat fra DNF til plassert
med tid. Dette og delte offisielle plasseringer fremgår som avvik i
forhåndsvisningen. En offisiell rad uten sluttplassering vises som NC.

Identisk gjenimport skrev null dokumenter for alle tre renn. Automatiserte
tester kontrollerer avvist svekket gjenimport, offisiell pallrettelse og
gjenopptakelse etter avbrudd. En eksisterende EQ-import av 79446 ble også
kjørt mot emulatoren som regresjonskontroll.

I Results ble sluttliste, heatvalg, klassebytte, utøverdetaljer og mellomtider
åpnet. Begge sprintklassene viste pallreferansen på tvers av heat med tre av
tre bidrag ved de tilgjengelige målepunktene. JSON-filene og PDF-ene som ble
brukt i kontrollen er lokale arbeidsdata og følger ikke kildekoden.
