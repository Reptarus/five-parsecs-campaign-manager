extends PanelContainer

## Visual 4x4 Battlefield Grid Panel for Tactical Companion
## Shows an overhead view of the 16-sector battlefield with terrain features,
## deployment zones, and cover indicators. Designed as a tabletop reference.

signal regenerate_requested
signal sector_clicked(sector_label: String, features: Array)
signal view_mode_changed(is_map_view: bool)

# Grid layout constants
const GRID_COLUMNS := 4
const GRID_ROWS := 4
const ROW_LABELS := ["A", "B", "C", "D"]
const COL_LABELS := ["1", "2", "3", "4"]
const FEATURE_TRUNCATE_LEN := 45

# Color palette (matching deep space theme)
const COLOR_CELL_EMPTY := Color(0.08, 0.08, 0.14, 0.9)
const COLOR_CELL_FEATURES := Color(0.12, 0.14, 0.22, 0.9)
const COLOR_BORDER_NOTABLE := Color(0.063, 0.725, 0.314, 0.8)
const COLOR_BORDER_NORMAL := Color(0.227, 0.227, 0.361, 0.5)
const COLOR_ZONE_CREW := Color(0.176, 0.353, 0.482, 1.0)
const COLOR_ZONE_ENEMY := Color(0.545, 0.153, 0.153, 1.0)
const COLOR_TEXT_PRIMARY := Color(0.878, 0.878, 0.878, 1.0)
const COLOR_TEXT_SECONDARY := Color(0.502, 0.502, 0.502, 1.0)
const COLOR_TEXT_DIM := Color(0.251, 0.251, 0.251, 1.0)
const COLOR_NOTABLE := Color(0.063, 0.725, 0.506, 1.0)
const COLOR_SCATTER := Color(0.502, 0.502, 0.502, 1.0)
const COLOR_COVER_FULL := Color(0.063, 0.725, 0.506, 1.0)
const COLOR_COVER_PARTIAL := Color(0.851, 0.467, 0.024, 1.0)
const COLOR_STAR := Color(0.961, 0.62, 0.043, 1.0)
const COLOR_HEADER_BG := Color(0.102, 0.102, 0.18, 1.0)
const COLOR_THEME_TEXT := Color(0.961, 0.62, 0.043, 1.0)

# Shared shape drawing library
var _shape_library := BattlefieldShapeLibrary.new()

# Internal state
var _sector_features: Dictionary = {}  # sector_label -> Array of feature strings
var _is_collapsed: bool = false
var _current_theme_name: String = ""

