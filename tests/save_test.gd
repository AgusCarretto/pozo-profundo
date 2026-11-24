extends "res://tests/test_base.gd"
## Tests headless de core/save.gd (guardado local por secciones).
##
## Cada test usa su propio archivo en user://save_test/ y su propia instancia de Save.
## El autoload real no se toca: en headless no persiste, así que correr los tests
## nunca pisa la partida del jugador.

const SaveScript := preload("res://core/save.gd")

const TEST_DIR: String = "user://save_test"
const BIG_GOLD: float = 1.2345678901234567e45


## Sección de prueba: devuelve `state` al guardar y anota lo que recibe al cargar.
class Provider extends RefCounted:
	var state: Dictionary
	var received: Array[Dictionary] = []

	func _init(initial: Dictionary = {}) -> void:
		state = initial

	func to_dict() -> Dictionary:
		return state

	func from_dict(data: Dictionary) -> void:
		received.append(data)


var _nodes: Array[Node] = []
## Un Callable no mantiene vivo a un RefCounted: los proveedores se guardan acá.
var _providers: Array[Provider] = []


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	_test_defaults()
	_test_round_trip_keeps_full_precision()
	_test_file_layout_and_no_temp_leftover()
	_test_overwrite_updates_file()
	_test_missing_file()
	_test_corrupt_files_are_set_aside()
	_test_unusable_shapes()
	_test_registration_order()
	_test_unknown_sections_survive()
	_test_never_writes_without_sections()
	_test_persistence_disabled()
	_test_save_triggers()
	await _test_autosave_timer()
	_test_real_autoloads()
	for node: Node in _nodes:
		node.free()
	_cleanup()
	_finish()


# --- Helpers -----------------------------------------------------------------

## Instancia de Save (fuera del árbol) apuntando a un archivo propio y con persistencia activa.
func _make(file_name: String, fresh: bool = true) -> SaveScript:
	var save: SaveScript = SaveScript.new()
	_nodes.append(save)
	save.path = "%s/%s.json" % [TEST_DIR, file_name]
	save.persistence_enabled = true
	if fresh:
		_remove_files(save.path)
	return save


func _register(save: SaveScript, state: Dictionary, section: String = "game") -> Provider:
	var provider: Provider = Provider.new(state)
	_providers.append(provider)
	save.register_section(section, provider.to_dict, provider.from_dict)
	return provider


func _remove_files(path: String) -> void:
	for suffix: String in ["", ".tmp", ".corrupt"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)


func _cleanup() -> void:
	var dir: DirAccess = DirAccess.open(TEST_DIR)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		DirAccess.remove_absolute("%s/%s" % [TEST_DIR, file_name])
	DirAccess.remove_absolute(TEST_DIR)


