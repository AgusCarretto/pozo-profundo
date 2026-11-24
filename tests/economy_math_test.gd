extends "res://tests/test_base.gd"
## Tests headless de las fórmulas puras de core/economy_math.gd y de la estructura de data/balance.json.

const EconomyMath := preload("res://core/economy_math.gd")

const GROWTH: float = 1.15
const BALANCE_PATH: String = "res://data/balance.json"


func _initialize() -> void:
	_test_single_unit_cost()
	_test_bulk_cost()
	_test_max_affordable_known_values()
	_test_max_affordable_boundaries()
	_test_max_affordable_degenerate_inputs()
	_test_pick_cost()
	_test_hit_value()
	_test_depth()
	_test_biome_index_and_multiplier()
	_test_biome_progress()
	_test_relics_for_depth()
	_test_relic_multiplier()
	_test_pick_weighted()
	_test_loot_bonus_effective()
	_test_offline_seconds()
	_test_balance_file()
	_finish()


func _test_single_unit_cost() -> void:
	_section("Costo de una unidad")
	_check_near(EconomyMath.bulk_cost(15.0, GROWTH, 0, 1), 15.0, "minero #1 cuesta el costo base (15)")
	_check_near(EconomyMath.bulk_cost(15.0, GROWTH, 3, 1), 15.0 * pow(GROWTH, 3), "con 3 mineros el siguiente cuesta 15 * 1.15^3")


func _test_bulk_cost() -> void:
	_section("Costo de comprar k unidades")
	_check_near(EconomyMath.bulk_cost(15.0, GROWTH, 0, 10), 304.5557735836, "10 mineros desde 0 cuestan ~304.56", 1e-9)
	var sum_of_singles: float = 0.0
	for i: int in range(10):
		sum_of_singles += EconomyMath.bulk_cost(120.0, GROWTH, 4 + i, 1)
	_check_near(EconomyMath.bulk_cost(120.0, GROWTH, 4, 10), sum_of_singles, "comprar 10 juntos = sumar 10 compras de a una")
	_check_eq(EconomyMath.bulk_cost(15.0, GROWTH, 5, 0), 0.0, "comprar 0 unidades cuesta 0")


func _test_max_affordable_known_values() -> void:
	_section("Compra máxima: valores conocidos")
	_check_eq(EconomyMath.max_affordable(15.0, GROWTH, 0, 15.0), 1, "con 15 de oro se compra 1 minero")
	_check_eq(EconomyMath.max_affordable(15.0, GROWTH, 0, 14.99), 0, "con 14.99 no se compra ninguno")
	_check_eq(EconomyMath.max_affordable(15.0, GROWTH, 0, 304.56), 10, "con 304.56 se compran 10 mineros")
	_check_eq(EconomyMath.max_affordable(15.0, GROWTH, 0, 304.55), 9, "con 304.55 se compran solo 9")


## Cada combinación (generador, cantidad ya comprada, k) se prueba en el borde exacto:
## con el oro justo para k se compran k; con una pizca menos, k - 1.
func _test_max_affordable_boundaries() -> void:
	_section("Compra máxima: bordes exactos")
	var base_costs: Array[float] = [15.0, 120.0, 1300.0, 14000.0, 160000.0]
	var owned_values: Array[int] = [0, 1, 7, 50, 200, 1000, 2000]
	var counts: Array[int] = [1, 2, 10, 37]
	var failures_before: int = _failures
	var combos: int = 0
	for base_cost: float in base_costs:
		for owned: int in owned_values:
			for k: int in counts:
				var exact: float = EconomyMath.bulk_cost(base_cost, GROWTH, owned, k)
				var below: float = exact * (1.0 - 1e-12)
				var label: String = "base=%s owned=%d k=%d" % [str(base_cost), owned, k]
				var at_exact: int = EconomyMath.max_affordable(base_cost, GROWTH, owned, exact)
				var at_below: int = EconomyMath.max_affordable(base_cost, GROWTH, owned, below)
				combos += 1
				if at_exact != k:
					_check_eq(at_exact, k, "oro justo, " + label)
				if at_below != k - 1:
					_check_eq(at_below, k - 1, "oro apenas menos, " + label)
	_check(_failures == failures_before, "%d combinaciones respetan el borde exacto (k con oro justo, k-1 con una pizca menos)" % combos)

	# Invariante general: lo que devuelve se puede pagar y una unidad más no.
	var invariant_ok: bool = true
	for gold: float in [20.0, 999.0, 1.0e5, 3.3e9, 1.0e15, 7.7e30, 1.0e100]:
		for owned: int in owned_values:
			var k: int = EconomyMath.max_affordable(120.0, GROWTH, owned, gold)
			var affordable: bool = k == 0 or EconomyMath.bulk_cost(120.0, GROWTH, owned, k) <= gold
			var next_too_expensive: bool = EconomyMath.bulk_cost(120.0, GROWTH, owned, k + 1) > gold
			if not (affordable and next_too_expensive):
				invariant_ok = false
				printerr("    invariante rota: gold=%s owned=%d k=%d" % [str(gold), owned, k])
	_check(invariant_ok, "max_affordable(oro) siempre paga k y nunca alcanza para k+1")


