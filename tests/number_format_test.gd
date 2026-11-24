extends "res://tests/test_base.gd"
## Tests headless del formato de números con sufijos (core/number_format.gd).

const NumberFormat := preload("res://core/number_format.gd")


func _initialize() -> void:
	_test_small_numbers()
	_test_amount_vs_cost_rounding()
	_test_suffixes()
	_test_rollover_between_bands()
	_test_scientific_notation()
	_test_special_values()
	_test_never_shows_four_digits()
	_test_percent()
	_test_duration()
	_finish()


func _test_percent() -> void:
	_section("Porcentajes (probabilidades y bonus)")
	_check_eq(NumberFormat.format_percent(0.70), "70%", "0.70 -> 70%")
	_check_eq(NumberFormat.format_percent(0.22), "22%", "0.22 -> 22% (sin el 22.000000000000004 del float)")
	_check_eq(NumberFormat.format_percent(0.07), "7%", "0.07 -> 7%")
	_check_eq(NumberFormat.format_percent(0.01), "1%", "0.01 -> 1%")
	_check_eq(NumberFormat.format_percent(0.60), "60%", "0.60 -> 60%")
	_check_eq(NumberFormat.format_percent(0.29), "29%", "0.29 -> 29% (29 * 100 da 28.999999999999996)")
	_check_eq(NumberFormat.format_percent(0.125), "12.5%", "0.125 -> 12.5% (un decimal si hace falta)")
	_check_eq(NumberFormat.format_percent(0.0033), "0.3%", "0.0033 -> 0.3%")
	_check_eq(NumberFormat.format_percent(0.0), "0%", "0 -> 0%")
	_check_eq(NumberFormat.format_percent(1.0), "100%", "1 -> 100%")
	_check_eq(NumberFormat.format_percent(12.5), "1250%", "12.5 -> 1250%")
	_check_eq(NumberFormat.format_percent(-0.05), "-5%", "negativo -> -5%")
	_check_eq(NumberFormat.format_percent(NAN), "NaN%", "NaN no explota")
	_check(NumberFormat.format_percent(1.0e30).ends_with("%"), "un valor enorme sigue terminando en %% (%s)" % NumberFormat.format_percent(1.0e30))


## Duración de una ausencia, para el aviso offline.
func _test_duration() -> void:
	_section("Duraciones")
	_check_eq(NumberFormat.format_duration(0.0), "0 s", "0 -> 0 s")
	_check_eq(NumberFormat.format_duration(45.0), "45 s", "45 s")
	_check_eq(NumberFormat.format_duration(59.9), "59 s", "59.9 s se trunca a 59 s")
	_check_eq(NumberFormat.format_duration(60.0), "1 min", "60 s -> 1 min")
	_check_eq(NumberFormat.format_duration(119.0), "1 min", "119 s -> 1 min")
	_check_eq(NumberFormat.format_duration(1800.0), "30 min", "30 min")
	_check_eq(NumberFormat.format_duration(3599.0), "59 min", "3599 s -> 59 min")
	_check_eq(NumberFormat.format_duration(3600.0), "1 h", "1 h exacta -> 1 h")
	_check_eq(NumberFormat.format_duration(3660.0), "1 h 1 min", "1 h 1 min")
	_check_eq(NumberFormat.format_duration(11520.0), "3 h 12 min", "3 h 12 min")
	_check_eq(NumberFormat.format_duration(28800.0), "8 h", "8 h (el tope offline)")
	_check_eq(NumberFormat.format_duration(90000.0), "25 h", "más de un día se cuenta en horas")
	_check_eq(NumberFormat.format_duration(-5.0), "0 s", "negativo -> 0 s")
	_check_eq(NumberFormat.format_duration(NAN), "0 s", "NaN -> 0 s")


func _test_small_numbers() -> void:
	_section("Números chicos (< 1000)")
	_check_eq(NumberFormat.format_number(0.0), "0", "0")
	_check_eq(NumberFormat.format_number(1.0), "1", "1")
	_check_eq(NumberFormat.format_number(15.0), "15", "15")
	_check_eq(NumberFormat.format_number(999.0), "999", "999")
	_check_eq(NumberFormat.format_number(-0.0), "0", "cero negativo se muestra como 0")


## El oro se trunca y el costo se redondea hacia arriba: si el cartel dice que cuesta 15
## y el oro dice 15, tiene que alcanzar. Nunca "me alcanza" con un botón deshabilitado.
func _test_amount_vs_cost_rounding() -> void:
	_section("Oro (trunca) vs costo (redondea hacia arriba)")
	_check_eq(NumberFormat.format_number(14.99), "14", "oro 14.99 se muestra 14")
	_check_eq(NumberFormat.format_cost(14.01), "15", "costo 14.01 se muestra 15")
	_check_eq(NumberFormat.format_cost(15.0), "15", "costo exacto 15 se muestra 15")
	_check_eq(NumberFormat.format_cost(22.813125), "23", "costo 22.81 se muestra 23")
	_check_eq(NumberFormat.format_number(999.99), "999", "oro 999.99 se muestra 999 (no pasa a 1.00K)")
	_check_eq(NumberFormat.format_cost(999.2), "1.00K", "costo 999.2 sube a 1.00K")
	_check_eq(NumberFormat.format_cost(0.0), "0", "costo 0 se muestra 0")


