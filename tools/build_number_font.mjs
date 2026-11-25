// Arma la fuente de los números: de una fuente TrueType deja a la vista SOLO los dígitos 0-9, con la altura y las
// métricas de línea de Pixelify Sans. El tema la usa primero y Pixelify como respaldo: así todos los números salen
// de esta fuente y todas las letras de Pixelify, sin elegir fuente etiqueta por etiqueta.
//
//   node tools/build_number_font.mjs <fuente.ttf> <salida.ttf>
//
// Solo cambia las tablas cmap, head, hhea y OS/2 (los dibujos y los pesos variables quedan como estaban). La
// licencia OFL permite modificar; la versión modificada sigue bajo OFL (ver CREDITS.md). Sin dependencias.
import { readFile, writeFile } from "node:fs/promises";

const DIGITS = [..."0123456789"].map((c) => c.codePointAt(0));
// El dígito que se mide para igualar alturas (el 0 puede cambiar de dibujo con la opción "zero").
const MEASURED = "5".codePointAt(0);

function parse(buffer) {
  const count = buffer.readUInt16BE(4);
  const tables = new Map();
  for (let i = 0; i < count; i++) {
    const at = 12 + i * 16;
    const tag = buffer.toString("latin1", at, at + 4);
    const offset = buffer.readUInt32BE(at + 8);
    tables.set(tag, Buffer.from(buffer.subarray(offset, offset + buffer.readUInt32BE(at + 12))));
  }
  for (const tag of ["cmap", "head", "hhea", "OS/2", "glyf", "loca"]) {
    if (!tables.has(tag)) throw new Error(`la fuente no tiene la tabla ${tag} (tiene que ser TrueType)`);
  }
  return { version: buffer.readUInt32BE(0), tables };
}

// Código -> glifo, de la tabla cmap (formatos 4 y 12).
function glyphOf(cmap, code) {
  const count = cmap.readUInt16BE(2);
  for (let i = 0; i < count; i++) {
    const at = cmap.readUInt32BE(8 + i * 8);
    const format = cmap.readUInt16BE(at);
    if (format === 12) {
      const groups = cmap.readUInt32BE(at + 12);
      for (let g = 0; g < groups; g++) {
        const group = at + 16 + g * 12;
        const start = cmap.readUInt32BE(group);
        if (code >= start && code <= cmap.readUInt32BE(group + 4)) return cmap.readUInt32BE(group + 8) + code - start;
      }
    } else if (format === 4) {
      const segments = cmap.readUInt16BE(at + 6) / 2;
      for (let s = 0; s < segments; s++) {
        const end = cmap.readUInt16BE(at + 14 + s * 2);
        const start = cmap.readUInt16BE(at + 16 + segments * 2 + s * 2);
        if (code < start || code > end) continue;
        const delta = cmap.readInt16BE(at + 16 + segments * 4 + s * 2);
        const rangeAt = at + 16 + segments * 6 + s * 2;
        const range = cmap.readUInt16BE(rangeAt);
        if (range === 0) return (code + delta) & 0xffff;
        const glyph = cmap.readUInt16BE(rangeAt + range + (code - start) * 2);
        return glyph === 0 ? 0 : (glyph + delta) & 0xffff;
      }
    }
  }
  return 0;
}

// Alto del dibujo de un carácter, en unidades de la fuente.
function heightOf(font, code) {
  const { cmap, head, loca, glyf } = Object.fromEntries(font.tables);
  const glyph = glyphOf(cmap, code);
  const long = head.readInt16BE(50) === 1;
  const offset = long ? loca.readUInt32BE(glyph * 4) : loca.readUInt16BE(glyph * 2) * 2;
  return glyf.readInt16BE(offset + 8) - glyf.readInt16BE(offset + 4);
}

