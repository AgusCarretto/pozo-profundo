# F4 · Validación web — plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Los pasos usan checkbox (`- [ ]`).

**Goal:** build web de Pozo Profundo listo para itch.io, jugable en celular, con métricas mínimas.

**Architecture:** lo reutilizable va en `core/` (plataforma web, copia del guardado, configuración online, Analytics); la UI en `game/`. Lo específico del navegador queda detrás de objetos reemplazables para poder testearlo en headless.

**Tech Stack:** Godot 4.7.2 (GDScript tipado), Supabase (PostgREST), Node 24 sin dependencias para verificar.

**Spec:** `docs/superpowers/specs/2026-11-25-f4-validacion-web-design.md`

## Global Constraints
- Sin dependencias ni plugins nuevos. No editar `.import` ni `.godot/`.
- `core/` no depende de `game/`. Táctiles ≥ 96 px de diseño; todo entra en 720×1280.
- Versión: `application/config/version="0.4.0"`.
- Sesión nueva: al abrir, o tras `1800` s sin frames.
- Payload del evento: exactamente `device_id`, `app_version`, `max_biome`, `relics`.
- Sin `supabase_url` + `supabase_key` no se envía nada; nunca desde editor ni headless.
- Retención en `America/Argentina/Buenos_Aires`.
- Textos en español rioplatense. Commits chicos; sin push.
- Tests: `powershell -File tools/run_tests.ps1 -All` pasa antes de cada commit.

## Review Focus
- Cerrar la pestaña justo después de comprar → la compra persiste (tareas 3 y 8).
- `localStorage` bloqueado (Safari, iframe) → el juego sigue y guarda en archivo (tarea 3).
- Sin configuración o mal escrita → ni pedidos, ni errores, ni "Opinar" (tareas 5 y 6).
- Supabase caído o 401 → el juego no se entera (tareas 5 y 8).
- Partida vieja sin `max_biome` y con reliquias → no se informa bioma 0 (tarea 4).

---

### Task 1: Export limpio, versión, pantalla de carga y zip
**Files:** Modify `export_presets.cfg`, `project.godot`, `tools/export_web.ps1`, `tests/smoke_test.gd`; Create `web/shell.html`.
**Produces:** `build/pozo-profundo-web-v<versión>.zip` (index.html en la raíz).
- [ ] Test en smoke_test `_test_export_settings()`: versión `"0.4.0"`; `exclude_filter` contiene `tests/*`, `docs/*`, `tools/*`, `build/*`, `data/online.example.json`; `include_filter` contiene `assets/fonts/OFL.txt`; `html/custom_html_shell` = `res://web/shell.html`; `application/boot_splash/show_image` = false. Ver que falla.
- [ ] Preset, project.godot y `web/shell.html` (barra con %, "Pozo Profundo", error en español, placeholders `$GODOT_URL`, `$GODOT_CONFIG`, `$GODOT_PROJECT_NAME`, `$GODOT_HEAD_INCLUDE`; sin selección ni menú de pulsación larga).
- [ ] `export_web.ps1`: borra el export anterior, crea `build/.gdignore`, arma el zip sin `*.import`, avisa si falta `data/online.json`.
- [ ] Verificar: export con `--verbose` no guarda nada de `res://docs/`, `res://tools/`, `res://build/`; el zip tiene `index.html` en la raíz.
- [ ] Commit.

### Task 2: La música espera el primer toque
**Files:** Modify `core/audio.gd`, `tests/audio_test.gd`.
**Produces:** `Audio.waiting_for_gesture: bool` (arranca en `OS.has_feature("web")`), `Audio.unlock() -> void`.
- [ ] Test `_test_waits_for_gesture()`: esperando, `play_music("a")` = true y `current_music_player() == null`; `play_sfx` = null; soltar o mover no destraba; `InputEventScreenTouch` apretado destraba y `current_music_id() == "a"` sonando; pedir "a" y después "b" mientras espera deja "b". Ver que falla.
- [ ] Implementar: guardar el último pedido; `_input` destraba con toque, click o tecla apretados; `silence()`/`stop_music()` descartan el pendiente.
- [ ] Tests, commit.

### Task 3: El guardado sobrevive al cierre de la pestaña
**Files:** Create `core/web_storage_mirror.gd`; Modify `core/save.gd`, `tests/save_test.gd`.
**Produces:** `WebStorageMirror.new(key: String)` con `read() -> String`, `write(text: String) -> bool`, `on_page_hide(callback: Callable) -> void`; `Save.mirror: RefCounted` (null fuera de web).
- [ ] Tests con un espejo falso: `save_now` escribe el mismo JSON; sin archivo carga del espejo; gana el `saved_at` más nuevo (empate → espejo); archivo corrupto → espejo y se aparta; espejo corrupto → archivo; `write` false no impide guardar; persistencia apagada no toca el espejo. Ver que fallan.
- [ ] Implementar. Clave `"<application/config/name>.save"`; JS con try/catch; `pagehide` y `visibilitychange` oculto → `save_now()`.
- [ ] Tests, commit.

