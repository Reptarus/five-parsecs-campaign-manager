extends "res://tests/tools/capture_screens.gd"
## WINDOWED capture of the variant game modes, screen by screen and STEP by step, for a
## visual UI/UX review on real renders (Sprint U, 2026-10-28).
##
## capture_screens.gd covers the 21 5PFH and shared screens. Nothing captured, swept or
## laid out the Planetfall or Tactics screens, or ANY variant mode's turn-step panels,
## which is how Planetfall shipped with no map screen and four self-labelled stubs. This
## builds a campaign through the mode's REAL producers (the creation wizard's own panels
## and coordinator, never a hand-written dict), then renders every creation step, the
## dashboard and each turn step as the turn controller shows it.
##
## Run (no --headless: headless has no renderer):
##   godot --path <root> --script res://tests/tools/capture_modes.gd -- \
##       mode=planetfall size=2560x1600 out=user://shots/pf_land
##
## Saves written by the phase manager while stepping are removed afterwards by the same
## SaveDirGuard the unit suites use, so a capture run leaves user://saves as it found it.

var _mode := "planetfall"
var _guard_snap: Dictionary = {}
var _guard: GDScript = null


func _run() -> void:
	_parse_args()
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("mode="):
			_mode = String(arg).substr(5)
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_guard = load("res://tests/fixtures/helpers/save_dir_guard.gd")
	_guard_snap = _guard.snapshot()
	DisplayServer.window_set_size(_size)
	for _i in range(4):
		await process_frame
	print("=== CAPTURE MODE %s %dx%d -> %s ===" % [_mode, _size.x, _size.y, _out_dir])
	match _mode:
		"planetfall":
			await _planetfall()
		_:
			print("unknown mode: %s" % _mode)
	var removed: int = _guard.restore(_guard_snap)
	print("saved %d screenshots to %s; removed %d save file(s) the run wrote" % [
			_saved, ProjectSettings.globalize_path(_out_dir), removed])
	quit(0)


## Save what is on screen now as <out>/<name>.png.
func _shot(name: String, inst: Node) -> void:
	if DisplayServer.window_get_size() != _size:
		DisplayServer.window_set_size(_size)
		for _i in range(3):
			await process_frame
	await _settle(inst)
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img == null:
		print("  SKIP %s: viewport image was null" % name)
		return
	img.save_png("%s/%s.png" % [_out_dir, name])
	_saved += 1
	print("  %s" % name)


func _mount(path: String) -> Node:
	var ps: PackedScene = load(path)
	var inst: Node = ps.instantiate() if ps else null
	if inst == null:
		print("  SKIP %s: did not instantiate" % path)
		return null
	root.add_child(inst)
	await _settle(inst)
	_apply_runtime_overlay_net(inst)
	await _settle(inst)
	return inst


func _unmount(inst: Node) -> void:
	if inst and is_instance_valid(inst):
		inst.queue_free()
	await process_frame
	await process_frame


## ============================================================================
## PLANETFALL
## ============================================================================

func _planetfall() -> void:
	var gs: Node = root.get_node_or_null("/root/GameState")
	if gs:
		gs.current_campaign = null

	# --- Creation wizard: each step as the player sees it, fed by its own panel ---
	var ui: Node = await _mount("res://src/ui/screens/planetfall/PlanetfallCreationUI.tscn")
	if ui == null:
		return
	var coord: Node = ui.coordinator
	var names := ["1_expedition", "2_roster", "3_backgrounds", "4_map", "5_tutorials", "6_review"]
	for step in range(names.size()):
		coord.go_to_step(step)
		await _settle(ui)
		await _shot("pf_create_%s_empty" % names[step], ui)
		var panel: Node = ui.panels[step]
		match step:
			0:
				panel._on_roll_pressed()
			1:
				panel.use_recommended_roster()
			2:
				for c in coord.roster_data.slice(0, 4):
					panel.set_experienced(str(c.id), true)
				panel.roll_all()
			3:
				panel._on_roll_home()
			4:
				panel._on_skip_all()
			5:
				if panel.has_method("refresh"):
					panel.refresh()
		await _settle(ui)
		await _shot("pf_create_%s_filled" % names[step], ui)
	var campaign: Resource = coord.build_campaign()
	await _unmount(ui)
	if gs:
		gs.set_current_campaign(campaign)

	# --- Dashboard ---
	var dash: Node = await _mount("res://src/ui/screens/planetfall/PlanetfallDashboard.tscn")
	if dash:
		await _shot("pf_dashboard", dash)
		await _unmount(dash)

	# --- The 18-step turn, as the turn controller shows each step ---
	var tc: Node = await _mount("res://src/ui/screens/planetfall/PlanetfallTurnController.tscn")
	if tc == null:
		return
	for _i in range(10):
		await process_frame
	var pm: Node = tc.phase_manager
	if pm == null:
		print("  SKIP turn: no phase manager")
		return
	var ph: Dictionary = (pm.get_script() as GDScript).get_script_constant_map()["Phase"]
	var guard := 0
	while pm.current_phase != ph.LOCK_AND_LOAD and pm.current_phase != ph.PLAY_OUT_MISSION \
			and guard < 12:
		await _shot("pf_turn_%02d_%s" % [pm.current_phase + 1, _phase_slug(pm)], tc)
		pm.complete_current_phase({})
		await _settle(tc)
		guard += 1
	await _shot("pf_turn_%02d_%s" % [pm.current_phase + 1, _phase_slug(pm)], tc)

	# The battle itself is TacticalBattleUI, captured with the 5PFH screens. A return
	# with a win against the stamped mission opens the post-battle steps.
	tc._resume_after_battle({"won": true, "mission_type": "exploration"})
	await _settle(tc)
	guard = 0
	while pm.current_phase != ph.NONE and guard < 14:
		await _shot("pf_turn_%02d_%s" % [pm.current_phase + 1, _phase_slug(pm)], tc)
		var before: int = pm.current_phase
		pm.complete_current_phase({})
		await _settle(tc)
		guard += 1
		if pm.current_phase <= before:
			break
	await _unmount(tc)


func _phase_slug(pm: Node) -> String:
	return str(pm.get_phase_name(pm.current_phase)).to_lower().replace(" ", "_") \
			.replace("&", "and").replace("/", "_")
