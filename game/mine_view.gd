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
const Juice := preload("res://game/juice.gd")
const WebPlatform := preload("res://core/web_platform.gd")
const GLOW_TEXTURE: Texture2D = preload("res://assets/particles/particle_pack/circle_05.png")
const STAR_TEXTURE: Texture2D = preload("res://assets/particles/particle_pack/star_06.png")

## Explotó un cartucho de dinamita en t (coordenadas de la mina). main.gd le pone el sonido.
signal dynamite_exploded(at: Vector2)

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
## Cuánto se corre a la izquierda todo el conjunto (roca y cuadrilla), a tamaño de diseño: deja libre la
## columna de la derecha para los botones de Botín, Reliquias y modo (ver main.tscn, SideBar).
const COMPOSITION_SHIFT: float = -32.0
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
## Golpe: astillas de la roca (chips_<bioma>.png, 4 dibujos en 2x2) y, a veces, gemas. Cada golpe usa el
## emisor siguiente de un grupo fijo (así una tanda no corta a la anterior). Con reduce_effects, la mitad.
const CHIP_EMITTERS: int = 4
const CHIP_AMOUNT: int = 10
const CHIP_SCALE: float = 5.0
const CHIP_LIFETIME: float = 0.7
const GEM_EMITTERS: int = 2
const GEM_AMOUNT: int = 3
const GEM_SCALE: float = 2.0
const GEM_CHANCE: float = 0.3

## Dinamita: cada tanto aparece un cartucho en el borde de la roca, la mecha dura DYNAMITE_FUSE y explota
## (astillas hacia afuera y un destello). Más cuadrillas = más seguido: DYNAMITE_BASE_INTERVAL / raíz de la
## cantidad, sin bajar de DYNAMITE_MIN_INTERVAL. Con reduce_effects no hay destello.
const DYNAMITE_BASE_INTERVAL: float = 4.0
const DYNAMITE_MIN_INTERVAL: float = 0.7
const DYNAMITE_FUSE: float = 0.35
const DYNAMITE_SCALE: int = 3
const BLAST_SIZE: float = 220.0
const BLAST_TIME: float = 0.35
const BLAST_COLOR: Color = Color(1.0, 0.68, 0.2)

## Excavadoras rúnicas: una runa por excavadora (hasta ORBIT_RUNES_MAX) orbita la roca, con un aura suave del
## color de runa del bioma. La órbita es una elipse chata (la mina se ve desde arriba en perspectiva): las runas de
## atrás se ven más chicas y apagadas, las de adelante enteras.
const ORBIT_RUNES_MAX: int = 6
## Lo que vive en la capa de efectos pero es parte de la escena (las runas): clear_effects no lo saca.
const PERSISTENT_META: StringName = &"persistent"
const ORBIT_SCALE: int = 7
const ORBIT_SPEED: float = 0.7
## Radios de la órbita como parte del tamaño de la roca (horizontal, vertical).
const ORBIT_RADIUS: Vector2 = Vector2(0.62, 0.3)
const ORBIT_BOB: float = 5.0
const ORBIT_BACK_SCALE: float = 0.75
const ORBIT_BACK_ALPHA: float = 0.5
const ORBIT_GLOW_SIZE: float = 2.6
const ORBIT_GLOW_ALPHA: float = 0.75

## Cofre: cae desde arriba de la mina y se apoya sobre la roca con un rebote, con un brillo y estrellas del color
## de su rareza; al rato sube un poco y se desvanece. Más de MAX_CHESTS a la vez no: se va el más viejo. El
## especial (legendario) es más grande y brilla más.
const MAX_CHESTS: int = 3
const CHEST_SCALE: int = 5
const CHEST_FALL_TIME: float = 0.55
const CHEST_STAY_TIME: float = 1.4
const CHEST_FADE_TIME: float = 0.4
const CHEST_GLOW_SIZE: float = 2.6
## Aviso del cofre: arriba de la mina, entra deslizando, queda TOAST_TIME y se desvanece. Uno solo a la vez.
const TOAST_TIME: float = 2.2
const TOAST_SLIDE_TIME: float = 0.25
const TOAST_TOP: float = 16.0
const TOAST_ICON: float = 48.0
## Ancho que ocupan arriba a la derecha los botones del costado (main.tscn, SideBar: 100 px más sus márgenes).
const SIDE_COLUMN_WIDTH: float = 116.0

## Cambio de bioma: el piso y la roca nuevos aparecen fundiéndose sobre los viejos en BIOME_FADE_TIME. Un cartel
## pasajero (no modal) anuncia el bioma: entra creciendo, queda BANNER_TIME y se desvanece.
const BIOME_FADE_TIME: float = 0.9
const BANNER_TIME: float = 1.6
const BANNER_HEIGHT_SHARE: float = 0.3

