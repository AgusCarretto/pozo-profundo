extends "res://tests/test_base.gd"
## Tests headless de la música dinámica (game/music_director.gd) en la escena principal: el tema del bioma, la capa
## de frenesí cuando golpeás rápido, el tema de Opciones y el de la vuelta a la superficie.
##
## El director mide el ritmo con su propio reloj (`clock`); acá se lo reemplaza por uno de prueba que se adelanta a
## mano, así el frenesí se prueba sin esperar en tiempo real. Qué suena se mira con Audio.current_music_id().

const TestBalance := preload("res://tests/test_balance.gd")
const MAIN_SCENE: String = "res://game/main.tscn"
const STEP: float = 1.0 / 60.0

var _economy: Node
var _audio: Node
var _scene: Control
var _director: Node
## El reloj de prueba del director (segundos).
var _now: Array[float] = [100.0]


func _initialize() -> void:
	_economy = root.get_node_or_null("Economy")
	_audio = root.get_node_or_null("Audio")
	await process_frame
	if _economy == null or _audio == null:
		_check(false, "existen los autoloads Economy y Audio")
		_finish()
		return
	_check(_economy.load_balance(TestBalance.with_fixed_curve(JSON.parse_string(FileAccess.get_file_as_string("res://data/balance.json")))), "carga el balance real, con la curva fija de los tests")
	_economy.reset()
	_scene = (load(MAIN_SCENE) as PackedScene).instantiate() as Control
	root.add_child(_scene)
	await process_frame
	await process_frame
	_director = _scene.get_node_or_null("MusicDirector")
	_check(_director != null, "la escena tiene un director de música (MusicDirector)")
	if _director == null:
		_finish()
		return
	_director.clock = func() -> float: return _now[0]
	_test_biome_theme()
	await _test_frenzy()
	await _test_biome_change_during_frenzy()
	await _test_options()
	await _test_prestige()
	_scene.queue_free()
	await process_frame
	_economy.reset()
	_finish()


func _playing() -> String:
	return _audio.current_music_id()


## Adelanta el reloj de prueba `seconds`, golpeando `rate` veces por segundo (0 = sin golpes).
func _play(seconds: float, rate: float) -> void:
	var end: float = _now[0] + seconds
	var next_hit: float = _now[0]
	while _now[0] < end:
		if rate > 0.0 and _now[0] >= next_hit:
			_economy.hit()
			next_hit += 1.0 / rate
		_director.update()
		_now[0] += STEP


## Espera (en frames reales) a que la escena registre un cambio de Economy.
func _settle() -> void:
	await process_frame
	await process_frame
	_director.update()


func _test_biome_theme() -> void:
	_section("Cada bioma tiene su tema")
	_check(_director.frenzy.enabled(), "el frenesí usa los umbrales del balance")
	_check_eq(_playing(), "earth", "al abrir el juego en Tierra suena el tema de Tierra")


func _test_frenzy() -> void:
	_section("Golpear rápido trae la capa de frenesí")
	_play(1.5, 6.0)
	_check_eq(_playing(), "earth", "una ráfaga corta no la trae")
	_play(2.0, 6.0)
	_check_eq(_playing(), "frenzy", "6 golpes por segundo sostenidos más de 2 s pasan a la música de frenesí")
	var fight: AudioStreamPlayer = _audio.current_music_player()
	_check(fight != null and fight.volume_linear < 1.0, "con un fundido cruzado (entra bajo)")
	_check(fight != null and fight.get_playback_position() < 0.5, "desde el principio, con su subida (%.2f s)" % (fight.get_playback_position() if fight != null else -1.0))
	_play(2.0, 6.0)
	_check_eq(_playing(), "frenzy", "mientras sigas a ritmo alto, sigue")
	_play(2.5, 0.0)
	_check_eq(_playing(), "frenzy", "una pausa de 2 s no la corta")
	_play(2.0, 0.0)
	_check_eq(_playing(), "earth", "3 s sin ritmo alto, vuelve al tema del bioma")
	await process_frame
	_section("Ir a comprar no corta el frenesí")
	_economy.gold = 1.0e9
	var buy: Button = _scene.get_node("%Shop").get_child(1) as Button
	buy.pressed.emit()
	_play(1.0, 0.0)
	_check_eq(_playing(), "earth", "comprar sin frenesí no lo trae")
	_play(4.0, 6.0)
	_check_eq(_playing(), "frenzy", "en frenesí")
	for second: int in range(6):
		buy.pressed.emit()
		_play(1.0, 0.0)
	_check_eq(_playing(), "frenzy", "6 s comprando un minero por segundo, sin golpear: sigue el frenesí")
	(_scene.get_node("%Shop").get_child(0) as Button).pressed.emit()
	_play(2.5, 0.0)
	_check_eq(_playing(), "frenzy", "mejorar el pico también lo sostiene")
	_play(1.0, 0.0)
	_check_eq(_playing(), "earth", "3 s después de la última compra, vuelve al bioma")
	_economy.gold = 0.0
	await process_frame


