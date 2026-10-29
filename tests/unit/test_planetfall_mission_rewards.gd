extends GdUnitTestSuite

## Planetfall mission Rewards (pp.115-133), the Pitched Battle's Campaign Consequences
## (p.127), Alien Artifacts (pp.135-136) and the once-per-turn Augmentation (p.105).
##
## ⚠ Before 2026-10-28 none of these reached the campaign. `objectives_completed` had no
## producer, so every objective-based Campaign Factor read 0 on a real battle return; the
## Science, Patrol, Hunt and Delve rewards were printed in the debrief and applied by
## nothing; a lost Pitched Battle applied p.62's Raid damage, never the p.127 table; and
## one Augmentation purchase locked the shop for the rest of the campaign.
##
## Every case drives the REAL path: stamp -> battle result -> debrief -> Step 12, and
## asserts campaign state, never a receipt the test built itself.

const CoreScript = preload("res://src/game/campaign/PlanetfallCampaignCore.gd")
const PMScript = preload("res://src/core/campaign/PlanetfallPhaseManager.gd")
const PostBattlePanel = preload("res://src/ui/screens/planetfall/panels/PlanetfallPostBattlePanel.gd")
const TacticalBattleScene := preload("res://src/ui/screens/battle/TacticalBattleUI.tscn")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")

var _user_state: Dictionary
var _saved_campaign: Variant
var _dm: Node


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()
	var gs := get_tree().root.get_node_or_null("/root/GameState")
	_saved_campaign = gs.current_campaign if gs else null
	_dm = get_tree().root.get_node_or_null("/root/DiceManager")


func after_test() -> void:
	if _dm != null:
		_dm.clear_forced_results()
	var gs := get_tree().root.get_node_or_null("/root/GameState")
	if gs:
		gs.current_campaign = _saved_campaign
	SaveDirGuard.restore(_user_state)


func _core() -> Resource:
	var core = CoreScript.new()
	core.colony_name = "Probe"
	core.game_phase = "active"
	core.campaign_turn = 3
	core.grunts = 10
	core.colony_morale = 0
	core.roster = [
		{"id": "c1", "name": "Ash", "class": "trooper", "xp": 0},
		{"id": "c2", "name": "Kip", "class": "scientist", "xp": 0},
	]
	return core


func _pm(core: Resource) -> Node:
	var pm: Node = PMScript.new()
	add_child(pm)
	auto_free(pm)
	pm.setup(core)
	return pm


func _force(key: String, values: Array) -> void:
	for v in values:
		_dm.queue_forced_result(key, v)


## One mission through Step 12: the stamp, what the battle screen returned, the debrief.
func _step12(core: Resource, mission_id: String, won: bool, objectives: int,
		extra: Dictionary = {}) -> Dictionary:
	var pm := _pm(core)
	pm.stamp_mission({"id": mission_id, "mission_name": mission_id.capitalize(),
		"opposition_type": "tactical", "tactical_enemy_index": -1, "grunts_deployed": 0,
		"deployed_ids": ["c1", "c2"]})
	var result := {"won": won, "victory": won, "crew_participants": core.roster.duplicate(true),
		"crew_injuries_data": [], "crew_casualties_data": []}
	result.merge(extra, true)
	pm.set_battle_result(result)
	pm.apply_battle_debrief({"objectives_completed": objectives})
	return pm.resolve_intel_step()


func _text(receipt: Dictionary) -> String:
	return "\n".join(receipt.get("lines", []).map(func(x): return str(x)))


# ── The objective count reaches the result (the producer that was missing) ─────────

func test_the_debrief_objective_count_reaches_the_battle_result() -> void:
	var core := _core()
	var pm := _pm(core)
	pm.stamp_mission({"id": "science", "deployed_ids": ["c1"]})
	pm.set_battle_result({"won": true, "crew_participants": [], "crew_injuries_data": []})
	pm.apply_battle_debrief({"objectives_completed": 3})
	assert_int(int(pm.get_battle_result().get("objectives_completed", -1))) \
		.override_failure_message("nothing produced objectives_completed: every objective "
			+ "factor read 0").is_equal(3)


