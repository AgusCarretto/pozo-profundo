extends Control
## Escena principal (layout vertical para celular): HUD arriba (oro, oro/s, profundidad con barra al
## próximo bioma y multiplicador), la mina en el medio (roca, mineros, taladro y gólem) y abajo un
## panel con pestañas: Cuadrilla, Botín y Reliquias.
##
## Toda la lógica está en el autoload Economy: acá solo se conecta la UI. El arte vive en
## game/mine_view.gd (la mina) y los estilos en ui/theme.tres.

const BiomePalette := preload("res://game/biome_palette.gd")
const DebugPanel := preload("res://game/debug_panel.gd")
const GeneratorRow := preload("res://game/generator_row.gd")
const Modal := preload("res://game/modal.gd")
const MineView := preload("res://game/mine_view.gd")
const NumberFormat := preload("res://core/number_format.gd")
const OptionsPanel := preload("res://game/options_panel.gd")
const ScreenFx := preload("res://game/screen_fx.gd")
const EconomyMath := preload("res://core/economy_math.gd")
const Juice := preload("res://game/juice.gd")
const PickRow := preload("res://game/pick_row.gd")
const SoundCues := preload("res://game/sound_cues.gd")

## Color de cada rareza de cofre, por id del balance. Es presentación, no balance.
const RARITY_COLORS: Dictionary = {
	"common": Color(0.78, 0.78, 0.8),
	"rare": Color(0.35, 0.65, 1.0),
	"epic": Color(0.75, 0.45, 1.0),
	"legendary": Color(1.0, 0.72, 0.2),
}
const DEFAULT_RARITY_COLOR: Color = Color(0.9, 0.9, 0.9)
## El cofre de esta rareza tiene su momento: una pausa breve (cámara lenta) y un destello de pantalla.
const SPECIAL_RARITY: String = "legendary"
const SPECIAL_PAUSE: float = 0.3
const SPECIAL_SLOW: float = 0.05
const SPECIAL_FLASH: Color = Color(1.0, 0.97, 0.85, 0.85)
const SPECIAL_FLASH_FADE: float = 0.5

const SOUND_ON_ICON: Texture2D = preload("res://assets/ui/game_icons/audioOn.png")
const SOUND_OFF_ICON: Texture2D = preload("res://assets/ui/game_icons/audioOff.png")

const CHEST_ICON: String = "res://assets/sprites/tiny_dungeon/tile_0089.png"
const COIN_ICON: String = "res://assets/sprites/generated/coin.png"
const RUNE_ICONS: Array[String] = [
	"res://assets/sprites/generated/rune_1.png",
	"res://assets/sprites/generated/rune_2.png",
	"res://assets/sprites/generated/rune_3.png",
]
## Cuántas runas se dibujan como máximo en la pestaña de reliquias (el contador dice el total real).
const MAX_RUNES_SHOWN: int = 8
const RUNE_SIZE: float = 80.0
## El oro achica su fuente de a este paso cuando el número no entra en su lugar, sin bajar del mínimo.
const GOLD_FONT_STEP: int = 4
const GOLD_FONT_MIN: int = 48
const CHEST_SIZE: float = 64.0

enum Tab { CREW, LOOT, RELICS }

var _mode: int = Economy.BuyMode.X1
var _rows: Array[GeneratorRow] = []
## Se marca cuando Economy cambia; la pantalla se refresca una vez por frame, no por señal.
var _dirty: bool = true
var _modal: Modal
var _options: OptionsPanel
var _screen_fx: ScreenFx
var _pick_row: PickRow
var _shown_runes: int = -1
## El último cofre que salió en esta partida ({rarity, bonus}); vacío si todavía no salió ninguno (o si el
## bonus volvió a 0). El aviso del botín se arma con esto y con el bonus real: ver _refresh_last_loot().
var _last_chest: Dictionary = {}
## Índice del bioma que se está mostrando (-1 = todavía ninguno). Bajar a uno más profundo suena.
var _shown_biome: int = -1
## Se prende al final de _ready: lo que se marca mientras se arma la escena no suena. (is_node_ready() no sirve:
## ya es true adentro de _ready.)
var _built: bool = false
## Tamaño de fuente del oro según el tema (el que se usa cuando el número entra).
var _gold_font_size: int = 0

