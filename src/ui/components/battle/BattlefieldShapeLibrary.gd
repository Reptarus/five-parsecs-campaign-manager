class_name BattlefieldShapeLibrary
extends RefCounted

## Shared terrain shape classification and drawing library.
##
## Provides terrain shape classification, _draw() primitives for sector cells,
## and ScalableVectorShape2D node creation for the graph-paper map view.

# ============================================================================
# SHAPE COLOR CONSTANTS (used by sector cell _draw() rendering)
# ============================================================================

const SHAPE_COLOR_BUILDING := Color(0.29, 0.565, 0.851, 0.9)    # Steel blue
const SHAPE_COLOR_WALL := Color(0.545, 0.545, 0.545, 0.9)       # Gray
const SHAPE_COLOR_CONTAINER := Color(0.831, 0.651, 0.455, 0.9)   # Tan/wood
const SHAPE_COLOR_ROCK := Color(0.478, 0.478, 0.478, 0.9)       # Stone gray
const SHAPE_COLOR_DEBRIS := Color(0.608, 0.463, 0.325, 0.9)     # Brown
const SHAPE_COLOR_HILL := Color(0.42, 0.557, 0.137, 0.9)        # Olive
const SHAPE_COLOR_VEGETATION := Color(0.133, 0.545, 0.133, 0.9) # Forest green
const SHAPE_COLOR_WATER := Color(0.118, 0.565, 1.0, 0.7)        # Dodger blue
const SHAPE_COLOR_HAZARD := Color(0.863, 0.153, 0.153, 0.8)     # Red
const SHAPE_COLOR_CRYSTAL := Color(0.678, 0.447, 0.894, 0.9)    # Purple
const SHAPE_COLOR_SCATTER := Color(0.502, 0.502, 0.502, 0.6)    # Dim gray
const SHAPE_COLOR_OPEN := Color(0.25, 0.25, 0.35, 0.3)          # Very dim
const SHAPE_COLOR_GOLD_OUTLINE := Color(0.961, 0.788, 0.043, 0.9) # Gold for notable

# ============================================================================
# MAP VIEW COLORS (graph-paper style, labrador.dev-inspired)
# ============================================================================

const MAP_COLOR_BUILDING := Color(0.55, 0.56, 0.58)     # Gray ruins
const MAP_COLOR_WALL := Color(0.50, 0.50, 0.52)          # Dark gray wall
const MAP_COLOR_ROCK := Color(0.65, 0.65, 0.67)          # Light gray rock
const MAP_COLOR_HILL := Color(0.64, 0.70, 0.54)          # Olive elevation
const MAP_COLOR_VEGETATION := Color(0.23, 0.49, 0.27)    # Dark green forest
const MAP_COLOR_WATER := Color(0.58, 0.77, 0.99)         # Light blue
const MAP_COLOR_CONTAINER := Color(0.18, 0.48, 0.55)     # Teal obstacles
const MAP_COLOR_CRYSTAL := Color(0.49, 0.23, 0.93)       # Purple crystal
const MAP_COLOR_HAZARD := Color(0.86, 0.15, 0.15)        # Red hazard
const MAP_COLOR_DEBRIS := Color(0.47, 0.44, 0.42)        # Brown-gray debris
const MAP_COLOR_SCATTER := Color(0.60, 0.58, 0.56)       # Warm gray scatter
const MAP_COLOR_NOTABLE_STROKE := Color(0.96, 0.78, 0.04) # Gold notable outline

# ============================================================================
# PUBLIC CLASSIFICATION API
# ============================================================================

