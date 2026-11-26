extends SceneTree
## Simula el árbol de reliquias y los logros (v0.7) antes de programarlos. No toca el juego ni la partida guardada.
##
##   godot --headless --path . --script res://tools/simulate_tree.gd -- campaign <arbol.json> [perfil] [semilla] [opciones]
##   godot --headless --path . --script res://tools/simulate_tree.gd -- descents <arbol.json> [semillas] [opciones]
##   godot --headless --path . --script res://tools/simulate_tree.gd -- stars <arbol.json> [semillas] [parte] [partes] [opciones]
##
## perfil: golpes/s (más de MAX_TAPS no cuentan); con "p" al final ("3p") el jugador pasa un 25% del tiempo sin golpear.
## opciones: el nombre de una variante de "variants" en el arbol.json, "sin=<estrella>" (se compra pero no hace nada) y
## "empuje" (en algunos días, cuánto tarda en pasar la meta quien no vuelve a la superficie a propósito).
##
## campaign: un jugador que entra una vez por día, juega 60 minutos y se va (23 h de progreso offline). Compra lo
## que antes se paga solo, vuelve a la superficie cuando las reliquias por minuto dejan de subir y gasta en la
## estrella más barata que pueda. Deja una línea "baja,reliquias,segundos hasta poder volver,anillo 2 completo,
## cruzó una ausencia,meta,día,metros pasados de la meta al volver,reliquias ganadas" por bajada (la usa tools/tree_sim/calibrate.mjs).
## descents: las primeras bajadas seguidas, con las reglas de hoy (+25% por reliquia, sin árbol) y con el árbol.
## stars: qué cambia cada estrella (de 0 a su máximo, con el resto de su anillo y anteriores comprados), medido en
## una bajada que viene de otra igual.
##
## Calibrar la tabla de la meta: node tools/tree_sim/calibrate.mjs <arbol.json> <salida.json> [variante] [vueltas]

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
const MAX_TAPS: float = 6.0
## Perfil con pausas: golpea de PAUSE_BURST segundos y para PAUSE_REST (en promedio, 25% del tiempo sin golpear).
const PAUSE_BURST: Vector2 = Vector2(30.0, 150.0)
const PAUSE_REST: Vector2 = Vector2(10.0, 50.0)
const PAUSE_ACTIVE_SHARE: float = 0.75
## Días que se miran para el ritmo de compras de mitad de campaña.
const MID_FROM: int = 10
const MID_TO: int = 25
const KEYSTONE_PREFERENCE: Array[String] = ["c_mina", "o_apostador", "f_furia", "t_cuenta"]
const BRIDGES: Array[String] = ["p_suerte", "p_mineros", "p_turnos", "p_critica"]
## Piso pedido para una bajada, a 3 golpes/s (s).
const FLOOR_SECONDS: float = 600.0
const ORACLE_SECONDS: float = 660.0
## stars: la meta de cada comparación es adonde llega la base en este tiempo (s).
const STAR_TARGET_SECONDS: float = 720.0
const DESCENTS: int = 8
## "empuje": en qué días se prueba y cuántos metros pasada la meta.
const PUSH_DAYS: Array[int] = [2, 5, 10, 18, 24]
const PUSH_METERS: Array[float] = [20.0, 40.0, 60.0]

var _balance: Dictionary
var _tree_data: Dictionary
var _achievements: Dictionary
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
var _muted: String = ""
var _push_probe: bool = false


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "campaign"
	var path: String = args[1] if args.size() > 1 else "res://tools/tree_sim/arbol_v3.json"
	_balance = _json("res://data/balance.json")
	_tree_data = _json(path)
	_achievements = _json("res://tools/tree_sim/logros.json")
	var plain: PackedStringArray = PackedStringArray()
	var options: PackedStringArray = PackedStringArray()
	for arg: String in args.slice(2):
		if arg == "empuje":
			_push_probe = true
		elif arg.begins_with("sin="):
			_muted = arg.trim_prefix("sin=")
			options.append(arg)
		elif _tree_data.get("variants", {}).has(arg):
			_tree_data.merge(_tree_data["variants"][arg], true)
			options.append(arg)
		else:
			plain.append(arg)
	print("Árbol: %s %s" % [path, " ".join(options)])
	if mode == "stars":
		_stars(int(plain[0]) if plain.size() > 0 else 5, int(plain[1]) if plain.size() > 1 else 0, int(plain[2]) if plain.size() > 2 else 1)
	elif mode == "descents":
		_descents(int(plain[0]) if plain.size() > 0 else 5)
	else:
		_campaign(plain[0] if plain.size() > 0 else "3", int(plain[1]) if plain.size() > 1 else 1)
	quit(0)


