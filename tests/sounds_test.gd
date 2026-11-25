extends "res://tests/test_base.gd"
## Tests headless de los sonidos del juego (F2-B): el catálogo real (data/sounds.json) y qué suena con
## cada acción de la escena principal.
##
## No escuchan nada: miran qué SFX pidió el juego (la señal Audio.sfx_played). Si suena bien o fuerte
## se decide con los auriculares puestos.

const MAIN_SCENE: String = "res://game/main.tscn"
const CATALOG_PATH: String = "res://data/sounds.json"
const AUDIO_DIR: String = "res://assets/audio"
const MUSIC_DIR: String = "res://assets/music"
## Qué tema suena en cada situación (los biomas por id del balance). Es la decisión de reparto, no balance.
const MUSIC_MAP: Dictionary = {
	"earth": "town_theme.ogg",
	"rock": "level_1.ogg",
	"crystal": "crystal_cave.ogg",
	"magma": "level_2.ogg",
	"abyss": "level_2.ogg",
	"frenzy": "fast_fight.ogg",
	"prestige": "ending.ogg",
	"options": "title_screen.ogg",
}
## Los temas que tienen intro: el loop vuelve después (segundos mínimos de intro).
const MUSIC_INTROS: Dictionary = { "earth": 10.0, "frenzy": 1.5 }
## El prestigio suena una vez; el resto loopea.
const MUSIC_ONCE: Array[String] = ["prestige"]
## Los SFX que el juego pide sí o sí (los de los cofres se agregan por rareza del balance).
const REQUIRED_SFX: Array[String] = ["hit", "crit", "buy", "pick", "tab", "mode", "toggle", "open", "close", "prestige", "biome", "dynamite", "coins", "relic"]

var _economy: Node
var _audio: Node
var _scene: Control
var _played: Array[String] = []


func _initialize() -> void:
	_economy = root.get_node_or_null("Economy")
	_audio = root.get_node_or_null("Audio")
	# Los _ready de los autoloads (Audio lee el catálogo) corren después de _initialize.
	await process_frame
	_test_catalog()
	_test_files()
	_test_music_catalog()
	_test_music_loops()
	if _economy == null or _audio == null:
		_check(false, "existen los autoloads Economy y Audio")
		_finish()
		return
	_audio.sfx_played.connect(_record)
	await _mount()
	await _test_economy_cues()
	await _test_ui_cues()
	await _test_dynamite_cue()
	await _test_biome_cue()
	await _test_prestige_cues()
	await _test_music_follows_biome()
	_scene.queue_free()
	await process_frame
	_economy.reset()
	_finish()


func _record(id: String) -> void:
	_played.append(id)


func _catalog() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	return parsed if parsed is Dictionary else {}


## El balance real, sin críticos: con uno al azar sonaría "crit" en vez de "hit".
func _real_balance() -> Dictionary:
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance.json"))
	balance.erase("crit")
	return balance


func _mount() -> void:
	_check(_economy.load_balance(_real_balance()), "carga el balance real")
	_take()
	_scene = (load(MAIN_SCENE) as PackedScene).instantiate() as Control
	root.add_child(_scene)
	await process_frame
	await process_frame
	var played: Array[String] = _take()
	_check(played.is_empty(), "abrir la escena no hace sonar nada (%s)" % str(played))


func _button(node_name: String) -> Button:
	return _scene.get_node("%" + node_name) as Button


## Lo que sonó desde la última vez que se miró (y lo olvida).
func _take() -> Array[String]:
	var played: Array[String] = _played.duplicate()
	_played.clear()
	return played


func _test_catalog() -> void:
	_section("El catálogo de sonidos")
	_check(FileAccess.file_exists(CATALOG_PATH), "existe " + CATALOG_PATH)
	_check(_audio != null and _audio.last_error == "", "el autoload Audio lo cargó sin errores (%s)" % (_audio.last_error if _audio != null else "sin Audio"))
	if _audio == null:
		return
	var required: Array[String] = REQUIRED_SFX.duplicate()
	for rarity: Variant in _real_balance()["loot"]["rarities"]:
		required.append("chest_%s" % (rarity as Dictionary)["id"])
	for id: String in required:
		_check(_audio.has_sfx(id), "tiene sonido para '%s'" % id)
	_check(_audio.sfx_variants("hit") >= 3, "el golpe, que suena todo el tiempo, tiene varias variantes (%d)" % _audio.sfx_variants("hit"))
	var hit: Dictionary = _catalog()["sfx"]["hit"]
	_check(hit.has("pitch") and float(hit["pitch"][0]) < float(hit["pitch"][1]), "y su tono varía")


