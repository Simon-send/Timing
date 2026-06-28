"use strict";

const mockAxiosGet = jest.fn();
const mockCreateTask = jest.fn();
const mockQueuePath = jest.fn(() => "queue-path");

let mockState;

jest.mock("axios", () => ({
  get: (...args) => mockAxiosGet(...args),
}));

jest.mock("firebase-functions", () => ({
  runWith: () => ({
    https: {
      onRequest: (...args) => args[args.length - 1],
    },
  }),
  https: {
    onRequest: (...args) => args[args.length - 1],
  },
}));

jest.mock("@google-cloud/tasks", () => ({
  CloudTasksClient: jest.fn(() => ({
    createTask: mockCreateTask,
    queuePath: mockQueuePath,
  })),
}));

jest.mock("firebase-admin", () => {
  const DELETE_FIELD = {__fieldValueDelete: true};

  const isDeleteField = function(value) {
    return value && value.__fieldValueDelete === true;
  };

  const createFirestoreState = function() {
    const docs = new Map();
    const writes = [];
    let autoId = 0;

    const applySet = function(path, data, options) {
      for (const [key, value] of Object.entries(data || {})) {
        if (isDeleteField(value) && !(options && options.merge)) {
          throw new Error(
            "Value for argument \"data\" is not a valid Firestore document. " +
            "FieldValue.delete() must appear at the top-level and can only be " +
            `used in update() or set() with {merge:true} (found in field "${key}").`,
          );
        }
      }

      const previous = docs.get(path) || {};
      const next = options && options.merge ?
        Object.assign({}, previous, data) :
        Object.assign({}, data);

      for (const [key, value] of Object.entries(next)) {
        if (isDeleteField(value)) delete next[key];
      }

      docs.set(path, next);
      writes.push({path, data: next, options: options || null});
    };

    const applyDelete = function(path) {
      docs.delete(path);
      writes.push({path, data: null, options: {delete: true}});
    };

    const makeDocRef = function(path) {
      return {
        path,
        id: path.split("/").pop(),
        collection: function(name) {
          return makeCollectionRef(path + "/" + name);
        },
        set: jest.fn((data, options) => {
          applySet(path, data, options);
          return Promise.resolve();
        }),
        get: jest.fn(() => Promise.resolve(
          docs.has(path) ?
            {exists: true, data: () => docs.get(path)} :
            {exists: false},
        )),
      };
    };

    const makeCollectionRef = function(path) {
      return {
        path,
        doc: function(id) {
          const docId = id || "auto-" + (++autoId);
          return makeDocRef(path + "/" + docId);
        },
        get: jest.fn(() => {
          const prefix = path + "/";
          const collectionDocs = [];
          for (const [docPath, data] of docs.entries()) {
            if (!docPath.startsWith(prefix)) continue;
            const rest = docPath.slice(prefix.length);
            if (rest.includes("/")) continue;
            collectionDocs.push({
              id: rest,
              ref: makeDocRef(docPath),
              data: () => data,
            });
          }
          return Promise.resolve({docs: collectionDocs});
        }),
      };
    };

    return {
      docs,
      writes,
      db: {
        collection: function(name) {
          return makeCollectionRef(name);
        },
        batch: function() {
          const ops = [];

          return {
            set: function(ref, data, options) {
              ops.push({ref, data, options});
            },
            delete: function(ref) {
              ops.push({ref, delete: true});
            },
            commit: jest.fn(() => {
              for (const op of ops) {
                if (op.delete) {
                  applyDelete(op.ref.path);
                } else {
                  applySet(op.ref.path, op.data, op.options);
                }
              }
              return Promise.resolve();
            }),
          };
        },
      },
    };
  };

  return {
    initializeApp: jest.fn(),
    firestore: Object.assign(() => {
      mockState = createFirestoreState();
      return mockState.db;
    }, {
      FieldValue: {
        serverTimestamp: jest.fn(() => "SERVER_TIMESTAMP"),
        arrayUnion: jest.fn((...values) => values),
        delete: jest.fn(() => DELETE_FIELD),
      },
    }),
  };
});

const loadModule = function() {
  jest.resetModules();
  mockAxiosGet.mockReset();
  mockCreateTask.mockReset();
  mockQueuePath.mockClear();
  mockState = null;
  return require("../index.js");
};

const makeResponse = function() {
  const res = {
    statusCode: 200,
    body: undefined,
  };

  res.status = jest.fn((code) => {
    res.statusCode = code;
    return res;
  });
  res.json = jest.fn((payload) => {
    res.body = payload;
    return res;
  });
  res.send = jest.fn((payload) => {
    res.body = payload;
    return res;
  });

  return res;
};

const buildImportFixtures = function() {
  return {
    event: {
      Navn: "Test Event",
      Gren: {
        Navn: "Skiskyting",
        Kode: "BT",
        Parent: {
          Name: "Biathlon",
        },
      },
      Klasser: {
        "1224375": {
          Navn: "K17",
        },
      },
      Etapper: {
        "330315": {
          Klasser: {
            "1224375": {},
          },
        },
      },
      Stasjoner: {
        "201150": {
          Navn: "Inn skyting",
          StasjonsOppsett: {
            "1434583": {
              EtappeUID: 330315,
              Navn: "IS1",
              Sortering: 1,
              Km: 1.2,
              Er_start: false,
              Er_stopp: false,
            },
            "1434582": {
              EtappeUID: 330315,
              Navn: "Maal",
              Sortering: 2,
              Km: 2.4,
              Er_start: false,
              Er_stopp: true,
            },
          },
        },
      },
    },
    participants: {
      "101": {
        UID: 101,
        Startnummer: 7,
        Klasse: {
          UID: 1224375,
          Navn: "K17",
        },
        Arrangement: {
          UID: 80088,
        },
        Pulje: {
          EtappeUID: 330315,
        },
        Utover: {
          UID: 1001,
          Fornavn: "Ada",
          Etternavn: "Lovelace",
          Fodselsaar: 1815,
        },
        Klubb: {
          UID: 90001,
          Navn: "Oslo Skiklubb",
        },
        Skole: {
          UID: 3001,
          Navn: "Oslo Katedralskole",
        },
        Team: {
          UID: 4001,
          Navn: "Team Oslo",
        },
        EtappeDeltaker: {
          "9001": {},
        },
      },
    },
    stationOneTimes: {
      Items: [
        {
          EtappeDeltakerUID: 9001,
          StasjonsOppsettUID: 1434583,
          AkkumulertTid: 60000,
          Formatert: "1:00.0",
          Splitt: {
            Tid: 60000,
            Formatert: "1:00.0",
          },
          StatusTekst: "TIME",
        },
      ],
    },
    stationTwoTimes: {
      Items: [
        {
          EtappeDeltakerUID: 9001,
          StasjonsOppsettUID: 1434582,
          AkkumulertTid: 120000,
          Formatert: "2:00.0",
          Splitt: {
            Tid: 60000,
            Formatert: "1:00.0",
          },
          StatusTekst: "TIME",
        },
      ],
    },
  };
};

