extends Control
## La mina: el fondo del bioma, la roca grande que se pica y la cuadrilla alrededor.
##
## Es solo presentación: no sabe nada de Economy. main.gd le dice en qué bioma estás (show_biome) y
## qué cuadrilla hay (set_crew). Acá se dibuja el fondo, se acomodan los sprites y se elige el arte.
## El pixel art va con filtro Nearest (lo fija la escena) y a escala entera: cada píxel de un sprite es
## un cuadrado de N x N píxeles de pantalla, sin borroneo.

const Palette := preload("res://game/palette.gd")
const BiomePalette := preload("res://game/biome_palette.gd")

const SPRITE_DIR: String = "res://assets/sprites/generated/"
const DEFAULT_BIOME: String = "earth"
## Cuántos mineros caben alrededor de la roca; con más unidades compradas se ven estos.
const MINER_COUNT: int = 8

## Tamaño de pantalla para el que se diseñó el acomodo (px de diseño); con otro tamaño todo escala parejo.
const DESIGN_SIZE: Vector2 = Vector2(720.0, 470.0)
const MIN_UNIT: float = 0.6
const MAX_UNIT: float = 1.4
## Cuánto sube el conjunto respecto del centro (px de diseño): la cuadrilla de abajo pesa más que el cielo.
const CENTER_LIFT: float = 20.0
## Cuántos píxeles de pantalla mide cada píxel de sprite, a tamaño de diseño.
const ROCK_SCALE: int = 14
const MINER_SCALE: int = 6
const DRILL_SCALE: int = 8
const GOLEM_SCALE: int = 10
const BACKDROP_SCALE: int = 8
## La zona de toque pasa de la roca por este margen (px de diseño): es más fácil acertar.
const TAP_MARGIN: float = 24.0

## Puestos de trabajo, en px de diseño desde el centro de la roca. Los mineros ocupan los primeros
## a medida que se compran: primero adelante, después a los costados y atrás.
const MINER_SLOTS: Array[Vector2] = [
	Vector2(-120.0, 178.0), Vector2(120.0, 178.0), Vector2(0.0, 196.0), Vector2(-215.0, -75.0),
	Vector2(215.0, -75.0), Vector2(-170.0, 15.0), Vector2(170.0, 15.0), Vector2(0.0, -150.0),
]
const DRILL_SLOT: Vector2 = Vector2(255.0, 112.0)
const GOLEM_SLOT: Vector2 = Vector2(-250.0, 108.0)

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


## Cambia el fondo y la roca por los del bioma `id` (uno desconocido usa los de Tierra).
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
	var center: Vector2 = Vector2(size.x * 0.5, size.y * 0.5 - CENTER_LIFT * unit)
	_place(_rock, center, Vector2.ZERO, ROCK_SCALE, unit)
	for index: int in range(miner_sprites.size()):
		_place(miner_sprites[index], center, MINER_SLOTS[index], MINER_SCALE, unit)
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
		for ty: int in range(ceili(size.y / tile)):
			for tx: int in range(ceili(size.x / tile)):
				draw_texture_rect(_backdrop_texture, Rect2(tx * tile, ty * tile, tile, tile), false)
	# bordes oscuros arriba y abajo: la mina se ve metida en la tierra
	var dark: Color = Color(Palette.OUTLINE, 0.75)
	var clear: Color = Color(Palette.OUTLINE, 0.0)
	var band: float = minf(size.y * 0.16, 72.0)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, band), Vector2(0, band)]),
		PackedColorArray([dark, dark, clear, clear]))
	draw_polygon(PackedVector2Array([Vector2(0, size.y - band), Vector2(size.x, size.y - band), Vector2(size.x, size.y), Vector2(0, size.y)]),
		PackedColorArray([clear, clear, dark, dark]))
	# sombras bajo la roca y la cuadrilla
	if _rock != null:
		_draw_shadow(_rock, 0.42)
	for sprite: TextureRect in miner_sprites:
		if sprite.visible:
			_draw_shadow(sprite, 0.34)
	for sprite: TextureRect in [drill_sprite, golem_sprite]:
		if sprite != null and sprite.visible:
			_draw_shadow(sprite, 0.4)


func _draw_shadow(sprite: TextureRect, width_share: float) -> void:
	var foot: Vector2 = Vector2(sprite.position.x + sprite.size.x * 0.5, sprite.position.y + sprite.size.y * 0.9)
	draw_set_transform(foot, 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, sprite.size.x * width_share, Color(Palette.OUTLINE, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
