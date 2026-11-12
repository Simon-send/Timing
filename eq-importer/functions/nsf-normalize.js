"use strict";

/* eslint-disable require-jsdoc, valid-jsdoc, max-len */

const {createHash} = require("node:crypto");

const SPRINT_PHASES = ["prolog", "quarterfinal", "semifinal", "final"];
const PHASE_ORDER = ["distance", ...SPRINT_PHASES];
const STATUSES = new Map(Object.entries({
  "": "", "OK": "", "FIN": "", "FINISHED": "", "DNS": "DNS", "DNF": "DNF",
  "DSQ": "DSQ", "DFQ": "DSQ", "DQ": "DSQ", "DISQUALIFIED": "DSQ", "DQB": "DSQ",
  "LAP": "LAP", "LAPPED": "LAP", "NQ": "NC", "DNQ": "NC", "NPS": "NPS", "NP": "NPS", "OTL": "OTL", "RAL": "RAL", "NC": "NC",
}));

function digest(value) {
  return createHash("sha256").update(stableJson(value)).digest("hex");
}

function stableJson(value) {
  if (Array.isArray(value)) return `[${value.map(stableJson).join(",")}]`;
  if (value && typeof value === "object") {
    return `{${Object.keys(value).sort().map((key) =>
      `${JSON.stringify(key)}:${stableJson(value[key])}`).join(",")}}`;
  }
  return JSON.stringify(value);
}

function text(value) {
  return typeof value === "string" ? value.trim() : "";
}

function normalized(value) {
  return text(value).normalize("NFKC").toLowerCase().replace(/\s+/gu, " ");
}

function array(value) {
  return Array.isArray(value) ? value : [];
}

function key(value) {
  const candidate = typeof value === "number" ? String(value) : text(value);
  return /^[A-Za-z0-9][A-Za-z0-9._-]{0,119}$/.test(candidate) ? candidate : null;
}

function positiveInt(value) {
  return Number.isSafeInteger(value) && value > 0 ? value : null;
}

function dateOnly(value) {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return null;
  const date = new Date(value);
  return !Number.isNaN(date.valueOf()) && date.toISOString().slice(0, 10) === value ?
    value : null;
}

function displaySort(a, b) {
  return Number(Boolean(a.status)) - Number(Boolean(b.status)) ||
    (a.rank ?? Infinity) - (b.rank ?? Infinity) ||
    a.entrant.name.localeCompare(b.entrant.name, "nb") ||
    a.id.localeCompare(b.id);
}

function normalizeRow(raw, location, error) {
  if (!raw || typeof raw !== "object" || !text(raw.name)) {
    error(location, "Resultatrad mangler navn.");
    return null;
  }
  const statusKey = text(raw.status).toUpperCase();
  if (!STATUSES.has(statusKey)) {
    error(location, `Ukjent resultatstatus: ${statusKey}.`);
    return null;
  }
  const rank = positiveInt(raw.rank);
  const totalMs = positiveInt(raw.totalMs);
  if ((raw.rank != null && !rank) || (raw.totalMs != null && !totalMs)) {
    error(location, "Resultatet inneholder ugyldig plassering eller sluttid.");
    return null;
  }
  if (raw.athleteId != null && typeof raw.athleteId !== "string" &&
      !positiveInt(raw.athleteId)) {
    error(location, "Kilde-ID for utøver må være tekst eller et positivt heltall.");
    return null;
  }
  const bib = typeof raw.bib === "number" ? String(raw.bib) : text(raw.bib);
  return {
    name: text(raw.name),
    sourceId: text(String(raw.athleteId ?? "")),
    club: text(raw.club),
    team: text(raw.team),
    country: text(raw.country),
    bib,
    rank,
    status: raw.unranked === true && !rank && !statusKey ? "NC" : STATUSES.get(statusKey),
    totalMs,
    points: raw.points && typeof raw.points === "object" && !Array.isArray(raw.points) ?
      raw.points : {},
  };
}

