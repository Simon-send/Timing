"use strict";

const {normalizeParticipants, timingPage} = require("../import-source");

describe("EQ source validation", () => {
  test.each([
    [{UID: 31}],
    {Items: [{UID: 31}]},
    {items: {31: {UID: 31}}},
    {31: {UID: 31}},
  ])("normalizes participant envelopes to the same lookup", (payload) => {
    expect(normalizeParticipants(payload)["31"]).toEqual({UID: 31});
  });

  test("does not invent IDs or silently overwrite participants", () => {
    expect(() => normalizeParticipants([{}])).toThrow("INVALID_PARTICIPANT_ID");
    expect(() => normalizeParticipants([{UID: 1}, {UID: 1}]))
        .toThrow("DUPLICATE_PARTICIPANT_ID");
  });

  test("does not accept a truncated participant list as complete", () => {
    expect(() => normalizeParticipants({Items: [{UID: 1}], TotalCount: 2}))
        .toThrow("INCOMPLETE_PARTICIPANTS_RESPONSE");
  });

  test.each([null, "<html>Error</html>", {}, {Items: null}])(
      "rejects invalid timing responses", (payload) => {
        expect(() => timingPage(payload)).toThrow("INVALID_TIMING_RESPONSE");
      });

  test("distinguishes an explicitly empty result list from a failure", () => {
    expect(timingPage({Items: [], TotalCount: 0}))
        .toEqual({items: [], total: 0});
    expect(timingPage({Items: [{EtappeDeltakerUID: 1}], TotalItems: 14}).total)
        .toBe(14);
  });
});
