class_name PortraitChrome
extends Node

## Self-wiring portrait de-clip helper for screens that do NOT extend
## CampaignScreenBase (so can't use its `_apply_portrait_chrome`). Trims a root
## MarginContainer's LEFT/RIGHT margins in portrait to reclaim design width on the
## 360dp floor, and restores them in landscape — reacting to rotation via
## `ResponsiveManager.layout_class_changed`. Desktop/landscape stays unchanged.
##
## Usage (in a screen's _ready, after its own setup):
##   var pc := PortraitChrome.new()
##   add_child(pc)
##   pc.setup($MarginContainer)            # or get_node_or_null("MarginContainer")
##
## Margins only (it never reparents or restyles) — pair with an HBox->HFlow scene
## edit for non-wrapping button rows, per docs/sop/responsive-adaptive-ui.md.

## Gutter kept on each side in portrait. NOT the old 4px: content flush against the
## screen edge reads as broken, and on a rounded-corner phone the first few pixels are
## physically cut off.
##
## The value is the STANDARD, not a taste call: Material 3's responsive layout grid
## specifies 16dp margins at the 360dp breakpoint, which is exactly the narrowest
## screen this app supports.
##   https://m3.material.io/foundations/layout/grids-spacing/spacing
##
## Expressed in dp and converted per-measurement, because this project's design space
## is NOT dp — it is dp / ~1.16 (SettingsManager._apply_ui_scale() cancels the square
## 1080 base stretch). Hardcoding a design-px number silently changes the physical
## margin if that scale ever moves; the ratio is derived live in _gutter_design_px(),
## the same way tests/tools/verify_layout.gd derives it for its dp assertions.
const PORTRAIT_GUTTER_DP := 16.0

## Wider gutter once the window is no longer "compact".
##
## Material 3 specifies margins of 8/16/24/40dp and moves off 16dp above the compact
## breakpoint (600dp) — 16dp is the value for a PHONE, not for every portrait window.
## Reported as "edge to edge kissing" on a larger portrait window, where a 16dp margin
## that reads as deliberate on a 360dp phone reads as content jammed against the frame.
##   https://m3.material.io/foundations/layout/applying-layout/window-size-classes
const PORTRAIT_GUTTER_MEDIUM_DP := 24.0

## Width (dp) at which the medium gutter takes over. Material 3's compact/medium
## boundary, and the same number ResponsiveManager classifies TABLET from.
const COMPACT_MAX_DP := 600.0

## Fallback design-px gutter for the rare case where the viewport cannot be measured.
const PORTRAIT_GUTTER := 14

var _mc: MarginContainer = null
var _offset_target: Control = null
var _portrait_lr: int = PORTRAIT_GUTTER
var _landscape_lr: int = 20
var _rm: Node = null
var _wired: bool = false

func setup(margin_container: MarginContainer, portrait_lr: int = PORTRAIT_GUTTER,
		landscape_lr: int = -1) -> void:
	_mc = margin_container
	_portrait_lr = portrait_lr
	# Capture the scene's ORIGINAL L/R margin as the landscape restore value (robust
	# across screens with different base margins — managers are 20, the dashboard 24),
	# unless an explicit landscape value is passed.
	if landscape_lr >= 0:
		_landscape_lr = landscape_lr
	elif _mc:
		_landscape_lr = _mc.get_theme_constant("margin_left", "MarginContainer")
	_ensure_wired()
	_apply()

## Same job for a code-built screen that pads with anchor OFFSETS instead of wrapping
## its content in a MarginContainer.
##
## The Library is built that way and kept 32px per side at every size: on a 360dp phone
## that is 64 of 310 design px — a fifth of the screen — while every MarginContainer
## screen trims to PORTRAIT_GUTTER. Its category cards were 246px wide as a result.
func setup_offsets(content: Control, portrait_lr: int = PORTRAIT_GUTTER,
		landscape_lr: int = -1) -> void:
	_offset_target = content
	_portrait_lr = portrait_lr
	if landscape_lr >= 0:
		_landscape_lr = landscape_lr
	elif content:
		_landscape_lr = int(absf(content.offset_left))
	_ensure_wired()
	_apply()


