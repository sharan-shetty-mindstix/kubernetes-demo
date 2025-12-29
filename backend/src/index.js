const express = require("express");
const cors = require("cors");
const routes = require("./routes");

const app = express();

app.use(cors({
  origin: "*" // dev-safe for now
}));

app.use(express.json());

let server;
let isShuttingDown = false;

console.log("App environment:", process.env.APP_ENV);
console.log("Log level:", process.env.LOG_LEVEL);
console.log("Async worker enabled:", process.env.FEATURE_ASYNC_WORKER);

let requestCount = 0;

// Minimal metrics endpoint

app.use((req, res, next) => {
  requestCount++;
  next();
});

app.get("/metrics", (req, res) => {
  res.set("Content-Type", "text/plain");
  res.send(`backend_requests_total ${requestCount}\n`);
});

app.use("/api", routes);

// Liveness probe
app.get("/healthz", (req, res) => {
  res.status(200).json({ status: "ok" });
});

// Readiness probe
app.get("/readyz", (req, res) => {
  if (isShuttingDown) {
    res.status(500).json({ status: "shutting down" });
  } 
  res.status(200).json({ status: "ready" });
});

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log(`Backend running on port ${PORT}`);
});

// Graceful shutdown
process.on("SIGTERM", () => {
  console.log("SIGTERM received. Draining connections...");
  isShuttingDown = true;

  const timeout = parseInt(process.env.GRACEFUL_SHUTDOWN_TIMEOUT || "10", 10) * 1000;

  server.close(() => {
    console.log("All connections closed. Exiting.");
    process.exit(0);
  });

  setTimeout(() => {
    console.error("Graceful shutdown timeout exceeded. Forcing exit.");
    process.exit(1);
  }, timeout);
});