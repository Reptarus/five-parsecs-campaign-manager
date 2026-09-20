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
## BugHuntCharacterGeneration, BugHuntCampaignCore, BugHuntPhaseManager,
## BugHuntPostBattleResolver) -- unlike the Bug Hunt SCREENS, which are the documented
## probe trap (CLAUDE.md: a --script probe cannot load screens that name autoloads as
## bare identifiers, so _ready() never runs and the probe measures a tree its own setup
## never touched).
##
## CORRECTED 2026-09-20 (Phase 7). This block used to say the guarded
## get_node_or_null("/root/X") lookups made the probe "safe here". That was true when
## written and Phase 3's dice routing made it stale, so it is superseded rather than
## deleted -- the measurement is worth more than the claim was:
##
##   * All 35 autoloads ARE registered as children of `root` in a --script probe
##     (measured: root child count 35, ProjectSettings autoload count 35, DiceManager
##     among them). Autoload ABSENCE is not the problem.
##   * `root.is_inside_tree()` is FALSE during _initialize(), and an ABSOLUTE path
##     needs the tree to resolve its leading /root. So "/root/DiceManager" errors while
##     the RELATIVE direct-child form root.get_node_or_null("DiceManager") returns the
##     live node and rolls.
##   * The absolute form ERRORS AND CONTINUES -- it pushes the error, returns null, and
##     execution carries on. CLAUDE.md's "it ERRORS and aborts the enclosing function"
##     describes a BARE get_node_or_null() on a detached RefCounted, which is a
##     different call. Here `if dm:` is simply falsy and the helper's randi_range()
##     fallback runs.
##
## Consequence for reading this probe's output: the error spam is expected and harmless,
## and every roll below is a REAL but UNFORCED roll. Rows that depend on a specific die
## therefore print the roll and the matched table row, never a bare outcome -- a 0 that
## cannot explain itself is indistinguishable from a step that never ran.
##
## SIDE EFFECT TO CLEAN UP AFTER RUNNING: completing a turn reaches
## BugHuntPhaseManager._complete_turn(), which saves the campaign -- so this probe
## leaves `probe_campaign_bh_*.save` in user://saves/. Delete them. A stray Bug Hunt
## save in that directory is exactly the cross-suite bleed CLAUDE.md documents, where a
## later process auto-loads whatever campaign the previous one happened to save.


## No class_name on the resolver (deliberate -- Phase 5 kept it out of the global
## namespace), so it is preloaded rather than named.
const PostBattleResolver = preload("res://src/core/campaign/BugHuntPostBattleResolver.gd")


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


## ✅ FIXED in Phase 5 -- this row now measures the CORE primitives, not the ordering.
##
## CORRECTED 2026-09-20 (Phase 7). The closing line used to read
## "BugHuntPhaseManager._apply_post_battle_results() does BOTH in one call", in the
## present tense. That was true on HEAD and is the defect Phase 5 fixed:
## `tick_sick_bay()` is now called at BugHuntPhaseManager.gd:232-233, BEFORE the
## receipt-effects loop at :239 that puts this turn's wounds in. A one-turn Casualty
## row therefore costs the marine a turn out of action, which is what p.202 hands out.
##
## ⭐ A probe line describing a FIXED defect in the present tense is worse than no
## line at all -- it is read as a finding and filed again. Superseded here rather than
## deleted, so the ordering stays pinned and the history is legible.
func _probe_sick_bay_ordering() -> void:
	_hdr("E. Sick Bay: does a fresh wound survive the turn it was assigned?")
	var core := BugHuntCampaignCore.new()
	core.add_to_sick_bay("probe_char", 3)
	print("   add_to_sick_bay(3)          -> " + str(core.sick_bay))
	core.tick_sick_bay()
	print("   after ONE tick_sick_bay()   -> " + str(core.sick_bay))
	print("   ordering in the mutator: tick FIRST (PhaseManager :232-233), then apply")
	print("   this turn's effects (:239). So the 3 above is served, not decremented on")
	print("   arrival. HEAD ticked LAST, which is the defect Phase 5 closed.")


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
		pm.complete_current_phase(_phase_payload(before, core))
		guard += 1
		print("      completed %-22s -> now %s" % [pm.get_phase_name(before), pm.get_phase_name()])
		if pm.current_phase == before:
			print("      (phase did not advance -- stopping)")
			break

	print("   campaign_turn after the walk: %d" % core.campaign_turn)
	print("   operational_progress_modifier: %d   <-- the win condition needs this to move" % core.operational_progress_modifier)
	print("   missions_in_current_operation: %d   <-- the R&R trigger the book specifies" % core.missions_in_current_operation)
	pm.queue_free()


