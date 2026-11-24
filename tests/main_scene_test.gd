extends "res://tests/test_base.gd"
## Tests headless de la escena principal de F1 (game/main.tscn): cableado entre la UI
## provisoria y el autoload Economy. No miden cómo se ve, solo que cada control haga lo suyo.
##
## Usan el autoload Economy real (se reinicia antes de cada test). Save no persiste en
## headless, así que no se toca ninguna partida guardada.

const MAIN_SCENE: String = "res://game/main.tscn"

var _economy: Node
var _scene: Control


func _initialize() -> void:
	_economy = root.get_node_or_null("Economy")
	_check(_economy != null, "existe el autoload Economy")
	_check_eq(ProjectSettings.get_setting("application/run/main_scene"), MAIN_SCENE, "la escena principal del proyecto es " + MAIN_SCENE)
	var packed: PackedScene = load(MAIN_SCENE) as PackedScene
	_check(packed != null, "carga " + MAIN_SCENE)
	if _economy == null or packed == null:
		_finish()
		return

	# En modo --script los autoloads recién corren _ready() después del primer frame, y Economy
	# recarga ahí el balance real: hay que esperar ese frame antes de cambiárselo.
	await process_frame
	# El botín es azar: cualquier cofre movería el oro que estos tests cuentan golpe a golpe.
	_check(_economy.load_balance(_balance_without_loot()), "carga el balance real sin botín (%s)" % _economy.last_error)
	_check_eq(_economy.loot_table().size(), 0, "el botín quedó apagado (el azar no mueve el oro)")
	_scene = packed.instantiate() as Control
	root.add_child(_scene)
	await process_frame

	await _test_initial_screen()
	await _test_tap_hits_the_rock()
	await _test_buying_a_generator()
	await _test_buy_modes()
	await _test_pick_upgrade()
	await _test_large_numbers_use_suffixes()
	_scene.queue_free()
	await process_frame
	_economy.reset()
	_finish()


## El balance real de data/ sin la sección "loot".
func _balance_without_loot() -> Dictionary:
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance.json"))
	balance.erase("loot")
	return balance


func _button(node_name: String) -> Button:
	return _scene.get_node("%" + node_name) as Button


func _label(node_name: String) -> Label:
	return _scene.get_node("%" + node_name) as Label


func _rows() -> Array[Node]:
	return _scene.get_node("%GeneratorList").get_children()


func _row_button(index: int) -> Button:
	return _rows()[index].find_children("*", "Button", true, false)[0] as Button


## Deja el estado de Economy en `gold` (resto en cero) y espera a que la UI se refresque.
func _set_gold(gold: float) -> void:
	_economy.reset()
	_economy.gold = gold
	await process_frame


func _test_initial_screen() -> void:
	_section("Pantalla inicial")
	_check_eq(_label("GoldLabel").text, "0", "el oro arranca en 0")
	_check_eq(_rows().size(), 5, "hay una fila por generador (5)")
	_check_eq(_rows().size(), _economy.generator_count(), "una fila por generador del balance")
	var any_enabled: bool = false
	for i: int in range(_rows().size()):
		if not _row_button(i).disabled:
			any_enabled = true
	_check(not any_enabled, "sin oro, ningún botón de compra está habilitado")
	_check(_button("PickButton").disabled, "sin oro, el botón del pico está deshabilitado")
	_check_eq(_button("Mode1Button").button_pressed, true, "el modo de compra arranca en x1")


func _test_tap_hits_the_rock() -> void:
	_section("Golpe a la roca")
	await _set_gold(0.0)
	_button("TapButton").button_down.emit()
	_check_eq(_economy.gold, 1.0, "tocar la roca suma el golpe a Economy")
	await process_frame
	_check_eq(_label("GoldLabel").text, "1", "el cartel de oro se actualiza a 1")
	for i: int in range(9):
		_button("TapButton").button_down.emit()
	await process_frame
	_check_eq(_label("GoldLabel").text, "10", "10 golpes -> 10 de oro")


func _test_buying_a_generator() -> void:
	_section("Compra de un generador")
	await _set_gold(14.0)
	_check(_row_button(0).disabled, "con 14 no se puede comprar el Minero (cuesta 15)")
	await _set_gold(15.0)
	_check(not _row_button(0).disabled, "con 15 el botón del Minero se habilita")
	_check(_row_button(0).text.contains("15"), "el botón muestra el costo (%s)" % _row_button(0).text.replace("\n", " | "))
	_row_button(0).pressed.emit()
	_check_eq(_economy.owned_count(0), 1, "apretar el botón compra 1 Minero")
	_check_eq(_economy.gold, 0.0, "y gasta 15")
	await process_frame
	_check_eq(_label("GoldLabel").text, "0", "el oro en pantalla baja a 0")
	_check(_rows()[0].find_children("*", "Label", true, false).any(func(l: Label) -> bool: return l.text.contains("×1")), "la fila muestra ×1")
	_check(_label("RateLabel").text.contains("1"), "el cartel de producción muestra 1 oro/s (%s)" % _label("RateLabel").text)


func _test_buy_modes() -> void:
	_section("Modos ×1 / ×10 / Máx")
	await _set_gold(10000.0)
	_button("Mode10Button").button_pressed = true
	await process_frame
	_check(_row_button(0).text.contains("×10"), "en modo ×10 el botón dice ×10 (%s)" % _row_button(0).text.replace("\n", " | "))
	_row_button(0).pressed.emit()
	_check_eq(_economy.owned_count(0), 10, "apretar compra 10 de una")
	_button("ModeMaxButton").button_pressed = true
	await process_frame
	var expected: int = _economy.quote(0, 2)["count"]
	_check(expected > 1, "con el oro que queda, Máx permite más de 1 (%d)" % expected)
	_check(_row_button(0).text.contains("×%d" % expected), "en modo Máx el botón dice ×%d (%s)" % [expected, _row_button(0).text.replace("\n", " | ")])
	var before: int = _economy.owned_count(0)
	_row_button(0).pressed.emit()
	_check_eq(_economy.owned_count(0), before + expected, "apretar compra %d" % expected)
	_button("Mode1Button").button_pressed = true
	await process_frame
	_check(_row_button(0).text.contains("×1") and not _row_button(0).text.contains("×1\n×"), "al volver a ×1 el botón vuelve a decir ×1")


func _test_pick_upgrade() -> void:
	_section("Mejora del pico")
	await _set_gold(49.0)
	_check(_button("PickButton").disabled, "con 49 no se puede mejorar (cuesta 50)")
	await _set_gold(50.0)
	_check(not _button("PickButton").disabled, "con 50 se habilita")
	_check(_button("PickButton").text.contains("50"), "muestra el costo (%s)" % _button("PickButton").text.replace("\n", " | "))
	_button("PickButton").pressed.emit()
	_check_eq(_economy.pick_level, 1, "apretar sube el pico a nivel 1")
	await process_frame
	_check(_button("PickButton").text.contains("300"), "ahora muestra el costo del siguiente nivel (300)")
	_button("TapButton").button_down.emit()
	_check_eq(_economy.gold, 2.0, "y un golpe ahora vale 2")


func _test_large_numbers_use_suffixes() -> void:
	_section("Números grandes")
	await _set_gold(1234567.0)
	_check_eq(_label("GoldLabel").text, "1.23M", "1234567 se muestra 1.23M")
	await _set_gold(2.5e12)
	_check_eq(_label("GoldLabel").text, "2.50T", "2.5e12 se muestra 2.50T")
