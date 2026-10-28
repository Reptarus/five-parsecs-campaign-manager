extends GdUnitTestSuite

## Planetfall Step 11 and Step 16: the Morale Incident table, Political Upheaval, the
## Crisis, and the Integrity Failure table (pp.68, 87-90). Every die is forced through
## the DiceManager seam, so each case names the row it lands on.
##
## ⚠ Before 2026-10-27:
##   - Step 16 rolled a D6 per point of negative Integrity and lost grunts on a 5-6, a
##     table in neither book (p.88 is a 3D6 roll against the flipped Integrity score);
##   - Step 11 printed "roll on the Morale Incident table" and rolled nothing, so no
##     Incident, Political Upheaval, Crisis or Campaign Failure could ever happen;
##   - per-turn Build and Research income was credited by each panel's refresh(), so a
##     resume paid the turn twice and no penalty could ever reach it.

const CoreScript = preload("res://src/game/campaign/PlanetfallCampaignCore.gd")
const PMScript = preload("res://src/core/campaign/PlanetfallPhaseManager.gd")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")
const LockAndLoad = preload("res://src/ui/screens/planetfall/panels/PlanetfallLockAndLoadPanel.gd")
const EndGamePanel = preload("res://src/ui/screens/planetfall/panels/PlanetfallEndGamePanel.gd")
const BuildingPanel = preload("res://src/ui/screens/planetfall/panels/PlanetfallBuildingPanel.gd")
const AutoResolve = preload("res://src/ui/screens/planetfall/panels/PlanetfallAutoResolveDialog.gd")
const PostBattlePanel = preload("res://src/ui/screens/planetfall/panels/PlanetfallPostBattlePanel.gd")
const Phase = PMScript.Phase

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
	core.story_points = 0
	core.roster = [{"id": "c1", "name": "Ash", "class": "trooper", "savvy": 1,
			"loyalty": "loyal", "xp": 0}]
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


func _text(receipt: Dictionary) -> String:
	return "\n".join(PackedStringArray(receipt.get("lines", [])))


# ── The tables are the book's, with no gaps ──────────────────────────────────────

func test_every_table_covers_its_dice_exactly_once() -> void:
	var crisis := PlanetfallColonyCrisis.new()
	assert_bool(crisis.is_loaded()).is_true()
	var integrity: Array = []
	for e in crisis._integrity.get("entries", []):
		integrity.append(int(e.roll))
	integrity.sort()
	assert_array(integrity).override_failure_message("p.88 is keyed 3-18") \
		.is_equal(range(3, 19))
	for spec in [["incidents", 1, 100], ["crisis_outcomes", 2, 12]]:
		var seen: Array = []
		for e in crisis._morale.get(spec[0], []):
			for v in range(int(e.min), int(e.max) + 1):
				assert_bool(seen.has(v)).override_failure_message(
					"%s overlaps at %d" % [spec[0], v]).is_false()
				seen.append(v)
		seen.sort()
		assert_array(seen).override_failure_message("%s has a gap" % spec[0]) \
			.is_equal(range(int(spec[1]), int(spec[2]) + 1))


# ── Step 16: Integrity Failure (pp.87-88) ────────────────────────────────────────

func test_a_roll_at_or_below_the_flipped_score_is_a_failure_on_the_table() -> void:
	var core := _core()
	core.colony_integrity = -8
	_force("Planetfall Integrity Failure", [8])
	var receipt: Dictionary = _pm(core).resolve_integrity_step()
	assert_str(_text(receipt)).contains("3 Colony Damage")
	assert_int(core.colony_integrity) \
		.override_failure_message("row 8: 3 Colony Damage") .is_equal(-11)
	assert_int(core.colony_morale) \
		.override_failure_message("p.87: the Integrity lost costs the same Morale") \
		.is_equal(-3)


