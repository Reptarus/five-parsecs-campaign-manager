extends SceneTree
## Why do verify_layout.gd and verify_rotation.gd DISAGREE about the same screen at
## the same size?
##
## After the backdrop filter was removed from verify_rotation's overflow check
## (2026-09-04), the rotation sweep reported SettingsScreen overflowing by 297.2 px at
## phone portrait and TacticalBattleUI's OverlayCenter by 181.3 px at phone landscape.
## verify_layout reports NEITHER, at any size, and raising its settle cap from 30 to 40
## frames (matching rotation) did not change that — so it is not a mid-build read.
##
## The remaining structural differences are two, and they have opposite implications:
##
##   A. ONE INSTANCE, MANY RESIZES. rotation builds once and resizes; layout builds
##      fresh per size. If a screen only overflows after being resized, the finding is
##      REAL and is exactly the bug class rotation exists to catch.
##   B. MANY SCREENS, ONE PROCESS. Both sweeps walk every screen in a single process
##      and share autoloads (SettingsOverlay's reserved band, SettingsManager, GameState).
##      If a screen only overflows when others ran first, the finding is ORDER-DEPENDENT
##      and the harness is wrong, not the screen.
##
## Telling them apart is the whole point of this probe: it measures the SAME screen in
## isolation, three ways, and prints all three. Filing a defect without this would be
## filing on speculation.
##
## Run (NOTE: no --headless — this needs a real window to resize):
##   godot --path <root> --script res://tests/tools/probe_rotation_divergence.gd \
##       -- campaign=user://saves/<x>.save

const TARGETS: Array = [
	["res://src/ui/screens/settings/SettingsScreen.tscn", 393, 851, "phone portrait"],
	["res://src/ui/screens/battle/TacticalBattleUI.tscn", 851, 393, "phone landscape"],
]

var _frame := 0
var _started := false


func _process(_d: float) -> bool:
	_frame += 1
	if _frame < 2 or _started:
		return false
	_started = true
	_run()
	return false


func _run() -> void:
	_force_windowed()
	_stub_legal_consent()
	_load_requested_campaign()
	print("=== ROTATION-DIVERGENCE PROBE ===")
	for t in TARGETS:
		await _probe(String(t[0]), int(t[1]), int(t[2]), String(t[3]))
	print("=== END ===")
	quit(0)


func _probe(path: String, w: int, h: int, label: String) -> void:
	var short := path.get_file()
	# T11-47: these are raw window PIXELS, not dp. Design space is window_px divided by
	# the net effective scale, which after the T11-07 fix carries NO density term — so a
	# dp-sized window gives HALF the linear room a 2.0-density device has, in the same
	# breakpoint. The design space is MEASURED below rather than computed from 1.16, so
	# this probe cannot start lying if TARGET_EFFECTIVE moves.
	print("\n---- %s @ %s (%dx%d px) ----" % [short, label, w, h])

	# 1. FRESH INSTANCE, MEASURED ONCE — reproduces verify_layout's flow exactly.
	await _apply_size(w, h)
	var ds: Vector2 = root.get_visible_rect().size
	print("     design space: %.0f x %.0f" % [ds.x, ds.y])
	var a := await _build_and_measure(path)
	print("  A  fresh instance, measured once      : %s" % a)

	# 2. SAME INSTANCE, RESIZED AWAY AND BACK — reproduces verify_rotation's flow.
	await _apply_size(w, h)
	var ps: PackedScene = load(path)
	var inst: Node = ps.instantiate()
	root.add_child(inst)
	if inst is CanvasItem and not (inst as CanvasItem).visible:
		(inst as CanvasItem).show()
	_populate(inst, path)
	await _settle(inst)
	_overlay_net(inst)
	await _settle(inst)
	var before := _worst(inst)
	await _apply_size(h, w)          # rotate
	await _settle(inst)
	await _apply_size(w, h)          # rotate back
	await _settle(inst)
	var after := _worst(inst)
	print("  B  same instance, before any rotation : %s" % before)
	print("  C  same instance, after a round trip  : %s" % after)
	inst.queue_free()
	await process_frame

	if a == before:
		print("  -> A == B: the sweeps should agree; any difference is ORDER-DEPENDENT")
	else:
		print("  -> A != B: the divergence is NOT rotation and NOT order — look here")
	if before != after:
		print("  -> B != C: the screen does not survive a rotation round trip (REAL)")