func _ready() -> void:
	_ensure_wired()
	_apply()

func _ensure_wired() -> void:
	if _wired:
		return
	_rm = get_node_or_null("/root/ResponsiveManager")
	if _rm and _rm.has_signal("layout_class_changed") \
			and not _rm.layout_class_changed.is_connected(_on_layout_changed):
		_rm.layout_class_changed.connect(_on_layout_changed)
		_wired = true

func _on_layout_changed(_cols: int) -> void:
	_apply()

func _is_portrait() -> bool:
	if _rm and _rm.has_method("is_portrait"):
		return _rm.is_portrait()
	var vp := get_viewport()
	if vp == null:
		return false
	var s := vp.get_visible_rect().size
	return s.y > s.x

## The 16dp page margin in DESIGN px, derived from the live scale.
##
## design_px = dp / ratio, where ratio = window_px / design_space_px. On Windows
## screen_get_scale() is 1.0 so a window pixel IS a dp; on device the same identity
## holds after the ui-scale cancellation. 16dp therefore lands at ~14 design px.
func _gutter_design_px() -> int:
	var vp := get_viewport()
	if vp == null:
		return PORTRAIT_GUTTER
	var ds: Vector2 = vp.get_visible_rect().size
	if ds.x <= 0.0:
		return PORTRAIT_GUTTER
	var ratio: float = float(DisplayServer.window_get_size().x) / ds.x
	if ratio <= 0.0:
		return PORTRAIT_GUTTER
	# window px / OS display scale = dp, the same identity ResponsiveManager
	# classifies breakpoints from. On Windows screen_get_scale() is 1.0, so a
	# window pixel IS a dp and this is verifiable on the desktop.
	var scale: float = maxf(1.0, DisplayServer.screen_get_scale())
	var width_dp: float = float(DisplayServer.window_get_size().x) / scale
	var gutter_dp: float = PORTRAIT_GUTTER_DP
	if width_dp >= COMPACT_MAX_DP:
		gutter_dp = PORTRAIT_GUTTER_MEDIUM_DP
	return int(round(gutter_dp / ratio))


## Extra inset when the OS reports a cutout or system bar on this edge.
##
## DisplayServer.get_display_safe_area() is the documented Godot 4 API for this
## (OS.get_window_safe_area() was removed); the community pattern is exactly this —
## a MarginContainer that takes its margins from the safe area. On desktop the safe
## area IS the whole screen, so this returns 0 and nothing changes.
func _safe_area_lr() -> Vector2:
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var screen: Vector2i = DisplayServer.screen_get_size()
	if safe.size.x <= 0 or screen.x <= 0 or safe.size.x >= screen.x:
		return Vector2.ZERO
	var vp := get_viewport()
	if vp == null:
		return Vector2.ZERO
	var ds: Vector2 = vp.get_visible_rect().size
	if ds.x <= 0.0:
		return Vector2.ZERO
	# Screen px -> design px, same ratio as above.
	var ratio: float = float(DisplayServer.window_get_size().x) / ds.x
	if ratio <= 0.0:
		return Vector2.ZERO
	var left: float = float(safe.position.x) / ratio
	var right: float = float(screen.x - (safe.position.x + safe.size.x)) / ratio
	return Vector2(maxf(0.0, left), maxf(0.0, right))


func _apply() -> void:
	var lr: int = _gutter_design_px() if _is_portrait() else _landscape_lr
	var inset := _safe_area_lr()
	var left: int = lr + int(inset.x)
	var right: int = lr + int(inset.y)
	if _offset_target != null and is_instance_valid(_offset_target):
		_offset_target.offset_left = float(left)
		_offset_target.offset_right = -float(right)
	if _mc == null or not is_instance_valid(_mc):
		return
	_mc.add_theme_constant_override("margin_left", left)
	_mc.add_theme_constant_override("margin_right", right)
