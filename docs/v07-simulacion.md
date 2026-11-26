# v0.7 — Árbol de reliquias y logros: simulación

Estado al 2026-11-26 (**tercera vuelta**). **Nada de esto está en el juego**: es la simulación y espera aprobación. Rama `v07-arbol`.
Especificación de partida: [arbol-reliquias.md](arbol-reliquias.md) (todavía sin actualizar con estos cambios).

## Para decidir antes de programar
1. **Bolsa inicial con 1 / 3 / 10 min rompe el balance:** acorta una bajada **55%** por 7 reliquias (las demás estrellas fuertes, 15–30%). La propuesta lo deja con tus números y la meta calibrada alrededor. Alternativa medida: **10 / 20 / 40 segundos → 25%**. Recomiendo la alternativa y recalibrar.
2. **Ventaja inicial y Descenso rápido siguen sin notarse** con los números pedidos (0%). Medido: Ventaja en **25 / 50 / 75%** acorta 22% (con la Bolsa corta); Descenso rápido hasta el **95% de la meta** acorta 27% (hasta el 50% o el 80%, casi nada: la profundidad es logarítmica y esos metros son menos del 2% del oro).
3. **Reclutas y Memoria no se notan con ningún número** (0–1%): los mineros pesan muy poco al final, y el pico y la dinamita se recompran enseguida. Opciones: dejarlas como comodidad, o juntar Reclutas con Ventaja.
4. **Bonus histórico:** recomiendo el **normal**. El chico funciona (la meta queda calibrada), pero al final multiplica ×3,2 en vez de ×9,5, el árbol tarda hasta 4 días más (a 1,5 golpes/s, 38–39 días: pasa las 5 semanas) y tres logros quedan fuera de alcance (Donde no llega el eco, El corazón del mundo, Queso suizo).
5. **Logros:** "Museo ambulante" a 14 no sale nunca (la mejor bajada posible es de **11** reliquias): propongo 11. "El corazón del mundo" a 575 m queda al límite (récord final 572–580 m): propongo 570.
6. **El tope de 10 golpes/s casi no frena:** un autoclicker completa el árbol en 15–16 días (la mitad) con bajadas de 4–6 min. Un tope de 6 lo acercaría al jugador de 5 golpes/s (21–23 días). Inferido de los datos, sin simular.
7. **Compras por día:** se cumplen las 3 entre los días 10 y 22 (como mucho 2 días flojos); del **23 al 25 bajan a 1–2** porque solo quedan piedras angulares y puentes. Si importa, hay que abaratarlos o sumar niveles.
8. **La meta salta unos 100 m** entre las 20 y las 40 reliquias sacadas (de 351 a 447 m), porque ahí el jugador se hace fuerte de golpe. Con la Bolsa corta debería suavizarse (sin verificar).
9. **Racha casi no existe para quien hace pausas** (2%, contra 7–15% sin pausas). Opción: que comprar la sostenga, como ya sostiene el frenesí.
10. **Las bajadas 2.ª a 8.ª**, volviendo apenas se puede, quedan en 12–16 min a 3 golpes/s (hoy bajan de 18 a 6). Es lo que pide el piso, pero conviene que lo veas en la tabla.

## Qué cambió en esta vuelta
| Pedido | Qué quedó | Resultado simulado |
|---|---|---|
| 1. Estrellas que escalan | Reclutas, Bolsa, Ventaja, Descenso, Memoria unida y **Racha** nueva, como las pediste | ⚠️ Bolsa 55% (demasiado); Reclutas, Ventaja, Descenso y Memoria 0–3% |
| 2. Bonus chico | Simulado con su propia meta calibrada | Funciona, con los costos del punto 4 |
| 3. Mitad de campaña | Probé crecimiento ×1,3 (A) y **más niveles más baratos** (B, el elegido) | A: 2,0–2,2 compras/día. B: 3,5. ⚠️ cumple hasta el día 22 |
| 4. Jugador con pausas | Golpea 30–150 s y para 10–50 s (25% sin golpear); en la pausa sigue comprando y usando dinamita | Árbol en 31–32 días; bajadas algo más largas |
| 5. Tope de 10 golpes/s | Simulado 10 golpes/s | Ver punto 6 de arriba |
| 6. Días hasta árbol completo | Columna nueva en "Estrella por estrella" | Corona ahorra ~3 días, Reliquia escondida ~1, Apostador ~1 |
| 7. AFK y cofres | **Confirmado en el código del juego** | El AFK no abre cofres y el cofre escala con el oro/s (detalle abajo) |
| 8. Logros | Mil escaleras 90, Museo ambulante 14, El corazón del mundo 575 m | Mil escaleras sale (día 26–27); los otros, punto 5 de arriba |
| 9. Cuenta regresiva 10% | Aplicado | Pasa de 3–8% a **5–14%**; sigue siendo la piedra angular más floja (las otras 11–26%) |
| 10. Contadores v0.8 | Agregados al final | — |
| Tu aclaración sobre el piso | El piso de ~10 min vale hasta completar el anillo 2; después apunto a ~9 | Cumple (tablas de abajo) |

**Punto 7, en detalle:** `apply_offline` no sortea cofres (`tests/offline_test.gd` lo comprueba con la chance forzada al 100%). El cofre paga lo que sea mayor entre N segundos de producción y M golpes (`tests/loot_test.gd`), y esos golpes incluyen el 6% del oro/s. Excepción que ya estaba a propósito: una ausencia de menos de 2 min es juego activo y puede salir un cofre.

