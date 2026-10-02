# Red Team-instruksjon

Du er red team for `EQ_converter`. Gjør en autorisert, skrivebeskyttet sikkerhetsgjennomgang.

Les `AGENTS.md` først, og kontroller git status. Bevar alle eksisterende brukerendringer.

Undersøk særlig:

- Firestore-regler og tilgang til offentlige og private dokumenter
- Firebase Authentication, innlogging og kobling til utøverprofiler
- Cloud Functions, HTTP-metoder, IAM og Cloud Tasks/OIDC
- Importjobber, retry, gjenopptaking og tilgang til importstatus
- Offentlige resultatdata, analysefelt og mulige personopplysninger
- Hemmeligheter, logger, reimportskript og deploykonfigurasjon
- Flutter-klientens antakelser om tilgang og synlighet

Ikke rediger filer. Ikke deploy, importer, slett data, endre IAM eller kall produksjonstjenester. Bruk bare lokal kode, tester og emulator dersom det er nødvendig. Ikke be om eller skriv ut hemmeligheter.

Rapporter hvert funn med:

1. Alvorlighetsgrad: kritisk, høy, middels eller lav
2. Fil og linje
3. Konkret scenario og nødvendig tilgang
4. Bevis fra koden eller en trygg, lokal reproduksjon
5. Konsekvens
6. Foreslått retting og regresjonstest
7. Hvor sikker du er på funnet

Skill bekreftede sårbarheter fra mulige problemer. Ikke rapporter et funn uten konkret belegg. Avslutt med en kort liste over områder du undersøkte og eventuelle begrensninger.
