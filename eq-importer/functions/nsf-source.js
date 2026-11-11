"use strict";

/* eslint-disable require-jsdoc, max-len */
/* global document, requestAnimationFrame */

const LIVE_ORIGIN = "https://live.nsftiming.no";
const LEGACY_ORIGIN = "https://cis.nsftiming.no";
const TIMEOUT_MS = 15000;

function clean(value) {
  return String(value ?? "").normalize("NFC").replace(/\s+/g, " ").trim();
}

function parseNsfRaceUrl(value) {
  let url;
  try {
    url = new URL(value);
  } catch {
    throw new Error("Enter a public NSF Timing race URL.");
  }
  const modern = /^\/live\/(?:splits\/|sprint\/)?(\d+)\/?$/;
  const hasCredentials = url.username || url.password;
  const modernId = url.origin === LIVE_ORIGIN && modern.exec(url.pathname)?.[1];
  const legacyId = url.origin === LEGACY_ORIGIN && /^\/live\/?$/.test(url.pathname) &&
    url.searchParams.getAll("raceid").length === 1 &&
    url.searchParams.get("raceid");
  const id = modernId || legacyId;
  if (hasCredentials || !/^\d{1,12}$/.test(id || "") || /^0/.test(id)) {
    throw new Error("Enter a public live.nsftiming.no or cis.nsftiming.no race URL.");
  }
  return {id, url: `${LIVE_ORIGIN}/live/${id}`};
}

function parseNsfTime(value) {
  const match = clean(value).match(/^(?:(\d+):)?(?:(\d+):)?(\d+)(?:[.,](\d{1,3}))?$/);
  if (!match) return undefined;
  const [, first, second, seconds, fraction] = match;
  if (second && Number(second) >= 60 || first && Number(seconds) >= 60) {
    return undefined;
  }
  const total = (second ? Number(first) * 3600 + Number(second) * 60 :
    Number(first || 0) * 60) + Number(seconds);
  const result = total * 1000 + Number((fraction || "").padEnd(3, "0"));
  return Number.isSafeInteger(result) ? result : undefined;
}

function nsfStatus(value) {
  const text = clean(value).toUpperCase();
  if (/^(?:DNS|DID NOT START|IKKE STARTET|STARTET IKKE)$/.test(text)) return "DNS";
  if (/^(?:DNF|DID NOT FINISH|BRUTT|IKKE FULLFØRT)$/.test(text)) return "DNF";
  if (/^(?:DSQ|DQ|DFQ|DISQUALIFIED|DISKVALIFISERT)$/.test(text)) return "DSQ";
  if (/^(?:LAP|LAPPED|NPS|DQB|DNQ|NC|NQ|OTL)$/.test(text)) return text;
}

function positiveInt(value) {
  return /^\d+$/.test(value) && Number(value) > 0 ? Number(value) : undefined;
}

function distanceInLabel(label) {
  const match = clean(label).match(/(?:^|\s)(\d+(?:[,.]\d+)?)\s*km\b/i);
  return match ? Number(match[1].replace(",", ".")) : undefined;
}

function nameKey(value) {
  return clean(value).toLocaleLowerCase("nb-NO");
}

function timingPoint(value) {
  const text = clean(value);
  const match = text.match(/^(\d+(?::\d+){0,2}(?:[.,]\d{1,3})?)(?:\s*\((\d+)\))?(?=$|\s|[↑↓])/);
  if (!match) return undefined;
  const cumMs = parseNsfTime(match[1]);
  if (cumMs === undefined) return undefined;
  const rank = positiveInt(match[2]);
  return rank ? {cumMs, rank} : {cumMs};
}

