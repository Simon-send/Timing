"use strict";

/* eslint-disable require-jsdoc, max-len */

const {readFile, stat} = require("node:fs/promises");
const {distanceInLabel, nsfStatus, parseNsfTime} = require("./nsf-source");

const MAX_PDF_BYTES = 16 * 1024 * 1024;
const MAX_PDF_PAGES = 100;
const SKIFORBUNDET = "https://www.skiforbundet.no";

function approvedPdfUrl(value) {
  const url = new URL(value);
  if (url.origin !== SKIFORBUNDET || url.username || url.password ||
      !/^\/(?:globalassets|contentassets)\//i.test(url.pathname) ||
      !/\.pdf$/i.test(url.pathname) || url.search || url.hash) {
    throw new Error("Use a public Skiforbundet PDF URL or a local PDF path.");
  }
  return url;
}

async function readPdfBytes(pathOrUrl) {
  if (!/^[a-z][a-z\d+.-]*:\/\//i.test(pathOrUrl)) {
    if ((await stat(pathOrUrl)).size > MAX_PDF_BYTES) {
      throw new Error("The official result PDF is too large.");
    }
    return new Uint8Array(await readFile(pathOrUrl));
  }
  const url = approvedPdfUrl(pathOrUrl);
  const response = await fetch(url, {
    redirect: "error",
    signal: AbortSignal.timeout(20000),
  });
  if (!response.ok || !response.body ||
      !/^application\/pdf\b/i.test(response.headers.get("content-type") || "")) {
    throw new Error("Skiforbundet did not return a public result PDF.");
  }
  const chunks = [];
  let bytes = 0;
  for await (const chunk of response.body) {
    bytes += chunk.byteLength;
    if (bytes > MAX_PDF_BYTES) throw new Error("The official result PDF is too large.");
    chunks.push(chunk);
  }
  return new Uint8Array(Buffer.concat(chunks, bytes));
}

function positions(items, width) {
  return items.filter((item) => item.str?.trim()).map((item) => ({
    text: item.str.normalize("NFC").trim(),
    // The official NSF report is A4. Normalize for PDF writers that scale it.
    x: item.transform[4] * 595.28 / width,
    y: item.transform[5] * 595.28 / width,
  }));
}

function textOnLine(items, y, x1, x2, tolerance = 1.5) {
  return items.filter((item) => item.x >= x1 && item.x < x2 &&
      Math.abs(item.y - y) <= tolerance)
      .sort((a, b) => a.x - b.x).map((item) => item.text).join(" ");
}

function pageInfo(items) {
  const official = items.find((item) => /^Offisiell Resultatliste$/i.test(item.text));
  if (!official) throw new Error("The PDF is not an official NSF result list.");
  const dateLabel = items.find((item) => item.y > official.y &&
    /\b\d{4}-\d{2}-\d{2}\b/.test(item.text));
  const date = dateLabel?.text.match(/\b\d{4}-\d{2}-\d{2}\b/)?.[0];
  const nameY = Math.max(...items.filter((item) => item.x >= 140 &&
      item.x < 250 && item.y > (dateLabel?.y || official.y)).map((item) => item.y));
  const name = textOnLine(items, nameY, 140, 450) || undefined;
  const placeLine = dateLabel && textOnLine(items, dateLabel.y, 130, 475);
  const place = placeLine?.match(/^(.+?)\s*\([A-Z]{3}\)/)?.[1];
  const classY = Math.min(...items.filter((item) => item.x >= 140 &&
      item.x < 250 && item.y > official.y).map((item) => item.y));
  const className = textOnLine(items, classY, 140, 390) || undefined;
  const count = items.find((item) => item.y < official.y && item.x < 40 &&
    /Number of Competitors\s*:\s*\d+/i.test(item.text));
  const expectedCount = Number(count?.text.match(/:\s*(\d+)/)?.[1]) || undefined;
  const courseCount = items.filter((item) => item.text === "Course" && item.x > 300).length;
  const lapLength = items.find((item) => /^LENGTH OF LAP$/i.test(item.text));
  const lapCount = items.find((item) => /^NUMBER OF LAPS$/i.test(item.text));
  const lapKm = lapLength && distanceInLabel(textOnLine(items, lapLength.y, 470, 590));
  const laps = lapCount && Number(textOnLine(items, lapCount.y, 470, 590));
  const courseDistanceKm = courseCount === 1 && lapKm > 0 &&
    Number.isInteger(laps) && laps > 0 ? lapKm * laps : undefined;
  return {name, date, place, className, distanceKm: distanceInLabel(className),
    expectedCount, courseCount, courseDistanceKm};
}

function finishFromPdf(value) {
  // One official NSF report uses ')' as the decimal separator in this column.
  const time = value.replace(/(?<=\d)\)(?=\d{1,3}$)/, ".");
  return /^(?:\d+:){1,2}\d{2}(?:[.,]\d{1,3})?$/.test(time) ?
    parseNsfTime(time) : undefined;
}

