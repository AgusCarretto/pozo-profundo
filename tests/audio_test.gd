extends "res://tests/test_base.gd"
## Tests headless de core/audio.gd: buses, catálogo de sonidos (validado), SFX con variantes y tono al
## azar, un tope de voces, música con fundido cruzado y volúmenes que vienen de Settings.
##
## En headless Godot usa el driver de audio "Dummy", que igual reproduce: `playing` se pone en true y la
## posición avanza. Los sonidos de prueba son AudioStreamWAV mudos guardados en user://audio_test/.

const AudioScript := preload("res://core/audio.gd")
const SettingsScript := preload("res://core/settings.gd")

const TEST_DIR: String = "user://audio_test"
const FADE: float = 0.1

var _nodes: Array[Node] = []
## Rutas de los sonidos de prueba: tres variantes de "hit", uno de "buy" y dos temas.
var _hit_files: Array[String] = []
var _buy_file: String = ""
var _song_a: String = ""
var _song_b: String = ""


func _initialize() -> void:
	_make_test_sounds()
	# Los nodos recién agregados entran al árbol en el próximo frame: recién ahí pueden sonar.
	await process_frame
	_test_buses()
	_test_catalog_validation()
	await _test_sfx()
	await _test_sfx_variation()
	await _test_voice_limit()
	await _test_silence()
	await _test_volumes_follow_settings()
	await _test_music_crossfade()
	await process_frame
	_test_real_autoload()
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_cleanup()
	_finish()


# --- Helpers -----------------------------------------------------------------

func _make_test_sounds() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	for index: int in range(3):
		_hit_files.append(_save_wav("hit_%d" % index, 0.5))
	_buy_file = _save_wav("buy", 0.5)
	_song_a = _save_wav("song_a", 4.0, true)
	_song_b = _save_wav("song_b", 4.0, true)


func _save_wav(file_name: String, seconds: float, loop: bool = false) -> String:
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var data: PackedByteArray = PackedByteArray()
	data.resize(int(22050 * seconds) * 2)
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = int(22050 * seconds)
	var path: String = "%s/%s.tres" % [TEST_DIR, file_name]
	ResourceSaver.save(wav, path)
	return path


func _catalog() -> Dictionary:
	return {
		"sfx": {
			"hit": { "files": _hit_files, "pitch": [0.9, 1.1], "volume_db": -2.0 },
			"buy": { "files": [_buy_file] },
		},
		"music": { "earth": _song_a, "rock": _song_b },
	}


## Un Audio con su propio Settings (no el autoload), ya dentro del árbol y con el catálogo de prueba.
func _make_audio() -> AudioScript:
	var settings: SettingsScript = SettingsScript.new()
	_nodes.append(settings)
	var audio: AudioScript = AudioScript.new()
	audio.settings = settings
	audio.catalog_path = ""
	_nodes.append(audio)
	root.add_child(audio)
	audio.rng.seed = 1234
	_check(audio.load_catalog(_catalog()), "el catálogo de prueba es válido (%s)" % audio.last_error)
	return audio


func _drop(audio: AudioScript) -> void:
	_nodes.erase(audio)
	root.remove_child(audio)
	audio.free()


func _bus_volume_db(bus: String) -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus))


func _bus_muted(bus: String) -> bool:
	return AudioServer.is_bus_mute(AudioServer.get_bus_index(bus))


func _cleanup() -> void:
	var dir: DirAccess = DirAccess.open(TEST_DIR)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		dir.remove(file_name)
	DirAccess.remove_absolute(TEST_DIR)


# --- Tests -------------------------------------------------------------------

func _test_buses() -> void:
	_section("Buses de Música y SFX")
	var audio: AudioScript = _make_audio()
	for bus: String in [AudioScript.MUSIC_BUS, AudioScript.SFX_BUS]:
		var index: int = AudioServer.get_bus_index(bus)
		_check(index > 0, "existe el bus %s" % bus)
		_check_eq(AudioServer.get_bus_send(index), &"Master", "y manda a Master")
	var before: int = AudioServer.bus_count
	var second: AudioScript = _make_audio()
	_check_eq(AudioServer.bus_count, before, "un segundo Audio no duplica los buses")
	_drop(second)
	_drop(audio)


