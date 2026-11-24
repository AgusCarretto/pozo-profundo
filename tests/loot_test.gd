extends "res://tests/test_base.gd"
## Tests headless del botín de core/economy.gd: cofres por golpe y pasivos, rarezas y bonus.
##
## Cada test crea su propia instancia de Economy SIN agregarla al árbol. Para que no dependan
## del azar se usan probabilidades 0 / 1; la distribución real se mide con una semilla fija.

const EconomyScript := preload("res://core/economy.gd")
const TestBalance := preload("res://tests/test_balance.gd")

var _nodes: Array[Node] = []


func _initialize() -> void:
	_test_probability_table()
	_test_chances_are_exposed()
	_test_hit_drops_a_chest()
	_test_bonus_accumulates()
	_test_drop_loot_directly()
	_test_bonus_stacks_with_biome_and_relics()
	_test_hit_without_chest()
	_test_passive_chest_needs_a_crew()
	_test_passive_chance_scales_with_time()
	_test_hit_chance_statistics()
	_test_rarity_distribution()
	_test_bonus_serialization()
	_test_reset_clears_the_bonus()
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


## Un solo tipo de cofre (bonus 10%) que sale siempre que hay tirada.
func _always(chance_per_hit: float, chance_per_second: float) -> Callable:
	return func(loot: Dictionary) -> void:
		loot["chance_per_hit"] = chance_per_hit
		loot["chance_per_second"] = chance_per_second
		loot["rarities"] = [{ "id": "only", "name": "Único", "weight": 1, "bonus": 0.10 }]


func _test_probability_table() -> void:
	_section("Tabla de probabilidades (la que ve el jugador)")
	var e: EconomyScript = _make()
	var table: Array[Dictionary] = e.loot_table()
	_check_eq(table.size(), 4, "4 rarezas")
	var names: Array[String] = []
	var chances: Array[float] = []
	var bonuses: Array[float] = []
	for entry: Dictionary in table:
		names.append(entry["name"])
		chances.append(entry["chance"])
		bonuses.append(entry["bonus"])
	_check_eq(names, ["Común", "Raro", "Épico", "Legendario"] as Array[String], "Común, Raro, Épico, Legendario (en ese orden)")
	_check_near(chances[0], 0.70, "Común 70%")
	_check_near(chances[1], 0.22, "Raro 22%")
	_check_near(chances[2], 0.07, "Épico 7%")
	_check_near(chances[3], 0.01, "Legendario 1%")
	_check_near(chances[0] + chances[1] + chances[2] + chances[3], 1.0, "las probabilidades suman 100%")
	_check_eq(bonuses, [0.01, 0.04, 0.15, 0.60] as Array[float], "bonus +1%, +4%, +15%, +60%")
	# Los pesos no tienen que sumar 100: la probabilidad es peso / total.
	var odd: EconomyScript = _make(func(loot: Dictionary) -> void:
		loot["rarities"] = [
			{ "id": "a", "name": "A", "weight": 3, "bonus": 0.1 },
			{ "id": "b", "name": "B", "weight": 1, "bonus": 0.2 },
		])
	_check_near(odd.loot_table()[0]["chance"], 0.75, "pesos 3 y 1 -> 75%")
	_check_near(odd.loot_table()[1]["chance"], 0.25, "pesos 3 y 1 -> 25%")


func _test_chances_are_exposed() -> void:
	_section("Probabilidad de cofre")
	var e: EconomyScript = _make()
	_check_eq(e.loot_chance_per_hit(), 0.04, "4% por golpe")
	_check_eq(e.loot_chance_per_second(), 0.02, "2% por segundo con cuadrilla")


func _test_hit_drops_a_chest() -> void:
	_section("Un golpe con cofre seguro")
	var e: EconomyScript = _make(_always(1.0, 0.0))
	# Se anota en Dictionary y no en Vector2: Vector2 guarda float32 y degrada los montos.
	var drops: Array[Dictionary] = []
	var golds: Array[float] = []
	var hits: Array[float] = []
	e.loot_dropped.connect(func(rarity: int, bonus: float) -> void: drops.append({ "rarity": rarity, "bonus": bonus }))
	e.gold_changed.connect(func(gold: float) -> void: golds.append(gold))
	e.hit_landed.connect(func(amount: float) -> void: hits.append(amount))
	e.gold = 1000.0
	var gained: float = e.hit()
	_check_eq(gained, 1.0, "hit() devuelve el oro del golpe (1): el cofre no da oro")
	_check_eq(hits, [1.0] as Array[float], "hit_landed(1)")
	_check_eq(drops.size(), 1, "cae 1 cofre")
	_check_eq(drops[0]["rarity"], 0, "de la rareza 0")
	_check_eq(drops[0]["bonus"], 0.10, "y trae su bonus: +10%")
	_check_eq(e.gold, 1001.0, "el oro es solo el del golpe: el cofre no suma oro")
	_check_eq(e.run_gold, 1.0, "ni lo ganado en la partida")
	_check_near(e.loot_bonus, 0.10, "el bonus de botín de la partida pasó a +10%")
	_check_near(e.loot_multiplier(), 1.10, "que multiplica el oro x1.10")
	_check_near(e.multiplier, 1.10, "y el multiplicador global también")
	_check_eq(golds.size(), 1, "gold_changed se emite una sola vez por golpe")
	_check_eq(golds[0], 1001.0, "con el oro final")