# Node refs built in _ready
var _main_vbox: VBoxContainer
var _header_bar: HBoxContainer
var _theme_label: Label
var _collapse_button: Button
var _regen_button: Button
var _grid_scroll: ScrollContainer
var _grid_container: GridContainer
var _detail_panel: PanelContainer
var _detail_label: RichTextLabel
var _popover: PanelContainer
var _popover_label: RichTextLabel
var _popover_close_btn: Button
var _tab_bar: TabBar
var _map_view: BattlefieldMapView
var _current_sectors: Array = []  # Cached for tab switching

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Panel styling
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.067, 0.094, 0.153, 0.85)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.216, 0.255, 0.318, 0.5)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.corner_radius_bottom_left = 12
	add_theme_stylebox_override("panel", panel_style)

	_main_vbox = VBoxContainer.new()
	_main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_vbox.add_theme_constant_override("separation", 4)
	add_child(_main_vbox)

	# Header bar: title + theme + buttons
	_build_header_bar()

	# Grid area in scroll container
	_grid_scroll = ScrollContainer.new()
	_grid_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_grid_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_main_vbox.add_child(_grid_scroll)

	# Map view (overhead grid) — hidden by default, shown via tab toggle
	_map_view = BattlefieldMapView.new()
	_map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_view.custom_minimum_size = Vector2(640, 420)
	_map_view.visible = false
	_map_view.show_unit_markers = true
	_main_vbox.add_child(_map_view)

	var grid_wrapper := VBoxContainer.new()
	grid_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_wrapper.custom_minimum_size = Vector2(640, 0)
	_grid_scroll.add_child(grid_wrapper)

	# Column headers row
	var col_header_row := HBoxContainer.new()
	col_header_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_header_row.add_theme_constant_override("separation", 4)
	grid_wrapper.add_child(col_header_row)

	# Empty corner cell for row labels column
	var corner := Control.new()
	corner.custom_minimum_size = Vector2(40, 24)
	col_header_row.add_child(corner)

	for col_label: String in COL_LABELS:
		var lbl := Label.new()
		lbl.text = col_label
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		col_header_row.add_child(lbl)

	# Grid with row labels
	var grid_with_rows := HBoxContainer.new()
	grid_with_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_with_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_with_rows.add_theme_constant_override("separation", 4)
	grid_wrapper.add_child(grid_with_rows)

	# Row labels column
	var row_labels_col := VBoxContainer.new()
	row_labels_col.custom_minimum_size = Vector2(40, 0)
	row_labels_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row_labels_col.add_theme_constant_override("separation", 4)
	grid_with_rows.add_child(row_labels_col)

	for i: int in range(GRID_ROWS):
		var row_panel := PanelContainer.new()
		row_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

		var row_style := StyleBoxFlat.new()
		if i < 2:
			row_style.bg_color = COLOR_ZONE_CREW.darkened(0.6)
		else:
			row_style.bg_color = COLOR_ZONE_ENEMY.darkened(0.6)
		row_style.corner_radius_top_left = 4
		row_style.corner_radius_bottom_left = 4
		row_panel.add_theme_stylebox_override("panel", row_style)

		var row_vbox := VBoxContainer.new()
		row_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		row_panel.add_child(row_vbox)

		var row_lbl := Label.new()
		row_lbl.text = ROW_LABELS[i]
		row_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row_lbl.add_theme_font_size_override("font_size", 16)
		row_lbl.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
		row_vbox.add_child(row_lbl)

		var zone_lbl := Label.new()
		zone_lbl.text = "CREW" if i < 2 else "ENEMY"
		zone_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		zone_lbl.add_theme_font_size_override("font_size", 9)
		zone_lbl.add_theme_color_override("font_color",
			COLOR_ZONE_CREW if i < 2 else COLOR_ZONE_ENEMY)
		row_vbox.add_child(zone_lbl)

		row_labels_col.add_child(row_panel)

	# The 4x4 grid
	_grid_container = GridContainer.new()
	_grid_container.columns = GRID_COLUMNS
	_grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid_container.add_theme_constant_override("h_separation", 4)
	_grid_container.add_theme_constant_override("v_separation", 4)
	grid_with_rows.add_child(_grid_container)

	# Detail panel below grid (shows selected sector info)
	_detail_panel = PanelContainer.new()
	_detail_panel.custom_minimum_size = Vector2(0, 48)
	_detail_panel.visible = false
	var detail_style := StyleBoxFlat.new()
	detail_style.bg_color = Color(0.102, 0.102, 0.18, 0.9)
	detail_style.border_width_top = 1
	detail_style.border_color = Color(0.216, 0.255, 0.318, 0.5)
	detail_style.content_margin_left = 12.0
	detail_style.content_margin_right = 12.0
	detail_style.content_margin_top = 6.0
	detail_style.content_margin_bottom = 6.0
	_detail_panel.add_theme_stylebox_override("panel", detail_style)
	_main_vbox.add_child(_detail_panel)

	_detail_label = RichTextLabel.new()
	_detail_label.bbcode_enabled = true
	_detail_label.fit_content = true
	_detail_label.scroll_active = false
	_detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_label.add_theme_color_override("default_color", COLOR_TEXT_PRIMARY)
	_detail_label.add_theme_font_size_override("normal_font_size", 13)
	_detail_panel.add_child(_detail_label)

	# Popover (hidden, shown on cell click)
	_build_popover()

