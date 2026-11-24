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
  core/        # código reutilizable entre juegos (autoloads: Save, Audio, Economy, Analytics)
  game/        # código específico de este juego (escenas, scripts)
  data/        # balance en archivos de datos (generadores, biomas, rarezas); nada de números mágicos en el código
  ui/          # escenas y temas de interfaz
  assets/      # assets ya importados (sprites, audio, fuentes)
  tests/       # tests headless
assets_src/    # zips/originales descargados (fuera de res://, ignorado por Godot con .gdignore)
CREDITS.md     # licencia y autor de CADA asset de terceros (obligatorio)
```

## Balance inicial (viene de la demo web, ajustable)
- Generadores (oro/s base, costo base, crecimiento de costo ×1.15 por unidad):
  - Minero 1 / 15 · Taladro a vapor 8 / 120 · Cuadrilla de dinamita 47 / 1.300 · Gólem de piedra 260 / 14.000 · Excavadora rúnica 1.400 / 160.000
- Costo de comprar k unidades: `c * 1.15^n * (1.15^k - 1) / 0.15`
- Pico: golpe = `2^nivel * mult + 3% del oro/s`; costo = `50 * 6^nivel`
- Profundidad: `25 * log2(1 + oroDeEstaPartida / 10)` metros; bioma nuevo cada 150 m; multiplicador de bioma `1.5^índice`
- Botín: 4% por golpe, 2%/s pasivo si hay cuadrilla. Rarezas: Común 70% (+1%), Raro 22% (+4%), Épico 7% (+15%), Legendario 1% (+60%) de bonus de oro. Las probabilidades se muestran en el juego.
- Reliquias: desde 300 m, `floor(((prof - 200) / 50)^1.3)`; cada una +25% de oro permanente.
- Progreso offline: hasta 8 horas.

## Checklist de "jugo"
Golpe: sacudida de cámara leve, partículas de roca y gemas, número flotante, squash de la roca, sonido con variación de tono, vibración corta en Android.
Compras: el botón "rebota", sonido, el trabajador aparece animado en la escena.
Botín: cofre que cae con brillo del color de la rareza; el legendario tiene momento especial (pausa breve, flash).
Cambio de bioma: transición de paleta, cartel, música que cambia.
Números grandes con sufijos (K, M, B, T...).

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
- [ ] F1 Loop principal: golpe, cuadrilla, pico, biomas, botín, prestigio, guardado local y offline.
- [ ] F2 Jugo y assets: sprites, partículas, tweens, SFX, música, fuente pixel.
- [ ] F3 Contenido: logros, eventos, más mejoras.
- [ ] F4 Validación web: publicar en itch.io, test con familia y la comunidad del bot, medir retención día 1.
- [ ] F5 Android: export firmado, cuenta de Play Console, prueba cerrada de 14 días con 12+ testers.
- [ ] F6 Supabase: login anónimo, guardado en la nube, ranking semanal.
- [ ] F7 Monetización amable: anuncio con recompensa opcional, pack "sin anuncios", compras validadas en servidor.
