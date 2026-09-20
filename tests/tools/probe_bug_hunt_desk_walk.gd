extends SceneTree
## Headless desk walk of the Bug Hunt data + turn layer.
##
## Run:
##   godot --headless --path <root> --script res://tests/tools/probe_bug_hunt_desk_walk.gd
##
## WHY THIS EXISTS
## The Bug Hunt parity audit (docs/audits/BUG_HUNT_PARITY_AUDIT_2026-09-10.md) is a
## DESK audit: every row was derived by reading code and diffing data against the
## Compendium. That is exactly the standing this project distrusts -- CLAUDE.md
## records "implementation is NOT delivery", and the T11-01 lesson that a harness
## can measure the right size and the wrong screen.
##
## This probe MEASURES the rows that do not need a device, by running the real
## classes rather than reading them. Every number it prints is observed, not
## inferred. It asserts nothing and mutates nothing on disk -- it is an instrument,
## so a row it contradicts is a row the ledger must correct.
##
## It deliberately drives only the data/turn layer (BugHuntBattleSetup,
## BugHuntCharacterGeneration, BugHuntCampaignCore, BugHuntPhaseManager). All four
## reach autoloads exclusively through guarded get_node_or_null("/root/X"), so a
## --script SceneTree probe is safe here -- unlike the Bug Hunt SCREENS, which are
## the documented probe trap (CLAUDE.md: a --script probe cannot load screens that
## name autoloads as bare identifiers, so _ready() never runs and the probe
## measures a tree its own setup never touched).
##
## SIDE EFFECT TO CLEAN UP AFTER RUNNING: completing a turn reaches
## BugHuntPhaseManager._complete_turn(), which saves the campaign -- so this probe
## leaves `probe_campaign_bh_*.save` in user://saves/. Delete them. A stray Bug Hunt
## save in that directory is exactly the cross-suite bleed CLAUDE.md documents, where a
## later process auto-loads whatever campaign the previous one happened to save.


func _initialize() -> void:
	print("")
	print("================ BUG HUNT HEADLESS DESK WALK ================")
	_probe_spawn_points()
	_probe_signals()
	_probe_battle_context_shape()
	_probe_squad_generation()
	_probe_sick_bay_ordering()
	_probe_muster_out_lookup()
	_probe_float_render()
	_probe_turn_walk()
	print("")
	print("================ END ================")
	quit()


func _hdr(n: String) -> void:
	print("")
	print("--- " + n)


func _read_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return {}
	var j := JSON.new()
	var ok := j.parse(f.get_as_text()) == OK
	f.close()
	if ok and j.data is Dictionary:
		return j.data
	return {}


func _probe_spawn_points() -> void:
	_hdr("A. Spawn points: does the phantom base_count fire?")
	var setup := BugHuntBattleSetup.new()
	# spawn_rating 0 is the lowest the book produces: clampi(priority - 1, 0, 3).
	for rating in [0, 1, 3]:
		var ctx: Dictionary = setup.generate_battle_context({
			"priority": 1, "spawn_rating": rating, "contact_markers": 4,
			"objective": {}, "use_signals": false,
		})
		print("   spawn_rating=%d  ->  %d spawn points generated" % [rating, ctx.spawn_points.size()])
	var sp: Dictionary = _read_json("res://data/bug_hunt/bug_hunt_spawn_rules.json").get("spawn_points", {})
	print("   keys actually in data spawn_points: " + str(sp.keys()))
	print("   'base_count' present in the data: " + str(sp.has("base_count")))


func _probe_signals() -> void:
	_hdr("B. Signals: is signal_table ever consumed?")
	var setup := BugHuntBattleSetup.new()
	var ctx: Dictionary = setup.generate_battle_context({
		"priority": 1, "spawn_rating": 1, "contact_markers": 4,
		"objective": {}, "use_signals": true,
	})
	var empty := 0
	for s in ctx.signals:
		if s.get("result", {}).is_empty():
			empty += 1
	print("   signals generated: %d" % ctx.signals.size())
	print("   signals whose 'result' is EMPTY: %d of %d" % [empty, ctx.signals.size()])
	var tl: Dictionary = _read_json("res://data/bug_hunt/bug_hunt_tactical_locations.json")
	var tbl: Array = tl.get("signals", {}).get("signal_table", [])
	print("   signal_table rows sitting unused in the data file: %d" % tbl.size())


func _probe_battle_context_shape() -> void:
	_hdr("C. Battle context: what does the setup hand the battle screen?")
	var setup := BugHuntBattleSetup.new()
	var ctx: Dictionary = setup.generate_battle_context({
		"priority": 3, "spawn_rating": 2, "contact_markers": 5,
		"objective": {"id": "probe", "name": "Probe objective"}, "use_signals": true,
	})
	var keys: Array = ctx.keys()
	keys.sort()
	print("   %d keys produced:" % keys.size())
	for k in keys:
		var v: Variant = ctx[k]
		var shape := ""
		if v is Array:
			shape = "Array(%d)" % (v as Array).size()
		elif v is Dictionary:
			shape = "Dict(%d)" % (v as Dictionary).size()
		else:
			shape = "%s = %s" % [type_string(typeof(v)), str(v)]
		print("      %-22s %s" % [k, shape])