## Cada cofre suma a lo que ya había (acumulable): el oro de ahí en más rinde más.
func _test_bonus_accumulates() -> void:
	_section("Los cofres acumulan bonus")
	var e: EconomyScript = _make(_always(1.0, 0.0))
	var hits: Array[float] = []
	e.hit_landed.connect(func(amount: float) -> void: hits.append(amount))
	for i: int in range(3):
		e.hit()
	_check_near(e.loot_bonus, 0.30, "3 cofres de +10% = +30%")
	_check_near(e.multiplier, 1.30, "multiplicador x1.30")
	_check_eq(hits.size(), 3, "3 golpes")
	_check_near(hits[0], 1.0, "el primer golpe vale 1 (todavía sin bonus)")
	_check_near(hits[1], 1.1, "el segundo ya vale 1.1 (con el cofre del primero)")
	_check_near(hits[2], 1.2, "el tercero 1.2")
	e.owned[0] = 10 # 10 oro/s base
	_check_near(e.gold_per_second(), 13.0, "10 oro/s base -> 13 oro/s")
	_check_near(e.generator_output(0), 13.0, "el generador aporta 13/s")
	var before: float = e.gold
	e.tick(2.0)
	_check_near(e.gold - before, 26.0, "2 s de producción = 26")
	e.pick_level = 3
	_check_near(e.hit_value(), 8.0 * 1.3 + 0.03 * 13.0, "el bonus escala la parte del pico: 8 * 1.3 + 3% de 13")


## drop_loot() fuerza un cofre de una rareza (lo usan el sorteo y el panel de debug).
func _test_drop_loot_directly() -> void:
	_section("drop_loot(): cofre de una rareza")
	var e: EconomyScript = _make()
	var drops: Array[Dictionary] = []
	var golds: Array[float] = []
	e.loot_dropped.connect(func(rarity: int, bonus: float) -> void: drops.append({ "rarity": rarity, "bonus": bonus }))
	e.gold_changed.connect(func(gold: float) -> void: golds.append(gold))
	e.drop_loot(3)
	_check_eq(drops.size(), 1, "emite loot_dropped una vez")
	_check_eq(drops[0]["rarity"], 3, "de la rareza 3 (Legendario)")
	_check_eq(drops[0]["bonus"], 0.60, "con su bonus +60%")
	_check_near(e.loot_bonus, 0.60, "el bonus de la partida es +60%")
	_check_eq(e.gold, 0.0, "no da oro")
	_check_eq(golds.size(), 0, "ni emite gold_changed")
	e.drop_loot(0)
	_check_near(e.loot_bonus, 0.61, "un Común más: +61%")
	e.drop_loot(99)
	e.drop_loot(-1)
	_check_eq(drops.size(), 2, "una rareza inexistente no hace nada (ni explota)")
	_check_near(e.loot_bonus, 0.61, "y no cambia el bonus")


func _test_bonus_stacks_with_biome_and_relics() -> void:
	_section("Multiplicador final: bioma x (1 + botín) x (1 + 0.25 x reliquias)")
	var e: EconomyScript = _make()
	e.run_gold = 700.0 # Roca, x1.5
	e.relics = 4 # x2
	e.drop_loot(3) # +60% -> x1.6
	_check_near(e.biome_multiplier(), 1.5, "bioma x1.5")
	_check_near(e.loot_multiplier(), 1.6, "botín x1.6")
	_check_near(e.relic_multiplier(), 2.0, "reliquias x2")
	_check_near(e.multiplier, 1.5 * 1.6 * 2.0, "todo junto: x4.8")
	e.owned[0] = 10
	_check_near(e.gold_per_second(), 48.0, "10 oro/s base -> 48 oro/s")