@onready var _gold_label: Label = %GoldLabel
@onready var _rate_label: Label = %RateLabel
@onready var _hit_label: Label = %HitLabel
@onready var _mult_label: Label = %MultLabel
@onready var _sound_button: Button = %SoundButton
@onready var _options_button: Button = %OptionsButton
@onready var _depth_label: Label = %DepthLabel
@onready var _next_biome_label: Label = %NextBiomeLabel
@onready var _depth_bar: ProgressBar = %DepthBar
@onready var _mine_view: MineView = %MineView
@onready var _tap_button: Button = %TapButton
@onready var _hint_label: Label = %HintLabel
@onready var _tab_buttons: Array[Button] = [%TabCrewButton, %TabLootButton, %TabRelicsButton]
@onready var _mode_buttons: Array[Button] = [%Mode1Button, %Mode10Button, %ModeMaxButton]
@onready var _pages: Array[Control] = [%CrewPage, %LootPage, %RelicsPage]
@onready var _loot_box: VBoxContainer = %LootBox
@onready var _loot_info_label: Label = %LootInfoLabel
@onready var _chest_row: HBoxContainer = %ChestRow
@onready var _odds_row: HBoxContainer = %OddsRow
@onready var _last_loot_label: Label = %LastLootLabel
@onready var _loot_bonus_label: Label = %LootBonusLabel
@onready var _pick_holder: VBoxContainer = %PickRow
@onready var _relics_label: Label = %RelicsLabel
@onready var _relics_row: HBoxContainer = %RelicsRow
@onready var _relics_hint: Label = %RelicsHint
@onready var _prestige_button: Button = %PrestigeButton
@onready var _generator_list: VBoxContainer = %GeneratorList


func _ready() -> void:
	_gold_font_size = _gold_label.get_theme_font_size("font_size")
	_gold_label.resized.connect(_fit_gold_label)
	for index: int in range(Economy.generator_count()):
		var row: GeneratorRow = GeneratorRow.new()
		_generator_list.add_child(row)
		row.setup(index)
		_rows.append(row)

	# El pico es la primera fila de la lista, con el mismo formato que los generadores.
	_pick_row = PickRow.new()
	_pick_holder.add_child(_pick_row)
	_pick_row.setup()

	var group: ButtonGroup = ButtonGroup.new()
	var mode_buttons: Dictionary = {
		Economy.BuyMode.X1: %Mode1Button,
		Economy.BuyMode.X10: %Mode10Button,
		Economy.BuyMode.MAX: %ModeMaxButton,
	}
	for mode: int in mode_buttons:
		var button: Button = mode_buttons[mode]
		button.button_group = group
		button.toggled.connect(_on_mode_toggled.bind(mode))
	(%Mode1Button as Button).button_pressed = true

	# Las pestañas: una sola activa a la vez (ButtonGroup) y cada una muestra su página.
	var tab_group: ButtonGroup = ButtonGroup.new()
	for index: int in range(_tab_buttons.size()):
		_tab_buttons[index].button_group = tab_group
		_tab_buttons[index].toggled.connect(_on_tab_toggled.bind(index))
	_tab_buttons[Tab.CREW].button_pressed = true
	_show_page(Tab.CREW)

	# Reaccionan al apretar (no al soltar): un clicker tiene que responder al toque.
	_tap_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	_tap_button.button_down.connect(_on_tap)
	_prestige_button.pressed.connect(_on_prestige_pressed)

	_build_loot_panel()
	add_child(SoundCues.new())

	# Solo en builds de debug; en un export de release no se crea (ver debug_panel.gd).
	DebugPanel.attach_if_debug(self, OS.is_debug_build())
	# Opciones: encima del juego y del panel de debug, debajo del cartel.
	_options = OptionsPanel.new()
	add_child(_options)
	# Efectos de pantalla completa (destello del legendario): encima de todo, debajo del cartel.
	_screen_fx = ScreenFx.new()
	add_child(_screen_fx)
	_options_button.pressed.connect(func() -> void:
		Juice.bounce(_options_button)
		_options.open())
	_sound_button.pressed.connect(_on_sound_pressed)
	Settings.changed.connect(_apply_settings)
	_apply_settings()
	# El cartel va último entre los hijos: se dibuja encima de todo (también del panel de debug).
	_modal = Modal.new()
	add_child(_modal)

	Economy.gold_changed.connect(_mark_dirty.unbind(1))
	Economy.generator_bought.connect(_mark_dirty.unbind(2))
	Economy.pick_upgraded.connect(_mark_dirty.unbind(1))
	Economy.prestiged.connect(_mark_dirty.unbind(1))
	Economy.loot_dropped.connect(_on_loot_dropped)
	Economy.hit_landed.connect(_on_hit_landed)
	_mine_view.dynamite_exploded.connect(func(_at: Vector2) -> void: Audio.play_sfx("dynamite"))
	Economy.offline_progress.connect(_show_offline_notice)
	_refresh()
	_built = true

	# Si el juego arrancó con progreso offline, Economy ya lo acreditó antes de que existiera esta escena.
	if not Economy.pending_offline_report.is_empty():
		_show_offline_notice(Economy.pending_offline_report)


