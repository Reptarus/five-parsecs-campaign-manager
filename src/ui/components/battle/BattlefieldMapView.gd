class_name BattlefieldMapView
extends Control

## Overhead gridded battlefield map with terrain features, deployment zones, and
## optional unit markers. Designed to be embedded in any parent Control.
##
## Usage:
##   var map_view := BattlefieldMapView.new()
##   parent.add_child(map_view)
##   map_view.populate_from_sectors(sectors, "Industrial Zone")
##
## Supports two modes:
## - Interactive (default): zoom via mouse wheel, pan via middle-click drag
## - Compact: auto-scales to fit container, no interaction (for post-battle recap)

signal cell_hovered(sector_label: String, features: Array)
signal cell_clicked(sector_label: String, features: Array)

# ============================================================================
# GRID CONSTANTS
# ============================================================================

const GRID_COLUMNS := 24    # 4 sectors * 6 cells each
const GRID_ROWS := 16       # 4 sectors * 4 cells each
const SECTOR_COLS := 6      # cells per sector horizontally
const SECTOR_ROWS := 4      # cells per sector vertically
const ROW_LABELS := ["A", "B", "C", "D"]
const COL_LABELS := ["1", "2", "3", "4"]

# ============================================================================
# VISUAL CONSTANTS
# ============================================================================

const COLOR_BACKGROUND := Color(0.067, 0.094, 0.153, 1.0)
const COLOR_GRID_LINE := Color(0.216, 0.255, 0.318, 0.2)
const COLOR_SECTOR_LINE := Color(0.216, 0.255, 0.318, 0.6)
const COLOR_SECTOR_LABEL := Color(0.878, 0.878, 0.878, 0.4)
const COLOR_ZONE_CREW := Color(0.176, 0.353, 0.482, 0.15)
const COLOR_ZONE_ENEMY := Color(0.545, 0.153, 0.153, 0.15)
const COLOR_HOVER := Color(0.961, 0.788, 0.043, 0.25)
const COLOR_UNIT_CREW := Color(0.118, 0.565, 1.0, 0.9)
const COLOR_UNIT_ENEMY := Color(0.863, 0.153, 0.153, 0.9)
const COLOR_UNIT_DEAD := Color(0.502, 0.502, 0.502, 0.6)
const COLOR_TOOLTIP_BG := Color(0.067, 0.094, 0.153, 0.95)
const COLOR_TOOLTIP_BORDER := Color(0.063, 0.725, 0.506, 0.8)
const COLOR_TOOLTIP_TEXT := Color(0.878, 0.878, 0.878, 1.0)

const ZOOM_MIN := 0.5
const ZOOM_MAX := 3.0
const ZOOM_STEP := 0.15

# ============================================================================
# PROPERTIES
# ============================================================================

## Base pixel size per grid cell (before zoom).
var cell_size: float = 24.0

## Current zoom level (1.0 = default).
var zoom_level: float = 1.0

## Current pan offset in pixels.
var pan_offset: Vector2 = Vector2.ZERO

## When true, disables zoom/pan and auto-scales to fit the container.
var compact_mode: bool = false

## When true, renders unit position markers on the grid.
var show_unit_markers: bool = false

## Theme name displayed in the corner.
var theme_name: String = ""

# ============================================================================
# INTERNAL STATE
# ============================================================================

# 2D array [sector_row][sector_col] of classified shape arrays.
# Each entry is an Array of shape dictionaries from BattlefieldShapeLibrary.
var _sector_shapes: Array = []  # [row][col] -> Array[Dictionary]
var _sector_features: Array = []  # [row][col] -> Array[String] (raw feature text)

# Unit markers: Array of {position: Vector2i, team: String, name: String, status: String}
var _unit_positions: Array = []

# Hovered cell in grid coordinates, or Vector2i(-1, -1) if none.
var _hovered_cell: Vector2i = Vector2i(-1, -1)

# Pan drag state
var _is_panning: bool = false
var _pan_start: Vector2 = Vector2.ZERO

# Tooltip
var _tooltip_panel: PanelContainer
var _tooltip_label: RichTextLabel

