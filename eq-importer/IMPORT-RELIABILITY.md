# Kontrollert innføring av ny importflyt

## Status

Den nye flyten er under lokal validering, ikke produksjonsklar. Produksjon er
ikke endret. Brukeren har godkjent `biathlonplotting1` som testmiljø.
Kontroll 2026-09-17 viste deaktivert fakturering; Cloud Functions-testdeploy
venter derfor på aktivert fakturering. Eksisterende testdatabase ligger i
`nam5`, mens produksjonsdatabasen ligger i `eur3`.

## Implementert grunnlag

- Unik kjørings-ID, privat arbeidsliste per klasse/ledd og eierskapskontrollerte
  arbeidslåser. Gamle oppgaver kan ikke skrive over en nyere kjøring.
- Holdbar planlegging av neste køoppgave og periodisk gjenoppretting med
  begrensede forsøk, også ved mislykket kølegging.
- Private, kontrollerte kildebuffer og skrivekvitteringer for gjenopptaking
  før workerens tidsgrense. Kildebufferens innhold indekseres ikke.
- Strengere kildeformat- og sidekontroller; deltakere uten tider tas med fra
  publisert liste. Ufullstendig dekning skal ikke bli merket ferdig.
- Separate rapporter per klasse/ledd og kontroll av at rapportene dekker hele
  delen som ble planlagt, uten duplikater eller selvmotsigende telling.
- Lokaliserte statusetiketter på resultatsiden.
- Operatørverktøy for lesende inspeksjon og eksplisitt gjenopptaking:

```sh
node functions/scripts/import-operations.js --project=biathlonplotting1 --event=83302
```

`--resume --run=<kontrollert kjørings-ID>` starter en ny kjøring for uløste
deler. Det oppgraderer ikke gamle produksjonsjobber uten arbeidsliste.

## Gjenstår før produksjon

- Full gjennomgang av kildeøyeblikksbilde ved oppstart, delvis manglende
  passeringer og store klasser over flere workerperioder.
- Fullstendig per-klasse forsøksoversikt og håndtering av uttømte midlertidige
  feil slik at andre klasser fortsatt kan fortsette.
- Oppbevarings-/oppryddingsregel for private kildebuffer og gamle kjøringer.
- Faktisk varsling ved tilgangsfeil, stans og uttømte forsøk (strukturerte logger
  alene er ikke en ferdig varslingstjeneste).
- Testdeploy, køoppsett og ende-til-ende-prøve med Cloud Tasks-identiteten;
  tilgangsskriptet er laget, men ikke kjørt mot ny deploy.
- Kontrollert testimport av 83302 og fixturedekning for alle resultatprofiler.
- Avklaring av aktive produksjonsoppgaver, kontrollert produksjonsutrulling,
  deretter verifisert ny kjøring av 83302 og lesende revisjon av eldre eventer.

`deploy-importer.sh` er foreløpig begrenset til testprosjekter og avviser
produksjon. Ikke bruk det som en snarvei rundt punktene over.
