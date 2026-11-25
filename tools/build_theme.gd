extends SceneTree
## Arma res://ui/theme.tres: botones del UI Pack (Kenney), fuentes (letras Pixelify Sans, números VT323) y colores
## de Tiny Dungeon.
##
## Uso (desde la raíz del proyecto; antes, `godot --headless --path . --import` si hay assets nuevos):
##   godot --headless --path . --script res://tools/build_theme.gd
##
## Se genera por código para poder retocar medidas y colores en un solo lugar y volver a armarlo.
## La pantalla se diseña a 720 px de ancho (ver CLAUDE.md): en un celular de 360 px de ancho todo se
## ve a la mitad, así que TOUCH_MIN = 96 deja los botones en 48 px o más en pantallas de 360 px.

const Palette := preload("res://game/palette.gd")

const OUT_PATH: String = "res://ui/theme.tres"
const FONT_PATH: String = "res://assets/fonts/PixelifySans.ttf"
## Los números: VT323 recortada a los dígitos (tools/build_number_font.mjs). En Pixelify el 5 y la S son iguales.
const NUMBER_FONT_PATH: String = "res://assets/fonts/VT323Digits.ttf"
## Cuánto se engrosan los números para igualar el trazo de las letras (con mucho más, el 0 tachado se empasta).
const NUMBER_EMBOLDEN: float = 0.25
## Peso de las letras. En 700 la C casi se cierra y parece una O.
const LETTER_WEIGHT: int = 500
const UI_PACK: String = "res://assets/ui/ui_pack/"

## Alto mínimo de todo lo que se toca (px de diseño; la mitad en un celular de 360 px de ancho = 48 px).
const TOUCH_MIN: int = 96
const DEFAULT_FONT_SIZE: int = 28

## El PNG de botón mide 192x64 con 6 px de "profundidad" abajo: esquinas de 16 px, y abajo 22.
const MARGIN_SIDE: int = 18
const MARGIN_TOP: int = 18
const MARGIN_BOTTOM: int = 24

## Relleno y borde de los botones neutros (selector de modo, pestañas inactivas, cancelar).
const NEUTRAL_FILL: Color = Color(0.2353, 0.2706, 0.3765)
const NEUTRAL_BORDER: Color = Color(0.3216, 0.3765, 0.4863)

var _theme: Theme = Theme.new()
var _font: FontVariation


func _initialize() -> void:
	_font = _make_font()
	_theme.default_font = _font
	_theme.default_font_size = DEFAULT_FONT_SIZE

	_build_labels()
	_build_buttons()
	_build_panels()
	_build_progress_bar()
	_build_scroll()
	_build_slider()
	_build_switch()

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://ui"))
	var error: Error = ResourceSaver.save(_theme, OUT_PATH)
	if error != OK:
		push_error("No se pudo guardar %s (%s)" % [OUT_PATH, error_string(error)])
		quit(1)
		return
	print("Tema guardado en ", OUT_PATH)
	quit(0)


## La fuente de todo el juego: primero la de los números (solo tiene los dígitos) y, de respaldo, la de las letras.
## Así cada número sale de VT323 y cada letra de Pixelify sin elegir fuente etiqueta por etiqueta.
func _make_font() -> FontVariation:
	var server: TextServer = TextServerManager.get_primary_interface()
	var letters: FontVariation = FontVariation.new()
	letters.base_font = load(FONT_PATH) as FontFile
	letters.variation_opentype = { server.name_to_tag("wght"): LETTER_WEIGHT }
	var font: FontVariation = FontVariation.new()
	font.base_font = load(NUMBER_FONT_PATH) as FontFile
	font.variation_embolden = NUMBER_EMBOLDEN
	font.fallbacks = [letters]
	# Las opciones OpenType de la primera fuente valen para toda la línea: "zero" tacha el cero, y sin ligaduras
	# porque en Pixelify la "fi" se dibuja como una "A" ("superficie" se leía "superAcie").
	# El diccionario se asigna entero: cambiar el que devuelve la propiedad no hace nada.
	font.opentype_features = { server.name_to_tag("zero"): 1, server.name_to_tag("liga"): 0, server.name_to_tag("clig"): 0 }
	return font


# --- Etiquetas -----------------------------------------------------------------------------

