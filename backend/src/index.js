const express = require("express");
const cors = require("cors");
const routes = require("./routes");
const { Pool } = require("pg");

const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
});

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

app.get("/api/db-health", async (req, res) => {
  try {
    const result = await pool.query("SELECT 1 AS ok");
    res.json({ status: "ok", db: result.rows[0].ok });
  } catch (error) {
    console.error("Database health check error:", error.message);
    console.error("Error details:", error);
    res.status(500).json({ status: "error", message: error.message });
  }
});

app.use("/api", routes);

// Liveness probe
app.get("/healthz", (req, res) => {
  res.status(200).json({ status: "ok" });
});

// Readiness probe
app.get("/readyz", (req, res) => {
  if (isShuttingDown) {
    return res.status(500).json({ status: "shutting down" });
  } 
  res.status(200).json({ status: "ready" });
});

const PORT = process.env.PORT || 3000;

server = app.listen(PORT, () => {
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