# Shape library
var _shape_library := BattlefieldShapeLibrary.new()

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_tooltip()

func _build_tooltip() -> void:
	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.visible = false
	_tooltip_panel.z_index = 20
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_TOOLTIP_BG
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = COLOR_TOOLTIP_BORDER
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	_tooltip_panel.add_theme_stylebox_override("panel", style)

	_tooltip_label = RichTextLabel.new()
	_tooltip_label.bbcode_enabled = true
	_tooltip_label.fit_content = true
	_tooltip_label.scroll_active = false
	_tooltip_label.custom_minimum_size = Vector2(180, 0)
	_tooltip_label.add_theme_color_override("default_color", COLOR_TOOLTIP_TEXT)
	_tooltip_label.add_theme_font_size_override("normal_font_size", 12)
	_tooltip_panel.add_child(_tooltip_label)

	add_child(_tooltip_panel)

# ============================================================================
# PUBLIC API
# ============================================================================

## Populate the map from sector data (same format as BattlefieldGridPanel.populate()).
## sectors: Array of {label: "A1", features: ["Boulder (full cover)", ...]}
func populate_from_sectors(sectors: Array, p_theme_name: String = "") -> void:
	theme_name = p_theme_name

	# Initialize 4x4 sector arrays
	_sector_shapes = []
	_sector_features = []
	for _r: int in range(4):
		var shape_row: Array = []
		var feat_row: Array = []
		for _c: int in range(4):
			shape_row.append([])
			feat_row.append([])
		_sector_shapes.append(shape_row)
		_sector_features.append(feat_row)

	# Populate from sector data
	for sector: Dictionary in sectors:
		var label: String = sector.get("label", "")
		if label.length() < 2:
			continue
		var row_char: String = label[0]
		var col_char: String = label[1]
		var row_idx: int = ROW_LABELS.find(row_char)
		var col_idx: int = COL_LABELS.find(col_char)
		if row_idx < 0 or col_idx < 0:
			continue

		var features: Array = sector.get("features", [])
		_sector_features[row_idx][col_idx] = features
		_sector_shapes[row_idx][col_idx] = _shape_library.classify_features(features)

	queue_redraw()

## Set unit positions for display on the map.
## units: Array of {position: Vector2i, team: "crew"|"enemy", name: String, status: "alive"|"dead"}
func set_unit_positions(units: Array) -> void:
	_unit_positions = units
	queue_redraw()

## Enable or disable compact mode (auto-scale, no interaction).
func set_compact_mode(enabled: bool) -> void:
	compact_mode = enabled
	if compact_mode:
		zoom_level = 1.0
		pan_offset = Vector2.ZERO
		_hovered_cell = Vector2i(-1, -1)
		_tooltip_panel.visible = false
	queue_redraw()

## Clear all data.
func clear() -> void:
	_sector_shapes = []
	_sector_features = []
	_unit_positions = []
	_hovered_cell = Vector2i(-1, -1)
	theme_name = ""
	_tooltip_panel.visible = false
	queue_redraw()

# ============================================================================
# RENDERING
# ============================================================================

func _draw() -> void:
	var effective_cell: float = _get_effective_cell_size()
	var grid_pixel_w: float = GRID_COLUMNS * effective_cell
	var grid_pixel_h: float = GRID_ROWS * effective_cell
	var offset: Vector2 = _get_draw_offset(grid_pixel_w, grid_pixel_h)

	# Layer 1: Background
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BACKGROUND)

	# Layer 2: Deployment zone tinting (rows A-B = crew, C-D = enemy)
	_draw_deployment_zones(offset, effective_cell, grid_pixel_w)

	# Layer 3: Grid lines
	_draw_grid_lines(offset, effective_cell, grid_pixel_w, grid_pixel_h)

	# Layer 4: Sector dividers and labels
	_draw_sector_dividers(offset, effective_cell, grid_pixel_w, grid_pixel_h)

	# Layer 5: Terrain features
	_draw_terrain_features(offset, effective_cell)

	# Layer 6: Unit markers
	if show_unit_markers:
		_draw_unit_markers(offset, effective_cell)

	# Layer 7: Hover highlight
	if _hovered_cell != Vector2i(-1, -1) and not compact_mode:
		_draw_hover_highlight(offset, effective_cell)

