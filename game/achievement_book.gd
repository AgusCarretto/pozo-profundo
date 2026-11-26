extends Control
## El librito de logros: todos, por categoría, con lo que llevás de cada uno. Los secretos se ven como "???" hasta
## conseguirlos. Se desliza con el dedo. Visual provisorio (los íconos y el arte esperan aprobación).

signal opened
signal closed

const Achievements := preload("res://core/achievements.gd")
const NumberFormat := preload("res://core/number_format.gd")
const Palette := preload("res://game/palette.gd")
const TROPHY: Texture2D = preload("res://assets/ui/game_icons/trophy.png")
const MEDAL: Texture2D = preload("res://assets/ui/game_icons/medal1.png")
const MEDAL_BIG: Texture2D = preload("res://assets/ui/game_icons/medal2.png")
const LOCKED: Texture2D = preload("res://assets/ui/game_icons/locked.png")
const MARK_SIZE: float = 52.0
## El color de cada dificultad (bronce, plata, oro y la épica).
const TIER_COLORS: Dictionary = { "facil": Palette.CLAY, "medio": Palette.STEEL_LIGHT, "dificil": Palette.GOLD, "epico": Palette.PINK }

const BUTTON_HEIGHT: float = 104.0
const CLOSE_WIDTH: float = 160.0
const BAR_HEIGHT: float = 16.0
const MARGIN: int = 16
## Cómo se nombra lo que cuenta cada logro. Es presentación; los números salen de data/logros.json.
const UNITS: Dictionary = {
	"hits": "golpes", "crits": "críticos", "record_depth": "m", "chests": "cofres", "chest_legendary": "Legendarios",
	"max_miner": "Mineros", "max_steam_drill": "Taladros", "max_mole": "Topos", "max_stone_golem": "Gólems",
	"max_rune_excavator": "Excavadoras", "max_abyss_worm": "Gusanos", "resets": "vueltas", "best_reset": "reliquias",
	"dynamite": "usos", "stars": "estrellas", "keystones": "piedras", "gear_opens": "toques", "mute_cycles": "veces",
	"loot_views": "veces",
}
## Estos se miden en segundos y se muestran como minutos:segundos.
const MINUTE_STATS: Array[String] = ["frenzy_best"]
## Este se mide en segundos y se muestra en horas.
const HOUR_STATS: Array[String] = ["max_away"]

var _summary: Label
var _scroll: ScrollContainer
## Por id de logro: {name, desc, fragments, bar, progress}.
var _rows: Dictionary = {}
## Por categoría: el encabezado.
var _headers: Dictionary = {}


func _init() -> void:
	name = "AchievementBook"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	var sky: ColorRect = ColorRect.new()
	sky.color = Palette.OUTLINE.darkened(0.45)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sky)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(column)
	column.add_child(_build_top())
	_scroll = ScrollContainer.new()
	_scroll.name = "BookScroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_build_rows()


func open() -> void:
	if visible or not Economy.has_achievements():
		return
	Economy.check_achievements()
	visible = true
	_scroll.scroll_vertical = 0
	refresh()
	Audio.play_sfx("tab")
	opened.emit()


func close() -> void:
	if not visible:
		return
	visible = false
	Audio.play_sfx("close")
	closed.emit()


func refresh() -> void:
	if not Economy.has_achievements():
		return
	var achievements: Achievements = Economy.achievements
	var earned: int = achievements.fragments_earned()
	_summary.text = "%d de %d · %d fragmentos ganados" % [achievements.unlocked_count(), _rows.size(), earned]
	var done: Dictionary = {}
	var total: Dictionary = {}
	for id: String in _rows:
		var category: String = str(achievements.entry(id).get("cat", ""))
		total[category] = int(total.get(category, 0)) + 1
		done[category] = int(done.get(category, 0)) + int(achievements.is_unlocked(id))
		_refresh_row(id)
	for category: String in _headers:
		(_headers[category] as Label).text = "%s · %d/%d" % [category, int(done.get(category, 0)), int(total.get(category, 0))]


func _refresh_row(id: String) -> void:
	var achievements: Achievements = Economy.achievements
	var data: Dictionary = achievements.entry(id)
	var row: Dictionary = _rows[id]
	var unlocked: bool = achievements.is_unlocked(id)
	var hidden: bool = achievements.is_secret(id) and not unlocked
	var title: Label = row["name"]
	title.text = "???" if hidden else str(data.get("name", id))
	title.add_theme_color_override("font_color", Palette.YELLOW if unlocked else Palette.FROST)
	(row["desc"] as Label).text = "Secreto: se descubre jugando." if hidden else str(data.get("desc", ""))
	(row["fragments"] as Label).text = "+%d" % achievements.fragments_for(id)
	# Trofeo si ya está; si no, la medalla de su dificultad apagada, o un candado si es secreto.
	var tier: String = str(data.get("tier", ""))
	var color: Color = TIER_COLORS.get(tier, Palette.FROST)
	var mark: TextureRect = row["mark"]
	if unlocked:
		mark.texture = TROPHY
		mark.modulate = color
	elif hidden:
		mark.texture = LOCKED
		mark.modulate = Color(Palette.STEEL, 0.7)
	else:
		mark.texture = MEDAL_BIG if tier == "dificil" or tier == "epico" else MEDAL
		mark.modulate = Color(color, 0.5)
	var bar: ProgressBar = row["bar"]
	var progress: Label = row["progress"]
	bar.visible = not hidden and not unlocked and float(data["target"]) > 1.0
	progress.visible = not hidden
	if unlocked:
		progress.text = "Conseguido"
		progress.add_theme_color_override("font_color", Palette.YELLOW)
		return
	progress.remove_theme_color_override("font_color")
	progress.text = _progress_text(data)
	var target: float = float(data["target"])
	bar.value = clampf(Economy.stat(str(data["stat"])) / target, 0.0, 1.0)


