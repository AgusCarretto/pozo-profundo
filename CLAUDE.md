# Pozo Profundo — guía del proyecto

Juego incremental (idle/clicker) de minería para celular. Primer juego del catálogo: el objetivo es recorrer el circuito completo (web → Play Store → backend → monetización) y dejar una base reutilizable para los próximos juegos.

## Visión
- Picás una roca, contratás una cuadrilla que mina sola, bajás por biomas (Tierra, Roca, Cristal, Magma, Abismo) y volvés a la superficie con reliquias (prestigio).
- Prioridad: que sea divertido y "jugoso" (feedback visual y sonoro en cada acción). La monetización es amable y opcional: nada de muros de pago ni anuncios forzados.
- Partidas cortas, ideal para jugar de a ratos.

## Stack
- Godot 4 (última estable, edición estándar), GDScript con tipado estático.
- Orientación vertical (portrait). Resolución base 720x1280, stretch mode `canvas_items`, aspect `expand`.
- Pixel art: filtro de texturas en `Nearest` a nivel proyecto.
- Exportación: Web (para validar en itch.io) y Android (Play Store).
- Backend (fase 6): Supabase vía HTTPRequest (auth anónima, guardado en la nube, ranking).
- Pagos (fase 7): plugin oficial GodotGooglePlayBilling. Toda compra se valida en el servidor.

## Estructura de carpetas
```
res://
  core/        # código reutilizable entre juegos (autoloads, en este orden: Save, Settings, Audio, Economy, Analytics)
  game/        # código específico de este juego (escenas, scripts)
  data/        # balance en archivos de datos (generadores, biomas, rarezas); nada de números mágicos en el código
  ui/          # tema de interfaz (theme.tres, generado por tools/build_theme.gd)
  assets/      # assets ya importados: fonts/, sprites/tiny_dungeon/ (originales), sprites/generated/ (propios), ui/ui_pack/
  tests/       # tests headless
  tools/       # scripts de ayuda (tests, export web, sprites, tema, capturas)
assets_src/    # zips/originales descargados (fuera de res://, ignorado por Godot con .gdignore)
docs/          # documentación y capturas de cada hito
CREDITS.md     # licencia y autor de CADA asset de terceros (obligatorio)
```

## Pantalla y arte (F2-A)
- **Layout vertical** (`game/main.tscn`), pensado para celular: arriba el HUD (oro, **oro/s grande debajo del oro**, golpe, multiplicador, profundidad con barra al próximo bioma); al medio la mina (`game/mine_view.gd`); abajo un panel con pestañas **Cuadrilla** (modos ×1/×10/Máx y una lista con el **pico como primera fila**, igual que los generadores: `game/shop_row.gd`), **Botín** y **Reliquias**. La mina se estira con el alto de la pantalla; el panel de abajo tiene alto mínimo y scroll.
- **La mina, vista desde arriba**: piso por bioma (mosaico de 16×16 mezclado al 40% con el color base: bajo contraste) con una viñeta oscura radial en los bordes; la roca mide 22× (352 px de diseño, ~1,6× la anterior), centrada y a 55% de la altura; los 8 mineros, el gólem y el taladro están parados alrededor **sin tocar la roca** (la roca ocupa el centro: abajo no hay lugar). Cada sprite tiene una **sombra elíptica a los pies** (`shadow_ellipses()`), se dibuja delante el de más abajo, y cada minero **mira hacia la roca** (variantes `miner_N_left/right/down.png`: los ojos corridos 1 px).
- **Colores de los botones** (un rol por color): **verde** = se puede comprar; **gris** = no alcanza (es el estilo `disabled` de todos); **amarillo** = solo la pestaña activa; **rojo** = solo el prestigio (también su confirmación); todo lo demás es **neutro** (estilo plano oscuro: selector ×1/×10/Máx, pestañas inactivas, cancelar, avisos). `tests/layout_scene_test.gd` lo verifica.
- **Aviso del último cofre** (pestaña Botín): se arma con el estado real, no solo con la señal del cofre. Sin bonus dice "Todavía no salió ningún cofre"; con bonus de una partida guardada, "Tu bonus viene de cofres que ya encontraste"; si no, el último cofre. Al volver a la superficie o reiniciar se limpia.
- **Medidas**: la pantalla se diseña a 720 px de ancho. Con `aspect = expand`, un celular de 360×640 es 720×1280 y uno de 412×915 es 720×1599. **Todo lo que se toca mide ≥ 96 px de diseño** (= 48 px en 360 de ancho). Los tests lo verifican en esos dos tamaños (`tests/layout_scene_test.gd`), igual que el texto cortado y el orden de dibujo.
- **Pixel art**: filtro `Nearest` y escala entera (cada píxel de sprite = N×N en pantalla). La UI va con filtro lineal (los botones del UI Pack son vectoriales).
- **Paleta**: los 27 colores de Tiny Dungeon (`game/palette.gd`). Cada bioma tiene la suya (`game/biome_palette.gd`: fondo, roca, vetas, acento de la barra), indexada por el id del bioma del balance; un bioma nuevo en `balance.json` necesita colores y arte (`tests/assets_test.gd` lo exige).
- **Sprites**: personajes y cofre salen de Tiny Dungeon (`assets/sprites/tiny_dungeon/`, solo las tiles usadas). Lo que no trae el pack (roca y piso por bioma, taladro, gólem, dinamita, runas, moneda, pico, gema), los mineros recoloreados y sus variantes de mirada los dibuja `tools/generate_sprites.gd` en 16×16 → `assets/sprites/generated/`. Volver a correrlo reescribe los mismos archivos.
- **Tema**: `ui/theme.tres` (botones del UI Pack + Pixelify Sans) lo arma `tools/build_theme.gd`; las escenas eligen estilos con `theme_type_variation` (`ButtonGreen`, `ButtonRed`, `ButtonNeutral`, `TabButton`, `CardPanel`...). Del UI Pack solo se importan los colores con rol (amarillo, verde, rojo, gris).
- **No usar `z_index`** en la mina: pondría los sprites por encima del cartel modal y del panel de debug. El orden de dibujo es el orden de los hijos (el cartel va último).
- Comandos útiles (desde la raíz): tests rápidos `powershell -File tools/run_tests.ps1` (todos con `-All`, solo los lentos con `-Slow`; ver abajo); sprites `godot --headless --path . --script res://tools/generate_sprites.gd` y luego `godot --headless --path . --import`; tema `godot --headless --path . --script res://tools/build_theme.gd`; capturas `godot --path . --windowed --script res://tools/screenshot.gd -- <carpeta>` (abre una ventana; no toca la partida guardada).

