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

var _rock: TextureRect
var _tap_button: Button
var _backdrop_texture: Texture2D


func _ready() -> void:
	_rock = get_node("Rock") as TextureRect
	_tap_button = get_node("TapButton") as Button
	for index: int in range(MINER_COUNT):
		miner_sprites.append(_make_sprite("miner_%d.png" % (index + 1), "Miner%d" % (index + 1)))
	drill_sprite = _make_sprite("drill.png", "Drill")
	golem_sprite = _make_sprite("golem.png", "Golem")
	show_biome(DEFAULT_BIOME)
	_layout()


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
	var center: Vector2 = Vector2(size.x * 0.5, size.y * ROCK_HEIGHT_SHARE)
	_place(_rock, center, Vector2.ZERO, ROCK_SCALE, unit)
	for index: int in range(miner_sprites.size()):
		_place(miner_sprites[index], center, MINER_SLOTS[index], MINER_SCALE, unit)
		_look_at_rock(miner_sprites[index], index)
	_place(drill_sprite, center, DRILL_SLOT, DRILL_SCALE, unit)
	_place(golem_sprite, center, GOLEM_SLOT, GOLEM_SCALE, unit)
	var margin: Vector2 = Vector2.ONE * TAP_MARGIN * unit
	_tap_button.position = _rock.position - margin
	_tap_button.size = _rock.size + margin * 2.0
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
		var tile: int = 16 * BACKDROP_SCALE
		var tint: Color = Color(1.0, 1.0, 1.0, BACKDROP_STRENGTH)
		for ty: int in range(ceili(size.y / tile)):
			for tx: int in range(ceili(size.x / tile)):
				draw_texture_rect(_backdrop_texture, Rect2(tx * tile, ty * tile, tile, tile), false, tint)
	# sombras a los pies de la roca y de la cuadrilla (se dibujan antes que los sprites: quedan debajo)
	for shadow: Dictionary in shadow_ellipses():
		var radius: Vector2 = shadow["radius"]
		draw_set_transform(shadow["center"], 0.0, Vector2(1.0, radius.y / radius.x))
		draw_circle(Vector2.ZERO, radius.x, SHADOW_COLOR)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
