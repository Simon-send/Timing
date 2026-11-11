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
