const API_BASE_URL = "/api";

async function submitTask() {
  const res = await fetch(`${API_BASE_URL}/submit`, { method: "POST" });
  const data = await res.json();
  document.getElementById("output").innerText = JSON.stringify(data, null, 2);
}
