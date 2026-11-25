extends Control
## Escena principal (layout vertical para celular): HUD arriba (oro, oro/s, profundidad con barra al
## próximo bioma y multiplicador), la mina en el medio (roca, mineros, taladro y gólem; al costado los
## botones de Botín, Reliquias y modo de compra) y abajo las mejoras en dos columnas, siempre a la vista.
##
## Toda la lógica está en el autoload Economy: acá solo se conecta la UI. El arte vive en
## game/mine_view.gd (la mina) y los estilos en ui/theme.tres.

const BiomePalette := preload("res://game/biome_palette.gd")
const DebugPanel := preload("res://game/debug_panel.gd")
const GeneratorCard := preload("res://game/generator_card.gd")
const GeneratorArt := preload("res://game/generator_art.gd")
const Palette := preload("res://game/palette.gd")
const Modal := preload("res://game/modal.gd")
const MineView := preload("res://game/mine_view.gd")
const NumberFormat := preload("res://core/number_format.gd")
const OptionsPanel := preload("res://game/options_panel.gd")
const ScreenFx := preload("res://game/screen_fx.gd")
const Juice := preload("res://game/juice.gd")
const PickCard := preload("res://game/pick_card.gd")
const SideButton := preload("res://game/side_button.gd")
const SidePanel := preload("res://game/side_panel.gd")
const SoundCues := preload("res://game/sound_cues.gd")
const MusicDirector := preload("res://game/music_director.gd")

## Color de cada rareza de cofre, por id del balance. Es presentación, no balance.
const RARITY_COLORS: Dictionary = {
	"common": Color(0.78, 0.78, 0.8),
	"rare": Color(0.35, 0.65, 1.0),
	"epic": Color(0.75, 0.45, 1.0),
	"legendary": Color(1.0, 0.72, 0.2),
}
const DEFAULT_RARITY_COLOR: Color = Color(0.9, 0.9, 0.9)
## Cuántas monedas llueven al abrir un cofre, por rareza. También es presentación.
const COINS_BY_RARITY: Dictionary = { "common": 12, "rare": 24, "epic": 44, "legendary": 80 }
const DEFAULT_COINS: int = 12
## El cofre de esta rareza tiene su momento: una pausa breve (cámara lenta) y un destello de pantalla.
const SPECIAL_RARITY: String = "legendary"
const SPECIAL_PAUSE: float = 0.3
const SPECIAL_SLOW: float = 0.05
const SPECIAL_FLASH: Color = Color(1.0, 0.97, 0.85, 0.85)
const SPECIAL_FLASH_FADE: float = 0.5
## Volver a la superficie: fundido (a blanco; a oscuro con "reducir efectos") y reliquias que vuelan al contador.
const PRESTIGE_WHITE: Color = Color(1.0, 1.0, 1.0)
const PRESTIGE_DARK: Color = Color(0.08, 0.07, 0.12)
const PRESTIGE_FADE_IN: float = 0.45
const PRESTIGE_FADE_OUT: float = 0.7
const MAX_FLYING_RELICS: int = 10
const RELIC_FLIGHT_TIME: float = 0.7
const RELIC_STAGGER: float = 0.12
const RELIC_SPREAD: float = 90.0

const SOUND_ON_ICON: Texture2D = preload("res://assets/ui/game_icons/audioOn.png")
const SOUND_OFF_ICON: Texture2D = preload("res://assets/ui/game_icons/audioOff.png")

const CHEST_ICON: String = "res://assets/sprites/tiny_dungeon/tile_0089.png"
const COIN_ICON: String = "res://assets/sprites/generated/coin.png"
const RUNE_ICONS: Array[String] = [
	"res://assets/sprites/generated/rune_1.png",
	"res://assets/sprites/generated/rune_2.png",
	"res://assets/sprites/generated/rune_3.png",
]
## Cuántas runas se dibujan como máximo en el cartel de reliquias (el contador dice el total real).
const MAX_RUNES_SHOWN: int = 8
const RUNE_SIZE: float = 80.0
## El oro achica su fuente de a este paso cuando el número no entra en su lugar, sin bajar del mínimo.
const GOLD_FONT_STEP: int = 4
const GOLD_FONT_MIN: int = 48
const CHEST_SIZE: float = 64.0

