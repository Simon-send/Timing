"use strict";

const {
  EXPECTED_PROJECT_ID,
  grantAdministrator,
  parseArgs,
} = require("../scripts/grant-rundeanalyse-admin");

describe("grant-rundeanalyse-admin", () => {
  test("requires an explicit target project, confirmation and matching email", () => {
    expect(() => parseArgs([])).toThrow("--yes");
    expect(() => parseArgs([
      "--yes",
      "--project", EXPECTED_PROJECT_ID,
      "--email", "one@example.com",
      "--confirm-email", "other@example.com",
    ])).toThrow("same email");
    expect(() => parseArgs([
      "--yes",
      "--project", "another-project",
      "--email", "admin@example.com",
      "--confirm-email", "admin@example.com",
    ])).toThrow(EXPECTED_PROJECT_ID);
  });

  test("merges the custom claim and records a narrow audit document", async () => {
    const setCustomUserClaims = jest.fn(async () => undefined);
    const set = jest.fn(async () => undefined);
    const initializeApp = jest.fn();
    const auth = {
      getUserByEmail: jest.fn(async () => ({
        uid: "admin-uid",
        email: "admin@example.com",
        customClaims: {anotherProductClaim: true},
      })),
      setCustomUserClaims,
    };
    const adminSdk = {
      getApps: () => [],
      initializeApp,
      getAuth: () => auth,
      getFirestore: () => ({
        collection: () => ({
          doc: () => ({set}),
        }),
      }),
    };

    const result = await grantAdministrator({
      adminSdk,
      email: "admin@example.com",
      projectId: EXPECTED_PROJECT_ID,
    });

    expect(initializeApp).toHaveBeenCalledWith({projectId: EXPECTED_PROJECT_ID});
    expect(setCustomUserClaims).toHaveBeenCalledWith("admin-uid", {
      anotherProductClaim: true,
      rundeanalyseAdmin: true,
    });
    expect(set).toHaveBeenCalledWith(expect.objectContaining({
      email: "admin@example.com",
      source: "one-off-admin-bootstrap",
    }), {merge: true});
    expect(result).toEqual({uid: "admin-uid", email: "admin@example.com"});
  });
});