func test_the_debrief_asks_a_mission_its_objectives() -> void:
	var core := _core()
	var pm := _pm(core)
	pm.stamp_mission({"id": "delve", "deployed_ids": ["c1"]})
	pm.set_battle_result({"won": true, "crew_participants": [], "crew_injuries_data": []})
	var panel: Control = auto_free(PostBattlePanel.new())
	add_child(panel)
	panel.set_campaign(core)
	panel.set_phase_manager(pm)
	panel.set_battle_results(pm.get_battle_result())
	panel._build_debrief()
	assert_object(panel._objective_spin).override_failure_message(
		"the debrief must ask the Delve whether the Artifact was found").is_not_null()
	assert_int(int(panel._objective_spin.max_value)).is_equal(1)
	panel._objective_spin.value = 1
	assert_int(int(panel._collect_debrief().get("objectives_completed", -1))).is_equal(1)


# ── p.119 Science ──────────────────────────────────────────────────────────────

func test_science_samples_roll_for_research_and_mission_data() -> void:
	var core := _core()
	_force("Planetfall Science Sample", [6, 6, 2])
	var r := _step12(core, "science", true, 3)
	assert_int(int(core.research_data.get("current_rp", 0))) \
		.override_failure_message("p.119: each 4-6 is 1 RP; two 6s and a 2 make 2") \
		.is_equal(2)
	assert_str(_text(r)).contains("6, 6, 2")
	assert_str(_text(r)).contains("Mission Data")


func test_a_single_six_earns_no_mission_data() -> void:
	var core := _core()
	_force("Planetfall Science Sample", [6, 4])
	var r := _step12(core, "science", true, 2)
	assert_int(int(core.research_data.get("current_rp", 0))).is_equal(2)
	assert_str(_text(r)).override_failure_message(
		"p.119: Mission Data needs MORE than a single 6").not_contains("more than one 6")


# ── p.122 Patrol ───────────────────────────────────────────────────────────────

func test_a_patrol_objective_raises_colony_morale() -> void:
	var core := _core()
	_step12(core, "patrol", false, 1)
	assert_int(int(core.colony_morale)) \
		.override_failure_message("p.122: 1+ Objective raises Colony Morale by 1").is_equal(1)


func test_a_patrol_with_no_objective_leaves_morale() -> void:
	var core := _core()
	_step12(core, "patrol", true, 0)
	assert_int(int(core.colony_morale)).is_equal(0)


# ── p.121 Hunt -> p.92 Bio-Analysis ────────────────────────────────────────────

func test_two_hunt_samples_authorize_bio_analysis_of_the_creature_met() -> void:
	var core := _core()
	core.lifeform_table = [{}, {}, {"name": "Glasswing", "speed": 6, "kp": 1}]
	_step12(core, "hunt", true, 2, {"lifeform_slot": 2})
	assert_bool(bool(core.lifeform_table[2].get("sampled", false))) \
		.override_failure_message("p.121: two samples authorize Bio-Analysis (p.92)") \
		.is_true()


func test_one_hunt_sample_authorizes_nothing() -> void:
	var core := _core()
	core.lifeform_table = [{}, {}, {"name": "Glasswing", "speed": 6, "kp": 1}]
	_step12(core, "hunt", true, 1, {"lifeform_slot": 2})
	assert_bool(bool(core.lifeform_table[2].get("sampled", false))).is_false()


## The battle screen is the only thing that knows which encounter entry the mission met.
func test_the_battle_screen_returns_the_lifeform_the_mission_met() -> void:
	var core := _core()
	var gs := get_tree().root.get_node_or_null("/root/GameState")
	gs.current_campaign = core
	var ui: Control = auto_free(TacticalBattleScene.instantiate())
	add_child(ui)
	await get_tree().process_frame
	ui.initialize_battle([], [], {"battle_mode": "planetfall", "title": "Hunt",
		"opposition_type": "lifeforms"})
	ui._planetfall_encounters["mission_slot"] = 4
	ui._result_temp_key = ""
	ui._return_screen = ""
	var result := {"won": true}
	ui._on_delegated_battle_completed(result)
	assert_int(int(result.get("lifeform_slot", -1))).override_failure_message(
		"p.121: the Hunt sample is of THIS mission's creature").is_equal(4)


# ── p.133 Delve, pp.135-136 Artifacts ──────────────────────────────────────────

