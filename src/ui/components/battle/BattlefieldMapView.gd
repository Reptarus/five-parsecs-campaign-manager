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
signal unit_right_clicked(unit_index: int, screen_pos: Vector2)
signal unit_position_changed(unit_index: int, new_grid_pos: Vector2i)

# ============================================================================
# GRID DIMENSIONS — square book tables (Core Rules p.108), 1.5"/cell
# ============================================================================

# Defaults = 3x3 ft (24x24 cells, 4x4 sectors of 6x6). Reconfigured via
# configure_grid(FPCM_BattlefieldGrid.dims_for_table(ft)) BEFORE populate.
# Uppercase to preserve the ~40 existing read sites — treat as read-only
# outside configure_grid(). (The old 24x16 grid mapped to a 30"x20" table,
# a size that exists nowhere in the book — fixed 2026-07-03.)
var GRID_COLUMNS := 24      # 4 sectors * 6 cells each
var GRID_ROWS := 24         # 4 sectors * 6 cells each
var SECTOR_COLS := 6        # cells per sector horizontally
var SECTOR_ROWS := 6        # cells per sector vertically
var table_inches := 36.0    # physical table side length
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

# STABLE placement-base unit. Terrain is baked in this space; the transform,
# my BUG-101 grid-rect clamp, and label/inch conversions all divide by it.
# Do NOT mutate after construction (a resize handler used to, which
# collapsed terrain top-left — see BUG-102). On-screen size = _get_effective_cell_size().
var cell_size: float = 24.0
var zoom_level: float = 1.0
var pan_offset: Vector2 = Vector2.ZERO
var compact_mode: bool = false
var show_unit_markers: bool = false
var show_scatter: bool = true
var theme_name: String = ""
# Set by populate_from_sectors caller — drives atmospheric overlay rendering
var current_world_traits: Array = []

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

# EDIT 15: drag-and-drop state — caller toggles allow_unit_drag during DEPLOYMENT.
var _dragging_unit_idx: int = -1
var allow_unit_drag: bool = false

# Terrain rendering
var _terrain_container: Node2D
var _overlay_control: Control
var _shape_library := BattlefieldShapeLibrary.new()

# BUG-102: set when _update_terrain_transform() ran before the control had a
# valid size (terrain clustered top-left). Healed on the first _draw() with a
# real size, so the first battle render no longer needs a manual Regenerate.
var _transform_dirty: bool = false

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
	focus_mode = Control.FOCUS_ALL  # Enable keyboard input for pan/zoom shortcuts

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

	# Callers that construct-then-add (PreBattleUI preview, PostBattle recap)
	# may call populate_from_sectors() BEFORE this node is in the tree, when
	# _terrain_container is still null. In that case populate stored the
	# sector data but _rebuild_terrain_shapes bailed — render it now that
	# the container exists (2026-07-03; campaign-path preview crash).
	if not _sector_shapes.is_empty():
		_rebuild_terrain_shapes()
		queue_redraw()
		_overlay_control.queue_redraw()

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

## Configure the grid for a book table size (Core Rules p.108). Call BEFORE
## populate_from_sectors; if terrain is already baked, it re-bakes in the
## new geometry. dims from FPCM_BattlefieldGrid.dims_for_table().
## cell_size (the stable placement base) is NEVER touched — BUG-102.
func configure_grid(dims: Dictionary) -> void:
	if dims.is_empty():
		return
	var new_cols: int = int(dims.get("cols", GRID_COLUMNS))
	var new_rows: int = int(dims.get("rows", GRID_ROWS))
	var new_sc: int = int(dims.get("sector_cols", SECTOR_COLS))
	var new_sr: int = int(dims.get("sector_rows", SECTOR_ROWS))
	var new_inches: float = float(dims.get("table_inches", table_inches))
	if new_cols == GRID_COLUMNS and new_rows == GRID_ROWS \
			and new_sc == SECTOR_COLS and new_sr == SECTOR_ROWS \
			and is_equal_approx(new_inches, table_inches):
		return
	GRID_COLUMNS = new_cols
	GRID_ROWS = new_rows
	SECTOR_COLS = new_sc
	SECTOR_ROWS = new_sr
	table_inches = new_inches
	# Pre-_ready() safe (recap builds the view before add_child): just
	# record the geometry — _ready + populate consume it.
	if _terrain_container == null:
		return
	# Re-bake terrain placement in the new geometry if already populated
	if not _sector_features.is_empty():
		_rebuild_terrain_shapes()
	_update_terrain_transform()
	queue_redraw()
	if _overlay_control:
		_overlay_control.queue_redraw()

