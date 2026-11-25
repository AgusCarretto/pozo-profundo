extends "res://tests/test_base.gd"
## Tests headless de core/online_config.gd (data/online.json) y core/analytics.gd (métricas mínimas).
##
## Nada sale a la red: cada Analytics de prueba va fuera del árbol y con un `sender` de mentira. El autoload real
## está apagado en headless.

const AnalyticsScript := preload("res://core/analytics.gd")
const EconomyScript := preload("res://core/economy.gd")
const OnlineConfig := preload("res://core/online_config.gd")

const TEST_DIR: String = "user://analytics_test"
const UUID_PATTERN: String = "^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"
const BASE_URL: String = "https://abc.supabase.co"
const KEY: String = "sb_publishable_abc123"
## JWT de mentira con {"role":"anon"} y con {"role":"service_role"} en el medio.
const ANON_JWT: String = "eyJhbGciOiJIUzI1NiJ9.eyJyb2xlIjoiYW5vbiJ9.firma"
const SERVICE_JWT: String = "eyJhbGciOiJIUzI1NiJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIn0.firma"
const EMPTY: Dictionary = { "supabase_url": "", "supabase_key": "", "feedback_url": "" }

var _nodes: Array[Node] = []
var _sent: Array[Dictionary] = []


func _initialize() -> void:
	# Los autoloads corren su _ready en el primer cuadro.
	await process_frame
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	_test_config_file()
	_test_secret_keys_are_refused()
	_test_uuid()
	_test_disabled()
	_test_request()
	_test_sessions()
	_test_device_id()
	_test_real_autoload()
	for node: Node in _nodes:
		node.free()
	var dir: DirAccess = DirAccess.open(TEST_DIR)
	for file_name: String in dir.get_files():
		dir.remove(file_name)
	DirAccess.remove_absolute(TEST_DIR)
	_finish()


func _load_config(text: String) -> Dictionary:
	var path: String = TEST_DIR + "/online.json"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	return OnlineConfig.load_file(path)


## Un Analytics encendido, con su Economy y un sender que anota en _sent.
func _make(key: String = KEY) -> AnalyticsScript:
	var economy: EconomyScript = EconomyScript.new()
	_nodes.append(economy)
	economy.load_balance_file(EconomyScript.DEFAULT_BALANCE_PATH)
	var analytics: AnalyticsScript = AnalyticsScript.new()
	_nodes.append(analytics)
	analytics.economy = economy
	analytics.config = { "supabase_url": BASE_URL, "supabase_key": key, "feedback_url": "" }
	analytics.enabled = true
	analytics.device_id = AnalyticsScript.new_uuid()
	analytics.sender = func(url: String, headers: PackedStringArray, body: String) -> void:
		_sent.append({ "url": url, "headers": headers, "body": body })
	_sent.clear()
	return analytics


func _test_config_file() -> void:
	_section("data/online.json: lo que falte o esté mal queda apagado")
	_check_eq(OnlineConfig.load_file(TEST_DIR + "/no_existe.json"), EMPTY, "sin archivo: todo vacío")
	for broken: String in ["{basura", "[1, 2]", "", "{}", "{\"supabase_url\": 5, \"supabase_key\": [], \"feedback_url\": null}"]:
		_check_eq(_load_config(broken), EMPTY, "con '%s': todo vacío" % broken)
	var good: Dictionary = _load_config(JSON.stringify({ "supabase_url": " " + BASE_URL + "/ ", "supabase_key": KEY, "feedback_url": "https://ejemplo.com/opinar?x=1" }))
	_check_eq(good, { "supabase_url": BASE_URL, "supabase_key": KEY, "feedback_url": "https://ejemplo.com/opinar?x=1" }, "lee los tres, sin espacios ni barra final")
	var odd: Dictionary = _load_config(JSON.stringify({ "supabase_url": "abc.supabase.co", "feedback_url": "javascript:alert(1)" }))
	_check_eq(odd, EMPTY, "solo acepta direcciones http o https")
	var example: Dictionary = OnlineConfig.load_file("res://data/online.example.json")
	_check_eq(example, EMPTY, "el ejemplo viene apagado")
	_check(FileAccess.file_exists("res://data/online.example.json"), "y existe")
	_check(FileAccess.get_file_as_string("res://.gitignore").contains("data/online.json"), "data/online.json no va a git")


func _test_secret_keys_are_refused() -> void:
	_section("Una key secreta nunca entra al juego")
	for secret: String in ["sb_secret_abc123", SERVICE_JWT]:
		var config: Dictionary = _load_config(JSON.stringify({ "supabase_url": BASE_URL, "supabase_key": secret }))
		_check_eq(config["supabase_key"], "", "rechaza %s…" % secret.left(12))
	_check_eq(_load_config(JSON.stringify({ "supabase_key": ANON_JWT }))["supabase_key"], ANON_JWT, "la anon key (JWT) sí")


