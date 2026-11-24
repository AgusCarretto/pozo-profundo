extends Node
## Autoload Audio: música, SFX y variación de tono.
##
## Código reutilizable entre juegos: no debe depender de nada de res://game/.
## Qué suena con cada evento lo dice un catálogo en datos (res://data/sounds.json), no el código:
##   {
##     "sfx":   { "<id>": { "files": ["res://...ogg", ...], "pitch": [0.9, 1.1], "volume_db": -2 } },
##     "music": { "<id>": "res://...ogg" }
##   }
## `pitch` y `volume_db` son opcionales (1 y 0 dB). Cada play_sfx() elige una variante al azar (nunca la
## misma dos veces seguidas) y un tono dentro del rango: así cien golpes no suenan como uno repetido.
## Hay SFX_VOICES reproductores para los SFX; si están todos sonando se corta el más viejo.
##
## La música suena en el bus "Music" y los SFX en "SFX" (los dos mandan a Master); Audio los crea si no
## existen. Los volúmenes y el silencio vienen de Settings (que va antes en los autoloads) y se aplican a
## los buses cada vez que cambian. play_music() cambia de tema con un fundido cruzado.

## Sonó el SFX `id` (no se emite si no sonó: id desconocido, silencio o volumen 0).
signal sfx_played(id: String)

const SettingsScript := preload("res://core/settings.gd")

const MUSIC_BUS: StringName = &"Music"
const SFX_BUS: StringName = &"SFX"
const MASTER_BUS: StringName = &"Master"
const DEFAULT_CATALOG_PATH: String = "res://data/sounds.json"
## Cuántos SFX pueden sonar a la vez.
const SFX_VOICES: int = 8
## Segundos del fundido cruzado entre temas, si no se pide otro.
const DEFAULT_MUSIC_FADE: float = 1.5
## Límites razonables para lo que trae el catálogo.
const PITCH_LIMITS: Vector2 = Vector2(0.25, 4.0)
const VOLUME_DB_LIMITS: Vector2 = Vector2(-60.0, 24.0)

## De dónde se lee el catálogo al arrancar ("" = no leer ninguno; lo usan los tests).
var catalog_path: String = DEFAULT_CATALOG_PATH
## Las opciones del jugador. Si nadie lo asignó antes de entrar al árbol, se usa el autoload Settings.
var settings: SettingsScript
## Azar de variantes y tonos. Los tests le fijan la semilla.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Motivo por el que se rechazó el último catálogo ("" si cargó bien).
var last_error: String = ""

## id -> { "streams": Array[AudioStream], "pitch_min", "pitch_max", "volume_db" }
var _sfx: Dictionary = {}
## id -> AudioStream
var _music: Dictionary = {}
## id -> índice de la última variante que sonó (para no repetirla).
var _last_variant: Dictionary = {}
## Reproductores de SFX, del que se usó hace más tiempo al más reciente.
var _voices: Array[AudioStreamPlayer] = []
var _music_players: Array[AudioStreamPlayer] = []
## Índice en _music_players del tema que suena (o al que se está entrando); -1 = ninguno.
var _current_music: int = -1
var _music_tween: Tween


func _init() -> void:
	rng.randomize()


func _ready() -> void:
	# La música y los sonidos siguen aunque el juego se pause (por ejemplo, un momento congelado).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	for index: int in range(SFX_VOICES):
		_voices.append(_make_player("Sfx%d" % index, SFX_BUS))
	for index: int in range(2):
		_music_players.append(_make_player("Music%d" % index, MUSIC_BUS))
	if settings == null:
		settings = get_node_or_null("/root/Settings") as SettingsScript
	if settings != null:
		settings.changed.connect(apply_settings)
	apply_settings()
	if catalog_path != "" and FileAccess.file_exists(catalog_path):
		if not load_catalog_file(catalog_path):
			push_error("Audio: no se pudo cargar %s (%s)" % [catalog_path, last_error])


func _exit_tree() -> void:
	silence()


## Corta en seco todo lo que suena (SFX y música) y suelta los streams de los reproductores. El catálogo
## queda: después se puede volver a sonar. Lo usa el cierre: un sonido que sigue sonando cuando Godot
## sale queda retenido por el AudioServer y se reporta como recurso todavía en uso (el AudioServer lo
## suelta unos milisegundos después de cortarlo, en su próximo ciclo de mezcla).
func silence() -> void:
	_kill_music_tween()
	_current_music = -1
	for player: AudioStreamPlayer in _voices + _music_players:
		player.stop()
		player.stream = null


# --- Catálogo ----------------------------------------------------------------

func load_catalog_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return _fail("no existe %s" % path)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return _fail("%s no es un JSON válido" % path)
	return load_catalog(parsed)


