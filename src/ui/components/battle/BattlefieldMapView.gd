class_name BattlefieldMapView
extends Control

## Graph-paper style battlefield map with terrain features, deployment zones,
## and unit markers. Inspired by labrador.dev/layout_builder and GW mission cards.
##
## Terrain pieces are rendered as ScalableVectorShape2D nodes (RECT/ELLIPSE)
## for crisp anti-aliased vector shapes at any zoom level.
## Background grid, axes, and zones use _draw() for efficiency.

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
# GRAPH-PAPER COLOR PALETTE (labrador.dev style)
# ============================================================================

const COLOR_BACKGROUND := Color(0.96, 0.96, 0.96, 1.0)        # Near-white paper
const COLOR_GRID_LINE := Color(0.82, 0.85, 0.88, 0.4)         # Subtle blue-gray
const COLOR_GRID_LINE_MAJOR := Color(0.70, 0.73, 0.78, 0.5)   # Bolder every 4th
const COLOR_SECTOR_LINE := Color(0.45, 0.48, 0.53, 0.7)       # Sector dividers
const COLOR_SECTOR_LABEL := Color(0.30, 0.30, 0.35, 0.5)      # Subtle dark labels
const COLOR_AXIS_TEXT := Color(0.35, 0.35, 0.40, 0.8)         # Axis numbers
const COLOR_ZONE_CREW := Color(0.18, 0.65, 0.35, 0.12)        # Green overlay
const COLOR_ZONE_ENEMY := Color(0.85, 0.25, 0.25, 0.12)       # Pink/red overlay
const COLOR_CENTER_LINE := Color(0.40, 0.40, 0.45, 0.5)       # Dashed center line
const COLOR_HOVER := Color(0.2, 0.5, 0.8, 0.15)               # Subtle blue hover
const COLOR_UNIT_CREW := Color(0.13, 0.53, 0.90, 0.9)         # Blue crew dots
const COLOR_UNIT_ENEMY := Color(0.85, 0.15, 0.15, 0.9)        # Red enemy dots
const COLOR_UNIT_DEAD := Color(0.50, 0.50, 0.50, 0.6)
const COLOR_LABEL_BG := Color(0.10, 0.10, 0.12, 0.85)         # Black label bg
const COLOR_LABEL_TEXT := Color(0.95, 0.95, 0.95, 1.0)         # White label text
const COLOR_TOOLTIP_BG := Color(0.12, 0.12, 0.15, 0.92)
const COLOR_TOOLTIP_BORDER := Color(0.40, 0.40, 0.45, 0.8)
const COLOR_TOOLTIP_TEXT := Color(0.93, 0.93, 0.93, 1.0)

# ============================================================================
# LAYOUT CONSTANTS
# ============================================================================

const AXIS_MARGIN := 28.0          # Space reserved for axis labels
const SHAPE_SCALE_MULT := 1.5      # Terrain shape scale multiplier
const PLACEMENT_ATTEMPTS := 50     # Random position tries before fallback
const PLACEMENT_PADDING := 20.0    # Min px gap between shapes (pre-scale)

const ZOOM_MIN := 0.5
const ZOOM_MAX := 3.0
const ZOOM_STEP := 0.15

# ============================================================================
# PROPERTIES
# ============================================================================

var cell_size: float = 24.0
var zoom_level: float = 1.0
var pan_offset: Vector2 = Vector2.ZERO
var compact_mode: bool = false
var show_unit_markers: bool = false
var theme_name: String = ""

# ============================================================================
# INTERNAL STATE
# ============================================================================

var _sector_shapes: Array = []     # [row][col] -> Array[Dictionary]
var _sector_features: Array = []   # [row][col] -> Array[String]
var _unit_positions: Array = []
var _hovered_cell: Vector2i = Vector2i(-1, -1)
var _is_panning: bool = false
var _pan_start: Vector2 = Vector2.ZERO
var _deployment_highlighted: bool = false
var _objective_positions: Array[Dictionary] = []  # [{type, grid_pos, label}]
var _active_overlays: Array[Dictionary] = []  # Battle event overlays [{id, type, center, radius, color}]

# Terrain rendering
var _terrain_container: Node2D
var _overlay_control: Control
var _shape_library := BattlefieldShapeLibrary.new()

# Pre-computed organic placements: [row][col] -> Array[Vector2] (normalized 0-1)
var _sector_placements: Array = []

