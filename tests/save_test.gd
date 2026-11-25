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


## Copia de mentira (en la web es localStorage).
class FakeMirror extends RefCounted:
	var text: String = ""
	var writes: int = 0
	var works: bool = true

	func read() -> String:
		return text

	func write(value: String) -> bool:
		writes += 1
		if works:
			text = value
		return works


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
	_test_mirror()
	_test_backup_code()
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
func _payload(saved_at: int, gold: float) -> String:
	return JSON.stringify({ "version": 1, "saved_at": saved_at, "sections": { "game": { "gold": gold } } })


## Instancia con copia: escribe `file_text` en el archivo ("" = sin archivo), carga y devuelve lo que recibió la sección.
func _load_with(file_name: String, file_text: String, mirror: FakeMirror) -> Array:
	var save: SaveScript = _make(file_name)
	save.set("mirror", mirror)
	if file_text != "":
		_write_raw(save.path, file_text)
	var provider: Provider = _register(save, {})
	var loaded: bool = save.load_from_disk()
	var gold: Variant = provider.received[0].get("gold") if not provider.received.is_empty() else null
	return [loaded, gold, save.loaded_saved_at, save.path]


func _test_mirror() -> void:
	_section("Copia sincrónica del guardado (en la web, localStorage)")
	var mirror: FakeMirror = FakeMirror.new()
	var save: SaveScript = _make("mirror_write")
	save.set("mirror", mirror)
	_register(save, { "gold": 5.0 })
	_check(save.save_now(), "guarda")
	_check_eq(mirror.text, _read_raw(save.path), "la copia es el mismo texto que el archivo")

	mirror = FakeMirror.new()
	mirror.text = _payload(100, 7.0)
	var result: Array = _load_with("mirror_only", "", mirror)
	_check_eq(result.slice(0, 3), [true, 7.0, 100], "sin archivo carga la copia")

	mirror.text = _payload(200, 20.0)
	result = _load_with("mirror_newer", _payload(100, 10.0), mirror)
	_check_eq(result.slice(0, 3), [true, 20.0, 200], "si la copia es más nueva, gana la copia")
	mirror.text = _payload(100, 20.0)
	result = _load_with("file_newer", _payload(200, 10.0), mirror)
	_check_eq(result.slice(0, 3), [true, 10.0, 200], "si el archivo es más nuevo, gana el archivo")
	mirror.text = _payload(100, 20.0)
	result = _load_with("tie", _payload(100, 10.0), mirror)
	_check_eq(result.slice(0, 3), [true, 20.0, 100], "empate: la copia (se escribe en el acto)")

	mirror.text = _payload(100, 30.0)
	result = _load_with("corrupt_file", "{basura", mirror)
	_check_eq(result.slice(0, 2), [true, 30.0], "con el archivo dañado carga la copia")
	_check(FileAccess.file_exists(str(result[3]) + ".corrupt"), "y aparta el archivo dañado")
	for broken: String in ["{basura", "[1]", "{\"saved_at\": 999}"]:
		mirror.text = broken
		result = _load_with("corrupt_mirror", _payload(100, 11.0), mirror)
		_check_eq(result.slice(0, 2), [true, 11.0], "con la copia inservible (%s) carga el archivo" % broken)
	mirror.text = ""
	result = _load_with("nothing", "", mirror)
	_check_eq(result.slice(0, 2), [false, null], "sin archivo ni copia no carga nada")

	var blocked: FakeMirror = FakeMirror.new()
	blocked.works = false
	save = _make("mirror_blocked")
	save.set("mirror", blocked)
	_register(save, { "gold": 9.0 })
	_check(save.save_now(), "con la copia bloqueada igual guarda")
	_check(FileAccess.file_exists(save.path), "en el archivo")

	var untouched: FakeMirror = FakeMirror.new()
	untouched.text = _payload(100, 1.0)
	save = _make("mirror_disabled")
	save.set("mirror", untouched)
	save.persistence_enabled = false
	_register(save, { "gold": 2.0 })
	_check(not save.load_from_disk() and not save.save_now() and untouched.writes == 0, "con la persistencia apagada no toca la copia")


## En iPhone el navegador puede borrar el almacenamiento del juego: el jugador se lleva la partida como texto.
func _test_backup_code() -> void:
	_section("Código de respaldo (copiar y pegar la partida)")
	var writer: SaveScript = _make("code_writer")
	_register(writer, { "gold": BIG_GOLD, "owned": [12, 3] })
	var code: String = writer.export_code()
	_check(code.begins_with("SAVE1.") and not code.contains("\n") and not code.contains(" "), "es un solo texto sin espacios (%s...)" % code.left(24))
	var data: Dictionary = writer.read_code(code)
	_check_eq(data.get("sections", {}).get("game", {}).get("gold"), BIG_GOLD, "se lee sin perder precisión")
	_check(absf(float(data.get("saved_at", 0.0)) - Time.get_unix_time_from_system()) < 5.0, "y dice de cuándo es")

	var reader: SaveScript = _make("code_reader")
	var section: Provider = _register(reader, { "gold": 1.0 })
	var imports: Array[bool] = []
	reader.imported.connect(func() -> void: imports.append(true))
	var half: int = code.length() / 2
	_check(reader.import_code("  %s\n %s \n" % [code.left(half), code.substr(half)]), "se restaura aunque al pegarlo se corte en líneas")
	_check_eq(section.received.size(), 1, "la sección recibe los datos")
	_check_eq(section.received[0].get("owned") if not section.received.is_empty() else null, [12.0, 3.0], "tal como estaban")
	_check_eq(imports.size(), 1, "avisa con imported")
	_check(FileAccess.file_exists(reader.path), "y queda guardada en el acto")

	var body: String = code.get_slice(".", 2)
	var broken: Array[String] = ["", "hola", "SAVE1.", "SAVE1.00000000.", "SAVE1.00000000." + body, code.left(code.length() - 3),
		code.replace("SAVE1.", "SAVE9."), code + "A"]
	var untouched: SaveScript = _make("code_broken")
	var nothing: Provider = _register(untouched, { "gold": 1.0 })
	for bad: String in broken:
		_check(untouched.read_code(bad).is_empty() and not untouched.import_code(bad), "un código roto se rechaza (%s)" % bad.left(20))
	_check_eq(nothing.received.size(), 0, "sin tocar la partida")
	_check(not FileAccess.file_exists(untouched.path), "ni el archivo")


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
