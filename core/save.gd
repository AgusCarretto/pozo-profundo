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
## Una sección puede pedir una copia de la partida antes de recibirla (para guardar la vieja antes de convertirla): ver
## register_section. La copia va a `<path sin extensión>.<nombre>.json` (y a la copia del navegador) y no se pisa nunca.
##
## En headless (tests, CI) no persiste por defecto, para no pisar la partida del jugador.
## En la web, además del archivo (IndexedDB, que se vacía de forma asíncrona) se guarda una copia sincrónica en
## localStorage (`mirror`), también cuando la página se oculta o se cierra; al cargar gana la más nueva.

## Se restauró una partida desde un código (import_code): lo que ya está en pantalla quedó viejo.
signal imported

const WebStorageMirror := preload("res://core/web_storage_mirror.gd")

## Código de respaldo: "SAVE1.<8 hex del sha256 del resto>.<el save en JSON, deflate, base64>".
const CODE_PREFIX: String = "SAVE1"
const CODE_CHECK_LENGTH: int = 8
## Tope del JSON descomprimido de un código (una partida pesa menos de 2 KB).
const CODE_MAX_BYTES: int = 1048576

const SAVE_VERSION: int = 1
const AUTOSAVE_INTERVAL: float = 5.0
const DEFAULT_PATH: String = "user://save.json"

var path: String = DEFAULT_PATH
var persistence_enabled: bool = DisplayServer.get_name() != "headless"
var autosave_interval: float = AUTOSAVE_INTERVAL
## Hora (unix) del save que se leyó del disco; 0 si no había. La usa el progreso offline.
var loaded_saved_at: int = 0
## Copia sincrónica del guardado, con read() -> String y write(text) -> bool; null = sin copia.
var mirror: RefCounted = null

## nombre -> { "to_dict": Callable, "from_dict": Callable }
var _sections: Dictionary = {}
## Secciones tal como estaban en el archivo leído (nombre -> Dictionary).
var _loaded_sections: Dictionary = {}
## Lo que se leyó, entero, para poder guardar una copia tal como estaba.
var _loaded_payload: Dictionary = {}


func _ready() -> void:
	if not persistence_enabled:
		return
	if mirror == null and OS.has_feature("web"):
		var web: WebStorageMirror = WebStorageMirror.new("%s.save" % ProjectSettings.get_setting("application/config/name"))
		web.on_page_hide(save_now)
		mirror = web
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
## enseguida; si no, los recibe cuando se llame a load_from_disk(). `backup_tag` (opcional) recibe esos datos antes de
## entregarlos y, si devuelve un nombre, la partida se copia con ese nombre.
func register_section(section: String, to_dict: Callable, from_dict: Callable, backup_tag: Callable = Callable()) -> void:
	_sections[section] = { "to_dict": to_dict, "from_dict": from_dict, "backup_tag": backup_tag }
	_deliver(section)


func has_section(section: String) -> bool:
	return _sections.has(section)


## Lee el archivo (y la copia, si hay) y entrega los datos del más nuevo a las secciones registradas. Devuelve
## true si había un save usable. Un archivo ilegible se aparta como `<path>.corrupt` (no se borra).
func load_from_disk() -> bool:
	if not persistence_enabled:
		return false
	var chosen: Dictionary = {}
	if FileAccess.file_exists(path):
		var from_file: Variant = _parse(FileAccess.get_file_as_string(path))
		if from_file == null:
			_set_aside_corrupt_file()
		elif _is_usable(from_file):
			chosen = from_file
	if mirror != null:
		var from_mirror: Variant = _parse(str(mirror.call("read")))
		# Con la misma hora gana la copia: se escribe en el acto, el archivo puede haber quedado atrás.
		if from_mirror != null and _is_usable(from_mirror) and (chosen.is_empty() or _saved_at(from_mirror) >= _saved_at(chosen)):
			chosen = from_mirror
	if chosen.is_empty():
		return false
	_loaded_payload = chosen
	_loaded_sections = chosen["sections"]
	loaded_saved_at = _saved_at(chosen)
	for section: String in _sections:
		_deliver(section)
	return true