func test_a_roll_above_the_flipped_score_is_no_failure() -> void:
	var core := _core()
	core.colony_integrity = -4
	_force("Planetfall Integrity Failure", [5])
	var receipt: Dictionary = _pm(core).resolve_integrity_step()
	assert_str(_text(receipt)).contains("no Integrity Failure")
	assert_int(core.colony_integrity).is_equal(-4)


func test_integrity_above_minus_three_rolls_nothing() -> void:
	var core := _core()
	core.colony_integrity = -2
	_force("Planetfall Integrity Failure", [3])
	_pm(core).resolve_integrity_step()
	assert_bool(_dm.get_forced_results().has("planetfall integrity failure")) \
		.override_failure_message("p.87: -1 or -2 has no risk, so nothing is rolled") \
		.is_true()


func test_emergency_repairs_spend_a_story_point_instead_of_rolling() -> void:
	var core := _core()
	core.colony_integrity = -10
	core.story_points = 2
	_force("Planetfall Integrity Failure", [18])
	var receipt: Dictionary = _pm(core).resolve_integrity_step({"emergency_repairs": true})
	assert_str(_text(receipt)).contains("Emergency Repairs")
	assert_int(core.story_points).is_equal(1)
	assert_int(core.roster.size()).override_failure_message("row 18 was rolled anyway") \
		.is_equal(1)


func test_row_18_slays_a_character_and_clears_their_sick_bay_entry() -> void:
	var core := _core()
	core.colony_integrity = -18
	core.sick_bay = {"c1": 2}
	_force("Planetfall Integrity Failure", [18])
	_pm(core).resolve_integrity_step()
	assert_int(core.roster.size()).is_equal(0)
	assert_bool(core.sick_bay.has("c1")).is_false()


func test_row_10_treats_death_as_five_turns_of_recovery() -> void:
	var core := _core()
	core.colony_integrity = -10
	_force("Planetfall Integrity Failure", [10])
	_force("Planetfall Injury", [1])
	_pm(core).resolve_integrity_step()
	assert_int(core.roster.size()).override_failure_message("row 10 must not kill") \
		.is_equal(1)
	assert_int(int(core.sick_bay.get("c1", 0))).is_equal(5)


func test_row_6_cuts_next_turns_earned_income_not_the_pool() -> void:
	var core := _core()
	core.colony_integrity = -6
	core.build_points_per_turn = 3
	core.buildings_data = {"current_bp": 7}
	_force("Planetfall Integrity Failure", [6])
	_pm(core).resolve_integrity_step()
	assert_int(int(core.buildings_data.current_bp)) \
		.override_failure_message("p.88: stored points are untouched").is_equal(7)
	core.campaign_turn += 1
	var income: Dictionary = core.claim_turn_income("bp")
	assert_int(int(income.net)).override_failure_message("3 earned, -2").is_equal(1)
	assert_int(int(core.buildings_data.current_bp)).is_equal(8)


func test_step_16_resolves_once() -> void:
	var core := _core()
	core.colony_integrity = -8
	_force("Planetfall Integrity Failure", [8, 8])
	var pm := _pm(core)
	var first: Dictionary = pm.resolve_integrity_step()
	var second: Dictionary = pm.resolve_integrity_step()
	assert_dict(second).is_equal(first)
	assert_int(core.colony_integrity).is_equal(-11)


# ── Step 11: Morale Incidents, Upheaval and the Crisis (pp.68, 89-90) ────────────

func test_an_incident_resets_morale_and_adds_upheaval() -> void:
	var core := _core()
	core.colony_morale = -9
	core.research_points_per_turn = 4
	_force("Planetfall Morale Incident", [40])
	_force("Planetfall Crisis Check", [12])
	var receipt: Dictionary = _pm(core).resolve_morale_step()
	assert_str(_text(receipt)).contains("Work stoppage")
	assert_int(core.colony_morale).override_failure_message("p.89: set back to 0") \
		.is_equal(0)
	assert_int(core.political_upheaval).is_equal(1)
	assert_bool(core.in_crisis).override_failure_message("2D6 12 > Upheaval 1") \
		.is_false()
	assert_int(int(core.claim_turn_income("rp").net)) \
		.override_failure_message("p.90 Work stoppage: -3 to RP earned THIS turn") \
		.is_equal(1)