const buildMultiDistanceFixtures = function() {
  return {
    event: {
      Navn: "Distance Event",
      Gren: {
        Navn: "Skiskyting",
        Kode: "BT",
        Parent: {
          Name: "Biathlon",
        },
      },
      Klasser: {
        "1224375": {
          Navn: "Kort",
        },
        "1224376": {
          Navn: "Lang",
        },
      },
      Etapper: {
        "330315": {
          Klasser: {
            "1224375": {},
          },
        },
        "330419": {
          Klasser: {
            "1224376": {},
          },
        },
      },
      Stasjoner: {
        "201150": {
          Navn: "Kort-lop",
          StasjonsOppsett: {
            "1434583": {
              EtappeUID: 330315,
              Navn: "Kort-IS1",
              Sortering: 1,
              Km: 1.2,
              Er_start: false,
              Er_stopp: false,
            },
            "1434582": {
              EtappeUID: 330315,
              Navn: "Kort-Maal",
              Sortering: 2,
              Km: 2.4,
              Er_start: false,
              Er_stopp: true,
            },
          },
        },
        "201250": {
          Navn: "Lang-lop",
          StasjonsOppsett: {
            "2434583": {
              EtappeUID: 330419,
              Navn: "Lang-IS1",
              Sortering: 1,
              Km: 2.0,
              Er_start: false,
              Er_stopp: false,
            },
            "2434582": {
              EtappeUID: 330419,
              Navn: "Lang-Maal",
              Sortering: 2,
              Km: 4.0,
              Er_start: false,
              Er_stopp: true,
            },
          },
        },
      },
    },
    participants: {
      "101": {
        UID: 101,
        Startnummer: 7,
        Klasse: {
          UID: 1224375,
          Navn: "Kort",
        },
        Arrangement: {
          UID: 80088,
        },
        Pulje: {
          EtappeUID: 330315,
        },
        Utover: {
          UID: 1001,
          Fornavn: "Ada",
          Etternavn: "Lovelace",
          Fodselsaar: 1815,
        },
        Klubb: {
          UID: 90001,
          Navn: "Oslo Skiklubb",
        },
        Skole: {
          UID: 3001,
          Navn: "Oslo Katedralskole",
        },
        Team: {
          UID: 4001,
          Navn: "Team Oslo",
        },
        EtappeDeltaker: {
          "9001": {},
        },
      },
      "202": {
        UID: 202,
        Startnummer: 9,
        Klasse: {
          UID: 1224376,
          Navn: "Lang",
        },
        Arrangement: {
          UID: 80088,
        },
        Pulje: {
          EtappeUID: 330419,
        },
        Utover: {
          UID: 2002,
          Fornavn: "Grace",
          Etternavn: "Hopper",
          Fodselsaar: 1906,
        },
        Klubbnavn: " Bergen Ski ",
        SkoleNavn: "  Bergen Handelsgym  ",
        LagNavn: " Vestland Lag ",
        EtappeDeltaker: {
          "9002": {},
        },
      },
    },
    shortStationOneTimes: {
      Items: [
        {
          EtappeDeltakerUID: 9001,
          StasjonsOppsettUID: 1434583,
          AkkumulertTid: 60000,
          Formatert: "1:00.0",
          Splitt: {
            Tid: 60000,
            Formatert: "1:00.0",
          },
          StatusTekst: "TIME",
        },
      ],
    },
    shortStationTwoTimes: {
      Items: [
        {
          EtappeDeltakerUID: 9001,
          StasjonsOppsettUID: 1434582,
          AkkumulertTid: 120000,
          Formatert: "2:00.0",
          Splitt: {
            Tid: 60000,
            Formatert: "1:00.0",
          },
          StatusTekst: "TIME",
        },
      ],
    },
    longStationOneTimes: {
      Items: [
        {
          EtappeDeltakerUID: 9002,
          StasjonsOppsettUID: 2434583,
          AkkumulertTid: 90000,
          Formatert: "1:30.0",
          Splitt: {
            Tid: 90000,
            Formatert: "1:30.0",
          },
          StatusTekst: "TIME",
        },
      ],
    },
    longStationTwoTimes: {
      Items: [
        {
          EtappeDeltakerUID: 9002,
          StasjonsOppsettUID: 2434582,
          AkkumulertTid: 210000,
          Formatert: "3:30.0",
          Splitt: {
            Tid: 120000,
            Formatert: "2:00.0",
          },
          StatusTekst: "TIME",
        },
      ],
    },
  };
};

const buildDuplicateClassAcrossDistancesFixtures = function() {
  return {
    event: {
      Navn: "Sprint Event",
      Gren: {
        Navn: "Skiskyting",
        Kode: "BT",
        Parent: {
          Name: "Biathlon",
        },
      },
      Klasser: {
        "5001": {
          Navn: "Kvinner senior 20-21",
        },
      },
      Etapper: {
        "7001": {
          Navn: "Sprint Menn senior 20-21",
          Klasser: {
            "5001": {},
          },
        },
        "7002": {
          Navn: "Sprint Kvinner senior 20-21",
          Klasser: {
            "5001": {},
          },
        },
      },
      Stasjoner: {
        "301001": {
          Navn: "Menn-lop",
          StasjonsOppsett: {
            "8001": {
              EtappeUID: 7001,
              Navn: "Menn-Maal",
              Sortering: 1,
              Km: 3.0,
              Er_start: false,
              Er_stopp: true,
            },
          },
        },
        "301002": {
          Navn: "Kvinner-lop",
          StasjonsOppsett: {
            "9001": {
              EtappeUID: 7002,
              Navn: "Kvinner-IS1",
              Sortering: 1,
              Km: 1.5,
              Er_start: false,
              Er_stopp: false,
            },
            "9002": {
              EtappeUID: 7002,
              Navn: "Kvinner-Maal",
              Sortering: 2,
              Km: 3.0,
              Er_start: false,
              Er_stopp: true,
            },
          },
        },
      },
    },
    participants: {
      "501": {
        UID: 501,
        Startnummer: 11,
        Klasse: {
          UID: 5001,
          Navn: "Kvinner senior 20-21",
        },
        Arrangement: {
          UID: 80088,
        },
        Pulje: {
          EtappeUID: 7002,
        },
        Utover: {
          UID: 5001,
          Fornavn: "Ingrid",
          Etternavn: "Skjaeveland",
        },
        Klubbnavn: "Team Rogaland",
        EtappeDeltaker: {
          "9501": {},
        },
      },
    },
    womenStationOneTimes: {
      Items: [
        {
          EtappeDeltakerUID: 9501,
          StasjonsOppsettUID: 9001,
          AkkumulertTid: 65000,
          Formatert: "1:05.0",
          Splitt: {
            Tid: 65000,
            Formatert: "1:05.0",
          },
          StatusTekst: "TIME",
        },
      ],
    },
    womenStationTwoTimes: {
      Items: [
        {
          EtappeDeltakerUID: 9501,
          StasjonsOppsettUID: 9002,
          AkkumulertTid: 140000,
          Formatert: "2:20.0",
          Splitt: {
            Tid: 75000,
            Formatert: "1:15.0",
          },
          StatusTekst: "TIME",
        },
      ],
    },
  };
};

const buildResultsOnlySubclassFixtures = function() {
  return {
    event: {
      Navn: "Results Subclass Event",
      Gren: {
        Navn: "Skiskyting",
        Kode: "BT",
        Parent: {
          Name: "Biathlon",
        },
      },
      Klasser: {
        "1146500": {
          Navn: "Menn senior",
        },
        "1146503": {
          Navn: "Menn U23",
        },
      },
      Etapper: {
        "314477": {
          Navn: "5 km",
          Klasser: {
            "1146500": {},
            "1146503": {},
          },
        },
      },
      Stasjoner: {
        "401001": {
          Navn: "Lop",
          StasjonsOppsett: {
            "5101": {
              EtappeUID: 314477,
              Navn: "M1",
              Sortering: 1,
              Km: 2.5,
              Er_start: false,
              Er_stopp: false,
            },
            "5102": {
              EtappeUID: 314477,
              Navn: "Maal",
              Sortering: 2,
              Km: 5.0,
              Er_start: false,
              Er_stopp: true,
            },
          },
        },
      },
    },
    participants: {
      "701": {
        UID: 701,
        Startnummer: 101,
        Klasse: {
          UID: 1146500,
          Navn: "Menn senior",
        },
        Arrangement: {
          UID: 74689,
        },
        Pulje: {
          EtappeUID: 314477,
        },
        Utover: {
          UID: 7001,
          Fornavn: "Ole",
          Etternavn: "Senior",
        },
        Klubbnavn: "Lyn Ski",
        EtappeDeltaker: {
          "9701": {},
        },
      },
    },
    seniorStationOneTimes: {
      Items: [
        {
          EtappeDeltakerUID: 9701,
          StasjonsOppsettUID: 5101,
          AkkumulertTid: 310000,
          Formatert: "5:10.0",
          Splitt: {
            Tid: 310000,
            Formatert: "5:10.0",
          },
          StatusTekst: "TIME",
        },
      ],
    },
    seniorStationTwoTimes: {
      Items: [
        {
          EtappeDeltakerUID: 9701,
          StasjonsOppsettUID: 5102,
          AkkumulertTid: 666000,
          Formatert: "11:06.0",
          Splitt: {
            Tid: 356000,
            Formatert: "5:56.0",
          },
          StatusTekst: "TIME",
        },
      ],
    },
    u23StationOneTimes: {
      Items: [
        {
          EtappeDeltakerUID: 9801,
          StasjonsOppsettUID: 5101,
          AkkumulertTid: 300000,
          Formatert: "5:00.0",
          Splitt: {
            Tid: 300000,
            Formatert: "5:00.0",
          },
          StatusTekst: "TIME",
        },
      ],
    },
    u23StationTwoTimes: {
      Items: [
        {
          EtappeDeltakerUID: 9801,
          StasjonsOppsettUID: 5102,
          AkkumulertTid: 660000,
          Formatert: "11:00.0",
          Splitt: {
            Tid: 360000,
            Formatert: "6:00.0",
          },
          StatusTekst: "TIME",
        },
      ],
    },
  };
};