## Escribe el archivo ya mismo. No hace nada (y devuelve false) si la persistencia está
## apagada o si todavía no hay ninguna sección registrada: así un autosave temprano nunca
## pisa un save bueno con uno vacío.
func save_now() -> bool:
	if not persistence_enabled or _sections.is_empty():
		return false
	var text: String = _serialize("\t")
	# La copia primero: es la que sobrevive si la página se está cerrando.
	var mirrored: bool = mirror != null and bool(mirror.call("write", text))
	var written: bool = _write_atomically(text)
	return written or mirrored


## La partida de ahora como un texto que el jugador puede copiar y guardar donde quiera: la salida cuando el
## navegador borra el almacenamiento del juego (iPhone dentro de un iframe). No depende de persistence_enabled.
func export_code() -> String:
	var body: String = Marshalls.raw_to_base64(_serialize("").to_utf8_buffer().compress(FileAccess.COMPRESSION_DEFLATE))
	return "%s.%s.%s" % [CODE_PREFIX, _check_of(body), body]


## El save que trae `code` ({version, saved_at, sections}), o {} si no es un código válido. Tolera espacios y
## saltos de línea que se cuelan al pegar. El dígito verificador se mira antes de decodificar nada.
func read_code(code: String) -> Dictionary:
	var clean: String = code.replace(" ", "").replace("\n", "").replace("\r", "").replace("\t", "")
	var parts: PackedStringArray = clean.split(".")
	if parts.size() != 3 or parts[0] != CODE_PREFIX or parts[2] == "" or parts[1] != _check_of(parts[2]):
		return {}
	var packed: PackedByteArray = Marshalls.base64_to_raw(parts[2])
	if packed.is_empty():
		return {}
	var data: Variant = _parse(packed.decompress_dynamic(CODE_MAX_BYTES, FileAccess.COMPRESSION_DEFLATE).get_string_from_utf8())
	if data == null or not _is_usable(data):
		return {}
	return data


## Reemplaza la partida por la del código y la guarda. Devuelve false (sin tocar nada) si el código no sirve.
## No acredita progreso offline: si no, un código viejo daría horas de producción cada vez que se pega.
func import_code(code: String) -> bool:
	var data: Dictionary = read_code(code)
	if data.is_empty():
		return false
	_loaded_payload = data
	_loaded_sections = data["sections"]
	for section: String in _sections:
		_deliver(section)
	save_now()
	imported.emit()
	return true


func _serialize(indent: String) -> String:
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
	return JSON.stringify(payload, indent, true, true)


func _check_of(body: String) -> String:
	return body.sha256_text().left(CODE_CHECK_LENGTH)


## El save como diccionario, o null si el texto no es un JSON con forma de objeto.
func _parse(text: String) -> Variant:
	var json: JSON = JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return null
	return json.data


func _is_usable(data: Dictionary) -> bool:
	return data.get("sections") is Dictionary


func _saved_at(data: Dictionary) -> int:
	return int(_number(data.get("saved_at"), 0.0))


func _deliver(section: String) -> void:
	var data: Variant = _loaded_sections.get(section)
	if not (data is Dictionary and _sections.has(section)):
		return
	var backup_tag: Callable = _sections[section]["backup_tag"]
	if backup_tag.is_valid():
		var tag: String = str(backup_tag.call(data))
		if tag != "":
			_back_up(tag)
	(_sections[section]["from_dict"] as Callable).call(data)


## Guarda la partida leída, sin cambios, con otro nombre. Si ya hay una copia con ese nombre, se deja la que está.
func _back_up(tag: String) -> void:
	if not persistence_enabled or _loaded_payload.is_empty():
		return
	var text: String = JSON.stringify(_loaded_payload, "\t", true, true)
	if mirror != null and mirror.has_method("back_up"):
		mirror.call("back_up", tag, text)
	var backup_path: String = "%s.%s.json" % [path.get_basename(), tag]
	if FileAccess.file_exists(backup_path):
		return
	var file: FileAccess = FileAccess.open(backup_path, FileAccess.WRITE)
	if file == null:
		push_error("Save: no se pudo escribir la copia %s (error %d)" % [backup_path, FileAccess.get_open_error()])
		return
	file.store_string(text)
	file.close()


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
