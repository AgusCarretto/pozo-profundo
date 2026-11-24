extends Control
## La mina, vista desde arriba: un piso por bioma, la roca grande al centro y la cuadrilla parada alrededor.
##
## Es solo presentación: no sabe nada de Economy. main.gd le dice en qué bioma estás (show_biome) y
## qué cuadrilla hay (set_crew). Acá se dibuja el piso, se acomodan los sprites y se elige el arte.
## El pixel art va con filtro Nearest (lo fija la escena) y a escala entera: cada píxel de un sprite es
## un cuadrado de N x N píxeles de pantalla, sin borroneo.
##
## Para que se lea que están parados en el piso: cada sprite tiene una sombra elíptica a los pies
## (shadow_ellipses), los de más abajo se dibujan delante, y cada minero mira hacia la roca.

const Palette := preload("res://game/palette.gd")
const BiomePalette := preload("res://game/biome_palette.gd")

const SPRITE_DIR: String = "res://assets/sprites/generated/"
const DEFAULT_BIOME: String = "earth"
## Cuántos mineros caben alrededor de la roca; con más unidades compradas se ven estos.
const MINER_COUNT: int = 8
## Hacia dónde puede mirar un minero (sufijo del archivo: miner_3_left.png).
const GAZES: Array[String] = ["left", "right", "down"]

## Tamaño de pantalla para el que se diseñó el acomodo (px de diseño); con otro tamaño todo escala parejo.
const DESIGN_SIZE: Vector2 = Vector2(720.0, 480.0)
const MIN_UNIT: float = 0.6
const MAX_UNIT: float = 1.4
## A qué altura de la mina queda el centro de la roca (0,5 sería justo en el medio): un poco más abajo.
const ROCK_HEIGHT_SHARE: float = 0.55
## Cuántos píxeles de pantalla mide cada píxel de sprite, a tamaño de diseño.
const ROCK_SCALE: int = 22
const MINER_SCALE: int = 5
const DRILL_SCALE: int = 8
const GOLEM_SCALE: int = 8
const BACKDROP_SCALE: int = 8
## El mosaico del piso se mezcla con el color base a esta fuerza (1 = tal cual): baja el contraste del
## fondo para que la roca y la cuadrilla sean lo que se ve.
const BACKDROP_STRENGTH: float = 0.4
## La zona de toque pasa de la roca por este margen (px de diseño): es más fácil acertar.
const TAP_MARGIN: float = 24.0

## Sombras: ancho (como parte del ancho del sprite) y alto (como parte de su ancho), y color.
const SHADOW_WIDTH: float = 0.4
const ROCK_SHADOW_WIDTH: float = 0.5
const MACHINE_SHADOW_WIDTH: float = 0.44
const SHADOW_FLATNESS: float = 0.3
const SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.5)

## Golpe: la roca se aplasta contra el piso (más ancha y más baja) y rebota a su tamaño.
const SQUASH_SCALE: Vector2 = Vector2(1.12, 0.86)
const SQUASH_TIME: float = 0.22
## Golpe: sacudida leve de la mina (px de diseño) que se apaga sola.
const SHAKE_STRENGTH: float = 6.0
const SHAKE_TIME: float = 0.16
## Golpe: número flotante que sube y se desvanece. Más de MAX_FLOATERS a la vez no: se va el más viejo.
const MAX_FLOATERS: int = 12
const FLOAT_RISE: float = 120.0
const FLOAT_TIME: float = 0.8
## Carriles por los que salen los números (como parte del ancho de la roca, desde su centro): dos golpes
## seguidos salen por carriles distintos y no se pisan. Encima, un poco de azar.
const FLOAT_LANES: Array[float] = [-0.26, 0.12, -0.08, 0.28, 0.0, -0.3, 0.2]
const FLOAT_JITTER: float = 0.04
## Golpe: vibración corta (solo hace algo en celulares).
const VIBRATION_MS: int = 25

