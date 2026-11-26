extends SceneTree
## Simula el árbol de reliquias y los logros (v0.7) antes de programarlos. No toca el juego ni la partida guardada.
##
##   godot --headless --path . --script res://tools/simulate_tree.gd -- campaign <arbol.json> [golpes/s] [semilla] [oraculo]
##   godot --headless --path . --script res://tools/simulate_tree.gd -- descents <arbol.json> [semillas]
##   godot --headless --path . --script res://tools/simulate_tree.gd -- stars <arbol.json> [semillas] [parte] [partes]
##
## campaign: un jugador que entra una vez por día, juega 60 minutos y se va (23 h de progreso offline). Compra lo
## que antes se paga solo, vuelve a la superficie cuando las reliquias por minuto dejan de subir y gasta en la
## estrella más barata que pueda. Con "oraculo" anota además, al empezar cada bajada, hasta qué profundidad llega
## en ORACLE_SECONDS (para calibrar cuánto correr la profundidad de volver).
## descents: las primeras bajadas seguidas, con las reglas de hoy (+25% por reliquia, sin árbol) y con el árbol.
## stars: qué cambia cada estrella (de 0 a su máximo, con el resto de su anillo y anteriores comprados).

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
const KEYSTONE_PREFERENCE: Array[String] = ["c_mina", "o_apostador", "f_furia", "t_cuenta"]
const BRIDGES: Array[String] = ["p_suerte", "p_mineros", "p_turnos", "p_critica"]
## Piso pedido para una bajada, a 3 golpes/s (s).
const FLOOR_SECONDS: float = 600.0
const ORACLE_SECONDS: float = 660.0
## stars: la meta de cada comparación es adonde llega la base en este tiempo (s).
const STAR_TARGET_SECONDS: float = 720.0
const DESCENTS: int = 8

var _balance: Dictionary
var _tree_data: Dictionary
var _achievements: Dictionary
var _random: RandomNumberGenerator = RandomNumberGenerator.new()


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "campaign"
	var path: String = args[1] if args.size() > 1 else "res://tools/tree_sim/arbol_v2.json"
	_balance = _json("res://data/balance.json")
	_tree_data = _json(path)
	_achievements = _json("res://tools/tree_sim/logros.json")
	print("Árbol: %s" % path)
	if mode == "stars":
		_stars(int(args[2]) if args.size() > 2 else 5, int(args[3]) if args.size() > 3 else 0, int(args[4]) if args.size() > 4 else 1)
	elif mode == "descents":
		_descents(int(args[2]) if args.size() > 2 else 5)
	else:
		_campaign(float(args[2]) if args.size() > 2 else 3.0, int(args[3]) if args.size() > 3 else 1, args.size() > 4 and args[4] == "oraculo")
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
	economy.setup(_balance, _tree_data["stars"], _tree_data.get("offline", {}))
	economy.rng.seed = seed_value
	economy.taps_per_second = taps
	var bonus: Dictionary = _tree_data.get("relic_bonus", {})
	economy.bonus_each = float(bonus.get("each", 0.05))
	economy.bonus_full_until = float(bonus.get("full_until", 0.0))
	economy.bonus_after = float(bonus.get("after", 0.0))
	economy.return_rule = _tree_data.get("return", {})
	_random.seed = seed_value + 1
	return economy


