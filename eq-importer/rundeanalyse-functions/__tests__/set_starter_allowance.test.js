"use strict";
const {configDigest, parseArgs, updateStarterConfig} = require("../scripts/set-starter-allowance");
function fixture(data = {freeAnalysisLimit: 5, offerEnabled: false}) {
  let current = data;
  const writes = [];
  const snapshot = () => ({exists: current !== undefined, data: () => current});
  const db = {
    collection: (name) => ({doc: (id) => ({path: `${name}/${id || "audit-id"}`, get: async () => snapshot()})}),
    runTransaction: async (fn) => fn({get: async () => snapshot(), set: (ref, value, options) => writes.push({path: ref.path, value, options})}),
  };
  return {db, writes, snapshot, replace: (value) => current = value};
}
describe("reviewed starter allowance configuration", () => {
  test("requires explicit project and reviewed digest for apply", () => {
    expect(() => parseArgs([])).toThrow("--project");
    expect(parseArgs(["--project", "time-plotting"]).apply).toBe(false);
    expect(() => parseArgs(["--project", "time-plotting", "--apply"])).toThrow("--expected-sha");
    expect(() => parseArgs(["--project", "other"])).toThrow("--project");
  });
  test("preview is read-only and apply updates only global config plus audit", async () => {
    const f = fixture();
    const preview = await updateStarterConfig(f.db, {apply: false});
    expect(f.writes).toEqual([]);
    expect(preview).toMatchObject({currentLimit: 5, proposedLimit: 15, applied: false});
    const result = await updateStarterConfig(f.db, {"apply": true, "expected-sha": preview.expectedSha, "reason": "Approved starter rollout"}, () => 123);
    expect(result.applied).toBe(true);
    expect(f.writes).toHaveLength(2);
    expect(f.writes[0]).toEqual({path: "rundeanalyseConfig/default", value: {freeAnalysisLimit: 15, updatedAtMs: 123}, options: {merge: true}});
    expect(f.writes.every((w) => !w.path.startsWith("rundeanalyseUsers/"))).toBe(true);
  });
  test("stale preview rejects before writes; already configured is a no-op", async () => {
    const f = fixture();
    const hash = configDigest(f.snapshot());
    f.replace({freeAnalysisLimit: 8});
    await expect(updateStarterConfig(f.db, {"apply": true, "expected-sha": hash, "reason": "Approved"})).rejects.toThrow("changed");
    expect(f.writes).toEqual([]);
    f.replace({freeAnalysisLimit: 15});
    expect(await updateStarterConfig(f.db, {"apply": true, "expected-sha": configDigest(f.snapshot()), "reason": "Approved"})).toMatchObject({unchanged: true, applied: false});
    expect(f.writes).toEqual([]);
  });
});