## Mineros picando: cada uno tiene un pico (pick.png, a escala PICK_SCALE) en la mano del lado de la roca
## y lo usa en loop: lo levanta despacio, lo baja de golpe y vuelve. Cada minero tiene su fase y un período
## apenas distinto: nunca pican todos juntos.
const SWING_PERIOD: float = 1.1
const PICK_SCALE: int = 3
## Ángulos del pico (radianes; positivo = hacia la roca): bien levantado hacia atrás y el golpe.
const SWING_RAISED: float = -1.3
const SWING_STRIKE: float = 0.5
## Partes del ciclo: levantar hasta 60%, bajar de golpe hasta 72%, volver a quieto hasta 100%.
const SWING_RAISE_END: float = 0.6
const SWING_STRIKE_END: float = 0.72
## Dónde agarra el mango (píxel del sprite pick.png) y dónde está la mano del minero (parte de su tamaño).
const PICK_GRIP: Vector2 = Vector2(3.5, 13.5)
const HAND: Vector2 = Vector2(0.8, 0.62)

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
## Cuánto se ve el piso nuevo en un cambio de bioma (1 = del todo; menos = se está fundiendo sobre el viejo).
var biome_blend: float = 1.0
## Los puestos de la cuadrilla; solo se ven los ocupados (set_crew).
var miner_sprites: Array[TextureRect] = []
var drill_sprite: TextureRect
var golem_sprite: TextureRect

## "Reducir efectos" (lo fija main.gd desde Settings): sin sacudida ni vibración, y la mitad de partículas.
var reduce_effects: bool = false:
	set(value):
		reduce_effects = value
		_apply_particle_amounts()
## Azar de los efectos (si salen gemas). Los tests le fijan la semilla.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Cuánto está corrida ahora la mina por la sacudida (px de pantalla); cero en reposo. La roca, la
## cuadrilla y el piso se dibujan corridos; la mina en sí (y el HUD) no se mueven.
var shake_offset: Vector2 = Vector2.ZERO:
	set(value):
		shake_offset = value
		_apply_shake()
## Quién hace vibrar (en la web espera al primer toque completo). Los tests lo reemplazan.
var platform: WebPlatform = WebPlatform.new()
## Cuántas veces vibró (para los tests: en la PC vibrar no hace nada visible).
var vibrations: int = 0
## Cuántas tandas de gemas salieron (para los tests).
var gem_bursts: int = 0
## Cuántas veces explotó la dinamita (para los tests).
var explosions: int = 0
## Cuántos cofres cayeron (para los tests).
var chests_dropped: int = 0

var _rock: TextureRect
var _tap_button: Button
var _backdrop_texture: Texture2D
## El piso del bioma anterior mientras dura el fundido.
var _old_backdrop_texture: Texture2D
var _old_backdrop_color: Color = Color.BLACK
var _biome_tween: Tween
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
## Reloj de las animaciones en loop (picos, runas): segundos de juego desde que arrancó la mina.
var _anim_time: float = 0.0
var _chip_emitters: Array[CPUParticles2D] = []
var _gem_emitters: Array[CPUParticles2D] = []
var _next_chip: int = 0
## Cuadrillas de dinamita y excavadoras rúnicas compradas (set_machines) y el reloj de la próxima explosión.
var _dynamite_count: int = 0
var _excavator_count: int = 0
var _dynamite_clock: float = 0.0
## Las runas que orbitan (fijas: se muestran las que hagan falta) y sus auras.
var _orbit_runes: Array[TextureRect] = []
var _orbit_glows: Array[TextureRect] = []
## El pico de cada minero y para qué lado lo usa (1 = la roca está a su derecha, -1 = a su izquierda).
var _picks: Array[TextureRect] = []
var _pick_sides: Array[float] = []
## Ya se mostró la cuadrilla una vez: desde ahora, lo que aparece aparece animado.
var _crew_shown: bool = false
var _next_gem: int = 0


