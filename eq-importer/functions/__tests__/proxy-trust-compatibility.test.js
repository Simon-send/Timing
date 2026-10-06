"use strict";

const {createRequire} = require("node:module");
// Exercise the dependency actually resolved by each deployed Express tree.
const proxyaddr = createRequire(require.resolve("express"))("proxy-addr");
const outsider = "198.51.100.23";

test("short mapped IPv6 trust prefix rejects an unrelated IPv4 peer", () => {
  expect(proxyaddr.compile("::ffff:10.0.0.0/8")(outsider)).toBe(false);
});

test("native IPv6 trust prefix does not trust an IPv4 peer", () => {
  expect(proxyaddr.compile("::/1")(outsider)).toBe(false);
});

test("untrusted peer cannot replace its address with a forwarded header", () => {
  const request = {
    socket: {remoteAddress: outsider},
    headers: {"x-forwarded-for": "10.0.0.2"},
  };
  const trust = proxyaddr.compile("::ffff:10.0.0.0/8");
  expect(proxyaddr(request, trust)).toBe(outsider);
});

test("plain IPv4 subnet continues to trust only its own network", () => {
  const trust = proxyaddr.compile("10.0.0.0/8");
  expect(trust("10.1.2.3")).toBe(true);
  expect(trust(outsider)).toBe(false);
});

test("full mapped IPv6 prefix continues to match the intended IPv4 network", () => {
  const trust = proxyaddr.compile("::ffff:10.0.0.0/104");
  expect(trust("10.1.2.3")).toBe(true);
  expect(trust(outsider)).toBe(false);
});

test("native IPv6 subnet continues to trust only its own network", () => {
  const trust = proxyaddr.compile("2001:db8::/32");
  expect(trust("2001:db8::1")).toBe(true);
  expect(trust("2001:db9::1")).toBe(false);
});
