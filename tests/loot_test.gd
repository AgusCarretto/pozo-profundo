extends "res://tests/test_base.gd"
## Tests headless del botín de core/economy.gd: cofres por golpe y pasivos, rarezas y el oro que dan.
##
## Un cofre paga oro al instante: el mayor entre `seconds` de producción de la cuadrilla y `hits` golpes. Una
## rareza puede dar además reliquias. Cada test crea su propia instancia de Economy SIN agregarla al árbol; para
## no depender del azar se usan probabilidades 0 / 1 y la distribución se mide con una semilla fija.

const EconomyScript := preload("res://core/economy.gd")
const TestBalance := preload("res://tests/test_balance.gd")

var _nodes: Array[Node] = []


func _initialize() -> void:
	_test_probability_table()
	_test_chances_are_exposed()
	_test_reward_is_the_best_of_two()
	_test_hit_drops_a_chest()
	_test_drop_loot_directly()
	_test_relic_chest()
	_test_hit_without_chest()
	_test_passive_chest_needs_a_crew()
	_test_passive_chance_scales_with_time()
	_test_hit_chance_statistics()
	_test_rarity_distribution()
	_test_old_bonus_is_gone()
	_test_no_loot_section()
	_test_balance_validation()
	_test_real_balance_file()
	for node: Node in _nodes:
		node.free()
	_finish()


## `tweak` recibe la sección "loot" para ajustarla antes de cargar el balance.
func _make(tweak: Callable = Callable()) -> EconomyScript:
	var balance: Dictionary = TestBalance.make()
	if tweak.is_valid():
		tweak.call(balance["loot"])
	var economy: EconomyScript = EconomyScript.new()
	_nodes.append(economy)
	if not economy.load_balance(balance):
		printerr("    el balance de prueba no cargó: ", economy.last_error)
	economy.rng.seed = 12345
	return economy


## Un solo tipo de cofre (5 s de producción o 15 golpes) que sale siempre que hay tirada.
func _always(chance_per_hit: float, chance_per_second: float) -> Callable:
	return func(loot: Dictionary) -> void:
		loot["chance_per_hit"] = chance_per_hit
		loot["chance_per_second"] = chance_per_second
		loot["rarities"] = [{ "id": "only", "name": "Único", "weight": 1, "seconds": 5, "hits": 15, "relics": 0 }]


## Anota los cofres que caen: [{rarity, amount}].
func _watch(e: EconomyScript) -> Array[Dictionary]:
	var drops: Array[Dictionary] = []
	e.loot_dropped.connect(func(rarity: int, amount: float) -> void: drops.append({ "rarity": rarity, "amount": amount }))
	return drops


func _test_probability_table() -> void:
	_section("Tabla de probabilidades y premios (la que ve el jugador)")
	var table: Array[Dictionary] = _make().loot_table()
	_check_eq(table.size(), 4, "4 rarezas")
	var expected: Array = [["Común", 0.78, 5.0, 15.0, 0], ["Raro", 0.17, 20.0, 50.0, 0], ["Épico", 0.045, 60.0, 150.0, 0], ["Legendario", 0.005, 200.0, 500.0, 1]]
	for index: int in range(mini(table.size(), expected.size())):
		var entry: Dictionary = table[index]
		var want: Array = expected[index]
		_check_eq(entry["name"], want[0], "%s en el lugar %d" % [want[0], index])
		_check_near(entry["chance"], want[1], "%s: %.1f%%" % [want[0], want[1] * 100.0])
		_check_eq([entry["seconds"], entry["hits"], entry["relics"]], [want[2], want[3], want[4]], "%s: segundos, golpes y reliquias" % want[0])
	# Los pesos no tienen que sumar 100: la probabilidad es peso / total.
	var odd: EconomyScript = _make(func(loot: Dictionary) -> void:
		loot["rarities"] = [
			{ "id": "a", "name": "A", "weight": 3, "seconds": 1, "hits": 1, "relics": 0 },
			{ "id": "b", "name": "B", "weight": 1, "seconds": 2, "hits": 2, "relics": 0 },
		])
	_check_near(odd.loot_table()[0]["chance"], 0.75, "pesos 3 y 1 -> 75%")
	_check_near(odd.loot_table()[1]["chance"], 0.25, "pesos 3 y 1 -> 25%")


