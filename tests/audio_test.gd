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
	_test_music_entries()
	await _test_music_resume()
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
	var heard: Array[String] = []
	audio.sfx_played.connect(func(id: String) -> void: heard.append(id))
	audio.play_sfx("hit")
	audio.play_sfx("no_existe")
	_check_eq(heard, ["hit"] as Array[String], "avisa con sfx_played lo que sonó (y no lo que no existe)")
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
	# El catálogo puede bajar toda la música (music_volume_db): se suma a lo que elige el jugador, solo en la música.
	var quieter: Dictionary = _catalog()
	quieter["music_volume_db"] = -10
	_check(audio.load_catalog(quieter), "un catálogo con music_volume_db es válido (%s)" % audio.last_error)
	audio.settings.music_volume = 1.0
	_check_near(_bus_volume_db(AudioScript.MUSIC_BUS), -10.0, "con el control al 100%, la música a -10 dB (la mitad al oído)", 1e-4)
	audio.settings.music_volume = 0.5
	_check_near(_bus_volume_db(AudioScript.MUSIC_BUS), linear_to_db(0.5) - 10.0, "al 50%, otros 6 dB menos", 1e-4)
	audio.settings.sfx_volume = 1.0
	_check_near(_bus_volume_db(AudioScript.SFX_BUS), 0.0, "los efectos no cambian", 1e-4)
	audio.settings.music_volume = 0.0
	_check(_bus_muted(AudioScript.MUSIC_BUS), "y 0 sigue siendo silencio")
	for bad: Variant in ["fuerte", 100, NAN]:
		var broken: Dictionary = _catalog()
		broken["music_volume_db"] = bad
		_check(not audio.load_catalog(broken), "rechaza music_volume_db %s" % str(bad))
	_check(audio.load_catalog(_catalog()), "sin la clave, vuelve a 0 dB")
	audio.settings.music_volume = 1.0
	_check_near(_bus_volume_db(AudioScript.MUSIC_BUS), 0.0, "0 dB", 1e-4)
	var real: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(AudioScript.DEFAULT_CATALOG_PATH))
	_check_near(float(real.get("music_volume_db", 0.0)), -10.0, "el catálogo del juego baja la música 10 dB")
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


## Un tema del catálogo puede ser solo la ruta (loopea entero) o {file, loop, loop_offset}: loop_offset es el segundo
## al que vuelve al terminar (lo que está antes es la intro y suena una sola vez). Se prueba con un OGG de verdad
## (los WAV no tienen loop_offset).
func _test_music_entries() -> void:
	_section("Temas con intro: loop y punto de loop")
	var ogg: String = "res://assets/music/title_screen.ogg"
	var audio: AudioScript = _make_audio()
	var catalog: Dictionary = _catalog()
	catalog["music"] = {
		"plain": ogg,
		"intro": { "file": "res://assets/music/fast_fight.ogg", "loop_offset": 0.25 },
		"once": { "file": "res://assets/music/ending.ogg", "loop": false },
	}
	_check(audio.load_catalog(catalog), "acepta temas como ruta o como {file, loop, loop_offset} (%s)" % audio.last_error)
	var plain: AudioStreamOggVorbis = load(ogg) as AudioStreamOggVorbis
	var intro: AudioStreamOggVorbis = load("res://assets/music/fast_fight.ogg") as AudioStreamOggVorbis
	var once: AudioStreamOggVorbis = load("res://assets/music/ending.ogg") as AudioStreamOggVorbis
	_check(plain.loop and plain.loop_offset == 0.0, "un tema que es solo la ruta loopea entero")
	_check(intro.loop and is_equal_approx(intro.loop_offset, 0.25), "con loop_offset vuelve a ese segundo (%.3f)" % intro.loop_offset)
	_check(not once.loop, "con loop: false suena una vez")
	var bad: Array[Dictionary] = [
		{ "music": { "a": { "loop_offset": 1.0 } } },
		{ "music": { "a": { "file": ogg, "loop_offset": -1.0 } } },
		{ "music": { "a": { "file": ogg, "loop_offset": 999.0 } } },
		{ "music": { "a": { "file": ogg, "loop": "sí" } } },
		{ "music": { "a": { "file": _song_a, "loop_offset": 1.0 } } },
		{ "music": { "a": { "file": ogg, "loop_offset": 1.0 }, "b": { "file": ogg, "loop_offset": 2.0 } } },
		{ "music": { "a": 5 } },
	]
	var reasons: Array[String] = [
		"un tema sin archivo", "un punto de loop negativo", "un punto de loop después del final", "un loop que no es sí/no",
		"un punto de loop en un sonido que no lo soporta (WAV)", "el mismo archivo con dos puntos de loop distintos",
		"un tema que no es ruta ni diccionario",
	]
	for index: int in range(bad.size()):
		_check(not audio.load_catalog(bad[index]), "rechaza %s" % reasons[index])
		_check(audio.last_error != "", "y dice por qué (%s)" % audio.last_error)
	_check(is_equal_approx(intro.loop_offset, 0.25), "un catálogo rechazado no toca los temas cargados")
	_check(audio.load_catalog({ "music": { "a": ogg, "b": ogg } }), "dos temas pueden usar el mismo archivo (Magma y Abismo)")
	_drop(audio)


