# Produksjonsdeploy

## Status 18. juli 2026

Fakturering er nå aktiv på `time-plotting`, og webpakken er bygget med en
offentlig reCAPTCHA v3 site key for Firebase App Check. Ikke lagre site key eller
secret i kildekoden; en tidligere delt secret skal roteres i reCAPTCHA-konsollen.

Produksjonsdeploy er nå gjennomført:

- Firestore-regler og indekser er publisert.
- `startImportEvent`, `runImportEventChunk` og `getImportStatus` kjører i
  `europe-west1`.
- Cloud Tasks-køen `imports` kjører i `europe-west1` med OIDC og begrenset
  invoker-tilgang.
- Firebase Hosting er publisert på `https://time-plotting.web.app`.

Firestore-regeltesten er kjørt og består (3 av 3) med Java 21. Java 21 må være
tilgjengelig for å kjøre samme emulatorbaserte kontroll på nytt lokalt eller i CI.

Functions-lint og alle 40 backendtester er også kjørt eksplisitt med Node
22.23.1. Runtimeversjonen er dermed verifisert før deploy.

De tidligere Gen 2-funksjonene i `us-central1` er fjernet etter at invoker-tilgang
ble låst ned. En autentisert status-smoketest returnerer forventet 404 for en
ukjent jobb.

Første produksjonsmål er Firebase Hosting for en responsiv webapp. Native
Android/iOS er ikke del av denne leveransen.

## Forutsetninger

- Bruk Node 22 for Functions.
- `firebase login` og `gcloud auth login` må være utført av driftsansvarlig.
- Firebase App Check for web må ha en reCAPTCHA v3-nøkkel.
- Google Cloud-fakturering må være aktivert fordi importkøen bruker Cloud Tasks.
- `OperatorMember` oppgis som for eksempel `user:drift@example.no`.

## Kontroll og bygg

```powershell
Set-Location functions
npm ci
npm run verify:deploy
npm run verify:rules

Set-Location ../../results
flutter pub get
flutter analyze
flutter test
flutter build web --release `
  --dart-define=FIREBASE_APP_CHECK_SITE_KEY=<recaptcha-site-key>

Set-Location ../eq-importer
powershell -NoProfile -File .\prepare-hosting.ps1
```

## Deployrekkefølge

```powershell
Set-Location ../eq-importer
firebase deploy --only firestore:rules,firestore:indexes
firebase deploy --only functions
powershell -NoProfile -File configure-production.ps1 `
  -OperatorMember "user:drift@example.no"
firebase deploy --only hosting
```

Kjør én kontrollert import og verifiser resultatene før App Check settes fra
overvåking til håndheving i Firebase-konsollen. Gamle funksjoner i
`us-central1`, inkludert `importFromEqTimingUrls`, slettes først etter at den nye
flyten i `europe-west1` er verifisert.
