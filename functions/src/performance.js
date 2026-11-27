"use strict";
const {performance} = require("node:perf_hooks");
class Metrics {
  constructor() { this.start = performance.now(); this.values = {}; }
  async measure(name, operation) {
    const start = performance.now();
    try { return await operation(); }
    finally { this.values[name] = (this.values[name] || 0) + performance.now() - start; }
  }
  sync(name, operation) {
    const start = performance.now();
    try { return operation(); }
    finally { this.values[name] = (this.values[name] || 0) + performance.now() - start; }
  }
  snapshot() {
    return {...Object.fromEntries(Object.entries(this.values).map(([k, v]) => [k, Math.round(v * 100) / 100])),
      totalMs: Math.round((performance.now() - this.start) * 100) / 100};
  }
}
async function boundedMap(items, limit, operation) {
  const output = new Array(items.length);
  let next = 0;
  await Promise.all(Array.from({length: Math.min(limit, items.length)}, async () => {
    while (next < items.length) { const index = next++; output[index] = await operation(items[index]); }
  }));
  return output;
}
function instrumentTransaction(transaction, metrics) {
  return new Proxy(transaction, {get(target, name) {
    if (["get", "getAll"].includes(name)) return async (...args) => {
      metrics.values.readRpcCalls = (metrics.values.readRpcCalls || 0) + 1;
      const result = await target[name](...args);
      const count = Array.isArray(result) ? result.length : result.docs ? Math.max(1, result.size) : 1;
      metrics.values.documentReads = (metrics.values.documentReads || 0) + count;
      return result;
    };
    return typeof target[name] === "function" ? target[name].bind(target) : target[name];
  }});
}
module.exports = {Metrics, boundedMap, instrumentTransaction};
