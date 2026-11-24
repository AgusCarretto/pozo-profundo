extends "res://tests/test_base.gd"
## Tests headless del estado de core/economy.gd (oro, generadores, pico, señales, serialización).
##
## Cada test crea su propia instancia de Economy SIN agregarla al árbol: así no corre
## _ready(), no toca el disco y no se registra en el autoload Save.

const EconomyScript := preload("res://core/economy.gd")
const EconomyMath := preload("res://core/economy_math.gd")
const BuyMode := EconomyScript.BuyMode

## Balance chico y fijo, independiente de data/balance.json (que se puede ajustar libremente).
const TEST_BALANCE: Dictionary = {
	"cost_growth": 1.15,
	"generators": [
		{ "id": "a", "name": "A", "base_rate": 1, "base_cost": 15 },
		{ "id": "b", "name": "B", "base_rate": 8, "base_cost": 120 },
	],
	"pick": { "power_base": 2, "cost_base": 50, "cost_growth": 6, "passive_share": 0.03 },
}

var _nodes: Array[Node] = []


func _initialize() -> void:
	_test_initial_state()
	_test_hit()
	_test_buy_one()
	_test_buy_ten()
	_test_buy_max()
	_test_gold_never_negative()
	_test_gold_per_second_and_hit_value()
	_test_pick_upgrade()
	_test_tick()
	_test_serialization_round_trip()
	_test_from_dict_tolerates_garbage()
	_test_load_balance_validation()
	_test_real_balance_file()
	_test_tick_realtime()
	await _test_slow_frames_still_credit_real_time()
	for node: Node in _nodes:
		node.free()
	_finish()


func _make() -> EconomyScript:
	var economy: EconomyScript = EconomyScript.new()
	_nodes.append(economy)
	var ok: bool = economy.load_balance(TEST_BALANCE)
	if not ok:
		printerr("    el balance de prueba no cargó")
	return economy


func _test_initial_state() -> void:
	_section("Estado inicial")
	var e: EconomyScript = _make()
	_check_eq(e.generator_count(), 2, "2 generadores")
	_check_eq(e.gold, 0.0, "oro 0")
	_check_eq(e.pick_level, 0, "pico nivel 0")
	_check_eq(e.owned_count(0), 0, "0 unidades del generador 0")
	_check_eq(e.gold_per_second(), 0.0, "0 oro/s")
	_check_eq(e.hit_value(), 1.0, "un golpe vale 1")
	_check_eq(e.generator_name(1), "B", "nombre del generador 1")


func _test_hit() -> void:
	_section("Golpe")
	var e: EconomyScript = _make()
	var hits: Array[float] = []
	var golds: Array[float] = []
	e.hit_landed.connect(func(amount: float) -> void: hits.append(amount))
	e.gold_changed.connect(func(gold: float) -> void: golds.append(gold))
	var gained: float = e.hit()
	_check_eq(gained, 1.0, "hit() devuelve lo ganado")
	_check_eq(e.gold, 1.0, "el oro sube 1")
	_check_eq(hits, [1.0] as Array[float], "emite hit_landed(1)")
	_check_eq(golds, [1.0] as Array[float], "emite gold_changed(1)")


func _test_buy_one() -> void:
	_section("Compra x1")
	var e: EconomyScript = _make()
	var bought: Array[Vector2i] = []
	e.generator_bought.connect(func(index: int, count: int) -> void: bought.append(Vector2i(index, count)))
	_check_eq(e.buy_generator(0, BuyMode.X1), 0, "sin oro no compra")
	_check_eq(e.owned_count(0), 0, "sigue en 0")
	_check_eq(bought.size(), 0, "no emite señal si no compra")
	e.gold = 14.99
	_check_eq(e.buy_generator(0, BuyMode.X1), 0, "con 14.99 no alcanza")
	e.gold = 15.0
	_check_eq(e.buy_generator(0, BuyMode.X1), 1, "con 15 compra 1")
	_check_eq(e.gold, 0.0, "gasta exactamente 15")
	_check_eq(e.owned_count(0), 1, "tiene 1")
	_check_eq(bought, [Vector2i(0, 1)] as Array[Vector2i], "emite generator_bought(0, 1)")
	_check_eq(e.buy_generator(99, BuyMode.X1), 0, "índice inexistente no compra (ni explota)")
	_check_eq(e.buy_generator(-1, BuyMode.X1), 0, "índice negativo no compra (ni explota)")


