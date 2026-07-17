# AGENTS.md

## Formål og omfang

Dette er arbeidsinstruksen for hele `EQ_converter`-repoet. Den gjelder for alle
filer under roten med mindre en dypere `AGENTS.md` senere gir mer spesifikke
regler. Dokumentet er skrevet for både mennesker og kodeagenter.

Målet med repoet er å hente konkurransedata fra EQ Timing, normalisere dem til
et stabilt Firestore-skjema og vise resultat-, utøver- og analysevisninger i en
Flutter-app. Bevar datakontrakten mellom importøren og klienten; endringer på
bare én side er den vanligste kilden til feil.

## Før du gjør endringer

1. Kjør `git status --short` og behold alle eksisterende brukerendringer.
2. Finn hvilket arbeidsområde endringen tilhører. Produksjonskoden ligger i
   `results/` og `eq-importer/`; `eq/`, `webScraper/` og `AI/` er foreløpig
   prototyper eller referansemateriale.
3. Les modell, repository, provider og presentasjon sammen når en dataflyt
   endres. Ikke utled Firestore-felter bare fra UI-koden.
4. Ved skjemaendringer: oppdater importør, klientmodell/mapping, regler,
   migrerings-/reimportstrategi og tester i samme arbeid.
5. Kjør den minste relevante testen underveis og full validering før levering.

## Repooversikt

- `results/`: aktiv Flutter-klient for web og øvrige Flutter-plattformer.
- `eq-importer/`: Firebase Cloud Functions, Firestore-regler, indekser og
  operasjonsskript som importerer EQ Timing-data.
- `eq/`: minimal, eldre Flutter-prototype. Ikke flytt funksjonalitet hit uten en
  eksplisitt oppgave.
- `webScraper/`: eldre Python-eksperimenter og lokale datasett. Filene har
  hardkodede arrangements-ID-er og er ikke produksjonspipeline.
- `AI/`: notater og referansedokumenter, ikke kjørekode.
- `tools/update-agents.ps1`: oppdaterer den maskin-genererte statusdelen nederst.

Bare `results/`, `eq-importer/` og rotfiler er sporet i dagens Git-historikk.
Ikke anta at uversjonerte prototypemapper skal inkluderes i en commit.

## Systemflyt

```text
EQ Timing API
  -> eq-importer/functions/index.js
  -> normalisering, profilklassifisering og avledede måltall
  -> Firestore skjema v3
  -> repositories i results/lib/features/*/data
  -> Riverpod-providere i results/lib/app/app_providers.dart
  -> GoRouter-sider og Flutter-widgets
```

## Flutter-klienten (`results/`)

### Oppstart og struktur

- `lib/main.dart` initialiserer Firebase og `SharedPreferences`, og oppretter én
  `ProviderScope`.
- `lib/app/results_app.dart` eier appnivå, tema og lokalisering.
- `lib/app/app_router.dart` er eneste autoritative rutetabell.
- `lib/app/app_providers.dart` er komposisjonsroten for Firebase-instanser,
  repositories og Riverpod-state.
- Funksjoner er organisert som `features/<feature>/{data,domain,presentation}`.
- Delte formatterere og widgets hører hjemme under `lib/core/`.

Hold avhengighetsretningen slik:

```text
presentation -> providers -> repository interface/implementation -> Firestore
presentation -> domain
data -> domain
domain -> ingen Flutter-UI- eller Firebase-avhengighet når det kan unngås
```

Ikke åpne Firestore direkte fra widgets. Legg nye spørringer i riktig
repository og eksponer dem via en provider. Provider-family-argumenter skal
inneholde alle ID-er som identifiserer strømmen, særlig `eventId`, `stageId` og
`classId`, slik at Riverpod ikke deler feil cache.

### Ruter og URL-state

Appen starter på `/events`. Resultatvalg som må kunne deles eller overleve
refresh skal være query-parametere definert og tolket via
`features/results/presentation/result_locations.dart`. Det gjelder blant annet
stage, klasse, split, stafettetappe og sammenligningsresultat.

Når en rute endres:

