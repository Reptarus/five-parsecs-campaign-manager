extends GdUnitTestSuite
## Headless PANEL harness for the Bug Hunt parity audit.
##
## Run (gdUnit4 registers autoloads; a --script probe does NOT):
##   godot --headless --path <root> --script addons/gdUnit4/bin/GdUnitCmdTool.gd \
##         -a tests/tools/probe_bug_hunt_panels.gd --ignoreHeadlessMode
##
## WHY THIS EXISTS AND WHY IT IS NOT IN tests/unit/
## `probe_bug_hunt_desk_walk.gd` covered the Bug Hunt DATA and TURN layer, but it is a
## --script SceneTree probe and therefore structurally unable to touch the panels: they
## resolve autoloads, and CLAUDE.md records that such a probe measures a tree its own
## setup never touched. gdUnit4 registers autoloads, so this harness can build the real
## screens.
##
## It is an INSTRUMENT, not a regression suite. Its assertions are deliberately confined
## to facts that must stay true no matter which Bug Hunt defects get fixed -- "the panel
## builds", "the step ran". Everything the audit actually cares about is PRINTED, never
## asserted, because asserting today's behaviour would pin the bugs in place and turn the
## fix sprint red. That is the `reference_a_green_test_can_detect_nothing` trap inverted:
## a test that locks in a defect is worse than no test.
##
## Read the printed block, not the pass count.

const PostBattlePanel := preload("res://src/ui/screens/bug_hunt/panels/BugHuntPostBattlePanel.gd")
const MissionPanel := preload("res://src/ui/screens/bug_hunt/panels/BugHuntMissionPanel.gd")
const AssignmentsPanel := preload("res://src/ui/screens/bug_hunt/panels/SpecialAssignmentsPanel.gd")
const SquadPanel := preload("res://src/ui/screens/bug_hunt/panels/BugHuntSquadPanel.gd")
const ReviewPanel := preload("res://src/ui/screens/bug_hunt/panels/BugHuntReviewPanel.gd")
const ConfigPanel := preload("res://src/ui/screens/bug_hunt/panels/BugHuntConfigPanel.gd")
const EquipmentPanel := preload("res://src/ui/screens/bug_hunt/panels/BugHuntEquipmentPanel.gd")
const TransferPanel := preload("res://src/ui/screens/bug_hunt/panels/CharacterTransferPanel.gd")

const CoreScript := preload("res://src/game/campaign/BugHuntCampaignCore.gd")
const PhaseManagerScript := preload("res://src/core/campaign/BugHuntPhaseManager.gd")
const CharGenScript := preload("res://src/core/character/BugHuntCharacterGeneration.gd")


## The payload TacticalBattleUI ACTUALLY emits for a Bug Hunt battle
## (TacticalBattleUI.gd:6866 result_dict, routed via _on_delegated_battle_completed
## -> temp_data["bug_hunt_battle_result"] -> BugHuntTurnController:400).
## Reproduced key-for-key so the harness measures the real boundary, not a fixture
## invented to match the consumer -- that is the documented
## `reference_a_fixture_that_skips_a_producer_key_hides_a_live_bug` trap.
func _real_battle_result(participant_ids: Array) -> Dictionary:
	return {
		"victory": true,
		"won": true,
		"success": true,
		"held_field": true,
		"objective_id": "bh_probe",
		"objective_met": true,
		"objective_progress": 1,
		"rounds_fought": 5,
		"crew_casualties": 1,
		"crew_injuries": 0,
		"crew_casualties_data": [{"id": participant_ids[0], "name": "Alpha"}],
		"crew_injuries_data": [],
		"crew_participants": participant_ids.duplicate(),
		"defeated_enemies": [],
		"enemies_defeated_count": 4,
		"enemies_remaining": 0,
		"crew_alive": 3,
		"auto_resolved": false,
	}


func _make_campaign(mc_count: int = 4) -> Resource:
	var core: Resource = CoreScript.new()
	core.campaign_name = "Panel Probe"
	var gen = CharGenScript.new()
	var names: Array = []
	for i in range(mc_count):
		names.append("MC%d" % (i + 1))
	var squad: Dictionary = gen.generate_squad(names)
	core.initialize_squad(squad.get("main_characters", []), [])
	core.reputation = 10
	core.start_campaign()
	return core


func _ids(core: Resource) -> Array:
	var out: Array = []
	for mc in core.main_characters:
		out.append(mc.get("id", mc.get("character_id", "")))
	return out