func _test_buy_ten() -> void:
	_section("Compra x10")
	var e: EconomyScript = _make()
	var ten_cost: float = EconomyMath.bulk_cost(15.0, 1.15, 0, 10)
	e.gold = ten_cost - 0.01
	_check_eq(e.buy_generator(0, BuyMode.X10), 0, "con 1 centavo menos no compra ninguno (todo o nada)")
	_check_eq(e.owned_count(0), 0, "no compró parcial")
	e.gold = ten_cost + 0.01
	_check_eq(e.buy_generator(0, BuyMode.X10), 10, "con lo justo compra 10")
	_check_eq(e.owned_count(0), 10, "tiene 10")
	_check_near(e.gold, 0.01, "descuenta el costo de 10 juntos", 1e-6)
	var quote: Dictionary = e.quote(0, BuyMode.X10)
	_check_eq(quote["count"], 10, "quote x10 -> count 10")
	_check_near(quote["cost"], EconomyMath.bulk_cost(15.0, 1.15, 10, 10), "quote x10 -> costo desde 10 unidades")
	_check_eq(quote["affordable"], false, "quote x10 -> no alcanza")


func _test_buy_max() -> void:
	_section("Compra máxima")
	var e: EconomyScript = _make()
	var broke: Dictionary = e.quote(0, BuyMode.MAX)
	_check_eq(broke["count"], 1, "sin oro, Máx muestra el costo de 1 ...")
	_check_eq(broke["cost"], 15.0, "... que es 15 ...")
	_check_eq(broke["affordable"], false, "... y no alcanza")
	_check_eq(e.buy_generator(0, BuyMode.MAX), 0, "Máx sin oro no compra")

	e.gold = 1000.0
	var expected: int = EconomyMath.max_affordable(15.0, 1.15, 0, 1000.0)
	var quote: Dictionary = e.quote(0, BuyMode.MAX)
	_check_eq(quote["count"], expected, "quote Máx = max_affordable (%d)" % expected)
	_check_eq(quote["affordable"], true, "quote Máx alcanza")
	var spent_before: float = e.gold
	_check_eq(e.buy_generator(0, BuyMode.MAX), expected, "Máx compra %d" % expected)
	_check_eq(e.owned_count(0), expected, "tiene %d" % expected)
	_check(e.gold >= 0.0, "el oro no queda negativo")
	_check(e.gold < EconomyMath.bulk_cost(15.0, 1.15, expected, 1), "con lo que sobra no alcanza para 1 más")
	_check_near(spent_before - e.gold, EconomyMath.bulk_cost(15.0, 1.15, 0, expected), "gastó el costo de %d" % expected)


## Secuencia larga de compras en modos mezclados: el oro nunca baja de 0 y siempre
## coincide con (oro inicial - suma de costos pagados).
func _test_gold_never_negative() -> void:
	_section("Invariante: el oro nunca es negativo")
	var e: EconomyScript = _make()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	var modes: Array[int] = [BuyMode.X1, BuyMode.X10, BuyMode.MAX]
	var always_non_negative: bool = true
	var ledger_ok: bool = true
	var expected_gold: float = 0.0
	for step: int in range(400):
		var income: float = rng.randf_range(0.0, 5000.0) * pow(1.02, step)
		e.gold += income
		expected_gold += income
		var index: int = rng.randi_range(0, 1)
		var mode: int = modes[rng.randi_range(0, 2)]
		var base_cost: float = 15.0 if index == 0 else 120.0
		var owned_before: int = e.owned_count(index)
		var count: int = e.buy_generator(index, mode)
		expected_gold -= EconomyMath.bulk_cost(base_cost, 1.15, owned_before, count)
		if e.gold < 0.0:
			always_non_negative = false
		if absf(e.gold - expected_gold) > maxf(absf(expected_gold) * 1e-9, 1e-6):
			ledger_ok = false
			expected_gold = e.gold # no arrastrar el error a los pasos siguientes
	_check(always_non_negative, "400 compras mezcladas: el oro nunca fue negativo")
	_check(ledger_ok, "el oro coincide con ingresos - costos pagados en cada paso")
	_check(e.owned_count(0) + e.owned_count(1) > 50, "la secuencia sí compró bastante (%d unidades)" % (e.owned_count(0) + e.owned_count(1)))