func _build_and_measure(path: String) -> String:
	var ps: PackedScene = load(path)
	if ps == null:
		return "scene failed to load"
	var inst: Node = ps.instantiate()
	if inst == null:
		return "instantiate() returned null"
	root.add_child(inst)
	if inst is CanvasItem and not (inst as CanvasItem).visible:
		(inst as CanvasItem).show()
	_populate(inst, path)
	await _settle(inst)
	_overlay_net(inst)
	await _settle(inst)
	var out := _worst(inst)
	inst.queue_free()
	await process_frame
	return out


## Worst overflow in the tree, named — the same arithmetic both sweeps use.
func _worst(inst: Node) -> String:
	var ds: Vector2 = root.get_visible_rect().size
	var worst := 0.0
	var who := ""
	var axis := ""
	var worst_rect := Rect2()
	var n_visible := 0
	var stack: Array = [inst]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for c in node.get_children():
			stack.append(c)
		if not (node is Control) or not (node as Control).is_visible_in_tree():
			continue
		var ctl := node as Control
		n_visible += 1
		var r: Rect2 = ctl.get_global_rect()
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			continue
		if _inside_scroll(ctl, inst):
			continue
		var off_x: float = maxf(-r.position.x, r.end.x - ds.x)
		var off_y: float = maxf(-r.position.y, r.end.y - ds.y)
		var off: float = maxf(off_x, off_y)
		if off > worst:
			worst = off
			who = String(ctl.name)
			axis = "X (width)" if off_x >= off_y else "Y (height)"
			worst_rect = r
	if worst <= 0.5:
		return "no overflow (%d visible controls)" % n_visible
	return "%s off by %.1f px on %s [rect %s vs design %s] (%d visible controls)" % [
		who, worst, axis, str(worst_rect), str(ds), n_visible]


func _inside_scroll(n: Node, stop: Node) -> bool:
	var p := n.get_parent()
	while p != null and p != stop:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false


func _populate(inst: Node, path: String) -> void:
	var cls = load("res://tests/tools/screen_populator.gd")
	if cls == null:
		return
	var pop = cls.new(root)
	pop.populate_pre(path)
	pop.populate_post(inst, path)


func _overlay_net(inst: Node) -> void:
	var so := root.get_node_or_null("/root/SettingsOverlay")
	if so == null:
		return
	if so.has_method("_update_visibility"):
		so._update_visibility()
	if so.has_method("reserve_band_on"):
		so.reserve_band_on(inst)


func _settle(inst: Node) -> void:
	var last := ""
	var stable := 0
	for _i in range(40):
		await process_frame
		var sig := _signature(inst)
		if sig == last:
			stable += 1
			if stable >= 3:
				return
		else:
			stable = 0
			last = sig


func _signature(inst: Node) -> String:
	var acc := 0.0
	var n := 0
	var stack: Array = [inst]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for c in node.get_children():
			stack.append(c)
		if node is Control and (node as Control).is_visible_in_tree():
			var r: Rect2 = (node as Control).get_global_rect()
			acc += r.position.x + r.position.y * 3.0 + r.size.x * 7.0 + r.size.y * 11.0
			n += 1
	return "%d:%.2f" % [n, acc]


func _apply_size(w: int, h: int) -> bool:
	DisplayServer.window_set_size(Vector2i(w, h))
	for _i in range(40):
		await process_frame
		var got: Vector2i = DisplayServer.window_get_size()
		if absi(got.x - w) <= 2 and absi(got.y - h) <= 2:
			for _j in range(3):
				await process_frame
			return true
	return false


func _force_windowed() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("probe_rotation_divergence: run WITHOUT --headless.")
		quit(2)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var scr: int = DisplayServer.window_get_current_screen()
	DisplayServer.window_set_position(
		DisplayServer.screen_get_usable_rect(scr).position + Vector2i(8, 8))


## In memory only. NEVER call accept_eula()/accept_privacy() — that would write a
## consent no human gave.
func _stub_legal_consent() -> void:
	var lcm := root.get_node_or_null("/root/LegalConsentManager")
	if lcm == null:
		return
	lcm.eula_accepted = true
	lcm.eula_accepted_version = lcm.EULA_VERSION
	lcm.privacy_accepted = true
	lcm.privacy_accepted_version = lcm.PRIVACY_VERSION


func _load_requested_campaign() -> void:
	var wanted := ""
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("campaign="):
			wanted = String(arg).substr("campaign=".length())
	if wanted.is_empty() or not FileAccess.file_exists(wanted):
		return
	var gs := root.get_node_or_null("/root/GameState")
	if gs and gs.has_method("load_campaign"):
		gs.load_campaign(wanted)
