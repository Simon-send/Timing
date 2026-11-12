"use strict";

/* eslint-disable require-jsdoc */

const {mkdtemp, readFile, rm, writeFile} = require("node:fs/promises");
const {tmpdir} = require("node:os");
const {join} = require("node:path");
const {prepareNsfImport} = require("../nsf-normalize");

jest.mock("../nsf-source", () => ({collectNsfRace: jest.fn()}));
const {collectNsfRace} = require("../nsf-source");
jest.mock("../nsf-official", () => ({readOfficialNsfPdf: jest.fn()}));
const {readOfficialNsfPdf} = require("../nsf-official");
const {main} = require("../scripts/import-nsf");

let directory;
let file;
let output;

function source() {
  return {
    schemaVersion: 1,
    event: {id: 2231, name: "Testløp", date: "2026-03-06", place: "Teststed"},
    classes: [{id: "senior", name: "Senior", expectedCount: 1}],
    stages: [{id: "distance", name: "5 km", phase: "distance", classes: [{
      classId: "senior", points: [],
      rows: [{name: "Testløper", bib: "1", rank: 1, totalMs: 689200}],
    }]}],
  };
}

beforeEach(async () => {
  directory = await mkdtemp(join(tmpdir(), "nsf-cli-test-"));
  file = join(directory, "source.json");
  await writeFile(file, JSON.stringify(source()));
  output = jest.spyOn(console, "log").mockImplementation(() => {});
  readOfficialNsfPdf.mockReset();
  collectNsfRace.mockReset();
});

afterEach(async () => {
  output.mockRestore();
  await rm(directory, {recursive: true, force: true});
});

test("preview emits a checked report and never overwrites its saved source", async () => {
  const saved = join(directory, "preview.json");
  await main(["--export", file, "--preview-out", saved]);
  expect(JSON.parse(output.mock.calls[0][0])).toMatchObject({
    ready: true, checksum: prepareNsfImport(source()).report.checksum,
    event: {eventId: "nsf-2231"},
  });
  expect(JSON.parse(await readFile(saved, "utf8"))).toEqual(source());
  await expect(main(["--export", file, "--preview-out", saved]))
      .rejects.toThrow(/EEXIST/);
});

test("apply requires a saved source, explicit project and matching preview", async () => {
  const checksum = prepareNsfImport(source()).report.checksum;
  await expect(main(["--export", file, "--apply", "--confirm", checksum]))
      .rejects.toThrow(/eksplisitt --project/);
  await expect(main(["--url", "https://live.nsftiming.no/live/2231", "--apply",
    "--confirm", checksum, "--project", "demo-nsf-import-tests"]))
      .rejects.toThrow(/lagrede eksporten/);
  await expect(main(["--export", file, "--apply", "--confirm", "0".repeat(64),
    "--project", "demo-nsf-import-tests"]))
      .rejects.toThrow(/kontrollsummen er endret/);
  expect(output).not.toHaveBeenCalled();
});

test("rejects the wrong official list kind, date and class before preview", async () => {
  const official = {kind: "timed", date: "2026-03-06", className: "Senior 5 km",
    expectedCount: 1, rows: source().stages[0].classes[0].rows};
  for (const [patch, message] of [
    [{kind: "sprint-overall"}, /Feil listetype/],
    [{date: "2026-03-07"}, /annen dato/],
    [{className: "Junior"}, /annen klasse/],
  ]) {
    readOfficialNsfPdf.mockResolvedValue({...official, ...patch});
    await expect(main(["--export", file, "--official", "senior=selected.pdf"]))
        .rejects.toThrow(message);
  }
  expect(output).not.toHaveBeenCalled();
});


test("preview passes explicit class and prolog-only choices into the public collector", async () => {
  const prolog = source();
  prolog.sprintPrologOnly = true;
  prolog.stages[0] = {...prolog.stages[0], id: "prolog", phase: "prolog"};
  collectNsfRace.mockResolvedValue(prolog);
  readOfficialNsfPdf.mockResolvedValue({kind: "timed", expectedCount: 1,
    date: "2026-03-06", className: "Senior", rows: source().stages[0].classes[0].rows});
  const saved = join(directory, "prolog.json");
  await main(["--url", "https://live.nsftiming.no/live/2231", "--classes", "senior",
    "--prolog-only", "--official", "senior=prolog.pdf", "--preview-out", saved]);
  expect(collectNsfRace).toHaveBeenCalledWith("https://live.nsftiming.no/live/2231",
      expect.objectContaining({classIds: ["senior"], sprintPrologOnly: true}));
  expect(JSON.parse(output.mock.calls[0][0]).ready).toBe(true);
  expect(JSON.parse(await readFile(saved, "utf8")).sprintPrologOnly).toBe(true);
});

test.each([["--classes", "senior"], ["--prolog-only"]])(
    "apply rejects source-altering collection flags (%j)", async (...flags) => {
      await expect(main(["--export", file, "--apply", "--confirm", "0".repeat(64),
        "--project", "demo-nsf-import-tests", ...flags])).rejects.toThrow(/--apply/);
      expect(collectNsfRace).not.toHaveBeenCalled();
    });

test.each(["", "senior,", ",senior", "senior,senior"])(
    "rejects empty or repeated CLI class selectors (%s)", async (selection) => {
      await expect(main(["--url", "https://live.nsftiming.no/live/2231", "--classes", selection]))
          .rejects.toThrow(/klasser|classes/);
      expect(collectNsfRace).not.toHaveBeenCalled();
    });

test("official class distances replace a shared live title distance without leaking between classes", async () => {
  const race = source();
  race.classes.push({id: "junior", name: "Junior", expectedCount: 1});
  race.stages[0].distanceKm = 10;
  race.stages[0].classes[0].points = [{id: "finish", label: "Mål", kind: "finish", km: 10}];
  race.stages[0].classes.push({
    classId: "junior", points: [{id: "finish", label: "Mål", kind: "finish", km: 10}],
    rows: [{name: "Juniorløper", bib: "2", rank: 1, totalMs: 700000}],
  });
  await writeFile(file, JSON.stringify(race));
  readOfficialNsfPdf.mockImplementation(async (location) => {
    const junior = location === "junior.pdf";
    return {kind: "timed", date: "2026-03-06", className: junior ? "Junior" : "Senior",
      distanceKm: junior ? 3.75 : 5, singleCourse: true, expectedCount: 1,
      rows: race.stages[0].classes[junior ? 1 : 0].rows};
  });
  const saved = join(directory, "distances.json");
  await main(["--export", file, "--official", "senior=senior.pdf",
    "--official", "junior=junior.pdf", "--preview-out", saved]);
  const stage = JSON.parse(await readFile(saved, "utf8")).stages[0];
  expect(stage.distanceKm).toBeUndefined();
  expect(stage.classes.map((group) => group.points[0].km)).toEqual([5, 3.75]);
  expect(stage.classes.map((group) => group.distanceKm)).toEqual([5, 3.75]);
});
