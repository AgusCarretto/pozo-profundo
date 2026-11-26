// Calibra la tabla de la meta ("return.points") de un árbol: corre campañas a 3 golpes/s, mira en cada tramo de la
// tabla cuánto tardó en poder volverse y mueve los metros hacia el objetivo. SOLO PARA SIMULAR.
//
//   node tools/tree_sim/calibrate.mjs <arbol.json> <salida.json> [variante] [vueltas]
//
// La salida es una copia del árbol con la tabla nueva (la variante calibrada queda en "variants"). Godot: variable de
// entorno GODOT o el de Descargas, como tools/run_tests.ps1.
import fs from 'node:fs';
import path from 'node:path';
import { execFile } from 'node:child_process';

const [input, output, variant = '', iterations = '8'] = process.argv.slice(2);
const godot = process.env.GODOT || path.join(process.env.USERPROFILE, 'Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe');
const KNOTS = [3, 6, 9, 12, 20, 40, 65, 100, 180, 300, 500, 700, 1000, 1400];
const SEEDS = [1, 2, 3];
const GOAL_BEFORE = 12.0; // minutos (mediana) hasta completar el anillo 2: deja casi todo por encima de 10
const GOAL_AFTER = 9.0; // después las bajadas pueden acortarse
const GAIN = 3.5; // metros por minuto de error
const MAX_STEP = 10;
const EXTRA = 30;

const tree = JSON.parse(fs.readFileSync(input, 'utf8'));
const rule = variant ? tree.variants[variant].return : tree.return;

function at(points, x) {
  if (x <= points[0][0]) return points[0][1];
  let i = 1;
  while (i < points.length - 1 && x > points[i][0]) i++;
  const [x0, y0] = points[i - 1], [x1, y1] = points[i];
  return y0 + (x - x0) * (y1 - y0) / (x1 - x0);
}
let meters = KNOTS.map(k => Math.round(at(rule.points, k)));

const median = list => [...list].sort((a, b) => a - b)[Math.floor(list.length / 2)];
const quantile = (list, q) => [...list].sort((a, b) => a - b)[Math.floor(list.length * q)];

function run(seed) {
  const args = ['--headless', '--path', '.', '--script', 'res://tools/simulate_tree.gd', '--', 'campaign', path.resolve(output).replace(/\\/g, '/'), '3', String(seed)];
  if (variant) args.push(variant);
  return new Promise((resolve, reject) => execFile(godot, args, { maxBuffer: 1 << 26 }, (error, stdout, stderr) => {
    if (error || /SCRIPT ERROR|Parse Error/.test(stdout + stderr)) reject(new Error(stderr + stdout));
    else resolve(stdout);
  }));
}

function write() {
  rule.points = [[0, 0], ...KNOTS.map((k, i) => [k, meters[i]])];
  rule.extra_every = EXTRA;
  fs.writeFileSync(output, JSON.stringify(tree, null, '\t'));
}

for (let iteration = 1; iteration <= Number(iterations); iteration++) {
  write();
  const outputs = await Promise.all(SEEDS.map(run));
  const descents = [];
  const days = [];
  for (const text of outputs) {
    for (const line of text.split(/\r?\n/)) {
      if (line.startsWith('baja,')) {
        const [claimed, ready, ring2, away] = line.split(',').slice(1).map(Number);
        if (claimed > 0 && !away) descents.push({ claimed, minutes: ready / 60, ring2 });
      }
    }
    days.push((text.match(/^ {2}completo: día (\d+)/m) || [, 'no'])[1]);
  }
  let previous = 0;
  const report = [];
  meters = KNOTS.map((knot, i) => {
    const low = i === 0 ? 0 : (KNOTS[i - 1] + knot) / 2;
    const high = i === KNOTS.length - 1 ? Infinity : (knot + KNOTS[i + 1]) / 2;
    const bucket = descents.filter(d => d.claimed >= low && d.claimed < high);
    let delta = previous;
    if (bucket.length >= 3) {
      const goal = bucket.filter(d => d.ring2).length * 2 >= bucket.length ? GOAL_AFTER : GOAL_BEFORE;
      const now = median(bucket.map(d => d.minutes));
      delta = Math.max(-MAX_STEP, Math.min(MAX_STEP, GAIN * (goal - now)));
      report.push(`${knot}:${now.toFixed(1)}`);
    }
    previous = delta;
    return Math.max(0, Math.round(meters[i] + delta));
  });
  for (let i = 1; i < meters.length; i++) meters[i] = Math.max(meters[i], meters[i - 1]);
  const before = descents.filter(d => !d.ring2).map(d => d.minutes);
  const after = descents.filter(d => d.ring2).map(d => d.minutes);
  console.log(`vuelta ${iteration}: antes del anillo 2 mín ${Math.min(...before).toFixed(1)} · 5% ${quantile(before, 0.05).toFixed(1)} · mediana ${median(before).toFixed(1)} | después mediana ${after.length ? median(after).toFixed(1) : '—'} | completo día ${days.join('/')}`);
  console.log('  mediana por tramo: ' + report.join(' '));
}
write();
console.log('puntos: ' + JSON.stringify(rule.points));