func _ready() -> void:
	_rock = get_node("Rock") as TextureRect
	_tap_button = get_node("TapButton") as Button
	var pick_texture: Texture2D = load(SPRITE_DIR + "pick.png") as Texture2D
	for index: int in range(MINER_COUNT):
		var miner: TextureRect = _make_sprite("miner_%d.png" % (index + 1), "Miner%d" % (index + 1))
		miner_sprites.append(miner)
		var pick: TextureRect = TextureRect.new()
		pick.name = "Pick"
		pick.texture = pick_texture
		pick.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pick.stretch_mode = TextureRect.STRETCH_SCALE
		pick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		miner.add_child(pick)
		_picks.append(pick)
		_pick_sides.append(1.0)
	drill_sprite = _make_sprite("drill.png", "Drill")
	golem_sprite = _make_sprite("golem.png", "Golem")
	_fx = Control.new()
	_fx.name = "FxLayer"
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.clip_contents = true
	add_child(_fx)
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var gem_texture: Texture2D = load(SPRITE_DIR + "gem.png") as Texture2D
	for index: int in range(CHIP_EMITTERS):
		_chip_emitters.append(_make_emitter("Chips%d" % index, null, true))
	for index: int in range(GEM_EMITTERS):
		_gem_emitters.append(_make_emitter("Gems%d" % index, gem_texture, false))
	_apply_particle_amounts()
	for index: int in range(ORBIT_RUNES_MAX):
		_make_orbit_rune(index)
	show_biome(DEFAULT_BIOME)
	_layout()


# --- Golpe -------------------------------------------------------------------

## Lo que se ve y se siente al golpear: la roca se aplasta, la mina se sacude, sale `text` flotando y el
## celular vibra. Con reduce_effects no hay sacudida ni vibración (el número y el aplastado quedan).
func play_hit(text: String) -> void:
	_squash_rock()
	_burst_particles()
	_spawn_floater(text)
	if reduce_effects:
		return
	_shake()
	vibrations += 1
	platform.vibrate(VIBRATION_MS)


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


# --- Cambio de bioma ---------------------------------------------------------

## Guarda el piso y la roca de ahora para fundirlos con los del bioma nuevo.
func _start_biome_fade() -> void:
	_finish_biome_fade()
	_old_backdrop_texture = _backdrop_texture
	_old_backdrop_color = backdrop_color
	var old_rock: TextureRect = TextureRect.new()
	old_rock.name = "OldRock"
	old_rock.texture = _rock.texture
	old_rock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	old_rock.stretch_mode = TextureRect.STRETCH_SCALE
	old_rock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rock.add_child(old_rock)
	old_rock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	biome_blend = 0.0
	_biome_tween = create_tween()
	_biome_tween.tween_method(_set_biome_blend, 0.0, 1.0, BIOME_FADE_TIME).set_trans(Tween.TRANS_SINE)
	_biome_tween.tween_callback(_finish_biome_fade)


func _set_biome_blend(value: float) -> void:
	biome_blend = value
	var old_rock: TextureRect = _rock.get_node_or_null("OldRock") as TextureRect
	if old_rock != null:
		old_rock.modulate.a = 1.0 - value
	queue_redraw()


func _finish_biome_fade() -> void:
	if _biome_tween != null and _biome_tween.is_valid():
		_biome_tween.kill()
	_biome_tween = null
	biome_blend = 1.0
	_old_backdrop_texture = null
	if _rock != null:
		var old_rock: Node = _rock.get_node_or_null("OldRock")
		if old_rock != null:
			_rock.remove_child(old_rock)
			old_rock.queue_free()
	queue_redraw()


## Cartel pasajero (no modal) en el medio de la mina: `title` grande y `subtitle` en `color`. Entra creciendo y
## se va solo; uno nuevo reemplaza al anterior.
func show_banner(title: String, subtitle: String, color: Color) -> void:
	for child: Node in _fx.get_children():
		if str(child.name).begins_with("BiomeBanner"):
			_fx.remove_child(child)
			child.queue_free()
	var banner: VBoxContainer = VBoxContainer.new()
	banner.name = "BiomeBanner"
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_theme_constant_override("separation", 0)
	var title_label: Label = Label.new()
	title_label.theme_type_variation = &"BannerLabel"
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_child(title_label)
	var subtitle_label: Label = Label.new()
	subtitle_label.theme_type_variation = &"HudLabel"
	subtitle_label.text = subtitle
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_color_override("font_color", color)
	banner.add_child(subtitle_label)
	_fx.add_child(banner)
	banner.size = banner.get_combined_minimum_size()
	banner.position = Vector2((size.x - banner.size.x) * 0.5, size.y * BANNER_HEIGHT_SHARE - banner.size.y * 0.5).round()
	Juice.pop_in(banner, banner.size * 0.5)
	var tween: Tween = banner.create_tween()
	tween.tween_interval(BANNER_TIME)
	tween.tween_property(banner, "modulate:a", 0.0, CHEST_FADE_TIME)
	tween.tween_callback(banner.queue_free)


# --- Cofre -------------------------------------------------------------------