// Una cmap con un único tramo (0-9) en formato 4, más el tramo final que exige el formato.
function digitCmap(glyphs) {
  const sub = Buffer.alloc(52);
  [4, sub.length, 0, 4, 4, 1, 0].forEach((v, i) => sub.writeUInt16BE(v, i * 2));
  [0x39, 0xffff].forEach((v, i) => sub.writeUInt16BE(v, 14 + i * 2)); // fin de cada tramo
  [0x30, 0xffff].forEach((v, i) => sub.writeUInt16BE(v, 20 + i * 2)); // comienzo
  [0, 1].forEach((v, i) => sub.writeUInt16BE(v, 24 + i * 2)); // delta
  [4, 0].forEach((v, i) => sub.writeUInt16BE(v, 28 + i * 2)); // el primer tramo lee de la lista de glifos
  glyphs.forEach((glyph, i) => sub.writeUInt16BE(glyph, 32 + i * 2));
  const header = Buffer.alloc(12);
  [0, 1, 3, 1].forEach((v, i) => header.writeUInt16BE(v, i * 2));
  header.writeUInt32BE(12, 8);
  return Buffer.concat([header, sub]);
}

function checksum(data) {
  const padded = Buffer.alloc(Math.ceil(data.length / 4) * 4);
  data.copy(padded);
  let sum = 0;
  for (let i = 0; i < padded.length; i += 4) sum = (sum + padded.readUInt32BE(i)) >>> 0;
  return sum;
}

function serialize({ version, tables }) {
  tables.delete("DSIG"); // la firma deja de valer
  tables.get("head").writeUInt32BE(0, 8);
  const tags = [...tables.keys()].sort();
  const header = Buffer.alloc(12 + tags.length * 16);
  const power = Math.floor(Math.log2(tags.length));
  header.writeUInt32BE(version, 0);
  [tags.length, 2 ** power * 16, power, tags.length * 16 - 2 ** power * 16].forEach((v, i) => header.writeUInt16BE(v, 4 + i * 2));
  let offset = header.length;
  const bodies = [];
  let headOffset = 0;
  tags.forEach((tag, i) => {
    const data = tables.get(tag);
    const at = 12 + i * 16;
    header.write(tag, at, "latin1");
    header.writeUInt32BE(checksum(data), at + 4);
    header.writeUInt32BE(offset, at + 8);
    header.writeUInt32BE(data.length, at + 12);
    if (tag === "head") headOffset = offset;
    const padded = Buffer.alloc(Math.ceil(data.length / 4) * 4);
    data.copy(padded);
    bodies.push(padded);
    offset += padded.length;
  });
  const file = Buffer.concat([header, ...bodies]);
  file.writeUInt32BE((0xb1b0afba - checksum(file)) >>> 0, headOffset + 8);
  return file;
}

const [source, output] = process.argv.slice(2);
if (!source || !output) {
  console.error("Uso: node tools/build_number_font.mjs <fuente.ttf> <salida.ttf>");
  process.exit(1);
}
const pixelify = parse(await readFile(new URL("../assets/fonts/PixelifySans.ttf", import.meta.url)));
const font = parse(await readFile(source));
const glyphs = DIGITS.map((code) => glyphOf(font.tables.get("cmap"), code));
if (glyphs.includes(0)) throw new Error("a la fuente le falta algún dígito");

const reference = pixelify.tables.get("head").readUInt16BE(18);
const head = font.tables.get("head");
const share = (f) => heightOf(f, MEASURED) / f.tables.get("head").readUInt16BE(18);
// Menos unidades por cuadratín = dibujos más grandes: se elige para que el 5 mida lo mismo que el de Pixelify.
const unitsPerEm = Math.round((head.readUInt16BE(18) * share(font)) / share(pixelify));

// Las métricas de línea de Pixelify, en las unidades nuevas: así las líneas miden lo mismo que antes.
const scaled = (value) => Math.round((value * unitsPerEm) / reference);
for (const [tag, offsets] of [["hhea", [4, 6, 8]], ["OS/2", [68, 70, 72, 74, 76]]]) {
  const from = pixelify.tables.get(tag);
  const to = font.tables.get(tag);
  for (const at of offsets) to.writeInt16BE(scaled(from.readInt16BE(at)), at);
}
head.writeUInt16BE(unitsPerEm, 18);
font.tables.set("cmap", digitCmap(glyphs));
await writeFile(output, serialize(font));
console.log(`${output}: dígitos ${glyphs.join(",")}, unitsPerEm ${unitsPerEm}`);
