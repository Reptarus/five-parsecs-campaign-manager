extends SceneTree
## T11-07 — can a SECOND size change arriving before the next frame leave
## ResponsiveManager's published state inconsistent with the theme it scaled?
##
## WHY THIS PROBE EXISTS. `verify_rotation.gd` applies ONE size change per step and
## awaits a frame after each (`_apply_size`, :187-190), so it is structurally blind to
## the only sequence that reproduces T11-07 on hardware: an extra configuration change
## delivered ~100 ms before a rotation. Android sends SEVERAL config updates around one
## physical turn, so the harness's clean single rotation is the ARTIFICIAL case.
##
## NOTE: no --headless. DisplayServer returns dummy values under --headless, so
## window_set_size() would do nothing and every reading would be the default rect.
##
##   godot --path . --script res://tests/tools/probe_double_config_change.gd
##
## The device is a Lenovo TB361FU: 1600x2560 physical at density 320, i.e.
## screen_get_scale 2.0, so 1280x800 dp landscape and 800x1280 dp portrait. On
## Windows screen_get_scale() is 1.0, so setting those numbers directly as window
## pixels reproduces the same dp classification: 1280 -> WIDE, 800 -> DESKTOP.

const TABLET_LANDSCAPE := Vector2i(1280, 800)
const TABLET_PORTRAIT := Vector2i(800, 1280)

var _rm: Node = null
var _theme: Theme = null
var _started := false
var _frame := 0


func _process(_d: float) -> bool:
	_frame += 1
	if _frame < 3:
		return false
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	_rm = root.get_node_or_null("/root/ResponsiveManager")
	if _rm == null:
		print("FATAL: ResponsiveManager autoload missing")
		quit(1)
		return
	_theme = load("res://src/ui/themes/sci_fi_theme.tres") as Theme
	if _theme == null:
		print("FATAL: sci_fi_theme.tres did not load")
		quit(1)
		return

	_force_windowed()
	await process_frame

	print("=== T11-07 double-config-change probe ===")
	print("screen_get_scale = %.3f  (Windows reports 1.0, the tablet reports 2.0)"
		% DisplayServer.screen_get_scale())
	print("")

	# ── CONTROL: one clean rotation, a frame between each step ────────────────
	print("--- CONTROL A: clean rotation (what verify_rotation does) ---")
	await _settle_at(TABLET_LANDSCAPE)
	var base_state := _state("landscape, settled")
	await _settle_at(TABLET_PORTRAIT)
	_state("portrait, settled")
	await _settle_at(TABLET_LANDSCAPE)
	var after_clean := _state("landscape again, settled")
	print("  clean round trip returns to start: %s"
		% ("YES" if after_clean == base_state else "NO  <-- FINDING"))
	print("")

	# ── B: a SAME-SIZE change immediately before the rotation, no frame ───────
	# This is the no-op `settings put` from the hardware repro: it changes nothing
	# about the device, it only delivers an extra configuration broadcast.
	print("--- B: no-op config change + rotation, NO frame between ---")
	await _settle_at(TABLET_LANDSCAPE)
	DisplayServer.window_set_size(TABLET_LANDSCAPE)   # the no-op write
	DisplayServer.window_set_size(TABLET_PORTRAIT)    # the rotation, same frame
	await _drain()
	_state("portrait after double change")
	await _settle_at(TABLET_LANDSCAPE)
	var after_b := _state("back to landscape, settled")
	print("  matches the clean baseline: %s"
		% ("YES" if after_b == base_state else "NO  <-- FINDING"))
	print("")

	# ── C: a DIFFERENT intermediate size, no frame — a transient reading ──────
	print("--- C: transient intermediate size + rotation, NO frame between ---")
	await _settle_at(TABLET_LANDSCAPE)
	DisplayServer.window_set_size(Vector2i(2560, 1600))  # a bogus mid-rotation read
	DisplayServer.window_set_size(TABLET_PORTRAIT)
	await _drain()
	_state("portrait after transient")
	await _settle_at(TABLET_LANDSCAPE)
	var after_c := _state("back to landscape, settled")
	print("  matches the clean baseline: %s"
		% ("YES" if after_c == base_state else "NO  <-- FINDING"))
	print("")

	print("=== done ===")
	quit(0)


## Everything the app's type sizing depends on, in one line, so two runs can be
## compared by string equality rather than by eye.
func _state(label: String) -> String:
	var bp: int = _rm.current_breakpoint
	var mult: float = _rm.get_font_size_multiplier()
	var vp: Vector2 = _rm.current_viewport_size
	# The invariant: the theme must be scaled for the breakpoint RM is publishing.
	# If these disagree, every non-overriding control is sized for a screen the app
	# is not on — and nothing recomputes it, because _apply_theme_font_scale() runs
	# only on a bucket CHANGE.
	var theme_default: int = _theme.default_font_size
	var sig := "bp=%s mult=%.2f vp=%dx%d theme_default=%d" % [
		_rm.get_breakpoint_name(), mult, int(vp.x), int(vp.y), theme_default]
	print("  %-34s %s" % [label, sig])
	return sig


func _settle_at(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
	await _drain()


## Let the resize propagate: size_changed, the RM handler, and TacticalBattleUI's
## 0.15 s debounce timer all need real frames.
func _drain() -> void:
	for _i in range(20):
		await process_frame


## verify_layout.gd's lesson: a maximized or minimized window ignores
## window_set_size() entirely, and window.ini has persisted MODE_MINIMIZED before.
func _force_windowed() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode != DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