## Cómo retomar
- Archivos: `tools/simulate_tree.gd` (simulador), `tools/tree_sim/economy_tree.gd` (el Economy real con los efectos del árbol encima), `tools/tree_sim/arbol_v3.json` (propuesta: todos los números), `tools/tree_sim/calibrate.mjs` (calibra la tabla de la meta), `logros.json`.
- Correr con el Godot de consola (ruta en `tools/run_tests.ps1`); cada campaña tarda ~2 min y se pueden lanzar en paralelo:
  - `godot --headless --path . --script res://tools/simulate_tree.gd -- campaign res://tools/tree_sim/arbol_v3.json 3 1` (perfil y semilla; `3p` = con pausas; sumar `chico` para el bonus chico o `sin=o_corona` para apagar una estrella)
  - `... -- descents res://tools/tree_sim/arbol_v3.json 7` y `... -- stars res://tools/tree_sim/arbol_v3.json 15 <parte> <partes>`
  - `node tools/tree_sim/calibrate.mjs tools/tree_sim/arbol_v3.json salida.json [chico]` (~20 min) y pasar los `puntos` al árbol. **Cualquier cambio de estrellas pide recalibrar.**
- Jugador simulado: compra casi óptimo, usa la dinamita, entra una vez por día 60 min (23 h fuera), vuelve a la superficie cuando las reliquias por minuto dejan de mejorar y compra siempre la estrella más barata. Es optimista.

## Decisiones ya tomadas
1. Las reliquias **dejan de dar +25% de oro**: son la moneda del árbol, con un bonus pasivo por reliquias ganadas en la historia.
2. Testers: conservan sus reliquias, cuentan para el bonus histórico y un cartel se los avisa.
3. La meta de volver se corre según una **tabla** y se ve en el juego: "Próximo regreso a X m".
4. "Planos viejos" es **"Bolsa inicial"**; "Cuenta regresiva ★" reemplaza a "Reloj de arena"; "A la par ★" reemplaza a "Mina sola".
5. El piso de ~10 min es a 3 golpes/s y **hasta completar el anillo 2**; después las bajadas pueden acortarse.
6. Aprobado: cofres como fuente principal de oro, 5 golpes/s por debajo del piso, 3.ª y 4.ª bajada más largas que hoy, AFK base 5%, meta por tabla.
7. El jugador activo es el más beneficiado.

## La propuesta (falta tu OK)
### Meta de volver a la superficie
Depende de las reliquias **sacadas de bajadas**; se fija al empezar cada bajada. Lineal entre puntos:

| Reliquias | 0–3 | 6 | 9 | 12 | 20 | 40 | 65 | 100 | 180 | 300 | 500 | 700 | 1000 | 1400 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Bonus normal (m) | 300 | 314 | 322 | 333 | 351 | 447 | 458 | 483 | 502 | 512 | 526 | 544 | 580 | 621 |
| Bonus chico (m) | 300 | 300 | 300 | 304 | 308 | 394 | 417 | 442 | 467 | 475 | 493 | 510 | 541 | 582 |

Más hondo paga más: +1 reliquia por cada 30 m de meta corrida. **Cambió:** la calibra un programa en vez de a mano (en la tabla normal sumé 3 m entre 40 y 500 reliquias, porque el 5% de bajadas más rápidas quedaba en 9:18).

### AFK (sin cambios)
Base 5% (hoy 25%); Vigilia 7 / 9 / 12%; tope 8 h, con Turno noche 10 / 12 h; Turnos rotativos +50%.

### Árbol
**1025 reliquias en 128 compras** (antes 918 en 98): anillo 1: 145 · anillo 2: 272 · anillo 3: 407 · puentes: 200. Requisitos de anillo sin cambios (350 m y 8 resets; 400 m y 25 resets). ★ = piedra angular (máximo 2 activas).
Decisiones mías al aplicar tus pedidos: Ventaja usa las mismas partes que Reclutas (5/10/15%) y no incluye mineros; "oro/s de la bajada anterior" es el que se veía al volver; Memoria queda en la rama Cuadrilla y Racha en Tiempo (requisito de Cuenta regresiva); Racha tiene 5 niveles que suben el tope hasta tu +30% y se reinicia al volver; para sumar compras repartí en más niveles también Eco, Corazón de dragón, Doble cofre e Hitos dorados (anillo 2).

