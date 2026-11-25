# Árbol de reliquias — especificación (v0.7)

Documento de diseño para implementar en v0.7. Ubicación sugerida en el repo: `docs/arbol-reliquias.md`.
Los números son punto de partida: **todo se valida con `tools/simulate_economy.gd` antes de implementar** y se ajusta para cumplir los objetivos de ritmo.

## 1. Concepto
- Un "cielo" de estrellas (constelación) donde se gastan las reliquias en mejoras permanentes.
- Un centro, **4 ramas** (una por estilo de juego), **piedras angulares** al final de cada rama y **puentes** entre ramas vecinas.
- Se revela de a poco: **niebla** + **anillos** que se abren con hitos de juego. La idea es que siempre aparezca algo nuevo y que nunca se pueda terminar en un día.
- Junto con el árbol entran los **logros** y los **fragmentos de reliquia** (sección 7).

## 2. Objetivos de ritmo (validar con el simulador)
- Primer reset: alcanza para comprar el Corazón y 1–2 estrellas.
- Primera semana jugando ~1 h por día: anillo 1 completo y parte del anillo 2.
- Árbol completo: **3 a 5 semanas** jugando ~1 h por día.
- Ninguna estrella debe sentirse inútil: cada compra tiene que notarse en la bajada siguiente.
- Con el árbol, las bajadas siguientes deben acortarse claramente (que el reset sea algo que se espera con ganas).

## 3. Estructura y desbloqueo

### Anillos (capa de revelado por hitos)
| Anillo | Qué contiene | Se abre con |
|---|---|---|
| 0 | Corazón | Primer reset |
| 1 | Primeras 3–4 estrellas de cada rama | Comprar el Corazón |
| 2 | Estrellas intermedias de cada rama | Récord de profundidad ≥ Magma **y** 5 resets |
| 3 | Estrellas avanzadas + piedras angulares | Llegar al Abismo una vez **y** 15 resets |
| 4 | Puentes entre ramas | Tener las piedras angulares de las dos ramas que une |

Los requisitos de anillo (profundidad y cantidad de resets) van en `data/`, para poder ajustarlos.

### Niebla
- Estrella comprada: encendida, con su color de rama.
- Vecina de una comprada (y en un anillo abierto): visible, con nombre, efecto y costo.
- Más lejos, o en un anillo cerrado: estrella apagada con "?". Si el anillo está cerrado, al tocarla se ve el requisito ("Llegá al Abismo para revelar esta zona").

### Prerrequisitos
- Cada estrella requiere **al menos una estrella vecina comprada** (con nivel ≥ 1). Las piedras angulares requieren la estrella anterior de su rama al máximo.

## 4. Las ramas

Notación: `id` · nombre · efecto por nivel · niveles máximos · costo base. Costo por nivel = `base × 1.6^(nivel-1)`, redondeado (validar).

### Centro
- `core` · **Corazón del pozo** · +10% de oro · 1 nivel · 1

### Fuerza (golpes) — color rojo/coral
| id | Nombre | Efecto | Niv. | Base |
|---|---|---|---|---|
| f_brazo | Brazo fuerte | +1 de golpe base | 10 | 1 |
| f_templado | Pico templado | +25% de golpe | 5 | 2 |
| f_ojo | Ojo certero | +2% de chance de crítico | 5 | 2 |
| f_brutal | Golpe brutal | +0,5× de daño crítico | 5 | 3 |
| f_eco | Eco | 10% de chance de golpe doble | 3 | 5 |
| f_combo | Combo | en frenesí, +15% de golpe por nivel | 3 | 6 |
| f_umbral | Mano rápida | el frenesí se activa con 1 golpe/s menos | 1 | 10 |
| **f_furia** | **Furia ciega** (piedra angular) | críticos ×4, pero la mitad de chance | 1 | 40 |

### Fortuna (cofres) — color dorado
| id | Nombre | Efecto | Niv. | Base |
|---|---|---|---|---|
| o_olfato | Olfato | +10% de chance de cofre | 5 | 1 |
| o_botin | Botín generoso | +20% de oro por cofre | 5 | 2 |
| o_gemologo | Gemólogo | +peso de Raro | 3 | 3 |
| o_dragon | Corazón de dragón | +peso de Épico | 3 | 5 |
| o_corona | Corona | +peso de Legendario | 2 | 8 |
| o_doble | Doble cofre | 5% de que el cofre salga doble | 3 | 6 |
| o_reliquia | Reliquia escondida | el Legendario da +1 reliquia extra | 1 | 15 |
| **o_apostador** | **Apostador** (piedra angular) | no salen Comunes; el resto sale ×1,5 más seguido | 1 | 40 |

### Cuadrilla (generadores) — color verde
| id | Nombre | Efecto | Niv. | Base |
|---|---|---|---|---|
| c_reclutas | Reclutas | empezás cada bajada con +5 mineros | 5 | 1 |
| c_capataz | Capataz | +10% de producción de toda la cuadrilla | 10 | 2 |
| c_contrato | Contrato barato | −3% de costo de generadores | 5 | 2 |
| c_ventaja | Ventaja inicial | empezás con 1 Taladro / 1 Topo / 1 Gólem (nivel 1, 2, 3) | 3 | 5 |
| c_hitos | Hitos dorados | los hitos dan ×2,5 en vez de ×2 | 1 | 10 |
| c_memoria | Memoria | conservás el nivel del Pico al volver a la superficie | 1 | 12 |
| c_revelado | Planos viejos | todos los generadores revelados desde el inicio | 1 | 4 |
| **c_mina** | **Mina sola** (piedra angular) | la cuadrilla produce ×2, tus golpes ×0,5 | 1 | 40 |

