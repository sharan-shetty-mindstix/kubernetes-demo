const client = require("prom-client");

// Collect default Node.js metrics (event loop, memory, GC)
client.collectDefaultMetrics();

const httpRequestDuration = new client.Histogram({
  name: "http_request_duration_seconds",
  help: "Duration of HTTP requests",
  labelNames: ["method", "route", "status"],
  buckets: [0.05, 0.1, 0.2, 0.5, 1, 2],
});

module.exports = { client, httpRequestDuration };
