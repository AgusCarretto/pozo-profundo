extends Control
## Panel de Opciones: volumen de música y de SFX, "reducir efectos", pantalla completa (si el navegador la
## permite), "Opinar" (si data/online.json trae el link), Créditos y la versión. Lo abre el engranaje del HUD.
##
## Se arma por código (como el cartel modal) y empieza cerrado. Lee y escribe el autoload Settings, que lo
## guarda; no guarda nada propio. Mientras está abierto oscurece la pantalla y traga los toques. Va entre
## los hijos de la escena después del panel de debug y antes del cartel modal: queda encima del juego y
## debajo de un aviso.

## Se abrió o se cerró (solo cuando cambia: abrirlo ya abierto no avisa).
signal opened
signal closed

const CreditsPanel := preload("res://game/credits_panel.gd")
const OnlineConfig := preload("res://core/online_config.gd")
const WebPlatform := preload("res://core/web_platform.gd")

const PANEL_WIDTH: float = 620.0
## Alto de todo lo que se toca (96 px de diseño = 48 px en un celular de 360 px de ancho).
const TOUCH_HEIGHT: float = 96.0

var music_slider: HSlider
var sfx_slider: HSlider
var reduce_check: CheckButton
var close_button: Button
var fullscreen_button: Button
var feedback_button: Button
var credits_button: Button
var version_label: Label
var credits_panel: CreditsPanel
## Pantalla completa y links; los tests lo reemplazan antes de abrir.
var platform: WebPlatform = WebPlatform.new()
## Lo que abre "Opinar" ("" = no hay botón).
var feedback_url: String = ""

var _music_value: Label
var _sfx_value: Label


func _init() -> void:
	name = "OptionsPanel"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	panel.theme_type_variation = &"ModalPanel"
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	center.add_child(panel)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)

	var title: Label = Label.new()
	title.theme_type_variation = &"TitleLabel"
	title.text = "Opciones"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	music_slider = _volume_row(box, "Música")
	_music_value = music_slider.get_meta("value_label") as Label
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider = _volume_row(box, "Efectos de sonido")
	_sfx_value = sfx_slider.get_meta("value_label") as Label
	sfx_slider.value_changed.connect(_on_sfx_changed)
	# Al soltar el volumen de los efectos suena un golpe de muestra, ya con el volumen nuevo.
	sfx_slider.drag_ended.connect(func(_changed: bool) -> void: Audio.play_sfx("hit"))

	reduce_check = CheckButton.new()
	reduce_check.text = "Reducir efectos"
	reduce_check.custom_minimum_size = Vector2(0, TOUCH_HEIGHT)
	reduce_check.focus_mode = Control.FOCUS_NONE
	reduce_check.toggled.connect(_on_reduce_toggled)
	box.add_child(reduce_check)

	var hint: Label = Label.new()
	hint.theme_type_variation = &"MutedLabel"
	hint.text = "Sin sacudidas, destellos ni vibración, y con menos partículas."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)

	fullscreen_button = _button(box, "Pantalla completa")
	fullscreen_button.pressed.connect(_on_fullscreen_pressed)
	var extras: HBoxContainer = HBoxContainer.new()
	extras.add_theme_constant_override("separation", 16)
	box.add_child(extras)
	feedback_button = _button(extras, "Opinar")
	feedback_button.pressed.connect(func() -> void: platform.open_url(feedback_url))
	credits_button = _button(extras, "Créditos")

	close_button = _button(box, "Cerrar")
	close_button.pressed.connect(close)

	version_label = Label.new()
	version_label.theme_type_variation = &"MutedLabel"
	version_label.text = "Versión %s" % ProjectSettings.get_setting("application/config/version", "")
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(version_label)

	# Último: se dibuja encima de las Opciones y al cerrarlo se vuelve a ellas.
	credits_panel = CreditsPanel.new()
	add_child(credits_panel)
	credits_button.pressed.connect(credits_panel.open)
	feedback_url = OnlineConfig.load_file()["feedback_url"]


## Abre el panel mostrando lo que hay ahora en Settings.
func open() -> void:
	_sync()
	if visible:
		return
	Audio.play_sfx("open")
	visible = true
	opened.emit()


func close() -> void:
	if not visible:
		return
	credits_panel.visible = false
	Audio.play_sfx("close")
	visible = false
	closed.emit()


## La pantalla completa también se cambia por fuera (el gesto de atrás del celular): el texto la sigue.
func _process(_delta: float) -> void:
	if visible:
		_show_fullscreen_state()


func _on_fullscreen_pressed() -> void:
	platform.set_fullscreen(not platform.is_fullscreen())
	Audio.play_sfx("toggle")


func _show_fullscreen_state() -> void:
	if fullscreen_button.visible:
		fullscreen_button.text = "Salir de pantalla completa" if platform.is_fullscreen() else "Pantalla completa"


func _button(parent: Container, text: String) -> Button:
	var button: Button = Button.new()
	button.theme_type_variation = &"ButtonNeutral"
	button.text = text
	button.custom_minimum_size = Vector2(0, TOUCH_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	parent.add_child(button)
	return button


## Pone los controles como está Settings, sin disparar sus señales (no se vuelve a escribir lo mismo).
func _sync() -> void:
	fullscreen_button.visible = platform.can_fullscreen()
	feedback_button.visible = feedback_url != ""
	_show_fullscreen_state()
	music_slider.set_value_no_signal(Settings.music_volume)
	sfx_slider.set_value_no_signal(Settings.sfx_volume)
	reduce_check.set_pressed_no_signal(Settings.reduce_effects)
	_show_percent(_music_value, Settings.music_volume)
	_show_percent(_sfx_value, Settings.sfx_volume)


func _on_music_changed(value: float) -> void:
	Settings.music_volume = value
	_show_percent(_music_value, value)


func _on_sfx_changed(value: float) -> void:
	Settings.sfx_volume = value
	_show_percent(_sfx_value, value)


func _on_reduce_toggled(pressed: bool) -> void:
	Settings.reduce_effects = pressed
	Audio.play_sfx("toggle")


func _show_percent(label: Label, value: float) -> void:
	label.text = "%d%%" % roundi(value * 100.0)


## Una fila "Nombre ........ 70%" y debajo el slider de 0 a 1 (con el % guardado en su meta "value_label").
func _volume_row(box: VBoxContainer, caption: String) -> HSlider:
	var row: HBoxContainer = HBoxContainer.new()
	box.add_child(row)
	var name_label: Label = Label.new()
	name_label.text = caption
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var value_label: Label = Label.new()
	value_label.theme_type_variation = &"AccentLabel"
	value_label.text = "100%"
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size = Vector2(90, 0)
	row.add_child(value_label)
	var slider: HSlider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(0, TOUCH_HEIGHT)
	slider.focus_mode = Control.FOCUS_NONE
	slider.set_meta("value_label", value_label)
	box.add_child(slider)
	return slider
