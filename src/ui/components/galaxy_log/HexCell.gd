extends Control

## One visited planet rendered as a flat-top hexagon on the Galaxy Log map.
##
## Lifecycle:
##   1. HexStarMap instantiates one per visited planet.
##   2. HexStarMap calls setup(planet, is_current, is_starting) and positions
##      the cell at axial_to_pixel() coords.
##   3. Player clicks the hex → cell emits `pressed(planet_id)`.
##
## Rendering:
##   - _draw() paints the 6-corner polygon using GalaxyHexLayout.hex_corners().
##   - A Label child shows the planet name; danger level drives a corner pip.
##   - Hover, current, starting all change fill color via the setter-driven
##     queue_redraw() pattern documented in the Godot 4 custom-drawing docs.

signal pressed(planet_id: String)

const UIColorsClass := preload("res://src/ui/components/base/UIColors.gd")
const GalaxyHexLayoutClass := preload("res://src/core/world/GalaxyHexLayout.gd")

const HEX_RADIUS: float = GalaxyHexLayoutClass.HEX_SIZE

# Per-state fill colors. Picked from the Deep Space theme palette so the
# Galaxy Log reads as part of the same UI family as the campaign dashboard.
const COLOR_FILL_DEFAULT := Color(0.16, 0.16, 0.27, 0.88)   # Dark indigo
const COLOR_FILL_HOVER := Color(0.22, 0.28, 0.45, 0.92)
const COLOR_FILL_CURRENT := Color(0.18, 0.38, 0.58, 0.96)   # Cyan-tinted
const COLOR_FILL_STARTING := Color(0.28, 0.18, 0.45, 0.94)  # Purple-tinted
const COLOR_STROKE := Color(0.55, 0.65, 0.85, 0.9)
const COLOR_STROKE_HIGH_DANGER := Color(0.85, 0.35, 0.35, 0.95)

var planet_id: String = ""
var planet_name: String = ""
var danger_level: int = 1
var visit_count: int = 1

# Setter-driven queue_redraw — per Godot docs (tutorials/2d/custom_drawing_in_2d).
var is_current: bool = false:
	set(value):
		is_current = value
		queue_redraw()

var is_starting: bool = false:
	set(value):
		is_starting = value
		queue_redraw()

var _hovered: bool = false:
	set(value):
		_hovered = value
		queue_redraw()

var _name_label: Label


func _ready() -> void:
	# Control sized to enclose the hex (slightly oversized for click forgiveness).
	var diam: float = HEX_RADIUS * 2.0 + 8.0
	custom_minimum_size = Vector2(diam, diam)
	size = custom_minimum_size
	pivot_offset = size / 2.0  # Needed by any future TweenFX scale/rotate calls.

	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	_name_label = Label.new()
	_name_label.text = planet_name
	_name_label.add_theme_font_size_override("font_size", UIColorsClass.FONT_SIZE_XS)
	_name_label.add_theme_color_override("font_color", UIColorsClass.COLOR_TEXT_PRIMARY)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't steal clicks.
	add_child(_name_label)
	_name_label.text = planet_name  # Refresh after add_child.


## Initialize this cell from a PlanetData instance (or any object exposing the
## relevant fields). Keeps the cell decoupled from PlanetDataManager.
func setup(planet: Object, current: bool, starting: bool) -> void:
	if not planet:
		return
	planet_id = str(planet.id) if "id" in planet else ""
	planet_name = str(planet.name) if "name" in planet else "?"
	danger_level = int(planet.danger_level) if "danger_level" in planet else 1
	visit_count = int(planet.visit_count) if "visit_count" in planet else 1
	is_current = current
	is_starting = starting
	if _name_label:
		_name_label.text = planet_name
	queue_redraw()


func _draw() -> void:
	var centre: Vector2 = size / 2.0
	var corners: PackedVector2Array = GalaxyHexLayoutClass.hex_corners(
		centre, HEX_RADIUS
	)
	# Pick fill based on state. Order of precedence: current > starting > hover > default.
	var fill: Color = COLOR_FILL_DEFAULT
	if is_current:
		fill = COLOR_FILL_CURRENT
	elif is_starting:
		fill = COLOR_FILL_STARTING
	elif _hovered:
		fill = COLOR_FILL_HOVER
	# Stroke red-tinted at high danger; this is the only data-driven recolor.
	var stroke: Color = COLOR_STROKE
	if danger_level >= 4:
		stroke = COLOR_STROKE_HIGH_DANGER
	draw_colored_polygon(corners, fill)
	# Outline by drawing the polygon edges as a closed polyline.
	var outline_points: PackedVector2Array = corners.duplicate()
	outline_points.append(corners[0])  # Close the loop.
	draw_polyline(outline_points, stroke, 2.0, true)

	# Visit-count badge: small filled circle for visit_count > 1.
	if visit_count > 1:
		var badge_centre: Vector2 = centre + Vector2(HEX_RADIUS * 0.55, -HEX_RADIUS * 0.55)
		draw_circle(badge_centre, 8.0, Color(0.95, 0.75, 0.25, 0.95))

	# Danger pip: filled triangle in bottom-right corner, scaled with danger.
	if danger_level >= 1:
		var pip_centre: Vector2 = centre + Vector2(HEX_RADIUS * 0.45, HEX_RADIUS * 0.45)
		var pip_r: float = 3.0 + float(danger_level)
		var pip_color: Color = Color(0.95, 0.45, 0.35, 0.95) if danger_level >= 4 else Color(0.75, 0.75, 0.85, 0.85)
		draw_circle(pip_centre, pip_r, pip_color)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			pressed.emit(planet_id)
			accept_event()


func _on_mouse_entered() -> void:
	_hovered = true


func _on_mouse_exited() -> void:
	_hovered = false