## Las reglas de hoy: sin árbol, +25% por reliquia, AFK del balance y la profundidad de volver fija.
func _today_economy(seed_value: int, taps: float) -> EconomyTree:
	var economy: EconomyTree = EconomyTree.new()
	economy.setup(_balance, _tree_data["stars"])
	economy.rng.seed = seed_value
	economy.taps_per_second = taps
	economy.bonus_each = float(_balance["prestige"]["bonus_per_relic"])
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
	stats["bridges"] = BRIDGES.filter(func(id: String) -> bool: return economy.level_of(id) > 0).size()
	var complete: bool = true
	for ring: int in range(5):
		complete = complete and _ring_done(economy, ring)
	stats["complete"] = int(complete)
	var per_relic: int = int(_tree_data.get("fragments_per_relic", 10))
	for entry: Dictionary in _achievements["list"]:
		if done.has(entry["name"]):
			continue
		var reached: bool = (day >= int(entry["day"])) if entry.has("day") else float(stats.get(entry["stat"], 0.0)) >= float(entry["target"])
		if reached:
			done[entry["name"]] = day
			var fragments: int = int(_achievements["fragments"][entry["tier"]])
			var before: int = int(stats.get("fragments", 0))
			stats["fragments"] = before + fragments
			economy.relics += (before + fragments) / per_relic - before / per_relic
			log.append({ "name": entry["name"], "day": day, "fragments": fragments })


# --- Jugar -------------------------------------------------------------------

func _income(economy: EconomyTree, taps: float) -> float:
	return economy.gold_per_second() + taps * economy.hit_average()


## Todo lo que entra por segundo jugando: cuadrilla, golpes, cofres y dinamita.
func _active_income(economy: EconomyTree, taps: float) -> float:
	var dynamite: float = economy.ability_reward() / (economy.ability_cooldown() + ABILITY_DELAY * 0.5)
	return _income(economy, taps) + economy.chest_income(taps) + dynamite


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
	return { "clock": 0.0, "hits": 0.0, "shop": SHOP_EVERY, "use_at": -1.0, "best_rate": 0.0, "best_time": 0.0, "ready": -1.0, "away": false }


func _play(economy: EconomyTree, taps: float, seconds: float, state: Dictionary = {}) -> Dictionary:
	if state.is_empty():
		state = _new_run_state()
	var until: float = state["clock"] + seconds
	while state["clock"] < until:
		_step(economy, taps, state)
	return state


func _time_to(economy: EconomyTree, taps: float, target: float) -> float:
	var state: Dictionary = _new_run_state()
	while economy.depth() < target and state["clock"] < 4.0 * 3600.0:
		_step(economy, taps, state)
	return state["clock"]


# --- Campaña -----------------------------------------------------------------

func _campaign(taps: float, seed_value: int, oracle: bool) -> void:
	var economy: EconomyTree = _new_economy(seed_value, taps)
	var done: Dictionary = {}
	var log: Array[Dictionary] = []
	var events: Dictionary = {}
	var descents: Array[Dictionary] = []
	var state: Dictionary = _new_run_state()
	var played: float = 0.0
	var costs: int = 0
	var rings: Dictionary = {}
	for star: Dictionary in _tree_data["stars"]:
		costs += _total_cost(star)
		rings[int(star["ring"])] = int(rings.get(int(star["ring"]), 0)) + _total_cost(star)
	print("%.1f golpes/s, semilla %d. El árbol entero cuesta %d reliquias (por anillo: %s)." % [taps, seed_value, costs, str(rings)])
	print("día | reliquias ganadas (gastadas) | estrellas | niveles | resets | se puede volver a los (mín/mediana) | bajada completa (mediana) | récord | meta | logros (frag.)")
	var day: int = 1
	while day <= MAX_DAYS and not events.has("completo"):
		if day > 1:
			economy.advance_ability(AWAY)
			economy.apply_offline(AWAY)
			economy.dismiss_offline_report()
			state["away"] = true
		var session: float = 0.0
		var today: Array[Dictionary] = []
		var next_check: float = 0.0
		while session < SESSION and not events.has("completo"):
			_step(economy, taps, state)
			session += STEP
			played += STEP
			if state["ready"] < 0.0 and economy.prestige_relics() > 0:
				state["ready"] = state["clock"]
			if session < next_check:
				continue
			next_check = session + 2.0
			_check_achievements(economy, day, done, log)
			if not _should_reset(economy, state):
				continue
			var gained: int = economy.prestige_relics()
			economy.stats["best_reset"] = maxi(int(economy.stats.get("best_reset", 0)), gained)
			economy.stats["resets"] = int(economy.stats.get("resets", 0)) + 1
			var descent: Dictionary = { "day": day, "ready": state["ready"], "time": state["clock"], "gained": gained, "target": economy.return_depth(), "depth": economy.depth(), "away": state["away"] }
			descents.append(descent)
			today.append(descent)
			economy.prestige()
			_check_achievements(economy, day, done, log)
			var lit: Array[String] = _buy_stars(economy)
			if int(economy.stats["resets"]) == 1:
				print("  primer reset a los %s: %d reliquias (con fragmentos) → encendió %s, sobran %d" % [_clock(played), economy.relics, ", ".join(lit), economy.available()])
			economy.fix_target()
			if economy.run_gold <= 0.0:
				economy._reset_run()
			if oracle:
				_oracle(economy, taps, day)
			state = _new_run_state()
			_record_events(economy, events, day, played)
		print(_day_line(economy, day, today, done))
		day += 1
	print("\nHitos (día de juego, horas jugadas):")
	for key: String in ["anillo 2 abierto", "anillo 3 abierto", "anillo 1 completo", "anillo 2 completo", "primera piedra angular", "primer puente", "anillo 3 completo", "completo"]:
		print("  %s: %s" % [key, events.get(key, "no se llegó")])
	_report_descents(descents)
	_report_sources(economy)
	_report_achievements(done, log)
	economy.free()