func _test_catalog_validation() -> void:
	_section("El catálogo se valida antes de usarse")
	var audio: AudioScript = _make_audio()
	_check(audio.has_sfx("hit") and audio.has_sfx("buy"), "carga los SFX del catálogo")
	_check_eq(audio.sfx_variants("hit"), 3, "hit tiene 3 variantes")
	var bad: Array[Dictionary] = [
		{ "sfx": { "hit": { "files": [] } } },
		{ "sfx": { "hit": { "files": ["res://no_existe.ogg"] } } },
		{ "sfx": { "hit": { "files": [_buy_file], "pitch": [1.2, 0.8] } } },
		{ "sfx": { "hit": { "files": [_buy_file], "pitch": [0.0, 1.0] } } },
		{ "sfx": { "hit": { "files": [_buy_file], "volume_db": "alto" } } },
		{ "sfx": { "hit": "res://algo.ogg" } },
		{ "music": { "earth": "res://no_existe.ogg" } },
		{ "sfx": [] },
	]
	var reasons: Array[String] = [
		"sin archivos", "un archivo que no existe", "un tono mínimo mayor que el máximo",
		"un tono en 0", "un volumen que no es número", "una entrada que no es diccionario",
		"un tema que no existe", "sfx que no es diccionario",
	]
	for index: int in range(bad.size()):
		_check(not audio.load_catalog(bad[index]), "rechaza %s" % reasons[index])
		_check(audio.last_error != "", "y dice por qué (%s)" % audio.last_error)
	_check(audio.has_sfx("hit") and audio.sfx_variants("hit") == 3, "un catálogo rechazado no toca el anterior")
	_check(not audio.load_catalog_file("res://no_existe.json"), "un archivo de catálogo que no existe se rechaza")
	_check(audio.load_catalog({}), "un catálogo vacío es válido (no suena nada)")
	_check(not audio.has_sfx("hit"), "y reemplaza al anterior")
	_drop(audio)


func _test_sfx() -> void:
	_section("Un SFX suena en el bus SFX")
	var audio: AudioScript = _make_audio()
	var player: AudioStreamPlayer = audio.play_sfx("hit")
	_check(player != null, "play_sfx devuelve el reproductor que usó")
	if player != null:
		_check_eq(player.bus, AudioScript.SFX_BUS, "en el bus SFX")
		_check(player.playing, "y está sonando")
		_check(player.pitch_scale >= 0.9 and player.pitch_scale <= 1.1, "con tono dentro del rango del catálogo (%.3f)" % player.pitch_scale)
		_check_near(player.volume_db, -2.0, "con el volumen del catálogo")
	var buy: AudioStreamPlayer = audio.play_sfx("buy")
	_check(buy != null and buy.pitch_scale == 1.0 and buy.volume_db == 0.0, "sin tono ni volumen en el catálogo: 1 y 0 dB")
	_check(audio.play_sfx("no_existe") == null, "un SFX que no está en el catálogo no suena (y no es error)")
	await process_frame
	_drop(audio)


func _test_sfx_variation() -> void:
	_section("Variación: otra variante y otro tono cada vez")
	var audio: AudioScript = _make_audio()
	var used: Dictionary = {}
	var pitches: Dictionary = {}
	var repeated: int = 0
	var last: Resource = null
	for index: int in range(30):
		var player: AudioStreamPlayer = audio.play_sfx("hit")
		if player == null:
			continue
		used[player.stream.resource_path] = true
		pitches[snappedf(player.pitch_scale, 0.001)] = true
		if player.stream == last:
			repeated += 1
		last = player.stream
	_check_eq(used.size(), 3, "en 30 golpes suenan las 3 variantes")
	_check_eq(repeated, 0, "nunca la misma variante dos veces seguidas")
	_check(pitches.size() >= 10, "y el tono cambia (%d tonos distintos)" % pitches.size())
	await process_frame
	_drop(audio)


func _test_voice_limit() -> void:
	_section("Tope de voces: muchos golpes no crean reproductores sin fin")
	var audio: AudioScript = _make_audio()
	var players: Dictionary = {}
	for index: int in range(AudioScript.SFX_VOICES * 3):
		var player: AudioStreamPlayer = audio.play_sfx("hit")
		if player != null:
			players[player] = true
	_check_eq(players.size(), AudioScript.SFX_VOICES, "se reusan %d voces" % AudioScript.SFX_VOICES)
	var playing: int = 0
	for player: AudioStreamPlayer in players:
		if player.playing:
			playing += 1
	_check_eq(playing, AudioScript.SFX_VOICES, "y las %d están sonando (el más viejo se corta)" % AudioScript.SFX_VOICES)
	await process_frame
	_drop(audio)


func _test_silence() -> void:
	_section("En silencio o con SFX en 0 no se reproduce nada")
	var audio: AudioScript = _make_audio()
	audio.settings.muted = true
	_check(audio.play_sfx("hit") == null, "silenciado: play_sfx no reproduce")
	_check(_bus_muted("Master"), "y el bus Master está muteado")
	audio.settings.muted = false
	_check(not _bus_muted("Master"), "al quitar el silencio se desmutea")
	audio.settings.sfx_volume = 0.0
	_check(audio.play_sfx("hit") == null, "con SFX en 0 tampoco")
	audio.settings.sfx_volume = 1.0
	_check(audio.play_sfx("hit") != null, "con volumen vuelve a sonar")
	await process_frame
	_drop(audio)