describe("eq importer helpers", () => {
  test("buildStationSetupMap treats MT passings as regular splits", () => {
    const mod = loadModule();
    const setupMap = mod._test.buildStationSetupMap({
      Stasjoner: {
        "10": {
          Navn: "Mellomtid",
          StasjonsOppsett: {
            "20": {
              EtappeUID: 30,
              Navn: "MT1",
            },
          },
        },
      },
    });

    expect(setupMap.get(30).get(20).kind).toBe("split");
  });

  test("buildEtappeMap maps etappeDeltakerUid to participantUid", () => {
    const mod = loadModule();
    const map = mod._test.buildEtappeMap({
      "101": {
        EtappeDeltaker: {
          "9001": {},
          "9002": {},
        },
      },
      "102": {
        EtappeDeltaker: {
          "9100": {},
        },
      },
    });

    expect(map.get(9001)).toBe(101);
    expect(map.get(9002)).toBe(101);
    expect(map.get(9100)).toBe(102);
  });

  test("normalizeTimes reads flat Items payload", () => {
    const mod = loadModule();
    const records = mod._test.normalizeTimes({
      Items: [
        {
          EtappeDeltakerUID: 10,
          StasjonsOppsettUID: 20,
          AkkumulertTid: 1234,
          Formatert: "0:01.2",
          Splitt: {
            Tid: 500,
            Formatert: "0:00.5",
          },
          StatusTekst: "TIME",
        },
      ],
    });

    expect(records).toEqual([
      expect.objectContaining({
        edUid: 10,
        soUid: 20,
        cumMs: 1234,
        cumText: "0:01.2",
        legMs: 500,
        legText: "0:00.5",
        status: "TIME",
        passTime: null,
        roundNumber: null,
        addition: null,
        additionParts: null,
        additionTotal: null,
        sourceType: "item",
      }),
    ]);
  });

  test("normalizeTimes accepts lowercase items and rangeringsTid fallback", () => {
    const mod = loadModule();
    const records = mod._test.normalizeTimes({
      items: [
        {
          EtappeDeltakerUID: 10,
          StasjonsOppsettUID: 20,
          RangeringsTid: 4321,
          Formatert: "0:04.3",
          Splitt: {},
        },
      ],
    });

    expect(records[0].cumMs).toBe(4321);
    expect(records[0].cumText).toBe("0:04.3");
  });

  test("normalizeTimes flattens nested passeringer and deduplicates station rows", () => {
    const mod = loadModule();
    const records = mod._test.normalizeTimes({
      Items: [
        {
          EtappeDeltakerUID: 10,
          StasjonsOppsettUID: 20,
          RangeringsTid: 2000,
          Formatert: "0:02.0",
          Passeringer: {
            "10": {
              "1": {
                Key: 1,
                EtappeDeltakerUID: 10,
                StasjonsOppsettUID: 10,
                AkkumulertTid: 1000,
                Formatert: "0:01.0",
                Tillegg: "0",
                Splitt: {Tid: 1000, Formatert: "0:01.0"},
                Diff: {Klasse: 0, KlasseFormatert: "0:00.0"},
                Plassering: {Klasse: 1},
              },
              "2": {
                Key: 2,
                StasjonsOppsettUID: 20,
                AkkumulertTid: 2000,
                Formatert: "0:02.0",
                Tillegg: "1",
                Splitt: {Tid: 1000, Formatert: "0:01.0"},
              },
            },
          },
        },
      ],
    });

    expect(records).toHaveLength(2);
    expect(records[0]).toMatchObject({
      edUid: 10,
      soUid: 10,
      passKey: "1",
      sourceType: "nested-pass",
      additionParts: [0],
      additionTotal: 0,
      diff: {class: 0, classText: "0:00.0"},
      placement: {class: 1},
    });
    expect(records[1]).toMatchObject({
      edUid: 10,
      soUid: 20,
      passKey: "2",
      sourceType: "nested-pass",
      cumMs: 2000,
      additionParts: [1],
      additionTotal: 1,
    });
  });

  test("normalizeTimes uses nested StasjonsOppsett UID when top-level UID is zero", () => {
    const mod = loadModule();
    const records = mod._test.normalizeTimes({
      Items: [
        {
          EtappeDeltakerUID: 10,
          Passeringer: {
            "1": {
              StasjonsOppsettUID: 0,
              StasjonsOppsett: {
                UID: 20,
                Navn: "Maal",
              },
              AkkumulertTid: 123000,
              Formatert: "2:03.0",
            },
          },
        },
      ],
    });

    expect(records).toHaveLength(1);
    expect(records[0]).toMatchObject({
      edUid: 10,
      soUid: 20,
      cumMs: 123000,
      cumText: "2:03.0",
    });
  });

  test("normalizeClubName trims, collapses whitespace and lowercases", () => {
    const mod = loadModule();
    expect(mod._test.normalizeClubName("  Oslo   SKIklubb ")).toBe("oslo skiklubb");
  });

  test("buildClubDoc, buildAffiliationDoc and buildAthleteDoc create normalized top-level docs", () => {
    const mod = loadModule();
    const participant = {
      UID: 101,
      Alder: 17,
      Utover: {
        UID: 1001,
        Fornavn: "Ada",
        Etternavn: "Lovelace",
        Kjonn: "F",
        Fodselsaar: 1815,
      },
      Klubb: {
        UID: 42,
        Navn: " Oslo Skiklubb ",
      },
      Skole: {
        UID: 77,
        Navn: " Oslo Katedralskole ",
      },
      Team: {
        UID: 88,
        Navn: " Team Oslo ",
      },
    };

    const clubDoc = mod._test.buildClubDoc(participant);
    const schoolDoc = mod._test.buildAffiliationDoc("school", participant);
    const teamDoc = mod._test.buildAffiliationDoc("team", participant);
    const athleteDoc = mod._test.buildAthleteDoc(
      participant,
      clubDoc.clubId,
      schoolDoc.clubId,
      null,
      teamDoc.clubId,
      null,
    );

    expect(clubDoc).toEqual({
      clubId: "club:42",
      name: " Oslo Skiklubb ",
      normalizedName: "oslo skiklubb",
      sourceRefs: [
        {
          provider: "eqtiming",
          sourceClubId: "42",
          sourceName: " Oslo Skiklubb ",
        },
      ],
    });
    expect(schoolDoc).toEqual({
      clubId: "school:77",
      type: "school",
      name: " Oslo Katedralskole ",
      normalizedName: "oslo katedralskole",
      sourceRefs: [
        {
          provider: "eqtiming",
          sourceClubId: "77",
          sourceName: " Oslo Katedralskole ",
        },
      ],
    });
    expect(teamDoc).toEqual({
      clubId: "team:88",
      type: "team",
      name: " Team Oslo ",
      normalizedName: "team oslo",
      sourceRefs: [
        {
          provider: "eqtiming",
          sourceClubId: "88",
          sourceName: " Team Oslo ",
        },
      ],
    });
    expect(athleteDoc).toEqual({
      athleteId: "athlete:1001",
      source: {
        provider: "eqtiming",
        participantUid: 101,
        athleteUid: 1001,
      },
      displayName: "Ada Lovelace",
      normalizedName: "ada lovelace",
      gender: "F",
      birthYear: 1815,
      age: 17,
      country: null,
      region: null,
      primaryClubId: "club:42",
      clubIds: ["club:42"],
      primarySchoolId: "school:77",
      schoolIds: ["school:77"],
      primaryOrganizationId: null,
      organizationIds: [],
      primaryTeamId: "team:88",
      teamIds: ["team:88"],
      primaryLagId: null,
      lagIds: [],
    });
  });

  test("buildClubDoc falls back to normalized club name when source id is missing", () => {
    const mod = loadModule();
    const clubDoc = mod._test.buildClubDoc({
      Klubbnavn: "  Team Alpha  ",
    });

    expect(clubDoc).toEqual({
      clubId: "clubname:team alpha",
      name: "  Team Alpha  ",
      normalizedName: "team alpha",
      sourceRefs: [
        {
          provider: "eqtiming",
          sourceClubId: null,
          sourceName: "  Team Alpha  ",
        },
      ],
    });
  });

  test("getClassIdsWithContestants returns only populated class ids", () => {
    const mod = loadModule();
    const classIds = mod._test.getClassIdsWithContestants({
      "1": {Klasse: {UID: 200}},
      "2": {KlasseUID: 300},
      "3": {Klasse: {UID: 200}},
      "4": {},
    }).sort((a, b) => a - b);

    expect(classIds).toEqual([200, 300]);
  });

  test("getEtappeUidFromEvent prefers the etappe that has contestants", () => {
    const mod = loadModule();
    const fixtures = buildDuplicateClassAcrossDistancesFixtures();

    expect(mod._test.getEtappeUidFromEvent(
      fixtures.event,
      5001,
      fixtures.participants,
    )).toBe(7002);
  });

  test("buildClassOverview includes all classes with contestant counts", () => {
    const mod = loadModule();
    const fixtures = buildDuplicateClassAcrossDistancesFixtures();

    expect(mod._test.buildClassOverview(
      fixtures.event,
      fixtures.participants,
    )).toEqual([
      {
        etappeUid: 7001,
        etappeName: "Sprint Menn senior 20-21",
        classId: 5001,
        className: "Kvinner senior 20-21",
        contestantCount: 0,
      },
      {
        etappeUid: 7002,
        etappeName: "Sprint Kvinner senior 20-21",
        classId: 5001,
        className: "Kvinner senior 20-21",
        contestantCount: 1,
      },
    ]);
  });

  test("getImportableClassIds includes result classes from event even without contestants", () => {
    const mod = loadModule();
    const fixtures = buildResultsOnlySubclassFixtures();

    expect(mod._test.getImportableClassIds(
      fixtures.event,
      fixtures.participants,
    ).sort((a, b) => a - b)).toEqual([1146500, 1146503]);
  });

  test("buildDerivedResultMetrics calculates ski and range analysis fields", () => {
    const mod = loadModule();
    const derived = mod._test.buildDerivedResultMetrics({
      "1": {
        code: "INS1",
        cumMs: 100000,
        addition: null,
        diff: {class: 10},
        placement: {class: 1},
      },
      "2": {
        code: "UTS1",
        cumMs: 130000,
        addition: "1",
      },
      "3": {
        code: "INS2",
        cumMs: 250000,
        addition: null,
      },
      "4": {
        code: "UTS2",
        cumMs: 285000,
        addition: "1+1",
      },
      "5": {
        code: "Maal",
        cumMs: 400000,
        addition: "1+1",
      },
    }, 400000);

    expect(derived.analysis).toMatchObject({
      courseTimeMs: 400000,
      skiTimeMs: 335000,
      netSkiTimeMs: 335000,
      rangeTimeMs: 65000,
      shootingTimeMs: 65000,
      missesTotal: 2,
      hitsTotal: 8,
      targetsTotal: 10,
      proneTimeMs: 30000,
      standingTimeMs: 35000,
      shootingResult: "1+1",
      proneMisses: 1,
      standingMisses: 1,
      proneHits: 4,
      standingHits: 4,
      shootingCount: 2,
    });
    expect(derived.shooting).toMatchObject({
      shoot1: {
        position: "prone",
        inCumMs: 100000,
        outCumMs: 130000,
        rangeMs: 30000,
        misses: 1,
        hits: 4,
      },
      shoot2: {
        position: "standing",
        inCumMs: 250000,
        outCumMs: 285000,
        rangeMs: 35000,
        misses: 1,
        hits: 4,
      },
    });
    expect(derived.laps).toMatchObject({
      lap1: {
        skiMs: 100000,
        endCode: "INS1",
      },
      lap2: {
        skiMs: 120000,
        endCode: "INS2",
      },
      lap3: {
        skiMs: 115000,
        endCode: "Maal",
      },
    });
    expect(derived.rawPasses.some((pass) => pass.addition === "1+1")).toBe(true);
    expect(derived.rawPasses).toEqual(expect.arrayContaining([
      expect.objectContaining({
        code: "INS1",
        cumMs: 100000,
      }),
      expect.objectContaining({
        code: "UTS2",
        cumMs: 285000,
      }),
    ]));
    expect(derived.rawPasses.some((pass) =>
      pass.diff || pass.placement || pass.shooting || pass.stationUid)).toBe(false);
  });

  test("buildDerivedResultMetrics calculates and ranks penalty time", () => {
    const mod = loadModule();
    const withPenalty = mod._test.buildDerivedResultMetrics({
      "1": {code: "INS1", cumMs: 100000},
      "2": {code: "S1", cumMs: 130000, addition: "1"},
      "3": {code: "US1", cumMs: 200000, addition: "1"},
      "4": {
        code: "Maal",
        cumMs: 400000,
        cumMsWithoutAddition: 390000,
        addition: "1",
      },
    }, 400000);
    const withoutPenalty = mod._test.buildDerivedResultMetrics({
      "1": {code: "INS1", cumMs: 90000},
      "2": {code: "S1", cumMs: 120000, addition: "0"},
      "3": {code: "US1", cumMs: 160000, addition: "0"},
      "4": {code: "Maal", cumMs: 350000, addition: "0"},
    }, 350000);

    expect(withPenalty.analysis.netSkiTimeMs).toBe(370000);
    expect(withPenalty.analysis.skiTimeMs).toBe(290000);
    expect(withPenalty.analysis.penaltyTimeMs).toBe(80000);
    expect(withPenalty.shooting.shoot1.penaltyMs).toBe(70000);
    expect(withoutPenalty.analysis.netSkiTimeMs).toBe(320000);
    expect(withoutPenalty.analysis.skiTimeMs).toBe(320000);
    expect(withoutPenalty.analysis.penaltyTimeMs).toBe(0);

    const ranked = [withPenalty, withoutPenalty].map((derived) => ({
      analysis: derived.analysis,
    }));
    mod._test.addMetricRanks(ranked, "skiTimeMs", "skiRank");
    mod._test.addMetricRanks(ranked, "netSkiTimeMs", "netSkiRank");
    mod._test.addMetricRanks(ranked, "penaltyTimeMs", "penaltyRank");

    expect(withPenalty.analysis.skiRank).toBe(1);
    expect(withoutPenalty.analysis.skiRank).toBe(2);
    expect(withoutPenalty.analysis.netSkiRank).toBe(1);
    expect(withPenalty.analysis.netSkiRank).toBe(2);
    expect(withoutPenalty.analysis.penaltyRank).toBe(1);
    expect(withPenalty.analysis.penaltyRank).toBe(2);
  });
});