func _test_max_affordable_degenerate_inputs() -> void:
	_section("Compra máxima: entradas límite")
	_check_eq(EconomyMath.max_affordable(15.0, GROWTH, 0, 0.0), 0, "con 0 de oro no se compra nada")
	_check_eq(EconomyMath.max_affordable(15.0, GROWTH, 0, -50.0), 0, "oro negativo no compra nada")
	_check_eq(EconomyMath.max_affordable(15.0, GROWTH, 0, NAN), 0, "oro NaN no compra nada")
	_check_eq(EconomyMath.max_affordable(15.0, GROWTH, 0, INF), 0, "oro infinito no explota (devuelve 0)")
	_check_eq(EconomyMath.max_affordable(15.0, GROWTH, 100000, 1.0e300), 0, "costo que desborda a infinito no se puede comprar")
	var big_cost: float = EconomyMath.bulk_cost(15.0, GROWTH, 2000, 1)
	_check(is_finite(big_cost) and big_cost > 1.0e100, "con 2000 unidades el costo sigue siendo finito (%s)" % str(big_cost))


func _test_pick_cost() -> void:
	_section("Costo del pico")
	_check_eq(EconomyMath.pick_cost(0, 50.0, 6.0), 50.0, "nivel 0 -> 50")
	_check_eq(EconomyMath.pick_cost(1, 50.0, 6.0), 300.0, "nivel 1 -> 300")
	_check_eq(EconomyMath.pick_cost(2, 50.0, 6.0), 1800.0, "nivel 2 -> 1800")
	_check(is_finite(EconomyMath.pick_cost(300, 50.0, 6.0)), "nivel 300 sigue siendo finito")


func _test_hit_value() -> void:
	_section("Valor del golpe")
	_check_eq(EconomyMath.hit_value(0, 2.0, 1.0, 0.0, 0.03), 1.0, "nivel 0 sin cuadrilla = 1")
	_check_eq(EconomyMath.hit_value(3, 2.0, 1.0, 0.0, 0.03), 8.0, "nivel 3 sin cuadrilla = 2^3 = 8")
	_check_near(EconomyMath.hit_value(3, 2.0, 1.0, 100.0, 0.03), 11.0, "nivel 3 con 100 oro/s = 8 + 3% de 100")
	_check_near(EconomyMath.hit_value(3, 2.0, 2.0, 100.0, 0.03), 19.0, "el multiplicador solo escala la parte del pico: 16 + 3")


