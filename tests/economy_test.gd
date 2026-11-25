extends "res://tests/test_base.gd"
## Tests headless del estado de core/economy.gd (oro, generadores, pico, señales, serialización).
##
## Cada test crea su propia instancia de Economy SIN agregarla al árbol: así no corre
## _ready(), no toca el disco y no se registra en el autoload Save.

const EconomyScript := preload("res://core/economy.gd")
const EconomyMath := preload("res://core/economy_math.gd")
const BuyMode := EconomyScript.BuyMode
const TestBalance := preload("res://tests/test_balance.gd")

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
	_test_critical_hits()
	_test_milestones()
	_test_hidden_generators()
	_test_ability()
	_test_old_dynamite_crews_become_moles()
	_test_buy_one()
	_test_buy_ten()
	_test_buy_max()
	_test_gold_never_negative()
	_test_gold_per_second_and_hit_value()
	_test_pick_upgrade()
	_test_grant_gold()
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
	_check_eq(e.generator_id(0), "a", "id del generador 0 (la UI elige su arte por id)")
	_check_eq(e.generator_id(1), "b", "id del generador 1")
	_check_eq(e.generator_id(2), "", "un generador inexistente no tiene id (ni explota)")
	_check_eq(e.generator_id(-1), "", "un índice negativo tampoco")


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


func _test_critical_hits() -> void:
	_section("Golpes críticos")
	var sure: Dictionary = TEST_BALANCE.duplicate(true)
	sure["crit"] = { "chance": 1.0, "multiplier": 2.0 }
	var e: EconomyScript = _make()
	_check(e.load_balance(sure), "carga con la sección crit")
	var hits: Array[float] = []
	var flags: Array[bool] = []
	e.hit_landed.connect(func(amount: float) -> void:
		hits.append(amount)
		flags.append(e.last_hit_critical))
	_check_eq(e.hit(), 2.0, "un crítico vale el doble")
	_check_eq(e.gold, 2.0, "y eso es lo que entra")
	_check_eq(hits, [2.0] as Array[float], "hit_landed lleva el monto del crítico")
	_check_eq(flags, [true] as Array[bool], "y last_hit_critical ya está puesto al avisar")
	_check_eq(e.hit_value(), 1.0, "el 'Golpe' que se muestra es el normal")
	var never: EconomyScript = _make()
	never.hit()
	_check(never.gold == 1.0 and not never.last_hit_critical, "sin sección crit no hay críticos")
	var real: Dictionary = TEST_BALANCE.duplicate(true)
	real["crit"] = { "chance": 0.08, "multiplier": 2.0 }
	var often: EconomyScript = _make()
	often.load_balance(real)
	often.rng.seed = 7
	var crits: int = 0
	for i: int in range(20000):
		often.hit()
		if often.last_hit_critical:
			crits += 1
	_check(absf(crits - 1600.0) < 150.0, "8%% de chance: ~1600 de 20000 (%d)" % crits)
	_check_eq(often.gold, 20000.0 + crits, "cada crítico sumó un golpe de más")
	for bad: Dictionary in [{ "chance": 1.5, "multiplier": 2.0 }, { "chance": -0.1, "multiplier": 2.0 }, { "chance": 0.1, "multiplier": 0.5 }, { "chance": 0.1 }]:
		var broken: Dictionary = TEST_BALANCE.duplicate(true)
		broken["crit"] = bad
		_check_eq(often.load_balance(broken), false, "crit %s -> inválido" % str(bad))


