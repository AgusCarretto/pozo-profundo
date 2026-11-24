# Créditos

Registro de **cada** asset de terceros usado en Pozo Profundo. Se anota acá (con licencia y link) **antes** de usarlo. Preferir CC0.

Cada fila dice dónde vive el asset con una ruta entre comillas invertidas; `tests/assets_test.gd` exige que todo archivo de `assets/` esté bajo una de esas rutas.

| Asset | Autor | Licencia | Link | Usado en |
|-------|-------|----------|------|----------|
| Tiny Dungeon 1.0 (personajes y cofre) | Kenney | CC0 1.0 | https://kenney.nl/assets/tiny-dungeon | `assets/sprites/tiny_dungeon/` (solo las 7 tiles usadas, sin tocar): mineros, cofre. Los mineros además se recolorean en `assets/sprites/generated/miner_*.png` |
| UI Pack 2.0 (botones rectangulares) | Kenney | CC0 1.0 | https://kenney.nl/assets/ui-pack | `assets/ui/ui_pack/` (solo los botones usados): tema de la interfaz (`ui/theme.tres`) |
| Pixelify Sans (fuente) | The Pixelify Sans Project Authors | SIL Open Font License 1.1 | https://github.com/eifetx/Pixelify-Sans · https://fonts.google.com/specimen/Pixelify+Sans | `assets/fonts/PixelifySans.ttf` (licencia en `assets/fonts/OFL.txt`): toda la interfaz |
| Impact Sounds 1.0 (golpes de pico, metal y campana) | Kenney | CC0 1.0 | https://kenney.nl/assets/impact-sounds | `assets/audio/impact_sounds/` (solo los usados): golpe a la roca, mejora del pico, cofre legendario |
| Interface Sounds 1.0 (clicks, cristales y avisos) | Kenney | CC0 1.0 | https://kenney.nl/assets/interface-sounds | `assets/audio/interface_sounds/` (solo los usados): pestañas, modos, carteles, cofres, prestigio y bioma nuevo |
| RPG Audio (monedas) | Kenney | CC0 1.0 | https://kenney.nl/assets/rpg-audio | `assets/audio/rpg_audio/` (solo los usados): compra de la cuadrilla |
| Game Icons (íconos blancos 2x) | Kenney | CC0 1.0 | https://kenney.nl/assets/game-icons | `assets/ui/game_icons/` (solo los usados): silencio (parlante encendido y tachado) y opciones (engranaje) del HUD |

Ya descargados en `assets_src/` pero **todavía sin usar** (se registra acá cuando se importe): Kenney Particle Pack (CC0).

## Motor

- [Godot Engine](https://godotengine.org) — licencia MIT.

## Assets propios

- `icon.svg` — ícono del proyecto, creado para Pozo Profundo.
- `assets/sprites/generated/` — sprites de 16×16 dibujados por código con la paleta de Tiny Dungeon (`game/palette.gd`) por `tools/generate_sprites.gd`: roca y fondo de cada bioma, taladro, gólem, dinamita, runas, moneda, pico y gema. Los mineros de ese mismo directorio son personajes de Tiny Dungeon recoloreados por el mismo script.
