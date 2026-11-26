extends "res://tools/tree_sim/economy_v06.gd"
## SOLO PARA SIMULAR (v0.7): el Economy real con los efectos del árbol de reliquias encima. No lo usa el juego.
##
## Las reliquias son los puntos que se gastan en el árbol. `relics` es el total ganado en la historia (de él sale un
## bonus pasivo chico: gastar nunca debilita) y `spent` lo gastado en estrellas.

## Se considera que el jugador está golpeando desde este ritmo (piedra angular que premia jugar activo).
const ACTIVE_TAPS: float = 0.5

var stars: Dictionary = {}          # id -> definición (arbol.json)
var tree: Dictionary = {}           # id -> nivel comprado
var active_keystones: Array = []
var spent: int = 0
## Bonus de oro por cada reliquia ganada en la historia.
var bonus_each: float = 0.05
## Desde esta cantidad cada reliquia suma `bonus_after` en vez de `bonus_each` (0 = sin tope).
var bonus_full_until: float = 0.0
var bonus_after: float = 0.0
## Cómo se corre la profundidad de volver: {} = no se corre. Ver shift_now().
var return_rule: Dictionary = {}
## Metros corridos en la bajada en curso (se fijan al empezarla, con fix_target()).
var run_shift: float = 0.0
var claimed: int = 0
## El jugador simulado sostiene el frenesí (golpea al ritmo del umbral o más).
var taps_per_second: float = 3.0
## Estadísticas para los logros y las métricas.
var stats: Dictionary = {}

var _fx_add: Dictionary = {}
var _fx_mul: Dictionary = {}
var _fx_set: Dictionary = {}
var _base: Dictionary = {}
var _balance_data: Dictionary = {}
var _offline_base: Dictionary = {}
var _away: bool = false
## Con qué terminó la bajada anterior (lo que usan las estrellas que escalan con ella): {owned, gps, pick, ability}.
var last_descent: Dictionary = {}
## Estrella comprada a la que se le apagan los efectos, para medir cuánto pesa en la partida ("" = ninguna).
var muted: String = ""
## Racha: segundos golpeando sin parar y segundos desde el último golpe.
var streak_seconds: float = 0.0
var since_hit: float = 1000.0
## Pasado este rato sin golpear, la racha se corta (s).
const STREAK_BREAK: float = 5.0


## `offline_base` pisa valores de la sección "offline" del balance (propuesta de v0.7).
func setup(balance: Dictionary, star_list: Array, offline_base: Dictionary = {}) -> void:
	_balance_data = balance
	_offline_base = offline_base
	if not load_balance(balance):
		push_error(last_error)
	for star: Dictionary in star_list:
		stars[star["id"]] = star
	var offline: Dictionary = _offline.duplicate()
	for key: String in offline_base:
		offline[key] = float(offline_base[key])
	_base = {
		"hit_chance": _loot_hit_chance, "second_chance": _loot_second_chance,
		"weights": _rarity_weights.duplicate(), "milestones": _milestones.duplicate(),
		"milestone_mult": _milestone_multiplier, "crit": _crit.duplicate(),
		"ability": _ability.duplicate(), "offline": offline,
		"frenzy": _frenzy.duplicate(),
	}
	apply_tree()


## Copia con el mismo estado, para probar "qué pasaría si" sin tocar la partida simulada.
func clone() -> Node:
	var other: Node = get_script().new()
	other.setup(_balance_data, stars.values(), _offline_base)
	for key: String in ["bonus_each", "bonus_full_until", "bonus_after", "run_shift", "claimed", "taps_per_second", "spent", "relics", "gold", "run_gold", "pick_level", "ability_level", "ability_cooldown_left", "_revealed", "_max_biome"]:
		other.set(key, get(key))
	other.return_rule = return_rule
	other.last_descent = last_descent.duplicate(true)
	other.muted = muted
	other.streak_seconds = streak_seconds
	other.since_hit = since_hit
	other.tree = tree.duplicate()
	other.active_keystones = active_keystones.duplicate()
	other.stats = stats.duplicate()
	other.owned.assign(owned)
	other.rng.state = rng.state
	other.apply_tree()
	return other


func level_of(id: String) -> int:
	return int(tree.get(id, 0))