func _test_uuid() -> void:
	_section("El id anónimo es un UUID v4 al azar")
	var pattern: RegEx = RegEx.create_from_string(UUID_PATTERN)
	var first: String = AnalyticsScript.new_uuid()
	var second: String = AnalyticsScript.new_uuid()
	_check(pattern.search(first) != null and pattern.search(second) != null, "con la forma de un UUID v4 (%s)" % first)
	_check(first != second, "y distinto cada vez")


func _test_disabled() -> void:
	_section("Apagado no manda nada")
	var analytics: AnalyticsScript = _make()
	analytics.enabled = false
	analytics.start_session()
	analytics.tick(1000.0)
	analytics.tick(100000.0)
	_check(_sent.is_empty(), "ni al empezar ni al volver")


func _test_request() -> void:
	_section("El pedido a Supabase")
	var analytics: AnalyticsScript = _make()
	analytics.economy.run_gold = 3.0e6
	analytics.economy.relics = 7
	analytics.start_session()
	_check_eq(_sent.size(), 1, "una sesión, un pedido")
	if _sent.is_empty():
		return
	_check_eq(_sent[0]["url"], BASE_URL + "/rest/v1/session_events", "a la tabla session_events")
	var headers: PackedStringArray = _sent[0]["headers"]
	for header: String in ["apikey: " + KEY, "Content-Type: application/json", "Prefer: return=minimal"]:
		_check(headers.has(header), "lleva '%s'" % header)
	_check(not ",".join(headers).contains("Authorization"), "una publishable key no va en Authorization")
	var body: Dictionary = JSON.parse_string(_sent[0]["body"])
	var keys: Array = body.keys()
	keys.sort()
	_check_eq(keys, ["app_version", "device_id", "max_biome", "relics"], "manda esas cuatro cosas y nada más")
	_check_eq(body["device_id"], analytics.device_id, "el id del dispositivo")
	_check_eq(body["app_version"], ProjectSettings.get_setting("application/config/version"), "la versión")
	_check_eq(int(body["max_biome"]), 3, "el bioma máximo")
	_check_eq(int(body["relics"]), 7, "las reliquias")
	_check(_sent[0]["body"].contains("\"max_biome\":3") and not _sent[0]["body"].contains("3.0"), "como enteros")
	analytics = _make(ANON_JWT)
	analytics.start_session()
	_check((_sent[0]["headers"] as PackedStringArray).has("Authorization: Bearer " + ANON_JWT), "una anon key (JWT) además va en Authorization")


func _test_sessions() -> void:
	_section("Volver después de media hora es otra sesión")
	var analytics: AnalyticsScript = _make()
	analytics.tick(10000.0)
	_check(_sent.is_empty(), "el primer tick solo toma la referencia")
	analytics.tick(10000.016)
	analytics.tick(10000.016 + AnalyticsScript.SESSION_GAP - 1.0)
	_check(_sent.is_empty(), "una pausa más corta no")
	var left: float = 10000.016 + AnalyticsScript.SESSION_GAP - 1.0
	analytics.tick(left + AnalyticsScript.SESSION_GAP)
	_check_eq(_sent.size(), 1, "media hora sin cuadros: sesión nueva")
	analytics.tick(left + AnalyticsScript.SESSION_GAP + 0.016)
	_check_eq(_sent.size(), 1, "una sola")
	analytics.tick(5.0)
	_check_eq(_sent.size(), 1, "un reloj que retrocede no inventa sesiones")
	_check_eq(AnalyticsScript.SESSION_GAP, 1800.0, "media hora son 1800 s")


func _test_device_id() -> void:
	_section("El id se guarda y no se cambia por basura")
	var analytics: AnalyticsScript = _make()
	var id: String = analytics.device_id
	var restored: AnalyticsScript = _make()
	restored.from_dict(analytics.to_dict())
	_check_eq(restored.device_id, id, "va y vuelve por el guardado")
	for garbage: Variant in ["", "no-es-un-uuid", 5, null]:
		restored.from_dict({ "device_id": garbage })
		_check_eq(restored.device_id, id, "ignora %s" % str(garbage))


func _test_real_autoload() -> void:
	_section("El autoload real")
	var analytics: Node = root.get_node_or_null("Analytics")
	_check(analytics != null, "existe")
	if analytics == null:
		return
	_check_eq(analytics.get("enabled"), false, "en headless está apagado")
	_check(RegEx.create_from_string(UUID_PATTERN).search(str(analytics.get("device_id"))) != null, "y tiene un id")
	_check(root.get_node("Save").has_section("analytics"), "guardado en su sección 'analytics'")
