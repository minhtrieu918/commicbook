"use strict";

const passwordErrors = (password) => {
  const value = typeof password === "string" ? password : "";
  const errors = [];
  if (value.length < 8) errors.push("ít nhất 8 ký tự");
  if (!/[A-Z]/.test(value)) errors.push("1 chữ hoa");
  if (!/[a-z]/.test(value)) errors.push("1 chữ thường");
  if (!/[0-9]/.test(value)) errors.push("1 chữ số");
  if (!/[^A-Za-z0-9\s]/.test(value)) errors.push("1 ký tự đặc biệt");
  return errors;
};

module.exports = {passwordErrors};