## El botón de modo pasa por estos, en este orden.
const MODE_ORDER: Array[int] = [Economy.BuyMode.X1, Economy.BuyMode.X10, Economy.BuyMode.MAX]
const MODE_NAMES: Array[String] = ["×1", "×10", "Máx"]

var _mode: int = Economy.BuyMode.X1
var _cards: Array[GeneratorCard] = []
## Se marca cuando Economy cambia; la pantalla se refresca una vez por frame, no por señal.
var _dirty: bool = true
var _modal: Modal
var _options: OptionsPanel
var _screen_fx: ScreenFx
var _music: MusicDirector
var _pick_card: PickCard
var _shown_runes: int = -1
## El último cofre que salió en esta partida ({rarity, amount}); vacío si todavía no salió ninguno.
var _last_chest: Dictionary = {}
## En el cartel de Botín, una etiqueta por rareza con lo que daría ahora.
var _odds_labels: Array[Label] = []
## Índice del bioma que se está mostrando (-1 = todavía ninguno). Bajar a uno más profundo suena.
var _shown_biome: int = -1
## Se prende al final de _ready: lo que se marca mientras se arma la escena no suena. (is_node_ready() no sirve:
## ya es true adentro de _ready.)
var _built: bool = false
## Mientras dura la vuelta a la superficie (no se puede confirmar dos veces) y cuántas reliquias muestra el contador
## mientras vuelan (-1 = las de Economy).
var _prestiging: bool = false
var _relics_shown: int = -1
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
@onready var _loot_button: SideButton = %LootButton
@onready var _relics_button: SideButton = %RelicsButton
@onready var _mode_button: SideButton = %ModeButton
@onready var _loot_panel: SidePanel = %LootPanel
@onready var _relics_panel: SidePanel = %RelicsPanel
@onready var _loot_box: VBoxContainer = %LootBox
@onready var _loot_info_label: Label = %LootInfoLabel
@onready var _chest_row: HBoxContainer = %ChestRow
@onready var _odds_row: HBoxContainer = %OddsRow
@onready var _last_loot_label: Label = %LastLootLabel
@onready var _loot_hint_label: Label = %LootHintLabel
@onready var _shop: GridContainer = %Shop
@onready var _relics_label: Label = %RelicsLabel
@onready var _relics_row: HBoxContainer = %RelicsRow
@onready var _relics_hint: Label = %RelicsHint
@onready var _prestige_button: Button = %PrestigeButton


func _ready() -> void:
	_gold_font_size = _gold_label.get_theme_font_size("font_size")
	_gold_label.resized.connect(_fit_gold_label)
	# La grilla de mejoras: primero el pico y después los generadores, todos con el mismo formato.
	_pick_card = PickCard.new()
	_shop.add_child(_pick_card)
	_pick_card.setup()
	for index: int in range(Economy.generator_count()):
		var card: GeneratorCard = GeneratorCard.new()
		_shop.add_child(card)
		card.setup(index)
		_cards.append(card)

	# Los botones del costado de la mina.
	_loot_button.build(load(CHEST_ICON) as Texture2D, "Botín")
	_relics_button.build(load(RUNE_ICONS[0]) as Texture2D, "Reliquias")
	_mode_button.build(null, "Comprar")
	_mode_button.set_big_text(MODE_NAMES[0])
	_loot_button.pressed.connect(_loot_panel.open)
	_relics_button.pressed.connect(_relics_panel.open)
	_mode_button.pressed.connect(_on_mode_pressed)

	# Reaccionan al apretar (no al soltar): un clicker tiene que responder al toque.
	_tap_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	_tap_button.button_down.connect(_on_tap)
	_prestige_button.pressed.connect(_on_prestige_pressed)

	_build_loot_panel()
	add_child(SoundCues.new())
	_music = MusicDirector.new()
	add_child(_music)

	# Solo en builds de debug; en un export de release no se crea (ver debug_panel.gd).
	DebugPanel.attach_if_debug(self, OS.is_debug_build())
	# Los carteles de Botín y Reliquias: encima del juego y del panel de debug.
	move_child(_loot_panel, -1)
	move_child(_relics_panel, -1)
	# Opciones: encima del juego y del panel de debug, debajo del cartel.
	_options = OptionsPanel.new()
	add_child(_options)
	_options.opened.connect(_music.set_options_open.bind(true))
	_options.closed.connect(_music.set_options_open.bind(false))
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
	Economy.milestone_reached.connect(_on_milestone_reached)
	_mine_view.dynamite_exploded.connect(func(_at: Vector2) -> void: Audio.play_sfx("dynamite"))
	Economy.offline_progress.connect(_show_offline_notice)
	# Guardado del navegador: la copia de la partida y sus avisos.
	_options.restore_code_entered.connect(_on_restore_code)
	Save.imported.connect(_on_save_imported)
	Economy.generator_bought.connect(_warn_fragile_storage.unbind(2))
	Economy.pick_upgraded.connect(_warn_fragile_storage.unbind(1))
	_refresh()
	_built = true

	# Si el juego arrancó con progreso offline, Economy ya lo acreditó antes de que existiera esta escena.
	if not Economy.pending_offline_report.is_empty():
		_show_offline_notice(Economy.pending_offline_report)
	check_storage()


