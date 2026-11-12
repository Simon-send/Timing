"use strict";

/* eslint-disable require-jsdoc */

const {approvedPdfUrl, parseOfficialPage} = require("../nsf-official");

function item(text, x, y) {
  return {str: text, transform: [1, 0, 0, 1, x, y]};
}

function reportHeader(classLabel) {
  return [
    item("Example Ski Event", 160, 807),
    item("Example Course (NOR)", 160, 790),
    item("2026-03-06", 420, 790),
    item(classLabel, 160, 758),
    item("Offisiell Resultatliste", 238, 735),
    item("Number of Competitors: 2", 20, 711),
  ];
}

describe("official NSF Timing PDF layout", () => {
  test("reads results by position, excluding age and gap columns", () => {
    const page = parseOfficialPage([
      ...reportHeader("Men 5 km Individual Start Classic"),
      item("Finish", 458, 690),
      item("1", 32, 665),
      item("140", 57, 665),
      item("Fictional Skier", 81, 671),
      item("Example Club", 81, 660),
      item("NOR", 405, 671),
      item("15 MAY 2006", 386, 660),
      item("11:29)2", 452, 665),
      item("0.0", 519, 665),
      item("-", 33, 640),
      item("100", 57, 640),
      item("Fictional Nonstarter", 81, 646),
      item("DNS", 464, 640),
      item("Side 1 av 1", 515, 145),
    ]);
    expect(page).toMatchObject({
      name: "Example Ski Event",
      place: "Example Course",
      date: "2026-03-06",
      distanceKm: 5,
      expectedCount: 2,
    });
    expect(page.rows).toEqual([
      {name: "Fictional Skier", bib: "140", club: "Example Club", country: "NOR",
        rank: 1, status: undefined, totalMs: 689200},
      {name: "Fictional Nonstarter", bib: "100", club: undefined, country: undefined,
        rank: undefined, status: "DNS", totalMs: undefined},
    ]);
  });

  test("keeps overall sprint placement separate from the phase values", () => {
    const page = parseOfficialPage([
      ...reportHeader("Women Sprint"),
      item("QUALIF.", 237, 692),
      item("1", 29, 648.8),
      item("5", 57, 648.3),
      item("Fictional Winner", 68.2, 648.3),
      item("NOR", 212, 648.3),
      item("+1.18 (5)", 250, 648.2),
      item("3:14.21 (1)", 461, 648.2),
      item("3:18.49 (1)", 536, 649.3),
      item("104", 48, 626.3),
      item("Fictional Unranked", 68.2, 626.3),
      item("SWE", 212, 626.3),
      item("+12.73 (21)", 243, 626.2),
      item("Course", 431, 409),
      item("LENGTH OF LAP", 324, 349),
      item("1.4 km", 536, 349),
      item("NUMBER OF LAPS", 324, 339),
      item("1", 562, 339),
    ]);
    expect(page).toMatchObject({courseCount: 1, courseDistanceKm: 1.4});
    expect(page.rows).toEqual([
      {name: "Fictional Winner", bib: "5", club: undefined, country: "NOR",
        rank: 1, status: undefined, totalMs: undefined},
      {name: "Fictional Unranked", bib: "104", club: undefined, country: "SWE",
        rank: undefined, status: undefined, totalMs: undefined, unranked: true},
    ]);
  });

  test("recognizes a split official header and an English official result header", () => {
    for (const header of [
      [item("Offisiell", 234.6, 735), item("Resultatliste", 282.4, 735)],
      [item("Official Results", 238, 735)],
    ]) {
      const page = parseOfficialPage([
        ...reportHeader("Men 10 km").filter((entry) => entry.str !== "Offisiell Resultatliste"),
        ...header, item("Finish", 458, 690),
      ]);
      expect(page).toMatchObject({kind: "timed", className: "Men 10 km", expectedCount: 2});
    }
  });

  test("reads an independently published Entries/NSA total on a summary-only page", () => {
    const page = parseOfficialPage([
      ...reportHeader("Men 10 km").filter((entry) => !entry.str.startsWith("Number of Competitors")),
      item("Jury", 137, 710), item("Course", 430, 710),
      item("COMPETITORS / NSA", 394, 497), item("ENTRIES", 288, 484),
      item("172 / 10", 288, 471),
    ]);
    expect(page).toMatchObject({expectedCount: 172, rows: []});
  });

  test("ignores a zero placeholder and never derives the total from readable rows", () => {
    const page = parseOfficialPage([
      ...reportHeader("Women sprint").filter((entry) => !entry.str.startsWith("Number of Competitors")),
      item("Number of Competitors: 0", 20, 711), item("Finish", 458, 690),
      item("1", 32, 665), item("584", 57, 665), item("Fictional Skier", 81, 671),
      item("2:17.35", 452, 665),
    ]);
    expect(page.rows).toHaveLength(1);
    expect(page.expectedCount).toBeUndefined();
  });

  test("rejects contradictory published totals instead of choosing one", () => {
    expect(() => parseOfficialPage([
      ...reportHeader("Men 10 km"), item("Finish", 458, 690),
      item("COMPETITORS / NSA", 394, 497), item("ENTRIES", 288, 484),
      item("3 / 1", 288, 471),
    ])).toThrow(/count|total/i);
  });

  test("keeps four-digit sprint bibs separate from official ranks", () => {
    const page = parseOfficialPage([
      ...reportHeader("M 18 år 1,2 km"), item("QUALIF.", 237, 692),
      item("31", 24, 648.8), item("1000", 43.5, 648.3),
      item("Fictional Skier", 68.2, 648.3), item("NOR", 212, 648.3),
      item("+12.00 (31)", 243, 648.2),
    ]);
    expect(page.rows).toEqual([expect.objectContaining({bib: "1000", rank: 31, name: "Fictional Skier"})]);
  });

  test("accepts the printed asterisk decimal separator and excludes a long gap from finish", () => {
    const page = parseOfficialPage([
      ...reportHeader("Men 50 km"), item("Finish", 458, 690),
      item("1", 32, 665), item("1", 62, 665), item("Fictional Sprinter", 81, 671),
      item("2:21*47", 452, 665),
      item("144", 28, 640), item("16", 59, 640), item("Fictional Distance Skier", 81, 646),
      item("3:16:08.5", 445, 640), item("1:13:24.2", 495.8, 640),
    ]);
    expect(page.rows.map((row) => row.totalMs)).toEqual([141470, 11768500]);
  });

  test("does not upgrade an explicitly unofficial list", () => {
    for (const extra of [[], [
      item("Results", 292, 634), item("Sprint Final", 283, 648),
      item("Name", 100, 618), item("Rk.", 66, 618), item("Qualification", 292, 617),
    ]]) {
      expect(() => parseOfficialPage([
        ...reportHeader("Women sprint").filter((entry) => entry.str !== "Offisiell Resultatliste"),
        item("Uoffisiell Resultatliste", 234, 735), item("Finish", 458, 690), ...extra,
      ])).toThrow(/official NSF/);
    }
  });

  test("reads the published FIS sprint final layout and its independent Entries total", () => {
    const page = parseOfficialPage([
      item("SPRINT EXAMPLE", 272, 717), item("(NOR)", 295, 687),
      item("Kvinner senior Sprint Classic", 246, 661), item("29-11-2025", 517, 659),
      item("Sprint Final", 283, 648), item("Results", 292, 634),
      item("Rk.", 66, 618), item("Bib", 87, 618), item("Name", 100, 618),
      item("NSA", 238, 617), item("Qualification", 292, 617),
      item("Final", 60, 600), item("1", 70, 580), item("5", 91, 580),
      item("SKIER Fictional Winner", 101, 580), item("NOR", 237, 580),
      item("3:14.21 (1)", 526, 580),
      item("Did not start", 62, 550), item("NONSTARTER Fictional", 101, 535),
      item("SWE", 237, 535),
      item("Participants", 447, 395), item("Entries", 381, 385), item("2/ 2", 384, 376),
      item("Sidan 1 av 1", 490, 119),
    ]);
    expect(page).toMatchObject({kind: "sprint-overall", date: "2025-11-29", expectedCount: 2,
      className: "Kvinner senior Sprint Classic"});
    expect(page.rows).toEqual([
      {name: "Fictional Winner Skier", bib: "5", country: "NOR", rank: 1, status: undefined},
      {name: "Fictional Nonstarter", bib: undefined, country: "SWE", rank: undefined, status: "DNS"},
    ]);
    expect(page.rows[0]).not.toHaveProperty("totalMs");
  });

  test("accepts an explicitly official legend-only continuation page", () => {
    expect(parseOfficialPage([
      ...reportHeader("M 17 år sprint free").filter((entry) => !entry.str.startsWith("Number of Competitors")),
      item("Legend", 24, 703), item("DNF", 24, 693), item("Did Not Finish", 51, 693),
    ])).toMatchObject({rows: [], className: "M 17 år sprint free"});
  });

  test("a generic Results heading does not establish an official sprint report", () => {
    expect(() => parseOfficialPage([item("Results", 292, 634), item("Name", 100, 618)]))
        .toThrow(/official NSF/);
  });

  test("rejects a document without an official result header", () => {
    expect(() => parseOfficialPage([item("Finish", 458, 690)])).toThrow("official NSF");
  });

  test("accepts public federation PDFs from the result asset directories", () => {
    expect(approvedPdfUrl("https://www.skiforbundet.no/globalassets/season/results.pdf").pathname)
        .toBe("/globalassets/season/results.pdf");
    expect(approvedPdfUrl("https://www.skiforbundet.no/contentassets/season/results.pdf").pathname)
        .toBe("/contentassets/season/results.pdf");
  });

  test.each([
    "https://www.skiforbundet.no.invalid/contentassets/season/results.pdf",
    "https://www.skiforbundet.no/admin/season/results.pdf",
    "https://user:pass@www.skiforbundet.no/globalassets/results.pdf",
    "https://www.skiforbundet.no/globalassets/results.pdf?next=other",
    "http://www.skiforbundet.no/globalassets/results.pdf",
  ])("rejects an unsupported remote PDF URL (%s)", (url) => {
    expect(() => approvedPdfUrl(url)).toThrow("public Skiforbundet PDF");
  });
});

test("a wrapped class heading keeps its class name instead of the final word fragment", () => {
  const page = parseOfficialPage([
    ...reportHeader("Kvinner senior 20 km Individual Start Clas"),
    item("sic", 160, 748),
    item("Finish", 458, 690),
    item("1", 32, 665), item("140", 57, 665),
    item("Fictional Skier", 81, 671), item("Example Club", 81, 660),
    item("NOR", 405, 671), item("54:47.4", 452, 665),
  ]);
  expect(page.className).toMatch(/^Kvinner senior /);
  expect(page.distanceKm).toBe(20);
});

test("a wrapped two-digit junior class heading keeps the complete class prefix", () => {
  const page = parseOfficialPage([
    ...reportHeader("K 19-20 år 10 km Individual Start Clas"),
    item("sic", 160, 748), item("Finish", 458, 690),
    item("1", 32, 665), item("140", 57, 665),
    item("Fictional Skier", 81, 671), item("11:29.2", 452, 665),
  ]);
  expect(page.className).toMatch(/^K 19-20 år /);
});