## Classify a single feature string into a shape dictionary.
## Returns: {shape, color, width, height, notable, label}
func classify_feature(feat: String) -> Dictionary:
	var lower: String = feat.to_lower()
	var is_notable: bool = feat.begins_with("NOTABLE:") or feat.begins_with("LARGE:")
	var is_linear: bool = feat.begins_with("LINEAR:")

	# Strip category prefix for keyword matching
	var text: String = lower
	if text.begins_with("notable: "):
		text = text.substr(9)
	elif text.begins_with("large: "):
		text = text.substr(7)
	elif text.begins_with("small: "):
		text = text.substr(7)
	elif text.begins_with("linear: "):
		text = text.substr(8)
	elif text.begins_with("scatter: "):
		# BUG-040 FIX: Mark scatter as non-terrain (not counted in 13 max)
		return {"shape": "scatter", "color": SHAPE_COLOR_SCATTER,
			"width": 48.0, "height": 16.0, "notable": false,
			"is_scatter": true, "size_category": "",
			"label": feat.substr(9) if feat.begins_with("Scatter: ") else feat}

	# Keyword -> shape mapping (ordered by specificity)
	var shape: String = "rect"
	var color: Color = SHAPE_COLOR_DEBRIS
	var w: float = 36.0
	var h: float = 24.0

	if _text_has_any(text, ["factory", "building", "warehouse", "cabin", "hull",
			"cockpit", "cargo bay", "control tower", "dock", "chamber", "console",
			"room", "section", "interior", "machinery", "nacelle"]):
		shape = "rect"
		color = SHAPE_COLOR_BUILDING
		w = 56.0; h = 38.0
	elif _text_has_any(text, ["barricade", "wall", "pipeline", "conveyor",
			"plate", "fence", "barrier", "railing", "walkway",
			"strut", "gear", "rack", "spool"]):
		shape = "line"
		color = SHAPE_COLOR_WALL
		w = 52.0; h = 8.0
	elif _text_has_any(text, ["crystal", "crystalline", "energy field",
			"monolith", "pillar", "shard"]):
		shape = "diamond"
		color = SHAPE_COLOR_CRYSTAL
		w = 28.0; h = 36.0
	elif _text_has_any(text, ["rock", "boulder", "outcrop", "stone"]):
		shape = "circle"
		color = SHAPE_COLOR_ROCK
		w = 32.0; h = 32.0
	elif _text_has_any(text, ["hill", "hilltop", "crater", "mound",
			"elevation", "ridge", "elevated"]):
		shape = "triangle"
		color = SHAPE_COLOR_HILL
		w = 40.0; h = 36.0
	elif _text_has_any(text, ["tree", "bush", "grass", "vegetation",
			"vine", "growth", "fungal", "spore", "mushroom", "flower"]):
		shape = "tree"
		color = SHAPE_COLOR_VEGETATION
		w = 44.0; h = 44.0
	elif _text_has_any(text, ["creek", "pond", "stream", "water", "pool"]):
		shape = "water"
		color = SHAPE_COLOR_WATER
		w = 42.0; h = 24.0
	elif _text_has_any(text, ["container", "crate", "barrel", "drum",
			"tank", "cargo", "seat"]):
		shape = "box"
		color = SHAPE_COLOR_CONTAINER
		w = 30.0; h = 30.0
	elif _text_has_any(text, ["dangerous", "hazard", "radiation",
			"explode", "electrical", "fuel"]):
		shape = "hazard"
		color = SHAPE_COLOR_HAZARD
		w = 30.0; h = 30.0
	elif _text_has_any(text, ["rubble", "debris", "scrap", "junk",
			"wreckage", "pile", "fragment", "wire", "cable", "panel",
			"insulation", "glass", "chunk", "artifact", "bone", "log",
			"effects"]):
		shape = "debris"
		color = SHAPE_COLOR_DEBRIS
		w = 38.0; h = 22.0

	# LINEAR category features default to line shape if not already matched
	if is_linear and shape == "rect":
		shape = "line"
		color = SHAPE_COLOR_WALL
		w = 52.0; h = 8.0

	if is_notable:
		w *= 1.3
		h *= 1.3

	# Short label for map view (1-2 words)
	var short_label: String = _get_short_label(shape, text)

	# BUG-041 FIX: Store size category for label prefixes
	var size_category: String = ""
	if feat.begins_with("LARGE:") or feat.begins_with("NOTABLE:"):
		size_category = "LARGE"
	elif feat.begins_with("SMALL:"):
		size_category = "SMALL"
	elif feat.begins_with("LINEAR:"):
		size_category = "LINEAR"

	return {"shape": shape, "color": color, "width": w, "height": h,
		"notable": is_notable, "is_scatter": false,
		"size_category": size_category,
		"label": feat, "short_label": short_label}

## Classify all feature strings for a cell into drawable shape dictionaries.
func classify_features(features: Array) -> Array:
	var result: Array = []
	for feat: String in features:
		result.append(classify_feature(feat))
	return result