func _test_chances_are_exposed() -> void:
	_section("Probabilidad de cofre")
	var e: EconomyScript = _make()
	_check_eq(e.loot_chance_per_hit(), 0.015, "por golpe")
	_check_eq(e.loot_chance_per_second(), 0.005, "por segundo con cuadrilla")


func _test_reward_is_the_best_of_two() -> void:
	_section("El premio: lo que más sea entre segundos de cuadrilla y golpes")
	var e: EconomyScript = _make()
	_check_eq(e.loot_reward(0), 15.0, "sin cuadrilla paga por golpes: 15 golpes de 1")
	_check_eq(e.loot_reward(3), 500.0, "el legendario: 500 golpes")
	e.owned[0] = 10 # 10 oro/s; el golpe vale 1 + 3% = 1.3
	_check_near(e.loot_reward(0), 50.0, "con cuadrilla: 5 s = 50 le ganan a 15 golpes = 19.5")
	e.pick_level = 6 # golpe = 64.3
	_check_near(e.loot_reward(0), 15.0 * 64.3, "con un pico fuerte ganan los golpes")
	_check_eq(e.loot_reward(99), 0.0, "una rareza inexistente no paga")
	_check_eq(e.loot_reward(-1), 0.0, "ni un índice negativo")


func _test_hit_drops_a_chest() -> void:
	_section("Un golpe con cofre seguro")
	var e: EconomyScript = _make(_always(1.0, 0.0))
	var drops: Array[Dictionary] = _watch(e)
	var golds: Array[float] = []
	var hits: Array[float] = []
	e.gold_changed.connect(func(gold: float) -> void: golds.append(gold))
	e.hit_landed.connect(func(amount: float) -> void: hits.append(amount))
	e.gold = 1000.0
	_check_eq(e.hit(), 1.0, "hit() devuelve el oro del golpe (1), sin el del cofre")
	_check_eq(hits, [1.0] as Array[float], "hit_landed(1)")
	_check_eq(drops.size(), 1, "cae 1 cofre")
	_check_eq(drops[0], { "rarity": 0, "amount": 15.0 }, "y avisa cuánto pagó")
	_check_eq(e.gold, 1016.0, "el oro entra en el acto: golpe + cofre")
	_check_eq(e.run_gold, 16.0, "y cuenta como ganado (te hace bajar)")
	_check_eq(golds, [1016.0] as Array[float], "gold_changed una sola vez, con el oro final")
	_check_eq(e.multiplier, 1.0, "no cambia ningún multiplicador")


func _test_drop_loot_directly() -> void:
	_section("drop_loot(): cofre de una rareza (sorteo y panel de debug)")
	var e: EconomyScript = _make()
	var drops: Array[Dictionary] = _watch(e)
	var golds: Array[float] = []
	e.gold_changed.connect(func(gold: float) -> void: golds.append(gold))
	e.drop_loot(1)
	_check_eq(drops, [{ "rarity": 1, "amount": 50.0 }] as Array[Dictionary], "emite loot_dropped con la rareza y el oro")
	_check_eq(e.gold, 50.0, "suma el oro")
	_check_eq(golds, [50.0] as Array[float], "y emite gold_changed")
	e.drop_loot(99)
	e.drop_loot(-1)
	_check_eq(drops.size(), 1, "una rareza inexistente no hace nada (ni explota)")
	_check_eq(e.gold, 50.0, "ni da oro")


func _test_relic_chest() -> void:
	_section("El legendario además da una reliquia")
	var e: EconomyScript = _make()
	e.owned[0] = 10
	var drops: Array[Dictionary] = _watch(e)
	e.drop_loot(3)
	_check_eq(e.relics, 1, "1 reliquia")
	_check_near(drops[0]["amount"], 2000.0, "el oro se calcula antes de sumarla (200 s x 10)")
	_check_near(e.relic_multiplier(), 1.25, "y desde ahí multiplica el oro")
	e.drop_loot(0)
	_check_eq(e.relics, 1, "un común no da reliquias")
	e.run_gold = 1.0e9
	e.prestige()
	_check(e.relics >= 1, "la del cofre sobrevive a volver a la superficie")


func _test_hit_without_chest() -> void:
	_section("Golpe sin cofre")
	var e: EconomyScript = _make(_always(0.0, 0.0))
	var drops: Array[Dictionary] = _watch(e)
	for i: int in range(500):
		e.hit()
	_check_eq(drops.size(), 0, "con probabilidad 0 nunca cae un cofre (500 golpes)")
	_check_eq(e.gold, 500.0, "el oro es solo de los golpes")


