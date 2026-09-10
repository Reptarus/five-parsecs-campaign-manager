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
## is NOT dp — it is `window_px / ~1.16` (SettingsManager._apply_ui_scale() cancels the
## square 1080 base stretch).
## ⚠ T11-47 (2026-09-06): this read "it is dp / ~1.16". The divisor applies to raw
## WINDOW PIXELS — the net effective scale has no density term after the T11-07 fix —
## and dp only equals px where screen_get_scale() is 1.0. Deriving the ratio live, which
## _gutter_design_px() already does, is what makes this correct on both; the unit in the
## prose was the only thing wrong. Hardcoding a design-px number silently changes the physical
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
## The screen's OWN top/bottom padding, captured once at setup. A safe-area inset
## is applied as maxi(base, inset), so a screen that already pads generously keeps
## its look and only grows where the OS actually reserves space.
var _base_top: int = 0
var _base_bottom: int = 0
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
	if _mc:
		_base_top = _mc.get_theme_constant("margin_top", "MarginContainer")
		_base_bottom = _mc.get_theme_constant("margin_bottom", "MarginContainer")
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
	if content:
		_base_top = int(maxf(0.0, content.offset_top))
		_base_bottom = int(absf(minf(0.0, content.offset_bottom)))
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


## Safe-area insets on ALL FOUR edges, in DESIGN px. The single implementation.
##
## `DisplayServer.get_display_safe_area()` is the documented Godot 4 API for this
## (`OS.get_window_safe_area()` was removed); the community pattern is exactly this —
## a MarginContainer that takes its margins from the safe area.
##
## ⚠ **Unified 2026-09-08, and the two implementations it replaced disagreed THREE ways.**
## This file covered LEFT/RIGHT only, ADDED the inset to the gutter, and measured against
## `screen_get_size()`. `CampaignScreenBase.get_safe_area_insets()` covered all four edges,
## took `maxi(base, inset)`, and measured against `window_get_size()` — and had exactly
## ONE caller, `CampaignDashboard`. Net effect: the **ten** screens routed through
## `ScreenChrome.apply_page_chrome()` had NO top/bottom protection at all, and `MainMenu`
## — the first screen the app shows — had neither.
##
## **`maxi` is the correct semantic; the additive version was wrong.** A safe area is a
## region you must not draw IN, not padding to add ON TOP of your own gutter. With a 40 px
## cutout and a 14 px gutter the requirement is 40, not 54.
##
## **The reference rect is the WINDOW, not the screen.** On Android the app is fullscreen
## so the two coincide; on a desktop window the safe area is the whole monitor, which is
## larger, so every edge clamps to 0 — the intended desktop no-op.
##
## ⚠ **All-zeros is a VALID answer, not a broken measurement.** `export_presets.cfg:60`
## sets `screen/immersive_mode=true`, which hides the system bars, so on this device the
## honest result may well be zero on every edge. Code that treats zero as "the API failed"
## and substitutes a guess would be indistinguishable from a real inset — and wrong.
static func safe_area_insets_design_px(vp: Viewport) -> Dictionary:
	var zero := {"left": 0, "top": 0, "right": 0, "bottom": 0}
	if vp == null:
		return zero
	var os_name := OS.get_name()
	if os_name != "Android" and os_name != "iOS":
		return zero
	var win_size := DisplayServer.window_get_size()
	var raw_safe := DisplayServer.get_display_safe_area()
	var vp_size := vp.get_visible_rect().size
	var insets := compute_safe_area_insets(win_size, raw_safe, vp_size)
	# §1 INSTRUMENT (deploy #29). This is the ONLY call to get_display_safe_area()
	# repo-wide and all three consumer paths funnel through this function, so one print
	# here covers the whole feature. It exists because a SCREENSHOT cannot distinguish
	# "the engine reported no inset" from "our math zeroed a real one" - the frame is
	# identical either way, which is exactly why §1 was unverifiable on deploy #28.
	# Under `screen/immersive_mode=true` the honest answer is often all-zeros; the RAW
	# rect is what says whether that zero is the device's or ours.
	if OS.is_debug_build():
		print("[SAFEAREA] win=", win_size, " raw=", raw_safe,
			" vp=", vp_size, " -> ", insets)
	return insets


## The pure math, split out from the live-state wrapper above so it is TESTABLE.
##
## ⚠ **The wrapper cannot be unit-tested and this can.** `safe_area_insets_design_px()`
## is OS-gated to Android/iOS and reads `DisplayServer` directly, so on a desktop test
## machine it returns zeros no matter what — a suite written against it would pass
## vacuously and could never prove anything about a notch it is unable to produce.
## Taking the three inputs as parameters is the whole reason a real cutout can be
## simulated at the desk.
##
## `win` and `safe` are PHYSICAL px; `ds` is the design-space size
## (`Viewport.get_visible_rect().size`). Every edge clamps at 0, so a safe area larger
## than the window — which is what a desktop monitor reports for a smaller window —
## yields zeros rather than negative padding.
static func compute_safe_area_insets(win: Vector2i, safe: Rect2i, ds: Vector2) -> Dictionary:
	var zero := {"left": 0, "top": 0, "right": 0, "bottom": 0}
	if win.x <= 0 or win.y <= 0 or safe.size.x <= 0 or safe.size.y <= 0:
		return zero
	if ds.x <= 0.0 or ds.y <= 0.0:
		return zero
	# physical px -> design px, derived per AXIS. The square-1080 canvas_items+expand
	# stretch makes rx == ry today; deriving both means a future stretch change cannot
	# silently mis-scale one edge pair while the other stays right.
	var rx: float = float(win.x) / ds.x
	var ry: float = float(win.y) / ds.y
	if rx <= 0.0 or ry <= 0.0:
		return zero
	return {
		"left": int(maxf(0.0, float(safe.position.x)) / rx),
		"top": int(maxf(0.0, float(safe.position.y)) / ry),
		"right": int(maxf(0.0, float(win.x - (safe.position.x + safe.size.x))) / rx),
		"bottom": int(maxf(0.0, float(win.y - (safe.position.y + safe.size.y))) / ry),
	}


func _apply() -> void:
	var lr: int = _gutter_design_px() if _is_portrait() else _landscape_lr
	var ins := safe_area_insets_design_px(get_viewport())
	# maxi, never + — see safe_area_insets_design_px(). On desktop and under immersive
	# mode every inset is 0, so all four collapse to the screen's own values and this is
	# a no-op: the device is the only place these lines change anything.
	var left: int = maxi(lr, int(ins["left"]))
	var right: int = maxi(lr, int(ins["right"]))
	var top: int = maxi(_base_top, int(ins["top"]))
	var bottom: int = maxi(_base_bottom, int(ins["bottom"]))
	if _offset_target != null and is_instance_valid(_offset_target):
		_offset_target.offset_left = float(left)
		_offset_target.offset_right = -float(right)
		_offset_target.offset_top = float(top)
		_offset_target.offset_bottom = -float(bottom)
	if _mc == null or not is_instance_valid(_mc):
		return
	_mc.add_theme_constant_override("margin_left", left)
	_mc.add_theme_constant_override("margin_right", right)
	_mc.add_theme_constant_override("margin_top", top)
	_mc.add_theme_constant_override("margin_bottom", bottom)