## Core Rules terrain category (p.37-39): determines LOS, cover, and movement rules.
## Returns one of: "Linear", "Individual", "Area", "Field", "Block", "Interior"
static func classify_terrain_rules_category(feature_name: String) -> String:
	var lower: String = feature_name.to_lower()
	# Strip size/type prefixes
	for prefix: String in ["notable: ", "large: ", "small: ", "linear: ", "scatter: "]:
		if lower.begins_with(prefix):
			lower = lower.substr(prefix.length())
			break

	# Linear: long features figures cannot stand on (walls, fences, barricades)
	if _text_has_any_static(lower, ["wall", "fence", "barricade", "sandbag", "barrier",
			"pipe", "cable", "rail", "ridge"]):
		return "Linear"

	# Interior: enclosed spaces figures can enter (buildings, tunnels, caves)
	if _text_has_any_static(lower, ["building", "room", "interior", "cabin", "tunnel",
			"cave", "chamber", "cockpit", "cargo bay", "section", "nacelle"]):
		return "Interior"

	# Block: climbable but not enterable (boulders, containers, sealed structures)
	if _text_has_any_static(lower, ["container", "boulder", "sealed", "crate", "tower",
			"pillar", "monolith", "statue", "console", "generator", "machinery",
			"warehouse", "factory", "dock", "control tower", "hull"]):
		return "Block"

	# Field: open area effects, no LOS blocking (mud, water, lava, toxic)
	if _text_has_any_static(lower, ["water", "pool", "lake", "river", "mud", "lava",
			"toxic", "swamp", "bog", "sludge", "acid"]):
		return "Field"

	# Area: larger features with LOS blocking and possible difficult terrain
	if _text_has_any_static(lower, ["forest", "grove", "thicket", "bush", "vegetation",
			"rubble", "ruin", "debris", "wreckage", "fungal", "crystal",
			"crater", "hill", "mound", "dune", "rock formation"]):
		return "Area"

	# Individual: single objects providing partial cover
	if _text_has_any_static(lower, ["barrel", "tree", "sign", "post", "rock",
			"terminal", "lamp", "pole"]):
		return "Individual"

	# Default to Block (most defensive assumption)
	return "Block"

## Get Core Rules interaction text for a terrain category (p.37-39)
static func get_terrain_rules_text(category: String) -> String:
	match category:
		"Linear":
			return "Cover when adjacent. Cannot be placed on top of. Can be climbed. LOS exists across but target gets Cover unless shooter within 1\"."
		"Individual":
			return "Partial cover from one side. Does not block LOS if target is partially visible."
		"Area":
			return "Blocks LOS at nearest edge. Figures inside can see out from edges only. May be Difficult terrain (+1\" per 2\" moved)."
		"Field":
			return "Does NOT block LOS. Cannot provide Cover. May be Difficult or Impassable terrain."
		"Block":
			return "Can be climbed. Cannot be entered. Blocks LOS. Provides Cover."
		"Interior":
			return "Can be entered. Figures inside cannot see out (and vice versa) except from edges/windows."
		_:
			return ""

static func _text_has_any_static(text: String, keywords: Array) -> bool:
	for kw: String in keywords:
		if text.contains(kw):
			return true
	return false

# ============================================================================
# PUBLIC DRAWING API
# ============================================================================

## Draw a single classified shape at a given origin on any Control's _draw().
## scale_factor: multiplier for shape dimensions (1.0 = original sector size).
func draw_shape(canvas: Control, shape_info: Dictionary,
		origin: Vector2, scale_factor: float = 1.0) -> void:
	var shape_type: String = shape_info.get("shape", "rect")
	var color: Color = shape_info.get("color", Color.WHITE)
	var w: float = shape_info.get("width", 30.0) * scale_factor
	var h: float = shape_info.get("height", 20.0) * scale_factor
	var is_notable: bool = shape_info.get("notable", false)

	match shape_type:
		"rect":
			_draw_building(canvas, origin, w, h, color)
		"line":
			_draw_wall(canvas, origin, w, h, color)
		"circle":
			_draw_rock(canvas, origin, w, h, color)
		"triangle":
			_draw_hill(canvas, origin, w, h, color)
		"tree":
			_draw_tree(canvas, origin, w, h, color)
		"water":
			_draw_water(canvas, origin, w, h, color)
		"box":
			_draw_container(canvas, origin, w, h, color)
		"diamond":
			_draw_crystal(canvas, origin, w, h, color)
		"hazard":
			_draw_hazard(canvas, origin, w, h, color)
		"debris":
			_draw_debris(canvas, origin, w, h, color)
		"scatter":
			_draw_scatter(canvas, origin, w, h, color)

	# Notable gold outline
	if is_notable:
		canvas.draw_rect(
			Rect2(origin - Vector2(2, 2), Vector2(w + 4, h + 4)),
			SHAPE_COLOR_GOLD_OUTLINE, false, 1.5)