## "3" -> 3 golpes/s; "3p" -> 3 golpes/s con pausas.
func _profile(text: String) -> Dictionary:
	return { "taps": minf(float(text.trim_suffix("p")), MAX_TAPS), "pauses": text.ends_with("p"), "label": text }


func _profile_name(profile: Dictionary) -> String:
	return "%s golpes/s%s" % [str(profile["label"]).trim_suffix("p"), " con pausas" if profile["pauses"] else ""]


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
	economy.muted = _muted
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
		var reached: bool = false
		if entry.has("day"):
			reached = day >= int(entry["day"])
		elif entry["stat"] == "overshoot":
			# Pasar la meta de la bajada en curso por "target" metros, con la meta en "meta" m o más.
			reached = economy.return_depth() >= float(entry["meta"]) and economy.depth() - economy.return_depth() >= float(entry["target"])
		else:
			reached = float(stats.get(entry["stat"], 0.0)) >= float(entry["target"])
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


## Un paso de juego. `clock` es el tiempo de la bajada.
func _step(economy: EconomyTree, taps: float, state: Dictionary) -> void:
	var current: float = taps
	if state["pauses"]:
		if state["rest"] > 0.0:
			current = 0.0
			state["rest"] -= STEP
			if state["rest"] <= 0.0:
				state["burst"] = _random.randf_range(PAUSE_BURST.x, PAUSE_BURST.y)
		else:
			state["burst"] -= STEP
			if state["burst"] <= 0.0:
				state["rest"] = _random.randf_range(PAUSE_REST.x, PAUSE_REST.y)
	economy.taps_per_second = current
	economy.advance_streak(STEP)
	economy.tick(STEP)
	economy.advance_ability(STEP)
	if economy.ability_ready():
		if state["use_at"] < 0.0:
			state["use_at"] = state["clock"] + _random.randf() * ABILITY_DELAY
		if state["clock"] >= state["use_at"]:
			economy.use_ability()
			state["use_at"] = -1.0
	state["hits"] += current * STEP
	while state["hits"] >= 1.0:
		economy.hit()
		state["hits"] -= 1.0
	state["shop"] += STEP
	if state["shop"] >= SHOP_EVERY:
		state["shop"] = 0.0
		# Las compras se piensan con el ritmo de siempre, no con el de este instante.
		economy.taps_per_second = taps
		_shop(economy, taps * (PAUSE_ACTIVE_SHARE if state["pauses"] else 1.0))
		economy.taps_per_second = current
	state["clock"] += STEP


func _new_run_state(pauses: bool = false) -> Dictionary:
	return { "clock": 0.0, "hits": 0.0, "shop": SHOP_EVERY, "use_at": -1.0, "best_rate": 0.0, "best_time": 0.0, "ready": -1.0, "away": false,
		"pauses": pauses, "burst": _random.randf_range(PAUSE_BURST.x, PAUSE_BURST.y), "rest": 0.0 }


func _play(economy: EconomyTree, taps: float, seconds: float, pauses: bool = false, state: Dictionary = {}) -> Dictionary:
	if state.is_empty():
		state = _new_run_state(pauses)
	var until: float = state["clock"] + seconds
	while state["clock"] < until:
		_step(economy, taps, state)
	return state


func _time_to(economy: EconomyTree, taps: float, target: float, pauses: bool = false) -> float:
	var state: Dictionary = _new_run_state(pauses)
	while economy.depth() < target and state["clock"] < 4.0 * 3600.0:
		_step(economy, taps, state)
	return state["clock"]


# --- Campaña -----------------------------------------------------------------