func _day_line(economy: EconomyTree, day: int, today: Array[Dictionary], done: Dictionary) -> String:
	var ready: Array = today.filter(func(d: Dictionary) -> bool: return not d["away"]).map(func(d: Dictionary) -> float: return d["ready"])
	var full: Array = today.filter(func(d: Dictionary) -> bool: return not d["away"]).map(func(d: Dictionary) -> float: return d["time"])
	ready.sort()
	full.sort()
	var ready_text: String = "%s / %s" % [_clock(ready[0]), _clock(ready[ready.size() / 2])] if not ready.is_empty() else "—"
	var full_text: String = _clock(full[full.size() / 2]) if not full.is_empty() else "—"
	return "%3d | %5d (%d) | %2d | %3d | %3d | %13s | %6s | %3d m | %3d m | %2d (%d)" % [day, economy.relics, economy.spent, economy.tree.size(), economy.total_levels(),
		int(economy.stats.get("resets", 0)), ready_text, full_text, int(economy.stats.get("record_depth", 0.0)), int(economy.return_depth()), done.size(), int(economy.stats.get("fragments", 0))]


func _report_descents(descents: Array[Dictionary]) -> void:
	print("\nPrimeras %d bajadas (se puede volver a los → volvió a los; meta; reliquias):" % DESCENTS)
	for i: int in range(mini(DESCENTS, descents.size())):
		var d: Dictionary = descents[i]
		print("  %d.ª: %s → %s · %d m · +%d%s" % [i + 1, _clock(d["ready"]), _clock(d["time"]), int(d["target"]), d["gained"], " (venía de una ausencia)" if d["away"] else ""])
	var active: Array = descents.filter(func(d: Dictionary) -> bool: return not d["away"])
	var ready: Array = active.map(func(d: Dictionary) -> float: return d["ready"])
	ready.sort()
	var full: Array = active.map(func(d: Dictionary) -> float: return d["time"])
	full.sort()
	var count: int = ready.size()
	if count == 0:
		return
	print("Bajadas sin ausencia en el medio: %d. Se puede volver a los: mínimo %s · 5%% %s · 25%% %s · mediana %s. Bajada completa mediana %s." % [count, _clock(ready[0]), _clock(ready[count / 20]), _clock(ready[count / 4]), _clock(ready[count / 2]), _clock(full[count / 2])])
	print("Por debajo del piso de %s: %d (%.1f%%). Por debajo de 9:00: %d. Bajadas que cruzan una ausencia: %d." % [_clock(FLOOR_SECONDS), ready.filter(func(t: float) -> bool: return t < FLOOR_SECONDS).size(),
		100.0 * ready.filter(func(t: float) -> bool: return t < FLOOR_SECONDS).size() / count, ready.filter(func(t: float) -> bool: return t < 540.0).size(), descents.size() - count])


