extends Control
## Cartel modal: oscurece la pantalla y pide confirmar (dos botones) o solo avisa (uno).
##
## Visual provisorio de F1 (panel + texto + botones); el arte llega en F2.
## Se arma por código y empieza cerrado. No sabe qué se confirma: quien lo abre le pasa
## el texto y la acción. Mientras está abierto traga los toques, así nada de abajo responde.

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
	panel.custom_minimum_size = Vector2(600, 0)
	center.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	margin.add_child(box)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 38)
	title_label.add_theme_color_override("font_color", Color(0.96, 0.77, 0.26))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.custom_minimum_size = Vector2(552, 0)
	box.add_child(title_label)

	body_label = Label.new()
	body_label.add_theme_font_size_override("font_size", 28)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.custom_minimum_size = Vector2(552, 0)
	box.add_child(body_label)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)

	cancel_button = _make_button()
	cancel_button.pressed.connect(close)
	buttons.add_child(cancel_button)

	confirm_button = _make_button()
	confirm_button.pressed.connect(_on_confirm_pressed)
	buttons.add_child(confirm_button)


## Abre el cartel. Con `cancel_text` vacío es solo un aviso (un único botón).
## `on_confirm` se llama al apretar el botón de confirmar, ya con el cartel cerrado.
func open(title: String, body: String, confirm_text: String, cancel_text: String = "", on_confirm: Callable = Callable()) -> void:
	title_label.text = title
	body_label.text = body
	confirm_button.text = confirm_text
	cancel_button.text = cancel_text
	cancel_button.visible = cancel_text != ""
	_on_confirm = on_confirm
	visible = true


func close() -> void:
	visible = false


func _on_confirm_pressed() -> void:
	close()
	if _on_confirm.is_valid():
		_on_confirm.call()


func _make_button() -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(0, 88)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 28)
	return button