func _test_gold_per_second_and_hit_value() -> void:
	_section("Oro por segundo y valor del golpe")
	var e: EconomyScript = _make()
	e.owned[0] = 10
	e.owned[1] = 5
	_check_eq(e.gold_per_second(), 50.0, "10*1 + 5*8 = 50 oro/s")
	_check_eq(e.generator_output(1), 40.0, "el generador 1 aporta 40/s")
	_check_near(e.hit_value(), 2.5, "golpe = 1 + 3% de 50")
	e.multiplier = 2.0
	_check_eq(e.gold_per_second(), 100.0, "el multiplicador duplica el oro/s")
	_check_near(e.hit_value(), 2.0 + 3.0, "golpe con mult 2 = 2*1 + 3% de 100")


func _test_pick_upgrade() -> void:
	_section("Mejora del pico")
	var e: EconomyScript = _make()
	var levels: Array[int] = []
	e.pick_upgraded.connect(func(level: int) -> void: levels.append(level))
	_check_eq(e.pick_cost(), 50.0, "primer nivel cuesta 50")
	e.gold = 49.0
	_check_eq(e.upgrade_pick(), false, "con 49 no se puede")
	_check_eq(e.pick_level, 0, "sigue en nivel 0")
	e.gold = 50.0
	_check_eq(e.upgrade_pick(), true, "con 50 sí")
	_check_eq(e.gold, 0.0, "gasta 50")
	_check_eq(e.pick_level, 1, "nivel 1")
	_check_eq(e.pick_cost(), 300.0, "el siguiente cuesta 300")
	_check_eq(e.hit_value(), 2.0, "el golpe vale 2")
	_check_eq(levels, [1] as Array[int], "emite pick_upgraded(1)")


func _test_tick() -> void:
	_section("Producción pasiva (tick)")
	var e: EconomyScript = _make()
	var changes: Array[float] = []
	e.gold_changed.connect(func(gold: float) -> void: changes.append(gold))
	e.tick(1.0)
	_check_eq(e.gold, 0.0, "sin generadores no produce")
	_check_eq(changes.size(), 0, "y no emite gold_changed")
	e.owned[0] = 10
	e.owned[1] = 5
	e.tick(0.5)
	_check_eq(e.gold, 25.0, "50 oro/s * 0.5 s = 25")
	_check_eq(changes, [25.0] as Array[float], "emite gold_changed(25)")
	e.tick(0.0)
	_check_eq(e.gold, 25.0, "delta 0 no cambia nada")
	e.tick(-1.0)
	_check_eq(e.gold, 25.0, "delta negativo se ignora")


func _test_serialization_round_trip() -> void:
	_section("to_dict / from_dict")
	var a: EconomyScript = _make()
	a.gold = 1.2345678901234567e45
	a.owned[0] = 12
	a.owned[1] = 3
	a.pick_level = 4
	var data: Dictionary = a.to_dict()
	var b: EconomyScript = _make()
	b.from_dict(data)
	_check_eq(b.gold, a.gold, "el oro se conserva exacto (1.2345678901234567e45)")
	_check_eq(b.owned_count(0), 12, "generador 0")
	_check_eq(b.owned_count(1), 3, "generador 1")
	_check_eq(b.pick_level, 4, "pico")


## Un save viejo, editado a mano o dañado nunca debe dejar el estado inválido.
func _test_from_dict_tolerates_garbage() -> void:
	_section("from_dict tolerante a datos raros")
	var e: EconomyScript = _make()
	e.from_dict({})
	_check_eq(e.gold, 0.0, "diccionario vacío -> oro 0")
	_check_eq(e.pick_level, 0, "diccionario vacío -> pico 0")
	e.from_dict({ "gold": -500.0, "pick_level": -3, "owned": [-1, 5] })
	_check_eq(e.gold, 0.0, "oro negativo -> 0")
	_check_eq(e.pick_level, 0, "nivel negativo -> 0")
	_check_eq(e.owned_count(0), 0, "cantidad negativa -> 0")
	_check_eq(e.owned_count(1), 5, "las demás cantidades se respetan")
	e.from_dict({ "gold": "mucho", "pick_level": "alto", "owned": "nada" })
	_check_eq(e.gold, 0.0, "oro de tipo string -> 0")
	_check_eq(e.pick_level, 0, "nivel de tipo string -> 0")
	_check_eq(e.owned_count(1), 0, "owned de tipo string -> todo 0")
	e.from_dict({ "gold": NAN, "owned": [INF, 2] })
	_check_eq(e.gold, 0.0, "oro NaN -> 0")
	_check_eq(e.owned_count(0), 0, "cantidad infinita -> 0")
	e.from_dict({ "owned": [7] })
	_check_eq(e.owned_count(0), 7, "save con menos generadores que el balance: el existente se carga")
	_check_eq(e.owned_count(1), 0, "y el faltante queda en 0")
	e.from_dict({ "owned": [1, 2, 3, 4] })
	_check_eq(e.owned_count(1), 2, "save con más generadores que el balance: se descartan los sobrantes")
	_check_eq(e.generator_count(), 2, "el balance no cambia")
	_check_eq(e.to_dict()["owned"].size(), 2, "to_dict devuelve exactamente un valor por generador")


