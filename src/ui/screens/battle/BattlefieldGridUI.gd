class_name BattlefieldGridUI
extends Control

## 2D Top-Down Battlefield Grid Renderer
## Mobile-friendly visual representation of Five Parsecs battlefield
## Supports configurable table sizes: 2x2, 2.5x2.5, 3x3 feet

# Signals
signal terrain_clicked(position: Vector2i)
signal unit_clicked(unit_id: String)
signal deployment_zone_clicked(zone: String, position: Vector2i)
signal grid_generated(grid_size: Vector2i)

# Design system constants (matching BaseCampaignPanel)
const COLOR_BASE := Color("#1A1A2E")
const COLOR_ELEVATED := Color("#252542")
const COLOR_BORDER := Color("#3A3A5C")
const COLOR_GRID_LINE := Color("#2A2A4A")
const COLOR_CREW_ZONE := Color(0.1, 0.4, 0.8, 0.3)  # Blue translucent
const COLOR_ENEMY_ZONE := Color(0.8, 0.2, 0.1, 0.3)  # Red translucent
const COLOR_NEUTRAL := Color(0.3, 0.3, 0.3, 0.2)

# Terrain colors per Five Parsecs terrain types
const TERRAIN_COLORS := {
	"large": Color("#4A6741"),      # Forest green - large terrain (4-6")
	"small": Color("#8B7355"),      # Brown/rock - small terrain (2-3")
	"linear": Color("#696969"),     # Gray - linear terrain (walls)
	"area": Color("#2D5A3D"),       # Dark green - area terrain (forest)
	"field": Color("#4A4A2A"),      # Olive - field terrain (difficult)
	"block": Color("#5A5A5A"),      # Medium gray - block terrain (climbable)
	"interior": Color("#6B4423"),   # Brown - interior terrain (buildings)
	"open": Color("#1E1E2E")        # Dark background
}

# Unit marker colors
const COLOR_CREW := Color("#3B82F6")        # Blue for crew
const COLOR_ENEMY := Color("#EF4444")       # Red for enemies
const COLOR_UNIQUE := Color("#F59E0B")      # Orange for unique individuals
const COLOR_SPECIALIST := Color("#8B5CF6")  # Purple for specialists

# Touch target sizing (mobile-friendly)
const TOUCH_TARGET_MIN := 48  # Minimum touch target in pixels
const CELL_SIZE_MIN := 16     # Minimum cell size in pixels
const CELL_SIZE_MAX := 32     # Maximum cell size in pixels

# Table size configurations (in inches)
const TABLE_SIZES := {
	"2x2": Vector2i(24, 24),     # 2x2 feet = 24x24 inches
	"2.5x2.5": Vector2i(30, 30), # 2.5x2.5 feet = 30x30 inches
	"3x3": Vector2i(36, 36)      # 3x3 feet = 36x36 inches
}

# Current state
var grid_size: Vector2i = Vector2i(36, 36)  # Default 3x3 feet
var cell_size: int = 24  # Pixels per grid cell (1 cell = 1 inch)
var current_table_size: String = "3x3"

# Terrain features: Array of {position: Vector2i, size: Vector2i, category: String, properties: Dictionary}
var terrain_features: Array[Dictionary] = []

# Unit positions: unit_id -> {position: Vector2i, is_enemy: bool, is_unique: bool, is_specialist: bool, name: String}
var unit_positions: Dictionary = {}

# Deployment zones: crew and enemy zones
var crew_deployment_zone: Array[Vector2i] = []
var enemy_deployment_zone: Array[Vector2i] = []

# Sector grid for tactical positioning
var sectors: Array[Dictionary] = []

# Interaction state
var show_grid_lines: bool = true
var show_deployment_zones: bool = true
var show_sectors: bool = false
var selected_cell: Vector2i = Vector2i(-1, -1)

# LOS visualization
var _los_visible: bool = false
var _los_source_cell: Vector2i = Vector2i(-1, -1)
var _los_visible_cells: Array[Vector2i] = []
var _los_blocked_cells: Array[Vector2i] = []

func _ready() -> void:
	# Set minimum size based on grid
	_calculate_cell_size()
	mouse_filter = Control.MOUSE_FILTER_STOP