func _process(_delta: float) -> void:
	if _dirty:
		_refresh()


func _mark_dirty() -> void:
	_dirty = true


func _on_tap() -> void:
	Economy.hit()


## Cada golpe se ve: la roca se aplasta, la mina se sacude y sale el oro que dio flotando.
func _on_hit_landed(amount: float) -> void:
	_mine_view.play_hit("+%s" % NumberFormat.format_number(amount))


## Silencia todo o devuelve el sonido. El click suena solo al devolverlo (silenciado no suena nada).
func _on_sound_pressed() -> void:
	Juice.bounce(_sound_button)
	Settings.muted = not Settings.muted
	Audio.play_sfx("toggle")


## Lo que depende de las opciones: el ícono del silencio y si la mina reduce los efectos.
func _apply_settings() -> void:
	_sound_button.icon = SOUND_OFF_ICON if Settings.muted else SOUND_ON_ICON
	_mine_view.reduce_effects = Settings.reduce_effects


# Los toggles que se marcan al armar la escena (en _ready) no suenan: solo los que toca el jugador.
func _on_mode_toggled(pressed: bool, mode: int) -> void:
	if pressed:
		if _built:
			Audio.play_sfx("mode")
			for button: Button in _mode_buttons:
				if button.button_pressed:
					Juice.bounce(button)
		_mode = mode
		_mark_dirty()


func _on_tab_toggled(pressed: bool, tab: int) -> void:
	if pressed:
		if _built:
			Audio.play_sfx("tab")
			Juice.bounce(_tab_buttons[tab])
		_show_page(tab)


func _show_page(tab: int) -> void:
	for index: int in range(_pages.size()):
		_pages[index].visible = index == tab


func _refresh() -> void:
	_dirty = false
	_gold_label.text = NumberFormat.format_number(Economy.gold)
	_fit_gold_label()
	_rate_label.text = "%s oro/s" % NumberFormat.format_number(Economy.gold_per_second())
	_hit_label.text = "Golpe %s" % NumberFormat.format_number(Economy.hit_value())
	_mult_label.text = "×%.2f" % Economy.multiplier
	_refresh_depth()
	_refresh_mine()
	# Se muestra el bonus efectivo (el que de verdad multiplica el oro); el bruto solo va en el panel de debug.
	_loot_bonus_label.text = "Bonus de botín: +%s" % NumberFormat.format_percent(Economy.loot_bonus_effective())
	_pick_row.refresh()
	_refresh_last_loot()
	_refresh_prestige()
	for row: GeneratorRow in _rows:
		row.refresh(_mode)


