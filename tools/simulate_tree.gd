extends SceneTree
## Simula el árbol de reliquias y los logros (v0.7) antes de programarlos. No toca el juego ni la partida guardada.
##
##   godot --headless --path . --script res://tools/simulate_tree.gd -- campaign <arbol.json> [golpes/s] [semilla]
##   godot --headless --path . --script res://tools/simulate_tree.gd -- stars <arbol.json> [semillas] [parte] [partes]
##   godot --headless --path . --script res://tools/simulate_tree.gd -- descents <arbol.json> [semillas]
##
## campaign: un jugador que entra una vez por día, juega 60 minutos y se va (23 h de progreso offline). Compra lo
## que antes se paga solo, vuelve a la superficie cuando las reliquias por minuto dejan de subir y gasta en la
## estrella más barata que pueda. Las reliquias ganadas en la historia dan el bonus "relic_bonus" del árbol.json.
## descents: bajadas seguidas hasta 300 m, comparadas con las reglas de hoy (+25% por reliquia, sin árbol).
## stars: cuánto acorta una bajada cada estrella (de 0 a su máximo, con el resto de su anillo comprado).

const EconomyTree := preload("res://tools/tree_sim/economy_tree.gd")

const STEP: float = 0.25
const SHOP_EVERY: float = 1.0
const PATIENCE: float = 90.0
const ABILITY_DELAY: float = 20.0
const MILESTONE_REACH: int = 12
const ABILITY: int = -2
const SESSION: float = 3600.0
const AWAY: float = 23.0 * 3600.0
const MAX_DAYS: int = 60
## Cuánto aguanta una bajada para llegar a la profundidad que abre un anillo antes de rendirse (s).
const PUSH_LIMIT: float = 5400.0
const KEYSTONE_PREFERENCE: Array[String] = ["c_mina", "o_apostador", "f_furia", "t_cuenta", "t_reloj"]

var _balance: Dictionary
var _tree_data: Dictionary
var _achievements: Dictionary
var _random: RandomNumberGenerator = RandomNumberGenerator.new()


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "campaign"
	var path: String = args[1] if args.size() > 1 else "res://tools/tree_sim/arbol_doc.json"
	_balance = _json("res://data/balance.json")
	_tree_data = _json(path)
	_achievements = _json("res://tools/tree_sim/logros.json")
	print("Árbol: %s" % path)
	if mode == "stars":
		_stars(int(args[2]) if args.size() > 2 else 5, int(args[3]) if args.size() > 3 else 0, int(args[4]) if args.size() > 4 else 1)
	elif mode == "descents":
		_descents(int(args[2]) if args.size() > 2 else 5)
	else:
		_campaign(float(args[2]) if args.size() > 2 else 3.0, int(args[3]) if args.size() > 3 else 1)
	quit(0)


func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		push_error("JSON inválido: " + path)
		quit(1)
		return {}
	return parsed


func _new_economy(seed_value: int, taps: float) -> EconomyTree:
	var economy: EconomyTree = EconomyTree.new()
	economy.setup(_balance, _tree_data["stars"])
	economy.rng.seed = seed_value
	economy.taps_per_second = taps
	var bonus: Dictionary = _tree_data.get("relic_bonus", {})
	economy.bonus_each = float(bonus.get("each", 0.05))
	economy.bonus_full_until = float(bonus.get("full_until", 0.0))
	economy.bonus_after = float(bonus.get("after", 0.0))
	economy.shift_per_relic = float(_tree_data.get("depth_per_relic", 0.0))
	_random.seed = seed_value + 1
	return economy


# --- Árbol -------------------------------------------------------------------

func _cost(star: Dictionary, level: int) -> int:
	return roundi(float(star["base"]) * pow(float(star.get("growth", _tree_data["cost_growth"])), level))


func _total_cost(star: Dictionary) -> int:
	var total: int = 0
	for level: int in range(int(star["max"])):
		total += _cost(star, level)
	return total


func _ring_open(economy: EconomyTree, star: Dictionary) -> bool:
	var ring: int = int(star["ring"])
	if ring == 0:
		return int(economy.stats.get("resets", 0)) >= 1
	if ring == 1:
		return economy.level_of("core") > 0
	if ring == 4:
		for id: String in star["bridge"]:
			if economy.level_of(id) <= 0:
				return false
		return true
	var gate: Dictionary = _tree_data["rings"][str(ring)]
	return float(economy.stats.get("record_depth", 0.0)) >= float(gate["depth"]) and int(economy.stats.get("resets", 0)) >= int(gate["resets"])


