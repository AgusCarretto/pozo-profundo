extends "res://core/economy.gd"
## SOLO PARA SIMULAR (v0.7): el Economy real con los efectos del árbol de reliquias encima. No lo usa el juego.
##
## Las reliquias son los puntos que se gastan en el árbol. `relics` es el total ganado en la historia (de él sale un
## bonus pasivo chico: gastar nunca debilita) y `spent` lo gastado en estrellas.

var stars: Dictionary = {}          # id -> definición (arbol.json)
var tree: Dictionary = {}           # id -> nivel comprado
var active_keystones: Array = []
var spent: int = 0
## Bonus de oro por cada reliquia ganada en la historia.
var bonus_each: float = 0.05
## Desde esta cantidad cada reliquia suma `bonus_after` en vez de `bonus_each` (0 = sin tope).
var bonus_full_until: float = 0.0
var bonus_after: float = 0.0
## Metros que baja la profundidad de volver (mínima y de la fórmula) por cada reliquia ya sacada de una bajada.
var shift_per_relic: float = 0.0
var claimed: int = 0


func return_depth() -> float:
	return prestige_min_depth() + shift_per_relic * claimed


func prestige_relics() -> int:
	return EconomyMath.relics_for_depth(depth() - shift_per_relic * claimed, _prestige["min_depth"], _prestige["depth_offset"], _prestige["depth_step"], _prestige["exponent"])


func prestige() -> int:
	var gained: int = super()
	claimed += gained
	return gained
## El jugador simulado sostiene el frenesí (golpea al ritmo del umbral o más).
var taps_per_second: float = 3.0
## Estadísticas para los logros.
var stats: Dictionary = {}

var _fx_add: Dictionary = {}
var _fx_mul: Dictionary = {}
var _fx_set: Dictionary = {}
var _base: Dictionary = {}


func setup(balance: Dictionary, star_list: Array) -> void:
	if not load_balance(balance):
		push_error(last_error)
	for star: Dictionary in star_list:
		stars[star["id"]] = star
	_base = {
		"hit_chance": _loot_hit_chance, "second_chance": _loot_second_chance,
		"weights": _rarity_weights.duplicate(), "milestones": _milestones.duplicate(),
		"milestone_mult": _milestone_multiplier, "crit": _crit.duplicate(),
		"ability": _ability.duplicate(), "offline": _offline.duplicate(),
		"frenzy": _frenzy.duplicate(),
	}
	apply_tree()


func level_of(id: String) -> int:
	return int(tree.get(id, 0))


func available() -> int:
	return relics - spent


## Nivel que está surtiendo efecto (una piedra angular comprada pero apagada no cuenta).
func _effective_level(id: String) -> int:
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
	for index: int in range(_rarities.size()):
		_rarity_weights[index] *= 1.0 + add("weight_" + str(_rarities[index]["id"]))
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
	if _fx_set.has("reloj_eff"):
		_offline["efficiency"] = _fx_set["reloj_eff"]
		_offline["max_hours"] = _fx_set["reloj_hours"]


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
	return (1.0 + full * bonus_each + (relics - full) * bonus_after) * (1.0 + add("gold"))


func _base_output(index: int) -> float:
	return super(index) * (1.0 + add("crew")) * mul("crew_mul")


func hit_value() -> float:
	var power: float = pow(_pick["power_base"], pick_level) + add("hit_flat")
	var share: float = _pick["passive_share"] + add("hit_share")
	return (power * multiplier + share * gold_per_second()) * (1.0 + add("hit")) * mul("hit_mul")


## Lo que rinde en promedio un golpe (con crítico, eco y combo): lo usa el comprador simulado.
func hit_average() -> float:
	var combo: float = 1.0 + add("frenzy_hit") if frenzied() else 1.0
	return hit_value() * crit_average() * (1.0 + add("double_hit")) * combo


func hit() -> float:
	var amount: float = hit_value()
	if frenzied():
		amount *= 1.0 + add("frenzy_hit")
	var critical: bool = rng.randf() < _crit["chance"]
	if critical:
		amount *= float(_crit["multiplier"])
		stats["crits"] = stats.get("crits", 0) + 1
	if add("double_hit") > 0.0 and rng.randf() < add("double_hit"):
		amount *= 2.0
	stats["hits"] = stats.get("hits", 0) + 1
	_earn(amount)
	_roll_loot(_loot_hit_chance)
	if critical and add("crit_chest") > 0.0:
		_roll_loot(add("crit_chest"))
	return amount


func _earn(amount: float) -> void:
	if add("shallow_depth") > 0.0 and depth() < add("shallow_depth"):
		amount *= mul("shallow_mul")
	super(amount)


# --- Cofres y dinamita ---------------------------------------------------------

func _open_chest(rarity: int) -> void:
	var times: int = 2 if add("double_chest") > 0.0 and rng.randf() < add("double_chest") else 1
	for i: int in range(times):
		var amount: float = loot_reward(rarity) * (1.0 + add("chest_gold"))
		_earn(amount)
		var given: int = int(_rarities[rarity]["relics"])
		if given > 0:
			given += int(add("legendary_relics"))
		relics += given
		stats["chests"] = stats.get("chests", 0) + 1
		var key: String = "chest_" + str(_rarities[rarity]["id"])
		stats[key] = stats.get(key, 0) + 1
		stats["chest_gold"] = stats.get("chest_gold", 0.0) + amount
		stats["chest_relics"] = stats.get("chest_relics", 0) + given


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
	stats["dynamite"] = stats.get("dynamite", 0) + 1
	return amount


func apply_offline(elapsed: float) -> Dictionary:
	var report: Dictionary = super(elapsed)
	if not report.is_empty() and add("offline_gain") > 0.0:
		_earn(float(report["gold"]) * add("offline_gain"))
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
	var kept_pick: int = pick_level
	var kept_ability: int = ability_level
	super()
	if add("keep_pick") > 0.0:
		pick_level = kept_pick
	if add("keep_ability") > 0.0:
		ability_level = kept_ability
	# Bolsa inicial: oro para gastar; no cuenta como ganado (no suma profundidad).
	gold += float(_fx_set.get("start_gold", 0.0))
	if owned.is_empty():
		return
	owned[0] += int(add("start_miners"))
	var starters: int = int(add("start_crew"))
	for index: int in range(1, mini(starters + 1, owned.size())):
		owned[index] += 1