func total_levels() -> int:
	var total: int = 0
	for id: String in tree:
		total += int(tree[id])
	return total


func available() -> int:
	return relics - spent


# --- Profundidad de volver -----------------------------------------------------

## Metros que se corre la profundidad de volver según las reliquias ya sacadas de bajadas (las de cofres y logros no
## cuentan). "points" = [[reliquias, metros], ...] en orden creciente: lineal entre puntos, 0 antes del primero y con la
## pendiente del último tramo más allá. La tabla sigue a la fuerza que dan esas reliquias gastadas en el árbol.
func shift_now() -> float:
	if return_rule.is_empty():
		return 0.0
	var points: Array = return_rule["points"]
	if claimed <= float(points[0][0]):
		return float(points[0][1])
	var i: int = 1
	while i < points.size() - 1 and claimed > float(points[i][0]):
		i += 1
	var from: Array = points[i - 1]
	var to: Array = points[i]
	return roundf(lerpf(float(from[1]), float(to[1]), (claimed - float(from[0])) / (float(to[0]) - float(from[0]))))


func fix_target() -> void:
	run_shift = shift_now()


func return_depth() -> float:
	return prestige_min_depth() + run_shift


## La fórmula de hoy medida desde la meta corrida, más una reliquia por cada "extra_every" metros que se corrió: bajar
## a una meta más honda paga más.
func prestige_relics() -> int:
	var gained: int = EconomyMath.relics_for_depth(depth() - run_shift, _prestige["min_depth"], _prestige["depth_offset"], _prestige["depth_step"], _prestige["exponent"])
	var every: float = float(return_rule.get("extra_every", 0.0))
	if gained <= 0 or every <= 0.0:
		return gained
	return gained + int(run_shift / every)


func prestige() -> int:
	if prestige_relics() <= 0:
		return 0
	# Antes de reiniciar: lo que las estrellas "de arrastre" le pasan a la bajada que empieza.
	last_descent = { "owned": owned.duplicate(), "gps": gold_per_second(), "pick": pick_level, "ability": ability_level }
	streak_seconds = 0.0
	since_hit = 1000.0
	var gained: int = super()
	claimed += gained
	return gained


# --- Árbol ---------------------------------------------------------------------

## Nivel que está surtiendo efecto (una piedra angular comprada pero apagada no cuenta).
func _effective_level(id: String) -> int:
	if id == muted:
		return 0
	if bool(stars[id].get("keystone", false)) and not active_keystones.has(id):
		return 0
	return level_of(id)


func apply_tree() -> void:
	_fx_add = {}
	_fx_mul = {}
	_fx_set = {}
	for id: String in tree:
		var lv: int = _effective_level(id)
		if lv <= 0:
			continue
		for fx: Dictionary in stars[id]["effects"]:
			var type: String = fx["type"]
			if fx.has("per_level"):
				_fx_add[type] = float(_fx_add.get(type, 0.0)) + float(fx["per_level"]) * lv
			if fx.has("mul"):
				_fx_mul[type] = float(_fx_mul.get(type, 1.0)) * float(fx["mul"])
			if fx.has("values"):
				_fx_set[type] = float(fx["values"][mini(lv, fx["values"].size()) - 1])
	_loot_hit_chance = _base["hit_chance"] * (1.0 + add("chest_chance"))
	_loot_second_chance = _base["second_chance"] * (1.0 + add("chest_chance")) * (1.0 + add("passive_chest"))
	_rarity_weights.assign(_base["weights"])
	# El peso que ganan las rarezas altas sale de los Comunes: así subir los Raros no hace menos probable un Legendario.
	var gained: float = 0.0
	for index: int in range(_rarities.size()):
		var extra: float = _rarity_weights[index] * add("weight_" + str(_rarities[index]["id"]))
		_rarity_weights[index] += extra
		gained += extra
	for index: int in range(_rarities.size()):
		if _rarities[index]["id"] == "common":
			_rarity_weights[index] = maxf(_rarity_weights[index] - gained, 0.0)
	if _fx_mul.has("no_common"):
		# Sin Comunes: cada una de las otras sale `no_common` veces más seguido que antes (por unidad de tiempo).
		var total: float = 0.0
		var rest: float = 0.0
		for index: int in range(_rarities.size()):
			total += _rarity_weights[index]
			if _rarities[index]["id"] != "common":
				rest += _rarity_weights[index]
			else:
				_rarity_weights[index] = 0.0
		var rate: float = rest * float(_fx_mul["no_common"]) / total
		_loot_hit_chance *= rate
		_loot_second_chance *= rate
	_milestone_multiplier = _fx_set.get("milestone_mult", _base["milestone_mult"])
	_milestones.clear()
	for threshold: int in _base["milestones"]:
		_milestones.append(int(ceil(threshold * (1.0 - add("milestone_discount")))))
	_crit = _base["crit"].duplicate()
	_crit["chance"] = (_crit["chance"] + add("crit_chance")) * mul("crit_chance_mul")
	_crit["multiplier"] = (_crit["multiplier"] + add("crit_mult")) * mul("crit_mult_mul")
	_ability = _base["ability"].duplicate()
	_ability["cooldown"] = _ability["cooldown"] * (1.0 - add("cooldown_cut")) * mul("cooldown_mul")
	_offline = _base["offline"].duplicate()
	_offline["efficiency"] = _fx_set.get("offline_eff", _offline["efficiency"])
	_offline["max_hours"] = _fx_set.get("offline_hours", _offline["max_hours"])