# Tooltip
var _tooltip_panel: PanelContainer
var _tooltip_label: RichTextLabel

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Terrain container (Node2D) — holds ScalableVectorShape2D children
	_terrain_container = Node2D.new()
	_terrain_container.name = "TerrainContainer"
	add_child(_terrain_container)

	# Overlay control — draws labels, unit markers, hover on top of terrain
	_overlay_control = Control.new()
	_overlay_control.name = "OverlayControl"
	_overlay_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_control.draw.connect(_draw_overlay)
	add_child(_overlay_control)

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

func populate_from_sectors(sectors: Array, p_theme_name: String = "") -> void:
	theme_name = p_theme_name

	# Initialize 4x4 sector arrays
	_sector_shapes = []
	_sector_features = []
	for row_i: int in range(4):
		var shape_row: Array = []
		var feat_row: Array = []
		for col_i: int in range(4):
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

	# Objective positions are set externally via set_objective_positions()
	# No hardcoded center default — mission type determines placement

	# Compute organic placements and build SVS terrain nodes
	_rebuild_terrain_shapes()
	queue_redraw()
	_overlay_control.queue_redraw()

func set_unit_positions(units: Array) -> void:
	_unit_positions = units
	_overlay_control.queue_redraw()

func set_compact_mode(enabled: bool) -> void:
	compact_mode = enabled
	if compact_mode:
		zoom_level = 1.0
		pan_offset = Vector2.ZERO
		_hovered_cell = Vector2i(-1, -1)
		_tooltip_panel.visible = false
	_update_terrain_transform()
	queue_redraw()
	_overlay_control.queue_redraw()

func set_deployment_highlight(enabled: bool) -> void:
	_deployment_highlighted = enabled
	queue_redraw()

func set_objective_position(grid_pos: Vector2) -> void:
	## Legacy single-position API — wraps into array format
	_objective_positions = [{"type": "center", "grid_pos": grid_pos, "label": "Objective"}]
	_overlay_control.queue_redraw()

func set_objective_positions(positions: Array) -> void:
	## Set multiple objective markers from BattlefieldGenerator.compute_objective_positions()
	_objective_positions = []
	for pos in positions:
		if pos is Dictionary:
			_objective_positions.append(pos)
	_overlay_control.queue_redraw()

func add_terrain_overlay(overlay: Dictionary) -> void:
	## Add a dynamic overlay from battle events (fog, hazard, markers)
	_active_overlays.append(overlay)
	_overlay_control.queue_redraw()

func remove_terrain_overlay(overlay_id: String) -> void:
	## Remove an overlay by ID
	_active_overlays = _active_overlays.filter(
		func(o: Dictionary) -> bool: return o.get("id", "") != overlay_id)
	_overlay_control.queue_redraw()

func clear_terrain_overlays() -> void:
	_active_overlays.clear()
	_overlay_control.queue_redraw()

func clear() -> void:
	_sector_shapes = []
	_sector_features = []
	_unit_positions = []
	_sector_placements = []
	_hovered_cell = Vector2i(-1, -1)
	_objective_positions = []
	_active_overlays = []
	theme_name = ""
	_tooltip_panel.visible = false
	_clear_terrain_nodes()
	queue_redraw()
	_overlay_control.queue_redraw()

# ============================================================================
# TERRAIN NODE MANAGEMENT
# ============================================================================

func _clear_terrain_nodes() -> void:
	for child in _terrain_container.get_children():
		child.queue_free()

