extends "res://tests/test_base.gd"
## El juego y la simulación aprobada calculan lo mismo. Compara core/economy.gd (con data/) contra el modelo que se
## simuló (tools/tree_sim/economy_tree.gd con arbol_v3.json), con el mismo estado y las mismas estrellas.

const EconomyScript := preload("res://core/economy.gd")
const SimEconomy := preload("res://tools/tree_sim/economy_tree.gd")

const OWNED: Array[int] = [60, 30, 26, 12, 5, 1]
const RING1: Array[String] = ["core", "f_brazo", "f_templado", "f_ojo", "o_olfato", "o_botin", "o_gemologo", "c_capataz", "c_contrato", "c_bolsa", "t_mecha", "t_polvora", "t_vigilia"]
const BUILDS: Dictionary = {
	"sin estrellas": [],
	"anillo 1": RING1,
	"fortuna y apostador": ["core", "o_olfato", "o_botin", "o_gemologo", "o_dragon", "o_doble", "o_corona", "o_reliquia", "o_apostador"],
	"cuadrilla y A la par": ["core", "c_capataz", "c_contrato", "c_bolsa", "c_ventaja", "c_hitos", "c_memoria", "c_mina"],
	"golpes y Furia": ["core", "f_brazo", "f_templado", "f_ojo", "f_brutal", "f_eco", "f_combo", "f_umbral", "f_furia"],
	"tiempo y cuenta regresiva": ["core", "t_mecha", "t_polvora", "t_veta", "t_vigilia", "t_noche", "t_racha", "t_cuenta"],
}


func _initialize() -> void:
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance.json"))
	var sim_tree: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/tree_sim/arbol_v3.json"))
	for title: String in BUILDS:
		_compare(title, BUILDS[title], balance, sim_tree)
	_finish()


func _compare(title: String, ids: Array, balance: Dictionary, sim_tree: Dictionary) -> void:
	_section(title)
	var game: EconomyScript = EconomyScript.new()
	_check(game.load_balance_file("res://data/balance.json"), "el juego carga (%s)" % game.last_error)
	_check(game.has_tree(), "con árbol")
	var now: Array[float] = [5000.0]
	game.clock = func() -> float: return now[0]

	var sim: SimEconomy = SimEconomy.new()
	sim.setup(balance, sim_tree["stars"], sim_tree.get("offline", {}))
	sim.bonus_each = sim_tree["relic_bonus"]["each"]
	sim.bonus_full_until = sim_tree["relic_bonus"]["full_until"]
	sim.bonus_after = sim_tree["relic_bonus"]["after"]
	sim.return_rule = sim_tree["return"]
	sim.taps_per_second = 3.0

	var levels: Dictionary = {}
	for star: Dictionary in sim_tree["stars"]:
		if ids.has(star["id"]):
			levels[star["id"]] = int(star["max"])
	var keystones: Array = ids.filter(func(id: String) -> bool: return game.relic_tree.is_keystone(id))
	game.relic_tree.from_dict({ "levels": levels, "keystones": keystones })
	sim.tree = levels.duplicate()
	sim.active_keystones = keystones
	sim.apply_tree()
	for economy: Variant in [game, sim]:
		economy.relics = 400
		economy.owned.assign(OWNED)
		economy.pick_level = 5
		economy.ability_level = 4
		economy.run_gold = 2.0e9
	sim.claimed = 300
	sim.fix_target()
	game.claimed_relics = 300
	game.run_shift = game.relic_tree.shift_for(300)
	game.hit() # "golpeando": el simulador mide con 3 golpes/s
	for economy: Variant in [game, sim]:
		economy.gold = 0.0
		economy.run_gold = 2.0e9

	_check_near(game.gold_per_second(), sim.gold_per_second(), "oro por segundo", 1e-9)
	_check_near(game.hit_value(), sim.hit_value(), "golpe", 1e-9)
	_check_near(game.crit_chance(), sim._crit["chance"], "chance de crítico")
	_check_near(game.crit_multiplier(), sim._crit["multiplier"], "daño crítico")
	_check_near(game.loot_chance_per_hit(), sim.loot_chance_per_hit(), "cofres por golpe")
	_check_near(game.loot_chance_per_second(), sim.loot_chance_per_second(), "cofres por segundo")
	var mine: Array[Dictionary] = game.loot_table()
	var theirs: Array[Dictionary] = sim.loot_table()
	for index: int in range(mine.size()):
		_check_near(mine[index]["chance"], theirs[index]["chance"], "chance de %s" % mine[index]["name"], 1e-9)
		_check_near(game.loot_reward(index), sim.loot_reward(index) * (1.0 + sim.add("chest_gold")), "premio de %s" % mine[index]["name"], 1e-9)
	_check_near(game.ability_reward(), sim.ability_reward(), "dinamita", 1e-9)
	_check_near(game.ability_cooldown(), sim.ability_cooldown(), "recarga")
	for index: int in range(OWNED.size()):
		_check_near(game.quote(index, EconomyScript.BuyMode.X1)["cost"], sim.generator_cost(index, 1), "precio del generador %d" % index, 1e-9)
	_check_near(game.return_depth(), sim.return_depth(), "meta")
	_check_eq(game.prestige_relics(), sim.prestige_relics(), "reliquias por volver ahora")
	_check_near(game.offline_efficiency(), sim._offline["efficiency"], "eficiencia AFK")
	_check_near(game.offline_max_seconds(), float(sim._offline["max_hours"]) * 3600.0, "tope AFK")
	var game_report: Dictionary = game.apply_offline(36000.0)
	var sim_report: Dictionary = sim.apply_offline(36000.0)
	_check_near(float(game_report.get("gold", 0.0)), float(sim_report.get("gold", 0.0)), "oro de 10 h fuera", 1e-9)
	# Y la bajada siguiente arranca igual (arrastre).
	for economy: Variant in [game, sim]:
		economy.run_gold = 1.0e15
		economy.gold = 0.0
		economy.prestige()
	sim.fix_target()
	_check_eq(game.owned, sim.owned, "cuadrilla al empezar la bajada siguiente")
	_check_eq(game.pick_level, sim.pick_level, "pico")
	_check_eq(game.ability_level, sim.ability_level, "dinamita")
	_check_near(game.gold, sim.gold, "oro de la Bolsa", 1e-6)
	_check_near(game.return_depth(), sim.return_depth(), "meta nueva")
	game.free()
	sim.free()