func test_a_delve_acquires_an_artifact_and_its_points() -> void:
	var core := _core()
	var rp_rate: int = int(core.research_points_per_turn)
	_force("Planetfall Artifact", [8])
	_step12(core, "delve", true, 1)
	assert_bool(core.has_artifact("ancient_ai_chip")) \
		.override_failure_message("p.133: the Artifact found is the colony's").is_true()
	assert_int(int(core.research_points_per_turn)) \
		.override_failure_message("p.135 Ancient AI chip: a Colony Item takes effect") \
		.is_equal(rp_rate + 1)
	assert_int(int(core.research_data.get("current_rp", 0))) \
		.override_failure_message("p.133: +2 Research Points").is_equal(2)
	assert_int(int(core.buildings_data.get("current_bp", 0))) \
		.override_failure_message("p.133: +2 Build Points").is_equal(2)


func test_a_delve_without_the_artifact_gains_nothing() -> void:
	var core := _core()
	_step12(core, "delve", true, 0)
	assert_int(core.artifacts_found.size()).is_equal(0)
	assert_int(int(core.research_data.get("current_rp", 0))).is_equal(0)


func test_a_found_artifact_gives_the_next_one_down() -> void:
	var core := _core()
	core.add_artifact({"id": "ancient_ai_chip", "type": "colony_item"})
	_force("Planetfall Artifact", [8])
	_step12(core, "delve", true, 1)
	assert_bool(core.has_artifact("inherent_core_principal_carbine")) \
		.override_failure_message("p.135: a duplicate is 'the next item down'").is_true()
	var carbine: Dictionary = core.artifacts_found[1]
	assert_str(str(carbine.get("carrier", "?"))).override_failure_message(
		"equipment waits to be given to a character").is_equal("")


func test_equipment_is_lost_with_its_carrier() -> void:
	var core := _core()
	core.acquire_artifact({"id": "focused_beam_emitter", "name": "Focused beam emitter",
		"type": "equipment"})
	core.artifacts_found[0]["carrier"] = "c1"
	core.slay_character("c1")
	assert_bool(bool(core.artifacts_found[0].get("lost", false))) \
		.override_failure_message("p.135: 'If the character dies ... the item is lost'") \
		.is_true()
	assert_bool(core.has_artifact("focused_beam_emitter")) \
		.override_failure_message("it stays found: Artifacts are unique").is_true()


func test_the_regenerative_schematic_mitigates_once_a_turn() -> void:
	var core := _core()
	core.colony_integrity = 10
	core.max_colony_integrity = 10
	core.acquire_artifact({"id": "regenerative_building_schematic", "type": "colony_item",
		"name": "Regenerative building material schematic",
		"effect": {"building_damage_mitigation": 1}})
	assert_int(int(core.take_colony_damage(3).taken)).is_equal(2)
	assert_int(int(core.take_colony_damage(3).taken)) \
		.override_failure_message("p.136: 1 point PER CAMPAIGN TURN, not per instance") \
		.is_equal(3)


# ── p.127 Pitched Battle ───────────────────────────────────────────────────────

func test_a_lost_pitched_battle_rolls_the_campaign_consequences() -> void:
	var core := _core()
	core.colony_integrity = 10
	core.offer_mission("pitched_battle", {"enemy_index": 0, "forced": true})
	_force("Planetfall Campaign Consequence", [70])
	var r := _step12(core, "pitched_battle", false, 0)
	assert_int(int(core.grunts)) \
		.override_failure_message("p.127 61-80 Attrition: remove 2 grunts").is_equal(8)
	assert_int(int(core.colony_integrity)) \
		.override_failure_message("p.127 replaces p.62's Raid: one defeat, one charge") \
		.is_equal(10)
	assert_str(_text(r)).contains("Attrition")


func test_consequence_colony_damage_is_1d6_plus_2() -> void:
	var core := _core()
	core.colony_integrity = 10
	core.max_colony_integrity = 10
	core.offer_mission("pitched_battle", {"enemy_index": 0, "forced": true})
	_force("Planetfall Campaign Consequence", [10])
	_force("Planetfall Consequence Severity", [1])
	_step12(core, "pitched_battle", false, 0)
	assert_int(int(core.colony_integrity)).is_equal(7)


