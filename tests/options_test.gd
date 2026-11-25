extends "res://tests/test_base.gd"
## Tests headless del botón de silencio y del panel de Opciones (F2-B).
##
## En el HUD, al lado del multiplicador: un botón que silencia todo y un engranaje que abre Opciones
## (volumen de música y de SFX, y "reducir efectos"). Todo va a Settings, que lo guarda. Usa los autoloads
## reales; al final deja Settings como estaba.

const MAIN_SCENE: String = "res://game/main.tscn"
const WebPlatform := preload("res://core/web_platform.gd")
const ICON_DIR: String = "res://assets/ui/game_icons/"
const LINK: String = "https://ejemplo.com/opinar"
const TOUCH_MIN: float = 96.0
const DESIGN_WIDTH: float = 720.0
const PHONE_SIZES: Array[Vector2] = [Vector2(720, 1280), Vector2(720, 1599)]

## Navegador de mentira: dice si hay pantalla completa y anota lo que se le pide.
class FakePlatform extends WebPlatform:
	var supported: bool = true
	var full: bool = false
	var opened: Array[String] = []

	func can_fullscreen() -> bool:
		return supported

	func is_fullscreen() -> bool:
		return full

	func set_fullscreen(on: bool) -> void:
		full = on

	func open_url(url: String) -> void:
		opened.append(url)


var _settings: Node
var _saved_settings: Dictionary = {}
var _played: Array[String] = []


func _initialize() -> void:
	await process_frame
	_settings = root.get_node_or_null("Settings")
	_check(_settings != null, "existe el autoload Settings")
	if _settings == null:
		_finish()
		return
	_saved_settings = _settings.to_dict()
	(root.get_node("Audio") as Node).sfx_played.connect(func(id: String) -> void: _played.append(id))
	var packed: PackedScene = load(MAIN_SCENE) as PackedScene
	await _test_hud_buttons(packed)
	await _test_mute_button(packed)
	await _test_options_panel(packed)
	_test_js_booleans()
	await _test_web_options(packed)
	await _test_credits(packed)
	await _test_options_layout(packed)
	_settings.from_dict(_saved_settings)
	_finish()


## JavaScriptBridge.eval no devuelve un bool para el true de JavaScript: en la web llega el entero 1.
func _test_js_booleans() -> void:
	_section("Las respuestas del navegador")
	for yes: Variant in [true, 1, 1.0]:
		_check_eq(WebPlatform.is_true(yes), true, "%s es sí" % str(yes))
	for no: Variant in [false, 0, 0.0, null, "", "true"]:
		_check_eq(WebPlatform.is_true(no), false, "%s es no" % str(no))


func _mount(packed: PackedScene, host_size: Vector2) -> Control:
	var host: Control = Control.new()
	host.size = host_size
	root.add_child(host)
	var scene: Control = packed.instantiate() as Control
	host.add_child(scene)
	await process_frame
	await process_frame
	return scene


func _free(scene: Control) -> void:
	scene.get_parent().queue_free()
	await process_frame


func _node(scene: Control, node_name: String) -> Control:
	return scene.get_node("%" + node_name) as Control


func _icon_name(button: Button) -> String:
	return button.icon.resource_path.get_file().get_basename() if button.icon != null else ""


func _test_hud_buttons(packed: PackedScene) -> void:
	_section("Silencio y opciones en el HUD, al lado del multiplicador")
	for phone: Vector2 in PHONE_SIZES:
		var scene: Control = await _mount(packed, phone)
		var label: String = "%dx%d" % [int(phone.x), int(phone.y)]
		var sound: Button = _node(scene, "SoundButton") as Button
		var options: Button = _node(scene, "OptionsButton") as Button
		var badge: Control = _node(scene, "MultBadge")
		_check(sound != null and options != null, "[%s] existen el botón de silencio y el de opciones" % label)
		if sound == null or options == null:
			await _free(scene)
			continue
		_check(sound.get_parent() == badge.get_parent() and options.get_parent() == badge.get_parent(), "[%s] están en la fila del oro, con el multiplicador" % label)
		_check(sound.get_index() == badge.get_index() + 1 and options.get_index() == sound.get_index() + 1, "[%s] a la derecha del multiplicador: silencio y después opciones" % label)
		for button: Button in [sound, options]:
			_check(button.size.x >= TOUCH_MIN - 0.5 and button.size.y >= TOUCH_MIN - 0.5, "[%s] %s mide al menos %d x %d (%s)" % [label, button.name, int(TOUCH_MIN), int(TOUCH_MIN), str(button.size)])
			_check(button.text == "" and button.icon != null, "[%s] %s es solo un ícono" % [label, button.name])
			_check(button.get_global_rect().end.x <= DESIGN_WIDTH + 0.5, "[%s] %s entra en la pantalla" % [label, button.name])
			_check_eq(button.theme_type_variation, &"ButtonNeutral", "[%s] %s es neutro (no tiene un rol de color)" % [label, button.name])
			_check_eq(button.focus_mode, Control.FOCUS_NONE, "[%s] %s no se queda con el foco" % [label, button.name])
		_check_eq(_icon_name(options), "gear", "[%s] opciones es un engranaje" % label)
		await _free(scene)


