extends PanelContainer

## Battlefield Grid Panel — Graph-paper terrain map container.
## Wraps BattlefieldMapView with a header bar (title, theme, regenerate, collapse).
## The map view is the sole visualization — no sector text view.

signal regenerate_requested
signal sector_clicked(sector_label: String, features: Array)

# Color palette (matching deep space theme for the panel chrome)
const COLOR_TEXT_PRIMARY := Color(0.878, 0.878, 0.878, 1.0)
const COLOR_TEXT_SECONDARY := Color(0.502, 0.502, 0.502, 1.0)
const COLOR_THEME_TEXT := Color(0.961, 0.62, 0.043, 1.0)
const COLOR_NOTABLE := Color(0.063, 0.725, 0.506, 1.0)

# Design system spacing (UIColors canonical source)
const SPACING_XS := UIColors.SPACING_XS
const SPACING_SM := UIColors.SPACING_SM
const SPACING_MD := UIColors.SPACING_MD

# Internal state
var _is_collapsed: bool = false
var _current_theme_name: String = ""

# Node refs
var _main_vbox: VBoxContainer
var _header_bar: HBoxContainer
var _theme_label: Label
var _collapse_button: Button
var _regen_button: Button
var _map_view: BattlefieldMapView
var _popover: PanelContainer
var _popover_label: RichTextLabel
var _popover_close_btn: Button

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
	panel_style.content_margin_left = float(SPACING_SM)
	panel_style.content_margin_right = float(SPACING_SM)
	panel_style.content_margin_top = float(SPACING_SM)
	panel_style.content_margin_bottom = float(SPACING_SM)
	add_theme_stylebox_override("panel", panel_style)

	_main_vbox = VBoxContainer.new()
	_main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_vbox.add_theme_constant_override("separation", SPACING_SM)
	add_child(_main_vbox)

	# Header bar
	_build_header_bar()

	# Map view (graph-paper terrain layout)
	_map_view = BattlefieldMapView.new()
	_map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_view.custom_minimum_size = Vector2(640, 420)
	_map_view.show_unit_markers = true
	_map_view.cell_clicked.connect(_on_map_cell_clicked)
	_main_vbox.add_child(_map_view)

	# Terrain legend
	_build_legend()

	# Popover (hidden, shown on cell click)
	_build_popover()

func _build_header_bar() -> void:
	_header_bar = HBoxContainer.new()
	_header_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_bar.add_theme_constant_override("separation", SPACING_SM)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", SPACING_XS)
	margin.add_theme_constant_override("margin_right", SPACING_XS)
	margin.add_theme_constant_override("margin_top", SPACING_XS)
	margin.add_theme_constant_override("margin_bottom", SPACING_XS)
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

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_bar.add_child(spacer)

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.122, 0.137, 0.216, 0.8)
	btn_style.border_width_left = 1
	btn_style.border_width_top = 1
	btn_style.border_width_right = 1
	btn_style.border_width_bottom = 1
	btn_style.border_color = Color(0.216, 0.255, 0.318, 1)
	btn_style.corner_radius_top_left = 6
	btn_style.corner_radius_top_right = 6
	btn_style.corner_radius_bottom_right = 6
	btn_style.corner_radius_bottom_left = 6
	btn_style.content_margin_left = 12.0
	btn_style.content_margin_right = 12.0
	btn_style.content_margin_top = 4.0
	btn_style.content_margin_bottom = 4.0

	_regen_button = Button.new()
	_regen_button.text = "Regenerate"
	_regen_button.custom_minimum_size = Vector2(0, 32)
	_regen_button.add_theme_font_size_override("font_size", 12)
	_regen_button.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_regen_button.add_theme_stylebox_override("normal", btn_style)
	_regen_button.pressed.connect(func(): regenerate_requested.emit())
	_header_bar.add_child(_regen_button)

	_collapse_button = Button.new()
	_collapse_button.text = "Collapse"
	_collapse_button.custom_minimum_size = Vector2(0, 32)
	_collapse_button.add_theme_font_size_override("font_size", 12)
	_collapse_button.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_collapse_button.add_theme_stylebox_override("normal", btn_style.duplicate())
	_collapse_button.pressed.connect(_toggle_collapse)
	_header_bar.add_child(_collapse_button)

