extends RefCounted
## Árbol de mejoras permanentes que se compran con puntos de prestigio (acá, reliquias): estrellas con niveles,
## anillos que se abren con hitos, prerrequisitos, piedras angulares con un máximo de activas y puentes.
##
## Código reutilizable entre juegos: no depende de nada de res://game/ ni de Economy. Todo el balance sale de un
## diccionario (en este juego, data/arbol.json). No lleva la cuenta de las reliquias: quien lo usa le dice cuántas
## hay disponibles y le pregunta cuánto lleva gastado (spent()).
##
## Efectos: cada estrella tiene una lista de {type, ...}:
##   per_level  se suma (valor x nivel)  -> add(type)
##   mul        multiplica               -> mul(type)
##   values     [valor en nivel 1, 2...] -> value(type, el de siempre)
## Una piedra angular comprada pero apagada no tiene efecto.

## HIDDEN: todavía no se ve (falta el prerrequisito). SEALED: se sabe que está, pero su anillo está cerrado.
## OPEN: se puede comprar. OWNED: comprada (con nivel 1 o más).
enum State { HIDDEN, SEALED, OPEN, OWNED }

var last_error: String = ""
## id -> nivel comprado (solo las que tienen nivel).
var levels: Dictionary = {}
var active_keystones: Array[String] = []

var _stars: Dictionary = {}
var _ids: Array[String] = []
var _branches: Dictionary = {}
var _rings: Dictionary = {}
var _points: Array = []
var _extra_every: float = 0.0
var _bonus: Dictionary = {}
var _fragments_per_relic: int = 0
var _max_keystones: int = 0
var _streak_break: float = 0.0
var _working_seconds: float = 0.0
var _dirty: bool = true
var _add: Dictionary = {}
var _mul: Dictionary = {}
var _set: Dictionary = {}


func load_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return _fail("no existe %s" % path)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return _fail("%s no es un JSON válido" % path)
	return load_data(parsed)


## Valida y carga. Si los datos son inválidos devuelve false (motivo en last_error) y no cambia nada.
func load_data(data: Dictionary) -> bool:
	var raw_stars: Variant = data.get("stars")
	if not (raw_stars is Array) or (raw_stars as Array).is_empty():
		return _fail("hacen falta estrellas")
	var stars: Dictionary = {}
	var ids: Array[String] = []
	for entry: Variant in raw_stars:
		if not (entry is Dictionary) or str(entry.get("id", "")) == "" or stars.has(str(entry.get("id"))):
			return _fail("cada estrella necesita un id propio")
		var id: String = str(entry["id"])
		var costs: Variant = entry.get("costs")
		if not (costs is Array) or (costs as Array).is_empty() or (costs as Array).any(func(cost: Variant) -> bool: return float(cost) < 1.0):
			return _fail("'%s' necesita un costo (de 1 o más) por nivel" % id)
		if not (entry.get("effects") is Array) or not (entry.get("from") is Array):
			return _fail("'%s' necesita effects y from" % id)
		stars[id] = entry
		ids.append(id)
	for id: String in ids:
		var star: Dictionary = stars[id]
		var links: Array = (star["from"] as Array) + (star.get("bridge", []) as Array)
		if star.has("requires_max"):
			links.append(star["requires_max"])
		for other: Variant in links:
			if not stars.has(str(other)):
				return _fail("'%s' nombra una estrella que no existe: %s" % [id, str(other)])
	var rule: Variant = data.get("return")
	if not (rule is Dictionary) or not (rule.get("points") is Array) or (rule["points"] as Array).size() < 2:
		return _fail("falta la tabla de la meta (return.points)")
	var bonus: Variant = data.get("relic_bonus")
	if not (bonus is Dictionary) or not bonus.has("each"):
		return _fail("falta relic_bonus")
	var rings: Variant = data.get("rings")
	if not (rings is Dictionary) or not (rings as Dictionary).has_all(["0", "1", "2", "3"]):
		return _fail("rings necesita los anillos 0 a 3")
	if int(data.get("fragments_per_relic", 0)) <= 0:
		return _fail("fragments_per_relic tiene que ser > 0")

	last_error = ""
	_stars = stars
	_ids = ids
	_branches = data.get("branches", {})
	_rings = rings
	_points = rule["points"]
	_extra_every = float(rule.get("extra_every", 0.0))
	_bonus = bonus
	_fragments_per_relic = int(data["fragments_per_relic"])
	_max_keystones = int(data.get("max_keystones", 2))
	_streak_break = float((data.get("streak", {}) as Dictionary).get("break_seconds", 5.0))
	_working_seconds = float(data.get("working_seconds", 5.0))
	clear()
	return true


