"use strict";

const {Gaxios} = require("gaxios");

test("scoped uuid update retains Gaxios CommonJS multipart boundaries", async () => {
  const http = new Gaxios();
  const response = await http.request({
    url: "https://local-fixture.invalid/upload",
    method: "POST",
    multipart: [{headers: {"Content-Type": "text/plain"}, content: "fixture"}],
    adapter: async (options) => {
      const contentType = options.headers["Content-Type"];
      const boundary = contentType.split("boundary=")[1];
      expect(boundary).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
      let body = "";
      for await (const chunk of options.body) body += chunk.toString();
      expect(body).toContain(`--${boundary}\r\nContent-Type: text/plain`);
      expect(body).toContain("fixture");
      expect(body.endsWith(`--${boundary}--`)).toBe(true);
      return {config: options, status: 200, statusText: "OK", headers: {}, data: body};
    },
  });
  expect(response.status).toBe(200);
});