func _test_milestones() -> void:
	_section("Hitos: con 25, 50 y 100 unidades ese generador produce el doble")
	var balance: Dictionary = TEST_BALANCE.duplicate(true)
	balance["milestones"] = { "at": [25, 50, 100], "multiplier": 2 }
	var e: EconomyScript = _make()
	_check(e.load_balance(balance), "carga con la sección milestones (%s)" % e.last_error)
	for pair: Array in [[0, 1.0, 25], [24, 1.0, 25], [25, 2.0, 50], [49, 2.0, 50], [50, 4.0, 100], [99, 4.0, 100], [100, 8.0, 0], [500, 8.0, 0]]:
		e.owned[0] = pair[0]
		_check_eq(e.milestone_multiplier(0), pair[1], "%d unidades -> x%d" % [pair[0], int(pair[1])])
		_check_eq(e.next_milestone(0), pair[2], "%d unidades -> próximo hito %d" % [pair[0], pair[2]])
	e.owned[0] = 25
	e.owned[1] = 2
	_check_eq(e.generator_output(0), 50.0, "25 x 1 oro/s x2 = 50")
	_check_eq(e.generator_output(1), 16.0, "el otro generador no cambia")
	_check_eq(e.gold_per_second(), 66.0, "y el total lo suma")
	var reached: Array[Vector2i] = []
	e.milestone_reached.connect(func(index: int, threshold: int) -> void: reached.append(Vector2i(index, threshold)))
	e.owned[0] = 20
	e.gold = 1.0e12
	e.buy_generator(0, BuyMode.X10)
	_check_eq(reached, [Vector2i(0, 25)] as Array[Vector2i], "x10 de 20 a 30 avisa el hito de 25 una vez")
	e.buy_generator(0, BuyMode.X1)
	_check_eq(reached.size(), 1, "comprar sin cruzar un hito no avisa")
	reached.clear()
	e.owned[0] = 0
	e.gold = EconomyMath.bulk_cost(15.0, 1.15, 0, 60) + 0.01
	e.buy_generator(0, BuyMode.MAX)
	_check_eq(reached, [Vector2i(0, 25), Vector2i(0, 50)] as Array[Vector2i], "Máx de 0 a 60 avisa los dos")
	var plain: EconomyScript = _make()
	plain.owned[0] = 100
	_check(plain.milestone_multiplier(0) == 1.0 and plain.next_milestone(0) == 0, "sin la sección no hay hitos")
	_check(e.milestone_multiplier(9) == 1.0 and e.next_milestone(-1) == 0, "un generador inexistente no explota")
	for bad: Variant in [{ "at": [], "multiplier": 2 }, { "at": [50, 25], "multiplier": 2 }, { "at": [0], "multiplier": 2 }, { "at": [25], "multiplier": 0.5 }, { "multiplier": 2 }, [25]]:
		var broken: Dictionary = TEST_BALANCE.duplicate(true)
		broken["milestones"] = bad
		_check_eq(plain.load_balance(broken), false, "milestones %s -> inválido" % str(bad))


func _test_hidden_generators() -> void:
	_section("Generadores ocultos hasta comprar el anterior")
	var balance: Dictionary = TestBalance.make(["loot"])
	balance["generators"].append({ "id": "c", "name": "C", "base_rate": 47, "base_cost": 1300 })
	var e: EconomyScript = _make()
	_check(e.load_balance(balance), "carga con 3 generadores (%s)" % e.last_error)
	var seen: Callable = func(economy: EconomyScript) -> Array:
		return [economy.is_generator_revealed(0), economy.is_generator_revealed(1), economy.is_generator_revealed(2)]
	_check_eq(seen.call(e), [true, false, false], "al empezar solo se ve el primero")
	e.gold = 1.0e6
	e.buy_generator(0, BuyMode.X1)
	_check_eq(seen.call(e), [true, true, false], "comprarlo revela el segundo")
	e.buy_generator(1, BuyMode.X1)
	_check_eq(seen.call(e), [true, true, true], "y así")
	e.run_gold = 1.0e9
	_check(e.prestige() > 0, "vuelve a la superficie")
	_check_eq(e.owned_count(1), 0, "sin cuadrilla")
	_check_eq(seen.call(e), [true, true, true], "pero lo revelado sigue a la vista")
	var loaded: EconomyScript = _make()
	loaded.load_balance(balance)
	loaded.from_dict(JSON.parse_string(JSON.stringify(e.to_dict())))
	_check_eq(seen.call(loaded), [true, true, true], "y se guarda")
	loaded.reset()
	_check_eq(seen.call(loaded), [true, false, false], "empezar de cero lo oculta")
	loaded.from_dict({ "owned": [3, 0, 0] })
	_check_eq(seen.call(loaded), [true, true, false], "una partida sin el dato muestra lo comprado y el siguiente")
	for garbage: Variant in ["todo", -5, NAN, 1.0e12]:
		var broken: EconomyScript = _make()
		broken.load_balance(balance)
		broken.from_dict({ "revealed": garbage })
		_check(broken.is_generator_revealed(0) and not broken.is_generator_revealed(3), "dato basura (%s): sin explotar" % str(garbage))
	_check(not e.is_generator_revealed(-1) and not e.is_generator_revealed(9), "un índice inexistente no está revelado")


const ABILITY: Dictionary = { "cooldown": 60, "seconds": 24, "step": 4, "hits": 50, "cost": 2000, "growth": 5, "max_level": 3, "reveal_with": "b" }


func _ability_economy() -> EconomyScript:
	var balance: Dictionary = TEST_BALANCE.duplicate(true)
	balance["ability"] = ABILITY
	balance["milestones"] = { "at": [25, 50, 100], "multiplier": 2 }
	var e: EconomyScript = _make()
	_check(e.load_balance(balance), "carga con la sección ability (%s)" % e.last_error)
	return e


