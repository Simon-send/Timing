"use strict";

jest.mock("firebase-admin/app", () => {
  const apps = [];
  return {
    getApps: () => apps,
    initializeApp: jest.fn(() => {
      if (apps.length) throw new Error("duplicate app");
      const app = {name: "[DEFAULT]"};
      apps.push(app);
      return app;
    }),
  };
});
jest.mock("firebase-admin/auth", () => ({getAuth: jest.fn(() => ({}))}));
jest.mock("firebase-admin/firestore", () => ({getFirestore: jest.fn(() => ({}))}));
jest.mock("firebase-functions/v2/https", () => ({
  onCall: (_, handler) => handler,
  HttpsError: Error,
}));
jest.mock("firebase-functions/params", () => ({
  defineSecret: () => ({value: () => "test-only"}),
}));
jest.mock("../access_service", () => ({
  AccessError: class extends Error {},
  RundeanalyseAccessService: class {
    getAccessStatus() {
      return {allowed: true};
    }

    consumeAnalysis() {
      return {allowed: true, access: {source: "code", codeId: "code-1"}};
    }

    createGuestSession() {
      return Promise.resolve();
    }
  },
}));
test("successive invocations reuse the default Admin app", async () => {
  const {getRundeanalyseAccessStatus} = require("../index");
  await expect(getRundeanalyseAccessStatus({})).resolves.toEqual({allowed: true});
  await expect(getRundeanalyseAccessStatus({})).resolves.toEqual({allowed: true});
  expect(require("firebase-admin/app").initializeApp).toHaveBeenCalledTimes(1);
});

test("uses Firebase Hosting's reserved __session cookie for guest codes", async () => {
  const {consumeRundeanalyseAnalysis} = require("../index");
  const append = jest.fn();

  await consumeRundeanalyseAnalysis({
    data: {code: "LØYPE-123", idempotencyKey: "guest-code-cookie-test"},
    rawRequest: {headers: {}, res: {append}},
  });

  expect(append).toHaveBeenCalledWith(
    "Set-Cookie",
    expect.stringMatching(/^__session=[^;]+; Path=\/api\/consume; HttpOnly; Secure; SameSite=Strict;/),
  );
});