### Tiempo (AFK y dinamita) — color azul
| id | Nombre | Efecto | Niv. | Base |
|---|---|---|---|---|
| t_vigilia | Vigilia | eficiencia AFK 25% → 40% → 55% → 70% | 3 | 2 |
| t_noche | Turno noche | tope AFK 8 → 12 → 16 h | 2 | 4 |
| t_mecha | Mecha corta | −8% de recarga de la dinamita | 5 | 2 |
| t_polvora | Pólvora | +20% de daño de la dinamita | 5 | 2 |
| t_descenso | Descenso rápido | los primeros 100 m de cada bajada rinden ×2 | 1 | 10 |
| t_memoria_din | Mecha guardada | conservás el nivel de la Dinamita al volver | 1 | 12 |
| **t_reloj** | **Reloj de arena** (piedra angular) | AFK al 100%, pero con tope de 2 h | 1 | 40 |

### Puentes (anillo 4)
| id | Une | Nombre | Efecto | Costo |
|---|---|---|---|---|
| p_suerte | Fuerza + Fortuna | Golpe de suerte | cada crítico tiene 3% de chance de soltar un cofre | 60 |
| p_mineros | Fortuna + Cuadrilla | Mineros con suerte | la cuadrilla encuentra cofres (+50% de chance pasiva) | 60 |
| p_turnos | Cuadrilla + Tiempo | Turnos rotativos | +25% de producción mientras estás AFK | 60 |
| p_critica | Tiempo + Fuerza | Dinamita crítica | la dinamita puede hacer crítico | 60 |

## 5. Piedras angulares
- Cambian la forma de jugar: tienen ventaja y desventaja.
- **Máximo 2 activas a la vez.** Se pueden tener compradas las 4, pero se activan/desactivan desde el árbol (solo en la superficie, justo después de un reset, para que no se abuse).
- Los puentes requieren tener **compradas** las dos piedras angulares que unen, no activas.

## 6. Reasignar
- Botón "Reasignar estrellas": devuelve todas las reliquias gastadas (salvo el Corazón).
- Gratis la primera vez; después cuesta 10% de las reliquias devueltas. Solo en la superficie.

## 7. Logros y fragmentos de reliquia
- **Fragmentos:** 10 fragmentos = 1 reliquia (conversión automática).
- Cada logro da fragmentos según dificultad: fácil 2, medio 5, difícil 10, épico 25.
- Proponer **60 o más logros**, en categorías:
  - Golpes (100, 1.000, 10.000, 100.000 golpes; 1.000 críticos)
  - Profundidad (cada bioma; récords)
  - Cofres (primer Raro/Épico/Legendario; 100 cofres; 3 Legendarios)
  - Cuadrilla (hitos ×25/×50/×100 de cada generador; primer Gusano)
  - Resets (1, 5, 15, 50 resets; reset con más de X reliquias)
  - Frenesí y dinamita (1 minuto de frenesí seguido; 100 usos de dinamita)
  - Árbol (primera piedra angular; primer puente; árbol completo)
  - Secretos y graciosos (por ejemplo, tocar 50 veces el engranaje), ocultos hasta conseguirlos
- Pantalla de logros con progreso visible ("3.412 / 10.000 golpes"). Aviso al conseguir uno, con sonido.
- Los logros alimentan, más adelante, los **Puntos de Leyenda** del ranking (v0.8). Guardar desde ahora un contador histórico de todo lo que el ranking pueda necesitar.

## 8. Visual y experiencia
- Pantalla propia: cielo oscuro con estrellas, líneas tenues entre estrellas conectadas.
- Colores por rama; piedras angulares más grandes; puentes con línea punteada.
- Zoom con pellizco y arrastre con el dedo; botón para centrar en el Corazón.
- Tocar una estrella: panel con nombre, efecto actual → siguiente nivel, costo y botón Comprar.
- Al comprar: la estrella se enciende con destello, partículas y un sonido "celestial" que sube de tono con el nivel.
- Al abrirse un anillo nuevo: animación que "barre" la niebla de esa zona y cartel ("¡Nueva zona del cielo!").
- Acceso: botón de Reliquias del costado. En la pantalla de confirmación del reset, mostrar cuántas reliquias vas a ganar y un atajo "Ir al árbol".
- Respetar "reducir efectos".

## 9. Datos y guardado
- Definición del árbol (estrellas, posiciones, efectos, costos, anillos, prerrequisitos) en `data/arbol.json`. Nada hardcodeado.
- Guardado: niveles por id de estrella, piedras angulares activas, fragmentos, contadores históricos y logros. Compatibilidad con saves de v0.6.
- Los efectos se aplican en `core/Economy` a través de una capa de modificadores (sumas y multiplicadores por tipo), no con `if` sueltos por estrella.

## 10. Tests y validación
- Tests de: prerrequisitos, apertura de anillos, niebla, costos, reasignación, límite de piedras angulares, conversión de fragmentos, compatibilidad de saves.
- Simulación: tiempos de bajada con distintas compras del árbol; tiempo total estimado para completarlo; mostrar una tabla antes de implementar.
- Capturas en vertical del árbol en sus estados (inicio, anillo 1 completo, con niebla, árbol avanzado).