| id | Nombre | Efecto por nivel | Anillo | Niveles | Costo por nivel | Total | Cambió |
|---|---|---|---|---|---|---|---|
| core | Corazón del pozo | +50% de oro | 0 | 1 | 1 | 1 |  |
| f_brazo | Brazo fuerte | cada golpe suma +1,2% del oro/s | 1 | 5 | 2, 2, 3, 3, 3 | 13 |  |
| f_templado | Pico templado | +30% de golpe | 1 | 5 | 2, 2, 3, 3, 3 | 13 |  |
| f_ojo | Ojo certero | +3% de crítico | 1 | 5 | 2, 2, 3, 3, 3 | 13 |  |
| f_brutal | Golpe brutal | +0,6× de daño crítico | 2 | 5 | 5, 6, 7, 8, 9 | 35 | costo |
| f_eco | Eco | +6% de golpe doble | 2 | 6 | 5, 6, 7, 8, 9, 10 | 45 | niveles |
| f_combo | Combo | en frenesí, +12% de golpe | 3 | 8 | 6, 6, 7, 8, 8, 9, 10, 10 | 64 | niveles |
| f_umbral | Mano rápida | frenesí con 1 golpe/s menos | 3 | 1 | 15 | 15 | costo |
| f_furia | Furia ciega ★ | críticos ×4, mitad de chance | 3 | 1 | 40 | 40 |  |
| o_olfato | Olfato | +20% de chance de cofre | 1 | 5 | 2, 2, 3, 3, 3 | 13 |  |
| o_botin | Botín generoso | +25% de oro por cofre | 1 | 5 | 2, 2, 3, 3, 3 | 13 |  |
| o_gemologo | Gemólogo | +50% de Raros | 1 | 3 | 2, 2, 3 | 7 |  |
| o_dragon | Corazón de dragón | +40% de Épicos | 2 | 6 | 5, 6, 7, 8, 9, 10 | 45 | niveles |
| o_doble | Doble cofre | +6% de cofre doble | 2 | 6 | 5, 6, 7, 8, 9, 10 | 45 | niveles |
| o_corona | Corona | +25% de Legendarios | 3 | 8 | 6, 6, 7, 8, 8, 9, 10, 10 | 64 | niveles |
| o_reliquia | Reliquia escondida | +20% de chance de +1 reliquia por Legendario | 3 | 5 | 7, 8, 8, 9, 10 | 42 | niveles |
| o_apostador | Apostador ★ | sin Comunes; el resto sale ×2 | 3 | 1 | 40 | 40 |  |
| c_reclutas | Reclutas | empezás con 5 / 10 / 15% de los mineros que tenías | 1 | 3 | 2, 2, 3 | 7 | **efecto** |
| c_capataz | Capataz | +5% de cuadrilla | 1 | 5 | 2, 2, 3, 3, 3 | 13 |  |
| c_contrato | Contrato barato | −4% de costo de generadores | 1 | 5 | 2, 2, 3, 3, 3 | 13 |  |
| c_bolsa | Bolsa inicial | empezás con 1 / 3 / 10 min del oro/s con el que volviste | 1 | 3 | 2, 2, 3 | 7 | **efecto** |
| c_ventaja | Ventaja inicial | empezás con 5 / 10 / 15% del resto de la cuadrilla que tenías | 2 | 3 | 8, 10, 14 | 32 | **efecto** |
| c_hitos | Hitos dorados | hitos ×2,1 … ×2,5 | 2 | 5 | 6, 7, 8, 9, 10 | 40 | niveles |
| c_memoria | Memoria | conservás el Pico y la Dinamita | 3 | 1 | 20 | 20 | **unida** |
| c_mina | A la par ★ | cuadrilla ×1,3 mientras golpeás, ×0,7 si no | 3 | 1 | 40 | 40 |  |
| t_mecha | Mecha corta | −8% de recarga de dinamita | 1 | 5 | 2, 2, 3, 3, 3 | 13 |  |
| t_polvora | Pólvora | +20% de dinamita | 1 | 5 | 2, 2, 3, 3, 3 | 13 |  |
| t_vigilia | Vigilia | AFK 7 / 9 / 12% (base 5%) | 1 | 3 | 2, 2, 3 | 7 |  |
| t_noche | Turno noche | tope AFK 10 / 12 h (base 8) | 2 | 2 | 8, 10 | 18 | costo |
| t_descenso | Descenso rápido | oro ×3 hasta el 50% de la meta | 2 | 1 | 12 | 12 | **efecto** |
| t_racha | Racha | +2% de oro por minuto golpeando sin parar; tope 6 / 12 / 18 / 24 / 30% | 3 | 5 | 7, 8, 8, 9, 10 | 42 | **nueva** |
| t_cuenta | Cuenta regresiva ★ | dinamita recarga en la mitad, paga 10% menos | 3 | 1 | 40 | 40 | **efecto** |
| p_suerte | Golpe de suerte | 3% de cofre por crítico | 4 | 1 | 50 | 50 |  |
| p_mineros | Mineros con suerte | +100% de cofres de la cuadrilla | 4 | 1 | 50 | 50 |  |
| p_turnos | Turnos rotativos | +50% de producción AFK | 4 | 1 | 50 | 50 |  |
| p_critica | Dinamita crítica | la dinamita puede hacer crítico | 4 | 1 | 50 | 50 |  |

## Resultados
1 h por día hasta completar el árbol; rangos de 3 semillas. "Se puede volver" es el momento en que se llega a la meta (lo que tardaría quien vuelve apenas puede); el jugador simulado se queda un rato más. No cuentan las bajadas con una ausencia en el medio, que el AFK adelanta.

### Compras por día (punto 3)
Compras de estrellas (niveles) por día entre el 10 y el 25, a 3 golpes/s, 3 semillas.

| | Árbol | Compras/día (promedio) | Días con menos de 3 | Árbol completo |
|---|---|---|---|---|
| A: anillos 2 y 3 con crecimiento ×1,3 | 889 reliquias, 96 compras | 2,0–2,2 | 9–10 de 13 | día 23–24 |
| **B: más niveles, más baratos** | 1025 reliquias, 128 compras | **3,5–3,6** | 2–5 de 16 (casi todos del 23 al 25) | día 28–30 |

A no puede llegar: al día 10 le quedan unas 26 compras y hacen falta 48.