func populate_from_sectors(sectors: Array, p_theme_name: String = "",
		world_traits: Array = []) -> void:
	theme_name = p_theme_name
	current_world_traits = world_traits

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

	# Compute organic placements and build SVS terrain nodes. All three are
	# no-ops / deferred when called before this node enters the tree (the
	# construct-then-add callers); _ready() re-runs them.
	_rebuild_terrain_shapes()
	queue_redraw()
	if _overlay_control:
		_overlay_control.queue_redraw()

func set_unit_positions(units: Array) -> void:
	_unit_positions = units
	_overlay_control.queue_redraw()

func set_show_scatter(enabled: bool) -> void:
	## Toggle scatter (small terrain dots) visibility. Triggers full terrain rebuild
	## since scatter is filtered during _rebuild_terrain_shapes.
	if show_scatter == enabled:
		return
	show_scatter = enabled
	_rebuild_terrain_shapes()
	queue_redraw()
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
	# Null-safe: the preview sets objectives before add_child; _ready redraws.
	if _overlay_control:
		_overlay_control.queue_redraw()

func set_objective_positions(positions: Array) -> void:
	## Set multiple objective markers from BattlefieldGenerator.compute_objective_positions()
	_objective_positions = []
	for pos in positions:
		if pos is Dictionary:
			_objective_positions.append(pos)
	# Null-safe: the preview sets objectives before add_child; _ready redraws.
	if _overlay_control:
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

func _hit_test_unit_marker(local_pos: Vector2) -> int:
	## Returns the unit index if local_pos is within the marker radius of any
	## unit, else -1. Mirrors the marker-rendering geometry in _draw_unit_markers_on.
	if _unit_positions.is_empty():
		return -1
	var effective_cell: float = _get_effective_cell_size()
	var grid_pixel_w: float = GRID_COLUMNS * effective_cell
	var grid_pixel_h: float = GRID_ROWS * effective_cell
	var offset: Vector2 = _get_draw_offset(grid_pixel_w, grid_pixel_h)
	var marker_radius: float = effective_cell * 0.35
	for i in range(_unit_positions.size()):
		var unit: Dictionary = _unit_positions[i]
		var grid_pos: Vector2i = unit.get("position", Vector2i.ZERO)
		var center := Vector2(
			offset.x + (grid_pos.x + 0.5) * effective_cell,
			offset.y + (grid_pos.y + 0.5) * effective_cell)
		if local_pos.distance_to(center) <= marker_radius:
			return i
	return -1

func tick_overlay_durations() -> void:
	## Decrement duration_rounds on all overlays. Remove those that expire.
	## Permanent overlays (duration_rounds = 0) are unaffected.
	## Called by TacticalBattleUI on each round_started.
	var still_alive: Array[Dictionary] = []
	for overlay: Dictionary in _active_overlays:
		var dur: int = int(overlay.get("duration_rounds", 0))
		if dur <= 0:
			still_alive.append(overlay)
		else:
			overlay["duration_rounds"] = dur - 1
			if overlay["duration_rounds"] > 0:
				still_alive.append(overlay)
	if still_alive.size() != _active_overlays.size():
		_active_overlays = still_alive
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
	if _terrain_container == null:
		return
	for child in _terrain_container.get_children():
		child.queue_free()