## Depth-first walk collecting every Label's text, so a card's presence can be
## detected by the title the panel actually rendered.
func _all_text(node: Node, out: Array = []) -> Array:
	if node is Label:
		out.append((node as Label).text)
	elif node is Button:
		out.append((node as Button).text)
	for c in node.get_children():
		_all_text(c, out)
	return out


func _buttons(node: Node, out: Array = []) -> Array:
	if node is Button and node is not CheckBox:
		out.append(node)
	for c in node.get_children():
		_buttons(c, out)
	return out


func _checkboxes(node: Node, out: Array = []) -> Array:
	if node is CheckBox:
		out.append(node)
	for c in node.get_children():
		_checkboxes(c, out)
	return out


func _has_card(texts: Array, needle: String) -> bool:
	for t in texts:
		if needle.to_lower() in str(t).to_lower():
			return true
	return false


# ══════════════════════════════════════════════════════════════════════
# 1. Do the panels build at all?
# ══════════════════════════════════════════════════════════════════════

func test_every_bug_hunt_panel_instantiates_and_builds() -> void:
	print("\n=== P1. Panel construction ===")
	var core := _make_campaign()
	var pm = auto_free(PhaseManagerScript.new())
	add_child(pm)
	pm.setup(core)

	var specs: Array = [
		["BugHuntPostBattlePanel", PostBattlePanel],
		["BugHuntMissionPanel", MissionPanel],
		["SpecialAssignmentsPanel", AssignmentsPanel],
		["BugHuntSquadPanel", SquadPanel],
		["BugHuntReviewPanel", ReviewPanel],
		["BugHuntConfigPanel", ConfigPanel],
		["BugHuntEquipmentPanel", EquipmentPanel],
		["CharacterTransferPanel", TransferPanel],
	]

	var built := 0
	for spec in specs:
		var panel_name: String = spec[0]
		var script: GDScript = spec[1]
		var p: Control = auto_free(script.new())
		add_child(p)
		if p.has_method("set_campaign"):
			p.set_campaign(core)
		if p.has_method("set_phase_manager"):
			p.set_phase_manager(pm)
		if p.has_method("refresh"):
			p.refresh()
		var texts: Array = _all_text(p)
		var kids: int = p.get_child_count()
		print("   %-26s children=%-3d text nodes=%-3d" % [panel_name, kids, texts.size()])
		built += 1

	# The only invariant worth pinning: they all construct. Everything else is printed.
	assert_int(built).is_equal(specs.size())


# ══════════════════════════════════════════════════════════════════════
# 2. The battle -> post-battle key boundary
# ══════════════════════════════════════════════════════════════════════

func test_battle_result_key_boundary() -> void:
	print("\n=== P2. What the post-battle panel reads vs what the battle emits ===")
	var core := _make_campaign()
	var ids := _ids(core)
	var real := _real_battle_result(ids)

	var consumed := ["casualties", "objectives_completed", "lost_marines"]
	print("   TacticalBattleUI emits these keys:")
	var ks: Array = real.keys()
	ks.sort()
	print("      " + str(ks))
	print("   BugHuntPostBattlePanel reads:")
	for k in consumed:
		print("      %-22s present in the real result? %s   -> resolves to %s"
			% [k, str(real.has(k)), str(real.get(k, "0 / [] (silent default)"))])

	assert_bool(real.has("crew_casualties_data")).is_true()


# ══════════════════════════════════════════════════════════════════════
# 3. Drive the post-battle panel with the REAL result
# ══════════════════════════════════════════════════════════════════════

func test_post_battle_panel_driven_with_the_real_result() -> void:
	print("\n=== P3. Post-battle panel, driven with the real battle payload ===")
	var core := _make_campaign()
	var ids := _ids(core)

	var panel: Control = auto_free(PostBattlePanel.new())
	add_child(panel)
	panel.set_campaign(core)
	panel.set_battle_results(_real_battle_result(ids))
	panel.refresh()
	panel._process_post_battle()

	var texts: Array = _all_text(panel)
	print("   Court Martial card rendered? %s   <-- fires when objectives_completed == 0"
		% str(_has_card(texts, "Court Martial")))
	print("   'ZERO objectives completed' shown? %s" % str(_has_card(texts, "ZERO objectives")))

	var res: Dictionary = panel._results
	print("   _results.op_progress_modifier = %s   <-- pins the win condition"
		% str(res.get("op_progress_modifier")))
	print("   _results.mustered_out         = %s" % str(res.get("mustered_out")))
	print("   _results.casualties_processed = %d entry/entries"
		% (res.get("casualties_processed", []) as Array).size())
	print("   _results.reputation_change    = %s" % str(res.get("reputation_change")))

	# Casualty step: the real result names a casualty in crew_casualties_data,
	# but the panel reads `casualties`. Report which branch actually ran.
	print("   'No casualties this mission' shown? %s   (the real result HAD 1 casualty)"
		% str(_has_card(texts, "No casualties this mission")))

	assert_bool(res.has("op_progress_modifier")).is_true()