# --- Estrellas -----------------------------------------------------------------

func ids() -> Array[String]:
	return _ids.duplicate()


func has_star(id: String) -> bool:
	return _stars.has(id)


func star(id: String) -> Dictionary:
	return _stars.get(id, {})


func branch(id: String) -> Dictionary:
	return _branches.get(str(star(id).get("branch", "")), {})


func level(id: String) -> int:
	return int(levels.get(id, 0))


func max_level(id: String) -> int:
	return (star(id).get("costs", []) as Array).size()


func total_levels() -> int:
	var total: int = 0
	for id: String in levels:
		total += int(levels[id])
	return total


## Lo que cuesta el próximo nivel; 0 si ya está al máximo (o no existe).
func next_cost(id: String) -> int:
	if level(id) >= max_level(id):
		return 0
	return int(_stars[id]["costs"][level(id)])


## Reliquias gastadas en los niveles que hay.
func spent() -> int:
	var total: int = 0
	for id: String in levels:
		for index: int in range(level(id)):
			total += int(_stars[id]["costs"][index])
	return total


func is_keystone(id: String) -> bool:
	return bool(star(id).get("keystone", false))


# --- Anillos, niebla y compra ---------------------------------------------------

func ring_open(ring: int, record_depth: float, resets: int) -> bool:
	match ring:
		0:
			return resets >= int(_rings["0"].get("resets", 1))
		1:
			return level(str(_rings["1"].get("star", ""))) > 0
		2, 3:
			var gate: Dictionary = ring_requirement(ring)
			return record_depth >= float(gate["depth"]) and resets >= int(gate["resets"])
		_:
			return true # los puentes se abren con sus piedras angulares (ver requirement_met)


## {depth, resets} que pide un anillo con puerta (2 y 3); {} si no tiene.
func ring_requirement(ring: int) -> Dictionary:
	var gate: Dictionary = _rings.get(str(ring), {})
	if not gate.has("depth"):
		return {}
	return { "depth": float(gate["depth"]), "resets": int(gate["resets"]) }


func requirement_met(id: String) -> bool:
	var data: Dictionary = star(id)
	if data.is_empty():
		return false
	if data.has("requires_max"):
		return level(str(data["requires_max"])) >= max_level(str(data["requires_max"]))
	if data.has("bridge"):
		return (data["bridge"] as Array).all(func(other: Variant) -> bool: return level(str(other)) > 0)
	var from: Array = data["from"]
	return from.is_empty() or from.any(func(other: Variant) -> bool: return level(str(other)) > 0)


func state(id: String, record_depth: float, resets: int) -> State:
	if level(id) > 0:
		return State.OWNED
	if not requirement_met(id):
		return State.HIDDEN
	return State.OPEN if ring_open(int(star(id).get("ring", 0)), record_depth, resets) else State.SEALED


func can_buy(id: String, available: int, record_depth: float, resets: int) -> bool:
	if not has_star(id) or level(id) >= max_level(id) or next_cost(id) > available:
		return false
	if level(id) > 0:
		return true
	return state(id, record_depth, resets) == State.OPEN


## Sube un nivel si se puede (`available` = reliquias sin gastar). No descuenta nada: spent() ya lo refleja.
func buy(id: String, available: int, record_depth: float, resets: int) -> bool:
	if not can_buy(id, available, record_depth, resets):
		return false
	levels[id] = level(id) + 1
	if is_keystone(id) and active_keystones.size() < _max_keystones and not active_keystones.has(id):
		active_keystones.append(id)
	_dirty = true
	return true


