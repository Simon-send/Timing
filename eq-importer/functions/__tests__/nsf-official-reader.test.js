"use strict";

/* eslint-disable require-jsdoc */

const {execFileSync} = require("node:child_process");
const {mkdtemp, rm, writeFile} = require("node:fs/promises");
const {tmpdir} = require("node:os");
const {join} = require("node:path");

function pdf(pages) {
  const fontId = 3 + pages.length * 2;
  const objects = [
    "<< /Type /Catalog /Pages 2 0 R >>",
    `<< /Type /Pages /Count ${pages.length} /Kids [${pages.map((_, i) => `${3 + i * 2} 0 R`).join(" ")}] >>`,
  ];
  for (const [index, items] of pages.entries()) {
    const content = items.map(([value, x, y]) => {
      const escaped = value.replace(/[\\()]/g, "\\$&");
      return `BT /F1 8 Tf 1 0 0 1 ${x} ${y} Tm (${escaped}) Tj ET\n`;
    }).join("");
    objects.push(`<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595.28 841.89] /Resources << /Font << /F1 ${fontId} 0 R >> >> /Contents ${4 + index * 2} 0 R >>`);
    objects.push(`<< /Length ${Buffer.byteLength(content)} >>\nstream\n${content}endstream`);
  }
  objects.push("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>");
  let value = "%PDF-1.4\n";
  const offsets = objects.map((object, index) => {
    const offset = Buffer.byteLength(value);
    value += `${index + 1} 0 obj\n${object}\nendobj\n`;
    return offset;
  });
  const start = Buffer.byteLength(value);
  value += `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`;
  value += offsets.map((offset) => `${String(offset).padStart(10, "0")} 00000 n \n`).join("");
  value += `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${start}\n%%EOF\n`;
  return value;
}

function header() {
  return [["Fixture Ski Event", 160, 807], ["Fixture Place (NOR)", 160, 790],
    ["2026-03-06", 420, 790], ["Men 5 km Individual Start Classic", 160, 758],
    ["Official Results", 238, 735]];
}

function document(firstCount, summaryCount) {
  return pdf([
    [...header(), [`Number of Competitors: ${firstCount}`, 20, 711], ["Finish", 458, 690],
      ["1", 32, 665], ["140", 57, 665], ["Fictional Skier", 81, 671],
      ["Fixture Club", 81, 660], ["NOR", 405, 671], ["11:29.2", 452, 665],
      ["-", 32, 640], ["100", 57, 640], ["Fictional Nonstarter", 81, 646],
      ["DNS", 464, 640], ["Side 1 av 2", 515, 145]],
    [...header(), ["COMPETITORS / NSA", 20, 680], ["Entries", 20, 660],
      [`${summaryCount} / 1`, 20, 645], ["Side 2 av 2", 515, 145]],
  ]);
}

let directory;
beforeEach(async () => {
  directory = await mkdtemp(join(tmpdir(), "nsf-reader-test-"));
});
afterEach(async () => {
  await rm(directory, {recursive: true, force: true});
});

function read(file) {
  // Run the actual ESM PDF dependency outside Jest's CommonJS VM.
  return execFileSync(process.execPath, ["-e", `
    const {readOfficialNsfPdf} = require(process.argv[1]);
    readOfficialNsfPdf(process.argv[2]).then((result) => {
      console.log(JSON.stringify(result));
    }).catch((error) => {
      console.error(error.message);
      process.exitCode = 1;
    });`, join(__dirname, "..", "nsf-official.js"), file], {
    encoding: "utf8", stdio: ["ignore", "pipe", "pipe"],
  });
}

test("the document reader adopts the independently published total from a later page", async () => {
  const file = join(directory, "later-count.pdf");
  await writeFile(file, document(0, 2));
  expect(JSON.parse(read(file))).toMatchObject({
    expectedCount: 2, kind: "timed", rows: [
      {name: "Fictional Skier", rank: 1, totalMs: 689200},
      {name: "Fictional Nonstarter", status: "DNS"},
    ],
  });
});

test("the document reader rejects contradictory totals printed on different pages", async () => {
  const file = join(directory, "conflicting-counts.pdf");
  await writeFile(file, document(2, 3));
  expect(() => read(file)).toThrow(/conflicting published participant totals/);
});
