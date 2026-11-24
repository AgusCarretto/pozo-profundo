# Créditos

Registro de **cada** asset de terceros usado en Pozo Profundo. Se anota acá (con licencia y link) **antes** de usarlo. Preferir CC0.

Cada fila dice dónde vive el asset con una ruta entre comillas invertidas; `tests/assets_test.gd` exige que todo archivo de `assets/` esté bajo una de esas rutas.

| Asset | Autor | Licencia | Link | Usado en |
|-------|-------|----------|------|----------|
| Tiny Dungeon 1.0 (personajes y cofre) | Kenney | CC0 1.0 | https://kenney.nl/assets/tiny-dungeon | `assets/sprites/tiny_dungeon/` (solo las 7 tiles usadas, sin tocar): mineros, cofre. Los mineros además se recolorean en `assets/sprites/generated/miner_*.png` |
| UI Pack 2.0 (botones rectangulares) | Kenney | CC0 1.0 | https://kenney.nl/assets/ui-pack | `assets/ui/ui_pack/` (solo los botones usados): tema de la interfaz (`ui/theme.tres`) |
| Pixelify Sans (fuente) | The Pixelify Sans Project Authors | SIL Open Font License 1.1 | https://github.com/eifetx/Pixelify-Sans · https://fonts.google.com/specimen/Pixelify+Sans | `assets/fonts/PixelifySans.ttf` (licencia en `assets/fonts/OFL.txt`): toda la interfaz |

Ya descargados en `assets_src/` pero **todavía sin usar** (se registran acá cuando se importen): Kenney Game Icons, Particle Pack, Interface Sounds, Impact Sounds y RPG Audio (todos CC0).

## Motor

- [Godot Engine](https://godotengine.org) — licencia MIT.

## Assets propios

- `icon.svg` — ícono del proyecto, creado para Pozo Profundo.
- `assets/sprites/generated/` — sprites de 16×16 dibujados por código con la paleta de Tiny Dungeon (`game/palette.gd`) por `tools/generate_sprites.gd`: roca y fondo de cada bioma, taladro, gólem, dinamita, runas, moneda, pico y gema. Los mineros de ese mismo directorio son personajes de Tiny Dungeon recoloreados por el mismo script.