## Un cofre (`texture`) cae sobre la roca con un brillo y estrellas de `color`. `special` (legendario): más
## grande, más brillo y más estrellas.
func drop_chest(texture: Texture2D, color: Color, special: bool) -> void:
	var alive: Array[Node] = []
	for child: Node in _fx.get_children():
		if child.has_meta(&"chest") and not child.is_queued_for_deletion():
			alive.append(child)
	while alive.size() >= MAX_CHESTS:
		alive.pop_front().queue_free()
	chests_dropped += 1
	var chest: TextureRect = TextureRect.new()
	chest.set_meta(&"chest", true)
	chest.texture = texture
	chest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chest.stretch_mode = TextureRect.STRETCH_SCALE
	chest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pixel: float = maxf(roundf((CHEST_SCALE + (1 if special else 0)) * _unit), 1.0)
	chest.size = Vector2(16.0, 16.0) * pixel
	var rock_rect: Rect2 = Rect2(_base_positions.get(_rock, _rock.position), _rock.size)
	var x: float = rock_rect.get_center().x + rng.randf_range(-0.15, 0.15) * rock_rect.size.x - chest.size.x * 0.5
	var landing_y: float = rock_rect.position.y - chest.size.y * 0.6
	chest.position = Vector2(x, -chest.size.y).round()
	chest.pivot_offset = chest.size * 0.5
	_add_chest_glow(chest, color, special)
	_add_chest_stars(chest, color, special)
	_fx.add_child(chest)
	var tween: Tween = chest.create_tween()
	tween.tween_property(chest, "position:y", roundf(landing_y), CHEST_FALL_TIME).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_interval(CHEST_STAY_TIME)
	tween.tween_property(chest, "position:y", roundf(landing_y - 40.0 * _unit), CHEST_FADE_TIME).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(chest, "modulate:a", 0.0, CHEST_FADE_TIME)
	tween.tween_callback(chest.queue_free)


func _add_chest_glow(chest: TextureRect, color: Color, special: bool) -> void:
	var glow: TextureRect = TextureRect.new()
	glow.name = "Glow"
	glow.texture = GLOW_TEXTURE
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.show_behind_parent = true
	var additive: CanvasItemMaterial = CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = additive
	glow.modulate = Color(color, 0.95 if special else 0.8)
	glow.size = chest.size * (CHEST_GLOW_SIZE * (1.4 if special else 1.0))
	glow.position = (chest.size - glow.size) * 0.5
	glow.pivot_offset = glow.size * 0.5
	chest.add_child(glow)
	# late despacio: el brillo respira
	var pulse: Tween = glow.create_tween().set_loops()
	pulse.tween_property(glow, "scale", Vector2.ONE * 1.12, 0.45).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(glow, "scale", Vector2.ONE * 0.92, 0.45).set_trans(Tween.TRANS_SINE)


func _add_chest_stars(chest: TextureRect, color: Color, special: bool) -> void:
	var stars: CPUParticles2D = CPUParticles2D.new()
	stars.name = "Stars"
	stars.texture = STAR_TEXTURE
	stars.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var additive: CanvasItemMaterial = CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	stars.material = additive
	stars.amount = 16 if special else 8
	if reduce_effects:
		stars.amount = maxi(stars.amount / 2, 1)
	stars.lifetime = 0.9
	stars.position = chest.size * 0.5
	stars.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	stars.emission_sphere_radius = chest.size.x * 0.7
	stars.direction = Vector2.UP
	stars.spread = 40.0
	stars.gravity = Vector2.ZERO
	stars.initial_velocity_min = 20.0 * _unit
	stars.initial_velocity_max = 60.0 * _unit
	var star_size: float = 48.0 * _unit / float(STAR_TEXTURE.get_width())
	stars.scale_amount_min = star_size * 0.5
	stars.scale_amount_max = star_size
	stars.color = Color(color, 1.0)
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	fade.add_point(0.3, Color.WHITE)
	stars.color_ramp = fade
	stars.emitting = true
	chest.add_child(stars)