func _process(_delta: float) -> void:
	if _dirty:
		_refresh()


func _mark_dirty() -> void:
	_dirty = true


func _on_tap() -> void:
	Economy.hit()


## Cada golpe se ve: la roca se aplasta, la mina se sacude y sale el oro que dio flotando.
func _on_hit_landed(amount: float) -> void:
	var critical: bool = Economy.last_hit_critical
	_mine_view.play_hit(("¡+%s!" if critical else "+%s") % NumberFormat.format_number(amount), critical)


## Un generador llegó a un hito: aviso en la mina y rebote de su tarjeta (el sonido lo pone SoundCues).
func _on_milestone_reached(index: int, threshold: int) -> void:
	var title: String = "¡%s ×%d!" % [Economy.generator_name(index), threshold]
	var step: float = Economy.milestone_step()
	var detail: String = "producen el doble" if is_equal_approx(step, 2.0) else "producen ×%.1f" % step
	_mine_view.show_toast(GeneratorArt.icon(Economy.generator_id(index)), title, detail, Palette.YELLOW)
	if index < _cards.size():
		Juice.bounce(_cards[index])


## Silencia todo o devuelve el sonido. El click suena solo al devolverlo (silenciado no suena nada).
func _on_sound_pressed() -> void:
	Juice.bounce(_sound_button)
	Settings.muted = not Settings.muted
	Audio.play_sfx("toggle")


## Lo que depende de las opciones: el ícono del silencio y si la mina reduce los efectos.
func _apply_settings() -> void:
	_sound_button.icon = SOUND_OFF_ICON if Settings.muted else SOUND_ON_ICON
	_mine_view.reduce_effects = Settings.reduce_effects


## El único botón de modo: cada toque pasa de ×1 a ×10, a Máx y vuelve.
func _on_mode_pressed() -> void:
	var next: int = (MODE_ORDER.find(_mode) + 1) % MODE_ORDER.size()
	_mode = MODE_ORDER[next]
	_mode_button.set_big_text(MODE_NAMES[next])
	Audio.play_sfx("mode")
	_mark_dirty()


func _refresh() -> void:
	_dirty = false
	_gold_label.text = NumberFormat.format_number(Economy.gold)
	_fit_gold_label()
	_rate_label.text = "%s oro/s" % NumberFormat.format_number(Economy.gold_per_second())
	_hit_label.text = "Golpe %s" % NumberFormat.format_number(Economy.hit_value())
	_mult_label.text = "×%.2f" % Economy.multiplier
	_refresh_depth()
	_refresh_mine()
	_refresh_odds()
	_pick_card.refresh()
	_refresh_last_loot()
	_refresh_prestige()
	_refresh_badges()
	for card: GeneratorCard in _cards:
		card.refresh(_mode)