func _test_ability() -> void:
	_section("Dinamita: una habilidad con recarga que da un golpe enorme")
	var e: EconomyScript = _ability_economy()
	_check(e.has_ability() and not e.ability_revealed(), "al empezar está oculta")
	e.gold = 1.0e6
	_check(not e.upgrade_ability(), "oculta no se compra")
	e.owned[0] = 1
	_check(e.ability_revealed(), "se revela junto con el segundo generador")
	_check_eq(e.ability_cost(), 2000.0, "el nivel 1 cuesta 2.000")
	_check(not e.ability_ready() and e.use_ability() == 0.0, "sin comprarla no se usa")
	var levels: Array[int] = []
	var used: Array[float] = []
	e.ability_upgraded.connect(func(level: int) -> void: levels.append(level))
	e.ability_used.connect(func(amount: float) -> void: used.append(amount))
	e.gold = 2000.0
	_check(e.upgrade_ability(), "se compra")
	_check(e.gold == 0.0 and e.ability_level == 1 and levels == [1], "gasta 2.000 y queda en nivel 1")
	_check_eq(e.ability_cost(), 10000.0, "el nivel 2 cuesta x5")
	_check_eq(e.ability_seconds(1), 24.0, "nivel 1: 24 s")
	_check_eq(e.ability_seconds(3), 32.0, "cada nivel suma 4 s")
	e.owned[0] = 0
	_check_eq(e.ability_reward(), 50.0, "sin cuadrilla paga por golpes (50 de 1)")
	e.owned[0] = 10
	e.owned[1] = 5 # 50 oro/s
	_check_near(e.ability_reward(), maxf(24.0 * 50.0, 50.0 * e.hit_value()), "con cuadrilla, 24 s de producción")
	_check(e.ability_ready(), "recién comprada está lista")
	var before: float = e.gold
	var reward: float = e.ability_reward()
	_check_eq(e.use_ability(), reward, "usarla devuelve lo que pagó")
	_check(e.gold == before + reward and e.run_gold >= reward and used == [reward], "entra en el acto y cuenta como ganado")
	_check(not e.ability_ready() and e.ability_cooldown_left == 60.0, "y queda recargando 60 s")
	_check_eq(e.use_ability(), 0.0, "recargando no hace nada")
	e.advance_ability(59.0)
	_check(not e.ability_ready(), "a los 59 s todavía no")
	e.advance_ability(5.0)
	_check(e.ability_ready() and e.ability_cooldown_left == 0.0, "después de 60 s vuelve")
	e.use_ability()
	e.tick_realtime(1000000)
	e.tick_realtime(31000000)
	_check_near(e.ability_cooldown_left, 30.0, "la recarga corre con el reloj real")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(e.to_dict()))
	var loaded: EconomyScript = _ability_economy()
	loaded.from_dict(saved)
	_check(loaded.ability_level == 1 and absf(loaded.ability_cooldown_left - 30.0) < 0.01, "el nivel y lo que falta de recarga se guardan (recargar la página no la saltea)")
	loaded.apply_offline_since(1000000, 1000100.0)
	_check_eq(loaded.ability_cooldown_left, 0.0, "el tiempo con el juego cerrado también recarga")
	e.gold = 1.0e12
	e.upgrade_ability()
	e.upgrade_ability()
	_check(e.ability_level == 3 and not e.upgrade_ability(), "no pasa del nivel máximo")
	e.run_gold = 1.0e12
	e.load_balance(TEST_BALANCE)
	_check(not e.has_ability() and not e.ability_revealed() and e.use_ability() == 0.0 and not e.upgrade_ability(), "sin la sección no hay habilidad")
	var real: EconomyScript = _ability_economy()
	real.from_dict({ "ability_level": 99, "ability_wait": 1.0e9, "owned": [1, 0] })
	_check(real.ability_level == 3 and real.ability_cooldown_left <= 60.0, "datos fuera de rango se topan")
	real.reset()
	_check(real.ability_level == 0 and real.ability_cooldown_left == 0.0, "al reiniciar la bajada vuelve a cero")
	var tiers: EconomyScript = _ability_economy()
	for pair: Array in [[0, 0], [24, 0], [25, 1], [50, 2], [100, 3], [400, 3]]:
		tiers.owned[0] = pair[0]
		_check_eq(tiers.milestone_tier(0), pair[1], "%d unidades -> aspecto %d" % pair)
	for bad: Dictionary in [{ "cooldown": 0 }, { "max_level": 0 }, { "growth": 0.5 }, { "hits": 0 }, { "reveal_with": "nadie" }]:
		var balance: Dictionary = TEST_BALANCE.duplicate(true)
		balance["ability"] = ABILITY.duplicate()
		balance["ability"].merge(bad, true)
		_check_eq(tiers.load_balance(balance), false, "ability %s -> inválido" % str(bad))