func _test_biome_change_during_frenzy() -> void:
	_section("Cambiar de bioma en pleno frenesí")
	_play(4.0, 6.0)
	_check_eq(_playing(), "frenzy", "en frenesí")
	_economy.run_gold = 700.0 # Roca
	_economy.gold_changed.emit(_economy.gold)
	await _settle()
	_check_eq(_playing(), "frenzy", "bajar a Roca no corta el frenesí")
	_play(4.0, 0.0)
	_check_eq(_playing(), "rock", "y al terminar vuelve al tema del bioma nuevo (Roca)")


func _test_options() -> void:
	_section("Las Opciones tienen su tema")
	var options: Node = _scene.get_node("OptionsPanel")
	_play(4.0, 6.0)
	_check_eq(_playing(), "frenzy", "en frenesí")
	options.open()
	_director.update()
	_check_eq(_playing(), "options", "abrir Opciones pasa al tema de Opciones (también desde el frenesí)")
	_play(5.0, 0.0)
	_check_eq(_playing(), "options", "y sigue mientras estén abiertas")
	options.close()
	_director.update()
	_check_eq(_playing(), "rock", "al cerrarlas vuelve al bioma (el frenesí se cortó al abrirlas)")
	await process_frame


func _test_prestige() -> void:
	_section("La vuelta a la superficie tiene su tema")
	_economy.run_gold = 2.7e6 # ~451 m: ya se puede
	_economy.gold_changed.emit(_economy.gold)
	await _settle()
	_play(4.0, 6.0)
	_check_eq(_playing(), "frenzy", "en frenesí")
	(_scene.get_node("%RelicsButton") as Button).pressed.emit()
	(_scene.get_node("%PrestigeButton") as Button).pressed.emit()
	var modal: Node = _scene.get_node("Modal")
	(modal.get("confirm_button") as Button).pressed.emit()
	await process_frame
	_director.update()
	_check_eq(_playing(), "prestige", "confirmar la vuelta pasa al tema del prestigio")
	var ending: AudioStreamPlayer = _audio.current_music_player()
	_check(ending != null and ending.get_playback_position() < 0.5, "desde el principio (%.2f s)" % (ending.get_playback_position() if ending != null else -1.0))
	# La secuencia (fundido, reliquias volando) corre por tiempo real; mientras, el reloj del director no se mueve.
	var deadline: int = Time.get_ticks_msec() + 6000
	while _director.get("prestige_running") and Time.get_ticks_msec() < deadline:
		await process_frame
		_director.update()
	_check(not _director.get("prestige_running"), "la secuencia termina")
	_check_eq(_economy.biome_index(), 0, "ya estás en la superficie")
	_check_eq(_playing(), "prestige", "el tema del prestigio sigue un rato más")
	_play(_director.PRESTIGE_HOLD + 0.1, 0.0)
	_check_eq(_playing(), "earth", "y después vuelve el tema de Tierra")
	var earth: AudioStreamPlayer = _audio.current_music_player()
	_check(earth != null and earth.get_playback_position() < 0.5, "desde el principio: es una partida nueva (%.2f s)" % (earth.get_playback_position() if earth != null else -1.0))
	_check(not _director.frenzy.active, "y sin frenesí")
