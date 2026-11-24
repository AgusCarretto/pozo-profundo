extends RefCounted
## Formato de números grandes con sufijos (K, M, B, T...), pensado para juegos incrementales.
##
## - Menos de 1000: entero. `format_number` trunca (oro: "14" si hay 14.99) y `format_cost`
##   redondea hacia arriba (un costo de 14.01 se muestra "15"), así que si el oro y el
##   costo muestran el mismo número, alcanza para comprar.
## - Desde 1000: siempre 3 cifras ("1.23K", "12.3K", "123K"), redondeadas al más cercano.
## - Más allá del último sufijo: notación científica ("1.00e36").
##
## Código reutilizable entre juegos: no debe depender de nada de game/.

const SUFFIXES: Array[String] = ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]


## Para cantidades que se poseen (oro, oro/s, daño): trunca por debajo de 1000.
static func format_number(value: float) -> String:
	return _format(value, false)


## Para precios: redondea hacia arriba por debajo de 1000.
static func format_cost(value: float) -> String:
	return _format(value, true)


static func _format(value: float, round_up: bool) -> String:
	if is_nan(value):
		return "NaN"
	if is_inf(value):
		return "∞" if value > 0.0 else "-∞"
	if value < 0.0:
		return "-" + _format(-value, false)

	var amount: float = value
	if amount < 1000.0:
		var whole: float = ceilf(amount) if round_up else floorf(amount)
		if whole < 1000.0:
			return str(int(whole))
		amount = whole # un costo de 999.2 sube a 1000 y se muestra como "1.00K"

	var tier: int = 0
	var mantissa: float = amount
	while mantissa >= 1000.0:
		mantissa /= 1000.0
		tier += 1

	var rounded: float = _round_to_three_digits(mantissa)
	if rounded >= 1000.0: # 999.6K redondea a 1000K: se muestra como 1.00M
		rounded /= 1000.0
		tier += 1

	if tier >= SUFFIXES.size():
		return _scientific(amount)
	var decimals: int = 2 if rounded < 10.0 else (1 if rounded < 100.0 else 0)
	return ("%." + str(decimals) + "f") % rounded + SUFFIXES[tier]


## Redondea una mantisa en [1, 1000) a 3 cifras significativas.
static func _round_to_three_digits(mantissa: float) -> float:
	if mantissa < 10.0:
		return snappedf(mantissa, 0.01)
	if mantissa < 100.0:
		return snappedf(mantissa, 0.1)
	return snappedf(mantissa, 1.0)


static func _scientific(value: float) -> String:
	var exponent: int = int(floorf(log(value) / log(10.0)))
	var mantissa: float = value / pow(10.0, exponent)
	if mantissa >= 10.0: # corrige el error de redondeo del logaritmo
		mantissa /= 10.0
		exponent += 1
	elif mantissa < 1.0:
		mantissa *= 10.0
		exponent -= 1
	mantissa = snappedf(mantissa, 0.01)
	if mantissa >= 10.0: # 9.999 redondea a 10.00: se muestra como 1.00e(n+1)
		mantissa /= 10.0
		exponent += 1
	return "%.2fe%d" % [mantissa, exponent]