func _progress_text(data: Dictionary) -> String:
	# Si pide además otra cosa (Museo ambulante), primero se muestra cuánto falta de esa.
	var requires: Dictionary = data.get("requires", {})
	for stat_name: String in requires:
		if Economy.stat(stat_name) < float(requires[stat_name]):
			return "Meta de regreso: %s / %s m" % [_thousands(Economy.stat(stat_name)), _thousands(float(requires[stat_name]))]
	var stat: String = str(data["stat"])
	var target: float = float(data["target"])
	if target <= 1.0:
		return "Pendiente"
	var value: float = clampf(Economy.stat(stat), 0.0, target)
	if stat in MINUTE_STATS:
		return "%s / %s" % [_minutes(value), _minutes(target)]
	if stat in HOUR_STATS:
		return "%d / %d h" % [int(value / 3600.0), int(target / 3600.0)]
	if stat == "overshoot":
		return "%d / %d m pasada la meta" % [int(value), int(target)]
	return ("%s / %s %s" % [_thousands(value), _thousands(target), UNITS.get(stat, "")]).strip_edges()


## Con punto de miles: acá importa el número exacto (342 / 1.000), no el sufijo.
static func _thousands(value: float) -> String:
	var digits: String = str(int(floorf(value)))
	var out: String = ""
	while digits.length() > 3:
		out = "." + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return digits + out


static func _minutes(seconds: float) -> String:
	var whole: int = int(floorf(seconds))
	return "%d:%02d" % [whole / 60, whole % 60]


# --- Armado -----------------------------------------------------------------------

func _build_top() -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.theme_type_variation = &"HudPanel"
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var texts: VBoxContainer = VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(texts)
	var title: Label = Label.new()
	title.text = "Logros"
	title.add_theme_font_size_override("font_size", 40)
	texts.add_child(title)
	_summary = Label.new()
	_summary.name = "BookSummary"
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.add_theme_font_size_override("font_size", 26)
	texts.add_child(_summary)
	var hint: Label = Label.new()
	hint.theme_type_variation = &"MutedLabel"
	hint.text = "20 fragmentos son 1 reliquia."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 22)
	texts.add_child(hint)
	var shut: Button = Button.new()
	shut.name = "CloseBook"
	shut.theme_type_variation = &"ButtonNeutral"
	shut.text = "Cerrar"
	shut.custom_minimum_size = Vector2(CLOSE_WIDTH, BUTTON_HEIGHT)
	shut.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	shut.focus_mode = Control.FOCUS_NONE
	shut.add_theme_font_size_override("font_size", 26)
	shut.pressed.connect(close)
	row.add_child(shut)
	return panel


func _build_rows() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, MARGIN)
	_scroll.add_child(margin)
	var list: VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	margin.add_child(list)
	if not Economy.has_achievements():
		return
	var achievements: Achievements = Economy.achievements
	for category: String in achievements.categories():
		var header: Label = Label.new()
		header.text = category
		header.add_theme_font_size_override("font_size", 32)
		list.add_child(header)
		_headers[category] = header
		for id: String in achievements.ids():
			if str(achievements.entry(id).get("cat", "")) == category:
				_rows[id] = _build_row(list, id)


## Todo deja pasar el toque (PASS o IGNORE): arrastrar sobre una fila tiene que deslizar la lista.
func _build_row(list: VBoxContainer, id: String) -> Dictionary:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Row_" + id
	panel.theme_type_variation = &"BottomPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	list.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	box.add_child(head)
	var mark: TextureRect = TextureRect.new()
	mark.name = "Mark"
	mark.custom_minimum_size = Vector2(MARK_SIZE, MARK_SIZE)
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(mark)
	var title: Label = _label(head, 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fragments: Label = _label(head, 28)
	fragments.autowrap_mode = TextServer.AUTOWRAP_OFF
	var desc: Label = _label(box, 22)
	desc.theme_type_variation = &"MutedLabel"
	var bar: ProgressBar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	bar.max_value = 1.0
	bar.step = 0.0
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bar)
	var progress: Label = _label(box, 22)
	return { "name": title, "desc": desc, "fragments": fragments, "bar": bar, "progress": progress, "mark": mark }


func _label(parent: Node, font_size: int) -> Label:
	var label: Label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label