func _test_files() -> void:
	_section("Los archivos de sonido")
	var referenced: Dictionary = {}
	var catalog: Dictionary = _catalog()
	for id: String in catalog.get("sfx", {}):
		for file: Variant in catalog["sfx"][id]["files"]:
			referenced[str(file)] = true
	var outside: Array[String] = []
	for path: String in referenced:
		if not path.begins_with(AUDIO_DIR + "/"):
			outside.append(path)
	var music_files: Dictionary = {}
	for id: String in catalog.get("music", {}):
		var path: String = _music_file(catalog["music"][id])
		music_files[path] = true
		if not path.begins_with(MUSIC_DIR + "/"):
			outside.append(path)
	_check(outside.is_empty(), "los SFX viven en %s/ y la música en %s/ (fuera: %s)" % [AUDIO_DIR, MUSIC_DIR, str(outside)])
	var unused: Array[String] = []
	for path: String in _list_audio(AUDIO_DIR):
		if not referenced.has(path):
			unused.append(path)
	for path: String in _list_audio(MUSIC_DIR):
		if not music_files.has(path):
			unused.append(path)
	_check(unused.is_empty(), "y no hay sonidos importados sin usar (%s)" % str(unused))
	var not_ogg: Array[String] = []
	for path: String in music_files:
		if path.get_extension() != "ogg":
			not_ogg.append(path)
	_check(not_ogg.is_empty(), "la música es OGG (%s)" % str(not_ogg))


## La ruta de un tema del catálogo: es la entrada misma o su "file".
func _music_file(entry: Variant) -> String:
	return str((entry as Dictionary).get("file", "")) if entry is Dictionary else str(entry)


func _test_music_catalog() -> void:
	_section("La música del catálogo")
	var music: Dictionary = _catalog().get("music", {})
	for id: String in MUSIC_MAP:
		_check(_audio.has_music(id), "hay tema para '%s'" % id)
		_check_eq(_music_file(music.get(id, "")), "%s/%s" % [MUSIC_DIR, MUSIC_MAP[id]], "'%s' es %s" % [id, MUSIC_MAP[id]])
	for biome: Variant in _real_balance()["biomes"]["list"]:
		_check(_audio.has_music(str((biome as Dictionary)["id"])), "cada bioma del balance tiene tema ('%s')" % (biome as Dictionary)["id"])
	for id: String in MUSIC_MAP:
		var stream: AudioStreamOggVorbis = load("%s/%s" % [MUSIC_DIR, MUSIC_MAP[id]]) as AudioStreamOggVorbis
		if stream == null:
			continue
		if id in MUSIC_ONCE:
			_check(not stream.loop, "'%s' suena una vez" % id)
			continue
		_check(stream.loop, "'%s' loopea" % id)
		_check(stream.loop_offset >= float(MUSIC_INTROS.get(id, 0.0)) and stream.loop_offset < stream.get_length(), "'%s' vuelve después de su intro (%.2f s de %.1f s)" % [id, stream.loop_offset, stream.get_length()])


