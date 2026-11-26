extends "res://tests/test_base.gd"
## Los momentos para festejar (balance real): al volver a la superficie se abre el árbol solo, y un logro se festeja con
## sonido, destello y pausa sin tapar el juego ni salir detrás de la vuelta.

const MAIN_SCENE: String = "res://game/main.tscn"

var _economy: Node
var _audio: Node
var _settings: Node
var _scene: Control
var _played: Array[String] = []


func _initialize() -> void:
	_economy = root.get_node_or_null("Economy")
	_audio = root.get_node_or_null("Audio")
	_settings = root.get_node_or_null("Settings")
	var save: Node = root.get_node_or_null("Save")
	if save != null:
		save.persistence_enabled = false
	await process_frame
	_check(_economy.load_balance_file("res://data/balance.json"), "carga el balance real (%s)" % _economy.last_error)
	_audio.sfx_played.connect(func(id: String) -> void: _played.append(id))
	var reduce: bool = _settings.reduce_effects
	var muted: bool = _settings.muted
	_settings.muted = false
	_settings.reduce_effects = false
	_test_pitch_multiplier()
	var packed: PackedScene = load(MAIN_SCENE) as PackedScene
	await _mount(packed)
	await _test_achievement_is_celebrated()
	await _test_the_rock_still_works()
	await _test_reduced_effects()
	await _test_prestige_opens_the_tree()
	await _unmount()
	_settings.reduce_effects = reduce
	_settings.muted = muted
	_economy.reset()
	_finish()


func _mount(packed: PackedScene) -> void:
	_economy.reset()
	_scene = packed.instantiate() as Control
	root.add_child(_scene)
	await _frames(3)


func _unmount() -> void:
	_scene.queue_free()
	await process_frame


func _frames(count: int = 2) -> void:
	for i: int in range(count):
		await process_frame


## Espera en tiempo real: la pausa del festejo frena el tiempo de juego.
func _wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout


func _wait_until(done: Callable, seconds: float = 10.0) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while not done.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	return done.call()


func _find(node_name: String) -> Control:
	return _scene.find_child(node_name, true, false) as Control


func _celebration() -> Control:
	return _find("AchievementCelebration")


func _text(node_name: String) -> String:
	return (_celebration().find_child(node_name, true, false) as Label).text


func _flash() -> ColorRect:
	return _find("ScreenFx").find_child("Flash", true, false) as ColorRect


func _test_pitch_multiplier() -> void:
	_section("Un sonido puede subir de tono a pedido")
	var base: AudioStreamPlayer = _audio.play_sfx("chest_epic")
	var low: float = base.pitch_scale
	var high: AudioStreamPlayer = _audio.play_sfx("chest_epic", 1.5)
	_check_near(high.pitch_scale, low * 1.5, "el tono se multiplica", 0.001)


func _test_achievement_is_celebrated() -> void:
	_section("Un logro se festeja")
	_check(_celebration() != null and not _celebration().visible, "sin logros no hay festejo")
	_played.clear()
	var scale_before: float = Engine.time_scale
	_economy.unlock_achievement("hits_100")
	await _frames(1)
	_check(_celebration().visible, "aparece")
	_check(_played.has("achievement"), "con su sonido (%s)" % str(_played))
	_check_eq(_text("CelebrationTitle"), "¡LOGRO!", "título")
	_check_eq(_text("CelebrationName"), "Primeras astillas", "y cuál es")
	var game_font: Font = (_scene.get_node("%GoldLabel") as Label).get_theme_font("font")
	var title: Label = _celebration().find_child("CelebrationTitle", true, false) as Label
	_check_eq(title.get_theme_font("font"), game_font, "con la fuente del juego")
	_check(_celebration().find_child("Medallion", true, false) != null, "y el trofeo sobre un medallón que lo destaca")
	_check(_flash().color.a > 0.0, "con un destello")
	_check(Engine.time_scale < scale_before, "y una pausa en cámara lenta")
	_check(_celebration().find_child("Confetti", true, false) != null, "y papelitos")
	await _wait(0.6)
	_check_near(Engine.time_scale, scale_before, "la pausa termina sola")
	var catches: Array[String] = []
	for node: Node in _celebration().find_children("*", "Control", true, false) + [_celebration()]:
		if (node as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			catches.append(str(node.name))
	_check(catches.is_empty(), "no come ningún toque (%s)" % str(catches))
	_economy.achievements.add("hits", 1000.0)
	_economy.achievements.add("crits", 100.0)
	_economy.check_achievements()
	await _frames(1)
	_check_eq(_text("CelebrationName"), "3 logros nuevos", "los que llegan mientras dura se suman al mismo festejo (%s)" % _text("CelebrationName"))
	_check(await _wait_until(func() -> bool: return not _celebration().visible), "y se va solo")


func _test_the_rock_still_works() -> void:
	_section("Se sigue picando durante el festejo")
	_economy.unlock_achievement("gear_opens_50")
	await _wait(0.5)
	var rock: Button = _scene.get_node("%TapButton") as Button
	var before: float = _economy.gold
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.position = root.get_final_transform() * rock.get_global_rect().get_center()
	touch.pressed = true
	Input.parse_input_event(touch)
	Input.flush_buffered_events()
	await _frames(1)
	var up: InputEventScreenTouch = touch.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await _frames(1)
	_check(_economy.gold > before, "el toque llega a la roca")
	_celebration().call("dismiss")


func _test_reduced_effects() -> void:
	_section("Con \"reducir efectos\"")
	_settings.reduce_effects = true
	await _frames(1)
	_flash().color.a = 0.0
	var scale_before: float = Engine.time_scale
	_economy.unlock_achievement("loot_views_25")
	await _frames(1)
	_check(_celebration().visible, "el festejo igual aparece")
	_check_eq(_flash().color.a, 0.0, "sin destello")
	_check_near(Engine.time_scale, scale_before, "ni pausa")
	_celebration().call("dismiss")
	_settings.reduce_effects = false


func _test_prestige_opens_the_tree() -> void:
	_section("Al volver a la superficie se abre el árbol")
	_economy.reset()
	_find("AchievementToast").call("dismiss")
	_celebration().call("dismiss")
	_economy.run_gold = 1.0e12
	_check(_economy.can_prestige(), "(se puede volver)")
	var tree: Control = _find("TreeView")
	# El reloj del director queda quieto durante la vuelta; después se adelanta para pasar el tema del prestigio.
	var director: Node = _scene.get_node("MusicDirector")
	var now: Array[float] = [Time.get_ticks_usec() / 1000000.0]
	director.set("clock", func() -> float: return now[0])
	_scene.call("_confirm_prestige")
	await _frames(3)
	_check(not tree.visible, "durante la vuelta todavía no")
	_check(not _celebration().visible, "ni el festejo del logro de volver, que quedaría tapado")
	_check(await _wait_until(func() -> bool: return not _scene.get("_prestiging")), "(termina la vuelta)")
	await _frames(2)
	_check(tree.visible, "y el árbol se abre solo")
	_check(_celebration().visible, "ahí sí se festejan los logros")
	now[0] += 60.0
	director.call("update")
	_check_eq(_audio.current_music_id(), "tree", "después del tema de la vuelta suena el del árbol")
	(tree.find_child("CloseTree", true, false) as Button).pressed.emit()
	director.call("update")
	_check_eq(_audio.current_music_id(), "earth", "y al cerrarlo, el de Tierra")
	var player: AudioStreamPlayer = _audio.current_music_player()
	_check(player != null and player.get_playback_position() < 0.5, "desde el principio: es una bajada nueva")
	_celebration().call("dismiss")
