extends "res://tests/test_base.gd"
## core/tap_limiter.gd: como mucho N golpes en la última ventana de tiempo (ventana deslizante, no separación mínima).

const TapLimiter := preload("res://core/tap_limiter.gd")


func _initialize() -> void:
	_test_sliding_window()
	_test_irregular_but_steady_taps_are_all_counted()
	_test_without_settings_everything_counts()
	_finish()


func _test_sliding_window() -> void:
	_section("Ventana deslizante: 6 en el último segundo")
	var limiter: TapLimiter = TapLimiter.new()
	limiter.configure({ "max_hits": 6, "window_seconds": 1 })
	for i: int in range(6):
		_check(limiter.allow(10.0 + i * 0.001), "el golpe %d entra aunque vengan juntos" % (i + 1))
	_check(not limiter.allow(10.5), "el 7.º dentro del segundo no entra")
	_check(not limiter.allow(10.999), "ni justo antes de que se cumpla el segundo")
	_check(limiter.allow(11.001), "al salir de la ventana los dos primeros entra otro")
	_check(limiter.allow(11.0011), "y otro más")
	_check(not limiter.allow(11.0015), "pero solo los que se liberaron (2)")
	limiter.reset()
	_check(limiter.allow(11.002), "reset() olvida todo")


func _test_irregular_but_steady_taps_are_all_counted() -> void:
	_section("Quien golpea a 4,5/s, irregular, casi no pierde golpes")
	var limiter: TapLimiter = TapLimiter.new()
	limiter.configure({ "max_hits": 6, "window_seconds": 1 })
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 7
	var now: float = 0.0
	var rejected: int = 0
	for i: int in range(2000):
		now += random.randf_range(0.6, 1.4) / 4.5
		if not limiter.allow(now):
			rejected += 1
	# Alguna ráfaga puede juntar 7 en un segundo; exigiendo 1/6 s entre golpes se perdería uno de cada seis.
	_check(rejected < 20, "menos del 1%% rechazado (%d de 2000)" % rejected)


func _test_without_settings_everything_counts() -> void:
	_section("Sin configuración no hay tope")
	var limiter: TapLimiter = TapLimiter.new()
	limiter.configure({})
	var all: bool = true
	for i: int in range(100):
		all = all and limiter.allow(1.0)
	_check(all, "100 golpes en el mismo instante entran todos")
