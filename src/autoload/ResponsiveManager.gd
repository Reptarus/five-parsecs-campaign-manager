extends Node

## Centralized Responsive Breakpoint Manager
## Provides unified breakpoint detection and layout mode signaling

enum Breakpoint { MOBILE, TABLET, DESKTOP, WIDE }

const BREAKPOINTS := {
	Breakpoint.MOBILE: 480,
	Breakpoint.TABLET: 768,
	Breakpoint.DESKTOP: 1024,
	Breakpoint.WIDE: 1440
}

signal breakpoint_changed(new_breakpoint: int)
signal viewport_resized(new_size: Vector2)
signal orientation_changed(is_landscape: bool)

var current_breakpoint: int = Breakpoint.DESKTOP
var current_viewport_size: Vector2 = Vector2.ZERO
var is_landscape: bool = true
var screen_scale_factor: float = 1.0
var _viewport: Viewport = null

func _ready() -> void:
	_viewport = get_tree().root
	_detect_screen_scale()
	_update_breakpoint()
	_update_orientation()
	if _viewport:
		_viewport.size_changed.connect(_on_viewport_size_changed)

func _on_viewport_size_changed() -> void:
	var previous_breakpoint := current_breakpoint
	_update_breakpoint()
	_update_orientation()
	viewport_resized.emit(current_viewport_size)
	if current_breakpoint != previous_breakpoint:
		breakpoint_changed.emit(current_breakpoint)

func _update_breakpoint() -> void:
	if not _viewport:
		return
	current_viewport_size = _viewport.get_visible_rect().size
	var width := int(current_viewport_size.x)
	if width < BREAKPOINTS[Breakpoint.MOBILE]:
		current_breakpoint = Breakpoint.MOBILE
	elif width < BREAKPOINTS[Breakpoint.TABLET]:
		current_breakpoint = Breakpoint.TABLET
	elif width < BREAKPOINTS[Breakpoint.DESKTOP]:
		current_breakpoint = Breakpoint.DESKTOP
	else:
		current_breakpoint = Breakpoint.WIDE

func is_mobile() -> bool:
	return current_breakpoint == Breakpoint.MOBILE

func is_tablet() -> bool:
	return current_breakpoint == Breakpoint.TABLET

func is_desktop() -> bool:
	return current_breakpoint == Breakpoint.DESKTOP

func is_wide() -> bool:
	return current_breakpoint == Breakpoint.WIDE

func is_desktop_or_wider() -> bool:
	return current_breakpoint >= Breakpoint.DESKTOP

func is_mobile_or_tablet() -> bool:
	return current_breakpoint <= Breakpoint.TABLET

func get_optimal_columns() -> int:
	match current_breakpoint:
		Breakpoint.MOBILE: return 1
		Breakpoint.TABLET: return 2
		Breakpoint.DESKTOP: return 3
		Breakpoint.WIDE: return 4
	return 2

func get_crew_grid_columns() -> int:
	match current_breakpoint:
		Breakpoint.MOBILE: return 1
		Breakpoint.TABLET: return 2
		Breakpoint.DESKTOP: return 2
		Breakpoint.WIDE: return 3
	return 2

func get_mission_grid_columns() -> int:
	return get_optimal_columns()

func get_spacing_multiplier() -> float:
	match current_breakpoint:
		Breakpoint.MOBILE: return 0.75
		Breakpoint.TABLET: return 1.0
		Breakpoint.DESKTOP: return 1.0
		Breakpoint.WIDE: return 1.25
	return 1.0

func get_responsive_spacing(base_spacing: int) -> int:
	return int(float(base_spacing) * get_spacing_multiplier())

func get_font_size_multiplier() -> float:
	match current_breakpoint:
		Breakpoint.MOBILE: return 0.9
		Breakpoint.TABLET: return 1.0
		Breakpoint.DESKTOP: return 1.0
		Breakpoint.WIDE: return 1.1
	return 1.0

func get_responsive_font_size(base_size: int) -> int:
	return int(float(base_size) * get_font_size_multiplier())

func get_touch_target_size() -> int:
	if current_breakpoint == Breakpoint.MOBILE:
		return 56
	return 48

func should_use_horizontal_scroll() -> bool:
	return current_breakpoint == Breakpoint.MOBILE

func should_use_grid_layout() -> bool:
	return current_breakpoint >= Breakpoint.TABLET

func get_breakpoint_name() -> String:
	match current_breakpoint:
		Breakpoint.MOBILE: return "MOBILE"
		Breakpoint.TABLET: return "TABLET"
		Breakpoint.DESKTOP: return "DESKTOP"
		Breakpoint.WIDE: return "WIDE"
	return "UNKNOWN"

func is_portrait() -> bool:
	return not is_landscape

func get_screen_scale() -> float:
	return screen_scale_factor

func _update_orientation() -> void:
	var was_landscape := is_landscape
	is_landscape = current_viewport_size.x >= current_viewport_size.y
	if is_landscape != was_landscape:
		orientation_changed.emit(is_landscape)

func _detect_screen_scale() -> void:
	screen_scale_factor = DisplayServer.screen_get_scale()
	if screen_scale_factor <= 0.0:
		screen_scale_factor = 1.0

func debug_print_state() -> void:
	pass