## Sonido y opciones (F2-B)
- **Settings** (`core/settings.gd`): volumen de música y de SFX (0 a 1), silencio y "reducir efectos" (sin sacudidas, destellos ni vibración, y menos partículas). Se guarda en la sección `settings` de Save y avisa con `changed`.
- **Audio** (`core/audio.gd`): buses `Music` y `SFX` (los crea si no están) que siguen a Settings; volumen 0 mutea el bus. Qué suena con cada evento lo dice `data/sounds.json` (`sfx.<id>.files`, `pitch: [mín, máx]`, `volume_db`; `music.<id>` = ruta o `{file, loop, loop_offset}`), validado al cargar. `play_sfx(id)` elige una variante al azar (nunca la misma dos seguidas) y un tono en el rango; hay 8 voces y se corta la más vieja. Un id sin sonido no es error. `play_music(id, fade, from_start)` cambia de tema con fundido cruzado y retoma un tema que ya sonó donde quedó (salvo `from_start`); `current_music_id()` dice cuál suena. Cada SFX que suena se avisa con `sfx_played(id)` (los tests escuchan eso).
- **Música** (`assets/music/`, OGG calidad 5; fuentes y LEEME en `assets_src/musica/`, fuera de git): Tierra → Town Theme, Roca → Junkala Level 1, Cristal → Crystal Cave, Magma y Abismo → Junkala Level 2 (el mismo archivo: pasar de uno al otro no lo reinicia), frenesí → fight, prestigio → Ending (suena una vez), Opciones → Title Screen. Un tema loopea salvo `"loop": false`; `loop_offset` (s) es adonde vuelve: lo anterior es la intro. El loop se aplica al recurso en runtime (los `.import` no se tocan). Los loops se armaron con ffmpeg buscando dónde se repite la música, cortando ahí y fundiendo la cola con lo que sigue al punto de loop: Town loopea 76 s desde 14,15 s, Crystal Cave se corta antes de su fundido a silencio (vuelve a 0,35 s), fight loopea en sus 68 tiempos (vuelve a 0,23 s); los de Junkala vienen listos. `tests/sounds_test.gd` mezcla cada loop con Godot (`AudioStreamPlayback.mix_audio`) cruzando el final y exige que la vuelta no salte más que la música alrededor; un tema nuevo tiene que pasar eso.
- **Director de música** (`game/music_director.gd`, hijo `MusicDirector` de la escena): suena lo de más prioridad que esté en el catálogo: prestigio > Opciones > frenesí > bioma, con fundidos cruzados (tiempos en sus constantes). El **frenesí** (`core/frenzy_meter.gd`) se prende con ritmo alto de golpes sostenido y se apaga tras un rato sin ritmo alto; los umbrales están en la sección `frenzy` de `balance.json` (`hits_per_second` contados en `window_seconds`, `enter_seconds`, `exit_seconds`) y se mide con reloj real. Al salir del frenesí el tema del bioma sigue donde quedó; abrir Opciones corta el frenesí. El prestigio arranca al confirmar, sigue `PRESTIGE_HOLD` s después de la secuencia y vuelve el tema de Tierra desde el principio. `main.gd` le pasa bioma, Opciones (señales `opened`/`closed` del panel) y prestigio. `tests/music_test.gd` (reloj de prueba) y `tests/frenzy_test.gd` lo verifican.
- **Qué suena**: `game/sound_cues.gd` traduce las señales de Economy (golpe, compra, pico, `chest_<rareza>`, prestigio); pestañas, modos y carteles piden su sonido ellos mismos, y `main.gd` el del bioma (solo al bajar a uno más profundo). Lo que se marca mientras se arma la escena no suena (`_built`; ojo: `is_node_ready()` ya es true dentro de `_ready`). `tests/sounds_test.gd` lo verifica y exige que todo `.ogg` de `assets/audio/` y `assets/music/` esté en el catálogo.
- **Silencio y Opciones**: en la fila del oro, a la derecha del multiplicador, un botón de silencio (`%SoundButton`, íconos `audioOn/audioOff` de Game Icons que siguen a `Settings.changed`) y un engranaje (`%OptionsButton`) que abre `game/options_panel.gd`: volumen de música y de SFX (sliders de 96 px; al soltar el de SFX suena un golpe de muestra) y "Reducir efectos". El panel va entre el de debug y el cartel modal. El slider y el interruptor salen del tema (`tools/build_theme.gd`). `tests/options_test.gd` lo verifica.
- **Oro que no entra**: el oro comparte fila con esos botones; si el número no entra, la fuente se achica de a 4 px hasta 48 (`_fit_gold_label`) y vuelve a 80 cuando entra. El peor caso del formato es "8.88Qa".
- **Golpe** (`MineView.play_hit`): la roca se aplasta contra el piso (pivote abajo al centro) y rebota; la mina se sacude poco (`shake_offset`: se corren la roca, la cuadrilla y el piso, no la mina ni el HUD); sale el oro flotando por carriles alternados (máx 12 a la vez) en `FxLayer` (último hijo de la mina, no come toques, recorta); vibra 25 ms. Además saltan astillas (`chips_<bioma>.png`: 4 dibujos de 4x4 en una hoja de 16x16 con las sombras de la roca del bioma; `CPUParticles2D` con animación 2x2 elige uno al azar) y, con 30% de chance, gemas (`gem.png`); los emisores son un grupo fijo que se reusa. Con "reducir efectos" no hay sacudida ni vibración y salen la mitad de partículas. `tests/juice_test.gd` lo verifica; `tools/screenshot.gd` tiene un estado `7_golpe`.
- **Escena viva**: los botones de compra, pestañas, modos, silencio, opciones y prestigio rebotan (`game/juice.gd`: escala con pivote, no toca el layout); la cuadrilla nueva crece desde los pies (no al cargar una partida). Cada minero pica en loop con su pico (`pick.png` a escala 3, del lado de la roca, se espeja), con fases repartidas por la razón áurea (`pick_angle`). La dinamita (sin sprite propio) explota en el borde de la roca: cartucho con mecha, astillas hacia afuera, destello (`circle_05` del Particle Pack, aditivo, filtro lineal; no con "reducir efectos") y sonido; cada `4 / √cantidad` s, nunca menos de 0,7 s. Las excavadoras rúnicas hacen orbitar una runa cada una (máx 6; glifos `runes_<bioma>.png` con los colores `rune`/`rune_light` de BiomePalette y un aura del mismo color); las de atrás, más chicas y apagadas. `clear_effects()` limpia lo que está en el aire (no las runas). Lo cubren `tests/scene_life_test.gd` y `tests/juice_test.gd` (base común `tests/scene_fx_base.gd`).
- **Cofre**: cae desde arriba de la mina y se apoya sobre la roca con rebote, con un brillo que respira y estrellas (`circle_05` y `star_06` del Particle Pack) del color de la rareza (`RARITY_COLORS` de `main.gd`); máx 3 a la vez. Sale un aviso de una línea arriba de la mina: "¡Cofre Raro! +4% → +2.8%" = el bonus bruto del cofre → lo que de verdad sube el efectivo (decimales con punto, como todo el juego). El legendario (`SPECIAL_RARITY`) pausa ~0,3 s con cámara lenta (`Engine.time_scale`; Economy no se frena) y destella en toda la pantalla (`game/screen_fx.gd`, entre Opciones y el cartel; sin destello con "reducir efectos"). `tests/chest_test.gd` lo verifica.
- **Cambio de bioma**: al bajar a uno más profundo, el piso y la roca nuevos se funden sobre los viejos (`show_biome(id, true)`, `biome_blend`, `OldRock`), sale un cartel pasajero "Bioma Roca · ×1.50 de oro" (no modal, no come toques) y suena; al abrir el juego o volver a la superficie, el cambio es inmediato y sin cartel. La música sigue al bioma (siempre, también al abrir o volver): `main.gd` se lo cuenta al director de música. `tests/transitions_test.gd` y `tests/sounds_test.gd` lo verifican.
- **Vuelta offline**: el mismo cartel de siempre (`Modal`) festeja con `celebrate()`: un contador grande que sube de 0 al oro juntado en 1,4 s y una lluvia de monedas (`coin.png`) entre el oscurecido y el cartel, con sonido `coins`. Cualquier otro cartel no muestra contador ni monedas.
- **Volver a la superficie**: al confirmar, la pantalla se funde a blanco en 0,45 s (`ScreenFx.cover`, bloquea los toques; a oscuro con "reducir efectos") y recién ahí corre `Economy.prestige()`, así no se ve el reinicio. Al aclarar, las reliquias ganadas (hasta 10 figuras con forma de runa) vuelan del centro al contador de la pestaña Reliquias, que suma al llegar cada una (rebote y sonido `relic`). Los tests que confirman el prestigio esperan a que pase (`_wait_until` en `main_scene_test.gd`).
- **Tests rápidos y lentos**: los tests de animación (`juice`, `scene_life`, `chest`, `transitions`) llevan `## @lento` en el encabezado y el runner los saltea salvo con `-All`, `-Slow` o un `-Filter` que los nombre. Se corren cuando se tocan animaciones y siempre antes de un commit de fase (`-All`). Corren el tiempo de juego a ×4 (`TIME_SCALE` en `tests/scene_fx_base.gd`): por eso las animaciones del juego usan tiempo de juego (`delta`, tweens, timers comunes) y no el reloj real; solo la pausa del legendario y su destello usan reloj real, divididos por la escala normal (`game/screen_fx.gd`). Economy sí usa reloj real (no lo acelera la escala).
- **Tests y audio**: un sonido que sigue sonando al salir deja "resources still in use at exit" (el runner lo cuenta como falla). `test_base._finish()` llama a `Audio.silence()` y espera 0,3 s antes de `quit()` (un OGG que sonaba tarda más de 0,1 s en soltarse; ojo, con `ignore_time_scale` no alcanza); un test que no herede de `test_base.gd` tiene que hacer lo mismo.

