extends RefCounted
## Lo que cambia entre publicaciones y no va en el código: a qué Supabase mandar las métricas y qué link abre
## "Opinar". Sale de res://data/online.json (fuera de git; el ejemplo es data/online.example.json).
##
## Código reutilizable entre juegos: no debe depender de nada de res://game/.
## Todo es opcional: lo que falte o esté mal queda en "" y esa parte queda apagada, sin errores.
## La key viaja dentro del juego, así que solo puede ser una pública (publishable o anon): una secreta o
## service_role se rechaza.

const DEFAULT_PATH: String = "res://data/online.json"


## { "supabase_url", "supabase_key", "feedback_url" }, siempre con las tres claves.
static func load_file(path: String = DEFAULT_PATH) -> Dictionary:
	var data: Dictionary = {}
	if FileAccess.file_exists(path):
		var json: JSON = JSON.new()
		if json.parse(FileAccess.get_file_as_string(path)) == OK and json.data is Dictionary:
			data = json.data
		else:
			print("OnlineConfig: %s no es un JSON válido; se ignora" % path)
	var key: String = _text(data, "supabase_key")
	if key != "" and _is_secret(key):
		print("OnlineConfig: la key de %s es secreta y no se usa; poné la publishable (o la anon)" % path)
		key = ""
	return {
		"supabase_url": _web_url(_text(data, "supabase_url")).trim_suffix("/"),
		"supabase_key": key,
		"feedback_url": _web_url(_text(data, "feedback_url")),
	}


static func _text(data: Dictionary, key: String) -> String:
	var value: Variant = data.get(key)
	return (value as String).strip_edges() if value is String else ""


## La dirección si es http o https; si no, "".
static func _web_url(url: String) -> String:
	return url if url.begins_with("https://") or url.begins_with("http://") else ""


## Key secreta nueva (sb_secret_...) o JWT cuyo rol es service_role: se saltan RLS.
static func _is_secret(key: String) -> bool:
	if key.begins_with("sb_secret_"):
		return true
	var parts: PackedStringArray = key.split(".")
	if parts.size() != 3:
		return false
	# El medio de un JWT es base64url sin relleno.
	var encoded: String = parts[1].replace("-", "+").replace("_", "/")
	while encoded.length() % 4 != 0:
		encoded += "="
	var payload: Variant = JSON.parse_string(Marshalls.base64_to_utf8(encoded))
	return payload is Dictionary and str((payload as Dictionary).get("role")) == "service_role"
