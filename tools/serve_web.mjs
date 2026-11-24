// Servidor estático mínimo para probar el export web en local (sin dependencias).
//
//   node tools/serve_web.mjs [puerto]        (por defecto 8060)
//
// Sirve build/web/ solo en 127.0.0.1. El export no usa threads, así que no hacen
// falta los headers COOP/COEP; así se parece más a lo que verá itch.io.
import { createServer } from "node:http";
import { readFile, stat } from "node:fs/promises";
import { extname, join, normalize, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(fileURLToPath(new URL("../build/web/", import.meta.url)));
const port = Number(process.argv[2] ?? 8060);

const mime = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".wasm": "application/wasm",
  ".pck": "application/octet-stream",
  ".png": "image/png",
  ".svg": "image/svg+xml",
  ".json": "application/json",
};

const server = createServer(async (req, res) => {
  try {
    const urlPath = decodeURIComponent(new URL(req.url, "http://localhost").pathname);
    const file = normalize(join(root, urlPath === "/" ? "index.html" : urlPath));
    if (file !== root && !file.startsWith(root + sep)) {
      res.writeHead(403).end("403");
      return;
    }
    const info = await stat(file);
    if (!info.isFile()) throw new Error("no es un archivo");
    const body = await readFile(file);
    res.writeHead(200, {
      "Content-Type": mime[extname(file)] ?? "application/octet-stream",
      "Content-Length": body.length,
      "Cache-Control": "no-store",
    });
    res.end(body);
  } catch {
    res.writeHead(404).end("404");
  }
});

server.listen(port, "127.0.0.1", () => {
  console.log(`Sirviendo ${root}`);
  console.log(`Abrí http://127.0.0.1:${port}/  (Ctrl+C para frenar)`);
});
