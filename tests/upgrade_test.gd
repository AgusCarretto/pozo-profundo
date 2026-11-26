extends "res://tests/test_base.gd"
## Una partida de la 0.6.1 (tests/fixtures/save_v061.json, escrita por el código de esa versión) al abrirla con la 0.7:
## antes de convertirla queda una copia con otro nombre, y no se pierde nada.

const SaveScript := preload("res://core/save.gd")
const EconomyScript := preload("res://core/economy.gd")

const FIXTURE: String = "res://tests/fixtures/save_v061.json"
const DIR: String = "user://upgrade_test"
const PATH: String = DIR + "/save.json"
const BACKUP: String = DIR + "/save.antes-0.7.json"


class FakeMirror extends RefCounted:
	var text: String = ""
	var backups: Dictionary = {}

	func read() -> String:
		return text

	func write(value: String) -> bool:
		text = value
		return true

	func back_up(tag: String, value: String) -> bool:
		if not backups.has(tag):
			backups[tag] = value
		return true


var _nodes: Array[Node] = []


func _initialize() -> void:
	_clean()
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var old: Dictionary = original["sections"]["economy"]
	_test_conversion_keeps_a_copy(old)
	_test_the_copy_is_never_replaced(old)
	_test_a_new_game_has_no_copy()
	for node: Node in _nodes:
		node.free()
	_clean()
	_finish()


func _clean() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for file_name: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file_name)


## Una partida abierta: Save leyendo de PATH y Economy con el balance real.
func _open(mirror: FakeMirror) -> Array:
	var save: Node = SaveScript.new()
	save.persistence_enabled = true
	save.path = PATH
	save.mirror = mirror
	var economy: Node = EconomyScript.new()
	_check(economy.load_balance_file("res://data/balance.json"), "balance real")
	_nodes.append(save)
	_nodes.append(economy)
	save.load_from_disk()
	save.register_section("economy", economy.to_dict, economy.from_dict, economy.save_backup_tag)
	return [save, economy]


func _test_conversion_keeps_a_copy(old: Dictionary) -> void:
	_section("Al convertir queda una copia de la partida vieja")
	DirAccess.copy_absolute(FIXTURE, PATH)
	var mirror: FakeMirror = FakeMirror.new()
	var opened: Array = _open(mirror)
	var save: Node = opened[0]
	var economy: Node = opened[1]
	_check(FileAccess.file_exists(BACKUP), "hay un archivo %s" % BACKUP.get_file())
	var copy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BACKUP)) if FileAccess.file_exists(BACKUP) else {}
	_check_eq(copy.get("sections", {}).get("economy", {}), old, "idéntica a la de la 0.6.1")
	_check(mirror.backups.has("antes-0.7"), "y otra en el almacenamiento del navegador")

	_check_eq(economy.relics, 14, "conserva sus reliquias")
	_check_eq(economy.available_relics(), 14, "todas para gastar")
	_check_eq(economy.owned.slice(0, 4), [62, 40, 27, 6] as Array[int], "la cuadrilla")
	_check_eq(economy.pick_level, 5, "el pico")
	_check_eq(economy.ability_level, 3, "la dinamita")
	_check(economy.gold >= float(old["gold"]), "el oro")
	_check_near(economy.run_gold, float(old["run_gold"]), "y la profundidad de la bajada", 1.0)
	_check(not economy.pending_tree_report.is_empty(), "con el cartel del árbol")
	economy.check_achievements()
	_check(economy.achievements.unlocked_count() >= 5, "y logros por lo que ya había hecho (%d)" % economy.achievements.unlocked_count())
	save.save_now()
	var now: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	_check_eq(int(now["sections"]["economy"]["balance_version"]), 3, "se guarda convertida")
	_check_eq(JSON.parse_string(FileAccess.get_file_as_string(BACKUP))["sections"]["economy"], old, "y la copia queda como estaba")


func _test_the_copy_is_never_replaced(old: Dictionary) -> void:
	_section("La copia no se pisa nunca")
	var first: String = FileAccess.get_file_as_string(BACKUP)
	_open(FakeMirror.new())
	_check_eq(FileAccess.get_file_as_string(BACKUP), first, "volver a abrir no la toca")
	var other: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	other["sections"]["economy"]["relics"] = 99
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(other))
	file.close()
	_open(FakeMirror.new())
	_check_eq(JSON.parse_string(FileAccess.get_file_as_string(BACKUP))["sections"]["economy"], old, "ni con otra partida vieja")


func _test_a_new_game_has_no_copy() -> void:
	_section("Sin partida vieja no hay copia")
	_clean()
	var opened: Array = _open(FakeMirror.new())
	(opened[0] as Node).save_now()
	_open(FakeMirror.new())
	_check(not FileAccess.file_exists(BACKUP), "una partida nueva no deja copia")