## Draw the open-ground cross-hatch pattern for empty cells.
func draw_empty_cell(canvas: Control, area: Vector2) -> void:
	var center := area / 2.0
	var s: float = minf(area.x, area.y) * 0.25
	canvas.draw_line(center - Vector2(s, s), center + Vector2(s, s),
		SHAPE_COLOR_OPEN, 1.5)
	canvas.draw_line(center - Vector2(-s, s), center + Vector2(-s, s),
		SHAPE_COLOR_OPEN, 1.5)

## Draw all classified shapes in a flow layout within a bounded area.
## Used by BattlefieldGridPanel sector cells for packed shape rendering.
func draw_shapes_packed(canvas: Control, shapes: Array, area: Vector2) -> void:
	if shapes.is_empty():
		draw_empty_cell(canvas, area)
		return

	var x_cursor: float = 6.0
	var y_cursor: float = 4.0
	var max_w: float = area.x - 12.0
	var row_height: float = 0.0

	for shape_info: Dictionary in shapes:
		var w: float = shape_info.get("width", 30.0)
		var h: float = shape_info.get("height", 20.0)

		# Wrap to next row if needed
		if x_cursor + w > max_w and x_cursor > 10.0:
			x_cursor = 6.0
			y_cursor += row_height + 4.0
			row_height = 0.0

		# Skip if out of vertical space
		if y_cursor + h > area.y - 4.0:
			break

		draw_shape(canvas, shape_info, Vector2(x_cursor, y_cursor))

		x_cursor += w + 6.0
		row_height = maxf(row_height, h)

# ============================================================================
# PRIVATE HELPERS
# ============================================================================

func _text_has_any(text: String, keywords: Array) -> bool:
	for kw: String in keywords:
		if kw in text:
			return true
	return false

## Get a 1-2 word label for map view display based on shape type
func _get_short_label(shape_type: String, text: String) -> String:
	match shape_type:
		"rect": return "Ruins" if "ruin" in text else "Building"
		"line": return "Wall"
		"circle": return "Rock"
		"triangle": return "Hill"
		"tree": return "Trees"
		"water": return "Water"
		"box": return "Crate"
		"diamond": return "Crystal"
		"hazard": return "Hazard"
		"debris": return "Debris"
		"scatter": return ""  # Scatter doesn't need a label
	return ""

# ============================================================================
# INDIVIDUAL SHAPE DRAWING METHODS
# ============================================================================

func _draw_building(canvas: Control, origin: Vector2,
		w: float, h: float, color: Color) -> void:
	canvas.draw_rect(Rect2(origin, Vector2(w, h)), color)
	canvas.draw_rect(Rect2(origin, Vector2(w, h)),
		color.lightened(0.3), false, 1.5)
	# Window dots
	var dot_y: float = origin.y + h * 0.35
	var dot_spacing: float = w / 4.0
	for di: int in range(3):
		canvas.draw_circle(
			Vector2(origin.x + dot_spacing * (di + 0.8), dot_y),
			2.0, color.lightened(0.5))

func _draw_wall(canvas: Control, origin: Vector2,
		w: float, h: float, color: Color) -> void:
	var mid_y: float = origin.y + h / 2.0
	canvas.draw_line(
		Vector2(origin.x, mid_y),
		Vector2(origin.x + w, mid_y),
		color, 4.0)
	canvas.draw_circle(Vector2(origin.x, mid_y), 3.0, color)
	canvas.draw_circle(Vector2(origin.x + w, mid_y), 3.0, color)

func _draw_rock(canvas: Control, origin: Vector2,
		w: float, h: float, color: Color) -> void:
	var cx: float = origin.x + w / 2.0
	var cy: float = origin.y + h / 2.0
	var radius: float = minf(w, h) / 2.0
	canvas.draw_circle(Vector2(cx, cy), radius, color)
	canvas.draw_arc(Vector2(cx - 2, cy - 2), radius * 0.7,
		-PI * 0.8, -PI * 0.2, 8, color.lightened(0.3), 1.5)

