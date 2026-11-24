extends Control
## Panel de debug: atajos para probar biomas, prestigio y botín sin jugar horas.
##
## SOLO EXISTE EN BUILDS DE DEBUG: main.gd lo crea con attach_if_debug(OS.is_debug_build()),
## que no hace nada en un export de release (el default de tools/export_web.ps1). Con
## `-DebugBuild` sí aparece. Arranca cerrado: solo se ve el botón DBG arriba a la izquierda.
## Visual provisorio; no es parte del juego.

const NumberFormat := preload("res://core/number_format.gd")

## "Oro": multiplica por este factor el oro que tenés (desde 0 deja 1.000).
const GOLD_FACTOR: float = 1000.0
## "Adelantar": cuánto tiempo (s) pasa de golpe, con el mismo cálculo que el progreso offline.
const ADVANCE_SECONDS: float = 3600.0
## Tope para no llegar a infinito apretando "Oro" muchas veces.
const MAX_DEBUG_GOLD: float = 1.0e100

var toggle_button: Button
var body: PanelContainer
var gold_button: Button
var time_button: Button
## Un botón por rareza del botín (en el orden de Economy.loot_table()); vacío si no hay botín.
var chest_buttons: Array[Button] = []


## Crea el panel como hijo de `parent` si `is_debug`; si no, no hace nada y devuelve null.
## `is_debug` es OS.is_debug_build() (se pasa por parámetro para poder probar el caso release).
static func attach_if_debug(parent: Node, is_debug: bool) -> Control:
	if not is_debug:
		return null
	var panel: Control = new()
	parent.add_child(panel)
	return panel


func _init() -> void:
	name = "DebugPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	toggle_button = _make_button("DBG", 22)
	toggle_button.position = Vector2(8, 8)
	toggle_button.custom_minimum_size = Vector2(96, 56)
	toggle_button.pressed.connect(_on_toggle_pressed)
	add_child(toggle_button)

	body = PanelContainer.new()
	body.position = Vector2(8, 72)
	body.custom_minimum_size = Vector2(460, 0)
	body.visible = false
	add_child(body)

	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	body.add_child(margin)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var title: Label = Label.new()
	title.text = "Debug (solo builds de debug)"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	box.add_child(title)

	gold_button = _make_button("Oro ×%d" % int(GOLD_FACTOR), 26)
	gold_button.pressed.connect(_on_gold_pressed)
	box.add_child(gold_button)

	time_button = _make_button("Adelantar %s" % NumberFormat.format_duration(ADVANCE_SECONDS), 26)
	time_button.pressed.connect(_on_time_pressed)
	box.add_child(time_button)

	var table: Array[Dictionary] = Economy.loot_table()
	if not table.is_empty():
		var chests_title: Label = Label.new()
		chests_title.text = "Forzar cofre:"
		chests_title.add_theme_font_size_override("font_size", 22)
		box.add_child(chests_title)
		var grid: GridContainer = GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		box.add_child(grid)
		for index: int in range(table.size()):
			var button: Button = _make_button("%s +%s" % [table[index]["name"], NumberFormat.format_percent(table[index]["bonus"])], 24)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.pressed.connect(_on_chest_pressed.bind(index))
			grid.add_child(button)
			chest_buttons.append(button)


func _on_toggle_pressed() -> void:
	body.visible = not body.visible


func _on_gold_pressed() -> void:
	var target: float = minf(maxf(Economy.gold, 1.0) * GOLD_FACTOR, MAX_DEBUG_GOLD)
	Economy.grant_gold(target - Economy.gold)


func _on_time_pressed() -> void:
	Economy.apply_offline(ADVANCE_SECONDS)


func _on_chest_pressed(rarity: int) -> void:
	Economy.drop_loot(rarity)


func _make_button(text: String, font_size: int) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 64)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", font_size)
	return button