func _build_labels() -> void:
	_theme.set_color("font_color", "Label", Palette.FROST)
	_theme.set_color("font_outline_color", "Label", Palette.OUTLINE)
	_theme.set_constant("outline_size", "Label", 0)
	# variaciones: se eligen con theme_type_variation en la escena
	_label_variation("GoldLabel", 80, Palette.YELLOW, 8)
	_label_variation("HudLabel", 32, Palette.FROST, 4)
	_label_variation("HudMutedLabel", 28, Palette.STEEL_PALE, 0)
	_label_variation("RateLabel", 42, Palette.SAND_LIGHT, 5)
	_label_variation("BarLabel", 24, Palette.WHITE, 5) # texto sobre la barra de profundidad
	_label_variation("MultLabel", 38, Palette.GOLD, 5)
	_label_variation("MutedLabel", 26, Palette.STEEL_PALE, 0)
	_label_variation("AccentLabel", 28, Palette.YELLOW, 0)
	_label_variation("TitleLabel", 38, Palette.YELLOW, 0)
	_label_variation("RowNameLabel", 30, Palette.FROST, 0)
	_label_variation("FloatLabel", 44, Palette.YELLOW, 8) # el número que sale de la roca al golpear
	_label_variation("BannerLabel", 60, Palette.WHITE, 10) # el cartel de bioma nuevo
	# tarjetas de mejora y botones del costado de la mina
	_label_variation("CardNameLabel", 24, Palette.FROST, 0)
	_label_variation("CardDetailLabel", 22, Palette.STEEL_PALE, 0)
	_label_variation("PriceLabel", 28, Palette.WHITE, 6) # sobre la franja verde
	_label_variation("PriceOffLabel", 28, Palette.NAVY, 0) # sobre la franja gris
	_label_variation("SideCaption", 18, Palette.FROST, 5)
	_label_variation("SideBigLabel", 34, Palette.WHITE, 6)
	_label_variation("BadgeLabel", 18, Palette.OUTLINE, 0)
	_label_variation("BadgeAlertLabel", 22, Palette.WHITE, 4)


func _label_variation(type_name: String, size: int, color: Color, outline: int) -> void:
	_theme.set_type_variation(type_name, "Label")
	_theme.set_font("font", type_name, _font)
	_theme.set_font_size("font_size", type_name, size)
	_theme.set_color("font_color", type_name, color)
	_theme.set_color("font_outline_color", type_name, Palette.OUTLINE)
	_theme.set_constant("outline_size", type_name, outline)


# --- Botones ---------------------------------------------------------------------------------

## Cada color tiene un único significado:
##   verde = se puede comprar (la franja del precio, PriceGreen); gris = no alcanza (PriceGrey, y el estilo
##   "deshabilitado" de los botones de acción); rojo (ButtonRed) = solo el prestigio.
## Lo demás es neutro (un estilo plano oscuro): tarjetas, botones del costado, cancelar y los avisos.
func _build_buttons() -> void:
	_theme.set_font("font", "Button", _font)
	_theme.set_font_size("font_size", "Button", 30)
	# Botón base = neutro (los que no eligen variación, como los del panel de debug).
	_neutral_style("Button")
	_action_style("ButtonGreen", "green")
	_action_style("ButtonRed", "red")
	_neutral_style("ButtonNeutral")
	_card_style("CardButton")
	_side_style("SideButton")
	for type_name: String in ["ButtonGreen", "ButtonRed", "ButtonNeutral", "CardButton", "SideButton"]:
		_theme.set_type_variation(type_name, "Button")
		_theme.set_font("font", type_name, _font)


## Tarjeta de mejora (toda la tarjeta es el botón): oscura; apretada, más clara; si no alcanza, apagada. El
## verde o gris de "alcanza / no alcanza" va en la franja del precio, no en la tarjeta entera.
func _card_style(type_name: String) -> void:
	var fill: Color = Palette.NAVY.lerp(Palette.SLATE, 0.3)
	_theme.set_stylebox("normal", type_name, _flat(fill, Palette.SLATE, 3, 14, 0))
	_theme.set_stylebox("hover", type_name, _flat(fill.lightened(0.08), Palette.SLATE_LIGHT, 3, 14, 0))
	_theme.set_stylebox("pressed", type_name, _flat(Palette.SLATE, Palette.STEEL_LIGHT, 3, 14, 0))
	_theme.set_stylebox("hover_pressed", type_name, _flat(Palette.SLATE, Palette.STEEL_LIGHT, 3, 14, 0))
	_theme.set_stylebox("disabled", type_name, _flat(Palette.NAVY, Palette.NAVY.lerp(Palette.SLATE, 0.5), 3, 14, 0))
	_theme.set_stylebox("focus", type_name, StyleBoxEmpty.new())


