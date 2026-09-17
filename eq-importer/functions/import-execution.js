"use strict";

/* eslint-disable require-jsdoc */
const {AsyncLocalStorage} = require("node:async_hooks");
const {ownsLease} = require("./import-job-state");
const execution = new AsyncLocalStorage();

function assertExecutionBudget() {
  const context = execution.getStore();
  if (context && context.deadlineMs && Date.now() >= context.deadlineMs) {
    const error = new Error("IMPORT_SLICE_YIELD");
    error.code = "IMPORT_SLICE_YIELD";
    throw error;
  }
}

async function assertWriteLease(transaction) {
  const context = execution.getStore();
  if (!context) return;
  const snapshot = await transaction.get(context.jobRef);
  if (!snapshot.exists ||
      !ownsLease(snapshot.data(), context.owner, context.runId) ||
      snapshot.data().leaseExpiresAtMs <= Date.now()) {
    const error = new Error("IMPORT_LEASE_LOST");
    error.code = "IMPORT_LEASE_LOST";
    throw error;
  }
}

module.exports = {execution, assertWriteLease, assertExecutionBudget};