func _campaign(label: String, seed_value: int) -> void:
	var profile: Dictionary = _profile(label)
	var taps: float = profile["taps"]
	var economy: EconomyTree = _new_economy(seed_value, taps)
	var done: Dictionary = {}
	var log: Array[Dictionary] = []
	var events: Dictionary = {}
	var descents: Array[Dictionary] = []
	var purchases: Array[int] = []
	var state: Dictionary = _new_run_state(profile["pauses"])
	var played: float = 0.0
	var costs: int = 0
	var rings: Dictionary = {}
	var total_levels: int = 0
	for star: Dictionary in _tree_data["stars"]:
		costs += _total_cost(star)
		total_levels += int(star["max"])
		rings[int(star["ring"])] = int(rings.get(int(star["ring"]), 0)) + _total_cost(star)
	print("%s, semilla %d. El árbol entero cuesta %d reliquias en %d compras (por anillo: %s)." % [_profile_name(profile), seed_value, costs, total_levels, str(rings)])
	print("día | reliquias ganadas (gastadas) | compras del día | niveles | resets | se puede volver a los (mín/mediana) | bajada completa (mediana) | récord | meta | logros (frag.)")
	var day: int = 1
	var claimed_start: int = 0
	var ring2_start: bool = false
	while day <= MAX_DAYS and not events.has("completo"):
		if day > 1:
			economy.advance_ability(AWAY)
			economy.apply_offline(AWAY)
			economy.dismiss_offline_report()
			economy.streak_seconds = 0.0
			state["away"] = true
		var session: float = 0.0
		var today: Array[Dictionary] = []
		var next_check: float = 0.0
		var levels_start: int = economy.total_levels()
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
			var descent: Dictionary = { "day": day, "ready": state["ready"], "time": state["clock"], "gained": gained, "target": economy.return_depth(), "away": state["away"], "ring2": ring2_start }
			descents.append(descent)
			today.append(descent)
			print("baja,%d,%.0f,%d,%d,%.0f,%d,%.1f,%d" % [claimed_start, descent["ready"], int(ring2_start), int(descent["away"]), descent["target"], day, economy.depth() - economy.return_depth(), gained])
			economy.prestige()
			_check_achievements(economy, day, done, log)
			var lit: Array[String] = _buy_stars(economy)
			if int(economy.stats["resets"]) == 1:
				print("  primer reset a los %s: %d reliquias (con fragmentos) → encendió %s, sobran %d" % [_clock(played), economy.relics, ", ".join(lit), economy.available()])
			economy.fix_target()
			if economy.run_gold <= 0.0:
				economy._reset_run()
			claimed_start = economy.claimed
			ring2_start = _ring_done(economy, 2)
			state = _new_run_state(profile["pauses"])
			_record_events(economy, events, day, played)
			if _push_probe and day in PUSH_DAYS and not events.has("probado %d" % day):
				events["probado %d" % day] = true
				_probe_push(economy, profile, day)
		var bought: int = economy.total_levels() - levels_start
		purchases.append(bought)
		print(_day_line(economy, day, bought, today, done))
		day += 1
	print("\nHitos (día de juego, horas jugadas):")
	for key: String in ["anillo 2 abierto", "anillo 3 abierto", "anillo 1 completo", "anillo 2 completo", "primera piedra angular", "primer puente", "anillo 3 completo", "completo"]:
		print("  %s: %s" % [key, events.get(key, "no se llegó")])
	_report_purchases(purchases)
	_report_descents(descents)
	_report_sources(economy)
	_report_achievements(done, log)
	economy.free()


func _day_line(economy: EconomyTree, day: int, bought: int, today: Array[Dictionary], done: Dictionary) -> String:
	var ready: Array = today.filter(func(d: Dictionary) -> bool: return not d["away"]).map(func(d: Dictionary) -> float: return d["ready"])
	var full: Array = today.filter(func(d: Dictionary) -> bool: return not d["away"]).map(func(d: Dictionary) -> float: return d["time"])
	ready.sort()
	full.sort()
	var ready_text: String = "%s / %s" % [_clock(ready[0]), _clock(ready[ready.size() / 2])] if not ready.is_empty() else "—"
	var full_text: String = _clock(full[full.size() / 2]) if not full.is_empty() else "—"
	return "%3d | %5d (%d) | %2d | %3d | %3d | %13s | %6s | %3d m | %3d m | %2d (%d)" % [day, economy.relics, economy.spent, bought, economy.total_levels(),
		int(economy.stats.get("resets", 0)), ready_text, full_text, int(economy.stats.get("record_depth", 0.0)), int(economy.return_depth()), done.size(), int(economy.stats.get("fragments", 0))]


## Desde el arranque de una bajada, cuánto juego activo hace falta para pasar la meta por PUSH_METERS.
func _probe_push(economy: EconomyTree, profile: Dictionary, day: int) -> void:
	var probe: EconomyTree = economy.clone()
	var state: Dictionary = _new_run_state(profile["pauses"])
	var cells: PackedStringArray = PackedStringArray()
	for meters: float in PUSH_METERS:
		while probe.depth() < economy.return_depth() + meters and state["clock"] < 4.0 * 3600.0:
			_step(probe, profile["taps"], state)
		cells.append("+%d m: %s" % [int(meters), _clock(state["clock"]) if state["clock"] < 4.0 * 3600.0 else "más de 4 h"])
	print("empuje, día %d, meta %d m: %s" % [day, int(economy.return_depth()), " · ".join(cells)])
	probe.free()