func add(type: String) -> float:
	return float(_fx_add.get(type, 0.0))


func mul(type: String) -> float:
	return float(_fx_mul.get(type, 1.0))


func frenzied() -> bool:
	return taps_per_second >= float(_base["frenzy"]["hits_per_second"]) - add("frenzy_threshold")


func crit_average() -> float:
	return 1.0 + _crit["chance"] * (_crit["multiplier"] - 1.0)


# --- Multiplicadores ---------------------------------------------------------

func relic_multiplier() -> float:
	var full: float = float(relics) if bonus_full_until <= 0.0 else minf(relics, bonus_full_until)
	return (1.0 + full * bonus_each + (relics - full) * bonus_after) * (1.0 + add("gold")) * (1.0 + streak_bonus())


## Racha: un escalón por cada minuto entero golpeando sin parar, hasta el tope. No corre mientras no estás.
func streak_bonus() -> float:
	if _away:
		return 0.0
	return minf(floorf(streak_seconds / 60.0) * float(_fx_set.get("streak_rate", 0.0)), add("streak_cap"))


## Pasa tiempo de juego para la racha (hit() la sostiene).
func advance_streak(delta: float) -> void:
	since_hit += delta
	streak_seconds = streak_seconds + delta if since_hit < STREAK_BREAK else 0.0


func _base_output(index: int) -> float:
	var working: bool = taps_per_second >= ACTIVE_TAPS and not _away
	return super(index) * (1.0 + add("crew")) * mul("crew_active" if working else "crew_idle")


func hit_value() -> float:
	var power: float = pow(_pick["power_base"], pick_level) + add("hit_flat")
	var share: float = _pick["passive_share"] + add("hit_share")
	return (power * multiplier + share * gold_per_second()) * (1.0 + add("hit")) * mul("hit_mul")


## Lo que rinde en promedio un golpe (con crítico, eco y combo): lo usa el comprador simulado.
func hit_average() -> float:
	var combo: float = 1.0 + add("frenzy_hit") if frenzied() else 1.0
	return hit_value() * crit_average() * (1.0 + add("double_hit")) * combo


func hit() -> float:
	since_hit = 0.0
	var amount: float = hit_value()
	if frenzied():
		amount *= 1.0 + add("frenzy_hit")
	var critical: bool = rng.randf() < _crit["chance"]
	if critical:
		amount *= float(_crit["multiplier"])
		_count("crits", 1)
	if add("double_hit") > 0.0 and rng.randf() < add("double_hit"):
		amount *= 2.0
	_count("hits", 1)
	_count("gold_hits", amount)
	_earn(amount)
	_roll_loot(_loot_hit_chance)
	if critical and add("crit_chest") > 0.0:
		_roll_loot(add("crit_chest"))
	return amount


func tick(delta: float) -> void:
	_count("gold_crew", gold_per_second() * delta)
	super(delta)