## Set table size from configuration
func set_table_size(size_key: String) -> void:
	if not TABLE_SIZES.has(size_key):
		push_warning("BattlefieldGridUI: Unknown table size '%s', using 3x3" % size_key)
		size_key = "3x3"

	current_table_size = size_key
	grid_size = TABLE_SIZES[size_key]
	_calculate_cell_size()
	_generate_default_deployment_zones()
	grid_generated.emit(grid_size)
	queue_redraw()

## Calculate optimal cell size based on available space
func _calculate_cell_size() -> void:
	var available_size := size if size.x > 0 else Vector2(400, 400)

	# Calculate cell size to fit grid in available space
	var cell_width := int(available_size.x / grid_size.x)
	var cell_height := int(available_size.y / grid_size.y)

	cell_size = min(cell_width, cell_height)
	cell_size = clamp(cell_size, CELL_SIZE_MIN, CELL_SIZE_MAX)

	# Update minimum size
	custom_minimum_size = Vector2(grid_size.x * cell_size, grid_size.y * cell_size)

## Generate default deployment zones per Five Parsecs rules
func _generate_default_deployment_zones() -> void:
	crew_deployment_zone.clear()
	enemy_deployment_zone.clear()

	# Crew deploys on left edge (first 4")
	for y in range(grid_size.y):
		for x in range(min(4, grid_size.x)):
			crew_deployment_zone.append(Vector2i(x, y))

	# Enemy deploys on right edge (last 4")
	for y in range(grid_size.y):
		for x in range(max(0, grid_size.x - 4), grid_size.x):
			enemy_deployment_zone.append(Vector2i(x, y))

## Set terrain features from battlefield generator
func set_terrain_features(features: Array) -> void:
	terrain_features = features
	queue_redraw()

## Add a single terrain feature
func add_terrain_feature(position: Vector2i, size_cells: Vector2i, category: String, properties: Dictionary = {}) -> void:
	terrain_features.append({
		"position": position,
		"size": size_cells,
		"category": category,
		"properties": properties
	})
	queue_redraw()

## Set unit positions for display
func set_unit_positions(positions: Dictionary) -> void:
	unit_positions = positions
	queue_redraw()

## Add or update a unit position
func set_unit_position(unit_id: String, position: Vector2i, is_enemy: bool = false, is_unique: bool = false, is_specialist: bool = false, unit_name: String = "") -> void:
	unit_positions[unit_id] = {
		"position": position,
		"is_enemy": is_enemy,
		"is_unique": is_unique,
		"is_specialist": is_specialist,
		"name": unit_name
	}
	queue_redraw()

## Remove a unit from the grid
func remove_unit(unit_id: String) -> void:
	unit_positions.erase(unit_id)
	queue_redraw()

## Set sector grid from battlefield generator
func set_sectors(sector_data: Array) -> void:
	sectors = sector_data
	queue_redraw()

## Main draw function
func _draw() -> void:
	_draw_background()
	_draw_deployment_zones()
	_draw_terrain_features()
	_draw_grid_lines()
	_draw_sectors()
	_draw_los_overlay()
	_draw_units()
	_draw_selection()

## Draw background
func _draw_background() -> void:
	var bg_rect := Rect2(Vector2.ZERO, Vector2(grid_size.x * cell_size, grid_size.y * cell_size))
	draw_rect(bg_rect, TERRAIN_COLORS["open"])

## Draw deployment zones
func _draw_deployment_zones() -> void:
	if not show_deployment_zones:
		return

	# Draw crew zone (left side)
	for cell_pos in crew_deployment_zone:
		var rect := Rect2(
			Vector2(cell_pos.x * cell_size, cell_pos.y * cell_size),
			Vector2(cell_size, cell_size)
		)
		draw_rect(rect, COLOR_CREW_ZONE)

	# Draw enemy zone (right side)
	for cell_pos in enemy_deployment_zone:
		var rect := Rect2(
			Vector2(cell_pos.x * cell_size, cell_pos.y * cell_size),
			Vector2(cell_size, cell_size)
		)
		draw_rect(rect, COLOR_ENEMY_ZONE)