func test_consequence_defenses_negate_each_point_on_a_4_plus() -> void:
	var core := _core()
	core.colony_defenses = 1
	core.colony_morale = 0
	core.offer_mission("pitched_battle", {"enemy_index": 0, "forced": true})
	_force("Planetfall Campaign Consequence", [50])
	_force("Planetfall Consequence Severity", [1])
	_force("Planetfall Colony Defenses", [4, 1, 6])
	_step12(core, "pitched_battle", false, 0)
	assert_int(int(core.colony_morale)) \
		.override_failure_message("p.127 41-60: 3 points, two negated on a 4+") \
		.is_equal(-1)


func test_consequence_interruption_loses_partial_projects() -> void:
	var core := _core()
	core.buildings_data = {"constructed": ["barracks"], "in_progress": {"lab": 2}}
	core.research_data = {"theory_progress": {"ai_theories": 3, "infantry_equipment": 5},
		"completed_theories": ["infantry_equipment"]}
	core.offer_mission("pitched_battle", {"enemy_index": 0, "forced": true})
	_force("Planetfall Campaign Consequence", [30])
	_step12(core, "pitched_battle", false, 0)
	assert_bool((core.buildings_data.in_progress as Dictionary).is_empty()).is_true()
	assert_bool(core.research_data.theory_progress.has("ai_theories")) \
		.override_failure_message("p.127: a part-paid Theory loses all progress").is_false()
	assert_bool(core.research_data.theory_progress.has("infantry_equipment")) \
		.override_failure_message("a COMPLETED Theory is not 'partially completed'") \
		.is_true()
	assert_array(core.buildings_data.constructed).contains(["barracks"])


func test_a_won_pitched_battle_gives_each_survivor_one_more_xp() -> void:
	var core := _core()
	var pm := _pm(core)
	pm.stamp_mission({"id": "pitched_battle", "deployed_ids": ["c1", "c2"]})
	pm.set_battle_result({"won": true, "crew_participants": core.roster.duplicate(true),
		"crew_injuries_data": [core.roster[0].duplicate()], "crew_casualties_data": []})
	var panel: Control = auto_free(PostBattlePanel.new())
	add_child(panel)
	panel.set_campaign(core)
	panel.set_phase_manager(pm)
	panel.set_battle_results(pm.get_battle_result())
	panel._current_sub_step = panel.SubStep.EXPERIENCE
	panel._resolve_experience()
	assert_int(int(core.get_roster_character_by_id("c2").get("xp", 0))) \
		.override_failure_message("p.67 +1 +1 and p.127 +1 for a survivor").is_equal(3)
	assert_int(int(core.get_roster_character_by_id("c1").get("xp", 0))) \
		.override_failure_message("a casualty is not a survivor").is_equal(1)


# ── p.105 Augmentation ─────────────────────────────────────────────────────────

# ── p.157 Slyn tracking (4th Milestone) ─────────────────────────────────────────

func _tracking(core: Resource, victories: int = 0) -> void:
	core.set_milestone_flag("slyn_tracking", true)
	core.slyn_victories = victories


func test_a_slyn_victory_after_the_4th_milestone_is_counted() -> void:
	var core := _core()
	_tracking(core)
	_force("Planetfall Slyn Departure", [9])
	var r := _step12(core, "exploration", true, 0, {"opposition_type": "slyn"})
	assert_int(int(core.slyn_victories)).override_failure_message(
		"p.157: 'Track how many times you beat the Slyn'").is_equal(1)
	assert_bool(bool(core.slyn_departed)).is_false()
	assert_str(_text(r)).contains("2D6 9 is above it")


func test_a_roll_at_or_below_the_count_sends_the_slyn_away() -> void:
	var core := _core()
	_tracking(core, 2)
	_force("Planetfall Slyn Departure", [3])
	_step12(core, "exploration", true, 0, {"opposition_type": "slyn"})
	assert_int(int(core.slyn_victories)).is_equal(3)
	assert_bool(bool(core.slyn_departed)).override_failure_message(
		"p.157: 'equal to or below the tracked victories, the Slyn decide to leave'").is_true()


func test_victories_before_the_4th_milestone_are_not_counted() -> void:
	var core := _core()
	_force("Planetfall Slyn Departure", [2])
	_step12(core, "exploration", true, 0, {"opposition_type": "slyn"})
	assert_int(int(core.slyn_victories)).override_failure_message(
		"p.157: 'Victories prior to this point are not counted'").is_equal(0)
	assert_bool(bool(core.slyn_departed)).is_false()


