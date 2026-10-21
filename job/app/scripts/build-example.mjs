// Example scheduled job: fetch a public dataset, write a snapshot and a status file.
// Stands in for the private production job, with the same shape: fetch, build, write, upload.
import { mkdir, writeFile } from "node:fs/promises";

const started = Date.now();
const response = await fetch("https://www.gov.uk/bank-holidays.json");
if (!response.ok) throw new Error(`Source returned ${response.status}`);
const data = await response.json();

const events = data["england-and-wales"]?.events ?? [];
const snapshot = { generated_at: new Date().toISOString(), source: "gov.uk/bank-holidays", count: events.length, events };
const status = { ok: true, generated_at: snapshot.generated_at, count: events.length, duration_ms: Date.now() - started };

await mkdir("output", { recursive: true });
await writeFile("output/latest.json", JSON.stringify(snapshot));
await writeFile("output/status.json", JSON.stringify(status, null, 2));
console.log(`Wrote ${events.length} events`);
