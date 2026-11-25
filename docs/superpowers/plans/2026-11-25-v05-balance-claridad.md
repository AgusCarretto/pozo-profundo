# v0.5 Balance y claridad — plan

**Goal:** aplicar el balance aprobado y hacerlo visible en pantalla.
**Architecture:** reglas en `core/economy.gd` con números en `data/balance.json`; la interfaz en `game/` solo las muestra.
**Tech Stack:** Godot 4.7, GDScript tipado, tests headless (`tools/run_tests.ps1`).
**Spec:** `docs/superpowers/specs/2026-11-25-v05-balance-claridad-design.md`
**Ejecución:** inline, en `main`, un commit por tarea. Test primero; antes de cada commit, la suite pasa.

## Global Constraints
- Ningún número de balance en el código; `core/` no depende de `game/`.
- Colores con rol: verde comprar, gris no alcanza, rojo solo prestigio.
- Todo lo que se toca mide ≥ 96 px; ningún texto cortado a 720×1280 ni 720×1599.
- Secciones nuevas del balance (`crit`, `milestones`, `legacy`) son opcionales: sin ellas ese sistema no existe.

## Review Focus
- Partida o código de respaldo de v0.4.x cargado en v0.5 → migra una sola vez (T6).
- Cofre antes de tener cuadrilla → paga por golpes, nunca 0 (T5).
- Compra ×10/Máx que cruza dos hitos de una vez → avisa y aplica los dos (T3).
- Guardado con generadores comprados y sin el dato "revealed" → se ven (T4).
- Tests que golpean con el balance real → sin críticos al azar (T2).

## Tareas
- [ ] **T1 AFK 25%.** `offline.efficiency`; `EconomyMath.offline_paid_seconds(seconds, full, efficiency) -> float`
  (= min(s, full) + max(s − full, 0)·eff); `Economy.offline_efficiency() -> float`; el cartel lo dice.
  Test: 10 oro/s, 1 h, 0.25 → 10·(120 + 3480·0.25) = 9900; 100 s → 1000; tope 8 h sobre el tiempo real.
- [ ] **T2 Críticos.** `crit {chance, multiplier}`; `Economy.last_hit_critical: bool`; `hit()` devuelve el monto ya
  multiplicado; el número flotante es más grande y naranja; sfx `crit`. Test: chance 1 → golpe ×2; 0 → igual;
  8% en 20.000 golpes ≈ 1600.
- [ ] **T3 Hitos.** `milestones {at, multiplier}`; `milestone_multiplier(i) -> float`, `next_milestone(i) -> int`,
  señal `milestone_reached(index, threshold)`. Tarjeta: "42/s · 21/25" (después del último, "· ×8"); aviso y sonido.
  Test: 24 → ×1, 25 → ×2, 50 → ×4, 100 → ×8; ×10 de 20 a 30 emite una vez; Máx de 0 a 60 emite 25 y 50.
- [ ] **T4 Generadores ocultos.** `is_generator_revealed(i) -> bool`, se guarda `revealed`, sobrevive al prestigio,
  `reset()` lo borra. Tarjeta oculta: "???", "Comprá el anterior", deshabilitada, ícono en silueta.
- [ ] **T5 Cofres de oro.** `loot.rarities[] {weight, seconds, hits, relics}`; fuera `loot_bonus*`;
  `loot_reward(rarity) -> float`; `loot_dropped(rarity, amount)`; `loot_table()` → {id, name, chance, seconds, hits,
  relics}. Cartel de Botín, aviso, lluvia de monedas (`MineView.rain_coins`), panel de debug.
  Test: reward = max(s·oro/s, h·golpe); legendario suma 1 reliquia; una sola `gold_changed` por golpe.
- [ ] **T6 Curva nueva y migración.** `balance.json` (1.15, 15/8, biomas 100, prestigio 300/200) y `legacy`
  {meters_scale 25, gold_scale 10, min_depth 450, depth_offset 350, depth_step 50, exponent 1.3};
  `to_dict()` marca `balance_version: 2`; `pending_migration_report {relics_gained}` y su cartel.
  Test: save viejo con run_gold 2.7e6 y 3 reliquias → 5 reliquias, bajada en cero, lo comprado sigue revelado;
  cargarlo de nuevo ya guardado no vuelve a migrar.
- [ ] **T7 Cierre.** `tools/simulate_economy.gd` (usa el Economy real), versión 0.5.0, CLAUDE.md, suite `-All`,
  prueba en Chrome, `tools/export_web.ps1`, push.