func _rebuild_terrain_shapes() -> void:
	# Pre-_ready() safe: if populate_from_sectors() was called before this
	# node entered the tree, the container does not exist yet. The sector
	# data is already stored; _ready() re-runs this once the container is up.
	if _terrain_container == null:
		return
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

			# Count non-scatter features for density-adaptive scaling
			var feature_count: int = shapes.filter(
				func(s): return not s.get("is_scatter", false)).size()

			# Fix 0a: Adaptive scale for dense sectors — shapes must fit
			var local_scale: float = scale_factor
			if feature_count >= 4:
				local_scale *= 0.6
			elif feature_count >= 3:
				local_scale *= 0.75

			# Fix 0c: Proportional rotation margin based on actual shape rotations
			var max_shape_rot: float = 0.0
			for s_info: Dictionary in shapes:
				if not s_info.get("is_scatter", false):
					var st: String = s_info.get("shape", "rect")
					max_shape_rot = maxf(max_shape_rot,
						BattlefieldShapeLibrary.get_rotation_range(st))
			var rot_margin: float = 4.0 + max_shape_rot * 8.0 / PI

			var sector_origin := Vector2(
				sc * sector_w + 4.0 + rot_margin,
				sr * sector_h + 14.0 + rot_margin
			)
			var avail_w: float = maxf(sector_w - 8.0 - rot_margin * 2.0, 20.0)
			var avail_h: float = maxf(sector_h - 18.0 - rot_margin * 2.0, 20.0)

			# Fix 0e: Reduce padding for dense sectors
			var total_shape_area: float = 0.0
			for s_area: Dictionary in shapes:
				if not s_area.get("is_scatter", false):
					total_shape_area += s_area.get("width", 30.0) \
						* s_area.get("height", 20.0) * local_scale * local_scale
			var density: float = total_shape_area / maxf(
				avail_w * avail_h, 1.0)
			# AREA-FIT (terrain-overlap root fix): collision can only REJECT
			# positions, never create space. If a sector holds more padded
			# feature area than random packing fits, the fallback stacks
			# features (observed 100% overlap). Shrink ALL of this sector's
			# shapes up front to a packable density. Better small terrain
			# than overlapping terrain (the map is suggestive, not to scale).
			if density > 0.42:
				var fit_factor: float = sqrt(0.42 / density)
				var new_scale: float = maxf(local_scale * fit_factor, scale_factor * 0.22)
				density *= pow(new_scale / local_scale, 2.0)
				local_scale = new_scale

			var effective_padding: float = PLACEMENT_PADDING
			if density > 0.4:
				effective_padding = maxf(PLACEMENT_PADDING * 0.5, 6.0)

			var positions: Array = []
			var grid_pc_w: float = GRID_COLUMNS * cell_size
			var grid_pc_h: float = GRID_ROWS * cell_size

			for shape_idx: int in range(shapes.size()):
				var shape: Dictionary = shapes[shape_idx]
				# BUG-040: Skip scatter unless show_scatter is enabled
				if shape.get("is_scatter", false) and not show_scatter:
					continue
				var w: float = shape.get("width", 30.0) * local_scale
				var h: float = shape.get("height", 20.0) * local_scale
				var shape_type_str: String = shape.get("shape", "rect")
				var max_rot: float = BattlefieldShapeLibrary.get_rotation_range(shape_type_str)

				# TERRAIN-OVERLAP FIX: the deconfliction MUST test the final
				# drawn footprint. Previously the boundary clamp + rotation ran
				# AFTER collision/recording, so shapes were nudged into each
				# other post-test (and oversized shapes all snapped to grid
				# centre). Decide rotation + the true rotation/stroke-aware
				# half-extents FIRST, clamp every candidate to grid bounds
				# BEFORE the collision test, and store that exact rect.
				var svs: ScalableVectorShape2D = _shape_library.create_vector_shape(
					shape, local_scale)
				var rot: float = 0.0
				if max_rot > 0.0:
					rot = placement_rng.randf_range(-max_rot, max_rot)
				var stroke_pad: float = 1.0
				if "stroke_width" in svs:
					stroke_pad = maxf(float(svs.stroke_width) * 0.5, 0.0)
				var cosr: float = absf(cos(rot))
				var sinr: float = absf(sin(rot))
				var half_x: float = (cosr * w + sinr * h) / 2.0 + stroke_pad
				var half_y: float = (sinr * w + cosr * h) / 2.0 + stroke_pad
				var pad: float = effective_padding / 2.0

				# NOTE: NO lambdas here. A captured Array closure made the
				# collision test read stale/empty data (every shape "passed"
				# -> 100% overlaps). All collision math is inline so it reads
				# the shared `all_placed_rects` directly.

				# Random placement: clamp the DRAWN centre to grid bounds, then
				# test that exact footprint against everything already placed.
				var final_center := Vector2.ZERO
				var placed: bool = false
				for attempt: int in range(PLACEMENT_ATTEMPTS):
					var try_x: float = placement_rng.randf() * maxf(avail_w - w, 1.0)
					var try_y: float = placement_rng.randf() * maxf(avail_h - h, 1.0)
					var c := sector_origin + Vector2(
						try_x + w / 2.0, try_y + h / 2.0)
					if half_x * 2.0 >= grid_pc_w:
						c.x = grid_pc_w / 2.0
					else:
						c.x = clampf(c.x, half_x, grid_pc_w - half_x)
					if half_y * 2.0 >= grid_pc_h:
						c.y = grid_pc_h / 2.0
					else:
						c.y = clampf(c.y, half_y, grid_pc_h - half_y)
					var fr := Rect2(c.x - half_x, c.y - half_y,
						half_x * 2.0, half_y * 2.0).grow(pad)
					var collides: bool = false
					for gr: Rect2 in all_placed_rects:
						if fr.intersects(gr):
							collides = true
							break
					if not collides:
						final_center = c
						placed = true
						break

				# Grid-distributed fallback (still clamped + collision-nudged).
				if not placed:
					var slot_idx: int = positions.size()
					var grid_cols: int = maxi(
						ceili(sqrt(float(feature_count))), 1)
					var grid_rows_count: int = maxi(
						ceili(float(feature_count) / float(grid_cols)), 1)
					var slot_w: float = avail_w / float(grid_cols)
					var slot_h: float = avail_h / float(grid_rows_count)
					var gx: int = slot_idx % grid_cols
					var gy: int = slot_idx / grid_cols
					var fb_x: float = gx * slot_w + maxf((slot_w - w) / 2.0, 0.0)
					var fb_y: float = gy * slot_h + maxf((slot_h - h) / 2.0, 0.0)
					var c := sector_origin + Vector2(
						fb_x + w / 2.0, fb_y + h / 2.0)
					var fb_retry: int = 0
					while fb_retry < 16:
						if half_x * 2.0 >= grid_pc_w:
							c.x = grid_pc_w / 2.0
						else:
							c.x = clampf(c.x, half_x, grid_pc_w - half_x)
						if half_y * 2.0 >= grid_pc_h:
							c.y = grid_pc_h / 2.0
						else:
							c.y = clampf(c.y, half_y, grid_pc_h - half_y)
						var fr := Rect2(c.x - half_x, c.y - half_y,
							half_x * 2.0, half_y * 2.0).grow(pad)
						var coll: bool = false
						for gr: Rect2 in all_placed_rects:
							if fr.intersects(gr):
								coll = true
								break
						if not coll:
							break
						# Nudge down a full footprint; re-clamped next pass.
						c.y += half_y * 2.0 + effective_padding
						fb_retry += 1
					final_center = c

				# Record the EXACT drawn footprint (collision + cache agree).
				all_placed_rects.append(Rect2(
					final_center.x - half_x, final_center.y - half_y,
					half_x * 2.0, half_y * 2.0))
				positions.append(final_center - Vector2(w / 2.0, h / 2.0))

				# ScalableVectorShape2D draws the body centered on `offset` in
				# LOCAL space, rotated by the node rotation. On-screen centre is
				# `position + offset.rotated(rot)`, NOT `position`. Back-solve
				# position so the DRAWN centre lands exactly on final_center
				# (BUG-101).
				var body_offset := Vector2(-w / 2.0, -h / 2.0)
				_terrain_container.add_child(svs)
				# Set offset AFTER add_child so _ready() wires dimensions_changed first
				svs.offset = body_offset
				if rot != 0.0:
					svs.rotation = rot
				svs.position = final_center - body_offset.rotated(rot)

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
	# BUG-102: before the control has a valid size, _get_effective_cell_size()
	# falls back to cell_size and _get_draw_offset() clamps to ~top-left, so
	# applying now clusters all terrain in the corner. Defer to the first
	# _draw() with a real size instead of baking a wrong transform.
	var margin: float = 0.0 if compact_mode else AXIS_MARGIN * 2
	var avail: Vector2 = size - Vector2(margin, margin)
	if avail.x <= 0.0 or avail.y <= 0.0:
		_transform_dirty = true
		return
	var effective_cs: float = _get_effective_cell_size()
	var grid_w: float = GRID_COLUMNS * effective_cs
	var grid_h: float = GRID_ROWS * effective_cs
	var offset: Vector2 = _get_draw_offset(grid_w, grid_h)

	# Scale terrain from the fixed placement space (cell_size, stable 24) to
	# screen pixels. cell_size MUST equal the value placement was baked with;
	# it is never mutated now (BUG-102 root-cause fix).
	var base_scale: float = effective_cs / cell_size
	_terrain_container.scale = Vector2(base_scale, base_scale)
	_terrain_container.position = offset
	_transform_dirty = false

