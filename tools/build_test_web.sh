#!/usr/bin/env bash
# Arma la build de prueba que se publica en /test/: de debug (trae el menú DBG), sin instalación como app, con noindex,
# con otro nombre de juego (así su partida no pisa la publicada) y sin data/online.json (no manda métricas).
# Los archivos se llaman "prueba.*" y no "index.*": el service worker de la versión publicada también alcanza /test/ y
# guardaría los "index.*" para siempre.
#
# CAMBIA project.godot: correr solo sobre una copia descartable (el flujo de GitHub o un git worktree).
#   bash tools/build_test_web.sh <godot> <carpeta de salida>
set -euo pipefail
godot="$1"
out="$2"

sed -i 's/^config\/name="Pozo Profundo"\r\?$/config\/name="Pozo Profundo Prueba"/' project.godot
grep -q '^config/name="Pozo Profundo Prueba"' project.godot
rm -f data/online.json

mkdir -p "$out"
"$godot" --headless --path . --import
"$godot" --headless --path . --export-debug "Prueba" "$out/prueba.html"
test -f "$out/prueba.pck"

# Lo que usa la pantalla de carga (igual que la versión publicada) y la página de entrada de /test/.
cp assets/fonts/PixelifySans.ttf assets/fonts/OFL.txt assets/fonts/VT323Digits.ttf assets/fonts/VT323-OFL.txt "$out/"
cp assets/sprites/generated/rock_earth.png "$out/loading_rock.png"
cp web/test_index.html "$out/index.html"

grep -q 'noindex' "$out/prueba.html"
grep -q 'noindex' "$out/index.html"
test ! -f "$out/prueba.service.worker.js"
echo "Build de prueba lista en $out"
