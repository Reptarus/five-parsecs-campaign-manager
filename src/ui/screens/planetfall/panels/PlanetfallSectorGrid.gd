extends VBoxContainer

## The colony's campaign map (Planetfall pp.52-54), drawn the way p.53 tells a player to
## mark a paper one: "H" for the colony, "?" for an Investigation Site, the Resource and
## Hazard levels ("R3 H5"), enemy occupation by colour, "S" for a Strongpoint, "A" for an
## Ancient Sign. Rows and columns are numbered because p.52 picks random sectors with
## them. PlanetfallMap owns every value shown here; this only reads it.
##
## View only by default. set_selectable(keys) makes those sectors tappable for a step that
## asks the player to pick one (a Scout explore, a mission site), and sector_selected
## fires with the key.

signal sector_selected(sector_key: String)

const MapScript := preload("res://src/core/systems/PlanetfallMap.gd")
const TouchScrollOpenerRef := preload("res://src/ui/components/common/TouchScrollOpener.gd")

const CELL_MIN := 52
## The smallest square that is still a 48 dp touch target at the shipped 1.16 effective
## scale (42 x 1.16 = 48.7 dp). It was 40, which is 46.4 dp, so on every portrait screen
## all 36 cells of a 6 x 6 map failed the touch floor (verify_layout, 2026-10-28).
const CELL_PHONE := 42
const HEADER_MIN := 24
const FONT_SIZE_CELL := 11
const FONT_SIZE_LEGEND := 12
## One colour per Tactical Enemy, in campaign order (p.53 "a specific color ... for each
## enemy"). Red is kept for the first because an enemy is a threat.
const ENEMY_COLORS := [UIColors.COLOR_RED, UIColors.COLOR_AMBER, UIColors.COLOR_PURPLE,
		UIColors.COLOR_CYAN]

var _campaign: Resource = null
var _selectable: Array = []
var _selected: String = ""
var _grid: GridContainer = null
var _legend: HFlowContainer = null
var _cells: Dictionary = {}


func _ready() -> void:
	add_theme_constant_override("separation", 8)


## Draw `campaign`'s map. A map that was never built (every save before 2026-10-28) is
## shown as it stands; the phase manager builds it at the next turn step.
func show_map(campaign: Resource) -> void:
	_campaign = campaign
	_rebuild()


func set_selectable(keys: Array) -> void:
	_selectable = keys.duplicate()
	_rebuild()


func set_selected(sector_key: String) -> void:
	_selected = sector_key
	_rebuild()


## All three at once, so a screen that redraws on every pick rebuilds the cells once.
func configure(campaign: Resource, selectable: Array, selected: String) -> void:
	_campaign = campaign
	_selectable = selectable.duplicate()
	_selected = selected
	_rebuild()


func get_selected() -> String:
	return _selected


func refresh() -> void:
	_rebuild()


## What one sector shows, for the cell and for a test: {marks, levels, status,
## enemy_index, tooltip}. Pure: reads the campaign and nothing else.
static func describe(campaign: Resource, sector_key: String) -> Dictionary:
	var md: Dictionary = campaign.map_data if campaign and "map_data" in campaign else {}
	var s: Dictionary = MapScript.sector(md, sector_key)
	var status: String = MapScript.status(md, sector_key)
	var marks: Array = []
	var notes: Array = []
	if sector_key == MapScript.home_key(md):
		marks.append("H")
		notes.append("your colony")
	if bool(s.get("investigation", false)):
		marks.append("?")
		notes.append("Investigation Site")
	if bool(s.get("ancient_sign", false)):
		marks.append("A")
		notes.append("Ancient Sign")
	if bool(s.get("ancient_site", false)):
		marks.append("Site")
		notes.append("Ancient Site")
	var holder: int = MapScript.occupant(campaign, sector_key) if campaign else -1
	var enemies: Array = MapScript.active_indices(campaign) if campaign else []
	for i in enemies:
		var em: Dictionary = MapScript.enemy_marks(campaign, i)
		if str(em.strongpoint) == sector_key:
			marks.append("S")
			notes.append("%s Strongpoint" % MapScript.enemy_name(campaign, i))
		if str(em.boss) == sector_key:
			marks.append("B")
			notes.append("%s Boss tracked here" % MapScript.enemy_name(campaign, i))
	var levels: String = ""
	if status != "unexplored":
		levels = "R%d H%d" % [int(s.get("resource", 0)), int(s.get("hazard", 0))]
		notes.append("%s, Resource %d, Hazard %d" % [status.capitalize(),
				int(s.get("resource", 0)), int(s.get("hazard", 0))])
	else:
		notes.append("Unexplored")
	if holder >= 0:
		notes.append("held by %s" % MapScript.enemy_name(campaign, holder))
	return {
		"marks": " ".join(PackedStringArray(marks)),
		"levels": levels,
		"status": status,
		"enemy_index": holder,
		"tooltip": "%s: %s." % [MapScript.label(sector_key), ", ".join(PackedStringArray(notes))],
	}


