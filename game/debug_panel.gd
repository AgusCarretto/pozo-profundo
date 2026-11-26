extends Control
## Panel de debug: atajos para probar biomas, prestigio y botín sin jugar horas.
##
## Con árbol de reliquias suma sus atajos: reliquias, fragmentos, abrir anillos, horas de AFK y borrar todo (la build de
## prueba publicada en /test/ es de debug y tiene su propia partida).
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
## El botón DBG va justo debajo del HUD, a la izquierda de la mina: no tapa el oro ni el multiplicador.
## Se acomoda solo según el alto del HUD (_follow_hud); esta es la posición si no hay HUD.
const TOGGLE_POSITION: Vector2 = Vector2(8.0, 300.0)
const HUD_GAP: float = 8.0
## Alto de los botones (px de diseño): 96 = 48 px en un celular de 360 px de ancho, igual que el juego.
const BUTTON_HEIGHT: float = 96.0
const GRANT_RELICS: int = 100
const GRANT_FRAGMENTS: int = 100
## Horas de AFK que se pueden simular de un toque.
const AFK_HOURS: Array[int] = [1, 8, 23]

var toggle_button: Button
var body: PanelContainer
var gold_button: Button
var time_button: Button
## Un botón por rareza del botín (en el orden de Economy.loot_table()); vacío si no hay botín.
var chest_buttons: Array[Button] = []
var wipe_button: Button


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
	toggle_button.position = TOGGLE_POSITION
	toggle_button.custom_minimum_size = Vector2(110, BUTTON_HEIGHT)
	toggle_button.pressed.connect(_on_toggle_pressed)
	add_child(toggle_button)

	body = PanelContainer.new()
	body.position = TOGGLE_POSITION + Vector2(0, BUTTON_HEIGHT + HUD_GAP)
	body.custom_minimum_size = Vector2(460, 0)
	body.visible = false
	add_child(body)
	_follow_hud()

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

	# Todo en dos columnas: así entra en la pantalla de un celular.
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)

	gold_button = _grid_button(grid, "DebugGold", "Oro ×%d" % int(GOLD_FACTOR), _on_gold_pressed)
	time_button = _grid_button(grid, "DebugAdvance", "Adelantar %s" % NumberFormat.format_duration(ADVANCE_SECONDS), _on_time_pressed)

	if Economy.has_tree():
		_grid_button(grid, "DebugRelics", "+%d reliquias" % GRANT_RELICS, func() -> void: Economy.grant_relics(GRANT_RELICS))
		_grid_button(grid, "DebugFragments", "+%d fragmentos" % GRANT_FRAGMENTS, func() -> void: Economy.add_fragments(GRANT_FRAGMENTS))
		_grid_button(grid, "DebugRings", "Abrir anillos", Economy.open_rings)
		wipe_button = _grid_button(grid, "DebugWipe", "Borrar todo", _on_wipe_pressed)
		for hours: int in AFK_HOURS:
			_grid_button(grid, "DebugAfk%d" % hours, "AFK %d h" % hours, _on_afk_pressed.bind(hours))

	var table: Array[Dictionary] = Economy.loot_table()
	for index: int in range(table.size()):
		chest_buttons.append(_grid_button(grid, "DebugChest%d" % index, str(table[index]["name"]), _on_chest_pressed.bind(index)))


func _grid_button(grid: GridContainer, node_name: String, text: String, action: Callable) -> Button:
	var button: Button = _make_button(text, 24)
	button.name = node_name
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	grid.add_child(button)
	return button


## Borrar todo pide un segundo toque.
func _on_wipe_pressed() -> void:
	if wipe_button.text == "Borrar todo":
		wipe_button.text = "¿Seguro? Tocá otra vez"
		return
	wipe_button.text = "Borrar todo"
	Economy.reset()
	Save.save_now()


## Como volver después de `hours` horas fuera: la dinamita recarga y la cuadrilla junta lo del AFK, con su aviso.
func _on_afk_pressed(hours: int) -> void:
	Economy.advance_ability(hours * 3600.0)
	Economy.apply_offline(hours * 3600.0)


## Se queda debajo del HUD de la escena (`%HudPanel` del padre), aunque cambie de alto.
func _follow_hud() -> void:
	var hud: Control = get_parent().get_node_or_null("%HudPanel") as Control
	if hud == null:
		return
	hud.resized.connect(_place_below.bind(hud))
	_place_below.call_deferred(hud)


func _place_below(hud: Control) -> void:
	var top: float = hud.get_global_rect().end.y + HUD_GAP
	toggle_button.position.y = top
	body.position.y = top + BUTTON_HEIGHT + HUD_GAP


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
	button.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", font_size)
	return button
