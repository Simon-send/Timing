#!/usr/bin/env node
"use strict";

/* eslint-disable require-jsdoc, valid-jsdoc, max-len */

const {readFile, stat, writeFile} = require("node:fs/promises");
const {parseArgs} = require("node:util");
const {prepareNsfImport} = require("../nsf-normalize");

const HELP = `NSF Timing → Results

Forhåndsvisning:
  npm run import:nsf -- --url <rennlenke> --preview-out <fil.json>
  npm run import:nsf -- --export <fil.json>

Valg for forhåndsvisning:
  --official <klasse-id>=<offisiell PDF-fil eller lenke>  Kan gjentas
  --official-stage <ledd-id>/<klasse-id>=<offisiell PDF>  Valgfri faseliste
  --date YYYY-MM-DD --place <sted>  Hvis kilden mangler rennmetadata
  --channel chrome                  Bruk installert Google Chrome

Skriv en kontrollert forhåndsvisning:
  npm run import:nsf -- --export <fil.json> --apply --confirm <kontrollsum> --project <prosjekt>
  Legg til --resume bare for å gjenoppta den samme uavsluttede importen.
`;

const options = {
  "help": {type: "boolean", short: "h"},
  "url": {type: "string"},
  "export": {type: "string"},
  "preview-out": {type: "string"},
  "date": {type: "string"},
  "place": {type: "string"},
  "channel": {type: "string"},
  "official": {type: "string", multiple: true},
  "official-stage": {type: "string", multiple: true},
  "apply": {type: "boolean"},
  "confirm": {type: "string"},
  "project": {type: "string"},
  "resume": {type: "boolean"},
};

async function readExport(file) {
  const info = await stat(file);
  if (!info.isFile() || info.size > 20 * 1024 * 1024) {
    throw new Error("Eksporten må være en lokal JSON-fil på høyst 20 MB.");
  }
  return JSON.parse(await readFile(file, "utf8"));
}

async function attachOfficial(source, entries, stagedEntries) {
  if (!entries?.length && !stagedEntries?.length) return;
  if (!Array.isArray(source.classes) || !Array.isArray(source.stages) ||
      !source.event || typeof source.event !== "object") {
    throw new Error("Eksporten mangler renn eller klasser.");
  }
  const {readOfficialNsfPdf} = require("../nsf-official");
  const used = new Set();
  for (const [entriesForScope, staged] of [[entries, false], [stagedEntries, true]]) {
    for (const entry of entriesForScope || []) {
      const separator = entry.indexOf("=");
      const id = entry.slice(0, separator);
      const location = entry.slice(separator + 1);
      const [stageId, classId] = staged ? id.split("/") : [null, id];
      const raceClass = source.classes.find((item) => String(item.id) === classId);
      const stage = stageId && source.stages.find((item) => String(item.id) === stageId);
      const group = stage?.classes.find((item) => String(item.classId) === classId);
      if (separator < 1 || !location || !raceClass || (staged && !group) || used.has(id)) {
        throw new Error(`Offisiell liste må angi en unik, kjent klasse eller ledd/klasse: ${id}.`);
      }
      used.add(id);
      const official = await readOfficialNsfPdf(location);
      const isSprint = source.stages.some((item) => item.phase !== "distance");
      const expectedKind = !staged && isSprint ? "sprint-overall" : "timed";
      if (official.kind !== expectedKind || (staged && stage.phase !== "prolog")) {
        throw new Error(`Feil listetype for ${id}. Bruk sprintens offisielle sluttliste og gi prologlista med --official-stage.`);
      }
      if (official.date && source.event.date && official.date !== source.event.date) {
        throw new Error(`Offisiell liste for ${id} har en annen dato enn rennet.`);
      }
      if (official.className && !official.className.toLowerCase().startsWith(raceClass.name.toLowerCase())) {
        throw new Error(`Offisiell liste for ${id} tilhører en annen klasse.`);
      }
      if (!source.event.date && official.date) source.event.date = official.date;
      if (!source.event.place && official.place) source.event.place = official.place;
      if (staged) {
        group.official = official.rows;
      } else {
        raceClass.official = official.rows;
        raceClass.expectedCount = official.expectedCount;
        for (const target of source.stages) {
          const targetGroup = target.classes.find((item) => String(item.classId) === classId);
          if (!targetGroup) continue;
          if (official.distanceKm) targetGroup.distanceKm = official.distanceKm;
          if (official.singleCourse === true) targetGroup.courseKey = `official-${classId}`;
        }
      }
    }
  }
  for (const stage of source.stages) {
    const distances = new Set(stage.classes.map((group) => group.distanceKm).filter(Boolean));
    if (distances.size === 1 && stage.classes.every((group) => group.distanceKm)) {
      const [distance] = distances;
      if (!stage.distanceKm) stage.distanceKm = distance;
    }
  }
}

/** Keep the default invocation read-only; apply reads the exact previewed snapshot. */
async function main(argv) {
  const {values} = parseArgs({args: argv, options});
  if (values.help) {
    console.log(HELP);
    return;
  }
  if (Boolean(values.url) === Boolean(values.export)) {
    throw new Error("Oppgi nøyaktig én av --url og --export.");
  }
  if (values.apply && (!values.export || !values.project ||
      !/^[a-f0-9]{64}$/.test(values.confirm || "") || values.official ||
      values["official-stage"] || values.date || values.place || values["preview-out"])) {
    throw new Error("--apply krever den lagrede eksporten, --confirm og et eksplisitt --project.");
  }
  if (!values.apply && (values.resume || values.confirm || values.project)) {
    throw new Error("--resume, --confirm og --project brukes bare med --apply.");
  }
  const source = values.export ? await readExport(values.export) :
    await require("../nsf-source").collectNsfRace(values.url, {
      date: values.date, place: values.place, channel: values.channel,
    });
  if (values.export && source?.event) {
    if (values.date) source.event.date = values.date;
    if (values.place) source.event.place = values.place;
  }
  await attachOfficial(source, values.official, values["official-stage"]);
  const bundle = prepareNsfImport(source);
  if (!values.apply) {
    if (values["preview-out"]) {
      await writeFile(values["preview-out"], JSON.stringify(source, null, 2) + "\n",
          {flag: "wx", mode: 0o600});
    }
    console.log(JSON.stringify(bundle.report, null, 2));
    if (!bundle.report.ready) process.exitCode = 2;
    return;
  }
  if (!bundle.report.ready || bundle.report.checksum !== values.confirm) {
    throw new Error("Eksporten er ufullstendig eller kontrollsummen er endret. Kjør forhåndsvisning igjen.");
  }
  const {initializeApp, deleteApp} = require("firebase-admin/app");
  const {getFirestore} = require("firebase-admin/firestore");
  const {writeNsfImport} = require("../nsf-write");
  const app = initializeApp({projectId: values.project});
  try {
    const result = await writeNsfImport(getFirestore(app), bundle, {
      checksum: values.confirm, resume: values.resume,
    });
    console.log(JSON.stringify(result, null, 2));
  } finally {
    await deleteApp(app);
  }
}

if (require.main === module) {
  main(process.argv.slice(2)).catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}

module.exports = {main};
