# v0.7 — Árbol de reliquias y logros: simulación

Estado al 2026-11-25. **Nada de esto está en el juego**: es la simulación previa y espera aprobación. Rama `v07-arbol`.
Especificación de partida: [arbol-reliquias.md](arbol-reliquias.md).

## Cómo retomar
- Archivos: `tools/simulate_tree.gd` (simulador), `tools/tree_sim/economy_tree.gd` (el Economy real con los efectos del árbol encima), `tools/tree_sim/arbol_v1.json` (propuesta), `arbol_doc.json` (números originales), `logros.json`.
- Correr (usar el Godot de consola; ver la ruta en `tools/run_tests.ps1`):
  - `godot --headless --path . --script res://tools/simulate_tree.gd -- campaign res://tools/tree_sim/arbol_v1.json` (1 h por día hasta completar; ~4 min)
  - `... -- descents res://tools/tree_sim/arbol_v1.json 7` (bajadas seguidas contra las reglas de hoy)
  - `... -- stars res://tools/tree_sim/arbol_v1.json 3 <parte> <partes>` (valor de cada estrella; repartible en procesos)
- Jugador simulado: 3 golpes/s sin pausas, compra casi óptima, usa la dinamita, entra una vez por día 60 min (23 h fuera), vuelve cuando las reliquias por minuto dejan de mejorar y compra siempre la estrella más barata. Es optimista.

## Decisiones ya tomadas
1. Las reliquias **dejan de dar +25% de oro**: son solo la moneda del árbol.
2. Bonus pasivo chico (~+5%) por **reliquias ganadas en toda la historia**, para que gastar nunca debilite.
3. Con el árbol, las bajadas siguientes tienen que acortarse al menos tanto como hoy.
4. Testers: conservan sus reliquias para gastarlas, cuentan para el bonus histórico y un cartel se los avisa la primera vez.
5. Correr la profundidad por reliquia, **visible en el juego: "Próxima reliquia a X m"**.
6. "Planos viejos" pasa a ser **"Bolsa inicial"** (empezás la bajada con algo de oro).
7. Otra piedra angular para Tiempo en lugar de "Reloj de arena", que no castigue a quien juega una vez por día.

## Hallazgos
- Con los números del documento y el +25% de hoy, el árbol se completaba en **6 h** (objetivo: 21–35 h).
- Sin el +25%, con los números del documento: 52 días (el anillo 1 se lleva más de la mitad del costo).
- Con +5% y las estrellas del documento **no** se cumple la condición de las bajadas (6.ª bajada 16:01 contra 7:10 de hoy).
- Costos y forma del bonus no controlan el ritmo solos: las reliquias salen 2 por llegar a 300 m, y con el árbol 300 m queda a segundos (7–10 h con cualquier forma de bonus).
- "Planos viejos" no hacía nada: los generadores revelados ya se conservan al volver.
- "Reloj de arena" (AFK 100%, tope 2 h) era una trampa para quien entra una vez por día: 2 h pagas contra 11,2 h con Vigilia y Turno noche.
- "Magma" como requisito del anillo 2 se cumple solo (volver ya pide 300 m).

## Cómo quedan tus cambios
- **Profundidad por reliquia:** cada reliquia sacada de una bajada corre más abajo la profundidad para volver (mínimo y fórmula de reliquias). Con 0 reliquias todo es igual que hoy; con 0,28 m y 100 reliquias, se vuelve desde 328 m. Las de cofres y logros no la corren. Un dato nuevo en el guardado (reliquias sacadas de bajadas); testers: arranca con las que ya tienen. En el juego: **"Próxima reliquia a X m"** junto a la profundidad y en la confirmación de volver, y un número en `data/` para ajustarlo.
- **Bolsa inicial** (reemplaza a Planos viejos, anillo 1, 3 niveles): oro para gastar al empezar; no cuenta para la profundidad.
- **Cuenta regresiva ★** (propuesta, reemplaza a Reloj de arena): la dinamita recarga en la mitad de tiempo y cada explosión paga 25% menos (en neto ~+50% de oro de dinamita). Premia jugar activo; la desventaja son explosiones más chicas y tocarla el doble. **No toca el AFK**, así que no castiga a quien entra una vez por día.

## Otras propuestas (falta tu OK)
- **Bonus histórico:** +6% por reliquia hasta 60 y después +0,5% cada una. Con +5% la 6.ª bajada quedaba justo corta. El tope es agregado mío: sin él el final se dispara.
- **Corazón:** +50% de oro (era +10%), para que el primer reset rinda como hoy.
- **Anillos:** anillo 2 = 350 m y 8 resets; anillo 3 = 400 m y 25 resets.
- **Profundidad por reliquia:** 0,28 m.

