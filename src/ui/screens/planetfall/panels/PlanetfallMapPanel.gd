extends Control

## Planetfall Creation Step 4: Creating Your Map (pp.52-53).
## The player picks the grid size (p.52: "The default is a 6 x 6 grid ... 6 x 10 (60
## sectors) or even 10 x 10 (100 sectors)") and the home sector (p.53: "Pick a home sector
## (or roll randomly)"). The Investigation Sites are NOT placed here: the coordinator rolls
## them once when the colony is founded (PlanetfallMap.generate), so a player stepping
## back and forth cannot re-roll them, and the expedition's extra sites (p.52 Corporate
## Funded) are counted. Until 2026-10-28 this step placed 10 sites with raw randi(),
## re-rolled a taken sector instead of taking an adjacent one, and dropped the extras.

signal map_updated(data: Dictionary)

const MapScript := preload("res://src/core/systems/PlanetfallMap.gd")
const SectorGridScript := preload("res://src/ui/screens/planetfall/panels/PlanetfallSectorGrid.gd")
const TouchScrollOpenerRef := preload("res://src/ui/components/common/TouchScrollOpener.gd")

const SIZES := [
	{"label": "6 x 6 (default, 36 sectors)", "rows": 6, "cols": 6},
	{"label": "6 x 10 (60 sectors)", "rows": 6, "cols": 10},
	{"label": "10 x 10 (100 sectors)", "rows": 10, "cols": 10},
]

var _coordinator = null
var _rows: int = 0
var _cols: int = 0
var _home: Array = []
## A campaign object that exists only to hold the preview map the grid draws.
var _preview: PlanetfallCampaignCore = null
var _content: VBoxContainer = null
var _grid: Control = null
var _status: Label = null
var _size_buttons: Array = []


func set_coordinator(coord) -> void:
	_coordinator = coord


func _ready() -> void:
	_build()


func _build() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 16)
	scroll.add_child(_content)

	var header := Label.new()
	header.text = "CREATING YOUR MAP"
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_theme_font_size_override("font_size", ScreenChrome.font_size(18))
	header.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	_content.add_child(header)

	var desc := Label.new()
	desc.text = ("Choose the size of the map around your landing site, then pick the sector "
			+ "your colony stands in. %d Investigation Sites (more for a Corporate Funded "
			% MapScript.INVESTIGATION_SITES + "expedition) are placed at random when the "
			+ "colony is founded (pp.52-53).")
	desc.add_theme_font_size_override("font_size", ScreenChrome.font_size(14))
	desc.add_theme_color_override("font_color", UIColors.COLOR_TEXT_SECONDARY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(desc)

	for opt in SIZES:
		var btn := Button.new()
		btn.text = str(opt.label)
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(0, 48)
		var r: int = int(opt.rows)
		var c: int = int(opt.cols)
		btn.pressed.connect(func() -> void: _on_size_selected(r, c))
		_content.add_child(btn)
		_size_buttons.append(btn)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", ScreenChrome.font_size(14))
	_status.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	_content.add_child(_status)

	var roll_btn := Button.new()
	roll_btn.text = "Roll the home sector randomly"
	roll_btn.custom_minimum_size = Vector2(0, 48)
	roll_btn.pressed.connect(_on_roll_home)
	_content.add_child(roll_btn)

	_grid = SectorGridScript.new()
	# Fill: the grid centres itself and scrolls sideways inside its own width.
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.sector_selected.connect(_on_home_picked)
	_content.add_child(_grid)

	_refresh()
	TouchScrollOpenerRef.open_subtree(self)


func _on_size_selected(rows: int, cols: int) -> void:
	_rows = rows
	_cols = cols
	_home = []
	_refresh()


## p.53 "(or roll randomly)": the row and column dice, through DiceManager.
func _on_roll_home() -> void:
	if _rows <= 0:
		_on_size_selected(MapScript.DEFAULT_SIZE, MapScript.DEFAULT_SIZE)
	var k: String = MapScript.random_sector(_preview.map_data)
	_on_home_picked(k)


func _on_home_picked(sector_key: String) -> void:
	_home = MapScript.coords(sector_key)
	_refresh()
	map_updated.emit({
		"grid_size": [_rows, _cols], "grid_rows": _rows, "grid_cols": _cols,
		"home_sector": _home.duplicate(),
	})


func _refresh() -> void:
	for i in range(_size_buttons.size()):
		var opt: Dictionary = SIZES[i]
		(_size_buttons[i] as Button).set_pressed_no_signal(
				int(opt.rows) == _rows and int(opt.cols) == _cols)
	if _rows <= 0:
		_status.text = "Choose a map size."
		_grid.visible = false
		return
	if _preview == null:
		_preview = PlanetfallCampaignCore.new()
	var md: Dictionary = {"grid_size": [_rows, _cols], "sectors": {}}
	if _home.size() >= 2:
		md["home_sector"] = _home.duplicate()
	_preview.map_data = md
	_grid.visible = true
	_grid.show_map(_preview)
	_grid.set_selectable(MapScript.all_keys(md))
	if _home.size() >= 2:
		_grid.set_selected(MapScript.key(int(_home[0]), int(_home[1])))
		_status.text = "Home sector: %s. Tap another sector to move it." % MapScript.label(
				MapScript.key(int(_home[0]), int(_home[1])))
	else:
		_status.text = "Tap the sector your colony stands in, or roll for it."