## Compras de estrellas por día en la mitad de la campaña (solo días jugados antes de completar el árbol).
func _report_purchases(purchases: Array[int]) -> void:
	var mid: Array = purchases.slice(MID_FROM - 1, mini(MID_TO, purchases.size() - 1))
	if mid.is_empty():
		return
	var total: int = 0
	for count: int in mid:
		total += count
	var sorted_mid: Array = mid.duplicate()
	sorted_mid.sort()
	print("\nCompras por día, días %d–%d: mínimo %d · mediana %d · promedio %.1f · días con menos de 3: %d de %d" % [MID_FROM, MID_FROM + mid.size() - 1, sorted_mid[0], sorted_mid[sorted_mid.size() / 2],
		float(total) / mid.size(), mid.filter(func(count: int) -> bool: return count < 3).size(), mid.size()])


func _report_descents(descents: Array[Dictionary]) -> void:
	print("\nPrimeras %d bajadas (se puede volver a los → volvió a los; meta; reliquias):" % DESCENTS)
	for i: int in range(mini(DESCENTS, descents.size())):
		var d: Dictionary = descents[i]
		print("  %d.ª: %s → %s · %d m · +%d%s" % [i + 1, _clock(d["ready"]), _clock(d["time"]), int(d["target"]), d["gained"], " (venía de una ausencia)" if d["away"] else ""])
	for after: bool in [false, true]:
		var active: Array = descents.filter(func(d: Dictionary) -> bool: return not d["away"] and d["ring2"] == after)
		var ready: Array = active.map(func(d: Dictionary) -> float: return d["ready"])
		ready.sort()
		var full: Array = active.map(func(d: Dictionary) -> float: return d["time"])
		full.sort()
		var count: int = ready.size()
		if count == 0:
			continue
		var below: int = ready.filter(func(t: float) -> bool: return t < FLOOR_SECONDS).size()
		print("%s: %d bajadas sin ausencia. Se puede volver a los: mínimo %s · 5%% %s · mediana %s. Completa mediana %s. Bajo %s: %d (%.1f%%); bajo 9:00: %d." % [
			"Con el anillo 2 completo" if after else "Hasta completar el anillo 2", count, _clock(ready[0]), _clock(ready[count / 20]), _clock(ready[count / 2]), _clock(full[count / 2]),
			_clock(FLOOR_SECONDS), below, 100.0 * below / count, ready.filter(func(t: float) -> bool: return t < 540.0).size()])


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
	print("Mejor bajada: %d reliquias · récord %d m" % [int(economy.stats.get("best_reset", 0)), int(economy.stats.get("record_depth", 0.0))])


func _report_achievements(done: Dictionary, log: Array[Dictionary]) -> void:
	var missing: PackedStringArray = PackedStringArray()
	var total_fragments: int = 0
	for entry: Dictionary in _achievements["list"]:
		total_fragments += int(_achievements["fragments"][entry["tier"]])
		if not done.has(entry["name"]):
			missing.append(entry["name"])
	print("Logros: %d en total = %d fragmentos = %d reliquias. Sin conseguir: %s" % [_achievements["list"].size(), total_fragments, total_fragments / int(_tree_data.get("fragments_per_relic", 10)), ", ".join(missing)])
	var when: PackedStringArray = PackedStringArray()
	for item: Dictionary in log:
		if item["name"] in ["Mil escaleras", "Museo ambulante", "El corazón del mundo"]:
			when.append("%s (día %d)" % [item["name"], item["day"]])
	print("Los tres logros ajustados: " + (", ".join(when) if not when.is_empty() else "ninguno"))


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


## Una economía con las estrellas `levels` y `relics` reliquias ganadas (para el bonus histórico), con la meta de la
## bajada en `target` metros.
func _build(seed_value: int, taps: float, levels: Dictionary, relics: int, keystone: String, target: float) -> EconomyTree:
	var economy: EconomyTree = _new_economy(seed_value, taps)
	economy.relics = relics
	economy.spent = relics
	economy.tree = levels.duplicate()
	economy.active_keystones = [keystone] if keystone != "" else []
	economy.run_shift = maxf(target - economy.prestige_min_depth(), 0.0)
	economy.apply_tree()
	economy._reset_run()
	return economy