## Costos por estrella
| id | Nombre | Efecto por nivel | Anillo | Costo por nivel | Total |
|---|---|---|---|---|---|
| core | Corazón del pozo | +50% de oro | 0 | 1 | 1 |
| f_brazo | Brazo fuerte | cada golpe suma +1,2% del oro/s | 1 | 1, 2, 2, 3, 5 | 13 |
| f_templado | Pico templado | +30% de golpe | 1 | 1, 2, 2, 3, 5 | 13 |
| f_ojo | Ojo certero | +3% de crítico | 1 | 1, 2, 2, 3, 5 | 13 |
| f_brutal | Golpe brutal | +0,6× de daño crítico | 2 | 4, 6, 9, 14, 20 | 53 |
| f_eco | Eco | +12% de golpe doble | 2 | 6, 9, 14 | 29 |
| f_combo | Combo | en frenesí, +30% de golpe | 3 | 10, 15, 23 | 48 |
| f_umbral | Mano rápida | frenesí con 1 golpe/s menos | 3 | 20 | 20 |
| f_furia | Furia ciega ★ | críticos ×4, mitad de chance | 3 | 60 | 60 |
| o_olfato | Olfato | +15% de chance de cofre | 1 | 1, 2, 2, 3, 5 | 13 |
| o_botin | Botín generoso | +30% de oro por cofre | 1 | 1, 2, 2, 3, 5 | 13 |
| o_gemologo | Gemólogo | +40% de peso del Raro | 1 | 2, 3, 5 | 10 |
| o_dragon | Corazón de dragón | +40% de peso del Épico | 2 | 6, 9, 14 | 29 |
| o_doble | Doble cofre | +8% de cofre doble | 2 | 6, 9, 14 | 29 |
| o_corona | Corona | +50% de peso del Legendario | 3 | 15, 23 | 38 |
| o_reliquia | Reliquia escondida | el Legendario da +1 reliquia | 3 | 30 | 30 |
| o_apostador | Apostador ★ | sin Comunes; el resto sale ×2 | 3 | 60 | 60 |
| c_reclutas | Reclutas | empezás con +5 mineros | 1 | 1, 2, 2, 3, 5 | 13 |
| c_capataz | Capataz | +20% de cuadrilla | 1 | 2, 3, 5, 7, 10 | 27 |
| c_contrato | Contrato barato | −4% de costo de generadores | 1 | 1, 2, 2, 3, 5 | 13 |
| c_bolsa | Bolsa inicial | empezás con 500 / 5.000 / 50.000 de oro | 1 | 2, 3, 5 | 10 |
| c_ventaja | Ventaja inicial | empezás con 1 Taladro / Topo / Gólem | 2 | 8, 12, 18 | 38 |
| c_hitos | Hitos dorados | hitos ×2,5 | 2 | 25 | 25 |
| c_memoria | Memoria | conservás el Pico | 3 | 30 | 30 |
| c_mina | Mina sola ★ | cuadrilla ×1,5, golpes ×0,25 | 3 | 60 | 60 |
| t_mecha | Mecha corta | −8% de recarga de dinamita | 1 | 1, 2, 2, 3, 5 | 13 |
| t_polvora | Pólvora | +25% de dinamita | 1 | 1, 2, 2, 3, 5 | 13 |
| t_vigilia | Vigilia | AFK 40 / 55 / 70% | 1 | 2, 3, 5 | 10 |
| t_noche | Turno noche | tope AFK 12 / 16 h | 2 | 8, 12 | 20 |
| t_descenso | Descenso rápido | hasta 200 m, oro ×3 | 2 | 15 | 15 |
| t_memoria_din | Mecha guardada | conservás la Dinamita | 3 | 30 | 30 |
| t_cuenta | Cuenta regresiva ★ | dinamita recarga en la mitad, paga 25% menos | 3 | 60 | 60 |
| p_suerte | Golpe de suerte | 3% de cofre por crítico | 4 | 60 | 60 |
| p_mineros | Mineros con suerte | +50% de cofres de la cuadrilla | 4 | 60 | 60 |
| p_turnos | Turnos rotativos | +50% de producción AFK | 4 | 60 | 60 |
| p_critica | Dinamita crítica | la dinamita puede hacer crítico | 4 | 60 | 60 |

Por anillo: anillo 0 = 1 · anillo 1 = 174 · anillo 2 = 238 · anillo 3 = 436 · anillo 4 = 240. **Árbol completo = 1089 reliquias.** ★ = piedra angular (máximo 2 activas).

## Resultados
<!--RESULTADOS-->

## Logros propuestos
70 logros, 630 fragmentos = **63 reliquias** en total. Fácil 2, medio 5, difícil 10, épico 25.

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
| Profundidad | El corazón del mundo | 600 m | épico | 25 |
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
| Resets | Mil escaleras | 150 veces | épico | 25 |
| Resets | Mochila llena | 10 reliquias en una sola bajada | difícil | 10 |
| Resets | Museo ambulante | 20 reliquias en una sola bajada | épico | 25 |
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

Contadores históricos a guardar desde v0.7 (para los Puntos de Leyenda de v0.8): golpes, críticos, oro ganado, profundidad récord, resets, reliquias ganadas, cofres por rareza, usos de dinamita, segundos de frenesí, máximo de cada generador y tiempo jugado.