func _report_sources(economy: EconomyTree) -> void:
	var keys: Array[String] = ["gold_hits", "gold_crew", "gold_chest", "gold_ability", "gold_offline"]
	var names: Array[String] = ["golpes", "cuadrilla jugando", "cofres", "dinamita", "AFK"]
	var total: float = 0.0
	for key: String in keys:
		total += float(economy.stats.get(key, 0.0))
	var cells: PackedStringArray = PackedStringArray()
	for i: int in range(keys.size()):
		cells.append("%s %.1f%%" % [names[i], 100.0 * float(economy.stats.get(keys[i], 0.0)) / maxf(total, 1.0)])
	print("\nDe dónde salió el oro en toda la campaña: " + " · ".join(cells))
	print("Cofres: %d (Legendarios %d) · reliquias de cofres %d · reliquias de bajadas %d · de logros %d" % [int(economy.stats.get("chests", 0)), int(economy.stats.get("chest_legendary", 0)),
		int(economy.stats.get("chest_relics", 0)), economy.claimed, int(economy.stats.get("fragments", 0)) / int(_tree_data.get("fragments_per_relic", 10))])


func _report_achievements(done: Dictionary, log: Array[Dictionary]) -> void:
	var missing: PackedStringArray = PackedStringArray()
	var total_fragments: int = 0
	for entry: Dictionary in _achievements["list"]:
		total_fragments += int(_achievements["fragments"][entry["tier"]])
		if not done.has(entry["name"]):
			missing.append(entry["name"])
	print("Logros: %d en total = %d fragmentos = %d reliquias. Sin conseguir: %s" % [_achievements["list"].size(), total_fragments, total_fragments / int(_tree_data.get("fragments_per_relic", 10)), ", ".join(missing)])
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


## Anota hasta dónde llega el jugador en ORACLE_SECONDS arrancando la bajada que empieza ahora.
func _oracle(economy: EconomyTree, taps: float, day: int) -> void:
	var probe: EconomyTree = economy.clone()
	var state: Dictionary = _play(probe, taps, FLOOR_SECONDS)
	var at_floor: float = probe.depth()
	_play(probe, taps, ORACLE_SECONDS - FLOOR_SECONDS, state)
	print("oraculo,%d,%d,%d,%d,%d,%d,%.0f,%.0f" % [day, int(economy.stats["resets"]), economy.total_levels(), economy.claimed, economy.spent, economy.relics, at_floor, probe.depth()])
	probe.free()


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


func _record_events(economy: EconomyTree, events: Dictionary, day: int, played: float) -> void:
	var stamp: String = "día %d (%.1f h)" % [day, played / 3600.0]
	var checks: Dictionary = {
		"anillo 2 abierto": _ring_open(economy, { "ring": 2 }),
		"anillo 3 abierto": _ring_open(economy, { "ring": 3 }),
		"anillo 1 completo": _ring_done(economy, 1),
		"anillo 2 completo": _ring_done(economy, 2),
		"anillo 3 completo": _ring_done(economy, 3),
		"primera piedra angular": KEYSTONE_PREFERENCE.any(func(id: String) -> bool: return economy.level_of(id) > 0),
		"primer puente": BRIDGES.any(func(id: String) -> bool: return economy.level_of(id) > 0),
		"completo": _ring_done(economy, 0) and _ring_done(economy, 1) and _ring_done(economy, 2) and _ring_done(economy, 3) and _ring_done(economy, 4),
	}
	for key: String in checks:
		if checks[key] and not events.has(key):
			events[key] = stamp


