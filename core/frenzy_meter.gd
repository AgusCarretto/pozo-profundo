extends RefCounted
## Medidor de frenesí: dice cuándo el jugador sostiene un ritmo alto de golpes.
##
## Código reutilizable entre juegos: no depende de nada de res://game/ ni lee el reloj (cada llamada recibe el
## segundo actual, así se puede probar sin esperar). Los umbrales vienen del balance (sección "frenzy"):
##   hits_per_second  ritmo "alto": golpes por segundo, contados en el último window_seconds.
##   enter_seconds    cuánto tiempo seguido de ritmo alto hace falta para prenderse.
##   exit_seconds     cuánto tiempo seguido sin ritmo alto hace falta para apagarse.
##   window_seconds   ventana en la que se cuentan los golpes.
## Sin umbrales (configure({})) nunca se prende.

## Si el frenesí está prendido (se actualiza en update()).
var active: bool:
	get:
		return _active

var _hits_per_second: float = 0.0
var _enter_seconds: float = 0.0
var _exit_seconds: float = 0.0
var _window_seconds: float = 0.0
## Segundos de los golpes dentro de la ventana, del más viejo al más nuevo.
var _hits: Array[float] = []
var _active: bool = false
## Desde cuándo el ritmo es alto (prendiéndose) o bajo (apagándose); -1 = no se está contando.
var _high_since: float = -1.0
var _low_since: float = -1.0


## Toma los umbrales (el diccionario de Economy.frenzy_settings()) y arranca apagado.
func configure(settings: Dictionary) -> void:
	_hits_per_second = float(settings.get("hits_per_second", 0.0))
	_enter_seconds = float(settings.get("enter_seconds", 0.0))
	_exit_seconds = float(settings.get("exit_seconds", 0.0))
	_window_seconds = float(settings.get("window_seconds", 0.0))
	reset()


func enabled() -> bool:
	return _hits_per_second > 0.0 and _window_seconds > 0.0


## Apaga el frenesí y olvida los golpes.
func reset() -> void:
	_hits.clear()
	_active = false
	_high_since = -1.0
	_low_since = -1.0


## Anota un golpe en el segundo `now`.
func hit(now: float) -> void:
	if enabled():
		_hits.append(now)


## Golpes por segundo en la ventana que termina en `now`.
func rate(now: float) -> float:
	if not enabled():
		return 0.0
	_forget_before(now - _window_seconds)
	return _hits.size() / _window_seconds


## Recalcula si está prendido en el segundo `now` (llamarlo seguido, por ejemplo cada frame) y lo devuelve.
func update(now: float) -> bool:
	if not enabled():
		return false
	var high: bool = rate(now) >= _hits_per_second
	if not _active:
		_low_since = -1.0
		if not high:
			_high_since = -1.0
		elif _high_since < 0.0:
			_high_since = now
		if high and now - _high_since >= _enter_seconds:
			_active = true
	else:
		_high_since = -1.0
		if high:
			_low_since = -1.0
		elif _low_since < 0.0:
			_low_since = now
		if not high and now - _low_since >= _exit_seconds:
			_active = false
	return _active


## Olvida los golpes en `since` o antes (la ventana es (now - window, now]).
func _forget_before(since: float) -> void:
	var drop: int = 0
	while drop < _hits.size() and _hits[drop] <= since:
		drop += 1
	if drop > 0:
		_hits = _hits.slice(drop)
