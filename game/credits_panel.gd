extends Control
## Créditos y licencias, encima de Opciones. Se arma por código y empieza cerrado.
##
## Las licencias de Godot (MIT) y de las fuentes Pixelify Sans y VT323 (OFL) piden acompañar lo que se distribuye.
## El detalle completo de cada asset está en CREDITS.md; un asset nuevo que pida crédito se suma también acá.

const FONT_LICENSE_PATH: String = "res://assets/fonts/OFL.txt"
const NUMBER_FONT_LICENSE_PATH: String = "res://assets/fonts/VT323-OFL.txt"
## Margen del cartel con el borde de la pantalla y alto del botón (px de diseño).
const SCREEN_MARGIN: int = 40
const TOUCH_HEIGHT: float = 96.0

const ASSET_CREDITS: String = """Arte, interfaz y efectos de sonido
Kenney (kenney.nl): Tiny Dungeon, UI Pack, Game Icons, Particle Pack, Impact Sounds, Interface Sounds y RPG Audio. CC0.

Música (CC0)
The Cynic Project / pixelsphere.org: Town Theme RPG y Crystal Cave.
Juhani Junkala (SubspaceAudio): Retro Game Music Pack.
Ville Nousiainen (soundcloud.com/mutkanto): Fast fight / battle music."""

const ENGINE_PARTS: String = """Portions of this software are copyright © 2026 The FreeType Project (www.freetype.org). All rights reserved.
ENet: Copyright (c) 2002-2024 Lee Salzman (MIT).
Mbed TLS: Copyright The Mbed TLS Contributors (Apache 2.0)."""

var close_button: Button

var _scroll: ScrollContainer


func _init() -> void:
	name = "CreditsPanel"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.85)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, SCREEN_MARGIN)
	add_child(margin)

	var panel: PanelContainer = PanelContainer.new()
	panel.theme_type_variation = &"ModalPanel"
	margin.add_child(panel)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)

	var title: Label = Label.new()
	title.theme_type_variation = &"TitleLabel"
	title.text = "Créditos"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)

	var text_box: VBoxContainer = VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 24)
	_scroll.add_child(text_box)
	_add_text(text_box, ASSET_CREDITS)
	_add_text(text_box, "Fuente: Pixelify Sans\n" + FileAccess.get_file_as_string(FONT_LICENSE_PATH).strip_edges())
	_add_text(text_box, "Fuente de los números: VT323 (solo los dígitos)\n" + FileAccess.get_file_as_string(NUMBER_FONT_LICENSE_PATH).strip_edges())
	_add_text(text_box, "Motor: Godot Engine (godotengine.org)\n" + Engine.get_license_text().strip_edges())
	_add_text(text_box, ENGINE_PARTS)

	close_button = Button.new()
	close_button.theme_type_variation = &"ButtonNeutral"
	close_button.text = "Cerrar"
	close_button.custom_minimum_size = Vector2(0, TOUCH_HEIGHT)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close)
	box.add_child(close_button)


func open() -> void:
	if visible:
		return
	Audio.play_sfx("open")
	_scroll.scroll_vertical = 0
	visible = true


func close() -> void:
	if not visible:
		return
	Audio.play_sfx("close")
	visible = false


func _add_text(box: VBoxContainer, text: String) -> void:
	var label: Label = Label.new()
	label.theme_type_variation = &"MutedLabel"
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)