function makeEntrant(eventId, classId, row, disambiguate) {
  const identity = row.sourceId ? ["source", row.sourceId] : [
    "name", normalized(row.name),
    ...(disambiguate ? [normalized(row.club), normalized(row.country)] : []),
  ];
  return {...row, id: `nsf-${digest([eventId, classId, ...identity]).slice(0, 32)}`};
}

function matchingEntrants(row, candidates) {
  if (row.sourceId) {
    const byId = candidates.filter((entry) => entry.sourceId === row.sourceId);
    if (byId.length) return byId;
  }
  return candidates.filter((entry) => {
    if (row.sourceId && entry.sourceId && row.sourceId !== entry.sourceId) return false;
    if (normalized(row.name) !== normalized(entry.name)) return false;
    return (!row.club || !entry.club || normalized(row.club) === normalized(entry.club)) &&
      (!row.country || !entry.country || normalized(row.country) === normalized(entry.country));
  });
}

function buildPoints(rawPoints, location, error) {
  const ids = new Set();
  const points = [];
  for (const raw of array(rawPoints)) {
    const id = key(raw?.id);
    if (!id || ids.has(id) || !text(raw?.label) ||
        !["split", "finish"].includes(raw?.kind)) {
      error(location, "Målepunkt mangler gyldig, unik ID, navn eller type.");
      continue;
    }
    if (raw.km != null && !(typeof raw.km === "number" &&
        Number.isFinite(raw.km) && raw.km > 0)) {
      error(location, "Målepunkt har ugyldig distanse.");
      continue;
    }
    ids.add(id);
    points.push({
      id, code: text(raw.label), kind: raw.kind, sort: points.length,
      ...(raw.km == null ? {} : {km: raw.km}),
    });
  }
  const finishes = points.filter((point) => point.kind === "finish");
  if (!finishes.length && !ids.has("finish")) {
    points.push({id: "finish", code: "Mål", kind: "finish", sort: points.length});
  } else if (finishes.length !== 1 || points.at(-1)?.kind !== "finish") {
    error(location, "Det må være nøyaktig ett målpunkt sist i løypa.");
  }
  return points;
}

function buildTimingPoints(row, defs, location, error) {
  const values = [];
  const ids = new Set(defs.map((point) => point.id));
  for (const id of Object.keys(row.points)) {
    if (!ids.has(id)) error(location, `Ukjent målepunkt: ${id}.`);
  }
  let previous = 0;
  let latestMeasured = 0;
  for (const point of defs) {
    const measurement = Object.hasOwn(row.points, point.id) ? row.points[point.id] : null;
    const cumMs = positiveInt(measurement?.cumMs) ??
      (point.kind === "finish" ? row.totalMs : null);
    if (measurement?.cumMs != null && !positiveInt(measurement.cumMs)) {
      error(location, `Ugyldig passering ved ${point.code}.`);
    }
    if (point.kind === "finish" && cumMs != null && row.totalMs != null &&
        cumMs !== row.totalMs) {
      error(location, "Måltid og sluttid stemmer ikke overens.");
    }
    if (cumMs == null) {
      previous = null;
      continue;
    }
    if (cumMs < latestMeasured) {
      error(location, `Passering ved ${point.code} er før en tidligere passering.`);
    }
    const cumRank = positiveInt(measurement?.rank) ??
      (point.kind === "finish" ? row.rank : null);
    values.push({
      setupUid: point.id, code: point.code, kind: point.kind, sort: point.sort, cumMs,
      ...(point.km == null ? {} : {km: point.km}),
      ...(previous != null && cumMs > previous ? {legMs: cumMs - previous} : {}),
      ...(cumRank ? {cumRank} : {}),
    });
    previous = cumMs;
    latestMeasured = cumMs;
  }
  return values;
}

function participant(row, entrant) {
  const clubName = row.club || entrant.club;
  const teamName = row.team || entrant.team;
  const country = row.country || entrant.country;
  return {
    kind: "athlete", name: entrant.name,
    ...(row.bib ? {bib: row.bib} : {}),
    ...(clubName ? {clubName} : {}),
    ...(teamName ? {teamName} : {}),
    ...(country ? {country} : {}),
  };
}