## Profundidad = meters_scale * log2(1 + oro_de_la_partida / gold_scale), con 25 y 10 del balance.
func _test_depth() -> void:
	_section("Profundidad")
	_check_eq(EconomyMath.depth(0.0, 25.0, 10.0), 0.0, "sin oro ganado: 0 m")
	_check_near(EconomyMath.depth(10.0, 25.0, 10.0), 25.0, "10 de oro: log2(2) = 1 -> 25 m")
	_check_near(EconomyMath.depth(30.0, 25.0, 10.0), 50.0, "30 de oro: log2(4) = 2 -> 50 m")
	_check_near(EconomyMath.depth(630.0, 25.0, 10.0), 150.0, "630 de oro: log2(64) = 6 -> 150 m (entra a Roca)")
	_check_near(EconomyMath.depth(40950.0, 25.0, 10.0), 300.0, "40.950 de oro: log2(4096) = 12 -> 300 m", 1e-6)
	_check(EconomyMath.depth(100.0, 25.0, 10.0) < EconomyMath.depth(200.0, 25.0, 10.0), "más oro ganado -> más profundo")
	_check_near(EconomyMath.depth(1.0e300, 25.0, 10.0), 25.0 * log(1.0e299) / log(2.0), "con oro astronómico sigue siendo finito y creciente", 1e-6)
	_check_eq(EconomyMath.depth(-5.0, 25.0, 10.0), 0.0, "oro negativo no da profundidad negativa")
	_check_eq(EconomyMath.depth(NAN, 25.0, 10.0), 0.0, "oro NaN -> 0 m")


## Un bioma nuevo cada 150 m; el último bioma se mantiene más allá de su tramo.
func _test_biome_index_and_multiplier() -> void:
	_section("Bioma por profundidad")
	_check_eq(EconomyMath.biome_index(0.0, 150.0, 5), 0, "0 m -> Tierra (0)")
	_check_eq(EconomyMath.biome_index(149.9, 150.0, 5), 0, "149.9 m sigue en Tierra")
	_check_eq(EconomyMath.biome_index(150.0, 150.0, 5), 1, "150 m -> Roca (1)")
	_check_eq(EconomyMath.biome_index(299.0, 150.0, 5), 1, "299 m -> Roca")
	_check_eq(EconomyMath.biome_index(300.0, 150.0, 5), 2, "300 m -> Cristal (2)")
	_check_eq(EconomyMath.biome_index(450.0, 150.0, 5), 3, "450 m -> Magma (3)")
	_check_eq(EconomyMath.biome_index(600.0, 150.0, 5), 4, "600 m -> Abismo (4)")
	_check_eq(EconomyMath.biome_index(9000.0, 150.0, 5), 4, "más allá del último bioma se queda en Abismo")
	_check_eq(EconomyMath.biome_index(-10.0, 150.0, 5), 0, "profundidad negativa -> Tierra")
	_check_eq(EconomyMath.biome_index(500.0, 150.0, 1), 0, "con un solo bioma siempre es el 0")
	_section("Multiplicador de bioma (1.5^índice)")
	_check_eq(EconomyMath.biome_multiplier(0, 1.5), 1.0, "Tierra x1")
	_check_eq(EconomyMath.biome_multiplier(1, 1.5), 1.5, "Roca x1.5")
	_check_eq(EconomyMath.biome_multiplier(2, 1.5), 2.25, "Cristal x2.25")
	_check_near(EconomyMath.biome_multiplier(3, 1.5), 3.375, "Magma x3.375")
	_check_near(EconomyMath.biome_multiplier(4, 1.5), 5.0625, "Abismo x5.0625")


