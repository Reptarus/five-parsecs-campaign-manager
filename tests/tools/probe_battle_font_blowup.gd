extends SceneTree
## T11-07 — does a config change immediately before a rotation leave
## TacticalBattleUI's TEXT larger than a clean rotation leaves it?
##
## The device symptom: the battle screen renders text ~1.8-2x too large, content
## clips off the top and bottom, and it persists until the app is restarted. Buttons
## keep their WIDTH and grow ~2.4x in HEIGHT — width is container-driven, height is
## font-driven, which is what named type as the driver rather than a zoom.
##
## WHAT THIS PROBE ADDS OVER verify_rotation.gd. That harness applies ONE size change
## per step and awaits a frame after each (`_apply_size`, :187-190). Android delivers
## SEVERAL configuration updates around one physical rotation, so the harness's clean
## single rotation is the ARTIFICIAL case and it is structurally blind to the real one.
## Here the second size change is issued in the SAME frame as the first.
##
## WHAT IS ALREADY RULED OUT (measured, not assumed):
##   - ResponsiveManager. tests/tools/probe_double_config_change.gd drives it through
##     the identical sequences and its breakpoint / multiplier / scaled theme stay
##     mutually consistent every time. Its font ladder is bounded at 1.3 / 0.85, so it
##     cannot produce a 1.8-2.4x change under ANY sequence.
##   - TacticalBattleUI._apply_responsive_layout(). It sets custom_minimum_size on four
##     panels and touches no font anywhere; its re-entrancy flag is reset on both exit
##     paths and the is_inside_tree() early return is deliberately placed BEFORE the
##     flag is set.
##
## So this measures the rendered result directly instead of another suspect.
##
## NOTE: no --headless. DisplayServer returns dummy values under --headless.
##
##   godot --path . --script res://tests/tools/probe_battle_font_blowup.gd

const BATTLE := "res://src/ui/screens/battle/TacticalBattleUI.tscn"
## ⚠ T11-47 (2026-09-06) — THESE ARE THE TABLET'S dp, NOT ITS PANEL. The TB361FU is
## 2560x1600 physical at screen_get_scale 2.0, so 1280x800 is its dp. After the T11-07
## density fix the net effective scale is `TARGET_EFFECTIVE * ui_scale` with NO density
## term, so design space is `window_px / 1.16` on every platform:
##
##     these constants  ->  1103 x  689 design px
##     the real device  ->  2207 x 1379 design px
##
## The BREAKPOINT is identical either way (ResponsiveManager divides by screen_get_scale),
## so the responsive font sizes this probe reads are the same in both — but the boxes
## holding them are HALF the linear size here. A font blowup is a ratio of glyph to box,
## so this probe is the harsher of the two: a blowup seen at these constants is not by
## itself evidence of one on hardware. Re-measure with TABLET_*_TRUE_PX before filing.
const TABLET_LANDSCAPE := Vector2i(1280, 800)
const TABLET_PORTRAIT := Vector2i(800, 1280)
const TABLET_LANDSCAPE_TRUE_PX := Vector2i(2560, 1600)
const TABLET_PORTRAIT_TRUE_PX := Vector2i(1600, 2560)

var _started := false
var _frame := 0
var _populator = null

## The probe's own premise, instrumented.
##
## Issuing two window_set_size() calls in one frame is only a two-event sequence if the
## engine actually DELIVERS two size_changed events. If it coalesces them, sequence B is
## identical to sequence A by construction and an "IDENTICAL" result would be a false
## negative dressed up as evidence — a check that cannot disagree with itself. So the
## events are counted and printed, and the verdict is withheld unless the count differs.
var _size_events := 0
var _last_events := 0


func _process(_d: float) -> bool:
	_frame += 1
	if _frame < 3:
		return false
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	_stub_legal_consent()
	_force_windowed()
	root.size_changed.connect(func() -> void: _size_events += 1)
	var cls = load("res://tests/tools/screen_populator.gd")
	_populator = cls.new(root) if cls != null else null
	if _populator == null:
		print("FATAL: screen_populator.gd failed to load")
		quit(1)
		return
	print("=== T11-07 battle-screen font probe ===")
	print("populator: %s" % _populator.state_line())
	print("")

	# CONTROL: a clean rotation out and back, a frame between every step.
	var clean := await _sequence(false)
	var clean_events := _last_events
	print("")
	# CANDIDATE: the same rotation with an extra config change just before it.
	var doubled := await _sequence(true)
	var doubled_events := _last_events

	print("")
	print("=== RESULT ===")
	print("  clean rotation      : %s  (%d event)" % [clean, clean_events])
	print("  extra config change : %s  (%d events)" % [doubled, doubled_events])
	if clean != doubled:
		print("  DIFFERENT  <-- reproduced; the diff names the driver.")
	elif doubled_events <= clean_events:
		print("  INCONCLUSIVE: sequence B did not actually deliver more size_changed")
		print("  events than A, so it was not a double change and proves nothing.")
	else:
		print("  IDENTICAL text metrics, and B genuinely delivered %d events to A's %d."
			% [doubled_events, clean_events])
		print("  T11-07 does NOT reproduce through the DisplayServer path at the desk.")
	quit(0)