func test_court_martial_fires_on_every_mission() -> void:
	print("\n=== P4. How often does Court Martial fire? (20 runs, real payload) ===")
	var fired := 0
	var guilty := 0
	for i in range(20):
		var core := _make_campaign()
		var panel: Control = auto_free(PostBattlePanel.new())
		add_child(panel)
		panel.set_campaign(core)
		panel.set_battle_results(_real_battle_result(_ids(core)))
		panel.refresh()
		panel._process_post_battle()
		var texts: Array = _all_text(panel)
		if _has_card(texts, "Court Martial"):
			fired += 1
		# "guilty" is a SUBSTRING of "Not guilty" -- the first version of this probe
		# reported GUILTY 20/20 for a 1-in-6 roll. Match the guilty branch's exact
		# wording instead. A detector that cannot distinguish the two outcomes is the
		# `reference_a_diagnostic_that_cannot_disagree` trap.
		if _has_card(texts, "GUILTY! Squad leader removed"):
			guilty += 1
			# On GUILTY the panel says the leader is removed. Is anyone actually removed?
			print("      run %-2d GUILTY -> mustered_out=%s  (removal is a COMMENT at :642)"
				% [i, str(panel._results.get("mustered_out"))])
		panel.queue_free()
	print("   Court Martial card appeared in %d of 20 runs" % fired)
	print("   GUILTY (D6 == 1) in %d of 20 runs" % guilty)
	assert_int(fired).is_between(0, 20)


# ══════════════════════════════════════════════════════════════════════
# 4. completed_missions_count: how many increments per mission?
# ══════════════════════════════════════════════════════════════════════

func test_completed_missions_increments_per_mission() -> void:
	print("\n=== P5. completed_missions_count per ONE mission ===")
	var core := _make_campaign()
	var ids := _ids(core)
	var before: int = core.main_characters[0].get("completed_missions_count", 0)

	var panel: Control = auto_free(PostBattlePanel.new())
	add_child(panel)
	panel.set_campaign(core)
	panel.set_battle_results(_real_battle_result(ids))
	panel.refresh()
	panel._process_post_battle()
	var after_panel: int = core.main_characters[0].get("completed_missions_count", 0)

	# Now the phase manager applies the same result, as the real flow does.
	var pm = auto_free(PhaseManagerScript.new())
	add_child(pm)
	pm.setup(core)
	pm._apply_post_battle_results(panel._results)
	var after_pm: int = core.main_characters[0].get("completed_missions_count", 0)

	print("   before                        = %d" % before)
	print("   after panel _update_completed  = %d" % after_panel)
	print("   after phase-manager apply      = %d   <-- book says +1 per mission (p.203)"
		% after_pm)
	print("   xp_awards in results: %s" % str(panel._results.get("xp_awards")))
	assert_int(after_pm).is_greater_equal(after_panel)


# ══════════════════════════════════════════════════════════════════════
# 5. Muster-out past 15
# ══════════════════════════════════════════════════════════════════════

func test_muster_out_for_a_15_mission_veteran() -> void:
	print("\n=== P6. A veteran at 15 completed missions ===")
	for tally in [14, 15, 16]:
		var core := _make_campaign(3)
		for mc in core.main_characters:
			mc["completed_missions_count"] = tally
		var panel: Control = auto_free(PostBattlePanel.new())
		add_child(panel)
		panel.set_campaign(core)
		panel.set_battle_results(_real_battle_result(_ids(core)))
		panel.refresh()
		panel._process_post_battle()
		var texts: Array = _all_text(panel)
		var lines: Array = []
		for t in texts:
			var s := str(t)
			if "missions" in s and ("MUSTER" in s.to_upper() or "Stays" in s or "No muster" in s or "Automatic" in s):
				lines.append(s)
		var tally_now: int = core.main_characters[0].get("completed_missions_count", 0)
		print("   tally in=%d -> after step 2 the stored tally is %d, step 3 then checks %d"
			% [tally, tally_now, tally_now + 1])
		print("      mustered_out=%s" % str(panel._results.get("mustered_out")))
		if lines.is_empty():
			print("      NO muster line rendered at all -- the check was SKIPPED")
		else:
			for l in lines:
				print("      " + str(l))
		panel.queue_free()
	assert_bool(true).is_true()