function resultData({eventId, classId, stageId, row, entrant, defs, error}) {
  const result = {
    id: entrant.id,
    schemaVersion: 3,
    eventId, classId, stageId,
    entrant: participant(row, entrant),
    status: row.status,
    ...(row.rank && !row.status ? {rank: row.rank, finishRank: row.rank} : {}),
    resultAuthority: row.officialResult || stageId === "sprint-overall" ? "official" : "live",
  };
  if (stageId === "sprint-overall") {
    return {...result, resultKind: "classification", hasTimingData: false,
      ...(row.status ? {officialStatus: true} : {})};
  }
  const timingRow = row.status ? {...row, totalMs: null, points: Object.fromEntries(
      Object.entries(row.points).filter(([id]) => defs.find((point) => point.id === id)?.kind !== "finish"),
  )} : row;
  const timingPoints = buildTimingPoints(timingRow, defs, `${classId}/${stageId}/${row.bib}`, error);
  const totalMs = timingPoints.find((point) => point.kind === "finish")?.cumMs;
  return {
    ...result,
    hasTimingData: timingPoints.length > 0,
    splitLegsAuthoritative: true,
    finishConfirmed: !row.status && totalMs != null,
    ...(row.officialStatus ? {officialStatus: true} : {}),
    ...(totalMs == null ? {} : {totalMs}),
    ...(timingPoints.length ? {timingPoints} : {}),
  };
}

function pointSignature(point) {
  return [point.kind, point.km ?? null, normalized(point.code)];
}

function mean(values) {
  return Math.round(values.reduce((sum, value) => sum + value, 0) / values.length);
}

function buildPodium(timedGroups, officialRows, warn, error, classId) {
  const places = [1, 2, 3].map((rank) =>
    officialRows.filter((row) => row.rank === rank && !row.status));
  if (places.some((matches) => matches.length !== 1)) {
    warn(classId, "Topp 3 er ikke tilgjengelig: sluttlista mangler en entydig pall.");
    return;
  }
  const podium = new Set(places.map(([row]) => row.id));
  const phases = Map.groupBy(timedGroups, (group) => group.stage.phase);
  for (const [phase, groups] of phases) {
    const observations = new Set();
    for (const group of groups) {
      for (const row of group.results) {
        if (!podium.has(row.id)) continue;
        if (observations.has(row.id)) {
          error(classId, `Pallutøver forekommer i flere heat i samme fase (${phase}).`);
        }
        observations.add(row.id);
      }
    }
    const compatible = Map.groupBy(groups, (group) => JSON.stringify([
      group.courseKey || group.stage.courseKey || group.stage.id,
      group.distanceKm ?? group.stage.distanceKm ?? null,
      group.points.map(pointSignature),
    ]));
    for (const compatibleGroups of compatible.values()) {
      const buckets = compatibleGroups[0].points.map(() => ({cum: [], leg: []}));
      for (const group of compatibleGroups) {
        for (const row of group.results) {
          if (row.status || row.finishConfirmed !== true || !podium.has(row.id)) continue;
          const times = new Map(array(row.timingPoints).map((value) => [value.setupUid, value]));
          group.points.forEach((point, index) => {
            const value = times.get(point.id);
            if (!value) return;
            buckets[index].cum.push(value.cumMs);
            if (value.legMs != null) buckets[index].leg.push(value.legMs);
          });
        }
      }
      for (const group of compatibleGroups) {
        const points = Object.fromEntries(group.points.flatMap((point, index) => {
          const {cum, leg} = buckets[index];
          return cum.length ? [[point.id, {
            cumMeanMs: mean(cum), cumCount: cum.length,
            ...(leg.length ? {legMeanMs: mean(leg), legCount: leg.length} : {}),
          }]] : [];
        }));
        if (Object.keys(points).length) group.sprintPodium = {phase, points};
      }
    }
  }
}