## Build the screen fresh, walk it through the rotation, and report the text metrics
## it settles at. Fresh per run so one run cannot inherit the other's damage — which
## is the very thing being tested for.
func _sequence(extra_config_change: bool) -> String:
	var label := "extra config change" if extra_config_change else "clean rotation"
	print("--- %s ---" % label)

	await _settle_at(TABLET_LANDSCAPE)
	_populator.populate_pre(BATTLE)
	var packed := load(BATTLE) as PackedScene
	if packed == null:
		return "SCENE FAILED TO LOAD"
	var inst := packed.instantiate()
	root.add_child(inst)
	_populator.populate_post(inst, BATTLE)
	await _drain()
	var before := _text_signature(inst)
	print("  landscape, built     : %s" % before)

	var events_before := _size_events
	if extra_config_change:
		# TWO REAL size_changed events inside TacticalBattleUI's 0.15 s debounce.
		#
		# ⚠ The first version of this issued window_set_size(SAME_SIZE) then the
		# rotation in one frame, modelling the hardware repro's no-op `settings put`
		# literally. It delivered ONE event, not two — a same-size write changes
		# nothing so the engine emits nothing — which made sequence B identical to
		# sequence A by construction. The counter above is what caught it; the
		# "IDENTICAL" it produced would otherwise have been filed as a real finding.
		#
		# window_set_size() twice in one frame also coalesces, so a genuine
		# two-event sequence needs a frame between the writes while still landing
		# both inside the debounce. That is the closest the desk can get to Android
		# delivering several configuration updates around one physical turn.
		DisplayServer.window_set_size(Vector2i(1024, 800))
		await process_frame
		DisplayServer.window_set_size(TABLET_PORTRAIT)
		await _drain()
	else:
		await _settle_at(TABLET_PORTRAIT)
	var delivered := _size_events - events_before
	print("  size_changed events  : %d  %s" % [delivered,
		"(premise holds)" if delivered >= 1 else "(NONE - probe measured nothing)"])
	print("  portrait             : %s" % _text_signature(inst))

	await _settle_at(TABLET_LANDSCAPE)
	var after := _text_signature(inst)
	print("  back to landscape    : %s" % after)
	print("  returned to start    : %s"
		% ("YES" if after == before else "NO  <-- the screen did not recover"))

	inst.queue_free()
	await _drain()
	_last_events = delivered
	return after


## Resolved type sizes actually in effect, plus the rect they are laid out in.
##
## get_theme_font_size() is read rather than the authored constant because it resolves
## the whole chain — a per-node add_theme_font_size_override() first, then the project
## theme ResponsiveManager rescales. Reading either half alone would miss the other,
## and the override half is ~1,200 call sites.
func _text_signature(inst: Node) -> String:
	var sizes: Array[int] = []
	_collect_font_sizes(inst, sizes)
	sizes.sort()
	var total := 0
	for s in sizes:
		total += s
	var vp := inst.get_viewport().get_visible_rect().size if inst.is_inside_tree() else Vector2.ZERO
	return "vp=%dx%d n=%d min=%d max=%d mean=%.2f" % [
		int(vp.x), int(vp.y), sizes.size(),
		sizes[0] if not sizes.is_empty() else -1,
		sizes[-1] if not sizes.is_empty() else -1,
		(float(total) / float(sizes.size())) if not sizes.is_empty() else 0.0]


func _collect_font_sizes(n: Node, out: Array[int]) -> void:
	if n is Label or n is Button or n is RichTextLabel:
		var c := n as Control
		if c.is_visible_in_tree():
			out.append(c.get_theme_font_size("font_size"))
	for child in n.get_children():
		_collect_font_sizes(child, out)


func _settle_at(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
	await _drain()


## TacticalBattleUI debounces resizes by 0.15 s before re-laying out, so a handful of
## frames is not enough — this must outlast the timer or the probe measures the state
## before the screen has reacted at all.
func _drain() -> void:
	for _i in range(40):
		await process_frame


func _force_windowed() -> void:
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


## IN MEMORY ONLY — never call accept_*(), which would write real consent to
## user://legal_consent.cfg and silently change what a later manual test is testing.
func _stub_legal_consent() -> void:
	var lcm := root.get_node_or_null("/root/LegalConsentManager")
	if lcm == null:
		return
	for prop in ["_eula_accepted", "_privacy_accepted", "eula_accepted", "privacy_accepted"]:
		if prop in lcm:
			lcm.set(prop, true)