## Draw terrain features
func _draw_terrain_features() -> void:
	for feature in terrain_features:
		var pos: Vector2i = feature.get("position", Vector2i.ZERO)
		var feature_size: Vector2i = feature.get("size", Vector2i(1, 1))
		var category: String = feature.get("category", "small")
		var properties: Dictionary = feature.get("properties", {})

		var rect := Rect2(
			Vector2(pos.x * cell_size, pos.y * cell_size),
			Vector2(feature_size.x * cell_size, feature_size.y * cell_size)
		)

		# Get color for terrain category
		var fill_color: Color = TERRAIN_COLORS.get(category, TERRAIN_COLORS["small"])
		draw_rect(rect, fill_color)

		# Draw border for visibility
		var border_color: Color = fill_color.lightened(0.3)
		draw_rect(rect, border_color, false, 2.0)

		# Draw indicators for special properties
		if properties.get("climbable", false):
			_draw_climbable_indicator(rect)
		if properties.get("elevated", false):
			_draw_elevated_indicator(rect)
		if properties.get("enterable", false):
			_draw_enterable_indicator(rect)

## Draw climbable indicator (ladder icon)
func _draw_climbable_indicator(rect: Rect2) -> void:
	var indicator_size: float = min(rect.size.x, rect.size.y) * 0.3
	var indicator_pos := rect.position + Vector2(4, 4)
	draw_rect(Rect2(indicator_pos, Vector2(indicator_size, indicator_size)), Color.YELLOW.darkened(0.3), false, 2.0)

## Draw elevated indicator (up arrow)
func _draw_elevated_indicator(rect: Rect2) -> void:
	var center: Vector2 = rect.get_center()
	var arrow_size: float = min(rect.size.x, rect.size.y) * 0.2
	var points := PackedVector2Array([
		center + Vector2(0, -arrow_size),
		center + Vector2(-arrow_size * 0.7, arrow_size * 0.5),
		center + Vector2(arrow_size * 0.7, arrow_size * 0.5)
	])
	draw_colored_polygon(points, Color.WHITE.darkened(0.2))

## Draw enterable indicator (door icon)
func _draw_enterable_indicator(rect: Rect2) -> void:
	var indicator_size: float = min(rect.size.x, rect.size.y) * 0.3
	var indicator_pos := rect.position + rect.size - Vector2(indicator_size + 4, indicator_size + 4)
	draw_rect(Rect2(indicator_pos, Vector2(indicator_size, indicator_size)), Color.CYAN.darkened(0.3))

## Draw grid lines
func _draw_grid_lines() -> void:
	if not show_grid_lines:
		return

	var total_width := grid_size.x * cell_size
	var total_height := grid_size.y * cell_size

	# Draw vertical lines
	for x in range(grid_size.x + 1):
		var x_pos := x * cell_size
		draw_line(Vector2(x_pos, 0), Vector2(x_pos, total_height), COLOR_GRID_LINE, 1.0)

	# Draw horizontal lines
	for y in range(grid_size.y + 1):
		var y_pos := y * cell_size
		draw_line(Vector2(0, y_pos), Vector2(total_width, y_pos), COLOR_GRID_LINE, 1.0)

## Draw sector boundaries
func _draw_sectors() -> void:
	if not show_sectors or sectors.is_empty():
		return

	for sector in sectors:
		var world_pos: Vector2 = sector.get("world_position", Vector2.ZERO)
		var sector_size: Vector2 = sector.get("size", Vector2(12, 12))

		var rect := Rect2(
			Vector2(world_pos.x * cell_size, world_pos.y * cell_size),
			Vector2(sector_size.x * cell_size, sector_size.y * cell_size)
		)

		# Draw sector boundary
		var zone_type: String = sector.get("deployment_zone", "neutral")
		var zone_color := COLOR_NEUTRAL
		if zone_type == "crew":
			zone_color = COLOR_CREW_ZONE
		elif zone_type == "enemy":
			zone_color = COLOR_ENEMY_ZONE

		draw_rect(rect, zone_color, false, 2.0)