## p.68 / p.89 Rescue Missions: "you do NOT suffer Morale loss due to casualties".
func test_a_rescue_mission_costs_no_morale_for_squad_casualties() -> void:
	assert_int(PlanetfallColonyCrisis.morale_change(2, "rescue")).is_equal(-1)
	assert_int(PlanetfallColonyCrisis.morale_change(2, "patrol")).is_equal(-3)


func test_morale_above_the_threshold_rolls_no_incident() -> void:
	var core := _core()
	core.colony_morale = -8
	_force("Planetfall Morale Incident", [1])
	_pm(core).resolve_morale_step()
	assert_int(core.colony_morale).is_equal(-9)
	assert_bool(_dm.get_forced_results().has("planetfall morale incident")).is_true()


func test_personal_appeals_spend_a_story_point_and_nothing_happens() -> void:
	var core := _core()
	core.colony_morale = -9
	core.story_points = 1
	_force("Planetfall Morale Incident", [1])
	var receipt: Dictionary = _pm(core).resolve_morale_step({"personal_appeals": true})
	assert_str(_text(receipt)).contains("Personal Appeals")
	assert_int(core.colony_morale).override_failure_message("p.89: still set to 0") \
		.is_equal(0)
	assert_int(core.story_points).is_equal(0)
	assert_int(core.political_upheaval) \
		.override_failure_message("nothing was rolled on the table, so no Upheaval") \
		.is_equal(0)
	assert_str(core.roster[0].loyalty).is_equal("loyal")


## p.90 Political strife: "Make a Crisis check", AND p.89: "Each time you receive a
## point of Political Upheaval, you must make a Crisis check" -- two checks. The
## forced order is what makes this discriminate: strife's own check spends the 12
## (no Crisis), the +1 Upheaval check spends the 2 (2 <= 3). With strife's check
## missing, the only check spends the 12 and no Crisis begins.
func test_political_strife_can_tip_the_colony_into_crisis() -> void:
	var core := _core()
	core.colony_morale = -9
	core.political_upheaval = 2
	core.build_points_per_turn = 2
	_force("Planetfall Morale Incident", [80])
	_force("Planetfall Crisis Check", [12, 2])
	_pm(core).resolve_morale_step()
	assert_bool(core.in_crisis) \
		.override_failure_message("two checks: strife's (12) then the Upheaval one (2 <= 3)") \
		.is_true()
	assert_int(core.political_upheaval).is_equal(3)
	core.adjust_morale(-5)
	assert_int(core.colony_morale) \
		.override_failure_message("p.90: Morale is fixed at 0 in a Crisis").is_equal(0)
	assert_int(int(core.claim_turn_income("bp").net)) \
		.override_failure_message("p.90: every source gives 1 less").is_equal(1)


func test_loyalty_loss_steps_down_the_ladder_and_stops_at_disloyal() -> void:
	var core := _core()
	core.colony_morale = -9
	_force("Planetfall Morale Incident", [5])
	_force("Planetfall Crisis Check", [12])
	_pm(core).resolve_morale_step()
	assert_str(core.roster[0].loyalty).is_equal("committed")
	core.roster[0].loyalty = "disloyal"
	assert_dict(core.lower_loyalty("c1")) \
		.is_equal({"name": "Ash", "from": "disloyal", "to": "disloyal"})


func test_protests_keep_the_chosen_trooper_out_of_next_turn_unless_pitched() -> void:
	var core := _core()
	core.colony_morale = -9
	_force("Planetfall Morale Incident", [20])
	_force("Planetfall Crisis Check", [12])
	var pm := _pm(core)
	pm.resolve_morale_step()
	assert_bool(core.protest_pending).is_true()
	pm.assign_protest("c1")
	assert_str(core.deployment_block_reason("c1", "patrol")) \
		.override_failure_message("not THIS turn: p.90 says next campaign turn") \
		.is_equal("")
	core.campaign_turn += 1
	assert_str(core.deployment_block_reason("c1", "patrol")).is_equal("PROTESTS")
	assert_str(core.deployment_block_reason("c1", "pitched_battle")).is_equal("")