### Task 4: Bioma máximo
**Files:** Modify `core/economy.gd`, `tests/save_test.gd`.
**Produces:** `Economy.max_biome() -> int` (índice 0 = Tierra); clave `"max_biome"` en la sección `economy`.
- [ ] Tests: nueva = 0; bajar a Magma y volver a la superficie mantiene 3; `reset()` = 0; `to_dict` lo incluye; partida vieja sin la clave y `relics > 0` ≥ 3; valor basura o enorme queda dentro de `0..biome_count()-1`. Ver que fallan.
- [ ] Implementar. Tests, commit.

### Task 5: Configuración y métricas
**Files:** Create `core/online_config.gd`, `data/online.example.json`, `tests/analytics_test.gd`, `docs/supabase/session_events.sql`, `docs/supabase/retencion.sql`, `tools/check_supabase.mjs`; Modify `core/analytics.gd`, `.gitignore`.
**Produces:** `OnlineConfig.load_file(path: String) -> Dictionary` (`supabase_url`, `supabase_key`, `feedback_url`; "" si falta o es inválido; solo http/https; URL sin `/` final). `Analytics`: `config: Dictionary`, `enabled: bool`, `sender: Callable(url: String, headers: PackedStringArray, body: String)`, `device_id: String`, `build_request() -> Dictionary`, `start_session()`, `tick(now: float)`, `static new_uuid() -> String`.
- [ ] Tests: UUID v4 con regex y dos distintos; config ausente/rota = todo ""; deshabilitado no envía; URL `<base>/rest/v1/session_events`; headers `apikey`, `Content-Type: application/json`, `Prefer: return=minimal`; `Authorization: Bearer` solo si la key empieza con `eyJ`; body con las 4 claves exactas; `tick` no repite antes de 1800 s y repite después; `device_id` va y vuelve por `to_dict`/`from_dict` e ignora basura. Ver que fallan.
- [ ] Implementar (HTTPRequest con `accept_gzip = false`; fallos en silencio; guardar el id apenas se crea).
- [ ] SQL: tabla `public.session_events` (`id`, `device_id uuid`, `created_at` default `now()`, `app_version`, `max_biome`, `relics`, con checks), RLS, `revoke all`, `grant insert` solo de las 4 columnas, política de insert para `anon`. Consultas D1 y D7 por cohorte con total, solo cohortes cuyo día N ya terminó, sin `app_version = 'prueba'`.
- [ ] `check_supabase.mjs`: lee `data/online.json`; el insert debe dar 201 y el select debe ser rechazado.
- [ ] Tests, commit.

### Task 6: Opciones — versión, pantalla completa, Opinar y Créditos
**Files:** Create `core/web_platform.gd`, `game/credits_panel.gd`; Modify `game/options_panel.gd`, `tests/options_test.gd`.
**Consumes:** `OnlineConfig.load_file`.
**Produces:** `WebPlatform`: `can_fullscreen()`, `is_fullscreen()`, `set_fullscreen(on)`, `open_url(url)`. `OptionsPanel`: `platform`, `feedback_url`, `fullscreen_button`, `feedback_button`, `credits_button`, `version_label`.
- [ ] Tests con plataforma falsa: etiqueta `"Versión 0.4.0"`; sin soporte no hay botón de pantalla completa; con soporte alterna y cambia el texto; sin link no hay "Opinar"; con link abre exactamente esa URL; Créditos abre, contiene "Godot Engine", "SIL OPEN FONT LICENSE", "pixelsphere.org" y cierra; todo entra en 720×1280 con todos los botones visibles. Ver que fallan.
- [ ] Implementar. Tests, commit.

### Task 7: Portada y capturas para itch.io
**Files:** Create `tools/itch_art.gd`, `docs/itch/*.png`.
- [ ] `portada.png` 630×500 (pixel art ×5: mina, roca, "Pozo Profundo"); `1_tierra.png`, `2_cristal_frenesi.png`, `3_cofre_legendario.png`, `4_abismo_cuadrilla.png` a 720×1280. No toca la partida guardada.
- [ ] Mirar cada imagen, corregir, verificar tamaños. Commit.

### Task 8: Prueba en Chrome como Android, zip final y documentación
**Files:** Modify `CLAUDE.md`, `CREDITS.md` si hace falta. Scripts de prueba en el scratchpad.
- [ ] Export con un `data/online.json` temporal que apunte a un Supabase simulado.
- [ ] CDP (emulación Android, táctil, autoplay con gesto obligatorio): carga y barra; consola sin errores; sin música antes del toque y con música después; evento recibido con las 4 claves; golpear, cerrar la pestaña en el acto y reabrir conserva; pantalla completa; Opinar; Créditos; Supabase con error no rompe.
- [ ] Borrar la configuración temporal, exportar el zip final y verificarlo.
- [ ] Sección "Web (F4)" en CLAUDE.md. Tests `-All`, commit.
