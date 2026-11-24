extends Control
## Escena principal de F1: roca, oro, profundidad, botín, modo de compra, mejora del pico,
## reliquias (prestigio) y lista de generadores.
##
## Visuales provisorios (rectángulos y texto); el arte y el "jugo" llegan en F2.
## Toda la lógica está en el autoload Economy: acá solo se conecta la UI.

const GeneratorRow := preload("res://game/generator_row.gd")
const Modal := preload("res://game/modal.gd")
const NumberFormat := preload("res://core/number_format.gd")

## Color de cada rareza de cofre, por id del balance. Es presentación, no balance.
const RARITY_COLORS: Dictionary = {
	"common": Color(0.78, 0.78, 0.8),
	"rare": Color(0.35, 0.65, 1.0),
	"epic": Color(0.75, 0.45, 1.0),
	"legendary": Color(1.0, 0.72, 0.2),
}
const DEFAULT_RARITY_COLOR: Color = Color(0.9, 0.9, 0.9)

var _mode: int = Economy.BuyMode.X1
var _rows: Array[GeneratorRow] = []
## Se marca cuando Economy cambia; la pantalla se refresca una vez por frame, no por señal.
var _dirty: bool = true
var _modal: Modal

@onready var _gold_label: Label = %GoldLabel
@onready var _rate_label: Label = %RateLabel
@onready var _depth_label: Label = %DepthLabel
@onready var _tap_button: Button = %TapButton
@onready var _loot_box: VBoxContainer = %LootBox
@onready var _loot_info_label: Label = %LootInfoLabel
@onready var _odds_row: HBoxContainer = %OddsRow
@onready var _last_loot_label: Label = %LastLootLabel
@onready var _pick_button: Button = %PickButton
@onready var _relics_label: Label = %RelicsLabel
@onready var _prestige_button: Button = %PrestigeButton
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
	_prestige_button.pressed.connect(_on_prestige_pressed)

	_build_loot_panel()

	# El cartel va último entre los hijos: se dibuja encima de todo.
	_modal = Modal.new()
	add_child(_modal)

	Economy.gold_changed.connect(_mark_dirty.unbind(1))
	Economy.generator_bought.connect(_mark_dirty.unbind(2))
	Economy.pick_upgraded.connect(_mark_dirty.unbind(1))
	Economy.prestiged.connect(_mark_dirty.unbind(1))
	Economy.loot_dropped.connect(_on_loot_dropped)
	Economy.offline_progress.connect(_show_offline_notice)
	_refresh()

	# Si el juego arrancó con progreso offline, Economy ya lo acreditó antes de que existiera esta escena.
	if not Economy.pending_offline_report.is_empty():
		_show_offline_notice(Economy.pending_offline_report)


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
	_refresh_depth()
	var cost: float = Economy.pick_cost()
	_pick_button.text = "Mejorar pico (nivel %d)\nCosto: %s" % [Economy.pick_level, NumberFormat.format_cost(cost)]
	_pick_button.disabled = cost > Economy.gold
	_refresh_prestige()
	for row: GeneratorRow in _rows:
		row.refresh(_mode)


func _refresh_depth() -> void:
	var text: String = "Profundidad %d m" % int(floorf(Economy.depth()))
	if Economy.biome_count() > 0:
		text += " · %s ×%.2f" % [Economy.biome_name(Economy.biome_index()), Economy.biome_multiplier()]
	_depth_label.text = text


# --- Botín -------------------------------------------------------------------

## Muestra las probabilidades reales del botín (las mismas que usa Economy para sortear).
func _build_loot_panel() -> void:
	var table: Array[Dictionary] = Economy.loot_table()
	_loot_box.visible = not table.is_empty()
	if table.is_empty():
		return
	_loot_info_label.text = "Cofres: %s por golpe · %s por segundo con cuadrilla" % [
		NumberFormat.format_percent(Economy.loot_chance_per_hit()),
		NumberFormat.format_percent(Economy.loot_chance_per_second()),
	]
	_last_loot_label.text = "Todavía no salió ningún cofre"
	for rarity: Dictionary in table:
		var label: Label = Label.new()
		label.text = "%s\n%s (+%s)" % [rarity["name"], NumberFormat.format_percent(rarity["chance"]), NumberFormat.format_percent(rarity["bonus"])]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 22)
		label.add_theme_color_override("font_color", _rarity_color(rarity["id"]))
		_odds_row.add_child(label)


func _on_loot_dropped(rarity: int, amount: float) -> void:
	var table: Array[Dictionary] = Economy.loot_table()
	if rarity < 0 or rarity >= table.size():
		return
	var entry: Dictionary = table[rarity]
	_last_loot_label.text = "¡Cofre %s! +%s de oro" % [entry["name"], NumberFormat.format_number(amount)]
	_last_loot_label.add_theme_color_override("font_color", _rarity_color(entry["id"]))


func _rarity_color(id: String) -> Color:
	return RARITY_COLORS.get(id, DEFAULT_RARITY_COLOR)


# --- Reliquias y prestigio ---------------------------------------------------

func _refresh_prestige() -> void:
	var relics_text: String = "Reliquias: %d" % Economy.relics
	if Economy.relics > 0:
		relics_text += " · +%s de oro" % NumberFormat.format_percent(Economy.relics * Economy.relic_bonus())
	_relics_label.text = relics_text
	if Economy.can_prestige():
		var gain: int = Economy.prestige_relics()
		_prestige_button.text = "Volver a la superficie\n+%s (+%s de oro)" % [_relics_phrase(gain), NumberFormat.format_percent(gain * Economy.relic_bonus())]
		_prestige_button.disabled = false
	else:
		_prestige_button.text = "Volver a la superficie\nDisponible desde los %s m" % NumberFormat.format_number(Economy.prestige_min_depth())
		_prestige_button.disabled = true


func _relics_phrase(count: int) -> String:
	return "1 reliquia" if count == 1 else "%d reliquias" % count


## Pide confirmación antes de volver a la superficie: se pierde casi toda la partida.
func _on_prestige_pressed() -> void:
	if not Economy.can_prestige():
		return
	var gain: int = Economy.prestige_relics()
	var body: String = "Estás a %d m (%s).\n\nGanás %s: +%s de oro permanente (en total ×%.2f).\n\nVolvés a la superficie sin oro, sin cuadrilla y con el pico en nivel 0. Las reliquias te quedan para siempre." % [
		int(floorf(Economy.depth())),
		Economy.biome_name(Economy.biome_index()),
		_relics_phrase(gain),
		NumberFormat.format_percent(gain * Economy.relic_bonus()),
		Economy.relic_multiplier_for(Economy.relics + gain),
	]
	_modal.open("¿Volver a la superficie?", body, "Sí, volver", "Seguir cavando", _confirm_prestige)


func _confirm_prestige() -> void:
	Economy.prestige()


# --- Progreso offline --------------------------------------------------------

func _show_offline_notice(report: Dictionary) -> void:
	var gold_text: String = NumberFormat.format_number(report["gold"])
	var body: String
	if report["capped"]:
		body = "Estuviste fuera mucho tiempo. Tu cuadrilla trabajó el máximo de %s y juntó %s de oro." % [
			NumberFormat.format_duration(Economy.offline_max_seconds()), gold_text]
	else:
		body = "Estuviste fuera %s. Tu cuadrilla siguió minando y juntó %s de oro." % [
			NumberFormat.format_duration(report["seconds"]), gold_text]
	_modal.open("¡Bienvenido de vuelta!", body, "¡A seguir!", "", Economy.dismiss_offline_report)