func _write_raw(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _read_raw(path: String) -> String:
	return FileAccess.get_file_as_string(path)


# --- Tests -------------------------------------------------------------------

func _test_defaults() -> void:
	_section("Valores por defecto")
	var save: SaveScript = SaveScript.new()
	_nodes.append(save)
	_check_eq(SaveScript.AUTOSAVE_INTERVAL, 5.0, "autoguardado cada 5 segundos")
	_check_eq(save.autosave_interval, 5.0, "la instancia usa el intervalo por defecto")
	_check_eq(DisplayServer.get_name(), "headless", "estos tests corren en headless")
	_check_eq(save.persistence_enabled, false, "en headless Save no persiste por defecto")
	_check_eq(save.path, "user://save.json", "archivo por defecto: user://save.json")


## El oro puede llegar a 1e45 o más: JSON.stringify con precisión por defecto
## recorta a ~14 dígitos y el jugador perdería oro en cada carga.
func _test_round_trip_keeps_full_precision() -> void:
	_section("Ida y vuelta sin perder precisión")
	var writer: SaveScript = _make("roundtrip")
	_register(writer, { "gold": BIG_GOLD, "owned": [12, 3], "name": "x", "tiny": 0.1 + 0.2 })
	_check_eq(writer.save_now(), true, "save_now() escribe")
	var reader: SaveScript = _make("roundtrip", false)
	_check_eq(reader.load_from_disk(), true, "load_from_disk() encuentra el archivo")
	var section: Provider = _register(reader, {})
	_check_eq(section.received.size(), 1, "la sección se entrega una sola vez")
	if section.received.is_empty():
		return
	var data: Dictionary = section.received[0]
	_check_eq(data["gold"], BIG_GOLD, "oro 1.2345678901234567e45 vuelve idéntico")
	_check_eq(data["tiny"], 0.1 + 0.2, "0.1 + 0.2 vuelve idéntico")
	_check_eq(data["owned"], [12.0, 3.0], "las listas vuelven (los enteros llegan como float)")
	_check_eq(data["name"], "x", "los textos vuelven")


func _test_file_layout_and_no_temp_leftover() -> void:
	_section("Formato del archivo")
	var save: SaveScript = _make("layout")
	_register(save, { "a": 1 })
	var before: float = Time.get_unix_time_from_system()
	save.save_now()
	var after: float = Time.get_unix_time_from_system()
	var parsed: Variant = JSON.parse_string(_read_raw(save.path))
	_check(parsed is Dictionary, "el archivo es un JSON válido")
	if not (parsed is Dictionary):
		return
	var data: Dictionary = parsed
	_check_eq(int(data.get("version", 0)), SaveScript.SAVE_VERSION, "guarda la versión del formato")
	var saved_at: float = float(data.get("saved_at", 0.0))
	_check(saved_at >= floorf(before) and saved_at <= ceilf(after), "saved_at es la hora del guardado (para el progreso offline)")
	_check_eq(data.get("sections", {}).get("game", {}).get("a"), 1.0, "la sección 'game' está dentro de 'sections'")
	_check_eq(FileAccess.file_exists(save.path + ".tmp"), false, "no queda el archivo temporal")
	var reader: SaveScript = _make("layout", false)
	reader.load_from_disk()
	_check_eq(reader.loaded_saved_at, int(saved_at), "loaded_saved_at expone la hora del save cargado")


func _test_overwrite_updates_file() -> void:
	_section("Sobrescribir un save existente")
	var save: SaveScript = _make("overwrite")
	var writer: Provider = _register(save, { "gold": 1 })
	save.save_now()
	writer.state["gold"] = 2
	_check_eq(save.save_now(), true, "el segundo guardado también escribe")
	var reader: SaveScript = _make("overwrite", false)
	var section: Provider = _register(reader, {})
	reader.load_from_disk()
	_check_eq(section.received.size(), 1, "se carga una vez")
	if section.received.size() == 1:
		_check_eq(section.received[0]["gold"], 2.0, "queda el contenido del último guardado")
	_check_eq(FileAccess.file_exists(save.path + ".tmp"), false, "sigue sin quedar archivo temporal")


func _test_missing_file() -> void:
	_section("Sin archivo de guardado")
	var save: SaveScript = _make("missing")
	var section: Provider = _register(save, {})
	_check_eq(save.load_from_disk(), false, "load_from_disk() devuelve false")
	_check_eq(section.received.size(), 0, "no se carga nada (partida nueva)")
	_check_eq(save.loaded_saved_at, 0, "loaded_saved_at = 0")


func _test_corrupt_files_are_set_aside() -> void:
	_section("Archivos dañados")
	var scenarios: Array = [
		["vacío", ""],
		["basura", "{esto no es json"],
		["cortado a la mitad", "{\"version\": 1, \"sections\": {\"game\": {\"gol"],
	]
	for scenario: Array in scenarios:
		var label: String = scenario[0]
		var save: SaveScript = _make("corrupt")
		_write_raw(save.path, scenario[1])
		var section: Provider = _register(save, { "gold": 5 })
		_check_eq(save.load_from_disk(), false, "%s: devuelve false sin explotar" % label)
		_check_eq(section.received.size(), 0, "%s: no se carga nada" % label)
		_check_eq(FileAccess.file_exists(save.path + ".corrupt"), true, "%s: el archivo dañado se conserva como .corrupt" % label)
		_check_eq(FileAccess.file_exists(save.path), false, "%s: el original se apartó" % label)
		_check_eq(save.save_now(), true, "%s: se puede volver a guardar" % label)
		_check(JSON.parse_string(_read_raw(save.path)) is Dictionary, "%s: el save nuevo es válido" % label)
		_remove_files(save.path)


## JSON válido pero que no es un save: no debe romper ni entregar basura a las secciones.
func _test_unusable_shapes() -> void:
	_section("JSON válido con forma inesperada")
	var shapes: Array = [
		["un array", "[1, 2, 3]"],
		["un número", "42"],
		["sin 'sections'", "{\"version\": 1}"],
		["'sections' no es objeto", "{\"version\": 1, \"sections\": [1]}"],
		["la sección no es objeto", "{\"version\": 1, \"sections\": {\"game\": 7}}"],
	]
	for scenario: Array in shapes:
		var label: String = scenario[0]
		var save: SaveScript = _make("shape")
		_write_raw(save.path, scenario[1])
		var section: Provider = _register(save, {})
		save.load_from_disk()
		_check_eq(section.received.size(), 0, "%s: no entrega nada a la sección" % label)
		_remove_files(save.path)


func _test_registration_order() -> void:
	_section("Registrar antes o después de cargar")
	var writer: SaveScript = _make("order")
	_register(writer, { "gold": 9 })
	writer.save_now()

	var load_first: SaveScript = _make("order", false)
	load_first.load_from_disk()
	var late: Provider = _register(load_first, {})
	_check_eq(late.received.size(), 1, "cargar y después registrar: la sección recibe sus datos al registrarse")

	var register_first: SaveScript = _make("order", false)
	var early: Provider = _register(register_first, {})
	_check_eq(early.received.size(), 0, "registrar antes de cargar: todavía no recibe nada")
	register_first.load_from_disk()
	_check_eq(early.received.size(), 1, "...y al cargar, recibe sus datos")


## Si el archivo trae una sección que esta versión del juego no registra, guardar no la borra.
func _test_unknown_sections_survive() -> void:
	_section("Secciones desconocidas")
	var original: SaveScript = _make("unknown")
	_register(original, { "gold": 1 })
	_register(original, { "x": 7 }, "future_feature")
	original.save_now()

	var older_version: SaveScript = _make("unknown", false)
	older_version.load_from_disk()
	_register(older_version, { "gold": 2 })
	older_version.save_now()
	var parsed: Dictionary = JSON.parse_string(_read_raw(older_version.path))
	_check_eq(parsed["sections"].has("future_feature"), true, "la sección que no se registró sigue en el archivo")
	_check_eq(parsed["sections"]["game"]["gold"], 2.0, "y la registrada se actualizó")


func _test_never_writes_without_sections() -> void:
	_section("Sin secciones registradas")
	var save: SaveScript = _make("nosections")
	_write_raw(save.path, "{\"version\": 1, \"saved_at\": 1, \"sections\": {\"game\": {\"gold\": 123}}}")
	var before: String = _read_raw(save.path)
	_check_eq(save.save_now(), false, "save_now() no escribe si nadie se registró")
	_check_eq(_read_raw(save.path), before, "el save existente queda intacto (un autosave temprano no lo vacía)")


func _test_persistence_disabled() -> void:
	_section("Persistencia desactivada")
	var save: SaveScript = _make("disabled")
	save.persistence_enabled = false
	var section: Provider = _register(save, { "gold": 1 })
	_check_eq(save.save_now(), false, "save_now() devuelve false")
	_check_eq(FileAccess.file_exists(save.path), false, "no escribe nada")
	_write_raw(save.path, "{\"version\": 1, \"sections\": {\"game\": {\"gold\": 5}}}")
	_check_eq(save.load_from_disk(), false, "load_from_disk() devuelve false")
	_check_eq(section.received.size(), 0, "y no entrega nada")


## Android pausa la app sin avisar de cierre; Web casi nunca manda CLOSE_REQUEST:
## guardar al cerrar, al pausar y al perder el foco cubre las tres plataformas.
func _test_save_triggers() -> void:
	_section("Guardar al cerrar, pausar o perder el foco")
	var triggers: Array = [
		["cierre de ventana", Node.NOTIFICATION_WM_CLOSE_REQUEST],
		["app en pausa", Node.NOTIFICATION_APPLICATION_PAUSED],
		["pérdida de foco", Node.NOTIFICATION_APPLICATION_FOCUS_OUT],
	]
	for trigger: Array in triggers:
		var save: SaveScript = _make("trigger")
		_register(save, { "gold": 1 })
		_check_eq(FileAccess.file_exists(save.path), false, "%s: parte sin archivo" % trigger[0])
		save.notification(trigger[1])
		_check_eq(FileAccess.file_exists(save.path), true, "%s: guarda" % trigger[0])
		_remove_files(save.path)


func _test_autosave_timer() -> void:
	_section("Autoguardado periódico")
	var save: SaveScript = _make("autosave")
	save.autosave_interval = 0.1
	var section: Provider = _register(save, { "gold": 1 })
	root.add_child(save)
	_check_eq(FileAccess.file_exists(save.path), false, "al arrancar todavía no escribió")
	await create_timer(0.45).timeout
	_check_eq(FileAccess.file_exists(save.path), true, "después de unos ciclos ya guardó solo")
	section.state["gold"] = 77
	await create_timer(0.35).timeout
	var parsed: Variant = JSON.parse_string(_read_raw(save.path))
	_check_eq(parsed["sections"]["game"]["gold"] if parsed is Dictionary else null, 77.0, "y sigue guardando los cambios")
	root.remove_child(save)


## El autoload real de Economy se registra en el autoload real de Save, sin acoplarse.
func _test_real_autoloads() -> void:
	_section("Autoloads reales")
	var real_save: Node = root.get_node_or_null("Save")
	_check(real_save != null and real_save.has_method("has_section"), "existe el autoload Save")
	if real_save == null or not real_save.has_method("has_section"):
		return
	_check_eq(real_save.has_section("economy"), true, "Economy registró su sección 'economy'")
	_check_eq(real_save.persistence_enabled, false, "el Save real no persiste en headless")
