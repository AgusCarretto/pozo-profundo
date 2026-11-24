extends Node
## Autoload Save: guardado local por secciones (y en la nube en F6).
##
## Código reutilizable entre juegos: no debe depender de nada de res://game/.
## Save no conoce el contenido de la partida: cada sistema (p. ej. Economy) registra una
## sección con `register_section(nombre, to_dict, from_dict)`. Al arrancar, Save lee el archivo
## y le entrega a cada sección sus datos; cada 5 segundos, al cerrar, al pausar y al perder el
## foco, junta `to_dict()` de todas las secciones y escribe el archivo.
##
## Formato (JSON): { "version": 1, "saved_at": <unix>, "sections": { "<nombre>": {...} } }
##
## En headless (tests, CI) no persiste por defecto, para no pisar la partida del jugador.
## Limitación en Web: al cerrar la pestaña el navegador no siempre llega a vaciar IndexedDB,
## así que pueden perderse los últimos segundos.

const SAVE_VERSION: int = 1
const AUTOSAVE_INTERVAL: float = 5.0
const DEFAULT_PATH: String = "user://save.json"

var path: String = DEFAULT_PATH
var persistence_enabled: bool = DisplayServer.get_name() != "headless"
var autosave_interval: float = AUTOSAVE_INTERVAL
## Hora (unix) del save que se leyó del disco; 0 si no había. La usa el progreso offline.
var loaded_saved_at: int = 0

## nombre -> { "to_dict": Callable, "from_dict": Callable }
var _sections: Dictionary = {}
## Secciones tal como estaban en el archivo leído (nombre -> Dictionary).
var _loaded_sections: Dictionary = {}


func _ready() -> void:
	if not persistence_enabled:
		return
	load_from_disk()
	var timer: Timer = Timer.new()
	timer.wait_time = autosave_interval
	timer.autostart = true
	timer.timeout.connect(save_now)
	add_child(timer)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			save_now()


## Registra una sección. Si el archivo ya se leyó y tiene datos para ella, se los entrega
## enseguida; si no, los recibe cuando se llame a load_from_disk().
func register_section(section: String, to_dict: Callable, from_dict: Callable) -> void:
	_sections[section] = { "to_dict": to_dict, "from_dict": from_dict }
	_deliver(section)


func has_section(section: String) -> bool:
	return _sections.has(section)


## Lee el archivo y entrega los datos a las secciones registradas. Devuelve true si había
## un save usable. Un archivo ilegible se aparta como `<path>.corrupt` (no se borra).
func load_from_disk() -> bool:
	if not persistence_enabled or not FileAccess.file_exists(path):
		return false
	var json: JSON = JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not (json.data is Dictionary):
		_set_aside_corrupt_file()
		return false
	var sections: Variant = (json.data as Dictionary).get("sections")
	if not (sections is Dictionary):
		return false
	_loaded_sections = sections
	loaded_saved_at = int(_number((json.data as Dictionary).get("saved_at"), 0.0))
	for section: String in _sections:
		_deliver(section)
	return true


## Escribe el archivo ya mismo. No hace nada (y devuelve false) si la persistencia está
## apagada o si todavía no hay ninguna sección registrada: así un autosave temprano nunca
## pisa un save bueno con uno vacío.
func save_now() -> bool:
	if not persistence_enabled or _sections.is_empty():
		return false
	# Parte de lo leído, para no perder secciones que esta versión del juego no registra.
	var sections: Dictionary = _loaded_sections.duplicate(true)
	for section: String in _sections:
		sections[section] = (_sections[section]["to_dict"] as Callable).call()
	var payload: Dictionary = {
		"version": SAVE_VERSION,
		"saved_at": int(Time.get_unix_time_from_system()),
		"sections": sections,
	}
	# full_precision: sin esto JSON recorta a ~14 dígitos y el oro grande se degrada.
	return _write_atomically(JSON.stringify(payload, "\t", true, true))


func _deliver(section: String) -> void:
	var data: Variant = _loaded_sections.get(section)
	if data is Dictionary and _sections.has(section):
		(_sections[section]["from_dict"] as Callable).call(data)


## Escribe en `<path>.tmp` y después renombra: si el proceso muere a mitad de escritura,
## el save anterior queda intacto.
func _write_atomically(text: String) -> bool:
	var temp_path: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("Save: no se pudo escribir %s (error %d)" % [temp_path, FileAccess.get_open_error()])
		return false
	file.store_string(text)
	file.close()
	var error: Error = DirAccess.rename_absolute(temp_path, path)
	if error != OK:
		push_error("Save: no se pudo mover %s a %s (error %d)" % [temp_path, path, error])
		return false
	return true


func _set_aside_corrupt_file() -> void:
	var backup_path: String = path + ".corrupt"
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)
	DirAccess.rename_absolute(path, backup_path)
	print("Save: %s estaba dañado; se conservó como %s y se empieza de cero" % [path, backup_path])


static func _number(value: Variant, fallback: float) -> float:
	if value is float or value is int:
		var number: float = float(value)
		if is_finite(number):
			return number
	return fallback