### Partidas completas, bonus normal (+6% / +0,5%)
| | 3 g/s | 3 g/s con pausas | 1,5 g/s | 5 g/s | 10 g/s (techo) |
|---|---|---|---|---|---|
| Primer reset | 44–49 min | 45–49 min | 49–52 min | 37–43 min | 30–35 min |
| Se puede volver, hasta completar el anillo 2: mínimo | 8:49–9:50 | 9:18–10:58 | 11:20–11:50 | 6:09–7:15 | 3:33–4:41 |
| … 5% más rápido | 10:25–10:47 | 10:56–11:48 | 12:43–13:35 | 6:49–7:28 | 4:18–4:52 |
| … mediana | 12:43–13:23 | 14:02–15:08 | 16:06–16:17 | 8:54–9:32 | 5:55–6:15 |
| … bajadas bajo 10 min | 2–4% | 0–2% | 0% | 64–73% | 97–98% |
| Bajada completa (mediana), hasta completar el anillo 2 | 18:32–19:02 | 20:18–21:28 | 22:36–22:58 | 12:46–13:52 | 8:46–9:14 |
| Se puede volver, con el anillo 2 completo: mínimo | 7:21–7:29 | 8:17–9:23 | 8:12–10:12 | 4:58–5:29 | 2:56–3:33 |
| … 5% más rápido | 7:30–7:56 | 8:39–9:32 | 8:41–10:18 | 5:27–5:52 | 3:02–3:43 |
| … mediana | 9:08–9:49 | 11:51–11:58 | 13:56–14:10 | 6:28–7:25 | 4:00–4:40 |
| … bajadas bajo 10 min | 54–78% | 23–24% | 0–15% | 100% | 100% |
| Bajada completa (mediana), con el anillo 2 completo | 13:08–14:02 | 16:48–16:56 | 19:34–19:54 | 9:30–10:48 | 6:10–7:04 |
| Anillo 1 completo | día 8 | día 8 | día 9 | día 6–7 | día 5 |
| Anillo 2 completo | día 22–23 | día 23–25 | día 25 | día 16–17 | día 12 |
| Primera piedra angular | día 23–25 | día 25–27 | día 28 | día 18–19 | día 12–13 |
| Primer puente | día 26–28 | día 28–30 | día 32 | día 20–21 | día 14–15 |
| **Árbol completo** | **día 28–30** | **día 31–32** | **día 35** | **día 21–23** | **día 15–16** |
| Compras por día, días 10–25: promedio | 3.5–3.6 | 3.4–3.5 | 3.6 | 4.2–4.5 | 5.3–5.8 |
| … día con menos compras | 1 | 1–2 | 2–3 | 1–2 | 2–3 |
| … días con menos de 3 | 2 de 16, 5 de 16, 4 de 16 | 1 de 16, 1 de 16, 3 de 16 | 0 de 16, 1 de 16, 0 de 16 | 5 de 13, 4 de 12, 4 de 11 | 1 de 6, 0 de 5, 0 de 5 |
| Oro: golpes | 27–28% | 23–24% | 12–12% | 38–39% | 48–50% |
| Oro: cofres | 39–40% | 38–40% | 43–44% | 37–37% | 35–36% |
| Oro: dinamita | 19–19% | 20–20% | 25–26% | 13–14% | 9–9% |
| Oro: AFK | 7–8% | 9–10% | 8–10% | 6–6% | 3–4% |

### Partidas completas, bonus chico (+2% / +0,1%)
| | 3 g/s | 3 g/s con pausas | 1,5 g/s | 5 g/s | 10 g/s (techo) |
|---|---|---|---|---|---|
| Primer reset | 47–50 min | 48–50 min | 51–54 min | 40–45 min | 32–36 min |
| Se puede volver, hasta completar el anillo 2: mínimo | 8:57–9:02 | 7:29–10:15 | 8:46–11:01 | 5:44–6:15 | 3:07–3:46 |
| … 5% más rápido | 10:02–10:38 | 11:07–11:15 | 11:16–12:04 | 6:32–6:37 | 3:39–4:14 |
| … mediana | 12:11–12:30 | 13:34–14:02 | 14:25–14:37 | 8:16–8:42 | 5:12–5:33 |
| … bajadas bajo 10 min | 2–5% | 0–2% | 0–2% | 75–82% | 97–97% |
| Bajada completa (mediana), hasta completar el anillo 2 | 17:26–18:02 | 19:38–20:08 | 20:44–20:56 | 11:58–12:34 | 7:48–8:16 |
| Se puede volver, con el anillo 2 completo: mínimo | 6:03–7:29 | 8:35–9:30 | 8:36–10:06 | 3:46–4:11 | 2:52–3:23 |
| … 5% más rápido | 7:11–7:58 | 8:59–9:30 | 9:14–10:51 | 4:21–5:53 | 3:25–3:57 |
| … mediana | 9:13–9:48 | 11:36–11:49 | 13:24–14:24 | 6:46–7:11 | 3:54–4:48 |
| … bajadas bajo 10 min | 68–74% | 9–17% | 0–9% | 100% | 100% |
| Bajada completa (mediana), con el anillo 2 completo | 13:14–14:00 | 16:26–16:44 | 18:52–20:12 | 9:54–10:30 | 6:02–7:14 |
| Anillo 1 completo | día 9 | día 9–10 | día 10–11 | día 7–8 | día 6 |
| Anillo 2 completo | día 24–25 | día 26–28 | día 28–29 | día 18–19 | día 12–13 |
| Primera piedra angular | día 26 | día 28–29 | día 30–32 | día 19–20 | día 13–14 |
| Primer puente | día 29 | día 32–33 | día 35–36 | día 21–23 | día 15–16 |
| **Árbol completo** | **día 31–32** | **día 35–36** | **día 38–39** | **día 23–24** | **día 16–17** |
| Compras por día, días 10–25: promedio | 3.7–3.9 | 3.7–3.9 | 3.7–3.9 | 4.1–4.3 | 5.4–6.2 |
| … día con menos compras | 1–2 | 2–3 | 2–3 | 1 | 2 |
| … días con menos de 3 | 1 de 16, 2 de 16, 1 de 16 | 0 de 16, 1 de 16, 1 de 16 | 0 de 16, 1 de 16, 1 de 16 | 3 de 14, 5 de 14, 4 de 13 | 2 de 7, 1 de 6, 2 de 7 |
| Oro: golpes | 27–28% | 23–24% | 12–12% | 39–40% | 50–51% |
| Oro: cofres | 38–39% | 38–38% | 41–42% | 35–36% | 33–34% |
| Oro: dinamita | 19–19% | 20–21% | 25–26% | 14–14% | 9–9% |
| Oro: AFK | 6–8% | 10–10% | 10–11% | 5–6% | 4–4% |

### Las primeras 8 bajadas, bonus normal
Volviendo apenas se puede, sin ausencias (mediana de 7).