func _build_header_bar() -> void:
	_header_bar = HBoxContainer.new()
	_header_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_bar.add_theme_constant_override("separation", 12)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 2)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(_header_bar)
	_main_vbox.add_child(margin)

	var title := Label.new()
	title.text = "BATTLEFIELD OVERVIEW"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	title.uppercase = true
	_header_bar.add_child(title)

	_theme_label = Label.new()
	_theme_label.text = ""
	_theme_label.add_theme_font_size_override("font_size", 14)
	_theme_label.add_theme_color_override("font_color", COLOR_THEME_TEXT)
	_header_bar.add_child(_theme_label)

	# View mode tab bar
	_tab_bar = TabBar.new()
	_tab_bar.add_tab("Sector View")
	_tab_bar.add_tab("Map View")
	_tab_bar.current_tab = 0
	_tab_bar.tab_changed.connect(_on_view_tab_changed)
	_tab_bar.add_theme_font_size_override("font_size", 12)
	_header_bar.add_child(_tab_bar)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_bar.add_child(spacer)

	_regen_button = Button.new()
	_regen_button.text = "Regenerate"
	_regen_button.custom_minimum_size = Vector2(0, 32)
	_regen_button.add_theme_font_size_override("font_size", 12)
	_regen_button.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	var regen_style := StyleBoxFlat.new()
	regen_style.bg_color = Color(0.122, 0.137, 0.216, 0.8)
	regen_style.border_width_left = 1
	regen_style.border_width_top = 1
	regen_style.border_width_right = 1
	regen_style.border_width_bottom = 1
	regen_style.border_color = Color(0.216, 0.255, 0.318, 1)
	regen_style.corner_radius_top_left = 6
	regen_style.corner_radius_top_right = 6
	regen_style.corner_radius_bottom_right = 6
	regen_style.corner_radius_bottom_left = 6
	regen_style.content_margin_left = 12.0
	regen_style.content_margin_right = 12.0
	regen_style.content_margin_top = 4.0
	regen_style.content_margin_bottom = 4.0
	_regen_button.add_theme_stylebox_override("normal", regen_style)
	_regen_button.pressed.connect(func(): regenerate_requested.emit())
	_header_bar.add_child(_regen_button)

	_collapse_button = Button.new()
	_collapse_button.text = "Collapse"
	_collapse_button.custom_minimum_size = Vector2(0, 32)
	_collapse_button.add_theme_font_size_override("font_size", 12)
	_collapse_button.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_collapse_button.add_theme_stylebox_override("normal", regen_style.duplicate())
	_collapse_button.pressed.connect(_toggle_collapse)
	_header_bar.add_child(_collapse_button)

func _build_popover() -> void:
	_popover = PanelContainer.new()
	_popover.visible = false
	_popover.custom_minimum_size = Vector2(400, 0)
	_popover.z_index = 10

	var pop_style := StyleBoxFlat.new()
	pop_style.bg_color = Color(0.102, 0.102, 0.18, 0.95)
	pop_style.border_width_left = 2
	pop_style.border_width_top = 2
	pop_style.border_width_right = 2
	pop_style.border_width_bottom = 2
	pop_style.border_color = COLOR_NOTABLE
	pop_style.corner_radius_top_left = 8
	pop_style.corner_radius_top_right = 8
	pop_style.corner_radius_bottom_right = 8
	pop_style.corner_radius_bottom_left = 8
	pop_style.content_margin_left = 16.0
	pop_style.content_margin_right = 16.0
	pop_style.content_margin_top = 12.0
	pop_style.content_margin_bottom = 12.0
	pop_style.shadow_color = Color(0, 0, 0, 0.4)
	pop_style.shadow_size = 8
	_popover.add_theme_stylebox_override("panel", pop_style)

	var pop_vbox := VBoxContainer.new()
	pop_vbox.add_theme_constant_override("separation", 8)
	_popover.add_child(pop_vbox)

	_popover_label = RichTextLabel.new()
	_popover_label.bbcode_enabled = true
	_popover_label.fit_content = true
	_popover_label.scroll_active = false
	_popover_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_popover_label.add_theme_color_override("default_color", COLOR_TEXT_PRIMARY)
	_popover_label.add_theme_font_size_override("normal_font_size", 14)
	pop_vbox.add_child(_popover_label)

	_popover_close_btn = Button.new()
	_popover_close_btn.text = "Dismiss"
	_popover_close_btn.custom_minimum_size = Vector2(0, 32)
	_popover_close_btn.add_theme_font_size_override("font_size", 12)
	_popover_close_btn.pressed.connect(func(): _popover.visible = false)
	pop_vbox.add_child(_popover_close_btn)

	add_child(_popover)

## Public API: Populate the grid with sector data from BattlefieldGenerator
func populate(sectors: Array, theme_name: String = "") -> void:
	_current_theme_name = theme_name
	_current_sectors = sectors.duplicate()
	_theme_label.text = theme_name
	_sector_features.clear()

	# Clear existing grid cells
	for child in _grid_container.get_children():
		child.queue_free()

	# Store features and build cells
	for sector: Dictionary in sectors:
		var label: String = sector.get("label", "??")
		var features: Array = sector.get("features", [])
		_sector_features[label] = features

	# Build cells in grid order (A1, A2, A3, A4, B1, B2, ...)
	for row_idx: int in range(GRID_ROWS):
		for col_idx: int in range(GRID_COLUMNS):
			var sector_label: String = ROW_LABELS[row_idx] + COL_LABELS[col_idx]
			var features: Array = _sector_features.get(sector_label, [])
			var cell := _build_sector_cell(sector_label, features, row_idx)
			_grid_container.add_child(cell)

	# Feed map view with the same data
	_map_view.populate_from_sectors(sectors, theme_name)

	# Hide detail panel until a cell is clicked
	_detail_panel.visible = false
	_popover.visible = false