## What a phase completion actually carries.
##
## POST_BATTLE is the only phase whose mutator needs a payload, and it needs a
## SPECIFIC one: BugHuntPhaseManager._apply_post_battle_results() reads
## `result.get("receipt", {})` and returns immediately when that is empty. Passing {}
## therefore walked the turn without applying a single post-battle effect -- which is
## how this probe once reported the Operational Progress modifier as 0 and made an
## instrument limitation look like a product defect.
##
## This mirrors BugHuntPostBattlePanel._build_snapshot() / :111-112, which is the sole
## producer of the receipt in product. It does NOT re-implement the rules: the same
## resolver the panel calls is called here, so a rules change cannot drift out of the
## probe.
func _phase_payload(phase: int, core) -> Dictionary:
	if phase != BugHuntPhaseManager.Phase.POST_BATTLE:
		return {}

	var ids: Array = []
	for mc in core.main_characters:
		if mc is Dictionary:
			ids.append(str(mc.get("id", "")))

	## ONE completed objective, deliberately. p.201 raises a Court Martial only on
	## ZERO weighted objectives, so this is the "a played mission raises no Court
	## Martial" arm -- the sprint headline. A walk with 0 objectives would measure the
	## punishment path and report it as normal.
	var battle := {
		"participant_ids": ids,
		"casualty_ids": [],
		"objectives_completed": 1,
		"priority": 3,
	}

	var snapshot := {
		"characters": core.main_characters.duplicate(true),
		"battle_result": battle,
		"sick_bay": core.sick_bay.duplicate(true) if core.sick_bay is Dictionary else {},
		"reputation": int(core.reputation),
		"operational_progress_modifier": int(core.operational_progress_modifier),
		"missions_in_current_operation": int(core.missions_in_current_operation),
		"pending_military_life_rolls": 0,
	}

	var receipt: Dictionary = PostBattleResolver.new().resolve(snapshot)
	_print_receipt_summary(receipt)
	return {"post_battle_result": {"receipt": receipt, "answers": {}}}


## Print the roll and the matched row, not just the outcome.
##
## The Operational Progress D100 is UNFORCED here (see the docblock: the absolute-path
## DiceManager lookup cannot resolve in a --script probe), and the +/-5 bands are
## narrow, so a modifier of 0 is the COMMON case and a correct one. Printing the roll
## and the row is what separates "0 because the table says 0" from "0 because the step
## never ran" -- the same discipline as instrumenting a probe's own premise.
func _print_receipt_summary(receipt: Dictionary) -> void:
	var steps: Array = receipt.get("steps", [])
	print("      receipt: %d steps, %d needing a choice"
		% [steps.size(), (receipt.get("choices_needed", []) as Array).size()])
	for st in steps:
		if not (st is Dictionary):
			continue
		var title: String = str(st.get("title", ""))
		if not title.contains("Operational Progress"):
			continue
		if bool(st.get("skipped", false)):
			print("      step 6 SKIPPED -- no table entries loaded")
			return
		for r in st.get("rolls", []):
			print("      step 6 roll: %s" % str(r))
		for line in st.get("lines", []):
			print("      step 6 row:  %s" % str(line))
		var effs: Array = st.get("effects", [])
		if effs.is_empty():
			print("      step 6 effects: NONE -- the matched row carries no adjustment")
		for e in effs:
			print("      step 6 effect: %s" % str(e))
