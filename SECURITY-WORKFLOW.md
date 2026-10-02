# Sikkerhetsflyt for EQ_converter

## Roller og godkjenning

Rolleinstruksjonene ligger i `.codex/security/RED_TEAM.md`,
`.codex/security/BLUE_TEAM.md` og `.codex/security/COORDINATOR.md`.
Dette er instruksjoner, ikke et kjørende agentoppsett. Det opprettes ikke
agenter eller automatiske rettinger bare ved å legge filene i repoet.

Flyten er: skrivebeskyttet gjennomgang → vurdering av bevis → eksplisitt
godkjent retting → regresjonstest → ny skrivebeskyttet gjennomgang.
Produksjonsdeploy, import og IAM-endringer krever egne oppdrag.

## Isolasjon

- CI bruker nye GitHub-hostede Ubuntu-runnere uten produksjonsnøkler.
- GitHub-tokenet har bare `contents: read`, og checkout lagrer ikke
  påloggingsdata i Git-konfigurasjonen.
- Firestore-regeltester kjøres i emulatoren med `demo-eq-results` eksplisitt.
  Ingen Firebase-innlogging eller produksjonsservicekonto skal legges til.
- Bruk ikke den innloggede produksjonsmaskinen som sikkerhetstestmiljø.
  Et Git-worktree skiller filer, men isolerer ikke maskinens credentials.
  Agenter i samme miljø kan få tilgang til samme filer og credentials.
- Ikke publiser sårbarhetsdetaljer, råpayloads, nøkler eller tokens i åpne PR-er.

## Automatiske kontroller

`.github/workflows/security-checks.yml` kjører på PR-er til `main`, push til
`main` og manuell oppstart. Disse jobbnavnene brukes som påkrevde kontroller:

- `importer-tests`: importørens lint og tester.
- `firestore-rules`: regeltester mot den lokale demo-emulatoren.
- `flutter`: pakker, lokalisering, format, analyse og tester.
- `dependency-audit`: produksjonsavhengigheter, feil ved high/critical.

Jobbene har tidsgrenser. Eldre, overlappende kjøringer av samme PR avbrytes.
Actions er låst til full commit-ID, ikke flyttbare versjonstagger.

Flyten forutsetter at importøren har `firebase-tools`,
`@firebase/rules-unit-testing` og `test:rules`, at `firebase.test.json` finnes,
og at regeltestene finnes. Den eldre GitHub-versjonen fra juli 2026 mangler
deler av dette. Publiser de tilsiktede produktendringene separat; ikke fjern
regelkontrollen eller svekk testene for å gjøre denne eldre versjonen grønn.

## Beskyttelse av main

Oppsettet krever PR, oppdatert gren og de fire beståtte kontrollene over.
Det kreves ikke godkjenning fra en annen person. Reglene gjelder også
administratorer. Force-push og sletting av `main` skal være avvist.

Når sikkerhetsflyten bare finnes på en PR-gren, kan `main` ikke produsere
disse kontrollene ennå. Sikkerhets-PR-en og de nødvendige produktendringene
må få grønne tester før de kan slås sammen. Ingen tester skal omgås.

## Godkjenning før produksjonsdeploy

GitHub-miljøet `production` skal ha `Simon-send` som påkrevd godkjenner.
Egen godkjenning er tillatt fordi repoet bare har én administrator.
Kun beskyttede grener skal kunne bruke miljøet. Oppsettet legger ikke inn
produksjonsnøkler eller gir noen ny tilgang til Firebase.

Miljøet beskytter bare jobber som faktisk deklarerer det:

```yaml
jobs:
  deploy:
    if: github.ref == 'refs/heads/main'
    environment: production
```

Det er ingen deployjobb i sikkerhetsflyten. En senere deployjobb skal vente
på de fire testene, bruke `environment: production` og autentisere med
minste nødvendige tilgang. Ikke legg deploycredentials i testjobbene.
GitHub-godkjenningen blokkerer ikke lokale Firebase- eller gcloud-kommandoer.

## Kilder

- [OpenAI: isolasjon av agentmiljøer](https://developers.openai.com/api/docs/guides/agents-api/environments/self-hosted)
- [GitHub: environments og godkjenning](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments)
- [GitHub: beskyttede grener](https://docs.github.com/en/rest/branches/branch-protection)