## Botón del costado de la mina: neutro y casi opaco, para que se lea sobre el piso.
func _side_style(type_name: String) -> void:
	var fill: Color = Color(NEUTRAL_FILL, 0.92)
	_theme.set_stylebox("normal", type_name, _flat(fill, NEUTRAL_BORDER, 3, 18, 0))
	_theme.set_stylebox("hover", type_name, _flat(fill.lightened(0.12), NEUTRAL_BORDER, 3, 18, 0))
	_theme.set_stylebox("pressed", type_name, _flat(Palette.SLATE_LIGHT, Palette.STEEL_LIGHT, 3, 18, 0))
	_theme.set_stylebox("hover_pressed", type_name, _flat(Palette.SLATE_LIGHT, Palette.STEEL_LIGHT, 3, 18, 0))
	_theme.set_stylebox("disabled", type_name, _flat(fill.darkened(0.2), NEUTRAL_BORDER, 3, 18, 0))
	_theme.set_stylebox("focus", type_name, StyleBoxEmpty.new())


## Botón de acción con el UI Pack: reposo con profundidad, apretado plano. Deshabilitado = gris (no alcanza).
func _action_style(type_name: String, color: String) -> void:
	var raised: StyleBoxTexture = _texture_style(color, true, Color.WHITE)
	var pressed: StyleBoxTexture = _texture_style(color, false, Color(0.9, 0.9, 0.9))
	pressed.content_margin_top += 4.0 # el texto "se hunde" al apretar
	var hover: StyleBoxTexture = _texture_style(color, true, Color(1.08, 1.08, 1.08))
	_set_button_states(type_name, raised, hover, pressed, pressed, Palette.WHITE, 5)


## Botón neutro: plano y oscuro, sin color de rol. Apretado/marcado = más claro y con borde.
func _neutral_style(type_name: String) -> void:
	var normal: StyleBoxFlat = _neutral_box(NEUTRAL_FILL, NEUTRAL_BORDER)
	var hover: StyleBoxFlat = _neutral_box(NEUTRAL_FILL.lightened(0.12), NEUTRAL_BORDER)
	var pressed: StyleBoxFlat = _neutral_box(Palette.SLATE_LIGHT, Palette.STEEL_LIGHT)
	_set_button_states(type_name, normal, hover, pressed, pressed, Palette.FROST, 0)
	_theme.set_color("font_pressed_color", type_name, Palette.WHITE)
	_theme.set_color("font_hover_pressed_color", type_name, Palette.WHITE)