## Reliquias de una subida: 0 bajo la profundidad mínima; desde ahí floor(((prof - 200) / 50)^1.3).
## Cuánto falta para el bioma siguiente: fracción de 0 a 1 dentro del tramo del bioma actual.
func _test_biome_progress() -> void:
	_section("Progreso hasta el próximo bioma")
	_check_eq(EconomyMath.biome_progress(0.0, 150.0, 5), 0.0, "en la superficie: 0")
	_check_near(EconomyMath.biome_progress(75.0, 150.0, 5), 0.5, "a mitad del primer tramo (75 m): 0.5")
	_check(EconomyMath.biome_progress(149.9, 150.0, 5) > 0.99 and EconomyMath.biome_progress(149.9, 150.0, 5) < 1.0, "justo antes de los 150 m: casi 1, sin llegar")
	_check_eq(EconomyMath.biome_progress(150.0, 150.0, 5), 0.0, "al cruzar los 150 m arranca el tramo siguiente: 0")
	_check_near(EconomyMath.biome_progress(225.0, 150.0, 5), 0.5, "a 225 m (mitad del segundo tramo): 0.5")
	_check_near(EconomyMath.biome_progress(525.0, 150.0, 5), 0.5, "a 525 m (mitad del cuarto tramo): 0.5")
	_check_eq(EconomyMath.biome_progress(600.0, 150.0, 5), 1.0, "en el último bioma la barra está llena (600 m)")
	_check_eq(EconomyMath.biome_progress(9999.0, 150.0, 5), 1.0, "y se queda llena más allá")
	_check_eq(EconomyMath.biome_progress(-10.0, 150.0, 5), 0.0, "una profundidad negativa: 0")
	_check_eq(EconomyMath.biome_progress(NAN, 150.0, 5), 0.0, "NaN: 0")
	_check_eq(EconomyMath.biome_progress(50.0, 150.0, 1), 1.0, "con un solo bioma ya estás en el último: 1")
	_check_eq(EconomyMath.biome_progress(50.0, 150.0, 0), 0.0, "sin biomas: 0")


func _test_relics_for_depth() -> void:
	_section("Reliquias según la profundidad")
	_check_eq(EconomyMath.relics_for_depth(0.0, 300.0, 200.0, 50.0, 1.3), 0, "en la superficie: 0")
	_check_eq(EconomyMath.relics_for_depth(250.0, 300.0, 200.0, 50.0, 1.3), 0, "250 m: la fórmula daría 1, pero no llega a los 300 m mínimos -> 0")
	_check_eq(EconomyMath.relics_for_depth(299.99, 300.0, 200.0, 50.0, 1.3), 0, "299.99 m: todavía 0")
	_check_eq(EconomyMath.relics_for_depth(300.0, 300.0, 200.0, 50.0, 1.3), 2, "300 m: floor(2^1.3 = 2.46) = 2")
	_check_eq(EconomyMath.relics_for_depth(350.0, 300.0, 200.0, 50.0, 1.3), 4, "350 m: floor(3^1.3 = 4.17) = 4")
	_check_eq(EconomyMath.relics_for_depth(400.0, 300.0, 200.0, 50.0, 1.3), 6, "400 m: floor(4^1.3 = 6.06) = 6")
	_check_eq(EconomyMath.relics_for_depth(600.0, 300.0, 200.0, 50.0, 1.3), 14, "600 m: floor(8^1.3 = 14.93) = 14")
	_check_eq(EconomyMath.relics_for_depth(1000.0, 300.0, 200.0, 50.0, 1.3), 36, "1000 m: floor(16^1.3 = 36.76) = 36")
	var monotonic: bool = true
	var previous: int = 0
	for meters: int in range(300, 1500, 7):
		var relics: int = EconomyMath.relics_for_depth(float(meters), 300.0, 200.0, 50.0, 1.3)
		if relics < previous:
			monotonic = false
		previous = relics
	_check(monotonic, "más profundo nunca da menos reliquias (300 a 1500 m)")
	_check_eq(EconomyMath.relics_for_depth(NAN, 300.0, 200.0, 50.0, 1.3), 0, "profundidad NaN -> 0")


func _test_relic_multiplier() -> void:
	_section("Multiplicador de reliquias (+25% cada una)")
	_check_eq(EconomyMath.relic_multiplier(0, 0.25), 1.0, "sin reliquias x1")
	_check_eq(EconomyMath.relic_multiplier(1, 0.25), 1.25, "1 reliquia x1.25")
	_check_eq(EconomyMath.relic_multiplier(4, 0.25), 2.0, "4 reliquias x2")
	_check_eq(EconomyMath.relic_multiplier(10, 0.25), 3.5, "10 reliquias x3.5")
	_check_eq(EconomyMath.relic_multiplier(-3, 0.25), 1.0, "reliquias negativas no restan")