func _test_load_balance_validation() -> void:
	_section("Validación del balance")
	var e: EconomyScript = _make()
	e.gold = 99.0
	var no_generators: Dictionary = TEST_BALANCE.duplicate(true)
	no_generators["generators"] = []
	_check_eq(e.load_balance(no_generators), false, "sin generadores -> inválido")
	var flat_growth: Dictionary = TEST_BALANCE.duplicate(true)
	flat_growth["cost_growth"] = 1.0
	_check_eq(e.load_balance(flat_growth), false, "crecimiento <= 1 -> inválido")
	_check(e.last_error.contains("cost_growth"), "last_error explica el motivo (%s)" % e.last_error)
	var free_generator: Dictionary = TEST_BALANCE.duplicate(true)
	free_generator["generators"][0]["base_cost"] = 0
	_check_eq(e.load_balance(free_generator), false, "costo base 0 -> inválido")
	var no_pick: Dictionary = TEST_BALANCE.duplicate(true)
	no_pick.erase("pick")
	_check_eq(e.load_balance(no_pick), false, "sin sección pick -> inválido")
	_check_eq(e.generator_count(), 2, "un balance inválido no pisa el anterior")
	_check_eq(e.gold, 99.0, "ni borra el estado")
	var three: Dictionary = TEST_BALANCE.duplicate(true)
	three["generators"].append({ "id": "c", "name": "C", "base_rate": 47, "base_cost": 1300 })
	_check_eq(e.load_balance(three), true, "un balance válido con 3 generadores carga")
	_check_eq(e.generator_count(), 3, "ahora hay 3")
	_check_eq(e.gold, 0.0, "cargar un balance reinicia el estado")


func _test_tick_realtime() -> void:
	_section("Producción según el reloj real (tick_realtime)")
	var e: EconomyScript = _make()
	e.owned[0] = 10 # 10 oro/s
	e.tick_realtime(1000000)
	_check_eq(e.gold, 0.0, "la primera llamada solo fija la referencia (no acredita el tiempo desde que arrancó el motor)")
	e.tick_realtime(3500000)
	_check_near(e.gold, 25.0, "2.5 s * 10 oro/s = 25")
	e.tick_realtime(3000000)
	_check_near(e.gold, 25.0, "un reloj que retrocede no suma ni resta")
	e.tick_realtime(4000000)
	_check_near(e.gold, 35.0, "y después de retroceder, la referencia es la nueva: 1 s más = +10")
	e.tick_realtime(4000000)
	_check_near(e.gold, 35.0, "dos llamadas con el mismo instante no suman nada")


## Godot recorta el delta de _process a ~0.13 s por frame. A pocos fps (celulares lentos,
## pestañas web en segundo plano) la cuadrilla produciría una fracción de lo que debe.
## Este test usa el autoload real y un frame de ~600 ms.
func _test_slow_frames_still_credit_real_time() -> void:
	_section("Frames lentos acreditan el tiempo real")
	var live: Node = root.get_node_or_null("Economy")
	_check(live != null, "existe el autoload Economy")
	if live == null:
		return
	# En modo --script los autoloads recién corren _ready() después del primer frame.
	await process_frame
	live.reset()
	live.owned[0] = 10 # 10 Mineros = 10 oro/s con el balance real
	await process_frame
	var gold_before: float = live.gold
	OS.delay_msec(600) # el frame siguiente tarda ~600 ms
	await process_frame
	await process_frame
	var gained: float = live.gold - gold_before
	_check(gained >= 5.0, "600 ms de frame lento acreditan ~6 de oro, no ~1.3 (ganó %.2f)" % gained)
	live.reset()


func _test_real_balance_file() -> void:
	_section("data/balance.json real")
	var e: EconomyScript = EconomyScript.new()
	_nodes.append(e)
	_check_eq(e.load_balance_file("res://data/balance.json"), true, "carga el balance real")
	_check_eq(e.generator_count(), 5, "5 generadores")
	_check_eq(e.generator_name(0), "Minero", "el primero es el Minero")
	_check_eq(e.load_balance_file("res://data/no_existe.json"), false, "un archivo inexistente devuelve false")