## Cada loop, tal como lo mezcla Godot, empalma sin clic: se mezcla desde un poco antes del final, cruzando la vuelta
## al punto de loop. Sigue sonando (no corta) y el salto de onda en la vuelta no es mayor que los saltos normales del
## tema alrededor (un clic sería el salto más grande de lejos).
func _test_music_loops() -> void:
	_section("Los loops empalman sin clic")
	var checked: Dictionary = {}
	for id: String in MUSIC_MAP:
		if id in MUSIC_ONCE or checked.has(MUSIC_MAP[id]):
			continue
		checked[MUSIC_MAP[id]] = true
		var stream: AudioStreamOggVorbis = load("%s/%s" % [MUSIC_DIR, MUSIC_MAP[id]]) as AudioStreamOggVorbis
		if stream == null or not stream.loop:
			_check(false, "'%s' es un OGG que loopea" % id)
			continue
		var lead: float = 0.25
		var playback: AudioStreamPlayback = stream.instantiate_playback()
		playback.start(stream.get_length() - lead)
		var rate: float = AudioServer.get_mix_rate()
		var frames: PackedVector2Array = PackedVector2Array()
		var wanted: int = int(rate * lead * 2.0)
		while frames.size() < wanted:
			var chunk: PackedVector2Array = playback.mix_audio(1.0, mini(1024, wanted - frames.size()))
			if chunk.is_empty():
				break
			frames.append_array(chunk)
		playback.stop()
		_check_eq(frames.size(), wanted, "'%s' sigue sonando después del final" % MUSIC_MAP[id])
		if frames.size() < wanted:
			continue
		var after: float = 0.0
		for index: int in range(int(rate * lead) + 64, frames.size()):
			after = maxf(after, absf(frames[index].x) + absf(frames[index].y))
		_check(after > 0.01, "'%s': lo que viene después de la vuelta es música, no silencio" % MUSIC_MAP[id])
		# El salto más grande cerca de la vuelta (±2 ms) contra el más grande del resto de la ventana.
		var seam: int = int(rate * lead)
		var near: int = int(rate * 0.002)
		var seam_jump: float = 0.0
		var other_jump: float = 0.0
		for index: int in range(1, frames.size()):
			var jump: float = maxf(absf(frames[index].x - frames[index - 1].x), absf(frames[index].y - frames[index - 1].y))
			if absi(index - seam) <= near:
				seam_jump = maxf(seam_jump, jump)
			else:
				other_jump = maxf(other_jump, jump)
		_check(seam_jump <= other_jump, "'%s': la vuelta no salta más que la música alrededor (%.4f vs %.4f)" % [MUSIC_MAP[id], seam_jump, other_jump])


