---
title: NSF-kategorirapporter kan inneholde hele seniorfeltet
date: "2026-11-12"
category: data-import
module: NSF-import
problem_type: workflow_issue
component: data_model
severity: medium
applies_when:
  - "En juniorkategori deler livefelt med seniorer"
tags: [nsf, langrenn, category-coverage, import-validation]
---

# NSF-kategorirapporter kan inneholde hele seniorfeltet

## Context

Ved kontroll av NC 2025/26 var filnavn, klasseoverskrift og trykt deltakerantall
utilstrekkelige til å avgjøre hvilke rader som tilhørte en juniorkategori.
Dette er en egenskap ved de undersøkte kildene, ikke en generell regel for
alle NSF-rapporter.

## Guidance

I Åsen-rennet 2041 inneholder de publiserte U20-rapportene kategoriens plasserte
løpere, men arver seniorfeltets totalantall og terminale statusrader. Kvinner
har 117 klassifiserte U20-løpere og trykt foreldretotal 228; menn har 192 og
396. Bruk de eksplisitt klassifiserte radene som kategoribevis. Behold DNS/DNF
i forelderklassen når kilden ikke avgjør kategoritilhørigheten. Ikke fordel
slike rader ved å gjette fra startnummer eller navn.

For Lygna 2446 kan det offentlige kategoriutvalget sammenholdes med de korte
offisielle listene. Avstem alle klassifiserte rader mot navn eller trykt
navneprefiks, startnummer og sluttid i samme renn og forelderfelt. Et kjent
kategorimedlem kan mangle i kategoriutvalget selv om passeringene finnes i
seniorfeltet. Offisiell kategoriplassering og forelderens registrerte tider
har forskjellige roller i denne avstemmingen.

Dersom begge klassevisninger importeres, deklarer forholdet i eksporten:

```json
{"id": "u20", "name": "U20", "categoryOf": "senior"}
```

`categoryOf` valideres i `eq-importer/functions/nsf-normalize.js` mot en kjent,
selvstendig distanseklasse, samme konkurranseledd og entydig identitet med
samsvarende status og tider. Det påvirker arrangementets deltakerantall;
begge klassevisningene beholdes. Uavhengige klasser dedupliseres ikke på navn.
Regresjonene ligger i `eq-importer/functions/__tests__/nsf-normalize.test.js`.

## Why This Matters

Å summere de avledede kategoriene en gang til ga 1380 i stedet for 1071
deltakere i 2041, og 1504 i stedet for 868 i 2446. Å stole på den arvede
PDF-totalen ville dessuten tildelt personer en klasse kilden ikke dokumenterer.

## When to Apply

Ved nye eller korrigerte kategorirapporter: undersøk også rader uten
plassering, og avstem medlemskapet før et deltakerantall bekreftes. Et trykt
antall på null eller en arvet foreldretotal er ikke en bekreftet kategoritotal.
En manuell eksport må bevare avstemmingsgrunnlaget og eventuelle dekningshull.

## Related

- [Åsen offisielle lister](https://www.skiforbundet.no/arrangement/2025-2026/aasenscan26/start--og-resultatlister/)
- [Lygna offisielle lister](https://www.skiforbundet.no/arrangement/2025-2026/nm2lygna/start_og_resultatlister/)
- [Operatørguiden](../../eq-importer/NSF-IMPORT.md)