func _test_mute_button(packed: PackedScene) -> void:
	_section("El botón de silencio")
	_settings.muted = false
	var scene: Control = await _mount(packed, PHONE_SIZES[0])
	var sound: Button = _node(scene, "SoundButton") as Button
	_check_eq(_icon_name(sound), "audioOn", "con sonido muestra el parlante encendido")
	sound.pressed.emit()
	_check_eq(_settings.muted, true, "tocarlo silencia todo")
	await process_frame
	_check_eq(_icon_name(sound), "audioOff", "y muestra el parlante tachado")
	_played.clear()
	sound.pressed.emit()
	_check_eq(_settings.muted, false, "tocarlo de nuevo devuelve el sonido")
	_check(_played.has("toggle"), "y suena el click (con sonido ya puesto)")
	await process_frame
	_check_eq(_icon_name(sound), "audioOn", "con el parlante encendido")
	_settings.muted = true
	await process_frame
	_check_eq(_icon_name(sound), "audioOff", "si el silencio cambia por otro lado (una partida cargada), el ícono lo sigue")
	_settings.muted = false
	await _free(scene)
	var mute_icon: String = ICON_DIR + "audioOff.png"
	_check(ResourceLoader.exists(mute_icon) and ResourceLoader.exists(ICON_DIR + "audioOn.png") and ResourceLoader.exists(ICON_DIR + "gear.png"), "los íconos son de Game Icons y están importados")


func _test_options_panel(packed: PackedScene) -> void:
	_section("El panel de Opciones")
	_settings.from_dict({ "music_volume": 0.4, "music_scale": 2, "sfx_volume": 0.9, "muted": false, "reduce_effects": false })
	var scene: Control = await _mount(packed, PHONE_SIZES[0])
	var panel: Control = scene.get_node_or_null("OptionsPanel") as Control
	_check(panel != null, "existe el panel de Opciones")
	if panel == null:
		await _free(scene)
		return
	_check(not panel.visible, "empieza cerrado")
	_played.clear()
	(_node(scene, "OptionsButton") as Button).pressed.emit()
	await process_frame
	_check(panel.visible, "el engranaje lo abre")
	_check(_played.has("open"), "y suena como un cartel")
	_check_eq(panel.mouse_filter, Control.MOUSE_FILTER_STOP, "mientras está abierto traga los toques (la roca no responde)")
	var music: HSlider = panel.get("music_slider") as HSlider
	var sfx: HSlider = panel.get("sfx_slider") as HSlider
	var reduce: CheckButton = panel.get("reduce_check") as CheckButton
	var close: Button = panel.get("close_button") as Button
	_check(music != null and sfx != null and reduce != null and close != null, "tiene volumen de música, de SFX, reducir efectos y cerrar")
	if music == null or sfx == null or reduce == null or close == null:
		await _free(scene)
		return
	_check_near(music.value, 0.4, "el volumen de música arranca en lo guardado")
	_check_near(sfx.value, 0.9, "y el de SFX también")
	_check(not reduce.button_pressed, "reducir efectos arranca apagado")
	_check(panel.find_children("*", "Label", true, false).any(func(l: Label) -> bool: return l.text == "40%"), "muestra el volumen en porcentaje (40%)")
	music.value = 0.75
	_check_near(_settings.music_volume, 0.75, "mover el volumen de música lo cambia en Settings")
	sfx.value = 0.3
	_check_near(_settings.sfx_volume, 0.3, "y el de SFX")
	await process_frame
	_check(panel.find_children("*", "Label", true, false).any(func(l: Label) -> bool: return l.text == "75%"), "el porcentaje se actualiza (75%)")
	_played.clear()
	sfx.drag_ended.emit(true)
	_check(_played.has("hit"), "al soltar el volumen de SFX suena un golpe de muestra")
	reduce.button_pressed = true
	_check_eq(_settings.reduce_effects, true, "reducir efectos se prende")
	_check(panel.find_children("*", "Label", true, false).any(func(l: Label) -> bool: return l.text.contains("sacudidas")), "y explica qué hace")
	_played.clear()
	close.pressed.emit()
	await process_frame
	_check(not panel.visible, "cerrar lo cierra")
	_check(_played.has("close"), "con su sonido")
	# Lo que cambia por otro lado se ve al volver a abrir.
	_settings.music_volume = 0.1
	(_node(scene, "OptionsButton") as Button).pressed.emit()
	await process_frame
	_check_near(music.value, 0.1, "al reabrir muestra el valor actual")
	close.pressed.emit()
	# El orden de dibujo: arriba del panel de debug y debajo del cartel modal (que va último).
	var debug: Node = scene.get_node_or_null("DebugPanel")
	var modal: Node = scene.get_node("Modal")
	if debug != null:
		_check(panel.get_index() > debug.get_index(), "se dibuja encima del panel de debug")
	_check(panel.get_index() < modal.get_index(), "y debajo del cartel modal")
	await _free(scene)