func _get_effective_cell_size() -> float:
	if compact_mode:
		# Scale to fit container
		var available: Vector2 = size
		var scale_x: float = available.x / (GRID_COLUMNS * cell_size)
		var scale_y: float = available.y / (GRID_ROWS * cell_size)
		return cell_size * minf(scale_x, scale_y)
	return cell_size * zoom_level

func _get_draw_offset(grid_w: float, grid_h: float) -> Vector2:
	if compact_mode:
		# Center the grid in the container
		return Vector2(
			(size.x - grid_w) / 2.0,
			(size.y - grid_h) / 2.0
		)
	return pan_offset

func _draw_deployment_zones(offset: Vector2, cs: float, grid_w: float) -> void:
	# Crew zone: rows 0-7 (sectors A and B)
	var crew_h: float = SECTOR_ROWS * 2 * cs
	draw_rect(Rect2(offset, Vector2(grid_w, crew_h)), COLOR_ZONE_CREW)

	# Enemy zone: rows 8-15 (sectors C and D)
	var enemy_y: float = offset.y + crew_h
	var enemy_h: float = SECTOR_ROWS * 2 * cs
	draw_rect(Rect2(Vector2(offset.x, enemy_y), Vector2(grid_w, enemy_h)), COLOR_ZONE_ENEMY)

func _draw_grid_lines(offset: Vector2, cs: float, grid_w: float, grid_h: float) -> void:
	# Vertical lines
	for col: int in range(GRID_COLUMNS + 1):
		var x: float = offset.x + col * cs
		draw_line(Vector2(x, offset.y), Vector2(x, offset.y + grid_h), COLOR_GRID_LINE, 1.0)

	# Horizontal lines
	for row: int in range(GRID_ROWS + 1):
		var y: float = offset.y + row * cs
		draw_line(Vector2(offset.x, y), Vector2(offset.x + grid_w, y), COLOR_GRID_LINE, 1.0)

func _draw_sector_dividers(offset: Vector2, cs: float, grid_w: float, grid_h: float) -> void:
	var sector_w: float = SECTOR_COLS * cs
	var sector_h: float = SECTOR_ROWS * cs

	# Vertical sector dividers
	for col: int in range(5):  # 0 through 4, inclusive edges
		var x: float = offset.x + col * sector_w
		draw_line(Vector2(x, offset.y), Vector2(x, offset.y + grid_h),
			COLOR_SECTOR_LINE, 2.0 if col > 0 and col < 4 else 1.5)

	# Horizontal sector dividers
	for row: int in range(5):
		var y: float = offset.y + row * sector_h
		draw_line(Vector2(offset.x, y), Vector2(offset.x + grid_w, y),
			COLOR_SECTOR_LINE, 2.0 if row > 0 and row < 4 else 1.5)

	# Sector labels (A1-D4) in top-left corner of each sector
	if cs >= 10.0:  # Only draw labels when cells are large enough to read
		var font: Font = ThemeDB.fallback_font
		var font_size: int = clampi(int(cs * 0.6), 8, 16)
		for sr: int in range(4):
			for sc: int in range(4):
				var label_text: String = ROW_LABELS[sr] + COL_LABELS[sc]
				var lx: float = offset.x + sc * sector_w + 3.0
				var ly: float = offset.y + sr * sector_h + font_size + 2.0
				draw_string(font, Vector2(lx, ly), label_text,
					HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, COLOR_SECTOR_LABEL)