## Sorteo por pesos: `roll` es un número en [0, 1) y cada peso ocupa un tramo proporcional.
func _test_pick_weighted() -> void:
	_section("Sorteo ponderado de rareza (70 / 22 / 7 / 1)")
	var weights: Array[float] = [70.0, 22.0, 7.0, 1.0]
	_check_eq(EconomyMath.pick_weighted(weights, 0.0), 0, "roll 0 -> Común")
	_check_eq(EconomyMath.pick_weighted(weights, 0.69), 0, "roll 0.69 -> Común")
	_check_eq(EconomyMath.pick_weighted(weights, 0.71), 1, "roll 0.71 -> Raro")
	_check_eq(EconomyMath.pick_weighted(weights, 0.91), 1, "roll 0.91 -> Raro")
	_check_eq(EconomyMath.pick_weighted(weights, 0.93), 2, "roll 0.93 -> Épico")
	_check_eq(EconomyMath.pick_weighted(weights, 0.985), 2, "roll 0.985 -> Épico")
	_check_eq(EconomyMath.pick_weighted(weights, 0.995), 3, "roll 0.995 -> Legendario")
	_check_eq(EconomyMath.pick_weighted(weights, 1.0), 3, "roll 1 (fuera de rango) -> el último, sin explotar")
	_check_eq(EconomyMath.pick_weighted(weights, -1.0), 0, "roll negativo -> el primero")
	var sparse: Array[float] = [0.0, 5.0, 0.0]
	_check_eq(EconomyMath.pick_weighted(sparse, 0.0), 1, "un peso 0 nunca sale (roll 0)")
	_check_eq(EconomyMath.pick_weighted(sparse, 0.999), 1, "un peso 0 nunca sale (roll 0.999)")
	var empty: Array[float] = []
	_check_eq(EconomyMath.pick_weighted(empty, 0.5), -1, "sin pesos -> -1")
	var none: Array[float] = [0.0, 0.0]
	_check_eq(EconomyMath.pick_weighted(none, 0.5), -1, "todos los pesos en 0 -> -1")


## Bonus de botín con rendimientos decrecientes: cap * (1 - e^(-bruto / cap)).
func _test_loot_bonus_effective() -> void:
	_section("Bonus de botín efectivo (rendimientos decrecientes, techo +300%)")
	_check_eq(EconomyMath.loot_bonus_effective(0.0, 3.0), 0.0, "sin bonus bruto no hay bonus efectivo")
	_check_near(EconomyMath.loot_bonus_effective(1.0, 3.0), 3.0 * (1.0 - exp(-1.0 / 3.0)), "bruto +100% -> 3 x (1 - e^(-1/3)) = +85.0%")
	_check_near(EconomyMath.loot_bonus_effective(1.0, 3.0), 0.8504060683, "bruto +100% -> ~+85.04%", 1e-9)
	_check_near(EconomyMath.loot_bonus_effective(0.6, 3.0), 0.5438077408, "bruto +60% (un legendario) -> ~+54.4%", 1e-9)
	_check_near(EconomyMath.loot_bonus_effective(3.0, 3.0), 3.0 * (1.0 - exp(-1.0)), "bruto +300% -> solo ~+189.6%", 1e-9)
	_check_near(EconomyMath.loot_bonus_effective(0.01, 3.0), 0.01, "con poco bonus es casi 1 a 1 (+1% bruto ~ +1%)", 2e-3)
	_check(EconomyMath.loot_bonus_effective(0.01, 3.0) < 0.01, "pero nunca rinde más que el bruto")
	var previous: float = 0.0
	var increasing: bool = true
	var below_gross: bool = true
	var gains: Array[float] = []
	for step: int in range(1, 41):
		var raw: float = step * 0.5
		var effective: float = EconomyMath.loot_bonus_effective(raw, 3.0)
		if not (effective > previous):
			increasing = false
		if effective >= raw:
			below_gross = false
		gains.append(effective - previous)
		previous = effective
	_check(increasing, "más bruto siempre da más efectivo (hasta 20 de bruto)")
	_check(below_gross, "el efectivo queda siempre por debajo del bruto")
	var shrinking: bool = true
	for i: int in range(1, gains.size()):
		if gains[i] >= gains[i - 1]:
			shrinking = false
	_check(shrinking, "cada +50% de bruto agrega menos que el anterior (rendimientos decrecientes)")
	_check(EconomyMath.loot_bonus_effective(100.0, 3.0) <= 3.0, "el techo de +300% no se pasa (bruto 100)")
	_check_near(EconomyMath.loot_bonus_effective(100.0, 3.0), 3.0, "y con mucho bruto se acerca al techo (bruto 100 -> +300%)", 1e-9)
	_check_eq(EconomyMath.loot_bonus_effective(1.0e6, 3.0), 3.0, "con un bruto absurdo (1e6) queda justo en el techo")
	_check_eq(EconomyMath.loot_bonus_effective(INF, 3.0), 3.0, "infinito -> techo")
	_check_near(EconomyMath.loot_bonus_effective(1.0, 5.0), 5.0 * (1.0 - exp(-1.0 / 5.0)), "el techo sale del parámetro: con 5 es otra curva")
	_check_eq(EconomyMath.loot_bonus_effective(-0.5, 3.0), 0.0, "un bruto negativo -> 0")
	_check_eq(EconomyMath.loot_bonus_effective(NAN, 3.0), 0.0, "NaN -> 0")
	_check_eq(EconomyMath.loot_bonus_effective(1.0, 0.0), 0.0, "un techo de 0 -> 0 (sin dividir por cero)")
	_check_eq(EconomyMath.loot_bonus_effective(1.0, -3.0), 0.0, "un techo negativo -> 0")


