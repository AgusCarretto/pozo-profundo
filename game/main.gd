extends Control
## Escena principal de F1: roca, oro, modo de compra, mejora del pico y lista de generadores.
##
## Visuales provisorios (rectángulos y texto); el arte y el "jugo" llegan en F2.
## Toda la lógica está en el autoload Economy: acá solo se conecta la UI.

const GeneratorRow := preload("res://game/generator_row.gd")
const NumberFormat := preload("res://core/number_format.gd")

var _mode: int = Economy.BuyMode.X1
var _rows: Array[GeneratorRow] = []
## Se marca cuando Economy cambia; la pantalla se refresca una vez por frame, no por señal.
var _dirty: bool = true

@onready var _gold_label: Label = %GoldLabel
@onready var _rate_label: Label = %RateLabel
@onready var _tap_button: Button = %TapButton
@onready var _pick_button: Button = %PickButton
@onready var _generator_list: VBoxContainer = %GeneratorList


func _ready() -> void:
	for index: int in range(Economy.generator_count()):
		var row: GeneratorRow = GeneratorRow.new()
		_generator_list.add_child(row)
		row.setup(index)
		_rows.append(row)

	var group: ButtonGroup = ButtonGroup.new()
	var mode_buttons: Dictionary = {
		Economy.BuyMode.X1: %Mode1Button,
		Economy.BuyMode.X10: %Mode10Button,
		Economy.BuyMode.MAX: %ModeMaxButton,
	}
	for mode: int in mode_buttons:
		var button: Button = mode_buttons[mode]
		button.button_group = group
		button.toggled.connect(_on_mode_toggled.bind(mode))
	(%Mode1Button as Button).button_pressed = true

	# Reaccionan al apretar (no al soltar): un clicker tiene que responder al toque.
	_tap_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	_pick_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	_tap_button.button_down.connect(_on_tap)
	_pick_button.pressed.connect(_on_pick_pressed)

	Economy.gold_changed.connect(_mark_dirty.unbind(1))
	Economy.generator_bought.connect(_mark_dirty.unbind(2))
	Economy.pick_upgraded.connect(_mark_dirty.unbind(1))
	_refresh()


func _process(_delta: float) -> void:
	if _dirty:
		_refresh()


func _mark_dirty() -> void:
	_dirty = true


func _on_tap() -> void:
	Economy.hit()


func _on_pick_pressed() -> void:
	Economy.upgrade_pick()


func _on_mode_toggled(pressed: bool, mode: int) -> void:
	if pressed:
		_mode = mode
		_mark_dirty()


func _refresh() -> void:
	_dirty = false
	_gold_label.text = NumberFormat.format_number(Economy.gold)
	_rate_label.text = "Golpe %s · %s oro/s" % [
		NumberFormat.format_number(Economy.hit_value()),
		NumberFormat.format_number(Economy.gold_per_second()),
	]
	var cost: float = Economy.pick_cost()
	_pick_button.text = "Mejorar pico (nivel %d)\nCosto: %s" % [Economy.pick_level, NumberFormat.format_cost(cost)]
	_pick_button.disabled = cost > Economy.gold
	for row: GeneratorRow in _rows:
		row.refresh(_mode)