## El oro comparte fila con el multiplicador y los botones de sonido y opciones: si el número no entra,
## se achica la fuente (de a GOLD_FONT_STEP, sin bajar de GOLD_FONT_MIN); si entra, vuelve al tamaño del tema.
func _fit_gold_label() -> void:
	var width: float = _gold_label.size.x
	if width <= 0.0:
		return
	var font: Font = _gold_label.get_theme_font("font")
	var font_size: int = _gold_font_size
	while font_size > GOLD_FONT_MIN and font.get_string_size(_gold_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
		font_size -= GOLD_FONT_STEP
	if font_size == _gold_font_size:
		_gold_label.remove_theme_font_size_override("font_size")
	else:
		_gold_label.add_theme_font_size_override("font_size", font_size)


# --- Profundidad y mina ------------------------------------------------------

func _refresh_depth() -> void:
	var text: String = "Profundidad %d m" % int(floorf(Economy.depth()))
	var has_biomes: bool = Economy.biome_count() > 0
	if has_biomes:
		text += " · %s ×%.2f" % [Economy.biome_name(Economy.biome_index()), Economy.biome_multiplier()]
	_depth_label.text = text
	_depth_bar.visible = has_biomes
	_next_biome_label.visible = has_biomes
	if not has_biomes:
		return
	_depth_bar.value = Economy.biome_progress()
	var next: int = Economy.next_biome_index()
	if next >= 0:
		_next_biome_label.text = "→ %s · %s m" % [Economy.biome_name(next), NumberFormat.format_number(Economy.next_biome_depth())]
	else:
		_next_biome_label.text = "¡Fondo!"
	# Bajar a un bioma más profundo es una novedad: el piso y la roca se funden al nuevo, sale un cartel y suena.
	# Abrir el juego o volver a la superficie cambia sin ceremonia. La música sigue al bioma siempre.
	var biome: int = Economy.biome_index()
	var deeper: bool = _shown_biome >= 0 and biome > _shown_biome
	var id: String = Economy.biome_id(biome)
	if biome != _shown_biome:
		Audio.play_music(id)
	_apply_biome(id, deeper)
	if deeper:
		Audio.play_sfx("biome")
		_mine_view.show_banner("Bioma %s" % Economy.biome_name(biome), "×%.2f de oro" % Economy.biome_multiplier(), BiomePalette.of(id)["accent"])
	_shown_biome = biome


## Cambia la paleta de la mina y el color de la barra cuando se entra en otro bioma.
func _apply_biome(id: String, animate: bool = false) -> void:
	if id == _mine_view.biome_id:
		return
	_mine_view.show_biome(id, animate)
	var fill: StyleBox = _depth_bar.get_theme_stylebox("fill")
	if fill is StyleBoxTexture:
		var tinted: StyleBoxTexture = (fill as StyleBoxTexture).duplicate()
		tinted.modulate_color = BiomePalette.of(_mine_view.biome_id)["accent"]
		_depth_bar.add_theme_stylebox_override("fill", tinted)


## La cuadrilla que se ve en la mina sale de lo que compraste: mineros, y el taladro y el gólem si los tenés.
func _refresh_mine() -> void:
	var miners: int = 0
	var has_drill: bool = false
	var has_golem: bool = false
	var dynamite: int = 0
	var excavators: int = 0
	for index: int in range(Economy.generator_count()):
		match Economy.generator_id(index):
			"miner":
				miners = Economy.owned_count(index)
			"steam_drill":
				has_drill = Economy.owned_count(index) > 0
			"stone_golem":
				has_golem = Economy.owned_count(index) > 0
			"dynamite_crew":
				dynamite = Economy.owned_count(index)
			"rune_excavator":
				excavators = Economy.owned_count(index)
	_mine_view.set_crew(miners, has_drill, has_golem)
	_mine_view.set_machines(dynamite, excavators)
	_hint_label.visible = Economy.run_gold <= 0.0


# --- Botín -------------------------------------------------------------------

## Muestra las probabilidades reales del botín (las mismas que usa Economy para sortear).
func _build_loot_panel() -> void:
	var table: Array[Dictionary] = Economy.loot_table()
	_loot_box.visible = not table.is_empty()
	_tab_buttons[Tab.LOOT].visible = not table.is_empty()
	if table.is_empty():
		return
	_loot_info_label.text = "Cofres: %s por golpe · %s por segundo con cuadrilla" % [
		NumberFormat.format_percent(Economy.loot_chance_per_hit()),
		NumberFormat.format_percent(Economy.loot_chance_per_second()),
	]
	var chest: Texture2D = load(CHEST_ICON) as Texture2D
	for rarity: Dictionary in table:
		var color: Color = _rarity_color(rarity["id"])
		var icon: TextureRect = TextureRect.new()
		icon.texture = chest
		icon.modulate = color
		icon.custom_minimum_size = Vector2(0, CHEST_SIZE)
		icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_chest_row.add_child(icon)
		var label: Label = Label.new()
		label.text = "%s\n%s (+%s)" % [rarity["name"], NumberFormat.format_percent(rarity["chance"]), NumberFormat.format_percent(rarity["bonus"])]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 22)
		label.add_theme_color_override("font_color", color)
		_odds_row.add_child(label)