- oppdater både URL-bygging og parsing;
- bevar relevante query-parametere ved navigasjon til utøverdetaljer og tilbake;
- legg til eller oppdater test i `test/result_locations_test.dart` og eventuelt
  rutetesten i `test/widget_test.dart`.

### Resultatprofiler

Importør og klient støtter fire profiler:

- `standard`: vanlig resultatliste med kumulative eller uavhengige splitter;
- `sprint`: flere konkurranseledd, for eksempel prolog og heat;
- `relay`: lag, løpere, etappenummer og etappetider;
- `biathlon`: ski-, standplass-, tillegg-/straff- og skyteanalyse.

Stafett og skiskyting er ortogonale egenskaper. En skiskytterstafett kan ha
`resultProfile: biathlon` og samtidig `isRelay: true`. Ikke implementer dem som
gjensidig utelukkende UI- eller datatilstander.

`CompetitionStage`, `ResultClass`, `RaceResult` og `SplitDef` er den sentrale
domenegrensen. Ukjente eller eldre felt bør håndteres defensivt. Null, manglende
analyse og eldre importversjoner er forventede lesetilstander.

### Resultatlasting og rangering

- Standard sidegrense og «last mer»-logikk ligger i repository/provider-laget.
- En innlogget og koblet utøvers rang kan utvide første spørring slik at egen
  rad vises.
- Søk filtrerer visningen, men skal ikke beregne plassering på nytt.
- DNS, DNF og andre ikke-fullførte statuser sorteres etter fullførte resultater.
- Stafettetider kan være kumulative i rådata; etappetid må avledes konsistent.
- Bruk importørens ferdig beregnede analyse når den finnes, med defensiv
  klientavledning bare for eldre data.

### Profil, innlogging og brukerdata

- Firebase Auth er pakket inn av `features/auth/data/auth_repository.dart`.
- Brukerinnstillinger lagres lokalt og synkroniseres til
  `users/{uid}/settings/app` for verifiserte brukere.
- Koblet utøver ligger i `users/{uid}/profile/main`.
- Favoritter ligger i `users/{uid}/favoriteAthletes/{athleteId}`.
- Offentlige utøver- og tilknytningsdata leses fra `athletes/` og `clubs/`.

Sjekk alltid både auth-state og e-postverifisering når ny brukerdata skal
skrives. Firestore-reglene, ikke UI-et, er sikkerhetsgrensen.

### Lokalisering

- `lib/l10n/app_en.arb` er malfilen.
- Støttede språk oppdages fra alle `app_<locale>.arb`-filer.
- Legg samme nøkkel og kompatible plassholdere i alle ARB-filer.
- Kjør `flutter gen-l10n` etter ARB-endringer.
- `app_localizations*.dart` er generert kode. Ikke håndrediger den.
- En manglende oversettelse er ikke ferdig arbeid selv om fallback gjør at
  appen kompilerer.

### Flutter-kommandoer

Kjør fra `results/`:

```powershell
flutter pub get
flutter gen-l10n
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter run -d chrome
flutter run -d web-server --web-port 8080
```

Bruk `dart format lib test` for å rette formatering. For en smal endring kan en
enkelt testfil kjøres først, for eksempel
`flutter test test/race_result_test.dart`.

## Importøren (`eq-importer/`)

### Runtime og inngangspunkter

- Aktiv runtime er CommonJS JavaScript i `functions/index.js` på Node 22.
- `functions_ts_old/` er arkivert TypeScript og skal ikke holdes synkronisert.
- Firebase-prosjektaliaset er `time-plotting`; Firestore-regionen er `eur3` og
  funksjoner/Cloud Tasks bruker `us-central1`.
- HTTP-endepunktene er `importFromEqTimingUrls`, `startImportEvent`,
  `runImportEventChunk` og `getImportStatus`.
- Asynkron helimport oppretter `importJobs/{jobId}` og legger klasse-chunks i
  Cloud Tasks-køen `imports`.

Importfunksjoner må avvise feil HTTP-metode og ugyldige parametere før nettverk
eller Firestore-skriving. Behold retry-idempotens: dokument-ID-er skal være
stabile, writes skal kunne gjentas, og en vellykket retry skal fjerne gammel
`lastError`.