# --- Estrella por estrella ---------------------------------------------------

func _stars(seeds: int, part: int, parts: int) -> void:
	for position: int in range(part, _tree_data["stars"].size(), parts):
		_measure_star(_tree_data["stars"][position], seeds)


## Una economía con las estrellas `levels` y `relics` reliquias ganadas (para el bonus histórico).
func _build(seed_value: int, taps: float, levels: Dictionary, relics: int, keystone: String) -> EconomyTree:
	var economy: EconomyTree = _new_economy(seed_value, taps)
	economy.relics = relics
	economy.spent = relics
	economy.tree = levels.duplicate()
	economy.active_keystones = [keystone] if keystone != "" else []
	economy.apply_tree()
	economy._reset_run()
	return economy


func _measure_star(star: Dictionary, seeds: int) -> void:
	var ring: int = int(star["ring"])
	var base: Dictionary = {}
	var relics: int = 0
	for other: Dictionary in _tree_data["stars"]:
		if int(other["ring"]) <= mini(ring, 3) and not bool(other.get("keystone", false)) and other["id"] != star["id"]:
			base[other["id"]] = int(other["max"])
			relics += _total_cost(other)
	var full: Dictionary = base.duplicate()
	full[star["id"]] = int(star["max"])
	var keystone: String = star["id"] if bool(star.get("keystone", false)) else ""
	relics += _total_cost(star)

	var target: float = 0.0
	for seed_value: int in range(1, seeds + 1):
		var probe: EconomyTree = _build(seed_value * 17, 3.0, base, relics, "")
		_play(probe, 3.0, STAR_TARGET_SECONDS)
		target += probe.depth() / seeds
		probe.free()

	var cells: PackedStringArray = PackedStringArray()
	for taps: float in [3.0, 1.5, 5.0]:
		var before: float = _mean_time(base, relics, "", taps, target, seeds)
		var after: float = _mean_time(full, relics, keystone, taps, target, seeds)
		var saved: float = (1.0 - after / before) * 100.0
		cells.append("%s → %s (%+.0f%%)" % [_clock(before), _clock(after), saved] if taps == 3.0 else "%+.0f%%" % saved)
	print("%-14s | anillo %d | %4d | meta %3d m: %s | %s | %s" % [star["id"], ring, _total_cost(star), int(target), cells[0], cells[1], cells[2]])

	# Métricas sin azar sobre una bajada a mitad de camino (10 min a 3 golpes/s): lo que la prueba de tiempo no ve.
	var mid: EconomyTree = _build(7, 3.0, base, relics, "")
	_play(mid, 3.0, FLOOR_SECONDS)
	var lit: EconomyTree = mid.clone()
	lit.tree = full.duplicate()
	lit.active_keystones = [keystone] if keystone != "" else []
	lit.apply_tree()
	var parts_text: PackedStringArray = PackedStringArray()
	var income: float = _active_income(mid, 3.0)
	var lit_income: float = _active_income(lit, 3.0)
	parts_text.append("ingreso jugando %+.0f%%" % ((lit_income / income - 1.0) * 100.0))
	parts_text.append("cofres %.1f%% → %.1f%% del ingreso, %.1f → %.1f cada 10 min" % [100.0 * mid.chest_income(3.0) / income, 100.0 * lit.chest_income(3.0) / lit_income, mid.chest_rate(3.0) * 600.0, lit.chest_rate(3.0) * 600.0])
	parts_text.append("reliquias de cofres/h %.1f → %.1f" % [mid.chest_relics_per_hour(3.0), lit.chest_relics_per_hour(3.0)])
	var afk: PackedStringArray = PackedStringArray()
	for hours: float in [2.0, 8.0, 23.0]:
		afk.append("%d h = %s → %s" % [int(hours), _clock(_afk_minutes(mid, hours, income)), _clock(_afk_minutes(lit, hours, income))])
	parts_text.append("AFK en minutos de juego activo: " + ", ".join(afk))
	print("    " + " · ".join(parts_text))
	mid.free()
	lit.free()

	if star["effects"].any(func(fx: Dictionary) -> bool: return str(fx["type"]).begins_with("keep_")):
		var before: float = _mean_second_time(base, relics, target, seeds)
		var after: float = _mean_second_time(full, relics, target, seeds)
		print("    2.ª bajada seguida: %s → %s (%+.0f%%)" % [_clock(before), _clock(after), (1.0 - after / before) * 100.0])


