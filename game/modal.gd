extends Control
## Cartel modal: oscurece la pantalla y pide confirmar (dos botones) o solo avisa (uno).
##
## Se arma por código y empieza cerrado. No sabe qué se confirma: quien lo abre le pasa
## el texto y la acción. Mientras está abierto traga los toques, así nada de abajo responde.
## Los estilos salen del tema (ui/theme.tres): panel, etiquetas y botones de 96 px de alto.

## Ancho del cartel y alto mínimo de sus botones (px de diseño).
const PANEL_WIDTH: float = 620.0
const BUTTON_HEIGHT: float = 96.0
const DEFAULT_CONFIRM_STYLE: StringName = &"ButtonNeutral"

var title_label: Label
var body_label: Label
var confirm_button: Button
var cancel_button: Button

var _on_confirm: Callable = Callable()


func _init() -> void:
	name = "Modal"
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
	box.add_theme_constant_override("separation", 20)
	panel.add_child(box)

	title_label = Label.new()
	title_label.theme_type_variation = &"TitleLabel"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title_label)

	body_label = Label.new()
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(body_label)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	box.add_child(buttons)

	cancel_button = _make_button(&"ButtonNeutral")
	cancel_button.pressed.connect(close)
	buttons.add_child(cancel_button)

	confirm_button = _make_button(DEFAULT_CONFIRM_STYLE)
	confirm_button.pressed.connect(_on_confirm_pressed)
	buttons.add_child(confirm_button)


## Abre el cartel. Con `cancel_text` vacío es solo un aviso (un único botón).
## `on_confirm` se llama al apretar el botón de confirmar, ya con el cartel cerrado.
## `confirm_style` es la variación de botón del tema para confirmar: neutra por defecto; el rojo es solo
## del prestigio (ver ui/theme.tres).
func open(title: String, body: String, confirm_text: String, cancel_text: String = "", on_confirm: Callable = Callable(),
		confirm_style: StringName = DEFAULT_CONFIRM_STYLE) -> void:
	title_label.text = title
	body_label.text = body
	confirm_button.theme_type_variation = confirm_style
	confirm_button.text = confirm_text
	cancel_button.text = cancel_text
	cancel_button.visible = cancel_text != ""
	_on_confirm = on_confirm
	if not visible:
		Audio.play_sfx("open")
	visible = true


func close() -> void:
	if visible:
		Audio.play_sfx("close")
	visible = false


func _on_confirm_pressed() -> void:
	close()
	if _on_confirm.is_valid():
		_on_confirm.call()


func _make_button(variation: StringName) -> Button:
	var button: Button = Button.new()
	button.theme_type_variation = variation
	button.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	return button