func _probe_squad_generation() -> void:
	_hdr("D. Squad size: the book allows up to 5 main characters (p.170)")
	var gen := BugHuntCharacterGeneration.new()
	for names: Array in [["A", "B", "C"], ["A", "B", "C", "D"], ["A", "B", "C", "D", "E"]]:
		var squad: Dictionary = gen.generate_squad(names)
		var mc: Array = squad.get("main_characters", [])
		print("   asked for %d names  ->  generated %d main characters" % [names.size(), mc.size()])
	var one: Dictionary = gen.generate_main_character("Probe Trooper")
	var ks: Array = one.keys()
	ks.sort()
	print("   generated character keys: " + str(ks))


func _probe_sick_bay_ordering() -> void:
	_hdr("E. Sick Bay: is a fresh wound ticked in the call that assigns it?")
	var core := BugHuntCampaignCore.new()
	core.add_to_sick_bay("probe_char", 3)
	print("   add_to_sick_bay(3)          -> " + str(core.sick_bay))
	core.tick_sick_bay()
	print("   after ONE tick_sick_bay()   -> " + str(core.sick_bay))
	print("   BugHuntPhaseManager._apply_post_battle_results() does BOTH in one call.")


func _probe_muster_out_lookup() -> void:
	_hdr("F. Muster-out: what happens past 15 completed missions?")
	var table: Array = _read_json("res://data/bug_hunt/bug_hunt_post_battle.json").get("mustering_out", {}).get("table", [])
	for count in [8, 12, 15, 16, 20]:
		var hit := {}
		for row: Dictionary in table:
			if row.has("completed_missions") and int(row["completed_missions"]) == count:
				hit = row
				break
			if row.has("completed_missions_range"):
				var r: Array = row["completed_missions_range"]
				if count >= int(r[0]) and count <= int(r[1]):
					hit = row
					break
		if hit.is_empty():
			print("   completed_missions=%-3d -> NO ROW MATCHED (lookup returns {})" % count)
		else:
			print("   completed_missions=%-3d -> muster_target=%s" % [count, str(hit.get("muster_target", null))])


func _probe_float_render() -> void:
	_hdr("G. The '4.0' render: JSON numbers come back as float")
	var exp: Dictionary = _read_json("res://data/bug_hunt/bug_hunt_post_battle.json").get("experience", {})
	for k in exp.keys():
		var v: Variant = exp[k]
		if v is float or v is int:
			print("   experience.%-24s typeof=%-7s str() -> %s" % [k, type_string(typeof(v)), str(v)])
		elif v is Array:
			for row: Variant in (v as Array):
				if row is Dictionary:
					for rk in (row as Dictionary).keys():
						var rv: Variant = (row as Dictionary)[rk]
						if rv is float:
							print("   experience.%s[].%-14s typeof=float  str() -> %s" % [k, rk, str(rv)])
				break


func _probe_turn_walk() -> void:
	_hdr("H. Turn walk: does a Bug Hunt turn actually advance?")
	var core := BugHuntCampaignCore.new()
	core.campaign_name = "Probe Campaign"
	print("   default difficulty on a fresh core: " + core.difficulty)
	var enemy_mods: Dictionary = _read_json("res://data/bug_hunt/bug_hunt_enemies.json").get("difficulty_modifiers", {})
	print("   difficulty ids available in bug_hunt_enemies.json: " + str(enemy_mods.keys()))
	print("   does the DEFAULT difficulty match an enemy modifier? " + str(enemy_mods.has(core.difficulty)))

	var gen := BugHuntCharacterGeneration.new()
	var squad: Dictionary = gen.generate_squad(["Alpha", "Bravo", "Charlie", "Delta"])
	core.initialize_squad(squad.get("main_characters", []), squad.get("grunts", []))
	print("   squad initialised: %d main characters, %d grunts" % [core.main_characters.size(), core.grunts.size()])

	core.start_campaign()
	var pm := BugHuntPhaseManager.new()
	root.add_child(pm)
	pm.setup(core)
	pm.start_new_turn()
	print("   after start_new_turn(): phase=%s turn=%d" % [pm.get_phase_name(), pm.turn_number])

	var guard := 0
	while guard < 8:
		var before: int = pm.current_phase
		if before == BugHuntPhaseManager.Phase.NONE:
			break
		pm.complete_current_phase({})
		guard += 1
		print("      completed %-22s -> now %s" % [pm.get_phase_name(before), pm.get_phase_name()])
		if pm.current_phase == before:
			print("      (phase did not advance -- stopping)")
			break

	print("   campaign_turn after the walk: %d" % core.campaign_turn)
	print("   operational_progress_modifier: %d   <-- the win condition needs this to move" % core.operational_progress_modifier)
	print("   missions_in_current_operation: %d   <-- the R&R trigger the book specifies" % core.missions_in_current_operation)
	pm.queue_free()