## El aviso del botón de Reliquias: cuántas hay, o un ! cuando ya se puede volver a la superficie (para que no se
## pase por alto con el cartel cerrado). El de Botín no lleva: el cofre ya pagó.
func _refresh_badges() -> void:
	var relics: int = Economy.relics if _relics_shown < 0 else _relics_shown
	if _relics_shown < 0 and Economy.can_prestige():
		_relics_button.set_badge("!", true)
	else:
		_relics_button.set_badge(NumberFormat.format_number(relics) if relics > 0 else "")


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
		_next_biome_label.text = "» %s · %s m" % [Economy.biome_name(next), NumberFormat.format_number(Economy.next_biome_depth())]
	else:
		_next_biome_label.text = "¡Fondo!"
	# Bajar a un bioma más profundo es una novedad: el piso y la roca se funden al nuevo, sale un cartel y suena.
	# Abrir el juego o volver a la superficie cambia sin ceremonia. El director de música sigue al bioma siempre.
	var biome: int = Economy.biome_index()
	var deeper: bool = _shown_biome >= 0 and biome > _shown_biome
	var id: String = Economy.biome_id(biome)
	if biome != _shown_biome:
		_music.set_biome(id)
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
	_loot_button.visible = not table.is_empty()
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
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 22)
		label.add_theme_color_override("font_color", color)
		_odds_row.add_child(label)
		_odds_labels.append(label)
	var hint: String = "Cada cofre paga oro al instante."
	for rarity: Dictionary in table:
		if int(rarity["relics"]) > 0:
			hint += " El %s además da %s." % [str(rarity["name"]).to_lower(), _relics_phrase(rarity["relics"])]
	_loot_hint_label.text = hint
	_refresh_odds()


## Cada rareza con su probabilidad y el oro que daría si saliera ahora.
func _refresh_odds() -> void:
	var table: Array[Dictionary] = Economy.loot_table()
	for index: int in range(mini(_odds_labels.size(), table.size())):
		_odds_labels[index].text = "%s\n%s\n+%s" % [table[index]["name"], NumberFormat.format_percent(table[index]["chance"]), NumberFormat.format_number(Economy.loot_reward(index))]


func _on_loot_dropped(rarity: int, amount: float) -> void:
	_mark_dirty()
	Juice.bounce(_loot_button)
	var table: Array[Dictionary] = Economy.loot_table()
	if rarity < 0 or rarity >= table.size():
		return
	_last_chest = { "rarity": rarity, "amount": amount }
	_refresh_last_loot() # ya mismo: no hace falta esperar al próximo refresco
	_celebrate_chest(table[rarity], amount)


## El cofre cae en la mina con el brillo de su rareza, llueven monedas (más cuanto más rara) y sale un aviso con
## el oro que dio. Si dio reliquias, el botón de Reliquias rebota. El legendario además pausa un momento y destella.
func _celebrate_chest(entry: Dictionary, amount: float) -> void:
	var color: Color = _rarity_color(entry["id"])
	var special: bool = entry["id"] == SPECIAL_RARITY
	var chest_icon: Texture2D = load(CHEST_ICON) as Texture2D
	_mine_view.drop_chest(chest_icon, color, special)
	_mine_view.rain_coins(load(COIN_ICON) as Texture2D, int(COINS_BY_RARITY.get(entry["id"], DEFAULT_COINS)))
	var detail: String = "+%s de oro" % NumberFormat.format_number(amount)
	if int(entry["relics"]) > 0:
		detail += " · +%s" % _relics_phrase(entry["relics"])
		Juice.bounce(_relics_button)
		Audio.play_sfx("relic")
	_mine_view.show_toast(chest_icon, "¡Cofre %s!" % entry["name"], detail, color)
	if special:
		_screen_fx.hit_stop(SPECIAL_PAUSE, SPECIAL_SLOW)
		if not Settings.reduce_effects:
			_screen_fx.flash(SPECIAL_FLASH, SPECIAL_FLASH_FADE)