describe("eq importer core import", () => {
  test("importEqTimingFromUrls writes splitDefs and results", async () => {
    const mod = loadModule();
    const fixtures = buildImportFixtures();

    mockAxiosGet
      .mockResolvedValueOnce({data: fixtures.event})
      .mockResolvedValueOnce({data: fixtures.participants})
      .mockResolvedValueOnce({data: fixtures.stationOneTimes})
      .mockResolvedValueOnce({data: fixtures.stationTwoTimes});

    const result = await mod._import({
      eventId: 80088,
      classId: 1224375,
      eventUrl: "https://example.test/event",
      participantsUrl: "https://example.test/participants",
      timesUrlBase: "https://live.eqtiming.com/api/Result/Class/80088/330315/1224375",
    });

    expect(result.ok).toBe(true);
    expect(result.importedSplitDefs).toBe(2);
    expect(result.importedResults).toBe(1);
    expect(mockState.docs.get("clubs/club:90001")).toMatchObject({
      clubId: "club:90001",
      name: "Oslo Skiklubb",
      normalizedName: "oslo skiklubb",
      sourceRefs: [
        {
          provider: "eqtiming",
          sourceClubId: "90001",
          sourceName: "Oslo Skiklubb",
        },
      ],
      athletes: [
        {
          athleteId: "athlete:1001",
          name: "Ada Lovelace",
        },
      ],
    });
    expect(mockState.docs.get("clubs/school:3001")).toMatchObject({
      clubId: "school:3001",
      type: "school",
      name: "Oslo Katedralskole",
      normalizedName: "oslo katedralskole",
    });
    expect(mockState.docs.get("clubs/team:4001")).toMatchObject({
      clubId: "team:4001",
      type: "team",
      name: "Team Oslo",
      normalizedName: "team oslo",
      athletes: [
        {
          athleteId: "athlete:1001",
          name: "Ada Lovelace",
        },
      ],
    });
    expect(mockState.docs.get("athletes/athlete:1001")).toMatchObject({
      athleteId: "athlete:1001",
      displayName: "Ada Lovelace",
      normalizedName: "ada lovelace",
      primaryClubId: "club:90001",
      clubIds: ["club:90001"],
      primarySchoolId: "school:3001",
      schoolIds: ["school:3001"],
      primaryOrganizationId: null,
      organizationIds: [],
      primaryTeamId: "team:4001",
      teamIds: ["team:4001"],
      birthYear: 1815,
      events: [
        {
          eventId: 80088,
          name: "Test Event",
          classId: 1224375,
          className: "K17",
          rank: 1,
          proneHits: null,
          proneMisses: null,
          standingHits: null,
          standingMisses: null,
          skiRank: 1,
          netSkiRank: 1,
          shootRank: null,
        },
      ],
    });
    expect(mockState.docs.get("events/80088")).toMatchObject({
      eventId: 80088,
      name: "Test Event",
      sportName: "Skiskyting",
      sportCode: "BT",
      sportParentName: "Biathlon",
    });
    const classDoc = mockState.docs.get("events/80088/classes/1224375");
    expect(classDoc).toMatchObject({
      schemaVersion: 2,
      eventId: 80088,
      classId: 1224375,
      etappeUid: 330315,
      resultCount: 1,
      participantCount: 1,
      hasResults: true,
      timingSummary: expect.objectContaining({
        sources: expect.objectContaining({
          stationFetches: expect.any(Array),
        }),
      }),
    });
    expect(classDoc.results).toBeUndefined();
    expect(classDoc.splitDefs).toBeUndefined();
    expect(classDoc.splitOrder).toBeUndefined();
    expect(classDoc.splitCount).toBeUndefined();
    expect(classDoc.splitTimes).toBeUndefined();
    const classWrites = mockState.writes.filter((write) =>
      write.path === "events/80088/classes/1224375");
    expect(classWrites[classWrites.length - 1].options).toEqual({merge: true});

    const resultDoc = mockState.docs.get("events/80088/classes/1224375/results/101");
    expect(resultDoc).toMatchObject({
      participantUid: 101,
      athleteId: "athlete:1001",
      clubId: "club:90001",
      clubName: "Oslo Skiklubb",
      schoolId: "school:3001",
      schoolName: "Oslo Katedralskole",
      organizationId: null,
      organizationName: null,
      teamId: "team:4001",
      teamName: "Team Oslo",
      lagId: null,
      lagName: null,
      name: "Ada Lovelace",
      className: "K17",
      arrangementUid: 80088,
      athleteSourceUid: 1001,
      etappeDeltakerUid: 9001,
      rank: 1,
      totalMs: 120000,
      totalText: "2:00.0",
      registration: expect.objectContaining({
        status: null,
        registeredAt: null,
        confirmedTime: null,
        eqmeNotInUse: null,
        ignoreForTracking: null,
      }),
    });
    expect(resultDoc.analysis).toEqual(expect.any(Object));
    expect(resultDoc.athlete).toBeUndefined();
    expect(resultDoc.participant).toBeUndefined();
    expect(resultDoc.club).toBeUndefined();
    expect(resultDoc.classUid).toBeUndefined();
    expect(resultDoc.splits).toBeUndefined();
    expect(resultDoc.splitValues).toBeUndefined();
    expect(resultDoc.splitOrder).toBeUndefined();
    expect(resultDoc.rawPasses).toEqual(expect.arrayContaining([
      expect.objectContaining({
        code: "IS1",
        cumMs: 60000,
        cumRank: 1,
      }),
      expect.objectContaining({
        code: "Maal",
        cumMs: 120000,
        cumRank: 1,
      }),
    ]));
  });

  test("importEqTimingFromUrls writes legRank on each raw pass", async () => {
    const mod = loadModule();
    const fixtures = buildImportFixtures();

    fixtures.participants["202"] = {
      UID: 202,
      Startnummer: 8,
      Klasse: {
        UID: 1224375,
        Navn: "K17",
      },
      Arrangement: {
        UID: 80088,
      },
      Pulje: {
        EtappeUID: 330315,
      },
      Utover: {
        UID: 1002,
        Fornavn: "Grace",
        Etternavn: "Hopper",
      },
      Klubb: {
        UID: 90002,
        Navn: "Bergen Skiklubb",
      },
      EtappeDeltaker: {
        "9002": {},
      },
    };

    fixtures.stationOneTimes.Items.push({
      EtappeDeltakerUID: 9002,
      StasjonsOppsettUID: 1434583,
      AkkumulertTid: 50000,
      Formatert: "0:50.0",
      Splitt: {
        Tid: 50000,
        Formatert: "0:50.0",
      },
      StatusTekst: "TIME",
    });
    fixtures.stationTwoTimes.Items.push({
      EtappeDeltakerUID: 9002,
      StasjonsOppsettUID: 1434582,
      AkkumulertTid: 130000,
      Formatert: "2:10.0",
      Splitt: {
        Tid: 80000,
        Formatert: "1:20.0",
      },
      StatusTekst: "TIME",
    });

    mockAxiosGet
      .mockResolvedValueOnce({data: fixtures.event})
      .mockResolvedValueOnce({data: fixtures.participants})
      .mockResolvedValueOnce({data: fixtures.stationOneTimes})
      .mockResolvedValueOnce({data: fixtures.stationTwoTimes});

    const result = await mod._import({
      eventId: 80088,
      classId: 1224375,
      eventUrl: "https://example.test/event",
      participantsUrl: "https://example.test/participants",
      timesUrlBase: "https://live.eqtiming.com/api/Result/Class/80088/330315/1224375",
    });

    expect(result.ok).toBe(true);
    expect(result.importedResults).toBe(2);

    const adaResult = mockState.docs.get("events/80088/classes/1224375/results/101");
    const graceResult = mockState.docs.get("events/80088/classes/1224375/results/202");

    expect(adaResult.rawPasses).toEqual(expect.arrayContaining([
      expect.objectContaining({
        code: "IS1",
        cumMs: 60000,
        legMs: 60000,
        cumRank: 2,
        legRank: 2,
      }),
      expect.objectContaining({
        code: "Maal",
        cumMs: 120000,
        legMs: 60000,
        cumRank: 1,
        legRank: 1,
      }),
    ]));
    expect(graceResult.rawPasses).toEqual(expect.arrayContaining([
      expect.objectContaining({
        code: "IS1",
        cumMs: 50000,
        legMs: 50000,
        cumRank: 1,
        legRank: 1,
      }),
      expect.objectContaining({
        code: "Maal",
        cumMs: 130000,
        legMs: 80000,
        cumRank: 2,
        legRank: 2,
      }),
    ]));
  });

  test("importEqTimingFromUrls tolerates null station payloads from EQ Timing", async () => {
    const mod = loadModule();
    const fixtures = buildImportFixtures();

    mockAxiosGet
      .mockResolvedValueOnce({data: fixtures.event})
      .mockResolvedValueOnce({data: fixtures.participants})
      .mockResolvedValueOnce({data: null})
      .mockResolvedValueOnce({data: fixtures.stationTwoTimes});

    const result = await mod._import({
      eventId: 80088,
      classId: 1224375,
      eventUrl: "https://example.test/event",
      participantsUrl: "https://example.test/participants",
      timesUrlBase: "https://live.eqtiming.com/api/Result/Class/80088/330315/1224375",
    });

    expect(result.ok).toBe(true);
    expect(result.normalizedCount).toBe(1);
    expect(mockState.docs.get("events/80088/classes/1224375/results/101")).toMatchObject({
      participantUid: 101,
      totalMs: 120000,
      totalText: "2:00.0",
    });
  });

  test("importEqTimingFromUrls keeps participant metadata without writing participant docs", async () => {
    const mod = loadModule();
    const fixtures = buildImportFixtures();

    mockAxiosGet
      .mockResolvedValueOnce({data: fixtures.event})
      .mockResolvedValueOnce({data: fixtures.participants})
      .mockResolvedValueOnce({data: {Items: []}})
      .mockResolvedValueOnce({data: {Items: []}});

    const result = await mod._import({
      eventId: 80088,
      classId: 1224375,
      eventUrl: "https://example.test/event",
      participantsUrl: "https://example.test/participants",
      timesUrlBase: "https://live.eqtiming.com/api/Result/Class/80088/330315/1224375",
    });

    expect(result.ok).toBe(true);
    expect(result.importedSplitDefs).toBe(2);
    expect(result.importedParticipants).toBe(0);
    expect(result.importedResults).toBe(0);
    expect(result.seededParticipantResults).toBe(1);
    expect(result.normalizedCount).toBe(0);
    expect(mockState.docs.has("clubs/club:90001")).toBe(true);
    expect(mockState.docs.has("clubs/school:3001")).toBe(true);
    expect(mockState.docs.has("clubs/organization:4001")).toBe(false);
    expect(mockState.docs.has("clubs/team:4001")).toBe(true);
    expect(mockState.docs.has("athletes/athlete:1001")).toBe(true);
    expect(mockState.docs.has("events/80088/classes/1224375/results/101")).toBe(false);
    expect(mockState.docs.get("events/80088/classes/1224375")).toMatchObject({
      schemaVersion: 2,
      resultCount: 0,
      participantCount: 1,
      hasResults: false,
    });
    expect(mockState.docs.get("events/80088/classes/1224375").results).toBeUndefined();
    expect(mockState.docs.has("events/80088/classes/1224375/participants/101")).toBe(false);
  });

  test("importEqTimingFromUrls falls back to contestant passeringer with nested station UID", async () => {
    const mod = loadModule();
    const fixtures = buildImportFixtures();
    const participantsWithPasses = JSON.parse(JSON.stringify(fixtures.participants));
    participantsWithPasses["101"].EtappeDeltaker["9001"] = {
      UID: 9001,
      Etappe: {
        UID: 330315,
      },
      Passeringer: {
        "1": {
          StasjonsOppsettUID: 0,
          StasjonsOppsett: {
            UID: 1434583,
            Navn: "IS1",
          },
          AkkumulertTid: 60000,
          Formatert: "1:00.0",
          Splitt: {
            Tid: 60000,
            Formatert: "1:00.0",
          },
        },
        "2": {
          StasjonsOppsettUID: 0,
          StasjonsOppsett: {
            UID: 1434582,
            Navn: "Maal",
          },
          AkkumulertTid: 120000,
          Formatert: "2:00.0",
          Tillegg: "1+0",
          Splitt: {
            Tid: 60000,
            Formatert: "1:00.0",
          },
        },
      },
    };

    mockAxiosGet
      .mockResolvedValueOnce({data: fixtures.event})
      .mockResolvedValueOnce({data: fixtures.participants})
      .mockResolvedValueOnce({data: {Items: []}})
      .mockResolvedValueOnce({data: {Items: []}})
      .mockResolvedValueOnce({data: participantsWithPasses});

    const result = await mod._import({
      eventId: 80088,
      classId: 1224375,
      eventUrl: "https://example.test/event",
      participantsUrl: "https://example.test/participants",
      timesUrlBase: "https://live.eqtiming.com/api/Result/Class/80088/330315/1224375",
    });

    expect(result.ok).toBe(true);
    expect(result.importedResults).toBe(1);
    expect(result.normalizedCount).toBe(2);
    expect(result.timeSources.participantPassesFallback).toMatchObject({
      fetchedItems: 2,
      used: true,
      error: null,
    });
    expect(mockState.docs.get("events/80088/classes/1224375")).toMatchObject({
      resultCount: 1,
      timingSummary: expect.objectContaining({
        normalizedCount: 2,
        sources: expect.objectContaining({
          participantPassesFallback: expect.objectContaining({
            used: true,
          }),
        }),
      }),
    });
    expect(mockState.docs.get("events/80088/classes/1224375/results/101")).toMatchObject({
      participantUid: 101,
      totalMs: 120000,
      totalText: "2:00.0",
      rawPasses: expect.arrayContaining([
        expect.objectContaining({
          code: "Maal",
          cumMs: 120000,
          addition: "1+0",
          additionParts: [1, 0],
        }),
      ]),
    });
  });

  test("importEqTimingFromUrls removes stale empty result docs when time rows are missing", async () => {
    const mod = loadModule();
    const fixtures = buildImportFixtures();

    mockAxiosGet
      .mockResolvedValueOnce({data: fixtures.event})
      .mockResolvedValueOnce({data: fixtures.participants})
      .mockResolvedValueOnce({data: {Items: []}})
      .mockResolvedValueOnce({data: {Items: []}});

    await mod._import({
      eventId: 80088,
      classId: 1224375,
      eventUrl: "https://example.test/event",
      participantsUrl: "https://example.test/participants",
      timesUrlBase: "https://live.eqtiming.com/api/Result/Class/80088/330315/1224375",
    });

    mockState.docs.set("events/80088/classes/1224375/results/101", {
      participantUid: 101,
      totalMs: null,
      splits: {},
      rawPasses: [],
    });
    mockState.docs.set("events/80088/classes/1224375/results/legacy-valid", {
      participantUid: 999,
      totalMs: 90000,
      splits: {
        "1434582": {
          cumMs: 90000,
        },
      },
      rawPasses: [
        {
          cumMs: 90000,
        },
      ],
    });

    mockAxiosGet
      .mockResolvedValueOnce({data: fixtures.event})
      .mockResolvedValueOnce({data: fixtures.participants})
      .mockResolvedValueOnce({data: {Items: []}})
      .mockResolvedValueOnce({data: {Items: []}});

    const result = await mod._import({
      eventId: 80088,
      classId: 1224375,
      eventUrl: "https://example.test/event",
      participantsUrl: "https://example.test/participants",
      timesUrlBase: "https://live.eqtiming.com/api/Result/Class/80088/330315/1224375",
    });

    expect(result.staleResultCleanup).toMatchObject({
      deleted: 1,
      scanned: 2,
    });
    expect(mockState.docs.has("events/80088/classes/1224375/results/101")).toBe(false);
    expect(mockState.docs.has("events/80088/classes/1224375/results/legacy-valid")).toBe(true);
  });

  test("importEqTimingFromUrls keeps real result docs when a later import has no time rows", async () => {
    const mod = loadModule();
    const fixtures = buildImportFixtures();

    mockAxiosGet
      .mockResolvedValueOnce({data: fixtures.event})
      .mockResolvedValueOnce({data: fixtures.participants})
      .mockResolvedValueOnce({data: fixtures.stationOneTimes})
      .mockResolvedValueOnce({data: fixtures.stationTwoTimes});

    await mod._import({
      eventId: 80088,
      classId: 1224375,
      eventUrl: "https://example.test/event",
      participantsUrl: "https://example.test/participants",
      timesUrlBase: "https://live.eqtiming.com/api/Result/Class/80088/330315/1224375",
    });

    expect(mockState.docs.get("events/80088/classes/1224375/results/101")).toMatchObject({
      participantUid: 101,
      totalMs: 120000,
      rawPasses: expect.arrayContaining([expect.objectContaining({cumMs: 120000})]),
    });

    mockAxiosGet
      .mockResolvedValueOnce({data: fixtures.event})
      .mockResolvedValueOnce({data: fixtures.participants})
      .mockResolvedValueOnce({data: {Items: []}})
      .mockResolvedValueOnce({data: {Items: []}});

    const result = await mod._import({
      eventId: 80088,
      classId: 1224375,
      eventUrl: "https://example.test/event",
      participantsUrl: "https://example.test/participants",
      timesUrlBase: "https://live.eqtiming.com/api/Result/Class/80088/330315/1224375",
    });

    expect(result.importedResults).toBe(0);
    expect(result.staleResultCleanup).toMatchObject({
      deleted: 0,
      scanned: 1,
    });
    expect(mockState.docs.get("events/80088/classes/1224375")).toMatchObject({
      resultCount: 1,
      hasResults: true,
    });
    expect(mockState.docs.get("events/80088/classes/1224375").results).toBeUndefined();
    expect(mockState.docs.get("events/80088/classes/1224375/results/101")).toMatchObject({
      participantUid: 101,
      totalMs: 120000,
      rawPasses: expect.arrayContaining([expect.objectContaining({cumMs: 120000})]),
    });
  });

  test("importEqTimingFromUrls keeps timing rows when participant mapping is missing", async () => {
    const mod = loadModule();
    const fixtures = buildImportFixtures();
    const unmappedEdUid = 9901;
    const stationOneTimes = {
      Items: fixtures.stationOneTimes.Items.map((item) => Object.assign({}, item, {
        EtappeDeltakerUID: unmappedEdUid,
      })),
    };
    const stationTwoTimes = {
      Items: fixtures.stationTwoTimes.Items.map((item) => Object.assign({}, item, {
        EtappeDeltakerUID: unmappedEdUid,
      })),
    };

    mockAxiosGet
      .mockResolvedValueOnce({data: fixtures.event})
      .mockResolvedValueOnce({data: fixtures.participants})
      .mockResolvedValueOnce({data: stationOneTimes})
      .mockResolvedValueOnce({data: stationTwoTimes});

    const result = await mod._import({
      eventId: 80088,
      classId: 1224375,
      eventUrl: "https://example.test/event",
      participantsUrl: "https://example.test/participants",
      timesUrlBase: "https://live.eqtiming.com/api/Result/Class/80088/330315/1224375",
    });

    expect(result.ok).toBe(true);
    expect(result.importedParticipants).toBe(0);
    expect(result.importedResults).toBe(1);
    expect(mockState.docs.get("events/80088/classes/1224375")).toMatchObject({
      resultCount: 1,
      participantCount: 1,
    });
    expect(mockState.docs.get("events/80088/classes/1224375").results).toBeUndefined();
    expect(mockState.docs.has("events/80088/classes/1224375/participants/101")).toBe(false);
    const unmappedResultDoc = mockState.docs.get("events/80088/classes/1224375/results/9901");
    expect(unmappedResultDoc).toMatchObject({
      participantUid: null,
      etappeDeltakerUid: unmappedEdUid,
      hasTimingData: true,
      totalMs: 120000,
      rawPasses: expect.arrayContaining([
        expect.objectContaining({code: "IS1", cumMs: 60000}),
        expect.objectContaining({code: "Maal", cumMs: 120000}),
      ]),
    });
    expect(unmappedResultDoc.athlete).toBeUndefined();
    expect(unmappedResultDoc.participant).toBeUndefined();
    expect(unmappedResultDoc.splits).toBeUndefined();
    expect(unmappedResultDoc.splitValues).toBeUndefined();
    expect(unmappedResultDoc.splitOrder).toBeUndefined();
  });

  test("importWholeEvent writes results for classes on different distances", async () => {
    const mod = loadModule();
    const fixtures = buildMultiDistanceFixtures();

    mockAxiosGet
      .mockResolvedValueOnce({data: fixtures.event})
      .mockResolvedValueOnce({data: fixtures.participants})
      .mockResolvedValueOnce({data: fixtures.event})
      .mockResolvedValueOnce({data: fixtures.participants})
      .mockResolvedValueOnce({data: fixtures.shortStationOneTimes})
      .mockResolvedValueOnce({data: fixtures.shortStationTwoTimes})
      .mockResolvedValueOnce({data: fixtures.event})
      .mockResolvedValueOnce({data: fixtures.participants})
      .mockResolvedValueOnce({data: fixtures.longStationOneTimes})
      .mockResolvedValueOnce({data: fixtures.longStationTwoTimes});

    const result = await mod._importWholeEvent({
      eventId: 80088,
      classIndex: 0,
      classCount: 2,
    });

    expect(result.ok).toBe(true);
    expect(result.classesImported).toBe(2);
    expect(result.perClass).toEqual([
      expect.objectContaining({
        classId: 1224375,
        etappeUid: 330315,
        importedResults: 1,
      }),
      expect.objectContaining({
        classId: 1224376,
        etappeUid: 330419,
        importedResults: 1,
      }),
    ]);
    expect(mockState.docs.get("events/80088/classes/1224375/results/101")).toMatchObject({
      totalMs: 120000,
      athleteId: "athlete:1001",
      clubId: "club:90001",
      rawPasses: expect.arrayContaining([expect.objectContaining({code: "Kort-Maal"})]),
    });
    expect(mockState.docs.get("events/80088/classes/1224376/results/202")).toMatchObject({
      totalMs: 210000,
      athleteId: "athlete:2002",
      clubId: "clubname:bergen ski",
      schoolId: "schoolname:bergen handelsgym",
      organizationId: null,
      teamId: null,
      lagId: "lagname:vestland lag",
      rawPasses: expect.arrayContaining([expect.objectContaining({code: "Lang-Maal"})]),
    });
    expect(mockState.docs.get("clubs/club:90001")).toMatchObject({
      clubId: "club:90001",
    });
    expect(mockState.docs.get("clubs/clubname:bergen ski")).toMatchObject({
      clubId: "clubname:bergen ski",
      normalizedName: "bergen ski",
    });
    expect(mockState.docs.get("clubs/schoolname:bergen handelsgym")).toMatchObject({
      clubId: "schoolname:bergen handelsgym",
      type: "school",
      normalizedName: "bergen handelsgym",
    });
    expect(mockState.docs.get("clubs/lagname:vestland lag")).toMatchObject({
      clubId: "lagname:vestland lag",
      type: "lag",
      normalizedName: "vestland lag",
    });
    expect(mockState.docs.get("athletes/athlete:2002")).toMatchObject({
      athleteId: "athlete:2002",
      primaryClubId: "clubname:bergen ski",
      primarySchoolId: "schoolname:bergen handelsgym",
      primaryOrganizationId: null,
      primaryTeamId: null,
      primaryLagId: "lagname:vestland lag",
    });
  });

  test("importWholeEvent uses results from the distance that has contestants when class exists twice", async () => {
    const mod = loadModule();
    const fixtures = buildDuplicateClassAcrossDistancesFixtures();

    mockAxiosGet
      .mockResolvedValueOnce({data: fixtures.event})
      .mockResolvedValueOnce({data: fixtures.participants})
      .mockResolvedValueOnce({data: fixtures.event})
      .mockResolvedValueOnce({data: fixtures.participants})
      .mockResolvedValueOnce({data: fixtures.womenStationOneTimes})
      .mockResolvedValueOnce({data: fixtures.womenStationTwoTimes});

    const result = await mod._importWholeEvent({
      eventId: 80088,
      classIndex: 0,
      classCount: 1,
    });

    expect(result.ok).toBe(true);
    expect(result.classesImported).toBe(1);
    expect(result.perClass).toEqual([
      expect.objectContaining({
        classId: 5001,
        etappeUid: 7002,
        importedSplitDefs: 2,
        importedResults: 1,
      }),
    ]);
    expect(mockState.docs.get("events/80088/classes/5001")).toMatchObject({
      classId: 5001,
      etappeUID: 7002,
    });
    expect(mockState.docs.get("events/80088/classes/5001/results/501")).toMatchObject({
      participantUid: 501,
      totalMs: 140000,
      rawPasses: expect.arrayContaining([
        expect.objectContaining({code: "Kvinner-Maal", cumMs: 140000}),
      ]),
    });
    expect(mockState.docs.has("events/80088/classes/5001/splitDefs/8001")).toBe(false);
  });

  test("importWholeEvent imports result subclasses even when participants report zero contestants", async () => {
    const mod = loadModule();
    const fixtures = buildResultsOnlySubclassFixtures();

    mockAxiosGet
      .mockResolvedValueOnce({data: fixtures.event})
      .mockResolvedValueOnce({data: fixtures.participants})
      .mockResolvedValueOnce({data: fixtures.event})
      .mockResolvedValueOnce({data: fixtures.participants})
      .mockResolvedValueOnce({data: fixtures.seniorStationOneTimes})
      .mockResolvedValueOnce({data: fixtures.seniorStationTwoTimes})
      .mockResolvedValueOnce({data: fixtures.event})
      .mockResolvedValueOnce({data: fixtures.participants})
      .mockResolvedValueOnce({data: fixtures.u23StationOneTimes})
      .mockResolvedValueOnce({data: fixtures.u23StationTwoTimes});

    const result = await mod._importWholeEvent({
      eventId: 74689,
      classIndex: 0,
      classCount: 2,
    });

    expect(result.ok).toBe(true);
    expect(result.classesFound).toBe(2);
    expect(result.classesImported).toBe(2);
    expect(result.perClass).toEqual([
      expect.objectContaining({
        classId: 1146500,
        importedResults: 1,
      }),
      expect.objectContaining({
        classId: 1146503,
        importedResults: 1,
      }),
    ]);
    expect(mockState.docs.get("events/74689/classes/1146503")).toMatchObject({
      classId: 1146503,
      name: "Menn U23",
      etappeUID: 314477,
    });
    expect(mockState.docs.get("events/74689/classes/1146503/results/9801")).toMatchObject({
      participantUid: null,
      athleteId: null,
      clubId: null,
      clubName: null,
      schoolId: null,
      schoolName: null,
      organizationId: null,
      organizationName: null,
      teamId: null,
      teamName: null,
      lagId: null,
      lagName: null,
      name: null,
      etappeDeltakerUid: 9801,
      totalMs: 660000,
      rawPasses: expect.arrayContaining([
        expect.objectContaining({code: "Maal", cumMs: 660000}),
      ]),
    });
  });

  test("importEqTimingFromUrls does not create club doc when participant has no club", async () => {
    const mod = loadModule();
    const fixtures = buildImportFixtures();
    delete fixtures.participants["101"].Klubb;

    mockAxiosGet
      .mockResolvedValueOnce({data: fixtures.event})
      .mockResolvedValueOnce({data: fixtures.participants})
      .mockResolvedValueOnce({data: fixtures.stationOneTimes})
      .mockResolvedValueOnce({data: fixtures.stationTwoTimes});

    await mod._import({
      eventId: 80088,
      classId: 1224375,
      eventUrl: "https://example.test/event",
      participantsUrl: "https://example.test/participants",
      timesUrlBase: "https://live.eqtiming.com/api/Result/Class/80088/330315/1224375",
    });

    expect(mockState.docs.has("clubs/club:90001")).toBe(false);
    expect(mockState.docs.get("athletes/athlete:1001")).toMatchObject({
      athleteId: "athlete:1001",
      primaryClubId: null,
      clubIds: [],
      primarySchoolId: "school:3001",
      schoolIds: ["school:3001"],
      primaryOrganizationId: null,
      organizationIds: [],
      primaryTeamId: "team:4001",
      teamIds: ["team:4001"],
      primaryLagId: null,
      lagIds: [],
    });
    expect(mockState.docs.get("events/80088/classes/1224375/results/101")).toMatchObject({
      athleteId: "athlete:1001",
      clubId: null,
      clubName: null,
      schoolId: "school:3001",
      schoolName: "Oslo Katedralskole",
      organizationId: null,
      organizationName: null,
      teamId: "team:4001",
      teamName: "Team Oslo",
      lagId: null,
      lagName: null,
    });
  });
});