func _draw_hill(canvas: Control, origin: Vector2,
		w: float, h: float, color: Color) -> void:
	var points := PackedVector2Array([
		Vector2(origin.x + w / 2.0, origin.y),
		Vector2(origin.x + w, origin.y + h),
		Vector2(origin.x, origin.y + h),
	])
	canvas.draw_colored_polygon(points, color)
	canvas.draw_polyline(points, color.lightened(0.3), 1.5)

func _draw_tree(canvas: Control, origin: Vector2,
		w: float, h: float, color: Color) -> void:
	var trunk_x: float = origin.x + w / 2.0
	var trunk_top: float = origin.y + h * 0.4
	var trunk_bot: float = origin.y + h
	canvas.draw_line(
		Vector2(trunk_x, trunk_top),
		Vector2(trunk_x, trunk_bot),
		color.darkened(0.4), 3.0)
	var canopy_r: float = w * 0.45
	canvas.draw_circle(Vector2(trunk_x, trunk_top), canopy_r, color)
	canvas.draw_circle(
		Vector2(trunk_x - 2, trunk_top - 2),
		canopy_r * 0.6, color.lightened(0.2))

func _draw_water(canvas: Control, origin: Vector2,
		w: float, h: float, color: Color) -> void:
	canvas.draw_rect(Rect2(origin, Vector2(w, h)), color)
	var wave_y1: float = origin.y + h * 0.35
	var wave_y2: float = origin.y + h * 0.65
	for wave_y: float in [wave_y1, wave_y2]:
		var wave_pts := PackedVector2Array()
		for wx: int in range(int(w / 4)):
			var px: float = origin.x + wx * 4.0
			var py: float = wave_y + sin(wx * 1.2) * 2.0
			wave_pts.append(Vector2(px, py))
		if wave_pts.size() > 1:
			canvas.draw_polyline(wave_pts, color.lightened(0.3), 1.0)

func _draw_container(canvas: Control, origin: Vector2,
		w: float, h: float, color: Color) -> void:
	canvas.draw_rect(Rect2(origin, Vector2(w, h)), color)
	canvas.draw_line(origin, origin + Vector2(w, h),
		color.darkened(0.3), 1.0)
	canvas.draw_line(
		Vector2(origin.x + w, origin.y),
		Vector2(origin.x, origin.y + h),
		color.darkened(0.3), 1.0)

func _draw_crystal(canvas: Control, origin: Vector2,
		w: float, h: float, color: Color) -> void:
	var cx: float = origin.x + w / 2.0
	var cy: float = origin.y + h / 2.0
	var hw: float = w / 2.0
	var hh: float = h / 2.0
	var dpts := PackedVector2Array([
		Vector2(cx, cy - hh),
		Vector2(cx + hw, cy),
		Vector2(cx, cy + hh),
		Vector2(cx - hw, cy),
	])
	canvas.draw_colored_polygon(dpts, color)
	canvas.draw_polyline(dpts, color.lightened(0.4), 1.5)
	canvas.draw_circle(Vector2(cx, cy), hw * 0.3, color.lightened(0.5))

func _draw_hazard(canvas: Control, origin: Vector2,
		w: float, h: float, color: Color) -> void:
	var cx: float = origin.x + w / 2.0
	var cy: float = origin.y + h / 2.0
	var hw: float = w / 2.0
	var hh: float = h / 2.0
	var hpts := PackedVector2Array([
		Vector2(cx, cy - hh),
		Vector2(cx + hw, cy),
		Vector2(cx, cy + hh),
		Vector2(cx - hw, cy),
	])
	canvas.draw_colored_polygon(hpts, color.darkened(0.2))
	canvas.draw_polyline(hpts, color, 2.0)
	canvas.draw_line(
		Vector2(cx, cy - hh * 0.5),
		Vector2(cx, cy + hh * 0.1),
		Color.WHITE, 2.0)
	canvas.draw_circle(Vector2(cx, cy + hh * 0.35), 2.0, Color.WHITE)

func _draw_debris(canvas: Control, origin: Vector2,
		w: float, h: float, color: Color) -> void:
	var rects: int = 4
	for ri: int in range(rects):
		var rx: float = origin.x + (w / rects) * ri + 2.0
		var ry: float = origin.y + (h * 0.2 if ri % 2 == 0 else h * 0.5)
		var rw: float = w / rects * 0.7
		var rh: float = h * 0.35
		canvas.draw_rect(Rect2(rx, ry, rw, rh), color.darkened(0.1 * ri))