func _test_passive_chest_needs_a_crew() -> void:
	_section("Cofre pasivo: solo si hay cuadrilla")
	var e: EconomyScript = _make(_always(0.0, 1.0))
	var drops: Array[Dictionary] = _watch(e)
	e.tick(1.0)
	_check_eq(drops.size(), 0, "sin cuadrilla no hay cofres pasivos")
	_check_eq(e.gold, 0.0, "ni oro")
	e.owned[0] = 10 # 10 oro/s
	var golds: Array[float] = []
	e.gold_changed.connect(func(gold: float) -> void: golds.append(gold))
	e.tick(1.0)
	_check_eq(drops.size(), 1, "con cuadrilla y 100% por segundo cae 1 cofre")
	_check_near(e.gold, 60.0, "producción (10) + cofre (5 s = 50)")
	_check_eq(golds.size(), 1, "una sola señal gold_changed por tick")
	e.tick(0.0)
	_check_eq(drops.size(), 1, "un tick de 0 s no tira ningún cofre")


## 2% por segundo se reparte según el tiempo del tick: 0.1 s de tick = 1 - 0.98^0.1 de chance.
func _test_passive_chance_scales_with_time() -> void:
	_section("El cofre pasivo escala con el tiempo")
	var e: EconomyScript = _make(_always(0.0, 0.02))
	e.owned[0] = 1
	var drops: Array[Dictionary] = _watch(e)
	for i: int in range(100000): # 10.000 s en ticks de 0.1 s -> ~202 cofres esperados
		e.tick(0.1)
	var expected: float = 100000.0 * (1.0 - pow(0.98, 0.1))
	_check(absf(drops.size() - expected) < 60.0, "~%.0f cofres en 10.000 s de ticks cortos (salieron %d)" % [expected, drops.size()])
	var slow: EconomyScript = _make(_always(0.0, 0.02))
	slow.owned[0] = 1
	var slow_drops: Array[Dictionary] = _watch(slow)
	for i: int in range(1000): # los mismos 10.000 s, en ticks de 10 s (un frame muy lento)
		slow.tick(10.0)
	var slow_expected: float = 1000.0 * (1.0 - pow(0.98, 10.0))
	_check(absf(slow_drops.size() - slow_expected) < 40.0, "~%.0f cofres en ticks de 10 s (salieron %d): la chance crece con el delta" % [slow_expected, slow_drops.size()])


func _test_hit_chance_statistics() -> void:
	_section("1,5% de cofre por golpe")
	var e: EconomyScript = _make()
	var drops: Array[Dictionary] = _watch(e)
	var total: int = 20000
	for i: int in range(total):
		e.hit()
	var expected: float = total * 0.015
	_check(absf(drops.size() - expected) < 70.0, "~%.0f cofres en %d golpes (salieron %d)" % [expected, total, drops.size()])


func _test_rarity_distribution() -> void:
	_section("Distribución de rarezas 78 / 17 / 4,5 / 0,5")
	var e: EconomyScript = _make(func(loot: Dictionary) -> void: loot["chance_per_hit"] = 1.0)
	var counts: Array[int] = [0, 0, 0, 0]
	e.loot_dropped.connect(func(rarity: int, _amount: float) -> void: counts[rarity] += 1)
	var total: int = 20000
	for i: int in range(total):
		e.hit()
	_check_eq(counts[0] + counts[1] + counts[2] + counts[3], total, "cada golpe dio un cofre (%d)" % total)
	_check(absf(counts[0] - 15600.0) < 300.0, "Común ~78%% (%d de %d)" % [counts[0], total])
	_check(absf(counts[1] - 3400.0) < 250.0, "Raro ~17%% (%d de %d)" % [counts[1], total])
	_check(absf(counts[2] - 900.0) < 120.0, "Épico ~4,5%% (%d de %d)" % [counts[2], total])
	_check(absf(counts[3] - 100.0) < 45.0, "Legendario ~0,5%% (%d de %d)" % [counts[3], total])


## El bonus porcentual de antes ya no existe: una partida vieja que lo traiga no rompe nada ni multiplica.
func _test_old_bonus_is_gone() -> void:
	_section("Sin bonus porcentual")
	var e: EconomyScript = _make()
	e.from_dict({ "gold": 10.0, "loot_bonus": 5.0 })
	_check_eq(e.multiplier, 1.0, "un 'loot_bonus' guardado no multiplica nada")
	_check(not e.to_dict().has("loot_bonus"), "y ya no se guarda")