func _unlocked(economy: EconomyTree, star: Dictionary) -> bool:
	if star.has("requires_max"):
		var previous: String = star["requires_max"]
		return economy.level_of(previous) >= int(economy.stars[previous]["max"])
	if star["from"].is_empty():
		return true
	for id: String in star["from"]:
		if economy.level_of(id) > 0:
			return true
	return false


## Compra estrellas (la más barata primero) y devuelve las que encendió por primera vez.
func _buy_stars(economy: EconomyTree) -> Array[String]:
	var lit: Array[String] = []
	while true:
		var best: Dictionary = {}
		var best_cost: int = 0
		for star: Dictionary in _tree_data["stars"]:
			var level: int = economy.level_of(star["id"])
			if level >= int(star["max"]) or not _ring_open(economy, star) or not _unlocked(economy, star):
				continue
			var cost: int = _cost(star, level)
			if cost <= economy.available() and (best.is_empty() or cost < best_cost):
				best = star
				best_cost = cost
		if best.is_empty():
			break
		if economy.level_of(best["id"]) == 0:
			lit.append(best["id"])
		economy.tree[best["id"]] = economy.level_of(best["id"]) + 1
		economy.spent += best_cost
		economy.active_keystones = KEYSTONE_PREFERENCE.filter(func(id: String) -> bool: return economy.level_of(id) > 0).slice(0, 2)
		economy.apply_tree()
	return lit


func _ring_done(economy: EconomyTree, ring: int) -> bool:
	for star: Dictionary in _tree_data["stars"]:
		if int(star["ring"]) == ring and economy.level_of(star["id"]) < int(star["max"]):
			return false
	return true


# --- Logros ------------------------------------------------------------------

func _check_achievements(economy: EconomyTree, day: int, done: Dictionary, log: Array[Dictionary]) -> void:
	var stats: Dictionary = economy.stats
	stats["record_depth"] = maxf(float(stats.get("record_depth", 0.0)), economy.depth())
	for index: int in range(economy.generator_count()):
		var key: String = "max_" + economy.generator_id(index)
		stats[key] = maxi(int(stats.get(key, 0)), economy.owned_count(index))
	stats["has_core"] = economy.level_of("core")
	stats["stars"] = economy.tree.size()
	stats["ring1_done"] = int(_ring_done(economy, 1))
	stats["ring2_done"] = int(_ring_done(economy, 2))
	stats["keystones"] = KEYSTONE_PREFERENCE.filter(func(id: String) -> bool: return economy.level_of(id) > 0).size()
	stats["bridges"] = ["p_suerte", "p_mineros", "p_turnos", "p_critica"].filter(func(id: String) -> bool: return economy.level_of(id) > 0).size()
	var complete: bool = true
	for ring: int in range(5):
		complete = complete and _ring_done(economy, ring)
	stats["complete"] = int(complete)
	for entry: Dictionary in _achievements["list"]:
		if done.has(entry["name"]):
			continue
		var reached: bool = (day >= int(entry["day"])) if entry.has("day") else float(stats.get(entry["stat"], 0.0)) >= float(entry["target"])
		if reached:
			done[entry["name"]] = day
			var fragments: int = int(_achievements["fragments"][entry["tier"]])
			var before: int = int(stats.get("fragments", 0))
			stats["fragments"] = before + fragments
			economy.relics += (before + fragments) / 10 - before / 10
			log.append({ "name": entry["name"], "day": day, "fragments": fragments })


# --- Jugar -------------------------------------------------------------------

func _income(economy: EconomyTree, taps: float) -> float:
	return economy.gold_per_second() + taps * economy.hit_average()


func _shop(economy: EconomyTree, taps: float) -> void:
	for i: int in range(400):
		var best: Dictionary = _best_option(economy, taps)
		if best.is_empty() or best["cost"] > economy.gold:
			return
		if best["index"] == ABILITY:
			economy.upgrade_ability()
		elif best["index"] < 0:
			economy.upgrade_pick()
		elif not economy.buy_units(best["index"], best["count"]):
			return


