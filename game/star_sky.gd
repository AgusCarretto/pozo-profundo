extends Control
## El cielo de fondo del árbol: un degradado y estrellitas que titilan (quietas con "reducir efectos"). Las posiciones
## salen de una semilla fija: es siempre el mismo cielo.

const Palette := preload("res://game/palette.gd")

const COUNT: int = 130
const SEED: int = 20261126
const TOP: Color = Color(0.055, 0.045, 0.095)
const BOTTOM: Color = Color(0.13, 0.12, 0.23)
## Cada cuánto se redibuja el titileo (s).
const TWINKLE_STEP: float = 0.1

## Por estrella: [posición como parte del tamaño, radio, brillo, fase].
var _stars: Array = []
var _time: float = 0.0
var _since_draw: float = 0.0


func _init() -> void:
	name = "StarSky"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = SEED
	for i: int in range(COUNT):
		_stars.append([Vector2(random.randf(), random.randf()), random.randf_range(1.0, 3.2), random.randf_range(0.2, 0.8), random.randf() * TAU])


func _process(delta: float) -> void:
	if not is_visible_in_tree() or Settings.reduce_effects:
		return
	_time += delta
	_since_draw += delta
	if _since_draw >= TWINKLE_STEP:
		_since_draw = 0.0
		queue_redraw()


func _draw() -> void:
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)]),
		PackedColorArray([TOP, TOP, BOTTOM, BOTTOM]))
	for star: Array in _stars:
		var at: Vector2 = (star[0] as Vector2) * size
		var radius: float = star[1]
		var alpha: float = float(star[2]) * (0.75 + 0.25 * sin(_time * 1.7 + float(star[3])))
		var color: Color = Color(Palette.FROST, alpha)
		draw_rect(Rect2(at - Vector2.ONE * radius * 0.5, Vector2.ONE * radius), color)
		if radius > 2.7:
			# Las más grandes, con una cruz.
			draw_rect(Rect2(at - Vector2(radius * 1.6, 0.5), Vector2(radius * 3.2, 1.0)), Color(color, alpha * 0.45))
			draw_rect(Rect2(at - Vector2(0.5, radius * 1.6), Vector2(1.0, radius * 3.2)), Color(color, alpha * 0.45))