## Draw unit markers
func _draw_units() -> void:
	for unit_id in unit_positions:
		var unit_data: Dictionary = unit_positions[unit_id]
		var pos: Vector2i = unit_data.get("position", Vector2i.ZERO)
		var is_enemy: bool = unit_data.get("is_enemy", false)
		var is_unique: bool = unit_data.get("is_unique", false)
		var is_specialist: bool = unit_data.get("is_specialist", false)

		var center := Vector2(
			pos.x * cell_size + cell_size * 0.5,
			pos.y * cell_size + cell_size * 0.5
		)
		var radius := cell_size * 0.4

		# Determine color based on unit type
		var unit_color := COLOR_CREW
		if is_enemy:
			if is_unique:
				unit_color = COLOR_UNIQUE
			elif is_specialist:
				unit_color = COLOR_SPECIALIST
			else:
				unit_color = COLOR_ENEMY

		# Draw unit circle
		draw_circle(center, radius, unit_color)

		# Draw border
		draw_arc(center, radius, 0, TAU, 32, unit_color.lightened(0.3), 2.0)

		# Draw unique/specialist indicator
		if is_unique:
			draw_circle(center, radius * 0.3, Color.WHITE)
		elif is_specialist:
			var points := PackedVector2Array()
			for i in range(5):
				var angle := i * TAU / 5 - PI / 2
				points.append(center + Vector2(cos(angle), sin(angle)) * radius * 0.3)
			draw_colored_polygon(points, Color.WHITE)

## Draw LOS overlay
func _draw_los_overlay() -> void:
	if not _los_visible:
		return

	# Draw visible cells (green)
	for cell in _los_visible_cells:
		var rect := Rect2(
			Vector2(cell.x * cell_size, cell.y * cell_size),
			Vector2(cell_size, cell_size)
		)
		draw_rect(rect, Color(0.0, 0.8, 0.0, 0.25))

	# Draw blocked cells (red)
	for cell in _los_blocked_cells:
		var rect := Rect2(
			Vector2(cell.x * cell_size, cell.y * cell_size),
			Vector2(cell_size, cell_size)
		)
		draw_rect(rect, Color(0.8, 0.0, 0.0, 0.25))

	# Draw LOS source cell with special highlight
	if _los_source_cell.x >= 0 and _los_source_cell.y >= 0:
		var source_rect := Rect2(
			Vector2(_los_source_cell.x * cell_size, _los_source_cell.y * cell_size),
			Vector2(cell_size, cell_size)
		)
		draw_rect(source_rect, Color.CYAN, false, 3.0)

## Draw selection highlight
func _draw_selection() -> void:
	if selected_cell.x < 0 or selected_cell.y < 0:
		return

	var rect := Rect2(
		Vector2(selected_cell.x * cell_size, selected_cell.y * cell_size),
		Vector2(cell_size, cell_size)
	)
	draw_rect(rect, Color.WHITE, false, 3.0)

## Handle input for cell selection
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := _get_cell_at_position(event.position)
		if cell.x >= 0 and cell.x < grid_size.x and cell.y >= 0 and cell.y < grid_size.y:
			selected_cell = cell

			# Emit appropriate signal based on what's at the cell
			if _is_unit_at_cell(cell):
				var unit_id := _get_unit_at_cell(cell)
				unit_clicked.emit(unit_id)
			elif cell in crew_deployment_zone:
				deployment_zone_clicked.emit("crew", cell)
			elif cell in enemy_deployment_zone:
				deployment_zone_clicked.emit("enemy", cell)
			else:
				terrain_clicked.emit(cell)

			queue_redraw()

## Convert screen position to grid cell
func _get_cell_at_position(screen_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(screen_pos.x / cell_size),
		int(screen_pos.y / cell_size)
	)

## Check if a unit is at a cell
func _is_unit_at_cell(cell: Vector2i) -> bool:
	for unit_id in unit_positions:
		if unit_positions[unit_id].get("position", Vector2i(-1, -1)) == cell:
			return true
	return false

## Get unit ID at a cell
func _get_unit_at_cell(cell: Vector2i) -> String:
	for unit_id in unit_positions:
		if unit_positions[unit_id].get("position", Vector2i(-1, -1)) == cell:
			return unit_id
	return ""

## Toggle grid lines visibility
func toggle_grid_lines(visible: bool) -> void:
	show_grid_lines = visible
	queue_redraw()

## Toggle deployment zones visibility
func toggle_deployment_zones(visible: bool) -> void:
	show_deployment_zones = visible
	queue_redraw()