# ============================================================================
# RENDERING — Background layer (_draw on self)
# ============================================================================

func _draw() -> void:
	# BUG-102: heal a transform computed before this control had a valid size.
	# _draw() runs only once the control is laid out, so the size is real here.
	if _transform_dirty:
		_update_terrain_transform()

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
	# Batched: 2 draw_multiline calls instead of ~50 draw_line calls.
	# This redraws every drag frame during pan/zoom — the docs recommend
	# multiline for many uniform segments (Godot 4.6 CanvasItem).
	var minor_pts := PackedVector2Array()
	var major_pts := PackedVector2Array()
	for col: int in range(GRID_COLUMNS + 1):
		var x: float = offset.x + col * cs
		if col % 4 == 0:
			major_pts.push_back(Vector2(x, offset.y))
			major_pts.push_back(Vector2(x, offset.y + grid_h))
		else:
			minor_pts.push_back(Vector2(x, offset.y))
			minor_pts.push_back(Vector2(x, offset.y + grid_h))
	for row: int in range(GRID_ROWS + 1):
		var y: float = offset.y + row * cs
		if row % 4 == 0:
			major_pts.push_back(Vector2(offset.x, y))
			major_pts.push_back(Vector2(offset.x + grid_w, y))
		else:
			minor_pts.push_back(Vector2(offset.x, y))
			minor_pts.push_back(Vector2(offset.x + grid_w, y))
	if minor_pts.size() >= 2:
		draw_multiline(minor_pts, COLOR_GRID_LINE, 1.0)
	if major_pts.size() >= 2:
		draw_multiline(major_pts, COLOR_GRID_LINE_MAJOR, 1.5)

