extends "res://tests/scene_fx_base.gd"
## @lento (animaciones: corre con -All o -Slow, ver tools/run_tests.ps1)
## Tests headless del "jugo" del golpe (F2-B): número flotante, roca que se aplasta, sacudida, astillas y gemas,
## y lo que apaga "reducir efectos". Miden estado, no cómo se ve: eso se mira en capturas (tools/screenshot.gd).
## Los helpers y el armado de la escena están en scene_fx_base.gd.

const WebPlatform := preload("res://core/web_platform.gd")


## Anota las vibraciones pedidas.
class FakePlatform extends WebPlatform:
	var calls: Array[int] = []

	func vibrate(milliseconds: int) -> void:
		calls.append(milliseconds)


func _run_tests() -> void:
	await _test_fx_layer()
	await _test_floating_number()
	await _test_floating_number_cap()
	await _test_rock_squash()
	await _test_shake()
	await _test_reduce_effects()
	await _test_vibration_platform()
	await _test_particles()
	await _test_clear_effects()


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


func _test_vibration_platform() -> void:
	_section("La vibración pasa por la plataforma (en la web espera a que se complete el primer toque)")
	var fake: FakePlatform = FakePlatform.new()
	_mine().set("platform", fake)
	_tap()
	_check_eq(fake.calls, [25] as Array[int], "cada golpe la pide ahí")
	_mine().set("platform", WebPlatform.new())
	await _wait(1.0)


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


func _test_clear_effects() -> void:
	_section("Los efectos se pueden limpiar de golpe")
	for index: int in range(5):
		_tap()
	await process_frame
	_check(_floaters().size() > 0 and _emitting(_emitters("chips_")) > 0, "hay números y astillas en el aire")
	_mine().call("clear_effects")
	await process_frame
	_check_eq(_floaters().size(), 0, "clear_effects saca los números")
	_check_eq(_emitting(_emitters("chips_")), 0, "y apaga las astillas")
	_check(_emitters("chips_").all(func(e: CPUParticles2D) -> bool: return not e.visible), "y saca las que estaban en el aire (no se ven)")
	_tap()
	_check_eq(_emitters("chips_").filter(func(e: CPUParticles2D) -> bool: return e.visible and e.emitting).size(), 1, "el próximo golpe vuelve a largar astillas")
	await _wait(1.0)
	_check((_mine().get("shake_offset") as Vector2).is_zero_approx() and _rock().scale.is_equal_approx(Vector2.ONE), "y deja la roca quieta en su lugar")