func _on_loot_dropped(rarity: int, bonus: float) -> void:
	_mark_dirty() # el bonus total cambió, aunque el oro no
	var table: Array[Dictionary] = Economy.loot_table()
	if rarity < 0 or rarity >= table.size():
		return
	_last_chest = { "rarity": rarity, "bonus": bonus }
	_refresh_last_loot() # ya mismo: no hace falta esperar al próximo refresco
	_celebrate_chest(table[rarity], bonus)


## El cofre cae en la mina con el brillo de su rareza y sale un aviso con lo que suma: el bonus del cofre y lo que
## de verdad sube el efectivo (rinde cada vez menos). El legendario además pausa un momento y destella.
func _celebrate_chest(entry: Dictionary, bonus: float) -> void:
	var color: Color = _rarity_color(entry["id"])
	var special: bool = entry["id"] == SPECIAL_RARITY
	var chest_icon: Texture2D = load(CHEST_ICON) as Texture2D
	_mine_view.drop_chest(chest_icon, color, special)
	var cap: float = Economy.loot_bonus_cap()
	var gain: float = Economy.loot_bonus_effective() - EconomyMath.loot_bonus_effective(Economy.loot_bonus - bonus, cap)
	_mine_view.show_toast(chest_icon, "¡Cofre %s!" % entry["name"], "+%s → +%s" % [NumberFormat.format_percent(bonus), NumberFormat.format_percent(gain)], color)
	if special:
		_screen_fx.hit_stop(SPECIAL_PAUSE, SPECIAL_SLOW)
		if not Settings.reduce_effects:
			_screen_fx.flash(SPECIAL_FLASH, SPECIAL_FLASH_FADE)


## El aviso del último cofre sale del estado, no solo de la señal del cofre: sin bonus dice que todavía no
## salió ninguno (también tras volver a la superficie o reiniciar); con bonus muestra el último cofre de esta
## sesión y, si el bonus viene de una partida guardada (no hay cofre que mostrar), lo dice.
func _refresh_last_loot() -> void:
	var table: Array[Dictionary] = Economy.loot_table()
	if table.is_empty():
		return
	if Economy.loot_bonus <= 0.0:
		_last_chest = {}
		_last_loot_label.text = "Todavía no salió ningún cofre"
		_last_loot_label.remove_theme_color_override("font_color")
	elif _last_chest.is_empty() or int(_last_chest["rarity"]) >= table.size():
		_last_chest = {}
		_last_loot_label.text = "Tu bonus viene de cofres que ya encontraste"
		_last_loot_label.remove_theme_color_override("font_color")
	else:
		var entry: Dictionary = table[int(_last_chest["rarity"])]
		_last_loot_label.text = "¡Cofre %s! +%s de bonus" % [entry["name"], NumberFormat.format_percent(_last_chest["bonus"])]
		_last_loot_label.add_theme_color_override("font_color", _rarity_color(entry["id"]))