func _draw_center_line(offset: Vector2, cs: float, grid_w: float) -> void:
	# Batched dashes: one draw_multiline call
	var mid_y: float = offset.y + GRID_ROWS / 2.0 * cs
	var dash_len: float = 8.0
	var gap_len: float = 6.0
	var dash_pts := PackedVector2Array()
	var x: float = offset.x
	while x < offset.x + grid_w:
		var end_x: float = minf(x + dash_len, offset.x + grid_w)
		dash_pts.push_back(Vector2(x, mid_y))
		dash_pts.push_back(Vector2(end_x, mid_y))
		x += dash_len + gap_len
	if dash_pts.size() >= 2:
		draw_multiline(dash_pts, COLOR_CENTER_LINE, 1.5)

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

	# Square book table (Core Rules p.108): table_inches per side, 1.5"/cell
	var inches_per_col: float = table_inches / GRID_COLUMNS
	var inches_per_row: float = table_inches / GRID_ROWS

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

	# World trait atmospheric overlay (haze/gloom/frozen/null_zone/warzone/overgrown/...)
	# Renders BEFORE terrain labels so labels stay readable.
	if not current_world_traits.is_empty():
		var full_rect := Rect2(offset, Vector2(grid_pixel_w, grid_pixel_h))
		_draw_world_trait_atmosphere(_overlay_control, full_rect, effective_cell)

	# Terrain labels (notable terrain only, when zoomed in enough)
	if effective_cell >= 20.0:
		_draw_terrain_labels_on(_overlay_control, offset, effective_cell)

	# Objective markers (mission-type aware — may be 0, 1, or multiple)
	for obj_data: Dictionary in _objective_positions:
		var grid_pos: Vector2 = obj_data.get("grid_pos", Vector2(-1, -1))
		if grid_pos != Vector2(-1, -1):
			var obj_label: String = obj_data.get("label", "OBJ")
			var obj_rule: String = obj_data.get("rule", "")
			_draw_objective_marker(
				_overlay_control, offset, effective_cell,
				grid_pos, obj_label, obj_rule)

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

	var inches_per_col: float = table_inches / GRID_COLUMNS
	var inches_per_row: float = table_inches / GRID_ROWS

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
				# Phase 5: Append terrain rules category badge.
				# Interior=[In] vs Individual=[I] — first-letter collision
				# fixed via get_category_badge (2026-07-02).
				var full_label: String = shape.get("label", "")
				var rules_cat: String = BattlefieldShapeLibrary \
					.classify_terrain_rules_category(full_label)
				var badge: String = BattlefieldShapeLibrary.get_category_badge(rules_cat) \
					if not rules_cat.is_empty() else ""
				var callout: String = "%s%s %d\",%d\" [%s]" % [
					prefix, short_label, inch_x, inch_y, badge]

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
				# Cover indicator chip — green (full), orange (partial), none (open Field)
				# Drives off the same rules_cat as the [L]/[I]/[A]/[F]/[B]/[I] badge above.
				var cover_chip_color: Color = Color.TRANSPARENT
				match rules_cat:
					"Block", "Interior":
						cover_chip_color = Color(0.06, 0.73, 0.51, 0.9)  # Green = full cover
					"Linear", "Area":
						cover_chip_color = Color(0.85, 0.46, 0.02, 0.9)  # Orange = partial
					"Individual":
						cover_chip_color = Color(0.85, 0.46, 0.02, 0.7)
					# Field gets no chip (no cover available)
				if cover_chip_color.a > 0:
					canvas.draw_circle(
						Vector2(label_x + label_w - 8.0, label_y - font_size / 2.0),
						3.5, cover_chip_color)
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
		cs: float, grid_pos: Vector2, label_text: String,
		rule_text: String = "") -> void:
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

	# Label — primary objective name, centered under the diamond, prefixed
	# "OBJECTIVE:" so a center-pinned marker reads as deliberate.
	var font: Font = ThemeDB.fallback_font
	var fsize: int = clampi(int(cs * 0.5), 8, 14)
	var box_w: float = maxf(cs * 10.0, 160.0)
	var box_x: float = center.x - box_w / 2.0
	var primary: String = "OBJECTIVE: %s" % _truncate_words(label_text, 22)
	var primary_y: float = center.y + hw + fsize + 4
	canvas.draw_string(font,
		Vector2(box_x, primary_y),
		primary, HORIZONTAL_ALIGNMENT_CENTER, box_w, fsize,
		Color(0.96, 0.78, 0.04, 1.0))

	# Rule cite — verbatim-faithful provenance from BattlefieldGenerator
	# (Core Rules p.90). Communicates the dead-center placement is the
	# intended tabletop rule, not a layout bug.
	if not rule_text.is_empty():
		var rsize: int = clampi(int(cs * 0.38), 7, 11)
		canvas.draw_string(font,
			Vector2(box_x, primary_y + rsize + 3),
			rule_text, HORIZONTAL_ALIGNMENT_CENTER, box_w, rsize,
			Color(0.96, 0.78, 0.04, 0.62))