func _best_option(economy: EconomyTree, taps: float) -> Dictionary:
	var now: float = _income(economy, taps)
	var options: Array[Dictionary] = []
	for index: int in range(economy.generator_count()):
		if not economy.is_generator_revealed(index):
			continue
		var owned: int = economy.owned_count(index)
		var counts: Array[int] = [1]
		var next: int = economy.next_milestone(index)
		if next > 0 and next - owned > 1 and next - owned <= MILESTONE_REACH:
			counts.append(next - owned)
		for count: int in counts:
			var cost: float = economy.generator_cost(index, count)
			economy.owned[index] += count
			var gain: float = _income(economy, taps) - now
			economy.owned[index] -= count
			_add_option(options, index, count, cost, gain, now, economy.gold)
	var pick_cost: float = economy.pick_cost()
	economy.pick_level += 1
	var pick_gain: float = _income(economy, taps) - now
	economy.pick_level -= 1
	_add_option(options, -1, 1, pick_cost, pick_gain, now, economy.gold)
	if economy.ability_revealed() and economy.ability_level < economy.ability_max_level():
		var before: float = economy.ability_reward()
		var cost: float = economy.ability_cost()
		economy.ability_level += 1
		var gain_each: float = economy.ability_reward() - before
		economy.ability_level -= 1
		_add_option(options, ABILITY, 1, cost, gain_each / (economy.ability_cooldown() + ABILITY_DELAY * 0.5), now, economy.gold)
	var fallback: Dictionary = {}
	var chosen: Dictionary = {}
	for option: Dictionary in options:
		if fallback.is_empty() or option["score"] < fallback["score"]:
			fallback = option
		if option["wait"] <= PATIENCE and (chosen.is_empty() or option["score"] < chosen["score"]):
			chosen = option
	return chosen if not chosen.is_empty() else fallback


func _add_option(options: Array[Dictionary], index: int, count: int, cost: float, gain: float, income: float, gold: float) -> void:
	if gain <= 0.0:
		return
	var wait: float = maxf(cost - gold, 0.0) / income
	options.append({ "index": index, "count": count, "cost": cost, "wait": wait, "score": wait + cost / gain })


## Un paso de juego activo. `clock` es el tiempo de la bajada.
func _step(economy: EconomyTree, taps: float, state: Dictionary) -> void:
	economy.tick(STEP)
	economy.advance_ability(STEP)
	if economy.ability_ready():
		if state["use_at"] < 0.0:
			state["use_at"] = state["clock"] + _random.randf() * ABILITY_DELAY
		if state["clock"] >= state["use_at"]:
			economy.use_ability()
			state["use_at"] = -1.0
	state["hits"] += taps * STEP
	while state["hits"] >= 1.0:
		economy.hit()
		state["hits"] -= 1.0
	state["shop"] += STEP
	if state["shop"] >= SHOP_EVERY:
		state["shop"] = 0.0
		_shop(economy, taps)
	state["clock"] += STEP


func _new_run_state() -> Dictionary:
	return { "clock": 0.0, "hits": 0.0, "shop": SHOP_EVERY, "use_at": -1.0, "best_rate": 0.0, "best_time": 0.0 }


func _time_to(economy: EconomyTree, taps: float, target: float) -> float:
	var state: Dictionary = _new_run_state()
	while economy.depth() < target and state["clock"] < 4.0 * 3600.0:
		_step(economy, taps, state)
	return state["clock"]


# --- Campaña -----------------------------------------------------------------