## Puestos de trabajo, en px de diseño desde el centro de la roca. Ninguno toca la roca (que mide 352):
## los mineros ocupan primero los costados y después una fila arriba, y el gólem y el taladro quedan
## abajo a los lados. Abajo de la roca no hay lugar: la roca va un poco más abajo del centro.
const MINER_SLOTS: Array[Vector2] = [
	Vector2(-240.0, 25.0), Vector2(240.0, 25.0), Vector2(-240.0, -95.0), Vector2(240.0, -95.0),
	Vector2(-75.0, -222.0), Vector2(75.0, -222.0), Vector2(-225.0, -222.0), Vector2(225.0, -222.0),
]
const DRILL_SLOT: Vector2 = Vector2(256.0, 135.0)
const GOLEM_SLOT: Vector2 = Vector2(-256.0, 135.0)

## Bioma que se está mostrando ("earth", "rock"...) y color de fondo de su paleta.
var biome_id: String = ""
var backdrop_color: Color = Color.BLACK
## Los puestos de la cuadrilla; solo se ven los ocupados (set_crew).
var miner_sprites: Array[TextureRect] = []
var drill_sprite: TextureRect
var golem_sprite: TextureRect

## "Reducir efectos" (lo fija main.gd desde Settings): sin sacudida ni vibración.
var reduce_effects: bool = false
## Cuánto está corrida ahora la mina por la sacudida (px de pantalla); cero en reposo. La roca, la
## cuadrilla y el piso se dibujan corridos; la mina en sí (y el HUD) no se mueven.
var shake_offset: Vector2 = Vector2.ZERO:
	set(value):
		shake_offset = value
		_apply_shake()
## Cuántas veces vibró (para los tests: en la PC vibrar no hace nada visible).
var vibrations: int = 0

var _rock: TextureRect
var _tap_button: Button
var _backdrop_texture: Texture2D
## Capa de efectos (números flotantes, partículas...): último hijo, no come toques, recorta lo que se sale.
var _fx: Control
## Escala del acomodo actual (1 = tamaño de diseño).
var _unit: float = 1.0
## Dónde va cada sprite sin sacudida (lo calcula _layout).
var _base_positions: Dictionary = {}
var _squash_tween: Tween
var _shake_tween: Tween
var _shake_direction: Vector2 = Vector2.RIGHT
var _next_lane: int = 0


func _ready() -> void:
	_rock = get_node("Rock") as TextureRect
	_tap_button = get_node("TapButton") as Button
	for index: int in range(MINER_COUNT):
		miner_sprites.append(_make_sprite("miner_%d.png" % (index + 1), "Miner%d" % (index + 1)))
	drill_sprite = _make_sprite("drill.png", "Drill")
	golem_sprite = _make_sprite("golem.png", "Golem")
	_fx = Control.new()
	_fx.name = "FxLayer"
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.clip_contents = true
	add_child(_fx)
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	show_biome(DEFAULT_BIOME)
	_layout()


# --- Golpe -------------------------------------------------------------------

## Lo que se ve y se siente al golpear: la roca se aplasta, la mina se sacude, sale `text` flotando y el
## celular vibra. Con reduce_effects no hay sacudida ni vibración (el número y el aplastado quedan).
func play_hit(text: String) -> void:
	_squash_rock()
	_spawn_floater(text)
	if reduce_effects:
		return
	_shake()
	vibrations += 1
	Input.vibrate_handheld(VIBRATION_MS)


