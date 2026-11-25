extends SceneTree
## Base común de los tests headless: contador de fallos y helpers de aserción.
##
## Un test hereda de esta clase, implementa `_initialize()` y termina con `_finish()`:
##   extends "res://tests/test_base.gd"
##   func _initialize() -> void:
##       _check(1 + 1 == 2, "suma")
##       _finish()
##
## Uso (desde la raíz del proyecto):
##   godot --headless --path . --script res://tests/<nombre>_test.gd
## Sale con código 0 si todo pasa y 1 si algún check falla.

var _failures: int = 0
var _checks: int = 0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if ok:
		print("  ok    ", label)
	else:
		_failures += 1
		printerr("  FALLO ", label)


func _check_eq(actual: Variant, expected: Variant, label: String) -> void:
	_checks += 1
	if actual == expected:
		print("  ok    ", label)
	else:
		_failures += 1
		printerr("  FALLO %s (esperado %s, obtenido %s)" % [label, str(expected), str(actual)])


## Compara floats con tolerancia relativa (útil para costos que crecen exponencialmente).
func _check_near(actual: float, expected: float, label: String, rel_tol: float = 1e-9) -> void:
	_checks += 1
	var tolerance: float = maxf(absf(expected) * rel_tol, 1e-12)
	if absf(actual - expected) <= tolerance:
		print("  ok    ", label)
	else:
		_failures += 1
		printerr("  FALLO %s (esperado %s, obtenido %s)" % [label, str(expected), str(actual)])


func _section(title: String) -> void:
	print(title)


func _finish() -> void:
	# Un sonido que sigue sonando al salir queda retenido por el AudioServer y Godot lo reporta como
	# "resources still in use at exit". Se corta todo y se le da un ciclo de mezcla para soltarlo.
	var audio: Node = root.get_node_or_null("Audio")
	if audio != null and audio.has_method("silence"):
		audio.call("silence")
		# Un OGG que sonaba tarda más de 0,1 s en soltarse. (Los tests lentos ya devolvieron Engine.time_scale a 1.)
		await create_timer(0.3).timeout
	print("")
	if _failures == 0:
		print("OK: %d checks pasaron" % _checks)
		quit(0)
	else:
		printerr("FALLO: %d de %d checks no pasaron" % [_failures, _checks])
		quit(1)