func _rebuild_terrain_shapes() -> void:
	_clear_terrain_nodes()

	if _sector_shapes.is_empty():
		return

	# Seed RNG deterministically so same data = same layout across redraws
	var placement_rng := RandomNumberGenerator.new()
	placement_rng.seed = hash(theme_name) ^ _sector_shapes.size()

	# Initialize placement cache
	_sector_placements = []
	for row_i: int in range(4):
		var row: Array = []
		for col_i: int in range(4):
			row.append([])
		_sector_placements.append(row)

	# Effective cell and sector sizes for placement computation
	var base_cs: float = cell_size
	var sector_w: float = SECTOR_COLS * base_cs
	var sector_h: float = SECTOR_ROWS * base_cs
	var scale_factor: float = SHAPE_SCALE_MULT

	# Cross-sector collision tracking (absolute coordinates)
	var all_placed_rects: Array[Rect2] = []

	for sr: int in range(4):
		for sc: int in range(4):
			var shapes: Array = _sector_shapes[sr][sc]
			if shapes.is_empty():
				_sector_placements[sr][sc] = []
				continue

			# Inset placement area to account for rotation overflow
			var rot_margin: float = 16.0
			var sector_origin := Vector2(
				sc * sector_w + 4.0 + rot_margin,
				sr * sector_h + 14.0 + rot_margin
			)
			var avail_w: float = sector_w - 8.0 - rot_margin * 2.0
			var avail_h: float = sector_h - 18.0 - rot_margin * 2.0

			var placed_rects: Array[Rect2] = []
			var positions: Array = []

			for shape_idx: int in range(shapes.size()):
				var shape: Dictionary = shapes[shape_idx]
				# BUG-040 FIX: Skip scatter items (flavor text, not counted features)
				if shape.get("is_scatter", false):
					continue
				var w: float = shape.get("width", 30.0) * scale_factor
				var h: float = shape.get("height", 20.0) * scale_factor

				# Compute rotation-aware collision padding for this shape
				var shape_type_str: String = shape.get("shape", "rect")
				var max_rot: float = BattlefieldShapeLibrary.get_rotation_range(shape_type_str)
				var rot_padding: float = (sqrt(w * w + h * h) - maxf(w, h)) * 0.5 + 4.0 if max_rot > 0.0 else 0.0

				# Try random positions within sector
				var placed: bool = false
				for attempt: int in range(PLACEMENT_ATTEMPTS):
					var try_x: float = placement_rng.randf() * maxf(avail_w - w, 1.0)
					var try_y: float = placement_rng.randf() * maxf(avail_h - h, 1.0)
					var candidate := Rect2(try_x, try_y, w, h)

					# Check collision with same-sector shapes (rotation-aware)
					var collides: bool = false
					for placed_rect: Rect2 in placed_rects:
						if candidate.grow(PLACEMENT_PADDING + rot_padding).intersects(placed_rect):
							collides = true
							break

					# Check collision with shapes from other sectors (absolute coords)
					if not collides:
						var abs_candidate := Rect2(
							sector_origin.x + try_x, sector_origin.y + try_y, w, h)
						for global_rect: Rect2 in all_placed_rects:
							if abs_candidate.grow(PLACEMENT_PADDING + rot_padding).intersects(global_rect):
								collides = true
								break

					if not collides:
						placed_rects.append(candidate)
						positions.append(sector_origin + Vector2(try_x, try_y))
						all_placed_rects.append(Rect2(
							sector_origin.x + try_x, sector_origin.y + try_y,
						w, h).grow(rot_padding))
						placed = true
						break

				# Fallback: flow-layout with rotation-aware spacing
				if not placed:
					var total_pad: float = PLACEMENT_PADDING + rot_padding
					var fallback_x: float = 0.0
					var fallback_y: float = 0.0
					for existing: Rect2 in placed_rects:
						var candidate_x: float = existing.position.x + existing.size.x + total_pad
						if candidate_x + w <= avail_w:
							fallback_x = candidate_x
							fallback_y = existing.position.y
						else:
							fallback_x = 0.0
							fallback_y = maxf(fallback_y, existing.end.y + total_pad)
					fallback_x = clampf(fallback_x, 0.0, maxf(avail_w - w, 0.0))
					fallback_y = clampf(fallback_y, 0.0, maxf(avail_h - h, 0.0))

					# Cross-sector collision check for fallback position
					var abs_fb := Rect2(
						sector_origin.x + fallback_x,
						sector_origin.y + fallback_y, w, h)
					var fb_retry: int = 0
					while fb_retry < 5:
						var fb_collides: bool = false
						for global_rect: Rect2 in all_placed_rects:
							if abs_fb.grow(total_pad).intersects(global_rect):
								fb_collides = true
								break
						if not fb_collides:
							break
						# Nudge down by shape height + padding
						fallback_y += h + total_pad
						fallback_y = clampf(fallback_y, 0.0, maxf(avail_h - h, 0.0))
						abs_fb = Rect2(
							sector_origin.x + fallback_x,
							sector_origin.y + fallback_y, w, h)
						fb_retry += 1

					var fb_rect := Rect2(fallback_x, fallback_y, w, h)
					placed_rects.append(fb_rect)
					positions.append(sector_origin + Vector2(fallback_x, fallback_y))
					all_placed_rects.append(Rect2(
						sector_origin.x + fallback_x,
						sector_origin.y + fallback_y, w, h).grow(rot_padding))

				# Create the SVS terrain node — position at shape center for symmetric rotation
				var svs: ScalableVectorShape2D = _shape_library.create_vector_shape(
					shape, scale_factor)
				var top_left: Vector2 = positions[positions.size() - 1]
				svs.position = top_left + Vector2(w / 2.0, h / 2.0)
				_terrain_container.add_child(svs)
				# Set offset AFTER add_child so _ready() wires dimensions_changed first
				svs.offset = Vector2(-w / 2.0, -h / 2.0)

				# Apply random rotation (now pivots around shape center)
				if max_rot > 0.0:
					svs.rotation = placement_rng.randf_range(-max_rot, max_rot)

			_sector_placements[sr][sc] = positions

	_update_terrain_transform()