func _open_options(packed: PackedScene, platform: FakePlatform, url: String) -> Control:
	var scene: Control = await _mount(packed, PHONE_SIZES[0])
	var panel: Control = scene.get_node("OptionsPanel") as Control
	panel.set("platform", platform)
	panel.set("feedback_url", url)
	(_node(scene, "OptionsButton") as Button).pressed.emit()
	await process_frame
	return scene


func _test_web_options(packed: PackedScene) -> void:
	_section("Versión, pantalla completa y Opinar")
	var platform: FakePlatform = FakePlatform.new()
	platform.supported = false
	var scene: Control = await _open_options(packed, platform, "")
	var panel: Control = scene.get_node("OptionsPanel") as Control
	var version: Label = panel.get("version_label") as Label
	var full: Button = panel.get("fullscreen_button") as Button
	var feedback: Button = panel.get("feedback_button") as Button
	_check(version != null and full != null and feedback != null, "tiene versión, pantalla completa y Opinar")
	if version == null or full == null or feedback == null:
		await _free(scene)
		return
	_check_eq(version.text, "Versión 0.4.0", "muestra la versión")
	_check(version.is_visible_in_tree(), "a la vista")
	_check(not full.visible, "si el navegador no permite pantalla completa, no hay botón")
	_check(not feedback.visible, "sin link no hay Opinar")
	await _free(scene)
	platform = FakePlatform.new()
	scene = await _open_options(packed, platform, LINK)
	panel = scene.get_node("OptionsPanel") as Control
	full = panel.get("fullscreen_button") as Button
	feedback = panel.get("feedback_button") as Button
	_check(full.visible and full.text == "Pantalla completa", "con soporte: 'Pantalla completa'")
	full.pressed.emit()
	await process_frame
	_check(platform.full, "tocarlo la activa")
	_check_eq(full.text, "Salir de pantalla completa", "y el botón pasa a salir")
	full.pressed.emit()
	await process_frame
	_check(not platform.full and full.text == "Pantalla completa", "y vuelve")
	platform.full = true
	await process_frame
	_check_eq(full.text, "Salir de pantalla completa", "si cambia por fuera (gesto de atrás, tecla) el texto lo sigue")
	_check(feedback.visible and feedback.text == "Opinar", "con link aparece Opinar")
	_check(platform.opened.is_empty(), "no abre nada solo")
	feedback.pressed.emit()
	_check_eq(platform.opened, [LINK] as Array[String], "tocarlo abre ese link")
	await _free(scene)