function verifiedCategory(raceClass, parent, error) {
  const identity = (result) => ({
    name: result.entrant.name, club: result.entrant.clubName || "",
    country: result.entrant.country || "", sourceId: "", result,
  });
  let valid = true;
  for (const group of raceClass.groups) {
    const parentGroup = parent.groups.find((item) => item.stage.id === group.stage.id);
    if (!parentGroup) {
      error(raceClass.id, "Kategorien mangler samme konkurranseledd i forelderklassen.");
      valid = false;
      continue;
    }
    const candidates = parentGroup.results.map(identity);
    const members = new Set();
    for (const result of group.results) {
      const matches = matchingEntrants(identity(result), candidates);
      const parentResult = matches.length === 1 ? matches[0].result : null;
      const parentPoints = new Map((parentResult?.timingPoints || [])
          .map((point) => [point.setupUid, point]));
      const differentTiming = (result.timingPoints || []).some((point) => {
        const original = parentPoints.get(point.setupUid);
        return !original || point.cumMs !== original.cumMs || point.legMs !== original.legMs;
      });
      if (!parentResult || members.has(parentResult.id) ||
          result.status !== parentResult.status || result.totalMs !== parentResult.totalMs ||
          differentTiming) {
        error(raceClass.id, "Kategorimedlemmet må ha entydig identitet, status og tider i forelderklassen.");
        valid = false;
      } else {
        members.add(parentResult.id);
      }
    }
  }
  return valid;
}