func test_colonist_demands_end_on_a_supervisors_five_plus() -> void:
	var core := _core()
	core.colonist_demands = true
	_force("Planetfall Colonist Demands", [4])
	var receipt: Dictionary = _pm(core).resolve_morale_step({"supervisors": ["c1"]})
	assert_str(_text(receipt)).contains("1D6 4 +1 Savvy = 5")
	assert_bool(core.colonist_demands).is_false()


func test_agreements_reached_ends_the_crisis() -> void:
	var core := _core()
	core.in_crisis = true
	core.political_upheaval = 4
	_force("Planetfall Crisis Outcome", [11])
	_pm(core).resolve_morale_step()
	assert_bool(core.in_crisis).is_false()
	assert_int(core.political_upheaval).is_equal(0)
	assert_int(core.colony_morale).is_equal(0)


func test_a_crisis_reroll_keeps_the_better_score() -> void:
	var core := _core()
	core.in_crisis = true
	core.political_upheaval = 4
	core.story_points = 1
	_force("Planetfall Crisis Outcome", [6, 11])
	var receipt: Dictionary = _pm(core).resolve_morale_step({"crisis_reroll": true})
	assert_str(_text(receipt)).contains("keeping 11")
	assert_bool(core.in_crisis).is_false()
	assert_int(core.story_points).is_equal(0)


## p.90: High tensions, then a second Crisis check at or below Upheaval, ends the
## campaign. Completing the step stops the turn and announces it.
func test_high_tensions_can_end_the_campaign_and_stop_the_turn() -> void:
	var core := _core()
	core.in_crisis = true
	core.political_upheaval = 3
	var pm := _pm(core)
	var ended: Array = []
	pm.campaign_ended.connect(func(reason: String) -> void: ended.append(reason))
	pm.start_new_turn()
	while pm.current_phase != Phase.MORALE_ADJUSTMENTS:
		pm.complete_current_phase({})
	_force("Planetfall Crisis Outcome", [2])
	_force("Planetfall Crisis Check", [3])
	pm.complete_current_phase({})
	assert_bool(core.is_failed()).is_true()
	assert_array(ended).is_equal(["crisis_collapse"])
	assert_int(pm.current_phase) \
		.override_failure_message("the turn must not run on past a failed campaign") \
		.is_equal(Phase.NONE)


# ── Income is credited once per turn (the resume double-credit) ──────────────────

func test_income_is_credited_once_per_turn() -> void:
	var core := _core()
	core.build_points_per_turn = 2
	core.buildings_data = {"current_bp": 0}
	core.claim_turn_income("bp")
	var again: Dictionary = core.claim_turn_income("bp")
	assert_bool(bool(again.already)).is_true()
	assert_int(int(core.buildings_data.current_bp)).is_equal(2)
	var restored = CoreScript.new()
	restored.from_dictionary(core.to_dictionary())
	assert_bool(bool(restored.claim_turn_income("bp").already)) \
		.override_failure_message("a reload must not pay the turn again").is_true()


func test_the_stability_state_survives_a_save() -> void:
	var core := _core()
	core.political_upheaval = 2
	core.in_crisis = true
	core.colonist_demands = true
	core.colony_damage_mitigation = 1
	core.add_income_penalty(4, 2, 5)
	var copy = CoreScript.new()
	copy.from_dictionary(JSON.parse_string(JSON.stringify(core.to_dictionary())))
	assert_int(copy.political_upheaval).is_equal(2)
	assert_bool(copy.in_crisis).is_true()
	assert_bool(copy.colonist_demands).is_true()
	assert_int(copy.colony_damage_mitigation).is_equal(1)
	copy.campaign_turn = 4
	assert_int(int(copy.claim_turn_income("rp").penalty)) \
		.override_failure_message("the penalty is keyed by turn and survives JSON") \
		.is_equal(1)