func _squash_rock() -> void:
	if _squash_tween != null and _squash_tween.is_valid():
		_squash_tween.kill()
	_rock.scale = SQUASH_SCALE
	_squash_tween = create_tween()
	_squash_tween.tween_property(_rock, "scale", Vector2.ONE, SQUASH_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## La sacudida va y viene en una dirección al azar y se apaga en SHAKE_TIME.
func _shake() -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_direction = Vector2.RIGHT.rotated(randf() * TAU)
	_shake_tween = create_tween()
	_shake_tween.tween_method(_shake_step, 0.0, 1.0, SHAKE_TIME)
	_shake_tween.tween_callback(func() -> void: shake_offset = Vector2.ZERO)
	_shake_step(0.0)


## `progress` de 0 a 1: oscila (tres idas y vueltas) y se achica hasta cero.
func _shake_step(progress: float) -> void:
	var amplitude: float = SHAKE_STRENGTH * _unit * (1.0 - progress)
	shake_offset = (_shake_direction * amplitude * cos(progress * TAU * 3.0)).round()


func _apply_shake() -> void:
	for sprite: Variant in _base_positions:
		(sprite as Control).position = _base_positions[sprite] + shake_offset
	queue_redraw()


func _spawn_floater(text: String) -> void:
	var alive: Array[Node] = []
	for child: Node in _fx.get_children():
		if child is Label and not child.is_queued_for_deletion():
			alive.append(child)
	while alive.size() >= MAX_FLOATERS:
		alive.pop_front().queue_free()
	var label: Label = Label.new()
	label.theme_type_variation = &"FloatLabel"
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.add_child(label)
	label.size = label.get_combined_minimum_size()
	label.pivot_offset = label.size * 0.5
	var rock_rect: Rect2 = Rect2(_base_positions.get(_rock, _rock.position), _rock.size)
	var start: Vector2 = Vector2(
		rock_rect.get_center().x + (FLOAT_LANES[_next_lane] + randf_range(-FLOAT_JITTER, FLOAT_JITTER)) * rock_rect.size.x,
		rock_rect.position.y + rock_rect.size.y * randf_range(0.18, 0.3))
	_next_lane = (_next_lane + 1) % FLOAT_LANES.size()
	label.position = (start - label.size * 0.5).round()
	label.scale = Vector2(0.6, 0.6)
	var tween: Tween = label.create_tween().set_parallel(true)
	tween.tween_property(label, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", label.position.y - FLOAT_RISE * _unit, FLOAT_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, FLOAT_TIME * 0.6).set_delay(FLOAT_TIME * 0.4)
	tween.chain().tween_callback(label.queue_free)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


## Cambia el piso y la roca por los del bioma `id` (uno desconocido usa los de Tierra).
func show_biome(id: String) -> void:
	var known: String = id if BiomePalette.BY_ID.has(id) else DEFAULT_BIOME
	if known == biome_id:
		return
	biome_id = known
	backdrop_color = BiomePalette.of(known)["bg"]
	if _rock != null:
		_rock.texture = load(SPRITE_DIR + "rock_%s.png" % known) as Texture2D
	_backdrop_texture = load(SPRITE_DIR + "bg_%s.png" % known) as Texture2D
	queue_redraw()


## Muestra `miners` mineros (hasta MINER_COUNT) y, si se compraron, el taladro y el gólem.
func set_crew(miners: int, has_drill: bool, has_golem: bool) -> void:
	for index: int in range(miner_sprites.size()):
		miner_sprites[index].visible = index < miners
	drill_sprite.visible = has_drill
	golem_sprite.visible = has_golem
	queue_redraw()


## Las sombras que se dibujan: una elipse ancha y chata a los pies de la roca y de cada sprite que se ve.
## Cada una es {sprite, center, radius} en coordenadas de la mina.
func shadow_ellipses() -> Array[Dictionary]:
	var shadows: Array[Dictionary] = []
	if _rock == null:
		return shadows
	var casters: Array[TextureRect] = [_rock, drill_sprite, golem_sprite]
	casters.append_array(miner_sprites)
	for sprite: TextureRect in casters:
		if not sprite.visible:
			continue
		var width_share: float = SHADOW_WIDTH
		if sprite == _rock:
			width_share = ROCK_SHADOW_WIDTH
		elif sprite == drill_sprite or sprite == golem_sprite:
			width_share = MACHINE_SHADOW_WIDTH
		var pixel: float = sprite.size.x / 16.0
		var radius_x: float = sprite.size.x * width_share
		shadows.append({
			"sprite": sprite,
			"center": Vector2(sprite.position.x + sprite.size.x * 0.5, sprite.position.y + sprite.size.y - pixel * 0.5),
			"radius": Vector2(radius_x, radius_x * SHADOW_FLATNESS),
		})
	return shadows


func _make_sprite(file_name: String, node_name: String) -> TextureRect:
	var sprite: TextureRect = TextureRect.new()
	sprite.name = node_name
	sprite.texture = load(SPRITE_DIR + file_name) as Texture2D
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_SCALE
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE # los toques pasan a la roca
	sprite.visible = false
	add_child(sprite)
	return sprite


## Acomoda la roca, la cuadrilla y la zona de toque según el tamaño actual de la mina.
func _layout() -> void:
	if _rock == null or drill_sprite == null:
		return
	var unit: float = clampf(minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y), MIN_UNIT, MAX_UNIT)
	_unit = unit
	var center: Vector2 = Vector2(size.x * 0.5, size.y * ROCK_HEIGHT_SHARE)
	_place(_rock, center, Vector2.ZERO, ROCK_SCALE, unit)
	for index: int in range(miner_sprites.size()):
		_place(miner_sprites[index], center, MINER_SLOTS[index], MINER_SCALE, unit)
		_look_at_rock(miner_sprites[index], index)
	_place(drill_sprite, center, DRILL_SLOT, DRILL_SCALE, unit)
	_place(golem_sprite, center, GOLEM_SLOT, GOLEM_SCALE, unit)
	# La roca se aplasta contra el piso: el pivote va abajo al centro.
	_rock.pivot_offset = _rock.size * Vector2(0.5, 1.0)
	var margin: Vector2 = Vector2.ONE * TAP_MARGIN * unit
	_tap_button.position = _rock.position - margin
	_tap_button.size = _rock.size + margin * 2.0
	_base_positions.clear()
	for sprite: TextureRect in [_rock, drill_sprite, golem_sprite] + miner_sprites:
		_base_positions[sprite] = sprite.position
	_apply_shake()
	_sort_by_depth()
	queue_redraw()


## Pone `sprite` con su centro en `center + slot * unit`, a escala entera (cada píxel = N x N en pantalla).
func _place(sprite: TextureRect, center: Vector2, slot: Vector2, pixel_scale: int, unit: float) -> void:
	var pixel: int = maxi(roundi(pixel_scale * unit), 1)
	sprite.size = Vector2(16 * pixel, 16 * pixel)
	sprite.position = (center + slot * unit - sprite.size * 0.5).round()


## El minero `index` mira hacia la roca: hacia abajo si está arriba de ella (y más lejos en vertical que en
## horizontal) y, si no, hacia el costado donde está la roca.
func _look_at_rock(sprite: TextureRect, index: int) -> void:
	var to_rock: Vector2 = _rock.get_rect().get_center() - sprite.get_rect().get_center()
	var gaze: String = GAZES[2] if (absf(to_rock.y) >= absf(to_rock.x) and to_rock.y > 0.0) else (GAZES[1] if to_rock.x > 0.0 else GAZES[0])
	sprite.texture = load(SPRITE_DIR + "miner_%d_%s.png" % [index + 1, gaze]) as Texture2D


## Los de más abajo se dibujan delante: parece que hay profundidad. Se ordena por posición de hijo (los
## que vienen después se dibujan encima) y NO con z_index: un z_index alto pondría los sprites por encima
## del cartel modal y del panel de debug, que son hermanos posteriores de esta escena.
func _sort_by_depth() -> void:
	var sprites: Array[TextureRect] = [_rock, drill_sprite, golem_sprite]
	sprites.append_array(miner_sprites)
	sprites.sort_custom(func(a: TextureRect, b: TextureRect) -> bool: return a.position.y + a.size.y < b.position.y + b.size.y)
	for index: int in range(sprites.size()):
		move_child(sprites[index], index)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), backdrop_color)
	if _backdrop_texture != null:
		# El piso también se sacude: el mosaico se corre con shake_offset (sobra una fila y una columna
		# de cada lado para que no se vea el borde).
		var tile: int = 16 * BACKDROP_SCALE
		var tint: Color = Color(1.0, 1.0, 1.0, BACKDROP_STRENGTH)
		for ty: int in range(-1, ceili(size.y / tile) + 1):
			for tx: int in range(-1, ceili(size.x / tile) + 1):
				draw_texture_rect(_backdrop_texture, Rect2(Vector2(tx * tile, ty * tile) + shake_offset, Vector2(tile, tile)), false, tint)
	# sombras a los pies de la roca y de la cuadrilla (se dibujan antes que los sprites: quedan debajo)
	for shadow: Dictionary in shadow_ellipses():
		var radius: Vector2 = shadow["radius"]
		draw_set_transform(shadow["center"], 0.0, Vector2(1.0, radius.y / radius.x))
		draw_circle(Vector2.ZERO, radius.x, SHADOW_COLOR)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
