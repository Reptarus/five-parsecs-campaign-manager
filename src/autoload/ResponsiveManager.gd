extends Node

## Centralized Responsive Breakpoint Manager
## Provides unified breakpoint detection and layout mode signaling

enum Breakpoint { MOBILE, TABLET, DESKTOP, WIDE, ULTRAWIDE }

const BREAKPOINTS := {
	Breakpoint.MOBILE: 480,
	Breakpoint.TABLET: 768,
	Breakpoint.DESKTOP: 1024,
	Breakpoint.WIDE: 1440,
	Breakpoint.ULTRAWIDE: 2560
}

## Design-base width the proportional UI sizing was tuned against (desktop
## landscape). This is the SCALE reference for get_proportional_size() — it is
## deliberately distinct from project.godot's stretch base (which goes square for
## dual-orientation). Keep at 1920 so desktop proportional sizing is unchanged.
const DESIGN_BASE_WIDTH := 1920.0

signal breakpoint_changed(new_breakpoint: int)
signal viewport_resized(new_size: Vector2)
signal orientation_changed(is_landscape: bool)
## Fires when the effective layout class changes — on a width-bucket change OR a
## portrait<->landscape rotation (which breakpoint_changed misses at constant
## width). Adaptive screens should listen to THIS for re-layout, not only
## breakpoint_changed.
signal layout_class_changed(effective_columns: int)

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
	var previous_landscape := is_landscape
	_update_breakpoint()
	_update_orientation()
	viewport_resized.emit(current_viewport_size)
	if current_breakpoint != previous_breakpoint:
		breakpoint_changed.emit(current_breakpoint)
	# The effective layout class shifts on a bucket change OR a rotation. Rotation
	# at constant width emits no breakpoint_changed, so portrait-aware screens
	# would never re-lay-out without this second signal. The decision is factored
	# into _evaluate_layout_change() so the emit guard is unit-testable.
	var eff := _evaluate_layout_change(previous_breakpoint, previous_landscape)
	if eff >= 0:
		layout_class_changed.emit(eff)

## Decision seam (deterministic, testable): given the PREVIOUS width bucket and
## orientation, returns the NEW effective column count if the layout class
## changed (bucket OR orientation), else -1. Reads the already-updated
## current_breakpoint/is_landscape, so call it AFTER _update_breakpoint() +
## _update_orientation(). Factored out so the emit guard can be tested without
## driving a real viewport.
func _evaluate_layout_change(prev_breakpoint: int, prev_landscape: bool) -> int:
	if current_breakpoint != prev_breakpoint or is_landscape != prev_landscape:
		return get_effective_columns()
	return -1

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
	elif width < BREAKPOINTS[Breakpoint.ULTRAWIDE]:
		current_breakpoint = Breakpoint.WIDE
	else:
		current_breakpoint = Breakpoint.ULTRAWIDE

func is_mobile() -> bool:
	return current_breakpoint == Breakpoint.MOBILE

func is_tablet() -> bool:
	return current_breakpoint == Breakpoint.TABLET

func is_desktop() -> bool:
	return current_breakpoint == Breakpoint.DESKTOP

func is_wide() -> bool:
	return current_breakpoint == Breakpoint.WIDE

func is_ultrawide() -> bool:
	return current_breakpoint == Breakpoint.ULTRAWIDE

func is_desktop_or_wider() -> bool:
	return current_breakpoint >= Breakpoint.DESKTOP

func is_wide_or_wider() -> bool:
	return current_breakpoint >= Breakpoint.WIDE

func is_mobile_or_tablet() -> bool:
	return current_breakpoint <= Breakpoint.TABLET

func get_optimal_columns() -> int:
	match current_breakpoint:
		Breakpoint.MOBILE: return 1
		Breakpoint.TABLET: return 2
		Breakpoint.DESKTOP: return 3
		Breakpoint.WIDE: return 4
		Breakpoint.ULTRAWIDE: return 4
	return 2

func get_crew_grid_columns() -> int:
	match current_breakpoint:
		Breakpoint.MOBILE: return 1
		Breakpoint.TABLET: return 2
		Breakpoint.DESKTOP: return 2
		Breakpoint.WIDE: return 3
		Breakpoint.ULTRAWIDE: return 4
	return 2

func get_mission_grid_columns() -> int:
	return get_optimal_columns()

## Max comfortable side-by-side panes for the current viewport AND orientation.
## Portrait downgrades the count so a tall tablet stops rendering a wide desktop
## grid (a 1536-wide portrait tablet is WIDE by width alone -> would claim 4).
## Landscape returns the legacy width-only value UNCHANGED, so desktop callers
## are unaffected.
func get_effective_columns() -> int:
	if is_portrait():
		return 1 if current_breakpoint <= Breakpoint.TABLET else 2
	return get_optimal_columns()

## Orientation-aware crew-grid columns. Mirrors get_effective_columns() but
## falls back to the crew-specific landscape value. NOTE: the portrait branch is
## intentionally identical-by-VALUE to get_effective_columns() (not delegated),
## so the generic and crew portrait caps can diverge later without coupling.
func get_effective_crew_columns() -> int:
	if is_portrait():
		return 1 if current_breakpoint <= Breakpoint.TABLET else 2
	return get_crew_grid_columns()

## True when the viewport+orientation can only comfortably show a single pane.
func should_collapse_to_single_column() -> bool:
	return get_effective_columns() <= 1

## Idempotent baseline push. layout_class_changed is NOT emitted at autoload boot
## (no consumer is connected yet), so a screen connecting after boot has no
## baseline and, on a fixed-orientation device that never resizes, would sit on
## its default until the first rotation. The primary contract is that consumers
## pull get_effective_columns()/should_collapse_to_single_column() synchronously
## in their own setup; a consumer that prefers a signal-only path may call this
## right after connecting to force one emit.
func emit_current_layout_class() -> void:
	layout_class_changed.emit(get_effective_columns())

func get_spacing_multiplier() -> float:
	match current_breakpoint:
		Breakpoint.MOBILE: return 0.75
		Breakpoint.TABLET: return 1.0
		Breakpoint.DESKTOP: return 1.0
		Breakpoint.WIDE: return 1.15
		Breakpoint.ULTRAWIDE: return 1.3
	return 1.0

func get_responsive_spacing(base_spacing: int) -> int:
	return int(float(base_spacing) * get_spacing_multiplier())

func get_font_size_multiplier() -> float:
	match current_breakpoint:
		Breakpoint.MOBILE: return 0.85
		Breakpoint.TABLET: return 1.0
		Breakpoint.DESKTOP: return 1.0
		Breakpoint.WIDE: return 1.15
		Breakpoint.ULTRAWIDE: return 1.3
	return 1.0

func get_responsive_font_size(base_size: int) -> int:
	return int(float(base_size) * get_font_size_multiplier())

func get_touch_target_size() -> int:
	if current_breakpoint == Breakpoint.MOBILE:
		return 56
	return 48

func get_proportional_size(base: float, min_val: float, max_val: float) -> float:
	## Scale a size proportionally to viewport width (design base: DESIGN_BASE_WIDTH)
	var scale := current_viewport_size.x / DESIGN_BASE_WIDTH if current_viewport_size.x > 0 else 1.0
	return clampf(base * scale, min_val, max_val)

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
		Breakpoint.ULTRAWIDE: return "ULTRAWIDE"
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
