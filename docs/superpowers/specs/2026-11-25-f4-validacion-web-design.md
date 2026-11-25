# F4 · Validación web — diseño (aprobado el 2026-11-25)

## Para qué
Que la familia del autor y la comunidad del bot jueguen desde el navegador del celular (itch.io) y poder medir si vuelven al día 1 y al día 7.

## Alcance
- Pantalla de carga propia con barra de progreso.
- La música arranca con el primer toque, sin errores y sin pantalla extra de "tocá para empezar".
- Opciones: pantalla completa (oculta si el navegador no la permite), versión visible (0.4.0), "Opinar" (link configurable; oculto sin link) y "Créditos".
- El guardado persiste al cerrar la pestaña.
- Métricas mínimas en Supabase: id anónimo por dispositivo y un evento por sesión (id, fecha, versión, bioma máximo, reliquias). RLS: solo insertar. Sin datos personales.
- itch.io: portada 630×500 en pixel art y 4 capturas verticales en `docs/itch/` (Tierra, Cristal con frenesí, cofre legendario, Abismo con la cuadrilla completa).
- Zip listo para subir (index.html en la raíz) y prueba en Chrome emulando Android.

## No entra
Efecto visual de frenesí, cola de reintentos de métricas, PWA, guardado en la nube (F6), dependencias o plugins nuevos.

## Decisiones
- **Audio:** se retiene la música hasta el primer toque (se descartó la pantalla "tocá para empezar": suma fricción).
- **Guardado:** además de `user://` (IndexedDB, asíncrono), copia sincrónica en `localStorage` al ocultarse o cerrarse la pestaña; al abrir gana la más nueva. Se descartó usar solo IndexedDB (pierde segundos) y reemplazarlo por localStorage (rompe Android/escritorio).
- **Sesión:** abrir el juego, o volver después de 30 min o más sin verlo.
- **Bioma máximo:** se empieza a guardar en la partida; en partidas viejas se estima.
- **Fecha del evento:** la pone el servidor (el reloj del celular puede estar mal).
- **Supabase:** publishable key en el header `apikey` (se acepta también la anon key, que se da de baja a fin de 2026). El SQL hace `grant insert` explícito.
- **Configuración:** `data/online.json` (URL, key, link de Opinar), fuera de git, con `data/online.example.json` versionado. Va empaquetado: cambiarlo pide re-exportar (así sirve igual en Android). Sin URL y key no se envía nada.
- **Retención:** consultas con días en hora de Argentina.
- **Pantalla completa en Opciones**, no en el HUD (la fila del oro ya está llena).
- `docs/`, `tools/`, `build/` y `tests/` quedan fuera del export.
- **"Cristal con frenesí":** el frenesí es solo música; la captura es una ráfaga de golpes.

## Restricciones del proyecto
`core/` no depende de `game/`; táctiles ≥ 96 px de diseño; sin números mágicos de balance en el código; tests headless; commits chicos, sin push sin permiso.