## Volver a un tema que ya sonó lo retoma donde quedó (salir del frenesí no reinicia el tema del bioma), salvo que
## se pida desde el principio.
func _test_music_resume() -> void:
	_section("Música: volver a un tema lo retoma")
	var audio: AudioScript = _make_audio()
	_check(audio.play_music("earth", 0.0), "suena Tierra")
	_check_eq(audio.current_music_id(), "earth", "y lo dice current_music_id")
	await create_timer(0.5).timeout
	var left_at: float = audio.current_music_player().get_playback_position()
	_check(left_at > 0.3, "avanza (%.2f s)" % left_at)
	audio.play_music("rock", FADE)
	_check_eq(audio.current_music_id(), "rock", "cambia a Roca")
	await create_timer(FADE * 3.0).timeout
	audio.play_music("earth", FADE)
	var position: float = audio.current_music_player().get_playback_position()
	_check(position >= left_at - 0.05, "volver a Tierra la retoma donde quedó (%.2f s; había quedado en %.2f s)" % [position, left_at])
	await create_timer(FADE * 3.0).timeout
	audio.play_music("rock", FADE)
	await create_timer(FADE * 0.5).timeout
	# A mitad del fundido (Tierra todavía suena, bajando) se vuelve a Tierra: sigue el mismo reproductor, sin saltar.
	var fading: AudioStreamPlayer = null
	for player: AudioStreamPlayer in [audio.get_node("Music0"), audio.get_node("Music1")]:
		if player.playing and player.stream.resource_path == _song_a:
			fading = player
	_check(fading != null, "a mitad del fundido Tierra sigue sonando")
	var fading_at: float = fading.get_playback_position() if fading != null else 0.0
	audio.play_music("earth", FADE)
	_check(audio.current_music_player() == fading and fading.get_playback_position() >= fading_at, "volver a mitad del fundido sigue desde ahí, sin cortar")
	await create_timer(FADE * 3.0).timeout
	_check_near(audio.current_music_player().volume_linear, 1.0, "y sube a volumen completo", 1e-3)
	audio.play_music("rock", 0.0)
	audio.play_music("earth", 0.0, true)
	_check(audio.current_music_player().get_playback_position() < 0.1, "con from_start arranca de cero (%.2f s)" % audio.current_music_player().get_playback_position())
	audio.stop_music(0.0)
	_check_eq(audio.current_music_id(), "", "sin música, current_music_id es \"\"")
	_drop(audio)


func _test_real_autoload() -> void:
	_section("El autoload real")
	var audio: Node = root.get_node_or_null("Audio")
	_check(audio != null and audio.has_method("play_sfx"), "existe el autoload Audio con play_sfx")
	_check(audio != null and audio.get("settings") == root.get_node_or_null("Settings"), "y usa el autoload Settings")
	var source: String = FileAccess.get_file_as_string("res://core/audio.gd")
	var game_import: RegEx = RegEx.create_from_string("load\\(\\s*\"res://game/")
	_check(game_import.search(source) == null, "core/audio.gd no carga nada de res://game/")
