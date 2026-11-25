// Comprueba contra tu proyecto de Supabase que la tabla de métricas deja insertar y NO deja leer,
// modificar ni borrar. Usa la URL y la key de data/online.json. Sin dependencias.
//
//   node tools/check_supabase.mjs
//
// Deja una fila con app_version = 'prueba' (las consultas de retención la ignoran).
import { readFile } from "node:fs/promises";
import { randomUUID } from "node:crypto";

const configUrl = new URL("../data/online.json", import.meta.url);
let config;
try {
  config = JSON.parse(await readFile(configUrl, "utf8"));
} catch (error) {
  console.error(`No pude leer data/online.json (${error.message}). Copiá data/online.example.json y completalo.`);
  process.exit(1);
}
const base = String(config.supabase_url ?? "").trim().replace(/\/+$/, "");
const key = String(config.supabase_key ?? "").trim();
if (!base || !key) {
  console.error("Falta supabase_url o supabase_key en data/online.json.");
  process.exit(1);
}
if (key.startsWith("sb_secret_")) {
  console.error("Esa es la key SECRETA. Poné la publishable (sb_publishable_...) y rotá la secreta si la compartiste.");
  process.exit(1);
}

const headers = { apikey: key, "Content-Type": "application/json", Prefer: "return=minimal" };
if (key.startsWith("eyJ")) headers.Authorization = `Bearer ${key}`;
const table = `${base}/rest/v1/session_events`;
let failed = 0;

async function check(label, url, options, wanted) {
  const response = await fetch(url, { headers, ...options });
  const ok = wanted.includes(response.status);
  if (!ok) failed++;
  const detail = ok ? "" : ` → ${(await response.text()).slice(0, 200)}`;
  console.log(`${ok ? "ok   " : "MAL  "} ${label} (HTTP ${response.status})${detail}`);
}

const row = { device_id: randomUUID(), app_version: "prueba", max_biome: 0, relics: 0 };
await check("insertar está permitido", table, { method: "POST", body: JSON.stringify(row) }, [201]);
// Sin permiso, PostgREST responde 401 (o 403). Un 200, aunque venga vacío, sería permiso de lectura.
await check("leer está prohibido", `${table}?select=*&limit=1`, { method: "GET" }, [401, 403]);
await check("modificar está prohibido", `${table}?app_version=eq.prueba`, { method: "PATCH", body: JSON.stringify({ relics: 1 }) }, [401, 403]);
await check("borrar está prohibido", `${table}?app_version=eq.prueba`, { method: "DELETE" }, [401, 403]);
await check("poner la fecha desde el cliente está prohibido", table,
  { method: "POST", body: JSON.stringify({ ...row, created_at: "2000-01-01T00:00:00Z" }) }, [401, 403]);

console.log(failed === 0 ? "La tabla está bien configurada." : `${failed} comprobación(es) fallaron: revisá docs/supabase/session_events.sql.`);
// exitCode y no process.exit(): cortar con conexiones abiertas hace caer a Node en Windows.
process.exitCode = failed === 0 ? 0 : 1;