func _build_legend() -> void:
	var legend_container := HBoxContainer.new()
	legend_container.name = "TerrainLegend"
	legend_container.add_theme_constant_override("separation", 12)
	legend_container.custom_minimum_size = Vector2(0, 24)

	var legend_title := Label.new()
	legend_title.text = "LEGEND:"
	legend_title.add_theme_font_size_override("font_size", 11)
	legend_title.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	legend_container.add_child(legend_title)

	var entries: Array = [
		[BattlefieldShapeLibrary.MAP_COLOR_BUILDING, "Building"],
		[BattlefieldShapeLibrary.MAP_COLOR_WALL, "Wall"],
		[BattlefieldShapeLibrary.MAP_COLOR_ROCK, "Rock"],
		[BattlefieldShapeLibrary.MAP_COLOR_HILL, "Hill"],
		[BattlefieldShapeLibrary.MAP_COLOR_VEGETATION, "Trees"],
		[BattlefieldShapeLibrary.MAP_COLOR_WATER, "Water"],
		[BattlefieldShapeLibrary.MAP_COLOR_CONTAINER, "Container"],
		[BattlefieldShapeLibrary.MAP_COLOR_HAZARD, "Hazard"],
		[BattlefieldShapeLibrary.MAP_COLOR_DEBRIS, "Debris"],
	]

	for entry: Array in entries:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 4)

		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(14, 14)
		swatch.color = entry[0]
		item.add_child(swatch)

		var lbl := Label.new()
		lbl.text = entry[1]
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
		item.add_child(lbl)

		legend_container.add_child(item)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 4)
	margin.add_child(legend_container)
	_main_vbox.add_child(margin)

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

## Public API: Populate the map with sector data from BattlefieldGenerator
func populate(sectors: Array, theme_name: String = "") -> void:
	_current_theme_name = theme_name
	_theme_label.text = theme_name
	_map_view.populate_from_sectors(sectors, theme_name)
	_popover.visible = false

## Collapse the panel, showing only the header bar
func collapse() -> void:
	_is_collapsed = true
	_map_view.visible = false
	_popover.visible = false
	_collapse_button.text = "Expand"

## Expand the panel back to full view
func expand() -> void:
	_is_collapsed = false
	_map_view.visible = true
	_collapse_button.text = "Collapse"

func _toggle_collapse() -> void:
	if _is_collapsed:
		expand()
	else:
		collapse()

## Route unit positions to the map view
func set_unit_positions(units: Array) -> void:
	_map_view.set_unit_positions(units)

## Route objective positions to the map view
func set_objective_positions(positions: Array) -> void:
	_map_view.set_objective_positions(positions)

## Route battle event overlays to the map view
func add_terrain_overlay(overlay: Dictionary) -> void:
	_map_view.add_terrain_overlay(overlay)

func remove_terrain_overlay(overlay_id: String) -> void:
	_map_view.remove_terrain_overlay(overlay_id)

func clear_terrain_overlays() -> void:
	_map_view.clear_terrain_overlays()

## Handle map cell click — show popover with terrain details
func _on_map_cell_clicked(sector_label: String, features: Array) -> void:
	sector_clicked.emit(sector_label, features)
	_popover_label.text = _build_popover_bbcode(sector_label, features)
	_popover.visible = true

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

		# Core Rules terrain category (p.37-39) with LOS/cover/movement rules
		if not feat.begins_with("Scatter:"):
			var category: String = BattlefieldShapeLibrary.classify_terrain_rules_category(feat)
			var rules_text: String = BattlefieldShapeLibrary.get_terrain_rules_text(category)
			bbcode += "  [color=#9CA3AF][i]%s — %s[/i][/color]\n" % [category, rules_text]

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
		if "partial cover" in lower:
			cover = "PARTIAL"
	return cover

func _input(event: InputEvent) -> void:
	# Dismiss popover on click outside
	if _popover.visible and event is InputEventMouseButton and event.pressed:
		var pop_rect := Rect2(_popover.global_position, _popover.size)
		if not pop_rect.has_point(event.global_position):
			_popover.visible = false
