extends SceneTree
## Arma res://ui/theme.tres: botones del UI Pack (Kenney), fuente Pixelify Sans y colores de Tiny Dungeon.
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
const UI_PACK: String = "res://assets/ui/ui_pack/"

## Alto mínimo de todo lo que se toca (px de diseño; la mitad en un celular de 360 px de ancho = 48 px).
const TOUCH_MIN: int = 96
const DEFAULT_FONT_SIZE: int = 28

## El PNG de botón mide 192x64 con 6 px de "profundidad" abajo: esquinas de 16 px, y abajo 22.
const MARGIN_SIDE: int = 18
const MARGIN_TOP: int = 18
const MARGIN_BOTTOM: int = 24

var _theme: Theme = Theme.new()
var _font: FontVariation
var _font_bold: FontVariation


func _initialize() -> void:
	var base: FontFile = load(FONT_PATH) as FontFile
	_font = _make_font(base, 500)
	_font_bold = _make_font(base, 700)
	_theme.default_font = _font
	_theme.default_font_size = DEFAULT_FONT_SIZE

	_build_labels()
	_build_buttons()
	_build_panels()
	_build_progress_bar()
	_build_scroll()

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://ui"))
	var error: Error = ResourceSaver.save(_theme, OUT_PATH)
	if error != OK:
		push_error("No se pudo guardar %s (%s)" % [OUT_PATH, error_string(error)])
		quit(1)
		return
	print("Tema guardado en ", OUT_PATH)
	quit(0)


func _make_font(base: FontFile, weight: int) -> FontVariation:
	var font: FontVariation = FontVariation.new()
	font.base_font = base
	font.variation_opentype = { TextServerManager.get_primary_interface().name_to_tag("wght"): weight }
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
	_label_variation("BarLabel", 24, Palette.WHITE, 5) # texto sobre la barra de profundidad
	_label_variation("MultLabel", 38, Palette.GOLD, 5)
	_label_variation("MutedLabel", 26, Palette.STEEL_PALE, 0)
	_label_variation("AccentLabel", 28, Palette.YELLOW, 0)
	_label_variation("TitleLabel", 38, Palette.YELLOW, 0)
	_label_variation("RowNameLabel", 30, Palette.FROST, 0)


func _label_variation(type_name: String, size: int, color: Color, outline: int) -> void:
	_theme.set_type_variation(type_name, "Label")
	_theme.set_font("font", type_name, _font_bold)
	_theme.set_font_size("font_size", type_name, size)
	_theme.set_color("font_color", type_name, color)
	_theme.set_color("font_outline_color", type_name, Palette.OUTLINE)
	_theme.set_constant("outline_size", type_name, outline)


# --- Botones ---------------------------------------------------------------------------------

func _build_buttons() -> void:
	_theme.set_font("font", "Button", _font_bold)
	_theme.set_font_size("font_size", "Button", 30)
	# Botón base = gris (los que no eligen variación, como los del panel de debug).
	_button_style("Button", "grey", Palette.OUTLINE, false)
	# De acción: se apretan y suben solos.
	_button_style("ButtonGreen", "green", Palette.WHITE, true)
	_button_style("ButtonYellow", "yellow", Palette.OUTLINE, false)
	_button_style("ButtonRed", "red", Palette.WHITE, true)
	_button_style("ButtonBlue", "blue", Palette.WHITE, true)
	_button_style("ButtonGrey", "grey", Palette.OUTLINE, false)
	# De selección (toggle): apagado = gris oscuro, prendido = el color.
	_toggle_style("TabButton", "yellow", Palette.OUTLINE)
	_toggle_style("ModeButton", "blue", Palette.WHITE)
	for type_name: String in ["ButtonGreen", "ButtonYellow", "ButtonRed", "ButtonBlue", "ButtonGrey", "TabButton", "ModeButton"]:
		_theme.set_type_variation(type_name, "Button")
		_theme.set_font("font", type_name, _font_bold)


func _button_style(type_name: String, color: String, text_color: Color, outlined: bool) -> void:
	var raised: StyleBoxTexture = _texture_style(color, true, Color.WHITE)
	var pressed: StyleBoxTexture = _texture_style(color, false, Color(0.9, 0.9, 0.9))
	pressed.content_margin_top += 4.0 # el texto "se hunde" al apretar
	var hover: StyleBoxTexture = _texture_style(color, true, Color(1.08, 1.08, 1.08))
	_set_button_states(type_name, raised, hover, pressed, pressed, text_color, outlined)


func _toggle_style(type_name: String, color: String, on_text_color: Color) -> void:
	var off: StyleBoxTexture = _texture_style("grey", true, Color(0.5, 0.52, 0.66))
	var off_hover: StyleBoxTexture = _texture_style("grey", true, Color(0.62, 0.64, 0.78))
	var on: StyleBoxTexture = _texture_style(color, false, Color.WHITE)
	on.content_margin_top += 4.0
	_set_button_states(type_name, off, off_hover, on, on, on_text_color, false)
	# texto del estado apagado: claro, para que se lea sobre el gris oscuro
	_theme.set_color("font_color", type_name, Palette.FROST)
	_theme.set_color("font_hover_color", type_name, Palette.WHITE)
	_theme.set_color("font_outline_color", type_name, Palette.OUTLINE)
	_theme.set_constant("outline_size", type_name, 4)
	_theme.set_color("font_pressed_color", type_name, on_text_color)
	_theme.set_color("font_hover_pressed_color", type_name, on_text_color)


func _set_button_states(type_name: String, normal: StyleBox, hover: StyleBox, pressed: StyleBox, hover_pressed: StyleBox,
		text_color: Color, outlined: bool) -> void:
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
	_theme.set_constant("outline_size", type_name, 5 if outlined else 0)
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
	_theme.set_stylebox("panel", "Panel", _flat(Palette.NAVY, Palette.SLATE, 3, 14, 16))


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
	_theme.set_font("font", "ProgressBar", _font_bold)
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
