// Arma data/online.json a partir de variables de entorno (lo usa el flujo de GitHub Pages con los secretos del
// repo). Sin dependencias. Falla en vez de publicar un juego sin métricas o con una key secreta adentro.
//
//   SUPABASE_URL=... SUPABASE_KEY=... [FEEDBACK_URL=...] node tools/write_online_config.mjs
import { writeFile } from "node:fs/promises";

const url = (process.env.SUPABASE_URL ?? "").trim();
const key = (process.env.SUPABASE_KEY ?? "").trim();
const feedback = (process.env.FEEDBACK_URL ?? "").trim();

function fail(message) {
  console.error(message);
  process.exit(1);
}

if (!url || !key) {
  fail("Faltan los secretos SUPABASE_URL y SUPABASE_KEY (Settings » Secrets and variables » Actions).");
}
if (!url.startsWith("https://")) {
  fail("SUPABASE_URL tiene que empezar con https://");
}
let role = "";
try {
  role = JSON.parse(Buffer.from(key.split(".")[1] ?? "", "base64url").toString()).role ?? "";
} catch {
  // No es un JWT: es una key nueva.
}
// La key viaja dentro del juego publicado: solo puede ser una pública.
if (key.startsWith("sb_secret_") || role === "service_role") {
  fail("SUPABASE_KEY es la key SECRETA. Usá la publishable (sb_publishable_...) y rotá la secreta.");
}

const config = { supabase_url: url, supabase_key: key, feedback_url: feedback };
await writeFile(new URL("../data/online.json", import.meta.url), JSON.stringify(config, null, "\t") + "\n");
console.log(`data/online.json listo (${feedback ? "con" : "sin"} link de Opinar).`);
