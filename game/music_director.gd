extends Node
## Director de la música: decide qué tema suena y le pide a Audio el cambio con un fundido cruzado.
##
## Por prioridad: la vuelta a la superficie ("prestige"), las Opciones ("options"), el frenesí ("frenzy", cuando
## golpeás rápido un rato) y si no, el tema del bioma (su id del balance). Qué archivo es cada uno lo dice
## data/sounds.json; si un tema no está en el catálogo, suena el siguiente de la lista. Los umbrales del frenesí
## vienen del balance (Economy.frenzy_settings(), ver core/frenzy_meter.gd); los tiempos de los fundidos son
## presentación y viven acá.
##
## main.gd lo crea y le cuenta el bioma (set_biome), las Opciones (set_options_open) y la vuelta a la superficie
## (begin_prestige / end_prestige). Los golpes los escucha de Economy.hit_landed, y las compras (generadores y pico)
## sostienen un frenesí prendido: ir a la tienda no lo corta.

const FrenzyMeter := preload("res://core/frenzy_meter.gd")

## Segundos de cada fundido cruzado, según a qué se entra (o de qué se vuelve al bioma).
const FRENZY_IN_FADE: float = 0.8
const FRENZY_OUT_FADE: float = 2.0
const OPTIONS_FADE: float = 0.6
const PRESTIGE_FADE: float = 0.4
const BIOME_FADE: float = 1.5
## Cuánto sigue el tema del prestigio después de que termina la secuencia, antes de volver al de Tierra.
const PRESTIGE_HOLD: float = 4.0

## Reloj en segundos con el que se mide el ritmo (real: el frenesí es del jugador, no del tiempo de juego, que
## una pausa del legendario frena). Los tests lo reemplazan por uno de prueba.
var clock: Callable = func() -> float: return Time.get_ticks_usec() / 1000000.0
var frenzy: FrenzyMeter = FrenzyMeter.new()
## Mientras corre la secuencia de la vuelta a la superficie (de begin_prestige a end_prestige).
var prestige_running: bool = false

var _biome: String = ""
var _options_open: bool = false
## Hasta cuándo (según `clock`) sigue el tema del prestigio una vez terminada la secuencia; -1 = no sigue.
var _prestige_until: float = -1.0
## El tema que se pidió por última vez ("" = ninguno todavía).
var _playing: String = ""


func _init() -> void:
	name = "MusicDirector"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	frenzy.configure(Economy.frenzy_settings())
	Economy.hit_landed.connect(_on_hit_landed)
	# Ir a comprar no corta el frenesí (sí lo cortan las Opciones y la vuelta a la superficie).
	Economy.generator_bought.connect(_on_bought.unbind(2))
	Economy.pick_upgraded.connect(_on_bought.unbind(1))


func _process(_delta: float) -> void:
	update()


func set_biome(id: String) -> void:
	_biome = id
	update()


## Abrir Opciones corta el frenesí: al cerrarlas se vuelve al bioma.
func set_options_open(open: bool) -> void:
	_options_open = open
	if open:
		frenzy.reset()
	update()


func begin_prestige() -> void:
	prestige_running = true
	_prestige_until = -1.0
	frenzy.reset()
	update()


func end_prestige() -> void:
	prestige_running = false
	_prestige_until = clock.call() + PRESTIGE_HOLD
	update()


## Qué tema corresponde ahora, de más a menos prioritario entre los que hay en el catálogo.
func wanted() -> String:
	var now: float = clock.call()
	var candidates: Array[String] = []
	if prestige_running or now < _prestige_until:
		candidates.append("prestige")
	if _options_open:
		candidates.append("options")
	if frenzy.active:
		candidates.append("frenzy")
	candidates.append(_biome)
	for id: String in candidates:
		if Audio.has_music(id):
			return id
	return ""


## Recalcula el frenesí y, si corresponde otro tema, lo pide. Corre cada frame; los tests lo llaman a mano.
func update() -> void:
	var now: float = clock.call()
	frenzy.update(now)
	if _prestige_until >= 0.0 and now >= _prestige_until:
		_prestige_until = -1.0
	var next: String = wanted()
	if next == _playing or next == "":
		return
	var previous: String = _playing
	_playing = next
	match next:
		"prestige":
			Audio.play_music(next, PRESTIGE_FADE, true)
		"options":
			Audio.play_music(next, OPTIONS_FADE)
		"frenzy":
			# Desde el principio: arranca con su subida.
			Audio.play_music(next, FRENZY_IN_FADE, true)
		_:
			match previous:
				"prestige":
					# Una partida nueva: el tema de Tierra desde el principio.
					Audio.play_music(next, BIOME_FADE, true)
				"frenzy":
					Audio.play_music(next, FRENZY_OUT_FADE)
				"options":
					Audio.play_music(next, OPTIONS_FADE)
				_:
					Audio.play_music(next, BIOME_FADE)


func _on_hit_landed(_amount: float) -> void:
	frenzy.hit(clock.call())


func _on_bought() -> void:
	frenzy.hold(clock.call())