func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_cells.clear()
	_grid = null
	_legend = null
	if _campaign == null or not "map_data" in _campaign:
		return
	var md: Dictionary = _campaign.map_data
	var rows: int = MapScript.rows(md)
	var cols: int = MapScript.cols(md)

	# A 6 x 6 map is ~354 px wide and a 10 x 10 one ~574 px, against a ~340 px phone
	# column. The grid sits in a sideways scroller (horizontal AUTO does not push its
	# minimum width up the tree, so the page never runs off the screen) and is centred
	# when it fits; on a phone the cells also shrink so a 6 x 6 map fits without scrolling.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	_grid = GridContainer.new()
	_grid.columns = cols + 1
	_grid.add_theme_constant_override("h_separation", 3)
	_grid.add_theme_constant_override("v_separation", 3)
	center.add_child(_grid)

	# p.52: "the rows and columns should be numbered, allowing you to select random
	# sectors through dice rolls".
	_grid.add_child(_header_label(""))
	for c in range(cols):
		_grid.add_child(_header_label("C%d" % (c + 1)))
	for r in range(rows):
		_grid.add_child(_header_label("R%d" % (r + 1)))
		for c in range(cols):
			var k: String = MapScript.key(r, c)
			var cell: Button = _make_cell(k)
			_cells[k] = cell
			_grid.add_child(cell)

	_legend = HFlowContainer.new()
	_legend.add_theme_constant_override("h_separation", 14)
	_legend.add_theme_constant_override("v_separation", 4)
	add_child(_legend)
	for entry in [["H", "Colony"], ["?", "Investigation Site"], ["A", "Ancient Sign"],
			["Site", "Ancient Site"], ["S", "Strongpoint"], ["B", "Boss tracked"],
			["R/H", "Resource / Hazard"]]:
		_legend.add_child(_legend_label("%s: %s" % entry, UIColors.COLOR_TEXT_SECONDARY))
	_legend.add_child(_legend_label("Dark cell: Exploited", UIColors.COLOR_TEXT_SECONDARY))
	for i in MapScript.active_indices(_campaign):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var swatch := ColorRect.new()
		swatch.color = _enemy_color(i)
		swatch.custom_minimum_size = Vector2(12, 12)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(swatch)
		row.add_child(_legend_label(MapScript.enemy_name(_campaign, i), _enemy_color(i)))
		_legend.add_child(row)
	TouchScrollOpenerRef.open_subtree(self)


func _make_cell(k: String) -> Button:
	var d: Dictionary = describe(_campaign, k)
	var btn := Button.new()
	var side: int = _cell_size()
	btn.custom_minimum_size = Vector2(side, side)
	btn.text = "%s\n%s" % [d.marks, d.levels] if str(d.levels) != "" else str(d.marks)
	btn.tooltip_text = str(d.tooltip)
	btn.clip_text = true
	btn.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_CELL))
	btn.focus_mode = Control.FOCUS_NONE
	var pickable: bool = _selectable.has(k)
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(4)
	style.bg_color = UIColors.COLOR_PRIMARY if d.status == "exploited" \
			else (UIColors.COLOR_TERTIARY if d.status == "explored" else UIColors.COLOR_SECONDARY)
	var holder: int = int(d.enemy_index)
	var border: Color = UIColors.COLOR_BORDER
	var width: int = 1
	# A pickable sector is marked first, so the colony and an enemy's colour still show
	# on a sector the player may also tap: at turn 1 every sector is pickable, and the
	# colony's border used to disappear under the highlight.
	if pickable:
		border = UIColors.COLOR_FOCUS
		width = 3
	if holder >= 0:
		border = _enemy_color(holder)
		width = 3
	if k == MapScript.home_key(_campaign.map_data):
		border = UIColors.COLOR_EMERALD
		width = 3
	if k == _selected:
		border = UIColors.COLOR_TEXT_PRIMARY
		width = 4
	style.border_color = border
	style.set_border_width_all(width)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		btn.add_theme_stylebox_override(state, style)
	var text_color: Color = UIColors.COLOR_TEXT_PRIMARY
	if not _selectable.is_empty() and not pickable:
		# A step is asking for a pick and this sector is not one of the answers.
		btn.modulate = Color(1, 1, 1, 0.45)
	for state in ["font_color", "font_hover_color", "font_pressed_color",
			"font_disabled_color"]:
		btn.add_theme_color_override(state, text_color)
	if pickable:
		btn.pressed.connect(func() -> void:
			_selected = k
			_rebuild()
			sector_selected.emit(k))
	return btn


## CELL_MIN on a tablet; CELL_PHONE where the layout collapses to one column, so a 6 x 6
## map fits a phone without scrolling. Orientation from ResponsiveManager, never from the
## viewport rect (CLAUDE.md: get_visible_rect() cannot tell a phone from a tablet).
func _cell_size() -> int:
	var rm: Node = get_node_or_null("/root/ResponsiveManager") if is_inside_tree() else null
	if rm and rm.has_method("should_collapse_to_single_column") \
			and rm.should_collapse_to_single_column():
		return CELL_PHONE
	return CELL_MIN


func _enemy_color(idx: int) -> Color:
	var order: int = MapScript.active_indices(_campaign).find(idx)
	return ENEMY_COLORS[maxi(order, 0) % ENEMY_COLORS.size()]


func _header_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(HEADER_MIN, HEADER_MIN)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_CELL))
	lbl.add_theme_color_override("font_color", UIColors.COLOR_TEXT_SECONDARY)
	return lbl


func _legend_label(text: String, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_LEGEND))
	lbl.add_theme_color_override("font_color", color)
	return lbl
