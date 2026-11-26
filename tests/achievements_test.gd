extends "res://tests/test_base.gd"
## core/achievements.gd con los datos reales de data/logros.json: carga, condiciones, desbloqueo, contadores y guardado.

const Achievements := preload("res://core/achievements.gd")
const DATA: String = "res://data/logros.json"


func _initialize() -> void:
	_test_data()
	_test_same_goals_as_simulated()
	_test_counters_and_unlocking()
	_test_conditions_with_two_parts()
	_test_save_roundtrip()
	_test_rejects_broken_data()
	_finish()


func _make() -> Achievements:
	var list: Achievements = Achievements.new()
	_check(list.load_file(DATA), "carga data/logros.json (%s)" % list.last_error)
	return list


func _test_data() -> void:
	_section("Datos")
	var list: Achievements = _make()
	_check_eq(list.ids().size(), 70, "70 logros")
	var seen: Dictionary = {}
	var fragments: int = 0
	var secrets: int = 0
	for id: String in list.ids():
		var entry: Dictionary = list.entry(id)
		seen[id] = true
		fragments += list.fragments_for(id)
		secrets += int(list.is_secret(id))
		_check(str(entry["name"]) != "" and str(entry["desc"]) != "" and str(entry["cat"]) != "" and float(entry["target"]) > 0.0 and str(entry["stat"]) != "", "%s está completo" % id)
	_check_eq(seen.size(), 70, "ids únicos")
	_check_eq(fragments, 630, "630 fragmentos en total")
	_check_eq(secrets, 8, "8 secretos")
	_check_eq(list.categories().size(), 8, "8 categorías")


## El juego pide lo mismo que se simuló (los que el simulador estimaba por día ahora tienen su contador).
func _test_same_goals_as_simulated() -> void:
	_section("Mismos objetivos que lo simulado")
	var list: Achievements = _make()
	var sim: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/tree_sim/logros.json"))
	var by_name: Dictionary = {}
	for id: String in list.ids():
		by_name[list.entry(id)["name"]] = list.entry(id)
	var different: Array[String] = []
	for entry: Dictionary in sim["list"]:
		var mine: Dictionary = by_name.get(entry["name"], {})
		if mine.is_empty() or mine["tier"] != entry["tier"] or (entry.has("target") and float(mine["target"]) != float(entry["target"])):
			different.append(entry["name"])
	_check(different.is_empty(), "mismos nombres, dificultades y objetivos (%s)" % str(different))
	_check_eq(list.tier_fragments("facil") + list.tier_fragments("medio") + list.tier_fragments("dificil") + list.tier_fragments("epico"), 42, "fácil 2, medio 5, difícil 10, épico 25")


func _test_counters_and_unlocking() -> void:
	_section("Contadores y desbloqueo")
	var list: Achievements = _make()
	_check_eq(list.check({}).size(), 0, "sin nada no hay logros")
	list.add("hits", 99.0)
	_check_eq(list.check({}).size(), 0, "99 golpes: todavía no")
	list.add("hits", 1.0)
	_check_eq(list.check({}), ["hits_100"] as Array[String], "100 golpes: el primero")
	_check(list.is_unlocked("hits_100"), "queda conseguido")
	_check_eq(list.check({}).size(), 0, "y no vuelve a salir")
	list.set_max("frenzy_best", 70.0)
	list.set_max("frenzy_best", 10.0)
	_check_eq(list.value("frenzy_best", {}), 70.0, "set_max se queda con el mayor")
	_check(list.check({}).has("frenzy_best_60"), "un minuto de frenesí")
	var unlocked: Array[String] = list.check({ "record_depth": 205.0 })
	_check(unlocked.has("record_depth_100") and unlocked.has("record_depth_200"), "lo que se calcula afuera también cuenta, y pueden salir varios juntos")
	_check_eq(list.unlocked_count(), 4, "4 conseguidos (%d)" % list.unlocked_count())
	_check_eq(list.fragments_earned(), 2 + 5 + 2 + 2, "fragmentos ganados")
	_check(list.unlock("gear_opens_50"), "se puede dar uno a mano")
	_check(not list.unlock("gear_opens_50"), "una sola vez")
	_check(not list.unlock("inventado"), "uno que no existe no")
	_check_eq(list.next_locked(), "hits_1000", "el siguiente sin conseguir, en orden")


func _test_conditions_with_two_parts() -> void:
	_section("Museo ambulante: meta alta y pasarla")
	var list: Achievements = _make()
	_check(not list.check({ "return_depth": 539.0, "overshoot": 40.0 }).has("overshoot_10"), "con la meta en 539 no")
	_check(not list.check({ "return_depth": 545.0, "overshoot": 9.0 }).has("overshoot_10"), "pasándola por 9 tampoco")
	_check(list.check({ "return_depth": 540.0, "overshoot": 10.0 }).has("overshoot_10"), "con las dos, sí")


func _test_save_roundtrip() -> void:
	_section("Guardado")
	var list: Achievements = _make()
	list.add("hits", 1500.0)
	list.check({})
	var copy: Achievements = _make()
	copy.from_dict(JSON.parse_string(JSON.stringify(list.to_dict())))
	_check_eq(copy.value("hits", {}), 1500.0, "vuelven los contadores")
	_check(copy.is_unlocked("hits_1000"), "y lo conseguido")
	_check_eq(copy.check({}).size(), 0, "no se vuelve a pagar")
	copy.from_dict({ "unlocked": ["hits_100", "inventado", 7], "counters": { "hits": -5, "crits": "x", "dynamite": 3 } })
	_check_eq(copy.unlocked_count(), 1, "lo que no existe se ignora")
	_check_eq(copy.value("hits", {}), 0.0, "un contador negativo vale 0")
	_check_eq(copy.value("dynamite", {}), 3.0, "los buenos quedan")
	copy.clear()
	_check_eq(copy.unlocked_count() + int(copy.value("dynamite", {})), 0, "clear() borra todo")


func _test_rejects_broken_data() -> void:
	_section("Datos rotos")
	var good: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	var list: Achievements = Achievements.new()
	_check(not list.load_data({}), "vacío: no carga")
	var repeated: Dictionary = good.duplicate(true)
	repeated["list"][1]["id"] = repeated["list"][0]["id"]
	_check(not list.load_data(repeated), "ids repetidos: no carga")
	var tier: Dictionary = good.duplicate(true)
	tier["list"][0]["tier"] = "imposible"
	_check(not list.load_data(tier), "dificultad que no existe: no carga")
	_check(list.last_error != "", "y dice por qué")
