const express = require("express");
const router = express.Router();

const tasks = {};

router.post("/submit", (req, res) => {
  const id = Date.now().toString();
  tasks[id] = { status: "pending" };

  console.log(`Task created: ${id}`);
  
  res.status(202).json({ taskId: id });
});

router.get("/status/:id", (req, res) => {
  const task = tasks[req.params.id];
  if (!task) return res.status(404).json({ error: "Not found" });

  console.log(`Task status: ${task.status}`);

  res.json(task);
});

router.get("/cpu", (req, res) => {
  const end = Date.now() + 500; // burn CPU for 500ms
  while (Date.now() < end) {}
  res.json({ status: "cpu work done" });
});

module.exports = router;
