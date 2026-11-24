extends RefCounted
## Efectos chicos de la interfaz que se reusan en varios lugares.
##
## Todos usan escala con pivote (no tamaño ni posición): no cambian el layout, así que se pueden usar con
## controles que viven dentro de contenedores.

## Un botón tocado se hunde un poco y vuelve con un rebote.
const BOUNCE_SQUEEZE: Vector2 = Vector2(0.88, 0.88)
const BOUNCE_IN_TIME: float = 0.06
const BOUNCE_OUT_TIME: float = 0.24
## Algo que aparece (un minero nuevo) crece desde `pivot` con un rebote.
const POP_START: Vector2 = Vector2(0.2, 0.2)
const POP_TIME: float = 0.38

const _TWEEN_META: StringName = &"juice_tween"


## El control se hunde desde su centro y vuelve a su tamaño con un rebote.
static func bounce(control: Control) -> void:
	control.pivot_offset = control.size * 0.5
	var tween: Tween = _restart(control)
	tween.tween_property(control, "scale", BOUNCE_SQUEEZE, BOUNCE_IN_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, BOUNCE_OUT_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## El control aparece creciendo desde `pivot` (en coordenadas del control: los pies de un minero).
static func pop_in(control: Control, pivot: Vector2) -> void:
	control.pivot_offset = pivot
	control.scale = POP_START
	var tween: Tween = _restart(control)
	tween.tween_property(control, "scale", Vector2.ONE, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Corta el efecto que el control tuviera a medias y arranca uno nuevo (dos rebotes no se pelean).
static func _restart(control: Control) -> Tween:
	if control.has_meta(_TWEEN_META):
		var previous: Tween = control.get_meta(_TWEEN_META) as Tween
		if previous != null and previous.is_valid():
			previous.kill()
	var tween: Tween = control.create_tween()
	control.set_meta(_TWEEN_META, tween)
	return tween