## Balance inicial (viene de la demo web, ajustable)
- Generadores (oro/s base, costo base, crecimiento de costo ×1.15 por unidad):
  - Minero 1 / 15 · Taladro a vapor 8 / 120 · Cuadrilla de dinamita 47 / 1.300 · Gólem de piedra 260 / 14.000 · Excavadora rúnica 1.400 / 160.000
- Costo de comprar k unidades: `c * 1.15^n * (1.15^k - 1) / 0.15`
- Pico: golpe = `2^nivel * mult + 3% del oro/s`; costo = `50 * 6^nivel`
- Profundidad: `25 * log2(1 + oroDeEstaPartida / 10)` metros; bioma nuevo cada 150 m; multiplicador de bioma `1.5^índice`
  - `oroDeEstaPartida` es el oro *ganado* en la partida (gastar no te hace retroceder). Pasado Abismo se queda en Abismo.
- Botín: 1,5% por golpe, 0,5%/s pasivo si hay cuadrilla. Rarezas: Común 70% (+1%), Raro 22% (+4%), Épico 7% (+15%), Legendario 1% (+60%) de bonus de oro. Las probabilidades se muestran en el juego.
  - El cofre no da oro en el momento: su bonus se *suma* a un bonus de botín **bruto** acumulable de la partida (Común +1%, Raro +4%, Épico +15%, Legendario +60%). Lo que multiplica el oro es el **efectivo**, con rendimientos decrecientes: `efectivo = cap × (1 − e^(−bruto / cap))`, con `cap = 3` (`loot.bonus_cap` en balance.json): techo de +300%, que nunca se alcanza. Con poco bruto rinde casi 1 a 1 (+10% bruto → +9,8%); +100% bruto → +85%; +300% bruto → +190%.
  - En pantalla se muestra el efectivo ("Bonus de botín: +27%"); el bruto solo va en el panel de debug. Se guarda el bruto y se reinicia al volver a la superficie. Sin sección `loot` en el balance no hay botín (efectivo 0).
