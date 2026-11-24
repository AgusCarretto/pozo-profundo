extends "res://tests/test_base.gd"
## Tests headless del "jugo" (F2-B): lo que pasa en pantalla cuando golpeás, comprás, sale un cofre...
##
## Miden estado, no cómo se ve: que aparezca el número flotante con el texto justo y después se vaya, que
## la roca se aplaste y vuelva a su tamaño, que la sacudida vuelva a cero, que "reducir efectos" apague lo
## que tiene que apagar. Cómo se ve se mira en capturas (tools/screenshot.gd).

const NumberFormat := preload("res://core/number_format.gd")
const MAIN_SCENE: String = "res://game/main.tscn"
const PHONE: Vector2 = Vector2(720, 1280)

var _economy: Node
var _settings: Node
var _saved_settings: Dictionary = {}
var _scene: Control


func _initialize() -> void:
	await process_frame
	_economy = root.get_node("Economy")
	_settings = root.get_node("Settings")
	_saved_settings = _settings.to_dict()
	_settings.reduce_effects = false
	_economy.load_balance(_real_balance_without_loot())
	await _mount()
	await _test_fx_layer()
	await _test_floating_number()
	await _test_floating_number_cap()
	await _test_rock_squash()
	await _test_shake()
	await _test_reduce_effects()
	_scene.get_parent().queue_free()
	await process_frame
	_settings.from_dict(_saved_settings)
	_economy.load_balance(JSON.parse_string(FileAccess.get_file_as_string("res://data/balance.json")))
	_economy.reset()
	_finish()


## El balance real sin botín: un cofre al azar movería lo que estos tests miran.
func _real_balance_without_loot() -> Dictionary:
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance.json"))
	balance.erase("loot")
	return balance


func _mount() -> void:
	var host: Control = Control.new()
	host.size = PHONE
	root.add_child(host)
	_scene = (load(MAIN_SCENE) as PackedScene).instantiate() as Control
	host.add_child(_scene)
	await process_frame
	await process_frame


func _mine() -> Control:
	return _scene.get_node("%MineView") as Control


func _rock() -> Control:
	return _scene.get_node("%Rock") as Control


func _fx() -> Control:
	return _mine().get_node("FxLayer") as Control


func _tap() -> void:
	(_scene.get_node("%TapButton") as Button).button_down.emit()


func _floaters() -> Array[Label]:
	var labels: Array[Label] = []
	for child: Node in _fx().get_children():
		if child is Label and not child.is_queued_for_deletion():
			labels.append(child as Label)
	return labels


## Espera `seconds` de tiempo real (los tweens avanzan con el proceso del árbol).
func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _test_fx_layer() -> void:
	_section("La capa de efectos de la mina")
	var fx: Control = _fx()
	_check(fx != null, "la mina tiene una capa FxLayer")
	if fx == null:
		return
	_check_eq(fx.get_index(), _mine().get_child_count() - 1, "va última: los efectos se ven encima de la roca, la viñeta y el cartel de ayuda")
	_check_eq(fx.mouse_filter, Control.MOUSE_FILTER_IGNORE, "no come toques (la roca sigue respondiendo)")
	_check(fx.position.is_zero_approx() and fx.size.is_equal_approx(_mine().size), "cubre toda la mina")
	_check(fx.clip_contents, "y recorta lo que se sale (un número no se mete en el HUD)")


func _test_floating_number() -> void:
	_section("Número flotante en cada golpe")
	_economy.reset()
	await _wait(1.0)
	var before: int = _floaters().size()
	_tap()
	var floaters: Array[Label] = _floaters()
	_check_eq(floaters.size(), before + 1, "un golpe crea un número")
	if floaters.is_empty():
		return
	var label: Label = floaters[floaters.size() - 1]
	_check_eq(label.text, "+%s" % NumberFormat.format_number(_economy.hit_value()), "dice cuánto oro dio el golpe (%s)" % label.text)
	_check_eq(label.mouse_filter, Control.MOUSE_FILTER_IGNORE, "no come toques")
	var rock_rect: Rect2 = _rock().get_rect()
	var center: Vector2 = label.position + label.size * 0.5
	_check(center.x >= rock_rect.position.x and center.x <= rock_rect.end.x, "sale a la altura de la roca (en horizontal)")
	_check(center.y <= rock_rect.get_center().y, "desde la mitad de arriba de la roca")
	var start_y: float = label.position.y
	await _wait(0.3)
	_check(is_instance_valid(label) and label.position.y < start_y, "sube")
	await _wait(0.3)
	_check(is_instance_valid(label) and label.modulate.a < 1.0, "y en la segunda mitad se va desvaneciendo")
	await _wait(0.7)
	_check(not is_instance_valid(label) or label.is_queued_for_deletion(), "al rato desaparece (se libera)")