function parseOfficialPage(rawItems, width = 595.28) {
  const items = positions(rawItems, width);
  const info = pageInfo(items);
  const sprint = items.find((item) => /^QUALIF\.$/i.test(item.text) &&
    item.x > 220 && item.x < 300);
  const individual = items.find((item) => /^Finish$/i.test(item.text) &&
    item.x > 420 && item.x < 500);
  if (!sprint && !individual) {
    if (items.some(({text}) => text === "Jury Decisions")) {
      return {...info, rows: []};
    }
    throw new Error("The official PDF does not use a supported NSF results layout.");
  }
  const upper = sprint ? sprint.y - 30 : individual.y - 5;
  const bottom = items.find((item) => /^Side \d+ av \d+$/i.test(item.text));
  const bibLeft = sprint ? 46 : 51;
  const anchors = items.filter((item) => item.x >= bibLeft && item.x < 68 &&
    item.y < upper && item.y > (bottom?.y || 145) && /^\d+$/.test(item.text));
  const rows = [];
  for (const bib of anchors) {
    const rankText = textOnLine(items, bib.y, 20, bibLeft);
    const rank = /^\d+$/.test(rankText) && Number(rankText) > 0 ?
      Number(rankText) : undefined;
    const finish = sprint ? "" : textOnLine(items, bib.y, 435, 500);
    const status = sprint ? nsfStatus(rankText) : nsfStatus(finish);
    const totalMs = sprint ? undefined : finishFromPdf(finish);
    const qualification = sprint && textOnLine(items, bib.y, 235, 278);
    const unranked = sprint && !rankText &&
      /^(?:\+?[\d:.]+)\s+\(\d+\)$/.test(qualification);
    if (!rank && !status && !unranked) continue;
    const name = sprint ? textOnLine(items, bib.y, 68, 207) :
      textOnLine(items, bib.y + 6, 79, 375);
    const club = sprint ? undefined :
      textOnLine(items, bib.y - 4.8, 79, 375) || undefined;
    const country = sprint ? textOnLine(items, bib.y, 208, 233) :
      textOnLine(items, bib.y + 6, 390, 430);
    if (!name || (!sprint && rank && totalMs === undefined)) {
      throw new Error("An official NSF result row could not be read.");
    }
    rows.push({
      bib: bib.text,
      name,
      club,
      country: /^[A-Z]{3}$/.test(country) ? country : undefined,
      rank,
      status,
      totalMs,
      ...(unranked ? {unranked: true} : {}),
    });
  }
  return {...info, kind: sprint ? "sprint-overall" : "timed", rows};
}

async function readOfficialNsfPdf(pathOrUrl) {
  const {getDocument} = await import("pdfjs-dist/legacy/build/pdf.mjs");
  const bytes = await readPdfBytes(pathOrUrl);
  const document = getDocument({
    data: bytes,
    isEvalSupported: false,
    stopAtErrors: true,
    verbosity: 0,
  });
  try {
    const pdf = await document.promise;
    if (pdf.numPages > MAX_PDF_PAGES) {
      throw new Error("The official result PDF has too many pages.");
    }
    let info;
    const rows = [];
    let courseCount = 0;
    let courseDistanceKm;
    for (let number = 1; number <= pdf.numPages; number++) {
      const page = await pdf.getPage(number);
      const {items} = await page.getTextContent();
      const {rows: pageRows, courseCount: pageCourses, courseDistanceKm: pageCourseKm,
        ...metadata} = parseOfficialPage(
          items, page.getViewport({scale: 1}).width,
      );
      if (!info) info = metadata;
      if ((metadata.kind && metadata.kind !== info.kind) ||
          (metadata.className && metadata.className !== info.className) ||
          (metadata.date && metadata.date !== info.date)) {
        throw new Error("The official PDF mixes different result lists.");
      }
      rows.push(...pageRows);
      courseCount += pageCourses;
      if (pageCourseKm !== undefined) courseDistanceKm = pageCourseKm;
    }
    if (!info?.expectedCount || rows.length !== info.expectedCount) {
      throw new Error(`Official NSF result PDF contains ${rows.length} readable rows; ` +
        `expected ${info?.expectedCount ?? "a published participant count"}.`);
    }
    if (new Set(rows.map((row) => `${row.bib}\0${row.name}`)).size !== rows.length) {
      throw new Error("Official NSF result PDF contains duplicate result rows.");
    }
    const singleCourse = courseCount === 1 && courseDistanceKm !== undefined;
    return {...info, distanceKm: info.distanceKm ?? (singleCourse ?
      courseDistanceKm : undefined), singleCourse, rows};
  } finally {
    await document.destroy();
  }
}

module.exports = {approvedPdfUrl, parseOfficialPage, readOfficialNsfPdf};