func _truncate_words(text: String, max_len: int) -> String:
	## Word-boundary truncation with ellipsis — avoids cutting mid-word so a
	## long mission objective still reads as a deliberate label, not garbled.
	if text.length() <= max_len:
		return text
	var cut: String = text.substr(0, max_len)
	var last_space: int = cut.rfind(" ")
	if last_space >= int(max_len * 0.5):
		cut = cut.substr(0, last_space)
	return cut.strip_edges() + "…"

func _draw_world_trait_atmosphere(canvas: Control, full_rect: Rect2, effective_cell: float) -> void:
	## Render visual representation for the 10 silent world traits.
	## Driven by current_world_traits set in populate_from_sectors.
	## Trait keywords match data/world_traits.json IDs (Core Rules pp.72-75).
	for trait_entry in current_world_traits:
		var tid: String = ""
		if trait_entry is String:
			tid = String(trait_entry).to_lower()
		elif trait_entry is Dictionary:
			tid = String(trait_entry.get("id", "")).to_lower()
		else:
			continue
		match tid:
			"haze":
				canvas.draw_rect(full_rect, Color(1.0, 0.7, 0.3, 0.10))
			"gloom":
				canvas.draw_rect(full_rect, Color(0.3, 0.2, 0.5, 0.12))
			"frozen":
				canvas.draw_rect(full_rect, Color(0.7, 0.85, 1.0, 0.10))
			"null_zone":
				canvas.draw_rect(full_rect, Color(0.0, 0.0, 0.0, 0.20))
			"reflective_dust":
				# Subtle white shimmer (looping animation handled by caller if desired)
				canvas.draw_rect(full_rect, Color(1.0, 1.0, 1.0, 0.06))
			"warzone":
				# 4 craters at deterministic positions (seed by theme_name for stability)
				var crater_rng := RandomNumberGenerator.new()
				crater_rng.seed = hash("warzone:" + theme_name)
				for ci in range(4):
					var cx: float = full_rect.position.x + crater_rng.randf() * full_rect.size.x
					var cy: float = full_rect.position.y + crater_rng.randf() * full_rect.size.y
					canvas.draw_circle(
						Vector2(cx, cy),
						effective_cell * 1.2,
						Color(0.15, 0.10, 0.08, 0.50))
			"overgrown":
				var veg_rng := RandomNumberGenerator.new()
				veg_rng.seed = hash("overgrown:" + theme_name)
				for vi in range(12):
					var vx: float = full_rect.position.x + veg_rng.randf() * full_rect.size.x
					var vy: float = full_rect.position.y + veg_rng.randf() * full_rect.size.y
					canvas.draw_circle(
						Vector2(vx, vy),
						effective_cell * 0.18,
						Color(0.13, 0.40, 0.18, 0.6))
			# barren / flat / crystals / fog handled by generator + event overlays already
			_:
				pass