func _neutral_box(fill: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


func _set_button_states(type_name: String, normal: StyleBox, hover: StyleBox, pressed: StyleBox, hover_pressed: StyleBox,
		text_color: Color, outline: int) -> void:
	var disabled: StyleBoxTexture = _texture_style("grey", true, Color(0.62, 0.62, 0.7))
	_theme.set_stylebox("normal", type_name, normal)
	_theme.set_stylebox("hover", type_name, hover)
	_theme.set_stylebox("pressed", type_name, pressed)
	_theme.set_stylebox("hover_pressed", type_name, hover_pressed)
	_theme.set_stylebox("disabled", type_name, disabled)
	_theme.set_stylebox("focus", type_name, StyleBoxEmpty.new())
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		_theme.set_color(key, type_name, text_color)
	_theme.set_color("font_disabled_color", type_name, Palette.SLATE)
	_theme.set_color("font_outline_color", type_name, Palette.OUTLINE)
	_theme.set_constant("outline_size", type_name, outline)
	_theme.set_constant("h_separation", type_name, 12)


## Estilo de botón con la textura del UI Pack: `raised` = con profundidad (reposo), si no, plano (apretado).
func _texture_style(color: String, raised: bool, modulate: Color) -> StyleBoxTexture:
	var kind: String = "button_rectangle_depth_flat" if raised else "button_rectangle_flat"
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = load("%s%s/%s.png" % [UI_PACK, color, kind]) as Texture2D
	style.texture_margin_left = MARGIN_SIDE
	style.texture_margin_right = MARGIN_SIDE
	style.texture_margin_top = MARGIN_TOP
	style.texture_margin_bottom = MARGIN_BOTTOM if raised else MARGIN_TOP
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	# el texto va centrado en la "cara" del botón, que en reposo deja 6 px de profundidad abajo
	style.content_margin_top = 8.0
	style.content_margin_bottom = 14.0 if raised else 8.0
	style.modulate_color = modulate
	return style


# --- Paneles ----------------------------------------------------------------------------------

func _build_panels() -> void:
	_theme.set_stylebox("panel", "PanelContainer", _flat(Palette.NAVY, Palette.SLATE, 3, 14, 16))
	_panel_variation("HudPanel", _flat_sides(Palette.OUTLINE, Palette.MAROON, Vector4(0, 0, 0, 6), 0, 20))
	_panel_variation("BottomPanel", _flat_sides(Palette.NAVY, Palette.SLATE_LIGHT, Vector4(0, 6, 0, 0), 0, 16, Vector4(28, 28, 0, 0)))
	_panel_variation("CardPanel", _flat(Palette.NAVY.lerp(Palette.SLATE, 0.3), Palette.SLATE, 3, 14, 12))
	_panel_variation("ModalPanel", _flat(Palette.NAVY, Palette.GOLD, 4, 18, 24))
	_panel_variation("BadgePanel", _flat(Palette.OUTLINE, Palette.GOLD, 3, 16, 10))
	# la franja del precio de una tarjeta: verde = se puede comprar, gris = no alcanza
	_panel_variation("PriceGreen", _price_strip("green", Color.WHITE))
	_panel_variation("PriceGrey", _price_strip("grey", Color(0.68, 0.68, 0.74)))
	# avisos sobre los botones del costado
	_panel_variation("SideBadge", _flat(Palette.GOLD, Palette.OUTLINE, 3, 12, 3))
	_panel_variation("SideBadgeAlert", _flat(Palette.RED, Palette.WHITE, 3, 14, 3))
	_theme.set_stylebox("panel", "Panel", _flat(Palette.NAVY, Palette.SLATE, 3, 14, 16))


func _price_strip(color: String, modulate: Color) -> StyleBoxTexture:
	var style: StyleBoxTexture = _texture_style(color, false, modulate)
	style.texture_margin_top = 12
	style.texture_margin_bottom = 12
	style.set_content_margin_all(2.0)
	return style


func _panel_variation(type_name: String, style: StyleBox) -> void:
	_theme.set_type_variation(type_name, "PanelContainer")
	_theme.set_stylebox("panel", type_name, style)


func _flat(fill: Color, border: Color, border_width: int, radius: int, margin: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style


## Panel con borde solo en algunos lados (izquierda, arriba, derecha, abajo) y radios por esquina.
func _flat_sides(fill: Color, border: Color, widths: Vector4, radius: int, margin: int, radii: Vector4 = Vector4.ZERO) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = int(widths.x)
	style.border_width_top = int(widths.y)
	style.border_width_right = int(widths.z)
	style.border_width_bottom = int(widths.w)
	style.corner_radius_top_left = int(radii.x) if radii != Vector4.ZERO else radius
	style.corner_radius_top_right = int(radii.y) if radii != Vector4.ZERO else radius
	style.corner_radius_bottom_right = int(radii.z) if radii != Vector4.ZERO else radius
	style.corner_radius_bottom_left = int(radii.w) if radii != Vector4.ZERO else radius
	style.set_content_margin_all(margin)
	return style


# --- Barra de progreso y scroll ------------------------------------------------------------------

func _build_progress_bar() -> void:
	_theme.set_stylebox("background", "ProgressBar", _flat(Palette.OUTLINE, Palette.SLATE, 3, 14, 0))
	# El relleno es el botón gris plano del UI Pack (casi blanco): se tiñe con el color del bioma.
	var fill: StyleBoxTexture = StyleBoxTexture.new()
	fill.texture = load(UI_PACK + "grey/button_rectangle_flat.png") as Texture2D
	fill.texture_margin_left = 14
	fill.texture_margin_right = 14
	fill.texture_margin_top = 12
	fill.texture_margin_bottom = 12
	fill.modulate_color = Palette.GOLD
	_theme.set_stylebox("fill", "ProgressBar", fill)
	_theme.set_font("font", "ProgressBar", _font)
	_theme.set_font_size("font_size", "ProgressBar", 22)


func _build_scroll() -> void:
	var grabber: StyleBoxFlat = _flat(Palette.SLATE_LIGHT, Palette.SLATE_LIGHT, 0, 6, 0)
	grabber.content_margin_left = 6
	grabber.content_margin_right = 6
	var track: StyleBoxFlat = _flat(Palette.OUTLINE, Palette.OUTLINE, 0, 6, 0)
	for type_name: String in ["VScrollBar", "HScrollBar"]:
		_theme.set_stylebox("grabber", type_name, grabber)
		_theme.set_stylebox("grabber_highlight", type_name, grabber)
		_theme.set_stylebox("grabber_pressed", type_name, grabber)
		_theme.set_stylebox("scroll", type_name, track)


# --- Opciones: slider de volumen e interruptor ------------------------------------------------------

## Slider de volumen (panel de Opciones): riel oscuro, la parte llena en dorado (el mismo acento que la
## barra de profundidad) y una perilla clara grande. El alto de 96 px lo pone la escena: el riel se dibuja
## centrado y toda la franja responde al toque.
const KNOB_SIZE: int = 48
const SWITCH_SIZE: Vector2i = Vector2i(88, 48)


func _build_slider() -> void:
	var track: StyleBoxFlat = _flat(Palette.OUTLINE, Palette.SLATE, 3, 10, 0)
	track.content_margin_top = 9
	track.content_margin_bottom = 9
	var filled: StyleBoxFlat = _flat(Palette.GOLD, Palette.GOLD, 0, 10, 0)
	filled.content_margin_top = 9
	filled.content_margin_bottom = 9
	var filled_hover: StyleBoxFlat = _flat(Palette.YELLOW, Palette.YELLOW, 0, 10, 0)
	filled_hover.content_margin_top = 9
	filled_hover.content_margin_bottom = 9
	_theme.set_stylebox("slider", "HSlider", track)
	_theme.set_stylebox("grabber_area", "HSlider", filled)
	_theme.set_stylebox("grabber_area_highlight", "HSlider", filled_hover)
	_theme.set_icon("grabber", "HSlider", _knob(Palette.FROST))
	_theme.set_icon("grabber_highlight", "HSlider", _knob(Palette.WHITE))
	_theme.set_icon("grabber_disabled", "HSlider", _knob(Palette.STEEL))
	_theme.set_constant("center_grabber", "HSlider", 1)


## Interruptor del CheckButton (reducir efectos): apagado = riel oscuro con la perilla a la izquierda;
## prendido = riel dorado con la perilla a la derecha. El botón en sí usa el estilo neutro de Button.
func _build_switch() -> void:
	_theme.set_icon("unchecked", "CheckButton", _switch(false))
	_theme.set_icon("checked", "CheckButton", _switch(true))
	_theme.set_icon("unchecked_disabled", "CheckButton", _switch(false))
	_theme.set_icon("checked_disabled", "CheckButton", _switch(true))
	_theme.set_icon("unchecked_mirrored", "CheckButton", _switch(false))
	_theme.set_icon("checked_mirrored", "CheckButton", _switch(true))


func _knob(fill: Color) -> ImageTexture:
	var img: Image = Image.create(KNOB_SIZE, KNOB_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_rounded_rect(img, Rect2i(0, 0, KNOB_SIZE, KNOB_SIZE), 12, Palette.OUTLINE)
	_rounded_rect(img, Rect2i(4, 4, KNOB_SIZE - 8, KNOB_SIZE - 8), 9, fill)
	return ImageTexture.create_from_image(img)


func _switch(on: bool) -> ImageTexture:
	var img: Image = Image.create(SWITCH_SIZE.x, SWITCH_SIZE.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_rounded_rect(img, Rect2i(Vector2i.ZERO, SWITCH_SIZE), 22, Palette.OUTLINE)
	_rounded_rect(img, Rect2i(4, 4, SWITCH_SIZE.x - 8, SWITCH_SIZE.y - 8), 18, Palette.GOLD if on else Palette.SLATE)
	var knob_x: int = SWITCH_SIZE.x - 44 if on else 4
	_rounded_rect(img, Rect2i(knob_x, 4, 40, 40), 18, Palette.FROST)
	return ImageTexture.create_from_image(img)


## Pinta en `img` un rectángulo con esquinas redondeadas de radio `radius`.
func _rounded_rect(img: Image, rect: Rect2i, radius: int, color: Color) -> void:
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var dx: int = maxi(maxi(rect.position.x + radius - x, x - (rect.end.x - 1 - radius)), 0)
			var dy: int = maxi(maxi(rect.position.y + radius - y, y - (rect.end.y - 1 - radius)), 0)
			if dx * dx + dy * dy <= radius * radius:
				img.set_pixel(x, y, color)