func _get_base_cell_size() -> float:
	## The unzoomed cell size that makes the grid fill the container.
	var margin: float = 0.0 if compact_mode else AXIS_MARGIN * 2
	var available: Vector2 = size - Vector2(margin, margin)
	if available.x <= 0 or available.y <= 0:
		return cell_size
	var fit_x: float = available.x / float(GRID_COLUMNS)
	var fit_y: float = available.y / float(GRID_ROWS)
	return minf(fit_x, fit_y)

func _update_terrain_transform() -> void:
	if not is_instance_valid(_terrain_container):
		return
	var effective_cs: float = _get_effective_cell_size()
	var grid_w: float = GRID_COLUMNS * effective_cs
	var grid_h: float = GRID_ROWS * effective_cs
	var offset: Vector2 = _get_draw_offset(grid_w, grid_h)

	# Scale terrain from placement coords (based on cell_size=24) to actual pixels
	var base_scale: float = effective_cs / cell_size
	_terrain_container.scale = Vector2(base_scale, base_scale)
	_terrain_container.position = offset

# ============================================================================
# RENDERING — Background layer (_draw on self)
# ============================================================================

func _draw() -> void:
	var effective_cell: float = _get_effective_cell_size()
	var grid_pixel_w: float = GRID_COLUMNS * effective_cell
	var grid_pixel_h: float = GRID_ROWS * effective_cell
	var offset: Vector2 = _get_draw_offset(grid_pixel_w, grid_pixel_h)

	# 1. Background
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BACKGROUND)

	# 2. Deployment zone overlays
	_draw_deployment_zones(offset, effective_cell, grid_pixel_w)

	# 3. Grid lines (graph paper)
	_draw_grid_lines(offset, effective_cell, grid_pixel_w, grid_pixel_h)

	# 4. Center line (dashed)
	_draw_center_line(offset, effective_cell, grid_pixel_w)

	# 5. Sector dividers and labels
	_draw_sector_dividers(offset, effective_cell, grid_pixel_w, grid_pixel_h)

	# 6. Axes (numbered borders)
	_draw_axes(offset, effective_cell, grid_pixel_w, grid_pixel_h)

	# Terrain shapes render automatically as SVS child nodes (between self._draw and overlay._draw)

func _get_effective_cell_size() -> float:
	# Always auto-scale to fill the available space, then apply zoom
	var margin: float = 0.0 if compact_mode else AXIS_MARGIN * 2
	var available: Vector2 = size - Vector2(margin, margin)
	if available.x <= 0 or available.y <= 0:
		return cell_size
	var fit_x: float = available.x / float(GRID_COLUMNS)
	var fit_y: float = available.y / float(GRID_ROWS)
	var base_cell: float = minf(fit_x, fit_y)
	if compact_mode:
		return base_cell
	return base_cell * zoom_level

func _get_draw_offset(grid_w: float, grid_h: float) -> Vector2:
	# Center the grid in available space (accounting for axis margins)
	var center_x: float = (size.x - grid_w) / 2.0
	var center_y: float = (size.y - grid_h) / 2.0
	if compact_mode:
		return Vector2(maxf(center_x, 0), maxf(center_y, 0))
	return pan_offset + Vector2(maxf(center_x, AXIS_MARGIN), maxf(center_y, AXIS_MARGIN))