func _test_hit_without_chest() -> void:
	_section("Golpe sin cofre")
	var e: EconomyScript = _make(_always(0.0, 0.0))
	var drops: Array[int] = []
	e.loot_dropped.connect(func(rarity: int, _bonus: float) -> void: drops.append(rarity))
	for i: int in range(500):
		e.hit()
	_check_eq(drops.size(), 0, "con probabilidad 0 nunca cae un cofre (500 golpes)")
	_check_eq(e.gold, 500.0, "el oro es solo de los golpes")
	_check_eq(e.loot_bonus, 0.0, "y no hay bonus de botín")


func _test_passive_chest_needs_a_crew() -> void:
	_section("Cofre pasivo: solo si hay cuadrilla")
	var e: EconomyScript = _make(_always(0.0, 1.0))
	var drops: Array[Dictionary] = []
	e.loot_dropped.connect(func(rarity: int, bonus: float) -> void: drops.append({ "rarity": rarity, "bonus": bonus }))
	e.tick(1.0)
	_check_eq(drops.size(), 0, "sin cuadrilla no hay cofres pasivos")
	_check_eq(e.gold, 0.0, "ni oro")
	_check_eq(e.loot_bonus, 0.0, "ni bonus")
	e.owned[0] = 10 # 10 oro/s
	var golds: Array[float] = []
	e.gold_changed.connect(func(gold: float) -> void: golds.append(gold))
	e.tick(1.0)
	_check_eq(drops.size(), 1, "con cuadrilla y 100% por segundo cae 1 cofre")
	_check_eq(drops[0]["bonus"], 0.10, "con su bonus (+10%)")
	_check_eq(e.gold, 10.0, "el oro es solo la producción (10): el cofre no da oro")
	_check_near(e.loot_bonus, 0.10, "y el bonus de la partida es +10%")
	_check_eq(golds.size(), 1, "una sola señal gold_changed por tick")
	e.tick(0.0)
	_check_eq(drops.size(), 1, "un tick de 0 s no tira ningún cofre")


## 2% por segundo se reparte según el tiempo del tick: 0.1 s de tick = 1 - 0.98^0.1 de chance.
func _test_passive_chance_scales_with_time() -> void:
	_section("El cofre pasivo escala con el tiempo")
	var e: EconomyScript = _make(_always(0.0, 0.02))
	e.owned[0] = 1
	var drops: Array[int] = []
	e.loot_dropped.connect(func(rarity: int, _bonus: float) -> void: drops.append(rarity))
	for i: int in range(100000): # 10.000 s en ticks de 0.1 s -> ~202 cofres esperados
		e.tick(0.1)
	var expected: float = 100000.0 * (1.0 - pow(0.98, 0.1))
	_check(absf(drops.size() - expected) < 60.0, "~%.0f cofres en 10.000 s de ticks cortos (salieron %d)" % [expected, drops.size()])
	var slow: EconomyScript = _make(_always(0.0, 0.02))
	slow.owned[0] = 1
	var slow_drops: Array[int] = []
	slow.loot_dropped.connect(func(rarity: int, _bonus: float) -> void: slow_drops.append(rarity))
	for i: int in range(1000): # los mismos 10.000 s, en ticks de 10 s (un frame muy lento)
		slow.tick(10.0)
	var slow_expected: float = 1000.0 * (1.0 - pow(0.98, 10.0))
	_check(absf(slow_drops.size() - slow_expected) < 40.0, "~%.0f cofres en ticks de 10 s (salieron %d): la chance crece con el delta" % [slow_expected, slow_drops.size()])


func _test_hit_chance_statistics() -> void:
	_section("4% de cofre por golpe")
	var e: EconomyScript = _make()
	var chests: Array[int] = []
	e.loot_dropped.connect(func(rarity: int, _bonus: float) -> void: chests.append(rarity))
	var total: int = 20000
	for i: int in range(total):
		e.hit()
	var expected: float = total * 0.04
	_check(absf(chests.size() - expected) < 120.0, "~%.0f cofres en %d golpes (salieron %d)" % [expected, total, chests.size()])