## Prende o apaga una piedra angular comprada. Prender falla si ya hay el máximo.
func set_keystone(id: String, active: bool) -> bool:
	if not is_keystone(id) or level(id) <= 0:
		return false
	if not active:
		active_keystones.erase(id)
	elif not active_keystones.has(id):
		if active_keystones.size() >= _max_keystones:
			return false
		active_keystones.append(id)
	_dirty = true
	return true


func max_keystones() -> int:
	return _max_keystones


# --- Efectos ---------------------------------------------------------------------

func add(type: String) -> float:
	_recompute()
	return float(_add.get(type, 0.0))


func mul(type: String) -> float:
	_recompute()
	return float(_mul.get(type, 1.0))


func value(type: String, fallback: float) -> float:
	_recompute()
	return float(_set.get(type, fallback))


func _recompute() -> void:
	if not _dirty:
		return
	_dirty = false
	_add = {}
	_mul = {}
	_set = {}
	for id: String in levels:
		var lv: int = level(id)
		if is_keystone(id) and not active_keystones.has(id):
			continue
		for fx: Dictionary in _stars[id]["effects"]:
			var type: String = fx["type"]
			if fx.has("per_level"):
				_add[type] = float(_add.get(type, 0.0)) + float(fx["per_level"]) * lv
			if fx.has("mul"):
				_mul[type] = float(_mul.get(type, 1.0)) * float(fx["mul"])
			if fx.has("values"):
				_set[type] = float(fx["values"][mini(lv, (fx["values"] as Array).size()) - 1])


# --- Meta, bonus y fragmentos ------------------------------------------------------

## Metros que se corre la profundidad de volver según los puntos ya sacados de bajadas: tabla [[puntos, metros]],
## lineal entre puntos y con la pendiente del último tramo más allá.
func shift_for(claimed: int) -> float:
	if claimed <= float(_points[0][0]):
		return float(_points[0][1])
	var i: int = 1
	while i < _points.size() - 1 and claimed > float(_points[i][0]):
		i += 1
	var from: Array = _points[i - 1]
	var to: Array = _points[i]
	return roundf(lerpf(float(from[1]), float(to[1]), (claimed - float(from[0])) / (float(to[0]) - float(from[0]))))


## Cada tantos metros corridos, una vuelta a la superficie paga un punto más (0 = nunca).
func return_extra_every() -> float:
	return _extra_every


## Multiplicador por los puntos ganados en la historia (gastados o no).
func history_multiplier(earned: int) -> float:
	var full: float = float(_bonus.get("full_until", 0.0))
	var counted: float = float(earned) if full <= 0.0 else minf(earned, full)
	return 1.0 + counted * float(_bonus["each"]) + (earned - counted) * float(_bonus.get("after", 0.0))


func fragments_per_relic() -> int:
	return _fragments_per_relic


## Segundos sin golpear que cortan la racha.
func streak_break_seconds() -> float:
	return _streak_break


## Con un golpe en los últimos estos segundos se considera que estás jugando activo.
func working_seconds() -> float:
	return _working_seconds


# --- Estado ------------------------------------------------------------------------

func clear() -> void:
	levels = {}
	active_keystones = []
	_dirty = true


func to_dict() -> Dictionary:
	return { "levels": levels.duplicate(), "keystones": active_keystones.duplicate() }


## Tolera datos de otra versión: estrellas que no existen se ignoran y los niveles se recortan.
func from_dict(data: Dictionary) -> void:
	clear()
	var saved: Variant = data.get("levels")
	if saved is Dictionary:
		for id: Variant in saved:
			if not has_star(str(id)) or not (saved[id] is float or saved[id] is int):
				continue
			var lv: int = clampi(int(saved[id]), 0, max_level(str(id)))
			if lv > 0:
				levels[str(id)] = lv
	var keystones: Variant = data.get("keystones")
	if keystones is Array:
		for id: Variant in keystones:
			set_keystone(str(id), true)


func _fail(message: String) -> bool:
	last_error = message
	return false