## La misma economía parada al empezar una bajada que viene de otra igual (así cuentan las estrellas que arrastran).
func _build_warm(seed_value: int, taps: float, levels: Dictionary, relics: int, keystone: String, target: float, pauses: bool = false) -> EconomyTree:
	var economy: EconomyTree = _build(seed_value, taps, levels, relics, keystone, target)
	_time_to(economy, taps, maxf(target, economy.return_depth()), pauses)
	economy.prestige()
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

	# La meta de la fila: adonde llega la base en STAR_TARGET_SECONDS viniendo de una bajada igual.
	var target: float = 0.0
	for seed_value: int in range(1, seeds + 1):
		var cold: EconomyTree = _build(seed_value * 17, 3.0, base, relics, "", 0.0)
		_play(cold, 3.0, STAR_TARGET_SECONDS)
		var warm: EconomyTree = _build_warm(seed_value * 17, 3.0, base, relics, "", cold.depth())
		_play(warm, 3.0, STAR_TARGET_SECONDS)
		target += warm.depth() / seeds
		cold.free()
		warm.free()

	var cells: PackedStringArray = PackedStringArray()
	for label: String in ["3", "1.5", "5", "3p"]:
		var profile: Dictionary = _profile(label)
		var before: float = _mean_time(base, relics, "", profile, target, seeds)
		var after: float = _mean_time(full, relics, keystone, profile, target, seeds)
		var saved: float = (1.0 - after / before) * 100.0
		cells.append("%s → %s (%+.0f%%)" % [_clock(before), _clock(after), saved] if label == "3" else "%+.0f%%" % saved)
	print("%-14s | anillo %d | %4d | meta %3d m: %s | %s | %s | %s" % [star["id"], ring, _total_cost(star), int(target), cells[0], cells[1], cells[2], cells[3]])

	# Métricas sin azar sobre una bajada a mitad de camino (10 min a 3 golpes/s): lo que la prueba de tiempo no ve.
	var mid: EconomyTree = _build_warm(7, 3.0, base, relics, "", target)
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


## Cuántos segundos de juego activo (con el ingreso `income`) vale una ausencia de `hours`.
func _afk_minutes(economy: EconomyTree, hours: float, income: float) -> float:
	var probe: EconomyTree = economy.clone()
	var report: Dictionary = probe.apply_offline(hours * 3600.0)
	probe.free()
	return float(report.get("gold", 0.0)) / income


## Tiempo medio hasta `target` de una bajada que viene de otra igual.
func _mean_time(levels: Dictionary, relics: int, keystone: String, profile: Dictionary, target: float, seeds: int) -> float:
	var total: float = 0.0
	for seed_value: int in range(1, seeds + 1):
		var economy: EconomyTree = _build_warm(seed_value * 17, profile["taps"], levels, relics, keystone, target, profile["pauses"])
		total += _time_to(economy, profile["taps"], target, profile["pauses"])
		economy.free()
	return total / seeds


# --- Bajadas seguidas --------------------------------------------------------

## DESCENTS bajadas, volviendo apenas se puede, una atrás de otra. modo "hoy": +25% por reliquia y sin árbol;
## "arbol": árbol sin logros; "arbol y logros": además las reliquias de los fragmentos.
func _run_descents(mode: String, profile: Dictionary, seed_value: int) -> Array[Dictionary]:
	var taps: float = profile["taps"]
	var economy: EconomyTree = _today_economy(seed_value * 31, taps) if mode == "hoy" else _new_economy(seed_value * 31, taps)
	var done: Dictionary = {}
	var log: Array[Dictionary] = []
	var rows: Array[Dictionary] = []
	for number: int in range(DESCENTS):
		var state: Dictionary = _new_run_state(profile["pauses"])
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
	for label: String in ["3", "3p", "1.5", "5", "6"]:
		var profile: Dictionary = _profile(label)
		print(_profile_name(profile))
		for mode: String in ["hoy", "arbol", "arbol y logros"]:
			var all: Array = []
			for seed_value: int in range(1, seeds + 1):
				all.append(_run_descents(mode, profile, seed_value))
			var cells: PackedStringArray = PackedStringArray()
			for number: int in range(DESCENTS):
				var times: Array = all.map(func(rows: Array) -> float: return rows[number]["time"])
				times.sort()
				cells.append("%s (%d/%d/%d)" % [_clock(times[times.size() / 2]), int(all[0][number]["target"]), all[0][number]["relics"], all[0][number]["stars"]])
			print("  %-15s %s" % [mode, " · ".join(cells)])


func _clock(seconds: float) -> String:
	var total: int = roundi(seconds)
	return "%d:%02d" % [total / 60, total % 60]