## Collapse the grid, showing only the header bar
func collapse() -> void:
	_is_collapsed = true
	_grid_scroll.visible = false
	_map_view.visible = false
	_detail_panel.visible = false
	_popover.visible = false
	_collapse_button.text = "Expand"

## Expand the grid back to full view
func expand() -> void:
	_is_collapsed = false
	# Restore visibility based on current tab
	var is_map: bool = _tab_bar.current_tab == 1
	_grid_scroll.visible = not is_map
	_map_view.visible = is_map
	_collapse_button.text = "Collapse"

func _toggle_collapse() -> void:
	if _is_collapsed:
		expand()
	else:
		collapse()

## Handle view mode tab change
func _on_view_tab_changed(tab_idx: int) -> void:
	var is_map: bool = tab_idx == 1
	if not _is_collapsed:
		_grid_scroll.visible = not is_map
		_map_view.visible = is_map
	# Hide sector-specific UI when switching to map
	if is_map:
		_detail_panel.visible = false
		_popover.visible = false
	view_mode_changed.emit(is_map)

## Route unit positions to the map view for tactical display
func set_unit_positions(units: Array) -> void:
	_map_view.set_unit_positions(units)

## Build a single sector cell
func _build_sector_cell(
		sector_label: String, features: Array, row_idx: int) -> PanelContainer:
	var cell := PanelContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cell.custom_minimum_size = Vector2(120, 100)
	cell.set_meta("sector_label", sector_label)

	# Determine cell properties
	var has_notable: bool = false
	var has_features: bool = features.size() > 0
	var cover_level: String = ""

	for feat: String in features:
		var lower: String = feat.to_lower()
		if feat.begins_with("NOTABLE:"):
			has_notable = true
		if "full cover" in lower and cover_level != "FULL":
			cover_level = "FULL"
		elif "partial cover" in lower and cover_level.is_empty():
			cover_level = "PARTIAL"

	# Cell style
	var cell_style := StyleBoxFlat.new()
	cell_style.bg_color = COLOR_CELL_FEATURES if has_features else COLOR_CELL_EMPTY
	cell_style.border_width_left = 4 if has_notable else 1
	cell_style.border_width_top = 1
	cell_style.border_width_right = 1
	cell_style.border_width_bottom = 1

	if has_notable:
		cell_style.border_color = COLOR_BORDER_NOTABLE
	elif row_idx < 2:
		cell_style.border_color = COLOR_ZONE_CREW.lerp(COLOR_BORDER_NORMAL, 0.5)
	else:
		cell_style.border_color = COLOR_ZONE_ENEMY.lerp(COLOR_BORDER_NORMAL, 0.5)

	# Deployment zone left stripe
	if row_idx < 2:
		cell_style.border_width_left = maxi(cell_style.border_width_left, 3)
		if not has_notable:
			cell_style.border_color = COLOR_ZONE_CREW.lerp(COLOR_BORDER_NORMAL, 0.3)
	else:
		cell_style.border_width_left = maxi(cell_style.border_width_left, 3)
		if not has_notable:
			cell_style.border_color = COLOR_ZONE_ENEMY.lerp(COLOR_BORDER_NORMAL, 0.3)

	cell_style.corner_radius_top_left = 6
	cell_style.corner_radius_top_right = 6
	cell_style.corner_radius_bottom_right = 6
	cell_style.corner_radius_bottom_left = 6
	cell_style.content_margin_left = 8.0
	cell_style.content_margin_right = 8.0
	cell_style.content_margin_top = 6.0
	cell_style.content_margin_bottom = 6.0
	cell.add_theme_stylebox_override("panel", cell_style)

	# Cell content
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 2)
	cell.add_child(vbox)

	# Header row: sector label + notable star
	var header_row := HBoxContainer.new()
	header_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(header_row)

	var label_node := Label.new()
	label_node.text = sector_label
	label_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_node.add_theme_font_size_override("font_size", 16)
	label_node.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	header_row.add_child(label_node)

	if has_notable:
		var star := Label.new()
		star.text = "★"
		star.add_theme_font_size_override("font_size", 14)
		star.add_theme_color_override("font_color", COLOR_STAR)
		header_row.add_child(star)

	# Separator
	var sep := HSeparator.new()
	sep.modulate = Color(0.216, 0.255, 0.318, 0.3)
	vbox.add_child(sep)

	# Visual terrain drawing area
	var draw_area := Control.new()
	draw_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	draw_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	draw_area.custom_minimum_size = Vector2(0, 60)
	# Store classified shapes as metadata for the draw callback
	var shapes: Array = _shape_library.classify_features(features)
	draw_area.set_meta("shapes", shapes)
	draw_area.draw.connect(_on_draw_terrain.bind(draw_area))
	vbox.add_child(draw_area)

	# Cover badge
	if not cover_level.is_empty():
		var badge_row := HBoxContainer.new()
		badge_row.alignment = BoxContainer.ALIGNMENT_END
		vbox.add_child(badge_row)

		var badge := Label.new()
		badge.text = cover_level
		badge.add_theme_font_size_override("font_size", 9)
		badge.add_theme_color_override("font_color",
			COLOR_COVER_FULL if cover_level == "FULL" else COLOR_COVER_PARTIAL)
		badge_row.add_child(badge)

	# Tooltip with full feature list
	var tooltip_lines: PackedStringArray = PackedStringArray()
	tooltip_lines.append("Sector %s" % sector_label)
	if features.is_empty():
		tooltip_lines.append("Open ground - no terrain features")
	else:
		for feat: String in features:
			tooltip_lines.append(feat)
	if not cover_level.is_empty():
		tooltip_lines.append("Cover: %s" % cover_level)
	cell.tooltip_text = "\n".join(tooltip_lines)

	# Click handler
	cell.gui_input.connect(_on_cell_input.bind(sector_label, features))

	return cell

