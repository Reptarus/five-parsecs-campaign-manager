extends Control

## Pan/zoom Control that hosts HexCell children and draws the chronological
## breadcrumb line connecting visited worlds in travel_history order.
##
## Pan/zoom adapted from BattlefieldMapView (the only pan/zoom in the codebase
## and the canonical anchor-preserving zoom math). Wheel zooms, middle-drag
## pans, double-click resets to origin.
##
## Setter-driven queue_redraw() per the Godot 4 custom-drawing pattern
## (tutorials/2d/custom_drawing_in_2d.md). Property changes that affect the
## drawn polyline (e.g. _show_breadcrumb) invalidate via their setters.

signal hex_selected(planet_id: String)

const UIColorsClass := preload("res://src/ui/components/base/UIColors.gd")
const GalaxyHexLayoutClass := preload("res://src/core/world/GalaxyHexLayout.gd")
const HexCellScript := preload("res://src/ui/components/galaxy_log/HexCell.gd")

const ZOOM_MIN: float = 0.5
const ZOOM_MAX: float = 2.5
const ZOOM_STEP: float = 0.15

# Visual styling.
const COLOR_GRID_BG := Color(0.04, 0.04, 0.10, 1.0)
const COLOR_BREADCRUMB_NEWEST := Color(0.55, 0.85, 1.0, 0.95)
const COLOR_BREADCRUMB_OLDEST_ALPHA: float = 0.25
const BREADCRUMB_WIDTH: float = 2.5

# Map of planet_id → axial coord Vector2i. Populated via set_layout().
var _coords: Dictionary = {}
# Map of planet_id → HexCell child Control. Populated via _add_hex_cell().
var _cells: Dictionary = {}
# Pulled from PlanetDataManager.travel_history at set_travel_history(). Each
# entry is a Dict with a "planet_id" key per PlanetDataManager._update_planet_visit.
var _travel_history: Array = []

# Pan + zoom state. Applied to _hex_container (Node2D) so HexCells move together.
var _hex_container: Node2D
var _pan_offset: Vector2 = Vector2.ZERO:
	set(value):
		_pan_offset = value
		_apply_transform()
		queue_redraw()
var _zoom_level: float = 1.0:
	set(value):
		_zoom_level = clampf(value, ZOOM_MIN, ZOOM_MAX)
		_apply_transform()
		queue_redraw()

var _show_breadcrumb: bool = true:
	set(value):
		_show_breadcrumb = value
		queue_redraw()

var _is_panning: bool = false


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_ALL  # So keyboard pan/reset works.

	_hex_container = Node2D.new()
	_hex_container.name = "HexContainer"
	add_child(_hex_container)
	_apply_transform()
	# Layout sizes the Control AFTER _ready runs. Without this hookup,
	# _hex_container stays at (0,0) because size was 0 when _apply_transform
	# first ran, leaving HexCells clustered at the top-left while the
	# breadcrumb _draw (which uses size/2 directly at draw time) is centered.
	resized.connect(_apply_transform)


# ----------------------------------------------------------------------------
# Public API
# ----------------------------------------------------------------------------

## Replace the entire hex map. Caller passes:
##   - planets: Array of Object (PlanetData or compatible) — one per hex
##   - coords:  Dictionary planet_id → Vector2i axial coord (from GalaxyHexLayout)
##   - current_id: String — planet to highlight as "current"
##   - starting_id: String — planet to highlight as "starting" (origin anchor)
func set_layout(
	planets: Array,
	coords: Dictionary,
	current_id: String,
	starting_id: String,
) -> void:
	_coords = coords.duplicate(true)
	# Clear existing children before rebuilding.
	for child in _hex_container.get_children():
		child.queue_free()
	_cells.clear()
	for planet in planets:
		if not planet:
			continue
		var pid: String = str(planet.id) if "id" in planet else ""
		if pid.is_empty() or not _coords.has(pid):
			continue
		_add_hex_cell(planet, _coords[pid], pid == current_id, pid == starting_id)
	queue_redraw()


## Set the travel-history sequence used to draw the breadcrumb line. Each entry
## must be a Dict with a "planet_id" key. Pass an empty Array to suppress the
## line entirely (independent of the _show_breadcrumb toggle).
func set_travel_history(history: Array) -> void:
	_travel_history = history.duplicate(true)
	queue_redraw()


func set_breadcrumb_visible(visible: bool) -> void:
	_show_breadcrumb = visible  # Triggers queue_redraw via setter.


# ----------------------------------------------------------------------------
# Internals
# ----------------------------------------------------------------------------

