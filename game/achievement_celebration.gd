extends Control
## El festejo de un logro: en el medio de la pantalla, un trofeo con rayos que giran, papelitos y destellos, y el
## nombre. No come toques (se sigue picando) y se va solo. El destello, la pausa y el sonido los pone main.gd.

const Palette := preload("res://game/palette.gd")
const TROPHY: Texture2D = preload("res://assets/ui/game_icons/trophy.png")
const GLOW: Texture2D = preload("res://assets/particles/particle_pack/circle_05.png")
const SPARK: Texture2D = preload("res://assets/particles/particle_pack/star_06.png")

const SHOW_SECONDS: float = 2.6
const FADE_SECONDS: float = 0.35
## Dónde va el centro, como parte del alto de la pantalla.
const HEIGHT_RATIO: float = 0.4
const TROPHY_SIZE: float = 176.0
const TEXT_WIDTH: float = 660.0
const RAY_COUNT: int = 14
const RAY_LENGTH: float = 330.0
const RAY_SPEED: float = 0.7
const CONFETTI: int = 110
const SPARKS: int = 28
const CONFETTI_COLORS: Array[Color] = [Palette.YELLOW, Palette.GOLD, Palette.CYAN, Palette.PINK, Palette.AQUA, Palette.FROST]


## Los rayos de atrás del trofeo.
class Rays extends Control:
	func _draw() -> void:
		for i: int in range(RAY_COUNT):
			var from: float = TAU * i / RAY_COUNT
			var to: float = from + TAU / RAY_COUNT * 0.5
			draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2.from_angle(from) * RAY_LENGTH, Vector2.from_angle(to) * RAY_LENGTH]),
				PackedColorArray([Color(Palette.YELLOW, 0.55), Color(Palette.GOLD, 0.0), Color(Palette.GOLD, 0.0)]))


var _stage: Node2D
var _rays: Rays
var _emblem: Node2D
var _name_label: Label
var _confetti: CPUParticles2D
var _sparks: CPUParticles2D
var _left: float = 0.0
## Cuántos logros cuenta el festejo de ahora.
var _count: int = 0
var _pop: Tween


func _init() -> void:
	name = "AchievementCelebration"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage = Node2D.new()
	add_child(_stage)
	_stage.add_child(_sprite(GLOW, 760.0, Color(0.05, 0.03, 0.08, 0.85)))
	_rays = Rays.new()
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_rays)
	_emblem = Node2D.new()
	_stage.add_child(_emblem)
	_emblem.add_child(_sprite(GLOW, 420.0, Color(Palette.GOLD, 0.8)))
	_emblem.add_child(_sprite(TROPHY, TROPHY_SIZE, Palette.YELLOW))
	_confetti = _build_confetti()
	_stage.add_child(_confetti)
	_sparks = _build_sparks()
	_stage.add_child(_sparks)
	var title: Label = _label("CelebrationTitle", 84, Palette.YELLOW, 110.0)
	title.text = "¡LOGRO!"
	_name_label = _label("CelebrationName", 40, Palette.FROST, 214.0)
	resized.connect(_place)


## Festeja `count` logros nuevos; si ya había un festejo, se suman. `single_name` es el nombre cuando es uno solo.
func play(count: int, single_name: String, reduce_effects: bool) -> void:
	var fresh: bool = not visible
	_count = count if fresh else _count + count
	_name_label.text = single_name if _count == 1 else "%d logros nuevos" % _count
	_left = SHOW_SECONDS
	visible = true
	modulate.a = 1.0
	_place()
	_confetti.amount = CONFETTI / 3 if reduce_effects else CONFETTI
	_sparks.amount = SPARKS / 2 if reduce_effects else SPARKS
	_confetti.restart()
	_sparks.restart()
	if _pop != null and _pop.is_valid():
		_pop.kill()
	_emblem.scale = Vector2.ONE * (0.2 if fresh else 0.8)
	_pop = create_tween()
	_pop.tween_property(_emblem, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func dismiss() -> void:
	visible = false
	_count = 0
	_left = 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	_rays.rotation += delta * RAY_SPEED
	_left -= delta
	modulate.a = clampf(_left / FADE_SECONDS, 0.0, 1.0)
	if _left <= 0.0:
		dismiss()


func _place() -> void:
	_stage.position = Vector2(size.x * 0.5, size.y * HEIGHT_RATIO).round()


func _sprite(texture: Texture2D, wide: float, color: Color) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = texture
	sprite.scale = Vector2.ONE * (wide / texture.get_width())
	sprite.modulate = color
	return sprite


func _label(node_name: String, font_size: int, color: Color, below: float) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size = Vector2(TEXT_WIDTH, 60.0)
	label.position = Vector2(-TEXT_WIDTH * 0.5, below)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Palette.OUTLINE)
	label.add_theme_constant_override("outline_size", 14)
	_stage.add_child(label)
	return label


func _build_confetti() -> CPUParticles2D:
	var particles: CPUParticles2D = _burst("Confetti", 2.2, CONFETTI)
	var paper: Image = Image.create_empty(8, 14, false, Image.FORMAT_RGBA8)
	paper.fill(Color.WHITE)
	particles.texture = ImageTexture.create_from_image(paper)
	particles.direction = Vector2.UP
	particles.spread = 75.0
	particles.initial_velocity_min = 350.0
	particles.initial_velocity_max = 850.0
	particles.gravity = Vector2(0.0, 900.0)
	particles.angle_min = 0.0
	particles.angle_max = 360.0
	particles.angular_velocity_min = -400.0
	particles.angular_velocity_max = 400.0
	particles.scale_amount_min = 0.8
	particles.scale_amount_max = 1.7
	# A cada papelito le toca un color al azar.
	var colors: Gradient = Gradient.new()
	colors.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var offsets: PackedFloat32Array = PackedFloat32Array()
	for i: int in range(CONFETTI_COLORS.size()):
		offsets.append(float(i) / CONFETTI_COLORS.size())
	colors.offsets = offsets
	colors.colors = PackedColorArray(CONFETTI_COLORS)
	particles.color_initial_ramp = colors
	return particles


func _build_sparks() -> CPUParticles2D:
	var particles: CPUParticles2D = _burst("Sparks", 1.1, SPARKS)
	particles.texture = SPARK
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 260.0
	particles.initial_velocity_max = 620.0
	particles.damping_min = 300.0
	particles.damping_max = 500.0
	particles.scale_amount_min = 40.0 / SPARK.get_width()
	particles.scale_amount_max = 110.0 / SPARK.get_width()
	particles.color = Palette.YELLOW
	var fade: Gradient = Gradient.new()
	fade.colors = PackedColorArray([Color.WHITE, Color(1.0, 1.0, 1.0, 0.0)])
	particles.color_ramp = fade
	return particles


func _burst(node_name: String, lifetime: float, amount: int) -> CPUParticles2D:
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.name = node_name
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.lifetime = lifetime
	particles.amount = amount
	return particles