| Golpes/s | Reglas | 1.ª | 2.ª | 3.ª | 4.ª | 5.ª | 6.ª | 7.ª | 8.ª |
|---|---|---|---|---|---|---|---|---|---|
| 3 | hoy | 28:16 | 17:40 | 13:06 | 10:23 | 9:11 | 7:32 | 6:36 | 6:08 |
| 3 | árbol | 28:16 | 16:09 | 15:34 | 15:16 | 14:04 | 13:57 | 13:59 | 13:15 |
| 3 | árbol y logros | 27:13 | 14:19 | 13:58 | 13:10 | 12:24 | 12:07 | 12:20 | 12:30 |
| 3 con pausas | hoy | 29:09 | 19:07 | 14:44 | 10:46 | 9:38 | 8:10 | 6:50 | 6:24 |
| 3 con pausas | árbol | 29:09 | 17:17 | 16:49 | 15:34 | 14:00 | 14:12 | 14:37 | 14:10 |
| 3 con pausas | árbol y logros | 28:01 | 15:24 | 14:49 | 13:38 | 13:29 | 12:30 | 13:18 | 13:10 |
| 1,5 | hoy | 30:58 | 20:09 | 16:08 | 12:32 | 9:55 | 8:46 | 7:56 | 6:41 |
| 1,5 | árbol | 30:58 | 17:53 | 17:22 | 18:04 | 15:38 | 16:17 | 16:35 | 15:52 |
| 1,5 | árbol y logros | 29:54 | 16:03 | 15:49 | 15:37 | 14:03 | 15:57 | 13:23 | 14:36 |
| 5 | hoy | 24:47 | 16:01 | 12:10 | 9:14 | 8:15 | 7:13 | 6:03 | 5:41 |
| 5 | árbol | 24:47 | 14:07 | 13:56 | 13:01 | 11:42 | 11:24 | 12:17 | 10:53 |
| 5 | árbol y logros | 23:57 | 13:15 | 10:58 | 10:26 | 10:31 | 10:53 | 10:16 | 9:59 |
| 10 | hoy | 19:47 | 12:24 | 8:45 | 7:07 | 6:12 | 5:10 | 4:24 | 4:24 |
| 10 | árbol | 19:47 | 10:53 | 9:39 | 9:09 | 8:03 | 8:08 | 8:31 | 7:51 |
| 10 | árbol y logros | 18:42 | 9:27 | 8:42 | 7:51 | 7:04 | 7:31 | 7:33 | 7:26 |

### Las primeras 8 bajadas, bonus chico

| Golpes/s | Reglas | 1.ª | 2.ª | 3.ª | 4.ª | 5.ª | 6.ª | 7.ª | 8.ª |
|---|---|---|---|---|---|---|---|---|---|
| 3 | árbol | 28:16 | 17:26 | 16:33 | 15:41 | 13:49 | 13:04 | 13:51 | 12:46 |
| 3 | árbol y logros | 27:32 | 16:32 | 15:20 | 13:53 | 12:11 | 12:57 | 12:24 | 11:46 |
| 3 con pausas | árbol | 29:09 | 18:52 | 18:23 | 15:51 | 14:10 | 14:48 | 14:20 | 14:07 |
| 3 con pausas | árbol y logros | 28:49 | 17:57 | 17:39 | 14:51 | 14:06 | 13:34 | 13:00 | 12:44 |
| 1,5 | árbol | 30:58 | 19:42 | 19:21 | 17:44 | 16:34 | 14:47 | 16:09 | 14:39 |
| 1,5 | árbol y logros | 30:58 | 18:52 | 18:19 | 17:12 | 15:44 | 15:19 | 14:46 | 13:48 |
| 5 | árbol | 24:47 | 15:31 | 14:43 | 12:57 | 11:58 | 11:19 | 11:34 | 10:18 |
| 5 | árbol y logros | 24:37 | 14:35 | 13:56 | 11:29 | 11:12 | 10:25 | 10:21 | 9:30 |
| 10 | árbol | 19:47 | 12:00 | 10:44 | 9:36 | 8:49 | 7:59 | 7:53 | 7:39 |
| 10 | árbol y logros | 19:15 | 11:05 | 9:46 | 8:16 | 7:45 | 7:24 | 7:34 | 6:44 |