func _test_volumes_follow_settings() -> void:
	_section("Los volúmenes de los buses siguen a Settings")
	var audio: AudioScript = _make_audio()
	audio.settings.music_volume = 0.5
	_check_near(_bus_volume_db(AudioScript.MUSIC_BUS), linear_to_db(0.5), "música a 0,5 = %.1f dB" % linear_to_db(0.5), 1e-4)
	audio.settings.sfx_volume = 0.25
	_check_near(_bus_volume_db(AudioScript.SFX_BUS), linear_to_db(0.25), "SFX a 0,25 = %.1f dB" % linear_to_db(0.25), 1e-4)
	_check(not _bus_muted(AudioScript.MUSIC_BUS), "el bus de música no está muteado")
	audio.settings.music_volume = 0.0
	_check(_bus_muted(AudioScript.MUSIC_BUS), "con volumen 0 se mutea el bus (en vez de -inf dB)")
	audio.settings.music_volume = 1.0
	_check(not _bus_muted(AudioScript.MUSIC_BUS) and is_equal_approx(_bus_volume_db(AudioScript.MUSIC_BUS), 0.0), "a 1 queda en 0 dB")
	audio.settings.sfx_volume = 1.0
	# Un Audio nuevo aplica lo que ya hay en Settings al arrancar.
	var settings: SettingsScript = SettingsScript.new()
	_nodes.append(settings)
	settings.music_volume = 0.2
	var fresh: AudioScript = AudioScript.new()
	fresh.settings = settings
	fresh.catalog_path = ""
	_nodes.append(fresh)
	root.add_child(fresh)
	_check_near(_bus_volume_db(AudioScript.MUSIC_BUS), linear_to_db(0.2), "al arrancar aplica el volumen guardado", 1e-4)
	settings.music_volume = 1.0
	await process_frame
	_drop(fresh)
	_drop(audio)


func _test_music_crossfade() -> void:
	_section("Música: fundido cruzado entre temas")
	var audio: AudioScript = _make_audio()
	_check(audio.play_music("earth", FADE), "play_music de un tema del catálogo")
	var first: AudioStreamPlayer = audio.current_music_player()
	_check(first != null and first.playing, "suena")
	if first == null:
		_drop(audio)
		return
	_check_eq(first.bus, AudioScript.MUSIC_BUS, "en el bus de música")
	_check_eq(first.stream.resource_path, _song_a, "el tema pedido")
	await create_timer(FADE * 3.0).timeout
	_check_near(first.volume_linear, 1.0, "terminado el fundido está a volumen completo", 1e-3)
	var position: float = first.get_playback_position()
	_check(audio.play_music("earth", FADE), "pedir el mismo tema otra vez")
	_check(audio.current_music_player() == first and first.get_playback_position() >= position, "no lo reinicia")
	_check(audio.play_music("rock", FADE), "pedir otro tema")
	var second: AudioStreamPlayer = audio.current_music_player()
	_check(second != null and second != first, "usa el otro reproductor")
	_check(first.playing and second.playing, "durante el fundido suenan los dos")
	_check(second.volume_linear < 0.5, "y el nuevo arranca bajo (%.2f)" % second.volume_linear)
	await create_timer(FADE * 3.0).timeout
	_check(not first.playing, "terminado el fundido, el viejo se detiene")
	_check_near(second.volume_linear, 1.0, "y el nuevo queda a volumen completo", 1e-3)
	_check(not audio.play_music("no_existe", FADE), "un tema que no está en el catálogo no hace nada")
	_check(second.playing, "y la música sigue")
	audio.stop_music(FADE)
	await create_timer(FADE * 3.0).timeout
	_check(not first.playing and not second.playing, "stop_music la apaga con fundido")
	_drop(audio)


func _test_real_autoload() -> void:
	_section("El autoload real")
	var audio: Node = root.get_node_or_null("Audio")
	_check(audio != null and audio.has_method("play_sfx"), "existe el autoload Audio con play_sfx")
	_check(audio != null and audio.get("settings") == root.get_node_or_null("Settings"), "y usa el autoload Settings")
	var source: String = FileAccess.get_file_as_string("res://core/audio.gd")
	var game_import: RegEx = RegEx.create_from_string("load\\(\\s*\"res://game/")
	_check(game_import.search(source) == null, "core/audio.gd no carga nada de res://game/")
