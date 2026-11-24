extends PanelContainer
## Fila de un generador: nombre y cantidad, producción y botón de compra.
##
## Visual provisorio de F1 (panel + texto + botón); el arte llega en F2.
## Se arma por código y se actualiza con refresh().

const NumberFormat := preload("res://core/number_format.gd")

var index: int = 0

## Modo de compra con el que se dibujó la fila; es el que usa el botón al apretarse.
var _mode: int = Economy.BuyMode.X1
var _name_label: Label
var _detail_label: Label
var _buy_button: Button


func setup(generator_index: int) -> void:
	index = generator_index
	custom_minimum_size = Vector2(0, 124)

	var box: HBoxContainer = HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)

	var texts: VBoxContainer = VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(texts)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 32)
	texts.add_child(_name_label)

	_detail_label = Label.new()
	_detail_label.add_theme_font_size_override("font_size", 24)
	_detail_label.add_theme_color_override("font_color", Color(0.7, 0.64, 0.58))
	texts.add_child(_detail_label)

	_buy_button = Button.new()
	_buy_button.custom_minimum_size = Vector2(240, 0)
	_buy_button.focus_mode = Control.FOCUS_NONE
	_buy_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	_buy_button.add_theme_font_size_override("font_size", 26)
	_buy_button.pressed.connect(_on_buy_pressed)
	box.add_child(_buy_button)

	refresh(_mode)


## Actualiza los textos y el estado del botón según el estado de Economy y el modo de compra.
func refresh(mode: int) -> void:
	_mode = mode
	_name_label.text = "%s  ×%d" % [Economy.generator_name(index), Economy.owned_count(index)]
	_detail_label.text = "Produce %s/s" % NumberFormat.format_number(Economy.generator_output(index))
	var offer: Dictionary = Economy.quote(index, mode)
	_buy_button.text = "Comprar ×%d\n%s" % [offer["count"], NumberFormat.format_cost(offer["cost"])]
	_buy_button.disabled = not offer["affordable"]


func _on_buy_pressed() -> void:
	Economy.buy_generator(index, _mode)
