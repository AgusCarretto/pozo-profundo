# Créditos

Registro de **cada** asset de terceros usado en Pozo Profundo. Se anota acá (con licencia y link) **antes** de usarlo. Preferir CC0.

Cada fila dice dónde vive el asset con una ruta entre comillas invertidas; `tests/assets_test.gd` exige que todo archivo de `assets/` esté bajo una de esas rutas.

| Asset | Autor | Licencia | Link | Usado en |
|-------|-------|----------|------|----------|
| Tiny Dungeon 1.0 (personajes y cofre) | Kenney | CC0 1.0 | https://kenney.nl/assets/tiny-dungeon | `assets/sprites/tiny_dungeon/` (solo las 7 tiles usadas, sin tocar): mineros, cofre. Los mineros además se recolorean en `assets/sprites/generated/miner_*.png` |
| UI Pack 2.0 (botones rectangulares) | Kenney | CC0 1.0 | https://kenney.nl/assets/ui-pack | `assets/ui/ui_pack/` (solo los botones usados): tema de la interfaz (`ui/theme.tres`) |
| Pixelify Sans (fuente) | The Pixelify Sans Project Authors | SIL Open Font License 1.1 | https://github.com/eifetx/Pixelify-Sans · https://fonts.google.com/specimen/Pixelify+Sans | `assets/fonts/PixelifySans.ttf` (licencia en `assets/fonts/OFL.txt`): las letras de toda la interfaz |
| VT323 (fuente de los números) | The VT323 Project Authors (Peter Hull) | SIL Open Font License 1.1 | https://fonts.google.com/specimen/VT323 · https://github.com/google/fonts/tree/main/ofl/vt323 | `assets/fonts/VT323Digits.ttf` (licencia en `assets/fonts/VT323-OFL.txt`): los números de toda la interfaz y de la pantalla de carga. Modificada con `tools/build_number_font.mjs`: solo quedan a la vista los dígitos 0-9, con la altura y las métricas de línea igualadas a las de Pixelify (la versión modificada sigue bajo OFL) |
| Impact Sounds 1.0 (golpes de pico, metal y campana) | Kenney | CC0 1.0 | https://kenney.nl/assets/impact-sounds | `assets/audio/impact_sounds/` (solo los usados): golpe a la roca, mejora del pico, cofre legendario, dinamita |
| Interface Sounds 1.0 (clicks, cristales y avisos) | Kenney | CC0 1.0 | https://kenney.nl/assets/interface-sounds | `assets/audio/interface_sounds/` (solo los usados): pestañas, modos, carteles, cofres, prestigio y bioma nuevo |
| RPG Audio (monedas) | Kenney | CC0 1.0 | https://kenney.nl/assets/rpg-audio | `assets/audio/rpg_audio/` (solo los usados): compra de la cuadrilla |
| Game Icons (íconos blancos 2x) | Kenney | CC0 1.0 | https://kenney.nl/assets/game-icons | `assets/ui/game_icons/` (solo los usados): silencio (parlante encendido y tachado) y opciones (engranaje) del HUD |
| Town Theme RPG (música de Tierra) | cynicmusic — crédito pedido por el autor: [The Cynic Project / pixelsphere.org](https://pixelsphere.org) | CC0 1.0 | https://opengameart.org/content/town-theme-rpg | `assets/music/town_theme.ogg`: tema de Tierra. Convertido a OGG; loop de 76 s que vuelve a los 14,15 s (lo anterior es la intro), sin la cola final |
| Crystal Cave (song18, música de Cristal) | cynicmusic — crédito pedido por el autor: [The Cynic Project / pixelsphere.org](https://pixelsphere.org) | CC0 1.0 | https://opengameart.org/content/crystal-cave-song18 | `assets/music/crystal_cave.ogg`: tema de Cristal. Convertido a OGG y recortado antes del fundido a silencio del final, para que el loop no tenga hueco |
| Retro Game Music Pack (Level 1, Level 2, Ending, Title Screen) | Juhani Junkala (SubspaceAudio) | CC0 1.0 | https://opengameart.org/content/5-chiptunes-action | `assets/music/level_1.ogg` (Roca), `assets/music/level_2.ogg` (Magma y Abismo), `assets/music/ending.ogg` (vuelta a la superficie), `assets/music/title_screen.ogg` (Opciones). Convertidos a OGG sin cambios (vienen listos para loopear) |
| Fast fight / battle music (frenesí) | Ville Nousiainen (Xythe / mutkanto) — crédito pedido por el autor: [soundcloud.com/mutkanto](https://soundcloud.com/mutkanto) | CC0 1.0 | https://opengameart.org/content/fast-fight-battle-music | `assets/music/fast_fight.ogg`: capa de frenesí (cuando golpeás rápido). Convertido a OGG; la subida del primer compás suena una vez y el loop vuelve después (16 compases, hasta los 68 tiempos que marca el archivo) |
| Particle Pack 1.1 (brillos) | Kenney | CC0 1.0 | https://kenney.nl/assets/particle-pack | `assets/particles/particle_pack/` (solo los brillos usados, sin tocar): destello de la dinamita, aura de las runas, brillo y estrellas de los cofres. Las astillas y gemas son propias (pixel art) |


## Motor

- [Godot Engine](https://godotengine.org) — licencia MIT.

## Assets propios

- `icon.svg` — ícono del proyecto, creado para Pozo Profundo.
- `assets/sprites/generated/` — sprites de 16×16 dibujados por código con la paleta de Tiny Dungeon (`game/palette.gd`) por `tools/generate_sprites.gd`: roca, fondo, astillas y runas que orbitan de cada bioma, taladro, gólem, dinamita, runas, moneda, pico y gema. Los mineros de ese mismo directorio son personajes de Tiny Dungeon recoloreados por el mismo script.