func _list_audio(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return found
	for sub: String in dir.get_directories():
		found.append_array(_list_audio(dir_path + "/" + sub))
	for file_name: String in dir.get_files():
		if file_name.get_extension() in ["ogg", "wav", "mp3"]:
			found.append(dir_path + "/" + file_name)
	return found


func _test_economy_cues() -> void:
	_section("Lo que pasa en la mina suena")
	_economy.reset()
	_economy.gold = 1.0e6
	await process_frame
	_take()
	_button("TapButton").button_down.emit()
	_check(_take().has("hit"), "golpear la roca")
	var sure: Dictionary = _real_balance()
	sure["crit"] = { "chance": 1.0, "multiplier": 2.0 }
	_economy.load_balance(sure)
	_take()
	_button("TapButton").button_down.emit()
	var critical: Array[String] = _take()
	_check(critical.has("crit") and not critical.has("hit"), "un crítico suena distinto (%s)" % str(critical))
	_economy.load_balance(_real_balance())
	_economy.gold = 1.0e6
	await process_frame
	_take()
	var buy: Button = _scene.get_node("%Shop").get_child(1) as Button
	buy.pressed.emit()
	_check(_take().has("buy"), "comprar un generador")
	var pick: Button = _scene.get_node("%Shop").get_child(0) as Button
	pick.pressed.emit()
	_check(_take().has("pick"), "mejorar el pico")
	var table: Array = _economy.loot_table()
	for index: int in range(table.size()):
		_economy.drop_loot(index)
		var id: String = "chest_%s" % (table[index] as Dictionary)["id"]
		_check(_take().has(id), "un cofre %s suena como %s" % [(table[index] as Dictionary)["name"], id])
	_economy.reset()
	await process_frame


func _test_ui_cues() -> void:
	_section("La interfaz suena")
	_take()
	_button("LootButton").pressed.emit()
	_check(_take().has("tab"), "abrir Botín")
	_scene.get_node("%LootPanel").call("close")
	_check(_take().has("close"), "cerrarlo")
	_button("ModeButton").pressed.emit()
	_check(_take().has("mode"), "cambiar el modo de compra")
	_button("ModeButton").pressed.emit()
	_button("ModeButton").pressed.emit()
	_take()
	var modal: Control = _scene.get_node("Modal") as Control
	modal.open("Aviso", "Cuerpo", "Listo")
	_check(_take().has("open"), "abrir un cartel")
	modal.close()
	_check(_take().has("close"), "cerrarlo")
	await process_frame


func _test_biome_cue() -> void:
	_section("Llegar a un bioma nuevo suena")
	_economy.reset()
	await process_frame
	_take()
	_economy.run_gold = 700.0 # Roca
	_economy.gold_changed.emit(_economy.gold)
	await process_frame
	_check(_take().has("biome"), "entrar a Roca")
	_economy.gold_changed.emit(_economy.gold)
	await process_frame
	_check(not _take().has("biome"), "y no vuelve a sonar mientras sigas en Roca")
	# Una escena que arranca en un bioma profundo (una partida guardada) no suena al abrir.
	_scene.queue_free()
	await process_frame
	_economy.run_gold = 60000.0 # Cristal
	_scene = (load(MAIN_SCENE) as PackedScene).instantiate() as Control
	root.add_child(_scene)
	await process_frame
	await process_frame
	_check(not _take().has("biome"), "abrir el juego ya en Cristal no suena como bioma nuevo")


func _test_prestige_cues() -> void:
	_section("Volver a la superficie")
	_economy.run_gold = 2.7e6 # ~451 m: ya se puede
	_economy.gold_changed.emit(_economy.gold)
	await process_frame
	_button("RelicsButton").pressed.emit()
	_take()
	_button("PrestigeButton").pressed.emit()
	_check(_take().has("open"), "pedir volver abre el cartel")
	var modal: Node = _scene.get_node("Modal")
	(modal.get("confirm_button") as Button).pressed.emit()
	# La vuelta a la superficie pasa detrás de un fundido: se espera (por tiempo real) a que suceda.
	var played: Array[String] = []
	var deadline: int = Time.get_ticks_msec() + 3000
	while not played.has("prestige") and Time.get_ticks_msec() < deadline:
		await process_frame
		played.append_array(_take())
	await create_timer(1.5).timeout
	played.append_array(_take())
	_check(played.has("prestige"), "confirmar suena como prestigio (%s)" % str(played))
	_check(not played.has("biome"), "y volver a Tierra no suena como bioma nuevo")


func _test_dynamite_cue() -> void:
	_section("La dinamita explota con sonido")
	_economy.reset()
	_economy.owned[2] = 400
	_economy.gold_changed.emit(_economy.gold)
	_take()
	var heard: bool = false
	# En headless los frames corren sin límite: se espera por tiempo real.
	var deadline: int = Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if _played.has("dynamite"):
			heard = true
			break
	_check(heard, "una explosión suena")
	_economy.reset()
	_economy.gold_changed.emit(_economy.gold)
	await process_frame


## Cada bioma tiene su tema (music.<id del bioma> en el catálogo). Todavía no hay música en el juego: se prueba
## con un catálogo de prueba (dos sonidos mudos) y al final se vuelve a cargar el real.
func _test_music_follows_biome() -> void:
	_section("La música sigue al bioma")
	DirAccess.make_dir_recursive_absolute("user://sounds_test")
	var paths: Array[String] = []
	for song: String in ["earth", "rock"]:
		var wav: AudioStreamWAV = AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = 22050
		var data: PackedByteArray = PackedByteArray()
		data.resize(22050 * 2 * 2)
		wav.data = data
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = 22050 * 2
		var path: String = "user://sounds_test/%s.tres" % song
		ResourceSaver.save(wav, path)
		paths.append(path)
	_check(_audio.load_catalog({ "music": { "earth": paths[0], "rock": paths[1] } }), "carga un catálogo de prueba con música")
	_economy.reset()
	_economy.gold_changed.emit(_economy.gold)
	_scene.queue_free()
	await process_frame
	_scene = (load(MAIN_SCENE) as PackedScene).instantiate() as Control
	root.add_child(_scene)
	await process_frame
	await process_frame
	var player: AudioStreamPlayer = _audio.current_music_player()
	_check(player != null and player.stream.resource_path == paths[0], "al abrir el juego en Tierra suena el tema de Tierra")
	_economy.run_gold = 700.0
	_economy.gold_changed.emit(_economy.gold)
	await process_frame
	await process_frame
	player = _audio.current_music_player()
	_check(player != null and player.stream.resource_path == paths[1], "al bajar a Roca cambia al tema de Roca")
	_economy.reset()
	_economy.gold_changed.emit(_economy.gold)
	await process_frame
	await process_frame
	player = _audio.current_music_player()
	_check(player != null and player.stream.resource_path == paths[0], "y al volver a la superficie, al de Tierra")
	_audio.stop_music(0.0)
	_check(_audio.load_catalog_file("res://data/sounds.json"), "se vuelve a cargar el catálogo real")
	for path: String in paths:
		DirAccess.remove_absolute(path)
	DirAccess.remove_absolute("user://sounds_test")
