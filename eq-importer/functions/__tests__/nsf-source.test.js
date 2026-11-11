"use strict";

const {
  addRosterMetadata, parseNsfRaceUrl, parseNsfTime, parseSplitTable, phaseForRun,
} = require("../nsf-source");

describe("public NSF Timing source", () => {
  test("normalizes the modern, legacy and split-view race links", () => {
    const expected = {id: "782", url: "https://live.nsftiming.no/live/782"};
    expect(parseNsfRaceUrl("https://live.nsftiming.no/live/782")).toEqual(expected);
    expect(parseNsfRaceUrl("https://live.nsftiming.no/live/splits/782")).toEqual(expected);
    expect(parseNsfRaceUrl("https://live.nsftiming.no/live/sprint/782")).toEqual(expected);
    expect(parseNsfRaceUrl("https://cis.nsftiming.no/live?raceid=782")).toEqual(expected);
  });

  test.each([
    "http://live.nsftiming.no/live/782",
    "https://live.nsftiming.no.invalid/live/782",
    "https://user:pass@live.nsftiming.no/live/782",
    "https://live.nsftiming.no:444/live/782",
    "https://live.nsftiming.no/api/782",
    "https://cis.nsftiming.no/live?raceid=782&raceid=783",
    "https://cis.nsftiming.no/live?raceid=foo",
  ])("rejects an unsupported race URL (%s)", (url) => {
    expect(() => parseNsfRaceUrl(url)).toThrow("public");
  });

  test.each([
    ["1:06:04.9", 3964900],
    ["2:33,87", 153870],
    ["59.999", 59999],
    ["0.0", 0],
    ["+1:03.22", undefined],
    ["1:60.05", undefined],
    ["1:65:05.0", undefined],
  ])("parses an absolute clock value (%s)", (clock, expected) => {
    expect(parseNsfTime(clock)).toBe(expected);
  });

  test("parses checkpoint distances and cumulative times independently of gaps", () => {
    const table = {
      headers: ["", "Rn.", "#", "Name", "Starttime", "1,2 km", "Mål"],
      rows: [
        {name: "Fictional Skier", club: "Sample Ski", cells: [
          "", "1", "31", "Fictional Skier", "11:32:00", "2:33.87 (2) +0.04", "3:12.04 (1)↑1",
        ]},
        {name: "Fictional Nonfinisher", cells: [
          "", "DNF", "32", "Fictional Nonfinisher", "11:32:30", "2:34.28 (3)", "",
        ]},
        {name: "Fictional DNS", cells: [
          "", "", "33", "Fictional DNS", "", "+0.35", "DNS",
        ]},
      ],
    };
    const result = parseSplitTable(table, 1.4);
    expect(result.points).toEqual([
      {id: "split-1", label: "1,2 km", km: 1.2, kind: "split"},
      {id: "finish", label: "Mål", km: 1.4, kind: "finish"},
    ]);
    expect(result.rows[0]).toMatchObject({
      bib: "31", name: "Fictional Skier", club: "Sample Ski", rank: 1, totalMs: 192040,
      points: {"split-1": {cumMs: 153870, rank: 2}, "finish": {cumMs: 192040, rank: 1}},
    });
    expect(result.rows[1]).toMatchObject({
      bib: "32", status: "DNF", points: {"split-1": {cumMs: 154280, rank: 3}},
    });
    expect(result.rows[1].totalMs).toBeUndefined();
    expect(result.rows[2]).toMatchObject({bib: "33", status: "DNS", points: {}});
  });

  test("matches a heat athlete across changed bibs only when club identifies the athlete", () => {
    const qualification = {name: "Fictional Skier", bib: "89", club: "Ski Club A"};
    const heat = {name: "Fictional Skier", bib: "9", club: "Ski Club A"};
    const ambiguous = {name: "Fictional Skier", bib: "10", club: "Ski Club B"};
    addRosterMetadata([
      {phase: "prolog", classes: [{rows: [qualification]}]},
      {phase: "semifinal", classes: [{rows: [heat, ambiguous]}]},
    ], [
      {name: "Fictional Skier", bib: "89", club: "Ski Club A", team: "Team A", country: "NOR"},
      {name: "Fictional Skier", bib: "91", club: "Ski Club B", team: "Team B", country: "NOR"},
      {name: "Fictional Skier", bib: "96", club: "Ski Club B", team: "Team C", country: "SWE"},
    ]);
    expect(qualification).toMatchObject({team: "Team A", country: "NOR"});
    expect(heat).toMatchObject({team: "Team A", country: "NOR"});
    expect(ambiguous.team).toBeUndefined();
  });

  test("rejects a checkpoint table with no identifiable finish", () => {
    expect(() => parseSplitTable({
      headers: ["", "Rn.", "#", "Name", "Starttime", "1,2 km"], rows: [],
    })).toThrow("split table layout");
  });

  test("separates qualification and every labeled heat", () => {
    expect(phaseForRun("Qualification")).toMatchObject({id: "prolog", order: 0});
    expect(phaseForRun("Quarterfinal-5")).toMatchObject({
      id: "quarterfinal-5", heat: 5, phase: "quarterfinal", order: 105,
    });
    expect(phaseForRun("Semifinal-2")).toMatchObject({phase: "semifinal", order: 202});
    expect(phaseForRun("Final-A")).toMatchObject({id: "final-a", heat: "A", order: 301});
    expect(() => phaseForRun("Unrecognized")).toThrow("Unsupported");
  });
});
