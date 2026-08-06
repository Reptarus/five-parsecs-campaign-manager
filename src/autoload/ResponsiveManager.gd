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

## The project theme, and the font sizes it shipped with.
##
## get_font_size_multiplier() has always existed and has always been right, but
## almost nothing asked it: the codebase sets type size at roughly 1,200 call sites
## with add_theme_font_size_override(), and an override outranks the theme, so text
## was the same number of pixels on a 310dp phone as on a 1920px desktop. On the
## narrow end that is what pushes layouts off the edge — a Label's minimum width IS
## its text width, so type that never shrinks makes a page that cannot.
##
## Scaling the theme fixes every control that does NOT override, which is the whole
## default-themed half of the app. Screens that do override are being moved onto the
## shared chrome batch by batch, and that reads the multiplier directly.
var _theme: Theme = null
var _base_font_sizes: Dictionary = {}


func _ready() -> void:
	_viewport = get_tree().root
	_detect_screen_scale()
	_update_breakpoint()
	_update_orientation()
	_capture_theme_font_sizes()
	_apply_theme_font_scale()
	if _viewport:
		_viewport.size_changed.connect(_on_viewport_size_changed)


## Remember the authored sizes ONCE, so repeated rescales compound off the original
## rather than off the last scaled value (0.85 applied twice is 0.72, and a few
## rotations would shrink the app to nothing).
func _capture_theme_font_sizes() -> void:
	_theme = load("res://src/ui/themes/sci_fi_theme.tres") as Theme
	if _theme == null:
		return
	for type_name in _theme.get_font_size_type_list():
		for size_name in _theme.get_font_size_list(type_name):
			_base_font_sizes[[type_name, size_name]] = _theme.get_font_size(size_name, type_name)
	if _theme.has_default_font_size():
		_base_font_sizes[["", "__default"]] = _theme.default_font_size


func _apply_theme_font_scale() -> void:
	if _theme == null or _base_font_sizes.is_empty():
		return
	var mult := get_font_size_multiplier()
	for key: Array in _base_font_sizes:
		var base: int = _base_font_sizes[key]
		var scaled: int = maxi(9, int(round(float(base) * mult)))
		if key[0] == "" and key[1] == "__default":
			_theme.default_font_size = scaled
		else:
			_theme.set_font_size(key[1], key[0], scaled)

func _on_viewport_size_changed() -> void:
	var previous_breakpoint := current_breakpoint
	var previous_landscape := is_landscape
	_update_breakpoint()
	_update_orientation()
	viewport_resized.emit(current_viewport_size)
	if current_breakpoint != previous_breakpoint:
		# Rescale type BEFORE announcing the change, so every listener that relays
		# out is already measuring against the new text metrics.
		_apply_theme_font_scale()
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
	# Classify by DENSITY-INDEPENDENT window size, NOT the stretched content rect.
	# With canvas_items+expand, _viewport.get_visible_rect() is the logical design
	# space (always ~1080 wide in portrait), so it cannot tell a phone from a
	# tablet. window_get_size() is the physical window; dividing by the OS display
	# scale (screen_get_scale) yields dp-like units: a 1080px phone @ 2.75x density
	# -> ~393 (MOBILE), a 1536px tablet @ 2x -> 768 (DESKTOP), a 1280px desktop
	# window @ 1x -> 1280 (WIDE). screen_get_scale reports a real value on
	# Android/iOS/macOS/Wayland/Web and falls back to 1.0 elsewhere (desktop px).
	screen_scale_factor = _resolve_screen_scale()
	current_viewport_size = Vector2(DisplayServer.window_get_size()) / screen_scale_factor
	current_breakpoint = _classify_breakpoint(int(current_viewport_size.x))

## Pure classification of a density-independent width into a Breakpoint. Factored
## out of _update_breakpoint so the threshold ladder is unit-testable without a
## real window. The BREAKPOINTS thresholds are interpreted as dp (logical px).
func _classify_breakpoint(dip_width: int) -> int:
	if dip_width < BREAKPOINTS[Breakpoint.MOBILE]:
		return Breakpoint.MOBILE
	elif dip_width < BREAKPOINTS[Breakpoint.TABLET]:
		return Breakpoint.TABLET
	elif dip_width < BREAKPOINTS[Breakpoint.DESKTOP]:
		return Breakpoint.DESKTOP
	elif dip_width < BREAKPOINTS[Breakpoint.ULTRAWIDE]:
		return Breakpoint.WIDE
	return Breakpoint.ULTRAWIDE

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
## Portrait is ALWAYS single-column (1) regardless of width bucket -- a phone-first
## rule: even a wide portrait tablet (1536-wide -> WIDE by width alone) shows one
## focused column / tab strip, never a cramped multi-column grid. Only LANDSCAPE
## uses the multi-column width ladder, so desktop callers are unaffected.
## (360dp is the most common phone width; at our effective ~1.12 scale that is
## ~321 design px -- far too tight for 2 columns. See plan: device baseline.)
func get_effective_columns() -> int:
	if is_portrait():
		return 1
	return get_optimal_columns()

## Orientation-aware crew-grid columns. Mirrors get_effective_columns() but
## falls back to the crew-specific landscape value. Portrait is ALWAYS 1
## (phone-first single-column); only landscape uses the crew width ladder.
func get_effective_crew_columns() -> int:
	if is_portrait():
		return 1
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

## The type ladder, one distinct step per breakpoint.
##
## TABLET used to return 1.0, the same as DESKTOP, so nothing about the type
## changed anywhere between 480dp and 1024dp -- which is most of a desktop
## window's travel and the whole tablet range. A ladder with a repeated rung is
## indistinguishable from no ladder at the sizes people actually resize through.
##
## The tokens in UIColors are authored at the DESKTOP rung (1.0), so this only
## ever trims for smaller screens and grows for genuinely large ones.
func get_font_size_multiplier() -> float:
	match current_breakpoint:
		Breakpoint.MOBILE: return 0.85
		Breakpoint.TABLET: return 0.92
		Breakpoint.DESKTOP: return 1.0
		Breakpoint.WIDE: return 1.15
		Breakpoint.ULTRAWIDE: return 1.3
	return 1.0

## Never round a readable size down into an unreadable one: 9px is the floor the
## theme rescale uses too, so the two paths agree on the smallest legible step.
func get_responsive_font_size(base_size: int) -> int:
	return maxi(9, int(round(float(base_size) * get_font_size_multiplier())))

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
	screen_scale_factor = _resolve_screen_scale()

## OS display scale for the main window's screen (e.g. 2.0 on a retina/hiDPI
## display, ~2.75 on an xxhdpi phone). Reported on Android/iOS/macOS/Wayland/Web;
## falls back to 1.0 on platforms that don't report it (Windows desktop), where
## physical px already equal logical px for breakpoint purposes.
func _resolve_screen_scale() -> float:
	var s := DisplayServer.screen_get_scale()
	return s if s > 0.0 else 1.0

func debug_print_state() -> void:
	pass