function parseSplitTable(table, distanceKm) {
  const headers = table.headers.map((header) => clean(header).toLowerCase());
  const rankColumn = headers.findIndex((header) => /^(?:rn\.?|rank|plass)$/.test(header));
  const bibColumn = headers.findIndex((header) => /^(?:#|bib\.?|startnr\.?)$/.test(header));
  const nameColumn = headers.findIndex((header) => /^(?:name|navn)$/.test(header));
  const startColumn = headers.findIndex((header) => /^(?:start\s*time|starttid)$/.test(header));
  const finishColumn = headers.findIndex((header) => /^(?:mål|finish)$/.test(header));
  if ([rankColumn, bibColumn, nameColumn, startColumn, finishColumn].includes(-1) ||
      finishColumn <= startColumn || finishColumn !== headers.length - 1) {
    throw new Error("NSF Timing changed the public split table layout.");
  }
  const splitColumns = table.headers.slice(startColumn + 1).map((value, index) => {
    const label = clean(value);
    const kind = index === finishColumn - startColumn - 1 ? "finish" : "split";
    const km = kind === "finish" ? distanceKm : distanceInLabel(label);
    return {id: kind === "finish" ? "finish" : `split-${index + 1}`, label, km, kind};
  });
  const rows = table.rows.map((row) => {
    const rankCell = clean(row.cells[rankColumn]);
    const finishCell = clean(row.cells[finishColumn]);
    const status = nsfStatus(rankCell) || nsfStatus(finishCell);
    const rank = status ? undefined : positiveInt(rankCell);
    const points = {};
    for (const [index, point] of splitColumns.entries()) {
      const value = timingPoint(row.cells[startColumn + 1 + index]);
      if (value && (point.kind !== "finish" || !status)) points[point.id] = value;
    }
    return {
      name: clean(row.name || row.cells[nameColumn]),
      bib: clean(row.cells[bibColumn]) || undefined,
      club: clean(row.club) || undefined,
      rank,
      status,
      totalMs: points.finish?.cumMs,
      points,
    };
  });
  return {points: splitColumns, rows};
}

function phaseForRun(run) {
  const label = clean(run);
  const key = label.toLowerCase().replace(/[\s_]+/g, "-");
  if (/^(?:qualification|prolog|kvalifisering)$/.test(key)) {
    return {id: "prolog", name: "Prolog", phase: "prolog", order: 0};
  }
  const match = key.match(/^(quarterfinal|kvartfinale|semifinal|semifinale|final|finale)-?([1-9]\d*|[a-z])$/);
  if (!match) throw new Error(`Unsupported NSF Timing sprint round: ${label}`);
  const phase = /^kvar|^quar/.test(match[1]) ? "quarterfinal" :
    match[1].startsWith("semi") ? "semifinal" : "final";
  const heat = /^\d+$/.test(match[2]) ? Number(match[2]) : match[2].toUpperCase();
  const order = {quarterfinal: 100, semifinal: 200, final: 300}[phase] +
    (typeof heat === "number" ? heat : heat.charCodeAt(0) - 64);
  const name = {quarterfinal: "Kvartfinale", semifinal: "Semifinale", final: "Finale"}[phase];
  return {id: `${phase}-${match[2]}`, name: `${name} ${heat}`, phase, order, heat};
}

async function optionsOf(control, eventId) {
  return (await control.locator("option").evaluateAll((options) =>
    options.map((option) => ({value: option.value, name: option.textContent.trim()})),
  )).filter(({value}) => value.endsWith(`_${eventId}`) &&
    /^\d+_\d+$/.test(value));
}

function firstSplitRow() {
  return Array.from(document.querySelectorAll("tbody tr")).find((row) =>
    row.querySelector("[class*=\"_athName_\"]"),
  )?.innerText;
}

async function waitForSplitRows(page, previous) {
  await page.waitForFunction(
      (before) => {
        const row = Array.from(document.querySelectorAll("tbody tr")).find((item) =>
          item.querySelector("[class*=\"_athName_\"]"),
        );
        return Boolean(row && (!before || row.innerText !== before));
      },
      previous ?? null,
      {timeout: TIMEOUT_MS},
  );
}

// NSF Timing renders only the rows around the current scroll position.
async function readRenderedTable(table, startlist = false) {
  return table.evaluate(async (element, isStartlist) => {
    const scroller = element.parentElement;
    const headers = Array.from(element.tHead.rows[0].cells, (cell) =>
      cell.textContent.trim(),
    );
    const found = new Map();
    const nextPaint = () => new Promise((resolve) =>
      requestAnimationFrame(() => requestAnimationFrame(resolve)),
    );
    if (scroller.clientHeight <= 0) throw new Error("NSF Timing table is hidden.");
    scroller.scrollTop = 0;
    await nextPaint();
    const step = Math.max(1, Math.floor(scroller.clientHeight / 2));
    let top = 0;
    for (let index = 0; index < 5000; index++) {
      scroller.scrollTop = top;
      await nextPaint();
      for (const row of element.querySelectorAll("tbody tr")) {
        const cellText = (selector) => row.querySelector(selector)?.textContent.trim();
        const name = isStartlist ? cellText("[class*=\"_fullNameSpan_\"]") :
          cellText("[class*=\"_athFull_\"]") ||
          row.querySelector("[class*=\"_athName_\"]")?.innerText.trim();
        if (!name) continue;
        const club = cellText(isStartlist ? "[class*=\"_club_span_\"]" : "[class*=\"_athClub_\"]");
        const cells = Array.from(row.cells, (cell) =>
          (cell.firstElementChild?.tagName === "DIV" ?
            cell.firstElementChild : cell).textContent.trim(),
        );
        const bib = cells[isStartlist ? 1 : 2];
        const record = isStartlist ? {
          name,
          bib,
          club,
          team: cellText("[class*=\"_team_span_\"]"),
          country: row.cells[4]?.querySelector("img")?.alt,
        } : {name, club, cells};
        const key = `${bib}\0${name}`;
        const old = found.get(key);
        if (old && JSON.stringify(old) !== JSON.stringify(record)) {
          throw new Error("NSF Timing changed results during collection.");
        }
        found.set(key, record);
      }
      const max = Math.max(0, scroller.scrollHeight - scroller.clientHeight);
      if (scroller.scrollTop >= max - 1) {
        scroller.scrollTop = 0;
        await nextPaint();
        return {headers, rows: Array.from(found.values())};
      }
      top = Math.min(scroller.scrollTop + step, max);
    }
    throw new Error("NSF Timing did not reach the end of the public table.");
  }, startlist);
}

async function openRacePage(page, path) {
  // The hosting fallback can serve the app shell with HTTP 404.
  await page.goto(`${LIVE_ORIGIN}${path}`, {
    waitUntil: "domcontentloaded",
    timeout: TIMEOUT_MS,
  });
  if (page.url() !== `${LIVE_ORIGIN}${path}`) {
    throw new Error("NSF Timing redirected outside the requested public race page.");
  }
}

async function readStartlist(page, id) {
  await openRacePage(page, `/live/${id}`);
  const decline = page.getByRole("button", {name: "Decline", exact: true});
  const lists = page.getByRole("button", {name: "Lists", exact: true});
  await lists.waitFor({timeout: TIMEOUT_MS});
  if (await decline.isVisible()) await decline.click();
  await lists.click();
  await page.getByRole("columnheader", {name: /^(?:start\s*time|starttid)$/i})
      .first().waitFor({state: "attached", timeout: TIMEOUT_MS});
  const table = page.locator("table").first();
  await table.locator("[class*=\"_fullNameSpan_\"]").first()
      .waitFor({state: "attached", timeout: TIMEOUT_MS});
  return (await readRenderedTable(table, true)).rows;
}

function addRosterMetadata(stages, roster) {
  const byName = new Map();
  for (const athlete of roster) {
    const key = nameKey(athlete.name);
    const candidates = byName.get(key) || [];
    candidates.push(athlete);
    byName.set(key, candidates);
  }
  for (const stage of stages) {
    for (const raceClass of stage.classes) {
      for (const row of raceClass.rows) {
        const candidates = byName.get(nameKey(row.name)) || [];
        // Heat bibs are reassigned. An exact name/club pair is still stable.
        const matches = stage.phase === "distance" || stage.phase === "prolog" ?
          candidates.filter((athlete) => athlete.bib === row.bib) :
          candidates.filter((athlete) => nameKey(athlete.club) === nameKey(row.club));
        if (matches.length !== 1) continue;
        const [match] = matches;
        if (match.club && !row.club) row.club = match.club;
        if (match.team) row.team = match.team;
        if (/^[A-Z]{3}$/.test(match.country)) row.country = match.country;
      }
    }
  }
}

async function collectNsfRace(value, options = {}) {
  const {id} = parseNsfRaceUrl(value);
  const {chromium} = require("playwright");
  const browser = await chromium.launch(options.channel ? {channel: options.channel} : {});
  try {
    const page = await browser.newPage({
      locale: "en-US",
      viewport: {width: 1440, height: 1000},
    });
    await openRacePage(page, `/live/splits/${id}`);
    const classControl = page.locator("select").first();
    await classControl.locator(`option[value$="_${id}"]`).first()
        .waitFor({state: "attached", timeout: TIMEOUT_MS});
    const classes = (await optionsOf(classControl, id)).map(({value, name}) =>
      ({id: value, name}),
    );
    if (!classes.length) throw new Error("NSF Timing did not show any race classes.");
    const name = clean(await page.locator("h1").first().textContent());
    if (!name) throw new Error("NSF Timing did not show a race name.");
    const event = {id, name, date: options.date, place: options.place};
    const distanceKm = options.distanceKm ?? distanceInLabel(name);
    const isSprint = await page.getByRole("button", {name: "Sprint", exact: true}).count() > 0;
    const stages = new Map();
    const runControl = page.locator("select").nth(1);
    const table = page.locator("table").first();

    const save = async (stage, raceClass) => {
      const data = parseSplitTable(await readRenderedTable(table), distanceKm);
      if (!data.rows.length) {
        throw new Error(`NSF Timing did not show rows for ${raceClass.name}, ${stage.name}.`);
      }
      const current = stages.get(stage.id) || {...stage, distanceKm, classes: []};
      current.classes.push({classId: raceClass.id, ...data});
      stages.set(stage.id, current);
    };

    for (const raceClass of classes) {
      const beforeClass = await classControl.inputValue() !== raceClass.id ?
        await page.evaluate(firstSplitRow) : undefined;
      await classControl.selectOption(raceClass.id);
      await waitForSplitRows(page, beforeClass);
      if (!isSprint) {
        await save({id: "distance", name, phase: "distance", order: 0}, raceClass);
        continue;
      }
      const runs = await optionsOf(runControl, id);
      if (!runs.length || !runs.some((run) => phaseForRun(run.name).phase === "prolog")) {
        throw new Error(`NSF Timing did not show the sprint rounds for ${raceClass.name}.`);
      }
      for (const run of runs) {
        if (await runControl.inputValue() !== run.value) {
          const beforeRun = await page.evaluate(firstSplitRow);
          await runControl.selectOption(run.value);
          await waitForSplitRows(page, beforeRun);
        }
        await save(phaseForRun(run.name), raceClass);
      }
    }
    const result = Array.from(stages.values()).sort((a, b) => a.order - b.order);
    if (isSprint && options.courseKey) {
      for (const stage of result.filter(({phase}) => phase !== "prolog")) {
        stage.courseKey = options.courseKey;
      }
    }
    addRosterMetadata(result, await readStartlist(page, id));
    return {schemaVersion: 1, event, classes, stages: result};
  } finally {
    await browser.close();
  }
}

module.exports = {
  addRosterMetadata,
  collectNsfRace,
  distanceInLabel,
  nameKey,
  nsfStatus,
  parseNsfRaceUrl,
  parseNsfTime,
  parseSplitTable,
  phaseForRun,
};