func _draw_terrain_features(offset: Vector2, cs: float) -> void:
	if _sector_shapes.is_empty():
		return

	var sector_w: float = SECTOR_COLS * cs
	var sector_h: float = SECTOR_ROWS * cs
	# Scale factor relative to the library's default sector cell size (~120px)
	var scale_factor: float = cs / 24.0

	for sr: int in range(4):
		for sc: int in range(4):
			var shapes: Array = _sector_shapes[sr][sc]
			if shapes.is_empty():
				# Draw open-ground marker in center of sector
				var sector_origin := Vector2(
					offset.x + sc * sector_w,
					offset.y + sr * sector_h
				)
				var center := sector_origin + Vector2(sector_w, sector_h) / 2.0
				var s: float = minf(sector_w, sector_h) * 0.15
				draw_line(center - Vector2(s, s), center + Vector2(s, s),
					BattlefieldShapeLibrary.SHAPE_COLOR_OPEN, 1.0)
				draw_line(center - Vector2(-s, s), center + Vector2(-s, s),
					BattlefieldShapeLibrary.SHAPE_COLOR_OPEN, 1.0)
				continue

			# Position features within the sector using a flow layout
			var sector_origin := Vector2(
				offset.x + sc * sector_w + 4.0 * scale_factor,
				offset.y + sr * sector_h + 14.0 * scale_factor  # Leave room for sector label
			)
			var avail_w: float = sector_w - 8.0 * scale_factor
			var avail_h: float = sector_h - 18.0 * scale_factor

			var x_cursor: float = 0.0
			var y_cursor: float = 0.0
			var row_height: float = 0.0

			for shape: Dictionary in shapes:
				var w: float = shape.get("width", 30.0) * scale_factor
				var h: float = shape.get("height", 20.0) * scale_factor

				# Wrap to next row
				if x_cursor + w > avail_w and x_cursor > 0.0:
					x_cursor = 0.0
					y_cursor += row_height + 3.0 * scale_factor
					row_height = 0.0

				# Skip if out of vertical space
				if y_cursor + h > avail_h:
					break

				var draw_origin := sector_origin + Vector2(x_cursor, y_cursor)
				_shape_library.draw_shape(self, shape, draw_origin, scale_factor)

				x_cursor += w + 4.0 * scale_factor
				row_height = maxf(row_height, h)

func _draw_unit_markers(offset: Vector2, cs: float) -> void:
	var marker_radius: float = cs * 0.35
	for unit: Dictionary in _unit_positions:
		var grid_pos: Vector2i = unit.get("position", Vector2i.ZERO)
		var team: String = unit.get("team", "crew")
		var status: String = unit.get("status", "alive")

		var center := Vector2(
			offset.x + (grid_pos.x + 0.5) * cs,
			offset.y + (grid_pos.y + 0.5) * cs
		)

		var color: Color
		if status == "dead":
			color = COLOR_UNIT_DEAD
		elif team == "enemy":
			color = COLOR_UNIT_ENEMY
		else:
			color = COLOR_UNIT_CREW

		# Draw unit circle
		draw_circle(center, marker_radius, color)

		# Draw X for dead units
		if status == "dead":
			var xs: float = marker_radius * 0.6
			draw_line(center - Vector2(xs, xs), center + Vector2(xs, xs),
				Color.WHITE.darkened(0.3), 2.0)
			draw_line(center - Vector2(-xs, xs), center + Vector2(-xs, xs),
				Color.WHITE.darkened(0.3), 2.0)
		else:
			# Inner dot
			draw_circle(center, marker_radius * 0.3, color.lightened(0.4))

func _draw_hover_highlight(offset: Vector2, cs: float) -> void:
	var hx: float = offset.x + _hovered_cell.x * cs
	var hy: float = offset.y + _hovered_cell.y * cs
	draw_rect(Rect2(hx, hy, cs, cs), COLOR_HOVER)

# ============================================================================
# INPUT HANDLING
# ============================================================================

func _gui_input(event: InputEvent) -> void:
	if compact_mode:
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed:
			match mb.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					_zoom(ZOOM_STEP, mb.position)
					accept_event()
				MOUSE_BUTTON_WHEEL_DOWN:
					_zoom(-ZOOM_STEP, mb.position)
					accept_event()
				MOUSE_BUTTON_MIDDLE:
					_is_panning = true
					_pan_start = mb.position
					accept_event()
				MOUSE_BUTTON_LEFT:
					_handle_click(mb.position)
					accept_event()
		else:
			if mb.button_index == MOUSE_BUTTON_MIDDLE:
				_is_panning = false

	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if _is_panning:
			pan_offset += mm.relative
			queue_redraw()
		else:
			_update_hover(mm.position)

