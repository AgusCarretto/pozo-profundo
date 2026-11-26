extends RefCounted
## Tope de toques que cuentan: como mucho `max_hits` en los últimos `window_seconds` (ventana deslizante). No exige
## separación entre toques: dos pulgares casi juntos entran los dos.
##
## Código reutilizable entre juegos: no lee el reloj (cada llamada recibe el segundo actual).

var _max_hits: int = 0
var _window: float = 0.0
## Segundos de los toques aceptados dentro de la ventana, del más viejo al más nuevo.
var _hits: Array[float] = []


## {max_hits, window_seconds}; sin esos datos no hay tope.
func configure(settings: Dictionary) -> void:
	_max_hits = int(settings.get("max_hits", 0))
	_window = float(settings.get("window_seconds", 0.0))
	reset()


func reset() -> void:
	_hits.clear()


## true si el toque del segundo `now` cuenta (y lo anota).
func allow(now: float) -> bool:
	if _max_hits <= 0 or _window <= 0.0:
		return true
	while not _hits.is_empty() and _hits[0] <= now - _window:
		_hits.pop_front()
	if _hits.size() >= _max_hits:
		return false
	_hits.append(now)
	return true
