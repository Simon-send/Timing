# Sikkerhetsoppsett

## Punkt 1: standard Compute-servicekonto med `roles/editor`

Dette er den viktigste sikkerhetsendringen. Cloud Functions skal bruke
`eq-import-runtime`, med bare tilgang til Firestore og Cloud Tasks. Standard
Compute-servicekontoen skal ikke brukes av funksjonene og skal ikke ha
`roles/editor`. Google bruker likevel denne kontoen som byggkonto i dette
prosjektet, så den beholder den avgrensede standardrollen
`roles/cloudbuild.builds.builder`.

Kjør på Mac fra repoet:

```zsh
gcloud auth login
gcloud config set project time-plotting
cd "/Users/simon/Documents/Projekter/Data/EQ_converter/eq-importer"
chmod +x ./configure-production.sh
./configure-production.sh "user:$(gcloud config get-value account)"
npx --yes firebase-tools@latest deploy --only functions
./configure-production.sh "user:$(gcloud config get-value account)" --remove-legacy-editor
```

Den første kjøringen oppretter runtime- og Cloud Tasks-servicekontoene og gir
runtime-identiteten disse begrensede tilgangene:

- `roles/datastore.user` for Firestore.
- `roles/cloudtasks.enqueuer` for importkøen.
- `roles/iam.serviceAccountUser` på `import-tasks`, slik at Cloud Tasks kan
  bruke OIDC til worker-funksjonen.

Den gir også standard Compute-servicekontoen
`roles/cloudbuild.builds.builder`. Rollen er nødvendig for å lese Functions-
kildepakken og skrive byggeartefakter, men gir ikke den brede prosjekttilgangen
som `roles/editor` gjorde.

Deretter deployes funksjonene på nytt. Først når deployen er kontrollert, skal
den siste kommandoen fjerne `roles/editor` fra standard Compute-
servicekontoen. Denne rekkefølgen hindrer at funksjonene mister tilgang før de
har byttet identitet.

Kontroller resultatet:

```zsh
gcloud functions describe startImportEvent --gen2 --region=europe-west1 \
  --project=time-plotting --format='value(serviceConfig.serviceAccountEmail)'
gcloud projects get-iam-policy time-plotting \
  --flatten='bindings[].members' \
  --filter='bindings.role:roles/editor AND bindings.members:serviceAccount:' \
  --format='table(bindings.members)'
```

Forventet runtime-identitet er
`eq-import-runtime@time-plotting.iam.gserviceaccount.com`. Den andre kontrollen
skal ikke vise standard Compute-servicekontoen. Hvis andre produksjonstjenester
bruker denne servicekontoen, må de flyttes til egne identiteter før den gamle
rollen fjernes.

Ikke legg inn service account-nøkler, OAuth-hemmeligheter eller reCAPTCHA
secret key i repoet. En reCAPTCHA site key er offentlig, men secret key er
ikke det.

## Punkt 2: lås import-endepunktene

Funksjonene er satt til `invoker: "private"`. Cloud Run/IAM avviser dermed
forespørsler før koden kjører. Cloud Tasks bruker en OIDC-token fra
`import-tasks`, og skriptet kontrollerer at brede medlemmer som `allUsers` og
`allAuthenticatedUsers` ikke finnes.

For punkt 2 gjør du dette i denne rekkefølgen. Den første kjøringen gir
deploy-brukeren og Cloud Tasks riktig tilgang før ny deploy:

```zsh
cd "/Users/simon/Documents/Projekter/Data/EQ_converter/eq-importer"
OPERATOR_MEMBER="user:$(gcloud config get-value account)"
./configure-production.sh "$OPERATOR_MEMBER"
npx --yes firebase-tools@latest deploy --only functions
./configure-production.sh "$OPERATOR_MEMBER"
```

`--remove-legacy-editor` hører til punkt 1 og skal ikke brukes som en del av
denne testen med mindre du også vil fjerne den gamle brede rollen etter at
funksjonene er kontrollert.

Test deretter tilgang uten å starte en import:

```zsh
STATUS_URI="https://europe-west1-time-plotting.cloudfunctions.net/getImportStatus"

# Skal svare 403 uten token.
curl -i "$STATUS_URI?jobId=missing-job"

# Skal svare 404, ikke 403, med operatørens Google ID-token.
# For en vanlig brukerkonto skal --audiences ikke brukes.
TOKEN="$(gcloud auth print-identity-token)"
curl -i -H "Authorization: Bearer $TOKEN" \
  "$STATUS_URI?jobId=missing-job"
```

Forventet resultat betyr at IAM fungerer: `403` uten token og `404 Job not
found` med gyldig operatør-token. Ikke test `startImportEvent` med gyldig token
med mindre du faktisk ønsker å starte en produksjonsimport.

## Punkt 3: fjern interne registreringsdata fra offentlige dokumenter

Nye importer skriver ikke lenger kjønn, fødselsår, alder, interne EQ-ID-er,
timing-ID-er eller registreringsstatus til offentlige resultat- og
utøverdokumenter. Detaljert skiskytteranalyse ligger under `privateAnalysis`,
som Firestore-reglene avviser for alle klienter.

Eksisterende dokumenter må ryddes én gang. Skriptet under er en tørrkjøring som
standard. Det skriver først når både `--apply` og nøyaktig prosjektbekreftelse
er oppgitt. Det logger bare antall dokumenter, ikke navn eller innhold.

Autentiser lokal Admin SDK mot riktig prosjekt:

```zsh
gcloud auth application-default login
gcloud auth application-default set-quota-project time-plotting
```

Deploy først importørkoden og Firestore-reglene som hindrer at feltene kommer
tilbake eller at private analysedokumenter blir lest:

```zsh
cd "/Users/simon/Documents/Projekter/Data/EQ_converter/eq-importer"
OPERATOR_MEMBER="user:$(gcloud config get-value account)"
./configure-production.sh "$OPERATOR_MEMBER"
npx --yes firebase-tools@latest deploy --only functions,firestore:rules
./configure-production.sh "$OPERATOR_MEMBER"
```

Den siste linjen gjenoppretter og verifiserer de private invoker-policyene fra
punkt 2 etter functions-deploy.

Kjør så en skrivebeskyttet rapport:

```zsh
cd "/Users/simon/Documents/Projekter/Data/EQ_converter/eq-importer/functions"
npm run security:scrub-public -- --project=time-plotting
```

Kontroller at rapporten sier `Project: time-plotting`. Utfør deretter
oppryddingen:

```zsh
npm run security:scrub-public -- \
  --project=time-plotting \
  --apply \
  --confirm-project=time-plotting
```

Kjør til slutt tørrkjøringen på nytt. Både utøver- og resultatantallet skal da
være `0`. Selve oppryddingen beholder navn, startnummer, klubb, resultat,
splitter og andre data appen trenger.