func _test_suffixes() -> void:
	_section("Sufijos")
	_check_eq(NumberFormat.format_number(1000.0), "1.00K", "1000 -> 1.00K")
	_check_eq(NumberFormat.format_number(1234.0), "1.23K", "1234 -> 1.23K")
	_check_eq(NumberFormat.format_number(12345.0), "12.3K", "12345 -> 12.3K")
	_check_eq(NumberFormat.format_number(123456.0), "123K", "123456 -> 123K")
	_check_eq(NumberFormat.format_number(1.0e6), "1.00M", "1e6 -> 1.00M")
	_check_eq(NumberFormat.format_number(1.5e9), "1.50B", "1.5e9 -> 1.50B")
	_check_eq(NumberFormat.format_number(2.5e12), "2.50T", "2.5e12 -> 2.50T")
	_check_eq(NumberFormat.format_number(1.0e15), "1.00Qa", "1e15 -> 1.00Qa")
	_check_eq(NumberFormat.format_number(1.0e18), "1.00Qi", "1e18 -> 1.00Qi")
	_check_eq(NumberFormat.format_number(1.0e33), "1.00Dc", "1e33 -> 1.00Dc (último sufijo)")
	_check_eq(NumberFormat.format_cost(1234.0), "1.23K", "los costos grandes también llevan sufijo")


## El redondeo a 3 cifras no puede producir "1000K" ni "10.00K": al redondear se salta
## de banda de decimales o de sufijo.
func _test_rollover_between_bands() -> void:
	_section("Redondeo en los bordes de banda")
	_check_eq(NumberFormat.format_number(9999.0), "10.0K", "9999 -> 10.0K (no 10.00K)")
	_check_eq(NumberFormat.format_number(99999.0), "100K", "99999 -> 100K (no 100.0K)")
	_check_eq(NumberFormat.format_number(999999.0), "1.00M", "999999 -> 1.00M (no 1000K)")
	_check_eq(NumberFormat.format_number(999499.0), "999K", "999499 -> 999K")
	_check_eq(NumberFormat.format_number(999500.0), "1.00M", "999500 -> 1.00M")
	_check_eq(NumberFormat.format_number(9.999e32), "1.00Dc", "999.9 No redondea a 1.00Dc (salta de sufijo)")
	_check_eq(NumberFormat.format_number(9.999e35), "1.00e36", "999.9 Dc redondea a 1000 Dc: no hay más sufijos, pasa a científica")


func _test_scientific_notation() -> void:
	_section("Notación científica más allá del último sufijo")
	_check_eq(NumberFormat.format_number(1.0e36), "1.00e36", "1e36")
	_check_eq(NumberFormat.format_number(1.23e50), "1.23e50", "1.23e50")
	_check_eq(NumberFormat.format_number(9.999e99), "1.00e100", "9.999e99 -> 1.00e100")
	_check_eq(NumberFormat.format_number(1.0e300), "1.00e300", "1e300")
	_check_eq(NumberFormat.format_number(1.7e308), "1.70e308", "cerca del máximo de un double")


func _test_special_values() -> void:
	_section("Valores especiales")
	_check_eq(NumberFormat.format_number(-1500.0), "-1.50K", "negativo con sufijo")
	_check_eq(NumberFormat.format_number(-15.0), "-15", "negativo chico")
	_check_eq(NumberFormat.format_number(NAN), "NaN", "NaN")
	_check_eq(NumberFormat.format_number(INF), "∞", "infinito")
	_check_eq(NumberFormat.format_number(-INF), "-∞", "menos infinito")
	_check_eq(NumberFormat.format_cost(INF), "∞", "costo infinito (generador impagable) -> ∞")


## Barrido de valores justo en los bordes de cada banda y de cada sufijo: nunca debe
## aparecer una parte numérica de 1000 o más, y a partir de 1000 siempre son 3 cifras.
func _test_never_shows_four_digits() -> void:
	_section("Barrido: nunca 4 cifras")
	var shape: RegEx = RegEx.create_from_string("^(\\d{1,3}(\\.\\d{1,2})?(K|M|B|T|Qa|Qi|Sx|Sp|Oc|No|Dc)?|\\d\\.\\d{2}e\\d{2,3})$")
	var plain_integer: RegEx = RegEx.create_from_string("^\\d{1,3}$")
	var mantissas: Array[float] = [1.0, 1.5, 9.994, 9.995, 9.999, 10.0, 99.94, 99.95, 99.99, 100.0, 999.4, 999.5, 999.99]
	var bad: Array[String] = []
	var tested: int = 0
	for exponent: int in range(0, 309):
		for mantissa: float in mantissas:
			var value: float = mantissa * pow(10.0, exponent)
			if not is_finite(value):
				continue
			for text: String in [NumberFormat.format_number(value), NumberFormat.format_cost(value)]:
				tested += 1
				if shape.search(text) == null:
					bad.append("%s (%s) no respeta el formato" % [text, str(value)])
				elif value >= 1000.0 and _significant_digits(text) != 3:
					bad.append("%s (%s) no tiene exactamente 3 cifras" % [text, str(value)])
				elif value < 999.0 and plain_integer.search(text) == null:
					bad.append("%s (%s) debería ser un entero sin sufijo" % [text, str(value)])
	for message: String in bad.slice(0, 10):
		printerr("    ", message)
	_check(bad.is_empty(), "%d formateos cumplen el formato (3 cifras, sin '1000K')" % tested)


## Cuenta los dígitos de la parte numérica ("1.23K" -> 3, "10.0K" -> 3, "1.00e36" -> 3).
func _significant_digits(text: String) -> int:
	var numeric: String = text.split("e")[0]
	var count: int = 0
	for i: int in range(numeric.length()):
		if numeric[i] >= "0" and numeric[i] <= "9":
			count += 1
	return count