func _zoom(delta: float, anchor: Vector2) -> void:
	var old_zoom: float = zoom_level
	zoom_level = clampf(zoom_level + delta, ZOOM_MIN, ZOOM_MAX)
	if zoom_level == old_zoom:
		return

	# Zoom toward mouse position
	var zoom_ratio: float = zoom_level / old_zoom
	pan_offset = anchor - (anchor - pan_offset) * zoom_ratio
	queue_redraw()

func _handle_click(mouse_pos: Vector2) -> void:
	var cell: Vector2i = _mouse_to_grid(mouse_pos)
	if cell == Vector2i(-1, -1):
		return

	var sector_label: String = _grid_to_sector_label(cell)
	var sr: int = cell.y / SECTOR_ROWS
	var sc: int = cell.x / SECTOR_COLS
	if sr >= 0 and sr < 4 and sc >= 0 and sc < 4 and not _sector_features.is_empty():
		cell_clicked.emit(sector_label, _sector_features[sr][sc])

func _update_hover(mouse_pos: Vector2) -> void:
	var cell: Vector2i = _mouse_to_grid(mouse_pos)
	if cell == _hovered_cell:
		return

	_hovered_cell = cell
	queue_redraw()

	if cell == Vector2i(-1, -1):
		_tooltip_panel.visible = false
		cell_hovered.emit("", [])
		return

	var sr: int = cell.y / SECTOR_ROWS
	var sc: int = cell.x / SECTOR_COLS
	if sr < 0 or sr >= 4 or sc < 0 or sc >= 4 or _sector_features.is_empty():
		_tooltip_panel.visible = false
		return

	var sector_label: String = _grid_to_sector_label(cell)
	var features: Array = _sector_features[sr][sc]
	cell_hovered.emit(sector_label, features)

	# Update tooltip
	var bbcode: String = "[b]%s[/b]" % sector_label
	if features.is_empty():
		bbcode += "\nOpen ground"
	else:
		for feat: String in features:
			bbcode += "\n%s" % feat
	_tooltip_label.text = bbcode
	_tooltip_panel.visible = true

	# Position tooltip near mouse but keep on screen
	var tip_pos := mouse_pos + Vector2(16, 16)
	if tip_pos.x + 200 > size.x:
		tip_pos.x = mouse_pos.x - 200
	if tip_pos.y + 100 > size.y:
		tip_pos.y = mouse_pos.y - 100
	_tooltip_panel.position = tip_pos

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		if _hovered_cell != Vector2i(-1, -1):
			_hovered_cell = Vector2i(-1, -1)
			_tooltip_panel.visible = false
			queue_redraw()

# ============================================================================
# COORDINATE HELPERS
# ============================================================================

## Convert mouse position to grid cell coordinates. Returns (-1,-1) if outside grid.
func _mouse_to_grid(mouse_pos: Vector2) -> Vector2i:
	var effective_cell: float = _get_effective_cell_size()
	var grid_w: float = GRID_COLUMNS * effective_cell
	var grid_h: float = GRID_ROWS * effective_cell
	var offset: Vector2 = _get_draw_offset(grid_w, grid_h)

	var local: Vector2 = mouse_pos - offset
	if local.x < 0 or local.y < 0 or local.x >= grid_w or local.y >= grid_h:
		return Vector2i(-1, -1)

	var col: int = int(local.x / effective_cell)
	var row: int = int(local.y / effective_cell)
	return Vector2i(clampi(col, 0, GRID_COLUMNS - 1), clampi(row, 0, GRID_ROWS - 1))

## Convert grid cell to sector label (e.g., Vector2i(7, 5) → "B2").
func _grid_to_sector_label(cell: Vector2i) -> String:
	var sr: int = cell.y / SECTOR_ROWS
	var sc: int = cell.x / SECTOR_COLS
	if sr < 0 or sr >= 4 or sc < 0 or sc >= 4:
		return ""
	return ROW_LABELS[sr] + COL_LABELS[sc]
