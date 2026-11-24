extends RefCounted
## Fórmulas puras de economía incremental: sin estado, sin autoloads y sin números de balance.
##
## Todo el balance (costos base, crecimiento, constantes del pico) llega por parámetro,
## desde res://data/. Código reutilizable entre juegos: no debe depender de nada de game/.


## Costo total de comprar `count` unidades teniendo `owned`:
## base * growth^owned * (growth^count - 1) / (growth - 1)
static func bulk_cost(base_cost: float, growth: float, owned: int, count: int) -> float:
	if count <= 0:
		return 0.0
	return base_cost * pow(growth, owned) * (pow(growth, count) - 1.0) / (growth - 1.0)


## Cantidad máxima de unidades que se pueden pagar con `gold`.
## Parte de la fórmula cerrada (logaritmo) y la corrige contra `bulk_cost`, así el
## error de redondeo de los floats nunca deja comprar de más ni de menos.
static func max_affordable(base_cost: float, growth: float, owned: int, gold: float) -> int:
	if not is_finite(gold) or gold <= 0.0:
		return 0
	# Se compara contra bulk_cost (no contra base * growth^owned): puede diferir en 1 ulp
	# por redondeo, y lo que muestra la UI como "costo de 1" es bulk_cost.
	var first_cost: float = bulk_cost(base_cost, growth, owned, 1)
	if not is_finite(first_cost) or gold < first_cost:
		return 0
	var estimate: float = log(gold * (growth - 1.0) / (base_cost * pow(growth, owned)) + 1.0) / log(growth)
	var count: int = maxi(int(floor(estimate)), 0)
	while count > 0 and bulk_cost(base_cost, growth, owned, count) > gold:
		count -= 1
	while bulk_cost(base_cost, growth, owned, count + 1) <= gold:
		count += 1
	return count


## Costo de subir el pico del nivel `level` al siguiente: cost_base * cost_growth^level.
static func pick_cost(level: int, cost_base: float, cost_growth: float) -> float:
	return cost_base * pow(cost_growth, level)


## Oro de un golpe: power_base^level * mult + passive_share * oro por segundo.
## `mult` (biomas, reliquias) escala solo la parte del pico; el oro/s ya viene multiplicado.
static func hit_value(level: int, power_base: float, mult: float, gold_per_second: float, passive_share: float) -> float:
	return pow(power_base, level) * mult + passive_share * gold_per_second


## Tope de seguridad para cantidades enteras calculadas con pow() (evita que un infinito
## se convierta en un entero basura).
const MAX_COUNT: float = 1.0e12


## Profundidad en metros: meters_scale * log2(1 + oro_de_la_partida / gold_scale).
## Sin oro ganado (o con un valor inválido) es 0 m.
static func depth(run_gold: float, meters_scale: float, gold_scale: float) -> float:
	if not (run_gold > 0.0):
		return 0.0
	return meters_scale * log(1.0 + run_gold / gold_scale) / log(2.0)


## Índice (desde 0) del bioma en el que está `depth`: uno nuevo cada `meters_each` metros.
## El último bioma se mantiene más allá de su tramo.
static func biome_index(depth: float, meters_each: float, biome_count: int) -> int:
	if biome_count <= 1 or not (depth > 0.0):
		return 0
	return int(minf(floorf(depth / meters_each), float(biome_count - 1)))


## Multiplicador de oro del bioma: growth^índice.
static func biome_multiplier(index: int, growth: float) -> float:
	return pow(growth, index)


## Reliquias que da volver a la superficie desde `depth`: 0 bajo `min_depth`; desde ahí
## floor(((depth - offset) / step)^exponent).
static func relics_for_depth(depth: float, min_depth: float, offset: float, step: float, exponent: float) -> int:
	if not (depth >= min_depth):
		return 0
	var raw: float = pow(maxf(depth - offset, 0.0) / step, exponent)
	return int(minf(floorf(raw), MAX_COUNT))


## Multiplicador de oro permanente de las reliquias: 1 + reliquias * bonus_each.
static func relic_multiplier(relics: int, bonus_each: float) -> float:
	return 1.0 + maxi(relics, 0) * bonus_each


## Sorteo por pesos. `roll` está en [0, 1) y cada peso ocupa un tramo proporcional.
## Devuelve el índice elegido, o -1 si no hay ningún peso positivo. Un peso 0 nunca sale.
static func pick_weighted(weights: Array[float], roll: float) -> int:
	var total: float = 0.0
	for weight: float in weights:
		if weight > 0.0:
			total += weight
	if total <= 0.0:
		return -1
	var target: float = clampf(roll, 0.0, 1.0) * total
	var cumulative: float = 0.0
	var chosen: int = -1
	for index: int in range(weights.size()):
		if weights[index] <= 0.0:
			continue
		cumulative += weights[index]
		chosen = index
		if target < cumulative:
			return index
	return chosen # roll >= 1 (o NaN): el último con peso


## Segundos de ausencia que se acreditan: el tiempo fuera, entre 0 y `max_seconds`.
## Un reloj atrasado (negativo) o inválido no acredita nada.
static func offline_seconds(elapsed: float, max_seconds: float) -> float:
	if is_nan(elapsed) or elapsed <= 0.0:
		return 0.0
	return minf(elapsed, maxf(max_seconds, 0.0))