func _test_credits(packed: PackedScene) -> void:
	_section("Créditos y licencias")
	var scene: Control = await _open_options(packed, FakePlatform.new(), "")
	var panel: Control = scene.get_node("OptionsPanel") as Control
	var button: Button = panel.get("credits_button") as Button
	var credits: Control = panel.get("credits_panel") as Control
	_check(button != null and credits != null, "hay un botón de Créditos y su cartel")
	if button == null or credits == null:
		await _free(scene)
		return
	_check(not credits.visible, "empieza cerrado")
	button.pressed.emit()
	await process_frame
	await process_frame
	_check(credits.visible, "el botón lo abre")
	var text: String = ""
	for node: Node in credits.find_children("*", "Label", true, false):
		text += (node as Label).text + "\n"
	for piece: String in ["Godot Engine", "Permission is hereby granted", "SIL OPEN FONT LICENSE", "pixelsphere.org", "mutkanto", "Juhani Junkala", "Kenney", "FreeType", "VT323"]:
		_check(text.contains(piece), "menciona %s" % piece)
	var close: Button = credits.get("close_button") as Button
	var rect: Rect2 = close.get_global_rect()
	_check(rect.size.y >= TOUCH_MIN - 0.5 and rect.end.y <= PHONE_SIZES[0].y and rect.position.x >= 0.0 and rect.end.x <= DESIGN_WIDTH + 0.5, "su Cerrar entra en la pantalla (%s)" % str(rect))
	var scroll: ScrollContainer = credits.find_children("*", "ScrollContainer", true, false)[0] as ScrollContainer
	_check(scroll.get_v_scroll_bar().max_value > scroll.size.y, "el texto largo se desliza")
	_check(scroll.get_h_scroll_bar().visible == false, "sin deslizar de costado")
	close.pressed.emit()
	await process_frame
	_check(not credits.visible and panel.visible, "cerrar vuelve a Opciones")
	button.pressed.emit()
	(panel.get("close_button") as Button).pressed.emit()
	(_node(scene, "OptionsButton") as Button).pressed.emit()
	await process_frame
	_check(not credits.visible, "al reabrir Opciones no quedan abiertos")
	await _free(scene)


func _test_options_layout(packed: PackedScene) -> void:
	_section("Opciones en un celular")
	for phone: Vector2 in PHONE_SIZES:
		var scene: Control = await _mount(packed, phone)
		var label: String = "%dx%d" % [int(phone.x), int(phone.y)]
		var panel: Control = scene.get_node("OptionsPanel") as Control
		# Con todo lo opcional a la vista: es el caso más alto.
		panel.set("platform", FakePlatform.new())
		panel.set("feedback_url", LINK)
		(_node(scene, "OptionsButton") as Button).pressed.emit()
		await process_frame
		await process_frame
		for shown: String in ["fullscreen_button", "feedback_button", "credits_button"]:
			var button: Button = panel.get(shown) as Button
			_check(button != null and button.is_visible_in_tree() and button.get_global_rect().end.y <= phone.y, "[%s] %s se ve entero" % [label, shown])
		var small: Array[String] = []
		for node: Node in panel.find_children("*", "Control", true, false):
			if (node is BaseButton or node is Slider) and (node as Control).is_visible_in_tree():
				if (node as Control).size.y < TOUCH_MIN - 0.5:
					small.append("%s (%d)" % [node.name, int((node as Control).size.y)])
		_check(small.is_empty(), "[%s] todo lo que se toca mide al menos %d px de alto (%s)" % [label, int(TOUCH_MIN), str(small)])
		var box: Control = panel.find_children("*", "PanelContainer", true, false)[0] as Control
		var rect: Rect2 = box.get_global_rect()
		_check(rect.position.x >= 0.0 and rect.end.x <= DESIGN_WIDTH + 0.5 and rect.end.y <= phone.y, "[%s] el panel entra en la pantalla (%s)" % [label, str(rect)])
		var cut: Array[String] = []
		for node: Node in panel.find_children("*", "Label", true, false):
			var text_label: Label = node as Label
			if text_label.autowrap_mode != TextServer.AUTOWRAP_OFF:
				continue
			var width: float = text_label.get_theme_font("font").get_string_size(text_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_label.get_theme_font_size("font_size")).x
			if width > text_label.size.x + 0.5:
				cut.append(text_label.text)
		_check(cut.is_empty(), "[%s] ningún texto se corta (%s)" % [label, str(cut)])
		await _free(scene)