# ══════════════════════════════════════════════════════════════════════
# 6. XP advancement: can a character overspend?
# ══════════════════════════════════════════════════════════════════════

func test_xp_advancement_affordability() -> void:
	print("\n=== P7. XP advancement: press every affordable button in one pass ===")
	var core := _make_campaign(3)
	# 9 XP affords exactly ONE 8-XP advance (Compendium p.204).
	for mc in core.main_characters:
		mc["xp"] = 9
		mc["reactions"] = 1
		mc["combat_skill"] = 0
		mc["toughness"] = 3
		mc["speed"] = 4
		mc["savvy"] = 0

	var panel: Control = auto_free(PostBattlePanel.new())
	add_child(panel)
	panel.set_campaign(core)
	panel.set_battle_results(_real_battle_result(_ids(core)))
	panel.refresh()
	panel._process_post_battle()

	var advance_btns: Array = []
	for b in _buttons(panel):
		var t := (b as Button).text
		if "XP)" in t and "→" in t:
			advance_btns.append(b)
	print("   advance buttons offered: %d" % advance_btns.size())

	var start_xp: int = core.main_characters[0].get("xp", 0)
	var pressed := 0
	for b in advance_btns:
		var btn := b as Button
		if btn.disabled:
			continue
		var label := btn.text
		btn.emit_signal("pressed")
		pressed += 1
		print("      pressed %-40s -> MC1 xp now %s"
			% [label.strip_edges(), str(core.main_characters[0].get("xp"))])
		if pressed >= 4:
			break
	print("   MC1 xp: %d -> %s   (started with 9; each advance costs 6 or 8)"
		% [start_xp, str(core.main_characters[0].get("xp"))])
	assert_int(pressed).is_greater_equal(0)


# ══════════════════════════════════════════════════════════════════════
# 7. Mission panel: escalation priority + the Hand Cannon lambda
# ══════════════════════════════════════════════════════════════════════

func test_campaign_escalation_priority() -> void:
	print("\n=== P8. Campaign Escalation priority (book p.187: 1-1-2-2-3-4-5-6) ===")
	var core := _make_campaign()
	core.use_campaign_escalation = true
	var panel: Control = auto_free(MissionPanel.new())
	add_child(panel)
	panel.set_campaign(core)
	var seq: Array = []
	for turn in range(1, 9):
		seq.append(panel._calculate_priority(turn, "mess_me_up"))
	print("   escalation ON, turns 1-8 -> %s" % str(seq))
	print("   book p.187               -> [1, 1, 2, 2, 3, 4, 5, 6]")
	var jkey: Dictionary = panel._missions_data
	print("   JSON key the code asks for: 'campaign_escalation'        present? %s"
		% str(jkey.has("campaign_escalation")))
	print("   JSON key that actually exists: 'campaign_escalation_option' present? %s"
		% str(jkey.has("campaign_escalation_option")))
	assert_int(seq.size()).is_equal(8)


func test_hand_cannon_is_limited_to_one_main_character() -> void:
	print("\n=== P9. Hand Cannon swap: 'One MC only' (p.187) ===")
	var core := _make_campaign(4)
	var panel: Control = auto_free(MissionPanel.new())
	add_child(panel)
	panel.set_campaign(core)
	panel.set_phase_manager(null)
	panel.refresh()
	# refresh() only CLEARS; the loadout section (and therefore the Hand Cannon
	# checkboxes) is built by _generate_mission(), gated on _mission_generated.
	# The first version of this probe stopped at refresh() and found 0 checkboxes,
	# which reads exactly like "the control does not exist" -- a probe that never
	# delivered its own stimulus.
	panel._generate_mission()

	var boxes: Array = []
	for cb in _checkboxes(panel):
		if "hand cannon" in (cb as CheckBox).text.to_lower():
			boxes.append(cb)
	print("   Hand Cannon checkboxes found: %d" % boxes.size())
	var accepted := 0
	for cb in boxes:
		var box := cb as CheckBox
		box.button_pressed = true
		box.emit_signal("toggled", true)
		if box.button_pressed:
			accepted += 1
	print("   checkboxes that STAYED pressed: %d   <-- book allows exactly 1" % accepted)
	assert_int(accepted).is_greater_equal(0)