func _add_hex_cell(planet: Object, coord: Vector2i, is_current: bool, is_starting: bool) -> void:
	var cell: Control = HexCellScript.new()
	_hex_container.add_child(cell)
	cell.setup(planet, is_current, is_starting)
	# axial_to_pixel returns the centre; offset by half the cell's expected size
	# to align centres. We must use the constant — `cell.size` is (0,0) here
	# because HexCell._ready() hasn't run yet (it sets custom_minimum_size at
	# _ready time), which previously caused every hex to render half-radius up
	# and left of its true position.
	var half_extent: float = HexCellScript.HEX_RADIUS + 4.0
	var centre_pixel: Vector2 = GalaxyHexLayoutClass.axial_to_pixel(coord)
	cell.position = centre_pixel - Vector2(half_extent, half_extent)
	cell.pressed.connect(_on_hex_pressed)
	_cells[str(planet.id) if "id" in planet else ""] = cell


func _on_hex_pressed(planet_id: String) -> void:
	hex_selected.emit(planet_id)


func _apply_transform() -> void:
	if not _hex_container:
		return
	# Anchor the inner container so axial (0,0) maps to roughly the centre of
	# the control, plus the current pan offset, scaled by zoom.
	_hex_container.scale = Vector2.ONE * _zoom_level
	_hex_container.position = size / 2.0 + _pan_offset


func _draw() -> void:
	# Background fill so the Control reads as a deep-space window even before
	# children render.
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_GRID_BG, true)
	if _show_breadcrumb:
		_draw_breadcrumb_line()


## Draw a polyline tracing the player's travel sequence. Older segments fade.
## Iterates the cached travel_history pairwise; skips any pair where either
## endpoint isn't in the current layout (defensive — handles partial loads).
func _draw_breadcrumb_line() -> void:
	if _travel_history.size() < 2:
		return
	var n: int = _travel_history.size()
	for i in range(n - 1):
		var prev: Variant = _travel_history[i]
		var curr: Variant = _travel_history[i + 1]
		if not (prev is Dictionary and curr is Dictionary):
			continue
		var prev_id: String = str(prev.get("planet_id", ""))
		var curr_id: String = str(curr.get("planet_id", ""))
		if not (_coords.has(prev_id) and _coords.has(curr_id)):
			continue
		var p1: Vector2 = _world_to_local(_coords[prev_id])
		var p2: Vector2 = _world_to_local(_coords[curr_id])
		# Alpha ramps from oldest (low) to newest (high) for that "drawing on
		# the back of a notebook" feel.
		var t: float = float(i) / float(maxi(1, n - 2))
		var color := COLOR_BREADCRUMB_NEWEST
		color.a = lerpf(COLOR_BREADCRUMB_OLDEST_ALPHA, COLOR_BREADCRUMB_NEWEST.a, t)
		draw_line(p1, p2, color, BREADCRUMB_WIDTH, true)


func _world_to_local(axial: Vector2i) -> Vector2:
	# Mirror the inner container's transform so the breadcrumb (drawn directly
	# on the Control, not on _hex_container) aligns with the HexCells.
	var px: Vector2 = GalaxyHexLayoutClass.axial_to_pixel(axial)
	return px * _zoom_level + size / 2.0 + _pan_offset


# ----------------------------------------------------------------------------
# Pan / zoom input (Control-scoped via _gui_input per Godot docs)
# ----------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					_zoom_at(mb.position, ZOOM_STEP)
					accept_event()
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					_zoom_at(mb.position, -ZOOM_STEP)
					accept_event()
			MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT:
				_is_panning = mb.pressed
				if mb.pressed:
					accept_event()
			MOUSE_BUTTON_LEFT:
				if mb.double_click and mb.pressed:
					recenter()
					accept_event()
	elif event is InputEventMouseMotion and _is_panning:
		var mm := event as InputEventMouseMotion
		_pan_offset += mm.relative
		accept_event()
	elif event is InputEventKey and event.pressed:
		var ke := event as InputEventKey
		var step: float = 32.0
		match ke.keycode:
			KEY_HOME:
				recenter()
				accept_event()
			KEY_LEFT:
				_pan_offset.x += step
				accept_event()
			KEY_RIGHT:
				_pan_offset.x -= step
				accept_event()
			KEY_UP:
				_pan_offset.y += step
				accept_event()
			KEY_DOWN:
				_pan_offset.y -= step
				accept_event()


## Reset pan + zoom to frame the whole map at 1:1. Shared by the double-click
## gesture, the HOME key, and the screen's "Recenter" button. Both assignments
## route through setters that call _apply_transform() + queue_redraw().
func recenter() -> void:
	_zoom_level = 1.0
	_pan_offset = Vector2.ZERO


## Anchor-preserving zoom around the mouse cursor. Adapted from
## BattlefieldMapView.gd's _zoom() — the canonical implementation that survived
## BUG-101 and BUG-102 in the battlefield map view.
func _zoom_at(anchor: Vector2, delta: float) -> void:
	var old_zoom: float = _zoom_level
	var new_zoom: float = clampf(_zoom_level + delta, ZOOM_MIN, ZOOM_MAX)
	if new_zoom == old_zoom:
		return
	var zoom_ratio: float = new_zoom / old_zoom
	# Setting _pan_offset triggers queue_redraw via the setter.
	_pan_offset = anchor - (anchor - _pan_offset) * zoom_ratio
	_zoom_level = new_zoom