func _test_offline_seconds() -> void:
	_section("Tiempo offline acreditable (tope de 8 h)")
	var cap: float = 8.0 * 3600.0
	_check_eq(EconomyMath.offline_seconds(0.0, cap), 0.0, "0 s -> 0")
	_check_eq(EconomyMath.offline_seconds(90.0, cap), 90.0, "90 s -> 90")
	_check_eq(EconomyMath.offline_seconds(cap, cap), cap, "justo 8 h -> 8 h")
	_check_eq(EconomyMath.offline_seconds(cap + 1.0, cap), cap, "8 h y 1 s -> se corta en 8 h")
	_check_eq(EconomyMath.offline_seconds(30.0 * 86400.0, cap), cap, "30 días fuera -> 8 h")
	_check_eq(EconomyMath.offline_seconds(-500.0, cap), 0.0, "reloj atrasado (negativo) -> 0")
	_check_eq(EconomyMath.offline_seconds(NAN, cap), 0.0, "NaN -> 0")
	_check_eq(EconomyMath.offline_seconds(INF, cap), cap, "infinito -> tope")


## Valida la estructura y la coherencia del balance, no los valores exactos:
## así se puede ajustar el balance sin tocar el test.
func _test_balance_file() -> void:
	_section("data/balance.json")
	_check(FileAccess.file_exists(BALANCE_PATH), "existe " + BALANCE_PATH)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BALANCE_PATH))
	_check(parsed is Dictionary, "es un objeto JSON válido")
	if not (parsed is Dictionary):
		return
	var balance: Dictionary = parsed
	_check(float(balance.get("cost_growth", 0.0)) > 1.0, "cost_growth > 1")
	var generators: Array = balance.get("generators", [])
	_check_eq(generators.size(), 5, "hay 5 generadores")
	var coherent: bool = true
	var previous_rate: float = 0.0
	var previous_cost: float = 0.0
	var ids: Dictionary = {}
	for entry: Variant in generators:
		var gen: Dictionary = entry
		var rate: float = float(gen.get("base_rate", 0.0))
		var cost: float = float(gen.get("base_cost", 0.0))
		var id: String = str(gen.get("id", ""))
		if id == "" or ids.has(id) or str(gen.get("name", "")) == "" or rate <= previous_rate or cost <= previous_cost:
			coherent = false
		ids[id] = true
		previous_rate = rate
		previous_cost = cost
	_check(coherent, "ids únicos, nombres presentes, y oro/s y costo base estrictamente crecientes")
	var pick: Dictionary = balance.get("pick", {})
	for key: String in ["power_base", "cost_base", "cost_growth", "passive_share"]:
		_check(float(pick.get(key, 0.0)) > 0.0, "pick.%s > 0" % key)