func _campaign(taps: float, seed_value: int) -> void:
	var economy: EconomyTree = _new_economy(seed_value, taps)
	var done: Dictionary = {}
	var log: Array[Dictionary] = []
	var events: Dictionary = {}
	var snapshots: Array[Dictionary] = []
	var state: Dictionary = _new_run_state()
	var played: float = 0.0
	var costs: int = 0
	for star: Dictionary in _tree_data["stars"]:
		costs += _total_cost(star)
	print("%.1f golpes/s, semilla %d. El árbol entero cuesta %d reliquias." % [taps, seed_value, costs])
	print("día | reliquias ganadas (gastadas) | estrellas | niveles | resets | bajada típica | prof. récord | logros (fragmentos) | se vuelve desde")
	var day: int = 1
	while day <= MAX_DAYS and not events.has("completo"):
		if day > 1:
			economy.advance_ability(AWAY)
			economy.apply_offline(AWAY)
			economy.dismiss_offline_report()
		var session: float = 0.0
		var descents: Array[float] = []
		var next_check: float = 0.0
		while session < SESSION and not events.has("completo"):
			_step(economy, taps, state)
			session += STEP
			played += STEP
			if session < next_check:
				continue
			next_check = session + 2.0
			_check_achievements(economy, day, done, log)
			if not _should_reset(economy, state):
				continue
			var gained: int = economy.prestige_relics()
			economy.stats["best_reset"] = maxi(int(economy.stats.get("best_reset", 0)), gained)
			economy.stats["resets"] = int(economy.stats.get("resets", 0)) + 1
			descents.append(state["clock"])
			economy.prestige()
			_check_achievements(economy, day, done, log)
			var lit: Array[String] = _buy_stars(economy)
			if int(economy.stats["resets"]) == 1:
				print("  primer reset a los %s: %d reliquias (con fragmentos) → encendió %s, sobran %d" % [_clock(played), economy.relics, ", ".join(lit), economy.available()])
			if economy.run_gold <= 0.0:
				economy._reset_run()
			state = _new_run_state()
			_record_events(economy, events, snapshots, day, played)
		descents.sort()
		var typical: String = _clock(descents[descents.size() / 2]) if not descents.is_empty() else "—"
		var levels: int = 0
		for id: String in economy.tree:
			levels += int(economy.tree[id])
		var fragments: int = int(economy.stats.get("fragments", 0))
		print("%3d | %5d (%d) | %2d | %3d | %3d | %6s | %3d m | %2d (%d) | %d m" % [day, economy.relics, economy.spent, economy.tree.size(), levels,
			int(economy.stats.get("resets", 0)), typical, int(economy.stats.get("record_depth", 0.0)), done.size(), fragments, int(economy.return_depth())])
		day += 1
	print("\nHitos (día de juego, horas jugadas):")
	for key: String in ["anillo 2 abierto", "anillo 3 abierto", "anillo 1 completo", "anillo 2 completo", "primera piedra angular", "primer puente", "anillo 3 completo", "completo"]:
		print("  %s: %s" % [key, events.get(key, "no se llegó")])
	print("\nCofres: %d · oro de cofres %s · reliquias de cofres %d" % [int(economy.stats.get("chests", 0)), String.num_scientific(economy.stats.get("chest_gold", 0.0)), int(economy.stats.get("chest_relics", 0))])
	var missing: PackedStringArray = PackedStringArray()
	for entry: Dictionary in _achievements["list"]:
		if not done.has(entry["name"]):
			missing.append("%s (%s)" % [entry["name"], str(entry.get("desc", ""))])
	var total_fragments: int = 0
	for entry: Dictionary in _achievements["list"]:
		total_fragments += int(_achievements["fragments"][entry["tier"]])
	print("Logros: %d en total = %d fragmentos = %d reliquias. Sin conseguir: %s" % [_achievements["list"].size(), total_fragments, total_fragments / 10, ", ".join(missing)])
	var by_day: PackedStringArray = PackedStringArray()
	for limit: int in [1, 2, 3, 7, 14, 21, 28, 35]:
		var sum: int = 0
		var count: int = 0
		for item: Dictionary in log:
			if item["day"] <= limit:
				sum += item["fragments"]
				count += 1
		by_day.append("día %d: %d logros, %d frag." % [limit, count, sum])
	print("Fragmentos acumulados: " + " · ".join(by_day))
	_benchmark(snapshots, taps)
	economy.free()


## Vuelve a la superficie cuando las reliquias por minuto de la bajada dejaron de mejorar hace rato.
func _should_reset(economy: EconomyTree, state: Dictionary) -> bool:
	var gain: int = economy.prestige_relics()
	if gain <= 0:
		return false
	# Si al jugador le falta profundidad para abrir un anillo (y ya hizo los resets), aguanta hasta llegar.
	var resets: int = int(economy.stats.get("resets", 0))
	for ring: String in _tree_data["rings"]:
		var gate: Dictionary = _tree_data["rings"][ring]
		if resets + 1 >= int(gate["resets"]) and float(economy.stats.get("record_depth", 0.0)) < float(gate["depth"]) and state["clock"] < PUSH_LIMIT:
			return false
	var rate: float = gain / maxf(state["clock"], 60.0)
	if rate > state["best_rate"]:
		state["best_rate"] = rate
		state["best_time"] = state["clock"]
	return state["clock"] > state["best_time"] * 1.35 + 45.0