func _test_rarity_distribution() -> void:
	_section("Distribución de rarezas 70 / 22 / 7 / 1")
	var e: EconomyScript = _make(func(loot: Dictionary) -> void: loot["chance_per_hit"] = 1.0)
	var counts: Array[int] = [0, 0, 0, 0]
	e.loot_dropped.connect(func(rarity: int, _bonus: float) -> void: counts[rarity] += 1)
	var total: int = 20000
	for i: int in range(total):
		e.hit()
	_check_eq(counts[0] + counts[1] + counts[2] + counts[3], total, "cada golpe dio un cofre (%d)" % total)
	_check(absf(counts[0] - 14000.0) < 300.0, "Común ~70%% (%d de %d)" % [counts[0], total])
	_check(absf(counts[1] - 4400.0) < 250.0, "Raro ~22%% (%d de %d)" % [counts[1], total])
	_check(absf(counts[2] - 1400.0) < 150.0, "Épico ~7%% (%d de %d)" % [counts[2], total])
	_check(absf(counts[3] - 200.0) < 60.0, "Legendario ~1%% (%d de %d)" % [counts[3], total])


func _test_bonus_serialization() -> void:
	_section("loot_bonus en to_dict / from_dict")
	var a: EconomyScript = _make()
	a.loot_bonus = 1.2345678901234567
	var data: Dictionary = a.to_dict()
	_check(data.has("loot_bonus"), "to_dict incluye loot_bonus")
	var b: EconomyScript = _make()
	b.from_dict(data)
	_check_eq(b.loot_bonus, a.loot_bonus, "se conserva exacto")
	var c: EconomyScript = _make()
	c.from_dict(JSON.parse_string(JSON.stringify(data)))
	_check_near(c.loot_bonus, a.loot_bonus, "también después de ir y volver por JSON")
	var old: EconomyScript = _make()
	old.loot_bonus = 0.5
	old.from_dict({ "gold": 10.0 })
	_check_eq(old.loot_bonus, 0.0, "un save sin 'loot_bonus' deja 0 (no conserva el de la sesión)")
	var garbage: Array = [-0.5, "mucho", NAN, INF]
	for value: Variant in garbage:
		old.from_dict({ "loot_bonus": value })
		_check_eq(old.loot_bonus, 0.0, "loot_bonus %s -> 0" % str(value))
	old.from_dict({ "loot_bonus": 1.0e30 })
	_check(old.loot_bonus > 0.0 and old.loot_bonus <= EconomyScript.MAX_LOADED_LOOT_BONUS, "un valor absurdo se topa (%s)" % str(old.loot_bonus))
	_check(is_finite(old.multiplier), "y el multiplicador sigue siendo finito")


func _test_reset_clears_the_bonus() -> void:
	_section("reset() borra el bonus")
	var e: EconomyScript = _make()
	e.drop_loot(3)
	e.reset()
	_check_eq(e.loot_bonus, 0.0, "reset() vuelve el bonus de botín a 0")
	_check_eq(e.multiplier, 1.0, "y el multiplicador a x1")


func _test_no_loot_section() -> void:
	_section("Balance sin loot")
	var e: EconomyScript = EconomyScript.new()
	_nodes.append(e)
	e.load_balance(TestBalance.make(["loot"]))
	e.owned[0] = 5
	for i: int in range(1000):
		e.hit()
		e.tick(1.0)
	_check_eq(e.loot_table().size(), 0, "tabla vacía")
	_check_eq(e.loot_chance_per_hit(), 0.0, "0% por golpe")
	_check_eq(e.loot_chance_per_second(), 0.0, "0% por segundo")
	_check_eq(e.loot_bonus, 0.0, "sin bonus de botín")
	e.drop_loot(0)
	_check_eq(e.loot_bonus, 0.0, "y drop_loot() no hace nada sin tabla")


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
		["bonus negativo", func(loot: Dictionary) -> void: loot["rarities"][0]["bonus"] = -0.01],
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
	_check_eq(e.loot_chance_per_hit(), 0.04, "4% por golpe")
	_check_eq(e.loot_chance_per_second(), 0.02, "2% por segundo")
	var table: Array[Dictionary] = e.loot_table()
	_check_eq(table.size(), 4, "4 rarezas")
	if table.size() == 4:
		_check_eq(table[0]["name"], "Común", "Común")
		_check_near(table[0]["chance"], 0.70, "Común 70%")
		_check_near(table[0]["bonus"], 0.01, "Común +1%")
		_check_near(table[1]["chance"], 0.22, "Raro 22%")
		_check_near(table[1]["bonus"], 0.04, "Raro +4%")
		_check_near(table[2]["chance"], 0.07, "Épico 7%")
		_check_near(table[2]["bonus"], 0.15, "Épico +15%")
		_check_eq(table[3]["name"], "Legendario", "Legendario")
		_check_near(table[3]["chance"], 0.01, "Legendario 1%")
		_check_near(table[3]["bonus"], 0.60, "Legendario +60%")