func _test_no_loot_section() -> void:
	_section("Balance sin loot")
	var e: EconomyScript = EconomyScript.new()
	_nodes.append(e)
	e.load_balance(TestBalance.make(["loot"]))
	e.owned[0] = 5
	var drops: Array[Dictionary] = _watch(e)
	for i: int in range(1000):
		e.hit()
		e.tick(1.0)
	_check_eq(e.loot_table().size(), 0, "tabla vacía")
	_check_eq(e.loot_chance_per_hit(), 0.0, "0% por golpe")
	_check_eq(e.loot_chance_per_second(), 0.0, "0% por segundo")
	e.drop_loot(0)
	_check_eq(drops.size(), 0, "y drop_loot() no hace nada sin tabla")
	_check_eq(e.loot_reward(0), 0.0, "ni hay premio")


func _test_balance_validation() -> void:
	_section("Validación de loot")
	var e: EconomyScript = _make()
	var cases: Array = [
		["rarezas vacías", func(loot: Dictionary) -> void: loot["rarities"] = []],
		["probabilidad por golpe mayor a 1", func(loot: Dictionary) -> void: loot["chance_per_hit"] = 1.5],
		["probabilidad por segundo negativa", func(loot: Dictionary) -> void: loot["chance_per_second"] = -0.1],
		["todos los pesos en 0", func(loot: Dictionary) -> void:
			for rarity: Dictionary in loot["rarities"]:
				rarity["weight"] = 0],
		["peso negativo", func(loot: Dictionary) -> void: loot["rarities"][1]["weight"] = -5],
		["segundos negativos", func(loot: Dictionary) -> void: loot["rarities"][0]["seconds"] = -1],
		["0 golpes (sin cuadrilla no pagaría nada)", func(loot: Dictionary) -> void: loot["rarities"][0]["hits"] = 0],
		["reliquias negativas", func(loot: Dictionary) -> void: loot["rarities"][3]["relics"] = -1],
		["sin reliquias", func(loot: Dictionary) -> void: loot["rarities"][3].erase("relics")],
		["rareza sin nombre", func(loot: Dictionary) -> void: loot["rarities"][2]["name"] = ""],
		["sin chance_per_hit", func(loot: Dictionary) -> void: loot.erase("chance_per_hit")],
	]
	for case: Array in cases:
		var balance: Dictionary = TestBalance.make()
		(case[1] as Callable).call(balance["loot"])
		_check_eq(e.load_balance(balance), false, "%s -> inválido" % case[0])
	_check(e.last_error.contains("loot"), "last_error nombra la sección (%s)" % e.last_error)
	var not_an_object: Dictionary = TestBalance.make()
	not_an_object["loot"] = [1, 2]
	_check_eq(e.load_balance(not_an_object), false, "loot que no es un objeto -> inválido")
	_check_eq(e.loot_table().size(), 4, "un balance inválido no pisa la tabla anterior")
	var zero: Dictionary = TestBalance.make()
	zero["loot"]["chance_per_hit"] = 0
	zero["loot"]["chance_per_second"] = 0
	_check_eq(e.load_balance(zero), true, "probabilidades 0 son válidas (cofres apagados)")


func _test_real_balance_file() -> void:
	_section("data/balance.json real")
	var e: EconomyScript = EconomyScript.new()
	_nodes.append(e)
	_check_eq(e.load_balance_file("res://data/balance.json"), true, "carga el balance real (%s)" % e.last_error)
	_check_eq(e.loot_chance_per_hit(), 0.003, "0,3% por golpe")
	_check_eq(e.loot_chance_per_second(), 0.015, "1,5% por segundo")
	var table: Array[Dictionary] = e.loot_table()
	_check_eq(table.size(), 4, "4 rarezas")
	if table.size() != 4:
		return
	var expected: Array = [["Común", 0.78, 5.0, 15.0, 0], ["Raro", 0.17, 20.0, 50.0, 0], ["Épico", 0.045, 60.0, 150.0, 0], ["Legendario", 0.005, 200.0, 500.0, 1]]
	for index: int in range(4):
		var entry: Dictionary = table[index]
		var want: Array = expected[index]
		_check_eq([entry["name"], entry["seconds"], entry["hits"], entry["relics"]], [want[0], want[2], want[3], want[4]], "%s: premio" % want[0])
		_check_near(entry["chance"], want[1], "%s: probabilidad" % want[0])
