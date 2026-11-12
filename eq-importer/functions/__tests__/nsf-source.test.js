"use strict";

/* eslint-disable require-jsdoc */

const {
  addRosterMetadata, collectNsfRace, parseNsfRaceUrl, parseNsfTime, parseSplitTable, phaseForRun,
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


jest.mock("playwright", () => ({chromium: {launch: jest.fn()}}));
const {chromium} = require("playwright");

// Model the public selectors and rendered tables at the browser boundary.
function publicRace(classes) {
  let selected = classes[0];
  let run;
  let roster = false;
  const visited = [];
  const attached = {waitFor: jest.fn(async () => {})};
  const optionLocator = (getOptions) => ({
    first: () => attached,
    evaluateAll: async () => getOptions(),
  });
  const classControl = {
    locator: () => optionLocator(() => classes.map(({id, name}) => ({value: id, name}))),
    inputValue: async () => selected.id,
    selectOption: async (id) => {
      selected = classes.find((item) => item.id === id);
      run = selected.runs?.[0]?.value;
      visited.push(id);
    },
  };
  const runControl = {
    locator: () => optionLocator(() => selected.runs || []),
    inputValue: async () => run,
    selectOption: async (value) => {
      run = value;
    },
  };
  const table = {
    locator: () => ({first: () => attached}),
    evaluate: async () => roster ? {rows: []} : {
      headers: ["Rn.", "#", "Name", "Starttime", "Mål"],
      rows: [{name: selected.name, cells: ["1", "1", selected.name, "12:00", "2:30"]}],
    },
  };
  const page = {
    goto: async (url) => {
      page.currentUrl = url;
      roster = !url.includes("/splits/");
    },
    url: () => page.currentUrl,
    evaluate: async () => "previous row",
    waitForFunction: async () => {
      if (selected.empty || selected.runs?.find((item) => item.value === run)?.empty) {
        throw new Error("No public result rows");
      }
    },
    getByRole: () => ({...attached, first: () => attached, isVisible: async () => false,
      count: async () => 1, click: async () => {}}),
    locator: (selector) => ({
      first: () => selector === "select" ? classControl :
        selector === "table" ? table : {textContent: async () => "Public race"},
      nth: () => runControl,
    }),
  };
  const close = jest.fn(async () => {});
  chromium.launch.mockResolvedValue({newPage: async () => page, close});
  return {visited, close};
}

describe("collecting selected public classes and rounds", () => {
  test("keeps a Ground-only race as distance despite the Sprint navigation button", async () => {
    publicRace([{id: "10_1683", name: "Senior", runs: [{value: "20_1683", name: "Ground"}]}]);
    const source = await collectNsfRace("https://live.nsftiming.no/live/1683");
    expect(source.stages).toMatchObject([{id: "distance", phase: "distance"}]);
  });

  test("selects only requested classes and records the selection in the export", async () => {
    const browser = publicRace([
      {id: "10_703", name: "Empty support class", empty: true},
      {id: "11_703", name: "NC senior"},
    ]);
    const source = await collectNsfRace("https://live.nsftiming.no/live/703", {classIds: ["11_703"]});
    expect(source.classes).toEqual([{id: "11_703", name: "NC senior"}]);
    expect(source.classIds).toEqual(["11_703"]);
    expect(source.stages[0].classes.map((item) => item.classId)).toEqual(["11_703"]);
    expect(browser.visited).toEqual(["11_703"]);
  });

  test.each([[], [""], ["12_703"], ["11_703", "11_703"]].map((ids) => [ids]))(
      "rejects an empty, unknown or repeated class selection (%j)", async (classIds) => {
        publicRace([{id: "11_703", name: "Senior"}]);
        await expect(collectNsfRace("https://live.nsftiming.no/live/703", {classIds}))
            .rejects.toThrow(/class/i);
      });

  test("never skips a requested class without public results", async () => {
    publicRace([{id: "11_703", name: "NC senior", empty: true}]);
    await expect(collectNsfRace("https://live.nsftiming.no/live/703", {classIds: ["11_703"]}))
        .rejects.toThrow("No public result rows");
  });

  test("collects only Ground as prolog when later sprint heats were cancelled", async () => {
    publicRace([{id: "10_1112", name: "M 19-20 år", runs: [
      {value: "20_1112", name: "Ground"},
      {value: "21_1112", name: "Final-A", empty: true},
    ]}]);
    const source = await collectNsfRace("https://live.nsftiming.no/live/1112", {
      classIds: ["10_1112"], sprintPrologOnly: true,
    });
    expect(source.sprintPrologOnly).toBe(true);
    expect(source.stages).toMatchObject([{id: "prolog", phase: "prolog"}]);
    expect(source.stages).toHaveLength(1);
  });

  test("full sprint still requires the public later round results", async () => {
    publicRace([{id: "10_1112", name: "M 19-20 år", runs: [
      {value: "20_1112", name: "Ground"},
      {value: "21_1112", name: "Final-A", empty: true},
    ]}]);
    await expect(collectNsfRace("https://live.nsftiming.no/live/1112"))
        .rejects.toThrow("No public result rows");
  });
});
