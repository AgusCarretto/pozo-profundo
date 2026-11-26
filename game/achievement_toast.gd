extends Button
## El aviso de logros: uno solo para todos los que llegan juntos (en la conversión de una partida salen unos 20). Va
## sobre la parte baja de la barra de arriba, se va solo y al tocarlo se abre el librito (lo conecta main.gd). Mientras
## hay un cartel modal adelante, espera.

const Achievements := preload("res://core/achievements.gd")

const SHOW_SECONDS: float = 4.0
const HEIGHT: float = 100.0
const SIDE_MARGIN: float = 16.0
const BOTTOM_MARGIN: float = 8.0

var _hud: Control
## Devuelve true mientras no conviene mostrarlo (hay un cartel adelante).
var _blocked: Callable
## Los logros que cuenta el aviso de ahora.
var _ids: Array[String] = []
var _left: float = 0.0


func _init() -> void:
	name = "AchievementToast"
	visible = false
	focus_mode = Control.FOCUS_NONE
	theme_type_variation = &"ButtonNeutral"
	add_theme_font_size_override("font_size", 28)
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func setup(hud: Control, blocked: Callable) -> void:
	_hud = hud
	_blocked = blocked


## Suma logros recién conseguidos al aviso.
func push(ids: Array) -> void:
	for id: String in ids:
		if not _ids.has(id):
			_ids.append(id)
	if _ids.is_empty():
		return
	_left = SHOW_SECONDS
	_compose()
	_show_if_free()


func dismiss() -> void:
	_ids.clear()
	visible = false


func _process(delta: float) -> void:
	if _ids.is_empty():
		return
	if not visible or (_blocked.is_valid() and _blocked.call()):
		_show_if_free()
		return
	_place()
	_left -= delta
	if _left <= 0.0:
		dismiss()


func _show_if_free() -> void:
	visible = not (_blocked.is_valid() and bool(_blocked.call()))
	if visible:
		_place()


func _compose() -> void:
	var achievements: Achievements = Economy.achievements
	if achievements == null:
		return
	var total: int = 0
	for id: String in _ids:
		total += achievements.fragments_for(id)
	if _ids.size() == 1:
		text = "¡Logro conseguido!\n%s · +%d fragmentos" % [achievements.entry(_ids[0]).get("name", ""), total]
	else:
		text = "¡%d logros nuevos!\n+%d fragmentos · tocá para verlos" % [_ids.size(), total]


func _place() -> void:
	if _hud == null:
		return
	var area: Rect2 = _hud.get_global_rect()
	var origin: Vector2 = (get_parent() as Control).get_global_rect().position
	size = Vector2(area.size.x - SIDE_MARGIN * 2.0, HEIGHT)
	global_position = Vector2(area.position.x + SIDE_MARGIN, maxf(area.end.y - HEIGHT - BOTTOM_MARGIN, origin.y))