## Valida y carga un catálogo (reemplaza al anterior). Si es inválido devuelve false y no toca nada.
## Los sonidos se cargan ya (no en el primer golpe) para que el primero no se atrase.
func load_catalog(catalog: Dictionary) -> bool:
	var sfx: Dictionary = {}
	var raw_sfx: Variant = catalog.get("sfx", {})
	if not (raw_sfx is Dictionary):
		return _fail("'sfx' tiene que ser un diccionario")
	for id: Variant in raw_sfx:
		var entry: Variant = _read_sfx(str(id), raw_sfx[id])
		if entry == null:
			return false
		sfx[str(id)] = entry
	var music: Dictionary = {}
	var raw_music: Variant = catalog.get("music", {})
	if not (raw_music is Dictionary):
		return _fail("'music' tiene que ser un diccionario")
	for id: Variant in raw_music:
		var stream: AudioStream = _load_stream(raw_music[id], "el tema '%s'" % id)
		if stream == null:
			return false
		music[str(id)] = stream
	_sfx = sfx
	_music = music
	_last_variant.clear()
	last_error = ""
	return true


func has_sfx(id: String) -> bool:
	return _sfx.has(id)


func sfx_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: String in _sfx:
		ids.append(id)
	return ids


func sfx_variants(id: String) -> int:
	return (_sfx[id]["streams"] as Array).size() if _sfx.has(id) else 0


func has_music(id: String) -> bool:
	return _music.has(id)


# --- SFX ---------------------------------------------------------------------

## Hace sonar el SFX `id` (una variante y un tono al azar) y devuelve el reproductor que usó. Devuelve null
## sin sonar si el id no está en el catálogo (no es un error: un evento puede no tener sonido todavía), si
## está todo en silencio o si el volumen de SFX está en 0.
func play_sfx(id: String) -> AudioStreamPlayer:
	if not _sfx.has(id) or _voices.is_empty() or not is_inside_tree():
		return null
	if settings != null and (settings.muted or settings.sfx_volume <= 0.0):
		return null
	var entry: Dictionary = _sfx[id]
	var streams: Array = entry["streams"]
	var variant: int = 0
	if streams.size() > 1:
		# Una variante al azar entre las demás: nunca la misma dos veces seguidas.
		variant = rng.randi_range(0, streams.size() - 2)
		if variant >= int(_last_variant.get(id, -1)):
			variant += 1
	_last_variant[id] = variant
	var player: AudioStreamPlayer = _take_voice()
	player.stream = streams[variant]
	player.pitch_scale = rng.randf_range(entry["pitch_min"], entry["pitch_max"])
	player.volume_db = entry["volume_db"]
	player.play()
	sfx_played.emit(id)
	return player


## Un reproductor libre, o el que se usó hace más tiempo si están todos sonando. Queda último en la fila.
func _take_voice() -> AudioStreamPlayer:
	var chosen: AudioStreamPlayer = _voices[0]
	for player: AudioStreamPlayer in _voices:
		if not player.playing:
			chosen = player
			break
	_voices.erase(chosen)
	_voices.append(chosen)
	return chosen


# --- Música ------------------------------------------------------------------

## Cambia al tema `id` del catálogo con un fundido cruzado de `fade` segundos. Si ya está sonando no lo
## reinicia. Devuelve false (y no cambia nada) si el tema no está en el catálogo.
func play_music(id: String, fade: float = DEFAULT_MUSIC_FADE) -> bool:
	if not _music.has(id):
		return false
	play_music_stream(_music[id], fade)
	return true


func play_music_stream(stream: AudioStream, fade: float = DEFAULT_MUSIC_FADE) -> void:
	if _music_players.is_empty() or stream == null:
		return
	var current: AudioStreamPlayer = current_music_player()
	if current != null and current.stream == stream and current.playing:
		return
	var next_index: int = 0 if _current_music != 0 else 1
	var next: AudioStreamPlayer = _music_players[next_index]
	_kill_music_tween()
	next.stream = stream
	next.volume_linear = 0.0 if fade > 0.0 else 1.0
	next.play()
	_current_music = next_index
	if fade <= 0.0:
		if current != null:
			current.stop()
		return
	_music_tween = create_tween().set_parallel(true)
	_music_tween.tween_property(next, "volume_linear", 1.0, fade)
	if current != null:
		_music_tween.tween_property(current, "volume_linear", 0.0, fade)
		_music_tween.chain().tween_callback(current.stop)


