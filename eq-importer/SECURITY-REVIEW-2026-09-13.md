# Sikkerhetskontroll 13. september 2026

## Bekreftet i produksjon (skrivebeskyttet kontroll)

- startImportEvent/getImportStatus: bare operatørens bruker har Run Invoker.
- runImportEventChunk: bare import-tasks-servicekontoen har Run Invoker.
- Anonym GET mot getImportStatus svarte 403.
- Importfunksjonene bruker eq-import-runtime; Rundeanalyse bruker rundeanalyse-runtime.
- Compute-kontoen har ikke Editor, men har fortsatt cloudtasks.enqueuer. Fjern denne bare etter kontroll av eventuelle andre køprodusenter.
- Appspot- og cloudservices-servicekontoene har fortsatt Editor. Kartlegg bruk før endring; disse er ikke importfunksjonenes runtime.
- Firebase Auth godkjenner results.plotting.live.
- App Check for Firestore og Authentication er UNENFORCED. Dette betyr at den tidligere reCAPTCHA-advarselen alene ikke beviser at App Check avviste innloggingen.
- Rundeanalyse-funksjonenes miljø mangler RUNDEANALYSE_ENFORCE_APP_CHECK. Med nåværende kildekode betyr det at callable-håndhevingen er av.
- De deployede Firestore-reglene inneholder privateAnalysis-avvisning, men ikke den nye kontrollen som binder favorittens athleteId til dokument-ID.
- Tørrkjøring av eksisterende oppryddingsskript: 572 utøverdokumenter og 4505 resultatdokumenter trenger rydding. Ingen produksjonsdokumenter er endret.

## Kodeendringer

Sentral redirect-behandling uten automatisk gjentakelse, vern mot dobbel innsending, e-post fjernet fra URL, synlig sikkerhetsfeil i oppstart, gjenbruk av pågående initialisering, avbrytbare profilstrømmer, favorittvalidering og gjenbruk av Firebase Admin-appen. Ny kvadratisk logo med nytt filnavn og lokaliserte titler uten EQ. Målrettet utfasing av Flutter sin gamle worker-cache; Auth-lagring berøres ikke.

## Utrulling og gjenværende produksjonstiltak

1. Hosting-preview testes før live-kloning. Preview-domenet må godkjennes i reCAPTCHA for å kunne verifisere hele oppstarten. Auth-retur må testes på produksjonsdomenet som er authDomain.
2. Favorittreglene deployes separat etter vurdering av regelavvik. Ikke publiser hele funksjonsprosjektet som del av en logoendring.
3. Rundeanalyse sin runtime-rettelse og avhengighetsoppdateringer testes og deployes som egen codebase. Eksisterende ikke-sporede filer må gjennomgås før en samlet deploy.
4. Før App Check håndheves: bekreft gyldige tokens og mål avvisninger for både results.plotting.live og analyse.plotting.live. Slå på tjenestevis først etter godkjente klienttester; ingen serverbeskyttelse er redusert av denne endringen.
5. Offentlig opprydding krever separat rapport, backup og eksplisitt oppdrag. Bruk den eksisterende tørrkjøringen igjen før eventuell apply.
6. Test fysisk iPhone/Safari og Android/Chrome, normal og privat fane, tastatur, bakgrunn/forgrunn og Google-avbrudd. Desktopverktøy beviser ikke at dette fungerer på fysiske telefoner.

## Reproduserbar kontroll

## Previewkontroll etter reCAPTCHA-godkjenning

Preview `https://time-plotting--security-review-ato21236.web.app` ble oppdatert
13. september etter bestått Flutter-analyse, 86 tester og releasebygg. Etter
at brukeren la domenet til reCAPTCHA, startet appen og viste ny logo,
«Resultater» og 18 arrangementer. Ingen nye feil kom i den observerte
nettleserloggen. Tre ekstra widgettester for innlogging på 320, 375 og
430 px med 300 px tastaturinnrykk besto. Dette er ikke fysiske mobiltester.
Samlet sluttkontroll etter disse tilleggene: Flutter-analyse uten merknader
og 89 beståtte tester.

Tidligere kontroller i denne gjennomgangen: importørens 56 tester og lint,
Firestore-emulatortester og Rundeanalyses 19 tester besto. Importørens
produksjonsavhengigheter har fortsatt tre moderate audit-funn (qs, uuid,
gaxios), men ingen høye/kritiske funn. Rundeanalyses audit viste null funn.
Backendtestene ble kjørt med lokal Node 24; produksjon bruker Node 22.

Etter brukerens eksplisitte oppdrag ble security-review klonet til live.
Kontroll på https://results.plotting.live viste ny logo, «Resultater» og
18 arrangementer uten feil eller advarsler i den observerte nettleserloggen.
Google-innlogging på fysiske telefoner og gammel mobilcache er fortsatt
åpne akseptansepunkter. Ingen IAM-, regel-, backend- eller dataendringer
er publisert.

### Kommandoer

`node security-inspect.mjs` leser IAM, regelversjon, autoriserte domener og App Check. Skriptet logger ikke tilgangstoken eller dokumentinnhold. Et korrekt x-goog-user-project er nødvendig; den innledende HTTP 403 skyldtes manglende kvoteprosjekt, ikke manglende IAM-rolle.

`bash deploy-web.sh preview` krever EQ_APP_CHECK_SITE_KEY, kjører Flutter-analyse og tester, bygger rent og validerer filene. `bash deploy-web.sh publish` kloner akkurat den kontrollerte previewversjonen. Tidligere live-versjon beholdes i Firebase Hosting for tilbakeføring.