func _draw_scatter(canvas: Control, origin: Vector2,
		w: float, h: float, color: Color) -> void:
	var items: int = mini(6, int(w / 8))
	for si: int in range(items):
		var sx: float = origin.x + si * 8.0
		var sy: float = origin.y + h * 0.3
		if si % 2 == 0:
			canvas.draw_rect(Rect2(sx, sy, 5, 5), color)
		else:
			canvas.draw_circle(Vector2(sx + 2.5, sy + 2.5), 3.0, color)

# ============================================================================
# VECTOR SHAPE FACTORY (for graph-paper map view)
# ============================================================================

## Create a ScalableVectorShape2D node for a classified terrain feature.
## Returns a configured node ready to be added to the scene tree.
## scale: multiplier applied to the shape's base dimensions.
func create_vector_shape(shape_info: Dictionary, scale: float = 1.0) -> ScalableVectorShape2D:
	var svs := ScalableVectorShape2D.new()
	svs.update_curve_at_runtime = true

	var shape_type: String = shape_info.get("shape", "rect")
	var w: float = shape_info.get("width", 30.0) * scale
	var h: float = shape_info.get("height", 20.0) * scale
	var is_notable: bool = shape_info.get("notable", false)
	var fill_color: Color = _get_map_color(shape_type)
	var stroke_col: Color = fill_color.darkened(0.3)

	if is_notable:
		stroke_col = MAP_COLOR_NOTABLE_STROKE

	# Choose SVS shape type
	match shape_type:
		"tree", "circle", "triangle":
			svs.shape_type = ScalableVectorShape2D.ShapeType.ELLIPSE
		_:
			svs.shape_type = ScalableVectorShape2D.ShapeType.RECT
			svs.rx = 4.0
			svs.ry = 4.0

	svs.size = Vector2(w, h)

	# Fill (Polygon2D child)
	var fill := Polygon2D.new()
	fill.color = fill_color
	svs.add_child(fill)
	svs.polygon = fill

	# Stroke (Line2D child)
	var stroke := Line2D.new()
	svs.add_child(stroke)
	svs.line = stroke
	svs.stroke_color = stroke_col
	svs.stroke_width = 3.0 if is_notable else 2.0

	# Store metadata for labels/tooltips
	svs.set_meta("shape_info", shape_info)

	return svs

## Get maximum rotation angle (radians) for a shape type.
## Buildings get subtle rotation; natural features get full rotation.
static func get_rotation_range(shape_type: String) -> float:
	match shape_type:
		"rect": return deg_to_rad(15.0)       # Buildings: subtle
		"line": return deg_to_rad(45.0)        # Walls: varied angles
		"circle": return deg_to_rad(360.0)     # Rocks: any rotation
		"triangle": return deg_to_rad(360.0)   # Hills: any rotation
		"tree": return deg_to_rad(360.0)       # Trees: any rotation
		"water": return deg_to_rad(10.0)       # Water: very subtle
		"box": return deg_to_rad(45.0)         # Containers: moderate
		"diamond": return deg_to_rad(30.0)     # Crystals: moderate
		"hazard": return deg_to_rad(20.0)      # Hazards: subtle
		"debris": return deg_to_rad(360.0)     # Debris: any rotation
		"scatter": return deg_to_rad(360.0)    # Scatter: any
	return deg_to_rad(15.0)

## Get the map-view fill color for a shape type (graph-paper palette).
func _get_map_color(shape_type: String) -> Color:
	match shape_type:
		"rect": return MAP_COLOR_BUILDING
		"line": return MAP_COLOR_WALL
		"circle": return MAP_COLOR_ROCK
		"triangle": return MAP_COLOR_HILL
		"tree": return MAP_COLOR_VEGETATION
		"water": return MAP_COLOR_WATER
		"box": return MAP_COLOR_CONTAINER
		"diamond": return MAP_COLOR_CRYSTAL
		"hazard": return MAP_COLOR_HAZARD
		"debris": return MAP_COLOR_DEBRIS
		"scatter": return MAP_COLOR_SCATTER
	return MAP_COLOR_DEBRIS
