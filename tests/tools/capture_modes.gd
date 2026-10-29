extends "res://tests/tools/capture_screens.gd"
## WINDOWED capture of the variant game modes, screen by screen and STEP by step, for a
## visual UI/UX review on real renders (Sprint U, 2026-10-28).
##
## capture_screens.gd covers the 21 5PFH and shared screens. Nothing captured, swept or
## laid out the Planetfall, Tactics or Bug Hunt screens, or ANY variant mode's turn-step panels,
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
		"tactics":
			await _tactics()
		"bug_hunt":
			await _bug_hunt()
		"simulator":
			await _simulator()
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
		# Every card on the dashboard opens one of these as an overlay; none of them was
		# ever rendered by a capture, a sweep or a layout check.
		for overlay in ["colony_status", "equipment", "enemy_tracker", "augmentation",
				"milestones", "calamities"]:
			dash._show_overlay_panel(overlay)
			await _shot("pf_dash_%s" % overlay, dash)
		dash._overlay_container.visible = false
		# Import and Muster Out mount on the root, not the dashboard.
		for entry in [["import", "_on_import_pressed"], ["muster_out", "_on_muster_out_pressed"]]:
			var before: int = root.get_child_count()
			dash.call(entry[1])
			await _settle(dash)
			if root.get_child_count() > before:
				var added: Node = root.get_child(root.get_child_count() - 1)
				await _shot("pf_dash_%s" % entry[0], added)
				added.queue_free()
				await process_frame
			else:
				print("  SKIP pf_dash_%s: nothing was mounted" % entry[0])
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
	# The End Game, the way the turn controller lays it over the turn flow (pp.160-164).
	tc._show_endgame_panel()
	await _shot("pf_endgame", tc)
	# Every stage for each of the four paths (p.160). The stages are reached directly: the
	# dice and the payment are pinned by test_planetfall_endgame.gd, and this pass judges
	# what each stage shows a player.
	var eg: Node = tc._endgame_panel
	var stage: Dictionary = load(
		"res://src/ui/screens/planetfall/panels/PlanetfallEndGamePanel.gd").Stage
	eg._on_action()  # Hold Summit
	await _shot("pf_endgame_paths", tc)
	for path_id in ["independence", "ascension", "loyalty", "isolation"]:
		eg._on_path_selected(path_id)
		await _shot("pf_endgame_%s_1_security" % path_id, tc)
		eg._go_to(stage["FINAL_CONSTRUCTION"])
		await _shot("pf_endgame_%s_2_final" % path_id, tc)
		eg._go_to(stage["RESOLUTION"])
		await _shot("pf_endgame_%s_3_resolution" % path_id, tc)
	eg._resolve({})  # Isolation, the last path selected
	await _shot("pf_endgame_isolation_4_complete", tc)
	await _unmount(tc)


## ============================================================================
## TACTICS
## ============================================================================

## A legal p.134 Infantry Platoon of Human Colonists: one Leader, two Troops, one Support
## (fewer than Troops) and one Specialist (0-1 per two Troops), composed from
## army_builder.json by the species loader the wizard uses.
const TACTICS_PLATOON := ["human_sergeant", "human_infantry_squad", "human_infantry_squad",
		"human_weapon_team", "human_medic"]


func _tactics() -> void:
	var gs: Node = root.get_node_or_null("/root/GameState")
	if gs:
		gs.current_campaign = null

	# --- Creation wizard: each step fed by its own panel's handlers ---
	var ui: Node = await _mount("res://src/ui/screens/tactics/TacticsCreationUI.tscn")
	if ui == null:
		return
	var coord: Node = ui.coordinator
	await _shot("tac_create_0_launch", ui)  # before any step change: what a player first sees
	var names := ["1_config", "2_species", "3_roster", "4_review"]
	for step in range(names.size()):
		coord.go_to_step(step)
		await _settle(ui)
		await _shot("tac_create_%s_empty" % names[step], ui)
		var panel: Node = ui.panels[step]
		match step:
			0:
				panel._name_edit.text = "Sweep fixture"
				panel._on_name_changed("Sweep fixture")
			1:
				panel._on_species_selected("human_colonists")
			2:
				for unit_id in TACTICS_PLATOON:
					panel._add_unit_to_roster(unit_id)
			3:
				panel.refresh()
		await _settle(ui)
		await _shot("tac_create_%s_filled" % names[step], ui)
	print("  roster legal: %s %s" % [coord._step_complete[2], coord.get_validation_errors()])
	var campaign: Resource = coord.build_campaign()
	await _unmount(ui)
	if gs:
		gs.set_current_campaign(campaign)

	# --- Dashboard ---
	var dash: Node = await _mount("res://src/ui/screens/tactics/TacticsDashboard.tscn")
	if dash:
		await _shot("tac_dashboard", dash)
		var before: int = root.get_child_count()
		dash._on_commission_pressed()
		await _settle(dash)
		if root.get_child_count() > before:
			var added: Node = root.get_child(root.get_child_count() - 1)
			await _shot("tac_dash_commission", added)
			added.queue_free()
			await process_frame
		else:
			print("  SKIP tac_dash_commission: nothing was mounted on the root")
		await _unmount(dash)

	# --- The eight-phase turn, as the turn controller shows each phase ---
	var tc: Node = await _mount("res://src/ui/screens/tactics/TacticsTurnController.tscn")
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
	while pm.current_phase != ph.STRATEGIC and pm.current_phase != ph.NONE and guard < 10:
		await _shot("tac_turn_%d_%s" % [pm.current_phase, _phase_slug(pm)], tc)
		var data: Dictionary = tc._battle_payload("victory") \
				if pm.current_phase == ph.BATTLE else {}
		pm.complete_current_phase(data)
		await _settle(tc)
		guard += 1
	await _shot("tac_turn_%d_%s" % [pm.current_phase, _phase_slug(pm)], tc)
	pm.complete_current_phase({})
	await _settle(tc)
	await _shot("tac_turn_complete", tc)
	await _unmount(tc)