func _rarity_color(id: String) -> Color:
	return RARITY_COLORS.get(id, DEFAULT_RARITY_COLOR)


# --- Reliquias y prestigio ---------------------------------------------------

func _refresh_prestige() -> void:
	var relics_text: String = "Reliquias: %d" % Economy.relics
	if Economy.relics > 0:
		relics_text += " · +%s de oro" % NumberFormat.format_percent(Economy.relics * Economy.relic_bonus())
	_relics_label.text = relics_text
	_relics_hint.text = "Desde los %s m podés volver a la superficie y ganar reliquias: cada una da +%s de oro para siempre." % [
		NumberFormat.format_number(Economy.prestige_min_depth()),
		NumberFormat.format_percent(Economy.relic_bonus()),
	]
	_refresh_runes()
	if Economy.can_prestige():
		var gain: int = Economy.prestige_relics()
		_prestige_button.text = "Volver a la superficie\n+%s (+%s de oro)" % [_relics_phrase(gain), NumberFormat.format_percent(gain * Economy.relic_bonus())]
		_prestige_button.disabled = false
	else:
		_prestige_button.text = "Volver a la superficie\nDisponible desde los %s m" % NumberFormat.format_number(Economy.prestige_min_depth())
		_prestige_button.disabled = true


## Una runa por reliquia (hasta MAX_RUNES_SHOWN), alternando entre los tres símbolos.
func _refresh_runes() -> void:
	var wanted: int = mini(Economy.relics, MAX_RUNES_SHOWN)
	if wanted == _shown_runes:
		return
	_shown_runes = wanted
	for child: Node in _relics_row.get_children():
		_relics_row.remove_child(child)
		child.queue_free()
	for index: int in range(wanted):
		var rune: TextureRect = TextureRect.new()
		rune.texture = load(RUNE_ICONS[index % RUNE_ICONS.size()]) as Texture2D
		rune.custom_minimum_size = Vector2(RUNE_SIZE, RUNE_SIZE)
		rune.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rune.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rune.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_relics_row.add_child(rune)


func _relics_phrase(count: int) -> String:
	return "1 reliquia" if count == 1 else "%d reliquias" % count


## Pide confirmación antes de volver a la superficie: se pierde casi toda la partida.
func _on_prestige_pressed() -> void:
	Juice.bounce(_prestige_button)
	if not Economy.can_prestige():
		return
	var gain: int = Economy.prestige_relics()
	var body: String = "Estás a %d m (%s).\n\nGanás %s: +%s de oro permanente (en total ×%.2f).\n\nVolvés a la superficie sin oro, sin cuadrilla, sin bonus de botín y con el pico en nivel 0. Las reliquias te quedan para siempre." % [
		int(floorf(Economy.depth())),
		Economy.biome_name(Economy.biome_index()),
		_relics_phrase(gain),
		NumberFormat.format_percent(gain * Economy.relic_bonus()),
		Economy.relic_multiplier_for(Economy.relics + gain),
	]
	_modal.open("¿Volver a la superficie?", body, "Sí, volver", "Seguir cavando", _confirm_prestige, &"ButtonRed")


func _confirm_prestige() -> void:
	Economy.prestige()


# --- Progreso offline --------------------------------------------------------

func _show_offline_notice(report: Dictionary) -> void:
	var gold_text: String = NumberFormat.format_number(report["gold"])
	var body: String
	if report["capped"]:
		body = "Estuviste fuera mucho tiempo. Tu cuadrilla trabajó el máximo de %s y juntó %s de oro." % [
			NumberFormat.format_duration(Economy.offline_max_seconds()), gold_text]
	else:
		body = "Estuviste fuera %s. Tu cuadrilla siguió minando y juntó %s de oro." % [
			NumberFormat.format_duration(report["seconds"]), gold_text]
	_modal.open("¡Bienvenido de vuelta!", body, "¡A seguir!", "", Economy.dismiss_offline_report)
	_modal.celebrate(report["gold"], NumberFormat.format_number, load(COIN_ICON) as Texture2D, Settings.reduce_effects)
