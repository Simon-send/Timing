"use strict";

/* eslint-disable require-jsdoc */

const {mkdtemp, readFile, rm, writeFile} = require("node:fs/promises");
const {tmpdir} = require("node:os");
const {join} = require("node:path");
const {prepareNsfImport} = require("../nsf-normalize");

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