## Toggle sector visibility
func toggle_sectors(visible: bool) -> void:
	show_sectors = visible
	queue_redraw()

## Clear all terrain and units
func clear() -> void:
	terrain_features.clear()
	unit_positions.clear()
	selected_cell = Vector2i(-1, -1)
	queue_redraw()

## Get grid data for saving/loading
func get_grid_data() -> Dictionary:
	return {
		"table_size": current_table_size,
		"grid_size": grid_size,
		"terrain_features": terrain_features,
		"unit_positions": unit_positions
	}

## Load grid data
func load_grid_data(data: Dictionary) -> void:
	if data.has("table_size"):
		set_table_size(data["table_size"])
	if data.has("terrain_features"):
		terrain_features = data["terrain_features"]
	if data.has("unit_positions"):
		unit_positions = data["unit_positions"]
	queue_redraw()

## Handle resize
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_calculate_cell_size()
		queue_redraw()

## LOS Visualization API

## Show line-of-sight overlay from a unit's position
func show_los_from_unit(unit_position: Vector2i) -> void:
	clear_los_overlay()
	_los_visible = true
	_los_source_cell = unit_position

	# Calculate visible and blocked cells
	var range_limit: int = 24  # Max visibility range (24 inches)

	# Check all cells within range
	for x in range(max(0, unit_position.x - range_limit), min(grid_size.x, unit_position.x + range_limit + 1)):
		for y in range(max(0, unit_position.y - range_limit), min(grid_size.y, unit_position.y + range_limit + 1)):
			var target := Vector2i(x, y)
			if target == unit_position:
				continue  # Skip source cell

			var distance: float = unit_position.distance_to(target)
			if distance > range_limit:
				continue  # Outside range

			# Check LOS using Bresenham's line algorithm
			if _has_line_of_sight(unit_position, target):
				_los_visible_cells.append(target)
			else:
				_los_blocked_cells.append(target)

	queue_redraw()

## Clear all LOS overlay visuals
func clear_los_overlay() -> void:
	_los_visible = false
	_los_source_cell = Vector2i(-1, -1)
	_los_visible_cells.clear()
	_los_blocked_cells.clear()
	queue_redraw()

## Toggle LOS visibility
func toggle_los_visibility(visible: bool) -> void:
	_los_visible = visible
	queue_redraw()

## Check if there's clear LOS between two cells using Bresenham's line
func _has_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	# Bresenham's line algorithm to trace path
	var dx: int = abs(to.x - from.x)
	var dy: int = abs(to.y - from.y)
	var x: int = from.x
	var y: int = from.y
	var n: int = 1 + dx + dy
	var x_inc: int = 1 if to.x > from.x else -1
	var y_inc: int = 1 if to.y > from.y else -1
	var error: int = dx - dy
	dx *= 2
	dy *= 2

	while n > 0:
		var current_cell := Vector2i(x, y)

		# Check if this cell blocks LOS (but skip source and destination)
		if current_cell != from and current_cell != to:
			if _is_blocking_terrain(current_cell):
				return false

		# Advance along line
		if error > 0:
			x += x_inc
			error -= dy
		else:
			y += y_inc
			error += dx
		n -= 1

	return true

## Check if a cell contains blocking terrain
func _is_blocking_terrain(cell: Vector2i) -> bool:
	# Check terrain features for blocking
	for feature in terrain_features:
		var pos: Vector2i = feature.get("position", Vector2i.ZERO)
		var feature_size: Vector2i = feature.get("size", Vector2i(1, 1))
		var category: String = feature.get("category", "small")
		var properties: Dictionary = feature.get("properties", {})

		# Check if cell is within this feature
		if cell.x >= pos.x and cell.x < pos.x + feature_size.x and \
		   cell.y >= pos.y and cell.y < pos.y + feature_size.y:
			# Blocking categories: large, block, interior, linear (walls)
			if category in ["large", "block", "interior", "linear"]:
				return true
			# Non-blocking: small, area, field, open
			# Unless explicitly marked as blocking
			if properties.get("blocks_los", false):
				return true

	return false

## Get LOS status - returns true if visible, false if blocked
func get_los_status(from: Vector2i, to: Vector2i) -> bool:
	return _has_line_of_sight(from, to)