func _draw_battle_event_overlay(canvas: Control,
		offset: Vector2, cs: float, overlay: Dictionary) -> void:
	## Draw a battle event overlay (fog cloud, hazard zone, markers)
	var o_type: String = overlay.get("type", "")
	var o_center: Vector2 = overlay.get("center",
		Vector2(GRID_COLUMNS / 2.0, GRID_ROWS / 2.0))
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
				MOUSE_BUTTON_RIGHT:
					var hit_idx: int = _hit_test_unit_marker(mb.position)
					if hit_idx >= 0:
						unit_right_clicked.emit(hit_idx, mb.global_position)
						accept_event()
				MOUSE_BUTTON_LEFT:
					if allow_unit_drag:
						var hit_idx: int = _hit_test_unit_marker(mb.position)
						if hit_idx >= 0:
							_dragging_unit_idx = hit_idx
							accept_event()
							return
					_handle_click(mb.position)
					accept_event()
		else:
			if mb.button_index == MOUSE_BUTTON_MIDDLE:
				_is_panning = false
			elif mb.button_index == MOUSE_BUTTON_LEFT and _dragging_unit_idx >= 0:
				# Drag release — validate deployment zone and commit
				var new_cell: Vector2i = _mouse_to_grid(mb.position)
				if new_cell != Vector2i(-1, -1):
					var unit: Dictionary = _unit_positions[_dragging_unit_idx]
					var is_crew: bool = str(unit.get("team", "crew")) == "crew"
					@warning_ignore("integer_division")
					var half_row: int = GRID_ROWS / 2
					var in_zone: bool = (is_crew and new_cell.y < half_row) or \
						(not is_crew and new_cell.y >= half_row)
					if in_zone:
						_unit_positions[_dragging_unit_idx]["position"] = new_cell
						unit_position_changed.emit(_dragging_unit_idx, new_cell)
						_overlay_control.queue_redraw()
				_dragging_unit_idx = -1
				accept_event()

	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if _is_panning:
			pan_offset += mm.relative
			_update_terrain_transform()
			queue_redraw()
			_overlay_control.queue_redraw()
		else:
			_update_hover(mm.position)

	elif event is InputEventKey and event.pressed and not event.echo:
		var k: InputEventKey = event
		var center: Vector2 = size / 2.0
		var pan_step: float = 24.0
		match k.keycode:
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
				_zoom(ZOOM_STEP, center)
				accept_event()
			KEY_MINUS, KEY_KP_SUBTRACT:
				_zoom(-ZOOM_STEP, center)
				accept_event()
			KEY_0, KEY_KP_0:
				zoom_level = 1.0
				pan_offset = Vector2.ZERO
				_update_terrain_transform()
				queue_redraw()
				_overlay_control.queue_redraw()
				accept_event()
			KEY_LEFT:
				pan_offset.x += pan_step
				_update_terrain_transform()
				queue_redraw()
				_overlay_control.queue_redraw()
				accept_event()
			KEY_RIGHT:
				pan_offset.x -= pan_step
				_update_terrain_transform()
				queue_redraw()
				_overlay_control.queue_redraw()
				accept_event()
			KEY_UP:
				pan_offset.y += pan_step
				_update_terrain_transform()
				queue_redraw()
				_overlay_control.queue_redraw()
				accept_event()
			KEY_DOWN:
				pan_offset.y -= pan_step
				_update_terrain_transform()
				queue_redraw()
				_overlay_control.queue_redraw()
				accept_event()

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

