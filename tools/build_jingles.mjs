// Sintetiza los jingles propios del juego (no son de terceros) en WAV mono de 16 bits.
//   node tools/build_jingles.mjs          # escribe en assets/audio/own/
//   godot --headless --path . --import
// Es determinista: correrlo de nuevo reescribe los mismos archivos.
import fs from 'node:fs';
import path from 'node:path';

const RATE = 22050;
const OUT = path.join('assets', 'audio', 'own');

// Azar con semilla, para que las chispas salgan siempre igual.
let seed = 7;
const random = () => ((seed = (seed * 48271) % 2147483647) / 2147483647);

const triangle = phase => 4 * Math.abs((phase % 1) - 0.5) - 1;
const square = phase => ((phase % 1) < 0.25 ? 1 : -1);
const sine = phase => Math.sin(2 * Math.PI * phase);

/** Suma una nota: ataque corto y caída exponencial. */
function note(buffer, { at, freq, seconds, volume, wave, decay = 4 }) {
  const start = Math.floor(at * RATE);
  const count = Math.floor(seconds * RATE);
  for (let i = 0; i < count && start + i < buffer.length; i++) {
    const t = i / RATE;
    const envelope = Math.min(1, t / 0.008) * Math.exp(-decay * t) * Math.min(1, (seconds - t) / 0.03);
    buffer[start + i] += wave(freq * t) * envelope * volume;
  }
}

function echo(buffer, seconds, gain) {
  const delay = Math.floor(seconds * RATE);
  for (let i = delay; i < buffer.length; i++) buffer[i] += buffer[i - delay] * gain;
}

function save(name, buffer) {
  const peak = buffer.reduce((m, v) => Math.max(m, Math.abs(v)), 0);
  const data = Buffer.alloc(44 + buffer.length * 2);
  data.write('RIFF', 0);
  data.writeUInt32LE(36 + buffer.length * 2, 4);
  data.write('WAVEfmt ', 8);
  data.writeUInt32LE(16, 16);
  data.writeUInt16LE(1, 20);
  data.writeUInt16LE(1, 22);
  data.writeUInt32LE(RATE, 24);
  data.writeUInt32LE(RATE * 2, 28);
  data.writeUInt16LE(2, 32);
  data.writeUInt16LE(16, 34);
  data.write('data', 36);
  data.writeUInt32LE(buffer.length * 2, 40);
  buffer.forEach((v, i) => data.writeInt16LE(Math.round((v / peak) * 0.7 * 32767), 44 + i * 2));
  fs.writeFileSync(path.join(OUT, name), data);
  console.log(name, (buffer.length / RATE).toFixed(2), 's');
}

fs.mkdirSync(OUT, { recursive: true });

// Logro: arpegio de do mayor que sube, acorde brillante sostenido y chispas arriba.
{
  const buffer = new Float64Array(Math.floor(RATE * 1.6));
  [523.25, 659.25, 783.99, 1046.5].forEach((freq, i) => {
    note(buffer, { at: i * 0.085, freq, seconds: 0.22, volume: 0.22, wave: square, decay: 7 });
    note(buffer, { at: i * 0.085, freq, seconds: 0.25, volume: 0.35, wave: triangle, decay: 5 });
  });
  for (const freq of [1046.5, 1318.5, 1568.0]) {
    note(buffer, { at: 0.34, freq, seconds: 1.1, volume: 0.2, wave: triangle, decay: 2.6 });
    note(buffer, { at: 0.34, freq: freq * 1.004, seconds: 1.1, volume: 0.06, wave: square, decay: 3.5 });
  }
  note(buffer, { at: 0.34, freq: 261.63, seconds: 0.9, volume: 0.3, wave: triangle, decay: 3 });
  const sparkles = [2093.0, 2637.0, 3136.0, 4186.0];
  for (let i = 0; i < 16; i++) {
    note(buffer, { at: 0.36 + i * 0.055, freq: sparkles[Math.floor(random() * sparkles.length)], seconds: 0.12, volume: 0.09 * (1 - i / 20), wave: sine, decay: 22 });
  }
  echo(buffer, 0.12, 0.28);
  save('achievement.wav', buffer);
}

// Anillo nuevo: campanas lentas que suben (sol mayor con séptima), como algo que se despeja.
{
  const buffer = new Float64Array(Math.floor(RATE * 1.8));
  [392.0, 493.88, 587.33, 739.99, 987.77].forEach((freq, i) => {
    note(buffer, { at: i * 0.16, freq, seconds: 1.0, volume: 0.28, wave: sine, decay: 2.8 });
    note(buffer, { at: i * 0.16, freq: freq * 2.01, seconds: 0.6, volume: 0.08, wave: sine, decay: 6 });
  });
  echo(buffer, 0.19, 0.35);
  save('ring_open.wav', buffer);
}
