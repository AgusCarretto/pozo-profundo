extends Control
## Panel de Opciones: volumen de música y de SFX, y "reducir efectos". Lo abre el engranaje del HUD.
##
## Se arma por código (como el cartel modal) y empieza cerrado. Lee y escribe el autoload Settings, que lo
## guarda; no guarda nada propio. Mientras está abierto oscurece la pantalla y traga los toques. Va entre
## los hijos de la escena después del panel de debug y antes del cartel modal: queda encima del juego y
## debajo de un aviso.

## Se abrió o se cerró (solo cuando cambia: abrirlo ya abierto no avisa).
signal opened
signal closed

const PANEL_WIDTH: float = 620.0
## Alto de todo lo que se toca (96 px de diseño = 48 px en un celular de 360 px de ancho).
const TOUCH_HEIGHT: float = 96.0

var music_slider: HSlider
var sfx_slider: HSlider
var reduce_check: CheckButton
var close_button: Button

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

	close_button = Button.new()
	close_button.theme_type_variation = &"ButtonNeutral"
	close_button.text = "Cerrar"
	close_button.custom_minimum_size = Vector2(0, TOUCH_HEIGHT)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close)
	box.add_child(close_button)


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
	Audio.play_sfx("close")
	visible = false
	closed.emit()


## Pone los controles como está Settings, sin disparar sus señales (no se vuelve a escribir lo mismo).
func _sync() -> void:
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