## BUG-105: feature labels for the shapes ACTUALLY rendered in sector (sr, sc).
## Mirrors the render skip predicate in _rebuild_terrain_shapes() (scatter is
## hidden unless show_scatter), so the hover tooltip and the click popover
## describe what is drawn instead of the raw _sector_features list (which
## listed hidden scatter and read as per-cell when it is per-sector).
func get_rendered_feature_labels(sr: int, sc: int) -> Array:
	var out: Array = []
	if _sector_shapes.is_empty():
		return out
	if sr < 0 or sr >= _sector_shapes.size():
		return out
	var row: Array = _sector_shapes[sr]
	if sc < 0 or sc >= row.size():
		return out
	for s in row[sc]:
		if not (s is Dictionary):
			continue
		if s.get("is_scatter", false) and not show_scatter:
			continue
		var lbl: String = str(s.get("label", ""))
		if not lbl.is_empty():
			out.append(lbl)
	return out

const LEGEND_ORDER: Array = ["building", "wall", "rock", "hill", "vegetation",
	"water", "container", "crystal", "hazard", "debris", "scatter", "notable"]

## BUG-103: map a drawn shape type to a legend key. Mirrors the renderer's own
## _get_map_color() shape->color match so the legend cannot drift from what is
## actually painted.
func _shape_to_legend_key(shape_type: String) -> String:
	match shape_type:
		"rect": return "building"
		"line": return "wall"
		"circle": return "rock"
		"triangle": return "hill"
		"tree": return "vegetation"
		"water": return "water"
		"box": return "container"
		"diamond": return "crystal"
		"hazard": return "hazard"
		"debris": return "debris"
		"scatter": return "scatter"
	return "debris"

## BUG-103: ordered legend keys for terrain ACTUALLY rendered (scatter excluded
## when hidden, "notable" added when any notable piece is drawn) so the panel
## legend lists only this mission's terrain, not all 12 categories.
func get_rendered_legend_keys() -> Array:
	var present: Dictionary = {}
	for sr in _sector_shapes.size():
		var row: Array = _sector_shapes[sr]
		for sc in row.size():
			for s in row[sc]:
				if not (s is Dictionary):
					continue
				if s.get("is_scatter", false) and not show_scatter:
					continue
				present[_shape_to_legend_key(s.get("shape", "debris"))] = true
				if s.get("notable", false):
					present["notable"] = true
	var out: Array = []
	for k in LEGEND_ORDER:
		if present.has(k):
			out.append(k)
	return out

func _handle_click(mouse_pos: Vector2) -> void:
	var cell: Vector2i = _mouse_to_grid(mouse_pos)
	if cell == Vector2i(-1, -1):
		return

	var sector_label: String = _grid_to_sector_label(cell)
	var sr: int = cell.y / SECTOR_ROWS
	var sc: int = cell.x / SECTOR_COLS
	if sr >= 0 and sr < 4 and sc >= 0 and sc < 4 and not _sector_shapes.is_empty():
		cell_clicked.emit(sector_label, get_rendered_feature_labels(sr, sc))

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
	var features: Array = get_rendered_feature_labels(sr, sc)
	cell_hovered.emit(sector_label, features)

	# BUG-105: frame as the SECTOR (the tooltip is sector-granular, not per
	# cell) and list only the terrain actually drawn here.
	var bbcode: String = "[b]Sector %s[/b]" % sector_label
	if features.is_empty():
		bbcode += "\n[i]No terrain drawn here[/i]"
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