## Apaga la música con un fundido de `fade` segundos.
func stop_music(fade: float = DEFAULT_MUSIC_FADE) -> void:
	_kill_music_tween()
	_current_music = -1
	var playing: Array[AudioStreamPlayer] = []
	for player: AudioStreamPlayer in _music_players:
		if player.playing:
			playing.append(player)
	if playing.is_empty():
		return
	if fade <= 0.0:
		for player: AudioStreamPlayer in playing:
			player.stop()
		return
	_music_tween = create_tween().set_parallel(true)
	for player: AudioStreamPlayer in playing:
		_music_tween.tween_property(player, "volume_linear", 0.0, fade)
	_music_tween.chain().tween_callback(func() -> void:
		for player: AudioStreamPlayer in playing:
			player.stop())


## El reproductor del tema actual (o al que se está entrando); null si no hay música.
func current_music_player() -> AudioStreamPlayer:
	if _current_music < 0 or _current_music >= _music_players.size():
		return null
	return _music_players[_current_music]


func _kill_music_tween() -> void:
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = null


# --- Volúmenes ---------------------------------------------------------------

## Pasa a los buses los volúmenes y el silencio de Settings. Volumen 0 mutea el bus (en vez de -inf dB).
func apply_settings() -> void:
	if settings == null:
		return
	_set_bus_volume(MUSIC_BUS, settings.music_volume)
	_set_bus_volume(SFX_BUS, settings.sfx_volume)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(MASTER_BUS), settings.muted)


func _set_bus_volume(bus: StringName, volume: float) -> void:
	var index: int = AudioServer.get_bus_index(bus)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, volume <= 0.0)
	if volume > 0.0:
		AudioServer.set_bus_volume_db(index, linear_to_db(volume))


func _ensure_bus(bus: StringName) -> void:
	if AudioServer.get_bus_index(bus) >= 0:
		return
	var index: int = AudioServer.bus_count
	AudioServer.add_bus(index)
	AudioServer.set_bus_name(index, bus)
	AudioServer.set_bus_send(index, MASTER_BUS)


func _make_player(node_name: String, bus: StringName) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = node_name
	player.bus = bus
	add_child(player)
	return player


# --- Validación --------------------------------------------------------------

func _read_sfx(id: String, raw: Variant) -> Variant:
	if not (raw is Dictionary):
		return _fail_null("el SFX '%s' tiene que ser un diccionario" % id)
	var entry: Dictionary = raw
	var files: Variant = entry.get("files")
	if not (files is Array) or (files as Array).is_empty():
		return _fail_null("el SFX '%s' necesita al menos un archivo en 'files'" % id)
	var streams: Array[AudioStream] = []
	for file: Variant in files:
		var stream: AudioStream = _load_stream(file, "el SFX '%s'" % id)
		if stream == null:
			return null
		streams.append(stream)
	var pitch_min: float = 1.0
	var pitch_max: float = 1.0
	if entry.has("pitch"):
		var pitch: Variant = entry["pitch"]
		if not (pitch is Array) or (pitch as Array).size() != 2 or not _is_number(pitch[0]) or not _is_number(pitch[1]):
			return _fail_null("el SFX '%s': 'pitch' tiene que ser [mínimo, máximo]" % id)
		pitch_min = float(pitch[0])
		pitch_max = float(pitch[1])
		if pitch_min < PITCH_LIMITS.x or pitch_max > PITCH_LIMITS.y or pitch_min > pitch_max:
			return _fail_null("el SFX '%s': el tono va de %.2f a %.2f y el mínimo no pasa al máximo" % [id, PITCH_LIMITS.x, PITCH_LIMITS.y])
	var volume_db: float = 0.0
	if entry.has("volume_db"):
		if not _is_number(entry["volume_db"]):
			return _fail_null("el SFX '%s': 'volume_db' tiene que ser un número" % id)
		volume_db = float(entry["volume_db"])
		if volume_db < VOLUME_DB_LIMITS.x or volume_db > VOLUME_DB_LIMITS.y:
			return _fail_null("el SFX '%s': 'volume_db' va de %d a %d" % [id, VOLUME_DB_LIMITS.x, VOLUME_DB_LIMITS.y])
	return { "streams": streams, "pitch_min": pitch_min, "pitch_max": pitch_max, "volume_db": volume_db }


## Carga `path` como AudioStream; null (y last_error) si no es una ruta a un sonido que existe.
func _load_stream(path: Variant, what: String) -> AudioStream:
	if not (path is String) or not ResourceLoader.exists(path):
		_fail("%s apunta a un archivo que no existe (%s)" % [what, str(path)])
		return null
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		_fail("%s no es un sonido (%s)" % [what, path])
	return stream


func _fail(message: String) -> bool:
	last_error = message
	return false


func _fail_null(message: String) -> Variant:
	last_error = message
	return null


static func _is_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))