func _earn(amount: float) -> void:
	# Veta rica: hasta una fracción de la meta de la bajada.
	if add("shallow_fraction") > 0.0 and depth() < add("shallow_fraction") * return_depth():
		amount *= mul("shallow_mul")
	super(amount)


func _count(key: String, amount: float) -> void:
	stats[key] = stats.get(key, 0) + amount


# --- Cofres y dinamita ---------------------------------------------------------

func _open_chest(rarity: int) -> void:
	var times: int = 2 if add("double_chest") > 0.0 and rng.randf() < add("double_chest") else 1
	for i: int in range(times):
		var amount: float = loot_reward(rarity) * (1.0 + add("chest_gold"))
		_earn(amount)
		var given: int = int(_rarities[rarity]["relics"])
		if given > 0:
			var extra: float = add("legendary_relics")
			given += int(extra) + (1 if rng.randf() < extra - int(extra) else 0)
		relics += given
		_count("chests", 1)
		_count("chest_" + str(_rarities[rarity]["id"]), 1)
		_count("gold_chest", amount)
		_count("chest_relics", given)


## Cofres por segundo de juego (en promedio) golpeando a `taps` y con cuadrilla.
func chest_rate(taps: float) -> float:
	return taps * (_loot_hit_chance + _crit["chance"] * add("crit_chest")) + _loot_second_chance


## Oro por segundo que dan los cofres en promedio (sin azar), con la producción de ahora.
func chest_income(taps: float) -> float:
	var table: Array[Dictionary] = loot_table()
	var each: float = 0.0
	for index: int in range(table.size()):
		each += float(table[index]["chance"]) * loot_reward(index)
	return chest_rate(taps) * each * (1.0 + add("chest_gold")) * (1.0 + add("double_chest"))


## Reliquias por hora que dan los cofres en promedio.
func chest_relics_per_hour(taps: float) -> float:
	var table: Array[Dictionary] = loot_table()
	var total: float = 0.0
	for entry: Dictionary in table:
		if int(entry["relics"]) > 0:
			total += float(entry["chance"]) * (int(entry["relics"]) + add("legendary_relics"))
	return chest_rate(taps) * total * (1.0 + add("double_chest")) * 3600.0


func ability_reward() -> float:
	return super() * (1.0 + add("ability")) * mul("ability_mul")


func use_ability() -> float:
	if not ability_ready():
		return 0.0
	var amount: float = ability_reward()
	if add("ability_crit") > 0.0 and rng.randf() < _crit["chance"]:
		amount *= float(_crit["multiplier"])
	_earn(amount)
	ability_cooldown_left = ability_cooldown()
	_count("dynamite", 1)
	_count("gold_ability", amount)
	return amount


func apply_offline(elapsed: float) -> Dictionary:
	_away = true
	var report: Dictionary = super(elapsed)
	if not report.is_empty():
		var extra: float = float(report["gold"]) * add("offline_gain")
		if extra > 0.0:
			_earn(extra)
		report["gold"] = float(report["gold"]) + extra
		_count("gold_offline", report["gold"])
	_away = false
	return report


# --- Compras y reinicio --------------------------------------------------------

func generator_cost(index: int, count: int) -> float:
	return EconomyMath.bulk_cost(_generators[index]["base_cost"], _cost_growth, owned[index], count) * (1.0 - add("discount"))


func buy_units(index: int, count: int) -> bool:
	var cost: float = generator_cost(index, count)
	if cost > gold:
		return false
	gold -= cost
	owned[index] += count
	return true


func _reset_run() -> void:
	super()
	if owned.is_empty() or last_descent.is_empty():
		return
	if add("keep_pick") > 0.0:
		pick_level = int(last_descent["pick"])
	if add("keep_ability") > 0.0:
		ability_level = int(last_descent["ability"])
	# Bolsa inicial: segundos de la producción con la que terminaste. Es oro para gastar; no suma profundidad.
	gold += float(_fx_set.get("carry_gold_seconds", 0.0)) * float(last_descent["gps"])
	# Ventaja inicial: una parte de la cuadrilla que tenías al volver, mineros incluidos.
	var before: Array = last_descent["owned"]
	for index: int in range(owned.size()):
		owned[index] += int(float(before[index]) * add("carry_crew"))