func _on_cell_input(event: InputEvent, sector_label: String, features: Array) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_show_sector_detail(sector_label, features)
		sector_clicked.emit(sector_label, features)

func _show_sector_detail(sector_label: String, features: Array) -> void:
	# Update detail bar
	_detail_panel.visible = true
	var bbcode: String = "[b]Sector %s[/b]" % sector_label
	if features.is_empty():
		bbcode += " — Open ground, no terrain features"
	else:
		for feat: String in features:
			if feat.begins_with("NOTABLE:"):
				bbcode += "  [color=#10B981]%s[/color]" % feat
			elif feat.begins_with("Scatter:"):
				bbcode += "  [color=#808080]%s[/color]" % feat
			else:
				bbcode += "  %s" % feat
	_detail_label.text = bbcode

	# Show popover
	_popover_label.text = _build_popover_bbcode(sector_label, features)
	_popover.visible = true

	# Position popover near center of panel
	var panel_size: Vector2 = size
	var pop_x: float = (panel_size.x - _popover.custom_minimum_size.x) / 2.0
	var pop_y: float = panel_size.y * 0.3
	_popover.position = Vector2(maxf(pop_x, 10), maxf(pop_y, 10))

func _build_popover_bbcode(sector_label: String, features: Array) -> String:
	var bbcode: String = "[b][font_size=18]Sector %s[/font_size][/b]\n\n" % sector_label
	if features.is_empty():
		bbcode += "[color=#404040]Open ground — no terrain features placed here.[/color]"
		return bbcode

	for feat: String in features:
		if feat.begins_with("NOTABLE:"):
			bbcode += "[color=#10B981][b]%s[/b][/color]\n" % feat
		elif feat.begins_with("Scatter:"):
			bbcode += "[color=#808080]%s[/color]\n" % feat
		else:
			bbcode += "%s\n" % feat

	# Cover inference
	var cover: String = _infer_cover(features)
	if not cover.is_empty():
		var cover_color: String = "#10B981" if cover == "FULL" else "#D97706"
		bbcode += "\n[color=%s]Best Cover: %s[/color]" % [cover_color, cover]

	return bbcode

func _infer_cover(features: Array) -> String:
	var cover: String = ""
	for feat: String in features:
		var lower: String = feat.to_lower()
		if "full cover" in lower:
			return "FULL"
		elif "partial cover" in lower:
			cover = "PARTIAL"
	return cover

## Draw callback connected to the terrain drawing Control's draw signal.
## Delegates to BattlefieldShapeLibrary for shape classification and rendering.
func _on_draw_terrain(canvas: Control) -> void:
	var shapes: Array = canvas.get_meta("shapes", [])
	_shape_library.draw_shapes_packed(canvas, shapes, canvas.size)

func _input(event: InputEvent) -> void:
	# Dismiss popover on click outside
	if _popover.visible and event is InputEventMouseButton and event.pressed:
		var pop_rect := Rect2(_popover.global_position, _popover.size)
		if not pop_rect.has_point(event.global_position):
			_popover.visible = false