- Reliquias: desde 300 m, `floor(((prof - 200) / 50)^1.3)`; cada una +25% de oro permanente.
  - Suman (`1 + 0.25 * reliquias`). Volver a la superficie pide confirmación y reinicia oro, cuadrilla, pico, profundidad y bonus de botín; las reliquias se conservan.
- Multiplicador final de oro: `bioma × (1 + botín efectivo) × (1 + 0.25 × reliquias)`.
- Frenesí (solo música, no da oro): 4 golpes en el último segundo, sostenido 2 s, lo prende; 3 s sin ese ritmo lo apagan (`frenzy` en balance.json).
- Progreso offline: hasta 8 horas.
  - Acredita la producción de hoy (bioma y reliquias actuales) por el tiempo fuera, sin sortear cofres. Avisa al volver si estuviste fuera 60 s o más; un hueco largo entre frames en la sesión (pestaña web o app en segundo plano) cuenta igual.

## Checklist de "jugo"
Golpe: sacudida de cámara leve, partículas de roca y gemas, número flotante, squash de la roca, sonido con variación de tono, vibración corta en Android.
Compras: el botón "rebota", sonido, el trabajador aparece animado en la escena.
Botín: cofre que cae con brillo del color de la rareza; el legendario tiene momento especial (pausa breve, flash).
Cambio de bioma: transición de paleta, cartel, música que cambia.
Números grandes con sufijos (K, M, B, T...).