func _draw_deployment_zones(offset: Vector2, cs: float, grid_w: float) -> void:
	var alpha_mult: float = 2.5 if _deployment_highlighted else 1.0

	# Crew zone: rows 0-7 (sectors A and B)
	var crew_h: float = SECTOR_ROWS * 2 * cs
	var crew_color := Color(
		COLOR_ZONE_CREW.r, COLOR_ZONE_CREW.g, COLOR_ZONE_CREW.b,
		minf(COLOR_ZONE_CREW.a * alpha_mult, 0.4))
	draw_rect(Rect2(offset, Vector2(grid_w, crew_h)), crew_color)

	# Enemy zone: rows 8-15 (sectors C and D)
	var enemy_y: float = offset.y + crew_h
	var enemy_h: float = SECTOR_ROWS * 2 * cs
	var enemy_color := Color(
		COLOR_ZONE_ENEMY.r, COLOR_ZONE_ENEMY.g, COLOR_ZONE_ENEMY.b,
		minf(COLOR_ZONE_ENEMY.a * alpha_mult, 0.4))
	draw_rect(
		Rect2(Vector2(offset.x, enemy_y), Vector2(grid_w, enemy_h)),
		enemy_color)

	# Deployment zone labels
	if _deployment_highlighted and cs >= 12.0:
		var font: Font = ThemeDB.fallback_font
		var font_size: int = clampi(int(cs * 1.0), 10, 20)
		var crew_lbl_pos := Vector2(
			offset.x + grid_w / 2.0 - 60,
			offset.y + crew_h / 2.0 + font_size / 2.0)
		draw_string(font, crew_lbl_pos, "CREW DEPLOYMENT",
			HORIZONTAL_ALIGNMENT_CENTER, -1, font_size,
			Color(0.15, 0.50, 0.30, 0.6))
		var enemy_lbl_pos := Vector2(
			offset.x + grid_w / 2.0 - 60,
			enemy_y + enemy_h / 2.0 + font_size / 2.0)
		draw_string(font, enemy_lbl_pos, "ENEMY DEPLOYMENT",
			HORIZONTAL_ALIGNMENT_CENTER, -1, font_size,
			Color(0.70, 0.20, 0.20, 0.6))

func _draw_grid_lines(offset: Vector2, cs: float, grid_w: float, grid_h: float) -> void:
	# Vertical lines
	for col: int in range(GRID_COLUMNS + 1):
		var x: float = offset.x + col * cs
		var is_major: bool = col % 4 == 0
		var color: Color = COLOR_GRID_LINE_MAJOR if is_major else COLOR_GRID_LINE
		var width: float = 1.5 if is_major else 1.0
		draw_line(Vector2(x, offset.y), Vector2(x, offset.y + grid_h), color, width)

	# Horizontal lines
	for row: int in range(GRID_ROWS + 1):
		var y: float = offset.y + row * cs
		var is_major: bool = row % 4 == 0
		var color: Color = COLOR_GRID_LINE_MAJOR if is_major else COLOR_GRID_LINE
		var width: float = 1.5 if is_major else 1.0
		draw_line(Vector2(offset.x, y), Vector2(offset.x + grid_w, y), color, width)

func _draw_center_line(offset: Vector2, cs: float, grid_w: float) -> void:
	var mid_y: float = offset.y + GRID_ROWS / 2.0 * cs
	var dash_len: float = 8.0
	var gap_len: float = 6.0
	var x: float = offset.x
	while x < offset.x + grid_w:
		var end_x: float = minf(x + dash_len, offset.x + grid_w)
		draw_line(Vector2(x, mid_y), Vector2(end_x, mid_y), COLOR_CENTER_LINE, 1.5)
		x += dash_len + gap_len

func _draw_sector_dividers(offset: Vector2, cs: float, grid_w: float, grid_h: float) -> void:
	var sector_w: float = SECTOR_COLS * cs
	var sector_h: float = SECTOR_ROWS * cs

	# Vertical sector dividers
	for col: int in range(5):
		var x: float = offset.x + col * sector_w
		draw_line(Vector2(x, offset.y), Vector2(x, offset.y + grid_h),
			COLOR_SECTOR_LINE, 2.0 if col > 0 and col < 4 else 1.5)

	# Horizontal sector dividers
	for row: int in range(5):
		var y: float = offset.y + row * sector_h
		draw_line(Vector2(offset.x, y), Vector2(offset.x + grid_w, y),
			COLOR_SECTOR_LINE, 2.0 if row > 0 and row < 4 else 1.5)

	# Sector labels (A1-D4) in top-left corner
	if cs >= 10.0:
		var font: Font = ThemeDB.fallback_font
		var font_size: int = clampi(int(cs * 0.6), 8, 16)
		for sr: int in range(4):
			for sc: int in range(4):
				var label_text: String = ROW_LABELS[sr] + COL_LABELS[sc]
				var lx: float = offset.x + sc * sector_w + 3.0
				var ly: float = offset.y + sr * sector_h + font_size + 2.0
				draw_string(font, Vector2(lx, ly), label_text,
					HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, COLOR_SECTOR_LABEL)