describe("eq importer http handlers", () => {
  test("importFromEqTimingUrls rejects non-POST requests", async () => {
    const mod = loadModule();
    const req = {method: "GET"};
    const res = makeResponse();

    await mod.importFromEqTimingUrls(req, res);

    expect(res.status).toHaveBeenCalledWith(405);
    expect(res.send).toHaveBeenCalledWith("Use POST");
  });

  test("startImportEvent validates eventId", async () => {
    const mod = loadModule();
    const req = {
      method: "POST",
      body: {},
    };
    const res = makeResponse();

    await mod.startImportEvent(req, res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({error: "Missing/invalid eventId"});
  });

  test("getImportStatus returns 404 for unknown jobs", async () => {
    const mod = loadModule();
    const req = {
      query: {
        jobId: "missing-job",
      },
    };
    const res = makeResponse();

    await mod.getImportStatus(req, res);

    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith({error: "Job not found"});
  });

  test("runImportEventChunk clears stale lastError after a successful retry", async () => {
    const mod = loadModule();
    const fixtures = buildImportFixtures();

    mockAxiosGet
      .mockResolvedValueOnce({data: fixtures.event})
      .mockResolvedValueOnce({data: fixtures.participants});

    const startReq = {
      method: "POST",
      body: {
        eventId: 80088,
        classCount: 1,
      },
    };
    const startRes = makeResponse();

    await mod.startImportEvent(startReq, startRes);

    const jobId = startRes.json.mock.calls[0][0].jobId;
    mockState.docs.set("importJobs/" + jobId, Object.assign(
      {},
      mockState.docs.get("importJobs/" + jobId),
      {lastError: "Old EQ Timing error"},
    ));

    mockAxiosGet
      .mockResolvedValueOnce({data: fixtures.event})
      .mockResolvedValueOnce({data: fixtures.participants})
      .mockResolvedValueOnce({data: fixtures.stationOneTimes})
      .mockResolvedValueOnce({data: fixtures.stationTwoTimes});

    const chunkReq = {
      method: "POST",
      body: {
        jobId,
        eventId: 80088,
        classIndex: 0,
        classCount: 1,
      },
    };
    const chunkRes = makeResponse();

    await mod.runImportEventChunk(chunkReq, chunkRes);

    expect(chunkRes.json).toHaveBeenCalledWith(expect.objectContaining({
      ok: true,
      jobId,
    }));
    expect(mockState.docs.get("importJobs/" + jobId)).toMatchObject({
      status: "done",
      done: true,
      nextClassIndex: 1,
    });
    expect(mockState.docs.get("importJobs/" + jobId).lastError).toBeUndefined();
  });

  test("startImportEvent enqueues a job and returns queued response", async () => {
    const mod = loadModule();
    const fixtures = buildDuplicateClassAcrossDistancesFixtures();
    mockAxiosGet
      .mockResolvedValueOnce({data: fixtures.event})
      .mockResolvedValueOnce({data: fixtures.participants});
    const req = {
      method: "POST",
      body: {
        eventId: 80088,
        classCount: 1,
      },
    };
    const res = makeResponse();

    await mod.startImportEvent(req, res);

    expect(mockCreateTask).toHaveBeenCalledTimes(1);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      ok: true,
      eventId: 80088,
      status: "queued",
      jobId: expect.any(String),
    }));
    const jobId = res.json.mock.calls[0][0].jobId;
    expect(mockState.docs.get("importJobs/" + jobId)).toMatchObject({
      eventId: 80088,
      classOverview: [
        expect.objectContaining({
          etappeUid: 7001,
          classId: 5001,
          contestantCount: 0,
        }),
        expect.objectContaining({
          etappeUid: 7002,
          classId: 5001,
          contestantCount: 1,
        }),
      ],
    });
  });
});
