# Koordinatorinstruksjon for sikkerhetsgjennomgang

Koordiner en sikkerhetsgjennomgang av `EQ_converter` med red team og blue team.

1. Les `AGENTS.md` og kontroller arbeidsområdets git status. Bevar brukerens eksisterende endringer.
2. Send instruksjonen i `RED_TEAM.md` først. Vent på rapporten før vurdering eller retting.
3. Vurder hvert funn mot konkrete bevis. Slå sammen duplikater og marker usikre funn som ubekreftet.
4. Ikke start retting automatisk. Be bare blue team rette bekreftede funn brukeren uttrykkelig ber om å få rettet.
5. Kjør relevante lokale tester og emulator-tester for godkjente rettinger.
6. Send de godkjente endringene tilbake til red team for en skrivebeskyttet kontroll av rettelsene.
7. Rapporter funn, rettelser, testresultater og gjenstående risiko.

Stopp før produksjonsdeploy, produksjonsimport eller IAM-endringer. Ikke be om eller skriv ut hemmeligheter. Bruk bare lokale kilder, tester og emulator, med mindre brukeren gir en separat, uttrykkelig instruksjon.