## Panel de debug
Solo existe en builds de debug (`OS.is_debug_build()`): el export release (el default de `tools/export_web.ps1`) no lo crea; con `-DebugBuild` sí. Botón DBG arriba a la izquierda, con: **Oro ×1000** (multiplica por 1000 el oro que tenés, desde 0 deja 1.000; cuenta como oro ganado, así sube la profundidad), **Adelantar 1 h** (mismo cálculo que el progreso offline, con su aviso), **forzar un cofre** de cada rareza, y una línea con el bonus de botín bruto, el efectivo y el techo. Con tres pulsaciones de Oro ×1000 llegás a Abismo y con dos ya se puede volver a la superficie. Código en `game/debug_panel.gd`.

## Reglas para Claude
- Antes de cambios grandes, proponé el plan en pocas líneas y esperá el OK.
- Commits chicos y descriptivos, uno por funcionalidad.
- Después de cada cambio, corré el proyecto o los tests headless y revisá errores en la salida.
- No edites archivos `.import` ni la carpeta `.godot/`.
- Todo asset de terceros se registra en CREDITS.md con licencia y link antes de usarse. Preferir CC0.
- No agregues dependencias ni plugins sin preguntar.
- El balance vive en `data/`, no en el código.
- Escribí código pensado para reutilizar: lo de `core/` no debe depender de nada de `game/`.

## Hoja de ruta
- [x] F0 Setup: proyecto, git, estructura, export web funcionando.
- [x] F1 Loop principal: golpe, cuadrilla, pico, biomas, botín, prestigio, guardado local y offline.
- [ ] F2 Jugo y assets
  - [ ] F2-A Arte y layout vertical: sprites, paleta por bioma, tema de UI, fuente pixel, HUD / mina / pestañas. Implementado y con tests; falta el OK sobre las capturas de `docs/capturas-f2a/`.
  - [ ] F2-B Jugo: partículas, tweens (squash de la roca, números flotantes, rebote de botones), SFX, música, transición entre biomas. Implementado y con tests (ver "Sonido y opciones (F2-B)"), con música dinámica; falta el OK sobre las capturas de `docs/capturas-f2b/` y escuchar la música (loops y frenesí).
- [ ] F3 Contenido: logros, eventos, más mejoras.
- [ ] F4 Validación web: publicar en itch.io, test con familia y la comunidad del bot, medir retención día 1.
- [ ] F5 Android: export firmado, cuenta de Play Console, prueba cerrada de 14 días con 12+ testers.
- [ ] F6 Supabase: login anónimo, guardado en la nube, ranking semanal.
- [ ] F7 Monetización amable: anuncio con recompensa opcional, pack "sin anuncios", compras validadas en servidor.
