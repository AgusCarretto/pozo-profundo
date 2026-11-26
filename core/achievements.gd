extends RefCounted
## Logros y contadores históricos de la partida. Los datos (qué logros hay y qué piden) salen de un diccionario; cada
## logro mira un número: un contador que se lleva acá o un dato que le pasa quien lo usa.
##
## Código reutilizable entre juegos: no depende de nada de res://game/ ni de Economy. No entrega premios: check() dice
## cuáles se acaban de conseguir y cuánto valen en fragmentos.
##
## Formato: {fragments: {dificultad: fragmentos}, list: [{id, cat, name, desc, tier, stat, target, requires?, secret?}]}

var last_error: String = ""

var _entries: Dictionary = {}
var _ids: Array[String] = []
var _tiers: Dictionary = {}
var _unlocked: Dictionary = {}
var _counters: Dictionary = {}


func load_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return _fail("no existe %s" % path)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return _fail("%s no es un JSON válido" % path)
	return load_data(parsed)


func load_data(data: Dictionary) -> bool:
	var tiers: Variant = data.get("fragments")
	var raw: Variant = data.get("list")
	if not (tiers is Dictionary) or not (raw is Array) or (raw as Array).is_empty():
		return _fail("hacen falta fragments y list")
	var entries: Dictionary = {}
	var ids: Array[String] = []
	for entry: Variant in raw:
		if not (entry is Dictionary):
			return _fail("un logro no es un objeto")
		var id: String = str(entry.get("id", ""))
		if id == "" or entries.has(id):
			return _fail("cada logro necesita un id propio ('%s')" % id)
		if str(entry.get("stat", "")) == "" or float(entry.get("target", 0.0)) <= 0.0 or not (tiers as Dictionary).has(str(entry.get("tier", ""))):
			return _fail("'%s' necesita stat, target > 0 y una dificultad conocida" % id)
		entries[id] = entry
		ids.append(id)
	last_error = ""
	_entries = entries
	_ids = ids
	_tiers = tiers
	clear()
	return true


func ids() -> Array[String]:
	return _ids.duplicate()


func entry(id: String) -> Dictionary:
	return _entries.get(id, {})


## Las categorías, en el orden en que aparecen.
func categories() -> Array[String]:
	var list: Array[String] = []
	for id: String in _ids:
		var category: String = str(_entries[id].get("cat", ""))
		if not list.has(category):
			list.append(category)
	return list


func is_secret(id: String) -> bool:
	return bool(entry(id).get("secret", false))


func is_unlocked(id: String) -> bool:
	return _unlocked.has(id)


func unlocked_count() -> int:
	return _unlocked.size()


func tier_fragments(tier: String) -> int:
	return int(_tiers.get(tier, 0))


func fragments_for(id: String) -> int:
	return tier_fragments(str(entry(id).get("tier", "")))


func fragments_earned() -> int:
	var total: int = 0
	for id: String in _unlocked:
		total += fragments_for(id)
	return total


## El valor de `stat`: el que venga en `values` (datos que se calculan afuera) o el contador de acá.
func value(stat: String, values: Dictionary) -> float:
	return float(values.get(stat, _counters.get(stat, 0.0)))


func add(stat: String, amount: float = 1.0) -> void:
	if amount > 0.0 and is_finite(amount):
		_counters[stat] = float(_counters.get(stat, 0.0)) + amount


func set_max(stat: String, amount: float) -> void:
	if is_finite(amount) and amount > float(_counters.get(stat, 0.0)):
		_counters[stat] = amount


## Marca los logros que ya se cumplen y devuelve los nuevos, en el orden de los datos.
func check(values: Dictionary) -> Array[String]:
	var new_ones: Array[String] = []
	for id: String in _ids:
		if _unlocked.has(id):
			continue
		var data: Dictionary = _entries[id]
		if value(str(data["stat"]), values) < float(data["target"]):
			continue
		var requires: Dictionary = data.get("requires", {})
		if requires.keys().any(func(stat: String) -> bool: return value(stat, values) < float(requires[stat])):
			continue
		_unlocked[id] = true
		new_ones.append(id)
	return new_ones


## Da un logro a mano (herramientas de prueba). false si no existe o ya estaba.
func unlock(id: String) -> bool:
	if not _entries.has(id) or _unlocked.has(id):
		return false
	_unlocked[id] = true
	return true


## El primer logro sin conseguir, en el orden de los datos ("" si no queda ninguno).
func next_locked() -> String:
	for id: String in _ids:
		if not _unlocked.has(id):
			return id
	return ""


func clear() -> void:
	_unlocked = {}
	_counters = {}


func to_dict() -> Dictionary:
	return { "unlocked": _unlocked.keys(), "counters": _counters.duplicate() }


## Tolera datos de otra versión: logros que no existen se ignoran y los contadores inválidos valen 0.
func from_dict(data: Dictionary) -> void:
	clear()
	var unlocked: Variant = data.get("unlocked")
	if unlocked is Array:
		for id: Variant in unlocked:
			if id is String and _entries.has(id):
				_unlocked[id] = true
	var counters: Variant = data.get("counters")
	if counters is Dictionary:
		for stat: Variant in counters:
			var number: Variant = counters[stat]
			if (number is float or number is int) and is_finite(float(number)) and float(number) > 0.0:
				_counters[str(stat)] = float(number)


func _fail(message: String) -> bool:
	last_error = message
	return false