func _draw_axes(offset: Vector2, cs: float, grid_w: float, grid_h: float) -> void:
	if compact_mode and cs < 8.0:
		return  # Too small to read axis labels

	var font: Font = ThemeDB.fallback_font
	var font_size: int = clampi(int(cs * 0.45), 8, 14)

	# Five Parsecs table: map 24 columns to ~30", 16 rows to ~20"
	# Each cell ≈ 1.25" horizontal, 1.25" vertical
	var inches_per_col: float = 30.0 / GRID_COLUMNS
	var inches_per_row: float = 20.0 / GRID_ROWS

	# Bottom axis (X — inches from left)
	for col: int in range(GRID_COLUMNS + 1):
		var inch_val: float = col * inches_per_col
		if fmod(inch_val, 5.0) > 0.1:
			continue  # Only label every 5"
		var x: float = offset.x + col * cs
		var label: String = str(int(inch_val))
		draw_string(font, Vector2(x - 4, offset.y + grid_h + font_size + 4),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, COLOR_AXIS_TEXT)

	# Top axis (mirror)
	for col: int in range(GRID_COLUMNS + 1):
		var inch_val: float = col * inches_per_col
		if fmod(inch_val, 5.0) > 0.1:
			continue
		var x: float = offset.x + col * cs
		var label: String = str(int(inch_val))
		draw_string(font, Vector2(x - 4, offset.y - 4),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, COLOR_AXIS_TEXT)

	# Left axis (Y — inches from top)
	for row: int in range(GRID_ROWS + 1):
		var inch_val: float = row * inches_per_row
		if fmod(inch_val, 5.0) > 0.1:
			continue
		var y: float = offset.y + row * cs
		var label: String = str(int(inch_val))
		draw_string(font, Vector2(offset.x - AXIS_MARGIN + 2, y + 4),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, COLOR_AXIS_TEXT)

	# Right axis (mirror)
	for row: int in range(GRID_ROWS + 1):
		var inch_val: float = row * inches_per_row
		if fmod(inch_val, 5.0) > 0.1:
			continue
		var y: float = offset.y + row * cs
		var label: String = str(int(inch_val))
		draw_string(font, Vector2(offset.x + grid_w + 4, y + 4),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, COLOR_AXIS_TEXT)

# ============================================================================
# RENDERING — Overlay layer (terrain labels, unit markers, hover)
# ============================================================================

func _draw_overlay() -> void:
	var effective_cell: float = _get_effective_cell_size()
	var grid_pixel_w: float = GRID_COLUMNS * effective_cell
	var grid_pixel_h: float = GRID_ROWS * effective_cell
	var offset: Vector2 = _get_draw_offset(grid_pixel_w, grid_pixel_h)

	# Terrain labels (notable terrain only, when zoomed in enough)
	if effective_cell >= 20.0:
		_draw_terrain_labels_on(_overlay_control, offset, effective_cell)

	# Objective markers (mission-type aware — may be 0, 1, or multiple)
	for obj_data: Dictionary in _objective_positions:
		var grid_pos: Vector2 = obj_data.get("grid_pos", Vector2(-1, -1))
		if grid_pos != Vector2(-1, -1):
			var obj_label: String = obj_data.get("label", "OBJ")
			_draw_objective_marker(
				_overlay_control, offset, effective_cell,
				grid_pos, obj_label)

	# Battle event overlays (fog, hazard zones, reinforcement markers)
	for overlay: Dictionary in _active_overlays:
		_draw_battle_event_overlay(
			_overlay_control, offset, effective_cell, overlay)

	# Unit markers
	if show_unit_markers:
		_draw_unit_markers_on(_overlay_control, offset, effective_cell)

	# Hover highlight
	if _hovered_cell != Vector2i(-1, -1) and not compact_mode:
		var hx: float = offset.x + _hovered_cell.x * effective_cell
		var hy: float = offset.y + _hovered_cell.y * effective_cell
		_overlay_control.draw_rect(
			Rect2(hx, hy, effective_cell, effective_cell), COLOR_HOVER)