function prepareNsfImport(source) {
  const issues = [];
  const issue = (severity) => (location, message) => issues.push({severity, location, message});
  const error = issue("error");
  const warn = issue("warning");
  const prologOnly = source?.sprintPrologOnly === true;
  const meta = source?.event;
  const sourceId = String(meta?.id ?? "");
  const name = text(meta?.name);
  const place = text(meta?.place);
  const date = dateOnly(meta?.date);
  if (source?.schemaVersion !== 1 || !/^[1-9]\d{0,11}$/.test(sourceId)) {
    error("renn", "Krever NSF-eksport versjon 1 med gyldig renn-ID.");
  }
  if (!name || !date || !place) {
    error("renn", "Rennnavn, gyldig dato og sted må være bekreftet før import.");
  }
  const eventId = `nsf-${sourceId}`;
  const eventPath = `events/${eventId}`;
  const classRows = new Map();
  const stages = new Map();
  const docs = [];
  const summary = [];
  const put = (path, data) => docs.push({path, data});
  const classIds = new Set();
  for (const item of array(source?.classes)) {
    const id = key(item?.id);
    if (!id || !text(item?.name) || classIds.has(id)) {
      error("klasser", "Klasse mangler gyldig, unik ID eller navn.");
      continue;
    }
    classIds.add(id);
    classRows.set(id, {...item, id, groups: []});
  }
  if (!classRows.size) error("klasser", "Kilden inneholder ingen klasser.");
  let hasSprint = false;
  let hasDistance = false;
  for (const raw of array(source?.stages)) {
    const id = key(raw?.id);
    if (!id || id === "sprint-overall" || stages.has(id) ||
        !PHASE_ORDER.includes(raw?.phase) || !text(raw?.name)) {
      error("ledd", "Konkurranseledd mangler gyldig, unik ID, navn eller fase.");
      continue;
    }
    const distanceKm = typeof raw.distanceKm === "number" &&
      Number.isFinite(raw.distanceKm) && raw.distanceKm > 0 ? raw.distanceKm : null;
    const stage = {
      id, name: prologOnly && raw.phase === "prolog" ? "Prolog (heat avlyst)" : text(raw.name),
      phase: raw.phase, distanceKm,
      courseKey: text(raw.courseKey), groups: [],
      order: Number.isSafeInteger(raw.order) ? raw.order : PHASE_ORDER.indexOf(raw.phase) * 100,
    };
    stages.set(id, stage);
    if (stage.phase === "distance") hasDistance = true;
    else hasSprint = true;
    const seen = new Set();
    for (const group of array(raw.classes)) {
      const classId = key(group?.classId);
      const raceClass = classRows.get(classId);
      const location = `${id}/${classId}`;
      if (!raceClass || seen.has(classId)) {
        error(location, "Konkurranseledd peker på ukjent eller gjentatt klasse.");
        continue;
      }
      seen.add(classId);
      const rows = array(group.rows).map((row) => normalizeRow(row, location, error)).filter(Boolean);
      if (!rows.length) error(location, "Konkurranseleddet har ingen resultatrader.");
      const resultGroup = {
        stage, classId, rows, points: buildPoints(group.points, location, error),
        courseKey: text(group.courseKey), distanceKm: group.distanceKm,
        official: array(group.official), results: [],
      };
      stage.groups.push(resultGroup);
      raceClass.groups.push(resultGroup);
    }
    if (!stage.groups.length) error(id, "Konkurranseleddet mangler klasser.");
  }
  if (!stages.size || (hasSprint && hasDistance)) {
    error("ledd", "Én NSF-import må inneholde enten individuelle distanseledd eller én sprint.");
  }
  if (prologOnly && (!hasSprint || [...stages.values()].some((stage) => stage.phase !== "prolog"))) {
    error("ledd", "En prolog-only-eksport kan bare inneholde sprintens prolog, uten senere heat.");
  }
  const overall = {id: "sprint-overall", name: "Sluttresultat", phase: "overall", order: -1, groups: []};
  let participantCount = 0;
  const classParticipantCounts = new Map();
  for (const raceClass of classRows.values()) {
    const classId = raceClass.id;
    const timedGroups = [...raceClass.groups].sort((a, b) => a.stage.order - b.stage.order);
    const initial = timedGroups[0];
    const officialInput = prologOnly && !array(raceClass.official).length ?
      initial?.official : raceClass.official;
    const official = array(officialInput)
        .map((row) => normalizeRow(row, classId, error)).filter(Boolean);
    const expected = positiveInt(raceClass.expectedCount);
    if (!initial) {
      error(classId, "Klassen mangler konkurranseledd.");
      continue;
    }
    if (hasSprint && !prologOnly && (!official.length ||
        !timedGroups.some((group) => group.stage.phase === "prolog") ||
        !timedGroups.some((group) => group.stage.phase === "final"))) {
      error(classId, "Sprint krever offisiell sluttliste, prolog og finale.");
    }
    if (prologOnly && (!official.length || !expected || timedGroups.length !== 1)) {
      error(classId, "Sprint med avlyste heat krever én prolog og en komplett offisiell prologliste med deltakerantall.");
    }
    const seeded = official.length ? official : initial.rows;
    const nameCounts = new Map();
    for (const row of seeded) {
      const nameKey = normalized(row.name);
      nameCounts.set(nameKey, (nameCounts.get(nameKey) || 0) + 1);
    }
    const entrants = seeded.map((row) =>
      makeEntrant(eventId, classId, row, nameCounts.get(normalized(row.name)) > 1));
    if (new Set(entrants.map((row) => row.id)).size !== entrants.length) {
      error(classId, "Deltakeridentitet i kildelista er ikke entydig.");
    }
    const officialById = new Map(official.length ? entrants.map((row) => [row.id, row]) : []);
    if (expected && expected !== entrants.length) {
      error(classId, `Offisielt antall er ${expected}, men ${entrants.length} rader er avstemt.`);
    }
    if (!expected) {
      warn(classId, "Kilden har ikke et uavhengig bekreftet deltakerantall.");
    }
    if (official.length && official.some((row) => !row.rank && !row.status)) {
      error(classId, "Offisiell resultatliste har rader uten plassering eller status.");
    }
    if ((!hasSprint || prologOnly) && official.some((row) => !row.status && (!row.rank || !row.totalMs))) {
      error(classId, `Offisiell ${prologOnly ? "prologliste" : "distanseliste"} må ha både plassering og sluttid for fullførte utøvere.`);
    }
    const seenTimed = new Set();
    const entrantAffiliations = new Map();
    for (const group of timedGroups) {
      const seen = new Set();
      const groupOfficial = (!hasSprint || prologOnly) && official.length ?
        officialById : new Map();
      for (const input of prologOnly && officialInput === group.official ? [] : group.official) {
        const row = normalizeRow(input, classId, error);
        if (!row) continue;
        const matches = matchingEntrants(row, entrants);
        if (matches.length !== 1 || groupOfficial.has(matches[0]?.id) ||
            (!row.status && (!row.rank || !row.totalMs))) {
          error(classId, `Uavklart offisiell rad i ${group.stage.name}.`);
        } else {
          groupOfficial.set(matches[0].id, row);
        }
      }
      for (const rawRow of group.rows) {
        const matches = matchingEntrants(rawRow, entrants);
        if (matches.length !== 1 || seen.has(matches[0]?.id)) {
          error(classId, `Startnummer ${rawRow.bib || "ukjent"} i ${group.stage.name} har ingen entydig kobling.`);
          continue;
        }
        const [entrant] = matches;
        seen.add(entrant.id);
        seenTimed.add(entrant.id);
        const affiliation = entrantAffiliations.get(entrant.id) || {};
        entrantAffiliations.set(entrant.id, {
          club: affiliation.club || rawRow.club,
          team: affiliation.team || rawRow.team,
          country: affiliation.country || rawRow.country,
        });
        let row = rawRow;
        const finalRow = groupOfficial.get(entrant.id);
        if (finalRow) {
          if ((finalRow.totalMs && rawRow.totalMs !== finalRow.totalMs) ||
              (finalRow.rank && rawRow.rank !== finalRow.rank) ||
              finalRow.status !== rawRow.status) {
            warn(classId, `Offisiell liste går foran live i ${group.stage.name} for startnummer ${rawRow.bib || "ukjent"}.`);
          }
          const points = {...rawRow.points};
          const finishId = group.points.find((point) => point.kind === "finish")?.id;
          if (finishId && finalRow.totalMs) {
            points[finishId] = {cumMs: finalRow.totalMs, rank: finalRow.rank};
          } else if (finishId && finalRow.status) {
            delete points[finishId];
          }
          row = {...rawRow, status: finalRow.status, rank: finalRow.rank, officialResult: true, officialStatus: Boolean(finalRow.status),
            totalMs: finalRow.status ? finalRow.totalMs : finalRow.totalMs ?? rawRow.totalMs, points};
        }
        group.results.push(resultData({
          eventId, classId, stageId: group.stage.id, row, entrant, defs: group.points, error,
        }));
      }
      for (const [id, row] of groupOfficial) {
        if (seen.has(id)) continue;
        const entrant = entrants.find((candidate) => candidate.id === id);
        warn(classId, `En utøver i ${group.stage.name} kommer bare fra offisiell liste (startnr. ${row.bib || "ukjent"}).`);
        seenTimed.add(id);
        group.results.push(resultData({
          eventId, classId, stageId: group.stage.id, row: {...row, officialResult: true, officialStatus: Boolean(row.status)},
          entrant, defs: group.points, error,
        }));
      }
      if (!group.results.some((row) => row.finishConfirmed || row.status)) {
        error(classId, `${group.stage.name} ser ut som en startliste, ikke en resultatliste.`);
      }
    }
    if (official.length) {
      for (const entrant of entrants) {
        if (seenTimed.has(entrant.id)) continue;
        if (!entrant.status) {
          error(classId, `En offisielt plassert utøver mangler i kildetidene (startnr. ${entrant.bib || "ukjent"}).`);
        } else if (!hasSprint || prologOnly) {
          initial.results.push(resultData({
            eventId, classId, stageId: initial.stage.id, row: entrant, entrant,
            defs: initial.points, error,
          }));
        }
      }
      if (initial.rows.length !== official.length) {
        warn(classId, `Kildelista har ${initial.rows.length} rader; offisiell liste har ${official.length}. Se avstemmingen.`);
      }
    }
    if (hasSprint && !prologOnly) {
      const officialResults = entrants.map((entrant) => resultData({
        eventId, classId, stageId: overall.id, row: entrant,
        entrant: {...entrant, ...entrantAffiliations.get(entrant.id)}, defs: [], error,
      }));
      overall.groups.push({stage: overall, classId, results: officialResults, points: []});
      buildPodium(timedGroups, officialResults, warn, error, classId);
    }
    participantCount += entrants.length;
    classParticipantCounts.set(classId, entrants.length);
    put(`${eventPath}/classes/${classId}`, {
      schemaVersion: 3, eventId, classId, name: text(raceClass.name),
      primaryStageId: hasSprint && !prologOnly ? overall.id : initial.stage.id,
      participantCount: entrants.length, resultCount: entrants.length, hasResults: true,
      resultProfile: hasSprint ? "sprint" : "standard",
    });
    summary.push({
      id: classId, name: text(raceClass.name), participants: entrants.length,
      official: official.length || null, expected,
      stages: timedGroups.map((group) => ({
        id: group.stage.id, name: group.stage.name, participants: group.results.length,
        points: group.points.map((point) => ({
          name: point.code,
          measured: group.results.filter((result) =>
            result.timingPoints?.some((time) => time.setupUid === point.id)).length,
        })),
        ...(group.sprintPodium ? {podium: group.sprintPodium} : {}),
      })),
    });
  }
  for (const raceClass of classRows.values()) {
    if (raceClass.categoryOf == null) continue;
    const parent = classRows.get(key(raceClass.categoryOf));
    if (hasSprint || !parent || parent === raceClass || parent.categoryOf != null) {
      error(raceClass.id, "En kategori krever en kjent, selvstendig distanseklasse som forelder.");
    } else if (verifiedCategory(raceClass, parent, error)) {
      participantCount -= classParticipantCounts.get(raceClass.id) || 0;
    }
  }
  if (hasSprint && !prologOnly) stages.set(overall.id, overall);
  for (const stage of stages.values()) {
    const stagePath = `${eventPath}/stages/${stage.id}`;
    const resultProfile = hasSprint ? "sprint" : "standard";
    put(stagePath, {
      schemaVersion: 3, eventId, stageId: stage.id, name: stage.name,
      type: stage.phase === "prolog" ? "interval" : stage.phase,
      order: stage.order, resultProfile, resultProfileSource: "nsf",
      classIds: stage.groups.map((group) => group.classId).sort(),
      ...(stage.distanceKm ? {distanceKm: stage.distanceKm} : {}),
    });
    for (const group of stage.groups) {
      const groupPath = `${stagePath}/classes/${group.classId}`;
      const ordered = group.results.toSorted(displaySort);
      put(groupPath, {
        schemaVersion: 3, eventId, stageId: stage.id, classId: group.classId,
        name: text(classRows.get(group.classId).name), resultProfile, resultOrderVersion: 1,
        resultCount: ordered.length, participantCount: ordered.length, hasResults: ordered.length > 0,
        hasTimingData: ordered.some((row) => row.hasTimingData),
        ...(group.sprintPodium ? {sprintPodium: group.sprintPodium} : {}),
      });
      for (const point of group.points) {
        const {id, ...definition} = point;
        put(`${groupPath}/splitDefs/${id}`, {...definition, setupUid: id});
      }
      ordered.forEach(({id, ...data}, displayOrder) =>
        put(`${groupPath}/results/${id}`, {...data, displayOrder}));
    }
  }
  const event = {
    schemaVersion: 3, eventId, name, place, date, timezone: "Europe/Oslo",
    sportName: "Langrenn", source: "nsf", participantCount,
    resultProfile: hasSprint ? "sprint" : "standard",
    disciplineName: text(meta?.disciplineName) || (hasSprint ? "Sprint" : "Distanse"),
  };
  put(eventPath, event);
  docs.sort((a, b) => a.path.localeCompare(b.path));
  const ready = !issues.some((item) => item.severity === "error");
  return {
    eventId, docs,
    report: {ready, event, classes: summary, issues, checksum: ready ? digest(docs) : null},
  };
}

module.exports = {prepareNsfImport, digest};