func _record_events(economy: EconomyTree, events: Dictionary, snapshots: Array[Dictionary], day: int, played: float) -> void:
	var stamp: String = "día %d (%.1f h)" % [day, played / 3600.0]
	var gates: Dictionary = _tree_data["rings"]
	var checks: Dictionary = {
		"anillo 2 abierto": _ring_open(economy, { "ring": 2 }) if gates.has("2") else false,
		"anillo 3 abierto": _ring_open(economy, { "ring": 3 }) if gates.has("3") else false,
		"anillo 1 completo": _ring_done(economy, 1),
		"anillo 2 completo": _ring_done(economy, 2),
		"anillo 3 completo": _ring_done(economy, 3),
		"primera piedra angular": KEYSTONE_PREFERENCE.any(func(id: String) -> bool: return economy.level_of(id) > 0),
		"primer puente": ["p_suerte", "p_mineros", "p_turnos", "p_critica"].any(func(id: String) -> bool: return economy.level_of(id) > 0),
		"completo": _ring_done(economy, 0) and _ring_done(economy, 1) and _ring_done(economy, 2) and _ring_done(economy, 3) and _ring_done(economy, 4),
	}
	for key: String in checks:
		if checks[key] and not events.has(key):
			events[key] = stamp
			if key in ["anillo 1 completo", "anillo 2 completo", "anillo 3 completo", "completo"]:
				snapshots.append(_snapshot(economy, key))
	if int(economy.stats["resets"]) == 1:
		snapshots.append(_snapshot(economy, "tras el primer reset"))


func _snapshot(economy: EconomyTree, label: String) -> Dictionary:
	return { "label": label, "tree": economy.tree.duplicate(), "relics": economy.relics, "spent": economy.spent, "active": economy.active_keystones.duplicate() }


## Cuánto tarda una bajada nueva en llegar a 300 y 400 m en distintos momentos de la campaña, con y sin árbol.
func _benchmark(snapshots: Array[Dictionary], taps: float) -> void:
	var first: Dictionary = { "label": "partida nueva", "tree": {}, "relics": 0, "spent": 0, "active": [] }
	var all: Array[Dictionary] = [first]
	all.append_array(snapshots)
	print("\nBajada nueva (mediana de 5): momento | reliquias | 300 m sin árbol → con árbol | 400 m sin árbol → con árbol")
	for snap: Dictionary in all:
		var cells: PackedStringArray = PackedStringArray()
		for target: float in [300.0, 400.0]:
			var pair: PackedStringArray = PackedStringArray()
			for with_tree: bool in [false, true]:
				pair.append(_clock(_median_time(snap, taps, target, with_tree, 5)))
			cells.append(" → ".join(pair))
		print("  %-22s | %4d | %s | %s" % [snap["label"], snap["relics"], cells[0], cells[1]])


func _median_time(snap: Dictionary, taps: float, target: float, with_tree: bool, seeds: int) -> float:
	var times: Array[float] = []
	for seed_value: int in range(1, seeds + 1):
		var economy: EconomyTree = _new_economy(seed_value * 17, taps)
		economy.relics = snap["relics"]
		if with_tree:
			economy.tree = snap["tree"].duplicate()
			economy.active_keystones = snap["active"].duplicate()
			economy.spent = snap["spent"]
		economy.apply_tree()
		economy._reset_run()
		times.append(_time_to(economy, taps, target))
		economy.free()
	times.sort()
	return times[times.size() / 2]


# --- Estrella por estrella ---------------------------------------------------

