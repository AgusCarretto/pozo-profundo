extends Node
## Autoload Analytics: métricas mínimas para medir retención.
##
## Código reutilizable entre juegos: no debe depender de nada de res://game/.
## Manda un evento por sesión a la tabla `session_events` de Supabase (docs/supabase/): un id anónimo del
## dispositivo (un UUID al azar, guardado con Save), la versión, el bioma más profundo y las reliquias. La fecha
## la pone el servidor. Nada personal. Una sesión es abrir el juego, o volver después de SESSION_GAP segundos sin
## que corra ningún cuadro (en el celular, volver a una pestaña abierta no recarga el juego).
##
## Solo manda el juego publicado: con URL y key en data/online.json (ver online_config.gd), nunca desde un build de
## debug, el editor ni en headless (ver should_send), así las pruebas no ensucian la retención.
## Todo falla en silencio: sin red o con Supabase caído el juego sigue igual y ese evento se pierde.

const OnlineConfig := preload("res://core/online_config.gd")

const SAVE_SECTION: String = "analytics"
const TABLE_PATH: String = "/rest/v1/session_events"
## Segundos sin cuadros a partir de los cuales volver es una sesión nueva.
const SESSION_GAP: float = 1800.0
const REQUEST_TIMEOUT: float = 15.0
const UUID_PATTERN: String = "^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"

## Lo leído de data/online.json.
var config: Dictionary = {}
var enabled: bool = false
var device_id: String = ""
## De dónde salen el bioma máximo y las reliquias. Si nadie lo asignó, el autoload Economy.
var economy: Node
## Quién hace el POST: func(url: String, headers: PackedStringArray, body: String). Los tests lo reemplazan.
var sender: Callable

## Hora (unix) del último cuadro; 0 = todavía sin referencia.
var _last_tick: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	config = OnlineConfig.load_file()
	enabled = should_send(config, OS.is_debug_build(), OS.has_feature("editor"), DisplayServer.get_name() == "headless")
	if economy == null:
		economy = get_node_or_null("/root/Economy")
	if not sender.is_valid():
		sender = _post
	var save: Node = get_node_or_null("/root/Save")
	if save != null and save.has_method("register_section"):
		save.register_section(SAVE_SECTION, to_dict, from_dict)
	if device_id == "":
		device_id = new_uuid()
		# Ya mismo: quien entra y cierra enseguida no tiene que contar como otro la próxima vez.
		if save != null and save.has_method("save_now"):
			save.save_now()
	start_session.call_deferred()


func _process(_delta: float) -> void:
	tick(Time.get_unix_time_from_system())


## Si este juego manda métricas, según su configuración y desde dónde corre.
static func should_send(settings: Dictionary, is_debug: bool, is_editor: bool, is_headless: bool) -> bool:
	var configured: bool = settings.get("supabase_url", "") != "" and settings.get("supabase_key", "") != ""
	return configured and not is_debug and not is_editor and not is_headless


## Manda el evento de una sesión que empieza (si está encendido).
func start_session() -> void:
	if not enabled or not sender.is_valid():
		return
	var request: Dictionary = build_request()
	sender.call(request["url"], request["headers"], request["body"])


## Se llama una vez por cuadro con la hora actual.
func tick(now: float) -> void:
	if _last_tick > 0.0 and now - _last_tick >= SESSION_GAP:
		start_session()
	_last_tick = now


## { "url", "headers", "body" } del POST a Supabase.
func build_request() -> Dictionary:
	var key: String = config.get("supabase_key", "")
	var headers: PackedStringArray = PackedStringArray(["apikey: " + key, "Content-Type: application/json", "Prefer: return=minimal"])
	# La anon key vieja es un JWT y va también en Authorization; la publishable nueva solo en apikey.
	if key.begins_with("eyJ"):
		headers.append("Authorization: Bearer " + key)
	var body: Dictionary = {
		"device_id": device_id,
		"app_version": str(ProjectSettings.get_setting("application/config/version", "")),
		"max_biome": int(economy.call("max_biome")) if economy != null else 0,
		"relics": int(economy.get("relics")) if economy != null else 0,
	}
	return { "url": str(config.get("supabase_url", "")) + TABLE_PATH, "headers": headers, "body": JSON.stringify(body) }


## UUID versión 4 (al azar): no sale de ningún dato del aparato.
static func new_uuid() -> String:
	var bytes: PackedByteArray = Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var hex: String = bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20)]


func to_dict() -> Dictionary:
	return { "device_id": device_id }


func from_dict(data: Dictionary) -> void:
	var saved: Variant = data.get("device_id")
	if saved is String and RegEx.create_from_string(UUID_PATTERN).search(saved) != null:
		device_id = saved


func _post(url: String, headers: PackedStringArray, body: String) -> void:
	var request: HTTPRequest = HTTPRequest.new()
	# En la web el navegador ya descomprime: si Godot lo intenta de nuevo, el pedido falla.
	request.accept_gzip = false
	request.timeout = REQUEST_TIMEOUT
	add_child(request)
	request.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
		print_verbose("Analytics: resultado %d, HTTP %d" % [result, code])
		request.queue_free())
	if request.request(url, headers, HTTPClient.METHOD_POST, body) != OK:
		request.queue_free()