### Día por día (bonus normal, 3 golpes/s, semilla 1)
```
día | reliquias ganadas (gastadas) | compras del día | niveles | resets | se puede volver a los (mín/mediana) | bajada completa (mediana) | récord | meta | logros (frag.)
  primer reset a los 46:02: 6 reliquias (con fragmentos) → encendió core, f_brazo, sobran 1
  1 |     6 (5) |  3 |   3 |   1 | 27:58 / 27:58 |  46:02 | 341 m | 300 m | 20 (55)
  2 |    18 (17) |  6 |   9 |   4 | 11:58 / 12:41 |  22:28 | 364 m | 335 m | 26 (82)
  3 |    31 (29) |  6 |  15 |   7 | 11:17 / 11:52 |  20:56 | 384 m | 370 m | 31 (106)
  4 |    51 (51) | 11 |  26 |  10 | 12:18 / 17:17 |  24:08 | 441 m | 448 m | 36 (143)
  5 |    81 (80) | 10 |  36 |  14 | 10:49 / 12:33 |  17:44 | 469 m | 462 m | 39 (180)
  6 |   102 (101) |  7 |  43 |  17 | 12:57 / 14:29 |  20:20 | 483 m | 477 m | 40 (185)
  7 |   129 (128) |  9 |  52 |  20 | 15:02 / 16:19 |  22:50 | 502 m | 487 m | 44 (240)
  8 |   163 (161) |  9 |  61 |  24 | 10:25 / 10:52 |  15:26 | 502 m | 494 m | 47 (260)
  9 |   187 (184) |  4 |  65 |  27 | 13:17 / 13:33 |  19:04 | 508 m | 500 m | 47 (260)
 10 |   214 (214) |  5 |  70 |  30 | 13:23 / 14:10 |  19:56 | 519 m | 503 m | 49 (280)
 11 |   247 (241) |  4 |  74 |  34 | 13:31 / 13:34 |  19:04 | 522 m | 506 m | 50 (290)
 12 |   271 (269) |  4 |  78 |  37 | 11:55 / 13:52 |  19:30 | 522 m | 508 m | 50 (290)
 13 |   297 (292) |  3 |  81 |  40 | 13:19 / 14:20 |  20:08 | 523 m | 510 m | 51 (295)
 14 |   326 (324) |  4 |  85 |  43 | 14:17 / 14:38 |  20:34 | 528 m | 512 m | 52 (305)
 15 |   355 (348) |  3 |  88 |  46 | 15:30 / 15:38 |  21:52 | 529 m | 514 m | 54 (320)
 16 |   384 (380) |  4 |  92 |  49 | 12:55 / 16:23 |  22:54 | 531 m | 516 m | 54 (320)
 17 |   423 (421) |  5 |  97 |  53 | 11:15 / 12:22 |  17:28 | 534 m | 519 m | 55 (330)
 18 |   452 (448) |  3 | 100 |  56 | 12:45 / 13:31 |  19:02 | 534 m | 521 m | 55 (330)
 19 |   484 (484) |  4 | 104 |  59 | 12:10 / 13:46 |  19:24 | 540 m | 523 m | 55 (330)
 20 |   532 (524) |  4 | 108 |  63 |  9:51 / 12:43 |  17:58 | 544 m | 525 m | 56 (355)
 21 |   580 (574) |  5 | 113 |  67 |  9:35 / 13:37 |  19:10 | 544 m | 528 m | 56 (355)
 22 |   612 (604) |  3 | 116 |  70 | 12:58 / 13:06 |  18:28 | 544 m | 531 m | 57 (365)
 23 |   661 (645) |  3 | 119 |  73 | 13:27 / 15:24 |  21:36 | 555 m | 533 m | 60 (425)
 24 |   704 (665) |  1 | 120 |  77 | 11:20 / 12:09 |  17:12 | 558 m | 537 m | 60 (425)
 25 |   756 (745) |  2 | 122 |  82 |   8:59 / 9:47 |  14:00 | 558 m | 541 m | 61 (435)
 26 |   818 (785) |  1 | 123 |  87 |   8:41 / 9:14 |  13:14 | 558 m | 546 m | 61 (435)
 27 |   869 (825) |  1 | 124 |  91 |   8:43 / 9:00 |  12:56 | 562 m | 551 m | 64 (495)
 28 |   946 (925) |  2 | 126 |  96 |   8:24 / 9:39 |  13:50 | 571 m | 557 m | 66 (530)
 29 |  1022 (975) |  1 | 127 | 101 |   7:21 / 8:50 |  12:44 | 572 m | 563 m | 66 (530)
 30 |  1033 (1025) |  1 | 128 | 102 |             — |      — | 577 m | 564 m | 67 (555)
```

### Estrella por estrella
Cuánto acorta una bajada pasar la estrella de 0 al máximo, con las demás de su anillo y anteriores al máximo (sin otras piedras angulares), en una bajada que viene de otra igual. La meta de cada fila es adonde se llega en 12 min sin la estrella; promedio de **15 semillas** (antes 5; el ruido ahora es de unos ±4 puntos). "Días hasta árbol completo": campaña a 3 golpes/s con la estrella comprada pero sin efecto, contra con efecto (3 semillas). La última columna son valores sin azar a los 10 min de bajada.