func _draw_terrain_labels_on(canvas: Control, offset: Vector2, cs: float) -> void:
	if _sector_shapes.is_empty() or _sector_placements.is_empty():
		return

	var font: Font = ThemeDB.fallback_font
	var font_size: int = clampi(int(cs * 0.4), 8, 12)
	var scale: float = cs / cell_size

	var inches_per_col: float = 30.0 / GRID_COLUMNS
	var inches_per_row: float = 20.0 / GRID_ROWS

	for sr: int in range(4):
		for sc: int in range(4):
			var shapes: Array = _sector_shapes[sr][sc]
			var placements: Array = _sector_placements[sr][sc]

			for i: int in range(mini(shapes.size(), placements.size())):
				var shape: Dictionary = shapes[i]
				# BUG-040: Skip scatter items in label rendering
				if shape.get("is_scatter", false):
					continue
				var short_label: String = shape.get("short_label", "")
				if short_label.is_empty():
					continue

				var is_notable: bool = shape.get("notable", false)
				var base_pos: Vector2 = placements[i]
				var w: float = shape.get("width", 30.0) * SHAPE_SCALE_MULT * scale
				var h: float = shape.get("height", 20.0) * SHAPE_SCALE_MULT * scale

				# Compute inch position from grid coordinates
				var sw: float = shape.get("width", 30.0) * SHAPE_SCALE_MULT
				var sh: float = shape.get("height", 20.0) * SHAPE_SCALE_MULT
				var inch_x: int = int(
					(base_pos.x + sw * 0.5) / cell_size * inches_per_col)
				var inch_y: int = int(
					(base_pos.y + sh * 0.5) / cell_size * inches_per_row)
				# BUG-041 FIX: Prepend size category prefix
				var cat: String = shape.get("size_category", "")
				var prefix: String = "%s: " % cat if not cat.is_empty() else ""
				var callout: String = "%s%s %d\",%d\"" % [
					prefix, short_label, inch_x, inch_y]

				# Position label below the shape
				var label_x: float = offset.x + base_pos.x * scale
				var label_y: float = offset.y + base_pos.y * scale + h + 4.0
				var label_w: float = font.get_string_size(
					callout, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 8.0

				# Black background pill (warm tint for notable)
				var bg_color: Color = COLOR_LABEL_BG
				if is_notable:
					bg_color = Color(0.15, 0.12, 0.05, 0.9)
				canvas.draw_rect(
					Rect2(label_x, label_y - font_size, label_w, font_size + 4),
					bg_color)
				# White text
				canvas.draw_string(font,
					Vector2(label_x + 4, label_y),
					callout, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
					COLOR_LABEL_TEXT)

func _draw_unit_markers_on(canvas: Control, offset: Vector2, cs: float) -> void:
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

		canvas.draw_circle(center, marker_radius, color)

		if status == "dead":
			var xs: float = marker_radius * 0.6
			canvas.draw_line(center - Vector2(xs, xs), center + Vector2(xs, xs),
				Color.WHITE.darkened(0.3), 2.0)
			canvas.draw_line(center - Vector2(-xs, xs), center + Vector2(-xs, xs),
				Color.WHITE.darkened(0.3), 2.0)
		else:
			canvas.draw_circle(center, marker_radius * 0.3, color.lightened(0.4))

func _draw_objective_marker(canvas: Control, offset: Vector2,
		cs: float, grid_pos: Vector2, label_text: String) -> void:
	var center := Vector2(
		offset.x + grid_pos.x * cs,
		offset.y + grid_pos.y * cs)
	var marker_size: float = cs * 1.5

	# Diamond shape
	var hw: float = marker_size / 2.0
	var points := PackedVector2Array([
		center + Vector2(0, -hw),
		center + Vector2(hw, 0),
		center + Vector2(0, hw),
		center + Vector2(-hw, 0),
	])
	canvas.draw_colored_polygon(
		points, Color(0.96, 0.78, 0.04, 0.25))
	canvas.draw_polyline(
		points, Color(0.96, 0.78, 0.04, 0.9), 2.0)
	# Close the diamond outline
	canvas.draw_line(
		points[3], points[0],
		Color(0.96, 0.78, 0.04, 0.9), 2.0)

	# Center dot
	canvas.draw_circle(
		center, cs * 0.2, Color(0.96, 0.78, 0.04, 0.8))

	# Label
	var font: Font = ThemeDB.fallback_font
	var fsize: int = clampi(int(cs * 0.5), 8, 14)
	var short_label: String = label_text.left(12)
	canvas.draw_string(font,
		Vector2(center.x - 10, center.y + hw + fsize + 4),
		short_label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize,
		Color(0.96, 0.78, 0.04, 1.0))

func _draw_battle_event_overlay(canvas: Control,
		offset: Vector2, cs: float, overlay: Dictionary) -> void:
	## Draw a battle event overlay (fog cloud, hazard zone, markers)
	var o_type: String = overlay.get("type", "")
	var o_center: Vector2 = overlay.get("center", Vector2(12, 8))
	var o_radius: float = overlay.get("radius", 6.0)
	var px_center := Vector2(
		offset.x + o_center.x * cs,
		offset.y + o_center.y * cs)
	var px_radius: float = o_radius * cs

	match o_type:
		"fog":
			# Core Rules p.117 roll 81-85: Fog cloud at center
			canvas.draw_circle(
				px_center, px_radius,
				Color(0.5, 0.5, 0.55, 0.15))
			canvas.draw_arc(
				px_center, px_radius, 0, TAU, 64,
				Color(0.5, 0.5, 0.55, 0.4), 2.0)
		"hazard":
			# Core Rules p.117 roll 55-60: Environmental hazard
			canvas.draw_circle(
				px_center, px_radius,
				Color(0.86, 0.15, 0.15, 0.12))
			canvas.draw_arc(
				px_center, px_radius, 0, TAU, 64,
				Color(0.86, 0.15, 0.15, 0.5), 2.0)
		"reinforcement_marker":
			# Core Rules p.117 roll 47-50: Marker on enemy edge
			var hw: float = cs * 0.6
			var pts := PackedVector2Array([
				px_center + Vector2(0, -hw),
				px_center + Vector2(hw, 0),
				px_center + Vector2(0, hw),
				px_center + Vector2(-hw, 0)])
			canvas.draw_colored_polygon(
				pts, Color(0.9, 0.6, 0.1, 0.3))
			canvas.draw_polyline(
				pts, Color(0.9, 0.6, 0.1, 0.8), 2.0)
			canvas.draw_line(
				pts[3], pts[0],
				Color(0.9, 0.6, 0.1, 0.8), 2.0)

	# Label
	var o_label: String = overlay.get("label", "")
	if not o_label.is_empty():
		var font: Font = ThemeDB.fallback_font
		var fsize: int = clampi(int(cs * 0.4), 7, 12)
		canvas.draw_string(font,
			Vector2(px_center.x - 20, px_center.y - px_radius - 4),
			o_label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize,
			Color(0.9, 0.9, 0.9, 0.8))

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
			_update_terrain_transform()
			queue_redraw()
			_overlay_control.queue_redraw()
		else:
			_update_hover(mm.position)

func _zoom(delta: float, anchor: Vector2) -> void:
	var old_zoom: float = zoom_level
	zoom_level = clampf(zoom_level + delta, ZOOM_MIN, ZOOM_MAX)
	if zoom_level == old_zoom:
		return

	var zoom_ratio: float = zoom_level / old_zoom
	pan_offset = anchor - (anchor - pan_offset) * zoom_ratio
	_update_terrain_transform()
	queue_redraw()
	_overlay_control.queue_redraw()

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
	_overlay_control.queue_redraw()

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

	var bbcode: String = "[b]%s[/b]" % sector_label
	if features.is_empty():
		bbcode += "\nOpen ground"
	else:
		for feat: String in features:
			bbcode += "\n%s" % feat
	_tooltip_label.text = bbcode
	_tooltip_panel.visible = true

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
			_overlay_control.queue_redraw()
	elif what == NOTIFICATION_RESIZED:
		_update_terrain_transform()
		queue_redraw()
		if is_instance_valid(_overlay_control):
			_overlay_control.queue_redraw()

# ============================================================================
# COORDINATE HELPERS
# ============================================================================

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

func _grid_to_sector_label(cell: Vector2i) -> String:
	var sr: int = cell.y / SECTOR_ROWS
	var sc: int = cell.x / SECTOR_COLS
	if sr < 0 or sr >= 4 or sc < 0 or sc >= 4:
		return ""
	return ROW_LABELS[sr] + COL_LABELS[sc]