## ============================================================================
## BUG HUNT
## ============================================================================

const BH_TURN := "res://src/ui/screens/bug_hunt/BugHuntTurnController.tscn"


func _bug_hunt() -> void:
	var gs: Node = root.get_node_or_null("/root/GameState")
	if gs:
		gs.current_campaign = null

	# --- Creation wizard: each step fed by its own panel's handlers ---
	var ui: Node = await _mount("res://src/ui/screens/bug_hunt/BugHuntCreationUI.tscn")
	if ui == null:
		return
	var coord: Node = ui.coordinator
	await _shot("bh_create_0_launch", ui)
	var names := ["1_config", "2_squad", "3_equipment", "4_review"]
	for step in range(names.size()):
		coord.go_to_step(step)
		await _settle(ui)
		await _shot("bh_create_%s_empty" % names[step], ui)
		var panel: Node = ui.panels[step]
		match step:
			0:
				panel._name_edit.text = "Sweep fixture"
				panel._on_name_changed("Sweep fixture")
				panel._on_generate_regiment()
			1:
				panel._on_generate_squad()
			3:
				panel.refresh()
		if step != 2:  # the equipment step is read-only standard issue
			await _settle(ui)
			await _shot("bh_create_%s_filled" % names[step], ui)
	# build_campaign() registers the campaign with GameState itself.
	coord.build_campaign(coord.state_manager.get_all_data())
	await _unmount(ui)

	# --- Dashboard and its two transfer pages ---
	var dash: Node = await _mount("res://src/ui/screens/bug_hunt/BugHuntDashboard.tscn")
	if dash:
		await _shot("bh_dashboard", dash)
		for pair in [["_on_enlist_pressed", "bh_dash_enlist"],
				["_on_muster_out_pressed", "bh_dash_muster"]]:
			var before: int = dash.get_child_count()
			dash.call(pair[0])
			await _settle(dash)
			if dash.get_child_count() > before:
				var added: Node = dash.get_child(dash.get_child_count() - 1)
				await _shot(pair[1], dash)
				added.queue_free()
				await process_frame
			else:
				print("  SKIP %s: nothing was mounted" % pair[1])
		await _unmount(dash)

	# --- Stage 1 and 2, as the turn controller shows them ---
	var tc: Node = await _mount(BH_TURN)
	if tc == null:
		return
	for _i in range(10):
		await process_frame
	var pm: Node = tc.phase_manager
	if pm == null:
		print("  SKIP turn: no phase manager")
		return
	await _shot("bh_turn_0_special_assignments", tc)
	tc.panels[0]._on_roll_all()
	await _settle(tc)
	await _shot("bh_turn_0_special_assignments_rolled", tc)
	tc._on_advance_pressed()  # the panel's own complete()
	await _settle(tc)
	await _shot("bh_turn_1_%s" % _phase_slug(pm), tc)
	tc.panels[1]._generate_mission()  # the Generate Mission button (support rolls too)
	await _settle(tc)
	await _shot("bh_turn_1_%s_generated" % _phase_slug(pm), tc)

	# The Launch button's own path. Without SceneRouter it stamps the mission and leaves
	# the battle context in temp data exactly as a real launch does, then reports that it
	# could not navigate; NotificationManager is held out too so that report is not drawn
	# over the next capture. Both are put back straight after.
	var held: Array = []
	for name in ["SceneRouter", "NotificationManager"]:
		var n: Node = root.get_node_or_null(name)
		if n:
			root.remove_child(n)
			held.append(n)
	tc.panels[1]._launch_mission()
	for n in held:
		root.add_child(n)
	var gsm: Node = root.get_node_or_null("/root/GameStateManager")
	var ctx: Variant = gsm.get_temp_data("bug_hunt_battle_context") if gsm else null
	var campaign: Resource = tc.campaign
	await _unmount(tc)

	# --- The battle screen in Bug Hunt mode, built from that context ---
	if ctx is Dictionary and not (ctx as Dictionary).is_empty():
		var tb: Node = await _mount("res://src/ui/screens/battle/TacticalBattleUI.tscn")
		if tb:
			await _shot("bh_battle", tb)
			tb._on_tier_selected(1)  # Assisted, from the companion-level chooser
			await _settle(tb)
			await _shot("bh_battle_assisted", tb)
			await _unmount(tb)
	else:
		print("  SKIP bh_battle: the launch left no battle context")
	if gsm:
		gsm.set_temp_data("bug_hunt_battle_context", null)

	# --- Stage 3: the controller is rebuilt on the return, as the router does ---
	var first: Dictionary = {}
	for mc in campaign.main_characters:
		if mc is Dictionary:
			first = mc
			break
	var fallen := {"id": str(first.get("id", first.get("character_id", ""))),
			"name": str(first.get("name", ""))}
	if gsm:
		# TacticalBattleUI's own vocabulary (its played-battle result, :7160-7185).
		gsm.set_temp_data("bug_hunt_battle_result", {
			"victory": true, "won": true, "held_field": true, "rounds_fought": 5,
			"crew_casualties": 1, "crew_casualties_data": [fallen],
			"crew_injuries": 0, "crew_injuries_data": [],
			"enemies_defeated_count": 4, "auto_resolved": false})
	tc = await _mount(BH_TURN)
	if tc == null:
		return
	for _i in range(10):
		await process_frame
	pm = tc.phase_manager
	await _shot("bh_turn_2_%s" % _phase_slug(pm), tc)
	tc.panels[2]._process_post_battle()
	await _settle(tc)
	await _shot("bh_turn_2_%s_processed" % _phase_slug(pm), tc)
	tc._on_advance_pressed()
	await _settle(tc)
	await _shot("bh_turn_complete", tc)
	await _unmount(tc)