## El aviso del último cofre sale del estado, no solo de la señal del cofre: en una partida sin nada ganado
## (volver a la superficie, reiniciar) no queda un cofre viejo.
func _refresh_last_loot() -> void:
	var table: Array[Dictionary] = Economy.loot_table()
	if table.is_empty():
		return
	if Economy.run_gold <= 0.0 or _last_chest.is_empty() or int(_last_chest["rarity"]) >= table.size():
		_last_chest = {}
		_last_loot_label.text = "Todavía no salió ningún cofre"
		_last_loot_label.remove_theme_color_override("font_color")
		return
	var entry: Dictionary = table[int(_last_chest["rarity"])]
	var text: String = "¡Cofre %s! +%s de oro" % [entry["name"], NumberFormat.format_number(_last_chest["amount"])]
	if int(entry["relics"]) > 0:
		text += " y %s" % _relics_phrase(entry["relics"])
	_last_loot_label.text = text
	_last_loot_label.add_theme_color_override("font_color", _rarity_color(entry["id"]))


func _rarity_color(id: String) -> Color:
	return RARITY_COLORS.get(id, DEFAULT_RARITY_COLOR)


# --- Reliquias y prestigio ---------------------------------------------------

func _refresh_prestige() -> void:
	var relics: int = Economy.relics if _relics_shown < 0 else _relics_shown
	var relics_text: String = "Reliquias: %d" % relics
	if relics > 0:
		relics_text += " · +%s de oro" % NumberFormat.format_percent(relics * Economy.relic_bonus())
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
	var wanted: int = mini(Economy.relics if _relics_shown < 0 else _relics_shown, MAX_RUNES_SHOWN)
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
	var body: String = "Estás a %d m (%s).\n\nGanás %s: +%s de oro permanente (en total ×%.2f).\n\nVolvés a la superficie sin oro, sin cuadrilla y con el pico en nivel 0. Las reliquias te quedan para siempre." % [
		int(floorf(Economy.depth())),
		Economy.biome_name(Economy.biome_index()),
		_relics_phrase(gain),
		NumberFormat.format_percent(gain * Economy.relic_bonus()),
		Economy.relic_multiplier_for(Economy.relics + gain),
	]
	_modal.open("¿Volver a la superficie?", body, "Sí, volver", "Seguir cavando", _confirm_prestige, &"ButtonRed")


## Volver a la superficie: la pantalla se funde a blanco (a oscuro con "reducir efectos") y recién ahí se reinicia
## la partida, así no se ve el oro bajar a 0. Al aclarar, las reliquias ganadas vuelan desde el centro al
## contador, que suma una por cada una que llega.
func _confirm_prestige() -> void:
	if _prestiging:
		return
	_prestiging = true
	_relics_panel.close() # las reliquias ganadas vuelan al botón del costado
	_music.begin_prestige()
	await _screen_fx.cover(PRESTIGE_DARK if Settings.reduce_effects else PRESTIGE_WHITE, PRESTIGE_FADE_IN)
	var before: int = Economy.relics
	var gained: int = Economy.prestige()
	_mine_view.clear_effects()
	_relics_shown = before
	_refresh()
	_screen_fx.uncover(PRESTIGE_FADE_OUT)
	await _fly_relics(before, gained)
	_relics_shown = -1
	_prestiging = false
	_music.end_prestige()
	_mark_dirty()