# ── The screens hand these rules to the player ───────────────────────────────────

func _mount(script: GDScript) -> Control:
	var panel: Control = script.new()
	add_child(panel)
	auto_free(panel)
	return panel


func test_lock_and_load_holds_back_the_protesting_trooper() -> void:
	var core := _core()
	core.protest_sitout = {"character_id": "c1", "turn": core.campaign_turn}
	var panel := _mount(LockAndLoad)
	panel.set_campaign(core)
	panel.set_mission_context({"selected_mission": {"id": "patrol"}})
	panel.refresh()
	var checks: Array = panel._roster_container.find_children("*", "CheckBox", true, false)
	assert_int(checks.size()).override_failure_message("premise: one roster row").is_equal(1)
	assert_bool((checks[0] as CheckBox).disabled).is_true()
	panel.set_mission_context({"selected_mission": {"id": "pitched_battle"}})
	panel.refresh()
	checks = panel._roster_container.find_children("*", "CheckBox", true, false)
	assert_bool((checks.back() as CheckBox).disabled) \
		.override_failure_message("p.90: the protests recede for a Pitched Battle").is_false()


func test_a_finished_campaign_opens_on_its_conclusion() -> void:
	var core := _core()
	core.game_phase = "failed"
	var panel := _mount(EndGamePanel)
	panel.set_campaign(core)
	panel.refresh()
	assert_int(panel._current_stage) \
		.override_failure_message("C13: refresh() always reset to the Summit") \
		.is_equal(panel.Stage.COMPLETE)
	var shown := ""
	for n in panel.find_children("*", "Label", true, false):
		shown += (n as Label).text
	assert_str(shown).contains("CAMPAIGN FAILURE")


func test_the_building_step_credits_income_once_across_a_resume() -> void:
	var core := _core()
	core.build_points_per_turn = 2
	core.buildings_data = {"current_bp": 0}
	var panel := _mount(BuildingPanel)
	panel.set_campaign(core)
	panel.set_phase_manager(_pm(core))
	panel.refresh()
	panel.refresh()
	assert_int(int(core.buildings_data.current_bp)) \
		.override_failure_message("each refresh() credited the turn's income again") \
		.is_equal(2)


func test_step_16_offers_emergency_repairs_before_the_roll() -> void:
	var core := _core()
	core.colony_integrity = -10
	core.story_points = 1
	var pm := _pm(core)
	var panel := _mount(AutoResolve)
	panel.set_campaign(core)
	panel.set_phase_manager(pm)
	panel.configure("colony_integrity", Phase.COLONY_INTEGRITY)
	panel.refresh()
	assert_object(panel._emergency_check).is_not_null()
	panel._emergency_check.button_pressed = true
	_force("Planetfall Integrity Failure", [18])
	panel.complete()
	assert_int(core.story_points).is_equal(0)
	assert_int(core.roster.size()).override_failure_message("the roll was made anyway") \
		.is_equal(1)


func test_step_11_offers_personal_appeals_before_the_incident() -> void:
	var core := _core()
	core.colony_morale = -9
	core.story_points = 1
	var pm := _pm(core)
	pm.start_new_turn()
	while pm.current_phase != Phase.MORALE_ADJUSTMENTS:
		pm.complete_current_phase({})
	var panel := _mount(PostBattlePanel)
	panel.set_campaign(core)
	panel.set_phase_manager(pm)
	panel.refresh()
	assert_object(panel._appeals_check) \
		.override_failure_message("-9 -1 = -10: an Incident is coming").is_not_null()
	panel._appeals_check.button_pressed = true
	_force("Planetfall Morale Incident", [1])
	panel._on_action_pressed()
	assert_int(core.story_points).is_equal(0)
	assert_int(core.colony_morale).is_equal(0)
	assert_str(core.roster[0].loyalty).is_equal("loyal")