## Cuántos segundos de juego activo (con el ingreso `income`) vale una ausencia de `hours`.
func _afk_minutes(economy: EconomyTree, hours: float, income: float) -> float:
	var probe: EconomyTree = economy.clone()
	var report: Dictionary = probe.apply_offline(hours * 3600.0)
	probe.free()
	return float(report.get("gold", 0.0)) / income


func _mean_time(levels: Dictionary, relics: int, keystone: String, taps: float, target: float, seeds: int) -> float:
	var total: float = 0.0
	for seed_value: int in range(1, seeds + 1):
		var economy: EconomyTree = _build(seed_value * 17, taps, levels, relics, keystone)
		total += _time_to(economy, taps, target)
		economy.free()
	return total / seeds


## Tiempo de la segunda de dos bajadas seguidas hasta `target` (lo que conservan las estrellas "keep_").
func _mean_second_time(levels: Dictionary, relics: int, target: float, seeds: int) -> float:
	var total: float = 0.0
	for seed_value: int in range(1, seeds + 1):
		var economy: EconomyTree = _build(seed_value * 17, 3.0, levels, relics, "")
		_time_to(economy, 3.0, maxf(target, economy.return_depth()))
		economy.prestige()
		total += _time_to(economy, 3.0, target)
		economy.free()
	return total / seeds


# --- Bajadas seguidas --------------------------------------------------------

## DESCENTS bajadas, volviendo apenas se puede, una atrás de otra. modo "hoy": +25% por reliquia y sin árbol;
## "arbol": árbol sin logros; "arbol y logros": además las reliquias de los fragmentos.
func _run_descents(mode: String, taps: float, seed_value: int) -> Array[Dictionary]:
	var economy: EconomyTree = _today_economy(seed_value * 31, taps) if mode == "hoy" else _new_economy(seed_value * 31, taps)
	var done: Dictionary = {}
	var log: Array[Dictionary] = []
	var rows: Array[Dictionary] = []
	for number: int in range(DESCENTS):
		var state: Dictionary = _new_run_state()
		var next_check: float = 0.0
		var target: float = economy.return_depth()
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
			economy.fix_target()
			economy._reset_run()
		rows.append({ "time": state["clock"], "relics": economy.relics, "stars": economy.tree.size(), "target": target })
	economy.free()
	return rows


func _descents(seeds: int) -> void:
	print("Bajadas seguidas, volviendo apenas se puede (mediana de %d). Entre paréntesis: meta en metros / reliquias ganadas en total / estrellas." % seeds)
	for taps: float in [3.0, 1.5, 5.0]:
		print("%.1f golpes/s" % taps)
		for mode: String in ["hoy", "arbol", "arbol y logros"]:
			var all: Array = []
			for seed_value: int in range(1, seeds + 1):
				all.append(_run_descents(mode, taps, seed_value))
			var cells: PackedStringArray = PackedStringArray()
			for number: int in range(DESCENTS):
				var times: Array = all.map(func(rows: Array) -> float: return rows[number]["time"])
				times.sort()
				cells.append("%s (%d/%d/%d)" % [_clock(times[times.size() / 2]), int(all[0][number]["target"]), all[0][number]["relics"], all[0][number]["stars"]])
			print("  %-15s %s" % [mode, " · ".join(cells)])


func _clock(seconds: float) -> String:
	var total: int = roundi(seconds)
	return "%d:%02d" % [total / 60, total % 60]