## Las reliquias ganadas (hasta MAX_FLYING_RELICS figuras) vuelan al contador; cada una que llega lo sube. Si se
## ganaron más que figuras, cada figura suma su parte y la última deja el total.
func _fly_relics(before: int, gained: int) -> void:
	var figures: int = mini(gained, MAX_FLYING_RELICS)
	if figures <= 0:
		return
	var target_control: Control = _relics_label if _relics_label.is_visible_in_tree() else _relics_button
	var target: Vector2 = target_control.get_global_rect().get_center() - _screen_fx.get_global_rect().position
	var origin: Vector2 = _screen_fx.size * 0.5
	var arrived: Array[int] = [0]
	for index: int in range(figures):
		var spread: Vector2 = Vector2.RIGHT.rotated(TAU * index / figures) * RELIC_SPREAD * minf(figures - 1, 1)
		var on_arrive: Callable = func() -> void:
			arrived[0] += 1
			_relics_shown = before + int(roundf(gained * float(arrived[0]) / figures))
			_refresh_prestige()
			_refresh_badges()
			Juice.bounce(target_control)
			Audio.play_sfx("relic")
		_screen_fx.fly(load(RUNE_ICONS[index % RUNE_ICONS.size()]) as Texture2D, origin + spread, target, RUNE_SIZE, PRESTIGE_FADE_OUT * 0.5 + index * RELIC_STAGGER, RELIC_FLIGHT_TIME, on_arrive)
	var deadline: float = PRESTIGE_FADE_OUT * 0.5 + figures * RELIC_STAGGER + RELIC_FLIGHT_TIME + 0.3
	await get_tree().create_timer(deadline).timeout


# --- Guardado en el navegador --------------------------------------------------

## Si el navegador no deja guardar nada, se dice apenas se abre: mejor saberlo antes de jugar media hora.
func check_storage() -> void:
	if not _options.platform.storage_blocked():
		return
	_modal.open("No se puede guardar", "Este navegador no deja guardar: al cerrar se pierde la partida.\n\nProbá sin modo privado, con las cookies permitidas, o en otro navegador.", "Entendido")


## En iPhone dentro de itch.io el navegador puede borrar la partida: se avisa una vez, recién con la primera compra
## (ya hay algo que perder y no interrumpe la entrada al juego).
func _warn_fragile_storage() -> void:
	if Settings.storage_notice_seen or _modal.visible or _prestiging or not _options.platform.has_fragile_storage():
		return
	Settings.storage_notice_seen = true
	_modal.open("Cuidá tu partida", "En iPhone y iPad el navegador puede borrar la partida al cerrarlo.\n\nGuardá una copia cada tanto (Opciones » Guardar copia), y jugá sin modo privado y siempre desde el mismo navegador.",
		"Guardar copia", "Después", _options.show_backup)


func _on_restore_code(code: String) -> void:
	if code.strip_edges() == "" or _prestiging:
		return
	var data: Dictionary = Save.read_code(code)
	if data.is_empty():
		_modal.open("Ese código no sirve", "Copialo entero, tal como te lo dio el juego, y probá de nuevo.", "Entendido")
		return
	var age: float = maxf(Time.get_unix_time_from_system() - float(data.get("saved_at", 0.0)), 0.0)
	_modal.open("¿Restaurar esta partida?", "La copia es de hace %s.\n\nSe reemplaza la partida de ahora por la de la copia." % NumberFormat.format_duration(age),
		"Sí, restaurar", "No", func() -> void: Save.import_code(code))


## La partida cambió de golpe: la pantalla se arma de nuevo sin festejos (ni cartel de bioma ni último cofre).
func _on_save_imported() -> void:
	Economy.dismiss_offline_report()
	_options.close()
	_mine_view.clear_effects()
	_shown_biome = -1
	_last_chest = {}
	_refresh()


# --- Progreso offline --------------------------------------------------------

func _show_offline_notice(report: Dictionary) -> void:
	var gold_text: String = NumberFormat.format_number(report["gold"])
	var rate_text: String = NumberFormat.format_percent(Economy.offline_efficiency())
	var body: String
	if report["capped"]:
		body = "Estuviste fuera mucho tiempo. Tu cuadrilla trabajó el máximo de %s, al %s, y juntó %s de oro." % [
			NumberFormat.format_duration(Economy.offline_max_seconds()), rate_text, gold_text]
	else:
		body = "Estuviste fuera %s. Sin vos la cuadrilla rinde al %s, y juntó %s de oro." % [
			NumberFormat.format_duration(report["seconds"]), rate_text, gold_text]
	_modal.open("¡Bienvenido de vuelta!", body, "¡A seguir!", "", Economy.dismiss_offline_report)
	_modal.celebrate(report["gold"], NumberFormat.format_number, load(COIN_ICON) as Texture2D, Settings.reduce_effects)