func test_a_loss_or_another_enemy_counts_nothing() -> void:
	var core := _core()
	_tracking(core)
	_force("Planetfall Slyn Departure", [2, 2])
	_step12(core, "exploration", false, 0, {"opposition_type": "slyn"})
	_step12(core, "exploration", true, 0, {"opposition_type": "lifeforms"})
	assert_int(int(core.slyn_victories)).is_equal(0)
	assert_bool(bool(core.slyn_departed)).is_false()


func test_a_new_turn_reopens_the_augmentation_shop() -> void:
	var core := _core()
	core.research_data["augmentation_purchased_this_turn"] = true
	var pm := _pm(core)
	pm.start_new_turn()
	assert_bool(bool(core.research_data.get("augmentation_purchased_this_turn", true))) \
		.override_failure_message("p.105: one per campaign turn, not one per campaign") \
		.is_false()


# ── p.115 Investigation ────────────────────────────────────────────────────────

func _investigation(core: Resource, won: bool, finds: int, rm: int) -> Dictionary:
	var pm := _pm(core)
	pm.stamp_mission({"id": "investigation", "mission_name": "Investigation",
		"opposition_type": "lifeforms", "tactical_enemy_index": -1, "grunts_deployed": 0,
		"deployed_ids": ["c1", "c2"]})
	pm.set_battle_result({"won": won, "victory": won,
		"crew_participants": core.roster.duplicate(true), "crew_injuries_data": [],
		"crew_casualties_data": []})
	pm.apply_battle_debrief({"objectives_completed": finds + rm,
		"mission_rewards": {"investigation_finds": finds, "investigation_raw_materials": rm}})
	return pm.resolve_intel_step()


## p.115 2 Rewards: "You may roll once on the Post-Mission Finds table ... after the mission
## is over"; p.116: "You receive any rewards you acquired during the mission", won or not.
func test_an_investigation_rewards_result_rolls_a_find_even_in_a_loss() -> void:
	var core := _core()
	core.raw_materials = 0
	_force("Planetfall Post-Mission Find", [36])
	_investigation(core, false, 1, 0)
	assert_int(int(core.raw_materials)).override_failure_message(
		"p.115: a tagged location rolls once on the Finds table (D100 36, Raw materials +3)") \
		.is_equal(3)


## p.115 4 Action required: "A score of 5+ will earn you 1 unit of Raw Materials."
func test_a_passed_action_required_adds_raw_materials() -> void:
	var core := _core()
	core.raw_materials = 0
	_investigation(core, false, 0, 2)
	assert_int(int(core.raw_materials)).is_equal(2)


## p.115 places four Discovery markers, one per table quarter.
func test_investigation_rewards_are_capped_at_the_four_markers() -> void:
	var core := _core()
	core.raw_materials = 0
	_investigation(core, true, 0, 9)
	assert_int(int(core.raw_materials)).is_equal(4)


func test_the_debrief_asks_an_investigation_for_its_rewards() -> void:
	var core := _core()
	var pm := _pm(core)
	pm.stamp_mission({"id": "investigation", "deployed_ids": ["c1"]})
	pm.set_battle_result({"won": false, "crew_participants": [], "crew_injuries_data": []})
	var panel: Control = auto_free(PostBattlePanel.new())
	add_child(panel)
	panel.set_campaign(core)
	panel.set_phase_manager(pm)
	panel.set_battle_results(pm.get_battle_result())
	panel._build_debrief()
	for key in ["investigation_finds", "investigation_raw_materials"]:
		assert_bool(panel._mission_inputs.has(key)).override_failure_message(
			"the debrief must ask for %s, win or lose (p.116)" % key).is_true()
		assert_int(int(panel._mission_inputs[key].max_value)).is_equal(4)
	panel._mission_inputs["investigation_finds"].value = 1
	panel._mission_inputs["investigation_raw_materials"].value = 2
	var rewards: Dictionary = panel._collect_debrief().get("mission_rewards", {})
	assert_int(int(rewards.get("investigation_finds", -1))).is_equal(1)
	assert_int(int(rewards.get("investigation_raw_materials", -1))).is_equal(2)