## Los testers tenían "Cuadrillas de dinamita": el Topo ocupa su lugar, así que se convierten en topos solos.
func _test_old_dynamite_crews_become_moles() -> void:
	_section("Las cuadrillas de dinamita de antes ahora son topos")
	var e: EconomyScript = EconomyScript.new()
	_nodes.append(e)
	e.load_balance_file("res://data/balance.json")
	e.from_dict({ "balance_version": 2, "gold": 10.0, "run_gold": 500000.0, "owned": [30, 12, 26, 4, 1], "revealed": 5 })
	_check_eq(e.generator_id(2), "mole", "el tercer puesto es el Topo")
	_check_eq(e.owned_count(2), 26, "26 cuadrillas de dinamita -> 26 topos")
	_check_eq([e.owned_count(3), e.owned_count(4), e.owned_count(5)], [4, 1, 0], "el resto no se corre y el Gusano arranca en 0")
	_check(e.is_generator_revealed(5) and e.ability_revealed() and e.ability_level == 0, "con la Excavadora ya ven el Gusano, y la Dinamita por comprar")


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
	# El multiplicador global ya no se asigna: lo da el bioma (acá, Roca = x1.5).
	var rocky: EconomyScript = _make()
	rocky.load_balance(TestBalance.make(["loot"]))
	rocky.owned[0] = 10
	rocky.owned[1] = 5
	rocky.run_gold = 700.0
	_check_eq(rocky.multiplier, 1.5, "en Roca el multiplicador es x1.5")
	_check_eq(rocky.gold_per_second(), 75.0, "el multiplicador escala el oro/s: 50 * 1.5")
	_check_near(rocky.hit_value(), 1.5 + 0.03 * 75.0, "golpe con mult 1.5 = 1*1.5 + 3% de 75")


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


## Oro que entra de afuera (anuncio con recompensa, herramientas de debug): cuenta como ganado.
func _test_grant_gold() -> void:
	_section("grant_gold")
	var e: EconomyScript = _make()
	e.load_balance(TestBalance.make(["loot"])) # con profundidad, para ver que baja
	var golds: Array[float] = []
	e.gold_changed.connect(func(gold: float) -> void: golds.append(gold))
	e.grant_gold(1000.0)
	_check_eq(e.gold, 1000.0, "suma al oro")
	_check_eq(e.run_gold, 1000.0, "y al oro ganado de la partida (cuenta para la profundidad)")
	_check_eq(golds, [1000.0] as Array[float], "emite gold_changed una vez con el oro final")
	_check(e.depth() > 150.0, "y te hace bajar (%.0f m)" % e.depth())
	e.grant_gold(0.0)
	e.grant_gold(-50.0)
	e.grant_gold(NAN)
	_check_eq(e.gold, 1000.0, "0, negativos y NaN no hacen nada")
	_check_eq(golds.size(), 1, "ni emiten señales")


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
	_check_eq(e.generator_count(), 6, "6 generadores")
	_check_eq(e.generator_name(0), "Minero", "el primero es el Minero")
	var ids: Array[String] = []
	for index: int in range(e.generator_count()):
		ids.append(e.generator_id(index))
	_check_eq(ids, ["miner", "steam_drill", "mole", "stone_golem", "rune_excavator", "abyss_worm"] as Array[String], "los ids del balance real, en orden")
	# El ritmo del juego (partidas largas): precios altos y cuadrilla que rinde poco; el pico no se recorta.
	var rates: Array[float] = []
	var costs: Array[float] = []
	for index: int in range(e.generator_count()):
		e.owned.fill(0)
		costs.append(e.quote(index, EconomyScript.BuyMode.X1)["cost"])
		e.owned[index] = 1
		rates.append(e.gold_per_second())
	e.owned.fill(0)
	_check_eq(rates, [1.0, 5.0, 25.0, 120.0, 600.0, 3000.0] as Array[float], "los generadores caros rinden menos")
	_check_eq(costs, [25.0, 600.0, 10000.0, 180000.0, 3000000.0, 50000000.0] as Array[float], "y cuesta bastante más")
	e.owned[0] = 1
	_check_near(e.quote(0, EconomyScript.BuyMode.X1)["cost"], 25.0 * 1.15, "cada unidad cuesta 15% más que la anterior")
	e.owned[0] = 0
	_check_eq(e.pick_cost(), 150.0, "el pico arranca en 150")
	e.pick_level = 1
	_check_eq(e.pick_cost(), 1800.0, "y la segunda mejora cuesta 150 x 12")
	_check_near(e.hit_value(), 2.0, "un golpe en nivel 1 sigue valiendo 2")
	e.owned[1] = 1
	_check_near(e.hit_value(), 2.0 + 0.06 * 5.0, "más el 6% del oro/s: la cuadrilla rinde menos pero el golpe no")
	e.owned[1] = 0
	e.pick_level = 0
	_check_eq(e.load_balance_file("res://data/no_existe.json"), false, "un archivo inexistente devuelve false")