## ============================================================================
## BATTLE SIMULATOR
## ============================================================================

## Setup -> battle -> results, with the results screen fed each SHAPE the four
## tactical_battle_completed emit sites produce (played, Record Result form,
## auto-resolve, evacuation). The battle itself is launched through the screen's own
## launch handler, so what is captured is what a player's Launch press builds.
func _simulator() -> void:
	var inst: Node = await _mount("res://src/ui/screens/battle_simulator/BattleSimulatorUI.tscn")
	if inst == null:
		return
	await _shot("sim_01_setup", inst)
	var scroll: ScrollContainer = null
	for n in inst.find_children("*", "ScrollContainer", true, false):
		scroll = n as ScrollContainer
		break
	if scroll:
		scroll.scroll_vertical = 100000
		await _shot("sim_02_setup_bottom", inst)
	var setup_panel: Node = inst.get("_setup_panel")
	var cfg: Dictionary = {}
	if setup_panel and "_current_config" in setup_panel:
		cfg = (setup_panel.get("_current_config") as Dictionary).duplicate()
	inst.call("_on_launch_battle", cfg)
	await _shot("sim_03_battle", inst)
	var shapes: Dictionary = {
		"played": {"victory": true, "won": true, "success": true, "held_field": true,
			"rounds_fought": 5, "crew_casualties": 1, "crew_injuries": 2,
			"crew_casualties_data": [{"name": "A"}],
			"crew_injuries_data": [{"name": "B"}, {"name": "C"}],
			"enemies_defeated_count": 6, "auto_resolved": false,
			"objective_id": "FIGHT_OFF", "objective_met": true},
		"auto": {"victory": false, "won": false, "success": false, "held_field": false,
			"rounds_fought": 3, "crew_casualties": 2, "crew_injuries": 0,
			"crew_casualties_data": [{"name": "A"}, {"name": "B"}],
			"crew_injuries_data": [], "auto_resolved": true},
		"evac": {"victory": false, "won": false, "success": false, "held_field": false,
			"rounds_fought": 2, "crew_casualties": 0, "crew_injuries": 1,
			"crew_injuries_data": [{"name": "A"}]},
	}
	for key in shapes:
		inst.call("_on_battle_completed", shapes[key])
		await _shot("sim_04_results_%s" % key, inst)
	inst.call("_on_play_again")
	await _shot("sim_05_play_again", inst)
	await _unmount(inst)


func _phase_slug(pm: Node) -> String:
	return str(pm.get_phase_name(pm.current_phase)).to_lower().replace(" ", "_") \
			.replace("&", "and").replace("/", "_")