## Aviso arriba de la mina, en una línea: `icon`, `title` en `color` y `detail`. Entra deslizando y se va solo;
## uno nuevo reemplaza al anterior.
func show_toast(icon: Texture2D, title: String, detail: String, color: Color) -> void:
	# El anterior sale del árbol ya mismo (no al final del frame): así el nuevo puede llamarse igual.
	for child: Node in _fx.get_children():
		if str(child.name).begins_with("ChestToast"):
			_fx.remove_child(child)
			child.queue_free()
	var toast: PanelContainer = PanelContainer.new()
	toast.name = "ChestToast"
	toast.theme_type_variation = &"CardPanel"
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBox = toast.get_theme_stylebox("panel", &"CardPanel")
	if style is StyleBoxFlat:
		var bordered: StyleBoxFlat = (style as StyleBoxFlat).duplicate()
		bordered.border_color = color
		bordered.set_border_width_all(4)
		toast.add_theme_stylebox_override("panel", bordered)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.add_child(row)
	var picture: TextureRect = TextureRect.new()
	picture.texture = icon
	picture.custom_minimum_size = Vector2.ONE * TOAST_ICON
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(picture)
	# Una sola línea (ícono, título y bonus): tapa lo menos posible de la mina.
	var texts: HBoxContainer = row
	var title_label: Label = Label.new()
	title_label.theme_type_variation = &"RowNameLabel"
	title_label.text = title
	title_label.add_theme_color_override("font_color", color)
	title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.add_child(title_label)
	var detail_label: Label = Label.new()
	detail_label.theme_type_variation = &"HudLabel"
	detail_label.text = detail
	detail_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.add_child(detail_label)
	_fx.add_child(toast)
	toast.size = toast.get_combined_minimum_size()
	# Centrado en lo que queda libre a la izquierda de los botones del costado, para no quedar debajo.
	var target: Vector2 = Vector2((size.x - SIDE_COLUMN_WIDTH - toast.size.x) * 0.5, TOAST_TOP * _unit).round()
	toast.position = Vector2(target.x, -toast.size.y)
	var tween: Tween = toast.create_tween()
	tween.tween_property(toast, "position:y", target.y, TOAST_SLIDE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(TOAST_TIME)
	tween.tween_property(toast, "modulate:a", 0.0, CHEST_FADE_TIME)
	tween.tween_callback(toast.queue_free)


## Corta todo lo que está en el aire (números, astillas, gemas, sacudida, aplastado): para un cambio de
## escena (volver a la superficie) o una captura limpia.
func clear_effects() -> void:
	for child: Node in _fx.get_children():
		if not (child is CPUParticles2D) and not child.has_meta(PERSISTENT_META):
			child.queue_free()
	_dynamite_clock = 0.0
	# Apagar un emisor no saca las partículas que ya están en el aire: se oculta, y el próximo disparo (_fire) lo
	# reinicia y lo vuelve a mostrar.
	for emitter: CPUParticles2D in _chip_emitters + _gem_emitters:
		emitter.emitting = false
		emitter.visible = false
	for tween: Tween in [_squash_tween, _shake_tween]:
		if tween != null and tween.is_valid():
			tween.kill()
	_rock.scale = Vector2.ONE
	shake_offset = Vector2.ZERO


## Una tanda de astillas desde la parte de arriba de la roca y, con suerte (GEM_CHANCE), unas gemas.
func _burst_particles() -> void:
	var rock_rect: Rect2 = Rect2(_base_positions.get(_rock, _rock.position), _rock.size)
	var origin: Vector2 = Vector2(rock_rect.get_center().x, rock_rect.position.y + rock_rect.size.y * 0.3)
	var chips: CPUParticles2D = _chip_emitters[_next_chip]
	_next_chip = (_next_chip + 1) % _chip_emitters.size()
	var extents: Vector2 = Vector2(rock_rect.size.x * 0.25, rock_rect.size.y * 0.08)
	_fire(chips, origin, extents, Vector2.UP)
	if rng.randf() < GEM_CHANCE:
		var gems: CPUParticles2D = _gem_emitters[_next_gem]
		_next_gem = (_next_gem + 1) % _gem_emitters.size()
		_fire(gems, origin, extents, Vector2.UP)
		gem_bursts += 1


## Larga la tanda de `emitter` desde un rectángulo centrado en `origin` (medio ancho y medio alto
## `extents`) hacia `direction` (abierta 70° para cada lado).
func _fire(emitter: CPUParticles2D, origin: Vector2, extents: Vector2, direction: Vector2) -> void:
	emitter.position = origin.round()
	emitter.emission_rect_extents = extents
	emitter.direction = direction
	var is_chip: bool = _chip_emitters.has(emitter)
	var pixel_scale: float = (CHIP_SCALE if is_chip else GEM_SCALE) * _unit
	emitter.scale_amount_min = pixel_scale
	emitter.scale_amount_max = pixel_scale
	emitter.initial_velocity_min = 260.0 * _unit
	emitter.initial_velocity_max = 520.0 * _unit
	emitter.gravity = Vector2(0.0, 1500.0 * _unit)
	emitter.restart()
	emitter.emitting = true
	emitter.visible = true


## Un emisor de partículas de una sola tanda: salen todas juntas hacia arriba (abiertas), giran y caen.
## Las astillas usan la hoja de 2x2 dibujos (`sheet` = true): a cada una le toca un dibujo al azar.
func _make_emitter(node_name: String, texture: Texture2D, sheet: bool) -> CPUParticles2D:
	var emitter: CPUParticles2D = CPUParticles2D.new()
	emitter.name = node_name
	emitter.texture = texture
	emitter.emitting = false
	emitter.one_shot = true
	emitter.explosiveness = 1.0
	emitter.lifetime = CHIP_LIFETIME if sheet else CHIP_LIFETIME * 1.3
	emitter.local_coords = false
	emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	emitter.direction = Vector2(0.0, -1.0)
	emitter.spread = 70.0
	emitter.angular_velocity_min = -540.0
	emitter.angular_velocity_max = 540.0
	if sheet:
		var material: CanvasItemMaterial = CanvasItemMaterial.new()
		material.particles_animation = true
		material.particles_anim_h_frames = 2
		material.particles_anim_v_frames = 2
		emitter.material = material
		emitter.anim_offset_max = 1.0
	# se apagan al final de su vida en vez de desaparecer de golpe
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	fade.add_point(0.7, Color.WHITE)
	emitter.color_ramp = fade
	_fx.add_child(emitter)
	return emitter


func _apply_particle_amounts() -> void:
	for emitter: CPUParticles2D in _chip_emitters:
		emitter.amount = CHIP_AMOUNT / 2 if reduce_effects else CHIP_AMOUNT
	for emitter: CPUParticles2D in _gem_emitters:
		emitter.amount = maxi(GEM_AMOUNT / 2, 1) if reduce_effects else GEM_AMOUNT


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


## Las máquinas que no tienen sprite propio se ven por lo que hacen: la dinamita explota en el borde de la
## roca y las excavadoras rúnicas hacen orbitar runas.
func set_machines(dynamite: int, excavators: int) -> void:
	_dynamite_count = maxi(dynamite, 0)
	_excavator_count = maxi(excavators, 0)


## Cada cuántos segundos explota un cartucho con `count` cuadrillas de dinamita (INF = nunca).
func dynamite_interval(count: int) -> float:
	if count <= 0:
		return INF
	return maxf(DYNAMITE_MIN_INTERVAL, DYNAMITE_BASE_INTERVAL / sqrt(float(count)))


## Aparece un cartucho en el borde de la roca (arriba o a los costados, donde se ve) y se le prende la mecha.
func _light_fuse() -> void:
	var rock_rect: Rect2 = Rect2(_base_positions.get(_rock, _rock.position), _rock.size)
	var angle: float = rng.randf_range(-PI * 1.1, PI * 0.1)
	var at: Vector2 = rock_rect.get_center() + Vector2(cos(angle) * rock_rect.size.x * 0.44, sin(angle) * rock_rect.size.y * 0.4)
	var stick: TextureRect = TextureRect.new()
	stick.texture = load(SPRITE_DIR + "dynamite.png") as Texture2D
	stick.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stick.stretch_mode = TextureRect.STRETCH_SCALE
	stick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pixel: float = maxf(roundf(DYNAMITE_SCALE * _unit), 1.0)
	stick.size = Vector2(16.0, 16.0) * pixel
	stick.position = (at - stick.size * 0.5).round()
	_fx.add_child(stick)
	Juice.pop_in(stick, stick.size * 0.5)
	var fuse: Tween = stick.create_tween()
	fuse.tween_interval(DYNAMITE_FUSE)
	fuse.tween_callback(_blast.bind(stick, at))


func _blast(stick: TextureRect, at: Vector2) -> void:
	stick.queue_free()
	explosions += 1
	var rock_center: Vector2 = Rect2(_base_positions.get(_rock, _rock.position), _rock.size).get_center()
	var chips: CPUParticles2D = _chip_emitters[_next_chip]
	_next_chip = (_next_chip + 1) % _chip_emitters.size()
	_fire(chips, at, Vector2(12.0, 12.0) * _unit, (at - rock_center).normalized())
	if not reduce_effects:
		_flash_glow(at)
	dynamite_exploded.emit(at)


## Destello de la explosión: un brillo suave (Particle Pack) que se abre y se apaga, sumando luz.
func _flash_glow(at: Vector2) -> void:
	var glow: TextureRect = TextureRect.new()
	glow.texture = GLOW_TEXTURE
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var additive: CanvasItemMaterial = CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = additive
	glow.modulate = BLAST_COLOR
	glow.size = Vector2.ONE * BLAST_SIZE * _unit
	glow.position = at - glow.size * 0.5
	glow.pivot_offset = glow.size * 0.5
	glow.scale = Vector2(0.3, 0.3)
	_fx.add_child(glow)
	var tween: Tween = glow.create_tween().set_parallel(true)
	tween.tween_property(glow, "scale", Vector2.ONE, BLAST_TIME * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(glow, "modulate:a", 0.0, BLAST_TIME).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(glow.queue_free)


func _process(delta: float) -> void:
	if _dynamite_count > 0 and is_visible_in_tree():
		_dynamite_clock += delta
		if _dynamite_clock >= dynamite_interval(_dynamite_count):
			_dynamite_clock = 0.0
			_light_fuse()
	else:
		_dynamite_clock = 0.0
	# Tiempo de juego (respeta Engine.time_scale: la pausa del legendario los frena y los tests los aceleran).
	_anim_time += delta
	var now: float = _anim_time
	_move_orbit_runes(now)
	for index: int in range(_picks.size()):
		if not miner_sprites[index].visible:
			continue
		# Fases repartidas con la razón áurea y períodos apenas distintos: nunca se sincronizan.
		var period: float = SWING_PERIOD * (1.0 + 0.08 * float(index % 3 - 1))
		var progress: float = fposmod(now / period + index * 0.618, 1.0)
		_picks[index].rotation = pick_angle(progress) * _pick_sides[index]


## Una runa de la órbita: un glifo de la hoja runes_<bioma>.png (cuarto index % 4) con un aura detrás.
func _make_orbit_rune(index: int) -> void:
	var rune: TextureRect = TextureRect.new()
	rune.name = "OrbitRune%d" % index
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.region = Rect2((index % 2) * 8, ((index / 2) % 2) * 8, 8, 8)
	rune.texture = atlas
	rune.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rune.stretch_mode = TextureRect.STRETCH_SCALE
	rune.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rune.visible = false
	rune.set_meta(PERSISTENT_META, true)
	var glow: TextureRect = TextureRect.new()
	glow.name = "Aura"
	glow.texture = GLOW_TEXTURE
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.show_behind_parent = true
	var additive: CanvasItemMaterial = CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = additive
	rune.add_child(glow)
	_fx.add_child(rune)
	_orbit_runes.append(rune)
	_orbit_glows.append(glow)


## Muestra una runa por excavadora (hasta el tope), repartidas en la órbita y girando.
func _move_orbit_runes(now: float) -> void:
	var shown: int = mini(_excavator_count, _orbit_runes.size())
	var rock_rect: Rect2 = Rect2(_base_positions.get(_rock, _rock.position), _rock.size)
	var pixel: float = maxf(roundf(ORBIT_SCALE * _unit), 1.0)
	var rune_size: Vector2 = Vector2(8.0, 8.0) * pixel
	for index: int in range(_orbit_runes.size()):
		var rune: TextureRect = _orbit_runes[index]
		rune.visible = index < shown
		if not rune.visible:
			continue
		var angle: float = now * ORBIT_SPEED + index * TAU / shown
		var center: Vector2 = rock_rect.get_center() + Vector2(cos(angle), sin(angle)) * rock_rect.size * ORBIT_RADIUS
		center.y += sin(now * 3.0 + index) * ORBIT_BOB * _unit
		# adelante (abajo en la elipse) = entera; atrás (arriba) = más chica y apagada
		var front: float = (sin(angle) + 1.0) * 0.5
		rune.size = rune_size
		rune.pivot_offset = rune_size * 0.5
		rune.scale = Vector2.ONE * lerpf(ORBIT_BACK_SCALE, 1.0, front)
		rune.modulate.a = lerpf(ORBIT_BACK_ALPHA, 1.0, front)
		rune.position = (center - rune_size * 0.5).round()
		var glow: TextureRect = _orbit_glows[index]
		glow.size = rune_size * ORBIT_GLOW_SIZE
		glow.position = (rune_size - glow.size) * 0.5


## Ángulo del pico (radianes, positivo = hacia la roca) en el momento `progress` (0 a 1) de un golpe.
func pick_angle(progress: float) -> float:
	var p: float = clampf(progress, 0.0, 1.0)
	if p <= SWING_RAISE_END:
		return SWING_RAISED * smoothstep(0.0, 1.0, p / SWING_RAISE_END)
	if p <= SWING_STRIKE_END:
		var t: float = (p - SWING_RAISE_END) / (SWING_STRIKE_END - SWING_RAISE_END)
		return lerpf(SWING_RAISED, SWING_STRIKE, t * t)
	return lerpf(SWING_STRIKE, 0.0, smoothstep(0.0, 1.0, (p - SWING_STRIKE_END) / (1.0 - SWING_STRIKE_END)))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


## Cambia el piso y la roca por los del bioma `id` (uno desconocido usa los de Tierra). Con `animate`, los nuevos
## se funden sobre los viejos (bajar a un bioma nuevo); si no, el cambio es inmediato (abrir el juego, volver a
## la superficie).
func show_biome(id: String, animate: bool = false) -> void:
	var known: String = id if BiomePalette.BY_ID.has(id) else DEFAULT_BIOME
	if known == biome_id:
		return
	var had_biome: bool = biome_id != ""
	if animate and had_biome and _rock != null:
		_start_biome_fade()
	else:
		_finish_biome_fade()
	biome_id = known
	backdrop_color = BiomePalette.of(known)["bg"]
	if _rock != null:
		_rock.texture = load(SPRITE_DIR + "rock_%s.png" % known) as Texture2D
	_backdrop_texture =load(SPRITE_DIR + "bg_%s.png" % known) as Texture2D
	var chips: Texture2D = load(SPRITE_DIR + "chips_%s.png" % known) as Texture2D
	for emitter: CPUParticles2D in _chip_emitters:
		emitter.texture = chips
	var runes: Texture2D = load(SPRITE_DIR + "runes_%s.png" % known) as Texture2D
	var rune_color: Color = BiomePalette.of(known)["rune"]
	for index: int in range(_orbit_runes.size()):
		(_orbit_runes[index].texture as AtlasTexture).atlas = runes
		_orbit_glows[index].modulate = Color(rune_color, ORBIT_GLOW_ALPHA)
	queue_redraw()


## Muestra `miners` mineros (hasta MINER_COUNT) y, si se compraron, el taladro y el gólem.
## Lo que aparece después de la primera vez (una compra) crece desde los pies; la primera vez (abrir el
## juego con una partida guardada) se muestra quieto.
func set_crew(miners: int, has_drill: bool, has_golem: bool) -> void:
	for index: int in range(miner_sprites.size()):
		_show_member(miner_sprites[index], index < miners)
	_show_member(drill_sprite, has_drill)
	_show_member(golem_sprite, has_golem)
	_crew_shown = true
	queue_redraw()


func _show_member(sprite: TextureRect, show: bool) -> void:
	var appears: bool = show and not sprite.visible
	sprite.visible = show
	if appears and _crew_shown:
		Juice.pop_in(sprite, sprite.size * Vector2(0.5, 1.0))


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
	var center: Vector2 = Vector2(size.x * 0.5 + COMPOSITION_SHIFT * unit, size.y * ROCK_HEIGHT_SHARE)
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
	_hold_pick(index, -1.0 if gaze == GAZES[0] else 1.0)


## Le pone el pico en la mano al minero `index`, del lado de la roca (`side` 1 = a su derecha, -1 = a su
## izquierda: el dibujo se espeja). Gira desde donde lo agarra.
func _hold_pick(index: int, side: float) -> void:
	var miner: TextureRect = miner_sprites[index]
	var pick: TextureRect = _picks[index]
	_pick_sides[index] = side
	var pixel: float = maxf(roundf(PICK_SCALE * _unit), 1.0)
	pick.size = Vector2(16.0, 16.0) * pixel
	pick.flip_h = side < 0.0
	var grip: Vector2 = Vector2(16.0 - PICK_GRIP.x if side < 0.0 else PICK_GRIP.x, PICK_GRIP.y) * pixel
	var hand: Vector2 = Vector2(HAND.x if side > 0.0 else 1.0 - HAND.x, HAND.y) * miner.size
	pick.pivot_offset = grip
	pick.position = (hand - grip).round()


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
	# En un cambio de bioma, el piso nuevo se dibuja encima del viejo con opacidad biome_blend.
	if biome_blend < 1.0 and _old_backdrop_texture != null:
		_draw_floor(_old_backdrop_color, _old_backdrop_texture, 1.0)
		_draw_floor(backdrop_color, _backdrop_texture, biome_blend)
	else:
		_draw_floor(backdrop_color, _backdrop_texture, 1.0)
	# sombras a los pies de la roca y de la cuadrilla (se dibujan antes que los sprites: quedan debajo)
	for shadow: Dictionary in shadow_ellipses():
		var radius: Vector2 = shadow["radius"]
		draw_set_transform(shadow["center"], 0.0, Vector2(1.0, radius.y / radius.x))
		draw_circle(Vector2.ZERO, radius.x, SHADOW_COLOR)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## El piso: el color base y encima el mosaico del bioma, mezclado a BACKDROP_STRENGTH, todo con opacidad `alpha`.
## El piso también se sacude: el mosaico se corre con shake_offset (sobra una fila y una columna de cada lado
## para que no se vea el borde).
func _draw_floor(color: Color, texture: Texture2D, alpha: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(color, color.a * alpha))
	if texture == null:
		return
	var tile: int = 16 * BACKDROP_SCALE
	var tint: Color = Color(1.0, 1.0, 1.0, BACKDROP_STRENGTH * alpha)
	for ty: int in range(-1, ceili(size.y / tile) + 1):
		for tx: int in range(-1, ceili(size.x / tile) + 1):
			draw_texture_rect(texture, Rect2(Vector2(tx * tile, ty * tile) + shake_offset, Vector2(tile, tile)), false, tint)