func _test_floating_number_cap() -> void:
	_section("Muchos golpes seguidos no llenan la pantalla de números")
	for index: int in range(60):
		_tap()
	var cap: int = int(_mine().get_script().get_script_constant_map().get("MAX_FLOATERS", 0))
	_check(cap >= 6 and cap <= 20, "hay un tope razonable de números a la vez (%d)" % cap)
	_check(_floaters().size() <= cap, "60 golpes dejan como mucho %d números (%d)" % [cap, _floaters().size()])
	await _wait(1.5)
	_check_eq(_floaters().size(), 0, "y se van todos")


func _test_rock_squash() -> void:
	_section("La roca se aplasta y vuelve")
	await _wait(0.5)
	var rock: Control = _rock()
	var rect_before: Rect2 = rock.get_rect()
	_tap()
	await process_frame
	_check(not rock.scale.is_equal_approx(Vector2.ONE), "justo después del golpe la roca está deformada (%s)" % str(rock.scale))
	_check(rock.scale.x > 1.0 and rock.scale.y < 1.0, "aplastada: más ancha y más baja")
	_check(rock.pivot_offset.is_equal_approx(rock.size * Vector2(0.5, 1.0)), "se aplasta contra el piso (el pivote está abajo al centro)")
	await _wait(0.5)
	_check(rock.scale.is_equal_approx(Vector2.ONE), "y vuelve a su tamaño (%s)" % str(rock.scale))
	_check(rock.get_rect().is_equal_approx(rect_before), "sin moverse de lugar (el layout no cambia)")


func _test_shake() -> void:
	_section("Sacudida leve, solo de la mina")
	await _wait(0.5)
	var mine: Control = _mine()
	var hud: Control = _scene.get_node("%HudPanel") as Control
	var hud_position: Vector2 = hud.global_position
	var mine_position: Vector2 = mine.global_position
	var rock_position: Vector2 = _rock().position
	_tap()
	await process_frame
	var offset: Vector2 = mine.get("shake_offset")
	_check(not offset.is_zero_approx(), "el golpe sacude (%s)" % str(offset))
	_check(offset.length() <= 12.0, "pero poco (máx 12 px de diseño)")
	_check(_rock().position.is_equal_approx(rock_position + offset), "la roca se mueve con la sacudida")
	_check(hud.global_position.is_equal_approx(hud_position) and mine.global_position.is_equal_approx(mine_position), "el HUD y la mina en sí no se mueven (no es la cámara)")
	await _wait(0.5)
	_check((mine.get("shake_offset") as Vector2).is_zero_approx(), "después se queda quieta")
	_check(_rock().position.is_equal_approx(rock_position), "y la roca vuelve a su lugar exacto")


func _test_reduce_effects() -> void:
	_section("Reducir efectos")
	var mine: Control = _mine()
	var vibrations: int = int(mine.get("vibrations"))
	_tap()
	_check_eq(int(mine.get("vibrations")), vibrations + 1, "con efectos, cada golpe vibra")
	await _wait(0.5)
	_settings.reduce_effects = true
	await process_frame
	vibrations = int(mine.get("vibrations"))
	var moved: bool = false
	_tap()
	for frame: int in range(5):
		await process_frame
		if not (mine.get("shake_offset") as Vector2).is_zero_approx():
			moved = true
	_check(not moved, "sin sacudida")
	_check_eq(int(mine.get("vibrations")), vibrations, "ni vibración")
	_check(_floaters().size() >= 1, "pero el número sigue saliendo (es información, no adorno)")
	_settings.reduce_effects = false
	await _wait(1.2)