### Firestore skjema v3

Autoritativ resultatstruktur:

```text
events/{eventId}
events/{eventId}/classes/{classId}
events/{eventId}/stages/{stageId}
events/{eventId}/stages/{stageId}/classes/{classId}
events/{eventId}/stages/{stageId}/classes/{classId}/splitDefs/{splitId}
events/{eventId}/stages/{stageId}/classes/{classId}/results/{resultId}
clubs/{affiliationId}
athletes/{athleteId}
importJobs/{jobId}
users/{uid}/settings/app
users/{uid}/profile/main
users/{uid}/favoriteAthletes/{athleteId}
```

Klienten har lesefallback for eldre klassebaserte `splitDefs`/`results`, men ny
import skal skrive v3 under stage-klassen. `primaryStageId` på klassedokumentet
styrer standardvisningen. Sprint og stafett må bevare alle relevante stages.

`sanitizeForFirestore` skal fjerne `undefined`, `null`, tom tekst og tomme
samlinger, men bevare `0` og `false`. Ikke skriv verdier Firestore ikke støtter.
Ved reimport skal utdaterte tomme resultater kunne ryddes uten å slette gyldige
resultater når EQ Timing midlertidig mangler tidsrader.

### EQ Timing-normalisering

EQ Timing kan variere i store/små feltnavn, nestede `passeringer`, manglende
stasjons-ID-er og flere avstander med samme klasse. Normaliseringen skal:

- akseptere kjente payload-varianter uten å miste gyldig null/0-informasjon;
- deduplisere passeringer med stabil identitet;
- knytte deltaker, klasse, stage og `etappeDeltakerUid` korrekt;
- skille klubb, skole, organisasjon, lag og øvrige tilknytninger;
- lage stabile normaliserte ID-er når kilde-ID mangler;
- bevare rå passeringer som trengs for senere analyse;
- beregne rangeringer først etter at hele klassens resultater er samlet.

Profilklassifisering kan overstyres med miljøvariabelen
`RESULT_PROFILE_OVERRIDES`. Gyldige verdier er `standard`, `sprint`, `relay` og
`biathlon`; overstyring kan gis for arrangement eller per stage. Ikke legg
arrangementsspesifikke unntak direkte i generell normaliseringskode.

### Sikkerhet og drift

- Offentlige arrangement-, resultat-, klubb- og utøverdata er lesbare, men ikke
  skrivbare fra klienten.
- Brukerdokumenter er bare tilgjengelige for samme, innloggede og
  e-postverifiserte UID.
- `importJobs` er backend-intern og skal ikke åpnes i klientreglene.
- Ikke logg tokens, private brukerdata eller hele råpayloads ukritisk.
- Ikke deploy funksjoner eller regler, start masseimport, reimporter produksjon
  eller kjør opprydding uten at oppgaven eksplisitt ber om det.
- `clear-firestore.ps1 -YesDeleteEverything` sletter hele databasen og er en
  eksplisitt destruktiv nødrutine. Kjør den aldri som del av testing eller setup.
- `cleanup-legacy-results.js` skal bare brukes etter at tilsvarende v3-data er
  kontrollert. Skriptets sikkerhetssjekker skal ikke omgås.

### Importørkommandoer

Kjør fra `eq-importer/functions/`:

```powershell
npm ci
npm run lint
npm test
npm run serve
```

Kjør deploy fra `eq-importer/` eller med riktig Firebase-konfigurasjon:

```powershell
firebase deploy --only functions
firebase deploy --only firestore:rules,firestore:indexes
```

Deploy- og importkommandoene er eksterne sideeffekter og krever eksplisitt
oppdrag. `start-import-events.ps1` peker som standard på produksjonsfunksjonen
og skal behandles som en produksjonsoperasjon.

## Tester og ferdigkriterier

Minimumsmatrise:

| Endring | Påkrevd kontroll |
| --- | --- |
| Dart-domene eller repository | målrettet Dart-test, `flutter analyze`, full `flutter test` |
| Widget, navigasjon eller provider | relevant widget/rutetest, full `flutter test` |
| ARB/lokalisering | `flutter gen-l10n`, analyze og relevant widgettest |
| Importnormalisering eller skjema | relevant Jest-test, `npm run lint`, full `npm test` |
| Firestore-regler | gjennomgang mot alle berørte paths; bruk emulator ved atferdsendring |
| Begge sider av datakontrakten | både Jest- og Flutter-suitene |
| Dokumentasjonsgenerator | `powershell -NoProfile -File tools/update-agents.ps1 -Check` |

Nye feilrettinger skal normalt ha en regresjonstest. Bruk små fixtures som
dekker den aktuelle EQ Timing-varianten. Ikke erstatt asynkrone streams med
vilkårlige `sleep`-kall i tester; vent på en observerbar tilstand.

Arbeid er ferdig når formattering, analyse/lint og relevante tester passerer,
genererte filer er oppdatert, og `git diff` bare inneholder tilsiktede endringer.

## Kode- og endringsregler

- Følg eksisterende Dart- og JavaScript-stil; ikke gjør bred refaktorering i en
  avgrenset feilretting.
- Foretrekk små, rene domenefunksjoner for tid, rangering og analyse. De er
  enklere å teste enn logikk inne i widgets eller HTTP-handlere.
- Tidsverdier i domenet er millisekunder. Vær eksplisitt i feltnavn med `Ms`.
- Skill kumulative tider, etappetider, nettotider, straff/tillegg og rangering.
- Bevar bakoverkompatibel lesing når importerte arrangementer kan være gamle.
- Ikke håndrediger Firebase-genererte konfigurasjonsfiler uten at prosjektoppsett
  faktisk endres.
- Ikke commit `.dart_tool/`, `build/`, `node_modules/`, `.firebase/`, logger eller
  lokale datasett bare fordi de finnes i arbeidsområdet.
- Bevar norske tegn som UTF-8. Eksisterende mojibake i gamle kommentarer er
  ikke en grunn til å omskrive store filer utenfor oppgaven.

## Automatisk vedlikehold av dette dokumentet

Den normative delen over redigeres manuelt når arkitektur, kontrakter eller
arbeidsregler endres. Prosjektfakta mellom markørene under genereres av
`tools/update-agents.ps1` og skal ikke håndredigeres.

```powershell
# Oppdater én gang
powershell -NoProfile -File tools/update-agents.ps1

# Verifiser i CI eller før commit
powershell -NoProfile -File tools/update-agents.ps1 -Check

# Overvåk repoet og oppdater kontinuerlig mens du arbeider
powershell -NoProfile -File tools/update-agents.ps1 -Watch
```

Watcher-modus ignorerer byggemapper, avhengigheter, `.git` og `AGENTS.md`
selv, og skriver bare når den genererte statusen faktisk har endret seg.

<!-- BEGIN AUTO-GENERATED PROJECT FACTS -->
## Genererte prosjektfakta

Denne delen avledes deterministisk fra arbeidsomradet. Oppdater den med `tools/update-agents.ps1`.

| Arbeidsomrade | Oppdagede filer | Manifest/runtime |
| --- | ---: | --- |
| `results/` | 219 | results (Dart SDK ^3.11.0) |
| `eq-importer/` | 24 | Node 22 |
| `eq/` | 0 | ikke versjonert |
| `webScraper/` | 0 | Python-prototyper uten manifest |
| `AI/` | 0 | Referansemateriale |

- Flutter-kilde: 70 Dart-filer under `results/lib`.
- Flutter-tester: 10 testfiler med 51 oppdagede `test`/`testWidgets`-tilfeller.
- Importortester: 1 Jest-fil med 39 oppdagede testtilfeller.
- Lokaler: de, en, es, et, fi, fr, it, nb, ru, sv.
- Deklarerte rutesegmenter: /, /login, /forgot-password, /register, /me, /events, :eventId/results, :classId/athletes/:resultId.
- Eksporterte Cloud Functions: getImportStatus, importFromEqTimingUrls, runImportEventChunk, startImportEvent.
<!-- END AUTO-GENERATED PROJECT FACTS -->