| Estrella | Anillo | Costo | 3 g/s | 3 con pausas | 1,5 g/s | 5 g/s | Días hasta árbol completo (sin » con) | Qué más cambia |
|---|---|---|---|---|---|---|---|---|
| Corazón del pozo | 0 | 1 | +35% | +35% | +31% | +33% |  | 2 h fuera = 4:13 → 6:19 min de juego · 8 h fuera = 13:48 → 20:42 min de juego · 23 h fuera = 13:48 → 20:42 min de juego |
| Brazo fuerte | 1 | 13 | +11% | +7% | +4% | +16% |  | cofres 27.8% → 25.3% del ingreso |
| Pico templado | 1 | 13 | +11% | +10% | +4% | +18% |  | cofres 28.3% → 25.3% del ingreso |
| Ojo certero | 1 | 13 | -0% | -0% | +3% | +4% |  | cofres 25.9% → 25.3% del ingreso |
| Golpe brutal | 2 | 35 | +6% | +12% | +7% | +15% |  | cofres 37.3% → 33.8% del ingreso |
| Eco | 2 | 45 | +6% | +8% | +5% | +10% |  | cofres 36.4% → 33.8% del ingreso |
| Combo | 3 | 64 | +19% | +17% | +0% | +17% |  | cofres 35.9% → 28.9% del ingreso |
| Mano rápida | 3 | 15 | +19% | +17% | +0% | +0% |  | cofres 35.9% → 28.9% del ingreso |
| Furia ciega ★ | 3 | 40 | +20% | +17% | +11% | +26% |  | cofres 28.9% → 22.9% del ingreso |
| Olfato | 1 | 13 | +15% | +14% | +9% | +14% |  | cofres 14.5% → 25.3% del ingreso · 14.4 → 28.8 cofres cada 10 min · reliquias de cofres/h 0.4 → 0.9 |
| Botín generoso | 1 | 13 | +16% | +15% | +13% | +15% |  | cofres 13.1% → 25.3% del ingreso |
| Gemólogo | 1 | 7 | +8% | +5% | +6% | +9% |  | cofres 20.1% → 25.3% del ingreso |
| Corazón de dragón | 2 | 45 | +7% | +11% | +14% | +10% |  | cofres 26.8% → 33.8% del ingreso |
| Doble cofre | 2 | 45 | +4% | +10% | +11% | +5% |  | cofres 27.3% → 33.8% del ingreso · reliquias de cofres/h 0.9 → 1.2 |
| Corona | 3 | 64 | +3% | +3% | +2% | +2% | 31–33 » 28–30 | cofres 27.1% → 28.9% del ingreso · reliquias de cofres/h 2.4 → 7.1 |
| Reliquia escondida | 3 | 42 | +1% | +0% | -0% | -1% | 30–31 » 28–30 | reliquias de cofres/h 3.5 → 7.1 |
| Apostador ★ | 3 | 40 | +17% | +23% | +24% | +20% | 29–31 » 28–30 | cofres 28.9% → 42.5% del ingreso · 28.8 → 34.2 cofres cada 10 min · reliquias de cofres/h 7.1 → 14.1 |
| Reclutas | 1 | 7 | +0% | -0% | -0% | +0% |  |  |
| Capataz | 1 | 13 | +25% | +23% | +22% | +26% |  |  |
| Contrato barato | 1 | 13 | +11% | +9% | +7% | +10% |  |  |
| Bolsa inicial | 1 | 7 | +55% | +57% | +57% | +55% |  |  |
| Ventaja inicial | 2 | 32 | +0% | +0% | +0% | -0% |  |  |
| Hitos dorados | 2 | 40 | +31% | +31% | +28% | +26% |  |  |
| Memoria | 3 | 20 | +1% | +1% | +0% | +1% |  |  |
| A la par ★ | 3 | 40 | +23% | +19% | +25% | +24% |  | 2 h fuera = 1:11 → 0:50 min de juego · 8 h fuera = 4:21 → 3:03 min de juego · 23 h fuera = 6:28 → 4:32 min de juego |
| Mecha corta | 1 | 13 | +15% | +13% | +14% | +14% |  | cofres 29.5% → 25.3% del ingreso |
| Pólvora | 1 | 13 | +22% | +19% | +20% | +17% |  | cofres 31.9% → 25.3% del ingreso |
| Vigilia | 1 | 7 | +0% | +0% | +0% | +0% |  | 2 h fuera = 1:15 → 2:33 min de juego · 8 h fuera = 4:06 → 9:24 min de juego · 23 h fuera = 4:06 → 9:24 min de juego |
| Turno noche | 2 | 18 | +0% | +0% | +0% | +0% |  | 23 h fuera = 6:35 → 9:47 min de juego |
| Descenso rápido | 2 | 12 | -0% | +3% | +1% | +1% |  |  |
| Racha | 3 | 42 | +13% | +2% | +15% | +7% |  |  |
| Cuenta regresiva ★ | 3 | 40 | +8% | +12% | +14% | +5% |  | cofres 28.9% → 26.1% del ingreso |
| Golpe de suerte | 4 | 50 | +13% | +11% | +9% | +13% |  | cofres 28.9% → 36.8% del ingreso · 28.8 → 41.2 cofres cada 10 min · reliquias de cofres/h 7.1 → 10.1 |
| Mineros con suerte | 4 | 50 | +16% | +18% | +20% | +12% |  | cofres 28.9% → 39.7% del ingreso · 28.8 → 46.8 cofres cada 10 min · reliquias de cofres/h 7.1 → 11.5 |
| Turnos rotativos | 4 | 50 | +0% | +0% | +0% | +0% |  | 2 h fuera = 1:11 → 1:47 min de juego · 8 h fuera = 4:21 → 6:32 min de juego · 23 h fuera = 6:28 → 9:42 min de juego |
| Dinamita crítica | 4 | 50 | +18% | +17% | +25% | +11% |  |  |

Lectura:
- **Bolsa inicial** es la más fuerte del árbol, y agranda todo lo que sube el oro/s (Capataz pasó de 19% a 25%).
- **No se notan:** Reclutas, Ventaja inicial, Descenso rápido, Memoria y Ojo certero (0–4%). Corona y Reliquia escondida no aceleran la bajada pero sí la campaña; las de AFK solo se ven al volver.
- **Combo** y **Mano rápida** no hacen nada por debajo del ritmo de frenesí (y Mano rápida tampoco por encima).
- **Racha** rinde más cuanto más larga la bajada (15% a 1,5 golpes/s) y casi nada con pausas.

### Alternativas medidas (no están en la propuesta)
Acortamiento a 3 golpes/s / con pausas / 1,5 / 5, 15 semillas. Las alternativas se midieron juntas (las otras estrellas de arrastre ya con la Bolsa corta).

| Estrella | Con tus números | Alternativa | Resultado |
|---|---|---|---|
| Bolsa inicial | 1 / 3 / 10 min → 55 / 57 / 57 / 55% | 10 / 20 / 40 s | **25 / 25 / 26 / 26%** |
| Ventaja inicial | 5 / 10 / 15% → 0% | 25 / 50 / 75% (con la Bolsa corta) | **22 / 25 / 23 / 20%** |
| Reclutas | 5 / 10 / 15% → 0% | 25 / 50 / 75% | 1 / 0 / 1 / -1% |
| Descenso rápido | oro ×3 hasta 50% de la meta → 0 / 3 / 1 / 1% | hasta 80% | 2 / 7 / 4 / 2% |
| Descenso rápido | | **hasta 95%** | **27 / 27 / 23 / 21%** |
| Memoria | → 0–1% | (sin números que cambiar) | — |

Las tres alternativas juntas harían al jugador más fuerte por otro lado: la meta hay que recalibrarla.

## Logros propuestos
70 logros, 630 fragmentos = **31 reliquias** en total (20 fragmentos = 1 reliquia). Fácil 2, medio 5, difícil 10, épico 25.