func _stars(seeds: int, part: int, parts: int) -> void:
	print("Estrella (0 → máximo), con el resto de las de su anillo y anteriores al máximo (sin piedras angulares).")
	print("id | anillo | costo total | 3 golpes/s: sin → con (ahorro) | 5 golpes/s: ahorro | 1 golpe/s: ahorro")
	for position: int in range(part, _tree_data["stars"].size(), parts):
		var star: Dictionary = _tree_data["stars"][position]
		var ring: int = int(star["ring"])
		var base: Dictionary = {}
		var relics: int = 0
		for other: Dictionary in _tree_data["stars"]:
			if int(other["ring"]) <= mini(ring, 3) and not bool(other.get("keystone", false)) and other["id"] != star["id"]:
				base[other["id"]] = int(other["max"])
				relics += _total_cost(other)
		var target: float = 300.0 if ring <= 1 else (350.0 if ring == 2 else 400.0)
		var cells: PackedStringArray = PackedStringArray()
		for taps: float in [3.0, 5.0, 1.0]:
			var without: Dictionary = { "tree": base, "relics": relics, "spent": relics, "active": [] }
			var with_star: Dictionary = without.duplicate(true)
			with_star["tree"][star["id"]] = int(star["max"])
			if bool(star.get("keystone", false)):
				with_star["active"] = [star["id"]]
			var before: float = _median_time(without, taps, target, true, seeds)
			var after: float = _median_time(with_star, taps, target, true, seeds)
			var saved: int = roundi((1.0 - after / before) * 100.0)
			cells.append("%s → %s (%+d%%)" % [_clock(before), _clock(after), saved] if taps == 3.0 else "%+d%%" % saved)
		print("%-14s | %d | %3d | %3d m: %s | %s | %s" % [star["id"], ring, _total_cost(star), int(target), cells[0], cells[1], cells[2]])


# --- Bajadas seguidas --------------------------------------------------------

## Seis bajadas hasta poder volver, una atrás de otra. modo "hoy": +25% por reliquia y sin árbol; "arbol": bonus histórico y
## árbol; "arbol y logros": además las reliquias de los fragmentos.
func _run_descents(mode: String, taps: float, seed_value: int) -> Array[Dictionary]:
	var economy: EconomyTree = _new_economy(seed_value * 31, taps)
	if mode == "hoy":
		economy.bonus_each = float(_balance["prestige"]["bonus_per_relic"])
		economy.bonus_full_until = 0.0
		economy.shift_per_relic = 0.0
	var done: Dictionary = {}
	var log: Array[Dictionary] = []
	var rows: Array[Dictionary] = []
	for number: int in range(6):
		var state: Dictionary = _new_run_state()
		var next_check: float = 0.0
		while economy.prestige_relics() <= 0 and state["clock"] < 4.0 * 3600.0:
			_step(economy, taps, state)
			if mode == "arbol y logros" and state["clock"] >= next_check:
				next_check = state["clock"] + 2.0
				_check_achievements(economy, 1, done, log)
		economy.stats["resets"] = number + 1
		economy.stats["record_depth"] = maxf(float(economy.stats.get("record_depth", 0.0)), economy.depth())
		economy.prestige()
		if mode != "hoy":
			if mode == "arbol y logros":
				_check_achievements(economy, 1, done, log)
			_buy_stars(economy)
			economy._reset_run()
		rows.append({ "time": state["clock"], "relics": economy.relics, "stars": economy.tree.size() })
	economy.free()
	return rows


func _descents(seeds: int) -> void:
	print("Bajadas seguidas hasta poder volver (mediana de %d). Entre paréntesis: reliquias ganadas en total / estrellas encendidas." % seeds)
	for taps: float in [3.0, 1.5, 5.0]:
		print("%.1f golpes/s" % taps)
		for mode: String in ["hoy", "arbol", "arbol y logros"]:
			var all: Array = []
			for seed_value: int in range(1, seeds + 1):
				all.append(_run_descents(mode, taps, seed_value))
			var cells: PackedStringArray = PackedStringArray()
			for number: int in range(6):
				var times: Array = all.map(func(rows: Array) -> float: return rows[number]["time"])
				times.sort()
				cells.append("%s (%d/%d)" % [_clock(times[times.size() / 2]), all[0][number]["relics"], all[0][number]["stars"]])
			print("  %-15s %s" % [mode, " · ".join(cells)])


func _clock(seconds: float) -> String:
	var total: int = roundi(seconds)
	return "%d:%02d" % [total / 60, total % 60]
