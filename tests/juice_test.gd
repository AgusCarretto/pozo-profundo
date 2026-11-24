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
	await _test_particles()
	await _test_buttons_bounce()
	await _test_crew_pops_in()
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


func _emitters(texture_prefix: String) -> Array[CPUParticles2D]:
	var found: Array[CPUParticles2D] = []
	for node: Node in _fx().find_children("*", "CPUParticles2D", true, false):
		var emitter: CPUParticles2D = node as CPUParticles2D
		if emitter.texture != null and emitter.texture.resource_path.get_file().begins_with(texture_prefix):
			found.append(emitter)
	return found


func _emitting(emitters: Array[CPUParticles2D]) -> int:
	return emitters.filter(func(emitter: CPUParticles2D) -> bool: return emitter.emitting).size()


func _test_particles() -> void:
	_section("Astillas y gemas al golpear")
	var mine: Control = _mine()
	(mine.get("rng") as RandomNumberGenerator).seed = 7
	await _wait(1.0)
	var chips: Array[CPUParticles2D] = _emitters("chips_")
	var gems: Array[CPUParticles2D] = _emitters("gem")
	_check(chips.size() >= 2, "hay emisores de astillas (%d)" % chips.size())
	_check(gems.size() >= 1, "y de gemas (%d)" % gems.size())
	if chips.is_empty() or gems.is_empty():
		return
	_check_eq(_emitting(chips), 0, "en reposo no sale nada")
	_check(chips.all(func(e: CPUParticles2D) -> bool: return e.texture.resource_path.ends_with("chips_earth.png")), "las astillas son del color de la roca de Tierra")
	_tap()
	_check_eq(_emitting(chips), 1, "un golpe larga una tanda de astillas")
	var emitter: CPUParticles2D = chips.filter(func(e: CPUParticles2D) -> bool: return e.emitting)[0]
	var full_amount: int = emitter.amount
	_check(full_amount >= 6, "de varias astillas (%d)" % full_amount)
	_check(emitter.one_shot and emitter.explosiveness >= 0.8, "todas de golpe, una sola vez")
	_check(emitter.direction.y < 0.0 and emitter.gravity.y > 0.0, "saltan para arriba y caen")
	var rock_rect: Rect2 = _rock().get_rect()
	_check(rock_rect.grow(4.0).has_point(emitter.position), "salen de la roca")
	var material: CanvasItemMaterial = emitter.material as CanvasItemMaterial
	_check(material != null and material.particles_animation and emitter.texture.get_width() == 16, "cada astilla es uno de los 4 dibujos de la hoja (animación de partículas 2x2)")
	_check(material != null and material.particles_anim_h_frames == 2 and material.particles_anim_v_frames == 2 and emitter.anim_offset_max >= 0.75, "elegido al azar")
	var bursts_before: int = int(mine.get("gem_bursts"))
	for index: int in range(20):
		_tap()
		await process_frame
	var gem_bursts: int = int(mine.get("gem_bursts")) - bursts_before
	_check(_emitting(gems) >= 1, "las gemas salen de sus propios emisores")
	_check(gem_bursts >= 1, "de vez en cuando también saltan gemas (%d en 20 golpes)" % gem_bursts)
	_check(gem_bursts <= 15, "pero no siempre")
	_check_eq(_emitters("chips_").size(), chips.size(), "muchos golpes no crean emisores nuevos (se reusan)")
	(_scene.get_node("%MineView") as Node).call("show_biome", "magma")
	_check(chips.all(func(e: CPUParticles2D) -> bool: return e.texture.resource_path.ends_with("chips_magma.png")), "en Magma las astillas son de la roca de Magma")
	_settings.reduce_effects = true
	await process_frame
	_check(chips.all(func(e: CPUParticles2D) -> bool: return e.amount <= full_amount / 2), "con reducir efectos salen la mitad de astillas")
	_settings.reduce_effects = false
	await process_frame
	_check(chips.all(func(e: CPUParticles2D) -> bool: return e.amount == full_amount), "y vuelven a ser todas")
	(_scene.get_node("%MineView") as Node).call("show_biome", "earth")
	await _wait(1.2)

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


func _test_buttons_bounce() -> void:
	_section("Los botones rebotan")
	_economy.reset()
	_economy.gold = 1.0e6
	await _wait(0.1)
	var buy: Button = _scene.get_node("%GeneratorList").get_child(0).find_children("*", "Button", true, false)[0] as Button
	buy.pressed.emit()
	await _check_bounce(buy, "comprar")
	var pick: Button = _scene.get_node("%PickRow").find_children("*", "Button", true, false)[0] as Button
	pick.pressed.emit()
	await _check_bounce(pick, "mejorar el pico")
	var tab: Button = _scene.get_node("%TabLootButton") as Button
	tab.button_pressed = true
	await _check_bounce(tab, "una pestaña")
	(_scene.get_node("%TabCrewButton") as Button).button_pressed = true
	await _wait(0.4)
	var mode: Button = _scene.get_node("%Mode10Button") as Button
	mode.button_pressed = true
	await _check_bounce(mode, "el modo ×10")
	(_scene.get_node("%Mode1Button") as Button).button_pressed = true
	await _wait(0.4)
	var sound: Button = _scene.get_node("%SoundButton") as Button
	sound.pressed.emit()
	await _check_bounce(sound, "el silencio")
	sound.pressed.emit()
	await _wait(0.4)
	_economy.reset()
	await _wait(0.1)


func _test_crew_pops_in() -> void:
	_section("La cuadrilla nueva aparece animada")
	var mine: Control = _mine()
	var miners: Array = mine.get("miner_sprites")
	var first: Control = miners[0]
	_check(first.scale.is_equal_approx(Vector2.ONE), "al abrir el juego, la cuadrilla que ya había no aparece animada")
	_economy.reset()
	_economy.gold = 1000.0
	await _wait(0.1)
	var buy: Button = _scene.get_node("%GeneratorList").get_child(0).find_children("*", "Button", true, false)[0] as Button
	buy.pressed.emit()
	# main.gd refresca la mina en su _process, que corre después de process_frame: dos frames.
	await process_frame
	await process_frame
	_check(first.visible, "comprar un minero lo muestra en la mina")
	_check(first.scale.x < 1.0, "y aparece de a poco, creciendo (%s)" % str(first.scale))
	_check(first.pivot_offset.is_equal_approx(first.size * Vector2(0.5, 1.0)), "desde los pies")
	await _wait(0.6)
	_check(first.scale.is_equal_approx(Vector2.ONE), "hasta su tamaño")
	var drill: Control = mine.get("drill_sprite")
	_economy.gold = 1000.0
	var buy_drill: Button = _scene.get_node("%GeneratorList").get_child(1).find_children("*", "Button", true, false)[0] as Button
	buy_drill.pressed.emit()
	await process_frame
	await process_frame
	_check(drill.visible and drill.scale.x < 1.0, "el taladro también aparece animado")
	await _wait(0.6)
	# Una escena nueva con cuadrilla (una partida cargada) la muestra quieta.
	_scene.get_parent().queue_free()
	await process_frame
	await _mount()
	var reloaded: Array = _mine().get("miner_sprites")
	_check((reloaded[0] as Control).visible and (reloaded[0] as Control).scale.is_equal_approx(Vector2.ONE), "una partida cargada muestra la cuadrilla quieta, sin animar")
	_economy.reset()
	await _wait(0.1)