| Categoría | Logro | Cómo | Dificultad | Frag. |
|---|---|---|---|---|
| Golpes | Primeras astillas | 100 golpes | fácil | 2 |
| Golpes | Muñeca firme | 1.000 golpes | fácil | 2 |
| Golpes | Rompepiedras | 10.000 golpes | medio | 5 |
| Golpes | Brazo de hierro | 100.000 golpes | difícil | 10 |
| Golpes | La roca te teme | 300.000 golpes | épico | 25 |
| Golpes | Buen ojo | 100 críticos | fácil | 2 |
| Golpes | Donde duele | 1.000 críticos | medio | 5 |
| Golpes | Cirujano de piedra | 10.000 críticos | difícil | 10 |
| Profundidad | Bajo la tierra | Llegá a Roca | fácil | 2 |
| Profundidad | Brillo propio | Llegá a Cristal | fácil | 2 |
| Profundidad | Hace calor | Llegá a Magma | medio | 5 |
| Profundidad | Mirar al Abismo | Llegá al Abismo | difícil | 10 |
| Profundidad | Sin fondo | 450 m | difícil | 10 |
| Profundidad | Medio kilómetro | 500 m | difícil | 10 |
| Profundidad | Donde no llega el eco | 550 m | épico | 25 |
| Profundidad | El corazón del mundo | 575 m | épico | 25 |
| Cofres | ¿Qué habrá adentro? | Primer cofre | fácil | 2 |
| Cofres | Algo azul | Primer cofre Raro | fácil | 2 |
| Cofres | Esto promete | Primer cofre Épico | fácil | 2 |
| Cofres | ¡Legendario! | Primer cofre Legendario | medio | 5 |
| Cofres | Coleccionista | 100 cofres | medio | 5 |
| Cofres | Buscatesoros | 1.000 cofres | difícil | 10 |
| Cofres | Rey del botín | 5.000 cofres | épico | 25 |
| Cofres | Racha dorada | 5 Legendarios | medio | 5 |
| Cofres | Cueva del dragón | 25 Legendarios | difícil | 10 |
| Cofres | Leyenda viva | 100 Legendarios | épico | 25 |
| Cuadrilla | Primer turno | 25 Mineros | fácil | 2 |
| Cuadrilla | Sindicato | 50 Mineros | medio | 5 |
| Cuadrilla | Pueblo minero | 100 Mineros | difícil | 10 |
| Cuadrilla | A toda presión | 25 Taladros | fácil | 2 |
| Cuadrilla | Nube de vapor | 50 Taladros | medio | 5 |
| Cuadrilla | Revolución industrial | 100 Taladros | difícil | 10 |
| Cuadrilla | Madriguera | 25 Topos | fácil | 2 |
| Cuadrilla | Colonia | 50 Topos | medio | 5 |
| Cuadrilla | Queso suizo | 100 Topos | épico | 25 |
| Cuadrilla | Guardia de piedra | 25 Gólems | medio | 5 |
| Cuadrilla | Ejército de roca | 50 Gólems | difícil | 10 |
| Cuadrilla | Runas encendidas | 25 Excavadoras | difícil | 10 |
| Cuadrilla | Círculo mayor | 50 Excavadoras | épico | 25 |
| Cuadrilla | Despertaste algo | Primer Gusano | difícil | 10 |
| Cuadrilla | Nido del Abismo | 25 Gusanos | épico | 25 |
| Resets | Aire fresco | Volvé a la superficie | fácil | 2 |
| Resets | Ida y vuelta | 5 veces | medio | 5 |
| Resets | Rutina | 15 veces | medio | 5 |
| Resets | Ascensor propio | 50 veces | difícil | 10 |
| Resets | Mil escaleras | 90 veces | épico | 25 |
| Resets | Mochila llena | 10 reliquias en una sola bajada | difícil | 10 |
| Resets | Museo ambulante | 14 reliquias en una sola bajada | épico | 25 |
| Frenesí y dinamita | Se te fue la mano | Encendé el frenesí | fácil | 2 |
| Frenesí y dinamita | Un minuto sin respirar | 1 min de frenesí seguido | medio | 5 |
| Frenesí y dinamita | Máquina de picar | 5 min de frenesí seguido | difícil | 10 |
| Frenesí y dinamita | ¡Fuego en el hoyo! | Usá la dinamita 10 veces | fácil | 2 |
| Frenesí y dinamita | Artificiero | 100 veces | medio | 5 |
| Frenesí y dinamita | Demoliciones S.A. | 1.000 veces | difícil | 10 |
| Árbol | Primera luz | Encendé el Corazón | fácil | 2 |
| Árbol | Constelación | 10 estrellas encendidas | medio | 5 |
| Árbol | Primer círculo | Anillo 1 completo | medio | 5 |
| Árbol | Segundo círculo | Anillo 2 completo | difícil | 10 |
| Árbol | Piedra angular | Primera piedra angular | difícil | 10 |
| Árbol | Cuatro pilares | Las 4 piedras angulares | difícil | 10 |
| Árbol | Tender puentes | Primer puente | difícil | 10 |
| Árbol | Cielo completo | Árbol completo | épico | 25 |
| Secretos | ¿Se rompió? | Tocá el engranaje 50 veces | fácil | 2 |
| Secretos | Shhh | Silenciá y reactivá 10 veces | fácil | 2 |
| Secretos | Siesta larga | Volvé después de 24 h sin jugar | fácil | 2 |
| Secretos | Turno nocturno | Jugá entre las 3 y las 5 de la mañana | medio | 5 |
| Secretos | Brazos cruzados | Llegá a Roca en una bajada sin dar un golpe | medio | 5 |
| Secretos | Curioso | Mirá la tabla de Botín 25 veces | fácil | 2 |
| Secretos | Justo a tiempo | Un golpe crítico que suelte un Legendario | épico | 25 |
| Secretos | Gracias por leer | Abrí los Créditos y llegá hasta el final | fácil | 2 |

Contadores históricos a guardar desde v0.7 (para los Puntos de Leyenda de v0.8): golpes, críticos, oro ganado, profundidad récord, resets, reliquias ganadas, cofres por rareza, usos de dinamita, segundos de frenesí, máximo de cada generador y tiempo jugado. **Nuevos en esta vuelta:** tiempo activo (segundos con algún golpe en los últimos 5 s), tiempo AFK (segundos acreditados como ausencia) y máximo de golpes/s sostenido (mejor promedio en 10 s, contando como mucho 10 por segundo). Las tres definiciones son propuesta mía.
