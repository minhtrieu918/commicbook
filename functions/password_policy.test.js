"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {passwordErrors} = require("./password_policy");

test("chấp nhận mật khẩu mạnh", () => {
  assert.deepEqual(passwordErrors("Admin@123"), []);
});

test("từ chối mật khẩu yếu hoặc không phải chuỗi", () => {
  assert.ok(passwordErrors("password").length > 0);
  assert.ok(passwordErrors(null).length > 0);
});
