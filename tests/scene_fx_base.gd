extends "res://tests/test_base.gd"
## Base de los tests de efectos de la escena (juice_test.gd, scene_life_test.gd): arma la escena principal en
## un celular de 720x1280 con el balance real sin botín (un cofre al azar movería lo que se mide), deja
## "reducir efectos" apagado, y al final restaura Settings y Economy. Trae los helpers para mirar la mina.
##
## Cada test hereda de acá, implementa _run_tests() y no llama a _finish() (lo hace la base).

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
	await _run_tests()
	_scene.get_parent().queue_free()
	await process_frame
	_settings.from_dict(_saved_settings)
	_economy.load_balance(JSON.parse_string(FileAccess.get_file_as_string("res://data/balance.json")))
	_economy.reset()
	_finish()


## Lo implementa cada test.
func _run_tests() -> void:
	pass


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


func _emitters(texture_prefix: String) -> Array[CPUParticles2D]:
	var found: Array[CPUParticles2D] = []
	for node: Node in _fx().find_children("*", "CPUParticles2D", true, false):
		var emitter: CPUParticles2D = node as CPUParticles2D
		if emitter.texture != null and emitter.texture.resource_path.get_file().begins_with(texture_prefix):
			found.append(emitter)
	return found


func _emitting(emitters: Array[CPUParticles2D]) -> int:
	return emitters.filter(func(emitter: CPUParticles2D) -> bool: return emitter.emitting).size()


func _glows() -> Array[Node]:
	# Solo los hijos directos de la capa: las auras de las runas (también circle_05) van dentro de cada runa.
	return _fx().get_children().filter(func(node: Node) -> bool:
		if not (node is TextureRect):
			return false
		return (node as TextureRect).texture != null and (node as TextureRect).texture.resource_path.ends_with("circle_05.png") and not node.is_queued_for_deletion())


## Un control "rebota" si justo después de tocarlo está escalado (desde su centro) y al rato vuelve a 1,
## sin moverse de lugar: la escala no cambia el layout.
func _check_bounce(control: Control, label: String) -> void:
	var rect: Rect2 = control.get_global_rect()
	await process_frame
	_check(not control.scale.is_equal_approx(Vector2.ONE), "%s rebota al tocarlo (%s)" % [label, str(control.scale)])
	_check(control.pivot_offset.is_equal_approx(control.size * 0.5), "%s rebota desde su centro" % label)
	await _wait(0.4)
	_check(control.scale.is_equal_approx(Vector2.ONE), "%s vuelve a su tamaño" % label)
	_check(control.get_global_rect().is_equal_approx(rect), "%s no se mueve de lugar" % label)
